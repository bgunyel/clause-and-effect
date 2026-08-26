"""
How many model calls a retried call really makes, and how many of them the
process can name.

**The question, and why it decides a schema.** `build_judge_llm` attaches
`.with_retry(stop_after_attempt=3)` to every judge stage. A retried call runs
the model more than once; each run is a generation at the provider and each is
billed. The returned message carries the id of the *last* one. So every cost
total this project has published may be a floor for a reason nobody has
measured, and the call log being designed in `docs/design/llm-call-log.md` would
inherit the same blind spot — one row per logical call, no row for the attempts
that failed inside the retry.

Two designs follow from the answer and they are not compatible. If the callback
layer sees each attempt, a row is *per attempt* and carries a shared logical-call
id. If it does not, a row is per logical call and the log must at least record
that attempts it cannot describe took place. Writing the schema before measuring
means writing it twice.

**There is a second retry layer, underneath the one we configured.**
`langchain_openrouter.chat_models:226` declares `max_retries: int = 2` and
nothing in `ai_common.get_llm` overrides it, so the OpenAI SDK client retries
before LangChain's `.with_retry` ever sees a failure. Up to 3 × 3 = 9 upstream
requests per logical call. (`llm_config` carries `max_llm_retries: 3`, but
`get_llm` takes no such argument and `build_judge_llm` does not pass it: it is
dead config, and is not the layer above.)

**So the probe counts at the socket.** The number of requests that actually
reached OpenRouter is read from `httpx.Client.send` / `httpx.AsyncClient.send`,
which is the last point the request is ours — the same method
`probe_wire_params.py` uses, and for the same reason. Counting retries by
reading `_create_chat_result`, or by trusting a callback, would re-derive the
answer from one of the layers whose behaviour is in question. Whatever the
socket saw is what happened.

**Failures are injected after a real generation, not instead of one.** Each
intercepted request is forwarded to OpenRouter for real; the response is read,
its generation id and cost recorded, and only *then* replaced with a 500. That
is deliberate and it is the whole point: a synthetic failure that never leaves
the machine produces no generation and would make the undercount unmeasurable by
construction. These runs cost real money — a handful of trivial calls on the
cheapest panelist — and the sum of what they cost against the sum the caller can
account for is the measurement.

Three scenarios:

1. **Async, failing twice then succeeding.** The ordinary retry: what does the
   caller end up holding, and what did it not hear about?
2. **Async, failing throughout.** The exhausted retry, which is where the
   attempts hide. Bounded by `_MAX_FORWARDED` so a misbehaving layer cannot
   spend without limit.
3. **Sync, succeeding.** The product path (`generator.py`, `compliance_agent.py`,
   `main_dev.py`) calls `.invoke`, not `.ainvoke`. The design proposes one
   handler for both, and that only holds if a plain `BaseCallbackHandler` fires
   on the synchronous path too.

The callback is passed through `config=` rather than attached at construction.
For counting events the two are equivalent — config propagates down to the chat
model — and construction-time attachment is what the design will actually do.

Run:

    uv run python -m scripts.probe_retry_visibility
"""
from __future__ import annotations

import asyncio
import json
import logging
import time
from contextlib import contextmanager
from dataclasses import dataclass, field
from typing import Any, Dict, Iterator, List, Optional, Tuple

import httpx
from pydantic import BaseModel, Field

from src.logging_setup import setup_logging

logger = logging.getLogger(__name__)

# Only completions traffic is touched. Anything else httpx carries — and the
# generation endpoint is not queried here — passes through untouched.
_COMPLETIONS = "/chat/completions"

# A hard ceiling on forwarded requests, because scenario 2 deliberately makes
# every attempt fail and the retry layers multiply. The first run of this probe
# used twelve and hit the cap, which is itself the finding: `max_retries` is not
# a count. `chat_models.py:457` turns it into
# `max_elapsed_time = max_retries * 150_000` ms — 300 seconds of exponential
# backoff with no attempt limit at all. There is no safe ceiling to pick, so the
# cap exists to bound spend and the report says plainly when it was what stopped
# the run.
_MAX_FORWARDED = 6

# Short, cheap, and answerable by every model. The content is irrelevant — what
# is being measured is how many times it was asked.
_PROMPT = "Which city is the capital of Türkiye? Answer with the city name only."


class _Answer(BaseModel):
    """A trivial schema, so the structured-output channel is the real one."""

    city: str = Field(description="the city named in the question")


class _ProbeCapReached(RuntimeError):
    """Raised at the socket when `_MAX_FORWARDED` is hit, to bound spend."""


@dataclass
class _Timeline:
    """
    Socket traffic and callback events in one ordered list.

    Two separate lists cannot answer the question this probe is actually asking.
    The first run produced twelve upstream requests and three callback runs, and
    "four requests per callback run" and "twelve requests inside the first run,
    then two runs that made none" fit those totals equally well — while implying
    opposite things about where the retrying happens. Interleaving them settles
    it by observation instead of by arithmetic.
    """

    started: float = field(default_factory=time.monotonic)
    entries: List[Tuple[float, str, str]] = field(default_factory=list)

    def add(self, kind: str, text: str) -> None:
        self.entries.append((time.monotonic() - self.started, kind, text))


@dataclass
class _WireCall:
    """One request that actually reached OpenRouter."""

    index: int
    upstream_status: int
    generation_id: Optional[str]
    # The field `_create_chat_result` drops on its way to `response_metadata`
    # (measured 2026-08-25). At this layer it has not been dropped yet.
    provider: Optional[str]
    cost: Optional[float]
    substituted: bool  # did the probe replace this response with a 500


@dataclass
class _Wire:
    """
    The socket's account of what happened, and the failure injector.

    ``fail_first`` is how many of the forwarded responses are replaced with a
    500 before the rest are allowed through; ``None`` means every one of them.
    """

    fail_first: Optional[int]
    timeline: _Timeline
    calls: List[_WireCall] = field(default_factory=list)

    @property
    def total_cost(self) -> float:
        """What the provider charged across every attempt, priced ones only."""
        return sum(c.cost for c in self.calls if c.cost is not None)

    def _substitute(self) -> bool:
        if self.fail_first is None:
            return True
        return len(self.calls) < self.fail_first

    def handle(
        self, request: httpx.Request, response: httpx.Response, body: bytes
    ) -> httpx.Response:
        """Record a real response, then decide whether the caller sees it."""
        try:
            payload: Dict[str, Any] = json.loads(body)
        except ValueError:
            payload = {}

        usage = payload.get("usage") or {}
        substituted = self._substitute()
        self.calls.append(
            _WireCall(
                index=len(self.calls) + 1,
                upstream_status=response.status_code,
                generation_id=payload.get("id"),
                provider=payload.get("provider"),
                cost=usage.get("cost"),
                substituted=substituted,
            )
        )
        self.timeline.add(
            "wire",
            f"#{len(self.calls)} {payload.get('id') or '<no id>'} "
            f"upstream {response.status_code}"
            f"{' -> replaced with 500' if substituted else ''}",
        )
        if not substituted:
            return response

        return httpx.Response(
            500,
            request=request,
            json={"error": {"message": "probe-injected failure", "code": 500}},
        )


@contextmanager
def _intercepting(wire: _Wire) -> Iterator[None]:
    """
    Wrap both httpx transports for the duration of one scenario.

    Both, not one: the eval path is `async` and the product path is not, and
    scenario 3 exists precisely to check the synchronous half.
    """
    original_async = httpx.AsyncClient.send
    original_sync = httpx.Client.send

    async def async_send(self, request: httpx.Request, **kwargs: Any) -> httpx.Response:
        if _COMPLETIONS not in str(request.url):
            return await original_async(self, request, **kwargs)
        if len(wire.calls) >= _MAX_FORWARDED:
            raise _ProbeCapReached(
                f"probe cap: {_MAX_FORWARDED} requests already forwarded"
            )
        response = await original_async(self, request, **kwargs)
        return wire.handle(request, response, await response.aread())

    def sync_send(self, request: httpx.Request, **kwargs: Any) -> httpx.Response:
        if _COMPLETIONS not in str(request.url):
            return original_sync(self, request, **kwargs)
        if len(wire.calls) >= _MAX_FORWARDED:
            raise _ProbeCapReached(
                f"probe cap: {_MAX_FORWARDED} requests already forwarded"
            )
        response = original_sync(self, request, **kwargs)
        return wire.handle(request, response, response.read())

    httpx.AsyncClient.send = async_send
    httpx.Client.send = sync_send
    try:
        yield
    finally:
        httpx.AsyncClient.send = original_async
        httpx.Client.send = original_sync


@dataclass
class _Event:
    """One thing the callback layer reported."""

    kind: str
    run_id: str
    generation_id: Optional[str]
    detail: Optional[str]


class _Recorder:
    """
    A callback handler that records every model event it is told about.

    Deliberately *not* subclassed off a stage or a wrapper: the design question
    is whether this layer sees attempts, so it must see whatever the layer
    offers and nothing filtered on its way.
    """

    # LangChain checks these attributes before dispatching. Declared explicitly
    # rather than inherited so the handler has no behaviour it did not ask for.
    ignore_llm = False
    ignore_chain = False
    ignore_agent = False
    ignore_retriever = False
    ignore_chat_model = False
    ignore_retry = False
    ignore_custom_event = False
    raise_error = False
    run_inline = False

    def __init__(self, timeline: _Timeline) -> None:
        self.events: List[_Event] = []
        self.timeline = timeline

    def _record(self, event: _Event) -> None:
        self.events.append(event)
        detail = " ".join(
            part for part in (event.generation_id, event.detail) if part
        )
        self.timeline.add(
            "callback", f"{event.kind} run=…{event.run_id[-8:]} {detail}".rstrip()
        )

    # Chat models fire `on_chat_model_start`; `on_llm_start` is the completion
    # models' equivalent. Both are defined because assuming which one arrives is
    # the kind of inference this probe exists to replace.
    def on_chat_model_start(self, serialized, messages, *, run_id=None, **kwargs):
        self._record(_Event("chat_model_start", str(run_id), None, None))

    def on_llm_start(self, serialized, prompts, *, run_id=None, **kwargs):
        self._record(_Event("llm_start", str(run_id), None, None))

    def on_llm_end(self, response, *, run_id=None, **kwargs):
        metadata: Dict[str, Any] = {}
        try:
            metadata = response.generations[0][0].message.response_metadata or {}
        except (AttributeError, IndexError):
            pass
        cost = metadata.get("cost")
        self._record(
            _Event(
                "llm_end",
                str(run_id),
                metadata.get("id"),
                None if cost is None else f"${cost:.8f}",
            )
        )

    def on_llm_error(self, error, *, run_id=None, **kwargs):
        self._record(
            _Event("llm_error", str(run_id), None, type(error).__name__)
        )

    def on_retry(self, retry_state, *, run_id=None, **kwargs):
        self._record(
            _Event("retry", str(run_id), None, f"attempt {retry_state.attempt_number}")
        )

    def __getattr__(self, name: str) -> Any:
        # Every other hook LangChain may call is a no-op. Written as a fallback
        # rather than as fifteen empty methods, and it cannot swallow one of the
        # hooks above, since those are found on the class first.
        if name.startswith("on_"):
            return lambda *args, **kwargs: None
        raise AttributeError(name)


@dataclass
class _Outcome:
    """One scenario's result, from all three vantage points."""

    name: str
    wire: _Wire
    recorder: _Recorder
    caller_saw: str
    caller_generation_id: Optional[str]
    caller_cost: Optional[float]
    timeline: _Timeline


def _judge_chain(schema: type[BaseModel]):
    """
    The real construction path, for the cheapest panelist.

    `build_judge_llm` rather than a locally assembled model, because the retry
    under investigation is the one *it* attaches, and its channel branch decides
    whether a failure raises or is captured into the payload.
    """
    from ai_common.enums import ModelNames

    from src.eval.sufficiency.llm import build_judge_llm
    from src.llm_config import get_llm_config, panelist

    entry = panelist(
        get_llm_config()["sufficiency_judge"], ModelNames.DEEPSEEK_V_4_FLASH_0731
    )
    return build_judge_llm(entry, schema)


def _read_caller_view(payload: Any) -> Tuple[str, Optional[str], Optional[float]]:
    """What a stage would record, given whatever the chain returned."""
    raw = (payload or {}).get("raw")
    metadata = getattr(raw, "response_metadata", None) or {}
    parsed = (payload or {}).get("parsed")
    return (
        f"returned; parsed={parsed!r}",
        metadata.get("id"),
        metadata.get("cost"),
    )


async def _async_scenario(name: str, fail_first: Optional[int]) -> _Outcome:
    chain = _judge_chain(_Answer)
    timeline = _Timeline()
    wire = _Wire(fail_first, timeline)
    recorder = _Recorder(timeline)

    with _intercepting(wire):
        try:
            payload = await chain.ainvoke(_PROMPT, config={"callbacks": [recorder]})
            caller_saw, generation_id, cost = _read_caller_view(payload)
        except Exception as exc:  # noqa: BLE001 — the failure *is* the result
            caller_saw = f"raised {type(exc).__name__}: {exc}"
            generation_id, cost = None, None

    return _Outcome(name, wire, recorder, caller_saw, generation_id, cost, timeline)


def _sync_scenario(name: str) -> _Outcome:
    chain = _judge_chain(_Answer)
    timeline = _Timeline()
    wire = _Wire(fail_first=0, timeline=timeline)
    recorder = _Recorder(timeline)

    with _intercepting(wire):
        try:
            payload = chain.invoke(_PROMPT, config={"callbacks": [recorder]})
            caller_saw, generation_id, cost = _read_caller_view(payload)
        except Exception as exc:  # noqa: BLE001
            caller_saw = f"raised {type(exc).__name__}: {exc}"
            generation_id, cost = None, None

    return _Outcome(name, wire, recorder, caller_saw, generation_id, cost, timeline)


def _report(outcome: _Outcome) -> str:
    lines = [f"=== {outcome.name} ==="]

    lines.append(f"upstream requests that really happened: {len(outcome.wire.calls)}")
    for call in outcome.wire.calls:
        price = "not reported" if call.cost is None else f"${call.cost:.8f}"
        lines.append(
            f"  {call.index}. {call.generation_id or '<no id in body>'}  "
            f"served by {call.provider or '<absent>'}  "
            f"upstream {call.upstream_status}  {price}"
            f"{'  [probe replaced with 500]' if call.substituted else ''}"
        )
    lines.append(f"total billed across attempts: ${outcome.wire.total_cost:.8f}")

    lines.append("")
    lines.append(f"callback events: {len(outcome.recorder.events)}")
    for event in outcome.recorder.events:
        parts = [f"  {event.kind}", f"run={event.run_id[-8:]}"]
        if event.generation_id:
            parts.append(event.generation_id)
        if event.detail:
            parts.append(event.detail)
        lines.append("  ".join(parts))

    distinct_runs = {e.run_id for e in outcome.recorder.events}
    lines.append(f"distinct callback run ids: {len(distinct_runs)}")

    lines.append("")
    lines.append("interleaved — which layer made which request:")
    for elapsed, kind, text in outcome.timeline.entries:
        lines.append(f"  {elapsed:7.2f}s  {kind:8}  {text}")

    lines.append("")
    lines.append(f"caller saw: {outcome.caller_saw}")
    lines.append(f"caller's generation id: {outcome.caller_generation_id}")
    accounted = outcome.caller_cost
    lines.append(
        "caller's cost: "
        + ("not reported" if accounted is None else f"${accounted:.8f}")
    )
    unaccounted = outcome.wire.total_cost - (accounted or 0.0)
    lines.append(
        f"UNACCOUNTED: ${unaccounted:.8f} "
        f"({len(outcome.wire.calls) - (1 if outcome.caller_generation_id else 0)} "
        f"generation(s) the caller cannot name)"
    )
    return "\n".join(lines)


async def main() -> None:
    setup_logging()
    # httpx logs one INFO line per request, which would interleave with the
    # report the probe exists to produce.
    logging.getLogger("httpx").setLevel(logging.WARNING)

    logger.info("scenario 1: two attempts fail, the third succeeds (async)")
    first = await _async_scenario("1 · async, fails twice then succeeds", fail_first=2)
    logger.info("\n%s", _report(first))

    logger.info("scenario 2: every attempt fails (async), capped at %d", _MAX_FORWARDED)
    second = await _async_scenario("2 · async, retry exhausted", fail_first=None)
    logger.info("\n%s", _report(second))

    logger.info("scenario 3: one clean call on the synchronous path")
    third = _sync_scenario("3 · sync, succeeds first time")
    logger.info("\n%s", _report(third))

    logger.info(
        "\ntotal spent by this probe: $%.8f over %d upstream requests",
        first.wire.total_cost + second.wire.total_cost + third.wire.total_cost,
        len(first.wire.calls) + len(second.wire.calls) + len(third.wire.calls),
    )


if __name__ == "__main__":
    asyncio.run(main())
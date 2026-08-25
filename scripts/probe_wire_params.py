"""
What this config actually sends, read off the socket rather than off the config.

`llm_config.model_args` carries `'provider': {'require_parameters': True}` —
the OpenRouter routing constraint that stops a request being handed to an
upstream provider which does not implement the parameters it contains. Without
it a provider that ignores `response_format` may be selected and simply drop it:
the call succeeds, is billed, and comes back as prose. It is the mechanism that
makes the per-model `structured_output` assignment *stick*, and it is a
candidate explanation for the roster's unexplained intermittency — Grok answered
4 of 6 in one panel run and 6 of 6 in the next with no change on our side.

**It has never been exercised, and it does not reach the request directly.** It
travels config → `get_llm` → `ChatOpenRouter(model_kwargs=...)` →
`_default_params` → request body, through a dict `get_llm` builds out of
whatever is left after it pops `temperature`, `top_p` and `reasoning_effort`.
Every step of that is inference from reading code. If `provider` is dropped
anywhere along it, the next panel run reads as *"require_parameters changed
nothing"* when in fact it was never sent — a null result about the wrong thing,
and the kind of mistake an eval instrument cannot make quietly.

**So this probe asserts against the bytes, not against an object.**
`httpx.AsyncClient.send` is wrapped for the duration of the run and the JSON body
of every `/chat/completions` request is kept. That is the last point the request
is ours; whatever is in there is what OpenRouter received. Reading
`_default_params`, or the model object's attributes, would re-derive the answer
from the same layer whose behaviour is in question.

**The call goes through `build_judge_llm`**, not through a locally assembled
model. The question is what *the judge* sends, so the judge's own construction
path — including the `dict(model_args)` copy and the channel branch — has to be
the one under test. A convenience wrapper here would be a probe of this file.

Expectations are written as literals below rather than imported from
`llm_config`, for the reason the suite already applies: a check that reads its
expected value from the code it is checking passes whatever that code does.

One trivial call per panelist, run sequentially. Sequential is deliberate —
bodies are attributed to the model that produced them by *when* they arrive, and
concurrency would leave that attribution to be inferred from the body's own
`model` field, which is the alias rather than the name in the config.

Run:

    uv run python -m scripts.probe_wire_params

(A path invocation fails — `scripts/` lands on `sys.path` instead of the repo
root, and `pythonpath` in `pyproject.toml` is pytest-only.)
"""
from __future__ import annotations

import asyncio
import json
import logging
import time
from contextlib import contextmanager
from dataclasses import dataclass
from typing import Any, Dict, Iterator, List, Literal, Optional, Tuple

import httpx
from pydantic import BaseModel, Field

from scripts.probe_spend import format_spend
from src.eval.sufficiency.llm import (
    JudgeResponseError,
    StageResponse,
    build_judge_llm,
    require_response,
)
from src.llm_config import get_llm_config
from src.logging_setup import setup_logging

logger = logging.getLogger(__name__)

# Half the panel probe's deadline. That one is sized for a real stage A2 prompt;
# this prompt is one sentence, and a panelist that cannot answer it inside a
# minute is not a panelist.
CALL_TIMEOUT_SECONDS = 60

# What the request body must contain. Literals, not imports — see the docstring.
_EXPECTED_PROVIDER = {"require_parameters": True}
_EXPECTED_TEMPERATURE = 0
_EXPECTED_TOP_P = 0.95
_EXPECTED_REASONING_EFFORT = "high"

# The body keys that show which structured-output channel was actually used.
# Checked because `provider` only means something if the parameters it is
# constraining routing over are the ones we think we sent.
_CHANNEL_KEYS = {
    "function_calling": ("tools", "tool_choice"),
    "json_schema": ("response_format",),
    "tool_call_auto": ("tools", "tool_choice"),
}

# How much of a provider error is kept. One can carry an HTML page.
_ERROR_CHARS = 200


class _WireCheck(BaseModel):
    """The roster probe's schema, for the same reason: a `Literal` is where a
    weaker structured-output implementation breaks, and both real channels have
    to be exercised with a shape the stages would recognise."""

    answer: str = Field(description="The capital city of Turkiye.")
    tag: Literal["core", "auxiliary"] = Field(description='Exactly "core".')


_PROMPT = (
    "You are being checked for wiring, not judgement. Return exactly:\n"
    "  answer: the capital city of Turkiye (one word)\n"
    '  tag:    the literal value "core"\n'
)


@contextmanager
def capture_request_bodies() -> Iterator[List[Dict[str, Any]]]:
    """
    Keep the JSON body of every chat completion request sent while active.

    Patched on `httpx.AsyncClient` rather than on anything in langchain or the
    OpenAI SDK, because those are the layers whose faithfulness is the question.
    `send` is the last call before the bytes leave, and it is reached by
    subclasses too.

    A body that will not parse is recorded as such rather than dropped: "the
    request was not JSON" and "no request was made" are different findings, and
    an empty list must be able to mean only the second.
    """
    bodies: List[Dict[str, Any]] = []
    original = httpx.AsyncClient.send

    async def recording(self, request, *args, **kwargs):  # type: ignore[no-untyped-def]
        if request.url.path.endswith("/chat/completions"):
            try:
                bodies.append(json.loads(request.content))
            except Exception as exc:  # noqa: BLE001 — recording, not handling
                bodies.append({"__unparseable__": f"{type(exc).__name__}: {exc}"})
        return await original(self, request, *args, **kwargs)

    httpx.AsyncClient.send = recording  # type: ignore[method-assign]
    try:
        yield bodies
    finally:
        httpx.AsyncClient.send = original  # type: ignore[method-assign]


@dataclass(frozen=True)
class WireResult:
    """One panelist's request body and what the call to produce it did."""

    model: str
    channel: str
    body: Optional[Dict[str, Any]]
    requests: int
    call_status: str
    call_detail: str
    seconds: float
    response: Optional[StageResponse]


def check_body(body: Optional[Dict[str, Any]], channel: str) -> Tuple[str, List[str]]:
    """
    Whether one request body carries what the config says it carries.

    Returns a verdict and the list of discrepancies. The sampling parameters are
    checked alongside `provider` because they share its route: all four leave
    `llm_config` in one dict, and three of them are popped out of it by `get_llm`
    before the remainder becomes `model_kwargs`. A run where `provider` arrived
    and `reasoning` did not is a different defect from one where neither did.
    """
    if body is None:
        return "NO REQUEST", ["no chat completion request was sent"]

    problems: List[str] = []

    if body.get("provider") != _EXPECTED_PROVIDER:
        problems.append(f"provider={body.get('provider')!r}")
    if body.get("temperature") != _EXPECTED_TEMPERATURE:
        problems.append(f"temperature={body.get('temperature')!r}")
    if body.get("top_p") != _EXPECTED_TOP_P:
        problems.append(f"top_p={body.get('top_p')!r}")

    reasoning = body.get("reasoning")
    effort = reasoning.get("effort") if isinstance(reasoning, dict) else None
    if effort != _EXPECTED_REASONING_EFFORT:
        problems.append(f"reasoning.effort={effort!r}")

    for key in _CHANNEL_KEYS.get(channel, ()):
        if key not in body:
            problems.append(f"{key} absent (channel {channel})")

    return ("OK" if not problems else "MISMATCH"), problems


async def probe_model(
    entry: Dict[str, Any], bodies: List[Dict[str, Any]]
) -> WireResult:
    """
    Send one call for one panelist and keep the body it produced.

    `bodies` is emptied first, so what remains afterwards belongs to this model
    and to no other. The call's own outcome is recorded but is not the finding:
    a request that was sent and then rejected still answers the question this
    probe asks, and a transport failure here would otherwise discard the
    evidence it just produced.
    """
    bodies.clear()
    started = time.perf_counter()
    response: Optional[StageResponse] = None

    try:
        llm = build_judge_llm(entry, _WireCheck)
        response = require_response(
            await asyncio.wait_for(
                llm.ainvoke(_PROMPT), timeout=CALL_TIMEOUT_SECONDS
            ),
            stage="wire",
        )
    except asyncio.TimeoutError:
        status, detail = "TIMEOUT", f"no response within {CALL_TIMEOUT_SECONDS}s"
    except JudgeResponseError as exc:
        status, detail = "STRUCTURE", str(exc)[:_ERROR_CHARS]
    except Exception as exc:  # noqa: BLE001 — a provider error is a result here
        status, detail = "TRANSPORT", f"{type(exc).__name__}: {str(exc)[:_ERROR_CHARS]}"
    else:
        status, detail = "OK", f"{response.value.answer!r} / {response.value.tag!r}"

    return WireResult(
        model=str(entry["model"]),
        channel=str(entry["structured_output"]),
        # The last body, not the first: `.with_retry(stop_after_attempt=3)` can
        # send several, and the one that produced the response is the one that
        # matters. `requests` is reported so a retried call is visible as such.
        body=bodies[-1] if bodies else None,
        requests=len(bodies),
        call_status=status,
        call_detail=detail,
        seconds=time.perf_counter() - started,
        response=response,
    )


def short_name(model: str) -> str:
    """`ModelNames.GROK_4_6` rendered for a table cell."""
    return model.split(".", 1)[-1]


def build_report(results: List[WireResult]) -> str:
    """The whole run as one record, so the table arrives as a table."""
    width = max(len(short_name(r.model)) for r in results)
    lines: List[str] = []
    out = lines.append

    out("=" * 96)
    out("require_parameters on the wire — captured from httpx, not read from config")
    out("=" * 96)
    out(
        f"{'model':{width}}  {'channel':16}  {'wire':10}  {'call':10}  "
        f"{'req':>3}  {'sec':>5}"
    )
    out("-" * 96)

    verdicts = []
    for r in results:
        verdict, problems = check_body(r.body, r.channel)
        verdicts.append((r, verdict, problems))
        out(
            f"{short_name(r.model):{width}}  {r.channel:16}  {verdict:10}  "
            f"{r.call_status:10}  {r.requests:3}  {r.seconds:5.1f}"
        )

    out("-" * 96)
    sent = sum(1 for _, v, _ in verdicts if v == "OK")
    out(f"provider={_EXPECTED_PROVIDER} reached the wire on {sent} of {len(results)}")

    bad = [(r, p) for r, v, p in verdicts if v != "OK"]
    if bad:
        out("")
        out("Discrepancies")
        for r, problems in bad:
            out(f"  {short_name(r.model)}: " + "; ".join(problems))

    failed = [r for r in results if r.call_status != "OK"]
    if failed:
        out("")
        out("Calls that did not return a graded answer")
        for r in failed:
            out(f"  {short_name(r.model)} [{r.call_status}] {r.call_detail}")

    # One body in full. The table says a key was present; this says what the
    # request looked like, which is what makes the run checkable by someone who
    # did not watch it. `messages` is dropped — it is the prompt above, and it
    # is the only large field.
    evidence = next((r for r in results if r.body), None)
    if evidence is not None:
        body = {k: v for k, v in evidence.body.items() if k != "messages"}
        out("")
        out(f"Request body sent for {short_name(evidence.model)} (messages elided)")
        out(json.dumps(body, indent=2, sort_keys=True, default=str))

    priced = [r.response for r in results if r.response is not None]
    out("")
    out(format_spend(priced) if priced else "spend: no call returned a price")
    out("=" * 96)
    return "\n".join(lines)


async def main() -> None:
    setup_logging()
    entries = get_llm_config()["sufficiency_judge"]

    results: List[WireResult] = []
    with capture_request_bodies() as bodies:
        for entry in entries:
            logger.info("probing %s", short_name(str(entry["model"])))
            results.append(await probe_model(entry, bodies))

    logger.info("\n%s", build_report(results))


if __name__ == "__main__":
    asyncio.run(main())
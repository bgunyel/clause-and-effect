"""
Making one model call: invoke it, time it, log it, and unwrap what came back.

Everything here is about **money and accountability** rather than about import
cost — that is :mod:`src.llm.structured`'s subject. A call has a price, an id at
the provider, and a number of reasoning tokens, and all three are read off the
raw message ``include_raw=True`` keeps. Every caller gets an
:class:`LlmResponse` rather than a bare value, so a run can report its spend
without any call site having to know how spend is totalled.

**Nothing in this module is judge-specific**, which is why it sits beside
``config.py`` rather than under ``src/eval/``. The four outcomes it tells apart
are properties of calling a model through LangChain: a structured-output call on
the product path fails to coerce exactly as a judge stage's does. The judge's
own vocabulary — ``stage``-worded messages, ``JudgeResponseError``,
``StageResponse`` — is a thin adapter in :mod:`src.eval.sufficiency.llm`.

**The wrapper is behaviour-identical when the log is off.** Nothing above it can
tell it is here: a failed call is written and then re-raised unchanged, and with
no ``DB_URL`` not a single line of the storage layer is imported.
"""
from __future__ import annotations

import time
from contextlib import nullcontext
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import (
    TYPE_CHECKING,
    Any,
    Dict,
    Generic,
    Iterable,
    Tuple,
    TypeVar,
)

from pydantic import BaseModel

from src.db.capture import response as response_reader
from src.llm.structured import StructuredPayload

if TYPE_CHECKING:
    from langchain_core.language_models import LanguageModelInput
    from langchain_core.runnables import Runnable

# The structured-output shape one call returns.
_SchemaT = TypeVar("_SchemaT", bound=BaseModel)

# What a caller hands back once it has mapped the schema into a domain type —
# `Decomposition`, `BlindAnswer`, a list of `Claim`. Unconstrained, because the
# mapping is the caller's business and none of it is visible here.
_ValueT = TypeVar("_ValueT")

# How much of a raw response is quoted when it could not be parsed. Enough to
# recognise what came back — a refusal, a prose answer, a truncated object —
# without pasting a full generation into a traceback.
_EXCERPT_CHARS = 300


@dataclass(frozen=True)
class CallRecord:
    """
    What one model call was: which generation, what it cost, how much of it was
    reasoning.

    **One record rather than three parallel tuples.** Until 2026-08-25 the id
    travelled alone in a ``Tuple[str | None, ...]``, which was right while there
    was one fact per call. Reasoning tokens are the third, and three tuples that
    must stay index-aligned across the three sites that concatenate them would
    make the alignment a convention rather than a structure — with the failure
    mode of attributing a reasoning count to the wrong generation, inside the
    record that exists to be checkable against the provider. A record cannot
    drift from itself.

    Every field is ``None`` for the same class of reason: the provider did not
    report it. ``None`` is never a zero. A call that reported ``reasoning: 0``
    thought without spending tokens on it, or was not given the budget; a call
    that reported nothing may have reasoned freely and simply not said so, and
    the two must not average together.
    """

    generation_id: str | None
    cost: float | None
    reasoning_tokens: int | None


class LlmResponseError(RuntimeError):
    """
    A model call returned nothing parseable into its schema.

    Observed 2026-08-22 on stage A2, where it surfaced as ``AttributeError:
    'NoneType' object has no attribute 'claims'`` from inside a list
    comprehension — a traceback naming neither the caller nor the cause. Every
    stage had the same shape, because every stage read a field straight off the
    value ``ainvoke`` returned.

    This is a *transport* failure, not a result: the work was not done badly, it
    was not done at all. Keeping it a distinct exception type is what lets a
    caller tell "the model decided" from "the model did not answer" — a
    distinction an eval instrument cannot afford to blur, since a swallowed one
    would silently shrink the sample.

    **A failure carries the record of the call that failed** — its price, its
    generation id, and its reasoning tokens. ``call`` is keyword-only and has no
    default, because the defect this repairs is precisely that these were in
    hand and thrown away: the raise sites read the raw message, and then dropped
    it. Observed 2026-08-23 — a MiniMax response that raised here reported
    ``finish_reason: stop`` and ``cost: 0.0011607`` on the very message the
    error was built from, while every report of that run said failed calls "may
    still have been billed". They *were* billed, by a knowable amount; 20 calls
    across three panel runs went unaccounted for that way. A defaulted ``None``
    would let a future raise site re-create the same silence by omission.

    **Its message names no stage and no case.** Those are the judge's words, and
    :class:`~src.eval.sufficiency.llm.JudgeResponseError` prefixes them when it
    re-raises. What is here is what any caller would say.
    """

    def __init__(self, message: str, *, call: CallRecord) -> None:
        super().__init__(message)
        self.call = call

    @property
    def cost(self) -> float | None:
        """What the provider charged for the call that failed."""
        return self.call.cost

    @property
    def generation_id(self) -> str | None:
        """The failed call's id at the provider, where it can still be read."""
        return self.call.generation_id

    @property
    def reasoning_tokens(self) -> int | None:
        """How much of the failed call was reasoning, if it said."""
        return self.call.reasoning_tokens


@dataclass(frozen=True)
class LlmResponse(Generic[_ValueT]):
    """
    One result, what the calls to produce it cost, and which they were.

    ``cost`` is ``None`` when the provider did not report one, and that is not
    the same as ``0.0``. A caller that made no call at all is genuinely free —
    stage C skips the model when there are no core claims — whereas an unpriced
    call is money spent that nobody can account for. Summing the two together
    would under-report spend and never say so, which is why the distinction is
    carried in the type instead of being flattened at the first opportunity.

    OpenRouter reports ``cost`` on every response, so ``None`` should not occur
    against the current configuration. It is modelled anyway because the panel
    (§8) is the reason the cost is being tracked, and a panel is several
    providers by definition.

    ``calls`` holds **one :class:`CallRecord` per model call behind this
    response**, in the order the calls were made. A response behind which no
    call was made has ``()`` — stage C's two no-call paths, where it is the
    exact companion of ``cost=0.0``. An aggregate has one entry per leg.

    **A tuple, though the design note (devlog 2026-08-23) proposed a singular
    ``generation_id``.** Singular composes wrong at the only two sites that
    matter: ``stage_a_twocall.decompose`` and ``judge.probe_case`` aggregate
    several calls into one response, and a single field forces them to pick one
    call and drop the rest — losing exactly the calls whose spend the aggregate
    is already summing. Cost survives aggregation by addition; the calls
    themselves survive it by concatenation, and ``()`` for no calls keeps both
    readings honest.

    ``cost`` on an aggregate is not the sum of ``calls``: it goes ``None`` when
    *any* leg was unpriced, because a total covering some of the calls is worse
    than no total. The per-call prices stay in ``calls``, where a reader can see
    which leg was the gap.
    """

    value: _ValueT
    cost: float | None
    calls: Tuple[CallRecord, ...]

    @property
    def generation_ids(self) -> Tuple[str | None, ...]:
        """
        The provider-side ids of the calls behind this response, in call order.

        A derived view rather than a stored field, so it cannot disagree with
        ``calls``. Kept because "which generations was this?" is the question
        reports actually ask, and answering it by mapping over records at every
        call site would put the same comprehension in six places.
        """
        return tuple(call.generation_id for call in self.calls)


def sum_costs(costs: Iterable[float | None]) -> Tuple[float, int]:
    """
    Total the known costs, and count the ones that were not reported.

    Returns both rather than a bare float so a caller cannot print a total
    without knowing how complete it is. A run of thirty calls where four went
    unpriced has a total that is real but not the spend, and the only honest
    report of that says so.
    """
    known = [c for c in costs if c is not None]
    return sum(known), sum(1 for c in costs if c is None)


def _cost_of(raw: Any) -> float | None:
    """
    The price the provider put on one response, if it reported one.

    ``.get`` rather than ``[]``: ``cost`` is an OpenRouter field, not a
    LangChain one, and a provider that omits it must yield an unpriced call
    rather than a ``KeyError`` that loses an otherwise valid result.

    Delegated to :mod:`src.db.capture.response`, which the call log reads the
    same field with. Two implementations of "where does the provider put the
    price" is one too many: the day OpenRouter moves it, one of them gets fixed
    and the other goes on returning ``None`` — indistinguishable, here, from a
    provider that did not report a price.
    """
    return response_reader.cost_of(raw)


def _generation_id_of(raw: Any) -> str | None:
    """
    The provider's own id for one generation, if it named one.

    ``response_metadata['id']``, and specifically **not** ``raw.id``. Measured
    2026-08-25 on both channels: the message's own ``id`` is a LangChain run
    identifier minted in this process (``lc_run--01a0376a-7f1a-…``), while
    OpenRouter's is ``gen-1787636121-eAEcEp3BID10rZPfqZgv`` and appears only in
    the metadata. ``raw.id`` is the tempting attribute and it is worthless here,
    because it joins to nothing outside this process.

    This is the one field that makes a run auditable against the provider. It is
    also the field whose absence made Bertan's 2026-08-23 finding manual work:
    the panel had recorded MiniMax as failing on cases the OpenRouter console
    showed as successful, and the two could only be matched by re-running the
    case with a diagnostic that printed an id the judge itself never kept.

    ``.get`` for the same reason as :func:`_cost_of`: this is a provider field,
    not a LangChain one, and a response without it must yield an unidentified
    call rather than a ``KeyError`` that loses a result over bookkeeping.

    Delegated for the reason :func:`_cost_of` gives.
    """
    return response_reader.generation_id_of(raw)


def _reasoning_tokens_of(raw: Any) -> int | None:
    """
    How many of the call's output tokens went on reasoning, if it reported any.

    ``usage_metadata['output_token_details']['reasoning']``, which LangChain
    normalises from whatever the provider sends. Recorded because the panel
    calls different models through different structured-output channels — a
    concession made 2026-08-23 to the fact that neither channel works for every
    model — and that concession has an unquantified cost.

    The specific suspicion, and it is measured rather than assumed: MiniMax
    reported ``{'reasoning': 0}`` under ``json_schema`` while producing
    reasoning on the tool path. If ``response_format`` suppresses reasoning for
    some models, then three of the eight panelists judge without the budget the
    other five get, *inside the comparison the panel exists to make*. Nothing
    could settle that while nothing recorded the number.

    ``None`` and ``0`` are different answers and both occur. ``0`` is a provider
    saying this call did no reasoning; ``None`` is a provider not saying. Only
    the first belongs in an average.

    Delegated for the reason :func:`_cost_of` gives.
    """
    return response_reader.reasoning_tokens_of(raw)


def _record_of(raw: Any) -> CallRecord:
    """One call's audit record, read off the message it came back on."""
    return CallRecord(
        generation_id=_generation_id_of(raw),
        cost=_cost_of(raw),
        reasoning_tokens=_reasoning_tokens_of(raw),
    )


def _audit_note(cost: float | None, generation_id: str | None) -> str:
    """
    Where to find this call at the provider, appended to a failure's message.

    In the message and not only on the exception, because a failure most often
    reaches a human as a line in a report or a traceback. An id that is only
    reachable through ``exc.generation_id`` is one nobody reads at the moment
    they are looking at the failure — which is the state this whole change is
    correcting.
    """
    where = (
        f"generation {generation_id}"
        if generation_id
        else "no generation id was reported, so this call cannot be matched "
        "against the provider's console"
    )
    price = "not reported" if cost is None else f"${cost:.6f}"
    return f"[{where}; cost {price}]"


def _excerpt(raw: Any) -> str:
    """What the model actually said, shortened, for an error message."""
    content = getattr(raw, "content", "") or ""
    flattened = " ".join(str(content).split())
    if len(flattened) > _EXCERPT_CHARS:
        flattened = flattened[:_EXCERPT_CHARS] + "…"
    return flattened or "<empty>"


def require_payload(
    payload: StructuredPayload[_SchemaT] | None,
) -> LlmResponse[_SchemaT]:
    """
    Unwrap one structured payload, or raise saying what came back instead.

    The single place the raw message is read, so it is also where the cost and
    the generation id are taken off it: a caller that mapped its schema and
    discarded the payload would have to be edited twice to keep them in step.

    **Both are recorded on the failure paths too, and that is the point.** A
    call that could not be parsed was still made, still billed, and still exists
    at the provider under an id. Raising without them — which is what this did
    until 2026-08-25 — throws away the two facts that would let someone check
    what actually happened, at exactly the moment they most need checking.

    Two failures reach here, and they are told apart rather than merged.
    ``None`` is nothing at all — the chain yielded no payload. A payload whose
    ``parsed`` is ``None`` means the model answered and the answer would not
    coerce, in which case ``parsing_error`` and the text itself are quoted:
    "the model returned prose" and "the model returned nothing" call for
    different repairs, and before ``include_raw`` both collapsed into the same
    bare ``None``.

    Note what is *not* retried. ``with_structured_output(include_raw=True)``
    catches a coercion failure and reports it in the payload instead of raising,
    so ``.with_retry`` never sees one and never retries it. That was equally
    true before, when the same failure arrived as ``None``.

    Args:
        payload: Whatever ``ainvoke`` returned.

    Raises:
        LlmResponseError: if the model returned no parseable structure.
    """
    if payload is None:
        # Nothing came back at all, so there is nothing to read a price or an id
        # off. This is the one failure that is genuinely unaccountable, and it
        # says so rather than implying the call was free.
        raise LlmResponseError(
            f"the model returned no output at all. {_audit_note(None, None)}",
            call=CallRecord(generation_id=None, cost=None, reasoning_tokens=None),
        )

    parsed = payload.get("parsed")
    if parsed is None:
        # The opposite case, and the common one: the model answered, the answer
        # would not coerce, and the message carrying the answer also carries
        # what it cost and which generation it was. Both are taken off the same
        # message the excerpt is quoted from, so a report can state the spend of
        # its failures instead of describing it as a floor.
        record = _record_of(payload.get("raw"))
        raise LlmResponseError(
            f"the model's output would not coerce into its schema "
            f"({payload.get('parsing_error')!r}). It returned: "
            f"{_excerpt(payload.get('raw'))}. "
            f"{_audit_note(record.cost, record.generation_id)}",
            call=record,
        )

    record = _record_of(payload.get("raw"))
    return LlmResponse(value=parsed, cost=record.cost, calls=(record,))


async def llm_call(
    runnable: "Runnable[LanguageModelInput, StructuredPayload[_SchemaT]]",
    prompt: Any,
    *,
    model_params: Dict[str, Any],
    stage: str | None = None,
    metadata: Dict[str, Any] | None = None,
) -> LlmResponse[_SchemaT]:
    """
    Invoke one model call, time it, log it, and unwrap it.

    Replaces the two lines every judge stage repeated — ``await
    llm.ainvoke(prompt)`` inside an unwrapper — and adds the call log around
    them. A caller that used it before the log existed would behave identically,
    which is the property that makes it safe to put on the hot path of every
    model call in the repository.

    **It takes a built runnable rather than building one.** Passing
    ``model_params`` and a schema would read better at the call site and would
    move :func:`~src.llm.structured.build_structured_llm` inside this function,
    where a caller's tests can no longer replace it — twenty of the judge's
    tests install a fake by patching the stage module's own reference. The log
    is not worth reaching into a test seam for.

    **The timer stops before the write** (design §The timed region excludes the
    write, Bertan's correction of 2025-08-25). ``call_seconds`` is the bare
    invocation; a run's wall clock includes the ~90 ms round trip that follows,
    and the per-call latency column does not.

    **A failed call is logged and then still raised.** That is most of the point
    rather than a nicety: a call that raised was still made, still billed, and
    still exists at the provider under an id that, per OpenRouter's
    documentation, no query can recover after the fact. The row is written
    first and the exception propagates unchanged, so nothing above this can tell
    the log is here.

    The four statuses are told apart because they call for different reactions.
    ``STRUCTURE_PROBLEM`` is a model that answered unusably — a prompt or a
    channel problem. ``TIMEOUT`` and ``TRANSPORT_PROBLEM`` are the network or
    the provider, and a run full of them says nothing about any model's output.

    **What the row's ``error_message`` holds is this tier's wording**, not a
    caller's. A judge stage re-raises as ``JudgeResponseError`` with the stage
    named, but the row already has a ``stage`` column; repeating it inside the
    message would store the same fact twice and make the column the redundant
    copy.

    Args:
        runnable:     What ``build_structured_llm`` returned.
        prompt:       Whatever the caller built; hashed, never stored.
        model_params: The config entry, for the model, channel and routing
                      constraint the row records.
        stage:        The log's ``stage`` column — ``"A"``, ``"A1"``, ``"A2"``,
                      ``"B"`` or ``"C"`` from the judge, ``None`` from a caller
                      with no stages.
        metadata:     Anything the call site knows that has no column.

    Returns:
        The :class:`LlmResponse` :func:`require_payload` would have returned.

    Raises:
        LlmResponseError: exactly as :func:`require_payload` does, after the row
            is written.
    """
    # Deferred for the reason `structured.py` gives about `get_llm`: the storage
    # layer costs 0.495s to import, and a module that is only imported — by its
    # tests, or to read a prompt — must not pay it.
    from src.db import engine as db_engine
    from src.db.capture import recorder
    from src.db.capture.context import call_context, current_case
    from src.db.models import CallStatus

    enabled = db_engine.is_enabled()
    # Built only when the log is on: the first call to `RUN.row()` shells out to
    # git, and a fresh clone with no DB_URL must not run a subprocess to make a
    # model call.
    context = recorder.new_call_context(stage, current_case()) if enabled else None

    async def record(status, *, raw=None, error=None, error_message=None) -> None:
        if not enabled:
            return
        await recorder.record_call(
            recorder.build_call_row(
                context=context,
                model_params=model_params,
                prompt=prompt,
                status=status,
                started_at=started_at,
                call_seconds=call_seconds,
                raw=raw,
                error=error,
                error_message=error_message,
                metadata=metadata,
            )
        )

    started_at = _now()
    started = time.perf_counter()
    try:
        # The context is published only around the invocation, because that is
        # the only window in which the socket sees a request belonging to this
        # call. Anything the process does outside it — including the log's own
        # writes — is correctly attributed to no call at all.
        with call_context(context) if enabled else nullcontext():
            payload = await runnable.ainvoke(prompt)
    except BaseException as exc:  # noqa: BLE001 — re-raised below, unchanged
        call_seconds = time.perf_counter() - started
        # `TimeoutError` and `asyncio.TimeoutError` are the same class from
        # Python 3.11, so one branch catches both. Everything else is transport:
        # the distinction worth drawing is "we gave up waiting" against "it went
        # wrong", and inventing finer categories from exception names would be
        # guessing about libraries we do not control.
        status = CallStatus.TIMEOUT if isinstance(exc, TimeoutError) else CallStatus.TRANSPORT_PROBLEM
        await record(status, error=exc, error_message=str(exc))
        raise
    call_seconds = time.perf_counter() - started

    # `payload` is `None` when the chain yielded nothing at all, which is the one
    # failure with no message to read a price off. `.get` guards that shape.
    raw = payload.get("raw") if payload else None
    try:
        response = require_payload(payload)
    except LlmResponseError as exc:
        # Logged from the exception rather than from the payload, so
        # `error_message` carries the full text a human would see — including
        # the audit note naming the generation. `raw_output` stores the model's
        # own words separately and, unlike that message, unshortened.
        await record(CallStatus.STRUCTURE_PROBLEM, raw=raw, error=exc, error_message=str(exc))
        raise

    await record(CallStatus.OK, raw=raw)
    return response


def _now() -> datetime:
    """
    Wall-clock start of a call, in UTC.

    Separate from ``perf_counter`` on purpose: this one places the call against
    other calls and other machines, and the monotonic clock times it. Neither
    can do the other's job — a monotonic reading is meaningless across
    processes, and a wall clock can go backwards mid-measurement.
    """
    return datetime.now(timezone.utc)

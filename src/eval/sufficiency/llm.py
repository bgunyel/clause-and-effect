"""
Building the structured-output model a judge stage runs on.

The only module in this package that reaches ``ai_common``, and therefore the
only one that can cost langchain → transformers → torch. Keeping it alone here
is what lets :mod:`src.eval.sufficiency.models` and everything derived from it
be tested for free.

**Alone is not enough — the cost has to be deferred as well as isolated.** Both
stage modules import :func:`build_judge_llm` at module scope, so while this
module paid at import time, so did they, and so did their tests: measured 6.3s
cold for ``import src.eval.sufficiency.llm``, and 2.4s on the test suite. Two
imports had to move, not one. ``get_llm`` goes inside the function; the two
``langchain_core`` names are needed only by the signature, and
``from __future__ import annotations`` already makes annotations strings, so
they go behind ``TYPE_CHECKING`` and never load at runtime. Deferring only
``get_llm`` would have bought nothing, because ``langchain_core`` is the leg
that pulls torch.

The cost is deferred, not removed: the first call to :func:`build_judge_llm`
pays it. Nothing here is cheaper to *run*, only cheaper to *import*.

**Two costs share this module and are unrelated.** The paragraphs above are
about import time. The rest of it — :class:`StructuredPayload`,
:class:`StageResponse`, :func:`sum_costs` — is about money: what a call to the
provider was charged, read off the raw message that ``include_raw=True`` keeps.
Every stage returns a :class:`StageResponse` rather than its value alone, so a
run can report its spend without any stage having to know how spend is totalled.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import (
    TYPE_CHECKING,
    Any,
    Dict,
    Generic,
    Iterable,
    Tuple,
    TypedDict,
    TypeVar,
    cast,
)

from pydantic import BaseModel, ValidationError

if TYPE_CHECKING:
    from langchain_core.language_models import LanguageModelInput
    from langchain_core.runnables import Runnable

# The structured-output shape a judge stage returns. Each stage has its own.
_SchemaT = TypeVar("_SchemaT", bound=BaseModel)

# What a stage hands back once it has mapped the schema into a domain type —
# `Decomposition`, `BlindAnswer`, a list of `Claim`. Unconstrained, because the
# mapping is the stage's business and none of it is visible here.
_ValueT = TypeVar("_ValueT")

# How much of a raw response is quoted when it could not be parsed. Enough to
# recognise what came back — a refusal, a prose answer, a truncated object —
# without pasting a full generation into a traceback.
_EXCERPT_CHARS = 300


class JudgeResponseError(RuntimeError):
    """
    A stage's model call returned nothing parseable into its schema.

    Observed 2026-08-22 on stage A2, where it surfaced as ``AttributeError:
    'NoneType' object has no attribute 'claims'`` from inside a list
    comprehension — a traceback naming neither the stage nor the cause. Every
    stage had the same shape, because every stage read a field straight off the
    value ``ainvoke`` returned.

    This is a *transport* failure, not a judgement: the case was not judged
    insufficient, it was not judged at all. Keeping it a distinct exception type
    is what lets a caller tell "the judge decided" from "the judge did not
    answer" — a distinction an eval instrument cannot afford to blur, since a
    swallowed one would silently shrink the sample.

    **A failure carries the record of the call that failed** — its price, its
    generation id, and its reasoning tokens. ``call`` is keyword-only and has no
    default, because the defect this repairs is precisely that these were in
    hand and thrown away: the raise sites read the raw message, and then dropped
    it. Observed 2026-08-23 — a MiniMax
    response that raised here reported ``finish_reason: stop`` and
    ``cost: 0.0011607`` on the very message the error was built from, while
    every report of that run said failed calls "may still have been billed".
    They *were* billed, by a knowable amount; 20 calls across three panel runs
    went unaccounted for that way. A defaulted ``None`` would let a future raise
    site re-create the same silence by omission.
    """

    def __init__(self, message: str, *, call: "CallRecord") -> None:
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


class StructuredPayload(TypedDict, Generic[_SchemaT]):
    """
    What ``with_structured_output(..., include_raw=True)`` returns.

    Declared rather than left as an untyped dict because the whole cost
    mechanism rests on the shape: ``parsed`` is what the stage wanted, and
    ``raw`` is the ``AIMessage`` carrying the metadata the parsed object throws
    away. Without ``include_raw`` the chain yields ``parsed`` alone and there is
    no message left to read a price off.
    """

    raw: Any
    parsed: _SchemaT | None
    parsing_error: Any


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


@dataclass(frozen=True)
class StageResponse(Generic[_ValueT]):
    """
    One stage's result, what the calls to produce it cost, and which they were.

    ``cost`` is ``None`` when the provider did not report one, and that is not
    the same as ``0.0``. A stage that made no call at all is genuinely free —
    stage C skips the model when there are no core claims — whereas an unpriced
    call is money spent that nobody can account for. Summing the two together
    would under-report spend and never say so, which is why the distinction is
    carried in the type instead of being flattened at the first opportunity.

    OpenRouter reports ``cost`` on every response, so ``None`` should not occur
    against the current configuration. It is modelled anyway because the panel
    (§8) is the reason the cost is being tracked, and a panel is several
    providers by definition.

    ``calls`` holds **one :class:`CallRecord` per model call behind this
    response**, in the order the calls were made. A stage that made none has
    ``()`` — stage C's two no-call paths, where it is the exact companion of
    ``cost=0.0``. The two-call variant has two, and :func:`judge.probe_case` has
    the union of its three stages.

    **A tuple, though the design note (devlog 2026-08-23) proposed a singular
    ``generation_id``.** Singular composes wrong at the only two sites that
    matter: ``stage_a_twocall.decompose`` and ``judge.probe_case`` aggregate
    several calls into one response, and a single field forces them to pick one
    call and drop the rest — losing exactly the calls whose spend the aggregate
    is already summing. Cost survives aggregation by addition; the calls
    themselves survive it by concatenation, and ``()`` for no calls keeps both
    readings honest.

    ``cost`` here is the aggregate and it is not the sum of ``calls``: it goes
    ``None`` when *any* leg was unpriced, because a total covering some of the
    calls is worse than no total. The per-call prices stay in ``calls``, where a
    reader can see which leg was the gap.
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
    rather than a ``KeyError`` that loses an otherwise valid judgement.
    """
    metadata = getattr(raw, "response_metadata", None) or {}
    return metadata.get("cost")


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
    call rather than a ``KeyError`` that loses a judgement over bookkeeping.
    """
    metadata = getattr(raw, "response_metadata", None) or {}
    return metadata.get("id")


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
    """
    usage = getattr(raw, "usage_metadata", None) or {}
    details = usage.get("output_token_details") or {}
    return details.get("reasoning")


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


def require_response(
    payload: StructuredPayload[_SchemaT] | None, *, stage: str
) -> StageResponse[_SchemaT]:
    """
    Unwrap a stage's structured payload, or raise naming the stage.

    The single place the raw message is read, so it is also where the cost and
    the generation id are taken off it: a stage that mapped its schema and
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
        stage:   Which stage is asking, for the error message.

    Raises:
        JudgeResponseError: if the model returned no parseable structure.
    """
    if payload is None:
        # Nothing came back at all, so there is nothing to read a price or an id
        # off. This is the one failure that is genuinely unaccountable, and it
        # says so rather than implying the call was free.
        raise JudgeResponseError(
            f"stage {stage}: the model returned no output at all. The case was "
            f"not judged; it must not be recorded as one that was. "
            f"{_audit_note(None, None)}",
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
        raise JudgeResponseError(
            f"stage {stage}: the model's output would not coerce into its "
            f"schema ({payload.get('parsing_error')!r}). It returned: "
            f"{_excerpt(payload.get('raw'))}. The case was not judged; it must "
            f"not be recorded as one that was. "
            f"{_audit_note(record.cost, record.generation_id)}",
            call=record,
        )

    record = _record_of(payload.get("raw"))
    return StageResponse(value=parsed, cost=record.cost, calls=(record,))


def payload_from_tool_call(
    message: Any, schema: type[_SchemaT]
) -> StructuredPayload[_SchemaT]:
    """
    Turn one ``bind_tools`` reply into the payload the rest of this module reads.

    The ``TOOL_CALL_AUTO`` path returns an ``AIMessage`` rather than the
    ``{raw, parsed, parsing_error}`` dict ``with_structured_output(include_raw=
    True)`` produces. Rebuilding that shape here — rather than teaching
    :func:`require_response` a second one — is what keeps every stage, the error
    reporting and the cost plumbing identical across the two paths. ``raw`` is
    the same message either way, so ``_cost_of`` needs no branch.

    **A missing tool call is a failure, and specifically not an empty result.**
    ``tool_choice="auto"`` permits the model to answer in prose instead of
    calling the tool, which the forced path makes impossible. Stage A2 may
    legitimately return *zero claims* (design §4.5: a gold answer that does not
    answer its own question), so if silence were mapped to an empty list the two
    would be indistinguishable — a case nobody judged would be recorded as a case
    judged to have no core content. It is reported as ``parsed: None`` instead,
    which :func:`require_response` turns into a :class:`JudgeResponseError`.

    The first tool call is taken. Only one tool is ever bound, so a second would
    mean the model called the same schema twice; that is not a shape any stage
    has a use for, and quietly concatenating them would invent content.
    """
    calls = getattr(message, "tool_calls", None) or []
    if not calls:
        return {
            "raw": message,
            "parsed": None,
            "parsing_error": (
                "the model returned no tool call. `tool_choice=\"auto\"` allows "
                "that; it means the case was not judged, not that it has no "
                "core claims."
            ),
        }

    try:
        parsed = schema(**calls[0]["args"])
    except ValidationError as exc:
        return {"raw": message, "parsed": None, "parsing_error": exc}

    return {"raw": message, "parsed": parsed, "parsing_error": None}


def build_judge_llm(
    model_params: Dict[str, Any],
    schema: type[_SchemaT],
) -> Runnable[LanguageModelInput, StructuredPayload[_SchemaT]]:
    """
    Build a structured-output LLM for one judge stage.

    Args:
        model_params: One entry from :func:`src.llm_config.get_llm_config`.
        schema:       The pydantic shape the stage must return.

    Returns:
        A runnable that yields a :class:`StructuredPayload` — the parsed schema
        *and* the message it was parsed from. Stages pass it to
        :func:`require_response` rather than reading it directly.

    **``include_raw=True`` is what makes the call auditable.** Without it the
    chain returns the parsed object alone, the ``AIMessage`` is dropped inside
    the chain, and with it goes ``response_metadata`` — where the provider puts
    the price of the call and the token counts. An eval instrument that cannot
    say what a run cost cannot be budgeted, and the panel (§8) multiplies every
    case by the number of members.

    ``with_structured_output`` is declared as returning ``dict | BaseModel``,
    because it accepts both a dict schema and a pydantic class. Passing a pydantic
    class narrows that at runtime but not in the type system, so the cast is made
    once here rather than at each of the five stage call sites.
    """
    # Deferred, like `get_llm` below: `src.llm_config` imports `ai_common.enums`
    # at module scope, which is 0.24s and 195 modules. Naming these at the top of
    # this file would put that on `models.py`'s test run and on every importer of
    # a stage — the cost this module is arranged to avoid. They are three
    # strings, and the config is where they are defined.
    from src.llm_config import FUNCTION_CALLING, JSON_SCHEMA, TOOL_CALL_AUTO

    # Checked before anything is built. Neither channel works for every model —
    # MiniMax M3's endpoint takes no tools, DeepSeek V4 Flash times out under
    # `response_format` — so a silent default would call some new panelist the
    # wrong way and the result would be recorded as that model's judgement.
    mode = model_params.get("structured_output")
    if mode not in (FUNCTION_CALLING, JSON_SCHEMA, TOOL_CALL_AUTO):
        raise ValueError(
            f"model {model_params.get('model')!r} has no structured-output "
            f"channel: got {mode!r}. Choose one in `llm_config.structured_output` "
            f"— it is a measurement about the model, not a default."
        )

    # Deferred deliberately — see the module docstring. This is the line that
    # costs langchain → transformers → torch, and it is paid on first call
    # rather than by every importer of a stage module.
    from ai_common import get_llm

    llm = get_llm(
        model_name=model_params["model"],
        model_provider=model_params["model_provider"],
        api_key=model_params["api_key"],
        # A fresh copy, because ``get_llm`` does not read this dict — it
        # **empties** it. The OpenRouter branch pops ``temperature``, ``top_p``
        # and ``reasoning_effort`` out and hands the remainder to the client as
        # ``model_kwargs``, leaving the caller's dict ``{}``.
        #
        # Every stage builds its model on every call from the one entry
        # ``get_llm_config`` returns, so without this copy only the *first*
        # build in a process gets the configured sampling. The two pops that
        # carry defaults survive by coincidence — ``pop('temperature', 0)`` and
        # ``pop('top_p', 0.95)`` happen to name the configured values — but
        # ``reasoning_effort`` defaults to ``None``, so the second call onwards
        # silently ran with no reasoning budget at all. Measured 2026-08-23:
        # build 1 gives ``reasoning={'effort': 'high'}``, build 2 gives
        # ``{'effort': None}``.
        #
        # `llm_config.py` already gives each entry its own copy, which stops one
        # panelist rewriting another's sampling. That cannot help here: this is
        # a single entry eroding across repeated builds of *itself*.
        model_args=dict(model_params["model_args"]),
    )
    if mode == JSON_SCHEMA:
        # `response_format` rather than tools. `include_raw` behaves identically
        # on this path — the parser assigns `parsed`/`parsing_error` beside the
        # same `raw` message — so the cost plumbing and `require_response` need
        # no branch. Note the failure mode is unchanged too: an unparseable
        # response arrives as `parsed: None`, not as an exception, so
        # `.with_retry` never sees it.
        return cast(
            "Runnable[LanguageModelInput, StructuredPayload[_SchemaT]]",
            llm.with_structured_output(
                schema=schema, method="json_schema", include_raw=True
            ).with_retry(stop_after_attempt=3),
        )

    if mode == TOOL_CALL_AUTO:
        # Deferred for the same reason as `get_llm`: this is a `langchain_core`
        # name, and `langchain_core` is the leg that pulls torch. By this line
        # `get_llm` has already imported it, so the cost is not paid twice.
        from langchain_core.runnables import RunnableLambda

        return cast(
            "Runnable[LanguageModelInput, StructuredPayload[_SchemaT]]",
            llm.bind_tools([schema], tool_choice="auto")
               .with_retry(stop_after_attempt=3)
            | RunnableLambda(lambda message: payload_from_tool_call(message, schema)),
        )

    return cast(
        "Runnable[LanguageModelInput, StructuredPayload[_SchemaT]]",
        llm.with_structured_output(schema=schema, include_raw=True)
           .with_retry(stop_after_attempt=3),
    )
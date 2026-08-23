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

from pydantic import BaseModel

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
    """


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
class StageResponse(Generic[_ValueT]):
    """
    One stage's result and what the call to produce it cost.

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
    """

    value: _ValueT
    cost: float | None


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

    The single place the raw message is read, so it is also where the cost is
    taken off it: a stage that mapped its schema and discarded the payload would
    have to be edited twice to keep the two in step.

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
        raise JudgeResponseError(
            f"stage {stage}: the model returned no output at all. The case was "
            f"not judged; it must not be recorded as one that was."
        )

    parsed = payload.get("parsed")
    if parsed is None:
        raw = payload.get("raw")
        raise JudgeResponseError(
            f"stage {stage}: the model's output would not coerce into its "
            f"schema ({payload.get('parsing_error')!r}). It returned: "
            f"{_excerpt(raw)}. The case was not judged; it must not be recorded "
            f"as one that was."
        )

    return StageResponse(value=parsed, cost=_cost_of(payload.get("raw")))


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
    # Deferred deliberately — see the module docstring. This is the line that
    # costs langchain → transformers → torch, and it is paid on first call
    # rather than by every importer of a stage module.
    from ai_common import get_llm

    llm = get_llm(
        model_name=model_params["model"],
        model_provider=model_params["model_provider"],
        api_key=model_params["api_key"],
        model_args=model_params["model_args"],
    )
    return cast(
        "Runnable[LanguageModelInput, StructuredPayload[_SchemaT]]",
        llm.with_structured_output(schema=schema, include_raw=True)
           .with_retry(stop_after_attempt=3),
    )
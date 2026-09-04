"""
The judge's words for a model call — an adapter over :mod:`src.llm`.

This module used to hold the machinery as well: building a structured-output
model, classifying what came back, timing it and logging it. On 2026-08-26 all
of that moved to :mod:`src.llm`, on Bertan's observation that most of it is not
specific to the sufficiency judge and that ``llm_call`` **will be used wherever
a model call is made, including every module under**
:mod:`src.clause_and_effect`. A wrapper both packages must reach cannot live
inside one of them.

What is left is what the judge means rather than what a model does:

``JudgeResponseError``
    The same failure as :class:`~src.llm.call.LlmResponseError`, said in the
    judge's terms — a *case* that was not judged. Kept a distinct type because
    the sample size depends on nobody catching it by accident.
``StageResponse``
    :class:`~src.llm.call.LlmResponse` under the name five stages, two
    aggregators and six probe scripts are typed on.
``require_response`` / ``stage_call``
    The ``stage=`` vocabulary. Both add exactly one thing to the shared tier:
    which of five identically-shaped call sites this was.

**One thing is deliberately no longer identical.** The row the log writes for a
failed call now carries the shared tier's wording, without the ``stage``
prefix and without "the case was not judged" — because ``llm_call`` writes the
row before this module ever sees the exception. Nothing is lost: ``llm_call``
has a ``stage`` column, and putting the stage in the message too would store the
same fact twice and make the column the copy that can drift.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import TYPE_CHECKING, Any, Dict, TypeVar

from pydantic import BaseModel

from src.llm.call import LlmResponse, LlmResponseError, llm_call, require_payload

if TYPE_CHECKING:
    from langchain_core.language_models import LanguageModelInput
    from langchain_core.runnables import Runnable

    from src.llm.structured import StructuredPayload

# The structured-output shape a judge stage returns. Each stage has its own.
_SchemaT = TypeVar("_SchemaT", bound=BaseModel)

# What a stage hands back once it has mapped the schema into a domain type —
# `Decomposition`, `BlindAnswer`, a list of `Claim`.
_ValueT = TypeVar("_ValueT")


class JudgeResponseError(LlmResponseError):
    """
    A stage's model call returned nothing parseable into its schema.

    Everything about *why* this is a distinct exception type is in
    :class:`~src.llm.call.LlmResponseError`, and everything about what it
    carries — the failed call's price, generation id and reasoning tokens — is
    inherited from it. What this subclass adds is the judge's reading of the
    event: **the case was not judged**, and a caller that folds it in with a
    judgement silently shrinks the sample.

    A subclass rather than a separate hierarchy, so that a call site which
    genuinely does not care which tier raised — a probe totalling spend across
    failures, say — can catch the shared type and still see these.
    """


@dataclass(frozen=True)
class StageResponse(LlmResponse[_ValueT]):
    """
    One stage's result, what the calls to produce it cost, and which they were.

    Adds no field to :class:`~src.llm.call.LlmResponse`; it is the same three
    facts under the name the judge's five stages, ``stage_a_twocall.decompose``,
    ``judge.probe_case`` and the probe scripts are written against. The
    reasoning behind each field — why ``cost`` may be ``None`` and why that is
    not ``0.0``, why ``calls`` is a tuple — is on the base class, where the
    product path can read it too.
    """


def require_response(
    payload: "StructuredPayload[_SchemaT] | None", *, stage: str
) -> StageResponse[_SchemaT]:
    """
    Unwrap a stage's structured payload, or raise naming the stage.

    The unwrapping itself is :func:`src.llm.call.require_payload`; this adds the
    stage. The stage label is not decoration — it is the only thing in the
    message that says *which* of five identically-shaped call sites failed, and
    a run that loses a case needs to record which stage lost it.

    Args:
        payload: Whatever ``ainvoke`` returned.
        stage:   Which stage is asking, for the error message.

    Raises:
        JudgeResponseError: if the model returned no parseable structure.
    """
    try:
        response = require_payload(payload)
    except LlmResponseError as exc:
        raise _as_judge_error(exc, stage=stage) from None
    return StageResponse(
        value=response.value, cost=response.cost, calls=response.calls
    )


async def stage_call(
    runnable: "Runnable[LanguageModelInput, StructuredPayload[_SchemaT]]",
    prompt: Any,
    *,
    model_params: Dict[str, Any],
    stage: str,
    metadata: Dict[str, Any] | None = None,
) -> StageResponse[_SchemaT]:
    """
    :func:`src.llm.call.llm_call`, in the judge's vocabulary.

    Everything that happens — the timing, the log row, the four statuses, the
    re-raise of a failure that was still billed — happens down there. This
    exists so the five stage call sites stay one line each and so a stage that
    fails says which stage it was.
    """
    try:
        response = await llm_call(
            runnable,
            prompt,
            model_params=model_params,
            stage=stage,
            metadata=metadata,
        )
    except LlmResponseError as exc:
        raise _as_judge_error(exc, stage=stage) from None
    return StageResponse(
        value=response.value, cost=response.cost, calls=response.calls
    )


def _as_judge_error(exc: LlmResponseError, *, stage: str) -> JudgeResponseError:
    """
    The shared failure, re-worded as a case that was not judged.

    One function rather than two raise sites, because the two paths into it —
    :func:`require_response` and :func:`stage_call` — must not drift into
    saying different things about the same event. ``exc.call`` is carried
    across unchanged: the price and the generation id of a failed call are the
    facts this whole error type exists to stop being dropped.
    """
    return JudgeResponseError(
        f"stage {stage}: {exc} The case was not judged; it must not be "
        f"recorded as one that was.",
        call=exc.call,
    )

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
"""
from __future__ import annotations

from typing import TYPE_CHECKING, Any, Dict, TypeVar, cast

from pydantic import BaseModel

if TYPE_CHECKING:
    from langchain_core.language_models import LanguageModelInput
    from langchain_core.runnables import Runnable

# The structured-output shape a judge stage returns. Each stage has its own.
_SchemaT = TypeVar("_SchemaT", bound=BaseModel)


class JudgeResponseError(RuntimeError):
    """
    A stage's model call returned nothing parseable into its schema.

    ``with_structured_output`` yields ``None`` when the model's output cannot be
    coerced into the requested shape. Observed 2026-08-22 on stage A2, where it
    surfaced as ``AttributeError: 'NoneType' object has no attribute 'claims'``
    from inside a list comprehension — a traceback naming neither the stage nor
    the cause. Every stage had the same shape, because every stage read a field
    straight off the value ``ainvoke`` returned.

    This is a *transport* failure, not a judgement: the case was not judged
    insufficient, it was not judged at all. Keeping it a distinct exception type
    is what lets a caller tell "the judge decided" from "the judge did not
    answer" — a distinction an eval instrument cannot afford to blur, since a
    swallowed one would silently shrink the sample.
    """


def require_response(response: _SchemaT | None, *, stage: str) -> _SchemaT:
    """
    Return the stage's structured response, or raise naming the stage.

    Args:
        response: Whatever ``ainvoke`` returned.
        stage:    Which stage is asking, for the error message.

    Raises:
        JudgeResponseError: if the model returned no parseable structure.
    """
    if response is None:
        raise JudgeResponseError(
            f"stage {stage}: the model returned no output parseable into its "
            f"schema. The case was not judged; it must not be recorded as one "
            f"that was."
        )
    return response


def build_judge_llm(
    model_params: Dict[str, Any],
    schema: type[_SchemaT],
) -> Runnable[LanguageModelInput, _SchemaT]:
    """
    Build a structured-output LLM for one judge stage.

    Args:
        model_params: One entry from :func:`src.llm_config.get_llm_config`.
        schema:       The pydantic shape the stage must return.

    Returns:
        A runnable that yields an instance of ``schema``.

    ``with_structured_output`` is declared as returning ``dict | BaseModel``,
    because it accepts both a dict schema and a pydantic class. Passing a pydantic
    class narrows that at runtime but not in the type system, so the cast is made
    once here rather than at each of the three stage call sites.
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
        "Runnable[LanguageModelInput, _SchemaT]",
        llm.with_structured_output(schema=schema).with_retry(stop_after_attempt=3),
    )
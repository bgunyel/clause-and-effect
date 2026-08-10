"""
Building the structured-output model a judge stage runs on.

The only module in this package that imports ``ai_common``, and therefore the
only one that costs langchain → transformers → torch to import. Keeping it alone
here is what lets :mod:`src.eval.sufficiency.models` and everything derived from
it be tested for free.
"""
from __future__ import annotations

from typing import Any, Dict, TypeVar, cast

from ai_common import get_llm
from langchain_core.language_models import LanguageModelInput
from langchain_core.runnables import Runnable
from pydantic import BaseModel

# The structured-output shape a judge stage returns. Each stage has its own.
_SchemaT = TypeVar("_SchemaT", bound=BaseModel)


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
    llm = get_llm(
        model_name=model_params["model"],
        model_provider=model_params["model_provider"],
        api_key=model_params["api_key"],
        model_args=model_params["model_args"],
    )
    return cast(
        "Runnable[LanguageModelInput, _SchemaT]",
        llm.with_structured_output(schema=schema),
    )
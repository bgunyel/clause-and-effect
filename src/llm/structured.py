"""
Building the structured-output model a call runs on.

The only module in this repository that reaches ``ai_common``, and therefore the
only one that can cost langchain → transformers → torch. Keeping it alone here
is what lets the judge's dataclasses, every stage's prompt builder and all of
their tests be imported for free.

**Alone is not enough — the cost has to be deferred as well as isolated.** Every
stage module imports :func:`build_structured_llm` at module scope, so while this
module paid at import time, so did they, and so did their tests: measured 6.3s
cold for the import, and 2.4s on the test suite. Two imports had to move, not
one. ``get_llm`` goes inside the function; the two ``langchain_core`` names are
needed only by the signature, and ``from __future__ import annotations`` already
makes annotations strings, so they go behind ``TYPE_CHECKING`` and never load at
runtime. Deferring only ``get_llm`` would have bought nothing, because
``langchain_core`` is the leg that pulls torch.

The cost is deferred, not removed: the first call to
:func:`build_structured_llm` pays it. Nothing here is cheaper to *run*, only
cheaper to *import*. Guarded by
``test_importing_a_judge_stage_does_not_load_torch``; re-measure before assuming
either way.

**The channel constants are imported at module scope and that is a change.**
While they lived in ``llm_config`` they had to be deferred like ``get_llm``,
because that module imports ``ai_common.enums`` — 0.24s and 195 modules — to
build its roster. :mod:`src.llm.channels` imports nothing, so the three strings
now cost nothing to name where they are used.
"""
from __future__ import annotations

from typing import TYPE_CHECKING, Any, Dict, Generic, TypeVar, TypedDict, cast

from pydantic import BaseModel, ValidationError

from src.llm.channels import FUNCTION_CALLING, JSON_SCHEMA, TOOL_CALL_AUTO

if TYPE_CHECKING:
    from langchain_core.language_models import LanguageModelInput
    from langchain_core.runnables import Runnable

# The structured-output shape one call returns. Each call site has its own.
_SchemaT = TypeVar("_SchemaT", bound=BaseModel)


class StructuredPayload(TypedDict, Generic[_SchemaT]):
    """
    What ``with_structured_output(..., include_raw=True)`` returns.

    Declared rather than left as an untyped dict because the whole cost
    mechanism rests on the shape: ``parsed`` is what the caller wanted, and
    ``raw`` is the ``AIMessage`` carrying the metadata the parsed object throws
    away. Without ``include_raw`` the chain yields ``parsed`` alone and there is
    no message left to read a price off.

    **This is LangChain's contract, not the judge's**, which is the observation
    that let the whole classification of a failed call move down here: a
    product-path structured-output call fails to coerce in exactly this shape,
    and a shared wrapper that reads it is not duck-typing something defined
    upstairs.
    """

    raw: Any
    parsed: _SchemaT | None
    parsing_error: Any


def payload_from_tool_call(
    message: Any, schema: type[_SchemaT]
) -> StructuredPayload[_SchemaT]:
    """
    Turn one ``bind_tools`` reply into the payload the rest of this tier reads.

    The ``TOOL_CALL_AUTO`` path returns an ``AIMessage`` rather than the
    ``{raw, parsed, parsing_error}`` dict ``with_structured_output(include_raw=
    True)`` produces. Rebuilding that shape here — rather than teaching
    :func:`src.llm.call.require_payload` a second one — is what keeps every call
    site, the error reporting and the cost plumbing identical across the two
    paths. ``raw`` is the same message either way, so reading a cost off it
    needs no branch.

    **A missing tool call is a failure, and specifically not an empty result.**
    ``tool_choice="auto"`` permits the model to answer in prose instead of
    calling the tool, which the forced path makes impossible. Stage A2 may
    legitimately return *zero claims* (design §4.5: a gold answer that does not
    answer its own question), so if silence were mapped to an empty list the two
    would be indistinguishable — a case nobody judged would be recorded as a case
    judged to have no core content. It is reported as ``parsed: None`` instead,
    which :func:`src.llm.call.require_payload` turns into an
    :class:`~src.llm.call.LlmResponseError`.

    The first tool call is taken. Only one tool is ever bound, so a second would
    mean the model called the same schema twice; that is not a shape any caller
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


def build_structured_llm(
    model_params: Dict[str, Any],
    schema: type[_SchemaT],
) -> Runnable[LanguageModelInput, StructuredPayload[_SchemaT]]:
    """
    Build a structured-output LLM for one model call.

    Named ``build_judge_llm`` until 2026-08-26, when it moved out of the judge.
    Nothing about it judges: it reads a config entry and a pydantic class and
    returns a runnable, and the product path needs exactly the same thing.

    Args:
        model_params: One entry from :func:`src.llm_config.get_llm_config`.
        schema:       The pydantic shape the call must return.

    Returns:
        A runnable that yields a :class:`StructuredPayload` — the parsed schema
        *and* the message it was parsed from. Callers pass it to
        :func:`src.llm.call.llm_call` rather than reading it directly.

    **``include_raw=True`` is what makes the call auditable.** Without it the
    chain returns the parsed object alone, the ``AIMessage`` is dropped inside
    the chain, and with it goes ``response_metadata`` — where the provider puts
    the price of the call and the token counts. An eval instrument that cannot
    say what a run cost cannot be budgeted, and the panel (§8) multiplies every
    case by the number of members.

    ``with_structured_output`` is declared as returning ``dict | BaseModel``,
    because it accepts both a dict schema and a pydantic class. Passing a pydantic
    class narrows that at runtime but not in the type system, so the cast is made
    once here rather than at each call site.
    """
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
        # same `raw` message — so the cost plumbing and `require_payload` need
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
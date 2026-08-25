"""
Which models each role runs on, and with what parameters.

Split out of ``src/config.py`` on 2026-08-09. The two modules answer different
questions — ``config.py`` says *where things are* (paths, URLs, keys) and this
one says *which LLM to build* — but the split is not about tidiness. It is about
what importing them costs.

``get_llm_config`` needs ``LlmServers`` and ``ModelNames`` from ``ai_common``,
and importing ``ai_common`` at module scope pulls its whole surface: ``.llm``
imports six langchain provider SDKs, langchain_core imports ``transformers`` for
a fallback token counter, and transformers imports ``torch``. Measured at the
time of the split, ``import src.config`` cost **8.34s**; without that line,
**0.21s**.

Eight modules import ``src.config``, and only the two that actually talk to an
LLM ever call this function. Leaving both in one module made every script —
chunk generation, corpus generation, the docling exporters, indexing — load
torch to read two directory paths.

Keeping this separate makes that structural. A lazy import inside
``get_llm_config`` would have bought the same seconds, but nothing would stop
the next edit hoisting it back to the top; a module boundary is not something
you undo by accident. See ``docs/todo.md`` for the ``ai_common`` side, which is
where the cost actually originates.
"""
from typing import Any, Dict, List

from ai_common.enums import LlmServers, ModelNames

from src.config import get_settings

# How a model is asked to return its schema, read by
# :func:`src.eval.sufficiency.llm.build_judge_llm`.
#
# The default — an entry whose ``structured_output`` is ``None`` — is
# ``with_structured_output``, which pins ``tool_choice`` to the schema's own
# function so the model cannot decline to fill it. ``TOOL_CALL_AUTO`` selects
# ``bind_tools(..., tool_choice="auto")`` instead, for a model that rejects that
# pinning.
TOOL_CALL_AUTO = 'tool_call_auto'

# ``with_structured_output(method="json_schema")``, which binds
# ``response_format={"type": "json_schema", ...}`` instead of sending tools.
#
# This is what the panel runs on. Function calling was the default and it failed
# unevenly across the roster: MiniMax M3's OpenRouter endpoint does not accept
# tools at all, so it answered in the schema's *shape* as prose and scored 2/6;
# Kimi K3 did the same on 2 of 6; Grok emitted the tool call as a fenced JSON
# block. Measured 2026-08-23 on the three cases MiniMax had failed, `json_schema`
# returned all three — including `art15_case1`'s ten core claims, which is §4.6's
# expected output exactly.
JSON_SCHEMA = 'json_schema'

# ``with_structured_output()`` as it comes — tools plus a pinned ``tool_choice``.
# The library's own default; named here so every panelist's channel is stated in
# the table below rather than half of them being an absence.
FUNCTION_CALLING = 'function_calling'


def get_llm_config():
    settings = get_settings()

    llm_names = {
        'sufficiency_judge': [
            ModelNames.DEEPSEEK_V_4_FLASH_0731,
            ModelNames.DEEPSEEK_V_4_PRO_0813,
            ModelNames.GEMINI_3_7_FLASH,
            # ModelNames.GLM_5_3 — callable, and too slow to be a panelist.
            # `TOOL_CALL_AUTO` below fixed its structured output: it answers the
            # roster probe's trivial prompt correctly in 18s. On a real stage A2
            # prompt it then **timed out on all six baseline cases at 120s
            # each** (2026-08-23 panel run), contributing nothing while stalling
            # every case behind it — the whole panel had previously sat for 19
            # minutes with no per-call deadline. The `structured_output` entry is
            # kept, so re-adding the model needs no rediscovery.
            ModelNames.GROK_4_6,
            ModelNames.KIMI_K3,
            ModelNames.MINIMAX_M_3,
            ModelNames.QWEN_3_8_27B,
            ModelNames.QWEN_3_8_2_4T_A95B,
        ],
        'writer_model': [
            ModelNames.DEEPSEEK_V_4_FLASH_0731,
        ]
    }

    # Every model above is served through OpenRouter, so the provider is a
    # constant rather than a per-model field.
    #
    # **A model without an OpenRouter alias cannot be caught here.** Checking one
    # means `get_model_name_alias`, which lives in `ai_common.llm` — the module
    # this file exists to keep out of the import graph. Measured 2026-08-23:
    # `ai_common.enums` costs 0.24s and 195 modules, `ai_common.llm` a further
    # **6.58s and 3,000 more**. Validating the list here would put that on every
    # importer of `src.config`, which is the whole cost the 2026-08-09 split
    # removed. The failure surfaces at `get_llm` instead, as
    # `KeyError: <LlmServers.OPENROUTER>`.
    #
    # It has happened: `ModelNames.GPT_OSS_120B` sat in this dict and raised
    # exactly that on construction, removed 2026-08-10. The model was never the
    # problem — it has `GROQ` and `OLLAMA` aliases and ran fine on `OLLAMA` at
    # 2638b52. The wholesale switch to OpenRouter (6ccd193) moved it to a
    # provider it has no alias for. Before adding a panelist, check the alias
    # dict for the *provider*, not just the model.
    provider = LlmServers.OPENROUTER
    api_key = settings.OPENROUTER_API_KEY

    # Every panelist runs on the same settings, so that a disagreement between
    # two of them is a disagreement about the case rather than about the
    # sampling. `temperature: 0` does not make a model deterministic — four
    # samples of stage A2 have disagreed with each other — it removes one source
    # of variance and leaves the rest visible.
    model_args = {
        'temperature': 0,
        'reasoning_effort': 'high',
        'top_p': 0.95,
        # OpenRouter routes one model id to whichever upstream provider it
        # picks, and **support for the parameters we send varies between them**
        # for the same model. Without this, a provider that does not implement
        # `response_format` may be chosen and simply ignore it: the call
        # succeeds, is billed, and comes back as prose. `require_parameters`
        # restricts routing to providers that honour what was sent, turning
        # silent degradation into an explicit routing failure.
        #
        # This is a candidate explanation for the roster's unexplained
        # intermittency — Grok answered 4 of 6 in one panel run and 6 of 6 in
        # the next with no change on our side.
        #
        # It reaches the request through `model_kwargs`: `get_llm` pops
        # `temperature`, `top_p` and `reasoning_effort` and hands the rest to
        # `ChatOpenRouter(model_kwargs=...)`, whose `_default_params` spreads
        # them into the body. `provider` is the body's own field name — the
        # constructor spells it `openrouter_provider`, which `get_llm` does not
        # pass, so nothing overwrites this.
        'provider': {'require_parameters': True},
    }

    # How a model is asked to return its schema, where the default does not work.
    #
    # `build_judge_llm` uses `with_structured_output`, which pins `tool_choice`
    # to the schema's own function so the model cannot decline to fill it.
    # OpenRouter's `z-ai/glm-5.3` rejects that outright —
    # `BadRequestResponseError: Tool choice must be auto` — while serving
    # perfectly well otherwise. Measured 2026-08-23: a plain `invoke` works and
    # reports cost; `method="json_schema"` is accepted but *unenforced*, so the
    # model answers in prose and the parser raises; `json_mode` is not
    # implemented by `langchain_openrouter` and silently falls back to the same
    # failure. `bind_tools([schema], tool_choice="auto")` works — three runs,
    # correct arguments every time, cost on the raw message.
    #
    # The cost of that path is that `auto` lets the model answer without calling
    # the tool at all, which the forced path makes impossible. That is handled
    # where it has to be: `payload_from_tool_call` reports a missing tool call as
    # a transport failure rather than as an empty claim list, because stage A2
    # returning *no core claims* is a legitimate verdict and must stay
    # distinguishable from a case nobody judged.
    #
    # Listed per model rather than sniffed at build time, so which panelist is
    # being called differently is visible here rather than inside a fallback.
    #
    # **Neither channel works for every model, so each is assigned its own.**
    # Measured over the six §4.6 cases, cases answered out of 6:
    #
    # | model | function_calling | json_schema | assigned |
    # |---|---|---|---|
    # | DeepSeek V4 Flash | 6/6, 6/6 @ ~7s | **3/6**, 3 timeouts @ 63s | function_calling |
    # | DeepSeek V4 Pro | 6/6, 6/6 @ ~25s | 6/6 @ 41s | function_calling |
    # | Gemini 3.7 Flash | 6/6, 6/6 @ ~10s | 6/6 @ 12s | function_calling |
    # | Qwen 3.8-27B | 6/6, 6/6 | 6/6 | function_calling |
    # | Qwen 3.8-2.4T | 6/6, 6/6 | 6/6 | function_calling |
    # | Grok 4.6 | 4/6, 6/6 | 6/6 | json_schema |
    # | Kimi K3 | 3/6, 4/6 | 6/6 | json_schema |
    # | MiniMax M3 | 2/6, 6/6 | 6/6 | json_schema |
    #
    # Two assignments rest on a mechanism and the rest on counts. **MiniMax's
    # OpenRouter endpoint does not accept tools at all** (their documentation),
    # which is why it answered in the schema's shape as prose — it was never a
    # judgement failure. **DeepSeek V4 Flash is the mirror image**: it is the
    # cheapest and fastest panelist on tools and times out under
    # `response_format`, 63s mean against 7s.
    #
    # **This costs the uniformity this config otherwise keeps.** Everything else
    # here is deliberately identical across panelists so that a disagreement is
    # about the case rather than the sampling, and a per-model channel weakens
    # exactly that. It is accepted because the alternative is worse — a uniform
    # channel means some panelist is being scored on calls it never had a fair
    # chance to answer. The risk to watch is that the channel changes more than
    # the wire format: MiniMax reported **zero reasoning tokens** under
    # `json_schema` while producing `reasoning_content` on the tool path, and if
    # `response_format` suppresses reasoning then those three panelists judge
    # without the budget the other five get. Unquantified, and it should be.
    #
    # Counts are one run per model per channel. Grok read 4/6 then 6/6 on
    # *identical* function-calling runs, so the single-sample rows are weaker
    # evidence than they look.
    structured_output = {
        ModelNames.DEEPSEEK_V_4_FLASH_0731: FUNCTION_CALLING,
        ModelNames.DEEPSEEK_V_4_PRO_0813: FUNCTION_CALLING,
        ModelNames.GEMINI_3_7_FLASH: FUNCTION_CALLING,
        ModelNames.GLM_5_3: TOOL_CALL_AUTO,
        ModelNames.GROK_4_6: JSON_SCHEMA,
        ModelNames.KIMI_K3: JSON_SCHEMA,
        ModelNames.MINIMAX_M_3: JSON_SCHEMA,
        ModelNames.QWEN_3_8_27B: FUNCTION_CALLING,
        ModelNames.QWEN_3_8_2_4T_A95B: FUNCTION_CALLING,
    }

    llm_config = {
        role: [
            {
                'model': model,
                'model_provider': provider,
                'api_key': api_key,
                'max_llm_retries': 3,
                # No default: a model absent from the table above is a model
                # whose channel nobody chose, and `build_judge_llm` refuses it
                # rather than guessing. Adding a panelist should require the one
                # measurement that says how to call it.
                'structured_output': structured_output[model],
                # A fresh copy per entry, and this is load-bearing rather than
                # defensive: `ai_common.get_llm` *mutates* the dict it is given
                # for Google models — it forces `temperature` to 1.0 on gemini-3
                # and pops `reasoning` into `thinking_level`. One shared dict
                # would let building the Gemini panelist silently rewrite the
                # sampling of every other model in this config.
                'model_args': dict(model_args),
            }
            for model in models
        ]
        for role, models in llm_names.items()
    }

    return llm_config

def panelist(entries: List[Dict[str, Any]], model: ModelNames) -> Dict[str, Any]:
    """
    The config entry for a named model, from one role's roster.

    **Use this instead of indexing.** `get_llm_config()['sufficiency_judge'][0]`
    appears at ten call sites, and every one of them makes the subject of a
    measurement a consequence of where a model happens to sit in `llm_names` —
    a list nobody reads as ordered. Reordering it, or inserting a panelist at the
    front, silently repoints every one of those probes while their reports go on
    saying exactly what they said before. The four A2 stability samples are the
    concrete risk: they are only comparable to each other if they measured the
    same model, and nothing in them recorded a reason to believe that beyond the
    model name in the header.

    Raises rather than falling back when the model is not in the roster. A probe
    whose model has been dropped should stop and say so; measuring its neighbour
    and reporting the result under the same title is the failure this exists to
    prevent.

    Takes the entries rather than fetching them, so the lookup is a pure
    function of the roster and needs no settings to test.
    """
    for entry in entries:
        if entry["model"] == model:
            return entry
    available = ", ".join(str(e["model"]).split(".", 1)[-1] for e in entries)
    raise KeyError(
        f"{str(model).split('.', 1)[-1]} is not in this roster. Available: "
        f"{available}. A probe pinned to a model that has left the roster must "
        f"stop rather than measure a different one."
    )

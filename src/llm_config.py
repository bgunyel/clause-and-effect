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
from ai_common.enums import LlmServers, ModelNames

from src.config import get_settings


def get_llm_config():
    settings = get_settings()

    llm_names = {
        'sufficiency_judge': [
            ModelNames.DEEPSEEK_V_4_FLASH_0731,
            ModelNames.DEEPSEEK_V_4_PRO_0813,
            ModelNames.GEMINI_3_7_FLASH,
            ModelNames.GLM_5_3,
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
    }

    llm_config = {
        role: [
            {
                'model': model,
                'model_provider': provider,
                'api_key': api_key,
                'max_llm_retries': 3,
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
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

    llm_config = {
        'orchestrator_model': [
            {
                'model': ModelNames.DEEPSEEK_V_4_FLASH,
                'model_provider': LlmServers.OPENROUTER,
                'api_key': settings.OPENROUTER_API_KEY,
                'max_llm_retries': 3,
                'model_args': {
                    'temperature': 0,
                    'reasoning_effort': 'high',
                    'top_p': 0.95,
                }
            },

        ],
        # NOTE: entry [1] is currently broken — `ModelNames.GPT_OSS_120B` has no
        # OpenRouter alias in `ai_common`'s `MODEL_NAME_ALIAS_DICT` (groq and
        # ollama only), so `get_llm` raises
        # `KeyError: <LlmServers.OPENROUTER>` on construction. Found 2026-08-05.
        # Tracked in docs/todo.md; entry [0] is the one in use.
        'writer_model': [
            {
                'model': ModelNames.DEEPSEEK_V_4_FLASH,
                'model_provider': LlmServers.OPENROUTER,
                'api_key': settings.OPENROUTER_API_KEY,
                'max_llm_retries': 3,
                'model_args': {
                    'temperature': 0,
                    'reasoning_effort': 'high',
                    'top_p': 0.95,
                }
            },
            {
                'model': ModelNames.GPT_OSS_120B,
                'model_provider': LlmServers.OPENROUTER,
                'api_key': settings.OPENROUTER_API_KEY,
                'max_llm_retries': 3,
                'model_args': {
                    'temperature': 0,
                    'reasoning_effort': 'high',
                    'top_p': 0.95,
                }
            },
        ]

    }

    return llm_config
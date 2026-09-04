"""
The shared model-call tier: what every caller of an LLM in this repository uses.

Both halves of the project make model calls — the product path under
:mod:`src.clause_and_effect` and the judge under :mod:`src.eval.sufficiency` —
and until 2026-08-26 the machinery for making one lived inside the judge. That
placement was wrong in a way that showed: the product path would have had to
import from ``src/eval/sufficiency/`` to build a structured-output model, and
the synchronous flavour of the call wrapper had nowhere to sit while its async
twin was inside the judge.

The test applied when splitting was **does this encode a fact about LangChain
and OpenRouter, or a fact about the judge?** Everything here is the first kind.
The judge keeps its own vocabulary — ``StageResponse``, ``JudgeResponseError``,
the ``stage=`` labels — in :mod:`src.eval.sufficiency.llm`, which is now a thin
adapter over this tier.

Layout
------
=================  =========================================================
module             holds
=================  =========================================================
``channels``       how a model is asked to return a schema; three constants
``structured``     ``build_structured_llm``, ``StructuredPayload`` — the only
                   ``ai_common`` touchpoint, and the only expensive import
``call``           ``llm_call`` — invoke, time, log, unwrap; ``CallRecord``,
                   ``LlmResponse``, ``sum_costs``
=================  =========================================================

**This file exports nothing**, for the reason
:mod:`src.eval.sufficiency` gives at greater length and one this tier makes
sharper. Python runs a package's ``__init__`` before any submodule of it, so a
re-export here would make ``import src.llm.channels`` — three strings, and the
cheapest thing in the repository — pull :mod:`src.llm.structured` and, on its
first call, ``ai_common`` → langchain → transformers → torch. Import by module
path::

    from src.llm.channels import JSON_SCHEMA
    from src.llm.structured import build_structured_llm
    from src.llm.call import llm_call, sum_costs
"""
"""
Answer-vs-quote sufficiency — the judge-tier gate on the golden set (plan §7.3).

:mod:`src.eval.golden_qa` checks **provenance**: that a ``supporting_quote`` is a
substring of its source article. This package checks **sufficiency**: that the
quote actually answers its question. The two properties are uncorrelated.
``art2_case4`` grounds *exact* and clears every deterministic gate, yet its quote
is a verbatim fragment of Article 2 that never contains the negation its answer
asserts — perfect provenance, zero sufficiency.

Sufficiency is semantic, so it is judged, not measured. That is why it lives here
rather than in :mod:`src.eval.golden_qa`, which stays free, deterministic and
runnable on every change.

The criterion
-------------
**Every question must be answerable using only its ``supporting_quote``.**

Deliberately the weaker of the two candidate readings — *not* "the gold ``answer``
is entailed by the quote". Auxiliary claims in a gold answer may run beyond what
its quote carries; only **core** claims must be quote-supported. Sufficiency is
also two-sided: a quote that cannot answer its question is **useless**, while one
carrying far more than the question needs is **not useless but devalued**, so
stage B returns the minimal sufficient span and the same pass yields the repair
rather than only the diagnosis.

The protocol — three stages, each blinded to what would let it rationalize
------------------------------------------------------------------------
=========  ==============================  ===========================
stage      sees                            blind to
=========  ==============================  ===========================
A          question, gold ``answer``       the quote
B          question, ``supporting_quote``  gold answer, source article
C          question, claims, blind answer  the quote
=========  ==============================  ===========================

Each blinding is structural rather than instructed: a stage's prompt builder
interpolates only the fields that stage may see, and a prompt cannot leak what it
was never given. Each panel member runs A→B→C independently and votes, so
disagreement is a calibration signal rather than noise to be averaged away.

**No verdict from this package gates anything.** Judge–human agreement is
unmeasured until the calibration step exists (§6.2 makes it mandatory), and
verdict derivation and the panel runner are not built. Stage C labels claims and
deliberately stops there: turning those labels into a verdict is deterministic,
needs no model call, and is a separate piece. Stages A and B have
tests as of 2026-08-17 (``tests/test_sufficiency_stages.py``), but they pin the
stages' *wiring* — the blinding, the response mapping, ``span_is_verbatim`` —
and say nothing about whether the judge's tagging or blind answers are any good.
That is calibration, and it is still the thing standing between this package and
gating anything.

Full reasoning, the evidence behind each design choice, and the known gaps:
``docs/design/sufficiency-judge.md``. Per-stage rationale lives beside each
stage's prompt, so the explanation cannot drift from the thing it explains.

Layout, and what this file deliberately does not do
---------------------------------------------------
=================  =========================================================
module             holds
=================  =========================================================
``models``         the dataclasses and literals every stage returns
``llm``            the judge's words for a model call — an adapter over
                   :mod:`src.llm`
``stage_a``        decompose: instructions, schemas, prompt builder, call
``stage_b``        answer blind: as above, plus ``span_is_verbatim``
``stage_c``        adjudicate: as above, and the claim/verdict mapping
``judge``          the driver; verdict derivation and the panel go here
=================  =========================================================

**This file exports nothing.** Import by module path::

    from src.eval.sufficiency.models import Decomposition, Verdict
    from src.eval.sufficiency.stage_a import decompose
    from src.eval.sufficiency.stage_b import answer_blind, span_is_verbatim

Two reasons, and the second one **has since been paid off elsewhere**. A
re-export is a claim that something is part of a public surface, and nothing
outside this package imports it yet, so every such claim today would be a guess —
the surface is decided when there is a caller to decide it for. That reason
stands unchanged.

The second was cost. Python runs a package's ``__init__`` before any submodule of
it, so re-exporting the stages here made even ``import
src.eval.sufficiency.models`` pull the module that reached ``ai_common``, and
with it langchain → transformers → torch: this file did re-export them for one
revision, and importing the dataclasses cost **7.7s**.

**That is no longer what a re-export would cost.** On 2026-08-17 the heavy
imports were deferred — ``get_llm`` into the function body, the two
``langchain_core`` names behind ``TYPE_CHECKING`` — so the module cost 0.11s and
loaded no torch, and on 2026-08-26 the ``ai_common`` touchpoint left this package
altogether for :mod:`src.llm.structured`. A re-export here would now be cheap at
import time and would pay only on the first ``build_structured_llm`` call. The
honest statement is therefore that **the argument above is now one reason, not
two**, and the surviving reason is the one about public surfaces. Re-measure
before assuming either way; the guard that keeps this true is
``test_importing_a_judge_stage_does_not_load_torch``.
"""
# Clause & Effect — TODO

> Working backlog. Captures the three explicitly-requested items plus the
> outstanding work surfaced while diagnosing the `gdpr_articles.json` truncation
> bug and standing up the eval framework + test suite.
>
> _Last updated: 2026-07-23._

---

## 🔴 Blocking — data integrity

The vector index is currently built from a corrupted source (76/99 articles were
silently truncated at their first inline "Article N" cross-reference). No eval
number should be trusted until this chain is redone, **in order**:

- [ ] **Re-generate `gdpr_articles.json`** _(requested)_
  - Run `python -m src.scripts.generate_gdpr_articles`.
  - Spot-check the articles the script flags, and the previously worst-hit ones
    (27, 8, 56, 46, 94, 97).
  - Confirm titles look right — the rewritten parser assumes each article's
    title is the **first line after** its `Article N` header. If docling emits
    the heading _before_ the number, titles will be wrong; flag it and we adjust.
- [ ] Re-chunk → re-embed → re-index Qdrant from the corrected JSON
  (`python -m src.scripts.index_documents`). Incurs OpenAI embedding + Qdrant
  upsert cost.
- [ ] Re-run golden-set QA (`python -m src.eval.golden_qa`) against the corrected
  source and measure how many of the 246 quote-grounding errors were **caused by
  the truncation bug** vs. genuine golden-set defects.

---

## 🟠 Repo hygiene

- [ ] Commit the pending work — parser fix + `generate_gdpr_articles.py`, and the
  new `tests/` suite + pytest config. Likely two commits (parser-fix vs.
  test-suite) for a clean history.

---

## 🟡 Tooling

- [ ] **Modify the Makefile for safe dependency upgrades** _(requested)_
  - Fix `TEST_DIRECTORY` — it points at `src/tests/`, but the suite now lives at
    `tests/` (repo root). `make test` currently runs nothing.
  - Gate `upgrade-safe` on the **test suite**, not only security scans: after
    `uv lock --upgrade` and the OSV + GuardDog tiers pass, run `make test` and
    revert `uv.lock` (restore `uv.lock.preupgrade`) if tests fail. Today a
    dependency bump can be functionally broken yet still pass the gate.
  - Consider applying the 7-day `--exclude-newer` quarantine inside
    `upgrade-safe` too, not just the blind `upgrade` target.
- [ ] **Prepare a comprehensive test-status document** _(requested)_
  - Coverage map: **tested** — GDPR parser extraction, eval dataset loaders, eval
    golden-QA gates. **Untested** — `vector_db`, `generator`, `compliance_agent`,
    `embedding_generator`, and the retrieval/lexical scorers (once built).
  - State the testing philosophy explicitly: deterministic plumbing → unit tests
    (cheap regression tripwire, plan §6.1); LLM/RAG behaviour → eval harness.
  - Record how to run (`python -m pytest`) and current status (33 passed,
    1 xfailed).

---

## 🟢 Golden-set remediation (plan §7.3)

- [ ] Decide the quote-grounding definition: strict exact-substring vs. a
  **token-subsequence** tolerance (the generator dropped enumeration markers like
  `2. ` / `(a)` when stitching quotes across paragraphs). If we relax it, add a
  "subsequence" grounding tier to `golden_qa` rather than silently loosening
  "exact".
- [ ] Fix/regenerate the **17 true leakage questions** that name their own article
  (e.g. "What does Article 14 require…"). Full list in the `golden_qa` output.
- [ ] Leakage check: add an allow-list for the **"Article 29 Working Party"**
  proper noun — currently the lone false positive, tracked as an `xfail` in
  `tests/test_eval_golden_qa.py`.

---

## 🔵 Eval P0 build-out (plan §11 — Foundations)

- [ ] Deterministic **retrieval scorers**: Context Recall (Hit@k), Context
  Precision, Rank (MRR / nDCG), Score Separation — reported as a function of
  `top_k ∈ {1, 3, 5, 10}`.
- [ ] Deterministic **lexical scorers**: Key-Phrase Coverage, Citation
  article-match.
- [ ] **Run harness + manifest**: record git SHA, eval-set version, model IDs
  (generator, embedder, judge), `top_k`, timestamp; append-only results history
  keyed by SHA + set version (plan §6.3, §8.3).
- [ ] **Operational metrics**: latency + cost-per-query (wire
  `calculate_token_cost` from `ai_common`).
- [ ] Every new scorer lands **with its unit test** in `tests/`.

---

## ⚪ Known code issues

- [ ] `Generator.generate` (`src/clause_and_effect/generators/generator.py`)
  computes `structured_response` but never uses it, and `total_tokens` is dead.
  Token/cost accounting is not wired — needed for the operational cost metric
  above.
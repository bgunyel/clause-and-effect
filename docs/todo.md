# Clause & Effect — TODO

> Working backlog. Captures the three explicitly-requested items plus the
> outstanding work surfaced while diagnosing the `gdpr_articles.json` truncation
> bug and standing up the eval framework + test suite.
>
> _Last updated: 2026-08-01._

---

## 🔴 Blocking — data integrity

The corpus has been rebuilt and re-indexed. One step remains before any eval
number means anything.

- [x] **Re-generate `gdpr_articles.json`** _(requested)_ — done 2026-08-01.
  Regenerating first exposed two further parser defects, both now fixed
  (`9ecdf6f`); the full post-mortem is in
  [`lessons-learned/2026-08-01-gdpr-article-header-collapse.md`](lessons-learned/2026-08-01-gdpr-article-header-collapse.md).
  - The boundary regex required a bare `Article N` line, but docling emits
    `## Article N` for 98 of 99 headers (bare for Article 28 only), so the
    whole regulation collapsed into a single 137k-char article.
  - `_clean_content` stopped stripping trailing headings at the first blank
    line, leaking chapter scaffolding into 22 articles' content.
  - Title assumption **confirmed**: the line after each header is the title,
    emitted as `## <Title>`. No adjustment needed.
  - Result: 99 articles, numbered 1–99, no gaps. Content 81,928 → **187,323
    chars**; 67 of 99 articles materially longer. Only article 99 is flagged by
    the truncation heuristic — a false positive (signature block, no terminal
    punctuation).
- [x] Re-chunk → re-embed → re-index Qdrant from the corrected JSON — done
  2026-08-01. `compliance_docs` recreated (1536-dim, cosine), **563/563 points**
  verified. Point IDs are now keyed by `uuid5(namespace, chunk.id)` (`7f42ea5`),
  so re-indexing is idempotent and no longer needs the collection dropped first.
- [x] Re-run golden-set QA (`python -m src.eval.golden_qa`) and measure how many of
  the 246 quote-grounding errors were **caused by the truncation bug** vs. genuine
  golden-set defects — done 2026-08-02. Full report:
  [`eval-reports/2026-08-02-golden-set-qa-baseline.md`](eval-reports/2026-08-02-golden-set-qa-baseline.md).
  - **246 → 151** quote-grounding errors; **95 (38.6%) were truncation artifacts**.
    Warnings collapsed 176 → 2. Both ends measured, not remembered — the pre-fix
    number was reproduced by running the gate against `bc63974^`.
  - Of the 151 remaining: 96 stitched, 18 typography, 17 ellipsis, **20 genuinely
    unsupported**. So **86.8% are recoverable by a subsequence/elision tier** and
    only 20 cases need hand remediation.
  - Leakage unchanged at 18 (17 genuine + the Article 29 Working Party false
    positive) — a useful control, since a corpus fix cannot affect question text.
  - Gate still **FAILs**, which is correct. Do not relax it to go green.
  - Correction: this run costs **nothing**. The module is fully deterministic; the
    LLM-judge gates are P1 and explicitly not implemented in it.

> ⚠️ **Every eval number recorded before 2026-08-01 is void.** The corpus content
> more than doubled and 22 articles shed foreign chapter text, so pre-fix results
> are not comparable to anything measured after. Re-establish the baseline from
> the corrected index before comparing chunking or embedding experiments.

---

## 🟠 Repo hygiene

- [x] Commit the pending work — parser fix + `generate_gdpr_articles.py`, and the
  new `tests/` suite + pytest config. Likely two commits (parser-fix vs.
  test-suite) for a clean history.
- [x] Open the PR from `dev-01` into `main` — done 2026-08-02.
  [#1](https://github.com/bgunyel/clause-and-effect/pull/1), 18 commits, merged
  with a merge commit (`3088d45`) so the split between the parser fix and the
  corpus data commit stays reviewable. Carried the eval framework, test suite,
  parser fix, corpus regeneration, point-ID rework, and lessons-learned docs.
  Eval development continues on `dev-02`.

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
  - Coverage map: **tested** — GDPR parser extraction (incl. against the real
    docling export), `vector_db` point-ID derivation and indexing invariants,
    eval dataset loaders, eval golden-QA gates. **Untested** — `generator`,
    `compliance_agent`, `embedding_generator`, and the retrieval/lexical scorers
    (once built).
  - State the testing philosophy explicitly: deterministic plumbing → unit tests
    (cheap regression tripwire, plan §6.1); LLM/RAG behaviour → eval harness.
  - Record how to run (`python -m pytest`) and current status (52 passed,
    1 xfailed).
  - Carry over the lesson from the header-collapse post-mortem: fixtures written
    from the same assumption as the code only prove self-consistency. Where a
    real artifact can be captured and committed, test against it.

---

## 🟢 Golden-set remediation (plan §7.3)

- [ ] Decide the quote-grounding definition: strict exact-substring vs. a
  **token-subsequence** tolerance (the generator dropped enumeration markers like
  `2. ` / `(a)` when stitching quotes across paragraphs). If we relax it, add a
  "subsequence" grounding tier to `golden_qa` rather than silently loosening
  "exact". **Now evidence-backed** (2026-08-02 report): a tiered check recovers
  **131 of 151** remaining errors — 96 stitched (mostly 2–4 spans), 18 typography,
  17 explicit `...` elision. Suggested tiers: `exact` → `typography` →
  `elided` → `stitched` → `unsupported`.
- [ ] Fix or remove the **20 genuinely unsupported quotes** (list in the report).
  Not one batch: `art61_case5` is off by an inflection (`expenditures`), while
  `art41_case3` has 11 consecutive absent tokens and looks invented.
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

## 🟣 Chunking & embedding rework (planned)

Upcoming experimentation with different chunking strategies and embedding
models. Corpus-formatting fixes that would require a full regeneration are
deliberately deferred into this work rather than done piecemeal.

- [ ] Deferred: `_clean_title` does not collapse OCR double-spacing the way
  `_clean_content` does, so 3 of 99 titles (articles **12, 60, 89**) keep runs of
  multiple spaces. Titles are embedded into every chunk of their article, so
  **27 of 563** indexed chunks carry it. Low impact on semantic retrieval, but
  the planned lexical scorers do string comparison and may false-flag these.
- [ ] Deferred (found 2026-08-02): **OCR soft-hyphen breaks** — 18 occurrences of
  U+00AD + space across **14 of 99 articles** (4, 9, 14, 30, 36, 42, 43, 44, 45,
  46, 49, 50, 58, 80), e.g. `internat­ ional`, `certifi­ cation`,
  `jurisdic­ tional`. The docling export carries 39; 18 survive into article
  content. Each splits one word into two meaningless tokens in the embedded text,
  and the lexical scorers will miss them outright. Same class as the title
  whitespace issue above — strip `­\s*` during parsing when the corpus is
  next regenerated.
- [ ] Establish the corrected-corpus baseline (golden-set QA above) *before*
  running experiments, so strategies are compared against a valid reference.

---

## ⚪ Known code issues

- [ ] `Generator.generate` (`src/clause_and_effect/generators/generator.py`)
  computes `structured_response` but never uses it, and `total_tokens` is dead.
  Token/cost accounting is not wired — needed for the operational cost metric
  above.
- [ ] `generate_gdpr_articles.py` has no corpus-level invariant: it printed
  `✅ Wrote 1 articles` and exited 0 while the corpus was collapsed. Assert the
  expected article count (99) and exit non-zero on mismatch.
- [ ] `_looks_truncated` false-flags article 99 (signature block). Either teach
  it about document trailers or decide whether that block belongs in article
  content at all — currently it makes a clean validation run impossible, so any
  future flag is easy to dismiss.
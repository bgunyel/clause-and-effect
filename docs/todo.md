# Clause & Effect — TODO

> Working backlog. Captures the three explicitly-requested items plus the
> outstanding work surfaced while diagnosing the `gdpr_articles.json` truncation
> bug and standing up the eval framework + test suite.
>
> _Last updated: 2026-08-02._

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
  - **246 → 151** quote-grounding errors; **95 (38.6%) were false failures caused
    by the truncated corpus, not eval-set defects** — those test cases were correct
    all along, and the article text they quoted had been cut short. Warnings
    collapsed 176 → 2. Both ends measured, not remembered — the pre-fix number was
    reproduced by running the gate against `bc63974^`.
  - Per-case transition: **95 resolved, 0 introduced, no regressions.**
  - After the soft-hyphen fix (same day) errors are **148**, clean cases **270**.
    After tier-5 normalization landed in `golden_qa.py`: **136 errors, 14
    normalized, 283 exact, 282 clean**. After fixing the `art60_case2` and
    `art80_case2` quotes: **134 errors, 285 exact, 284 clean**.
  - Of the 134 remaining (segment order enforced): **76 faithful elision**,
    **37 text altered** (reordered/reworded), **20 text absent**, **1 inserted
    punctuation**. Every one is now a statement about the quote's *words*, not its
    formatting. **58 need the quote rewritten**; the 76 elision cases would be
    covered by a multi-span `supporting_quote`. An earlier revision of this entry
    claimed 86.8% recoverable; that classifier did not require segments to advance
    in order and so counted reordered quotes as faithful stitching.
  - Leakage held at 18 through every corpus and measurement change — a useful
    control, since none of them can affect question text. It moved to **17** only
    when `art94_case3` was reworded, which also emptied the false-positive category.
  - **Final state: 285 exact, 14 normalized, 134 ungrounded, 17 leakage, 285 clean
    of 433. Gate FAIL.**
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
  - Record how to run (`python -m pytest`) and current status (64 passed,
    1 xfailed).
  - Carry over the lesson from the header-collapse post-mortem: fixtures written
    from the same assumption as the code only prove self-consistency. Where a
    real artifact can be captured and committed, test against it.

---

## 🟢 Golden-set remediation (plan §7.3)

- [x] Decide the quote-grounding definition — done 2026-08-02. Grounding is now
  reported in **three tiers** (`exact` / `normalized` / `ungrounded`) rather than
  pass/fail, with `normalize_for_grounding()` removing rendering differences only:
  space-before-punctuation, markdown list markers, whitespace, case. Punctuation
  itself is deliberately kept, so an inserted comma still fails. Tier chosen by
  measurement: it clears 12 of 15 formatting failures with **0 of 37 altered and
  0 of 20 absent leaking through**, and that property is pinned by a test over the
  real golden set, not just measured once.
- [ ] Still open: **elision**. 76 quotes are verbatim and in sequence but
  non-contiguous — they join an enumeration stem to a specific item, which is real
  GDPR structure rather than a defect. Preferred shape: let `supporting_quote` hold a
  **list of spans**, each an exact substring, in document order, so elision is
  explicit in the data instead of inferred by a fuzzy matcher. The explicit `...`
  markers become list boundaries.
- [ ] Rewrite the **58 quotes that are not verbatim** — 37 altered, 20 absent, 1 with an
  inserted comma (lists in the report). Not one batch: `art61_case5` is off by an
  inflection (`expenditures`), `art25_case2` moves "the controller shall" across a
  clause, while `art41_case3` has 11 consecutive absent tokens and looks invented.
  - Done 2026-08-02: `art60_case2` and `art80_case2`, one comma each, both now *exact*.
    `art80_case2` mattered — the comma turned a restrictive clause non-restrictive,
    widening the provision's apparent scope in a case whose `answer_type` is `scope`.
  - Open: `art36_case4`. The corpus is faithful here (verified against the PDF:
    Article 36(2) genuinely leaves its parenthetical unclosed), so the quote is the
    altered side and the fix is to delete its comma.
- [x] Fix the **17 remaining leakage questions**, all of which named their own gold
  article — done 2026-08-03. **Leakage is now 0**; clean cases 285 → **299**.
  - Eleven used the number as a bare handle and were swapped for the substance
    ("What types of identifiers does Article 87 cover?" → "Which identifiers may Member
    States lay down specific processing conditions for?"). Four needed a substitute for
    what the number carried (`art65_case1`, `art93_case3`, `art95_case3`, `art96_case2`).
  - Two keep a cross-reference and pass only because of the self-reference rule:
    `art10_case2` (retains `Article 6(1)`, which its `key_phrases` require) and
    `art93_case2` (retains `Article 5 of Regulation (EU) No 182/2011`).
  - `art14_case6`, `art90_case2`, `art93_case2` still have a broken quote — question
    fixed, quote still on the 58-quote item above.
  - Pinned by `test_no_golden_case_names_its_own_article`, which runs over the real set;
    mutation-checked to confirm it fails when a self-reference is reintroduced.
  - Done 2026-08-02: `art94_case3`, reworded to "What body replaces the Working Party of
    Directive 95/46/EC?".
- [x] Leakage check: flag only when the cited article number equals the case's own
  `article_number` — done 2026-08-03. Superseded the planned "Article 29 Working Party"
  allow-list; the discriminator is **self-reference**, not a proper noun.
  - Deliberately narrow: `_ARTICLE_REF` matches one citation at a time, so
    "Article 93(2)" reads as article 93 and the `(2)` is not mistaken for article 2. It
    does *not* parse multi-article runs ("Articles 13 and 14" reads as 13 alone) — no
    question uses that form; widen it when one does.
  - The bare `paragraph 2` / `recital 39` arm of the old pattern was **dropped**, not
    ported: only self-reference is prohibited. No question in the 433 contains such a
    reference, so this gives up no live coverage, and its test was deleted rather than
    left asserting a rule that no longer holds.
  - Known boundary: a same-numbered article of a *different* instrument ("Article 5 of
    Regulation (EU) No 182/2011" in a case whose gold article is 5) would be flagged.
    No case does this.
  - The `xfail` this item referenced is gone — it is now a passing test, and the suite
    has no xfails left (64 passed/1 xfailed → **67 passed**).
- [x] **Questions that are not self-contained** — a defect class distinct from leakage,
  found and closed 2026-08-03. **8 cases fixed, new `check_self_containment` gate, now 0.**
  - `art22_case2`, `art48_case1`, `art49_case2`, `art86_case1`, `art86_case3` ("this
    article"), `art48_case3` ("this rule"), `art96_case1` ("this provision"),
    `art49_case4` ("these derogations"). They leak no location — nothing can be looked up
    by citation — but a question that only makes sense beside its answer is not a
    retrieval query.
  - **The count went 5 → 7 → 8 across three sweeps**, and that is the finding worth
    keeping. Each sweep enumerated *nouns*, which is an open class: a pass for "article"
    missed "rule"/"provision", and a pass for those still missed "derogations". The gate
    anchors on the **determiner** (`this|these|those|such|said`) and leaves the noun a
    wildcard, so it catches words nobody predicted — pinned by
    `test_self_containment_catches_nouns_nobody_enumerated`.
  - Bare `that` is excluded: it is ambiguous with the relative pronoun ("activities that
    fall outside the scope of EU law"), which is a part-of-speech judgement, not a lexical
    one. Including it flagged **29 questions to find 8**. Two closed-class exemptions keep
    precision at 9/9: `this Regulation` (a term of art) and a demonstrative followed by an
    auxiliary (`can this be extended?` — pronoun, not determiner).
  - Pinned by `test_no_golden_case_refers_to_absent_context` over the real set,
    mutation-checked by restoring the old `art86_case3` wording.
- [ ] **Non-deictic context dependence is unmeasured.** The gate above is a floor, not a
  proof: a question can depend on absent context with no demonstrative at all ("Are there
  any exemptions?"). Deterministic checks cannot reach it — it is judge-tier (P1), and the
  regression test says so explicitly so a green result is not read as coverage.
- [ ] `art44_case4` names **"Chapter V"**. A roman numeral is invisible to a `\d`-based
  check, and a chapter is a location — worth a decision, though a chapter is coarser than
  an article and is not the gold unit.
- [ ] **Constrain the generator, not just the artifact.** Both defect classes closed today
  are systematic producer faults: the generator wrote while looking at the article and
  assumed its reader was too. Same principle as the soft-hyphen fix — patching the JSON
  would leave the generator reintroducing them. The Tier-1 generation prompt should
  require questions that name no article number and carry their own referents.
- [x] **Reconcile `docs/evaluation-plan.md` §7.3 with the implemented gates** — done
  2026-08-03. §7.3 had specified only 2 of the 5 checks in `run_golden_qa`, and both
  differently from what the code does; the module docstring was the de-facto spec.
  Rewritten into four parts: **deterministic gates** (grounding tiers with the
  proxy-vs-purpose rationale and the measured normalization boundary, self-reference
  leakage, self-containment, structural validity), **judge/manual gates** (entailment and
  human audit, explicitly P1), **known limits** (non-deictic context dependence,
  parametric answerability, elision), and **how these checks are meant to be built**.
  - That last part records the method rather than the rules: checks are *regression*
    devices, not discovery devices, over a finite set from a known generator; enumerate
    the construction, not the vocabulary; fix the generator, not just the artifact. Plus
    mutation as the way check quality is verified — "a gate that has never been observed
    to fail is not known to work."
  - Also fixed in §7.1: Tier 1 was described as "~38 articles". It is **433 cases across
    all 99 articles**.
- [ ] **Reconcile §3.1** — still open, and more consequential than §7.3 was. §3.1 does not
  say that **Context Recall, its *primary* retrieval metric, is scored by matching
  `supporting_quote` against retrieved chunks** — so an ungrounded quote registers as a
  retriever failure whatever the retriever did, and 134 cases would depress the number for
  reasons that have nothing to do with retrieval. Mitigation is already in the data: score
  article-level Hit@k from `article_number` (unaffected), and restrict chunk-level matching
  to the 299 exact-or-normalized cases with the exclusion reported rather than hidden.
  When that scorer is built it should import `normalize_for_grounding` rather than
  reimplement matching, so the gate and the metric cannot drift apart.
- [ ] **Measure check recall by mutation, systematically.** Both regression tests were
  mutation-checked by hand (restore the old wording, confirm failure, restore). Worth
  making that a harness: inject known defect instances into the clean set and count
  catches, so check quality is a number rather than a feeling.
- [ ] **Parametric answerability** — a defect class with no check. `art94_case3` is
  answerable from general knowledge without retrieving anything. Retrieval metrics are
  unaffected (Hit@k measures whether the gold chunk was retrieved regardless), but
  end-to-end generation metrics would score well over a broken retriever. The plan's
  paired end-to-end / gold-context probes (§2) make it detectable — an unusually small
  gap between probes — but nothing flags it and the extent across the 433 is unmeasured.
  Worth sampling.

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
he - [x] **OCR soft-hyphen breaks** — found and fixed 2026-08-02. 18 occurrences of
  U+00AD + space across **14 of 99 articles** (4, 9, 14, 30, 36, 42, 43, 44, 45,
  46, 49, 50, 58, 80), e.g. `internat­ ional`, `certifi­ cation`,
  `jurisdic­ tional`. Fixed in the parser
  (`GDPRParser._rejoin_hyphenated_words`, applied per-article in `_clean_content`
  and `_clean_title`) rather than by editing the JSON, so a regeneration cannot
  reintroduce it. Corpus regenerated: 14 lines changed, every one `'\xad ' -> ''`,
  soft hyphens 18 → 0, all 242 real U+002D hyphens preserved. Golden-set QA
  151 → 148 errors. **Qdrant re-index still pending** — 14 articles' content
  changed.
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
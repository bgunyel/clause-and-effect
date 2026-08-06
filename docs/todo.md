# Clause & Effect — TODO

> Working backlog. Captures the three explicitly-requested items plus the
> outstanding work surfaced while diagnosing the `gdpr_articles.json` truncation
> bug and standing up the eval framework + test suite.
>
> _Last updated: 2026-08-06._

---

## 🔴 Blocking — data integrity

The corpus text is intact, but its **structure is not**: docling's markdown
serializer destroys the paragraph hierarchy inside 43 of 99 articles, and the
chunker turns that into a retrieval-correctness fault. Everything else in this
file is downstream of fixing it.

- [ ] 🔺 **Regenerate the corpus from the docling *document tree*, not its markdown.**
  Found by Bertan on 2026-08-05 reading `gdpr.docling.md`; full analysis, worked
  example and reconstruction plan in
  [`dev-log/devlog_2026-08-05_session-1.md`](dev-log/devlog_2026-08-05_session-1.md).

  **The defect.** The serializer renumbers non-enumerated list items into the
  surrounding ordered list, so lettered sub-items are promoted to paragraph level.
  Article 2 has four paragraphs, with (a)–(d) under ¶2. The markdown emits:

  ```
  1. This Regulation applies to the processing of personal data ...     <- ¶1
  2. This Regulation does not apply to the processing of personal data: <- ¶2 stem
  3. (a) in the course of an activity which falls outside ...           <- ¶2(a)
  4. (b) by the Member States when carrying out activities ...          <- ¶2(b)
  5. (c) by a natural person in the course of a purely personal ...     <- ¶2(c)
  6. (d) by competent authorities for the purposes of the prevention... <- ¶2(d)
  3. For the processing of personal data by the Union institutions ...  <- ¶3
  4. This Regulation shall be without prejudice to ...                  <- ¶4
  ```

  The numbering **restarts** where the real list resumes, so within one article
  `3.` denotes both ¶2(a) and ¶3. "Article 2(3)" is unresolvable from corpus text.

  | measured 2026-08-05 | |
  |---|---:|
  | articles where a numbered line is really a lettered sub-item | **43 / 99** |
  | articles carrying a genuine paragraph-number collision | **41 / 99** |
  | articles whose real numbering reconstructs from markdown alone | 82 / 82 |

  **Why this is blocking and not cosmetic.** `_split_into_paragraphs`
  (`gdpr_parser.py:291`) splits on `\d+\.\s+`, so every spurious number becomes a
  **chunk boundary**. Article 2 is indexed as 8 chunks, and
  `gdpr_article_2_para_6` is ¶2(d) severed from the stem that negates it —
  standing alone it reads as a *positive* statement of scope. A perfect retriever
  returning that chunk hands the generator text meaning the opposite of what it
  says in context. `metadata["paragraph"]` is also a sequential index mislabelled
  as a paragraph number (`para=6` is really ¶2(d)), so any paragraph-level
  citation metric would score against wrong labels in 43 articles.

  **The source to use.** `data/regulations/gdpr.docling.json` (untracked, 1.4 MB)
  is the same run's intermediate document tree: 171 groups, 1623 texts. Article 2
  is `#/groups/35` holding `#/texts/367`…`374`, and the true numbers survive in
  each item's `marker` with `enumerated` separating the two kinds:

  | item | `label` | `enumerated` | `marker` | is |
  |---|---|---|---|---|
  | texts/367 | `list_item` | `true` | `"1."` | ¶1 |
  | texts/368 | `list_item` | `true` | `"2."` | ¶2 stem |
  | texts/369–372 | `list_item` | **`false`** | `""` | (a) (b) (c) (d) |
  | texts/373–374 | `list_item` | `true` | `"3."` `"4."` | ¶3, ¶4 |

  Extraction was never the problem; rendering was. Items also carry `prov`
  (`page_no`, `charspan`) into the PDF text layer, which makes the PDF
  verification this file demands elsewhere mechanical rather than manual.

  **Four complications, each measured — the tree is a better source, not a clean one:**
  1. **Hierarchy is inferred, not encoded.** Every text item has `children: []`
     and no group contains a group — **0 nesting** across 1623 texts / 171 groups.
     "(a)–(d) belong to ¶2" is a rule we impose on a flat sibling list.
  2. **41 paragraphs are `label: "text"`**, with the number left inline in the
     string (Article 9(1) is `"1. Processing of personal data revealing racial…"`).
     A rule reading only `list_item.marker` drops them — the cause of the irregular
     marker runs in articles **9, 18, 35, 57, 58**.
  3. **Article 28 recurs.** Its header is `[text] #/texts/746 'Article 28'`, not a
     `section_header`, so a header-label walk finds 98 articles and folds Article
     28's paragraphs into Article 27. Same quirk as the 2026-08-01 post-mortem,
     different serialization. **Tested fix:** match `^Article\s+(\d+)$` on items
     labelled `section_header` *or* `text` → 99 articles, no gaps.
  4. **Sub-items do not always follow a numbered paragraph.** Article 50 has none
     (a `text` stem then (a)–(d)); Article 4 is a `text` stem then definitions
     `(1)`…`(26)` as `enumerated: true, marker: "(1)"`. The attach rule must be
     *nearest preceding item*, not nearest preceding **enumerated** item.

  **Reconstruction steps** (detail in the devlog): walk `#/body` depth-first,
  resolving `$ref` against `texts`/`groups` and special-casing `#/body`, which is
  in neither; detect article boundaries on text with either label; classify each
  item by the table above; **assert paragraph numbers are 1..N per article** and
  exit non-zero otherwise; emit real paragraph identity (`2(2)(d)`, not `para=6`)
  carrying `prov`; re-use `_rejoin_hyphenated_words` and the whitespace collapse;
  and **chunk each paragraph together with its sub-items**, which is what actually
  fixes `art2_case4`.

  **The argument for switching is detectability, not cleanliness.** With markdown,
  hierarchy loss was invisible — the text was intact and only segmentation was
  wrong, so no gate could see it. With `marker`, the invariant *"every article's
  paragraph markers form 1..N, no gaps, no repeats"* fails loudly on exactly the
  six irregular articles. That is the corpus-level assertion this file already
  wants for `generate_gdpr_articles.py`.

  **Caveat to carry:** the 1..N check proves *consistency*, not *fidelity*. A
  paragraph docling dropped entirely would still reconstruct cleanly. Per the
  `art36_case4` lesson this rules out one link in the chain and no more.

  **Consequences to plan for:** corpus content changes, so **every number measured
  before it is void again**; Qdrant needs a full rebuild; golden-set QA must be
  re-run and the 134 ungrounded re-derived (26 are predicted to clear).

- [ ] **Re-index Qdrant — carried over from 2026-08-02, still not done.** Now
  **folded into the regeneration above** rather than a standalone task: the corpus
  is about to change again, so re-indexing the current one would be wasted. The
  soft-hyphen fix changed the content of **14 articles** after the 2026-08-01
  re-index, so those articles' chunk text and embeddings no longer match the
  corpus. Cheap (~$0.001) and idempotent: point IDs are `uuid5(namespace,
  chunk.id)`, so the write overwrites in place and the collection does not need
  dropping. Any retrieval number measured before this is against a corpus that
  does not exist.
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
  - **State at end of 2026-08-02: 285 exact, 14 normalized, 134 ungrounded, 17
    leakage, 285 clean of 433. Gate FAIL.**
  - **Superseded 2026-08-03: leakage 0, self-containment 0, 299 clean of 433.**
    Quote grounding is unchanged at 134 — every remaining error is a quote.
  - The 76/37/20/1 split above **could not be reproduced** on 2026-08-03. The
    script that produced it was never committed, so its `absent` threshold is not
    recoverable. Re-deriving with an explicit criterion gives **77 elision / 56
    altered / 1 punctuation**. The underlying signal does reproduce —
    `art41_case3` shows an 11-word run with no matching bigram in its article,
    matching the original note.
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
  - Record how to run (`python -m pytest`) and current status (**81 passed, no
    xfails** as of 2026-08-03).
  - Carry over the lesson from the header-collapse post-mortem: fixtures written
    from the same assumption as the code only prove self-consistency. Where a
    real artifact can be captured and committed, test against it.

---

## 🟢 Golden-set remediation (plan §7.3)

- [ ] 🔺 **Build the answer-vs-quote sufficiency judge.** The acceptance criterion, set by
  Bertan on 2026-08-03: **every one of the 433 questions must be answerable using only its
  `supporting_quote`.** That is not what the gate measures, and the two properties are
  uncorrelated:
  - **Provenance** (`quote ⊆ article`) is what the gate checks. **Sufficiency** (the quote
    answers the question) is what matters. `art2_case4` grounds *exact* and passes cleanly
    today: its quote is a verbatim fragment of Article 2 that never contains the negation,
    while its answer is *"No, GDPR does not apply…"*. Perfect provenance, zero sufficiency.
  - **Two-sided property.** A quote that cannot answer the question is **useless**; one
    carrying far more than needed is **not useless but devalued**. The judge should
    therefore return both a verdict and the minimal sufficient span — which makes the same
    pass produce the repair, not just the diagnosis.
  - **Not deterministic, by decision.** A `key_phrases`-in-quote screen was built and
    rejected as a gate: literal matching flagged 57 cases (mostly word-order noise),
    subsequence matching 35, but it still fails on glosses — `art8_case1` is flagged for
    missing `'parental consent'` though its quote fully answers *"what is the minimum
    age?"*. The screen's only role is **triage and judge calibration**.
  - **Scope: the repair set is 169 cases, not 134** — 35 pass the gate today and fail the
    criterion (screen: 264 grounded-and-covered, 35 grounded-but-flagged, 110 ungrounded-
    but-covered, 24 both).
  - **Undecided, and it changes the target:** *question answerable from quote* (Bertan's
    wording) versus the stronger *answer entailed by quote*. They disagree on real cases —
    `art7_case3`'s quote answers "can consent be withdrawn?" (yes) but does not support
    the answer's second clause about the lawfulness of prior processing. The stronger
    reading matters because the gold `answer` is the reference against which Groundedness
    is scored; if it asserts what its quote does not support, the metric is measuring
    against a standard that fails its own test.
  - **Protocol sketched, nothing built.** Blind design: the judge answers the question from
    the quote alone, seeing neither the article nor the gold answer, with an explicit
    INSUFFICIENT escape; a second stage compares its answer to the gold. Asking a judge to
    *perform* the task rather than opine on it is what stops it rationalising. Panel for
    the verdict (§6.2 already mandates majority/consensus for high-stakes gates), plus a
    human-labelled calibration sample as §7.3 requires — the judge is not trusted before
    agreement is reported.
  - Implementation fits existing plumbing: OpenRouter via `ai_common`, and
    `gdpr_test_data_generation.py` already has the async multi-model pattern to copy.
  - **Resolved 2026-08-05, by Bertan on `art7_case3`:** the target is *question
    answerable from quote*, the weaker reading. The shortest sufficient answer there
    is *"Yes, the data subject shall have the right to withdraw their consent at any
    time"*; the clause about prior lawfulness is auxiliary information that
    strengthens the answer, not a claim the quote must carry. Measured: **175 of 433**
    cases have at least one answer sentence poorly covered by their quote, so the
    stronger reading would make ~40% of the set a candidate failure. The
    core-vs-auxiliary split is therefore a first-class judge output.
  - **Built 2026-08-05 (uncommitted):** `src/eval/sufficiency_judge.py` — stages A
    (decompose) and B (answer-blind), eyeballed on 8 cases. Stage C, verdict
    derivation, the `sufficient_verbose` threshold (**measure it, do not guess** —
    observed span/quote ratios run 19%–100%), the async runner, the calibration
    sample and tests are **not started**.
    - Stage A tags by making the judge **write the shortest sufficient answer first**.
      An earlier leave-one-out removal test returned **zero** core claims on
      `art7_case3`, because it cannot see mutual redundancy: *"Yes."* was excused by
      the substantive clause and the substantive clause by *"Yes."*.
    - Stage B never names the regulation and **copies its span before answering**, so
      it must ground before it speaks. On `art2_case4` it returned `answered=False`
      and reasoned about the excerpt's provenance rather than supplying the negation
      from parametric knowledge — the failure mode that would have made the whole
      judge worthless.
    - `span_is_verbatim` reuses `normalize_for_grounding` so the judge and the
      grounding gate cannot drift on what "the same text" means. It returned 8/8
      verbatim, i.e. **it has never been observed to fail and so is not yet known to
      work** — mutate it when the tests land.
  - Still undecided: calibration sequencing (label a stratified sample first, or run
    all 433 and sample after), panel composition (constrained by the broken
    `writer_model[1]`, see known code issues), and whether an `UNANSWERABLE` verdict
    belongs in this pass at all given stage B is blind to the article.
- [x] Decide the quote-grounding definition — done 2026-08-02. Grounding is now
  reported in **three tiers** (`exact` / `normalized` / `ungrounded`) rather than
  pass/fail, with `normalize_for_grounding()` removing rendering differences only:
  space-before-punctuation, markdown list markers, whitespace, case. Punctuation
  itself is deliberately kept, so an inserted comma still fails. Tier chosen by
  measurement: it clears 12 of 15 formatting failures with **0 of 37 altered and
  0 of 20 absent leaking through**, and that property is pinned by a test over the
  real golden set, not just measured once.
- [ ] Still open: **elision** — **77** quotes (re-derived 2026-08-03) are verbatim and in
  sequence but non-contiguous, joining an enumeration stem to a specific item, which is
  real GDPR structure rather than a defect. Preferred shape: let `supporting_quote` hold a
  **list of spans**, each an exact substring, in document order, so elision is
  explicit in the data instead of inferred by a fuzzy matcher. The explicit `...`
  markers become list boundaries.
  - **26 of the 77 are not elision at all** — they are the corpus line-numbering artifact
    (see the chunking-rework section). Strip the spurious indices and all 26 ground as
    contiguous verbatim, no false clears. So the real elision count is **51**, and the
    other 26 are blocked on the corpus regeneration rather than on this design.
  - **Sufficiency is the argument for span lists.** `art2_case4` grounds *exact* yet
    cannot answer its own question, because the span was truncated and lost the stem
    carrying the negation (*"This Regulation does not apply to…"*). Stem-plus-item is
    exactly what a span list preserves and a single contiguous span destroys.
  - **2026-08-05: this is the same decision as the hierarchy fix.** `art2_case4`'s
    quote *is* ¶2(d); its stem is ¶2, separated by (a), (b) and (c). **No contiguous
    substring of the corpus can satisfy the sufficiency criterion for that case** — so
    the case is not a badly-chosen quote, as this file previously implied. Confirmed
    independently by stage B of the sufficiency judge, which returned `answered=False`
    on it. Whether span lists are still needed once paragraphs are chunked
    stem-with-items is an open question the regeneration should answer, not a
    foregone one.
  - Schema note: this changes `supporting_quote` from `str` to `list[str]`, so
    `TestCase`, the loader, `check_quote_grounding`, its tests and all 433 files are
    affected — not only the 51. Decide whether to permit both shapes or migrate cleanly.
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
  - **"Altered" is three different defects** (found 2026-08-03) and must not be worked as
    one batch:
    1. **The generator tidied the statute.** `art32_case4` writes *"shall not process
       them"* for *"does not process them"*; `art38_case2` writes *"performing his or her
       tasks"* where the regulation genuinely says *"performing his tasks"*. Same class as
       `art36_case4`. Fix is mechanical: restore the exact text.
    2. **Substantive alteration.** `art37_case1` turns *"Article 9 **and** personal
       data"* into *"Article 9 **or** personal data"* — a conjunction governing when a DPO
       must be designated, like `art80_case2`'s comma.
    3. **Invalid case, not a quote defect.** `art41_case3` asks how long accreditation
       lasts; Article 41 contains no *"five years"*, no *"maximum period"*, no
       *"renewed"*, and it is the only case where **none** of its `key_phrases` appear in
       its gold article. `art8_case5` quotes **Recital 38**, not Article 8. Writing a
       quote for these would launder an unanswerable question into a clean-looking case —
       decide between rewriting question+answer, re-pointing `article_number`, or removal.
       - **Re-classified 2026-08-05.** Stage B of the sufficiency judge answered *both*
         cleanly from their quotes, so **the questions are sound** — the defect is
         provenance, not answerability, and "invalid case" was the wrong label.
       - `art41_case3`: its quote matches **no article in the corpus**. A
         maximum-period-of-five-years accreditation rule is not Article 41 (monitoring
         of approved codes of conduct) and reads like Article 43's certification-body
         rule — so this is a mis-pointed `article_number` or text from outside the
         corpus, not an invention. Re-pointing is the likely fix.
       - `art8_case5`: the quote is two fragments joined by `...`. The **first is in
         Article 8**; the **second matches no article**, so the Recital 38 note holds
         for that fragment only. An intermediate claim that this entry was simply
         wrong was itself wrong and is retracted here.
       - Both were checked against the **corpus only**. Verify against the PDF before
         editing — now cheap, since `gdpr.docling.json` carries `page_no` and
         `charspan` per item.
    - Both were checked against the **corpus only, not the source PDF**. Per the
      `art36_case4` lesson, that rules out one link in the chain and no more — verify
      against the PDF before deleting or rewriting anything.
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
    has no xfails left (64 passed/1 xfailed → 67 at this commit, **81 by end of session**).
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
- [ ] **Commit the quote classifier.** The 77/56/1 split is currently reproducible only
  from an uncommitted scratch script — the same gap that made the earlier 76/37/20/1 split
  unreproducible, which the 2026-08-02 report itself flagged. Criterion to encode:
  contiguous word match → *punctuation*; word subsequence → *elision*; otherwise *altered*,
  with the longest run of consecutive quote words having no matching bigram in the article
  as the severity signal (`art41_case3` = 11).
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

- [ ] **Resolve each quote to gold chunk ID(s) at eval-set build time**, and score
  Context Recall by ID comparison at run time. Designed 2026-08-03; nothing built.
  - ⛔ **Blocked on the corpus regeneration** (🔴 above). Pinning quotes to chunk IDs
    against today's chunking would fix them to a decomposition that is wrong in 43 of
    99 articles — `gdpr_article_2_para_6` is ¶2(d) severed from its stem. The
    feasibility numbers below (294/299 pin exactly one chunk) were measured against
    that chunking and must be re-derived after the rebuild.
  - Neither obvious option is right on its own. **Article-level** matching is too coarse —
    71.1% of cases sit in multi-chunk articles, mean **6.5** chunks (median 6, max 28), so
    it credits any 1 of ~6 — and, decisively, it is *blind to the variable under test*:
    re-chunking changes which chunk is retrieved, rarely which article, so the metric would
    sit flat across exactly the experiments this roadmap exists to run. **Quote-text
    matching at scoring time** does fuzzy matching in the loop, turns the 134 ungrounded
    quotes into silent retrieval failures, and duplicates matching logic that can drift
    from the gate.
  - It also has a concrete false-positive mode: chunks are built as
    `f"Article {n}.{i}: {title}\n\n{para}"`, so a quote overlapping the article **title**
    matches *every* chunk of that article — `art14_case1` matches all 10 chunks of
    Article 14. Resolve the span against article **content** by character offset, not by
    substring search in rendered chunk text.
  - Measured feasibility: **294 of 299** grounded cases pin exactly one chunk; 3 span a
    chunk boundary (`art12_case3`, `art37_case3`, `art42_case4`), 2 are ambiguous
    (`art14_case1`, `art89_case4`). Ungrounded quotes then fail **loudly at build time**
    ("no gold chunk assignable") instead of depressing every run.
  - `gold_chunk_ids` is a function of (quote, chunking config), so re-chunking recomputes
    it — which is correct, and turns chunk-boundary problems into a build-time report.
  - **Report both levels.** The gap between chunk-level and article-level is the
    diagnostic: right article/wrong chunk = chunking or embedding problem; wrong article =
    retrieval problem. That maps onto the §9 failure taxonomy, and article-level stays
    trustworthy across the cases chunk-level must exclude.
  - Decide: multi-chunk gold sets need *any* (Hit@k) and *all* (full-evidence recall)
    reported separately — averaging them hides both. And `art14_case1`'s quote is the
    article title restated, which is weak evidence regardless of scoring; tighten it.
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

- [x] ~~Deferred, and the largest of these: **enumeration line numbering leaks into
  article content.**~~ **Superseded 2026-08-05** — this was the symptom, seen from the
  quote-grounding side. The defect is **hierarchy destruction by the markdown
  serializer**, it affects 43 of 99 articles, and it severs chunks as well as
  corrupting quotes. Promoted to the 🔴 blocking section as a corpus regeneration from
  `gdpr.docling.json`; the note below is kept for the evidence it records.
  - The **26 of 134** figure below counts only quotes that fail *grounding*. Chunk
    severance never fails grounding — Article 2's text is intact and only its
    segmentation is wrong — so it is a floor on a different quantity, not a measure of
    this defect.

  <details><summary>Original entry (2026-08-03)</summary>

  docling numbered the first sub-items of an enumeration `2. 3. 4.` — continuing
  the paragraph count — then switched to bullets partway through the *same* list:

  ```
  1. Where personal data ... are collected from the data subject, the controller shall ...
  2. (a) the identity and the contact details of the controller ...
  3. (b) the contact details of the data protection officer ...
  - (d) where the processing is based on point (f) of Article 6(1) ...
  ```

  Real Article 13(1) has (a)–(f) under one paragraph, so those indices are spurious.
  Measured 2026-08-03: stripping them grounds **26 of the 134** remaining quote errors,
  **all 26 contiguous verbatim** — no false clears. Same shape as the 2026-08-01
  truncation finding: a corpus fault reported in test-case vocabulary. Fix belongs in the
  parser, not in `normalize_for_grounding` — normalizing it away would hide a real corpus
  defect and leave the chunk text (and embeddings) still carrying it.

  </details>
- [ ] **Footnotes are dropped from article content by the tree-based parser — decided
  2026-08-06, flagged for future review.** `_build_units` skips every item labelled
  `footnote`, matching the markdown path's effect but for a different reason: the
  markdown serializer inlined them as ordinary text, so they were in the corpus by
  accident rather than by decision. Now it is a decision, and it should be revisited
  once retrieval quality is being measured rather than assumed.

  **Scope: 3 items, in articles 5, 43 and 79** (21 exist document-wide; the other 18
  sit outside any article range and never reached the corpus). All three are
  citations of other instruments — Directive (EU) 2015/1535, Regulation (EC) No
  765/2008, and Regulation (EC) No 1049/2001. Verified: removing them leaves each
  article's prose **byte-identical** to the markdown path, and they are the *only*
  prose difference between the two paths across all 99 articles (96 match exactly;
  these 3 differ by exactly their footnote).

  **The known wart.** Only the footnote *body* is dropped; the inline reference
  marker stays. Article 43's content still reads `... ( 1 ) in accordance with
  EN-ISO/IEC 17065/2012 ...`, so the text now carries a pointer to something the
  corpus no longer contains. Harmless for grounding (no golden quote covers it) and
  invisible to the current gates, but it is a dangling reference inside embedded
  text.

  **What to review, and when.** Whether a footnote is article content at all is a
  genuine question, not an oversight: Article 43's footnote defines the
  accreditation standard its paragraph 1(b) depends on, so a question about
  accreditation criteria is arguably answerable only *with* it. Revisit alongside
  the chunking rework, when there is a retrieval metric to decide it against.
  Reversing the decision is one line in `_NON_CONTENT_LABELS` plus a regeneration.
- [ ] **Cited instruments may need to enter the corpus — future versions, explicitly
  not now.** Raised by Bertan 2026-08-06 off the footnote decision above. The corpus
  today is the GDPR alone, so every cross-instrument reference is a dead end: the
  text names a rule the retriever cannot reach, and a question whose answer lives in
  the cited document is unanswerable from the corpus no matter how good retrieval
  gets.

  **Size of the job, measured 2026-08-06** over `gdpr_articles.json` — **9 distinct
  instruments, 25 mentions, across 14 articles**:

  | instrument | mentions | articles |
  |---|---:|---|
  | Directive 95/46/EC (Data Protection Directive) | 8 | 45, 46, 94, 97 |
  | Directive 2002/58/EC (ePrivacy) | 3 | 21, 95 |
  | Regulation (EC) No 765/2008 (accreditation) | 3 | 43 |
  | Regulation (EU) No 182/2011 (comitology) | 3 | 93 |
  | Regulation (EC) No 45/2001 (EU institutions) | 2 | 2 |
  | Directive (EU) 2015/1535 (technical regulations) | 2 | 4, 5 |
  | Regulation (EC) No 1049/2001 (document access) | 2 | 76, 79 |
  | Directive 2000/31/EC (e-commerce) | 1 | 2 |
  | Regulation (EEC) No 339/93 | 1 | 43 |

  **What it would take, and why it is not a "just add more PDFs" job:**
  - `GDPRParser` is GDPR-shaped (99 articles, chapter map, `Article N` headings).
    A second instrument needs either its own parser or the article/paragraph model
    generalised — the `docling_tree` walk is already instrument-agnostic, which is
    part of why it was split out.
  - Chunk IDs, `regulation` metadata and the gold-chunk-ID scheme (P0) all assume a
    single corpus. Multi-instrument retrieval makes *which regulation* a scoring
    dimension, not a constant.
  - The golden set is Tier-1 GDPR-only. Cross-instrument questions would be a new
    tier with its own generation and validation, not extra cases in this one.
  - Retrieval gets harder before it gets better: Directive 95/46/EC is the GDPR's
    repealed predecessor and overlaps it heavily in wording, so adding it invites
    near-duplicate retrieval against text that is *no longer in force*.

  Related: the footnote decision above, which is the narrow version of this question
  (3 citations, already excluded) — revisit the two together.
- [ ] Deferred: `_clean_title` does not collapse OCR double-spacing the way
  `_clean_content` does, so 3 of 99 titles (articles **12, 60, 89**) keep runs of
  multiple spaces. Titles are embedded into every chunk of their article, so
  **27 of 563** indexed chunks carry it. Low impact on semantic retrieval, but
  the planned lexical scorers do string comparison and may false-flag these.
- [x] **OCR soft-hyphen breaks** — found and fixed 2026-08-02. 18 occurrences of
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
- [ ] `GDPRParser._split_into_paragraphs` (`gdpr_parser.py:291`) splits on
  `\d+\.\s+`, which (a) makes every spurious sub-item number a chunk boundary — see
  the 🔴 regeneration item — and (b) *deletes* the numbers, so paragraph identity
  survives neither in the text nor in `metadata["paragraph"]`, which holds a
  sequential index instead. Both go away if the rebuild emits real paragraph
  identity, so fix it there rather than patching the regex.
- [ ] `src/config.py` `get_llm_config()['writer_model'][1]` is **broken**:
  `ModelNames.GPT_OSS_120B` has no OpenRouter alias in `ai_common`
  (`MODEL_NAME_ALIAS_DICT` lists groq and ollama only), so `get_llm` raises
  `KeyError: <LlmServers.OPENROUTER>` on construction. Found 2026-08-05 while
  picking a judge model. Only DeepSeek V3.2/V4-Flash and Gemini 3.1 Flash-Lite are
  reachable over OpenRouter today, which also constrains judge-panel diversity.
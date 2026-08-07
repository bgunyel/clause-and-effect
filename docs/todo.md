# Clause & Effect — TODO

> Working backlog. Captures the three explicitly-requested items plus the
> outstanding work surfaced while diagnosing the `gdpr_articles.json` truncation
> bug and standing up the eval framework + test suite.
>
> _Last updated: 2026-08-07._

---

## 🎯 Priority order — set by Bertan, 2026-08-07

**The goal is the first eval numbers from the RAG system as it stands today.**
Getting the evaluation pipeline end-to-end and measured comes before improving
any algorithm inside it, because until there is a baseline no improvement can be
shown to be one.

> **The algorithm does not need to be perfect. The evaluation pipeline does.**
> The product is measurable-not-optimal; the eval is the instrument, and a
> defective instrument corrupts every decision taken on its output. Recorded in
> full at [`evaluation-plan.md` §1](evaluation-plan.md#the-asymmetry-of-standards).

This is what makes the ordering below non-negotiable rather than a preference —
and what makes step 3 (tests) a hard requirement for eval components while the
generator and agent staying untested remains an accepted state.

1. ~~**Generate the first chunk snapshot** against a clean tree, then commit it
   separately.~~ **Done 2026-08-07** (`2a7811a`) — 368 chunks, `sha256
   157d4d38…`, generated at `c67e266` with `git_dirty: false`. Two defects in
   `git_state` were found and fixed first (`c67e266`); see ⚪ Known code issues.
2. ~~**Write the chunk-set hash into Qdrant when indexing**, and make it true
   that *every point in a collection belongs to that collection's chunk set*.~~
   **Done 2026-08-07** (`d7db4f9`). `compliance_docs` now holds **368 points, 0
   orphans, 0 missing**, advertising `157d4d38…`. It held 563 with
   `metadata=None`; **196 were orphans** (not the ~195 estimated) and one
   snapshot chunk, `gdpr_article_79`, was absent entirely — dropping its
   footnote pushed the article under the chunk budget, so it stopped splitting
   into paragraphs and acquired a new ID. `--check` now answers "does the
   collection hold exactly this snapshot?" for free.

   **Extended the same day** (`6f4df7a`): every point now carries
   `chunk_set_sha256` in its own payload. Raised by Bertan — ID-set comparison
   is structurally blind to a text-only revision, because point IDs derive from
   chunk IDs alone. The paragraph-citation fix proved it: `IDs added 0, removed
   0, text changed 330`. Current baseline is
   `chunks_2026-08-07_081627_a231f919`; the collection reports 0 orphans, 0
   missing, **0 stale**.
3. ~~**Tests** for what was verified by hand only: `chunk_store.py`,
   `generate_chunks.py`, `docling_tree.py`,
   `GDPRParser.get_articles_from_dictionary`.~~ **Done 2026-08-07**
   (`efd2f09`, `50d8eb8`). Suite **81 → 180**. Mutation-checked across 35
   mutations; **four were not caught**, and all four were bad or missing tests
   rather than missing code — listed under 🟡 Tooling below, because what they
   have in common is worth more than any one of them.
4. **Finish the sufficiency judge** — stage C, verdict derivation, runner,
   calibration, tests.

**Explicitly not in this sequence: the hierarchy-aware chunker.** It is a future
algorithm improvement, not a blocker — Bertan's decision, 2026-08-07. The
current chunker's known defects (below) are accepted for the baseline run; they
are recorded so the numbers are read with them in mind, not so they are fixed
first. Measuring the improvement is exactly what the chunk snapshot exists for.

---

## 🔴 Blocking — data integrity

**The corpus half of this was fixed on 2026-08-06.** It now carries the
regulation's own paragraph numbering, rebuilt from docling's document tree. The
*other* half of the same defect — the **chunker** re-deriving structure from a
string with `\d+\.\s+` — is real, documented below, and **deliberately deferred**
per the priority order above.

- [x] ✅ **Regenerate the corpus from the docling *document tree*, not its markdown
  — done 2026-08-06** (`b69a79c` parser, `78a58bb` corpus).
  Found by Bertan on 2026-08-05 reading `gdpr.docling.md`; full analysis, worked
  example and reconstruction plan in
  [`dev-log/devlog_2026-08-05_session-1.md`](dev-log/devlog_2026-08-05_session-1.md),
  and the outcome in
  [`dev-log/devlog_2026-08-06_session-1.md`](dev-log/devlog_2026-08-06_session-1.md).

  **Outcome, measured.** 99 articles numbered 1..99, paragraph numbering
  contiguous in every one. 59 of 99 articles changed; content 187,287 → 185,466
  chars. Prose is byte-identical to the markdown path in **96 of 99** once
  numbering and bullets are stripped — the three that differ (articles 5, 43, 79)
  differ by exactly the footnote each now drops. Golden-set QA: clean cases
  **299 → 319**, ungrounded **134 → 114**, exact unchanged at 285, **zero
  regressions**. Chunk count 563 → 368 with the chunker untouched.

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

  **Correction, 2026-08-06: 20 cleared, not 26.** The 26 was never a measurement
  of this defect — it counted quotes that failed *grounding* after stripping
  spurious enumeration numbers, and this file already flagged it as "a floor on a
  different quantity". Recorded here so the prediction is not quietly remembered
  as having been met.

- [ ] ⏸️ **Make the chunker hierarchy-aware. `article_to_chunks` still re-derives
  structure from a string, and Article 4 shows what that costs.**
  Designed with Bertan 2026-08-06; the recursive-descent shape and the
  stem-repetition rule are his. Nothing implemented.

  **Deferred to a future iteration — Bertan, 2026-08-07.** This is an algorithm
  improvement, not a blocker on the eval pipeline. The baseline runs on the
  chunker as it stands, with the defects below known and accepted; the snapshot
  mechanism preserves that baseline so this change can be measured against it
  rather than argued for. The design below is kept complete so it can be picked
  up without re-deriving it.

  **Why the corpus fix did not fix this.** `_split_into_paragraphs`
  (`gdpr_parser.py:291`) splits `content` on `\d+\.\s+`. Correct numbering fixed
  most of it — measured on the rebuilt corpus, **50 of 61** over-budget articles
  now split into exactly their real paragraph count. The remaining 11 are the
  cases a regex over rendered text cannot reach:

  - **10 articles split on a cross-reference**, because `\d+\.\s+` cannot tell
    `22. ` in *"…rights under Articles 15 to 22. In the cases…"* from `2. `
    opening a paragraph. Articles 12, 20, 35, 36, 40, 42, 43, 58, 62, 65.
    **This is the bug already fixed one level up**: `_ARTICLE_HEADER` is
    line-anchored precisely because the original parser keyed article boundaries
    off inline `Article N` references and truncated three-quarters of the corpus.
    The paragraph splitter has the identical defect, unfixed.
  - **It fails silently and shifts every later label.** `re.split` deletes the
    number, and `metadata["paragraph"]` is the enumeration index — so one spurious
    split inside ¶2 stamps real ¶3 as `paragraph: "4"` through the end of the
    article. In those 10 articles the paragraph metadata is wrong **against a
    perfect corpus**, and nothing surfaces it.
  - **Article 4 does not split at all**, because its definitions are `(1)`…`(26)`.
    One chunk, 8,655 chars.

  ### The worked example: Article 4 before the corpus fix

  Article 4 has **no numbered paragraphs**. It has a stem, *"For the purposes of
  this Regulation:"*, and 26 definitions, three of which — (16), (22), (23) —
  have their own (a)/(b)/(c) sub-points. The old markdown corpus renumbered those
  sub-points into the surrounding ordered list, and those invented numbers became
  the chunk boundaries:

  ```
  "…'main establishment' means:\n8. (a) as regards a controller…"
  "…considered to be the main establishment;\n9. (b) as regards a processor…"
  "…personal data because:\n2. (a) the controller or processor is estab…"
  "…of that supervisory authority;\n3. (b) data subjects residing…"
  "…affected by the processing; or\n4. (c) a complaint has been lodged…"
  "…'cross-border processing' means either:\n6. (a) processing of personal data…"
  "…in more than one Member State; or\n7. (b) processing of personal data…"
  ```

  `8.` `9.` `2.` `3.` `4.` `6.` `7.` — **not one of those numbers exists in the
  regulation.** The resulting eight chunks:

  | chunk | `paragraph` | contains |
  |---|---|---|
  | `para_1` | 1 | definitions 1–16, 4,779 chars, ending on `"(16) 'main establishment' means:"` |
  | `para_2` | 2 | 4(16)(a), severed from its definiendum |
  | `para_3` | 3 | definitions **17–22** — but the chunk *opens* `"(b) as regards a processor with establishments in more than one Member State…"` |
  | `para_4` | 4 | 4(22)(a) |
  | `para_5` | 5 | 4(22)(b) |
  | `para_6` | 6 | 4(22)(c), then definition 23 |
  | `para_7` | 7 | 4(23)(a) |
  | `para_8` | 8 | 4(23)(b), then definitions 24–26 |

  Three distinct harms, and they are worth separating:

  1. **Severance inverts meaning.** `para_6` in full is *"(c) a complaint has been
     lodged with that supervisory authority;"* — 111 characters with nothing
     saying it is one of three conditions defining *"supervisory authority
     concerned"*. Retrieved alone it is a floating clause with no subject.
  2. **Retrieval by accident.** Which definition lands in which chunk is decided
     by where the serializer's fake numbers fell. *"Binding corporate rules"*
     (definition 20) is reachable only through `para_3`, whose embedding is
     dominated by processor-establishment language it opens with. The chunk cannot
     be found by the query it answers.
  3. **Fabricated citations.** Every `paragraph` value 1–8 is invented. Article 4
     has no paragraph 2. `"Article 4.2"` names something that does not exist.

  **Today, post-rebuild, Article 4 is one 8,655-char chunk.** Nothing severed and
  no fabricated numbers — strictly better — but not retrievable at definition
  granularity. This is a knowingly accepted interim state, not an oversight.

  ### What to build

  **Recursive descent with stem repetition.** Try the whole unit; if it does not
  fit the budget, descend one level and repeat the stem into each child. Applied
  at every level, not twice — Article 4 needs three (article → definition (16) →
  sub-point (a)), so the record model must nest to the document's depth rather
  than a fixed paragraph/sub-item pair.

  Article 2 is the easy case and already behaves: 1,366 chars → doesn't fit →
  four paragraphs of 247/594/324/197, all fit, ¶2 keeps (a)–(d).

  **The stem must ride along, always.** Splitting Article 9 ¶2 into ten bare
  `(a)`…`(j)` chunks re-creates `art2_case4` one level down: *"(b) processing
  relates to personal data manifestly made public…"* reads as a permission when
  the stem says *"Paragraph 1 shall not apply if one of the following applies"*.
  A 60-char stem copied into ten chunks costs nothing. **This rule is the point of
  the exercise; a chunker that splits sub-items off their stem has fixed nothing.**

  **The third level is not an edge case — 31 paragraphs across 26 articles exceed
  1000 chars:**

  ```
  art  4 ¶1: 8511 chars, 34 sub-items (the definitions)
  art 70 ¶1: 5750, 25   art 47 ¶2: 3988, 14   art 57 ¶1: 3469, 22
  art  9 ¶2: 3359, 10   art 49 ¶1: 2727,  8   art 28 ¶3: 2529,  9
  … 25 more
  ```

  **Pack at the third level, not the first.** Article 9 ¶2 becomes ~4 chunks of
  stem + consecutive sub-items rather than 10 of stem + one. But do **not** pack
  at paragraph level: the project's direction is paragraph-level citation and gold
  chunk IDs, and merging ¶3+¶4 makes `2(3)` unaddressable. A definitions article
  is the clearest case — 26 definitions should be 26 retrievable units, and today's
  `para_1` holding sixteen unrelated definitions in 4,779 chars is what packing
  looks like taken to its conclusion.

  **`art 65 ¶6` breaks pure recursion: 1,049 chars, 0 sub-items.** Over budget
  with no hierarchy to descend into. Needs a deliberate terminal rule — emit
  oversized (preferred: it is 5% over, and a sentence split severs a legal
  provision at an arbitrary point, the same class of harm being removed) or
  sentence-split as a last resort. Decide it rather than discover it.

  **Fix the budget test while you are here.** `article_to_chunks` checks
  `len(content) < 1000` but emits `f"Article {n}: {title}\n\n{content}"`, so every
  chunk exceeds the budget it passed. Measure the *rendered* text. And note the
  1000 is a retrieval-granularity choice, not a capacity limit —
  `text-embedding-3-small` accepts 8,191 tokens, so even Article 4's 8,655 chars
  would fit the model.

  **Chunk IDs become the citation surface.** `gdpr_article_2_para_2` can finally
  mean ¶2; a third-level chunk needs something like
  `gdpr_article_9_para_2_items_a-c`. Since gold chunk IDs (P0) will pin to this
  scheme, design it rather than inherit it.

  **How to measure the fix.** The chunk snapshot mechanism
  (`docs/design/chunk-snapshot-reproducibility.md`) exists for this: the current
  chunk set is a named, hashed artifact, so the *before* survives the change. Run
  golden-set QA and retrieval against both and report the delta — this is the
  first change in the project with a preserved baseline to measure against.

  **Blocked on nothing.** The corpus already carries the hierarchy this needs.

- [x] ✅ **Re-index Qdrant — done 2026-08-07** (`d7db4f9`), after being carried
  from 2026-08-02. The collection now holds exactly the
  `chunks_2026-08-07_064658_157d4d38` snapshot: **368 points, 0 orphans, 0
  missing**, advertising its hash, embedding model and vector size. The 196
  orphans were deleted — the first real use of destructive point deletion, and
  the reason `--prune` is an explicit flag with the delete re-checked afterwards
  rather than assumed. Entry below kept for the history it records.

  **Original entry.** Now
  **folded into the regeneration above** rather than a standalone task: the corpus
  is about to change again, so re-indexing the current one would be wasted. The
  soft-hyphen fix changed the content of **14 articles** after the 2026-08-01
  re-index, so those articles' chunk text and embeddings no longer match the
  corpus. Cheap (~$0.001) and idempotent: point IDs are `uuid5(namespace,
  chunk.id)`, so the write overwrites in place and the collection does not need
  dropping. Any retrieval number measured before this is against a corpus that
  does not exist.

  **2026-08-06 — quantified, and now worse.** Probed live: the collection holds
  **563 points** with `config.metadata=None`. The rebuilt corpus produces **368**
  chunks, so a re-index leaves roughly **195 orphaned points** — real GDPR text,
  embedded and searchable, from a decomposition that exists nowhere else.
  `index_chunks` (`vector_db.py:134`) already warns about surplus points but
  cannot identify *which*, so the warning ends at "drop the collection". Writing
  the chunk-set hash into each point's payload makes orphans exactly the points
  whose hash is not current — filterable, and prunable behind an explicit flag.
  Deleting points is destructive; these 195 are its first real test.
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

- [ ] 🔺 **Modify the Makefile for safe dependency upgrades** _(requested)_ —
  **Bertan, 2026-08-07: not to be postponed much longer.** The motivating case
  arrived on its own that day. `pyproject.toml` had declared `docling-core` since
  `fabe4ba` without the lock being updated, so the lock sat stale against its own
  manifest and a plain `uv run` silently re-resolved it — dirtying the tree at the
  exact moment a clean one was needed to write a chunk snapshot. Nothing in the
  repo noticed for a session. A **global cache** for `upgrade-safe` is the piece
  Bertan has been pushing for; resolution being implicit and unrecorded is what
  makes it necessary.
  - **A plain `uv sync` uninstalls pytest** — found 2026-08-07. `test` is a PEP 735
    `[dependency-groups]` entry, not `dev`, so `uv sync` excludes it and the suite
    becomes unrunnable until `uv sync --group test`. Whatever `make test` does must
    guarantee the group is present, or the target can report success over a tree
    that cannot run tests at all.
  - **Add a lock-consistency check.** `uv lock --check` (or equivalent) run in CI
    and in `make test` would have caught the `docling-core` drift immediately.
    Under the eval-flawlessness rule this matters more than usual: a snapshot's
    reproducibility claim rests on `git_dirty`, and a lock that re-resolves on use
    means an otherwise-clean tree goes dirty for reasons unrelated to the work.
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
  - **Built 2026-08-05 (`e2ebef1`):** `src/eval/sufficiency_judge.py` — stages A
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
- [ ] 🔺 **Measure check recall by mutation, systematically.** Regression tests are
  mutation-checked by hand (apply the mutation, confirm failure, restore). Worth
  making that a harness: inject known defect instances and count catches, so check
  quality is a number rather than a feeling.

  **2026-08-07 made the case, with data.** 35 mutations were run by hand across
  `chunk_store`, `generate_chunks`, `vector_db`, `docling_tree` and the tree-based
  parser. **Four survived**, and not one of them meant "add a missing test" — every
  one was a test that already existed and did not work:

  | mutation | why the existing test missed it |
  |---|---|
  | `delete_points` empty-selector guard removed | asserted *nothing was deleted*, not *no call was issued* — and an empty selector deletes nothing in a fake while being exactly the call that could delete everything against a real server |
  | `with_payload` narrowed to drop `chunk_set_sha256` | the fake ignored `with_payload` and returned the full payload, so the field never actually went missing |
  | `sorted()` dropped from `list_snapshots` | `glob` returns directory order and this directory happened to enumerate the way the assertion wanted — **passing for an accidental reason** |
  | inline paragraph-number recovery disabled | rendered `content` is byte-identical; only the *unit structure* changes, and the test asserted on the string |

  The common thread is that a test can be green for a reason unrelated to the
  property it names — through an over-permissive fake, an incidental environment,
  or an assertion aimed one layer away from the behaviour. That is invisible to
  coverage and invisible to review, and only mutation reveals it. Under
  `evaluation-plan.md` §1 this is not optional for eval code: "a gate never
  observed to fail is not known to work" applies to the gates' own tests.

  A fifth mutation exposed a different failure — the non-ASCII hash test was
  pinning a property (`ensure_ascii=False`) that is not a correctness property at
  all, since escaping stays deterministic and injective. The real requirement was
  *stability*, which only a golden value expresses. Worth having the harness
  report survivors rather than a pass/fail, so cases like that surface as
  questions about what a test is for.
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
  - ✅ **Unblocked 2026-08-07.** It was blocked on the corpus regeneration, then
    briefly on the hierarchy-aware chunker; that chunker is now deferred, so this
    pins against the **current** chunk set. `gold_chunk_ids` is a function of
    (quote, chunking config) and is recomputed at build time, so pinning now is
    not a commitment — it is a derived artifact that the snapshot hash identifies.
    **Record the `chunk_set_sha256` the IDs were derived from**, or the golden set
    silently carries IDs from a chunk set nobody can name.
  - Two costs of pinning against today's chunker, accepted knowingly: **Article 4
    is one 8,655-char chunk**, so all its cases pin to the same ID and the metric
    cannot distinguish retrieval within it; and the **10 cross-reference-split
    articles** carry wrong `paragraph` metadata, which does not affect ID equality
    but does make any per-paragraph reporting off in those articles.
  - The feasibility numbers below (294/299 pin exactly one chunk) were measured
    against the **pre-rebuild** chunking and are void. Re-derive against the first
    snapshot before relying on them.
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
- [x] ~~`generate_gdpr_articles.py` has no corpus-level invariant: it printed
  `✅ Wrote 1 articles` and exited 0 while the corpus was collapsed.~~ **Done
  2026-08-06** (`b4265f9`). `_check_invariants` enforces 99 articles numbered
  1..99, no gaps or duplicates, no empty title or content, and paragraph
  numbering contiguous 1..N per article — exiting non-zero *before* writing.
  Checks the rendered output rather than parser internals, so it validates what
  reaches disk. **Verified to fail, not only to pass:** run against the old
  markdown path it rejects 42 articles and exits 1, reporting Article 2 as
  `[1, 2, 3, 4, 5, 6, 3, 4]` — the restart-collision found by hand on 2026-08-05,
  now detected mechanically.
- [ ] `_looks_truncated` false-flags article 99 (signature block). Either teach
  it about document trailers or decide whether that block belongs in article
  content at all — currently it makes a clean validation run impossible, so any
  future flag is easy to dismiss.
- [ ] `GDPRParser._split_into_paragraphs` (`gdpr_parser.py:291`) splits on
  `\d+\.\s+`, which (a) makes every spurious sub-item number a chunk boundary and
  (b) *deletes* the numbers, so paragraph identity survives neither in the text
  nor in `metadata["paragraph"]`, which holds a sequential index instead.
  **Superseded 2026-08-06 by the 🔴 hierarchy-aware chunker item**, which covers
  this and more: the corpus rebuild fixed (a) for 50 of 61 articles but left the
  cross-reference splits and Article 4 untouched, and (b) is unchanged. Do not
  patch the regex — it is the wrong layer.
- [x] ~~**Nothing writes `chunk_set_sha256` into Qdrant yet.**~~ **Done
  2026-08-07** (`d7db4f9`). `set_collection_metadata` writes it on every index
  run — `create_collection` no-ops when the collection exists, so metadata passed
  there would only ever be written by the run that created it — and it is written
  **last**, after `index_chunks` verifies its count and after orphans are gone. A
  run that leaves orphans exits non-zero writing nothing: a collection
  advertising a snapshot it only partly holds is worse than one advertising
  nothing, because the first is trusted and wrong.
- [x] ~~**The chunk-set hash does not cover the embedding model.**~~ **Closed
  2026-08-07** by recording `embedding_model` and `vector_size` in the collection
  metadata alongside the hash. The gap was real: identical chunks through
  different models give different vectors and different retrieval while both
  collections would honestly advertise the same `chunk_set_sha256`. The schema is
  fixed up front rather than grown, because `update_collection` **merges rather
  than replaces** — a key written once persists until explicitly overwritten, so
  a renamed key leaves its predecessor behind advertising a value nothing
  produced. Pinned by `test_collection_metadata_merges_rather_than_replaces`.
- [ ] **Tests cover `git_state` only; the rest of `chunk_store.py` and all of
  `generate_chunks.py` are still unguarded.** Every property was verified by hand
  on 2026-08-06 — determinism under randomized `PYTHONHASHSEED`, byte-identical
  regeneration, tamper detection, `git_state` across six tree states — and none of
  it was guarded by the suite. Full list of what was observed:
  `docs/design/chunk-snapshot-reproducibility.md` §4.

  **`git_state` closed 2026-08-07** (`c67e266`), and the hand-verification is
  exactly what it took to show why hand-verification is not enough: those six tree
  states missed a bug that made the manifest name a file that does not exist.
  `run()` stripped `git status --porcelain` output, which deletes the leading
  space of the *first* line's index column, so `" M uv.lock"` sliced to `"v.lock"`.
  Writing the tests then surfaced a second one — plain `--porcelain` C-quotes paths
  containing a space or non-ASCII byte, recording `'"a file.txt"'` — fixed by
  reading with `-z`. `tests/test_chunk_store.py`, 10 tests, mutation-checked at
  6-of-10 failing against the pre-fix code. Suite 81 → 91.

  **The rest closed 2026-08-07** (`efd2f09`): `chunk_set_hash` (determinism,
  insensitivity to generation order and metadata key order, sensitivity to
  id/text/metadata, cross-process stability, golden values),
  `write_snapshot`/`read_snapshot` (round trip, generation order, tamper
  detection on text *and* metadata, truncation, count disagreement, missing
  manifest), `build_manifest`, snapshot naming and discovery, and every
  invariant in `_check_chunks`.
- [x] ~~**No tests cover the tree-based parser either.**~~ **Closed 2026-08-07**
  (`50d8eb8`). `docling_tree.py` and `GDPRParser.get_articles_from_dictionary`
  are covered by synthetic trees, one structural hazard each, every one
  mirroring a shape verified against `gdpr.docling.json`. The `visited` guard
  gets its own tests precisely because the real export **cannot** exercise it —
  it has no nesting anywhere, so nothing there would notice its removal.
- [ ] **`src/clause_and_effect/__init__.py` imports the world eagerly**, found
  2026-08-07. `from .agents/.parsers/.retrieval import *` pulls docling,
  langchain, openai and qdrant, so importing a pure-stdlib module like
  `chunk_store` costs **~17 seconds**. Every test run pays ~14s before doing
  anything, and it is why the cross-process hash test is a single invocation
  rather than a sweep of seeds. A regression suite is meant to be cheap enough
  to run on every change; this is the main thing making it not. Lazy imports, or
  importing submodules directly rather than re-exporting, would fix it.
- [ ] `src/config.py` `get_llm_config()['writer_model'][1]` is **broken**:
  `ModelNames.GPT_OSS_120B` has no OpenRouter alias in `ai_common`
  (`MODEL_NAME_ALIAS_DICT` lists groq and ollama only), so `get_llm` raises
  `KeyError: <LlmServers.OPENROUTER>` on construction. Found 2026-08-05 while
  picking a judge model. Only DeepSeek V3.2/V4-Flash and Gemini 3.1 Flash-Lite are
  reachable over OpenRouter today, which also constrains judge-panel diversity.
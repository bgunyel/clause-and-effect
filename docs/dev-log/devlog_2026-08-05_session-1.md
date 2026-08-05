# Devlog — 2026-08-05 · session 1

**Branch:** `dev-02`, 25 commits ahead of `main` · `33b4c6d` → `08d6edb`
(5 commits this session, all made after this entry was written)
**Theme:** The sufficiency judge reached stage B, and stage B's first clean result
pointed at a corpus defect that had been invisible to every gate: docling's
markdown serializer destroys the paragraph hierarchy inside 43 of 99 articles
**Tests:** 81 passed, unchanged
**Gate:** unchanged — 285 exact / 14 normalized / 134 ungrounded, 299 of 433 clean

---

## The sufficiency criterion was settled, and it is the weaker of the two readings

The 2026-08-03 session left the target undecided: *question answerable from quote*
versus the stronger *answer entailed by quote*. Bertan settled it on `art7_case3`:

> The answer in article 7, case 3 actually gives more than enough (or more than
> asked). For that test case, the shortest sufficient answer is *"Yes, the data
> subject shall have the right to withdraw their concent at any time"*. The second
> part of the question is auxiliary information which strengthens the statement.

So the criterion is **every question must be answerable using only its
`supporting_quote`**, and a gold `answer` may carry claims the quote does not
support without that being a defect.

The assistant measured how much this decides before designing around it. Of 433
cases, **283 have a gold answer of two or more sentences**, and **175 have at least
one answer sentence poorly covered by their quote** (fewer than half its content
words present, stopwords removed). Under the stronger reading roughly 40% of the
set is a candidate failure; under Bertan's ruling most of that is auxiliary
surplus. That is the difference between a repair set near 169 and one near 300, and
it is why the core-versus-auxiliary distinction became a first-class output of the
judge rather than a refinement of it.

`art7_case3`'s surplus clause is not loose text: it is, verbatim, the
`supporting_quote` of `art7_case4`. It is article-supported, just not
quote-supported — which is exactly the distinction the judge has to be able to draw.

---

## The judge: three blinded stages, built one at a time

Bertan asked for step-by-step delivery with review between steps, and set the file
under `src/eval/` beside `golden_qa.py` rather than in `src/scripts/` — the
deterministic gates and the judge tier are siblings. New file:
`src/eval/sufficiency_judge.py` (uncommitted).

| stage | sees | withheld | returns |
|---|---|---|---|
| **A — Decompose** | question, gold `answer` | the quote | shortest sufficient answer; claims tagged `core`/`auxiliary` |
| **B — Answer blind** | question, `supporting_quote` | article, gold answer | minimal span, answer, `answered`, note |
| **C — Adjudicate** | question, tagged claims, blind answer | the quote | per-claim supported / contradicted / absent |

Blinding is **structural, not instructed**: each prompt is rendered from only the
fields that stage is allowed to see, so a prompt cannot leak what it was never
given. Each panel member is to run A→B→C independently and vote, so disagreement
becomes the calibration signal rather than noise to be averaged away (§6.2).

Steps 1–3 are done. Steps 4–8 (adjudicator, verdict derivation and panel
aggregation, async runner, calibration sample, tests) are not started.

Verdict vocabulary, defined but not yet derived anywhere: `sufficient`,
`sufficient_verbose`, `insufficient`, `contradicted`. `contradicted` is kept
separate from `insufficient` deliberately — evidence pointing *away* from the
answer is a worse defect than evidence merely missing, and it implicates the
answer as well as the quote.

### The assistant's first tagging rule was wrong, and failed on the case the criterion came from

Stage A's first implementation used a leave-one-out removal test: *delete this
claim; does what remains still answer the question?* Run against `art7_case3` it
returned **zero core claims**. Applied one claim at a time, *"Yes."* was excused
because the substantive clause remained, and the substantive clause was excused
because *"Yes."* remained.

Leave-one-out cannot see mutual redundancy: it marks both members of a redundant
pair removable, though removing both destroys the answer. This is a property of the
test, not of that case — any answer containing a redundant pair would have done it,
and a spot check on a friendlier case would have missed it entirely.

The replacement came from Bertan's own wording. The judge now **writes the shortest
sufficient answer first**, then tags each claim by whether its content appears in
it. That is the same principle already carrying stage B: make the judge *perform*
the task rather than opine on it. Re-run, `art7_case3` produced:

```
shortest sufficient answer: Yes. The data subject shall have the right to withdraw
                            their consent at any time.
   [core     ] Yes. The data subject shall have the right to withdraw their consent
               at any time.
   [auxiliary] The withdrawal of consent shall not affect the lawfulness of
               processing based on consent before its withdrawal.
```

That is Bertan's sentence returned unprompted. `art7_case3` is deliberately **not**
in the prompt — the obvious worked example to include would have been the very case
the criterion was settled on, which would have destroyed its value as a check on
whether the judge agrees with the ruling. No worked example is used at all; adding
one is a fix for inconsistency that has not been observed.

Two amendments to the step-1 types came out of this and were flagged rather than
slipped in: `Claim` gained `reason`, and `Decomposition` gained
`shortest_sufficient_answer` — kept rather than discarded because it is the
auditable trace of *why* a claim came out core.

### Stage B: parametric leakage was the risk, and the defence held

The dominant failure mode for stage B is that the judge knows GDPR and will answer
from memory when the quote does not support it. Two structural defences were built:

1. **The regulation is never named.** The prompt says "EXCERPT of legal text", and
   states outright that answering from prior knowledge is the failure being tested —
   *"an answer that is correct in law but absent from the EXCERPT is a wrong answer
   here."*
2. **The span is copied before the answer is written.** Producing the answer first
   invites the model to find evidence fitting a conclusion it already holds;
   producing the span first means there is nothing to answer from until it has
   found text.

`art2_case4` is the case this was built for. Its quote is a verbatim fragment of
Article 2 listing law-enforcement purposes, containing no negation, while its gold
answer is *"No, GDPR does not apply…"*. Any model that knows Article 2(2)(d) can
supply the missing "No". It did not:

```
-- stage B: answered=False  span verbatim=True  245/245 chars
   answer: The excerpt does not directly state whether GDPR applies to law
           enforcement agencies investigating criminal offences...
   note:   The excerpt concerns the right subject ... but does not state whether
           GDPR applies. It appears to be a definition or scope provision from a
           related instrument (possibly the Law Enforcement Directive)...
```

The model recognised the text, reasoned about its provenance, and still refused to
answer beyond it. If parametric leakage were going to sink this design it would have
sunk it there.

Across the eight probe cases, **8 of 8 returned spans were verbatim**. By this
project's own rule that is *unverified*, not *working*: `span_is_verbatim` has never
been observed to fail, so it is not known to work. Step 8 must mutate it.

Span shrink ratios, the raw material for the `sufficient_verbose` threshold, spread
widely enough that the threshold will be measurable rather than arbitrary:
`art8_case1` 34/181 (19%), `art33_case1` 96/297 (32%), `art41_case3` 101/213 (47%),
and four cases with no shrink at all.

`span_is_verbatim` reuses `normalize_for_grounding` from `golden_qa` rather than
reimplementing matching, so the judge and the grounding gate cannot drift apart on
what "the same text" means — as §3.1's open item requires of the retrieval scorers.

### Two backlog entries corrected by stage B output

The backlog lists `art41_case3` and `art8_case5` as *"invalid case, not a quote
defect"* — questions the article cannot answer, to be rewritten or removed. Stage B
answered both cleanly from their quotes, so the **questions are fine**. Checking each
quote fragment against the whole corpus:

- **`art41_case3`** — its quote appears in **no article at all**. A
  maximum-period-of-five-years accreditation rule is not Article 41 (monitoring of
  approved codes of conduct); it reads like Article 43's certification-body rule. So
  this is a mis-pointed `article_number` or text drawn from outside the corpus, not
  an invented question.
- **`art8_case5`** — the quote has two fragments joined by `...`. The **first is in
  Article 8**; the **second is in no article**. The backlog's "quotes Recital 38"
  is therefore right about the second fragment and wrong about the case as a whole.
  An intermediate claim by the assistant that the backlog entry was simply wrong was
  itself wrong, and is corrected here.

Both still need the PDF check the backlog demands before anything is rewritten.
Neither data file was touched.

---

## Bertan found the defect that overtakes all of it: docling flattens the hierarchy

Reading `data/regulations/gdpr.docling.md`, Bertan established that the within-article
structure present in the source PDF is destroyed by docling's markdown output, and
gave Article 2 as the example. In the regulation, Article 2 has four numbered
paragraphs, and ¶2 has four lettered sub-items (a)–(d). The markdown has this:

```
340: 1. This  Regulation  applies  to  the  processing  of  personal  data ...
341: 2. This Regulation does not apply to the processing of personal data:
342: 3. (a)   in  the  course of an activity which falls outside the scope of Union law;
343: 4. (b)   by the Member States when carrying out activities which fall within ...
344: 5. (c)   by a natural person in the course of a purely personal or household activity;
345: 6. (d)   by  competent  authorities  for  the  purposes  of  the  prevention, ...
346: 3. For  the  processing  of  personal  data  by  the  Union  institutions ...
347: 4. This  Regulation  shall  be  without  prejudice  to  the  application  of ...
```

| line | emitted | actually is |
|---|---|---|
| 340 | `1.` | ¶1 |
| 341 | `2.` | ¶2 stem |
| 342–345 | `3.` `4.` `5.` `6.` | ¶2(a) (b) (c) (d) |
| 346 | `3.` | ¶3 |
| 347 | `4.` | ¶4 |

It is not a flat 1–8 relabelling. The numbering **restarts** where the real list
resumes, so within one article `3.` denotes both ¶2(a) and ¶3, and `4.` denotes both
¶2(b) and ¶4. "Article 2(3)" is unresolvable from corpus text.

### Three distinct damages, measured

Measured over `data/regulations/gdpr_articles.json`:

| | |
|---|---:|
| articles where a numbered line is really a lettered sub-item | **43 / 99** |
| articles carrying a genuine paragraph-number collision | **41 / 99** |
| articles whose real numbering reconstructs from markdown alone | **82 / 82** |

1. **Hierarchy loss** — sub-items are promoted to paragraph level, orphaning the
   stem that governs them.
2. **Number collision** — in 41 articles one number denotes two different things.
3. **Chunk severance** — the worst of the three, and the reason this is not merely
   a formatting complaint.

### The chunker turns a formatting defect into a retrieval-correctness defect

`GDPRParser._split_into_paragraphs` (`gdpr_parser.py:291`) splits on `\d+\.\s+`, so
every spurious number becomes a chunk boundary. Article 2 is indexed today as eight
chunks:

```
[gdpr_article_2_para_2] para=2   This Regulation does not apply to the processing of personal data:
[gdpr_article_2_para_3] para=3   (a) in the course of an activity which falls outside the scope of Union law;
[gdpr_article_2_para_4] para=4   (b) by the Member States when carrying out activities ...
[gdpr_article_2_para_5] para=5   (c) by a natural person in the course of a purely personal or household activity;
[gdpr_article_2_para_6] para=6   (d) by competent authorities for the purposes of the prevention, ...
```

`para_6` is ¶2(d) severed from the stem that negates it. Standing alone it reads as
a *positive* statement of scope. **A perfect retriever returning that chunk hands the
generator text meaning the opposite of what it says in context** — which is the exact
failure this project exists to detect, sitting in the index the whole time.

Two further consequences:

- `metadata["paragraph"]` is a **sequential index mislabelled as a paragraph
  number**. Chunk `para_6` is really ¶2(d). Any paragraph-level citation metric would
  be scored against wrong labels in 43 articles.
- The regex also *deletes* the numbers, so paragraph identity is not recoverable
  from chunk text either.

### This explains `art2_case4` rather than blaming it

The backlog treats `art2_case4` as a quote chosen badly. It is not. Its quote **is**
¶2(d); the negation lives in the ¶2 stem, four lines earlier, separated by (a), (b)
and (c). **No contiguous substring of the corpus can satisfy the sufficiency
criterion for that case.** The span-list decision for `supporting_quote` and the
hierarchy decision are therefore the same decision, and stage B's `answered=False`
was correct for a reason nobody had identified.

### Correction to a figure already in the backlog

The recorded "26 of 134 grounding errors are traceable to line numbering" counts
only quotes that fail *grounding*. Chunk severance never fails grounding — Article
2's text is intact and only its segmentation is wrong — so the retrieval damage is
entirely invisible to that number. 26 is a floor on a different quantity, not a
measure of this defect.

---

## The solution: reconstruct the corpus from docling's document tree, not its markdown

Bertan supplied `data/regulations/gdpr.docling.json` (1.4 MB, untracked), the
intermediate document-tree output of the same docling run, and identified its shape:
a `#/body` root whose children are `#/groups/N` and `#/texts/N` references, with 171
groups and 1623 text items.

Article 2 lives there as headings `#/texts/365` ("Article 2") and `#/texts/366`
("Material scope"), and a list group `#/groups/35` holding `#/texts/367` … `374`:

| item | `label` | `enumerated` | `marker` | is |
|---|---|---|---|---|
| texts/367 | `list_item` | `true` | `"1."` | ¶1 |
| texts/368 | `list_item` | `true` | `"2."` | ¶2 stem |
| texts/369–372 | `list_item` | **`false`** | `""` | (a) (b) (c) (d) |
| texts/373 | `list_item` | `true` | `"3."` | ¶3 |
| texts/374 | `list_item` | `true` | `"4."` | ¶4 |

**The real paragraph numbers survive intact in `marker`: 1, 2, 3, 4, no collision.**
The 3/4/5/6 in the markdown were invented by the *serializer*, which renumbered
non-enumerated list items sequentially while rendering them into one ordered list.
Extraction was never the problem; rendering was.

One text item in full, `#/texts/367`:

```json
{
  "self_ref": "#/texts/367",
  "parent": {"$ref": "#/groups/35"},
  "children": [],
  "label": "list_item",
  "prov": [{"page_no": 32, "bbox": {...}, "charspan": [0, 286]}],
  "orig": "1. This  Regulation  applies  to  the  processing  of  personal  data ...",
  "text": "This  Regulation  applies  to  the  processing  of  personal  data ...",
  "enumerated": true,
  "marker": "1."
}
```

Three fields the markdown path has no equivalent of:

- **`orig` vs `text`** — `orig` keeps the number inline, `text` has it stripped and
  promoted into `marker`. Their consistency is itself a signal: items where this
  promotion did *not* happen are exactly the ones parsed imperfectly.
- **`prov`** — `page_no` and `charspan` into the PDF text layer, per item. `orig` is
  286 characters and `charspan` is `[0, 286]`, so `orig` is the verbatim source
  range. This makes the PDF verification the backlog demands for `art41_case3`
  mechanical rather than manual.
- The **OCR double-spacing is present in both `orig` and `text`** (36 doubled runs in
  this one item, irregularly placed — `"This  Regulation  applies"` doubled but
  `"form part of a filing system"` single). It originates upstream of any
  serialization choice, so switching source neither fixes nor worsens it.

### What the JSON does *not* give, all verified

The tree is a better source, not a clean one. Four complications were measured, and
each needs handling in the reconstruction:

1. **Hierarchy is inferred, not encoded.** Every text item has `children: []` and no
   group contains another group — **0 nesting in 1623 texts and 171 groups**.
   "(a)–(d) belong to ¶2" is a rule *we* impose on a flat sibling list, not something
   read off the tree.
2. **Some paragraphs are not list items.** 41 items inside articles carry
   `label: "text"` with the number left inline in the string. Article 9 is the
   clearest: `[text] "1. Processing of personal data revealing racial…"` followed by
   `[list_item enumerated=true marker="2."]`. A rule reading only `list_item.marker`
   silently drops ¶1 — the cause of the irregular marker runs in articles **9, 18,
   35, 57, 58**.
3. **Article 28 recurs.** Its header is `[text] #/texts/746 'Article 28'`, not a
   `section_header`. A `section_header`-only walk finds **98** articles and folds
   Article 28's ten paragraphs into Article 27, producing the run
   `['1'…'5','2'…'10']`. This is the same Article 28 quirk the 2026-08-01 post-mortem
   recorded for the markdown path — same root cause, different serialization.
   **Widening the boundary rule to accept `label: "text"` was tested and finds all 99
   articles with no gaps**, and Article 27's spurious run disappears.
4. **Sub-items do not always follow a numbered paragraph.** Article 50 has no
   numbered paragraphs at all — a `text` stem followed by (a)–(d), giving 4 orphans
   under a naive rule. Article 4 has the same shape: a `text` stem *"For the purposes
   of this Regulation:"* followed by definitions `(1)`…`(26)` as
   `enumerated: true, marker: "(1)"`. So the attach rule must be **nearest preceding
   item**, not nearest preceding *enumerated* item.

Marker vocabulary across 925 list items: **363** `N.` (article paragraphs), **199**
`(N)` (recitals *and* Article 4's definitions), **359** `""` on `(x)` sub-items,
**4** `-` (Article 53's parliament/government list, the one `_LIST_MARKER` in
`golden_qa` normalizes).

### The argument for switching is detectability, not cleanliness

The JSON's failures are **loud**. With markdown, hierarchy loss was invisible: the
text was intact and only segmentation was wrong, so no gate could see it. With
`marker`, the invariant *"every article's paragraph markers form 1..N with no gaps
and no repeats"* fails on precisely the six irregular articles. That is the same
missing corpus-level assertion the backlog already wants for
`generate_gdpr_articles.py`, which once printed `✅ Wrote 1 articles` and exited 0
over a collapsed corpus.

---

## What the next session should build

Agreed with Bertan: **regenerate the articles from `gdpr.docling.json`**. Concretely:

**1. Walk the tree in document order.** Resolve `$ref` strings against `texts`,
`groups`, and `#/body` (which is in neither dictionary and must be special-cased —
this raised `AttributeError` on the first attempt). Depth-first over `children`
preserves document order.

**2. Detect article boundaries on text, not label.** Match `^Article\s+(\d+)$`
against items whose label is `section_header` **or** `text`. Verified: this yields
99 articles, 1–99, no gaps. Assert that and exit non-zero otherwise — the invariant
`generate_gdpr_articles.py` has always lacked. Everything before Article 1 is
recitals and is skipped by construction, since no article is open yet.

**3. Classify each item within an article.**

| item | rule | becomes |
|---|---|---|
| `list_item`, `enumerated`, `marker` matches `^\d+\.$` | new paragraph, number from `marker` | ¶N |
| `text` whose string starts `^\d+\.\s` | paragraph whose number stayed inline; strip and use it | ¶N (Article 9(1)) |
| `list_item`, not `enumerated` | sub-item; attach to nearest preceding item | ¶N(a) |
| `list_item`, `enumerated`, `marker` matches `^\(\d+\)$` | sub-item; attach to nearest preceding item | Article 4's definitions |
| `text` with no leading number | unnumbered stem or trailing prose; attach or keep in order | Article 50's stem |

**4. Assert the numbering invariant per article** — paragraph numbers must be 1..N,
contiguous, no repeats. Articles **9, 18, 28, 35, 57, 58** will fail until rule 3's
`text` arm is in place; they are the acceptance test for it, not surprises to work
around.

**5. Emit a structured corpus.** Paragraph identity should become real data —
`2(2)(d)` rather than today's `para=6` — with each unit carrying its `prov`
(`page_no`, `charspan`) so PDF verification is mechanical. Keep `text` rather than
`orig` for content, since the number is already promoted out of it, and strip
manually only for the `text`-labelled arm.

**6. Re-use the existing cleaners.** `_rejoin_hyphenated_words` and the whitespace
collapse in `_clean_content` still apply — the OCR damage is in `orig` and `text`
alike. Note that `_clean_title` still does not collapse double spacing, which is the
open three-title item (articles 12, 60, 89).

**7. Chunk stem-with-items.** A paragraph and its sub-items are one retrieval unit.
This is what fixes `art2_case4` at the source, and it is the point of the whole
exercise — not tidier text, but chunks that do not invert their own meaning.

**Consequences to plan for, not discover:** the corpus content changes, so **every
number measured before it is void again** (the same warning as 2026-08-01); Qdrant
needs re-indexing (still not done from 2026-08-02); golden-set QA must be re-run and
the 134 ungrounded re-derived — 26 of them are predicted to clear. The gold-chunk-ID
design (P0) should wait for this, since pinning quotes to chunk IDs against today's
chunking would fix them to a decomposition wrong in 43 articles.

**One caveat to carry.** The reconstruction check proves *consistency*, not
*fidelity*: markers forming 1..N does not prove N is right, and a paragraph docling
dropped entirely would still reconstruct cleanly. Per the `art36_case4` lesson this
rules out one link in the chain and no more. Confirming paragraph counts against the
PDF is a separate job, now made cheap by `prov`.

---

## Decisions

- **Sufficiency target is *question answerable from quote***, at Bertan's direction.
  A gold answer may carry auxiliary claims the quote does not support.
- **The judge lives in `src/eval/`**, beside `golden_qa.py` — deterministic gates and
  judge tier are siblings, and `golden_qa` stays free and runnable on every change.
- **Build step by step with review between steps**, at Bertan's direction, after he
  reversed an earlier decision to implement it himself.
- **Tag by writing the shortest sufficient answer first**, not by leave-one-out
  removal, because leave-one-out is blind to mutual redundancy.
- **No worked example in the stage-A prompt.** The natural example is the case the
  criterion was settled on, and using it would destroy its value as a check.
- **Stage B never names the regulation** and copies its span before answering.
- **`contradicted` stays a separate verdict** from `insufficient`.
- **`minimal_span` is a single continuous run**, conservatively — multi-span evidence
  is a pending schema decision for `supporting_quote` itself and this stage should
  follow it rather than pre-empt it.
- **Regenerate the corpus from `gdpr.docling.json`** rather than patch the markdown
  path. Agreed at the end of the session; nothing built.
- **DeepSeek V4 Flash for now**, at Bertan's direction — panel composition is a
  post-implementation decision.

---

## Mistakes made this session

Attributed, per this log's convention. All are the assistant's unless stated.

- **The stage-A removal test was a bad design**, and it failed on `art7_case3`,
  the one case whose answer was already known. Caught only because the assistant ran
  it on that case before moving on; a friendlier probe would have passed.
- **Proposed `src/scripts/` for the judge.** Bertan moved it to `src/eval/`, which is
  obviously right given `golden_qa.py` lives there.
- **Asserted the backlog was wrong about `art8_case5`** on the strength of its first
  quote fragment matching Article 8. The second fragment matches no article, so the
  backlog's "Recital 38" note is right about that fragment. Corrected above.
- **Wrote a memory recording that Bertan implements designs himself**, generalising
  from a single message he reversed the same day. Deleted and replaced.
- **Asked three design questions at once** — calibration sequencing, panel
  composition, and whether `UNANSWERABLE` belongs in the pass — when Bertan wanted to
  clarify the premises first. The panel question rested on an unverified assumption
  about which model generated the Tier-1 data, which the assistant flagged only after
  being asked.

Bertan's catches this session were the two that mattered most: settling the
sufficiency criterion on a concrete case rather than in the abstract, and finding the
docling hierarchy defect by reading the source markdown — a defect no gate in the
repository could have surfaced, because every gate checks text and this one destroys
structure.

---

## State handed to the next session

| | |
|---|---|
| Corpus | 99 articles, 187,287 chars — **hierarchy flattened in 43 of 99**, collisions in 41 |
| New source | `data/regulations/gdpr.docling.json`, 1.4 MB, untracked — 171 groups, 1623 texts |
| Qdrant | `compliance_docs`, **still stale** — 14 articles changed 2026-08-02, never re-indexed; and now due for a full rebuild |
| Golden set | 285 exact · 14 normalized · 134 ungrounded · 0 leakage · 0 self-containment · 299/433 clean |
| Sufficiency judge | stages A and B built and eyeballed on 8 cases; C, verdicts, runner, calibration, tests not started |
| Tests | **81 passed**, no xfails |
| Working tree | clean — `c58a5a1` `tmp/` ignore · `552c7df` `gdpr.docling.json` (1.4 MB, tracked like `gdpr.docling.md`; only the PDF is kept local) · `e2ebef1` judge stages A/B + `golden_qa.py` import made absolute · `84762f4` this entry · `08d6edb` backlog |

**Open, roughly in order:**

- **Regenerate the corpus from the document tree**, per the seven steps above. This
  now precedes the rest of the eval work, because chunk severance corrupts retrieval
  itself and not just the eval set.
- **Re-index Qdrant.** Carried untouched across three sessions; now folded into the
  regeneration rather than standing alone.
- **Finish the sufficiency judge** — stage C, verdict derivation and the
  `sufficient_verbose` threshold (measure it, do not guess), async runner, calibration
  sample, tests. Still undecided: calibration sequencing, panel composition, and
  whether an `UNANSWERABLE` verdict belongs in this pass given stage B is blind to the
  article.
- **`src/config.py` `writer_model[1]` is broken** — `GPT_OSS_120B` has no OpenRouter
  alias in `ai_common` (groq and ollama only), so constructing it raises `KeyError`.
  Pre-existing, found while picking a judge model.
- **Span lists for `supporting_quote`** — now the same decision as the hierarchy fix,
  since `art2_case4` cannot be expressed as one contiguous span under any chunking.
- **Gold chunk IDs (P0)** — blocked on the regeneration.
- **58 quotes to rewrite**, with `art41_case3` re-classified: the question is sound
  and the quote belongs to no article in the corpus. Verify against the PDF, now
  cheap via `prov`.
- **Commit the quote classifier**; **reconcile §3.1**; **constrain the generator**;
  **systematise mutation testing** — all carried unchanged from 2026-08-03.
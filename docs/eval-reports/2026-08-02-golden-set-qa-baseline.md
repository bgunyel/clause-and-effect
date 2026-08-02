# Golden-set QA — corrected-corpus baseline

**Date:** 2026-08-02 · **Branch:** `dev-02` · **Corpus:** 99 articles, 187,287 chars
**Command:** `python -m src.eval.golden_qa` — fully deterministic, **no LLM calls, no spend**

Answers the blocking backlog item: of the 246 quote-grounding errors recorded before
the corpus fix, how many were **caused by the truncation bug** versus **genuine
golden-set defects**?

Two corpus fixes are measured here, in the order they landed: the **truncation fix**
(`9ecdf6f`/`bc63974`, last session) and the **soft-hyphen fix** (this session, found
while classifying the residue of the first).

---

## Headline

| | pre-fix (`bc63974^`) | truncation fixed | + soft-hyphen fixed | total Δ |
|---|---|---|---|---|
| cases checked | 433 | 433 | 433 | — |
| clean cases | 176 | 267 | **270** | +94 |
| quote-grounding **errors** | 246 | 151 | **148** | **−98 (−39.8%)** |
| quote-grounding **warnings** | 176 | 2 | 2 | −174 |
| leakage errors | 18 | 18 | 18 | 0 |
| gate | FAIL | FAIL | **FAIL** | — |

Every figure is measured, not remembered: the pre-fix column comes from running the same
gate against `git show bc63974^:data/regulations/gdpr_articles.json`. The 246 baseline
reproduced exactly.

**95 of 246 quote-grounding errors (38.6%) were false failures caused by the truncated
corpus — not defects in the eval set.** The distinction matters: those 95 test cases
were correct all along. Pre-fix, 76 of 99 articles were cut short at their first inline
`Article N` cross-reference, so a golden quote drawn from the full regulation extended
past the cut and `quote in source` could not find it. The gate was reporting a corpus
defect in the vocabulary of a test-case defect.

The warning count collapsing 176 → 2 is the other half of the same story — those were
quotes that matched only after whitespace normalization, and the corrected parser now
collapses OCR double-spacing at the source.

Per-case transition, which the net figure would otherwise hide:

```
174  warning -> ok        95  error -> ok        11  ok      -> ok
151  error   -> error      2  warning -> warning

errors resolved: 95     errors introduced: 0
```

**No case regressed.** `246 → 151` is a genuine improvement, not a net of offsetting
movements in both directions.

The soft-hyphen fix then cleared three more — `art4_case10`, `art9_case8`,
`art44_case3` — again with zero regressions. Small, and expected to be: only three of
the 18 soft-hyphen-affected cases had the hyphen as their *sole* remaining defect. Its
real payoff is downstream, not here (see below).

Leakage is unchanged across both fixes, as expected: it is a property of the question
text and cannot be affected by anything done to the corpus. That it moved by exactly
zero, twice, is a useful control.

---

## The 148 remaining errors, by root cause

Classified by testing four hypotheses in order, each strictly weaker than the last,
with matching done formatting-insensitively (case, punctuation, whitespace, and OCR
soft-hyphens normalized away):

Segment order is **enforced**: a run only counts if it starts after the previous run
ends, so a quote that reassembles article text out of sequence cannot be classified as
faithful elision.

| count | share | root cause |
|---:|---:|---|
| 76 | 51.4% | **faithful elision** — multi-span, every word verbatim and in sequence (with or without an explicit `...`) |
| 37 | 25.0% | **text altered** — every word appears in the article, but not in this order; reordered or reworded |
| 20 | 13.5% | **text absent** — contains words that appear nowhere in the gold article |
| 15 | 10.1% | **typography** — contiguous in the article; only punctuation or case differs |

**91 of 148 (61.5%) are recoverable by an elision/typography-tolerant grounding tier** —
the 76 faithful-elision cases plus the 15 typography ones. The other **57 (38.5%)
require the quote text itself to be rewritten**, because a subsequence check would not
pass them either: subsequence requires order, and these cases violate it.

The soft-hyphen fix moved only the typography bucket (18 → 15). The other three
categories are byte-for-byte unchanged, which is the expected result — a broken word
inside the article could only ever affect quotes that were otherwise contiguous.

> **Correction.** An earlier revision of this report claimed 131 of 151 (86.8%)
> recoverable. That number came from a classifier that checked whether each segment
> existed *somewhere* in the article without requiring the segments to advance in
> order, so it counted reordered and reworded quotes as faithful stitching. The figures
> above supersede it.

The 37 altered cases are lightly edited rather than invented, which is why they are easy
to miss. Two verified examples:

- `gdpr_art25_case2` — **reordered.** Article: *"the controller shall, both at the time
  of the determination of the means for processing and at the time of the processing
  itself, implement appropriate technical…"*. Quote moves the subject across the
  temporal clause: *"both at the time of … itself, the controller shall implement…"*.
  Semantically faithful, textually not the regulation.
- `gdpr_art27_case1` — **reworded.** Article: *"mandated by the controller or
  processor"*. Quote: *"mandated by the controller or **the** processor"*.

Both would read as perfectly good citations to a human, which is precisely the risk: an
LLM-generated evidence span that has been silently normalized is indistinguishable from
a real one without an exact check.

Span-count distribution for the 76 faithful-elision cases — most are two- or three-span
joins, not wholesale reassembly:

```
spans: 2→36  3→13  4→10  5→6  6→5  7→2  8→2  9→1  18→1
```

This confirms the hypothesis already recorded in the backlog (§7.3): the generator
dropped enumeration markers like `2. ` / `(a)` when joining quotes across paragraphs.
Example — `gdpr_art2_case3` joins the paragraph 2 stem directly to item (c), skipping
(a) and (b):

> "This Regulation does not apply to the processing of personal data: (c) by a natural
> person in the course of a purely personal or household activity"

### Case lists

**37 altered** — every word is in the article, but not in this order:

```
art6_case5   art12_case7  art14_case3  art25_case2  art27_case1  art28_case3
art32_case4  art37_case1  art38_case2  art40_case4  art41_case1  art41_case2
art41_case5  art43_case2  art43_case4  art45_case4  art47_case2  art47_case5
art49_case1  art49_case3  art49_case4  art51_case3  art56_case4  art60_case4
art61_case4  art62_case4  art62_case5  art64_case3  art64_case4  art66_case4
art68_case4  art69_case1  art75_case2  art80_case4  art90_case2  art90_case3
art92_case4
```

**20 absent** — contain words appearing nowhere in the gold article:

```
art8_case5   art30_case2  art40_case5  art41_case3  art41_case4  art43_case1
art43_case3  art54_case1  art55_case3  art56_case2  art59_case3  art60_case3
art61_case5  art65_case2  art65_case4  art66_case5  art75_case1  art82_case3
art92_case3  art93_case2
```

None of the 20 matched a *different* article either, so these are not mis-attributions —
the text is not in the corpus at all. Severity varies and they should not be treated as
one batch: `art61_case5` differs by a single inflection (`expenditures` vs.
`expenditure`) and `art40_case5` cites `Article 41` where the source reads `Article
41(1)`, while `art41_case3` has 11 consecutive absent tokens and looks genuinely
invented.

**15 typography** — identical words, contiguous; only non-alphanumeric characters or
case differ. Attributed by applying each candidate fix to the article and re-testing
`quote in article`, so each row is the fix that actually resolves it:

| resolved by | count | cases |
|---|---:|---|
| flatten markdown list markers (`\n- `) | 4 | art23_case4, art47_case3, art53_case1, art58_case3 |
| case-insensitive match | 5 | art16_case1, art20_case4, art21_case1, art28_case5, art69_case2 |
| none of the above | 6 | art7_case6, art36_case4, art50_case1, art50_case4, art60_case2, art80_case2 |

Three examples, to show how small these are:

- `art16_case1` — one character. Quote opens `'the data subject shall have…'`; the
  article reads `'The data subject shall have…'`.
- `art53_case1` — docling rendered Article 53's enumeration as a bulleted list and the
  quote flattened it: article `'…procedure by:\n- their parliament;\n- their
  government;…'` vs. quote `'…procedure by: their parliament; their government;…'`.
- `art80_case2` — the quote *adds* a comma the regulation does not have, after
  `'…referred to in Article 82 on his or her behalf'`.

The list-marker group is arguably a corpus question rather than a quote defect: `\n- `
is docling's rendering of the regulation's enumerations, not text in the regulation.
Whether those markers belong in article content is the same open question the backlog
already raises about Article 99's signature block.

> A previous revision of this section attributed 15 of these to "trailing `.` dropped".
> That was wrong — a quote ending before a sentence-final period is still a valid
> substring. It was an artifact of how the comparison span was extracted, not a cause of
> rejection.

---

## OCR soft-hyphen breaks — found and fixed this session

Not something the QA gate looks for; surfaced while classifying the errors above, and
fixed in the parser rather than by editing the corpus.

**18 occurrences of U+00AD (soft hyphen) followed by a space, across 14 of 99 articles**
— OCR line-break hyphenation that docling preserved and the parser passed through:

```
adminis­ tration (2)   internat­ ional (2)   identifi­ cation (2)   certifi­ cation (2)
physio­ logical        propor­ tionate      representa­ tive       author­ isation
accredi­ tation        organ­ isations      authoris­ ation        in­ ternational
jurisdic­ tional       in­ dependently
```

Articles affected: **4, 9, 14, 30, 36, 42, 43, 44, 45, 46, 49, 50, 58, 80**.
The source export `gdpr.docling.md` carries 39; 18 were surviving into article content.

This matters beyond quote matching — each break splits one word into two meaningless
tokens in the embedded text, and the planned lexical scorers (key-phrase coverage,
citation matching) do string comparison and would miss them outright. Only 3 of the 148
gate errors were attributable to it; the reason to fix it is the embeddings, not the
gate.

**Fix:** `GDPRParser._rejoin_hyphenated_words`, applied in `_clean_content` and
`_clean_title`. It consumes the hyphen *and* the whitespace after it — deleting only the
codepoint leaves `internat ional`, which is no improvement. Applied per-article rather
than document-wide, so the 21 soft hyphens outside article text are left alone and
`gdpr.docling.md` is unmodified. Real hyphens are U+002D (`cross-border`,
`Subject-matter`); all 242 are preserved.

Verified: the regenerated corpus differs by exactly 14 lines, one per affected article,
and every change is `'\xad ' -> ''`. Soft hyphens in `gdpr_articles.json`: **18 → 0**.
Three tests guard it, including one asserting none survive into any of the 99 articles
of the real export.

The corpus was regenerated through the new cached-export path added this session
(`export_docling_markdown.py` writes `gdpr.docling.md`; `generate_gdpr_articles.py`
reads it by default), which turns a parser change from a ~6-minute OCR run into a
sub-second regenerate-and-diff.

The related `_clean_title` double-spacing issue is untouched and still deferred into the
chunking/embedding rework.

---

## Leakage — 18 errors, 17 genuine

Unchanged from the pre-fix run. Confirmed by inspection that exactly one is a false
positive, matching what the backlog recorded:

- `gdpr_art94_case3` — *"What body replaces the **Article 29 Working Party** under the
  GDPR?"* — proper noun, not a location reference. Already tracked as an `xfail` in
  `tests/test_eval_golden_qa.py`; needs an allow-list.
- `gdpr_art29_case3` — *"Does **Article 29** apply to contractors…"* — genuine leakage,
  despite also naming Article 29. The allow-list must key on the phrase *"Article 29
  Working Party"*, not on the number.

---

## What this means for the eval build-out

1. **The gate still FAILs, and that is the correct state.** It should not be relaxed to
   go green. 148 quote-grounding errors is a real signal about the golden set.
2. **Keep "exact substring" as the requirement and fix the data, not the check.** Only
   61.5% of the remainder is faithful elision or typography; a quarter has been
   reordered or reworded. A tolerant matcher would bless altered text as grounded,
   defeating the point of having a verifiable evidence span at all.

   The cleanest remediation makes elision *explicit in the data* rather than inferred by
   a fuzzy matcher: let `supporting_quote` hold a **list of spans**, each required to be
   an exact substring, in document order. That covers the 76 legitimate cases where a
   quote joins an enumeration stem to a specific item — a real feature of GDPR
   structure, not a defect — while keeping the check trivially exact. The explicit `...`
   markers become list boundaries.
3. **57 cases need their quote text rewritten** (37 altered + 20 absent), plus the 17
   leakage questions. Larger than the 20 first reported, but still tractable, and worth
   doing before any scorer is calibrated against this set. The 15 typography cases are
   cheaper still — 9 of them resolve by a mechanical rule, not a judgement call.
4. **Any retrieval metric computed today inherits a golden set where 34% of cases carry
   an ungrounded quote.** Key-phrase and citation scorers are affected most.
5. **Qdrant is stale as of the soft-hyphen fix.** 14 articles' content changed, so their
   chunk text and embeddings no longer match the corpus. Re-indexing is cheap
   (~$0.001) and idempotent — chunk IDs are semantic, so `uuid5(chunk.id)` yields the
   same point IDs and the write overwrites in place rather than needing a drop.

## Reproducing

```bash
python -m src.eval.golden_qa                     # the gate itself
python -m src.scripts.generate_gdpr_articles     # rebuild the corpus from the cached export
git show bc63974^:data/regulations/gdpr_articles.json > /tmp/prefix.json   # pre-fix baseline
```

Classification was done with a throwaway analysis script, not committed. If these
numbers need to be tracked over time, the tiered grounding check (item 2 above) should
land in `golden_qa.py` and report the breakdown directly.
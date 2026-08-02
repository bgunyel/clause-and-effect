# Golden-set QA — corrected-corpus baseline

**Date:** 2026-08-02 · **Branch:** `dev-02` · **Corpus:** 99 articles, 187,323 chars
**Command:** `python -m src.eval.golden_qa` — fully deterministic, **no LLM calls, no spend**

Answers the blocking backlog item: of the 246 quote-grounding errors recorded before
the corpus fix, how many were **caused by the truncation bug** versus **genuine
golden-set defects**?

---

## Headline

| | pre-fix (`bc63974^`) | corrected | Δ |
|---|---|---|---|
| cases checked | 433 | 433 | — |
| clean cases | 176 | **267** | +91 |
| quote-grounding **errors** | 246 | **151** | **−95 (−38.6%)** |
| quote-grounding **warnings** | 176 | 2 | −174 |
| leakage errors | 18 | 18 | 0 |
| gate | FAIL | **FAIL** | — |

Both figures are measured, not remembered: the pre-fix column comes from running the
same gate against `git show bc63974^:data/regulations/gdpr_articles.json`. The 246
baseline reproduced exactly.

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

Leakage is unchanged, as expected: it is a property of the question text and cannot be
affected by a corpus fix. That it moved by exactly zero is a useful control.

---

## The 151 remaining errors, by root cause

Classified by testing four hypotheses in order, each strictly weaker than the last,
with matching done formatting-insensitively (case, punctuation, whitespace, and OCR
soft-hyphens normalized away):

| count | share | root cause |
|---:|---:|---|
| 96 | 63.6% | **stitched** — quote concatenates N contiguous article spans, in order, with no elision marker |
| 20 | 13.2% | **unsupported** — text genuinely absent from the gold article |
| 18 | 11.9% | **typography** — contiguous in the article; only punctuation/case differ |
| 17 | 11.3% | **ellipsis** — quote uses `...` as an explicit elision marker |

**131 of 151 (86.8%) are recoverable by a subsequence/elision-tolerant grounding tier.**
Only **20 cases (13.2% of the remainder, 4.6% of the full set)** are genuine golden-set
defects requiring a fix or removal.

Stitched-segment distribution — most are two- or three-span joins, not wholesale
reassembly:

```
segments: 2→28  3→22  4→15  5→7  6→10  7→4  8→5  9→1  10→1  16→1  17→1  18→1
```

This confirms the hypothesis already recorded in the backlog (§7.3): the generator
dropped enumeration markers like `2. ` / `(a)` when stitching quotes across paragraphs.
Example — `gdpr_art2_case3` joins the paragraph 2 stem directly to item (c), skipping
(a) and (b):

> "This Regulation does not apply to the processing of personal data: (c) by a natural
> person in the course of a purely personal or household activity"

### The 20 genuinely unsupported cases

```
art8_case5   art30_case2  art40_case5  art41_case3  art41_case4
art43_case1  art43_case3  art54_case1  art55_case3  art56_case2
art59_case3  art60_case3  art61_case5  art65_case2  art65_case4
art66_case5  art75_case1  art82_case3  art92_case3  art93_case2
```

None matched a *different* article either, so these are not mis-attributions — the text
is not in the corpus at all. Severity varies and they should not be treated as one
batch: `art61_case5` differs from its source by a single inflection (`expenditures` vs.
`expenditure`) and `art40_case5` cites `Article 41` where the source reads `Article
41(1)`, while `art41_case3` has 11 consecutive absent tokens and looks genuinely
invented.

---

## New finding — OCR soft-hyphen breaks in the corpus

Not something the QA gate looks for; surfaced while classifying the errors above.

**18 occurrences of U+00AD (soft hyphen) followed by a space, across 14 of 99 articles**
— OCR line-break hyphenation that docling preserved and the parser passes through:

```
adminis­ tration (2)   internat­ ional (2)   identifi­ cation (2)   certifi­ cation (2)
physio­ logical        propor­ tionate      representa­ tive       author­ isation
accredi­ tation        organ­ isations      authoris­ ation        in­ ternational
jurisdic­ tional       in­ dependently
```

Articles affected: **4, 9, 14, 30, 36, 42, 43, 44, 45, 46, 49, 50, 58, 80**.
The source export `gdpr.docling.md` carries 39; 18 survive into article content.

This matters beyond quote matching — each break splits one word into two meaningless
tokens in the embedded text, and the planned lexical scorers (key-phrase coverage,
citation matching) do string comparison and will miss them outright. It is the same
class of defect as the deferred `_clean_title` double-spacing issue and belongs with it
in the chunking/embedding rework, which regenerates everything anyway.

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
   go green. 151 quote-grounding errors is a real signal about the golden set.
2. **The grounding definition is now the decision to make** (backlog §7.3). The evidence
   says a subsequence/elision tier recovers 86.8% of the remainder. Add it as a
   *separate tier* — do not loosen "exact", or the distinction between a stitched quote
   and a fabricated one is lost.
3. **Only 20 cases need hand remediation**, plus the 17 leakage questions. That is a
   tractable batch, and small enough to be worth doing properly before any scorer is
   calibrated against this set.
4. **Any retrieval metric computed today inherits a golden set where 38% of cases carry
   an ungrounded quote.** Key-phrase and citation scorers are affected most.

## Reproducing

```bash
python -m src.eval.golden_qa                     # the gate itself
git show bc63974^:data/regulations/gdpr_articles.json > /tmp/prefix.json   # pre-fix baseline
```

Classification was done with a throwaway analysis script, not committed. If these
numbers need to be tracked over time, the tiered grounding check (item 2 above) should
land in `golden_qa.py` and report the breakdown directly.
# Golden-set QA — corrected-corpus baseline

**Date:** 2026-08-02, **updated 2026-08-03** · **Branch:** `dev-02` · **Corpus:** 99 articles, 187,287 chars
**Command:** `python -m src.eval.golden_qa` — fully deterministic, **no LLM calls, no spend**

> **2026-08-03 update.** Leakage is closed (17 → **0**) and a defect class this report did
> not know about — questions that are not self-contained — was found and closed (8 → **0**,
> new gate). Rows 6–8 of the ledger, plus the two sections marked *2026-08-03*. Earlier
> analysis is left as written; where a passage has been overtaken by events it is marked
> rather than rewritten.

Answers the blocking backlog item: of the 246 quote-grounding errors recorded before
the corpus fix, how many were **caused by the truncation bug** versus **genuine
golden-set defects**?

Three changes are measured here, in the order they landed: the **truncation fix**
(`9ecdf6f`/`bc63974`, last session), the **soft-hyphen fix** (this session, found while
classifying the residue of the first), and **tier-5 normalization** of the grounding
check itself — the first change to the *measurement* rather than the data.

---

## Headline

One row per change, newest last. All 433 cases in every row.

| # | change | layer | clean | errors | warn | leak | self | gate |
|---:|---|---|---:|---:|---:|---:|---:|---|
| 0 | baseline (`bc63974^`) | — | 176 | 246 | 176 | 18 | 8 ᵃ | FAIL |
| 1 | truncation fix | corpus | 267 | 151 | 2 | 18 | 8 ᵃ | FAIL |
| 2 | soft-hyphen fix | corpus | 270 | 148 | 2 | 18 | 8 ᵃ | FAIL |
| 3 | tier-5 normalization | measurement | 282 | 136 | 14 | 18 | 8 ᵃ | FAIL |
| 4 | `art60_case2`, `art80_case2` quotes | golden set | 284 | 134 | 14 | 18 | 8 ᵃ | FAIL |
| 5 | `art94_case3` question | golden set | 285 | 134 | 14 | 17 | 8 ᵃ | FAIL |
| 6 | self-reference leakage rule | measurement | 285 | 134 | 14 | 17 | 8 ᵃ | FAIL |
| 7 | 17 leakage questions reworded | golden set | 299 | 134 | 14 | **0** | 8 ᵃ | FAIL |
| 8 | 8 questions reworded + new gate | golden set | **299** | **134** | 14 | **0** | **0** | **FAIL** |
| | **total Δ** | | **+123** | **−112 (−45.5%)** | −162 | **−18** | **−8** | — |

ᵃ *Latent, not reported: the self-containment gate did not exist until row 8. The data was
unchanged from row 0 through row 7, so the count is 8 throughout — it is shown to make
clear the defects were present all along, not introduced by the rewrites.*

The `layer` column is the useful one to read down. Of the eight changes, three did not
touch the golden set at all: two corrected the corpus and two corrected the measurement.
That ratio is the first session's main finding — most of what the gate was reporting as
golden-set defects were defects somewhere else.

Row 5 is the first movement in **leakage**, which had been flat at 18 through every other
change — a useful control, since nothing done to the corpus or the measurement can affect
what a question says.

**Row 6 moves nothing, and that is the point.** Replacing the leakage rule with the
self-reference rule (2026-08-03) left the count at 17, because all 17 named their own gold
article. A rule change that corrects the discriminator without moving the number is
evidence it was a correction rather than a relaxation — the 17 → 0 in row 7 came entirely
from editing questions.

**Row 8 adds a gate without changing `clean`**, for the same reason in reverse: the 8
offending questions were rewritten before `check_self_containment` landed, so the new gate
reports 0 on arrival. The honest reading of rows 0–7 is not "0 self-containment errors" but
"unmeasured".

Grounding is now reported in three tiers rather than pass/fail:

```
285  exact       byte-identical substring
 14  normalized  identical once rendering differences are removed (warning)
134  ungrounded  not in the article at all (error)
```

Row 4 is the first **golden-set** remediation — two quotes edited rather than code or
corpus. Both moved to *exact*, not merely *normalized*, so the quotes are now
byte-identical to their articles.

Every figure is measured, not remembered: row 0 comes from running the same
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

## The 134 remaining errors, by root cause

Classified by testing four hypotheses in order, each strictly weaker than the last,
with matching done formatting-insensitively (case, punctuation, whitespace, and OCR
soft-hyphens normalized away):

Segment order is **enforced**: a run only counts if it starts after the previous run
ends, so a quote that reassembles article text out of sequence cannot be classified as
faithful elision.

| count | share | root cause |
|---:|---:|---|
| 76 | 56.7% | **faithful elision** — multi-span, every word verbatim and in sequence (with or without an explicit `...`) |
| 37 | 27.6% | **text altered** — every word appears in the article, but not in this order; reordered or reworded |
| 20 | 14.9% | **text absent** — contains words that appear nowhere in the gold article |
| 1 | 0.7% | **punctuation inserted** — the quote adds a comma the regulation does not have |

Every remaining error is now a statement about the quote's **words**, not its formatting.
The formatting classes were absorbed by the normalization tier; what is left differs from
the regulation in word content, word order, or completeness.

**76 of 134 (56.7%) would be recoverable by an elision-tolerant tier** — quotes that are
verbatim and in sequence but non-contiguous. The other **58 (43.3%) require the quote
text itself to be rewritten**, because a subsequence check would not pass them either:
subsequence requires order, and these cases violate it.

Neither the soft-hyphen fix nor the normalization tier moved the elision, altered, or
absent buckets by a single case. Both only ever touched quotes that were otherwise
contiguous — which is the expected result, and a useful check that neither change
reached further than intended.

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

**1 punctuation inserted**, down from 3 — two were fixed by deleting the comma, and both
moved straight to *exact*:

```
FIXED   art60_case2   '…mutual assistance pursuant to Article 61[,] and may conduct…'
FIXED   art80_case2   '…in Article 82 on his or her behalf[,] where provided for…'
OPEN    art36_case4   '…to the controller and, where applicable[,] to the processor…'
```

These three were the deliberate boundary of the normalization tier (see below) — the only
formatting-shaped failures left flagged, because in a legal text a comma marks restrictive
versus non-restrictive clauses and enumeration boundaries. Two of the three turned out to
be substantive, which is the case for having drawn the boundary there:

- **`art80_case2` changed the provision's scope.** Article 80(1) lists three mandated
  actions in series, each ending `on his or her behalf`. In the source, `where provided
  for by Member State law` attaches *restrictively* to the third — the compensation right
  is the one conditional on Member State law. The inserted comma made it a non-restrictive
  tail reading as if it qualified all three. The case's `answer_type` is `scope` and its
  question asks what actions a mandated organisation can take, so the comma altered
  exactly what the case measures.
- **`art36_case4` silently corrects the statute's grammar.** Article 36(2) opens a
  parenthetical with `and,` and never closes it. **Verified against the source PDF: the
  regulation genuinely reads `and, where applicable to the processor,`.** The quote's
  version is better English, which is precisely the problem — an evidence span that tidies
  the regulation reads as if the law were drafted more carefully than it was.
- `art60_case2` was the only genuinely inert one: two coordinated verb phrases sharing a
  subject, grammatical either way.

> **Correction.** An earlier reading of this session took `art36_case4` for an OCR dropout
> in the corpus, inferring that an unclosed parenthetical must mean a lost comma. Checking
> the docling export only ruled out the parser, not the source. The PDF settles it: the
> corpus is faithful and the quote is the altered side. Corroboration was already in the
> same sentence — it reads `within period of up to eight weeks`, missing an "a", in both
> the article *and* the quote. The generator reproduced one irregularity verbatim while
> silently fixing another.

---

## The grounding rule was itself producing false positives

Twelve cases previously counted as defects were not defects. They were the exact-substring
rule disagreeing with its own purpose, which is *evidence verifiably drawn from the
regulation* — not byte-identity.

**The clearest case is `art53_case1`.** Its quote is Article 53(1) verbatim, missing only
the `1. ` paragraph label and the four `- ` list markers; every other character matches.
Verified programmatically against the article's paragraph 1.

- article: `'1. Member States shall provide…by:\n- their parliament;\n- their government;\n- their head of State; or\n- an independent body…'`
- quote: `'Member States shall provide…by: their parliament; their government; their head of State; or an independent body…'`

That is what a careful human citation of a bulleted provision looks like. Dropping the
`1.` is not a loss but an improvement: the quote covers only that one numbered statement,
so carrying the enumeration's own label would imply a context the quote does not have.
And the markers are not a corpus defect either — the sub-items of Article 53(1) are a
genuine enumeration in the regulation, so stripping them from article content would
destroy real structure. Neither side was broken. The rule was.

All six list-marker cases were checked and all six are faithful flattenings: each becomes
an exact substring once markers are removed, with no other difference.

| cleared by | count | cases |
|---|---:|---|
| flatten markdown list markers | 6 | art23_case4, art47_case3, art50_case1, art50_case4, art53_case1, art58_case3 |
| letter case | 5 | art16_case1, art20_case4, art21_case1, art28_case5, art69_case2 |
| space before punctuation | 1 | art7_case6 (corpus has `inter alia ,`) |

> **Two corrections to earlier revisions of this section.** It reported 4 list-marker
> cases; it is 6 — Article 50's two use `\n\n- `, which the first normalization test did
> not cover. And it attributed 15 cases to a dropped trailing `.`, which was wrong: a
> quote ending before a sentence-final period is still a valid substring. That was an
> artifact of how the comparison span was extracted, not a cause of rejection.

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
citation matching) do string comparison and would miss them outright. Only 3 of the then-148
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

## Tier-5 normalization — what it removes, and the proof it removes nothing else

`normalize_for_grounding()` applies, symmetrically to quote and article: space before
punctuation → markdown list markers → whitespace collapse → lowercase.

**Punctuation itself is kept.** That is the whole design decision. Erasing it would clear
the three inserted-comma cases too, but a comma in a statute is not reliably inert, and a
check that cannot see an inserted one cannot report punctuation tampering at all. Three
cases, each fixable by deleting one character, is a cheap price for keeping that
capability.

The tier boundary was chosen by measurement, not taste. Each candidate normalization was
applied to the full error set and scored against the four root-cause categories:

| tier | typography (15) | elision (76) | altered (37) | absent (20) |
|---|---:|---:|---:|---:|
| 1 exact | 0 | 0 | 0 | 0 |
| 2 whitespace | 0 | 0 | 0 | 0 |
| 3 + list markers | 6 | 0 | 0 | 0 |
| 4 + space-before-punct | 7 | 0 | 0 | 0 |
| **5 + case-insensitive** ← adopted | **12** | 0 | **0** | **0** |
| 6 + strip all punctuation | 15 | 0 | 0 | 0 |

**Zero leakage at every tier, including the most aggressive.** Not one reordered,
reworded, or fabricated quote clears, even with all punctuation stripped and case
ignored. That is structural rather than lucky: normalization only removes *rendering*,
while those categories differ in word order and word content, which no rendering rule can
touch. Equally, zero elision cases clear at any tier — their gaps are dropped words, not
dropped punctuation.

This safety property is now **enforced rather than remembered**.
`test_normalization_only_ever_clears_contiguous_verbatim_quotes` runs against the real
golden set and asserts that every case the tier promotes to warning has its exact word
sequence appearing *contiguously* in its article — same words, same order, no gaps. A
quote that was reordered or truncated cannot satisfy that, so widening the normalization
later fails the suite.

The gate's semantics are unchanged: warnings tolerated, errors fail. This is not a
loosening of "exact" — it is a distinction being made visible, and it extends a pattern
the check already had, since whitespace-only matches were already reported as warnings.

---

## Leakage — 17 errors, all genuine

Flat at 18 through the truncation fix, the soft-hyphen fix and the normalization tier —
the expected control, since leakage is a property of the question text. It moved only
when a question was actually edited.

**The useful discriminator is self-reference:** does the question name *its own* gold
article? That is what "leakage" means operationally — the question must not reveal where
the answer lives. Classified that way, the 18 split 17 / 1, and the single outlier was
exactly the known false positive:

- `art94_case3` — *"What body replaces the **Article 29 Working Party** under the GDPR?"*
  Gold article **94**, cited article **29**. Not a location reference at all: the Working
  Party takes its nickname from Article 29 of *Directive 95/46/EC*, a different and now
  repealed instrument. The article's own text says so — *"established by Article 29 of
  Directive 95/46/EC"*. Naming it gave nothing away.
- `art29_case3` — *"Does **Article 29** apply to contractors…"* Gold article **29**,
  cited article **29**. Genuine leakage despite naming the same number, which is why a
  phrase allow-list keyed to "Article 29 Working Party" would have been the wrong shape.

**Resolved by rewording the question** to *"What body replaces the Working Party of
Directive 95/46/EC?"* — measured against the checker, this is the only variant tried that
passes as the rule stands today, because the regex keys on `article|paragraph|recital|…`
followed by a number and `Directive 95/46/EC` contains no such keyword. Variants that kept
the literal string "Article 29" stayed flagged. The `answer` and `supporting_quote` needed
no change and the quote still grounds *exact*.

> That resolves the case but **not the underlying bug** — the checker will still flag any
> future question citing an unrelated article. The principled fix is to flag only when the
> cited number equals the case's own `article_number`; `TestCase` already carries it, so no
> signature change is needed. The `xfail` in `tests/test_eval_golden_qa.py` builds its own
> synthetic question rather than reading the data file, so it survives this edit and
> remains the standing record of the defect.
>
> **Done 2026-08-03** (row 6). `check_leakage` now compares each cited article number
> against the case's own. The `xfail` is a passing test, and the suite has no xfails left.

### The remaining 17

All self-referential. Three also have a broken `supporting_quote`
(`art14_case6`, `art90_case2`, `art93_case2`) and so need two fixes rather than one.

Most use the number as a bare handle that can be swapped for the substance —
*"What types of identifiers does Article 87 cover?"*. Three need a substitute for
something the number is carrying: `art65_case1` (the Board's binding decision),
`art95_case3` (the ePrivacy carve-out), and `art10_case2`, which names **two** articles
where only one is the self-leak — removing `Article 10` still leaves `Article 6(1)`, so
that case depends on the self-reference rule landing.

They cluster in the regulation's final chapters — 81, 87, 90, 91, 93, 95, 96 — plus the
two near-twin information-duty articles, 13 and 14. Those late articles are short and
procedural, and hard to characterise without naming them, so the leakage looks like a
predictable failure on low-distinctiveness articles rather than random sloppiness. Worth
knowing if the set is ever regenerated.

### Resolved — 2026-08-03 (row 7)

All 17 reworded; **leakage is 0**, clean cases 285 → 299. Eleven swapped the number for the
substance (*"What types of identifiers does Article 87 cover?"* → *"Which identifiers may
Member States lay down specific processing conditions for?"*); four needed a substitute for
what the number carried (`art65_case1`, `art93_case3`, `art95_case3`, `art96_case2`).

Two keep a cross-reference and pass **only** because of the rule change in row 6 —
`art10_case2` retains `Article 6(1)`, which its `key_phrases` require, and `art93_case2`
retains `Article 5 of Regulation (EU) No 182/2011`. Under the old rule both would still be
flagged, so the checker fix was a precondition for the rewrite, not an independent cleanup.

`art14_case6`, `art90_case2` and `art93_case2` still carry a broken `supporting_quote` —
question fixed, quote outstanding on the 58-quote list.

Held by `test_no_golden_case_names_its_own_article`, which runs over the real set;
mutation-checked by restoring the old `art87_case1` wording and confirming it fails.

---

## Self-containment — a defect class this report missed (2026-08-03)

Eight questions leaned on the article the reader was assumed to be looking at:

- **"this article"** — `art22_case2`, `art48_case1`, `art49_case2`, `art86_case1`, `art86_case3`
- **"this rule"** — `art48_case3`
- **"this provision"** — `art96_case1`
- **"these derogations"** — `art49_case4`

They leak no location — nothing can be looked up by citation — so `check_leakage` was right
to pass them. But *"Does this article apply to all personal data held by a public body?"*
cannot be read on its own, and a retrieval query that only makes sense beside its answer is
not a retrieval query. Same root cause as the leakage cluster: the generator wrote while
looking at the article and assumed its reader would be too.

### The finding worth keeping: the count went 5 → 7 → 8

Three sweeps, each enumerating **nouns**, each incomplete. A pass for `article` found 5. A
pass adding `provision`, `rule`, `regulation`, `section`, `point`, `chapter`… found 7. Only
anchoring on the **determiner** and leaving the noun a wildcard found the 8th — *"Do these
**derogations** apply…"*, a word no list had thought to include.

That is the general answer to "how do you test the endless possibilities": **enumerate the
construction, not the vocabulary.** Determiners are a closed class and stable; the nouns
they can attach to are not. `check_self_containment` matches
`this|these|those|such|said` + *any* word, and accepts it only when that word already
appeared earlier in the same question. `test_self_containment_catches_nouns_nobody_enumerated`
pins the property with *"this widget"*.

Bare `that` is deliberately excluded: it is the one member of the class ambiguous with a
relative pronoun (*"activities that fall outside the scope of EU law"*), and separating
those is a part-of-speech judgement rather than a lexical one. Including it **flagged 29
questions to find 8**. Two closed-class exemptions hold precision at 9/9 — `this Regulation`
(a term of art; exactly one regulation is in scope) and a demonstrative followed by an
auxiliary (*"can this be extended?"* — pronoun, not determiner).

### What this check does not cover

A floor, not a proof. A question can depend on absent context with **no demonstrative at
all** — *"Are there any exemptions?"* names nothing and points nowhere, and no lexical rule
reaches it. That residue is judge-tier (P1) and unmeasured. The regression test says so in
its docstring, so a green result is not read as evidence the set is self-contained.

`art44_case4` also names **"Chapter V"** — a roman numeral, invisible to a `\d`-based
check. Left as an open decision: a chapter is coarser than an article and is not the gold
retrieval unit.

---

## What this means for the eval build-out

1. **The gate still FAILs, and that is the correct state.** It should not be relaxed to
   go green. 134 quote-grounding errors is a real signal about the golden set.
2. **Distinguish the rule from its purpose before "fixing" anything.** Twelve of the
   cases counted as defects this morning were the rule misfiring, not the data. The
   general lesson is worth carrying into the scorers: an exact-match proxy will flag
   rendering differences as substantive ones, and the fix belongs in the proxy.

   What remains genuinely open is elision. The cleanest remediation makes it *explicit
   in the data* rather than inferred by a fuzzy matcher: let `supporting_quote` hold a
   **list of spans**, each required to be an exact substring, in document order. That
   covers the 76 cases where a quote joins an enumeration stem to a specific item — a
   real feature of GDPR structure, not a defect — while keeping the check exact. The
   explicit `...` markers become list boundaries.
3. **58 cases need their quote text rewritten** (37 altered + 20 absent + 1 inserted
   punctuation), plus **17 leakage questions**. Three cases appear on both lists, so the
   distinct total is **72**. Worth doing before any scorer is calibrated against this set.
   Remediation has started: 2 of the 3 punctuation cases and 1 of the 18 leakage cases are
   done.

   *Updated 2026-08-03:* the question-side work is finished — all 17 leakage questions and
   all 8 self-containment questions are reworded. **58 quote rewrites remain**, and they
   are now the only thing standing between this set and a passing gate.
4. **Any retrieval metric computed today inherits a golden set where 31% of cases carry
   an ungrounded quote.** Key-phrase and citation scorers are affected most.

   This is not hypothetical for the plan as written: §3.1 scores **Context Recall**, its
   *primary* retrieval metric, by matching `supporting_quote` against retrieved chunks. A
   quote that is not a substring of its own article cannot be found in any chunk of it, so
   those 134 cases would register as retrieval misses whatever the retriever did. Two
   mitigations, both already available in the data: score article-level Hit@k from the
   gold `article_number` (unaffected by any of this) and treat chunk-level matching as a
   secondary restricted to the 299 exact-or-normalized cases, reporting the exclusion
   rather than letting it depress the number. When that scorer is built it should import
   `normalize_for_grounding` rather than reimplement matching, so the gate and the metric
   cannot drift apart.
5. **Qdrant is stale as of the soft-hyphen fix.** 14 articles' content changed, so their
   chunk text and embeddings no longer match the corpus. Re-indexing is cheap
   (~$0.001) and idempotent — chunk IDs are semantic, so `uuid5(chunk.id)` yields the
   same point IDs and the write overwrites in place rather than needing a drop.
6. **A defect class we have no check for: parametric answerability.** `art94_case3` asks
   what replaced the Article 29 Working Party — answerable from general knowledge without
   retrieving anything. Retrieval metrics are unaffected (Hit@k measures whether the gold
   chunk was retrieved, regardless of whether the model needed it), but end-to-end
   generation metrics would score well over a broken retriever. The plan's paired
   end-to-end / gold-context probes (§2) make it *detectable* — such a case shows an
   unusually small gap between the two probes — but nothing currently flags it, and the
   extent across the 433 is unmeasured.

7. **The checks have drifted from the plan that specifies them** (noted 2026-08-03).
   `docs/evaluation-plan.md` §7.3 is the only document defining golden-set QA, and only two
   of the five implemented gates trace to it — both now doing something different from what
   it says:

   - `check_quote_grounding` — §7.3 bullet 1, but it says "exact substring… any miss is a
     broken test case"; the code reports three tiers.
   - `check_leakage` — §7.3 bullet 4, but it says "must not name article/paragraph
     numbers"; the code flags only self-reference.
   - `check_self_containment` — **not in the plan at all.**
   - `check_required_fields` — "structural validity" exists only in the module docstring.
   - `check_answer_type` — the taxonomy is §3.2/§7.1, but no gate is specified.

   §7.3's other two gates — answer-vs-quote entailment and the human audit sample — are the
   judge/manual ones deliberately left to P1. The practical effect was that
   `src/eval/golden_qa.py`'s docstring, not the plan, was the specification.

   **Reconciled 2026-08-03.** §7.3 now describes all five deterministic gates as they
   behave, separates the P1 judge/manual gates, states the known limits (non-deictic
   context dependence, parametric answerability, elision), and records the method the two
   defect classes were closed by — checks as regression rather than discovery devices,
   enumerate the construction rather than the vocabulary, fix the generator rather than the
   artifact, and verify check quality by mutation. §7.1's stale "~38 articles" is now 433
   cases across all 99 articles. **§3.1 remains unreconciled** and matters more: it still
   does not say that Context Recall is scored by matching `supporting_quote` against
   retrieved chunks, which is what makes item 4 above a live problem rather than a
   theoretical one.

## Reproducing

```bash
python -m src.eval.golden_qa                     # the gate itself
python -m src.scripts.generate_gdpr_articles     # rebuild the corpus from the cached export
git show bc63974^:data/regulations/gdpr_articles.json > /tmp/prefix.json   # pre-fix baseline
```

Classification was done with a throwaway analysis script, not committed. If these
numbers need to be tracked over time, the tiered grounding check (item 2 above) should
land in `golden_qa.py` and report the breakdown directly.
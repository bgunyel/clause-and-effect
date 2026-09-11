# Tier-1 retrieval — the article−chunk gap, corrected — 2026-09-11

**Correcting one number published on 2026-09-09: the article−chunk gap at k=5 is
`+2.5` points, not `+4.2`.** Nothing else in that report moves. The 2026-09-09
entry is history and is left untouched; this is the forward correction.

| | |
|---|---|
| Cases | 433 (Tier-1, all 99 articles) |
| Index | `compliance_docs`, 368 points, `text-embedding-3-small`, `indexed_at 2026-08-07T08:17:19Z` |
| `top_k` | 10 (Hit@k read from one ranked list per case) |
| Commit | `f5b17d1` |
| Scorer | `src/eval/retrieval.py`, run by `scripts/score_retrieval.py` |
| Issue | #60 |

**The same index the 2026-09-09 baseline scored**, unchanged since 2026-08-07 —
and every article-level and chunk-level figure below reproduces that report
digit for digit. That is the point of this run: the retrieval did not change, so
the only thing that moves is the arithmetic that was wrong.

(The index advertises digest `a231f919…` while the committed snapshot
`chunks_2026-08-10_060327_5caac594.jsonl` hashes to `5caac594…` — all 368 points
stale, 0 orphans, 0 missing. Pre-existing, unrelated to this correction, and
noted so the next reader does not take the reproduction as proof the index is
current.)

## What was wrong

`scripts/score_retrieval.py` subtracted two rates taken over different cases:

```
(article hits / 433) − (chunk hits / 319)
```

Chunk-level scoring drops the 114 cases whose `supporting_quote` is not a
substring of its own article — correctly, and it says so on the result.
Article-level scoring excludes nothing — correctly, and that is the whole reason
a publishable article number exists while the answer key is being repaired.
Subtracting one from the other is neither quantity. It printed under the label
*"right article, wrong chunk = chunking/embedding"*, which is a statement about
cases that were retrieved well at one level and badly at the other — and no case
can be in both terms unless both terms cover it.

The 114 excluded cases are not a random sample of the 433. They are the ones the
parser damaged, so the size and the **sign** of the bias were both unknown.

Found by a Codex review of `dev-05` against `main`, alongside the Hit@k cutoff
defect (#59, fixed first).

## The corrected number

Scored over the 319 grounded cases at both levels:

| | value | |
|---|---|---|
| article-level, grounded subset | 89.3% | 285/319 |
| chunk-level, grounded subset | 86.8% | 277/319 |
| **article − chunk at k=5** | **+2.5 points** | **8 cases** |

Published on 2026-09-09: `+4.2`, from `91.0% (394/433) − 86.8% (277/319)`.

**1.7 of the published 4.2 points were population, not chunking.** The
direction is now measurable rather than unknown: the damaged cases retrieve
their own article *better* than the clean ones — 109 of 114 at k=5, **95.6%**,
against 89.3% for the grounded 319. Keeping them in the first term and out of
the second inflated the difference. It could as easily have gone the other way,
and with a worse split it could have printed a negative "right article, wrong
chunk" figure, which the quantity cannot be.

The full-population article-level score is unchanged and stays published:
**91.0% (394/433) at k=5**. It is not the term the gap uses, and it was never
the defect.

## The conclusion it was carrying, revisited

2026-09-09 concluded:

> When retrieval finds the right article it usually finds the chunk holding the
> evidence too, so the dominant loss is not chunking or embedding — it is the
> 9% of cases that miss the article entirely at k=5. That is where the next work
> goes.

**That conclusion survives, and the corrected number strengthens it.** Over the
one population, at k=5:

| loss | cases | of 319 |
|---|---|---|
| article missed entirely | 34 | 10.7% |
| article found, chunk missed | 8 | 2.5% |

Article misses outnumber chunk misses **more than four to one**. The error ran
in the direction of *overstating* the chunking and embedding loss, so correcting
it moves nothing about where the next work goes — the case for going after
article-level misses is stronger at 8 cases than it was at the 13-or-so the
published figure implied.

Two things the correction does change:

- **The article-miss rate quoted in that conclusion was over the wrong
  population too.** "9% miss the article entirely at k=5" is `39/433`. Beside a
  chunk-level number it should be `34/319` — **10.7%**. Same conclusion, and a
  slightly larger share of the loss than was claimed.
- **8 cases is a small enough number to look at individually.** A 2.5-point gap
  over 319 is no longer a rate to reason about in aggregate; it is a list. That
  is a cheaper next step than the published figure suggested, and it is worth
  taking before any chunking work is scoped from this diagnostic.

## What was changed to make the number honest

The fix went into `src/eval/retrieval.py`, not into the one script, so that the
next caller cannot repeat it:

- `grounded_retrievals()` is public and is now the single place the grounding
  restriction is applied. `score_chunk_level` is rebuilt on it instead of
  keeping its own copy of the predicate — the same reason the module imports
  `normalize_for_grounding` rather than reimplementing it.
- `article_chunk_gap()` **raises** when the two scores it is handed cover
  different numbers of cases. The cross-population subtraction now fails loudly
  instead of returning a plausible float.
- `gap_lines()` prints the population, its `n`, both terms and the difference in
  cases, and says in as many words that the figure does not reconcile against
  the article table above it.

Equal `scored` is a necessary condition, not a sufficient one — two equal-sized
populations could still be different cases. It catches the mistake that was
actually made, and it is what a `LevelScore` carries.

## Not measured here

Everything the 2026-09-09 entry listed as not measured is still not measured:
Context Precision, Score Separation, key-phrase coverage, citation
article-match, every generation-side metric, and a run manifest. This is one
re-run of the same index, not a distribution. The 95.6% article-level figure for
the 114 damaged cases is derived from this run's counts (`394 − 285 = 109`), not
separately scored, and it is reported as a diagnosis of the bias rather than as
a number about retrieval quality — those cases still have a broken answer key.

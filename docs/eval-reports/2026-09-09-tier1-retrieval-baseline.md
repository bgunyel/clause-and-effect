# Tier-1 retrieval baseline — 2026-09-09

**The first published performance numbers for this project.**

| | |
|---|---|
| Cases | 433 (Tier-1, all 99 articles) |
| Index | `compliance_docs`, 368 points |
| `top_k` | 10 (Hit@k read from one ranked list per case) |
| Commit | `a38692d` |
| Scorer | `src/eval/retrieval.py`, run by `scripts/score_retrieval.py` |

## Article level — all 433 cases, nothing excluded

| metric | value | |
|---|---|---|
| Hit@1 | **80.6%** | 349/433 |
| Hit@3 | **88.5%** | 383/433 |
| Hit@5 | **91.0%** | 394/433 |
| Hit@10 | **94.2%** | 408/433 |
| MRR | **0.853** | |

Matched on gold `article_number` against the `article_number` metadata of each
retrieved chunk. **No quote text is involved**, so this level is untouched by the
114 damaged quotes and is publishable while the answer key is still being repaired.

That was established on 2026-08-02 — *"score article-level Hit@k from the gold
article_number (unaffected by any of this)"* — and recorded again in
`docs/todo.md`. It went unbuilt for 38 days while the status table read
*"Published performance numbers: none."* The gate was blocking less than it said.

## Chunk level — 319 cases, 114 excluded

| metric | value | |
|---|---|---|
| Hit@1 | 68.7% | 219/319 |
| Hit@3 | 83.1% | 265/319 |
| Hit@5 | 86.8% | 277/319 |
| Hit@10 | 90.9% | 290/319 |
| MRR | 0.765 | |

**Excluded: 114 cases whose `supporting_quote` is not a substring of its own
article.** A quote absent from its article cannot be found in any chunk of it, so
including these would score the parser rather than the retriever. The exclusion is
carried on the result object, not applied silently.

## The count, reconciled

Several figures have been in circulation. Checked today:

| | |
|---|---|
| Total Tier-1 cases | **433** |
| Ungrounded quote (error) | **114** |
| Clean | **319** |
| "Passing every quality check" vs "quote grounded" | **the same set** — verified identical, 0 errors from any other check |

Every remaining error in the golden set is a quote-grounding error; the leakage and
self-containment rewrites are finished. The **"58 quote rewrites remain"** figure
from 2026-08-03 is stale and differently scoped — retired.

## What the gap says

**Article − chunk at k=5: +4.2 points.** When retrieval finds the right article it
usually finds the chunk holding the evidence too, so the dominant loss is not
chunking or embedding — it is the **9% of cases that miss the article entirely at
k=5**. That is where the next work goes.

## Not measured here

Context Precision, Score Separation, key-phrase coverage, citation article-match,
and every generation-side metric. No run manifest yet: git SHA is recorded above by
hand, but eval-set version, embedding model ID and an append-only results history
are not. Numbers here are one run, not a distribution.

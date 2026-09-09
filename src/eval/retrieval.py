"""
Deterministic retrieval scorers (plan §3.1).

Retrieval is scored at **two levels, always reported side by side**, because
they fail for different reasons and only the pair is diagnostic:

- **Article level** — did the top-k contain a chunk of the gold *article*?
  Matched on ``article_number`` metadata, never on quote text.
- **Chunk level** — did the top-k contain the chunk holding the gold
  *supporting quote*? Matched by locating the quote inside the chunk's text.

The gap between them is the diagnostic the failure taxonomy (§9) reads: right
article / wrong chunk is a chunking or embedding problem; wrong article is a
retrieval problem.

**Why the two levels are not equally trustworthy today.** 114 of the 433 Tier-1
cases carry a ``supporting_quote`` that is not a substring of its own article —
the parser damaged them, not the retriever. A quote that is absent from its
article cannot be found in any chunk of it, so those cases would register as
retrieval misses *whatever the retriever did*. Chunk-level scoring is therefore
restricted to the grounded subset and **reports its exclusion count in the
result**, rather than letting a known-bad answer key depress a number that gets
published.

Article-level scoring has no such dependency: ``article_number`` is gold
metadata, untouched by the quote damage. This was established in
``docs/eval-reports/2026-08-02-golden-set-qa-baseline.md`` — *"score
article-level Hit@k from the gold article_number (unaffected by any of this)"* —
and it is why an article-level number is publishable before the answer key is
repaired.

Matching imports :func:`~src.eval.golden_qa.normalize_for_grounding` rather than
reimplementing it, so the gate that decides a quote is grounded and the metric
that looks for it cannot drift apart.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Callable, Dict, List, Sequence

from src.eval.dataset import Article, TestCase
from src.eval.golden_qa import check_quote_grounding, normalize_for_grounding

# A retrieval backend: (query, top_k) -> ordered results, best first. Each result
# carries at least {"chunk_id": str, "text": str, "metadata": {"article_number": str}}.
SearchFn = Callable[[str, int], List[Dict[str, Any]]]

DEFAULT_K = (1, 3, 5, 10)


@dataclass(frozen=True)
class CaseRetrieval:
    """What one case's retrieval returned, reduced to what the scorers need."""

    case_id: str
    gold_article: str
    retrieved_articles: List[str]  # ordered, best first
    retrieved_chunk_ids: List[str]
    retrieved_texts: List[str]

    def article_rank(self) -> int | None:
        """1-based rank of the first chunk from the gold article, or None."""
        for i, art in enumerate(self.retrieved_articles, start=1):
            if art == self.gold_article:
                return i
        return None

    def chunk_rank(self, quote: str) -> int | None:
        """1-based rank of the first chunk containing ``quote``, or None."""
        needle = normalize_for_grounding(quote)
        for i, text in enumerate(self.retrieved_texts, start=1):
            if needle in normalize_for_grounding(text):
                return i
        return None


@dataclass
class LevelScore:
    """Hit@k and MRR at one level, plus what was excluded to get them."""

    level: str
    scored: int
    excluded: int
    excluded_reason: str
    hit_at_k: Dict[int, float] = field(default_factory=dict)
    hits: Dict[int, int] = field(default_factory=dict)
    mrr: float = 0.0

    def as_lines(self) -> List[str]:
        head = f"{self.level}: n={self.scored}"
        if self.excluded:
            head += f"  (excluded {self.excluded} — {self.excluded_reason})"
        out = [head]
        for k in sorted(self.hit_at_k):
            out.append(f"  Hit@{k:<3} {self.hit_at_k[k]:6.1%}   ({self.hits[k]}/{self.scored})")
        out.append(f"  MRR     {self.mrr:6.3f}")
        return out


def retrieve_all(
    cases: Sequence[TestCase],
    search: SearchFn,
    max_k: int = max(DEFAULT_K),
    progress: Callable[[int, int], None] | None = None,
) -> List[CaseRetrieval]:
    """Run every case's question through ``search`` once, at ``max_k``.

    One retrieval per case serves every k: Hit@3 reads the first three of the
    same ranked list Hit@10 reads ten of. Scoring k separately would multiply
    cost and, with a non-deterministic backend, could disagree with itself.
    """
    out: List[CaseRetrieval] = []
    for i, case in enumerate(cases, start=1):
        results = search(case.question, max_k)
        out.append(
            CaseRetrieval(
                case_id=case.case_id,
                gold_article=str(case.article_number),
                retrieved_articles=[str(r["metadata"]["article_number"]) for r in results],
                retrieved_chunk_ids=[r["chunk_id"] for r in results],
                retrieved_texts=[r["text"] for r in results],
            )
        )
        if progress:
            progress(i, len(cases))
    return out


def _score(ranks: List[int | None], level: str, excluded: int, reason: str,
           ks: Sequence[int]) -> LevelScore:
    n = len(ranks)
    s = LevelScore(level=level, scored=n, excluded=excluded, excluded_reason=reason)
    if not n:
        return s
    for k in ks:
        hits = sum(1 for r in ranks if r is not None and r <= k)
        s.hits[k] = hits
        s.hit_at_k[k] = hits / n
    s.mrr = sum(1.0 / r for r in ranks if r is not None) / n
    return s


def score_article_level(retrievals: Sequence[CaseRetrieval],
                        ks: Sequence[int] = DEFAULT_K) -> LevelScore:
    """Hit@k and MRR against the gold article number. Nothing is excluded."""
    ranks = [r.article_rank() for r in retrievals]
    return _score(list(ranks), "article-level", 0, "", ks)


def score_chunk_level(retrievals: Sequence[CaseRetrieval],
                      cases: Sequence[TestCase],
                      articles: Dict[str, Article],
                      ks: Sequence[int] = DEFAULT_K) -> LevelScore:
    """
    Hit@k and MRR against the chunk holding the gold quote.

    Restricted to cases whose quote is grounded in its article — exact or
    normalized. An ungrounded quote is absent from the article by definition, so
    including it would score the parser, not the retriever. The count dropped is
    carried on the result so a reader sees the restriction next to the number.
    """
    by_id = {c.case_id: c for c in cases}
    ranks: List[int | None] = []
    excluded = 0
    for r in retrievals:
        case = by_id[r.case_id]
        issue = check_quote_grounding(case, articles.get(str(case.article_number)))
        if issue is not None and issue.severity == "error":
            excluded += 1
            continue
        ranks.append(r.chunk_rank(case.supporting_quote))
    return _score(ranks, "chunk-level", excluded, "quote ungrounded in its article", ks)

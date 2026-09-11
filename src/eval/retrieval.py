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

**A cutoff may never be deeper than the retrieval it is computed over.** One
retrieval per case serves every k, so the depth it was taken at bounds every
number read off it: a list fetched three deep can answer Hit@1 and Hit@3 and
nothing more. Counting ``rank <= 10`` over three ranks still prints the label
``Hit@10``, and what it reports is Hit@3 — pessimistic, stable across re-runs,
and indistinguishable from a retrieval regression. So :class:`CaseRetrieval`
carries ``max_k`` (what the backend was *asked* for, which ``len(retrieved_*)``
cannot recover because a backend may legitimately return fewer), and the
scorers raise on a cutoff beyond it.

Raising rather than clipping: a clipped Hit@10 is still printed under the label
Hit@10, which is the defect itself. A caller that wants fewer cutoffs asks for
fewer — :func:`cutoffs_for_depth` derives them. MRR is bounded the same way and
is therefore labelled with the depth it was taken at.

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


def cutoffs_for_depth(depth: int) -> tuple[int, ...]:
    """The cutoffs a retrieval taken ``depth`` deep can honestly report.

    Those of :data:`DEFAULT_K` the retrieval actually reaches, plus ``depth``
    itself. The second half settles what a depth beyond ``max(DEFAULT_K)``
    prints: ``depth=20`` reports ``(1, 3, 5, 10, 20)``, so a deeper retrieval
    shows what the extra ranks bought instead of changing only MRR. The rule is
    uniform — ``depth=4`` reports ``(1, 3, 4)``, ``depth=3`` reports ``(1, 3)``.
    """
    if depth < 1:
        raise ValueError(f"retrieval depth must be at least 1, got {depth}")
    return tuple(sorted({k for k in DEFAULT_K if k <= depth} | {depth}))


@dataclass(frozen=True)
class CaseRetrieval:
    """What one case's retrieval returned, reduced to what the scorers need."""

    case_id: str
    gold_article: str
    retrieved_articles: List[str]  # ordered, best first
    retrieved_chunk_ids: List[str]
    retrieved_texts: List[str]
    max_k: int  # depth the backend was asked for, not the depth it returned

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
    depth: int  # retrieval depth every cutoff below was computed over
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
        # MRR reads the same truncated list, so it carries the depth too.
        out.append(f"  MRR@{self.depth:<3} {self.mrr:6.3f}")
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

    ``max_k`` is recorded on every result, because it is the ceiling on what the
    scorers may report and it cannot be recovered afterwards from the number of
    results that came back.
    """
    if max_k < 1:
        raise ValueError(f"max_k must be at least 1, got {max_k}")
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
                max_k=max_k,
            )
        )
        if progress:
            progress(i, len(cases))
    return out


def _retrieval_depth(retrievals: Sequence[CaseRetrieval]) -> int:
    """The depth *every* retrieval reaches — the shallowest ``max_k`` among them.

    A mixed batch is bounded by its weakest member: a cutoff deeper than that
    would be a miss for some cases only because they were never asked.
    """
    return min((r.max_k for r in retrievals), default=0)


def _score(ranks: List[int | None], level: str, excluded: int, reason: str,
           ks: Sequence[int], depth: int) -> LevelScore:
    n = len(ranks)
    s = LevelScore(level=level, scored=n, excluded=excluded, excluded_reason=reason,
                   depth=depth)
    if not n:
        # Nothing is reported, so nothing can be mislabelled.
        return s
    too_deep = sorted({k for k in ks if k > depth})
    if too_deep:
        raise ValueError(
            f"{level}: cutoffs {too_deep} exceed the retrieval depth {depth}; "
            f"a Hit@{too_deep[0]} over {depth} ranks would be a Hit@{depth} "
            f"wearing the wrong label. Retrieve deeper, or ask for fewer cutoffs "
            f"(see cutoffs_for_depth)."
        )
    for k in ks:
        hits = sum(1 for r in ranks if r is not None and r <= k)
        s.hits[k] = hits
        s.hit_at_k[k] = hits / n
    s.mrr = sum(1.0 / r for r in ranks if r is not None) / n
    return s


def score_article_level(retrievals: Sequence[CaseRetrieval],
                        ks: Sequence[int] = DEFAULT_K) -> LevelScore:
    """Hit@k and MRR against the gold article number. Nothing is excluded.

    Raises ``ValueError`` if any ``k`` is deeper than the retrieval.
    """
    ranks = [r.article_rank() for r in retrievals]
    return _score(list(ranks), "article-level", 0, "", ks, _retrieval_depth(retrievals))


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

    Raises ``ValueError`` if any ``k`` is deeper than the retrieval.
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
    return _score(ranks, "chunk-level", excluded, "quote ungrounded in its article", ks,
                  _retrieval_depth(retrievals))

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

**The gap is a difference, so it is only that diagnostic when both terms are
taken over the same cases.** Chunk-level scoring drops the ungrounded cases
(below); the published article-level score keeps all of them, deliberately.
Subtracting the second from the first mixes a population difference into a
number whose label claims to measure right-article/wrong-chunk, and the dropped
cases are not a random sample — they are the ones the parser damaged, so their
article-level performance biases the result by an unknown amount *and sign*. The
published +4.2 points of
``docs/eval-reports/2026-09-09-tier1-retrieval-baseline.md`` was that
subtraction, ``91.0% (394/433) − 86.8% (277/319)``, and a conclusion about where
the next work goes rested on it (issue #60). So the gap now subtracts a *second*
article score taken over :func:`grounded_retrievals` — the same cases chunk
level scores — while the full-population article score stays exactly as it is,
because being publishable over all 433 is the whole reason it exists.
:func:`article_chunk_gap` refuses two scores of unequal ``scored``, so the
cross-population subtraction cannot be written again by accident, and
:func:`gap_lines` prints the population and its ``n`` beside the number.

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
fewer — :func:`cutoffs_for_depth` derives them, and it is what the scorers use
when no ``ks`` is passed, so the *default* path cannot reintroduce the defect
and only an explicit over-ask reaches the raise. The check reads the retrieval
batch rather than the cases that survive exclusion, so the same wrong call
cannot raise on one run and pass on the next. MRR is bounded the same way and is
therefore labelled with the depth it was taken at.

The article−chunk gap is bounded too, by :func:`gap_cutoff`, but it is pinned at
5 rather than following the depth upward: a deeper retrieval must not silently
move a published diagnostic.

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


GAP_K = 5  # the cutoff the article−chunk gap has always been published at


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


def gap_cutoff(art: LevelScore, chunk: LevelScore, prefer: int = GAP_K) -> int | None:
    """The cutoff to report the article−chunk gap at, or None if there is none.

    ``prefer`` — 5, the cutoff the baseline has always been published at —
    whenever both levels hold it. A shallower retrieval falls back to the
    deepest cutoff the two share, rather than printing a ``@5`` gap neither
    level reached. It never goes *deeper* than ``prefer``: a deeper retrieval
    must not silently move the published diagnostic.

    Which cutoff, only. Which *population* the gap is taken over is
    :func:`article_chunk_gap`'s to enforce — pass it the article score over
    :func:`grounded_retrievals`, and this function sees the same two levels
    either way.
    """
    shared = [k for k in art.hit_at_k if k in chunk.hit_at_k and k <= prefer]
    return max(shared) if shared else None


def article_chunk_gap(art: LevelScore, chunk: LevelScore, k: int) -> float:
    """Right article, wrong chunk at ``k`` — from two scores over the same cases.

    ``art`` must be the article-level score over :func:`grounded_retrievals`,
    not the published full-population one. Unequal populations are refused
    rather than subtracted: the difference of two rates over different case sets
    is not the quantity this name promises, and the one shape the defect took
    read exactly like arithmetic (issue #60).

    Equal ``scored`` is a necessary condition, not a sufficient one — two
    same-sized populations could still be different cases. It is what a
    :class:`LevelScore` carries, it catches the mistake that was actually made,
    and the alternative (carrying case ids on every score) buys nothing against
    a caller who is already constructing scores by hand.
    """
    if art.scored != chunk.scored:
        raise ValueError(
            f"the article−chunk gap needs two scores over the same cases, got "
            f"{art.level} over {art.scored} and {chunk.level} over {chunk.scored}. "
            f"Score the article level over grounded_retrievals(...) for the gap; "
            f"the full-population article score is for publishing, not subtracting."
        )
    return art.hit_at_k[k] - chunk.hit_at_k[k]


def gap_lines(art: LevelScore, chunk: LevelScore, k: int) -> List[str]:
    """The printed gap, naming the population it was taken over.

    Both terms are stated next to the difference, and the ``n`` is named, so the
    reader is not invited to reconcile the number against the full-population
    article table printed above it — which is the reconciliation that produced
    the defect in the first place.
    """
    gap = article_chunk_gap(art, chunk, k)
    return [
        f"article−chunk gap @{k}: {gap:+.1%}"
        f"   (right article, wrong chunk = chunking/embedding)",
        # Both counts carry their denominator, as every count in LevelScore
        # does: a bare "(285)" beside an "n=319" reads for a moment as the n.
        f"  over the grounded subset only, n={art.scored}: "
        f"article {art.hit_at_k[k]:.1%} ({art.hits[k]}/{art.scored}) − "
        f"chunk {chunk.hit_at_k[k]:.1%} ({chunk.hits[k]}/{chunk.scored}) = "
        f"{art.hits[k] - chunk.hits[k]} cases."
        f" Not the article table above, which covers every case.",
    ]


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

    An empty batch has no depth; 0 stands for "unknown", and no cutoff is
    checked against it because there is nothing to report either way.
    """
    return min((r.max_k for r in retrievals), default=0)


def _resolve_ks(ks: Sequence[int] | None, depth: int) -> Sequence[int]:
    """An explicit ``ks``, or the honest cutoffs for ``depth`` when none given."""
    if ks is not None:
        return ks
    return cutoffs_for_depth(depth) if depth >= 1 else ()


def _score(ranks: List[int | None], level: str, excluded: int, reason: str,
           ks: Sequence[int], depth: int) -> LevelScore:
    # Validated against the batch, before anything is scored: whether a cutoff
    # is honest is a property of the retrieval depth alone. Deferring the check
    # until something survives exclusion would make it data-dependent — the same
    # wrong call raising on one run and passing on the next.
    if depth >= 1:
        too_deep = sorted({k for k in ks if k > depth})
        if too_deep:
            raise ValueError(
                f"{level}: cutoffs {too_deep} exceed the retrieval depth {depth}; "
                f"a Hit@{too_deep[0]} over {depth} ranks would be a Hit@{depth} "
                f"wearing the wrong label. Retrieve deeper, or ask for fewer cutoffs "
                f"(see cutoffs_for_depth)."
            )
    n = len(ranks)
    s = LevelScore(level=level, scored=n, excluded=excluded, excluded_reason=reason,
                   depth=depth)
    if not n:
        return s
    for k in ks:
        hits = sum(1 for r in ranks if r is not None and r <= k)
        s.hits[k] = hits
        s.hit_at_k[k] = hits / n
    s.mrr = sum(1.0 / r for r in ranks if r is not None) / n
    return s


def score_article_level(retrievals: Sequence[CaseRetrieval],
                        ks: Sequence[int] | None = None) -> LevelScore:
    """Hit@k and MRR against the gold article number. Nothing is excluded.

    ``ks`` defaults to :func:`cutoffs_for_depth` over the batch's own depth, so
    the default path cannot ask for a cutoff the retrieval never reached. An
    explicit ``ks`` deeper than the retrieval raises ``ValueError``.
    """
    depth = _retrieval_depth(retrievals)
    ranks = [r.article_rank() for r in retrievals]
    return _score(list(ranks), "article-level", 0, "", _resolve_ks(ks, depth), depth)


GROUNDING_EXCLUSION = "quote ungrounded in its article"


def grounded_retrievals(retrievals: Sequence[CaseRetrieval],
                        cases: Sequence[TestCase],
                        articles: Dict[str, Article]) -> List[CaseRetrieval]:
    """The cases whose quote is grounded in its article — the population
    chunk-level scoring is restricted to.

    Public, and the one place the restriction is applied, so that a caller who
    needs the same population for something else (the article−chunk gap, which
    needs it to be a difference at all) takes it from here rather than writing a
    second copy of the predicate. Order is preserved.
    """
    by_id = {c.case_id: c for c in cases}
    out: List[CaseRetrieval] = []
    for r in retrievals:
        case = by_id[r.case_id]
        issue = check_quote_grounding(case, articles.get(str(case.article_number)))
        if issue is not None and issue.severity == "error":
            continue
        out.append(r)
    return out


def score_chunk_level(retrievals: Sequence[CaseRetrieval],
                      cases: Sequence[TestCase],
                      articles: Dict[str, Article],
                      ks: Sequence[int] | None = None) -> LevelScore:
    """
    Hit@k and MRR against the chunk holding the gold quote.

    Restricted by :func:`grounded_retrievals` to the cases whose quote is
    grounded in its article — exact or normalized. An ungrounded quote is absent
    from the article by definition, so including it would score the parser, not
    the retriever. The count dropped is carried on the result so a reader sees
    the restriction next to the number.

    The restriction is taken from that function rather than applied again here,
    for the reason the module docstring gives for importing
    ``normalize_for_grounding``: the population the gap is scored over and the
    population this metric covers cannot be allowed to drift apart.

    ``ks`` defaults and is bounded exactly as in :func:`score_article_level`.
    The bound reads the retrieval batch, not the surviving subset, so excluding
    every case does not quietly excuse a dishonest cutoff.
    """
    by_id = {c.case_id: c for c in cases}
    grounded = grounded_retrievals(retrievals, cases, articles)
    ranks = [r.chunk_rank(by_id[r.case_id].supporting_quote) for r in grounded]
    depth = _retrieval_depth(retrievals)
    return _score(ranks, "chunk-level", len(retrievals) - len(grounded),
                  GROUNDING_EXCLUSION, _resolve_ks(ks, depth), depth)

"""
Score Tier-1 retrieval at both levels and print the pair.

    uv run python -m scripts.score_retrieval --limit 20     # smoke test
    uv run python -m scripts.score_retrieval                # all 433

Article-level is publishable today; chunk-level is restricted to the grounded
subset and says so. See ``src.eval.retrieval`` for why they are not equally
trustworthy yet.

**Three scores are computed and two are printed as a table.** The gap needs an
article-level rate over the *same* cases chunk level scores, so it gets its own
restricted score; the published article-level number keeps every case, and the
two must not be subtracted from each other (issue #60). The gap line names the
population it was taken over for that reason.

**The reported cutoffs follow ``--top-k``**, via
:func:`~src.eval.retrieval.cutoffs_for_depth`: ``--top-k 3`` prints Hit@1 and
Hit@3 and nothing else, and ``--top-k 20`` prints Hit@1/3/5/10 *and* Hit@20. A
cutoff deeper than the retrieval cannot be printed at all — the scorers raise —
because a Hit@10 taken over three ranks is a Hit@3 under the wrong name, and it
reads as a retrieval regression that never happened.

**The report is printed; everything else is logged.** Of the eight callers of
`setup_logging` this is the only one whose product is not the log — the table
below is written to stdout with `print` so that a redirect of it into
`docs/eval-reports/` captures the report and nothing else. The run banner and
the progress counter are diagnostics about a 433-case run that takes minutes, so
they go through the logger, which is pointed at stderr for exactly that reason
(`src.logging_setup`). The split is the one the hand-written `file=sys.stderr`
already had; what it gains is a level, a timestamp and a name, so the progress
can be turned down without touching the report.

**Not settled, deferred.** The cheaper arrangement is the one the five probe
siblings have — put the report through the logger too, and no `stream` parameter
is needed anywhere. Issue #85 put that out of scope in as many words ("*The
scope of this ticket is diagnostics, not the report*"), because the report on
stdout is what makes the redirect work and moving it would change what an
eval-report file captures. So the `print` exception is kept deliberately and the
parameter pays for it; a later change that moves the report onto the logger
should take the parameter out with it.
"""
from __future__ import annotations

import argparse
import logging
import sys
from datetime import datetime, timezone

from src.clause_and_effect.retrieval.vector_db import VectorDatabase
from src.config import get_settings
from src.eval.dataset import load_gdpr_articles, load_tier1
from src.eval.retrieval import (
    DEFAULT_K,
    cutoffs_for_depth,
    gap_cutoff,
    gap_lines,
    grounded_retrievals,
    retrieve_all,
    score_article_level,
    score_chunk_level,
)
from src.logging_setup import setup_logging

logger = logging.getLogger(__name__)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=None, help="score only the first N cases")
    ap.add_argument("--top-k", type=int, default=max(DEFAULT_K),
                    help="retrieval depth; the reported cutoffs follow it")
    args = ap.parse_args()
    if args.top_k < 1:
        ap.error("--top-k must be at least 1")

    # stderr, not the stdout default: the report on stdout is this script's
    # product, and a redirect of it must not collect the progress counter.
    #
    # First call wins — `setup_logging` is idempotent in its stream too, so this
    # only holds while nothing configures logging ahead of it. Nothing on this
    # import graph does: the other callers are scripts and `migrations/env.py`,
    # none of which this imports. An import-time caller added under `src/` would
    # take the stdout default and put the progress counter back in the report,
    # silently, which is the failure this line exists to prevent.
    setup_logging(stream=sys.stderr)

    settings = get_settings()
    cases = load_tier1()
    articles = load_gdpr_articles()
    if args.limit:
        cases = cases[: args.limit]

    vector_db = VectorDatabase(
        vector_db_url=settings.QDRANT_URL,
        vector_db_port=settings.QDRANT_PORT,
        vector_db_api_key=settings.QDRANT_API_KEY,
        collection_name=settings.VECTOR_DB_COLLECTION_NAME,
        embedding_model=settings.EMBEDDING_MODEL,
        embedding_model_api_key=settings.OPENAI_API_KEY,
    )

    def progress(i: int, n: int) -> None:
        if i % 25 == 0 or i == n:
            logger.info("retrieved %d/%d", i, n)

    started = datetime.now(timezone.utc)
    logger.info("scoring %d cases at top_k=%d", len(cases), args.top_k)
    retrievals = retrieve_all(cases, vector_db.search, max_k=args.top_k, progress=progress)

    # Cutoffs come from the depth actually retrieved, never from a constant.
    # Passed explicitly rather than left to default, so that a future change to
    # how the script retrieves is refused by the scorers instead of reinterpreted.
    ks = cutoffs_for_depth(args.top_k)
    art = score_article_level(retrievals, ks)                     # all cases, published
    chunk = score_chunk_level(retrievals, cases, articles, ks)    # grounded subset

    # A third score, published nowhere: the article level over the same cases
    # chunk level scores, so that the gap below is a difference between two
    # rates and not between two populations (issue #60).
    art_grounded = score_article_level(grounded_retrievals(retrievals, cases, articles), ks)

    print()
    print(f"Tier-1 retrieval — {len(cases)} cases, top_k={args.top_k}, {started:%Y-%m-%d %H:%M UTC}")
    print("=" * 64)
    for score in (art, chunk):
        for line in score.as_lines():
            print(line)
        print()

    # Report the gap at the deepest cutoff both levels actually hold, so a
    # shallow --top-k cannot print a gap at a cutoff neither level reached.
    #
    # What is *not* pinned by a test: that these two lines are handed
    # `art_grounded` and not `art`. Nothing in tests/ imports this module — it
    # pulls the Qdrant client at import time, and the import-cost rule in
    # CLAUDE.md is why that is left alone. So the defect's own site is guarded
    # at runtime rather than in the suite: article_chunk_gap raises on two
    # populations, which turns the wrong wiring into a crash on the next run
    # instead of a plausible number in a report. Writing the subtraction out by
    # hand here would evade that, and is the one way back to the defect.
    gap_k = gap_cutoff(art_grounded, chunk)
    if gap_k is None:
        print("article−chunk gap: not reportable at this depth")
        return
    for line in gap_lines(art_grounded, chunk, gap_k):
        print(line)


if __name__ == "__main__":
    main()

"""
Score Tier-1 retrieval at both levels and print the pair.

    uv run python -m scripts.score_retrieval --limit 20     # smoke test
    uv run python -m scripts.score_retrieval                # all 433

Article-level is publishable today; chunk-level is restricted to the grounded
subset and says so. See ``src.eval.retrieval`` for why they are not equally
trustworthy yet.
"""
from __future__ import annotations

import argparse
import sys
from datetime import datetime, timezone

from src.clause_and_effect.retrieval.vector_db import VectorDatabase
from src.config import get_settings
from src.eval.dataset import load_gdpr_articles, load_tier1
from src.eval.retrieval import (
    DEFAULT_K,
    retrieve_all,
    score_article_level,
    score_chunk_level,
)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=None, help="score only the first N cases")
    ap.add_argument("--top-k", type=int, default=max(DEFAULT_K))
    args = ap.parse_args()

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
            print(f"  retrieved {i}/{n}", file=sys.stderr, flush=True)

    started = datetime.now(timezone.utc)
    print(f"scoring {len(cases)} cases at top_k={args.top_k}", file=sys.stderr)
    retrievals = retrieve_all(cases, vector_db.search, max_k=args.top_k, progress=progress)

    art = score_article_level(retrievals)
    chunk = score_chunk_level(retrievals, cases, articles)

    print()
    print(f"Tier-1 retrieval — {len(cases)} cases, top_k={args.top_k}, {started:%Y-%m-%d %H:%M UTC}")
    print("=" * 64)
    for score in (art, chunk):
        for line in score.as_lines():
            print(line)
        print()

    gap = art.hit_at_k.get(5, 0) - chunk.hit_at_k.get(5, 0)
    print(f"article−chunk gap @5: {gap:+.1%}"
          "   (right article, wrong chunk = chunking/embedding)")


if __name__ == "__main__":
    main()

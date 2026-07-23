"""
Regenerate ``data/regulations/gdpr_articles.json`` from the source PDF.

This is the committed, reproducible generator for the pre-parsed article file
that BOTH the indexer (`index_documents.py`) and the evaluation framework
(`src/eval`) treat as ground truth. Previously this file was produced by an
uncommitted, one-off step and shipped with a parser bug that truncated ~3/4 of
the articles at their first inline "Article N" cross-reference. Run this after
any change to the parser or the source PDF:

    python -m src.scripts.generate_gdpr_articles

It extracts article text via GDPRParser (docling -> markdown -> article split),
writes the JSON, and prints a validation summary that flags anything that still
looks truncated — so a regression surfaces here rather than silently poisoning
the chunks and embeddings downstream.
"""
import json
import re
from pathlib import Path
from typing import Any, Dict, List

from src.config import get_settings
from src.clause_and_effect import GDPRParser

def _looks_truncated(content: str) -> bool:
    """
    Heuristic: does this article content appear cut mid-sentence?

    A complete article ends on sentence-terminating punctuation. Content that
    ends on a bare word (e.g. "... established by") was almost certainly
    truncated — which is exactly the failure mode of the old parser.
    """
    core = content.rstrip()
    if not core:
        return True
    return not core.endswith((".", ":", ";", "?", "!", "”", '"', ")"))


def _validate(articles: List[Dict[str, Any]]) -> None:
    suspect = [a["number"] for a in articles if _looks_truncated(a["content"])]
    shortest = sorted(articles, key=lambda a: len(a["content"]))[:8]

    print("\nValidation summary")
    print("-" * 48)
    print(f"articles extracted     : {len(articles)}")
    print(f"likely-truncated       : {len(suspect)}")
    if suspect:
        print(f"  -> {', '.join(suspect)}")
    print("shortest articles (chars):")
    for a in shortest:
        print(f"  art {a['number']:>3}: {len(a['content']):5d}")
    if suspect:
        print(
            "\n⚠  Some articles still look truncated. Inspect the flagged ones "
            "before re-indexing."
        )
    else:
        print("\n✅ No obvious truncation detected.")


def main() -> None:
    settings = get_settings()
    gdpr_path = Path(settings.REGULATIONS_DIR) / "gdpr.pdf"
    out_path = Path(settings.REGULATIONS_DIR) / "gdpr_articles.json"

    if not gdpr_path.exists():
        print(f"❌ GDPR source PDF not found at: {gdpr_path}")
        return

    print(f"📖 Extracting articles from {gdpr_path}")
    parser = GDPRParser()
    articles = parser.get_articles(file_path=gdpr_path)

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(articles, f, ensure_ascii=False, indent=2)
    print(f"✅ Wrote {len(articles)} articles to {out_path}")

    _validate(articles)


if __name__ == "__main__":
    main()
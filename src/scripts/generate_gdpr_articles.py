"""
Regenerate ``data/regulations/gdpr_articles.json`` from the docling export.

This is the committed, reproducible generator for the pre-parsed article file
that BOTH the indexer (`index_documents.py`) and the evaluation framework
(`src/eval`) treat as ground truth. Previously this file was produced by an
uncommitted, one-off step and shipped with a parser bug that truncated ~3/4 of
the articles at their first inline "Article N" cross-reference. Run this after
any change to the parser or the source document:

    python -m src.scripts.generate_gdpr_articles [--from-pdf]

By default it reads the cached markdown export
(``data/regulations/gdpr.docling.md``, produced by
``src.scripts.export_docling_markdown``) and runs only the article split, which
takes well under a second. That keeps parser iteration cheap: the OCR
conversion behind that file costs ~6 minutes of CPU and is deterministic on this
input, so repeating it per parser change buys nothing. ``--from-pdf`` forces the
full conversion, and the script falls back to it automatically if no export
exists.

It writes the JSON and prints a validation summary that flags anything that
still looks truncated — so a regression surfaces here rather than silently
poisoning the chunks and embeddings downstream.
"""
import argparse
import json
import sys
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


def main(argv: List[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=(__doc__ or "").split("\n\n")[0])
    ap.add_argument(
        "--from-pdf",
        action="store_true",
        help="re-run the docling conversion instead of reading the cached export",
    )
    args = ap.parse_args(argv)

    settings = get_settings()
    pdf_path = Path(settings.REGULATIONS_DIR) / "gdpr.pdf"
    markdown_path = Path(settings.REGULATIONS_DIR) / "gdpr.docling.md"
    out_path = Path(settings.REGULATIONS_DIR) / "gdpr_articles.json"

    parser = GDPRParser()
    use_pdf = args.from_pdf or not markdown_path.exists()

    if use_pdf:
        if not pdf_path.exists():
            print(f"❌ GDPR source PDF not found at: {pdf_path}")
            if not args.from_pdf:
                print(f"   (no cached export at {markdown_path} either)")
            return 1
        if not args.from_pdf:
            print(f"⚠  No cached export at {markdown_path}; falling back to the PDF.")
            print("   Run `python -m src.scripts.export_docling_markdown` to cache it.")
        print(f"📖 Converting and extracting articles from {pdf_path}")
        print("   docling + OCR — expect several minutes on CPU")
        articles = parser.get_articles(file_path=pdf_path)
    else:
        print(f"📖 Extracting articles from {markdown_path}")
        markdown = markdown_path.read_text(encoding="utf-8")
        articles = parser.get_articles_from_markdown(markdown)

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(articles, f, ensure_ascii=False, indent=2)
    print(f"✅ Wrote {len(articles)} articles to {out_path}")

    _validate(articles)
    return 0


if __name__ == "__main__":
    sys.exit(main())
"""
Regenerate ``data/regulations/gdpr_articles.json`` from the docling export.

This is the committed, reproducible generator for the pre-parsed article file
that BOTH the indexer (`index_documents.py`) and the evaluation framework
(`src/eval`) treat as ground truth. Run it after any change to the parser or
the source document:

    python -m src.scripts.generate_gdpr_articles [--source tree|markdown|pdf]

**The default source is docling's document tree** (``gdpr.docling.json``), not
its markdown. The markdown serializer flattens nested lists — sub-items (a)-(d)
under a numbered paragraph are promoted to siblings and renumbered into one
ordered run — so within an article "3." could denote both paragraph 2(a) and
paragraph 3. The text was intact and only its segmentation was wrong, which is
why no gate caught it for weeks. The tree keeps each item's own ``marker``, so
the regulation's real numbering survives. Full analysis in
``docs/dev-log/devlog_2026-08-05_session-1.md``.

``--source markdown`` runs the old path against ``gdpr.docling.md``. It is kept
deliberately: the two paths agreeing on 96 of 99 articles' prose is the check
that the tree walk did not silently drop content, and deleting the old path
would leave nothing to compare against. ``--source pdf`` forces the full
conversion — roughly six minutes of CPU OCR — and is only needed when neither
export exists.

It writes the JSON and prints a validation summary. Corpus-level invariants are
**enforced**, not merely reported: a corpus that is not 99 articles numbered
1..99, or whose paragraph numbering has gaps or repeats, exits non-zero without
writing. This script once printed ``✅ Wrote 1 articles`` and exited 0 over a
collapsed corpus; the assertions below are what make that impossible.
"""
import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Dict, List

from src.config import get_settings
from src.clause_and_effect.parsers import GDPRParser

# The number of articles the GDPR has. Not a heuristic — a known constant, and
# the single strongest check available on the whole pipeline.
EXPECTED_ARTICLE_COUNT = 99


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


# A first-order paragraph number as the parser renders it: at the start of a
# line, never mid-sentence. Line-anchoring is the whole point — an unanchored
# pattern also matches the "22." ending "...referred to in Articles 15 to 22.",
# which is the defect this corpus rebuild exists to remove.
_PARAGRAPH_NUMBER = re.compile(r'^(\d+)\.\s', re.MULTILINE)


def _paragraph_numbers(content: str) -> List[int]:
    """The first-order paragraph numbers this article's content declares."""
    return [int(m.group(1)) for m in _PARAGRAPH_NUMBER.finditer(content)]


def _check_invariants(articles: List[Dict[str, Any]]) -> List[str]:
    """
    Check the properties a valid corpus must have, whatever the source.

    Returns a list of problems; empty means the corpus is structurally sound.
    Deliberately checks the *rendered output* rather than the parser's internal
    state, so it validates what actually gets written to disk.

    Note what this does and does not prove. Paragraph numbers forming 1..N
    shows the reconstruction is **self-consistent**; it cannot show it is
    **faithful**. A paragraph docling dropped entirely would still leave 1..N
    intact. Confirming counts against the PDF is a separate job.
    """
    problems: List[str] = []

    if len(articles) != EXPECTED_ARTICLE_COUNT:
        problems.append(
            f"expected {EXPECTED_ARTICLE_COUNT} articles, got {len(articles)}"
        )

    numbers = [int(a["number"]) for a in articles]
    if numbers != sorted(numbers):
        problems.append("articles are not in ascending order")
    missing = sorted(set(range(1, EXPECTED_ARTICLE_COUNT + 1)) - set(numbers))
    if missing:
        problems.append(f"missing article numbers: {missing}")
    duplicates = sorted({n for n in numbers if numbers.count(n) > 1})
    if duplicates:
        problems.append(f"duplicate article numbers: {duplicates}")

    for article in articles:
        if not article["title"].strip():
            problems.append(f"article {article['number']}: empty title")
        if not article["content"].strip():
            problems.append(f"article {article['number']}: empty content")

        paragraphs = _paragraph_numbers(article["content"])
        expected = list(range(1, len(paragraphs) + 1))
        if paragraphs and paragraphs != expected:
            problems.append(
                f"article {article['number']}: paragraph numbering is not 1..N "
                f"({paragraphs})"
            )

    return problems


def _validate(articles: List[Dict[str, Any]]) -> None:
    """Print the soft, heuristic checks — advisory, unlike `_check_invariants`."""
    suspect = [a["number"] for a in articles if _looks_truncated(a["content"])]
    shortest = sorted(articles, key=lambda a: len(a["content"]))[:8]

    print("\nValidation summary")
    print("-" * 48)
    print(f"articles extracted     : {len(articles)}")
    print(f"total content          : {sum(len(a['content']) for a in articles):,} chars")
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


def _report_change(existing: List[Dict[str, Any]], articles: List[Dict[str, Any]]) -> None:
    """Say what this run changes, so a regeneration is never a silent overwrite."""
    before = {a["number"]: a for a in existing}
    after = {a["number"]: a for a in articles}

    changed: List[str] = sorted(
        (str(n) for n in before.keys() & after.keys()
         if before[n]["content"] != after[n]["content"]
         or before[n]["title"] != after[n]["title"]),
        key=int,
    )
    delta = sum(len(a["content"]) for a in articles) - sum(len(a["content"]) for a in existing)

    print("\nChange against the existing corpus")
    print("-" * 48)
    print(f"articles           : {len(existing)} -> {len(articles)}")
    print(f"articles changed   : {len(changed)}")
    if changed:
        head = ", ".join(changed[:20])
        print(f"  -> {head}{' …' if len(changed) > 20 else ''}")
    print(f"content delta      : {delta:+,} chars")
    if changed:
        print(
            "\n⚠  Chunks and embeddings are downstream of this file. Re-run\n"
            "   `python -m src.scripts.index_documents` before trusting retrieval,\n"
            "   and re-run the golden-set QA — quote grounding is measured against\n"
            "   this content."
        )


def _load_articles(source: str, paths: Dict[str, Path], parser: GDPRParser) -> List[Dict[str, Any]]:
    """Extract articles from the requested source. Caller checks the path exists."""
    if source == "tree":
        print(f"📖 Extracting articles from {paths['tree']}")
        document = json.loads(paths["tree"].read_text(encoding="utf-8"))
        return parser.get_articles_from_dictionary(document)

    if source == "markdown":
        print(f"📖 Extracting articles from {paths['markdown']}")
        print("   ⚠  the markdown path flattens paragraph hierarchy in 43 of 99 "
              "articles;\n      use it for comparison, not to produce the corpus.")
        return parser.get_articles_from_markdown(paths["markdown"].read_text(encoding="utf-8"))

    print(f"📖 Converting and extracting articles from {paths['pdf']}")
    print("   docling + OCR — expect several minutes on CPU")
    return parser.get_articles(file_path=paths["pdf"])


def main(argv: List[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=(__doc__ or "").split("\n\n")[0])
    ap.add_argument(
        "--source",
        choices=("tree", "markdown", "pdf"),
        default="tree",
        help=(
            "where to read the document from: the docling document tree "
            "(default), the docling markdown, or a fresh PDF conversion"
        ),
    )
    ap.add_argument(
        "--dry-run",
        action="store_true",
        help="validate and report, but do not write the output file",
    )
    args = ap.parse_args(argv)

    settings = get_settings()
    paths = {
        "pdf": Path(settings.REGULATIONS_DIR) / "gdpr.pdf",
        "markdown": Path(settings.REGULATIONS_DIR) / "gdpr.docling.md",
        "tree": Path(settings.REGULATIONS_DIR) / "gdpr.docling.json",
    }
    out_path = Path(settings.REGULATIONS_DIR) / "gdpr_articles.json"

    if not paths[args.source].exists():
        print(f"❌ Source for --source {args.source} not found at: {paths[args.source]}")
        if args.source == "tree":
            print("   Run `python -m src.scripts.export_docling_json` to produce it.")
        elif args.source == "markdown":
            print("   Run `python -m src.scripts.export_docling_markdown` to produce it.")
        return 1

    articles = _load_articles(args.source, paths, GDPRParser())

    problems = _check_invariants(articles)
    if problems:
        print(f"\n❌ Corpus invariants violated ({len(problems)}); nothing written.")
        for problem in problems:
            print(f"   - {problem}")
        return 1
    print(f"✅ Corpus invariants hold: {len(articles)} articles, "
          f"numbered 1..{EXPECTED_ARTICLE_COUNT}, paragraph numbering contiguous.")

    if out_path.exists():
        _report_change(json.loads(out_path.read_text(encoding="utf-8")), articles)

    if args.dry_run:
        print(f"\n🔍 --dry-run: {out_path} left untouched.")
    else:
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(articles, f, ensure_ascii=False, indent=2)
        print(f"\n✅ Wrote {len(articles)} articles to {out_path}")

    _validate(articles)
    return 0


if __name__ == "__main__":
    sys.exit(main())
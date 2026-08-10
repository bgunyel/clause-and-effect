"""
Export the docling markdown for the GDPR PDF to ``data/regulations/gdpr.docling.md``.

This is the expensive half of the corpus pipeline — roughly six minutes of CPU
OCR on a machine without a GPU. Its output is committed so the cheap half, the
article split in ``generate_gdpr_articles.py``, can run in under a second
against the cached export instead of re-running the conversion on every parser
change. The same file doubles as the parser's real-input test fixture
(``tests/test_gdpr_parser.py``), which is why parser work needs no PDF, OCR, or
GPU.

Until now the export existed only as a hand-produced commit with no script
behind it, which is the same class of gap that let a "fixed" parser and a
corrupt corpus coexist for nine days. Run:

    python -m src.scripts.export_docling_markdown [--force]

The conversion is deterministic on this input — verified 2026-08-01, when
articles extracted from the cached markdown came out byte-identical to those
from a fresh conversion. A changed output therefore means the PDF or the docling
version changed, not run-to-run noise, so overwriting an existing export
requires ``--force`` and reports what changed.
"""
import argparse
import sys
import time
from pathlib import Path

from src.config import get_settings
from src.clause_and_effect.parsers import GDPRParser


def _describe(text: str) -> str:
    return f"{len(text):,} chars, {text.count(chr(10)) + 1:,} lines"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=(__doc__ or "").split("\n\n")[0])
    ap.add_argument(
        "--force",
        action="store_true",
        help="overwrite an existing export whose content differs",
    )
    args = ap.parse_args(argv)

    settings = get_settings()
    pdf_path = Path(settings.REGULATIONS_DIR) / "gdpr.pdf"
    out_path = Path(settings.REGULATIONS_DIR) / "gdpr.docling.md"

    if not pdf_path.exists():
        print(f"❌ GDPR source PDF not found at: {pdf_path}")
        return 1

    existing = out_path.read_text(encoding="utf-8") if out_path.exists() else None

    print(f"📖 Converting {pdf_path}")
    print("   docling + OCR — expect several minutes on CPU")
    started = time.monotonic()
    markdown = GDPRParser().to_markdown(pdf_path)
    elapsed = time.monotonic() - started
    print(f"✅ Converted in {elapsed:.0f}s — {_describe(markdown)}")

    if existing is not None:
        if existing == markdown:
            print(f"✅ Identical to the existing export; {out_path} left untouched.")
            return 0
        print(f"\n⚠  Output differs from the existing export at {out_path}")
        print(f"   existing : {_describe(existing)}")
        print(f"   new      : {_describe(markdown)}")
        if not args.force:
            print(
                "\n   The conversion is deterministic on this input, so a difference "
                "means\n   the PDF or the docling version changed. Re-run with --force "
                "to overwrite,\n   then regenerate the corpus and re-index — the "
                "committed articles, chunks,\n   and Qdrant points are all downstream "
                "of this file."
            )
            return 1
        print("   --force given; overwriting.")

    out_path.write_text(markdown, encoding="utf-8")
    print(f"✅ Wrote {out_path}")
    print("\nNext: python -m src.scripts.generate_gdpr_articles")
    return 0


if __name__ == "__main__":
    sys.exit(main())
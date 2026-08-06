"""
Export docling's document tree for the GDPR PDF to ``data/regulations/gdpr.docling.json``.

The sibling of ``export_docling_markdown.py``, and the same expensive half of the
corpus pipeline — roughly six minutes of CPU OCR on a machine without a GPU. It
runs the identical conversion and serializes the result with
``export_to_dict()`` instead of ``export_to_markdown()``.

The two exports are not interchangeable. Markdown is a *rendering* of the
document, and its serializer flattens nested lists: sub-items (a)-(d) under a
numbered paragraph are promoted to siblings and renumbered into one ordered
run, so within one article "3." can denote both paragraph 2(a) and paragraph 3.
That damage is invisible in the text, which stays intact, and it propagates
into chunking — a sub-item severed from the stem that governs it can read as
the opposite of what it means in context. The tree keeps what the renderer
discards: each list item carries its own ``marker`` and ``enumerated`` flag, so
real paragraph numbers survive, and each item carries ``prov`` (page number and
character span) back into the PDF text layer. It is therefore the source the
corpus should be rebuilt from.

    python -m src.scripts.export_docling_json [--force]

Overwriting an existing export requires ``--force``, on the same reasoning as
the markdown script: the conversion is deterministic on this input — verified
2026-08-01 for the markdown path, and this is the same conversion behind a
different serializer, though determinism of the tree itself has not been
separately observed — so a changed output means the PDF or the docling version
changed, not run-to-run noise. Comparison is on the parsed structures rather
than the file bytes, so a re-serialization that differs only in formatting is
correctly reported as unchanged.
"""
import argparse
import json
import sys
import time
from pathlib import Path
from typing import Any, Dict

from src.config import get_settings
from src.clause_and_effect import GDPRParser


def _describe(document: Dict[str, Any]) -> str:
    """Summarize a document tree by the counts that matter to the rebuild."""
    return (
        f"{len(document.get('texts', [])):,} texts, "
        f"{len(document.get('groups', [])):,} groups, "
        f"{len(document.get('pages', [])):,} pages, "
        f"schema {document.get('version', '?')}"
    )


def _serialize(document: Dict[str, Any]) -> str:
    """
    Render the tree exactly as the committed export is rendered.

    Compact and ASCII-escaped, matching ``gdpr.docling.json`` byte for byte so
    a re-export of unchanged content produces no diff.
    """
    return json.dumps(document)


def _report_differences(existing: Dict[str, Any], new: Dict[str, Any]) -> None:
    """Print which top-level sections of the tree changed, as a starting point."""
    only_existing = sorted(set(existing) - set(new))
    only_new = sorted(set(new) - set(existing))
    changed = sorted(k for k in set(existing) & set(new) if existing[k] != new[k])

    if only_existing:
        print(f"   sections dropped : {', '.join(only_existing)}")
    if only_new:
        print(f"   sections added   : {', '.join(only_new)}")
    if changed:
        print(f"   sections changed : {', '.join(changed)}")
    if "origin" in changed:
        # binary_hash lives here, so a changed origin identifies the PDF itself
        # as what moved rather than the conversion.
        print("   -> 'origin' changed: the source PDF is not the one exported before.")


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
    out_path = Path(settings.REGULATIONS_DIR) / "gdpr.docling.json"

    if not pdf_path.exists():
        print(f"❌ GDPR source PDF not found at: {pdf_path}")
        return 1

    existing: Dict[str, Any] | None = None
    if out_path.exists():
        try:
            existing = json.loads(out_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            print(f"⚠  Existing export at {out_path} is not valid JSON ({exc}).")
            if not args.force:
                print("   Re-run with --force to replace it.")
                return 1
            print("   --force given; it will be replaced.")

    print(f"📖 Converting {pdf_path}")
    print("   docling + OCR — expect several minutes on CPU")
    started = time.monotonic()
    document = GDPRParser().to_dictionary(pdf_path)
    elapsed = time.monotonic() - started
    print(f"✅ Converted in {elapsed:.0f}s — {_describe(document)}")

    if existing is not None:
        if existing == document:
            print(f"✅ Identical to the existing export; {out_path} left untouched.")
            return 0
        print(f"\n⚠  Output differs from the existing export at {out_path}")
        print(f"   existing : {_describe(existing)}")
        print(f"   new      : {_describe(document)}")
        _report_differences(existing, document)
        if not args.force:
            print(
                "\n   The conversion is deterministic on this input, so a difference "
                "means\n   the PDF or the docling version changed. Re-run with --force "
                "to overwrite,\n   then regenerate the corpus and re-index — the "
                "articles, chunks, and\n   Qdrant points are all downstream of this "
                "file."
            )
            return 1
        print("   --force given; overwriting.")

    out_path.write_text(_serialize(document), encoding="utf-8")
    print(f"✅ Wrote {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
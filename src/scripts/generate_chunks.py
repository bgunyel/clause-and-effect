"""
Generate a chunk snapshot from ``data/regulations/gdpr_articles.json``.

The chunking stage of the corpus pipeline, split out so it can be run without
touching the vector database:

    gdpr.pdf -> gdpr.docling.json -> gdpr_articles.json -> data/chunks/<snapshot> -> Qdrant

Run:

    python -m src.scripts.generate_chunks [--dry-run] [--force]

Chunking used to happen inside ``index_documents.py`` and leave no trace, which
is why the Qdrant collection could hold 563 points from a corpus that no longer
exists with nothing in the repository able to say so. Making the chunk set a
named, hashed artifact is what lets the index declare which chunks it was built
from — and lets a future chunker be compared against this one, since the "before"
survives the change that replaces it.

This script is the **only** producer of indexed chunks. ``GDPRParser.parse()``
still chunks a PDF directly as a library entry point, but nothing downstream of
here consumes its output; keeping two producers would mean chunks reaching the
index without ever being recorded.

An unchanged corpus regenerates to an identical ``chunk_set_sha256``, and the
script then declines to write a duplicate snapshot unless given ``--force``.
"""
import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List

from src.config import get_settings
from src.clause_and_effect import GDPRParser
from src.clause_and_effect.chunking import Chunk
from src.clause_and_effect.chunking.chunk_store import (
    build_manifest,
    chunk_set_hash,
    latest_snapshot,
    manifest_path_for,
    read_snapshot,
    write_snapshot,
)

_REPO_ROOT = Path(__file__).resolve().parents[2]


def _check_chunks(chunks: List[Chunk], articles: List[Dict[str, Any]]) -> List[str]:
    """
    Properties a chunk set must have before it is worth keeping.

    Enforced here rather than at index time because a defect caught after
    embedding has already cost money and left a collection to clean up.
    """
    problems: List[str] = []

    if not chunks:
        problems.append("no chunks produced")

    # Duplicate IDs collapse onto one Qdrant point silently —
    # `embed_and_upsert_chunks` raises on this, but by then the embeddings are
    # already paid for.
    seen: Dict[str, int] = {}
    for chunk in chunks:
        seen[chunk.id] = seen.get(chunk.id, 0) + 1
    duplicates = sorted(cid for cid, n in seen.items() if n > 1)
    if duplicates:
        problems.append(
            f"{len(duplicates)} duplicate chunk ID(s): {duplicates[:8]}"
        )

    empty = [c.id for c in chunks if not c.text.strip()]
    if empty:
        problems.append(f"{len(empty)} chunk(s) with empty text: {empty[:8]}")

    # An article that produces nothing is unreachable by retrieval, and would
    # not show up as a count mismatch anywhere downstream.
    covered = {str(c.metadata.get("article_number")) for c in chunks}
    missing = sorted(
        (a["number"] for a in articles if a["number"] not in covered),
        key=int,
    )
    if missing:
        problems.append(f"{len(missing)} article(s) produced no chunks: {missing}")

    return problems


def _report(chunks: List[Chunk], manifest: Dict[str, Any]) -> None:
    stats = manifest["stats"]
    print("\nChunk set")
    print("-" * 52)
    print(f"chunks           : {manifest['chunk_count']}")
    print(f"chunk_set_sha256 : {manifest['chunk_set_sha256']}")
    print(f"by chunk_type    : {stats['by_chunk_type']}")
    c = stats["chars"]
    print(f"chars            : total {c['total']:,}  min {c['min']}  "
          f"median {c['median']}  max {c['max']}")
    print(f"source corpus    : {Path(manifest['source']['path']).name} "
          f"({manifest['source']['article_count']} articles, "
          f"sha {manifest['source']['sha256'][:12]}…)")
    print(f"git              : {manifest['git_commit'][:12]}"
          f"{' (DIRTY)' if manifest['git_dirty'] else ''}")
    if manifest["git_dirty"]:
        print("  ⚠  Working tree is dirty, so the commit does not pin the chunker\n"
              "     that produced this snapshot. Fine for experiments; do not use\n"
              "     it as a baseline to measure a later chunker against.")
        # Which paths are dirty is what decides whether the warning matters,
        # so show them rather than making the reader go and look.
        for path in manifest["git_dirty_paths"][:12]:
            print(f"       {path}")
        remaining = len(manifest["git_dirty_paths"]) - 12
        if remaining > 0:
            print(f"       … and {remaining} more")

    oversized = sorted((len(c_.text), c_.id) for c_ in chunks)[-3:]
    print("largest chunks   :")
    for size, cid in reversed(oversized):
        print(f"  {size:6,} chars  {cid}")


def main(argv: List[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=(__doc__ or "").split("\n\n")[0])
    ap.add_argument(
        "--dry-run",
        action="store_true",
        help="chunk and report, but do not write a snapshot",
    )
    ap.add_argument(
        "--force",
        action="store_true",
        help="write a snapshot even if the newest one has identical content",
    )
    args = ap.parse_args(argv)

    settings = get_settings()
    articles_path = Path(settings.REGULATIONS_DIR) / "gdpr_articles.json"
    chunks_dir = Path(settings.CHUNKS_DIR)

    if not articles_path.exists():
        print(f"❌ Corpus not found at: {articles_path}")
        print("   Run `python -m src.scripts.generate_gdpr_articles` first.")
        return 1

    articles = json.loads(articles_path.read_text(encoding="utf-8"))
    print(f"📖 Chunking {len(articles)} articles from {articles_path}")

    parser = GDPRParser()
    chunks: List[Chunk] = []
    for article in articles:
        chunks.extend(parser.article_to_chunks(article))

    problems = _check_chunks(chunks, articles)
    if problems:
        print(f"\n❌ Chunk set is invalid ({len(problems)}); nothing written.")
        for problem in problems:
            print(f"   - {problem}")
        return 1

    created_at = datetime.now(timezone.utc)
    manifest = build_manifest(
        chunks,
        source_path=articles_path,
        source_description={"article_count": len(articles)},
        repo_root=_REPO_ROOT,
        created_at=created_at,
    )
    _report(chunks, manifest)

    previous = latest_snapshot(chunks_dir)
    if previous is not None:
        prior = read_snapshot(previous)
        if prior.chunk_set_sha256 == manifest["chunk_set_sha256"] and not args.force:
            print(f"\n✅ Identical to the newest snapshot ({previous.name}); "
                  f"nothing written.")
            print("   Pass --force to record a duplicate anyway.")
            return 0
        print(f"\nAgainst the newest snapshot ({previous.name}):")
        print(f"   chunks {prior.manifest['chunk_count']} -> {manifest['chunk_count']}")
        added = {c.id for c in chunks} - {c.id for c in prior.chunks}
        removed = {c.id for c in prior.chunks} - {c.id for c in chunks}
        prior_text = {c.id: c.text for c in prior.chunks}
        changed = sum(
            1 for c in chunks if c.id in prior_text and prior_text[c.id] != c.text
        )
        print(f"   IDs added {len(added)}, removed {len(removed)}, "
              f"text changed {changed}")

    if args.dry_run:
        print(f"\n🔍 --dry-run: {chunks_dir} left untouched.")
        return 0

    chunks_path, written_manifest = write_snapshot(
        chunks, chunks_dir, manifest, created_at
    )
    # Read it straight back: the manifest check in `read_snapshot` is what
    # proves the file on disk is the chunk set just reported, rather than
    # whatever a partial write left behind.
    verified = read_snapshot(chunks_path)
    print(f"\n✅ Wrote {verified.manifest['chunk_count']} chunks to {chunks_path}")
    print(f"   manifest: {written_manifest}")
    print(f"   verified: re-read and re-hashed to "
          f"{verified.chunk_set_sha256[:12]}…")
    print("\nNext: python -m src.scripts.index_documents")
    return 0


if __name__ == "__main__":
    sys.exit(main())
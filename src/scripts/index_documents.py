"""
Index a chunk snapshot into the vector database.

    gdpr.pdf -> gdpr.docling.json -> gdpr_articles.json -> data/chunks/<snapshot> -> Qdrant
                                                                                    ^^^^^^
Run:

    python -m src.scripts.index_documents [--check] [--snapshot NAME]

**Indexes a snapshot, never a fresh chunking.** Re-chunking here would embed a
chunk set that was never written down, so the hash recorded on the collection
would describe something no file holds — which is the failure this whole
mechanism exists to prevent. `generate_chunks.py` is the only producer; this is
the only consumer.

Two invariants are enforced, and both were violated by the live collection as of
2026-08-07:

  * **The collection advertises the chunk set it holds.** Nothing wrote
    `chunk_set_sha256` before, so `config.metadata` was None over 563 points and
    no query could tell whether the index matched the corpus.
  * **Every point in the collection belongs to that chunk set.** 196 points
    survived the 2026-08-06 corpus rebuild: real GDPR text, embedded and
    returned by `search`, from a decomposition that exists nowhere else. A
    retrieval metric measured against them is measuring a corpus nobody has.

**Pruning is not optional** — Bertan, 2026-08-09. It was briefly gated behind a
`--prune` flag, when the first destructive run had 196 points to remove and an
opt-in felt prudent. The flag is gone. The second invariant above is not a
preference the caller may decline: a collection holding points from a corpus
that no longer exists does not partly satisfy it, it fails it, and an index run
that leaves them behind has not indexed the snapshot. Making removal optional
made "did this run do its job?" depend on which flags were typed, which is
exactly the state the `chunk_set_sha256` machinery exists to end. Use `--check`
to see what a run would change without changing anything.

Order matters and is not arbitrary. Metadata is written **last** — after
`index_chunks` verifies its count and after orphans are gone — because a
collection that advertises a snapshot it only partly holds is worse than one
that advertises nothing: the first is trusted and wrong, the second is merely
unknown. For the same reason a run that leaves orphans behind exits non-zero
*without* writing metadata.
"""
import argparse
import logging
import sys
from pathlib import Path
from typing import Any, Dict, List

from src.config import get_settings
from src.logging_setup import setup_logging
from src.clause_and_effect.retrieval import VectorDatabase
from src.clause_and_effect.chunking import Chunk, ChunkSetMetadata
from src.clause_and_effect.chunking.chunk_store import (
    latest_snapshot,
    list_snapshots,
    read_snapshot,
)

_SMOKE_QUERY = "What is the timeline for data deletion requests?"

logger = logging.getLogger(__name__)

# How many offending items a report names before summarising the rest.
_REPORT_LIMIT = 10


def _resolve_snapshot(chunks_dir: Path, name: str | None) -> Path | None:
    """The snapshot to index: the one named, or the newest available."""
    if name is None:
        return latest_snapshot(chunks_dir)
    candidate = chunks_dir / name
    if candidate.exists():
        return candidate
    # Accept the bare stem too, since that is what the report prints.
    for path in list_snapshots(chunks_dir):
        if path.stem == name or path.name == name:
            return path
    return None


def _listing(items: List[str], limit: int = _REPORT_LIMIT) -> str:
    """Indented lines for a log record, truncated with an honest tail count."""
    shown = "\n".join(f"     {item}" for item in items[:limit])
    if len(items) > limit:
        shown += f"\n     … and {len(items) - limit} more"
    return shown


def _report_orphans(orphans: Dict[str, str | None]) -> None:
    lines = [
        f"{chunk_id or '<no chunk_id in payload>'}  ({point_id})"
        for point_id, chunk_id in sorted(orphans.items(), key=lambda kv: str(kv[1]))
    ]
    logger.warning(
        "⚠️  %d point(s) in the collection belong to no chunk in this snapshot:\n%s",
        len(orphans), _listing(lines),
    )


def _compare(vector_db: VectorDatabase, chunks: List[Chunk]) -> Dict[str, Any]:
    """Collection contents against a chunk set, without writing anything."""
    stored = vector_db.stored_point_ids()
    expected = {str(vector_db.point_id(c.id)): c.id for c in chunks}
    orphan_ids = set(stored) - set(expected)
    missing_ids = set(expected) - set(stored)
    return {
        "stored": stored,
        "expected": expected,
        "orphans": {pid: stored[pid] for pid in orphan_ids},
        "missing": sorted(expected[pid] for pid in missing_ids),
    }


def main(argv: List[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=(__doc__ or "").split("\n\n")[0])
    ap.add_argument(
        "--check",
        action="store_true",
        help="report whether the collection matches the snapshot, then stop. "
             "Writes nothing and spends nothing.",
    )
    ap.add_argument(
        "--snapshot",
        default=None,
        help="snapshot to index (default: the newest in CHUNKS_DIR)",
    )
    args = ap.parse_args(argv)
    setup_logging()

    settings = get_settings()
    chunks_dir = Path(settings.CHUNKS_DIR)

    snapshot_path = _resolve_snapshot(chunks_dir, args.snapshot)
    if snapshot_path is None:
        logger.error("❌ No chunk snapshot found in %s\n"
                     "   Run `python -m src.scripts.generate_chunks` first.",
                     chunks_dir)
        return 1

    # `read_snapshot` re-hashes the file and compares against its manifest, so a
    # tampered or truncated snapshot fails here rather than reaching the index.
    snapshot = read_snapshot(snapshot_path)
    manifest = snapshot.manifest
    chunks = snapshot.chunks

    logger.info(
        "📦 Snapshot  : %s\n"
        "   chunks    : %d\n"
        "   sha256    : %s\n"
        "   corpus    : %s (sha %s…)\n"
        "   chunker   : %s%s",
        snapshot_path.name, len(chunks), snapshot.chunk_set_sha256,
        manifest["source"]["path"], manifest["source"]["sha256"][:12],
        manifest["git_commit"][:12], " (DIRTY)" if manifest["git_dirty"] else "",
    )

    vector_db = VectorDatabase(
        vector_db_url=settings.QDRANT_URL,
        vector_db_port=settings.QDRANT_PORT,
        vector_db_api_key=settings.QDRANT_API_KEY,
        collection_name=settings.VECTOR_DB_COLLECTION_NAME,
        embedding_model=settings.EMBEDDING_MODEL,
        embedding_model_api_key=settings.OPENAI_API_KEY,
    )

    if args.check:
        return _check(vector_db, snapshot_path, snapshot, chunks)


    # Stamped into every point. Point IDs derive from chunk IDs alone, so a
    # chunk whose *text* changes keeps its ID and its point — which means an
    # ID-set comparison is structurally blind to stale content. This is the
    # field that is not: after any run, complete or interrupted, the points
    # not carrying the current digest are exactly the ones not rewritten.
    #
    # Taken from the snapshot rather than recomputed. `read_snapshot` has
    # already hashed these exact chunks and raised if the result disagreed with
    # the manifest, so re-deriving it here re-hashes 368 chunks to arrive at a
    # value that cannot differ.
    #
    # It was a real comparison once, when `index_chunks` derived the digest from
    # the chunks it wrote: the two came from genuinely independent routes and
    # could disagree. Since the digest became caller-supplied, both sides read
    # the same manifest field, and the check that guarded them became
    # unreachable — code that reads like a safeguard and can never fire, which
    # is worse than no check because it invites trust it cannot earn. The
    # guarantee still exists; it lives in `read_snapshot`.
    chunk_set_id = snapshot.chunk_set_sha256

    # Read the collection before writing, so the run can say what it is about to
    # do rather than only what it did. Insert and update are the same upsert to
    # Qdrant — the split is for the operator, not for the client.
    before = vector_db.stored_points()
    expected = {str(vector_db.point_id(c.id)): c.id for c in chunks}
    logger.info(
        "🔁 Reconciling against %d existing point(s)\n"
        "   update  : %d\n"
        "   insert  : %d\n"
        "   delete  : %d",
        len(before),
        len(set(expected) & set(before)),
        len(set(expected) - set(before)),
        len(set(before) - set(expected)),
    )

    chunk_set_metadata = ChunkSetMetadata(
        chunk_set_id = chunk_set_id,
        snapshot = snapshot_path.name,
        source_sha256 = manifest["source"]["sha256"],
        chunker_commit = manifest["git_commit"],
        chunker_tree_dirty = manifest["git_dirty"],
    )

    collection_metadata = vector_db.index_chunks(
        chunks=chunks,
        chunk_set_metadata=chunk_set_metadata
    )

    # Read back what the server actually stored. The write is the point of this
    # script, so reporting the dict we sent would verify nothing.
    recorded = vector_db.collection_metadata() or {}
    rows = []
    for key in sorted(collection_metadata):
        stored_value = recorded.get(key, "N/A")
        mark = "✅" if str(stored_value) == str(collection_metadata[key]) else "❌"
        rows.append(f"   {mark} {key}: {stored_value}")
    logger.info("📋 Collection metadata\n%s", "\n".join(rows))

    if any(str(recorded.get(k, "N/A")) != str(v) for k, v in collection_metadata.items()):
        logger.error("❌ Collection metadata did not read back as written.")
        return 1

    final = _compare(vector_db, chunks)
    count = vector_db.client.count(
        collection_name=vector_db.collection_name, exact=True
    ).count
    logger.info("✅ %d points, %d chunks, %d orphans, %d missing.",
                count, len(chunks), len(final["orphans"]), len(final["missing"]))

    hits = []
    for i, result in enumerate(vector_db.search(_SMOKE_QUERY, top_k=3), 1):
        meta = result["metadata"]
        hits.append(
            f"{i}. {result['chunk_id']} (score: {result['score']:.3f})\n"
            f"   Article {meta['article_number']} — {meta['article_title']}\n"
            f"   {result['text'][:150]}..."
        )
    logger.info("🔍 Smoke search: %s\n%s", _SMOKE_QUERY, "\n".join(hits))
    return 0


def _check(
    vector_db: VectorDatabase,
    snapshot_path: Path,
    snapshot: Any,
    chunks: List[Chunk],
) -> int:
    """
    Answer "does the collection hold exactly this snapshot?" and change nothing.

    Free: no embeddings are generated and no writes are issued, so this is the
    safe thing to run before deciding whether an index is needed at all.
    """
    if not vector_db.client.collection_exists(vector_db.collection_name):
        logger.error("❌ Collection '%s' does not exist.", vector_db.collection_name)
        return 1

    recorded = vector_db.collection_metadata() or {}
    comparison = _compare(vector_db, chunks)
    advertised = recorded.get("chunk_set_sha256")
    stale = vector_db.find_stale(snapshot.chunk_set_sha256)

    rows = [
        f"   points          : {len(comparison['stored'])}",
        f"   advertises      : {advertised or '<nothing>'}",
        f"   snapshot        : {snapshot.chunk_set_sha256}",
        f"   orphans         : {len(comparison['orphans'])}",
        f"   missing         : {len(comparison['missing'])}",
        f"   stale           : {len(stale)}",
    ]
    if recorded:
        rows.append(f"   embedding_model : {recorded.get('embedding_model')}")
        rows.append(f"   indexed_at      : {recorded.get('indexed_at')}")
    logger.info("🔎 Collection '%s'\n%s", vector_db.collection_name, "\n".join(rows))

    if comparison["orphans"]:
        _report_orphans(comparison["orphans"])
    if comparison["missing"]:
        logger.warning(
            "⚠️  %d chunk(s) in the snapshot are not in the collection:\n%s",
            len(comparison["missing"]), _listing(comparison["missing"]),
        )

    if stale:
        logger.warning(
            "⚠️  %d point(s) do not carry this snapshot's digest:\n%s",
            len(stale),
            _listing([f"{pid}  holds {held or '<no digest>'}"
                      for pid, held in stale.items()]),
        )

    # Membership, advertisement and per-point provenance are three different
    # claims and all three are required. The ID sets agreeing proves only that
    # the right chunks are represented, not that their vectors are current — a
    # text-only change keeps every ID and every point. The advertised hash is
    # the collection's claim about itself; `stale` is the per-point evidence for
    # or against it, and the only one that survives a half-finished run.
    matches = (
        advertised == snapshot.chunk_set_sha256
        and not comparison["orphans"]
        and not comparison["missing"]
        and not stale
    )
    if matches:
        logger.info("✅ Collection holds exactly %s.", snapshot_path.name)
        return 0

    logger.error("❌ Collection does not match the snapshot. "
                 "Run without --check to index it.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
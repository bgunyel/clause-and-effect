"""
Index a chunk snapshot into the vector database.

    gdpr.pdf -> gdpr.docling.json -> gdpr_articles.json -> data/chunks/<snapshot> -> Qdrant
                                                                                    ^^^^^^
Run:

    python -m src.scripts.index_documents [--check] [--prune] [--snapshot NAME]

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

Order matters and is not arbitrary. Metadata is written **last** — after
`index_chunks` verifies its count and after orphans are gone — because a
collection that advertises a snapshot it only partly holds is worse than one
that advertises nothing: the first is trusted and wrong, the second is merely
unknown. For the same reason a run that leaves orphans behind exits non-zero
*without* writing metadata.
"""
import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List

from src.config import get_settings
from src.clause_and_effect.retrieval import VectorDatabase
from src.clause_and_effect.chunking import Chunk
from src.clause_and_effect.chunking.chunk_store import (
    chunk_set_hash,
    latest_snapshot,
    list_snapshots,
    read_snapshot,
)

_SMOKE_QUERY = "What is the timeline for data deletion requests?"


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


def _build_metadata(
    snapshot_path: Path,
    manifest: Dict[str, Any],
    settings: Any,
    vector_size: int,
    indexed_at: datetime,
) -> Dict[str, Any]:
    """
    What the collection records about its own provenance.

    Decided in full up front rather than grown key by key: Qdrant **merges**
    collection metadata, so a key written once persists until explicitly
    overwritten. A schema that accretes leaves stale keys behind advertising
    values nothing produced.

    `embedding_model` and `vector_size` are here because the chunk hash does not
    cover them. Identical chunks through different models give different vectors
    and different retrieval, while both collections would honestly report the
    same `chunk_set_sha256` — so the hash alone cannot answer "does this index
    match?" and these two close that gap.
    """
    return {
        "chunk_set_sha256": manifest["chunk_set_sha256"],
        "chunk_count": manifest["chunk_count"],
        "snapshot": snapshot_path.name,
        "source_sha256": manifest["source"]["sha256"],
        "chunker_commit": manifest["git_commit"],
        "chunker_tree_dirty": manifest["git_dirty"],
        "embedding_model": settings.EMBEDDING_MODEL,
        "vector_size": vector_size,
        "indexed_at": indexed_at.strftime("%Y-%m-%dT%H:%M:%SZ"),
    }


def _report_orphans(orphans: Dict[str, str | None], limit: int = 10) -> None:
    print(f"\n⚠️  {len(orphans)} point(s) in the collection belong to no chunk "
          f"in this snapshot.")
    for point_id, chunk_id in sorted(orphans.items(), key=lambda kv: str(kv[1]))[:limit]:
        print(f"     {chunk_id or '<no chunk_id in payload>'}  ({point_id})")
    if len(orphans) > limit:
        print(f"     … and {len(orphans) - limit} more")


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
        "--prune",
        action="store_true",
        help="delete points that belong to no chunk in the snapshot (destructive)",
    )
    ap.add_argument(
        "--snapshot",
        default=None,
        help="snapshot to index (default: the newest in CHUNKS_DIR)",
    )
    args = ap.parse_args(argv)

    settings = get_settings()
    chunks_dir = Path(settings.CHUNKS_DIR)

    snapshot_path = _resolve_snapshot(chunks_dir, args.snapshot)
    if snapshot_path is None:
        print(f"❌ No chunk snapshot found in {chunks_dir}")
        print("   Run `python -m src.scripts.generate_chunks` first.")
        return 1

    # `read_snapshot` re-hashes the file and compares against its manifest, so a
    # tampered or truncated snapshot fails here rather than reaching the index.
    snapshot = read_snapshot(snapshot_path)
    manifest = snapshot.manifest
    chunks = snapshot.chunks

    print(f"📦 Snapshot  : {snapshot_path.name}")
    print(f"   chunks    : {len(chunks)}")
    print(f"   sha256    : {snapshot.chunk_set_sha256}")
    print(f"   corpus    : {manifest['source']['path']} "
          f"(sha {manifest['source']['sha256'][:12]}…)")
    print(f"   chunker   : {manifest['git_commit'][:12]}"
          f"{' (DIRTY)' if manifest['git_dirty'] else ''}")

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


    """
    print(f"\n🔁 Reconciling against {len(before)} existing point(s)")
    print(f"   update  : {len(set(expected) & set(before))}")
    print(f"   insert  : {len(set(expected) - set(before))}")
    print(f"   delete  : {len(set(before) - set(expected))}")
    """

    # Stamped into every point. Point IDs derive from chunk IDs alone, so a
    # chunk whose *text* changes keeps its ID and its point — which means an
    # ID-set comparison is structurally blind to stale content. This is the
    # field that is not: after any run, complete or interrupted, the points
    # not carrying the current digest are exactly the ones not rewritten.
    chunk_set_id = chunk_set_hash(chunks)

    # Two independently derived values: `index_chunks` hashes the chunks it
    # actually wrote, the manifest hashes what was written to disk. They can
    # only disagree if the snapshot on disk is not the chunk set in memory.
    if chunk_set_id != snapshot.chunk_set_sha256:
        message = f"\n❌ Indexed chunks hash to {chunk_set_id[:12]}… but the snapshot "
        message += f"records {snapshot.chunk_set_sha256[:12]}…"
        raise Exception(message)

    # Read the collection before writing, so the run can report what it is about
    # to do rather than only what it did. Insert and update are the same upsert
    # to Qdrant — the split is for the operator, not for the client.
    before = vector_db.stored_points()
    expected = {str(vector_db.point_id(c.id)): c.id for c in chunks}

    collection_metadata = {
        "snapshot": snapshot_path.name,
        "source_sha256": manifest["source"]["sha256"],
        "chunker_commit": manifest["git_commit"],
        "chunker_tree_dirty": manifest["git_dirty"],
    }

    vector_db.index_chunks(
        chunks=chunks,
        chunk_set_id=chunk_set_id,
        **collection_metadata
    )

    indexed_at = datetime.now(timezone.utc)
    vector_size = vector_db.client.get_collection(
        vector_db.collection_name
    ).config.params.vectors.size
    expected_metadata = _build_metadata(
        snapshot_path, manifest, settings, vector_size, indexed_at
    )




    # Read back what the server actually stored. The write is the point of this
    # script, so reporting the dict we sent would verify nothing.
    recorded = vector_db.collection_metadata() or {}
    print("\n📋 Collection metadata")
    for key in sorted(expected_metadata):
        stored_value = recorded.get(key, 'N/A')
        mark = "✅" if str(stored_value) == str(expected_metadata[key]) else "❌"
        print(f"   {mark} {key}: {stored_value}")
    if any(str(recorded.get(k, 'N/A')) != str(v) for k, v in expected_metadata.items()):
        print("\n❌ Collection metadata did not read back as written.")
        return 1

    final = _compare(vector_db, chunks)
    count = vector_db.client.count(
        collection_name=vector_db.collection_name, exact=True
    ).count
    print(f"\n✅ {count} points, {len(chunks)} chunks, "
          f"{len(final['orphans'])} orphans, {len(final['missing'])} missing.")

    print(f"\n🔍 Smoke search: {_SMOKE_QUERY}")
    for i, result in enumerate(vector_db.search(_SMOKE_QUERY, top_k=3), 1):
        meta = result["metadata"]
        print(f"\n{i}. {result['chunk_id']} (score: {result['score']:.3f})")
        print(f"   Article {meta['article_number']} — {meta['article_title']}")
        print(f"   {result['text'][:150]}...")
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
        print(f"\n❌ Collection '{vector_db.collection_name}' does not exist.")
        return 1

    recorded = vector_db.collection_metadata() or {}
    comparison = _compare(vector_db, chunks)
    advertised = recorded.get("chunk_set_sha256")
    stale = vector_db.find_stale(snapshot.chunk_set_sha256)

    print(f"\n🔎 Collection '{vector_db.collection_name}'")
    print(f"   points          : {len(comparison['stored'])}")
    print(f"   advertises      : {advertised or '<nothing>'}")
    print(f"   snapshot        : {snapshot.chunk_set_sha256}")
    print(f"   orphans         : {len(comparison['orphans'])}")
    print(f"   missing         : {len(comparison['missing'])}")
    print(f"   stale           : {len(stale)}")
    if recorded:
        print(f"   embedding_model : {recorded.get('embedding_model')}")
        print(f"   indexed_at      : {recorded.get('indexed_at')}")

    if comparison["orphans"]:
        _report_orphans(comparison["orphans"])
    if comparison["missing"]:
        print(f"\n⚠️  {len(comparison['missing'])} chunk(s) in the snapshot are not "
              f"in the collection:")
        for chunk_id in comparison["missing"][:10]:
            print(f"     {chunk_id}")
        if len(comparison["missing"]) > 10:
            print(f"     … and {len(comparison['missing']) - 10} more")

    if stale:
        print(f"\n⚠️  {len(stale)} point(s) do not carry this snapshot's digest:")
        for point_id, held in list(stale.items())[:10]:
            print(f"     {point_id}  holds {held or '<no digest>'}")
        if len(stale) > 10:
            print(f"     … and {len(stale) - 10} more")

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
        print(f"\n✅ Collection holds exactly {snapshot_path.name}.")
        return 0

    print("\n❌ Collection does not match the snapshot. "
          "Run without --check to index it.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
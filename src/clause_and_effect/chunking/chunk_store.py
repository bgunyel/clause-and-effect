"""
On-disk archive of generated chunk sets.

Chunking sits between two artifacts that are already tracked — the corpus
(`gdpr_articles.json`) and the vector index — but until now it happened inside
`index_documents.py` and left no trace. That gap is why the Qdrant collection
could hold 563 points from a corpus that no longer exists with nothing in the
repository able to say so.

A snapshot fixes that by making the chunk set a named artifact:

    data/chunks/chunks_<timestamp>_<hash8>.jsonl           the chunks
    data/chunks/chunks_<timestamp>_<hash8>.manifest.json   where they came from

**The timestamp orders snapshots; the hash identifies them.** Two runs a minute
apart over an unchanged corpus produce the same `chunk_set_sha256`, and the
same hash written into the Qdrant collection is what turns "is the index
stale?" from something remembered into something checked. The hash is computed
over the chunks' canonical content — sorted by ID, keys sorted — and never over
the file bytes, because file bytes carry the timestamp and would report a false
change on every regeneration.

The manifest deliberately does **not** copy the chunker's parameters. Any
constant duplicated here becomes a second source of truth that goes stale
silently the first time someone edits the chunker without editing this file.
`git_commit` pins the exact code instead — which is also why `git_dirty` is
recorded and reported loudly: against a dirty tree, the commit pins nothing.
"""
import hashlib
import json
import subprocess
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Tuple

from pydantic import ValidationError

from .chunk import Chunk, ChunkMetadata
from .chunker import Chunker

SNAPSHOT_PREFIX = "chunks_"
SNAPSHOT_SUFFIX = ".jsonl"
MANIFEST_SUFFIX = ".manifest.json"

# How much of the hash goes in the filename. Enough to tell snapshots apart at
# a glance; the manifest and the Qdrant metadata always carry the full digest.
_HASH_PREFIX_LEN = 8


@dataclass(frozen=True)
class Snapshot:
    """A chunk set as it exists on disk, with the manifest that describes it."""

    chunks_path: Path
    manifest_path: Path
    chunks: List[Chunk]
    manifest: Dict[str, Any]

    @property
    def chunk_set_sha256(self) -> str:
        return self.manifest["chunk_set_sha256"]


def _row(chunk: Chunk) -> Dict[str, Any]:
    """
    A chunk as plain JSON-ready data.

    The single place a `Chunk` becomes a dict, shared by the hash and the
    writer. They must agree exactly: the hash is taken over this shape, the file
    is written in this shape, and `read_snapshot` re-hashes what it loaded to
    prove the two match. Two independent conversions would let a snapshot fail
    its own tamper check the first time they drifted.
    """
    return {"id": chunk.id, "text": chunk.text, "metadata": chunk.metadata.model_dump()}


def _canonical_rows(chunks: List[Chunk]) -> List[Dict[str, Any]]:
    """The chunk set reduced to what identifies it, in a stable order."""
    return sorted((_row(c) for c in chunks), key=lambda row: row["id"])


def chunk_set_hash(chunks: List[Chunk]) -> str:
    """
    Content identity of a chunk set: same chunks in, same digest out.

    Sorted by chunk ID so generation order cannot change the answer, and over
    the chunks themselves rather than their serialization so formatting choices
    (indentation, key order, the manifest's timestamp) cannot either.
    """
    canonical = json.dumps(
        _canonical_rows(chunks),
        sort_keys=True,
        ensure_ascii=False,
        separators=(",", ":"),
    )
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def file_hash(path: Path) -> str:
    """SHA-256 of a file, used to record which corpus a snapshot came from."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


# Cap on the recorded dirty-path list. Enough to judge a normal working tree
# without letting a mass refactor turn the manifest into a file listing.
_MAX_DIRTY_PATHS = 50

# Recorded in place of a path list when git itself could not be consulted, so
# that `git_dirty` being true always comes with a reason.
_GIT_UNAVAILABLE = "<git unavailable>"


def git_state(repo_root: Path) -> Tuple[str, List[str]]:
    """
    Current commit and the paths that make the tree dirty.

    Returns the paths rather than a boolean because the boolean alone is not
    actionable: `git_dirty` is repo-wide, so an unrelated draft in docs/ marks
    a snapshot dirty even when the chunker is fully committed. A reader three
    months later can only tell those apart if the paths are recorded.

    Emptiness is the dirty check — no separate flag to fall out of sync with
    the list. Git being unavailable yields ``("unknown", ["<git unavailable>"])``,
    which reads as dirty: an unverifiable tree should never look reproducible.
    """
    def run(*args: str) -> str | None:
        try:
            result = subprocess.run(
                ["git", *args], cwd=repo_root,
                capture_output=True, text=True, timeout=10, check=False,
            )
        except (OSError, subprocess.SubprocessError):
            return None
        # Deliberately *not* stripped. Porcelain's first column is the index
        # status and is a space for a worktree-only change, so the first line
        # reads " M uv.lock"; stripping shifts it left and the `line[3:]` below
        # then eats a character of the path, recording "v.lock". Callers that
        # want a bare value strip it themselves.
        return result.stdout if result.returncode == 0 else None

    head = run("rev-parse", "HEAD")
    if head is None:
        return "unknown", [_GIT_UNAVAILABLE]
    commit = head.strip()

    # `-z` rather than plain `--porcelain`: without it git C-quotes any path
    # containing a space or non-ASCII byte ("a file.txt", "\303\251.txt"), and
    # the manifest would record the quoting as part of the name — a path that
    # does not exist, which is the one thing this list must never contain.
    # `-z` emits literal NUL-terminated paths and never quotes.
    status = run("status", "--porcelain", "-z")
    if status is None:
        return commit, [_GIT_UNAVAILABLE]

    # Each record is "XY <path>" with the two status columns fixed-width, so the
    # path starts at offset 3. Renames and copies emit the *old* path as a
    # second record, which is consumed here and rendered "old -> new" — the same
    # shape plain porcelain would have produced.
    records = [r for r in status.split("\0") if r]
    paths: List[str] = []
    pending = iter(records)
    for record in pending:
        code, path = record[:2], record[3:]
        if "R" in code or "C" in code:
            origin = next(pending, None)
            if origin is not None:
                path = f"{origin} -> {path}"
        paths.append(path)
    if len(paths) > _MAX_DIRTY_PATHS:
        overflow = len(paths) - _MAX_DIRTY_PATHS
        paths = paths[:_MAX_DIRTY_PATHS] + [f"… and {overflow} more"]
    return commit, paths


def snapshot_name(created_at: datetime, digest: str) -> str:
    """``chunks_2026-08-06_145322_a1b2c3d4`` — sorts chronologically by name."""
    stamp = created_at.strftime("%Y-%m-%d_%H%M%S")
    return f"{SNAPSHOT_PREFIX}{stamp}_{digest[:_HASH_PREFIX_LEN]}"


def list_snapshots(directory: Path) -> List[Path]:
    """Every snapshot in the directory, oldest first."""
    if not directory.is_dir():
        return []
    return sorted(directory.glob(f"{SNAPSHOT_PREFIX}*{SNAPSHOT_SUFFIX}"))


def latest_snapshot(directory: Path) -> Path | None:
    """The newest snapshot, or None if the directory holds none."""
    snapshots = list_snapshots(directory)
    return snapshots[-1] if snapshots else None


def manifest_path_for(chunks_path: Path) -> Path:
    """The manifest that accompanies a chunks file."""
    return chunks_path.with_name(chunks_path.name[: -len(SNAPSHOT_SUFFIX)] + MANIFEST_SUFFIX)


def build_manifest(
    chunks: List[Chunk],
    *,
    chunker: Chunker,
    source_path: Path,
    source_description: Dict[str, Any],
    repo_root: Path,
    created_at: datetime,
) -> Dict[str, Any]:
    """
    Assemble the provenance record written beside a chunk set.

    ``chunker`` is taken as an object rather than a description because the
    hardcoded ``{"class": "GDPRParser", "method": "article_to_chunks"}`` this
    replaced was wrong for two days without anything noticing — the chunker had
    moved out of the parser and the manifest went on naming a class that no
    longer had that method. A value read off the live object cannot go stale;
    a constant typed in by hand is exactly what the module docstring warns
    against, and this field proved the warning.
    """
    commit, dirty_paths = git_state(repo_root)
    # Repo-relative: the manifest is committed, and an absolute path would
    # bake one machine's home directory into a shared artifact.
    try:
        source_name = str(source_path.resolve().relative_to(repo_root.resolve()))
    except ValueError:
        source_name = source_path.name
    lengths = sorted(len(c.text) for c in chunks)
    by_type: Dict[str, int] = {}
    for chunk in chunks:
        key = chunk.metadata.chunk_type
        by_type[key] = by_type.get(key, 0) + 1

    return {
        "chunk_set_sha256": chunk_set_hash(chunks),
        "chunk_count": len(chunks),
        "created_at": created_at.strftime("%Y-%m-%dT%H:%M:%SZ"),
        # Pins the chunker's behaviour. `git_dirty` matters as much as the
        # commit: against a dirty tree the commit pins nothing, so a snapshot
        # taken there is not reproducible and should not be trusted as a
        # baseline. The paths say *what* is dirty, which is what decides
        # whether that actually matters — an uncommitted devlog does not
        # affect chunking; an uncommitted gdpr_parser.py does.
        "git_commit": commit,
        "git_dirty": bool(dirty_paths),
        "git_dirty_paths": dirty_paths,
        "source": {
            "path": source_name,
            "sha256": file_hash(source_path),
            **source_description,
        },
        # No chunker *parameters* here on purpose — see the module docstring.
        # Both values below are read off the live chunker, so neither can
        # disagree with what actually ran. The regulation is worth recording
        # because it decides the chunk-ID prefix and three payload fields.
        "chunker": {
            "class": type(chunker).__name__,
            "regulation": chunker.regulation.name,
        },
        "stats": {
            "by_chunk_type": dict(sorted(by_type.items())),
            "chars": {
                "total": sum(lengths),
                "min": lengths[0] if lengths else 0,
                "median": lengths[len(lengths) // 2] if lengths else 0,
                "max": lengths[-1] if lengths else 0,
            },
        },
    }


def write_snapshot(
    chunks: List[Chunk],
    directory: Path,
    manifest: Dict[str, Any],
    created_at: datetime,
) -> Tuple[Path, Path]:
    """
    Write a chunk set and its manifest, returning both paths.

    Chunks are written in generation order — document order for this corpus —
    rather than the hash's sort order, because a snapshot is read by people as
    well as machines and article 2 belongs before article 10. One JSON object
    per line so that diffing two snapshots shows which chunks changed instead
    of a reflowed array.
    """
    directory.mkdir(parents=True, exist_ok=True)
    stem = snapshot_name(created_at, manifest["chunk_set_sha256"])
    chunks_path = directory / f"{stem}{SNAPSHOT_SUFFIX}"
    manifest_path = directory / f"{stem}{MANIFEST_SUFFIX}"

    with open(chunks_path, "w", encoding="utf-8") as handle:
        for chunk in chunks:
            handle.write(json.dumps(_row(chunk), ensure_ascii=False) + "\n")

    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return chunks_path, manifest_path


class LegacySnapshotError(ValueError):
    """
    A snapshot written against an older chunk schema, which cannot be loaded.

    Subclasses ``ValueError`` so existing handlers still catch it, but exists as
    its own type because it means something entirely different from the tamper
    error beside it: nothing is wrong with the file, it simply predates the
    current `ChunkMetadata`. Conflating the two is how a routine format change
    ends up reported as corruption.
    """


def _load_chunks(rows: List[Dict[str, Any]], chunks_path: Path) -> List[Chunk]:
    """
    Build chunks from parsed rows, or say precisely why they cannot be built.

    Pydantic ignores unknown keys by default, so a pre-typing snapshot loads
    *successfully* with its `topics` and `paragraph` fields silently discarded —
    and then fails the hash check below, reporting "chunk set does not match its
    manifest". That message was written for a hand-edited or truncated file, and
    it sent the reader looking for tampering that had not happened. Rejecting
    here, by name, is the difference between "this archive is old" and "this
    archive is corrupt".

    **This check is load-bearing for integrity, not only for the message.** The
    same silent discarding hides real tampering: add an unknown key to a chunks
    file on disk, and without this check pydantic drops it, the reconstructed
    chunks are identical to the originals, the re-hash *matches* the manifest,
    and `read_snapshot` returns a `Snapshot` as though nothing happened —
    verified 2026-08-09 by disabling only this branch. The hash cannot catch an
    edit the loader throws away before hashing, which makes this the only thing
    standing between a hand-edited metadata key and a clean bill of health. Do
    not relax it as over-strict.
    """
    known = set(ChunkMetadata.model_fields)
    unknown = sorted(
        {key for row in rows for key in row.get("metadata", {})} - known
    )
    if unknown:
        raise LegacySnapshotError(
            f"{chunks_path.name} predates the current chunk schema and can no "
            f"longer be loaded: its metadata carries {unknown}, which "
            f"ChunkMetadata does not define. The file is intact — it is the "
            f"schema that moved. Read it as raw JSONL if you need the "
            f"historical chunk set, or regenerate with "
            f"`python -m src.scripts.generate_chunks`."
        )

    try:
        return [
            Chunk(id=row["id"], text=row["text"], metadata=row["metadata"])
            for row in rows
        ]
    except (ValidationError, KeyError) as exc:
        raise LegacySnapshotError(
            f"{chunks_path.name} does not fit the current chunk schema and "
            f"cannot be loaded: {exc}. If this snapshot predates a schema "
            f"change, read it as raw JSONL rather than through read_snapshot."
        ) from exc


def read_snapshot(chunks_path: Path) -> Snapshot:
    """
    Load a snapshot from disk and verify it is what its manifest claims.

    The hash check is the point: a chunks file edited by hand, truncated by a
    failed write, or paired with the wrong manifest would otherwise be indexed
    as though it were the recorded chunk set, and the collection would then
    advertise a hash it does not hold.

    Raises `LegacySnapshotError` — separately from the tamper check — when the
    file was written against an older `ChunkMetadata`.
    """
    manifest_path = manifest_path_for(chunks_path)
    if not manifest_path.exists():
        raise FileNotFoundError(f"snapshot has no manifest: {manifest_path}")

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    rows = [
        json.loads(line)
        for line in chunks_path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    chunks = _load_chunks(rows, chunks_path)

    recomputed = chunk_set_hash(chunks)
    if recomputed != manifest["chunk_set_sha256"]:
        raise ValueError(
            f"chunk set does not match its manifest: {chunks_path.name} hashes to "
            f"{recomputed[:12]}… but the manifest records "
            f"{manifest['chunk_set_sha256'][:12]}…"
        )
    if len(chunks) != manifest["chunk_count"]:
        raise ValueError(
            f"{chunks_path.name} holds {len(chunks)} chunks but its manifest "
            f"records {manifest['chunk_count']}"
        )

    return Snapshot(chunks_path, manifest_path, chunks, manifest)
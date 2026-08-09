"""
Tests for `chunk_store` — the archive every eval measurement is compared against.

Under the rule in `docs/evaluation-plan.md` §1 this module is held to the eval
standard rather than the product one: a defect here does not produce one bad
answer, it silently invalidates every before/after comparison made with it.

Three properties carry that weight. **`chunk_set_hash`** is the identity
everything downstream keys off — snapshot filenames, collection metadata, and
every indexed point's payload. **`read_snapshot`** is the tamper check that
stands between a hand-edited file and the index. **`git_state`** is what decides
whether a snapshot counts as a baseline at all.

The git tests came first, and the reason is worth keeping.

`git_dirty_paths` is what decides whether a snapshot is usable as a baseline:
`git_dirty` is repo-wide, so an uncommitted devlog and an uncommitted
`gdpr_parser.py` set the same flag and carry opposite verdicts. The paths are
the only thing that separates them, which makes recording them *exactly* a
correctness requirement rather than a nicety.

It was not exact. `run()` returned `result.stdout.strip()`, which is right for
`rev-parse` but wrong for `status --porcelain`: the first column is the index
status and is a space for a worktree-only change, so the first line reads
`" M uv.lock"`. Stripping shifted it left and the `line[3:]` slice then ate a
character of the path, recording `"v.lock"` — a file that does not exist. Only
the first line was affected, and only when its index column was blank, which is
why the hand-verification across six tree states on 2026-08-06 missed it.

These use a real git repository in `tmp_path` rather than a mocked subprocess.
Mocking would have encoded the same wrong belief about porcelain's format that
the bug came from, and so would have passed against the broken code.
"""
import hashlib
import json
import random
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import List

import pytest

from src.clause_and_effect.chunking.chunk_store import (
    MANIFEST_SUFFIX,
    SNAPSHOT_SUFFIX,
    LegacySnapshotError,
    _canonical_rows,
    build_manifest,
    chunk_set_hash,
    file_hash,
    git_state,
    latest_snapshot,
    list_snapshots,
    manifest_path_for,
    read_snapshot,
    snapshot_name,
    write_snapshot,
)
from src.clause_and_effect.chunking import Chunk, ChunkMetadata, Chunker, Regulation


def _git(repo: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args], cwd=repo, capture_output=True, text=True, check=True,
    )
    return result.stdout


@pytest.fixture
def repo(tmp_path: Path) -> Path:
    """A real repository with one commit, so HEAD resolves."""
    _git(tmp_path, "init", "-q")
    # Local config only: must not depend on, or touch, the developer's global git.
    _git(tmp_path, "config", "user.email", "test@example.invalid")
    _git(tmp_path, "config", "user.name", "Test")
    (tmp_path / "uv.lock").write_text("original\n", encoding="utf-8")
    (tmp_path / "keep.txt").write_text("original\n", encoding="utf-8")
    _git(tmp_path, "add", ".")
    _git(tmp_path, "commit", "-q", "-m", "initial")
    return tmp_path


def test_clean_tree_reports_no_dirty_paths(repo: Path) -> None:
    commit, dirty = git_state(repo)

    assert dirty == []
    assert commit == _git(repo, "rev-parse", "HEAD").strip()
    # The commit must be usable as an identifier, not carry stray whitespace —
    # `run` no longer strips, so this is the call site's job now.
    assert len(commit) == 40 and commit == commit.strip()


def test_worktree_modification_records_the_exact_path(repo: Path) -> None:
    """
    The regression. An unstaged edit is porcelain `" M uv.lock"` — leading
    space — and it is the *first* line, which is the only position `.strip()`
    could corrupt.
    """
    (repo / "uv.lock").write_text("changed\n", encoding="utf-8")

    _, dirty = git_state(repo)

    assert dirty == ["uv.lock"]


def test_every_dirty_path_names_a_real_file(repo: Path) -> None:
    """
    The property the bug actually violated, stated directly: a recorded path
    must exist. `"v.lock"` passed a "non-empty list" check and failed this one.
    """
    (repo / "uv.lock").write_text("changed\n", encoding="utf-8")
    (repo / "keep.txt").write_text("changed\n", encoding="utf-8")
    (repo / "untracked.md").write_text("new\n", encoding="utf-8")

    _, dirty = git_state(repo)

    assert sorted(dirty) == ["keep.txt", "untracked.md", "uv.lock"]
    for path in dirty:
        assert (repo / path).exists(), f"manifest names a path that does not exist: {path}"


def test_staged_and_untracked_paths_survive(repo: Path) -> None:
    """
    Untracked lines are `"?? path"` with no leading space and were never
    corrupted, so they are the control: they pin that the fix did not simply
    move the off-by-one somewhere else.
    """
    (repo / "untracked.md").write_text("new\n", encoding="utf-8")
    (repo / "keep.txt").write_text("staged\n", encoding="utf-8")
    _git(repo, "add", "keep.txt")

    _, dirty = git_state(repo)

    assert sorted(dirty) == ["keep.txt", "untracked.md"]


def test_deleted_file_is_reported_by_name(repo: Path) -> None:
    """A deletion is `" D path"` — same blank index column as a modification."""
    (repo / "uv.lock").unlink()

    _, dirty = git_state(repo)

    assert dirty == ["uv.lock"]


@pytest.mark.parametrize("name", ["a file.txt", "é.txt", "quote\"d.txt"])
def test_awkward_filenames_are_recorded_literally(repo: Path, name: str) -> None:
    """
    Plain `--porcelain` C-quotes any path with a space or non-ASCII byte, so it
    reported `'"a file.txt"'` — quotes included, naming a file that does not
    exist. Latent in this repo, but the same defect as the leading-space bug and
    caught by the same property, which is why `-z` is used instead of an
    unescaper. Slicing at a fixed column also survives spaces where splitting on
    whitespace would not.
    """
    (repo / name).write_text("new\n", encoding="utf-8")

    _, dirty = git_state(repo)

    assert dirty == [name]
    assert (repo / dirty[0]).exists()


def test_rename_records_both_paths(repo: Path) -> None:
    """A rename is two `-z` records; the old path must not become its own entry."""
    _git(repo, "mv", "keep.txt", "renamed.txt")

    _, dirty = git_state(repo)

    assert dirty == ["keep.txt -> renamed.txt"]


def test_missing_git_repository_reads_as_dirty(tmp_path: Path) -> None:
    """
    An unverifiable tree must never look reproducible, so the failure mode is
    "dirty with a reason" rather than an empty list.
    """
    commit, dirty = git_state(tmp_path / "not-a-repo")

    assert commit == "unknown"
    assert dirty == ["<git unavailable>"]

# --------------------------------------------------------------------------- #
#  chunk_set_hash — the identity of a chunk set                                #
#                                                                              #
#  Everything downstream keys off this: the snapshot filename, the collection   #
#  metadata, and every point's payload. A digest that moved for a reason that   #
#  is not a content change would make every index look stale; one that stayed   #
#  put through a real change would make a stale index look current.            #
# --------------------------------------------------------------------------- #

# A complete, deliberately uninteresting metadata payload.
#
# These tests are about hashing and the file round-trip, not about what
# metadata says — they used to pass `{"k": "v"}` for exactly that reason. A
# fixed schema makes "arbitrary keys" unexpressible, so every chunk now needs a
# full one; keeping it dull keeps the tests reading as being about the hash.
_METADATA = {
    "article_number": "1",
    "article_title": "Subject-matter and objectives",
    "chapter": "1",
    "chapter_title": "General provisions",
    "regulation": "GDPR",
    "jurisdiction": "EU",
    "effective_date": "2018-05-25",
    "chunk_type": "article",
}


def _c(cid, text="text", **overrides):
    """
    A chunk with valid metadata. Keyword overrides vary one field at a time,
    which is what a test asserting *metadata* affects the digest needs — the
    old helper varied it by adding a key, and that is no longer possible.
    """
    return Chunk(id=cid, text=text, metadata=ChunkMetadata(**{**_METADATA, **overrides}))


def test_chunk_set_hash_is_deterministic():
    chunks = [_c("a"), _c("b")]
    assert chunk_set_hash(chunks) == chunk_set_hash(chunks)


def test_chunk_set_hash_ignores_generation_order():
    """
    Sorted by chunk ID, so the order chunks happen to be produced in cannot
    change the answer. `write_snapshot` deliberately writes in document order
    rather than hash order, which only works because identity is order-free.
    """
    a, b, c = _c("a"), _c("b"), _c("c")
    assert chunk_set_hash([a, b, c]) == chunk_set_hash([c, a, b])


def test_chunk_set_hash_ignores_metadata_key_order():
    """
    The order fields are supplied in must not reach the digest.

    This guarded `sort_keys=True` when metadata was a plain dict: two code paths
    building the same metadata in different insertion orders serialized to
    different bytes and hashed differently, so the same chunk set produced twice
    could disagree with itself.

    A typed `ChunkMetadata` removes that at the source — `model_dump()` emits
    declaration order whatever order the fields arrive in — so **this test
    cannot currently fail**, and it is kept deliberately as a tripwire on that
    normalization rather than as a live check. If metadata ever goes back to
    being a bare mapping, or the model stops normalizing, the guarantee would be
    lost in silence; this is what would say so.

    It does **not** protect `sort_keys=True` any more. Sorted order is not
    declaration order, so dropping `sort_keys` still moves every digest — but
    only `test_chunk_set_hash_is_pinned_to_golden_values` would notice.
    """
    forward = dict(_METADATA)
    backward = dict(reversed(list(_METADATA.items())))
    assert list(forward) != list(backward), "the two orders must actually differ"

    first = Chunk(id="a", text="t", metadata=ChunkMetadata(**forward))
    second = Chunk(id="a", text="t", metadata=ChunkMetadata(**backward))

    # Asserted separately so a failure names the layer that broke: the
    # normalization itself, or the hash that depends on it.
    assert list(first.metadata.model_dump()) == list(second.metadata.model_dump())
    assert chunk_set_hash([first]) == chunk_set_hash([second])


@pytest.mark.parametrize("mutate", [
    pytest.param(lambda c: Chunk(id=c.id, text=c.text + "!", metadata=c.metadata),
                 id="text"),
    pytest.param(lambda c: Chunk(id=c.id + "!", text=c.text, metadata=c.metadata),
                 id="id"),
])
def test_chunk_set_hash_changes_when_id_or_text_changes(mutate):
    original = _c("a")
    assert chunk_set_hash([original]) != chunk_set_hash([mutate(original)])


def _altered(metadata: ChunkMetadata, field: str) -> ChunkMetadata:
    """
    The same metadata with one field changed, whatever that field's type.

    Rebuilt through the model rather than with `model_copy(update=...)`, which
    skips validation: a `chunk_type` outside its `Literal` would sail through
    and the test would then pin behaviour on a value the schema forbids.
    """
    values = metadata.model_dump()
    if field == "chunk_type":
        values[field] = "paragraph" if values[field] == "article" else "article"
    elif values[field] is None:
        values[field] = "1"
    else:
        values[field] = values[field] + "!"
    return ChunkMetadata(**values)


@pytest.mark.parametrize("field", sorted(ChunkMetadata.model_fields))
def test_chunk_set_hash_changes_when_any_metadata_field_changes(field: str):
    """
    Every field is part of identity — enumerated from the model, not listed
    here, so a field added to `ChunkMetadata` is covered without anyone
    remembering to extend this.

    This replaced a single case that proved the point by adding an arbitrary
    key. That is no longer expressible against a fixed schema, and mutating one
    chosen field would have been strictly weaker than what it replaced: the
    realistic failure is not "metadata is ignored" but "*one field* is". `_row`
    dumps the model, and a dump narrowed by `exclude=` or `include=` would drop
    a field out of identity silently — with `paragraph_number` gone, Article
    12(1) and Article 12(2) hash the same, and a chunk set could change while
    the digest, the snapshot filename and every point's payload stayed put.
    """
    original = _c("a", chunk_type="paragraph", paragraph_number="1")
    altered = Chunk(
        id=original.id,
        text=original.text,
        metadata=_altered(original.metadata, field),
    )
    assert chunk_set_hash([original]) != chunk_set_hash([altered])


def test_chunk_set_hash_changes_when_a_chunk_is_added_or_removed():
    assert chunk_set_hash([_c("a")]) != chunk_set_hash([_c("a"), _c("b")])


def test_chunk_set_hash_is_pinned_to_golden_values():
    """
    Golden values, in the spirit of `test_point_id_namespace_is_pinned`. The
    scheme itself must never drift: every committed snapshot's filename, every
    collection's advertised digest and every indexed point's payload derive
    from it, so a change silently re-identifies artifacts already on disk and
    makes a correct index look permanently stale.

    An earlier version of this test tried to pin `ensure_ascii=False` by
    comparing an accented string against its escaped spelling. That was the
    wrong frame — escaping is still deterministic and injective, so it is not a
    correctness property at all, and the test passed happily when the flag was
    flipped. Stability is what actually matters here, and only a golden value
    expresses it. Non-ASCII text and unsorted input are folded into the fixture
    so the same assertion covers them.

    This is also the **only** test that covers stability across code versions.
    The other three hash tests vary input order, the process and the hash seed,
    and all of them recompute both sides — so a changed scheme moves both and
    they stay green. `test_chunk_set_hash_ignores_metadata_key_order` no longer
    guards `sort_keys=True` either, now that a typed model normalizes field
    order at the source. If this test is weakened, nothing is left.

    A failure here means the hashing scheme changed. That is not necessarily
    wrong, but it invalidates every snapshot in `data/chunks/` and every
    collection built from one — so it must be a decision, not a side effect.

    ### Regenerated 2026-08-09, when `Chunk.metadata` became `ChunkMetadata`

    The old fixture carried `{"z": 1, "a": [2, 3]}` and `{"paragraph": "1"}`,
    shapes a fixed schema rejects, so the value could not simply be re-pinned —
    the fixture had to change too. Nested metadata is gone from the docstring
    above because it is no longer constructible; every field is now a string.
    Added in its place: both `chunk_type` branches, so `paragraph_number` is
    covered set *and* `None`.

    The digest was **not** taken from whatever the code emitted. It was derived
    independently, by writing out the canonical form by hand from the rules in
    `chunk_store`'s module docstring — rows sorted by id, keys sorted at every
    level, `separators=(",", ":")`, `ensure_ascii=False` — hashing that string,
    and confirming the two agreed. Pasting the implementation's own output would
    have made the pin a restatement of the code rather than a check on it, and
    regeneration is the one moment when that distinction is invisible.

    The empty-chunk-set value is unchanged and needs no regeneration: it is
    `sha256(b"[]")` and touches no metadata at all.
    """
    common = dict(chapter="1", chapter_title="General provisions",
                  regulation="GDPR", jurisdiction="EU",
                  effective_date="2018-05-25")
    chunks = [
        # Deliberately unsorted — article_2 first — so the sort in
        # `_canonical_rows` is part of what the golden value pins.
        Chunk(id="gdpr_article_2", text="données — personnelles",
              metadata=ChunkMetadata(article_number="2",
                                     article_title="Champ d'application",
                                     chunk_type="paragraph",
                                     paragraph_number="1", **common)),
        Chunk(id="gdpr_article_1", text="Scope",
              metadata=ChunkMetadata(article_number="1",
                                     article_title="Subject-matter",
                                     chunk_type="article", **common)),
    ]

    assert chunk_set_hash(chunks) == (
        "8ff0c98eeac4707265d9be0dffce9374409a94c2181573341635e6bbe0822daf"
    )
    assert chunk_set_hash([]) == (
        "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945"
    )


# Seeds that always run. `0` is qualitatively different from the rest — it
# disables hash randomization outright rather than seeding it, so it exercises a
# different branch in CPython's startup, not just another point in the same
# space. `1` is the minimal enabled case.
#
# Any seed that has ever been seen to fail belongs here permanently: that is how
# a one-off observation becomes a standing regression test.
_FIXED_HASH_SEEDS = (0, 1)

# Drawn fresh on every collection, so coverage widens across runs instead of
# retesting the same points forever.
_RANDOM_HASH_SEEDS = 3


def _hash_seeds() -> List[int]:
    """
    Fixed seeds plus fresh random ones.

    Chosen *here* rather than delegated to `PYTHONHASHSEED=random`, which is a
    sentinel telling CPython to draw its own seed from OS entropy. That reads
    like the same thing and is not: the interpreter never exposes the seed it
    generated — `sys.hash_info.seed_bits` is the width, not the value, and the
    environment variable still just says "random" — so a failure under it is
    irreproducible *in principle*. Picking the integer on this side keeps the
    breadth and makes every failure replayable, because we know what we passed.

    Deliberately not seeded from the clock. `random` is already seeded from
    `os.urandom(32)` at import; seeding from `time.time()` would be strictly
    worse, and worse precisely where it matters — parallel CI jobs starting in
    the same second would draw *identical* seeds while appearing to sample
    independently.
    """
    return [*_FIXED_HASH_SEEDS,
            *(random.randrange(2 ** 32) for _ in range(_RANDOM_HASH_SEEDS))]


@pytest.mark.parametrize("seed", _hash_seeds())
def test_chunk_set_hash_is_stable_across_processes(seed: int):
    """
    The property hand-verified on 2026-08-06 and never guarded since: a digest
    regenerated tomorrow, in a fresh interpreter, must equal today's. One that
    shifted between runs would make every index permanently stale.

    Hash randomization perturbs set iteration order — the thing an in-process
    test cannot vary. Reading the implementation says this should be safe
    (`sorted()` by ID, `sort_keys=True`, no set anywhere in the path), but that
    reasoning is exactly what a hand-verification already assumed; the
    subprocess is what makes it observed rather than argued. It cannot currently
    fail for that same reason — it is a tripwire against a `set()` appearing in
    the canonical path later, not a live check.

    The chunk set is built here and handed over as JSON rather than written into
    the child's source. The fixture used to live inside the `-c` string, where
    no symbol search and no IDE rename could reach it — which is how it went on
    passing untyped metadata for two days after `Chunk` was retyped, and why the
    package move before that had to have this program's import paths corrected
    by hand. Named once, in real code, it breaks visibly instead.

    Was one invocation under `PYTHONHASHSEED=random`, on the grounds that
    importing the package cost ~17s. That cost is 0.27s since
    `src/clause_and_effect/__init__.py` stopped importing the world
    (2026-08-09), so the constraint that shaped this test no longer applies.
    """
    chunks = [
        _c("b", "second"),
        _c("a", "first", chunk_type="paragraph", paragraph_number="1"),
    ]
    repo_root = Path(__file__).resolve().parents[1]
    program = (
        "import json,sys;"
        "from src.clause_and_effect.chunking.chunk_store import chunk_set_hash;"
        "from src.clause_and_effect.chunking import Chunk;"
        "print(chunk_set_hash([Chunk(**row) for row in json.loads(sys.argv[1])]))"
    )
    result = subprocess.run(
        [sys.executable, "-c", program,
         json.dumps([c.model_dump() for c in chunks], ensure_ascii=False)],
        cwd=repo_root, capture_output=True, text=True, check=True,
        env={"PATH": "/usr/bin:/bin", "PYTHONPATH": str(repo_root),
             "PYTHONHASHSEED": str(seed)},
    )

    # The seed goes in the message, not a print: pytest swallows stdout for
    # passing tests, and this is the one fact that makes a failure replayable.
    assert result.stdout.strip() == chunk_set_hash(chunks), (
        f"digest depends on the interpreter's hash seed; "
        f"reproduce with PYTHONHASHSEED={seed}"
    )


def test_file_hash_is_sha256_of_the_bytes(tmp_path: Path):
    target = tmp_path / "corpus.json"
    target.write_bytes(b"[]\n")
    assert file_hash(target) == hashlib.sha256(b"[]\n").hexdigest()


# --------------------------------------------------------------------------- #
#  Snapshot naming and discovery                                               #
# --------------------------------------------------------------------------- #

def test_snapshot_name_embeds_timestamp_and_hash_prefix():
    stamp = datetime(2026, 8, 7, 6, 46, 58, tzinfo=timezone.utc)
    assert snapshot_name(stamp, "157d4d385908" + "0" * 52) == (
        "chunks_2026-08-07_064658_157d4d38"
    )


def test_snapshot_names_sort_chronologically():
    """
    `list_snapshots` orders by filename, which is chronological only because
    the timestamp is fixed-width and zero-padded. A single-digit hour rendered
    without its zero would sort after a double-digit one.
    """
    digest = "a" * 64
    early = snapshot_name(datetime(2026, 8, 7, 9, 5, 3, tzinfo=timezone.utc), digest)
    late = snapshot_name(datetime(2026, 8, 7, 10, 5, 3, tzinfo=timezone.utc), digest)
    assert early < late


def test_list_snapshots_is_empty_for_missing_or_empty_directory(tmp_path: Path):
    assert list_snapshots(tmp_path / "nope") == []
    assert latest_snapshot(tmp_path / "nope") is None
    assert list_snapshots(tmp_path) == []
    assert latest_snapshot(tmp_path) is None


def test_list_snapshots_ignores_manifests_and_strangers(tmp_path: Path):
    (tmp_path / f"chunks_2026-08-07_000001_aaaaaaaa{SNAPSHOT_SUFFIX}").touch()
    (tmp_path / f"chunks_2026-08-07_000001_aaaaaaaa{MANIFEST_SUFFIX}").touch()
    (tmp_path / "notes.md").touch()

    found = list_snapshots(tmp_path)

    assert [p.name for p in found] == [
        f"chunks_2026-08-07_000001_aaaaaaaa{SNAPSHOT_SUFFIX}"
    ]


def test_latest_snapshot_returns_the_newest(tmp_path: Path):
    for stamp in ["000001", "000003", "000002"]:
        (tmp_path / f"chunks_2026-08-07_{stamp}_aaaaaaaa{SNAPSHOT_SUFFIX}").touch()

    assert latest_snapshot(tmp_path).name.startswith("chunks_2026-08-07_000003")


def test_list_snapshots_sorts_what_the_filesystem_hands_back(
    tmp_path: Path, monkeypatch
):
    """
    `glob` returns directory order, which is arbitrary and filesystem-specific.
    Creating files in a scrambled order does *not* test the sort: dropping
    `sorted()` from `list_snapshots` left the test above green, because this
    directory happened to enumerate in the order the assertion wanted. Passing
    for an accidental reason is worse than failing.

    Forcing `glob` to hand back a known-bad order is what makes the assertion
    mean something. It matters because `latest_snapshot` is how every script
    picks the snapshot to index, and ordering is only chronological by
    convention — the timestamp being fixed-width and zero-padded.
    """
    names = [
        f"chunks_2026-08-07_00000{i}_aaaaaaaa{SNAPSHOT_SUFFIX}" for i in (1, 2, 3)
    ]
    for name in names:
        (tmp_path / name).touch()

    real_glob = Path.glob
    monkeypatch.setattr(
        Path, "glob", lambda self, pattern: reversed(list(real_glob(self, pattern)))
    )

    assert [p.name for p in list_snapshots(tmp_path)] == names
    assert latest_snapshot(tmp_path).name == names[-1]


def test_manifest_path_for_sits_beside_the_chunks_file(tmp_path: Path):
    chunks_path = tmp_path / f"chunks_2026-08-07_000001_aaaaaaaa{SNAPSHOT_SUFFIX}"
    assert manifest_path_for(chunks_path) == (
        tmp_path / f"chunks_2026-08-07_000001_aaaaaaaa{MANIFEST_SUFFIX}"
    )


# --------------------------------------------------------------------------- #
#  write_snapshot / read_snapshot — the round trip and the tamper check        #
# --------------------------------------------------------------------------- #

_STAMP = datetime(2026, 8, 7, 6, 46, 58, tzinfo=timezone.utc)


def _written(tmp_path: Path, chunks, **manifest_overrides):
    """Write a snapshot into tmp_path and return its chunks file."""
    manifest = {
        "chunk_set_sha256": chunk_set_hash(chunks),
        "chunk_count": len(chunks),
        "created_at": "2026-08-07T06:46:58Z",
        **manifest_overrides,
    }
    chunks_path, _ = write_snapshot(chunks, tmp_path, manifest, _STAMP)
    return chunks_path


def test_snapshot_round_trip_preserves_chunks_exactly(tmp_path: Path):
    """
    Both chunk shapes, and text that is not ASCII: `ensure_ascii=False` is what
    keeps "données" readable in the archive rather than escaped, and the round
    trip is what proves the choice does not corrupt it.
    """
    chunks = [
        _c("gdpr_article_2", "Scope", chunk_type="paragraph", paragraph_number="1"),
        _c("gdpr_article_5", "données — personnelles", article_number="5"),
    ]

    loaded = read_snapshot(_written(tmp_path, chunks))

    assert [(c.id, c.text, c.metadata) for c in loaded.chunks] == [
        (c.id, c.text, c.metadata) for c in chunks
    ]
    assert loaded.chunk_set_sha256 == chunk_set_hash(chunks)


def test_snapshot_preserves_generation_order_not_hash_order(tmp_path: Path):
    """
    Written in document order so a human can read it and a diff shows which
    chunks changed. Identity is order-free (see the hash tests), which is what
    makes that safe.
    """
    chunks = [_c("gdpr_article_2"), _c("gdpr_article_10"), _c("gdpr_article_3")]

    loaded = read_snapshot(_written(tmp_path, chunks))

    assert [c.id for c in loaded.chunks] == [
        "gdpr_article_2", "gdpr_article_10", "gdpr_article_3"
    ]


def test_snapshot_is_one_json_object_per_line(tmp_path: Path):
    """
    The format is load-bearing for review: a reflowed array would make every
    diff between two snapshots useless.
    """
    chunks = [_c("a"), _c("b"), _c("c")]

    text = _written(tmp_path, chunks).read_text(encoding="utf-8")

    lines = [line for line in text.splitlines() if line.strip()]
    assert len(lines) == 3
    assert [json.loads(line)["id"] for line in lines] == ["a", "b", "c"]


def test_read_snapshot_rejects_edited_chunk_text(tmp_path: Path):
    """
    The tamper check, and the reason `read_snapshot` exists rather than a plain
    JSON load. A hand-edited chunks file would otherwise be indexed as though it
    were the recorded chunk set, and the collection would advertise a digest it
    does not hold.
    """
    chunks_path = _written(tmp_path, [_c("a", "original"), _c("b", "other")])
    rows = chunks_path.read_text(encoding="utf-8").splitlines()
    first = json.loads(rows[0])
    first["text"] = "tampered"
    rows[0] = json.dumps(first, ensure_ascii=False)
    chunks_path.write_text("\n".join(rows) + "\n", encoding="utf-8")

    with pytest.raises(ValueError, match="does not match its manifest"):
        read_snapshot(chunks_path)


def _edited(tmp_path: Path, edit) -> Path:
    """Write a one-chunk snapshot, then apply `edit` to the row on disk."""
    chunks_path = _written(tmp_path, [_c("a")])
    row = json.loads(chunks_path.read_text(encoding="utf-8").strip())
    edit(row)
    chunks_path.write_text(json.dumps(row) + "\n", encoding="utf-8")
    return chunks_path


# --------------------------------------------------------------------------- #
#  Editing metadata has three outcomes, and which one you get depends on how   #
#  the file was edited. They must stay distinguishable in both directions:     #
#  reporting a merely-old snapshot as corrupt sends the reader hunting for     #
#  tampering that did not happen, and reporting a tampered one as old tells    #
#  them to regenerate it instead of investigating.                             #
# --------------------------------------------------------------------------- #

def test_read_snapshot_rejects_an_edited_metadata_value(tmp_path: Path):
    """
    Metadata is part of identity, so editing a field must fail exactly as an
    edited `text` does. The schema is still satisfied here — the chunk loads
    cleanly and it is the re-hash that catches it, which is the tamper check
    doing its job.
    """
    chunks_path = _edited(
        tmp_path, lambda row: row["metadata"].__setitem__("article_title", "tampered")
    )

    with pytest.raises(ValueError, match="does not match its manifest"):
        read_snapshot(chunks_path)


def test_read_snapshot_rejects_an_unknown_metadata_key(tmp_path: Path):
    """
    An unknown key is rejected **before** hashing, and that rejection is
    load-bearing for integrity rather than for error messages.

    Pydantic ignores unknown keys by default. Without the check, adding one to a
    chunks file on disk is discarded at load, the reconstructed chunks are
    identical to the originals, the re-hash matches the manifest, and
    `read_snapshot` returns a `Snapshot` as though nothing happened — verified
    2026-08-09 by disabling only that branch. **The tamper check cannot catch an
    edit the loader throws away before hashing.** This is the only thing between
    a hand-edited metadata key and a clean bill of health.
    """
    chunks_path = _edited(
        tmp_path, lambda row: row["metadata"].__setitem__("paragraph", "99")
    )

    with pytest.raises(LegacySnapshotError, match="predates the current chunk schema"):
        read_snapshot(chunks_path)


def test_read_snapshot_rejects_a_missing_required_field(tmp_path: Path):
    """
    The other way a row can fail the schema: a field removed rather than added.
    Caught as a `ValidationError` and re-raised with the file named, since the
    bare pydantic error says nothing about which snapshot it came from.
    """
    chunks_path = _edited(tmp_path, lambda row: row["metadata"].pop("chapter"))

    with pytest.raises(LegacySnapshotError, match="does not fit the current chunk schema"):
        read_snapshot(chunks_path)


def test_read_snapshot_reports_a_real_legacy_snapshot_as_legacy(tmp_path: Path):
    """
    The direction `LegacySnapshotError` was introduced for, against the shape
    actually on disk: `chunks_2026-08-07_081627_a231f919` carries `topics` on
    every chunk and `paragraph` on its 330 paragraph chunks.

    Before the check existed, pydantic dropped both keys, the re-hash then
    disagreed with the manifest, and the reader was told *"chunk set does not
    match its manifest"* — the message written for a hand-edited or truncated
    file. The file was intact; only the schema had moved.

    Reconstructed here rather than read from `data/chunks/`, so the test states
    the shape it is about and keeps working once that archive is retired.
    """
    chunks_path = _written(tmp_path, [_c("a")])
    row = json.loads(chunks_path.read_text(encoding="utf-8").strip())
    row["metadata"]["topics"] = ["data_subject_rights", "processing"]
    row["metadata"]["paragraph"] = row["metadata"].pop("paragraph_number")
    chunks_path.write_text(json.dumps(row) + "\n", encoding="utf-8")

    with pytest.raises(LegacySnapshotError) as raised:
        read_snapshot(chunks_path)

    # Both offending keys named, so the reader learns which schema it predates
    # rather than only that it does.
    assert "paragraph" in str(raised.value) and "topics" in str(raised.value)
    assert "does not match its manifest" not in str(raised.value)


def test_read_snapshot_rejects_a_truncated_file(tmp_path: Path):
    """A failed write that lost its tail must not read back as a smaller set."""
    chunks_path = _written(tmp_path, [_c("a"), _c("b"), _c("c")])
    rows = chunks_path.read_text(encoding="utf-8").splitlines()
    chunks_path.write_text("\n".join(rows[:2]) + "\n", encoding="utf-8")

    with pytest.raises(ValueError):
        read_snapshot(chunks_path)


def test_read_snapshot_rejects_a_count_that_disagrees_with_the_manifest(tmp_path: Path):
    """
    Belt and braces beside the digest. A manifest whose count was written from
    a different set is a paired-wrongly snapshot even if someone recomputed the
    hash to match.
    """
    chunks = [_c("a"), _c("b")]
    chunks_path = _written(tmp_path, chunks, chunk_count=99)

    with pytest.raises(ValueError, match="chunk_count|records 99|holds 2"):
        read_snapshot(chunks_path)


def test_read_snapshot_requires_a_manifest(tmp_path: Path):
    chunks_path = _written(tmp_path, [_c("a")])
    manifest_path_for(chunks_path).unlink()

    with pytest.raises(FileNotFoundError, match="no manifest"):
        read_snapshot(chunks_path)


def test_write_snapshot_creates_the_directory(tmp_path: Path):
    target = tmp_path / "nested" / "chunks"
    chunks = [_c("a")]

    chunks_path, manifest_path = write_snapshot(
        chunks, target,
        {"chunk_set_sha256": chunk_set_hash(chunks), "chunk_count": 1},
        _STAMP,
    )

    assert chunks_path.exists() and manifest_path.exists()


# --------------------------------------------------------------------------- #
#  build_manifest                                                              #
# --------------------------------------------------------------------------- #

# Deliberately not `GDPR`. `build_manifest` records the chunker's regulation by
# reading it off the live object, and against the real constant a test could not
# tell that apart from the hardcoded `"GDPR"` string this replaced — which is the
# exact failure being guarded against, since the field it replaced sat wrong for
# two days.
_TEST_REGULATION = Regulation(
    name="TESTREG",
    jurisdiction="XX",
    effective_date="2000-01-01",
    chapter_titles={"1": "Only chapter"},
)


class _SubclassedChunker(Chunker):
    """
    A chunker whose class name is not `Chunker`.

    Same reason `_TEST_REGULATION` is not `GDPR`: the manifest records
    `type(chunker).__name__`, and against the real class that is indistinguishable
    from the hardcoded `"Chunker"` a future edit might reintroduce.
    """


def _manifest(repo: Path, chunks=None):
    source = repo / "data" / "regulations" / "gdpr_articles.json"
    source.parent.mkdir(parents=True, exist_ok=True)
    source.write_text('[{"number": "1"}]', encoding="utf-8")
    return build_manifest(
        chunks if chunks is not None else [_c("a", "x"), _c("b", "yy")],
        chunker=_SubclassedChunker(regulation=_TEST_REGULATION),
        source_path=source,
        source_description={"article_count": 1},
        repo_root=repo,
        created_at=_STAMP,
    )


def test_manifest_records_the_source_path_relative_to_the_repo(repo: Path):
    """
    An absolute path bakes one machine's home directory into an artifact that
    is committed and read by others. This was written absolute once and caught
    by reading the output rather than by any check — now it is checked.
    """
    manifest = _manifest(repo)

    assert manifest["source"]["path"] == "data/regulations/gdpr_articles.json"
    assert not Path(manifest["source"]["path"]).is_absolute()


def test_manifest_carries_hash_count_and_source_description(repo: Path):
    chunks = [_c("a", "x"), _c("b", "yy")]

    manifest = _manifest(repo, chunks)

    assert manifest["chunk_set_sha256"] == chunk_set_hash(chunks)
    assert manifest["chunk_count"] == 2
    assert manifest["source"]["article_count"] == 1
    assert manifest["stats"]["chars"] == {"total": 3, "min": 1, "median": 2, "max": 2}


def test_manifest_git_dirty_agrees_with_its_path_list(repo: Path):
    """
    Emptiness is the dirty check — there is no separate flag that could drift
    out of sync with the list. Pin both directions.
    """
    clean = _manifest(repo)
    assert clean["git_dirty"] is bool(clean["git_dirty_paths"])

    (repo / "uv.lock").write_text("changed\n", encoding="utf-8")
    dirty = _manifest(repo)
    assert dirty["git_dirty"] is True
    assert "uv.lock" in dirty["git_dirty_paths"]


def test_manifest_truncates_a_very_dirty_tree(repo: Path):
    """
    A mass refactor must not turn the manifest into a file listing, but the
    overflow has to say how much it hid — a silently truncated list reads as a
    complete one.
    """
    for i in range(60):
        (repo / f"file_{i:03d}.txt").write_text("x", encoding="utf-8")

    manifest = _manifest(repo)

    paths = manifest["git_dirty_paths"]
    assert len(paths) == 51, "50 paths plus one overflow marker"
    assert "more" in paths[-1]
    assert manifest["git_dirty"] is True


def test_manifest_records_the_chunker_that_actually_ran(repo: Path):
    """
    Provenance read off the live chunker, never typed in.

    This field said `{"class": "GDPRParser", "method": "article_to_chunks"}` for
    two days after the chunker moved out of the parser and that method ceased to
    exist — a manifest naming a producer that could not have produced it. It is
    the exact hazard the module docstring warns about ("any constant duplicated
    here becomes a second source of truth"), and the field proved the warning.

    Both values are deliberately unlike the production ones. `_TEST_REGULATION`
    is not `GDPR`, and the chunker is a subclass rather than a `Chunker` — with
    the real types, `type(chunker).__name__` and `chunker.regulation.name` would
    each produce exactly the string a hardcoded literal would, and this
    assertion would pass against the very bug it exists to catch. Verified: with
    a plain `Chunker`, re-hardcoding `"class": "Chunker"` does not fail.
    """
    manifest = _manifest(repo)

    assert manifest["chunker"] == {"class": "_SubclassedChunker",
                                   "regulation": "TESTREG"}


def test_manifest_stats_count_both_chunk_types(repo: Path):
    """`by_chunk_type` reads the typed field; it used to `.get` a dict."""
    chunks = [
        _c("a", chunk_type="article"),
        _c("b", chunk_type="paragraph", paragraph_number="1"),
        _c("c", chunk_type="paragraph", paragraph_number="2"),
    ]

    manifest = _manifest(repo, chunks)

    assert manifest["stats"]["by_chunk_type"] == {"article": 1, "paragraph": 2}


def test_written_rows_are_the_rows_that_were_hashed(tmp_path: Path):
    """
    The hash and the writer must serialize a chunk identically.

    They are both `_row` for that reason. When they were two separate literals,
    any drift between them would have made a freshly written snapshot fail its
    own tamper check on the very next read — a failure that reads as corruption
    and is really a mismatch between two copies of the same idea.

    Asserted against the file on disk rather than by calling `_row` twice, so it
    still holds if the two ever diverge again.
    """
    chunks = [
        _c("a", "first"),
        _c("b", "second", chunk_type="paragraph", paragraph_number="1"),
    ]
    chunks_path = _written(tmp_path, chunks)

    written = [
        json.loads(line)
        for line in chunks_path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    # Same rows the digest was taken over, modulo the writer's document order.
    assert sorted(written, key=lambda r: r["id"]) == _canonical_rows(chunks)

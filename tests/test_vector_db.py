"""
Tests for VectorDatabase point-ID derivation and indexing invariants.

These cover the layer between chunking and Qdrant, which had no tests and two
latent hazards:

  * Point IDs were assigned positionally (`i*batch_size + j`, where `i` was
    already an offset rather than a batch counter). The arithmetic happened to
    stay collision-free, but nothing verified that, and positional IDs re-key
    the whole corpus whenever chunk composition changes.
  * Qdrant's upsert silently overwrites a repeated point ID, and
    embed_and_upsert_chunks reported success using len(chunks) — the input — so
    a collision would have been invisible.

No live Qdrant or embedding API is used: __init__ is bypassed and the client
and embedding generator are replaced with fakes, so these run offline.
"""
import logging
import uuid

import pytest
from qdrant_client.models import PointStruct

from src.clause_and_effect.chunking.chunk_store import chunk_set_hash
from src.clause_and_effect.chunking import Chunk, ChunkMetadata, ChunkSetMetadata
from src.clause_and_effect.retrieval.vector_db import (
    _ORPHAN_REPORT_LIMIT,
    IndexVerificationError,
    VectorDatabase,
)


# --------------------------------------------------------------------------- #
#  point_id                                                                    #
# --------------------------------------------------------------------------- #

def test_point_id_is_deterministic():
    assert VectorDatabase.point_id("gdpr_article_5_para_1") == VectorDatabase.point_id(
        "gdpr_article_5_para_1"
    )


def test_point_id_is_a_uuid_accepted_by_qdrant():
    """Qdrant point IDs must be unsigned ints or UUIDs — not arbitrary strings."""
    pid = VectorDatabase.point_id("gdpr_article_28")
    assert isinstance(pid, uuid.UUID)
    assert PointStruct(id=pid, vector=[0.0], payload={}).id == pid


def test_point_id_namespace_is_pinned():
    """
    Golden values. The namespace must never change: every point ID in every
    existing collection derives from it, so a change silently re-keys the
    corpus and a re-index writes parallel points instead of updating in place.
    A failure here means someone edited POINT_ID_NAMESPACE.
    """
    assert str(VectorDatabase.point_id("gdpr_article_1")) == (
        "6ecf1937-038d-5d62-bda0-4ab86bd9482a"
    )
    assert str(VectorDatabase.point_id("gdpr_article_5_para_1")) == (
        "790c3d0b-2f38-54f4-b1d7-df789a4d6998"
    )
    assert str(VectorDatabase.point_id("gdpr_article_99_para_3")) == (
        "c28bcc2a-b3f5-5159-b83e-85c6d8bec78d"
    )


def test_distinct_chunk_ids_yield_distinct_point_ids():
    chunk_ids = [f"gdpr_article_{a}_para_{p}" for a in range(1, 100) for p in range(1, 12)]
    point_ids = {VectorDatabase.point_id(c) for c in chunk_ids}
    assert len(point_ids) == len(chunk_ids)


# --------------------------------------------------------------------------- #
#  Fakes                                                                       #
# --------------------------------------------------------------------------- #

class _FakeCount:
    def __init__(self, count):
        self.count = count


class _FakePoint:
    def __init__(self, point_id, payload):
        self.id = point_id
        self.payload = payload


class _FakeVectors:
    size = 1536


class _FakeParams:
    vectors = _FakeVectors()


class _FakeConfig:
    def __init__(self, metadata):
        self.metadata = metadata
        self.params = _FakeParams()


class _FakeCollection:
    def __init__(self, metadata):
        self.config = _FakeConfig(metadata)


class _FakeClient:
    """
    An in-memory stand-in for the parts of Qdrant this module uses.

    Two real behaviours are modelled deliberately, because both have already
    cost this project something:

      * an upsert of a repeated point ID overwrites rather than appends, which
        is why `embed_and_upsert_chunks` verifies against the collection and not
        its input;
      * `update_collection` **merges** metadata, so a key written once survives
        an update that does not mention it.
    """

    def __init__(self, metadata=None, fail_upsert_after=None):
        self.upserted = []
        self.points = {}          # str(point_id) -> payload
        # Point IDs this client accepts and silently fails to persist. An upsert
        # that raises is the easy case; this models the one that does not — the
        # server returns success and the point is not there afterwards, which is
        # the only reason the post-write check reads the collection back instead
        # of trusting the call. Recorded in `upserted` regardless: the write was
        # sent, and "sent" and "stored" being different things is the point.
        self.drop_ids = set()
        self.metadata = metadata  # None models a collection nothing has stamped
        self.deleted = []
        self.delete_calls = []
        self.upsert_calls = 0
        # Counted, not just observed through `self.metadata`, for the same
        # reason `delete_calls` exists: "never called" and "called and wrote
        # nothing" are the same by outcome here and very much not the same
        # guarantee.
        self.update_calls = 0
        # A delete the server accepts and does not perform. `UpdateResult`
        # carries an operation id and a status, no tally, so a no-op delete is
        # indistinguishable from a successful one at the call site — which is
        # why `index_chunks` looks at the collection again instead of trusting
        # the return.
        self.delete_is_a_noop = False
        # Batch index at which upsert starts raising, to model a run that dies
        # partway. The batches already written stay written — which is the whole
        # point: a crash leaves the collection holding two chunk sets at once.
        self._fail_upsert_after = fail_upsert_after

    # --- points ----------------------------------------------------------- #

    def upsert(self, collection_name, points):
        if (self._fail_upsert_after is not None
                and self.upsert_calls >= self._fail_upsert_after):
            raise ConnectionError("connection lost mid-index")
        self.upsert_calls += 1
        self.upserted.extend(points)
        for point in points:
            if str(point.id) in self.drop_ids:
                continue
            self.points[str(point.id)] = point.payload

    def count(self, collection_name, exact=True):
        # Kept because `index_documents.py` calls it when reporting a run, but
        # `vector_db` itself no longer does: verification moved from comparing
        # totals to comparing identities. The knob that used to force a wrong
        # answer here is gone with it — a fake that can lie about a number
        # nothing reads is a trap, not a test seam.
        return _FakeCount(len(self.points))

    def scroll(self, collection_name, limit, offset=None, with_payload=None,
               with_vectors=None):
        """
        Qdrant's offset is the ID to resume *from*, not a row number.

        `with_payload` is honoured rather than ignored. A field the caller did
        not ask for is genuinely absent from the response, so a reader that
        forgets to request `chunk_set_sha256` sees None for every point and
        concludes the whole collection is stale. A fake that returned the full
        payload regardless would make that bug invisible.
        """
        ids = sorted(self.points)
        start = 0 if offset is None else ids.index(str(offset))
        page = ids[start:start + limit]
        next_offset = ids[start + limit] if start + limit < len(ids) else None

        def projected(payload):
            if isinstance(with_payload, list):
                return {k: v for k, v in payload.items() if k in with_payload}
            return payload

        return [_FakePoint(pid, projected(self.points[pid])) for pid in page], next_offset

    def delete(self, collection_name, points_selector, wait=True):
        # Every invocation is recorded, not just every deleted point, so a test
        # can distinguish "never called" from "called with an empty selector".
        # Those are the same by outcome here and very much not the same against
        # a real server.
        self.delete_calls.append(list(points_selector.points))
        if self.delete_is_a_noop:
            return
        for point_id in points_selector.points:
            self.points.pop(str(point_id), None)
            self.deleted.append(str(point_id))

    # --- collection ------------------------------------------------------- #

    def collection_exists(self, collection_name):
        return True

    def get_collection(self, collection_name):
        return _FakeCollection(self.metadata)

    def update_collection(self, collection_name, metadata=None, **kwargs):
        self.update_calls += 1
        if metadata is not None:
            self.metadata = {**(self.metadata or {}), **metadata}


class _FakeEmbeddings:
    def embed_batch(self, batch):
        return [[0.1, 0.2, 0.3] for _ in batch]

    def get_model(self):
        # Recorded into the collection metadata by `index_chunks`, which reads
        # it off the generator that ran rather than off settings — so it says
        # what was used, not what config claimed.
        return "fake-embedding-model"


def _make_db():
    """Build a VectorDatabase without touching Qdrant or OpenAI."""
    db = VectorDatabase.__new__(VectorDatabase)
    db.collection_name = "test_collection"
    db.client = _FakeClient()
    db.embedding_generator = _FakeEmbeddings()
    return db


def _chunks(*ids):
    """
    Chunks distinguishable by ID alone, carrying a complete `ChunkMetadata`.

    `article_number` is the chunk ID rather than a bare number so that a test
    reading a point's payload back can say *which* chunk's metadata landed on
    it. The remaining fields are required by the model and asserted on nowhere;
    they are fixed values, not fixture parameters.
    """
    return [
        Chunk(
            id=chunk_id,
            text=f"text for {chunk_id}",
            metadata=ChunkMetadata(
                article_number=chunk_id,
                article_title=f"Title of {chunk_id}",
                chapter="I",
                chapter_title="General provisions",
                effective_date="2018-05-25",
                jurisdiction="EU",
                regulation="GDPR",
                chunk_type="article",
            ),
        )
        for chunk_id in ids
    ]


# The digest a test must supply and has no opinion about. Deliberately *not*
# `chunk_set_hash(chunks)`: the digest is now whatever the caller says it is,
# so passing the chunks' own hash here would re-teach, test by test, the
# coupling that was removed on purpose.
#
# This constant does not, on its own, *catch* a re-derivation: the tests below
# that use it never read the stamped value back, so they stay green either way.
# What catches it is `stamps_the_digest_it_is_given`, which reads it back and
# is the one test in this file that fails against a re-deriving primitive.
_ANY_DIGEST = "0" * 64

# The digest of whatever the collection held *before* the run under test —
# distinct from `_ANY_DIGEST` so that "left over from an earlier chunk set" and
# "written by this one" are never the same value by accident.
_PRIOR_DIGEST = "1" * 64


def _chunk_set_metadata(**overrides):
    """
    The provenance `index_chunks` records on the collection.

    Takes no chunks, deliberately. `chunk_set_id` defaults to `_ANY_DIGEST`
    rather than `chunk_set_hash(chunks)` for the reason above — the digest is
    the caller's to supply — and a fixture accepting the chunks would imply it
    was derived from them even while it wasn't.
    """
    fields = dict(
        chunk_set_id=_ANY_DIGEST,
        snapshot="chunks_2026-08-10T00-00-00Z_0000000.jsonl",
        source_sha256="85fba45c40b6" + "0" * 52,
        chunker_commit="3bf78bb",
        chunker_tree_dirty=False,
    )
    fields.update(overrides)
    return ChunkSetMetadata(**fields)


# --------------------------------------------------------------------------- #
#  embed_and_upsert_chunks                                                     #
# --------------------------------------------------------------------------- #

def test_embed_and_upsert_chunks_keys_points_by_chunk_id():
    db = _make_db()
    chunks = _chunks("gdpr_article_1", "gdpr_article_2", "gdpr_article_3")
    db.embed_and_upsert_chunks(chunks, _ANY_DIGEST)

    assert [p.id for p in db.client.upserted] == [
        VectorDatabase.point_id(c.id) for c in chunks
    ]


def test_embed_and_upsert_chunks_is_idempotent():
    """Re-indexing the same corpus must update points, not duplicate them."""
    db = _make_db()
    chunks = _chunks("gdpr_article_1", "gdpr_article_2")
    db.embed_and_upsert_chunks(chunks, _ANY_DIGEST)
    first = {p.id for p in db.client.upserted}
    db.embed_and_upsert_chunks(chunks, _ANY_DIGEST)
    assert {p.id for p in db.client.upserted} == first


def test_embed_and_upsert_chunks_spans_multiple_batches():
    """IDs must stay unique across batch boundaries (batch_size is 100)."""
    db = _make_db()
    chunks = _chunks(*[f"gdpr_article_{i}" for i in range(250)])
    db.embed_and_upsert_chunks(chunks, _ANY_DIGEST)
    assert len(db.client.upserted) == 250
    assert len({p.id for p in db.client.upserted}) == 250


def test_embed_and_upsert_chunks_rejects_duplicate_chunk_ids():
    db = _make_db()
    chunks = _chunks("gdpr_article_1", "gdpr_article_2", "gdpr_article_1")
    with pytest.raises(ValueError, match="unique"):
        db.embed_and_upsert_chunks(chunks, _ANY_DIGEST)
    assert db.client.upserted == [], "nothing should be written when input is invalid"


# --------------------------------------------------------------------------- #
#  index_chunks                                                                #
#                                                                              #
#  The reconcile step in front of the write primitive. It used to delegate and #
#  nothing more; it now creates the collection, writes, prunes what no chunk   #
#  maps onto, verifies twice, and records the provenance — the pruning half     #
#  has its own section below. These cover the seam and the record: the points   #
#  the primitive writes must still be written, the digest must reach it         #
#  unaltered, and the dict handed back must be the one that was stored.         #
# --------------------------------------------------------------------------- #

def test_index_chunks_writes_the_points_embed_and_upsert_writes():
    db = _make_db()
    chunks = _chunks("gdpr_article_1", "gdpr_article_2")

    db.index_chunks(chunks, _chunk_set_metadata())

    assert {p.id for p in db.client.upserted} == {
        VectorDatabase.point_id(c.id) for c in chunks
    }


def test_index_chunks_returns_the_metadata_it_recorded():
    """
    The returned dict must be the one that was stored, not a second dict built
    to the same schema.

    `index_documents.py` used to rebuild the schema independently so it could
    compare the two, which made the comparison a check on two builders agreeing
    rather than on the write — and put a clock read of `indexed_at` on each side
    of an equality test, so it failed at random whenever the round trip crossed
    a second boundary. Reading the collection back and comparing against the
    return value is the check it was reaching for.

    The key set is pinned whole because Qdrant **merges**: a key written once
    survives an update that does not mention it, so a schema grown one key at a
    time leaves predecessors behind advertising values nothing produced. A test
    that only spot-checked a few keys would not notice one being added.
    """
    db = _make_db()
    chunks = _chunks("gdpr_article_1", "gdpr_article_2")

    returned = db.index_chunks(chunks, _chunk_set_metadata())

    assert returned == db.collection_metadata()
    assert set(returned) == {
        "chunk_set_sha256",
        "chunk_count",
        "snapshot",
        "source_sha256",
        "chunker_commit",
        "chunker_tree_dirty",
        "embedding_model",
        "vector_size",
        "indexed_at",
    }
    assert returned["chunk_count"] == len(chunks)
    # Read off the generator that ran, not off settings — so it records what was
    # used rather than what config claimed.
    assert returned["embedding_model"] == "fake-embedding-model"


def test_index_chunks_goes_through_embed_and_upsert_chunks():
    """
    Asserts on the *call*, not on the outcome. A re-implementation that wrote
    the same points by another route would satisfy the behavioural test above
    while leaving two write paths to keep in step.

    It also pins what is handed down. The digest reaches the primitive from
    `chunk_set_metadata`, unaltered: a version that re-derived it here — hashing
    the chunks on their way past — would write points advertising a set the
    snapshot never recorded, and every check downstream would agree with it,
    because they would all be comparing against the same locally invented value.
    The spy sees `_ANY_DIGEST`, which the chunks do not hash to, so that
    substitution cannot pass.
    """
    db = _make_db()
    chunks = _chunks("gdpr_article_1")
    chunk_set_metadata = _chunk_set_metadata()
    calls = []

    def _spy(chunks, chunk_set_id):
        calls.append((chunks, chunk_set_id))

    db.embed_and_upsert_chunks = _spy

    db.index_chunks(chunks, chunk_set_metadata)

    assert calls == [(chunks, chunk_set_metadata.chunk_set_id)]
    assert chunk_set_metadata.chunk_set_id != chunk_set_hash(chunks), (
        "the fixture must not collide, or a re-derivation here would pass"
    )


# --------------------------------------------------------------------------- #
#  stored_point_ids / find_orphans / delete_points                             #
#                                                                              #
#  The live collection held 563 points against a 368-chunk snapshot on         #
#  2026-08-07: 196 belonged to no current chunk and one current chunk          #
#  (gdpr_article_79) was absent. Orphans are not surplus — they hold real GDPR  #
#  text, they are embedded, and `search` returns them, so a retrieval metric    #
#  measured over them is measuring a corpus that exists nowhere else.          #
# --------------------------------------------------------------------------- #

def test_stored_point_ids_walks_every_page():
    """
    Pagination is the whole risk here: a scroll that stops after one page
    under-reports the collection, and every point it missed is an orphan that
    silently survives pruning.
    """
    db = _make_db()
    db.embed_and_upsert_chunks(
        _chunks(*[f"gdpr_article_{i}" for i in range(1200)]), _ANY_DIGEST
    )

    stored = db.stored_point_ids()

    assert len(stored) == 1200
    assert set(stored) == {str(VectorDatabase.point_id(f"gdpr_article_{i}"))
                           for i in range(1200)}


def test_stored_point_ids_maps_point_id_to_chunk_id():
    db = _make_db()
    db.embed_and_upsert_chunks(_chunks("gdpr_article_1", "gdpr_article_2"), _ANY_DIGEST)

    stored = db.stored_point_ids()

    assert stored[str(VectorDatabase.point_id("gdpr_article_1"))] == "gdpr_article_1"


def test_find_orphans_identifies_points_no_chunk_maps_onto():
    """The 2026-08-07 shape in miniature: some carried over, some orphaned."""
    db = _make_db()
    db.embed_and_upsert_chunks(
        _chunks("gdpr_article_79_para_1", "gdpr_article_79_para_2", "gdpr_article_5"),
        _ANY_DIGEST,
    )

    current = _chunks("gdpr_article_79", "gdpr_article_5")
    orphans = db.find_orphans(current)

    assert sorted(orphans.values()) == ["gdpr_article_79_para_1",
                                        "gdpr_article_79_para_2"]


def test_find_orphans_is_empty_when_collection_matches():
    db = _make_db()
    chunks = _chunks("gdpr_article_1", "gdpr_article_2")
    db.embed_and_upsert_chunks(chunks, _ANY_DIGEST)

    assert db.find_orphans(chunks) == {}


def test_find_orphans_flags_points_with_no_chunk_id_payload():
    """
    Membership is decided by derived point ID, not by the payload. A point
    whose payload is missing or corrupt must still be identifiable as an
    orphan — comparing on `chunk_id` would skip exactly the points least
    likely to be legitimate.
    """
    db = _make_db()
    db.client.points["deadbeef-0000-0000-0000-000000000000"] = {}

    orphans = db.find_orphans(_chunks("gdpr_article_1"))

    assert orphans == {"deadbeef-0000-0000-0000-000000000000": None}


def test_delete_points_removes_exactly_what_it_is_given():
    db = _make_db()
    db.embed_and_upsert_chunks(
        _chunks("gdpr_article_1", "gdpr_article_2", "gdpr_article_3"), _ANY_DIGEST
    )
    doomed = [str(VectorDatabase.point_id("gdpr_article_2"))]

    deleted = db.delete_points(doomed)

    assert deleted == 1
    assert set(db.stored_point_ids()) == {
        str(VectorDatabase.point_id("gdpr_article_1")),
        str(VectorDatabase.point_id("gdpr_article_3")),
    }


def test_delete_points_on_empty_list_does_not_call_the_server():
    """
    A delete with an empty selector is the kind of call that deletes everything
    if the server or client interprets it generously. Never issue it.

    Asserts on *calls*, not on outcome. An earlier version checked that nothing
    was deleted, which a mutation removing the guard passed trivially: the call
    went out with an empty selector and this fake, unlike an unknown server,
    happened to do nothing with it.
    """
    db = _make_db()
    db.embed_and_upsert_chunks(_chunks("gdpr_article_1"), _ANY_DIGEST)

    assert db.delete_points([]) == 0
    assert db.client.delete_calls == [], "no delete should be issued at all"
    assert len(db.stored_point_ids()) == 1


def test_pruning_orphans_makes_the_collection_match_the_chunk_set():
    """End to end: index a new chunk set over an old one, prune, and verify."""
    db = _make_db()
    db.embed_and_upsert_chunks(
        _chunks(*[f"old_chunk_{i}" for i in range(5)]), _ANY_DIGEST
    )
    current = _chunks(*[f"gdpr_article_{i}" for i in range(3)])
    db.embed_and_upsert_chunks(current, _ANY_DIGEST)

    db.delete_points(list(db.find_orphans(current)))

    assert db.find_orphans(current) == {}
    assert len(db.stored_point_ids()) == len(current)


# --------------------------------------------------------------------------- #
#  chunk_set_sha256 per point / find_stale                                     #
#                                                                              #
#  Point IDs derive from chunk IDs alone, so a chunk whose *text* changes keeps #
#  its point. ID comparison is structurally blind to that. The per-point digest #
#  is what is not — it is the only signal that survives a half-finished index.  #
# --------------------------------------------------------------------------- #

def _retext(chunks, suffix):
    """The same chunk IDs carrying different text — a text-only revision."""
    return [Chunk(id=c.id, text=c.text + suffix, metadata=c.metadata) for c in chunks]


def test_embed_and_upsert_chunks_stamps_every_point_with_the_chunk_set_digest():
    db = _make_db()
    chunks = _chunks("gdpr_article_1", "gdpr_article_2")

    digest = chunk_set_hash(chunks)

    db.embed_and_upsert_chunks(chunks, digest)

    assert all(p.payload["chunk_set_sha256"] == digest for p in db.client.upserted)


def test_embed_and_upsert_chunks_stamps_the_digest_it_is_given():
    """
    Supplied, never derived — the inverse of what this file asserted until
    2026-08-09, and the only test here that can tell the two apart.

    The digest a point must advertise is not "a hash of these chunks" but "the
    hash the snapshot on disk recorded", and only the caller can compare the
    two: `index_documents` takes it from the manifest that `read_snapshot` has
    already verified against these exact chunks (`test_chunk_store.py` covers
    that half). Re-deriving here would look equivalent and would silently drop
    the comparison.

    The digest passed is deliberately *not* `chunk_set_hash(chunks)`, so a
    version that re-derived internally stamps a different value and fails.
    Established by mutation on 2026-08-10: re-deriving inside the primitive
    left every other test in this file green.
    """
    db = _make_db()
    chunks = _chunks("gdpr_article_1")

    db.embed_and_upsert_chunks(chunks, _ANY_DIGEST)

    assert _ANY_DIGEST != chunk_set_hash(chunks), "the fixture must not collide"
    assert [p.payload["chunk_set_sha256"] for p in db.client.upserted] == [_ANY_DIGEST]


def test_find_stale_catches_a_text_only_revision_that_orphan_detection_cannot():
    """
    The citation fix in miniature: `Article 78.3:` -> `Article 78(3):` changes
    every paragraph chunk's text and none of their IDs. find_orphans correctly
    reports nothing while every stored vector is from the old text.
    """
    db = _make_db()
    old = _chunks("gdpr_article_78_para_3", "gdpr_article_78_para_4")
    db.embed_and_upsert_chunks(old, chunk_set_hash(old))
    new = _retext(old, " (revised citation form)")
    new_digest = chunk_set_hash(new)

    assert db.find_orphans(new) == {}, "ID comparison cannot see a text-only change"
    assert len(db.find_stale(new_digest)) == 2, "the digest can"


def test_find_stale_is_empty_after_a_complete_index():
    db = _make_db()
    chunks = _chunks("gdpr_article_1", "gdpr_article_2")

    digest = chunk_set_hash(chunks)

    db.embed_and_upsert_chunks(chunks, digest)

    assert db.find_stale(digest) == {}


def test_find_stale_localises_a_partial_index():
    """
    A run that dies midway leaves every ID matching and metadata unwritten, so
    the collection quietly advertises the previous chunk set while holding a mix
    of two. The points not rewritten are exactly those whose digest is not
    current — which is what makes the failure diagnosable rather than merely
    detectable.

    The crash is modelled inside a single `embed_and_upsert_chunks` call, which
    is where a
    real one happens: the digest is computed once from the full chunk list, so
    the batches that did land carry the *new* set's digest and the rest carry
    the old. Simulating it as a second call over a subset would be wrong — that
    stamps the subset's own hash, which is a different thing entirely.
    """
    old = _chunks(*[f"gdpr_article_{i}" for i in range(150)])
    new = _retext(old, " revised")
    new_digest = chunk_set_hash(new)

    db = _make_db()
    db.embed_and_upsert_chunks(old, chunk_set_hash(old))
    db.client.upsert_calls = 0       # count batches of the *second* index only
    db.client._fail_upsert_after = 1  # batch size is 100: write one, then die

    with pytest.raises(ConnectionError):
        db.embed_and_upsert_chunks(new, new_digest)

    stale = db.find_stale(new_digest)
    assert len(stale) == 50, "the 50 chunks in the unwritten batch"
    assert all(held == chunk_set_hash(old) for held in stale.values())
    assert db.find_orphans(new) == {}, "and the ID comparison still sees nothing"


# `test_indexing_a_subset_stamps_the_subset_not_the_full_set` was removed here
# on 2026-08-10. It asserted that a subset index advertises the subset, which
# was a property of `vector_db` only while the digest was derived from the
# chunks being written. Supplied by the caller, the two assertions that remain
# say `chunk_set_hash(chunks[:1]) != chunk_set_hash(chunks)` — a statement about
# the hash, already pinned by
# `test_chunk_store.test_chunk_set_hash_changes_when_a_chunk_is_added_or_removed`.
#
# Its warning did not survive the inversion either; it reversed. It read "a
# subset index can never make the collection carry the full set's digest,
# however many times it is repeated" — safe by construction. Now nothing here
# stops a caller stamping the full set's digest onto a subset, and
# `index_chunks` would follow through: every written point carries the digest,
# so `find_stale` is satisfied, and every chunk *not* in the subset is an orphan
# and gets deleted. The collection ends up holding one chunk and advertising
# three hundred. That guarantee now rests entirely on the caller taking chunks
# and digest from the same snapshot, which `index_documents.py` does.


def test_find_stale_treats_points_with_no_digest_as_stale():
    """
    Points indexed before this field existed carry nothing. Nothing is not a
    match — the live collection held 563 such points on 2026-08-07.
    """
    db = _make_db()
    db.client.points["deadbeef-0000-0000-0000-000000000000"] = {
        "chunk_id": "gdpr_article_1"
    }

    stale = db.find_stale("157d4d38")

    assert stale == {"deadbeef-0000-0000-0000-000000000000": None}


# --------------------------------------------------------------------------- #
#  Collection metadata                                                         #
# --------------------------------------------------------------------------- #

def test_collection_metadata_is_none_before_anything_stamps_it():
    """The live collection's state on 2026-08-07: 563 points, metadata None."""
    assert _make_db().collection_metadata() is None


def test_set_collection_metadata_round_trips():
    db = _make_db()
    db.set_collection_metadata({"chunk_set_sha256": "157d4d38", "chunk_count": 368})

    assert db.collection_metadata() == {
        "chunk_set_sha256": "157d4d38",
        "chunk_count": 368,
    }


def test_collection_metadata_merges_rather_than_replaces():
    """
    Qdrant merges, so a key written once persists until explicitly overwritten.
    This is why the metadata schema is decided up front in `index_documents`
    rather than grown a key at a time — a renamed key leaves its predecessor
    behind, still advertising a value nothing produced.
    """
    db = _make_db()
    db.set_collection_metadata({"chunk_set_sha256": "aaaa", "embedding_model": "small"})
    db.set_collection_metadata({"chunk_set_sha256": "bbbb"})

    recorded = db.collection_metadata()
    assert recorded["chunk_set_sha256"] == "bbbb"
    assert recorded["embedding_model"] == "small", (
        "a key absent from the update must survive it — that is the hazard"
    )


def test_embed_and_upsert_chunks_raises_when_points_are_lost():
    """
    A write the server accepts and does not persist — silent data loss.

    Modelled as a point that goes out and is not there afterwards, because that
    is the only failure this check can still see. It used to be driven by a
    collection count lower than the input, which no longer means anything: the
    check compares the *identities* it wrote against what the collection holds,
    so points left by an earlier corpus can no longer pad the total.

    The exception must **name the chunk**. Turning "the numbers disagree" into
    "this chunk did not land" is the whole gain of the identity check, and a
    test matching only on the exception type would pass just as well against a
    diagnostic that reported a count.
    """
    db = _make_db()
    chunks = _chunks("gdpr_article_1", "gdpr_article_2", "gdpr_article_3")
    db.client.drop_ids = {str(VectorDatabase.point_id("gdpr_article_2"))}

    with pytest.raises(IndexVerificationError, match="gdpr_article_2"):
        db.embed_and_upsert_chunks(chunks, _ANY_DIGEST)

    # The other two did land. A check that failed the whole batch whenever any
    # point went missing would satisfy the raise above while saying nothing
    # about which chunk to look at.
    assert set(db.stored_point_ids().values()) == {"gdpr_article_1", "gdpr_article_3"}


# --------------------------------------------------------------------------- #
#  index_chunks — orphan pruning                                               #
#                                                                              #
#  This used to be a warning inside `embed_and_upsert_chunks` that counted the #
#  surplus and left it in place. It is not that any more, in three ways: the   #
#  points are named rather than tallied, they are deleted rather than reported #
#  (pruning stopped being opt-in on 2026-08-09), and the delete is verified    #
#  rather than assumed. 196 points were destroyed on 2026-08-07 and the run    #
#  printed nothing about which — this log is now the only record that anything #
#  was removed at all.                                                         #
# --------------------------------------------------------------------------- #

def test_index_chunks_names_the_orphans_it_deletes(caplog):
    """
    Named, not merely counted.

    A count is enough to notice a loss and useless for investigating one: an
    operator who finds 196 points gone has no way to ask what they were, since
    by then the only record of them was the collection they were deleted from.
    """
    db = _make_db()
    db.embed_and_upsert_chunks(_chunks("old_chunk_1", "old_chunk_2"), _PRIOR_DIGEST)
    current = _chunks("gdpr_article_1")

    with caplog.at_level(logging.WARNING):
        db.index_chunks(current, _chunk_set_metadata())

    assert "belonging to no chunk" in caplog.text
    assert "old_chunk_1" in caplog.text
    assert "old_chunk_2" in caplog.text


def test_index_chunks_caps_the_orphan_list_it_prints(caplog):
    """
    Enough to recognise a pattern; not so many that the message drowns.

    The case this guards is exactly the one where the log matters most: a
    re-keying rebuild orphans the *entire* previous corpus, so an uncapped list
    would push the line saying what happened hundreds of rows off the screen.

    IDs are zero-padded because `old_chunk_1` is a substring of `old_chunk_10`,
    and a substring count over the log would otherwise report names that were
    never printed.
    """
    db = _make_db()
    old = _chunks(*[f"old_chunk_{i:02d}" for i in range(_ORPHAN_REPORT_LIMIT + 5)])
    db.embed_and_upsert_chunks(old, _PRIOR_DIGEST)
    current = _chunks("gdpr_article_1")

    with caplog.at_level(logging.WARNING):
        db.index_chunks(current, _chunk_set_metadata())

    named = [chunk.id for chunk in old if chunk.id in caplog.text]
    # Sorted by chunk ID, so which ten appear is deterministic rather than
    # whichever ten the collection happened to yield first.
    assert named == sorted(chunk.id for chunk in old)[:_ORPHAN_REPORT_LIMIT]
    assert "… and 5 more" in caplog.text


def test_index_chunks_deletes_the_orphans_it_names():
    """Named *and* removed — the log is a record of a deletion, not a proposal."""
    db = _make_db()
    db.embed_and_upsert_chunks(_chunks("old_chunk_1", "old_chunk_2"), _PRIOR_DIGEST)
    current = _chunks("gdpr_article_1", "gdpr_article_2")

    db.index_chunks(current, _chunk_set_metadata())

    assert db.find_orphans(current) == {}
    assert set(db.stored_point_ids().values()) == {chunk.id for chunk in current}


def test_index_chunks_records_nothing_when_orphans_survive_deletion():
    """
    The guarantee is not that the delete succeeds — it is that a collection
    never advertises a chunk set it does not hold.

    So what did *not* happen alongside the raise is the real assertion. A
    version that recorded the metadata and then raised would satisfy
    `pytest.raises` while leaving the collection claiming a chunk set it is
    still polluted with, which is the state nothing downstream could detect.

    The delete is modelled as accepted-and-not-performed rather than as an
    error, because an error already raises out on its own; the silent no-op is
    the case the re-check exists for.
    """
    db = _make_db()
    db.embed_and_upsert_chunks(_chunks("old_chunk_1"), _PRIOR_DIGEST)
    db.client.delete_is_a_noop = True
    current = _chunks("gdpr_article_1")

    with pytest.raises(IndexVerificationError, match="survived deletion"):
        db.index_chunks(current, _chunk_set_metadata())

    assert db.client.delete_calls, "the delete must have been attempted, not skipped"
    assert db.client.update_calls == 0
    assert db.collection_metadata() is None


# `test_embed_and_upsert_chunks_reports_the_stored_count_not_the_input_count`
# was removed here on 2026-08-10. It pinned the string "N points in collection",
# which the method no longer emits: the only line it logs now is the input count,
# announced before the work rather than offered afterwards as evidence it
# succeeded. That distinction is the whole of what the old test was defending,
# and it is no longer defended by a message at all — success is established by
# `raises_when_points_are_lost`'s check, which consults the collection and names
# the chunks that did not land. A message cannot be wrong about that because
# there is no longer a message making the claim.


def test_chunk_payload_carries_identity_and_metadata():
    db = _make_db()
    db.embed_and_upsert_chunks(_chunks("gdpr_article_7"), _ANY_DIGEST)
    payload = db.client.upserted[0].payload
    assert payload["chunk_id"] == "gdpr_article_7"
    assert payload["text"] == "text for gdpr_article_7"
    # A `dict`, not the model. Pydantic happens to convert a `ChunkMetadata` on
    # the REST transport, so the stored payload would look the same either way —
    # but `payload_to_grpc` rejects a BaseModel outright, so the model form works
    # only until someone sets `prefer_grpc`. Pinned as a type, not just read
    # through, or this passes equally against the form that breaks.
    assert isinstance(payload["metadata"], dict)
    assert payload["metadata"]["article_number"] == "gdpr_article_7"
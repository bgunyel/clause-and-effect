"""
Tests for VectorDatabase point-ID derivation and indexing invariants.

These cover the layer between chunking and Qdrant, which had no tests and two
latent hazards:

  * Point IDs were assigned positionally (`i*batch_size + j`, where `i` was
    already an offset rather than a batch counter). The arithmetic happened to
    stay collision-free, but nothing verified that, and positional IDs re-key
    the whole corpus whenever chunk composition changes.
  * Qdrant's upsert silently overwrites a repeated point ID, and index_chunks
    reported success using len(chunks) — the input — so a collision would have
    been invisible.

No live Qdrant or embedding API is used: __init__ is bypassed and the client
and embedding generator are replaced with fakes, so these run offline.
"""
import uuid

import pytest
from qdrant_client.models import PointStruct

from src.clause_and_effect.chunk_store import chunk_set_hash
from src.clause_and_effect.parsers import Chunk
from src.clause_and_effect.retrieval.vector_db import VectorDatabase


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
        is why `index_chunks` verifies against the collection and not its input;
      * `update_collection` **merges** metadata, so a key written once survives
        an update that does not mention it.
    """

    def __init__(self, reported_count=None, metadata=None, fail_upsert_after=None):
        self.upserted = []
        self.points = {}          # str(point_id) -> payload
        self.metadata = metadata  # None models a collection nothing has stamped
        self.deleted = []
        self.delete_calls = []
        self.upsert_calls = 0
        # Batch index at which upsert starts raising, to model a run that dies
        # partway. The batches already written stay written — which is the whole
        # point: a crash leaves the collection holding two chunk sets at once.
        self._fail_upsert_after = fail_upsert_after
        self._reported_count = reported_count

    # --- points ----------------------------------------------------------- #

    def upsert(self, collection_name, points):
        if (self._fail_upsert_after is not None
                and self.upsert_calls >= self._fail_upsert_after):
            raise ConnectionError("connection lost mid-index")
        self.upsert_calls += 1
        self.upserted.extend(points)
        for point in points:
            self.points[str(point.id)] = point.payload

    def count(self, collection_name, exact=True):
        if self._reported_count is not None:
            return _FakeCount(self._reported_count)
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
        for point_id in points_selector.points:
            self.points.pop(str(point_id), None)
            self.deleted.append(str(point_id))

    # --- collection ------------------------------------------------------- #

    def collection_exists(self, collection_name):
        return True

    def get_collection(self, collection_name):
        return _FakeCollection(self.metadata)

    def update_collection(self, collection_name, metadata=None, **kwargs):
        if metadata is not None:
            self.metadata = {**(self.metadata or {}), **metadata}


class _FakeEmbeddings:
    def embed_batch(self, batch):
        return [[0.1, 0.2, 0.3] for _ in batch]


def _make_db(reported_count=None):
    """Build a VectorDatabase without touching Qdrant or OpenAI."""
    db = VectorDatabase.__new__(VectorDatabase)
    db.collection_name = "test_collection"
    db.client = _FakeClient(reported_count)
    db.embedding_generator = _FakeEmbeddings()
    return db


def _chunks(*ids):
    return [Chunk(id=i, text=f"text for {i}", metadata={"article_number": i}) for i in ids]


# --------------------------------------------------------------------------- #
#  index_chunks                                                                #
# --------------------------------------------------------------------------- #

def test_index_chunks_keys_points_by_chunk_id():
    db = _make_db()
    chunks = _chunks("gdpr_article_1", "gdpr_article_2", "gdpr_article_3")
    db.index_chunks(chunks)

    assert [p.id for p in db.client.upserted] == [
        VectorDatabase.point_id(c.id) for c in chunks
    ]


def test_index_chunks_is_idempotent():
    """Re-indexing the same corpus must update points, not duplicate them."""
    db = _make_db()
    chunks = _chunks("gdpr_article_1", "gdpr_article_2")
    db.index_chunks(chunks)
    first = {p.id for p in db.client.upserted}
    db.index_chunks(chunks)
    assert {p.id for p in db.client.upserted} == first


def test_index_chunks_spans_multiple_batches():
    """IDs must stay unique across batch boundaries (batch_size is 100)."""
    db = _make_db()
    chunks = _chunks(*[f"gdpr_article_{i}" for i in range(250)])
    db.index_chunks(chunks)
    assert len(db.client.upserted) == 250
    assert len({p.id for p in db.client.upserted}) == 250


def test_index_chunks_rejects_duplicate_chunk_ids():
    db = _make_db()
    chunks = _chunks("gdpr_article_1", "gdpr_article_2", "gdpr_article_1")
    with pytest.raises(ValueError, match="unique"):
        db.index_chunks(chunks)
    assert db.client.upserted == [], "nothing should be written when input is invalid"


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
    db.index_chunks(_chunks(*[f"gdpr_article_{i}" for i in range(1200)]))

    stored = db.stored_point_ids()

    assert len(stored) == 1200
    assert set(stored) == {str(VectorDatabase.point_id(f"gdpr_article_{i}"))
                           for i in range(1200)}


def test_stored_point_ids_maps_point_id_to_chunk_id():
    db = _make_db()
    db.index_chunks(_chunks("gdpr_article_1", "gdpr_article_2"))

    stored = db.stored_point_ids()

    assert stored[str(VectorDatabase.point_id("gdpr_article_1"))] == "gdpr_article_1"


def test_find_orphans_identifies_points_no_chunk_maps_onto():
    """The 2026-08-07 shape in miniature: some carried over, some orphaned."""
    db = _make_db()
    db.index_chunks(_chunks("gdpr_article_79_para_1", "gdpr_article_79_para_2",
                            "gdpr_article_5"))

    current = _chunks("gdpr_article_79", "gdpr_article_5")
    orphans = db.find_orphans(current)

    assert sorted(orphans.values()) == ["gdpr_article_79_para_1",
                                        "gdpr_article_79_para_2"]


def test_find_orphans_is_empty_when_collection_matches():
    db = _make_db()
    chunks = _chunks("gdpr_article_1", "gdpr_article_2")
    db.index_chunks(chunks)

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
    db.index_chunks(_chunks("gdpr_article_1", "gdpr_article_2", "gdpr_article_3"))
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
    db.index_chunks(_chunks("gdpr_article_1"))

    assert db.delete_points([]) == 0
    assert db.client.delete_calls == [], "no delete should be issued at all"
    assert len(db.stored_point_ids()) == 1


def test_pruning_orphans_makes_the_collection_match_the_chunk_set():
    """End to end: index a new chunk set over an old one, prune, and verify."""
    db = _make_db()
    db.index_chunks(_chunks(*[f"old_chunk_{i}" for i in range(5)]))
    current = _chunks(*[f"gdpr_article_{i}" for i in range(3)])
    db.index_chunks(current)

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


def test_index_chunks_stamps_every_point_with_the_chunk_set_digest():
    db = _make_db()
    chunks = _chunks("gdpr_article_1", "gdpr_article_2")

    digest = db.index_chunks(chunks)

    assert digest == chunk_set_hash(chunks)
    assert all(p.payload["chunk_set_sha256"] == digest for p in db.client.upserted)


def test_index_chunks_derives_the_digest_from_what_it_writes():
    """
    Derived, never passed in. A caller-supplied hash is one more thing that can
    be wrong, and a point advertising a chunk set it is not part of is exactly
    the failure this field exists to prevent.
    """
    db = _make_db()
    first = db.index_chunks(_chunks("gdpr_article_1"))
    second = db.index_chunks(_retext(_chunks("gdpr_article_1"), " revised"))

    assert first != second


def test_find_stale_catches_a_text_only_revision_that_orphan_detection_cannot():
    """
    The citation fix in miniature: `Article 78.3:` -> `Article 78(3):` changes
    every paragraph chunk's text and none of their IDs. find_orphans correctly
    reports nothing while every stored vector is from the old text.
    """
    db = _make_db()
    old = _chunks("gdpr_article_78_para_3", "gdpr_article_78_para_4")
    db.index_chunks(old)
    new = _retext(old, " (revised citation form)")
    new_digest = chunk_set_hash(new)

    assert db.find_orphans(new) == {}, "ID comparison cannot see a text-only change"
    assert len(db.find_stale(new_digest)) == 2, "the digest can"


def test_find_stale_is_empty_after_a_complete_index():
    db = _make_db()
    chunks = _chunks("gdpr_article_1", "gdpr_article_2")

    digest = db.index_chunks(chunks)

    assert db.find_stale(digest) == {}


def test_find_stale_localises_a_partial_index():
    """
    A run that dies midway leaves every ID matching and metadata unwritten, so
    the collection quietly advertises the previous chunk set while holding a mix
    of two. The points not rewritten are exactly those whose digest is not
    current — which is what makes the failure diagnosable rather than merely
    detectable.

    The crash is modelled inside a single `index_chunks` call, which is where a
    real one happens: the digest is computed once from the full chunk list, so
    the batches that did land carry the *new* set's digest and the rest carry
    the old. Simulating it as a second call over a subset would be wrong — that
    stamps the subset's own hash, which is a different thing entirely.
    """
    old = _chunks(*[f"gdpr_article_{i}" for i in range(150)])
    new = _retext(old, " revised")
    new_digest = chunk_set_hash(new)

    db = _make_db()
    db.index_chunks(old)
    db.client.upsert_calls = 0       # count batches of the *second* index only
    db.client._fail_upsert_after = 1  # batch size is 100: write one, then die

    with pytest.raises(ConnectionError):
        db.index_chunks(new)

    stale = db.find_stale(new_digest)
    assert len(stale) == 50, "the 50 chunks in the unwritten batch"
    assert all(held == chunk_set_hash(old) for held in stale.values())
    assert db.find_orphans(new) == {}, "and the ID comparison still sees nothing"


def test_indexing_a_subset_stamps_the_subset_not_the_full_set():
    """
    The digest describes the set that was written, so indexing part of a corpus
    advertises that part. Correct, and a trap: a subset index can never make the
    collection carry the full set's digest, however many times it is repeated.
    """
    db = _make_db()
    chunks = _chunks("gdpr_article_1", "gdpr_article_2")

    subset_digest = db.index_chunks(chunks[:1])

    assert subset_digest == chunk_set_hash(chunks[:1])
    assert subset_digest != chunk_set_hash(chunks)


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


def test_index_chunks_raises_when_points_are_lost():
    """A collection holding fewer points than chunks means silent data loss."""
    db = _make_db(reported_count=2)
    with pytest.raises(ValueError, match="lost to ID collisions"):
        db.index_chunks(_chunks("a", "b", "c"))


def test_index_chunks_warns_about_points_belonging_to_no_chunk(capsys):
    """
    Extra points survive from a previous, larger corpus — warn, don't fail.
    `index_chunks` counts them but cannot name them; identifying and removing
    them is `find_orphans` / `delete_points`, and the warning now says so
    rather than offering "drop the collection" as the only remedy.
    """
    db = _make_db(reported_count=10)
    db.index_chunks(_chunks("a", "b", "c"))
    out = capsys.readouterr().out
    assert "belong to no chunk" in out
    assert "7" in out
    assert "find_orphans" in out


def test_index_chunks_reports_the_stored_count_not_the_input_count(capsys):
    db = _make_db()
    db.index_chunks(_chunks("a", "b", "c"))
    assert "3 points in collection" in capsys.readouterr().out


def test_chunk_payload_carries_identity_and_metadata():
    db = _make_db()
    db.index_chunks(_chunks("gdpr_article_7"))
    payload = db.client.upserted[0].payload
    assert payload["chunk_id"] == "gdpr_article_7"
    assert payload["text"] == "text for gdpr_article_7"
    assert payload["metadata"]["article_number"] == "gdpr_article_7"
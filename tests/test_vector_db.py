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


class _FakeClient:
    """Records upserts and reports a configurable point count."""

    def __init__(self, reported_count=None):
        self.upserted = []
        self._reported_count = reported_count

    def upsert(self, collection_name, points):
        self.upserted.extend(points)

    def count(self, collection_name, exact=True):
        if self._reported_count is not None:
            return _FakeCount(self._reported_count)
        # Model Qdrant's real behaviour: repeated IDs collapse onto one point.
        return _FakeCount(len({p.id for p in self.upserted}))


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


def test_index_chunks_raises_when_points_are_lost():
    """A collection holding fewer points than chunks means silent data loss."""
    db = _make_db(reported_count=2)
    with pytest.raises(ValueError, match="lost to ID collisions"):
        db.index_chunks(_chunks("a", "b", "c"))


def test_index_chunks_warns_about_orphaned_points(capsys):
    """Extra points survive from a previous, larger corpus — warn, don't fail."""
    db = _make_db(reported_count=10)
    db.index_chunks(_chunks("a", "b", "c"))
    out = capsys.readouterr().out
    assert "orphaned" in out
    assert "7" in out


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
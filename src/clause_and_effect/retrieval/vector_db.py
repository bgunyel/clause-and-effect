"""
Vector database operations using Qdrant
"""
import logging
import uuid
from datetime import datetime, timezone
from typing import List, Dict, Any, Optional
from pydantic import BaseModel, Field, SecretStr
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct, PointIdsList
from tqdm import tqdm

from src.clause_and_effect.chunking import Chunk, ChunkSetMetadata
from src.clause_and_effect.retrieval import EmbeddingGenerator

logger = logging.getLogger(__name__)

# Page size for walking the collection. Only the provenance fields are fetched —
# no vectors, no text — so this stays cheap regardless of corpus size.
_SCROLL_PAGE_SIZE = 512

# The payload fields that say which chunk set a point belongs to. Fetched when
# walking the collection; everything else stays on the server.
_PROVENANCE_FIELDS = ["chunk_id", "chunk_set_sha256"]

# How many offending points a diagnostic names before summarising the rest.
# Enough to recognise a pattern; not so many that a whole-corpus mismatch
# buries the message that produced it.
_ORPHAN_REPORT_LIMIT = 10


class IndexVerificationError(RuntimeError):
    """
    An index run did not reach the state it promised, and recorded nothing.

    `RuntimeError` rather than `ValueError` because nothing is wrong with the
    caller's arguments: the chunks were valid, the digest was valid, and the
    operation simply did not end with the collection holding what it was asked
    to hold. `ValueError` stays for the one fault that *is* an argument fault —
    duplicate chunk IDs, which are wrong before anything is attempted.

    Named rather than bare so `index_documents.py` can tell "this index failed
    its own post-condition" apart from a bug, and exit non-zero with the message
    instead of a traceback. Every raise of this type happens **before** metadata
    is written, so a collection is never left advertising a chunk set it does
    not hold.
    """




class VectorDatabase:
    """Qdrant vector database wrapper"""

    # Namespace for deriving point IDs from chunk IDs. Qdrant accepts only
    # unsigned integers or UUIDs as point IDs, so a semantic key such as
    # 'gdpr_article_5_para_1' cannot be used directly — uuid5 hashes it into a
    # valid UUID deterministically.
    #
    # This is a domain separator, not a credential: uuid5 is an unkeyed SHA-1,
    # and the chunk_id it hashes is stored in the payload in plaintext anyway.
    # It belongs in source precisely because it must be byte-identical across
    # every environment forever — a namespace that differs between environments
    # silently re-keys the corpus, so a re-index writes a parallel set of points
    # instead of updating them in place. Never change this value.
    POINT_ID_NAMESPACE = uuid.UUID("b1f3a4c2-7d58-4e26-9a0f-3c8d5e1b7a94")

    def __init__(self,
                 vector_db_url: SecretStr,
                 vector_db_port: int,
                 vector_db_api_key: SecretStr,
                 collection_name: str,
                 embedding_model: str,
                 embedding_model_api_key: SecretStr):
        self.collection_name = collection_name
        self.client = QdrantClient(
            api_key=vector_db_api_key.get_secret_value(),
            url=vector_db_url.get_secret_value(),
            port=vector_db_port,
        )
        self.embedding_generator = EmbeddingGenerator(
            model=embedding_model,
            api_key=embedding_model_api_key,
        )

    def create_collection(self, vector_size: int = 1536):
        """Create collection if it doesn't exist"""

        if self.client.collection_exists(self.collection_name):
            logger.info("✅ Collection '%s' already exists", self.collection_name)
        else:
            # Create new collection
            self.client.create_collection(
                collection_name=self.collection_name,
                vectors_config=VectorParams(
                    size=vector_size,
                    distance=Distance.COSINE
                )
            )
            logger.info("✅ Created collection '%s'", self.collection_name)


    @classmethod
    def point_id(cls, chunk_id: str) -> uuid.UUID:
        """
        Map a chunk's semantic ID onto a stable Qdrant point ID.

        Keying points by content identity rather than by position makes
        re-indexing idempotent: the same chunk lands on the same point every
        run, so a corrected corpus updates in place. Positional IDs shift
        whenever the corpus changes, which leaves the collection holding a mix
        of old and new content unless it is dropped first.
        """
        return uuid.uuid5(cls.POINT_ID_NAMESPACE, chunk_id)

    def index_chunks(
            self,
            chunks: List[Chunk],
            chunk_set_metadata: ChunkSetMetadata
    ) -> Dict[str, Any]:
        """
        Make the collection hold exactly ``chunks``, and record what it was
        built from.

        The reconcile step in front of `embed_and_upsert_chunks`: that primitive
        touches only the points its chunks map onto, while what the collection
        holds *besides* them is decided here — create the collection, write,
        prune what no chunk maps onto, verify the post-conditions, record the
        metadata.

        Two orderings are load-bearing. Upsert runs before delete, so a run that
        dies partway leaves a superset rather than a deficit. `find_stale` runs
        before the metadata write, so nothing can advertise a snapshot it only
        partly holds.

        **The returned dict is the metadata that was written**, so a caller can
        read the collection back and compare against what was actually sent.
        `index_documents.py` used to rebuild the same schema independently for
        that comparison, which made it a check on two builders agreeing rather
        than on the write — and put two clock reads of `indexed_at` on either
        side of an equality test, so it failed at random whenever the round trip
        crossed a second boundary.

        The schema is decided in full here rather than grown key by key: Qdrant
        **merges** collection metadata, so a key written once persists until
        explicitly overwritten. A schema that accretes leaves stale keys behind
        advertising values nothing produced, and a renamed key leaves its
        predecessor in place.

        `embedding_model` and `vector_size` are recorded because the chunk hash
        does not cover them. Identical chunks embedded through different models
        give different vectors and different retrieval, while both collections
        would honestly report the same `chunk_set_sha256` — so the hash alone
        cannot answer "does this index match?" and these two close that gap.
        `embedding_model` is read off the generator that ran rather than from
        settings, so it records what was used and not what config claimed.

        Args:
            chunks: the chunk set the collection must end up holding.
            chunk_set_metadata: provenance of that chunk set — its digest, the
                snapshot it came from, the corpus hash, and the chunker's commit
                and tree state.

        Returns:
            The collection metadata as written.
        """

        self.create_collection()

        chunk_set_id = chunk_set_metadata.chunk_set_id

        self.embed_and_upsert_chunks(chunks=chunks, chunk_set_id=chunk_set_id)

        orphans = self.find_orphans(chunks)
        if orphans:
            # Named before they are removed, not counted after. Pruning is not
            # optional (Bertan, 2026-08-09), so the operator no longer opts in
            # by typing `--prune` and this log is the only record that anything
            # was destroyed. 196 points were deleted on 2026-08-07 and the run
            # printed nothing about which.
            listed = "\n".join(
                f"    {chunk_id or '<no chunk_id in payload>'}  ({point_id})"
                for point_id, chunk_id in sorted(
                    orphans.items(), key=lambda kv: str(kv[1])
                )[:_ORPHAN_REPORT_LIMIT]
            )
            if len(orphans) > _ORPHAN_REPORT_LIMIT:
                listed += f"\n    … and {len(orphans) - _ORPHAN_REPORT_LIMIT} more"
            logger.warning(
                "🗑  Deleting %d point(s) belonging to no chunk in this set:\n%s",
                len(orphans), listed,
            )

            self.delete_points(list(orphans))

            # Re-check rather than trust the delete: this is the destructive
            # step, and a partial delete would otherwise be recorded as a clean
            # index. The server does not say what it removed — Qdrant's
            # `UpdateResult` carries only an operation id and a status — so
            # looking again is the only way to know.
            #
            # Checked once, not retried. This was a `while` loop, which could
            # not help and could not stop: the second attempt sends the same
            # point IDs to the same collection, so a delete that did not take
            # effect the first time will not the second, and the run would spin
            # against the server without limit or output. A delete that *errors*
            # raises out of here already; a delete that silently no-ops, or a
            # concurrent writer producing orphans faster than they are removed,
            # is a condition to report rather than to grind against.
            survivors = self.find_orphans(chunks)
            if survivors:
                raise IndexVerificationError(
                    f"{len(survivors)} orphan(s) survived deletion from "
                    f"'{self.collection_name}'; nothing recorded. "
                    f"Point IDs: {sorted(survivors)[:10]}"
                )

        # The post-condition that count verification cannot give. Every live point
        # must carry the digest about to be advertised — including points that kept
        # their ID through the change, which is where a silently failed upsert or a
        # half-finished run would otherwise hide.
        stale = self.find_stale(chunk_set_sha256=chunk_set_id)

        if stale:
            raise IndexVerificationError(
                f"{len(stale)} point(s) do not carry {chunk_set_id[:12]}… after "
                f"indexing; nothing recorded."
            )

        vector_size = self.client.get_collection(
            self.collection_name
        ).config.params.vectors.size

        collection_metadata = {
            "chunk_set_sha256": chunk_set_metadata.chunk_set_id,
            "chunk_count": len(chunks),
            "snapshot": chunk_set_metadata.snapshot,
            "source_sha256": chunk_set_metadata.source_sha256,
            "chunker_commit": chunk_set_metadata.chunker_commit,
            "chunker_tree_dirty": chunk_set_metadata.chunker_tree_dirty,
            "embedding_model": self.embedding_generator.get_model(),
            "vector_size": vector_size,
            "indexed_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        }
        self.set_collection_metadata(metadata=collection_metadata)

        return collection_metadata

    def embed_and_upsert_chunks(self, chunks: List[Chunk], chunk_set_id: str) -> None:
        """
        Embed chunks and write them to the collection, stamping each point with
        the chunk set it belongs to.

        The write primitive: it touches only the points these chunks map onto
        and decides nothing about the ones it does not. What the collection
        holds *besides* them is `index_chunks`'s question.

        **The digest is supplied, not derived here.** An earlier version hashed
        the chunks it was writing, on the grounds that a caller-supplied hash is
        one more thing that can be wrong. What that argument missed is that the
        digest a point must advertise is not "a hash of these chunks" but
        "the hash the snapshot on disk recorded" — and only the caller can
        compare the two. `index_documents.py` derives it with
        `chunk_set_hash(chunks)` and refuses to index at all if it disagrees
        with `snapshot.chunk_set_sha256`, which is a stronger check than
        re-deriving it here would be: it catches a snapshot whose file no longer
        matches the chunk set in memory, which a second local hash cannot see.

        The consequence is that the invariant *a point never advertises a chunk
        set it is not part of* now lives with the caller rather than here. This
        method takes the digest on trust and writes it verbatim.

        Args:
            chunks: the chunks to embed and write.
            chunk_set_id: the `chunk_set_sha256` stamped into every point's
                payload, and the field `find_stale` later reads to decide which
                points were not rewritten.

        Raises:
            ValueError: if two chunks share an ID — an argument fault, caught
                before anything is written.
            IndexVerificationError: if any chunk did not reach the collection
                carrying ``chunk_set_id``.

        Note:
            The post-write check is scoped to the points this call stamped and
            compares them by identity. A bare collection count would be masked
            by points left from an earlier corpus — 10 stale points plus 13 of
            15 written is 23, which passes ``23 >= 15`` while two chunks are
            missing. Verifying the expected point IDs are present *with this
            digest* is immune to that, and names which chunks are absent rather
            than reporting that two numbers disagree.

            It is, in exchange, blind to an ID **collision**, which the count
            check could see: if two chunk IDs derived the same point, the upsert
            overwrites and one chunk is lost, yet both find their point present
            and neither is reported missing. Nothing here can detect that,
            because it asks the collection the same question that produced the
            collision. The claim is carried where it can be made instead —
            duplicate chunk IDs are rejected above, and
            `test_distinct_chunk_ids_yield_distinct_point_ids` pins that
            distinct IDs derive distinct points.
        """
        logger.info("📊 Embedding and upserting %d chunks…", len(chunks))

        # Duplicate chunk IDs collapse onto one point: Qdrant's upsert
        # overwrites a repeated ID silently, so the loss would otherwise show
        # up only as a quietly under-populated collection.
        chunk_ids = [chunk.id for chunk in chunks]
        if len(set(chunk_ids)) != len(chunk_ids):
            seen, duplicates = set(), []
            for chunk_id in chunk_ids:
                if chunk_id in seen:
                    duplicates.append(chunk_id)
                seen.add(chunk_id)
            raise ValueError(
                f"Chunk IDs must be unique; {len(duplicates)} duplicate(s): "
                f"{sorted(set(duplicates))[:10]}"
            )



        batch_size = 100

        for i in tqdm(range(0, len(chunks), batch_size)):
            chunks_batch = chunks[i:i + batch_size]
            texts_batch = [c.text for c in chunks_batch]
            batch_embeddings = self.embedding_generator.embed_batch(batch=texts_batch)

            points = [
                PointStruct(
                    id = self.point_id(chunk.id),
                    vector = embedding,
                    # `.model_dump()` rather than the model itself. Pydantic
                    # happens to convert it when serializing the REST request,
                    # so the stored payload is identical either way — but that
                    # is incidental, and `payload_to_grpc` rejects a BaseModel
                    # outright, so the model form works only for as long as
                    # nobody sets `prefer_grpc`. Dumping here also matches
                    # `chunk_store._row`, which converts explicitly so that the
                    # archive and its hash cannot disagree.
                    payload = {
                        "chunk_id": chunk.id,
                        "text": chunk.text,
                        "metadata": chunk.metadata.model_dump(),
                        "chunk_set_sha256": chunk_set_id,
                        }
                    ) for chunk, embedding in zip(chunks_batch, batch_embeddings)
            ]

            self.client.upsert(collection_name=self.collection_name, points=points)

        # Verify against the collection rather than against the input: reporting
        # len(chunks) back would claim success without ever asking the server
        # whether the write landed.
        #
        # Scoped to the points this call stamped, not the collection's total. A
        # bare `count()` compares against everything the collection holds, so
        # points left by an earlier corpus mask a loss: 10 old points plus 13 of
        # 15 written is 23, and `23 >= 15` passes while two chunks are missing.
        #
        # Checked by identity rather than by count, because the point IDs are
        # known here — which turns "the numbers disagree" into "these chunks did
        # not land", and is immune to an unrelated point happening to make the
        # totals add up.
        landed = {
            point_id
            for point_id, payload in self.stored_points().items()
            if payload.get("chunk_set_sha256") == chunk_set_id
        }
        missing = {
            chunk.id: str(self.point_id(chunk.id))
            for chunk in chunks
            if str(self.point_id(chunk.id)) not in landed
        }
        if missing:
            raise IndexVerificationError(
                f"Indexed {len(chunks)} chunks but {len(missing)} did not reach "
                f"collection '{self.collection_name}' carrying "
                f"{chunk_set_id[:12]}… — lost to a failed upsert: "
                f"{sorted(missing)[:10]}"
            )


    def stored_points(self) -> Dict[str, Dict[str, Any]]:
        """
        Every point in the collection, as ``{point_id: {chunk_id, chunk_set_sha256}}``.

        Only the provenance fields are fetched — no vectors and no text — so
        this is cheap enough to run on every index, which is what makes
        "does this collection hold exactly this chunk set?" a checkable
        question rather than a remembered one.
        """
        stored: Dict[str, Dict[str, Any]] = {}
        offset = None
        while True:
            points, offset = self.client.scroll(
                collection_name=self.collection_name,
                limit=_SCROLL_PAGE_SIZE,
                offset=offset,
                with_payload=_PROVENANCE_FIELDS,
                with_vectors=False,
            )
            for point in points:
                payload = point.payload or {}
                stored[str(point.id)] = {
                    field: payload.get(field) for field in _PROVENANCE_FIELDS
                }
            # `offset is None` is the documented end of the scroll. The empty
            # page check is a belt-and-braces guard: a server that returned a
            # non-null offset forever would otherwise loop without end.
            if offset is None or not points:
                return stored

    def stored_point_ids(self) -> Dict[str, Optional[str]]:
        """Every point in the collection, as ``{point_id: payload chunk_id}``."""
        return {
            point_id: payload.get("chunk_id")
            for point_id, payload in self.stored_points().items()
        }

    def find_stale(self, chunk_set_sha256: str) -> Dict[str, Optional[str]]:
        """
        Points not carrying ``chunk_set_sha256``, as ``{point_id: its digest}``.

        This is the check an ID comparison cannot make. Point IDs derive from
        chunk IDs alone, so a chunk whose text changes keeps its point — and
        `find_orphans` correctly reports nothing while the stored vector is
        still embedded from the old text. Changing the paragraph citation form
        from ``Article 78.3:`` to ``Article 78(3):`` is exactly that shape: a
        new chunk-set digest, identical IDs, zero orphans, 330 stale vectors.

        It also localises a **partial** index. If a run dies midway, every ID
        still matches and metadata was never written, so the collection quietly
        advertises the previous chunk set while holding a mix of two. The points
        that were not rewritten are precisely those whose digest is not current.

        Points with no digest at all — indexed before this field existed —
        report ``None`` and count as stale, which is correct: nothing says what
        they belong to.
        """
        return {
            point_id: payload.get("chunk_set_sha256")
            for point_id, payload in self.stored_points().items()
            if payload.get("chunk_set_sha256") != chunk_set_sha256
        }

    def find_orphans(self, chunks: List[Chunk]) -> Dict[str, Optional[str]]:
        """
        Points in the collection that no chunk in ``chunks`` maps onto.

        These are not a cosmetic surplus. They hold real regulation text, they
        are embedded, and they are returned by `search` — so a retrieval metric
        measured against a collection with orphans is measuring a corpus that
        exists nowhere else. 196 of them survived the 2026-08-06 corpus rebuild.

        Compared by derived point ID rather than by `chunk_id` payload, so a
        point whose payload is missing or corrupt still counts as an orphan
        instead of being silently skipped.
        """
        expected = {str(self.point_id(chunk.id)) for chunk in chunks}
        return {
            point_id: chunk_id
            for point_id, chunk_id in self.stored_point_ids().items()
            if point_id not in expected
        }

    def delete_points(self, point_ids: List[str]) -> int:
        """
        Delete points by ID, returning how many were **requested**.

        Destructive and deliberately dumb: it deletes exactly what it is given
        and decides nothing. Callers choose what to delete, which keeps the
        judgement in the script the operator invoked.

        The return value is `len(point_ids)` and nothing more. It cannot be a
        count of what was removed, because Qdrant does not report one — an
        `UpdateResult` carries an operation id and a status, no tally — so this
        number says what was asked for, never what happened. It used to be
        documented as "how many were removed", which made it look like a
        progress signal a caller could act on; `index_chunks` had a retry loop
        built on that reading. Verifying a delete means looking at the
        collection again, which is what `find_orphans` is for.
        """
        if not point_ids:
            return 0
        self.client.delete(
            collection_name=self.collection_name,
            points_selector=PointIdsList(points=list(point_ids)),
            wait=True,
        )
        return len(point_ids)

    def set_collection_metadata(self, metadata: Dict[str, Any]) -> None:
        """
        Record what this collection was built from, on the collection itself.

        Must be called on **every** index run, not at creation:
        `create_collection` no-ops when the collection already exists, so
        metadata passed there would only ever be written once — on the run that
        happened to create it.

        Note that Qdrant **merges** rather than replaces: a key written once
        survives an update that does not mention it. So the schema has to be
        decided up front rather than allowed to accrete, and a renamed key
        leaves its predecessor behind advertising a stale value.
        """
        self.client.update_collection(
            collection_name=self.collection_name, metadata=metadata
        )

    def collection_metadata(self) -> Optional[Dict[str, Any]]:
        """What this collection says it was built from, or None if it says nothing."""
        if not self.client.collection_exists(self.collection_name):
            return None
        return getattr(self.client.get_collection(self.collection_name).config,
                       "metadata", None)

    def search(self, query: str, top_k: int = 5) -> List[Dict[str, Any]]:
        """
        Search for similar chunks

        Args:
            query: Query text
            top_k: Number of results to return

        Returns:
            List of search results with scores
        """
        # Generate query embedding
        query_embedding = self.embedding_generator.embed_text(query)

        search_result = self.client.query_points(
            collection_name = self.collection_name,
            query = query_embedding,
            query_filter = None,
            limit = top_k,
        ).points

        formatted_results = [
            {
                "chunk_id": result.payload["chunk_id"],
                "text": result.payload["text"],
                "metadata": result.payload["metadata"],
                "score": result.score
                }
            for result in search_result
        ]

        return formatted_results

    def get_collection_info(self) -> Dict[str, Any]:
        """Get information about the collection"""

        if self.client.collection_exists(self.collection_name):
            collection = self.client.get_collection(self.collection_name)
            info = {
                "name": self.collection_name,
                "vectors_count": collection.indexed_vectors_count,
                "points_count": collection.points_count,
                "status": collection.status
            }
        else:
            info = {"error": "Collection not found"}

        return info

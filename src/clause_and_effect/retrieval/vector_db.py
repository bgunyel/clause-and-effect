"""
Vector database operations using Qdrant
"""
import uuid
from typing import List, Dict, Any, Optional
from pydantic import SecretStr
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct, PointIdsList
from tqdm import tqdm

from src.clause_and_effect.parsers import Chunk
from src.clause_and_effect.retrieval import EmbeddingGenerator

# Page size for walking the collection. Only point IDs and `chunk_id` are
# fetched, so this stays cheap regardless of corpus size.
_SCROLL_PAGE_SIZE = 512


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
        self.embedding_generator = EmbeddingGenerator(model=embedding_model, api_key=embedding_model_api_key)

    def create_collection(self, vector_size: int = 1536):
        """Create collection if it doesn't exist"""

        if self.client.collection_exists(self.collection_name):
            print(f"✅ Collection '{self.collection_name}' already exists")
        else:
            # Create new collection
            self.client.create_collection(
                collection_name=self.collection_name,
                vectors_config=VectorParams(
                    size=vector_size,
                    distance=Distance.COSINE
                )
            )
            print(f"✅ Created collection '{self.collection_name}'")


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

    def index_chunks(self, chunks: List[Chunk]):
        """
        Index chunks into vector database

        Args:
            chunks: List of Chunk objects to index

        Raises:
            ValueError: if two chunks share an ID, or if the collection does
                not hold every chunk once indexing completes.
        """
        print(f"📊 Indexing {len(chunks)} chunks...")

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
                    payload = {
                        "chunk_id": chunk.id,
                        "text": chunk.text,
                        "metadata": chunk.metadata,
                        }
                    ) for chunk, embedding in zip(chunks_batch, batch_embeddings)
            ]

            self.client.upsert(collection_name=self.collection_name, points=points)

        # Verify against the collection rather than against the input: reporting
        # len(chunks) back would claim success even if every point had collided.
        stored = self.client.count(collection_name=self.collection_name, exact=True).count
        if stored < len(chunks):
            raise ValueError(
                f"Indexed {len(chunks)} chunks but collection "
                f"'{self.collection_name}' holds {stored} points — "
                f"{len(chunks) - stored} were lost to ID collisions."
            )
        if stored > len(chunks):
            print(
                f"⚠️  Collection '{self.collection_name}' holds {stored} points for "
                f"{len(chunks)} chunks: {stored - len(chunks)} point(s) belong to no "
                f"chunk in this set. Use `find_orphans` to identify them and "
                f"`delete_points` to remove them — dropping the collection is no "
                f"longer the only option."
            )

        print(f"✅ Indexed {len(chunks)} chunks successfully ({stored} points in collection)")

    def stored_point_ids(self) -> Dict[str, Optional[str]]:
        """
        Every point in the collection, as ``{point_id: payload chunk_id}``.

        Only the ID and `chunk_id` are fetched — no vectors and no text — so
        this is cheap enough to run on every index, which is what makes
        "does this collection hold exactly this chunk set?" a checkable
        question rather than a remembered one.
        """
        stored: Dict[str, Optional[str]] = {}
        offset = None
        while True:
            points, offset = self.client.scroll(
                collection_name=self.collection_name,
                limit=_SCROLL_PAGE_SIZE,
                offset=offset,
                with_payload=["chunk_id"],
                with_vectors=False,
            )
            for point in points:
                stored[str(point.id)] = (point.payload or {}).get("chunk_id")
            # `offset is None` is the documented end of the scroll. The empty
            # page check is a belt-and-braces guard: a server that returned a
            # non-null offset forever would otherwise loop without end.
            if offset is None or not points:
                return stored

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
        Delete points by ID, returning how many were removed.

        Destructive and deliberately dumb: it deletes exactly what it is given
        and decides nothing. Callers choose what to delete, which keeps the
        judgement in the script the operator invoked.
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

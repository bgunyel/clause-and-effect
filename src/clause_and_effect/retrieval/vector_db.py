"""
Vector database operations using Qdrant
"""
from typing import List, Dict, Any
from pydantic import SecretStr
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct
from tqdm import tqdm

from src.clause_and_effect.parsers import Chunk
from src.clause_and_effect.retrieval import EmbeddingGenerator


class VectorDatabase:
    """Qdrant vector database wrapper"""

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


    def index_chunks(self, chunks: List[Chunk]):
        """
        Index chunks into vector database

        Args:
            chunks: List of Chunk objects to index
        """
        print(f"📊 Indexing {len(chunks)} chunks...")

        # Generate embeddings in batch
        texts = [chunk.text for chunk in chunks]

        batch_size = 100

        for i in tqdm(range(0, len(texts), batch_size)):
            chunks_batch = chunks[i:i + batch_size]
            texts_batch = [c.text for c in chunks_batch]
            batch_embeddings = self.embedding_generator.embed_batch(batch=texts_batch)

            points = [
                PointStruct(
                    id = i*batch_size + j,  # Use numeric ID for Qdrant
                    vector = embedding,
                    payload = {
                        "chunk_id": chunk.id,
                        "text": chunk.text,
                        "metadata": chunk.metadata,
                        }
                    ) for j, (chunk, embedding) in enumerate(zip(chunks_batch, batch_embeddings))
            ]

            self.client.upsert(collection_name=self.collection_name, points=points)

        print(f"✅ Indexed {len(chunks)} chunks successfully")

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

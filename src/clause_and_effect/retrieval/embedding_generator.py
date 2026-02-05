"""
Embeddings generation for documents and queries
"""
from typing import List
from openai import OpenAI
from pydantic import SecretStr


class EmbeddingGenerator:
    """Generate embeddings using OpenAI"""

    def __init__(self, model: str, api_key: SecretStr):
        self.model = model
        self.client = OpenAI(api_key=api_key.get_secret_value())

    def embed_text(self, text: str) -> List[float]:
        """
        Generate embedding for a single text

        Args:
            text: Text to embed

        Returns:
            List of floats (embedding vector)
        """
        response = self.client.embeddings.create(
            model=self.model,
            input=text
        )
        return response.data[0].embedding

    def embed_batch(self, batch: List[str]) -> List[List[float]]:
        """
        Generate embeddings for multiple texts in batches

        Args:
            batch: List of texts to embed

        Returns:
            List of embedding vectors
        """

        response = self.client.embeddings.create(
            model=self.model,
            input=batch
        )

        batch_embeddings = [item.embedding for item in response.data]
        return batch_embeddings

"""
Complete RAG system - putting it all together
"""
from typing import Dict, Any
import time

from pydantic import SecretStr

from ai_common import calculate_token_cost, get_llm
from src.clause_and_effect.generators import Generator
from src.clause_and_effect.retrieval import VectorDatabase


class ComplianceAgent:

    def __init__(self,
                 llm_config: dict[str, Any],
                 vector_db_url: SecretStr,
                 vector_db_port: int,
                 vector_db_api_key: SecretStr,
                 collection_name: str,
                 embedding_model: str,
                 embedding_model_api_key: SecretStr):
        self.models = list({*[v['model'] for k, v in llm_config.items()]})

        self.vector_db = VectorDatabase(
            vector_db_url=vector_db_url,
            vector_db_port=vector_db_port,
            vector_db_api_key=vector_db_api_key,
            collection_name=collection_name,
            embedding_model=embedding_model,
            embedding_model_api_key=embedding_model_api_key,
        )
        self.generator = Generator(model_params=llm_config['reasoning_model'])


    def ask(self, query: str, top_k: int = 3) -> Dict[str, Any]:
        """
        Ask a compliance question

        Args:
            query: User's question
            top_k: Number of chunks to retrieve

        Returns:
            Dict with answer, citations, and metadata
        """
        start_time = time.time()

        # Retrieve relevant chunks
        results = self.vector_db.search(query=query, top_k=top_k)

        if not results:
            return {
                "answer": "I couldn't find relevant information in the regulations to answer this question.",
                "citations": [],
                "retrieval_time": time.time() - start_time,
                "chunks_retrieved": 0
            }

        # Generate answer
        response = self.generator.generate(question=query, scored_points=results)

        # Add timing and retrieval info
        response["retrieval_time"] = time.time() - start_time
        response["chunks_retrieved"] = len(results)
        response["retrieval_scores"] = [r["score"] for r in results]

        return response

    def get_system_info(self) -> Dict[str, Any]:
        """Get information about the RAG system"""
        db_info = self.vector_db.get_collection_info()

        return {
            "vector_db": db_info,
            "generator_model": self.generator.model,
            "embedding_model": self.vector_db.embedding_generator.model,
            "status": "ready" if db_info.get("points_count", 0) > 0 else "not_indexed"
        }

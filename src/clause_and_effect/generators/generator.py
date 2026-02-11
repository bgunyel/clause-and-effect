"""
LLM answer generation with citation grounding.

Episode 1: Simple prompt + structured output. temperature=0.0 for
deterministic compliance answers.

Future episodes will add: multi-hop reasoning, confidence scoring,
conflicting-regulation detection, jurisdiction-aware generation.
"""
import re
from dataclasses import dataclass
from typing import Any, Dict, List
from qdrant_client.models import ScoredPoint

from ai_common import get_llm


@dataclass
class GeneratedAnswer:
    """Structured response from the generator."""
    answer:       str
    citations:    List[str]           # e.g. ["GDPR Article 17", "GDPR Article 7"]
    raw_chunks:   List[Dict[str, Any]]
    model:        str
    total_tokens: int


SYSTEM_PROMPT = """\
You are a compliance AI assistant specialising in GDPR, CCPA, and PIPEDA.
You help B2B SaaS companies understand their regulatory obligations.

Rules:
1. Answer ONLY from the provided regulation excerpts.
2. Cite every article you reference as "REGULATION Article N".
3. If the excerpts don't cover the question, say so clearly — never hallucinate.
4. Be precise and practical. Your audience is an experienced engineering or legal team.
5. If regulations conflict or differ by jurisdiction, explicitly note this.
"""

QUERY_TEMPLATE = """\
Question: {question}

Regulation excerpts:
{context}

Instructions:
- Answer the question using ONLY the excerpts above.
- End with a "Citations:" section listing every article referenced.
"""


class Generator:
    """Generates grounded answers from retrieved regulation chunks."""

    def __init__(self, model_params: Dict[str, Any]):

        self.base_llm = get_llm(model_name=model_params['model'],
                                model_provider=model_params['model_provider'],
                                api_key=model_params['api_key'],
                                model_args=model_params['model_args'])
        self.model_name = model_params['model']


    def generate(self,
                 question: str,
                 scored_points: List[Dict[str, Any]],
                 max_tokens: int = 1024,
    ) -> GeneratedAnswer:
        """
        Generate a grounded answer from retrieved chunks.

        Args:
            question:      User's compliance question
            scored_points: Retrieved chunks from vector search
            max_tokens:    Cap on response length

        Returns:
            GeneratedAnswer with answer text, citations, and metadata
        """
        context = self._format_context(scored_points)
        query = QUERY_TEMPLATE.format(question=question, context=context)

        response = self.base_llm.invoke(
            input = [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user",   "content": query},
            ]
        )

        answer_text  = response.content
        total_tokens = 0

        return GeneratedAnswer(
            answer=answer_text,
            citations=self._extract_citations(answer_text),
            raw_chunks=scored_points,
            model=self.model_name,
            total_tokens=total_tokens,
        )

    # ------------------------------------------------------------------ #
    #  Private helpers                                                     #
    # ------------------------------------------------------------------ #

    @staticmethod
    def _format_context(scored_points: List[Dict[str, Any]]) -> str:
        parts = []
        for i, point in enumerate(scored_points, 1):
            regulation = point['metadata'].get("regulation", "Unknown")
            article    = point['metadata'].get("article_number", "?")
            title      = point['metadata'].get("article_title", "")
            text       = point.get("text", "")
            score      = point.get("score", "N/A")
            parts.append(
                f"[{i}] {regulation} Article {article}: {title} (relevance: {score:.2f})\n"
                f"{text}\n"
            )
        return "\n---\n".join(parts)

    @staticmethod
    def _extract_citations(answer_text: str) -> List[str]:
        pattern = r"(GDPR|CCPA|PIPEDA)\s+Article\s+[\d\.]+"
        return list(dict.fromkeys(re.findall(pattern, answer_text, re.IGNORECASE)))

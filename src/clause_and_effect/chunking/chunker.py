import re
from typing import Any, Dict, List

from .chunk import Chunk, ChunkMetadata, ArticleMetadata
from .regulation import Regulation

class Chunker:
    def __init__(self, regulation: Regulation):
        self.regulation = regulation

    def run(self, content: str, article_metadata: ArticleMetadata) -> List[Chunk]:

        # If article is short enough, return as single chunk
        if len(content) < 1000:
            full_text = (
                f"Article {article_metadata.article_number}: "
                f"{article_metadata.article_title}\n\n{content}"
            )
            chunk_id = self._create_chunk_id(article_num=article_metadata.article_number)
            return [
                Chunk(
                    id=chunk_id,
                    text=full_text,
                    metadata=ChunkMetadata(
                        **article_metadata.model_dump(),
                        **self._regulation_fields(),
                        chunk_type="article",
                        )
                    )
            ]

        # For long articles, split by paragraphs
        paragraphs = self._split_into_paragraphs(content)
        chunks = []

        for i, paragraph_text in enumerate(paragraphs, start=1):
            chunk_id = self._create_chunk_id(
                article_num=article_metadata.article_number,
                paragraph=str(i),
            )
            paragraph_full_text = (
                f"Article {article_metadata.article_number}({i}): "
                f"{article_metadata.article_title}\n\n{paragraph_text}"
            )
            chunks.append(
                Chunk(
                    id=chunk_id,
                    text=paragraph_full_text,
                    metadata=ChunkMetadata(
                        **article_metadata.model_dump(),
                        **self._regulation_fields(),
                        chunk_type="paragraph",
                        paragraph_number=str(i),
                        )
                    )
            )

        return chunks

    def _regulation_fields(self) -> Dict[str, str]:
        """The regulation-level half of every `ChunkMetadata`."""
        return {
            "regulation": self.regulation.name,
            "jurisdiction": self.regulation.jurisdiction,
            "effective_date": self.regulation.effective_date,
        }

    def _create_chunk_id(self, article_num: str, paragraph: str | None = None) -> str:
        """
        Generate a unique chunk ID.

        The same string that goes into the payload's ``regulation`` field is
        what prefixes the ID here, so the two cannot disagree — an ID reading
        ``gdpr_…`` beside a payload claiming another regulation is not a state
        this can reach.

        Never change the derivation. Chunk IDs derive Qdrant point IDs, so a
        different format re-keys the corpus and a re-index writes a parallel set
        of points instead of updating them in place.
        """
        base_id = f"{self.regulation.name.lower()}_article_{article_num}"
        if paragraph:
            return f"{base_id}_para_{paragraph}"
        return base_id

    @staticmethod
    def _split_into_paragraphs(content: str) -> List[str]:
        """Split article content into numbered paragraphs"""
        # GDPR uses numbered paragraphs: "1. ", "2. ", etc.
        paragraph_pattern = r'\d+\.\s+'
        paragraphs = re.split(paragraph_pattern, content)
        # Remove empty strings and clean up
        return [p.strip() for p in paragraphs if p.strip()]
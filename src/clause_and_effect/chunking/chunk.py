from typing import Literal, Optional
from pydantic import BaseModel, Field


class ArticleMetadata(BaseModel):
    """What varies from one article to the next."""

    article_number: str = Field(description="Article number or id", repr=True)
    article_title: str = Field(description="Article title", repr=True)
    chapter: str = Field(description="Chapter number of the article", repr=True)
    chapter_title: str = Field(description="Chapter title of the article", repr=True)

class ChunkMetadata(ArticleMetadata):
    """
    What a chunk carries into the vector store.

    The three regulation-level fields are supplied by the `Chunker` from its
    `Regulation` rather than repeated on every `ArticleMetadata`, so they cannot
    vary between articles of the same corpus.
    """

    effective_date: str = Field(
        description="Date the regulation became applicable",
        repr=True,
    )
    jurisdiction: str = Field(
        description="Jurisdiction of the regulation",
        examples=["EU"],
        repr=True,
    )
    regulation: str = Field(
        description="Name of the regulation",
        examples=["GDPR, CCPA"],
        repr=True,
    )
    chunk_type: Literal["article", "paragraph"] = Field(
        description="Chunk type of the article",
        repr=True,
    )
    paragraph_number: Optional[str] = Field(
        default=None,
        description="Paragraph number within the article (if chunk_type == paragraph)",
        repr=True
    )

class Chunk(BaseModel):
    """A chunk of text from a regulation document"""
    id: str
    text: str
    metadata: ChunkMetadata

    def __repr__(self):
        return f"Chunk(id='{self.id}', metadata={self.metadata.model_dump()})"



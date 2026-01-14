import re
from pathlib import Path
from typing import List, Dict, Any
import pypdf
from docling.document_converter import DocumentConverter

from .base_parser import BaseParser, Chunk
from src.config import get_settings


class GDPRParser(BaseParser):
    """
    Parser for GDPR regulation documents
    Handles the structure of GDPR regulation (99 articles + recitals)
    """

    # GDPR has 11 chapters
    CHAPTER_TITLES = {
        "1": "General provisions",
        "2": "Principles",
        "3": "Rights of the data subject",
        "4": "Controller and processor",
        "5": "Transfers of personal data to third countries or international organisations",
        "6": "Independent supervisory authorities",
        "7": "Cooperation and consistency",
        "8": "Remedies, liability and penalties",
        "9": "Provisions relating to specific processing situations",
        "10": "Delegated acts and implementing acts",
        "11": "Final provisions",
    }

    def __init__(self):
        super().__init__("GDPR")

    def parse(self, file_path: Path) -> List[Chunk]:
        """
        Parse GDPR PDF into article-level chunks

        Args:
            file_path: Path to GDPR PDF file

        Returns:
            List of Chunk objects, one per article (or paragraph for long articles)
        """
        print(f"📖 Parsing GDPR from {file_path}")

        # Extract text from PDF
        # text = self._extract_text_from_pdf(file_path)

        document_converter = DocumentConverter()
        document = document_converter.convert(file_path)



        # Extract articles
        articles = self._extract_articles(text=document.document.export_to_markdown())

        print(f"✅ Extracted {len(articles)} articles from GDPR")

        # Convert to chunks
        chunks = []
        for article in articles:
            article_chunks = self._article_to_chunks(article)
            chunks.extend(article_chunks)

        print(f"✅ Created {len(chunks)} chunks from GDPR")

        return chunks

    @staticmethod
    def _extract_text_from_pdf(file_path: Path) -> str:
        """Extract all text from PDF"""
        reader = pypdf.PdfReader(file_path)
        text = ""
        for page in reader.pages:
            text += page.extract_text()
        return text

    def _extract_articles(self, text: str) -> List[Dict[str, Any]]:
        """
        Extract individual articles from GDPR text

        GDPR articles follow pattern: "Article X\n[Title]\n[Content]"
        """
        articles = []

        # Pattern to match "Article N" followed by title and content
        # This is a simplified pattern - real implementation needs refinement
        article_pattern = r'Article\s+(\d+)\s*\n([^\n]+)\n((?:(?!Article\s+\d+).)+)'

        matches = re.finditer(article_pattern, text, re.DOTALL)

        for match in matches:
            article_num = match.group(1)
            title = match.group(2).strip()
            content = match.group(3).strip()

            # Extract chapter (approximation based on article number)
            chapter = self._get_chapter_for_article(int(article_num))

            articles.append({
                "number": article_num,
                "title": title,
                "content": content,
                "chapter": chapter
            })

        return articles

    @staticmethod
    def _get_chapter_for_article(article_num: int) -> str:
        """Determine chapter based on article number"""
        # Approximate chapter divisions for GDPR
        if 1 <= article_num <= 4:
            return "1"
        elif 5 <= article_num <= 11:
            return "2"
        elif 12 <= article_num <= 23:
            return "3"
        elif 24 <= article_num <= 43:
            return "4"
        elif 44 <= article_num <= 50:
            return "5"
        elif 51 <= article_num <= 59:
            return "6"
        elif 60 <= article_num <= 76:
            return "7"
        elif 77 <= article_num <= 84:
            return "8"
        elif 85 <= article_num <= 91:
            return "9"
        elif 92 <= article_num <= 93:
            return "10"
        else:
            return "11"

    def _article_to_chunks(self, article: Dict[str, Any]) -> List[Chunk]:
        """
        Convert an article to one or more chunks

        For short articles: 1 chunk
        For long articles (>1000 chars): Split by paragraph
        """
        article_num = article["number"]
        title = article["title"]
        content = article["content"]
        chapter = article["chapter"]
        chapter_title = self.CHAPTER_TITLES.get(chapter, "Unknown")

        # Full article text
        full_text = f"Article {article_num}: {title}\n\n{content}"

        # Base metadata
        base_metadata = {
            "regulation": "GDPR",
            "article_number": article_num,
            "article_title": title,
            "chapter": chapter,
            "chapter_title": chapter_title,
            "jurisdiction": "EU",
            "effective_date": "2018-05-25",
            "topics": self._extract_topics(full_text),
            "chunk_type": "article"
        }

        # If article is short enough, return as single chunk
        if len(content) < 1000:
            chunk_id = self._create_chunk_id(article_num)
            return [Chunk(
                id=chunk_id,
                text=full_text,
                metadata=base_metadata
            )]

        # For long articles, split by paragraphs
        paragraphs = self._split_into_paragraphs(content)
        chunks = []

        for i, para_text in enumerate(paragraphs, start=1):
            chunk_id = self._create_chunk_id(article_num, str(i))
            para_metadata = {
                **base_metadata,
                "paragraph": str(i),
                "chunk_type": "paragraph"
            }

            para_full_text = f"Article {article_num}.{i}: {title}\n\n{para_text}"

            chunks.append(Chunk(
                id=chunk_id,
                text=para_full_text,
                metadata=para_metadata
            ))

        return chunks

    @staticmethod
    def _split_into_paragraphs(content: str) -> List[str]:
        """Split article content into numbered paragraphs"""
        # GDPR uses numbered paragraphs: "1. ", "2. ", etc.
        paragraph_pattern = r'\d+\.\s+'
        paragraphs = re.split(paragraph_pattern, content)
        # Remove empty strings and clean up
        return [p.strip() for p in paragraphs if p.strip()]


# Example usage function
def demo_gdpr_parser():
    """Demonstrate GDPR parser functionality"""
    settings = get_settings()

    parser = GDPRParser()
    gdpr_path = settings.regulations_dir / "gdpr.pdf"

    if gdpr_path.exists():
        chunks = parser.parse(gdpr_path)

        # Display sample chunks
        print("\n" + "=" * 60)
        print("SAMPLE CHUNKS")
        print("=" * 60)

        for chunk in chunks[:3]:  # Show first 3 chunks
            print(f"\n📄 {chunk.id}")
            print(f"Metadata: {chunk.metadata}")
            print(f"Text preview: {chunk.text[:200]}...")
            print("-" * 60)
    else:
        print(f"❌ GDPR file not found at {gdpr_path}")
        print("Run: bash scripts/download_regulations.sh")
        chunks = None

    return chunks


if __name__ == "__main__":
    demo_gdpr_parser()
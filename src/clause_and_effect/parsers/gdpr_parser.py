import re
from pathlib import Path
from typing import List, Dict, Any
import pypdf

from .base_parser import BaseParser, Chunk


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
        articles = self.get_articles(file_path=file_path)
        print(f"✅ Extracted {len(articles)} articles from GDPR")

        # Convert to chunks
        chunks = []
        for article in articles:
            article_chunks = self.article_to_chunks(article)
            chunks.extend(article_chunks)

        print(f"✅ Created {len(chunks)} chunks from GDPR")

        return chunks

    def get_articles(self, file_path: Path) -> List[Dict[str, Any]]:
        # Extract text from PDF
        text = self._extract_text_from_pdf(file_path)

        # Extract articles
        articles = self._extract_articles(text=text)
        return articles


    # A *real* article header: "Article N" alone on its own line, optionally
    # carrying a markdown heading prefix (MULTILINE anchors ^ to line starts;
    # the number must be followed only by optional spaces and a line break).
    # docling exports 98 of the 99 headers as "## Article N" and one — Article
    # 28 — bare, so the '#' prefix must be optional rather than required:
    # requiring the bare form collapsed the whole document into a single
    # article, and requiring '##' would drop Article 28's boundary.
    #
    # This deliberately does NOT match inline cross-references such as "...  as
    # referred to in Article 6 ...", which sit mid-line. Keying article
    # boundaries off inline references was the original implementation's bug: a
    # tempered-token regex stopped each article's content at the first inline
    # "Article N", silently truncating ~3/4 of the articles (and dropping
    # everything after the reference).
    _ARTICLE_HEADER = re.compile(r'^#{0,6}[ \t]*Article[ \t]+(\d+)[ \t]*$', re.MULTILINE)

    def _extract_articles(self, text: str) -> List[Dict[str, Any]]:
        """
        Split the GDPR document into one record per article.

        Articles are delimited by *line-anchored* headers ("Article N" on its
        own line). Everything from one header up to the next header — or the end
        of the document for the final article — belongs to that article. The
        first line of that block is the title; the remainder is the content.

        Because boundaries key off line-anchored headers only, inline
        cross-references between articles are kept as content instead of
        prematurely ending an article.
        """
        articles = []
        headers = list(self._ARTICLE_HEADER.finditer(text))

        for i, header in enumerate(headers):
            article_num = header.group(1)
            body_start = header.end()
            body_end = headers[i + 1].start() if i + 1 < len(headers) else len(text)

            block = text[body_start:body_end].strip('\n')
            # First (non-empty) line is the title; the rest is the content.
            first_line, _, rest = block.partition('\n')
            title = self._clean_title(first_line)
            content = self._clean_content(rest)

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
    def _clean_title(line: str) -> str:
        """Strip leading markdown heading markers ('## ') and whitespace."""
        return re.sub(r'^#+\s*', '', line.strip())

    # Structural scaffolding that can trail an article when the next chapter or
    # section starts: a markdown heading, or a bare 'CHAPTER IV' / 'Section 2'
    # marker. docling is inconsistent about the '##' prefix — it dropped it for
    # Article 28's header and for the 'Section 1' after Article 59 — so the
    # bare forms must be recognised too.
    _TRAILING_SCAFFOLDING = re.compile(
        r'^\s*(?:#+\s.*|(?:CHAPTER\s+[IVXLC]+|Section\s+\d+)\s*)$'
    )

    @classmethod
    def _is_trailing_scaffolding(cls, line: str) -> bool:
        """True for blank lines and structural headings that belong to the next section."""
        return not line.strip() or bool(cls._TRAILING_SCAFFOLDING.match(line))

    @staticmethod
    def _clean_content(content: str) -> str:
        """
        Tidy extracted article content.

        - Drop dangling markdown headings the next section bled in. The last
          article before a chapter break picks up that chapter's scaffolding
          ('## CHAPTER II', blank, '## Principles'), which belongs to the next
          chapter rather than this article. Blank lines between those headings
          must not stop the strip — halting on the first blank left one heading
          glued to the content, which is how chapter titles ended up inside
          article text (and tripped the generator's truncation heuristic).
        - Collapse OCR double-spacing (runs of spaces/tabs) to single spaces,
          while preserving line breaks and paragraph structure.
        """
        lines = content.rstrip().split('\n')
        while lines and GDPRParser._is_trailing_scaffolding(lines[-1]):
            lines.pop()
        cleaned = '\n'.join(lines)
        cleaned = re.sub(r'[ \t]{2,}', ' ', cleaned)
        return cleaned.strip()

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

    def article_to_chunks(self, article: Dict[str, Any]) -> List[Chunk]:
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
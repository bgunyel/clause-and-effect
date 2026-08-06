import re
from pathlib import Path
from typing import List, Dict, Any
import pypdf

from .base_parser import BaseParser, Chunk
from .docling_tree import text_items


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

    def get_articles_from_markdown(self, markdown: str) -> List[Dict[str, Any]]:
        """
        Extract articles from an already-exported docling markdown.

        The article split is pure text processing, so separating it from the OCR
        conversion means a parser change can be re-run in under a second against
        the cached export (``data/regulations/gdpr.docling.md``) rather than
        repeating six minutes of OCR. Same code path as :meth:`get_articles`
        past the conversion, so the two agree by construction.
        """
        return self._extract_articles(text=markdown)

    def get_articles_from_dictionary(self, document: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Extract articles from docling's document tree (``gdpr.docling.json``).

        The tree is the better source because it never rendered the hierarchy
        away: paragraph numbers survive in each item's ``marker`` field, kept
        structurally apart from the body text. The markdown path has to
        re-derive them from a string, where "22." ending a cross-reference
        ("Articles 15 to 22. In the cases...") is indistinguishable from "2."
        opening a paragraph — the same defect, one level down, that
        :attr:`_ARTICLE_HEADER` had to be line-anchored to avoid.

        Returns the same four-key records as :meth:`get_articles_from_markdown`
        so every consumer is unaffected. What changes is their ``content``: the
        numbering is the regulation's own rather than the serializer's
        invention, and sub-items stay with the paragraph that governs them.
        """
        return self._extract_articles_from_items(text_items(document))

    # An article heading in the tree: the whole item reads "Article N". There
    # is no '#' prefix to allow for — the heading is its own item — but the
    # *label* still varies, so it cannot be the test: 98 headings are
    # 'section_header' and Article 28 alone is 'text'. This is the same Article
    # 28 quirk the markdown path hit, in a different serialization. Verified
    # 2026-08-06: matching on text alone finds all 99, in order, no gaps;
    # matching on 'section_header' alone finds 98 and folds Article 28 into 27.
    _ARTICLE_HEADING = re.compile(r'^Article\s+(\d+)$')

    # A first-order paragraph, as docling promotes it out of the text: "1.".
    # Distinct from "(1)", which Article 4 uses for its 26 definitions — those
    # are sub-items of the article's stem, not paragraphs.
    _PARAGRAPH_MARKER = re.compile(r'^(\d+)\.$')

    # A paragraph number docling left inline instead of promoting it. 9 items,
    # across articles 9, 18, 35, 57 and 58. Reading only `marker` drops these
    # paragraphs silently and leaves those articles' numbering with holes.
    _INLINE_PARAGRAPH = re.compile(r'^(\d+)\.\s+')

    # Chapter and section scaffolding sitting between two articles. 49 such
    # items fall inside article ranges: 24 'CHAPTER V'/'Section 2' markers and
    # their 25 title items, all labelled 'section_header' and dropped by label.
    # The 'Section 1' after Article 59 is labelled 'text' and needs this — the
    # same inconsistency the markdown path handles in _TRAILING_SCAFFOLDING.
    _STRUCTURAL_HEADING = re.compile(r'^(?:CHAPTER\s+[IVXLC]+|Section\s+\d+)$')

    # Items that are never article content, whatever they contain: chapter and
    # section headings, and the 3 footnotes citing other instruments.
    _NON_CONTENT_LABELS = frozenset({"section_header", "footnote"})

    def _extract_articles_from_items(self, items: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Split a document-ordered item list into one record per article.

        An article runs from its heading item to the next heading, or the end
        of the document for Article 99 — which is why its closing provisions
        ("It shall apply from 25 May 2018", the signature block) stay with it,
        matching the markdown path.

        The item immediately after each heading is its title: verified 99/99,
        and always a 'section_header'. That replaces the markdown path's
        "first line of the block" convention, which had to guess.
        """
        headings = [
            (i, match.group(1))
            for i, item in enumerate(items)
            if (match := self._ARTICLE_HEADING.match((item.get("text") or "").strip()))
        ]

        articles = []
        for n, (start, number) in enumerate(headings):
            end = headings[n + 1][0] if n + 1 < len(headings) else len(items)

            title = self._clean_title(items[start + 1].get("text", "")) if start + 1 < end else ""
            units = self._build_units(items[start + 2:end])

            articles.append({
                "number": number,
                "title": title,
                "content": self._render_units(units),
                "chapter": self._get_chapter_for_article(int(number)),
            })

        return articles

    @classmethod
    def _build_units(cls, items: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Group an article's items into paragraphs, each holding its sub-items.

        This is the hierarchy the markdown serializer destroyed, rebuilt from
        the fields that survived. A unit is one first-order paragraph (or, for
        the 17 articles with no numbered paragraphs, an unnumbered stem), and
        its ``sub_items`` are everything that belongs *under* it — Article
        2(2)'s (a)-(d), Article 4's 26 definitions, an unnumbered subparagraph
        continuing the provision above it.

        Sub-items attach to the nearest preceding unit rather than the nearest
        preceding *numbered* unit, because Article 4 and Article 50 both open
        on an unnumbered stem that governs everything after it.

        Only ``content`` is serialized today, and rendering flattens this back
        to lines — but the nesting is what makes that rendering correct, and it
        is what a hierarchy-aware chunker will need (see docs/todo.md).
        """
        units: List[Dict[str, Any]] = []

        for item in items:
            if item.get("label") in cls._NON_CONTENT_LABELS:
                continue

            text = cls._clean_text(item.get("text", ""))
            if not text or cls._STRUCTURAL_HEADING.match(text):
                continue

            marker = (item.get("marker") or "").strip()
            number = None

            if item.get("label") == "list_item" and item.get("enumerated"):
                match = cls._PARAGRAPH_MARKER.match(marker)
                if match:
                    number, marker = match.group(1), ""
            elif item.get("label") == "text":
                match = cls._INLINE_PARAGRAPH.match(text)
                if match:
                    number, marker, text = match.group(1), "", text[match.end():]

            if number is not None or not units:
                units.append({"number": number, "marker": marker, "text": text, "sub_items": []})
            else:
                units[-1]["sub_items"].append({"marker": marker, "text": text})

        return units

    @staticmethod
    def _render_units(units: List[Dict[str, Any]]) -> str:
        """
        Render units back to the flat ``content`` string consumers expect.

        One line per item, marker inline. Indentation is deliberately not used:
        `_clean_content` collapses runs of spaces on the markdown path, quote
        grounding normalizes whitespace away, and embeddings never see it — so
        it would be decoration that makes the two paths' output differ for no
        gain. The hierarchy is carried by correct numbering, not by layout.
        """
        lines = []
        for unit in units:
            if unit["number"] is not None:
                lines.append(f'{unit["number"]}. {unit["text"]}')
            elif unit["marker"]:
                lines.append(f'{unit["marker"]} {unit["text"]}')
            else:
                lines.append(unit["text"])
            lines.extend(
                f'{sub["marker"]} {sub["text"]}' if sub["marker"] else sub["text"]
                for sub in unit["sub_items"]
            )
        return "\n".join(lines).strip()

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

    # A soft hyphen (U+00AD) together with the whitespace that follows it.
    # docling preserves the discretionary hyphen the scanned page used to break
    # a word across a line, so the export carries "internat\xad ional",
    # "certifi\xad cation", "propor\xad tionate" and so on.
    _SOFT_HYPHEN_BREAK = re.compile('­\\s*')

    @classmethod
    def _rejoin_hyphenated_words(cls, text: str) -> str:
        """
        Rejoin words that OCR broke across lines with a soft hyphen.

        Left in place, each break splits one word into two meaningless tokens —
        wrong in the text that gets embedded, and invisible to any lexical
        scorer doing string comparison. The whitespace *after* the hyphen has to
        go with it: deleting only the codepoint leaves "internat ional", which
        is no improvement.

        Applied per-article rather than to the whole document, so it only
        touches text that actually becomes article content. Real hyphens are
        U+002D ("cross-border", "Subject-matter") and are left alone.
        """
        return cls._SOFT_HYPHEN_BREAK.sub('', text)

    @classmethod
    def _clean_text(cls, text: str) -> str:
        """
        The OCR repairs both source paths need: rejoin soft-hyphen breaks and
        collapse double spacing.

        Shared so markdown-derived and tree-derived content cannot disagree on
        what the same sentence looks like. The damage is upstream of any
        serialization choice — it is present in the tree's ``text`` field too —
        so switching source neither fixes nor worsens it.
        """
        return re.sub(r'[ \t]{2,}', ' ', cls._rejoin_hyphenated_words(text)).strip()

    @classmethod
    def _clean_title(cls, line: str) -> str:
        """Strip leading markdown heading markers ('## ') and whitespace."""
        return cls._rejoin_hyphenated_words(re.sub(r'^#+\s*', '', line.strip()))

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
        - Rejoin words the scan broke across lines with a soft hyphen
          ("internat\xad ional" -> "international").
        - Collapse OCR double-spacing (runs of spaces/tabs) to single spaces,
          while preserving line breaks and paragraph structure.
        """
        content = GDPRParser._rejoin_hyphenated_words(content)
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
"""
Regression tests for GDPRParser article extraction.

These guard a real, critical defect: the original `_extract_articles` regex
stopped each article's content at the first *inline* "Article N"
cross-reference, silently truncating ~3/4 of GDPR's articles before they were
ever chunked, embedded, and indexed. That bug was invisible because the parser
is deterministic plumbing with no test around it. These tests exercise the
extraction logic directly on synthetic, GDPR-shaped markdown — no PDF or OCR
needed — so the regression can never return silently.
"""
import pytest

from src.clause_and_effect.parsers.gdpr_parser import GDPRParser
from src.clause_and_effect.parsers.base_parser import Chunk


# Synthetic markdown mirroring docling's export: a line-anchored "Article N"
# header, a title line, then numbered content. Deliberately seeded with the
# exact patterns that broke the old parser: inline "Article N" cross-references,
# a dangling next-section heading, and OCR double-spacing.
SAMPLE = """Article 93
## Committee procedure
1. The Commission shall be assisted by a committee.
2. Where reference is made to this paragraph, Article 5 of Regulation (EU) No 182/2011 shall apply.
Article 94
## Repeal of Directive 95/46/EC
1. Directive  95/46/EC  is  repealed with effect from 25 May 2018.
2. References to the Working Party established by Article 29 of Directive 95/46/EC shall be construed as references to the European Data Protection Board established by this Regulation.

## Entry into force and application
Article 95
## Relationship with Directive 2002/58/EC
This Regulation shall not impose additional obligations in relation to processing."""


@pytest.fixture
def parser():
    return GDPRParser()


@pytest.fixture
def articles(parser):
    return {a["number"]: a for a in parser._extract_articles(SAMPLE)}


def test_extracts_every_article(articles):
    assert set(articles) == {"93", "94", "95"}


def test_inline_cross_reference_does_not_truncate(articles):
    """The core regression: content after an inline 'Article N' must survive."""
    art94 = articles["94"]["content"]
    # Everything past the old truncation point ("... established by") must be here.
    assert "Article 29 of Directive 95/46/EC" in art94
    assert art94.rstrip().endswith("established by this Regulation.")


def test_content_kept_after_inline_reference_midsentence(articles):
    art93 = articles["93"]["content"]
    assert art93.rstrip().endswith("shall apply.")
    assert "Article 5 of Regulation" in art93


def test_final_article_captured_to_end_of_document(articles):
    """The last article has no trailing header — it must run to EOF."""
    assert articles["95"]["content"].rstrip().endswith("processing.")


def test_title_stripped_of_markdown_heading(articles):
    assert articles["94"]["title"] == "Repeal of Directive 95/46/EC"
    assert not articles["94"]["title"].startswith("#")


def test_ocr_double_spacing_collapsed(articles):
    assert "  " not in articles["94"]["content"]


def test_dangling_next_section_heading_removed(articles):
    assert "Entry into force" not in articles["94"]["content"]


def test_chapter_assigned_from_article_number(articles):
    # Articles 92-93 -> chapter 10; 94-99 -> chapter 11 (see _get_chapter_for_article).
    assert articles["93"]["chapter"] == "10"
    assert articles["94"]["chapter"] == "11"


def test_record_shape_is_stable(articles):
    assert sorted(articles["94"]) == ["chapter", "content", "number", "title"]


def test_no_headers_yields_no_articles(parser):
    assert parser._extract_articles("Just some text with no article headers.") == []


def test_inline_reference_never_creates_spurious_record(parser):
    """An inline 'Article 29' reference must not spawn its own article record."""
    nums = [a["number"] for a in parser._extract_articles(SAMPLE)]
    assert nums == ["93", "94", "95"]
    assert nums.count("29") == 0


# --------------------------------------------------------------------------- #
#  article_to_chunks — the bridge from extracted articles to indexed chunks.  #
# --------------------------------------------------------------------------- #

def test_short_article_becomes_single_article_chunk(parser, articles):
    chunks = parser.article_to_chunks(articles["94"])
    assert len(chunks) == 1
    chunk = chunks[0]
    assert isinstance(chunk, Chunk)
    assert chunk.metadata["article_number"] == "94"
    assert chunk.metadata["regulation"] == "GDPR"
    assert chunk.metadata["chunk_type"] == "article"
    # The recovered cross-reference text must reach the indexed chunk.
    assert "European Data Protection Board" in chunk.text


def test_long_article_splits_into_paragraph_chunks(parser):
    long_content = "\n".join(f"{i}. " + "clause text " * 40 for i in range(1, 5))
    article = {"number": "5", "title": "Principles", "content": long_content, "chapter": "2"}
    chunks = parser.article_to_chunks(article)
    assert len(chunks) > 1
    assert all(c.metadata["chunk_type"] == "paragraph" for c in chunks)
    assert all(c.metadata["article_number"] == "5" for c in chunks)
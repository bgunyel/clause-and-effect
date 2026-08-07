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
from pathlib import Path

import pytest

from src.clause_and_effect.parsers.gdpr_parser import GDPRParser
from src.clause_and_effect.chunking import Chunk


# Synthetic markdown mirroring docling's *actual* export, verified against
# data/regulations/gdpr.docling.md. Header shapes matter: docling writes 98 of
# the 99 headers as "## Article N" and exactly one (Article 28) bare, so both
# forms appear below. An earlier version of this fixture used only the bare
# form; the parser was then written to match only that, which collapsed the
# whole regulation into a single 137k-character article — a bug this suite
# waved through precisely because the fixture was not calibrated to reality.
#
# Also seeded with the patterns that broke earlier parser revisions: inline
# "Article N" cross-references, dangling next-section headings, trailing
# chapter/section scaffolding (including a *bare* "Section 1"), and OCR
# double-spacing.
SAMPLE = """## Article 93
## Committee procedure
1. The Commission shall be assisted by a committee.
2. Where reference is made to this paragraph, Article 5 of Regulation (EU) No 182/2011 shall apply.

## CHAPTER XI

## Final provisions

Section 1

Article 94
## Repeal of Directive 95/46/EC
1. Directive  95/46/EC  is  repealed with effect from 25 May 2018. Any cross-border admin­ istration shall be propor­ tionate.
2. References to the Working Party established by Article 29 of Directive 95/46/EC shall be construed as references to the European Data Protection Board established by this Regulation.

## Entry into force and application
## Article 95
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


def test_ocr_soft_hyphen_breaks_rejoined(articles):
    """
    docling keeps the discretionary hyphen (U+00AD) where the scan broke a word
    across a line, e.g. "internat\xad ional". Both the hyphen and the space
    after it must go, or the word stays split into two meaningless tokens.
    """
    content = articles["94"]["content"]
    assert "­" not in content
    assert "administration" in content
    assert "proportionate" in content


def test_real_hyphens_are_not_touched(articles):
    """U+002D is a real hyphen in the regulation's own wording, not an artifact."""
    assert "cross-border" in articles["94"]["content"]


def test_dangling_next_section_heading_removed(articles):
    assert "Entry into force" not in articles["94"]["content"]


def test_markdown_prefixed_header_detected(articles):
    """docling writes almost every header as '## Article N' — it must delimit."""
    assert articles["93"]["title"] == "Committee procedure"
    assert articles["95"]["title"] == "Relationship with Directive 2002/58/EC"


def test_bare_header_detected(articles):
    """One real header (Article 28) has no '##' prefix; both forms must work."""
    assert articles["94"]["title"] == "Repeal of Directive 95/46/EC"


def test_trailing_chapter_scaffolding_removed(articles):
    """
    The last article before a chapter break picks up that chapter's heading
    block. Blank lines between those headings must not stop the strip, and the
    bare 'Section 1' form must be recognised alongside the '## ' form.
    """
    art93 = articles["93"]["content"]
    assert "CHAPTER XI" not in art93
    assert "Final provisions" not in art93
    assert "Section 1" not in art93
    assert art93.rstrip().endswith("shall apply.")


def test_chapter_assigned_from_article_number(articles):
    # Articles 92-93 -> chapter 10; 94-99 -> chapter 11 (see _get_chapter_for_article).
    assert articles["93"]["chapter"] == "10"
    assert articles["94"]["chapter"] == "11"


def test_record_shape_is_stable(articles):
    assert sorted(articles["94"]) == ["chapter", "content", "number", "title"]


def test_no_headers_yields_no_articles(parser):
    assert parser._extract_articles("Just some text with no article headers.") == []


def test_get_articles_from_markdown_matches_internal_split(parser):
    """
    The cached-export path must agree with the PDF path past the conversion.

    `generate_gdpr_articles.py` reads `gdpr.docling.md` by default and only
    falls back to re-running OCR, so the two entry points have to produce the
    same records or the cheap path would silently diverge from the expensive
    one.
    """
    assert parser.get_articles_from_markdown(SAMPLE) == parser._extract_articles(SAMPLE)


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


# --------------------------------------------------------------------------- #
#  Extraction against the real docling export.                                #
#                                                                             #
#  The synthetic fixture above encodes what we *believe* docling emits; these  #
#  run the same logic over what it actually emitted (checked in as            #
#  data/regulations/gdpr.docling.md, so no PDF or OCR is needed). A fixture    #
#  that drifts from the real export is exactly how the single-article          #
#  collapse shipped, so both layers are kept.                                  #
# --------------------------------------------------------------------------- #

DOCLING_MARKDOWN = (
    Path(__file__).resolve().parent.parent
    / "data" / "regulations" / "gdpr.docling.md"
)


@pytest.fixture(scope="module")
def real_articles():
    if not DOCLING_MARKDOWN.exists():
        pytest.skip(f"docling export not available at {DOCLING_MARKDOWN}")
    text = DOCLING_MARKDOWN.read_text(encoding="utf-8")
    return GDPRParser()._extract_articles(text)


def test_real_export_yields_all_99_articles(real_articles):
    """GDPR has exactly 99 articles, each appearing once, in order."""
    numbers = [int(a["number"]) for a in real_articles]
    assert numbers == list(range(1, 100))


def test_real_export_articles_all_have_title_and_content(real_articles):
    assert [a["number"] for a in real_articles if not a["title"].strip()] == []
    assert [a["number"] for a in real_articles if not a["content"].strip()] == []
    assert [a["number"] for a in real_articles if "#" in a["title"]] == []


def test_real_export_carries_no_soft_hyphens(real_articles):
    """
    The real export has 39 soft hyphens, 18 of which land inside article
    content (14 articles, e.g. "internat\xad ional" in Article 14). None may
    survive into the corpus: each one splits a word into two tokens that no
    embedding or lexical scorer can match.
    """
    offenders = [
        a["number"] for a in real_articles
        if "­" in a["title"] or "­" in a["content"]
    ]
    assert offenders == []


def test_real_export_no_structural_scaffolding_leaks_into_content(real_articles):
    leaked = [
        a["number"]
        for a in real_articles
        if "## CHAPTER" in a["content"] or "## Section" in a["content"]
    ]
    assert leaked == []


def test_real_export_public_markdown_entry_point_yields_all_99(parser):
    """The path `generate_gdpr_articles.py` actually uses, on the real export."""
    if not DOCLING_MARKDOWN.exists():
        pytest.skip(f"docling export not available at {DOCLING_MARKDOWN}")
    articles = parser.get_articles_from_markdown(
        DOCLING_MARKDOWN.read_text(encoding="utf-8")
    )
    assert [int(a["number"]) for a in articles] == list(range(1, 100))


def test_real_export_inline_cross_references_do_not_truncate(real_articles):
    """
    Article 56 opens with an inline 'Article 55' reference; the old tempered
    regex cut the article there. It must survive intact.
    """
    art56 = next(a for a in real_articles if a["number"] == "56")
    assert "Without prejudice to Article 55" in art56["content"]
    assert len(art56["content"]) > 1500
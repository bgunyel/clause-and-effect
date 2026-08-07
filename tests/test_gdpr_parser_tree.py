"""
Tests for `GDPRParser.get_articles_from_dictionary` — the tree-based corpus path.

This is the half of the 2026-08-05 defect that was fixed: the markdown
serializer flattened nested lists into one ordered run and renumbered them, so
Article 2's sub-items (a)-(d) were emitted as `3. 4. 5. 6.` and the real ¶3 and
¶4 then restarted at `3.` and `4.`. Within one article, `3.` denoted two
different things, and "Article 2(3)" was unresolvable from corpus text. 43 of 99
articles were affected.

The tree keeps what the serializer discarded: each item's own `marker`, with an
`enumerated` flag separating a paragraph from a sub-item. These tests pin the
rules that rebuild the hierarchy from those fields.

Synthetic documents, deliberately, and each one mirrors a real shape verified
against `gdpr.docling.json`:

  * **Article 2** — the headline case: four paragraphs with (a)-(d) under ¶2.
  * **Article 28** — its heading is labelled `text`, not `section_header`, alone
    among the 99. Matching on label finds 98 articles and folds 28's paragraphs
    into 27. Same quirk the markdown path hit, different serialization.
  * **Article 9** — its ¶1 is a `text` item with the number left inline in the
    string rather than promoted to `marker`. Reading only `marker` drops those
    paragraphs and leaves the numbering with holes.
  * **Article 4** — an unnumbered stem followed by definitions marked `(1)`,
    which are sub-items, not paragraphs.

`tests/test_gdpr_parser.py` covers the markdown path, which is kept because the
two agreeing on 96 of 99 articles is the check that the tree walk dropped
nothing.
"""
import pytest

from src.clause_and_effect import GDPRParser


@pytest.fixture
def parser():
    return GDPRParser()


def _item(index, text, *, label="text", marker=None, enumerated=None):
    item = {
        "self_ref": f"#/texts/{index}",
        "label": label,
        "text": text,
        "children": [],
    }
    if marker is not None:
        item["marker"] = marker
    if enumerated is not None:
        item["enumerated"] = enumerated
    return item


def _document(*specs):
    """A flat body holding `specs` in order, which is the real tree's shape."""
    texts = [_item(i, **spec) if isinstance(spec, dict) else _item(i, spec)
             for i, spec in enumerate(specs)]
    return {
        "body": {"self_ref": "#/body", "label": "unspecified",
                 "children": [{"$ref": t["self_ref"]} for t in texts]},
        "texts": texts,
        "groups": [],
    }


def _heading(number, label="section_header"):
    return {"text": f"Article {number}", "label": label}


def _title(text):
    return {"text": text, "label": "section_header"}


def _paragraph(number, text):
    """A first-order paragraph as docling promotes it: marker "N.", enumerated."""
    return {"text": text, "label": "list_item", "marker": f"{number}.",
            "enumerated": True}


def _sub_item(text):
    """A lettered sub-item: enumerated False, empty marker, letter inline."""
    return {"text": text, "label": "list_item", "marker": "", "enumerated": False}


# --------------------------------------------------------------------------- #
#  Article boundaries                                                          #
# --------------------------------------------------------------------------- #

def test_extracts_articles_with_number_title_content_and_chapter(parser):
    articles = parser.get_articles_from_dictionary(_document(
        _heading(1), _title("Subject-matter and objectives"),
        _paragraph(1, "This Regulation lays down rules."),
    ))

    assert articles == [{
        "number": "1",
        "title": "Subject-matter and objectives",
        "content": "1. This Regulation lays down rules.",
        "chapter": parser._get_chapter_for_article(1),
    }]


def test_heading_labelled_text_is_found(parser):
    """
    Article 28 alone is exported as `label: "text"` rather than
    `section_header`. Keying boundaries off the label finds 98 articles and
    folds Article 28's paragraphs into Article 27 — the same shape as the
    2026-08-01 collapse, in a different serialization.
    """
    articles = parser.get_articles_from_dictionary(_document(
        _heading(27), _title("Representatives"),
        _paragraph(1, "Where Article 3(2) applies."),
        _heading(28, label="text"), _title("Processor"),
        _paragraph(1, "Where processing is to be carried out."),
    ))

    assert [a["number"] for a in articles] == ["27", "28"]
    assert "carried out" not in articles[0]["content"]
    assert articles[1]["title"] == "Processor"


def test_heading_must_be_the_whole_item(parser):
    """
    `^Article\\s+(\\d+)$` anchored at both ends. An inline cross-reference —
    "as referred to in Article 6" — must not open a new article; that is the
    defect that truncated three-quarters of the corpus on the markdown path.
    """
    articles = parser.get_articles_from_dictionary(_document(
        _heading(5), _title("Principles"),
        _paragraph(1, "Personal data shall be processed as in Article 6."),
        _paragraph(2, "The controller shall be responsible."),
    ))

    assert len(articles) == 1
    assert "2. The controller shall be responsible." in articles[0]["content"]


def test_heading_must_not_match_a_leading_citation(parser):
    """
    Anchored at the *end* as well as the start. An item opening "Article 6(1)
    shall apply..." is a provision, not a heading, and a pattern anchored only
    at the start turns it into a spurious Article 6 — swallowing the rest of
    the real article into a record that does not exist.

    The mid-sentence case above cannot catch this: its text does not begin with
    "Article", so `^Article` never matches and the anchor is never tested.
    """
    articles = parser.get_articles_from_dictionary(_document(
        _heading(46), _title("Transfers subject to safeguards"),
        _paragraph(1, "A controller may transfer personal data."),
        {"text": "Article 6(1) point (a) shall apply to such transfers.",
         "label": "text"},
    ))

    assert [a["number"] for a in articles] == ["46"]
    assert "shall apply to such transfers" in articles[0]["content"]


def test_last_article_runs_to_the_end_of_the_document(parser):
    """Article 99's closing provisions and signature block stay with it."""
    articles = parser.get_articles_from_dictionary(_document(
        _heading(99), _title("Entry into force and application"),
        _paragraph(1, "This Regulation shall enter into force."),
        _paragraph(2, "It shall apply from 25 May 2018."),
    ))

    assert articles[-1]["content"].endswith("It shall apply from 25 May 2018.")


def test_a_document_with_no_headings_yields_no_articles(parser):
    assert parser.get_articles_from_dictionary(_document("Some preamble")) == []


# --------------------------------------------------------------------------- #
#  Hierarchy — the defect this path exists to fix                              #
# --------------------------------------------------------------------------- #

def test_article_2_keeps_the_regulations_own_numbering(parser):
    """
    The headline case. Four paragraphs, with (a)-(d) under ¶2. The markdown
    serializer renumbered the sub-items into the surrounding ordered list and
    then restarted, so `3.` denoted both ¶2(a) and ¶3.
    """
    articles = parser.get_articles_from_dictionary(_document(
        _heading(2), _title("Material scope"),
        _paragraph(1, "This Regulation applies to the processing."),
        _paragraph(2, "This Regulation does not apply to the processing:"),
        _sub_item("(a) in the course of an activity outside Union law;"),
        _sub_item("(b) by the Member States when carrying out activities;"),
        _sub_item("(c) by a natural person in a purely personal activity;"),
        _sub_item("(d) by competent authorities for the purposes of prevention."),
        _paragraph(3, "For the processing by the Union institutions."),
        _paragraph(4, "This Regulation shall be without prejudice."),
    ))

    assert articles[0]["content"].splitlines() == [
        "1. This Regulation applies to the processing.",
        "2. This Regulation does not apply to the processing:",
        "(a) in the course of an activity outside Union law;",
        "(b) by the Member States when carrying out activities;",
        "(c) by a natural person in a purely personal activity;",
        "(d) by competent authorities for the purposes of prevention.",
        "3. For the processing by the Union institutions.",
        "4. This Regulation shall be without prejudice.",
    ]


def test_paragraph_numbering_is_contiguous_and_unrepeated(parser):
    """
    The invariant `generate_gdpr_articles._check_invariants` enforces, stated
    here at the source. Against the markdown path Article 2 renders
    `[1, 2, 3, 4, 5, 6, 3, 4]`.
    """
    import re

    articles = parser.get_articles_from_dictionary(_document(
        _heading(2), _title("Material scope"),
        _paragraph(1, "First."), _paragraph(2, "Second:"),
        _sub_item("(a) one;"), _sub_item("(b) two;"),
        _paragraph(3, "Third."), _paragraph(4, "Fourth."),
    ))

    numbers = re.findall(r"^(\d+)\.", articles[0]["content"], re.MULTILINE)
    assert [int(n) for n in numbers] == [1, 2, 3, 4]


def test_inline_paragraph_numbers_are_recovered(parser):
    """
    9 items across articles 9, 18, 35, 57 and 58 are `label: "text"` with the
    number left inside the string rather than promoted to `marker`. Reading
    only `marker` drops them and leaves those articles' numbering with holes —
    which the contiguity invariant would then reject.
    """
    articles = parser.get_articles_from_dictionary(_document(
        _heading(9), _title("Processing of special categories"),
        {"text": "1. Processing of personal data revealing racial origin "
                 "shall be prohibited.", "label": "text"},
        _paragraph(2, "Paragraph 1 shall not apply if one of the following:"),
    ))

    assert articles[0]["content"].splitlines() == [
        "1. Processing of personal data revealing racial origin shall be prohibited.",
        "2. Paragraph 1 shall not apply if one of the following:",
    ]


def test_an_inline_numbered_paragraph_becomes_its_own_unit():
    """
    Asserted on the unit structure, not the rendered string, and that is the
    point: disabling inline recovery leaves `content` **byte-identical**,
    because a unit with no number and no marker renders as bare text and a
    sub-item with an empty marker does too. The rendered output cannot see this
    defect at all.

    What breaks is the hierarchy. Without recovery the paragraph carries no
    number and, since a unit already exists, attaches as a *sub-item* of the
    paragraph above it — so Article 9(2) would be modelled as part of 9(1).
    Only `content` is serialized today, which is why this stayed invisible; the
    nesting is what a hierarchy-aware chunker will read, and what makes
    paragraph-level citation possible.
    """
    units = GDPRParser._build_units([
        _item(0, "First paragraph.", label="list_item", marker="1.",
              enumerated=True),
        _item(1, "2. Second paragraph, left inline by docling.", label="text"),
    ])

    assert [u["number"] for u in units] == ["1", "2"]
    assert units[1]["text"] == "Second paragraph, left inline by docling."
    assert units[0]["sub_items"] == [], "the second paragraph is not a sub-item"


def test_parenthesised_markers_are_sub_items_not_paragraphs(parser):
    """
    Article 4 numbers its 26 definitions `(1)`…`(26)`. Those are sub-items of
    the article's unnumbered stem, not paragraphs — Article 4 has none. Reading
    them as paragraphs is what produced eight fabricated citations.
    """
    articles = parser.get_articles_from_dictionary(_document(
        _heading(4), _title("Definitions"),
        {"text": "For the purposes of this Regulation:", "label": "text"},
        {"text": "'personal data' means any information;", "label": "list_item",
         "marker": "(1)", "enumerated": True},
        {"text": "'processing' means any operation;", "label": "list_item",
         "marker": "(2)", "enumerated": True},
    ))

    content = articles[0]["content"]
    assert content.startswith("For the purposes of this Regulation:")
    assert "(1) 'personal data' means any information;" in content
    assert "1. 'personal data'" not in content, "a definition is not a paragraph"


def test_sub_items_attach_to_an_unnumbered_stem(parser):
    """
    Attachment is to the nearest preceding *unit*, not the nearest preceding
    numbered one. Articles 4 and 50 both open on an unnumbered stem that
    governs everything after it, so a numbered-only rule would strand their
    sub-items with no parent.
    """
    units = GDPRParser._build_units([
        _item(0, "The Commission shall take steps to:", label="text"),
        _item(1, "(a) develop international cooperation mechanisms;",
              label="list_item", marker="", enumerated=False),
        _item(2, "(b) provide international mutual assistance;",
              label="list_item", marker="", enumerated=False),
    ])

    assert len(units) == 1
    assert units[0]["number"] is None
    assert len(units[0]["sub_items"]) == 2


def test_sub_items_attach_to_the_paragraph_above_them(parser):
    units = GDPRParser._build_units([
        _item(0, "First.", label="list_item", marker="1.", enumerated=True),
        _item(1, "Second:", label="list_item", marker="2.", enumerated=True),
        _item(2, "(a) one;", label="list_item", marker="", enumerated=False),
        _item(3, "Third.", label="list_item", marker="3.", enumerated=True),
    ])

    assert [u["number"] for u in units] == ["1", "2", "3"]
    assert [len(u["sub_items"]) for u in units] == [0, 1, 0]


# --------------------------------------------------------------------------- #
#  What is excluded from content                                               #
# --------------------------------------------------------------------------- #

def test_chapter_and_section_scaffolding_is_dropped(parser):
    """
    49 scaffolding items fall *inside* article ranges. Most are
    `section_header` and go by label, but the "Section 1" after Article 59 is
    labelled `text` — the same label inconsistency as the Article 28 heading,
    so the pattern is needed as well as the label.
    """
    articles = parser.get_articles_from_dictionary(_document(
        _heading(59), _title("Activity reports"),
        _paragraph(1, "Each supervisory authority shall draw up a report."),
        {"text": "CHAPTER VII", "label": "section_header"},
        {"text": "Section 1", "label": "text"},
        {"text": "Cooperation", "label": "section_header"},
        _heading(60), _title("Cooperation"),
        _paragraph(1, "The lead supervisory authority shall cooperate."),
    ))

    assert "CHAPTER VII" not in articles[0]["content"]
    assert "Section 1" not in articles[0]["content"]
    assert articles[0]["content"] == (
        "1. Each supervisory authority shall draw up a report."
    )


def test_footnotes_are_dropped(parser):
    """
    Decided 2026-08-06 and flagged for future review: 3 items, in articles 5,
    43 and 79, all citing other instruments. Removing them leaves each
    article's prose byte-identical to the markdown path.
    """
    articles = parser.get_articles_from_dictionary(_document(
        _heading(43), _title("Certification bodies"),
        _paragraph(1, "Certification bodies shall be accredited."),
        {"text": "Regulation (EC) No 765/2008 of the European Parliament.",
         "label": "footnote"},
    ))

    assert "765/2008" not in articles[0]["content"]


def test_the_title_item_is_not_repeated_in_content(parser):
    """The item after the heading is the title; content starts after it."""
    articles = parser.get_articles_from_dictionary(_document(
        _heading(7), _title("Conditions for consent"),
        _paragraph(1, "The controller shall be able to demonstrate consent."),
    ))

    assert articles[0]["title"] == "Conditions for consent"
    assert "Conditions for consent" not in articles[0]["content"]


def test_empty_items_do_not_become_blank_lines(parser):
    articles = parser.get_articles_from_dictionary(_document(
        _heading(1), _title("Subject-matter"),
        _paragraph(1, "Content."),
        {"text": "   ", "label": "text"},
        _paragraph(2, "More content."),
    ))

    assert articles[0]["content"].splitlines() == ["1. Content.", "2. More content."]
"""
Tests for `docling_tree.text_items`, the walk the corpus is rebuilt from.

This module was deliberately split out on 2026-08-06 so it could be tested
against a small synthetic tree rather than the 1.4 MB `gdpr.docling.json`
fixture, and that test did not exist until now. Synthetic trees are the right
shape here: each one isolates a single structural hazard, and the hazards are
what the walk exists to survive — the real export exercises them all at once
and would say only that something broke.

Every case below is a property verified by hand against the real export when
the walk was written:

  * `#/body` is a plain document key, not a collection member, so it cannot be
    resolved through the same lookup as its descendants;
  * `#/pictures/0` is reachable from the body, so a texts-and-groups-only
    lookup raises on a document that is perfectly well-formed;
  * 349 of 1623 text items are `content_layer: "furniture"` — running page
    headers interleaved with the body in reading order. The markdown serializer
    dropped these for us; a tree walk does not, and unfiltered they land in the
    middle of article text.

The `visited` guard is the one property the real document does *not* exercise:
it has no nesting at all, so nothing there would notice its removal.
"""
import pytest

from src.clause_and_effect.parsers.docling_tree import text_items


def _text(index, text, *, label="text", furniture=False, children=(), **extra):
    item = {
        "self_ref": f"#/texts/{index}",
        "label": label,
        "text": text,
        "children": list(children),
        **extra,
    }
    if furniture:
        item["content_layer"] = "furniture"
    return item


def _ref(collection, index):
    return {"$ref": f"#/{collection}/{index}"}


def _document(body_children, *, texts=(), groups=(), pictures=()):
    return {
        "body": {"self_ref": "#/body", "label": "unspecified",
                 "children": list(body_children)},
        "texts": list(texts),
        "groups": list(groups),
        "pictures": list(pictures),
    }


def _texts_of(items):
    return [item["text"] for item in items]


# --------------------------------------------------------------------------- #
#  Reading order                                                               #
# --------------------------------------------------------------------------- #

def test_returns_text_items_in_body_order():
    document = _document(
        [_ref("texts", 0), _ref("texts", 1), _ref("texts", 2)],
        texts=[_text(0, "first"), _text(1, "second"), _text(2, "third")],
    )

    assert _texts_of(text_items(document)) == ["first", "second", "third"]


def test_walk_is_depth_first_so_nesting_keeps_reading_order():
    """
    A group's children belong where the group sits, not after everything else.
    Breadth-first would put "before" and "after" adjacent and move the article
    body to the end.
    """
    document = _document(
        [_ref("texts", 0), _ref("groups", 0), _ref("texts", 3)],
        texts=[_text(0, "before"), _text(1, "inside-1"), _text(2, "inside-2"),
               _text(3, "after")],
        groups=[{"self_ref": "#/groups/0", "label": "list",
                 "children": [_ref("texts", 1), _ref("texts", 2)]}],
    )

    assert _texts_of(text_items(document)) == [
        "before", "inside-1", "inside-2", "after"
    ]


def test_groups_are_traversed_but_not_returned():
    """Only items carrying text are content; groups are containers."""
    document = _document(
        [_ref("groups", 0)],
        texts=[_text(0, "only real content")],
        groups=[{"self_ref": "#/groups/0", "label": "list", "text": "",
                 "children": [_ref("texts", 0)]}],
    )

    assert _texts_of(text_items(document)) == ["only real content"]


def test_pictures_in_the_body_do_not_break_the_walk():
    """
    `#/pictures/0` is reachable from the body of the real export. A lookup
    covering only texts and groups raises "unresolved reference" on a document
    that is entirely well-formed — which is how this was found.
    """
    document = _document(
        [_ref("texts", 0), _ref("pictures", 0), _ref("texts", 1)],
        texts=[_text(0, "before the logo"), _text(1, "after the logo")],
        pictures=[{"self_ref": "#/pictures/0", "label": "picture",
                   "children": []}],
    )

    assert _texts_of(text_items(document)) == ["before the logo",
                                               "after the logo"]


def test_empty_body_yields_nothing():
    assert text_items(_document([])) == []


# --------------------------------------------------------------------------- #
#  Furniture                                                                   #
# --------------------------------------------------------------------------- #

def test_furniture_is_dropped_by_default():
    """
    Running page headers sit *between* body items in reading order, so leaving
    them in does not append noise at the end — it splices "4.5.2016" and
    "Official Journal of the European Union" into the middle of an article.
    """
    document = _document(
        [_ref("texts", 0), _ref("texts", 1), _ref("texts", 2)],
        texts=[
            _text(0, "Article 5 opening"),
            _text(1, "Official Journal of the European Union", furniture=True),
            _text(2, "continues here"),
        ],
    )

    assert _texts_of(text_items(document)) == ["Article 5 opening",
                                               "continues here"]


def test_furniture_can_be_requested():
    document = _document(
        [_ref("texts", 0), _ref("texts", 1)],
        texts=[_text(0, "body"), _text(1, "EN", furniture=True)],
    )

    assert _texts_of(text_items(document, include_furniture=True)) == ["body", "EN"]


def test_items_with_no_content_layer_are_kept():
    """
    Absence must not read as furniture. Most items carry no `content_layer` at
    all, so a check for anything other than an explicit "furniture" would drop
    the entire document.
    """
    document = _document([_ref("texts", 0)], texts=[_text(0, "kept")])
    assert "content_layer" not in document["texts"][0]

    assert _texts_of(text_items(document)) == ["kept"]


# --------------------------------------------------------------------------- #
#  Malformed trees                                                             #
# --------------------------------------------------------------------------- #

def test_missing_body_raises():
    """
    Not an empty result. A document with no body is not the shape this module
    was written against, and returning nothing would look like a document with
    no content — which is exactly how the 2026-08-01 corpus collapse went
    unnoticed.
    """
    with pytest.raises(ValueError, match="no '#/body' root"):
        text_items({"texts": [], "groups": []})


def test_unresolved_reference_raises():
    """Silently skipping a dangling ref would drop content without a trace."""
    document = _document([_ref("texts", 0), _ref("texts", 99)],
                         texts=[_text(0, "present")])

    with pytest.raises(ValueError, match="unresolved reference"):
        text_items(document)


def test_a_node_reachable_twice_is_returned_once():
    """
    The real export is flat — no group inside a group — so nothing in it would
    notice this guard being removed. The schema does not forbid a shared node,
    and duplicated article text would be very hard to spot downstream.
    """
    document = _document(
        [_ref("texts", 0), _ref("groups", 0), _ref("texts", 0)],
        texts=[_text(0, "shared")],
        groups=[{"self_ref": "#/groups/0", "label": "list",
                 "children": [_ref("texts", 0)]}],
    )

    assert _texts_of(text_items(document)) == ["shared"]


def test_a_cycle_terminates():
    """A group holding itself must not recurse forever."""
    document = _document(
        [_ref("groups", 0)],
        texts=[_text(0, "content")],
        groups=[{"self_ref": "#/groups/0", "label": "list",
                 "children": [_ref("texts", 0), _ref("groups", 0)]}],
    )

    assert _texts_of(text_items(document)) == ["content"]


def test_children_of_text_items_are_followed():
    """
    Text items carry a `children` list too. It is empty throughout the real
    export, so a walk that only descended into groups would pass today and
    lose content the first time docling nested anything.
    """
    document = _document(
        [_ref("texts", 0)],
        texts=[_text(0, "parent", children=[_ref("texts", 1)]),
               _text(1, "child")],
    )

    assert _texts_of(text_items(document)) == ["parent", "child"]
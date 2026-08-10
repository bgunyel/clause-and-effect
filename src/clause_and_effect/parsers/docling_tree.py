"""
Traversal helpers for docling's exported document tree (``export_to_dict()``).

The tree is the *unrendered* form of a converted document, and it is the only
form that preserves within-article hierarchy: each list item keeps its own
``marker`` ("1.", "(a)", "(16)") and an ``enumerated`` flag, so a sub-item is
distinguishable from a paragraph. The markdown serializer discards that
distinction — it flattens nested lists into one ordered run and renumbers them
— which is why the corpus is rebuilt from here instead.

Nothing in this module knows anything about the GDPR, or about regulations at
all. It resolves references and yields items in reading order; deciding what an
item *means* is the parser's job.

Shape of the tree, as verified against ``gdpr.docling.json`` on 2026-08-06:

- ``#/body`` is the root. It is not a member of any item collection, so it
  cannot be resolved through the same lookup as its descendants.
- Every other node is referenced as ``{"$ref": "#/texts/12"}`` and lives in one
  of the collections below — including ``#/pictures/0``, which is reachable
  from the body and would break a texts-and-groups-only lookup.
- Only ``texts`` entries carry content; ``groups`` are containers.
- 349 of 1623 text items are ``content_layer: "furniture"`` — running page
  headers such as "Official Journal of the European Union", interleaved with
  the body in reading order. The markdown serializer drops these for us. A
  tree walk does not, and unfiltered they land in the middle of article text.
"""
from typing import Any, Dict, List, Mapping

# Collections a "$ref" can point into. `key_value_items` and `form_items` are
# empty for this document but are part of the schema, so resolving them costs
# nothing and keeps an unresolved-reference error meaningful.
_ITEM_COLLECTIONS = ("texts", "groups", "pictures", "tables", "key_value_items", "form_items")

# Roots that are plain keys on the document rather than collection members.
_ROOT_KEYS = ("body", "furniture")

_FURNITURE_LAYER = "furniture"


def _build_reference_index(document: Mapping[str, Any]) -> Dict[str, Dict[str, Any]]:
    """Map every ``self_ref`` in the document to its item, roots included."""
    index: Dict[str, Dict[str, Any]] = {}
    for collection in _ITEM_COLLECTIONS:
        for item in document.get(collection) or ():
            ref = item.get("self_ref")
            if ref:
                index[ref] = item
    for key in _ROOT_KEYS:
        root = document.get(key)
        if isinstance(root, Mapping) and root.get("self_ref"):
            index[root["self_ref"]] = root
    return index


def text_items(
    document: Mapping[str, Any],
    *,
    include_furniture: bool = False,
) -> List[Dict[str, Any]]:
    """
    Return the document's text items in reading order.

    Walks depth-first from ``#/body`` following each node's ``children``, which
    is what puts items in the order they appear on the page. Groups and
    pictures are traversed but not returned — only items carrying text.

    Args:
        document: a ``DoclingDocument`` as produced by ``export_to_dict()``.
        include_furniture: keep running page headers and other furniture-layer
            items. Off by default; see the module docstring for why they are a
            hazard rather than a nuisance.

    Raises:
        ValueError: if the document has no ``#/body`` root, or a ``$ref``
            points at something the document does not contain. Both mean the
            tree is not the shape this module was written against, and
            continuing would silently drop content.
    """
    index = _build_reference_index(document)
    text_refs = {
        item["self_ref"]
        for item in document.get("texts") or ()
        if item.get("self_ref")
    }

    body = document.get("body")
    if not isinstance(body, Mapping):
        raise ValueError("docling document has no '#/body' root")

    items: List[Dict[str, Any]] = []
    # A node reachable by two paths would otherwise be emitted twice, and a
    # cycle would recurse forever. Neither occurs in this document — the tree
    # is flat, with no group inside a group — but neither is guaranteed by the
    # schema, and duplicated article text would be hard to spot downstream.
    visited: set[str] = set()

    def visit(node: Mapping[str, Any]) -> None:
        for child in node.get("children") or ():
            ref = child.get("$ref") if isinstance(child, Mapping) else None
            if ref is None or ref in visited:
                continue
            visited.add(ref)
            item = index.get(ref)
            if item is None:
                raise ValueError(f"unresolved reference in docling document tree: {ref!r}")
            if ref in text_refs:
                if include_furniture or item.get("content_layer") != _FURNITURE_LAYER:
                    items.append(item)
            visit(item)

    visit(body)
    return items
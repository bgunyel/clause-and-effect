"""
Tests for `generate_chunks._check_chunks`, the gate before a snapshot is written.

The checks run here rather than at index time on purpose: a defect caught after
embedding has already cost money and left a collection to clean up. That makes
this the cheapest place in the pipeline to fail, and the one where a check that
silently passes is most expensive — a bad chunk set written to `data/chunks/`
becomes a committed artifact and, once indexed, the thing every eval number is
measured against.

Every case below is a defect the pipeline has actually produced or can produce:
`generate_gdpr_articles.py` printed `✅ Wrote 1 articles` over a collapsed corpus
on 2026-08-01, and Article 4 still yields one 8,655-char chunk today.
"""
from typing import Any, Dict, List

import pytest

from src.clause_and_effect.parsers import Chunk
from src.scripts.generate_chunks import _check_chunks


def _chunk(chunk_id: str, article: str, text: str = "some text") -> Chunk:
    return Chunk(id=chunk_id, text=text, metadata={"article_number": article})


def _articles(*numbers: str) -> List[Dict[str, Any]]:
    return [{"number": n} for n in numbers]


def test_a_valid_chunk_set_has_no_problems():
    chunks = [_chunk("gdpr_article_1", "1"), _chunk("gdpr_article_2", "2")]

    assert _check_chunks(chunks, _articles("1", "2")) == []


def test_an_article_split_into_several_chunks_is_valid():
    """Coverage is per article, not per chunk — most articles produce several."""
    chunks = [
        _chunk("gdpr_article_1_para_1", "1"),
        _chunk("gdpr_article_1_para_2", "1"),
        _chunk("gdpr_article_2", "2"),
    ]

    assert _check_chunks(chunks, _articles("1", "2")) == []


def test_empty_chunk_set_is_rejected():
    problems = _check_chunks([], [])

    assert any("no chunks" in p for p in problems)


def test_duplicate_chunk_ids_are_rejected():
    """
    Qdrant's upsert overwrites a repeated point ID silently, so duplicates
    collapse onto one point. `index_chunks` raises on this too, but by then the
    embeddings are already paid for.
    """
    chunks = [
        _chunk("gdpr_article_1", "1"),
        _chunk("gdpr_article_1", "1"),
        _chunk("gdpr_article_2", "2"),
    ]

    problems = _check_chunks(chunks, _articles("1", "2"))

    assert any("duplicate" in p and "gdpr_article_1" in p for p in problems)


@pytest.mark.parametrize("blank", ["", "   ", "\n\t "])
def test_whitespace_only_chunks_are_rejected(blank):
    """
    Not just empty strings. A chunk of pure whitespace embeds to a vector that
    is retrievable and meaningless, and would pass a `len(text)` check.
    """
    chunks = [_chunk("gdpr_article_1", "1", blank), _chunk("gdpr_article_2", "2")]

    problems = _check_chunks(chunks, _articles("1", "2"))

    assert any("empty text" in p and "gdpr_article_1" in p for p in problems)


def test_an_article_producing_no_chunks_is_rejected():
    """
    Unreachable by retrieval, and invisible everywhere downstream: the chunk
    count is self-consistent, the hash is valid, and the collection matches the
    snapshot exactly. Nothing but this check compares against the corpus.
    """
    chunks = [_chunk("gdpr_article_1", "1")]

    problems = _check_chunks(chunks, _articles("1", "2", "3"))

    assert any("produced no chunks" in p and "2" in p and "3" in p for p in problems)


def test_missing_articles_are_reported_in_numeric_order():
    """`['2', '10']`, not `['10', '2']` — the ids are strings."""
    chunks = [_chunk("gdpr_article_1", "1")]

    problems = _check_chunks(chunks, _articles("1", "10", "2"))

    missing = next(p for p in problems if "produced no chunks" in p)
    assert missing.index("'2'") < missing.index("'10'")


def test_all_problems_are_reported_together():
    """
    One run should surface every defect, not the first. A gate that reports one
    problem at a time turns a single regeneration into several.
    """
    chunks = [
        _chunk("gdpr_article_1", "1", ""),
        _chunk("gdpr_article_1", "1"),
    ]

    problems = _check_chunks(chunks, _articles("1", "2"))

    assert len(problems) == 3, problems
    assert any("duplicate" in p for p in problems)
    assert any("empty text" in p for p in problems)
    assert any("produced no chunks" in p for p in problems)


def test_article_coverage_compares_against_the_corpus_not_the_chunks():
    """
    A chunk claiming an article the corpus does not contain is not flagged here
    — coverage runs corpus-first. Recorded as the boundary of this check rather
    than asserted as desirable: it is the direction that matters, since a
    fabricated article number would still be caught by the snapshot diff.
    """
    chunks = [_chunk("gdpr_article_1", "1"), _chunk("gdpr_article_400", "400")]

    assert _check_chunks(chunks, _articles("1")) == []
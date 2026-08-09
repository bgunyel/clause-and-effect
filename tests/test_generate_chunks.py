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

from src.clause_and_effect.chunking import Chunk, ChunkMetadata, GDPR, Regulation
from src.scripts.generate_chunks import (
    _article_metadata,
    _check_articles,
    _check_chunks,
)


# Everything `_check_chunks` looks at is `id`, `text` and `article_number`; the
# rest of the schema is required but plays no part, so it is filled once here
# rather than repeated at each call and left dull on purpose.
_METADATA = {
    "article_title": "Subject-matter and objectives",
    "chapter": "1",
    "chapter_title": "General provisions",
    "regulation": "GDPR",
    "jurisdiction": "EU",
    "effective_date": "2018-05-25",
    "chunk_type": "article",
}


def _chunk(chunk_id: str, article: str, text: str = "some text") -> Chunk:
    return Chunk(
        id=chunk_id,
        text=text,
        metadata=ChunkMetadata(article_number=article, **_METADATA),
    )


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
    collapse onto one point. `embed_and_upsert_chunks` raises on this too, but by
    then the embeddings are already paid for.
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

# --------------------------------------------------------------------------- #
#  _check_articles — the gate before chunking is attempted at all.            #
#                                                                             #
#  Separate from `_check_chunks` because these are faults that stop chunks     #
#  being produced rather than faults *in* them. An unknown chapter used to     #
#  surface as a bare KeyError from inside the chunking loop, which named       #
#  neither the article nor the chapter and reported none of the others.        #
# --------------------------------------------------------------------------- #

def _corpus(*articles: Dict[str, Any]) -> List[Dict[str, Any]]:
    return list(articles)


def _article(number: str = "1", **overrides: Any) -> Dict[str, Any]:
    return {"number": number, "title": "T", "content": "c", "chapter": "1", **overrides}


def test_a_valid_corpus_has_no_problems():
    assert _check_articles(_corpus(_article("1"), _article("2")), GDPR) == []


def test_a_chapter_the_regulation_does_not_declare_is_rejected():
    """
    `chapter_title` is looked up from the regulation, so an undeclared chapter
    has no title to find. Reported here rather than raised from the loop: the
    lookup is what used to fail, with a `KeyError` naming only the missing key.
    """
    problems = _check_articles(_corpus(_article("1", chapter="99")), GDPR)

    assert len(problems) == 1
    assert "99" in problems[0] and "GDPR" in problems[0]


def test_a_missing_required_key_is_rejected():
    problems = _check_articles(_corpus({"number": "7", "chapter": "1"}), GDPR)

    assert len(problems) == 1
    assert "missing required keys" in problems[0] and "7" in problems[0]


def test_every_problem_is_reported_not_just_the_first():
    """
    The point of collecting rather than raising: one run should tell you
    everything that is wrong with the corpus, not the first thing.
    """
    problems = _check_articles(
        _corpus(_article("1", chapter="99"), {"number": "2", "chapter": "1"}), GDPR
    )

    assert len(problems) == 2
    assert any("not declared" in p for p in problems)
    assert any("missing required keys" in p for p in problems)


def test_the_same_unknown_chapter_is_reported_once():
    """Per distinct chapter, not per article — 99 articles in one bad chapter
    should not print 99 lines."""
    corpus = _corpus(*(_article(str(n), chapter="99") for n in range(1, 6)))

    problems = _check_articles(corpus, GDPR)

    assert len(problems) == 1


# --------------------------------------------------------------------------- #
#  _article_metadata — the corpus schema's only reader.                       #
# --------------------------------------------------------------------------- #

def test_article_metadata_maps_the_corpus_record():
    metadata = _article_metadata(
        {"number": "12", "title": "Transparency", "content": "…", "chapter": "3"}, GDPR
    )

    assert metadata.article_number == "12"
    assert metadata.article_title == "Transparency"
    assert metadata.chapter == "3"


def test_article_metadata_takes_chapter_title_from_the_regulation():
    """
    The corpus carries no `chapter_title`, so it is looked up. That is what
    makes an article claiming a title no chapter has unreachable, rather than
    something a corpus generator could get wrong independently.
    """
    metadata = _article_metadata(_article("5", chapter="3"), GDPR)

    assert metadata.chapter_title == GDPR.chapter_titles["3"]
    assert metadata.chapter_title == "Rights of the data subject"


def test_article_metadata_follows_the_regulation_it_is_given():
    """Not GDPR-specific: the lookup reads whichever regulation is passed."""
    other = Regulation(name="OTHER", jurisdiction="XX", effective_date="2000-01-01",
                       chapter_titles={"1": "Only chapter"})

    metadata = _article_metadata(_article("1", chapter="1"), other)

    assert metadata.chapter_title == "Only chapter"

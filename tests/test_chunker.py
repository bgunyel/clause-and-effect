"""
Tests for `Chunker` — the derivation that keys every stored vector.

Held to the eval standard of `docs/evaluation-plan.md` §1 rather than the
product one. Three properties carry that weight.

**The chunk ID.** `_create_chunk_id` derives every Qdrant point ID, so its
output *is* the identity of a stored vector. Changing its form does not corrupt
a point, it creates a parallel set: the next index run writes new points beside
the old ones instead of updating them, and the collection ends up holding two
corpora with nothing to say so. The method's own docstring says "never change
the derivation" — nothing enforced that until this file. The strongest check
available is the archive: the 368 IDs in
`chunks_2026-08-07_081627_a231f919.jsonl` were produced by the code this
`Chunker` was extracted out of, so reproducing them *in order* is what proves
the extraction preserved behaviour.

**The citation.** A paragraph chunk announces itself as `Article 12(4):`, and
the golden set grades answers against quotes carried by those headers. A
paragraph number that is off by one does not look wrong — it looks like a
correct citation of a different provision. Three places encode that number (the
ID suffix, the header, and `paragraph_number`) and the tests below pin all
three together, because two of them agreeing is not evidence.

**The regulation constants.** `regulation` reaches the payload and, lowercased,
prefixes the ID. That those two cannot disagree is the entire reason
`Regulation` exists, so it is asserted rather than assumed.

The `xfail(strict=True)` tests state behaviour this chunker does *not* have.
They are the paragraph-splitting defect described in `docs/todo.md`, which the
hierarchy-aware chunker is meant to fix; written now so that fixing it
announces itself instead of being noticed a snapshot later.
"""
import json
import re
from pathlib import Path

import pytest
from pydantic import ValidationError

from src.clause_and_effect.chunking import (
    ArticleMetadata,
    Chunk,
    Chunker,
    GDPR,
    Regulation,
)


# --------------------------------------------------------------------------- #
#  Fixtures and content builders.                                             #
# --------------------------------------------------------------------------- #

# A second regulation, so that anything derived from `Regulation` can be shown
# to *follow* it rather than to be a GDPR-shaped constant that happens to match.
CCPA = Regulation(
    name="CCPA",
    jurisdiction="US-CA",
    effective_date="2020-01-01",
    chapter_titles={"1": "General duties", "2": "Consumer rights"},
)


@pytest.fixture
def chunker():
    return Chunker(GDPR)


def _meta(
    article_number: str = "5",
    article_title: str = "Principles relating to processing",
    chapter: str = "2",
    chapter_title: str = "Principles",
) -> ArticleMetadata:
    return ArticleMetadata(
        article_number=article_number,
        article_title=article_title,
        chapter=chapter,
        chapter_title=chapter_title,
    )


def _numbered(length: int) -> str:
    """
    Two numbered paragraphs, padded with filler to *exactly* `length` chars.

    The length has to be exact: the article/paragraph branch turns on
    `len(content) < 1000`, and a test that cannot place content on a chosen side
    of that boundary cannot tell `<` from `<=`. The filler carries no digits, so
    padding never changes how many paragraphs the split finds.
    """
    body = "1. First paragraph text. 2. Second paragraph text. "
    filler = ("filler " * (length // 7 + 2))[: length - len(body)]
    content = body + filler
    assert len(content) == length
    return content


# --------------------------------------------------------------------------- #
#  Chunk ID derivation — the identity of every stored vector.                 #
# --------------------------------------------------------------------------- #

def test_article_chunk_id_form(chunker):
    chunks = chunker.run("Short content.", _meta(article_number="94"))
    assert [c.id for c in chunks] == ["gdpr_article_94"]


def test_paragraph_chunk_id_form(chunker):
    chunks = chunker.run(_numbered(1200), _meta(article_number="12"))
    assert [c.id for c in chunks] == [
        "gdpr_article_12_para_1",
        "gdpr_article_12_para_2",
    ]


def test_chunk_id_prefix_is_the_regulation_name_lowercased():
    """
    The prefix follows `Regulation.name` rather than being a baked-in literal.

    Stated in `regulation.py`: changing a regulation's name re-keys its whole
    corpus. That is only true if the name is what the ID reads from.
    """
    chunks = Chunker(CCPA).run("Short content.", _meta(article_number="7"))
    assert chunks[0].id == "ccpa_article_7"


def test_chunk_id_prefix_and_payload_regulation_cannot_disagree():
    """
    The invariant `Regulation` was introduced for.

    An ID reading `gdpr_…` beside a payload naming another regulation is meant
    to be unreachable, because both read the same field. Checked on both
    branches, since each builds its metadata separately.
    """
    for regulation in (GDPR, CCPA):
        chunker = Chunker(regulation)
        produced = chunker.run("Short content.", _meta()) + chunker.run(
            _numbered(1200), _meta()
        )
        for chunk in produced:
            assert chunk.id.startswith(f"{chunk.metadata.regulation.lower()}_")


def test_regulation_cannot_be_mutated_after_construction():
    """
    `Regulation` is frozen, which is what keeps the invariant above true for the
    life of a `Chunker` rather than only at the moment it is built.
    """
    with pytest.raises(ValidationError):
        GDPR.name = "CCPA"


def test_chapter_titles_cannot_be_mutated_in_place():
    """
    `frozen=True` blocks reassigning an attribute, not mutating what it points
    at — a plain `dict` here left `GDPR.chapter_titles["1"] = …` working, and
    every chunk built afterwards would have carried the change with nothing to
    catch it. The field is wrapped read-only for that reason.
    """
    with pytest.raises(TypeError):
        GDPR.chapter_titles["1"] = "Rewritten"
    with pytest.raises(TypeError):
        del GDPR.chapter_titles["1"]


def test_chapter_titles_are_insulated_from_the_caller_s_dict():
    """
    A model built from a caller's dict must not change when that dict later
    does. Pydantic happens to copy before the validator runs, so this passes
    with or without the explicit `dict()` in `_freeze_chapter_titles` — it pins
    the *guarantee*, not the layer that currently provides it, which is why the
    copy is kept even though it is redundant today.
    """
    source = {"1": "Original"}
    regulation = Regulation(
        name="TEST",
        jurisdiction="XX",
        effective_date="2020-01-01",
        chapter_titles=source,
    )
    source["1"] = "Mutated"
    assert regulation.chapter_titles["1"] == "Original"


def test_regulation_stays_hashable():
    """
    A mapping field makes pydantic's generated `__hash__` raise `unhashable
    type: 'dict'` at runtime, which would leave a model declared immutable
    unusable as a dict key or set member. Equality and hashing must agree.
    """
    twin = Regulation(
        name=GDPR.name,
        jurisdiction=GDPR.jurisdiction,
        effective_date=GDPR.effective_date,
        chapter_titles=dict(GDPR.chapter_titles),
    )
    assert twin == GDPR
    assert hash(twin) == hash(GDPR)
    assert len({GDPR, twin, CCPA}) == 2


def test_regulation_dumps_chapter_titles_as_a_plain_dict():
    """
    Immutability is a property of the live object, not of serialized output —
    and without an explicit serializer pydantic warns that a `mappingproxy` is
    not the `dict[str, str]` it expected.
    """
    dumped = GDPR.model_dump()["chapter_titles"]
    assert type(dumped) is dict
    assert dumped == dict(GDPR.chapter_titles)


# --------------------------------------------------------------------------- #
#  The archive oracle.                                                        #
#                                                                             #
#  `a231f919` is the snapshot the live `compliance_docs` collection was built  #
#  from. Reproducing it exactly is what allows the chunker to be moved,        #
#  retyped and re-homed without silently re-keying 368 points.                 #
# --------------------------------------------------------------------------- #

_REPO_ROOT = Path(__file__).resolve().parent.parent
_ARCHIVE = _REPO_ROOT / "data" / "chunks" / "chunks_2026-08-07_081627_a231f919.jsonl"
_MANIFEST = (
    _REPO_ROOT / "data" / "chunks" / "chunks_2026-08-07_081627_a231f919.manifest.json"
)
_CORPUS = _REPO_ROOT / "data" / "regulations" / "gdpr_articles.json"


@pytest.fixture(scope="module")
def recorded():
    """
    The archived chunks, read as raw JSON rather than through `read_snapshot`.

    Deliberate: `read_snapshot` cannot load this file any more — pydantic drops
    the `topics` and `paragraph` keys it no longer knows, and the re-hash then
    reports tampering. That is an open item in its own right; routing the oracle
    through it would make this file fail for an unrelated reason.
    """
    for path in (_ARCHIVE, _CORPUS, _MANIFEST):
        if not path.exists():
            pytest.skip(f"baseline artifact not available at {path}")
    return [json.loads(line) for line in _ARCHIVE.read_text(encoding="utf-8").splitlines()]


@pytest.fixture(scope="module")
def corpus():
    if not _CORPUS.exists():
        pytest.skip(f"corpus not available at {_CORPUS}")
    return json.loads(_CORPUS.read_text(encoding="utf-8"))


@pytest.fixture(scope="module")
def produced(recorded, corpus):
    """
    The whole corpus re-chunked by the current `Chunker`.

    `chapter_title` comes from the archive rather than the corpus because
    `gdpr_articles.json` does not carry one, and the wiring that will supply it
    is still open. Taking it from the archive feeds back exactly the value the
    recorded chunks were built with, which is what keeps this a comparison of
    the chunker rather than of a guess about the wiring.
    """
    chapter_titles = {
        row["metadata"]["article_number"]: row["metadata"]["chapter_title"]
        for row in recorded
    }
    chunker = Chunker(GDPR)
    chunks = []
    for article in corpus:
        chunks.extend(
            chunker.run(
                article["content"],
                _meta(
                    article_number=article["number"],
                    article_title=article["title"],
                    chapter=article["chapter"],
                    chapter_title=chapter_titles[article["number"]],
                ),
            )
        )
    return chunks


def test_baseline_corpus_is_the_one_the_snapshot_records(corpus):
    """
    Guards the oracle itself: comparing against `a231f919` means nothing if the
    corpus on disk is no longer the corpus it was built from.
    """
    import hashlib

    manifest = json.loads(_MANIFEST.read_text(encoding="utf-8"))
    assert manifest["source"]["article_count"] == len(corpus)
    assert (
        hashlib.sha256(_CORPUS.read_bytes()).hexdigest()
        == manifest["source"]["sha256"]
    )


def test_reproduces_every_recorded_chunk_id_in_order(recorded, produced):
    """
    Order-identical, not merely set-identical.

    Set equality would pass while the chunks were emitted in a different
    sequence, which is not a property this needs but is a cheap signal that
    something moved. The IDs themselves are the load-bearing half: they are the
    Qdrant point IDs of the live collection.
    """
    assert [c.id for c in produced] == [row["id"] for row in recorded]


def test_reproduces_every_recorded_chunk_text_byte_for_byte(recorded, produced):
    """
    Text drives the embeddings, so a change here re-embeds the corpus even when
    every ID holds still — a cost and a baseline break that would otherwise be
    invisible until the vectors moved.
    """
    differing = [
        row["id"]
        for row, chunk in zip(recorded, produced)
        if row["text"] != chunk.text
    ]
    assert differing == []


def _recorded_keys(recorded) -> set:
    """
    Every metadata key the archive uses anywhere.

    Taken across all rows rather than from the first: `paragraph` appears on the
    330 paragraph chunks and not on the 38 article chunks, so sampling row zero
    would miss it and make the diff below look smaller than it is.
    """
    return {key for row in recorded for key in row["metadata"]}


def test_metadata_differs_from_the_archive_only_as_the_retyping_intended(
    recorded, produced
):
    """
    The digest *will* move at the next snapshot, and this pins why: `topics` was
    dropped as a toy and `paragraph` was renamed `paragraph_number`. Anything
    else in this diff is an unintended payload change — one that moves the
    digest, re-embeds nothing, and stales every point for a reason nobody wrote
    down.
    """
    recorded_keys = _recorded_keys(recorded)
    produced_keys = set(produced[0].metadata.model_dump())
    assert recorded_keys - produced_keys == {"topics", "paragraph"}
    assert produced_keys - recorded_keys == {"paragraph_number"}


def test_paragraph_was_renamed_not_renumbered(recorded, produced):
    """
    `paragraph` -> `paragraph_number` has to be a rename of the key alone. If the
    values moved too, every paragraph citation in the index would shift while the
    diff still looked like a tidy-up.
    """
    offenders = [
        row["id"]
        for row, chunk in zip(recorded, produced)
        if row["metadata"].get("paragraph") != chunk.metadata.paragraph_number
    ]
    assert offenders == []


def test_shared_metadata_fields_are_unchanged(recorded, produced):
    """Every field the archive and the new model have in common still agrees."""
    shared = _recorded_keys(recorded) & set(produced[0].metadata.model_dump())
    offenders = [
        row["id"]
        for row, chunk in zip(recorded, produced)
        if {k: row["metadata"].get(k) for k in shared}
        != {k: chunk.metadata.model_dump()[k] for k in shared}
    ]
    assert offenders == []


# --------------------------------------------------------------------------- #
#  The article / paragraph branch and its boundary.                           #
# --------------------------------------------------------------------------- #

def test_short_article_becomes_a_single_article_chunk(chunker):
    chunks = chunker.run("1. A short provision.", _meta(article_number="94"))
    assert len(chunks) == 1
    assert isinstance(chunks[0], Chunk)
    assert chunks[0].metadata.chunk_type == "article"


def test_long_article_splits_into_paragraph_chunks(chunker):
    chunks = chunker.run(_numbered(1200), _meta())
    assert len(chunks) == 2
    assert all(c.metadata.chunk_type == "paragraph" for c in chunks)


def test_content_of_999_chars_stays_one_article_chunk(chunker):
    """The boundary is `< 1000`, so 999 is the last length that stays whole."""
    chunks = chunker.run(_numbered(999), _meta())
    assert [c.metadata.chunk_type for c in chunks] == ["article"]


def test_content_of_exactly_1000_chars_splits(chunker):
    """
    The other side of the same comparison. Pinned separately from the 999 case
    because only the pair distinguishes `<` from `<=`; either alone survives the
    off-by-one.
    """
    chunks = chunker.run(_numbered(1000), _meta())
    assert [c.metadata.chunk_type for c in chunks] == ["paragraph", "paragraph"]


def test_short_article_keeps_its_content_whole(chunker):
    """
    An article chunk is the article, numbered paragraphs and all — the split
    must not run on the short branch.
    """
    content = "1. First provision. 2. Second provision."
    chunks = chunker.run(content, _meta())
    assert chunks[0].text.endswith(content)


def test_empty_content_still_produces_a_header_only_chunk(chunker):
    """
    Characterizing a gap rather than endorsing it: empty content takes the short
    branch and yields one chunk whose text is only the header. That chunk is not
    empty, so `generate_chunks._check_chunks`'s empty-text guard does not catch
    it — the article-coverage guard is what would, and only because the article
    still appears in the chunk set.
    """
    chunks = chunker.run("", _meta(article_number="94", article_title="Repeal"))
    assert len(chunks) == 1
    assert chunks[0].text == "Article 94: Repeal\n\n"


def test_long_whitespace_only_content_produces_no_chunks(chunker):
    """
    The one input that makes an article vanish. `_split_into_paragraphs` drops
    every empty segment, so the loop never runs and `run` returns `[]` with no
    error. Pinned because it means the "article produced no chunks" check in
    `generate_chunks` is load-bearing rather than defensive.
    """
    assert chunker.run(" " * 1200, _meta()) == []


# --------------------------------------------------------------------------- #
#  Citation form — what a retrieved chunk claims about where it came from.    #
# --------------------------------------------------------------------------- #

def test_article_chunk_header_form(chunker):
    chunks = chunker.run(
        "Body text.", _meta(article_number="94", article_title="Repeal of Directive")
    )
    assert chunks[0].text == "Article 94: Repeal of Directive\n\nBody text."


def test_paragraph_chunk_header_cites_the_form_the_regulation_uses(chunker):
    """
    `Article N(M):`, not `Article N paragraph M` or `Article N.M` — this is the
    citation form GDPR itself uses, and the form the golden set was written
    against.
    """
    chunks = chunker.run(_numbered(1200), _meta(article_number="12", article_title="Transparency"))
    assert chunks[0].text.startswith("Article 12(1): Transparency\n\n")
    assert chunks[1].text.startswith("Article 12(2): Transparency\n\n")


def test_paragraph_body_is_the_split_text_verbatim(chunker):
    """
    The header is a prefix, not a rewrite: everything after the blank line is
    what the split produced, so a quote grounded against the source still
    matches the indexed text.
    """
    content = _numbered(1200)
    chunker_parts = chunker._split_into_paragraphs(content)
    chunks = chunker.run(content, _meta())
    for part, chunk in zip(chunker_parts, chunks):
        assert chunk.text.split("\n\n", 1)[1] == part


def test_paragraph_number_agrees_across_id_header_and_metadata(chunker):
    """
    The same number is written in three places by three separate expressions.
    Two of them agreeing proves nothing; this asserts all three at once, which
    is the only form that catches one of them drifting.
    """
    chunks = chunker.run(_numbered(2000), _meta(article_number="12"))
    assert len(chunks) >= 2
    for position, chunk in enumerate(chunks, start=1):
        assert chunk.metadata.paragraph_number == str(position)
        assert chunk.id == f"gdpr_article_12_para_{position}"
        assert chunk.text.startswith(f"Article 12({position}):")


def test_paragraph_numbering_is_one_based(chunker):
    """`Article 12(0)` is not a provision; the enumerate start is load-bearing."""
    chunks = chunker.run(_numbered(1200), _meta(article_number="12"))
    assert chunks[0].metadata.paragraph_number == "1"
    assert "(0)" not in chunks[0].text


# --------------------------------------------------------------------------- #
#  Metadata.                                                                  #
# --------------------------------------------------------------------------- #

def test_article_chunk_carries_no_paragraph_number(chunker):
    """
    An article chunk covers the whole article, so claiming a paragraph would be
    a false citation rather than a missing one.
    """
    chunks = chunker.run("Short content.", _meta())
    assert chunks[0].metadata.chunk_type == "article"
    assert chunks[0].metadata.paragraph_number is None


def test_article_level_fields_reach_every_chunk(chunker):
    """
    The article half of the metadata is carried through unchanged on both
    branches — it is what the retrieval filters key off.
    """
    metadata = _meta(
        article_number="12",
        article_title="Transparent information",
        chapter="3",
        chapter_title="Rights of the data subject",
    )
    for content in ("Short content.", _numbered(1200)):
        for chunk in chunker.run(content, metadata):
            assert chunk.metadata.article_number == "12"
            assert chunk.metadata.article_title == "Transparent information"
            assert chunk.metadata.chapter == "3"
            assert chunk.metadata.chapter_title == "Rights of the data subject"


def test_regulation_level_fields_come_from_the_regulation(chunker):
    """
    Not from the article record. These three are fixed for the corpus, which is
    what makes a chunk claiming a different jurisdiction than its neighbours an
    unreachable state rather than a bug waiting to happen.
    """
    for content in ("Short content.", _numbered(1200)):
        for chunk in chunker.run(content, _meta()):
            assert chunk.metadata.regulation == GDPR.name
            assert chunk.metadata.jurisdiction == GDPR.jurisdiction
            assert chunk.metadata.effective_date == GDPR.effective_date


def test_effective_date_is_the_date_of_application(chunker):
    """
    2018-05-25, not 2016-05-24. GDPR entered into force on the earlier date and
    became applicable on the later one; compliance is measured against the
    later. The field name does not make the distinction, so it is pinned here.
    """
    chunks = chunker.run("Short content.", _meta())
    assert chunks[0].metadata.effective_date == "2018-05-25"


# --------------------------------------------------------------------------- #
#  Paragraph splitting.                                                       #
# --------------------------------------------------------------------------- #

def test_splits_on_numbered_markers(chunker):
    content = "1. First provision.\n2. Second provision.\n3. Third provision."
    assert chunker._split_into_paragraphs(content) == [
        "First provision.",
        "Second provision.",
        "Third provision.",
    ]


def test_leading_text_before_the_first_marker_is_kept(chunker):
    """
    The unnumbered stem that governs the paragraphs below it (Articles 4 and 50
    both open on one) must not be dropped — it carries the sentence the numbered
    items complete.
    """
    content = "For the purposes of this Regulation:\n1. First.\n2. Second."
    assert chunker._split_into_paragraphs(content)[0] == (
        "For the purposes of this Regulation:"
    )


def test_empty_segments_are_dropped(chunker):
    """Consecutive markers must not produce an empty chunk between them."""
    assert chunker._split_into_paragraphs("1. \n2. Real text.") == ["Real text."]


def test_unnumbered_content_stays_one_segment(chunker):
    content = "A single provision with no numbering at all."
    assert chunker._split_into_paragraphs(content) == [content]


# --------------------------------------------------------------------------- #
#  The paragraph-splitting defect.                                            #
#                                                                             #
#  `_split_into_paragraphs` re-derives paragraph boundaries from a flat        #
#  string, where "22." closing a cross-reference is indistinguishable from     #
#  "2." opening a paragraph. This is the same ambiguity `_ARTICLE_HEADER` had  #
#  to be line-anchored to avoid, one level down, and the reason                #
#  `get_articles_from_dictionary` reads the document tree instead.             #
#                                                                             #
#  These assert the behaviour the hierarchy-aware chunker is meant to have.    #
#  They are strict xfails, so fixing it turns them into failures that ask to   #
#  be un-marked rather than passing silently.                                  #
# --------------------------------------------------------------------------- #

@pytest.mark.xfail(
    strict=True,
    reason="`\\d+\\.\\s+` matches a cross-reference; needs the hierarchy-aware chunker",
)
def test_cross_reference_number_does_not_open_a_paragraph(chunker):
    """
    Article 12(2)'s real text, which the split cuts in half at "Articles 15 to
    22. In the cases…" — leaving one chunk truncated mid-phrase and shifting
    every paragraph number after it by one.
    """
    content = (
        "1. The first provision.\n"
        "2. The controller shall facilitate the exercise of data subject rights "
        "under Articles 15 to 22. In the cases referred to in Article 11(2), the "
        "controller shall not refuse to act.\n"
        "3. The third provision.\n"
    )
    parts = chunker._split_into_paragraphs(content)
    assert len(parts) == 3
    assert parts[1].endswith("shall not refuse to act.")


@pytest.mark.xfail(
    strict=True,
    reason="cross-reference splits mis-number 10 articles; needs the hierarchy-aware chunker",
)
def test_paragraph_count_matches_the_regulations_own_numbering(corpus, chunker):
    """
    The corpus-wide statement of the same defect, and the one that says how much
    of the live index is affected.

    Every long article with numbered paragraphs should produce exactly as many
    paragraph chunks as it has line-anchored markers. Where it produces more,
    every citation after the spurious split names the wrong provision.
    """
    marker = re.compile(r"(?m)^(\d+)\.\s")
    offenders = []
    for article in corpus:
        if len(article["content"]) < 1000:
            continue
        markers = marker.findall(article["content"])
        if not markers:
            continue
        produced = len(chunker._split_into_paragraphs(article["content"]))
        if produced != len(markers):
            offenders.append((article["number"], produced, len(markers)))
    assert offenders == []


@pytest.mark.xfail(
    strict=True,
    reason="the delimiter is consumed, deleting the number; needs the hierarchy-aware chunker",
)
def test_a_cross_reference_number_is_not_deleted_from_the_text(chunker):
    """
    The quieter half of the same defect, and the one a count check cannot see.

    When the matched number is the last thing on its line, `\\s+` swallows the
    newline too, so the delimiter spans right up to the next real marker and the
    empty segment between them is dropped. The paragraph count is therefore
    correct — and the sentence has silently lost its citation, ending "in
    accordance with Article" with nothing after it.
    """
    content = (
        "1. First provision.\n"
        "2. The controller shall act in accordance with Article 98.\n"
        "3. Third provision.\n"
    )
    parts = chunker._split_into_paragraphs(content)
    assert len(parts) == 3
    assert parts[1] == "The controller shall act in accordance with Article 98."


@pytest.mark.xfail(
    strict=True,
    reason="26 articles lose characters to the split; needs the hierarchy-aware chunker",
)
def test_splitting_an_article_never_loses_characters(corpus, chunker):
    """
    The invariant both halves of the defect violate, and the one worth keeping
    after the fix: chunking *partitions* an article, it does not edit it.

    Everything in the source except its own paragraph markers must survive into
    some chunk. Compared with whitespace removed, since the split legitimately
    trims — what is being asserted is that no *characters of the regulation* go
    missing. This is the check that catches the silent deletions; the count
    check above only catches the splits that also move a number.
    """
    marker = re.compile(r"(?m)^\d+\.[ \t]+")
    whitespace = re.compile(r"\s+")
    offenders = []
    for article in corpus:
        if len(article["content"]) < 1000:
            continue
        source = whitespace.sub("", marker.sub("", article["content"]))
        produced = whitespace.sub(
            "", "".join(chunker._split_into_paragraphs(article["content"]))
        )
        if source != produced:
            offenders.append(article["number"])
    assert offenders == []


@pytest.mark.xfail(
    strict=True,
    reason="Article 4 has no numbered paragraphs; needs the hierarchy-aware chunker",
)
def test_long_article_without_paragraphs_is_not_cited_as_paragraph_one(chunker):
    """
    Article 4 is a definitions list with an unnumbered stem — it has no
    paragraph 1. Over 1000 chars it nonetheless takes the paragraph branch and
    emits `gdpr_article_4_para_1` headed `Article 4(1):`, which reads as a
    citation of the definition of "personal data" while holding all 26.
    """
    content = "For the purposes of this Regulation: " + "definition text " * 100
    chunks = chunker.run(content, _meta(article_number="4", article_title="Definitions"))
    assert [c.metadata.chunk_type for c in chunks] == ["article"]
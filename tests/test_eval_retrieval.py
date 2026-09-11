"""
Unit tests for the retrieval scorers (src/eval/retrieval.py).

These pin one property: a reported cutoff never claims more depth than the
retrieval was taken at. A ``Hit@10`` computed over three retrieved ranks is not
a noisy number, it is a wrong one wearing a label that no re-run corrects — the
exact failure the eval tier exists to prevent (issue #59).

Scope is the fixed behaviour only; the module's wider coverage gap is not
closed here. Expected cutoffs, counts and labels are written as literals, and
nothing here touches Qdrant, a database or a model API.

The scorer tests build :class:`CaseRetrieval` values directly rather than
running ``retrieve_all`` to produce them: ``max_k`` is the field the whole
guarantee turns on, and ``retrieve_all`` is itself under test below, so letting
it supply that value would let one defect mask another. Only
``test_max_k_records_what_was_asked_for_not_what_came_back``, whose subject
*is* ``retrieve_all``, calls it — against a fake backend.
"""
import pytest

from src.eval.dataset import Article, TestCase
from src.eval.retrieval import (
    CaseRetrieval,
    LevelScore,
    article_chunk_gap,
    cutoffs_for_depth,
    gap_cutoff,
    gap_lines,
    grounded_retrievals,
    retrieve_all,
    score_article_level,
    score_chunk_level,
)


def make_case(case_id: str, article_number: str, question: str,
              supporting_quote: str = "limited to what is necessary") -> TestCase:
    return TestCase(
        case_id=case_id,
        article_number=article_number,
        article_title="Principles relating to processing of personal data",
        question=question,
        answer="Personal data must be limited to what is necessary.",
        answer_type="definition",
        supporting_quote=supporting_quote,
        key_phrases=["data minimisation"],
    )


def make_retrieval(case_id: str, gold_article: str, articles: list,
                   max_k: int, texts: list | None = None) -> CaseRetrieval:
    """One case's retrieval, written out rather than produced by retrieve_all."""
    return CaseRetrieval(
        case_id=case_id,
        gold_article=gold_article,
        retrieved_articles=articles,
        retrieved_chunk_ids=[f"{case_id}-chunk{i}" for i in range(1, len(articles) + 1)],
        retrieved_texts=texts if texts is not None else ["unrelated text"] * len(articles),
        max_k=max_k,
    )


# Gold article 5 first appears at rank 4, so a depth-3 retrieval holds three of
# these ranks and none of them is the gold one. Gold article 6 sits at rank 2,
# which a depth-3 retrieval does hold.
GOLD_AT_RANK_4 = make_retrieval("gdpr_art5_case1", "5", ["9", "12", "30"], max_k=3)
GOLD_AT_RANK_2 = make_retrieval("gdpr_art6_case1", "6", ["44", "6", "6"], max_k=3)
SHALLOW_BATCH = [GOLD_AT_RANK_4, GOLD_AT_RANK_2]


# ---------------------------- depth is carried ----------------------------- #

def test_max_k_records_what_was_asked_for_not_what_came_back():
    question = "When is processing lawful?"
    # The fake holds two results for this question; five are asked for.
    stored = [
        {"chunk_id": "d1", "text": "t", "metadata": {"article_number": "44"}},
        {"chunk_id": "d2", "text": "t", "metadata": {"article_number": "6"}},
    ]

    def fake_search(q: str, top_k: int) -> list:
        assert q == question
        return stored[:top_k]

    retrievals = retrieve_all([make_case("gdpr_art6_case1", "6", question)],
                              fake_search, max_k=5)

    assert len(retrievals) == 1
    assert retrievals[0].max_k == 5
    assert len(retrievals[0].retrieved_chunk_ids) == 2


def test_a_mixed_batch_is_bounded_by_its_shallowest_member():
    deep = make_retrieval("gdpr_art7_case1", "7", ["7"] + ["1"] * 9, max_k=10)
    batch = [deep, GOLD_AT_RANK_2]  # max_k 10 and 3

    score = score_article_level(batch)

    assert score.depth == 3
    assert sorted(score.hit_at_k) == [1, 3]
    with pytest.raises(ValueError):
        score_article_level(batch, ks=(5,))


# ------------------------- cutoffs bounded by depth ------------------------ #

def test_cutoffs_deeper_than_the_retrieval_are_refused():
    with pytest.raises(ValueError):
        score_article_level(SHALLOW_BATCH, ks=(10,))


def test_hit_at_k_counts_only_ranks_actually_retrieved():
    score = score_article_level(SHALLOW_BATCH, ks=(1, 3))

    # No cutoff above the retrieved depth is reported at all.
    assert sorted(score.hit_at_k) == [1, 3]
    assert score.scored == 2

    # The rank-4 gold is absent from every reported cutoff; the rank-2 gold is
    # counted at 3 and not at 1.
    assert score.hits == {1: 0, 3: 1}
    assert score.hit_at_k == {1: 0.0, 3: 0.5}

    # MRR reads the same truncated list: 0 + 1/2, over two cases.
    assert score.mrr == pytest.approx(0.25)
    assert score.depth == 3


def test_the_default_cutoffs_follow_the_batch_depth():
    score = score_article_level(SHALLOW_BATCH)

    assert sorted(score.hit_at_k) == [1, 3]
    assert score.hits == {1: 0, 3: 1}


def test_chunk_level_refuses_a_cutoff_deeper_than_the_retrieval():
    cases = [make_case("gdpr_art5_case1", "5", "What must be minimised?")]
    articles = {"5": Article(
        number="5",
        title="Principles relating to processing of personal data",
        content="Personal data shall be limited to what is necessary in relation to the purposes.",
    )}
    retrievals = [make_retrieval("gdpr_art5_case1", "5", ["9", "12", "5"], max_k=3,
                                 texts=["a", "b", "limited to what is necessary"])]

    with pytest.raises(ValueError):
        score_chunk_level(retrievals, cases, articles, ks=(10,))

    score = score_chunk_level(retrievals, cases, articles)
    assert score.depth == 3
    assert sorted(score.hit_at_k) == [1, 3]
    assert score.hits == {1: 0, 3: 1}


# ------------------------- the cutoff rule itself -------------------------- #

def test_cutoffs_for_depth_drops_what_the_retrieval_cannot_reach():
    assert cutoffs_for_depth(1) == (1,)
    assert cutoffs_for_depth(3) == (1, 3)
    assert cutoffs_for_depth(10) == (1, 3, 5, 10)


def test_cutoffs_for_depth_reports_the_depth_itself():
    assert cutoffs_for_depth(4) == (1, 3, 4)
    assert cutoffs_for_depth(20) == (1, 3, 5, 10, 20)


# --------------------------- the gap's cutoff ------------------------------ #

def level(name: str, ks: list) -> LevelScore:
    return LevelScore(level=name, scored=1, excluded=0, excluded_reason="",
                      depth=max(ks), hit_at_k={k: 0.5 for k in ks},
                      hits={k: 1 for k in ks})


def test_the_gap_stays_at_five_however_deep_the_retrieval_goes():
    both = [1, 3, 5, 10, 20]
    assert gap_cutoff(level("article-level", both), level("chunk-level", both)) == 5


def test_a_shallow_retrieval_reports_the_gap_at_a_cutoff_both_levels_reached():
    shallow = [1, 3]
    assert gap_cutoff(level("article-level", shallow), level("chunk-level", shallow)) == 3


def test_the_gap_is_not_reportable_when_a_level_scored_nothing():
    assert gap_cutoff(level("article-level", [1, 3, 5]),
                      LevelScore(level="chunk-level", scored=0, excluded=9,
                                 excluded_reason="quote ungrounded in its article",
                                 depth=10)) is None


# ------------------- the gap's population (issue #60) ---------------------- #
#
# The gap answers "right article, wrong chunk". The subtraction is only that
# quantity when both terms are taken over the same cases. Chunk-level scoring
# drops the cases whose quote is ungrounded; the published article score keeps
# all of them, on purpose. Subtracting one from the other mixes a population
# difference into the answer — and the excluded cases are not a random sample,
# they are the ones the parser damaged.
#
# The two fixtures below hold the grounded cases fixed and change only the
# excluded ones, so anything that moves between them is population, not
# retrieval quality.

GAP_ARTICLES = {
    "5": Article(
        number="5", title="Principles relating to processing of personal data",
        content="Personal data shall be limited to what is necessary in relation to the purposes."),
    "6": Article(
        number="6", title="Lawfulness of processing",
        content="Processing is necessary for compliance with a legal obligation."),
    "7": Article(
        number="7", title="Conditions for consent",
        content="The controller shall be able to demonstrate that the data subject consented."),
    "8": Article(
        number="8", title="Conditions applicable to child's consent",
        content="The processing of the personal data of a child shall be lawful where the child is at least 16."),
}

# Two grounded cases: one hits both levels, the other misses both.
GAP_GROUNDED_CASES = [
    make_case("gdpr_art5_case1", "5", "What must processing be limited to?",
              supporting_quote="limited to what is necessary"),
    make_case("gdpr_art6_case1", "6", "When is processing lawful?",
              supporting_quote="necessary for compliance with a legal obligation"),
]
GAP_GROUNDED_RETRIEVALS = [
    make_retrieval("gdpr_art5_case1", "5", ["5", "9", "12"], max_k=3,
                   texts=["limited to what is necessary", "b", "c"]),
    make_retrieval("gdpr_art6_case1", "6", ["9", "12", "13"], max_k=3,
                   texts=["a", "b", "c"]),
]

# Two ungrounded cases — the quote is nowhere in its own article, so chunk-level
# scoring must drop both whatever the retriever did.
GAP_UNGROUNDED_CASES = [
    make_case("gdpr_art7_case1", "7", "Who must demonstrate consent?",
              supporting_quote="a sentence that appears nowhere in Article 7"),
    make_case("gdpr_art8_case1", "8", "What age applies to a child's consent?",
              supporting_quote="a sentence that appears nowhere in Article 8"),
]
# Variant A: the excluded cases retrieve their own article at rank 1.
GAP_EXCLUDED_HIT = [
    make_retrieval("gdpr_art7_case1", "7", ["7", "9", "12"], max_k=3),
    make_retrieval("gdpr_art8_case1", "8", ["8", "9", "12"], max_k=3),
]
# Variant B: the excluded cases miss their article entirely.
GAP_EXCLUDED_MISS = [
    make_retrieval("gdpr_art7_case1", "7", ["9", "12", "13"], max_k=3),
    make_retrieval("gdpr_art8_case1", "8", ["9", "12", "13"], max_k=3),
]

GAP_CASES = GAP_GROUNDED_CASES + GAP_UNGROUNDED_CASES
GAP_KS = (1, 3)
GAP_AT = 3  # the deepest cutoff this max_k=3 fixture holds


def test_gap_is_scored_on_one_population():
    """Changing only the excluded cases moves the published number, not the gap."""
    for retrievals, published_at_3 in ((GAP_GROUNDED_RETRIEVALS + GAP_EXCLUDED_HIT, 0.75),
                                       (GAP_GROUNDED_RETRIEVALS + GAP_EXCLUDED_MISS, 0.25)):
        art = score_article_level(retrievals, GAP_KS)
        chunk = score_chunk_level(retrievals, GAP_CASES, GAP_ARTICLES, GAP_KS)
        art_g = score_article_level(
            grounded_retrievals(retrievals, GAP_CASES, GAP_ARTICLES), GAP_KS)

        # The published article score covers all four cases and moves with them.
        assert art.scored == 4
        assert art.hit_at_k[3] == published_at_3

        # The gap is taken over the two grounded cases and does not move: one of
        # the two hits the article, and the same one hits the chunk.
        assert (art_g.scored, chunk.scored) == (2, 2)
        assert art_g.hit_at_k[3] == 0.5
        assert chunk.hit_at_k[3] == 0.5
        assert article_chunk_gap(art_g, chunk, GAP_AT) == 0.0


def test_the_gap_refuses_two_scores_taken_over_different_cases():
    """The cross-population subtraction is refused, not quietly computed."""
    retrievals = GAP_GROUNDED_RETRIEVALS + GAP_EXCLUDED_HIT
    art = score_article_level(retrievals, GAP_KS)
    chunk = score_chunk_level(retrievals, GAP_CASES, GAP_ARTICLES, GAP_KS)

    assert (art.scored, chunk.scored) == (4, 2)
    with pytest.raises(ValueError):
        article_chunk_gap(art, chunk, GAP_AT)


def test_grounded_subset_is_what_chunk_level_scores():
    retrievals = GAP_GROUNDED_RETRIEVALS + GAP_EXCLUDED_HIT
    grounded = grounded_retrievals(retrievals, GAP_CASES, GAP_ARTICLES)
    chunk = score_chunk_level(retrievals, GAP_CASES, GAP_ARTICLES, GAP_KS)

    assert [r.case_id for r in grounded] == ["gdpr_art5_case1", "gdpr_art6_case1"]
    assert len(grounded) == 2
    assert chunk.scored == 2
    assert chunk.excluded == 2
    assert chunk.scored + chunk.excluded == 4
    assert chunk.excluded_reason == "quote ungrounded in its article"


def test_gap_cannot_be_negative_from_population_alone():
    """The review's pathological case: excluded cases with poor article retrieval.

    Article-level over all four is 25%, chunk-level over the grounded two is
    50%, so the old subtraction printed −25 points — a "right article, wrong
    chunk" figure below zero, which the quantity cannot be.
    """
    retrievals = GAP_GROUNDED_RETRIEVALS + GAP_EXCLUDED_MISS
    art = score_article_level(retrievals, GAP_KS)
    chunk = score_chunk_level(retrievals, GAP_CASES, GAP_ARTICLES, GAP_KS)
    art_g = score_article_level(
        grounded_retrievals(retrievals, GAP_CASES, GAP_ARTICLES), GAP_KS)

    assert art.hit_at_k[3] - chunk.hit_at_k[3] == -0.25  # what the defect printed
    assert article_chunk_gap(art_g, chunk, GAP_AT) == 0.0


def test_the_printed_gap_names_its_population():
    retrievals = GAP_GROUNDED_RETRIEVALS + GAP_EXCLUDED_HIT
    chunk = score_chunk_level(retrievals, GAP_CASES, GAP_ARTICLES, GAP_KS)
    art_g = score_article_level(
        grounded_retrievals(retrievals, GAP_CASES, GAP_ARTICLES), GAP_KS)

    text = "\n".join(gap_lines(art_g, chunk, GAP_AT))

    assert "article−chunk gap @3: +0.0%" in text
    assert "n=2" in text
    assert "grounded" in text

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
    cutoffs_for_depth,
    gap_cutoff,
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

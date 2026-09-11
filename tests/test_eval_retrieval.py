"""
Unit tests for the retrieval scorers (src/eval/retrieval.py).

These pin one property: a reported cutoff never claims more depth than the
retrieval was taken at. A ``Hit@10`` computed over three retrieved ranks is not
a noisy number, it is a wrong one wearing a label that no re-run corrects — the
exact failure the eval tier exists to prevent (issue #59).

Scope is the fixed behaviour only; the module's wider coverage gap is not
closed here. Expected cutoffs, counts and labels are written as literals, the
search backend is a fake, and nothing here touches Qdrant, a database or a
model API.
"""
import pytest

from src.eval.dataset import TestCase
from src.eval.retrieval import (
    cutoffs_for_depth,
    retrieve_all,
    score_article_level,
)


def make_case(case_id: str, article_number: str, question: str) -> TestCase:
    return TestCase(
        case_id=case_id,
        article_number=article_number,
        article_title="Principles relating to processing of personal data",
        question=question,
        answer="Personal data must be limited to what is necessary.",
        answer_type="definition",
        supporting_quote="limited to what is necessary",
        key_phrases=["data minimisation"],
    )


def result(chunk_id: str, article_number: str, text: str = "some chunk text") -> dict:
    """One search hit, in the shape the scorers read."""
    return {
        "chunk_id": chunk_id,
        "text": text,
        "metadata": {"article_number": article_number},
    }


def fake_search(by_question: dict):
    """A backend that replays a fixed ranked list, truncated to what was asked."""

    def search(question: str, top_k: int) -> list:
        return by_question[question][:top_k]

    return search


# A question whose gold article (5) first appears at rank 4, and one whose gold
# article (6) appears at rank 2. Retrieved three deep, the first is a miss the
# backend was never asked to find; the second is a hit at 3 but not at 1.
GOLD_AT_RANK_4 = "What does data minimisation require?"
GOLD_AT_RANK_2 = "When is processing lawful?"

CORPUS = {
    GOLD_AT_RANK_4: [
        result("c1", "9"),
        result("c2", "12"),
        result("c3", "30"),
        result("c4", "5"),
        result("c5", "5"),
    ],
    GOLD_AT_RANK_2: [
        result("d1", "44"),
        result("d2", "6"),
        result("d3", "6"),
    ],
}

CASES = [
    make_case("gdpr_art5_case1", "5", GOLD_AT_RANK_4),
    make_case("gdpr_art6_case1", "6", GOLD_AT_RANK_2),
]


# ---------------------------- depth is carried ----------------------------- #

def test_max_k_records_what_was_asked_for_not_what_came_back():
    # The backend holds three results for this question; five are asked for.
    retrievals = retrieve_all(
        [make_case("gdpr_art6_case1", "6", GOLD_AT_RANK_2)],
        fake_search(CORPUS),
        max_k=5,
    )
    assert len(retrievals) == 1
    assert retrievals[0].max_k == 5
    assert len(retrievals[0].retrieved_chunk_ids) == 3


# ------------------------- cutoffs bounded by depth ------------------------ #

def test_cutoffs_deeper_than_the_retrieval_are_refused():
    retrievals = retrieve_all(CASES, fake_search(CORPUS), max_k=3)
    with pytest.raises(ValueError):
        score_article_level(retrievals, ks=(10,))


def test_hit_at_k_counts_only_ranks_actually_retrieved():
    retrievals = retrieve_all(CASES, fake_search(CORPUS), max_k=3)
    score = score_article_level(retrievals, ks=(1, 3))

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


# ------------------------- the cutoff rule itself -------------------------- #

def test_cutoffs_for_depth_drops_what_the_retrieval_cannot_reach():
    assert cutoffs_for_depth(1) == (1,)
    assert cutoffs_for_depth(3) == (1, 3)
    assert cutoffs_for_depth(10) == (1, 3, 5, 10)


def test_cutoffs_for_depth_reports_the_depth_itself():
    assert cutoffs_for_depth(4) == (1, 3, 4)
    assert cutoffs_for_depth(20) == (1, 3, 5, 10, 20)

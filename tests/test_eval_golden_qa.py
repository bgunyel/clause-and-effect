"""
Unit tests for the deterministic golden-set QA gates (src/eval/golden_qa.py).

The golden set is LLM-generated and treated as ground truth, so the checks that
police it are themselves safety-critical — a broken check would wave defective
test cases through. These tests pin the behaviour of every deterministic gate,
including the known proper-noun false positive in the leakage check.
"""
import pytest

from src.eval.dataset import Article, TestCase
from src.eval.golden_qa import (
    check_answer_type,
    check_leakage,
    check_quote_grounding,
    check_required_fields,
    run_golden_qa,
)


def make_case(**overrides) -> TestCase:
    base = dict(
        case_id="gdpr_art5_case1",
        article_number="5",
        article_title="Principles",
        question="What does the data minimisation principle require?",
        answer="Personal data must be limited to what is necessary.",
        answer_type="definition",
        supporting_quote="limited to what is necessary",
        key_phrases=["data minimisation", "necessary"],
    )
    base.update(overrides)
    return TestCase(**base)


ARTICLE = Article(
    number="5",
    title="Principles relating to processing of personal data",
    content="Personal data shall be limited to what is necessary in relation to the purposes.",
)


# ------------------------------ leakage ------------------------------------ #

def test_leakage_flags_article_number_in_question():
    case = make_case(question="What does Article 5 require of controllers?")
    issue = check_leakage(case)
    assert issue is not None and issue.severity == "error"
    assert "Article 5" in issue.detail


def test_leakage_reports_full_multi_digit_reference():
    case = make_case(question="What does Article 13 require?")
    issue = check_leakage(case)
    assert issue is not None and "Article 13" in issue.detail  # not truncated to 'Article 1'


def test_leakage_flags_paragraph_reference():
    case = make_case(question="When does the procedure under paragraph 2 apply?")
    assert check_leakage(case) is not None


def test_leakage_passes_clean_question():
    assert check_leakage(make_case()) is None


@pytest.mark.xfail(reason="known false positive: 'Article 29 Working Party' is a proper noun, not a location leak")
def test_leakage_allows_article_29_working_party_proper_noun():
    case = make_case(question="What body replaces the Article 29 Working Party under the GDPR?")
    assert check_leakage(case) is None


# --------------------------- quote grounding ------------------------------- #

def test_quote_grounding_exact_substring_passes():
    assert check_quote_grounding(make_case(), ARTICLE) is None


def test_quote_grounding_whitespace_only_difference_is_a_warning():
    case = make_case(supporting_quote="limited  to   what is necessary")  # extra spaces
    issue = check_quote_grounding(case, ARTICLE)
    assert issue is not None and issue.severity == "warning"


def test_quote_grounding_genuine_miss_is_an_error():
    case = make_case(supporting_quote="a phrase that does not appear in the article")
    issue = check_quote_grounding(case, ARTICLE)
    assert issue is not None and issue.severity == "error"


def test_quote_grounding_empty_quote_is_an_error():
    issue = check_quote_grounding(make_case(supporting_quote="   "), ARTICLE)
    assert issue is not None and issue.severity == "error"


def test_quote_grounding_missing_article_is_an_error():
    issue = check_quote_grounding(make_case(), article=None)
    assert issue is not None and issue.severity == "error"


# ------------------------- structural validity ----------------------------- #

def test_answer_type_valid_passes():
    assert check_answer_type(make_case(answer_type="timeline")) is None


def test_answer_type_unknown_is_an_error():
    issue = check_answer_type(make_case(answer_type="bogus"))
    assert issue is not None and issue.severity == "error"


def test_required_fields_missing_answer_is_an_error():
    issue = check_required_fields(make_case(answer="   "))
    assert issue is not None and "answer" in issue.detail


def test_required_fields_complete_case_passes():
    assert check_required_fields(make_case()) is None


# ------------------------------ runner ------------------------------------- #

def test_run_golden_qa_aggregates_and_gates():
    good = make_case(case_id="good")
    leaky = make_case(case_id="leaky", question="Explain Article 5.")
    articles = {"5": ARTICLE}

    report = run_golden_qa(cases=[good, leaky], articles=articles)

    assert report.total_cases == 2
    assert not report.passed  # the leaky case has an error-level issue
    assert report.clean_cases == 1
    assert any(i.case_id == "leaky" and i.check == "leakage" for i in report.errors)


def test_run_golden_qa_clean_set_passes():
    report = run_golden_qa(cases=[make_case()], articles={"5": ARTICLE})
    assert report.passed
    assert report.errors == []
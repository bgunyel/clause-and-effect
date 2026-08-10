"""
Unit tests for the deterministic golden-set QA gates (src/eval/golden_qa.py).

The golden set is LLM-generated and treated as ground truth, so the checks that
police it are themselves safety-critical — a broken check would wave defective
test cases through. These tests pin the behaviour of every deterministic gate,
including that leakage keys on *self*-reference — a question naming some other
article is a cross-reference, not a leak.
"""
import re

import pytest

from src.eval.dataset import Article, TestCase, load_gdpr_articles, load_tier1
from src.eval.golden_qa import (
    check_answer_type,
    check_leakage,
    check_quote_grounding,
    check_required_fields,
    check_self_containment,
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
    case = make_case(article_number="13", question="What does Article 13 require?")
    issue = check_leakage(case)
    assert issue is not None and "Article 13" in issue.detail  # not truncated to 'Article 1'


def test_leakage_passes_clean_question():
    assert check_leakage(make_case()) is None


def test_leakage_allows_reference_to_a_different_article():
    """A cross-reference points a citation lookup *away* from the gold article."""
    case = make_case(
        article_number="10",
        question="How does Article 6(1) interact with criminal conviction data?",
    )
    assert check_leakage(case) is None


def test_leakage_flags_self_reference_with_paragraph():
    """'Article 93(2)' cites article 93 — the '(2)' must not read as article 2."""
    case = make_case(
        article_number="93",
        question="When does the examination procedure under Article 93(2) apply?",
    )
    issue = check_leakage(case)
    assert issue is not None and "Article 93" in issue.detail

    unrelated = make_case(article_number="2", question="What does Article 93(2) trigger?")
    assert check_leakage(unrelated) is None


def test_leakage_allows_article_29_working_party_proper_noun():
    """
    The former false positive: 'Article 29' is the Working Party's name, taken
    from the repealed Directive 95/46/EC, not a pointer into this regulation.
    """
    case = make_case(
        article_number="94",
        question="What body replaces the Article 29 Working Party under the GDPR?",
    )
    assert check_leakage(case) is None


# --------------------------- self-containment ------------------------------ #

@pytest.mark.parametrize(
    "question",
    [
        "Does this article apply to all personal data held by a public body?",
        "Do these derogations apply to public authorities?",
        "If an order cannot be enforced under this rule, can data be transferred?",
        "What is the cutoff date under this provision?",
        "Do those obligations bind processors?",
        "Are such transfers permitted without safeguards?",
    ],
)
def test_self_containment_flags_dangling_demonstrative(question):
    issue = check_self_containment(make_case(question=question))
    assert issue is not None and issue.severity == "error"


def test_self_containment_catches_nouns_nobody_enumerated():
    """
    The rule anchors on the determiner, so the noun can be anything.

    Enumerating nouns is what made earlier sweeps miss cases: a pass for
    'article' missed 'this rule' and 'this provision', and a pass for those
    still missed 'these derogations'.
    """
    issue = check_self_containment(make_case(question="Does this widget apply to processors?"))
    assert issue is not None and "this widget" in issue.detail


@pytest.mark.parametrize(
    "question",
    [
        # antecedent present earlier in the same question
        "If a person objects to their data being processed, can the company keep using that data?",
        "If a user gives consent, what requirements must that consent meet?",
        # 'this Regulation' is a term of art — exactly one regulation is in scope
        "What rights does this Regulation grant to data subjects?",
        # demonstrative as a pronoun, not a determiner: the referent is a clause
        "How long does a company have to respond, and can this be extended?",
        # 'such as' is not a demonstrative phrase
        "Does GDPR apply to activities outside EU law, such as national security?",
        # bare relative 'that' is not a demonstrative and must not be flagged
        "Under what conditions does GDPR apply to a company that is not based in the EU?",
    ],
)
def test_self_containment_allows_resolvable_references(question):
    assert check_self_containment(make_case(question=question)) is None


# --------------------------- quote grounding ------------------------------- #

def test_quote_grounding_exact_substring_passes():
    assert check_quote_grounding(make_case(), ARTICLE) is None


def test_quote_grounding_whitespace_only_difference_is_a_warning():
    case = make_case(supporting_quote="limited  to   what is necessary")  # extra spaces
    issue = check_quote_grounding(case, ARTICLE)
    assert issue is not None and issue.severity == "warning"


def test_quote_grounding_list_markers_flattened_is_a_warning():
    """
    docling renders the regulation's enumerations as markdown bullets. A
    citation that reproduces the sub-items as running prose is normal practice
    — see Article 53(1), whose four sub-items reach the corpus as '\\n- ' lines.
    """
    article = Article(
        number="53",
        title="General conditions",
        content=(
            "1. Member States shall provide for each member to be appointed by:\n"
            "- their parliament;\n- their government;\n- their head of State."
        ),
    )
    case = make_case(
        article_number="53",
        supporting_quote=(
            "Member States shall provide for each member to be appointed by: "
            "their parliament; their government; their head of State."
        ),
    )
    issue = check_quote_grounding(case, article)
    assert issue is not None and issue.severity == "warning"


def test_quote_grounding_letter_case_difference_is_a_warning():
    """A span lifted from mid-sentence is routinely re-cased to stand alone."""
    case = make_case(supporting_quote="Limited to what is necessary")
    issue = check_quote_grounding(case, ARTICLE)
    assert issue is not None and issue.severity == "warning"


def test_quote_grounding_space_before_punctuation_is_a_warning():
    """OCR artifact: the corpus carries 'inter alia ,' in Article 7."""
    article = Article(number="7", title="Consent",
                      content="Account shall be taken of whether, inter alia , the contract applies.")
    case = make_case(
        article_number="7",
        supporting_quote="whether, inter alia, the contract applies",
    )
    issue = check_quote_grounding(case, article)
    assert issue is not None and issue.severity == "warning"


def test_quote_grounding_inserted_punctuation_stays_an_error():
    """
    The deliberate boundary of the normalization. In a legal text a comma marks
    restrictive vs non-restrictive clauses, so a quote that inserts one has
    altered the statute. Normalizing punctuation away would erase the check's
    ability to notice.
    """
    case = make_case(supporting_quote="limited to what, is necessary")
    issue = check_quote_grounding(case, ARTICLE)
    assert issue is not None and issue.severity == "error"


def test_quote_grounding_reordered_words_stay_an_error():
    """Same words, different order — a rewrite, not a rendering difference."""
    case = make_case(supporting_quote="what is necessary limited to")
    issue = check_quote_grounding(case, ARTICLE)
    assert issue is not None and issue.severity == "error"


def test_quote_grounding_dropped_words_stay_an_error():
    """Normalization must not bridge a gap in the quoted text."""
    case = make_case(supporting_quote="Personal data shall be limited to the purposes")
    issue = check_quote_grounding(case, ARTICLE)
    assert issue is not None and issue.severity == "error"


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


# ---------------------- leakage, on the real set ---------------------------- #

def test_no_golden_case_names_its_own_article():
    """
    The whole set is free of self-reference, and must stay that way.

    Seventeen cases named their own gold article, all of them in short,
    procedural articles that are hard to characterise without the number
    ("What types of identifiers does Article 87 cover?"). They were reworded on
    2026-08-03. A regenerated or hand-edited case that reintroduces the pattern
    fails here rather than silently scoring retrieval on citation lookup.
    """
    offenders = [
        (c.case_id, c.question) for c in load_tier1() if check_leakage(c) is not None
    ]
    assert not offenders, "questions naming their own gold article: " + "; ".join(
        f"{cid}: {q!r}" for cid, q in offenders
    )


def test_no_golden_case_refers_to_absent_context():
    """
    The whole set is free of dangling demonstratives, and must stay that way.

    Eight questions leaned on the article the reader was assumed to be looking
    at — five "this article", plus "this rule", "this provision" and "these
    derogations". They were reworded on 2026-08-03.

    Note what this does *not* cover: a question can depend on absent context
    with no demonstrative in it at all. That residue is judge-tier (P1) and
    unmeasured — a green result here is not evidence the set is self-contained.
    """
    offenders = [
        (c.case_id, c.question)
        for c in load_tier1()
        if check_self_containment(c) is not None
    ]
    assert not offenders, "questions referring to absent context: " + "; ".join(
        f"{cid}: {q!r}" for cid, q in offenders
    )


# ------------------- normalization safety, on the real set ------------------ #
#                                                                             #
#  The normalization is only sound if it removes *rendering* differences and  #
#  nothing else. That claim is measured against the real golden set rather    #
#  than asserted, so a future loosening cannot quietly start waving through   #
#  reordered or fabricated quotes.                                            #

def _word_sequence(text: str) -> list[str]:
    """Alphanumeric words, lowercased — all rendering stripped away."""
    return [w for w in (re.sub(r"[^a-z0-9]", "", t.lower()) for t in text.split()) if w]


def test_normalization_only_ever_clears_contiguous_verbatim_quotes():
    """
    Every case the normalization promotes from error to warning must have the
    quote's exact word sequence appearing *contiguously* in its article.

    That is the precise definition of "differs only in rendering": same words,
    same order, no gaps. A quote whose words were reordered, reworded, or
    dropped cannot satisfy it, so this fails the moment normalization starts
    clearing something it should not.
    """
    articles = load_gdpr_articles()
    promoted = [
        (c, articles[c.article_number])
        for c in load_tier1()
        if (issue := check_quote_grounding(c, articles.get(c.article_number)))
        and issue.severity == "warning"
    ]
    assert promoted, "expected the real set to exercise the normalization tier"

    for case, article in promoted:
        quote_words = _word_sequence(case.supporting_quote)
        source_words = _word_sequence(article.full_text)
        joined_source = " " + " ".join(source_words) + " "
        joined_quote = " " + " ".join(quote_words) + " "
        assert joined_quote in joined_source, (
            f"{case.case_id}: normalization cleared a quote whose words are not "
            f"contiguous in article {case.article_number}"
        )
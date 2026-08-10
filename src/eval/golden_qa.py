"""
Golden-set QA — "the eval-of-the-eval" (plan §7.3).

The Tier-1 golden set is LLM-generated, so it cannot be trusted as ground
truth until validated. An unvalidated golden set silently launders model bias
into "truth" (principle §1.3). These are the *deterministic* gates that run on
the set before any score computed against it is believed:

    - **Quote grounding** — every ``supporting_quote`` must be a substring of
      its source article. Reported in three tiers rather than pass/fail:
      *exact* (byte-identical), *normalized* (identical once rendering
      differences are removed — see :func:`normalize_for_grounding` — reported
      as a warning), and *ungrounded* (an error: a broken test case, to fix or
      remove). The middle tier exists because the substring rule is only a
      proxy for what we actually want, which is evidence verifiably drawn from
      the regulation; where proxy and purpose disagree, the proxy bends.
    - **Leakage discipline** — a question must not name *its own* gold article,
      or retrieval is tested on citation lookup rather than meaning. Naming
      some *other* article is a cross-reference, not a leak — it points the
      lookup away from the answer.
    - **Self-containment** — a question must not point at context it does not
      carry. "Does this article apply to all personal data held by a public
      body?" leaks no location, but it cannot be read as a standalone retrieval
      query either.
    - **Structural validity** — non-empty required fields, a known
      ``answer_type``, and a gold article that actually exists in the corpus.

The semantic gates (answer-vs-quote entailment, human audit) are LLM-judge /
manual and belong to P1 — they are intentionally not implemented here.

Run directly for a summary:

    python -m src.eval.golden_qa
"""
from __future__ import annotations

import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Literal

from src.eval.dataset import (
    ANSWER_TYPES,
    Article,
    TestCase,
    load_gdpr_articles,
    load_tier1,
)

Severity = Literal["error", "warning"]

# An article citation in a question: "Article 5", "Art. 6(1)", "Article 93(2)".
# Only the article number is captured — a parenthesised paragraph is a location
# *within* the cited article, not a second article, so "93(2)" reads as 93.
#
# Deliberately narrow: it does not parse multi-article runs ("Articles 13 and
# 14" reads as 13 alone). No question in the set uses that form; widen it when
# one does.
_ARTICLE_REF = re.compile(r"\b(?:articles?|arts?\.?)\s*(\d+)", re.IGNORECASE)

# A demonstrative phrase — "this article", "these derogations", "such rules".
#
# Anchored on the *determiner*, which is a closed class, rather than on the
# noun, which is not. Listing nouns is what makes this kind of check unwinnable:
# successive sweeps for "article", then "provision"/"rule", still missed "these
# derogations". The noun is left as a wildcard so the rule catches words nobody
# thought to enumerate.
#
# Bare "that" is deliberately excluded. It is the one member of the class that
# is ambiguous with a relative pronoun ("activities that fall outside the scope
# of EU law"), and telling those apart is a part-of-speech judgement, not a
# lexical one. Including it flagged 29 questions to find 8.
_DEMONSTRATIVE = re.compile(r"\b(?:this|these|those|such|said)\s+([a-z]+)\b", re.IGNORECASE)

# "this Regulation" is a term of art, not a dangling reference: exactly one
# regulation is in scope, so the phrase is unambiguous standing alone.
_TERMS_OF_ART = frozenset({"regulation"})

# Where the next word is an auxiliary or copula, the demonstrative is a pronoun
# rather than a determiner ("...and can this be extended?"), and its referent is
# a clause, not a noun. Also a closed class, which is why enumerating it is safe
# in a way that enumerating nouns is not.
_NOT_A_NOUN = frozenset({
    "as", "be", "is", "are", "was", "were", "been", "being", "has", "have",
    "had", "will", "would", "can", "could", "shall", "should", "may", "might",
    "must", "do", "does", "did",
})

# Collapse whitespace runs (incl. newlines) to a single space. The source
# articles carry OCR/formatting artifacts (e.g. double spaces), so a quote can
# be semantically grounded yet fail a byte-exact substring test.
_WS = re.compile(r"\s+")

# docling renders the regulation's enumerations as markdown bullets, so
# Article 53(1) reaches the corpus as "...procedure by:\n- their parliament;\n-
# their government;...". A citation that reproduces those sub-items as running
# prose is normal practice, not a misquotation — and dropping the markers is
# arguably better than keeping them, since a quote covering one numbered
# paragraph should not carry the enumeration's own labels.
_LIST_MARKER = re.compile(r"\n+[ \t]*-[ \t]*")

# OCR occasionally leaves a space before punctuation ("inter alia ,"). That is
# an artifact of the scan, not of the regulation's wording.
_SPACE_BEFORE_PUNCT = re.compile(r"\s+([,;.)])")


def _normalize_ws(text: str) -> str:
    return _WS.sub(" ", text).strip()


def normalize_for_grounding(text: str) -> str:
    """
    Strip differences that are *rendering*, not wording.

    Applied symmetrically to a quote and its source article, this removes the
    distinctions a citation legitimately normalizes away:

    - a space before punctuation (OCR artifact)
    - markdown list markers (docling's rendering of an enumeration)
    - whitespace runs and line breaks (layout)
    - letter case (a span lifted from mid-sentence is routinely re-cased to
      stand alone, and vice versa)

    Punctuation itself is deliberately *kept*. In a legal text a comma marks
    restrictive versus non-restrictive clauses and enumeration boundaries, so a
    quote that inserts one has altered the statute — mildly, but really. Erasing
    punctuation would also erase the check's ability to notice.

    The boundary is drawn from measurement, not taste: across the full error
    set these steps clear 12 of the 15 formatting-only failures while leaving
    every reordered, reworded and fabricated quote flagged — 0 of 37 "altered"
    and 0 of 20 "absent" cases leak through. See
    ``tests/test_eval_golden_qa.py`` for the property that pins this.
    """
    text = _SPACE_BEFORE_PUNCT.sub(r"\1", text)
    text = _LIST_MARKER.sub(" ", text)
    return _normalize_ws(text).lower()


@dataclass(frozen=True)
class QAIssue:
    """One problem found with one test case."""

    case_id: str
    check: str
    severity: Severity
    detail: str


@dataclass
class QAReport:
    """Aggregate result of running the golden-set QA gates."""

    total_cases: int
    issues: List[QAIssue]

    @property
    def errors(self) -> List[QAIssue]:
        return [i for i in self.issues if i.severity == "error"]

    @property
    def warnings(self) -> List[QAIssue]:
        return [i for i in self.issues if i.severity == "warning"]

    @property
    def clean_cases(self) -> int:
        """Cases with no error-level issue (warnings are tolerated)."""
        flagged = {i.case_id for i in self.errors}
        return self.total_cases - len(flagged)

    @property
    def passed(self) -> bool:
        """The set clears the gate iff no case has an error-level issue."""
        return not self.errors


# --------------------------------------------------------------------------- #
#  Individual checks — each returns 0 or 1 QAIssue for a single case.          #
# --------------------------------------------------------------------------- #

def check_quote_grounding(case: TestCase, article: Article | None) -> QAIssue | None:
    """`supporting_quote` must be a substring of its source article (§7.3)."""
    quote = case.supporting_quote
    if not quote.strip():
        return QAIssue(case.case_id, "quote_grounding", "error", "empty supporting_quote")

    if article is None:
        return QAIssue(
            case.case_id,
            "quote_grounding",
            "error",
            f"gold article {case.article_number!r} not found in source corpus",
        )

    source = article.full_text
    if quote in source:
        return None  # tier: exact

    # Byte-exact miss: is it a rendering difference or a real one? Normalizing
    # both sides answers that without loosening what "grounded" means — a
    # normalized match is still reported, just not as a failure.
    if normalize_for_grounding(quote) in normalize_for_grounding(source):
        return QAIssue(
            case.case_id,
            "quote_grounding",
            "warning",
            "grounded only after formatting normalization "
            "(list markers / whitespace / case / spacing)",
        )

    return QAIssue(
        case.case_id,
        "quote_grounding",
        "error",
        f"supporting_quote not found in article {case.article_number}: {quote[:80]!r}...",
    )


def check_leakage(case: TestCase) -> QAIssue | None:
    """
    Question must not name its own gold article (§7.3).

    The discriminator is *self-reference*, not the presence of a citation. A
    question that names the article its answer lives in can be resolved by
    citation lookup, so retrieval is never tested on meaning. A question that
    names some *other* article is an ordinary cross-reference — it points a
    lookup shortcut away from the gold article, and Article 10's relationship
    to Article 6(1) cannot be asked about otherwise.

    Known boundary: a same-numbered article of a *different* instrument
    ("Article 5 of Regulation (EU) No 182/2011" in a case whose gold article is
    5) would be flagged. No case in the set does this.
    """
    for number in _ARTICLE_REF.findall(case.question):
        if number == case.article_number:
            return QAIssue(
                case.case_id,
                "leakage",
                "error",
                f"question names its own gold article: 'Article {number}'",
            )
    return None


def check_self_containment(case: TestCase) -> QAIssue | None:
    """
    A question must carry its own referents (§7.3).

    Distinct from leakage: "Does this article apply to all personal data held by
    a public body?" reveals no location, so nothing can be looked up by
    citation — but it cannot be read on its own either, and a retrieval query
    that only makes sense next to the answer is not a retrieval query. The
    generator produced these because it was looking at the article while it
    wrote, and assumed its reader would be too.

    A demonstrative is accepted when its noun already appeared earlier in the
    same question ("...inform other organizations that received that data").

    This is a floor, not a proof. A question can depend on absent context with
    no demonstrative at all — "Are there any exemptions?" points nowhere and is
    invisible here. That residue belongs to the LLM-judge/audit tier (P1).
    """
    for match in _DEMONSTRATIVE.finditer(case.question):
        noun = match.group(1).lower()
        if noun in _TERMS_OF_ART or noun in _NOT_A_NOUN:
            continue
        preceding = case.question[: match.start()]
        if re.search(rf"\b{re.escape(noun)}s?\b", preceding, re.IGNORECASE):
            continue  # antecedent is present in the question itself
        return QAIssue(
            case.case_id,
            "self_containment",
            "error",
            f"question refers to absent context: {match.group(0)!r}",
        )
    return None


def check_answer_type(case: TestCase) -> QAIssue | None:
    """`answer_type` must be one of the known slice tags (§3.2)."""
    if case.answer_type not in ANSWER_TYPES:
        return QAIssue(
            case.case_id,
            "answer_type",
            "error",
            f"unknown answer_type {case.answer_type!r} (expected one of {ANSWER_TYPES})",
        )
    return None


def check_required_fields(case: TestCase) -> QAIssue | None:
    """Question, gold answer, and key_phrases must be present."""
    missing = [
        name
        for name, value in (
            ("question", case.question.strip()),
            ("answer", case.answer.strip()),
            ("key_phrases", case.key_phrases),
        )
        if not value
    ]
    if missing:
        return QAIssue(
            case.case_id,
            "required_fields",
            "error",
            f"missing/empty field(s): {', '.join(missing)}",
        )
    return None


# --------------------------------------------------------------------------- #
#  Runner                                                                      #
# --------------------------------------------------------------------------- #

def run_golden_qa(
    cases: List[TestCase] | None = None,
    articles: Dict[str, Article] | None = None,
) -> QAReport:
    """
    Run every deterministic golden-set QA gate over the Tier-1 set.

    Args:
        cases:    Test cases to check. Defaults to the full Tier-1 set on disk.
        articles: Source articles, keyed by number. Defaults to the GDPR corpus.

    Returns:
        A :class:`QAReport` aggregating every issue found.
    """
    if cases is None:
        cases = load_tier1()
    if articles is None:
        articles = load_gdpr_articles()

    issues: List[QAIssue] = []
    for case in cases:
        article = articles.get(case.article_number)
        candidates = [
            check_required_fields(case),
            check_answer_type(case),
            check_leakage(case),
            check_self_containment(case),
            check_quote_grounding(case, article),
        ]
        issues.extend(issue for issue in candidates if issue is not None)

    return QAReport(total_cases=len(cases), issues=issues)


def main() -> None:
    report = run_golden_qa()

    by_check: Counter[str] = Counter(f"{i.check}/{i.severity}" for i in report.issues)

    grounding = {i.case_id: i.severity for i in report.issues if i.check == "quote_grounding"}
    exact = report.total_cases - len(grounding)
    normalized = sum(1 for s in grounding.values() if s == "warning")
    ungrounded = sum(1 for s in grounding.values() if s == "error")

    print("Golden-set QA — Tier 1")
    print("=" * 48)
    print(f"cases checked : {report.total_cases}")
    print(f"clean cases   : {report.clean_cases}")
    print(f"errors        : {len(report.errors)}")
    print(f"warnings      : {len(report.warnings)}")
    print(f"gate          : {'PASS' if report.passed else 'FAIL'}")

    print("\nquote grounding by tier:")
    print(f"  {exact:4d}  exact       (byte-identical substring)")
    print(f"  {normalized:4d}  normalized  (matches once rendering differences are removed)")
    print(f"  {ungrounded:4d}  ungrounded  (not in the article — a real defect)")

    if by_check:
        print("\nissues by check:")
        for key, count in sorted(by_check.items()):
            print(f"  {count:4d}  {key}")

    if report.errors:
        print("\nerror-level issues:")
        for issue in report.errors:
            print(f"  [{issue.case_id}] {issue.check}: {issue.detail}")


if __name__ == "__main__":
    main()
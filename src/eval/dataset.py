"""
Typed loaders for the evaluation datasets.

Two sources feed the eval framework:

    - The **golden set** — LLM-generated Tier-1 test cases in
      `data/tier-1/article_NN_test_cases.json`. Each case carries a gold
      `answer`, an `answer_type`, an exact `supporting_quote`, and a list of
      `key_phrases`. This is our ground truth (once validated — see `golden_qa`).

    - The **article source** — the regulation text the golden set is drawn
      from, in `data/regulations/gdpr_articles.json`. Needed to verify that a
      `supporting_quote` really is a substring of its source article (§7.3).

Everything downstream (scorers, harness, reports) consumes the typed objects
defined here rather than raw dicts, so the on-disk shape is decoupled from the
rest of the framework.
"""
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List

# Repo root, resolved from this file: src/eval/dataset.py -> src -> <root>.
_REPO_ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = _REPO_ROOT / "data"
TIER1_DIR = DATA_DIR / "tier-1"
GDPR_ARTICLES_FILE = DATA_DIR / "regulations" / "gdpr_articles.json"

# The four answer-type tags every Tier-1 case is expected to carry. All
# generation metrics are sliced by these (plan §3.2).
ANSWER_TYPES = ("timeline", "definition", "conditional", "scope")


@dataclass(frozen=True)
class TestCase:
    """A single Tier-1 golden test case, plus the gold article it belongs to."""

    # Not a pytest test class despite the name (no annotation -> not a dataclass field).
    __test__ = False

    case_id: str  # stable, e.g. "gdpr_art5_case2"
    article_number: str  # gold article, as a string ("5")
    article_title: str
    question: str
    answer: str  # gold reference answer
    answer_type: str  # timeline | definition | conditional | scope
    supporting_quote: str  # gold evidence span; exact substring of the article
    key_phrases: List[str]


@dataclass(frozen=True)
class Article:
    """A source regulation article — the ground truth a test case is drawn from."""

    number: str
    title: str
    content: str

    @property
    def full_text(self) -> str:
        """Title + content, matching how the indexer builds the chunk text."""
        return f"{self.title}\n\n{self.content}"


def load_tier1(tier1_dir: Path | str = TIER1_DIR) -> List[TestCase]:
    """
    Load every Tier-1 test case into a flat list of :class:`TestCase`.

    Args:
        tier1_dir: Directory holding the ``article_NN_test_cases.json`` files.

    Returns:
        All test cases across all articles, ordered by article number then by
        their position within the file. ``case_id`` is stable across runs.
    """
    tier1_dir = Path(tier1_dir)
    files = sorted(tier1_dir.glob("article_*_test_cases.json"))
    if not files:
        raise FileNotFoundError(f"No Tier-1 test-case files found in {tier1_dir}")

    cases: List[TestCase] = []
    for path in files:
        with open(path, "r", encoding="utf-8") as f:
            payload = json.load(f)

        article_number = str(payload["article_number"])
        article_title = payload.get("article_title", "")

        for i, raw in enumerate(payload.get("test_cases", []), start=1):
            cases.append(
                TestCase(
                    case_id=f"gdpr_art{article_number}_case{i}",
                    article_number=article_number,
                    article_title=article_title,
                    question=raw["question"],
                    answer=raw["answer"],
                    answer_type=raw.get("answer_type", ""),
                    supporting_quote=raw.get("supporting_quote", ""),
                    key_phrases=list(raw.get("key_phrases", [])),
                )
            )

    return cases


def load_gdpr_articles(
    articles_file: Path | str = GDPR_ARTICLES_FILE,
) -> Dict[str, Article]:
    """
    Load the GDPR source articles, keyed by article number (as a string).

    Args:
        articles_file: Path to ``gdpr_articles.json``.

    Returns:
        Mapping of ``article_number -> Article``.
    """
    articles_file = Path(articles_file)
    with open(articles_file, "r", encoding="utf-8") as f:
        raw_articles = json.load(f)

    return {
        str(a["number"]): Article(
            number=str(a["number"]),
            title=a.get("title", ""),
            content=a.get("content", ""),
        )
        for a in raw_articles
    }
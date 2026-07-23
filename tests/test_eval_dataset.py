"""
Unit tests for the eval dataset loaders (src/eval/dataset.py).

Everything downstream (scorers, harness, reports) consumes these typed objects,
so the loader's field mapping and stable case IDs are load-bearing.
"""
import json

import pytest

from src.eval.dataset import Article, TestCase, load_gdpr_articles, load_tier1


def _write_json(path, payload):
    path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")


def test_load_tier1_maps_fields_and_assigns_stable_ids(tmp_path):
    _write_json(
        tmp_path / "article_05_test_cases.json",
        {
            "article_number": "5",
            "article_title": "Principles",
            "test_cases": [
                {
                    "question": "Q1?",
                    "answer": "A1.",
                    "answer_type": "definition",
                    "supporting_quote": "quote one",
                    "key_phrases": ["a", "b"],
                },
                {
                    "question": "Q2?",
                    "answer": "A2.",
                    "answer_type": "scope",
                    "supporting_quote": "quote two",
                    "key_phrases": ["c"],
                },
            ],
        },
    )

    cases = load_tier1(tmp_path)

    assert [c.case_id for c in cases] == ["gdpr_art5_case1", "gdpr_art5_case2"]
    first = cases[0]
    assert isinstance(first, TestCase)
    assert first.article_number == "5"
    assert first.article_title == "Principles"
    assert first.question == "Q1?"
    assert first.answer_type == "definition"
    assert first.key_phrases == ["a", "b"]


def test_load_tier1_orders_by_article_number(tmp_path):
    for n in ("02", "10", "01"):
        _write_json(
            tmp_path / f"article_{n}_test_cases.json",
            {
                "article_number": n.lstrip("0"),
                "article_title": f"Art {n}",
                "test_cases": [
                    {"question": "q", "answer": "a", "answer_type": "scope",
                     "supporting_quote": "s", "key_phrases": ["k"]}
                ],
            },
        )
    cases = load_tier1(tmp_path)
    # sorted() on the glob orders files lexically: article_01, article_02, article_10
    assert [c.article_number for c in cases] == ["1", "2", "10"]


def test_load_tier1_raises_when_no_files(tmp_path):
    with pytest.raises(FileNotFoundError):
        load_tier1(tmp_path)


def test_load_gdpr_articles_keys_by_number(tmp_path):
    articles_file = tmp_path / "gdpr_articles.json"
    _write_json(
        articles_file,
        [
            {"number": "1", "title": "Subject-matter", "content": "Body one."},
            {"number": "2", "title": "Material scope", "content": "Body two."},
        ],
    )
    articles = load_gdpr_articles(articles_file)
    assert set(articles) == {"1", "2"}
    assert isinstance(articles["1"], Article)
    assert articles["2"].title == "Material scope"


def test_article_full_text_joins_title_and_content():
    art = Article(number="1", title="Subject-matter", content="Body.")
    assert art.full_text == "Subject-matter\n\nBody."
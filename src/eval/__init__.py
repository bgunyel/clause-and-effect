"""
Evaluation framework for { Clause & Effect }.

Implements the measurement blueprint in `docs/evaluation-plan.md`. The
governing rule is: *every architecture decision gets measured before it gets
kept.* The framework is the durable asset; the pipeline behind it is disposable.

P0 — Foundations (current):
    - Typed golden-set loader                (`dataset`)
    - Golden-set QA / "the eval-of-the-eval" (`golden_qa`, §7.3)

Later phases add deterministic scorers, the run harness + manifest, and the
LLM-judge scorers (see the plan's §11 roadmap).
"""

from .dataset import (
    Article,
    TestCase,
    load_gdpr_articles,
    load_tier1,
)

__all__ = [
    "Article",
    "TestCase",
    "load_gdpr_articles",
    "load_tier1",
]
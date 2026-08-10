"""
Driver for the sufficiency judge — runs the stages and reports.

What exists today is a **probe harness**, not the runner: it takes eight cases
chosen to cover the criterion's edges and prints stage A and stage B output for
each, so the stages can be read against real data. It derives no verdict, runs no
panel and writes nothing.

The runner proper — stage C, verdict derivation, the panel, aggregation over
`PanelistRun` into `CaseJudgement`, and the calibration sample — belongs here and
is not built. See ``docs/design/sufficiency-judge.md`` §§6-9.

Run:

    python -m src.eval.sufficiency.judge
"""
from __future__ import annotations

import asyncio

from src.eval.dataset import load_tier1
from src.eval.sufficiency.stage_a import decompose
from src.eval.sufficiency.stage_b import answer_blind, span_is_verbatim
from src.llm_config import get_llm_config


async def main():
    wanted = [
        "gdpr_art7_case3",   # the case the criterion was settled on
        "gdpr_art2_case4",   # grounds exact, quote carries no negation
        "gdpr_art33_case1",  # core timing rule + auxiliary consequence
        "gdpr_art15_case1",  # enumeration question: every item is core
        "gdpr_art8_case1",   # key-phrase screen flags it; quote answers it
        "gdpr_art41_case3",  # invalid case — the article has no such content
        "gdpr_art8_case5",   # quote is from Recital 38, not the article
        "gdpr_art7_case4",   # carries art7_case3's auxiliary clause as its own quote
    ]

    cases = {c.case_id: c for c in load_tier1()}
    picked = [cases[c] for c in wanted if c in cases]

    model_params = get_llm_config()["writer_model"][0]
    print(f"model: {model_params['model']}\n")

    decompositions, blind_answers = await asyncio.gather(
        asyncio.gather(*[decompose(c, model_params) for c in picked]),
        asyncio.gather(*[answer_blind(c, model_params) for c in picked]),
    )

    for case, dec, blind in zip(picked, decompositions, blind_answers):
        print("=" * 78)
        print(f"{case.case_id}  [{case.answer_type}]")
        print(f"Q: {case.question}")
        print(f"A: {case.answer}")
        print(f"quote: {case.supporting_quote}")

        print(f"\n-- stage A: {len(dec.core_claims)} core / {len(dec.claims)} claims")
        print(f"   shortest sufficient answer: {dec.shortest_sufficient_answer}")
        for c in dec.claims:
            print(f"   [{c.tag:9}] {c.text}")
            print(f"               ({c.reason})")

        verbatim = span_is_verbatim(blind.minimal_span, case.supporting_quote)
        shrink = (
            f"{len(blind.minimal_span)}/{len(case.supporting_quote)} chars"
            if blind.minimal_span else "no span"
        )
        print(f"\n-- stage B: answered={blind.answered}  span verbatim={verbatim}  {shrink}")
        print(f"   span:   {blind.minimal_span}")
        print(f"   answer: {blind.answer}")
        print(f"   note:   {blind.note}")
        print()


if __name__ == "__main__":
    asyncio.run(main())
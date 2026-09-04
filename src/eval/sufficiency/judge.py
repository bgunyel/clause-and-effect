"""
Driver for the sufficiency judge — runs the stages and reports.

What exists today is a **probe harness**, not the runner: it takes eight cases
chosen to cover the criterion's edges and prints all three stages' output for
each, so the chain can be read against real data. It derives no verdict, runs no
panel and writes nothing.

The runner proper — verdict derivation, the panel, aggregation over `PanelistRun`
into `CaseJudgement`, and the calibration sample — belongs here and is not built.
See ``docs/design/sufficiency-judge.md`` §§7-9.

**Why the printed stage C section says which claims were adjudicated.** Stage C
is given core claims only and declines to call the model at all when there are
none or when stage B produced no answer, so a silent section would be
indistinguishable from a stage that ran and found nothing. The harness exists to
be read, so it reports which of the three paths a case took.

Run:

    python -m src.eval.sufficiency.judge
"""
from __future__ import annotations

import asyncio
from typing import Any, Dict, Tuple

from src.eval.dataset import TestCase, load_tier1
from src.eval.sufficiency.llm import StageResponse
from src.llm.call import sum_costs
from src.eval.sufficiency.models import Adjudication, BlindAnswer, Decomposition
from src.eval.sufficiency.stage_a import decompose
from src.eval.sufficiency.stage_b import answer_blind, span_is_verbatim
from src.eval.sufficiency.stage_c import adjudicate
from src.llm_config import get_llm_config


async def probe_case(
    case: TestCase,
    model_params: Dict[str, Any],
) -> StageResponse[Tuple[Decomposition, BlindAnswer, Adjudication]]:
    """
    Run one case through A, B and C.

    A and B are independent — neither sees the other's output — so they go
    concurrently. C consumes both, so it waits. Cases are gathered in ``main``,
    which keeps the concurrency across cases rather than across stages: a
    stage-wide barrier would idle the fast cases until the slowest caught up.

    Returns:
        The three stages' output and what the case cost across all three. As in
        :func:`stage_a_twocall.decompose`, an unpriced stage makes the whole
        case unpriced rather than reporting a partial total as the case's cost.
        Stage C may contribute a true ``0.0`` — it skips the model when there is
        nothing to adjudicate — and that is a price, not a gap.
    """
    decomposition, blind = await asyncio.gather(
        decompose(case, model_params),
        answer_blind(case, model_params),
    )
    adjudication = await adjudicate(
        case.question, decomposition.value.core_claims, blind.value, model_params
    )
    total, unpriced = sum_costs([decomposition.cost, blind.cost, adjudication.cost])
    return StageResponse(
        value=(decomposition.value, blind.value, adjudication.value),
        cost=None if unpriced else total,
        # A, B, then C — and C contributes nothing on the two paths where it
        # makes no call, so a case's id count is 2 or 3 and says which it was.
        calls=decomposition.calls + blind.calls + adjudication.calls,
    )


def print_stage_c(decomposition: Decomposition, blind: BlindAnswer, adjudication: Adjudication):
    """Print stage C, naming which of its three paths the case took."""
    if not decomposition.core_claims:
        print("\n-- stage C: not run — stage A found no core claim, so the gold answer "
              "does not answer its own question")
        return
    if not blind.answer.strip():
        print(f"\n-- stage C: no call — stage B produced no answer, so all "
              f"{len(adjudication.claim_verdicts)} core claim(s) are absent by arithmetic")
    else:
        counts: Dict[str, int] = {}
        for verdict in adjudication.claim_verdicts:
            counts[verdict.support] = counts.get(verdict.support, 0) + 1
        tally = "  ".join(f"{support}={n}" for support, n in sorted(counts.items()))
        print(f"\n-- stage C: {len(adjudication.claim_verdicts)} core claim(s) adjudicated"
              f"  [{tally}]")

    for verdict in adjudication.claim_verdicts:
        print(f"   [{verdict.support:12}] {verdict.claim.text}")
        print(f"                  ({verdict.rationale})")


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

    model_params = get_llm_config()["sufficiency_judge"][0]
    print(f"model: {model_params['model']}\n")

    results = await asyncio.gather(*[probe_case(c, model_params) for c in picked])

    for case, result in zip(picked, results):
        dec, blind, adjudication = result.value
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

        print_stage_c(dec, blind, adjudication)
        cost = "unpriced" if result.cost is None else f"${result.cost:.6f}"
        print(f"\n-- cost: {cost} across A, B and C")
        print()

    total, unpriced = sum_costs([r.cost for r in results])
    print("=" * 78)
    print(f"total: ${total:.6f} over {len(picked)} cases"
          + (f", {unpriced} of them unpriced and excluded" if unpriced else ""))


if __name__ == "__main__":
    asyncio.run(main())
"""
Stage A as **two independent calls** — an experiment against :mod:`stage_a`.

Today's stage A asks one model call to do two things in sequence: write the
shortest version of the ANSWER that still answers the QUESTION (STEP 1), then
split the whole ANSWER into claims tagged against it (STEP 2). This module runs
those as two calls that **do not see each other**:

    :mod:`stage_a1`  (question, answer) -> shortest sufficient answer
    :mod:`stage_a2`  (question, answer) -> tagged claims

Both are given the same two fields and neither is given the other's output, so
they are two independent derivations of related quantities rather than a
pipeline. A2 therefore has to carry the core/auxiliary criterion itself instead
of reading it off a string A1 handed it.

**Why independent rather than chained** (Bertan, 2026-08-22). A chained A1 -> A2
would only relocate the coupling. Independent calls make the two outputs
*comparable*: A2's core claims are an assertion about what the shortest
sufficient answer contains, and A1's output is that shortest sufficient answer,
so the two can be checked against each other. Detecting stage A instability on a
case currently costs N runs of the same prompt — design §4.6 took four runs of
`art8_case1` to see 1/1/2/1 core claims. A disagreement between A1 and A2 is
visible in **one** run, which turns an invisible residue into a per-case signal.

``stage_a.py`` is deliberately left untouched. The §4.6 table is the baseline
this is measured against, and a baseline you cannot re-run is not a baseline. If
this version proves better, this module becomes ``stage_a.py``.

**What this experiment does not change.** The atomicity rule drafted on
2026-08-17 (sentence-fragment claims, open item 1) is *not* applied. Two changes
at once cannot be attributed to either, so the fragment residue is expected to
still be present; that is the point.

**A prediction worth recording before the numbers arrive**, so it can be wrong on
the record. Removing STEP 1 from A2's output removes a written intermediate the
model was previously reasoning through, and that scaffold may have been carrying
weight. It is entirely possible A2 alone is *less* stable than today's combined
prompt. The consistency check is what makes that visible either way, and it is a
useful result in both directions.
"""
from __future__ import annotations

import asyncio
from typing import Any, Dict

from src.eval.dataset import TestCase
from src.eval.sufficiency.llm import StageResponse, sum_costs
from src.eval.sufficiency.models import Decomposition
from src.eval.sufficiency.stage_a1 import write_shortest_answer
from src.eval.sufficiency.stage_a2 import tag_claims


async def decompose(
    case: TestCase, model_params: Dict[str, Any]
) -> StageResponse[Decomposition]:
    """
    Stage A as two independent calls — a drop-in for :func:`stage_a.decompose`.

    A1 and A2 receive the same two fields and neither receives the other's output,
    so they go concurrently. The ``supporting_quote`` is withheld structurally: the
    case is unpacked here and neither call takes a :class:`TestCase`, which is a
    stronger guarantee than handing each stage the case and declining to
    interpolate it — the same reasoning as :func:`stage_c.adjudicate`.

    Returns:
        A :class:`StageResponse` carrying a :class:`Decomposition` with A1's
        shortest sufficient answer and A2's claims, and what the pair cost.
        **The two are recorded exactly as returned, and are not reconciled
        here.** A1 returning empty while A2 tags claims core is a disagreement
        between two independent derivations, and it is the signal this experiment
        exists to expose; forcing the tags to agree would erase it. Whatever
        reconciliation the verdict needs is a separate, later decision.

        The cost is the sum of both calls, and **``None`` if either leg went
        unpriced**. Reporting the priced half as the pair's cost would put a
        number on a two-call stage while silently omitting one of the calls —
        the flattening :class:`StageResponse` exists to prevent. This variant is
        twice the calls of the combined stage, which is the trade it is being
        measured on, so its price has to be either right or absent.
    """
    a1, a2 = await asyncio.gather(
        write_shortest_answer(case.question, case.answer, model_params),
        tag_claims(case.question, case.answer, model_params),
    )
    total, unpriced = sum_costs([a1.cost, a2.cost])
    return StageResponse(
        value=Decomposition(
            shortest_sufficient_answer=a1.value,
            claims=a2.value,
        ),
        cost=None if unpriced else total,
        # Concatenated in call order — A1 then A2 — rather than reduced to one.
        # The cost above collapses to `None` when either leg is unpriced, which
        # is right for a number that is only usable whole; ids are not that kind
        # of value. Dropping one because the other is missing would hide the leg
        # that *did* run from anyone trying to look this pair up.
        generation_ids=a1.generation_ids + a2.generation_ids,
    )
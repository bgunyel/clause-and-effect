"""
One phrasing of what a probe run cost, shared by the eight probe scripts.

The arithmetic lives in :func:`src.llm.call.sum_costs`; only the
wording is here. Keeping the two apart is the same split the rest of the
codebase keeps: `llm.py` is library code and returns numbers, and how a number
is put in front of a person is the script's business.

**Unpriced calls are named, never folded into the total.** A run of thirty calls
where four came back without a price has a total that is real and is not the
spend. Every probe therefore says how many it could not price, and says nothing
at all when there were none — the common case against OpenRouter, where the
absence of the clause is itself the signal that the total is complete.

Six decimal places because a single A2 call costs on the order of $0.00003:
rounding to cents would report every probe run in this repository as free.
"""
from __future__ import annotations

from typing import Iterable

from src.eval.sufficiency.llm import StageResponse
from src.llm.call import sum_costs


def format_spend(responses: Iterable[StageResponse]) -> str:
    """
    What the calls behind ``responses`` cost, as one line.

    Takes the responses rather than the costs so a caller cannot forget to pull
    the field out, and so the unpriced count is always computed from the same
    collection the run actually used.
    """
    total, unpriced = sum_costs([r.cost for r in responses])
    line = f"spend: ${total:.6f}"
    if unpriced:
        line += f"  ({unpriced} call(s) returned no price and are not in that total)"
    return line
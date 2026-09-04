"""
One cheap call to every panelist, before any of them is trusted with a case.

`llm_names['sufficiency_judge']` lists nine models. Eight have never been sent a
request: they are **name resolution only**, and nothing so far has confirmed that
OpenRouter serves those ids, that it accepts the sampling settings this config
sends, or that the model can return structured output at all. A panel run over
433 cases discovers all three at the end of the expensive part, one model at a
time. This discovers them for about a thousandth of a cent.

**Four distinct failures are told apart, because they call for different
repairs.** They are collapsed by a bare traceback, which is what a panel run
would give:

| failure | what it means | repair |
|---|---|---|
| construction | no OpenRouter alias for the model | `ai_common` enum work |
| transport | the provider rejected the request | wrong id, or unsupported sampling arg |
| structure | it answered, the answer would not coerce | the model cannot be a judge |
| content | it coerced, and says the wrong thing | judgement, not wiring |

The last row is why the probe grades rather than merely surviving. A model that
returns a well-formed object filled with something it invented has passed every
mechanical check and is useless as a panelist, so the schema asks for two values
this script already knows.

**The call is structured, not a plain `invoke`.** A model can serve text and
still fail `with_structured_output`, and it is the structured path every stage
uses. The 2026-08-23 cost work turned on the same distinction: the price was
read off a *structured* call rather than assumed from a plain one.

**The schema mirrors the shape the stages actually use** — one free string and
one `Literal` — because a `Literal` is where a weaker model's structured output
tends to break, and stages A and C both depend on one.

Each model is isolated: one that cannot be built must not stop the other eight
being tried, since the whole point is to learn the state of the roster in a
single run rather than one failure per run.

Run:

    uv run python -m scripts.probe_panel_roster

(A path invocation fails — `scripts/` lands on `sys.path` instead of the repo
root, and `pythonpath` in `pyproject.toml` is pytest-only.)

Prints rather than logs, consistent with the nine probe scripts beside it and
inconsistent with the rest of the codebase. Recorded as open item 16.
"""
from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass
from typing import Any, Dict, List, Literal, Tuple

from pydantic import BaseModel, Field

from scripts.probe_spend import format_spend
from src.eval.sufficiency.llm import (
    JudgeResponseError,
    StageResponse,
    require_response,
)
from src.llm.structured import build_structured_llm
from src.llm_config import get_llm_config

# What the probe asks for, and what it must get back. Both values are fixed here
# rather than derived, so this file states the expectation instead of computing
# it from the same code that produces it.
_EXPECTED_ANSWER = "Ankara"
_EXPECTED_TAG = "core"

_PROMPT = (
    "You are being checked for wiring, not judgement. Return exactly:\n"
    f'  answer: the capital city of Turkiye (one word)\n'
    f'  tag:    the literal value "{_EXPECTED_TAG}"\n'
)

# How much of a failure message is kept. Provider errors can carry a whole HTML
# error page, and a roster table is unreadable with one embedded in it.
_ERROR_CHARS = 200


class _RosterCheck(BaseModel):
    """
    The smallest schema shaped like the ones the stages use.

    A single string would not exercise the part that breaks: stages A and C both
    require a ``Literal`` field, and a model whose structured output cannot hold
    an enum will pass a one-string probe and fail the first real case.
    """

    answer: str = Field(description="The capital city of Turkiye.")
    tag: Literal["core", "auxiliary"] = Field(description='Exactly "core".')


@dataclass(frozen=True)
class RosterResult:
    """One panelist's outcome. ``response`` is None unless the call returned."""

    model: str
    status: str
    detail: str
    seconds: float
    args_sent: Dict[str, Any]
    args_after: Dict[str, Any]
    response: StageResponse[_RosterCheck] | None


def _grade(check: _RosterCheck) -> Tuple[str, str]:
    """
    Whether a well-formed answer is also the right one.

    Case- and punctuation-insensitive on the free string, exact on the
    ``Literal``: the point is not to test spelling, it is to separate a model
    that read the prompt from one that filled the schema with something plausible.
    """
    answer_ok = _EXPECTED_ANSWER.lower() in check.answer.strip().lower()
    tag_ok = check.tag == _EXPECTED_TAG
    if answer_ok and tag_ok:
        return "OK", f"{check.answer!r} / {check.tag!r}"
    wrong = []
    if not answer_ok:
        wrong.append(f"answer={check.answer!r} (wanted {_EXPECTED_ANSWER!r})")
    if not tag_ok:
        wrong.append(f"tag={check.tag!r} (wanted {_EXPECTED_TAG!r})")
    return "CONTENT", "; ".join(wrong)


async def probe_model(entry: Dict[str, Any]) -> RosterResult:
    """
    Send one call to one panelist and classify whatever comes back.

    ``model_args`` is snapshotted before construction because ``ai_common.get_llm``
    **mutates** the dict it is handed for Google models — it forces
    ``temperature`` to 1.0 on ``gemini-3*`` and pops ``reasoning`` into
    ``thinking_level``. `llm_config.py` gives every entry its own copy so one
    panelist cannot rewrite another's sampling; this run is the first time that
    isolation is exercised against a live Gemini, so the probe reports what each
    model was actually built with rather than what the config nominally says.
    """
    args_sent = dict(entry["model_args"])
    started = time.perf_counter()

    try:
        llm = build_structured_llm(entry, _RosterCheck)
    except Exception as exc:  # noqa: BLE001 — classifying, not handling
        return RosterResult(
            model=str(entry["model"]),
            status="CONSTRUCTION",
            detail=f"{type(exc).__name__}: {str(exc)[:_ERROR_CHARS]}",
            seconds=time.perf_counter() - started,
            args_sent=args_sent,
            args_after=dict(entry["model_args"]),
            response=None,
        )

    args_after = dict(entry["model_args"])

    try:
        response = require_response(await llm.ainvoke(_PROMPT), stage="roster")
    except JudgeResponseError as exc:
        status, detail = "STRUCTURE", str(exc)[:_ERROR_CHARS]
        response = None
    except Exception as exc:  # noqa: BLE001 — a provider error is a result here
        status, detail = "TRANSPORT", f"{type(exc).__name__}: {str(exc)[:_ERROR_CHARS]}"
        response = None
    else:
        status, detail = _grade(response.value)

    return RosterResult(
        model=str(entry["model"]),
        status=status,
        detail=detail,
        seconds=time.perf_counter() - started,
        args_sent=args_sent,
        args_after=args_after,
        response=response,
    )


def print_report(results: List[RosterResult]) -> None:
    """The roster as a table, then the rows that need reading in full."""
    width = max(len(r.model) for r in results)

    print("=" * 78)
    print(f"{'model':{width}}  {'status':12}  {'cost':>10}  {'sec':>6}")
    print("-" * 78)
    for r in results:
        if r.response is None:
            cost = "—"
        elif r.response.cost is None:
            cost = "unpriced"
        else:
            cost = f"${r.response.cost:.6f}"
        print(f"{r.model:{width}}  {r.status:12}  {cost:>10}  {r.seconds:6.1f}")

    ok = [r for r in results if r.status == "OK"]
    print("-" * 78)
    print(f"{len(ok)} of {len(results)} panelists usable")

    # Only the entries that need explaining. A run where every model works
    # should print a table and almost nothing else.
    for r in results:
        if r.status != "OK":
            print(f"\n{r.model} — {r.status}\n   {r.detail}")

    # The mutation check, reported only when a model's args changed under it.
    # Silence here is the assertion that eight of nine were untouched.
    mutated = [r for r in results if r.args_sent != r.args_after]
    print()
    if mutated:
        for r in mutated:
            print(f"{r.model}: model_args rewritten by get_llm")
            print(f"   sent:  {r.args_sent}")
            print(f"   after: {r.args_after}")
    else:
        print("model_args: unchanged for every panelist")

    priced = [r.response for r in results if r.response is not None]
    print(format_spend(priced) if priced else "spend: $0.000000 (no call returned)")


async def main() -> None:
    entries = get_llm_config()["sufficiency_judge"]

    print(f"probing {len(entries)} panelists on "
          f"{entries[0]['model_provider']}, one call each\n")

    # Concurrent, and each coroutine catches its own failure, so the sweep
    # reports the whole roster in one pass instead of stopping at the first
    # model that cannot be reached.
    results = await asyncio.gather(*[probe_model(e) for e in entries])
    print_report(list(results))


def manual_test() -> None:
    entries = get_llm_config()["sufficiency_judge"]

    structured_llm = build_structured_llm(entries[3], _RosterCheck)
    response = structured_llm.invoke(_PROMPT)

    dummy = -32


if __name__ == "__main__":
    asyncio.run(main())
    #manual_test()
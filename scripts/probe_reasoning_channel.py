"""
Does asking for `json_schema` cost a model its reasoning?

The panel calls three of its eight members through `response_format` and five
through function calling, because neither channel works for every model
(`llm_config.structured_output`, measured 2026-08-23). That concession breaks
the premise the rest of `llm_config` is built on — every panelist runs identical
settings, so a disagreement between two of them is a disagreement **about the
case**. If the channel also changes how much the model thinks, then three
panelists judge on a smaller budget than the other five, inside the comparison
the panel exists to make.

The suspicion is not hypothetical and it is not general: MiniMax reported
`output_token_details: {'reasoning': 0}` under `json_schema` while producing
reasoning on the tool path. One observation, one model, noticed in passing.

**This measures it as a paired comparison.** Each model answers the *same real
A2 prompt* through both channels, so the only thing that differs within a pair
is the channel. Cross-model comparison is meaningless here — models differ in
how much they reason for reasons that have nothing to do with this — and a
per-model average over both channels would hide the very difference being
looked for.

**A failed call is still a measurement, and this is why the item-3 plumbing had
to come first.** MiniMax's endpoint accepts no tools at all and DeepSeek V4
Flash times out under `response_format`: exactly the cells where the channel is
doing something unusual are the cells where the call does not come back clean.
`usage_metadata` rides on the same message as the price, so a call that answered
in prose still reports what it spent thinking. Discarding failures would leave
the question unanswerable for the models it is really about.

**What this sample can and cannot support.** Reasoning token counts vary between
runs of the same prompt, and this is one run per cell. So a *ratio* — 114 against
90 — is not a finding here. A **categorical** split is: a model that reports a
positive count on one channel and exactly `0` on the other is not thinking less,
it is not thinking, and no amount of run-to-run variance produces a clean zero.
The report says which of the two it found rather than leaving the reader to
assume the stronger reading. `None` is kept distinct from `0` throughout: one is
a provider not reporting, the other is a provider reporting nothing spent.

Two cases rather than six, because the pairing doubles every call and Grok alone
runs about $0.07 per case. They are chosen at the ends of the range: a short
two-claim answer and the ten-item enumeration that is the panel's one contested
case, so a suppression that only shows up under load has somewhere to show.

**This is not a statistically meaningful sample, and nothing here should be read
as a rate — Bertan, 2026-08-25.** Two cases of 433, eight models, one run per
cell. It is sized to detect a *categorical* effect cheaply, and that is the only
kind of claim it makes. In particular:

  - A model marked SUPPRESSED or INTERMITTENT on this sample has produced a
    clean zero, which is a real observation about that call. It is **not**
    evidence about how often, on which cases, or under what load.
  - A model marked "no suppression" has been checked on two cases. That is the
    weakest possible negative result and does not clear it.
  - Nothing here supports comparing models to each other.

The intended repeat is a larger case set — stratified across answer types rather
than picked at the ends — and possibly a wider roster, with repeats per cell so
that intermittency can be separated from run-to-run variance. That is the same
wall `probe_a2_stability.py` hit at N=5, recorded there: four samples of one
instrument read 4/6, 3/6, 0/6, 0/6, and between-sample variance swamped the
signal. Decide the sample size before spending the calls.

Run:

    uv run python -m scripts.probe_reasoning_channel
"""
import asyncio
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from scripts.probe_a2_stability import REPORTS_DIR, Report, describe_tree
from src.clause_and_effect.chunking.chunk_store import git_state
from src.eval.dataset import load_tier1
from src.eval.sufficiency.llm import JudgeResponseError
from src.llm.call import CallRecord, sum_costs
from src.eval.sufficiency.stage_a2 import tag_claims
from src.llm_config import FUNCTION_CALLING, JSON_SCHEMA, get_llm_config

_REPO_ROOT = Path(__file__).resolve().parents[1]

# The two channels a panelist can be assigned. `TOOL_CALL_AUTO` is deliberately
# not here: it is GLM's workaround, GLM is out of the roster on latency, and no
# panelist is called through it.
CHANNELS = (FUNCTION_CALLING, JSON_SCHEMA)

# Both ends of the range. `art7_case4` is a short answer whose expected output is
# one core claim and one auxiliary; `art15_case1` is the ten-item enumeration —
# the one case the panel splits on, and the one with the most to think about.
CASE_IDS = ("gdpr_art7_case4", "gdpr_art15_case1")

# The panel's own deadline, unchanged. DeepSeek V4 Flash timed out three times at
# this limit under `json_schema` (63s mean against 7s on tools), and that is a
# result this probe should record rather than wait out.
CALL_TIMEOUT_SECONDS = 120


@dataclass(frozen=True)
class Cell:
    """One model, one case, one channel."""

    model: str
    case_id: str
    channel: str
    status: str                 # OK, STRUCTURE, TIMEOUT, TRANSPORT
    call: Optional[CallRecord]  # None only when nothing came back at all
    claims: Optional[int]
    seconds: float
    detail: str

    @property
    def reasoning(self) -> Optional[int]:
        return None if self.call is None else self.call.reasoning_tokens

    @property
    def cost(self) -> Optional[float]:
        return None if self.call is None else self.call.cost


def short_name(model) -> str:
    return str(model).split(".", 1)[-1]


async def run_cell(case, entry: Dict, channel: str) -> Cell:
    """
    One call, and never an exception.

    The entry is copied with its channel overridden rather than reconfigured
    globally, so `build_structured_llm` takes the same path it takes in a panel run —
    including its refusal to build a model whose channel it does not recognise.
    """
    params = dict(entry, structured_output=channel)
    started = time.perf_counter()
    try:
        response = await asyncio.wait_for(
            tag_claims(case.question, case.answer, params),
            timeout=CALL_TIMEOUT_SECONDS,
        )
    except asyncio.TimeoutError:
        return Cell(
            model=short_name(entry["model"]), case_id=case.case_id, channel=channel,
            status="TIMEOUT", call=None, claims=None,
            seconds=time.perf_counter() - started,
            detail=f"no response within {CALL_TIMEOUT_SECONDS}s",
        )
    except JudgeResponseError as exc:
        # The interesting failure: the model answered, the answer would not
        # coerce, and the message it came back on still says what the call spent
        # reasoning. This is the cell MiniMax produces on the tool channel.
        return Cell(
            model=short_name(entry["model"]), case_id=case.case_id, channel=channel,
            status="STRUCTURE", call=exc.call, claims=None,
            seconds=time.perf_counter() - started,
            detail=str(exc)[:200],
        )
    except Exception as exc:  # noqa: BLE001 — a provider error is a result here
        return Cell(
            model=short_name(entry["model"]), case_id=case.case_id, channel=channel,
            status="TRANSPORT", call=None, claims=None,
            seconds=time.perf_counter() - started,
            detail=f"{type(exc).__name__}: {str(exc)[:200]}",
        )
    return Cell(
        model=short_name(entry["model"]), case_id=case.case_id, channel=channel,
        status="OK", call=response.calls[0] if response.calls else None,
        claims=len(response.value),
        seconds=time.perf_counter() - started,
        detail="",
    )


def render_reasoning(cell: Optional[Cell]) -> str:
    """
    One cell's reasoning count, with the two kinds of nothing kept apart.

    `0` is the provider saying the call spent no tokens thinking — the finding
    this probe exists to detect. `—` is the provider not saying, and `no data`
    is no call to say anything about. Rendering all three as a blank would let a
    reader read a suppression out of a timeout.
    """
    if cell is None or cell.call is None:
        return "no data"
    if cell.call.reasoning_tokens is None:
        return "—"
    return str(cell.call.reasoning_tokens)


def verdict_for(pairs: List[Tuple[Optional[Cell], Optional[Cell]]]) -> Tuple[str, str]:
    """
    What one model's paired cells say about the channel, and on what basis.

    Only two readings are offered, because only two are supportable at one run
    per cell. **suppressed** means some case reported a positive count on one
    channel and exactly zero on the other: a clean zero is categorical, and
    run-to-run variance does not produce one. **no suppression** means every
    case that reported both sides reported the same kind of number on both —
    which does not mean the counts were equal, and the table beside it shows
    they often are not.

    Anything else is `inconclusive` with the reason named, because "we could not
    measure this model" and "this model is unaffected" are the two conclusions
    most worth not confusing.
    """
    comparable = [
        (tools.call.reasoning_tokens, schema.call.reasoning_tokens)
        for tools, schema in pairs
        if tools and schema and tools.call and schema.call
        and tools.call.reasoning_tokens is not None
        and schema.call.reasoning_tokens is not None
    ]
    if not comparable:
        return "inconclusive", "no case reported reasoning on both channels"

    flips = [(t, s) for t, s in comparable if (t > 0) != (s > 0)]
    if flips:
        direction = "json_schema" if flips[0][1] == 0 else "function_calling"
        # A model whose every comparable case went to zero is being suppressed by
        # the channel. One that flipped on some and not others is doing something
        # the channel alone does not explain, and calling both "suppressed" would
        # hide the more awkward of the two findings — which is the one that says
        # the effect is not a stable property of the model.
        label = "SUPPRESSED" if len(flips) == len(comparable) else "INTERMITTENT"
        return label, (
            f"{len(flips)} of {len(comparable)} comparable case(s) went to zero "
            f"under {direction}"
        )
    if all(t == 0 and s == 0 for t, s in comparable):
        return "no reasoning either way", (
            f"both channels reported 0 on all {len(comparable)} comparable case(s)"
        )
    return "no suppression", (
        f"both channels reported a positive count on all {len(comparable)} "
        f"comparable case(s)"
    )


def emit_provenance(out: Report, started: datetime, entries: List[Dict]) -> None:
    commit, dirty = git_state(_REPO_ROOT)
    out(f"# Reasoning tokens by structured-output channel")
    out()
    out("Does asking for `json_schema` cost a model its reasoning? Each model "
        "answers the same A2 prompt through both channels; only the channel "
        "differs within a pair.")
    out()
    out("| | |")
    out("|---|---|")
    out(f"| started | {started.strftime('%Y-%m-%dT%H:%M:%SZ')} |")
    out(f"| commit | `{commit[:12]}` |")
    out(f"| working tree | {describe_tree(dirty)} |")
    out(f"| provider | `{entries[0]['model_provider']}` |")
    out(f"| temperature | {entries[0]['model_args']['temperature']} |")
    out(f"| reasoning effort | {entries[0]['model_args'].get('reasoning_effort')} |")
    out(f"| channels | {', '.join(f'`{c}`' for c in CHANNELS)} |")
    out(f"| cases | {', '.join(f'`{c}`' for c in CASE_IDS)} |")
    out(f"| calls | {len(CASE_IDS) * len(entries) * len(CHANNELS)} |")
    out(f"| per-call timeout | {CALL_TIMEOUT_SECONDS}s |")
    out("| stage | `src/eval/sufficiency/stage_a2.py` |")
    out("| script | `scripts/probe_reasoning_channel.py` |")
    out()
    out("`—` is a call that reported no reasoning field; `0` is a call that "
        "reported spending nothing on reasoning; `no data` is a call that did "
        "not come back. The three are different findings.")
    out()


async def main() -> None:
    started = datetime.now(timezone.utc)
    path = REPORTS_DIR / (
        f"{started.strftime('%Y-%m-%d')}-reasoning-channel-"
        f"{started.strftime('%H%M%S')}.md"
    )

    loaded = {c.case_id: c for c in load_tier1()}
    missing = [c for c in CASE_IDS if c not in loaded]
    if missing:
        raise SystemExit(f"case ids not found in the golden set: {missing}")

    entries = get_llm_config()["sufficiency_judge"]
    names = [short_name(e["model"]) for e in entries]

    out = Report()
    emit_provenance(out, started, entries)

    # (model, case, channel) -> Cell. One case at a time so every pair in a case
    # is drawn from the same moment; both channels of a model go concurrently,
    # since the pairing is what must be held together and the case is what must
    # not drift.
    cells: Dict[Tuple[str, str, str], Cell] = {}
    for case_id in CASE_IDS:
        case = loaded[case_id]
        results = await asyncio.gather(*[
            run_cell(case, entry, channel)
            for entry in entries for channel in CHANNELS
        ])
        for cell in results:
            cells[(cell.model, cell.case_id, cell.channel)] = cell
        slowest = max(results, key=lambda c: c.seconds)
        failed = sum(1 for c in results if c.status != "OK")
        print(f"  {case_id} complete ({failed} of {len(results)} did not return "
              f"claims)  [{slowest.seconds:.0f}s, slowest {slowest.model}]",
              flush=True)

    out(f"Completed {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}.")
    out()

    out("## Reasoning tokens, paired")
    out()
    for case_id in CASE_IDS:
        out(f"**{case_id}**")
        out()
        out("| panelist | function_calling | json_schema | tools status | "
            "json_schema status |")
        out("|---|---:|---:|---|---|")
        for name in names:
            tools = cells.get((name, case_id, FUNCTION_CALLING))
            schema = cells.get((name, case_id, JSON_SCHEMA))
            out(f"| `{name}` | {render_reasoning(tools)} | "
                f"{render_reasoning(schema)} | "
                f"{tools.status if tools else '—'} | "
                f"{schema.status if schema else '—'} |")
        out()

    out("## Verdict per model")
    out()
    out("One run per cell, so only a categorical difference is claimed. See the "
        "module docstring on why a ratio is not a finding here.")
    out()
    out("| panelist | assigned channel | verdict | basis |")
    out("|---|---|---|---|")
    assigned = {short_name(e["model"]): str(e["structured_output"]) for e in entries}
    for name in names:
        pairs = [
            (cells.get((name, cid, FUNCTION_CALLING)), cells.get((name, cid, JSON_SCHEMA)))
            for cid in CASE_IDS
        ]
        verdict, basis = verdict_for(pairs)
        out(f"| `{name}` | `{assigned[name]}` | {verdict} | {basis} |")
    out()

    out("## Every call")
    out()
    out("| case | panelist | channel | status | claims | reasoning | cost | generation |")
    out("|---|---|---|---|---:|---:|---:|---|")
    for case_id in CASE_IDS:
        for name in names:
            for channel in CHANNELS:
                cell = cells.get((name, case_id, channel))
                if cell is None:
                    continue
                gen = (f"`{cell.call.generation_id}`"
                       if cell.call and cell.call.generation_id else "—")
                cost = "—" if cell.cost is None else f"${cell.cost:.6f}"
                claims = "—" if cell.claims is None else str(cell.claims)
                out(f"| {case_id} | `{name}` | `{channel}` | {cell.status} | "
                    f"{claims} | {render_reasoning(cell)} | {cost} | {gen} |")
    out()

    every = list(cells.values())
    total, unpriced = sum_costs([c.cost for c in every])
    out(f"**Spend: ${total:.6f}** over {len(every)} call(s)"
        + (f"; {unpriced} returned no price" if unpriced else "") + ".")
    out()

    failures = [c for c in every if c.status != "OK"]
    if failures:
        out("## Calls that returned no claims")
        out()
        out("Kept because they still measured the channel — and because the "
            "cells where a channel misbehaves are the cells this probe is about.")
        out()
        for cell in failures:
            out(f"- `{cell.model}` / {cell.case_id} / `{cell.channel}` "
                f"[{cell.status}] {cell.detail}")
        out()

    out.write(path)
    print(f"\nreport written to {path}")


if __name__ == "__main__":
    asyncio.run(main())
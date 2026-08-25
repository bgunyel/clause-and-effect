"""
Run A2 over the six §4.6 cases on every panelist, and report where they agree.

The first panel measurement (§8), and it answers one question: **is there a
dominant majority?** A panel is only worth its cost if its members mostly agree
and their disagreements are informative. If eight models produce eight different
answers, the majority vote §8.3 specifies is arithmetic over noise.

This is the panel counterpart of ``probe_a2_stability.py``. That script varies
the *run* and holds the model fixed; this one varies the *model* and runs each
once. The two failure modes are different and neither substitutes for the other:
a model that disagrees with the panel on every case is a bad panelist, whereas a
model that disagrees with *itself* across runs is a bad instrument.

**Agreement is measured on core coverage, not on claims or text.** Design §4.6's
metric was core count, which the 2026-08-22 reframing invalidated: splitting one
core claim into two changes nothing about what the quote must contain, while
moving material across the core/auxiliary line removes a requirement silently.
So two panelists agree when they mark **the same words of the gold answer core**,
however they carved them up. ``core_coverage`` is imported from the stability
script rather than reimplemented, because two definitions of agreement would
drift and the whole point is that these numbers are comparable to that sample's.

**Two views of agreement, because one of them lies in a predictable direction.**

    dominant bloc    how many panelists produced an IDENTICAL coverage set
    per-word vote    for each answer word, how many panelists marked it core

The bloc is exact-match and therefore brittle: eight models that differ by one
stopword each produce eight blocs of one, reporting total disagreement where
there is near-consensus. The per-word vote does not have that failure and shows
*where* the panel splits, which is what a contested case needs. Neither is
sufficient alone, so both are reported and the contested words are listed.

**Coverage is approximate, and it is approximate in both directions.** A word may
be claimed by several claims (A2 repeats an enumeration's stem into every item),
and a claim may reword. Set comparison under-reports differences that reshuffle
the same vocabulary and over-reports ones that reword. A coverage difference is a
prompt to read the claims printed beneath it, not a verdict on its own.

**Stopwords are not filtered.** They inflate every coverage set and appear in the
contested list, which looks like noise and is: filtering them would mean a
stoplist inside an eval instrument, deciding which words count as content. Left
visible, they are obvious to a reader; removed, they would be a silent editorial
judgement in the middle of a measurement.

**One panelist failing costs one cell, not the run.** ``return_exceptions=True``
throughout: a `JudgeResponseError` from one model on one case must not discard
the other 47 calls, and the loss is reported rather than quietly shrinking N.

**Cost is reported per panelist, because that is the number the panel is planned
on.** The roster probe (2026-08-23) found a 110x spread across these eight on a
single trivial call. Over 433 cases x 3 stages x 8 members, which panelists are
in the panel decides the run's cost by two orders of magnitude, so a report that
says who agreed but not what they charged cannot be used to choose.

**Failed calls are priced too, since 2026-08-25.** The three samples before that
date said their totals were "a floor - failed calls are unpriced and may still
have been billed", which understated them by 11, 6 and 3 calls. It was never
true: a response that would not coerce arrives on a message carrying its price,
and the judge discarded it while raising. A model that fails half its cases while
being billed for them is expensive in a way "cost of answers" alone reports as
cheap, which is exactly how MiniMax read at 2/6. What stays genuinely unknown is
narrower and is now named as such: a timeout, where nothing came back at all and
the generation may have completed and been billed after we stopped waiting.

**Every call is listed with its provider-side generation id.** That table is the
only thing in this report the OpenRouter console can contradict - and on
2026-08-23 it did, showing as successful six MiniMax generations recorded here
as failures. Reconciling the two took a hand-run diagnostic, because nothing in
the run kept an id.

Run:

    uv run python -m scripts.probe_a2_panel
"""
import asyncio
import time
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from scripts.probe_a2_baseline_cases import CASES
from scripts.probe_a2_stability import (
    REPORTS_DIR,
    Report,
    core_coverage,
    describe_tree,
    words,
)
from src.clause_and_effect.chunking.chunk_store import git_state
from src.eval.dataset import load_tier1
from src.eval.sufficiency.llm import CallRecord, JudgeResponseError, sum_costs
from src.eval.sufficiency.stage_a2 import tag_claims
from src.llm_config import get_llm_config

_REPO_ROOT = Path(__file__).resolve().parents[1]

# How many contested words a case's table lists before summarising the rest. A
# ten-item enumeration can contest most of its vocabulary, and a table that
# unrolls it stops being readable at exactly the case that most needs reading.
_MAX_CONTESTED_SHOWN = 12

# How long one panelist gets for one case, retries included.
#
# **Nothing else bounds this run.** `get_llm`'s OpenRouter branch builds
# `ChatOpenRouter` without a `timeout`, and `.with_retry(stop_after_attempt=3)`
# retries *exceptions* — a request that never returns never raises one. Since
# every panelist on a case is gathered, one hung request stalls the case with no
# upper bound: observed 2026-08-23, a 9-panelist run sat for 19 minutes having
# used 4 seconds of CPU, with eight sockets open and zero bytes arriving, where
# the 8-panelist run before it had finished in 3m56s.
#
# 120s is roughly double the slowest call the previous run recorded (Grok at a
# 32s mean). A panelist that needs longer than that is reporting something about
# itself worth recording, which is why the timeout produces a `Cell` like any
# other failure rather than killing the run.
CALL_TIMEOUT_SECONDS = 120


@dataclass(frozen=True)
class Cell:
    """
    One panelist's result on one case.

    ``cost`` is what the call was charged **whether or not it produced claims**.
    Until 2026-08-25 a failed cell was recorded as costing nothing knowable,
    which is how three of these reports came to describe their totals as a floor:
    a call that returned prose instead of a tool call was billed, and the price
    was on the very message the error was built from. ``ok`` still gates the
    *agreement* arithmetic — a failed cell judges nothing — but it no longer
    gates the accounting.

    ``calls`` is what makes a row checkable at the provider: the generation id,
    the price and the reasoning tokens of every call behind the cell. Empty when
    nothing came back to record (a timeout, a transport error).
    """

    model: str
    claims: Optional[list]      # None when the call failed
    coverage: Optional[frozenset]
    cost: Optional[float]
    seconds: float
    error: Optional[str]
    calls: Tuple[CallRecord, ...]

    @property
    def ok(self) -> bool:
        return self.claims is not None


def short_name(model) -> str:
    """`ModelNames.GROK_4_6` rendered for a table cell."""
    return str(model).split(".", 1)[-1]


async def run_cell(case, model_params: Dict) -> Cell:
    """
    One panelist, one case, one call — and never an exception.

    A failure is a *result* here, not an interruption: the report exists to say
    what the roster did, and a model that cannot answer a case has told us
    something about itself that a traceback would turn into a lost run.
    """
    started = time.perf_counter()
    try:
        response = await asyncio.wait_for(
            tag_claims(case.question, case.answer, model_params),
            timeout=CALL_TIMEOUT_SECONDS,
        )
    except asyncio.TimeoutError:
        # Named separately from every other failure. A model that answers wrongly
        # and a model that never answers are different findings about a panelist,
        # and the second one is invisible without this because nothing else in
        # the stack imposes a deadline.
        #
        # This is the one failure whose spend stays genuinely unknown: we stopped
        # waiting, so nothing came back to read a price or an id off, and the
        # generation may well have completed and been billed on the provider's
        # side after we walked away.
        return Cell(
            model=short_name(model_params["model"]),
            claims=None,
            coverage=None,
            cost=None,
            seconds=time.perf_counter() - started,
            error=f"TIMEOUT: no response within {CALL_TIMEOUT_SECONDS}s",
            calls=(),
        )
    except JudgeResponseError as exc:
        # The model answered and the answer would not coerce — the failure that
        # was miscounted as a judgement for three panel runs, when in fact
        # MiniMax was returning §4.6's expected output as prose. It is billed, it
        # exists at the provider under an id, and both now travel on the
        # exception. This branch precedes the general one so those two facts
        # survive; catching `Exception` first would discard them.
        return Cell(
            model=short_name(model_params["model"]),
            claims=None,
            coverage=None,
            cost=exc.cost,
            seconds=time.perf_counter() - started,
            error=f"{type(exc).__name__}: {str(exc)[:200]}",
            calls=(exc.call,),
        )
    except Exception as exc:  # noqa: BLE001 — the failure is the datum
        # A transport error: the provider rejected or dropped the request, so
        # there is no generation to point at and nothing was charged for one.
        return Cell(
            model=short_name(model_params["model"]),
            claims=None,
            coverage=None,
            cost=None,
            seconds=time.perf_counter() - started,
            error=f"{type(exc).__name__}: {str(exc)[:200]}",
            calls=(),
        )
    return Cell(
        model=short_name(model_params["model"]),
        claims=response.value,
        coverage=core_coverage(response.value, case.answer),
        cost=response.cost,
        seconds=time.perf_counter() - started,
        error=None,
        calls=response.calls,
    )


def failed_spend(cells: List[Cell]) -> str:
    """
    What the failed calls among ``cells`` cost, as a phrase.

    A zero is **not** printed when nothing among them was priced. "$0.000000"
    for a case whose only failure was a timeout reads as *the failure was free*,
    which is the understatement this column exists to remove — the previous
    reports made the same claim in words. The unknown count is always shown,
    because it is the part of the number that is missing rather than the part
    that happens to be small.

    One formatter for both the per-case line and the panelist table, so the two
    cannot drift into disagreeing about the same calls.
    """
    failed = [c for c in cells if not c.ok]
    if not failed:
        return "—"
    total, unknown = sum_costs([c.cost for c in failed])
    if unknown == len(failed):
        return f"unknown ({unknown} call(s) returned no price)"
    return f"${total:.6f}" + (f" (+{unknown} unknown)" if unknown else "")


def dominant_bloc(cells: List[Cell]):
    """
    The largest set of panelists whose core coverage is byte-identical.

    Returns ``(size, coverage, blocs)``. Exact-match by construction — see the
    module docstring on why this is reported next to the per-word vote rather
    than instead of it.
    """
    groups = Counter(c.coverage for c in cells if c.ok)
    if not groups:
        return 0, frozenset(), []
    coverage, size = groups.most_common(1)[0]
    return size, coverage, groups.most_common()


def word_votes(cells: List[Cell], answer: str) -> Dict[str, int]:
    """
    How many panelists marked each answer word core.

    Keyed on the answer's own vocabulary rather than on what the claims
    contained, so a word no panelist marked still appears — with zero votes.
    That is the difference between "the panel agreed to leave this out" and
    "nobody considered it", and only the first is visible if the tally is built
    from the claims.
    """
    votes = {w: 0 for w in words(answer)}
    for cell in cells:
        if not cell.ok:
            continue
        for word in cell.coverage:
            if word in votes:
                votes[word] += 1
    return votes


def emit_provenance(out: Report, started: datetime, entries: List[Dict]) -> None:
    """The header, written before the first call rather than after the last."""
    commit, dirty = git_state(_REPO_ROOT)
    out(f"# A2 panel — {len(CASES)} cases × {len(entries)} panelists")
    out()
    out("| | |")
    out("|---|---|")
    out(f"| started | {started.strftime('%Y-%m-%dT%H:%M:%SZ')} |")
    out(f"| commit | `{commit[:12]}` |")
    out(f"| working tree | {describe_tree(dirty)} |")
    out(f"| provider | `{entries[0]['model_provider']}` |")
    out(f"| temperature | {entries[0]['model_args']['temperature']} |")
    out(f"| reasoning effort | {entries[0]['model_args'].get('reasoning_effort')} |")
    out(f"| calls | {len(CASES) * len(entries)} |")
    out(f"| per-call timeout | {CALL_TIMEOUT_SECONDS}s |")
    # Which channel the schema was requested through. Not cosmetic: the
    # 2026-08-23 16:58 sample ran on function calling, where MiniMax answered
    # 2 of 6 because its endpoint does not accept tools at all. Two samples
    # taken through different channels are not comparable, and nothing else in
    # this header would say so.
    modes = sorted({str(e.get("structured_output")) for e in entries})
    out(f"| structured output | {', '.join(f'`{m}`' for m in modes)} |")
    out("| stage | `src/eval/sufficiency/stage_a2.py` |")
    out("| script | `scripts/probe_a2_panel.py` |")
    out("| cases | `scripts/probe_a2_baseline_cases.py` |")
    out()
    out("Panel:")
    out()
    out("| # | model |")
    out("|---:|---|")
    for i, entry in enumerate(entries, 1):
        out(f"| {i} | `{short_name(entry['model'])}` |")
    out()


def emit_case(out: Report, baseline, case, cells: List[Cell]) -> None:
    """One case: who said what, where the panel split, and what it cost."""
    n_ok = sum(1 for c in cells if c.ok)
    size, bloc_coverage, blocs = dominant_bloc(cells)
    votes = word_votes(cells, case.answer)

    unanimous = [w for w, v in votes.items() if v == n_ok and v > 0]
    contested = sorted(
        ((w, v) for w, v in votes.items() if 0 < v < n_ok),
        key=lambda wv: (-wv[1], wv[0]),
    )
    never = [w for w, v in votes.items() if v == 0]

    out(f"## {case.case_id}")
    out()
    out(f"*{case.answer_type}* — {baseline.probes}")
    out()
    out(f"**Q:** {case.question}")
    out()
    out(f"**A:** {case.answer}")
    out()
    out(f"§4.6 correct output: {baseline.core_baseline}. "
        f"Basis: {baseline.basis}")
    out()

    out("| panelist | claims | core | coverage | in bloc | cost | sec |")
    out("|---|---:|---:|---:|:---:|---:|---:|")
    for cell in cells:
        if not cell.ok:
            # The cost column is filled in even here. A failed call that was
            # billed is exactly the row a reader would otherwise skip past.
            failed_cost = "—" if cell.cost is None else f"${cell.cost:.6f}"
            out(f"| `{cell.model}` | — | — | — | — | {failed_cost} | "
                f"{cell.seconds:.1f} |")
            continue
        n_core = sum(1 for c in cell.claims if c.tag == "core")
        in_bloc = "yes" if cell.coverage == bloc_coverage else "—"
        cost = "unpriced" if cell.cost is None else f"${cell.cost:.6f}"
        out(f"| `{cell.model}` | {len(cell.claims)} | {n_core} | "
            f"{len(cell.coverage)} | {in_bloc} | {cost} | {cell.seconds:.1f} |")
    out()

    out("| | |")
    out("|---|---|")
    out(f"| panelists answering | {n_ok}/{len(cells)} |")
    out(f"| distinct coverage sets | {len(blocs)} |")
    out(f"| dominant bloc | **{size}/{n_ok}** |")
    out(f"| words core to all {n_ok} | {len(unanimous)} |")
    out(f"| contested words | {len(contested)} |")
    out(f"| words no panelist marked core | {len(never)} |")
    # Only cells that returned. A failed call also carries ``cost=None``, and
    # folding it in would report it as *unpriced* — which in this codebase means
    # a call that happened and came back without a price. The two are opposite
    # facts about the same missing number, and `StageResponse` exists to keep
    # them apart; a report that merges them undoes that at the last step.
    case_total, case_unpriced = sum_costs([c.cost for c in cells if c.ok])
    out(f"| spend | ${case_total:.6f}"
        + (f" ({case_unpriced} unpriced)" if case_unpriced else "") + " |")
    if any(not c.ok for c in cells):
        out(f"| spend on failed calls | {failed_spend(cells)} |")
    out()

    if contested:
        out("Contested words — how many of "
            f"{n_ok} panelists marked each core:")
        out()
        out("```")
        shown = contested[:_MAX_CONTESTED_SHOWN]
        out("  ".join(f"{w}={v}" for w, v in shown))
        if len(contested) > len(shown):
            out(f"... and {len(contested) - len(shown)} more")
        out("```")
        out()

    for cell in cells:
        if not cell.ok:
            out(f"`{cell.model}`: **call failed** — {cell.error}")
            out()
            continue
        tags = [c.tag for c in cell.claims]
        out(f"`{cell.model}`: {len(cell.claims)} claims  {tags}")
        out()
        out("```")
        core_texts = [c.text for c in cell.claims if c.tag == "core"]
        for text in core_texts:
            out(f"core  {text}")
        if not core_texts:
            # A real result, not a rendering gap: it says the gold answer does
            # not answer its own question.
            out("(no core claims)")
        out("```")
        out()


def emit_agreement_matrix(out: Report, grid: Dict[str, List[Cell]], names: List[str]) -> None:
    """
    Pairwise: on how many of the six cases did these two mark the same words core?

    The panel-level view the per-case tables cannot give. A member that agrees
    with everyone is redundant rather than valuable; one that agrees with nobody
    is either the only one reading the case correctly or the one to drop, and
    §8.3 keeps non-unanimity precisely because that distinction is a human's to
    make.
    """
    out("## Pairwise agreement")
    out()
    out(f"Cases (of {len(CASES)}) where two panelists marked identical core "
        f"coverage. Both must have answered for a case to count.")
    out()
    width = max(len(n) for n in names)
    out("| " + " " * width + " | " + " | ".join(f"`{n}`" for n in names) + " |")
    out("|---" * (len(names) + 1) + "|")
    for a in names:
        row = []
        for b in names:
            if a == b:
                row.append("·")
                continue
            agree = 0
            for cells in grid.values():
                ca = next(c for c in cells if c.model == a)
                cb = next(c for c in cells if c.model == b)
                if ca.ok and cb.ok and ca.coverage == cb.coverage:
                    agree += 1
            row.append(str(agree))
        out(f"| `{a}` | " + " | ".join(row) + " |")
    out()


def emit_panelist_summary(out: Report, grid: Dict[str, List[Cell]], names: List[str]) -> None:
    """Per panelist: how often it sat in the bloc, what it cost, how slow it was."""
    out("## Panelists")
    out()
    # Two cost columns rather than one. The panel is planned on what a panelist
    # charges, and a model that fails half its cases while being billed for them
    # is expensive in a way a single "cost of answers" column reports as cheap —
    # which is precisely how MiniMax read at 2/6 in the 2026-08-23 samples.
    out("| panelist | answered | in dominant bloc | cost of answers | "
        "cost of failures | mean sec |")
    out("|---|---:|---:|---:|---:|---:|")
    for name in names:
        cells = [next(c for c in grid[case_id] if c.model == name) for case_id in grid]
        answered = sum(1 for c in cells if c.ok)
        in_bloc = 0
        for case_id, cell in zip(grid, cells):
            _, bloc_coverage, _ = dominant_bloc(grid[case_id])
            if cell.ok and cell.coverage == bloc_coverage:
                in_bloc += 1
        total, unpriced = sum_costs([c.cost for c in cells if c.ok])
        cost = f"${total:.6f}" + (f" ({unpriced} unpriced)" if unpriced else "")
        mean = sum(c.seconds for c in cells) / len(cells)
        out(f"| `{name}` | {answered}/{len(CASES)} | {in_bloc}/{len(CASES)} | "
            f"{cost} | {failed_spend(cells)} | {mean:.1f} |")
    out()


def emit_generations(out: Report, grid: Dict[str, List[Cell]]) -> None:
    """
    Every call in the run, by the id it has at the provider.

    The join table. Each row can be pasted into the OpenRouter console, which is
    the only place that can contradict this report — and on 2026-08-23 it did:
    the panel recorded MiniMax as failing six cases the console showed as
    successful, billed generations, and reconciling the two took a hand-run
    diagnostic because nothing here kept an id.

    Failed calls are listed **beside** successful ones rather than in a section
    of their own, because the question this table answers — "what did we actually
    send, and what came back?" — does not distinguish them.
    """
    out("## Generations")
    out()
    out("Every call, by its provider-side id. `—` means nothing came back to "
        "identify the call: the request timed out or was rejected before a "
        "generation existed.")
    out()
    out("| case | panelist | result | cost | reasoning | generation |")
    out("|---|---|---|---:|---:|---|")
    for case_id, cells in grid.items():
        for cell in cells:
            result = "answered" if cell.ok else "failed"
            cost = "—" if cell.cost is None else f"${cell.cost:.6f}"
            # `0` and `—` are different answers and the column keeps them apart.
            # A zero is the provider saying this call did no reasoning, which is
            # the suppression the mixed-channel panel is suspected of causing; a
            # dash is the provider not saying, which is evidence of nothing.
            reasoning = ", ".join(
                "—" if c.reasoning_tokens is None else str(c.reasoning_tokens)
                for c in cell.calls
            ) or "—"
            ids = ", ".join(f"`{c.generation_id}`" if c.generation_id
                            else "unidentified" for c in cell.calls) or "—"
            out(f"| {case_id} | `{cell.model}` | {result} | {cost} | "
                f"{reasoning} | {ids} |")
    out()


async def main() -> None:
    started = datetime.now(timezone.utc)
    path = REPORTS_DIR / (
        f"{started.strftime('%Y-%m-%d')}-a2-panel-"
        f"{started.strftime('%H%M%S')}.md"
    )

    loaded = {c.case_id: c for c in load_tier1()}
    missing = [c.case_id for c in CASES if c.case_id not in loaded]
    if missing:
        raise SystemExit(f"case ids not found in the golden set: {missing}")

    entries = get_llm_config()["sufficiency_judge"]
    names = [short_name(e["model"]) for e in entries]

    out = Report()
    emit_provenance(out, started, entries)

    # One case at a time, all panelists concurrently. Ordering the loop this way
    # keeps every cell of a case drawn from the same moment, which is what makes
    # a disagreement a disagreement about the case rather than about when it was
    # asked.
    grid: Dict[str, List[Cell]] = {}
    for baseline in CASES:
        case = loaded[baseline.case_id]
        grid[baseline.case_id] = list(await asyncio.gather(
            *[run_cell(case, entry) for entry in entries]
        ))
        cells = grid[baseline.case_id]
        failures = sum(1 for c in cells if not c.ok)
        note = f"  ({failures} call(s) failed)" if failures else ""
        slowest = max(cells, key=lambda c: c.seconds)
        # `flush` is load-bearing, not tidiness. Redirected to a file, stdout is
        # block-buffered, so a run in progress shows *nothing* — which is how a
        # 19-minute stall on 2026-08-23 became undiagnosable from the outside.
        # The slowest panelist is named because that is who the case waited on.
        print(f"  {baseline.case_id} complete{note}"
              f"  [{slowest.seconds:.0f}s, slowest {slowest.model}]", flush=True)

    out(f"Completed {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}.")
    out()

    every_cost = [c.cost for cells in grid.values() for c in cells if c.ok]
    total, unpriced = sum_costs(every_cost)
    failed_cells = [c for cells in grid.values() for c in cells if not c.ok]
    failed_total, failed_unknown = sum_costs([c.cost for c in failed_cells])
    lost = len(failed_cells)

    # **This paragraph used to be wrong in the timid direction.** It read "a
    # floor — failed calls are unpriced and may still have been billed", which
    # treated a knowable number as unknowable: a call whose output would not
    # coerce came back on a message carrying its price, and `require_response`
    # discarded it while raising. Three reports understated their spend by
    # 11 + 6 + 3 = 20 calls that way. What is left genuinely unknown is narrower
    # and now named: the calls where nothing came back at all.
    out(f"**Spend: ${total + failed_total:.6f}** over "
        f"{len(every_cost) + lost} call(s)"
        + (f" — ${total:.6f} on {len(every_cost)} that answered, "
           f"${failed_total:.6f} on {lost} that failed" if lost else "")
        + (f", {unpriced} of the answers unpriced" if unpriced else "")
        + ".")
    if failed_unknown:
        out()
        out(f"{failed_unknown} of the failed call(s) returned no price — a "
            f"timeout or a rejected request — so this total is a floor by "
            f"however much those were billed.")
    out()

    # The headline table first, so the report answers its own question before it
    # asks the reader for six pages of claims.
    out("## Summary")
    out()
    out("| case | probes | answered | distinct | dominant bloc | contested words |")
    out("|---|---|---:|---:|---:|---:|")
    for baseline in CASES:
        cells = grid[baseline.case_id]
        case = loaded[baseline.case_id]
        n_ok = sum(1 for c in cells if c.ok)
        size, _, blocs = dominant_bloc(cells)
        votes = word_votes(cells, case.answer)
        contested = sum(1 for v in votes.values() if 0 < v < n_ok)
        out(f"| {baseline.case_id} | {baseline.probes} | {n_ok}/{len(cells)} | "
            f"{len(blocs)} | **{size}/{n_ok}** | {contested} |")
    out()

    unanimous_cases = sum(
        1 for baseline in grid
        if dominant_bloc(grid[baseline])[0] == sum(1 for c in grid[baseline] if c.ok)
    )
    out(f"**{unanimous_cases} of {len(CASES)} cases are unanimous** on core "
        f"coverage across the panel.")
    out()
    if lost:
        out(f"{lost} call(s) failed and are excluded from every count above.")
        out()

    emit_panelist_summary(out, grid, names)
    emit_agreement_matrix(out, grid, names)

    for baseline in CASES:
        emit_case(out, baseline, loaded[baseline.case_id], grid[baseline.case_id])

    # Last, because it is a reference rather than a reading: nobody works
    # through 48 generation ids in order, and everybody wants one of them the
    # moment a row above looks wrong.
    emit_generations(out, grid)

    out("---")
    out()
    out(f"{len(CASES)} of 433 cases, one run per panelist. **One sample, not a "
        f"rate** — `probe_a2_stability.py` has read the same stage at 4/6, 3/6, "
        f"0/6 and 0/6 unstable across four samples of a single model, so a "
        f"disagreement here may be the model's variance rather than its "
        f"judgement. Separating the two needs repeats per panelist, which this "
        f"run does not do.")

    out.write(path)
    print(f"\nreport written to {path}")


if __name__ == "__main__":
    asyncio.run(main())
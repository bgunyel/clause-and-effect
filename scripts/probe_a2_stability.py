"""
Run A2 five times over each of the six §4.6 cases and report what varies.

The measurement this whole experiment exists for. Design §4.6 found the combined
stage A **unstable at temperature 0**: `gdpr_art8_case1` returned 1, 1, 2 and 1
core claims across four runs of a byte-identical prompt, and the two-claim run
flipped the case from `sufficient` to `insufficient`. A2 is the half that
produces core claims, so this is the number directly comparable to that table.

The cases are imported from ``probe_a2_baseline_cases`` rather than re-declared.

**What counts as a difference, and why counting claims is the wrong metric.**
Stage C consumes core claims only, so what matters is *which material is core*,
not how many claims carry it. Splitting one core claim into two changes nothing
about what the quote must support; moving material across the core/auxiliary line
changes everything, and in the silent direction (Bertan, 2026-08-22). This
script therefore reports three things, in increasing order of what they mean:

    claims    how many claims came back           - noise unless it moves content
    coverage  WHICH WORDS OF THE ANSWER ARE CORE  - the property that matters
    texts     the exact claim strings             - strictest, mostly cosmetic

`art33_case1` is the worked example already observed: the single-pass run split
"without undue delay" and "within 72 hours" into two core claims where §4.6
records one. Same core content, finer split. A count metric calls that a
regression; a coverage metric correctly calls it identical.

**Coverage is computed by mapping each core claim back onto the gold answer**,
word by word, which is approximate: A2 legitimately repeats a stem into every
item of an enumeration, so a word may be claimed by several claims, and a claim
may reword slightly. It is compared as a SET of answer words marked core. This
under-reports differences that reshuffle the same vocabulary and over-reports
ones that reword - so a coverage difference is a prompt to read the output, not
a verdict on its own.

**Failures cost one data point, not the run.** ``asyncio.gather`` is called with
``return_exceptions=True`` because a `JudgeResponseError` at call 29 of 30 would
otherwise discard the whole measurement. Losses are counted and reported rather
than quietly reducing N.

**Every run writes a record to `docs/eval-reports/`.** A run of this script is a
*sample*, not a rate: at five runs per case a failure occurring one run in five
has a substantial chance of not appearing at all, and the two samples taken on
2026-08-22 found a different three cases unstable each. Comparing samples is the
only way to read that, and it cannot be done from a terminal scrollback - the
first sample of 2026-08-22 was piped through `tail` and its per-case diffs were
lost, which cost a second sample that was not the same sample.

The report is therefore the output of this script, and stdout is a view of it:
the terminal and the file are the same text, emitted through :class:`Report`.
Three consequences follow from `eval-reports/` being an append-only record of
what the numbers were at a point in time (`docs/design/README.md`):

  - **The filename carries the time, not just the date**, because two samples in
    one day is the observed case rather than the exceptional one.
  - **An existing path is never overwritten** - a collision raises instead. The
    check costs nothing and turns "these are distinct samples" from something
    trusted into something enforced.
  - **The commit is recorded, and so is a dirty tree.** A sample is a measurement
    of a prompt, and the prompt is a file; against a dirty tree the commit pins
    nothing, which the report has to say rather than imply.
  - **What the sample cost is part of the sample.** Thirty calls is the price of
    one reading of one stage against six of 433 cases, and the panel (§8)
    multiplies it by the number of members. A record that says what was measured
    but not what measuring it cost cannot be used to plan the measurement that
    comes next.

Run:

    uv run python -m scripts.probe_a2_stability
"""
import asyncio
import re
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional

from scripts.probe_a2_baseline_cases import CASES
from src.clause_and_effect.chunking.chunk_store import git_state
from src.eval.dataset import load_tier1
from src.eval.sufficiency.llm import sum_costs
from src.eval.sufficiency.stage_a2 import tag_claims
from src.llm_config import get_llm_config

RUNS = 5

_REPO_ROOT = Path(__file__).resolve().parents[1]
REPORTS_DIR = _REPO_ROOT / "docs" / "eval-reports"

# How many dirty paths the provenance table names before summarising the rest.
# `git_state` already caps its list at 50; this is the narrower cap for a table
# whose job is to say *whether* the tree was clean, not to list a refactor.
_MAX_DIRTY_SHOWN = 5


class Report:
    """
    Every line, printed as it is produced and kept for the file.

    The file is not a formatted version of the run - it is the run, and stdout is
    the same text arriving earlier. Two things fall out of that. A long run stays
    watchable, because nothing is buffered until the end; and the record cannot
    drift from what the operator read, because there is no second formatting path
    for it to drift through.

    Markdown that is also plain text: tables and headings survive a terminal, and
    claim text goes in fenced blocks rather than table cells, because a claim
    containing a pipe would silently corrupt a row.
    """

    def __init__(self) -> None:
        self._lines: List[str] = []

    def __call__(self, line: str = "") -> None:
        print(line)
        self._lines.append(line)

    def write(self, path: Path) -> None:
        """
        Write the report, refusing to replace one that already exists.

        Raises:
            SystemExit: if ``path`` exists. Records here are append-only, and a
                second sample silently landing on the first destroys the only
                thing the pair is good for.
        """
        if path.exists():
            raise SystemExit(
                f"{path} already exists; refusing to overwrite an eval report. "
                f"The run above is complete and its output is on stdout."
            )
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("\n".join(self._lines) + "\n", encoding="utf-8")


def report_path(started: datetime) -> Path:
    """
    Where this sample is recorded: ``2026-08-23-a2-stability-141502.md``.

    Date first, to match the directory's existing convention and sort with it;
    time appended, because a sample is identified by when it was taken and two
    in one day is the observed case.
    """
    return REPORTS_DIR / (
        f"{started.strftime('%Y-%m-%d')}-a2-stability-"
        f"{started.strftime('%H%M%S')}.md"
    )


def words(text: str) -> List[str]:
    return re.findall(r"[a-z0-9]+", text.lower())


def core_coverage(claims, answer: str) -> frozenset:
    """
    Which words of the gold answer this run marked core.

    Claim text is matched against the answer's vocabulary rather than by span,
    because A2 rewords: it repeats an enumeration's stem into every item, and
    turns "the purposes of processing" into "the company must provide the
    purposes of processing". Words a claim introduces that are not in the answer
    are dropped here - the wording rule is checked separately in the baseline
    script, and counting them would conflate two different defects.
    """
    in_answer = set(words(answer))
    covered = set()
    for claim in claims:
        if claim.tag == "core":
            covered |= {w for w in words(claim.text) if w in in_answer}
    return frozenset(covered)


def describe_tree(dirty: List[str]) -> str:
    """The dirty-path list as one table cell, or `clean`."""
    if not dirty:
        return "clean"
    shown = ", ".join(f"`{p}`" for p in dirty[:_MAX_DIRTY_SHOWN])
    if len(dirty) > _MAX_DIRTY_SHOWN:
        shown += f", and {len(dirty) - _MAX_DIRTY_SHOWN} more"
    return f"**DIRTY** - {shown}"


def emit_provenance(out: Report, started: datetime, model_params: Dict) -> None:
    """
    The header, written before the first call rather than after the last.

    What a reader comparing two samples needs in order to know they are
    comparable: when, which code, which model, and how many calls. `model` and
    `temperature` are read off the params actually passed to the stage, not off
    a constant, because the 2026-08-22 near-miss was a probe reading
    `writer_model` while `orchestrator_model` had been changed.
    """
    commit, dirty = git_state(_REPO_ROOT)
    out(f"# A2 stability - {len(CASES)} cases x {RUNS} runs")
    out()
    out("| | |")
    out("|---|---|")
    out(f"| started | {started.strftime('%Y-%m-%dT%H:%M:%SZ')} |")
    out(f"| commit | `{commit[:12]}` |")
    out(f"| working tree | {describe_tree(dirty)} |")
    out(f"| model | `{model_params['model']}` |")
    out(f"| provider | `{model_params['model_provider']}` |")
    out(f"| temperature | {model_params['model_args']['temperature']} |")
    out(f"| calls | {len(CASES) * RUNS} |")
    out("| stage | `src/eval/sufficiency/stage_a2.py` |")
    out("| script | `scripts/probe_a2_stability.py` |")
    out("| cases | `scripts/probe_a2_baseline_cases.py` |")
    out()


async def main() -> None:
    started = datetime.now(timezone.utc)
    path = report_path(started)

    loaded = {c.case_id: c for c in load_tier1()}
    missing = [c.case_id for c in CASES if c.case_id not in loaded]
    if missing:
        raise SystemExit(f"case ids not found in the golden set: {missing}")

    model_params = get_llm_config()["sufficiency_judge"][0]

    out = Report()
    emit_provenance(out, started, model_params)

    results: Dict[str, List[list]] = {c.case_id: [] for c in CASES}
    costs: Dict[str, List[Optional[float]]] = {c.case_id: [] for c in CASES}
    lost: Dict[str, int] = {c.case_id: 0 for c in CASES}

    for run in range(1, RUNS + 1):
        outputs = await asyncio.gather(
            *[
                tag_claims(
                    loaded[c.case_id].question, loaded[c.case_id].answer, model_params
                )
                for c in CASES
            ],
            return_exceptions=True,
        )
        failures = 0
        for baseline, result in zip(CASES, outputs):
            if isinstance(result, BaseException):
                lost[baseline.case_id] += 1
                failures += 1
                continue
            results[baseline.case_id].append(result.value)
            costs[baseline.case_id].append(result.cost)
        note = f"  ({failures} call(s) lost)" if failures else ""
        print(f"  run {run}/{RUNS} complete{note}")

    out(f"Completed {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}.")
    out()
    # A lost call is missing from this total and may still have been billed: the
    # exception means no response came back to read a price off, not that the
    # provider forgave the attempt. The total is therefore a floor whenever the
    # run lost anything, which the line below says outright rather than leaving
    # to be inferred from the loss count further down.
    every_cost = [c for case_costs in costs.values() for c in case_costs]
    total, unpriced = sum_costs(every_cost)
    floor = " (a floor - lost calls are unpriced and may still have been billed)"
    out(f"**Spend: ${total:.6f}** over {len(every_cost)} completed call(s)"
        + (f", {unpriced} of them unpriced" if unpriced else "")
        + (floor if len(every_cost) < len(CASES) * RUNS else "")
        + ".")
    out()

    summary = []
    for baseline in CASES:
        case = loaded[baseline.case_id]
        runs = results[baseline.case_id]
        n = len(runs)

        out("## " + case.case_id)
        out()
        if n == 0:
            out("Every call failed; no data.")
            out()
            summary.append((case.case_id, 0, 0, 0, "NO DATA"))
            continue

        counts = Counter(sum(1 for c in r if c.tag == "core") for r in runs)
        coverage = Counter(core_coverage(r, case.answer) for r in runs)
        texts = Counter(
            tuple(sorted((c.tag, " ".join(words(c.text))) for c in r)) for r in runs
        )

        if len(coverage) > 1:
            verdict = "UNSTABLE - the core content differs"
        elif len(texts) > 1:
            verdict = "stable core, wording/granularity varies"
        else:
            verdict = "stable"
        summary.append((case.case_id, len(counts), len(coverage), len(texts), verdict))

        out(f"*{case.answer_type}* - {baseline.probes}")
        out()
        out("| | |")
        out("|---|---|")
        out(f"| runs kept | {n}/{RUNS}"
            + (f" ({lost[case.case_id]} lost)" if lost[case.case_id] else "")
            + " |")
        out(f"| core-claim counts | {dict(sorted(counts.items()))} "
            f"(§4.6 expects {baseline.expected_core}) |")
        out(f"| core coverage | {len(coverage)} distinct over {n} |")
        out(f"| verdict | {verdict} |")
        case_total, case_unpriced = sum_costs(costs[case.case_id])
        out(f"| spend | ${case_total:.6f}"
            + (f" ({case_unpriced} unpriced)" if case_unpriced else "")
            + " |")
        out()

        if len(coverage) > 1:
            for i, (cov, times) in enumerate(coverage.most_common(), 1):
                out(f"- variant {i} ({times}x): {len(cov)} answer words core")
            out()
            base, *others = [c for c, _ in coverage.most_common()]
            for i, other in enumerate(others, 2):
                out(f"variant 1 vs {i}:")
                out()
                out("```")
                out(f"core only in variant 1: {sorted(base - other)}")
                out(f"core only in variant {i}: {sorted(other - base)}")
                out("```")
                out()

        for i, run_claims in enumerate(runs, 1):
            tags = [c.tag for c in run_claims]
            out(f"run {i}: {len(run_claims)} claims  {tags}")
            out()
            out("```")
            core_texts = [c.text for c in run_claims if c.tag == "core"]
            for text in core_texts:
                out(f"core  {text}")
            if not core_texts:
                # A run with no core claim is a real result, not a rendering
                # gap: it says the gold answer does not answer its own question.
                # An empty fenced block would read as a formatting bug.
                out("(no core claims)")
            out("```")
            out()

    out("## Summary")
    out()
    out("| case | counts | coverage | texts | verdict |")
    out("|---|---:|---:|---:|---|")
    for case_id, n_counts, n_cov, n_texts, verdict in summary:
        out(f"| {case_id} | {n_counts} | {n_cov} | {n_texts} | {verdict} |")
    out()

    unstable = sum(1 for _, _, n_cov, _, _ in summary if n_cov > 1)
    total_lost = sum(lost.values())
    out(f"**{unstable} of {len(CASES)} cases differ in core CONTENT.**")
    out()
    if total_lost:
        out(f"{total_lost} call(s) lost to transport failures and excluded.")
        out()
    out(f"{RUNS} runs, {len(CASES)} tuning cases. Necessary, not sufficient - "
        f"427 cases remain unmeasured. One sample, not a rate.")

    out.write(path)
    print(f"\nreport written to {path}")


if __name__ == "__main__":
    asyncio.run(main())
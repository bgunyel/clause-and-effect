"""
Run A2 twenty-five times over each of the six §4.6 cases and report what varies.

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
*sample*. It was not a rate at five runs per case - a failure occurring one run
in five had a substantial chance of not appearing at all, and the four samples
taken on 2026-08-22 and 2026-08-23 read 4/6, 3/6, 0/6 and 0/6 for that reason.
`RUNS` is 25 as of 2026-08-25, which makes the frequency of a minority reading
*within these six cases* estimable; it makes nothing about the other 427 cases
estimable, and it does not replace a second sample, which is the only way to see
the instrument's own sample-to-sample variance. Comparing samples cannot be done
from a terminal scrollback - the first sample of 2026-08-22 was piped through
`tail` and its per-case diffs were lost, which cost a second sample that was not
the same sample.

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
  - **What the sample cost is part of the sample.** A hundred and fifty calls is
    the price of one reading of one stage against six of 433 cases, and the panel
    (§8) multiplies it by the number of members. A record that says what was
    measured but not what measuring it cost cannot be used to plan the
    measurement that comes next - and it is why `RUNS` can be 25 here and cannot
    be there.

Run:

    uv run python -m scripts.probe_a2_stability
"""
import asyncio
import re
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional

from dataclasses import dataclass

from scripts.probe_a2_baseline_cases import CASES
from src.clause_and_effect.chunking.chunk_store import git_state
from src.eval.dataset import load_tier1
from src.eval.sufficiency.llm import JudgeResponseError
from src.llm.call import CallRecord, sum_costs
from ai_common.enums import ModelNames

from src.eval.sufficiency.stage_a2 import tag_claims
from src.llm_config import get_llm_config, panelist

# Runs per case.
#
# **Raised from 5 to 25 on 2026-08-25, and cost was never the reason it was 5.**
# Four samples of this instrument read 4/6, 3/6, 0/6 and 0/6 unstable — a spread
# that says the between-sample variance swamped the signal, and that no single
# sample was a rate. At five runs a failure occurring one run in five has a
# substantial chance of not appearing at all, so each sample was closer to a
# coin flip than a measurement.
#
# The fix is arithmetic, and it is nearly free here: this stage on DeepSeek V4
# Flash costs about $0.0001 a call, so 150 calls is under two cents. The panel
# probe cannot do this — eight members including Grok at $0.07 a case — but the
# single-model stability question can, and it is the question the four samples
# failed to answer. At 25 runs a one-in-five instability is expected five times
# and its absence means something.
RUNS = 25

# Which panelist this sample measures, named rather than indexed.
#
# `get_llm_config()["sufficiency_judge"][0]` was the previous form, and it made
# the subject of the measurement a consequence of where a model sits in
# `llm_names` — so inserting a panelist at the front of that list would repoint
# this probe silently while its reports went on being titled "A2 stability".
# The four earlier samples are only comparable to this one if all five measured
# the same model, and an index is not a way to promise that.
#
# DeepSeek V4 Flash because that is what the 2026-08-22 and 2026-08-23 samples
# ran on. Changing it is allowed and cheap; doing so without noticing is what
# this constant prevents. `panelist` raises if the model has left the roster.
STABILITY_MODEL = ModelNames.DEEPSEEK_V_4_FLASH_0731

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


@dataclass(frozen=True)
class RunResult:
    """
    One run of one case: what came back, and the record of the call behind it.

    ``call`` survives a failure as well as a success, because a call that would
    not coerce was still made, still billed, and still reports what it spent on
    reasoning — which is the field this sample exists to check. Keeping the
    record beside the claims is what lets a lost run be priced instead of
    turning the total into a floor.
    """

    claims: Optional[list]
    call: Optional[CallRecord]
    error: Optional[str]

    @property
    def ok(self) -> bool:
        return self.claims is not None

    @property
    def cost(self) -> Optional[float]:
        return None if self.call is None else self.call.cost

    @property
    def reasoning(self) -> Optional[int]:
        return None if self.call is None else self.call.reasoning_tokens


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
    # Both added 2026-08-25, and both are comparability facts rather than
    # decoration. The four earlier samples ran on an instrument where only the
    # *first* call of a process received `reasoning_effort` — so a header naming
    # the configured effort described something that did not reach calls 2..N.
    # The channel matters for the same reason: two samples taken through
    # different structured-output channels are not the same measurement, which
    # the panel probe's header already records and this one did not.
    out(f"| reasoning effort | {model_params['model_args'].get('reasoning_effort')} |")
    out(f"| structured output | `{model_params.get('structured_output')}` |")
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

    model_params = panelist(get_llm_config()["sufficiency_judge"], STABILITY_MODEL)

    out = Report()
    emit_provenance(out, started, model_params)

    # Every run of every case, kept whether or not it produced claims. The
    # earlier shape appended only successes, so a lost run left no trace beyond
    # a counter — and the call behind it, which had a price and a reasoning
    # count, was gone.
    attempts: Dict[str, List[RunResult]] = {c.case_id: [] for c in CASES}

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
            if isinstance(result, JudgeResponseError):
                # It answered and would not coerce: billed, identified, and it
                # reported its reasoning. All three survive on the exception.
                attempts[baseline.case_id].append(
                    RunResult(claims=None, call=result.call, error=str(result)[:200])
                )
                failures += 1
            elif isinstance(result, BaseException):
                attempts[baseline.case_id].append(
                    RunResult(
                        claims=None, call=None,
                        error=f"{type(result).__name__}: {str(result)[:200]}",
                    )
                )
                failures += 1
            else:
                attempts[baseline.case_id].append(
                    RunResult(
                        claims=result.value,
                        call=result.calls[0] if result.calls else None,
                        error=None,
                    )
                )
        note = f"  ({failures} call(s) lost)" if failures else ""
        # `flush` for the reason the panel probe records: redirected to a file,
        # stdout is block-buffered, and a long run then shows nothing at all.
        print(f"  run {run}/{RUNS} complete{note}", flush=True)

    results: Dict[str, List[list]] = {
        cid: [a.claims for a in runs if a.ok] for cid, runs in attempts.items()
    }
    lost: Dict[str, int] = {
        cid: sum(1 for a in runs if not a.ok) for cid, runs in attempts.items()
    }

    out(f"Completed {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}.")
    out()
    # **This used to declare itself a floor whenever anything was lost**, on the
    # premise that a failed call could not be priced. Since 2026-08-25 it can:
    # a response that would not coerce arrives on a message carrying its price,
    # and that price now travels on the exception. What remains genuinely
    # unknown is narrower — a call that never came back at all — and only that
    # makes the total a floor.
    every = [a for runs in attempts.values() for a in runs]
    answered = [a for a in every if a.ok]
    failed = [a for a in every if not a.ok]
    total, unpriced = sum_costs([a.cost for a in answered])
    failed_total, failed_unknown = sum_costs([a.cost for a in failed])
    out(f"**Spend: ${total + failed_total:.6f}** over {len(every)} call(s)"
        + (f" — ${total:.6f} on {len(answered)} that answered, "
           f"${failed_total:.6f} on {len(failed)} that did not" if failed else "")
        + (f", {unpriced} of the answers unpriced" if unpriced else "")
        + ".")
    if failed_unknown:
        out()
        out(f"{failed_unknown} call(s) never came back, so their price is "
            f"unknown and this total is a floor by that much.")
    out()

    # **Did every call actually get the reasoning budget the header claims?**
    # This is the question item 5 exists for. Until 2026-08-23 `get_llm` emptied
    # the `model_args` dict it was handed, so only the *first* build in a process
    # received `reasoning_effort` and every later call ran with none — which is
    # the confound sitting under the four earlier samples. The fix is a copy per
    # build; this is the live evidence for it, and it costs nothing to print
    # because the number is already on every call.
    #
    # It is a *check*, not a stability metric: reasoning tokens vary run to run
    # for ordinary reasons, so what matters is the shape of the spread. Under
    # the bug it would be one high value and 149 near-zero ones.
    budgets = [a.reasoning for a in every if a.reasoning is not None]
    out("## Reasoning budget")
    out()
    if not budgets:
        out("No call reported a reasoning count, so whether every call received "
            "the configured effort cannot be confirmed from this sample.")
    else:
        zero = sum(1 for b in budgets if b == 0)
        out("| | |")
        out("|---|---|")
        out(f"| calls reporting a count | {len(budgets)}/{len(every)} |")
        out(f"| reported zero | {zero} |")
        out(f"| min / median / max | {min(budgets)} / "
            f"{sorted(budgets)[len(budgets) // 2]} / {max(budgets)} |")
        out()
        out("Under the `model_args` defect fixed on 2026-08-23, exactly one "
            "call per process received `reasoning_effort` and the rest ran with "
            "none. A single high value among near-zeros would be that defect "
            "still present; a spread with a non-zero minimum is the fix holding.")
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
            summary.append((case.case_id, 0, 0, 0, "0/0", "NO DATA"))
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
        # How often the *majority* reading came back. At five runs this was not
        # worth reporting — a minority variant appearing once told you almost
        # nothing — but at twenty-five "24 of 25" and "14 of 25" are different
        # findings that the distinct-variant count renders identically as 2.
        dominant = coverage.most_common(1)[0][1] if coverage else 0
        summary.append(
            (case.case_id, len(counts), len(coverage), len(texts),
             f"{dominant}/{n}", verdict)
        )

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
        case_total, case_unpriced = sum_costs([a.cost for a in attempts[case.case_id]])
        out(f"| spend | ${case_total:.6f}"
            + (f" ({case_unpriced} unpriced)" if case_unpriced else "")
            + " |")
        case_budgets = [
            a.reasoning for a in attempts[case.case_id] if a.reasoning is not None
        ]
        if case_budgets:
            out(f"| reasoning tokens | {min(case_budgets)}–{max(case_budgets)} "
                f"over {len(case_budgets)} call(s) |")
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

        # **One exemplar per distinct coverage variant, not one block per run.**
        # At five runs, printing all of them was the whole record; at
        # twenty-five it would be 150 blocks of which most are byte-identical,
        # and a reader looking for the variant would have to find it. Nothing is
        # dropped silently — every run is counted in its variant, and the run
        # number and generation id of the exemplar are given so the call can be
        # opened at the provider.
        by_coverage: Dict[frozenset, List[tuple]] = {}
        for i, attempt in enumerate(attempts[case.case_id], 1):
            if attempt.ok:
                key = core_coverage(attempt.claims, case.answer)
                by_coverage.setdefault(key, []).append((i, attempt))

        for variant, members in sorted(
            by_coverage.items(), key=lambda kv: (-len(kv[1]), sorted(kv[0]))
        ):
            run_no, attempt = members[0]
            runs_listed = ", ".join(str(i) for i, _ in members[:10])
            if len(members) > 10:
                runs_listed += f", and {len(members) - 10} more"
            gen = attempt.call.generation_id if attempt.call else None
            tags = [c.tag for c in attempt.claims]
            out(f"**{len(members)} of {n} run(s)** — {len(attempt.claims)} claims "
                f"{tags}; runs {runs_listed}")
            out()
            out(f"exemplar: run {run_no}"
                + (f", generation `{gen}`" if gen else ", generation unidentified"))
            out()
            out("```")
            core_texts = [c.text for c in attempt.claims if c.tag == "core"]
            for text in core_texts:
                out(f"core  {text}")
            if not core_texts:
                # A run with no core claim is a real result, not a rendering
                # gap: it says the gold answer does not answer its own question.
                # An empty fenced block would read as a formatting bug.
                out("(no core claims)")
            out("```")
            out()

        for i, attempt in enumerate(attempts[case.case_id], 1):
            if attempt.ok:
                continue
            gen = attempt.call.generation_id if attempt.call else None
            cost = "—" if attempt.cost is None else f"${attempt.cost:.6f}"
            out(f"run {i} did not answer [{cost}"
                + (f", generation `{gen}`" if gen else ", no generation")
                + f"]: {attempt.error}")
            out()

    out("## Summary")
    out()
    out("| case | counts | coverage | texts | dominant | verdict |")
    out("|---|---:|---:|---:|---:|---|")
    for case_id, n_counts, n_cov, n_texts, dominant, verdict in summary:
        out(f"| {case_id} | {n_counts} | {n_cov} | {n_texts} | {dominant} | "
            f"{verdict} |")
    out()

    unstable = sum(1 for _, _, n_cov, _, _, _ in summary if n_cov > 1)
    total_lost = sum(lost.values())
    out(f"**{unstable} of {len(CASES)} cases differ in core CONTENT.**")
    out()
    if total_lost:
        out(f"{total_lost} call(s) lost to transport failures and excluded.")
        out()
    out(f"{RUNS} runs over {len(CASES)} of 433 cases.")
    out()
    out("**What twenty-five runs changed, and what they did not.** The dominant "
        "column is now worth reading: at five runs a minority variant appearing "
        "once was indistinguishable from noise, and four samples of this "
        "instrument read 4/6, 3/6, 0/6 and 0/6 for exactly that reason. Within "
        "these six cases the frequency of a minority reading is now estimable. "
        "What is still **not** a rate is anything about the other 427 cases, "
        "which remain unmeasured, and the sample-to-sample variance of the "
        "instrument itself — that needs a second sample of this size, not a "
        "larger first one.")

    out.write(path)
    print(f"\nreport written to {path}")


if __name__ == "__main__":
    asyncio.run(main())
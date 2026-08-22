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

Run:

    uv run python -m scripts.probe_a2_stability
"""
import asyncio
import re
from collections import Counter
from typing import Dict, List

from scripts.probe_a2_baseline_cases import CASES
from src.eval.dataset import load_tier1
from src.eval.sufficiency.stage_a2 import tag_claims
from src.llm_config import get_llm_config

RUNS = 5


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


def summarise(label: str, counter: Counter, runs: int) -> str:
    return f"{label}: {len(counter)} distinct over {runs}"


async def main() -> None:
    loaded = {c.case_id: c for c in load_tier1()}
    missing = [c.case_id for c in CASES if c.case_id not in loaded]
    if missing:
        raise SystemExit(f"case ids not found in the golden set: {missing}")

    model_params = get_llm_config()["writer_model"][0]
    print(f"model: {model_params['model']}  "
          f"temperature={model_params['model_args']['temperature']}")
    print(f"{len(CASES)} cases x {RUNS} runs = {len(CASES) * RUNS} calls\n")

    results: Dict[str, List[list]] = {c.case_id: [] for c in CASES}
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
            results[baseline.case_id].append(result)
        note = f"  ({failures} call(s) lost)" if failures else ""
        print(f"  run {run}/{RUNS} complete{note}")

    print()
    summary = []
    for baseline in CASES:
        case = loaded[baseline.case_id]
        runs = results[baseline.case_id]
        n = len(runs)
        if n == 0:
            print("=" * 78)
            print(f"{case.case_id}: every call failed; no data")
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

        print("=" * 78)
        print(f"{case.case_id}  [{case.answer_type}]   {baseline.probes}")
        print(f"  runs kept: {n}/{RUNS}" + (f"  ({lost[case.case_id]} lost)"
                                            if lost[case.case_id] else ""))
        print(f"  core-claim counts : {dict(sorted(counts.items()))} "
              f"(§4.6 expects {baseline.expected_core})")
        print(f"  {summarise('core coverage', coverage, n)}   -> {verdict}")

        if len(coverage) > 1:
            for i, (cov, times) in enumerate(coverage.most_common(), 1):
                print(f"\n    variant {i} ({times}x): {len(cov)} answer words core")
            base, *others = [c for c, _ in coverage.most_common()]
            for i, other in enumerate(others, 2):
                only_base = sorted(base - other)
                only_other = sorted(other - base)
                print(f"\n    variant 1 vs {i}:")
                print(f"      core only in variant 1: {only_base}")
                print(f"      core only in variant {i}: {only_other}")

        for i, run_claims in enumerate(runs, 1):
            tags = [c.tag for c in run_claims]
            print(f"\n    run {i}: {len(run_claims)} claims  {tags}")
            for claim in run_claims:
                if claim.tag == "core":
                    print(f"       core  {claim.text}")

    print("=" * 78)
    print(f"\n{'case':<20} {'counts':>7} {'coverage':>9} {'texts':>6}   verdict")
    for case_id, n_counts, n_cov, n_texts, verdict in summary:
        print(f"{case_id:<20} {n_counts:>7} {n_cov:>9} {n_texts:>6}   {verdict}")

    unstable = sum(1 for _, _, n_cov, _, _ in summary if n_cov > 1)
    total_lost = sum(lost.values())
    print(f"\n{unstable} of {len(CASES)} cases differ in core CONTENT.")
    if total_lost:
        print(f"{total_lost} call(s) lost to transport failures and excluded.")
    print("Five runs, six tuning cases. Necessary, not sufficient — 427 cases "
          "remain unmeasured.")


if __name__ == "__main__":
    asyncio.run(main())
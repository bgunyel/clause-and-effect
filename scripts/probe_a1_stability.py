"""
Run A1 five times over each of the six §4.6 cases and report what varies.

The first measurement in this experiment that tests **stability** rather than
correctness. Everything before it was a single pass, and a single pass cannot see
the defect that started this work: on 2026-08-17 the combined stage A returned
1, 1, 2 and 1 core claims for `gdpr_art8_case1` across four runs of a
byte-identical prompt at temperature 0, and the two-claim run flipped the case
from `sufficient` to `insufficient`.

The cases are imported from ``probe_a1_baseline_cases`` rather than re-declared,
so the two scripts cannot drift apart.

**Two thresholds are reported, and the difference between them matters.**

  strict  - outputs differ at all, punctuation included
  loose   - outputs differ in their alphanumeric words

`art41_case3` returned its shortest answer without a terminal full stop on the
single-pass run, which design §4.6 already records as "trailing-dot drift" under
the three-example prompt. That is a strict difference and not a loose one. It
reads as cosmetic, but A1's output is what A2's core claims are compared against,
so a terminal character is a difference any exact or substring comparison sees.

**What a clean result here would and would not mean.** Five runs is a small N and
these six are the tuning cases. Stability here is necessary, not sufficient, and
open item 2 — roughly 20 held-out cases, stratified by answer type — remains the
honest test.

Run:

    uv run python -m scripts.probe_a1_stability
"""
import asyncio
import re
from collections import Counter
from typing import Dict, List

from scripts.probe_a1_baseline_cases import CASES
from src.eval.dataset import load_tier1
from src.eval.sufficiency.stage_a1 import write_shortest_answer
from src.llm_config import get_llm_config

RUNS = 5


def norm(text: str) -> str:
    """Whitespace-collapsed, punctuation intact. The strict comparison key."""
    return " ".join(text.split())


def loose(text: str) -> str:
    """Alphanumeric words only. The loose comparison key."""
    return " ".join(re.findall(r"[a-z0-9]+", text.lower()))


async def main() -> None:
    loaded = {c.case_id: c for c in load_tier1()}
    missing = [c.case_id for c in CASES if c.case_id not in loaded]
    if missing:
        raise SystemExit(f"case ids not found in the golden set: {missing}")

    model_params = get_llm_config()["writer_model"][0]
    print(f"model: {model_params['model']}  "
          f"temperature={model_params['model_args']['temperature']}")
    print(f"{len(CASES)} cases x {RUNS} runs = {len(CASES) * RUNS} calls\n")

    # One round of six concurrent calls at a time, repeated. Independent calls
    # either way; batching only keeps the burst small.
    results: Dict[str, List[str]] = {c.case_id: [] for c in CASES}
    for run in range(1, RUNS + 1):
        outputs = await asyncio.gather(*[
            write_shortest_answer(
                loaded[c.case_id].question, loaded[c.case_id].answer, model_params
            )
            for c in CASES
        ])
        for baseline, actual in zip(CASES, outputs):
            results[baseline.case_id].append(actual)
        print(f"  run {run}/{RUNS} complete")

    print()
    summary = []
    for baseline in CASES:
        case = loaded[baseline.case_id]
        outputs = results[baseline.case_id]
        strict = Counter(norm(o) for o in outputs)
        loose_counts = Counter(loose(o) for o in outputs)

        n_strict, n_loose = len(strict), len(loose_counts)
        if n_loose > 1:
            verdict = "UNSTABLE - the words differ"
        elif n_strict > 1:
            verdict = "punctuation-only drift"
        else:
            verdict = "stable"
        summary.append((case.case_id, n_strict, n_loose, verdict))

        print("=" * 78)
        print(f"{case.case_id}  [{case.answer_type}]   {baseline.probes}")
        print(f"  distinct outputs: {n_strict} strict / {n_loose} loose, "
              f"over {RUNS} runs   -> {verdict}")
        for text, count in strict.most_common():
            print(f"\n    {count}x  {text!r}")

    print("=" * 78)
    print(f"\n{'case':<20} {'strict':>7} {'loose':>7}   verdict")
    for case_id, n_strict, n_loose, verdict in summary:
        print(f"{case_id:<20} {n_strict:>7} {n_loose:>7}   {verdict}")

    unstable = sum(1 for _, _, n_loose, _ in summary if n_loose > 1)
    drift = sum(1 for _, s, l, _ in summary if l == 1 and s > 1)
    print(f"\n{unstable} of {len(CASES)} cases unstable in their words; "
          f"{drift} showed punctuation-only drift.")
    print("Five runs, and these are the tuning cases. Necessary, not sufficient.")


if __name__ == "__main__":
    asyncio.run(main())
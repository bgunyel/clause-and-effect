"""
Run A2 over the six real golden-set cases the combined stage A was tuned against.

The A2 counterpart of ``probe_a1_baseline_cases.py``, and the run that is
directly comparable to design §4.6: that table's "correct output" column is a
statement about **core claims**, which is A2's output, not A1's.

**These six are the cases three rounds of prompt work were measured on.** Per
Bertan (2026-08-22) that is not leakage - the 433 cases are the population the
judge runs on, not a sample - but it does mean a good result here says nothing
about the 427 cases nobody has looked at, `conditional` least of all.

**Whose standard each expectation is, per case.** Only `art7_case3` rests on a
ruling of Bertan's. The other five are the assistant's, and `art7_case4` is the
consequential one - §4.6's 6/6 for it depends entirely on the third sentence
being auxiliary, and reading it as core makes the same output 0/6.

**What to compare, and what to ignore.** Stage C consumes core claims only, so
the property that matters is *which material is core*, not how many claims carry
it. Splitting one core claim into two changes nothing about what the quote must
support; moving a claim across the core/auxiliary line changes everything, and
in the silent direction (Bertan, 2026-08-22). Claim counts are printed, but a
count difference with the same core content is not a defect.

**Mechanical checks, needing nobody's agreement:**

    introduced words     a word not in the ANSWER breaks a stated rule
    bare polarity        a claim of only "Yes"/"No" is never correct output
    leading conjunction  HEURISTIC. Narrowed from the first version, which fired
                         on "Where..." three times and was wrong every time -
                         `Where` opens an ordinary legal conditional. Now limited
                         to the shapes actually observed in §4.6's residue.

Run:

    uv run python -m scripts.probe_a2_baseline_cases
"""
import asyncio
import re
from dataclasses import dataclass
from typing import List

from src.eval.dataset import load_tier1
from src.eval.sufficiency.stage_a2 import tag_claims
from src.llm_config import get_llm_config

# Narrowed from the A1 adversarial version. `where`, `including`, `unless`,
# `having` and `whichever` were dropped: all of them open complete sentences in
# regulatory prose, and `where` alone produced three false positives in one run.
# What remains is the shape §4.6 actually recorded - `art41_case3` returning
# "and may be renewed on the same conditions, provided...".
_CONTINUATION = ("and", "or", "but", "provided", "which")


@dataclass(frozen=True)
class BaselineCase:
    """One §4.6 case, what it probes, and the core set expected of A2."""

    case_id: str
    probes: str
    core_baseline: str  # the §4.6 "correct output" column, verbatim
    expected_core: int  # a guide, not a score - see the note on granularity
    expectation: str
    basis: str


CASES: List[BaselineCase] = [
    BaselineCase(
        case_id="gdpr_art7_case3",
        probes="the case the criterion was settled on",
        core_baseline="1 core; prior-lawfulness auxiliary",
        expected_core=1,
        expectation="CORE: 'Yes. The data subject shall have the right to withdraw "
                    "their consent at any time.' with the polarity attached. "
                    "AUXILIARY: the prior-lawfulness sentence.",
        basis="BERTAN'S RULING - the only one of the six that is not the assistant's "
              "classification.",
    ),
    BaselineCase(
        case_id="gdpr_art7_case4",
        probes="polarity - is `No.` split off?",
        core_baseline="1 core, `No.` attached",
        expected_core=1,
        expectation="CORE: 'No. The withdrawal of consent does not affect the "
                    "lawfulness of processing that was based on consent before the "
                    "withdrawal.' AUXILIARY: 'The data processed while consent was "
                    "still valid remains lawfully processed.'",
        basis="THE ASSISTANT'S CLASSIFICATION, AND THE DISPUTED ONE. Read the third "
              "sentence as CORE instead and §4.6's 6/6 becomes 0/6. Open item 5, "
              "Bertan's call, undecided. Note the 2026-08-22 asymmetry argument "
              "points toward CORE: demoting it is the choice whose errors are silent.",
    ),
    BaselineCase(
        case_id="gdpr_art8_case1",
        probes="implication - is a consequence tagged core?",
        core_baseline="1 core",
        expected_core=1,
        expectation="CORE: 'The minimum age is 16 years old.' AUXILIARY: the "
                    "consequence about children below that age needing parental "
                    "consent. This is the case whose four identical runs of the "
                    "combined prompt returned 1/1/2/1 core claims and flipped the "
                    "verdict - the 2-core run tagged the consequence core.",
        basis="the assistant's classification",
    ),
    BaselineCase(
        case_id="gdpr_art33_case1",
        probes="consequence - *reasons for delay* stays auxiliary",
        core_baseline="1 core",
        expected_core=1,
        expectation="CORE: the notification timing sentence. AUXILIARY: 'If "
                    "notification is made after 72 hours, it must be accompanied by "
                    "reasons for the delay.' The timing sentence carries 'without "
                    "undue delay AND within 72 hours', so splitting it into two core "
                    "claims is fine - both halves stay core.",
        basis="the assistant's classification",
    ),
    BaselineCase(
        case_id="gdpr_art15_case1",
        probes="enumeration - a 10-item answer",
        core_baseline="10 core, one per item",
        expected_core=10,
        expectation="Every enumerated item CORE, one claim each, with the stem "
                    "repeated so no claim is a bare fragment. This is the case that "
                    "collapsed to ONE claim under the three-example prompt, and the "
                    "one whose ten claims produced stage C's two useful `absent` "
                    "findings. PROBE 4 of the adversarial set is this shape, and the "
                    "old model packed it while the new one split it.",
        basis="the assistant's classification, though the least contestable of the "
              "five: the question asks what details must be provided.",
    ),
    BaselineCase(
        case_id="gdpr_art41_case3",
        probes="*renewal* stays auxiliary",
        core_baseline="1 core",
        expected_core=1,
        expectation="CORE: 'Accreditation is granted for a maximum period of five "
                    "years.' AUXILIARY: the renewal clause. Watch for the fragment "
                    "shape - one run of the combined prompt returned 'and may be "
                    "renewed on the same conditions, provided...' AND TAGGED IT CORE, "
                    "which is why this is the one case §4.6 records as worse after "
                    "the prompt work than before it.",
        basis="the assistant's classification",
    ),
]


def norm(text: str) -> str:
    return " ".join(text.split())


def words(text: str) -> List[str]:
    return re.findall(r"[a-z0-9]+", text.lower())


def mechanical_breaches(claims, answer: str) -> List[str]:
    """The checks that rest on no one's classification."""
    found = []

    permitted = set(words(answer))
    extras, seen = [], set()
    for claim in claims:
        for word in words(claim.text):
            if word not in permitted and word not in seen:
                seen.add(word)
                extras.append(word)
    if extras:
        found.append(f"RULE - words not in the ANSWER: {extras}")

    for i, claim in enumerate(claims, 1):
        if norm(claim.text).strip(".").strip().lower() in ("yes", "no"):
            found.append(f"RULE - claim {i} is a bare polarity marker: {claim.text!r}")

    for i, claim in enumerate(claims, 1):
        first = norm(claim.text).split(" ")[0].lower().strip(",")
        if first in _CONTINUATION:
            found.append(
                f"HEURISTIC - claim {i} opens with {first!r}, the fragment shape: "
                f"{claim.text!r}"
            )

    return found


async def main() -> None:
    loaded = {c.case_id: c for c in load_tier1()}
    missing = [c.case_id for c in CASES if c.case_id not in loaded]
    if missing:
        raise SystemExit(f"case ids not found in the golden set: {missing}")

    model_params = get_llm_config()["writer_model"][0]
    print(f"model: {model_params['model']}  "
          f"temperature={model_params['model_args']['temperature']}")
    print(f"cases: {len(CASES)}, all resolved from the golden set\n")

    outputs = await asyncio.gather(*[
        tag_claims(loaded[c.case_id].question, loaded[c.case_id].answer, model_params)
        for c in CASES
    ])

    total_breaches = 0
    for baseline, claims in zip(CASES, outputs):
        case = loaded[baseline.case_id]
        tags = [c.tag for c in claims]
        n_core = tags.count("core")

        print("=" * 78)
        print(f"{case.case_id}  [{case.answer_type}]  article {case.article_number}")
        print(f"probes: {baseline.probes}")
        print(f"\nQ: {case.question}")
        print(f"A: {case.answer}")
        print(f"\n  §4.6 correct output: {baseline.core_baseline}")
        print(f"  expected of A2     : {baseline.expectation}")
        print(f"  basis              : {baseline.basis}")
        print(f"\n  actual: {len(claims)} claims, {n_core} core "
              f"(§4.6 expects {baseline.expected_core})  {tags}")
        for i, claim in enumerate(claims, 1):
            print(f"    {i} [{claim.tag:9}] {claim.text}")
            print(f"        reason: {claim.reason}")

        breaches = mechanical_breaches(claims, case.answer)
        total_breaches += len(breaches)
        if breaches:
            print()
            for breach in breaches:
                print(f"  !! {breach}")
        else:
            print("\n  mechanical checks: clean")

    print("=" * 78)
    print(f"\n{total_breaches} mechanical breach(es) across {len(CASES)} cases.")
    print("Core COUNT is printed for reference; the property that matters is which "
          "material\nis core. A different split of the same core content is not a "
          "defect.")


if __name__ == "__main__":
    asyncio.run(main())
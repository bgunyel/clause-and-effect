"""
Run A1 over the six real golden-set cases the combined stage A was tuned against.

The third A1 probe. ``probe_a1_examples.py`` fed A1 its own worked examples (a
floor test); ``probe_a1_adversarial.py`` fed it six held-out synthetic cases.
These six are real: they are the cases in design §4.6, the ones three rounds of
prompt work were measured on.

**Read the results knowing what these six are.** They are the *tuning* set. The
combined prompt was revised against them three times, so a good result here is
partly fitted and says little about the other 427 cases. Design §4.6 records this
as the first of two caveats limiting everything in that table, and open item 2 is
to measure on cases not used for tuning. This script is not that measurement.

**Whose standard each expectation is, stated per case.** Only `art7_case3` rests
on a ruling of Bertan's. The other five are the assistant's classification, and
`art7_case4` is the consequential one: round 1 of the prompt work demoted its
third sentence from core to auxiliary, and the 6/6 result in §4.6 is scored
against that reading. Read as core, the same output scores 0/6. Every
``expected`` below carries its ``basis``.

**The expectations are derived, not recorded.** §4.6 tabulates *core claim
counts*, which is combined stage A's output. A1 alone returns a shortest
sufficient answer, which was never separately tabulated, so the strings below are
the assistant's derivation of what that table implies. They are a reading of a
reading in five of six cases.

**One check here needs nobody's agreement.** A1 is told to use only wording that
appears in the ANSWER, so any word in its output that is absent from the gold
answer is a rule breach regardless of how anyone classifies core and auxiliary.
That is reported mechanically. Everything else is printed to be read.

Run:

    uv run python -m scripts.probe_a1_baseline_cases
"""
import asyncio
import re
from dataclasses import dataclass
from typing import List

from scripts.probe_spend import format_spend
from src.eval.dataset import load_tier1
from src.eval.sufficiency.stage_a1 import write_shortest_answer
from src.llm_config import get_llm_config


@dataclass(frozen=True)
class BaselineCase:
    """One §4.6 case, what it probes, and the shortest answer expected of A1."""

    case_id: str
    probes: str  # the §4.6 "what it probes" column
    core_baseline: str  # the §4.6 "correct output" column, verbatim
    expected: str  # what that implies for A1 alone
    basis: str  # whose standard the expectation is


CASES: List[BaselineCase] = [
    BaselineCase(
        case_id="gdpr_art7_case3",
        probes="the case the criterion was settled on",
        core_baseline="1 core; prior-lawfulness auxiliary",
        expected="Yes. The data subject shall have the right to withdraw their "
                 "consent at any time.",
        basis="BERTAN'S RULING - the only one of the six that is not the "
              "assistant's classification. The prior-lawfulness sentence is "
              "auxiliary because it is not what the question asked.",
    ),
    BaselineCase(
        case_id="gdpr_art7_case4",
        probes="polarity - is `No.` split off?",
        core_baseline="1 core, `No.` attached",
        expected="No. The withdrawal of consent does not affect the lawfulness of "
                 "processing that was based on consent before the withdrawal.",
        basis="THE ASSISTANT'S CLASSIFICATION, AND THE DISPUTED ONE. Round 1 "
              "demoted the third sentence ('The data processed while consent was "
              "still valid remains lawfully processed') from core to auxiliary. "
              "Read as core instead, the expectation is the whole answer and the "
              "§4.6 6/6 becomes 0/6. Open item 5; Bertan's call, undecided.",
    ),
    BaselineCase(
        case_id="gdpr_art8_case1",
        probes="implication - is a consequence tagged core?",
        core_baseline="1 core",
        expected="The minimum age is 16 years old.",
        basis="the assistant's classification. The second sentence is a "
              "consequence that adds specificity, so it is auxiliary. This is the "
              "case whose four identical runs returned 1/1/2/1 core claims and "
              "flipped the verdict.",
    ),
    BaselineCase(
        case_id="gdpr_art33_case1",
        probes="consequence - *reasons for delay* stays auxiliary",
        core_baseline="1 core",
        expected="The controller must notify the supervisory authority without undue "
                 "delay and, where feasible, within 72 hours after becoming aware of "
                 "the breach.",
        basis="the assistant's classification. The reasons-for-delay sentence is a "
              "consequence of missing the deadline, not part of how quickly the "
              "breach must be reported.",
    ),
    BaselineCase(
        case_id="gdpr_art15_case1",
        probes="enumeration - a 10-item answer",
        core_baseline="10 core, one per item",
        expected="Effectively the whole answer: confirmation of processing, the "
                 "personal data itself, and all ten enumerated items. This is the "
                 "case that collapsed from ten core claims to one under the "
                 "three-example prompt, and the one whose ten claims produced the "
                 "two useful `absent` findings from stage C.",
        basis="the assistant's classification, though the least contestable of the "
              "five: the question asks what details must be provided, so every "
              "item is one of the details asked for.",
    ),
    BaselineCase(
        case_id="gdpr_art41_case3",
        probes="*renewal* stays auxiliary",
        core_baseline="1 core",
        expected="Accreditation is granted for a maximum period of five years.",
        basis="the assistant's classification. NOTE: this is the one case now "
              "worse than before the prompt work started - 1 run in 3 promoted the "
              "renewal clause to core, and one run returned it as a sentence "
              "fragment. It is also flagged in judge.py as an invalid case (the "
              "article has no such content), but that is a defect in the quote, "
              "which A1 never sees, so A1's job here is unaffected.",
    ),
]


def norm(text: str) -> str:
    """Collapse whitespace, so wrapped literals compare to flat model output."""
    return " ".join(text.split())


def words(text: str) -> List[str]:
    """Alphanumeric tokens, lowercased. Splits on the em-dash `art8_case1` carries."""
    return re.findall(r"[a-z0-9]+", text.lower())


def introduced_words(actual: str, answer: str) -> List[str]:
    """
    Words in A1's output that do not appear in the gold answer.

    The one check in this script that rests on no one's classification: A1 is
    told to use only wording that appears in the ANSWER, so anything here is a
    rule breach however core and auxiliary are drawn.
    """
    permitted = set(words(answer))
    seen, extras = set(), []
    for word in words(actual):
        if word not in permitted and word not in seen:
            seen.add(word)
            extras.append(word)
    return extras


async def main() -> None:
    loaded = {c.case_id: c for c in load_tier1()}

    # Fail on a missing id rather than filtering it out. judge.py builds its probe
    # list with `if c in cases`, which silently shrinks the sample when an id stops
    # resolving — acceptable for a harness meant to be read, not for a measurement.
    missing = [c.case_id for c in CASES if c.case_id not in loaded]
    if missing:
        raise SystemExit(f"case ids not found in the golden set: {missing}")

    model_params = get_llm_config()["sufficiency_judge"][0]
    print(f"model: {model_params['model']}  "
          f"temperature={model_params['model_args']['temperature']}")
    print(f"cases: {len(CASES)}, all resolved from the golden set\n")
    print("These six are the TUNING set. A good result here is partly fitted.\n")

    responses = await asyncio.gather(*[
        write_shortest_answer(
            loaded[c.case_id].question, loaded[c.case_id].answer, model_params
        )
        for c in CASES
    ])
    outputs = [r.value for r in responses]

    breaches = 0
    for baseline, actual in zip(CASES, outputs):
        case = loaded[baseline.case_id]
        print("=" * 78)
        print(f"{case.case_id}  [{case.answer_type}]  article {case.article_number}")
        print(f"probes: {baseline.probes}")
        print(f"\nQ: {case.question}")
        print(f"A: {case.answer}")
        print(f"\n  §4.6 correct output: {baseline.core_baseline}")
        print(f"  expected of A1     : {baseline.expected}")
        print(f"  basis              : {baseline.basis}")
        print(f"\n  actual             : {actual!r}")

        extras = introduced_words(actual, case.answer)
        if extras:
            breaches += 1
            print(f"\n  !! introduced words not in the gold answer: {extras}")
        else:
            print("\n  wording check: no word introduced that is absent from the answer")

    print("=" * 78)
    print(f"\n{breaches} of {len(CASES)} outputs introduced wording not in the gold "
          f"answer.")
    print("Everything else above is for reading: five of the six standards are the "
          "assistant's,\nand these are the cases the prompt was tuned on.")
    print(format_spend(responses))


if __name__ == "__main__":
    asyncio.run(main())
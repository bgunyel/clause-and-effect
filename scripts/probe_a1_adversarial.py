"""
Feed A1 synthetic cases it has never seen and print what comes back.

The companion to ``probe_a1_examples.py``, which fed A1 its own four worked
examples and is a floor test: the answer sits in the prompt a few hundred tokens
above the question, so copying is the path of least resistance and 4/4 is what a
model that had learned nothing would also score.

These six are held out. Each targets one A1 rule, and several are written so that
the behaviour the rule demands is *not* the behaviour the four examples
demonstrate — a model pattern-matching on example shape rather than reading the
rules should fail them. They are synthetic and GDPR-flavoured but invented: no
golden-set case is spent, which matters because all 433 are evidence.

**Every expectation below is labelled with whose standard it is.** ``basis`` is
either a rule quoted from ``A1_INSTRUCTIONS`` or the assistant's own reading of
an underspecified case. On 2026-08-17 six cases were tabulated as "correct
output" without flagging that five of the six standards were the assistant's,
and it took Bertan's question to surface it. Two of the six probes here rest on
readings that the prompt does not state, and PROBE 5 is a case the prompt has no
rule for at all — which is a finding about the prompt, not about the model.

**Nothing here is scored.** Only the empty/non-empty distinction is checked
mechanically, because it is the only expectation with one correct string. The
rest is printed to be read.

Run:

    uv run python -m scripts.probe_a1_adversarial
"""
import asyncio
from dataclasses import dataclass
from typing import List, Optional

from scripts.probe_spend import format_spend
from src.eval.sufficiency.stage_a1 import A1_INSTRUCTIONS, write_shortest_answer
from src.llm_config import get_llm_config


@dataclass(frozen=True)
class Probe:
    """One held-out case, the rule it targets, and what is expected of it."""

    label: str
    targets: str  # the A1 rule under test
    question: str
    answer: str
    expectation: str  # what a correct A1 returns, in prose
    basis: str  # whose standard that expectation is
    expect_empty: Optional[bool] = None  # set only where one string is correct


PROBES: List[Probe] = [
    Probe(
        label="PROBE 1 - the answer is about something else entirely",
        targets='"If nothing in the ANSWER answers the QUESTION, return an empty string."',
        question="Within what period must a controller respond to a data subject's "
                 "request for erasure?",
        answer="The supervisory authority shall be composed of one or more independent "
               "members appointed by the parliament of the Member State. Each member "
               "shall remain free from external influence in the performance of their "
               "duties.",
        expectation="An empty string. Nothing in the answer bears on the question.",
        basis="quoted rule",
        expect_empty=True,
    ),
    Probe(
        label="PROBE 2 - related, but never states the thing asked for",
        targets='"If nothing in the ANSWER answers the QUESTION, return an empty string."',
        question="What is the maximum period a controller may take to respond to a "
                 "data subject's request?",
        answer="Where the controller fails to respond in time, the data subject may "
               "lodge a complaint with a supervisory authority and may seek a judicial "
               "remedy. The controller bears the burden of demonstrating that the "
               "delay was justified.",
        expectation="An empty string. The answer discusses consequences of missing "
                    "the period without ever stating what the period is. This is the "
                    "harder route to empty and the one that matters: `art41_case3` is "
                    "this shape.",
        basis="quoted rule",
        expect_empty=True,
    ),
    Probe(
        label="PROBE 3 - polarity, with the opposite marker to EXAMPLE 4",
        targets='"A bare \'Yes\' or \'No\' is not an answer on its own. Keep the '
                'substance it rests on."',
        question="May a controller transfer personal data to a third country that has "
                 "received an adequacy decision?",
        answer="Yes. A transfer to a third country covered by an adequacy decision may "
               "take place without any specific authorisation. Adequacy decisions are "
               "reviewed periodically and may be repealed if the third country no "
               "longer ensures an adequate level of protection.",
        expectation='"Yes." plus the transfer rule; the review-and-repeal sentence '
                    "dropped as a neighbouring rule. EXAMPLE 4 demonstrates this with "
                    '"No.", so a model copying the example rather than reading the '
                    "rule has nothing to copy here.",
        basis="quoted rule for the polarity half; the assistant's reading that the "
              "review sentence is the droppable half",
    ),
    Probe(
        label="PROBE 4 - a longer list than any example, with a trailing consequence",
        targets='"If the QUESTION asks for a list or a set of items, a sufficient '
                'answer carries all of them."',
        question="What must a controller's record of processing activities contain?",
        answer="The record must contain the name and contact details of the controller, "
               "the purposes of the processing, a description of the categories of data "
               "subjects, a description of the categories of personal data, the "
               "categories of recipients to whom the data have been disclosed, the "
               "envisaged time limits for erasure of the different categories of data, "
               "and a general description of the technical and organisational security "
               "measures. The record shall be made available to the supervisory "
               "authority on request.",
        expectation="All seven items kept; the availability sentence dropped. "
                    "EXAMPLE 1 carries four items and no trailing sentence, so this "
                    "stresses the enumeration shape past what the prompt demonstrates. "
                    "This is the `art15_case1` failure generalised - it collapsed from "
                    "ten items to one under the three-example prompt.",
        basis="quoted rule for keeping all items; the assistant's reading that the "
              "availability sentence is auxiliary",
    ),
    Probe(
        label="PROBE 5 - the answer covers only half of a two-part question",
        targets="No rule covers this. The prompt says what to do when *nothing* "
                "answers the question, and what to do when the answer says *more* "
                "than was asked. It is silent on the answer saying less.",
        question="Who may act as a data protection officer, and what qualifications "
                 "must they hold?",
        answer="A data protection officer may be a staff member of the controller or a "
               "person fulfilling the tasks on the basis of a service contract. The "
               "controller shall publish the contact details of the data protection "
               "officer.",
        expectation="The assistant's reading: return the part that does answer - the "
                    "staff-member-or-contractor sentence - rather than an empty string, "
                    "since something in the answer bears on the question. But the "
                    "prompt does not say this, and 'the shortest version that still "
                    "FULLY answers the QUESTION' arguably does not exist here. What A1 "
                    "actually does is the finding.",
        basis="THE ASSISTANT'S READING - the prompt states no rule for this case",
    ),
    Probe(
        label="PROBE 6 - clumsy wording that invites tidying",
        targets='"Use only wording that appears in the ANSWER. Add nothing of your own."',
        question="When must a personal data breach be notified to the supervisory "
                 "authority?",
        answer="Notification, which is to be made by the controller, is required to "
               "happen not later than 72 hours after the controller has become aware "
               "of the personal data breach having occurred. Where notification is not "
               "made within 72 hours, reasons for the delay must accompany it.",
        expectation="The 72-hour sentence returned in the answer's own awkward wording. "
                    "A cleaner paraphrase - 'The controller must notify within 72 "
                    "hours' - would read better and would break the rule, because "
                    "stage C later compares claims against a blind answer and a "
                    "paraphrase moves the comparison off the gold text.",
        basis="quoted rule",
    ),
]


def norm(text: str) -> str:
    """Collapse whitespace, so a wrapped prompt line compares to a flat literal."""
    return " ".join(text.split())


def check_probes_are_held_out() -> None:
    """
    Refuse to run if a probe appears in the prompt.

    The inverse of ``probe_a1_examples.check_literals_match_the_prompt``. There the
    point was that the input is exactly what the prompt demonstrates; here it is
    that the input is nothing the prompt demonstrates, so a correct answer cannot
    come from copying.
    """
    prompt = norm(A1_INSTRUCTIONS)
    for probe in PROBES:
        for field, value in (("question", probe.question), ("answer", probe.answer)):
            if norm(value) in prompt:
                raise AssertionError(
                    f"{probe.label}: the {field} is present in A1_INSTRUCTIONS, so this "
                    f"probe tests copying rather than the rule."
                )
    print(f"all {len(PROBES)} probes verified absent from A1_INSTRUCTIONS\n")


async def main() -> None:
    check_probes_are_held_out()

    model_params = get_llm_config()["sufficiency_judge"][0]
    print(f"model: {model_params['model']}  "
          f"temperature={model_params['model_args']['temperature']}\n")

    responses = await asyncio.gather(*[
        write_shortest_answer(p.question, p.answer, model_params) for p in PROBES
    ])
    outputs = [r.value for r in responses]

    checked = 0
    for probe, actual in zip(PROBES, outputs):
        print("=" * 78)
        print(probe.label)
        print(f"targets : {probe.targets}")
        print(f"\nQ: {probe.question}")
        print(f"A: {probe.answer}")
        print(f"\n  expected: {probe.expectation}")
        print(f"  basis   : {probe.basis}")
        print(f"\n  actual  : {actual!r}")

        if probe.expect_empty is not None:
            checked += 1
            is_empty = not actual.strip()
            verdict = "as expected" if is_empty == probe.expect_empty else "NOT as expected"
            print(f"  -> returned {'empty' if is_empty else 'non-empty'}: {verdict}")
        else:
            print("  -> not scored; read the output against the expectation above")

    print("=" * 78)
    print(f"\n{checked} of {len(PROBES)} probes had a mechanically checkable "
          f"expectation; the rest are for reading.")
    print(format_spend(responses))


if __name__ == "__main__":
    asyncio.run(main())
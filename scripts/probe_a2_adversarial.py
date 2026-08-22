"""
Feed A2 synthetic cases it has never seen and print what comes back.

The A2 counterpart of ``probe_a1_adversarial.py``. ``probe_a2_examples.py`` fed
A2 its own worked examples and scored 4/4 on count, tags and texts - a floor
test, where the expected claims sit in the prompt above the input and copying is
the path of least resistance. These six are held out.

**The probes are weighted toward one direction of error, deliberately.** The
judge's output is a work list of golden-set cases to repair, so the two error
types cost different amounts (Bertan, 2026-08-22):

    a claim wrongly tagged CORE       -> a spurious `absent` from stage C, which
                                         a human reads and dismisses. Visible.
    a claim wrongly tagged AUXILIARY  -> the quote is never asked to support it,
                                         a defective case is certified sound, and
                                         nothing ever raises it again. Silent.

Four of the six below probe the silent direction. Two of those are **rule
collisions**: the prompt says a consequence is auxiliary and that added
specificity is auxiliary, and both probes ask a question whose answer *is* the
consequence or *is* the specificity. Applied mechanically the rule gives the
wrong tag, and the wrong tag is the invisible one.

**Every expectation is labelled with whose standard it is** - see the same note
in ``probe_a1_adversarial.py``. Four of these rest on the assistant's reading of
what the question asks for, which is exactly the kind of judgement that needs
Bertan's agreement rather than the assistant's confidence.

**Four checks here need nobody's agreement**, and are reported mechanically:

    introduced words     a word not in the ANSWER breaks a stated rule
    bare polarity        a claim of only "Yes"/"No" is never correct output
    single-claim answer  the whole ANSWER returned as one claim is forbidden
    leading conjunction  HEURISTIC, not a rule - flags the sentence-fragment
                         shape (`"and may be renewed on the same conditions..."`)
                         that design §4.6 records as an unfixed residue

The atomicity rule that would fix fragments is deliberately NOT applied to this
prompt, so PROBE 5 is expected to be able to fail.

Run:

    uv run python -m scripts.probe_a2_adversarial
"""
import asyncio
import re
from dataclasses import dataclass
from typing import List

from src.eval.sufficiency.stage_a2 import A2_INSTRUCTIONS, tag_claims
from src.llm_config import get_llm_config

# Words that begin a continuation rather than an assertion. A claim opening with
# one is very likely a fragment sheared off the sentence before it.
_CONTINUATION = ("and", "or", "but", "provided", "which", "including", "where",
                 "unless", "having", "whichever")


@dataclass(frozen=True)
class Probe:
    """One held-out case, the rule it targets, and what is expected of it."""

    label: str
    targets: str
    direction: str  # which way an error here would go, and whether it is visible
    question: str
    answer: str
    expectation: str
    basis: str


PROBES: List[Probe] = [
    Probe(
        label="PROBE 1 - RULE COLLISION: the consequence IS the answer",
        targets='"A claim that ... follows from it as a consequence ... is AUXILIARY."',
        direction="SILENT if wrong - the sentence that answers the question would be "
                  "tagged auxiliary, so the quote is never asked to support it.",
        question="What happens if a controller fails to notify a personal data breach "
                 "within 72 hours?",
        answer="The controller must notify the supervisory authority within 72 hours of "
               "becoming aware of a personal data breach. Where notification is not "
               "made within that period, it must be accompanied by reasons for the "
               "delay, and the supervisory authority may impose an administrative fine.",
        expectation="The second sentence is CORE - it is what the question asks for - "
                    "and splits into two claims (reasons for the delay; the fine). The "
                    "72-hour rule is context the question did not ask about, so it is "
                    "AUXILIARY. A model applying 'a consequence is AUXILIARY' "
                    "mechanically will invert this exactly.",
        basis="the assistant's reading of what the question asks for",
    ),
    Probe(
        label="PROBE 2 - RULE COLLISION: the specificity IS the answer",
        targets='"...or that adds specificity it does not carry, is AUXILIARY."',
        direction="SILENT if wrong - the figures are the answer, and tagging them "
                  "auxiliary certifies a quote that need not contain them.",
        question="What is the maximum administrative fine for infringing the basic "
                 "principles for processing?",
        answer="Infringements of the basic principles for processing are subject to "
               "administrative fines. The fine may be up to 20 000 000 EUR, or in the "
               "case of an undertaking, up to 4 % of total worldwide annual turnover of "
               "the preceding financial year, whichever is higher.",
        expectation="The figures sentence is CORE. The first sentence states only that "
                    "fines apply, which does not answer 'what is the maximum', so it is "
                    "AUXILIARY. A model reading 'adds specificity -> AUXILIARY' "
                    "mechanically demotes the one sentence that answers the question.",
        basis="the assistant's reading of what the question asks for",
    ),
    Probe(
        label="PROBE 3 - a two-part question where both parts are core",
        targets='"How many claims come back CORE follows from the ANSWER and the '
                'QUESTION, not from habit."',
        direction="SILENT if wrong - the 'how' half reads as elaboration of the 'who' "
                  "half, and demoting it excuses a quote that answers only half.",
        question="Who is responsible for demonstrating compliance with the data "
                 "protection principles, and how must they do it?",
        answer="The controller is responsible for demonstrating compliance with the "
               "principles. Compliance must be demonstrated by implementing appropriate "
               "technical and organisational measures and by maintaining records of "
               "processing activities. Supervisory authorities may request evidence at "
               "any time.",
        expectation="Both halves CORE: the controller is responsible, and the two means "
                    "of demonstrating it (measures; records) - the conjunction splits. "
                    "The supervisory-authority sentence is AUXILIARY, a neighbouring "
                    "rule. So 3 core of 4, or 2 of 3 if the means stay one claim.",
        basis="the assistant's reading; the question asks two things in as many words, "
              "which makes this the least contestable of the four silent-direction "
              "probes",
    ),
    Probe(
        label="PROBE 4 - a five-item enumeration with a genuine consequence after it",
        targets='"If the QUESTION asks for a list or a set of items, every item is '
                'CORE." / "Never return the whole ANSWER as a single claim."',
        direction="SILENT if it collapses - `art15_case1` went from ten core claims to "
                  "one under the three-example prompt, and one wholesale claim turns "
                  "two real stage C findings into a single uninformative label.",
        question="What must a data protection impact assessment contain?",
        answer="The assessment must contain a systematic description of the envisaged "
               "processing operations, the purposes of the processing, an assessment of "
               "the necessity and proportionality of the processing, an assessment of "
               "the risks to the rights and freedoms of data subjects, and the measures "
               "envisaged to address those risks. Where the assessment indicates a high "
               "risk, the controller shall consult the supervisory authority before "
               "processing.",
        expectation="Five CORE claims, one per item, and the consultation sentence "
                    "AUXILIARY. EXAMPLE 1 demonstrates four items and no trailing "
                    "sentence, so this runs past the shape the prompt shows.",
        basis="quoted rule for keeping every item; the assistant's reading that the "
              "consultation sentence is auxiliary",
    ),
    Probe(
        label="PROBE 5 - over-split bait: one assertion carrying a proviso",
        targets='"...but do not split so far that a fragment stops meaning anything on '
                'its own."',
        direction="VISIBLE if wrong - a fragment handed to stage C cannot be judged "
                  "supported or absent usefully, and it shows up as nonsense on the "
                  "work list rather than hiding.",
        question="When may a supervisory authority impose a temporary limitation on "
                 "processing?",
        answer="A supervisory authority may impose a temporary or definitive limitation "
               "including a ban on processing where the controller has failed to comply "
               "with an order previously issued by that authority, provided that the "
               "limitation is appropriate, necessary and proportionate having regard to "
               "the circumstances of each individual case.",
        expectation="ONE core claim, kept whole. The 'provided that...' clause is a "
                    "condition on the same assertion, not a separate one; split off it "
                    "becomes the exact fragment shape §4.6 records as unfixed - "
                    "`art41_case3` returned 'and may be renewed on the same conditions, "
                    "provided...' and tagged it core. THE ATOMICITY RULE THAT WOULD FIX "
                    "THIS IS NOT IN THIS PROMPT, so a failure here is expected and is "
                    "not evidence against the call split.",
        basis="quoted rule, but the residue it names is known and unfixed",
    ),
    Probe(
        label="PROBE 6 - polarity, with two substantive core sentences after it",
        targets='"A claim consisting only of \'Yes\' or \'No\' is never correct output."',
        direction="MIXED - a bare 'Yes.' claim is visible nonsense; demoting the "
                  "'must stop' half is silent and worse.",
        question="Can a data subject object to processing for direct marketing, and "
                 "must the controller then stop?",
        answer="Yes. The data subject may object at any time to processing of personal "
               "data for direct marketing purposes. Where the data subject objects, the "
               "personal data shall no longer be processed for such purposes. The right "
               "to object must be brought to the data subject's attention at the latest "
               "at the time of the first communication.",
        expectation="'Yes.' stays attached to the first substantive claim. Two CORE - "
                    "the right to object, and that processing must stop - because the "
                    "question asks both. The attention sentence is AUXILIARY. EXAMPLE 4 "
                    "shows polarity with ONE core claim, so a model copying it will "
                    "produce one core here and drop the half about stopping.",
        basis="quoted rule for the polarity half; the assistant's reading that the "
              "stopping half is core and the attention sentence is not",
    ),
]


def norm(text: str) -> str:
    """Collapse whitespace, so a wrapped literal compares to flat model output."""
    return " ".join(text.split())


def words(text: str) -> List[str]:
    """Alphanumeric tokens, lowercased."""
    return re.findall(r"[a-z0-9]+", text.lower())


def check_probes_are_held_out() -> None:
    """Refuse to run if a probe appears in the prompt, which would test copying."""
    prompt = norm(A2_INSTRUCTIONS)
    for probe in PROBES:
        for field, value in (("question", probe.question), ("answer", probe.answer)):
            if norm(value) in prompt:
                raise AssertionError(
                    f"{probe.label}: the {field} is present in A2_INSTRUCTIONS, so this "
                    f"probe tests copying rather than the rule."
                )
    print(f"all {len(PROBES)} probes verified absent from A2_INSTRUCTIONS\n")


def mechanical_breaches(claims, answer: str) -> List[str]:
    """
    The checks that rest on no one's classification.

    Three are stated rules; the fourth is a heuristic and is labelled as one.
    """
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

    if len(claims) == 1 and len(words(claims[0].text)) >= 0.9 * len(words(answer)):
        found.append("RULE - the whole ANSWER came back as a single claim")

    for i, claim in enumerate(claims, 1):
        first = norm(claim.text).split(" ")[0].lower().strip(",")
        if first in _CONTINUATION:
            found.append(
                f"HEURISTIC - claim {i} opens with {first!r}, the fragment shape: "
                f"{claim.text!r}"
            )

    return found


async def main() -> None:
    check_probes_are_held_out()

    model_params = get_llm_config()["writer_model"][0]
    print(f"model: {model_params['model']}  "
          f"temperature={model_params['model_args']['temperature']}\n")

    outputs = await asyncio.gather(*[
        tag_claims(p.question, p.answer, model_params) for p in PROBES
    ])

    total_breaches = 0
    for probe, claims in zip(PROBES, outputs):
        tags = [c.tag for c in claims]
        print("=" * 78)
        print(probe.label)
        print(f"targets  : {probe.targets}")
        print(f"direction: {probe.direction}")
        print(f"\nQ: {probe.question}")
        print(f"A: {probe.answer}")
        print(f"\n  expected: {probe.expectation}")
        print(f"  basis   : {probe.basis}")
        print(f"\n  actual  : {len(claims)} claims, {tags.count('core')} core  {tags}")
        for i, claim in enumerate(claims, 1):
            print(f"    {i} [{claim.tag:9}] {claim.text}")
            print(f"        reason: {claim.reason}")

        breaches = mechanical_breaches(claims, probe.answer)
        total_breaches += len(breaches)
        if breaches:
            print()
            for breach in breaches:
                print(f"  !! {breach}")
        else:
            print("\n  mechanical checks: clean")

    print("=" * 78)
    print(f"\n{total_breaches} mechanical breach(es) across {len(PROBES)} probes.")
    print("The tags themselves are for reading: four of the six expectations are the "
          "assistant's\nreading of what the question asks for, and those need Bertan's "
          "agreement to mean anything.")


if __name__ == "__main__":
    asyncio.run(main())
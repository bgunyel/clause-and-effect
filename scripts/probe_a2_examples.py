"""
Feed A2 its own four worked examples and print what comes back.

The A2 counterpart of ``probe_a1_examples.py``, and the same floor test: the
expected claims sit in the prompt a few hundred tokens above the input, so
copying is the path of least resistance. Failing here would be serious; passing
says little about real cases.

The four cases are written as literals - questions, answers, and every expected
claim text - and checked against ``A2_INSTRUCTIONS`` verbatim before any call
goes out. Parsing them out of the prompt instead would mean a defective prompt
feeds itself defective input and agrees with itself.

**A2's output is a list, so there are three levels of agreement**, reported
separately because they fail for different reasons:

    count   how many claims came back
    tags    the core/auxiliary sequence - this is what stage C consumes
    texts   the exact claim strings

The tag sequence is the one that matters most. Stage C sees core claims only, so
a wrong count with right tags and a right count with wrong tags are not the same
defect. Design §4.6 measured stability on the core-claim *set* for this reason.

``Claim.reason`` is printed for every claim. With the written STEP 1 gone from
A2's output, it is the only trace of how the tag was decided - and it is the
field that diagnosed both 2026-08-17 divergences.

Run:

    uv run python -m scripts.probe_a2_examples
"""
import asyncio
from dataclasses import dataclass
from typing import List, Tuple

from scripts.probe_spend import format_spend
from src.eval.sufficiency.stage_a2 import A2_INSTRUCTIONS, tag_claims
from src.llm_config import get_llm_config


@dataclass(frozen=True)
class Example:
    """One of A2's own worked examples, and the claims the prompt shows for it."""

    label: str
    question: str
    answer: str
    expected: List[Tuple[str, str]]  # (tag, text) in the order the prompt lists them


EXAMPLES: List[Example] = [
    Example(
        label="EXAMPLE 1  (4 claims, 4 core - enumeration)",
        question="What information must a controller give a data subject when "
                 "collecting data directly from them?",
        answer="The controller must provide the identity and contact details of the "
               "controller, the purposes of the processing, the legal basis for the "
               "processing, and the period for which the personal data will be stored.",
        expected=[
            ("core", "The controller must provide the identity and contact details of "
                     "the controller."),
            ("core", "The controller must provide the purposes of the processing."),
            ("core", "The controller must provide the legal basis for the processing."),
            ("core", "The controller must provide the period for which the personal "
                     "data will be stored."),
        ],
    ),
    Example(
        label="EXAMPLE 2  (3 claims, 2 core - conjunction split, consequence auxiliary)",
        question="Who must appoint a data protection officer?",
        answer="A data protection officer must be appointed by any public authority or "
               "body, and by any controller whose core activities involve large-scale "
               "regular and systematic monitoring of data subjects. Failure to "
               "designate one where it is required can attract an administrative fine.",
        expected=[
            ("core", "A data protection officer must be appointed by any public "
                     "authority or body."),
            ("core", "A data protection officer must be appointed by any controller "
                     "whose core activities involve large-scale regular and systematic "
                     "monitoring of data subjects."),
            ("auxiliary", "Failure to designate one where it is required can attract "
                          "an administrative fine."),
        ],
    ),
    Example(
        label="EXAMPLE 3  (3 claims, 1 core - consequence repeats the same period)",
        question="How long may a supervisory authority take to respond to a complaint?",
        answer="The supervisory authority must inform the complainant of the progress "
               "of the complaint within three months. If it does not respond within "
               "three months, the complainant may seek a judicial remedy. A complaint "
               "may be lodged in the Member State of the data subject's habitual "
               "residence.",
        expected=[
            ("core", "The supervisory authority must inform the complainant of the "
                     "progress of the complaint within three months."),
            ("auxiliary", "If it does not respond within three months, the complainant "
                          "may seek a judicial remedy."),
            ("auxiliary", "A complaint may be lodged in the Member State of the data "
                          "subject's habitual residence."),
        ],
    ),
    Example(
        label="EXAMPLE 4  (2 claims, 1 core - polarity stays attached)",
        question="Does a data subject have to pay a fee to obtain a copy of their "
                 "personal data?",
        answer="No. The first copy of personal data must be provided free of charge. "
               "The controller may charge a reasonable fee for any further copies "
               "requested.",
        expected=[
            ("core", "No. The first copy of personal data must be provided free of "
                     "charge."),
            ("auxiliary", "The controller may charge a reasonable fee for any further "
                          "copies requested."),
        ],
    ),
]


def norm(text: str) -> str:
    """Collapse whitespace, so a wrapped prompt line compares to a flat literal."""
    return " ".join(text.split())


def check_literals_match_the_prompt() -> None:
    """Refuse to run if a literal above is not in the prompt exactly as written."""
    prompt = norm(A2_INSTRUCTIONS)
    for example in EXAMPLES:
        fields = [("question", example.question), ("answer", example.answer)]
        fields += [(f"claim {i}", text) for i, (_, text) in enumerate(example.expected, 1)]
        for field, value in fields:
            if norm(value) not in prompt:
                raise AssertionError(
                    f"{example.label}: the {field} literal is not verbatim in "
                    f"A2_INSTRUCTIONS.\n  {norm(value)[:120]}..."
                )
    total = sum(len(e.expected) for e in EXAMPLES)
    print(f"all {len(EXAMPLES)} examples and {total} claim texts verified verbatim "
          f"against A2_INSTRUCTIONS\n")


async def main() -> None:
    check_literals_match_the_prompt()

    model_params = get_llm_config()["sufficiency_judge"][0]
    print(f"model: {model_params['model']}  "
          f"temperature={model_params['model_args']['temperature']}\n")

    responses = await asyncio.gather(*[
        tag_claims(e.question, e.answer, model_params) for e in EXAMPLES
    ])
    outputs = [r.value for r in responses]

    counts_ok = tags_ok = texts_ok = 0
    for example, claims in zip(EXAMPLES, outputs):
        expected_tags = [tag for tag, _ in example.expected]
        actual_tags = [c.tag for c in claims]
        expected_texts = [norm(t) for _, t in example.expected]
        actual_texts = [norm(c.text) for c in claims]

        count_match = len(claims) == len(example.expected)
        tag_match = actual_tags == expected_tags
        text_match = actual_texts == expected_texts
        counts_ok += count_match
        tags_ok += tag_match
        texts_ok += text_match

        print("=" * 78)
        print(example.label)
        print(f"Q: {example.question}")
        print(f"A: {example.answer}")

        n_core_expected = expected_tags.count("core")
        n_core_actual = actual_tags.count("core")
        print(f"\n  expected: {len(example.expected)} claims, "
              f"{n_core_expected} core  {expected_tags}")
        print(f"  actual  : {len(claims)} claims, "
              f"{n_core_actual} core  {actual_tags}")

        print("\n  claims returned:")
        for i, claim in enumerate(claims, 1):
            expected_text = expected_texts[i - 1] if i <= len(expected_texts) else None
            expected_tag = expected_tags[i - 1] if i <= len(expected_tags) else None
            flags = []
            if expected_tag is not None and claim.tag != expected_tag:
                flags.append(f"TAG differs (expected {expected_tag})")
            if expected_text is not None and norm(claim.text) != expected_text:
                flags.append("TEXT differs")
            if expected_text is None:
                flags.append("EXTRA claim")
            marker = "  <-- " + "; ".join(flags) if flags else ""
            print(f"    {i} [{claim.tag:9}] {claim.text}{marker}")
            print(f"        reason: {claim.reason}")
        for i in range(len(claims) + 1, len(example.expected) + 1):
            print(f"    {i} [MISSING  ] {example.expected[i - 1][1]}")

        print(f"\n  count {'OK' if count_match else 'DIFFERS'}  |  "
              f"tags {'OK' if tag_match else 'DIFFER'}  |  "
              f"texts {'OK' if text_match else 'DIFFER'}")

    n = len(EXAMPLES)
    print("=" * 78)
    print(f"\ncount matched {counts_ok}/{n}   tags matched {tags_ok}/{n}   "
          f"texts matched {texts_ok}/{n}")
    print("Floor test: the expected output is in the prompt above the input.")
    print(format_spend(responses))


if __name__ == "__main__":
    asyncio.run(main())
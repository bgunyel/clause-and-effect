"""
Feed A1 its own four worked examples and print what comes back.

A floor test, not a ceiling test: the input is present verbatim in the prompt's
own example block, so reproducing it is the easiest thing the stage will ever be
asked to do. Failing here would be serious; passing says little about real cases.

The four cases are written as literals and then checked against
``A1_INSTRUCTIONS`` verbatim (whitespace-normalised, since the prompt wraps).
Parsing them out of the prompt instead would mean a defective prompt feeds itself
defective input and agrees with itself.
"""
import asyncio

from scripts.probe_spend import format_spend
from src.eval.sufficiency.stage_a1 import A1_INSTRUCTIONS, write_shortest_answer
from src.llm_config import get_llm_config

# (label, QUESTION, ANSWER, the shortest sufficient answer the prompt shows)
EXAMPLES = [
    (
        "EXAMPLE 1  (enumeration - shortest answer is the whole ANSWER)",
        "What information must a controller give a data subject when collecting data "
        "directly from them?",
        "The controller must provide the identity and contact details of the "
        "controller, the purposes of the processing, the legal basis for the "
        "processing, and the period for which the personal data will be stored.",
        "The controller must provide the identity and contact details of the "
        "controller, the purposes of the processing, the legal basis for the "
        "processing, and the period for which the personal data will be stored.",
    ),
    (
        "EXAMPLE 2  (two obligations kept, a consequence dropped)",
        "Who must appoint a data protection officer?",
        "A data protection officer must be appointed by any public authority or body, "
        "and by any controller whose core activities involve large-scale regular and "
        "systematic monitoring of data subjects. Failure to designate one where it is "
        "required can attract an administrative fine.",
        "A data protection officer must be appointed by any public authority or body, "
        "and by any controller whose core activities involve large-scale regular and "
        "systematic monitoring of data subjects.",
    ),
    (
        "EXAMPLE 3  (one sentence of three)",
        "How long may a supervisory authority take to respond to a complaint?",
        "The supervisory authority must inform the complainant of the progress of the "
        "complaint within three months. If it does not respond within three months, "
        "the complainant may seek a judicial remedy. A complaint may be lodged in the "
        "Member State of the data subject's habitual residence.",
        "The supervisory authority must inform the complainant of the progress of the "
        "complaint within three months.",
    ),
    (
        "EXAMPLE 4  (polarity stays attached)",
        "Does a data subject have to pay a fee to obtain a copy of their personal data?",
        "No. The first copy of personal data must be provided free of charge. The "
        "controller may charge a reasonable fee for any further copies requested.",
        "No. The first copy of personal data must be provided free of charge.",
    ),
]


def norm(text: str) -> str:
    """Collapse whitespace, so a wrapped prompt line compares to a flat literal."""
    return " ".join(text.split())


def check_literals_match_the_prompt() -> None:
    """Refuse to run if a literal above is not in the prompt exactly as written."""
    prompt = norm(A1_INSTRUCTIONS)
    for label, question, answer, shortest in EXAMPLES:
        for field, value in (("question", question), ("answer", answer),
                             ("shortest", shortest)):
            if norm(value) not in prompt:
                raise AssertionError(
                    f"{label}: the {field} literal is not verbatim in A1_INSTRUCTIONS.\n"
                    f"  {norm(value)[:120]}..."
                )
    print(f"all {len(EXAMPLES)} examples verified verbatim against A1_INSTRUCTIONS\n")


async def main() -> None:
    check_literals_match_the_prompt()

    model_params = get_llm_config()["sufficiency_judge"][0]
    print(f"model: {model_params['model']}  "
          f"temperature={model_params['model_args']['temperature']}\n")

    responses = await asyncio.gather(*[
        write_shortest_answer(question, answer, model_params)
        for _, question, answer, _ in EXAMPLES
    ])
    outputs = [r.value for r in responses]

    exact = 0
    for (label, question, answer, expected), actual in zip(EXAMPLES, outputs):
        match = norm(actual) == norm(expected)
        exact += match
        print("=" * 78)
        print(label)
        print(f"Q: {question}")
        print(f"A: {answer}")
        print(f"\n  expected: {expected}")
        print(f"  actual  : {actual}")
        print(f"\n  exact match: {'YES' if match else 'NO'}")
        if not match:
            print(f"  expected len {len(norm(expected))} chars, "
                  f"actual len {len(norm(actual))} chars")

    print("=" * 78)
    print(f"\n{exact}/{len(EXAMPLES)} reproduced exactly")
    print(format_spend(responses))


if __name__ == "__main__":
    asyncio.run(main())

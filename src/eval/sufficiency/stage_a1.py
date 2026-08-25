"""
Stage A1 — write the shortest version of the gold answer that still answers the
question.

Sees the question and the gold ``answer``. **Never the quote**, and never stage
A2's output: A1 and A2 are two independent derivations, not a pipeline. See
:mod:`src.eval.sufficiency.stage_a_twocall` for why that independence is the
point rather than an implementation detail.
"""
from __future__ import annotations

from typing import Any, Dict

from pydantic import BaseModel, Field

from src.eval.sufficiency.llm import (
    StageResponse,
    build_judge_llm,
    require_response,
)

# The rules are STEP 1's from `stage_a.py`, plus one that used to be implicit.
#
# In the combined prompt, STEP 2's AUXILIARY wording — "elaboration, context, a
# consequence, a neighbouring rule" — sat a few lines below STEP 1 and reached it
# for free. Split into its own call, A1 never sees that wording unless it is
# stated here, so it is stated here. This is the one rule that had to be *added*
# rather than moved, and it is the kind of thing a prompt split silently drops.
#
# The examples are the same four synthetic cases the combined prompt uses,
# rendered to show only the shortest answer. Reusing them is deliberate on two
# counts: they were built synthetic precisely so that no real case is spent as an
# example (all 433 are evidence, and the diagnostic ones are exactly the ones
# worth not spending), and holding them fixed keeps the call split as the only
# variable against the design §4.6 baseline.
#
# Their order is preserved too — the shortest answer runs from "the whole ANSWER"
# down to "one sentence of three". Few-shot teaches shape as readily as rule, and
# a model shown three short shortest-answers first will write short ones. That
# ordering is what repaired `art15_case1`'s collapse from ten core claims to one.
# The specific coupling it defended against cannot occur here — there is no STEP 1
# text in A2's context for A2 to copy — but the enumeration is still the shape
# most at risk, so the defence is kept rather than assumed unnecessary.
A1_INSTRUCTIONS = """\
You are auditing an evaluation dataset for a GDPR question-answering system. Each
test case pairs a QUESTION with a reference ANSWER.

Write the shortest version of the ANSWER that still fully answers the QUESTION.

  - Use only wording that appears in the ANSWER. Add nothing of your own.
  - A bare "Yes" or "No" is not an answer on its own. Keep the substance it rests
    on.
  - If the QUESTION asks for a list or a set of items, a sufficient answer carries
    all of them.
  - Leave out what the ANSWER adds beyond what the QUESTION asked - elaboration,
    context, a consequence, a neighbouring rule. Those belong to the ANSWER, but
    not to the shortest version of it that answers the QUESTION.
  - If nothing in the ANSWER answers the QUESTION, return an empty string.

Judge against the QUESTION exactly as written. Do not consider what a more
thorough question might have asked, and do not consider where the ANSWER's
information came from.

Four worked examples follow. They are illustrations only. Their shapes differ on
purpose - the shortest answer runs from the whole ANSWER down to a single
sentence of three - and the length of your own answer must follow the ANSWER you
are actually given, not any of these.

EXAMPLE 1

QUESTION: What information must a controller give a data subject when collecting data
directly from them?
ANSWER: The controller must provide the identity and contact details of the
controller, the purposes of the processing, the legal basis for the processing, and
the period for which the personal data will be stored.

shortest sufficient answer: The controller must provide the identity and contact
details of the controller, the purposes of the processing, the legal basis for the
processing, and the period for which the personal data will be stored.

EXAMPLE 2

QUESTION: Who must appoint a data protection officer?
ANSWER: A data protection officer must be appointed by any public authority or body,
and by any controller whose core activities involve large-scale regular and systematic
monitoring of data subjects. Failure to designate one where it is required can attract
an administrative fine.

shortest sufficient answer: A data protection officer must be appointed by any public
authority or body, and by any controller whose core activities involve large-scale
regular and systematic monitoring of data subjects.

EXAMPLE 3

QUESTION: How long may a supervisory authority take to respond to a complaint?
ANSWER: The supervisory authority must inform the complainant of the progress of the
complaint within three months. If it does not respond within three months, the
complainant may seek a judicial remedy. A complaint may be lodged in the Member State
of the data subject's habitual residence.

shortest sufficient answer: The supervisory authority must inform the complainant of
the progress of the complaint within three months.

EXAMPLE 4

QUESTION: Does a data subject have to pay a fee to obtain a copy of their personal data?
ANSWER: No. The first copy of personal data must be provided free of charge. The
controller may charge a reasonable fee for any further copies requested.

shortest sufficient answer: No. The first copy of personal data must be provided
free of charge.

END OF EXAMPLES. Now do the same for the case below.

QUESTION:
{question}

ANSWER:
{answer}
"""


class _A1ShortestAnswer(BaseModel):
    """Structured-output shape for the A1 call."""

    shortest_sufficient_answer: str = Field(
        description="The shortest version of the answer that still fully answers "
                    "the question, in the answer's own wording. Empty if nothing "
                    "in the answer answers the question."
    )


def build_a1_prompt(question: str, answer: str) -> str:
    """
    Render the A1 prompt.

    Takes the two fields rather than a ``TestCase``: the quote is not a parameter
    of this stage at any point, which is a stronger guarantee than being handed
    the case and declining to interpolate it.
    """
    return A1_INSTRUCTIONS.format(question=question, answer=answer)


async def write_shortest_answer(
    question: str,
    answer: str,
    model_params: Dict[str, Any],
) -> StageResponse[str]:
    """
    A1 — the shortest version of ``answer`` that still fully answers ``question``.

    Returns:
        A :class:`StageResponse` carrying the shortest sufficient answer and what
        the call cost. The value is an empty string when nothing in the answer
        answers the question: a finding about the case — the gold answer does not
        answer its own question — and not an error.
    """
    llm = build_judge_llm(model_params, _A1ShortestAnswer)
    response = require_response(
        await llm.ainvoke(build_a1_prompt(question, answer)), stage="A1"
    )
    return StageResponse(
        value=response.value.shortest_sufficient_answer,
        cost=response.cost,
        calls=response.calls,
    )
"""
Stage A — split a case's gold answer into core and auxiliary claims.

Sees the question and the gold ``answer``. **Never the quote**, so the tagging
cannot be fitted to whatever the quote happens to contain — which is precisely
the failure that would erase the core-vs-auxiliary ruling this stage exists to
apply. The blinding is structural: :func:`build_stage_a_prompt` interpolates two
fields, and a prompt cannot leak what it was never given.
"""
from __future__ import annotations

from typing import Any, Dict, List, Literal

from pydantic import BaseModel, Field

from src.eval.dataset import TestCase
from src.eval.sufficiency.llm import build_judge_llm
from src.eval.sufficiency.models import Claim, Decomposition

# Tagging works by making the judge *write the shortest sufficient answer first*,
# then tag claims against it — rather than by scoring each claim on its own.
#
# The first attempt used a leave-one-out removal test ("delete this claim; does the
# rest still answer the question?") and it failed on `art7_case3`, the very case
# the criterion was settled on, returning **zero** core claims. Taken one claim at
# a time, "Yes." was excused because the substantive clause remained, and the
# substantive clause was excused because "Yes." remained. Leave-one-out cannot see
# mutual redundancy: it marks both members of a redundant pair removable, though
# removing both destroys the answer.
#
# Writing the shortest sufficient answer is also how the criterion was stated in
# the first place, and it keeps the judge performing the task rather than opining
# on it — the same reason stage B answers blind instead of rating.
#
# No worked example is included. The obvious one would be `art7_case3`, which is
# the case the criterion was settled on — putting it in the prompt would destroy
# its value as a check on whether the judge agrees with that ruling. A synthetic
# example is a fix for inconsistency that has not been observed yet, so it waits
# until the output asks for it.
STAGE_A_INSTRUCTIONS = """\
You are auditing an evaluation dataset for a GDPR question-answering system. Each
test case pairs a QUESTION with a reference ANSWER.

Work in two steps.

STEP 1 - Write the shortest version of the ANSWER that still fully answers the
QUESTION.

  - Use only wording that appears in the ANSWER. Add nothing of your own.
  - A bare "Yes" or "No" is not an answer on its own. Keep the substance it rests
    on.
  - If the QUESTION asks for a list or a set of items, a sufficient answer carries
    all of them.
  - If nothing in the ANSWER answers the QUESTION, leave this empty.

STEP 2 - Split the whole ANSWER into atomic claims and tag each one.

  - An atomic claim is a single assertion that could independently be true or
    false. Split conjunctions and separate obligations, but do not split so far
    that a fragment stops meaning anything on its own.
  - Keep a polarity marker ("Yes", "No") attached to the proposition it qualifies,
    rather than making it a claim of its own.
  - Keep the ANSWER's own wording, and never introduce information the ANSWER does
    not state.
  - Tag a claim CORE if its content appears in the shortest sufficient answer you
    wrote in STEP 1.
  - Tag it AUXILIARY otherwise. Auxiliary claims are relevant additions -
    elaboration, context, a consequence, a neighbouring rule - that make the
    answer fuller without being what was asked.

Judge against the QUESTION exactly as written. Do not consider what a more
thorough question might have asked, and do not consider where the ANSWER's
information came from.

QUESTION:
{question}

ANSWER:
{answer}
"""


class _StageAClaim(BaseModel):
    """Structured-output shape for one claim. Internal to the stage-A call."""

    text: str = Field(description="The claim, in the answer's own wording where possible.")
    tag: Literal["core", "auxiliary"] = Field(
        description="CORE if the claim's content appears in the shortest sufficient "
                    "answer; AUXILIARY if it does not."
    )
    reason: str = Field(
        description="One sentence saying whether the claim's content appears in the "
                    "shortest sufficient answer, and why."
    )


class _StageADecomposition(BaseModel):
    """Structured-output shape for the stage-A response."""

    shortest_sufficient_answer: str = Field(
        description="STEP 1 — the shortest version of the answer that still fully "
                    "answers the question, in the answer's own wording. Empty if "
                    "nothing in the answer answers the question."
    )
    claims: List[_StageAClaim] = Field(
        description="STEP 2 — every atomic claim in the answer, in the order it appears."
    )


def build_stage_a_prompt(case: TestCase) -> str:
    """
    Render the stage-A prompt for one case.

    Only the question and the gold answer are interpolated. The
    ``supporting_quote`` is withheld by construction, not by instruction — a
    prompt cannot leak what it was never given.
    """
    return STAGE_A_INSTRUCTIONS.format(question=case.question, answer=case.answer)


async def decompose(case: TestCase, model_params: Dict[str, Any]) -> Decomposition:
    """
    Stage A — split a case's gold answer into core and auxiliary claims.

    The quote is never shown, so the tagging cannot be fitted to whatever the
    quote happens to contain.

    Returns:
        A :class:`Decomposition`. ``core_claims`` may legitimately be empty: that
        says the gold answer does not answer its own question, which is a defect
        in the case rather than in the quote.
    """
    llm = build_judge_llm(model_params, _StageADecomposition)
    response: _StageADecomposition = await llm.ainvoke(build_stage_a_prompt(case))
    return Decomposition(
        shortest_sufficient_answer=response.shortest_sufficient_answer,
        claims=[Claim(text=c.text, tag=c.tag, reason=c.reason) for c in response.claims],
    )
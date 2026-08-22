"""
Stage A2 — split the gold answer into atomic claims and tag each core or
auxiliary.

Sees the question and the gold ``answer``. **Never the quote**, and never stage
A1's output: A1 and A2 are two independent derivations, not a pipeline. See
:mod:`src.eval.sufficiency.stage_a_twocall` for why that independence is the
point rather than an implementation detail.
"""
from __future__ import annotations

from typing import Any, Dict, List, Literal

from pydantic import BaseModel, Field

from src.eval.sufficiency.llm import build_judge_llm, require_response
from src.eval.sufficiency.models import Claim

# A2 states the criterion as a hypothetical — *consider* the shortest version that
# would answer the QUESTION — and returns only the claims.
#
# **It must not emit its own shortest answer.** If it did, the consistency check
# this split exists for would compare A1's text against A2's text and say nothing
# about the tags, which are the only thing stage C consumes. The comparison worth
# having is A1's shortest answer against A2's CORE claims: two independent
# derivations of the same quantity, disagreeing observably within a single run.
#
# The cost of that choice is that A2's intermediate reasoning is unobservable.
# `Claim.reason` is the only trace left, which makes this the third time that
# field has turned out to be load-bearing — design §4.3 kept it on the argument
# that a panel needs to know *which* member read the question correctly, and both
# 2026-08-17 divergences were diagnosed from it.
#
# **One rule is rewritten rather than moved.** STEP 2 said "Split the whole ANSWER
# however long your STEP 1 answer is", which names an object A2 no longer has.
# What it was defending is still live — `art15_case1`'s ten-item answer coming
# back as a single claim — so the defence is restated in terms A2 can act on: the
# core count follows from the ANSWER and the QUESTION, a question asking for a set
# makes every item core, and the whole ANSWER is never one claim.
#
# **The atomicity rule is deliberately absent.** Sentence-fragment claims (open
# item 1, drafted 2026-08-17) are a known residue of the current prompt, and
# fixing them here would mean two changes at once with no way to attribute either.
# Fragments are expected to survive this experiment.
A2_INSTRUCTIONS = """\
You are auditing an evaluation dataset for a GDPR question-answering system. Each
test case pairs a QUESTION with a reference ANSWER.

Split the whole ANSWER into atomic claims and tag each one CORE or AUXILIARY.

The test is this. Consider the shortest version of the ANSWER that would still
fully answer the QUESTION. A claim is CORE if its content appears in that shortest
version, and AUXILIARY if it does not. Do not write that shortest version out -
return the claims only.

  - An atomic claim is a single assertion that could independently be true or
    false. Split conjunctions and separate obligations, but do not split so far
    that a fragment stops meaning anything on its own.
  - How many claims come back CORE follows from the ANSWER and the QUESTION, not
    from habit. If the QUESTION asks for a list or a set of items, every item is
    CORE. If the ANSWER answers with a single assertion and then elaborates on it,
    one claim is CORE. Never return the whole ANSWER as a single claim.
  - Keep a polarity marker ("Yes", "No") attached to the proposition it qualifies.
    A claim consisting only of "Yes" or "No" is never correct output: the polarity
    and the substance it rests on are one claim, not two.
  - Keep the ANSWER's own wording, and never introduce information the ANSWER does
    not state.
  - Decide CORE by reading what the shortest sufficient answer would have to say,
    not by judging how important or how closely related a claim is.
  - Tag AUXILIARY otherwise, and "otherwise" is wider than it looks. A claim that
    the shortest sufficient answer merely implies, or that follows from it as a
    consequence, or that adds specificity it does not carry, is AUXILIARY. If your
    reason for calling a claim CORE would be that the shortest sufficient answer
    implies it, that claim is AUXILIARY. Auxiliary claims are relevant additions -
    elaboration, context, a consequence, a neighbouring rule - that make the
    answer fuller without being what was asked.

Judge against the QUESTION exactly as written. Do not consider what a more
thorough question might have asked, and do not consider where the ANSWER's
information came from.

Four worked examples follow. They are illustrations only. Their shapes differ on
purpose - they carry 4, 2, 1 and 1 CORE claims out of 4, 3, 3 and 2 claims in
total - and the shape of your own answer must follow the ANSWER you are actually
given, not any of these.

EXAMPLE 1

QUESTION: What information must a controller give a data subject when collecting data
directly from them?
ANSWER: The controller must provide the identity and contact details of the
controller, the purposes of the processing, the legal basis for the processing, and
the period for which the personal data will be stored.

claims:
  CORE - "The controller must provide the identity and contact details of the
  controller."
    reason: The question asks for a set of items, so the shortest sufficient answer
    carries all of them; this is one of them.
  CORE - "The controller must provide the purposes of the processing."
    reason: One of the items the question asks for.
  CORE - "The controller must provide the legal basis for the processing."
    reason: One of the items the question asks for.
  CORE - "The controller must provide the period for which the personal data will be
  stored."
    reason: One of the items the question asks for.

EXAMPLE 2

QUESTION: Who must appoint a data protection officer?
ANSWER: A data protection officer must be appointed by any public authority or body,
and by any controller whose core activities involve large-scale regular and systematic
monitoring of data subjects. Failure to designate one where it is required can attract
an administrative fine.

claims:
  CORE - "A data protection officer must be appointed by any public authority or body."
    reason: One of the two obligations the shortest sufficient answer states.
    Conjunctions are split into separate claims even when both parts are core.
  CORE - "A data protection officer must be appointed by any controller whose core
  activities involve large-scale regular and systematic monitoring of data subjects."
    reason: The second obligation the shortest sufficient answer states.
  AUXILIARY - "Failure to designate one where it is required can attract an
  administrative fine."
    reason: This follows from the rule as a consequence. A consequence is AUXILIARY
    even when closely related, because the shortest sufficient answer does not state it.

EXAMPLE 3

QUESTION: How long may a supervisory authority take to respond to a complaint?
ANSWER: The supervisory authority must inform the complainant of the progress of the
complaint within three months. If it does not respond within three months, the
complainant may seek a judicial remedy. A complaint may be lodged in the Member State
of the data subject's habitual residence.

claims:
  CORE - "The supervisory authority must inform the complainant of the progress of
  the complaint within three months."
    reason: Its content is what the shortest sufficient answer states.
  AUXILIARY - "If it does not respond within three months, the complainant may seek a
  judicial remedy."
    reason: This follows from the three-month rule as a consequence. A consequence is
    AUXILIARY even when it is closely related and repeats the same period, because
    the shortest sufficient answer does not state it.
  AUXILIARY - "A complaint may be lodged in the Member State of the data subject's
  habitual residence."
    reason: A neighbouring rule about where to complain, not about how long a
    response takes.

EXAMPLE 4

QUESTION: Does a data subject have to pay a fee to obtain a copy of their personal data?
ANSWER: No. The first copy of personal data must be provided free of charge. The
controller may charge a reasonable fee for any further copies requested.

claims:
  CORE - "No. The first copy of personal data must be provided free of charge."
    reason: It is what the shortest sufficient answer says. The polarity marker stays
    attached to the proposition it qualifies instead of being split off as a claim of
    its own.
  AUXILIARY - "The controller may charge a reasonable fee for any further copies
  requested."
    reason: It concerns further copies, which the question did not ask about.

END OF EXAMPLES. Now do the same for the case below.

QUESTION:
{question}

ANSWER:
{answer}
"""


class _A2Claim(BaseModel):
    """Structured-output shape for one claim. Internal to the A2 call."""

    text: str = Field(description="The claim, in the answer's own wording where possible.")
    tag: Literal["core", "auxiliary"] = Field(
        description="CORE if the claim's content would appear in the shortest "
                    "sufficient answer; AUXILIARY if it would not."
    )
    reason: str = Field(
        description="One sentence saying whether the claim's content would appear in "
                    "the shortest sufficient answer, and why."
    )


class _A2Claims(BaseModel):
    """Structured-output shape for the A2 response."""

    claims: List[_A2Claim] = Field(
        description="Every atomic claim in the answer, in the order it appears."
    )


def build_a2_prompt(question: str, answer: str) -> str:
    """
    Render the A2 prompt.

    Takes the two fields rather than a ``TestCase``: the quote is not a parameter
    of this stage at any point, which is a stronger guarantee than being handed
    the case and declining to interpolate it.
    """
    return A2_INSTRUCTIONS.format(question=question, answer=answer)


async def tag_claims(
    question: str,
    answer: str,
    model_params: Dict[str, Any],
) -> List[Claim]:
    """
    A2 — split ``answer`` into atomic claims and tag each core or auxiliary.

    Does not receive A1's output. The criterion is stated in the prompt and applied
    without writing the shortest sufficient answer down, so the core claims
    returned here are an independent derivation rather than a reading of A1's text.

    Returns:
        Every claim in the answer, in the order it appears. May legitimately
        contain no core claim: that says the gold answer does not answer its own
        question, which is a defect in the case rather than in the quote.
    """
    llm = build_judge_llm(model_params, _A2Claims)
    response = require_response(
        await llm.ainvoke(build_a2_prompt(question, answer)), stage="A2"
    )
    return [Claim(text=c.text, tag=c.tag, reason=c.reason) for c in response.claims]
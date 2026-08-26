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
from src.eval.sufficiency.llm import (
    StageResponse,
    build_judge_llm,
    llm_call,
)
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
#
# 2026-08-17: the output asked, and two rules were sharpened rather than an
# example added. Ten stage A runs across six cases produced two divergences, both
# of them breaches of a constraint already stated above, and in both the model's
# own `reason` field recorded the breach — which is what `Claim.reason` was kept
# for.
#
#   - `art8_case1`, four runs, 1 / 1 / 2 / 1 core claims. The run that differed
#     tagged "Children below that age cannot provide their own consent" CORE and
#     explained it as "IMPLIED BY the shortest sufficient answer but adds
#     specificity". The test is *appears in*, and that phrase does not appear in
#     "The minimum age is 16 years old." Stage C then labelled the extra claim
#     `absent`, which flips the case from sufficient to insufficient — so the
#     instability reaches the verdict, it does not stay inside stage A.
#   - `art7_case4`, two runs, 3 / 2 claims. One split "No." off as a claim of its
#     own, which the polarity rule already forbade.
#
# The CORE test now names implication, consequence and added specificity as
# AUXILIARY, and addresses the model's own reasoning directly: if the reason for
# calling a claim CORE would be that STEP 1 implies it, it is AUXILIARY. The
# polarity rule now says outright that a bare "Yes"/"No" claim is never correct
# output rather than only preferring the alternative.
#
# **The rule fix closed one failure and not the other.** Measured over 21 runs:
# `art8_case1` went 6/6 to one core claim with an identical core set and no
# implication-justified tagging, and `art15_case1` kept all ten enumeration items
# core — the regression the "adds specificity" wording risked. But `art7_case4`
# still split a bare "No." off in 2 of 6 runs. A constraint stated twice and
# broken a third of the time is not fixed by stating it a third time, so worked
# examples were added (Bertan, 2026-08-17).
#
# The examples are **synthetic on purpose.** Every one of the 433 cases is
# evidence, and the cases worth using as examples are exactly the diagnostic ones:
# `art7_case3` independently reproduced Bertan's ruling 3/3, and `art8_case1` and
# `art15_case1` are the cases whose stability is being measured. Showing the judge
# the answer for a case removes that case from the evidence, and a synthetic
# example costs nothing.
#
# Each example targets one observed failure or one thing at risk, and their shapes
# differ deliberately — 2 claims / 1 core, 3 claims / 1 core, 4 claims / 4 core —
# because few-shot teaches the shape as readily as the rule. A model shown three
# two-claim splits will produce two-claim splits.
#
#   1. An enumeration where every item is core, protecting the `art15_case1`
#      behaviour from the sharpened AUXILIARY wording.
#   2. A shortest sufficient answer spanning two claims, so conjunctions stay split
#      even when both halves are core — plus a consequence tagged AUXILIARY.
#   3. A consequence that repeats the same number as the core claim and is still
#      AUXILIARY. This is the `art8_case1` failure shape, generalised.
#   4. Polarity attached, and the reason says so in as many words. This is the
#      failure that survived two statements of the rule.
#
# **The first three-example set was a net regression, and how it failed is the
# reason there are four.** With examples carrying 1, 1 and 4 core claims in that
# order, `art7_case4`'s bare "No." went to 0/6 — but `art15_case1` collapsed from
# **10 core claims to 1**, on all three runs. Two of the three examples had a
# single core claim *and* a first claim that was verbatim the shortest sufficient
# answer, and the model generalised "claim 1 = STEP 1's text": correct when STEP 1
# is one sentence, catastrophic when it is a whole enumerated answer. Example 3
# contradicted it and was outvoted.
#
# Three things answer that, and all three are needed: the STEP 2 rule above that
# splitting does not depend on STEP 1's length; the ordering below, 4 / 2 / 1 / 1
# core claims, so the enumeration shape is seen first; and Example 2, whose first
# claim is deliberately *not* STEP 1's text. The lead-in also states the four
# shapes outright, because few-shot teaches shape as readily as rule and saying so
# costs nothing.
#
# The collapse matters more than the polarity win it bought, which is why it was
# not left standing: `art15_case1`'s ten claims are what produced the two useful
# `absent` findings — "confirmation of processing" missing from the quote, and
# "restriction/objection" cut off by the quote's own elision. One monolithic claim
# turns both into a single wholesale label.
#
# **The examples encode the criterion, so a wrong label here is a wrong label 433
# times.** They are the one part of this prompt that asserts what the right answer
# *is* rather than how to look for it, and they should be read as a claim needing
# Bertan's agreement rather than as scaffolding.
#
# **A prompt fix cannot remove run-to-run variance at temperature 0.** It narrows
# one failure mode. The panel and the reporting of non-unanimity are what make
# the residue visible instead of invisible.
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
  - Split the whole ANSWER however long your STEP 1 answer is. A shortest
    sufficient answer that states several things yields several CORE claims; one
    that states a single thing yields one. Never return the ANSWER as a single
    claim because STEP 1 was long.
  - Keep a polarity marker ("Yes", "No") attached to the proposition it qualifies.
    A claim consisting only of "Yes" or "No" is never correct output: the polarity
    and the substance it rests on are one claim, not two.
  - Keep the ANSWER's own wording, and never introduce information the ANSWER does
    not state.
  - Tag a claim CORE if its content appears in the shortest sufficient answer you
    wrote in STEP 1. Decide this by reading what STEP 1 says, not by judging how
    important or how closely related the claim is.
  - Tag it AUXILIARY otherwise, and "otherwise" is wider than it looks. A claim
    that STEP 1's text merely implies, or that follows from it as a consequence,
    or that adds specificity STEP 1 does not carry, is AUXILIARY. If your reason
    for calling a claim CORE would be that the shortest sufficient answer implies
    it, that claim is AUXILIARY. Auxiliary claims are relevant additions -
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

shortest sufficient answer: The controller must provide the identity and contact
details of the controller, the purposes of the processing, the legal basis for the
processing, and the period for which the personal data will be stored.
claims:
  CORE - "The controller must provide the identity and contact details of the
  controller."
    reason: The question asks for a set of items, so a sufficient answer carries all
    of them; this is one of them.
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

shortest sufficient answer: A data protection officer must be appointed by any public
authority or body, and by any controller whose core activities involve large-scale
regular and systematic monitoring of data subjects.
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

shortest sufficient answer: The supervisory authority must inform the complainant of
the progress of the complaint within three months.
claims:
  CORE - "The supervisory authority must inform the complainant of the progress of
  the complaint within three months."
    reason: Its content appears in the shortest sufficient answer.
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

shortest sufficient answer: No. The first copy of personal data must be provided
free of charge.
claims:
  CORE - "No. The first copy of personal data must be provided free of charge."
    reason: It is the shortest sufficient answer. The polarity marker stays attached
    to the proposition it qualifies instead of being split off as a claim of its own.
  AUXILIARY - "The controller may charge a reasonable fee for any further copies
  requested."
    reason: It concerns further copies, which the question did not ask about.

END OF EXAMPLES. Now do the same for the case below.

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


async def decompose(
    case: TestCase, model_params: Dict[str, Any]
) -> StageResponse[Decomposition]:
    """
    Stage A — split a case's gold answer into core and auxiliary claims.

    The quote is never shown, so the tagging cannot be fitted to whatever the
    quote happens to contain.

    Returns:
        A :class:`StageResponse` carrying a :class:`Decomposition` and what the
        call cost. ``core_claims`` may legitimately be empty: that says the gold
        answer does not answer its own question, which is a defect in the case
        rather than in the quote.
    """
    response = await llm_call(
        build_judge_llm(model_params, _StageADecomposition),
        build_stage_a_prompt(case),
        model_params=model_params,
        stage="A",
    )
    parsed = response.value
    return StageResponse(
        value=Decomposition(
            shortest_sufficient_answer=parsed.shortest_sufficient_answer,
            claims=[
                Claim(text=c.text, tag=c.tag, reason=c.reason) for c in parsed.claims
            ],
        ),
        cost=response.cost,
        calls=response.calls,
    )
"""
Stage C — decide which of stage A's claims the stage B answer carries.

Sees the question, stage A's core claims and stage B's blind answer. **Never the
quote.** That blinding is the one that makes stage B worth running: a stage C
able to re-read the evidence would substitute its own reading of the quote for
stage B's, and the two artifacts it is supposed to compare would collapse into
one. As in stages A and B the blinding is structural — :func:`build_stage_c_prompt`
interpolates the question, the claim texts and the answer text, and nothing else.

This stage produces **no verdict**. It labels claims and stops; turning those
labels into `sufficient` / `sufficient_verbose` / `insufficient` / `contradicted`
is verdict derivation, which is deterministic, needs no model call, and lives
apart from here.
"""
from __future__ import annotations

from typing import Any, Dict, List, Literal, Sequence

from pydantic import BaseModel, Field

from src.eval.sufficiency.llm import (
    StageResponse,
    build_judge_llm,
    require_response,
)
from src.eval.sufficiency.models import Adjudication, BlindAnswer, Claim, ClaimVerdict

# Four decisions are baked into the prompt below, each of which could have gone
# the other way. Recorded here rather than in the commit message, because the
# next person to edit the prompt is the person who needs them.
#
# 1. **Core claims only.** `Decomposition.core_claims` is filtered before the
#    prompt is built, so an auxiliary claim is never shown and never labelled.
#    The alternative — adjudicate everything and let verdict derivation ignore
#    the surplus — was rejected on evidence rather than on cost. Stage B is told
#    to answer "as fully as that text allows, and no further", so its answer is
#    scoped to the question; an auxiliary claim is by definition not what the
#    question asked, so it comes back ABSENT almost by construction. On
#    `art8_case1` stage B answered "16 years old", against which both auxiliary
#    claims are trivially absent. That measures how far the gold answer runs past
#    the *question*, which stage A already recorded when it tagged them — not how
#    far it runs past its *evidence*, which is the quantity worth having and
#    which no stage blind to the quote can produce.
#
# 2. **The answer alone, not the note.** `BlindAnswer` carries four fields; only
#    `answer` is interpolated. The `note` is stage B's self-assessment, and
#    adjudicating against it would judge what stage B *thought* rather than what
#    it *answered*. The cost is real and is recorded so it is not rediscovered as
#    a surprise: on `art8_case1` the answer is "16 years old" while the note adds
#    "for their own consent to be lawful", so a fully-phrased core claim can read
#    ABSENT off stage B's brevity rather than off the quote's content. If that
#    shows up at scale the fix belongs in stage B's step 2 wording, not in
#    feeding this stage a second artifact.
#
# 3. **The regulation is never named**, exactly as in stage B. This stage judges
#    text against text and needs no legal knowledge whatsoever, so naming the law
#    could only invite the model to supply what the answer does not say. The
#    prompt therefore also states outright that a true-but-unstated claim is
#    ABSENT — the single failure mode that would make this stage worthless.
#
# 4. **Claims are numbered and the mapping is validated.** Pairing verdicts to
#    claims by position looks simpler and is unsafe: a model that returns two
#    verdicts for three claims silently mislabels the third rather than failing.
#    Numbering makes a dropped, duplicated or invented claim detectable, and
#    :class:`AdjudicationError` reports which — an eval instrument should fail
#    loudly rather than return a plausible wrong answer.
STAGE_C_INSTRUCTIONS = """\
You are checking whether an ANSWER carries the content of each of several CLAIMS.

The ANSWER was written from a single short source and may well be incomplete.
That is expected, and detecting it is the point of this task. You are not being
asked whether a claim is true, and you are not being asked to improve or complete
the ANSWER. Judge only what the ANSWER states.

The QUESTION is given so you can read the CLAIMS and the ANSWER in context. Do
not answer it yourself.

For each CLAIM, choose exactly one label.

  SUPPORTED - the ANSWER states the claim's content. The wording does not have to
    match; what matters is that someone reading only the ANSWER would learn what
    the claim asserts.
  ABSENT - the ANSWER does not state the claim's content. A claim that is true,
    or well known, or an obvious consequence of the subject matter, but is not
    stated in the ANSWER, is ABSENT. Supplying it yourself is the specific failure
    this task exists to detect.
  CONTRADICTED - the ANSWER states something that cannot hold at the same time as
    the claim. Silence is never a contradiction; an unaddressed claim is ABSENT.

Label every CLAIM exactly once, using the number it was given. Give a one-sentence
rationale for each, saying what in the ANSWER decided it.

QUESTION:
{question}

ANSWER:
{answer}

CLAIMS:
{claims}
"""


class AdjudicationError(ValueError):
    """
    The model did not return exactly one verdict per claim.

    Raised rather than repaired. A missing, duplicated or invented claim number
    means the adjudication cannot be matched to what was asked about, and an
    instrument that guesses at the mapping produces a plausible wrong answer
    instead of a failure someone can see.
    """


class _StageCClaimVerdict(BaseModel):
    """Structured-output shape for one claim's label. Internal to the stage-C call."""

    claim_number: int = Field(
        description="The number of the CLAIM this labels, exactly as it was given."
    )
    support: Literal["supported", "contradicted", "absent"] = Field(
        description="SUPPORTED if the answer states the claim's content, ABSENT if it "
                    "does not, CONTRADICTED if the answer states something that cannot "
                    "hold at the same time as the claim."
    )
    rationale: str = Field(
        description="One sentence saying what in the answer decided the label."
    )


class _StageCAdjudication(BaseModel):
    """Structured-output shape for the stage-C response."""

    claim_verdicts: List[_StageCClaimVerdict] = Field(
        description="One entry per CLAIM, in the order the claims were given."
    )


def render_claims(claims: Sequence[Claim]) -> str:
    """
    Number the claims for the prompt, one per line, from 1.

    The numbering is what the response is matched on, so it is produced here and
    read back in :func:`adjudicate` rather than being assumed at either end. Tags
    are deliberately not rendered: every claim shown to this stage is core, so a
    tag would carry no information and could only invite the model to treat one
    claim as lower-stakes than another.
    """
    return "\n".join(f"{i}. {claim.text}" for i, claim in enumerate(claims, start=1))


def build_stage_c_prompt(
    question: str,
    claims: Sequence[Claim],
    blind_answer: BlindAnswer,
) -> str:
    """
    Render the stage-C prompt.

    Only the question, the claim texts and ``blind_answer.answer`` are
    interpolated. The quote is not a parameter of this function at all, which is
    a stronger guarantee than withholding it: this stage cannot leak evidence it
    was never able to reach.
    """
    return STAGE_C_INSTRUCTIONS.format(
        question=question,
        answer=blind_answer.answer,
        claims=render_claims(claims),
    )


def _verdicts_by_claim_number(
    response: _StageCAdjudication,
    claim_count: int,
) -> Dict[int, _StageCClaimVerdict]:
    """
    Index the response by claim number, refusing anything that does not line up.

    Three failures are separated because they mean different things: a number
    outside the range means the model invented a claim, a repeat means it labelled
    one twice, and a gap means it dropped one.
    """
    expected = set(range(1, claim_count + 1))
    by_number: Dict[int, _StageCClaimVerdict] = {}

    for verdict in response.claim_verdicts:
        if verdict.claim_number not in expected:
            raise AdjudicationError(
                f"verdict for claim {verdict.claim_number}, but only "
                f"{claim_count} claim(s) were given"
            )
        if verdict.claim_number in by_number:
            raise AdjudicationError(f"claim {verdict.claim_number} was labelled more than once")
        by_number[verdict.claim_number] = verdict

    missing = sorted(expected - by_number.keys())
    if missing:
        raise AdjudicationError(f"no verdict for claim(s) {missing}")

    return by_number


def _nothing_to_carry(claims: Sequence[Claim]) -> Adjudication:
    """
    Label every claim ``absent`` without a model call.

    Used when stage B produced no answer text. Nothing can carry a claim, so this
    is arithmetic rather than judgement, and asking a model to confirm it would
    cost a call and invite it to fill the silence from what it knows.
    """
    return Adjudication(
        claim_verdicts=[
            ClaimVerdict(
                claim=claim,
                support="absent",
                rationale="Stage B produced no answer, so there is nothing that could carry this claim.",
            )
            for claim in claims
        ]
    )


async def adjudicate(
    question: str,
    claims: Sequence[Claim],
    blind_answer: BlindAnswer,
    model_params: Dict[str, Any],
) -> StageResponse[Adjudication]:
    """
    Stage C — label each claim against the blind answer.

    Args:
        question:     The case's question, as context for reading both artifacts.
        claims:       The claims to label — **core claims only**; the caller
                      filters, so this stage is never told a claim's tag.
        blind_answer: Stage B's output. Only its ``answer`` reaches the prompt.
        model_params: One entry from :func:`src.llm_config.get_llm_config`.

    Returns:
        A :class:`StageResponse` carrying an :class:`Adjudication` with one
        :class:`ClaimVerdict` per claim, in the order the claims were given, and
        what the call cost.

    Two inputs are handled without a model call, and neither is an error. Both
    report a cost of **0.0 rather than None**: no call was made, so the price is
    known and it is nothing. ``None`` is reserved for a call that happened and
    came back unpriced, which is money spent that cannot be accounted for.

    - **No claims.** Stage A legitimately returns an empty ``core_claims`` when a
      gold answer does not answer its own question. That is a defect in the case
      rather than in the quote, and there is nothing here to adjudicate.
    - **No answer text.** Stage B's insufficiency escape leaves ``answer`` empty,
      and an empty answer carries nothing. Note the guard is on the text and not
      on ``answered``: a model that sets the flag false while still writing an
      answer has produced something to judge, and it gets judged.

    Raises:
        AdjudicationError: if the response does not carry exactly one verdict per
            claim. See :func:`_verdicts_by_claim_number`.
    """
    # `calls=()` is the companion of `cost=0.0` on both no-call paths: no call
    # was made, so there is no record to keep. An empty tuple says that, where a
    # single record of Nones would claim a call happened and reported nothing
    # about itself.
    if not claims:
        return StageResponse(
            value=Adjudication(claim_verdicts=[]), cost=0.0, calls=()
        )
    if not blind_answer.answer.strip():
        return StageResponse(
            value=_nothing_to_carry(claims), cost=0.0, calls=()
        )

    llm = build_judge_llm(model_params, _StageCAdjudication)
    response = require_response(
        await llm.ainvoke(build_stage_c_prompt(question, claims, blind_answer)),
        stage="C",
    )
    by_number = _verdicts_by_claim_number(response.value, len(claims))

    return StageResponse(
        value=Adjudication(
            claim_verdicts=[
                ClaimVerdict(
                    claim=claim,
                    support=by_number[i].support,
                    rationale=by_number[i].rationale,
                )
                for i, claim in enumerate(claims, start=1)
            ]
        ),
        cost=response.cost,
        calls=response.calls,
    )
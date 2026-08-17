"""
Stage B — answer a case's question from its ``supporting_quote`` alone.

Sees the question and the quote. **Never the gold answer and never the source
article**, so the judge cannot work backwards from the conclusion it is meant to
be testing. As in stage A the blinding is structural, not instructed:
:func:`build_stage_b_prompt` interpolates two fields and nothing else.

Asking the judge to *perform* the task rather than opine on it is what stops it
rationalising a verdict it has already been shown.
"""
from __future__ import annotations

from typing import Any, Dict

from pydantic import BaseModel, Field

from src.eval.dataset import TestCase
from src.eval.golden_qa import normalize_for_grounding
from src.eval.sufficiency.llm import build_judge_llm
from src.eval.sufficiency.models import BlindAnswer

# Two structural defences against the judge answering from what it knows rather
# than from what it was given, which would make every verdict here worthless:
#
#   1. The regulation is never named. The prompt says "EXCERPT of legal text", not
#      "GDPR article". A capable model will often recognise it anyway, so this is
#      a reduction in prior activation rather than a guarantee — which is why the
#      instructions also state outright that answering from prior knowledge is the
#      failure being tested.
#   2. The span is copied *before* the answer is written. Producing the answer
#      first and the evidence second invites the model to find a span that fits an
#      answer it has already committed to; producing the span first means there is
#      nothing to answer from until it has found text. `art2_case4` is the case
#      this is built for: its quote lists law-enforcement purposes but contains no
#      negation, and any model that knows Article 2(2)(d) can supply the "No" the
#      quote does not.
#
# `minimal_span` is required to be a single continuous run, not a list of spans.
# That is conservative: where an answer genuinely needs disjoint pieces, the
# shortest continuous run covering them is the whole stretch between them, so the
# span looks longer and fewer cases are flagged verbose. Multi-span evidence is a
# pending schema decision for `supporting_quote` itself; this stage should follow
# that decision rather than pre-empt it.
STAGE_B_INSTRUCTIONS = """\
You are given a QUESTION and an EXCERPT of legal text. Answer the QUESTION using
the EXCERPT and nothing else.

The EXCERPT is the whole of what you are allowed to know. You may recognise the
law it is taken from and believe you know the answer from elsewhere. Do not use
that. Answering from what you already know, rather than from what the EXCERPT
says, is the specific failure this task exists to detect - an answer that is
correct in law but absent from the EXCERPT is a wrong answer here.

Work in this order.

STEP 1 - Find the shortest continuous run of text in the EXCERPT that carries the
answer, and copy it out exactly, character for character. Do not paraphrase it, do
not stitch together separate parts of the EXCERPT, and do not repair its spelling
or punctuation. If no run of text in the EXCERPT carries the answer, leave this
empty.

STEP 2 - Answer the QUESTION from the text you copied in STEP 1. Answer as fully
as that text allows, and no further.

STEP 3 - State whether the EXCERPT answered the QUESTION.

  - Answered is true only if STEP 1 found text that carries the answer.
  - Answered is false if the EXCERPT concerns the right subject but does not
    settle the question, and false if it concerns something else entirely. Say
    which of the two in the note.

QUESTION:
{question}

EXCERPT:
{quote}
"""


class _StageBAnswer(BaseModel):
    """Structured-output shape for the stage-B response."""

    minimal_span: str = Field(
        description="STEP 1 — the shortest continuous run of the excerpt that carries "
                    "the answer, copied verbatim. Empty if the excerpt has none."
    )
    answer: str = Field(
        description="STEP 2 — the answer to the question, derived only from the span "
                    "above. Empty if there is no span."
    )
    answered: bool = Field(
        description="STEP 3 — true only if the excerpt carries the answer."
    )
    note: str = Field(
        description="If answered is false, what the excerpt is missing and whether it "
                    "concerns the right subject at all. If true, one sentence on what "
                    "the span establishes."
    )


def build_stage_b_prompt(case: TestCase) -> str:
    """
    Render the stage-B prompt for one case.

    Only the question and the quote are interpolated — never the gold answer and
    never the source article. As in stage A, the blinding is structural: a prompt
    cannot leak what it was never given.
    """
    return STAGE_B_INSTRUCTIONS.format(question=case.question, quote=case.supporting_quote)


def span_is_verbatim(span: str, quote: str) -> bool:
    """
    Whether a returned ``minimal_span`` really is a run of the quote.

    A deterministic check on the judge's own output: stage B is told to copy, and
    a span it paraphrased instead is not a repair candidate. Matching reuses
    :func:`normalize_for_grounding` rather than reimplementing it, so this stage
    and the grounding gate cannot drift apart on what "the same text" means.
    """
    if not span.strip():
        return False
    if span in quote:
        return True
    return normalize_for_grounding(span) in normalize_for_grounding(quote)


async def answer_blind(case: TestCase, model_params: Dict[str, Any]) -> BlindAnswer:
    """
    Stage B — answer a case's question from its ``supporting_quote`` alone.

    Neither the gold answer nor the source article is shown, so the judge cannot
    work backwards from the conclusion it is meant to be testing.

    Returns:
        A :class:`BlindAnswer`. ``answered`` False is the insufficiency escape and
        a legitimate outcome, not an error.
    """
    llm = build_judge_llm(model_params, _StageBAnswer)
    response = await llm.ainvoke(build_stage_b_prompt(case))
    return BlindAnswer(
        answered=response.answered,
        answer=response.answer,
        minimal_span=response.minimal_span,
        note=response.note,
    )
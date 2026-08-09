"""
Answer-vs-quote sufficiency — the judge-tier gate on the golden set (plan §7.3).

:mod:`golden_qa` checks **provenance**: that a ``supporting_quote`` is a substring
of its source article. This module checks **sufficiency**: that the quote actually
answers its question. The two properties are uncorrelated. ``art2_case4`` grounds
*exact* and clears every deterministic gate, yet its quote is a verbatim fragment
of Article 2 that never contains the negation its answer asserts — perfect
provenance, zero sufficiency.

Sufficiency is semantic, so it is judged, not measured. That is why it lives here
rather than in :mod:`golden_qa`, which stays free, deterministic and runnable on
every change.

The criterion
-------------
**Every question must be answerable using only its ``supporting_quote``.**

Deliberately the weaker of the two candidate readings — *not* "the gold ``answer``
is entailed by the quote". The deciding case is ``art7_case3``, whose two-sentence
answer is covered by its quote only in the first sentence. The shortest sufficient
answer is *"Yes, the data subject shall have the right to withdraw their consent at
any time"*; the second sentence — that withdrawal does not affect the lawfulness of
prior processing — is auxiliary information which strengthens the statement rather
than a claim the quote must carry. (It is also, verbatim, the ``supporting_quote``
of ``art7_case4``: article-supported, just not quote-supported.)

That is not one case bending the rule. **175 of 433** cases carry at least one gold
answer sentence poorly covered by their quote, so the stronger reading would make
roughly 40% of the set a candidate failure. Distinguishing *core* from *auxiliary*
claims is therefore the load-bearing part of this module, not a refinement of it.

Sufficiency is two-sided. A quote that cannot answer its question is **useless**; a
quote carrying far more than the question needs is **not useless but devalued**.
Stage B returns the minimal sufficient span so the same pass yields the repair and
not merely the diagnosis.

Protocol — three stages, each blinded to what would let it rationalize
---------------------------------------------------------------------
A. **Decompose** — sees the question and the gold ``answer``, *not* the quote.
   Splits the answer into atomic claims, tagging each ``core`` or ``auxiliary``.
   Blind to the quote so the tagging cannot be fitted to whatever the quote happens
   to contain, which is precisely the failure that would erase the ruling above.

B. **Answer blind** — sees the question and the ``supporting_quote`` *only*: no
   article, no gold answer. Answers from the quote alone, with an explicit
   insufficiency escape, and returns the minimal span carrying that answer. Asking
   the judge to *perform* the task rather than opine on it is what stops it
   rationalizing a verdict it has already been shown.

C. **Adjudicate** — sees the question, the tagged claims and the blind answer, *not*
   the quote. Marks each core claim supported / contradicted / absent.

Each panel member runs A→B→C independently and votes, so disagreement is a
calibration signal rather than noise to be averaged away (§6.2: panel with
majority/consensus for high-stakes gates, and mandatory human calibration before a
judge is trusted as a gate at all).

Known limits, recorded so a result is not read as coverage it does not have:

- Stage B is blind to the article, so it can report that *this quote* fails to
  answer the question but never that *nothing in the article could*. Invalid cases
  (``art41_case3``, whose article contains no accreditation period; ``art8_case5``,
  which quotes Recital 38) surface as insufficient and must be triaged against the
  source PDF. Writing them a quote would launder an unanswerable question into a
  clean-looking case.
- Judge–human agreement is unmeasured until the calibration step exists. Until then
  no verdict here gates anything.
"""
from __future__ import annotations

import asyncio, re, sys
from dataclasses import dataclass
from typing import Any, Dict, List, Literal, TypeVar, cast

from ai_common import get_llm
from langchain_core.language_models import LanguageModelInput
from langchain_core.runnables import Runnable
from pydantic import BaseModel, Field

from src.eval.dataset import load_tier1, TestCase
from src.eval.golden_qa import normalize_for_grounding
from src.llm_config import get_llm_config

# The structured-output shape a judge stage returns. Each stage has its own.
_SchemaT = TypeVar("_SchemaT", bound=BaseModel)

# Whether a claim in the gold answer must be carried by the quote. Only `core`
# claims bear on the verdict; `auxiliary` ones may elaborate or strengthen the
# answer beyond what the quote supports, which the criterion above permits.
ClaimTag = Literal["core", "auxiliary"]

# How a single claim fared against the blind answer. `absent` and `contradicted`
# are kept apart because they call for different repairs: absent evidence means
# the span was cut too short, whereas a contradiction means it points the wrong
# way (the `art2_case4` shape) and the case needs re-reading, not extending.
ClaimSupport = Literal["supported", "contradicted", "absent"]

# The per-case outcome.
#
#   sufficient          the quote answers the question
#   sufficient_verbose  it answers, but the minimal span is far shorter than the
#                       quote — the "devalued" side of the criterion
#   insufficient        the quote cannot answer the question
#   contradicted        the blind answer contradicts a core claim
#
# `contradicted` is deliberately not folded into `insufficient`: evidence that
# points away from the answer is a worse defect than evidence that is merely
# missing, and it implicates the answer as well as the quote.
Verdict = Literal["sufficient", "sufficient_verbose", "insufficient", "contradicted"]


@dataclass(frozen=True)
class Claim:
    """
    One atomic assertion extracted from a gold answer (stage A).

    ``reason`` records why the tag was chosen. It is not decoration: when two
    panel members tag the same claim differently, it is the only thing that says
    which of them read the question correctly (§6.2 — decomposed verdicts carry a
    rationale).
    """

    text: str
    tag: ClaimTag
    reason: str


@dataclass(frozen=True)
class Decomposition:
    """
    Stage A output — the gold answer split into tagged claims.

    ``shortest_sufficient_answer`` is what the tagging was done against, so it is
    kept rather than discarded: it is the auditable trace of *why* a claim came
    out core, and the thing a human calibrator reads first. Empty when the judge
    found nothing in the answer that answers the question, which makes
    ``core_claims`` empty too — a defect in the case, not in the quote.
    """

    shortest_sufficient_answer: str
    claims: List[Claim]

    @property
    def core_claims(self) -> List[Claim]:
        """The claims the quote is required to carry."""
        return [c for c in self.claims if c.tag == "core"]


@dataclass(frozen=True)
class BlindAnswer:
    """
    Stage B output — the question answered from the quote alone.

    ``answered`` is False when the judge took the insufficiency escape; ``answer``
    and ``minimal_span`` are then empty and ``note`` carries what was missing.
    ``minimal_span`` is a substring of the quote, not a paraphrase of it — it is
    the repair candidate.
    """

    answered: bool
    answer: str
    minimal_span: str
    note: str


@dataclass(frozen=True)
class ClaimVerdict:
    """How one claim fared against the blind answer (stage C)."""

    claim: Claim
    support: ClaimSupport
    rationale: str


@dataclass(frozen=True)
class Adjudication:
    """Stage C output — a support decision per claim, with its reasoning."""

    claim_verdicts: List[ClaimVerdict]


@dataclass(frozen=True)
class PanelistRun:
    """One panel member's full A→B→C chain over one case, and its verdict."""

    case_id: str
    model: str
    decomposition: Decomposition
    blind_answer: BlindAnswer
    adjudication: Adjudication
    verdict: Verdict


@dataclass(frozen=True)
class CaseJudgement:
    """The panel's aggregate outcome for one case."""

    case_id: str
    runs: List[PanelistRun]
    verdict: Verdict

    @property
    def unanimous(self) -> bool:
        """Whether every panel member reached the aggregate verdict."""
        return all(run.verdict == self.verdict for run in self.runs)


# --------------------------------------------------------------------------- #
#  Stage A — decompose the gold answer into tagged claims                      #
# --------------------------------------------------------------------------- #

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


def build_judge_llm(
    model_params: Dict[str, Any],
    schema: type[_SchemaT],
) -> Runnable[LanguageModelInput, _SchemaT]:
    """
    Build a structured-output LLM for one judge stage.

    Args:
        model_params: One entry from :func:`src.llm_config.get_llm_config`.
        schema:       The pydantic shape the stage must return.

    Returns:
        A runnable that yields an instance of ``schema``.

    ``with_structured_output`` is declared as returning ``dict | BaseModel``,
    because it accepts both a dict schema and a pydantic class. Passing a pydantic
    class narrows that at runtime but not in the type system, so the cast is made
    once here rather than at each of the three stage call sites.
    """
    llm = get_llm(
        model_name=model_params["model"],
        model_provider=model_params["model_provider"],
        api_key=model_params["api_key"],
        model_args=model_params["model_args"],
    )
    return cast(
        "Runnable[LanguageModelInput, _SchemaT]",
        llm.with_structured_output(schema=schema),
    )


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


# --------------------------------------------------------------------------- #
#  Stage B — answer the question from the quote alone                          #
# --------------------------------------------------------------------------- #

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


async def main():
    wanted = [
        "gdpr_art7_case3",   # the case the criterion was settled on
        "gdpr_art2_case4",   # grounds exact, quote carries no negation
        "gdpr_art33_case1",  # core timing rule + auxiliary consequence
        "gdpr_art15_case1",  # enumeration question: every item is core
        "gdpr_art8_case1",   # key-phrase screen flags it; quote answers it
        "gdpr_art41_case3",  # invalid case — the article has no such content
        "gdpr_art8_case5",   # quote is from Recital 38, not the article
        "gdpr_art7_case4",   # carries art7_case3's auxiliary clause as its own quote
    ]

    cases = {c.case_id: c for c in load_tier1()}
    picked = [cases[c] for c in wanted if c in cases]

    model_params = get_llm_config()["writer_model"][0]
    print(f"model: {model_params['model']}\n")

    decompositions, blind_answers = await asyncio.gather(
        asyncio.gather(*[decompose(c, model_params) for c in picked]),
        asyncio.gather(*[answer_blind(c, model_params) for c in picked]),
    )

    for case, dec, blind in zip(picked, decompositions, blind_answers):
        print("=" * 78)
        print(f"{case.case_id}  [{case.answer_type}]")
        print(f"Q: {case.question}")
        print(f"A: {case.answer}")
        print(f"quote: {case.supporting_quote}")

        print(f"\n-- stage A: {len(dec.core_claims)} core / {len(dec.claims)} claims")
        print(f"   shortest sufficient answer: {dec.shortest_sufficient_answer}")
        for c in dec.claims:
            print(f"   [{c.tag:9}] {c.text}")
            print(f"               ({c.reason})")

        verbatim = span_is_verbatim(blind.minimal_span, case.supporting_quote)
        shrink = (
            f"{len(blind.minimal_span)}/{len(case.supporting_quote)} chars"
            if blind.minimal_span else "no span"
        )
        print(f"\n-- stage B: answered={blind.answered}  span verbatim={verbatim}  {shrink}")
        print(f"   span:   {blind.minimal_span}")
        print(f"   answer: {blind.answer}")
        print(f"   note:   {blind.note}")
        print()


if __name__ == "__main__":
    asyncio.run(main())

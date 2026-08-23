"""
Unit tests for stages A, B and C of the sufficiency judge.

Stages A and B were built on 2026-08-05 and verified by eyeballing eight cases,
which under this project's own rule leaves them unverified rather than working —
``span_is_verbatim`` in particular returned 8/8 verbatim and has therefore never
been observed to fail. These tests pin what is deterministic in the three stages:
the **structural blinding** that the whole protocol rests on, the mapping from a
model response into the stage's dataclass, ``span_is_verbatim``, and stage C's
claim-to-verdict matching.

The blinding is the load-bearing part. Stage A must never see the quote, or its
core/auxiliary tagging can be fitted to whatever the quote happens to contain;
stage B must never see the gold answer, or it can work backwards from the
conclusion it exists to test; stage C must never see the quote, or it re-reads
the evidence and the two artifacts it exists to compare collapse into one. Each
is a claim about what a prompt *cannot* contain, so they are tested as invariance
properties — two inputs differing in every field but the ones a stage is allowed
to see must produce byte-identical prompts — rather than by checking one sentinel
string, which a later field added to a prompt would slip straight past.

No model is called. Each stage's runnable is replaced with a fake, so what is
tested is the stage's own wiring: which prompt it sends, which schema it asks
for, how it maps what comes back, and — for stage C — when it declines to call
at all.
"""
import asyncio
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest

from src.eval.dataset import TestCase
from src.eval.sufficiency.models import BlindAnswer, Claim, Decomposition
from src.eval.sufficiency.stage_a import build_stage_a_prompt, decompose
from src.eval.sufficiency.stage_b import (
    answer_blind,
    build_stage_b_prompt,
    span_is_verbatim,
)
from src.eval.sufficiency.stage_c import (
    AdjudicationError,
    adjudicate,
    build_stage_c_prompt,
    render_claims,
)
from src.eval.sufficiency.llm import JudgeResponseError, sum_costs
from src.eval.sufficiency.stage_a1 import write_shortest_answer
from src.eval.sufficiency.stage_a2 import tag_claims
from src.eval.sufficiency.stage_a_twocall import decompose as decompose_twocall
from src.eval.sufficiency import stage_a as stage_a_module
from src.eval.sufficiency import stage_a1 as stage_a1_module
from src.eval.sufficiency import stage_a2 as stage_a2_module
from src.eval.sufficiency import stage_b as stage_b_module
from src.eval.sufficiency import stage_c as stage_c_module


# The fixtures follow `gdpr_art7_case3` — the case the criterion was settled on,
# whose gold answer carries one core claim and one auxiliary one.
QUESTION = "Can a data subject withdraw their consent after they have already given it?"
ANSWER = (
    "Yes. The data subject shall have the right to withdraw their consent at any time. "
    "The withdrawal shall not affect the lawfulness of processing based on consent "
    "before its withdrawal."
)
QUOTE = "The data subject shall have the right to withdraw his or her consent at any time."

# Distinctive fragments used to assert a field did *not* reach a prompt. Each is
# a phrase that appears in exactly one of the fields above, so a partially
# interpolated prompt fails as loudly as a fully interpolated one.
ANSWER_ONLY_PHRASE = "shall not affect the lawfulness"
QUOTE_ONLY_PHRASE = "his or her consent"

# tests/ -> <repo root>. The import-cost guard below runs a fresh interpreter
# from here, so `import src...` resolves the same way pytest's `pythonpath`
# setting makes it resolve in-process.
REPO_ROOT = Path(__file__).resolve().parents[1]

MODEL_PARAMS = {
    "model": "a-model",
    "model_provider": "a-provider",
    "api_key": "not-a-real-key",
    "model_args": {"temperature": 0.0},
}


def make_case(**overrides) -> TestCase:
    base = dict(
        case_id="gdpr_art7_case3",
        article_number="7",
        article_title="Conditions for consent",
        question=QUESTION,
        answer=ANSWER,
        answer_type="conditional",
        supporting_quote=QUOTE,
        key_phrases=["withdraw consent", "at any time"],
    )
    base.update(overrides)
    return TestCase(**base)


# The price a faked call reports. A literal, not a constant imported from the
# code under test: a stage that dropped the cost on the floor and returned 0.0
# would agree with a shared constant of 0.0 and fail against this.
FAKE_COST = 0.000123


class _FakeJudgeLLM:
    """Stands in for the structured-output runnable a stage builds."""

    def __init__(self, payload):
        self.payload = payload
        self.prompts = []

    async def ainvoke(self, prompt):
        self.prompts.append(prompt)
        return self.payload


def make_payload(parsed, *, cost=FAKE_COST, content="", parsing_error=None):
    """
    The dict ``with_structured_output(..., include_raw=True)`` hands back.

    Built here from literals rather than by calling anything in ``llm.py``,
    because a stage is only correct if it reads the shape the *provider* sends;
    a helper shared with the code under test would agree with whatever that code
    happened to do. ``response_metadata`` carries ``cost`` the way OpenRouter
    sends it — observed 2026-08-23 alongside ``cost_details`` and the usual
    ``model_name``/``finish_reason`` keys.
    """
    raw = SimpleNamespace(
        content=content,
        response_metadata={} if cost is None else {"cost": cost},
    )
    return {"raw": raw, "parsed": parsed, "parsing_error": parsing_error}


def install_fake_llm(monkeypatch, module, response, *, cost=FAKE_COST):
    """
    Replace a stage's ``build_judge_llm`` with one returning a fake runnable.

    ``response`` is the *parsed* object — what the stage would have got before
    ``include_raw``. It is wrapped in a payload here so that the twenty-odd
    tests written against the old contract keep saying what they said, and the
    payload shape is stated in exactly one place.

    Returns the fake — which records every prompt it was invoked with — and a
    dict capturing the arguments the stage passed to the builder.
    """
    return install_fake_payload(
        monkeypatch, module, make_payload(response, cost=cost)
    )


def install_fake_payload(monkeypatch, module, payload):
    """
    As :func:`install_fake_llm`, but for a payload built by the caller.

    Used by the transport-failure tests, which need shapes no parsed response
    can express: no payload at all, and a payload whose ``parsed`` is None.
    """
    fake = _FakeJudgeLLM(payload)
    captured = {}

    def build(model_params, schema):
        captured["model_params"] = model_params
        captured["schema"] = schema
        return fake

    monkeypatch.setattr(module, "build_judge_llm", build)
    return fake, captured


# ---------------------------- stage A — the prompt -------------------------- #

def test_stage_a_prompt_carries_the_question_and_the_answer_under_their_own_labels():
    """
    Presence is not enough: a prompt built with the two fields swapped still
    contains both. The label positions are what pin which is which.

    ``rindex`` rather than ``index``, because the worked examples added on
    2026-08-17 carry their own ``QUESTION:``/``ANSWER:`` lines. Against ``index``
    this test would compare the real fields to the *examples'* labels and pass
    however the real ones were ordered.
    """
    prompt = build_stage_a_prompt(make_case())

    assert prompt.rindex("QUESTION:") < prompt.rindex(QUESTION)
    assert prompt.rindex(QUESTION) < prompt.rindex("ANSWER:")
    assert prompt.rindex("ANSWER:") < prompt.rindex(ANSWER)


def test_stage_a_prompt_never_carries_the_quote():
    """The blinding stage A's core/auxiliary tagging depends on."""
    prompt = build_stage_a_prompt(make_case())

    assert QUOTE not in prompt
    assert QUOTE_ONLY_PHRASE not in prompt


def test_stage_a_prompt_is_blind_to_everything_but_the_question_and_the_answer():
    """
    The invariance form of the claim above. Two cases agreeing only on question
    and answer must render identically, so a field added to the prompt later
    fails here even if nobody thinks to write a test for that field.
    """
    one = make_case()
    other = make_case(
        case_id="gdpr_art99_case7",
        article_number="99",
        article_title="Entry into force and application",
        answer_type="timeline",
        supporting_quote="This Regulation shall be binding in its entirety.",
        key_phrases=["binding", "directly applicable"],
    )

    assert build_stage_a_prompt(one) == build_stage_a_prompt(other)


# ----------------------------- stage A — the call --------------------------- #

def test_decompose_maps_the_response_into_a_decomposition(monkeypatch):
    response = SimpleNamespace(
        shortest_sufficient_answer="Yes. The data subject shall have the right to withdraw their consent at any time.",
        claims=[
            SimpleNamespace(
                text="The data subject has the right to withdraw consent at any time.",
                tag="core",
                reason="It is the substance of the shortest sufficient answer.",
            ),
            SimpleNamespace(
                text="Withdrawal does not affect the lawfulness of prior processing.",
                tag="auxiliary",
                reason="It elaborates beyond what the question asked.",
            ),
        ],
    )
    install_fake_llm(monkeypatch, stage_a_module, response)

    decomposition = asyncio.run(decompose(make_case(), MODEL_PARAMS)).value

    assert isinstance(decomposition, Decomposition)
    assert decomposition.shortest_sufficient_answer == response.shortest_sufficient_answer
    assert [c.text for c in decomposition.claims] == [c.text for c in response.claims]
    assert [c.tag for c in decomposition.claims] == ["core", "auxiliary"]
    assert [c.reason for c in decomposition.claims] == [c.reason for c in response.claims]


def test_decompose_sends_a_prompt_that_never_carries_the_quote(monkeypatch):
    """
    The prompt-builder test above proves the builder is blind; this proves the
    stage uses it, which is the property that actually reaches the model.
    """
    response = SimpleNamespace(shortest_sufficient_answer="", claims=[])
    fake, _ = install_fake_llm(monkeypatch, stage_a_module, response)

    asyncio.run(decompose(make_case(), MODEL_PARAMS))

    sent = fake.prompts[0]
    assert QUOTE not in sent
    assert QUOTE_ONLY_PHRASE not in sent
    assert QUESTION in sent and ANSWER in sent


def test_decompose_asks_for_the_stage_a_schema_and_passes_the_caller_s_model(monkeypatch):
    """
    Field names rather than the private class, so the assertion says what the
    schema *is* instead of restating an import — and a stage swapped onto the
    other stage's schema fails.
    """
    response = SimpleNamespace(shortest_sufficient_answer="", claims=[])
    _, captured = install_fake_llm(monkeypatch, stage_a_module, response)

    asyncio.run(decompose(make_case(), MODEL_PARAMS))

    assert set(captured["schema"].model_fields) == {"shortest_sufficient_answer", "claims"}
    assert captured["model_params"] == MODEL_PARAMS


def test_decompose_accepts_a_decomposition_with_no_core_claims(monkeypatch):
    """
    An empty ``core_claims`` says the gold answer does not answer its own
    question — a defect in the case, not an error in the stage. It must survive
    the call rather than raise.
    """
    response = SimpleNamespace(
        shortest_sufficient_answer="",
        claims=[
            SimpleNamespace(
                text="Consent is defined in Article 4.",
                tag="auxiliary",
                reason="Nothing in the answer addresses the question.",
            )
        ],
    )
    install_fake_llm(monkeypatch, stage_a_module, response)

    decomposition = asyncio.run(decompose(make_case(), MODEL_PARAMS)).value

    assert decomposition.core_claims == []
    assert len(decomposition.claims) == 1


def test_core_claims_keeps_only_core_tags_in_order():
    claims = [
        Claim(text="first core", tag="core", reason="r1"),
        Claim(text="an aside", tag="auxiliary", reason="r2"),
        Claim(text="second core", tag="core", reason="r3"),
    ]
    decomposition = Decomposition(shortest_sufficient_answer="first core second core", claims=claims)

    assert [c.text for c in decomposition.core_claims] == ["first core", "second core"]


# ---------------------------- stage B — the prompt -------------------------- #

def test_stage_b_prompt_carries_the_question_and_the_quote_under_their_own_labels():
    prompt = build_stage_b_prompt(make_case())

    assert prompt.index("QUESTION:") < prompt.index(QUESTION)
    assert prompt.index(QUESTION) < prompt.index("EXCERPT:")
    assert prompt.index("EXCERPT:") < prompt.index(QUOTE)


def test_stage_b_prompt_never_carries_the_gold_answer():
    """The blinding that stops the judge working backwards from the conclusion."""
    prompt = build_stage_b_prompt(make_case())

    assert ANSWER not in prompt
    assert ANSWER_ONLY_PHRASE not in prompt


def test_stage_b_prompt_is_blind_to_everything_but_the_question_and_the_quote():
    one = make_case()
    other = make_case(
        case_id="gdpr_art99_case7",
        article_number="99",
        article_title="Entry into force and application",
        answer="No. It applies from 25 May 2018.",
        answer_type="timeline",
        key_phrases=["binding", "directly applicable"],
    )

    assert build_stage_b_prompt(one) == build_stage_b_prompt(other)


def test_stage_b_prompt_never_names_the_regulation():
    """
    The first of the two defences against the judge answering from what it
    knows: the prompt says "EXCERPT of legal text", never "GDPR article". A
    model may recognise the text anyway, so this reduces prior activation rather
    than guaranteeing anything — but it must not be given away for free.
    """
    case = make_case(
        question="May a person take back their agreement once it has been given?",
        supporting_quote="The person shall have the right to take back their agreement at any time.",
    )
    prompt = build_stage_b_prompt(case)

    for name in ("GDPR", "General Data Protection", "Regulation", "Article"):
        assert name not in prompt


# --------------------------- stage B — span_is_verbatim --------------------- #

def test_span_that_is_a_run_of_the_quote_is_verbatim():
    assert span_is_verbatim("right to withdraw", QUOTE) is True


def test_the_whole_quote_is_verbatim():
    assert span_is_verbatim(QUOTE, QUOTE) is True


def test_span_differing_only_in_case_is_verbatim():
    """A span lifted from mid-sentence is routinely re-cased to stand alone."""
    assert span_is_verbatim("The Right To Withdraw", QUOTE) is True


def test_span_differing_only_in_whitespace_is_verbatim():
    quote = "The data subject shall have\n   the right to withdraw his or her consent."
    assert span_is_verbatim("shall have the right to withdraw", quote) is True


def test_span_that_closes_a_space_before_punctuation_is_verbatim():
    """An OCR artifact of the scan, not a difference in wording."""
    quote = "The controller shall , without undue delay , inform the data subject."
    assert span_is_verbatim("The controller shall, without undue delay, inform", quote) is True


def test_span_that_drops_a_markdown_list_marker_is_verbatim():
    """docling renders the regulation's enumerations as bullets; a citation reproducing them as prose is normal practice."""
    quote = "the procedure shall be adopted by:\n- their parliament;\n- their government;"
    assert span_is_verbatim("adopted by: their parliament;", quote) is True


def test_an_empty_span_is_not_verbatim():
    """
    Without the guard this is the worst failure available: '' is a substring of
    every quote, so a stage B that found no text would be reported as having
    copied it perfectly.
    """
    assert span_is_verbatim("", QUOTE) is False


def test_a_whitespace_only_span_is_not_verbatim():
    assert span_is_verbatim("   \n  ", QUOTE) is False


def test_a_paraphrased_span_is_not_verbatim():
    """Stage B is told to copy; a span it wrote instead is not a repair candidate."""
    assert span_is_verbatim("consent can be revoked whenever the data subject wants", QUOTE) is False


def test_a_span_with_an_inserted_comma_is_not_verbatim():
    """
    Punctuation is deliberately kept by ``normalize_for_grounding``: in a legal
    text a comma marks restrictive versus non-restrictive clauses, so a span
    that inserts one has altered the statute. This is the boundary the judge and
    the grounding gate must not drift apart on.
    """
    assert span_is_verbatim("the right to withdraw, his or her consent", QUOTE) is False


def test_a_span_with_reordered_words_is_not_verbatim():
    assert span_is_verbatim("his or her consent to withdraw the right", QUOTE) is False


def test_a_span_stitched_from_disjoint_parts_of_the_quote_is_not_verbatim():
    """
    ``minimal_span`` is required to be one continuous run. Where an answer needs
    disjoint pieces, the shortest run covering them is the whole stretch between
    them — so stitching must fail here rather than be quietly accepted.
    """
    assert span_is_verbatim("The data subject shall have consent at any time", QUOTE) is False


def test_a_span_absent_from_the_quote_is_not_verbatim():
    assert span_is_verbatim("the supervisory authority shall be informed", QUOTE) is False


# ----------------------------- stage B — the call --------------------------- #

def test_answer_blind_maps_the_response_into_a_blind_answer(monkeypatch):
    response = SimpleNamespace(
        answered=True,
        answer="Yes, consent may be withdrawn at any time.",
        minimal_span="the right to withdraw his or her consent at any time",
        note="The span establishes an unconditional right of withdrawal.",
    )
    install_fake_llm(monkeypatch, stage_b_module, response)

    blind = asyncio.run(answer_blind(make_case(), MODEL_PARAMS)).value

    assert blind.answered is True
    assert blind.answer == response.answer
    assert blind.minimal_span == response.minimal_span
    assert blind.note == response.note


def test_answer_blind_carries_the_insufficiency_escape(monkeypatch):
    """
    ``answered=False`` is a legitimate outcome, not an error — it is what stage
    B returned on ``gdpr_art2_case4``, the adversarial case the design was built
    around. The note is the only output that survives it, so it must not be lost.
    """
    response = SimpleNamespace(
        answered=False,
        answer="",
        minimal_span="",
        note="The excerpt concerns the right subject but does not settle the question.",
    )
    install_fake_llm(monkeypatch, stage_b_module, response)

    blind = asyncio.run(answer_blind(make_case(), MODEL_PARAMS)).value

    assert blind.answered is False
    assert blind.answer == ""
    assert blind.minimal_span == ""
    assert blind.note == response.note


def test_answer_blind_sends_a_prompt_that_never_carries_the_gold_answer(monkeypatch):
    response = SimpleNamespace(answered=False, answer="", minimal_span="", note="")
    fake, _ = install_fake_llm(monkeypatch, stage_b_module, response)

    asyncio.run(answer_blind(make_case(), MODEL_PARAMS))

    sent = fake.prompts[0]
    assert ANSWER not in sent
    assert ANSWER_ONLY_PHRASE not in sent
    assert QUESTION in sent and QUOTE in sent


def test_answer_blind_asks_for_the_stage_b_schema_and_passes_the_caller_s_model(monkeypatch):
    response = SimpleNamespace(answered=False, answer="", minimal_span="", note="")
    _, captured = install_fake_llm(monkeypatch, stage_b_module, response)

    asyncio.run(answer_blind(make_case(), MODEL_PARAMS))

    assert set(captured["schema"].model_fields) == {"minimal_span", "answer", "answered", "note"}
    assert captured["model_params"] == MODEL_PARAMS


# ---------------------------- stage C — the prompt -------------------------- #

# Stage C's fixtures follow the `gdpr_art8_case1` run: one core claim, and a
# blind answer far terser than the claim it has to carry.
C_QUESTION = "What is the minimum age at which a child can give their own consent?"
CORE_CLAIM = Claim(
    text="The minimum age is 16 years old.",
    tag="core",
    reason="It is the substance of the shortest sufficient answer.",
)
SECOND_CLAIM = Claim(
    text="Consent must be given by the holder of parental responsibility.",
    tag="core",
    reason="The question asks who may consent.",
)

# `minimal_span` is a verbatim slice of the quote and `note` is stage B's own
# assessment. Neither may reach stage C, so both carry distinctive text.
BLIND = BlindAnswer(
    answered=True,
    answer="16 years old",
    minimal_span="the child is at least 16 years old",
    note="The span establishes an unconditional age threshold.",
)
SPAN_ONLY_PHRASE = "at least 16"
NOTE_ONLY_PHRASE = "unconditional age threshold"


def test_stage_c_prompt_carries_the_question_the_answer_and_the_claims_under_their_own_labels():
    prompt = build_stage_c_prompt(C_QUESTION, [CORE_CLAIM], BLIND)

    assert prompt.index("QUESTION:") < prompt.index(C_QUESTION)
    assert prompt.index(C_QUESTION) < prompt.index("ANSWER:")
    assert prompt.index("ANSWER:") < prompt.index(BLIND.answer)
    assert prompt.index(BLIND.answer) < prompt.index("CLAIMS:")
    assert prompt.index("CLAIMS:") < prompt.index(CORE_CLAIM.text)


def test_stage_c_prompt_never_carries_the_span_or_the_note():
    """
    The span is a verbatim slice of the quote, so leaking it would hand stage C
    the evidence it must not re-read — the blinding that makes stage B worth
    running at all. The note is stage B's self-assessment: adjudicating against
    it would judge what stage B thought rather than what it answered.
    """
    prompt = build_stage_c_prompt(C_QUESTION, [CORE_CLAIM], BLIND)

    assert BLIND.minimal_span not in prompt
    assert SPAN_ONLY_PHRASE not in prompt
    assert BLIND.note not in prompt
    assert NOTE_ONLY_PHRASE not in prompt


def test_stage_c_prompt_is_blind_to_every_field_of_the_blind_answer_but_the_answer():
    """The invariance form of the test above — a field added later fails here."""
    other = BlindAnswer(
        answered=False,
        answer=BLIND.answer,
        minimal_span="an entirely different slice of some other article",
        note="a different note, reaching a different conclusion",
    )

    assert build_stage_c_prompt(C_QUESTION, [CORE_CLAIM], BLIND) == build_stage_c_prompt(
        C_QUESTION, [CORE_CLAIM], other
    )


def test_stage_c_prompt_never_shows_a_claims_tag_or_stage_as_reasoning():
    """
    Every claim reaching stage C is core, so a tag carries no information and
    could only invite treating one claim as lower-stakes. Stage A's ``reason`` is
    withheld for a sharper reason: it is *how stage A thought*, and stage C
    comparing two independent artifacts must not be shown one of their workings.
    """
    tagged = Claim(
        text="The minimum age is 16 years old.",
        tag="auxiliary",
        reason="A distinctive rationale that must not reach stage C.",
    )
    prompt = build_stage_c_prompt(C_QUESTION, [tagged], BLIND)

    assert "auxiliary" not in prompt
    assert tagged.reason not in prompt
    assert "distinctive rationale" not in prompt


def test_stage_c_prompt_never_names_the_regulation():
    """
    Stage C judges text against text and needs no legal knowledge at all, so
    naming the law could only invite it to supply what the answer does not say.
    """
    prompt = build_stage_c_prompt(
        "What is the minimum age for a person to agree on their own behalf?",
        [Claim(text="The minimum age is 16 years old.", tag="core", reason="asked")],
        BlindAnswer(answered=True, answer="16 years old", minimal_span="", note=""),
    )

    for name in ("GDPR", "General Data Protection", "Regulation", "Article"):
        assert name not in prompt


# --------------------------- stage C — render_claims ------------------------ #

def test_render_claims_numbers_from_one_in_order():
    rendered = render_claims([CORE_CLAIM, SECOND_CLAIM])

    assert rendered == (
        "1. The minimum age is 16 years old.\n"
        "2. Consent must be given by the holder of parental responsibility."
    )


def test_render_claims_of_no_claims_is_empty():
    assert render_claims([]) == ""


# ----------------------------- stage C — the call --------------------------- #

def test_adjudicate_matches_verdicts_to_claims_by_number_not_by_position(monkeypatch):
    """
    The reason claims are numbered at all. A response listing claim 2 before
    claim 1 must still label the right claims — under positional pairing this
    silently swaps them, and every downstream verdict is derived from the swap.
    """
    response = SimpleNamespace(
        claim_verdicts=[
            SimpleNamespace(claim_number=2, support="absent", rationale="Says nothing about who consents."),
            SimpleNamespace(claim_number=1, support="supported", rationale="States '16 years old'."),
        ]
    )
    install_fake_llm(monkeypatch, stage_c_module, response)

    adjudication = asyncio.run(
        adjudicate(C_QUESTION, [CORE_CLAIM, SECOND_CLAIM], BLIND, MODEL_PARAMS)
    ).value

    first, second = adjudication.claim_verdicts
    assert first.claim is CORE_CLAIM
    assert first.support == "supported"
    assert first.rationale == "States '16 years old'."
    assert second.claim is SECOND_CLAIM
    assert second.support == "absent"
    assert second.rationale == "Says nothing about who consents."


def test_adjudicate_carries_all_three_support_values(monkeypatch):
    third = Claim(text="Consent may be withdrawn.", tag="core", reason="asked")
    response = SimpleNamespace(
        claim_verdicts=[
            SimpleNamespace(claim_number=1, support="supported", rationale="r1"),
            SimpleNamespace(claim_number=2, support="absent", rationale="r2"),
            SimpleNamespace(claim_number=3, support="contradicted", rationale="r3"),
        ]
    )
    install_fake_llm(monkeypatch, stage_c_module, response)

    adjudication = asyncio.run(
        adjudicate(C_QUESTION, [CORE_CLAIM, SECOND_CLAIM, third], BLIND, MODEL_PARAMS)
    ).value

    assert [v.support for v in adjudication.claim_verdicts] == [
        "supported", "absent", "contradicted",
    ]


def test_adjudicate_rejects_a_verdict_for_a_claim_that_was_never_given(monkeypatch):
    """An invented claim number means the mapping cannot be trusted at all."""
    response = SimpleNamespace(
        claim_verdicts=[
            SimpleNamespace(claim_number=1, support="supported", rationale="r1"),
            SimpleNamespace(claim_number=7, support="absent", rationale="r7"),
        ]
    )
    install_fake_llm(monkeypatch, stage_c_module, response)

    with pytest.raises(AdjudicationError) as excinfo:
        asyncio.run(adjudicate(C_QUESTION, [CORE_CLAIM], BLIND, MODEL_PARAMS))

    assert "7" in str(excinfo.value)


def test_adjudicate_rejects_claim_number_zero(monkeypatch):
    """Numbering starts at 1, so a 0 is off-by-one rather than a stray value."""
    response = SimpleNamespace(
        claim_verdicts=[SimpleNamespace(claim_number=0, support="supported", rationale="r")]
    )
    install_fake_llm(monkeypatch, stage_c_module, response)

    with pytest.raises(AdjudicationError):
        asyncio.run(adjudicate(C_QUESTION, [CORE_CLAIM], BLIND, MODEL_PARAMS))


def test_adjudicate_rejects_a_claim_labelled_twice(monkeypatch):
    response = SimpleNamespace(
        claim_verdicts=[
            SimpleNamespace(claim_number=1, support="supported", rationale="r1"),
            SimpleNamespace(claim_number=1, support="absent", rationale="r1-again"),
        ]
    )
    install_fake_llm(monkeypatch, stage_c_module, response)

    with pytest.raises(AdjudicationError) as excinfo:
        asyncio.run(adjudicate(C_QUESTION, [CORE_CLAIM, SECOND_CLAIM], BLIND, MODEL_PARAMS))

    assert "more than once" in str(excinfo.value)


def test_adjudicate_rejects_a_dropped_claim(monkeypatch):
    """
    The failure positional pairing hides: two verdicts for three claims would
    mislabel the third rather than fail, and the error names which is missing.
    """
    third = Claim(text="Consent may be withdrawn.", tag="core", reason="asked")
    response = SimpleNamespace(
        claim_verdicts=[
            SimpleNamespace(claim_number=1, support="supported", rationale="r1"),
            SimpleNamespace(claim_number=3, support="absent", rationale="r3"),
        ]
    )
    install_fake_llm(monkeypatch, stage_c_module, response)

    with pytest.raises(AdjudicationError) as excinfo:
        asyncio.run(
            adjudicate(C_QUESTION, [CORE_CLAIM, SECOND_CLAIM, third], BLIND, MODEL_PARAMS)
        )

    assert "2" in str(excinfo.value)


def test_adjudicate_asks_for_the_stage_c_schema_and_passes_the_caller_s_model(monkeypatch):
    response = SimpleNamespace(
        claim_verdicts=[SimpleNamespace(claim_number=1, support="supported", rationale="r")]
    )
    _, captured = install_fake_llm(monkeypatch, stage_c_module, response)

    asyncio.run(adjudicate(C_QUESTION, [CORE_CLAIM], BLIND, MODEL_PARAMS))

    assert set(captured["schema"].model_fields) == {"claim_verdicts"}
    assert captured["model_params"] == MODEL_PARAMS


# ------------------- stage C — the two paths that take no call -------------- #

def test_adjudicate_makes_no_call_when_there_are_no_claims(monkeypatch):
    """
    Stage A legitimately returns no core claims when a gold answer does not
    answer its own question. There is nothing to adjudicate, and spending a call
    to be told so would be spending it 433 times.
    """
    fake, _ = install_fake_llm(monkeypatch, stage_c_module, SimpleNamespace(claim_verdicts=[]))

    adjudication = asyncio.run(adjudicate(C_QUESTION, [], BLIND, MODEL_PARAMS)).value

    assert adjudication.claim_verdicts == []
    assert fake.prompts == []


def test_adjudicate_makes_no_call_when_stage_b_produced_no_answer_text(monkeypatch):
    """
    An empty answer carries nothing, so every claim is absent by arithmetic
    rather than by judgement — and asking a model to confirm it would invite it
    to fill the silence from what it knows.
    """
    silent = BlindAnswer(answered=False, answer="", minimal_span="", note="nothing settles it")
    fake, _ = install_fake_llm(monkeypatch, stage_c_module, SimpleNamespace(claim_verdicts=[]))

    adjudication = asyncio.run(
        adjudicate(C_QUESTION, [CORE_CLAIM, SECOND_CLAIM], silent, MODEL_PARAMS)
    ).value

    assert fake.prompts == []
    assert [v.support for v in adjudication.claim_verdicts] == ["absent", "absent"]
    assert [v.claim for v in adjudication.claim_verdicts] == [CORE_CLAIM, SECOND_CLAIM]
    assert all(v.rationale for v in adjudication.claim_verdicts)


def test_adjudicate_treats_a_whitespace_only_answer_as_no_answer(monkeypatch):
    blank = BlindAnswer(answered=True, answer="  \n  ", minimal_span="", note="")
    fake, _ = install_fake_llm(monkeypatch, stage_c_module, SimpleNamespace(claim_verdicts=[]))

    adjudication = asyncio.run(adjudicate(C_QUESTION, [CORE_CLAIM], blank, MODEL_PARAMS)).value

    assert fake.prompts == []
    assert [v.support for v in adjudication.claim_verdicts] == ["absent"]


def test_adjudicate_judges_an_answer_written_despite_the_escape(monkeypatch):
    """
    The guard is on the answer text, not on ``answered``. A model that took the
    escape and still wrote an answer has produced something judgeable, and
    short-circuiting on the flag would discard it unread.
    """
    contrary = BlindAnswer(
        answered=False,
        answer="16 years old",
        minimal_span="the child is at least 16 years old",
        note="Reported as unanswered, but an answer was written anyway.",
    )
    response = SimpleNamespace(
        claim_verdicts=[SimpleNamespace(claim_number=1, support="supported", rationale="r")]
    )
    fake, _ = install_fake_llm(monkeypatch, stage_c_module, response)

    adjudication = asyncio.run(adjudicate(C_QUESTION, [CORE_CLAIM], contrary, MODEL_PARAMS)).value

    assert len(fake.prompts) == 1
    assert [v.support for v in adjudication.claim_verdicts] == ["supported"]


# ------------------------------ import cost --------------------------------- #

def test_importing_a_judge_stage_does_not_load_torch():
    """
    The stages are importable without paying langchain → transformers → torch,
    measured at 6.3s before ``llm.py`` deferred it.

    A fresh interpreter is required: by the time this test runs, another test
    module has already imported torch into *this* process, so an in-process
    ``sys.modules`` check would pass no matter what the stages do. Both names
    are asserted because ``langchain_core`` is the leg that pulls torch — a
    future edit re-importing it at module scope would reintroduce the whole
    cost, and this test names that rather than only its symptom.
    """
    probe = (
        "import sys\n"
        "import src.eval.sufficiency.stage_a\n"
        "import src.eval.sufficiency.stage_b\n"
        "import src.eval.sufficiency.stage_c\n"
        "loaded = [m for m in ('torch', 'langchain_core') if m in sys.modules]\n"
        "print(','.join(loaded))\n"
    )
    result = subprocess.run(
        [sys.executable, "-c", probe],
        cwd=REPO_ROOT, capture_output=True, text=True, check=True,
    )

    assert result.stdout.strip() == "", (
        f"importing the judge stages loaded {result.stdout.strip()}; "
        "the ai_common and langchain_core imports in sufficiency/llm.py are deferred on purpose"
    )


# ------------------------- the two stages against each other ---------------- #

def test_the_two_stages_see_disjoint_evidence():
    """
    The protocol's whole claim in one assertion: stage A sees the answer and not
    the quote, stage B sees the quote and not the answer. If either half ever
    stops holding, the stages stop being independent and stage C is comparing
    two views of the same evidence.
    """
    case = make_case()
    prompt_a = build_stage_a_prompt(case)
    prompt_b = build_stage_b_prompt(case)

    assert case.answer in prompt_a and case.supporting_quote not in prompt_a
    assert case.supporting_quote in prompt_b and case.answer not in prompt_b

# --------------------- the transport failure every stage shares ------------- #
#
# `with_structured_output` yields None when the model's output cannot be coerced
# into the requested schema. Observed 2026-08-22 on stage A2 as
# `AttributeError: 'NoneType' object has no attribute 'claims'` — raised from
# inside a list comprehension, naming neither the stage nor the cause. Every
# stage had the same shape, because every stage read a field straight off what
# `ainvoke` returned.
#
# These pin the guard per stage rather than testing `require_response` once,
# because the defect was never in the helper: it was that five call sites each
# forgot the check. A test of the helper alone would pass against a stage that
# had dropped it.

@pytest.mark.parametrize(
    "module, call, stage_label",
    [
        (stage_a_module, lambda: decompose(make_case(), MODEL_PARAMS), "A"),
        (stage_a1_module,
         lambda: write_shortest_answer("Q?", "An answer.", MODEL_PARAMS), "A1"),
        (stage_a2_module,
         lambda: tag_claims("Q?", "An answer.", MODEL_PARAMS), "A2"),
        (stage_b_module, lambda: answer_blind(make_case(), MODEL_PARAMS), "B"),
        (stage_c_module,
         lambda: adjudicate(
             "Q?",
             [Claim(text="A claim.", tag="core", reason="because")],
             BlindAnswer(answered=True, answer="An answer.", minimal_span="An", note=""),
             MODEL_PARAMS,
         ),
         "C"),
    ],
)
def test_a_stage_raises_rather_than_crashing_when_the_model_returns_nothing(
    monkeypatch, module, call, stage_label
):
    """
    A None response must raise JudgeResponseError naming the stage, not an
    AttributeError from wherever the first field access happens to be.

    The stage label is asserted because the message is the only thing that says
    *which* of five identically-shaped call sites failed, and a run that loses a
    case needs to record which stage lost it.
    """
    install_fake_payload(monkeypatch, module, None)

    with pytest.raises(JudgeResponseError) as excinfo:
        asyncio.run(call())

    assert f"stage {stage_label}" in str(excinfo.value)


def test_a_transport_failure_is_not_a_judgement():
    """
    JudgeResponseError must not be catchable as a stage's own domain error.

    Stage C raises AdjudicationError when the model answers but the answer does
    not map onto the claims — a judgement that went wrong. A transport failure is
    a case that was never judged at all. Folding the two together would let a
    caller that meant to tolerate a bad mapping silently drop unjudged cases,
    which shrinks the sample without saying so.
    """
    assert not issubclass(JudgeResponseError, AdjudicationError)
    assert not issubclass(AdjudicationError, JudgeResponseError)


def test_a_stage_says_what_the_model_returned_when_it_would_not_parse(monkeypatch):
    """
    An unparseable answer must be quoted back, not reported as silence.

    Before ``include_raw`` these were the same event: a coercion failure and an
    empty response both arrived as ``None``, and the error could only say that
    something went wrong. They call for different repairs — a refusal is a
    prompt problem, an empty response is a transport problem — so the text and
    the parser's own complaint are both carried into the message.
    """
    install_fake_payload(
        monkeypatch,
        stage_a2_module,
        make_payload(
            None,
            content="I cannot split this answer into claims.",
            parsing_error=ValueError("no tool call found"),
        ),
    )

    with pytest.raises(JudgeResponseError) as excinfo:
        asyncio.run(tag_claims("Q?", "An answer.", MODEL_PARAMS))

    message = str(excinfo.value)
    assert "stage A2" in message
    assert "I cannot split this answer into claims." in message
    assert "no tool call found" in message


# ------------------------------ what a call cost ---------------------------- #
#
# Every stage reads its price off the same payload, and every stage has to hand
# it on. That is five call sites each of which can silently drop the field —
# the shape of the defect the None guard was written for, so it is pinned the
# same way: per stage, not once on the helper.

@pytest.mark.parametrize(
    "module, call, parsed",
    [
        (stage_a_module,
         lambda: decompose(make_case(), MODEL_PARAMS),
         SimpleNamespace(shortest_sufficient_answer="An answer.", claims=[])),
        (stage_a1_module,
         lambda: write_shortest_answer("Q?", "An answer.", MODEL_PARAMS),
         SimpleNamespace(shortest_sufficient_answer="An answer.")),
        (stage_a2_module,
         lambda: tag_claims("Q?", "An answer.", MODEL_PARAMS),
         SimpleNamespace(claims=[])),
        (stage_b_module,
         lambda: answer_blind(make_case(), MODEL_PARAMS),
         SimpleNamespace(answered=True, answer="An answer.", minimal_span="An", note="")),
        (stage_c_module,
         lambda: adjudicate(C_QUESTION, [CORE_CLAIM], BLIND, MODEL_PARAMS),
         SimpleNamespace(
             claim_verdicts=[
                 SimpleNamespace(claim_number=1, support="supported", rationale="r")
             ]
         )),
    ],
)
def test_a_stage_carries_the_price_of_its_call(monkeypatch, module, call, parsed):
    install_fake_llm(monkeypatch, module, parsed, cost=FAKE_COST)

    assert asyncio.run(call()).cost == FAKE_COST


def test_a_call_the_provider_did_not_price_is_unpriced_rather_than_free(monkeypatch):
    """
    ``cost`` is an OpenRouter field, and a provider that omits it must yield
    ``None``.

    Zero would be a lie of the expensive kind: it reads as a call that cost
    nothing, sums into a total that looks complete, and hides spend that
    happened. ``None`` propagates into :func:`sum_costs` as a count of what
    could not be priced.
    """
    install_fake_llm(monkeypatch, stage_a2_module, SimpleNamespace(claims=[]), cost=None)

    assert asyncio.run(tag_claims("Q?", "An answer.", MODEL_PARAMS)).cost is None


@pytest.mark.parametrize(
    "claims, blind",
    [
        ([], BLIND),
        ([CORE_CLAIM], BlindAnswer(answered=False, answer="", minimal_span="", note="")),
    ],
    ids=["no claims", "no answer text"],
)
def test_stage_c_reports_zero_rather_than_unpriced_when_it_makes_no_call(
    monkeypatch, claims, blind
):
    """
    The other half of the distinction above. Stage C declines to call the model
    when there is nothing to adjudicate, and a call that never happened has a
    known price of zero — unlike a call that happened and came back unpriced.
    Collapsing the two would make a skipped stage look like a billing gap.
    """
    install_fake_llm(monkeypatch, stage_c_module, SimpleNamespace(claim_verdicts=[]))

    assert asyncio.run(adjudicate(C_QUESTION, claims, blind, MODEL_PARAMS)).cost == 0.0


def test_summing_costs_returns_the_total_and_how_much_was_unpriced():
    assert sum_costs([0.25, 0.75]) == (1.0, 0)


def test_summing_costs_counts_the_unpriced_instead_of_treating_them_as_zero():
    """
    The count is what stops a partial total being read as a complete one. A
    caller that only gets the float cannot tell $1.00 over two calls from $1.00
    over two calls plus three that nobody could price.
    """
    assert sum_costs([0.25, None, 0.75, None]) == (1.0, 2)


def test_summing_no_costs_is_zero_and_nothing_unpriced():
    """A run that made no calls spent nothing, and knows it."""
    assert sum_costs([]) == (0.0, 0)


# --------------------- the two-call stage A variant ------------------------- #

def test_the_two_call_variant_charges_for_both_of_its_calls(monkeypatch):
    """
    A1 and A2 are two calls, and the variant exists to be compared against the
    combined stage on exactly that trade. A cost that reported one leg would
    make the expensive option look like the cheap one.
    """
    install_fake_llm(
        monkeypatch, stage_a1_module,
        SimpleNamespace(shortest_sufficient_answer="An answer."), cost=0.001,
    )
    install_fake_llm(monkeypatch, stage_a2_module, SimpleNamespace(claims=[]), cost=0.002)

    assert asyncio.run(decompose_twocall(make_case(), MODEL_PARAMS)).cost == 0.003


def test_the_two_call_variant_is_unpriced_when_either_leg_is(monkeypatch):
    """
    Not the priced half. A number covering one of two calls, presented as the
    cost of the pair, understates by exactly the amount nobody can see.
    """
    install_fake_llm(
        monkeypatch, stage_a1_module,
        SimpleNamespace(shortest_sufficient_answer="An answer."), cost=0.001,
    )
    install_fake_llm(monkeypatch, stage_a2_module, SimpleNamespace(claims=[]), cost=None)

    assert asyncio.run(decompose_twocall(make_case(), MODEL_PARAMS)).cost is None


def test_the_two_call_variant_keeps_both_halves_of_what_it_paid_for(monkeypatch):
    """
    The cost plumbing must not disturb what the variant is for: A1's answer and
    A2's claims arrive unreconciled, exactly as returned.
    """
    install_fake_llm(
        monkeypatch, stage_a1_module,
        SimpleNamespace(shortest_sufficient_answer="The shortest answer."),
    )
    install_fake_llm(
        monkeypatch, stage_a2_module,
        SimpleNamespace(
            claims=[SimpleNamespace(text="A claim.", tag="core", reason="because")]
        ),
    )

    decomposition = asyncio.run(decompose_twocall(make_case(), MODEL_PARAMS)).value

    assert decomposition.shortest_sufficient_answer == "The shortest answer."
    assert [c.text for c in decomposition.claims] == ["A claim."]

"""
Unit tests for stages A and B of the sufficiency judge.

Both stages were built on 2026-08-05 and verified by eyeballing eight cases,
which under this project's own rule leaves them unverified rather than working —
``span_is_verbatim`` in particular returned 8/8 verbatim and has therefore never
been observed to fail. These tests pin what is deterministic in the two stages:
the **structural blinding** that the whole protocol rests on, the mapping from a
model response into the stage's dataclass, and ``span_is_verbatim``.

The blinding is the load-bearing part. Stage A must never see the quote, or its
core/auxiliary tagging can be fitted to whatever the quote happens to contain;
stage B must never see the gold answer, or it can work backwards from the
conclusion it exists to test. Both are claims about what a prompt *cannot*
contain, so they are tested as invariance properties — two cases differing in
every field but the two a stage is allowed to see must produce byte-identical
prompts — rather than by checking one sentinel string, which a later field
added to a prompt would slip straight past.

No model is called. Each stage's runnable is replaced with a fake, so what is
tested is the stage's own wiring: which prompt it sends, which schema it asks
for, and how it maps what comes back.
"""
import asyncio
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace

from src.eval.dataset import TestCase
from src.eval.sufficiency.models import Claim, Decomposition
from src.eval.sufficiency.stage_a import build_stage_a_prompt, decompose
from src.eval.sufficiency.stage_b import (
    answer_blind,
    build_stage_b_prompt,
    span_is_verbatim,
)
from src.eval.sufficiency import stage_a as stage_a_module
from src.eval.sufficiency import stage_b as stage_b_module


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


class _FakeJudgeLLM:
    """Stands in for the structured-output runnable a stage builds."""

    def __init__(self, response):
        self.response = response
        self.prompts = []

    async def ainvoke(self, prompt):
        self.prompts.append(prompt)
        return self.response


def install_fake_llm(monkeypatch, module, response):
    """
    Replace a stage's ``build_judge_llm`` with one returning a fake runnable.

    Returns the fake — which records every prompt it was invoked with — and a
    dict capturing the arguments the stage passed to the builder.
    """
    fake = _FakeJudgeLLM(response)
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

    rindex rather than index, because the worked examples in the stage A
    prompt carry their own QUESTION:/ANSWER: lines. Against index this
    test would compare the real fields to the *examples'* labels and pass however
    the real ones were ordered.
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

    decomposition = asyncio.run(decompose(make_case(), MODEL_PARAMS))

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

    decomposition = asyncio.run(decompose(make_case(), MODEL_PARAMS))

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

    blind = asyncio.run(answer_blind(make_case(), MODEL_PARAMS))

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

    blind = asyncio.run(answer_blind(make_case(), MODEL_PARAMS))

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
        "import src.eval.sufficiency.stage_a, src.eval.sufficiency.stage_b\n"
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
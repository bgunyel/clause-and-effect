"""
Unit tests for the capture half: the response readers, the contexts, the row.

**Nothing here calls a model and nothing writes to a database.** The gate that
makes the second true is the same structural one `test_db_engine` covers, and
every test that needs the log *on* replaces the recorder as it forces the gate,
so the only thing a forced gate can reach is a list in this file.

Three properties get most of the attention, because all three fail silently:

- **A row's fields are read off the right place.** A metadata key that moved
  yields ``None``, which is indistinguishable from a provider that did not
  report the field. The literal shapes below come from a real OpenRouter reply
  dumped 2026-08-23, not from the documentation.
- **A failed call is still logged.** The failure paths are where the money goes
  unaccounted for, so they are tested more heavily than the success path.
- **The timer excludes the write**, which is why the eval's latency numbers are
  the model's and not ours.

Expected values are literals: the digest is written out as a hex string rather
than recomputed with ``hashlib``, and the status strings as ``"OK"`` rather than
``CallStatus.OK.value``.
"""
import asyncio
import uuid
from datetime import datetime, timezone
from types import SimpleNamespace

import pytest

from src.db import engine as engine_module
from src.db.capture import context as context_module
from src.db.capture import recorder, response
from src.db.capture.context import (
    CallContext,
    call_context,
    case_context,
    current_call,
    current_case,
    reset_run,
)
from src.db.models import CallStatus, LlmCall, LlmRun
from src.eval.sufficiency.llm import JudgeResponseError, llm_call

RUN_ID = uuid.UUID("44444444-4444-4444-8444-444444444444")
CALL_ID = uuid.UUID("55555555-5555-4555-8555-555555555555")
WHEN = datetime(2026, 8, 26, 12, 0, tzinfo=timezone.utc)

# A real OpenRouter reply's metadata, from the 2026-08-23 dev log. The keys are
# transcribed rather than derived; that is the whole point of the fixture.
LIVE_RESPONSE_METADATA = {
    "cost": 3.235e-05,
    "cost_details": {},
    "created": 1787636121,
    "finish_reason": "stop",
    "id": "gen-1787636121-eAEcEp3BID10rZPfqZgv",
    "logprobs": None,
    "model_name": "deepseek/deepseek-v4-flash",
    "model_provider": "openrouter",
    "object": "chat.completion",
}
LIVE_USAGE_METADATA = {
    "input_tokens": 287,
    "output_tokens": 180,
    "total_tokens": 467,
    "output_token_details": {"reasoning": 153},
}


def a_message(content="{}", **overrides):
    """An `AIMessage`-shaped object. Duck-typed, because the readers are."""
    return SimpleNamespace(
        content=content,
        response_metadata={**LIVE_RESPONSE_METADATA, **overrides.pop("metadata", {})},
        usage_metadata={**LIVE_USAGE_METADATA, **overrides.pop("usage", {})},
        **overrides,
    )


MODEL_PARAMS = {
    # Enum-shaped, like the real config entry: `.value` is the platform-neutral
    # name and `str()` on these members yields the Python identifier.
    "model": SimpleNamespace(value="deepseek-v4-flash-0731"),
    "model_provider": SimpleNamespace(value="openrouter"),
    "structured_output": "function_calling",
    "model_args": {"temperature": 0, "provider": {"require_parameters": True}},
}


@pytest.fixture(autouse=True)
def _clean_run():
    reset_run()
    yield
    reset_run()


@pytest.fixture
def fake_run(monkeypatch):
    """Stop the run row shelling out to git, and make it predictable."""
    monkeypatch.setattr(
        context_module,
        "_build_run_row",
        lambda: LlmRun(
            run_id=RUN_ID, entry_point="probe.py", commit_sha="c6cf492",
            git_dirty_paths=[], started_at=WHEN, hostname="workstation",
        ),
    )


@pytest.fixture
def recorded(monkeypatch, fake_run):
    """
    Force the gate open and replace the writer with a list.

    Both halves matter. Forcing the gate is what exercises the recording path at
    all — `is_enabled` is `False` under pytest by construction — and replacing
    the writer is what makes that safe.
    """
    rows = []

    async def capture(row):
        rows.append(row)
        return True

    monkeypatch.setattr(engine_module, "_under_pytest", lambda: False)
    monkeypatch.setattr(
        engine_module, "get_settings",
        lambda: SimpleNamespace(DB_URL=SimpleNamespace(get_secret_value=lambda: "postgresql://h/d")),
    )
    monkeypatch.setattr(recorder, "record_call", capture)
    return rows


class _FakeRunnable:
    """A built runnable, as `build_judge_llm` would have returned one."""

    def __init__(self, payload=None, raises=None):
        self.payload = payload
        self.raises = raises
        self.seen_context = "not invoked"

    async def ainvoke(self, prompt):
        # Read *during* the call, which is the only window the socket has.
        self.seen_context = current_call()
        if self.raises is not None:
            raise self.raises
        return self.payload


def a_payload(parsed=None, raw=None, parsing_error=None):
    return {"raw": raw if raw is not None else a_message(), "parsed": parsed,
            "parsing_error": parsing_error}


# --------------------------------------------------------------------------
# Reading a response
# --------------------------------------------------------------------------


def test_every_field_is_read_off_the_shape_a_real_reply_had():
    message = a_message()

    assert response.generation_id_of(message) == "gen-1787636121-eAEcEp3BID10rZPfqZgv"
    assert response.cost_of(message) == 3.235e-05
    assert response.finish_reason_of(message) == "stop"
    assert response.prompt_tokens_of(message) == 287
    assert response.completion_tokens_of(message) == 180
    assert response.reasoning_tokens_of(message) == 153


def test_the_generation_id_is_the_providers_and_not_langchains():
    """
    `raw.id` is a LangChain run identifier minted in this process. It is the
    tempting attribute and it joins to nothing outside this process — while the
    provider's id is the only key by which a call can ever be found again.
    """
    message = a_message(id="lc_run--01a0376a-7f1a-4a5e-9c2f-000000000000")

    assert response.generation_id_of(message) == "gen-1787636121-eAEcEp3BID10rZPfqZgv"


def test_a_missing_field_reads_as_none_rather_than_raising():
    """A provider field, not a LangChain one: absence must not lose a judgement."""
    bare = SimpleNamespace(content="hi")

    assert response.cost_of(bare) is None
    assert response.generation_id_of(bare) is None
    assert response.reasoning_tokens_of(bare) is None
    assert response.cost_of(None) is None


def test_zero_reasoning_tokens_are_not_none():
    """
    `0` is a provider saying this call did no reasoning; `None` is a provider
    not saying. Only the first belongs in an average, and the panel's channel
    question turns on the difference.
    """
    message = a_message(usage={"output_token_details": {"reasoning": 0}})

    assert response.reasoning_tokens_of(message) == 0


def test_content_is_returned_whole():
    """
    Decision 10. `JudgeResponseError` quotes 300 characters, and on 2026-08-25
    that truncation was the reason a MiniMax failure could not be diagnosed.
    """
    long_answer = "x" * 5000

    assert response.content_of(a_message(content=long_answer)) == long_answer


# --------------------------------------------------------------------------
# The contexts
# --------------------------------------------------------------------------


def test_there_is_no_call_in_flight_outside_a_wrapper():
    """
    Trap 8. The socket writes a null `call_id` for a request made outside any
    wrapper, which is how a bypassed wrapper reports itself instead of hiding.
    """
    assert current_call() is None


def test_the_call_in_flight_is_visible_and_then_gone():
    context = CallContext(run_id=RUN_ID, call_id=CALL_ID, stage="A2", case_id="art7_case4")

    with call_context(context):
        assert current_call() is context

    assert current_call() is None


def test_a_nested_call_restores_the_outer_one():
    """
    `reset(token)` rather than setting back to `None`: the two differ when
    contexts nest, and only the token restores what was actually there.
    """
    outer = CallContext(run_id=RUN_ID, call_id=CALL_ID, stage="B", case_id="c1")
    inner = CallContext(run_id=RUN_ID, call_id=uuid.uuid4(), stage="C", case_id="c1")

    with call_context(outer):
        with call_context(inner):
            assert current_call() is inner
        assert current_call() is outer


def test_the_case_is_set_by_the_caller_and_cleared_after():
    assert current_case() is None
    with case_context("art15_case1"):
        assert current_case() == "art15_case1"
    assert current_case() is None


def test_a_case_of_none_is_allowed():
    """The product path has no case, and design §Schema says that is not a gap."""
    with case_context(None):
        assert current_case() is None


def test_the_call_context_cannot_be_mutated_in_place():
    """
    A contextvar holding a mutable object would let one task's edit reach
    another task's view of it — the one property the choice of contextvars was
    making.
    """
    context = CallContext(run_id=RUN_ID, call_id=CALL_ID, stage="A", case_id=None)

    with pytest.raises(Exception):
        context.stage = "B"


def test_the_run_row_is_built_once_per_process(fake_run):
    first = context_module.RUN.row()

    assert context_module.RUN.row() is first


def test_the_entry_point_is_a_name_and_not_a_path(monkeypatch):
    monkeypatch.setattr(context_module.sys, "argv", ["/home/x/scripts/probe_a2_panel.py"])

    assert context_module._entry_point() == "probe_a2_panel.py"


def test_an_interpreter_with_no_script_still_names_something(monkeypatch):
    """`entry_point` is NOT NULL, and `python -c` sets argv[0] to an empty string."""
    monkeypatch.setattr(context_module.sys, "argv", [""])

    assert context_module._entry_point() == "<interactive>"


# --------------------------------------------------------------------------
# Building the row
# --------------------------------------------------------------------------


def a_context(stage="A2", case_id="art7_case4"):
    return CallContext(run_id=RUN_ID, call_id=CALL_ID, stage=stage, case_id=case_id)


def build(status=CallStatus.OK, **overrides):
    fields = dict(
        context=a_context(), model_params=MODEL_PARAMS, prompt="the prompt",
        status=status, started_at=WHEN, call_seconds=12.5, raw=a_message(),
    )
    return recorder.build_call_row(**{**fields, **overrides})


def test_the_prompt_is_hashed_and_not_stored():
    """
    Decision 11: the prompt is a pure function of the case, the stage and the
    templates at `commit_sha`. The hash is what makes that reconstruction
    checkable rather than merely asserted.
    """
    row = build(prompt="hello")

    assert row.prompt_sha256 == (
        "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
    )


def test_the_model_is_written_as_the_platform_neutral_value():
    """
    Decision 14. These enums carry no `str` mixin, so `str(member)` yields
    `DEEPSEEK_V_4_FLASH_0731` — a Python identifier, and the wrong string for a
    column that has to match what the alias table maps to a wire id.
    """
    row = build()

    assert row.model == "deepseek-v4-flash-0731"
    assert row.llm_server == "openrouter"


def test_a_model_already_given_as_a_string_is_left_alone():
    row = build(model_params={**MODEL_PARAMS, "model": "minimax-m3"})

    assert row.model == "minimax-m3"


def test_the_routing_constraint_is_recorded_as_it_was_sent():
    """
    What we asked for. `llm_attempt.served_provider` is what answered, and the
    finding of 2026-08-25 is that the two differ — trap 7.
    """
    row = build()

    assert row.requested_provider == {"require_parameters": True}


def test_the_call_carries_its_context():
    row = build()

    assert row.call_id == CALL_ID
    assert row.run_id == RUN_ID
    assert row.stage == "A2"
    assert row.case_id == "art7_case4"


def test_a_successful_call_stores_no_raw_output():
    """
    Storing it on every call would put every generation this project has made
    into a public database's backups.
    """
    row = build(status=CallStatus.OK)

    assert row.status == "OK"
    assert row.raw_output is None
    assert row.error_type is None


def test_a_failed_call_stores_what_the_model_said_in_full():
    row = build(
        status=CallStatus.STRUCTURE_PROBLEM,
        raw=a_message(content="y" * 4000),
        error=JudgeResponseError("stage A2: …", call=None),
        error_message="stage A2: the model's output would not coerce",
    )

    assert row.status == "STRUCTURE_PROBLEM"
    assert row.raw_output == "y" * 4000
    assert row.error_type == "JudgeResponseError"
    assert row.error_message == "stage A2: the model's output would not coerce"


def test_a_failed_call_still_records_what_it_cost():
    """
    The whole reason failures are logged. They were billed, and on the evidence
    of 2026-08-25 they are disproportionately the interesting ones.
    """
    row = build(status=CallStatus.TRANSPORT_PROBLEM, error=OSError("connection reset"))

    assert row.cost == 3.235e-05
    assert row.generation_id == "gen-1787636121-eAEcEp3BID10rZPfqZgv"


def test_a_call_with_no_response_at_all_records_nulls_not_zeroes():
    row = build(status=CallStatus.TIMEOUT, raw=None, error=TimeoutError())

    assert row.cost is None
    assert row.prompt_tokens is None
    assert row.error_type == "TimeoutError"


# --------------------------------------------------------------------------
# Writing it
# --------------------------------------------------------------------------


def test_the_run_is_written_before_the_first_call(monkeypatch, fake_run):
    """
    `llm_call.run_id` is a foreign key — the one enforced reference in the
    schema — so a call whose run has not landed is rejected outright.
    """
    written = []

    class FakeLog:
        async def record_run(self, run):
            written.append(("run", run.run_id))
            return True

        async def record_call(self, row):
            written.append(("call", row.call_id))
            return True

    monkeypatch.setattr(recorder, "AsyncCallLog", FakeLog)
    asyncio.run(recorder.record_call(build()))
    asyncio.run(recorder.record_call(build()))

    assert written == [("run", RUN_ID), ("call", CALL_ID), ("call", CALL_ID)]


def test_a_run_that_failed_to_write_is_retried_on_the_next_call(monkeypatch, fake_run):
    """
    Otherwise every call in the run fails its foreign key, one after another,
    for a reason that happened once.
    """
    attempts = []

    class FakeLog:
        async def record_run(self, run):
            attempts.append("run")
            return False

        async def record_call(self, row):
            return False

    monkeypatch.setattr(recorder, "AsyncCallLog", FakeLog)
    asyncio.run(recorder.record_call(build()))
    asyncio.run(recorder.record_call(build()))

    assert attempts == ["run", "run"]


# --------------------------------------------------------------------------
# The wrapper
# --------------------------------------------------------------------------


def invoke(runnable, prompt="the prompt", stage="A2", **kwargs):
    return asyncio.run(
        llm_call(runnable, prompt, model_params=MODEL_PARAMS, stage=stage, **kwargs)
    )


class _Parsed:
    """Stands in for a stage's schema instance."""


def test_a_successful_call_writes_one_row_and_returns_the_response(recorded):
    parsed = _Parsed()

    result = invoke(_FakeRunnable(a_payload(parsed=parsed)))

    assert result.value is parsed
    assert len(recorded) == 1
    assert recorded[0].status == "OK"
    assert recorded[0].stage == "A2"


def test_the_call_id_is_visible_to_the_socket_during_the_invocation(recorded):
    """
    The socket sees an HTTP request and nothing else. This contextvar is the
    only thing that lets an attempt row name the call that made it.
    """
    runnable = _FakeRunnable(a_payload(parsed=_Parsed()))

    invoke(runnable)

    assert runnable.seen_context.call_id == recorded[0].call_id
    assert runnable.seen_context.run_id == RUN_ID
    assert current_call() is None


def test_the_case_comes_from_the_caller_not_from_the_stage(recorded):
    """
    The five stage functions take a question and an answer, not a case id.
    Threading one through five signatures to reach a log would put the log into
    the judge's API.
    """
    with case_context("art15_case1"):
        invoke(_FakeRunnable(a_payload(parsed=_Parsed())))

    assert recorded[0].case_id == "art15_case1"


def test_an_unparseable_response_is_logged_and_then_still_raised(recorded):
    """
    Logged **and then** raised: the row is bookkeeping and the exception is the
    judge's business, and nothing above this may be able to tell the log is here.
    """
    payload = a_payload(parsed=None, raw=a_message(content="I cannot answer that."),
                        parsing_error="not valid JSON")

    with pytest.raises(JudgeResponseError):
        invoke(_FakeRunnable(payload))

    assert len(recorded) == 1
    assert recorded[0].status == "STRUCTURE_PROBLEM"
    assert recorded[0].raw_output == "I cannot answer that."
    assert recorded[0].cost == 3.235e-05


def test_a_timeout_is_logged_as_a_timeout_and_re_raised(recorded):
    with pytest.raises(TimeoutError):
        invoke(_FakeRunnable(raises=TimeoutError("no response in 120s")))

    assert recorded[0].status == "TIMEOUT"
    assert recorded[0].error_type == "TimeoutError"


def test_any_other_failure_is_transport(recorded):
    """
    The distinction worth drawing is "we gave up waiting" against "it went
    wrong". Finer categories would be guessing about libraries we do not
    control.
    """
    with pytest.raises(ConnectionError):
        invoke(_FakeRunnable(raises=ConnectionError("reset by peer")))

    assert recorded[0].status == "TRANSPORT_PROBLEM"


def test_a_call_that_returned_nothing_at_all_is_still_recorded(recorded):
    """
    The one failure with no message to read a price off — and the one that must
    not be described as free.
    """
    with pytest.raises(JudgeResponseError):
        invoke(_FakeRunnable(payload=None))

    assert recorded[0].status == "STRUCTURE_PROBLEM"
    assert recorded[0].cost is None


def test_the_timer_measures_the_invocation_and_not_the_write(recorded, monkeypatch):
    """
    Bertan's correction of 2025-08-25. The write costs ~90 ms against a call
    that takes seconds; a per-call latency that included it would be a
    latency-plus-bookkeeping number, and the eval reports it as the model's.
    """
    slow_write_seconds = 0.05

    async def slow_capture(row):
        await asyncio.sleep(slow_write_seconds)
        recorded.append(row)
        return True

    monkeypatch.setattr(recorder, "record_call", slow_capture)
    invoke(_FakeRunnable(a_payload(parsed=_Parsed())))

    assert recorded[0].call_seconds < slow_write_seconds


def test_nothing_is_recorded_and_no_git_is_run_when_the_log_is_off(monkeypatch):
    """
    The default state of a fresh clone. Building a run row shells out to git, so
    a disabled log must not reach `RUN.row()` at all — not merely decline to
    write what it built.
    """
    def explode():
        raise AssertionError("the run row was built with the log disabled")

    monkeypatch.setattr(context_module, "_build_run_row", explode)
    result = invoke(_FakeRunnable(a_payload(parsed=_Parsed())))

    assert result.value is not None
    assert current_call() is None
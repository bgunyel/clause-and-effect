"""
Unit tests for the repository layer. Nothing here connects to anything.

The layer is split so that this is possible: ``statements.py`` builds Core
constructs and never executes them, so **what the log is about to write can be
compiled to a string and read**, which is the only way to check the two
properties that are otherwise invisible until much later —

- **that every UPDATE carries ``updated_at``.** It is applied by SQLAlchemy when
  the *statement* is built, so it is a property of how the statement was
  constructed rather than of the schema. A repository that reached for
  ``text()`` would still pass its own round-trip test while silently leaving the
  column at its insert value; the compiled SQL is where the difference shows.
- **that a cost is bound as a ``Decimal``** and a duration is not.

What is checked live rather than here, on 2026-08-26, because no compiled string
can show it: that ``AUTOCOMMIT`` actually commits (rows read back from a second
connection), that ``updated_at`` actually moves (+2.4s on a real UPDATE while
``created_at`` held), that a cost round-trips exactly, and that
``pending_enrichment`` uses the partial index — ``Index Scan using
ix_llm_attempt_pending_enrichment``, confirmed by ``EXPLAIN``.

Expected values are **literals**. The compiled SQL is asserted against written-out
strings and never against a string built the way the code builds it.
"""
import asyncio
import inspect
import logging
import uuid
from datetime import datetime, timezone
from decimal import Decimal
from types import SimpleNamespace

import pytest
from pydantic import SecretStr
from sqlalchemy.dialects import postgresql

from src.db import engine as engine_module
from src.db.models import LlmAttempt, LlmCall, LlmRun
from src.db.repos import LEDGER, AsyncCallLog, SyncCallLog, WriteLedger, reset_ledger
from src.db.repos import statements

# Same sentinel password as test_db_engine, for the same reason: it appears in
# no other test, so finding it in a log record means redaction did not happen.
FAKE_URL = "postgresql://postgres.abcdefghijkl:hunter2@aws-0-eu-central-2.pooler.supabase.com:5432/postgres"
FAKE_PASSWORD = "hunter2"

RUN_ID = uuid.UUID("11111111-1111-4111-8111-111111111111")
CALL_ID = uuid.UUID("22222222-2222-4222-8222-222222222222")
ATTEMPT_ID = uuid.UUID("33333333-3333-4333-8333-333333333333")
WHEN = datetime(2026, 8, 26, 12, 0, tzinfo=timezone.utc)


def sql(statement) -> str:
    """The statement as Postgres will receive it, parameters left as binds."""
    return str(statement.compile(dialect=postgresql.dialect()))


def a_run(**overrides) -> LlmRun:
    fields = dict(
        run_id=RUN_ID, entry_point="probe_a2_stability.py", commit_sha="c6cf492",
        git_dirty_paths=["docs/todo.md"], started_at=WHEN, hostname="workstation",
    )
    return LlmRun(**{**fields, **overrides})


def a_call(**overrides) -> LlmCall:
    fields = dict(
        call_id=CALL_ID, run_id=RUN_ID, model="deepseek-v4-flash-0731",
        llm_server="openrouter", status="OK", call_seconds=12.5, started_at=WHEN,
        prompt_sha256="d" * 64,
    )
    return LlmCall(**{**fields, **overrides})


def an_attempt(**overrides) -> LlmAttempt:
    fields = dict(
        attempt_id=ATTEMPT_ID, call_id=CALL_ID, seq=1, llm_server="openrouter",
        started_at=WHEN, request_seconds=11.9,
    )
    return LlmAttempt(**{**fields, **overrides})


@pytest.fixture(autouse=True)
def _clean_ledger():
    reset_ledger()
    yield
    reset_ledger()


def resolve(result):
    """
    The result of a repository call, whichever flavour produced it.

    ``AsyncCallLog``'s methods are coroutines and ``SyncCallLog``'s are not, so
    every test below runs against both by awaiting only what needs awaiting.
    That parametrisation is not tidiness: the two classes are written out
    separately on purpose, and a test that exercised one of them would leave the
    other — **the judge path, which is the async one** — covered by nothing.
    Mutation found exactly that: a mutant that made the async ``_write`` re-raise
    instead of counting survived the whole suite.
    """
    if inspect.isawaitable(result):
        return asyncio.run(result)
    return result


@pytest.fixture(params=[SyncCallLog, AsyncCallLog], ids=["sync", "async"])
def enabled_log(request, monkeypatch):
    """
    A repository with the gate forced open and both engines replaced.

    Forcing the gate is the point of the fixture and is safe: the engines it
    would reach are replaced in the same breath, so nothing can leave the
    process. Trap 5 is tested separately, on the unforced gate.
    """
    monkeypatch.setattr(
        engine_module, "get_settings", lambda: SimpleNamespace(DB_URL=SecretStr(FAKE_URL))
    )
    monkeypatch.setattr(engine_module, "_under_pytest", lambda: False)
    return request.param()


class _FakeConnection:
    """Records what the repository asks of a connection, and answers nothing."""

    def __init__(self, calls: list):
        self.calls = calls

    def execution_options(self, **options):
        self.calls.append(options)
        return self

    def execute(self, statement):
        self.calls.append("execute")
        return SimpleNamespace(all=list)

    def __enter__(self):
        return self

    def __exit__(self, *exc_info):
        return False


class _FakeAsyncConnection(_FakeConnection):
    """
    The same, with the awaitables the async API actually returns.

    ``AsyncConnection.execution_options`` is a coroutine function while the
    synchronous one is not, which is the kind of asymmetry that makes one
    flavour work and the other fail at runtime only.
    """

    async def execution_options(self, **options):
        return _FakeConnection.execution_options(self, **options)

    async def execute(self, statement):
        return _FakeConnection.execute(self, statement)

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc_info):
        return False


@pytest.fixture
def recorded_connection(enabled_log, monkeypatch):
    """Replace whichever engine this flavour reaches with one that records."""
    calls: list = []
    is_async = isinstance(enabled_log, AsyncCallLog)
    connection = (_FakeAsyncConnection if is_async else _FakeConnection)(calls)
    engine = SimpleNamespace(connect=lambda: connection)
    monkeypatch.setattr(
        engine_module,
        "get_async_engine" if is_async else "get_sync_engine",
        lambda: engine,
    )
    return calls


# --------------------------------------------------------------------------
# Money
# --------------------------------------------------------------------------


def test_a_float_price_becomes_an_exact_decimal():
    """
    `Decimal(0.1)` is 0.1000000000000000055511151231257827…; `Decimal(str(0.1))`
    is 0.1. The whole reason the column is NUMERIC is that these are summed.
    """
    assert statements.to_money(0.1) == Decimal("0.1")
    assert str(statements.to_money(0.1)) == "0.1"


def test_a_price_of_none_stays_none_and_does_not_become_zero():
    """Null means the provider did not report a price. Zero means it was free."""
    assert statements.to_money(None) is None


def test_a_decimal_price_is_left_alone():
    assert statements.to_money(Decimal("0.00123")) == Decimal("0.00123")


def test_a_cost_is_bound_as_a_decimal_and_a_duration_is_not():
    """
    `Float` subclasses `Numeric` in SQLAlchemy, so the obvious isinstance check
    converts `call_seconds` as well — handing psycopg a Decimal for a double
    precision column, and implying a precision a stopwatch does not have.
    """
    values = statements.values_of(a_call(cost=0.00123))

    assert values[LlmCall.__table__.c.cost] == Decimal("0.00123")
    assert isinstance(values[LlmCall.__table__.c.cost], Decimal)
    assert values[LlmCall.__table__.c.call_seconds] == 12.5
    assert isinstance(values[LlmCall.__table__.c.call_seconds], float)


# --------------------------------------------------------------------------
# Turning a model instance into values
# --------------------------------------------------------------------------


def test_the_metadata_column_is_read_from_its_python_attribute():
    """
    `llm_call.metadata` is mapped as `call_metadata`, but `Column.key` is still
    `metadata` — only the mapper knows about the rename. Iterating the table's
    columns and calling `getattr(row, column.key)` therefore reads SQLAlchemy's
    own `MetaData` object off the class and binds it as a value.
    """
    values = statements.values_of(a_call(call_metadata={"panelist": 3}))

    assert values[LlmCall.__table__.c.metadata] == {"panelist": 3}


def test_unset_columns_are_omitted_so_the_server_defaults_apply():
    """
    `created_at` and `updated_at` are filled by the database. Binding NULL for
    them would override the default with an error, and binding a Python clock
    would stamp rows from several machines against several clocks — the one
    ordering a call log exists to support.
    """
    values = statements.values_of(a_call())

    assert LlmCall.__table__.c.created_at not in values
    assert LlmCall.__table__.c.updated_at not in values
    assert LlmCall.__table__.c.stage not in values


# --------------------------------------------------------------------------
# The statements
# --------------------------------------------------------------------------


def test_a_run_insert_does_nothing_when_the_run_is_already_open():
    """Lazily created by the first call that needs it; every later call conflicts."""
    compiled = sql(statements.insert_run(a_run()))

    assert "INSERT INTO llm_run" in compiled
    assert "ON CONFLICT (run_id) DO NOTHING" in compiled


def test_finishing_a_run_carries_updated_at():
    compiled = sql(statements.finish_run(RUN_ID, WHEN))

    assert "UPDATE llm_run SET" in compiled
    assert "updated_at=now()" in compiled


def test_enriching_an_attempt_carries_updated_at():
    compiled = sql(statements.enrich_attempt(ATTEMPT_ID, enriched_at=WHEN))

    assert "UPDATE llm_attempt SET" in compiled
    assert "updated_at=now()" in compiled


def test_enrichment_always_writes_the_stamp_even_when_it_found_nothing():
    """
    Trap 4. *Not yet swept* and *swept, nothing there* must stay
    distinguishable, or every sweep re-fetches the same permanently-missing
    generations forever.
    """
    compiled = sql(statements.enrich_attempt(ATTEMPT_ID, enriched_at=WHEN))

    assert "enriched_at=" in compiled
    assert "routing_chain=" in compiled


def test_the_call_insert_writes_the_metadata_column_by_its_database_name():
    compiled = sql(statements.insert_call(a_call(call_metadata={"panelist": 3})))

    assert "INSERT INTO llm_call" in compiled
    assert "metadata" in compiled
    assert "call_metadata" not in compiled


def test_the_pending_set_matches_the_partial_index_predicate():
    """
    Written to match `ix_llm_attempt_pending_enrichment` exactly. A partial
    index is only used when the query's WHERE implies the index's, and the
    table only grows — nothing is ever deleted.
    """
    compiled = sql(statements.pending_enrichment("openrouter", limit=10))

    assert "llm_attempt.enriched_at IS NULL" in compiled
    assert "llm_attempt.generation_id IS NOT NULL" in compiled
    assert "llm_attempt.llm_server = " in compiled
    assert "ORDER BY llm_attempt.started_at" in compiled
    assert "LIMIT" in compiled


def test_a_call_without_an_id_is_refused_rather_than_defaulted():
    """
    The column would generate one and the caller would never learn it — fatal
    here, because `call_id` travels in a contextvar to the socket, which writes
    attempt rows against it before the call row exists.
    """
    with pytest.raises(ValueError, match="call_id"):
        statements.insert_call(a_call(call_id=None))

    with pytest.raises(ValueError, match="run_id"):
        statements.insert_call(a_call(run_id=None))

    with pytest.raises(ValueError, match="attempt_id"):
        statements.insert_attempt(an_attempt(attempt_id=None))


def test_an_attempt_without_a_call_id_is_allowed():
    """
    A null `call_id` means a request made outside any wrapper. That is how trap
    8 reports itself instead of hiding, so it must not be refused.
    """
    compiled = sql(statements.insert_attempt(an_attempt(call_id=None)))

    assert "INSERT INTO llm_attempt" in compiled


# --------------------------------------------------------------------------
# The failure policy
# --------------------------------------------------------------------------


def unreachable(monkeypatch, message: str = "connection refused"):
    """Make both engines fail to build, whichever one this flavour reaches."""
    def explode():
        raise OSError(message)

    monkeypatch.setattr(engine_module, "get_sync_engine", explode)
    monkeypatch.setattr(engine_module, "get_async_engine", explode)


@pytest.mark.parametrize("flavour", [SyncCallLog, AsyncCallLog], ids=["sync", "async"])
def test_a_write_under_pytest_is_not_attempted_at_all(flavour):
    """
    Trap 5 at the repository, on the unforced gate — the layer that would do the
    writing, rather than the gate function on its own.
    """
    assert resolve(flavour().record_call(a_call())) is False
    assert LEDGER.attempted == 0


def test_an_unreachable_database_costs_a_row_and_not_the_run(enabled_log, monkeypatch):
    """Design §Failure policy rule 1: catch, do not raise into a judged call."""
    unreachable(monkeypatch)

    assert resolve(enabled_log.record_call(a_call())) is False
    assert LEDGER.failed == 1
    assert LEDGER.written == 0


def test_a_failed_write_is_counted_and_reported(enabled_log, monkeypatch, caplog):
    """Rule 2: never silent. The count is what an entry point reports."""
    unreachable(monkeypatch)
    with caplog.at_level(logging.WARNING):
        resolve(enabled_log.record_call(a_call()))

    assert "Call log write failed" in caplog.text
    assert "1 of 1 writes landed" not in LEDGER.report()
    assert "1 failed" in LEDGER.report()


def test_every_write_method_absorbs_a_failure(enabled_log, monkeypatch):
    """
    All of them, not just ``record_call``. Each method is one line, and one line
    is exactly what gets written without the ``try`` around it.
    """
    unreachable(monkeypatch)

    assert resolve(enabled_log.record_run(a_run())) is False
    assert resolve(enabled_log.finish_run(RUN_ID, WHEN)) is False
    assert resolve(enabled_log.record_call(a_call())) is False
    assert resolve(enabled_log.record_attempt(an_attempt())) is False
    assert resolve(enabled_log.pending_enrichment("openrouter", limit=10)) == []
    assert resolve(enabled_log.enrich_attempts(
        [{"attempt_id": ATTEMPT_ID, "enriched_at": WHEN}]
    )) == 0
    assert LEDGER.failed == 6


def test_the_password_never_reaches_a_log_record(enabled_log, monkeypatch, caplog):
    """
    Trap 6. Driver connection errors quote the DSN they failed on, and the
    failure is unrecoverable once written: it is in the log file whether or not
    it is in the code.
    """
    unreachable(monkeypatch, f"could not connect using {FAKE_URL}")
    with caplog.at_level(logging.WARNING):
        resolve(enabled_log.record_call(a_call()))

    assert FAKE_PASSWORD not in caplog.text
    assert "aws-0-eu-central-2.pooler.supabase.com:5432/postgres" in caplog.text


def test_a_caller_bug_is_a_missed_row_rather_than_a_crash(enabled_log):
    """
    A missing id raises out of the statement builder. The executor catches it
    like any other failure, so a bug in the wrapper costs the row it was
    writing rather than the judged run around it.

    This is the test that found the builders being called *outside* the ``try``,
    which made a caller's bug the one exception the failure policy let through.
    """
    assert resolve(enabled_log.record_call(a_call(call_id=None))) is False
    assert LEDGER.failures == {"ValueError": 1}


def test_a_single_row_write_asks_for_autocommit(enabled_log, recorded_connection):
    """
    141 ms against 48 ms, measured — SQLAlchemy otherwise wraps one statement in
    an implicit transaction and spends three round trips delivering it.

    **This pins the request, not the effect.** That AUTOCOMMIT actually commits
    was checked against the live instance on 2026-08-26, by reading the rows
    back from a second connection; no compiled statement can show it, and a
    mutant that deleted this option survived every other test in this file.
    """
    assert resolve(enabled_log.record_call(a_call())) is True

    assert {"isolation_level": "AUTOCOMMIT"} in recorded_connection
    assert "execute" in recorded_connection


# --------------------------------------------------------------------------
# The ledger
# --------------------------------------------------------------------------


def test_repeated_failures_of_one_kind_are_logged_once(caplog):
    """
    An unreachable database fails every write in the run. 150 identical warnings
    would bury the findings the run exists to produce; the total is the number
    that matters, and it is in the report.
    """
    ledger = WriteLedger()
    with caplog.at_level(logging.WARNING):
        for _ in range(5):
            ledger.record_failed(OSError("refused"), what="call", where="host:5432/db")

    assert caplog.text.count("Call log write failed") == 1
    assert "5× OSError" in ledger.report()


def test_a_second_kind_of_failure_is_logged_too(caplog):
    ledger = WriteLedger()
    with caplog.at_level(logging.WARNING):
        ledger.record_failed(OSError("refused"), what="call", where="host:5432/db")
        ledger.record_failed(ValueError("bad id"), what="call", where="host:5432/db")

    assert caplog.text.count("Call log write failed") == 2


def test_a_run_that_wrote_nothing_does_not_report_success():
    """"0 of 0 writes landed" reads as success to someone skimming."""
    assert WriteLedger().report() == "Call log: nothing was written (no writes were attempted)."


def test_the_report_counts_what_landed():
    ledger = WriteLedger()
    for _ in range(3):
        ledger.record_written()

    assert ledger.report() == "Call log: 3 of 3 writes landed."


def test_resetting_the_ledger_keeps_the_same_object():
    """
    Rebinding the module global would leave every `from ledger import LEDGER`
    counting into the old object while the report read the new one — a run
    reporting zero writes having made hundreds.
    """
    before = LEDGER
    LEDGER.record_written()
    reset_ledger()

    assert LEDGER is before
    assert LEDGER.written == 0
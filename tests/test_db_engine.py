"""
Unit tests for the call log's engines and its ``DB_URL`` gate.

**Nothing here connects to anything.** SQLAlchemy builds an engine lazily — no
socket is opened until a connection is checked out — so the connection
parameters can be asserted against a fabricated URL, hermetically, which is the
only way to test them without writing to the record the log exists to be.

Three things are pinned, and they fail in different ways:

- **The gate** (:func:`is_enabled`). Trap 5. The failure is invisible: a suite
  that writes to the production log leaves fixture rows nobody notices until
  they read the table.
- **Redaction** (:func:`safe_target`, ``redact``). Trap 6. The failure is a
  password in a log line, and it is unrecoverable once it has been written
  somewhere.
- **The connection parameters.** The failure is slow rather than loud — a
  missing statement timeout is invisible until the day a query hangs, and a
  wrong pool size is invisible always.

Every expected value below is written as a **literal**, never derived from the
module under test. ``POOL_SIZE`` is asserted as ``5``, not as
``engine.POOL_SIZE``; the statement timeout as ``"10000"``, not as
``str(STATEMENT_TIMEOUT_SECONDS * 1000)``. A test that computes its expectation
the way the code does passes for any value both agree on, including a wrong
one — three such tests were found by mutation in one week of this project.
"""
import asyncio
import sys
from types import SimpleNamespace

import pytest
from pydantic import SecretStr

from src.db import engine as engine_module
from src.db.engine import (
    engine_url,
    get_async_engine,
    get_sync_engine,
    is_enabled,
    safe_target,
    warm_up_async,
    warm_up_sync,
)

# A URL with the shape of the real one — Supabase's session pooler on 5432,
# a dotted username, a password that is a recognisable sentinel — and pointing
# nowhere. `hunter2` appears in no other test and is what redaction is checked
# against.
FAKE_URL = "postgresql://postgres.abcdefghijkl:hunter2@aws-0-eu-central-2.pooler.supabase.com:5432/postgres"
FAKE_PASSWORD = "hunter2"


@pytest.fixture(autouse=True)
def _reset_engines():
    """
    Clear the module's cached engines around every test.

    The engines are process-wide singletons by design. Without this a test that
    builds one with the fake URL would hand it to every test that follows, and
    the suite would pass or fail depending on its own ordering.
    """
    engine_module._async_engine = None
    engine_module._sync_engine = None
    yield
    engine_module._async_engine = None
    engine_module._sync_engine = None


@pytest.fixture
def db_url(monkeypatch):
    """Point the module at the fake URL, whatever the machine's .env says."""

    def _set(raw: str = FAKE_URL):
        monkeypatch.setattr(
            engine_module,
            "get_settings",
            lambda: SimpleNamespace(DB_URL=SecretStr(raw)),
        )

    return _set


# --------------------------------------------------------------------------
# The gate — trap 5
# --------------------------------------------------------------------------


def test_the_log_is_disabled_under_pytest_even_with_a_url_configured(db_url):
    """
    The one that matters. A developer's .env carries a real DB_URL, so the
    empty-string default does not make this suite hermetic on their machine;
    the pytest guard does.
    """
    db_url()
    assert is_enabled() is False


def test_the_gate_is_open_when_a_url_is_set_and_this_is_not_a_test_run(
    db_url, monkeypatch
):
    """
    The guard above must not be the *only* reason the gate is shut, or it would
    hide a broken gate: a `return False` at the top of `is_enabled` would pass
    every other test in this file.
    """
    db_url()
    monkeypatch.setattr(engine_module, "_under_pytest", lambda: False)
    assert is_enabled() is True


@pytest.mark.parametrize("raw", ["", "   "])
def test_an_absent_url_shuts_the_gate(db_url, monkeypatch, raw):
    db_url(raw)
    monkeypatch.setattr(engine_module, "_under_pytest", lambda: False)
    assert is_enabled() is False


def test_the_pytest_guard_reads_the_imported_module_not_an_environment_variable():
    """
    Pinned because the tempting implementation — `"PYTEST_CURRENT_TEST" in
    os.environ` — is set only *during a test*, so it is absent at import time
    and absent in fixtures at session scope.
    """
    assert "pytest" in sys.modules
    assert engine_module._under_pytest() is True


def test_a_write_helper_declines_when_the_log_is_disabled(db_url):
    """
    `warm_up_sync` must *decline*, not attempt and fail.

    The `False` alone does not say which happened: an ungated version would
    build an engine, fail to reach a host that does not exist, catch that, log
    it and return `False` too. So the assertion is that no engine was ever
    built — the one observable that separates the two. Found by mutation: the
    gate could be removed entirely and a return-value-only test still passed.
    """
    db_url()
    assert warm_up_sync() is False
    assert engine_module._sync_engine is None


def test_the_async_warm_up_declines_on_the_same_terms(db_url):
    """Same assertion on the judge path, which is the one that runs 150 times."""
    db_url()
    assert asyncio.run(warm_up_async()) is False
    assert engine_module._async_engine is None


# --------------------------------------------------------------------------
# Redaction — trap 6
# --------------------------------------------------------------------------


def test_safe_target_names_the_host_and_database_and_not_the_credentials(db_url):
    db_url()
    assert safe_target() == "aws-0-eu-central-2.pooler.supabase.com:5432/postgres"


def test_safe_target_leaks_neither_the_password_nor_the_username(db_url):
    db_url()
    target = safe_target()
    assert FAKE_PASSWORD not in target
    assert "postgres.abcdefghijkl" not in target


def test_safe_target_survives_an_unparseable_url(db_url):
    """
    It is called from exception handlers. One that raises would replace the
    error it was reporting with its own.
    """
    db_url("not a url at all")
    assert safe_target() == "<unparseable DB_URL>"


def test_safe_target_survives_an_absent_url(db_url):
    db_url("")
    assert safe_target() == "<no DB_URL>"


def testredact_removes_the_password_from_a_driver_error(db_url):
    db_url()
    message = f'connection to server failed: password "{FAKE_PASSWORD}" rejected'
    redacted = engine_module.redact(message)
    assert FAKE_PASSWORD not in redacted
    assert "***" in redacted


def testredact_removes_a_whole_dsn_quoted_back_at_us(db_url):
    db_url()
    redacted = engine_module.redact(f"could not translate host name in {FAKE_URL}")
    assert FAKE_PASSWORD not in redacted
    assert "<DB_URL>" in redacted


def testredact_accepts_an_exception_rather_than_a_string(db_url):
    """It is called as `redact(exc)`, not `redact(str(exc))`."""
    db_url()
    redacted = engine_module.redact(RuntimeError(f"auth failed for {FAKE_URL}"))
    assert FAKE_PASSWORD not in redacted


def testredact_leaves_an_unrelated_message_alone(db_url):
    db_url()
    assert engine_module.redact("connection timed out") == "connection timed out"


# --------------------------------------------------------------------------
# URL rewriting
# --------------------------------------------------------------------------


def test_the_async_engine_speaks_asyncpg():
    assert engine_url(FAKE_URL, "postgresql+asyncpg").drivername == "postgresql+asyncpg"


def test_the_sync_engine_speaks_psycopg():
    assert engine_url(FAKE_URL, "postgresql+psycopg").drivername == "postgresql+psycopg"


def test_rewriting_the_driver_changes_nothing_else():
    """
    The URL carries the credentials and the pooler's host and port. A rewrite
    that dropped the port would silently move us onto 6543 — the transaction
    pooler — where asyncpg's prepared statements break intermittently.
    """
    rewritten = engine_url(FAKE_URL, "postgresql+asyncpg")
    assert rewritten.host == "aws-0-eu-central-2.pooler.supabase.com"
    assert rewritten.port == 5432
    assert rewritten.database == "postgres"
    assert rewritten.username == "postgres.abcdefghijkl"
    assert rewritten.password == FAKE_PASSWORD


# --------------------------------------------------------------------------
# Connection parameters — design decision 20
# --------------------------------------------------------------------------


def test_building_an_engine_without_a_url_is_an_error_not_a_silent_no_op(db_url):
    db_url("")
    with pytest.raises(RuntimeError):
        get_async_engine()


def test_the_async_engine_is_built_once(db_url):
    db_url()
    assert get_async_engine() is get_async_engine()


def test_the_sync_engine_is_built_once(db_url):
    db_url()
    assert get_sync_engine() is get_sync_engine()


def test_the_two_engines_are_different_engines(db_url):
    """
    One URL, two drivers. They are separate because an asyncpg connection is
    bound to the loop that opened it, so the synchronous path cannot share the
    async pool.
    """
    db_url()
    assert get_async_engine().url.drivername == "postgresql+asyncpg"
    assert get_sync_engine().url.drivername == "postgresql+psycopg"


def test_the_async_pool_is_sized_as_decided(db_url):
    db_url()
    pool = get_async_engine().pool
    assert pool.size() == 5
    assert pool._max_overflow == 5
    assert pool._recycle == 300
    assert pool._timeout == 10
    assert pool._pre_ping is True


def test_the_sync_pool_is_sized_as_decided(db_url):
    db_url()
    pool = get_sync_engine().pool
    assert pool.size() == 5
    assert pool._max_overflow == 5
    assert pool._recycle == 300
    assert pool._timeout == 10
    assert pool._pre_ping is True


def test_disposing_clears_the_cached_async_engine(db_url):
    """
    Session mode holds a pooler connection until it is released, and the pooler
    is shared and finite. An engine left cached after disposal would be handed
    to the next caller with a closed pool behind it.
    """
    db_url()
    get_async_engine()
    assert engine_module._async_engine is not None
    asyncio.run(engine_module.dispose_async())
    assert engine_module._async_engine is None


def test_disposing_clears_the_cached_sync_engine(db_url):
    db_url()
    get_sync_engine()
    assert engine_module._sync_engine is not None
    engine_module.dispose_sync()
    assert engine_module._sync_engine is None


def test_disposing_when_nothing_was_built_is_a_no_op():
    """Called at exit, including from runs that never wrote anything."""
    asyncio.run(engine_module.dispose_async())
    engine_module.dispose_sync()


def _captured_kwargs(monkeypatch, factory_name: str) -> dict:
    """
    Capture the keyword arguments the module hands its engine factory.

    ``connect_args`` cannot be read back off a built engine: SQLAlchemy merges
    it with the URL's own parameters at build time and keeps the result inside
    the pool creator's closure, reachable only by positional index into
    ``__closure__``. Asserting on the call is the stable way to pin what we
    send. The pool tests above cover the other direction — that the kwargs
    reach a real engine and take effect.
    """
    captured: dict = {"listeners": []}

    def _fake(url, **kwargs):
        captured["url"] = url
        captured.update(kwargs)
        # `sync_engine` because the async builder registers its connect
        # listener against it rather than against the AsyncEngine facade.
        return SimpleNamespace(url=url, sync_engine=SimpleNamespace(url=url))

    monkeypatch.setattr(engine_module, factory_name, _fake)
    # A fabricated engine is not a valid event target, and the registration is
    # asserted from this journal instead.
    monkeypatch.setattr(
        engine_module.event,
        "listen",
        lambda target, identifier, fn: captured["listeners"].append((identifier, fn)),
    )
    return captured


def test_asyncpg_gets_a_client_side_connect_timeout(db_url, monkeypatch):
    """
    The connect timeout is what makes the failure policy achievable: an
    unreachable database has to produce a skipped write rather than a stalled
    run. It is client-side, so unlike the GUCs it survives the pooler.
    """
    captured = _captured_kwargs(monkeypatch, "create_async_engine")
    db_url()
    get_async_engine()

    assert captured["connect_args"]["timeout"] == 10.0


def test_psycopg_gets_the_same_connect_timeout_by_its_own_spelling(
    db_url, monkeypatch
):
    captured = _captured_kwargs(monkeypatch, "create_engine")
    db_url()
    get_sync_engine()

    assert captured["connect_args"]["connect_timeout"] == 10


@pytest.mark.parametrize(
    "factory,builder",
    [("create_async_engine", get_async_engine), ("create_engine", get_sync_engine)],
)
def test_the_gucs_do_not_travel_as_startup_parameters(
    db_url, monkeypatch, factory, builder
):
    """
    Measured 2026-08-26 against the live instance: Supabase's pooler swallows
    startup parameters. With the timeout in asyncpg's `server_settings`,
    `current_setting('statement_timeout')` read back `2min` and
    `SELECT pg_sleep(30)` ran to completion — decision 20 quietly not in force.

    Pinned as an absence because the two spellings are the obvious thing to
    reach for, and putting one back would look like a fix while changing
    nothing that reaches the server.
    """
    captured = _captured_kwargs(monkeypatch, factory)
    db_url()
    builder()

    args = captured["connect_args"]
    assert "server_settings" not in args
    assert "options" not in args


def test_the_session_settings_are_the_two_the_design_decided():
    """
    Literals, and in a form Postgres accepts. `statement_timeout` takes an
    interval or a bare integer meaning **milliseconds** — `SET statement_timeout
    = 10` would mean ten milliseconds and time out every query rather than none.
    """
    assert engine_module.SESSION_SETTINGS == (
        "SET statement_timeout = '10s'",
        "SET application_name = 'clause-and-effect'",
    )


class _FakeCursor:
    def __init__(self, journal):
        self._journal = journal

    def execute(self, statement):
        self._journal.append(("execute", statement))

    def close(self):
        self._journal.append(("close", None))


class _FakeConnection:
    def __init__(self):
        self.journal = []

    def cursor(self):
        return _FakeCursor(self.journal)

    def commit(self):
        self.journal.append(("commit", None))


def test_the_session_settings_are_committed_after_being_set():
    """
    **The commit is the finding, not a formality.** Both drivers open an
    implicit transaction for these statements and neither ends it, so without a
    commit the settings read back correctly on first use and revert to the
    server defaults after the connection makes one round trip through the pool.
    Measured both ways against the live instance.

    Order matters as much as presence: a commit before the statements would
    leave them in the same uncommitted transaction they started in.
    """
    conn = _FakeConnection()
    engine_module._apply_session_settings(conn, None)

    assert conn.journal == [
        ("execute", "SET statement_timeout = '10s'"),
        ("execute", "SET application_name = 'clause-and-effect'"),
        ("close", None),
        ("commit", None),
    ]


def test_a_failing_statement_still_closes_the_cursor():
    """A leaked cursor on a pooled connection outlives the failure that made it."""

    class _Exploding(_FakeConnection):
        def cursor(self):
            journal = self.journal

            class _C(_FakeCursor):
                def execute(self, statement):
                    journal.append(("execute", statement))
                    raise RuntimeError("permission denied")

            return _C(journal)

    conn = _Exploding()
    with pytest.raises(RuntimeError):
        engine_module._apply_session_settings(conn, None)
    assert ("close", None) in conn.journal


@pytest.mark.parametrize(
    "factory,builder",
    [("create_async_engine", get_async_engine), ("create_engine", get_sync_engine)],
)
def test_both_engines_register_the_session_settings_on_connect(
    db_url, monkeypatch, factory, builder
):
    """
    The settings are useless if nothing calls them, and an engine that skips the
    registration fails in the quietest possible way — every query runs under the
    server's two-minute default and nothing says so.
    """
    captured = _captured_kwargs(monkeypatch, factory)
    db_url()
    builder()

    assert ("connect", engine_module._apply_session_settings) in captured["listeners"]


def test_neither_engine_disables_the_prepared_statement_cache(db_url, monkeypatch):
    """
    The session pooler on 5432 supports prepared statements, which is why it was
    chosen. A `statement_cache_size=0` workaround here would be the transaction
    pooler's fix applied to the wrong port, and it would cost throughput
    silently.
    """
    captured = _captured_kwargs(monkeypatch, "create_async_engine")
    db_url()
    get_async_engine()

    args = captured["connect_args"]
    assert "statement_cache_size" not in args
    assert "prepared_statement_cache_size" not in args
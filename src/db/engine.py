"""
Engines, session factories, and the ``DB_URL`` gate.

One URL, two engines, and the reason is not symmetry. An asyncpg connection is
bound to the event loop that opened it, so a synchronous caller cannot borrow
the async pool by wrapping each write in ``asyncio.run()`` — the second call
would find the pool holding connections belonging to a loop that has closed.
The judge path is ``async`` (every probe is a single ``asyncio.run(main())``)
and gets asyncpg; the product path is synchronous (``generator.py:83,99``,
``ComplianceAgent.ask()``) and gets psycopg. **Only one of them is ever built in
a given process**, because both are built lazily and no entry point today mixes
the two.

The alternative — one engine on a dedicated background loop, with synchronous
callers blocking on ``run_coroutine_threadsafe`` — was considered and not taken.
It saves a dependency and costs a thread whose shutdown has to be right.

**Nothing here decides whether a failure is fatal.** These functions build,
connect and report; the failure policy of design §Failure policy — catch, never
raise into a judged call, never fail silently — belongs to the repository layer
above. What this module guarantees is that the failure arrives *fast*, which is
what makes that policy achievable: every timeout below exists so that an
unreachable database produces a skipped write rather than a stalled run.

The timeouts and pool sizes are design decision 20, restated here so the
numbers have their reasons attached rather than looking arbitrary:

- **Connect 10s, not 5.** A scale-to-zero Supabase instance takes seconds to
  wake, and a 5-second budget turns a cold start into a failed write.
- **Statement 10s**, set as a server-side GUC rather than a client-side
  cancel, so the server stops working on it too — but applied **after** the
  connection is open rather than as a startup parameter, because the pooler
  swallows startup parameters. See :data:`SESSION_SETTINGS`.
- **Pool 5 + 5 overflow, not ``NullPool``.** In the *session* pooler on 5432 a
  pooler connection is held for the session's duration, so opening and closing
  one per write is the expensive option — the opposite of the advice that
  applies to the transaction pooler on 6543. That port choice is also why no
  ``statement_cache_size=0`` workaround appears here: session mode supports
  prepared statements, so asyncpg runs with its defaults.
- **``pool_timeout`` 10s**, down from SQLAlchemy's default of 30. An exhausted
  pool is a stalled write, and a write that must not stall a run may not wait
  three times longer than the query it is waiting to make.
- **``pool_pre_ping`` and ``pool_recycle`` 300s**, because a serverless host
  drops idle connections and a stale one surfaces as a failed write rather
  than as a reconnect.

**The round trip, measured 2026-08-26** against the live instance from this
machine, ``aws-0-eu-central-2``. The design quotes 0.012 ms median for a local
SQLite row as the *shape* of an argument and explicitly not as a stand-in for
this; the real figure is four orders of magnitude larger, and how it is spent
turns out to matter more than the network:

| one statement, connection already open        |  47 ms | 1 round trip  |
| checkout + statement, implicit BEGIN/ROLLBACK | 141 ms | 3 round trips |
| checkout + statement, ``AUTOCOMMIT``          |  48 ms | 1 round trip  |
| checkout + statement, ``AUTOCOMMIT`` + pre-ping| 202 ms | ~4 round trips |

Two consequences for the layer above, neither of which this module decides.
**A single-row insert wrapped in an implicit transaction costs three round
trips for one statement** — so a repository writing one row should say
``AUTOCOMMIT`` and a repository writing a call plus its attempts should batch
them into one transaction, and the difference between those two is 100 ms per
call. **``pool_pre_ping`` costs about 155 ms per checkout here**, which over a
150-call stability sample is around 23 seconds of wall clock buying protection
against a stale connection. That trade was decided (decision 20) before the
number existed; the number is recorded here so it can be revisited on evidence.

Trap 6: **``DB_URL`` is a secret and contains a password.** It is never logged.
Every message here names :func:`safe_target` — host, port and database — and
every exception is passed through :func:`redact` before it reaches a log line,
because connection errors are fond of quoting the DSN they failed on.
"""
from __future__ import annotations

import logging
import sys
import threading
import time
from typing import TYPE_CHECKING

from sqlalchemy import create_engine, event, text
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker, create_async_engine
from sqlalchemy.orm import sessionmaker

from src.config import get_settings

if TYPE_CHECKING:
    from sqlalchemy.engine import Engine, URL
    from sqlalchemy.ext.asyncio import AsyncSession
    from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

# The two dialects the one URL is rewritten into. `DB_URL` is stored with a
# bare `postgresql://` scheme so it stays a valid DSN for psql and for
# Supabase's own tooling; the driver is our business, not the URL's.
ASYNC_DRIVER = "postgresql+asyncpg"
SYNC_DRIVER = "postgresql+psycopg"

# Design decision 20. See the module docstring for why each one is what it is.
POOL_SIZE = 5
MAX_OVERFLOW = 5
POOL_RECYCLE_SECONDS = 300
POOL_TIMEOUT_SECONDS = 10
CONNECT_TIMEOUT_SECONDS = 10
STATEMENT_TIMEOUT_SECONDS = 10

# Stamped on every connection so a session on the Supabase dashboard can be
# traced back to this repository rather than showing up as an anonymous client.
APPLICATION_NAME = "clause-and-effect"

_lock = threading.Lock()
_async_engine: AsyncEngine | None = None
_sync_engine: Engine | None = None


# Applied after every connection is opened. **Not** sent as startup parameters —
# `asyncpg`'s `server_settings` and psycopg's `options` both reach Supabase's
# pooler and go no further. Measured 2026-08-26 against the live instance: with
# the timeout in `server_settings`, `current_setting('statement_timeout')` read
# back `2min` (the project default) and `application_name` read back
# `Supavisor`, and `SELECT pg_sleep(30)` ran to completion. Decision 20 was
# quietly not in force.
SESSION_SETTINGS = (
    f"SET statement_timeout = '{STATEMENT_TIMEOUT_SECONDS}s'",
    f"SET application_name = '{APPLICATION_NAME}'",
)


def _apply_session_settings(dbapi_connection, _connection_record) -> None:
    """
    Set the session GUCs on a freshly opened connection, and commit them.

    **The commit is the whole point and it is not decoration.** Both drivers
    open an implicit transaction for these statements and neither ends it, so
    the settings live in a transaction that is never committed: measured, they
    read back correctly on the first use of the connection and revert to the
    server defaults the moment it goes back to the pool and comes out again.
    With the commit they survive — checked by reading them back after a pool
    round trip, not by assuming.

    ``pool_reset_on_return`` is not the cause and turning it off does not help;
    the same reversion happens with it disabled.
    """
    cursor = dbapi_connection.cursor()
    try:
        for statement in SESSION_SETTINGS:
            cursor.execute(statement)
    finally:
        cursor.close()
    dbapi_connection.commit()


def engine_url(raw: str, driver: str) -> URL:
    """
    Rewrite ``raw`` onto ``driver``, keeping everything else untouched.

    Pure, and separated from :func:`get_settings` on purpose: it is the one
    piece of this module a hermetic test can exercise directly, without an
    environment and without a connection.
    """
    return make_url(raw).set(drivername=driver)


def _under_pytest() -> bool:
    """
    Whether this process is a test run.

    **Trap 5 is not covered by the empty ``DB_URL`` default on this machine.**
    The design argues the suite is hermetic by construction because ``DB_URL``
    defaults to empty — but ``Settings`` reads the repository's ``.env``, and on
    a developer's machine that file has a real URL in it. Under that default
    alone, a test that touched the log would write to the production record it
    exists to verify, and nothing would say so until someone read the table and
    found fixture rows in it.

    So the guard is structural rather than a fixture: a test run cannot be
    enabled, whatever the environment says. Putting test-awareness in
    non-test code is a smell and it is taken deliberately, because the
    alternative is hermeticity that depends on every future test remembering to
    unset something — which is exactly the arrangement the design rejected.

    If integration tests against a scratch database are ever wanted, this is the
    one line to revisit, and revisiting it should be a deliberate change with
    its own review rather than an environment variable anybody can set.
    """
    return "pytest" in sys.modules


def is_enabled() -> bool:
    """
    Whether the call log should write at all.

    Absent ``DB_URL`` is the default and means *do not write*: a fresh clone
    runs the whole pipeline with no infrastructure, and no entry point has to
    opt out of logging.
    """
    if _under_pytest():
        return False
    return bool(get_settings().DB_URL.get_secret_value().strip())


def raw_url() -> str:
    """
    The configured ``DB_URL``, stripped. Empty string when there is none.

    Public because the migration environment reads it too, and one function
    means one answer to "is a URL configured?" — the stripping in particular,
    without which a ``DB_URL`` holding a stray newline would be absent here and
    present to Alembic. What is deliberately *not* shared is the reaction to it
    being empty: :func:`_require_url` says the call log's writes were not gated,
    which is not what a migration run needs to hear.
    """
    return get_settings().DB_URL.get_secret_value().strip()


def safe_target() -> str:
    """
    ``host:port/database`` — the only form of the URL that may be logged.

    Returns a placeholder rather than raising when there is nothing to describe,
    since this is called from failure paths and a logging helper that throws
    inside an exception handler replaces the error it was reporting.
    """
    raw = raw_url()
    if not raw:
        return "<no DB_URL>"
    try:
        url = make_url(raw)
    except Exception:
        return "<unparseable DB_URL>"
    return f"{url.host}:{url.port}/{url.database}"


def redact(message: object) -> str:
    """
    Strip the password, and the URL carrying it, out of ``message``.

    Trap 6. Driver-level connection errors quote the DSN they failed on, and a
    ``SecretStr`` protects the value in *our* code without protecting it in a
    library's exception text. Applied to every exception this module logs, and
    public because the repository layer logs the same class of exception from
    the same driver — a second implementation there would be a second thing to
    get right, and this one is the tested one.
    """
    text_out = str(message)
    raw = raw_url()
    if not raw:
        return text_out
    if raw in text_out:
        text_out = text_out.replace(raw, "<DB_URL>")
    try:
        password = make_url(raw).password
    except Exception:
        password = None
    if password:
        text_out = text_out.replace(password, "***")
    return text_out


def get_async_engine() -> AsyncEngine:
    """
    The asyncpg engine, built once per process on first use.

    Raises if ``DB_URL`` is absent — callers gate on :func:`is_enabled` first.
    That is deliberate: "no database configured" is a state the caller must
    already have handled, so reaching here without one is a bug, not a
    condition to be absorbed.
    """
    global _async_engine
    # The lock is taken on every call rather than guarded by a fast path. A
    # double-checked lock would make the two checks individually redundant and
    # therefore individually untestable — mutation-verified: removing either one
    # alone changes nothing observable. An uncontended lock costs tens of
    # nanoseconds in front of a write that crosses the Atlantic.
    with _lock:
        if _async_engine is None:
            _async_engine = create_async_engine(
                engine_url(_require_url(), ASYNC_DRIVER),
                pool_size=POOL_SIZE,
                max_overflow=MAX_OVERFLOW,
                pool_pre_ping=True,
                pool_recycle=POOL_RECYCLE_SECONDS,
                pool_timeout=POOL_TIMEOUT_SECONDS,
                connect_args={
                    # asyncpg spells the connect timeout `timeout`. It is
                    # client-side, so unlike the GUCs it survives the pooler.
                    # `server_settings` deliberately absent — see
                    # SESSION_SETTINGS.
                    "timeout": float(CONNECT_TIMEOUT_SECONDS),
                },
            )
            event.listen(
                _async_engine.sync_engine, "connect", _apply_session_settings
            )
    return _async_engine


def get_sync_engine() -> Engine:
    """The psycopg engine, built once per process on first use."""
    global _sync_engine
    with _lock:  # See get_async_engine for why there is no fast path.
        if _sync_engine is None:
            _sync_engine = create_engine(
                engine_url(_require_url(), SYNC_DRIVER),
                pool_size=POOL_SIZE,
                max_overflow=MAX_OVERFLOW,
                pool_pre_ping=True,
                pool_recycle=POOL_RECYCLE_SECONDS,
                pool_timeout=POOL_TIMEOUT_SECONDS,
                connect_args={
                    # A libpq keyword, handled client-side. The GUCs that would
                    # travel here as `options="-c ..."` are set after connect
                    # instead — see SESSION_SETTINGS.
                    "connect_timeout": CONNECT_TIMEOUT_SECONDS,
                },
            )
            event.listen(_sync_engine, "connect", _apply_session_settings)
    return _sync_engine


def _require_url() -> str:
    raw = raw_url()
    if not raw:
        raise RuntimeError(
            "DB_URL is not set. Call log writes must be gated on is_enabled()."
        )
    return raw


def get_async_sessionmaker() -> async_sessionmaker[AsyncSession]:
    """
    Session factory for the judge path.

    ``expire_on_commit=False`` because a repository returns the row it wrote and
    the caller may read its id afterwards; the default would make that a second
    round trip to a remote database for a value we already have.
    """
    return async_sessionmaker(get_async_engine(), expire_on_commit=False)


def get_sync_sessionmaker() -> sessionmaker[Session]:
    """Session factory for the product path. Same reasoning as the async one."""
    return sessionmaker(get_sync_engine(), expire_on_commit=False)


async def warm_up_async() -> bool:
    """
    Open one connection before the first judged call, and report the round trip.

    Design §Storage: the cold start is paid here rather than inside the first
    call being timed. Returns whether the log is usable, and **never raises** —
    an unreachable database costs rows, not a run. An entry point that would
    rather stop than run unlogged can act on the ``False``.
    """
    if not is_enabled():
        return False
    started = time.perf_counter()
    try:
        async with get_async_engine().connect() as conn:
            await conn.execute(text("SELECT 1"))
    except Exception as exc:
        logger.warning(
            "Call log unreachable at %s — writes will be skipped (%s: %s)",
            safe_target(),
            type(exc).__name__,
            redact(exc),
        )
        return False
    elapsed_ms = (time.perf_counter() - started) * 1000
    logger.info(
        "Call log connected to %s in %.0f ms (asyncpg)", safe_target(), elapsed_ms
    )
    return True


def warm_up_sync() -> bool:
    """Synchronous counterpart of :func:`warm_up_async`, for the product path."""
    if not is_enabled():
        return False
    started = time.perf_counter()
    try:
        with get_sync_engine().connect() as conn:
            conn.execute(text("SELECT 1"))
    except Exception as exc:
        logger.warning(
            "Call log unreachable at %s — writes will be skipped (%s: %s)",
            safe_target(),
            type(exc).__name__,
            redact(exc),
        )
        return False
    elapsed_ms = (time.perf_counter() - started) * 1000
    logger.info(
        "Call log connected to %s in %.0f ms (psycopg)", safe_target(), elapsed_ms
    )
    return True


async def dispose_async() -> None:
    """
    Return the async pool's connections. Safe to call when nothing was built.

    Worth calling at exit: in *session* mode a pooler connection is held until
    it is released, so a process that leaves without disposing keeps occupying
    slots on a shared, finite pooler.
    """
    global _async_engine
    with _lock:
        engine, _async_engine = _async_engine, None
    if engine is not None:
        await engine.dispose()


def dispose_sync() -> None:
    """Synchronous counterpart of :func:`dispose_async`."""
    global _sync_engine
    with _lock:
        engine, _sync_engine = _sync_engine, None
    if engine is not None:
        engine.dispose()
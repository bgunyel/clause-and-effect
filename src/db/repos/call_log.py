"""
The repository the rest of the code talks to. Two flavours, one set of rules.

``AsyncCallLog`` serves the judge path and ``SyncCallLog`` the product path,
because an asyncpg connection is bound to the event loop that opened it and only
one of the two engines is ever built in a given process (see
:mod:`src.db.engine`). The two classes are deliberately parallel and the
duplication is deliberate: the bodies differ only by ``await``, and the
alternatives — a shared base with a hook per statement, or one class branching
on a flag — both hide which path a reader is on, in a layer whose whole purpose
is that a failure on one path must not reach the other.

**Nothing here raises.** Design §Failure policy: a logging failure must never
fail a judged call, and must never be silent. Every method returns whether the
write landed, counts itself in :data:`~src.db.repos.ledger.LEDGER`, and logs the
first failure of each kind. A caller that wants to know can read the return
value; a caller that does not may ignore it, which is the common case and the
reason the return type is a plain ``bool``.

**The transaction shape is not uniform, and the difference was measured.**
2026-08-26, against the live instance, writing **the real 23-column
``llm_call`` row** rather than a ``SELECT 1`` — 20 samples, median:

| connection already open, no checkout      |  46.8 ms |
| checkout + insert, ``pool_pre_ping=False``|  47.7 ms |
| checkout + insert, ``pool_pre_ping=True`` |  91.1 ms |

So a single-row write runs in ``AUTOCOMMIT``: SQLAlchemy otherwise opens an
implicit transaction and spends three round trips delivering one statement —
141 ms against 48 ms, measured the same day. What does get a transaction is the
enrichment sweep, which writes many rows and wants all or none of them.

Two things in that table are worth carrying forward. **The row shape costs
nothing**: a 23-column insert with JSONB and a NUMERIC takes the same 47 ms as
``SELECT 1``, so this is round trips and not payload, and no amount of trimming
what is stored will make it faster. **The checkout itself costs nothing either
— ``pool_pre_ping`` is the whole of it**, at 43.4 ms per write, about 6.5
seconds over a 150-call run. That is a quarter of the 23 seconds estimated from
the earlier ``SELECT 1`` figure, and it is the number open item 7 should be
decided on.

**There is no method that writes a call together with its attempts**, though the
latency argument would favour one. It is not possible under this design and that
is worth stating so nobody adds it: the socket writes an attempt while the
request is in flight, and the wrapper writes the call only after it returns,
because the row needs the status and the duration. The rows are never in hand at
the same moment — which is also why ``llm_attempt.call_id`` carries no foreign
key (departure 3).
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime
from collections.abc import Callable
from typing import Any

from sqlalchemy import Executable

from src.db import engine as engine_module
from src.db.models import LlmAttempt, LlmCall, LlmRun
from src.db.repos import statements
from src.db.repos.ledger import LEDGER

logger = logging.getLogger(__name__)

# Passed to `Connection.execution_options`. Named rather than inlined at four
# call sites, so the two flavours cannot drift apart on the one option that
# decides how many round trips a row costs.
AUTOCOMMIT = {"isolation_level": "AUTOCOMMIT"}


class AsyncCallLog:
    """The judge path's repository. Every method is a coroutine and none raise."""

    async def record_run(self, run: LlmRun) -> bool:
        """Open a run, or notice it is already open. Idempotent by ON CONFLICT."""
        return await self._write(statements.insert_run, run, what="run")

    async def finish_run(self, run_id: uuid.UUID, finished_at: datetime) -> bool:
        return await self._write(
            statements.finish_run, run_id, finished_at, what="run.finished_at"
        )

    async def record_call(self, call: LlmCall) -> bool:
        return await self._write(statements.insert_call, call, what="call")

    async def record_attempt(self, attempt: LlmAttempt) -> bool:
        return await self._write(statements.insert_attempt, attempt, what="attempt")

    async def pending_enrichment(
        self, llm_server: str, *, limit: int
    ) -> list[tuple[uuid.UUID, str]]:
        """
        The sweep's working set. Returns an empty list on failure, like a write.

        An empty list is also the correct answer when there is nothing pending,
        and the two are not distinguished — a sweep that cannot reach the
        database has nothing to do either way, and the ledger records the miss.
        """
        if not engine_module.is_enabled():
            return []
        try:
            statement = statements.pending_enrichment(llm_server, limit=limit)
            async with engine_module.get_async_engine().connect() as conn:
                result = await conn.execute(statement)
                return [tuple(row) for row in result.all()]
        except Exception as exc:
            LEDGER.record_failed(
                exc, what="pending enrichment", where=engine_module.safe_target()
            )
            return []

    async def enrich_attempts(self, updates: list[dict[str, Any]]) -> int:
        """
        Write a sweep's findings **in one transaction**, and return how many.

        The one place a transaction earns its extra round trips: this is the
        only multi-row write in the log, and a sweep that half-lands leaves rows
        stamped ``enriched_at`` whose findings were rolled back — which trap 4
        makes permanent, since a stamped row is never swept again.

        Each mapping is the keyword set of
        :func:`~src.db.repos.statements.enrich_attempt`.
        """
        if not engine_module.is_enabled() or not updates:
            return 0
        try:
            async with engine_module.get_async_engine().begin() as conn:
                for fields in updates:
                    await conn.execute(statements.enrich_attempt(**fields))
        except Exception as exc:
            LEDGER.record_failed(
                exc, what="enrichment sweep", where=engine_module.safe_target()
            )
            return 0
        for _ in updates:
            LEDGER.record_written()
        return len(updates)

    async def _write(self, build: Callable[..., Executable], *args: Any, what: str) -> bool:
        """
        One statement, one round trip, nothing raised.

        **The statement is built inside the ``try``**, which is why this takes a
        builder and its arguments rather than a finished statement. The builders
        refuse a missing primary key by raising, and a caller's bug must cost
        the row it was writing rather than the judged run around it — with the
        construction outside, the very exception the failure policy exists to
        absorb was the one exception that escaped it. Found by the test that
        asserts a bug is a counted miss.
        """
        if not engine_module.is_enabled():
            return False
        try:
            statement = build(*args)
            async with engine_module.get_async_engine().connect() as conn:
                await conn.execution_options(**AUTOCOMMIT)
                await conn.execute(statement)
        except Exception as exc:
            LEDGER.record_failed(exc, what=what, where=engine_module.safe_target())
            return False
        LEDGER.record_written()
        return True


class SyncCallLog:
    """
    The product path's repository, on psycopg.

    Parallel to :class:`AsyncCallLog` line for line. See this module's docstring
    for why that is written out twice rather than shared.
    """

    def record_run(self, run: LlmRun) -> bool:
        return self._write(statements.insert_run, run, what="run")

    def finish_run(self, run_id: uuid.UUID, finished_at: datetime) -> bool:
        return self._write(
            statements.finish_run, run_id, finished_at, what="run.finished_at"
        )

    def record_call(self, call: LlmCall) -> bool:
        return self._write(statements.insert_call, call, what="call")

    def record_attempt(self, attempt: LlmAttempt) -> bool:
        return self._write(statements.insert_attempt, attempt, what="attempt")

    def pending_enrichment(
        self, llm_server: str, *, limit: int
    ) -> list[tuple[uuid.UUID, str]]:
        if not engine_module.is_enabled():
            return []
        try:
            statement = statements.pending_enrichment(llm_server, limit=limit)
            with engine_module.get_sync_engine().connect() as conn:
                return [tuple(row) for row in conn.execute(statement).all()]
        except Exception as exc:
            LEDGER.record_failed(
                exc, what="pending enrichment", where=engine_module.safe_target()
            )
            return []

    def enrich_attempts(self, updates: list[dict[str, Any]]) -> int:
        if not engine_module.is_enabled() or not updates:
            return 0
        try:
            with engine_module.get_sync_engine().begin() as conn:
                for fields in updates:
                    conn.execute(statements.enrich_attempt(**fields))
        except Exception as exc:
            LEDGER.record_failed(
                exc, what="enrichment sweep", where=engine_module.safe_target()
            )
            return 0
        for _ in updates:
            LEDGER.record_written()
        return len(updates)

    def _write(self, build: Callable[..., Executable], *args: Any, what: str) -> bool:
        """See :meth:`AsyncCallLog._write` for why this takes a builder."""
        if not engine_module.is_enabled():
            return False
        try:
            statement = build(*args)
            with engine_module.get_sync_engine().connect() as conn:
                conn.execution_options(**AUTOCOMMIT)
                conn.execute(statement)
        except Exception as exc:
            LEDGER.record_failed(exc, what=what, where=engine_module.safe_target())
            return False
        LEDGER.record_written()
        return True
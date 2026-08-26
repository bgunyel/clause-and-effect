"""
Every statement the call log writes, built and never executed.

**The split is what makes the rest testable.** A repository that builds and
executes in one method can only be checked against a database; these functions
return SQLAlchemy Core constructs, so what the log is about to write can be
compiled to a string and asserted against, hermetically, with no connection and
no rows. `test_db_repos.py` reads the compiled SQL of every one of them. The
executors in `call_log.py` are then thin enough that what is left untested by
that arrangement is the part that genuinely needs a live database.

Three rules live here rather than in the callers, because a rule a caller has to
remember is a rule that holds until the next call site is written:

**Core ``update()``, never ``text()``.** ``updated_at`` is maintained by
SQLAlchemy's ``onupdate``, which is applied when the *statement* is built — so a
handwritten ``text("UPDATE llm_attempt SET …")`` silently leaves the column at
its insert value while the row changes underneath it. Measured 2026-08-26: raw
``text()`` executemany moved ``updated_at`` on 0 of 300 rows, Core ``update()``
on 300 of 300, for 7.6 ms per 300 rows.

**Cost is ``Decimal(str(value))``.** ``SUM(llm_attempt.cost)`` is the headline
query of the whole log, and ``Decimal(0.00123)`` carries the float's own
representation error into the column chosen to avoid it. Since a caller reading
a price off a JSON body has a float in hand, the conversion is applied here to
**every** value bound for a ``Numeric`` column, rather than being a thing the
wrapper and the socket patch must each get right.

**Nulls are dropped, not written.** ``None`` on a mapped attribute means the
caller did not set it, and the two columns where that matters —
``created_at``/``updated_at`` — have server defaults that a bound ``NULL`` would
override with an error. Since null and unset are the same thing for every other
column in this schema, dropping is safe: design §Schema's rule is that null
means *the provider did not report it*, which is exactly what omitting produces.
"""
from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import Float, Numeric, Select, Update, select, update
from sqlalchemy import inspect as sa_inspect
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.dialects.postgresql import Insert as PostgresInsert

from src.db.models import Base, LlmAttempt, LlmCall, LlmRun


def to_money(value: Any) -> Decimal | None:
    """
    A price, as an exact decimal. ``None`` stays ``None`` — it is not zero.

    ``str`` first and always, including for a value that is already a float:
    ``Decimal(0.1)`` is ``0.1000000000000000055511151231257827…`` and
    ``Decimal(str(0.1))`` is ``0.1``. A ``Decimal`` passed in is returned
    unchanged rather than round-tripped through ``str``, which would be
    harmless but pointless.
    """
    if value is None:
        return None
    if isinstance(value, Decimal):
        return value
    return Decimal(str(value))


def values_of(row: Base) -> dict[Any, Any]:
    """
    The set columns of a model instance, keyed by :class:`~sqlalchemy.Column`.

    **The instances are data holders and are never added to a session.** They
    are used because they keep one definition of the columns — a
    ``dict[str, Any]`` per call site would let a typo become a silently missing
    column — and because the measured cost of the ORM's identity map (125.5 ms
    against 67.5 ms for Core, 300 rows) is a cost this layer declines to pay per
    call.

    **Iterated through the mapper, not through ``__table__.columns``**, and
    ``llm_call.metadata`` is why. That column is mapped under the Python name
    ``call_metadata`` because ``Base.metadata`` owns the other one — but
    ``Column.key`` is ``metadata``, the same as ``Column.name``, since only the
    *mapper* knows about the rename. So the obvious loop does
    ``getattr(row, "metadata")`` and reads SQLAlchemy's ``MetaData`` object off
    the class, which then reaches ``values()`` as a value to bind. It does not
    fail quietly: ``ArgumentError: SQL expression element expected, got
    MetaData()``. It does fail confusingly, and it fails for every future column
    whose attribute name differs from the database's.

    ``mapper.column_attrs`` is keyed by the attribute name and carries the
    Column beside it, so both halves come from the one place that knows they
    differ. The dict is then keyed by the Column object itself rather than by
    either string, which leaves nothing for a later reader to get wrong.
    """
    values: dict[Any, Any] = {}
    for attribute in sa_inspect(type(row)).column_attrs:
        value = getattr(row, attribute.key)
        if value is None:
            continue
        column = attribute.columns[0]
        # `Float` subclasses `Numeric`, so the obvious isinstance check would
        # convert `call_seconds` and `request_seconds` — durations, measured
        # with a stopwatch and meaningless past the millisecond — into exact
        # decimals, and would then hand psycopg a Decimal for a double
        # precision column. Money is the arbitrary-precision type; a latency is
        # not.
        if isinstance(column.type, Numeric) and not isinstance(column.type, Float):
            value = to_money(value)
        values[column] = value
    return values


def _require_id(value: uuid.UUID | None, name: str) -> uuid.UUID:
    """
    Refuse to build a statement whose primary key the caller left to the column
    default.

    The columns carry ``default=uuid.uuid4``, so an insert without an id would
    succeed and generate one — and the caller would never learn it. That is
    fatal for this schema rather than untidy: ``call_id`` travels in a
    contextvar to the socket, which writes attempt rows referencing it *before*
    the call row exists. An id the wrapper does not know is a call whose
    attempts can never be joined to it.

    Raising is safe here despite the failure policy, because the executors catch
    everything: a caller's bug becomes a counted, reported miss rather than a
    crashed judge run.
    """
    if value is None:
        raise ValueError(f"{name} must be supplied by the caller, not defaulted")
    return value


def insert_run(run: LlmRun) -> PostgresInsert:
    """
    Insert a run, or do nothing if it is already there.

    Design §Schema: created lazily by the first call that needs one, so no entry
    point has to remember to open a run. Every call after the first then hits
    the conflict, which is why this is ``DO NOTHING`` and not ``DO UPDATE`` —
    the row's later columns (``finished_at``) belong to :func:`finish_run`, and
    an upsert here would overwrite a finished run's own timestamps with the
    values the first call happened to carry.
    """
    _require_id(run.run_id, "run_id")
    return insert(LlmRun.__table__).values(values_of(run)).on_conflict_do_nothing(
        index_elements=[LlmRun.__table__.c.run_id]
    )


def finish_run(run_id: uuid.UUID, finished_at: datetime) -> Update:
    """
    Stamp a run as finished.

    The only UPDATE on ``llm_run``, and the reason ``finished_at`` is nullable:
    a run without one is a run that did not finish, which is worth being able to
    query for.
    """
    return (
        update(LlmRun.__table__)
        .where(LlmRun.__table__.c.run_id == run_id)
        .values(finished_at=finished_at)
    )


def insert_call(call: LlmCall) -> PostgresInsert:
    """One logical call, written by the wrapper after the call returns."""
    _require_id(call.call_id, "call_id")
    _require_id(call.run_id, "run_id")
    return insert(LlmCall.__table__).values(values_of(call))


def insert_attempt(attempt: LlmAttempt) -> PostgresInsert:
    """
    One upstream HTTP request, written by the socket while it is in flight.

    ``call_id`` is deliberately not required: a null one means a request made
    outside any wrapper, which is how trap 8 reports itself instead of hiding.
    """
    _require_id(attempt.attempt_id, "attempt_id")
    return insert(LlmAttempt.__table__).values(values_of(attempt))


def enrich_attempt(
    attempt_id: uuid.UUID,
    *,
    enriched_at: datetime,
    routing_chain: str | None = None,
    native_finish_reason: str | None = None,
    generation_time: float | None = None,
    latency: float | None = None,
) -> Update:
    """
    Phase 2: what the generation endpoint said, eight to ten seconds later.

    **``enriched_at`` is required and the rest are not.** Trap 4: the stamp is
    set even when the sweep finds nothing, or every future sweep re-fetches the
    same permanently-missing generations forever. *Not yet swept* and *swept,
    nothing there* must stay distinguishable, and they are only distinguishable
    if the empty result still writes the timestamp.

    The four findings are written as ``None`` when absent rather than omitted,
    unlike an insert: this is an UPDATE, and the column being updated to null is
    a statement about what enrichment found. There is nothing to default to.
    """
    return (
        update(LlmAttempt.__table__)
        .where(LlmAttempt.__table__.c.attempt_id == attempt_id)
        .values(
            enriched_at=enriched_at,
            routing_chain=routing_chain,
            native_finish_reason=native_finish_reason,
            generation_time=generation_time,
            latency=latency,
        )
    )


def pending_enrichment(llm_server: str, *, limit: int) -> Select:
    """
    The sweep's working set: attempts with a generation id and no stamp.

    The predicate is written to match ``ix_llm_attempt_pending_enrichment``
    exactly — a partial index is only used when the query's ``WHERE`` implies
    the index's, and this table only grows, since nothing is ever deleted
    (decision 19). Ordered oldest first so a sweep that hits its limit makes
    progress through the backlog rather than re-reading the same newest rows.
    """
    attempt = LlmAttempt.__table__.c
    return (
        select(attempt.attempt_id, attempt.generation_id)
        .where(attempt.enriched_at.is_(None))
        .where(attempt.generation_id.is_not(None))
        .where(attempt.llm_server == llm_server)
        .order_by(attempt.started_at)
        .limit(limit)
    )
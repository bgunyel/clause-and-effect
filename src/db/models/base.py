"""
The declarative base: the row-lifecycle timestamps, and the constraint naming
convention Alembic needs.

**The naming convention is not cosmetic and it has to exist before the first
migration.** Without it Postgres invents names for indexes, foreign keys and
unique constraints, those invented names end up in the first migration, and a
later ``op.drop_constraint`` has to quote a string nobody chose and nothing
derives. Adding the convention afterwards renames every constraint in the
database, which is a migration written to fix a problem that only existed
because the convention was late. Decision 3 puts Alembic in from the first
commit; this is the half of that decision which has to be right on day one.
"""
from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, MetaData, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

# The convention SQLAlchemy documents for Alembic. `column_0_label` on indexes
# rather than `column_0_name` so a multi-column index is still distinguishable.
NAMING_CONVENTION = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}


class Base(DeclarativeBase):
    """
    Declarative base for every table in the call log.

    ``Base.metadata`` is what Alembic's ``target_metadata`` points at, and it is
    also the reason no mapped class may have an attribute called ``metadata``:
    the name is taken. ``llm_call`` has a column named ``metadata`` in the
    design, and it is mapped as ``call_metadata`` for exactly this reason —
    see :class:`~src.db.models.llm_log.LlmCall`.

    **The two timestamps live here rather than in a mixin the tables opt into**
    — Bertan, 2026-08-26: every table carries them, whatever it stores. On the
    base they are structural, so a table added next year cannot be the one that
    forgot; a mixin is something a new class can be written without.

    They are **not** duplicates of the domain timestamps beside them, and the
    apparent redundancy is worth stating so nobody tidies it away.
    ``llm_call.started_at`` is when the model call began; ``created_at`` is when
    the row reached the database, and the gap between them is the call's
    duration plus the write. ``llm_run.finished_at`` is a fact about the run;
    ``updated_at`` is a fact about the row. When a record and its subject
    disagree about time, only having one of them makes the disagreement
    invisible.
    """

    metadata = MetaData(naming_convention=NAMING_CONVENTION)

    # `server_default` rather than a Python default, deliberately: the clock is
    # the database's. Runs come from more than one machine, and rows stamped by
    # each machine's own clock cannot be ordered against each other — which is
    # the ordering a call log exists to support. `func.now()` is Postgres's
    # `transaction_timestamp()`, so every row written in one transaction shares
    # a stamp, which is the behaviour wanted for a call and its attempts.
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    # `onupdate` is applied by SQLAlchemy when it *builds* an UPDATE, so it is
    # a property of the statement rather than of the table. A literal
    # `text("UPDATE llm_attempt SET …")` does not get it, and the column would
    # then keep the insert's value while the row changed underneath it.
    #
    # **The rule that closes this is: repositories write with Core `update()`,
    # never with `text()`** — Bertan, 2026-08-26. A Core `update()` is a
    # statement builder against these columns, not the ORM's object graph: no
    # rows are loaded, no identity map is kept, and it compiles to the same SQL
    # as the handwritten version plus one `SET`. Measured against the live
    # instance, 300 rows, median of 5:
    #
    #     raw text() executemany       59.9 ms   updated_at moved:   0/300
    #     Core update() executemany    67.5 ms   updated_at moved: 300/300
    #     ORM load + mutate + flush   125.5 ms   updated_at moved: 300/300
    #
    # 7.6 ms for 300 rows, against a 47 ms network round trip — and the sweep
    # runs once per run, not once per call.
    #
    # **A `BEFORE UPDATE` trigger was considered and rejected** on those
    # numbers. It would be schema Alembic has to carry, invisible from this
    # file — so the model would stop describing the table — and firing per row
    # forever to buy a guarantee the calling code already provides. It would
    # also be inconsistent with decision 12, which keeps the enum vocabularies
    # out of the database on the grounds that repositories are the only
    # writers; enforcing `updated_at` in the database while declining a CHECK
    # for `status` is the same guarantee bought two different ways.
    #
    # What replaces it is a test: every UPDATE a repository emits must carry
    # this column. `test_db_models.py` pins the property at the statement
    # level, and the repository tests pin it per method.
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
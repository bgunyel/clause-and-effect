"""
The three tables of the LLM call log.

``llm_run`` is one row per **process**, ``llm_call`` one row per logical call,
``llm_attempt`` one row per upstream HTTP request. The third is the one that
makes cost totals true: **the real cost of a call is
``SUM(llm_attempt.cost)``**, and ``llm_call.cost`` is stored beside it as what
the caller believed. The two are kept apart on purpose — the gap between them
is the undercount this project has been publishing, and on the retry probe's
first scenario it was 67% of the call.

Three rules govern the column types, and each of them is a decision with an
argument behind it rather than a convention.

**No enum types in the database** (decision 12). ``status``, ``llm_server``,
``channel`` and ``model`` are all text. A Postgres enum is the wrong shape for
values that change with the roster: adding one is ``ALTER TYPE … ADD VALUE``,
which does not sit comfortably in a migration, and removing one is not
supported at all. The enumerations live in Python and the repositories enforce
them at the only point rows enter. ``sqlalchemy.Enum`` is specifically not used
anywhere here: its native form would create the type this decision forbids, and
its non-native form stores the member's ``.name`` rather than its ``.value``,
which is the wrong string.

**Null means the provider did not report it, and null is never zero.** A call
reporting ``reasoning: 0`` did not reason; a call reporting nothing may have
reasoned freely and not said so, and averaging the two together would invent a
measurement. So every metric column is nullable, and the repositories must
never fill one with a default.

**Cost is ``Numeric``, not ``Float``.** ``SUM(llm_attempt.cost)`` is the
headline query of the whole log, and summing a few hundred binary floats at the
fifth significant figure of a cent accumulates error into precisely the number
the table exists to make trustworthy. Postgres ``NUMERIC`` with no precision is
arbitrary-precision, so nothing is rounded at write time and no scale has to be
guessed now. **The repository must convert with ``Decimal(str(value))``** —
``Decimal(float)`` carries the float's own representation error into a column
chosen to avoid it.

Three places this file departs from ``docs/design/llm-call-log.md``. All are
marked ``DEPARTURE`` at the column and summarised here so they are easy to
reverse:

1. ``llm_run`` stores ``git_dirty_paths`` rather than a ``git_dirty`` boolean.
2. ``llm_call`` and ``llm_attempt`` each gain a ``started_at``.
3. ``llm_attempt.call_id`` carries no foreign key, and ``llm_attempt`` gains
   ``llm_server``.
"""
from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from enum import Enum

from sqlalchemy import (
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    Uuid,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from src.db.models.base import Base


class CallStatus(Enum):
    """
    How a logical call ended, as seen by the wrapper.

    Deliberately a plain ``Enum`` and **not** ``StrEnum``, so that writing
    ``.value`` is the only way to get the string and the discipline is the same
    one decision 14 imposes on ``ai_common``'s enums. Those carry no ``str``
    mixin either, and the three shortcuts that look like they work — ``str()``,
    an f-string, and ``member == "ok"`` — are wrong there. One rule everywhere
    beats two rules and a memory of which is which.
    """

    OK = "OK"
    STRUCTURE = "STRUCTURE"
    TIMEOUT = "TIMEOUT"
    TRANSPORT = "TRANSPORT"


class LlmRun(Base):
    """One row per process. Not per script: a long-lived server is one run."""

    __tablename__ = "llm_run"

    run_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, primary_key=True, default=uuid.uuid4
    )
    entry_point: Mapped[str] = mapped_column(String, nullable=False)
    commit_sha: Mapped[str] = mapped_column(String, nullable=False)

    # DEPARTURE 1. The design says `git_dirty`, a boolean. `chunk_store.git_state`
    # returns `(sha, dirty_paths)` and argues in its own docstring against the
    # boolean: it is repo-wide, so an unrelated draft in docs/ marks a run dirty
    # even when everything that produced it is committed, and only the paths let
    # a reader three months later tell those apart. That docstring also warns
    # against keeping a separate flag beside the list, because the two fall out
    # of sync. So the paths are stored and the boolean is a query —
    # `jsonb_array_length(git_dirty_paths) > 0`. An empty array is a clean tree;
    # `["<git unavailable>"]` reads as dirty, which is what git_state intends.
    git_dirty_paths: Mapped[list[str]] = mapped_column(JSONB, nullable=False)

    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    # Null while the run is in progress, and still null if it died. A run with
    # no `finished_at` is a run that did not finish, which is worth being able
    # to find.
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    hostname: Mapped[str] = mapped_column(String, nullable=False)


class LlmCall(Base):
    """
    One row per logical call, written by the wrapper after the call returns.

    Everything from ``generation_id`` down to ``reasoning_tokens`` is **what the
    caller believed**: it comes off the last attempt's response metadata, and on
    a retried call that is one attempt out of an unbounded number. The truth is
    in ``llm_attempt``.
    """

    __tablename__ = "llm_call"

    call_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, primary_key=True, default=uuid.uuid4
    )
    run_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("llm_run.run_id"), nullable=False, index=True
    )

    # Eval concepts. The product path has neither, and that is not a gap.
    stage: Mapped[str | None] = mapped_column(String)
    case_id: Mapped[str | None] = mapped_column(String)

    # `ModelNames.value` — 'deepseek-v4-flash-0731', never `.name` and never
    # `str(member)`. See CallStatus for why the repository spells it out.
    model: Mapped[str] = mapped_column(String, nullable=False)
    # The `structured_output` mode. Null for a call that asked for none.
    channel: Mapped[str | None] = mapped_column(String)
    # `LlmServers.value` — who we bought the call from. NOT who ran it; that is
    # `llm_attempt.served_provider`, and conflating the two is trap 7.
    llm_server: Mapped[str] = mapped_column(String, nullable=False)
    # The routing constraint we sent, verbatim, as it went on the wire. What we
    # asked for; `served_provider` is what answered, and the finding of
    # 2026-08-25 is that they differ.
    requested_provider: Mapped[dict | None] = mapped_column(JSONB)

    status: Mapped[str] = mapped_column(String, nullable=False)
    # The bare invocation. The timer stops before the row is written, so this
    # is the model's latency and not ours.
    call_seconds: Mapped[float] = mapped_column(Float, nullable=False)
    # DEPARTURE 2. Not in the design's column list. Without it a call can be
    # placed no more precisely than its run, so two runs interleaved on one
    # machine cannot be untangled and no query can ask what the panel was doing
    # at a given moment. It costs eight bytes and cannot be reconstructed later.
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )

    generation_id: Mapped[str | None] = mapped_column(String)
    cost: Mapped[Decimal | None] = mapped_column(Numeric)
    finish_reason: Mapped[str | None] = mapped_column(String)
    prompt_tokens: Mapped[int | None] = mapped_column(Integer)
    completion_tokens: Mapped[int | None] = mapped_column(Integer)
    reasoning_tokens: Mapped[int | None] = mapped_column(Integer)

    # The prompt itself is not stored — it is a pure function of the case, the
    # stage and the templates at `commit_sha`. This hash is what makes that
    # reconstruction checkable rather than merely assumed.
    prompt_sha256: Mapped[str] = mapped_column(String, nullable=False)

    # Failures only, and **in full**. `JudgeResponseError` truncates at 300
    # characters, and on 2026-08-25 that was exactly the gap: MiniMax's failure
    # read `Invalid json output: ` with nothing before the newline, and whether
    # the content was empty or merely unparseable is still unknown because the
    # excerpt did not reach far enough.
    raw_output: Mapped[str | None] = mapped_column(Text)
    error_type: Mapped[str | None] = mapped_column(String)
    error_message: Mapped[str | None] = mapped_column(Text)

    # The DB column is `metadata`; the attribute cannot be, because
    # `Base.metadata` is SQLAlchemy's own. Mapping it under a different Python
    # name is the whole fix, and it is easy to lose in a later edit.
    call_metadata: Mapped[dict | None] = mapped_column("metadata", JSONB)


class LlmAttempt(Base):
    """
    One row per upstream HTTP request, written by the socket patch.

    **This is the table that says what a call actually cost.** A row here exists
    for every request that reached the provider, including the ones a retry
    swallowed and the ones that failed — which, on the evidence of 2026-08-25,
    are disproportionately the interesting ones.
    """

    __tablename__ = "llm_attempt"

    attempt_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, primary_key=True, default=uuid.uuid4
    )

    # DEPARTURE 3a. Nullable by design — a null means a request made outside any
    # wrapper, which is how trap 8 reports itself instead of hiding.
    #
    # Carrying **no foreign key** is the departure, and the reason is write
    # ordering. The socket writes this row while the request is in flight; the
    # wrapper writes `llm_call` only after the call returns, because the row
    # needs the status and the duration. So an attempt is written before the
    # call it belongs to exists, and a foreign key would reject it — turning the
    # log's failure policy into a design constraint on when rows may be written.
    # The reference is real and indexed; it is simply not enforced by the
    # database, which is the same trade decision 12 already makes for the
    # enumerations.
    call_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, index=True)
    # Order within the call. Not unique against `call_id`, since `call_id` is
    # nullable and the socket cannot sequence requests it cannot attribute.
    seq: Mapped[int] = mapped_column(Integer, nullable=False)

    # DEPARTURE 3b. Not in the design's column list, but the design's own
    # enrichment query filters on it — `WHERE enriched_at IS NULL AND
    # generation_id IS NOT NULL AND llm_server = 'openrouter'`. It cannot come
    # from a join, because the rows that most need filtering are exactly the
    # ones with a null `call_id`. The socket knows it from the request URL.
    llm_server: Mapped[str] = mapped_column(String, nullable=False)
    # DEPARTURE 2, again. Attempts within one call are ordered by `seq`; this is
    # what places them against the clock, which is how the retry timeline that
    # produced this table was read in the first place.
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )

    # --- phase 1: everything the socket sees, immediately -------------------
    generation_id: Mapped[str | None] = mapped_column(String, index=True)
    # `provider` in the response body — who ran the machine. **Verbatim, always**
    # (decision 16). No case-folding, no trimming, no reconciliation against
    # `LlmServers` even when the string matches one. Normalising at write time
    # is irreversible and turns a record of the call into a record of our
    # opinion about it. `GROUP BY served_provider` returning three spellings of
    # one company is correct behaviour, not a defect. Trap 9.
    served_provider: Mapped[str | None] = mapped_column(String)
    # `model` in the response body — the wire id, e.g. 'minimax/minimax-m3'.
    # Kept beside `llm_call.model`, which holds the canonical name, so that
    # grouping and console-matching each have their own column instead of one
    # being derived from the other by string surgery.
    model_alias: Mapped[str | None] = mapped_column(String)
    # Null when the request never got a response at all — a connection error is
    # still an attempt, and may still have been billed.
    http_status: Mapped[int | None] = mapped_column(Integer)
    cost: Mapped[Decimal | None] = mapped_column(Numeric)
    prompt_tokens: Mapped[int | None] = mapped_column(Integer)
    completion_tokens: Mapped[int | None] = mapped_column(Integer)
    reasoning_tokens: Mapped[int | None] = mapped_column(Integer)
    finish_reason: Mapped[str | None] = mapped_column(String)
    # Measured at the socket, so it includes the provider's queueing and not
    # ours.
    request_seconds: Mapped[float] = mapped_column(Float, nullable=False)

    # --- phase 2: the generation endpoint, 8-10 seconds later ---------------
    # e.g. 'Parasail:429 -> Venice:200'. The fallback chain is the evidence
    # that settled the MiniMax channel question, and it is recoverable for
    # failed attempts too now that enrichment attaches here rather than to the
    # call.
    routing_chain: Mapped[str | None] = mapped_column(String)
    native_finish_reason: Mapped[str | None] = mapped_column(String)
    generation_time: Mapped[float | None] = mapped_column(Float)
    latency: Mapped[float | None] = mapped_column(Float)
    # Trap 4. Set even when enrichment finds nothing, or every sweep re-fetches
    # the same permanently-missing generations forever. *Not yet swept* and
    # *swept, nothing there* must stay distinguishable, which is why this is a
    # timestamp and not a boolean derived from `routing_chain IS NULL`.
    enriched_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    __table_args__ = (
        # The sweep's working set, and nothing else. A partial index keeps it
        # proportional to the rows still awaiting enrichment rather than to the
        # table, which only ever grows — nothing is ever deleted (decision 19).
        Index(
            "ix_llm_attempt_pending_enrichment",
            "llm_server",
            postgresql_where=text("enriched_at IS NULL AND generation_id IS NOT NULL"),
        ),
    )
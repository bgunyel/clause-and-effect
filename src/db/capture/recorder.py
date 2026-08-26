"""
Turning one finished model call into one row, and writing it.

**The recorder knows nothing about why the call was made.** It is handed an
outcome and a response; the wrapper above decides which outcome that was, and
the wrapper is where the knowledge of a particular response shape belongs. That
split is what lets the judge path and the product path — which agree on nothing
about what they call or what comes back — share one writing path.

Two orderings here are load-bearing and neither is obvious from reading a single
function.

**The run row is written before the first call row.** ``llm_call.run_id`` is a
foreign key, so a call whose run has not landed is rejected by the database —
the one enforced reference in the schema. Every later call finds the run already
written and pays nothing.

**The timer has already stopped by the time anything here runs.** The duration
this records is the caller's measurement of the bare invocation; design §The
timed region excludes the write, so that a run's per-call latency stays the
model's latency and not ours. The write costs ~90 ms against a call that takes
seconds, it is awaited inline, and it is outside the number.
"""
from __future__ import annotations

import hashlib
import uuid
from datetime import datetime
from typing import Any

from src.db.capture import response as response_reader
from src.db.capture.context import RUN, CallContext
from src.db.models import CallStatus, LlmCall
from src.db.repos import AsyncCallLog, SyncCallLog


def prompt_digest(prompt: Any) -> str:
    """
    The SHA-256 of the prompt as the runnable received it.

    **The prompt itself is not stored** (decision 11): it is a pure function of
    the case, the stage and the templates at ``commit_sha``, all three of which
    are on the row. What that reconstruction lacks is a way to *check* itself,
    and this is it — recompute the prompt from the recorded inputs, hash it, and
    compare.

    ``str()`` rather than a canonical encoding, because a prompt reaches here as
    whatever the call site passed: a string on every current path, and a list of
    message dicts on others. Python's repr of a list of dicts is stable within a
    process and across runs of the same code, which is all a check against a
    recorded ``commit_sha`` needs. It is **not** stable across a refactor that
    changes the container — a hash that stops matching means "recompute this
    differently", not "the prompt changed".
    """
    return hashlib.sha256(str(prompt).encode("utf-8")).hexdigest()


def build_call_row(
    *,
    context: CallContext,
    model_params: dict,
    prompt: Any,
    status: CallStatus,
    started_at: datetime,
    call_seconds: float,
    raw: Any = None,
    error: BaseException | None = None,
    error_message: str | None = None,
    metadata: dict | None = None,
) -> LlmCall:
    """
    One ``llm_call`` row. Pure — it builds nothing that touches a database.

    Pure so that it can be checked: what the log is about to record about a call
    that failed is otherwise only observable by making a call fail against a
    live instance.

    ``raw`` is the message the provider's metadata rides on, and everything read
    off it is **what the caller believed** — on a retried call it describes the
    last attempt only. The truth about cost is ``SUM(llm_attempt.cost)``, which
    the socket writes and this function cannot see.
    """
    failed = status is not CallStatus.OK
    return LlmCall(
        call_id=context.call_id,
        run_id=context.run_id,
        stage=context.stage,
        case_id=context.case_id,
        # `.value`, never `.name` and never `str(member)` — decision 14. These
        # enums carry no `str` mixin, so the three shortcuts that look like they
        # work are all wrong.
        model=_enum_value(model_params.get("model")),
        channel=model_params.get("structured_output"),
        llm_server=_enum_value(model_params.get("model_provider")),
        # The routing constraint we sent, verbatim as it went on the wire. What
        # we asked for; `llm_attempt.served_provider` is what answered, and the
        # finding of 2026-08-25 is that they differ.
        requested_provider=(model_params.get("model_args") or {}).get("provider"),
        status=status.value,
        call_seconds=call_seconds,
        started_at=started_at,
        generation_id=response_reader.generation_id_of(raw),
        cost=response_reader.cost_of(raw),
        finish_reason=response_reader.finish_reason_of(raw),
        prompt_tokens=response_reader.prompt_tokens_of(raw),
        completion_tokens=response_reader.completion_tokens_of(raw),
        reasoning_tokens=response_reader.reasoning_tokens_of(raw),
        prompt_sha256=prompt_digest(prompt),
        # Failures only, and in full. Storing it on every call would put every
        # generation this project has ever made into a public database's
        # backups; storing none of it is what made 2026-08-25's MiniMax failure
        # undiagnosable.
        raw_output=response_reader.content_of(raw) if failed else None,
        error_type=type(error).__name__ if error is not None else None,
        error_message=error_message,
        call_metadata=metadata,
    )


def _enum_value(member: Any) -> Any:
    """
    ``member.value`` for an enum, the object itself otherwise.

    The config holds ``ModelNames`` and ``LlmServers`` members; a test or a
    future caller may hold the string already. Both must reach the column as the
    platform-neutral name — ``deepseek-v4-flash-0731``, not
    ``DEEPSEEK_V_4_FLASH_0731``, which is what `str()` on these enums produces.
    """
    return getattr(member, "value", member)


async def record_call(row: LlmCall) -> bool:
    """
    Write one call on the judge path, opening the run first if it is not open.

    Returns whether the row landed. Never raises: the repositories absorb every
    failure and count it, and this adds nothing that could throw — a caller can
    ignore the result, which is the common case.
    """
    log = AsyncCallLog()
    if not RUN.written:
        RUN.written = await log.record_run(RUN.row())
    return await log.record_call(row)


def record_call_sync(row: LlmCall) -> bool:
    """The product path's counterpart. Same ordering, same guarantees."""
    log = SyncCallLog()
    if not RUN.written:
        RUN.written = log.record_run(RUN.row())
    return log.record_call(row)


def new_call_context(stage: str | None, case_id: str | None) -> CallContext:
    """
    The context for a call that is about to be made.

    **The call id is generated here rather than by the database**, and that is
    the reason `statements.py` refuses to default a primary key: the socket
    writes attempt rows against this id while the request is in flight, long
    before the call row exists. An id the wrapper does not know is a call whose
    attempts can never be joined to it.
    """
    return CallContext(
        run_id=RUN.row().run_id,
        call_id=uuid.uuid4(),
        stage=stage,
        case_id=case_id,
    )
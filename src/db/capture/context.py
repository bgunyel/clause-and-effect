"""
Which run, which call, which case — and how the socket gets to know.

Three scopes, each with a different lifetime and a different owner:

- **The run** is the process. Built once, lazily, by the first call that needs
  it, so no entry point has to remember to open one and a script that never
  calls a model never writes a row.
- **The case** is set by whoever is iterating cases — a probe, the judge driver
  — and read by every call underneath it. It is a `contextvar` rather than an
  argument because the five stage functions take a question and an answer, not a
  case id, and threading one through five signatures to reach a log would put
  the log into the judge's API.
- **The call** is set by the wrapper for the duration of one model call, and
  **read by the socket patch**, which otherwise sees an HTTP request with no
  idea what produced it.

``contextvars`` are the right primitive here rather than a convenience. Each
asyncio task gets its own copy of the context at creation, so eight panelists
running concurrently each see their own call id with no locking and no leakage
between them; the same mechanism works unchanged on the synchronous product
path, where there is one context and nothing to isolate.

**An attempt row with a null call id is a feature.** It means a request was made
outside any wrapper — the bypass trap 8 worries about — and this way the log
reports it instead of missing it.
"""
from __future__ import annotations

import os
import socket
import sys
import uuid
from contextlib import contextmanager
from contextvars import ContextVar
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterator

# `src/db/capture/context.py` -> capture -> db -> src -> the repository.
_REPO_ROOT = Path(__file__).resolve().parents[3]


@dataclass(frozen=True)
class CallContext:
    """
    What is in flight right now, as the socket will see it.

    Frozen, and replaced rather than mutated: a `contextvar` holding a mutable
    object would let one task's edit reach another's view of it, which is the
    one property the choice of `contextvars` was making.
    """

    run_id: uuid.UUID
    call_id: uuid.UUID
    stage: str | None
    case_id: str | None


_current_call: ContextVar[CallContext | None] = ContextVar(
    "clause_and_effect_current_call", default=None
)
_current_case: ContextVar[str | None] = ContextVar(
    "clause_and_effect_current_case", default=None
)


def current_call() -> CallContext | None:
    """
    The call this code is running inside, or ``None``.

    **``None`` is a real answer and the socket must record it as one**: a
    request made outside any wrapper writes an attempt row with a null
    ``call_id``, which is how a bypassed wrapper reports itself.
    """
    return _current_call.get()


def current_case() -> str | None:
    """The case id set by whoever is iterating cases, if anyone is."""
    return _current_case.get()


@contextmanager
def case_context(case_id: str | None) -> Iterator[None]:
    """
    Name the case every model call underneath this belongs to.

    ``None`` is allowed and clears it — the product path has no case, and design
    §Schema says that is not a gap.
    """
    token = _current_case.set(case_id)
    try:
        yield
    finally:
        _current_case.reset(token)


@contextmanager
def call_context(context: CallContext) -> Iterator[None]:
    """
    Publish one call to the socket for the duration of the model invocation.

    ``reset`` in a ``finally`` rather than setting back to ``None``: the two
    differ when contexts nest, and the token restores whatever was there before
    rather than asserting that nothing was.
    """
    token = _current_call.set(context)
    try:
        yield
    finally:
        _current_call.reset(token)


class RunRegistry:
    """
    The process's run row, built once and written on first use.

    **Built lazily and written even more lazily.** Constructing the row shells
    out to git, so a process that never calls a model never pays for it; and the
    row is only *written* when a call is about to be recorded, so a run with no
    calls leaves nothing behind.

    ``written`` is set only after a successful insert. A failed one leaves the
    flag down so the next call retries — which matters because ``llm_call.run_id``
    is a foreign key, and every call row in a run whose run row never landed
    would fail too.

    **The concurrent case needs no lock.** Two panelists starting at once can
    both find ``written`` false and both insert; the statement is
    ``ON CONFLICT DO NOTHING``, so the second is a no-op. A lock would not help
    anyway — it cannot be held across the ``await`` that does the writing.
    """

    def __init__(self) -> None:
        self._row = None
        self.written = False

    def row(self):
        """The ``LlmRun`` for this process, built on first ask."""
        if self._row is None:
            self._row = _build_run_row()
        return self._row

    def reset(self) -> None:
        """Forget the run. For tests, and for a process starting a second run."""
        self._row = None
        self.written = False


def _build_run_row():
    """
    One row describing this process: where it ran, from what code, and when.

    Imported inside the function for the same reason everything heavy in this
    package is: ``chunk_store`` costs 0.181s and the models pull SQLAlchemy, and
    a process that logs nothing should pay neither.
    """
    from src.clause_and_effect.chunking.chunk_store import git_state
    from src.db.models import LlmRun

    commit, dirty_paths = git_state(_REPO_ROOT)
    return LlmRun(
        run_id=uuid.uuid4(),
        entry_point=_entry_point(),
        commit_sha=commit,
        # The paths, not a boolean — departure 1. An empty list is a clean tree
        # and `["<git unavailable>"]` reads as dirty, which is what `git_state`
        # intends: an unverifiable tree should never look reproducible.
        git_dirty_paths=dirty_paths,
        started_at=datetime.now(timezone.utc),
        hostname=socket.gethostname(),
    )


def _entry_point() -> str:
    """
    What was run, as a name rather than a path.

    ``sys.argv[0]`` is the script; under ``python -m`` it is the module's file
    and under an interactive interpreter it is empty, which is why the fallback
    exists rather than letting a ``NOT NULL`` column decide. The basename and
    not the full path: the path is this machine's, and `hostname` already
    records which machine that was.
    """
    argv0 = sys.argv[0] if sys.argv else ""
    return os.path.basename(argv0) or "<interactive>"


# One registry per process, for the same reason the engines are process-wide:
# every writer in the process belongs to one run.
RUN = RunRegistry()


def reset_run() -> None:
    """Forget the process's run. For tests."""
    RUN.reset()
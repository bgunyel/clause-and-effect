"""
The count of writes that did not happen.

Design §Failure policy has two rules in deliberate tension. **A logging failure
must never fail a judged call** — the judgement is the valuable output and the
row is bookkeeping, so the repositories catch and do not raise. **A logging
failure must never be silent** — an instrument that quietly drops records is the
same defect class as every other finding this project made in August, so the
misses are counted and reported.

This module is the second rule. Without it the first one is just a bare
``except`` and the log becomes an instrument that reports 100% coverage of
whatever happened to get through.

**The report is per process, not per run.** It counts what this process
attempted, which is what a process can honestly claim; `llm_run` is a database
row and a run whose writes all failed has no row to attach a count to.
"""
from __future__ import annotations

import logging
import threading
from dataclasses import dataclass, field

logger = logging.getLogger(__name__)


@dataclass
class WriteLedger:
    """
    Attempted, written, failed — and what the failures were.

    Mutable and shared, because the socket patch writes attempts from whatever
    thread httpx is on while the wrapper writes calls from the caller's. The
    lock guards a few integer increments in front of a network round trip and
    is not worth optimising away.
    """

    attempted: int = 0
    written: int = 0
    failed: int = 0
    # Failure type -> how many. Kept by type rather than as a list of messages
    # so that a database down for a whole run costs one dictionary entry rather
    # than 150 stored strings.
    failures: dict[str, int] = field(default_factory=dict)
    _lock: threading.Lock = field(default_factory=threading.Lock, repr=False)

    def record_written(self) -> None:
        with self._lock:
            self.attempted += 1
            self.written += 1

    def record_failed(self, exc: Exception, *, what: str, where: str) -> None:
        """
        Count a failed write and say so, once per failure kind.

        **Not once per failure.** An unreachable database fails every write in
        the run, and 150 identical warnings would bury the output the run exists
        to produce — including, on a judged run, the findings themselves. The
        first of each kind is a warning; the rest are counted and reported at
        the end, which is the number that actually matters. ``where`` is
        :func:`~src.db.engine.safe_target` and never the URL.
        """
        kind = type(exc).__name__
        with self._lock:
            self.attempted += 1
            self.failed += 1
            first_of_kind = kind not in self.failures
            self.failures[kind] = self.failures.get(kind, 0) + 1

        from src.db.engine import redact

        if first_of_kind:
            logger.warning(
                "Call log write failed (%s) at %s — %s: %s. "
                "Further failures of this kind are counted, not logged.",
                what, where, kind, redact(exc),
            )
        else:
            logger.debug("Call log write failed (%s): %s", what, kind)

    def reset(self) -> None:
        """
        Zero the counts **in place**.

        In place, and not by rebinding :data:`LEDGER` to a fresh instance: any
        module that did ``from ledger import LEDGER`` would keep counting into
        the old object while the report read the new one, and the symptom would
        be a run reporting zero writes having made hundreds.
        """
        with self._lock:
            self.attempted = 0
            self.written = 0
            self.failed = 0
            self.failures = {}

    def report(self) -> str:
        """
        One line, for an entry point to log at the end of a run.

        Says nothing reassuring when nothing was attempted: "0 of 0" would read
        as success to a reader skimming, and a run that logged nothing at all is
        exactly the case worth noticing.
        """
        with self._lock:
            if self.attempted == 0:
                return "Call log: nothing was written (no writes were attempted)."
            if self.failed == 0:
                return f"Call log: {self.written} of {self.attempted} writes landed."
            kinds = ", ".join(
                f"{count}× {kind}" for kind, count in sorted(self.failures.items())
            )
            return (
                f"Call log: {self.written} of {self.attempted} writes landed; "
                f"{self.failed} failed ({kinds})."
            )


# The process-wide ledger. A module-level singleton for the same reason the
# engines are: every writer in the process is counting into one total, and
# threading a ledger through the socket patch would mean the patch taking an
# argument at install time that only exists to be counted into.
LEDGER = WriteLedger()


def reset_ledger() -> None:
    """Zero the counts. For tests, and for a long-lived process starting a run."""
    LEDGER.reset()
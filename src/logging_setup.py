"""
Logging configuration for the command-line entry points.

Configured **only** here and only by scripts. Library modules under
`src/clause_and_effect/` call `logging.getLogger(__name__)` and nothing else:
they do not add handlers, do not set levels, and never write to stdout
directly. A library that prints cannot be silenced, redirected or captured by
the program using it, which is why `vector_db` announcing "Indexing 368
chunks..." on stdout was a defect rather than a style preference.

**Not `rich.logging.RichHandler`, though `rich` is already a dependency.** It
was the obvious choice and it is the wrong one here. Rich word-wraps each record
to the console width and re-indents the continuation under a gutter, so the
aligned reports these scripts emit come apart — measured at width 80, a
`chunk_set_sha256` broke across two lines mid-hash and a snapshot filename was
pushed onto a line of its own. `print` never did that: the *terminal* wrapped,
which leaves a hash intact for copying and keeps columns lined up when the
window is wide. A plain `StreamHandler` behaves the same way. Colour by level is
not worth a mangled digest.

Multi-line reports are emitted as **one record** with embedded newlines rather
than one record per line, so a table stays a table and carries a single
timestamp instead of one per row.

Output goes to **stdout** by default, not the `StreamHandler` default of stderr.
For the callers that take the default the report *is* the product rather than a
diagnostic sidecar, and it was on stdout when it was `print`; moving it would
silently change what a redirect captures. Seven callers take it: the five probe
scripts, `src.scripts.index_documents`, and `migrations/env.py`.

**The default holds only while the logger carries the report.** `score_retrieval`
is the eighth caller, the only one whose product is *not* the log, and the reason
`stream` is a parameter: it prints its report to stdout by hand and logs nothing
but a run banner and progress, so a logger on stdout would interleave diagnostics
into the file a redirect of that report writes. It asks for `sys.stderr`, which
is where those two lines already were, and the split survives becoming logging. A
script whose report goes *through* the logger must not pass this — two streams
would cut such a report in half.

The count is of `setup_logging` callers, not of scripts. Eleven others under
`scripts/` — the `probe_a1_*` and `probe_a2_*` families, `probe_panel_roster`,
`probe_reasoning_channel` — print everything and call nothing here. They are not
evidence either way about the default; they have not been brought to the rule
yet. (`probe_spend` is in neither count: it is a shared helper the probes import,
not an entry point.)
"""
import logging
import sys
from typing import Optional, TextIO

_FORMAT = "%(asctime)s %(levelname)-7s %(message)s"
_DATE_FORMAT = "%H:%M:%S"


def setup_logging(level: int = logging.INFO, stream: Optional[TextIO] = None) -> None:
    """
    Install a console handler on the root logger. Idempotent.

    Called from a script's ``main()``. Safe to call twice — a second call is a
    no-op rather than a second handler, which would double every line. That
    holds for ``stream`` too: the first call's stream is the one that stays.

    ``stream`` defaults to `sys.stdout`, read at call time rather than bound to
    the default argument, so a caller that has already redirected `sys.stdout`
    gets the stream it installed and not the one that existed at import.
    """
    root = logging.getLogger()
    if any(getattr(h, "_clause_and_effect", False) for h in root.handlers):
        return

    handler = logging.StreamHandler(sys.stdout if stream is None else stream)
    handler.setFormatter(logging.Formatter(_FORMAT, datefmt=_DATE_FORMAT))
    # Marked so a second call recognises its own handler rather than counting
    # any StreamHandler — pytest and other harnesses install their own.
    handler._clause_and_effect = True

    root.handlers.clear()
    root.addHandler(handler)
    root.setLevel(level)
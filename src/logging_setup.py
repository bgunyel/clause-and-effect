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

Output goes to **stdout**, not the `StreamHandler` default of stderr. For these
scripts the report *is* the product rather than a diagnostic sidecar, and it was
on stdout when it was `print`; moving it would silently change what a redirect
captures.
"""
import logging
import sys

_FORMAT = "%(asctime)s %(levelname)-7s %(message)s"
_DATE_FORMAT = "%H:%M:%S"


def setup_logging(level: int = logging.INFO) -> None:
    """
    Install a console handler on the root logger. Idempotent.

    Called from a script's ``main()``. Safe to call twice — a second call is a
    no-op rather than a second handler, which would double every line.
    """
    root = logging.getLogger()
    if any(getattr(h, "_clause_and_effect", False) for h in root.handlers):
        return

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(logging.Formatter(_FORMAT, datefmt=_DATE_FORMAT))
    # Marked so a second call recognises its own handler rather than counting
    # any StreamHandler — pytest and other harnesses install their own.
    handler._clause_and_effect = True

    root.handlers.clear()
    root.addHandler(handler)
    root.setLevel(level)
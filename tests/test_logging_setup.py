"""
Tests for the console handler installed by the command-line entry points.

The claim under test is *where a record goes*, which is the whole reason the
parameter exists: `score_retrieval` prints its report to stdout by hand and logs
only diagnostics, so a logger on stdout would drop progress lines into whatever
a redirect of the report captures. The seven other callers — the five probe
scripts, `src.scripts.index_documents` and `migrations/env.py` — log the report
itself and must keep the stdout default.

No expected value here is obtained by calling `setup_logging` — the streams are
named directly and the handler count and level are literals.
"""
import io
import logging
import sys

import pytest

from src.logging_setup import setup_logging


@pytest.fixture(autouse=True)
def _restore_root_logger():
    """
    `setup_logging` clears and repopulates the root logger, which pytest also
    uses. Put back exactly what was there, so one test cannot silence another's
    captured output.
    """
    root = logging.getLogger()
    handlers, level = list(root.handlers), root.level
    yield
    root.handlers.clear()
    root.handlers.extend(handlers)
    root.setLevel(level)


def test_the_default_stream_is_stdout():
    """
    The seven default callers emit their report *through* the logger, and that
    report was on stdout when it was `print`. Defaulting anywhere else would
    silently change what a redirect of those scripts captures.
    """
    setup_logging()

    root = logging.getLogger()
    assert len(root.handlers) == 1
    assert root.handlers[0].stream is sys.stdout


def test_the_default_is_read_at_call_time_not_bound_at_import(monkeypatch):
    """
    `sys.stdout` as a default *argument* would be bound once, at import, and
    every test above would still pass — so the distinction needs its own check.
    It matters because a caller that has already replaced `sys.stdout` (a
    harness capturing output, a script redirecting its own report) would
    otherwise get the interpreter's original stream and write past the
    redirection it just installed.
    """
    replacement = io.StringIO()
    monkeypatch.setattr(sys, "stdout", replacement)

    setup_logging()

    assert logging.getLogger().handlers[0].stream is replacement


def test_a_named_stream_is_the_one_written_to():
    """
    Not merely stored on the handler — a record has to come out of the stream
    that was asked for. `score_retrieval` depends on this: its diagnostics go to
    stderr so that stdout carries the report alone.
    """
    stream = io.StringIO()

    setup_logging(stream=stream)
    logging.getLogger("scripts.score_retrieval").info("retrieved 25/433")

    assert "retrieved 25/433" in stream.getvalue()
    assert logging.getLogger().handlers[0].stream is stream


def test_a_second_call_does_not_add_a_second_handler():
    """
    Idempotence, restated for the parameter: a second call with a *different*
    stream is still a no-op. Two handlers would double every line, which is the
    failure the marker on the handler was added to prevent.
    """
    first, second = io.StringIO(), io.StringIO()

    setup_logging(stream=first)
    setup_logging(stream=second)

    root = logging.getLogger()
    assert len(root.handlers) == 1
    assert root.handlers[0].stream is first


def test_the_level_asked_for_is_the_level_set():
    """
    `migrations/env.py` relies on the root level reaching INFO. Pinned as a
    literal so a changed default is a failure here rather than a quiet loss of
    every INFO record in an alembic run.
    """
    setup_logging(level=logging.WARNING, stream=io.StringIO())

    assert logging.getLogger().level == 30

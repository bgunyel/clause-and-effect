"""
The LLM call log: where every model call, and every upstream attempt it made,
is recorded.

Designed in :doc:`docs/design/llm-call-log.md`. The package sits directly under
``src/`` rather than inside ``clause_and_effect/`` or ``eval/`` because it spans
both: the product path and the judge path make model calls, and both are logged.

The dependency runs one way only. ``src/config.py`` declares ``DB_URL`` and
knows nothing about this package; this package reads config. Inverting that
would put SQLAlchemy on the import path of all eight modules that import
``config``, against a docstring contract that module states explicitly.

Nothing here is imported on the cheap path. Importing this package costs
SQLAlchemy, and only code that writes to the log should pay it.
"""
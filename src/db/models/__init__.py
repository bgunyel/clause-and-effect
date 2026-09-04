"""
SQLAlchemy models for the LLM call log.

Importing this package is what puts the three tables on ``Base.metadata``, so
Alembic's ``env.py`` imports it for its ``target_metadata`` and an autogenerate
run that skipped it would cheerfully produce a migration dropping every table.
"""
from src.db.models.base import Base
from src.db.models.llm_log import CallStatus, LlmAttempt, LlmCall, LlmRun

__all__ = ["Base", "CallStatus", "LlmAttempt", "LlmCall", "LlmRun"]
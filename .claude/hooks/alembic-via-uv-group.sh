#!/bin/bash
# CLAUDE.md: "Alembic is a `migrations` dependency group, not a runtime
# dependency; the DB URL comes from DB_URL in .env via src.db.engine, never
# from alembic.ini."
#
# A bare `alembic ...` runs outside that group and resolves its environment
# differently, which is the failure mode the doc warns about. Every sanctioned
# invocation in CLAUDE.md and pyproject.toml carries `uv run --group migrations`.
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

if echo "$COMMAND" | grep -qE '(^|[;&|]|\s)alembic(\s|$)'; then
  if ! echo "$COMMAND" | grep -qE 'uv\s+run\s+.*--group\s+migrations'; then
    echo "Blocked: bare alembic invocation. CLAUDE.md pins Alembic to the 'migrations' dependency group. Run it as: uv run --group migrations alembic <args>" >&2
    exit 2
  fi
fi

exit 0

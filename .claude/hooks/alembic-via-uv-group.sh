#!/bin/bash
# CLAUDE.md: "Alembic is a `migrations` dependency group, not a runtime
# dependency; the DB URL comes from DB_URL in .env via src.db.engine, never
# from alembic.ini."
#
# A bare `alembic ...` runs outside that group and resolves its environment
# differently, which is the failure mode the doc warns about. Every sanctioned
# invocation in CLAUDE.md and pyproject.toml carries `uv run --group migrations`.
#
# Issue #69: this hook and pytest-via-uv-group.sh were the two that read a
# command without knowing where one starts. The name was matched after a
# separator or any whitespace, so it matched as an ARGUMENT and as PROSE --
# `grep -rn alembic docs/`, `git log --grep alembic` and
# `echo "we run alembic upgrade head via the group"` were all refused, and the
# allowlist beneath could not rescue them because prose does not carry
# `uv run --group migrations`. The companion file carries the fuller note,
# including why the verdict on a quoted mention depended on which character
# happened to precede the name; the fix is the same one and is made the same
# way, because a rule answered twice is how these two came to disagree with the
# four hooks that already knew the answer.
LIB="$(dirname "$0")/lib/command-scan.sh"
[ -r "$LIB" ] && . "$LIB"
if ! command -v cs_split >/dev/null 2>&1; then
  echo "Blocked: alembic-via-uv-group.sh could not load lib/command-scan.sh, so it cannot tell an alembic invocation from a mention of one. Refusing rather than permitting." >&2
  exit 2
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
CMDS=$(printf '%s\n' "$COMMAND" | cs_normalise | cs_split)

# alembic standing where a command word goes.
if printf '%s\n' "$CMDS" | grep -qE '^alembic([[:space:]]|$)'; then
  echo "Blocked: bare alembic invocation. CLAUDE.md pins Alembic to the 'migrations' dependency group. Run it as: uv run --group migrations alembic <args>" >&2
  exit 2
fi

# `uv run` that reaches alembic without naming the group. Scoped to the one
# fragment, so the group has to be named by the command that runs alembic and
# not merely somewhere on the line, which is what the allowlist asked.
if printf '%s\n' "$CMDS" \
   | grep -E '^uv[[:space:]]+run([[:space:]]|$)' \
   | grep -E '(^|[[:space:]])alembic([[:space:]]|$)' \
   | grep -qvE -e '--group[[:space:]]+migrations([[:space:]]|$)'; then
  echo "Blocked: uv run reaches alembic without the 'migrations' dependency group. CLAUDE.md pins Alembic to that group. Run it as: uv run --group migrations alembic <args>" >&2
  exit 2
fi

exit 0

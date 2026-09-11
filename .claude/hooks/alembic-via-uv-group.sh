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
# `uv run --group migrations`.
#
# The companion file carries the fuller note: why the verdict on a quoted
# mention depended on which character happened to precede the name, why the
# rule about runners is a list, why the group must be named before the tool,
# and what a quote costs as a word boundary. The fix is the same one and is
# made the same way, deliberately -- a rule answered twice is how these two
# came to disagree with the four hooks that already knew the answer, and the
# only honest way to keep them in step is to keep them identical.
LIB="$(dirname "$0")/lib/command-scan.sh"
[ -r "$LIB" ] && . "$LIB"
# Both functions this file calls, not just the one that names the file's
# subject. Testing cs_split alone left cs_normalise unguarded, and a library
# missing only that one permitted a bare `alembic upgrade head` silently.
if ! command -v cs_split >/dev/null 2>&1 \
   || ! command -v cs_normalise >/dev/null 2>&1; then
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

# A runner standing where a command word goes, naming alembic. `uv run` is the
# sanctioned one and is asked for the group; the rest cannot name a dependency
# group at all, so naming alembic is enough to refuse.
UV_RUN='^uv[[:space:]]+run([[:space:]]|$)'
OTHER_RUNNER='^(uvx|uv[[:space:]]+tool[[:space:]]+run|poetry[[:space:]]+run|pdm[[:space:]]+run|hatch[[:space:]]+run|pipenv[[:space:]]+run|rye[[:space:]]+run|conda[[:space:]]+run|micromamba[[:space:]]+run|pixi[[:space:]]+run|pipx[[:space:]]+run|nix[[:space:]]+run)([[:space:]]|$)'
# A quote ends the name as a space does. See the trade in the companion file.
NAME='(^|[^A-Za-z0-9_.-])alembic([^A-Za-z0-9_.-]|$)'

while IFS= read -r FRAGMENT; do
  echo "$FRAGMENT" | grep -qE "$NAME" || continue
  if echo "$FRAGMENT" | grep -qE "$OTHER_RUNNER"; then
    echo "Blocked: that runner reaches alembic outside the 'migrations' dependency group, which it cannot name. CLAUDE.md pins Alembic to that group. Run it as: uv run --group migrations alembic <args>" >&2
    exit 2
  fi
  echo "$FRAGMENT" | grep -qE "$UV_RUN" || continue
  # Everything before the name. The group has to be an argument of uv, not of
  # alembic, and this is what tells the two apart.
  if ! printf '%s' "${FRAGMENT%%alembic*}" \
       | grep -qE -e '--group[[:space:]]+migrations([[:space:]]|$)'; then
    echo "Blocked: uv run reaches alembic without the 'migrations' dependency group named first. CLAUDE.md pins Alembic to that group. Run it as: uv run --group migrations alembic <args>" >&2
    exit 2
  fi
done <<CS_FRAGMENTS
$CMDS
CS_FRAGMENTS

exit 0

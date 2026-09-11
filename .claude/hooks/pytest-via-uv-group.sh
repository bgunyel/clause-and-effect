#!/bin/bash
# CLAUDE.md: the test invocation is `make test`, which is
# `uv run --group test pytest tests/`. pytest lives in the `test` dependency
# group, so a bare `pytest` runs against whatever interpreter is on PATH.
#
# Deliberately narrow: bare `python -m src.scripts...` and
# `python -m src.eval.golden_qa` are the documented forms for the corpus and
# eval entry points and are not matched here.
#
# Issue #69: this hook and alembic-via-uv-group.sh were the two that read a
# command without knowing where one starts. The name was matched after a
# separator or any whitespace, so it matched as an ARGUMENT and as PROSE --
# `grep -rn pytest docs/`, `ls tests/ | grep pytest` and `git log --grep pytest`
# were all refused, and the allowlist beneath could not rescue them because
# prose does not carry `uv run --group test`. Worse than the refusal is that it
# was intermittent: the match needed a separator in front of the name, so
# `echo "pytest lives in the test group"` was permitted only because a quote
# happens not to be in the class, while the same sentence shape with a space
# there was refused. Same shape, opposite verdict, on a difference that has
# nothing to do with what the command would run.
#
# Saying where a command word is is cs_split's job, and this file asks it now
# rather than answering it again. That is the whole of the fix: with the
# command word at ^, an argument and a mention are no longer command positions.
#
# The allowlist went with it, and its replacement is worth writing down because
# it is not simply a deletion. `uv run --group test pytest tests/` has `uv` as
# its command word and never matches the first rule, so the rescue had nothing
# left to rescue. But `uv run pytest` also has `uv` as its command word, and
# that one was refused before and has to stay refused -- it runs pytest outside
# the group, which is the failure this hook is about. So the group is asked for
# on the `uv run` fragment itself, where cs_split has already bounded the
# arguments to one command, rather than anywhere on the line the way the
# allowlist did. `uv pip install pytest` is not `uv run` and is untouched.
LIB="$(dirname "$0")/lib/command-scan.sh"
[ -r "$LIB" ] && . "$LIB"
if ! command -v cs_split >/dev/null 2>&1; then
  echo "Blocked: pytest-via-uv-group.sh could not load lib/command-scan.sh, so it cannot tell a pytest invocation from a mention of one. Refusing rather than permitting." >&2
  exit 2
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
CMDS=$(printf '%s\n' "$COMMAND" | cs_normalise | cs_split)

# pytest, or python -m pytest, standing where a command word goes.
if printf '%s\n' "$CMDS" \
   | grep -qE '^(pytest|python[0-9.]*[[:space:]]+-m[[:space:]]+pytest)([[:space:]]|$)'; then
  echo "Blocked: bare pytest invocation. CLAUDE.md runs tests through the 'test' dependency group. Use: make test, or uv run --group test pytest tests/<file>::<test>" >&2
  exit 2
fi

# `uv run` that reaches pytest without naming the group.
if printf '%s\n' "$CMDS" \
   | grep -E '^uv[[:space:]]+run([[:space:]]|$)' \
   | grep -E '(^|[[:space:]])pytest([[:space:]]|$)' \
   | grep -qvE -e '--group[[:space:]]+test([[:space:]]|$)'; then
  echo "Blocked: uv run reaches pytest without the 'test' dependency group. CLAUDE.md runs tests through that group. Use: make test, or uv run --group test pytest tests/<file>::<test>" >&2
  exit 2
fi

exit 0

#!/bin/bash
# CLAUDE.md: the test invocation is `make test`, which is
# `uv run --group test pytest tests/`. pytest lives in the `test` dependency
# group, so a bare `pytest` runs against whatever interpreter is on PATH.
#
# Deliberately narrow: bare `python -m src.scripts...` and
# `python -m src.eval.golden_qa` are the documented forms for the corpus and
# eval entry points and are not matched here.
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

if echo "$COMMAND" | grep -qE '(^|[;&|]|\s)(pytest|python[0-9.]*\s+-m\s+pytest)(\s|$)'; then
  if ! echo "$COMMAND" | grep -qE 'uv\s+run\s+.*--group\s+test|make\s+test'; then
    echo "Blocked: bare pytest invocation. CLAUDE.md runs tests through the 'test' dependency group. Use: make test, or uv run --group test pytest tests/<file>::<test>" >&2
    exit 2
  fi
fi

exit 0

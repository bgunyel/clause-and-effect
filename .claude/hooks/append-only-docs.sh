#!/bin/bash
# CLAUDE.md: docs/dev-log/, docs/lessons-learned/ and docs/eval-reports/ are
# append-only. "Old entries are history — corrections go in the newest entry,
# never backwards."
#
# Adding a new entry file is the normal case and stays allowed; so does a >>
# append. What is blocked is destroying or rewriting what is already recorded.
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

APPEND_ONLY='docs/(dev-log|lessons-learned|eval-reports)/'

if echo "$COMMAND" | grep -qE "$APPEND_ONLY"; then
  # rm / mv / cp over an existing entry
  if echo "$COMMAND" | grep -qE "(^|[;&|]|\s)(rm|mv|cp)\s+[^;&|]*$APPEND_ONLY"; then
    echo "Blocked: removing or overwriting a file under an append-only docs directory. CLAUDE.md treats docs/dev-log/, docs/lessons-learned/ and docs/eval-reports/ as history; corrections belong in a new entry." >&2
    exit 2
  fi
  # in-place rewrite
  if echo "$COMMAND" | grep -qE "(^|[;&|]|\s)(sed|perl)\s+[^;&|]*-i" && echo "$COMMAND" | grep -qE "$APPEND_ONLY"; then
    echo "Blocked: in-place edit of an append-only docs file. CLAUDE.md treats docs/dev-log/, docs/lessons-learned/ and docs/eval-reports/ as history; corrections belong in a new entry." >&2
    exit 2
  fi
  # truncating redirect (single >), but not an >> append
  if echo "$COMMAND" | grep -qE "[^>]>\s*[^>|&]*$APPEND_ONLY"; then
    echo "Blocked: truncating redirect into an append-only docs file. Use >> to append, or write a new entry. CLAUDE.md treats these directories as history." >&2
    exit 2
  fi
fi

exit 0

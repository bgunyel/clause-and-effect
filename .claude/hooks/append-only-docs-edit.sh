#!/bin/bash
# Companion to append-only-docs.sh, which only sees Bash commands. This one
# covers the Edit and Write tools, where the append-only directories were
# otherwise reachable without passing through a shell at all.
#
# CLAUDE.md: docs/dev-log/, docs/lessons-learned/ and docs/eval-reports/ are
# append-only. "Old entries are history — corrections go in the newest entry,
# never backwards."
#
# The distinction that matters is existence, not tool: writing a NEW entry file
# is the normal way to record a session, so a Write to a path that does not yet
# exist is allowed. Touching a file that is already there is what rewrites
# history, and that is blocked for both tools.
#
# docs/design/ is deliberately absent from the guarded set — CLAUDE.md's own
# table marks it "revised in place".
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[ -z "$FILE" ] && exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
case "$FILE" in
  /*) ABS="$FILE" ;;
  *)  ABS="$ROOT/$FILE" ;;
esac

# Anchor to the project root so an identically-named path in another checkout
# is not caught by a bare substring match.
REL="${ABS#"$ROOT"/}"

if echo "$REL" | grep -qE '^docs/(dev-log|lessons-learned|eval-reports)/'; then
  # A README describes its directory rather than recording a session, a failure
  # or a measurement. CLAUDE.md's rule is about entries — "old entries are
  # history" — so the directory's own description stays revisable in place,
  # exactly as docs/design/README.md is.
  if basename "$REL" | grep -qE '^README\.md$'; then
    exit 0
  fi
  if [ -e "$ABS" ]; then
    echo "Blocked: editing an existing file under an append-only docs directory ($REL). CLAUDE.md treats docs/dev-log/, docs/lessons-learned/ and docs/eval-reports/ as history; corrections go in the newest entry, never backwards. Writing a new entry file is allowed." >&2
    exit 2
  fi
fi

exit 0

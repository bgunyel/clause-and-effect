#!/bin/bash
# CLAUDE.md: docs/dev-log/, docs/lessons-learned/ and docs/eval-reports/ are
# append-only. "Old entries are history — corrections go in the newest entry,
# never backwards."
#
# Adding a new entry file is the normal case and stays allowed; so does a >>
# append. What is blocked is destroying or rewriting what is already recorded.
#
# docs/research/ was considered for this set and deliberately left out (issue
# #61). A research document carries [NEEDS OBSERVATION] markers, and clearing
# one as the observation is made is the edit the directory exists to allow;
# CLAUDE.md's table marks it "revised in place" for that reason. The same is
# true of docs/design/. See the companion note in append-only-docs-edit.sh.
#
# Issue #69: the directory pattern required a trailing slash, so the removal
# that destroys the most history was the one thing this hook did not see.
# `rm -rf docs/dev-log` was permitted and `rm -rf docs/dev-log/` refused -- the
# same command, one character apart, opposite verdicts, and the permitted half
# takes every entry with it. The boundary is written out now instead: a slash,
# or any character that cannot continue a path name, or the end of the string.
# It is not simply made optional, because `docs/dev-logbook/` is a different
# directory and must stay untouched.
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# The trailing group is the directory boundary, and it is what #69 was about.
# `.` and `-` are path-name characters here so that `docs/dev-log.bak` and
# `docs/dev-logbook` are other paths rather than this one; a quote, a space or
# a separator ends the name and is matched.
APPEND_ONLY='docs/(dev-log|lessons-learned|eval-reports)(/|[^A-Za-z0-9_.-]|$)'

if echo "$COMMAND" | grep -qE "$APPEND_ONLY"; then
  # rm / mv / cp over an existing entry, or over the directory itself.
  #
  # truncate and tee are here because both overwrite an entry in place without
  # naming a redirect, so the two rules below saw neither: `truncate -s 0` and
  # `tee <path> < new.md` were both measured permitted in #69. The list is what
  # has been measured and nothing more -- a verb added on a guess is a rule no
  # check asks about.
  #
  # The trade, taken knowingly: `tee -a` appends, which is the operation this
  # directory exists to allow, and it is refused here with the truncating
  # spelling because the verb is read and its options are not. `>>` is the
  # documented way to append and stays permitted; the check suite pins the
  # refusal so that it is a decision rather than a surprise.
  if echo "$COMMAND" | grep -qE "(^|[;&|]|\s)(rm|mv|cp|truncate|tee)\s+[^;&|]*$APPEND_ONLY"; then
    echo "Blocked: removing or overwriting an append-only docs directory, or a file under one. CLAUDE.md treats docs/dev-log/, docs/lessons-learned/ and docs/eval-reports/ as history; corrections belong in a new entry." >&2
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

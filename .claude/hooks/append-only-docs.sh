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
#
# Issue #95: the command was read with its own `jq -r`, so jq missing or a tool
# call that was not JSON left it empty and every overwrite permitted. It is read
# through cs_tool_input now, the reader every hook shares; see THE INPUT READ in
# lib/command-scan.sh. Issue #96 is the other function this file takes from the
# library: every Bash hook runs under the 5 s timeout in settings.json, a hook
# the harness kills permits, and the cap on line length that stops that is
# answered once, there. Its grep passes answered a 300 KB line in 0.03 s and
# were never the risk; the cap is here because a rule that reaches every Bash
# hook but one is the shape #84 was filed against. This file still matches paths
# where they stand rather than through the tokeniser. The library is tested for
# before it is sourced, and both functions after, for THE LOAD CONTRACT's reason.
LIB="$(dirname "$0")/lib/command-scan.sh"
[ -r "$LIB" ] && . "$LIB"
if ! command -v cs_tool_input >/dev/null 2>&1 \
   || ! command -v cs_within_cap >/dev/null 2>&1; then
  echo "Blocked: append-only-docs.sh could not load lib/command-scan.sh, so it cannot read the command it was handed, or hold the line cap every Bash hook holds. Refusing rather than permitting." >&2
  exit 2
fi

COMMAND=$(cs_tool_input command) || exit 2
# THE LINE CAP, in lib/command-scan.sh: a line longer than 16 KB is refused
# before any pass reads it, because a hook still reading when the harness
# timeout kills it permits. Issue #96.
if ! printf '%s\n' "$COMMAND" | cs_within_cap; then
  echo "Blocked: append-only-docs.sh: $CS_LINE_CAP_REFUSAL" >&2
  exit 2
fi

# The trailing group is the directory boundary, and it is what #69 was about.
# `.` and `-` are path-name characters here so that `docs/dev-log.bak` and
# `docs/dev-logbook` are other paths rather than this one; a quote, a space or
# a separator ends the name and is matched.
#
# The leading `/+(\./+)*` is the same finding on the other side of the slash,
# found by review of the fix above rather than by the issue. This hook compares
# spellings, exactly as append-only-docs-edit.sh did before #69 normalised it,
# and the spellings that a shell reduces to the same directory were permitted:
# `rm -rf docs//dev-log` and `rm -rf docs/./dev-log` both were. Nothing here
# can normalise the way the Edit companion does -- the path is embedded in a
# command rather than handed over as one -- so the two spellings a reader
# actually writes are matched where they stand. That is a narrower answer than
# the companion's and it is named as one: `docs/foo/../dev-log` is still
# permitted, and closing that would mean parsing paths out of shell text.
APPEND_ONLY='docs/+(\./+)*(dev-log|lessons-learned|eval-reports)(/|[^A-Za-z0-9_.-]|$)'

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

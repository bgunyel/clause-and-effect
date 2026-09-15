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
# docs/design/ and docs/research/ are deliberately absent from the guarded set —
# CLAUDE.md's own table marks both "revised in place". For research/ the
# omission is load-bearing rather than incidental: a research document carries
# [NEEDS OBSERVATION] markers, and clearing one as the observation is made is
# the edit the directory exists to allow.
#
# Issue #69: the project root was stripped off by string prefix and the result
# anchored at ^docs/, so the comparison was between spellings rather than
# between paths. Any spelling of a guarded file that did not reduce to that one
# literal prefix was permitted, on a file that exists -- `./docs/dev-log/<entry>`
# and `docs/../docs/dev-log/<entry>` both were. A leading `./` is not an evasion;
# it is an ordinary way to write a relative path, which is the shape of the
# ordinary mistake this hook exists to stop.
#
# Issue #95: the path was read with `jq -r '.tool_input.file_path // empty'`, so
# jq missing, stdin that was not JSON, and a file_path that was null, false or
# absent all became "no file" and were permitted before any path was compared.
# The read is cs_tool_input now, the one reader every hook shares, and THE INPUT
# READ in lib/command-scan.sh states what it refuses. This file sources the
# library for that function alone -- the tokeniser's questions are not this
# file's -- because a second copy of the read is a second answer to it, and #95
# found eight. Tested for before it is sourced and the reader after, for THE
# LOAD CONTRACT's reason.
LIB="$(dirname "$0")/lib/command-scan.sh"
[ -r "$LIB" ] && . "$LIB"
if ! command -v cs_tool_input >/dev/null 2>&1; then
  echo "Blocked: append-only-docs-edit.sh could not load lib/command-scan.sh, so it cannot read which file this edit touches. Refusing rather than permitting." >&2
  exit 2
fi

FILE=$(cs_tool_input file_path) || exit 2

# An empty file_path string is read and permitted, as it was. #95 names the
# empty string as the one fail-open case for a command, where there is nothing
# to run; an empty path names no file, so there is nothing here to protect
# either. Recorded because the issue left it to this file, and pinned.
[ -z "$FILE" ] && exit 0

# Collapse `.`, `..` and repeated slashes, lexically. This is what `realpath -ms`
# does, written out rather than shelled out to: the hook already depends on jq,
# and a second external tool would be a second thing that can be absent. Since
# #95 the answer to jq being absent is to refuse every edit in the repository,
# which is a trade taken once and named; a second tool would take it twice, on
# a tool the reader does not need.
#
# Lexical, not physical: no symlink is resolved. That is deliberate as well as
# cheap. Resolving the file and not the root, or either through a root that is
# itself reached by a symlink, is how the two sides stop being comparable --
# which is the defect above in a second spelling. Both sides go through the same
# function here and neither touches the filesystem, so they cannot disagree.
# A guarded file reached through a symlink is therefore still permitted; that is
# a smaller hole than the one being closed, and it is not a spelling anyone
# writes by accident.
#
# It carries no cs_ prefix on purpose. That namespace belongs to
# lib/command-scan.sh, which this hook sources for its input reader alone and
# which otherwise answers a different question -- where a command word is, not
# what a path reduces to.
# Its sibling append-only-docs.sh cannot use this function either: the path
# there is embedded in a command rather than handed over as one, so that file
# matches the two spellings where they stand and says so.
norm_path() {  # norm_path <absolute path>
  local seg out="" oldopts=$-
  # The loop splits on / by word splitting, which would also glob each segment
  # against the tree. Both call sites are command substitutions, so the restore
  # below has nothing to restore today; it is kept so that a later call which
  # is NOT a substitution does not leave globbing off for the rest of the hook.
  set -f
  local IFS=/
  for seg in $1; do
    case "$seg" in
      ''|.) ;;
      ..)   out="${out%/*}" ;;
      *)    out="$out/$seg" ;;
    esac
  done
  case $oldopts in *f*) ;; *) set +f ;; esac
  printf '%s' "${out:-/}"
}

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
case "$FILE" in
  /*) ABS="$FILE" ;;
  *)  ABS="$ROOT/$FILE" ;;
esac
ROOT=$(norm_path "$ROOT")
ABS=$(norm_path "$ABS")

# Anchor to the project root so an identically-named path in another checkout
# is not caught by a bare substring match. Both sides are normalised first, so
# what is compared is the path rather than the way it was typed.
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

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

# stdin is buffered because this hook reads more than one field of the tool
# call: the path, and -- for #177's heading exception below -- the two strings
# an Edit would swap. `cs_tool_input` is `jq -rs`, which slurps, so a second
# call on the same stdin would read an empty stream and refuse. Buffering keeps
# ONE reader, which is #95's finding: a second copy of the read is a second
# answer to it, and #95 found eight. Every refusal this hook already made on
# malformed input is made here unchanged, because what jq is handed is the same
# bytes -- the command substitution strips trailing newlines, which JSON does
# not carry meaning in, and a JSON document cannot hold a NUL.
PAYLOAD=$(cat)
FILE=$(printf '%s' "$PAYLOAD" | cs_tool_input file_path) || exit 2

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

# --- #177: the one line of an entry that is metadata rather than history -----
#
# ADR 0003 decides that the session segment of a `docs/dev-log/` entry's heading
# is the entry's label and not a statement of history a reader relies on, so it
# may be corrected in place when it contradicts the file name. This is the whole
# of that exception, written as a conjunction so each clause reads against the
# ADR's sentence:
#
#   the file is a docs/dev-log/ entry named devlog_<date>_<session>.md;
#   the tool call carries both strings an Edit swaps (a Write carries neither);
#   old_string is the file's current first line, and occurs in it exactly once;
#   new_string is one line;
#   both parse as `# <date> · <session> — <rest>`;
#   the date and the rest are byte-identical between them;
#   the new session agrees with the file's, and the old one does not.
#
# Everything else about a history entry is refused exactly as it was. The last
# clause is what keeps this from being a licence: an edit is permitted only
# towards the name the file already has, so the guard can move the label onto
# the file and can move nothing else anywhere.
#
# Agreement is deliberately not string equality. A file's session name is
# hyphenated throughout and a heading's is not uniformly so -- `session-5` is
# written `session 5`, `session-dev-issue-117` is written `session dev-issue-117`
# and `dev-issue-141` keeps its hyphens -- so both sides collapse every run of
# spaces and hyphens to a single hyphen before being compared. That makes
# `session-5` against `session 2` a contradiction and `session-5` against
# `session 5` agreement, which is the distinction the decision rests on.
#
# The heading's date is NOT required to equal the file's. An entry may open
# `# 2026-09-17 21:53 · dev-issue-141 — …`, where the segment before the
# separator carries a time the file name has no room for. Requiring equality
# would refuse the correction on exactly those entries. What is required is that
# the date segment does not MOVE, which is what keeps this exception to one part
# of one line.
#
# No external tool is added. `grep` is already this hook's dependency two lines
# below; the normalisation is written out in bash for the reason `norm_path` is,
# so that a hook whose answer to a missing tool is to refuse every edit in the
# repository does not gain a second tool that can be missing.
norm_session() {  # norm_session <session as written> -- its comparable form
  local s="$1" out="" c prev=""
  while [ -n "$s" ]; do
    c=${s:0:1}; s=${s:1}
    case "$c" in
      ' '|-) [ "$prev" = '-' ] || out="$out-"; prev='-' ;;
      *)     out="$out$c"; prev="$c" ;;
    esac
  done
  printf '%s' "$out"
}

# Sets PH_DATE, PH_SESS and PH_REST from an entry heading; non-zero if the line
# is not one. The separators are the ones the entries and the README's index are
# written with, ` · ` and ` — `, and each is required to be present rather than
# defaulted, so a line that is not a heading cannot parse as one with empty parts.
parse_heading() {  # parse_heading <line>
  local line="$1" body after
  case "$line" in '# '*) ;; *) return 1 ;; esac
  body=${line#\# }
  case "$body" in *" · "*) ;; *) return 1 ;; esac
  PH_DATE=${body%%" · "*}
  after=${body#*" · "}
  case "$after" in *" — "*) ;; *) return 1 ;; esac
  PH_SESS=${after%%" — "*}
  PH_REST=${after#*" — "}
  [ -n "$PH_DATE" ] && [ -n "$PH_SESS" ]
}

heading_correction() {  # heading_correction <abs> <rel> -- 0 if this edit is the permitted one
  local abs="$1" rel="$2" stem fsession old new first
  local o_date o_sess o_rest n_date n_sess n_rest

  case "$rel" in docs/dev-log/*) ;; *) return 1 ;; esac

  stem=${abs##*/}
  case "$stem" in *.md) stem=${stem%.md} ;; *) return 1 ;; esac
  case "$stem" in devlog_*) stem=${stem#devlog_} ;; *) return 1 ;; esac
  case "$stem" in *_*) fsession=${stem#*_} ;; *) return 1 ;; esac
  [ -n "$fsession" ] || return 1

  # A Write carries no old_string, so this is where a Write of an existing entry
  # leaves the exception and goes back to being refused.
  old=$(printf '%s' "$PAYLOAD" | cs_tool_input old_string 2>/dev/null) || return 1
  new=$(printf '%s' "$PAYLOAD" | cs_tool_input new_string 2>/dev/null) || return 1
  # REDUNDANT, AND KEPT KNOWINGLY. Hand-mutation of this hook found that deleting
  # both lines flips no payload the suite drives: a newline in `new` moves the
  # rest of the heading, which the rest-unchanged test below refuses, and a
  # newline in `old` stops it equalling the file's first line, which that test
  # refuses. So no check fails without them, which by CLAUDE.md's standard is a
  # reason to look hard at a clause. They stay because they say the shape the
  # exception is about -- one line swapped for one line -- where the tests that
  # currently cover them say something else and cover this only as a side effect.
  # A reader who later reorders those tests should find this stated rather than
  # discover it. Recorded because an unexercised clause read as evidence is
  # exactly what this repository keeps finding.
  case "$new" in *$'\n'*) return 1 ;; esac
  case "$old" in *$'\n'*) return 1 ;; esac

  IFS= read -r first < "$abs" 2>/dev/null
  [ -n "$first" ] || return 1
  [ "$old" = "$first" ] || return 1
  [ "$(grep -cxF -- "$old" "$abs" 2>/dev/null)" = 1 ] || return 1

  parse_heading "$old" || return 1
  o_date=$PH_DATE o_sess=$PH_SESS o_rest=$PH_REST
  parse_heading "$new" || return 1
  n_date=$PH_DATE n_sess=$PH_SESS n_rest=$PH_REST

  [ "$o_date" = "$n_date" ] || return 1
  [ "$o_rest" = "$n_rest" ] || return 1

  fsession=$(norm_session "$fsession")
  [ "$(norm_session "$n_sess")" = "$fsession" ] || return 1
  [ "$(norm_session "$o_sess")" != "$fsession" ] || return 1
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
    # ADR 0003 (#177). The one part of one line that is the entry's label rather
    # than its history, corrected only onto the name the file already carries.
    if heading_correction "$ABS" "$REL"; then
      exit 0
    fi
    echo "Blocked: editing an existing file under an append-only docs directory ($REL). CLAUDE.md treats docs/dev-log/, docs/lessons-learned/ and docs/eval-reports/ as history; corrections go in the newest entry, never backwards. Writing a new entry file is allowed. The one exception (ADR 0003, #177) is an Edit that changes only the session segment of a docs/dev-log/ entry's first-line heading, to agree with the session the file is named for." >&2
    exit 2
  fi
fi

exit 0

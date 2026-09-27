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
# history, and that is blocked for both tools -- with one exception, an Edit of
# the session segment of a docs/dev-log/ entry's heading onto the name the file
# already carries, which ADR 0003 decides is the entry's label and not its
# history (#177). Its section below states the whole of it.
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
# document -- the command substitution strips trailing newlines, which JSON does
# not carry meaning in.
#
# AND IT DROPS EVERY NUL, which is a different matter: a JSON document cannot
# hold a raw NUL, but the STREAM can, and a stream holding one is exactly the
# malformed input jq refused before this buffer existed. With a bare `$(cat)` a
# valid document followed by a NUL, or a NUL inside the file_path string, reached
# jq with the NUL gone and parsed (review of #189, round 2). So each NUL becomes a
# \001 on the way in. That is the identity on every valid document, which holds
# neither byte raw, and on every other stream it swaps one byte jq rejects for
# another it rejects wherever it stands -- outside a string it is no token, and
# inside one it is an unescaped control character -- so jq's verdict is the one
# it gave the raw stream. No #95 row went red when the NUL started being dropped,
# and none could have: each is fed through a bash string, which cannot carry one.
# `tr` is coreutils, like the `cat` beside it; a `tr` that is not there leaves
# the buffer empty, and an empty buffer is refused by the reader.
# `read -d ''` would have kept the NULs without a second tool, and was measured
# and rejected: bash reads a pipe one byte at a time, 0.4 s a megabyte, and a
# large Write would meet this hook's 5-second timeout, and a hook that times out
# has refused nothing.
#
# That argument is about the DOCUMENT and not about the strings inside it, which
# is why the two strings #177 compares are not read the way the path is: see
# `field_exact` below.
PAYLOAD=$(cat | tr '\000' '\001')
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
#   the tool call is an Edit -- it carries no `content`, which every Write does --
#   and carries both strings an Edit swaps, neither holding a NUL;
#   old_string is the file's current first line, and occurs in the file
#   exactly once as the Edit tool matches it -- as a substring, not a line;
#   new_string is one line;
#   both parse as `# <date> · <session> — <rest>`;
#   the date and the rest are byte-identical between them;
#   the new session is a spelling the file's name gives, and the old one does
#   not already name that session.
#
# Everything else about a history entry is refused exactly as it was. The last
# clause is what keeps this from being a licence: an edit is permitted only
# towards the name the file already has, so the guard can move the label onto
# the file and can move nothing else anywhere.
#
# AGREEMENT IS ASKED TWO WAYS, because its two tests err in opposite directions
# (review of #189, round 3). Round 2 had one normalisation serve both, so every
# spelling added to let the OLD segment agree was also a spelling the NEW segment
# could be written in; and every spelling it missed on the old side read as a
# contradiction and permitted rewriting a heading that was right. Review measured
# both at once: `Session 5`, a tab, `session: <name>` and `*<name>*` each still
# read as contradicting their file's name, and a lone backtick was a label the
# exception would write -- one that pairs with a backtick in the rest and renders
# a code span across the separator, with every byte of the rest unchanged.
#
# The OLD segment is asked whether it already names the file's session, and a
# yes refuses, so it is asked loosely: `session_key` lowercases both sides, keeps
# only letters and digits, and takes a leading `session` off. Any spelling that
# differs from the name only in case, punctuation, spacing or that word agrees --
# `session 5` with `session-5`, session `dev-agent-pr-184` with
# `dev-agent-pr-184`. However loose, it can only refuse more; it could make two
# different names agree only where they differ in nothing but those.
#
# The NEW segment is what the exception writes, so it is asked strictly: it must
# be byte-equal to one of the three spellings the file name gives, with <n> the
# file's session less a leading `session-` -- `<n>`, `session <n>`, or `session`
# and <n> quoted as code. `session-5` accepts `5`, `session 5` and the quoted 5;
# `dev-issue-141` accepts `dev-issue-141` and the two with the word. They are the
# three the real headings are written in, and nothing else can be written, so a
# spelling the old side comes to know later widens nothing the exception permits.
#
# The heading's date is NOT required to equal the file's. An entry may open
# `# 2026-09-17 21:53 · dev-issue-141 — …`, where the segment before the
# separator carries a time the file name has no room for. Requiring equality
# would refuse the correction on exactly those entries. What is required is that
# the date segment does not MOVE, which is what keeps this exception to one part
# of one line.
#
# No external tool is added for the exception. `grep` is already this hook's
# dependency; the session tests are written in bash builtins for the reason `norm_path`
# is, so that a hook whose answer to a missing tool is to refuse every edit in the
# repository does not gain a second tool that can be missing. The `tr` on the
# buffer above is the input's, not the exception's, and is argued there.
session_key() {  # session_key <session as written> -- lowercased letters and digits, less a leading `session`
  local s=${1,,}
  s=${s//[^[:alnum:]]/}
  case "$s" in session?*) s=${s#session} ;; esac
  printf '%s' "$s"
}
canonical_session() {  # canonical_session <file's session> <segment> -- 0 if the segment is a spelling the name gives
  local n="$1"
  case "$n" in session-?*) n=${n#session-} ;; esac
  case "$2" in "$n"|"session $n"|"session \`$n\`") return 0 ;; esac
  return 1
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

# Sets <var> to tool_input.<field> exactly as the tool call carries it, trailing
# newlines included; non-zero, having refused as cs_tool_input refuses, if the
# field cannot be read. THE STRINGS ARE COMPARED AS THE TOOL WILL ACT ON THEM.
# A command substitution strips every trailing newline, so `old=$(... old_string)`
# handed this function's tests a copy the Edit tool never sees: an old_string of
# the heading and its newline equalled the first line, passed every test below,
# and the tool then joined the first body line onto the heading. An old_string
# ending in a newline is what an agent writes when it copies a whole line, so
# that was an ordinary shape and not a contrived one (review of #189, round 1).
# jq -r ends its output with exactly one newline of its own; the `x` holds every
# newline before it through the substitution, and the one jq added is taken off.
field_exact() {  # field_exact <var> <field>
  local _raw
  _raw=$(printf '%s' "$PAYLOAD" | cs_tool_input "$2" && printf x) || return 2
  _raw=${_raw%x}
  printf -v "$1" '%s' "${_raw%$'\n'}"
}

heading_correction() {  # heading_correction <abs> <rel> -- 0 if this edit is the permitted one
  local abs="$1" rel="$2" stem fsession old new first content written
  local o_date o_sess o_rest n_date n_sess n_rest

  case "$rel" in docs/dev-log/*) ;; *) return 1 ;; esac

  stem=${abs##*/}
  case "$stem" in *.md) stem=${stem%.md} ;; *) return 1 ;; esac
  case "$stem" in devlog_*) stem=${stem#devlog_} ;; *) return 1 ;; esac
  case "$stem" in *_*) fsession=${stem#*_} ;; *) return 1 ;; esac
  [ -n "$fsession" ] || return 1

  # A NUL is the one byte a bash string cannot hold: jq -r writes a `\u0000` out
  # as a NUL and the substitution drops it, so a new_string ending in one read
  # here as the corrected heading and the tool wrote the NUL into the entry. The
  # escape is the only way a JSON document spells a NUL, so it is refused where
  # it is spelled, before any string is read. Refusing the escape anywhere in the
  # document also refuses a `\\u0000` that is only text, which costs a refusal
  # and never a permission (review of #189, round 1, measured with the sweep of
  # that round's class A).
  case "$PAYLOAD" in *'\u0000'*) return 1 ;; esac
  # A WRITE IS NEVER THE EXCEPTION, whatever else it carries. It was told apart
  # by lacking an old_string, which is the tool inferred from the payload's shape:
  # a Write that also carried old_string and new_string was judged as the Edit
  # they describe and permitted, and would have replaced the whole entry (review
  # of #189, round 2, which did not measure whether the harness can deliver one).
  # The tool's name is not read, because the one reader reads tool_input only and
  # GH-95.2 holds that no hook calls jq itself. So it is told apart by the field
  # a Write cannot be sent without: a call carrying a `content` string is refused
  # here, which is every Write, and an Edit never carries one.
  field_exact written content 2>/dev/null && return 1
  # A Write carries no old_string either, and an Edit without one is not the
  # exception.
  field_exact old old_string 2>/dev/null || return 1
  field_exact new new_string 2>/dev/null || return 1
  # REDUNDANT, AND KEPT KNOWINGLY. A newline in `new` moves the rest of the
  # heading, which the rest-unchanged test below refuses, and a newline in `old`
  # stops it equalling the file's first line, which that test refuses. So no
  # payload flips when both lines are deleted, which by CLAUDE.md's standard is a
  # reason to look hard at a clause. They stay because they say the shape the
  # exception is about -- one line swapped for one line -- where the tests that
  # cover them say something else and cover this only as a side effect.
  # WHAT THEY DID NOT DO BEFORE #189's FIRST ROUND: the strings were read through
  # a command substitution, which strips trailing newlines, so the one newline an
  # agent actually writes -- at the end -- never reached these tests or the ones
  # that back them, and an old_string of the heading and its newline was
  # permitted. The tests were right and were asked of the wrong string; the fix
  # was the read, `field_exact`, and not these lines.
  case "$new" in *$'\n'*) return 1 ;; esac
  case "$old" in *$'\n'*) return 1 ;; esac

  IFS= read -r first < "$abs" 2>/dev/null
  [ -n "$first" ] || return 1
  [ "$old" = "$first" ] || return 1
  # OCCURS EXACTLY ONCE, COUNTED IN THE TOOL'S UNIT. The Edit tool matches
  # old_string as a substring anywhere in the file, and with `replace_all` it
  # replaces every match. This was `grep -cxF`, which counts whole LINES, so an
  # entry quoting its own heading inside a body line -- in backticks, or behind a
  # `> ` -- counted once, and `replace_all` then rewrote the quotation too
  # (review of #189, round 1). Counted here as a substring, and overlapping: old
  # is the first line, so its first match starts at the file's first character,
  # and the file from its second character on must not hold another. That is at
  # least the tool's count however the tool counts, so `replace_all` has nothing
  # left to widen and is not read. The file is read with the same `x` as
  # `field_exact`, so its trailing newlines are its own; a NUL in the file is
  # dropped, here as by `read` above, which can only join text into a further
  # match, and so can only refuse.
  content=$(cat -- "$abs" 2>/dev/null && printf x) || return 1
  content=${content%x}
  case "${content:1}" in *"$old"*) return 1 ;; esac

  parse_heading "$old" || return 1
  o_date=$PH_DATE o_sess=$PH_SESS o_rest=$PH_REST
  parse_heading "$new" || return 1
  n_date=$PH_DATE n_sess=$PH_SESS n_rest=$PH_REST

  [ "$o_date" = "$n_date" ] || return 1
  [ "$o_rest" = "$n_rest" ] || return 1

  canonical_session "$fsession" "$n_sess" || return 1
  [ "$(session_key "$o_sess")" != "$(session_key "$fsession")" ] || return 1
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

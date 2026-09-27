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
# Issue #159: #69 normalised both sides and kept the anchor, so the comparison
# was between paths but still against one root, the main checkout's -- and an
# entry in a linked worktree, where every agent works, was permitted. Whether a
# path is guarded is read off its own segments now; see GUARDED_RE below, and
# the trade it takes.
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
# it gave the raw stream. That rests on jq rejecting a raw control character in a
# string, which jq 1.7 does (measured, exit 5; the CI runner's Ubuntu 24.04 ships
# 1.7.1). jq 1.6 is said to accept one, which is not measured: there a NUL inside
# a string would read as \001, the path or string would name nothing real, and
# the row that feeds one would go red -- a false red, and no worse than before. No #95 row went red when the NUL started being dropped,
# and none could have: each is fed through a bash string, which cannot carry one.
# `tr` is coreutils, like the `cat` beside it; a `tr` that is not there leaves
# the buffer empty, and an empty buffer is refused by the reader.
# THE BUFFER'S OWN COST, measured and left (review of #189, round 6). Emitting a
# large bash string into a pipe runs at about 23 ms a megabyte, whether by
# `printf`, `echo` or a here-string, so every call reading a field pays it once
# more than the base did: a 30 MB Write to an unguarded path takes 1.1 s against
# 0.23 s, and a Write of an existing entry meets the 5-second timeout at about
# 130 MB against about 600 MB. Closing it means buffering to a temporary file,
# which adds `mktemp`, a cleanup trap and a writable directory to what a guard
# needs, for a payload size no agent writes by accident; so it is recorded
# rather than closed, the stopping rule this repository's hooks are held to.
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
#   the file is under docs/dev-log/, at any depth, named devlog_<x>_<session>.md,
#   where <x> is anything without an underscore -- the date the README names is
#   not checked, since the label is moved only onto the name the file carries;
#   the tool call carries no `content` string, which every Write the harness
#   sends does, and carries both strings an Edit swaps, neither holding a NUL;
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
# different names agree only where they differ in nothing but those. It is
# equality of keys and not containment, so an old segment that names the session
# and says more -- `session 3 (continued)` -- has a different key, and the
# correction would erase the rest; that case is #245's (review of #189, round 4).
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
# The exception adds no tool. It reads the entry with `read` and with `cat`,
# which the buffer above already runs, and the rest is bash builtins, for the
# reason `norm_path` is: a hook whose answer to a missing tool is to refuse every
# edit in the repository should not gain a second tool that can be missing. The
# `tr` on the buffer is the input's, not the exception's, and is argued there.
# This said the exception's dependency was `grep` until review of #189, round 5,
# found it had not used `grep` since round 1 replaced the line count.
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
#
# EACH FIELD IS BOUNDED, because both are cut at a separator's first occurrence
# and nothing else says where a field ends. The session runs to the first ` — `
# and so cannot hold one, but it could hold a ` · `: `# <date> · 21:53 · <name>
# — …` parsed with the time inside the session, and the correction deleted it. So
# a session holding ` · ` is not a heading of this shape (review of #189, round
# 4). The date runs to the first ` · `, and it is bounded by being a date: one of
# the three shapes every real heading's date segment has -- `YYYY-MM-DD`,
# `YYYY-MM-DD HH:MM` and `YYYY-MM-DD HH:MM +ZZ`, 30, 2 and 4 of the 36 that parse
# when review counted them. Round 4 bounded it by refusing a ` — ` in it, which
# closed the em dash of `# <date> — <summary>`, the shape the newest entries
# open with, and nothing else: an en dash, a `--` or a colon after the date still
# let a ` · x — ` inside the summary parse as a session made of summary text,
# and the correction rewrote it (round 5). A shape closes every such spelling at
# once. An empty date fails it too, so the closing test asks only that the
# session is not empty. The test that a ` · ` is there at all is backed by the
# shape and the ` — ` test together -- without one the whole body is the date --
# and stays because it states the shape, as the single-line tests do. The rest
# is the remainder, and bounds nothing after it.
parse_heading() {  # parse_heading <line>
  local line="$1" body after
  case "$line" in '# '*) ;; *) return 1 ;; esac
  body=${line#\# }
  case "$body" in *" · "*) ;; *) return 1 ;; esac
  PH_DATE=${body%%" · "*}
  # These three patterns are copied into the real-directory loop of
  # checks/GH-177.sh, which cannot call this function; add a shape to both.
  case "$PH_DATE" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' '[0-9][0-9]:[0-9][0-9]) ;;
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' '[0-9][0-9]:[0-9][0-9]' '[+-][0-9][0-9]) ;;
    *) return 1 ;;
  esac
  after=${body#*" · "}
  case "$after" in *" — "*) ;; *) return 1 ;; esac
  PH_SESS=${after%%" — "*}
  case "$PH_SESS" in *" · "*) return 1 ;; esac
  PH_REST=${after#*" — "}
  [ -n "$PH_SESS" ]
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

heading_correction() {  # heading_correction <abs> -- 0 if this edit is the permitted one
  local abs="$1" stem fsession old new first content written
  local o_date o_sess o_rest n_date n_sess n_rest

  # A CORRECTION IS SMALL, AND A HOOK PAST ITS TIMEOUT REFUSES NOTHING. The tests
  # below read whole fields, scan the whole payload and read the whole entry, so
  # their cost grew with the payload: a 50 MB Write of an existing entry took 7.9
  # s and a 30 MB new_string Edit 9.6 s against this hook's 5 s timeout, where
  # the base refused both in under half a second (review of #189, round 6). The
  # correction's payload is a path and two headings, a few hundred characters, so
  # anything over 4096 is not it and is refused before any field is read.
  [ "${#PAYLOAD}" -le 4096 ] || return 1
  # Under a docs/dev-log/ by the same segments the guard reads (#159), so the
  # correction is made in a linked worktree as in the main checkout.
  case "$abs" in */docs/dev-log/*) ;; *) return 1 ;; esac

  stem=${abs##*/}
  case "$stem" in *.md) stem=${stem%.md} ;; *) return 1 ;; esac
  case "$stem" in devlog_*) stem=${stem#devlog_} ;; *) return 1 ;; esac
  case "$stem" in *_*) fsession=${stem#*_} ;; *) return 1 ;; esac
  [ -n "$fsession" ] || return 1

  # A CALL CARRYING A `content` STRING IS NEVER THE EXCEPTION. That is every Write
  # the harness sends, since a Write's schema requires one, and an Edit never
  # carries one. The Write was told apart by lacking an old_string until review of
  # #189, round 2, found a Write that also carried old_string and new_string
  # judged as the Edit they describe; this closes that. What it does NOT close,
  # measured in round 5: a Write whose `content` is null, a number or absent, with
  # the Edit's two strings beside it, is still judged as that Edit, because only
  # the tool's name tells it apart then, and the tool's name is not read -- the
  # one reader reads tool_input only, and GH-95.2 holds that no hook calls jq
  # itself. Whether the harness can deliver such a Write is not measured; its
  # schema says it cannot. Filed as #248. This test runs before the scan for a NUL escape below
  # because that scan reads the whole payload, which for a Write is the whole
  # file: a refused 10 MB Write took 1.67 s against the 5 s timeout (round 5).
  field_exact written content 2>/dev/null && return 1
  # A NUL is the one byte a bash string cannot hold: jq -r writes a `\u0000` out
  # as a NUL and the substitution drops it, so a new_string ending in one read
  # here as the corrected heading and the tool wrote the NUL into the entry. The
  # escape is the only way a JSON document spells a NUL, so it is refused where
  # it is spelled, before any string is read. Refusing the escape anywhere in the
  # document also refuses a `\\u0000` that is only text, which costs a refusal
  # and never a permission (review of #189, round 1, measured with the sweep of
  # that round's class A).
  case "$PAYLOAD" in *'\u0000'*) return 1 ;; esac
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

# WHETHER A PATH IS GUARDED IS READ OFF THE PATH'S OWN SEGMENTS, and never off
# where the project root is (#159). A `docs/` segment followed by one of the
# three directory names and then a `/`, anywhere in the normalised absolute path,
# is the whole test. The project root is still where a relative path is resolved
# from, and where the refusal below measures the path it names from; it decides
# nothing else.
#
# It was anchored to the project root: the root stripped off by string prefix and
# the remainder matched at `^docs/`, "so an identically-named path in another
# checkout is not caught by a bare substring match". CLAUDE_PROJECT_DIR is the
# main checkout, so in a linked worktree the remainder began with the worktree's
# own path and the anchor matched nothing -- an existing entry there was
# permitted, and a linked worktree is where CLAUDE.md sends every agent to work.
# The guard covered the checkout nobody edits in and not the one everybody does.
#
# What that comment asked for is kept: this is no bare substring match. The pair
# is bounded by a `/` on both sides, so `docs/dev-log.bak/`, `docs/dev-logbook/`
# and `notdocs/dev-log/` are other directories and stay permitted, and the
# normalisation above still runs first, so `.`, `..` and doubled slashes reach the
# same answer. A relative path is resolved against the project directory first,
# so every path compared is absolute and opens with the `/` the pattern asks for.
#
# THE TRADE, TAKEN KNOWINGLY: an identically-named path in a repository that is
# NOT this one is now refused as well -- an existing `docs/dev-log/<entry>` in
# any checkout of anything. The comment above declined that, and it is taken now
# because a refusal is visible and one edit away from being routed around, while
# a silently permitted rewrite of history is neither; CLAUDE.md's consequence 3
# accepts a refused comment on the same reasoning. It is also where the Bash half,
# append-only-docs.sh, already stood: it matches path spellings in a command and
# resolves them against no root at all, so the two halves now agree about which
# paths are append-only, and checks/GH-159.sh holds them to one path set. Asking
# git which repository a path belongs to was the other route #159 offered, and
# was not taken: it would have fixed the worktree and left the two halves
# disagreeing about every other checkout.
GUARDED_RE='/docs/(dev-log|lessons-learned|eval-reports)/'

# The path a reader can act on: relative to the project root when it is under
# it, and whole when it is not, since a worktree's entry has no spelling
# relative to the main checkout.
case "$ABS" in
  "$ROOT"/*) SHOWN="${ABS#"$ROOT"/}" ;;
  *)         SHOWN="$ABS" ;;
esac

if echo "$ABS" | grep -qE "$GUARDED_RE"; then
  # A README describes its directory rather than recording a session, a failure
  # or a measurement. CLAUDE.md's rule is about entries — "old entries are
  # history" — so the directory's own description stays revisable in place,
  # exactly as docs/design/README.md is.
  if basename "$ABS" | grep -qE '^README\.md$'; then
    exit 0
  fi
  if [ -e "$ABS" ]; then
    # ADR 0003 (#177). The one part of one line that is the entry's label rather
    # than its history, corrected only onto the name the file already carries.
    if heading_correction "$ABS"; then
      exit 0
    fi
    echo "Blocked: editing an existing file under an append-only docs directory ($SHOWN). CLAUDE.md treats docs/dev-log/, docs/lessons-learned/ and docs/eval-reports/ as history; corrections go in the newest entry, never backwards. Writing a new entry file is allowed. The one exception (ADR 0003, #177) is an Edit that changes only the session segment of a docs/dev-log/ entry's first-line heading, to agree with the session the file is named for." >&2
    exit 2
  fi
fi

exit 0

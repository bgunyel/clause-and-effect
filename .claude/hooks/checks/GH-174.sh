#!/bin/bash
# THE ISSUE FILE OF #174: the #95 section's jq fixture guard asks the farm, not
# the calling shell, whether it holds a `jq`.
#
# Why: the guard asked `$( PATH=<farm>; command -v jq )`, and `command -v`
# resolves a shell function ahead of PATH. bash imports an exported one --
# `BASH_FUNC_jq%%` in the environment -- into a non-interactive script like
# this suite, so on a host whose profile exports a `jq` wrapper the question
# about the jq-less copy read the function and answered yes. The guard then
# called the fixture broken and `exit 1` ended the whole run, skipping every
# section below it, #104's coverage derivations included. #155 removed that
# abort one fixture over and named the fix, `farm_has`, a file test on the
# directory; this was the one question of that shape still asking the shell.
# Reproduced before the fix: under an exported `jq` wrapper the run printed
# 2036 results and stopped at that guard.
#
# WHAT IS DRIVEN is the guard itself. #155 read its guard's text because a
# guard whose failure is `exit 1` cannot be driven from inside the run it would
# end -- but it can be driven from a subshell of that run, where `exit` ends
# the subshell. So the guard's own lines are taken from the suite text and
# evaluated inside $( ) against the fixtures the #95 section built, under a
# shell that defines and exports `jq` and under one that does not, and what
# each printed is compared with a literal. A control points the jq-less name at
# the with-jq farm, so the same evaluation is seen to fail on a broken fixture
# and a `passed` is evidence rather than an evaluation that ran nothing.
#
# AND THE RULE IS DERIVED, NOT WRITTEN AGAIN BY HAND (GH-174.2). #174 asked
# whether every future fixture guard should be held to the same reading by
# derivation, and it is: #155 put the rule in one guard with a `lacks`, this
# issue would have put it in a second, and the next guard is the one no `lacks`
# names -- #84's shape one level out. So the whole suite's text is read, and a
# line that sets PATH and then asks the calling shell what a name is fails the
# run wherever it stands. Written here and not in the library, because this
# file is its only caller.

section "=== issue #174: a fixture guard asks the farm, not the calling shell, what it holds ==="

requirement GH-174.1 <<'REQ'
- text: The fixture guard of the #95 section asks whether the symlink farm
  holds a `jq`, and whether its jq-less copy holds none, of the directories,
  through `farm_has`, and asks the calling shell nothing. So a host whose
  environment exports a `jq` function -- which `command -v` resolves ahead of
  PATH, under the jq-less PATH too -- builds the same fixtures and passes the
  same guard as one that does not, where the guard used to abort the run.
- from: #174
- kind: defect-refusing
- status: active
- direction: static: it runs the guard's own text in a subshell and reads
  what it printed, and reads no hook's verdict
- note: Measured on the whole run, not only by these checks. With a `jq`
  wrapper exported into its environment the suite stopped at this guard after
  2036 results before the fix. After it, the run goes to the end and prints as
  many results as a run without the wrapper -- which is what this entry
  establishes -- but not the same results: nine rows that pass without the
  wrapper fail with it, because the function also reaches every hook and child
  shell the suite starts, and the library's own jq guard asks `command -v`.
  That is a different defect with a different fix, and #283 owns it. The
  rule is in the suite and not in a hook, so `mutate-hooks.sh` cannot
  register it -- that harness refuses `check-hooks.sh` and every file under
  `checks/` as a target, because an edit to the copy would be executed by
  nothing. It was hand-mutated instead, and the cases and what each turned
  red are in the dev-log entry of the session that wrote it.
REQ
requirement GH-174.2 <<'REQ'
- text: No line of the suite -- the driver and every file it sources -- sets
  PATH and then asks the calling shell what a name is, with `command -v`,
  `command -V` or `type`, whether PATH is set as a statement before it or as
  an assignment in front of it. A question about what a PATH holds is asked of
  its directory, so a function in the invoker's environment cannot answer it.
  A line that is a comment is not read; a line that fails to be read fails
  the check rather than reading as clean.
- from: #174
- kind: defect-refusing
- status: active
- direction: static: it reads the suite's own text
- note: What the derivation cannot read is stated rather than left to be
  found: PATH set on one line and asked about on the next, an `export PATH=`
  before the question, a question inside a quoted payload handed to a child
  shell, and any other builtin that resolves a function -- `hash` among them.
  It reads the shape both defects of this class were written in, #155's and
  #174's. A trailing comment is read, so a comment carrying the shape can
  refuse a line; that is the refusing direction and is accepted, because
  stripping trailing comments cuts at the first `#` and could hide a question.
REQ
shape_pin 'GH-174.1:static GH-174.2:static'

# The guard as the #95 section wrote it: the lines after the one that takes jq
# out of the copy, down to the brace that closes its failure branch, without
# its comment lines. The `rm` is left out so that evaluating the range repeats
# no act on the fixtures.
suite_range R174_GUARD '/^rm -f "\$NO_JQ_BIN\/jq"$/' '/^}$/'
R174_GUARD=$(printf '%s\n' "$R174_GUARD" | sed '1d; /^[[:space:]]*#/d')
# The guard's own words when it fails, as a literal: what the control below
# must print, so that an evaluation which did nothing reads as a failure.
R174_GUARD_SAYS='the jq-less PATH fixture is not the with-jq one minus jq; the checks using it prove nothing'
r174_guard() {  # r174_guard -- evaluate the guard in a subshell; `passed`, or what it printed
  ( eval "$R174_GUARD" ) 2>&1 && echo passed
}

req GH-174.1
holds 'the jq fixture guard asks the with-jq farm, as a directory, whether it holds jq' \
      "$R174_GUARD" 'farm_has "$WITH_JQ_BIN" jq'
holds 'and asks the jq-less copy the same way' \
      "$R174_GUARD" '! farm_has "$NO_JQ_BIN" jq'
lacks 'and asks the calling shell nothing, which would resolve a function ahead of PATH' \
      "$R174_GUARD" 'command -v'
# The function is defined and exported inside each $( ), so it reaches the
# guard's own subshells and the programs they run the way an invoker's profile
# would, and it is gone when the $( ) ends: a `jq` left standing here would be
# run by every later check that feeds a hook, in place of the program.
tok 'under a shell that exports a jq function, the shell has a jq whatever PATH says' \
    'function' "$( jq() { echo 'a wrapper in the invoker environment'; }; export -f jq; type -t jq )"
tok 'and there the jq fixture guard passes, having asked the farm and not the function' \
    'passed' "$( jq() { echo 'a wrapper in the invoker environment'; }; export -f jq; r174_guard )"
tok 'under a shell with no jq function, it passes too' \
    'passed' "$( unset -f jq; r174_guard )"
tok 'and pointed at a jq-less copy that still holds jq, it fails and says why' \
    "$R174_GUARD_SAYS" "$( unset -f jq; NO_JQ_BIN=$WITH_JQ_BIN; r174_guard )"

# THE DERIVATION. A line that sets PATH, as a word of its own, and then -- after
# a separator, or as the command the assignment stands in front of -- asks
# `command -v`, `command -V` or `type`. A line whose first word is `#` is not
# read. awk and not grep, for the file and line it names; `-v` would eat a
# backslash, and the expression has none.
R174_RE='(^|[^A-Za-z0-9_])PATH=[^;&|]*[;&[:space:]][[:space:]]*(command[[:space:]]+-[vV]|type)([[:space:]]|$)'
farm_asked_of_shell() {  # farm_asked_of_shell <file>... -- <file>:<line> of each such line, space-separated
  local out awk_status
  # With no file awk would read stdin, and an empty answer would read as clean.
  [ "$#" -gt 0 ] || { echo 'unread: no file was named'; return; }
  out=$(awk -v re="$R174_RE" '
    /^[[:space:]]*#/ { next }
    $0 ~ re { printf "%s%s:%d", sep, FILENAME, FNR; sep = " " }' "$@" 2>/dev/null)
  awk_status=$?
  if [ "$awk_status" = 0 ]; then printf '%s' "$out"; else echo "unread: awk exited $awk_status"; fi
}

# The fixture: each shape the derivation reads, and the near misses it must
# not. The asking words are held in variables so that no line of this file is
# a line the derivation reads over the suite below.
R174_ASK_V='command -v'
R174_ASK_UPPER_V='command -V'
R174_ASK_TYPE='type'
R174_SHAPES="$FIXTURES/r174-shapes.sh"
R174_GONE="$FIXTURES/r174-no-such-file"
printf '%s\n' \
  '[ -n "$( PATH="$WITH_JQ_BIN"; '"$R174_ASK_V"' jq )" ] \' \
  '  && [ -z "$( PATH="$NO_JQ_BIN"; '"$R174_ASK_V"' jq )" ] \' \
  'PATH="$FARM" '"$R174_ASK_UPPER_V"' gh' \
  'x=$(PATH=$FARM:$PATH; '"$R174_ASK_TYPE"' -t jq)' \
  '  # PATH=<farm>; '"$R174_ASK_V"' gh, a comment' \
  'REAL_GIT=$('"$R174_ASK_V"' git)' \
  '( PATH="$FARM"; gh --version )' \
  'farm_has "$FARM" jq' \
  'ENV_PATH=x; '"$R174_ASK_TYPE"' y' \
  > "$R174_SHAPES"
rm -f "$R174_GONE"
[ "$(wc -l < "$R174_SHAPES")" = 9 ] && [ ! -e "$R174_GONE" ] || {
  echo "the #174 fixtures were not created; the checks against them prove nothing" >&2
  exit 1
}

req GH-174.2
tok 'the derivation reads the guard as #174 found it, a PATH assignment and then command -v, and PATH in front of command -V or type -- and nothing else' \
    "$R174_SHAPES:1 $R174_SHAPES:2 $R174_SHAPES:3 $R174_SHAPES:4" \
    "$(farm_asked_of_shell "$R174_SHAPES")"
tok 'a file it could not read is not clean, and says why' \
    'unread: awk exited 2' "$(farm_asked_of_shell "$R174_SHAPES" "$R174_GONE")"
tok 'and no file at all is not clean either' \
    'unread: no file was named' "$(farm_asked_of_shell)"
tok 'no line of the suite asks the calling shell what a name is under a PATH it set' \
    '' "$(farm_asked_of_shell "${SUITE_FILES[@]}")"

sourced_to_end

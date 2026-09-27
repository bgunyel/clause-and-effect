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
# shell that defines `jq` and under one that does not, and what each printed
# is compared with a literal. A control points the jq-less name at the with-jq
# farm, so the same evaluation is seen to fail on a broken fixture and a
# `passed` is evidence rather than an evaluation that ran nothing.
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
  through `farm_has`, and asks the calling shell nothing. So under a shell
  that defines a `jq` function -- which `command -v` resolves ahead of PATH,
  under the jq-less PATH too -- the guard passes against the same fixtures,
  where it used to fail and abort the run.
- from: #174
- kind: defect-refusing
- status: active
- direction: static: it runs the guard's own text in a subshell and reads
  what it printed, and reads no hook's verdict
- note: What the whole run does was measured by hand, and is not what these
  checks establish. With a `jq` wrapper exported into its environment the
  suite stopped at this guard after 2036 results before the fix. After it,
  the run went to the end and printed as many results as a run without the
  wrapper, but not the same results: nine rows that pass without the wrapper
  failed with it, because the function also reaches every hook and child
  shell the suite starts, and the library's own jq guard asks `command -v`.
  That is a different defect with a different fix, and #283 owns it.
  The checks define the function in the shell that evaluates the guard, and
  do not import it from `BASH_FUNC_jq%%`. For `command -v` the two are the
  same thing -- an imported function is a defined one by the time the script
  runs -- which is why a defined one stands in for the host here.
  The rule is in the suite and not in a hook, so `mutate-hooks.sh` cannot
  register it: that harness refuses `check-hooks.sh` and every file under
  `checks/` as a target, because an edit to the copy would be executed by
  nothing. It was hand-mutated instead, each case a full run of the suite in
  a checkout of its own. The guard put back to its two `command -v`
  questions turned five rows red: both `holds`, the `lacks`, the row that
  evaluates the guard under a `jq` function, and GH-174.2's row over the
  suite. The guard's range evaluated as `:` turned three red: both `holds`
  and the control that must fail. Neither turned the other rows red.
REQ
requirement GH-174.2 <<'REQ'
- text: No line of the suite -- the driver and every file it sources -- sets
  PATH and then, later on the same line, asks the calling shell what a name
  is, with `command` and an option word holding `v` or `V`, after any other
  option words, or with `type`. PATH is set by `PATH=` or `PATH+=` standing
  as a word of its own, `export PATH=`, `declare PATH=` and `local PATH=`
  included; the question is a word of its own after a blank, `;`, `&`, `|`,
  `(`, `!`, a backquote, a quote or a backslash, so it is read after `&&` and
  `||`, after `if`, `!`, `$(` or `[`, after a command standing in between, as
  the command a PATH assignment stands in front of, as the first word of a
  payload quoted for a child shell, and written `\command` or `\type`. A
  question about what a PATH holds is asked of its directory, so a function
  in the invoker's environment cannot answer it. A line that is a comment is
  not read; a file that fails to be read fails the check rather than reading
  as clean.
- from: #174
- kind: defect-refusing
- status: active
- direction: static: it reads the suite's own text
- note: What the derivation cannot read is a fixture of its own, every line
  of it expected unread, so the list is checked and not written from memory:
  PATH set on one line and asked about on the next; PATH set through `read`,
  `printf -v` or a name held in a variable; `hash` and `compgen -c`, which a
  function answers as well; `command` reached through a variable; and a
  question word in quotes of its own. Review of the pull request for #174
  found the list written by hand wrong twice, `export PATH=` in the first
  round and `declare` and `local` in the second, each named unread and each
  read, which is why it is a fixture now. `type -P` is read, though it alone
  of these spellings ignores a function: the rule is that what a PATH holds
  is asked of its directory, the correction is one edit to `farm_has`, and a
  false red is the refusing direction. `type -p` is no such exception, since
  it answers nothing for a name that is a function even where the PATH holds
  that name. It reads within quotes as readily as outside them, so prose on
  a line that sets PATH and then says one of the asking words is read too:
  the refusing direction, and accepted, because telling code from quoted
  text is the thing a line-wide read cannot do. A trailing comment is read
  for the same reason; stripping one cuts at the first `#` and could hide a
  question.
  Review found the expression narrower than this text in both of its first
  two rounds. In the first it read the question only straight after the
  first separator, so `&&`, `||`, `if`, `!`, `$(`, a command between,
  `PATH+=` and `command -pv` went unread. In the second it did not read a
  question opening a quoted payload -- where a child shell imports an
  exported function -- nor `\command -v`, nor `command -p -v`, whose `v` is
  in the second option word. Each is now a row of the fixture.
  Hand-mutated like GH-174.1, for the same reason, each case a full run:
  `type` taken out of the expression; the blank taken out of the boundary
  class; `(` taken out of it; `+=` no longer read as setting PATH; the
  option cluster narrowed to `-v` or `-V` alone; and comment lines read.
  Each turned the fixture row red, and reading comments turned the row over
  the suite red as well. awk's status ignored turned the unreadable-file row
  red.
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
# The function is defined inside each $( ), so the guard's own subshells
# inherit it, and it is gone when the $( ) ends: a `jq` left standing here
# would be run by every later check that feeds a hook, in place of the program.
#
# What the calling shell calls `jq` under the jq-less PATH is asked in the same
# $( ) the guard is evaluated in, and printed beside its `passed`, so the row
# fails if no function stands in the guard's way there: a `passed` alone says
# nothing about a function that was never defined. r174_shadowed keeps PATH on
# one line and the question on the next, which is a shape GH-174.2 states it
# does not read, and it is the one question in the suite meant to be answered
# by a function.
r174_shadowed() {  # r174_shadowed -- what the calling shell calls `jq` under the jq-less PATH
  local PATH=$NO_JQ_BIN
  type -t jq
}
tok 'under a shell whose jq is a function under the jq-less PATH too, the jq fixture guard passes, having asked the farm' \
    'function passed' "$( jq() { echo 'a wrapper in the invoker environment'; }; echo "$(r174_shadowed) $(r174_guard)" )"
tok 'under a shell with no jq function, it passes too' \
    'passed' "$( unset -f jq; r174_guard )"
tok 'and pointed at a jq-less copy that still holds jq, it fails and says why' \
    "$R174_GUARD_SAYS" "$( unset -f jq; NO_JQ_BIN=$WITH_JQ_BIN; r174_guard )"

# THE DERIVATION. A line that sets PATH, as a word of its own, and later on it
# asks `command -v` -- an option word holding `v` or `V`, after any other option
# words -- or `type`, as a word of its own after a blank, one of `;&|(!`, a
# backquote, a quote or a backslash. A line whose first word is `#` is not
# read. awk and not grep, for the file and line it names; the expression goes
# in through ENVIRON and not `-v`, which would take the backslash that stands
# for a backslash in the class as an escape.
R174_RE='(^|[^A-Za-z0-9_])PATH[+]?=.*[;&|(![:space:]`"'"'"'\\](command([[:space:]]+-[A-Za-z]+)*[[:space:]]+-[A-Za-z]*[vV][A-Za-z]*|type)([[:space:]]|$)'
path_lines_asking_shell() {  # path_lines_asking_shell <file>... -- <file>:<line> of each such line, space-separated
  local out awk_status
  # With no file awk would read stdin, and an empty answer would read as clean.
  [ "$#" -gt 0 ] || { echo 'unread: no file was named'; return; }
  out=$(R174_RE=$R174_RE awk '
    BEGIN { re = ENVIRON["R174_RE"] }
    /^[[:space:]]*#/ { next }
    $0 ~ re { printf "%s%s:%d", sep, FILENAME, FNR; sep = " " }' "$@" 2>/dev/null)
  awk_status=$?
  if [ "$awk_status" = 0 ]; then printf '%s' "$out"; else echo "unread: awk exited $awk_status"; fi
}

# The fixtures. r174-shapes.sh holds each shape the derivation reads, lines 1
# to 23, and the near misses it must not, lines 24 to 34. Line 23 is `type -P`,
# read by the trade GH-174.2's note states. r174-gaps.sh holds what that note
# says the derivation cannot read, every line of it, so the note's list is a
# check: a derivation widened to read one turns its row red, and the note has
# to say so. The asking words are held in variables so that no line of this
# file is a line the derivation reads over the suite below.
R174_ASK_V='command -v'
R174_ASK_UPPER_V='command -V'
R174_ASK_PV='command -pv'
R174_ASK_P_V='command -p -v'
R174_ASK_TYPE='type'
R174_SHAPES="$FIXTURES/r174-shapes.sh"
R174_GAPS="$FIXTURES/r174-gaps.sh"
R174_GONE="$FIXTURES/r174-no-such-file"
printf '%s\n' \
  '[ -n "$( PATH="$WITH_JQ_BIN"; '"$R174_ASK_V"' jq )" ] \' \
  '  && [ -z "$( PATH="$NO_JQ_BIN"; '"$R174_ASK_V"' jq )" ] \' \
  'PATH="$FARM" '"$R174_ASK_UPPER_V"' gh' \
  'x=$(PATH=$FARM:$PATH; '"$R174_ASK_TYPE"' -t jq)' \
  'PATH="$F" && '"$R174_ASK_V"' jq' \
  'PATH="$F" || '"$R174_ASK_TYPE"' jq' \
  'PATH="$F"; if '"$R174_ASK_V"' jq; then :; fi' \
  'PATH="$F"; ! '"$R174_ASK_V"' jq' \
  'PATH="$F"; out=$('"$R174_ASK_V"' jq)' \
  'PATH="$F"; cd y; '"$R174_ASK_V"' jq' \
  'PATH+=":$F"; '"$R174_ASK_V"' jq' \
  'PATH="$F"; '"$R174_ASK_PV"' jq' \
  'export PATH="$F"; '"$R174_ASK_V"' gh' \
  'PATH="$F"; x=`'"$R174_ASK_V"' jq`' \
  'PATH="$F" bash -c "'"$R174_ASK_V"' jq"' \
  'PATH="$F" bash -c '\'''"$R174_ASK_TYPE"' -t jq'\''' \
  'x=$(PATH="$FARM" bash -c '\'''"$R174_ASK_V"' gh'\'' 2>/dev/null)' \
  'PATH="$F"; '"$R174_ASK_P_V"' jq' \
  'PATH=$F \'"$R174_ASK_V"' jq' \
  'PATH=$F \'"$R174_ASK_TYPE"' jq' \
  'declare PATH="$F"; '"$R174_ASK_V"' jq' \
  'local PATH="$F"; '"$R174_ASK_V"' jq' \
  'PATH="$F"; '"$R174_ASK_TYPE"' -P jq' \
  '  # PATH=<farm>; '"$R174_ASK_V"' gh, a comment' \
  'REAL_GIT=$('"$R174_ASK_V"' git)' \
  '( PATH="$FARM"; gh --version )' \
  'farm_has "$FARM" jq' \
  'ENV_PATH=x; '"$R174_ASK_TYPE"' y' \
  'PATH="$F"; command jq' \
  'PATH="$F"; my'"$R174_ASK_TYPE"' x' \
  'PATH="$F"; command -p jq' \
  'PATH="$F"; find . -'"$R174_ASK_TYPE"' f' \
  'PATH="$F"; echo "$'"$R174_ASK_TYPE"'"' \
  'PATH="$F"; command -p -- -v' \
  > "$R174_SHAPES"
printf '%s\n' \
  'PATH="$F"' \
  "$R174_ASK_V"' jq' \
  'read -r PATH <<< "$F"; '"$R174_ASK_V"' jq' \
  'printf -v PATH %s "$F"; '"$R174_ASK_V"' jq' \
  'declare "$P=$F"; '"$R174_ASK_V"' jq' \
  'PATH="$F"; hash jq' \
  'PATH="$F"; compgen -c jq' \
  'PATH="$F"; c=command; $c -v jq' \
  'PATH="$F"; "'"$R174_ASK_TYPE"'" jq' \
  > "$R174_GAPS"
rm -f "$R174_GONE"
[ "$(wc -l < "$R174_SHAPES")" = 34 ] && [ "$(wc -l < "$R174_GAPS")" = 9 ] && [ ! -e "$R174_GONE" ] || {
  echo "the #174 fixtures were not created; the checks against them prove nothing" >&2
  exit 1
}
R174_READ=
for n in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23; do
  R174_READ="$R174_READ${R174_READ:+ }$R174_SHAPES:$n"
done

req GH-174.2
tok 'the derivation reads every shape of asking the shell under a PATH it set, lines 1 to 23, and no near miss' \
    "$R174_READ" "$(path_lines_asking_shell "$R174_SHAPES")"
tok 'and reads none of the shapes its note states it cannot read' \
    '' "$(path_lines_asking_shell "$R174_GAPS")"
tok 'a file it could not read is not clean, and says why' \
    'unread: awk exited 2' "$(path_lines_asking_shell "$R174_SHAPES" "$R174_GONE")"
tok 'and no file at all is not clean either' \
    'unread: no file was named' "$(path_lines_asking_shell)"
tok 'no line of the suite asks the calling shell what a name is under a PATH it set' \
    '' "$(path_lines_asking_shell "${SUITE_FILES[@]}")"

sourced_to_end

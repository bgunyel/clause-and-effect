#!/bin/bash
# THE ISSUE FILE OF #295: the order the checks are sourced in is derived from
# checks/, and nothing else there is sourced.
#
# Why: the driver named the files it sources on one hand-written line,
# SUITE_CHECKS, and every branch that added an issue file appended its name
# there. Git merges by line, so any two such branches conflicted on it, and
# every merge of one hook pull request left each other open one that added an
# issue file with no merge ref for CI to build until its agent re-resolved the
# line. At 2f1a89b four of the five open pull requests conflicted, all four on
# that line and two on nothing else. So the driver derives the list instead:
# the unsplit file, then every `GH-<n>.sh` in ascending order of <n>, then the
# end-of-run file. Two branches that each add an issue file now edit no line in
# common.
#
# THE ORDER IS ONE NOBODY WROTE, AND IT WAS MEASURED BEFORE IT WAS TAKEN. ADR
# 0004 rejected a directory listing because its order is one nobody chose.
# Sorted by issue number, it is fixed, so a new file that depends on the order
# shows up as a red run on the pull request that adds it and never as a flake;
# and before it was taken the whole suite was run with the issue files in the
# order the list gave, ascending and descending, and the three agreed row for
# row. docs/adr/0006-check-order-derived-from-issue-numbers.md records the runs
# and the trade.
#
# WHAT IS DRIVEN is `suite_checks`, over a fixture directory whose issue files
# sort differently as text and as numbers, and `source_checks` over what it
# derived, in a subshell with a sourcing record of its own -- as the #204
# fixtures in the unsplit file run it -- so the FAILs it prints for the strays
# beside them are this file's evidence and not red rows. And the driver: its one
# assignment of the list, and the list it derived for this run.

section "=== issue #295: the order the checks are sourced in is derived from checks/, and nothing else there runs ==="

requirement GH-295 <<'REQ'
- text: The driver writes no list of the files it sources after the library.
  It derives one from what `checks/` holds, with `suite_checks`: the unsplit
  file, then every file named `GH-<n>.sh` -- `<n>` digits with no leading zero
  -- in ascending numeric order of `<n>`, so `GH-9.sh` comes before
  `GH-10.sh`; and the end-of-run file after them. Any other file under
  `checks/`, the library aside, is on no list, so `source_checks` fails the
  run on it and never sources it: a merge's `GH-166.sh.orig`, an editor's
  `.swp`, `GH-12a.sh`, `GH-012.sh`, `GH-0.sh`, `notes.sh`. A `checks/` that
  cannot be listed stops the run before anything is judged, rather than
  leaving a list of the unsplit file alone.
- from: #295
- kind: defect-permitting
- status: active
- direction: static: it drives the derivation and the routine against a
  fixture directory, and reads the driver's list and its one assignment
- note: The order was measured before it was taken: the whole suite run with
  the issue files in the list's order, ascending and descending, agreed row
  for row (ADR 0006). The rule it rests on is tooling, which `mutate-hooks.sh`
  refuses as a target, so its evidence is the fixture rows and the mutations
  run by hand that PR #295's description records, as ADR 0004 did for
  `source_checks`. What it does not reach, named: a stray whose name matches
  the pattern, which is an issue file by definition and is sourced.
REQ
shape_pin 'GH-295:static'

# THE FIXTURE: a checks directory holding the three named files, four issue
# files whose numbers sort one way as text and another as numbers, and a stray
# of every kind the brief names and two it does not. Each file says it ran, so
# a stray that was sourced would say so in the output asked about below.
R295_DIR="$FIXTURES/r295/checks"
mkdir -p "$R295_DIR"
for f in library.sh unsplit.sh end-of-run.sh GH-2.sh GH-9.sh GH-10.sh GH-100.sh \
         GH-166.sh.orig .GH-166.sh.swp GH-12a.sh GH-012.sh GH-0.sh notes.sh; do
  printf 'echo "%s ran"\nsourced_to_end\n' "$f" > "$R295_DIR/$f"
done
[ "$(cd "$R295_DIR" && ls -A | wc -l)" = 13 ] || {
  echo "the #295 fixture was not created; the checks against it prove nothing" >&2
  exit 1
}
# The routine over a directory and a list, in a subshell that records on its
# own, as the #204 fixtures do: what the routine printed, its FAIL prefix
# rewritten because the #104 section reads this suite for a quoted line opening
# with a result word, and then its record.
r295_sourcing() {  # r295_sourcing <dir> <file>... -- what source_checks printed, and its record
  ( cd -- "$(dirname -- "$1")" || exit 1
    SOURCED="$1.record"; : > "$SOURCED"; SOURCED_SHELL=$BASHPID; SUITE_LIBRARY=library.sh
    source_checks "$@" > "$1.out"
    sed 's/^  FAIL /FAIL: /' "$1.out"
    sed 's/^/record: /' "$SOURCED" )
}

req GH-295
tok 'the unsplit file, then the issue files in ascending order of their numbers, and no stray' \
'unsplit.sh
GH-2.sh
GH-9.sh
GH-10.sh
GH-100.sh' "$(suite_checks "$R295_DIR")"
tok 'and what it derived, with the end-of-run file after it, is sourced in that order, and every stray is a FAIL and never sourced' \
"FAIL: .GH-166.sh.swp is under $R295_DIR and on no list the driver sources, so no check in it runs
FAIL: GH-0.sh is under $R295_DIR and on no list the driver sources, so no check in it runs
FAIL: GH-012.sh is under $R295_DIR and on no list the driver sources, so no check in it runs
FAIL: GH-12a.sh is under $R295_DIR and on no list the driver sources, so no check in it runs
FAIL: GH-166.sh.orig is under $R295_DIR and on no list the driver sources, so no check in it runs
FAIL: notes.sh is under $R295_DIR and on no list the driver sources, so no check in it runs
unsplit.sh ran
GH-2.sh ran
GH-9.sh ran
GH-10.sh ran
GH-100.sh ran
end-of-run.sh ran
record: start $R295_DIR/unsplit.sh
record: end $R295_DIR/unsplit.sh 2
record: start $R295_DIR/GH-2.sh
record: end $R295_DIR/GH-2.sh 2
record: start $R295_DIR/GH-9.sh
record: end $R295_DIR/GH-9.sh 2
record: start $R295_DIR/GH-10.sh
record: end $R295_DIR/GH-10.sh 2
record: start $R295_DIR/GH-100.sh
record: end $R295_DIR/GH-100.sh 2
record: start $R295_DIR/end-of-run.sh
record: end $R295_DIR/end-of-run.sh 2" \
    "$(r295_sourcing "$R295_DIR" $(suite_checks "$R295_DIR") end-of-run.sh)"
tok 'a directory that cannot be listed derives nothing, and says so with its status' \
    'status 1' "$(suite_checks "$FIXTURES/r295/no-such-dir"; printf 'status %s\n' "$?")"

# AND THE DRIVER. Its one assignment of the list is the derivation, with the
# guard that stops the run when it fails; a literal list written again beside
# it, or in its place, is a second line here.
tok 'the driver assigns its list once, from suite_checks, and stops the run when that fails' \
    'SUITE_CHECKS=$(suite_checks "$SUITE_DIR/checks") || {' \
    "$(grep -E '^[[:space:]]*SUITE_CHECKS=' "${SUITE_FILES[0]}")"
# And the list it derived for this run, read without the function under check:
# the unsplit file first, then names of the issue-file shape whose numbers only
# rise. Nothing is printed when all of that holds.
r295_order() {  # r295_order <list> -- each way <list> is not the unsplit file and then rising issue files
  local f n=0 first=1
  for f in $1; do
    if [ -n "$first" ]; then
      [ "$f" = unsplit.sh ] || printf 'first: %s\n' "$f"
      first=
    elif [[ $f =~ ^GH-([1-9][0-9]*)[.]sh$ ]]; then
      (( BASH_REMATCH[1] > n )) || printf 'not rising: %s after GH-%s.sh\n' "$f" "$n"
      n=${BASH_REMATCH[1]}
    else
      printf 'not an issue file: %s\n' "$f"
    fi
  done
}
tok 'the list this run derived is the unsplit file and then issue files in rising order' \
    '' "$(r295_order "$SUITE_CHECKS")"
tok 'and the reader of it says so of a list that is not' \
'first: GH-2.sh
not an issue file: unsplit.sh
not rising: GH-10.sh after GH-100.sh
not an issue file: GH-012.sh' \
    "$(r295_order 'GH-2.sh unsplit.sh GH-100.sh GH-10.sh GH-012.sh')"
present 'and this file is on it' GH-295.sh "$(printf '%s ' $SUITE_CHECKS)"

sourced_to_end

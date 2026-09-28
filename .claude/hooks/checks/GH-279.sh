#!/bin/bash
# THE ISSUE FILE OF #279: the end-of-run verdict's read-backs hard-coded and
# label-matched what they read, and the head's record child read a failed
# source as emptiness.
#
# THREE DEFECTS, one per requirement below, each found by review of PR #216 or
# PR #220 and each latent when #279 was filed.
#
#   - The record child ran `. "$1" || exit 1`, and the head asked only whether
#     the record was empty. A tokeniser copy that sourced non-zero stopped the
#     run before any section, saying the file "defined nothing" -- the refusing
#     direction, and under mutate-hooks.sh a row that comes back
#     did-not-complete instead of judged. And a child that died partway
#     through printing left a partial record that passed as whole -- the
#     permitting direction. The two are fixed together, as the issue asks:
#     dropping the `exit 1` without reading the child's own status would have
#     let a partial record from a failed source pass. GH-279.1.
#   - The last check before the matrix read `tail -n 4` of the ledger, compared
#     four tags and the heading row's label alone, so a verdict row replaced by
#     another of its tag read green, and so did a clause added to the verdict
#     with no row. GH-279.2.
#   - The verdict rows' read-back chose rows by label and ran before GH-204.7's
#     fixtures, so a fixture row under another label and a leftover `req` went
#     unread, and GH-204.7's rows were never read at all. GH-279.3.
#
# WHAT IS HERE is the fixtures that drive each fix. The fixes themselves stand
# where they have to: the child and the head's loop in check-hooks.sh, the
# helpers in the library, and the two read-backs in the end-of-run file, which
# is the only place that runs after every verdict fixture and every row.
#
# NO REGISTRY ROW FOR TWO OF THE THREE. mutate-hooks.sh mutates a copy of the
# hooks under check and never the suite, so a rule of the suite's own, as
# GH-279.2's and GH-279.3's are, is not a thing it can break. Each is held
# instead by the fixtures below, which go red with the rule reverted. GH-279.1
# has a row, `tokeniser-sources-non-zero`: a tokeniser copy that ends in
# `false` is the shape the defect needed, and the run with it is judged, with
# the head's FAIL row under GH-279.1, where before #279 it stopped unjudged.

section "=== issue #279: the record child's three outcomes, and what the end-of-run read-backs read ==="

requirement GH-279.1 <<'REQ'
- text: The head of the check suite records what the library and the tokeniser
  define through a child that sources each file alone, and tells three
  outcomes apart. The child records whatever sourcing defined, whatever status
  it returned, and reports that status apart from the record. A file whose
  sourcing returned non-zero, and a child that exited non-zero, was killed, or
  ended before sourcing returned, is a FAIL row at the head, under GH-279.1,
  naming the file and why; the run goes on to its verdict with the record as it
  stands. A file whose sourcing defined nothing still stops the run, and says
  so, with the status when it was not 0.
- from: #279
- kind: defect-permitting
- status: active
- direction: static: it drives the suite's own record child against fixture
  files, and reads the driver's loop
- note: Two defects, fixed together (filed from the reviews of PR #216 and PR
  #220). A copy that sourced non-zero left an empty
  record and stopped the run as a file that "defined nothing", which is the
  refusing direction; a child that died partway left a partial record that
  passed as whole, which is the permitting one, and gives this entry its kind.
  All 26 registry rows that mutate the tokeniser were probed by the reviewer,
  and each sourced with status 0, so neither had fired. A record the child did
  not finish is used all the same once the row has failed the run: a name it
  lacks is not compared at the foot, and the row is what says so.
REQ
requirement GH-279.2 <<'REQ'
- text: The end-of-run file's last check before the matrix derives the rows the
  ledger has to end on from the verdict code the driver ends on -- the heading
  question's row, then one for each clause of the final verdict that writes
  one, in order -- and compares each row's tags and label. Which clauses write
  a row is a table beside the derivation: each clause of FOOT_VERDICT_CODE
  writes one; SOURCED_VERDICT_CODE and LEDGER_VERDICT_CODE write none, and each
  is held to the one clause it has. A verdict variable, a clause, or a place
  that sets the failure outside a clause of its own, that the table does not
  know, is red until the table says what it writes.
- from: #279
- kind: defect-permitting
- status: active
- direction: static: it derives the rows from the suite's own verdict code,
  drives the derivation with fixtures, and reads the ledger
- note: It was `tail -n 4` of the ledger against a literal of four tags and the
  heading row's label, so a verdict row replaced by another row of its tag read
  green while one verdict question had no row, and so did a fourth clause added
  to the verdict. Counting FOOT_VERDICT_CODE's clauses alone, the fix first
  proposed, would miss the heading row and the two verdict variables written
  after it.
  What it does not see, named: a clause written as `if` over more than one
  line, which is counted as a place that sets the failure outside a clause and
  is red, not missed.
REQ
requirement GH-279.3 <<'REQ'
- text: Every block of verdict fixtures -- the rows that drive the final
  verdict's code -- is opened and closed with `verdict_fixtures`, which writes
  down where the block begins and ends in the ledger, and the end-of-run file
  reads every row inside every block, whatever its label, once all have run,
  and holds its tags and label to a literal. A mark out of place, or a block
  never ended, is red. And a check file that evaluates a verdict's code outside
  a block is red, so a fixture outside one is not left unread.
- from: #279
- kind: defect-permitting
- status: active
- direction: static: it reads the rows the run recorded inside the blocks, and
  the check files' text for an evaluation outside one
- note: The read chose the rows whose label began `the final verdict `, or was
  `and says why on stderr`, and ran in the unsplit file's #204 section before
  GH-204.7's fixtures. So a fixture row under another label and a leftover
  `req` -- the tagging slip of rounds 5 and 7 of the review of PR #216, the
  class #212 describes -- was never read, and neither was either GH-204.7 row.
  What it does not see, named: an evaluation of a verdict's code spelt through
  another variable, or built some other way than `eval "$<NAME>_VERDICT_CODE"`.
REQ
shape_pin 'GH-279.1:static GH-279.2:static GH-279.3:static'

R279="$FIXTURES/r279"
mkdir -p "$R279"

# --- GH-279.1: the record child's three outcomes, driven -----------------------
#
# Each fixture file is recorded by `record_loaded`, the head's own routine, in a
# subshell with arrays of its own, so that nothing it records reaches the
# suite's. Printed: what it wrote on either stream, its status, and each name it
# recorded with the file it came from. The FAIL a fixture prints is its
# subshell's, and not recorded.
r279_loaded() {  # r279_loaded <file> -- record_loaded's output, its status, and the names it recorded
  ( declare -A LOADED_BODY=() LOADED_FROM=()
    record_loaded "$1" "$R279/record" 2>&1
    echo "status $?"
    for k in "${!LOADED_FROM[@]}"; do
      printf 'recorded %s from %s\n' "$k" "${LOADED_FROM[$k]##*/}"
    done | LC_ALL=C sort )
}
printf '%s\n' 'r279_a() { :; }' 'R279_V=1' > "$R279/whole.sh"
printf '%s\n' 'r279_a() { :; }' 'false' > "$R279/nonzero.sh"
: > "$R279/nothing.sh"
printf '%s\n' 'false' > "$R279/nothing-nonzero.sh"
printf '%s\n' 'r279_a() { :; }' 'exit 0' > "$R279/exits.sh"
# Killed partway: `declare` redefined so that the child's `declare -f` of the
# last function the file defines kills the child. Functions are recorded in
# name order, so `declare` and `r279_a` are printed and `r279_z` is not.
printf '%s\n' 'r279_a() { :; }' 'r279_z() { :; }' \
  'declare() { [[ $2 == r279_z ]] && kill -KILL $$; builtin declare "$@"; }' > "$R279/killed.sh"
req GH-279.1
tok 'a file that sources with status 0 and defines something is recorded, and no row is written' \
'status 0
recorded $R279_V from whole.sh
recorded r279_a from whole.sh' "$(r279_loaded "$R279/whole.sh")"
tok 'a file that sources non-zero is a FAIL row naming it and its status, and what it defined is recorded all the same' \
"  FAIL the record of $R279/nonzero.sh is not to be trusted whole: sourcing it returned 1; the names it holds are compared at the foot, and a name it lacks is not
status 0
recorded r279_a from nonzero.sh" "$(r279_loaded "$R279/nonzero.sh")"
tok 'a child killed partway through its record is a FAIL row, though the record it left is not empty' \
"  FAIL the record of $R279/killed.sh is not to be trusted whole: the child that records it exited 137; the names it holds are compared at the foot, and a name it lacks is not
status 0
recorded declare from killed.sh
recorded r279_a from killed.sh" "$(r279_loaded "$R279/killed.sh")"
tok 'and so is a file that ends the child before sourcing it returns' \
"  FAIL the record of $R279/exits.sh is not to be trusted whole: the child that records it ended before sourcing it returned; the names it holds are compared at the foot, and a name it lacks is not
status 0" "$(r279_loaded "$R279/exits.sh")"
tok 'a file that defines nothing stops the run, and writes no row' \
"sourcing $R279/nothing.sh alone defined nothing, so nothing of it can be compared at the foot; nothing was judged
status 1" "$(r279_loaded "$R279/nothing.sh")"
tok 'and so does one that defines nothing and sources non-zero, naming the status' \
"sourcing $R279/nothing-nonzero.sh alone defined nothing (sourcing it returned 1), so nothing of it can be compared at the foot; nothing was judged
status 1" "$(r279_loaded "$R279/nothing-nonzero.sh")"
# And the head records through it, stopping only on the one outcome that stops
# it. Pinned as text, since only a whole run shows it behaving; the registry
# row `tokeniser-sources-non-zero` is that run.
tok 'the head records each file through record_loaded, and stops the run only when it defined nothing' \
'for f in "$SUITE_DIR/checks/$SUITE_LIBRARY" "$HOOKS/lib/command-scan.sh"; do
  record_loaded "$f" "$FIXTURES/record" || exit 1
done' "$(grep -F -A2 'for f in "$SUITE_DIR/checks/$SUITE_LIBRARY" "$HOOKS/lib/command-scan.sh"; do' "${SUITE_FILES[0]}")"
tok 'and this run'"'"'s record of both was whole, or the head would have said so above' \
    'whole whole' \
    "$(for f in "$SUITE_DIR/checks/$SUITE_LIBRARY" "$HOOKS/lib/command-scan.sh"; do
         record_of "$f" "$R279/this-run" > /dev/null && printf 'whole '
       done | sed 's/ $//')"

# --- GH-279.2: the rows the ledger ends on, derived -----------------------------
#
# The derivation of this driver, as a literal: the heading question's row, then
# the final verdict's three clauses that write one.
req GH-279.2
tok 'the rows the ledger ends on, derived from this driver'"'"'s verdict code, are the heading question'"'"'s and one for each clause of FOOT_VERDICT_CODE' \
"$(printf '%s\t%s\n' \
   GH-204.8 'every heading section wrote down has at least one row under it' \
   GH-204.1 'every function and tokeniser variable this run started with is the one it ended with' \
   GH-204.5 'no command this suite called was missing, in this shell or in any subshell of it' \
   GH-204.5 'the not-found record is where the head put it, so what the handler wrote is what the verdict reads')" \
    "$(verdict_tail_want "${SUITE_FILES[0]}")"
# A driver of the verdict lines alone, copied from this one, and a ledger that
# ends as the derivation says, after a row of something else.
grep -E '^eval "\$[A-Z_]+_VERDICT_CODE"$' "${SUITE_FILES[0]}" > "$R279/driver"
printf '%s\t%s\t%s\t%s\n' \
  GH-1 static ok 'a row before them' \
  GH-204.8 static ok 'every heading section wrote down has at least one row under it' \
  GH-204.1 static ok 'every function and tokeniser variable this run started with is the one it ended with' \
  GH-204.5 static ok 'no command this suite called was missing, in this shell or in any subshell of it' \
  GH-204.5 static ok 'the not-found record is where the head put it, so what the handler wrote is what the verdict reads' \
  > "$R279/tail-ledger"
tok 'the driver fixture holds the three verdict lines, in the order this driver takes them' \
'SOURCED_VERDICT_CODE
FOOT_VERDICT_CODE
LEDGER_VERDICT_CODE' "$(sed 's/^eval "\$\(.*\)"$/\1/' "$R279/driver")"
tok 'a ledger that ends on the derived rows reads as matching' \
    '' "$(verdict_tail_read "$R279/driver" "$R279/tail-ledger")"
# The last verdict row replaced by another row of the same tag.
sed '$d' "$R279/tail-ledger" > "$R279/tail-swapped"
printf '%s\t%s\t%s\t%s\n' GH-204.5 static ok 'another GH-204.5 row' >> "$R279/tail-swapped"
tok 'a verdict row replaced by another row of the same tag is red, and both are named' \
"derived:
$(printf '%s\t%s\n' \
   GH-204.8 'every heading section wrote down has at least one row under it' \
   GH-204.1 'every function and tokeniser variable this run started with is the one it ended with' \
   GH-204.5 'no command this suite called was missing, in this shell or in any subshell of it' \
   GH-204.5 'the not-found record is where the head put it, so what the handler wrote is what the verdict reads')
the ledger ends:
$(printf '%s\t%s\n' \
   GH-204.8 'every heading section wrote down has at least one row under it' \
   GH-204.1 'every function and tokeniser variable this run started with is the one it ended with' \
   GH-204.5 'no command this suite called was missing, in this shell or in any subshell of it' \
   GH-204.5 'another GH-204.5 row')" "$(verdict_tail_read "$R279/driver" "$R279/tail-swapped")"
# A clause added to the verdict code, in a subshell of its own: the ledger
# above, which ends as the unchanged verdict derives, is red against it.
tok 'a clause added to the final verdict with no row known for it is named, and the ledger no longer matches' \
'FOOT_VERDICT_CODE has a clause with no row known for it: if [[ -e $R279_NONE ]]
red' "$( FOOT_VERDICT_CODE+=$'\nif [[ -e $R279_NONE ]]; then\n  FAILED=1\nfi'
         verdict_tail_want "$R279/driver" | tail -n 1
         [ -n "$(verdict_tail_read "$R279/driver" "$R279/tail-ledger")" ] && echo red )"
tok 'and so is one that sets the failure outside a clause of its own' \
    'FOOT_VERDICT_CODE sets FAILED in 4 places, and not each in a clause of its own' \
    "$( FOOT_VERDICT_CODE+=$'\n[[ -e $R279_NONE ]] && FAILED=1'
        verdict_tail_want "$R279/driver" | sed -n 2p )"
tok 'and a second clause in either verdict known to write no row' \
'SOURCED_VERDICT_CODE sets FAILED in 2 places, and one clause is all it is known to write no row for
LEDGER_VERDICT_CODE sets FAILED in 2 places, and one clause is all it is known to write no row for' \
    "$( SOURCED_VERDICT_CODE+=$'\n[[ -e $R279_NONE ]] && FAILED=1'
        LEDGER_VERDICT_CODE+=$'\n[[ -e $R279_NONE ]] && FAILED=1'
        verdict_tail_want "$R279/driver" | grep -v '^GH-' )"
# A verdict variable the table does not know, taken at the end of a driver.
# Written through printf, so that this file's text holds no evaluation of a
# verdict's code for GH-279.3's read to find.
cp "$R279/driver" "$R279/driver-more"
printf 'eval "$%s"\n' R279_EXTRA_VERDICT_CODE >> "$R279/driver-more"
tok 'and a verdict variable the table does not know is named' \
    'R279_EXTRA_VERDICT_CODE is taken at the end of the driver, and which rows it writes is not known' \
    "$(verdict_tail_want "$R279/driver-more" | grep -v '^GH-')"

# --- GH-279.3: the verdict fixtures, enumerated by where they stand -------------
#
# A block written in this shell, with a ledger and a marks record of its own:
# a fixture row whose label does not begin `the final verdict `, under a `req`
# left over from the block before it, the slip the label read could not see.
# Both are put back before anything is asked, so a FAIL below is recorded in
# the real ledger, as the #204.8 fixture in the unsplit file does it.
R279_LEDGER=$LEDGER R279_MARKS=$VERDICT_MARKS
LEDGER="$R279/marks-ledger" VERDICT_MARKS="$R279/marks"
: > "$LEDGER"; : > "$VERDICT_MARKS"
{ REQ=GH-9
  pass static 'a row before the block'
  verdict_fixtures begin
  pass static 'the final verdict fails on something'
  pass static 'a fixture row under another label'
  ( verdict_fixtures end )
  verdict_fixtures end
  pass static 'a row after the block'
} > /dev/null
LEDGER=$R279_LEDGER VERDICT_MARKS=$R279_MARKS
req GH-279.3
tok 'every row inside a block is read, whatever its label, and no row outside it' \
'GH-9 | the final verdict fails on something
GH-9 | a fixture row under another label' "$(verdict_fixture_rows "$R279/marks" "$R279/marks-ledger")"
tok 'which the read by label did not: it finds one row of the two' \
    'GH-9 | the final verdict fails on something' \
    "$(awk -F'\t' '$4 ~ /^the final verdict / || $4 == "and says why on stderr" { print $1 " | " $4 }' "$R279/marks-ledger")"
tok 'a mark is written with the rows the ledger held and the file that wrote it, and none from a subshell' \
"$(printf '%s\t%s\t%s\n' begin 1 checks/GH-279.sh end 3 checks/GH-279.sh)" "$(cat "$R279/marks")"
printf '%s\t%s\t%s\n' end 1 checks/a.sh begin 2 checks/a.sh begin 3 checks/a.sh > "$R279/marks-bad"
tok 'a mark out of place is named, and so is a block never ended' \
'a end mark in checks/a.sh out of place, after row 1
a begin mark in checks/a.sh out of place, after row 3
a block begun in checks/a.sh after row 2 and never ended' \
    "$(verdict_fixture_rows "$R279/marks-bad" "$R279/marks-ledger")"
# The blocks this run has marked so far: the unsplit file's two.
tok 'this run marked the unsplit file'"'"'s two blocks of verdict fixtures, each begun and ended' \
"$(printf '%s\t%s\n' begin checks/unsplit.sh end checks/unsplit.sh begin checks/unsplit.sh end checks/unsplit.sh)" \
    "$(cut -f1,3 "$VERDICT_MARKS")"
# An evaluation outside a block, written through printf for the reason above.
{ printf '%s\n' 'verdict_fixtures begin'
  printf 'x=$(eval "$%s")\n' FOOT_VERDICT_CODE
  printf '%s\n' 'verdict_fixtures end'
  printf '( eval "${%s}" )\n' SOURCED_VERDICT_CODE
} > "$R279/evals.sh"
printf 'eval "$%s"\n' LEDGER_VERDICT_CODE > "$R279/evals-second.sh"
tok 'a check file that evaluates a verdict'"'"'s code outside a block is named, by file and line, and in every file' \
"$R279/evals.sh:4
$R279/evals-second.sh:1" "$(verdict_evals_outside "$R279/evals.sh" "$R279/evals-second.sh")"
tok 'and one it cannot read is not taken for one with none' \
    'unread: awk exited 2' "$(verdict_evals_outside "$R279/no-such-file.sh")"

sourced_to_end

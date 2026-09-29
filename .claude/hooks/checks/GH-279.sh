#!/bin/bash
# THE ISSUE FILE OF #279: the end-of-run verdict's read-backs hard-coded and
# label-matched what they read, and the head's record child read a failed
# source as emptiness.
#
# FOUR DEFECTS, under the three requirements below, each found by review of PR
# #216 or PR #220 and each latent when #279 was filed; the first two are one
# requirement's, because they had to be fixed together.
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
# Its first run found two fixture guards stopping it the same way, below.

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
  so, with the status when it was not 0. The child records in a shell of its
  own setting and not the one the file left: what the file left in IFS,
  globbing, case matching, traps, aliases or enabled builtins changes neither
  which names it records nor how it ends. What it records with is out of the
  file's reach: the names it started with are kept outside any variable while
  the file is sourced, and a file that declared a name the child works with,
  or left a setting it cannot put back, is a FAIL row saying so. And a fixture the suite builds from a copy of the
  tokeniser -- a half-library, an emptied-list library -- is judged to load
  by what sourcing it defined and by a status that is the one sourcing the
  tokeniser it was copied from returns, not by a status of 0: a tokeniser copy
  that sources non-zero, as the tokeniser does, is judged by the run and does
  not stop it, and a copy its builder broke into another status does.
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
  When #279 was filed, the reviewer probed the 26 registry rows then
  applicable that mutate the tokeniser, and each sourced with status 0, so
  neither had fired. Measured again on the merge of dev-05 at 1486270, once
  #202 had grown it: 83 rows name the tokeniser, 82 of them change it, and every one of
  those but tokeniser-sources-non-zero sources with status 0. A record the child did
  not finish is used all the same once the row has failed the run: a name it
  lacks is not compared at the foot, and the row is what says so. A child that
  did not finish and recorded nothing is such a row too, and not a stop: that
  the file would have defined nothing is what it did not get to say. And a
  file that turns on `set -e` and then fails ends the child, so its row says
  the child exited, not that sourcing returned; either way it is a FAIL.
  Round 1 of the review of PR #330 found two more on this branch, each
  measured: the two fixture guards had been loosened to ask only that a name
  was defined, so a copy its builder broke passed them; and a file that left
  IFS changed gave a record the child called whole while it lacked names,
  which the sweep of that class found nullglob, nocasematch, an EXIT trap
  and an alias of `declare` doing too. Round 2 found the class inside that
  fix: the child's own bookkeeping, `bf`, `bv`, `n` and `v`, and the reset's
  own success, were the file's to change -- a readonly `v`, or `bf` assigned,
  dropped a name from a record called whole -- and its sweep found builtins
  the file disables with `enable -n` doing the same.
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
  A clause is counted by the lines of the code that name FAILED, however the
  assignment is spelt. What it does not see, named: a clause that sets the
  failure without naming FAILED on its line, through another variable or text
  it evaluates. A clause written as `if` over more than one line is counted
  as a line outside a clause of its own, and is red, not missed.
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
# subshell's, and not recorded; its prefix is rewritten `FAIL:`, because a
# quoted string opening with a result's own prefix is read by the #104 audit
# as a result printed outside `pass` and `fail`.
r279_loaded() {  # r279_loaded <file> -- record_loaded's output, its status, and the names it recorded
  ( declare -A LOADED_BODY=() LOADED_FROM=() LOADED_STATUS=()
    record_loaded "$1" "$R279/record" > "$R279/said" 2>&1
    loaded_status=$?
    sed 's/^  FAIL /FAIL: /' "$R279/said"
    echo "status $loaded_status"
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
"FAIL: the record of $R279/nonzero.sh is not to be trusted whole: sourcing it returned 1; the names it holds are compared at the foot, and a name it lacks is not
status 0
recorded r279_a from nonzero.sh" "$(r279_loaded "$R279/nonzero.sh")"
tok 'a child killed partway through its record is a FAIL row, though the record it left is not empty' \
"FAIL: the record of $R279/killed.sh is not to be trusted whole: the child that records it exited 137; the names it holds are compared at the foot, and a name it lacks is not
status 0
recorded declare from killed.sh
recorded r279_a from killed.sh" "$(r279_loaded "$R279/killed.sh")"
tok 'and so is a file that ends the child before sourcing it returns' \
"FAIL: the record of $R279/exits.sh is not to be trusted whole: the child that records it ended before sourcing it returned; the names it holds are compared at the foot, and a name it lacks is not
status 0" "$(r279_loaded "$R279/exits.sh")"
tok 'a file that defines nothing stops the run, and writes no row' \
"sourcing $R279/nothing.sh alone defined nothing, so nothing of it can be compared at the foot; nothing was judged
status 1" "$(r279_loaded "$R279/nothing.sh")"
tok 'and so does one that defines nothing and sources non-zero, naming the status' \
"sourcing $R279/nothing-nonzero.sh alone defined nothing (sourcing it returned 1), so nothing of it can be compared at the foot; nothing was judged
status 1" "$(r279_loaded "$R279/nothing-nonzero.sh")"
# A caller's tag is the same after the FAIL row as before it: the row is tagged
# through a `local` REQ, and a routine the head calls once would otherwise
# clear the tag of any later caller (round 1 of the review of PR #330).
tok 'a caller'"'"'s tag is the same after record_loaded writes a FAIL row as before it' \
    'GH-1' "$( ( req GH-1; record_loaded "$R279/nonzero.sh" "$R279/record" > /dev/null 2>&1; printf '%s' "$REQ" ) )"
# THE CHILD RECORDS IN A SHELL OF ITS OWN SETTING (round 1 of the review of PR
# #330). Each file below leaves the child's shell set some way, and before the
# reset in LOADED_CHILD each was measured to leave a record the child called
# whole that lacked a name: IFS joined every name into one key, nullglob
# dropped the function whose name is a glob, and nocasematch skipped `path`
# as though it were the `PATH` the child started with. An EXIT trap and an
# alias follow.
printf '%s\n' 'r279_a() { :; }' 'r279_b() { :; }' 'R279_V=1' 'IFS=x' > "$R279/state-ifs.sh"
printf '%s\n' 'r279_a() { :; }' 'r279_g*() { :; }' 'shopt -s nullglob' > "$R279/state-glob.sh"
printf '%s\n' 'r279_a() { :; }' 'path=1' 'shopt -s nocasematch' > "$R279/state-case.sh"
printf '%s\n' 'r279_a() { :; }' "trap 'exit 0' EXIT" > "$R279/state-trap.sh"
tok 'a file that leaves IFS changed has each of its names recorded, and no row is written' \
'status 0
recorded $R279_V from state-ifs.sh
recorded r279_a from state-ifs.sh
recorded r279_b from state-ifs.sh' "$(r279_loaded "$R279/state-ifs.sh")"
tok 'and so does one that turns nullglob on, its function whose name is a glob among them' \
'status 0
recorded r279_a from state-glob.sh
recorded r279_g* from state-glob.sh' "$(r279_loaded "$R279/state-glob.sh")"
tok 'and so does one that turns nocasematch on, a variable whose name differs from one the child started with only in case among them' \
'status 0
recorded $path from state-case.sh
recorded r279_a from state-case.sh' "$(r279_loaded "$R279/state-case.sh")"
# An EXIT trap changes nothing while the child finishes, so it is driven where
# the child's write fails: its stdout is /dev/full, and the child has to exit
# 3. Without the reset, `trap 'exit 0' EXIT` made that 0 -- a whole record. The
# same write from a file with no trap is the control that /dev/full fails it.
tok 'a file that traps EXIT is recorded, and no row is written' \
'status 0
recorded r279_a from state-trap.sh' "$(r279_loaded "$R279/state-trap.sh")"
tok 'the child whose write fails exits 3' \
    'exited 3' "$(env -i PATH="$PATH" "$BASH" -c "$LOADED_CHILD" _ "$R279/whole.sh" > /dev/full 3> "$R279/full.sourced" 4> "$R279/full.before" 5< "$R279/full.before" 2> /dev/null; echo "exited $?")"
tok 'and still exits 3 when the file it sourced traps EXIT to exit 0' \
    'exited 3' "$(env -i PATH="$PATH" "$BASH" -c "$LOADED_CHILD" _ "$R279/state-trap.sh" > /dev/full 3> "$R279/full.sourced" 4> "$R279/full.before" 5< "$R279/full.before" 2> /dev/null; echo "exited $?")"
# And an alias the file defines expands in the lines the child reads after
# it: with `declare` aliased to `builtin echo`, the child recorded r279_a's body
# as `-f r279_a` and exited 0. The body is compared, since the name is right.
printf '%s\n' 'r279_a() { :; }' 'shopt -s expand_aliases' "alias declare='builtin echo'" > "$R279/state-alias.sh"
tok 'a file that aliases declare has its function recorded as bash defines it, not as the alias prints it' \
    $'r279_a () \n{ \n    :\n}' \
    "$( ( declare -A LOADED_BODY=() LOADED_FROM=() LOADED_STATUS=()
          record_loaded "$R279/state-alias.sh" "$R279/record" > /dev/null 2>&1
          printf '%s' "${LOADED_BODY[r279_a]}" ) )"
# WHAT THE CHILD WORKS WITH IS OUT OF THE FILE'S REACH, OR THE CHILD SAYS SO
# (round 2 of the review of PR #330). The child held the names it started with
# in `bf` and `bv` and looped through `n` and `v`, and a file could reach all
# four: `bf=" r279_a "` dropped r279_a, `readonly v` dropped R279_V, `bv=" ...
# "` recorded bash's own variables, and `readonly n` emptied the record. Now
# they are the file's names like any other, and recorded.
printf '%s\n' 'r279_a() { :; }' 'R279_V=1' 'bf=" r279_a "' > "$R279/own-bf.sh"
printf '%s\n' 'r279_a() { :; }' 'R279_V=1' 'readonly v=2' > "$R279/own-v.sh"
printf '%s\n' 'r279_a() { :; }' 'R279_V=1' 'bv=" R279_V "' > "$R279/own-bv.sh"
printf '%s\n' 'r279_a() { :; }' 'R279_V=1' 'readonly n=3' > "$R279/own-n.sh"
tok 'a file that assigns bf has every name it defines recorded, bf among them' \
'status 0
recorded $R279_V from own-bf.sh
recorded $bf from own-bf.sh
recorded r279_a from own-bf.sh' "$(r279_loaded "$R279/own-bf.sh")"
tok 'and so does one that makes v readonly' \
'status 0
recorded $R279_V from own-v.sh
recorded $v from own-v.sh
recorded r279_a from own-v.sh' "$(r279_loaded "$R279/own-v.sh")"
tok 'and one that assigns bv, which records none of bash'"'"'s own variables' \
'status 0
recorded $R279_V from own-bv.sh
recorded $bv from own-bv.sh
recorded r279_a from own-bv.sh' "$(r279_loaded "$R279/own-bv.sh")"
tok 'and one that makes n readonly' \
'status 0
recorded $R279_V from own-n.sh
recorded $n from own-n.sh
recorded r279_a from own-n.sh' "$(r279_loaded "$R279/own-n.sh")"
# The names the child does work with, and a reset it cannot make: each ends it
# with 4, which is a FAIL row that says so.
printf '%s\n' 'r279_a() { :; }' '_lc_v=1' > "$R279/lc-name.sh"
printf '%s\n' 'r279_a() { :; }' 'readonly _lc_n' > "$R279/lc-readonly.sh"
printf '%s\n' 'r279_a() { :; }' 'readonly IFS=x' > "$R279/ifs-readonly.sh"
printf '%s\n' 'r279_a() { :; }' 'enable -n enable' > "$R279/enable-off.sh"
tok 'a file that assigns a name the child works with is a FAIL row saying the child could not put it back' \
"FAIL: the record of $R279/lc-name.sh is not to be trusted whole: sourcing it left a name or a setting the child that records it works with, and the child could not put it back; the names it holds are compared at the foot, and a name it lacks is not
status 0" "$(r279_loaded "$R279/lc-name.sh")"
tok 'and so is one that declares such a name readonly, with no value' \
"FAIL: the record of $R279/lc-readonly.sh is not to be trusted whole: sourcing it left a name or a setting the child that records it works with, and the child could not put it back; the names it holds are compared at the foot, and a name it lacks is not
status 0" "$(r279_loaded "$R279/lc-readonly.sh")"
tok 'and one that makes IFS readonly, so that the reset cannot be made' \
"FAIL: the record of $R279/ifs-readonly.sh is not to be trusted whole: sourcing it left a name or a setting the child that records it works with, and the child could not put it back; the names it holds are compared at the foot, and a name it lacks is not
status 0" "$(r279_loaded "$R279/ifs-readonly.sh")"
tok 'and one that disables enable, so that no builtin can be enabled again' \
"FAIL: the record of $R279/enable-off.sh is not to be trusted whole: sourcing it left a name or a setting the child that records it works with, and the child could not put it back; the names it holds are compared at the foot, and a name it lacks is not
status 0" "$(r279_loaded "$R279/enable-off.sh")"
# A builtin the child calls, disabled by the file: `enable -n compgen` recorded
# nothing, `enable -n printf` recorded garbage keys, and `enable -n declare`
# recorded every body empty. Each is enabled again before the record.
printf '%s\n' 'r279_a() { :; }' 'R279_V=1' 'enable -n compgen' > "$R279/off-compgen.sh"
printf '%s\n' 'r279_a() { :; }' 'R279_V=1' 'enable -n printf' > "$R279/off-printf.sh"
printf '%s\n' 'r279_a() { :; }' 'enable -n declare' > "$R279/off-declare.sh"
tok 'a file that disables compgen has every name it defines recorded' \
'status 0
recorded $R279_V from off-compgen.sh
recorded r279_a from off-compgen.sh' "$(r279_loaded "$R279/off-compgen.sh")"
tok 'and so does one that disables printf' \
'status 0
recorded $R279_V from off-printf.sh
recorded r279_a from off-printf.sh' "$(r279_loaded "$R279/off-printf.sh")"
tok 'and one that disables declare has its function recorded as bash defines it' \
    $'r279_a () \n{ \n    :\n}' \
    "$( ( declare -A LOADED_BODY=() LOADED_FROM=() LOADED_STATUS=()
          record_loaded "$R279/off-declare.sh" "$R279/record" > /dev/null 2>&1
          printf '%s' "${LOADED_BODY[r279_a]}" ) )"
# And the head records through it, stopping only on the one outcome that stops
# it. Pinned as text, since only a whole run shows it behaving; the registry
# row `tokeniser-sources-non-zero` is that run.
tok 'the head records each file through record_loaded, and stops the run only when it defined nothing' \
'for f in "$SUITE_DIR/checks/$SUITE_LIBRARY" "$HOOKS/lib/command-scan.sh"; do
  record_loaded "$f" "$FIXTURES/record" || exit 1
done' "$(grep -F -A2 'for f in "$SUITE_DIR/checks/$SUITE_LIBRARY" "$HOOKS/lib/command-scan.sh"; do' "${SUITE_FILES[0]}")"
# AND THE FIXTURE GUARDS THAT LOAD A COPY OF THE TOKENISER (#279). The first
# run of the registry row tokeniser-sources-non-zero, with the head fixed, came
# back did-not-complete all the same: `mk_halflib` asked `. lib && command -v`,
# and its guard stopped the run on the status, saying the copy "does not load
# at all" -- the head's defect one fixture over. `mk_emptylist`, in the unsplit
# file, asked the same way. Both then asked only what sourcing defined, and
# round 1 of the review of PR #330 measured the cost: a copy its builder broke,
# which defines every name and sources with status 2, passed every
# half-library guard. So each asks `copy_sources_as` as well: the copy's status
# is the original's. Both builders are driven here, each in both directions --
# against a copy of the tokeniser that ends in `false`, which they build, and
# against a small original whose copy their own edit breaks, which they refuse.
mkdir -p "$R279/hooks-false/lib"
cp "$HOOKS/no-git-push.sh" "$R279/hooks-false/"
{ cat "$HOOKS/lib/command-scan.sh"; echo false; } > "$R279/hooks-false/lib/command-scan.sh"
tok 'the tokeniser copy the guard is asked about sources with a non-zero status' \
    'status 1' "$(bash -c '. "$1" 2>/dev/null; echo "status $?"' _ "$R279/hooks-false/lib/command-scan.sh")"
tok 'and a half-library built from it is built, and does not stop the run' \
    'status 0' "$( ( HOOKS="$R279/hooks-false" FIXTURES="$R279/halflib"; mk_halflib no-git-push.sh cs_split ) 2>&1; echo "status $?" )"
tok 'and so is an emptied-list library' \
    'status 0' "$( ( HOOKS="$R279/hooks-false" FIXTURES="$R279/emptylist"; mk_emptylist no-git-push.sh ) 2>&1; echo "status $?" )"
tok 'a copy that sources with the status its original does is not refused' \
    'status 0: ' "$(why=$(copy_sources_as "$R279/nonzero.sh" "$R279/nonzero.sh"); echo "status $?: $why")"
printf '%s\n' 'r279_a() { :; }' 'if true; then' > "$R279/unterminated.sh"
tok 'a copy that sources with status 2 where its original sources with 0 is refused, naming both' \
    'status 1: it sources with status 2, and the tokeniser it was copied from with 0' \
    "$(why=$(copy_sources_as "$R279/unterminated.sh" "$R279/whole.sh"); echo "status $?: $why")"
# Originals whose copy the builder's own edit breaks. The half-library's rename
# leaves the top-level call to cs_split with nothing to call, 127; the emptied
# list fails the test the original ends on, 1. Each copy still defines every
# name its guard asks for, so a guard that asked only that would build it.
mkdir -p "$R279/hooks-renamed/lib" "$R279/hooks-emptied/lib"
cp "$HOOKS/no-git-push.sh" "$R279/hooks-renamed/"
cp "$HOOKS/no-git-push.sh" "$R279/hooks-emptied/"
printf '%s\n' 'cs_split() { :; }' 'cs_split' > "$R279/hooks-renamed/lib/command-scan.sh"
printf '%s\n' "CS_WRAP_OPTION_WORDS='a'" "CS_WRAP_OPERAND_WORDS='b'" \
  'cs_normalise() { :; }' 'cs_git_args() { :; }' 'cs_gh_args() { :; }' 'cs_join() { :; }' \
  '[ -n "$CS_WRAP_OPTION_WORDS" ]' > "$R279/hooks-emptied/lib/command-scan.sh"
tok 'a half-library its builder broke into another status stops the run, naming both' \
    'the half-library for no-git-push.sh does not source as the tokeniser it was copied from: it sources with status 127, and the tokeniser it was copied from with 0; the check using it proves nothing
status 1' "$( ( HOOKS="$R279/hooks-renamed" FIXTURES="$R279/halflib-renamed"; mk_halflib no-git-push.sh cs_split ) 2>&1; echo "status $?" )"
tok 'and so does an emptied-list library' \
    'the emptied-list library for no-git-push.sh does not source as the tokeniser it was copied from: it sources with status 1, and the tokeniser it was copied from with 0; the checks using it prove nothing
status 1' "$( ( HOOKS="$R279/hooks-emptied" FIXTURES="$R279/emptylist-emptied"; mk_emptylist no-git-push.sh ) 2>&1; echo "status $?" )"
# And what the head found when it recorded the two files this run judges: its
# own outcome for each, as record_loaded kept it, and not a second recording
# of the files (round 1 of the review of PR #330).
tok 'and the head found its record of both whole: the outcome it kept for each is 0' \
    '0 0' "${LOADED_STATUS[$SUITE_DIR/checks/$SUITE_LIBRARY]-unset} ${LOADED_STATUS[$HOOKS/lib/command-scan.sh]-unset}"

# --- GH-279.2: the rows the ledger ends on, derived -----------------------------
#
# The derivation of this driver, as a literal: the heading question's row, then
# the final verdict's three clauses that write one.
req GH-279.2
R279_TAIL=$(printf '%s\t%s\n' \
   GH-204.8 'every heading section wrote down has at least one row under it' \
   GH-204.1 'every function and tokeniser variable this run started with is the one it ended with' \
   GH-204.5 'no command this suite called was missing, in this shell or in any subshell of it' \
   GH-204.5 'the not-found record is where the head put it, so what the handler wrote is what the verdict reads')
tok 'the rows the ledger ends on, derived from this driver'"'"'s verdict code, are the heading question'"'"'s and one for each clause of FOOT_VERDICT_CODE' \
    "$R279_TAIL" "$(verdict_tail_want "${SUITE_FILES[0]}")"
# A driver of the verdict lines alone, copied from this one, and a ledger that
# ends as the derivation says, after a row of something else.
grep -E '^eval "\$[A-Za-z0-9_]+_VERDICT_CODE"$' "${SUITE_FILES[0]}" > "$R279/driver"
{ printf '%s\t%s\t%s\t%s\n' GH-1 static ok 'a row before them'
  awk -F'\t' '{ print $1 "\tstatic\tok\t" $2 }' <<< "$R279_TAIL"
} > "$R279/tail-ledger"
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
$R279_TAIL
the ledger ends:
$(sed '$d' <<< "$R279_TAIL")
$(printf '%s\t%s' GH-204.5 'another GH-204.5 row')" "$(verdict_tail_read "$R279/driver" "$R279/tail-swapped")"
# A clause added to the verdict code, in a subshell of its own: the ledger
# above, which ends as the unchanged verdict derives, is red against it.
tok 'a clause added to the final verdict with no row known for it is named, and the ledger no longer matches' \
'FOOT_VERDICT_CODE has a clause with no row known for it: if [[ -e $R279_NONE ]]
red' "$( FOOT_VERDICT_CODE+=$'\nif [[ -e $R279_NONE ]]; then\n  FAILED=1\nfi'
         verdict_tail_want "$R279/driver" | tail -n 1
         [ -n "$(verdict_tail_read "$R279/driver" "$R279/tail-ledger")" ] && echo red )"
# The failure set outside an `if`, and spelt without `FAILED=`, which the
# count of `FAILED=` let by (review of #279's first round).
tok 'and so is one that sets the failure outside a clause of its own, however the assignment is spelt' \
    'FOOT_VERDICT_CODE names FAILED on 4 lines, and not each in a clause of its own' \
    "$( FOOT_VERDICT_CODE+=$'\n[[ -e $R279_NONE ]] && (( FAILED = 1 ))'
        verdict_tail_want "$R279/driver" | sed -n 2p )"
tok 'and a second clause in either verdict known to write no row' \
'SOURCED_VERDICT_CODE names FAILED on 2 lines, and one clause is all it is known to write no row for
LEDGER_VERDICT_CODE names FAILED on 2 lines, and one clause is all it is known to write no row for' \
    "$( SOURCED_VERDICT_CODE+=$'\n[[ -e $R279_NONE ]] && let FAILED=1'
        LEDGER_VERDICT_CODE+=$'\n[[ -e $R279_NONE ]] && printf -v FAILED 1'
        verdict_tail_want "$R279/driver" | grep -v '^GH-' )"
# A verdict variable the table does not know, taken at the end of a driver:
# its name holding a digit, which the first reading of the driver's lines,
# `[A-Z_]*`, did not see; indented, braced and followed by more, which the
# anchored reading did not see (review of #279's first round); and one in a
# comment, which is not taken. Written through printf, so that this file's
# text holds no evaluation of a verdict's code for GH-279.3's read to find.
cp "$R279/driver" "$R279/driver-more"
printf '  eval "${%s}" || :\n' R279_EXTRA_VERDICT_CODE >> "$R279/driver-more"
printf '# eval "$%s"\n' R279_COMMENTED_VERDICT_CODE >> "$R279/driver-more"
tok 'and a verdict variable the table does not know is named, however the line spells it, and one in a comment is not' \
    'R279_EXTRA_VERDICT_CODE is taken at the end of the driver, and which rows it writes is not known' \
    "$(verdict_tail_want "$R279/driver-more" | grep -v '^GH-')"

# --- GH-279.3: the verdict fixtures, enumerated by where they stand -------------
#
# A block written in this shell, with a ledger and a marks record of its own:
# a fixture row whose label does not begin `the final verdict `, under a `req`
# left over from the block before it, the slip the label read could not see.
# Both are put back before anything is asked, so a FAIL below is recorded in
# the real ledger, as GH-204.8's fixture in the unsplit file does it.
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
printf 'eval "$%s"\n' R279_VERDICT_CODE > "$R279/evals-second.sh"
tok 'a check file that evaluates a verdict'"'"'s code outside a block is named, by file and line, in every file, whatever the name' \
"$R279/evals.sh:4
$R279/evals-second.sh:1" "$(verdict_evals_outside "$R279/evals.sh" "$R279/evals-second.sh")"
tok 'and one it cannot read is not taken for one with none' \
    'unread: awk exited 2' "$(verdict_evals_outside "$R279/no-such-file.sh")"

sourced_to_end

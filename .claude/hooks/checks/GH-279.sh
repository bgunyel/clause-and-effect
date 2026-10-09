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
  sourcing returned non-zero, and a child that wrote no status, exited
  non-zero, was killed, or dumped what the suite cannot read whole, is a FAIL
  row at the head, under GH-279.1, naming the file and why; the run goes on to
  its verdict. A file whose sourcing defined nothing still stops the run, and
  says so, with the status when it was not 0. After the source the child runs
  only bash's own listings, from a line parsed before the file ran, and the
  record is made from them in the suite's shell; so what the fixtures leave in
  the child's shell -- IFS, globbing, case matching, traps, aliases, disabled
  builtins, a trace, and names the child once worked with -- is recorded as
  bash holds it or is a FAIL row saying why. That is the whole of the claim:
  each clause is a fixture, and what the child does not reach is named in the
  note. And a fixture the suite builds from a copy of the tokeniser -- a
  half-library, an emptied-list library -- is judged to load by what sourcing
  it defined and by a status that is the one sourcing the tokeniser it was
  copied from returns, not by a status of 0: a tokeniser copy that sources
  non-zero, as the tokeniser does, is judged by the run and does not stop it,
  and a copy its builder broke into another status does.
- from: #279
- kind: defect-permitting
- status: active
- direction: static: it drives the suite's own record child against fixture
  files and hand-written dumps, and reads the driver's loop
- note: Two defects, fixed together (filed from the reviews of PR #216 and PR
  #220). A copy that sourced non-zero left an empty record and stopped the run
  as a file that "defined nothing", which is the refusing direction; a child
  that died partway left a partial record that passed as whole, which is the
  permitting one, and gives this entry its kind. When #279 was filed, the
  reviewer probed the 26 registry rows then applicable that mutate the
  tokeniser, and each sourced with status 0, so neither had fired. Measured
  again on the merge of dev-05 at 1486270, once #202 had grown it: 83 rows name
  the tokeniser, 82 of them change it, and every one of those but
  tokeniser-sources-non-zero sources with status 0. A child that did not finish
  leaves no record, and its row is what fails the run; a file that turns on
  `set -e` and then fails ends the child before it writes a status, and its row
  says so. Review of PR #330 found the rest on this branch, each measured.
  Round 1: the two fixture guards had been loosened to ask only that a name was
  defined, so a copy its builder broke passed them; and a file that left IFS
  changed gave a record the child called whole while it lacked names, which the
  sweep of that class found nullglob, nocasematch, an EXIT trap and an alias of
  `declare` doing too. Round 2 found the class inside that fix -- the child's
  own variables, and builtins disabled with `enable -n` -- and round 3 inside
  the next: `exit` aliased under every guard written after the source, and a
  trace written into the record. Each fix had been a guard, and each guard more
  program for the next state to reach, so round 3 took the program out of the
  child instead. Round 4 found the reader of its dumps stricter than bash: it
  refused what `declare -f` prints for an exported, readonly or traced
  function, and for one written with redirections, each of which the child
  before #279 recorded; it reads both now, and records each as that child did.
  Round 6 found the child's starting variables taken from `declare -p`, which
  lists OLDPWD declared and unset where `compgen -v` does not, so a file that
  changed directory had OLDPWD left out of its record; they are `compgen -v`'s
  now, as that child's were. What the child does not reach, named: a record
  forged on purpose -- a status and a dump in bash's shape, written through the
  descriptors bash saves 3 to 7 at while the file is sourced, from a DEBUG trap
  that outlives the source or an EXIT trap, or by a function the file defines
  under the name of a builtin the child calls, `declare`, `enable` or `printf`,
  which is the head's shadowed-builtin limit -- since these checks stop
  mistakes and not adversaries; a name bash itself starts with, `OPTIND` or
  `PS4` say, which a file assigns, since the child compares against the names
  it started with and that was so before #279 too; a heredoc in a function's
  body that holds a `}` line and then a line that is the next function's
  header, which cuts the function there and gives the next one its tail, so
  that the foot reads both as redefined -- the other order, the header first,
  is refused -- and the rest of what a heredoc in a body can do to the reader,
  which is #363's; a variable declared with no value, which is not recorded, as
  `compgen -v` did not list it for the child before #279 (rounds 5 and 6 made
  the two agree); and any state a file can leave in the child's shell that no
  fixture here drives. `set -e`, `set -u` and posix mode left at the end of a
  file were probed and changed no record; no fixture holds that.
REQ
requirement GH-279.2 <<'REQ'
- text: The end-of-run file's last check before the matrix derives the rows the
  ledger has to end on from the verdict code the driver ends on -- the heading
  question's row, then one for each clause of the final verdict that writes
  one, in order -- and compares each row's tags, and the label of each row that
  passed. Which clauses write a row is a table beside the derivation: each
  clause of FOOT_VERDICT_CODE writes one; SOURCED_VERDICT_CODE and
  LEDGER_VERDICT_CODE write none, and each is held to the one clause it has. A
  verdict variable, a clause, or a place that sets the failure outside a clause
  of its own, that the table does not know, is red until the table says what it
  writes.
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
  A row that failed is read by its tags and not its label, since the label a
  clause writes when it fails carries the failure's detail, and the table
  knows the one it writes when it passes; reading both made a failing verdict
  row fail this check too, under requirements that did nothing wrong (round 6
  of the review of PR #330). What that lets by, named: a FAIL row standing in
  for another row of its tag, which the run is red on all the same.
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
# Killed partway: `declare` redefined so that the child's `declare -f` kills
# it, once the status and the function names are written and before the
# functions are.
printf '%s\n' 'r279_a() { :; }' \
  'declare() { [[ $1 == -f ]] && kill -KILL $$; builtin declare "$@"; }' > "$R279/killed.sh"
req GH-279.1
tok 'a file that sources with status 0 and defines something is recorded, and no row is written' \
'status 0
recorded $R279_V from whole.sh
recorded r279_a from whole.sh' "$(r279_loaded "$R279/whole.sh")"
tok 'a file that sources non-zero is a FAIL row naming it and its status, and what it defined is recorded all the same' \
"FAIL: the record of $R279/nonzero.sh holds what sourcing it defined, but sourcing it returned 1; that is compared at the foot, and a name it did not get to define is not
status 0
recorded r279_a from nonzero.sh" "$(r279_loaded "$R279/nonzero.sh")"
tok 'a child killed partway through its dump is a FAIL row, and leaves no record' \
"FAIL: the record of $R279/killed.sh was not made: the child that records it exited 137; nothing of it is compared at the foot
status 0" "$(r279_loaded "$R279/killed.sh")"
tok 'and so is a file that ends the child before sourcing it returns' \
"FAIL: the record of $R279/exits.sh was not made: the child that records it wrote no status for it: it ended before sourcing it returned, or could not write one; nothing of it is compared at the foot
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
# WHAT A FILE LEAVES IN THE CHILD'S SHELL (review rounds 1 to 3 of PR #330).
# Each file below leaves the child's shell set some way, and each was measured
# against the child that round replaced to give a record called whole that was
# wrong: a name missing, a bogus key, a body that was not bash's, or a failure
# read as success. Since round 3 the child runs no program after the source,
# only bash's own listings, and the record is made in this shell, so each
# of these is recorded as bash holds it or is a FAIL row that says why. The
# rows are the cases that found the class, round by round.
#
# Round 1: IFS, nullglob, nocasematch, an EXIT trap, an alias of `declare`.
printf '%s\n' 'r279_a() { :; }' 'r279_b() { :; }' 'R279_V=1' 'IFS=x' > "$R279/state-ifs.sh"
printf '%s\n' 'r279_a() { :; }' 'r279_g*() { :; }' 'shopt -s nullglob' > "$R279/state-glob.sh"
printf '%s\n' 'r279_a() { :; }' 'path=1' 'shopt -s nocasematch' > "$R279/state-case.sh"
printf '%s\n' 'r279_a() { :; }' "trap 'exit 0' EXIT" > "$R279/state-trap.sh"
printf '%s\n' 'r279_a() { :; }' 'shopt -s expand_aliases' "alias declare='builtin echo'" > "$R279/state-alias.sh"
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
tok 'a file that traps EXIT is recorded, and no row is written' \
'status 0
recorded r279_a from state-trap.sh' "$(r279_loaded "$R279/state-trap.sh")"
tok 'a file that aliases declare has its function recorded as bash defines it, not as the alias prints it' \
    $'r279_a () \n{ \n    :\n}' \
    "$( ( declare -A LOADED_BODY=() LOADED_FROM=() LOADED_STATUS=()
          record_loaded "$R279/state-alias.sh" "$R279/record" > /dev/null 2>&1
          printf '%s' "${LOADED_BODY[r279_a]}" ) )"
# Round 2: the names the child worked with, `bf`, `bv`, `n`, `v` and then
# `_lc_*`, and builtins disabled with `enable -n`. The child has no names of
# its own now, so each is a name of the file's, recorded like any other.
printf '%s\n' 'r279_a() { :; }' 'R279_V=1' 'bf=" r279_a "' > "$R279/own-bf.sh"
printf '%s\n' 'r279_a() { :; }' 'R279_V=1' 'readonly v=2' > "$R279/own-v.sh"
printf '%s\n' 'r279_a() { :; }' 'R279_V=1' 'bv=" R279_V "' > "$R279/own-bv.sh"
printf '%s\n' 'r279_a() { :; }' 'R279_V=1' 'readonly n=3' > "$R279/own-n.sh"
printf '%s\n' 'r279_a() { :; }' '_lc_v=1' > "$R279/lc-name.sh"
printf '%s\n' 'r279_a() { :; }' 'readonly _lc_n' > "$R279/lc-readonly.sh"
printf '%s\n' 'r279_a() { :; }' 'readonly IFS=x' > "$R279/ifs-readonly.sh"
printf '%s\n' 'r279_a() { :; }' 'enable -n enable' > "$R279/enable-off.sh"
printf '%s\n' 'r279_a() { :; }' 'R279_V=1' 'enable -n compgen' > "$R279/off-compgen.sh"
printf '%s\n' 'r279_a() { :; }' 'R279_V=1' 'enable -n printf' > "$R279/off-printf.sh"
printf '%s\n' 'r279_a() { :; }' 'enable -n declare' > "$R279/off-declare.sh"
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
tok 'and one that assigns _lc_v' \
'status 0
recorded $_lc_v from lc-name.sh
recorded r279_a from lc-name.sh' "$(r279_loaded "$R279/lc-name.sh")"
tok 'and one that declares _lc_n readonly with no value, which is not recorded, as the child before #279 did not record it' \
'status 0
recorded r279_a from lc-readonly.sh' "$(r279_loaded "$R279/lc-readonly.sh")"
tok 'and one that makes IFS readonly' \
'status 0
recorded r279_a from ifs-readonly.sh' "$(r279_loaded "$R279/ifs-readonly.sh")"
tok 'and one that disables enable' \
'status 0
recorded r279_a from enable-off.sh' "$(r279_loaded "$R279/enable-off.sh")"
tok 'and one that disables compgen' \
'status 0
recorded $R279_V from off-compgen.sh
recorded r279_a from off-compgen.sh' "$(r279_loaded "$R279/off-compgen.sh")"
tok 'and one that disables printf' \
'status 0
recorded $R279_V from off-printf.sh
recorded r279_a from off-printf.sh' "$(r279_loaded "$R279/off-printf.sh")"
# `declare` is the one builtin the child enables again, and this row is what
# holds that: with it disabled and not enabled, there is no dump at all.
tok 'and one that disables declare has its function recorded as bash defines it' \
    $'r279_a () \n{ \n    :\n}' \
    "$( ( declare -A LOADED_BODY=() LOADED_FROM=() LOADED_STATUS=()
          record_loaded "$R279/off-declare.sh" "$R279/record" > /dev/null 2>&1
          printf '%s' "${LOADED_BODY[r279_a]}" ) )"
# Round 3: `exit` aliased to `:`, which reached every guard written on a line
# after the source, and a trace pointed at the record. Nothing after the source
# is parsed after it now, and the child's standard output is /dev/null.
printf '%s\n' 'r279_a() { :; }' 'R279_V=1' 'shopt -s expand_aliases' 'alias exit=:' 'readonly _lc_v' > "$R279/alias-exit.sh"
printf '%s\n' 'r279_a() { :; }' 'R279_V=1' 'BASH_XTRACEFD=1' 'set -x' > "$R279/xtrace.sh"
tok 'a file that aliases exit has every name it defines recorded' \
'status 0
recorded $R279_V from alias-exit.sh
recorded r279_a from alias-exit.sh' "$(r279_loaded "$R279/alias-exit.sh")"
tok 'and so does one that points a trace at the child'"'"'s standard output' \
'status 0
recorded $R279_V from xtrace.sh
recorded r279_a from xtrace.sh' "$(r279_loaded "$R279/xtrace.sh")"
# Every command after the source is written with a backslash, which no alias
# expands, so what the one parsed line holds that the backslashes do not is
# its brace: `{` aliased reaches a group on a line after the source, and the
# child's dump is then the alias's. Measured: with the group split after the
# source, this row goes red, and no other does.
printf '%s\n' 'r279_a() { :; }' 'R279_V=1' 'shopt -s expand_aliases' "alias {='echo r279;'" > "$R279/alias-brace.sh"
tok 'and so does one that aliases the brace a group opens with' \
'status 0
recorded $R279_V from alias-brace.sh
recorded r279_a from alias-brace.sh' "$(r279_loaded "$R279/alias-brace.sh")"
# Round 4: what `declare -f` prints for a function that is exported, readonly
# or traced -- a line `declare -f<flags> <name>` after it -- and for one written
# with redirections, which close it on the `}` line. The first version of the
# reader refused both, and each is recorded now as the child before #279
# recorded it: the trailer is not part of the body, and the redirections are.
printf '%s\n' 'r279_a() { :; }' 'r279_b() { :; }' 'r279_c() { :; }' \
  'export -f r279_a' 'readonly -f r279_b' 'declare -ft r279_c' > "$R279/trailers.sh"
printf '%s\n' 'r279_a() { :; } > /dev/null' 'r279_b() { :; } 2>&1 < /dev/null' 'export -f r279_a' > "$R279/redirs.sh"
tok 'a file whose functions are exported, readonly and traced has each recorded' \
'status 0
recorded r279_a from trailers.sh
recorded r279_b from trailers.sh
recorded r279_c from trailers.sh' "$(r279_loaded "$R279/trailers.sh")"
tok 'and one whose functions carry redirections, the redirections in the body and the trailer not' \
    $'r279_a () \n{ \n    :\n} > /dev/null' \
    "$( ( declare -A LOADED_BODY=() LOADED_FROM=() LOADED_STATUS=()
          record_loaded "$R279/redirs.sh" "$R279/record" > /dev/null 2>&1
          printf '%s' "${LOADED_BODY[r279_a]}" ) )"
tok 'and the other of them is recorded too' \
'status 0
recorded r279_a from redirs.sh
recorded r279_b from redirs.sh' "$(r279_loaded "$R279/redirs.sh")"
# And a trailer-shaped line inside a body, before the function closes, is the
# body's: a heredoc holding `declare -fx <name>`. The reader skips a trailer
# only once its function is closed, and without that it dropped this line
# from the body (round 5 of the review of PR #330).
printf '%s\n' 'r279_h() { cat <<EOF' 'declare -fx r279_h' 'EOF' '}' > "$R279/heredoc-trailer.sh"
tok 'a trailer-shaped line in a heredoc, before its function closes, stays in the body' \
    $'r279_h () \n{ \n    cat <<EOF\ndeclare -fx r279_h\nEOF\n\n}' \
    "$( ( declare -A LOADED_BODY=() LOADED_FROM=() LOADED_STATUS=()
          record_loaded "$R279/heredoc-trailer.sh" "$R279/record" > /dev/null 2>&1
          printf '%s' "${LOADED_BODY[r279_h]}" ) )"
# Round 6: the variables the child starts with are `compgen -v`'s, as the
# child before #279's were. Taken from `declare -p`, they held OLDPWD, which
# bash starts declared and unset, so a file that changed directory had OLDPWD
# left out of its record and never compared. And a rule over `declare -p`'s
# text that dropped OLDPWD dropped SECONDS, RANDOM and COMP_WORDBREAKS too,
# which it prints with no value, so a file that assigned them had them
# recorded where that child did not. Each row is what that child records.
printf '%s\n' 'r279_a() { :; }' 'cd /' > "$R279/start-oldpwd.sh"
printf '%s\n' 'r279_a() { :; }' 'SECONDS=5' 'RANDOM=3' 'COMP_WORDBREAKS=x' 'FUNCNAME=x' \
  'false | true' > "$R279/start-dynamic.sh"
tok 'a file that changes directory has OLDPWD recorded, which bash starts declared and unset' \
'status 0
recorded $OLDPWD from start-oldpwd.sh
recorded r279_a from start-oldpwd.sh' "$(r279_loaded "$R279/start-oldpwd.sh")"
tok 'and one that assigns bash'"'"'s own SECONDS, RANDOM, COMP_WORDBREAKS, FUNCNAME and PIPESTATUS has none of them recorded' \
'status 0
recorded r279_a from start-dynamic.sh' "$(r279_loaded "$R279/start-dynamic.sh")"
# What a file can still do by mistake, and each is a FAIL row: leave the child
# no way to dump, as `declare` and `enable` both disabled do; the same under an
# EXIT trap that makes the child's status 0, which the missing marker gives
# away; skip every command of the child's with a DEBUG trap under extdebug;
# write text that is not in bash's shape into a dump from an EXIT trap; and run
# `exit` itself, which is the file ending the child, and is said as that (round
# 3, finding 10). A dump forged in bash's shape is not refused; that is the
# limit the driver names beside $LOADED_CHILD, and no row here pretends
# otherwise.
printf '%s\n' 'r279_a() { :; }' 'enable -n declare enable' > "$R279/no-dump.sh"
printf '%s\n' 'r279_a() { :; }' "trap 'exit 0' EXIT" 'enable -n declare enable' > "$R279/no-dump-trapped.sh"
printf '%s\n' 'r279_a() { :; }' 'shopt -s extdebug' "trap 'false' DEBUG" > "$R279/skips.sh"
printf '%s\n' 'r279_a() { :; }' "trap 'echo junk >&7' EXIT" > "$R279/writes-dump.sh"
printf '%s\n' 'r279_a() { :; }' 'exit 4' > "$R279/exits-4.sh"
tok 'a file that leaves the child no way to dump is a FAIL row, and leaves no record' \
"FAIL: the record of $R279/no-dump.sh was not made: the child that records it exited 127; nothing of it is compared at the foot
status 0" "$(r279_loaded "$R279/no-dump.sh")"
tok 'and so is the same under an EXIT trap that ends the child with 0' \
"FAIL: the record of $R279/no-dump-trapped.sh was not made: the dump of its variables is not whole, or holds text the child did not write there; nothing of it is compared at the foot
status 0" "$(r279_loaded "$R279/no-dump-trapped.sh")"
tok 'and one that skips the child'"'"'s commands with a DEBUG trap' \
"FAIL: the record of $R279/skips.sh was not made: the child that records it wrote no status for it: it ended before sourcing it returned, or could not write one; nothing of it is compared at the foot
status 0" "$(r279_loaded "$R279/skips.sh")"
tok 'and one that writes into a dump from an EXIT trap' \
"FAIL: the record of $R279/writes-dump.sh was not made: the dump of its variables is not whole, or holds text the child did not write there; nothing of it is compared at the foot
status 0" "$(r279_loaded "$R279/writes-dump.sh")"
tok 'and leaves no partial record beside the one it did not make' \
    'absent' "$([ -e "$R279/record.part" ] && echo present || echo absent)"
tok 'and one that runs exit 4 itself, said as the file ending the child' \
"FAIL: the record of $R279/exits-4.sh was not made: the child that records it wrote no status for it: it ended before sourcing it returned, or could not write one; nothing of it is compared at the foot
status 0" "$(r279_loaded "$R279/exits-4.sh")"
# RECORD_DUMP, DRIVEN WITH DUMPS WRITTEN BY HAND: each rule it reads a dump by,
# broken one at a time against a whole dump. Printed: its status, why, and each
# name it wrote.
r279_dump() {  # r279_dump <before> <names> <functions> <variables> -- record_dump's status and why, and each name it wrote
  printf '%s' "$1" > "$R279/d.before"
  printf '%s' "$2" > "$R279/d.names"
  printf '%s' "$3" > "$R279/d.functions"
  printf '%s' "$4" > "$R279/d.variables"
  : > "$R279/d"
  local why st k v
  why=$(record_dump "$R279/d")
  st=$?
  printf 'status %s%s\n' "$st" "${why:+: $why}"
  while IFS= read -r -d '' k && IFS= read -r -d '' v; do
    printf 'recorded %s as %s\n' "$k" "$v"
  done < "$R279/d"
}
R279_BEFORE=$'declare -f r279_pre\ne:\nR279_PRE\ne:\n'
R279_NAMES=$'declare -f r279_a\ndeclare -f r279_pre\n'
R279_FNS=$'r279_a () \n{ \n    :\n}\nr279_pre () \n{ \n    :\n}\n'
R279_VARS=$'declare -A R279_EMPTY\ndeclare -- BASH_R279="1"\ndeclare -- R279_PRE="1"\ndeclare -r R279_V="1"\ndeclare -- _="x"\ne:\n'
tok 'a whole dump is recorded, less the names the child started with, _, BASH_* and a variable with no value' \
'status 0
recorded r279_a as r279_a () 
{ 
    :
}
recorded $R279_V as R279_V="1"' "$(r279_dump "$R279_BEFORE" "$R279_NAMES" "$R279_FNS" "$R279_VARS")"
tok 'starting names that do not end in e: are refused' \
    'status 1: starting names' "$(r279_dump $'declare -f r279_pre\ne:\nR279_PRE\n' "$R279_NAMES" "$R279_FNS" "$R279_VARS")"
tok 'and so are starting names with no listing of variables' \
    'status 1: starting names' "$(r279_dump $'declare -f r279_pre\ne:\n' "$R279_NAMES" "$R279_FNS" "$R279_VARS")"
tok 'and a starting function name that is not a declaration' \
    'status 1: starting names' "$(r279_dump $'+ declare -F\ne:\nR279_PRE\ne:\n' "$R279_NAMES" "$R279_FNS" "$R279_VARS")"
tok 'and a starting variable that is not a name, as a declaration is not' \
    'status 1: starting names' "$(r279_dump $'declare -f r279_pre\ne:\ndeclare -- R279_PRE="1"\ne:\n' "$R279_NAMES" "$R279_FNS" "$R279_VARS")"
tok 'a function name that is not a declaration is refused' \
    'status 1: function names' "$(r279_dump "$R279_BEFORE" $'declare -f r279_a\nr279_pre\n' "$R279_FNS" "$R279_VARS")"
tok 'text before the first function is refused' \
    'status 1: functions' "$(r279_dump "$R279_BEFORE" "$R279_NAMES" $'+ printf %s 0\n'"$R279_FNS" "$R279_VARS")"
tok 'and a function that does not end on }, as one cut at a heredoc line that is the next header is' \
    'status 1: functions' "$(r279_dump "$R279_BEFORE" "$R279_NAMES" $'r279_a () \n{ \n    cat <<EOF\nr279_pre () \nEOF\n}\nr279_pre () \n{ \n    :\n}\n' "$R279_VARS")"
tok 'and a named function with no header' \
    'status 1: functions' "$(r279_dump "$R279_BEFORE" "$R279_NAMES" $'r279_a () \n{ \n    :\n}\n' "$R279_VARS")"
tok 'a trailer naming a function other than the one it follows is refused' \
    'status 1: functions' "$(r279_dump "$R279_BEFORE" "$R279_NAMES" $'r279_a () \n{ \n    :\n}\ndeclare -fx r279_pre\nr279_pre () \n{ \n    :\n}\n' "$R279_VARS")"
tok 'variables that do not end in e: are refused' \
    'status 1: variables' "$(r279_dump "$R279_BEFORE" "$R279_NAMES" "$R279_FNS" $'declare -r R279_V="1"\n')"
tok 'and a variable line that is not a declaration' \
    'status 1: variables' "$(r279_dump "$R279_BEFORE" "$R279_NAMES" "$R279_FNS" $'declare -r R279_V="1"\n+ printf e:\ne:\n')"
# And a dump it refuses leaves the record it was to replace as it found it,
# which neither caller shows, since both empty it first (round 4, finding 17).
printf '%s' "$R279_BEFORE" > "$R279/k.before"
printf '%s' "$R279_NAMES" > "$R279/k.names"
printf '%s' "$R279_FNS" > "$R279/k.functions"
printf '%s' $'declare -r R279_V="1"\n' > "$R279/k.variables"
printf '%s' 'kept' > "$R279/k"
tok 'a refused dump leaves the record it was to replace as it found it' \
    'status 1: kept' "$(record_dump "$R279/k" > /dev/null; echo "status $?: $(< "$R279/k")")"
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
# A verdict row that failed, which writes the label its failure carries and
# not the one derived: the run is red on that row, and this one reads its tags
# alone (round 6 of the review of PR #330). Under another tag it is red.
sed '$d' "$R279/tail-ledger" > "$R279/tail-failed"
printf '%s\t%s\t%s\t%s\n' GH-204.5 static FAIL 'the not-found record was moved during the run' >> "$R279/tail-failed"
sed '$d' "$R279/tail-ledger" > "$R279/tail-failed-tag"
printf '%s\t%s\t%s\t%s\n' GH-204.1 static FAIL 'the not-found record was moved during the run' >> "$R279/tail-failed-tag"
tok 'a verdict row that failed, under its own tag and the label its failure writes, reads as matching' \
    '' "$(verdict_tail_read "$R279/driver" "$R279/tail-failed")"
tok 'and under another tag it is red' \
"derived:
$R279_TAIL
the ledger ends:
$(sed '$d' <<< "$R279_TAIL")
$(printf '%s\t%s' GH-204.1 'the not-found record was moved during the run')" "$(verdict_tail_read "$R279/driver" "$R279/tail-failed-tag")"
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

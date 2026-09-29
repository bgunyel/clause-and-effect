#!/bin/bash
# THE ISSUE FILE OF #193: `mutate-hooks.sh --list` applies every row's edit,
# and every row's edit does what the row declares.
#
# Why: `--list` counted the runs a whole-registry pass costs off the DECLARED
# outcome, so a row declared `caught` whose anchor a rename had moved was
# counted as a run and reported `did-not-apply` only after a whole pass, which
# is hours. Nothing but a run found a rotted anchor. #193 made `--list` apply
# each edit, through `row_apply`, the function pass two edits the copy with, so
# the count is what a pass runs and a rotted anchor is marked on its row by a
# command that runs no suite. Measured on this branch under load 27: three
# runs of `--list` took 3.1 to 3.9 s of wall clock and 0.83 to 0.91 s of CPU.
#
# WHAT IS CHECKED, in three parts:
#   - The registry. Every row's edit, applied here with `sed --sandbox` to the
#     file beside the harness, changes that file when the row declares `caught`
#     or `survived`, and leaves it as it was when it declares `did-not-apply`.
#     The program is this file's own: it calls neither `--list` nor
#     `row_apply`, which are what is under test, and its expectation is the
#     declared column, read off the registry. It is driven first with fixture
#     rows, one of each way a row can be wrong, so that it is shown able to go
#     red before it is asked about the real rows.
#   - `--list` itself, against a copy of the harness whose registry is fixture
#     rows and whose files are fixture files: the EDIT column, the line marking
#     a row whose edit does not do what it declares and a fault, the run count,
#     and the exit status, each against a literal.
#   - The hedge. The header's prose and `--list`'s run-count line no longer say
#     `at most`, and the header points at what replaced it.
#
# WHAT THE #148 RUN-COUNT CHECK NOW MEANS is written beside it, in the unsplit
# file: it compares the count this suite reads off the declarations with the
# count `--list` measures, and this file's registry check is what makes the two
# the same count.
#
# WHAT IS NOT HERE, named. `--list` asking whether a target is writable of the
# file beside the harness rather than of the copy rests on the copy being the
# running user's, which a fixture cannot vary: making a file owned by someone
# else needs another user. The header and `row_apply` name that assumption. And
# `--list` exiting non-zero when .claude/hooks/ moved under it is pinned on its
# code and not driven, since nothing `--list` is given can make it write there;
# that was shown by hand, by making the edit land in place. The sandbox refusing
# a `w`, `r` or `e` is #272's, in its own issue file.
section "=== issue #193: --list applies every row's edit, and every edit does what its row declares ==="

requirement GH-193 <<'REQ'
- text: `bash .claude/hooks/mutate-hooks.sh --list` applies every registry row's
  edit, through `row_apply`, the function pass two edits the copy with, and
  prints beside each row's declared outcome whether its edit applies, leaves its
  file unchanged, or is a fault. A row whose edit does not do what it declares,
  and a fault, are each marked on a line under the row. A fault is a row pass
  one refuses, a target that is not a writable regular file, or a `sed` that
  fails; it is not counted. The run count is the baseline plus every row whose
  edit applies, and neither it nor the harness's header says `at most`.
  `--list` sums `.claude/hooks/` before and after and exits non-zero if it
  moved. And every row of the registry, its edit applied with `sed --sandbox`
  to the file beside the harness, changes that file when it declares `caught`
  or `survived`, and leaves it as it was when it declares `did-not-apply`.
- from: #193
- kind: doc-claim
- status: active
- direction: static: it applies the registry's edits with its own program, and
  drives `--list` against a copy of the harness holding a fixture registry
- note: `--list` asks whether a target is writable of the file beside the
  harness, and pass two of the copy; `cp -a` keeps the mode and makes the copy
  the running user's, so the two agree whenever that user owns the file, and
  no fixture can vary that. The #148 run-count check compares the count read
  off the declarations with the count `--list` measures; with this entry green
  they are one count, which is what that check establishes since #193.
REQ
shape_pin 'GH-193:static'

# THE PROGRAM: a line for each row whose edit does not do what it declares, and
# nothing for a row that does. `fails` is a sed that exits non-zero, a sandbox
# refusal among the ways, and is never what a row declares.
R193_EDITED="$FIXTURES/r193-edited"
r193_mismatches() {  # r193_mismatches <dir> <rows> -- each row whose edit does not do what it declares
  local id file edit reqs want got
  while IFS='%' read -r id file edit reqs want; do
    [ -n "$id" ] || continue
    if ! sed --sandbox -e "$edit" -- "$1/$file" > "$R193_EDITED" 2>/dev/null; then
      got=fails
    elif cmp -s -- "$1/$file" "$R193_EDITED"; then
      got=unchanged
    else
      got=applies
    fi
    case "$want:$got" in
      caught:applies|survived:applies|did-not-apply:unchanged) ;;
      *) printf '%s declares %s and its edit %s\n' "$id" "$want" "$got" ;;
    esac
  done <<< "$2"
}

req GH-193
R193_FIX="$FIXTURES/r193"
mkdir -p "$R193_FIX"
printf 'alpha\n' > "$R193_FIX/hook.sh"
# One row of each kind: two that do what they declare, one of each outcome the
# issue named as wrong -- declared `caught` with an anchor that matches nothing,
# declared `did-not-apply` with an edit that applies -- a `sed` that does not
# parse, and a `w` the program's own sandbox has to refuse.
R193_FIX_ROWS="fine%hook.sh%s/alpha/beta/%GH-1%caught
rotted%hook.sh%s/nothing-matches-this/x/%GH-1%caught
stale-selftest%hook.sh%s/alpha/gamma/%GH-1%did-not-apply
kept%hook.sh%s/nothing-matches-this/x/%GH-1%did-not-apply
survivor%hook.sh%s/alpha/delta/%GH-1%survived
broken%hook.sh%s/unterminated%GH-1%caught
writes%hook.sh%s/alpha/beta/w $FIXTURES/r193-written%GH-1%caught"
tok 'the program reports a row whose anchor matches nothing, one declared did-not-apply whose edit applies, and a sed that fails, and no row that does what it declares' \
    'rotted declares caught and its edit unchanged
stale-selftest declares did-not-apply and its edit applies
broken declares caught and its edit fails
writes declares caught and its edit fails' \
    "$(r193_mismatches "$R193_FIX" "$R193_FIX_ROWS")"
tok 'and its sandbox wrote nothing for the row carrying a w' \
    'absent' "$([ -e "$FIXTURES/r193-written" ] && echo present || echo absent)"

# THE REGISTRY, read by the #107 section in the unsplit file, which is sourced
# before any issue file and stops the run if it reads no row. Asked again here
# rather than trusted, because an empty list reports no mismatch and reads as
# every row agreeing.
req GH-193
if [ -z "$MUT_ROWS" ]; then
  fail static 'no registry row was read, so no row was asked whether its edit does what it declares'
else
  tok "every registered mutation's edit, applied to the file beside the harness, does what its row declares" \
      '' "$(r193_mismatches "$SUITE_DIR" "$MUT_ROWS")"
fi

# `--list` ITSELF, against a copy of the harness whose registry is these rows.
# One row of each EDIT column value and each fault: an edit that applies, one
# that matches nothing declared `caught`, a self-test declared `did-not-apply`
# whose edit applies, one that does not, a `sed` that does not parse, a target
# that is not there, a target that is a symlink, and a target pass one refuses
# for climbing out of the directory. The check-hooks.sh beside it is empty: the
# harness only needs one there to be readable, and `--list` runs none of it.
req GH-193
R193_HARNESS="$FIXTURES/r193-harness"
R193_HARNESS_ROWS='applies-row%hook.sh%s/alpha/beta/%GH-1%caught
rotted-row%hook.sh%s/nothing-matches-this/x/%GH-1%caught
selftest-applies%hook.sh%s/alpha/gamma/%GH-1%did-not-apply
selftest-unchanged%hook.sh%s/nothing-matches-this/x/%GH-1%did-not-apply
broken-sed%hook.sh%s/unterminated%GH-1%caught
missing-target%not-there.sh%s/alpha/beta/%GH-1%caught
symlink-target%link.sh%s/alpha/beta/%GH-1%caught
refused-row%../hook.sh%s/alpha/beta/%GH-1%caught'
harness_fixture "$R193_HARNESS" "$R193_HARNESS_ROWS"
printf 'alpha\n' > "$R193_HARNESS/hook.sh"
ln -s hook.sh "$R193_HARNESS/link.sh"
: > "$R193_HARNESS/check-hooks.sh"
printf '# A fixture\n\n## Boundary issues\n\n### GH-1\n- status: active\n' > "$R193_HARNESS/requirements.md"
tok 'the copy of the harness registers the fixture rows and nothing else' \
    "$R193_HARNESS_ROWS" "$(harness_rows "$R193_HARNESS/mutate-hooks.sh")"
R193_LIST=$(bash "$R193_HARNESS/mutate-hooks.sh" --list 2>&1)
R193_STATUS=$?
tok '--list exits 0 over a registry with faults and rows that do not do what they declare, which is not a failure of its own' \
    '0' "$R193_STATUS"
# The row lines are the ones before the first blank line, after the header,
# that are not a mark; the EDIT column is the fourth field.
tok 'the EDIT column says, per row, whether the edit applies, leaves its file as it was, or is a fault' \
    'applies-row:applies rotted-row:unchanged selftest-applies:applies selftest-unchanged:unchanged broken-sed:fault missing-target:fault symlink-target:fault refused-row:fault ' \
    "$(printf '%s\n' "$R193_LIST" | awk '/^$/ { exit } NR > 1 && !/^    \^/ { printf "%s:%s ", $1, $4 }')"
# The marks, in row order. sed's own complaint is cut off after the harness's
# words, because its wording and its character position are sed's and not what
# this asks.
tok 'a row whose edit does not do what it declares is marked, and so is each fault, with its reason' \
    'declared caught, and the edit leaves hook.sh as it was
declared did-not-apply, and the edit changes hook.sh
fault: the sed expression failed:
fault: not-there.sh is not a writable regular file
fault: link.sh is not a writable regular file
fault: the target ../hook.sh is not a path inside the hooks directory' \
    "$(printf '%s\n' "$R193_LIST" | awk 'sub(/^    \^ /, "") { sub(/failed: .*/, "failed:"); print }')"
holds 'and the summary counts both' "$R193_LIST" \
  '2 rows whose edit does not do what the row declares, and 4 faults; each is marked on its own line above'
# The baseline, the row that applies, and the self-test whose edit applies
# though it declares otherwise: pass two runs the suite on it, whatever it
# declares, so it is counted. Counting off the declarations instead gives six.
tok 'the run count is the baseline plus the rows whose edit applies' \
    '3' "$(printf '%s\n' "$R193_LIST" | awk '/runs of check-hooks.sh for a whole-registry pass/ { print $1; exit }')"
lacks 'and is not hedged' \
    "$(printf '%s\n' "$R193_LIST" | grep 'runs of check-hooks.sh for a whole-registry pass')" 'at most'
tok 'and the fixture file the rows edit is as it was' 'alpha' "$(cat "$R193_HARNESS/hook.sh")"

# THE SUM, pinned on the code: nothing `--list` is given makes it write under
# the directory, so the comparison is read rather than driven.
req GH-193
R193_MUT="$SUITE_DIR/mutate-hooks.sh"
armed '--list sums the hooks directory before it applies anything' \
      "$R193_MUT" 'LIST_SUM_BEFORE=$(tree_sum "$SRC") || {'
armed 'and exits non-zero when the sum after differs, or is empty' \
      "$R193_MUT" 'if [ -z "$LIST_SUM_AFTER" ] || [ "$LIST_SUM_BEFORE" != "$LIST_SUM_AFTER" ]; then'
armed 'and both halves apply an edit through the one function' \
      "$R193_MUT" 'if ! FAULT=$(row_apply "$SRC/$file" "$edit" "$file" 2>&1 >"$WORK_ROOT/mutated"); then'
armed 'pass two included' \
      "$R193_MUT" 'if ! row_apply "$TARGET" "$EDIT" "$FILE in the working copy" > "$WORK_ROOT/mutated" 2>"$WORK_ROOT/sed.err"; then'

# THE HEDGE IN THE HEADER, asked of its prose through prose_reflow, the reader a
# pin on prose takes (#192), and of the header alone: the region ends at
# `set -u`, and its last paragraph is asked for so that a region cut short is
# red rather than an absence. Not `prose` with `unarmed`, as #192's rule words
# it, because `prose` reads the whole file, and the code below `set -u` says
# `at most` in the comment recording why the output line no longer does.
req GH-193
R193_HEADER=$(sed -n '1,/^set -u$/p' "$R193_MUT" | prose_reflow)
holds 'the header is read to its last paragraph' "$R193_HEADER" \
  'the documents it is judged against stay this repository'
lacks 'the header no longer hedges the run count' "$R193_HEADER" 'at most'
holds 'and says what replaced the hedge' "$R193_HEADER" \
  "IT IS COUNTED BY APPLYING EVERY ROW'S EDIT, and so it is the count a pass runs, under the one assumption named below (#193)."
holds 'and what --list does, on its usage line' "$R193_HEADER" \
  "--list the registry, each row's edit applied sandboxed and never in place, and no suite run"

sourced_to_end

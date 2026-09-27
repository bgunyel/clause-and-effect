#!/bin/bash
# THE ISSUE FILE OF #224: `fail` marks which lines of the log are a failing
# row's, by indenting every line of its message after the first.
#
# Why: the `check-hooks` job summary shows a failing row with its detail, and
# the log did not say which lines those were, so the summary guessed -- the
# lines up to the next row, heading or blank line. The guess took a library's
# stderr, printed at column 0 before the row it belongs to, as the detail of
# the failing row above it, which run 35836366963's log can produce; and it
# cut a hook's stderr short at its first blank line or line opening `---`.
# `fail` embeds that stderr verbatim, so a line of it started wherever the
# hook started it, column 0 included. Split off by the triage of the issue
# that bounds the summary's size, which #224's own text names.
#
# The indent is seven spaces, the width of the `  FAIL ` a row opens with, so
# a continuation line stands under the message's first character. It is added
# to every line after the first whatever the line starts with, a blank line
# included, so the hook's stderr is byte-exact once one indent is removed:
# that is what the summary shows. .github/scripts/check_hooks_ci.py spells the
# same seven spaces as DETAIL_INDENT, and tests/test_check_hooks_ci.py runs
# this library's own `fail` into that parser, which is what keeps the two
# spellings one; this file asks the bash half alone.
#
# WHAT IS DRIVEN is `fail` itself, inside $( ) where its row is not recorded
# and its FAILED does not reach this shell, so a `fail` printed here is this
# file's evidence and not a red row, as in #219's file. The ledger is asked in
# a child bash that sources the library, because `record` writes only from the
# shell whose $$ it is, and a child bash is one.

section "=== issue #224: fail marks the lines of its message after the first ==="

requirement GH-224.1 <<'REQ'
- text: `fail` prints its message's first line after `  FAIL `, as before,
  and every line after the first with seven spaces in front of it, whatever
  the line already starts with. A line at column 0 gets the seven spaces, a
  line that opens with spaces gets them added to its own, and a blank line
  becomes the seven spaces alone. So a hook's stderr that `fail` embeds is
  byte-exact once seven spaces are taken off each line after the first, and
  no line of a failing row's message stands at column 0.
- from: #224
- kind: defect-permitting
- status: active
- direction: static: a property of the suite's helpers
- note: The seven spaces are also .github/scripts/check_hooks_ci.py's
  DETAIL_INDENT, which takes a failing row's detail by them for the job
  summary. tests/test_check_hooks_ci.py runs this `fail` into that parser;
  this entry is the bash half. A stray line that opens with seven spaces and
  that `fail` did not print is read there as detail of the row above it --
  the open case #224 records rather than fixes.
REQ
requirement GH-224.2 <<'REQ'
- text: The ledger line `fail` records for a message of several lines is its
  first line only, as it was before #224: the indent goes on what `fail`
  prints and never on what it records, so the ledger `mutate-hooks.sh` reads
  is byte-identical for every `fail` call.
- from: #224
- kind: defect-permitting
- status: active
- direction: static: a property of the suite's helpers
REQ
shape_pin 'GH-224.1:static GH-224.2:static'

# What `fail` prints opens with two blanks, held in a variable so that no
# quoted string here opens with a result's prefix: #104's audit at the foot of
# the suite reads every such string as a result printed around pass and fail.
R224_ROW='  '
# The indent, written out: seven spaces. Not read from the library, because
# what is under test is whether the library prints these.
R224_IND='       '
# A hook's stderr holding every line the old guess stopped at or took in: one
# at column 0, a blank one, one opening `---` and one opening `===`, and one
# the hook indented itself.
R224_STDERR='first line
column zero

--- a/diff
=== not a heading
   three spaces'

req GH-224.1
tok 'a fail embedding a stderr of several lines prints every line after the first with the indent in front, a column-0 line, a blank one and a --- one included' \
"${R224_ROW}FAIL r224 driven check
${R224_IND}         stderr |first line
${R224_IND}column zero
${R224_IND}
${R224_IND}--- a/diff
${R224_IND}=== not a heading
${R224_IND}   three spaces|" \
    "$(fail static '%s\n         stderr |%s|' 'r224 driven check' "$R224_STDERR")"
tok 'a fail of one line prints that line alone, as before' \
    "${R224_ROW}FAIL r224 one line" \
    "$(fail static 'r224 %s' 'one line')"
tok "and a message's own blank lines, one after another and at its end, are each the indent alone" \
"${R224_ROW}FAIL r224 blanks
${R224_IND}
${R224_IND}
${R224_IND}after two
${R224_IND}" \
    "$(fail static 'r224 blanks\n\n\nafter two\n')"

# The ledger, from a child bash with a ledger of its own. What it records for
# the message above is its first line, which is what it recorded before #224:
# measured, not assumed, against the library as #224 found it -- see the pull
# request -- and pinned here as that literal.
req GH-224.2
R224_LEDGER="$FIXTURES/r224-ledger"
: > "$R224_LEDGER"
LEDGER="$R224_LEDGER" REQ=GH-0 bash -c 'source "$1"; fail static "%s\n         stderr |%s|" "r224 driven check" "$2" > /dev/null' \
  bash "$SUITE_DIR/checks/library.sh" "$R224_STDERR"
# Read with an `x` after it, so the line's own newline is compared too and
# not stripped by the $( ).
R224_TAB=$'\t'
tok 'the ledger records only the first line of a fail of several lines, byte for byte as before #224' \
    "GH-0${R224_TAB}static${R224_TAB}FAIL${R224_TAB}r224 driven check
x" "$(cat "$R224_LEDGER"; printf x)"

sourced_to_end

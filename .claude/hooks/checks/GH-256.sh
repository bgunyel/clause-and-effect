#!/bin/bash
# THE ISSUE FILE OF #256: an empty file is a read file, and an empty string is
# not.
#
# Why: #219 made `unarmed` and `prose_count` decide by grep's exit status, 1
# passing, and grep exits 1 on a zero-byte file too. `lacks` refuses an empty
# string. rev-agent-219 filed the two as helpers that disagree about empty
# input, from round 1 of the review of PR #254, and withdrew that framing after
# dev-agent-219's answer there: the helpers apply one rule -- an absence counts
# only in something that was read -- to different evidence. `lacks` is handed
# text, where a failed read and an empty file both arrive as "", so empty is
# all it can refuse on. The other two are handed a path, where grep's status
# already tells an unread file (2) from a read one with nothing in it (1). A
# truncated file is a presence question, for `armed`, `written` and `holds`.
# Triage took option 2 of the issue: record the choice beside the helpers and
# pin it as verdicts, and add no `[ -s ]`, which would refuse a true absence in
# a file that is legitimately empty.
#
# WHAT IS DRIVEN is each helper, run inside $( ) against a zero-byte file this
# file makes, and `lacks` against an empty string -- the way #219's issue file
# drives them, asserting the whole of what each printed as a literal. A helper
# that fails inside $( ) records nothing and sets no FAILED here, so the `lacks`
# row's FAIL is this file's evidence and not a red row.
#
# NO MUTATION ROW, BECAUSE NONE IS POSSIBLE, as in #187's issue file:
# mutate-hooks.sh refuses any row whose target is under checks/, because the
# suite it runs is this repository's and a mutation to the copy's library would
# be read and never executed. The evidence is a recorded run instead.
#
# MEASURED, 2026-09-29, by hand: this file alone, sourced in a fresh bash after
# a copy of library.sh with one edit applied to the copy, the driver's
# bookkeeping stubbed, so no whole-suite run and no edit to this checkout.
#
#   the edit to the copy                                   red row
#   none                                                   none of 3
#   `[ -s "$2" ]` after status 1 in `unarmed`              GH-256.1, unarmed
#   `[ -s "$2" ] || fail; return` in front of its grep     GH-256.1, unarmed
#   `[ -s "$1" ]` after status 0|1 in `prose_count`        GH-256.1, prose_count
#   status 1 left to the unread arm of `prose_count`       GH-256.1, prose_count
#   `lacks` with its empty-string arm made `if false`      GH-256.2
#   `nothing was read, so ` deleted from `lacks`'s message GH-256.2

section "=== issue #256: an empty file is a read file, and an empty string is not ==="

requirement GH-256.1 <<'REQ'
- text: `unarmed <label> <file> <literal>` passes on a zero-byte file, whose
  grep exits 1, and `prose_count <file> <literal>` prints `0` for one. An
  empty file was read and holds nothing, so the absence is a true one.
- from: #256
- kind: defect-refusing
- status: active
- direction: static: a property of the suite's helpers
- note: A `[ -s ]` question would refuse that true absence. A file a failed
  write emptied is a presence question, answered by an `armed` or `written`
  over the same file, and not by these two.
REQ
requirement GH-256.2 <<'REQ'
- text: `lacks <label> <text> <literal>` fails on an empty string, saying
  nothing was read, because a failed or deleted read and an empty file are
  indistinguishable once they are text.
- from: #256
- kind: defect-permitting
- status: active
- direction: static: a property of the suite's helpers
REQ
shape_pin 'GH-256.1:static GH-256.2:static'

# What a helper prints opens with two blanks, held in a variable so that no
# quoted string here opens with a result's prefix: #104's audit at the foot of
# the suite reads every such string as a result printed around pass and fail.
R256_INDENT='  '
# THE FIXTURE, a regular file of zero bytes. Anything else here -- no file, a
# directory, a byte in it -- and the rows below would be about something else.
R256_EMPTY="$FIXTURES/r256-empty.txt"
rm -rf "$R256_EMPTY"
: > "$R256_EMPTY"
[ -f "$R256_EMPTY" ] && [ "$(wc -c < "$R256_EMPTY")" = 0 ] || {
  echo "the #256 zero-byte fixture was not created; the checks against it prove nothing" >&2
  exit 1
}

req GH-256.1
tok 'unarmed aimed at a zero-byte file passes: it was read, and the literal is not in it' \
    "${R256_INDENT}ok   armed r256 driven check" \
    "$(unarmed 'r256 driven check' "$R256_EMPTY" 'R256_LITERAL')"
tok 'prose_count on a zero-byte file prints the count 0, and nothing that names grep' \
    '0' "$(prose_count "$R256_EMPTY" 'R256_LITERAL')"

req GH-256.2
tok 'lacks handed an empty string fails, and says nothing was read' \
"${R256_INDENT}FAIL r256 driven check
                nothing was read, so the absence of |R256_LITERAL| is evidence of nothing" \
    "$(lacks 'r256 driven check' '' 'R256_LITERAL')"

sourced_to_end

#!/bin/bash
# THE ISSUE FILE OF #219: an absence helper fails when grep could not read its
# file, and a directory is such a file.
#
# Why: `unarmed` pinned an absence behind a `[ ! -r ]` guard, and `[ -r ]` is
# true of a directory. grep exits 2 on one, `Is a directory`, and the
# `elif grep; then fail; else pass` that followed read every status but 0 as
# "absent", so the check printed ok having read nothing. `prose_count` hid
# grep's stderr and printed its count, and on a directory grep prints `0` and
# exits 2, so every `tok ... '0' "$(prose_count ...)"` passed the same way.
# Both are the permitting direction, and both were silent. Filed by
# rev-agent-204 from the review of PR #216; measured at dbb1141 and again at
# 2c65f4d by #219's triage.
#
# WHAT IS DRIVEN is each helper, run inside $( ) against fixtures this file
# makes: a directory, a file that is not there, and a readable file that says
# the literal on two lines. Inside $( ) a helper's `pass` or `fail` is not
# recorded and its FAILED does not reach this shell, so a helper that fails
# here, as it should, is this file's evidence and not a red row. What each row
# asserts is the whole of what the helper printed, as a literal.
#
# UNDER THE SUITE'S GREP. In a Claude Code session the interactive shell's
# `grep` is a function running a bundled ugrep, which searches a directory
# recursively instead of exiting 2, so a probe typed there says the unfixed
# helpers behave otherwise than they do. This file runs in the suite's child
# bash, where grep is the one on PATH. A grep that recursed would turn the
# directory rows red, not green: none of them passes on anything but a status
# other than 0 and 1.

section "=== issue #219: an absence helper fails when grep could not read its file ==="

requirement GH-219.1 <<'REQ'
- text: `unarmed <label> <file> <literal>` branches on the exit status of the
  grep that reads the file: 0 fails, because the literal is there; 1 passes;
  any other status fails, and the failure line names the status and the file.
  So `unarmed` aimed at a directory, which `[ -r ]` calls readable and on
  which grep exits 2, fails, and so does one aimed at a file that is not
  there. A readable file that lacks the literal still passes, and one that
  says it still fails.
- from: #219
- kind: defect-permitting
- status: active
- direction: static: a property of the suite's helpers
- note: The branch does not rest on a readability test. The `[ ! -r ]` arm
  that stood in front of it was the whole of the old fix for a missing file,
  and it is gone, so no arm in front of the grep can pass a file the grep did
  not read.
REQ
requirement GH-219.2 <<'REQ'
- text: `prose_count <file> <literal>` prints grep's count only when grep
  exited 0 or 1, 1 being a count of zero; on any other status it prints
  `unread: grep exited <status> on <file>`, which no count equals. So a
  `tok <label> '0' "$(prose_count <directory> <literal>)"` check fails, and a
  readable file still yields `0` for no matching line and `n` for n.
- from: #219
- kind: defect-permitting
- status: active
- direction: static: a property of the suite's helpers
REQ
shape_pin 'GH-219.1:static GH-219.2:static'

# What a helper prints opens with two blanks, held in a variable so that no
# quoted string here opens with a result's prefix: #104's audit at the foot of
# the suite reads every such string as a result printed around pass and fail.
R219_INDENT='  '
# THE FIXTURES. The directory holds a file that says the literal, so a grep that
# recursed into it would find it; none of the rows below passes on that either.
R219_DIR="$FIXTURES/r219-dir"
R219_FILE="$FIXTURES/r219-file.txt"
R219_GONE="$FIXTURES/r219-no-such-file"
mkdir -p "$R219_DIR"
printf '%s\n' 'R219_LITERAL' > "$R219_DIR/inside.txt"
printf '%s\n' 'R219_LITERAL once' 'nothing here' 'R219_LITERAL twice' > "$R219_FILE"
rm -f "$R219_GONE"
[ -d "$R219_DIR" ] && [ -r "$R219_FILE" ] && [ ! -e "$R219_GONE" ] || {
  echo "the #219 fixtures were not created; the checks against them prove nothing" >&2
  exit 1
}

req GH-219.1
tok 'unarmed aimed at a directory fails, and says grep exited 2 on that directory' \
"${R219_INDENT}FAIL r219 driven check
         grep exited 2 on $R219_DIR, so it was not read and the absence of |R219_LITERAL| is evidence of nothing" \
    "$(unarmed 'r219 driven check' "$R219_DIR" 'R219_LITERAL')"
tok 'and aimed at a file that is not there, it fails the same way' \
"${R219_INDENT}FAIL r219 driven check
         grep exited 2 on $R219_GONE, so it was not read and the absence of |R219_LITERAL| is evidence of nothing" \
    "$(unarmed 'r219 driven check' "$R219_GONE" 'R219_LITERAL')"
tok 'aimed at a readable file that lacks the literal, it passes' \
    "${R219_INDENT}ok   armed r219 driven check" \
    "$(unarmed 'r219 driven check' "$R219_FILE" 'R219_ABSENT')"
tok 'and aimed at one that says it, it fails' \
"${R219_INDENT}FAIL r219 driven check
         $R219_FILE must not contain |R219_LITERAL|" \
    "$(unarmed 'r219 driven check' "$R219_FILE" 'R219_LITERAL')"

req GH-219.2
tok 'prose_count on a directory prints no count, and says grep exited 2 on it' \
    "unread: grep exited 2 on $R219_DIR" "$(prose_count "$R219_DIR" 'R219_LITERAL')"
tok "so a check that the directory says it nowhere, tok '0' over prose_count, fails" \
"${R219_INDENT}FAIL r219 driven check
         want |0|
         got  |unread: grep exited 2 on $R219_DIR|" \
    "$(tok 'r219 driven check' '0' "$(prose_count "$R219_DIR" 'R219_ABSENT')")"
tok 'and on a file that is not there, it says the same and prints no count' \
    "unread: grep exited 2 on $R219_GONE" "$(prose_count "$R219_GONE" 'R219_LITERAL')"
tok 'on a readable file with no matching line, grep exits 1 and the count is 0' \
    '0' "$(prose_count "$R219_FILE" 'R219_ABSENT')"
tok 'and with two, the count is 2' \
    '2' "$(prose_count "$R219_FILE" 'R219_LITERAL')"

sourced_to_end

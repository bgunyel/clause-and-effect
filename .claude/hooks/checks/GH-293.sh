#!/bin/bash
# THE ISSUE FILE OF #293: `fail` costs time linear in its message.
#
# Why: #224 made `fail` indent every line of its message after the first, and
# wrote it as one substitution, `${line//$'\n'/$'\n'$indent}`. Under a UTF-8
# locale bash's substitution grows with the square of the message: one `fail`
# over a 10,000-line message took 7.19 s in rev-agent-224's measurement (569
# KB) and 6.8 s in dev-agent's (580 KB), against 0.19 s and 0.06 s before
# #224, and another reviewer measured 78 s at 2 MB. A failing row only prints
# a message that large when it embeds a large captured output, and the
# largest in three full mutant runs was 53 lines, so it was latent. It is the
# refusing direction: a slow run reads `did-not-complete` under
# mutate-hooks.sh and not `caught`, and pushes the `check-hooks` job toward
# its timeout. Found in round 2 of the review of PR #285 and fixed there,
# before #224 merged.
#
# WHAT IS DRIVEN is the library's own `fail`, in a child bash that sources it
# with an empty LEDGER and times the one `fail` call, and nothing else, under
# C.UTF-8, the locale all three measurements above were taken in. The
# messages are written to fixtures once, so the time is `fail`'s and not the
# loop that made it or the file read.
#
# A RATIO OF CPU TIMES, in the form of #96's `scales_linearly`: four times the
# lines may cost at most eight times the time, each size's fastest of three,
# the smaller floored at 10 ms. The time is the child's user and system time
# over the `fail` call, read with bash's `time` and TIMEFORMAT, and not the
# wall clock, because the wall clock on a loaded machine is what made two
# earlier forms of this row unreliable:
#
#   - `under_a_second` over 10,000 lines measured 266 ms and then 521 ms in two
#     full runs, the second at a load average of 36. That is the shape of the
#     row that flaked in round 1 of the review of PR #285, `cs_normalise over
#     one 512 KB line`.
#   - The same ratio as below over $EPOCHREALTIME, in round 3 of that review,
#     at a load average of about 38 on 6 cores: rev-agent-224 drove this
#     file's code and measured the linear `fail` failing in 1 run of 27, with
#     ratios from 3.0 to 7.2, and the plain `printf` of the `fail` before #224,
#     also linear, failing in 5 of 30, one of them 27 ms and 251 ms, 9.3
#     times. Widening the step to eight times was measured too, by
#     dev-agent at a load average of 25: 8.0 to 21.2 over eight runs, each
#     outlier a small run whose fastest of three caught a quiet moment. The
#     noisy term is the wall clock, not the step.
#
# Measured by CPU time at a load average of 26, fastest of three at each size,
# when the linear `fail` was the second form described below: that form 4.2
# to 4.4 times over eight runs (22 or 23 ms and 97 to 101 ms), the `fail`
# before #224 3.9 to 4.2 over six (10 or 11 ms and 42 to 46 ms), and the
# substitution 15.4 and 15.5 over two (227 ms and 3,535 ms, 231 ms and 3,576
# ms). The form `fail` has now, reading the whole message with `mapfile`,
# measured 15 or 16 ms and 69 to 73 ms, 4.3 to 4.7 times, in four runs of
# this row at a load average of 18 to 25, two of them rev-agent-224's (review
# of PR #285, round 4); beside `fail` the library quotes one of them, 70 ms at
# 10,000 lines. So the bound of eight stands about 1.7 times above the linear
# form and 1.9 times below the substitution, against a spread of about five
# per cent. A
# run cut off at 20 s of wall clock, or one that exits non-zero, fails the
# row, so a `fail` that is not there fails it too, and one slow enough to be
# cut off fails it in the refusing direction, as the defect does.
#
# TWO SHAPES, because a size can be in many lines or in one. The form this
# file first pinned, `${line%%$'\n'*}` for the first line and `${line#*$'\n'}`
# for the rest, is linear in the number of lines and grows with the square of
# the FIRST line: 55 ms of CPU for a 10,000-byte first line and 887 ms at
# 40,000, measured by rev-agent-224 in round 3 of the review of PR #285 at
# 2.9 s and 51.9 s of wall clock for 40 KB and 160 KB. The many-lines shape
# never sees it, because each of its lines is 58 bytes. So the second shape is
# a first line of 40,000 bytes against one of 160,000, each followed by one
# short line. Not 10,000 against 40,000: a linear `fail` takes 3 or 4 ms at
# 10,000, under the 10 ms floor, and the floor then hides a `%%` strip alone,
# 3 ms and 38 ms reading as 3.8 times. Measured on this row at a load
# average of 24, fastest of three: the linear `fail` 13 and 16 ms, ok; the
# `fail` before #224, whose `%%` strip this shape exists for, 41 and 855 ms,
# FAIL; the linear `fail` with its first line taken by `%%` again, 48 and
# 887 ms, FAIL; and the second form cut off at 20 s at 160,000 bytes, FAIL.
# The many-lines shape passes all three of those, which is why it is not
# enough alone.
#
# THE TIME PRINTED IS THE TIME MEASURED. The floor enters the ratio and
# nothing else, so a small time under 10 ms is printed as it was read (review
# of PR #285, round 3).
#
# `record` IS NOT TIMED HERE. LEDGER is empty, so `record` returns before its
# own `${3//$'\t'/ }`, which is a many-match substitution of #293's kind over
# the first line and is #300's, with `pass`'s `%%` strip.

section "=== issue #293: fail costs time linear in its message ==="

requirement GH-293 <<'REQ'
- text: `fail` prints a message, and hands `record` its first line, in time
  linear in the message's size, whether that size is in many lines or in one
  long first line. Under C.UTF-8, each the fastest of three: one `fail` over
  10,000 lines of 58 bytes costs at most eight times the CPU time of one over
  the first 2,500 of them; and one over a 160,000-byte first line and a short
  second line costs at most eight times the CPU time of one over a
  40,000-byte first line and the same second line.
- from: #293
- kind: defect-refusing
- status: active
- direction: static: a property of the suite's helpers
- note: What `fail` prints is #224's, pinned by GH-224.1, and a linear `fail`
  prints it byte for byte as the substitution did; this entry is about the
  time alone. `record`'s own time is not in it: the check runs with an empty
  LEDGER, and `record`'s tab substitution is #300's.
REQ
shape_pin 'GH-293:static'

R293_LARGE="$FIXTURES/r293-large"
R293_SMALL="$FIXTURES/r293-small"
awk 'BEGIN { for (i = 0; i < 10000; i++) printf "line %05d of a captured output, padded to about 57 bytes\n", i }' > "$R293_LARGE"
head -n 2500 "$R293_LARGE" > "$R293_SMALL"
R293_FIRST_LARGE="$FIXTURES/r293-first-large"
R293_FIRST_SMALL="$FIXTURES/r293-first-small"
{ head -c 160000 /dev/zero | tr '\0' a; printf '\nsecond\n'; } > "$R293_FIRST_LARGE"
{ head -c 40000 /dev/zero | tr '\0' a; printf '\nsecond\n'; } > "$R293_FIRST_SMALL"
# The status is `timeout_status` and not `rc`: it is what `timeout` returns,
# the child bash's status or 124 at the cut-off, and the #98 self-test derives
# every helper that reads `rc=$?` as one that runs a hook, which this one does
# not. Named after the tool it reads, as `unarmed` names grep's `grep_status`.
r293_fail_ms() {  # r293_fail_ms <message file> -- "<CPU ms> <exit>", the fastest of three
  local i ms timeout_status best=
  for i in 1 2 3; do
    ms=$(LC_ALL=C.UTF-8 LEDGER= REQ=GH-0 timeout 20 bash -c '
      source "$1" || exit 90
      m=$(< "$2")
      TIMEFORMAT="%3U %3S"
      cpu=$( { time fail static "%s" "$m" > /dev/null; } 2>&1 ) || exit 91
      user=${cpu% *} sys=${cpu#* }
      echo $(( 10#${user/./} + 10#${sys/./} ))' bash "$SUITE_DIR/checks/library.sh" "$1" 2> /dev/null)
    timeout_status=$?
    [ "$timeout_status" = 0 ] || { printf '%s %s\n' - "$timeout_status"; return; }
    if [ -z "$best" ] || [ "$ms" -lt "$best" ]; then best=$ms; fi
  done
  # Every status but 0 returned above, so the one printed here is 0.
  printf '%s 0\n' "$best"
}
# THE INPUTS ARE ASKED FIRST (review of PR #285, round 5). Were a generator
# above to break, its file would be empty or one line, `fail` would take no
# time at either size, and the ratio of two floored nothings would pass --
# measured, with the awk program given one `{` too many, `head -c 0` for the
# long first lines and the quadratic substitution as `fail`, both rows printed
# ok at 0 ms and 0 ms. So each file is held to what the row's label says it
# is, written as literals and not read back from the generators, and a file
# that is not fails the row before anything is timed.
r293_holds() {  # r293_holds <file> -- "<lines> lines, <bytes> bytes, first line <bytes>"
  printf '%s lines, %s bytes, first line %s' "$(( $(wc -l < "$1") ))" "$(( $(wc -c < "$1") ))" \
    "$(( $(head -n 1 "$1" | wc -c) ))"
}
r293_scales() {  # r293_scales <shape> <small file> <small size> <small holds> <large file> <large size> <large holds>
  local small large floored holds file size want
  for holds in "$2|$3|$4" "$5|$6|$7"; do
    IFS='|' read -r file size want <<< "$holds"
    if [ "$(r293_holds "$file" 2> /dev/null)" != "$want" ]; then
      fail static '%s\n         the input at %s holds %s, not %s, so no time over it is the time this row names' \
        "fail over $1" "$size" "$(r293_holds "$file" 2>&1)" "$want"
      return
    fi
  done
  small=$(r293_fail_ms "$2")
  large=$(r293_fail_ms "$5")
  if [ "${small#* }" != 0 ] || [ "${large#* }" != 0 ]; then
    fail static '%s\n         the child bash exited %s at %s and %s at %s (124 is the 20 s cut-off), so no time here is the time of fail' \
      "fail over $1" "${small#* }" "$3" "${large#* }" "$6"
    return
  fi
  small=${small% *} large=${large% *}
  floored=$small
  [ "$floored" -ge 10 ] || floored=10
  if [ $(( large * 10 / floored )) -lt 80 ]; then
    pass static 'scaled fail over %s: %s ms of CPU at %s, %s ms at %s' "$1" "$small" "$3" "$large" "$6"
  else
    fail static '%s\n         %s ms of CPU at %s, %s ms at %s; four times the size may cost at most eight times' \
      "fail is not linear in $1" "$small" "$3" "$large" "$6"
  fi
}

req GH-293
r293_scales 'many lines' \
  "$R293_SMALL" '2,500 lines' '2500 lines, 145000 bytes, first line 58' \
  "$R293_LARGE" '10,000 lines' '10000 lines, 580000 bytes, first line 58'
r293_scales 'one long first line' \
  "$R293_FIRST_SMALL" 'a 40,000-byte first line' '2 lines, 40008 bytes, first line 40001' \
  "$R293_FIRST_LARGE" 'a 160,000-byte first line' '2 lines, 160008 bytes, first line 160001'

sourced_to_end

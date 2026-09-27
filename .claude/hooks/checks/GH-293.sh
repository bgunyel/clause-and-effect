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
# Measured by CPU time at a load average of 26, fastest of three at each size:
# the linear `fail` 4.2 to 4.4 times over eight runs (22 or 23 ms and 97 to
# 101 ms), the `fail` before #224 3.9 to 4.2 over six (10 or 11 ms and 42 to
# 46 ms), and the substitution 15.4 and 15.5 over two (227 ms and 3,535 ms,
# 231 ms and 3,576 ms). So the bound of eight stands 1.8 times above the one
# and 1.9 times below the other, against a spread of about five per cent. A
# run cut off at 20 s of wall clock, or one that exits non-zero, fails the
# row, so a `fail` that is not there fails it too, and one slow enough to be
# cut off fails it in the refusing direction, as the defect does.

section "=== issue #293: fail costs time linear in its message ==="

requirement GH-293 <<'REQ'
- text: `fail` prints and records a message in time linear in its size:
  under C.UTF-8, one `fail` over a message of 10,000 lines, 580 KB, costs at
  most eight times the CPU time of one over the first 2,500 of those lines,
  each the fastest of three.
- from: #293
- kind: defect-refusing
- status: active
- direction: static: a property of the suite's helpers
- note: What `fail` prints is #224's, pinned by GH-224.1, and a linear `fail`
  prints it byte for byte as the substitution did; this entry is about the
  time alone.
REQ
shape_pin 'GH-293:static'

R293_LARGE="$FIXTURES/r293-large"
R293_SMALL="$FIXTURES/r293-small"
awk 'BEGIN { for (i = 0; i < 10000; i++) printf "line %05d of a captured output, padded to about 57 bytes\n", i }' > "$R293_LARGE"
head -n 2500 "$R293_LARGE" > "$R293_SMALL"
# The child's status is `child_status` and not `rc`, as `unarmed` names grep's
# `grep_status`: the #98 self-test derives every helper that reads `rc=$?` as
# one that runs a hook, and this one runs none.
r293_fail_ms() {  # r293_fail_ms <message file> -- "<CPU ms> <exit>", the fastest of three
  local i ms child_status best= best_status=
  for i in 1 2 3; do
    ms=$(LC_ALL=C.UTF-8 LEDGER= REQ=GH-0 timeout 20 bash -c '
      source "$1" || exit 90
      m=$(< "$2")
      TIMEFORMAT="%3U %3S"
      cpu=$( { time fail static "%s" "$m" > /dev/null; } 2>&1 ) || exit 91
      user=${cpu% *} sys=${cpu#* }
      echo $(( 10#${user/./} + 10#${sys/./} ))' bash "$SUITE_DIR/checks/library.sh" "$1" 2> /dev/null)
    child_status=$?
    [ "$child_status" = 0 ] || { printf '%s %s\n' - "$child_status"; return; }
    if [ -z "$best" ] || [ "$ms" -lt "$best" ]; then best=$ms best_status=$child_status; fi
  done
  printf '%s %s\n' "$best" "$best_status"
}
R293_S=$(r293_fail_ms "$R293_SMALL")
R293_L=$(r293_fail_ms "$R293_LARGE")

req GH-293
if [ "${R293_S#* }" != 0 ] || [ "${R293_L#* }" != 0 ]; then
  fail static '%s\n         the child bash exited %s at 2,500 lines and %s at 10,000, so no time here is the time of fail' \
    'fail over 2,500 and 10,000 lines' "${R293_S#* }" "${R293_L#* }"
else
  R293_S=${R293_S% *} R293_L=${R293_L% *}
  [ "$R293_S" -ge 10 ] || R293_S=10
  if [ $(( R293_L * 10 / R293_S )) -lt 80 ]; then
    pass static 'scaled fail over 2,500 and 10,000 lines: %s ms and %s ms of CPU' "$R293_S" "$R293_L"
  else
    fail static '%s\n         %s ms of CPU at 2,500 lines, %s ms at 10,000; four times the lines may cost at most eight times' \
      'fail is not linear in its message' "$R293_S" "$R293_L"
  fi
fi

sourced_to_end

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
# with an empty LEDGER, fastest of three runs as the library's other timings
# are, and under C.UTF-8, the locale all three measurements above were taken
# in. The message is written to a fixture once and read by each run, so the
# time is `fail`'s and not the loop that made it. Timed this way, the linear
# `fail` took 195 ms over this file and the substitution 6,622 ms, so the
# bound of 1000 ms stands about five times above the one and seven times
# below the other. The exit status is printed beside the time, as `lib_run`'s
# is, because a `fail` that is not there fails fast at every size.

section "=== issue #293: fail costs time linear in its message ==="

requirement GH-293 <<'REQ'
- text: `fail` prints and records a message in time linear in its size. One
  `fail` over a message of 10,000 lines, 580 KB, under C.UTF-8, finishes in
  under a second, fastest of three.
- from: #293
- kind: defect-refusing
- status: active
- direction: static: a property of the suite's helpers
- note: What `fail` prints is #224's, pinned by GH-224.1, and a linear `fail`
  prints it byte for byte as the substitution did; this entry is about the
  time alone.
REQ
shape_pin 'GH-293:static'

R293_MSG="$FIXTURES/r293-message"
awk 'BEGIN { for (i = 0; i < 10000; i++) printf "line %05d of a captured output, padded to about 57 bytes\n", i }' > "$R293_MSG"
R293_BEST=
R293_RC=
for R293_I in 1 2 3; do
  R293_S=$(date +%s%N)
  LC_ALL=C.UTF-8 LEDGER= REQ=GH-0 timeout 20 bash -c 'source "$1"; fail static "%s" "$(< "$2")"' \
    bash "$SUITE_DIR/checks/library.sh" "$R293_MSG" > /dev/null 2>&1
  R293_STATUS=$?
  R293_E=$(date +%s%N)
  R293_MS=$(( (R293_E - R293_S) / 1000000 ))
  if [ -z "$R293_BEST" ] || [ "$R293_MS" -lt "$R293_BEST" ]; then
    R293_BEST=$R293_MS R293_RC=$R293_STATUS
  fi
done

req GH-293
if [ "$R293_RC" != 0 ]; then
  fail static '%s\n         the child bash exited %s, so its time is not the time of fail' \
    'fail over a 10,000-line message' "$R293_RC"
else
  under_a_second 'fail over a 10,000-line message' "$R293_BEST"
fi

sourced_to_end

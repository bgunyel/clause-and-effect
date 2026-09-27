#!/bin/bash
# THE ISSUE FILE OF #187: `report_says` records a run of the session report only
# for a byte copy of the registered one.
#
# Why: `ran` refuses an absolute path, because an absolute path is a fixture
# copy and not the registered hook, and `report_says` stepped around that rule
# for the session report, which reads the repository it sits in and so is only
# ever run as a copy placed in a fixture. It recorded any script whose basename
# was `report-stale-branches.sh`, on the strength of an invariant -- every
# fixture carrying that name is a byte copy -- which a comment stated and
# nothing enforced, while `nolib_path` and `halflib_path` build modified copies
# of other hooks. A modified copy keeping the name would have been recorded as
# a run of the registered report, and GH-109.4 would have gone green for a hook
# no check ran. The sixth review of PR #169 filed it; nothing was a false green
# when it was filed, since every copy that reached `report_says` was a `cp`.
# The condition is now `cmp -s` against `$HOOKS/report-stale-branches.sh`, so
# the invariant is the test itself. Under an override $HOOKS is the mutated
# copy, and every fixture copies from $HOOKS, so a copy of a mutated report
# still matches and is still recorded.
#
# WHAT IS DRIVEN is the helper, run inside a subshell against a private run
# record, which prints what the helper printed on either stream and the FAILED
# it left, and then everything written to that record. Inside the subshell the
# helper's `pass` is not recorded, and the private record keeps its `ran` out of
# the real one, so neither row adds a run of the report to what GH-109.4 reads.
# The PATH is the suite's own, which is one of the four `report_run_paths`
# pins.
#
# NO MUTATION ROW, BECAUSE NONE IS POSSIBLE: the condition is in the check
# library, which is the tooling, and mutate-hooks.sh runs this suite against a
# mutated copy of the hooks and never a mutated suite. The evidence is a
# recorded run instead, as GH-144.4's is.
#
# MEASURED, 2026-09-28, three whole runs of the suite, each scratch edit made
# on a copy of the library backed up first and restored from that backup, its
# sha256 checked. Before the fix, and again with the fix's `cmp -s` guard taken
# out and the name test left, the run failed one row of 6228, the first below,
# and printed the same failure both times:
#
#     FAIL report_says records nothing for a copy that keeps the report's name and not its bytes
#          want |  ok   report r187 driven check
#     FAILED=0
#     record |||
#          got  |  ok   report r187 driven check
#     FAILED=0
#     record |GH-187	report-stale-branches.sh||
#
# The second row's label was held to what it claims the same way: with the
# whole recording line deleted from `report_says`, it went red, `record |||`
# where it wanted the tagged name, and the first row stayed green -- so the
# second row is what stops the fix passing by recording nothing. That run failed
# one more row, GH-109.4's `settings.json registers report-stale-branches.sh,
# and no tagged check ran it`, which is the record doing its job.

section "=== issue #187: report_says records the session report only for a byte copy of it ==="

requirement GH-187 <<'REQ'
- text: `report_says <PATH> <script> <literal> <label>` records a run of
  `report-stale-branches.sh` only when `cmp -s` finds the script it ran
  byte-identical to `$HOOKS/report-stale-branches.sh`. A modified copy is not
  recorded, whatever its name, since it is not the registered report; an
  unmodified copy is recorded, against the tag in force. The verdict the
  helper prints is unchanged either way.
- from: #187, the sixth review of PR #169
- kind: defect-permitting
- status: active
- direction: static: a property of the suite's run
- note: The condition was the script's basename, resting on an invariant --
  every fixture carrying the name is a byte copy -- that a comment stated and
  nothing enforced. Byte equality makes that invariant the condition. The
  alternative, builders registering their copies in a list, was rejected: a
  builder could register a modified copy as easily as it makes one. The fix
  gives up no case: every copy the suite runs today is a `cp` of the file.
REQ
shape_pin 'GH-187:static'

# What a helper prints opens with two blanks, held in a variable so that no
# quoted string here opens with a result's prefix: #104's audit at the foot of
# the suite reads every such string as a result printed around pass and fail.
R187_INDENT='  '
# THE FIXTURES, two copies of the report outside any repository, where it says
# the branches were not read and exits 0: one a byte copy, and one with a
# comment line appended, which changes nothing it does and keeps its name. Each
# sits two levels down, as the report cds to its own grandparent. Both are made
# from $HOOKS, so under an override the byte copy is still one.
R187_DIR="$FIXTURES/r187"
R187_COPY="$R187_DIR/copy/.claude/hooks/report-stale-branches.sh"
R187_MODIFIED="$R187_DIR/modified/.claude/hooks/report-stale-branches.sh"
R187_RAN="$R187_DIR/ran"
mkdir -p "${R187_COPY%/*}" "${R187_MODIFIED%/*}"
cp "$HOOKS/report-stale-branches.sh" "$R187_COPY"
cp "$HOOKS/report-stale-branches.sh" "$R187_MODIFIED"
printf '# a line #187 appended, so that this is not the registered report\n' >> "$R187_MODIFIED"
cmp -s "$R187_COPY" "$HOOKS/report-stale-branches.sh" \
  && [ -s "$R187_MODIFIED" ] && ! cmp -s "$R187_MODIFIED" "$HOOKS/report-stale-branches.sh" || {
  echo "the #187 report copies were not made as a byte copy and a modified one; the checks against them prove nothing" >&2
  exit 1
}
r187_report() {  # r187_report <script> -- what report_says printed on <script>, its FAILED, and the private record
  : > "$R187_RAN"
  ( FAILED=0
    RAN="$R187_RAN"
    report_says "$PATH" "$1" 'branches: NOT READ -- this is not a git repository' 'r187 driven check'
    printf 'FAILED=%s\n' "$FAILED" ) 2>&1
  printf 'record |%s|\n' "$(cat "$R187_RAN")"
}

req GH-187
tok "report_says records nothing for a copy that keeps the report's name and not its bytes" \
"${R187_INDENT}ok   report r187 driven check
FAILED=0
record ||" \
    "$(r187_report "$R187_MODIFIED")"
tok 'and records a byte copy as the report, against the tag in force' \
"${R187_INDENT}ok   report r187 driven check
FAILED=0
record |GH-187	report-stale-branches.sh|" \
    "$(r187_report "$R187_COPY")"

sourced_to_end

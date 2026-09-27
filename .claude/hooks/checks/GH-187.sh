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
# NO NAME TEST beside the bytes. The first version of this fix kept one, and
# round 1 of its review measured that deleting it left every check green: it
# could refuse only a byte copy under another name, and that is the registered
# report's bytes, so a run of it. A clause no check can fail is not carried
# here, and the third row below records such a copy, so that putting the name
# test back is a red row and not only a reversal of this paragraph.
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
# MEASURED, 2026-09-28, in answer to round 2 of its review: eleven whole runs
# of the suite, each in its own scratch clone of the branch with one edit
# applied there, so no backup of this checkout was needed. Each run's record
# was copied out just before end-of-run.sh reads it.
#
#   the edit                                     exit  FAIL rows          runs
#   the base, cd67c8e, which has no GH-187       0     none of 6226       10
#   none, this fix                               0     none of 6229       10
#   the base's name-only test put back           1     the first and      10
#                                                      third rows
#   the name test put back beside `cmp -s`       1     the third row      10
#   `cmp -s` deleted, `ran` unconditional        1     the first row      13
#   the recording line deleted                   1     the second and      -
#                                                      third rows, and
#                                                      GH-109.4's
#   `cmp -s` against no-git-push.sh instead      1     as the line above   -
#   `ran` given REQ=GH-109.4 for the report      1     the second and     10
#                                                      third rows
#   R187_TAB set to a blank                      1     the second and     10
#                                                      third rows
#   the fixture's appended line not written      1     none; the fixture   -
#                                                      guard stopped the
#                                                      run, at 6075 rows
#   the renamed copy given the report's name     1     as the line above   -
#
# In answer to round 3, two more, so that each clause of the fixture guard has
# been broken on its own: a line appended to the byte copy, and one appended to
# the renamed copy. Each exited 1 with no FAIL row, the guard having stopped
# the run at 6075 rows, as above.
#
# `runs` is what GH-109.4 derived, `report-stale-branches.sh was run N times
# under a tag`. The base's record and this fix's, sorted, are identical, all
# 16 lines, so the fix gives up no case. With the name test put back alone,
# the first row printed this, the TAB written <TAB> here:
#
#     FAIL report_says records nothing for a copy that keeps the report's name and not its bytes
#          want |  ok   report r187 driven check
#     FAILED=0
#     record |||
#          got  |  ok   report r187 driven check
#     FAILED=0
#     record |GH-187<TAB>report-stale-branches.sh||
#
# The 13 is three of the #98 self-test's fixtures, `speak-0`, `allow-0` and
# `block-2`, recorded as the report under `GH-98 GH-124`; that run logged the
# name and status of every script it recorded. Its two crashing fixtures are
# never recorded whatever the condition, because `ran` records only an exit 0
# or 2. So with no `cmp -s` nothing keeps those three out, and nothing but the
# first row goes red. The name test would keep them out too, since they carry
# other names, but `cmp -s` already does. This block as it stood at bc114b5,
# and that commit's message, said the 13 was the crashing fixtures: that was
# reasoned from a comment this change deleted, and never measured.
# GH-109.4's row is `settings.json registers report-stale-branches.sh, and no
# tagged check ran it`, which is the record doing its job. The second row going
# red with the first row green, and the right tool recorded under the wrong
# tag, is what holds the "against the tag in force" half of its label.

section "=== issue #187: report_says records the session report only for a byte copy of it ==="

requirement GH-187 <<'REQ'
- text: `report_says <PATH> <script> <literal> <label>` records a run of
  `report-stale-branches.sh` for a script which `cmp -s` finds byte-identical
  to `$HOOKS/report-stale-branches.sh`, whatever it is named, and for no other
  script. It records it as `ran` records any run: only for an exit of 0 or 2,
  under a tag. A modified copy is not recorded, even one keeping the name,
  since it is not the registered report; an unmodified copy is recorded,
  against the tag in force, and so is a byte copy under another name, since
  its bytes are the registered report's. The verdict the helper prints is
  unchanged.
- from: #187, the sixth review of PR #169
- kind: defect-permitting
- status: active
- direction: static: a property of the suite's run
- note: The condition was the script's basename, resting on an invariant --
  every fixture carrying the name is a byte copy -- that a comment stated and
  nothing enforced. Byte equality makes that invariant the condition. The
  alternative, builders registering their copies in a list, was rejected: a
  builder could register a modified copy as easily as it makes one. No name
  test is kept beside the bytes: it could only refuse a byte copy under
  another name, which is the registered report's bytes, and a check records
  one. The fix gives up no case: every copy the suite runs today is a `cp` of
  the file.
REQ
shape_pin 'GH-187:static'

# What a helper prints opens with two blanks, held in a variable so that no
# quoted string here opens with a result's prefix: #104's audit at the foot of
# the suite reads every such string as a result printed around pass and fail.
R187_INDENT='  '
# The record's two fields are TAB-separated; written as $'\t' so that no editor
# or reflow can turn the expectation into spaces.
R187_TAB=$'\t'
# THE FIXTURES, three copies of the report outside any repository, where it
# says the branches were not read and exits 0: a byte copy; one with a comment
# line appended, which changes nothing it does and keeps its name; and a byte
# copy under another name. Each sits two levels down, as the report cds to its
# own grandparent. All are made from $HOOKS, so under an override the two byte
# copies are still byte copies.
R187_DIR="$FIXTURES/r187"
R187_COPY="$R187_DIR/copy/.claude/hooks/report-stale-branches.sh"
R187_MODIFIED="$R187_DIR/modified/.claude/hooks/report-stale-branches.sh"
R187_RENAMED="$R187_DIR/renamed/.claude/hooks/renamed.sh"
R187_RAN="$R187_DIR/ran"
mkdir -p "${R187_COPY%/*}" "${R187_MODIFIED%/*}" "${R187_RENAMED%/*}"
cp "$HOOKS/report-stale-branches.sh" "$R187_COPY"
cp "$HOOKS/report-stale-branches.sh" "$R187_MODIFIED"
cp "$HOOKS/report-stale-branches.sh" "$R187_RENAMED"
printf '# a line #187 appended, so that this is not the registered report\n' >> "$R187_MODIFIED"
cmp -s "$R187_COPY" "$HOOKS/report-stale-branches.sh" \
  && ! cmp -s "$R187_MODIFIED" "$HOOKS/report-stale-branches.sh" \
  && cmp -s "$R187_RENAMED" "$HOOKS/report-stale-branches.sh" \
  && [ "${R187_RENAMED##*/}" != report-stale-branches.sh ] || {
  echo "the #187 report copies were not made as a byte copy, a modified one and a renamed byte copy; the checks against them prove nothing" >&2
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
record |GH-187${R187_TAB}report-stale-branches.sh|" \
    "$(r187_report "$R187_COPY")"
tok "and a byte copy under another name as the report too, since its bytes are the registered report's" \
"${R187_INDENT}ok   report r187 driven check
FAILED=0
record |GH-187${R187_TAB}report-stale-branches.sh|" \
    "$(r187_report "$R187_RENAMED")"

sourced_to_end

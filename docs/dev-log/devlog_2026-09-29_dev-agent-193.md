# 2026-09-29 · dev-agent-193 — `--list` applies every row's edit, sandboxed, and the run count is exact

2026-09-29 08:08 +03. Branch `worktree-issue-193-list-applies-edits`, cut with
`--no-track` from `origin/dev-05` and fast-forwarded to `f539d9a` before its
first commit. Range `f539d9a..` this entry's commit: four commits ahead of
`origin/dev-05`, the entry included. Closes #193 and #272.

## `--list` now measures the run count instead of predicting it

`mutate-hooks.sh --list` applies every registry row's edit through
`row_apply`, a new function that pass two also edits the copy with. It uses
`sed --sandbox`, writes to a scratch file and never back into its file. A new
`EDIT` column says, per row, `applies`, `unchanged` or `fault`. A row whose edit
does not do what it declares is marked on a line under it, and so is a fault,
with its reason. The run count is the baseline plus every row whose edit
applies, so the `at most` hedge came out of the output line, the header and
GH-148's text. `--list` sums `.claude/hooks/` before and after, the way a whole
run does, and exits non-zero if it moved. It exits non-zero for nothing else.
Faults and mismatches are GH-193's to turn red.

Measured on today's registry: all 152 rows' edits do exactly what they declare
under the sandbox. The run count is unchanged at 152, and no row is a fault.
Three `--list` runs at load 27 took 3.1–3.9 s of wall clock and 0.83–0.91 s of
CPU. Before this change it read only the table. A rotted anchor used to
surface only as `did-not-apply` at the end of a whole-registry pass.

The working copy's temporary directory and its guards, `hooks_copy` and
`tree_sum` moved above the `--list` branch, so `--list` writes its scratch
file only after the same containment questions a run asks. So `--list`
also exits 1 under a `TMPDIR` inside the hooks directory. The spec review
named that exit, and it is the guard's own refusal.

## #272 is the sandbox, and gave up no row

Pass two used to run `sed "$EDIT" "$TARGET"`. A `w`, `r` or `e` in an edit
therefore wrote, read or ran something before any guard was asked. The
sandbox refuses `w`, `W`, `r`, `R`, `e`, `s///w` and `s///e`, each measured as
sed exiting 1. The refusal reaches the caller as the row's fault. Refusing the
letters by reading the text was rejected, as #272's triage recommended: `w` is
an ordinary character in a pattern.

One behaviour beyond the spec: `row_apply` also refuses a symlinked target.
The spec asked for "a regular file and writable". A mutation written through a
symlink lands wherever the link points. No file under `.claude/hooks/` is a
symlink, so nothing moved. Pass two's refusal message changed with it.

`--list` asks whether a target is writable of the file beside the harness,
while pass two asks it of the copy. `cp -a` keeps the mode and makes the copy
the running user's, so the two agree whenever that user owns the file. That
one assumption is named in the header and beside `row_apply`, and no fixture
can vary it.

## The suite side

- `checks/GH-193.sh` applies every row's edit with a `sed --sandbox` program of
  its own, never `--list` or `row_apply`, and holds each row to its declared
  outcome. The program is driven first by fixture rows, one per way a row can
  be wrong. The file then drives `--list` against a copy of the harness whose
  registry is eight fixture rows. It checks the `EDIT` column, the marks, the
  run count (3), the exit status, and that nothing is hedged. It also pins the
  header's new paragraph.
- `checks/GH-272.sh` drives `--list` and a whole pass against a fixture
  registry of the seven sandbox-refused commands and a stub `check-hooks.sh`,
  so pass two reaches every row in under a second. Every row is a fault in both
  passes, and none of the files the rows name is written.
- `harness_fixture` and `harness_rows` went into the library, because they have
  two calling files.
- Both entries are generated and carry `shape_pin`. GH-148's hand-written
  entry was revised, and its `SPLIT_MOVED` token moved with it, as #164 and
  #118 had done for theirs.
- The #148 run-count check keeps comparing against declarations. Its comment
  now says what it establishes and, since review, what it cannot see (below).

## Hand mutation checks: nine, all caught

The work is `$TOOLING`, so no registry row can reach it. Each mutant was built
by a script that asserts its edit landed exactly once, in a `git archive` copy
of the tree at `e3fcb58`. The suite ran in each copy beside an unmutated
control copy. The control's only reds were the two a copy outside a git
repository produces ("no git common directory", and the dev-NN run reader),
and every mutant was red beyond them:

| mutant | red |
|---|---|
| `--sandbox` dropped from `row_apply` | six GH-272 rows, `--list` and pass two both; the files were written |
| `--list` counting unchanged rows off the declaration | GH-193's fixture run count, and nothing else |
| symlink target admitted | GH-193's `EDIT` column, marks, summary, run count |
| `at most` put back on the output line | GH-193 "and is not hedged" |
| a real row's anchor rotted (`sudo-not-a-wrapper`) | GH-193's registry check, and both #148 figures (runs, minutes) |
| GH-193's own program unsandboxed | its fixture mismatch list, and the `w` target written |
| `--list` writing each edit back in place | the suite stopped at the #148 guard: `--list` exited 1 naming both sums |
| `--list`'s sum comparison deleted | GH-193's `armed` pin on it |
| pass two back on unsandboxed `sed`, `--list` left alone | GH-193's pass-two pin and three GH-272 pass rows, and not GH-272's `--list` rows |

`2086cc4` then restructured `--list`'s branch assignment without changing
behaviour, so the second mutant's anchor no longer matches that commit
verbatim. The rest of the table stands on `e3fcb58`.

## Mistakes, and who found them

- The assistant ran the suite before checking `origin/dev-05`, which had moved
  eight commits (#227's CI summary, touching nothing under `.claude/hooks/`).
  `no-work-on-stale-branch.sh` refused the first commit. The run was stopped
  and the branch fast-forwarded. Measurements taken before that were of
  unchanged hook files.
- The first full run on the branch was red on two rows, both the assistant's.
  GH-193.sh called `comment_reflow` directly, where #192's rule wants
  `prose_reflow`. Its four `armed` pins also moved the text-check count from
  322 to 326. Fixed in `e3fcb58`.
- The assistant wrote the #148 comment claiming that check would catch a
  `--list` put back to counting off the declarations. It cannot: both sides
  then count declarations and agree on every registry. That is the trap the
  issue's question 4 warned about. The spec review, run by the assistant as a
  sub-agent, found it, and the second mutant above measured it: GH-193's
  fixture went red, and #148 stayed green. The comment now says so.
- The standards review found "a few seconds" written twice in a header that
  states it holds no magnitude, and "so it is exact" beside "one assumption is
  left in it". Both were rewritten in `2086cc4`, and the measurement moved
  into GH-193.sh with its load.
- The spec review found three citations from #199 and #208, in
  `.github/scripts/check_hooks_ci.py` and two test docstrings. They credited
  #193 with asking for CI's machine-readable counts and with settling how the
  harness constants follow from them, and #193 did neither. They now say so.
  `tests/test_check_hooks_ci.py` and `tests/test_check_hooks_workflow.py`
  passed afterwards (88).
- `no-git-push.sh` refused a push followed by `2>&1 | grep`, reading `2>` as
  the destination. `no-commit-to-main.sh` refused a `cd` in front of a
  commit. Both were run again plainly. One scripted edit reported nothing
  because its checking `grep` was the interactive ugrep. The edit had landed,
  which was confirmed from `git diff`.

Bertan added the worktree-scoped Edit/Write rules for `.claude/hooks/` before
any hook file was touched. Without them auto mode refuses hook edits.

## Evidence at the end

- `bash .claude/hooks/check-hooks.sh` at `2086cc4`: ALL CHECKS PASSED, 8058
  rows ok.
- `bash .claude/hooks/mutate-hooks.sh -v selftest-anchor-that-matches-nothing
  selftest-registered-against-the-wrong-requirement` at `2086cc4`: the baseline
  was green over 267 requirements. The first self-test reported did-not-apply
  and the second survived, both as declared, in 2 runs of the suite, which is
  what `--list`'s counting predicts for those two rows. `.claude/hooks/` was
  byte-identical after. No whole-registry pass was run.

## Open

- `harness_rows` is the same awk as the #107 section's `MUT_ROWS` reader, and
  GH-193 and GH-272 parse `--list`'s output with the same inline awk. The
  standards review called both judgement calls. They were left as they are.
- How the harness's rate constants follow from CI's recorded counts and times
  is now owned by no issue. It is not #193's.
- `--list`'s writability assumption (a source file owned by someone else) is
  named, not driven.

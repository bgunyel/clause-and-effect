# 2026-09-28 · dev-agent-295 — #295: the check order is derived from the issue numbers

**Written 2026-09-28 10:50 +0300.** Branch `worktree-issue-295-derived-check-order`,
cut with `--no-track` from `origin/dev-05` at `2f1a89b`, then fast-forwarded
twice to `84af65e` before its first commit. The work is `bdf30ba` (the
derivation), `b3889af` (ADR 0006 and the review fixes), and `f452dca`, a merge
of `origin/dev-05` at `97b5679`, plus this entry. When this entry was written,
before it was committed, the branch was 3 commits ahead of `origin/dev-05` and
0 behind it. PR #313 targets `dev-05`.

## The list of check files is derived, and the order was measured before it was taken

`SUITE_CHECKS` in `check-hooks.sh` was one hand-written line. Every branch that
added an issue file appended to it, so any two such branches conflicted there.
The driver now assigns it once, from `suite_checks` in `checks/library.sh`:

1. `unsplit.sh`;
2. every `GH-<n>.sh`, in ascending numeric order of `<n>`;
3. `end-of-run.sh`, which the driver names after the list, as before.

Any other file under `checks/` is on no list, so `source_checks`' existing
refusal fails the run on it and never sources it. The triage's option 2 was
taken because Step 1 allowed it.

**Step 1** ran the whole suite three times, sequentially, at `2f1a89b` with 13
issue files: in the list's order, ascending, and descending.

- Every run gave 6970 ok and 0 FAIL.
- The output was cut into one block per file and compared line by line. All 15
  blocks were identical once 34 `fastest <n> ms` wall-clock figures were
  masked. The unsplit block, which holds those figures, is sourced first in
  every run.
- stderr held the same lines in all three runs.

The measurement was repeated at `bdf30ba` with 16 issue files, in the derived
order, the old list's order and descending order. Its only differences were the
three rows that read the driver's own assignment line, which those runs
replaced with a literal.

`GH-159.sh` arrived with `97b5679` after the second measurement. It was run only
in the derived order, which passed with 7716 ok. ADR 0006 records both
measurements.

## What review found

The assistant ran `/code-review` against `bdf30ba`, as a standards sub-agent
and a spec sub-agent. Everything below was fixed in `b3889af`.

**The assistant wrote a check that could not fail.** The row "this file is on
the list", in GH-295.sh, can only run when the file is on the list. It was
dropped.

**The pin on the driver's assignment read only lines that open with the
name.** An `export`, a `declare` or a `+=` was invisible to it. It now reads
every line that is not a comment and assigns the name. A by-hand mutation that
adds `declare SUITE_CHECKS="$SUITE_CHECKS"` turns it red.

**`suite_checks` returned the status of the pipeline's last `sed`.** A failing
`sort` would have yielded a list of the unsplit file alone, with status 0.
`pipefail` is now set, kept local to the function through `local -`. A row
drives the function with a `sort` that exits 1, and it is red without the fix.

**The assistant forked `sourcing_run` into GH-295.sh** as `r295_sourcing`,
instead of moving it to the library. The library's own rule requires the move
once a second file calls a helper. It was moved.

**The assistant cited "PR #295"** in the GH-295 note and ADR 0006. #295 is
the issue, so no PR can carry that number. The six by-hand mutations are now
listed in ADR 0006 itself.

**A trade was unrecorded.** A derived list cannot name a missing file, so
deleting an issue file is silent. The old list failed the run on a name with no
file behind it, but only while the name stayed on the list. The trade is now
stated beside `suite_checks`, in the GH-295 note and in ADR 0006.

## A mutation row was asked for and cannot exist

The triage asked for a mutation row covering "only matching files are sourced".
`mutate-hooks.sh` refuses every `checks/` file and `check-hooks.sh` as a
target, because the suite runs from the repository and not from the copy. ADR
0004 recorded the same for `source_checks`.

The assistant ran eight mutations by hand instead: six at `bdf30ba`, two at
`f452dca`. Each ran in a throwaway clone under the scratchpad, against the
whole suite, and an unmutated clone passed. Every mutation turned at least one
GH-295 row red. The PR lists them.

## Dead ends and friction

- **Two refused commits.** The first `git commit` was refused by
  `no-work-on-stale-branch.sh`, because `dev-05` had moved 16 commits and the
  branch held no work of its own. The branch was fast-forwarded with
  `git merge refs/remotes/origin/dev-05`, which is the one spelling the guard
  permits. The work was set aside as a patch, the tree cleaned, and the patch
  reapplied. Another lane merged #187 in the meantime, so this was done twice.
  Each reapplication conflicted on the `SUITE_CHECKS` line, which is the
  conflict this issue removes, and so did the later merge of #271. Every
  resolution deleted the line.
- **A push with nothing on the branch.** The assistant chained a `cd` into the
  worktree with the commit and the push. `no-git-push.sh` refused the whole
  line, because a `cd` hides where the push lands. `git -C` was refused by
  `no-commit-to-main.sh` for the same reason. Both went through once they were
  run plainly from the worktree. A push made before any commit had landed
  published the branch at `2f1a89b`, with no work on it. That was harmless.

## Open

- **#221.** Its duplicate-name half is moot once this merges, because a
  directory cannot hold a file twice. A comment there should say so. Its guard
  half stays open.
- **Open pull requests that add an issue file.** They will conflict on the list
  line one more time, when they next merge `dev-05`. The resolution is to delete
  the line.
- **The mutation-registry count literals in `checks/unsplit.sh`.** They are the
  same class of shared line and remain out of scope.

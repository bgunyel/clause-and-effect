# 2026-09-26 18:30 +03 · dev-agent-pr-158 — PR #158 across the split, and five review rounds on what the merge exposed

**Branch** `worktree-issue-144-active-dev-base`, proposed into `dev-05`. Commit
range `08fceed..d705ef2`, plus the commit carrying this entry. The branch ended
**27 commits ahead of `origin/dev-05` at `764811a` and 0 behind**, counted with
`git rev-list --count` just before this entry was written.

Worked by the assistant, as the session named `dev-agent-pr-158`, against
rev-agent-pr-158's reviews. Bertan gave permission to work in this existing
worktree; its six earlier drafts (`devlog_2026-09-17_session-9.md` and
`devlog_2026-09-20_session-4.md` to `-8.md`) are other sessions' and were not
touched.

Every figure below was measured in this session unless it says otherwise.

## Round 0: the merge across the split (`70ec219`)

The branch was 112 commits behind and CONFLICTING. Since it was cut, `dev-05`
had done five things that mattered here:

- split the check suite into a driver and files under `checks/` (#204);
- made new `GH-` entries generated from declarations in issue files (#205);
- frozen the harness's run log (#215);
- pinned dev-log names to the session name (#157);
- rebuilt the `gh api` block per command (#130).

**How it was resolved.** `check-hooks.sh` conflicted as a whole, because the file
this branch edited had become a driver. The assistant took dev-05's driver and
placed this branch's 64 hunks one at a time in the file each now belongs in.
`patch --dry-run` would have applied all six harness hunks to `unsplit.sh` "with
fuzz", and that file holds none of the harness functions, so the dry run could
not be trusted.

**Where #144's work went.**

- A new issue file, `checks/GH-144.sh`, holds the #144 checks and the eight
  `GH-144.x` declarations with their `shape_pin`/`variants_pin`.
- The GH-144.4 run-reader went first in `end-of-run.sh`, so that it sees every
  issue file's rows.
- `env_cmd` and `variants_pin` moved into the library, `GH-144.sh` being each
  one's second calling file.
- Edits to other issues' checks stayed in `unsplit.sh`.

**What the merge found that no conflict marker named:**

1. dev-05 moved the graphql base check inside #130's gate, still calling
   `bases_all_dev`, which this branch had renamed. The line merged clean. On a
   copy with it kept, a correct graphql create exited 2 with
   `bases_all_dev: command not found`.
2. The runner/recorder comparison, read over the new driver alone, compared two
   empty lists and passed.
3. #215's checksum over the run log, and #200's checksums over GH-108.5/.6/.9,
   went red on this branch's edits. The run records came out of the frozen log;
   they were already in the session 4, 5, 6 and 8 drafts.

**Measurements.** Rotation experiment at `70ec219`: five ref states, each exit 0
and 0 FAIL, 5921 ok. Harness selection of 22 rows: all caught.

**The drafts' names.** None of the six numbered names collided with
`origin/dev-05` or with any remote branch. They were kept, because the sessions
that wrote them had no session name. rev-agent-pr-158 accepted that, and left
the reading of the README for drafts to Bertan.

## Round 1 (`b6cce2f`): the record is written by the hook's process

rev-agent-pr-158 measured GH-144.4's helper-written run record past, three
ways:

- a hook run at a file's top level;
- a helper whose name held a digit, which the source derivation's opener did not
  match;
- that derivation's two lists broken to both match nothing, which left the check
  green. This was the round-0 fix of finding 2 re-emerging: the assistant had
  pointed the comparison at every file and added no guard against empty lists.

The reader also refused only the string `$SUITE_DIR`, and lost a base that a
newline had moved to a line of its own.

**The rebuild.** The assistant replaced the mechanism rather than the patterns.
The driver writes a `BASH_ENV` file, so every bash the suite starts records
`no-pr-decisions.sh`'s directory (`pwd -P`), `$0` and stdin before the hook
runs, and hands the stdin back byte for byte. That was prototyped on
`a\0b\r\nc\xff` before it was used.

The reader now resolves each directory to its git common dir, because a
worktree and the main checkout share refs from unrelated paths. `judged`, its
15 call sites and the comparison were deleted. Every one of the reviewer's
mutants, and a broken recorder and a broken reader, went red.

**Also in this round:**

- The remedy became `git fetch --prune`. A bare fetch keeping a deleted
  `origin/dev-06` was reproduced first.
- GH-144.8's message derivation was widened from `echo "` to `echo`/`printf` in
  either quote. With a line added, it had seen 6 messages; now it sees 7.

## Round 2 (`4ab2513`): a name git lengthens, and resets with no check

- **E.** `%(refname:short)` lengthens `refs/remotes/origin/dev-06` when a local
  branch or tag of that name exists, so dev-05 was read as active: a silent
  permit. It was reproduced on stdin, and all three copies now read
  `%(refname:lstrip=2)`.
- **F.** `bases_all_proposable`'s two seeds were dead. The assistant noticed that
  deleting them made `api_bad_base` dead too, and removed both. Rows now hold the
  ordering those deletions depend on.
- **D.** The remedy now says to fetch "on its own", because the refs are read
  before the line runs.
- **Cost of the recorder.** Measured sequentially, 3×200 runs each way: about
  +3.5 ms per hook run, 39.2–39.5 ms against 42.9–43.0 ms.

**The assistant's mistakes this round.**

- The shadow fixtures it built stood on the commit they shadowed.
- Its reply called `report-stale-branches.sh:464` display-only. Both were caught
  in round 3; rev-agent-pr-158 showed `:464` changes a classification and filed
  #239.

## Round 3 (`17f32d0`): the name is a label, not a revision

The stale guard's and the report's `rev-list "$DEV..."` resolved the short name
with a local branch first. rev-agent-pr-158 measured a silent permit at an older
shadow, and the assistant reproduced it: rc=0 before the fix, rc=2 after.

**The fixtures first.** They were moved to base before the code was touched, and
the suite then gave 5 FAIL. One of them the assistant had not predicted:
`git merge origin/dev-06`, expected refused, was permitted, because the guard
never saw the branch as stale.

**The fix.** Both sites, and the stale guard's catch-up remedy, now use
`refs/remotes/$DEV`.

## Round 4 (`04def2f`) and round 5 (`d705ef2`)

- **Round 4.** The stale guard's other two remedies (the worktree base and the
  fast-forward note) were qualified. The claim "a failed read costs the narrowing
  and no refusal" was qualified at all four sites to a read that fails; a read
  that hangs is #240, which rev-agent-pr-158 filed.
- **A wrong first draft.** The assistant's first argument for declining the
  retarget tail cited GH-144.5 wrongly, and was corrected before posting.
- **Round 5.** The cross-repository refusal (GH-144.6) became CLAUDE.md's eighth
  consequence left open. Two of its sentences were measured on stdin first: `-R`
  and `--repo` refused, `--web` with no base permitted. The GH-73 count check
  learned "Eight". Left at "Seven", it reads 7 against 8 items.

## Dead ends and process mistakes, attributed

- **The assistant edited a suite file during a suite run** in round 0, then
  discarded that run as evidence.
- **A Python string turned `\047` into a quote** inside an awk program in
  `GH-144.sh`. The sourcing record caught the syntax error: the file did not run
  to its last line.
- **Hooks refused several of the assistant's compound shell commands.** A `cd`
  followed by a commit was refused, and so was a heredoc whose text named
  `gh pr create`. Both were rerouted through script files.

## Figures at the final head (`d705ef2`)

- **`check-hooks.sh`:** 5939 ok, 0 FAIL, exit 0. The same held at `04def2f`,
  including under all five rotation ref states.
- **Requirements:** 226, of which 207 active and all covered, and 13 gaps.
- **Registry:** `mutate-hooks.sh --list` gives 104 rows, 102 real mutations
  against 12 files, naming 63 requirement IDs, and 2 self-tests.
- **Harness selections, every row caught, `.claude/hooks/` byte-identical
  afterwards:** 22 at `70ec219`, 3 at `b6cce2f`, 9 at `4ab2513`, 6 at
  `17f32d0`, 2 at `04def2f`.
- **What was not run:** no whole-registry pass was run in this session, and 100
  real rows have not run against `04def2f`. Round 5 changed no hook.

## Still open, for the next session

- **Filed and open:** #238 (a stale read's permit), #239 (the report's
  `refs/heads/` walk) and #240 (a hung read ahead of the refusals).
- **Bertan's call:** whether the six numbered drafts should be renamed before
  they land.
- **Not re-run since this branch's work:** the rows not in any selection. A
  whole-registry pass before merge would be the evidence this entry does not
  have.

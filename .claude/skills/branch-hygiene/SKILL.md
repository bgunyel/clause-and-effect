---
name: branch-hygiene
description: Report whether the active dev branch is ready to rotate and what branches are stale, and hold Bertan's two procedures - rotating the dev branch, and sweeping merged worktree branches and the worktrees standing on them. Use after a dev-NN pull request lands in main, after a worktree branch's pull request merges, or when branches beyond main, one active dev branch and the worktree branches in flight against it are lying around. Both procedures are Bertan's; an agent runs only the read-only half and reports what it found.
---

# Branch hygiene

At any time this repository holds `main`, exactly one **active dev branch**
named `dev-NN`, and however many **worktree branches** are in flight against it.
Work never lands on `main` directly — only through a pull request from the
active dev branch — and an agent's work reaches the active dev branch the same
way, by a pull request from the worktree branch it was done on. `CONTEXT.md`
defines all three terms.

When that pull request into `main` is merged, the dev branch has served its
purpose and is rotated: the next branch takes the next number, and the merged
one is deleted from both the local repository and the remote.

**Rotation is a reserved act, and so are the sweep's removals.** Rotating the
dev branch, advancing the active dev branch on the remote, and removing a
worktree or deleting a worktree branch are each reserved. `CONTEXT.md`'s
*reserved act* entry holds the list; this file cites it rather than counting it,
so that a number here cannot go stale while the list grows there. What it makes
Bertan's is every step of either procedure that changes something — the whole
of the rotation below, and step 2 of the sweep.
`.claude/hooks/no-git-push.sh` refuses both of the pushes a rotation needs — the
first push of `dev-NN+1`, and the remote deletion of `dev-NN` — from anywhere,
correctly. Issue #41 considered carving a hook exception for this skill and
rejected it: the exception would reopen the wholesale and deletion forms that
PR #35 closed, for a procedure run every few weeks. Bertan runs the procedure
from his own terminal, where no hook applies.

An agent keeps the half that is genuinely useful and changes nothing: confirm
from the remote that the merge actually happened, and report what is stale.

## What an agent does

Both steps are reads. Report the answers and stop — do not check out, create,
push or delete anything, and do not offer to.

### 1. Confirm the merge really happened

Never take "the merge command ran" as evidence. Ask the remote:

```bash
gh pr view <PR#> --json state,mergedAt,headRefName --jq '{state,mergedAt,headRefName}'
```

`state` must be `MERGED` and `mergedAt` must be non-null. If it says `OPEN` or
`CLOSED`, there is nothing to rotate, and say so plainly: rotating on a
closed-without-merge pull request would discard the work.

### 2. Report what is stale

Part of this now runs on its own. `.claude/hooks/report-stale-branches.sh` is a
`SessionStart` hook that does the pruning fetch and reports stale branches and
the worktrees standing on them — the read-only half of this step, and nothing
else: it removes nothing, which is why it is named `report-` and not `sweep-`.
Its output is already in the session; read it before running the commands below,
and run them for what it does not cover — the pull request state, which needs
`gh`, and the last commit dates.

**The sweep** below is the other half — what acts on that report. It is
Bertan's, for the reason the rotation is, and an agent that has produced the
report stops there.

That fetch is also what arms `.claude/hooks/no-work-on-stale-branch.sh`, which
refuses a commit on a branch whose work is over. Both read remote-tracking refs,
so both are exactly as fresh as that fetch; when the report says the fetch
failed, neither detector is armed for that session.

```bash
git fetch --prune
git branch -a
gh pr list --state all --limit 30 --json number,headRefName,state,mergedAt \
  --jq '.[] | "\(.headRefName)\t\(.state)"'
```

Stale is a branch whose work is over: a `dev-NN` other than the active one, or a
worktree branch whose pull request is merged or closed. A worktree branch with an
open pull request is **not** stale — several open at once is the ordinary state
of this repository, not drift. That is what the invariant at the top of this file
already says, and it is the half of it most easily read as a mess to tidy.

**A worktree branch with no pull request at all is neither, and saying which it
is takes more than this skill can see.** A branch freshly cut for work not yet
started and a branch abandoned after a rotation are both branches with no pull
request, and ahead/behind does not separate them: a fresh one cut before the dev
branch moved is `ahead == 0`, and an abandoned one carrying a commit of its own
is `ahead > 0`, so the count that would condemn the first exonerates the second.
Only whoever cut it knows. Report it by name with its ahead/behind and its last
commit date, call it unclassified rather than stale, and stop — the *reserved
act* entry in `CONTEXT.md` says what to do where nothing enforces.

Two more things to name in the report rather than act on:

- **Open pull requests against `dev-NN`.** Deleting a base branch closes the
  pull requests that target it, so a rotation waits until they are merged or
  retargeted. Say which ones are open.
- **A branch that was never merged.** Its commits exist nowhere else. Report it;
  losing them should be a decision, not a side effect.

## Bertan's procedure

Run from a terminal, where no hook applies. Each step's verification is what
makes the next one safe.

### 1. Confirm the merge, and that nothing is in flight

The two reads above, if an agent has not already run them: `state` is `MERGED`
with a non-null `mergedAt`, and no pull request is open against `dev-NN`.

### 2. Move to main and pull

```bash
git checkout main
git pull
```

Confirm the merge commit is present and local `main` matches the remote:

```bash
git log --oneline -1
git status -sb | head -1
```

### 3. Create the new branch

The new branch is the merged branch's number plus one, zero-padded to two
digits: `dev-01` merged → create `dev-02`; `dev-09` merged → create `dev-10`.
Derive the number from the branch that was merged, not from whatever happens to
exist locally:

```bash
git checkout -b dev-NN+1
git push -u origin dev-NN+1
```

Verify you are on it before going any further — step 4 cannot delete the branch
you are standing on, and a failed checkout would otherwise turn the next command
into an attempt to delete your own working branch:

```bash
git branch --show-current
```

### 4. Delete the merged branch, locally then remotely

```bash
git branch -d dev-NN
git push origin --delete dev-NN
```

Use `-d`, never `-D`. The lowercase form refuses to delete a branch whose
commits are not reachable from the current HEAD, which is a genuine safety
check: if it refuses, the branch is not merged the way you believe it is, and
forcing it would silently discard commits.

The one legitimate exception is a **squash or rebase merge**, where `main`
carries the changes under different commit hashes and `-d` refuses even though
nothing would be lost. Confirm that is the case before reaching for `-D`:

```bash
gh pr view <PR#> --json state,mergeCommit --jq '{state,mergeCommit}'
git log --oneline main | head -5
```

### 5. Verify the invariant holds

```bash
git branch -a
git fetch --prune
```

`main`, the new dev branch, and any worktree branch still in flight — nothing
else. Prune the remote-tracking references left behind by the remote
delete.

## What must be true at the end

- `main` contains the merge commit and matches the remote.
- The new `dev-NN+1` branch exists, is checked out, is based on the updated
  `main`, and is on the remote.
- The merged `dev-NN` is gone from the local repository and from `origin`.
- Every other branch present is a worktree branch, and no pull request is left
  pointing at the deleted `dev-NN`: each was merged before the rotation or
  retargeted to `dev-NN+1` after it. Whether each of those is still in flight or
  merely not yet swept is the sweep's question, not the rotation's.

## The sweep

The local half of a worktree branch's end, and the counterpart of the remote
half `delete_branch_on_merge` performs automatically. `CONTEXT.md`'s *worktree
branch* entry states the lifetime this enforces: a worktree branch exists for
one pull request, and the worktree that produced it is not reused afterwards.

Also Bertan's. Removing a worktree is one of the acts that entry names, which is
why `.claude/hooks/report-stale-branches.sh` names what is over and removes
nothing, and why its name is `report-`.

**Cadence: manual, and unscheduled.** Nothing runs this and nothing reminds
anyone to. That is a deliberate position rather than an omission: a merged
worktree branch left lying about locally costs nothing except a line in the
report, and the one way it could cost something — work committed onto it after
its pull request merged — is refused by
`.claude/hooks/no-work-on-stale-branch.sh` whether or not anyone has swept. So
this is run when the report has accumulated enough to be worth clearing, and a
rotation is the natural moment: every branch in flight was merged or retargeted
before it, so the report just after one names very nearly the whole backlog.

Read the two hook headers that cite the sweep in that register. They name a
procedure that is written and is run by hand — not one that has already
happened.

Run from a terminal, where no hook applies.

### 1. Take the list from the report, and act only on the merged

The report classifies three ways and exactly one of the three is the sweep's.

- **stale** — a worktree branch whose pull request is merged or closed. These
  are the sweep's, and only these.
- **clear** — a worktree branch with an open pull request. It is in flight.
  Several at once is the ordinary state of this repository, not drift.
- **unclassified** — a branch with no pull request at all. A branch freshly cut
  for work not yet started and a branch abandoned after a rotation read
  identically, and ahead/behind does not separate them; the reasoning is at the
  end of *Report what is stale* above. Leave every unclassified branch alone.
  Sweeping one deletes work that was about to start.

Confirm from the remote rather than from the report, the same read the rotation
opens with — the report's classification is as fresh as its fetch, and a pull
request merged or closed since then is a branch it has not reclassified:

```bash
gh pr list --state all --limit 30 --json number,headRefName,state,mergedAt \
  --jq '.[] | "\(.headRefName)\t\(.state)\t\(.mergedAt)"'
```

A branch whose pull request is `CLOSED` rather than `MERGED` is stale by the
same definition and is **not** swept on that evidence alone: its commits exist
nowhere else. Report it, decide, and only then remove it.

### 2. Remove the worktree, then the branch

In that order, and the order is not a preference. A linked worktree holds its
branch checked out, and git refuses to delete a branch a worktree is standing
on — `cannot delete branch '<name>' used by worktree at '<path>'` — so reaching
for the branch first simply fails, in the direction that leaves a half-swept
pair behind.

```bash
git worktree list
git worktree remove .claude/worktrees/<name>
git branch -d <branch>
```

`git worktree remove` refuses a worktree holding uncommitted changes or
untracked files — `'<path>' contains modified or untracked files, use --force
to delete it`. Treat that refusal as `-d`'s: it is saying there is something
there nobody has looked at. Look before reaching for `--force`.

Use `-d`, never `-D`, for the reason step 4 of the rotation gives — the
lowercase form refuses a branch whose commits are not reachable from HEAD, so a
refusal here means the pull request did not merge the way the report believes.
The squash-or-rebase exception named there applies unchanged, and so does its
remedy: confirm the merge commit with `gh pr view` before forcing anything.

### 3. Verify, and prune what step 2 could not

```bash
git worktree prune
git fetch --prune
git branch -a
git worktree list
```

`git worktree remove` cleans up its own metadata, so `git worktree prune` is not
here to finish step 2. It is for the other way a worktree ends — a directory
deleted by hand, which leaves an administrative entry behind that `git worktree
list` still reports.

There is no `git push origin --delete` in this procedure.
`delete_branch_on_merge` has already taken the remote half, and if it had not,
`.claude/hooks/no-git-push.sh` would refuse the deletion form anyway.

What must be true at the end: every branch the report called stale is gone
locally, every worktree that stood on one is gone, every unclassified branch is
untouched, and `git worktree list` names no worktree without a branch.

## Notes

- Worktrees fork from the current HEAD (`worktree.baseRef: head` in
  `.claude/settings.json`), so every worktree made after a rotation branches
  from the new dev branch. One made before it does not, which is the second
  reason a rotation waits for the branches in flight.
- Rotate only after a merge, not after each session. A dev branch spanning
  several sessions is normal; two dev branches at once is not.
- Push a worktree branch with `git push -u origin <branch>` the first time, as
  the rotation pushes `dev-NN+1`. Without the upstream, a merged branch whose
  remote half `delete_branch_on_merge` has removed is indistinguishable from one
  that was never pushed — both read as having no upstream, and the `[gone]` that
  says *this branch had a remote and lost it* never appears.

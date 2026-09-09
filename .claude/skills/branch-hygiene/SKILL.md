---
name: branch-hygiene
description: Report whether the active dev branch is ready to rotate and what branches are stale, and hold Bertan's procedure for the rotation itself. Use after a dev-NN pull request lands in main, or when branches beyond main, one active dev branch and the worktree branches in flight against it are lying around. The rotation is Bertan's; an agent runs only the read-only half.
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

**Rotation is a reserved act.** Rotating the dev branch is one of the four acts
`CONTEXT.md` names, and advancing the active dev branch on the remote is
another, so every step of this that changes anything belongs to Bertan.
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

```bash
git fetch --prune
git branch -a
gh pr list --state all --limit 30 --json number,headRefName,state,mergedAt \
  --jq '.[] | "\(.headRefName)\t\(.state)"'
```

Stale is a branch with nothing in flight on it: a `dev-NN` other than the active
one, or a worktree branch whose pull request is merged or closed. A worktree
branch with an open pull request is **not** stale — several open at once is the
ordinary state of this repository, not drift. That is what the invariant at the
top of this file already says, and it is the half of it most easily read as a
mess to tidy.

Two things to name in the report rather than act on:

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
  retargeted to `dev-NN+1` after it.

## Notes

- Worktrees fork from the current HEAD (`worktree.baseRef: head` in
  `.claude/settings.json`), so every worktree made after a rotation branches
  from the new dev branch. One made before it does not, which is the second
  reason a rotation waits for the branches in flight.
- Rotate only after a merge, not after each session. A dev branch spanning
  several sessions is normal; two dev branches at once is not.

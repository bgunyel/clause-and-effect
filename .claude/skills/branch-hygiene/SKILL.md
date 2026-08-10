---
name: branch-hygiene
description: Rotate to the next development branch after a PR is merged into main. Use immediately after a dev-NN branch lands in main via pull request, or whenever the repository has stale branches beyond main plus one active dev branch. Covers checkout main, pull, create dev-NN+1, and delete the merged branch locally and remotely.
---

# Branch hygiene

This repository holds **exactly two branches at any time**: `main`, and one
active development branch named `dev-NN`. Work never lands on `main` directly —
only through a pull request from the active dev branch.

When that PR is merged, the dev branch has served its purpose and is rotated:
the next branch takes the next number, and the merged one is deleted from both
the local repository and the remote.

## When this applies

Apply **after a PR from `dev-NN` into `main` has been merged**, and not before.
Also apply when the repository has drifted — any branch other than `main` and
the single active dev branch is stale and should be removed.

Do **not** apply while a PR is open, in review, or closed-without-merge. The
delete step is unrecoverable from the local repository alone, so the merge is
the precondition for the whole procedure, not just the last step.

## The naming rule

The new branch is the merged branch's number plus one, zero-padded to two
digits. `dev-01` merged → create `dev-02`. `dev-02` merged → create `dev-03`.
`dev-09` merged → create `dev-10`.

## Procedure

Run these in order. Each step's verification is what makes the next one safe.

### 1. Confirm the merge really happened

Never take "the merge command ran" as evidence. Ask the remote:

```bash
gh pr view <PR#> --json state,mergedAt,headRefName --jq '{state,mergedAt,headRefName}'
```

`state` must be `MERGED` and `mergedAt` must be non-null. If it says `OPEN`
or `CLOSED`, stop — there is nothing to rotate, and deleting the branch would
discard the work.

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

Derive the number from the branch that was merged, not from whatever happens to
exist locally:

```bash
git checkout -b dev-NN+1
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

The repository should now show `main` and the new dev branch, and nothing else:

```bash
git branch -a
```

Prune any remote-tracking references left behind by the remote delete:

```bash
git fetch --prune
```

## What must be true at the end

- `main` contains the merge commit and matches the remote.
- The new `dev-NN+1` branch exists, is checked out, and is based on the updated
  `main`.
- The merged `dev-NN` is gone from the local repository and from `origin`.
- `git branch -a` lists `main` and `dev-NN+1` only.

## Notes

- The new branch has no upstream until its first push. Use
  `git push -u origin dev-NN+1` the first time, plain `git push` after that.
- Rotate only after a merge, not after each session. A branch spanning several
  sessions is normal; several branches open at once is not.
- If a stale branch turns up that was never merged, do not delete it silently.
  Its commits exist nowhere else — report it and let the decision be made
  deliberately.
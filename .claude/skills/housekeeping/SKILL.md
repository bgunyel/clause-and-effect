---
name: housekeeping
description: Print the exact housekeeping commands this repository needs right now — the branch-hygiene sweep of merged worktree branches and their worktrees, pruning of worktree entries whose directory is gone, and the dev-branch rotation when it is due — filled in with real names and paths, for Bertan to run. Runs nothing. Use when asked for housekeeping commands, cleanup commands, what to sweep, or whether the dev branch is ready to rotate.
---

# Housekeeping commands

Run the generator and relay what it prints:

```bash
bash .claude/skills/housekeeping/housekeeping-commands.sh
```

Then stop. Every command it prints is a *reserved act* in `CONTEXT.md` —
removing a worktree, deleting a worktree branch, rotating the dev branch — so
the output is for Bertan's own terminal, where no hook applies. Do not run any
of it, and do not run it "just the safe part".

## What to relay

Show the output as one fenced `bash` block, unchanged. Every line that is not a
command starts with `#`, so it pastes whole. Above it, in a sentence or two,
say what it found: how many branches it sweeps, what it held back and why, and
whether a rotation is due. It prints those reasons itself; do not re-derive
them.

Exit status 1 means it declined to produce a plan — the fetch failed, or a pull
request read failed — and the `#` lines say which. It prints no command then,
not even the part it could have worked out. Report that as *could not tell*,
never as *nothing to do*.

## Why it is a script and not a procedure

Which worktree branch is stale is decided once, by
`.claude/hooks/report-stale-branches.sh`, and the generator reads that report's
lines rather than re-deriving them. What it adds is only the checks a person
would make before removing something: whether a lock's session is still alive,
whether a worktree holds uncommitted files, whether a branch is checked out in
the main checkout, and whether a dev branch may be deleted. The script's header
states each rule and which way it errs when it cannot tell — always toward
printing no removal. `.claude/hooks/check-hooks.sh` drives it against a fixture
repository and executes the plan it prints.

A dev branch is deleted on the same four conditions whether it is the active one
being rotated or one the report calls *rotated past*: its newest pull request
into `main` merged, its local and remote copies contained in `origin/main`,
nothing open against it, and not checked out in a worktree the plan cannot move
off it. A branch is *rotated past* as soon as a higher `dev-NN` is pushed, which
can be before its own pull request into `main` has merged.

What it will not print, by design:

- a command for a branch whose pull request **closed without merging** — its
  commits may exist nowhere else, so it is listed as a decision;
- anything for an **unclassified** branch — freshly cut and abandoned read the
  same, and only whoever cut it knows — including an unlock of its worktree;
- a removal for a worktree **locked by a live session**, or holding
  **uncommitted files**, or whose status cannot be read;
- a delete for a dev branch failing any of the four conditions above.

`git worktree prune` is repository-wide. When the plan prints it, it also clears
the entry of any *unlocked* worktree whose directory is already gone, whatever
branch that entry held. The branch itself is untouched, and a locked entry is
skipped.

## When a printed command refuses

That refusal is the safety check working, as the sweep in `branch-hygiene`
explains. `git branch -d` saying *not fully merged* usually means the checkout
it runs in lags `origin` — pull the dev branch first — and never means reach
for `-D`. `git worktree remove` refusing means files appeared since the plan
was printed; re-run the generator.

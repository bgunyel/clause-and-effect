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

Exit status 1 means it declined to produce a plan — the fetch failed, or pull
requests could not be read — and the `#` lines say which. Report that as
*could not tell*, never as *nothing to do*.

## Why it is a script and not a procedure

Which branch is stale is decided once, by
`.claude/hooks/report-stale-branches.sh`, and the generator reads that report's
lines rather than re-deriving them. What it adds is only the checks the sweep in
the `branch-hygiene` skill asks a person to make before removing something:
whether a lock's session is still alive, whether a worktree holds uncommitted
files, whether a branch is checked out in the main checkout, and whether the
rotation's three preconditions hold. The script's header states each rule and
which way it errs when it cannot tell — always toward printing no removal.

What it will not print, by design:

- a command for a branch whose pull request **closed without merging** — its
  commits may exist nowhere else, so it is listed as a decision;
- anything for an **unclassified** branch — freshly cut and abandoned read the
  same, and only whoever cut it knows;
- a removal for a worktree **locked by a live session**, or holding
  **uncommitted files**.

## When a printed command refuses

That refusal is the safety check working, as the sweep in `branch-hygiene`
explains. `git branch -d` saying *not fully merged* usually means the checkout
it runs in lags `origin` — pull the dev branch first — and never means reach
for `-D`. `git worktree remove` refusing means files appeared since the plan
was printed; re-run the generator.

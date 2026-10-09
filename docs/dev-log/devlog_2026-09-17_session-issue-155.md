# 2026-09-17 · session issue-155 — #155: a `gh` in the fixture farm, so `GH-108.6` is evidence everywhere

**Branch** `worktree-issue-155-stub-gh-into-farm`, cut from `origin/dev-05` at
`897bdff` and proposed into `dev-05`. Worked unattended by an AI assistant.
**Check suite 3786 → 3799 results, all passing — and the same 3799 on a PATH
built with `gh` removed**, which is the whole point of the change. One
requirement, `GH-155.1`, eight checks. One row added to the mutation registry,
29 → 30. Two latent defects found in the assistant's own work, one of them by
mutation and one by the review pass; both were in the destructive direction.

## What the issue asked, and the shape of it

`check-hooks.sh` builds the `gh`-less environment of its #108 section as the #95
symlink farm minus `gh`. On a machine with no `gh` at all that subtraction
removed nothing, and the first version of the fixture guard — which demanded a
one-name difference — aborted the whole suite there, skipping every section below
it including #104's coverage derivations. Bertan's review of PR #150 found that,
and the fix that answered it made the guard *tolerate* a no-difference copy.

The tolerance was correct, and it was disclosed in a paragraph beside the guard
rather than hidden. #155 was filed in the re-review of that same pull request as
an explicit non-finding — *"Not a finding — the current state is correct and
honest about itself"* — because the disclosure bought machine-independence with
evidence. On a host with no `gh`, the `gh`-less environment **is** the ordinary
environment, so the `GH-108.6` checks that run under it asserted their verdicts
twice rather than once, and were evidence about `gh` on none of the machines that
had none.

## What was done

The farm is given a `gh` where it is built — the host's, or a stub the suite
synthesises — so the guard requires the one-name difference unconditionally and
the tolerance is gone rather than documented. The comment that disclosed the
doubled assertion now argues instead why a stub is right for `gh` and wrong for
`git`: `gh` is a dependency of no hook, so a name is all the fixture wants of it,
while `git` runs throughout this suite, so a farm with no `git` is a machine the
suite cannot run on and a fake `git` would answer the very questions the hooks'
verdicts are read off. The guard still treats the two alike, because the rule is
the same — the farm minus exactly this one name — and it now says which of its
two messages belongs to which cause.

**The stub alone does not fix the evidence, and the issue's acceptance criteria
do not say so.** `GH-108.6`'s `gh`-on-PATH reference was `plain`, the invoker's
own PATH, which on a `gh`-less host is itself a `gh`-less environment: the pair
went on asserting the same thing twice. So the farm became a row of its own in
that loop, and of `ENV_STATUS_CASES` with it, by that section's own rule that a
case driven anywhere in it is driven there — 100 → 110 status cases.

`GH-155.1` carries the fixture rule, and asks it of this machine **and** of the
machine this is not. What decides the fixture is whether the host's PATH held a
`gh`; where it did there is nothing to synthesise, so a check that only looked at
the farm as built would be green on any machine with `gh` installed and would say
nothing whatever about the machine that found the defect. So that machine is
built: a farm with `gh` taken out stands in for a host that never had one, the
same synthesis runs against it, and the one-name property is asserted there too.
That is PR #150's manual reproduction — *"reproduced by building a farm with no
`gh` in it"* — written as a check instead of as a sentence in a comment.

One of the eight reads the suite's own text. On a host that *has* `gh` the
synthesis call is a functional no-op, so deleting that one line leaves every
other check here green while the machine-independence reverts to an accident of
the invoker's PATH. That is #84's direction one level out again, and the text
read is the only thing that can see it. It reads the *range* the farm is built in
rather than the whole file, because a literal asserted of the file would match
the check's own argument and pass with the call gone.

## Two defects the work found in its own code

**A symlink write that could have destroyed the invoker's `gh`.** Every entry in
the farm is a symlink to a host binary, so `>` on one writes *through* it. With
the synthesis's early return mutated away, the write targeted `/usr/bin/gh` and
was refused only because that file is root's; a user-writable install — `gh` in
`~/.local/bin`, or a Homebrew one — would have been truncated. The assistant
found this by running the mutation, not by reading the line it had just written.
An unlink now precedes the write.

Its comment records something the suite cannot: **no check covers that unlink,
and removing it is a measured survivor.** It is reachable only when the early
return above it is wrong, so a suite in which that return is right cannot tell
the two spellings apart. What the pair of mutations says is the whole of what is
known — with the return gone and the unlink present the host's `gh` is left alone
and a named check goes red; with both gone the suite aborts at the fixture guard
having tried to truncate a file it does not own.

**A `says` check standing for less than its label claimed.** The refusal-text
check read the fragment `Bertan's call` against the `gh`-less PATH and against
nothing else, while its label said the refusal was *"word for word the one gh on
PATH gets"*. Two refusals differing in every other word passed it. Worse, the
assistant's first draft of this branch added a *second* `env_says` carrying the
same fragment, which made the pair look like a comparison while still comparing
nothing — the identical defect this branch argues against a hundred lines
earlier, where the stub's own sentence is pinned whole. Both sides now pin the
refusal whole, as a literal written from `no-pr-decisions.sh` and verified
byte-exact against a run, and the two stderrs are read and compared to each
other — guarded by a check that both were read at all, since two hooks that
crashed saying nothing compare equal, which is the check passing on the case it
exists to catch. Found by the review pass, not by the suite.

A third, smaller one from the same pass: the second symlink write, at the
host-`gh` fixture, was safe only because of which directory the `cp -a` above it
had copied, and that load-bearing choice carried no comment at all. It now
unlinks too, so it is safe by construction rather than by provenance.

## The `gh` these checks run

Two lines in `GH-155.1` execute a `gh` rather than handing its text to a hook,
which nothing else in this suite does. They run `gh --version` and not
`gh pr merge 5`: the stub ignores argv, so both establish the same two things,
and what the checks rest on is that PATH names one directory holding a stub. Were
that ever wrong, the harmless spelling turns both checks red, where the other
would have merged a pull request. This repository's own lesson is that a command
run to learn something once created a real release.

## Measured

`check-hooks.sh`: **ALL CHECKS PASSED, 3799 results** — 3786 before this branch —
on the ordinary PATH **and** on a PATH built by symlinking every executable on
the invoker's PATH except `gh`. The same count on both, which is the property
that made #150's fix verifiable in the first place. 175 requirements, 157 of them
active, 112 off the both-directions rule.

Mutation, **by hand**, for the fixture rule. `mutate-hooks.sh` cannot hold it:
that harness refuses `check-hooks.sh` as a target by name, because the suite that
runs is always the repository's, so an edit to a copy would be read by the
suite's text checks and executed by nothing. Each edit was applied to the file
that runs and restored from a per-file backup — never from git, which in a
throwaway script eats whatever else is uncommitted — and the file was verified
byte-identical after. All four were re-run against the committed code, and the
committed file's sha256 matches the backup they were measured against.

| edit | outcome |
|---|---|
| the farm build stops calling the synthesis | **caught** — 1 FAIL, the text read, and nothing else |
| the synthesis writes its stub off the farm's PATH | **caught** — 4 FAIL |
| the synthesis overwrites a host-provided `gh` | **caught** — 1 FAIL, the host-`gh` check |
| the unlink before the write removed | **survived**, for the reason recorded beside it |

The third is the one that, before the unlink existed, aborted the suite at the
fixture guard instead of failing a named check.

Mutation, **registered**, for the hook rule the fixture exists to establish:
`pr-hook-reads-gh-off-the-environment` makes `no-pr-decisions.sh` permit when
`gh` is off PATH. Run as a named selection, baseline plus one: caught, red in
`GH-108.6` and in nothing else, `.claude/hooks/` byte-identical after. The
registry is 30 rows — 28 real mutations against 6 files, naming 39 requirement
IDs, and 2 self-tests.

**That row is not evidence about what #155 changed**, and the entry in
`requirements.md` says so rather than implying otherwise: `GH-108.6`'s `gh`-less
fixture held no `gh` on either kind of host, so the row would have been caught
before this branch as well. It is a mutation `GH-108.6` had none of, and it is
the nearest the harness can come to the rule this issue establishes.

## A mistake worth writing down

The assistant committed while the hand-mutation driver had a mutation applied to
`check-hooks.sh` in place, and `git add -A` staged the mutated file: the early
return the synthesis rests on was committed as `:`. The working tree was correct
minutes later, because the driver restores from its backup, so nothing in the
tree or in any measurement was wrong — only the commit, and only until the next
`--amend`. It was caught by reading `git status` and asking why a file was
modified at all, and confirmed by comparing the committed file's sha256 against
the driver's backup. A driver that edits the file that runs and a `git add` are
safe apart and not together; the check that catches it is comparing the commit's
content against the backup the measurements were taken from, which is now part of
the record above.

## Left open

`GH-155.1`'s checks sit inside the `=== issue #108 ===` section heading, beside
the fixture they are about. A `section` of their own would reset the tag for
everything after it and file #108's remaining checks under a #155 heading, which
is worse; the block's own heading line names #155 instead.

`--list`'s four restated counts in `mutate-hooks.sh`'s header moved again with
this branch — 27 → 28 real mutations, 38 → 39 requirement IDs, 156 → 157 active
requirements, and the run count. That is the fourth day running that one of those
numbers has moved, and #148 is still the issue that takes them out.

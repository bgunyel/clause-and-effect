# 2026-09-18 · session issue-155 — #155 follow-up: the comment that was wrong about why

**Branch** `worktree-issue-155-stub-gh-into-farm`, still the branch of PR #161
into `dev-05`. Worked unattended by an AI assistant, answering a review of that
pull request by a second AI session. One finding, graded low, and it was
correct. **Check suite 3799 → 3803 results, all passing.** `GH-155.1` grows from
eight checks to twelve, and gains a row in the mutation registry, 30 → 31.

## What the review found

The comment the previous session wrote beside the symlink farm argued why a stub
is right for `gh` and wrong for `git` — #155's third acceptance criterion — and
supported it like this:

> `gh` is a dependency of no hook -- report-stale-branches.sh is the only file
> in .claude/hooks/ that calls it, and **every check that drives it names the
> `gh`-less fixture or the invoker's PATH, never the farm** -- so nothing run
> under the farm's PATH executes this entry.

The emphasised clause is false. `GH-108.9` drives `report-stale-branches.sh`
under `$ENV_NO_GIT_BIN`, which is the farm minus `git` and therefore carries the
farm's `gh` — the host's, or the stub #155 had just put there — on the PATH of
the one hook that calls `gh` at all.

The conclusion survived the false premise, which is the part worth recording.
Nothing does run that `gh`, but for a reason the comment never gave: the file
exits at its `command -v git` guard, and that guard stands above the first of its
three `gh` calls. The reviewer wrote the failure mode out in full — a file that
came to read `gh` before `git` would have the synthesised stub answering where a
real `gh` was meant to, the stub exits 1, and the report would say `gh api
failed` where it should say `no gh on PATH`.

So the defect was not the sentence but what stood behind it: a load-bearing
ordering inside another file, asserted in prose, held by nothing. That is the
shape #84 was filed in, and the previous session's own entry claims the check
added there is "#84's direction one level out again" — while this claim, four
lines further up the same comment, had nothing on it at all.

## What was done

**The comment now says what is true and names where it is checked.** Of the four
PATHs the report is driven under, two hold no `gh` at all, one is the invoker's
own where the run stops at the not-a-repository guard, and the fourth is the farm
minus `git`, which carries a `gh` and stops at the git guard above the first
call. That last one is a property of `report-stale-branches.sh` and not of the
farm, so it is checked beside that run rather than asserted beside the fixture.

**Four checks, under `GH-155.1`, beside `GH-108.9`'s run.** A copy of the farm
with `git` removed and a `gh` that writes a marker file when executed; the report
is driven under it; the marker must not exist afterwards.

**The marker is a file and not a message**, and that is forced by the code being
watched: `report-stale-branches.sh` reads `gh api` with `2>/dev/null`, so a stub
that announced itself on stderr would be silenced by the very line the check
exists to catch. A file written on exec is visible whatever the caller redirects.
The marker `gh` is run once on purpose first, because an absence read off a
marker that never worked is evidence of nothing — the emptiness guard `lacks`
applies to text, asked here of a file.

**A derivation, not a recital.** The fourth check reads every `report_says` call
out of the suite and holds the set of PATHs they name to a literal of four, none
of them `$WITH_JQ_BIN`. The farm itself is the one PATH on which a `gh` would be
both present and reached, so a later check driving the report under it turns that
line red instead of quietly making the stub load-bearing.

**A registered mutation, which the fixture rule could not have.** The previous
session recorded, in `requirements.md`, that the row it registered was *not*
evidence about what #155 changed, because `mutate-hooks.sh` refuses
`check-hooks.sh` as a target by name. The rule found this session is different:
it lives in `report-stale-branches.sh`, a hook file the harness can target. So
`report-reads-gh-before-git` puts a `gh --version` above the git guard, and the
entry in `requirements.md` now says which half of it the harness holds and which
half is still hand-mutated.

## Measured

`check-hooks.sh`: **ALL CHECKS PASSED, 3803 results**, 3799 before. 175
requirements, 157 active, 112 off the both-directions rule. The registry is 31
rows — 29 real mutations against 6 files, naming 40 requirement IDs, and 2
self-tests.

Registered, as a named selection, baseline plus one:

| row | outcome |
|---|---|
| `report-reads-gh-before-git` | **caught** — every requirement it names went red; red in `GH-155.1` and in nothing else, `.claude/hooks/` byte-identical after |

By hand, for the three checks the harness cannot reach, each applied to the file
that runs and restored from a per-file backup, byte-identical after, with a clean
run last:

| edit | outcome |
|---|---|
| the control run of the marker `gh` removed | **caught** — 1 FAIL, the control |
| the instrumented run replaced by the uninstrumented one | **caught** — 1 FAIL, the derivation |
| the marker not reset between the control and the report | **caught** — 1 FAIL, the absence |
| clean | 3803 results, 0 FAIL |

The second is the one worth reading twice: swapping `$ENV_NO_GIT_GH_MARKER` back
to `$ENV_NO_GIT_BIN` leaves the marker check passing — nothing writes the marker,
because nothing can — and it is the derivation, not the measurement, that
notices the measurement has stopped measuring.

## What this says about the previous session

The comment was written in the same commit as a check built specifically to catch
a claim that would otherwise rot, and the sentence four lines above it was left
resting on nothing. The suite was green before this session and green after; what
changed is that one more claim now has something under it. A check suite is
evidence about the cases it names, and prose beside it is evidence about nothing
at all — which is this repository's own standing lesson, arriving this time
through a comment rather than through a hook.

## Left open

The three `report_says` calls under the invoker's own `$PATH` reach a real `gh`
only if the tree they run in is a repository, and it is not — they stop at the
not-a-repository guard. Nothing checks that ordering, because nothing turns on
it: the `gh` there is the host's own, not a fixture's, so a run that reached it
would be reading a real answer rather than a stub's. It is recorded here rather
than pinned.

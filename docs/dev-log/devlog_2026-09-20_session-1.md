# 2026-09-20 · session 1 — #155 round two: two guards weaker than the prose beside them

**Branch** `worktree-issue-155-stub-gh-into-farm`, still the branch of PR #161
into `dev-05`. Worked unattended by an AI assistant, answering a second review
of that pull request by a separate AI session. Three findings: two accepted as
written, one accepted in substance and refused in its remedy. **Check suite 3803
→ 3807 results, all passing.** `GH-155.1` grows from twelve checks to sixteen.
No new requirement, no new registry row.

## Finding 1, graded medium — a derivation anchored where the calls sit today

The previous session ended by deriving, off the suite's own text, every PATH
`report-stale-branches.sh` is driven under, and holding the list to a literal of
four with the farm not among them. The comment beside it rested the stub's
safety on that derivation: *"a later check that drove the report under the farm
would turn this line red."*

It would not have. The derivation read

```
grep -o '^report_says "[^"]*"' …
```

and the `^` meant it saw only calls beginning a line. The suite already holds an
indented one — `drive_helper`'s `case`, at what is now line 8229 — and every
environment sweep in that section is written as an indented loop body, so the
shape the derivation could not see is the shape the section is written in. A
future check driving the report under `$WITH_JQ_BIN` from inside a `for` would
have been invisible, the literal-of-four would have gone on matching, and the
farm's `gh` stub would have become load-bearing with the line that exists to
catch that still green.

This is #84's direction one step further out, and it is the third time in this
branch's history that the question has been *how far around the thing being
derived to look*.

**What changed.** The derivation is now a function, `report_run_paths <file>`,
whose pattern skips leading whitespace. The anchor is kept rather than dropped,
and the reason is measured rather than assumed: dropping it outright makes the
pattern match **its own source line**, which was confirmed by running the
unanchored spelling over the file —

```
[^ $ENV_NO_GH_BIN $ENV_NO_GIT_BIN $ENV_NO_GIT_GH_MARKER $PATH $WITH_JQ_BIN //; s/
```

— three entries of which are text and not PATHs. That spelling goes red, which
is the safe direction, but for a reason that has nothing to do with the report.

The expected literal did not change: the indented call at 8229 names `$PATH`,
which the derivation already held. So the fix could not be shown by the checks
that existed, and a second check was written — the derivation driven over a
fixture whose only run is indented. Without the fix that check is the only thing
red.

## Finding 2, graded low — `command -v` answers a question about the calling shell

`farm_stub_gh` decided whether to synthesise a `gh` like this:

```
[ -n "$( PATH="$dir"; command -v gh )" ] && return 0
```

`command -v` resolves shell **functions** ahead of PATH, and bash imports
exported ones — `BASH_FUNC_gh%%` in the environment — into a non-interactive
script. On a host whose profile exports a `gh` wrapper, that test says the farm
holds a `gh` where it holds nothing: no stub is written, and the #108 fixture
guard, which **this branch made unconditional**, aborts the whole suite before
#104's coverage derivations are reached.

That is exactly the abort-on-some-machines failure #155 exists to remove,
reintroduced behind a rarer trigger, and the reviewer graded it low on the
strength of how rare. The grading is right and the class is not: this branch's
whole argument is that a fixture must be a fact about the directory and not an
accident of the invoker's environment, and this line asked the environment.

**What changed.** A `farm_has <dir> <name>` helper — `[ -x "$1/$2" ]`, a file
test — and every question this suite asks of a farm now goes through it: the
synthesis, the three `GH-155.1` `tok`s that read whether a farm holds a `gh`,
and **the guard**. The guard matters as much as the synthesis and was not in the
finding as filed: fixing only the synthesis leaves the same host aborting, one
line later, because a `gh` function resolves under the `gh`-less PATH too and
the one-name difference the guard demands reads as absent. The two are one rule
read twice.

Two checks were written for it. A farm built under a shell that defines and
exports a `gh` function, which must still get its stub — that is the finding
written as a fixture. And, because a guard whose failure is `exit 1` cannot be
driven from inside the run it would end, a `holds`/`lacks` pair over the guard's
text, pinning that it asks the directory and asks the calling shell nothing.

The `-x` spelling also makes the unlink inside the synthesis more reachable than
it was, not less: a dangling symlink is not `-x`, so it now falls through to the
write the unlink protects. That is the line recorded as a measured survivor, and
nothing about its status changed.

## Finding 3, graded low — accepted in substance, refused in its remedy

The registry row `pr-hook-reads-gh-off-the-environment` inserts
`command -v gh >/dev/null 2>&1 || exit 0` above the first rule in
`no-pr-decisions.sh`, and `mutate-hooks.sh` records it as *"caught, red in
GH-108.6 and in nothing else"*. The reviewer is right that the second half of
that sentence is this host's. On a machine with no `gh` — the machine #155 was
filed about — the inserted early exit fires for every check run under the plain
PATH and short-circuits `pr review`, `pr close`, the release allowlist, the base
rules and the api rules as well, so the run goes red across dozens of
requirements. The outcome stays `caught`, because `caught` is read off the IDs
the row names and is not exclusive, so nothing in the harness turns red to say
the sentence has stopped being true.

**The remedy offered was to qualify the claim or to move the anchor below the
rules it disables. The claim is qualified; the anchor is not moved.** A hook
that reads `gh`'s presence out of the environment reads it *before* it decides
anything — that is what the defect shape is. A row anchored below the rules it
currently disables would be a weaker mutation wearing the same name, and this
repository's rule for that case is to record what a measurement covered rather
than to reshape the measurement until the sentence is true everywhere.

While writing the qualification the assistant found that the header recorded
only **one** of #155's two rows, although both were measured and the second is
written up in the 2026-09-18 entry. It now records both, with the second's
host-independence stated — its `gh --version` is silent where there is no `gh`
and harmless where there is.

**The finding's citation of `requirements.md:1806` is wrong, and nothing was
changed there on account of it.** That file does not carry the exclusivity
claim; the sentence lives only in `mutate-hooks.sh`. It is also in the pull
request's body, which was corrected.

## Measured

`check-hooks.sh` **ALL CHECKS PASSED, 3807 results** (3803 before this round),
exit 0, on a host that has `gh`. 175 requirements, 157 active, 112 off the
both-directions rule — unchanged, since this round added no requirement.

Hand mutation, each edit applied to the file that runs, restored from one
backup, `sha256sum -c` clean after every one:

| edit | outcome |
|---|---|
| the derivation's anchor put back at column 0 | **caught** — 1 FAIL, the indented-run fixture and nothing else |
| the synthesis asks `command -v` again | **caught** — 1 FAIL, the exported-function fixture and nothing else |
| the fixture guard asks `command -v` again | **caught** — 2 FAIL, the `holds`/`lacks` pair over the guard and nothing else |

`#161` gains an entry in the *Citations that are not requirements* section,
which is what the suite's own `GH-104.3` demanded the moment a comment cited the
pull request number — the first run after the fixes failed on exactly that, and
on nothing else.

## What was not done

The same `command -v` shape is still in the `jq` fixture guard a few lines above
the farm's, where a host exporting a `jq` function would abort the suite the same
way. It predates #155, is outside this pull request's diff, and was left for the
reviewer to decide on rather than folded in — reported, not fixed.

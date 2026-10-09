# 2026-09-20 · session 6 — #158 round four: the suite's guarantee about itself, and a fix that was wrong until a row said so

**Branch** `worktree-issue-144-active-dev-base`, still proposed into `dev-05`, at
`2a52322`. **Check suite 5190 → 5196 results, all passing**; requirements 190,
173 active; mutation registry 63 → 64 rows, 62 real. No requirement was added and
the production hook was not touched: every finding this round was in
`check-hooks.sh`, which is the file that decides whether anything else is
evidence.

Worked by the assistant against the fourth review of PR #158, cited on this
branch as *the fourth review of PR #158* for the reason session 4's entry gives.

## A bare row survived, and it was this branch's own failure mode

`GH-144.4` says no row naming a `dev-NN` base is judged in the directory the
suite was started from. One was: a `#117` permitting row at `check-hooks.sh:2433`,
judging `/usr/bin/gh pr create --base dev-05` in `$SUITE_DIR`, which is this
repository, where `dev-05` is active today.

The review did not argue it. It added `refs/remotes/origin/dev-06` to a scratch
clone and ran the suite: **5190 green became one FAIL**, blaming a hook that was
right. That is the rot `GH-144.4` exists to stop, reproduced inside the pull
request that introduces the requirement, and it falsified the requirement's own
text and a sentence of the pull request body at the same time.

The assistant reproduced it before fixing anything, in a clone and never in the
shared repository — an extra `origin/dev-06` there would change `read_active_dev`
for every concurrent session and refuse their `--base dev-05`.

## The guard that should have caught it tested a weaker property

`PR_DEV_ROW_HARNESS` extracted the **harness word** and nothing else, so it
distinguished a named directory from an inherited one and stopped. `check_in
"$SUITE_DIR"` names a directory: it satisfied `holds … 'check_in'` and `lacks …
'check '` both.

The review asked for the derivation to be fixed **before** the row, or at least
for the strengthened derivation to be shown failing on the unfixed row, because a
derivation that passes either side of a fix is not evidence. That is the same
standard this branch applied to `GH-108.5` in its first commit, turned back on
it. The order was followed. With the directory argument read and held to a
literal, and the row still at `$SUITE_DIR`:

```
FAIL and the directory each one names is one of these, read off the rows themselves
       want |$ENV_DEV_NONE $ENV_DEV_TWO $ON_DEV $PR_NOISE $PR_ONE $PR_TEN $dir |
       got  |… $PR_TEN $SUITE_DIR $dir |
FAIL so none of them is judged in this repository, where dev-05 is active today
```

Then the row was moved, and both went green.

## The fix that was wrong, and the row that said so

This is the part of the session worth keeping, because the assistant made the
defect it had spent the round removing.

`GH-144.8`'s text claims six sites in the report name both hooks; four were
pinned. The assistant pinned the other two with `written` and registered a
mutation that deletes one clause. The mutation **survived**.

`written` is `grep -qF` over a whole file. The clause stands at six sites, so
deleting one leaves the literal present and the pin satisfied: a pin on a string
that occurs six times is evidence about no site at all. That is structurally the
same defect as `PR_DEV_ROW_HARNESS` reading the harness word instead of the
directory — a check whose subject is narrower than the claim beside it — made by
the assistant, in the same round, while fixing that one.

Nothing in the suite said so. The row did, and only because it deletes exactly
one clause rather than the five its sibling takes at once. The pins were replaced
by a derivation over the report's `echo` groups: scaffolding stripped, whitespace
collapsed — one of the six splits *"neither staleness"* from *"detector in"*
across two lines — and every message about a read that was not made or not
trusted must name `no-pr-decisions.sh` beside `no-work-on-stale-branch.sh`. All
three rows caught after that.

Two messages are deliberately out of scope: `merge settings: NOT READ`, whose
subject is a setting that arms the other guard's detectors and feeds no base
rule, and the `main ancestry` line, whose subject is that guard's own
ahead/behind test. Both correctly name one hook. A derivation sweeping them in
would be the correction applied one site too far, which session 5 recorded as the
same defect as one applied one site too short.

## A limit that is a limit, and not a gap

Whether the `GH-144.4` derivations can fail cannot be asked of the mutation
registry. `#107`'s harness mutates the hooks under judgment; `check-hooks.sh` is
in its `TOOLING` list and a row naming it is refused, because the harness **runs**
this file rather than judging it. A row putting the `$SUITE_DIR` spelling back
was written, registered, and refused by that guard — correctly.

So every `GH-144.4` derivation is in a class the registry cannot reach. This is
written where the derivations stand rather than smoothed over, and the substitute
is a measurement: the derivation was run against the unfixed row and went red,
and anyone can reproduce that by moving the row back.

## The rotation experiment

Run on the fixed tree, in a scratch clone, under five ref states:

| refs present | result |
|---|---|
| `origin/dev-05` alone | exit 0, 5196 ok, 0 FAIL |
| `dev-05` and `dev-06` — the rotation window | exit 0, 5196 ok, 0 FAIL |
| `dev-06` alone — the rotation completed | exit 0, 5196 ok, 0 FAIL |
| no `dev-NN` ref at all | exit 0, 5196 ok, 0 FAIL |
| `dev-09` beside `dev-10` — the version sort | exit 0, 5196 ok, 0 FAIL |

Identical under all five. The suite's verdicts no longer depend on what refs this
repository holds, which is what `GH-144.4` claims and what was not true before
this session. Three of the five states were not asked for and were added because
the review said a finding neither party had was worth more than a merge; none of
them found one.

## What was measured

- Check suite: **5196 results, exit 0**, under every ref state above.
- requirements.md: **190 entries**, 173 active, 173 covered, 12 marked a gap.
- Mutation registry: **64 rows**, 62 real against 7 files, naming 52 requirement
  IDs.
- `GH-144.8`'s three rows run twice: once finding the survivor, once after the
  derivation replaced the pins, all caught, `.claude/hooks/` byte-identical.

## What the next session inherits

The production hook has now survived four review rounds without a defect found in
it. What moved this round was the suite's guarantee about itself. The registry
rows outside this round's selections have not been run since the files they run
against changed, which is the standing state of that registry.

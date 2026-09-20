# 2026-09-20 · session 8 — #158 round six: the derived check earned its place on the first merge after it was written

**Branch** `worktree-issue-144-active-dev-base`, proposed into `dev-05`, merged a
third time at `7bea85f` (#109). **Check suite 5197 → 5398 results, all passing**,
and exit 0 with 0 FAIL under each of five ref states; requirements 190 → 196, of
which 178 active; mutation registry 64 → 77 rows, 75 real against 8 files. The
production hook was not touched, for the sixth round running.

## The merge found three unrecorded harnesses, and nothing else would have

Session 7 replaced `GH-144.4`'s text derivations with a pair that reads the run,
and left one thing assumed: that every harness records. That assumption was
written as a derived check — the set of functions whose body calls `hook_path`
compared with the set calling `judged` — rather than as a sentence.

`#109` added three harnesses this merge brought in: `every_hook`, `report_says`
and `says_first`. All three run a hook. None called `judged`. **No conflict
marker pointed at any of them**, because they are additions in regions neither
branch touched twice, and the suite would have been green with a `dev-NN` payload
judged in an unrecorded harness.

The check named all three. It had already found two on the run that introduced it
(`cap_timed`, `check_file`); it has now found three more on the first merge after.
A claim about twelve function bodies that finds five violations in two outings is
the opposite of decoration, and it is the whole argument for deriving an
assumption rather than asserting it.

## Two recorders in one file, kept apart on purpose

`#109`'s `ran` records which hook ran under which requirement. `#144`'s `judged`
records which directory judged which payload. `every_hook` deliberately feeds
neither `ran` nor `GH-109.4`, because a run derived from what `settings.json`
registers would make that row self-satisfying — PR #169's third review found
that, and it stands. It does feed `judged`, because the reason `GH-109.4` must
not read that loop is not a reason `GH-144.4` may skip it. The distinction is
written at the call rather than left for the next reader to reconstruct.

## Three stale literals, and a fourth that was the assistant's

The same class both previous merges produced. `#109` pinned the `gh api` arm's
refusal as it read before `#144` interpolated `BAD_BASE_WHY`; its list of silent
functions still named `is_dev_base`, renamed by `#144` to `may_propose_into`, and
did not name `api_bad_base` or `read_active_dev`. Neither side was wrong; the
pair was.

The fourth was the assistant's own: resolving the families-scope literal by
taking both sides whole duplicated `GH-139:transformation`, which both branches
carried. The literal caught it on the next run, which is what a literal is for.

## A finding reported from one run, withdrawn on six

The sixth review reported the five-state ok-count differing in one state — 5196
where the others gave 5197 — and escalated it to a claim that the table asserted
uniformity it did not have. The assistant's own five-state run on the same tip
returned 5197 in all five, one distinct value, which contradicted it. The review
then re-measured three times on each of two heads, did not reproduce 5196 once,
and **withdrew the finding**, saying plainly that it had reported a single run as
a fact — the same class it had handed this branch a round earlier.

It is recorded here because the correction it produced is better than the finding
would have been. **A count is a fragile carrier for the claim the table makes.**
It moves when a check is added, and a single anomalous run makes it look like it
moved when nothing did. What the table actually asserts is that no ref state
changes a verdict, and `exit 0` with `FAIL 0` says that and does not drift. The
table now carries the verdicts as the claim and the count as a freshness signal.

## What was measured

- Check suite on the merged tree: **5398 results, exit 0**.
- requirements.md: **196 entries**, 178 active, 178 covered, 13 marked a gap.
- Mutation registry: **77 rows**, 75 real against 8 files, naming 56 requirement
  IDs.
- Five ref states, **one run**: `dev-05` alone; `dev-05` beside `dev-06`; `dev-06`
  alone; no dev ref; `dev-09` beside `dev-10`. Every one exit 0, 0 FAIL, 5398 ok.

## What the next session inherits

The registry rows outside earlier selections have not been run since the files
they run against changed — `#109` added thirteen rows and this merge brought them
in unrun on this tree. The five-state experiment is still run by hand, for the
reason `GH-144.4` gives.

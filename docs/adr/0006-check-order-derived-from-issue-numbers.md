# The check suite's order is derived from the issue numbers

This decision supersedes one consequence of ADR 0004, the one about the
driver's list `SUITE_CHECKS`. The rest of ADR 0004 stands.

The driver no longer holds a hand-written list of the files it sources. It
derives the list with `suite_checks`, a library function, from what
`.claude/hooks/checks/` holds:

1. the unsplit file, `unsplit.sh`;
2. then every **issue file**, `GH-<n>.sh`, where `<n>` is digits with no leading
   zero, in ascending numeric order of `<n>`, so `GH-9.sh` comes before
   `GH-10.sh`;
3. then the end-of-run file, `end-of-run.sh`, which the driver names last as it
   did before.

Nothing else in the directory is on the list, so `source_checks` fails the run
on it and never sources it. That covers a merge's `GH-166.sh.orig`, an editor's
swap file, `GH-12a.sh`, `GH-012.sh` and `notes.sh`, as well as the library,
which the driver sources earlier by name. If `checks/` cannot be listed, the run
stops before anything is judged. A new issue file is sourced because of its
name, and adding one edits no shared line.

## Why

**The old trade.** ADR 0004 kept the list as a single line and accepted the
cost: "One line still takes an edit from every loop that adds an issue file ...
The order has to be written somewhere, and a directory listing has no order
anyone chose, so the conflict is kept and made as small as it can be." This was
reasonable while one loop ran at a time. With parallel lanes, every pair of
branches that added an issue file conflicted on that line, because git merges by
line. When one of them merged, GitHub could not build the others'
`refs/pull/N/merge`, so their CI stopped until an agent merged `dev-05` in and
resolved the line by hand. At `2f1a89b` four of the five open pull requests were
conflicting, all four on that line, and two of them on nothing else (#295's
triage). The branch that made this change hit the same conflict twice while it
was being written: `dev-05` gained `GH-110.sh`, and then `GH-187.sh`.

**Why a derived order is now acceptable.** ADR 0004 rejected a listing because
its order is one nobody chose. That objection only matters if the issue files
depend on each other's order, so the dependence was measured before the
decision was taken. At `2f1a89b` there were thirteen issue files. The whole
suite was run three times, sequentially, on one machine: with the issue files
in the list's order, in ascending order and in descending order. The unsplit
file stayed first and the end-of-run file stayed last in all three runs.

| run | order of the issue files | rows ok | FAIL | seconds |
|---|---|---|---|---|
| current | the list, `GH-205 … GH-182` | 6970 | 0 | 395 |
| ascending | `GH-118 … GH-273` | 6970 | 0 | 472 |
| descending | `GH-273 … GH-118` | 6970 | 0 | 454 |

The output of each run was cut into one block per file, at the heading each file
opens with, and the blocks were compared line by line across the runs. All
thirteen issue-file blocks and the end-of-run block were identical. The unsplit
block differed only in 34 `fastest <n> ms` wall-clock figures, and it is sourced
first in every run, so its output cannot depend on the order of the files after
it. With those figures masked, every block was identical, and stderr held the
same lines in every run.

The measurement was repeated at `bdf30ba`, the tree after the change. It also
carried `GH-110.sh` and `GH-187.sh`, which had merged into `dev-05` in the
meantime, and this change's own `GH-295.sh`, so it covered sixteen issue files.
The three runs used the derived order, the order the old list would have had,
and descending order. The derived run passed with 7009 rows. The other two each
failed the same three rows, and all three read the driver's assignment of the
list, which those runs replace with a literal:

- the GH-295 pin of that line;
- the GH-295 row that asks that the list rises;
- the library-placement rule, since `suite_checks` then has one caller.

Apart from those three rows and the timing figures, all seventeen blocks were
identical, and so was stderr.

So the order among the issue files is still one that nobody chose, but it is now
**fixed**, not arbitrary, and it was measured not to matter. Sorting by number
has three properties:

- The order does not depend on the filesystem, the locale or the merge order.
- A file that comes to depend on the order turns the run red on the pull request
  that adds it, instead of appearing later as a flake.
- A new file sorts after every file older than it, because issue numbers only
  grow. Most dependence runs from a newer file to an older one, so this is the
  direction it usually needs.

**Why not a glob.** A glob handed straight to `source_checks` would source
whatever lay in the directory. The derivation matches one name shape, and the
routine's existing refusal of files on no list becomes the guard for everything
else. So the guard ADR 0004 relied on ("present and unlisted") is kept, not
weakened.

## Considered Options

- **The list in a file of its own, marked `merge=union` in `.gitattributes`**
  (#295's option 1). Git would keep both appended lines without a conflict.
  Rejected because the measurement allowed option 2, and option 1 has costs of
  its own:
  - Whether GitHub applies `merge=union` when it builds `refs/pull/N/merge` was
    never observed.
  - Union can keep a line that one side deleted.
  - A name listed twice would need its own guard (#221).
- **Accept the conflict and record its cost** (#295's option 3). Rejected: the
  cost grew with the number of lanes, and at the triage it was the main cost of
  adding a lane.
- **Sort by name as text.** Rejected: `GH-10.sh` would sort before `GH-9.sh`.
  Today every number has three digits, so the difference would not show until
  the first four-digit issue.

## Consequences

- Adding an issue file edits no line of the driver. A branch that merges one
  across this change resolves the old conflict by deleting the list line,
  because the derivation already finds the file.
- The `SUITE_CHECKS`, `SUITE_LAST`, `SUITE_SOURCED` and `SOURCED_WANT` variables
  keep their names and their readers. `SUITE_CHECKS` is now assigned once, from
  `suite_checks`. The #204 checks still hold the list's two ends, and the
  GH-295 checks hold the order between them: a fixture directory whose names
  sort differently as text and as numbers, and the list this run derived, read
  without the derivation.
- A name listed twice is no longer possible, because a directory cannot hold a
  file twice. That half of #221 is moot. Its guard half is not.
- The rule lives in the tooling, which `mutate-hooks.sh` refuses as a target, as
  ADR 0004 recorded for `source_checks`. Its checks are fixture self-tests. Six
  mutations were run by hand at `bdf30ba`, each in a throwaway clone and against
  the whole suite. An unmutated clone passed. Each mutation turned at least one
  GH-295 row red:
  - the numeric sort made textual;
  - the pattern loosened to any `GH-*.sh`;
  - every file in the directory handed to the routine, as a glob would;
  - a directory that cannot be listed swallowed;
  - a literal list put back in the driver;
  - the driver's guard on a failed derivation dropped.
- **What is given up.** The hand-written list failed the run on an issue file it
  named that was missing. A derived list cannot name a file that is gone, so
  deleting an issue file is silent. What still catches it is the #205 check
  that every generated entry is declared by a file the run sourced, and that
  reaches only a file that declared an entry. The old list was silent too
  whenever the deletion took the name off the list with it. A symlink named
  `GH-<n>.sh` is sourced like a file.
- The mutation-registry count literals in `checks/unsplit.sh` are the same kind
  of shared line and are not changed here.

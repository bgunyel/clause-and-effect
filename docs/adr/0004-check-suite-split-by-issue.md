# The check suite is split by the issue whose work wrote each check

`.claude/hooks/check-hooks.sh` was one file that every loop appended to. It is
now a driver that sources the files under `.claude/hooks/checks/`, in an order
the driver writes: the helper library, the **unsplit file** holding every check
written before the split, one **issue file** per issue whose work wrote checks
after it, and the **end-of-run file** last (`CONTEXT.md` defines *issue file*).
A check lives in the file of the issue whose work wrote it, whatever it covers:
what a check covers is its tags, which the ledger records, and never its file.

The files are sourced into the driver's shell, one at a time, by a library
routine, `source_checks`. It records a start marker for each file, clears `REQ`
at each boundary, fails the run on a file that is listed and missing or present
and unlisted, and fails it on a file that did not run to its last line in that
shell or that left a shell option, the working directory, a trap or the umask
changed. The routine is proven by fixture self-tests, which are #204's step-2
checks at the end of the unsplit file: step 2 keeps the unsplit file the only
file of checks, and the first issue file is the next loop's.

## Why

The measurement that prompted #204: with three pull requests open against
`dev-05`, every one of the six merge orders conflicted in `check-hooks.sh`. The
file was 15,790 lines at `9c7dfdb`, having grown thirty-two-fold in fourteen
days, and every loop wrote into it. #200 had already split `requirements.md`
for the same reason, and splitting that file alone left the conflict rate where
it was.

The unit of the split follows **who writes**. Two loops collide when they edit
the same file at once, and a loop writes checks under one issue. A file per issue
is therefore a file with one writer, and two loops never open the same one.

## Considered Options

- **A file per section.** Rejected on #204's own numbers: between 2026-09-18
  and 2026-09-23 the sections went from 91 to 99 while the file gained about
  4,000 lines. New checks are appended inside existing sections, which several
  loops share, so a file per section would still put two loops in one file
  exactly when they touch the same subject.
- **A file per requirement ID** (`GH-130.1`, `GH-130.2`), as #200 did for the
  registry. Rejected: one loop writes under several IDs of one issue, so this
  spreads one writer across several files and prevents no collision. The
  registry is data keyed by ID; the checks are code written by a loop.
- **Concatenating the files and running the result.** Rejected in favour of
  sourcing. `record` writes a ledger row only when `$BASHPID` is the suite's own
  process, so where the checks run decides whether they count. Sourcing keeps
  one shell, one `FAILED` and one `REQ`, and it is also the mechanism a later
  `--only GH-<n>` selector would use. Concatenation would keep `BASHPID`
  identical as well, but it runs a file nobody wrote, and every line number and
  `BASH_SOURCE` in a failure would point into it.
- **A mutation row for the sourcing routine**, so that `mutate-hooks.sh` shows
  its checks can fail. Rejected: the harness mutates a copy of the hooks and runs
  the suite from the repository, which is why it refuses any row that targets
  the tooling (#107). The routine is tooling, and making an exception for it
  would break the premise the harness rests on. Its checks are fixture
  self-tests instead, each written against a file built to make one clause of
  the routine fail.

## Consequences

- The library holds a function when it has callers in more than one file. While
  a caller is still in the unsplit file, each section of that file counts as a
  separate caller, so the rule means something before any section has moved.
  It counts files and not sections, so that a helper two sections of one issue
  file share stays with the only work that edits it.
- Existing checks stay in the unsplit file until a loop touches them for its
  own reasons, and a fixture moves into the driver's prelude only when an issue
  file that owns it moves. The split is incremental, not a bulk rewrite. The
  conventions a loop follows are stated in the driver's header, and the reasons
  are stated only here.
- One line still takes an edit from every loop that adds an issue file: the
  driver's list, `SUITE_CHECKS`. The order has to be written somewhere, and a
  directory listing has no order anyone chose, so the conflict is kept and made
  as small as it can be -- one line, resolved by keeping both names. Nothing
  else about the list is pinned whole for the same reason: the checks hold only
  its two ends.
- A check file is sourced inside `source_checks`, a function, so a `declare` at
  its top level makes a variable local to that call rather than global. It
  works for every variable read inside the call, which is every check; one read
  after the last file has run has to be declared in the driver or with
  `declare -g`.
- The end-of-run file is sourced last whatever else the driver sources, because
  it reads the record every earlier check wrote. `REQUIREMENT_SHAPE` goes with
  it and stays a hunk every loop edits until #211. `SPLIT_MOVED` stays in the
  driver, because `split-requirements.sh` reads its tokens out of
  `check-hooks.sh` by name.
- Each file writes its own end marker with its last line, `sourced_to_end`.
  Bash returns from `.` the same way at a `return` halfway through a file as at
  its end, so a marker written by the routine after the `.` would call a file
  that returned early whole. The marker names the line it was written from,
  and the routine asks that it is the file's last: a marker's presence alone
  would pass a file that wrote one early and then returned. A file that runs `exit 0` ends the run before the
  routine can ask anything, so the driver's EXIT trap turns a status of 0 into 1
  when the record is short.
- The sourcing record is a file of its own, not rows in the ledger. The ledger
  is the record of check results: the #104 coverage counts its rows and
  requires each one to carry a tag, so a marker row there would be an untagged
  check.

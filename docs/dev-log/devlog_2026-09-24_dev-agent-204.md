# Dev-log — 2026-09-24 — dev-agent-204

## 2026-09-24 11:00 +03 — #204 step 2: the driver sources each file of checks/ whole, in order, in its own shell

Branch `worktree-issue-204-driver`, cut from `origin/dev-05` at `6884732` with
`git worktree add --no-track`. Commits `f17145a` (the move) and `508dbb9`, plus
this entry, three ahead of `origin/dev-05`. This is pull request 2 of the two the #204 triage brief asks
for; #204 was reopened after PR #216 (step 1) closed it through the
Development link, and this pull request is not linked there.

### The precondition was not met again, and Bertan chose to proceed

#189, #184 and #158 are still open, and each touches `check-hooks.sh` (read
from the API at the start of the session). The assistant asked, and Bertan
chose to proceed. All three now have to rebase across a move of nearly the
whole file into `checks/unsplit.sh`.

### Commit 1 is a pure move, measured byte-identical

`check-hooks.sh` keeps the prelude and the final verdict. Everything from the
first single-caller helper to the end of the #204 section moved, in order, into
`checks/unsplit.sh`, and the #104 section to the foot into
`checks/end-of-run.sh`. The move was done by a script that asserted each cut
line before writing. Three pieces of code changed so that the output would not:

- `SUITE_LIBRARY` and `SUITE_CHECKS` now split `SUITE_SOURCED`. Without the
  split, the head's record of what the library defines would have sourced each
  file of checks alone in a child, and so run every check a second time.
- `lib_callers` counts each section of `unsplit.sh` as a caller, as it counted
  the sections of the one file before.
- `SPLIT_MOVED` stays in the driver, because `split-requirements.sh` reads its
  tokens out of `check-hooks.sh` by name.

Measured against `6884732`, masked with `sed -E 's/[0-9]+ ms/<n> ms/g'`:
stdout, stderr, `--matrix` stdout and `--matrix` stderr are byte-identical, all
four of them. The hashes are `d8998ab8…`, `cf01f588…`, `25718226…` and
`cf01f588…`. Both runs printed 5,702 `ok` rows and exited 0.

### Commit 2: the routine, and where the assistant's design left the brief

`source_checks` is a library function. For each file it records a start marker,
clears `REQ`, sources the file, clears `REQ` again, and fails on four things: a
missing file, an unlisted file, a file that did not reach its last line in the
recording shell, and a file that changed the shell's state. The driver compares
the record with what its list says in three places: in a row, in a verdict taken
after every helper, and in the EXIT trap. The assistant departed from the brief
in four places, and each is in the pull request:

- **The end marker is written by the file's own last line, `sourced_to_end`.**
  The brief has the routine record it after sourcing. The assistant measured,
  on bash 5.2, that `.` returns identically from a `return` halfway through a
  file and from the end of the file. So a marker written by the routine could
  not have caught case (iv), a file that returns partway through.
- **The markers are a file of their own, `$SOURCED`, not ledger rows.** The
  #104 coverage counts every ledger row as a check and requires each to carry a
  tag, so a marker row would be an untagged check.
- **An `exit 0` in a file is caught by the EXIT trap.** It ends the run before
  anything after the `.` can ask, so the trap turns status 0 into 1 when the
  record is short.
- **The driver's comparison row prints only on failure.** A row printed after
  the last file would land after the matrix that `--matrix` has already printed.

### Mistakes, and what caught them

- **The assistant put the new checks in a new issue file, `checks/GH-204.sh`.**
  The brief says of step 2 that the unsplit file "is the only file of checks".
  The two-axis review's Spec half caught it, and the section moved to the end of
  `unsplit.sh`. That file already ended with the #204 step-1 section, so the
  output order did not change.
- **The assistant's first `shell_state` read the options through a pipeline
  inside `$( )`.** A command substitution reads errexit as off, so a `set -e`
  left behind would not have shown. The assistant caught this with a probe
  before the first run, and `shell_state` now writes from the sourcing shell.
  The assistant's first comment on it then said "a subshell" reads errexit as
  off. That was wrong: a `( )` subshell keeps errexit, and only `$( )` resets it
  (measured). The comment is corrected.
- **The assistant's first (vi) fixture would have read the parent's EXIT trap
  as removed.** A subshell shows the parent's traps in `trap -p` only until it
  sets a trap of its own, then drops them all (measured). A probe caught this
  before the run, and the fixture subshell now sets an EXIT trap of its own
  first.
- **Two expectations had the wrong order.** In (i) and (iii) the assistant wrote
  the FAIL line after the next file's output, but the routine prints them in
  list order. The assistant fixed them while reading the fixture, before the
  first run.
- **Three lines of `requirements.md`, `check-hooks.sh` and the text-check
  count needed updating.**
  - The assistant's first full run of commit 2 cited #212 in a comment, and
    #212 has no entry; the #104 citation audit went red. It is now listed under
    *Citations that are not requirements*, with its reason.
  - The second run went red on the text-check count literal, which moved 318 →
    319 for one new `armed`. Like `REQUIREMENT_SHAPE`, that literal is a line
    every loop adding a text check edits.
- **A mutant survived.** With the clear of `REQ` before each file removed, the
  suite stayed green, because the clear after each file covered for it. The
  fixture now enters the routine with `REQ` set, and the first file reports it.
  Its sibling mutant, the clear after each file removed, went red only on the
  (ii) row. The assistant then made the (v) fixture's last file end inside a
  `req`, so the row whose label claims it is the one that catches it.
- **Review found stale prose.** The two-axis review found a source-order comment
  missing the issue files, "sections" where the rule now counts files,
  `requirements.md` placing #106's seed table in `check-hooks.sh`, and the
  `declare` hazard unstated. The review also found that the driver's list,
  `SUITE_CHECKS`, is itself a line every loop adding an issue file edits. That
  trade is now recorded in the driver, ADR 0004 and GH-204.7, and not claimed
  away.

### Evidence (measured)

- **The final tree, against commit 1** (masked as above):
  - 5,702 → 5,727 `ok`: one new heading, and 25 new rows, 24 under it and one
    in the end-of-run file;
  - three labels moved: 208 → 211 requirements, 133 → 136 off the
    both-directions rule, 5,688 → 5,712 results;
  - stderr is unchanged in both modes, `cf01f588…`;
  - both modes exit 0, with `ALL CHECKS PASSED`.
- **Mutants.** Each ran on a scratch clone, and each was checked to apply once.
  - First pass, 24 runs: 22 went red on the check aimed at each, one survived
    (the `REQ` clear, above), and the control stayed green.
  - The survivor, once the fixture was fixed, went red. So did its sibling.
  - Among the red: the unsplit file not counted by section, each clause of the
    routine removed, the state read through `$( )`, the markers written from
    any shell, the verdict inert or never taken, the EXIT trap keeping 0 or
    replaced by the old one, the driver's row removed, `section` not writing
    headings, the reading inverted, the end-of-run heading check removed, an
    empty heading added, the end-of-run file sourced first, the unsplit file's
    last line removed, the end-of-run file running `exit 0` first (exit 1, with
    the record on stderr), and a check file leaving `set -f`.
  - A listed file that is missing stops the run in the prelude, with exit 1,
    before the routine runs, because the suite's own text cannot be read.
    That is the refusing direction. The routine's own arm for it is driven by
    the (i) fixture.

### Open

- **#218 stays open.** A file whose middle is deleted still reaches its last
  line, and GH-204.6 names that limit.
- **#217's items are untouched.**
- **Shared hunks remain.** `REQUIREMENT_SHAPE` stays a shared hunk until #211,
  and so do the text-check count and `SPLIT_MOVED`, which is in the driver.
  `SUITE_CHECKS` is a one-line conflict point by design.
- **#189, #184 and #158 must rebase across this move.**
- **Nobody has written an issue file yet.** The next loop that writes checks
  writes the first.

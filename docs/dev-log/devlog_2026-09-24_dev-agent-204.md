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

## 2026-09-24 11:50 +03 — PR #220, review round 1

Branch `worktree-issue-204-driver`, commits `8b9f906..56e86fe` plus this entry,
five ahead of `origin/dev-05` (`6884732`). rev-agent-204's round 1 is
[comment 5810561483](https://github.com/bgunyel/clause-and-effect/pull/220#issuecomment-5810561483):
one gating finding, two filed as #221, one prose.

### Finding 1, taken with a different fix

An end marker written before a file's last line, followed by a `return`,
passed as a whole run. The reviewer's m8c showed it: exit 0, `ALL CHECKS
PASSED`, one row short. The routine asked the marker's presence and its place
in the record, and both held.

The reviewer suggested counting the lines that read `sourced_to_end` and
requiring one. The assistant declined that and measured why: the count is a
text proxy for a runtime property, and `if true; then sourced_to_end; return
0; fi` is not a line that reads `sourced_to_end`. On a clone of `8b9f906` with
the count applied as "at most one" and that line inserted before the unsplit
file's last row, the suite exited 0 with `ALL CHECKS PASSED` and one row fewer.
The same clone with the own-line m8c shape went red, so the count closes the
instance named and not its sibling.

What was done instead: `sourced_to_end` records `BASH_LINENO[0]`, measured on
bash 5.2.21 to be the line in the sourced file. The routine, the driver's
`SOURCED_WANT` and so its row, its verdict and its EXIT trap all expect
`end <file> <last line>`. The (iv') fixture carries both shapes, the own-line
one and the one-line one. A stray second marker with no `return` passes the
routine's last-marker question, and the driver's whole-record comparison
catches it; the verdict fixture now has that `long` record.

### Findings 2 and 3, agreed as filed

Each needs two independent mistakes in one file, and each mistake alone is
caught. The assistant agrees with filing them in #221 rather than gating. This
round's change leaves both where they were.

### Finding 4, taken, and the sweep widened it

The routine's comment named three questions in an order the code does not
follow. It now names five, in code order. GH-204.6's text had the same defect:
it said "records a start marker, clears `REQ`" where the code clears first. It
now follows the code. GH-204.7 and GH-204.8 state no sequence and were left.
ADR 0004's summary sentence names no count and was left. Its consequence bullet
on the end marker, and the driver header's convention for a new issue file,
now say the marker names its line and is called once.

### Mistakes, and what caught them

- **The assistant's first mutant of the reviewer's fix proved nothing.** It
  applied the count as "exactly one", and it went red. The cause was the
  existing no-end fixture, where a file with no marker now printed an extra
  FAIL, and not the shape under test. The assistant re-ran it as "at most one",
  which is the reviewer's intent, and that run is the one reported above.
- **The citation audit went red on the first run.** The new comments cite
  #220, which had no entry, and the #104 audit refused it. #220 now has one
  under the citations that are not requirements.

### Evidence (measured)

- Head `56e86fe`: 5,728 `ok`, exit 0, `ALL CHECKS PASSED`. That is one more row
  than round 1's 5,727, the (iv') row.
- Mutants, each on its own scratch clone, each diff checked to have applied:
  - m8c on `56e86fe` (own-line marker and `return` before the last row): exit
    1, FAILs from the routine and the driver's row.
  - m8d on `56e86fe` (the one-line shape): exit 1, the same two FAILs.
  - m10 on `56e86fe` (a stray marker with no `return`): exit 1, the driver's
    row alone.
  - m11 on `56e86fe` (the routine accepts any line number): exit 1, the (iv')
    row alone.
  - The reviewer's count, as "at most one", on `8b9f906`, with the one-line
    shape: **exit 0, `ALL CHECKS PASSED`**, 5,726 `ok`. With the own-line
    shape: exit 1.

### Open

- #221 holds Findings 2 and 3.
- #218, #217 and the shared hunks named in the step-2 entry are unchanged.

## 2026-09-24 12:40 +03 — PR #220, review round 2

Branch `worktree-issue-204-driver`, commits `c15d648..65160d3` plus this entry,
seven ahead of `origin/dev-05` (`6884732`). rev-agent-204's round 2 is
[comment 5811334589](https://github.com/bgunyel/clause-and-effect/pull/220#issuecomment-5811334589).
Finding 1 is closed there, and the reviewer records that the line-numbered
marker was the better fix. Nothing in round 2 is gating; A and B were left to
the assistant's judgement.

### B, taken, and the sweep found a second instance

The pin on the driver's record comparison matched the statement's first line
only, so a `|| :` in place of its `|| fail` would keep the pin green with the
row gone. The reviewer reasoned this and did not measure it. The assistant
measured it: at `c15d648`, `|| fail` rewritten to `|| : fail` gave exit 0 and
`ALL CHECKS PASSED`.

The reviewer swept the four pins in the GH-204.7 block. The assistant swept
every pin added since commit 1, which also covers GH-204.8's block. There, the
`armed` pin on the end-of-run file's heading question matched only the
argument line of a two-line `tok`. At `c15d648`, that `tok` rewritten to `:`
gave exit 0 and `ALL CHECKS PASSED`, one row fewer.

Both pins are now a `tok` over the whole statement, read with `grep -F -A`
from the one file that holds it. At `65160d3` each of the two mutants goes red
on its own pin. Replacing an `armed` moved the text-check count literal
319 → 318; the first run went red on it.

The `SOURCED_WANT` pin stays first-line only, and says why at the pin: its
body is held by the live comparison with the record the files write.

### A, taken as prose

`heading_mark` runs only in `section`, so a heading printed with `echo` is
never written down. The reviewer found that every `===` heading goes through
`section` today, and the assistant agrees with naming the limit rather than
widening the check. It is in GH-204.8's note, and in the driver's convention
for a new issue file.

### Evidence (measured)

- `65160d3`: 5,728 `ok`, exit 0, `ALL CHECKS PASSED`. The row count is
  unchanged, since one pin replaced another.
- Mutants, each on its own scratch clone, each diff checked to have applied:
  - `|| fail` → `|| : fail` in the driver's row: exit 0 at `c15d648`; exit 1 at
    `65160d3`, on the new pin alone.
  - the end-of-run heading `tok` → `:`: exit 0 at `c15d648`; exit 1 at
    `65160d3`, on the new pin alone.

### Open

- #221 still holds round 1's Findings 2 and 3.
- The reviewer's declined simplifications were not taken.

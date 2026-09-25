# 2026-09-25 15:30 +03 — #215: the mutation harness's run log is frozen, and later runs go to the dev-log

Branch `worktree-issue-215-freeze-run-log`, cut from `origin/dev-05` at
`2c65f4d` with `git worktree add --no-track`, then fast-forwarded to
`origin/dev-05` at `5017b2b` before its first commit. Commits `9732562` and
`9fba2f0`, plus this entry: three ahead of `origin/dev-05` once it is
committed.

## The conflict was in the run log, so the log is frozen

The mutation harness's header mixed two kinds of text: the rules, and a dated
run log. Every loop that registered a row appended a paragraph to the log.
#215's triage re-measured at `2c65f4d`: #184 and #158 conflict only in header
prose, and no hunk falls inside the `MUTATIONS` heredoc. So the registry was
left whole and the log was frozen.

- **The frozen region runs from the line**
  `# MEASURED, 2026-09-17, at the commit that answered that review: all twenty-three`
  to `# thing #107 was filed about, and the registry is re-runnable instead.`
  It is 216 lines, and each bounding line stands once in the file.
- **Byte identity was measured, not asserted.** The region was extracted from
  `origin/dev-05` and from the branch with the same awk, and `diff` was
  empty: 216 lines, cksum `1303306919 15781`. The harness diff adds 14 lines
  and removes none.
- **A freeze paragraph stands directly above the log.** It names both lines by
  their text, and says the log's present tense is #215's. It also says a run
  after #215 is recorded in the dev-log of the session that ran it.
- **No rules paragraph told a reader to record a run in the header**, so no
  rules text changed.
- **What the region covers and leaves out, and why,** is in the header of
  `checks/GH-215.sh`. Two rule paragraphs inside the log, THE BRACKET FIGURE
  IS HISTORY and THREE ROWS FOR ONE FIX, are frozen with it rather than moved
  out, because each qualifies figures the log measured.
- **The trade is recorded** in the commit message and in the check file. A
  block that is stale by construction stays in the file. The rejected
  alternative was moving the log into a dated file under `docs/`.

## The check pins content, and asks the neighbours by their opening words

`checks/GH-215.sh` declares GH-215 (`doc-claim`, `static`), pins it with
`shape_pin`, and its requirements file is generated. The checks:

- **Each bounding line stands once.**
- **A cksum of the region.** A shape pin would pass a paragraph rewritten in
  place, and the log stays verbatim with its errors.
- **The paragraph below the log opens `WHAT A MUTATION IS.`,** so a record
  appended after the log's last line is red. That is where the loops
  appended, and where a region checksum is blind.
- **The paragraph above the log opens `THE RUN LOG BELOW IS FROZEN, AT
  #215,`.**
- **Four `holds` on that paragraph's claims.**

`requirement` and `shape_pin` moved from `checks/GH-205.sh` into
`checks/library.sh`, because GH-215.sh is their second caller. ADR 0005
predicted the move. `variants_pin` stays in GH-205.sh.

`mutate-hooks.sh --list`: all 85 rows are unchanged (measured, diff of the
two outputs). The one line that moves is the derived active-requirement
count, 195 → 196, which counts GH-215.

## Measured

- **Baseline** at `2c65f4d`, in a detached checkout: 5,774 ok, ALL CHECKS
  PASSED, 198 s.
- **At `9732562`'s content**, as an unmutated rsync control: 5,783 ok, ALL
  CHECKS PASSED. Nine new checks. **At `9fba2f0`'s:** 5,783 ok, ALL CHECKS
  PASSED.
- **Twelve hand mutations of the harness header**, each in its own rsync copy
  of the worktree, because the harness refuses its own file as a target. Run
  against `9fba2f0`'s checks, each turned red exactly the GH-215 checks named
  below and nothing else in the suite:
  - a record appended after the log's last line: the neighbour below
  - a record inside the log: the checksum
  - a record between the freeze paragraph and the log: the neighbour above,
    and the four claims, because the inserted record is then the paragraph
    they are asked of
  - the freeze paragraph deleted: the neighbour above and the four claims
  - `AT #215` dropped: the neighbour above and the frozen claim
  - the line-naming clause, the present-tense sentence, and the dev-log
    clause, each weakened in turn: its own claim
  - the present-tense sentence moved into WHAT A MUTATION IS: its claim.
    Under `9732562`'s checks this mutation would have been green (see below).
  - the first line duplicated elsewhere: the count of the first line
  - the last line deleted: its count, the checksum and the neighbour below

  A rewrap of the freeze paragraph and of WHAT A MUTATION IS stayed green:
  5,783 ok. The first eleven were also run against `9732562`'s checks, and
  each was red there too. The one difference was the inserted record, which
  turned only the neighbour above red, because the claims were then read off
  the whole header.
- **This session's mutation run, the first recorded here under the new rule
  rather than in the harness header:**
  `bash .claude/hooks/mutate-hooks.sh -v selftest-anchor-that-matches-nothing`,
  run alone at `9fba2f0` on 2026-09-25 to show the harness still starts with
  its header edited. The unmutated baseline copy was green, and the row
  reported `did-not-apply`, as it declares. `.claude/hooks/` was
  byte-identical after the run. Exit 0, 183 s (measured). That is evidence
  that the harness runs, and about nothing else: no real row was run.

## Mistakes and dead ends, attributed

- **The assistant edited files under a running baseline.** It started the
  suite in the worktree in the background and then edited `mutate-hooks.sh`
  and `check-hooks.sh` while the suite was running. It killed that run by PID
  and re-ran the baseline in a detached checkout of `origin/dev-05`.
- **The first run of the change was red on the library-membership check.**
  The assistant had read the driver header's note that `requirement` and
  `shape_pin` move to the library once a second file calls them, and still
  wrote the issue file without moving them. The move was made after the red
  run.
- **The stale-branch guard refused the first commit.** `origin/dev-05` had
  moved 8 commits, none of them under `.claude/`. The branch was
  fast-forwarded and the commit made on top.
- **Review of `9732562` found five defects in the assistant's work.** A
  standards review and a spec review, run as parallel sub-agents, found them.
  - The four freeze-paragraph claims were asked of the whole header, so a
    sentence moved into any other paragraph stayed green, while GH-215's text
    claims the freeze paragraph says them.
  - The commit message gave a wrong reason for using `holds`: to keep a count
    literal in `unsplit.sh` still.
  - The 2026-09-17 readings were called "a measurement of the rate, not a run
    of any row". They are the wall-clock of two whole-registry passes.
  - The left-out list omitted several dated paragraphs, two of them below
    `set -u`.
  - The neighbour pins used hand-counted prefix widths.

  All five are answered in `9fba2f0`, whose message gives each one.

## Open

- **Not yet reviewed by Bertan.** The pull request goes to `dev-05`.
- **#184 and #158 add paragraphs to the log's account**, according to #215's
  triage. When either one merges `dev-05`, a record it keeps inside the
  frozen region turns GH-215 red. The remedy is to move that paragraph into the dev-log of
  the session that ran it, which is what the freeze paragraph says to do.

# 2026-09-28 · dev-agent-279 — the end-of-run read-backs derive what they read, and the record child tells its outcomes apart (#279)

**2026-09-28 21:40 +03.** Branch `worktree-issue-279-verdict-readbacks`, cut
with `git worktree add --no-track` from `origin/dev-05` at `0d5829d`. The
entry was written at `a8a701c`, three commits ahead of `origin/dev-05` and none
behind it: `e86c0e2`, `351ff1b`, `a8a701c`. The commit that adds this entry is
the fourth.

## What was asked

#279 is the part of #217 still open in the end-of-run verdict and the head's
record child. It names three defects. The record child read a failed source as
emptiness, and read a dead child's partial record as whole (items 14 and 19).
The ledger-tail read-back was `tail -n 4` against four tags and one label
(items 24 and 29). The verdict-row read-back chose rows by label and ran before
GH-204.7's fixtures (item 26).

## What was built

- **GH-279.1.**
  - `LOADED_CHILD` records whatever sourcing defined, whatever status sourcing
    returned, and writes that status on fd 3 before recording anything.
  - `record_of` reads the child's own exit status too, and returns one of
    three outcomes.
  - `record_loaded`, in the library, is the head's loop. It turns a
    non-zero source or an unfinished child into a FAIL row under GH-279.1.
    It stops the run only on a file that defined nothing.
- **GH-279.2.** `verdict_tail_want` derives the tail rows from every
  `<NAME>_VERDICT_CODE` the driver evaluates, with a table of which clauses
  write a row. `verdict_tail_read` compares tag and label.
- **GH-279.3.**
  - `verdict_fixtures begin|end` marks each block of verdict fixtures in a new
    driver record, `$VERDICT_MARKS`.
  - The end-of-run file reads every row inside every block against a literal
    of seven rows.
  - `verdict_evals_outside` reads the check files for a verdict evaluated
    outside any block.
- **Registry.** One row, `tokeniser-sources-non-zero`. GH-279.2 and GH-279.3
  have none, because `mutate-hooks.sh` never mutates the suite, which is where
  their rules live.

## Measured

Everything below was run in this session. Nothing is recalled.

- **The new child against the old.** Run against the library and the
  tokeniser at `0d5829d`, the new child's record is byte-identical to the old
  child's: 30,498 and 57,596 bytes, compared with `cmp`.
- **Function-level mutations.** The assistant wrote a mini harness that
  sources the library and `checks/GH-279.sh` alone in a scratch copy. Eighteen
  mutations were run through it, each reverting one rule of the three
  requirements. Every one turned at least one GH-279 row red:
  - fifteen at `351ff1b`;
  - three more for the review round's widenings;
  - one for the `mk_halflib` guard, with `;` put back to `&&`.
- **The two real read-backs.** One whole-suite run in a scratch copy made two
  slips at once:
  - the ledger-verdict fixture's `req` changed from GH-204.1 to GH-204.7, under
    a label that does not begin `the final verdict `;
  - the not-found record's tail row given a shorter label under the same tag.

  The verdict-fixture read-back and the tail read-back each went red on its
  slip. The run's two other FAILs were GH-144's repository checks, red because
  the copy has no `.git`.
- **The registry row.** `mutate-hooks.sh -v tokeniser-sources-non-zero` at
  `a8a701c`: the baseline was green, and the row was caught. GH-279.1 went red
  with GH-117, GH-118, GH-124, GH-96.2, GH-96.3 and GH-98, whose rows source
  the tokeniser with `&&` before calling it.
- **The whole suite.** At `a8a701c`: ALL CHECKS PASSED, 7,790 rows ok, at a
  load average of 13 to 19 on 6 cores.

## Dead ends and mistakes

- **The first full run, at `e86c0e2`, went red twice**, both on the
  assistant's own code:
  - `verdict_tail_want` read a verdict's name as `[A-Z_]*`, so the fixture's
    `R279_EXTRA_VERDICT_CODE` went unseen. The derivation's own fixture caught
    it.
  - The record fixtures' expected output opened with the FAIL prefix inside
    quotes. The #104 audit reads that as a result printed outside `pass` and
    `fail`.

  The assistant's first fix for the second piped `record_loaded` through
  `sed`. That ran it in a subshell, so the fixture listed no recorded names.
  The mini harness caught it before commit. Both were fixed in `351ff1b`.
- **The registry row's first run came back `did-not-complete`**, with the head
  already fixed. `mk_halflib` in the library and `mk_emptylist` in the unsplit
  file asked `. lib && command -v …`, and their guards stopped the run on the
  source status. That is item 14's defect one fixture over, and the assistant
  had not swept for it. The sweep, after the fact, found these two as the only
  run-stopping guards. The other `. lib && call` lines are ordinary rows, and
  under the mutation they go red rather than stop the run. Fixed in `a8a701c`.
- **Review of the branch's own work** was two parallel sub-agents, one on
  standards and one on the spec.
  - The spec reviewer found two reads narrower than their prose: clauses
    counted by `FAILED=`, which `(( FAILED = 1 ))` passes, and the driver's
    verdict lines read anchored, which an indented or braced `eval` passes.
    Both were widened, and each now has a fixture.
  - The standards reviewer found six comment inaccuracies and a literal
    repeated three times. All were fixed in `a8a701c`.
- **Suggestions not taken.**
  - Renaming `verdict_tail_read`.
  - A `local REQ` in `record_loaded`. `sourcing_fail`'s pattern was kept for
    consistency.
- **A pushed commit refused.** The assistant's first push shared a line with a
  `2>&1`, and `no-git-push.sh` read the redirect as a refspec and refused the
  line. Committing and pushing as separate commands passed.

## Open

- A dead child that recorded nothing is a FAIL row and not a stop. That is
  stated in GH-279.1's note, as a departure from the issue's "defined nothing
  still stops the run", which the spec reviewer flagged.
- `verdict_evals_outside` and `verdict_tail_want` read text. A verdict
  evaluated through another variable is not seen, which both requirements name.
- #218 and #221 stay out of scope, as the issue says. `$VERDICT_MARKS` is one
  more piece of driver state a sourced file can change, which is #221's class.

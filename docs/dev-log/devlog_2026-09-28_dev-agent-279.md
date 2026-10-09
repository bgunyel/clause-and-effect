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

# 2026-09-30 · dev-agent-279 — the review of PR #330: five rounds, and the record child rebuilt (#279)

**2026-09-30 17:15 +03.** Appended to this entry, which is dated 2026-09-28. That is the file's date, and an entry cannot be renamed, so this section carries its own. Branch `worktree-issue-279-verdict-readbacks`. It runs from `5a03b23`, where the entry above was written, to `b15f391`, plus the commit that appends this section. It stands 20 commits ahead of `origin/dev-05` at `285e10d` before this one, and none behind. The review was rev-agent-279's, over five rounds on PR #330. This section also carries the corrections to the entry above that the review asked for.

## Corrections to the entry above

- **"A `local REQ` in `record_loaded`" is not a suggestion not taken.** Round 1 of the review raised it again, and the assistant took it in `f3f5cea`. `sourcing_fail` keeps its own pattern, which its comment argues is safe.
- **The two fixture guards no longer ask with `;`.** `mk_halflib` and `mk_emptylist` now ask `copy_sources_as` as well: a copy has to source with the status its original does. Round 1 measured a copy the builder broke (an unterminated `if` appended, status 2) passing every half-library guard with the old question. `mk_emptylist` moved to the library in `c783217`, because #279's issue file now calls it too.
- **The record child described above no longer exists.** The rounds below replaced it, and the byte figures above (30,498 and 57,596) are from `0d5829d` only.

## What the review found, and what was done

- **Round 1** (`f3f5cea`, `c783217`):
  - finding 1 was the guards above;
  - finding 2 was a record child that ran its loops in the shell the sourced file had just set. `IFS=x` joined every name into one key, and the record was still called whole.
  - The assistant's sweep of that class found nullglob, nocasematch, an EXIT trap and an alias of `declare` doing the same. The child was given a reset line.
- **Round 2** (`6cf1cfb`, `78c1f78`, `a8a9089`) found the class inside the reset. The child's own variables (`bf`, `bv`, `n`, `v`) and the reset's own success were reachable by the file: `readonly v` dropped a name silently. The assistant moved the before-lists to descriptors, gave the child `_lc_*` names with an exit-4 check, and re-enabled builtins, since the sweep found `enable -n` corrupting records too.
- **Round 3** (`f2e99a9`, `779b5af`, `7450987`) found it a third time: `alias exit=:` reached every guard written after the source, and a trace could be written into the record. rev-agent-279 asked for the altitude fix instead of another guard, and the assistant took it:
  - the child writes `declare -F`/`declare -p` before the source;
  - it then runs one brace group on the source's own line, parsed before the file runs, that only dumps `declare -F`, `-f` and `-p` to their own descriptors;
  - a new library function, `record_dump`, reads those dumps in the suite's shell and refuses any line it cannot account for.
- **Round 4** (`df17124`) found `record_dump` stricter than bash. It refused the trailer line `declare -f<flags> <name>` that bash prints after an exported, readonly or traced function, and a closing line with redirections, `} > /dev/null`. The child before #279 recorded both. It also found comments claiming refusals for dumps forged on purpose, which the code does not make. Forgery is now a named limit, since these checks stop mistakes and not adversaries.
- **Round 5** (`b15f391`):
  - a fixture for the trailer branch's `record_closed` guard;
  - the note's heredoc limit, which named the order that is refused rather than the one that mis-cuts;
  - the caveat on the sourced-non-zero row restored;
  - a variable declared with no value left unrecorded again, as `compgen -v` left it;
  - `record_dump` cleaning up its own `.part`.
  - Its heredoc findings are filed as #363.
- **Merges of `origin/dev-05`:**
  - `29f1a1f` (`abffdbf`) and `fd84115` (`f539d9a`);
  - `1f9487a` (`1486270`, #314 for #202, which grew the tokeniser by 427 lines);
  - `874171e` (`4cf79b1`);
  - `9d794bd` (`285e10d`).

  Each time the registry pins were re-derived with `mutate-hooks.sh --list` on the merged tree, not incremented: 153/151, then 185/183, then 191/189.

## Measured

- **Records:** after every change, the child's record of the library and of the tokeniser was compared with `cmp` against the record the child before #279 writes. It was byte for byte the same each time. The last figures are 47,315 and 72,227 bytes at `b15f391`. The tokeniser figures before #202 grew it were 57,596.
- **Mutations:** each round's fixes were reverted one at a time, in whole-suite runs in scratch clones with an unmutated control:
  - round 1: 11 of 11 went red;
  - round 2: 5 of 6 went red;
  - round 3: 13 of 14 went red;
  - round 4: 6 of 6 went red.

  The two survivors were real. Dropping `IFS=` from the round-2 read-back survived, because the entry `read` trims was one the child skips in the suite's environment. It was closed by construction, with an end marker. Splitting round 3's dump group onto a later line survived, because every command in it carries a backslash. It was closed by a fixture that aliases `{`, which that split turns red alone.
- **The registry row:** `tokeniser-sources-non-zero` came back caught at every head it was run on (`c783217`, `a8a9089`, `7450987`, `df17124`), with GH-117, GH-118, GH-124, GH-279.1, GH-96.2, GH-96.3 and GH-98 red.
- **Figures before this section:** the full suite at `9d794bd` gave ALL CHECKS PASSED, 8,502 ok. The run at `b15f391` is in the pull request's body.

## Dead ends and mistakes

- **Guards that kept growing.** The assistant answered rounds 1 and 2 with guards, and each guard was more program in the tainted shell for the next piece of state to reach. rev-agent-279 named the pattern in round 3, after its third appearance. The class stopped growing only when the program left the child.
- **An unmeasured claim in a draft.** The assistant's round-1 reply said a function named as a glob was expanded against the working directory. It measured this only before posting (it was recorded under a file's name, `r279_gx`), so the claim went out true. But it had been written first.
- **A first version refused bash's own output.** The first `record_dump` (`f2e99a9`) wrote functions before validating the variables, so it left partial records. It was fixed in `779b5af`, before the reviewer saw it. It also refused bash's trailer and redirection lines, which the reviewer found in round 4. The assistant had swept function shapes for heredocs, subshell bodies and headers, but not attributes and redirections.
- **Two citations the suite refused.** `#314` was cited without a cite entry (`fb978bc`). `#330` needed an entry once the checks cited it (`c783217`).
- **A byte figure written as "once round 3 was in"** went stale when the library changed, and the reviewer caught it in round 4. The code's figure is now dated by commit.
- **A run count miscounted in the pull request body** (fifteen for fourteen), corrected the same hour.
- **`2>&1` after a `git push` in one line** was read by `no-git-push.sh` as the destination and refused, once. Committing and pushing as separate commands passed.

## Open

- **#363:** heredocs in a function's body that `record_dump` reads wrongly. All are refusing, and none reaches a file the suite records today.
- **#339:** the verdict scanners read one spelling of an evaluation.
- **Named limits, in GH-279.1's note:** a record forged on purpose, through the saved descriptors, a DEBUG or EXIT trap, or a function named after `declare`, `enable` or `printf`; and a name bash itself starts with, assigned by the file.
- #218 and #221 stay out of scope, as before.

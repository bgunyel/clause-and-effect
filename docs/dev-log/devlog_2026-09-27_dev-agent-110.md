# 2026-09-27 · dev-agent-110 — #110: the live acceptance runbook, and its first run

**Written 2026-09-27, 19:46.** Branch `worktree-issue-110-live-runbook`, cut
with `--no-track` from `origin/dev-05` at `abba1d0`. It has two commits
(`bf99ba5`, `20587a5`) plus this entry, and is 3 ahead of `origin/dev-05` and 0
behind it. The session is lane #110 of wave 2.

## What was done

- **`.claude/hooks/runbook.md`**, six `## §<n>` sections, one per requirement
  no check reaches. Each gives what it verifies, who may run it, the commands,
  the expected observation as a literal, and what to do when that differs.
  - §1 is the worktree fork point, US-5 and US-6. It has four parts: the
    `git worktree add` route, the `EnterWorktree`-then-reset route, #99 Q8's
    four harness questions, and the `main ancestry` line.
  - §3 is the merge settings, FR-39.
  - §2, §4, §5 and §6 verify new entries, GH-110.1 to GH-110.4: the `main`
    ruleset, a refusal reaching the agent, a hook outlasting its timeout, and
    an offline SessionStart.
  - US-5, US-6 and FR-39 lost `gap → #110`, and `REQUIREMENT_SHAPE` moved with
    them.
- **A departure from the issue's labels**, which the pull request has to say.
  #110 names §2 "(US-1)" and §4 "(US-7)". Both have checks, and an entry with
  `seam: none` may have none. The assistant therefore minted GH-110.1 and
  GH-110.2 as the sections' own requirements, and listed US-1 and US-7 under
  an **Also observes** line.
- **GH-110.5, not asked for.** Each section's **Verifies** line is held both
  ways against the entries' `verify` fields, by `checks/GH-110.sh`. #104's
  check proves only that a section exists.
- **Where results go: `docs/eval-reports/`**, one dated file per run. Not the
  dev-log, because a run Bertan makes in his own terminal has no session. The
  first run is `docs/eval-reports/2026-09-27-boundary-runbook-183114.md`.

## The first run: what was measured

The assistant ran §1a, §1d, §2, §3 and §4 in this repository. It ran §1b's
harness half, §1c and §5 by starting `claude -p` sessions (Claude Code
2.1.283, Haiku 4.5) in scratch repositories, with `--setting-sources project`
so that only the scratch settings loaded.

- **§5 turned #96's premise into an observation.** A `PreToolUse` hook that
  sleeps 10 s under a 2 s timeout never logged past its sleep, so it was
  killed. The `touch` it would have refused ran 2.24 s after the hook started.
  The agent was shown `(Bash completed with no output)`, which is not an
  error. The same hook refusing at once blocked the call. So the kill permits,
  and it is silent. That is written into THE LINE CAP in `lib/command-scan.sh`,
  and pointed at from `no-pr-decisions.sh` and `append-only-docs-edit.sh`.
- **§1b and §1c answered #99 Q8 for `EnterWorktree`.**
  - `fresh` forked at `origin/main` and set no upstream, so #99's rule does
    not need `--unset-upstream`.
  - A `PostToolUse` matcher on `EnterWorktree` fires.
  - `WorktreeCreate` fires for `EnterWorktree`, in the project directory.
  - With a `WorktreeCreate` hook configured, the harness creates nothing.
    A hook that prints no path fails the call.
  - By the runbook's rule, #113 proceeds. The other three routes were not
    taken.
- **§2, §3 and §4 matched.** §2 gave `requires_pull_request: true` and an
  empty bypass list, and the ruleset targets `~DEFAULT_BRANCH`, not `main` by
  name. §3 read `false false true`. §4's refusal reached the assistant byte for
  byte after `PreToolUse:Bash hook error: [<command>]: `.
- **Not run:** §6, and §1b in this repository with its own
  `settings.local.json`. Both are Bertan's.

## Mistakes and dead ends

- **The assistant wrote a `git push` into the scratch setup.** It pushed to a
  local bare repository, and `no-git-push.sh` refused it, correctly, since it
  cannot judge the destination. The scratch repositories were rebuilt from a
  plain `origin` by cloning.
- **`unshare -rn`, to run the report hook offline**, failed in the sandbox
  (`write failed /proc/self/uid_map`). §6 stayed Bertan's.
- **Review round 1 found real defects in the assistant's own work.**
  - `r110_disagree` went green having read nothing when `requirements/` held a
    directory named `*.md`. mawk aborts on it, and the pipe loses the status.
    This is #219's class, in the file written the day #219 merged.
  - The new #96 paragraph said the permit "was reasoning" directly under a
    paragraph that read as having measured it. #96 had timed the hooks alone.
  - The record broke the runbook's own "verbatim" contract. The assistant
    loosened the contract to "a shortening said where it is made", and
    appended the record's corrections, since the record is append-only. That
    is a trade, taken knowingly: the contract moved toward the record.
- **§2's literal was first written in the assistant's key order.** `gh --jq`
  sorts keys, and running the command caught it before the commit.

## Evidence

- Check suite: `ALL CHECKS PASSED`, three times.
  - At `abba1d0`, before any change: 17m34s.
  - At `bf99ba5`: 19m57s.
  - Before `20587a5`: 28m01s, with 6,234 `ok` rows.
- The GH-110.5 mutants were run standalone, with stub helpers, and not
  through the suite: each goes red at the row that names it.
  - A dropped US-6 on §1.
  - The old `-e` test.
  - The no-sections branch deleted.

## Open

- **Bertan's:** §6, §1b in this repository, and the remaining §1c routes
  (`--worktree`, `isolation: "worktree"`, background sessions).
- **#113** can proceed on §1c's answers, which say a `WorktreeCreate` hook
  owns the whole creation and not only the base.
- **The interactive front end** was not watched for §5. Only `claude -p` was.

# 2026-09-27 · dev-agent-110 — #110: rev-agent-110's round 1 on PR #287

**Written 2026-09-27, 21:13.** Branch `worktree-issue-110-live-runbook`, from
`ba1e11b` to `4b302b6` plus this entry; 5 ahead of `origin/dev-05`, which
has not moved from `abba1d0`, and 0 behind it.

## What rev-agent-110 found, and what was done

rev-agent-110 reviewed the head `ba1e11b` and posted two gating findings and
eight others. The assistant took all ten, and declined none.

- **G2: GH-110.5 was a second copy of #104's grammar, narrower than the
  original.** The assistant wrote `r110_disagree` to parse the `verify` field
  on its own, and it wanted `^- verify: runbook §[0-9]+$` exactly. #104's
  reader trims the value and joins continuation lines, so a verify with a
  trailing blank, or wrapped onto a second line, resolved for #104 and pointed
  nowhere for the copy. A runbook that then dropped the entry passed with the
  suite green; rev-agent-110 measured both. The copy's own header named the
  risk ("THE GRAMMAR IS #104'S, written a second time"). The assistant chose
  the fix rev-agent-110 preferred: the comparison is now a part of #104's
  reader, in its `findings` mode, and emits GH-110.5 rows. Its checks stand
  beside that reader's fixtures in `end-of-run.sh`, because a reader sourced
  after the issue file cannot be called from it. `checks/GH-110.sh` now only
  declares. Moving the reader into the library so the issue file could call it
  was rejected: it would move three hundred lines of #104 for one caller.
  - N1 (a directory runbook or `requirements.md` let the copy print
    agreement), N2 (a `*.md` glob and `awk -v` paths where
    `requirements_split` and `ENVIRON` exist) and N5 (no scope reset on a `##`
    heading of another shape) were siblings, and went with the copy. The
    reader already reset scope in `requirements.md`. The assistant added the
    same reset to the runbook read, and a Verifies line outside any section is
    now a finding.
  - Measured on a scratch copy of the reader, never in this checkout:
    rev-agent-110's mutants A, B and C, and D (`- verify:runbook §1`), each
    print `§1: US-6 points here, and the Verifies line does not name it`, and
    the unmutated copy prints the `ok` row.
- **G1: runbook §2's filter read neither `target` nor
  `.conditions.ref_name.exclude`.** The assistant wrote it that way, so a
  ruleset excluding `main`, or targeting tags, printed the expected literal.
  The filter and literal now carry both. The assistant re-ran §2 live, and ran
  the filter over six locally mutated copies of the ruleset's JSON: each one
  differs from the literal. The run record has an addendum.
- **N3, N4, N7 (prose against itself or its source).** §5's *When it
  differs* line called a timed-out refusal an exception its own prose filed
  like any other. §1d and §6 quoted a line's opening without saying so. §5's
  **Also observes** named an issue. `GH-110.sh` said "this pull request".
- **N6.** *Mistakes and dead ends* above says "The scratch repositories were
  rebuilt from a plain `origin` by cloning." That is passive, and it is a
  correction. The assistant rebuilt them. This entry is append-only, so the
  correction is made here rather than in that line.
- **N8.** A 140-column comment line in THE LINE CAP, reflowed.
- **One more of the assistant's.** The first suite run after the fix went red
  on GH-104.3: the new comments cited `#287`, a number with no entry. They now
  name "the pull request that closed #110".

The `r110_disagree` named above, under review round 1, no longer exists.

## Evidence

- Check suite on `4b302b6`: `ALL CHECKS PASSED`, 6,240 ok rows, run beside
  the two mutant runs below.
- The run before it, on the uncommitted tree, went red on the `#287`
  citation only, and passed every GH-110.5 row.
- The new reader rules, mutated in scratch clones of `4b302b6` and run through
  the full suite:
  - X: the runbook's scope reset, the unread-runbook finding and the
    no-entries finding disabled. Red at four rows: the three naming those
    rules, and the renamed-headings row, whose expected lines name the
    heading each stray Verifies line stands under.
  - Y: the no-sections finding disabled. Red at exactly the one row naming it.

## Open

- Unchanged from the entry above: §6, §1b in this repository, and the rest of
  §1c are Bertan's; #113 can proceed; the interactive front end was not
  watched for §5.
- A runbook or `requirements.md` that is a directory still aborts #104's
  reader under mawk. The live read goes red on the status and no GH-110.5 row
  says agreement, and a fixture now pins both halves. Refusing it in the shell
  first, as the split set is, would be #104's to take.

# 2026-09-27 · dev-agent-110 — #110: rev-agent-110's round 2 on PR #287

**Written 2026-09-27, 22:17.** Branch `worktree-issue-110-live-runbook`, from
`7c1c0bb` to `be0a6e8` plus this entry; 7 ahead of `origin/dev-05`, still at
`abba1d0`, and 0 behind it.

## What rev-agent-110 found, and what was done

rev-agent-110 re-ran its round-1 mutants through the full suite and confirmed
B, C and D fixed. It posted one gating finding and five others. The assistant
took all six and declined none.

- **G3: CI was red on `7c1c0bb`, and the assistant's round-1 fixture caused
  it.** The `rb-directory` fixture asserted `status 2`, which is mawk's abort
  on a directory. The CI runner's awk reads a directory as empty and runs to
  its end, so the row failed there and passed here, where `/usr/bin/awk` is
  mawk. busybox's awk behaves like the runner's, and the assistant used it to
  reproduce the difference. rev-agent-110 proposed accepting either outcome.
  The assistant went further: #104's reader now refuses a runbook that exists
  and is not a regular file before any awk reads it, the way it already
  refuses a split file that is not one. So the fixture asks for one outcome
  under every awk: a named FR-45 finding, the pointing entries told the
  runbook "is not a regular file", the program finishing with status 0, and a
  GH-110.5 FAIL rather than agreement. On scratch copies of this repository's
  requirements, the directory case and the unmutated case each printed the
  same rows under mawk and busybox awk.
- **The dev-log's *Open* above is wrong under the CI awk.** It says a
  directory runbook "still aborts #104's reader under mawk. The live read
  goes red on the status". That was true only of mawk, and since `be0a6e8` it
  is true of no awk: the reader names the directory, and the live read goes
  red on that FAIL row. A `requirements.md` that is a directory is unchanged,
  because it predates #110 and nothing in this branch asserts how an awk
  handles it.
- **N9.** `requirements.md`'s list of what the suite fails on now names
  GH-110.5's rules, together with the not-a-regular-file runbook.
- **N10.** runbook §1b expected the count against `origin/dev-NN` to show `0`
  on the right, which holds only while `origin/main` is an ancestor of the
  dev branch. It now expects whatever
  `git rev-list --left-right --count origin/dev-NN...origin/main` prints, and
  says what each ancestry gives.
- **N11.** The assistant's comment said a verify refused by #104's resolution
  points at no section in the comparison either. That is untrue for a gap
  entry, which the resolution skips. The comment now says so. The skip is
  deliberate: US-5 and US-6 pointed at an unwritten runbook while they were
  gaps.
- **N12.** A fixture now reaches the "above the first section" message.
- **N13.** A 120-column prose line in runbook §5, left by the assistant's N7
  edit, is reflowed. The assistant's N8 width sweep had covered comment lines
  only.

## Evidence

- Check suite on `be0a6e8`: `ALL CHECKS PASSED`, 6,243 ok rows, run beside
  the mutant below. CI run 36342835115 on `be0a6e8`: success, with the
  directory rows passing under the runner's awk.
- The directory guard removed in a scratch clone of `be0a6e8`, full suite:
  red at exactly the four `rb-directory` rows, and at no other row.

## Open

- As in the entries above: §6, §1b in this repository, and the rest of §1c
  are Bertan's. #113 can proceed. The interactive front end was not watched
  for §5.
- rev-agent-110 filed #298: the Verifies parser reads layout, prose and fenced
  code as the list.
- rev-agent-110 left two questions for Bertan. Should GH-110.5's checks live
  in `end-of-run.sh` rather than the issue file? Should US-6 stay `gap` until
  §1b runs with this repository's own settings?

# 2026-09-27 · dev-agent-110 — #110: rev-agent-110's round 3 on PR #287

**Written 2026-09-27, 23:06.** Branch `worktree-issue-110-live-runbook`, from
`fdbcf32` to `6b1ff56` plus this entry; 9 ahead of `origin/dev-05`, still at
`abba1d0`, and 0 behind it.

## What rev-agent-110 found, and what was done

rev-agent-110 re-ran the round-2 fixes through the full suite, busybox awk
included, and confirmed them. It posted one gating finding and four others.
The assistant took four and declined one.

- **G4: a section number used twice merged silently.** The assistant keyed
  the runbook's sections by number, and `if (!(s in rbsec))` skipped the
  second `## §3`. A second §3 with no Verifies line therefore passed green,
  and the `ok` row counted six sections over seven headings. rev-agent-110
  measured this with a full suite. The reader now counts headings per number.
  A number heading two sections is a GH-110.5 finding, and for each entry
  pointing at it an FR-45 one, since `runbook §3` then names one of two.
  Running rev-agent-110's mutant H through the new reader under mawk and
  under busybox awk printed both findings, identically.
- **N16: "not read" described four states.** It was used for an absent, an
  empty, an unreadable and a not-regular runbook alike. The shell now
  classifies the path, and each state is named in its own words. An
  unreadable runbook, like a directory, is never handed to `getline` and is a
  finding of its own. New fixtures cover the empty and unreadable cases. The
  unreadable one fails loudly if it runs as root, where mode 000 reads.
- **N14: runbook §6's fourth literal had a second shape the assistant missed
  in both earlier sweeps.** In the `NOT` case the message runs to three lines,
  and the stale-refs suffix ends the third. §6 and §1d now both say so.
- **N15: two procedures raced their own reads.** §1b fetched before reading
  the fork point, so a moved `main` read `1	0` for a correct fork. It now
  reads first and fetches only before the reset. §1d fetched after the
  SessionStart report had read the ancestry, so the two could disagree about
  refs that moved in between. It now runs the report by hand and reads the
  ancestry straight after, with no fetch of its own between. §3 had the same
  shape against the `merge settings` line, and the assistant gave it the same
  change.
- **N17, declined.** The `#110` row under citations that are not
  requirements is redundant now that GH-110.1 to .5 exist, and it says so
  itself. `#107`'s row is the precedent: kept as history of why the number
  was cited before its entries existed.
- **A mistake of the assistant's during the fix.** It reflowed the runbook's
  over-wide paragraphs with Python's `textwrap`. That expanded the literal
  tabs in the expected `0	0` counts to spaces, and flattened §1c's
  numbered list into one paragraph. It saw this in the diff before
  committing, restored the file from HEAD (it held only this round's edits,
  which a script re-applied), and reflowed the two paragraphs by hand. The
  tab count went from 5 to 6, the one added being §1b's new `1	0`.

## Evidence

- Check suite on `6b1ff56`: `ALL CHECKS PASSED`, 6,249 ok rows, run beside
  the two mutants below. CI run 36346183579 on `6b1ff56`: success, the
  unreadable-runbook fixture having run there as a user mode 000 stops.
- Scratch clones of `6b1ff56`, full suite:
  - The duplicate-number findings disabled: red at exactly the two
    `rb-duplicate` rows.
  - `runbook_state` made to print nothing: red at the ten rows that name a
    runbook's state, #104's own "which is not written" fixture among them,
    and at no other.
- Five runbook states on scratch copies of this repository's requirements,
  under mawk and under busybox awk: identical rows for each, status 0.

## Open

- As before: §6, §1b in this repository, and the rest of §1c are Bertan's.
  #113 can proceed. The interactive front end was not watched for §5.
- #298 (rev-agent-110's) now also holds the ID scan's missing word boundary,
  `FR-3.1` read as one ID, and a `## ` comment inside a bash block ending a
  section.
- The record's §1d and §3 were run under the earlier procedure, which
  fetched before reading. Their observations agreed, and the record names
  the runbook commit it followed, so nothing in it is corrected.
- For Bertan, from rev-agent-110: whether GH-110.5's checks may live in
  `end-of-run.sh`, given that the driver's header conventions and CLAUDE.md
  both place an issue's checks in its issue file; and US-6's status.

# 2026-09-27 · dev-agent-110 — #110: rev-agent-110's round 4 on PR #287

**Written 2026-09-27, 23:45.** Branch `worktree-issue-110-live-runbook`, from
`912686a` to `74e9eed` plus this entry; 12 ahead of `origin/dev-05`, still at
`abba1d0`, and 0 behind it.

## What rev-agent-110 found, and what was done

rev-agent-110 re-ran the round-3 fixes and confirmed them. It posted no
gating finding and six others. The assistant took all six.

- **N18: two claims were wider than the evidence the assistant gathered.**
  §5 watched one `PreToolUse` hook on the Bash tool under `claude -p`.
  `append-only-docs-edit.sh`, an Edit or Write hook, cited §5 as having
  watched the kill, and GH-110.3's text covered every hook and every front
  end. The assistant scoped the matcher and kept the front end:
  - GH-110.3 is now about a hook on the Bash tool, which is what #96's line
    cap and #240 are about.
  - GH-110.3 still claims the interactive front end. §5 now says an
    interactive run is what the section still owes it.
  - The Edit or Write hook's comment says the kill is presumed there, not
    watched.
  - GH-110.2 had the same width: "a hook's exit 2" also covers
    `append-only-docs-edit.sh`, which §4 did not watch. rev-agent-110 read it
    as clean. The assistant scoped it to the Bash tool as well, and §4 says
    so.
  - Both requirement files were regenerated with `generate-requirements.sh`.
- **N19: the record's §1d and §3 had been run under the procedure round 3
  replaced.** The assistant re-ran both at 23:28:39 under the current one.
  Both match, and the result is appended to the record. §3 told the reader
  to run the report "as §1d runs it" but gave no command, so the command is
  now written out. The record says the command it ran is that one.
- **N20: the unreadable-runbook fixture failed under root, permanently.**
  Under root, mode 000 reads, so there is no unreadable runbook to name. That
  branch now asks the opposite: `runbook_state` says nothing of the file, and
  the runbook is read and agrees. No run here was made as root, so that
  branch is written and not yet run.
- **N21: gap entries demanded a runbook.** An unwritten runbook with only gap
  entries pointing into it, the state before #110, failed GH-110.5, although
  #104's resolution calls it legitimate. Gap entries now count toward the
  comparison with sections that exist, and never toward a demand that the
  runbook exist. A runbook that is not a regular file, or cannot be read, now
  fails GH-110.5 whatever points into it. Before, a directory runbook with no
  non-gap pointers printed `ok`, next to an FR-45 FAIL. There are fixtures
  for both.
- **N22.** §1d said the hand-run report "removes nothing", and its fetch
  prunes. It now says what the report deletes and what it does not.
- **N23.** `rb_mutant` was a second copy of `req_mutant`. `req_mutant` now
  takes a source fixture as an optional fourth argument. The state fixtures
  now filter the findings they already hold rather than running the program
  twice.
- **One more of the assistant's.** Its round-3 edit to the runbook's header
  left an 82-column line, which its round-3 width sweep missed. Reflowed.

## Evidence

- Check suite on `74e9eed`: `ALL CHECKS PASSED`, 6,251 ok rows, run beside
  the two mutants below. CI run 36348356699 on `74e9eed`: success.
- Scratch clones of `74e9eed`, full suite:
  - Gap entries counted as demanding a runbook again: red at six rows, the
    gap-only row, the gap-only directory row, and the four state rows whose
    count of non-gap pointers they change.
  - The not-a-regular-file clause dropped: red at exactly the gap-only
    directory row.
- §1d and §3, live, at 23:28:39: both match. The record has them.

## Open

- As before: §6, §1b in this repository, and the rest of §1c are Bertan's.
  #113 can proceed.
- §5 owes GH-110.3 a run in an interactive session.
- The root branch of the unreadable fixture has not run anywhere.
- Bertan's: where GH-110.5's checks live, and US-6's status.

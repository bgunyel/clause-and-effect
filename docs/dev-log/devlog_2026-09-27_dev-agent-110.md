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

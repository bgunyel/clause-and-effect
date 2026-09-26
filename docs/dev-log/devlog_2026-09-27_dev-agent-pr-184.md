# 2026-09-27 00:55 +03 · session `dev-agent-pr-184` — PR #184 (#118) merged across the split, then review rounds 5–8

**Branch** `worktree-issue-118-gh-preoption`, in the existing worktree
`.claude/worktrees/issue-118-gh-preoption`, which Bertan gave this session
permission to work in. The session's commits run from `2550c60` (the tip it
found) to the commit carrying this entry, and they are a6a0ffd, 90fb247,
9cbeda2, af84077 and that one. The branch ended **10 commits ahead of
`origin/dev-05` at 5d95c8a and 0 behind**.

The session was worked as a review-and-fix loop between two AI assistant
sessions. **dev-agent-pr-184** (this one, "the assistant" below) made the
changes. **rev-agent-pr-184** (a second session, "the reviewer") posted each
round as a PR comment. Both were told to push back rather than comply.

**Check suite: 5939 results at `origin/dev-05` 5d95c8a → 6072 at this entry's
commit, all passing on both.** Both sessions measured the 5939 independently.
All ten of #118's mutation rows were run as one selection against af84077's
tree: baseline green over 226 requirements, all ten caught, `.claude/hooks/`
byte-identical afterwards.

This entry also carries three corrections owed to
`devlog_2026-09-20_clause-and-effect-37.md`, the entry of the session that wrote
#118. They are under *Corrections to an earlier entry* below. That entry is
append-only, so they are made here and not there.

## Round 0: the merge across the split

The branch was 153 commits behind and conflicting. It predated the check-suite
split (#204) and generated requirement entries (#205). The assistant merged
rather than rebased, so that the history already reviewed stays readable, and
resolved the conflicts as follows.

- **The driver** was taken from dev-05 whole. #118's checks moved into a new
  issue file, `checks/GH-118.sh`, extracted mechanically from the branch's diff
  rather than retyped.
- **Three checks stayed in `checks/unsplit.sh`:** the `no-work-on-stale-branch.sh`
  flips for `--config-env` and `--attr-source`, and the `--attr-source HEAD
  status` permit. They run in `$WT_STALE`, a fixture the unsplit file builds.
  The driver header says "a fixture moves into this prelude only when an issue
  file that owns it moves", and also that "a new issue's checks go in a new
  issue file". Here the two rules conflict. The assistant chose the fixture
  rule. The reviewer called the reading defensible, and named the conflict for
  Bertan to decide, not infer.
- **GH-118 was not declared in the issue file.** The kickoff asked for it, and
  the assistant pushed back: GH-118 is in `REQUIREMENTS_LEGACY`, and GH-205's
  text says no legacy ID has a declaration. `split-requirements.sh` ran three
  ways during the merge and wrote `requirements/GH-118.md` from the branch
  side. That file stays hand-written.
- **The run records #118 had appended to `mutate-hooks.sh`'s run log were
  dropped.** #215 froze that log after #118's branch was cut. **The assistant
  first carried them into it**, and `checks/GH-215.sh`'s byte-for-byte check
  went red. The records survive in 2550c60's `mutate-hooks.sh` and in the
  Sep-20 entry. One of them is only in 2550c60: the merge-at-7bea85f run, "188
  requirements, all eight caught".
- **One semantic conflict git did not flag.** #134.1's derivation of the load
  guard's triggers reads every `if [ -z` guard in the library. It found #118's
  `CS_GH_AWK` withdrawal and found it silent. The assistant made the withdrawal
  print a line naming `CS_GH_AWK`, instead of narrowing the derivation, and
  added a check that is red without that line.
- **Stale literals** were moved. The `no-pr-decisions.sh` arm count had merged
  clean and stale for the second time, because each side counted the other's
  arm out.

## Round 5 (answered in 90fb247)

- **Gating: the stump rule asked only the separate value.**
  `gh pr --repo=$(echo o/r) merge 5`, `-R"$(…)"`, `--repo=` followed by a
  backtick, `-R=$(…)`, and `--hostname=$(…)` in front of a create or an api
  merge were all permitted, while `-R $(…)` was refused. The fix is one test,
  `unfinished()`, asked at both places a value is written, with `ghattached()`
  pulling out the attached value.
  - **The reviewer proposed a unified rule that would also reach #197.** The
    assistant declined: a backtick cut leaves no marker, so the walk can only
    judge what a cut leaves behind. In round 6 the reviewer pointed out that
    `line_was_cut` in `no-pr-decisions.sh` already exists, and put that on
    #197.
- **Swept, filed as #243:** the gh api method (`-X$(…)`) and field values
  (`state=$(…)`) read from their stump. Identical at dev-05, and not #118's
  walk.
- **`$'-t'` / `$"-t"` options** were pinned as boundary rows citing #166.
- **Prose fixed:** the withdrawal was described as covering "the one state" a
  `command -v` guard cannot see. It covers the harmless one of two. A program
  that does not compile fails open, which was measured with one extra `{`, and
  #242 owns it.
- **CLAUDE.md** gained a ninth deliberately-left-open consequence for the refused
  reads.
- **Pushback accepted by the reviewer:** the bare "I" in the Sep-20 entry would
  not be edited in place. The README says an existing entry is never edited,
  and CLAUDE.md says corrections go in the newest entry.

## Round 6 (9cbeda2): two claims about gh that the evidence did not support

- **The longhand claim.** "An unknown longhand is treated as a boolean and eats
  nothing" was stated in five places as measured on gh 2.45.0, from the message
  `unknown flag: --squash`. That message is printed whether or not a word was
  eaten. The reviewer ran `gh pr --squash view --help` on gh 2.45.0 and got
  `gh pr`'s usage, so `view` was eaten.
  - **The assistant had repeated the claim itself in round 0**, writing
    `checks/GH-118.sh`'s new header as "cobra hands a shorthand it does not
    know the next word". It was corrected with the rest.
  - The sweep found a sixth instance, in #106's departure comment in
    `unsplit.sh`.
  - The corrected account has two steps. When gh resolves the path, an option
    it cannot look up takes the next word. Whether the resolved subcommand then
    runs is decided by that subcommand's own flag parse.
- **The bare `-` paragraph** said gh stops on a lone `-`. It skips it and
  resolves the verb after it. The paragraph now points at #241.
- **The assistant did not run gh this round.** The hook refuses
  `gh pr --squash view --help` as unreadable, and running gh under another name
  to get an answer would have been routing around it. `stripFlags` was read in
  cobra v1.8.1, from a terraform Go module cache, which is not gh's own build.
  Every statement about gh in this entry is either the reviewer's gh 2.45.0 run
  or that source, and says which.

## Round 7 (af84077)

- **Gating: `--version` below the root.** `ghopt` recognised it at every level.
  cobra registers it on the root command's own `Flags()`, so below the root it
  is unknown and eats the next word. `gh release --version view delete v1` was
  granted as a release read. It is now recognised only in front of the group;
  `--help` is persistent and stays recognised everywhere.
- **The refusal's first example, `gh pr merge 5 --squash`, was itself
  refused.** It was replaced, and a derived check now reads the examples out of
  the refusal as printed and feeds each to the hook.
  - **The assistant's first version of that check guarded an empty read with
    `exit 1`.** Under `gh-option-never-unreadable` that stopped the whole run,
    and the harness reported the row *did-not-complete* instead of caught. The
    assistant's own mutation run found it, not a review. The guard is now an
    ordinary failing check.
- **The four CLAUDE.md pins read raw lines.** The reviewer rewrapped item 9 with
  no word changed and a pin went red. They now read through `comment_reflow`,
  and were measured in both directions: the rewrap stays green, and a removed
  phrase goes red.
  - The same raw shape in the GH-99.1 and GH-117.1 pins, and two false-green
    `prose_count` absence pins, were added to #192 rather than changed here.

## Round 8 (this entry's commit)

- **The derived example check cut at the first `.`**, so a refused example
  holding `site.github.io` was read as `gh -R o/site`, which passes. It now
  cuts at the literal next sentence. A copy of the hooks with that example
  planted went red on it.
- **Three statements of the recognised set named only `-R`, `--repo` and
  `--hostname`:** the refusal, CLAUDE.md item 9, and GH-118's text. All three
  now name `--help`, and `--version` in front of the group.
- **"No walk sees it" was true of a backtick substitution and false of a
  `$(` one**, whose `$` stump lands in the path position. The two are now told
  apart, and the `$(` rows are pinned as #241's.
  - **The reviewer offered folding the path-position test into this PR, and the
    assistant declined.** #241 holds three spellings of one class (`""`, a lone
    `-`, a `$` stump). Closing one here would recreate the asymmetry #197's
    reasoning warns against.

## Corrections to an earlier entry

These correct `devlog_2026-09-20_clause-and-effect-37.md`, which is append-only.

1. **Line 373**, under *Why the git classes are not fixed in this PR*, opens
   with a bare "I": "I considered it, and the argument for is real". The
   decision was the AI assistant's in session `clause-and-effect-37`, and the
   sentence should read "The assistant considered it". The reasoning after it
   stands. Found by the reviewer in round 5.
2. **Lines 19–22**, under *The defect, and the correction to the defect
   report*, say cobra treats an unknown **longhand** as a boolean, so
   `gh pr --squash view 5` "eats nothing", and that only a shorthand consumes
   the next word. That is wrong. The `unknown flag: --squash` it cites is
   printed either way. gh 2.45.0 prints `gh pr`'s usage for
   `gh pr --squash view --help` (the reviewer's run, round 6). cobra's
   `stripFlags` gives the next word to any option it cannot look up, longhand
   or shorthand (v1.8.1 source, read by the assistant). The rule was never
   narrowed on the strength of the claim, so no verdict was wrong. The longhand
   rows pin a word gh really eats, not only the rule's width.
3. **Lines 215–228**, under *Dropping the exemption had a price*, say
   `--version` and `--help` are recognised as the root flag set and "cannot
   hide a verb". That holds at the root only. `--help` is persistent.
   `--version` is the root's own, and below the root it eats the next word, so
   `gh release --version view delete v1` resolved `release delete` and was
   granted as a read until round 7 of the review of #184. The same paragraph
   says `-h` "stays unreadable, because cobra registering it is a thing to
   measure". The reviewer measured it in round 7: below the root it eats as
   `--version` does, so leaving it unreadable was right.

## What was measured and what was not

| claim | status |
|---|---|
| 5939 at dev-05, 6072 here | measured, full suite, by the assistant; the 5939 by the reviewer too |
| ten mutation rows caught | measured, one selection, against af84077's tree; round 8 changed no line a row edits |
| every verdict quoted above | measured by feeding the hook on stdin, by the assistant and the reviewer separately |
| gh eats a word after an unknown longhand, a lone `-` is skipped, `--version` is root-only | gh 2.45.0 `--help` runs by the reviewer; cobra v1.8.1 source by the assistant; gh never run by the assistant |
| `pr merge` defines `-t`, so `gh pr -t view merge 5` merges | asserted from gh's documented `-t, --subject`; the hook refused the check |
| the round-7 rows fail at gh's second step when run | inferred from `unknown flag: --version`; not run |

## Open, for the next session

- **PR #184 is ready for Bertan's review and merge decision.** Nothing gated
  after round 7.
- **For Bertan:** which rule wins when an issue's checks need a fixture the
  unsplit file owns. The driver header does not say.
- **Filed or widened this session**, none fixed here: #243 (api method and
  field stumps), #241 (path-position words gh never receives, now three
  spellings), #242 (no awk compile check), #192 (raw-line pins over CLAUDE.md,
  including two false greens), #197 (backtick cut with no stump, and
  `line_was_cut` as a starting point).
- **Still open from before:** #166, #191, #194.

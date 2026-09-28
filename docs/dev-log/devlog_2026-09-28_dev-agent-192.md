# 2026-09-28 · dev-agent-192 — #192: a pin on prose reads the prose, not the lines

**Written 2026-09-28 17:12 +0300.** Branch `worktree-issue-192-prose-pin-reflow`
was cut with `--no-track` from `origin/dev-05` at `0d5829d`. The work is two
commits: `acff2fb` (the reader, the sweep and `checks/GH-192.sh`) and
`2386b3e` (fixes from the review). This entry is a third. When it was written,
before it was committed, the branch was 2 commits ahead of `origin/dev-05` and
0 behind it.

## What changed

The library has a reader for a pin on prose, `prose <file>`. It writes the file
as `comment_reflow` reads it to a fixture under `$FIXTURES/prose` and prints the
fixture's path. The rule that governs its use is stated once, beside it:

> A pin whose literal holds a blank and whose file is prose — Markdown, or a
> comment — reads the file through `prose`. A pin on code reads the lines, and
> so does a pin on prose whose literal needs a line's opening `#`, with a
> comment saying so.

- **The sweep moved 125 pins onto the reader.** 122 were moved by a scripted
  pass over `unsplit.sh` and `GH-182.sh`, driven by a list of targets and
  literals the assistant judged one by one. The other three were the ones
  `flatten` had covered (below), plus the two `#N` pins over the sweep section
  that review found (below).
- **The left-open pins read the list through `comment_reflow`.** They are
  GH-99.1's and GH-117.1's `holds`/`lacks` over `$LEFT_OPEN`.
- **The counts count occurrences.** GH-99.1's two `'0'` counts over CLAUDE.md,
  and the `'1'`/`'0'` counts of the history and the argument over three hooks,
  now use `prose_occurrences`, which counts occurrences in the reflow. The
  `prose_count` they used counts lines, and a reflow is one line.
- **`flatten` is retired.** It was a second reader, with its own rule for what a
  rewrap may do, and it had three fixtures. The two heading pins over the
  domain-docs section stay on the lines, because `prose` takes the `#` they
  need.
- **`beside` reads its comment block through `comment_reflow`.** It moved into
  the library together with `dev_pointer`, because the suite's placement rule
  requires that once `GH-192.sh` drives it too.
- **Pins deliberately left on the lines**, each with a comment saying why:
  - the heading pins (a `#` literal);
  - the report's `worktree remove` / `branch -d` absences, which are code;
  - two literals inside printed `echo` messages;
  - the suite text's `# THE HELPER LIBRARY` line.

`checks/GH-192.sh` declares GH-192.1 to GH-192.3:

- It drives `prose`, `prose_occurrences` and `beside` against wrapped fixtures.
- It audits the suite's own text for a `written`, `unarmed`, `holds`, `lacks`
  or `prose_count` that names a prose variable directly with a literal holding
  a blank. The prose variables are every variable assigned an `.md` path,
  derived off the text, plus five named ones. On `origin/dev-05` the audit
  reports 100 such pins; on the branch it reports none.

## Measured

All runs below are full runs of `check-hooks.sh`. The four demonstrations ran
on `git archive` copies, which have no `.git`. Two rows fail there on every
copy for that reason alone: `this repository has no git common directory…`
and `the reader names a dev-NN run…`. The baseline copy of `0d5829d` showed
the same two, and nothing else. They are left out of the counts below.

**False greens, with the forbidden phrase re-added wrapped.** The demonstration
added three things across line breaks:

- `The reserved acts below are the four` / `acts …` to the branch-hygiene
  skill;
- `` `git fetch origin `` / `` dev-NN:dev-NN` `` and `` `git `` /
  `` branch -f` `` to CLAUDE.md;
- `three` / `# citations named below.` as a comment in `unsplit.sh`.

| rows | `origin/dev-05` | branch |
|---|---|---|
| `the skill does not carry the count that went stale` | ok | FAIL |
| `CLAUDE.md does not restate the glossary's fetch into a local branch` | ok | FAIL |
| `nor its forced branch move` | ok | FAIL |
| the suite head's count at three | ok | FAIL |

With the phrases absent, the branch run was green: `ALL CHECKS PASSED` at
`acff2fb`, and again after the review fixes.

**False reds, with a paragraph rewrapped.** The paragraphs were rewrapped at
width 12 by a script that asserts the word sequence is unchanged:

- CLAUDE.md's *Where a worktree branch starts* section, through the paragraph
  before *Deliberately left open*;
- the left-open list's consequence 6.

Width 12 was chosen after the assistant measured which widths split each of the
eleven pinned literals. At width 44, five stayed on one line, including
`Nothing enforces`, which opens a paragraph. At width 12, none did.

- On `origin/dev-05`, 11 rows went red: the six GH-99.1 boundary-section pins
  and the five GH-117.1 consequence-6 pins.
- On the branch, none did.

## Dead ends and mistakes

- **The first rewrap demonstration left `git branch -f` on one line.** The
  assistant wrote the CLAUDE.md edit with that literal on a single line, so on
  `origin/dev-05` the `nor its forced branch move` row went red because the
  literal was really there, not because of a wrap. The script was corrected to
  break it, and both copies were re-run. The table above is from the corrected
  run.
- **The first full run on the branch had three FAILs, all the assistant's own:**
  - `GH-192.sh`'s fixture literal `no three citations named below.` tripped the
    suite's own absence pin over its text. The pin was working; the fixture was
    reworded.
  - The text-check count literal went from 321 to 322, from the added
    `written`.
  - `beside` and `dev_pointer` were called from two sections and had to move
    into the library.
- **The review found five defects in `acff2fb`.** It ran as two subagents, one
  on standards and one on spec. Each defect was confirmed and fixed in
  `2386b3e`:
  1. The `written` the assistant added beside the suite-text absences matched
     its own line in `$SUITE_TEXT`, so it could not fail. Its literal is now
     split the way its neighbours' are, and the reflowed text holds the
     sentence once.
  2. The audit exempted any literal holding a `#`. The rule exempts one that
     opens with `#`. The two `` `…pull request #N` `` pins over the sweep
     section had passed the audit for that reason alone, and now read through
     `prose`. The audit also missed a literal that opens the next line; it
     reads one now.
  3. Behind `prose`, `written` and `unarmed` are handed an absolute fixture
     path, so `absolute_or_fail` (#142) could no longer see a relative source.
     `text_check_faults` read `$(prose …)` as the file. Now `prose` refuses a
     relative name, and `text_check_faults` judges the path inside the
     substitution. Both are driven.
  4. `comment_reflow` turns an empty line into a blank, so an empty extraction
     made `$LEFT_OPEN_PROSE` a blank that `lacks` passes. For the same reason,
     `prose` now asks whether the reflow holds a word, not whether the source
     has a size.
  5. `GH-118.sh`'s comment still said the class "is on #192".
- **A `2>&1` after `git push` in a compound line was refused by
  `no-git-push.sh`.** It named `2>` as the destination. A `cd` in front of
  `git commit` was refused by `no-commit-to-main.sh`. Both hooks behaved as
  documented, and both commands were re-run plainly.

## Open

- **The hook files' comment prose is swept by judgement, not audited.** Whether
  a literal over `$HOOKS/*.sh` is prose or code was decided pin by pin, and the
  audit does not reach those pins. GH-192.3's note says so.
- **An indented comment keeps its `#`**, so a phrase wrapped across two
  indented comment lines is not found through `prose`. No pin needed one when
  the sweep ran. The limit is pinned as a check, so a fix that reached it would
  go red there first.
- **A prose fixture with no `.md` in its name is audited only if it is added to
  `R192_NAMED`.**
- **No `mutate-hooks.sh` row was added.** The harness copies only
  `.claude/hooks/`, and the false greens live in the skill, in CLAUDE.md and in
  the suite text, so a row could not reach them. The demonstrations above are
  the evidence instead.

## Correction, 2026-09-28 17:20 +0300

The first bullet of *What changed* above miscounts the sweep, and the
assistant wrote it that way. The right figure is **134 pins, in three
groups**:

- 122 moved by the scripted pass, of which 7 are the left-open `holds`/`lacks`
  named in the next bullet;
- 10 that had read through `flatten`;
- the 2 `#N` pins over the sweep section, which review found.

"The other three" in that bullet is wrong as well: it is 12 pins in two
groups.


## Review round 1, 2026-09-28 18:25 +0300

rev-agent-192 posted round 1 on PR #318 at `e7dc1e3`. It raised three gating findings (G1–G3) and three non-gating asks (N1–N3), and filed #319–#322. The assistant agreed with all six. The fixes are `751c1d6`. When this section was written, before it was committed, the branch was 4 commits ahead of `origin/dev-05` and 0 behind it.

- **G1 and G2, one class: the reader normalised fewer line shapes than its targets carry.**
  - `prose` now reads through `prose_reflow`. Before `comment_reflow`, it turns a tab, a CR, a VT and an FF into a blank, and takes each line's leading blanks off.
  - An indented comment's `#` now comes off, so an absence pin reads a phrase re-added wrapped inside a function (G1).
  - A tab no longer splits a phrase. That was `flatten`'s `tr -s '[:space:]'`, which the sweep retired, and so a regression on GH-97.2 (G2).
  - The library paragraph that said no pin needed indented comments was wrong for absence pins, and the assistant wrote it. A presence pin names where today's text sits; an absence pin must read wherever the text can be put back.
  - `comment_reflow` is unchanged, as #192 requires. `beside` reads through `prose_reflow` too.
  - GH-192.1's pinned limit row flipped from FAIL to ok, as its comment said it would.
- **G3: a wider reader satisfied a presence pin from somewhere else.**
  - GH-182's literal now runs into `, which no consumer calls`, which only the statement carries.
  - G1's own fix widens the reader again, into that same class. So the assistant re-ran rev-agent-192's instrumentation of `written` after the fix: 124 calls through `prose`.
  - No pin has an extra reflowed occurrence beside a single raw one.
  - `THE LINE CAP` went from 4 reflow occurrences to 5, from an indented wrapped cross-reference at `lib/command-scan.sh:1485–1486`. It is already in #321, with 3 raw occurrences.
- **N1: the GH-192.3 audit was narrower than its requirement text.**
  - It now reads `"${NAME}"` and a quoted `.md` path written into a pin.
  - It derives variables assigned indented, after `local`/`export`/`readonly`, single-quoted, or with a trailing comment.
  - Both the audit and the derivation are driven against fixtures.
  - Lower-case names are deliberately not derived, and the requirement's note says why.
  - Re-measured with the widened audit: 100 on `origin/dev-05` (unchanged), 0 at `e7dc1e3` and at `751c1d6`. The widening found no new variable in today's text.
- **N2:** the audit's comment claimed `prose` keeps a `#` inside a literal. It does not keep one that a wrap puts at a line's start. The comment was corrected.
- **N3:** the `beside` row moved under GH-192.1, and GH-192.1's text now names `beside`.

### Measured

Every row is a full `check-hooks.sh` run on a `git clone` of `751c1d6`, so each has a `.git`. Every mutation's diffstat was confirmed non-empty before its result was counted. The unmutated head read ALL CHECKS PASSED (5m13s wall-clock, 3m29s user).

| mutation | result on `751c1d6` |
|---|---|
| B: wrapped `$ARGUMENT` in an indented comment of `report-stale-branches.sh` | 1 FAIL, `and the report does not argue it a second time` |
| C: wrapped `$HISTORY` in an indented comment of `no-work-on-stale-branch.sh` | 1 FAIL, `the history of the recorded version is told in the guard, once` |
| H: tab-wrapped `publishing a` / `release` in CONTEXT.md's reserved-act entry | 1 FAIL, `and no longer narrows it to publishing one` |
| F: `lib/command-scan.sh:709` deleted | 1 FAIL, `the library says cs_normalise answers for cs_drop_heredocs` |
| E2: `"$(prose "$SKILL_MD")"` → `"${SKILL_MD}"` | 1 FAIL, the GH-192.3 audit |
| U1: `prose_reflow` without the `tr` | 3 FAIL: the tab row, the `prose_reflow` row, the `beside` row |
| U2: `prose_reflow` without the leading-blank strip | 2 FAIL: the indented row, the `prose_reflow` row |
| U3: `beside` back on `comment_reflow` | 1 FAIL, the `beside` row |
| U4: the audit without the `${NAME}` scan | 1 FAIL, the audit fixture row |
| U5: the audit without the `.md`-path scan | 1 FAIL, the audit fixture row |
| U6: the derivation back to the old regex | 1 FAIL, the derivation row |

B, C, H and F were ALL CHECKS PASSED on `e7dc1e3` in rev-agent-192's runs.

### Found in the sweep, not fixed here

- **#323.** Seven readers call `comment_reflow` directly, so they skip `prose_reflow`'s normalisation. GH-157's four `lacks` and GH-177's two are absence pins among them. The direction was derived from the reader, not measured by a suite run, and no target file holds a tab today. #318's own `LEFT_OPEN_PROSE` is one of the seven. It carries only presence pins, and on `origin/dev-05` those read raw lines, so it is not a regression.
- **#319's fix now lands in `prose_reflow`.**

### A second correction to the first entry

The assistant's correction at 17:20 above gets the composition of the 134 wrong: it counts the 7 left-open `holds`/`lacks` inside the 134, and they are not in it. Re-derived at `e7dc1e3`, 128 `$(prose …)` pin sites stand outside `checks/GH-192.sh`: 97 continued `written`, 18 continued `unarmed`, 12 one-line `written` and 1 one-line `unarmed`. Less the one new `written` that rev-agent-192 excluded, which the assistant did not identify separately, that is 127, and the 7 `prose_occurrences` bring it to 134. This agrees with rev-agent-192's re-derivation. So the 122 moved by the scripted pass does **not** include the 7 left-open pins. Those are 7 more, read through `comment_reflow` on the string rather than through `prose`. The PR body counts them separately and was right. Only this entry's correction was wrong.

## Open, after round 1

- The *Open* bullet above that says an indented comment keeps its `#` no longer holds: G1 closed it.
- #319 through #323 are open.


## Review round 2, 2026-09-28 19:05 +0300

rev-agent-192 reviewed `55051ad` and raised one gating finding (G4) and two non-gating asks (N4, N5). It filed #324 and #325, neither for this PR. The fixes are `e19e246` and `cde846f`. When this section was written, before it was committed, the branch was 6 commits ahead of `origin/dev-05` and 0 behind it.

- **G4, and a false claim, both the assistant's.** `$LEFT_OPEN_PROSE`, a reader #192's own sweep added, piped into bare `comment_reflow`. So a tab inside `git reset --hard origin/dev-NN` split the phrase, and the `lacks` over it read ok with the phrase standing in CLAUDE.md (rev-agent-192 measured this). It now reads through `prose_reflow`.
  - The round-1 reply and the section above both said this string "has presence pins only". That is false: `unsplit.sh:7168` is a `lacks`.
  - The assistant's sweep missed it because it grepped single lines, and that `lacks` has its reader on a backslash-continued second line. The sweep was reading a pin on raw lines, which is #192's own class.
  - The same miss undercounted #323's table. With continuations joined, the direct readers carry 14 absence pins, not 6: GH-157 4, GH-177 2, GH-215 1, `$LEFT_OPEN_PROSE` 1 (fixed here), and `$MUT_PROSE` 6.
- **A standing check for G4's class.** GH-192.3 now pins each suite file's count of direct `comment_reflow` calls as a literal: GH-118 1, GH-157 1, GH-177 2, GH-215 5, library 1, unsplit 1. It is driven first against a fixture. The first run of that row went red on its own regex, which is itself a direct call in GH-192.sh's text. The pattern is now built from a variable.
- **N4.** GH-118's and `unsplit.sh`'s comments said `prose` is bare `comment_reflow` over a file; both are corrected. The same sweep, run over the assistant's own file, found GH-192.sh's header saying the same thing and counting two helpers. It is corrected in `cde846f`.
- **N5.** GH-192.3's note now says that a pin whose literal is a variable is not judged.
- **Checked:** no absence pin through `prose` holds a `#` in its literal. The library says so, and a continuation-joined sweep found none, while its control over `written` found the two `#N` presence pins.

### Measured

Full runs on `e19e246`: the head in the worktree, and each mutation on a `git clone`, with the diffstat checked.

| run | result |
|---|---|
| head | ALL CHECKS PASSED (372 s wall-clock, 212 s user, 172 s sys, with four other runs alongside) |
| J: `git reset --hard<TAB>origin/dev-NN` on a continuation line of CLAUDE.md's left-open list | 1 FAIL, `and the unenforced rule is not one of its items` (rev-agent-192: ALL CHECKS PASSED at `55051ad`) |
| J0: the same with a blank, as the control | 1 FAIL, same row |
| U7: `$LEFT_OPEN_PROSE` back on `comment_reflow` | 1 FAIL, the direct-reader count |
| U8: the direct-reader pattern without its `comment_reflow <` alternative | 2 FAIL, the driven row and the suite row |

`cde846f` changes only a comment. It was run once more: ALL CHECKS PASSED.

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

# 2026-09-29 06:55 +03 · dev-agent-162 — #162: every entry's heading is read against its file name

**Written 2026-09-29 06:55 +0300.** Branch `worktree-issue-162-devlog-heading-agrees`,
cut with `--no-track` from `origin/dev-05` at `abffdbf`, then fast-forwarded to
`f539d9a` before its first commit. The work is `8418ae2` (the check), plus a
second commit answering the two-axis review and holding this entry. When this
entry was written, before that second commit, the branch was 1 commit ahead of
`origin/dev-05` and 0 behind it. No pull request was open.

## The check reads the property #162 asked for, narrowed to contradiction by Bertan

`checks/GH-162.sh` walks `docs/dev-log/`, taking every name but `README.md`,
and asks each entry four things. Its name is `devlog_<date>_<session>.md`. Its
first line is a `# ` heading. The first date on that line is the file's. And
the heading names no session, or names the file's. A session is compared by the
Edit guard's `session_key`, and it is read in two places. One is before the
date, less a `Devlog` title. The other is the label after the date, up to the
first ` — `; when that names nothing, the label is the one word after the dash.
Requirement `GH-162`, `doc-claim`, `direction: static`. The README's Conventions
gained one bullet stating the rule, pinned whole.

Measured on the real directory after the review fixes: of 74 entries, 70 name
their session and 4 name none, and none contradict its name.

## The issue's premise had moved, and the rule was decided again

The issue and its triage brief were written on 2026-09-17 and 2026-09-20. The
assistant re-measured on `abffdbf` before building, and three things had
changed:

- The heading #162 was filed against, `devlog_2026-09-17_session-5.md`, had
  already been corrected by #177 under ADR 0003.
- #157's README no longer indexes entries, so the triage's properties B
  (bullet text) and C (completeness) had nothing to read. They were not built.
- Four entries written after the triage — `dev-agent-205`, `-157`, `-207` and
  `-215` — open `# <date> <time> +03 — #<n>:` and name no session. The
  triage's rule, that a heading *contains* its session, would be red on them
  for ever. They are history, and ADR 0003's correction moves a segment but
  cannot insert one.

The assistant put the choice to Bertan: contradiction only, require the
session, or require it with four named exceptions. Bertan chose contradiction
only.

## Errors on the way, and who found them

- **The first full run of the suite had three FAILs, all from this branch's own
  text.**
  - One line of the requirement's heredoc opened with the word `written`, and
    the text-check scanner read it as a call to the `written` helper. That
    also moved the text-check count from 322 to 323.
  - A fixture heading cited `PR #152`, which has no requirement entry and no
    cite reason.
  - Both were rewrapped or reworded, and the second run passed: 8112 ok.
- **The assistant's first commit command was refused whole**, by
  `no-work-on-stale-branch.sh`, because `origin/dev-05` had moved 8 commits.
  The `git add` in the same command never ran. The assistant fast-forwarded,
  then pushed before noticing that nothing had been committed. That push only
  created the remote branch at `f539d9a`, dev-05's tip. The commit and a
  second push followed.
- **The two-axis review found defects the fixtures had pinned as correct.**
  - The spec reviewer found that the two `dev-agent-204` entries, shaped
    `# Dev-log — <date> — dev-agent-204`, write their session after the dash.
    The first version read them as naming none, and passed one naming the
    wrong session. The assistant had written that case into the header as a
    trade. The reviewer's narrower reading, one word after the dash, closes it
    without turning summaries into labels, and is what was built.
  - The standards reviewer found that a session written *before* the date was
    never read (`# Session 2 — 2026-09-17 — x` passed on `session-5`). It also
    found four comments claiming more than the code did, among them a
    `session 50` fixture that was really `session 60`, and "75 entries" where
    75 was the count with the README. It found as well that `r162_key` copied
    the guard's `session_key` with no check holding the two equal. Each was
    fixed, and the copy is now pinned line for line to the guard's body, read
    off `$HOOKS`.

## Evidence that the rows can go red

The real entries cannot be broken to test the check. Both append-only guards
refuse the edit, and `mutate-hooks.sh` cannot reach this file, because
`checks/` files are tooling and not mutation targets. So the evidence was
gathered in scratch, and is recorded here rather than in the registry.

- **Sixteen mutations of the judge, one at a time**, against the issue file
  under stub helpers. Each one turned at least one row red. The rules broken
  were:
  - key equality, the date test, the time strip, the offset strip, the ` — `
    cut, and the README exclusion;
  - the no-session verdict, the heading test, the name test and the file test;
  - the title test, the `devlog` strip, the one-word rest, and blanks allowed
    in that word;
  - a title-only heading read as naming none, and the copied key drifting from
    the guard's.
- **The real-directory loop**, run against a scratch copy of `docs/dev-log/`
  with `session-5`'s heading put back to `session 2`, was red on exactly that
  entry. Against a directory that is not there, the read guard was red.
- **The README pin** read 1 on the bullet as written, 1 after rewrapping and
  re-indenting it, and 0 after changing `it may name none` to
  `it must name one`.

## Still open

- **Seen wrongly, and pinned as verdicts:**
  - a one-word summary on a heading that names no session is read as a
    session and refused;
  - so is a title before the date other than the three `Devlog` spellings;
  - so is a rest opened by an en dash.
  - No entry has any of these shapes.
- **Not seen:**
  - only an entry's first line is read, so an appended entry's heading is not
    judged;
  - the key is locale-dependent for non-ASCII letters, and the guard's key has
    the same exposure.
- The full suite is to be run again on the second commit before a pull request
  into `dev-05`.

**Appended 2026-09-29.** The full suite on the second commit's tree printed ALL CHECKS PASSED, 8117 ok, this entry's own row among them.

## Appended 2026-09-29 — review round 1 (rev-agent-162), answered in `74fb487` and the commit holding this section

This section corrects the entry above. Three of its claims no longer hold. The
rest after the dash is no longer read as "the one word after the dash". The
first item under *Still open* is wider now. And the evidence counts have grown.

**Finding 1, a permitting hole the assistant had left.** rev-agent-162 put
seven first lines on a copy of the real directory, and every one passed green
while naming the wrong session. Among them were `# 2026-09-17 — session 2 —
#128: …` on `session-5` (#162's own defect, with the ` · ` swapped for a
` — `), `# Dev-log — <date> — session dev-agent-999`, a trailing blank, a CR
and `(continued)`. The one-word reading skipped any rest with a blank in it.
The assistant had chosen that reading in the two-axis round, to keep summaries
from being read as labels, and this entry above calls it closed. It was not.
Now, when neither the title nor the label names a session, the rest's first
word is read, or its first two when the first is `session`. A rest opened with
`#` names none. The trade is wider than before and is pinned as a verdict: a
summary opened by a word, on a heading that names no session before its dash,
is refused (`— the check-hooks summary` reads `the`). No entry has that shape.
The assistant took the refusing direction because a false red is visible and a
false green is not.

**Finding 2, three claims that said more than the code.** They were the README
bullet ("every entry's first line"), the header's "On a draft it is one edit",
and "each pinned by a row". The README and the entry above both call an
appended entry an entry, and only a file's first line is read. #190 freezes a
draft from its first write, so a draft has no one-edit fix. And the non-ASCII
limit had no row. The first two are reworded, and the third has a row now. The
same sweep found one more claim, a sentence the assistant wrote this round
("every spelling of a correct heading an agent might write is a fixture"). It
was narrowed before commit.

**Finding 3 and #344, false reds with no agent remedy.** The fixes are these:

- a time with seconds or after a `T`, and a zone of `+0300`, `+03:00`, `Z` or
  `UTC`;
- a trailing CR;
- #344's `# Session 8 — <date> — follow-up`: once a title names the session,
  the rest is not read;
- #344's `# Devlog session 5 — <date>`.

Each is a fixture that agrees. A session named `Zulu-1` is a fixture too,
because a zone read without the blank after it would cut its `Z`.

**An error of the assistant's, found by the suite.** The first full run on
`74fb487` had 4 FAILs, all GH-104.3. The assistant had given the new fixture
headings made-up summaries citing `#207`, `#217` and `#218`, and had cited
`#344` in the header. None of the four had a cite entry. The fixture summaries
no longer cite issues they do not mean, and #344 has a cite entry in
`requirements.md`.

**Evidence, measured.**

- The #162 section alone: 88 ok, 0 FAIL. That is 12 fixture and pin rows, 75
  real entries (71 name their session, 4 name none) and the README pin.
- Eleven mutations of the new code, each in a scratch copy of `.claude/hooks/`
  and `docs/dev-log/`, each turned a row red. They were: the old one-word rule,
  the `#` exemption, the two-word `session` read, reading the rest after a
  title, the CR strip, seconds, the `T`, the old zone rule, the zone's
  boundary, `Z`, and the title's `session` strip.
- rev-agent-162's seven surviving mutants and its control, on a copy of the
  real directory, are red now. Its three false reds and the two #344 shapes are clear.
- The full suite on the commit holding this section's code printed ALL CHECKS
  PASSED, 8118 ok, one more than before: the non-ASCII row.

## Appended 2026-09-29 — review round 2 (rev-agent-162), answered in `4d81a55`

rev-agent-162 re-ran the round-1 mutants: every one was red where a
contradiction stood, and green where the heading was right. Its seven
mutations of the round-1 code were each caught. It accepted the condition the
assistant had added to its sketch, that the rest is read only when neither the
title nor the label named a session, together with the wider trade that
condition brings.

**Finding 4, a claim of the assistant's own round-1 delta that drifted.** The
round-1 reply said the README bullet "now tells the writer the rule before the
first write". It did not. The bullet named one word after the dash, but the
code also reads `session` and the word after it, and it skips the rest
entirely when the title named a session. Under the bullet,
`— session dev-agent-162` would be refused; the code passes it. This is the
class of round 1's Finding 2, in the text written to answer it. The bullet now
names all three places a session is read, and the time and the zone. The
`check-hooks.sh` header said "first heading" where the code reads the first
line. Both are fixed, and the zone's wording in the issue file's header is
too: two more digits are optional, and a zone is taken with or without a time
before it.

**#354, filed by rev-agent-162 and folded in here.**

- The real rows classed a `<name>: <judgement>` line by its end. A name is
  text that the judgement repeats, so `devlog_<date>_x: names its session.md`,
  with a wrong heading, was passed. Each real row now takes its judgement from
  `r162_judge` and classes it by equality in `r162_class`, which has a row of
  literals.
- The title's `session` strip was a second copy of the guard's, and nothing
  pinned it. The title is now keyed a second time through `r162_key`, which is
  pinned line for line to the guard.

**Evidence, measured.**

- The #162 section alone: 89 ok, 0 FAIL, one more than before, for the
  `r162_class` row.
- Mutations in scratch copies, one at a time:
  - classing by suffix: 1 FAIL;
  - the title not keyed again: 1 FAIL;
  - the key copy with no `session` strip: 9 FAIL;
  - the real list read as empty: the read guard FAILs;
  - the README pin with `session` and the word after it deleted: 1 FAIL.
- **Survived**: flipping the real loop's `fail` to `pass`. Nothing on disk
  contradicts, so no real row can show it. On a copy of `docs/dev-log/` holding
  `session-5` with its old heading and #354's `x: names its session` file, the
  unmutated section is 88 ok / 2 FAIL, naming both, and the mutated one is
  90 ok / 0 FAIL. rev-agent-162 had measured that, before this round, the loop recorded the
  `x: names its session` file as `ok`.
- The full suite at `4d81a55` printed ALL CHECKS PASSED, 8119 ok, one more
  than before: the `r162_class` row.

## Appended 2026-09-29 — review round 3 (rev-agent-162), answered in `22209ed` and the commit holding this section

### A correction to this entry's voice

CLAUDE.md asks for active voice with a named agent for errors and corrections.
This entry broke that rule in the places below. rev-agent-162 found the first
one, and the assistant's sweep of the rest of the entry found the others. The
entry cannot be edited, so each is restated here.

- *Errors on the way*, first bullet. The assistant wrote both of those FAILs:
  a line of the requirement's heredoc that opened with `written`, and a
  fixture heading citing `PR #152`. The assistant rewrapped the first and
  reworded the second.
- *Errors on the way*, the two-axis review. The four comments that claimed
  more than the code did were the assistant's. The assistant built the spec
  reviewer's narrower reading.
- Round 1, *Finding 2*. The assistant wrote the three claims that said more
  than the code. The assistant reworded two of them and added a row for the
  third. The assistant also wrote the "every spelling of a correct heading"
  sentence, and narrowed it before commit.
- Round 1, *Finding 3*. The false reds came from the assistant's time and zone
  strips, and the assistant widened them.
- Round 2, *Finding 4*. The drifted round-1 reply and README bullet were the
  assistant's, and the assistant rewrote both. The assistant also wrote the
  `check-hooks.sh` header line and the zone wording, and fixed both.
- Round 2, *#354*. The assistant wrote the real rows that classed a line by
  its end and passed the `x: names its session` file. The assistant wrote the
  unpinned `session` strip too.

### Round 3

**Finding 5, a `fail` arm nothing drove.** rev-agent-162 flipped the real
loop's `fail` to `pass`, and the mutant survived, 89 ok / 0 FAIL. The
assistant had reported that survivor in round 2 and put it down to the real
directory holding no contradiction. rev-agent-162 showed that the arm could be
driven all the same. A row printed inside `$( )` is not recorded, because
`record` returns in a subshell. So the assistant moved the loop into
`r162_rows <dir>`, which the fixtures and the real directory share. A fixture
directory holds one entry naming its session, one naming none, one
contradicting it, and #354's colon-named file. Its rows are asserted whole,
FAIL lines included. With the mutant, the section is now 90 ok / 1 FAIL.

**A sibling the assistant's own mutations found.** Deleting the real
`r162_rows` call left the section green at 15 ok / 0 FAIL. The read guard
proved that names were read, and nothing proved that rows were made from them.
`r162_rows` now counts its rows, and a row holds that count equal to the number
of names read. Without the call it is 1 FAIL.

**An error of the assistant's, found by the suite.** The first full run on
`22209ed` had 1 FAIL, GH-104.1. That check greps the suite's text for a quoted
string opening with a result's prefix. The literal the assistant wrote for the
rows fixture opened `'  ok   devlog_…`. The assistant broke that word with a
quote, as `end-of-run.sh` does for its own pattern, and said why beside it.

**Finding 6.** The assistant's header listed the rule "in the order
`r162_judge` asks it", and left out the readable-file test. The assistant has
added it, and has made the date test say that the line must carry a date at
all. On a full re-read of the header, the "THE DIRECTORY IS AN ARGUMENT"
paragraph also needed to name `r162_rows`. Nothing else was found to drift.

**Recommended, and taken.**

- Both dev-log paths now come from `REPO_ROOT`, the root `unsplit.sh` derives
  once, as GH-177 uses it.
- The read guard matches a whole name between newlines, so a stray
  `…session-5.md.orig` alone no longer satisfies it. That holds by
  construction. The one mutant run on it only shows the guard going red when
  the name it wants is absent.

**Evidence, measured.**

- The #162 section alone: 91 ok, 0 FAIL, two more than before, for the
  fixture-rows literal and the rows-made count.
- Mutations of the round-3 code, each in a scratch copy:
  - the `fail` arm flipped: 90 / 1;
  - the `none` arm flipped: 86 / 5;
  - `r162_class` by suffix: 89 / 2;
  - the real call deleted: 15 / 1;
  - `REPO_ROOT` misspelled in either path: 1 FAIL each;
  - the guard's needle replaced: 1 FAIL.
- The full suite with the quote fix in place printed ALL CHECKS PASSED, 8121
  ok.

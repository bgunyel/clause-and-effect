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

# 2026-09-17 · session 3 — #117 recommendation 4: the close was written, measured, and rejected

**Branch** `worktree-issue-117-command-word`, PR #152 into `dev-05`, third commit.
**Check suite 3868 → 3880 results, all passing.** The mutation registry goes from
26 rows to 27 — 25 real mutations against 5 files naming 34 requirement IDs, and
the two self-tests. `GH-117.1` is new and `active`: 0 refusing, 7 permitting, 5
static, `permit-only`. CLAUDE.md's *Deliberately left open* goes from five
consequences to six.

Session 2 left one thing undecided: recommendation 4 of #117's triage, a command
word that is a parameter or a command substitution. The triage called it "a
judgement call for the maintainer [that] should be settled before
implementation", and the assistant declined to take it either way.

## Bertan refused the framing, and was right to

His answer was that it is not a judgement call at all but an empirical question,
and he answered it: every Bash command from 651 local session transcripts,
74,992 of them, scanned for a command substitution in command position. He
reported `$(…)` 0, `` `…` `` 2026, `$VAR` 144, and concluded that the three
shapes recommendation 4 lumps together have nothing in common empirically — so
refuse `$(…)`, where the measured mistake rate is zero, and let an item 6 cover
the other two.

He also wrote out the strongest objection to his own recommendation, which is
that a shape with a measured mistake rate of zero offers exactly zero
mistake-protection, and CLAUDE.md says these hooks stop mistakes rather than
adversaries. He overrode it on the ground that the cost actually being paid is
re-litigation: `/usr/bin/env gh` was permitted, the next review round found it,
and `$(command -v gh)` would be found the same way — so buy the permanent close
while it costs one alternative in a regular expression that already exists.

## Two measurements, and they reversed the recommendation

The assistant re-ran the count before implementing, on the same corpus, and got
75,346 commands and 37 rather than 0. The difference was methodology and worth
chasing: `CS_WRAPPER_RE` strips assignments and prefix words before it looks, so
`cmd="echo $(…)` puts a `$(` in a command position **as the hook reads one**,
where bash would not call it one. The hook is looser than bash there, and a
count taken against bash undercounts what the rule would fire on.

So the question was re-asked with the repository's own expression rather than a
paraphrase of it — the current `CS_WRAPPER_RE`, and the same string with a `\$\(`
alternative added — and then the candidates were fed to the real hooks.

**Finding one: the close closes nothing it is named for.** The wrapper block is
an *and*. Is a wrapper in a command position, and does the line carry what this
hook guards. The alternative answers the first question; the second is answered
by patterns that want the tool's name followed by whitespace, and a command
substitution eats that boundary — the line reads `gh)`, not `gh `.

| command | before | with the `$(` alternative |
|---|---|---|
| `$(command -v gh) pr merge 5` | ALLOW | **ALLOW** |
| `$(which gh) pr merge 5` | ALLOW | **ALLOW** |
| `$(command -v gh) release create v1` | ALLOW | **ALLOW** |
| `$(command -v git) push origin main` | ALLOW | **ALLOW** |
| `$(command -v gh) api -X PUT repos/o/r/pulls/5/merge` | ALLOW | BLOCK |
| `$(echo gh ) pr merge 5` | ALLOW | BLOCK |

The two that flip are the control. The `gh api` spelling matches on the
`/pulls/…/merge` literal and needs no `gh` at all; the other is the same command
with one space added so the surface pattern can see the name. Between them they
isolate the whitespace requirement as the whole mechanism.

**Finding two: the false-positive count is not zero.** Of 75,346 commands, 88 are
newly called a wrapper and **9 change verdict**. Every one is a false refusal,
and 8 of the 9 are lines of `check-hooks.sh` being edited — for instance
`"$(printf 'sudo -u root git push --all origin\n' | cs_split)"`. The close would
have obstructed work on these very files.

## What landed instead

Consequence 6, covering all three shapes, carrying the numbers and the rejected
close. Bertan chose it once the measurements were in.

The item is held by checks in both of its halves, because neither half is enough
on its own — the document without the verdicts is a claim nobody ran, and the
verdicts without the document are three permitted commands with no reason
attached:

- Five `holds` checks on the extracted list: the three spellings by name, the
  corpus size, and the sentence recording that the close was written first. Each
  was mutation-checked by hand, all five literals removed from `CLAUDE.md` in one
  run, and each check failed by its own label; `CLAUDE.md` was restored from a
  file copy rather than from git.
- Seven permitting checks across `no-pr-decisions.sh`, `no-git-push.sh` and
  `no-commit-to-main.sh`. `GH-117.1` is `permit-only` and says why in its
  `direction` field: an accepted gap has no refusing half, and writing one would
  claim a refusal that does not happen.
- One of the 9 false refusals is kept as a check, so a later attempt at the same
  close fails in this suite rather than in a review.
- A registry row, `the-close-117-rejected`, whose edit is the close itself. It
  reported `caught`.

**That row took two goes, and the first one is worth recording.** The sed
replacement was written `\\$\\(`, which sed turns into `\$\(` in the file, which
bash then reads inside a double-quoted string as `$\(` — a `$` anchor followed by
a literal paren, an alternative that can never match. The harness said `survived`
with nothing red, and the honest reading of that was not "the check is wrong" but
"the mutation did nothing". It needed `\\\\$\\\\(` to put `\\$\\(` in the file.
Three escaping layers — the registry heredoc, sed, and the shell that reads the
expression back — and the suite was green on both sides of a mutation that was
not a mutation. That is the shape the two self-tests in the registry exist for,
and it arrived unprompted the first time a row of this kind was written.

## What this session did not settle

Nothing. Recommendation 4 is closed, and `GH-117` and `GH-117.1` are both active
and covered. `make test` is unchanged: 595 passed, 5 xfailed, and the
pre-existing `test_installed_packages_match_uv_lock` failure, which is the
virtual environment drifting from `uv.lock` and touches nothing on this branch.

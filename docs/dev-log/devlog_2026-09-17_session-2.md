# 2026-09-17 · session 2 — #117: a command word spelled as a path, quoted or escaped

**Branch** `worktree-issue-117-command-word`, proposed into `dev-05`. One commit,
cut from `origin/dev-05` at `befcf8a`. **Check suite 3657 → 3714 results, all
passing.** The mutation registry goes from 23 rows to 25 — 23 real mutations
against 5 files naming 33 requirement IDs, and the two self-tests. `GH-117` moves
from `gap → #117` to `active`, which takes requirements.md from 106 entries off
the both-directions rule to 105.

Issue #117 was found by Bertan's review of PR #115 and measured against
`origin/dev-05` d71ab1c: every hook recognised a command only by the bare name at
the start of a split command, and bash runs the same program when that name is
spelled `/usr/bin/gh`, `./gh`, `"gh"`, `'gh'` or `\gh`. All five spellings of all
seven refused shapes in the issue's table were permitted — a forced push, a
`gh pr merge`, a `gh pr create` naming no base, a bare `pytest`, a bare
`alembic`, and a commit on `main`.

## The defect had a second half, one word further left

The issue measured the ordinary rules. Measuring the wrapper rule the same way —
feeding each spelling to `no-pr-decisions.sh` on stdin, never running it — showed
the identical hole in `CS_WRAPPER_RE`: `/usr/bin/bash -c "gh pr merge 5"`,
`"bash" -c …`, `'bash' -c …`, `./bash -c …` and `\bash -c …` were all ALLOW,
where the bare `bash -c "gh pr merge 5"` is BLOCK. That is the shape CLAUDE.md's
*Deliberately left open* item 1 says is refused outright, and it was not.

It matters to the fix and not only to the count. #106's invariance families
carried the five spellings as `BLOCK:*` class rows — one row per spelling
against every refused seed of every hook — and three of those seeds are wrapped
commands. Fixing only the half the issue measured would have left those rows
declaring a departure that no longer existed for most seeds and still existed
for three, which the families' own guard refuses. The class row is what made the
second half impossible to ship without.

## Two places read a command word, and both are in the library

`cs_split` gained `cw_reduce` and `printhead`. Every candidate it emits has its
first word reduced to **the basename after unquoting and unescaping**, so the
anchors in all six hooks stay exactly as they were and get the fix without
knowing it happened. The two halves of that rule are not interchangeable:
asking instead whether the guarded name *appears in* the word would refuse
`my-gh`, which #72 decided is a different program, and asking only about a
leading path would miss the three quoting spellings.

A slash separates path components whatever quoting it is written under, so the
decision is taken on the character after unescaping and `/usr\/bin\/gh` reduces
to `gh` as `/usr/bin/gh` does.

`CS_WRAPPER_RE` gained `CS_WORD_SPELLING`. It cannot use `cw_reduce`, because it
reads raw text — a wrapper is recognised before anything is split, and the
reason it is recognised at all is that its payload cannot be read. So it admits
the same spellings as a regular expression: a run ending in a slash, or a quote
or a backslash, repeated, in front of the name. The run cannot cross whitespace
or a separator, so the command position the anchor establishes is not given up;
`ls /usr/bin/bash` offers no command position at that path and `mybash -c` reaches
the name through no slash. Both are pinned.

**What the regular expression does not reach, and `cw_reduce` does**: an escaped
slash inside the path, and a quoted span in the middle of the word — `b"a"sh`,
`/usr/"bin"/bash`. Both stay permitted in the wrapper detector while they are
refused everywhere else. Recorded rather than left to be discovered, under the
same "these stop mistakes, not adversaries" that decides the rest.

## An array of cells, and the measurement that decided it

The first version built the basename with `out = out ch`, which copies the whole
of `out` to add one character — the shape #96 found in six passes of this file
and fixed in all six. The assistant wrote it that way, noticed it before
proposing the change, and measured both versions against the suite's own
`scales_linearly` harness rather than arguing about it: the string version costs
416 ms at 128 KB and 5,310 ms at 512 KB, a ratio of 12.7 where that check fails
at 8; the array of cells costs 129 ms and 497 ms, a ratio of 3.8. A
`shape_cmdword` row now holds it, a command word that is a single quoted path
component so that nothing resets the count and the whole of it is both walked
and printed.

Measured at THE LINE CAP, `LC_ALL=C`, mawk 1.3.4, fastest of three: a 16 KB line
with no command word to reduce costs `cs_split` 6 ms, a command word of 5,460
path components 14 ms, and one quoted component of 16 KB 16 ms.

## The comment that was true of one rule and read as true of the hook

Above `GH_SURFACE_ANYWHERE` in `no-pr-decisions.sh` stood "`./gh` and
`/usr/bin/gh` still refuse", offered as the reason three narrowings of that
pattern are acceptable. It was true of the wrapper rule, which matches raw text
with a left boundary, and of nothing else in the file. The issue's *For triage*
required it corrected either way, and it now says **here** and says what was
false about the version without that word.

## What the suite gained

- **Fifteen `tok` checks** at the tokeniser seam, both directions. They are
  there rather than only at the hooks because a check through a hook cannot tell
  this transformation from the anchor being widened, and a widened anchor is how
  `my-gh` would quietly become `gh`.
- **Forty-six hook-level checks**, tagged `GH-117`: thirty-one `flip` rows from
  ALLOW to BLOCK across all six hooks and both halves of the defect, and fifteen
  permitting rows, among them the three the acceptance criteria name —
  `/usr/bin/gh pr view 5`, `"git" push origin <this worktree's branch>` and
  `/usr/bin/uv run --group test pytest tests/` — together with `my-gh pr merge 5`
  reached both bare and by path, and `mybash -c …` against the widened wrapper
  expression.
- **One `scales_linearly` row**, `shape_cmdword`.
- The five `BLOCK:*` departure rows are **gone** from #106's table. Those
  variants now reach their seed's verdict under the seed's own tags. Sixty-two
  checks added and five departure rows removed is the 3657 → 3714 the head of
  this entry reports.
- **Two registry rows**, `command-word-not-reduced` and
  `wrapper-word-spelling-not-admitted`, each read off a run of the harness and
  each reported `caught`.

Every one of the new refusing checks was measured red with `lib/command-scan.sh`
reverted to `befcf8a` and the rest of the branch in place: **151 FAILs**, of
which 41 are the new checks that move — the thirty-one flips and the ten `tok`
checks that assert a reduction — and the other 110 are the invariance variants
the departure rows had been holding down. The remaining twenty new checks are
invariants that pass on both sides of the fix, and **no permitting check failed
in that run**, which is what separates this from the hooks merely getting
stricter.

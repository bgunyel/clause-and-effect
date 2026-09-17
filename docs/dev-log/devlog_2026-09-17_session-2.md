# 2026-09-17 · session 2 — #117: a word recognised by name is the word it spells

**Branch** `worktree-issue-117-command-word`, proposed into `dev-05`, cut from
`origin/dev-05` at `befcf8a`. **Check suite 3657 → 3868 results, all passing.**
The mutation registry goes from 23 rows to 26 — 24 real mutations against 5 files
naming 33 requirement IDs, and the two self-tests. `GH-117` moves from
`gap → #117` to `active`, covered by 57 refusing, 22 permitting and 16 static
checks.

Issue #117 was found by Bertan's review of PR #115 and measured against
`origin/dev-05` d71ab1c: every hook recognised a command only by the bare name at
the start of a split command, and bash runs the same program when that name is
spelled `/usr/bin/gh`, `./gh`, `"gh"`, `'gh'` or `\gh`. All five spellings of all
seven refused shapes in the issue's table were permitted.

## The scope is the issue's triage comment, not the issue body

The assistant implemented the issue body first and only read the triage comment
after the review of this branch cited it. That was a mistake in method rather
than in code — the comment carries four extra acceptance criteria and a
measurement table two rows longer than the body's — and everything below the
next heading exists because of it. The lesson is the cheap one: on this tracker
the triage comment amends the issue, so both are the spec.

**The gap is wider than the issue body states**, in the comment's own words. The
defect is not about the command word. It is about **every word the library
recognises by name**, and there are three kinds:

- **The command word**, which the anchors read: `^git`, `^gh`,
  `^(pytest|python[0-9.]* -m pytest)`, `^alembic`, `^uv run`.
- **The prefix words** `cs_split` strips by comparing a token against a list.
  Measured ALLOW before this branch: `/usr/bin/env gh pr merge 5`,
  `/usr/bin/sudo gh pr merge 5`, `"timeout" 30 gh pr merge 5` — where the bare
  `sudo gh pr merge 5` is refused. Fixing the command word alone leaves all
  three, and the triage says what happens then: "the next review round finds it".
- **The wrapper words** in `CS_WRAPPER_RE`. `/usr/bin/bash -c "gh pr merge 5"`
  reached no wrapper rule at all, so CLAUDE.md's *Deliberately left open* item 1,
  "a wrapped command is refused outright", was false for a wrapper spelled as a
  path.

Reserved words are deliberately **not** in that set. Quoting one takes its
reserved meaning away — bash runs a program named `if` for `"if" true` — so the
control-word strip is right to stop at a bare word. The two lists are matched by
name and the reserved words are matched as syntax, and that is the whole
difference.

## One rule, three places, all in the library

`cw_reduce` reduces a word to **its basename after unquoting and unescaping**.
The two halves of that rule are not interchangeable: asking instead whether the
guarded name *appears in* the word would refuse `my-gh`, which #72 decided is a
different program, and asking only about a leading path would miss the three
quoting spellings. A slash separates path components whatever quoting it is
written under, so the decision is taken on the character after unescaping and
`/usr\/bin\/gh` reduces to `gh` as `/usr/bin/gh` does.

It is reached three ways:

- `printhead`, for the word a rule anchors on. Every candidate `cs_split` emits
  has its first word reduced, so the anchors in all six hooks stay exactly as
  they were and get the fix without knowing it happened.
- `cw_spelled`, for the prefix-word and operand-word lists.
- `CS_WORD_SPELLING`, in `CS_WRAPPER_RE`. That expression cannot call
  `cw_reduce`, because it reads raw text — a wrapper is recognised before
  anything is split, and the reason it is recognised at all is that its payload
  cannot be read. So it admits the same spellings as a regular expression, in
  front of both the prefix words and the shell name.

**What the regular expression does not reach, and `cw_reduce` does**: a quoted
span in the middle of the word — `b"a"sh`, `/usr/"bin"/bash`. Both are pinned as
accepted gaps. The comment named a second unreachable shape, an escaped slash
inside the path, until Bertan's review measured it: a backslash is not excluded
from the run, so `/usr\/bin\/bash -c "x"` matches after all. The assistant had
written that claim from the shape of the expression rather than from a
measurement of it, which is the habit this file exists to end. Both spellings are
pinned now, the one that matches and the one that does not.

## An array of cells, and the measurement that decided it

The first version built the basename with `out = out ch`, which copies the whole
of `out` to add one character — the shape #96 found in six passes of this file
and fixed in all six. The assistant wrote it that way, noticed it before
proposing the change, and measured both versions against the suite's own
`scales_linearly` harness rather than arguing about it: the string version costs
416 ms at 128 KB and 5,310 ms at 512 KB, a ratio of 12.7 where that check fails
at 8; the array of cells costs 129 ms and 497 ms, a ratio of 3.8. A
`shape_cmdword` row now holds it.

`cw_spelled` does have to build a string, because a list is matched against one,
so it is **bounded**: a name longer than 32 characters is not built at all, being
longer than any word either list holds. The walk stays linear and the build is
constant.

Measured at THE LINE CAP, `LC_ALL=C`, mawk 1.3.4, fastest of three: a 16 KB line
with no command word to reduce costs `cs_split` 6 ms, a command word of 5,460
path components 14 ms, and one quoted component of 16 KB 16 ms.

## Two claims that were wider than their evidence

Both were found by review of this branch, and both are the #84 shape in
miniature — a sentence true of one rule reading as true of all.

- The comment above `GH_SURFACE_ANYWHERE` in `no-pr-decisions.sh` said "`./gh`
  and `/usr/bin/gh` still refuse", offered as the reason three narrowings of that
  pattern are acceptable. It was true of the wrapper rule and of nothing else in
  the file. It now says **here**, and says what was false about the version
  without that word.
- The assistant's own new comments said the defect was measured "in every hook
  there is". The issue measured five, and says so of the sixth:
  `no-work-on-stale-branch.sh` "was not measured, since it needs a stale-branch
  fixture". That hook reads its git commands through the same `^git` anchor, so
  it had the defect too; it had no `GH-117` check until the review asked, because
  #117's own section stands above the line where `$WT_STALE` is built. Four flips
  and two permitting checks now sit beside that fixture.

## An over-refusal, recorded rather than fixed

Reducing **every** tail candidate the prefix strip offers — not only the first —
is what makes `sudo /usr/bin/git push` visible. It also turns a path-shaped
*argument* into a name a rule reads: `sudo cp /usr/bin/pytest /tmp/` is now
refused by `pytest-via-uv-group.sh`, where the same command without the prefix
word offers no tail at all and is permitted. Refusing direction, so it is taken
rather than fixed — telling an argument from a command word there is the shell
parser the stopping rule in these files refuses to write — but it is written down
at the call site and both verdicts are pinned, because a refusal nobody wrote
down reads as a defect to whoever meets it.

## What the suite gained

- **Fifteen `tok` checks** at the tokeniser seam, both directions. They are there
  rather than only at the hooks because a check through a hook cannot tell this
  transformation from the anchor being widened, and a widened anchor is how
  `my-gh` would quietly become `gh`.
- **Hook-level checks against all six hooks that read a command**, tagged
  `GH-117`, in both directions — the five spellings of every row of both tables,
  the prefix-word and wrapper-word spellings, `g"h"`, `~/bin/gh`, and the
  permitting rows the criteria name: `/usr/bin/gh pr view 5`, `"git" push origin
  <this worktree's branch>`, `/usr/bin/uv run --group test pytest tests/`,
  `my-gh`, `my_gh`, `mybash -c …`, `sudo apt-get install jq` and
  `/usr/bin/env python3 -c …`.
- **Transformation 13** in #106's families, `pre-sudo-path pre-env-path
  pre-timeout-quoted`, which is the triage comment's last criterion. The wrapper
  words need no row of their own: a wrapped seed carries the wrapper *as* its
  command word, so transformation 11 already rewrites it.
- The five `BLOCK:*` departure rows are **gone**. Those variants now reach their
  seed's verdict under the seed's own tags.
- **Three registry rows** — `command-word-not-reduced`,
  `wrapper-word-spelling-not-admitted` and `prefix-word-spelling-not-reduced` —
  each read off a run of the harness and each reported `caught`.

With `lib/command-scan.sh` alone reverted to `origin/dev-05` and the rest of the
branch in place, **246 checks go red**, 70 of them named checks and the rest
invariance variants. **No permitting check fails in that run**, which is what
separates this from the hooks merely getting stricter.

## Left for Bertan: recommendation 4

The triage comment raises one thing it explicitly declines to decide, and calls
it "a judgement call for the maintainer [that] should be settled before
implementation":

> **A parameter or command substitution in command position** (`$(…)`,
> `` `…` ``, `$VAR`) cannot be resolved from text.

`$(command -v gh) pr merge 5`, `` `command -v gh` pr merge 5 `` and
`$GH pr merge 5` are **permitted today and still permitted on this branch**. The
two answers the comment offers are to refuse such a line when it also carries
what the hook guards — a refusal is visible where a silent permit is not — or to
record a sixth numbered item in CLAUDE.md's *Deliberately left open*, which would
change the count that section says went stale last time. The assistant took
neither, because taking either without asking would be deciding it; the gap is
named in `requirements.md` under `GH-117` so that it is on the record rather than
implied by the absence of a check.

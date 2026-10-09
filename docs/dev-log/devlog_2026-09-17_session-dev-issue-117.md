# 2026-09-17 · session dev-issue-117 — #117 and PR #152: a word recognised by name is the word it spells

This file holds three entries written on 2026-09-17 by the session named
`dev-issue-117`, in the order they were written. They were first committed as
`session-2`, `session-3` and `session-4`, renumbered `session-7`, `session-8` and
`session-9` when they collided with #143's and #108's entries on the first merge
of `dev-05`, and collided again when #137's entries took 7 and 8. `db06477`
replaced day-numbering with the writing session's name, so the three now share
one file. Each keeps its own heading and its text unchanged apart from heading
levels, so every count inside a part is the one that stood at that part's commit
— 28 registry rows and a suite of 3903 at the end of Part 3, against 39 rows and
4346 results after the first merge of `dev-05`.

## Part 1 — #117: a word recognised by name is the word it spells

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

### The scope is the issue's triage comment, not the issue body

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

### One rule, three places, all in the library

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

### An array of cells, and the measurement that decided it

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

### Two claims that were wider than their evidence

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

### An over-refusal, recorded rather than fixed

Reducing **every** tail candidate the prefix strip offers — not only the first —
is what makes `sudo /usr/bin/git push` visible. It also turns a path-shaped
*argument* into a name a rule reads: `sudo cp /usr/bin/pytest /tmp/` is now
refused by `pytest-via-uv-group.sh`, where the same command without the prefix
word offers no tail at all and is permitted. Refusing direction, so it is taken
rather than fixed — telling an argument from a command word there is the shell
parser the stopping rule in these files refuses to write — but it is written down
at the call site and both verdicts are pinned, because a refusal nobody wrote
down reads as a defect to whoever meets it.

### What the suite gained

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

### Left for Bertan: recommendation 4

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

## Part 2 — #117 recommendation 4: the close was written, measured, and rejected

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

### Bertan refused the framing, and was right to

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

### Two measurements, and they reversed the recommendation

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

### What landed instead

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

### What this session did not settle

Nothing. Recommendation 4 is closed, and `GH-117` and `GH-117.1` are both active
and covered. `make test` is unchanged: 595 passed, 5 xfailed, and the
pre-existing `test_installed_packages_match_uv_lock` failure, which is the
virtual environment drifting from `uv.lock` and touches nothing on this branch.

## Part 3 — the review of PR #152: the wrapper rule asks two questions

**Branch** `worktree-issue-117-command-word`, PR #152 into `dev-05`, fourth
commit. **Check suite 3880 → 3903 results, all passing.** The mutation registry
goes from 27 rows to 28 — 26 real mutations against 5 files naming 34 requirement
IDs, and the two self-tests.

A review session went over the branch read-only and returned five findings, with
the verdict that there is no permitting regression: a differential harness over
about 400 commands and a 300-case quoting fuzz produced no BLOCK→ALLOW flip, and
the `cw_reduce`/`printhead` core is sound. Every one of the five was reproduced
here before anything was changed.

### The two that matter: #117 closed three sites of four

The wrapper rule is an **and**. Is a wrapper in a command position — that is
`CS_WRAPPER_RE`, shared, and this branch had already taught it the five
spellings. And does the line carry the surface this hook guards — that is **each
hook's own pattern**, four of them, and every one matched its guarded name by the
bare spelling only.

So the quoting half of #117 leaked at exactly the place the wrapper rule exists
to close:

| command | before this session |
|---|---|
| `bash -c "gh pr merge 5"` | BLOCK |
| `bash -c '"gh" pr merge 5'` | **ALLOW** |
| `bash -c "'gh' pr merge 5"` | **ALLOW** |
| `bash -c '"git" push --all origin'` | **ALLOW** |
| `bash -c "/usr/bin/gh pr merge 5"` | BLOCK |
| `bash -c "\gh pr merge 5"` | BLOCK |

The path and backslash spellings already passed, because those patterns carry a
left boundary that admits `/` and `\`. It is quotes alone that never produce the
name-then-whitespace the patterns wanted — the half `cw_reduce` exists for.

Worse than the gap: the assistant had flipped `GH-117` to `status: active` with
text claiming quoted spellings reach the bare-name verdict **in every hook**.
That was false at four sites and pinned by no check. A requirement asserting more
than its checks establish is the failure this file is most often about, written
by the session that had just spent two rounds on it.

**Measured before the fix was taken**, which is the only reason it was taken:
across the 476 wrapper-carrying commands in a 75,346-command corpus, widening all
four patterns to admit a quoted name changed **no verdict at all**. That is the
contrast with recommendation 4 one session earlier, where the proposed close was
measured and closed nothing — here the close works and costs nothing.

The class is written out in each of the four rather than shared from the library.
A shared variable that came back empty would degrade all four to their old
spelling silently, in the permitting direction, and no guard can tell an empty
variable from a narrow one — which is the argument `THE WORD LIST IS PART OF THE
LOAD` already makes one level down. What holds the four together instead is a
derivation: `check-hooks.sh` reads the boundary set off `settings.json` and asks
every hook in it whether it carries the class, so a fifth boundary hook is asked
without anyone revising a sentence. That is #84's lesson applied at the point
where this session had just repeated #84's mistake.

`g"h"` stays open — a quoted span in the *middle* of the word, which a character
class cannot see and a quoted payload gives no word to reduce. It is the same
accepted gap `CS_WORD_SPELLING` names one level up, and it is pinned.

### The other three

- **Consequence 6 gave an example that its own commit refused.** It offered
  `"$VENV/bin/gh"` as a permitted `$VAR` shape; the reduction resets at each
  slash, so the word spells `gh` and is refused. The item now draws the line
  where the behaviour draws it — a variable is unresolved only while it is the
  **whole word** — and both verdicts are pinned. `requirements.md` had it right;
  it was the prose that was wrong.
- **A registry row mutated the wrong occurrence.** `wrapper-word-spelling-not-admitted`
  was written as `/^CS_WRAPPER_RE=/s/[$]CS_WORD_SPELLING//`, and the same session
  then added a second `$CS_WORD_SPELLING` to that line for the prefix words. With
  no `g` flag, `sed` takes the first, so the row named for the wrapper word broke
  the prefix word instead — and still reported `caught`, because both make
  `GH-117` checks red. A row can be wrong in the permitting direction while
  reporting exactly what the registry expects, which is what the `selftest-`
  rows are about, arriving here as an ordinary defect. It is anchored on
  `SPELLING((ba|z|)sh` now, which is unique.
- **The path spelling reaches into quoted text.** `CS_WRAPPER_RE`'s spelling
  prefix has no idea what a quote is, so a `sed` script whose *pattern* names a
  wrapper is now read as one: `sed -i 's|/bin/sh -c git push --all origin|X|'
  hooks.sh` was permitted at `origin/dev-05` and is refused here. Refusing
  direction, one edit away, and in the same family as consequence 3 — a hook
  cannot tell a command from prose that quotes one. Recorded and pinned in both
  directions rather than fixed.

### Evidence

- Suite 3880 → 3903, all passing. With `lib/command-scan.sh` alone reverted to
  `origin/dev-05` and the rest of the branch in place, **249 checks go red and no
  permitting check does**.
- `wrapper-word-spelling-not-admitted` and the new
  `wrapper-surface-quotes-not-admitted` both report `caught` off a run.
- `make test`: 595 passed, 5 xfailed, and the pre-existing
  `test_installed_packages_match_uv_lock` failure, which is the virtual
  environment drifting from `uv.lock` and touches nothing on this branch.

### What this session did not do

It did not re-open recommendation 4. The review did not contest it, and nothing
measured here bears on it.

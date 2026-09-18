# 2026-09-17 · session 9 — the review of PR #152: the wrapper rule asks two questions

**Branch** `worktree-issue-117-command-word`, PR #152 into `dev-05`, fourth
commit. **Check suite 3880 → 3903 results, all passing.** The mutation registry
goes from 27 rows to 28 — 26 real mutations against 5 files naming 34 requirement
IDs, and the two self-tests.

A review session went over the branch read-only and returned five findings, with
the verdict that there is no permitting regression: a differential harness over
about 400 commands and a 300-case quoting fuzz produced no BLOCK→ALLOW flip, and
the `cw_reduce`/`printhead` core is sound. Every one of the five was reproduced
here before anything was changed.

## The two that matter: #117 closed three sites of four

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

## The other three

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

## Evidence

- Suite 3880 → 3903, all passing. With `lib/command-scan.sh` alone reverted to
  `origin/dev-05` and the rest of the branch in place, **249 checks go red and no
  permitting check does**.
- `wrapper-word-spelling-not-admitted` and the new
  `wrapper-surface-quotes-not-admitted` both report `caught` off a run.
- `make test`: 595 passed, 5 xfailed, and the pre-existing
  `test_installed_packages_match_uv_lock` failure, which is the virtual
  environment drifting from `uv.lock` and touches nothing on this branch.

## What this session did not do

It did not re-open recommendation 4. The review did not contest it, and nothing
measured here bears on it.

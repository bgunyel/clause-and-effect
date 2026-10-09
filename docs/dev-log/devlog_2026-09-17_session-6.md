# 2026-09-17 · session 6 — #133: a refused retarget now names the retarget that would correct it

**Branch** `worktree-issue-133-retarget-correction`, cut from `origin/dev-05` at
`befcf8a` and proposed into `dev-05`. **Check suite 3657 → 3659 results, all
passing.** The mutation registry goes from 23 rows to 24 — 22 real mutations
against 5 files naming 33 requirement IDs, and the two self-tests — and
`requirements.md` from 144 active requirements to 145, GH-133 having stopped
being a gap.

Issue #133 was filed out of Bertan's review of PR #142, which asked why a check
pinning `no-pr-decisions.sh`'s retarget refusal was tagged US-7. It should not
have been, and #105 untagged it rather than pinning a verdict there was reason to
think wrong — #103's Q18, the same reasoning that filed #130 and #131. This
session closes the underlying defect.

## The defect, restated from the issue

US-7 asks that a refusal tell an agent the permitted spelling *so that it can
correct itself in one step*. `no-pr-decisions.sh` holds one `BASE` constant and
appends a per-arm tail, so all four base refusals name the same spelling,
`gh pr create --base dev-NN`. For the three creating arms that is the one-step
correction. For a refused **retarget** it is not: retargeting to the active dev
branch is permitted, so the correction to

```
gh pr edit 5 --base main
```

is

```
gh pr edit 5 --base dev-05
```

— one word of the command already written. The message instead named a create,
which is not a correction of that command at all: acted on literally it leaves
the mis-targeted pull request open and opens a second beside it. The old tail's
second sentence, "Edit anything else you like", made it worse rather than
repairing it: read against a refusal whose subject *is* the base, it says the
base is the one thing that may not be edited, when editing it to `dev-NN` is
exactly what is allowed.

## What was changed, and what was deliberately not

The constant was not split. FR-23 asks the base rule's messages to name the
permitted spelling *consistent with the existing ones*, and #40 was filed
because a rule held for `gh pr create` and not for `gh api`; one sentence for
four refusals is how that consistency is kept, and it is a requirement in its
own right. So the same fact was evidence **for** FR-23 and **against** US-7, and
the fix had to keep the first while answering the second.

The tail was already per-arm. It is the retarget arm's tail that was written
about the destination rather than about what to write next, and that is the one
line the fix moves:

```
Retargeting to main chooses that destination just as creating it there would.
Retarget to the active dev branch instead: gh pr edit <n> --base dev-NN. No
other edit is checked here.
```

Three decisions inside that, taken by the assistant and recorded here because
each rejected something:

- **`<n>` rather than the pull request's number.** The bare-push refusal in
  `no-git-push.sh` interpolates `$CURRENT`, and the precedent argues for reading
  the number out of the command and naming it. It was not done: `dev-NN` stays a
  placeholder either way — the hook's rule is `^dev-[0-9]+$` and it does not
  know which dev branch is active — so interpolating the number would buy half a
  copy-pasteable command at the cost of a new argument reader in a guard file.
  The rule that decides a command is not worth widening to improve the prose of
  a message.
- **"No other edit is checked here" in place of "Edit anything else you like".**
  The replaced phrase was not joined by the new sentence, it was removed. The two
  read against each other: one sentence naming the permitted base beside another
  saying the base may not be edited is US-7's guessing with a step added. What is
  true and worth saying is that this arm reads the base and nothing else.
- **Message content is #109's, and #109 is still open.** #133 is the defect in
  one message; #109 is the suite-wide question of whether every refusal in these
  two files is read for its words. The `note` on GH-133 now says so explicitly,
  so closing #133 does not read as closing that.

## The checks

Written first, run red, then the hook changed — the two new rows were the only
failures in the suite, and they failed for the text they name rather than for a
verdict. The `#105: a refusal names the permitted spelling` section now carries
three retarget rows where it carried two:

| row | tags | what it pins |
|---|---|---|
| the constant | `FR-23` | `Write: gh pr create --base dev-NN` appears in a retarget refusal |
| the tail, first half | `FR-23` | `Retargeting to main chooses that destination` — which branch was named |
| the tail, second half | `US-7 FR-23 GH-133` | `Retarget to the active dev branch instead: gh pr edit <n> --base dev-NN` |
| and a `says_not` | `US-7 FR-23 GH-133` | the refusal does **not** say `Edit anything else you like` |

The constant row stays tagged `FR-23` alone, and the reason survives the fix
unchanged: the create spelling is still not a retarget's one-step correction, so
that row is still not US-7 evidence. What changed is that US-7's half is now
carried by a row of its own rather than going uncovered.

The fragment pinned is the whole spelling and not the word `retarget`. A message
naming the act without naming what to write is the guessing US-7 exists to end,
and a check reading only the verb would stay green through exactly that
regression.

## Whether those checks can fail

A registry row was added beside `base-refusal-drops-the-spelling`, which is its
analogue for the constant:

```
retarget-refusal-drops-the-retarget-spelling%no-pr-decisions.sh%s/Retarget to the active dev branch instead: gh pr edit <n> --base dev-NN\. //%US-7 FR-23 GH-133%caught
```

Run on its own, it reported `caught`, with `FR-23 GH-133 US-7` all red, and
`.claude/hooks/` came back byte-identical to what it was. The whole registry was
not re-run — forty-five minutes, and the other twenty-one rows are untouched by
this change — so this entry's claim is about the one row it ran and about nothing
else.

Three literals moved with it, each written down twice on purpose so that the
second copy is what a reviewer sees move in the diff: `check-hooks.sh`'s registry
size (23 → 24) and its count of rows expected to be caught (21 → 22), and
`mutate-hooks.sh`'s own prose (twenty-one real mutations → twenty-two,
thirty-two requirement IDs → thirty-three, 144 active requirements → 145).
`--list`'s last line was read after the edit and agrees with all three.

## The requirement

`GH-133` was already in `requirements.md`, carried by #105 as `status: gap →
#133` so the matrix would report it as a known, filed gap rather than as covered.
It is now `status: active` with `direction: refuse-only` — a message exists only
on a refusal, as US-7 and FR-23 themselves declare — and `REQUIREMENT_SHAPE` in
`check-hooks.sh` moves `GH-133:gap` to `GH-133:refuse-only` to match. The entry's
`text` gained the second half of the requirement, that the message must not also
say the base is the one thing that may not be edited, because the `says_not` row
establishes it and a requirement's text is what a tag is read against.

## Verification

- `bash .claude/hooks/check-hooks.sh` — 3659 results, ALL CHECKS PASSED.
- `bash .claude/hooks/mutate-hooks.sh -v retarget-refusal-drops-the-retarget-spelling`
  — `caught`, hooks directory byte-identical afterwards.
- `bash .claude/hooks/mutate-hooks.sh --list` — 24 rows, 22 real mutations
  against 5 files, naming 33 requirement IDs, and 2 self-tests.
- The two commands fed to the hook on stdin rather than run:
  `gh pr edit 5 --base main` exits 2 with the new message, and
  `gh pr edit 5 --base dev-05` exits 0, which is the spelling the message now
  names.

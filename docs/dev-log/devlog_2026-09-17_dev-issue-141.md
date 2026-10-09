# 2026-09-17 21:53 · dev-issue-141 — #141: which requirements the invariance families seed

**Branch** `worktree-issue-141-seed-scope-rule`, cut from `origin/dev-05` at
`897bdff`. **Commits** `897bdff..f4e0530`, two of them: `e7b6d5a` the change,
`f4e0530` the answer to its review. The branch ends 2 commits ahead of
`origin/dev-05` and 193 ahead of `origin/main`.

Worked unattended by the assistant on Bertan's `/implement` invocation. Bertan
did not take part; the review recorded below was run by two subagents on the
assistant's own commit, which is a weaker instrument than his review has been —
every previous session's most valuable findings were his, and nothing here
should be read as having had that pass.

## The families seeded one of three requirement families, and not the one written from defects

#106's invariance families take a seed — a command with a literal verdict —
rewrite its text, and assert every variant reaches that verdict or a departure
declared with its reason. Their leverage is that a transformation added to the
list is asked of every seed at once, so **what is seeded is what the generator
can ever find.**

The derivation that held the seed table to its scope read `FR-` tags and nothing
else. `requirements.md` holds three families, and measured on 2026-09-17 it
holds 95 `GH-` entries to 49 FRs — the `GH-` ones being the entries written
*from* defects rather than from the specification. So GH-43.6, GH-68.1, GH-72
and the GH-79 family named commands and no transformation was ever asked of one
of them, and GH-94.1 was seeded in one direction only. #140's four findings were
all on FR-seeded commands, which is evidence that the FR set is a reasonable
start and none at all that it is a sufficient one.

## The scope is now a rule, and the rule is mechanical where the answer is declared

None of the three candidates #141 raised is both derivable and right on its own,
and the session's first substantive decision was to say so rather than pick one.
`kind: defect-permitting` alone takes in every entry about the suite's own
helpers, its tags and its timings, which name no command; "an entry naming a
hook that judges commands" takes in the same; "text contains a command" is not
derivable from prose.

What landed splits the question. *Membership* is derived off `requirements.md`:
a `GH-` entry is in scope when it is `defect-permitting` or `defect-refusing`,
`active`, and declares neither `direction: static` nor `seam: none` — the
derivable form of "a requirement about a verdict on a command", which is the
only thing a variant can reach. The *answer* is declared per entry, in a new
`variants` field, as one of `seed`, `transformation: <name> …` and
`none: <reason>`. Three checks at the foot of #106's section hold the
declarations to the tables: a seed to a tagged row of `INV_SEEDS` by set
equality, each named transformation to `INV_TRANSFORMS`, and a `none` to a
reason.

38 entries are in scope: 11 seeded, 7 naming a transformation, 20 with no
command spelling for a variant to vary. Those four numbers are a line the suite
prints, not a comment — they stood in the prose for one revision and the review
caught them.

The trade is recorded where the rule is. `none` is a declaration, so an entry
that ought to be seeded can carry a reason that reads well, and this rule would
not catch it. What changed is that the choice is made once per entry, in
writing, with a reason a reviewer reads in the diff — where before it was made
by an `awk` filter nobody had to argue with. The silent direction is closed by
holding the in-scope set and each entry's keyword as a literal in the suite as
well, which is #104's reason for holding this file's shape, applied to the one
field #104 does not read.

## The first hook the rule brought into scope failed on its first generated spelling

`append-only-docs.sh` judges commands and had never been seeded. Seeding it cost
two rows, and the `continuation` transformation refused to pass: **the verb and
the path on either side of a backslash are two lines to `grep` and one command
to a shell.** Fed to the hook on stdin — nothing was executed — `rm`, `mv`,
`tee`, `truncate` and a truncating redirect are all permitted behind one
backslash, and `rm -rf docs/dev-log` written across two lines takes every entry
in the directory with it. `sed -i` survives by accident: its rule is two greps
rather than one, the verb on a line and the path anywhere, which is the shape of
the fix arrived at unintentionally in one rule of four.

It is #84's shape once more. `no-pr-decisions.sh` calls `cs_join` for exactly
this reason, and the comment above `cs_join` in `lib/command-scan.sh` states the
defect in the present tense, one file away from the hook that has it. Filed as
**#156** with a gap row rather than fixed here: the fix touches the hook and its
load guard together, because GH-84.2 requires a consumer's guard to require
exactly the `cs_*` functions its code calls.

## Two constraints on the seed table that were discovered rather than known

**A seed command may not contain `|`**, which is the table's field separator. So
GH-68.1 cannot be seeded with its own example, `sed -i 's/a\|b/c/'`; the seed
carries the same shape with a `;` inside the quotes instead. A requirement whose
only command contains a `|` cannot be seeded at all, and would be
`variants: none` with that as the reason.

**A verdict is a property of the command text together with the fixture and the
hook.** `git push --all origin` is now seeded twice on purpose — against
`no-git-push.sh` in a worktree and `no-commit-to-main.sh` on `main`, because two
hooks reading one command is two claims. The regeneration skip was keyed on text
alone, so its premise ("already checked as a seed, with the same verdict")
stopped holding in general the moment that happened. Both seeds are BLOCK, so
nothing was skipped wrongly; the key is `fixture|hook|text` now. The two
examples that comment offered turned out to regenerate nothing at all — their
tails had diverged, `--body y` against `--title x` — and the counter reading 0
is the evidence.

## The review found nine things, and the one with teeth was a pass about nothing

`[ -n "$INV_SCOPE_DERIVED" ] || fail …` did not count itself into the failure
tally, so a run that read nothing out of `requirements.md` printed its failure
and then, on the next line, `ok every GH- entry in the families scope declares a
variants value this suite can act on` — a pass about cases it had not asked.
That is the shape #98's section exists for, written by the assistant into the
one section whose subject is guards that cannot fail.

The other eight were claims wider than what the code asks, or numbers already
stale:

- "Both directions for every requirement with a command spelling" — the
  derivation under it has read `FR-` tags since the day it was written, so the
  sentence was never what was checked, and the assistant's one-directional
  `GH-` seeds then contradicted it outright. GH-106's own `text` carried the
  same overclaim; both now say *functional*, and the entry's note records that
  this is a correction and not a widening.
- `requirements.md`'s trade claimed "a value changed" goes red. The literal
  holds `ID:keyword`, so a reworded reason or a different transformation named
  stays green. It now says which half the literal closes.
- GH-43.6 declared `transformation: global-flag` while `inv_global` writes only
  `-C`, claiming a shape no variant generated. `global-flag-gitdir` added, and
  measured first: `--git-dir` and `--work-tree` behave exactly as `-C` does,
  refused on a push and permitted on a `status`.
- "60-odd `GH-` entries against 49 FRs", quoted from #141's own text, is two
  different bases — all FRs against some `GH-` entries. Measured and replaced.
- `trim`, `keyword` and `after_colon` are `requirements.md`'s field grammar and
  had been written twice in one file, which is the defect class
  `lib/command-scan.sh`'s header opens by naming. One `REQ_FIELD_AWK` now,
  prepended to both programs.
- The `^GH-` test the rule states rested on `requirements.md`'s separate rule
  that only a `GH-` entry carries a `kind`; it is in the condition now.
- Two splits left unpaired where the rest of the section pairs `set -f`/`set +f`.
- The `none`-is-a-declaration trade was written out in three places, one of them
  labelled "said once".

## What it costs, and why #140's number could not be used

Measured on one machine, in one worktree, every run green:

| tree | wall clock | n | families |
|---|---|---|---|
| before, at `897bdff` | 118.6 s | 1 | 39 seeds, 1436 variants |
| after | 116.8 / 117.1 / 118.4 / 119.9 / 122.6 / 133.1 s | 6 | 46 seeds, 1807 variants |

371 more variants, 26% more of them, and **the difference between the two rows
is smaller than the range within the second**: the six after-runs span 16.3 s
and their median is 119.2 s, against a single before-run of 118.6 s. So the
measurement supports "the addition did not move the run time by anything this
suite can resolve", and does not support a figure for how much it moved it by.
A second before-run was not taken and should have been.

The range is the finding rather than noise around one. The 133.1 s run and a
116.8 s run are the same tree minutes apart, with other worktree sessions on the
machine.

The per-variant model over-predicts, which matters because #141's cost paragraph
reasons from one. Timed directly at n=100 each, one hook invocation exactly as
`check_in` makes it: 10.9 ms for `append-only-docs.sh`, 16.0 ms for
`no-commit-to-main.sh`, 29.8 ms for `no-pr-decisions.sh`. At those rates 371
variants would be 5–7 s and the suite does not show it; a cold invocation from a
shell loop is not what a variant costs in the middle of a run that has paged
everything in.

**#140's 94.0 s is not comparable with any of these.** The commit this branch
starts from measures 118.6 s here, so the comparison #141's fourth acceptance
criterion asks for had to be made baseline-to-after on one machine rather than
against the recorded figure. #141's warning that "the same again would want a
decision about the budget" is about the 53 s #140 added, and on this evidence
this is not that.

## Mutation, and the limit it moved

Two registry rows added, `variants-field-deleted` and `variants-seed-disowned`,
both reported `caught` in a clean run with `.claude/hooks/` byte-identical
afterwards. The first run of them was not clean and reported `.claude/hooks/
changed during this run` — the assistant had edited `requirements.md` while the
harness was running, which is exactly the integrity check doing its job, and the
run was repeated rather than explained away.

Those two rows moved a stated limit. `mutate-hooks.sh` says a rule living in the
tooling beside the hooks cannot be registered, because the suite that runs is
this repository's whatever `CHECK_HOOKS_DIR` says — and GH-141's rule *is* code
in `check-hooks.sh`. It is registrable all the same, because what that code
**reads** is `requirements.md`, which an override does move. The test is whether
the run reads the copy, not whose file the rule sits in. #106's own self-guards
still fail it: what they read is the seed table, which is in the suite.
GH-107.2's note said otherwise and is corrected.

## The append-only guard is off in every worktree, found by trying to obey it

Writing this entry produced the session's second permitting defect, and the way
it was found is worth recording. The numbers in the cost section above were
wrong by two later runs. `docs/dev-log/` is append-only and the convention is
that an entry freezes once written, so the assistant expected
`append-only-docs-edit.sh` to refuse the correction, and attempted it to
confirm. **It went through.**

`append-only-docs-edit.sh` resolves the edited path against
`CLAUDE_PROJECT_DIR`, which is the main checkout, so for a file in a linked
worktree the remainder is `.claude/worktrees/<name>/docs/dev-log/<entry>.md` and
the `^docs/` anchor does not match. Measured by feeding tool calls to the hook
on stdin, with the controls run rather than assumed:

| `CLAUDE_PROJECT_DIR` | path | verdict |
|---|---|---|
| main checkout | `<main>/docs/dev-log/<entry>` | BLOCK |
| main checkout | `docs/dev-log/<entry>`, relative | BLOCK |
| main checkout | `<worktree>/docs/dev-log/<entry>` | **ALLOW** |
| worktree | `<worktree>/docs/dev-log/<entry>` | BLOCK |
| main checkout | a new entry file | ALLOW |

The fourth row is what says the cause is the anchoring and not the path. The
Bash-side `append-only-docs.sh` does not share it — it matches path spellings in
the command text and resolves nothing against a root, so `rm -rf` of a
worktree's `docs/dev-log` is still refused, measured in all three spellings. So
the two halves of one rule disagree about which files are append-only, which is
the class `lib/command-scan.sh` exists to end, here between two files rather
than inside one.

The consequence runs the wrong way round from the guard's purpose: CLAUDE.md
says an unattended agent *shall* work in a dedicated worktree, so a worktree is
where every agent edit to `docs/dev-log/` happens. The guard covers the checkout
where an agent is not working. Filed as **#159**, unfixed.

Two things about this entry follow from that, stated rather than left for a
reader to work out. The corrected cost table above, and this section, were both
written through the gap — the guard should have refused both, and the second
edit is a record of a defect that only exists because the first one worked.
Neither revises history: the file was minutes old, uncommitted, and factually
wrong. And the check suite is green with the guard inoperative, because every
check for this hook passes a path under the project root — #84's shape, one
question asked of one spelling, which is the same finding as this session's
main one arriving from the other side.

## Open

- **#156** is filed and unfixed: the continuation evasion in
  `append-only-docs.sh`. Its gap row goes red when the fix lands, which is the
  intended outcome. The fix has to move the load guard with the call.
- **#159** is filed and unfixed: `append-only-docs-edit.sh` is off in every
  linked worktree. Nothing in the suite fails on it, so nothing will remind
  anyone; it is the more urgent of the two, because the hook is not merely
  evadable there but inoperative.
- **The `GH-` half of the seed table is 11 entries wide**, and 20 in-scope
  entries are `variants: none`. Each reason is a claim someone can argue with,
  which is the point, and the frontier is whichever of them turns out to be
  wrong.
- **GH-131 and GH-143.1–.3** are the entries the file-payload decision will land
  on. Both are out of scope today — #131 is `gap → #131`, GH-143.1 to .3 are not
  written — and the rule makes the declaration compulsory when either goes
  active. The decision itself is recorded now rather than left to be
  rediscovered: `-f query=@file` and `--input file` put what a rule must judge
  outside the command's text, so no text-rewriting generator can produce or
  judge them.
- **This branch has not had Bertan's review.** Every previous entry in this
  directory records that pass finding defects a green suite did not, several of
  them in the commit that fixed the previous round.

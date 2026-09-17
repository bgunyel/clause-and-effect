# 2026-09-17 · session 1 — Bertan's review of #142: the text checks were reading the wrong directory

**Branch** `worktree-issue-107-mutation-harness`, still proposed into `dev-05`.
Session 3 of 2026-09-16 left one commit on it, `efa681f`; this session adds a
second, so the branch is two ahead of `origin/dev-05` and 183 ahead of
`origin/main`. **Check suite 3637 → 3657 results, all passing.** The mutation
registry goes from 10 rows to 23 — 21 real mutations against 5 files naming 32
requirement IDs, and the two self-tests — and a full harness run from ten runs of
the suite to twenty-three, measured at **45 min 24 s**.

Bertan reviewed PR #142 at its head against `origin/dev-05` — nine finder
angles, 31 candidates, three verifier passes — and returned ten findings, six
lower-severity ones, and the verdict *not mergeable as is*. None of them was a
wrong result: the suite was green, every registered mutation had behaved, and
`.claude/hooks/` came back byte-identical. What the review found is that several
of those greens were not evidence of what the pull request read them as.

## Forty-four bare file names, which were sixty-nine

`armed`, `unarmed` and `written` take a file path and grep it. Forty-four calls
passed a bare name — `no-git-push.sh`, `lib/command-scan.sh` — which resolves
against the process's working directory. That directory is `$SUITE_DIR` and
stays `$SUITE_DIR` under an override, so every one of those checks read this
repository's own hooks and said nothing whatever about the copy under judgment.
The review reproduced it: a copy with `command -v cs_normalise` removed from
`no-git-push.sh` and an unguarded `. "$(dirname "$0")/lib/command-scan.sh"`
appended still printed `ok armed no-git-push.sh requires cs_normalise` and `ok`
for the pin that says it does not source the library unguarded. That is #84's
defect exactly, in the section written to catch #84's defect, with nothing
watching.

Counted here before it was fixed, the number was sixty-nine rather than
forty-four. The review named seven line ranges and the ranges were right:
sixty-one of the sixty-nine are inside them, and the other eight sit one or two
lines outside a boundary. The difference is a count taken by reading against one
taken by parsing every call in the file with its continuation lines joined, and
it is the same kind of difference as the one two sections below is about. All
sixty-nine now spell `"$HOOKS/<name>"`.

Two things hold them there, because one of them is not enough:

- **A derivation over this suite's own text**, in the #107 section. It joins
  continuations, cuts each call into shell words and asks the third. A name
  ending `.sh` has to sit under `$HOOKS` if it is a hook and under `$SUITE_DIR`
  if it is one of the two files beside them that are not hooks. "It must be a
  variable" was the assistant's first version and is not enough: it accepts
  `"$SUITE_DIR/no-git-push.sh"`, which is the same defect one door along.
- **A guard inside the three helpers**, `absolute_or_fail`, which refuses a
  relative path at the moment the file is read. This was not in the first
  version of the fix and had to be, because the derivation reads text and cannot
  see through a variable — and one call site was `armed "$hook requires
  cs_tool_input" "$hook" ...`, a bare name held in a loop variable, which the
  assistant's rewrite skipped and the derivation passed. The suite being green
  with that guard in place is the evidence that no call site names a file
  relatively; before it, nothing said so.

## Twenty-one rules with no row, which was #107's acceptance criterion

The registry held eight real mutations. The review measured what #105 and #106
had tagged — 40 IDs, of which the registry named nine — and found 21 of the
remainder to be hook rules the harness can reach and simply had no row for: the
whole base rule (`FR-14`–`FR-21`, `US-8`–`US-12`), the release allowlist, the
stale-branch fallback, the convention hooks' command-position judgement, the
main-checkout recognition, and the three push stories. Break the base rule so
that `--base main` is accepted and the harness stayed green, because no row
named `FR-15`.

Thirteen rows were added, and the registry now holds twenty-one real mutations
against five files naming thirty-two requirement IDs, with the two self-tests.
Those counts are what `bash .claude/hooks/mutate-hooks.sh --list` prints on its
last line; they are deliberately not restated in the harness's header, in
`requirements.md`, in CLAUDE.md or here, which is the subject of a section below.

One of the thirteen is `library-loaded-unguarded`, which appends the unguarded
source line the review used to demonstrate the first finding. It is registered
against `GH-84.2`, and before the fix above it would have reported `survived`.
It reports `caught`, which is the end-to-end evidence that the text checks now
read the directory under judgment.

## The harness found a rule with 36 checks and no coverage

The first full run of the grown registry came back with one survivor, and the
survivor was not a bad row.

`no-git-push.sh` refuses a push from a worktree that is standing on `main` or on
a dev branch — two lines, read off `git branch --show-current`. The assistant
registered a row against `US-2` that breaks the dev half. It survived, and the
detail said `red instead: nothing at all`: the whole suite stayed green with the
rule deleted.

`--matrix` says `US-2 active covered (36 refusing, 0 permitting, 0 static)`. All
36 are real, and every one of them refuses because the command NAMES a branch
this worktree does not own — `git push origin dev-05` from a worktree on
`wt-branch`, or `git push --all`. Not one of them stands a worktree ON a dev
branch, because the push fixture builds a main checkout on `feature-x` and one
linked worktree on `wt-branch` and nothing else. The hook's own test of
`$CURRENT` was reached by no check in this suite, and the coverage machinery
cannot see that: it counts checks tagged with a requirement, which is what #104
built it to do, and a requirement can be well covered in that sense with one of
its rules untouched.

The fixture gains two more linked worktrees, one on `dev-05` and one on `main`,
and six checks: a bare push and a push naming the branch, from each, plus a
`says` on each pinning which refusal spoke — the commands name nothing the
worktree does not own, so any other rule would permit them both. The `main` half
was uncovered for exactly the same reason, so the registered row now deletes the
whole condition and names `US-1` and `US-2`.

This is the first thing the harness has found that review did not, and it is the
argument for the harness stated plainly: the suite was green, the matrix said
covered, and the rule was not checked.

## A count wrong in four documents

"#105 and #106 gained checks for some twenty-five requirements, and the other
nineteen have no row" appeared verbatim in `mutate-hooks.sh`, `requirements.md`,
`docs/todo.md` and session 3's dev-log entry. The review measured 40 tagged IDs
and 31 without a row, or 15 and 10 on the narrowest reading; no reading yields 25
or 19. "Six rules" was not derivable from the registry at all, since a row
carries no rule field.

That entry was the one the assistant wrote saying it counted rather than
characterised, after the previous count had already drifted once in the same
session. The correction is not a better number: the counts now come from
`--list`, and the four documents say what shape the coverage has — a row per rule
reaches a requirement, it does not exercise every check that requirement has —
and leave the arithmetic to the program that can do it.

## Three ways a survivor could be reported as expected

Each of these is in the permitting direction, and each is one line.

**The fifth field was untied from the id.** `caught` is what a real mutation
expects; `survived` and `did-not-apply` are the self-tests'. Nothing said so, so
replacing the wrongly-registered self-test with a real row declared `survived`
left the counts in the suite's #107 section intact, reported `ok`, and exited 0
with a registered mutation alive. The header the assistant wrote had argued that
no spelling could leave the exit status at 0 for one and non-zero for the other;
there is one, and it is `case "$WANT:$ID"`. A whole-registry run additionally
requires both self-tests to be present, since a row can be deleted as easily as
declared.

**The registry audit accepted retired and superseded requirements.** It asked
whether `### <ID>` was a heading in `requirements.md` and never read the status.
`### FR-12` is retired and `### FR-1` is superseded; both are headings, neither
has a covering check, so a row naming one would report `survived` on every run
for ever and read as a defect in the hooks rather than in the row. That is the
case the audit's own paragraph says it exists to prevent, and it did not ask it.

**`mutate-hooks.sh` was an accepted mutation target.** `check-hooks.sh` was
refused by name, for an argument that applies to both: the program that runs is
this repository's, so an edit to the copy would be read and never executed. But
`$MUT` read the harness's text out of `$HOOKS`, so a row editing the harness's
own header could turn one of those pins red and be reported as `caught` for a
file whose running instance was never touched. The two files are one list now,
`$TOOLING`, read by the harness's refusal, by the suite's registry audit, by the
text-argument rule above and by the tokeniser-consumer exclusion that had a
third spelling of the same fact.

## A relative override named this repository's own lib/

`check-hooks.sh` resolved `$CHECK_HOOKS_DIR` after its own `cd` into
`.claude/hooks/`, so a relative override was read from there rather than from
where the caller stood. `CHECK_HOOKS_DIR=hooks-copy` from a directory holding
one exits 1 saying it is not a directory; `CHECK_HOOKS_DIR=lib` silently named
this repository's `lib/`, which is there, so nothing stopped and the run judged
it. `CHECK_HOOKS_DIR=-` made `cd -` print `$OLDPWD` and left `$HOOKS` a two-line
string. `mutate-hooks.sh` passes an absolute path and never saw any of it: the
documented manual usage is the half no harness exercises. The caller's directory
is kept before the `cd` now, `CDPATH` is cleared and both steps are `cd --`, and
a third nested run checks it.

## The byte-identical check's guard was inert

`tree_sum` is the harness's last line of defence on the files it is meant not to
touch, and three of its guarantees were not implemented. `find -printf` always
emits the `.` entry, so the test for an empty listing could never fire. `xargs
-0 sha256sum` with no `-r` runs `sha256sum` with no arguments when a tree holds
no regular files, which reads stdin and exits 0. And symlink targets were never
hashed, so a symlink repointed from one file in the tree to another left the sum
where it was — the review verified that on findutils 4.9 with `a`, `b`,
`link -> a`, then `ln -sfn b link`. Latent for `.claude/hooks/` as it stands
today; the comment the assistant wrote above the function claimed all three.

## Smaller, and taken

- `RAN` was incremented before the `cmp`, so a row whose edit does not apply
  counted as run. The footer's "(10 run)" equalled nine mutation runs plus the
  baseline by coincidence. There are two counters now, one for rows an
  invocation asked about and one for invocations of the suite.
- `bash mutate-hooks.sh -v <typo>` paid for the baseline and then reported twice
  — once for the row it refused, once for having run none. The registry is read
  in full before anything is copied or run, which answers both.
- The partial-hooks fixture was built by addition and was "one file short" only
  while `lib/` held exactly one file; a second `lib/*.sh` sorting earlier would
  have turned the check red about the order of a glob. Built by subtraction now.
- The three nested runs were a nine-line copy-paste; they are a section-local
  helper, which is this suite's idiom for a shape it repeats.
- The suite's own header said its harness's runs are "the evidence that the
  checks here can fail", unqualified — a claim about 3657 results over 162 IDs
  where the registry establishes something about thirty-two. It contradicted the
  harness's own header and CLAUDE.md both.
- `requirements.md` listed #107 under *citations that are not requirements* with
  the reason "it adds no requirement of its own", which stopped being true when
  `GH-107.1` and `GH-107.2` landed in the same file.

## Recorded rather than fixed

Two of the review's lower-confidence points are now backlog items in
`docs/todo.md` rather than changes here.

`check-hooks.sh` pins the 5 s timeout `settings.json` puts on the hooks Claude
Code runs, and then runs every hook itself with no timeout at all. A hook left
looping by a registered mutation hangs the suite; `mutate-hooks.sh` bounds the
whole run at 600 s and reads a killed run as `did-not-complete`, which names the
harness's problem rather than the hook's, so the requirement that mutation was
registered against is never asked. Changing how every check here runs a process
is its own piece of work.

`$TOOLING` is a by-name list that grows with every non-hook script anyone puts
beside the hooks. Iterating what `settings.json` registers would answer the same
question off the configuration instead.

One finding stays answered as it was: #107's criterion says the harness exits
non-zero "on any survivor or non-applying mutation", and a clean run reports one
of each — the self-tests — and exits 0. The two cannot both hold literally, which
is why the outcome is a field; what changed is that the field is now tied to the
id, so the deviation is the self-tests' alone.

## What this is not evidence of

A registered mutation says that some check tagged with the requirement it names
went red. It does not say the right check went red, and nothing in the harness
can say that. Thirty-two requirement IDs of the 144 that are active have a row,
one row per rule rather than one per requirement, and one mutation per functional
requirement remains the backlog item `docs/todo.md` carries from #103 Q8.

The review found ten defects in a change whose whole subject is checks that
cannot fail, in the same repository that records nine tokeniser defects found by
review rather than by its suite. Neither the suite nor the harness found any of
these ten. What the harness then found, once its registry was grown, was an
eleventh that review had not.

## Measured

`bash .claude/hooks/check-hooks.sh` — 3657 results, all passing, exit 0.
`bash .claude/hooks/mutate-hooks.sh -v` — all twenty-three rows reported what the
registry declares, `.claude/hooks/` byte-identical afterwards, 45 min 24 s over
23 runs of the suite; an earlier run, of a registry one row different, took
47 min 34 s. `make test` — 596 passed, 5 xfailed. The only edit to
`.claude/hooks/` after the measuring run is the cost figure in the harness's own
header, which is a comment.

## Still open

The backlog items above: one mutation per functional requirement, bounding the
hooks the suite runs, and deriving the tooling list off `settings.json`. #108 and
#109 register their own rows when they land. The pull request, #142, is Bertan's
to merge.

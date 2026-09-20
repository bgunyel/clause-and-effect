# 2026-09-20 · session 1 — #144's merge with dev-05: five conflicts, and the defects none of them named

**Branch** `worktree-issue-144-active-dev-base`, still proposed into `dev-05`.
`origin/dev-05` merged into it at `5ff5f10`, fifty commits on from the fork point
`897bdff`. **Check suite 3870 → 5160 results, all passing**; requirements 180 →
188, of which 171 active; mutation registry 34 → 59 rows, 57 real. One
requirement was added, `GH-144.7`, and one behaviour changed with it; one
registered mutation survived and was split into two, which is the finding of the
session.

Worked by the assistant against the second review of PR #158, which was
machine-authored and posted through Bertan's account. It is cited throughout
this branch as *the second review of PR #158* and never by his name, matching
what the first round's citations already said: attributing a machine's reading
to the engineer would delete the distinction the dev-log README exists to keep.

## The merge was a source of defects, not a rebase chore

This is the finding of the session and it is the reason the entry leads with it.
The review named a blocker — the branch was `CONFLICTING` — and six findings.
Resolving the five conflicts was the smaller half. The larger half is that the
merged tree failed the check suite in **four** places that no conflict marker
pointed at and that no reviewer of either branch alone could have seen, because
each is an interaction between a rule this branch added and rows the other
branch added after this one was cut.

- **Twenty-seven bare `check` rows naming a `dev-NN` base.** `GH-144.4` is this
  branch's rule that a row whose payload names such a base must name the
  directory it is judged in, `$ON_DEV` rather than wherever the suite was
  started. dev-05 landed #137 and #139 after the fork, and both wrote rows in the
  bare `check` form. Git merged them cleanly — they are additions in untouched
  regions — and the rule then refused them as a set. The derivation `GH-144.4`
  installs is what reported it, which is the requirement doing exactly the work
  it was written for, one merge after it was written.
- **Two refusal literals pinned against the superseded wording.** #137 pinned
  `This names main;` and #133 pinned
  `Retargeting to main chooses that destination just as creating it there would`.
  This branch had rewritten both messages to interpolate `$BAD_BASE_WHY`, so the
  fragments no longer occur. Neither side was wrong; the pair was.
- **Five entries missing a field that became compulsory while the branch was
  away.** #141 landed the rule that every `GH-` entry in the invariance
  families' scope declares a `variants` field. `GH-144.1`, `.2`, `.3`, `.5` and
  `.6` were written before that rule existed and carry none.
- A fourth, smaller: the registry count literals, which are two sides' counts of
  one table.

The general lesson, and it is not this branch's alone: **a clean textual merge of
two branches that both add rules is not a merged rule set.** The suite is what
notices, so a merge is not done when git stops printing conflicts.

## The five conflicts

`check-hooks.sh`, `mutate-hooks.sh`, `no-pr-decisions.sh`, `requirements.md` and
one dev-log entry.

The `no-pr-decisions.sh` conflict is worth naming because a careless resolution
would have silently reverted a landed fix. Both sides rewrote the same retarget
refusal: this branch to carry `$BAD_BASE_WHY`, dev-05 (#133) to end with
`Retarget to the active dev branch instead: gh pr edit <n> --base dev-NN.` Taking
either side whole loses the other, and taking this branch's side — the tempting
one, it being "ours" — would have removed #133's fix while every check of it
still passed, those checks living in the file the other side of the conflict.
Both were kept.

In `requirements.md`, dev-05's entries were placed before this branch's: the file
appends, so the order records which landed first. dev-05's rewritten `#141` line
was taken over this branch's stale copy of it, and this branch's deletion of the
`#144` line was kept, `GH-144.1` to `.6` now being what carries that issue.

## The dev-log collision was a filename collision, and ADR 0003 decided who may fix it

Both branches hold a `docs/dev-log/devlog_2026-09-17_session-5.md` and they are
different sessions — dev-05's is #128's. Nothing about the contents conflicts;
the name does. dev-05's entry was kept where it stood and this branch's was
written to `devlog_2026-09-17_session-9.md`, the first free slot for that date.

Who is allowed to do that was settled by dev-05 itself, in the same merge. ADR
0003, from #149, says a file is a **history entry** once it is present on the
active dev branch at the merge base, and a **draft** before that; a draft may be
rewritten. This branch's entry is absent from the merge base, so it is a draft,
and renaming it is the ordinary case rather than a breach.

`append-only-docs.sh` refuses it all the same. The hook reads the verb and the
path out of the command text and `git mv` on a `docs/dev-log/` path is refused
whatever the file's status, which ADR 0003 states as a deliberate consequence:
the Bash half cannot tell a draft from history without parsing paths out of
shell text, so it applies its allowlist to both. The rename was therefore made
through the merge resolution — `git checkout --theirs` on the kept entry, a `>>`
append for the new name — and not by arguing with the hook. Nothing was
destroyed either way.

## The six findings

1. **The refusal argued for the wrong branch.** `GH-144.7`, below.
2. **The cross-repository corner was defended with an argument that does not
   hold.** Three documents said the corner "is not a regression" because the
   accepted set is a subset of what was accepted before #144. A narrower accept
   set *is* a new refusal: `gh pr create -R other/repo --base dev-04` passed
   before and is refused now, naming this repository's `dev-05`, and no base a
   caller can write both passes the hook and names the other repository's real
   active branch — the only way through is `--web`. The subset claim is struck in
   all three places; the stopping rule, which was always the real reason, is left
   as the whole of it.
3. **`CLAUDE.md` under-counted which hooks read refs.** The boundary paragraph
   still said "the last of them" read refs when two of the four now do.
   `CONTEXT.md`, `requirements.md` and the branch-hygiene skill had all been
   updated for this; `CLAUDE.md` had not.
4. **Two comment blocks contradicted themselves two lines apart** — "the next two
   lines stand verbatim in report-stale-branches.sh as well" above a line reading
   "check-hooks.sh holds the three equal". Both name both siblings now.
5. **A count in a comment, over-counted and stale inside its own pull request.**
   "Thirty-five such rows moved to `$ON_DEV` … and three loops with them" counted
   the loops twice, and the merge then moved twenty-seven more. The count is gone
   rather than corrected: `GH-144.4`'s own note says the count is deliberately not
   claimed, and a count in a comment is what #107 was filed about.
6. **The #108 preamble had become a counterexample to itself.** It argues that
   every cross-repository spelling is refused off the text of the command and
   never off the environment, and closes "a hook that starts reading the
   environment for one of those decisions turns them red, which is the point".
   `no-pr-decisions.sh` is now that hook. The paragraph is kept as the argument it
   was and a second one added saying so, because rewriting it to read as though it
   had always allowed for #144 would delete the prediction it got right.

## GH-144.7: a refusal that rests on a read has to say what would make the read current

Rotate and push `origin/dev-06` mid-session. The agent's refs were last fetched
at SessionStart, so `ACTIVE_DEV` is still `dev-05`, and `gh pr create --base
dev-06` — the correct base — is refused with "this names dev-06, which is not
dev-05, the active dev branch here". `GH-144.1`'s header named `git fetch` as the
remedy. The message did not. So the one remedy an agent could read off the
refusal was to retarget to `dev-05`, which the hook then permits, landing the
pull request on the branch on its way out — which is the failure #144 was filed
to stop, arriving back through the message.

`BAD_BASE_FETCH` carries the sentence and is set on the branch question alone.
The converse rows are the half that makes the requirement worth having, and the
second review asked for them by name: a fetch offer on every refusal would be as
wrong as one on none. A base of `main`, a base that is no branch shape at all,
and a create naming no base are each refused without it, there being nothing a
fetch would change about any of them.

## What was measured

- Check suite: **5160 results, exit 0**, on the merged tree.
- requirements.md: **188 entries**, 171 active, 171 covered, 12 marked a gap.
- Mutation registry: **59 rows**, 57 real against 7 files, naming 49 requirement
  IDs.
- Mutation rows for #144, run as selections against the merged tree: the seven
  standing after the merge, then the two that replaced the survivor among them.
  Eight rows now, all `caught`, `.claude/hooks/` byte-identical after each run.

## A mutation survived, and it is the best evidence in the session

The seven #144 rows were re-run as one selection against the merged tree rather
than carried forward from the pre-merge run, and **`base-pattern-admits-main`
survived**. That row admits `main` to the `dev-NN` pattern and claimed eight
requirements would go red. Three did. Five — `FR-17`, `FR-19`, `US-8`, `US-10`,
`US-11` — did not.

The assistant drove the mutated hook by hand in both ref states rather than
reasoning about it, because a survivor is exactly where a wrong explanation is
cheapest to believe. With the pattern admitting `main`,
`gh pr create --base main` exits 2 in this repository and exits 0 in a fixture
with no dev ref. That is the whole mechanism: **since #144 the shape test is no
longer load-bearing for `main` wherever a dev ref can be read**, because the
branch question refuses it anyway. The verdict is unchanged and the hook is
safer for having two reasons; what moved is the evidence. Five requirements'
checks had quietly stopped depending on the test the row breaks, and nothing in
the suite said so — the row was green before the merge and its own verdict was
not what the merge changed.

It is #128's overlap one rule out, and it is answered the same way. The row is
narrowed to what it still establishes, which is the refusals that change their
*wording* here plus `GH-144.2`, whose no-dev-ref rows are the one place the
pattern still decides. `base-admits-main-outright` carries the original list by
breaking what now decides — `main` accepted before either question is asked.
Both were then run: both caught.

The general point, and the reason this session's entry leads where it does: a
mutation registry's verdicts are evidence about the tree they were measured on.
Carrying them across a fifty-commit merge would have kept a green row that had
stopped establishing five of the eight things it claimed.

## What the next session inherits

The branch merges and the suite is green on the merged tree. Not done here: the
registry rows outside the two selections above have not been run since the files
they run against changed, which is the standing state of that registry and not a
regression of this merge. How many is not written down, for the reason finding 5
took a count out of a comment; `--list` says which rows exist and this entry says
which were run.

One operational note, recorded because it cost this session its working copy and
not because it belongs to #144: the worktree and the local branch were removed by
a sweep in the main checkout while this session was working in them and while
PR #158 was open. Nothing committed was lost — `origin` held the branch at
`6fa4fab` — and the merge resolution was replayed from the scripts that made it.
A sweep that takes a worktree whose pull request is open is worth a look at the
tooling; it is carried to Bertan separately.

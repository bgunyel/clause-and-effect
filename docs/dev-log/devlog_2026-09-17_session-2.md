# 2026-09-17 · session 2 — #108: what the hooks decide when the environment they read is broken

**Branch** `worktree-issue-108-malformed-input-verdicts`, cut from
`origin/dev-05` at `befcf8a` and proposed into `dev-05`. **Check suite 3657 →
3778 results, all passing** — 97 of the 121 new ones in a section of its own, 24
in the #98 self-test, which had to grow before the section could be written.
Ten requirements, `GH-108.1` to `GH-108.10`. Six rows added to the mutation
registry, 23 → 29. One permitting gap found, filed as #144 and not fixed.

Issue #108 is the third of #103's stages. #95 pinned what a hook does when it
cannot read its input; this one asks the step after it — what the hooks decide
once the input has been read and the environment they read the *answer* out of is
not the ordinary one. #103's audit had written the table and measured every cell
at `750aace`, and marked some open, some closed, some by design and some by
accident, with no check anywhere naming any of them.

## The question that decides whether an open cell is a hole

The assistant re-measured the whole table at `befcf8a` before writing anything
down, because the audit predates #95's landing and several cells could have moved
under it. They had not. What the re-measurement added was the question the table
does not ask: **is there a case where a hook's read of the environment fails while
the command would still reach a repository?**

Every spelling that reaches one — `git -C`, `git --git-dir`, a `cd` or a
`git checkout main` before the commit — was driven under each broken environment,
and every one is refused. Those refusals are read off the text of the command and
never off the environment, so they do not move when the environment does. That is
the finding, and it is what makes the open cells safe to write down as intended
rather than tolerated: the environments that produce a permit are the ones in
which the command cannot run either.

They are pinned all the same, in both directions. A hook that starts consulting
the environment for one of those decisions turns them red, which is the whole
point of pinning an answer that is currently right for a reason nobody wrote down.

## The row the issue left to this pull request to decide

`report-stale-branches.sh` exited 0 with no output at all when `git` was off PATH
or it stood outside a repository. #108 named it and declined to decide it: either
the silence is stated as intended in the file's header, or the file is changed to
say why it reported nothing.

The assistant changed it. The argument was already in that file, twice over: it
fails open *with a timeout* and says so in as many words when the fetch fails,
"because the consequence is not cosmetic", and its heading
`THE ARMING PROPERTY IS NOT SELF-ANNOUNCING` says that this file arms enforcement
rather than performing it, so its breakage does not announce itself. Every other
unread thing in the report already says so — the fetch, the merge settings, the
pull requests, the main ancestry. These two paths were the exception, and no
reason for the exception survived being looked for.

The heading is now printed before the first thing that can fail, and each of the
three ways the file can have nothing to report prints a `branches: NOT READ` line
naming its cause and naming what is not armed. The exit status stays 0: a
SessionStart hook that fails is a session that does not start.

Two of the three causes are driven against a copy of the file in a tree that is
no repository. The third — a root the file cannot reach — is not, and this is
recorded rather than glossed: a directory unsearchable enough to fail that `cd`
is one the file cannot be *read* out of either, so bash exits 126 before the
guard is reached. The assistant measured that rather than assuming it, and the
branch is held to the file's text instead. That is the whole of what is claimed
for it.

The row above it in the table — the report when the fetch fails — turned out to
be pinned in a way that says less than it looks like it says. `GH-100` asserts
that `report-stale-branches.sh` CONTAINS `fetch: FAILED`, `merge settings: NOT
READ` and the rest, and a file that never reaches those lines contains them just
as well. `GH-108.10` drives the degraded report instead: a repository whose origin
is a path that is not there, under the `gh`-less PATH the section already builds.
It costs no wall clock, which is why it can be a check at all — a fetch of a
local path that does not exist fails at once, and the file's own header says the
pull request read is skipped when the settings read found `gh` missing. A
genuinely unreachable network would cost the full fifteen seconds and is nobody's
check.

## A NUL in the suite's own text, which nothing said the name of

The first draft of the byte-level checks carried a real NUL byte in a payload
literal. GNU grep calls a file with a NUL in it binary and `grep -o` then prints
nothing, so `READ_DOCS` — a derivation four hundred lines away that reads this
suite's own text to learn which documents it reads — came back empty, and two
checks about names in a paragraph went red. Nothing anywhere said NUL.

It happened four times. The second was in the comment the assistant wrote
warning about the first, which spelled the escape and embedded the byte instead;
the third was in the paragraph above, in this file, caught by a scan of every
file this branch touches rather than by anything that would have announced it;
and the fourth was in the first draft of the commit message, which git refused
outright, being the one consumer of these bytes that checks. Four other
derivations in the suite read this file the same way and would have gone quiet
rather than red.

This paragraph said three until Bertan's review of PR #150, because it was
written before the fourth happened and was not revisited when it did — which is
the same failure as the counts below, arriving through the same door.

The cause is worth naming, because it is not carelessness: the escape is written
into a tool call, which is itself JSON, so a `\u0000` in the text being written
is decoded once before it ever reaches the file. Spelling the escape and writing
the byte are the same keystrokes. Nothing in the editing path says so, and the
only reliable check is to read the bytes back.

The payloads are now spelled `\u0000` and jq does the decoding, which is also how
such a command would actually arrive: a tool call is JSON, and a NUL can only
reach a hook as that escape. The account is in the section, because a fix whose
whole content is "do not do the thing that looked fine" is one the next person
will undo.

What the byte checks pin, measured rather than reasoned: a NUL is **stripped** by
the command substitution that reads it, so what decides the verdict is whether
stripping it joins two words. On one line it fuses `ls` and `git` into `lsgit`
and the push is hidden; after a newline it fuses nothing and the push is refused
as it always was. The issue's table had the first half and not the second. The
permit is accepted, with the reason beside it: neither a NUL nor a non-breaking
space is whitespace to a shell, so what is hidden from the hook is not a command
that would have run.

## The self-test had to grow first

Four new helpers were needed — `env_feed`, `env_cmd`, `env_says` and
`report_says` — because every existing one fixes half of what each
row of the table needs — `check_in` names a directory and takes the suite's PATH,
`feed` names a PATH and runs in a fixed directory. The suite refused all three
until they were driven: it derives, from its own text, every helper that reads a
hook's exit status, and fails one that the #98 self-test does not drive against
hooks exiting 0, 2, 1 and 127. Three of the four are caught by that derivation;
`env_cmd` reads no status of its own, handing its payload to `env_feed`. So they
had to move up beside the others, since a function defined after the self-test
has not been defined when it runs.

`report_says` needed a fifth fixture. It is the first helper that asks for a
status *and* a sentence at once — a report that exits 0 having said nothing is
precisely the defect it exists to catch — so `allow-0`, silent and successful, is
its failing case rather than its passing one, and `speak-0` was added to be the
passing one. Both halves were dropped in turn and measured to fail exactly there.

## The gap that was found and not fixed

`no-pr-decisions.sh` judges a pull request's base by pattern, `^dev-[0-9]+$`, and
reads no git at all. With two `dev-NN` refs on origin — which is what a dev-branch
rotation looks like — `gh pr create --base dev-05` is permitted while `dev-06` is
the active dev branch. CLAUDE.md says "into the active dev branch", so this
permits something the boundary refuses. In the same fixture
`no-work-on-stale-branch.sh` refuses and names `origin/dev-06`, so two hooks in
one repository disagree about which branch is active; that is the sharpest way to
state it.

#103's Q18 says such a case is filed as a sub-issue of #36 with its check written
at the *correct* verdict. The assistant filed it — #144 — and wrote the check at
the **measured** verdict instead, which is the one place this work departs from
its own ticket. The reason is the ticket's own subject: the fix is to have that
hook read refs, and a hook that reads refs fails open when it cannot, which is the
failure mode every other row here exists to pin. `no-pr-decisions.sh` is today the
only hook in the boundary whose verdict is independent of its environment, and
`GH-108.6` pins that as a property across every fixture. Trading it for a gap that
exists during a rotation is the wrong way round.

The check carries `ACCEPTED GAP` in its label and names #144, so the fix turns it
red and finds the issue. Bertan may well decide the other way; what this session
declined to do is decide it silently.

## Six rows in the mutation registry

Registered and run, rather than declared: `--list` now prints 29 rows. The six
new ones break the unresolved-git-dir refusal in `no-git-push.sh`, the version
sort that picks the active dev branch, the reader's indifference to `tool_name`,
a hook's exit status, the report's new sentence, and — the sixth, added by the
review pass — the line in which the degraded report says its fetch failed, which
is `GH-108.10`'s own claim that a report which cannot read still reports.

`dev-branch-not-version-sorted` is worth its own line. It replaces `sort -V |
tail -1` with `sort | head -1`, and the *existing* lifecycle fixture — which
holds `dev-05`, `dev-4` and `dev-foo` specifically to check that sort — stays
green under it, because a lexical sort of those three happens to put `dev-05`
first as well. Only the new two-ref fixture catches it, where `dev-05` sits at
base and `dev-06` at the tip so the two refs disagree about the stale branch. A
fixture with both refs at the tip would have refused whichever was chosen and
been evidence about neither.

Four of the ten requirements have no row. The first count was five, and the
review that followed found one of them reachable after all: `GH-108.10` says the
degraded report still reports, and deleting the line that reports it turns that
check red. It is registered. The four that remain are `GH-108.3`, `GH-108.4` and
`GH-108.7`, which pin verdicts no single edit to a hook flips without flipping a
great deal else, and `GH-108.6`, a property of a hook starting no process, which
an edit can only break by making it start one. That the first answer was wrong by
one is worth recording rather than quietly correcting: "no mutation reaches this"
is the same shape of claim as "this check covers that", and it wants the same
scepticism. The
backlog item in `docs/todo.md` carries the shape of that gap and now carries this
instance of it.

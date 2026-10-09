# 2026-09-17 · session 9 — #144: the pull request base is the active dev branch, and the lookup only narrows

**Branch** `worktree-issue-144-active-dev-base`, cut from `origin/dev-05` at
`897bdff` and proposed into `dev-05`. **Check suite 3786 → 3870 results, all
passing**; requirements 174 → 180, `GH-144.1` to `GH-144.6`; mutation registry
29 → 34 rows, the five new ones run against a baseline and all caught.

`no-pr-decisions.sh` judged a pull request's base by pattern — every `dev-NN`
string was accepted whatever refs `origin` held — while
`no-work-on-stale-branch.sh`, in the same repository, derived *the* active dev
branch as the highest `origin/dev-NN` and refused a commit measured against it.
Two definitions of one term, and they disagree exactly during a rotation, which
is the window in which both refs exist and in which a worktree pull request
would land on the branch on its way out with nothing saying so. #108 found it,
measured it, and filed it rather than fixing it.

## The argument #108 left, and why what landed is not what it refused

#108's reason was not caution. That issue's whole table is the account of what a
failed environment read costs: every other hook in the boundary abstains or
refuses when its read comes back empty, and an abstaining pull-request hook is
one that permits `--base main` whenever refs cannot be read. Trading a gap during
a rotation for a hook that fails open is the wrong way round, and `GH-108.6`
pinned the property that made this the one hook whose verdict did not depend on
its environment.

The base rule now asks two questions, and the order is the whole of the answer.
The shape question — is this base a `dev-NN` at all — is answered on the text of
the command, and it is what refuses main, master, a worktree branch, a typo and a
create naming no base. The branch question is asked **only of a base that has
already passed the shape question**. So the set this hook accepts is a subset of
`dev-NN` under every ref state there is, and a read that comes back empty costs
the narrowing and no refusal. That is written as a requirement, `GH-144.2`,
rather than as a comment, and the sharpest check of it runs with `git` off PATH
in the fixture that holds *both* refs: the same command refused eight checks
earlier is permitted there, and the only thing that differs is whether the read
could be made.

`GH-108.6`'s text was narrowed rather than deleted — "reaches the same verdict in
every environment" becomes "every refusal it makes is reached in every
environment", which is the half #108 was protecting and the half that is still
true. The check written at the measured verdict rather than the correct one did
what it was written to do: it went red when the fix landed, and it is what led
this session to the issue.

The old header rested on a second argument, that an agent can make a branch. It
is answered by the same asymmetry rather than by trust: forging
`refs/remotes/origin/dev-99`, which no hook here guards, moves which single
`dev-NN` is accepted inside a set that is already only `dev-NN`, and `gh` then
opens the pull request against a branch the remote does not have. No ref state
makes main reachable through this rule.

## The three questions the issue asked a fix to answer

*Where the branch is read from, and what the verdict is when the read returns
nothing.* From `refs/remotes/origin/dev-*`, by the two lines that already stood
verbatim in two files and now stand in three; check-hooks.sh holds the three
equal, as #62 arranged for the first two. When the read returns nothing the shape
question is the whole rule, which is the verdict this file gave everywhere before.

*Whether the refusal can name the branch it expected.* It does, in all four
spellings: "This names dev-05, which is not dev-06, the active dev branch here."
`GH-144.3` pins that, and its load-bearing half is the two `says_not` rows — one
constant carries both answers, so a dev branch must never be told it is "not a
dev-NN branch", and main must never be told which dev branch was expected. What
is **not** done, and is written down as a decision rather than left as an
oversight: the refusal's first half still says `Write: gh pr create --base
dev-NN`. FR-23's claim is that one constant serves all four refusals and five
checks pin its text, and the constant is assigned before any command is judged,
so interpolating the branch there would make the read happen for the refusal
where no base is named — which `GH-144.5` says it does not. #109 owns which
sentence the name belongs in.

*Whether the rotation window belongs to a hook at all, or to the rotation
procedure in the branch-hygiene skill.* To the hook. The procedure is Bertan's
and runs when he rotates; the window it opens stays open in every agent session
that fetched during it, and a procedure cannot refuse a command. The skill gains
a note saying the hook now covers the window rather than a step.

## Forty checks that would have gone red at the next rotation

The cost of the lookup fell on the suite rather than on the hook. `check` runs a
hook in the directory this suite was started from, which is this repository, so
every row reading `--base dev-05` passed only because `dev-05` is the active
branch today: at the next rotation they would have gone red blaming a hook that
was right. Thirty-five rows moved to `$ON_DEV`, which has no remote and so no dev
ref; five seeds of the #106 invariance families moved from `hooks` to `on-dev`;
three loops with them. The rule is mechanical — a `dev-NN` base in the payload
means a named directory — and `GH-144.4` holds this file to it with three
derivations, one per shape a payload reaches a hook by: a row on one logical
line, a payload held in a variable and passed by a loop, and a seed table row
whose fixture is its first field.

The loop shape is there because the first version of the guard missed it. The
assistant wrote a derivation over lines beginning `check`, and the `must ALLOW`
loop drives `gh pr create --base dev-05` through `"$c"` from a `for` list, so the
payload and the harness word are on different lines and neither derivation saw
them. Three derivations, each hand-mutated on a copy of the file to confirm it
moves the value its own check reads — including one pointed at a hook name that
is not there, because `lacks` must fail on an empty read rather than pass on an
absence it could not have found.

## What the review found

Two review agents read the commit, one against this repository's standards and
one against the issue. Both found the same defect, and it was in the thing this
session had just claimed: **the memo did not memoise**. The assistant wrote
`DEV=$(active_dev)` at the only call site; a command substitution is a subshell,
so the variable recording the read was set in a process that then exited, and the
hook forked one `git for-each-ref` per base tested while the comment beside it
said once per run. Verdicts were identical either way, the read being idempotent,
which is why no verdict check in the suite could have shown it and none did. The
fix is `read_active_dev`, which leaves its answer in a variable and prints
nothing, and the check that would have caught it is `GH-144.5`: a git shim first
on PATH that logs every `for-each-ref`, two payloads naming two bases each, and a
count. One read for a line naming two bases, none at all for a command naming no
base.

The other findings, each acted on: the registry's run count was off by one
because the baseline was dropped from it, and the sentence that keeps going stale
now names the whole registry instead of a number; the #62 block still said "both
files" and "two copies" after a third arrived, and its argument for duplicating
rather than sharing — that the guard must read its state before it may depend on
`lib/` — does not cover `no-pr-decisions.sh`, which sources the library before it
reads anything, so that file's own two reasons are now written out; the `#144`
bullet under *Citations that are not requirements* contradicted that section's
preamble once the entries existed, and is gone; `is_dev_base` and `bases_all_dev`
became `may_propose_into` and `bases_all_proposable`, because both now return
false for a genuine `dev-NN` branch and a name that lies is the defect this
repository treats a stale comment as; and the flipped two-ref row is tagged
`GH-144.1` rather than `GH-108.5`, whose rewritten text no longer claims it —
which in turn meant dropping `GH-108.5` from two mutation rows that would
otherwise have reported `survived`.

## The corner left open

The refs are read in the directory the hook process runs in — the session's, and
no command moves it — so a base is judged against this repository's active dev
branch whichever repository the pull request is going to.
It is not a regression — before this change every `dev-NN` base was accepted in
every repository, so what is left is a subset of that — and it stays open under
the stopping rule, opening a pull request into another repository being no shape
an agent working here writes by accident. It is written as `GH-144.6` with the
permitting row named `ACCEPTED`, because a fix that gives up a case has to say so
where a reader will be looking rather than in a header.

The wording above is the second attempt at it. A third review, run from a peer
session against the pushed pull request, found no correctness defect and one
thing: the header and `GH-144.6` both said the refs read were "those of the
repository the command runs in", and `cd other-repo && gh pr create --base
dev-02` is the case where that is false — the `cd` moves the command and not the
hook, so the command runs in one repository and the refs are read in another.
The verdicts were right; only the account of them was wrong, which is why the
answer is a wording change rather than a fix. The assistant measured the other
routes before rewording rather than reasoning about them: `GH_REPO=` and `cd`
were fed to the hook in a one-ref fixture and behave exactly as `-R` does, so
the corner is one corner reached four ways. `GH-144.6` gains a row per route,
on the argument that a claim about *which directory is read* is the kind a
reader would otherwise have to re-derive — and this session has now got it
wrong once.

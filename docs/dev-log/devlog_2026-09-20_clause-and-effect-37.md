# 2026-09-20 17:22 +03 · session `clause-and-effect-37` — #118: an option in front of a gh subcommand eats it, and git's list of globals was two short

**Branch** `worktree-issue-118-gh-preoption`, cut from `origin/dev-05` at
2a52322 and one commit ahead of it when this entry was written; the whole change
is that commit. Worked unattended by an AI assistant. **Check suite 5093 → 5147
results, all passing.** Four mutation rows added and run; all four caught, with
one of them correcting the assistant's own registry row first.

## The defect, and the correction to the defect report

gh resolves a subcommand path at the first non-flag argument, and cobra gives a
value to an option it does not know as a boolean. So an option written in front
of a subcommand **eats the next word**, and every rule in `no-pr-decisions.sh`
read the word after it as the verb. `gh pr -t view merge 5` is a merge to gh and
was a `view` to the hook. Fifteen shapes were permitted, and one of them is not
a hypothetical: verifying the issue, an agent ran `gh release -t list create v1`
and it **created a real release on this repository**.

#118's own table was written with `--squash`, and that spelling is one gh
rejects — cobra treats an unknown **longhand** as a boolean, so
`gh pr --squash view 5` returns `unknown flag: --squash` and eats nothing. It is
an unknown or value-taking **shorthand** that consumes the next word, and `-t`
(`--template`) is value-taking at every group level. The issue's own later
comment made that correction; the acceptance criteria stood, because the rule
that answers it is wider than either spelling.

## What was built

**The rule refuses the shape rather than parsing it.** Modelling which options
take a value means keeping gh's flag definitions per group, which #97 decided
against and which a gh release moves. `cs_gh_opaque` in `lib/command-scan.sh`
answers one question — does an option that is not `-R`, `--repo` or
`--hostname`, in any of their four spellings, stand before a word of this
subcommand path — and `CS_GH_OPAQUE_REFUSAL` is the one refusal, naming where
the option goes instead. The rule is stated there and in no hook.

**`cs_gh_args` gained a third outcome**, "cannot tell", spelled as **success
with no arguments**. That spelling is the whole design. A caller writes
`ARGS=$(cs_gh_args …) || continue`, and a status collapses into "not this path",
which permits — the direction every defect in that file's list went. Spelled
like a match, a caller that asks nothing further refuses. `check-hooks.sh`
drives that caller rather than reasoning about it.

**The one caller this is not enough for is named in both files.**
`release_is_read` is the only place where success means *permit* — it asks
whether a command is one of five reads — so "cannot tell" spelled as success
would grant the read to `gh release -t list view v1`. It asks `cs_gh_opaque`
itself, and reads the status as **1-or-nothing**: only an explicit "readable"
lets the read through, so a call that does not run at all withholds it. That
last part is review's, below.

**git's half is a different defect wearing the same shape.** git rejects an
unknown global option itself, so it has no shape to refuse — only a list to
complete. `cs_git_args` was missing `--config-env` and `--attr-source`, so
`git --attr-source HEAD push origin main` was a push to git and not a push to
any of the three hooks that ask. The list was re-derived on git 2.43.0 by
running `git <option> <value> version` for every option `git help git` lists:
**seven** take a separate value. `--exec-path` is an eighth entry and is not one
of the seven — bare `git --exec-path /usr/bin version` prints
`/usr/lib/git-core` and exits — and is kept, because dropping it would refuse a
command git does not run as a push either. That is written beside the list.

## What the measurements were

**Every `was` column is measured, not quoted from the issue.** A copy of the
hooks with `lib/command-scan.sh` and `no-pr-decisions.sh` reverted to
`origin/dev-05` was built, and 20 of the 22 new `flip` commands were fed to it:
every one reads ALLOW there. The rows claiming no movement were fed to it too,
and each reads the verdict it claims. The remaining two — the
`no-work-on-stale-branch.sh` pair, added after that measurement in answer to
review — were measured separately, by running this suite under
`CHECK_HOOKS_DIR` against a copy with only the two git entries removed; both
read ALLOW there, and the control beside them stayed ALLOW. They are called out
because the first draft of this paragraph said 22 and had run 20, which is the
gap a reader has no way to see.

**The trade is paid on reads and is recorded as one.** `gh pr --json title
view 5` is a view and is refused. 37,597 past Bash commands from this project's
sessions were searched for a pre-subcommand option on a guarded group; the only
two were commands written while developing these hooks. The pre-**group**
position is refused on an argument rather than on that number — a group that may
have been eaten cannot be called unguarded — and the library and
`requirements.md` both say which half has which evidence.

**#106's families.** `option-eats-verb` already generated this shape and pinned
sixteen variants as gaps, six of them with a right verdict that is not the
seed's. Those six are a `design` row at BLOCK now, and the class row covering
every refused seed is gone: their variants reach the seed's own verdict.

## What review changed

Two review agents ran, one on standards and one on the spec. Five things moved.

1. **A comment claimed more than the code does.** The library said that without
   `cs_gh_opaque` "every rule over a gh command refuses — loud". True of every
   rule whose match refuses, and false of the one whose match grants: there the
   same default is silent and permitting. That is what put the 1-or-nothing
   status read into `release_is_read`, and the paragraph now says which polarity
   the default cannot serve.
2. **"Stated once" was not quite true.** `cs_gh_args` still carries the same
   three names in its own skip list, which answers the narrower question of
   which of them eat the next word. Two lists that must agree and are written
   twice will disagree, so `check-hooks.sh` now derives both off the file and
   holds each to the literal `-R --repo --hostname`.
3. **A check label was wider than what it drove**, and the missing half was the
   granting polarity. It has three drivers of its own now, plus an `armed` pin on
   the `release_is_read` line itself — because `&& return 1` and the
   1-or-nothing read satisfy every verdict in the suite equally, and only the
   text says which is there.
4. **The git half had no mutation row**, and a reviewer found it the way the
   registry exists to be found: by reverting the two list entries in a copy and
   watching three flips go back to ALLOW with nothing to say so. It also had no
   check against `no-work-on-stale-branch.sh`, the third caller of
   `cs_git_args`; the criterion says "the same hooks that refuse `git push
   origin main`", and two of three is checking a rule where it was convenient.
5. **A sentence in the hook read wider than the code.** "Before every rule
   below" is false of the heredoc re-admission, which asks `gh_rule api` earlier
   still; harmless, and now written down as harmless rather than left as a
   sentence a reader would carry away.

## What the unreadable pass is not load-bearing for

Worth its own heading because the assistant's first draft claimed the opposite
in a comment. With the pass disabled, **every command it refuses is still
refused** — cs_gh_args's third outcome makes an unreadable command match
`gh_rule 'pr merge'`, and the decision rule speaks. What the pass adds is
*which* refusal: without it `gh --squash view issue list` is told that deciding
a pull request is Bertan's call, which is not true of it and names no correction
its writer can act on. So no verdict check in the suite can see that loop at
all, and it is `says`/`says_not` on the refusal's own text that covers it, with
`gh-unreadable-pass-removed` saying those can fail.

## What the mutation harness found in this session's own work

`release-read-granted-when-opaque` was registered against `GH-118 FR-48` and
reported **survived**: `no failing check for FR-48; red instead: GH-118`. The
rule was fine and the row was a requirement too wide. The row was narrowed and
re-run alone, caught. It is written into `mutate-hooks.sh` because a registry
row is itself a claim, and this one was made before it was measured.

The other three were caught on the first run. `.claude/hooks/` came back
byte-identical after both runs.

## Dead ends and mistakes

- **The third outcome was designed three times.** A distinct exit status was the
  first answer and is wrong: `|| continue` collapses it into "not this path",
  which permits. A sentinel string on stdout was the second and is wrong for the
  granting caller, which never looks at stdout. Success-with-no-arguments is the
  third, and it is still not sufficient on its own — hence the explicit question
  in `release_is_read`. That the polarity problem is irreducible in shell is the
  finding, not a limitation of the spelling chosen.
- **This entry was first written as `session-4`**, which is not the convention:
  `docs/dev-log/README.md` names the file for the writing session, and
  `ListAgents` gives that as `clause-and-effect-37`. Bertan caught it before the
  commit. The mis-named draft could not be removed from the worktree — both `mv`
  and `rm` under `docs/dev-log/` are refused by `append-only-docs.sh`, which
  reads the path and cannot see that the file is an uncommitted draft — so it
  was left untracked and out of the commit rather than routed around with a tool
  the hook does not cover.

## Still open

- `docs/dev-log/README.md`'s index stops at 2026-09-17; the entries for
  2026-09-18, 09-19 and 09-20 have no rows. A row for this entry was added, so
  the index is now non-contiguous rather than merely short. Filling the gap is a
  separate pass over five entries and was not done here.
- `make test` fails one test in this worktree,
  `test_installed_packages_match_uv_lock` — the worktree's `.venv` is missing the
  `migrations` group (alembic, mako). Environmental, predates this branch; 595
  tests pass.
- A bare `-` before a subcommand is not an option to this walk and leaves
  `gh pr - merge 5` permitted. gh runs no merge there either, and the behaviour
  predates #118; it is written down in the library rather than fixed.
- The whole mutation registry has still never been run in one pass; this session
  added four rows and ran those four.

---

# 2026-09-20 18:09 +03 · session `clause-and-effect-37` — #118 round two: two spellings of the refused command were still permitted

**Branch** `worktree-issue-118-gh-preoption`, answering Bertan's review of PR
#184. Five findings, all verified against the real hooks before anything was
changed; two were blocking. **Check suite 5147 → 5163 results, all passing.**
All six #118 mutation rows were run as one selection: all caught,
`.claude/hooks/` byte-identical after.

## Both blocking findings were the same mistake in different clothes

The walk asked its question of **a `cs_split` fragment while reasoning about a
command**, and twice that difference let the command through.

**A backtick makes the option the last token.** `cs_split` cuts at a backtick,
so ``gh pr -t `echo view` merge 5`` arrives as the fragment `gh pr -t`. The walk
had an exemption — "a token with no blank behind it is the last word of the line
and consumes nothing" — which is true of a command and false of a fragment, so
the option was never judged. Reproduced: **ALLOW**, and the shell expands it to
the merge this rule exists to refuse. The `$( )` spelling of the same command
was already refused, its fragment ending `gh pr -t $`, so two spellings of one
command disagreed. That pair is what makes it a defect rather than a shortfall.

**A quote in front of the option ends the walk.** It tested the raw first
character for a dash, so `gh pr "-t" view merge 5`, the single-quoted spelling
and `gh pr \-t view merge 5` were all **ALLOW**, and all three reach gh as a
merge. The release arm was closed against this and the pr arm was not — the read
allowlist catches the eaten word there — so the file failed closed in one place
and open in another for one cause.

**The fixes.** The exemption is gone; option tokens have quotes and backslashes
removed before classification, by a reducer narrower than `cw_reduce` on
purpose, since `cw_reduce` also takes a path to its basename and would read
`--repo=o/r` as `r`. Path words are not reduced, so `gh "pr" merge 5` stays
GH-135's and is pinned as the boundary rather than left to be assumed.

## Dropping the exemption had a price, and it was measured before it was paid

Without it, `gh --version` is unreadable and refused. That is not theoretical:
**23 occurrences in 100,929 Bash commands from 861 local session transcripts**,
against 3 for every other non-repo option in that position put together — and
all three of those were written while developing these hooks. So `--version`
and `--help` are recognised rather than refused.

That *is* a list of gh booleans, and saying otherwise would be the evasion. It
is not the list #97 refused: that one is gh's flag definitions **per group**,
which a gh release moves and which has to be tracked. These two are the **root**
flag set, which `gh help` prints in two lines, which gh 2.45.0 defines as
exactly `--help` and `--version`, and which both print and exit — so recognising
them cannot hide a verb behind a value they never take. `-h` stays unreadable,
because cobra registering it is a thing to measure and not a thing to assume.

## The cost finding was real and is gone

Bertan measured the hook at 63 ms before this issue and 167 ms after — 2.6×, on
every Bash tool call — because asking the unreadable question separately meant
`cs_gh_args` read stdin into a variable and piped it twice: three processes
where there had been one. Measured here, 8 runs each, same input:

| | `pytest && ruff && mypy` | `gh pr view && gh issue list && gh release list` |
|---|---|---|
| `dev-05` | 61 ms | 58 ms |
| PR #184 as reviewed | 157 ms | 140 ms |
| after this round | **64 ms** | **67 ms** |

Two changes. `cs_gh_args` and `cs_gh_opaque` are now **one awk program**,
`CS_GH_AWK`, asked two questions through a `mode` variable — one process again,
and one copy of the classification. And the unreadable pass in the hook skips a
command that does not begin with `gh` before forking awk for it, which is free:
the program's own first act is that same test.

The one-program change also settled round 1's "stated once" finding properly.
That round had left `cs_gh_args` carrying the same three names again in its own
skip list, with a comment explaining why that was not a second copy. It was a
second copy. There is one now, and the check derives it off the file.

## What the contract change cost, and the check that says so

Folding the two questions together moved a documented contract: `cs_gh_args`
answered about **the first match**, and now answers about **the first line it
can decide** — an unreadable line decides too. Reachable only from
`check-hooks.sh`, every hook caller feeding one command at a time, which is
exactly why it needed a check rather than a caller. Bertan's finding 5 was that
the two existing multi-line checks pass only because their first lines happen to
be readable; a third now drives the case that changed.

## Mistakes in this round's own work

- **The withdrawal guard was written from reasoning and the reasoning was
  wrong.** The comment said an empty `CS_GH_AWK` makes awk read its program from
  the first operand and exit non-zero, which a caller reads as "not this path"
  and permits. Measured: an empty program is a *valid* awk program that reads
  its input, does nothing and exits **0**, so every path answers "cannot tell"
  and every gh rule refuses — loud, and the safe direction. The guard is kept as
  belt and braces and the paragraph now says which it is.
- **A derived check went stale in the direction that reads as a defect.** With
  the gh pair merged, `skipopts` has one definition, and the loop asserting
  every copy is identical failed with "fewer than two definitions … nothing to
  compare". Correctly: it is a check saying it cannot make its claim. It is a
  literal count now, so a second `skipopts` reappearing rejoins the comparison.
- **A check's claim stopped being about its subject and went green.** "A caller
  of that shape refuses everything when `cs_gh_opaque` is gone" was true while
  `cs_gh_args` called it; once they shared a program it read PERMIT for an
  honest reason. Replaced by the claim that now holds — the walk emptied — with
  the direction asserted.

## Still open after round two

- Everything under the previous entry's *Still open* stands.
- An option **inside** a command substitution — ``gh pr `echo -t` view merge
  5`` — is still permitted, on both `dev-05` and here. `cs_split` cuts there, so
  the option sits in a fragment no walk sees. CLAUDE.md's deliberately-left-open
  consequences 4 and 6; closing it means resolving a substitution from text.
  Pinned as permitted so the boundary is evidence.
- The registry is at 60 rows and has still never been run in one pass.

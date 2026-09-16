# 2026-09-16 · session 2 — Bertan's review of #132, and a correction to session 1

**Branch** `worktree-issue-105-coverage-gaps`, still proposed into `dev-05`.
Session 1 left one commit on it; this session adds a second, so the branch is two
ahead of `origin/dev-05` and 172 ahead of `origin/main`. **Check suite 1987
results, all passing** — compared line by line against session 1's run, and the
only lines that differ are the thirteen timing measurements, which differ every
run, and the two that state the requirements file's own size (152 → 153 entries,
96 → 97 of them off the both-directions rule). `--matrix`: 6 gaps → 7, the new
one being the defect filed below.

Bertan reviewed pull request #132 against #105's acceptance criteria, working
from clones of `dev-05` at `43fb767` and of the branch at `153c8c2` in scratch
directories, running the suite and `--matrix` on both, comparing sorted result
lines, and re-running nine of the assistant's mutations independently in parallel
copies. He modified nothing. His verdict was that all three acceptance criteria
are met; his numbers matched the assistant's exactly, including two mutations he
ran that the assistant's table did not list, both of which behaved. He raised
four findings, one of which he judged worth an issue before merge.

All four are answered in the second commit. None of them was a wrong result: the
suite was green, the matrix was right, and every mutation had behaved. Three of
the four are about what a check *claims* rather than what it *does*, which is now
the third consecutive round in which that is where the defects were.

## The finding worth an issue: a refusal that names the wrong correction

`no-pr-decisions.sh` holds one `BASE` constant and appends a tail per refused
act, so all four base refusals name the same permitted spelling,
`gh pr create --base dev-NN`. Session 1 pinned that constant across all four
spellings and tagged every row `req US-7 FR-23`.

US-7 asks that a refusal "tell me the permitted spelling, so that I can correct
myself in one step". Bertan measured what one step actually is for a refused
retarget, and the assistant reproduced it:

```
$ gh pr edit 5 --base main
Blocked: … Write: gh pr create --base dev-NN --title ... --body ... Retargeting
to main chooses that destination just as creating it there would. Edit anything
else you like.
exit=2

$ gh pr edit 5 --base dev-05
exit=0
```

Retargeting to the active dev branch is permitted. So the one-step correction for
that refusal is `gh pr edit 5 --base dev-05` — one word of the command already
written — and the message instead names a create, which is not a correction of
that command at all: acted on literally it leaves the mis-targeted pull request
open and opens a second beside it. "Edit anything else you like" makes it worse
rather than better: read against a refusal whose subject is the base, it says the
base is the one thing that may not be edited, when editing it to `dev-NN` is
exactly what is allowed.

The assistant had tagged that row US-7 without asking what one step meant for a
retarget, having checked only that the message said what the literal said.

What is interesting about the defect is that the same fact is evidence **for**
FR-23 and **against** US-7. FR-23 asks that the base rule's messages name the
permitted spelling "consistent with the existing ones", and #40 was filed because
a rule held for `gh pr create` and not for `gh api`; one sentence for four
refusals is how that consistency is kept. The constant is not the bug. The bug is
that the retarget arm's tail was written about the destination rather than about
what to write next, and it is the one arm of the four where those differ.

Filed as **#133**, a sub-issue of #36, with the measurement and a suggested shape
that keeps the constant and lets the retarget tail name its own correction.
Message content belongs to #109, so this session changed no message. Following
#103's Q18 — the rule that filed #130 and #131 rather than pinning them — the two
retarget rows are now tagged `req FR-23` alone, with the reasoning written beside
them. US-7 drops from 23 refusing checks to 21 and stays covered; FR-23 keeps all
ten. `requirements.md` carries GH-133 marked `gap → #133`, so the matrix reports
it as a known, filed gap rather than as silence.

## The tag dilution that survived a round of looking for it

Session 1's own review found the check/probe block tagged `req FR-11 US-24 FR-27`
when it established only FR-11, and the assistant fixed it and wrote the finding
up. Bertan found `req FR-28 US-24 FR-27` on the block eight lines below, which is
the same defect, in the same shape, in the same section — and the assistant had
looked at that section, in that round, for that failure, and not seen it.

Now `req FR-28`. The eight checks read the keying rationale, which is FR-28's text
and no one else's; US-24 and FR-27 are covered by the #70 block above, so the
extra tags bought nothing and claimed something. US-24 drops from 17 static
checks to 9, FR-27 from 19 to 11, both still covered.

## A prefix doing the work of a decision

The stopping-rule loop session 1 added derived its four hooks by grepping
CLAUDE.md's boundary paragraph for `no-[A-Za-z0-9_-]*\.sh`, and the comment
beside it said a boundary hook named in that paragraph "arrives here and is asked
for the rule". Bertan pointed out that this is false for a hook named under any
other prefix: it passes the paragraph audit, drops out of this loop in silence,
and nothing counts the check that was never run.

The assistant measured it rather than reasoning about it, by renaming
`no-work-on-stale-branch.sh` to `stale-branch-guard.sh` in two scratch copies of
the worktree — in `settings.json`, in CLAUDE.md and on disk, but not in
`check-hooks.sh` — and reading which hooks the loop asked in each:

| derivation | hooks the stopping-rule loop asked |
|---|---|
| off the paragraph, by `no-` prefix | `no-commit-to-main.sh`, `no-git-push.sh`, `no-pr-decisions.sh` |
| off `REGISTERED`, minus two named lists | those three, **and `stale-branch-guard.sh`** |

Three of four, which is the proportion #84 was filed for, arriving in the change
that cites #84 twice.

The loop now derives its hooks by the subtraction the paragraph audit above it
already makes: what `settings.json` registers, less `NOT_THE_BOUNDARY` (the hooks
about documents and commands), less a new `JUDGES_NO_COMMAND`, which holds
`report-stale-branches.sh` — registered, named in the paragraph, and carrying no
stopping rule because it judges no command and so has no evasion to stop fixing.
That audit holds the paragraph and `settings.json` to each other in both
directions, so the derived set is still the set the paragraph names; what changes
is that a boundary hook arrives whatever it is called. The exclusion is a named
list because it is a decision, which is the reason `NOT_THE_BOUNDARY` is one.

Mutation-checked: emptying `JUDGES_NO_COMMAND` turns exactly two checks red, both
of them `report-stale-branches.sh` being asked for a rule it has no reason to
carry, and nothing else moves.

## The correction session 1 needs, and why it is here rather than there

Bertan found stale numbers in session 1's entry — in the entry whose own review
section is about a stale number. Both are corrected here, forward, because that
is the only direction available: `append-only-docs-edit.sh` refuses every edit to
an existing file under `docs/dev-log/`, and CLAUDE.md's rule is that corrections
go in the newest entry and never backwards. Session 1's entry stands as written,
wrong numbers and all, which is what append-only means.

**The mutation count is 22.** Session 1's entry says "twenty-one" in one place
and "twenty mutations" in another; the commit message on `153c8c2` says both, in
two paragraphs; the body of #132 says twenty-one twice. All four are wrong. The
table in session 1's entry has twenty-two rows, and the table in #132's body has
the same twenty-two. The assistant wrote the counts, then added mutations during
the review-fix pass, then did not recount.

The count went stale three times in one session, so the assistant has stopped
writing it in prose. #132's body now says the mutations were run one at a time
and reverted between, and lets the table be the count; the second commit's
message does the same. A count of rows in a table that sits four lines below the
sentence is not a fact worth restating, and the repository has now paid for that
lesson in #73, in session 1's review and again here.

**The SHA in session 1's header is wrong.** It says the branch carried one
commit, `e8c10b9`. That SHA was amended away before the branch was pushed, and
the commit that exists is `153c8c2`. Naming a commit that never left the
assistant's machine is worse than naming none, so this entry names the branch and
the pull request, both of which are stable, and leaves SHAs to `git log`.

## Two things worth recording plainly

The first is that Bertan's review found nothing wrong with any *result*. The
suite was green, the matrix was right, all twenty-two mutations had behaved, and
he re-ran nine of them and got the assistant's numbers. Every one of his four
findings is about a claim: a tag that says a check is evidence for a story it does
not answer, a comment that says a loop asks something it does not ask, a count
that says twenty-one when the table says twenty-two. This repository's own
standard of care for guard code says a check suite is evidence about the cases it
names and about nothing else — and the failure that keeps recurring is not that
the cases are wrong but that the naming is.

The second is that the assistant reviewed its own commit in session 1, on two
axes, found three real defects, fixed them, and wrote up the finding that none of
them would have been caught by running anything. Bertan then found four more of
exactly that kind, one of them eight lines from a defect the assistant had just
fixed for the identical reason. Self-review found real defects and was not a
substitute for the second reader.

## Where #105 stands

Both commits are on `worktree-issue-105-coverage-gaps`, proposed into `dev-05` as
#132. All three of #105's acceptance criteria are met, by Bertan's independent
measurement as well as the assistant's: `--matrix` reports no uncovered active
requirement, the seven gaps being US-5, US-6 and FR-39 (`seam: none`, awaiting
#110's runbook) and GH-127, GH-130, GH-131 and GH-133 (filed bugs); every new
check is tagged and mutation-checked; and the before-and-after matrix output is in
the pull request body.

Three defects were found while doing #105 and none was pinned: #130 (four `gh api`
rules read an endpoint out of an issue body), #131 (`gh issue develop` creates a
branch on origin that no hook sees) and now #133. All three are sub-issues of #36
with `GH-` entries marked `gap`. Of #103's seven work issues, #104 has landed and
#105 is in review; #106, #107, #108, #109 and #110 remain. #109 gains a fourth
piece of work from this session and starts from ten `says` checks plus a measured
defect report.

## Correction to this entry, appended rather than edited

Two sentences above say Bertan "re-ran nine of the assistant's mutations". That
is wrong twice, and the assistant wrote it in the entry whose subject is counts
going stale.

Bertan's comment says "Nine mutations re-run by me, counts below" and the table
below it lists **eight**. Two of those eight — `_Avoid_: check` dropped from
CONTEXT.md's *Probe*, and the agent section's fences renamed from ```` ```bash ````
to ```` ```sh ```` — he marks as not being in the assistant's table at all. So of
the assistant's twenty-two mutations he re-ran six, and the count in his own prose
does not match the count in his own table either.

The assistant copied "nine" out of that sentence without reading the table under
it, which is the same act that produced the stale counts this entry is about:
restating a number that sits four lines above the thing that would have checked
it. What the review establishes is unchanged — every mutation he ran matched, and
two the assistant had not tabulated behaved as designed.

This correction is appended rather than made in place because
`append-only-docs-edit.sh` refuses every Edit or Write to a file that exists under
`docs/dev-log/`, and `append-only-docs.sh` refuses `rm`, `mv`, `cp`, `tee`,
`sed -i` and a truncating `>` against the same paths. Both fire on existence, not
on whether the file has ever been committed — so a draft the assistant created
twenty minutes earlier, untracked and unpushed, is already history as far as the
guards are concerned, and `>>` is the only door left. That is arguably the guards
working: the assistant does not get to decide which of its own writing counts as
recorded. It is also a shape worth a look, since nothing in CLAUDE.md asks for an
uncommitted draft to be immutable, and the alternative the assistant rejected —
writing the file from a Python script, which the Bash guard cannot read into — is
exactly the evasion CLAUDE.md's left-open list says these hooks do not stop and
are not meant to.

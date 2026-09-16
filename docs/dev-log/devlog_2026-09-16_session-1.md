# 2026-09-16 · session 1 — the fifteen coverage gaps the matrix reported are closed, and two defects were found closing them

**Branch** `worktree-issue-105-coverage-gaps`, cut at `origin/dev-05` `43fb767`.
One commit, `e8c10b9`, one ahead of `origin/dev-05` and 171 ahead of
`origin/main`, proposed into `dev-05`. **Check suite 1902 → 1987 results, every
one of the 1902 present and unchanged** — verified by sorting both runs' result
lines and comparing, not by reading the green line. The only baseline lines
absent from the new run are the fifteen timing measurements, which differ every
run, and the two that state the requirements file's own size (150 → 152
entries). `--matrix`: 19 gaps → 6, and the 15 that closed are all of #105's.
`make test` 595 passed / 5 xfailed / 1 failed —
`test_installed_packages_match_uv_lock`, a worktree venv without the
`migrations` group, failing the same way on `dev-05` and unrelated.

The whole session was issue #105, worked by the assistant unattended from the
issue text and #103's decisions. Bertan took no part in it; every choice below
that the issue left open is the assistant's, and the pull request is where
Bertan reviews them.

---

## 85 checks close the fifteen gaps #105 owned

#104 landed with the known gaps visible rather than hidden: each uncovered
requirement carried `status: gap → #<n>` naming the issue that owed it a check,
and `--matrix` listed them. Fifteen named #105 — US-7, US-14, US-20, US-27,
US-28, US-29, US-31, FR-2, FR-11, FR-23, FR-24, FR-25, FR-26, FR-28 and FR-35.
They are closed by 85 checks in seven groups, and the gap markers are off in
both places the coverage machinery reads — `requirements.md` and the
`REQUIREMENT_SHAPE` literal in the suite, which #104 built so that a marker
taken off is written down twice and shows in the diff.

**US-14, every `gh` issue subcommand.** Three verbs of gh's fifteen were pinned;
twelve are now, off `gh issue --help` rather than off a guess. The thirteenth is
#131, below.

**US-7 and FR-23, refusal messages.** Two refusals in this tree were read for
their verdict and never for their words: the base rule's and the bare push's.
Either could have been emptied to `Blocked.` and the suite would have stayed
green. Ten `says` checks now read them, split so that the two claims fail
apart — the permitted *spelling*, which is what US-7's story asks for, and the
*tail* that says which of four refusals fired. The bare-push literal carries the
fixture's branch name, so it pins that the message interpolates the branch an
agent is actually on rather than a placeholder.

**US-20 and FR-2, the stopping rule.** The rule that says when to stop fixing
evasions lives in a comment, which `armed` cannot pin because it strips comments
before it looks; `written` reads the file as written. The four files are derived
off the CLAUDE.md paragraph audited immediately above, not listed again, so a
boundary hook added without being named there is already red one section earlier
and arrives here to be asked for the rule.

**FR-11 and FR-28, `CONTEXT.md`.** *Check* and *probe* are now checked as a
pair — each entry for its own test and for the other's name in its `_Avoid_`
line, which is the half that makes them define each other rather than merely
stand beside each other. The *worktree branch* entry is asked for the keying it
records: on where the command runs, deliberately not on the branch's name, and
both halves of the "wrong twice over" that the instruction not to "fix" it rests
on.

**US-27, US-28, US-29, FR-24, FR-25, FR-26, the `branch-hygiene` skill.** The
sweep half was already checked by #100's block; the rotation half and the
opening invariant were read by nothing. The strongest of these is not a literal.
US-27 asks that an agent following the skill not run a procedure whose middle
steps are refused, so the agent section's own fenced command blocks are
extracted and put through `no-git-push.sh` and `no-pr-decisions.sh`, and must be
permitted; the two pushes a rotation needs are asked in the other direction and
must be refused, which is the claim the skill's own head makes in as many words.

**US-31 and FR-35, the suite's own limit.** The header says a green run is not a
measure of the boundary, and names the run that was green while an indented
wholesale push inside an `if` was permitted. Neither sentence was read by
anything, which is the exact shape both requirements are about.

## Every new check was mutation-checked, and one mutation corrected the comment beside it

#107's harness has not landed, so twenty-one mutations were run by hand, one at
a time, each reverted before the next. Each turned red the checks it should and
nothing else. The counts, measured:

| mutation | red |
|---|---|
| `gh_rule issue` added beside the existing rules | 18 — all twelve new US-14 rows, plus six `gh issue` commands pinned elsewhere; nothing that is not a `gh issue` command |
| `gh_rule 'issue delete' \|\| gh_rule 'issue transfer'` | 2 of the twelve |
| wrapper rule's group widened to `pr\|release\|api\|issue` | 0 of the new rows |
| `BASE` loses `Write: gh pr create --base dev-NN …` | 5, the spelling checks; the tails stay green |
| retarget refusal routed through the create's sentence | 1 tail; the spellings stay green |
| `gh api` bad-base tail shortened | 2 — the REST and graphql rows, which share one sentence |
| `$CURRENT` → `<branch>` in the bare-push message | 2 |
| the bare-push refusal's reason clause dropped | 1 |
| stopping rule deleted from `no-work-on-stale-branch.sh` | 3 |
| `no-commit-to-main.sh`'s citation of it reworded | 1 |
| `_Avoid_: probe` dropped from CONTEXT.md's *Check* | 1 |
| the keying sentence replaced by a prefix rule | 2 |
| "wrong twice over" softened | 1 |
| "Rotation is a reserved act" softened | 1 |
| invariant loses "in flight against it" | 1 |
| the agent's "report the answers and stop" dropped | 2 |
| `git push origin --delete dev-05` added to the agent's fenced block | 1, the driven check |
| `gh pr merge 5` added to the agent's fenced block | 1, the driven check |
| "never take the merge command ran as evidence" dropped | 1 |
| the header's concrete green-run sentence removed | 2 |
| "evidence about the cases it names" removed | 2 |
| `## What an agent does` renamed | 6, then the fixture guard stops the suite |

The one that corrected a claim: the assistant first wrote that widening the
wrapper rule's group from `pr|release|api` to `pr|release|api|issue` would turn
every new US-14 row red. Measured, it turns **none** of them red — that rule
reads only a wrapped line, so what goes red instead is the pair of wrapped issue
commands already pinned in the #51 section. The mutation that does reach the new
rows is `gh_rule issue`, a subcommand path one word short of the verb whoever
added it would have meant to name. The comment in the suite now records all
three, because the wrong guess is the one a reader makes first.

**The assistant wrote a mutation harness that destroyed its own work, and lost
about an hour to it.** The harness reverted each mutated file with
`git checkout --`, which on uncommitted work discards all of it rather than the
mutation: the first run against `check-hooks.sh` took the session's insertions
with it, and the two mutation results measured after that were of the
pre-session file and meaningless. The assistant had not committed, and had not
considered that the revert step and the work occupied the same file. Rebuilt
from the generating script, which had been kept, and the harness changed to
restore from a copy taken before the mutation. The general shape, worth stating
once: a throwaway tool that reverts from git is safe only against committed work.

## Two defects were found while covering US-14, and neither was pinned

#103 Q18: a defect found during this work is filed as its own bug, with the
check written to the *correct* verdict rather than to today's. Both are
sub-issues of #36 and both have a `GH-` entry with `gap → #<n>`, so `--matrix`
carries them.

**#130, four `gh api` rules read an endpoint out of an issue body.** #105 asked
this question by name and told whoever answered it to decide per case: pin it and
cite CLAUDE.md's left-open item 2 if that item already names it, or file it. It
does not name it — item 2's subject is a line carrying a *wrapper*, and none of
these does. A `gh api` write to an issue is refused when its quoted body names
`/releases`, `repos/o/r/pulls` or `state=closed`, and a *read* of `/releases`
beside an unrelated issue write on the same line is refused with it. The `gh
issue` spelling of the same prose is permitted, which is the control, so the
boundary is spelling-dependent exactly where #36 says it is not. Refusing
direction, and the same shape as #50 and #68: the cost lands on an agent filing
an issue about the boundary whose body quotes the commands it is about, which is
how the issues in this repository are written — #130 included.
`no-pr-decisions.sh`'s own comment already records one of the four as a known
bleed, which is why it is filed rather than pinned: it reads as unfinished, not
as a trade taken.

**#131, `gh issue develop` creates a branch on origin.** It is an issue
subcommand by name, so US-14 says it stays available; it is a ref-creating write
by effect, and no hook sees it, because none of them matches anything but `git
push`. CLAUDE.md says pushing this worktree's branch "is the whole of what it may
push". The assistant's first draft pinned both creating spellings `ALLOW`. That
is pinning a verdict that may be wrong, which Q18 forbids, so the section pins
`gh issue develop --list` as the read it is and leaves the two creating spellings
unpinned with a comment pointing at #131. US-14 is covered either way — coverage
is one bit per requirement, and the other twelve rows carry it — so nothing in
the matrix hides it. The issue sets out the three answers available; which is
taken is Bertan's.

Severity, stated rather than implied: #131 cannot move or delete a ref and cannot
push a commit. What it can do is leave a branch on `origin` that nobody cut
deliberately, which lands in the one category `branch-hygiene` says it cannot
resolve — a branch with no pull request, where only whoever cut it knows.

## Review of the assistant's own commit found three more defects in it

`/code-review` was run against `origin/dev-05` before the pull request was
opened, on two axes in parallel. Both axes found real defects in the assistant's
work, and all of them were in the artefact whose job is to make claims checkable.

- **A stale count, in the file that argues counts go stale.** The US-14 loop has
  twelve rows. The assistant wrote "twelve" in one comment and "thirteen" in
  another, and repeated "thirteen" in `requirements.md`. The cause was removing
  the two `gh issue develop` rows for #131 after writing the counts, and not
  re-reading them. CLAUDE.md's guard-code paragraph names this exact failure.
- **A mis-tag.** The check/probe block was tagged `req FR-11 US-24 FR-27`. FR-27
  names *worktree branch*, *active dev branch* and *reserved act*; US-24 asks for
  the branch words. The block reads only the *Check* and *Probe* entries and
  establishes neither, so two of its three tags were dilution — the one failure
  `requirements.md` says the coverage machinery cannot catch, arriving in the
  change that cites it. Now `req FR-11`.
- **#84's shape, in the change that cites #84.** The heading pair
  `## What an agent does` / `^## Bertan` was walked twice, by two awk programs
  carrying the same two literals, so one renaming would have had to be fixed in
  two places. The second walk now reads the already-extracted section file, which
  the `written`/`unarmed` pair has bounded from both ends.

Two smaller ones were taken as well: the base-rule message block pinned five
spellings and only four tails, leaving the graphql spelling's tail unasked — the
#40 shape, a claim that holds for one spelling and not another — and the rotation
block's stated reason for writing its commands out did not distinguish them from
the agent block's `gh pr view <PR#>`, which is equally unrunnable and is fed
anyway. The real distinction is where the placeholder sits: `<PR#>` is in an
argument position no rule reads, `dev-NN+1` is in the branch-name position the
push rule does read.

Worth recording plainly: the suite was green before this review, the twenty
mutations had all behaved, and none of the three defects would have been found by
running anything. That is the finding this repository keeps making about itself,
made once more by the assistant against its own work.

## What #105's own gap list got wrong, and what it got right

The issue's starting list is explicit that the matrix is authoritative and the
list is a starting point. Two entries had moved by the time the work ran.

- **US-24, the glossary.** The issue says `CONTEXT.md`'s *Active dev branch*
  entry has no check. It has had five since #99, tagged `GH-99.1 FR-27 US-24`.
  Nothing was added; Q1 is gap-fill only.
- **US-15, releases.** Covered by #97, as the issue expected. Confirmed, not
  re-checked.

US-2, US-3, US-4 and US-25, which the list asks to verify in both directions now
that #94 has landed, were read off the matrix and are covered: 6/0 refuse-only,
89/21/5, 0/25 permit-only and 4/11 respectively. Nothing was added for them
either.

## State the next session inherits

`--matrix` reports six gaps, and every one is accounted for: US-5, US-6 and
FR-39 declare `seam: none` and are verified by `.claude/hooks/runbook.md`, which
#110 has not written; GH-127, GH-130 and GH-131 are filed bugs. There is no
uncovered active requirement without an issue that owns it, which is #105's
acceptance criterion.

Of #103's seven work issues, #104 and #105 have landed or are in review. #106
(invariance families), #107 (the mutation harness — which would have caught none
of this session's three review findings, all of which are about text), #108,
#109 and #110 remain. #109 in particular now overlaps less than it did: the two
story-7 messages #105 was told to add if #109 had not landed are added, so #109's
message work starts from ten `says` checks rather than none.

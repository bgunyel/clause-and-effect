# Requirements of the agent boundary and its hooks

Every requirement the hooks under `.claude/hooks/` have accumulated, each with a
permanent ID, so that "is this requirement verified?" is answered by
`bash .claude/hooks/check-hooks.sh --matrix` rather than by reading the suite.
The decisions behind this file are #103's, taken in a grilling session on
2026-09-13, and their question numbers (Q2, Q6 …) are cited below. #104 built it.

`check-hooks.sh` reads this file. Every check there carries the IDs it
establishes, and the suite fails when an active requirement here has no check
that covers it. It is next to the suite and outside the `docs/` taxonomy on
purpose (Q6): it is an input to the checks, not documentation of them.

## The rules this file keeps

**IDs are never renumbered and never reused.** A requirement that stops being
true is marked, never deleted: its `status` says what became of it. A new
requirement is appended at the end of its family. So an ID cited in an issue, a
commit or a check means the same thing for as long as this repository exists.

**A pull request that fixes a hook defect appends its `GH-<n>` entry** and tags
the check that fails without the fix (Q16). A pull request carries no ID of its
own; its issue does. This is what keeps the matrix whole after #103's work ends,
and the suite holds half of it: every `#<n>` cited in `check-hooks.sh` must have
an entry here, or be listed under *Citations that are not requirements* with a
reason.

## The families

- `US-n`: #36's user stories, transcribed verbatim. A story a later amendment
  replaced is marked `superseded-by`, never rewritten (Q10).
- `FR-n`: #36's Implementation Decisions (stages 0–3), its Testing Decisions,
  and its Amendments, one per behaviour that can be tested on its own.
- `GH-<n>` and `GH-<n>.<m>`: the issues after #36 that change what a hook decides
  or what the suite pins (Q7, Q13). A sub-ID is used when one issue names more
  than one behaviour that can fail independently (Q14).

#37–#41 get no IDs of their own, because their content is the FRs (Q12). Their
acceptance criteria are quoted at the foot of this file, each mapped to the IDs
that carry it or marked dropped (Q23).

## An entry

Each entry is a `### <ID>` heading followed by fields, one `- key: value` per
field, a value continuing onto lines indented by two spaces.

- `text`: the requirement. Verbatim for a story.
- `from`: the issue or section it came from.
- `kind`: `GH-` entries only. `defect-permitting`, `defect-refusing` or
  `doc-claim` (Q13).
- `status`: one of
  - `active`
  - `retired: <reason>`
  - `superseded-by: <ID>` (Q10)
  - `drifted: <evidence>`, for a requirement that has stopped being true with
    nothing replacing it (Q22)
  - `gap → #<n>`, for a requirement known not to be covered yet, where issue
    `#<n>` owns closing it. This is how #104 landed green with the known gaps
    visible rather than hidden: each is listed by `--matrix`, and the coverage
    check does not ask about it. It is taken off when `#<n>` covers it.
- `direction`: `refuse-only: <reason>`, `permit-only: <reason>` or
  `static: <reason>`, for a requirement that is one-sided (Q15). See below.
- `seam: none` together with `verify: runbook §<n>`, `verify: review` or
  `verify: tests/<file>.py`, for a requirement no check can reach (Q17).
- `note`: anything a reader of the entry needs that is not one of the above.

## What covers a requirement

A check in `check-hooks.sh` has one of three directions, fixed by what it reads:

- **refuse**: it expects a hook to refuse. A `BLOCK` verdict, or the message of
  a refusal (`says`, `says_not`, `feed_says`).
- **permit**: it expects a hook to permit. An `ALLOW` verdict.
- **static**: it reads no verdict. A file's text (`armed`, `written`, `unarmed`,
  `beside`), a function's output (`tok`, `holds`, `lacks`, `present`), a timing,
  or a count derived from the tree.

An `active` requirement is **covered** (Q15) when it has

- at least one refusing and one permitting check, which is #36's "both
  directions, always" made computable; or
- when it declares `direction: refuse-only` or `permit-only`, one check of that
  direction; or
- when it declares `direction: static`, any one check. That is a requirement
  about what a file says or what a function returns, where there is no verdict
  to have two directions of. It is a third value beside Q15's two, added by #104
  because a third of these requirements are of that kind; declaring it is what
  keeps a behavioural requirement from being covered by a pin on its text.

A requirement with `seam: none` needs no check, and has none tagged with it; its
`verify` must resolve: `tests/<file>.py` to a file that exists, and
`runbook §<n>` to a heading `## §<n>` in `.claude/hooks/runbook.md`.

The suite fails on each of these, and `--matrix` shows the rest:

- an `active` requirement that is not covered;
- a check with no tags, or a tag naming an ID not in this file;
- an entry that is malformed: an ID out of family, one used twice, one under a
  `##` heading that holds no entries, a missing field, an unknown status or kind,
  a `superseded-by` naming no entry, a `direction` with no reason, `seam: none`
  with a `verify` that does not resolve, and `seam: none` with checks tagged with
  it after all;
- a check recording a direction other than refuse, permit and static;
- a shape other than the one the suite holds as a literal: every entry by ID,
  with whatever takes it off the both-directions rule beside it -- a status
  other than `active`, a declared `direction`, and `seam: none` with the kind of
  its `verify`. Those are everything the coverage check reads off an entry, so
  an edit here that changes what the check asks of a requirement -- a marker
  added, taken off or moved to another entry, a direction declared, a move to
  `seam: none`, a deletion -- is made twice, here and in the suite, and the
  second is what makes it visible. Which checks carry a tag is not in it: a
  check tagged with an ID it does not establish covers that ID all the same;
- a criterion of #37–#41 with no mapping, a mapping naming an unknown ID, or a
  number of criteria for an issue other than the number that issue has;
- a `#<n>` cited in `check-hooks.sh` with neither an entry nor a listing under
  *Citations that are not requirements*.

## User stories

### US-1
- text: As Bertan, I want `main` to receive changes only through a pull request I
  merge myself, so that nothing reaches the default branch without my review.
- from: #36, User Stories, 1
- status: active
- direction: refuse-only: the story withholds main from an agent; what it leaves an
  agent is US-4's and US-8's

### US-2
- text: As Bertan, I want the active dev branch to be pushable only by me, so that
  the integration branch advances when I decide it does and not when an agent
  finishes something.
- from: #36, User Stories, 2
- status: active
- direction: refuse-only: the story withholds the active dev branch from an agent;
  the push it leaves an agent is US-4's

### US-3
- text: As Bertan, I want an agent to be able to push exactly one branch — the one
  belonging to the linked worktree it is running in — so that it can open a
  pull request without being able to reach anything else.
- from: #36, User Stories, 3
- status: active

### US-4
- text: As an unattended agent, I want to push my own worktree branch, so that
  opening a pull request has a remote branch to work from.
- from: #36, User Stories, 4
- status: active
- direction: permit-only: the story asks that one push stay possible; what is
  refused beside it is US-3's

### US-5
- text: As an unattended agent, I want my worktree to be created from the active dev
  branch, so that the pull request I open contains only my own work and not a
  reversion of everything merged into that branch since.
- from: #36, User Stories, 5
- status: gap → #110
- seam: none
- verify: runbook §1

### US-6
- text: As Bertan, I want `EnterWorktree` and a manually created worktree to share a
  base, so that which tool an agent reached for does not change what my review
  sees.
- from: #36, User Stories, 6
- status: gap → #110
- seam: none
- verify: runbook §1

### US-7
- text: As an unattended agent, I want a refusal to tell me the permitted spelling,
  so that I can correct myself in one step instead of guessing.
- from: #36, User Stories, 7
- status: active
- direction: refuse-only: a message is written only on a refusal

### US-8
- text: As Bertan, I want a pull request opened by an agent to target the active dev
  branch, so that no agent-authored change is ever one merge click away from
  `main`.
- from: #36, User Stories, 8
- status: active

### US-9
- text: As Bertan, I want an agent that omits the base to be refused rather than
  defaulted, so that a pull request never reaches `main` because nobody said
  where it should go.
- from: #36, User Stories, 9
- status: active

### US-10
- text: As Bertan, I want retargeting an existing pull request to be governed by the
  same rule as opening one, so that a permitted base is not a formality undone
  by the next command.
- from: #36, User Stories, 10
- status: active

### US-11
- text: As Bertan, I want the REST and graphql spellings of creating a pull request
  covered too, so that the rule is not merely a rule about one convenient
  command.
- from: #36, User Stories, 11
- status: active

### US-12
- text: As an unattended agent, I want the browser hand-off form of opening a pull
  request to remain available, so that I can hand Bertan a prepared pull
  request when the hook cannot judge what happens next.
- from: #36, User Stories, 12
- status: active

### US-13
- text: As an unattended agent, I want to keep commenting on, editing, viewing and
  reading pull requests, so that the boundary constrains deciding and not
  talking.
- from: #36, User Stories, 13
- status: active
- direction: permit-only: the story names what stays permitted; the refusals
  beside it are US-15's

### US-14
- text: As an unattended agent, I want every issue subcommand to stay available, so
  that issue work is unaffected by a rule about pull requests.
- from: #36, User Stories, 14
- status: active
- direction: permit-only: the story names what stays permitted

### US-15
- text: As Bertan, I want merging, verdict reviews, closing, reopening and releases
  to stay refused, so that stage 2 adds a rule without loosening one.
- from: #36, User Stories, 15; widened for releases by #36's Amendment of
  2026-09-13, which is FR-48
- status: active
- note: active rather than superseded-by, because the Amendment widened what the
  story refuses and replaced none of it; every act the story names is still
  refused

### US-16
- text: As a reviewer of this repository, I want to know what an unattended agent
  can do to it without reading the two hooks and their tokeniser, so that I can judge the
  boundary rather than the implementation.
- from: #36, User Stories, 16
- status: active
- direction: static: a claim about what CLAUDE.md's boundary section says

### US-17
- text: As a future contributor, I want to know why the boundary is carried by hooks
  rather than a server-side ruleset, so that I do not propose a `dev-*`
  ruleset that was already considered and rejected for a reason.
- from: #36, User Stories, 17
- status: active
- seam: none
- verify: review

### US-18
- text: As a future contributor, I want the rejected alternative — giving the agent
  its own identity through a deploy key or an installation token — recorded,
  so that a real option is not lost behind a sentence claiming nothing else
  was possible.
- from: #36, User Stories, 18
- status: active
- seam: none
- verify: review

### US-19
- text: As a future contributor, I want to know that the hooks do not guard
  themselves, so that I do not mistake an unnamed gap for a covered one.
- from: #36, User Stories, 19
- status: active
- direction: static: a claim about what CLAUDE.md says

### US-20
- text: As a maintainer of these hooks, I want a written rule for when a newly found
  evasion earns a fix, so that the file stops growing when the shapes stop
  being ones an agent would plausibly write.
- from: #36, User Stories, 20
- status: active
- direction: static: a claim about what the hook files say

### US-21
- text: As a maintainer of these hooks, I want the standard of care for guard code
  named alongside the eval and product standards, so that "which bar does this
  meet" has an answer rather than an argument.
- from: #36, User Stories, 21
- status: active
- seam: none
- verify: review

### US-22
- text: As a reader of this repository, I want **probe** to keep meaning an
  empirical measurement, so that the word still distinguishes what was
  measured from what was asserted.
- from: #36, User Stories, 22
- status: active
- direction: static: a claim about the words the hook files use

### US-23
- text: As a reader of the hook suite, I want its 207 assertions called checks, so
  that a file of literal expectations is not named after the thing it is not.
- from: #36, User Stories, 23
- status: active
- direction: static: a claim about the words the hook files use

### US-24
- text: As an agent working anywhere in this repository, I want a glossary that
  settles which word to use for the branch I work on and the branch I propose
  into, so that four spellings of the same idea do not accumulate.
- from: #36, User Stories, 24
- status: active
- direction: static: a claim about what CONTEXT.md says

### US-25
- text: As a future contributor, I want the glossary to record that the boundary is
  keyed on whether the command runs in a linked worktree and deliberately not
  on the branch's name, so that I do not "fix" it into a naming rule.
- from: #36, User Stories, 25
- status: active

### US-26
- text: As Bertan, I want one word for the class of acts reserved to me, so that
  advancing the active dev branch, merging any pull request, rotating the dev
  branch and publishing a release are one concept rather than four rules.
- from: #36, User Stories, 26
- status: active
- direction: static: a claim about what CONTEXT.md says

### US-27
- text: As an agent asked to rotate the dev branch, I want the skill to describe
  what I can actually do, so that I do not run a procedure whose middle steps
  are refused.
- from: #36, User Stories, 27
- status: active
- direction: static: a claim about what the branch-hygiene skill says

### US-28
- text: As Bertan, I want rotation of the active dev branch to be mine, so that the
  one procedure that advances the integration branch and destroys a branch is
  not delegated.
- from: #36, User Stories, 28
- status: active
- direction: static: a claim about what the branch-hygiene skill says

### US-29
- text: As an agent following the rotation skill, I want a useful half of the job —
  confirming the merge really happened and reporting what is stale — so that
  the skill stays worth invoking.
- from: #36, User Stories, 29
- status: active
- direction: static: a claim about what the skill says and the report prints

### US-30
- text: As a reviewer of any of these stages, I want each fixed defect to arrive
  with a check that fails without its fix, so that the suite is evidence about
  the change and not just green.
- from: #36, User Stories, 30
- status: active
- seam: none
- verify: review

### US-31
- text: As a reviewer, I want to be told what the check suite's count is worth, so
  that I remember it was green while an indented wholesale push inside an `if`
  was permitted.
- from: #36, User Stories, 31
- status: active
- direction: static: a claim about what the suite's header says

### US-32
- text: As Bertan, I want each stage to arrive as its own pull request, so that I
  review one reviewable step at a time.
- from: #36, User Stories, 32
- status: active
- seam: none
- verify: review

## Functional requirements

### FR-1
- text: `worktree.baseRef` is set to `head` in the checked-in settings, so that
  `EnterWorktree` branches from the session's HEAD, the active dev branch, rather
  than from `origin/main`.
- from: #36, Implementation Decisions, Stage 0
- status: superseded-by: GH-99.2

### FR-2
- text: The hook files carry the stopping rule: a newly found evasion earns a fix
  only if it is a shape an agent would plausibly write, not one it would have to
  construct.
- from: #36, Implementation Decisions, Stage 0
- status: active
- direction: static: a claim about what the hook files say

### FR-3
- text: A command is judged where it stands in a command position, wherever an
  agent would plausibly write it: after `;`, `&&`, `||`, `|` or a newline, after a
  control word, indented, inside `$( )` or backticks, joined across a line
  continuation, and behind an environment assignment. Text that
  only names a command is not one: a heredoc body, a quoted argument, a word in
  prose.
- from: #36, Implementation Decisions, Stage 0, the stopping rule, which names three
  shapes ("Indentation, `&&` chains and control words clear that bar"); the others
  are the review findings on PR #35 that the rule was written after, as this
  suite's header records them. Prefix words and quoted separators are not here:
  they are GH-43.6, GH-79.1 and GH-68.1
- status: active

### FR-4
- text: A shell wrapper (`bash -c`, `sh -c`, `eval`, a heredoc fed to a shell)
  around a command a boundary hook guards is refused outright rather than
  assessed, because nothing can be read out of a quoted payload. A wrapper
  around anything else is not.
- from: #36, Implementation Decisions, Stage 0, the stopping rule ("refusing
  wrappers outright is the designed answer and not a limitation"). Its last
  sentence is not #36's: it is CLAUDE.md's left-open item 1, "Only what a hook
  guards is refused", as #51 and #73 settled it
- status: active

### FR-5
- text: CLAUDE.md does not claim the boundary "can rest on nothing else", and
  states that it rests on the hooks because the agent shares Bertan's
  credentials, a choice open to revision rather than a constraint.
- from: #36, Implementation Decisions, Stage 0
- status: active
- seam: none
- verify: review

### FR-6
- text: CLAUDE.md's "deliberately left open" section names that nothing guards
  `.claude/`, with the standard that excludes it: these hooks stop mistakes, and
  an agent does not mistakenly rewrite the hook that just refused it.
- from: #36, Implementation Decisions, Stage 0
- status: active
- direction: static: a claim about what CLAUDE.md says, of which the count of
  Edit hooks is the part a check can hold

### FR-7
- text: CLAUDE.md's boundary section is trimmed to the operative paragraph an agent
  needs each session.
- from: #36, Implementation Decisions, Stage 0
- status: drifted: the section "What an unattended agent may do to this repository"
  is 118 lines at 9d217c6, grown by the worktree rule (#99), the five numbered
  left-open consequences (#73) and the hooks named since (#63)

### FR-8
- text: `docs/adr/` holds the repository's first ADR, recording why the boundary is
  enforced by hooks rather than a server-side ruleset and the rejected
  alternative of giving the agent its own actor, and no inventory of permitted
  commands.
- from: #36, Implementation Decisions, Stage 0
- status: active
- seam: none
- verify: review

### FR-9
- text: `probe` becomes `check` throughout the hook suite: the script's name, its
  assertion function, its header, and CLAUDE.md's invocation line.
- from: #36, Implementation Decisions, Stage 1
- status: active
- seam: none
- verify: review

### FR-10
- text: `scripts/probe_*.py` is untouched, and `probe` keeps its meaning of an
  empirical measurement.
- from: #36, Implementation Decisions, Stage 1
- status: active
- seam: none
- verify: review

### FR-11
- text: `CONTEXT.md` at the repository root defines *check* and *probe* against each
  other.
- from: #36, Implementation Decisions, Stage 1
- status: active
- direction: static: a claim about what CONTEXT.md says

### FR-12
- text: The rename changes no behaviour, and the check count is identical before
  and after it.
- from: #36, Implementation Decisions, Stage 1
- status: retired: a property of that one change, measured when #38 landed, not a
  standing requirement

### FR-13
- text: The base rule lives in the existing pull-request hook, whose header widens
  to "may not decide one, and may propose one only into the active dev branch";
  no seventh hook is added.
- from: #36, Implementation Decisions, Stage 2
- status: active
- seam: none
- verify: review

### FR-14
- text: A pull request's base must be named in the command. A create naming no base
  is refused, rather than defaulted to the repository's default branch.
- from: #36, Implementation Decisions, Stage 2
- status: active

### FR-15
- text: Every base a command names must match `^dev-[0-9]+$`. A pattern, not a
  fork-point computation.
- from: #36, Implementation Decisions, Stage 2
- status: active

### FR-16
- text: The base rule covers `gh pr create`.
- from: #36, Implementation Decisions, Stage 2, the four spellings
- status: active

### FR-17
- text: The base rule covers retargeting through `gh pr edit --base`.
- from: #36, Implementation Decisions, Stage 2, the four spellings
- status: active

### FR-18
- text: The base rule covers a REST write to the pull-requests collection.
- from: #36, Implementation Decisions, Stage 2, the four spellings
- status: active

### FR-19
- text: The base rule covers the `createPullRequest` graphql mutation.
- from: #36, Implementation Decisions, Stage 2, the four spellings
- status: active

### FR-20
- text: The two API spellings are decided by the hook's write-detection helper and
  not by the endpoint, so a read of a pull request through `gh api` is permitted.
- from: #36, Implementation Decisions, Stage 2
- status: active

### FR-21
- text: The browser hand-off form of opening a pull request stays permitted. It
  exempts a missing base and nothing else.
- from: #36, Implementation Decisions, Stage 2
- status: active

### FR-22
- text: `cs_gh_args` in the shared tokeniser, mirroring the git-argument helper,
  returns a subcommand's own arguments and signals by its exit status whether the
  command was that subcommand.
- from: #36, Implementation Decisions, Stage 2
- status: active
- direction: static: seam 2, a function's output and exit status

### FR-23
- text: The base rule's refusal messages name the permitted spelling, consistent
  with the existing ones.
- from: #36, Implementation Decisions, Stage 2
- status: active
- direction: refuse-only: a message is written only on a refusal

### FR-24
- text: `branch-hygiene` is Bertan's procedure: rotation is described as his, and
  an agent is instructed to run nothing the hooks refuse.
- from: #36, Implementation Decisions, Stage 3
- status: active
- direction: static: a claim about what the skill says

### FR-25
- text: The agent's half of `branch-hygiene` stays: confirm from the remote that the
  merge happened, and report what is stale.
- from: #36, Implementation Decisions, Stage 3
- status: active
- direction: static: a claim about what the skill says and the report prints

### FR-26
- text: The skill's invariant is one active dev branch plus `main`, with worktree
  branches in flight against the former.
- from: #36, Implementation Decisions, Stage 3
- status: active
- direction: static: a claim about what the skill says

### FR-27
- text: `CONTEXT.md` defines *worktree branch*, *active dev branch* and *reserved
  act*.
- from: #36, Implementation Decisions, Stage 3
- status: active
- direction: static: a claim about what CONTEXT.md says

### FR-28
- text: The *worktree branch* entry records that the boundary is keyed on whether
  the command runs in a linked worktree and deliberately not on the branch's name,
  and why.
- from: #36, Implementation Decisions, Stage 3
- status: active
- direction: static: a claim about what CONTEXT.md says

### FR-29
- text: *Reserved act* covers advancing the active dev branch, merging any pull
  request, rotating the dev branch and publishing a release.
- from: #36, Implementation Decisions, Stage 3
- status: active
- direction: static: a claim about what CONTEXT.md says

### FR-30
- text: CLAUDE.md's rules section names the guard-code standard of care: its
  evidence is the check suite, and no fix lands without a check that fails
  without the fix.
- from: #36, Implementation Decisions, Stage 3
- status: active
- seam: none
- verify: review

### FR-31
- text: No new seam is introduced by any stage of the specification.
- from: #36, Testing Decisions, Seam 1
- status: drifted: `check-hooks.sh` names four seams of its own beyond the two #36
  listed, each where it begins: the arming literals ("A second kind of check"),
  the Edit companion's file path ("A new seam in this suite, named as one"), the
  CLAUDE.md audit ("A third kind of check") and the citation audit ("A fourth
  kind of check")

### FR-32
- text: Expected verdicts are literals, never derived by running the script under
  test.
- from: #36, Testing Decisions
- status: active
- seam: none
- verify: review

### FR-33
- text: Both directions, always: each rule has checks that it refuses what it
  should and that it still permits what it should.
- from: #36, Testing Decisions
- status: active
- direction: static: made computable by the coverage check, which reads tags
  rather than verdicts

### FR-34
- text: The one standing exception to literal verdicts is the context banner:
  whether the current branch may be pushed is read off the suite's own checkout.
- from: #36, Testing Decisions
- status: superseded-by: GH-94.3

### FR-35
- text: The suite states its own limit: that it was green while an indented
  wholesale push inside an `if` was permitted, and that a check suite is evidence
  about the cases it names and nothing else.
- from: #36, Testing Decisions
- status: active
- direction: static: a claim about what the suite's header says

### FR-36
- text: New checks are mutation-checked: the rule is broken deliberately and the
  checks are confirmed to go red.
- from: #36, Testing Decisions
- status: active
- seam: none
- verify: review

### FR-37
- text: An agent starts a new worktree branch for each unit of work, forked from
  the active dev branch's tip, and never reuses an existing worktree.
- from: #36, Amendment of 2026-09-09, the branch lifecycle rule
- status: active
- direction: static: a rule stated in CLAUDE.md and CONTEXT.md; no hook enforces
  where a branch starts, and CLAUDE.md says so

### FR-38
- text: A worktree branch exists for exactly one pull request. When that pull
  request merges into the active dev branch the branch has ceased to exist, and
  work on it is refused until it is removed, remotely by `delete_branch_on_merge`
  and locally by Bertan's sweep.
- from: #36, Amendment of 2026-09-09, the branch lifecycle rule
- status: active

### FR-39
- text: The repository has `delete_branch_on_merge` enabled and
  `allow_squash_merge` and `allow_rebase_merge` disabled.
- from: #36, Amendment of 2026-09-09, and Amendment of 2026-09-11
- status: gap → #110
- seam: none
- verify: runbook §3

### FR-40
- text: A file in `.claude/` that arms enforcement rather than performing it
  carries a check asserting its arming property as a literal.
- from: #36, Amendment of 2026-09-09
- status: active
- direction: static: a property of the file's text

### FR-41
- text: `report-stale-branches.sh` reads `allow_squash_merge`, `allow_rebase_merge`
  and `delete_branch_on_merge` each session and reports any that has drifted from
  what the branch lifecycle rule requires.
- from: #36, Amendment of 2026-09-11
- status: active
- direction: static: a property of the report's text and output

### FR-42
- text: The settings read is bounded and fails open on its own timeout: an offline
  session starts, and the report says the settings were not read.
- from: #36, Amendment of 2026-09-11
- status: active
- direction: static: a property of the report's text and output

### FR-43
- text: `check-hooks.sh` pins the settings read, the three settings it names, the
  required values, the bound and the fail-open message as literals, and pins the
  report hook's timeout against the sum of the budgets it spends in series.
- from: #36, Amendment of 2026-09-11
- status: active
- direction: static: a property of the files' text

### FR-44
- text: The guard's header states no setting's value, and points at the report as
  the live answer.
- from: #36, Amendment of 2026-09-11
- status: active
- direction: static: a claim about what the guard's header says

### FR-45
- text: Every user story, functional requirement and boundary issue has a permanent
  ID in `.claude/hooks/requirements.md`, never renumbered or reused, and a
  requirement that stops being true is marked rather than deleted.
- from: #36, Amendment of 2026-09-13
- status: active
- direction: static: a property of this file, read by the suite

### FR-46
- text: The check suite fails when an active requirement has no covering check.
- from: #36, Amendment of 2026-09-13
- status: active
- direction: static: a property of the tags and this file, read by the suite

### FR-47
- text: The acceptance criteria of #37–#41 are carried in `requirements.md`
  verbatim, each mapped to the requirement that holds it.
- from: #36, Amendment of 2026-09-13
- status: active
- direction: static: a property of this file, read by the suite

### FR-48
- text: Every read-only `gh release` action is permitted and every other release
  action is refused: an allowlist of read verbs, so a subcommand `gh` adds later
  is refused until named.
- from: #36, Amendment of 2026-09-13, user story 15 widened
- status: active

### FR-49
- text: A hook that cannot read its input fails closed: `jq` absent, stdin that is
  not JSON, or no command field. An empty command string still permits. Every
  hook, enforced once in `lib/command-scan.sh`.
- from: #36, Amendment of 2026-09-13
- status: active

## Boundary issues

### GH-43.1
- text: `no-commit-to-main.sh` does not read text as a command: a heredoc body or a
  quoted string naming a commit or a push to main is permitted.
- from: #43
- kind: defect-refusing
- status: active

### GH-43.2
- text: `no-commit-to-main.sh` refuses a command that changes where git runs or
  which branch is checked out before a commit or push (`cd`, `GIT_DIR=`, `-C`,
  `--git-dir`, `checkout main`, `switch main`), because it reads the branch where
  the hook runs.
- from: #43
- kind: defect-permitting
- status: active

### GH-43.3
- text: `no-commit-to-main.sh` refuses a shell wrapper around a commit or a push,
  consistent with its two siblings.
- from: #43
- kind: defect-permitting
- status: active

### GH-43.4
- text: `no-commit-to-main.sh` refuses a push that reaches main without naming it:
  `--all`, `--mirror`, configuration set inline, and `HEAD` or `@` while on main.
  A push of a dev branch is none of its business.
- from: #43, and the review of its migration
- kind: defect-permitting
- status: active

### GH-43.5
- text: `no-commit-to-main.sh`'s refusals still name main and say which rule fired.
- from: #43
- kind: doc-claim
- status: active
- direction: refuse-only: a message is written only on a refusal

### GH-43.6
- text: A prefix word with an operand (`timeout 30`), a prefix word the list lacked
  (`sudo`, `doas`, `setsid`, `chronic`), a prefix word's separated option value,
  and git's directory options in their separated spelling do not hide a command,
  in any hook.
- from: #43, the review of its migration and of PR #49
- kind: defect-permitting
- status: active

### GH-44.1
- text: On a worktree branch whose upstream is gone, a commit, cherry-pick, revert,
  am, merge and rebase are refused, with a message naming the merge.
- from: #44
- kind: defect-permitting
- status: active

### GH-44.2
- text: On a worktree branch with nothing of its own that the active dev branch has
  moved past (ahead 0, behind more than 0), the same commands are refused, with a
  message about state and not about a merge.
- from: #44
- kind: defect-permitting
- status: active

### GH-44.3
- text: Under the fallback detector, a merge or rebase naming the active dev branch
  is permitted, being a fast-forward, and one naming anything else, naming
  nothing, forced to commit, or preceded by a move of directory or branch, is
  refused. Under `upstream: gone` both are refused.
- from: #44
- kind: defect-permitting
- status: active

### GH-44.4
- text: A mid-operation continuation (`rebase --continue`, `merge --abort`,
  `cherry-pick --skip`) is permitted in a refused state, and a continuation flag
  anywhere but in that position, a commit message included, is not.
- from: #44
- kind: defect-permitting
- status: active

### GH-44.5
- text: The guard keys on the linked worktree: a fresh branch at the dev tip and a
  branch carrying work are permitted, and so is the main checkout at the same
  commit as a stale branch.
- from: #44
- kind: defect-permitting
- status: active

### GH-44.6
- text: The fallback abstains when no `refs/remotes/origin/dev-*` exists or the
  ancestry cannot be read, and `upstream: gone` still refuses then.
- from: #44
- kind: defect-permitting
- status: active

### GH-44.7
- text: A SessionStart hook runs `report-stale-branches.sh`, which fetches with an
  explicit prune, is bounded and fails open, reports, and removes nothing.
- from: #44
- kind: defect-permitting
- status: active
- direction: static: arming properties, asserted as literals (FR-40)

### GH-47.1
- text: A flag written before the group or before the subcommand (`-R`, `--repo`,
  `--hostname`) evades no `gh` rule, and does not make an ordinary subcommand a
  decision.
- from: #47, and the review of 02a14d8 that preceded it
- kind: defect-permitting
- status: active

### GH-47.2
- text: Every `gh` command on the line is judged, not only the first: `cs_gh_args`
  answers about the first match, so the rules loop per command.
- from: #47
- kind: defect-permitting
- status: active
- direction: refuse-only: what is asserted is that a second command is reached,
  which only a refusal can show

### GH-50.1
- text: A redirection is not an argument. An otherwise permitted push wearing one is
  permitted, in every spelling of the operator, and a refused push wearing one is
  still refused.
- from: #50
- kind: defect-refusing
- status: active

### GH-50.2
- text: Dropping redirections hides nothing: a process substitution and a command
  substitution used as a target keep their command, and a redirect inside quotes
  is text.
- from: #50
- kind: defect-permitting
- status: active
- direction: refuse-only: a drop can only hide a command, and what it must not
  hide is a refusal

### GH-50.3
- text: A quoted redirect target is left in the arguments, so a push wearing one is
  refused; the same target unquoted is permitted. Taken knowingly, as a shortfall
  against #50.
- from: #50
- kind: defect-refusing
- status: active

### GH-51.1
- text: A wrapped `gh pr`, `gh release` or `gh api` is refused whatever stands
  between `gh` and the group, a flag or a line continuation included.
- from: #51, and its review
- kind: defect-permitting
- status: active

### GH-51.2
- text: The verb is not read inside a wrapper: a wrapped read is refused with the
  writes, the refusal reaches an unwrapped `gh` command sharing the line in either
  order, and a wrapper named only in passing reaches nothing.
- from: #51
- kind: defect-refusing
- status: active

### GH-58.1
- text: The catch-up merge or rebase must name the commit the ancestry was read
  against: a local `dev-NN` that has diverged, is behind, or does not exist is
  refused in its short and `refs/heads/` spellings, and the remote spelling is
  permitted.
- from: #58
- kind: defect-permitting
- status: active

### GH-58.2
- text: An unresolvable dev tip withdraws the carve-out rather than widening it.
- from: #58
- kind: defect-permitting
- status: active
- direction: static: no running hook reaches that line, because the ancestry read
  fails first and the guard abstains, so the line is pinned as text; the
  abstention beside it is GH-44.6's verdict

### GH-61
- text: `docs/research/` is named in CLAUDE.md's documentation table, and stays
  outside the append-only guard.
- from: #61
- kind: doc-claim
- status: active
- seam: none
- verify: tests/test_docs_directory_naming.py
- note: in the shape #103 Q30 gave it. The checks that `docs/research/` stays
  writable carry GH-69.2 and GH-69.3, whose rules they exercise; tagged GH-61 as
  well, they would contradict its `seam: none`

### GH-62
- text: The two derivations of the active dev branch, in the guard and in the
  report, are each pinned whole and held equal to each other, and their
  rationale is argued once.
- from: #62
- kind: defect-permitting
- status: active
- direction: static: a property of two files' text

### GH-63
- text: CLAUDE.md's boundary paragraph names every hook `settings.json` registers
  for the boundary, and names none that is not registered or not on disk.
- from: #63
- kind: doc-claim
- status: active
- direction: static: a document asserted against configuration

### GH-68.1
- text: A separator inside quotes does not cut a command, so an ordinary `sed` or
  `grep` naming a push or a commit is permitted.
- from: #68
- kind: defect-refusing
- status: active

### GH-68.2
- text: A closed quote restores the separator, unbalanced quoting falls back to the
  old splitting, and a substitution inside double quotes still splits out.
- from: #68
- kind: defect-refusing
- status: active

### GH-68.3
- text: Every wrapper detection reads the raw command text, never the split
  fragments.
- from: #68
- kind: defect-refusing
- status: active
- direction: refuse-only: a rule reading fragments would permit a wrapped command,
  so only refusals can show where it reads

### GH-69.1
- text: `pytest-via-uv-group.sh` and `alembic-via-uv-group.sh` judge a tool at a
  command position: a mention in an argument or in prose is permitted, and the
  tool run bare, behind a runner without the group, or behind a prefix word is
  refused.
- from: #69, and its reviews
- kind: defect-refusing
- status: active

### GH-69.2
- text: `append-only-docs.sh` guards each append-only directory with or without its
  trailing slash, in a doubled-slash or dot-segment spelling, and against
  `truncate` and `tee`.
- from: #69, and its review
- kind: defect-permitting
- status: active

### GH-69.3
- text: `append-only-docs-edit.sh` normalises a path before comparing it, so a
  leading `./`, a `..` or a doubled slash does not permit an edit of an existing
  entry.
- from: #69
- kind: defect-permitting
- status: active

### GH-70.1
- text: CONTEXT.md's *worktree branch* entry says the branch exists for exactly one
  pull request and that its worktree is not reused.
- from: #70
- kind: doc-claim
- status: active
- direction: static: a claim about what CONTEXT.md says

### GH-70.2
- text: The `branch-hygiene` skill holds the sweep both hooks cite: unlock, remove
  the worktree, delete the branch with `-d` and never `-D`, leave the unclassified
  alone, and state its cadence.
- from: #70
- kind: doc-claim
- status: active
- direction: static: a claim about what the skill says

### GH-70.3
- text: *Reserved act* names removing a worktree or deleting a worktree branch, and
  the skill cites the enumeration rather than counting it.
- from: #70
- kind: doc-claim
- status: active
- direction: static: a claim about what CONTEXT.md and the skill say

### GH-71
- text: The merge settings are read by the report rather than recorded by hand in
  the guard's header, which was false in both directions in turn.
- from: #71
- kind: doc-claim
- status: active
- direction: static: FR-41 to FR-44 carry the mechanism

### GH-72
- text: `gh` is matched as a word in the wrapper rule, not as a suffix: a wrapped
  command whose prose holds a word ending in `gh` is permitted, and `./gh` and
  `/usr/bin/gh` are still refused.
- from: #72
- kind: defect-refusing
- status: active

### GH-73
- text: CLAUDE.md's "deliberately left open" list states the wrapper trade as the
  hooks act on it: wrapped reads are refused, the refusal reaches across the line
  in either order, the push half and the pull-request half differ, and its head
  count matches its items.
- from: #73
- kind: doc-claim
- status: active

### GH-79.1
- text: A wrapper behind a prefix word `cs_split` already strips (`sudo`, `timeout`,
  `xargs`, `env`, `nohup`, with separated option values up to the bound) is
  refused by every hook with a wrapper rule.
- from: #79, and its review
- kind: defect-permitting
- status: active

### GH-79.2
- text: The wrapper anchor was widened and not dropped: prose naming a wrapper word
  and a push on one line stays permitted, and the quote-blind soft spot it keeps
  is pinned in both directions.
- from: #79
- kind: defect-permitting
- status: active

### GH-79.3
- text: A command that runs another command and is not a prefix word (`python3 -c`,
  `perl -e`, `find -exec sh -c`) is out of reach, named and not closed.
- from: #79
- kind: defect-permitting
- status: active
- direction: permit-only: named and not closed; a refusal here would be a claim
  the fix does not make

### GH-79.4
- text: The prefix words are written once, read by `cs_split` and by the anchor
  through one variable, and an emptied list withdraws `cs_split` so that every
  consumer refuses.
- from: #79, and PR #89
- kind: defect-permitting
- status: active

### GH-84.1
- text: Every file that sources `lib/command-scan.sh` refuses when the library is
  absent, when any one `cs_*` function it calls is missing, or when the word list
  is empty, and the refusal names the hook and says it is refusing rather than
  permitting.
- from: #84
- kind: defect-permitting
- status: active

### GH-84.2
- text: Each consumer's load guard requires exactly the `cs_*` functions its code
  calls, tests the library before sourcing it, and the list of consumers is the
  list of files that source it.
- from: #84
- kind: defect-permitting
- status: active
- direction: static: derived from the files' text

### GH-84.3
- text: THE LOAD CONTRACT is written in the library, where a rename is made, and each
  consumer points at it by name.
- from: #84
- kind: doc-claim
- status: active
- direction: static: a claim about what the files say

### GH-94.1
- text: The push hook recognises the main checkout at its root, below it and through
  a symlink, and refuses a push of its branch as the main checkout; the linked
  worktree at the same depths is permitted its own branch and refused main and a
  dev branch.
- from: #94
- kind: defect-permitting
- status: active

### GH-94.2
- text: The stale guard does not apply worktree-lifecycle rules to the main checkout
  at any depth, and still applies them to a stale worktree at every depth.
- from: #94
- kind: defect-refusing
- status: active

### GH-94.3
- text: No expected verdict depends on where the suite is run: every push-hook and
  stale-guard check runs in a named directory of a fixture the suite builds.
- from: #94
- kind: defect-permitting
- status: active
- seam: none
- verify: review

### GH-94.4
- text: An unresolvable `--git-common-dir`, or a directory outside any repository,
  is refused by the push hook as unresolvable rather than as the main checkout,
  and the stale guard abstains; the two copies of `canonical_dir` are identical and
  do not follow `CDPATH`.
- from: #94, the review of PR #111
- kind: defect-permitting
- status: active

### GH-95.1
- text: Every hook refuses when `jq` is not on PATH, naming it, when stdin is not a
  single JSON object, and when the field it reads is missing or not a string; an
  empty string is permitted.
- from: #95
- kind: defect-permitting
- status: active

### GH-95.2
- text: The input read is one shared reader in the library and no hook calls `jq`
  itself; the trade that an environment without `jq` refuses the commands the
  convention hooks permit is recorded and pinned.
- from: #95
- kind: defect-permitting
- status: active

### GH-96.1
- text: A command whose longest line, once joined, exceeds 16 KB is refused by every
  Bash hook with the cap's message; a line at the cap and 200 KB across 80-column
  lines are judged on their content.
- from: #96
- kind: defect-permitting
- status: active

### GH-96.2
- text: Each Bash hook finishes a command whose longest line sits at the cap in
  under 1 s, fastest of three, and the library's passes are linear.
- from: #96
- kind: defect-permitting
- status: active
- direction: static: a bound on time, not a verdict

### GH-96.3
- text: `cs_within_cap` fails closed when a function it calls is missing or the cap
  is empty; the cap is the literal 16384; the copied awk helpers are identical.
- from: #96, and the review of PR #123
- kind: defect-permitting
- status: active
- direction: static: seam 2 and the library's text

### GH-97.1
- text: Every `gh release` subcommand but `list`, `view`, `download`, `verify` and
  `verify-asset` is refused, whatever flag stands before it and wherever it sits on
  the line, and a `gh api` write to a release is refused while a read is permitted.
- from: #97
- kind: defect-permitting
- status: active

### GH-97.2
- text: The release refusal says that any write to a release is Bertan's and that
  reading one is permitted, and CLAUDE.md and CONTEXT.md say "any write to a
  release".
- from: #97
- kind: doc-claim
- status: active
- direction: refuse-only: a message is written only on a refusal, and the documents
  are held to the same words

### GH-98
- text: Every helper that runs a hook reads exit 0 as ALLOW, 2 as BLOCK and anything
  else as FAIL, with the status and stderr on the failure line, and a self-test
  drives each against hooks that exit 0, 2, 1 and 127.
- from: #98
- kind: defect-permitting
- status: active
- direction: static: a property of the suite's helpers

### GH-99.1
- text: CLAUDE.md gives the two routes to a worktree branch starting at
  `origin/dev-NN` and says nothing enforces them; CONTEXT.md's *active dev branch*
  says the tip is the remote-tracking ref and the local branch a working copy; and
  *reserved act* names moving a local `main` or `dev-NN`.
- from: #99
- kind: doc-claim
- status: active
- direction: static: a claim about what the documents say

### GH-99.2
- text: `worktree.baseRef` is `fresh`, so a skipped step starts from `origin/main`
  and is refused, rather than from HEAD and permitted.
- from: #99
- kind: defect-permitting
- status: active
- direction: static: configuration the harness reads

### GH-99.3
- text: The report prints one `main ancestry` line: NOT an ancestor, an ancestor, or
  NOT READ, with a suffix when no fetch refreshed the refs, and no line when there
  is no dev ref.
- from: #99
- kind: defect-permitting
- status: active
- direction: static: the report's output

### GH-100
- text: The report classifies branches by pull request, as the sweep defines its
  classes, and falls back to ref state and says so when pull requests cannot be
  read; the skill's definitions name the wording the report prints.
- from: #100
- kind: doc-claim
- status: active
- direction: static: the report's output and the skill's text

### GH-101
- text: `lib/command-scan.sh` and every file that sources it say a guard "requires"
  a function, and use "probe" nowhere but in the one line that names the rename.
- from: #101
- kind: doc-claim
- status: active
- direction: static: a claim about the words the files use

### GH-102
- text: The suite's header names every file it checks, and points at no count that
  is not there.
- from: #102
- kind: doc-claim
- status: active
- direction: static: a claim about what the suite's header says

### GH-104.1
- text: A check with no tags fails the suite.
- from: #104
- kind: defect-permitting
- status: active
- direction: static: a property of the tags

### GH-104.2
- text: A tag naming an ID that is not in `requirements.md` fails the suite.
- from: #104
- kind: defect-permitting
- status: active
- direction: static: a property of the tags

### GH-104.3
- text: A `#<n>` cited in `check-hooks.sh` with no entry in `requirements.md` and no
  listing as a citation that is not a requirement fails the suite.
- from: #104
- kind: defect-permitting
- status: active
- direction: static: a property of the suite's text

### GH-104.4
- text: `check-hooks.sh --matrix` prints, per ID, its status, its tagged checks with
  their results, and whether coverage is met.
- from: #104
- kind: defect-permitting
- status: active
- direction: static: the matrix's output

### GH-104.5
- text: The rule that a pull request fixing a hook defect appends its `GH-<n>` entry
  and tags the check that fails without the fix is written in this file's header
  and in CLAUDE.md's guard-code paragraph.
- from: #104
- kind: doc-claim
- status: active
- seam: none
- verify: review

### GH-106
- text: Every spelling variant of a seeded command reaches that seed's verdict, or a
  verdict the suite declares for that pair with its reason. The seeds are a
  literal table covering every requirement with a command spelling in both
  directions; the variants come from a fixed list of transformations; and every
  departure is declared, either by design or as a gap naming the issue that owns
  it.
- from: #106
- kind: defect-permitting
- status: active
- direction: static: a property of the seed table, the transformation list and the
  departure table. The variants themselves establish the requirements their seeds
  are tagged with, one refusing or permitting check each; what is left for this
  entry is that the three tables say what they claim to, which is read off them
- note: the departures are not a second opinion about a hook. A `design` row is a
  verdict the hook's own comment argues for; a `gap` row is a verdict that is
  wrong today, written at the right one and owned by an issue. #103 Q18 forbids
  the third thing, which is calling a defect a design exception

### GH-117
- text: A command word spelled as a path, quoted or backslash-escaped is the command
  it spells: `/usr/bin/gh pr merge 5`, `./gh …`, `"git" push origin main`, `'git'
  …` and `\git …` reach the verdict their bare-name spelling reaches, in every
  hook.
- from: #117, found reviewing PR #115
- kind: defect-permitting
- status: gap → #117
- note: #106's families pin the five spellings as permitted against every refused
  seed, one row per spelling rather than one per seed, so the claim held is the
  class the issue measured. Those rows go red when #117 lands, which is the
  intended outcome.

### GH-118
- text: A `gh` command carrying any option other than `-R`, `--repo` or
  `--hostname` before a word of a guarded subcommand path is refused as
  unreadable, whatever verb it appears to name. A shorthand that is unknown or
  takes a value consumes the next word, so the verb the hook reads is not the
  verb `gh` runs: `gh pr -t view merge 5` is a merge and `gh release -t list
  create v1` is a create.
- from: #118, found reviewing PR #115; the refuse-the-shape decision is that
  issue's agent brief, and the spelling is corrected by the measurement in #106's
  comment on it
- kind: defect-permitting
- status: gap → #118
- note: the spelling matters and the issue's original example is not one `gh`
  runs. Cobra treats an unknown LONGHAND as a boolean, so `gh pr --squash view 5`
  returns `unknown flag: --squash` and eats nothing; it is a shorthand that
  consumes the next word. Measured on gh 2.45.0.
  The requirement is a refusal of the shape and not a reading of the verb, so it
  is not verdict-preserving in either direction: #106's families pin every
  refused `gh pr` and `gh release` seed as permitted, and also six PERMITTED
  seeds whose right verdict is BLOCK although their seed's is ALLOW --
  `gh pr -t view view 5` is a read the rule refuses. That second set is why the
  departure table carries a right verdict of its own. `gh issue` is not a guarded
  group, so `gh issue -t list list` stays ALLOW; `gh api` takes no group, so the
  shape does not arise there.

### GH-124
- text: `feed` and `feed_says` read a hook's exit status as every other helper does,
  and the #98 self-test drives both.
- from: #124
- kind: defect-permitting
- status: active
- direction: static: a property of the suite's helpers

### GH-127
- text: A command inside the 16 KB line cap whose fragments are numerous enough to
  outlast the 5 s timeout is refused within the timeout.
- from: #127
- kind: defect-permitting
- status: gap → #127

### GH-130
- text: A `gh api` write to an issue is judged on that command's own arguments, with
  quoted spans dropped: an issue body naming `/releases`, `repos/o/r/pulls` or
  `state=closed` is prose, and a read of `/releases` beside an unrelated issue
  write on the same line is a read.
- from: #130, found while covering US-14 for #105
- kind: defect-refusing
- status: gap → #130
- note: the four refusals are in `no-pr-decisions.sh`'s `$SCAN`-wide rules and the
  `API_NO_BASE` arm. The `gh issue` spelling of the same text is permitted, so the
  boundary is spelling-dependent where #36 says it is not. Not CLAUDE.md's
  left-open item 2: that item's subject is a line carrying a wrapper, and none of
  these does.

### GH-131
- text: `gh issue develop` creates a branch on the remote, which is a ref-creating
  write no hook sees; what an agent may do with it is decided rather than left to
  whichever rule happens not to match.
- from: #131, found while covering US-14 for #105
- kind: defect-permitting
- status: gap → #131
- note: US-14 says every issue subcommand stays available and this is one by name,
  so #105 pins the read spelling `gh issue develop --list` and leaves the two
  creating spellings unpinned rather than pinning a verdict that may be wrong
  (Q18). US-14 is covered by the other twelve rows.

### GH-133
- text: A refused retarget names the correction for a retarget. `gh pr edit <n>
  --base dev-NN` is permitted, so the one-step correction is one word of the
  command already written, not the create the four base refusals share.
- from: #133, found by Bertan's review of #132
- kind: defect-refusing
- status: gap → #133
- note: one `BASE` constant for four refusals is what FR-23 asks for, and for the
  three creating arms it is US-7's one-step correction too. For the retarget arm
  it is not, and "Edit anything else you like" reads as saying the base may not
  be edited when editing it to `dev-NN` is what is allowed. So the same message
  is evidence for FR-23 and against US-7: #105's two retarget rows are tagged
  FR-23 alone, and US-7 stays covered by the other twenty-one refusing checks.
  Message content is #109's.

### GH-134
- text: A shell wrapper is refused wherever it stands in a command position,
  control words included: `if true; then bash -c "…"; fi`, the `for`, `while`,
  `until`, `case` and `else` bodies, a function body and `{ …; }` are each a
  command position, as they already are for the unwrapped command.
- from: #134, found by #106's invariance families
- kind: defect-permitting
- status: gap → #134
- note: `CS_WRAPPER_RE` is matched against raw text and so carries its own
  command-position class -- start of line and `;` `&` `|` `(` and a backtick --
  where every other rule reads `cs_split`, which strips control words. The two
  answers disagree, which is the defect class `lib/command-scan.sh` exists to
  end. #106 pins the three control words it generates against its three wrapped
  seeds.

### GH-135
- text: A quoted group or subcommand word is the word it spells: `git "push" --all
  origin`, `git "commit" -m x` on main, `gh "pr" merge 5`, `gh pr "merge" 5`,
  `gh "api" …` and `gh "release" create v1` reach the verdicts their unquoted
  spellings reach.
- from: #135, found by #106's invariance families
- kind: defect-permitting
- status: gap → #135
- note: one word past #117, and a different fix site: the command word is found by
  an anchor, the group and verb by `cs_git_args`, `cs_gh_args` and the verb tests.
  The contrast that makes it a defect rather than a policy is that a quoted VALUE
  is read correctly -- `--base "dev-05"` is permitted and `--base "main"` refused
  -- so `base_args` knows what a quote is and the group and verb tests do not.
  Both directions are this entry. The permitting half is above; the refusing half
  is `gh release "view" v1`, refused because the read-verb allowlist is
  `cs_gh_args "release <verb>"` per verb and cannot read a quoted one. #106 first
  declared that one by design, citing the allowlist's fail-closed comment, and
  Bertan's review of PR #140 corrected it: that comment argues for refusing a
  subcommand `gh` adds later, and a quoted `view` is not one. It is a gap here,
  in the function this entry already names as the fix site.
  What is NOT this entry is the `base_args` family -- `gh pr create "--web"` and
  `gh pr create "--base" dev-05` -- which #106 declares by design, citing the
  comment that argues quoted text may trigger a refusal and may not grant an
  exemption. Those four rows hold only if #139 is fixed by refusing on the
  retarget and `--web` arms rather than by teaching `base_args` to read a quoted
  flag everywhere; #139 records that, so whoever takes it decides rather than
  discovers it.

### GH-136
- text: The dependency group is named whichever way `uv` and bash accept it: `uv run
  --group=test …`, `--group "test"` and `"--group" test` are the sanctioned
  invocation that `--group test` is, in both uv-group hooks.
- from: #136, found by #106's invariance families
- kind: defect-refusing
- status: gap → #136
- note: the hooks' own header argues a different quoting trade knowingly -- that a
  command name inside a quoted argument is treated as an invocation, so prose is
  refused -- and this is not that. `--group=test` is the shape the base rule
  already handles as `--base=main`, one file away.

### GH-139
- text: A quoted base flag is still a base flag where its absence would be permitted:
  `gh pr edit <n> "--base" main`, `"--base=main"` and `"-B" main`, and
  `gh pr create --web "--base" main`, are refused as their unquoted spellings are.
- from: #139, found by #106's invariance families once they quoted a fifth
  argument position
- kind: defect-permitting
- status: gap → #139
- note: `base_args` drops a quoted span whole, and its comment argues that
  deleting a span cannot invent a flag. True, and not the whole of it: on the
  retarget arm and under `--web`, naming no base is permitted, so deleting the
  span removes a refusal rather than adding one. On the three creating arms the
  same drop is safe, because a create naming no base is refused for naming none
  -- which is why this stood. The refusing consequences of the same drop are not
  this entry; #106 declares those by design, citing the comment that argues them.
  The second time the retarget arm has differed from the creating arms in a way
  their shared reasoning missed, after #133.

### GH-107.1
- text: `check-hooks.sh` judges the hooks in `$CHECK_HOOKS_DIR` when that names a
  directory, and the ones beside itself when it does not. What moves with it is
  what is judged — the hooks run as processes, the library they source, the text
  of both, and `requirements.md`. What does not move is what they are judged
  against: `settings.json`, `CLAUDE.md`, `CONTEXT.md`, the two skills, the working
  directory a hook is run in, and the suite itself. An override naming no
  directory, or one missing a file that sits beside the suite, stops the run and
  says which. A relative override is resolved against the directory the caller
  stood in, not against `.claude/hooks/`. Every check that reads a hook's text
  reads it out of `$CHECK_HOOKS_DIR` too: a file argument spelled as a bare name
  resolves against the suite's own working directory, so such a check judges this
  repository whatever the override says, and the suite holds every one of them to
  a variable.
- from: #107
- kind: doc-claim
- status: active
- direction: static: the two checks that can be made here read the guard's exit
  status and its message, which is no hook's verdict. The permitting direction is
  a whole run of this suite against a copy, which this suite cannot ask of
  itself; it is mutate-hooks.sh's baseline run, and every caught mutation depends
  on it
- note: the guard is checked by running this suite again with an override it must
  refuse, three times: a directory that is not there, one missing a file that sits
  beside the suite, and a relative name that exists beside the suite but not
  beside the caller. The inner run is marked so that a guard which failed to
  refuse cannot recurse, and each check asserts the refusal's message rather than
  only a non-zero exit — an inner run that went the whole way would exit 1 for its
  own uncovered requirement and say nothing about a directory. The rule about
  bare file arguments is checked by derivation over this suite's own text rather
  than by a list: sixty-nine checks were spelled that way when this requirement
  first landed, among them every pin that says a hook does not source the library
  unguarded, and a copy with the guard deleted printed ok for all of them. Found
  by Bertan's review of PR #142; `library-loaded-unguarded` in the harness's
  registry is the mutation that now asks it.

### GH-107.2
- text: `mutate-hooks.sh` re-runs the mutation claims this suite makes. Each
  registered mutation names a file in the hooks directory, a `sed` expression, the
  requirement IDs whose checks must go red, and what the harness must report; a
  mutation is caught only when every ID it names has at least one failing check.
  An edit that leaves its target byte-identical is a failure, not a pass. The
  harness never edits this repository's hooks, refuses to run if its working copy
  is them, requires an unmutated copy to be green before it believes any
  mutation, and checks that `.claude/hooks/` is byte-identical afterwards. Two
  rows of the registry are its self-tests: one whose edit matches nothing, and one
  registered against a requirement its edit cannot reach.
- from: #107
- kind: doc-claim
- status: active
- direction: static: what this suite can ask of the harness is what its text says
  and whether its registry names files and requirements that are active. Whether
  the harness is right is a run of the harness, which takes about forty-five
  minutes and is nobody's check
- note: the registry's size is what `bash .claude/hooks/mutate-hooks.sh --list`
  prints, and this file does not restate it — the first version did, in four
  documents, and was wrong in all four, which Bertan's review of PR #142 measured.
  What is worth recording is the shape: one row per rule rather than one per
  requirement, so a requirement with a row is one some mutation reaches and not
  one whose every check has been exercised. One mutation per FR is the backlog
  item docs/todo.md carries from #103 Q8, and #108 and #109 register theirs when
  they land. Two kinds of rule cannot be registered at all, which is GH-107.1's
  split seen from the other side: one that lives in the tooling beside the hooks —
  `check-hooks.sh` and `mutate-hooks.sh` themselves, so #106's six self-guards and
  #104's coverage machinery — because both run from this repository whatever the
  override says; and a claim about a file outside `.claude/hooks/`, because only
  the hooks directory is copied. A row may name only an active requirement: a
  retired or superseded one has no covering check, so a row naming it would report
  `survived` for ever and read as a defect in the hooks rather than in the row.

### GH-128
- text: A heredoc body begins where bash begins it, so a command written after the
  terminator is read as a command. A line ending in an ODD run of trailing
  backslashes continues and the body waits for it; an EVEN run does not continue,
  and the body begins on the next line. Every spelling of the opener reaches that
  verdict — `<<-E` with a tab-indented terminator, `<<'E'`, `<<"E"`, `<< E`, an
  opener continued more than once, and a redirect in front of it — and a heredoc
  body is still dropped whether or not its lines end in a backslash.
  `cs_normalise` emits no line longer than the longest line `cs_within_cap`
  measured of the same command.
- from: #128, found by Bertan's review of PR #123
- kind: defect-permitting
- status: active
- note: the fifth answer to where a heredoc body begins and the fourth wrong one,
  and the first about the opener's own line rather than about the terminator. Two
  rules carry it. `cs_normalise`'s first pass ends the logical line by bash's
  parity rule rather than by the looser one `cs_join` uses, and it takes the
  trailing run off the line a body starts after — which under the parity rule is
  always an even run, the one case where `cs_join` joins and bash does not, and
  the one line onto which `cs_join` could otherwise glue the first line past the
  terminator. Each rule has a row in `mutate-hooks.sh`, and a third breaks both,
  because on an odd run either one alone holds the case the issue was filed for.
  The first version of this fix used `cs_join`'s rule in the drop and argued that
  looser than bash was the safe side, because a line held open too long "only
  exposes more lines as commands" — and this entry said so for one revision. It
  is false: holding the line open moves the terminator search forward, so a
  delimiter line bash took as the terminator of an empty body is scanned past and
  the body runs to the next delimiter, dropping what lies between.
  `cat <<E \\` / `E` / `echo after` / a push / `E` was permitted at exit 0 where
  `dev-05` refused it, found by review of PR #151. What IS safe is ending a body
  early, which is why bash's joining inside an unquoted body and an opener split
  by its own continuation (`cat <<\` / `E`) are still not modelled. The second
  consequence was a claim about the cap: forty 15,011-byte groups within the cap
  made `cs_normalise` emit one 600,400-byte line, and THE LINE CAP in
  `lib/command-scan.sh` said so until this fix. #127 is the half of that claim
  which is still open.

## Provenance: the acceptance criteria of #37–#41

Every criterion of the five stage tickets, quoted verbatim, with the IDs that
carry it (Q12, Q23). A criterion that no requirement carries is marked
`dropped` with the reason. The suite holds the number of criteria per issue to a
literal of its own, written from the issues rather than from this section, so a
criterion deleted from here fails as surely as one left unmapped.

### #37.1
- criterion: `worktree.baseRef` is set in the checked-in settings so a worktree is
  created from the active dev branch; verified by creating one and
  confirming its fork point is the active dev branch and not `main`
- maps: FR-1, US-5

### #37.2
- criterion: Both hook files carry the stopping rule: a newly found evasion earns a fix
  only if it is a shape an agent would plausibly write, not one it would
  have to construct
- maps: FR-2, US-20

### #37.3
- criterion: CLAUDE.md no longer claims the boundary "can rest on nothing else", and
  states the shared-credentials reason as a choice rather than a constraint
- maps: FR-5

### #37.4
- criterion: The "deliberately left open" section names that nothing guards `.claude/`,
  together with the standard that excludes it
- maps: FR-6, US-19

### #37.5
- criterion: CLAUDE.md's boundary section is reduced to its operative paragraph
- maps: FR-7

### #37.6
- criterion: `docs/adr/0001` exists, states the principle and the rejected alternative,
  and contains no inventory of permitted commands
- maps: FR-8, US-17, US-18

### #37.7
- criterion: The check suite passes, with the same count as before this ticket
- dropped: a property of that one change, measured when it landed (207 checks at
  b625d64 and at 2fad130, recorded on #37); a standing count would be the claim
  #102 removed from the suite's header

### #37.8
- criterion: Everything lands on the branch of PR #35
- dropped: where one change was delivered, done when PR #35 merged as 47bee38

### #38.1
- criterion: The suite's filename, its assertion function and its header speak of
  checks rather than probes
- maps: FR-9, US-23

### #38.2
- criterion: CLAUDE.md's invocation line matches the new name
- maps: FR-9

### #38.3
- criterion: The measurement scripts and every other use of *probe* for a measurement
  are untouched
- maps: FR-10, US-22

### #38.4
- criterion: `CONTEXT.md` exists at the repository root, defines *check* and *probe*
  against each other, and contains no other terms yet
- maps: FR-11

### #38.5
- criterion: The suite passes with a count identical to before — 207, measured at
  `b625d64`
- dropped: a property of that one change, recorded as FR-12 and retired with it

### #38.6
- criterion: No hook changes what it refuses or permits
- dropped: a property of that one change, recorded as FR-12 and retired with it

### #39.1
- criterion: `cs_gh_args` exists beside the git-argument helper, taking a subcommand
  and returning that command's own arguments
- maps: FR-22

### #39.2
- criterion: Its exit status distinguishes "was this subcommand" from "was not", so no
  caller has to infer that from the printed text
- maps: FR-22

### #39.3
- criterion: Checks at the tokeniser seam pin both the returned arguments and the exit
  status, with expectations written as literals and never derived by
  running the function
- maps: FR-22, FR-32

### #39.4
- criterion: Every pre-existing check still passes, unchanged
- dropped: a property of that one change, a behaviour-free prefactor, not a
  standing requirement

### #39.5
- criterion: No hook changes what it refuses or permits
- dropped: a property of that one change, a behaviour-free prefactor, not a
  standing requirement

### #39.6
- criterion: Mutation-checked: deliberately breaking the helper turns the new checks
  red
- maps: FR-36

### #40.1
- criterion: Creating a pull request into `main` is refused
- maps: FR-16, US-8

### #40.2
- criterion: Retargeting an existing pull request's base to `main` is refused
- maps: FR-17, US-10

### #40.3
- criterion: A REST write that creates a pull request into `main` is refused
- maps: FR-18, US-11

### #40.4
- criterion: The graphql mutation that creates a pull request into `main` is refused
- maps: FR-19, US-11

### #40.5
- criterion: Creating a pull request with no base named at all is refused, rather than
  defaulted to the repository's default branch
- maps: FR-14, US-9

### #40.6
- criterion: A base naming an active dev branch is permitted in every spelling
- maps: FR-15

### #40.7
- criterion: The browser hand-off form of opening a pull request stays permitted
- maps: FR-21, US-12

### #40.8
- criterion: Still permitted, with checks: commenting, editing without touching the
  base, viewing, listing, diffing, reviewing without a verdict, reading a
  pull request through the API, and every issue subcommand
- maps: US-13, US-14, FR-20

### #40.9
- criterion: Still refused, with checks: merging, a verdict review, closing, reopening,
  and creating or deleting a release
- maps: US-15, FR-48

### #40.10
- criterion: Each refusal names the permitted spelling, consistent with the existing
  messages
- maps: FR-23, US-7

### #40.11
- criterion: The rule lives in the existing pull-request hook, whose header is widened
  to describe it
- maps: FR-13

### #40.12
- criterion: Argument scoping goes through the tokeniser helper, not a new match over
  the whole line
- maps: FR-22, GH-47.1

### #40.13
- criterion: Mutation-checked: deliberately breaking the rule turns the new checks red
- maps: FR-36

### #41.1
- criterion: `branch-hygiene` describes rotation as Bertan's, and instructs an agent to
  run nothing the hooks refuse
- maps: FR-24, US-27, US-28

### #41.2
- criterion: The agent's remaining half is kept: confirm from the remote that the merge
  happened, and report what is stale
- maps: FR-25, US-29

### #41.3
- criterion: The skill's invariant is corrected — one active dev branch plus `main`,
  with worktree branches in flight against the former
- maps: FR-26

### #41.4
- criterion: `CONTEXT.md` defines *worktree branch*, *active dev branch* and *reserved
  act*
- maps: FR-27, US-24

### #41.5
- criterion: The *worktree branch* entry records that the check keys on the linked
  worktree and deliberately not on the branch's name, and why
- maps: FR-28, US-25

### #41.6
- criterion: *reserved act* covers advancing the active dev branch, merging any pull
  request, rotating the dev branch, and publishing a release
- maps: FR-29, US-26

### #41.7
- criterion: CLAUDE.md's rules section names the guard-code standard: its evidence is
  the check suite, and no fix lands without a check that fails without it
- maps: FR-30, US-21

### #41.8
- criterion: The check suite passes
- dropped: a condition of every change rather than a requirement of this one; no
  requirement here is "the suite passes", which is what running it answers

## Citations that are not requirements

Numbers `check-hooks.sh` cites that are not boundary issues, each with the reason
it has no entry above (Q16).

- #1: a pull request number in the stand-in data of the report or housekeeping fixtures
- #2: a pull request number in the stand-in data of the report or housekeeping fixtures
- #3: a pull request number in the stand-in data of the report or housekeeping fixtures
- #4: a pull request number in the stand-in data of the report or housekeeping fixtures
- #6: a pull request number in the stand-in data of the report or housekeeping fixtures
- #7: a pull request number in the stand-in data of the report or housekeeping fixtures
- #9: a pull request number in the stand-in data of the report or housekeeping fixtures
- #11: a pull request number in the stand-in data of the report or housekeeping fixtures
- #12: a pull request number in the stand-in data of the report or housekeeping fixtures
- #14: a pull request number in the stand-in data of the report or housekeeping fixtures
- #15: a pull request number in the stand-in data of the report or housekeeping fixtures
- #21: a pull request number in the stand-in data of the report or housekeeping fixtures
- #35: a pull request; the review findings on it are carried by FR-3 and FR-4
- #36: the specification; its content is the US- and FR- entries
- #38: a stage ticket of #36; its criteria are in the provenance section
- #40: a stage ticket of #36; its criteria are in the provenance section
- #48: a pull request, for #41
- #49: a pull request, for #43
- #64: a pull request, for #58
- #77: a pull request, for #71
- #89: a pull request, for #79
- #103: the audit that decided this file; its decisions are cited as Q-numbers
- #115: a pull request, for #97; Bertan's review of it found #117 and #118, which
  have entries above
- #140: a pull request, for #106; Bertan's review of it is cited where the four
  things it corrected stand
- #141: the issue that owns deciding which non-FR requirements the invariance
  families seed; it adds no requirement of its own until that is decided
- #107: has entries above, GH-107.1 and GH-107.2, and is listed here only because
  #106's section cited it before it landed — that section writes out three
  mutations of its own and says they are run by hand until the harness exists.
  The two rules that decide this list, an entry above or a reason here, are
  answered by the first for #107
- #105: the gap-fill issue that owned fifteen of the nineteen `gap` markers #104
  left and has taken all fifteen off; it adds checks, not requirements of its own,
  and the three defects found doing it are #130, #131 and #133, which have entries
  above
- #109: the issue that owns what a refusal says; cited where a message is pinned
  for its words, so that a reworded message is changed in one place and checked in
  another. The defect #133 records is its to fix
- #110: the live acceptance runbook, not yet written; `verify: runbook §<n>` names
  its sections
- #111: a pull request, for #94
- #116: a pull request, for #98
- #119: a pull request, for #101
- #120: a pull request, for #100
- #123: a pull request, for #96
- #126: a pull request with no issue behind it, the housekeeping skill; its checks carry
  the IDs of the procedures its generator prints, GH-70.2, GH-100 and US-29
- #132: a pull request, for #105; cited where its review changed a check, because a
  tag dropped for a reason is only auditable if the reason is reachable
- #142: a pull request, for #107; Bertan's review of it is cited at each thing it
  corrected, which is most of what GH-107.1 and GH-107.2 now say. It is not
  counted here, because a count of corrections is the kind of number this file has
  already had to fix once

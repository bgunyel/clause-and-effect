# Requirements of the agent boundary and its hooks

Every requirement the hooks under `.claude/hooks/` have accumulated, each with a
permanent ID, so that "is this requirement verified?" is answered by
`bash .claude/hooks/check-hooks.sh --matrix` rather than by reading the suite.
The decisions behind this file are #103's, taken in a grilling session on
2026-09-13, and their question numbers (Q2, Q6 …) are cited below. #104 built it.

`check-hooks.sh` reads this file and the `requirements/` directory beside it,
which holds the `GH-` entries one file each (#200). Every check there carries
the IDs it establishes, and the suite fails when an active requirement here or
there has no check that covers it. Both are next to the suite and outside the
`docs/` taxonomy on purpose (Q6): they are an input to the checks, not
documentation of them.

`check-hooks.sh` is the suite's driver: the checks themselves are in the files
under `checks/` that it sources (#204), and where this file says
`check-hooks.sh` holds, cites or checks something, it means the suite.

## The rules this file keeps

**IDs are never renumbered and never reused.** A requirement that stops being
true is marked, never deleted: its `status` says what became of it. The suite
holds that for the `GH-` entries written before #205, and not yet for a
generated one (#223). A new `US-`
or `FR-` requirement is appended at the end of its family; a new `GH-` one is a
new file, `requirements/<ID>.md`, generated from its declaration (below). So an
ID cited in an issue, a commit or a check means the same thing for as long as
this repository exists.

**A pull request that fixes a hook defect adds its `GH-<n>` entry**, declared
in its issue file and written to a file of its own under `requirements/` by
`generate-requirements.sh`, and tags the check that fails without the fix
(Q16). A pull request carries no ID of its own; its issue does. This is what
keeps the matrix whole after #103's work ends, and the suite holds half of it:
every `#<n>` cited in `check-hooks.sh` must have an entry, here or under
`requirements/`, or be listed under *Citations that are not requirements* with a
reason.

**A behavioural `GH-` entry says what #106's invariance families do with it**,
in a `variants` field, and the families' scope is that rule rather than a list
someone once wrote (#141). What is seeded is what any future transformation can
ever be asked of, so leaving the choice unstated made it "whatever the
specification happened to state as an FR in 2026-09", which has no particular
relation to where the defects have been. *What the invariance families seed*
below defines the scope and the three values, and the foot of #106's section in
`checks/unsplit.sh` holds the seed table and the transformation list to them.

## The families

- `US-n`: #36's user stories, transcribed verbatim. A story a later amendment
  replaced is marked `superseded-by`, never rewritten (Q10).
- `FR-n`: #36's Implementation Decisions (stages 0–3), its Testing Decisions,
  and its Amendments, one per behaviour that can be tested on its own.
- `GH-<n>` and `GH-<n>.<m>`: the issues after #36 that change what a hook decides
  or what the suite pins (Q7, Q13). A sub-ID is used when one issue names more
  than one behaviour that can fail independently (Q14). The grammar is
  `GH-[1-9][0-9]*` with an optional `.[1-9][0-9]*`, and a bare ID may stand
  beside its own sub-IDs. A loop mints IDs only under its own issue's number, so
  two loops should never mint the same one; if two do, it is an add/add conflict
  on one path, which git stops on.

**Where a `GH-` entry lives (#200).** Not in this file. Each is
`requirements/<ID>.md` beside it, holding that entry's `### <ID>` block and
nothing else, because the `GH-` family is a ledger appended to by every review
loop, and while it was a section here every pair of concurrent branches
conflicted on it. A ledger entry has a unique name, so adding one is adding a
file, which git merges without a decision; `US-` and `FR-` stay here, where a
conflict means two authors redefined the boundary and a person should look. The
files are read in version order on the ID -- what `sort -V` gives, a bare
`GH-<n>` before its `GH-<n>.1` and `GH-108.10` after `GH-108.9` -- and that is
the order `--matrix` presents them in. `split-requirements.sh` moves any `GH-`
entry found in this file into its own, and refuses to overwrite a file that
holds something else; an entry it moves that is not in the legacy set (below)
is red all the same, because an entry written after #205 is declared rather
than written.

**A `GH-` entry written after #205 is declared, and its file is generated.**
The issue file whose checks establish it, `checks/GH-<n>.sh`, declares it with
a heredoc at the start of a line, `requirement <ID> <<'REQ'`, whose body is the
entry's fields in the grammar below; `bash .claude/hooks/generate-requirements.sh`
writes `requirements/<ID>.md` from it -- the heading, the body byte for byte,
and a last field, `generated`, naming the issue file -- and a file carrying
that field is never edited by hand. The same issue file pins the entry's shape
with `shape_pin`, and its `variants` keyword with `variants_pin` when it has
one, in the tokens `REQUIREMENT_SHAPE` and `INV_SCOPE` use; those two literals
hold the entries written before #205 and no others. Those entries -- the
legacy set, which the driver holds as `REQUIREMENTS_LEGACY` and which never
grows -- stay hand-written: none is rewritten, migrated or declared, and an
entry outside it that is not its declaration is red. The residue this leaves
with no check site is not a list of its own: a `gap` or `seam: none` entry is
declared in the issue file of the work that wrote it, like any other, with no
check tagged. Why this form and what was rejected is
`docs/adr/0005-generated-requirement-entries.md`.

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
- `variants`: what #106's invariance families do with this requirement. Required
  of every `GH-` entry in their scope and written on no other entry; one of
  `seed`, `transformation: <name> …` and `none: <reason>`. See *What the
  invariance families seed* (#141).
- `note`: anything a reader of the entry needs that is not one of the above.
- `generated`: the issue file an entry is declared in, written last by
  `generate-requirements.sh` and on no hand-written entry (#205).

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
- a check with no tags, or a tag naming an ID that neither this file nor
  `requirements/` holds;
- an entry that is malformed: an ID out of family, one used twice, one under a
  `##` heading that holds no entries, a missing field, an unknown status or kind,
  a `superseded-by` naming no entry, a `direction` with no reason, `seam: none`
  with a `verify` that does not resolve, and `seam: none` with checks tagged with
  it after all;
- a `GH-` entry out of place: one left in this file, a file under
  `requirements/` whose name is not the ID it holds, one holding a second entry
  or none, one with text before its heading, a `##` heading in it, or a line
  after its heading that is no field of the entry, an ID there outside the
  `GH-` grammar, and a name there that is not a regular file;
- a check recording a direction other than refuse, permit and static;
- a shape other than the one the suite holds as a literal -- `REQUIREMENT_SHAPE`
  and the shape pins of the issue files (#205): every entry by ID,
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

## What the invariance families seed

#106's invariance families take a seed -- a command with a literal verdict --
rewrite its text, and assert every variant reaches that verdict or a departure
declared with its reason. Their leverage is that a transformation added to the
list is asked of every seed at once, so what is seeded is what the generator can
ever find. #106 asked for "at least one per FR with a command spelling", and the
derivation that held the table to it read `FR-` tags and nothing else. This
section is the rule for the other two families (#141).

**In scope.** A `GH-` entry is in the families' scope when its `kind` is
`defect-permitting` or `defect-refusing`, its `status` is `active`, and it
declares neither `direction: static` nor `seam: none`. That is the derivable
form of "a requirement about a verdict on a command", which is the only thing a
variant can reach: a `doc-claim` is about what a document says, a
`direction: static` entry about what a file or a function holds, and `seam: none`
about what no check reaches at all. A `gap → #<n>` entry is out for the reason
the coverage check does not ask about one either -- its behaviour does not hold
today, and a seed whose verdict is wrong is a departure row and not a seed. The
departure table names those, and `INV_DEPARTURES` is where they are.

None of the three candidates #141 raised is both derivable and right on its own.
`kind: defect-permitting` alone takes in every entry about the suite's own
helpers, its tags and its timings, which name no command; "an entry naming a
hook that judges commands" takes in the same; and "text contains a command" is
not derivable from prose. So the scope is mechanical and the answer within it is
declared per entry, which is the shape `direction` and `seam` already have.

**Every entry in scope carries `variants`**, one of:

- `seed`: the entry names a command with a verdict, and at least one seed in
  `INV_SEEDS` is tagged with its ID. Which verdicts are seeded is in the
  derivation's literal, and one direction is allowed -- the both-directions rule
  is coverage's, and coverage is met by the checks above the families as much as
  by a seed.
- `transformation: <name> …`: the entry names a rewriting of a command rather
  than a command, so asking it as a seed would be a category error. Each name is
  in `INV_TRANSFORMS`, which is what makes this value a claim rather than a
  label: an entry naming a transformation the list lacks is red until the
  transformation is added.
- `none: <reason>`: neither, and the reason says why. Three kinds qualify, and
  the reason says which: a requirement whose subject is not a command spelling
  at all -- a state of the tree, a file path, which operations a state covers,
  where a flag stands among the arguments; a command shape the transformations
  cannot generate, such as one written to probe the tokeniser's quote state; and
  a command whose judged content is not in its own text.

A `transformation` value names the transformations that reach the entry's
shapes. It is not a claim that they exhaust it, and where an entry names a shape
no transformation reaches, that shape is named as a gap rather than covered by
the value: GH-43.6's `-C` is `global-flag` and its `--git-dir` spelling is
`global-flag-gitdir`, and both had to be in the list for the value to be
honest.

**The third kind of `none`, named because #141's follow-up asked for the
decision rather than the discovery.** `gh api graphql -f query=@/tmp/rel.graphql`
and `gh api graphql --input /tmp/rel.json` put the payload in a file, so the
thing a rule has to judge is not in the command. A generator that rewrites a
command's text can neither produce those spellings nor say anything about one,
and the rule that would refuse them is a rule about a file argument rather than
about a spelling — so they are `variants: none` on whichever entry comes to own
them, with that as the reason. The contrast that makes this a departure and not
a limitation of the idea is the third spelling #143 measured beside those two:
`mutation{delete"Release"(…)}` is intra-word quoting, which a quoting
transformation does generate, and is GH-135's shape. GH-131 and GH-143.1 to
GH-143.3 are the entries this will land on; both are out of scope today by the
rule above — #131 is `gap → #131` and GH-143.1 to .3 are not written — and when
either goes active the rule makes the declaration compulsory rather than
optional, which is the point of stating a rule instead of a list.

**The trade, taken knowingly.** `none` is a declaration and not a derivation, so
an entry that ought to be seeded can be written `none` with a plausible reason,
and this rule would not catch it. What it changes is that the choice is made
once per entry, in writing, with a reason a reviewer reads in the diff -- where
before it was made by an `awk` filter nobody had to argue with.

What the literal in `check-hooks.sh` does close is narrower than the sentence
that first stood here, which claimed "a value changed" and was wider than the
guard. The literal holds each in-scope entry's ID beside its *keyword*, so a new
entry, an entry whose answer moves between `seed`, `transformation` and `none`,
and an answer moved to another entry each go red until the suite's copy moves
with it. What it does not hold is the prose after the keyword: a `none` reason
reworded, or a different transformation named, stays green. The transformation
names have a guard of their own -- each must be in `INV_TRANSFORMS` -- and a
reason is prose, which no literal can judge. That is #104's reason for holding
this file's shape as a literal, applied to the one field #104 does not read,
and held to the same standard of saying only what it asks.

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

The `GH-` entries, one file each under `requirements/`, named by ID (#200). See
*The families*. This heading stays so that an entry appended here the old way is
read and refused rather than read as part of some other section.

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
- #153: a pull request, for #137; Bertan's review of it found the separator half
  of GH-137.2, which that entry carries, and corrected three claims in this
  change — the flag pairing, the safety property `rest_bases`' comment asserted,
  and two static checks that counted lines where they meant occurrences
- #163: the in-word half of the quoting GH-137.1 and GH-137.2 read round a field,
  found by the follow-up review of #153; it adds its requirements in the pull
  request that fixes it, after #130, rather than pinning today's verdicts
- #198: `no-pr-decisions.sh` refuses an unreadable base and permits an unreadable
  endpoint, and says so nowhere. Raised as Class 2 of rev-agent-130's round-1
  review of #196 and filed rather than fixed there: the four transitions that
  review measured were the line-wide read finding an assignment's text, which is
  #130's own defect, and what is left over is a policy #130's scope does not
  reach. Cited in the accepted-verdict rows that pin today's answer
- #196: a pull request, for #130; rev-agent-130's review rounds are cited where
  each thing they found stands
- #138: no field rule reads a JSON request body supplied by `--input`; the last of
  the three the grilling of #130 split out, after #137 and #130 themselves. Cited
  in the `gh api` heredoc row #130 rewrote, to say what that row is NOT about:
  reading an ENDPOINT out of a request body is not a thing, `gh api` taking the
  endpoint as its one positional argument, and reading a FIELD out of one is
  #138's. It adds its requirements in the pull request that fixes it
- #141: has an entry above, GH-141, and is listed here only because this file
  cited it before it landed, as the issue that owned deciding which non-FR
  requirements the invariance families seed. It decided that, and the rule is
  *What the invariance families seed*
- #107: has entries above, GH-107.1 and GH-107.2, and is listed here only because
  #106's section cited it before it landed — that section writes out three
  mutations of its own and says they are run by hand until the harness exists.
  The two rules that decide this list, an entry above or a reason here, are
  answered by the first for #107
- #105: the gap-fill issue that owned fifteen of the nineteen `gap` markers #104
  left and has taken all fifteen off; it adds checks, not requirements of its own,
  and the three defects found doing it are #130, #131 and #133, which have entries
  above
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
- #145: the issue that owns how strongly a document claim can be pinned at all —
  `written` and `unarmed` decide whether a literal occurs, so an entry can satisfy
  every pin it carries and a later sentence can reverse the claim. Cited beside the
  `unarmed` that pairs GH-143.4, to mark which half that pairing reaches. It has no
  entry of its own on purpose: its four options differ in whether a requirement is
  produced at all — accepting the limit moves existing doc-claims to
  `verify: review` under Q17 and adds none — so an entry written now would have to
  say only that the question is open, which is the unfalsifiable text GH-131 was
  rewritten to stop saying
- #150: the pull request for #108; Bertan's review of it is cited where each of
  the five things it corrected stands, the largest being a fixture guard that made
  the suite abort on any machine without `gh` installed
- #172: the pull request for #134; its two reviews are cited where each thing
  they corrected stands. The first added GH-167 and GH-175 as gaps and the
  separator membership pins; the second found three guards that did not guard --
  a backslash pin spelled with two backslashes and so unable to fire, a
  malformed list that fails open, and a control-word list with no validity check
  at all -- which is GH-134.1 and the corrected pin under GH-134. It has no
  entry of its own, for the reason #142 has none: a count of what a review
  corrected is the kind of number this file has already had to fix once
- #173: the pull request for #139; Bertan's review of it found the two holes
  GH-139's note records -- `$'...'` escapes left undecoded, a quote open at the
  end of a line read as a word with no whitespace, a NUL decoded as a
  character, and `\c` and cut spans read past where bash reads them -- and is
  cited where each fix stands
- #161: the pull request for #155; Bertan's review of it is cited where each of the
  two things it corrected in this suite stands — a derivation of every PATH the
  report is driven under that was anchored at column 0 and so could not see an
  indented run, and a fixture test that asked the calling shell what the farm
  holds, which resolves a `gh` shell function ahead of PATH and would have aborted
  the suite on a host that exports one. Its third correction is a measurement in
  `mutate-hooks.sh`, whose exclusivity was that host's, and is recorded there
- #148: has an entry above, GH-148, and is listed here only because #109's
  section cited it before it landed. What that citation records is worth
  keeping, because it is the issue found independently and from the other side:
  the second review of PR #169 found the heading saying ABOUT AN HOUR for a
  registry the paragraph under it put at ninety minutes, with this suite pinning
  the hour. A rate does not move when a row is registered and a total does, so
  #169 made the heading a rate. #148 finished it — every count about the
  registry is derived by `--list`, the heading states no magnitude at all, and
  the rate is measured, dated, and checked against the suite's growth
- #154: the order of `$BASE`'s two imperatives on a retarget, which #109 left
  untouched. Cited where `says_first` says why an opening is a different question
  from a fragment: ordering is already a live concern at one of these constants,
  which is what made it worth asking at the other
- #181: `fn_calls` cannot see an indirect call, so a wrapper around a function
  that writes a refusal hides arms from the count. Cited beside that helper,
  which names what it can and cannot see
- #182: `arms` and `fn_writes` do not know where a heredoc body starts. Cited
  where the count names the shapes it cannot reach; one of the three is the
  permitting direction, which is why it is filed rather than only named
- #185: `dup_stderr` does not reach `/dev/stderr` named on an `exec`, nor a
  two-digit fd. Cited where that guard is, because a guard narrower than the
  prose beside it reads as coverage -- the shape the fifth review of PR #169
  found in `nested_defs` and the sixth found here
- #186: `every_hook` passes on an empty hook list, and the guard answering it
  sits at one of its producers rather than in the consumer. Cited in the helper.
  It is the first review of PR #169's finding at a second call site
- #187: `report_says` records the report by basename, so a modified fixture
  keeping that name would satisfy GH-109.4 for a hook nothing ran. Cited where
  the exception is taken. The invariant it rests on is written in a comment and
  held by nothing
- #179: the invariance families cannot seed a requirement whose subject is
  agreement across hooks, which is the reason GH-109.5 declares `variants:
  none`. Filed out of the second review of PR #169 so that the reason is a
  question someone can answer rather than a paragraph in an entry
- #180: GH-109.5's 41 spellings are hand-written with no tripwire on CLAUDE.md's
  boundary section. The derivation was measured and declined, and the decline
  was accepted; this owns the residual gap rather than closing it, which is the
  class #164 came from
- #169: the pull request for #109; its two reviews are cited at each thing they
  moved, and every one of them is this suite saying more than it had
  established rather than a defect in a hook — which is why the pull request
  adds no requirement of its own. The first found the `ran` record written at
  path resolution, so a hook that was never there counted as run; the
  refusal-arm count reading `echo` on one physical line; and the one derivation
  in #109's section without an empty guard. The second measured what the first
  had left: the widened count still missed a redirection written before the
  command, a heredoc, and a helper called more than once, and `$BASE` was a
  shared opening read only by its prefix, so deleting its rule sentence or its
  remedy tail survived green. `$REFUSE` was closed with it, on the same
  reasoning and without waiting for a round that measures it. It also found the
  `ABOUT AN HOUR` heading this file records under #148
- #193: the issue that owns making `--list` apply each row's edit, so the run
  count is exact rather than an upper bound and a rotted anchor surfaces without
  a whole-registry pass. Cited beside the three pass-two cases `--list` cannot
  see, so that the limit names what would lift it. It has no entry above on
  purpose: the requirement that would carry it is the change, and GH-148 states
  today's behaviour as the upper bound it is
- #183: the pull request for #148; Bertan's review of it is cited where each of
  the seven things it corrected stands. Two were the issue's own thesis failing
  on the number the branch had just made load-bearing: the harness's runtime was
  wrong by about a factor of two, and the pin classified as the safe kind of
  literal asserted only that a string was present and so could never go red as
  the registry grew. The rest are a count in `CLAUDE.md` that misdescribed which
  numbers live in two places, two readers of `requirements.md` that were not
  section-aware, a run count that included rows a pass refuses, and a suppressed
  stderr. It is not counted here, for the reason #142's entry gives
- #210: the pull request for #200; rev-agent-200's review of it is cited where
  what it found stands -- `split-requirements.sh` refusing what the reader would
  refuse in a file it writes, and the fixtures that tell the split set's `*`
  from a narrower glob, in the suite and in the harness
- #158: the pull request for #144, open across the split; it and #184 are the
  merges `split-requirements.sh` was measured on, and the reason it compares
  three ways on a merge (rev-agent-200's round 4 of #210). Its review of the
  cross-repository corner found no defect in a verdict and one in the account of
  them, and GH-144.6 is where the correction stands — the suite cites the number
  beside the three rows that review asked for, because a claim about which
  directory is read is worth saying who last got it wrong
- #184: the pull request for #118, open across the split; cited beside #158,
  for the same measurement. Bertan's three reviews of it are cited where
  each thing they corrected stands. The largest were two spellings of the
  refused command still permitted — an option made last by a backtick, and a
  quoted one — and then the same shape twice more, in the guard written for the
  first of them and in the guard written for that
- #216: the pull request for #204's first step; rev-agent-204's review of it is
  cited where what it found stands -- a helper missing from the library running
  as `command not found` with the run green, a helper redefined in a later
  section replacing it silently, and `checks/.+` taking `checks/../<hook>.sh`
  as the tooling
- #212: the issue that owns a tag reaching into the checks after it, or missing
  an arm of an `if`, within one file. Cited where `source_checks` clears `REQ` at
  every file boundary, which closes that class at the boundary and nowhere
  else; it has no entry above because the general fix is #212's to choose
- #220: the pull request for #204's second step; rev-agent-204's review of it is
  cited where what it found stands -- an end marker written before a file's
  last line and followed by a `return`, which the record read as a whole run
  until the marker carried the line it was written from
- #211: the issue that found every new `GH-` entry still appending a token to
  `REQUIREMENT_SHAPE` and `INV_SCOPE` after the split; #205 decided it, and the
  decision is GH-205.3, so it has no entry of its own
- #222: the pull request for #205; rev-agent-205's review of it is cited where
  what it found stands -- a generator that read nothing and reported a pass,
  and a stage path `awk -v` could mangle, which the generator now refuses and
  reads whole
- #223: the issue holding what review of #222 filed rather than gated; it is
  cited where a rule is held for the legacy entries and not yet for a
  generated one -- an ID deleted outright, with its declaration, its pin and
  its file, which nothing disagrees with afterwards
- #159: the issue filed as "append-only-docs-edit.sh is inoperative in every
  linked worktree". What it measured is narrower than its title, and review
  of #234 measured the other half: the guard permits an Edit or a Write of an
  entry in another checkout of this repository than the session's project
  directory -- a linked worktree's entry when the project directory is the
  main checkout, and the main checkout's when it is the worktree. Cited in
  #157's issue file, which pins the dev-log README saying so, so that the
  README gives the append rule as an instruction rather than as something the
  guard holds, and which feeds the guard both directions at today's verdict
  (GH-157.3), against a real linked worktree. Each of the two remedies the
  issue proposes was measured turning a check there red. It adds its
  requirements in the pull request that fixes it
- #176: the heredoc append `append-only-docs.sh` refuses because a `>` in the
  heredoc's prose, with a guarded path after it, reads as a truncating
  redirect. Cited in #157's issue file, where the dev-log README routes
  around it -- a scratch file, appended with `cat <file> >> <entry>` -- and
  GH-157.3 feeds the guard the README's `>` example at today's verdict;
  taking the `>` rule out of the guard was measured turning that check red.
  Whether it is fixed or accepted is its own decision, so it has no entry
  above
- #237: the same refusal from the guard's other two rules, a `sed -i` or an
  `rm`, `mv`, `cp`, `truncate` or `tee` read out of a heredoc's prose, which
  #176's proposed remedy does not reach. Filed from review of #234 (round 3),
  when the dev-log README was found citing #176 for all four of its
  examples. Cited in #157's issue file beside the `sed -i`, `rm` and `mv`
  rows; taking the `sed -i` rule, or `mv`, out of the guard was measured
  turning the row it decides red. Fix or accept is its own decision, so it
  has no entry above
- #238: the permitting half of a stale read, which #144 leaves: a session that
  fetched before a dev branch rotated reads the outgoing branch as active, so
  `--base dev-05` is permitted without a word, and no refusal exists to name
  the remedy in. Filed from round 1 of rev-agent-pr-158's review of PR #158,
  after the merge across the split. Cited in GH-144.7's note and in
  `no-pr-decisions.sh`'s header, where the refusing half is answered by the
  message and this half is not. It needs a network read to close, so fix or
  accept is its own decision, and it has no entry above
- #240: a git read that hangs rather than fails, holding a boundary hook past
  the harness's timeout. In `no-pr-decisions.sh` the ref read runs ahead of the
  gh api rules, so a stalled read holds a merge refusal behind a create that
  names a base. Filed from round 4 of rev-agent-pr-158's review of PR #158,
  across the boundary, since the other hooks' local git reads are unbounded too.
  Cited in GH-144.2's note, GH-108.5's and the #144 issue file, where "a failed
  read costs the narrowing and no refusal" is qualified to a read that fails. It
  concerns every hook that reads git, so it has no entry above
- #234: the pull request for #157; rev-agent-157's review of it is cited where
  what it found stands -- a README sentence about a guard, pinned as text,
  that the guard did not bear out, which is why GH-157.3 feeds the guards the
  README's own examples, against a fixture the proposed fixes of #159 read;
  an absence asked of one spelling of the numbered name, then of one case of
  its stem; and a bullet pinned a sentence at a time, then ending on a ` - `
  a nested sub-bullet supplies, then chained by pins that were each a
  substring match anywhere, which is why the span is one literal
- #235: the issue that owns the #102 header audit comparing basenames. Cited
  in #157's issue file, which spells the dev-log README's path so that the
  audit asks for it, and which says the audit is satisfied by any file named
  `README.md`
- #191: the two classes `cs_git_args` carries and `CS_GH_AWK` does not, found by
  the class sweep in that review's round 2. It has no entry above on purpose:
  pre-existing and measured identical at `dev-05`, so the requirement that would
  carry it is the fix. GH-118's note names both classes and points here
- #194: a quoted gh option value holding whitespace, several tokens to a walk
  that cuts on whitespace. No entry above for the same reason as #191, and for
  one more: it is third-order, none of the three recognised options taking a
  value that may contain whitespace, so there is no decision behind it to
  require. A check pins the permitted verdict and its label names the issue
- #197: a command substitution cutting inside an option value, which leaves no
  stump, and the same cut inside a path word, which defeats the rule outright.
  Found by the class sweep in that review's round 4. No entry above for #191's
  reason, and the two are one issue on purpose — the second is easier to write
  than the first and is unreachable by option-value work, so a fix that closed
  only the first would re-create the asymmetry it was meant to remove. Three
  checks pin the permitted verdicts and a fourth pins the contrast that says the
  first is a gap in the rule rather than the rule working
- #166: `$'…'` and `$"…"` quoting, not read as quoting at any position. Cited
  in #118's issue file, where `gh pr $'-t' view merge 5`, its locale spelling
  and an ANSI-C option in front of the group are pinned as permitted boundary
  rows: `ghreduce` takes the quotes out and leaves the `$`, so the token does
  not open with a dash and the walk stops on it. Found by round 5 of the
  review of #184. It adds its requirements in the pull request that fixes it
- #242: no load-time compile check for the library's awk programs, so one
  that does not compile fails open. Cited beside the `CS_GH_AWK` withdrawal in
  `lib/command-scan.sh` and in `no-pr-decisions.sh`, where round 5 of the review
  of #184 found the withdrawal called the one state a `command -v` guard cannot
  see when it is the harmless one of two. It concerns every awk program the
  library carries, so it has no entry above
- #192: `written` and `unarmed` grep a file's lines, so a phrase that wraps
  reads as absent -- a false green for an absence pin and a false red for a
  presence pin. Cited in #118's issue file, where the four pins over CLAUDE.md's
  ninth left-open consequence read the section through `comment_reflow` after
  round 7 of the review of #184 rewrapped the item and turned one red. The same
  raw shape in the GH-99.1 and GH-117.1 pins over CLAUDE.md, and in
  `prose_count`, was added to #192 then, as that issue's class. It adds its
  requirements in the pull request that fixes it

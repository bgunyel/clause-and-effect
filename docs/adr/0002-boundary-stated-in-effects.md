# The agent boundary is stated in a command's effect, not in its spelling

A boundary rule here names an **effect** — a write to `origin`'s git data, a
decision about a pull request, a write to a release — and where it must name a
command surface to do that, it names the surface as an **allowlist of what is
permitted, with a default-deny**. A spelling nobody enumerated is then refused,
and the cost of having missed it is a refusal that is visible and one edit away,
rather than a permission nobody knew was granted.

This is written down because the alternative was tried four times and failed the
same way each time. Each of these is one act reached under a spelling the rule
that governed it did not name, and **every one was found by review rather than
by the check suite, which was green before each**:

- **#47** — a rule existed for `gh pr`, and the `gh api` REST spelling of the
  same decision reached past it.
- **#97** — release writes were refused by a denylist of three verbs. It was
  short by `edit --draft=false`, by `upload`, and by `new`, which is gh's own
  alias for `create`.
- **#131** — `gh issue develop` creates a ref on `origin`. It is an issue
  subcommand by name, which is what every rule about it read, and a ref-creating
  write by effect, which none of them read.
- **#143** — the whole class underneath #131. A force-move and a deletion of
  `refs/heads/dev-NN` through `gh api` pass all seven registered Bash hooks, and
  `dev-NN` carries no ruleset to refuse them afterwards the way `main` does, so
  they are covered by nothing at either layer. Review of the commit that records
  this decision found a further spelling in the same position,
  `POST /repos/O/R/merges` — the REST *merge a branch* endpoint, which no hook
  names at all and which advances `dev-NN` when `dev-NN` is its base. This
  decision does not say how many there are, and the reason is that the number
  moved three times while one rule was being argued about.

#143 also measures the trap directly, and the numbers are the argument. Its
first filing counted four GraphQL mutations that write a ref and asserted the
class could not attach content; re-measurement the same day found a fifth
mutation, `createCommitOnBranch`, and found `PUT /repos/O/R/contents/…?branch=…`
advancing that ref with content — strictly worse than the ref creation the
filing did cover. A hand-kept list of spellings was wrong within hours of being
written by someone looking straight at the surface it described.

**The decision therefore has two halves, and the second is what makes the first
enforceable.** A rule states the effect; and because the hooks can only read a
command's text, the text-level rule that stands for that effect is a positive
list of what may pass. `.claude/hooks/no-pr-decisions.sh` already holds the
worked example, in the `gh release` allowlist taken as #103's Q26: a group gate,
five permitted read verbs asked one at a time, and a default-deny, replacing a
denylist of writes. Its header states the reason this ADR generalises — "a list
of writes has to be kept in step with gh, and misses a subcommand a future gh
adds".

`CONTEXT.md`'s *Reserved act* entry is the same principle expressed as
vocabulary rather than as a rule: it enumerates acts, says in terms that
"reserved is not a synonym for refused", and directs an agent to report and stop
where nothing enforces. That entry predates all four issues above and was
already right. What was missing was the general statement that a *rule*, not
only a reserved act, is named by its effect — and the clause in that entry which
its own principle required, added with this ADR.

## What this costs, knowingly

**An allowlist refuses legitimate work until someone names it.** That is the
trade, and it is not free here: two `gh api` writes the agent workflow uses
today sit on the wrong side of the inversion and are written down nowhere in the
repository — a `POST …/issues/<n>/sub_issues`, which is how every boundary bug
since #94 was linked to its parent, and the `addCloseIssueReferences` mutation,
which is the only way a pull request based on `dev-NN` links its issue, the
`Closes` keyword having no effect on a non-default base. No rule, hook or check
names either; outside this ADR and the dev-log entries that record it, a grep
for either over every `*.md` and `*.sh` in the repository returns nothing. So an
allowlist
seeded by reading the hooks would have been seeded from the wrong set, and
seeding one is an audit of what agents actually do, not a transcription of what
the denylists currently refuse.

**It does not make a rule read a command correctly.** An allowlist changes the
default; it does not change the tokeniser. `gh api graphql -f
query=mutation{delete"Release"(…)}` evades a name in the existing list by
quoting inside the word (#135), and `-f query=@file` and `--input file` put the
payload where no field rule reads it (#138). Both survive this decision and are
tracked as their own bugs. What the decision buys against them is direction: the
same three evasions against an allowlist produce a refusal, not a permission.

**It widens what the suite must pin.** A default-deny rule needs checks in the
permitting direction for everything that must keep working, which is more checks
than a denylist needs and they are the ones that matter — #103's Q15 already
requires both directions, and the permitting half is now the regression net for
the inversion itself.

## What this does not decide

The inventory. Following ADR 0001's own scope rule — "this decision is about the
mechanism and deliberately records no inventory of which commands are
permitted" — which surfaces are allowlisted, and with what on them, lives in the
hooks, in `CLAUDE.md` and in the `GH-` entries of
`.claude/hooks/requirements.md`. This ADR records why those lists have the shape
they have.

## Considered Options

**Keep denylists and extend one per spelling as each is found.** The status quo,
and the reason this ADR exists: four occurrences, none caught by the suite, each
extension correct and each still short. The failure is not that any list was
badly made — #97's was three verbs and missed three more, one of them an alias
the provider chose — but that a list of what is refused has to track a surface
neither Bertan nor the hooks control. Rejected on that record.

**Parse commands semantically instead** — model `gh`'s and the REST API's
argument grammar properly, and judge the parsed act. This is the shape that
would actually read an effect rather than standing in for one. Rejected on
cost and on risk: the hooks run under a 5-second `PreToolUse` timeout with a
16 KB per-line cap (#96), they are shell reading text, and the tokeniser they
already have has produced nine defects found by review across three rounds
(#84's header counts them). A larger parser is a larger silent-permit surface,
and the direction of its failures is what matters, not their number.

**Move the boundary server-side so effects are judged where the agent cannot
reach them.** This is ADR 0001's question, not this one's, and 0001's answer
stands: an agent acting with Bertan's credentials cannot be separated from him
by a ruleset. #143 sharpens the consequence rather than the decision — `main`
has a ruleset that refuses a force-move after the hooks permit it, and `dev-NN`
has none, so on `dev-NN` there is no second layer for an effects-based rule to
fail into. That argues for the allowlist being right, and for revisiting 0001's
deferred option of giving the agent its own actor.

**State the effect in prose only, in `CLAUDE.md` and `CONTEXT.md`, and leave the
hooks as they are.** Cheapest, and it is half of what is being done — the
vocabulary edit landed with this ADR. Rejected as sufficient: #36's US-16 asks
that a reader be able to judge the boundary without reading the hooks, which
prose serves, but a documented boundary that no rule enforces is the state #143
found, where `CONTEXT.md` reserved an act and named `no-git-push.sh` as what
refuses it while three other spellings went through.

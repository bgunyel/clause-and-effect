# 2026-09-17 · session 2 — the boundary was written in a command's spelling, and the fourth spelling of one act was permitted

**Branch** `worktree-issue-143-boundary-in-effects`, cut from `origin/dev-05` at
`befcf8a`, to be proposed into `dev-05`. The work is **uncommitted in the
worktree** at the time of writing, left in the tree for Bertan's review.
**Check suite 3657 → 3660 results, all passing.** Three of the new results are
checks added here — two `written` and the `unarmed` that pairs them — each
mutation-checked individually; the text-check count literal moved 274 → 277 with
them.

A grilling session on #131, which was open on one question: which of three
verdicts `gh issue develop` gets. It closed that question, and on the way it
established that #131 was the fourth arrival of one defect rather than an
isolated gap, filed the class as #143, and corrected two claims of the
assistant's — one of them in a GitHub issue that had already been filed.

No hook was changed. Every rule this session decided on is queued behind other
open bugs, for a reason recorded below.

## The verdict on #131, and the option that was proposed on a false premise

#131 offered three answers: leave `gh issue develop`'s creating spellings
permitted and pin `ALLOW`; refuse them and permit `--list`; or refuse the
subcommand outright and narrow US-14. **Option 2 was taken** — refuse the
creating spellings, permit `--list` — which is #103 Q26's `gh release` shape,
every read-only action permitted and every other refused.

The assistant proposed a fourth option that is not in the issue: permit
`gh issue develop` only when `--base` names the active dev branch, on the
argument that the command used that way enforces two things the repository
currently gets by convention — the fork point at `origin/dev-NN`, and the
issue-to-branch link that the `Closes` keyword cannot make on a non-default
base.

**Bertan established that the second half of that argument is false, and that
the repository had already measured it.** `gh issue develop` writes
`linkedBranches`, a branch-to-issue link; `Closes` writes
`closingIssuesReferences`, a pull-request-to-issue link. They are different
GitHub features, no mutation exists for the second, and this was recorded on
2026-09-09 under PR #35 and #37. The fork-point half survives but is weaker than
the assistant put it: `--base dev-05` creates a *remote* ref at `origin/dev-05`'s
tip, while CLAUDE.md's rule governs where the *local* worktree branch starts, so
the command removes no step from that rule. Against it, `--checkout` moves the
invoking checkout off its branch and `--branch-repo` writes the ref into another
repository entirely — two effects #131's body did not name.

Option 4 was then rejected on cost as well as premise, and the reasoning is the
transferable part: it is a **permit conditional on a field's value**, and #135,
#137 and #139 are all open bugs in exactly that machinery — a quoted subcommand
word evades every rule that reads one, the base reader knows one quote spelling,
and a quoted base flag removes a refusal where naming no base is permitted. A
conditional permit built on an unfixed parser fails **open** when the parse
fails. Option 2 fails closed under the same three. That is why it was taken over
option 3 as well, which is simpler but buys a spec amendment and discards a real
read.

## #143: the class under #131, and the two rows nothing covers

#131's own triage note had measured a class of commands beside `gh issue
develop` — a write to a ref on `origin` spelled through `gh api` rather than as
a push — and recommended filing it separately so a low-severity headline would
not bury it. That was done, as **#143**, and the recommendation was right for a
reason sharper than severity: #131's body asserts the subcommand "cannot move or
delete an existing ref", and the row beside it deletes `dev-05`.

Measured by feeding each command to each of the seven registered Bash
`PreToolUse` hooks as JSON on stdin, at `acefb24` and again at `befcf8a` with
the same verdicts; nothing was executed and nothing reached `origin`. Every
spelling is permitted by all seven: `POST …/git/refs`, a force-`PATCH` and a
`DELETE` of `refs/heads/dev-05`, and the GraphQL mutations `createRef`,
`updateRef(force:true)`, `deleteRef` and `createLinkedBranch`. `git push --force
origin dev-05` and `gh api --method POST …/merges` were carried as controls and
are refused, because a harness that permitted everything would print the same
table.

**#131's triage said four boundary hooks; the number is seven.** Bertan's
verification corrected it: the four boundary hooks plus `alembic-via-uv-group`,
`pytest-via-uv-group` and `append-only-docs` are all registered on `Bash`, and a
claim about what "every hook" permits is a claim about all seven.

The `main-branch-protection` ruleset was read rather than recalled:
`include: ["~DEFAULT_BRANCH"]`, `exclude: []`, `bypass_actors: []`, rules
`deletion`, `non_fast_forward`, `pull_request`. So a force-move or deletion of
`main` passes all seven hooks and is then refused by the server, while `dev-NN`
carries no ruleset at all. **A force-`PATCH` and a `DELETE` of
`refs/heads/dev-NN` are the only acts in the measured set that neither a hook
nor the server covers**, and they are a data-loss path onto the branch where
unmerged work lives. `docs/adr/0001-hooks-not-ruleset.md` argues that `dev-NN`
rests on hooks because an agent acts with Bertan's credentials; these are the
rows where that reasoning has no hook to rest on.

## The assistant's filing of #143 was wrong about its own scope, and review found it by measuring

As first filed, #143 asserted that the class "cannot push blobs that are not
already on the remote — a ref write names an existing object — so this is ref
manipulation, not a content-upload path". **That is false.** Bertan's review
measured `gh api --method PUT …/contents/README.md -f branch=dev-05`, which
writes content *and advances `dev-05`* in one call — strictly worse than the
`POST …/git/refs` the filing did cover — along with `DELETE …/contents/`,
`POST …/git/blobs`, `POST …/git/commits`, and `createCommitOnBranch`, a fifth
ref-affecting mutation the filing's count of four had missed. All permitted by
all seven hooks.

CONTEXT.md names *advancing the active dev branch on the remote* as a reserved
act in as many words, and cites `no-git-push.sh` as what refuses it. The first
of those rows does exactly that and is refused by nothing.

The issue's title and body were widened the same day and the original scope
recorded in a revision note rather than silently replaced. **The number is the
argument, not the embarrassment**: a hand-kept list of spellings was wrong within
hours of being written by someone looking straight at the surface it described,
which is the whole case for the decision below.

## Two ways a mutation-name denylist is evaded today, and they decide the fix's shape

Also Bertan's, measured against the live `/releases` rule as a proxy and against
the mutation lists directly. All permitted by all seven hooks:

- `gh api graphql -f query=mutation{delete"Release"(…)}` — intra-word quoting,
  which is #135's shape, against a name already on the list.
- `gh api graphql -f query=@/tmp/rel.graphql` and
  `gh api graphql --input /tmp/rel.json` — the payload is in a file, and **no
  field rule reads a request body**, which is #138's shape applied to GraphQL.

The endpoint machinery held up better than feared: whole-argument quoting,
trailing-segment quoting and `-X` are all survived, and only intra-word quoting
evades. So a fix here inherits one tracked bug rather than new debt.

The consequence is about wording, and it is why the verdict below is phrased the
way it is. Any predicate that *hunts for mutation text* inherits all three
evasions however long its list. Only a predicate that refuses **unless a query
is demonstrably present and a mutation demonstrably absent** refuses the two
file spellings, because neither has a demonstrable query anywhere in its text.

## The verdict on #143: two allowlists, which is Q26 applied twice

**Refuse every `gh api` write whose endpoint is not on an allowlist of permitted
writes, and refuse every GraphQL command that is not demonstrably a query.**

Two amendments are Bertan's, and both move the answer away from where the
assistant had put it:

- The REST predicate must **not** be a `git/refs` denylist. That is the same
  mistake one layer up: it leaves `PUT …/contents/`, `POST …/git/commits` and
  `POST …/git/blobs` permitted, and the first of those advances `dev-05` with
  content attached.
- The GraphQL half must be the allowlist and not a widened denylist. The
  assistant's phrasing contained both readings; the measurement above decides
  which is operative.

`gh_api_is_write` (`no-pr-decisions.sh:244`) was verified rather than assumed as
the gate to hang the REST half on: it is a genuine method allowlist, it reads
both `-X` and `--method`, and at `:252` it returns *write* when the flag is
present but its value unparsed. It fails closed.

**What the verdict costs was found by checking before recording it.** An
allowlist inverts `gh api`'s default from permit to refuse for every write, and
two writes the agent workflow uses today are on the wrong side of that
inversion: `POST …/issues/<n>/sub_issues`, which is how every boundary bug since
#94 was linked to its parent and how #143 itself was, and the
`addCloseIssueReferences` mutation, which is the only way a pull request based
on `dev-NN` links its issue. **A grep for either over every `*.md` and `*.sh` in
the repository returns nothing** — they are conventions held in session memory
alone. An allowlist seeded by reading the hooks would therefore have been seeded
from the wrong set, and seeding one is an audit of what agents actually do.

A severity split of #143 was considered and rejected. What forced the split off
#131 was a headline asserting the opposite of a row beneath it; #143's headline
names its worst row, so nothing is buried, and splitting a class whose edge was
still wrong would have produced two issues that both had the wrong edge.
**#103 Q14 sub-IDs** take its place: `GH-143.1` a ref is not created, `.2` not
moved non-fast-forward or deleted, `.3` not advanced by a content write — by
effect, not by spelling, spelling-independence being #141's business.

Sequencing: after #135 and #138 at minimum, because the GraphQL half is phrased
as it is *because* #138 is open, and both halves inherit #135.

## The lesson was already in the glossary, one clause short

The assistant proposed coining a term — *Ref write* — for the class.
**Bertan established that the term already exists**: CONTEXT.md's *Reserved act*
says in terms that "reserved is not a synonym for refused", enumerates acts
rather than commands, and directs an agent to report and stop where nothing
enforces. That is effects-not-spellings, written before any of these four
issues.

What was missing was one clause *in* it. The entry reserved advancing the active
dev branch **on the remote**, and moving a **local** `main` or `dev-NN`. A remote
force-move or deletion is named by neither, and that gap is exactly where #143's
two worst rows sit. The clause was added, with a paragraph naming what refuses
it — nothing — and `GH-143.4` records the claim as a `doc-claim`, tagged by two
new `written` checks.

`docs/adr/0002-boundary-stated-in-effects.md` records the general form: a rule
names an effect, and where it must name a surface it names an allowlist with a
default-deny. **ADR 0001 pre-authorises the second ADR rather than colliding with
it** — Bertan's point — because 0001 says of itself that it "is about the
mechanism and deliberately records no inventory of which commands are
permitted", and how a rule is *stated* is a mechanism question. Its Considered
Options section was written by the four issues: keeping per-spelling denylists,
parsing commands semantically, moving the boundary server-side, and stating the
effect in prose only.

## GH-131's requirement text could never have gone green

As written by #105, `GH-131` required that "what an agent may do with it **is
decided** rather than left to whichever rule happens not to match". That was
right while the verdict was open, and it is not falsifiable by any check.
Bertan's point is that **Q15 makes the rewrite mandatory rather than tasteful**:
an active requirement is covered only when it has a tagged check that refuses
and one that permits, and "a decision exists" admits neither, so the entry would
have sat permanently uncoverable — the state Q15 exists to prevent.

The text now states the behaviour in both directions: a creating spelling is
refused whichever of `--base`, `--name`, `--checkout` and `--branch-repo` it
carries and whether it carries none, and `gh issue develop --list` is permitted.
This is **not** a Q10 supersession — Q10 governs user stories, which are
transcribed verbatim and gain `superseded-by:`. A `GH-` entry is written from a
defect and is edited in place. The general rule recorded with it: a
`gap → #<n>` entry's text is provisional, and is restated in the behaviour when
its verdict is taken.

## A re-wrap of CONTEXT.md turned three passing checks red, and the reason is worth keeping

The assistant's first edit placed the new clause mid-enumeration and re-wrapped
the paragraph. Three existing checks went red: two spellings of "the enumeration
names the act the report cites" and "the enumeration reserves moving a local
main or dev branch". `written` greps a file for a literal phrase, and a phrase
that was on one line was now split across two. The clause was moved to the end
of the enumeration, leaving both pinned phrases intact, and the suite went green
again.

The wrap sensitivity fails in the safe direction — a cosmetic edit is refused
loudly — and is recorded rather than filed. The weakness beside it is filed, as
**#145**, and the assistant's first framing of it was too wide.

The assistant claimed `written` cannot tell a claim from its negation, and
therefore that superseded-wording drift went unguarded. **Bertan established
that half of that is already solved and the idiom is in the same file**:
`unarmed` (`check-hooks.sh:643`) asserts a literal's *absence*, `GH-97.2` pairs
it with `written` for exactly this reason — "a document that gained the new
phrase and kept the old would state two rules" — and it already carries the
unreadable-file guard that review of #84's change added, `grep -qF` on a missing
file having exited 2 and read as `ok`.

What is actually open is narrower and in two parts. **Contradiction by
addition**: both helpers ask only whether a string occurs, so a sentence added
to an entry can reverse a pinned claim while leaving its literal untouched, and
nothing goes red. **Re-framing**: the phrase stays, nothing contradicts it
outright, and it no longer means what the check reads it as meaning — which no
`grep` can decide, and for which #103 Q17 already provides `seam: none` with
`verify: review`, unused for these.

The immediate consequence was concrete and is fixed here: the new clause was
pinned by two `written` checks and no `unarmed`, so a straight revert of it
would have passed. It now carries one, keyed on the terminating period the
enumeration used to end with, and the pairing reddens on a revert though still
not on a contradiction. Text checks 276 → 277.

Q16's other half then fired, which is worth recording because it fired on the
comment rather than on the code. The `unarmed`'s comment cites #145 to mark
which half the pairing reaches, and the suite holds that **every `#<n>` cited in
`check-hooks.sh` has an entry in `requirements.md` or an explicit reason** — so
`the suite cites #145, which has no entry and no reason` went red alongside the
mutation's two. #145 is listed as a citation that is not a requirement, with the
reason stated: its four options differ in whether they produce a requirement at
all, since accepting the limit moves existing doc-claims to `verify: review`
under Q17 and adds none. Writing a `GH-145` entry now would have had to say only
that the question is open — the unfalsifiable shape `GH-131` was rewritten in
this same session to stop saying.

## State, and what the next session picks up

- **#131** `ready-for-agent`, verdict recorded in its second comment, sequenced
  after #135 and #137.
- **#143** `ready-for-agent`, sub-issue of #36, verdict recorded, sequenced
  after #135 and #138. Its `GH-143.1`–`.3` entries are not written; `.4`, the
  document half, is.
- **#145** `needs-triage`, sub-issue of #36: contradiction by addition, and the
  re-framing half that belongs under Q17's `verify: review`. Four options, none
  pinned.
- **Uncommitted in this worktree**: the CONTEXT.md clause, ADR 0002, `GH-131`'s
  rewritten text, `GH-143.4`, two `written` checks and an `unarmed`, and the
  text-check count literal at 277.
- **Open**: whether the `gh api` write allowlist is seeded from an audit of
  agent usage, which #143's verdict says it must be and which nothing has yet
  done. CLAUDE.md's boundary paragraph is deliberately untouched and lands with
  #143's rule in the same pull request, so the paragraph and the refusal move
  together; the *Deliberately left open* count stays at **Five**, since
  `check-hooks.sh:5199` reads that word and fails on one it does not recognise
  rather than passing as zero.
- **Not decided here**: #141's scope rule, which decides whether either issue's
  `GH-` entries ever get an invariance seed. Both were linked to it.

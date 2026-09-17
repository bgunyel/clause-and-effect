# 2026-09-17 · session 3 — a control recorded as refused was permitted, and the count it stood on was stale in four documents

**Branch** `worktree-issue-143-boundary-in-effects`, proposed into `dev-05` as
pull request #146, at `9bd972a` when the review arrived. **Check suite 3660 →
3665 results, all passing.** Five of the new results are checks added here; the
text-check count literal moved 277 → 282 with them. No hook is changed by this
session either.

Bertan reviewed #146 and requested changes, re-measuring every load-bearing
claim in it in a separate clone. The thesis and the central measurement
reproduced exactly, and so did the suite figures, the ruleset read and the
seven-hook correction. Five findings did not reproduce, and the first of them is
a defect in the permitting direction: a command the previous entry recorded as
**refused** is permitted by all seven registered Bash hooks, and its effect is a
reserved act that no ruleset reaches either.

## The control that was not refused

`gh api --method POST /repos/bgunyel/clause-and-effect/merges -f base=dev-05 -f
head=<branch>` passes all seven hooks. Re-measured here by feeding it to each
hook as JSON on stdin; nothing was executed. It cannot block in any
environment, because **no hook contains a rule that matches `/merges` at all** —
a grep across every hook and `lib/command-scan.sh` returns two prose comments in
`no-work-on-stale-branch.sh` about when a pull request merges, and nothing else.
The merge spellings that are ruled on block correctly: `gh api --method PUT
…/pulls/35/merge` and `gh pr merge 35 --squash` both on `no-pr-decisions.sh`,
and `git push --force origin dev-05` on `no-git-push.sh`. So the measurement rig
was sound and the row was simply wrong.

The previous entry recorded that force-push and that `POST …/merges` as
"controls, and they are refused". The push is refused. The assistant wrote the
second row without measuring it, and wrote it in the direction that made the
boundary look tighter than it is — in a record that is append-only.

`POST …/merges` is the REST *merge a branch* endpoint. With `base=dev-05` it
creates a merge commit on `dev-05`, which **advances the active dev branch on
the remote** — the first act `CONTEXT.md`'s *reserved act* enumerates, and one
`main-branch-protection` does not reach, since that ruleset targets
`~DEFAULT_BRANCH`. It is therefore uncovered at both layers, exactly like the
force-move and the deletion that #143 was filed on. Recorded on #143 rather than
as a new issue: it is the same thesis arriving under a third name for one
effect, and it needs no new sub-ID, because a default-deny predicate that
refuses it is the predicate `GH-143.1`–`GH-143.3` already describe. It does
sharpen that issue's Amendment B, which is the half that matters — a REST
allowlist keyed on `git/refs`, or on "ref endpoints" generally, would not catch
this one, because `/merges` is a ref endpoint only by effect and not by path.

## The count, in four documents, already false where it stood

The sentence "those two are the only acts here that neither a hook nor the
server covers" was carried by `CONTEXT.md`, by ADR 0002, by #146's body and by
the previous entry. `POST …/merges` falsifies it. Reading falsifies it too,
without any measurement: the same paragraph in `CONTEXT.md` named a third such
act two sentences later, the `PUT …/contents/` write found during the previous
session.

Bertan's instruction was to correct it rather than re-number it, and no document
carries a count now. `CONTEXT.md`, ADR 0002 and `GH-143.4` state none, and a new
`unarmed` holds `CONTEXT.md` to stating none. The number had moved three times
in one day — two spellings when #143 was filed, three by the end of the session
that filed it, four at review — which is the argument for saying that a measured
set is only ever as wide as the spellings someone thought to try.

## A check that pinned a placement rather than a claim

The `unarmed` added last session asserted the absence of `'checkout it is
checked out in.'`, on the reasoning that the enumeration used to end on that
clause, so the absence of its terminating period says the addition is still
there. Bertan measured the five mutants that reasoning implies and it does not
hold. A straight revert of the clause reddens **both** `written` checks on its
own, so the `unarmed` adds no falsification power there. What it uniquely
catches is the clause moved to sit beside the act it extends — a **correct**
document, and one of the four judgements #146's own review pointers invited a
reviewer to overturn.

The justification the assistant wrote into the comment beside that check — that
a revert would otherwise pass — was false, and it was checkable in the file it
was written in. The check is replaced by an `unarmed` on `'the only acts'`,
which is a claim about what the document says rather than about where its lines
break, and which falsifies a count coming back.

The session-2 entry recorded those three checks as "mutation-checked
individually", and that was true as far as it went: each was reverted and seen
to redden. What the assistant did not ask is whether each reddened for the
*reason* its label gives. A mutation that reddens a check is evidence the check
is reachable; it is not evidence that the check measures the claim beside it.

## The fragile fixture the suite had already fixed

All three new checks read `$RESERVED_ENTRY`, the extracted entry as written.
`written` and `unarmed` match a literal within a line, so a check over that
fixture is partly a check on where the paragraph happens to wrap — which is why
`$RESERVED_FLAT` exists at `check-hooks.sh:5362`, added under `GH-97.2`, with
the measurement recorded in the comment above it.

So the fact the previous entry recorded as a property of the document — that
placing the clause mid-paragraph re-wrapped two pinned literals and turned three
passing checks red — was a property of the checks. The assistant wrote three new
checks against the fragile fixture, hit its documented weakness, and then shaped
`CONTEXT.md` around it, with the fix sitting 200 lines up in the same file. All
four checks now read `$RESERVED_FLAT`, the clause sits beside the act it
extends, and the placement decision recorded last session is overturned. The
re-wrap that follows from moving it leaves every pre-existing pin green, which
was measured rather than assumed.

## `CLAUDE.md` said there was one ADR

`CLAUDE.md`'s *Domain docs* section opened "Single-context: `docs/adr/` holds one
ADR", and `docs/adr/0002-boundary-stated-in-effects.md` made that false in the
commit that added it. Nothing caught it: a grep for `docs/adr` across
`check-hooks.sh` returned nothing at all. The clause sat two clauses to the left
of the one sentence in the file that warns a reader off exactly this — "this line
deliberately does not enumerate it: the sentence that did named two terms of
five and went stale without saying so".

The count is gone rather than corrected, for the reason that sentence gives
about the glossary, and the line is now pinned as `GH-143.5` with a
`written`/`unarmed` pair over the flattened section: that the section names
`docs/adr/` as where the ADRs are, and that it states no count of them. This was
the drift class ADR 0002 is about, arriving unguarded in the document that
describes where ADR 0002 lives.

The reason the rest of `CLAUDE.md` is still untouched is unchanged and was
confirmed in review: its boundary paragraph is the text the hooks refuse in the
words of, `GH-97.2` pins the two to the same phrase, and restating it in effects
while the hooks still refuse one spelling would manufacture that drift in the
wider direction. That reason does not reach the *Domain docs* line.

## ADR 0002 contained a claim its own commit falsified

The ADR said of the two undocumented `gh api` writes that "a grep for either
over every `*.md` and `*.sh` in the repository returns nothing". True at
`befcf8a`; false at `9bd972a`, where the ADR and the dev-log entry both name
them. The intent — that no rule, hook or check documents those writes — is what
the sentence now says, with the two hits named.

## Errors, all four the assistant's

1. **A control row recorded without being measured**, in the permitting
   direction, in an append-only record.
2. **A count published in four documents** that was false in the paragraph it
   stood in.
3. **A check whose stated justification was false**, pinning a placement while
   its comment claimed it pinned a revert.
4. **Three checks written against a fixture documented as fragile**, followed by
   a document reshaped to satisfy them.

The first was caught by measurement, the other three by reading — two of them by
reading the very file the checks were added to.

## What is open

- **#143** gains `POST …/merges`, by comment; its body stands as filed, with the
  comment as the correction rather than a silent edit. Sub-IDs unchanged. Still
  sequenced after #135 and #138.
- **#145** is unchanged. Contradiction by addition is still the half no text
  check reaches, and the new `unarmed` disclaims it in as many words.
- **The *Deliberately left open* count stays at Five**, for the reason recorded
  on #143: reaching for an API spelling after a push was refused is an honest
  next move, which is what makes this a bug rather than an accepted gap.
- **No rule is written.** Every verdict this branch records is still queued
  behind #135, #137 and #138.

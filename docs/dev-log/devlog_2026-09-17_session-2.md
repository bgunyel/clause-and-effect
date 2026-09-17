# 2026-09-17 · session 2 — #137: two field readers, each knowing one quote spelling of its own field

**Branch** `worktree-issue-137-field-quote-spellings`, cut from `origin/dev-05`
at `befcf8a` and proposed into `dev-05`. One commit, leaving the branch one ahead
of `origin/dev-05` and 185 ahead of `origin/main`. **Check
suite 3657 → 3698 results, all passing** — 41 new checks, of which 18 go red
when the fix is reverted. Every figure here was measured in the worktree, none
recalled.

Issue #137 was filed during the grilling of #130's fix design and measured on
`dev-05` at `8b1cbaf`. Two rules in `no-pr-decisions.sh` read the value of a
named **field** rather than an endpoint: `state` decides whether a `gh api`
write closes or reopens a pull request, and `base` decides where one is
proposed. Each knew one spelling of the quoting around its own field.

## The gap ran in opposite directions, because the two rules are triggered oppositely

**State refuses on presence**, so a spelling it cannot see is a refusal that does
not happen. The pattern was `state[[:space:]]*[=:][[:space:]]*"?(closed|open)"?`
— a double quote admitted round the value, a single quote not — so
`gh api -X PATCH repos/o/r/pulls/5 -f state='closed'` reached GitHub. Four
spellings of one request were permitted: the value in single quotes, the same
for `state='open'`, `--field state='closed'` and `-fstate='closed'`.

**Base refuses on absence**, so a spelling it cannot see is a base that is not
there. `rest_bases` anchored on the field flag with the field name immediately
after it, and the quote `gh` accepts round a whole field goes *between* the two.
So `-f "base=dev-05"` read as a create that named no base, and the single
destination an agent may propose into was refused with the message saying none
was given.

Both were measured by the assistant before anything was changed, by feeding each
command to the hook on stdin — never by running one. The issue's table
reproduced exactly.

## A third consequence, which the issue's table does not name

The quoted base is not only a refusing defect. The no-base arm it fell into is
keyed on the **collection** endpoint, and `/pulls/35` is not one. So
`gh api -X PATCH repos/o/r/pulls/35 -f "base=main"` — a retarget of an existing
pull request onto `main` — set no base the reader could see, matched no
collection endpoint, and was **permitted**. The refusing half of the base defect
was visible in the issue because a create was refused loudly; this half was
silent, and in the permitting direction. It is recorded in `GH-137.2`'s note and
pinned by two checks.

## The fix, and why the two readers are not made alike

**State** gains `STATE_FIELD_RE`, written once at the head of the file and read
by both call sites — the wrapper arm and the `gh api` write block. Two copies
were the defect's cause, not merely its shape: two copies can be fixed apart,
and a fix applied to one of them reads exactly like a fix.

The obvious next move — re-anchoring state on its field flag, in `rest_bases`'
shape — was considered and rejected. State has to reach a graphql `state:CLOSED`
inside a mutation body and a bare `state=closed` sitting in a wrapped line's
text, neither of which carries a flag at all; anchoring would narrow a rule whose
whole job is to be wide. So the two readers stay different shapes on purpose, and
the comment beside each says which direction it fails in and why that decides it.

**Base** gains an optional quote in one position only, between the flag and the
name. Everything the anchor was for survives: `-f database=x` and `-f rebase=x`
still begin with the wrong letter, `-f "database=main"` likewise, and
`-f title="base: dev-05"` still supplies no base. `rest_bases`' comment now
records three answers to "where does the field begin" rather than two, each
right about the one it replaced.

What the state widening costs is one spelling more of CLAUDE.md's left-open item
2: `state='open'` written as prose, on a line that already reaches these rules,
is now refused as `state="open"` already was. Named in the code and in
`GH-137.1`'s note rather than left for a later review to find.

## The evidence, and what it is evidence of

`requirements.md` gains `GH-137.1` (`defect-permitting`) and `GH-137.2`
(`defect-refusing`), both bare in `REQUIREMENT_SHAPE`, so each needs a refusing
and a permitting check.

The 41 checks were then run against three broken copies of `.claude/hooks/`,
judged through `$CHECK_HOOKS_DIR` so that this repository's own hooks were never
edited:

| what was broken | checks that went red |
|---|---|
| `STATE_FIELD_RE` back to the double-quote-only form | 6 |
| `rest_bases` back to no quote between flag and name | 10, two of them message checks |
| the fix applied to the write block and not the wrapper arm | 4, two of them the static pair |

Eighteen distinct rows; the two wrapper rows go red twice over, which is what
makes them the pair that tells a broken pattern from a pattern fixed in one place
only.

Twenty-three stay green under all three, and each block is declared in the
section's comments as what it is rather than left for a reader to assume. The
assistant's first version of this section declared it only in aggregate; the
per-block declarations and the ledger at the head of the section were added after
review, because #137's acceptance criterion asks that the pull request say so for
each and an aggregate does not.

Fourteen are contrast rows: the spellings the old patterns already reached, kept
so that the shape of the hole is on the record beside the hole. `-f
"state=closed"` and `-f 'state=closed'` are the two that matter most — they pass
today through the raw grep alone, and they are pinned so that a later
re-anchoring of the state reader on its field flag turns them red instead of
inheriting the gap this issue closed in `base`. Five of the fourteen reached the
same verdict before the fix **for a different reason**: a quoted create into
`main`, in three flag spellings, was refused for naming no base rather than for
naming `main` — which is what the two message checks exist to separate — and a
quoted retarget to `dev-05` was permitted because no base was seen at all rather
than because the base was good.

The remaining nine are arming and property rows: that the widened state pattern
still permits an ordinary retitle and still reads `state='draft'` as neither
verdict, and that the widened base anchor still keeps `rebase`, `database` and a
quoted title out of the base.

Nine of the 41 were added after the standards review observed that `rest_bases`'
own comment now claims five spellings of one request while the suite named two,
and that two of the three flags the anchor admits — `-F` and `--raw-field` —
reached no row at all. Three of those nine go red on the `rest_bases` revert; the
other six are contrast and property rows, declared as such beside them.

The two static checks are the half no verdict can see: that the state pattern
appears once in the file's code and that exactly two call sites read it. They are
the pair that fires on the one-call-site mutation, and without them a copy
reintroduced and corrected in one place would be silent again.

No mutation registry rows were added. `mutate-hooks.sh` takes about forty-five
minutes for its 23 rows, and a row that has not been run is the trap #107's own
self-tests exist to name: an edit that silently fails to apply reads exactly like
evidence and is none. The three reverts above were run instead, and they are
recorded here rather than claimed in a registry.

## Left for #130 and #138

#130's endpoint reader, the per-command move and the graphql gate are untouched,
and its worktree is cut after this one. A field read out of a JSON request body
supplied by `--input` is #138 and lands last; a state in such a body is permitted
today and a base in one is refused today, and neither changed here.

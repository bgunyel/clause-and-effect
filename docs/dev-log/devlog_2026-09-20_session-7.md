# 2026-09-20 · session 7 — #158 round five: the derivation was finished by changing what it reads, and the review changed what it asks

**Branch** `worktree-issue-144-active-dev-base`, proposed into `dev-05` at
`2a52322`. **Check suite 5196 → 5197 results, all passing**, and 5197 under each
of five ref states; requirements 190, 173 active; mutation registry unchanged at
64 rows. No requirement was added. The production hook was not touched, for the
fifth round running.

## The review changed method, and that is the larger half of the session

The fifth review of PR #158 arrived in two parts. The first was four findings in
`GH-144.4`. The second said the loop had been run by instance for five rounds —
each round re-reading a bigger diff, finding the next single defect, ending when
someone tires — and proposed the alternative: **a defect is evidence of a class;
one instance is enough to name it; name it and sweep every sibling.** It named
six classes this pull request had produced, and observed that class A contained
a guard written to close class A, and class D the pins written as evidence for it.

That observation is correct and it is the session's finding. Rounds four and five
patched instances. The class was never named, so it kept reappearing one shape
over.

## The argument the review invited, and the measurement that settled it

The review said it did not believe `GH-144.4`'s derivation could be finished, and
asked for a ruling rather than a fifth strengthening — while explicitly inviting
the opposite case: *"If you think the derivation can be made complete and I am
wrong, say so and show me the shape enumeration that closes it."*

The assistant disagreed, and the disagreement was settled by measuring rather
than by arguing. The derivations read this file's text, and a rule about shell
source enforced by grepping shell source will always have another spelling —
that part of the review is right, and is #128, #137, #139 and #155 one level up.
What does not follow is that the claim cannot be established. **It can be
established by reading the run instead of the file.**

Every harness that runs a hook now records the directory it actually entered, the
script, and the payload as the shell expanded it. None of the five known shapes
survives expansion: a variable arrives expanded, a loop arrives once per
iteration, a continuation is joined before the parser is done, and a hard-coded
`cd "$ON_DEV"` is recorded as `$ON_DEV` rather than read off an argument that is
a PATH. Measured on the shape the review said no derivation sees — the `for`-list
payload judged by `check_in … "$c" "$c"` — with that row flipped to `$SUITE_DIR`:

```
ok    and the directory each one names is one of these   <- the text derivation, blind
FAIL  and not one of them was judged in the directory the suite was started from
```

So the answer to "show me the shape enumeration" is that there is not one: the
enumeration is replaced by expansion. What remains assumed is that every harness
records, which is **one claim about twelve function bodies** rather than an open
claim about every row spelling — and it is derived, not asserted: the set of
functions whose body calls `hook_path` is compared with the set calling `judged`.
That check found two harnesses unrecorded on its first run, `cap_timed` and
`check_file`, which is the derivation earning its place immediately.

## The four findings

Finding 1 is closed by the above rather than by moving a row: the two live rows
were correct already, and what was wrong was that nothing covered them. Findings
2 and 3 are **deferred with the reason written** beside the derivations — they
are blind spots of a check that is no longer what the requirement rests on.
Finding 4 is **fixed**, because it is not a blind spot but a false red:
`feed`/`feed_says` take a PATH and hard-code `cd "$ON_DEV"`, so a `dev-NN` row
through either would have been reported as naming an unexpected directory while
being perfectly safe.

Then the variable-payload rule was **deleted**. Its `case "${!v}"` read each
value once, after the file had run, so a loop variable was read as its last
element — the review's class G, a value read at the wrong time. It is not
repaired because the run-reading pair covers the shape, and repairing it would
have left two answers to one question with the weaker one first in the file.

## What the sweeps returned, including the empty ones

A sweep that finds nothing is a result. Queries and returns are in the pull
request comment; in summary: the deferred-read class has exactly one live
instance and it was deleted; the restated-number class recomputes clean against
`--list` and against the file; the claim-in-more-places query for the deleted
rule returns **empty**, and for the superseded basis returns only the places that
describe it as superseded. Every `GH-144.x` requirement but one is named by at
least one registry row; `GH-144.4` can be named by none, for a structural reason,
and `GH-144.6` is named by none while two rows turn it red — so it is asserted by
no row but is not decoration.

## The order of evidence, written down so a later reader does not over-trust it

Three tiers, cheapest first: the text derivations read the file and see the
shapes someone thought of; the run-reading pair reads the run and sees every row
that executed; the five-state rotation experiment runs the whole suite under
`dev-05` alone, `dev-05` beside `dev-06`, `dev-06` alone, no dev ref, and `dev-09`
beside `dev-10`, and catches a rotted row whatever its spelling and whether or
not any derivation can see it. All five states: exit 0, 5197 results, 0 FAIL,
identical. The experiment is not a check in this suite because it needs ref
states these fixtures do not have.

## What the next session inherits

The production hook has survived five rounds with no defect found in it. What has
moved for three rounds is the suite's guarantee about itself. The stopping
criterion is now class coverage rather than a quiet round, and the classes and
their sweeps are recorded on the pull request.

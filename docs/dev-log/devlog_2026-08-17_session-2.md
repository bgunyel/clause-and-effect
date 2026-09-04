# 2026-08-17 · session 2

**Repositories worked in:** `clause-and-effect` (`dev-04`) — six commits,
`c96c210..HEAD`, pushed, no PR opened.
**State at close:** suite **298 passed / 5 xfailed**, up from 249 at the session's
start. Stage C built and tested; the full A→B→C chain runs over the eight probe
cases. Tree clean.

**Theme:** the session was meant to be *implement stage C, then test it*, and it
was — but the finding that outranks the code came from running the thing. **Stage
A is not stable at temperature 0, and the instability reaches the verdict.**
`gdpr_art8_case1` returned 1, 1, 2 and 1 core claims across four identical runs,
and with two core claims the case flips from `sufficient` to `insufficient`. Two
rounds of prompt work took the observed failures to zero and introduced a new one.

---

## Stage C, and the decision that was made on evidence rather than taste

`sufficiency/stage_c.py` labels each core claim `supported` / `absent` /
`contradicted` against stage B's blind answer, and **produces no verdict** —
§7's derivation is deterministic and separate.

Bertan settled the §10.7 question the design document had carried since
2026-08-10: **core claims only.** The argument that decided it was not cost. Stage
B is instructed to answer *"as fully as that text allows, and no further"*, so its
answer is scoped to the question; an auxiliary claim is by definition not what was
asked and comes back `absent` almost by construction. On `art8_case1` stage B
answered *"16 years old"*, against which both auxiliary claims are trivially
absent. Adjudicating them would measure how far the gold answer runs past the
**question** — which stage A already recorded when it tagged them — rather than
past its **evidence**, which is the quantity worth having and which no stage blind
to the quote can produce. The assistant had opened by recommending the opposite,
and withdrew it when the `art8_case1` output was read.

Three further choices, each recorded in the module rather than only in the commit:
the `answer` alone and never the `note`, because the note is stage B's
self-assessment and adjudicating it judges what B *thought* rather than what it
*answered*; the regulation never named, as in stage B; and claims **numbered**,
with the mapping validated, because pairing verdicts by position silently
mislabels the third of three claims rather than failing.

`adjudicate` takes a `question: str` rather than a `TestCase`. The quote is not a
parameter of the stage at any point, which is a stronger guarantee than being
handed the case and declining to interpolate it.

## The guard on the text rather than the flag paid off on the first real run

Two inputs return without a model call: no claims, and no answer text. The second
guard keys on `answer.strip()` and deliberately **not** on `answered`, on the
grounds that a model taking the insufficiency escape while still writing an answer
has produced something judgeable.

That is exactly what stage B did on `gdpr_art2_case4` — `answered=False` with a
paragraph explaining that the excerpt does not settle the question. The text guard
let it through, and stage C, blind to the quote, returned `absent`: *"The ANSWER
states it does not specify whether GDPR applies."* Both of §7.2's routes to
`insufficient` agree on the case the whole design was built around.

## Stage A is not stable at temperature 0

Found by running the probe harness twice and noticing the core-claim counts
differed. `art8_case1`: **1, 1, 2, 1** core claims across four runs of a
byte-identical prompt. `art7_case4`: 3 claims one run, 2 the next.

Both divergences broke a constraint the prompt already stated, and in both **the
model's own `reason` field recorded the breach**. The run that tagged an extra
claim core explained it as *"IMPLIED BY the shortest sufficient answer but adds
specificity"* — where the test is *appears in*. The run that split `No.` off as
its own claim broke the polarity rule verbatim. `Claim.reason` was kept for
exactly this (design §4.3), and this is the first time it has done the job.

**Round 1 — the rules were sharpened.** 21 runs across five cases. `art8_case1`
went 6/6 to one core claim with an identical core set and zero implication-
justified tagging; `art15_case1` kept all ten enumeration items core, which was
the regression the sharpened AUXILIARY wording risked. But `art7_case4` still
split a bare `No.` in **2 of 6** runs.

**Round 2 — worked examples**, at Bertan's suggestion, on the reasoning that a
constraint stated twice and broken a third of the time is not fixed by stating it
a third time. Design §4.4 had made this conditional — *a synthetic example waits
until the output asks for one* — and the output had now asked.

**The first three-example set was a net regression, and how it failed is the
useful part.** `art7_case4`'s bare `No.` went to 0/6, and `art15_case1`
**collapsed from ten core claims to one**, on all three runs. Two of the three
examples had a single core claim *and* a first claim that was verbatim the
shortest sufficient answer, so the model generalised *"claim 1 = STEP 1's text"* —
correct when STEP 1 is one sentence, catastrophic when it is a whole enumerated
answer. The third example contradicted it and was outvoted. The assistant had
named shape-copying as the risk and varied the claim counts to mitigate it; the
mitigation was too weak, because the thing being copied was not the count.

**Four examples**, ordered 4 / 2 / 1 / 1 core claims with the counts stated in the
prompt's own lead-in, plus a rule that splitting does not depend on STEP 1's
length, plus a new example whose first claim is deliberately not STEP 1's text.
Bertan asked for the three-month example to be kept rather than swapped out, which
is why there are four rather than three. Both hunted failures are now at zero.

Full before/after table at `docs/design/sufficiency-judge.md` §4.6.

## What is still wrong, stated so a green column is not read as a clean result

**Sentence-fragment claims are a new failure mode the examples introduced.** One
`art15_case1` run returned `"the personal data itself"` and `"and information
including: the purposes of processing"`; one `art41_case3` run returned `"and may
be renewed on the same conditions, provided…"` **and tagged it core**, which is
why that case is the one thing now worse than when the session started. These
break a rule already in the prompt. Example 2 models the correct behaviour
explicitly — both its core claims repeat the full subject — and the model
fragmented anyway, so the fix is a rule and not a fifth example. **Not applied.**

**Three prompt revisions have been tuned against the same six cases**, and small-N
differences are being read as signal. Some of what looks fixed is fitted.
`art41_case3`'s "three different shapes in three runs" is one observation, not a
rate. The next measurement needs cases *not* used for tuning.

**Only `art7_case3`'s expected output rests on a ruling of Bertan's.** The other
five columns are the assistant's classification, and `art7_case4` is the one that
matters: round 1 demoted *"The data processed while consent was still valid
remains lawfully processed"* from core to auxiliary, and the 6/6 result is scored
against that reading. Read as core, the current prompt scores 0/6 there.

**`art8_case5` returned `contradicted` and it is probably a false positive.** The
claim *"it specifically applies to information society services offered directly
to a child"* is compatible with the answer's *"does not apply to preventive or
counselling services offered directly to a child"* — a rule with an exception.
`contradicted` is the most expensive label to get wrong, since it implicates the
gold answer and not only the quote.

## The tests, and one thing they found in the source

49 tests over the three stages, 36 mutations, no survivors. Stage C's 18 cover the
blinding (stage B's span and note must not reach it — the span is a verbatim slice
of the quote), matching by claim number rather than position, the four ways the
mapping can fail, and the two no-call paths.

`art15_case1` also showed the judge producing **repairs and not only verdicts**:
ten core claims, 8 supported, 2 absent, and both absences are real defects —
*"confirmation of processing"* asserted by the gold answer and missing from the
quote, and *"restriction/objection"* cut off by the quote's own `...`. That is the
elision problem (§10.2) surfacing as a sufficiency finding rather than a
formatting one.

---

## Verification

- Suite **249 → 298 passed**, 5 xfailed, green at every one of the six commits;
  the intermediate commits were checked out and run rather than assumed.
- 36 mutations injected one at a time and reverted, **no survivors**; the source
  tree was confirmed clean after each sweep.
- The label-order assertion was re-verified after being changed to `rindex`, by
  re-running the field-swap mutation against it.
- 45 stage A calls across six cases produced the §4.6 table; three full 8-case
  probe runs exercised the A→B→C chain end to end.
- Both stage C no-call paths were exercised against real data, not only in tests.

## Mistakes made this session

All the assistant's unless stated.

- **The first example set was a net regression that reached the working tree.**
  Shape-copying was named as the risk and mitigated by varying claim counts, but
  the copied pattern was *"claim 1 = the shortest sufficient answer"*, which the
  mitigation did not touch. Caught by measuring rather than by review.
- **The opening recommendation on stage C's scope was wrong**, and was withdrawn
  on reading the `art8_case1` output that showed auxiliary adjudication is nearly
  information-free.
- **`art8_case1`'s run count was reported as three when it was four.**
- **The results table was presented in a notation nobody could read** — a
  different convention per row, three different values of N, and a different
  meaning of "correct" per case. Bertan had to ask for it to be explained before
  it could be discussed. For an eval instrument the presentation of a measurement
  is part of the measurement.
- **"Correct output" was tabulated for six cases without flagging that five of the
  six standards were the assistant's own**, until Bertan's yes/no question forced
  the distinction. `art7_case4`'s 6/6 depends entirely on it.
- Two syntax slips in the stage C test file as first written, caught immediately
  by running it.

## State handed to the next session

| | |
|---|---|
| `clause-and-effect` | `dev-04`, six commits pushed, tree clean, no PR open |
| Suite | **298 passed / 5 xfailed** |
| Judge | stages A, B, C built and tested; verdict derivation, panel, calibration **not built** |
| Stage A prompt | two sharpened rules + four worked examples; residue unfixed |
| Gate | untouched this session; `make verify` last green at `3dc7a33` |

## Open items — start here next session

| # | open item | state |
|---|---|---|
| 1 | **The atomicity rule for stage A** — stops sentence-fragment claims; drafted in the log above, not applied | one edit, then re-measure the same six |
| 2 | **Measure on cases not used for tuning** — ~20 stratified across `answer_type`, 3 runs each, ~60 calls | the honest test of whether any of §4.6 generalises |
| 3 | **Verdict derivation (§7)** — deterministic, no model call; the `sufficient_verbose` threshold must be *measured* from the span/quote distribution | unblocked now stage C exists |
| 4 | `art8_case5`'s `contradicted` — probable false positive on an elided quote | unresolved |
| 5 | Whether `art7_case4`'s third sentence is core or auxiliary — Bertan's call, and it scores the prompt | undecided |
| 6 | The panel (§8) and calibration (§9) — non-unanimity is now demonstrated, not hypothesised | not started |
| 7 | `judge.py` prints rather than logs — pre-existing, extended this session | deliberate, flagged, not fixed |
| 8 | Everything on the 2026-08-17 session 1 list — the gate's detection side, the three GuardDog defects, the rest | untouched |
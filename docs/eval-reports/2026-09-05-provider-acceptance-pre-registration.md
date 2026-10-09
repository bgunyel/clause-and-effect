# Provider acceptance — pre-registration

> **This entry is a commitment, not a result.** Every number below was fixed
> *before* the data existed, and none of them is a measurement. The rest of
> `docs/eval-reports/` records what the numbers were at a point in time; this
> one records what the numbers will be *judged against*, written while the log
> holds **zero provider-attributed rows**. A reader who takes the 10% below for
> an observed failure rate has read it backwards.

| | |
|---|---|
| registered | 2026-09-05 |
| branch | `dev-05` |
| commit at registration | `3c936c3f9418` |
| decided in | [#7 — The acceptance set, and how many observations a cell needs](https://github.com/bgunyel/clause-and-effect/issues/7) |
| written by | [#19](https://github.com/bgunyel/clause-and-effect/issues/19), under map [#6](https://github.com/bgunyel/clause-and-effect/issues/6) |
| subject | which `(model, channel, provider)` cells may be pinned, and on what evidence |
| status of the data | none — `record_attempt` has no caller in `src/`, so `llm_attempt` has never held a row |

**Why this is registered rather than reported.** Pre-registration means the bar
is fixed by someone who has not seen the data. The map that decided it has no
data by construction; the agent that will run the acquisition would be choosing
its own bar. The freeze is verifiable rather than merely stated:
`llm_run.commit_sha` is non-nullable, so the commit that carries this file can be
ordered against the commit that produced any acquisition row.

---

## 1. The tolerance, and the condition it hangs on

**Tolerance: 10%**, registered as a **conditional**:

> **10% if the judge runner ships with a `PanelistFailure` slot and an
> `expected_panel_size`; otherwise 5%.**

The condition **currently fails**, and it is registered as a conditional for that
reason rather than as an aspiration. 10% holds only while a structure failure
stays loud *at the point of use* — a missing vote, visible and re-runnable, not a
wrong answer. Today `Verdict` has no failure member, `PanelistRun`'s fields are
all non-optional so a structurally-failed panelist cannot be constructed,
`CaseJudgement.unanimous` is computed over survivors with no record of how many
there should have been, and **`all([])` is `True`** — a case nobody judged reports
as the strongest possible result. Under those types the loss is silent, and the
expensive bar applies.

The tolerance is a **bound, not an expectation**. A cell clears it on 0/29 with a
point estimate of zero. What is accepted is the inability to rule out 10%, not
10% failures.

The panel result types themselves are **out of scope** for the effort that
registered this — they land in `src/eval/` and belong to the judge runner. The
dependency runs the other way and is recorded here rather than dropped: whoever
reads a verdict against this entry must first establish which branch of the
conditional was in force at acquisition time.

## 2. n, and the two bars

One tolerance, read from both ends (Clopper-Pearson, 95% one-sided):

| n | 0 failures → upper bound | all failures → lower bound |
|---:|---:|---:|
| 2 | 77.6% | **22.4%** |
| 4 | 52.7% | 47.3% |
| 6 | **39.3%** | 60.7% |
| **29** | **9.8%** | 90.2% |
| 59 | 5.0% | 95.0% |

- **Rule-in:** upper bound below tolerance → **n = 29 clean observations**.
- **Rule-out:** lower bound above tolerance → **2 consecutive failures**.

The asymmetry is not imposed on auditability grounds; it falls out of the same
bound read from opposite ends. It happens to fit the auditability argument —
false rule-ins are silent, false rule-outs announce themselves — which is why it
was accepted rather than corrected.

Two consequences worth registering now, so neither is discovered later as a
surprise: the old `structured_output` table's n=6 carries a 39.3% upper bound,
which is the number saying why 6 licensed nothing; and Parasail's 4/4 gives 47.3%
and rules out on evidence already in hand.

**Forced and organic observations do not pool.** 20 forced plus 6 organic is not
n=26. A measurement pin and organic routing sample different conditions, so a
cell's n is counted within a regime, never across.

## 3. The six pre-registration rules

Verbatim as registered. Each names the leak it closes; a rule without a named
leak is decoration.

**Scope — fixed before any acquisition call**

- **R1.** The candidate set — the `(model, channel, provider)` cells that will
  receive a rule-in test — is recorded before the first acquisition call.
  *Closes:* picking candidates after seeing which cells look good, i.e. the
  ~30-cell multiplicity re-entering as cherry-picking. It is also what makes
  "only test genuine pin candidates" a multiplicity control rather than a
  selection effect.
- **R2.** Each candidate's rule-in n is declared before that cell's first call.
  *Closes:* setting n once early rows are visible.

**Timing — one analysis per cell**

- **R3.** Rule-in is evaluated exactly once, at the declared n. A bound that
  clears at n=20 is not a pass. *Closes:* stopping on good news.
- **R4.** A cell that fails rule-in at its declared n is failed, and is not
  extended. *Closes:* extending on bad news. R3's mirror, and the likelier of the
  two, because "we just need a few more observations" is a comfortable thing to
  say and "we got lucky, stop now" is not.

**Finality**

- **R5.** Rule-out peeks are unrestricted, but each rule-out is recorded with the
  n and the bound at which it was taken. *Closes:* a cell quietly dropped and
  later described as unmeasured.
- **R6.** Re-testing a failed cell requires a cause external to the log — a
  config, model, or provider change — recorded before the new acquisition, with
  the prior result left standing. *Closes:* R4 evaded by relabelling.

Peeking is **free for rule-out and forbidden for rule-in**, grounded on
revisability: a rule-out self-corrects in rotation, a pin self-seals.

### R4's anticipated pressure point

Named here so it is anticipated rather than discovered. Under the **k>1**
reframing — where the pin becomes an *acceptable set*
`{only: [X, Y], allow_fallbacks: True}` and membership is the rule-in test — a
member failing rule-in shrinks the set, and a set that is too small no longer buys
refusal headroom. The tempting move at that moment is to un-fail the marginal
member rather than accept a smaller k. That is R4 evaded under a new name. **The
registered position: accept the smaller k, or accept no pin.** Every member clears
rule-in individually; k is chosen purely to buy refusal headroom, never to rescue
a member.

## 4. The registered draw

Frozen in [#7](https://github.com/bgunyel/clause-and-effect/issues/7)'s
resolution comment, before any provider observation existed. Reproduced and
verified against the corpus while writing this entry — population, method and
digest all agree.

```
population: 433 (src.eval.dataset.load_tier1)
seed:       20260905
method:     random.Random(20260905).sample(sorted(case_ids), 29)
sha256:     26cdec8e9ab8a5b3bfa15f76a88d136516066acc548a971bb402e07019638d84
            (of the newline-joined, sorted draw)
```

```
gdpr_art6_case2    gdpr_art6_case4    gdpr_art10_case4   gdpr_art13_case6
gdpr_art13_case8   gdpr_art15_case2   gdpr_art17_case5   gdpr_art20_case2
gdpr_art23_case1   gdpr_art27_case4   gdpr_art32_case1   gdpr_art33_case2
gdpr_art33_case5   gdpr_art34_case1   gdpr_art39_case2   gdpr_art41_case1
gdpr_art42_case4   gdpr_art58_case3   gdpr_art60_case5   gdpr_art66_case5
gdpr_art69_case1   gdpr_art69_case2   gdpr_art78_case2   gdpr_art80_case2
gdpr_art81_case1   gdpr_art84_case3   gdpr_art86_case3   gdpr_art92_case2
gdpr_art93_case2
```

**Drawn once and shared across every candidate cell**, making the campaign a
paired design: provider comparisons are within-case, so difficulty is eliminated
as a between-provider confound rather than merely spanned. Within a cell there are
still 29 distinct prompts.

**Simple random, not stratified** — a stratified allocation would need
post-stratification reweighting before its bound could be compared to a tolerance
defined on the production distribution.

**Not the 8-case probe corpus.** Repeats of 8 quotes are clustered observations
with high intra-cluster correlation; a Clopper-Pearson bound computed on n=29 from
8 prompts is not conservative but **optimistic**, certifying at 10% a cell whose
honest bound is the 0/8 one. Both routes cost 29 calls.

**Difficulty is defined operationally, before the draw, as quote token count** —
mechanism-plausible, since longer quotes produce the timeouts and truncation, and
computable from the corpus without running anything. This is the difficulty
variable for the pooled failure-rate-against-difficulty read; it is fixed here so
it cannot be chosen later to suit a gradient.

## 5. R1's candidate rule, as a rule and not a list

R1 is satisfied by a **deterministic rule**, because `served_provider` has never
been written and there are no rows to enumerate a list from:

> **The candidate set is every provider OpenRouter lists for model M as of the
> acquisition commit**, as returned by `/api/v1/models/.../endpoints`.

Registered **before the acquisition commit** so that `llm_run.commit_sha` orders
this file against the rows it judges. A rule evaluated at a recorded commit is
reproducible from the commit alone; a list written after the first call is not
distinguishable from a list chosen to fit.

## 6. The invariant ordering, which runs before any reproduction

Attribution being **broken** and attribution being **right but disagreeing** are
both live hypotheses. They are separated by check, in this order, and not by
judgement.

1. **Ground truth — a planted measurement pin.** A measurement pin sends
   `{'only': [X], 'allow_fallbacks': False, 'require_parameters': True}`, so
   `llm_call.requested_provider` **is** ground truth for what should have served.
   Compare it against `llm_attempt.served_provider`. Disagreement means
   attribution is broken, full stop, with no reference to MiniMax. This check
   leads **on ground truth, not on independence**: two independent sources can
   agree on a wrong answer; ground truth cannot.
2. **Independent corroboration — the routing chain's terminal element.**
   `served_provider` must equal the last element of that same attempt's
   `routing_chain` (`Parasail:429 -> Venice:200` → Venice).

The two checks cross different seams, which is what makes the ordering meaningful:
check 1 crosses **recorder → socket** (both phase 1 — `served_provider` is written
by the socket from the response body immediately, not filled by enrichment), and
check 2 crosses **socket → generation endpoint**, a genuinely different source
rather than a re-parse of the same one.

**The reproduction is attempted only after both pass.** A reproduction that fails
after the invariants pass then has one surviving explanation by elimination,
rather than by argument.

## 7. The expected reproduction — rank and direction only

The gate is a **positive control**: the log must reproduce the 2026-08-25 MiniMax
finding from its own rows. It is necessarily **prospective**, since there are no
provider-attributed rows to reproduce it from today.

**Registered expected output, before it runs:**

> For `minimax/minimax-m3`, the structure-failure rate on **Parasail** is worse
> than on **Venice** and on **CoreWeave**.

**Agreement is required in rank and direction only, never in equality of rates.**
The 2026-08-25 finding rests on its own limited n, so this validates an instrument
against a reference of unknown accuracy. Demanding numeric agreement is how a
working log gets debugged until it confirms an artifact.

**The acquisition must be unpinned.** Reproducing "failures on Parasail, successes
on Venice and CoreWeave" needs traffic across all three, which means organic
routing; a measurement pin changes the condition and it is no longer the same
finding.

**Scope of what a pass buys.** The reproduction exercises the attempt → provider →
status join, so it validates the pin query and the provider-variance query well.
It is **silent** on the others, and specifically on the bypass count: a bypassed
call is missing from the original finding and from the reproduction identically,
so agreement there proves nothing.

## 8. What each outcome means, registered in advance

| outcome | registered meaning |
|---|---|
| Invariants fail | **Attribution is broken.** The reproduction is not attempted, and nothing is concluded about any provider. |
| Invariants pass, reproduction agrees in rank and direction | The log resolves provider attribution well enough for the pin query. Nothing is concluded about the bypass count, cost reconciliation, joint refusal, or difficulty. |
| Invariants pass, reproduction disagrees | **"The 2026-08-25 finding does not reproduce at n=X."** An appended finding, recorded as it stands. It is **not** a licence to keep debugging until the log agrees. |
| Parasail never appears in the acquisition | **Not run** — an outcome distinct from *failed*. The control neither passes nor fails, because organic routing never created the condition. |

**"Not run" is registered as a first-class outcome** precisely because the unpinned
acquisition is exposed to the router's skew, and the alternative — a control
quietly counted as a pass, or quietly retried until Parasail shows up — is the
failure mode this table exists to close.

*Not registered here:* how many calls precede a "not run" declaration. It cannot be
phrased sharply until the attempt writer exists and the router's skew is
observable, and it is recorded as open on map
[#6](https://github.com/bgunyel/clause-and-effect/issues/6) rather than guessed at
now. A number invented here would be a number invented without the mechanism.

## 9. The second conditional — the sampled cross-check

> **If the build takes the phase-1 chain route** — reading `routing_chain` from the
> completions body behind `X-OpenRouter-Metadata: enabled` rather than from the
> enrichment sweep — **then a sampled cross-check applies**: a fraction of organic
> attempts is enriched from the generation endpoint and its chain is asserted to
> match the header-derived one, with disagreements recorded in a form that can be
> inspected rather than only counted.

Both branches are bound in advance. Under the two-phase route, the joint-refusal
read has `served_provider` as an independent check on the chain; under the phase-1
route both come from the same source, and the sampled cross-check is what restores
the independence. Registering both branches now is stronger than waiting for the
fork and then picking a number — the same reasoning that made the tolerance a
conditional in §1.

---

## The two kinds of append

This entry grows by **dated appends**, of two kinds — **amendments** and
**registrations**. The two rules below govern both, and are stated once here
rather than inside either section.

**Timing.** Both kinds are appended **before the numbers they govern are looked
at**. An append written after the data is read is neither an amendment nor a
registration; it is a result, and it belongs in a report of its own that says so.

**Which kind.** If an append changes what an already-written sentence would have
meant, it is an **amendment** regardless of what it is labelled, and it owes an
old value. An append that owes no old value is a **registration**: it fixes the
decision rule for a measurement that had none, and nothing above it changes.

The dichotomy is exhaustive, and that is the second rule's claim rather than an
accident of what exists today. The guard is written **here** rather than inside
`## Registrations` for the reason `## Amendments` gives below — append-only stops
history being edited but not a later append quietly restating a threshold at a
friendlier value, and *"registration"* is the friendlier of the two labels, so it
is the one such an append would hide behind. A classification rule placed inside
one of the two classes is only ever read by someone who has already chosen that
class.

## Amendments

**Amendments are dated appends.** Append-only prevents history being edited; it
does not prevent a later append quietly restating a threshold at a friendlier
value. So:

- An amendment names **the old value, the new value, and the reason**.
- An amendment is appended before the numbers it governs are looked at. That
  timing rule is shared with registrations and is stated once, in
  [§The two kinds of append](#the-two-kinds-of-append), together with the guard
  that decides which kind an append is.
- The two conditionals in §1 and §9 resolve by *observing which branch holds*,
  which is not an amendment and needs no entry here.

*No amendments.*

## Registrations

**A registration has no old value**, so it cannot be formed as an amendment: it
fixes the decision rule for a measurement that had none, and nothing above it
changes. Both rules in [§The two kinds of append](#the-two-kinds-of-append)
apply — the timing rule, and the guard that stops this section becoming the place
a restated threshold goes to avoid owing an old value.

Registrations are **appended in full at the end of this entry**, in append order,
each under its own dated header table. This section is the index.

| # | registered | registration | decided in |
|---|---|---|---|
| 1 | 2026-09-05 | [Registration — the header A/B, and what the design may claim about non-distortion](#registration--the-header-ab-and-what-the-design-may-claim-about-non-distortion) | [#14](https://github.com/bgunyel/clause-and-effect/issues/14) |
| 2 | 2026-09-05 | [Registration — the candidate pool, its denominator, and what R1 freezes](#registration--the-candidate-pool-its-denominator-and-what-r1-freezes) | [#20](https://github.com/bgunyel/clause-and-effect/issues/20) |

**Appending a registration adds a row to the table above it**, which is an edit
to text that precedes the append. It is permitted and it is not an amendment, by
the guard's own test: an index row changes what no already-written sentence would
have meant. Said explicitly, because the next author will otherwise stop here.

---

**Verified against:** the draw was reproduced at registration time from
`src.eval.dataset.load_tier1` — population 433,
`random.Random(20260905).sample(sorted(case_ids), 29)`, sha256 of the
newline-joined sorted draw equal to the digest frozen in
[#7](https://github.com/bgunyel/clause-and-effect/issues/7), and the 29 ids
transcribed above identical to the recomputed set. Nothing else in this file is a
measurement: there is no data yet, which is the point.

---

# Registration — the header A/B, and what the design may claim about non-distortion

| | |
|---|---|
| registered | 2026-09-05 |
| branch | `dev-05` |
| commit at registration | `3c936c3f9418` |
| decided in | [#14 — Whether the socket patch mutates the request](https://github.com/bgunyel/clause-and-effect/issues/14) |
| run under | [#22](https://github.com/bgunyel/clause-and-effect/issues/22), under map [#6](https://github.com/bgunyel/clause-and-effect/issues/6) |
| subject | what `docs/design/llm-call-log.md` is permitted to assert about `X-OpenRouter-Metadata: enabled` not distorting the request |
| status of the data | none — written before the first A/B call |

**This is a registration, not an amendment.** It has no old value. Nothing above
it changes: §1's conditional tolerance, §2's two bars, R1–R6, the frozen draw,
the invariant ordering and §8's outcome table all stand exactly as registered,
and the *Amendments* section still reads *no amendments*. What follows fixes the
decision rule for a measurement that had none. Dressing a new registration as an
amendment would imply something was changed and send a reader hunting for what.

**Why it is appended here rather than opened as its own document.** The header
determines whether `openrouter_metadata.endpoints` exists at all; `available` is
the pool [#20](https://github.com/bgunyel/clause-and-effect/issues/20) must pick
a denominator out of; that denominator is the denominator of the per-provider
acceptance rate, which is §2's subject. The commitment sits upstream of this
document's subject, not beside it. Splitting it out would oblige a future reader
to know both documents exist.

**Why it is registered at all.** #14 decided to send the header and registered
that decision as **reversible**; the design writes its non-distortion claim
*conditionally* until this run reports. An unrun measurement is not an
outstanding decision — but an unwritten rule is, and a rule written at the
keyboard with the numbers already in hand is the failure R1–R6 exist to
legislate against.

## A.1 What is under test, and what is not

**Distortion, not coverage.** #14 separated two objections that had been argued
as one. #11's stripped-on-cache-hit, absent-on-5xx and absent-on-auth-failure
behaviours are **coverage**: they fail benign, they cost rows and never corrupt
one. **Distortion** — the header changing what the request receives — has no
proposed mechanism, and a claim with no mechanism and no measurement is the kind
this document exists to stop being made. Only distortion is measured here.

Also not under test, and stated so it is not later read in: the purity of the
request. Every OpenRouter request this project sends already carries
`http-referer: https://docs.langchain.com` and `x-title: LangChain`, set by
`langchain_openrouter`'s defaults on traffic nobody chose to shape
([#25](https://github.com/bgunyel/clause-and-effect/issues/25)). The question is
which shaping is deliberate, never whether shaping begins here.

## A.2 The arms, and the request shape held fixed across them

- **Alternating header-on / header-off**, strictly adjacent in time, one process,
  sequential. Adjacency is what makes the pair a pair: it holds the router's
  state, the region and the hour fixed by construction rather than by argument.
  **The leading arm alternates between pairs** — on/off, then off/on — so that
  neither arm is systematically the warmer or the colder call of its pair. Order
  would otherwise be confounded with the treatment on the latency endpoint, which
  is the one endpoint sensitive to it.
- **One fixed request shape, and it is the judge's own** —
  `build_structured_llm` on `ModelNames.DEEPSEEK_V_4_FLASH_0731` under
  `FUNCTION_CALLING`, with `model_args` exactly as `llm_config` sets them, so
  `provider: {'require_parameters': True}` and a bound tool both reach the wire.
  That is the **23-endpoint** pool, not the 29 ([#13](https://github.com/bgunyel/clause-and-effect/issues/13)).
  The pool is request-shaped, so a request shape that varies between arms
  confounds the very thing being compared.
- **The two arms differ only in the presence of one request header.** The probe
  asserts the two arms' request *bodies* are byte-identical and aborts the run if
  they are not; a body difference would make the comparison a comparison of
  something else.
- **Switching models to buy variance is registered as forbidden.** A model whose
  pool actually splits would upgrade the categorical endpoint from a flip test to
  a share test — but it would test the header somewhere the judge does not run.
  #13's stated limit is already one model, one provider, one region, one day, and
  chasing variance changes the subject rather than widening it.
- **A wiring smoke run of at most 5 pairs precedes the measurement**, and its
  observations are **discarded and never pooled** with the run. Registered in
  advance so that it cannot later be mistaken for a peek, nor the run for a
  continuation of it.

## A.3 n, declared before the first call

> **n = 300 pairs (600 calls), evaluated exactly once, at 300.**

300 is chosen for the bound it buys and for nothing else: 0 flips out of 300
gives a one-sided 95% Clopper–Pearson upper bound of
`1 − 0.05^(1/300) = 0.99%`, so a clean run licenses a **sub-1%** statement.
The instrument is §2's instrument deliberately — one scale across this document,
not a second convention introduced for a second question.

R3's discipline applies, though this is not a rule-in test: **no interim
analysis, and a result that looks settled at 100 pairs is not a result.** A pair
in which *either* arm returns a non-200, times out, or fails structurally is
dropped **as a pair**, and the number of dropped pairs is reported. Dropping by
pair rather than by call, and registering it now, is what stops the drop rule
being chosen later to suit the residue.

## A.4 The three endpoints, and only one of them is degenerate

**Primary, categorical — the selected provider.** Full power against the failure
that actually matters: the header steering selection to a *different* provider
shows up as a flip, loudly, at small n. **No power at all against a subtle
reweighting**, because a baseline that is 100% one provider has no share to
shift. The statistic is the count of pairs whose header-arm selected provider
differs from its baseline-arm selected provider, read as a Clopper–Pearson bound
at the achieved n.

**Secondary, continuous — powered by n however routing lands.** #13 measured all
three at n=3 and found nothing; this run is what turns *"no penalty observed"*
into a bounded interval.

- **Prompt-side cost: registered as exact equality, to all digits.** #13 observed
  it identical across all six of its calls, so a difference is a finding rather
  than noise. Any pair whose prompt-side cost differs is reported individually
  and is never averaged away.
- **`cached_tokens`: a per-arm distribution plus a paired-equality count.** Cache
  eligibility is the mechanism by which a header could plausibly cost money
  without costing latency.
- **Wire latency: the paired difference, header minus baseline, with an
  equivalence margin fixed here at ±10% of the baseline arm's mean.** The design
  may assert *no latency penalty* only if the 95% confidence interval of the mean
  paired difference lies inside that margin. Latency is taken at the socket,
  around `httpx`'s `send`, which is the last point the request is ours.

Registering the margin before the run is the whole point: without it, an interval
of any width gets read as a pass, and #13's n=3 null gets promoted to a bound it
never earned.

## A.5 "Degenerate" is a registered outcome, distinct from "no shift"

A degenerate baseline is **likely**: #13 saw Baidu 6/6, and #7's MiniMax finding
was CoreWeave ×6.

> **An arm is degenerate when a single provider holds every one of its
> observations.** If both arms come back degenerate on the same provider, the
> registered reading is **"no categorical flip detected at the achieved n;
> reweighting untested"** — never *"no effect"*.

Registered as a distinct outcome for exactly the reason §8 registers *not run* as
distinct from *failed*. Without it written down in advance, this run gets cited
six months from now as having cleared the header generally, which it will not
have done.

## A.6 The vocabulary check, repeated against a live pool

#14 §4 checked that the top-level `provider`, `endpoints.available[selected].provider`
and the `selected=` clause of `openrouter_metadata.summary` spell an endpoint the
same way — because switching primary source part-way through accumulation would
silently re-key `served_provider` under trap 9, splitting one provider into two
under `GROUP BY served_provider`. That is the failure class `CLAUDE.md` forbids
for chunk ids, reached through a different door. They agreed, at **n=3, one
provider, one model**.

> **Registered assertion, on every header-arm response of this run:** the three
> spellings agree. **Any disagreement blocks the first production row**, and is
> reported with the responses that produced it rather than as a count.

**Agreement under a degenerate run does not retire the check.** It remains
bounded at one provider and defers to the first genuinely multi-provider
observation. Registered so that a clean single-provider result is not filed as
the settled fact #14 explicitly declined to call it.

## A.7 What each outcome licenses the design to assert

| outcome | what `docs/design/llm-call-log.md` may then say |
|---|---|
| 0 flips, both arms degenerate on the same provider | *"No categorical flip observed at n pairs; one-sided 95% upper bound on a header-induced provider flip of `1 − 0.05^(1/n)`. Reweighting is untested, the pool having never exercised a second provider."* The claim stays qualified. It is **not** *"the header does not affect routing"*. |
| 0 flips, ≥2 providers observed in both arms | The categorical claim above, **plus** a share comparison at the achieved n. Non-distortion may be asserted as categorical *and* reweighting-tested, with the share test's power stated alongside it. |
| ≥1 flip | **The header distorts routing.** #14's decision is reversed on the reversibility it registered, and the design's conditional claim resolves to the negative branch. |
| Prompt-side cost differs on any pair | A distortion finding independent of routing, reported with the offending pairs. It stands whatever the categorical endpoint did. |
| Latency CI not contained in ±10% | **"Inconclusive on latency at the achieved n."** Not a penalty, and not a pass. |
| Fewer than 300 usable pairs | **"Not run at the registered n."** The bound is recomputed at the achieved n and labelled as such; the registered n is not quietly restated to match what the run produced. |
| Any vocabulary disagreement | The precedence constant in #14 is not yet safe to fix, and no production row may be written until it is. |

## A.8 What this registration does not cover

- **The coverage behaviours** (#11) — stripped on cache hits, absent on 5xx and
  on auth failures. Unchanged, not measured here, and not touched by any outcome
  above.
- **The multi-attempt shape.** #13 saw `attempt: 1` throughout, so no fallback has
  ever been observed. If none occurs during this run, that stays true and is
  reported as still-unobserved rather than as absent.
- **§1's tolerance, §2's bars, and the draw.** Nothing here bears on them.

**Written before the run**, with zero A/B observations in hand. The freeze is
verifiable the same way the rest of this document's is: this file is carried by a
commit that can be ordered against the commit that produced any A/B row.

---

# Registration — the candidate pool, its denominator, and what R1 freezes

| | |
|---|---|
| registered | 2026-09-05 |
| branch | `dev-05` |
| commit at registration | `3c936c3f9418` |
| decided in | [#20 — The candidate pool is request-shaped, so what denominator does a per-provider rate have](https://github.com/bgunyel/clause-and-effect/issues/20) |
| written by | [#28](https://github.com/bgunyel/clause-and-effect/issues/28), under map [#6](https://github.com/bgunyel/clause-and-effect/issues/6) |
| subject | what a per-provider acceptance rate's denominator is, now that the candidate pool is known to be request-shaped |
| status of the data | none — written before the first acquisition call |

**This is a registration, not an amendment**, under the guard in [§The two kinds
of append](#the-two-kinds-of-append). It has no old value: nothing above ever
said that a cell with no observations reads `0/n`, so the thing that looked like
an old value was an inference about an unstated default. §1's conditional
tolerance, §2's two bars, R1–R6, the frozen draw, the invariant ordering and §8's
outcome table all stand exactly as registered, and *Amendments* still reads *No
amendments.*

**R-a, R-b and R-c are registrations, not a continuation of R1–R6.** The
pre-registration rules are six and stay six, verbatim. These three fix how a
denominator is formed for the rates those rules judge; they add no rule to §3.

**Why it is appended here rather than opened as its own document.** The
denominator of a per-provider acceptance rate is §2's subject, and #20 found that
the pool supplying it is request-shaped. A commitment about how §2's denominator
is formed sits inside this document's subject, not beside it.

## R-a. The mechanism, never the ratio

> Binding a tool narrows the candidate pool below the catalogue's enumeration by
> a **model-specific** amount **not predictable from `supported_parameters`**.
> Measured 2026-09-05 on `deepseek/deepseek-v4-flash-0731` alone: 30 → 23
> endpoints, 29 → 22 distinct providers, while all 30 catalogue endpoints declare
> `tools` and `tool_choice`. **This figure is not transferable to another model.**

What is registered is the mechanism. The ratio is not, and per-attempt pool
storage ([#20](https://github.com/bgunyel/clause-and-effect/issues/20) §1) is what
makes registering it unnecessary: each cell's denominator comes from its own
observed pool, at acquisition time, for its own model and request shape. The
pools differ enormously — 29 providers for DeepSeek Flash, 15 for Kimi K3, 12 for
MiniMax M3, 2 for Grok 4.6 — so a reader applying 22-of-29 to Grok would be
reasoning from a number that was never about their model.

## R-b. `NOT_IN_POOL` is a denominator of zero, not a category

> Each cell's denominator is the number of calls in which its provider appeared
> in the pool. A cell present in *some* pools and not others is **not**
> `NOT_IN_POOL`; it is a cell with a smaller effective n. `NOT_IN_POOL` is the
> degenerate case where the denominator is zero. A cell with denominator zero is
> reported **undefined, never `0/n`**.

The binary would have hidden the partial case, which is the commoner one.

## R-c. Named and testable are both reported, and the correction is over testable

> The candidate set stays at what R1 named — **29 providers for DeepSeek Flash,
> frozen**, and not §4's 29 cases, which is a coincidence of magnitude and
> nothing more. The multiplicity correction is taken over the **testable** cells
> — those with denominator > 0 — and the gap between named and testable is always
> shown.

The argument that makes the narrowing legitimate is registered here, before the
numbers, because after them it is indistinguishable from the thing R1 forbids:

> **Pool membership is observable without seeing any rate.** A cell drops out
> because its provider was never served, not because it looked bad — a provider
> absent from every pool has zero observations and so cannot have looked good or
> bad.

R1's registration is a record of *naming*. Letting the named set shrink on
observation is the narrowing R1 exists to forbid, which is why the named set
stays frozen and only the correction's denominator moves.

**Written before the first acquisition call**, with zero provider-attributed rows
in hand. The freeze is verifiable the same way the rest of this document's is:
this file is carried by a commit that can be ordered against the commit that
produced any acquisition row.

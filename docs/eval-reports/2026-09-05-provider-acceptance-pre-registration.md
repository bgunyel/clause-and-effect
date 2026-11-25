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

---

# Amendment — an acceptance rate's denominator is the calls its provider served, not pool exposure

| | |
|---|---|
| amended | 2026-11-17 |
| branch | `dev-06` |
| commit at amendment | `20a52ca2991f` |
| decided in | [#367 — R-b divides a served-call rate by pool exposure: the amendment it owes](https://github.com/bgunyel/clause-and-effect/issues/367) |
| written by | [#376](https://github.com/bgunyel/clause-and-effect/issues/376), under map [#6](https://github.com/bgunyel/clause-and-effect/issues/6) |
| amends | all of R-b, and the clause of R-c that defines *testable* |
| status of the data | none — written before the first acquisition call; `record_attempt` still has no caller in `src/`, so `llm_attempt` has never held a row |

**This is an amendment, not a registration**, under the guard in [§The two kinds
of append](#the-two-kinds-of-append). It changes what already-written sentences
mean, so it owes an old value, and the old value is given in full below. No
sentence of R-b keeps its meaning. *"`NOT_IN_POOL` is the degenerate case where
the denominator is zero"* and R-b's heading become false in the other direction:
`NOT_IN_POOL` still implies a zero denominator, but a zero denominator no longer
implies `NOT_IN_POOL`. So R-b is amended as one block and is not patched one
sentence at a time.

**What stands unamended.** §1, §2, R1–R6, §5, the frozen draw, the invariant
ordering, §8's outcome table, R-a, and every part of R-c except the clause quoted
below. R-c's named set stays frozen at what R1 named, and the gap between named
and testable is still always shown. This amendment moves only the quantity that
the correction is taken over.

## The old value

R-b, verbatim. Its heading is set in bold so that this quote does not create a
second anchor:

> **R-b. `NOT_IN_POOL` is a denominator of zero, not a category**
>
> > Each cell's denominator is the number of calls in which its provider appeared
> > in the pool. A cell present in *some* pools and not others is **not**
> > `NOT_IN_POOL`; it is a cell with a smaller effective n. `NOT_IN_POOL` is the
> > degenerate case where the denominator is zero. A cell with denominator zero is
> > reported **undefined, never `0/n`**.
>
> The binary would have hidden the partial case, which is the commoner one.

R-c's definition of *testable*, verbatim from inside its first quote:

> — those with denominator > 0 —

## The new value

**R-b, as amended. A cell's denominator is the calls its provider served.**

> Each cell's denominator is the number of calls its provider **served**. Every
> cell is reported as the triple **(exposure, served, clean)**: the calls whose
> pool offered its provider, the calls its provider served, and the served calls
> that were structure-clean. A zero denominator covers two different states, and
> each has a name:
>
> | state | exposure | served |
> |---|---:|---:|
> | `NOT_IN_POOL` | 0 | 0 |
> | `OFFERED_NOT_SERVED` | > 0 | 0 |
>
> A cell in either state is reported **undefined, never `0/n`**. A cell offered
> in some pools and not others is in neither state merely for that reason: its
> served count is its effective n, and that count is smaller.

Exposure is kept only to separate the two zero states. It is never a
denominator. The partial case that the old R-b protected survives in substance:
a cell offered in only some pools has a smaller served count, and the served
count is the effective n.

**R-c, as amended. *Testable* means served at least once.** The clause quoted
above now reads:

> — those served at least once —

The argument for that narrowing is registered here, before the numbers, because
after them it is indistinguishable from the thing R1 forbids:

> **Whether a provider served a call is observable without seeing any rate, for
> structure failures.** A structure failure reaches the router as an ordinary
> 200 response, so it cannot change what the router offers or picks next. A cell
> that was offered and never served has no observations, so it cannot have looked
> good or bad, and counting it in the correction loses power and gains no
> safety. **The argument does not hold for HTTP-level failures**, which can
> change what the router offers or picks next. The offered count has the same
> limit, so moving from offered to served does not weaken the argument.

R-c's own argument paragraph is not part of the old value, because none of its
sentences changes meaning. *"Pool membership is observable without seeing any
rate"* is still true. It is no longer the whole argument, and the paragraph
above adds what the served count needs. *"A cell drops out because its provider
was never served"* was not literally true under the old R-b, which dropped a
cell only when its provider was never offered. It is literally true now.

## The reason

[#20](https://github.com/bgunyel/clause-and-effect/issues/20) took pool exposure
as the denominator deliberately. It derived the denominator from its own ruling
of *"one exposure per provider per call"*, and it located the open question in
*"whether being offered twice is one exposure or two"*. Its argument for R-c,
though, spoke of serving: *"a cell drops out because its provider was never
served"*. That mixes a selection quantity with an acceptance rate.
[#31](https://github.com/bgunyel/clause-and-effect/issues/31) separated the two.
It showed that the acceptance rate is a **served-call rate**: §2 rules in on
*"n = 29 clean observations"*, and §7's positive control is a structure-failure
rate. Its numerator is structure-clean calls among the calls the provider served.
An exposure denominator dilutes that rate in the silent direction. In #31's
words, *"offered in 100 pools, served 3 times with no failures reads 0/100, a
false rule-in."*

So this is a **change of meaning, not of wording**. R-b said what it meant to
say, and what it meant was the wrong quantity.

**Not decided here.** What a served call is when no provider is attributed,
for example a timeout or a failure that carries no router metadata, belongs to
[#371 — Failures with no served provider: where a timeout lands in the
acceptance read](https://github.com/bgunyel/clause-and-effect/issues/371). When R-c's m
is fixed, now that the served-at-least-once count grows across the acquisition
window, belongs to [#377 — When is R-c's m fixed, if cells reach their declared
n at different times?](https://github.com/bgunyel/clause-and-effect/issues/377).

**Written before the first acquisition call**, with zero provider-attributed rows
in hand. The only per-provider traffic on record is
[#22](https://github.com/bgunyel/clause-and-effect/issues/22)'s header A/B, which
measured distortion, latency and cost and never computed a structure-failure
rate.

---

# Registration — a channel change makes new cells, and acquisition runs on the roster channel

| | |
|---|---|
| registered | 2026-11-17 |
| branch | `dev-06` |
| commit at registration | `20a52ca2991f` |
| decided in | [#32 — Is a provider pin specified per model, or per (model, channel)?](https://github.com/bgunyel/clause-and-effect/issues/32) |
| written by | [#370](https://github.com/bgunyel/clause-and-effect/issues/370), under map [#6](https://github.com/bgunyel/clause-and-effect/issues/6) |
| subject | which cells a channel change produces, and which channel an acquisition runs each model on |
| status of the data | none — written before the first acquisition call; `record_attempt` still has no caller in `src/`, so `llm_attempt` has never held a row |

**This is a registration, not an amendment**, under the guard in [§The two kinds
of append](#the-two-kinds-of-append). The guard is applied here, not just the
label, because R6 is the sentence an amendment would be changing. R6 permits
*"re-testing a failed cell"* after *"a config, model, or provider change"*, and a
channel switch is a config change. Read literally, that seems to let DeepSeek V4
Flash's failed `function_calling` cell be re-tested under `json_schema`. But what
R6 re-tests is a **cell**, and R1 says what a cell is: a `(model, channel,
provider)` triple, the same key this entry's subject line uses. Rows taken on
`json_schema` carry `json_schema` in `llm_call.channel`, so they belong to a
different triple. R6 never moves a row from one triple to another, so under no
reading do those rows re-test the `function_calling` cell. R6's cause list still
governs exactly what it did: when the **same** triple may be measured again.
What nothing above said is where the other rows go, and R-e says it. §1, §2,
R1–R6, §5, the frozen draw, the invariant ordering, §8's outcome table, R-a, and R-b and R-c as amended all stand.

**The trade, recorded.** The argument also applies to R6's *"model change"*. A
new model slug puts its rows in a different triple as well, which would leave
that clause naming a re-test it cannot reach. This registration decides the
channel only. Whether R6's model change means a change **behind** the same slug
(a true re-test) or a **new** slug (new cells) is held by [Does R6's model change
re-test the same cell, or make new cells as a channel change
does?](https://github.com/bgunyel/clause-and-effect/issues/378). That question
also has to be settled before the first acquisition call.

**Why now.** Once an acquisition row exists, applying this rule after a channel
switch cannot be told apart from relabelling to fit the result. Written before
any such row exists, it is a commitment.

**Labels.** R-d is reserved for [Append R-d: what the pin read reports when the
observed pools hold one provider](https://github.com/bgunyel/clause-and-effect/issues/368). 
A label is fixed when its ticket is decided, so the order of labels and the order in this file
can differ. The index records append order.

## R-e. A channel change makes new cells, not a re-test

> When a model's channel changes, acquisition on the new channel produces **new**
> `(model, channel, provider)` cells. Each needs its own R1 naming and its own R2
> n before its first call. It inherits nothing from the cells on the old channel,
> **in either direction**. A cell that failed on the old channel stays failed and
> is not re-tested by the new one. A pass on the new channel licenses a pin on
> the new channel only, and a pass on the old channel licenses nothing on the new
> one.

*Closes:* R4 evaded by relabelling, which is R6's own leak one level further
out. A channel selects a provider pool, and the pools are not nested.
[#27](https://github.com/bgunyel/clause-and-effect/issues/27) measured it: on
DeepSeek V4 Flash, `BaseTen` appeared twice in the `function_calling` pool and
not at all in the `json_schema` pool. A `json_schema` result reported under the
`function_calling` cell's name is a different pool's result under the same name.
It agrees with [#32](https://github.com/bgunyel/clause-and-effect/issues/32),
which makes a pin a property of the `(model, channel)` pair.

## R-f. Acquisition runs each model on its roster channel only

> Each model is acquired on its **roster channel** and on no other. The roster
> channel is the one `llm_config.structured_output` assigns the model at the
> acquisition commit. A cell takes its channel from **`llm_call.channel` on its
> own rows**, never from `llm_config`, whose assignment may have changed since.
> There are no cross-channel cells: one acquisition yields one channel per model.

The rule can be checked without seeing any rate. Among one acquisition's rows,
count the distinct `llm_call.channel` values for each model. More than one means
R-f was broken, and that is visible before any acceptance rate is computed.

R-f is also what turns R-e's channel change into a single, dated event: the
roster changes at a later commit, and the next acquisition runs on the new
roster channel only.

**§5 is unamended, and R-f is why it can stay so.** §5 names the candidate set
per model: *every provider OpenRouter lists for model M*. That is channel-blind
by design. Naming happens before any pool is seen, and the endpoints catalogue
§5 reads is listed per model, not per request shape. Whether a named provider is
**testable** is a fact about one cell, read from that cell's own rows under R-c,
and the rows carry their channel. Under the amendment above, R-c's test is served at least once. Under R-f each 
model has exactly one channel per acquisition, so each named `(model, provider)` 
matches exactly one `(model, roster channel, provider)` cell. R1's named set and R-c's testable set then count
the same cells. A provider the roster channel never routes to is named but not
testable, and it appears in the named-versus-testable gap that R-c already
requires to be shown. `BaseTen`, for DeepSeek Flash on `json_schema`, would be
one. Without R-f, a provider named once could be tested in two cells, and the
correction's m would count cells R1 never named.

**Written before the first acquisition call**, with zero provider-attributed rows
in hand. This file is carried by a commit, and that commit can be ordered
against the commit of any acquisition row, as with the rest of this document.

---

# Registration — when the observed pools hold one provider, a pin has no alternative

| | |
|---|---|
| registered | 2026-11-17 |
| branch | `dev-06` |
| commit at registration | `c774335625cb` |
| decided in | [#31 — A one-provider pool: what the acceptance read prints when the router never had a choice](https://github.com/bgunyel/clause-and-effect/issues/31) |
| written by | [#368](https://github.com/bgunyel/clause-and-effect/issues/368), under map [#6](https://github.com/bgunyel/clause-and-effect/issues/6) |
| subject | what the pin read and the acceptable-set read report for a cell whose observed pools hold one provider between them |
| status of the data | none — written before the first acquisition call; `record_attempt` still has no caller in `src/`, so `llm_attempt` has never held a row |

**This is a registration, not an amendment**, under the guard in [§The two kinds
of append](#the-two-kinds-of-append). The guard is applied here, not just the
label, because three passages above come close to the case and each was read for
whether it already says what R-d says:

- **R-b, as amended.** A cell's denominator is the calls its provider served. A
  provider that is the only one its pools ever offered still serves calls, so
  its cell is in neither zero state and the amended R-b already reports its rate
  normally. R-d's first clause says so explicitly and changes nothing R-b means.
  It is written because #31 was opened on the opposite premise, that such a rate
  is not identified, and the premise is the misreading this registration exists
  to prevent.
- **R-c, as amended.** *Testable* means served at least once, so the same cell
  is testable and is counted in the correction's m. R-d leaves that as it
  stands.
- **[R4's anticipated pressure point](#r4s-anticipated-pressure-point).** It says
  that k is chosen *"purely to buy refusal headroom"* and that a set too small
  *"no longer buys"* it, and its position is *"accept the smaller k, or accept no
  pin"*. It never says how large k can be. R-d puts an observed ceiling on k.
  Every sentence of that paragraph keeps its meaning, and at a ceiling of one
  the paragraph's own terms already imply that no headroom is bought.

Nothing registered or amended so far says what a pin read prints when the
router never offered an alternative, so R-d owes no old value. §1, §2, R1–R6,
§5, the frozen draw, the invariant ordering, §8's outcome table, R-a, R-b and
R-c as amended, and R-e and R-f all stand.

**Labels.** The label R-d was fixed when #31 was decided. Other registrations
may be appended before it, so the order of labels and the order in this file
can differ. The index records append order.

## R-d. One provider observed removes the pin's choice, not the acceptance rate

> The condition is read off the per-attempt rows and never off the model. It
> holds for a cell when **every pool observed on the cell's `(model, channel)`
> in the acquisition window holds the same one provider**, counting distinct
> providers and not endpoints. If a second provider appears in even one of those
> pools, the condition does not hold. When it holds:
>
> - The cell **stays in the acceptance set**, and its acceptance rate is
>   reported as any other cell's is.
> - The **pin read reports *no alternative observed*** and makes no
>   recommendation.
> - The **acceptable-set read reports `max k = 1`**, so the refusal headroom
>   that the k>1 reframing buys is zero.

**Why the rate stays.** The acceptance rate is a served-call rate. Its numerator
is the structure-clean calls among the calls the provider served, and a served
call can still fail. If the only provider serves 29 calls, those are 29 genuine
observations of its failure rate, and §2's bars apply to them unchanged. What a
one-provider pool takes away is the pin's choice, not the rate's identification.
If the cell fails rule-in, the remedy is a different model, because there is no
other provider to pin to.

**Why the pin read prints no recommendation.** A pin to the only provider the
router offered is a no-op: it constrains the router to what it was already
doing. A recommendation to pin would read as evidence that a choice was made,
and none was available to make.

**Why `max k` is observed and not assumed.** The acceptable-set read reports
`max k` as the number of distinct providers observed across the same pools, and
R-d registers the value it takes at one. A set cannot hold providers that were
never offered, so with one provider the k>1 reframing has nothing to buy. If
that provider fails rule-in, R4's registered position applies as written: accept
no pin.

**Why the rule is keyed on pools.** [#27](https://github.com/bgunyel/clause-and-effect/issues/27)
measured Grok 4.6's pool under all three request shapes on one day and found two
endpoints, both `xAI`, with `endpoints.total: 5`. `Amazon Bedrock`, which the
catalogue lists, was never offered. That makes Grok one-provider today, at n=1
per shape. It does not make Grok one-provider tomorrow. A rule naming the model
would go stale without anything turning red, and a rule over the observed pools
is evaluated from per-attempt pool storage
([#20](https://github.com/bgunyel/clause-and-effect/issues/20) §1), which needs no
new column. The distinct-provider count and `len(endpoints.available)` are
different numbers, as Grok's 2 endpoints and 1 provider show, and R-d counts
providers. Nothing in R-d names Grok.

**Which pools are the cell's.** A pool belongs to a call, and a call belongs to a
`(model, channel)` pair, not to a provider. So the pools a cell's condition is
read over are every pool observed for its `(model, channel)` in the window,
including any its own provider was absent from. A narrower reading, over only
the pools that offered the cell's provider, fails in the permitting direction:
an alternative that was offered only when the cell's provider was not would be
missed, and the read would print *no alternative observed* when one was observed.
This agrees with [#32](https://github.com/bgunyel/clause-and-effect/issues/32),
which makes a pin a property of the `(model, channel)` pair.

**Why *observed*.** [#11](https://github.com/bgunyel/clause-and-effect/issues/11)
found the router metadata absent on 5xx responses and on auth failures, so a call
that fails at the HTTP level writes no pool. The read can only report what the
written pools show, and its wording says that. *No alternative observed* is a
statement about the rows, not about what the router could have offered.

**Not decided here.** R-d does not fix where the acquisition window starts or
ends. The pin and acceptable-set reads are taken over the whole window, so they
are only final when it closes. When R-c's m is fixed against the same window
belongs to [#377 — When is R-c's m fixed, if cells reach their declared n at
different times?](https://github.com/bgunyel/clause-and-effect/issues/377). Where a
call with no attributed provider lands belongs to [#371 — Failures with no
served provider: where a timeout lands in the acceptance
read](https://github.com/bgunyel/clause-and-effect/issues/371).

**Written before the first acquisition call**, with zero provider-attributed rows
in hand. This file is carried by a commit, and that commit can be ordered
against the commit of any acquisition row, as with the rest of this document.

---

# Registration — a no-response attempt is counted beside the rate, never in it

| | |
|---|---|
| registered | 2026-11-17 |
| branch | `dev-06` |
| commit at registration | `fd9381c619ed` |
| decided in | [#371 — Failures with no served provider: where a timeout lands in the acceptance read](https://github.com/bgunyel/clause-and-effect/issues/371) |
| written by | [#384](https://github.com/bgunyel/clause-and-effect/issues/384), under map [#6](https://github.com/bgunyel/clause-and-effect/issues/6) |
| subject | where an attempt that got no HTTP response lands in the acceptance read, what an organic and a forced acquisition report for it, and the deadline it is read under |
| status of the data | none — written before the first acquisition call; `record_attempt` still has no caller in `src/`, so `llm_attempt` has never held a row |

**This is a registration, not an amendment**, under the guard in [§The two kinds
of append](#the-two-kinds-of-append). The guard is applied here, not just the
label, because four passages above come close to the case and each was read for
whether it already says what R-g says:

- **R-b, as amended.** A cell's denominator is the calls its provider served. A
  no-response attempt was served by nobody, so under the amended R-b it was
  already in no denominator. R-g's first clause says so explicitly and changes
  nothing R-b means. The triple *(exposure, served, clean)* keeps its three
  members and their meanings. The forced cell's *timed out* sits beside the
  triple and is not a fourth member of it.
- **R-c, as amended.** *Testable* means served at least once. A no-response
  attempt serves nothing, so it makes no cell testable and leaves m where it was.
- **R-d's *Why observed*.** It says a call that fails at the HTTP level writes no
  pool, and that the pin read reports only what the written pools show. R-g
  counts those attempts. It does not give them a pool or a provider, so R-d's
  reads are unchanged.
- **R6.** It permits re-testing a failed cell after *"a config, model, or
  provider change"*, and a deadline change is a config change. R-g's deadline
  clause is written for **R-g's own numbers**: the no-response buckets, the
  forced *timed out* count, and the no-response share that the amendment below
  gates on. None of those had a decision rule before, so conditioning them on a
  deadline changes no sentence. For a cell's rule-in, R6 governs a deadline
  change as written.

Nothing registered or amended so far says what the read does with an attempt
that no provider answered, so R-g owes no old value. §1, §2, R1–R6, §5, the
frozen draw, the invariant ordering, §8's outcome table, R-a, R-b and R-c as
amended, R-d, R-e and R-f all stand. The gate that makes the count matter to a
pin is a separate append, the amendment that follows this registration, because
it changes what R4's pressure point already says.

**Labels.** The label R-g was fixed when #371 was decided. Other registrations
may be appended before it, so the order of labels and the order in this file
can differ. The index records append order.

## R-g. A no-response attempt is counted beside the rate, never in it

> A **no-response attempt** is an attempt that left the client and got no HTTP
> response. It names no provider, so it is **never in an acceptance rate's
> denominator**. The acceptance rate stays a served-call structure rate, as R-b
> amended defines it.
>
> - **Organic acquisition.** Each `(model, channel)` gets an **attempt-level
>   count** of the attempts whose `served_provider` is still null. Attempts are
>   reached through `call_id` to their call's `(model, channel)`, and the count
>   is read only **once enrichment has finished**. It is split into three
>   buckets: *no response* (`http_status` null), *4xx* and *5xx*. It is printed
>   **beside every cell of that `(model, channel)`** and is never a denominator.
> - **Forced acquisition (measurement pin).** Each cell reports a fourth number,
>   **timed out**, beside *(exposure, served, clean)*. It counts the cell's
>   no-response attempts under the pin. It is attributed to the **pinned
>   condition** and is not proven against the provider, because OpenRouter's
>   queueing sits between the two. Forced and organic counts never pool, as §2
>   already says of a cell's n.
> - **The deadline in force.** Acquisition runs under the stack's existing
>   behaviour, and no new deadline is added for it. The deadline in force,
>   outer and library-level, is recorded on **every `llm_call` row**, and the
>   recording exists before the first acquisition call. A deadline that is
>   absent is recorded as null, never as 0. For R-g's numbers, a run under a
>   different deadline is a **different condition, not a re-test**, and its
>   numbers are never pooled with those of another deadline.

**Why outside the rate.** Folding a no-response attempt into the numerator would
put *"the model answered unusably"* and *"nobody answered"* in one count, and
only the first is a fact about a provider's output. `src/llm/call.py` already
draws that line between `STRUCTURE_PROBLEM` and the network-or-provider statuses.
The amended R-b reaches the same answer from the other side: nobody served the
attempt, so there is no cell for it to be a failure of.

**Why never out of the read.** Dropping it is the survivorship this registration
exists to close. The motivating case is concrete. The 2026-08-23 channel
experiment recorded DeepSeek V4 Flash at **3/6 under `json_schema`**, and all
three failures were the probe's own 120 s `asyncio.wait_for` cutoff, with no
response at all. A provider that times out every time would contribute to no
cell's numerator or denominator, and would read as never having failed. That is
the survivorship [#11](https://github.com/bgunyel/clause-and-effect/issues/11)
found for 5xx and auth failures, in its largest form. The organic count absorbs
#11's cases too, in buckets of their own.

**Why attempts, not calls.** A call that timed out on its first attempt and was
served clean on its second has `llm_call.status` `OK`. A call-level count would
not see the timeout at all.

**Why the forced number is attributed to the condition.** Under `only: [X]` with
no fallbacks, no other provider could have served, so the timeout belongs to the
cell's condition. It is not proven against X, because a request can wait in
OpenRouter's queue before X ever sees it. The forced number is a measurement pin
in the map's own sense: it holds routing fixed to measure something downstream
of routing, which is legitimate. The config pin is the thing the map rules out.

**Why the deadline is part of the condition.** A timeout exists only relative to
a deadline. The same provider reads 3/6 under 120 s and 0/6 under no deadline at
all. A no-response count read without the deadline it was taken under cannot be
compared with any other count. No new deadline is added, because the map rules
the retry deadline out until the log holds data: a deadline truncates exactly
the retry storms whose cost is being counted.

**Why the gate reads `http_status` and not `llm_call.status`.** No timeout the
stack raises is a `TimeoutError` ([#383](https://github.com/bgunyel/clause-and-effect/issues/383)),
so every real timeout is logged as `TRANSPORT_PROBLEM` and `CallStatus.TIMEOUT`
is unreachable. R-g's *no response* bucket is defined on the attempt row's null
`http_status`, which does not depend on how the exception was classified.

**Not decided here.** How the socket writes an attempt row when `send` raises,
and whether the header `generation_id` survives a client timeout, belong to
[#385 — Specify the socket's attempt row on a raised send, and the deadline in
force on llm_call](https://github.com/bgunyel/clause-and-effect/issues/385). So
does whether the deadline is a column or a `metadata` key. Whether headers arrive
before the body on a non-streamed call is unobserved. R-g holds either way, and
that fact only changes how many no-response attempts the enrichment sweep can
later attribute. Whether a forced cell also prints the 4xx and 5xx buckets
beside *timed out* is not fixed here; the no-response share counts them either
way. When the no-response share is read, and what n a forced acquisition that
clears it declares, belongs to [#392 — When is the no-response share read, and
what n does a forced clearing acquisition
declare?](https://github.com/bgunyel/clause-and-effect/issues/392).

**Written before the first acquisition call**, with zero provider-attributed rows
in hand. This file is carried by a commit, and that commit can be ordered
against the commit of any acquisition row, as with the rest of this document.

---

# Amendment — acceptable-set membership needs a cleared no-response share, not rule-in alone

| | |
|---|---|
| amended | 2026-11-17 |
| branch | `dev-06` |
| commit at amendment | `fd9381c619ed` |
| decided in | [#371 — Failures with no served provider: where a timeout lands in the acceptance read](https://github.com/bgunyel/clause-and-effect/issues/371) |
| written by | [#384](https://github.com/bgunyel/clause-and-effect/issues/384), under map [#6](https://github.com/bgunyel/clause-and-effect/issues/6) |
| amends | two clauses of [R4's anticipated pressure point](#r4s-anticipated-pressure-point): what membership is, and what every member clears |
| status of the data | none — written before the first acquisition call; `record_attempt` still has no caller in `src/`, so `llm_attempt` has never held a row |

**This is an amendment, not a registration**, under the guard in [§The two kinds
of append](#the-two-kinds-of-append). R4's pressure point says that
*"membership is the rule-in test"*. Under that sentence a cell that rules in is a
member. After this amendment a cell can rule in and still not be a member, so the
sentence would have meant something different, and it owes an old value.

**What stands unamended.** §2's definition of rule-in does not move: the upper
bound below the tolerance in force, at the declared n. R3 is untouched. The gate
governs what a rule-in **licenses**, not when rule-in is evaluated. The rest of
R4's pressure point stands, including its registered position, *"accept the
smaller k, or accept no pin"*, and *"k is chosen purely to buy refusal headroom,
never to rescue a member"*. §1, R1, R2, R4–R6, §5, R-a to R-g, and R-b and R-c as
amended all stand.

## The old value

From R4's anticipated pressure point, verbatim, the two sentences that carry
the change. Each is quoted whole, with its own markup, so that it can be found:

> Under the **k>1** reframing — where the pin becomes an *acceptable set*
> `{only: [X, Y], allow_fallbacks: True}` and membership is the rule-in test — a
> member failing rule-in shrinks the set, and a set that is too small no longer
> buys refusal headroom.

> Every member clears rule-in individually; k is chosen purely to buy refusal
> headroom, never to rescue a member.

The words that change are *"membership is the rule-in test"* in the first and
*"Every member clears rule-in individually"* in the second. The rest of both
sentences stands.

## The new value

The first passage now reads *"and membership is the rule-in test plus a
cleared no-response share"*. The second now reads *"Every member clears rule-in,
and its no-response share, individually"*. What the share is, and what happens
when it does not clear:

> A cell is a member of an acceptable set only if it **rules in** under §2 and
> its **no-response share also clears**.
>
> - The **no-response share** is non-served attempts over all attempts. Its
>   numerator is every attempt no provider served, whatever its bucket, so for
>   organic acquisition it is the sum of R-g's three buckets.
> - It **clears** when its Clopper-Pearson upper bound, 95% one-sided, is below
>   the §1 tolerance in force. That is the same bound and the same reading as
>   §2's rule-in, applied to a different quantity.
> - It is read at the **`(model, channel)`** level for organic acquisition and
>   **per cell** for forced acquisition. Forced and organic never pool.
> - A cell that rules in and whose share does not clear is reported as
>   **"rule-in, no-response unresolved"**. It is not a member. A config pin on
>   it needs a **forced acquisition** whose per-cell share clears.

A member whose share does not clear is not rescued any more than one that fails
rule-in. The position stands as registered: accept the smaller k, or accept no
pin.

## The reason

Without the gate, rule-in is blind to a provider that times out often. A
provider that gets no response on 40% of its attempts still rules in on its 29
clean served calls, because its no-response attempts are in no denominator
under R-g, as they must be. The pin that follows sends traffic to a provider
that fails 40% of the time, and nothing in the read says so. That is a false
rule-in of the silent kind, which is the error §2's asymmetry is built against.

Two alternatives were rejected when #371 was decided:

- **Report only.** It prints the count and gates on nothing. A pin could then be
  taken on a cell whose count was printed and ignored, and the case above stays
  silent.
- **Worst-case attribution.** Charging every organic no-response attempt to
  every cell of its `(model, channel)` turns one organic timeout into a rule-out
  across a whole `(model, channel)`.

The organic share is read at `(model, channel)` level because an organic
no-response attempt names no provider, so it cannot be charged to one cell. The
forced acquisition is the way out of that bluntness, because under a pin the
attempt belongs to the cell's condition.

**The trade, recorded.** #371 judged the organic read blunt but safe. It is safe
in one direction only. A provider can be held back by its neighbours' timeouts,
and it can also be **let through by its neighbours' clean attempts** when it
carries a small fraction of its `(model, channel)`'s attempts. In the case
above, a provider with 19 no-response attempts of 48 has a share whose upper
bound is 52.5% on its own. Pooled with 300 clean attempts from other providers
on the same `(model, channel)`, it is 19/348 with an upper bound of 7.9%, which
clears a 10% tolerance. Pooled with 1000, it is 19/1048 with an upper bound of
2.7%, which clears 5% too. The organic gate then passes, nothing triggers a
forced acquisition, and the silent false rule-in this amendment was decided to
close stays open for that provider. The rule above is registered as decided.
Its limit is recorded here, so that the commitment does not claim a safety it
lacks. Whether the gate needs more than a `(model, channel)` read belongs to
[#391 — The organic no-response share can be cleared by dilution: does the gate
need more than a (model, channel) read?](https://github.com/bgunyel/clause-and-effect/issues/391),
and any change it makes is a further amendment, owed before the first
acquisition call.

**Written before the first acquisition call**, with zero provider-attributed rows
in hand. The only per-provider traffic on record is
[#22](https://github.com/bgunyel/clause-and-effect/issues/22)'s header A/B, which
measured distortion, latency and cost and never computed a structure-failure
rate or a no-response share.

---

# Amendment — the multiplicity correction is Bonferroni over the named set, and the draw grows to 125 cases

| | |
|---|---|
| amended | 2026-11-17 |
| branch | `dev-06` |
| commit at amendment | `e59a02d674b6` |
| decided in | [#377 — When is R-c's m fixed, if cells reach their declared n at different times?](https://github.com/bgunyel/clause-and-effect/issues/377) |
| written by | [#390](https://github.com/bgunyel/clause-and-effect/issues/390), under map [#6](https://github.com/bgunyel/clause-and-effect/issues/6) |
| amends | §1's *0/29* sentence; §2's rule-in bullet; R-c's heading, its correction clause as the amendment of R-b left it, and the last clause of its paragraph on R1; and three passages of §4 |
| status of the data | none — written before the first acquisition call; `record_attempt` still has no caller in `src/`, so `llm_attempt` has never held a row |

**This is an amendment, not a registration**, under the guard in [§The two kinds
of append](#the-two-kinds-of-append). It changes what already-written sentences
mean, so it owes an old value, and the old value is given in full below.

The pre-registration never says **which** multiplicity correction it uses.
[#7](https://github.com/bgunyel/clause-and-effect/issues/7) controlled
multiplicity only by restricting rule-in tests to genuine candidates, which is
R1. §2's n = 29 is an **uncorrected** 95% bound.
[#20](https://github.com/bgunyel/clause-and-effect/issues/20) then wrote *"the
multiplicity correction"* into R-c as though one had been chosen, and none had.
Under any family-wise correction, 0/29 does not rule in once m ≥ 2. Its one-sided
upper bound is 11.9% at m = 2, 18.9% at m = 22 and 19.7% at m = 29, against a
tolerance of 10%. So every sentence that rules a cell in on 29 changes meaning.
The corrected n depends on m, and R2 declares n before a cell's first call, so m
has to be known before the first call too. That is why R-c's choice of what the
correction is taken over changes with it.

**What stands unamended**, each with its reason:

- **§2's table.** Its numbers are uncorrected 95% bounds, and they are still
  true. They are the m = 1 row of the rule below.
- **R2 and R3.** n is still declared before a cell's first call, and rule-in is
  still evaluated exactly once, at that n. Only the way n is found changes.
- **R-c's legitimacy argument**, *"Pool membership is observable without seeing
  any rate"*, and its restatement for served calls in the amendment of R-b.
  Both are still true. Neither is needed any more, because m is now fixed before
  anything is observed.
- **R-d's *"is counted in the correction's m"*.** Still true. A one-provider cell
  is named, so it is counted.
- **R-d's *"If the only provider serves 29 calls, those are 29 genuine
  observations of its failure rate, and §2's bars apply to them unchanged"*.**
  It reads through to §2, and §2 is amended below. 29 is §2's n at m = 1 under
  the 10% branch.
- **R-f's reason clause**, *"Without R-f, a provider named once could be tested
  in two cells, and the correction's m would count cells R1 never named."* Still
  true. R-f is also what makes the named set per `(model, channel)` the same as
  §5's named set per model.
- **R-g's *"it makes no cell testable and leaves m where it was"*.** Still true,
  and more strongly: no attempt moves m, which is fixed at R1. R-g was appended
  after #377 was decided, so #377 did not list it. It was read for this
  amendment under the guard.
- **The acceptable-set amendment's *"still rules in on its 29 clean served
  calls"*.** Its argument holds at any n. 29 is §2's n at m = 1 under the 10%
  branch. Read under the guard for the same reason as R-g.
- **The *Verified against* paragraph after
  [§Registrations](#registrations).** It records how §4's 29 were reproduced at
  registration, and that record is still true.

§1's conditional, R1 and R4–R6, §5 to §9, R-a, R-b as amended, R-e to R-g, and
R4's pressure point as amended all stand. What the acceptable-set amendment says
about the no-response share's bound is taken up under *Not decided here*.

## The old value

Each passage verbatim, with its own markup.

From §1:

> A cell clears it on 0/29 with a point estimate of zero.

From §2, the rule-in bullet:

> - **Rule-in:** upper bound below tolerance → **n = 29 clean observations**.

R-c's heading, set in bold so that this quote does not create a second anchor:

> **R-c. Named and testable are both reported, and the correction is over testable**

R-c's correction clause, as the [amendment of
R-b](#amendment--an-acceptance-rates-denominator-is-the-calls-its-provider-served-not-pool-exposure)
left it:

> The multiplicity correction is taken over the **testable** cells — those
> served at least once — and the gap between named and testable is always shown.

The last clause of R-c's paragraph on R1:

> … which is why the named set stays frozen and only the correction's
> denominator moves.

From §4, the method line inside the frozen block, and two sentences:

```
method:     random.Random(20260905).sample(sorted(case_ids), 29)
```

> Within a cell there are still 29 distinct prompts.

> Both routes cost 29 calls.

R-c's heading and the last clause of its paragraph on R1 are not on #377's
list. Both are here because the guard puts them here: each says the correction
follows the testable count, and #377 decided that it does not.

## The new value

**The correction.**

> The multiplicity correction is **single-step Bonferroni on each cell's
> one-sided rule-in bound, at α/m** with α = 0.05. The family is **one pin
> decision**: one `(model, channel)`. **m is the size of R1's named set for that
> `(model, channel)`, fixed at R1**, before the first acquisition call. It is not
> the testable count.
>
> R2's n follows from m. **The binding rule is the smallest n with
> (1 − t)ⁿ ≤ 0.05 / m**, where t is whichever branch of §1's tolerance holds at
> acquisition. Each cell is evaluated once, as R3 requires, as soon as it
> reaches that n. Nothing waits for the acquisition window to close.
>
> **Rule-out is not corrected.** It stays at 2 consecutive failures, the
> uncorrected 95% lower bound §2 registered.

The table is illustrative. The formula binds.

| m | t = 10% | t = 5% |
|---:|---:|---:|
| 1 | 29 | 59 |
| 2 | 36 | 72 |
| 12 | 53 | 107 |
| 15 | 55 | 112 |
| 29 | 61 | 125 |

§1's condition currently fails, so the 5% column is the live one today. At m = 1
the formula gives §2's 29 and 59 again. The *≤* and §2's *"below"* pick the same
n. Zero failures in n has the upper bound 1 − (α/m)^(1/n), which is below t
exactly when (1 − t)ⁿ < α/m. Equality never occurs, because (1 − t)ⁿ = 0.05 / m
would need 3 to divide 10ⁿ at t = 10%, or 19 to divide 20ⁿ⁻¹ at t = 5%.

**§1.** The sentence now reads: *"A cell clears it on 0/n, at the n §2 declares
for it, with a point estimate of zero."*

**§2's rule-in bullet** now reads:

> - **Rule-in:** the one-sided upper bound at α/m below tolerance → **n clean
>   observations, n the smallest with (1 − t)ⁿ ≤ 0.05 / m**.

**R-c.** Its heading now reads *"Named and testable are both reported, and the
correction is over the named set"*. Its correction clause now reads:

> The multiplicity correction is taken over the **named** set: m is the number
> of cells R1 named for the `(model, channel)`, fixed at R1. Testable cells —
> those served at least once — are still reported, and the gap between named
> and testable is always shown.

The last clause of its paragraph on R1 now reads: *"… which is why the named set
stays frozen. The correction is taken over that frozen set, so nothing about it
moves on observation."*

**The trade, recorded.** Testable stops being the correction's denominator. That
reverses the clause the amendment of R-b wrote, for the reason below. A named
cell that is never served still costs the correction power and buys no safety,
as that amendment's argument says. The cost is accepted so that m is known
before the first call, which R2 needs.

**§4. The draw becomes one ordered list of 125 distinct cases.** Its head is
§4's frozen 29, unchanged and in sorted order. Its tail is 96 cases drawn from
the 404 not in §4's draw, under a new seed, in the order they were drawn. **Every
cell in a family uses the list's first n cases**, n being the family's n under
§2, so the pairing holds within each pin decision.

```
population: 433 (src.eval.dataset.load_tier1)
head:       §4's draw, unchanged
            head = random.Random(20260905).sample(sorted(case_ids), 29)
            sha256 of the newline-joined sorted head reproduces
            26cdec8e9ab8a5b3bfa15f76a88d136516066acc548a971bb402e07019638d84
seed:       20261117
method:     random.Random(20261117).sample(sorted(set(case_ids) - set(head)), 96)
order:      the order sample() returns them in, which is the draw order
sha256:     32547f20f5004126e7fb7765a2e7c1386f7c4b02559772cf232ccff69c033a2e
            (of the newline-joined extension, in draw order)
list:       sorted(head) followed by the extension in draw order
sha256:     4802ad2996039d14ba5473f3d4fc638110181c242cd72e3fa3907459ceb19730
            (of the newline-joined 125, in list order)
```

Each digest is over UTF-8 ids joined with `\n` and no trailing newline, as §4's
is. Reproduced on CPython 3.13.15 under `uv run`, where §4's head also
reproduces its own digest. **The seed is the amendment's date**, as §4's
`20260905` was its registration's. It was fixed before the draw was run, and the
draw was run once.

The whole list, by position. Positions 1–29 are §4's 29, and 30–125 are the
extension. *Sorted* means Python's string order, the order §4's digest is taken
over, so `gdpr_art10_case4` comes before `gdpr_art6_case2`. That differs from
the article order §4 prints its 29 in. Every family's n is at least 29, so the
head's internal order never decides which cases a cell uses.

```
  1 gdpr_art10_case4      2 gdpr_art13_case6      3 gdpr_art13_case8      4 gdpr_art15_case2
  5 gdpr_art17_case5      6 gdpr_art20_case2      7 gdpr_art23_case1      8 gdpr_art27_case4
  9 gdpr_art32_case1     10 gdpr_art33_case2     11 gdpr_art33_case5     12 gdpr_art34_case1
 13 gdpr_art39_case2     14 gdpr_art41_case1     15 gdpr_art42_case4     16 gdpr_art58_case3
 17 gdpr_art60_case5     18 gdpr_art66_case5     19 gdpr_art69_case1     20 gdpr_art69_case2
 21 gdpr_art6_case2      22 gdpr_art6_case4      23 gdpr_art78_case2     24 gdpr_art80_case2
 25 gdpr_art81_case1     26 gdpr_art84_case3     27 gdpr_art86_case3     28 gdpr_art92_case2
 29 gdpr_art93_case2     30 gdpr_art27_case1     31 gdpr_art12_case7     32 gdpr_art37_case4
 33 gdpr_art33_case4     34 gdpr_art35_case3     35 gdpr_art48_case3     36 gdpr_art43_case5
 37 gdpr_art9_case5      38 gdpr_art49_case1     39 gdpr_art5_case5      40 gdpr_art16_case1
 41 gdpr_art11_case3     42 gdpr_art95_case2     43 gdpr_art4_case1      44 gdpr_art43_case2
 45 gdpr_art42_case2     46 gdpr_art61_case1     47 gdpr_art8_case1      48 gdpr_art23_case3
 49 gdpr_art64_case2     50 gdpr_art93_case1     51 gdpr_art53_case1     52 gdpr_art5_case8
 53 gdpr_art2_case4      54 gdpr_art24_case4     55 gdpr_art44_case1     56 gdpr_art83_case2
 57 gdpr_art84_case1     58 gdpr_art68_case2     59 gdpr_art75_case1     60 gdpr_art68_case4
 61 gdpr_art25_case4     62 gdpr_art78_case4     63 gdpr_art37_case5     64 gdpr_art70_case4
 65 gdpr_art29_case3     66 gdpr_art74_case3     67 gdpr_art79_case4     68 gdpr_art88_case1
 69 gdpr_art89_case4     70 gdpr_art94_case1     71 gdpr_art32_case3     72 gdpr_art67_case3
 73 gdpr_art20_case4     74 gdpr_art24_case3     75 gdpr_art17_case3     76 gdpr_art79_case1
 77 gdpr_art18_case2     78 gdpr_art1_case1      79 gdpr_art96_case3     80 gdpr_art25_case2
 81 gdpr_art64_case1     82 gdpr_art2_case5      83 gdpr_art23_case4     84 gdpr_art71_case2
 85 gdpr_art43_case3     86 gdpr_art70_case2     87 gdpr_art90_case3     88 gdpr_art94_case2
 89 gdpr_art47_case1     90 gdpr_art18_case1     91 gdpr_art17_case4     92 gdpr_art72_case1
 93 gdpr_art2_case1      94 gdpr_art49_case4     95 gdpr_art80_case1     96 gdpr_art49_case2
 97 gdpr_art26_case3     98 gdpr_art3_case1      99 gdpr_art61_case4    100 gdpr_art51_case2
101 gdpr_art22_case4    102 gdpr_art93_case3    103 gdpr_art52_case3    104 gdpr_art77_case2
105 gdpr_art64_case4    106 gdpr_art44_case3    107 gdpr_art82_case5    108 gdpr_art33_case6
109 gdpr_art9_case4     110 gdpr_art70_case1    111 gdpr_art84_case2    112 gdpr_art12_case2
113 gdpr_art82_case4    114 gdpr_art4_case8     115 gdpr_art31_case2    116 gdpr_art57_case3
117 gdpr_art98_case2    118 gdpr_art56_case1    119 gdpr_art59_case1    120 gdpr_art10_case2
121 gdpr_art9_case7     122 gdpr_art42_case1    123 gdpr_art3_case4     124 gdpr_art30_case2
125 gdpr_art87_case1
```

§4's three sentences now read:

- The method line in §4's block describes the list's head. The block above is
  the method for the whole list.
- *"Within a cell there are still n distinct prompts, n as §2 declares for the
  cell's family."*
- *"Both routes cost n calls."*

**The cost, on record.** DeepSeek V4 Flash alone, at m = 29, needs **1,769**
served calls at t = 10% (29 × 61) or **3,625** at 5% (29 × 125). The old n
needed 841 (29 × 29).

**The list's capacity, on record.** 125 cases supply n for m ≤ 30 under the 5%
branch: n is 125 at m = 30 and 126 at m = 31. Under the 10% branch they supply
any m this campaign could name. What a family named larger than that gets is
under *Not decided here*.

## The reason

**Why Bonferroni.** Holm and Benjamini-Hochberg need every cell's p-value at
once, and R3 evaluates each cell alone, at its own n and its own time.
Bonferroni is the one correction compatible with R3. It holds under dependence,
which the paired design creates, and it needs only m, never another cell's rate.
Šidák assumes independence and buys at most one case. #377's resolution says it
*"gives the same n"* at these sizes. Measured while writing this amendment, it
gives the same n or one fewer at every m in the table: 35 against 36 at m = 2,
and 124 against 125 at m = 29 under 5%.

**Why the family is one `(model, channel)`.** A false rule-in corrupts one
model's pin, and R-c already states the named set per model. A campaign-wide
family of about 58 cells was rejected.

**Why m is the named count.** It needs no observation at all, so it is known
before the first call, as R2 needs. The testable count is known only once the
acquisition window closes, and cells reach their n at different times. Fixing m
at R1 also removes #377's question about testable cells that never reach n.
Rejected: sizing n at the named m and reading the bar at the window's close with
the testable m. That needs a pre-registered close. Without one, closing early is
a lever decided after rates are visible. The power it buys is small, because n
grows with the log of m: **58 against 61** for DeepSeek's 22 testable against 29
named, at t = 10%.

**Why rule-out stays uncorrected.** A false rule-out corrects itself when the
pool rotates, and a false rule-in seals itself in as a pin. That is the
revisability asymmetry §3 grounds peeking on. It is stated here because R-c says
only *"the multiplicity correction"*, and never which bar it applies to.

**Why 125 distinct cases, and not 29 used again.** §4's own reason. Repeats of a
case are clustered observations, and a bound computed on them is optimistic, so
61 or 125 calls cannot come from 29 prompts. Keeping the head frozen means
[#7](https://github.com/bgunyel/clause-and-effect/issues/7)'s digest still
verifies, and the extension has a seed and a digest of its own.

**Not decided here.**

- **Re-tests.** Whether an R6 re-test adds to m, or what bounds the extra chance
  at rule-in that each re-test gets under a fixed m, belongs to [#397 — Does an
  R6 re-test add to R-c's m, or does each re-test buy a free chance at
  rule-in?](https://github.com/bgunyel/clause-and-effect/issues/397). This
  amendment fixes m at R1 and says nothing about re-tests.
- **The no-response share.** The [acceptable-set
  amendment](#amendment--acceptable-set-membership-needs-a-cleared-no-response-share-not-rule-in-alone)
  says the share clears when *"its Clopper-Pearson upper bound, 95% one-sided,
  is below the §1 tolerance in force. That is the same bound and the same
  reading as §2's rule-in, applied to a different quantity."* This amendment
  corrects the rule-in bound only. So the share's bound stays at 95% as that
  amendment states it, and the second sentence no longer holds of the level.
  Whether the share takes the correction belongs to [#400 — Does the no-response
  share's bound take R-c's Bonferroni correction, or stay at
  95%?](https://github.com/bgunyel/clause-and-effect/issues/400).
- **A named set larger than the list.** What n a cell gets when R1 names more
  than 30 providers for its `(model, channel)` under the 5% branch belongs to
  [#401 — What n does a cell get when R1 names more providers than the 125-case
  draw supports?](https://github.com/bgunyel/clause-and-effect/issues/401).
- **The acquisition window.** m no longer needs a close. R-d's pin and
  acceptable-set reads still do.

**Written before the first acquisition call**, with zero provider-attributed rows
in hand. This file is carried by a commit, and that commit can be ordered
against the commit of any acquisition row, as with the rest of this document.

---

# Registration — a new model makes new cells, and a re-test counts only its own rows

| | |
|---|---|
| registered | 2026-11-17 |
| branch | `dev-06` |
| commit at registration | `fd9381c619ed` |
| decided in | [#378 — Does R6's model change re-test the same cell, or make new cells as a channel change does?](https://github.com/bgunyel/clause-and-effect/issues/378) |
| written by | [#388](https://github.com/bgunyel/clause-and-effect/issues/388), under map [#6](https://github.com/bgunyel/clause-and-effect/issues/6) |
| subject | what R6's *model change* reaches, which cells a new model produces, and which rows a re-test counts |
| status of the data | none — written before the first acquisition call; `record_attempt` still has no caller in `src/`, so `llm_attempt` has never held a row |

**This is a registration, not an amendment**, under the guard in [§The two kinds
of append](#the-two-kinds-of-append). The guard is applied here, not just the
label, because R6 is again the sentence an amendment would be changing. R6 permits
*"re-testing a failed cell"* after *"a config, model, or provider change"*. What
R6 re-tests is a **cell**, and a cell's model is read from its own rows, the way
R-f reads its channel: `llm_call.model`, which holds the `ModelNames` value, e.g.
`deepseek-v4-flash-0731`. It is not the OpenRouter slug that value was sent as,
which `ai_common` resolves at call time and no column records, and it is not
`llm_attempt.model_alias`, the wire id the response reports. Rows taken under a
new `ModelNames` value carry that value, so they belong to a different triple,
and R6 never moves a row from one triple to another. So R6's *model change* can
reach only a change **behind** a fixed value: a provider redeploying, OpenRouter
or the lab moving an alias, or an `ai_common` upgrade repointing the value's slug.
That reads all three of R6's causes alike, as changes behind a fixed triple, which
is how the channel registration above read *config change*. Nothing R6 said
changes meaning. R1's key never let it reach another triple. What nothing above
said is where a new model's rows go, which R-h says, and which rows a re-test
counts, which R-i says. §1 and §2 as amended, R1–R6, §4 as amended, §5, the
invariant ordering, §8's outcome table, R4's pressure point as amended, R-a, R-b
as amended, R-c as amended twice, R-d, R-e, R-f and R-g all stand.

**The trade, recorded.** Keying on the `ModelNames` value means a change behind
it does not make a new cell. Recorded before the new acquisition, such a change
is what R6 permits and R-i governs. **Unrecorded, it mixes two models' rows into
one cell**, and nothing in this registration detects it. The slug sent is
recorded nowhere. `llm_run.commit_sha` pins `uv.lock`, so an `ai_common` repoint
can be recovered. Whether `llm_attempt.model_alias` reveals an alias move is
unobserved: the only response observed is for the dated slug
`deepseek/deepseek-v4-flash-0731`, and six of the eight roster slugs are undated.
That gap is held by [A change behind the model key is silent: what in the log
detects it?](https://github.com/bgunyel/clause-and-effect/issues/387). Neither
rule here says anything about R-c's m. The [Bonferroni
amendment](#amendment--the-multiplicity-correction-is-bonferroni-over-the-named-set-and-the-draw-grows-to-125-cases)
fixes m at R1 and leaves re-tests open, so whether a re-test adds to it is held
by [#397 — Does an R6 re-test add to R-c's m, or does each re-test buy a free
chance at rule-in?](https://github.com/bgunyel/clause-and-effect/issues/397).

**Why now.** Once an acquisition row exists, applying either rule after a model
change or a re-test cannot be told apart from relabelling to fit the result.
Written before any such row exists, it is a commitment.

**Labels.** R-g was fixed when #371 was decided, before #378, and is registered
above, so the two rules here are R-h and R-i. A label is
fixed when its ticket is decided, so the order of labels and the order in this
file can differ. The index records append order.

## R-h. A new model makes new cells, not a re-test

> When the roster replaces a model with a different `ModelNames` value,
> acquisition under the new value produces **new** `(model, channel, provider)`
> cells. Each needs its own R1 naming and its own R2 n before its first call. It
> inherits nothing from the old value's cells, **in either direction**. A cell
> that failed under the old value stays failed and is not re-tested by the new
> one. A pass under the new value licenses a pin on the new value only, and a pass
> under the old value licenses nothing on the new one.

*Closes:* R4 evaded by relabelling, one level out, as with R-e. A successor
model's pass reported under its failed predecessor's name is a different model's
result under the same name. A dated successor snapshot is the likeliest case:
`DEEPSEEK_V_4_FLASH_0731` and a later DeepSeek Flash snapshot are different
values, and so different cells, however close the names read.

## R-i. A re-test is a new acquisition of the same cell

> A re-test permitted by R6 counts only the rows of acquisition runs whose
> `llm_run.commit_sha` has, as an ancestor, the commit that records the cause.
> It has its own R2 n, declared before its first call, and R3 evaluates it once,
> at that n, on those rows only. Rows taken before the cause are never pooled
> with them. The prior result stands, and it is reported beside the re-test's.

*Closes:* R4 evaded by extension under R6's name. Pooling a failed cell's rows
with the rows taken after the cause is that cell extended past its declared n.
R2 fixes n *"before that cell's first call"*, and a re-tested cell's first call
is already in the log, so without R-i nothing says when a re-test's n is fixed.

The rule can be checked without seeing any rate. Which rows a re-test counts is
decided by commit ancestry between `llm_run.commit_sha` and the commit recording
the cause, and both are fixed before any acceptance rate is computed.

**Written before the first acquisition call**, with zero provider-attributed rows
in hand. This file is carried by a commit, and that commit can be ordered
against the commit of any acquisition row, as with the rest of this document.

---

# Amendment — a cell whose rows carry two permaslugs is mixed, and a mixed cell cannot be ruled in

| | |
|---|---|
| amended | 2026-11-17 |
| branch | `dev-06` |
| commit at amendment | `c2f2816e04ff` |
| decided in | [#387 — A change behind the model key is silent: what in the log detects it?](https://github.com/bgunyel/clause-and-effect/issues/387) |
| written by | [#399](https://github.com/bgunyel/clause-and-effect/issues/399), under map [#6](https://github.com/bgunyel/clause-and-effect/issues/6) |
| amends | R3 |
| status of the data | none — written before the first acquisition call; `record_attempt` still has no caller in `src/`, so `llm_attempt` has never held a row |

**This is an amendment, not a registration**, under the guard in [§The two kinds
of append](#the-two-kinds-of-append). R3 says that rule-in *"is evaluated exactly
once, at the declared n"*. Under that sentence every cell that reaches its
declared n is evaluated. After this amendment a cell can reach its n and not be
evaluated, so the sentence would have meant something different, and it owes an
old value.

The registration of R-h and R-i recorded the gap this closes. A change behind a
fixed `ModelNames` value, if no one records it, *"mixes two models' rows into one
cell, and nothing in this registration detects it."*
[#386](https://github.com/bgunyel/clause-and-effect/issues/386) and #387 found
that the log can detect most such changes. The permaslug, the dated id
OpenRouter routes a slug to, is stored on every attempt. This amendment says what
the acceptance read does when it sees more than one.

**What stands unamended**, each with its reason:

- **§1 and §2, as amended.** They say what clears the bar. R3 says when the bar
  is read, and only R3 changes.
- **R4.** A mixed cell is never evaluated, so it is never *"failed at its
  declared n"*, and R4 does not reach it.
- **R5.** Rule-out peeks stay unrestricted, mixed rows included.
- **R6.** It states what re-testing a **failed** cell requires. A mixed cell is
  not failed, and this amendment says how a mixed cell is re-tested. It does so
  on R6's terms, so no sentence of R6 changes meaning. *"A cause external to the
  log"* still holds. The cause is the change itself, OpenRouter re-pointing the slug
  to another dated model. The log is only where the change shows.
- **R-i.** *"counts only the rows of acquisition runs whose `llm_run.commit_sha`
  has, as an ancestor, the commit that records the cause"* is still a condition
  that every counted row meets. The condition this amendment adds is in R3.
  *"R3 evaluates it once, at that n, on those rows only"* reads through to R3,
  and R3 is amended below.
- **§8's outcome table.** It covers the reproduction, not cell outcomes. Its
  *Not run* row is the precedent this amendment follows: an outcome that is
  neither a pass nor a failure, registered so that it is not quietly counted as
  either.
- **R-g.** A no-response attempt is not a served row, so it never enters the
  mix.

R1, R2, §4 as amended, §5 to §9, R4's pressure point as amended, R-a, R-b as
amended, R-c as amended twice, and R-d to R-h all stand. A mixed cell's model,
channel and provider are still read from its own rows, as the *Acceptance cell*
entry in `CONTEXT.md` says. The mix is a fact about which dated model served those
rows, and it makes no new cell.

## The old value

R3, verbatim, from §3:

> - **R3.** Rule-in is evaluated exactly once, at the declared n. A bound that
>   clears at n=20 is not a pass. *Closes:* stopping on good news.

## The new value

**R3, as amended.**

> - **R3.** Rule-in is evaluated exactly once, at the declared n, and never on
>   rows that are **mixed**. A bound that clears at n=20 is not a pass. A cell
>   whose rows are mixed is not evaluated, so its one evaluation is not spent,
>   and its outcome is **mixed**. *Closes:* stopping on good news.

**What mixed is.**

> An acceptance cell is **mixed** when its served rows carry more than one
> permaslug with no recorded cause between them. A row's permaslug is the one in
> `endpoints` (hoisted), or failing that the one in
> `routing_chain[].model_permaslug`. A null permaslug is its own bucket and never
> a value. Null rows are printed and counted toward n and toward failures, and
> they never make a mix: the mix is read over the values only.

The mix is read over **served** rows, the rows an acceptance rate's denominator
is made of. A null row is not dropped. Whether a row's metadata arrived might go
with whether it failed, and dropping it could then remove failures in the silent
direction. A change hidden in null rows cannot be seen. It joins the limit
recorded under *The trade* below.

**Only an external change mixes a cell.**

> A change of `requested_slug` is our own commit, such as an `ai_common`
> repoint, and `commit_sha` already dates it. R-i handles it as written: rows
> before the commit are the prior cell, and rows descending from the commit are
> the re-test. It never produces the mixed outcome.

That holds when a commit carries the repoint, which it does when `ai_common` is
installed from `uv.lock`. **A repoint that no commit carries** has no recorded
cause, so the definition above reads the cell as **mixed**. An editable
`ai_common` install is one such case, and it is the case #387 rejected `uv.lock`
reconstruction for. Its rows show `requested_slug` changing where `commit_sha`
does not. So the clause above covers a repoint that some commit carries. Reading
the other case as mixed is the direction that blocks a rule-in.

**The outcome.**

> A mixed cell **cannot be ruled in**. R3 is not evaluated on mixed rows, so its
> one evaluation is not spent and R4 does not fire. The cell's outcome is
> **mixed**, distinct from *failed*. **Rule-out stays open** on the mixed rows
> under R5, so a cell that is actually failing is still ruled out, and the
> outcome rescues nothing.

*Failed* would be a false claim about the provider. Mixed rows are observations
of two dated models under one name, and a bound over them describes neither.
Reporting the cell as unmeasured would be the leak R5 closes, a cell quietly
dropped. So mixed is reported as an outcome, with its rows.

**The identity check is not a peek.**

> Slug and permaslug values reveal nothing about failures, so the read may
> report them at any time. A mix found before the declared n ends that
> acquisition without waiting for n.

Ending an acquisition early is what R3 forbids on good news. Here the stop is
decided by which permaslug the rows carry, which says nothing about failure. So it cannot be a
stop on good news, and it cannot be an extension on bad.

**The re-test.**

> The detection is the R6 cause. It is recorded as a commit. The re-test counts
> only rows whose `llm_run.commit_sha` descends from that commit and that carry
> the new permaslug. It runs under R-i's own R2 n and one R3 evaluation. The
> mixed rows stay standing as the prior result.

Two cases follow from the definitions above. Each is written down here so that
it is not settled after the rows exist:

- **A null row in a re-test** counts toward the re-test's n and toward its
  failures, as it does in any cell. It carries no permaslug, so it is neither
  the new one nor another.
- **A descendant row carrying any other permaslug**, the old one coming back or
  a third, is not counted toward n, and it **makes the re-test mixed**. A
  re-test is a cell's acquisition like any other, and the mixed rule applies to
  it. Without this, a slug that alternates between two permaslugs could be
  ruled in on the one the re-test happened to count.

**What the read prints, per cell.**

> Each distinct `requested_slug`, `model_alias` and permaslug, each with its row
> count and its first and last `started_at`. Also, for information only and
> never as a gate: the number of distinct `endpoint_id` values, and the distinct
> `system_fingerprint` values.

One provider legitimately runs several endpoints. BaseTen runs two in
[#14](https://github.com/bgunyel/clause-and-effect/issues/14)'s pool, so more
than one endpoint is not a mix. The fingerprint does not gate until item 9 of
`docs/research/openrouter-undated-alias-model-field.md` is observed, because
`vllm-dev-ep-8b5ae245` may name a replica rather than a deployment. A gate on it
before then could mark as mixed a cell that never changed. The print also shows
where `model_alias` differs from `requested_slug`. The echo held on 16 of 16
captured bodies, and that is an observation, not a guarantee.

`requested_slug` and `system_fingerprint` are not columns yet. #18's migration
adds them to `llm_attempt` with #24's table, and their rows are verbatim on
#387's resolution.

**The trade, recorded.**

> A lab's own alias move, or a provider redeploying, behind an **unchanged**
> permaslug leaves no per-call trace the log is known to carry. It is
> undetectable, and is accepted as a named limit, not closed. No per-run
> catalogue snapshot is taken, because `/endpoints` cannot be joined to a call.

So *not mixed* means *no change the log can see*. It does not mean *one
deployment*. A cell that rules in under this amendment may still have been
served by two deployments under one permaslug, or by another dated model in
its null rows. That limit is written down here, before the numbers.

## The reason

A cell's rows are its evidence about one thing: the provider's failure rate on
one model through one channel. When the dated model behind the slug
changes partway through, the rows describe two things. A bound over them is then
a bound on a mixture, weighted by when the change happened. A pin taken on it
licenses whichever dated model serves next, and none of the rows may describe
that one. That is a false rule-in of the silent kind, the error §2's asymmetry is
built against.

Three alternatives are not taken. #387 rejected the first and the third, and the
cell's identity rules out the second:

- **Fail the cell.** R4 would make that final, and a provider would be failed
  for something the router or the lab did. *Failed* is a claim about a rate,
  and no rate was measured.
- **Split the cell by permaslug.** That makes the permaslug part of the cell's
  identity, but the model in a cell is the `ModelNames` value, by the
  *Acceptance cell* entry and R-h. A split would also let a cell be cut, after
  its rows exist, into the part that looks good.
- **Snapshot the catalogue per run.** #387 rejected it: `/endpoints` cannot be
  joined to a call, so a snapshot dates a change to a run at best and attributes
  it to no row.

The mixed outcome blocks rule-in and leaves rule-out alone. That is the
revisability asymmetry §3 grounds peeking on. A false rule-out on mixed rows
corrects itself in rotation, and a false rule-in on them seals itself as a pin.

**Three cases decided while writing this**, by Bertan on 2026-11-17 under #399,
because #387's clauses left each open to more than one reading: null rows count
toward n and never mix; a re-test row carrying another permaslug makes the
re-test mixed; and a repoint that no commit carries reads as mixed.

**Written before the first acquisition call**, with zero provider-attributed rows
in hand. This file is carried by a commit, and that commit can be ordered
against the commit of any acquisition row, as with the rest of this document.

---

# Amendment — an organic cell's no-response share charges every unattributed attempt to the candidate

| | |
|---|---|
| amended | 2026-11-25 |
| branch | `dev-06` |
| commit at amendment | `63396fb71661` |
| decided in | [#391 — The organic no-response share can be cleared by dilution: does the gate need more than a (model, channel) read?](https://github.com/bgunyel/clause-and-effect/issues/391) |
| written by | [#404](https://github.com/bgunyel/clause-and-effect/issues/404), under map [#6](https://github.com/bgunyel/clause-and-effect/issues/6) |
| amends | four passages of the [acceptable-set amendment](#amendment--acceptable-set-membership-needs-a-cleared-no-response-share-not-rule-in-alone): the share's ratio, the level it is read at, the reason given for that level, and its *The trade, recorded* |
| status of the data | none — written before the first acquisition call; `record_attempt` still has no caller in `src/`, so `llm_attempt` has never held a row |

**This is an amendment, not a registration**, under the guard in [§The two kinds
of append](#the-two-kinds-of-append). The acceptable-set amendment says the
organic share *"is read at the **`(model, channel)`** level"*. Under that
sentence every cell of a `(model, channel)` reads one share. After this
amendment each cell reads its own, so the sentence would have meant something
different, and it owes an old value. Three other passages of the same amendment
state that level or rest on it. They owe old values for the same reason, and all
four are given below.

The acceptable-set amendment recorded the limit this closes, under *The trade,
recorded*. Read per `(model, channel)`, a provider that carries a small fraction
of its `(model, channel)`'s attempts can be let through by its neighbours' clean
attempts. Its no-response attempts are diluted below the tolerance, nothing
triggers a forced acquisition, and the silent false rule-in the gate was decided
to close stays open for that provider. #391 decided how to close it, and this
amendment writes that decision.

**What stands unamended**, each with its reason:

- **R-g.** Unchanged, including its attempt-level count in three buckets,
  printed beside every cell of the `(model, channel)`. The count stays per
  `(model, channel)`. Only the share read from it moves to the cell.
- **§2's rule-in, and R3 as amended.** The share gates what a rule-in licenses.
  Neither the bar nor when it is read changes.
- **The acceptable-set amendment's numerator sentence**, *"Its numerator is
  every attempt no provider served, whatever its bucket, so for organic
  acquisition it is the sum of R-g's three buckets."* Still true. A, below, is
  that sum.
- **Its *clears* bullet.** The bound and its level do not move here: the
  Clopper-Pearson upper bound, 95% one-sided, below the §1 tolerance in force.
  [#400 — Does the no-response share's bound take R-c's Bonferroni correction,
  or stay at 95%?](https://github.com/bgunyel/clause-and-effect/issues/400)
  decided that the level moves to α/m, and [#407 — Append the share-level
  amendment: the no-response share is read at α/m over the named
  set](https://github.com/bgunyel/clause-and-effect/issues/407) writes it. Every
  bound below is at the level the acceptable-set amendment states.
- **Its last bullet.** A cell that rules in and whose share does not clear is
  still *"rule-in, no-response unresolved"*. It is not a member, and a config pin
  on it still needs a forced acquisition whose per-cell share clears. When the
  share is read, and over which window A and s_X are counted, [#392 — When is
  the no-response share read, and what n does a forced clearing acquisition
  declare?](https://github.com/bgunyel/clause-and-effect/issues/392) decided,
  and [#405 — Append the share-timing amendment: the no-response share is read
  once, where rule-in is read, and a forced acquisition decides membership
  alone](https://github.com/bgunyel/clause-and-effect/issues/405) writes it.
  Whether an organic read can admit a member at all, [#408 — Does clearing the
  no-response share by organic read, then by forced run, buy a second chance at
  α/m?](https://github.com/bgunyel/clause-and-effect/issues/408) decided, and
  [#411 — Append the forced-membership amendment: only a forced acquisition
  admits a member, and the organic share is report-only](https://github.com/bgunyel/clause-and-effect/issues/411)
  writes it.
- **The forced read.** It was already per cell, and it is unchanged. Forced and
  organic never pool.
- **Its rejected alternative *Worst-case attribution*.** It records what #371
  rejected and why, and it is still true of the consequence it names. This
  amendment takes the same arithmetic without that consequence. *Why this is not
  the worst-case attribution #371 rejected*, below, says why.

§1 and §2 as amended, R1, R2, R3 as amended, R4–R6, §4 as amended, §5 to §9,
R4's pressure point as amended, R-a, R-b as amended, R-c as amended twice, R-d
to R-i, and the mixed-cell amendment all stand.

## The old value

From the acceptable-set amendment, verbatim, four passages. Each is quoted
whole, with its own markup, so that it can be found.

**The share's ratio**, its first bullet:

> - The **no-response share** is non-served attempts over all attempts. Its
>   numerator is every attempt no provider served, whatever its bucket, so for
>   organic acquisition it is the sum of R-g's three buckets.

The words that change are *"non-served attempts over all attempts"*. Read per
cell under organic routing, *all attempts* would be the cell's own, and an
organic cell's own non-served attempts cannot be counted, because they name no
provider. The second sentence stands.

**The level**, its third bullet:

> - It is read at the **`(model, channel)`** level for organic acquisition and
>   **per cell** for forced acquisition. Forced and organic never pool.

**The reason for the level**, from its *The reason*:

> The organic share is read at `(model, channel)` level because an organic
> no-response attempt names no provider, so it cannot be charged to one cell. The
> forced acquisition is the way out of that bluntness, because under a pin the
> attempt belongs to the cell's condition.

**The dilution paragraph**, from the same section:

> **The trade, recorded.** #371 judged the organic read blunt but safe. It is safe
> in one direction only. A provider can be held back by its neighbours' timeouts,
> and it can also be **let through by its neighbours' clean attempts** when it
> carries a small fraction of its `(model, channel)`'s attempts. In the case
> above, a provider with 19 no-response attempts of 48 has a share whose upper
> bound is 52.5% on its own. Pooled with 300 clean attempts from other providers
> on the same `(model, channel)`, it is 19/348 with an upper bound of 7.9%, which
> clears a 10% tolerance. Pooled with 1000, it is 19/1048 with an upper bound of
> 2.7%, which clears 5% too. The organic gate then passes, nothing triggers a
> forced acquisition, and the silent false rule-in this amendment was decided to
> close stays open for that provider. The rule above is registered as decided.
> Its limit is recorded here, so that the commitment does not claim a safety it
> lacks. Whether the gate needs more than a `(model, channel)` read belongs to
> [#391 — The organic no-response share can be cleared by dilution: does the gate
> need more than a (model, channel) read?](https://github.com/bgunyel/clause-and-effect/issues/391),
> and any change it makes is a further amendment, owed before the first
> acquisition call.

#391 named the level bullet and the dilution paragraph. The assistant, writing
this under #404, read the rest of the acceptable-set amendment under the guard
and found two more passages whose meaning a per-cell read changes: the share's
ratio and the reason given for the level.

## The new value

**The share's ratio.** The first bullet now reads:

> - The **no-response share** is a cell's non-served attempts over its
>   non-served and served attempts, counted as the read bullet below says for
>   each regime. Its numerator is every attempt no provider served, whatever its
>   bucket, so for organic acquisition it is the sum of R-g's three buckets.

**The level.** The third bullet now reads:

> - It is read **per cell** under both regimes. Forced and organic never pool.
>   - **Forced acquisition.** The cell's non-served attempts under the pin, over
>     all its attempts under the pin, as before.
>   - **Organic acquisition.** Cell X's share is **A / (s_X + A)**. **A** is
>     every attempt on X's `(model, channel)` whose `served_provider` is null,
>     in all three of R-g's buckets. **s_X** is the attempts X's provider served
>     under organic routing, clean or not, counted per attempt and not per call.

A cell whose share does not clear reads *"rule-in, no-response unresolved"* and
needs a forced acquisition, as the last bullet already says.

**The reason for the level** now reads:

> Both regimes read the share per cell. An organic no-response attempt names no
> provider, so it cannot be charged to the one cell it belongs to, and it is
> charged to every candidate instead. The forced acquisition is the way out of
> that bluntness, because under a pin the attempt belongs to the cell's
> condition.

**The dilution paragraph** now reads:

> **Dilution, closed by construction.** Let a_X be the attempts in A that were
> in fact routed to X, so a_X ≤ A. X's own share is a_X / (s_X + a_X), which
> increases with a_X, so no split of the unattributed attempts makes X look
> worse than the read A / (s_X + A). Other providers' clean attempts are not in
> s_X, so they cannot dilute it. The case above, a provider with 19 no-response
> attempts of 48, has s_X = 29 and A ≥ 19, whatever its neighbours carry. Its
> share is at least 19/48, with an upper bound of 52.48%. That case uses n = 29,
> which is uncorrected. At the corrected rule-in n of 61 it reads at least
> 19/80, with an upper bound of 32.87%. Neither clears either tolerance. The
> trade this read makes in place of dilution is recorded in this amendment.

The same holds of the bound the gate reads, not only of the ratio. At fixed s,
the Clopper-Pearson upper bound on k of s + k is `beta.ppf(0.95, k + 1, s)`, and
Beta(k + 1, s) is stochastically increasing in k. #391 checked this numerically
for s in 20..200 and k in 0..40. It was checked again for this amendment for s
in 1..400 and k in 0..199, with no exception.

## The reason

Without this amendment the acceptable-set amendment's gate is open in the case
it was decided for. A provider that gets no response on a large part of its
attempts, but carries a small part of its `(model, channel)`'s attempts, reads a
pooled share below the tolerance. No forced acquisition is triggered. A pin on
it is a false rule-in of the silent kind, the error §2's asymmetry is built
against.

**Bounds at the corrected rule-in n.** The Clopper-Pearson upper bound on A of
s + A, **95% one-sided, the level the acceptable-set amendment states**.
s = 61 and s = 125 are the m = 29 row of the Bonferroni amendment's table of n,
under the 10% and 5% branches. Recomputed for this amendment with
`scipy.stats.beta.ppf(0.95, k + 1, n - k)` at k = A and n = s + A:

| A | s = 61, 10% | clears | s = 125, 5% | clears |
|---:|---:|---|---:|---|
| 0 | 4.79% | yes | 2.37% | yes |
| 1 | 7.42% | yes | 3.71% | yes |
| 2 | 9.66% | yes | 4.87% | yes |
| 3 | 11.67% | no | 5.95% | no |
| 19 | 32.87% | no | 18.76% | no |

In practice the organic read clears only on a `(model, channel)` that is nearly
free of no-response attempts. Otherwise it routes the candidate to a forced
acquisition.

**Why this is not the worst-case attribution #371 rejected.** #371 rejected
charging every organic no-response attempt to every cell for its consequence:
it *"turns one organic timeout into a rule-out across a whole
`(model, channel)`"*. Under the acceptable-set amendment a share that does not
clear is never a rule-out. It is only *"rule-in, no-response unresolved"*, so
the same arithmetic now costs a forced run and nothing more. At the 95% level this
amendment inherits, one timeout still clears at both tolerances, the A = 1 row
above. #400 decided that the level moves to α/m, and #407, which writes that,
gives this property up explicitly.

Three alternatives are not taken. #391 rejected each:

- **Accept the limit.** It leaves the silent false rule-in open.
- **A forced acquisition for every candidate.** It is never safer than the read
  above, and it always costs more.
- **The largest plausible per-provider share, from pool exposure.** It cannot be
  computed. An attempt that fails at the HTTP level writes no pool, as R-d's
  *Why observed* says.

**The trade, recorded.**

> **A ignores attribution.** `served_provider` is phase 1 and is read from the
> response body only. So a no-response attempt that the enrichment sweep later
> traces to a provider through `routing_chain` still has a null
> `served_provider`. It stays in A and is charged to every candidate, the
> provider it was traced to included. Such a trace is possible only if the
> header `generation_id` survives a timeout, and that is unobserved.

Precision is given up so that the gate never depends on enrichment being right.
A candidate can be sent to a forced acquisition by a timeout the log could have
placed on another provider. That costs calls and never makes a false rule-in,
which is the direction §2's asymmetry prefers. The limit is written down here,
before the numbers.

**Written before the first acquisition call**, with zero provider-attributed rows
in hand. This file is carried by a commit, and that commit can be ordered
against the commit of any acquisition row, as with the rest of this document.

---

# Amendment — the no-response share is read once, where rule-in is read, and a forced acquisition decides membership alone

| | |
|---|---|
| amended | 2026-11-25 |
| branch | `dev-06` |
| commit at amendment | `5b6290ffe2d7` |
| decided in | [#392 — When is the no-response share read, and what n does a forced clearing acquisition declare?](https://github.com/bgunyel/clause-and-effect/issues/392) |
| written by | [#405](https://github.com/bgunyel/clause-and-effect/issues/405), under map [#6](https://github.com/bgunyel/clause-and-effect/issues/6) |
| amends | two bullets of the [acceptable-set amendment](#amendment--acceptable-set-membership-needs-a-cleared-no-response-share-not-rule-in-alone): its last bullet, and its read bullet as the [dilution amendment](#amendment--an-organic-cells-no-response-share-charges-every-unattributed-attempt-to-the-candidate) left it |
| status of the data | none — written before the first acquisition call; `record_attempt` still has no caller in `src/`, so `llm_attempt` has never held a row |

**This is an amendment, not a registration**, under the guard in [§The two kinds
of append](#the-two-kinds-of-append). The acceptable-set amendment's last bullet
says that a config pin on a cell whose share does not clear *"needs a **forced
acquisition** whose per-cell share clears"*. Under that sentence the forced run
settles the share and nothing else, so the organic rule-in keeps licensing the
pin. After this amendment the forced run's own rule-in decides as well, so the
sentence would have meant something different, and it owes an old value. The
read bullet owes one too. It counts *"all its attempts under the pin"* and
*"every attempt on X's `(model, channel)`"*, with no point at which the count
stops, and this amendment gives the count an end.

R-g left open when the share is read and what n a forced acquisition declares,
and named #392 for both. The acceptable-set and dilution amendments say what the
share is and per what it is read. Neither says when it is read or over which
attempts. This amendment writes #392's answer.

**What stands unamended**, each with its reason:

- **§2's rule-in, and R3 as amended.** The share is now read where rule-in is
  read. Neither the bar nor the point at which rule-in is evaluated moves.
- **R4.** A forced rule-in that fails is failed under R4 as written. §2 counts a
  cell's n within a regime, never across, so the failure is the forced regime's.
- **R5.** Rule-out peeks stay unrestricted, the forced rows included. The early
  stop below is not a rule-out. It is recorded the way R5 records one, and it
  says that the share cannot clear, not that the rate is bad.
- **R6 and R-i.** R6 says what re-testing a **failed** cell requires. An
  unresolved forced share is not a failed cell. The finality clause below
  requires the same of it on R6's terms, so no sentence of R6 changes meaning.
  R-i says which rows a re-test counts, and a further forced acquisition counts
  those.
- **R-g**, including its three buckets, its deadline clause and its *"read only
  once enrichment has finished"*. `served_provider` and `http_status` are
  phase 1, so the values counted at the rule-in point are the values the log
  holds once enrichment has finished.
- **The share's definition, as the dilution amendment leaves it.** That is the
  ratio bullet, its numerator sentence, the *clears* bullet and the reason given
  for the level. The ratio bullet already counts the share *"as the read bullet
  below says for each regime"*, and the read bullet is where the window goes.
- **The dilution amendment's** *"A cell whose share does not clear reads
  "rule-in, no-response unresolved" and needs a forced acquisition, as the last
  bullet already says."* It reads through to the last bullet, which is amended
  below.
- **The Bonferroni amendment's** *"Nothing waits for the acquisition window to
  close"*, and its *"m no longer needs a close. R-d's pin and acceptable-set
  reads still do."* The share now waits on no close either. R-d's acceptable-set
  read reports the headroom the observed pools offer, not membership, so it is
  still taken over the whole window.

§1 and §2 as amended, R1, R2, R3 as amended, R4–R6, §4 as amended, §5 to §9,
R4's pressure point as amended, R-a, R-b as amended, R-c as amended twice, R-d
to R-i, the mixed-cell amendment and the dilution amendment all stand.

## The old value

From the acceptable-set amendment, verbatim, two bullets. Each is quoted whole,
with its own markup, so that it can be found.

**The read bullet**, as the dilution amendment left it:

> - It is read **per cell** under both regimes. Forced and organic never pool.
>   - **Forced acquisition.** The cell's non-served attempts under the pin, over
>     all its attempts under the pin, as before.
>   - **Organic acquisition.** Cell X's share is **A / (s_X + A)**. **A** is
>     every attempt on X's `(model, channel)` whose `served_provider` is null,
>     in all three of R-g's buckets. **s_X** is the attempts X's provider served
>     under organic routing, clean or not, counted per attempt and not per call.

The words that change are *"all its attempts under the pin"*, *"every attempt on
X's `(model, channel)`"* and *"the attempts X's provider served under organic
routing"*. Read as written, each takes in attempts made after the cell reached
its n.

**The last bullet:**

> - A cell that rules in and whose share does not clear is reported as
>   **"rule-in, no-response unresolved"**. It is not a member. A config pin on
>   it needs a **forced acquisition** whose per-cell share clears.

The words that change are *"A config pin on it needs a **forced acquisition**
whose per-cell share clears"*. The first two sentences stand.

#405's checklist named the last bullet. The assistant, writing this under #405,
read the rest of the acceptable-set amendment under the guard and found the read
bullet's three phrases as well.

## The new value

**The read bullet** now reads:

> - It is read **per cell** under both regimes, **once**, at the cell's
>   **rule-in point**: the attempt that brings the cell to its declared n. It is
>   counted over the rows rule-in reads there, under one condition: the channel
>   (R-e), the `ModelNames` value (R-h) and the deadline in force (R-g), and for
>   a re-test only R-i's rows. Forced and organic never pool.
>   - **Forced acquisition.** The cell's non-served attempts under the pin, over
>     all its attempts under the pin, from the forced acquisition's first call
>     to its rule-in point.
>   - **Organic acquisition.** Cell X's share is **A / (s_X + A)**. **A** is
>     every attempt on X's `(model, channel)` whose `served_provider` is null,
>     in all three of R-g's buckets. **s_X** is the attempts X's provider served
>     under organic routing, clean or not, counted per attempt and not per call.
>     Both are counted from the first organic acquisition call on the
>     `(model, channel)` to X's rule-in point.
>   - The share is never read again on later rows. An organic share that does
>     not clear at the rule-in point stays unresolved for the organic regime.
>   - A **mixed** cell reads no share, because R3 is not evaluated on it.

**The last bullet** now reads:

> - A cell that rules in and whose share does not clear is reported as
>   **"rule-in, no-response unresolved"**. It is not a member. A config pin on
>   it needs a **forced acquisition**, and **membership is then read from the
>   forced acquisition alone**: its rule-in and its share, both read once, at
>   its rule-in point, on its rows.
>   - The forced acquisition is an ordinary measurement pin. It declares the
>     family's R2 n before its first call, uses the case list's first n cases,
>     as every cell of the family does, and runs to n served calls.
>   - The organic result is reported beside the forced one. Once its share was
>     unresolved, it licenses nothing on its own.
>   - A forced rule-in that fails is failed under R4, for the forced regime.
>   - **An unresolved forced share is final.** It is not extended. Another
>     forced acquisition needs a cause recorded before it under R6. It counts
>     only R-i's rows, under its own R2 n.
>   - **The early stop.** Let A be the forced acquisition's non-served
>     attempts so far. The run stops at the non-served attempt that brings A to
>     **k\***, the smallest k for which the share's upper bound on k non-served
>     attempts of n + k, at the level the share is read at, is at or above the
>     §1 tolerance t. The cell reads *"rule-in, no-response unresolved"*. The
>     stop is recorded with the attempt count, the served count and the A at
>     which it was taken. Rule-out peeks on the forced rows stay unrestricted
>     under R5.

A cell measured under a measurement pin from the start is read under the forced
regime throughout. Its own reads are the forced reads, and it needs no second
run. So the share has one rule in both regimes: it is read where rule-in is read.

**k\* at the level the acceptable-set amendment states**, 95% one-sided.
Recomputed for this amendment with `scipy.stats.beta.ppf(0.95, k + 1, n)` for k
non-served attempts of n + k, at the m = 29 row of the Bonferroni amendment's
table of n:

| A | n = 61, t = 10% | clears | n = 125, t = 5% | clears |
|---:|---:|---|---:|---|
| 2 | 9.66% | yes | 4.87% | yes |
| 3 | 11.67% | no | 5.95% | no |

So k\* is 3 in both columns: the run stops at its 3rd non-served attempt. The
table is illustrative. The formula binds, so a change in the level the share is
read at carries through it.

**Two cases that follow from the definitions above.** Each is written down here
so that it is not settled after the rows exist:

- **Every unresolved forced share is an early stop.** At the rule-in point the
  served count is n, and at fixed s the bound rises with A. The dilution
  amendment checked that for s in 1..400 and k in 0..199, and it was checked
  again for this amendment over the same grid, with no exception. A forced run
  that reaches its rule-in point has A below k\*, so its share clears. The early
  stop is the only way a forced share is unresolved.
- **A forced run that stops early does not evaluate its rule-in.** It never
  reaches its declared n, so R3 is not evaluated on it and R4 does not fire, as
  with a mix found before n. A cell that ruled in organically keeps that
  organic rule-in, which licenses nothing on its own. A cell measured under a
  pin from the start has no rule-in to report, and reads *"no-response
  unresolved"*.

## The reason

**Why once, and why at the rule-in point.** A share that can be read again
later is stopping on good news, because waiting lets clean traffic grow s while
A stands still. At the 95% level the acceptable-set amendment states, a provider
at s = 125 with A = 3 has a bound of 5.95% and does not clear 5%. The same
provider at s = 250 with A = 4 has 3.57%, and clears. The argument does not
depend on the level. Reading the share where rule-in is read ties the stopping
point to X's served count, which the share does not decide. A no-response
attempt can only move the point later, and it adds to A on the way, which is the
safe direction.

**Why the forced acquisition decides membership alone.** A run that reads only
the share and keeps the organic rule-in costs the same number of calls. It would
see a structure failure under the pin and ignore it for membership, unless the
failures came two in a row and R5 ruled the cell out. Read under the pin, the
rule-in and the share describe the same condition.

**Why the forced n is R2's n, whatever the share's level.** With no non-served
attempt, the share's upper bound at a level 1 − α′ is below t exactly when
(1 − t)ⁿ < α′. R2's n is the smallest n with (1 − t)ⁿ ≤ 0.05 / m, and the
Bonferroni amendment shows that equality never occurs at either tolerance. So
at R2's n,
(1 − t)ⁿ < 0.05 / m ≤ 0.05, and a forced share with no non-served attempt
clears at 95% and at α/m alike. The share's zero-failure threshold is 29 at 10%
and 59 at 5% under 95%, and 61 and 125 under α/29. R2's n for m = 29 is 61 and
125. The forced n does not wait on #400.

**Why an unresolved forced share is final.** It is R4's mirror for the share:
*"we just need a few more attempts"* is the same comfortable thing to say. A
different deadline is already a different condition under R-g, and is never
pooled with this one.

**Why the early stop is not a peek.** Once A reaches k\*, the outcome is fixed.
The served count at the read point is n, and A can only grow. Stopping changes
no outcome, as with a mix found before n, and running on would spend calls on a
read whose answer is known.

Two alternatives are not taken. #392 rejected each:

- **Read the share at the acquisition window's close.** The window is still
  fog, and #377 removed every dependence on its close except R-d's.
- **A share-only clearing run that keeps the organic rule-in.** It costs the
  same number of calls, and it would ignore a forced structure failure short of
  R5's two in a row.

**Not decided here.**

- **The share's level.** [#400 — Does the no-response share's bound take R-c's
  Bonferroni correction, or stay at 95%?](https://github.com/bgunyel/clause-and-effect/issues/400)
  decided that it moves to α/m, and [#407 — Append the share-level amendment:
  the no-response share is read at α/m over the named
  set](https://github.com/bgunyel/clause-and-effect/issues/407) writes it. Every
  bound above is at the level the acceptable-set amendment states.
- **Whether an organic read can admit a member at all.** [#408 — Does clearing
  the no-response share by organic read, then by forced run, buy a second chance
  at α/m?](https://github.com/bgunyel/clause-and-effect/issues/408) decided that
  only a forced acquisition admits one, and [#411 — Append the forced-membership
  amendment: only a forced acquisition admits a member, and the organic share is
  report-only](https://github.com/bgunyel/clause-and-effect/issues/411) writes
  it. This amendment reads membership from the forced acquisition for the cells
  #392 named: an organic rule-in whose share does not clear, and a cell pinned
  from the start.
- **What level a further forced acquisition is read at.** It is a re-test, and
  [#397 — Does an R6 re-test add to R-c's m, or does each re-test buy a free
  chance at rule-in?](https://github.com/bgunyel/clause-and-effect/issues/397)
  decided how re-tests spend α. [#413 — Append the re-test reserve
  amendment](https://github.com/bgunyel/clause-and-effect/issues/413) writes it.
- **The case list's length.** [#401 — What n does a cell get when R1 names more
  providers than the 125-case draw supports?](https://github.com/bgunyel/clause-and-effect/issues/401)
  decided to extend it to all 433 Tier-1 cases, and [#409 — Append the
  case-list amendment](https://github.com/bgunyel/clause-and-effect/issues/409)
  writes it. Positions 1–125 do not move, so *"the case list's first n cases"*
  names the same cases for every n the 125 supply.

**Written before the first acquisition call**, with zero provider-attributed rows
in hand. This file is carried by a commit, and that commit can be ordered
against the commit of any acquisition row, as with the rest of this document.

---

# Amendment — the no-response share is read at α/m over the named set, the level rule-in is read at

| | |
|---|---|
| amended | 2026-11-25 |
| branch | `dev-06` |
| commit at amendment | `1cbc4eda388f` |
| decided in | [#400 — Does the no-response share's bound take R-c's Bonferroni correction, or stay at 95%?](https://github.com/bgunyel/clause-and-effect/issues/400) |
| written by | [#407](https://github.com/bgunyel/clause-and-effect/issues/407), under map [#6](https://github.com/bgunyel/clause-and-effect/issues/6) |
| amends | the [acceptable-set amendment](#amendment--acceptable-set-membership-needs-a-cleared-no-response-share-not-rule-in-alone)'s *clears* bullet; one sentence of the [Bonferroni amendment](#amendment--the-multiplicity-correction-is-bonferroni-over-the-named-set-and-the-draw-grows-to-125-cases)'s *Not decided here*; and every passage of the [dilution amendment](#amendment--an-organic-cells-no-response-share-charges-every-unattributed-attempt-to-the-candidate) and the [share-timing amendment](#amendment--the-no-response-share-is-read-once-where-rule-in-is-read-and-a-forced-acquisition-decides-membership-alone) that states the share's level, or reads a consequence of it |
| status of the data | none — written before the first acquisition call; `record_attempt` still has no caller in `src/`, so `llm_attempt` has never held a row |

**This is an amendment, not a registration**, under the guard in [§The two kinds
of append](#the-two-kinds-of-append). The acceptable-set amendment says the
share clears when its Clopper-Pearson upper bound, *"95% one-sided"*, is below
the tolerance in force. After this amendment the bound is read at α/m, so the
sentence would have meant something different, and it owes an old value.

The later amendments owe old values for two reasons. Some passages state a 95%
bound, or a consequence of one, as the bound the gate reads. Five others name
the share's level by pointing at the acceptable-set amendment, as *"the level
the acceptable-set amendment states"* or *"the 95% level"* it states. That
phrase meant 95% when each was written. This amendment changes what it would
mean, so those passages would mean something different too.

The Bonferroni amendment corrected the rule-in bound only. It left the share's
level to [#400](https://github.com/bgunyel/clause-and-effect/issues/400). #400
decided that the share takes the same correction, and this amendment writes that
decision.

**What stands unamended**, each with its reason:

- **§2's rule-in, R3 as amended, and R-c as amended twice.** The share is now
  read at their level. The bar, the point at which it is read, and m do not
  move.
- **Rule-out.** It stays uncorrected, at 2 consecutive failures, for the
  Bonferroni amendment's reason. A share that does not clear is never a
  rule-out.
- **R-g.** Its buckets, its deadline clause and its count name no level.
- **The share's definition and its reads.** These are the ratio bullet and its
  numerator sentence as the dilution amendment left them, and the read bullet
  and the last bullet as the share-timing amendment left them. None of them
  names a level. The share is still read per cell, once, at the rule-in point.
- **The share-timing amendment's early stop.** It defines k\* at *"the level the
  share is read at"*, so the level carries through and the wording does not
  change. Only the illustrative table and the sentence that reads k\* off it owe
  old values.
- **The share-timing amendment's *Why the forced n is R2's n, whatever the
  share's level*.** It argues both levels, and it already states the thresholds
  under α/29, 61 and 125. Recomputed for this amendment, the smallest n whose
  zero-failure bound at 1 − 0.05/29 is below t is 61 at 10% and 125 at 5%. That
  is R2's n for m = 29.
- **The bound rises with k at any level.** The dilution amendment's bound
  sentence and the share-timing amendment's *Every unresolved forced share is an
  early stop* rest on this. Beta(k + 1, s) is stochastically increasing in k, so
  every quantile of it is too. It was checked numerically for this amendment at
  every level 1 − 0.05/m for m in 1..31, for s in 1..400 and k in 0..199, with
  no exception.
- **The dilution paragraph's 52.48%.** Its case uses n = 29, which is §2's n at
  m = 1. At m = 1, α/m is 0.05, so the level is 95% and the bound is the one the
  gate reads for that m.
- **The arguments that hold at any level.** The share-timing amendment's
  re-read example says *"The argument does not depend on the level"* of itself.
  The dilution amendment's *Why this is not the worst-case attribution #371
  rejected* holds at any level: a share that does not clear costs a forced run
  and is never a rule-out. Only the sentences of each that state the level, or
  read the A = 1 row, are owed below.

§1 and §2 as amended, R1, R2, R3 as amended, R4–R6, §4 as amended, §5 to §9,
R4's pressure point as amended, R-a, R-b as amended, R-c as amended twice, R-d
to R-i and the mixed-cell amendment all stand. So do the dilution and
share-timing amendments, except for the passages quoted below.

## The old value

Each passage verbatim, with its own markup, so that it can be found.

**From the acceptable-set amendment**, its *clears* bullet:

> - It **clears** when its Clopper-Pearson upper bound, 95% one-sided, is below
>   the §1 tolerance in force. That is the same bound and the same reading as
>   §2's rule-in, applied to a different quantity.

The words that change are *"95% one-sided"*. The second sentence stands, and
after this amendment it holds of the level too.

**From the Bonferroni amendment**, its *Not decided here*, on the share:

> So the share's bound stays at 95% as that amendment states it, and the second
> sentence no longer holds of the level.

**From the dilution amendment**, five passages.

The last sentence of its *What stands* bullet on the *clears* bullet:

> Every bound below is at the level the acceptable-set amendment states.

The sentences of its dilution paragraph that bound the case:

> Its share is at least 19/48, with an upper bound of 52.48%. That case uses
> n = 29, which is uncorrected. At the corrected rule-in n of 61 it reads at
> least 19/80, with an upper bound of 32.87%. Neither clears either tolerance.

The words that change are *"with an upper bound of 32.87%"*. The rest stands.

Its bound sentence:

> At fixed s, the Clopper-Pearson upper bound on k of s + k is
> `beta.ppf(0.95, k + 1, s)`, and Beta(k + 1, s) is stochastically increasing
> in k.

Its *Bounds at the corrected rule-in n*, with the table and the sentence after
it:

> **Bounds at the corrected rule-in n.** The Clopper-Pearson upper bound on A of
> s + A, **95% one-sided, the level the acceptable-set amendment states**.
> s = 61 and s = 125 are the m = 29 row of the Bonferroni amendment's table of n,
> under the 10% and 5% branches. Recomputed for this amendment with
> `scipy.stats.beta.ppf(0.95, k + 1, n - k)` at k = A and n = s + A:
>
> | A | s = 61, 10% | clears | s = 125, 5% | clears |
> |---:|---:|---|---:|---|
> | 0 | 4.79% | yes | 2.37% | yes |
> | 1 | 7.42% | yes | 3.71% | yes |
> | 2 | 9.66% | yes | 4.87% | yes |
> | 3 | 11.67% | no | 5.95% | no |
> | 19 | 32.87% | no | 18.76% | no |
>
> In practice the organic read clears only on a `(model, channel)` that is nearly
> free of no-response attempts. Otherwise it routes the candidate to a forced
> acquisition.

The table's numbers are 95% bounds, and they are still true as such. What
changes is the label, which named the level in force, the *clears* columns,
which read the gate, and *"nearly free"*.

Its A = 1 sentence:

> At the 95% level this amendment inherits, one timeout still clears at both
> tolerances, the A = 1 row above. #400 decided that the level moves to α/m, and
> #407, which writes that, gives this property up explicitly.

**From the share-timing amendment**, three passages.

Its k\* table, with the sentence after it:

> **k\* at the level the acceptable-set amendment states**, 95% one-sided.
> Recomputed for this amendment with `scipy.stats.beta.ppf(0.95, k + 1, n)` for k
> non-served attempts of n + k, at the m = 29 row of the Bonferroni amendment's
> table of n:
>
> | A | n = 61, t = 10% | clears | n = 125, t = 5% | clears |
> |---:|---:|---|---:|---|
> | 2 | 9.66% | yes | 4.87% | yes |
> | 3 | 11.67% | no | 5.95% | no |
>
> So k\* is 3 in both columns: the run stops at its 3rd non-served attempt. The
> table is illustrative. The formula binds, so a change in the level the share is
> read at carries through it.

The words that change are the label, the *clears* columns, and *"So k\* is 3 in
both columns: the run stops at its 3rd non-served attempt"*. The last two
sentences stand.

The first sentence of its re-read example:

> At the 95% level the acceptable-set amendment states, a provider at s = 125
> with A = 3 has a bound of 5.95% and does not clear 5%.

The last sentence of its *Not decided here* bullet on the share's level:

> Every bound above is at the level the acceptable-set amendment states.

#407's checklist named the *clears* bullet, the Bonferroni amendment's sentence,
the dilution amendment's A = 1 sentence and its table. A comment on #407 added
the share-timing amendment's k\* table and its *"So k\* is 3"* sentence. The
assistant, writing this under #407, read both later amendments in full under the
guard and found five more passages. They are the dilution amendment's *What
stands* sentence, its 32.87%, its bound sentence, and the share-timing
amendment's re-read sentence and *Not decided here* sentence.

The comment on #407 judged the re-read example as owing nothing, because its
level is not stated as the level in force. That is true of its numbers, which
are labelled 95% and stand. The assistant quoted it anyway, because the label
names the acceptable-set amendment as the source of 95%, and after this
amendment that source no longer says 95%.

## The new value

**The *clears* bullet** now reads:

> - It **clears** when its Clopper-Pearson upper bound, one-sided at **α/m**
>   with α = 0.05, is below the §1 tolerance in force. **m is R1's named count**
>   for the cell's `(model, channel)`, fixed at R1: the m of R-c as amended. The
>   level is the same under both regimes. That is the same bound, the same level
>   and the same reading as §2's rule-in, applied to a different quantity.
> - Rule-in and the share are each read at α/m. **α is not split** between them.

**The Bonferroni amendment's sentence** no longer holds. The share's bound is
corrected at the same α/m as rule-in, so the acceptable-set amendment's second
sentence holds of the level again.

**The phrase *"the level the acceptable-set amendment states"***, wherever an
amendment written before this one uses it, means **95% one-sided**, the level
that amendment stated when the phrase was written. Every bound it labels is a
95% bound and is still true as one. None of them is the level in force. That
covers the dilution amendment's *What stands* sentence and its table label, and
the share-timing amendment's k\* label, its re-read sentence and its *Not decided
here* sentence.

**The dilution amendment's case** now reads *"At the corrected rule-in n of 61
it reads at least 19/80, with an upper bound of 39.94% at α/29."* At m = 29 the
corrected n is 61, so the level is α/29. It still does not clear either
tolerance.

**The bound sentence** now reads *"At fixed s, the Clopper-Pearson upper bound on
k of s + k is `beta.ppf(1 − α/m, k + 1, s)`, and Beta(k + 1, s) is
stochastically increasing in k."*

**Bounds at the corrected rule-in n, at α/m.** These are the Clopper-Pearson
upper bounds on A of s + A, one-sided at α/29. s = 61 and s = 125 are the m = 29
row of the Bonferroni amendment's table of n, under the 10% and 5% branches.
Recomputed for this amendment with `scipy.stats.beta.ppf(1 − 0.05/29, k + 1, n − k)`
at k = A and n = s + A. The 95% columns repeat the dilution amendment's bounds,
which were recomputed and are unchanged. Each *clears* column reads the bound at
α/29:

| A | s = 61, 10%, at 95% | at α/29 | clears | s = 125, 5%, at 95% | at α/29 | clears |
|---:|---:|---:|---|---:|---:|---|
| 0 | 4.79% | 9.91% | yes | 2.37% | 4.96% | yes |
| 1 | 7.42% | 13.09% | no | 3.71% | 6.64% | no |
| 2 | 9.66% | 15.69% | no | 4.87% | 8.05% | no |
| 3 | 11.67% | 17.96% | no | 5.95% | 9.31% | no |
| 19 | 32.87% | 39.94% | no | 18.76% | 23.31% | no |

The sentence after the table now reads:

> **As this amendment leaves the share, an organic share read at s_X equal to
> the declared n clears only at A = 0**, that is, on a `(model, channel)` with no
> non-served attempt at all up to X's rule-in point. Otherwise it routes the
> candidate to a forced acquisition.

**The A = 1 sentence** now reads:

> At α/m one timeout does not clear at either tolerance. The A = 1 row reads
> 13.09% at s = 61 and 6.64% at s = 125, for m = 29. The property the 95% level
> gave, that one timeout still clears, is given up.

**k\* at α/m.** The share-timing amendment's k\* table now reads at α/29,
recomputed with `scipy.stats.beta.ppf(1 − 0.05/29, k + 1, n)` for k non-served
attempts of n + k, at the m = 29 row of the Bonferroni amendment's table of n:

| A | n = 61, t = 10% | clears | n = 125, t = 5% | clears |
|---:|---:|---|---:|---|
| 0 | 9.91% | yes | 4.96% | yes |
| 1 | 13.09% | no | 6.64% | no |

The sentence after it now reads *"So k\* is 1 in both columns: the run stops at
its 1st non-served attempt."* The table is still illustrative and the formula
still binds. A forced acquisition's share clears only on 0 non-served attempts:
in 61 attempts at 10%, or 125 at 5%, for m = 29.

## The reason

**Why the share takes the correction.** Membership needs two things: rule-in,
and a cleared share. A member is bad if its failure rate or its share is at or
above t. R-c's Bonferroni caps the chance of any false rule-in in the family at
α. Correcting rule-in alone caps only one of the two ways a member can be bad.
With the share at 95%, the family's share direction is capped only by m × 0.05.
At m = 29 that is 1.45, which is no cap at all. The share's direction is the
timeout case, which the acceptable-set amendment calls silent.

The counter-argument was that the organic share is read once per
`(model, channel)`, so it is not a family. That premise was lost with the
dilution amendment. Both regimes are now read per cell, so a family has m share
reads, as it has m rule-in reads.

**Why m is R1's named count.** It is rule-in's m, and it is known before the
first call, as R2 needs. Rejected: m as the number of cells that ruled in. It
depends on the data, which is #377's reason for rejecting the testable count.

**Why α is not split.** Membership is an intersection-union test: a cell is
admitted only if both reads pass. A bad cell is falsely admitted only if the
read that should catch it passes anyway, and each read makes that error with
probability at most α/m. Over the family a false admission has probability at
most m × α/m = α, so requiring both reads costs no α. An α/2m split was rejected
because it buys nothing.

**The cost, on record.** As this amendment leaves the share, an organic share at
s_X equal to the declared n clears only at A = 0. The dilution amendment's *one
timeout still clears* is given up. One non-served attempt anywhere on a
`(model, channel)` before X's rule-in point sends X to a forced acquisition. A
forced acquisition's share clears on 0 non-served attempts in 61 or 125, and the
run stops at its first non-served attempt. The cost falls on calls, and it never
makes a false rule-in, which is the direction §2's asymmetry prefers.

Three alternatives are not taken. #400 rejected each:

- **The share uncorrected, at 95%.** It leaves the share direction capped by
  m × 0.05.
- **α/2m for each read.** It buys nothing, because requiring both reads costs no
  α.
- **m as the cells that ruled in.** It depends on the data.

**Not decided here.**

- **Whether an organic read can admit a member at all.** [#408 — Does clearing
  the no-response share by organic read, then by forced run, buy a second chance
  at α/m?](https://github.com/bgunyel/clause-and-effect/issues/408) decided that
  only a forced acquisition admits a member, and that the organic share is
  report-only. [#411 — Append the forced-membership amendment: only a forced
  acquisition admits a member, and the organic share is
  report-only](https://github.com/bgunyel/clause-and-effect/issues/411) writes
  it. This amendment writes the organic share's level as #400 decided it, and
  states its organic cost of the share as this amendment leaves it.
- **What level a further forced acquisition is read at.** It is a re-test.
  [#397 — Does an R6 re-test add to R-c's m, or does each re-test buy a free
  chance at rule-in?](https://github.com/bgunyel/clause-and-effect/issues/397)
  decided how re-tests spend α, and [#413 — Append the re-test reserve
  amendment: the j-th extra evaluation in a family is read at
  α/(m·2ʲ)](https://github.com/bgunyel/clause-and-effect/issues/413) writes it.

**Written before the first acquisition call**, with zero provider-attributed rows
in hand. This file is carried by a commit, and that commit can be ordered
against the commit of any acquisition row, as with the rest of this document.

---

# Amendment — the case list covers all 433 Tier-1 cases, and a family it cannot supply is stopped

| | |
|---|---|
| amended | 2026-11-25 |
| branch | `dev-06` |
| commit at amendment | `88611bbf45b4` |
| decided in | [#401 — What n does a cell get when R1 names more providers than the 125-case draw supports?](https://github.com/bgunyel/clause-and-effect/issues/401) |
| written by | [#409](https://github.com/bgunyel/clause-and-effect/issues/409), under map [#6](https://github.com/bgunyel/clause-and-effect/issues/6) |
| amends | five passages of the [Bonferroni amendment](#amendment--the-multiplicity-correction-is-bonferroni-over-the-named-set-and-the-draw-grows-to-125-cases): its heading, its §4 sentences on the list's length and its tail, its block's `list:` line and that line's digest note, its *whole list* sentence, and its capacity paragraph |
| status of the data | none — written before the first acquisition call; `record_attempt` still has no caller in `src/`, so `llm_attempt` has never held a row |

**This is an amendment, not a registration**, under the guard in [§The two kinds
of append](#the-two-kinds-of-append). The Bonferroni amendment made the draw one
ordered list of 125 cases. This amendment lengthens that list to every Tier-1
case. A sentence that says the list holds 125 cases, or that 125 is all it can
supply, would then mean something different, so it owes an old value.

The Bonferroni amendment left open what n a cell gets when R1 names more than
30 providers for its `(model, channel)` under the 5% branch. At that m the
binding n is 126 or more, and the list held 125.
[#401](https://github.com/bgunyel/clause-and-effect/issues/401) found that the
named count is not stable. Between 2026-09-05 and 2026-11-25 the provider count
on OpenRouter's endpoints listing moved by about ten in either direction for the
roster's models. It decided to **extend the list now, over the whole
population, and never to cap m**. A family whose n the list still cannot supply
receives no call.

**What stands unamended**, each with its reason:

- **The m = 29 row of the Bonferroni amendment's table of n.** The formula that
  gives n from m is untouched, so every row of the table is still true.
- **Its cost line**, *"DeepSeek V4 Flash alone, at m = 29, needs 1,769 served
  calls …"*. It is still true at m = 29.
- **Its Šidák line.** It was measured as stated, and the measurement is still
  true.
- **Its *Why 125 distinct cases, and not 29 used again*.** The clustering
  argument holds for a list of any length. Repeats of a case are clustered
  observations, so a longer list is still a list of distinct cases.
- **Its *Not decided here* bullet on a named set larger than the list.** It
  points at #401. It is still true as history, and this amendment writes what
  #401 decided.
- **The 125 themselves and their digests.** `32547f20…` is the 96-case
  extension in draw order, and `4802ad29…` is the 125 in list order. They become
  positions 1–125 of the case list, unchanged.
- **The share-timing amendment's *"uses the case list's first n cases"*.** It
  names the list's first n positions and not its length. Positions 1–125 do not
  move, so it names the same cases for every n the 125 supplied. For a larger
  n it now names cases that exist. That amendment's *Not decided here* already
  says so. It is not on #401's list, because it was appended after #401 was
  resolved, and it was read for this amendment under the guard.

§1 and §2 as amended, R1, R2, R3 as amended, R4–R6, §4 as amended, §5 to §9,
R4's pressure point as amended, R-a, R-b as amended, R-c as amended twice, R-d
to R-i, and the mixed-cell, dilution, share-timing and share-level amendments
all stand. So does the Bonferroni amendment, except for the passages quoted
below.

## The old value

Each passage verbatim, with its own markup.

The Bonferroni amendment's heading, set in bold so that this quote does not
create a second anchor:

> **Amendment — the multiplicity correction is Bonferroni over the named set, and the draw grows to 125 cases**

The first two sentences of its §4 paragraph, which name the list's length and
its tail:

> **§4. The draw becomes one ordered list of 125 distinct cases.** Its head is
> §4's frozen 29, unchanged and in sorted order. Its tail is 96 cases drawn from
> the 404 not in §4's draw, under a new seed, in the order they were drawn.

#401 named the first sentence. The *"Its tail"* sentence is here because the
guard puts it here: once the list runs to 433, the list's tail is no longer
those 96. The *"Its head"* sentence between them is quoted for context and
stands.

The `list:` line of its frozen block, with the note on the digest that follows
it:

```
list:       sorted(head) followed by the extension in draw order
sha256:     4802ad2996039d14ba5473f3d4fc638110181c242cd72e3fa3907459ceb19730
            (of the newline-joined 125, in list order)
```

The sentence that introduces its printed list:

> The whole list, by position. Positions 1–29 are §4's 29, and 30–125 are the
> extension.

Its capacity paragraph:

> **The list's capacity, on record.** 125 cases supply n for m ≤ 30 under the 5%
> branch: n is 125 at m = 30 and 126 at m = 31. Under the 10% branch they supply
> any m this campaign could name. What a family named larger than that gets is
> under *Not decided here*.

## The new value

**The case list.** The draw is one ordered list of **all 433 Tier-1 cases**, the
**case list**. Positions 1–125 are the Bonferroni amendment's 125, unchanged and
in their list order. Positions 126–433 are the other 308 cases, in the order
seed `20261125` draws them. **Every cell in a family still uses the list's first
n cases**, n being the family's n under §2, so the pairing holds within each pin
decision.

```
population: 433 (src.eval.dataset.load_tier1, over data/tier-1 at git tree
            6348d8f7b452816f88beab7c5a9e18660e3977f7, commit 3c936c3f9418)
            asserted before drawing
head:       the Bonferroni amendment's 125, in list order
            sha256 4802ad2996039d14ba5473f3d4fc638110181c242cd72e3fa3907459ceb19730
            asserted before drawing
seed:       20261125
method:     random.Random(20261125).sample(sorted(set(case_ids) - set(head)), 308)
order:      the order sample() returns them in, which is the draw order
sha256:     7962ad6b4a8e9629bbe7a2b891380cb8a5b0558dc0c7fbfbb028108160ec11f1
            (of the newline-joined 308-case tail, in draw order)
list:       head followed by the tail in draw order
sha256:     0020415da942323a43e38756d3974d86269b8696301148adb1638e0c819a0085
            (of the newline-joined 433, in list order)
```

Each digest is over UTF-8 ids joined with `\n` and no trailing newline, as §4's
is. `308` is a literal and not `len(remaining)`, so a population that is not 433
cannot be drawn around. If either assertion had failed, nothing would have been
drawn. The failure would have gone to [#406 — What happens to the frozen case
list if a Tier-1 case is edited or removed before
acquisition?](https://github.com/bgunyel/clause-and-effect/issues/406).

The population was read from `data/tier-1` at tree `6348d8f7…`, extracted from
commit `3c936c3f9418` with `git archive`, and not from the working copy. That
tree is byte-identical to the working copy at `88611bbf45b4`, and it is the tree
§4 and the Bonferroni amendment drew from. Before the draw, §4's head reproduced
`26cdec8e…`, the 96-case extension reproduced `32547f20…`, and the 125 in list
order reproduced `4802ad29…`. The draw was then run once. Reproduced on CPython
3.13.15 under `uv run`.

**The seed is `20261125`, the date of #401's resolution.** It was fixed in that
resolution, before this amendment was written, so the writer had no choice over
it. This departs from the Bonferroni amendment's *"The seed is the amendment's
date"*, and is recorded as a departure. This amendment happens to carry the same
date, but the seed comes from #401 and not from that date.

**The Bonferroni amendment's heading** now reads *"Amendment — the multiplicity
correction is Bonferroni over the named set, and the draw grows to 125 cases,
the head of the case list"*. Its text in place is not edited, so every link to
its anchor still resolves.

**Its §4 sentences** now read: *"§4. The draw becomes one ordered list of
distinct cases, the case list, which the case-list amendment extends to all 433
Tier-1 cases. Its first 125 positions are drawn here. … Positions 30–125 are 96
cases drawn from the 404 not in §4's draw, under a new seed, in the order they
were drawn."*

**Its `list:` line and digest note** now describe positions 1–125, the case
list's head. `4802ad29…` is the digest of that head, of the newline-joined 125 in
list order. The digest of the whole list is `0020415d…`, in the block above.

**Its *whole list* sentence** now reads: *"Positions 1–125 of the case list, by
position. Positions 1–29 are §4's 29, and 30–125 are the extension. Positions
126–433 are printed in the case-list amendment."*

Positions 126–433, in the Bonferroni amendment's four-column format:

```
126 gdpr_art12_case1    127 gdpr_art55_case1    128 gdpr_art75_case4    129 gdpr_art92_case3
130 gdpr_art46_case4    131 gdpr_art14_case4    132 gdpr_art86_case1    133 gdpr_art65_case2
134 gdpr_art38_case4    135 gdpr_art7_case3     136 gdpr_art29_case2    137 gdpr_art52_case4
138 gdpr_art9_case6     139 gdpr_art16_case2    140 gdpr_art54_case3    141 gdpr_art15_case3
142 gdpr_art13_case4    143 gdpr_art50_case3    144 gdpr_art94_case3    145 gdpr_art38_case2
146 gdpr_art21_case3    147 gdpr_art46_case2    148 gdpr_art4_case7     149 gdpr_art72_case2
150 gdpr_art56_case4    151 gdpr_art92_case1    152 gdpr_art60_case4    153 gdpr_art61_case2
154 gdpr_art4_case3     155 gdpr_art91_case1    156 gdpr_art13_case1    157 gdpr_art56_case3
158 gdpr_art73_case2    159 gdpr_art63_case3    160 gdpr_art77_case3    161 gdpr_art28_case5
162 gdpr_art74_case1    163 gdpr_art34_case3    164 gdpr_art44_case4    165 gdpr_art68_case1
166 gdpr_art73_case1    167 gdpr_art40_case2    168 gdpr_art86_case2    169 gdpr_art15_case6
170 gdpr_art99_case3    171 gdpr_art53_case3    172 gdpr_art80_case4    173 gdpr_art1_case3
174 gdpr_art98_case1    175 gdpr_art88_case4    176 gdpr_art66_case1    177 gdpr_art39_case4
178 gdpr_art9_case8     179 gdpr_art81_case3    180 gdpr_art50_case2    181 gdpr_art59_case3
182 gdpr_art89_case5    183 gdpr_art43_case1    184 gdpr_art25_case1    185 gdpr_art45_case3
186 gdpr_art52_case2    187 gdpr_art77_case1    188 gdpr_art32_case2    189 gdpr_art12_case5
190 gdpr_art82_case1    191 gdpr_art9_case9     192 gdpr_art22_case2    193 gdpr_art9_case1
194 gdpr_art35_case2    195 gdpr_art17_case1    196 gdpr_art63_case2    197 gdpr_art2_case2
198 gdpr_art70_case5    199 gdpr_art48_case1    200 gdpr_art39_case1    201 gdpr_art30_case5
202 gdpr_art83_case1    203 gdpr_art41_case2    204 gdpr_art41_case4    205 gdpr_art62_case4
206 gdpr_art14_case3    207 gdpr_art28_case4    208 gdpr_art58_case5    209 gdpr_art29_case1
210 gdpr_art38_case3    211 gdpr_art40_case5    212 gdpr_art44_case2    213 gdpr_art90_case2
214 gdpr_art61_case5    215 gdpr_art5_case1     216 gdpr_art53_case4    217 gdpr_art14_case1
218 gdpr_art95_case3    219 gdpr_art66_case4    220 gdpr_art62_case3    221 gdpr_art4_case6
222 gdpr_art78_case1    223 gdpr_art52_case1    224 gdpr_art54_case4    225 gdpr_art21_case4
226 gdpr_art62_case5    227 gdpr_art5_case2     228 gdpr_art27_case3    229 gdpr_art46_case1
230 gdpr_art31_case1    231 gdpr_art51_case4    232 gdpr_art36_case2    233 gdpr_art97_case1
234 gdpr_art10_case3    235 gdpr_art41_case5    236 gdpr_art57_case2    237 gdpr_art53_case2
238 gdpr_art83_case3    239 gdpr_art83_case4    240 gdpr_art24_case1    241 gdpr_art6_case1
242 gdpr_art35_case4    243 gdpr_art81_case4    244 gdpr_art7_case4     245 gdpr_art85_case1
246 gdpr_art8_case2     247 gdpr_art12_case4    248 gdpr_art77_case4    249 gdpr_art51_case1
250 gdpr_art71_case1    251 gdpr_art46_case5    252 gdpr_art87_case2    253 gdpr_art15_case7
254 gdpr_art60_case2    255 gdpr_art56_case2    256 gdpr_art12_case6    257 gdpr_art55_case2
258 gdpr_art34_case2    259 gdpr_art24_case2    260 gdpr_art99_case2    261 gdpr_art97_case3
262 gdpr_art72_case3    263 gdpr_art5_case6     264 gdpr_art39_case3    265 gdpr_art36_case3
266 gdpr_art15_case5    267 gdpr_art59_case4    268 gdpr_art58_case2    269 gdpr_art7_case6
270 gdpr_art3_case2     271 gdpr_art21_case1    272 gdpr_art26_case1    273 gdpr_art4_case10
274 gdpr_art57_case5    275 gdpr_art36_case1    276 gdpr_art41_case3    277 gdpr_art50_case1
278 gdpr_art3_case5     279 gdpr_art75_case2    280 gdpr_art45_case4    281 gdpr_art9_case2
282 gdpr_art54_case1    283 gdpr_art45_case1    284 gdpr_art61_case3    285 gdpr_art66_case2
286 gdpr_art5_case7     287 gdpr_art18_case3    288 gdpr_art82_case3    289 gdpr_art50_case4
290 gdpr_art60_case1    291 gdpr_art38_case1    292 gdpr_art13_case5    293 gdpr_art40_case1
294 gdpr_art42_case6    295 gdpr_art9_case3     296 gdpr_art74_case2    297 gdpr_art89_case3
298 gdpr_art3_case3     299 gdpr_art76_case3    300 gdpr_art30_case3    301 gdpr_art4_case9
302 gdpr_art22_case1    303 gdpr_art62_case2    304 gdpr_art19_case3    305 gdpr_art5_case3
306 gdpr_art2_case3     307 gdpr_art4_case2     308 gdpr_art7_case2     309 gdpr_art57_case1
310 gdpr_art37_case2    311 gdpr_art78_case3    312 gdpr_art25_case3    313 gdpr_art33_case1
314 gdpr_art8_case5     315 gdpr_art85_case4    316 gdpr_art75_case3    317 gdpr_art65_case4
318 gdpr_art46_case3    319 gdpr_art97_case2    320 gdpr_art62_case1    321 gdpr_art8_case4
322 gdpr_art47_case3    323 gdpr_art87_case3    324 gdpr_art64_case3    325 gdpr_art33_case3
326 gdpr_art85_case2    327 gdpr_art95_case1    328 gdpr_art70_case3    329 gdpr_art21_case2
330 gdpr_art11_case1    331 gdpr_art91_case2    332 gdpr_art28_case3    333 gdpr_art40_case4
334 gdpr_art6_case3     335 gdpr_art76_case1    336 gdpr_art57_case4    337 gdpr_art14_case5
338 gdpr_art34_case4    339 gdpr_art19_case2    340 gdpr_art68_case3    341 gdpr_art56_case5
342 gdpr_art20_case1    343 gdpr_art13_case2    344 gdpr_art80_case3    345 gdpr_art89_case1
346 gdpr_art96_case2    347 gdpr_art39_case5    348 gdpr_art51_case3    349 gdpr_art35_case1
350 gdpr_art20_case5    351 gdpr_art73_case3    352 gdpr_art23_case2    353 gdpr_art66_case3
354 gdpr_art5_case4     355 gdpr_art63_case1    356 gdpr_art88_case2    357 gdpr_art13_case3
358 gdpr_art22_case3    359 gdpr_art65_case3    360 gdpr_art8_case3     361 gdpr_art71_case3
362 gdpr_art47_case5    363 gdpr_art88_case3    364 gdpr_art85_case3    365 gdpr_art26_case2
366 gdpr_art59_case2    367 gdpr_art7_case1     368 gdpr_art14_case2    369 gdpr_art91_case3
370 gdpr_art45_case2    371 gdpr_art49_case5    372 gdpr_art41_case6    373 gdpr_art84_case4
374 gdpr_art17_case2    375 gdpr_art37_case3    376 gdpr_art69_case3    377 gdpr_art30_case4
378 gdpr_art79_case3    379 gdpr_art42_case5    380 gdpr_art81_case2    381 gdpr_art13_case7
382 gdpr_art82_case2    383 gdpr_art15_case1    384 gdpr_art90_case1    385 gdpr_art6_case5
386 gdpr_art12_case3    387 gdpr_art28_case2    388 gdpr_art48_case2    389 gdpr_art4_case5
390 gdpr_art58_case1    391 gdpr_art19_case1    392 gdpr_art20_case3    393 gdpr_art99_case1
394 gdpr_art37_case1    395 gdpr_art67_case1    396 gdpr_art67_case2    397 gdpr_art15_case4
398 gdpr_art4_case4     399 gdpr_art30_case1    400 gdpr_art65_case1    401 gdpr_art52_case5
402 gdpr_art79_case2    403 gdpr_art47_case2    404 gdpr_art58_case4    405 gdpr_art7_case5
406 gdpr_art27_case2    407 gdpr_art14_case6    408 gdpr_art1_case2     409 gdpr_art11_case2
410 gdpr_art78_case5    411 gdpr_art43_case4    412 gdpr_art36_case4    413 gdpr_art92_case4
414 gdpr_art31_case3    415 gdpr_art76_case2    416 gdpr_art54_case2    417 gdpr_art10_case1
418 gdpr_art26_case4    419 gdpr_art98_case3    420 gdpr_art83_case5    421 gdpr_art40_case3
422 gdpr_art89_case2    423 gdpr_art16_case3    424 gdpr_art42_case3    425 gdpr_art55_case3
426 gdpr_art32_case4    427 gdpr_art60_case3    428 gdpr_art28_case1    429 gdpr_art96_case1
430 gdpr_art47_case4    431 gdpr_art49_case3    432 gdpr_art45_case5    433 gdpr_art55_case4
```

**The list's capacity, on record.** 433 cases supply n for any m up to
**221,130,635** under the 5% branch, since 0.95⁴³³ ≈ 2.26 × 10⁻¹⁰. Under the 10%
branch they supply any m up to about 3.25 × 10¹⁸. Both limits are far beyond any
m this campaign could name. n is still 125 at m = 29 and m = 30, and 126 at
m = 31 under the 5% branch, which the 125 could not supply and the 433 can.

**The stop rule.** Registered here, in #401's wording:

> Before a family's first acquisition call, whoever runs acquisition computes n
> from the family's frozen m and the branch of §1 in force, and confirms that n
> does not exceed the list's length. If it does, the family receives no call.
> The stop is recorded with m, t and n, and only a later append can lift it.

It applies under both branches of §1. Under the whole-population list it is
practically unreachable. It is kept so that the rule covers every case rather
than going silent at its edge. It is a **requirement on the acquisition reads**,
for whoever builds acquisition.

## The reason

**Why extend, and not cap m.** R1 names every provider OpenRouter lists for the
model at the acquisition commit. Capping m after reading the catalogue narrows
R1 on observation. Capping it by a rule set now leaves some named providers
untested, chosen arbitrarily. Either way, a named provider would go untested
because the list was short, and the list's length is the thing that is cheap to
change.

**Why now, and over the whole population.** The named count moved by about ten
in either direction in 2½ months. #401 read OpenRouter's endpoints listing on
2026-11-25. DeepSeek V4 Flash, Kimi K3, MiniMax M3 and Grok 4.6 listed 19, 19, 5
and 1 distinct providers, against R-a's 29, 15, 12 and 2 on 2026-09-05. That
snapshot is not R1's m, which is read at the acquisition commit. m ≤ 30 holds today, and nothing keeps it there. New models (R-h),
channel changes (R-e) and re-tests
([#397](https://github.com/bgunyel/clause-and-effect/issues/397)) can each add to
what the list must supply. These alternatives were rejected:

- **Extend at the acquisition commit, only if needed.** That writes a second §4
  amendment after m has been seen.
- **Extend now to a fixed size.** That defers the question rather than closing
  it.

The whole population closes it, because no larger list can be drawn from
Tier-1.

**Why the head does not move.** Keeping positions 1–125 exactly as the
Bonferroni amendment froze them means [#7](https://github.com/bgunyel/clause-and-effect/issues/7)'s
digest and both of the Bonferroni amendment's digests still verify. Every family
whose n is 125 or less uses exactly the cases it would have used before this
amendment.

**Why the stop is kept though it cannot be reached.** A rule that is silent at
its edge leaves the edge to whoever meets it, and that person would meet it
after m has been read. With the stop registered now, the edge is decided before
any rate exists.

**Not decided here.**

- **Re-tests against the list.** [#397 — Does an R6 re-test add to R-c's m, or
  does each re-test buy a free chance at
  rule-in?](https://github.com/bgunyel/clause-and-effect/issues/397) decided
  that re-tests spend a reserve at α/(m·2ʲ), and that the stop rule above gains
  a sentence covering them. [#413 — Append the re-test reserve
  amendment](https://github.com/bgunyel/clause-and-effect/issues/413) writes
  both. This amendment states the stop for a family's first test only.
- **Which version of the cases acquisition reads.** This amendment drew from
  tree `6348d8f7…` and records that it did. That acquisition reads its case text
  from that tree too, by hash and never from the working copy, was decided in
  [#406](https://github.com/bgunyel/clause-and-effect/issues/406). [#412 —
  Append the case-text amendment: acquisition reads the cases at tree 6348d8f7,
  never the working copy](https://github.com/bgunyel/clause-and-effect/issues/412)
  writes it.

**Written before the first acquisition call**, with zero provider-attributed rows
in hand. This file is carried by a commit, and that commit can be ordered
against the commit of any acquisition row, as with the rest of this document.

---

# Amendment — only a forced acquisition admits a member, and the organic share is report-only

| | |
|---|---|
| amended | 2026-11-25 |
| branch | `dev-06` |
| commit at amendment | `0a80d6882a41` |
| decided in | [#408 — Does clearing the no-response share by organic read, then by forced run, buy a second chance at α/m?](https://github.com/bgunyel/clause-and-effect/issues/408) |
| written by | [#411](https://github.com/bgunyel/clause-and-effect/issues/411), under map [#6](https://github.com/bgunyel/clause-and-effect/issues/6) |
| amends | the [acceptable-set amendment](#amendment--acceptable-set-membership-needs-a-cleared-no-response-share-not-rule-in-alone)'s membership sentence, and its last bullet as the [share-timing amendment](#amendment--the-no-response-share-is-read-once-where-rule-in-is-read-and-a-forced-acquisition-decides-membership-alone) left it; and every passage of the [dilution amendment](#amendment--an-organic-cells-no-response-share-charges-every-unattributed-attempt-to-the-candidate), the share-timing amendment and the [share-level amendment](#amendment--the-no-response-share-is-read-at-αm-over-the-named-set-the-level-rule-in-is-read-at) that gives the organic share a clearing or routing role |
| status of the data | none — written before the first acquisition call; `record_attempt` still has no caller in `src/`, so `llm_attempt` has never held a row |

**This is an amendment, not a registration**, under the guard in [§The two kinds
of append](#the-two-kinds-of-append). The acceptable-set amendment's last bullet
first said that a config pin on a cell whose share does not clear *"needs a
**forced acquisition** whose per-cell share clears"*. The share-timing amendment
rewrote it, and both versions send only a cell whose share does **not** clear to
a forced acquisition. Both imply that a cell whose organic share clears is a
member with no forced run. After this amendment no organic read admits a member,
so those sentences would mean something different, and they owe old values. So
do the later passages that let an organic share clear a cell or route one.

[#408](https://github.com/bgunyel/clause-and-effect/issues/408) found that the
organic route was a second chance at the share, and that it could be a test of
the wrong quantity. It decided that only a forced acquisition admits a member,
and that the organic share is printed and decides nothing. This amendment writes
that decision.

**What stands unamended**, each with its reason:

- **§2's rule-in, R3 as amended, and R4.** Neither the bar nor the point at which
  rule-in is read moves. An organic rule-in is still evaluated once, at the
  declared n. It now decides only who gets a forced acquisition.
- **R5.** Rule-out peeks stay unrestricted in both regimes. An organic rule-out
  is still a rule-out, and the cell gets no forced acquisition without an R6
  cause.
- **R6 and R-i.** A further membership read needs a cause recorded under R6, as
  a re-test always did. R-i says which rows it counts.
- **R-g**, including its three-bucket count printed beside every cell of the
  `(model, channel)`. The organic share is now printed beside the cell in the
  same way.
- **The share's definition, its timing and its level.** That is the dilution
  amendment's A / (s_X + A), the share-timing amendment's read bullet except the
  one sentence owed below, the forced read, and the share-level amendment's α/m
  under both regimes. The organic share is computed and read exactly as they
  say. Only what it decides changes, and after this amendment it decides
  nothing. It is still read once, so that a number which decides nothing cannot
  be chosen by when it is read.
- **R4's pressure point as amended.** *"Membership is the rule-in test plus a
  cleared no-response share"* and *"Every member clears rule-in, and its
  no-response share, individually"* name no regime. They read through to the
  membership sentence below.
- **The share-timing amendment's forced-acquisition sub-bullets**, except the
  two owed below: the ordinary measurement pin at the family's R2 n on the case
  list's first n cases, *"A forced rule-in that fails is failed under R4"*, and
  *"An unresolved forced share is final"*. Its early stop also stands, except its
  label sentence. Its *Why the forced acquisition decides membership alone* now
  holds of every member. Both of its derived cases stand. The second, *A forced
  run that stops early does not evaluate its rule-in*, is what settles the labels
  below.
- **The share-level amendment's** *"The level is the same under both regimes"*.
  It is about the level, and the organic share is still read at α/m. Its *Why α
  is not split* holds of the forced reads, which are now the only reads that
  admit. Its *"a family has m share reads, as it has m rule-in reads"* still
  holds of the reads that admit: at most one forced read per cell, so at most m.
  Its bounds, its A = 1 sentence and its k\* table are statements about bounds,
  and they stand.
- **The dilution amendment's** *Dilution, closed by construction*, its bound
  sentence as the share-level amendment left it, and its quoted *A ignores
  attribution*. They describe the number that is printed. Its *What stands*
  bullet on the last bullet reads through to the last bullet as amended below.
- **The dilution amendment's rejected alternative** *"A forced acquisition for
  every candidate. It is never safer than the read above, and it always costs
  more."* It records what #391 rejected, and it is still true as history. This
  amendment does not take that alternative, because a cell that failed organic
  rule-in gets no forced acquisition. Its premise, that a forced run is never
  safer than the organic read, is what #408's first decision denies, because
  the two reads bound different quantities. It is recorded here, so that the
  sentence is not read as standing against this amendment.
- **The forced n.** It is 61 at 10% and 125 at 5%, for m = 29. The share-timing
  amendment's *Why the forced n is R2's n, whatever the share's level* is
  unchanged.
- **The case list and its stop rule**, as the case-list amendment wrote them.

§1 and §2 as amended, R1, R2, R3 as amended, R4–R6, §4 as amended, §5 to §9,
R4's pressure point as amended, R-a, R-b as amended, R-c as amended twice, R-d
to R-i, and the mixed-cell and case-list amendments all stand. So do the
dilution, share-timing and share-level amendments, except for the passages
quoted below.

## The old value

Each passage verbatim, with its own markup, so that it can be found.

**From the acceptable-set amendment**, two passages.

Its membership sentence:

> A cell is a member of an acceptable set only if it **rules in** under §2 and
> its **no-response share also clears**.

Read with the organic share's per-cell read, an organic rule-in whose organic
share clears satisfies it with no forced run.

Its last bullet as the share-timing amendment left it, with two of its
sub-bullets:

> - A cell that rules in and whose share does not clear is reported as
>   **"rule-in, no-response unresolved"**. It is not a member. A config pin on
>   it needs a **forced acquisition**, and **membership is then read from the
>   forced acquisition alone**: its rule-in and its share, both read once, at
>   its rule-in point, on its rows.

>   - The organic result is reported beside the forced one. Once its share was
>     unresolved, it licenses nothing on its own.

>   - **The early stop.** Let A be the forced acquisition's non-served
>     attempts so far. The run stops at the non-served attempt that brings A to
>     **k\***, the smallest k for which the share's upper bound on k non-served
>     attempts of n + k, at the level the share is read at, is at or above the
>     §1 tolerance t. The cell reads *"rule-in, no-response unresolved"*. The
>     stop is recorded with the attempt count, the served count and the A at
>     which it was taken. Rule-out peeks on the forced rows stay unrestricted
>     under R5.

In the bullet, the whole first sentence changes, and so does the scope of the
third: *"A config pin on it"* names only a cell whose share did not clear. In
the first sub-bullet, *"Once its share was unresolved"* and *"on its own"*
change. In the early stop, only *"The cell reads "rule-in, no-response
unresolved""* changes.

**From the dilution amendment**, three passages.

The sentence after its level bullet:

> A cell whose share does not clear reads *"rule-in, no-response unresolved"* and
> needs a forced acquisition, as the last bullet already says.

From its *Why this is not the worst-case attribution #371 rejected*:

> Under the acceptable-set amendment a share that does not
> clear is never a rule-out. It is only *"rule-in, no-response unresolved"*, so
> the same arithmetic now costs a forced run and nothing more.

From its *The trade, recorded*, after the quoted block:

> Precision is given up so that the gate never depends on enrichment being right.
> A candidate can be sent to a forced acquisition by a timeout the log could have
> placed on another provider. That costs calls and never makes a false rule-in,
> which is the direction §2's asymmetry prefers.

Its *"In practice the organic read clears only on a `(model, channel)` that is
nearly free of no-response attempts. Otherwise it routes the candidate to a
forced acquisition."* is not quoted again. The share-level amendment replaced
it, and its replacement is quoted below.

**From the share-timing amendment**, two passages.

The last-but-one sub-bullet of its read bullet:

>   - The share is never read again on later rows. An organic share that does
>     not clear at the rule-in point stays unresolved for the organic regime.

The first sentence stands.

From its *Not decided here*, the last sentence of the bullet on whether an
organic read can admit a member:

> This amendment reads membership from the forced acquisition for the cells
> #392 named: an organic rule-in whose share does not clear, and a cell pinned
> from the start.

**From the share-level amendment**, three passages.

The sentence after its bounds table:

> **As this amendment leaves the share, an organic share read at s_X equal to
> the declared n clears only at A = 0**, that is, on a `(model, channel)` with no
> non-served attempt at all up to X's rule-in point. Otherwise it routes the
> candidate to a forced acquisition.

The *clears* columns of that table, at s = 61 and s = 125. Under the
share-level amendment they read the organic gate as well as the forced one. The
numbers are not quoted again and do not change.

Its *The cost, on record*:

> **The cost, on record.** As this amendment leaves the share, an organic share at
> s_X equal to the declared n clears only at A = 0. The dilution amendment's *one
> timeout still clears* is given up. One non-served attempt anywhere on a
> `(model, channel)` before X's rule-in point sends X to a forced acquisition. A
> forced acquisition's share clears on 0 non-served attempts in 61 or 125, and the
> run stops at its first non-served attempt. The cost falls on calls, and it never
> makes a false rule-in, which is the direction §2's asymmetry prefers.

The words that change are the first sentence's *"clears"* and the whole of
*"One non-served attempt anywhere on a `(model, channel)` before X's rule-in
point sends X to a forced acquisition."* The rest stands.

#408's checklist named the acceptable-set amendment's last bullet, and the
dilution amendment's two sentences, *"A cell whose share does not clear …"* and
*"In practice the organic read clears only …"*. It also named the share-timing
amendment's scoping of the forced read, and the share-level amendment's *"clears
only at A = 0"*. A comment on #411 from #405 named the share-timing amendment's
read sub-bullet, its organic-result sub-bullet, its *Not decided here* sentence,
and the early-stop label. A comment from #407 named the share-level amendment's
sentence after the table, its *clears* columns and its *The cost, on record*. The
assistant, writing this under #411, read all four amendments and `CONTEXT.md`
under the guard. It found three more passages: the acceptable-set amendment's
membership sentence, the dilution amendment's worst-case sentence, and its trade
sentence. Its rejected alternative *A forced acquisition for every candidate*
is taken up under *What stands*.

## The new value

**Membership.** The acceptable-set amendment's membership sentence now reads:

> A cell is a member of an acceptable set only if **one forced acquisition** of
> it rules in under §2 and its no-response share also clears. Both are read once
> under the pin, at the family's R2 n, each at α/m. The share membership needs
> is the **pinned-condition share**, which is X's share under the condition a
> config pin `{only: [X, Y], allow_fallbacks: True}` sends X traffic under. **No
> organic read admits a member.** The organic share is evidence about a
> different quantity. It is not a test of this one.

**The last bullet** now reads:

> - A cell that rules in under organic acquisition is reported as **"organic
>   rule-in, not a member"**, whatever its organic share. A config pin on it
>   needs a **forced acquisition**, and **membership is then read from the
>   forced acquisition alone**: its rule-in and its share, both read once, at
>   its rule-in point, on its rows.

Its sub-bullets stand as the share-timing amendment wrote them, except two.

The organic-result sub-bullet now reads:

>   - The organic result is reported beside the forced one, with its share and
>     that share's bound. It licenses nothing.

The early stop's label sentence now reads *"The cell reads "rule-in,
no-response unresolved" if it ruled in under organic acquisition, and
"no-response unresolved" if it was measured under a pin from the start."* The
rest of the early stop stands.

**Who gets a forced acquisition.** Every organic rule-in, and every cell
measured under a measurement pin from the start, whose own reads are already
the forced reads. A cell that failed organic rule-in gets none without a cause
recorded under R6. So does a cell that was ruled out organically.

**The organic share is report-only.** It is computed as the dilution amendment
defines it, A / (s_X + A). It is read once, at X's organic rule-in point, as the
share-timing amendment times it, and at α/m, the share-level amendment's level.
It is printed with its bound beside the cell, like R-g's three-bucket count. It
neither clears a cell nor routes one. Where an amendment before this one says
that an organic share clears, or does not, that now says only whether its
printed bound is below t.

**Labels.**

| outcome | reads |
|---|---|
| an organic rule-in, whatever its organic share | **"organic rule-in, not a member"** |
| a forced acquisition that reaches n and rules in | a member; its share clears, because every unresolved forced share is an early stop |
| a forced acquisition that reaches n and fails rule-in | failed under R4, for the forced regime |
| a forced acquisition that stops early, after an organic rule-in | **"rule-in, no-response unresolved"** |
| a forced acquisition that stops early, for a cell pinned from the start | **"no-response unresolved"** |

*"Rule-in, no-response unresolved"* is reserved for a forced run whose share
fails. Every forced share that fails is an early stop, and an early stop does
not evaluate the forced rule-in, as the share-timing amendment derived. So the
*rule-in* that label names is always the organic one. A cell pinned from the
start has no organic rule-in, and it reads *"no-response unresolved"*, as the
share-timing amendment already said. A rule-out under R5, in either regime, is
recorded as R5 says.

**The invariant.** A cell gets at most one membership read per condition. A
further one needs a cause recorded under R6, before it, and counts only R-i's
rows. The forced acquisition that follows an organic rule-in is the cell's
**first** membership read, because the organic rule-in is no longer one. It is
read at α/m, as #408 decided, and it spends no slot of the re-test reserve.

**The dilution amendment's** sentence after its level bullet now reads *"An
organic share decides nothing. Every organic rule-in reads "organic rule-in, not
a member" and needs a forced acquisition, as the last bullet says."*

Its worst-case sentence now reads *"After the forced-membership amendment the
organic share decides nothing, so the same arithmetic changes a printed number
and no outcome. A share that does not clear is never a rule-out."*

Its trade sentence now reads *"Precision is given up so that the printed share
never depends on enrichment being right. A candidate's printed share can be
raised by a timeout the log could have placed on another provider. That changes
no decision, because every organic rule-in gets a forced acquisition whatever
its share."*

**The share-timing amendment's** read sub-bullet now reads *"The share is never
read again on later rows. An organic share is report-only, and is never
unresolved. It is printed with its bound at the rule-in point."*

Its *Not decided here* sentence now reads *"The forced-membership amendment
reads membership from the forced acquisition for every cell: every organic
rule-in, whatever its share, and a cell pinned from the start."*

**The share-level amendment's** sentence after its bounds table now reads *"As
this amendment leaves the share, an organic share read at s_X equal to the
declared n has a bound below t only at A = 0, that is, on a `(model, channel)`
with no non-served attempt at all up to X's rule-in point. It is printed, and it
routes nothing. Every organic rule-in goes to a forced acquisition, whatever A
is."*

Its *clears* columns at s = 61 and s = 125 read the gate for a forced share,
with n = s served calls. For an organic share at s_X = s they say only whether
the printed bound is below t, and they admit no one.

In its *The cost, on record*, the first sentence now reads *"… an organic share
at s_X equal to the declared n has a bound below t only at A = 0."* The routing
sentence now reads *"Every organic rule-in goes to a forced acquisition, whatever
A is."*

## The reason

**The organic route was a second chance.** Under the old text a cell had two
routes to membership on the share: the organic read, and then a forced run.
Each was read at α/m. Rule-in had no second chance, because the forced route
opened only after an organic rule-in, so a cell with a bad structure rate had to
pass both rule-in reads. Only the share direction had two routes.

Recomputed for this amendment at m = 29, with `scipy.stats.beta.ppf(1 − α/m,
k + 1, n − k)` for the bound and `(1 − t)ˢ` for the chance of no non-served
attempt in s served calls. At α/29 an organic share at s = n clears only at
A = 0. The bound there is 9.91% at s = 61 and 4.96% at s = 125. Take a cell whose
share is exactly t, and which is the only source of nulls on its
`(model, channel)`. It falsely clears organically with probability **0.00162**
at 61 / 10% and **0.00164** at 125 / 5%. If the forced share is the same
quantity, the forced read clears falsely with the same probability. Across both
routes that is 1 − (1 − p)², **0.00323** and **0.00328**. α/m is 0.00172 and
2α/m is 0.00345. The union bound is nearly reached, so the family bound on the
share direction was 2α, not α.

**Two quantities, and why it does not matter which.** The share a pin needs is
X's share under the pin. The organic read bounds X's share under organic
routing. Nothing shows the two are equal, and nothing shows that the organic one
bounds the pinned one. A plausible mechanism, **not observed**: under organic
routing OpenRouter can fall back away from a slow X inside one client request,
so X's slowness never appears as a null. If the two quantities are the same, the
organic route was a second chance. If they differ, it was a test of the wrong
quantity, with no bound at all on the one a pin needs. Dropping the organic
route closes both cases. The per-cell bound returns to α/m, and, with the
share-level amendment's *Why α is not split*, the family bound returns to α.

**Why a cell that failed organic rule-in gets no forced acquisition.** This is
not about α, since membership reads only the one forced run either way. It
follows R4's anticipated pressure point: pinning a cell that failed organically
is *"un-fail the marginal member"*. So the organic rule-in stays as a screen in
front of the forced read. A screen that must also pass adds a condition to
admission and spends no α.

**Why the organic share is still computed and read once.** It is still
evidence, and it is printed. A number that decides nothing could still be chosen
by when it is read, if it could be read at any point. The share-timing
amendment's read-once rule closes that, so it is kept.

Three alternatives are not taken. #408 rejected each:

- **Accept 2α/m.** The family bound on the silent error would be 2α, which is
  10%.
- **Split α to α/2m per route.** It is dominated. Recomputed: at A = 0 the
  organic share's bound at the declared n is 10.92% at 61 / 10% and 5.49% at
  125 / 5%, so it fails, and the organic route is dead anyway. The forced
  zero-failure n rises from 61 to 67 and from 125 to 138.
- **Count forced runs into m.** Counted as they occur, m depends on the data,
  which is #377's reason. Fixed at 2m in advance, it is the α/2m split.

**The trade, recorded.** Every organic rule-in now costs a forced run at the
family's R2 n, 61 or 125 served calls for m = 29. That includes one with A = 0,
which would have cleared before. Since #400 that case was already rare, because
A = 0 means not one null anywhere on the `(model, channel)` up to the rule-in
point. #391's and #392's organic machinery now governs a printed number, not a
decision. The cost falls on calls, and it never makes a false rule-in, which is
the direction §2's asymmetry prefers.

**`CONTEXT.md`.** No new term. **No-response attempt** was read under the guard.
It says how a no-response attempt is counted and that the share is read per
cell under both regimes. It gives the organic share no clearing or routing role,
so it is not amended.

**Not decided here.**

- **What level a further membership read is read at.** It is a re-test.
  [#397 — Does an R6 re-test add to R-c's m, or does each re-test buy a free
  chance at rule-in?](https://github.com/bgunyel/clause-and-effect/issues/397)
  decided that re-tests spend a reserve at α/(m·2ʲ), and [#413 — Append the
  re-test reserve amendment: the j-th extra evaluation in a family is read at
  α/(m·2ʲ)](https://github.com/bgunyel/clause-and-effect/issues/413) writes it.
  This amendment says only that the forced acquisition after an organic rule-in
  is not one.
- **A re-test's share level.** Whether a re-test's share is read at its rule-in
  level, α/(m·2ʲ), or stays at α/m was raised on #408 from #397. Neither ticket
  decided it, and this amendment does not.

**Written before the first acquisition call**, with zero provider-attributed rows
in hand. This file is carried by a commit, and that commit can be ordered
against the commit of any acquisition row, as with the rest of this document.

# 2026-08-22 · session 1

**Repositories worked in:** `clause-and-effect` (`dev-04`) — four commits,
`5f9fca0..6128a3a`, pushed, no PR opened. `ai-common` (`main`) — one commit via
[#30](https://github.com/bgunyel/ai-common/pull/30), merged, branch deleted.
**State at close:** suite **304 passed / 5 xfailed**, up from 298 at the session's
start. Tree clean, everything pushed.

**Theme:** the session was meant to be *split stage A into two calls and measure
it*, and it was — but the two things that outrank the code are both Bertan's, and
both are reframings rather than findings. **The judge is a defect finder for the
golden set, not a classifier fitted to it**, which removes the train/test framing
the assistant had been importing. And **granularity is soft while the
core/auxiliary boundary is hard**, which invalidates the metric design §4.6 uses
and immediately changed four stability verdicts.

Stage A now exists as two independent calls. A1 is clean on every probe run at
it — 4/4 on its own examples, 6/6 on held-out adversarial cases, 6/6 on the real
§4.6 cases, and **0/6 unstable across 30 calls**. A2 is clean on examples and on
the six baseline cases, and **unstable on 3–4 of 6 cases across two separate
30-call runs** — though two of those failures turned out to be degenerate output
rather than disagreement.

---

## Bertan's first reframe: there is no held-out set, and there should not be

The assistant opened the session by flagging that the six §4.6 cases are the
tuning set, that there is no separate tuning corpus, and that item 2 of the
backlog is therefore "the honest generalisation test". It used the vocabulary of
a train/test split throughout — *contaminated*, *spent*, *burn a case*,
*held-out* — and built a probe set of synthetic cases partly to avoid "spending"
real ones.

**Bertan: that framing does not apply.** The goal is not a judge that generalises
to unseen cases. It is a judge that determines sufficiency correctly *in this
context*, with as little help as possible. The 433 Tier-1 cases are not a sample
drawn from a population of GDPR test cases — they **are** the population the
judge will ever run on. A held-out set exists to estimate error on unseen data,
and that estimand does not exist when there is no unseen data. The right analogy
is calibrating an instrument against known reference standards, not training a
classifier; nobody holds back three of the reference weights to check whether the
scale generalises.

The assistant agreed, and the concrete consequence is a reframing of backlog item
2. It is not *"measure on cases not used for tuning"*, which implies a hygiene
requirement. It is **"we have measured 6 of 433"** — a coverage gap. Any case may
be tuned on, including all of them; what may not be done is declaring a rate from
six and assuming the other 427 behave. `conditional` is 133 cases and no tuning
round has ever touched it.

The one real cost of using a case as a prompt worked example survives, and it is
narrow: a case shown to the judge stops being a *check* on whether the judge
agrees with a ruling. That applies to a handful of diagnostic cases, not to the
set, and it is already recorded in `stage_a2.py`.

**The risk that survives is not generalisation — it is fitting to an unvalidated
standard.** Five of the six §4.6 expectations are the assistant's classification.
Under this framing nothing downstream would ever surface a wrong label, since
every future measurement scores against the same standard. The defences are
Bertan's rulings on contested cases, `Claim.reason` as an audit trail, and the
panel's non-unanimity reporting — which makes §8 and §9 *more* important under
this framing, not less.

Recorded to memory as `no-held-out-set-golden-qa-is-the-population`.

## Bertan's second reframe: the judge is a defect finder, and its errors are asymmetric

Stated when the assistant raised the unvalidated-standard risk: *"I know that our
eval set is still not validated. The sufficiency judge is not fitting to the set.
The sufficiency judge is our help tool to find the self-sufficient and
insufficient examples in our set. We will make the necessary modifications on the
samples that are not self-sufficient."*

Three consequences, and the second is the one that changes decisions.

**It covers a defect class `golden_qa.py` structurally cannot see.** The
deterministic gate asks *is this quote in the article?* — grounding, 134 failures,
58 needing the quote rewritten. A quote can be perfectly grounded, a verbatim
substring, faithfully elided, and still **not answer the question**. No string
check can see that; it needs someone to read the quote and try to answer from it
alone, which is stage B. This is not a second opinion on work the gate already
does; it is the half of *"is this case sound?"* that has never been measurable.

**The two error types cost wildly different amounts.**

| error | consequence | visibility |
|---|---|---|
| a claim wrongly tagged **core** | a spurious `absent` from stage C, which a human reads and dismisses | visible, self-correcting |
| a claim wrongly tagged **auxiliary** | the quote is never asked to support it, a defective case is certified sound | **silent, permanent** |

So **the core/auxiliary split should err toward more core, not fewer.** This
bears directly on open item 5: `art7_case4`'s third sentence was demoted from core
to auxiliary in round 1 of the previous session's prompt work, and the assistant
had been treating the choice as a toss-up between two defensible readings. It is
not symmetric — demoting it is the choice whose errors are silent. Still Bertan's
call, but the asymmetry argues for core, and argues the same way for every
borderline case. It also de-escalates `art8_case5`'s probable false-positive
`contradicted`: a false positive is the cheap error.

**The set is not static.** Judge findings produce edits, and edited cases need
re-running. That retires the last objection to tuning on everything — you cannot
overfit to a target you are actively repairing — but it means case text will move
underneath any recorded number. Worth deciding early whether judge findings get
recorded against a case-set identity the way chunks do, so a finding can be told
apart from a finding about a case that no longer exists.

## Bertan's third reframe: granularity is soft, the boundary is hard

Raised while reading PROBE 1 of the A2 adversarial set. The assistant had expected
the second sentence to be core and split into two claims; A2 returned exactly
that. Bertan's question was whether splitting a core claim into two pieces is a
problem at all, and his own answer was that splitting it into one core and one
auxiliary *would* be a red-line mistake.

That is correct, and the design document does not currently state it. Splitting
one core claim into two changes **nothing** about what the quote must contain —
the union of core content is identical, and stage C simply checks two propositions
instead of one. If anything the finer split is the *stricter* test: a quote
supporting one half and not the other yields one `supported` and one `absent`, so
the case gets flagged, whereas one bundled claim forces stage C into a single
verdict on a partially-supported proposition, and *"mostly supported"* has no
label.

Moving a piece across the core/auxiliary line is categorically different: it
**removes a requirement**.

| property | error direction | cost |
|---|---|---|
| core/auxiliary **boundary** | silent | a defective case certified sound, permanently |
| core **granularity** | visible, or stricter | a slightly coarser or finer work list |

There is a floor on splitting: it bottoms out at meaningfulness. A fragment like
`"and information including: the purposes of processing"` cannot be judged either
way, which is what the unapplied atomicity rule guards.

**This invalidates §4.6's metric.** That table measures *core claim count*, which
conflates the two properties. `art8_case1`'s 1/1/2/1 was genuinely alarming
because the extra claim was a consequence promoted to core — a boundary move. But
a 1→2 difference produced by splitting one core claim in half counts identically
and is noise. The measurement that matches the criterion is **core coverage**:
which parts of the gold answer are marked core, regardless of how they were carved
up. That is what `probe_a2_stability.py` implements, and it changed four verdicts
the first time it ran (below).

---

## Stage A as two independent calls

Bertan's design, and it changed twice during specification. The assistant's first
reading was a pipeline — A1 writes the shortest sufficient answer, A2 receives it
and tags against it — and it began building that, including asking whether A2
should be blinded to the question. Bertan corrected it mid-build: **A1 and A2 both
receive the question and the answer, and neither receives the other's output.**

    stage_a1.py   (question, answer) -> shortest sufficient answer
    stage_a2.py   (question, answer) -> tagged claims
    stage_a_twocall.py                decompose(case) -> Decomposition

The correction matters. A chained A1 → A2 relocates the coupling; independent
calls make the two outputs *comparable*. A2's core claims are an assertion about
what the shortest sufficient answer contains, and A1's output is that answer, so
the two can be checked against each other. **Detecting stage A instability
currently costs N runs of the same prompt** — §4.6 needed four runs of
`art8_case1` to see 1/1/2/1. A disagreement between A1 and A2 is visible in
**one**. That consistency check is designed but not built.

`Decomposition` is unchanged, so stage C, `judge.py` and every test downstream of
the seam are untouched, and `stage_a.py` is left intact so the §4.6 baseline stays
reproducible.

**Four design decisions, each recorded in the modules rather than only here:**

1. **A2 must not emit its own shortest answer.** If it did, the consistency check
   would compare A1's text against A2's text and say nothing about the *tags*,
   which are the only thing stage C consumes. The cost is that A2's intermediate
   reasoning is unobservable, leaving `Claim.reason` as the only trace — the third
   time that field has proved load-bearing.
2. **`decompose` reconciles nothing.** A1 returning empty while A2 tags claims
   core is the disagreement the split exists to expose; forcing them to agree
   would erase the signal. The assistant had initially planned to force tags to
   auxiliary in that case and reversed it when the design changed to independent
   calls.
3. **Neither call takes a `TestCase`.** The case is unpacked in `decompose`, so
   the quote is not a parameter of either stage at any point — the same reasoning
   `stage_c.adjudicate` already uses, and a stronger guarantee than being handed
   the case and declining to interpolate it.
4. **The atomicity rule is deliberately not applied.** Two changes at once cannot
   be attributed to either, so the sentence-fragment residue is expected to
   survive this experiment.

**Two prompt rules changed rather than moved, and both are the kind of thing a
prompt split drops silently:**

- **A1 gained a rule that was previously implicit.** In the combined prompt,
  STEP 2's *"elaboration, context, a consequence, a neighbouring rule"* wording
  sat a few lines below STEP 1 and reached it for free. Split apart, A1 never sees
  it, so it is now stated in A1.
- **A2's enumeration defence had to be restated.** STEP 2 said *"Split the whole
  ANSWER however long your STEP 1 answer is"*, which names an object A2 no longer
  has. What it defended is still live — `art15_case1`'s ten-item answer coming
  back as one claim — so it became *the core count follows from the ANSWER and the
  QUESTION, a question asking for a set makes every item core, and the whole
  ANSWER is never one claim.*

**A prediction was recorded in `stage_a_twocall.py` before any numbers existed**,
so it could be wrong on the record: removing the written STEP 1 from A2's output
removes a scaffold the model was reasoning through, and A2 alone might be *less*
stable than the combined prompt. The stability numbers below are consistent with
that but do not establish it — see the caveat on metrics.

## Six probe scripts, and what each is worth

New top-level `scripts/`, invoked as `uv run python -m scripts.<name>`. A path
invocation fails: running a file by path puts `scripts/` on `sys.path` rather than
the repo root, and `pythonpath = ["."]` in `pyproject.toml` is pytest-only. There
is now both a `scripts/` and a `src/scripts/`, with no written rule separating
them — flagged at the time, not resolved.

| script | input | worth |
|---|---|---|
| `probe_a{1,2}_examples` | the prompt's own worked examples | floor test only |
| `probe_a{1,2}_adversarial` | held-out synthetic cases, one rule each | real |
| `probe_a{1,2}_baseline_cases` | the six real §4.6 cases | real, but tuned-on |
| `probe_a{1,2}_stability` | the same six, five runs each | the measurement |

Two guards, mirror images of each other. The examples probes **verify their
literals verbatim against the prompt** before any call goes out — parsing the
examples out of the prompt instead would let a defective prompt feed itself
defective input and agree with itself. The adversarial probes assert the
**inverse**: that no probe appears in the prompt, so a correct answer cannot come
from copying.

Every expectation carries its `basis` — a rule quoted from the prompt, or the
assistant's reading. This was built in structurally because the previous session's
devlog records the same omission as a mistake. It did not prevent the assistant
making it again in conversation; see below.

**Checks that need nobody's agreement** are reported mechanically: words
introduced that are absent from the gold answer, bare polarity claims, the whole
answer returned as one claim, and a leading-conjunction fragment heuristic. Two of
those four turned out to encode the assistant's assumptions after all.

## A1: clean everywhere it was pointed

**Its own four examples — 4/4 exact**, character for character after whitespace
normalisation. Uninformative on its own: the expected output sits in the prompt a
few hundred tokens above the input, and 4/4 is what a pure copier scores.

**Six held-out adversarial probes — 6/6 matched expectation.**

| probe | rule | result |
|---|---|---|
| 1 | empty when nothing answers | `''` |
| 2 | empty when *related but non-answering* | `''` |
| 3 | polarity with `Yes.` not `No.` | kept, neighbouring rule dropped |
| 4 | 7-item list, longer than any example | all seven kept |
| 5 | half-answered question — **no rule exists** | returned the answering half |
| 6 | clumsy wording preserved | preserved, not tidied |

Probe 2 is the strongest: the answer is entirely about failing to respond in time
— remedies, burden of proof — without ever stating a period. That is the
`art41_case3` shape and A1 returned empty cleanly. Probe 4 stresses the
enumeration past `EXAMPLE 1`'s four items with a trailing sentence the examples
never demonstrate, and all seven survived.

**Probe 5 is a finding about the prompt, not the model.** The question asks two
things and the answer addresses one. A1 returned the answering half — which the
prompt does not license. It is told to write *"the shortest version that still
**fully** answers the QUESTION"* and to return empty when *nothing* answers; it
says nothing about a partial answer. Both behaviours are defensible from the text.
This is not academic: a gold answer that half-answers its question is **a defect
in the case**, and which behaviour A1 takes decides whether the pipeline reports
it as `insufficient` (blaming the quote) or as an empty decomposition (blaming the
case). Different repairs. Undecided.

**Six real §4.6 cases — all six matched the derived expectation, 0/6 introduced
wording.** `art41_case3` returned without its terminal full stop. The stability
run then showed this is **systematic, not drift** — 5/5 runs, identical. §4.6
records "trailing-dot drift" for this case under the three-example prompt; it has
survived the call split as a stable quirk, which is better than an intermittent
one because A2's comparison can be designed around it.

**Stability — 6/6 stable over 30 calls**, one distinct output per case, identical
down to punctuation at the strict threshold. `art8_case1` — the 1/1/2/1 case —
returned the same string five times. `art15_case1`'s 400-character enumeration
came back byte-identical five times.

Caveat: A1 writes one string. It is the easier half, and its stability says
nothing about A2.

## A2: clean on examples and baseline, unstable under repetition

**Its own four examples — 4/4 on count, tag sequence and exact texts.** The
`reason` fields also came back verbatim from the prompt, which means the floor
test says nothing about whether A2 can *generate* a reason — the thing that
matters most now that the written STEP 1 is gone.

**Six held-out adversarial probes, on the old model (`deepseek-v4-flash`):**

| probe | expectation | result |
|---|---|---|
| 1 rule collision: consequence *is* the answer | `[aux, core, core]` | ✅ |
| 2 rule collision: specificity *is* the answer | `[aux, core]` | ✅ |
| 3 two-part question, both parts core | `[core, core, core, aux]` | ✅ |
| 4 five-item enumeration | 5 core | ❌ packed into one claim |
| 5 one assertion with a proviso | 1 claim whole | ✅ |
| 6 polarity + two substantive cores | `[core, core, aux]` | ✅ |

The probes were weighted toward the silent direction on purpose, four of six.
**Both rule collisions held**, which is the strongest result: the prompt says a
consequence is auxiliary and that added specificity is auxiliary, and both probes
ask a question whose answer *is* the consequence or *is* the specificity.
Mechanical rule-following gives the wrong tag, silently. A2 took neither bait, and
the reasons show it reasoning about the question rather than pattern-matching —
*"The question asks what happens upon failure to notify, not what the notification
obligation is; the shortest sufficient answer would state the consequences of
failure, not restate the rule that was violated."* Newly written, case-specific,
and the answer the floor test could not give.

**Six real §4.6 cases, on the new model — core content matched on all six, 0
mechanical breaches.**

| case | §4.6 | actual | |
|---|---|---|---|
| `art7_case3` | 1 core | `[core, aux]` | matches Bertan's ruling |
| `art7_case4` | 1 core | `[core, aux]` | matches the disputed reading |
| `art8_case1` | 1 core | `[core, aux, aux]` | consequence stayed auxiliary |
| `art33_case1` | 1 core | `[core, core, aux]` | same material, split in two |
| `art15_case1` | 10 core | `[core × 10]` | exactly ten, stem repeated |
| `art41_case3` | 1 core | `[core, aux, aux]` | renewal auxiliary, no fragment |

`art15_case1` returning ten core claims with the stem repeated into each —
*"When an individual requests access, the company must provide…"* — is the single
best result of the session. That case collapsed to one claim under the
three-example prompt, and its ten claims are what produce stage C's two real
`absent` findings.

`art41_case3` produced **no fragment**. §4.6 records it as the one case worse
after the prompt work than before, because one run returned *"and may be renewed
on the same conditions, provided…"* and tagged it core. Here it came back as two
clean auxiliary claims with proper subjects.

`art33_case1` returned **2 core where §4.6 says 1**, splitting *"without undue
delay"* from *"within 72 hours"*. Both core, same material. Under Bertan's third
reframe this is not a defect, and it is the worked example proving the count
metric is wrong.

## Stability: two 30-call runs, and the metric mattered more than the model

Run with core **coverage** as the comparison — which words of the gold answer are
marked core — rather than core count.

| case | sample 1 counts / coverage | sample 2 counts / coverage |
|---|---|---|
| `art7_case3` | 1 / 1 stable | 1 / 1 stable |
| `art7_case4` | 1 / 1 stable | 1 / **2 unstable** |
| `art8_case1` | **1 / 2 unstable** | 1 / 1 stable |
| `art33_case1` | 2 / **3 unstable** | 2 / **3 unstable** |
| `art15_case1` | **1 / 2 unstable** | 3 / **3 unstable** |
| `art41_case3` | **1 / 2 unstable** | 1 / 1 stable |
| | **4 of 6 unstable** | **3 of 6 unstable** |

**The `counts` column is the finding about the instrument.** In sample 1,
`art8_case1`, `art15_case1` and `art41_case3` all returned the *same number* of
core claims on every run — count-stable — while their core *content* differed.
§4.6's metric is core count, so **it would have called all three stable**.
Coverage caught what count structurally cannot see. §4.6 records `art8_case1` as
*"6/6 correct, identical core set"*; if that was measured by counting, the
identical-core-set half may never have been checked.

**Two of the failures are degenerate output, not disagreement.**

- `art7_case4` sample 2 run 1 returned **one core claim whose text is literally
  `"..."`**.
- `art15_case1` sample 2 run 2 returned **one core claim whose text is the empty
  string**.

Both got past the schema because `str` accepts `""` and `"..."`. They are the
entire "unstable" verdict for their case in that sample.

**Genuine instability, in both samples:**

- `art33_case1` — three distinct coverages. The runs split *"without undue delay"*
  and *"within 72 hours"* differently, and the diff words are `notification`,
  `made`, `be`, `and`. Granularity, same material — arguably not a defect at all
  under the third reframe, which suggests the coverage metric is still slightly
  too strict about reworded stems.
- `art15_case1` — claim counts of **10 / 1 / 10 / 13 / 10** in sample 2. The 1 is
  the empty claim; the 13 is a real over-split.

**The instability is itself unstable across samples** — a different three cases in
each run. At N=5, a failure occurring 1 run in 5 has a substantial chance of not
appearing at all. Neither sample is a rate.

**The comparison to §4.6 is not like-for-like**, and the assistant flagged this
before Bertan asked. §4.6 measured core count under the combined prompt; this
measures core coverage under the split. Since three cases are count-stable and
coverage-unstable, the combined prompt may have been equally unstable and simply
never measured for it. **Settling whether the split helped or hurt requires
re-running the untouched `stage_a.py` under the coverage metric** — 30 calls, and
both the module and the metric already exist. Not done.

## A transport failure that had been latent in all five stages

An adversarial re-run died with:

```
AttributeError: 'NoneType' object has no attribute 'claims'
  stage_a2.py:227  return [Claim(...) for c in response.claims]
```

`with_structured_output` yields `None` when the model's output cannot be coerced
into the requested schema. **Every stage had the same shape** — `stage_a`,
`stage_a1`, `stage_a2`, `stage_b` and `stage_c` all read a field straight off what
`ainvoke` returned — and the traceback named neither the stage nor the cause.
Because the probes used plain `asyncio.gather`, one bad call took down all six.

`require_response` and `JudgeResponseError` now live in `llm.py`, applied at all
five call sites. `build_judge_llm` was kept as the seam so the existing 49 tests
were untouched; the guard sits on the response instead.

**The error type is deliberately unrelated to `AdjudicationError`.** A transport
failure is a case that was never judged; an adjudication failure is a judgement
that went wrong. Folding them together would let a caller tolerating a bad mapping
silently drop unjudged cases, which shrinks an eval sample without saying so.
Pinned as its own test.

Six tests added — one per stage asserting the error names *that* stage, plus the
type-relationship test. **Tested per call site rather than once on the helper**:
the defect was never in a helper, it was five sites each missing a check, and a
helper test passes against a stage that dropped it. Mutation-checked — removing
the guard from A2 fails exactly that stage's test and no other.

`probe_a2_stability.py` also uses `return_exceptions=True`, so a failure costs one
data point rather than the run, and losses are counted and reported rather than
quietly reducing N.

**Bertan added `.with_retry(stop_after_attempt=3)` to `build_judge_llm`.** It
covers transient API errors. It does *not* cover the observed `None`, which is a
returned value rather than a raised exception, so the guard remains what catches
that. Noted at the time: `model_params` already carries `'max_llm_retries': 3`
and nothing reads it, so line 108 hardcodes a 3 beside a config field that exists
for exactly this.

**The assistant touched `stage_a.py` after promising to freeze it.** The change is
defensive only — prompt, schema and mapping are byte-identical, and a successful
run is unaffected — but the promise was made and then broken, and the decision to
break it was the assistant's rather than Bertan's.

## `ai-common`: five models, merged, and the import win finally lands

Added `DEEPSEEK_V_4_FLASH_0731`, then `DEEPSEEK_V_4_PRO_0813`, `QWEN_3_7_FLASH`,
`QWEN_3_8_27B` and `MIMO_V_2_5`, each with its OpenRouter alias. Branch
`openrouter-model-aliases`, commit `969a6d2`, [#30](https://github.com/bgunyel/ai-common/pull/30),
merged as `05aed76`, branch deleted locally and remotely.

Naming follows the file's conventions: `MIMO_V_2_5` after `MINIMAX_M_2_5` for the
`-v2.5` form, `QWEN_3_8_27B` after `GPT_OSS_120B` for the size suffix, date
suffixes after `KIMI_K2_0905`. Verified no duplicate enum values — 25 members, 25
distinct — because `Enum` silently aliases a duplicate onto the first member
rather than erroring, so a copy-paste slip would produce a hidden alias instead of
a new model. Suite green at 146 before committing.

**All five are OpenRouter-only**, so `get_model_name_alias` raises `KeyError` if
one is requested on Ollama or Groq. That is the 2026-08-10 `GPT_OSS_120B` trap
exactly, and it is recorded in the commit body rather than only here.

`uv.lock` in `ai-common` was already dirty before any of this — a lockfile format
bump (`revision 2` → `3`, `upload_time` → `upload-time`) plus dependency bumps
such as `anthropic 0.121.0` → `0.122.0`. Deliberately excluded from the commit; it
moves dependencies and belongs in its own change. Still uncommitted.

**In `clause-and-effect`, the pin string never needed changing** — it was already
`@main`. What was stale was the lock, held at `a0f06ea`. Re-resolved to `05aed76`
with `uv lock --upgrade-package ai-common`: a **one-line lock diff**, no dependency
movement.

That re-resolve also carried `ai-common`'s lazy package `__init__`, which
`todo.md` has been waiting on since 2026-08-10:

| | before | now |
|---|---|---|
| `import src.llm_config` | ~7.7s | **0.233s** |
| modules loaded | 3124 | **285** |
| torch pulled | yes | **no** |

**Prediction met** — `todo.md` predicted ~0.2s. Backlog item 6's blocker
(*"Nothing reaches this repo until the branch merges"*) is closed. The win reaches
`gdpr_test_data_generation.py`, `sufficiency/judge.py` and `main_dev.py`.

Both `orchestrator_model` and `writer_model` now run `DEEPSEEK_V_4_FLASH_0731`.
Bertan changed `orchestrator_model` first; the assistant caught before spending
calls that the probes read `writer_model`, which was still on the old model, and
would have compared a model against itself.

**The model change fixed the one clear A2 adversarial failure.** PROBE 4's
five-item enumeration, packed into a single core claim by `deepseek-v4-flash`, now
splits one claim per item with the stem repeated into each. PROBE 5 also changed:
the new model split the temporary/definitive disjunction and tagged the definitive
half auxiliary — **better than the assistant's expectation**, since the question
asks only about temporary limitations — but introduced the words `must be`,
paraphrasing *"provided that the limitation is appropriate"*, which breaks the
wording rule and was caught mechanically. PROBE 1 on the new model was lost to the
`None` crash and never re-run.

---

## Verification

- Suite **298 → 304 passed**, 5 xfailed, green before every commit.
- The `None` guard was mutation-checked: removing it from stage A2 fails exactly
  that stage's parametrized test and no other; source reverted and confirmed.
- `ai-common`'s 146 tests run green before its commit; all five new models
  resolved end to end through `get_model_name_alias` on `OPENROUTER`; enum value
  uniqueness asserted.
- Probe literals verified verbatim against their prompts before any call;
  adversarial probes verified **absent** from their prompts.
- A1: 4 + 6 + 6 single-pass calls and 30 stability calls. A2: 4 + 6 + 6 + 6
  single-pass calls and 60 stability calls across two samples.
- `import src.llm_config` measured directly, with `sys.modules` count and a torch
  presence check rather than timing alone.
- Both invocation forms for `scripts/` tested; the failing one documented.

## Mistakes made this session

All the assistant's unless stated.

- **The answers were far too long, and Bertan lost the thread of the session.**
  Told once to keep them brief; the next substantive answer was long again, and
  Bertan had to say *"I couldn't even follow what you were doing… I don't know
  where you are, what you have done."* For a session whose output is a judgement
  about an instrument, burying the result in commentary destroys the result.
  Recorded to memory as `keep-answers-brief`.
- **PROBE 4 was reported as "the failure" against the assistant's own expectation,
  without flagging whose standard it was** — the exact mistake the previous
  session's devlog records, reproduced while the assistant was explicitly claiming
  to have designed it out. The `basis` field was in the script; the conversation
  ignored it.
- **PROBE 4 was then graded three different ways in three messages** — headline
  failure, then granularity-only and less severe, then a stated-rule breach after
  all. The oscillation was itself the signal that the standard had never been
  pinned down.
- **Two of the four "mechanical, needs nobody's agreement" checks encoded the
  assistant's assumptions.** The rule *"Never return the whole ANSWER as a single
  claim"* is over-broad — PROBE 5 is a legitimate single claim and it fired
  wrongly — and it failed to catch PROBE 4, the collapse it was written for. The
  leading-conjunction fragment heuristic fired three times on `"Where…"`, wrong
  every time; `Where` opens ordinary legal conditionals constantly. Narrowed
  later, but it would have flooded a real work list.
- **The first stability run was piped through `tail -25`**, discarding every
  per-case coverage diff — the entire diagnostic value of the run. It had to be
  repeated, and the second sample is not the same sample.
- **The initial reading of Bertan's two-call design was wrong** (a pipeline), and
  the assistant had begun building it, including asking a blinding question that
  the correct design makes moot.
- **`stage_a.py` was modified after the assistant had stated it would be frozen**
  as the §4.6 baseline. Defensive change only, and flagged — but the promise was
  the assistant's to keep.
- Ran `probe_a2_adversarial` against `writer_model` while Bertan had changed
  `orchestrator_model`; caught before spending calls, but only just.

## State handed to the next session

| | |
|---|---|
| `clause-and-effect` | `dev-04`, four commits pushed, tree clean, no PR open |
| `ai-common` | `main`, #30 merged, branch deleted, `uv.lock` still dirty |
| Suite | **304 passed / 5 xfailed** |
| Judge | stages A, B, C built; A also exists as A1+A2; verdict derivation, panel, calibration **not built** |
| Stage A | combined `stage_a.py` untouched; two-call variant measured but not adopted |
| Model | both roles on `DEEPSEEK_V_4_FLASH_0731` |
| Gate | `make upgrade-safe` **not run** on this branch; required before a PR |

## Open items — start here next session

| # | open item | state |
|---|---|---|
| 1 | **Reject degenerate claims in `stage_a2.py`** — text `""` and `"..."` reached the caller and account for 2 of 3 stability failures | one guard, then re-measure |
| 2 | **Re-run the combined `stage_a.py` under the coverage metric** — without it, nothing says whether the split helped or hurt | 30 calls; module and metric both exist |
| 3 | **Build the A1↔A2 consistency check** — the whole point of independent calls, designed and not built | makes instability visible in one run |
| 4 | **The atomicity rule** — still unapplied, deliberately held out of this experiment | one edit, then re-measure |
| 5 | **`art7_case4`'s third sentence: core or auxiliary** — Bertan's call. The 2026-08-22 asymmetry argues for core | undecided; it scores the prompt |
| 6 | **A1's partial-answer behaviour is unspecified** — the prompt has no rule for a question the answer half-answers | decides whether the defect is reported against the quote or the case |
| 7 | **Measure beyond the six** — 6 of 433 seen; `conditional` (133) never touched | reframed from "held-out test" to a coverage gap |
| 8 | **Rewrite §4.6's expectations as *which rule does this case test*** rather than *what output is correct* | checkable against the prompt, not against memory |
| 9 | **§4.6's metric is core count and should be coverage** | the table's stability claims may not have been measured |
| 10 | `make upgrade-safe` on `dev-04`; `ai-common`'s `uv.lock` churn as its own change | required before a PR closes |
| 11 | Wire `max_llm_retries` into `with_retry` instead of the hardcoded 3 | config field exists and is unread |
| 12 | `scripts/` and `src/scripts/` coexist with no written rule separating them | decide or document |
| 13 | The panel (§8) and calibration (§9) — **now unblocked**, four extra OpenRouter models available | not started |
| 14 | `judge.py` prints rather than logs — the six new probe scripts do too | deliberate, flagged, not fixed |
| 15 | `art8_case5`'s `contradicted` — probable false positive; de-escalated by the error asymmetry | unresolved |
| 16 | Everything on the 2026-08-17 lists — the gate's detection side, the three GuardDog defects | untouched |
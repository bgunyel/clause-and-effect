# The answer-vs-quote sufficiency judge

Every Tier-1 test case carries a `supporting_quote`, and the deterministic gate
in `src/eval/golden_qa.py` checks that the quote is a substring of its source
article. That is **provenance**. It says nothing about whether the quote
*answers the question it is attached to* — which is **sufficiency**, and which is
the property the eval actually depends on. This module measures sufficiency.
The failure it exists to prevent is a golden set that looks clean and is not:
`gdpr_art2_case4` grounds *exact*, clears every deterministic gate, and its quote
is a verbatim fragment of Article 2 that never contains the negation its answer
asserts. Perfect provenance, zero sufficiency. Sufficiency is semantic, so it is
judged rather than measured, which is why it lives outside `golden_qa.py` — that
module stays free, deterministic, and runnable on every change.

---

## 1. Status — what exists and what does not

This document describes a mechanism that is **half built**. The directory's
convention is that a design document describes what exists; this one does not
yet, and says so rather than reading as though it did.

| Component | Location | State |
|---|---|---|
| Criterion, protocol, verdict vocabulary | `sufficiency/__init__.py` docstring | **Built** — documented in code |
| Types (`Claim`, `Decomposition`, `BlindAnswer`, `ClaimVerdict`, `Adjudication`, `PanelistRun`, `CaseJudgement`) | `sufficiency/models.py` | **Built** |
| Stage A — decompose | `sufficiency/stage_a.py` | **Built**; wiring tested, tagging quality still eyeballed on 8 cases |
| Stage B — answer blind | `sufficiency/stage_b.py` | **Built**; wiring tested, leakage resistance still one observation on one case |
| `span_is_verbatim` | `sufficiency/stage_b.py:span_is_verbatim` | **Built and mutation-tested** (§5.5) |
| Stage C — adjudicate | `sufficiency/stage_c.py` | **Built** 2026-08-17 (§6) |
| Verdict derivation | `Verdict` in `models.py`; no function derives one | **Specified below, not built** |
| `sufficient_verbose` threshold | — | **Not decided** — to be measured |
| Panel runner / aggregation | `CaseJudgement.unanimous` exists; nothing populates it | **Specified below, not built** |
| Calibration sample | — | **Not started** |
| Tests — stages A, B and C | `tests/test_sufficiency_stages.py` | **Built** — 49 tests, 36 mutations, no survivors (§1.1) |
| `main()` probe harness | `sufficiency/judge.py:main` | Built — a scratch driver over 8 cases, not the runner |

Sections 2–5 describe built behaviour. Sections 6–10 are specification for work
not yet done, and are marked as such. **No verdict from this module gates
anything today**, because judge–human agreement is unmeasured (§9).

### 1.1 The test surface, and what it deliberately does not reach

`tests/test_sufficiency_stages.py` pins what is **deterministic** in stages A, B
and C. No model is called: each stage's runnable is replaced by a fake, so what
is under test is the stage's own wiring — which prompt it sends, which schema it
asks for, how it maps what comes back, and for stage C when it declines to call
at all.

| Group | What it pins |
|---|---|
| **Structural blinding** | §3's claim, as an *invariance*: two inputs agreeing only on the fields a stage may see must render byte-identical prompts. Plus label positions (`QUESTION:` < question < `ANSWER:` < answer), and that stages B and C never name the regulation (§5.2, §6.1) |
| **`span_is_verbatim`** | 13 cases — substring, case, whitespace, space-before-punctuation and list-marker all verbatim; empty, whitespace-only, paraphrased, reordered, stitched-from-disjoint-parts and inserted-comma all not |
| **Response mapping** | `answered=False` with an empty span survives as a legitimate outcome (§10.1 escape), and an empty `core_claims` is not an error (§4.5) |
| **Stage C's claim matching** | A response listing claim 2 before claim 1 still lands on the right claims, and an invented, zero-numbered, duplicated or dropped claim number raises rather than being silently repaired (§6.2) |
| **Stage C's no-call paths** | No claims, and no answer text, each return without a model call; a `answered=False` that nonetheless carries answer text is judged, because the guard is on the text (§6.3) |
| **Schema wiring** | Asserted by field names rather than the private class, so a stage swapped onto another stage's schema fails |
| **Import cost** | Importing a stage loads neither `torch` nor `langchain_core` — see below |

Two prompt-level assertions use `rindex` rather than `index`, because stage A's
worked examples (§4.6) carry their own `QUESTION:`/`ANSWER:` lines. Against
`index` those tests would compare the real fields against the *examples'* labels
and pass however the real ones were ordered.

**Why blinding is tested as invariance rather than by searching for the quote.**
A sentinel check answers "is *this* field absent"; the invariance answers "can
*any* field but the permitted two reach the prompt". A field added to a prompt
later fails the second and slips past the first, and the blinding is the property
the whole protocol rests on.

**Mutation results.** 36 mutations injected one at a time — 20 for stages A and B
and `llm.py`, 16 for stage C — **all 36 killed, no survivors**. The load-bearing
ones: leaking the quote into stage A's prompt (4 tests fail), leaking the gold
answer into stage B's (4), leaking stage B's span or note into stage C's (2 each),
removing the empty-span guard — without which `""` is a substring of every quote,
so a stage B that found nothing reads as having copied perfectly (2) — erasing
punctuation inside `span_is_verbatim`, caught by exactly the one test that exists
to pin that boundary (§5.5), and pairing stage C's verdicts by position instead of
by claim number, which is the failure that would silently mislabel rather than
fail.

**The tests forced a source fix.** Both stage modules import `build_judge_llm` at
module scope, so `sufficiency/llm.py` charged every importer — and every test —
for langchain → transformers → torch: **6.3s** to `import
src.eval.sufficiency.llm`, 2.4s on the suite. Two imports had to move, not one.
`get_llm` is now called inside `build_judge_llm`, and the two `langchain_core`
names — needed only by the signature, which `from __future__ import annotations`
already makes a string — sit behind `TYPE_CHECKING`. Deferring `get_llm` alone
would have bought nothing, because `langchain_core` is the leg that pulls torch.
Measured after: **6.3s → 0.11s**, and the test file runs in **0.32s** against
6.60s before. The cost is deferred, not removed — the first `build_judge_llm`
call still pays it.

That guard runs in a **fresh interpreter**, because by the time it executes
another test module has already imported torch into the pytest process and an
in-process `sys.modules` check would pass regardless. Both mutations that undo
the fix are caught, and caught *by wall clock as well as by assertion* — the file
takes 8.3s and 14.0s under them against 0.32s clean.

**What the tests do not reach.** They say nothing about whether stage A tags
core/auxiliary *correctly* or whether stage B actually resists parametric
leakage. Those are judge behaviour, measured against human labels, and they
remain one observation each on eight eyeballed cases — that is calibration (§9),
not unit testing, and it is why no verdict here gates anything yet.

---

## 2. The criterion

> **Every question must be answerable using only its `supporting_quote`.**

Set by Bertan on 2026-08-03 and refined on 2026-08-05. It is deliberately the
**weaker** of two candidate readings. The stronger one — *the gold `answer` is
entailed by the quote* — was rejected.

### 2.1 The deciding case

`gdpr_art7_case3` asks *"Can a data subject withdraw their consent after they have
already given it?"* Its gold answer has two sentences; the quote covers only the
first. Bertan's ruling: the shortest sufficient answer is

> *"Yes, the data subject shall have the right to withdraw their consent at any time"*

and the second sentence — that withdrawal does not affect the lawfulness of
processing already carried out — is **auxiliary information that strengthens the
statement**, not a claim the quote must carry. It is also, verbatim, the
`supporting_quote` of `gdpr_art7_case4`: article-supported, just not
quote-supported by *this* case's quote.

### 2.2 Why the reading changes the size of the problem

This is not one case bending a rule. **Measured 2026-08-05: 175 of 433 cases**
have at least one gold-answer sentence poorly covered by their quote. Under the
strict reading roughly 40% of the set becomes a candidate failure; under this
ruling most of those are auxiliary surplus. It is the difference between a
repair set near ~169 and one near ~300.

The consequence for design is structural, not cosmetic: **separating *core* from
*auxiliary* claims is the load-bearing part of this module**, not a refinement of
it. A judge that cannot make that distinction cannot implement the criterion at
all.

### 2.3 Sufficiency is two-sided

- A quote that **cannot** answer its question is **useless**.
- A quote carrying far **more** than the question needs is **not useless but
  devalued** — it dilutes retrieval ground truth and inflates any span-overlap
  metric computed against it.

Both sides are reported. Stage B therefore returns the **minimal sufficient
span**, so the same pass produces the repair and not merely the diagnosis.

### 2.4 Why this is not a deterministic check

A `key_phrases`-in-quote screen was built and **rejected as a gate**, on
measurement rather than principle:

| Screen | Cases flagged |
|---|---|
| Literal `key_phrase` matching | 57 (mostly word-order noise) |
| Subsequence matching | 35 |

It still fails on glosses. `gdpr_art8_case1` is flagged for missing the phrase
`'parental consent'` even though its quote fully answers *"what is the minimum
age?"*. The screen's surviving role is **triage and judge calibration** (§9.3),
not gating.

Scope measured at the time: the repair set is **169 cases, not 134** — 35 cases
pass the deterministic gate today and fail the sufficiency criterion. The screen
split the set into 264 grounded-and-covered, 35 grounded-but-flagged, 110
ungrounded-but-covered, 24 both.

---

## 3. The protocol — three blinded stages

Each stage is blinded to whatever would let it rationalise a conclusion it has
already been shown. The blinding is **structural, not instructed**: each prompt
is built from only the fields that stage is allowed to see, so there is nothing
to leak. A prompt cannot leak what it was never given.

| Stage | Sees | Blind to | Produces                                                                                             |
|---|---|---|------------------------------------------------------------------------------------------------------|
| **A — Decompose** | `question`, gold `answer` | the quote | shortest sufficient answer; every claim tagged `core`/`auxiliary`, each with a reason                |
| **B — Answer blind** | `question`, `supporting_quote` | gold answer, source article | minimal span (copied verbatim), an answer derived from it (blind answer), an `answered` flag, a note |
| **C — Adjudicate** | `question`, tagged claims, blind answer | the quote | per-core-claim `supported`/`contradicted`/`absent`, with rationale                                   |

The ordering is what makes it work. Stage A cannot fit its core/auxiliary tagging
to whatever the quote happens to contain, because it has never seen the quote —
which is precisely the failure that would erase the §2.1 ruling. Stage B cannot
work backwards from the conclusion, because it has never seen the gold answer.
Stage C compares two independent artifacts and never sees the evidence either was
derived from, so it cannot substitute its own reading of the quote for theirs.

Each panel member runs A→B→C independently and votes. Disagreement is a
calibration signal, not noise to be averaged away (§8).

---

## 4. Stage A — decompose (built)

`sufficiency/stage_a.py` — `decompose`, with `STAGE_A_INSTRUCTIONS`,
`_StageAClaim`/`_StageADecomposition` and `build_stage_a_prompt` beside it.

### 4.1 Mechanism

Two steps in one call:

1. **Write the shortest version of the ANSWER that still fully answers the
   QUESTION**, using only wording that appears in the answer. Empty if nothing in
   the answer answers the question.
2. **Split the whole answer into atomic claims** and tag each `core` if its
   content appears in the shortest sufficient answer, `auxiliary` otherwise.

Additional constraints in the prompt, each closing a specific way the split goes
wrong:

- A bare *"Yes"* or *"No"* is not an answer on its own — keep the substance it
  rests on.
- If the question asks for a list, a sufficient answer carries **all** items.
- Keep a polarity marker attached to the proposition it qualifies rather than
  making it a claim of its own.
- Split conjunctions and separate obligations, but not so far that a fragment
  stops meaning anything.
- Judge against the question **exactly as written** — not what a more thorough
  question might have asked, and not where the answer's information came from.

### 4.2 Why "write the shortest sufficient answer first" and not leave-one-out

The first implementation used a leave-one-out removal test: *delete this claim;
does the rest still answer the question?* It returned **zero core claims** on
`gdpr_art7_case3` — the very case the criterion was settled on.

The mechanism of the failure: taken one claim at a time, *"Yes."* was excused
because the substantive clause remained, and the substantive clause was excused
because *"Yes."* remained. **Leave-one-out cannot see mutual redundancy.** It
marks both members of a redundant pair removable, though removing both destroys
the answer.

Writing the shortest sufficient answer is also how the criterion was stated in
the first place, and it keeps the judge **performing** the task rather than
opining on it — the same principle carrying stage B.

Observed on `gdpr_art7_case3` after the change:

```
shortest sufficient answer: Yes. The data subject shall have the right to withdraw
their consent at any time.
```

### 4.3 Why `shortest_sufficient_answer` and `reason` are retained

Neither is decoration.

- `Decomposition.shortest_sufficient_answer` is *what the tagging was done
  against*, so it is the auditable trace of **why** a claim came out core, and the
  first thing a human calibrator reads.
- `Claim.reason` is the only thing that says which of two panel members read the
  question correctly when they tag the same claim differently. §6.2 of the plan
  requires decomposed verdicts to carry a rationale.

### 4.4 Why there were no worked examples, until the output asked

The obvious example would be `gdpr_art7_case3`, and putting it in the prompt would
destroy its value as a check on whether the judge independently agrees with the
ruling. A synthetic example is a fix for an inconsistency that has not been
observed, so it waits until the output asks for one.

**On 2026-08-17 the output asked**, and four synthetic examples were added — see
§4.6. They are synthetic rather than drawn from the golden set for the reason this
section already gives, generalised: every one of the 433 cases is *evidence*, and
the cases worth using as examples are exactly the diagnostic ones. `art7_case3`
independently reproduced Bertan's ruling on 3 of 3 runs, and `art8_case1` and
`art15_case1` are the cases whose stability is being measured. Showing the judge
the answer for a case removes that case from the evidence; a synthetic example
costs nothing.

### 4.5 An empty `core_claims` is a legitimate output

It says the gold answer does not answer its own question — a defect in the
**case**, not in the quote. It must not be treated as an error.

### 4.6 Stage A is not stable at temperature 0, and the instability reaches the verdict

Found 2026-08-17 by running the probe harness twice. `gdpr_art8_case1` returned
**1, 1, 2 and 1** core claims across four runs of an identical prompt. That is not
a cosmetic difference: with one core claim the case reads `sufficient`, and with
two the second comes back `absent` from stage C and it reads `insufficient`. The
same run also split `art7_case4` into 3 claims where another run gave 2.

Both divergences broke a constraint the prompt already stated, and in both the
model's own `reason` field **recorded the breach** — which is what §4.3 keeps
`Claim.reason` for, now demonstrated rather than argued:

- The run that tagged an extra claim core explained it as *"IMPLIED BY the
  shortest sufficient answer but adds specificity"*. The test is **appears in**.
- The run that split `No.` off as its own claim broke the polarity rule verbatim.

#### What was changed, in two rounds

**Round 1 — the rules were sharpened.** The CORE test now names implication,
consequence and added specificity as AUXILIARY and addresses the model's own
reasoning (*"if your reason for calling a claim CORE would be that the shortest
sufficient answer implies it, that claim is AUXILIARY"*), and the polarity rule now
states that a bare `Yes`/`No` claim is never correct output rather than merely
preferring the alternative.

**Round 2 — four worked examples**, because a constraint stated twice and broken a
third of the time is not fixed by stating it a third time. Ordered by descending
core count — **4 / 2 / 1 / 1** core claims out of 4 / 3 / 3 / 2 total — with the
counts stated in the prompt's own lead-in. Each targets one observed failure or one
thing at risk: an enumeration where every item is core; a shortest sufficient
answer spanning two claims, plus a consequence tagged auxiliary; a consequence that
repeats the core claim's own number and is still auxiliary; and polarity attached,
with the reason saying so in as many words.

#### The measurements

Each cell is *N* independent calls to stage A for one case, identical prompt,
`temperature=0`, DeepSeek V4 Flash. Any difference between runs in one cell is
model nondeterminism, not a different input. **The property that matters is the
core-claim set**, because stage C sees only core claims, so a core set that varies
between runs is a verdict that varies between runs.

| case | what it probes | correct output | N | rules only | + 3 examples | + 4 examples |
|---|---|---|---|---|---|---|
| `art7_case4` | polarity — is `No.` split off? | 1 core, `No.` attached | 6 | bare `No.` in **2/6** | 0/6 | **6/6 correct**, identical |
| `art8_case1` | implication — is a consequence tagged core? | 1 core | 6 | 6/6 correct | 6/6 | **6/6 correct**, identical core set |
| `art7_case3` | the case the criterion was settled on | 1 core; prior-lawfulness auxiliary | 3 | 3/3 | 3/3 | **3/3**, ruling reproduced |
| `art33_case1` | consequence — *reasons for delay* stays auxiliary | 1 core | 3 | 3/3 | 3/3 | **3/3** |
| `art15_case1` | enumeration — a 10-item answer | 10 core, one per item | 3 | 3/3 | **1 claim total** ✗ | **3/3**, one run fragmentary |
| `art41_case3` | *renewal* stays auxiliary | 1 core | 3 | 3/3 | 3/3, trailing-dot drift | **1 of 3 promotes renewal** ✗ |

Read across the last three columns rather than down them. The two hunted failures
are at zero in the current prompt, and four cases hold in all three states — but
examples damaged two cases that had been correct without them:

- **`art15_case1` collapsed from 10 core claims to 1** under three examples, on all
  three runs. Two of those three examples had a single core claim *and* a first
  claim that was verbatim the shortest sufficient answer, and the model generalised
  *"claim 1 = STEP 1's text"* — right when STEP 1 is one sentence, catastrophic when
  it is a whole enumerated answer. The third example contradicted it and was
  outvoted. Reordering to 4 / 2 / 1 / 1 and adding the rule that splitting does not
  depend on STEP 1's length repaired it.
- **`art41_case3` is the one case now worse than when this started.** One run in
  three promoted *"and may be renewed on the same conditions…"* to core.

#### The residue, and it is not small

**Sentence-fragment claims are a new failure mode introduced by the examples.** One
`art15_case1` run returned claims like `"the personal data itself"` and `"and
information including: the purposes of processing"`; one `art41_case3` run returned
`"and may be renewed on the same conditions, provided…"` and tagged it core. These
break a rule already in the prompt — *do not split so far that a fragment stops
meaning anything on its own* — and a fragment handed to stage C cannot be judged
supported or absent in any useful way. Example 2 models the correct behaviour
explicitly, repeating the full subject in both of its core claims, and the model
fragmented anyway; so the fix is a rule, not a fifth example. **Not yet applied.**

**Two caveats on all of the above, and they limit what it is worth.**

1. **Three prompt revisions have been tuned against the same six cases**, and
   small-*N* differences are being read as signal. Some of what looks fixed is
   fitted. `art41_case3`'s "three different shapes in three runs" is one
   observation of instability, not a rate. The next measurement should include
   cases *not* used for tuning — a stratified sample of ~20 across the four
   `answer_type`s at three runs each is about 60 calls on this model.
2. **Only `art7_case3`'s expected output rests on a ruling of Bertan's.** The other
   five "correct output" columns are the assistant's classification. `art7_case4`
   is the case to watch: round 1 demoted *"The data processed while consent was
   still valid remains lawfully processed"* from core to auxiliary, and the 6/6
   result is against that reading. Read as core, the current prompt scores 0/6
   there.

**A prompt fix cannot remove run-to-run variance at temperature 0.** It narrows one
failure mode. The panel (§8) and the reporting of non-unanimity are what make the
residue visible instead of invisible — and this section is the first evidence that
they are load-bearing rather than ceremony.

---

## 5. Stage B — answer blind (built)

`sufficiency/stage_b.py` — `answer_blind`, with `STAGE_B_INSTRUCTIONS`,
`_StageBAnswer` and `build_stage_b_prompt` beside it.

### 5.1 Mechanism

Three steps, in this order:

1. **Copy the shortest continuous run of the EXCERPT that carries the answer**,
   character for character. No paraphrase, no stitching separate parts, no
   repairing spelling or punctuation. Empty if no run carries the answer.
2. **Answer the question from the text copied in step 1**, as fully as that text
   allows and no further.
3. **State whether the excerpt answered the question** — `answered` is true only
   if step 1 found text. If false, the note must say whether the excerpt concerns
   the right subject but does not settle the question, or concerns something else
   entirely.

### 5.2 The dominant failure mode, and the two defences against it

The risk that would make every verdict here worthless: the judge knows GDPR and
answers from memory when the quote does not support it.

1. **The regulation is never named.** The prompt says *"EXCERPT of legal text"*,
   not "GDPR article". A capable model will often recognise it anyway, so this
   reduces prior activation rather than guaranteeing anything — which is why the
   instructions also state outright that answering from prior knowledge is the
   failure being tested: *"an answer that is correct in law but absent from the
   EXCERPT is a wrong answer here."*
2. **The span is copied before the answer is written.** Producing the answer
   first invites the model to find a span fitting a conclusion it already holds.
   Producing the span first means there is nothing to answer from until it has
   found text.

### 5.3 Observed: the defence held on the case it was built for

`gdpr_art2_case4` is the adversarial case — its quote lists law-enforcement
purposes and contains no negation, while its gold answer is *"No, GDPR does not
apply…"*. Any model that knows Article 2(2)(d) can supply the missing "No".
Actual output:

```
-- stage B: answered=False  span verbatim=True  245/245 chars
   answer: The excerpt does not directly state whether GDPR applies to law
           enforcement agencies investigating criminal offences...
   note:   The excerpt concerns the right subject ... but does not state whether
           GDPR applies. It appears to be a definition or scope provision from a
           related instrument (possibly the Law Enforcement Directive)...
```

The model recognised the text, reasoned about its provenance, and still refused
to answer beyond it. If parametric leakage were going to sink this design, it
would have sunk it there. **This is one observation on one case, not a measured
rate.**

### 5.4 Why the span is a single continuous run

`minimal_span` is required to be one continuous run, not a list of spans. This is
**conservative**: where an answer genuinely needs disjoint pieces, the shortest
continuous run covering them is the whole stretch between them, so the span looks
longer and *fewer* cases are flagged verbose. Multi-span evidence is a pending
schema decision for `supporting_quote` itself (§10.2); this stage should follow
that decision rather than pre-empt it.

### 5.5 `span_is_verbatim` — a deterministic check on the judge's own output

`sufficiency/stage_b.py:span_is_verbatim`. Stage B is told to copy; a span it paraphrased
instead is not a repair candidate. Matching reuses
`golden_qa.normalize_for_grounding` rather than reimplementing it, so the judge
and the grounding gate cannot drift apart on what "the same text" means — the
same requirement §3.1 places on the retrieval scorers.

It returned 8/8 verbatim on the probe set, which by this project's own rule made
it unverified rather than working — a gate never observed to fail is not known to
work. **It is now mutation-tested** (§1.1): thirteen cases, and four mutations —
the empty-span guard removed, the normalized fallback removed,
always-true-for-non-empty, and punctuation erased alongside whitespace — each
killed by the tests that exist for them.

One boundary is worth naming, because it is the one a later edit will be tempted
to move. Punctuation is **kept**, so a span that inserts a comma is not verbatim,
and `test_a_span_with_an_inserted_comma_is_not_verbatim` is the only thing
standing between this check and the grounding gate drifting apart on what "the
same text" means. Under the punctuation-erasing mutation, 12 of the 13 cases
still pass.

What this does **not** establish is that stage B copies rather than paraphrases.
The check is verified against synthetic spans; how often a real model returns a
non-verbatim span is a measurement that needs the full run (§7.3), and 8/8 on the
probe set remains one small sample.

### 5.6 Observed span-shrink ratios

The raw material for the `sufficient_verbose` threshold (§7.3). From the 8-case
probe:

| Case | span / quote | ratio |
|---|---|---|
| `gdpr_art8_case1` | 34 / 181 | 19% |
| `gdpr_art33_case1` | 96 / 297 | 32% |
| `gdpr_art41_case3` | 101 / 213 | 47% |
| `gdpr_art2_case4` | 245 / 245 | 100% |
| four further cases | — | no shrink |

They spread widely enough that a threshold will be **measurable rather than
arbitrary**.

---

## 6. Stage C — adjudicate (built 2026-08-17)

`sufficiency/stage_c.py` — `adjudicate`, with `STAGE_C_INSTRUCTIONS`,
`_StageCClaimVerdict` / `_StageCAdjudication`, `build_stage_c_prompt`,
`render_claims` and `AdjudicationError` beside it.

Inputs: the question, stage A's core claims, stage B's blind answer. **Not the
quote** — stage C must not be able to re-read the evidence and substitute its own
judgement for stage B's, because that would collapse the blinding that makes B
worth running. The signature takes a `question: str` rather than a `TestCase`,
deliberately unlike stages A and B: the quote is not a parameter of this stage at
any point, which is stronger than being handed the case and declining to
interpolate it.

**Stage C produces no verdict.** It labels claims and stops; §7's derivation is
deterministic, needs no model call, and is a separate piece.

Per **core** claim, one of:

| Support | Meaning | Repair it implies |
|---|---|---|
| `supported` | the blind answer carries the claim's content | none |
| `absent` | the blind answer does not carry it | the span was cut too short — extend it |
| `contradicted` | the blind answer asserts something incompatible | the quote points the wrong way; **re-read the case**, do not extend |

`absent` and `contradicted` are kept apart precisely because they call for
different repairs. Folding them together would make the output less actionable
than the two-line distinction costs.

Each `ClaimVerdict` carries a `rationale`, for the same reason `Claim.reason`
does.

### 6.1 Core claims only — decided on evidence, not on cost

**Decided 2026-08-17 (Bertan): core claims only.** The caller filters, so this
stage is never told a claim's tag, and `render_claims` renders no tags — every
claim it sees is core, so a tag could only invite treating one as lower-stakes.

The alternative — adjudicate everything and let §7 ignore the surplus — was
rejected on measurement. Stage B is instructed to answer *"as fully as that text
allows, and no further"*, so its answer is scoped to the question; an auxiliary
claim is by definition not what the question asked, and comes back `absent` almost
by construction. On `art8_case1` stage B answered *"16 years old"*, against which
both auxiliary claims are trivially absent. That measures how far the gold answer
runs past the **question** — which stage A already recorded when it tagged them —
not how far it runs past its **evidence**, which is the quantity worth having and
which no stage blind to the quote can produce.

Two further choices in the prompt:

- **The `answer` alone, not the `note`.** The note is stage B's self-assessment,
  and adjudicating against it would judge what stage B *thought* rather than what
  it *answered*. The cost is recorded rather than hidden: on `art8_case1` the
  answer is *"16 years old"* while the note adds *"for their own consent to be
  lawful"*, so a fully-phrased core claim can read `absent` off stage B's brevity.
  If that shows at scale the fix belongs in stage B's step 2 wording, not in
  feeding this stage a second artifact.
- **The regulation is never named**, as in §5.2. This stage judges text against
  text and needs no legal knowledge, so naming the law could only invite it to
  supply what the answer does not say. The prompt states outright that a
  true-but-unstated claim is `absent`, and that supplying it is the failure being
  detected.

### 6.2 Claims are numbered, and the mapping is validated

Pairing verdicts to claims by position looks simpler and is unsafe: a model
returning two verdicts for three claims silently mislabels the third rather than
failing. Claims are numbered from 1 by `render_claims`, the response carries
`claim_number`, and `AdjudicationError` separates the three ways it can fail to
line up — a number outside the range means an invented claim, a repeat means one
labelled twice, a gap means one dropped. An eval instrument should fail loudly
rather than return a plausible wrong answer.

### 6.3 Two inputs take no model call, and neither is an error

- **No claims.** Stage A legitimately returns an empty `core_claims` (§4.5). There
  is nothing to adjudicate, and spending a call to be told so would spend it 433
  times.
- **No answer text.** An empty answer carries nothing, so every claim is `absent`
  by arithmetic rather than judgement, and asking a model to confirm it would
  invite it to fill the silence from what it knows.

The guard is on `answer.strip()` and **not on `answered`**: a model that takes the
insufficiency escape while still writing an answer has produced something
judgeable, and short-circuiting on the flag would discard it unread. That is not
hypothetical — it is what stage B did on `gdpr_art2_case4` in the first real run
(§6.4).

### 6.4 First real run, eight cases

Stage C ran the §11 probe set on 2026-08-17. Three results are worth keeping:

- **`art2_case4` behaved as designed.** Stage B returned `answered=False` and an
  answer explaining that the excerpt does not settle the question; stage C, blind
  to the quote, labelled the core claim `absent` — *"The ANSWER states it does not
  specify whether GDPR applies."* Both of §7.2's routes to `insufficient` agree.
- **`art15_case1` produced repairs, not just a verdict.** Ten core claims, 8
  `supported`, 2 `absent`, and both absences are real defects in the case:
  *"confirmation of processing"* is asserted by the gold answer and absent from the
  quote, and *"restriction/objection"* is cut off by the quote's own `...`. That is
  §10.2's elision problem surfacing as a sufficiency finding.
- **`art8_case5` returned `contradicted`, and it is probably a false positive.**
  The claim *"it specifically applies to information society services offered
  directly to a child"* is compatible with the answer's *"does not apply to
  preventive or counselling services offered directly to a child"* — a rule with an
  exception. Stage C read the shared phrase as incompatible. `contradicted` is the
  most expensive label to get wrong, since §7.1 has it implicate the gold answer
  and not only the quote, and this case's quote is two fragments joined by `...`
  whose second half matches no article (§10.1). **Unresolved.**

---

## 7. Verdict derivation (specified, not built)

The `Verdict` literal exists in `sufficiency/models.py`; nothing derives one.

### 7.1 The vocabulary

| Verdict | Meaning |
|---|---|
| `sufficient` | the quote answers the question |
| `sufficient_verbose` | it answers, but the minimal span is far shorter than the quote — the *devalued* side of §2.3 |
| `insufficient` | the quote cannot answer the question |
| `contradicted` | the blind answer contradicts a core claim |

`contradicted` is deliberately **not** folded into `insufficient`. Evidence
pointing *away* from the answer is a worse defect than evidence merely missing,
and it implicates the **answer** as well as the quote — the `gdpr_art2_case4`
shape.

### 7.2 Proposed derivation

In precedence order:

1. Any core claim `contradicted` → **`contradicted`**.
2. Stage B returned `answered=False`, or any core claim `absent` → **`insufficient`**.
3. Every core claim `supported`, and `len(minimal_span) / len(quote)` below the
   threshold → **`sufficient_verbose`**.
4. Otherwise → **`sufficient`**.

Rule 2 deliberately gives two independent routes to `insufficient`. They can
disagree — stage B may answer while stage C finds a core claim absent, which is
the interesting case: it means the quote answers the question as *asked* but not
as the gold answer *framed* it. Both routes should be recorded distinctly in the
run output even though they produce one verdict, or the disagreement is lost.

An empty `core_claims` (§4.5) must **not** fall through to `sufficient`. It is a
case defect and needs its own outcome — see §10.7.

### 7.3 The `sufficient_verbose` threshold — measure it, do not guess

There is no defensible value to pick a priori. The procedure:

1. Run stages A and B over all 433 cases.
2. Plot the distribution of `len(minimal_span) / len(supporting_quote)`.
3. Choose the threshold from the distribution's shape, and **record the reasoning
   with the number** — the same discipline that set the `normalize_for_grounding`
   boundary by measuring what it cleared and what it left flagged.

The 8-case probe (§5.6) shows the range is wide, so the distribution should have
shape to read.

---

## 8. Panel and aggregation (specified, not built)

Plan §6.2 requires, for high-stakes gates, a small multi-judge panel with
majority/consensus rather than a single call. `CaseJudgement` and its `unanimous`
property exist for this; nothing populates them.

### 8.1 How the golden set was actually generated

§6.2 requires preferring a judge from a different family than the generator where
feasible, so this has to be established before a panel can be chosen.

The set was produced in **two stages by seven models**:

| Role | Models | In version control? |
|---|---|---|
| **Proposers** — many candidate QA pairs per article, independently | Minimax M-2.7, GLM 5, Kimi K-2.5, Qwen 3.5, Minimax M-2.5, DeepSeek V-3.2 | **Yes** — `2638b52:src/config.py`, all six on `LlmServers.OLLAMA` (Ollama Cloud) |
| **Chief judge** — integrated the suggestions into the final set | **Opus 4.5**, used interactively | **No** — see below |

The proposal stage is reproducible from the repository.
`2638b52:src/scripts/gdpr_test_data_generation.py:130` fans the same
`TIER_ONE_INSTRUCTIONS` out to all six models concurrently, concatenates their
responses under the header *"Please analyze and merge the following in order to
obtain full coverage. Generate new samples for full coverage, if necessary:"*,
and writes the result to `article_NN.txt`.

**The script stops there.** It produces the merge *prompt*, not the merged set —
it never invokes `writer_model` (Nemotron-3-Super and GPT-OSS-120B at that
commit) and never writes JSON. The integration step, where Opus 4.5 turned those
concatenated proposals into `article_NN_test_cases.json`, ran outside this
codebase. Consistent with that, Opus 4.5 does not appear in `ai_common`'s
`ModelNames` at all.

So the set is a **consensus artifact of six proposing models across five
families, arbitrated by a seventh from a sixth family** — not one model's output.
That changes how self-preference should be reasoned about: the risk is not that a
judge shares idiosyncrasies with a single author, but that it shares them with
whichever stage of a seven-model pipeline it overlaps.

> **Why reading git naively gets this wrong.** `get_llm_config()["orchestrator_model"]`
> holds a single DeepSeek V4 Flash entry today, *and* at `59f7c03` (2026-07-23),
> the commit that first added `data/tier-1/`. But the config had been rewritten to
> OpenRouter the day before, at `6ccd193` (2026-07-22, *"Switch LLM config to
> OpenRouter and scaffold structured output"*), while the data itself was generated
> months earlier under the 2026-03-20 config. Inspecting the config as of the data
> commit therefore describes a configuration the data was never produced by. This
> was in fact got wrong twice while writing this document.

### 8.2 What this means for panel composition

**`LlmServers.OLLAMA` here is Ollama's *cloud* service, not a local install.**
That matters: every model carrying an `OLLAMA` alias is reachable, so the judge
pool is not limited to what OpenRouter serves. The full pool, enumerated from
`ai_common.llm.MODEL_NAME_ALIAS_DICT` at `HEAD`:

| Model | Role in generation | Reachable via |
|---|---|---|
| Minimax M-2.7 | **proposer** | `OLLAMA` |
| Minimax M-2.5 | **proposer** | `OLLAMA` |
| GLM 5 | **proposer** | `OLLAMA` |
| Kimi K-2.5 | **proposer** | `OLLAMA` |
| Qwen 3.5 | **proposer** | `OLLAMA` |
| DeepSeek V-3.2 | **proposer** | `OLLAMA`, `OPENROUTER` |
| DeepSeek V4 Flash | none | `OPENROUTER` |
| Gemini 3.1 Flash-Lite | none | `GOOGLE`, `OPENROUTER` |
| Nemotron-3-Super | none | `OLLAMA` |
| GPT-OSS-120B / 20B | none | `GROQ`, `OLLAMA` |
| Kimi K2-0905 | none (older sibling of a proposer) | `GROQ`, `OLLAMA` |

Opus 4.5 — the chief judge, and the model that made every final call on the set —
**is not in `ai_common`'s `ModelNames` at all**, so it can be neither used nor
deliberately avoided through this configuration.

Four consequences:

1. **The current judge is cleaner than it first appeared, but not clean.**
   `sufficiency/judge.py` runs on DeepSeek V4 Flash — a *different family from
   the chief judge* that arbitrated the set, which is the comparison that matters
   most, but the *same family as proposer DeepSeek V-3.2*.
2. **Six models were involved in generation; five families were not.** A judge is
   "clean" on §6.2 grounds if it shares a family with neither a proposer nor the
   chief judge. Gemini 3.1 Flash-Lite, Nemotron-3-Super and the GPT-OSS pair all
   qualify. DeepSeek V-3.2 is the **worst** available choice, being a proposer
   itself.
3. **Panel diversity is not the binding constraint.** A three-model panel of
   Gemini 3.1 Flash-Lite (Google), Nemotron-3-Super (NVIDIA) and GPT-OSS-120B
   (OpenAI open-weights) spans three families with no proposer overlap at all,
   using two providers already configured. An earlier draft of this document
   claimed diversity was bounded at two families; that was wrong, and followed
   from assuming OpenRouter was the only route.
4. **There is no second judge slot configured.** `writer_model` held a second
   entry — GPT-OSS-120B on `OPENROUTER` — which raised
   `KeyError: <LlmServers.OPENROUTER>` on construction; it was **removed on
   2026-08-10**. `get_llm_config()` now has one entry per role, so a panel needs
   slots added before it needs models chosen.

   The diagnosis is worth carrying forward, because the backlog recorded it
   wrongly: the model was never unavailable. GPT-OSS-120B has `GROQ` and `OLLAMA`
   aliases and ran fine on `OLLAMA` at `2638b52`; the wholesale switch to
   OpenRouter at `6ccd193` moved it to a provider it has no alias for. **Check the
   alias dict for the provider, not just the model.**

> **On the role names.** `orchestrator_model` and `writer_model` are provisional
> and do not presently mean much (Bertan, 2026-08-10) — the judge simply reads
> `writer_model[0]`. Nothing in this document should be read as depending on those
> names, and they are expected to be reorganised as the project's roles firm up.

### 8.3 Aggregation

Majority vote over panelist verdicts. `CaseJudgement.unanimous` is retained
because **non-unanimity is itself the signal** — a case where the panel splits is
a case for the human calibration sample, not a case to resolve by tie-break.
Panel disagreement rate should be reported alongside judge–human agreement.

### 8.4 If the golden set is regenerated

Bertan's stated preference, 2026-08-10: a regeneration would run **over
OpenRouter**, with **newer models** as both the proposing panel and the chief
judge. Four things follow, and the first is the one most easily missed.

1. **§8.2 does not survive a regeneration.** Every conclusion there is a fact
   about *this* set — which models proposed it, which arbitrated it, and therefore
   which judges are clean. A new panel makes a new answer, and the judge must be
   re-chosen against the new list rather than inherited. This section should be
   re-derived, not carried forward.
2. **It is the natural moment to close §10.9.** The integration stage is
   unreproducible because it ran interactively. A regeneration that scripts the
   merge, commits the per-article proposals, and records a manifest of proposer
   IDs, chief-judge ID, prompts and settings would satisfy plan §6.3 for the
   ground truth itself — which currently only the eval *runs* satisfy.
3. **Every number measured against the current set is invalidated.** The 175/433
   poor-coverage measurement (§2.2), the 169-case repair set (§2.4), the grounding
   tiers (§10.4), the composition figures (§10.5), and any sufficiency verdicts
   produced before the change. Plan §7.4 already requires this: the set is
   versioned, and scores are never compared across versions without a re-baseline.
   A regeneration is a version bump, not an edit.
4. **The proposer pool changes shape.** The five Ollama-only proposers — Minimax
   M-2.7 and M-2.5, GLM 5, Kimi K-2.5, Qwen 3.5 — have no OpenRouter alias in
   `ai_common` today, so an OpenRouter-only regeneration cannot reuse them.
   Whether that matters depends entirely on what newer models are reachable there
   at the time, so it is a check to run then rather than a constraint to plan
   around now.

Note that a regeneration and this judge are **not alternatives**. Sufficiency is
a property of the quote-question pairing, and a newer, better panel produces a
better set without making it self-verifying. The judge is what says whether the
new set is any good — so it should exist, and be calibrated, before a regeneration
is measured against the old one.

---

## 9. Calibration (specified, not started)

### 9.1 It is mandatory, and it is a gate on the judge

Plan §6.2 and §7.3: before a judge is trusted, its verdicts are correlated
against a human-labelled sample, and **judge–human agreement is reported**. A
judge below the agreement bar is not used as a gate. Until this exists, **no
verdict from this module gates anything** — which is stated in the module
docstring so a result is never read as coverage it does not have.

### 9.2 The open sequencing decision

Two orders, and it is undecided which:

| Option | Argument for | Argument against |
|---|---|---|
| **Label a stratified sample first**, then run | The judge is never applied at scale before its agreement is known; no wasted spend if it is poor | Stratifying without run output means stratifying on deterministic features only |
| **Run all 433 first**, then sample | Sample can be stratified on *verdict* — including the rare `contradicted` and the panel-split cases, which are the informative ones | Spends the full run before knowing the judge is trustworthy |

The second buys a better sample because the interesting strata are only visible
after a run. The first is what §6.2 reads most naturally as requiring. The cost
difference is small enough (§9.4) that this should be decided on sample quality,
not budget.

### 9.3 The key-phrase screen's surviving role

Rejected as a gate (§2.4), it remains useful as **triage** — a cheap prior on
which cases are likely insufficient — and as a **calibration stratifier**. The
264 / 35 / 110 / 24 split gives four natural strata for a labelled sample.

### 9.4 Cost

433 cases × 3 stages = 1,299 calls per panelist, plus one more multiple per
additional panel member. Against DeepSeek V4 Flash on OpenRouter this is small —
the deterministic gate by comparison costs nothing, and the whole re-index costs
about $0.001. Cost is not the constraint on this design; trust is.

---

## 10. Known gaps

Each is a scope limit stated so a green result is not read as coverage it does
not have. `todo.md` entries are named where they exist.

### 10.1 Stage B cannot distinguish "this quote fails" from "nothing could"

It is blind to the article by design, so it can report that *this quote* does not
answer the question but never that *nothing in the article would*. Getting an
`UNANSWERABLE` verdict would mean either showing some stage the article — which
costs the blinding — or treating the result as a triage hint against the source
PDF. Whether that verdict belongs in this pass at all is **undecided**
(`todo.md`, golden-set remediation).

This is not theoretical. `gdpr_art41_case3` and `gdpr_art8_case5` were listed in
the backlog as *"invalid case, not a quote defect"*. **Stage B answered both
cleanly from their quotes**, so the questions are sound and the defect is
provenance, not answerability — the backlog label was wrong and was corrected on
2026-08-05. `gdpr_art41_case3`'s quote matches **no article in the corpus** and
reads like Article 43's certification rule, so it is likely a mis-pointed
`article_number`. `gdpr_art8_case5`'s quote is two fragments joined by `...`; the
first is in Article 8, the second matches no article.

### 10.2 Some cases cannot be satisfied by any contiguous span

`gdpr_art2_case4`'s quote *is* ¶2(d); the stem carrying the negation is ¶2,
separated from it by (a), (b) and (c). **No contiguous substring of the corpus can
satisfy the sufficiency criterion for that case.** It is not a badly-chosen quote.

The fix is a schema change — `supporting_quote` becoming a list of spans, each an
exact substring, in document order — which is the same decision as the
enumeration-chunking rework. **39 of the 433 quotes currently contain a literal
`...`** (measured at `HEAD`), and the explicit markers become list boundaries.
Until then, such cases will read as `insufficient` and the verdict will be
correct about the quote while wrong about the case. (`todo.md`: elision / span
lists.)

### 10.3 Judge–human agreement is unmeasured

§9. No verdict gates anything until it exists.

### 10.4 The set this judges is itself failing its deterministic gate

Measured at `HEAD`:

```
cases checked : 433
clean cases   : 319
errors        : 114
warnings      : 34
gate          : FAIL

285  exact       (byte-identical substring)
 34  normalized  (matches once rendering differences are removed)
114  ungrounded  (not in the article — a real defect)
```

114 cases carry a quote that is not in its article. Stage B will judge those
quotes on their own terms — a quote can answer its question perfectly while
coming from nowhere in the corpus, which is exactly `gdpr_art41_case3`. **A
`sufficient` verdict is therefore not evidence the case is sound**, and
sufficiency results must be read alongside grounding tier, never instead of it.

### 10.5 Set composition limits what the verdicts generalise to

Measured at `HEAD` over all 433 cases:

| Property | Value |
|---|---|
| `answer_type` | definition 133, conditional 133, scope 131, **timeline 36** |
| quote length (chars) | min 31, median 237, max 1430 |
| answer length (chars) | min 116, median 284, max 731 |

`timeline` is a quarter the size of the other slices, and it is the classic
failure mode for numeric deadlines. Per-`answer_type` sufficiency rates will have
correspondingly weaker resolution there.

### 10.6 The judge's *behaviour* is unverified; its wiring no longer is

**Closed in part.** `span_is_verbatim` and the deterministic surface of stages A
and B are tested and mutation-verified (§1.1, §5.5) — 8/8 verbatim on the probe
set was not evidence anything worked, and is no longer what the claim rests on.

What remains open is the half unit tests cannot reach: whether stage A's
core/auxiliary tagging matches a human's, and whether stage B resists parametric
leakage at a rate rather than in one observed case. That is §9's calibration, and
it is the reason no verdict here gates anything.

The 20 mutations behind §1.1 were hand-run, which `todo.md` carries a broader
entry against: 35 hand-run mutations on 2026-08-07 left **four survivors**, and
not one meant "add a missing test" — every one was a test that already existed
and did not work. A hand procedure that has to be remembered is the gap, not the
mutations themselves.

### 10.7 Undecided, and each changes the output

- ~~Whether stage C adjudicates auxiliary claims at all~~ — **decided 2026-08-17:
  core only, on the evidence in §6.1.**
- Whether stage A needs the atomicity rule that would stop sentence-fragment
  claims, and whether the prompt work so far generalises beyond the six cases it
  was tuned on (§4.6). Both are open and both are measurable.
- What verdict an empty `core_claims` produces (§4.5, §7.2) — it is a case defect
  and does not fit the four-verdict vocabulary.
- Calibration sequencing (§9.2).
- Panel composition, blocked on the broken `writer_model[1]` (§8.2).
- Whether `UNANSWERABLE` belongs in this pass (§10.1).
- The `sufficient_verbose` threshold (§7.3) — to be measured, not chosen.

### 10.8 What this judge does not reach

Two defect classes named in plan §7.3's known limits are **outside** this
mechanism, and a clean sufficiency result says nothing about either:

- **Non-deictic context dependence** — *"Are there any exemptions?"* names
  nothing and points nowhere. No lexical rule reaches it, and neither does a
  quote-vs-question check.
- **Parametric answerability** — a question answerable from general knowledge
  without retrieving anything (`gdpr_art94_case3`). Detectable via the paired
  end-to-end / gold-context probes of plan §2, not here.

---

### 10.9 The golden set's integration stage is not reproducible

The **proposal** stage is fully in version control — six models, their provider,
the prompt, and the fan-out code, all at `2638b52` (§8.1). The **integration**
stage is not, in three ways:

- **The chief judge is not in the config, and was never meant to be.**
  `writer_model` at that commit is Nemotron-3-Super and GPT-OSS-120B; the actual
  arbiter was Opus 4.5, used **interactively** rather than through the codebase.
  It is not in `ai_common`'s `ModelNames` and appears nowhere in the repository.
- **The merge was never coded, and could not have been captured by code as run.**
  `gdpr_test_data_generation.py` writes `article_NN.txt` — the concatenated
  proposals under a merge instruction — and ends. The step that turned those into
  `article_NN_test_cases.json` was an interactive session, so there is no script,
  no parameters, and no transcript to record. This makes the integration stage
  unreproducible **in principle**, not merely unrecorded: even with the same model
  and the same inputs, an interactive session is not a rerunnable artifact.
- **The intermediates were never committed.** No `article_NN.txt` has ever been
  tracked (checked with `git log --all --diff-filter=A`), so the proposals the
  chief judge worked from are gone. The proposal stage can be *re-run*, but its
  original output cannot be recovered, and six non-deterministic models will not
  reproduce it.

Plan §6.3 requires model IDs recorded for every eval run. The ground truth those
runs are scored against has a half-record: enough to say who proposed, not enough
to say how the set was decided.

Consequences for this module are bounded but real. Self-preference reasoning
(§8.2) rests partly on a fact held outside version control — the identity of the
chief judge — and if the set is ever extended, the new cases will be arbitrated by
a process that cannot be matched to the existing ones.

## 11. Reproducing

```bash
python -m src.eval.golden_qa          # the deterministic gate — free, no model calls
python -m src.eval.sufficiency.judge  # the 8-case probe harness — all three stages

# The stage A/B tests — no model calls, 0.32s
uv run --group test pytest tests/test_sufficiency_stages.py
```

The probe harness runs against `get_llm_config()["writer_model"][0]` and prints
stage A and stage B output for eight cases chosen to cover the criterion's edges:
`gdpr_art7_case3` (the case the criterion was settled on), `gdpr_art2_case4`
(grounds exact, quote carries no negation), `gdpr_art33_case1` (core timing rule
plus auxiliary consequence), `gdpr_art15_case1` (enumeration — every item core),
`gdpr_art8_case1` (key-phrase screen flags it; the quote answers it),
`gdpr_art41_case3` and `gdpr_art8_case5` (the re-classified provenance cases), and
`gdpr_art7_case4` (carries `art7_case3`'s auxiliary clause as its own quote).

---

**Verified against `60ab36d`.** Counts in §10.4 and §10.5 were measured at that
commit; the 8-case probe figures in §4.2, §5.3 and §5.6 are from the 2026-08-05
run recorded in `docs/dev-log/devlog_2026-08-05_session-1.md` and have not been
re-run since.

**§1.1 and §5.5 verified on 2026-08-17**, session 1, against `b99783b` plus the
then-uncommitted `tests/test_sufficiency_stages.py` and the `sufficiency/llm.py`
deferral — 31 tests, 20 mutations with no survivors, and the import figures
measured on this machine rather than carried over.

**§4.6, §6 and §1.1's stage C rows verified on 2026-08-17**, session 2, against
`c96c210` plus this session's work — 49 tests, 36 mutations with no survivors, one
full 8-case probe run per prompt revision, and 45 stage A calls across six cases
for the stability table. Every figure in §4.6 was measured, not estimated, and the
two caveats stated there — six tuning cases, one ruled expectation — bound what
those figures are worth.
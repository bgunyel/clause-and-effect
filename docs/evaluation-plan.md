# Clause & Effect — Evaluation Plan

> **Status:** Planning document. No implementation, scoring code, or judge prompts are defined here — this document defines *what* we measure, *why*, and *how the pieces fit together*. Prompt design and implementation follow in later work.

---

## 1. Purpose & Guiding Principles

This project's governing rule is: **every architecture decision gets measured before it gets kept.** The evaluation framework is the durable asset; the pipeline behind it is disposable. This document is the blueprint for that framework.

Four principles shape every choice below:

1. **Separate the stages.** Retrieval and generation fail for different reasons and are fixed by different changes. The eval must attribute a bad end-to-end answer to a *specific* stage, or it cannot guide improvement.
2. **Cheap first, expensive second.** Deterministic checks (lexical, exact-match) run on every change; LLM-judge checks (which cost money and have variance) run at milestone gates. A metric nobody can afford to run is not a metric.
3. **The eval set is itself under test.** Our golden data is LLM-generated. An unvalidated golden set silently launders model bias into "ground truth." The golden set has its own quality bar (§7).
4. **Groundedness over fluency.** This is a compliance tool. A confident, well-written, *wrong or uncited* legal claim is the worst possible output. Metrics are weighted accordingly.

---

## 2. System Under Evaluation

The current pipeline (`ComplianceAgent.ask`) is a linear RAG flow:

```
question
   │
   ▼
[ VectorDatabase.search(query, top_k) ]      ← Retrieval stage
   │   returns scored chunks (text + score + metadata)
   ▼
[ Generator.generate(question, scored_points) ]   ← Generation stage
   │   returns GeneratedAnswer { answer_text, citations[] }
   ▼
answer + citations + operational metadata (retrieval_time, scores, token cost)
```

Evaluation therefore has three natural probe points:

| Probe point | What we can observe | Stage evaluated |
|---|---|---|
| After `search()` | Retrieved chunk set + scores | **Retrieval** |
| After `generate()` given *retrieved* context | Answer produced by the real pipeline | **End-to-end generation** |
| After `generate()` given *gold* context | Answer quality with retrieval held perfect | **Generation in isolation** |

The third probe (feeding the generator the known-correct chunk instead of the retrieved one) is what lets us decouple "the retriever missed" from "the generator mishandled good context." Both probes are required.

---

## 3. Evaluation Layers & Dimensions

We evaluate three layers. Each dimension below lists **what it measures**, **the signal source in our data**, and **the scoring method class** (deterministic vs. LLM-judge — defined in §6).

### 3.1 Retrieval Layer

We have a strong advantage here: every Tier-1 test case carries a `supporting_quote` (exact substring of the source article) and a known gold `article_number`. That gives us free, objective retrieval ground truth.

| Dimension | Measures | Signal source | Method |
|---|---|---|---|
| **Context Recall (Hit@k)** | Did the retrieved top-k contain the gold chunk? | Match `supporting_quote` / gold `article_number` against retrieved chunks | Deterministic |
| **Context Precision** | Of the retrieved chunks, how many are relevant (vs. noise/dilution)? | Gold article vs. retrieved articles | Deterministic |
| **Rank Quality (MRR / nDCG)** | *Where* in the list did the gold chunk land? | Rank of first gold-matching chunk | Deterministic |
| **Score Separation** | Do similarity scores discriminate relevant from irrelevant? (calibration for a future confidence threshold) | `retrieval_scores` distribution, gold vs. non-gold | Deterministic |

**Primary retrieval metric: Context Recall.** If the answer-bearing chunk is not retrieved, no downstream quality can recover it. Precision and rank are diagnostic secondaries that explain *why* recall or groundedness dips.

**Sweep parameter:** all retrieval metrics are reported as a function of `top_k` (e.g., k ∈ {1, 3, 5, 10}) so we can choose k on evidence, not by default.

### 3.2 Generation Layer

Measured at **both** the end-to-end probe and the gold-context probe (§2), so we can tell whether a generation failure is the retriever's fault or the generator's.

| Dimension | Measures | Signal source | Method |
|---|---|---|---|
| **Groundedness / Faithfulness** | Is every claim in the answer supported by the provided context? No fabrication. | Answer vs. retrieved context | LLM-judge (primary) |
| **Citation Correctness** | Do the cited articles actually contain the claims, and are they the right articles? | `citations[]` vs. gold `article_number` + context | Deterministic (article match) + LLM-judge (claim support) |
| **Citation Completeness** | Does every claim that needs a citation have one? | Answer structure vs. citations | LLM-judge |
| **Answer Correctness** | Is the answer factually right vs. the reference answer? | Answer vs. gold `answer` | LLM-judge (reference-guided) |
| **Key-Phrase Coverage** | Cheap proxy for correctness: are the expected substantive phrases present? | Answer vs. `key_phrases[]` | Deterministic |
| **Answer Relevance / Focus** | Does it answer the question asked, without over-answering or drifting? | Answer vs. `question` | LLM-judge |
| **Abstention Correctness** | When context is insufficient, does it correctly refuse instead of hallucinating? | Negative/out-of-scope cases (§7.2) | Deterministic (refusal detected) + LLM-judge |

**Primary generation metrics: Groundedness and Citation Correctness.** These two encode the product's core promise. Answer Correctness and Relevance are important but secondary; Key-Phrase Coverage is a cheap early-warning signal, *not* a substitute for the judge.

**Note on `answer_type`.** Every test case is tagged `timeline | definition | conditional | scope`. All generation metrics are sliced by `answer_type` — a system can be strong on definitions and weak on timelines (numeric deadlines are a classic failure mode), and an aggregate score would hide that.

### 3.3 End-to-End / Operational Layer

| Dimension | Measures | Signal source | Method |
|---|---|---|---|
| **Composite Answer Quality** | Weighted roll-up of the generation metrics into one release-gate number | Weighted combination (§8) | Derived |
| **Latency** | Retrieval + generation wall-clock | `retrieval_time` + generation timing | Deterministic |
| **Cost per query** | Token/$ cost | `calculate_token_cost` (already in `ai_common`) | Deterministic |
| **Robustness / Consistency** | Does the answer stay stable under paraphrase of the question? | Paraphrase variants of golden questions | LLM-judge |

Latency and cost are **not** quality gates but **budget guardrails** — tracked so that a quality gain bought with a 5× cost increase is a visible, deliberate trade, not a silent one.

---

## 4. What We Deliberately Do *Not* Measure (yet)

Stating exclusions keeps the eval focused and honest:

- **Standalone "helpfulness"** — too fuzzy; it decomposes into relevance + completeness + groundedness, which we already measure. No separate score.
- **Fluency / grammaticality** — modern LLMs rarely fail here; low signal, not worth judge budget.
- **Toxicity / safety** — near-zero risk in this domain. A cheap guardrail, revisited only if the corpus or audience changes.
- **Human preference / A-B UX** — out of scope until there is a UI and real users.

Each exclusion is a decision to revisit, not a permanent one.

---

## 5. Metric Taxonomy Summary

```
                        ┌─────────────────────────────────────────┐
                        │            EVALUATION LAYERS             │
                        └─────────────────────────────────────────┘

   RETRIEVAL                    GENERATION                     OPERATIONAL
   (deterministic,              (judge-heavy,                  (deterministic,
    objective ground truth)      reference-guided)              guardrails)
   ───────────                  ──────────                     ───────────
 • Context Recall  ★          • Groundedness       ★         • Composite Quality
 • Context Precision          • Citation Correctness ★        • Latency
 • Rank (MRR/nDCG)            • Citation Completeness         • Cost / query
 • Score Separation           • Answer Correctness            • Robustness
                              • Key-Phrase Coverage
                              • Answer Relevance / Focus
                              • Abstention Correctness

   ★ = primary gate metric      (all generation metrics sliced by answer_type)
```

---

## 6. Scoring Methodology

Two classes of scorer, chosen per dimension by cost and objectivity.

### 6.1 Deterministic scorers
Fast, free, zero-variance, run on **every change**. Cover: all retrieval metrics, key-phrase coverage, citation *article-match*, refusal detection, latency, cost. These form a **cheap regression tripwire** — if they move, something changed.

### 6.2 LLM-as-judge scorers
For the semantic dimensions (groundedness, correctness, relevance, claim-level citation support) that no lexical rule captures. Run at **milestone gates**, not every commit, because they cost money and carry variance. Design principles (prompts themselves are deferred to a later document):

- **Reference-guided.** The judge sees the gold `answer` and `supporting_quote`, not just the question. Judging against a reference is far more reliable than open-ended quality rating.
- **Same constraint as the system.** The judge is bound by "score only against the provided source text" — otherwise it rewards plausible claims drawn from its own parametric knowledge, which is exactly the hallucination we are hunting.
- **Structured, decomposed verdicts.** Per-claim support decisions and a short rationale, not a bare 1–5. Decomposition improves reliability and gives us a debuggable trail.
- **Bias controls.** Mitigate known LLM-judge biases: position bias (randomize order in any pairwise comparison), verbosity bias (length must not buy score), self-preference (prefer a judge model from a different family than the generator where feasible).
- **Calibration is mandatory.** Before a judge is trusted, its scores are correlated against a human-labeled sample (§7.3). We report judge–human agreement; a judge below the agreement bar is not used as a gate.
- **Panel for high-stakes.** For the primary gate metrics (groundedness, citation correctness), consider a small multi-judge panel with majority/consensus rather than a single call, to cut variance.

### 6.3 Determinism & reproducibility
Generation runs at `temperature = 0.0` (already set) for repeatability. Every eval run records: pipeline git SHA, eval-set version, model IDs (generator, embedder, judge), `top_k`, and timestamp — so any number in a report can be reproduced and any regression bisected.

---

## 7. Evaluation Datasets

### 7.1 Tier structure (aligned to README roadmap)

| Tier | Question style | Tests primarily | Status |
|---|---|---|---|
| **Tier 1 — Factual** | Single-article factual Q&A (`answer_type`: timeline/definition/conditional/scope) | Retrieval recall + grounded single-hop generation | ✅ Exists (`data/tier-1/`, 433 cases across all 99 articles) |
| **Tier 2 — Multi-hop** | Answer requires combining ≥2 articles | Multi-chunk retrieval + synthesis without conflation | 📋 Planned |
| **Tier 3 — Realistic/Vague** | Underspecified, practitioner-phrased queries | Query understanding, disambiguation, graceful partial answers | 📋 Planned |

Each tier is a **separate scoreboard**. A system that aces Tier 1 and fails Tier 3 is the *expected* and most interesting result — the README explicitly names that gap as where systems quietly fail. Aggregating tiers into one number would erase the finding.

### 7.2 Required additional slices
The current golden set covers questions the corpus *can* answer. Two slices are missing and must be built:

- **Negative / out-of-scope set.** Questions that GDPR does **not** answer (e.g., CCPA-specific, or nonsense). Correct behavior is *refusal*, per the system prompt's rule #3. Without this slice, Abstention Correctness cannot be measured and hallucination-on-ignorance goes undetected. *(Note: Article 2's "does not apply" cases are still in-scope factual questions — they are answerable from the article and are not a substitute for a true out-of-scope set.)*
- **Paraphrase / robustness set.** Reworded variants of existing golden questions, to measure consistency (§3.3).

### 7.3 Golden-set quality assurance (the eval-of-the-eval)
Tier-1 data is generated by an LLM (`gdpr_test_data_generation.py`). It cannot be trusted as ground truth until validated. The gates below are implemented in `src/eval/golden_qa.py` and run with `python -m src.eval.golden_qa`.

#### Deterministic gates
Free, fully reproducible, no model calls — so they run on every change. Each issue is an **error** (fails the gate) or a **warning** (reported, tolerated).

- **Quote grounding.** Every `supporting_quote` must be a substring of its source article, reported in three tiers: *exact* (byte-identical), *normalized* (identical once rendering differences are removed — a **warning**), and *ungrounded* (an **error** — a broken test case, to fix or remove).

  The middle tier exists because exact-substring is only a **proxy** for what is actually wanted: evidence verifiably drawn from the regulation. Where proxy and purpose disagree, the proxy bends — not the data. Normalization removes a space before punctuation (an OCR artifact), markdown list markers (docling's rendering of an enumeration), whitespace runs, and letter case. It deliberately **keeps punctuation**: in a legal text a comma separates restrictive from non-restrictive clauses, so a quote that inserts one has altered the statute — and two of the three cases this cost turned out to be exactly that. The boundary was set by measurement, not taste: the steps clear 12 of 15 formatting-only failures while leaving 0 of 37 reordered and 0 of 20 fabricated quotes unflagged. That safety property is pinned by a test over the real set, not asserted once.

- **Leakage discipline.** A question must not name **its own** gold article. The discriminator is *self-reference*, not the presence of a citation: naming some other article is an ordinary cross-reference that points a citation-lookup shortcut *away* from the answer, and some questions cannot be asked otherwise — Article 10's relationship to Article 6(1), for instance. The earlier "no article/paragraph numbers" formulation produced false positives on cross-instrument references, the *Article 29 Working Party* being named for a repealed directive rather than for anything in this regulation.

- **Self-containment.** A question must carry its own referents. *"Does this article apply to all personal data held by a public body?"* reveals no location, so nothing can be looked up by citation — but it cannot be read on its own either, and a query that only makes sense beside its answer is not a retrieval query. The check anchors on the **determiner** (`this|these|those|such|said`) and leaves the noun a wildcard, accepting a demonstrative only when its noun already appeared earlier in the same question. Enumerating nouns instead is unwinnable: successive sweeps for "article", then "provision" and "rule", still missed "these derogations".

- **Structural validity.** Non-empty `question`, `answer` and `key_phrases`; a known `answer_type` (§3.2); and an `article_number` that exists in the corpus.

#### Judge and manual gates (P1 — deliberately not implemented here)
Kept out of the deterministic suite so that suite stays free and runnable on every change.

- **Answer-vs-quote entailment.** The `answer` must be supported by its `supporting_quote`. Spot-checked by judge and, for a sample, by a human.
- **Human audit sample.** A fixed random sample per tier, human-reviewed for question realism, answer correctness, and single-article answerability. Doubles as the **judge-calibration set** (§6.2).

#### Known limits
The deterministic gates are floors, not proofs. Each is stated here and in the relevant test docstring, so a green result is never read as coverage it does not have.

- **Non-deictic context dependence.** A question can depend on absent context with no demonstrative at all — *"Are there any exemptions?"* names nothing and points nowhere. No lexical rule reaches it; judge-tier.
- **Parametric answerability.** A question answerable from general knowledge without retrieving anything. Retrieval metrics are unaffected — Hit@k measures whether the gold chunk was retrieved, regardless of whether the model needed it — but end-to-end generation would score well over a broken retriever. Detectable via the paired end-to-end / gold-context probes (§2); currently unmeasured.
- **Elision.** Quotes that are verbatim and in document order but non-contiguous, joining an enumeration stem to a specific item. That is real GDPR structure, not a defect, and no fuzzy matcher should be asked to guess at it. Preferred fix is to make it explicit in the data: let `supporting_quote` hold a **list of spans**, each required to be an exact substring, in document order.

#### How these checks are meant to be built
Three working rules, each learned by getting it wrong first:

- **Checks are regression devices, not discovery devices.** The set is a finite number of fixed strings from one known generator, not adversarial input, so completeness over possible phrasings is the wrong goal — and unreachable anyway. Defects are found by auditing the finite set once; the check then holds the line. Every defect class closed this way gets a whole-set test that fails if it reappears.
- **Enumerate the construction, not the vocabulary.** Closed classes (determiners, auxiliaries) are finite and stable; open classes (nouns) are not. A check anchored on an open class will keep missing cases no matter how long the list grows.
- **Fix the generator, not just the artifact.** Both defect classes closed on 2026-08-03 were systematic producer faults — the generator wrote while looking at the article and assumed its reader would be too. Patching the data alone leaves the generator free to reintroduce them, which is the same failure mode as a fixed parser sitting beside a corrupt corpus.

Check quality is itself verified by **mutation**: reintroduce a known defect and confirm the corresponding test fails. A gate that has never been observed to fail is not known to work.

### 7.4 Versioning
The eval set is versioned and frozen per reporting run. Changes to the set bump its version; scores are never compared across set versions without a re-baseline. The set is an asset with a changelog, not a moving target.

---

## 8. Aggregation, Thresholds & Gates

### 8.1 Composite score
A single release-gate number, computed **per tier**, as a weighted roll-up reflecting the compliance priority order:

```
Groundedness  >  Citation Correctness  >  Answer Correctness  >  Relevance  >  Key-Phrase Coverage
```

Exact weights are a decision to make once baseline numbers exist (weighting before we know the score distribution is guesswork). The composite is a **convenience roll-up, never a replacement** for reading the per-dimension, per-`answer_type` breakdown.

### 8.2 Gate philosophy
- **Hard floors** on the primary metrics (Context Recall, Groundedness, Citation Correctness): a change that drops any floor is a regression, regardless of what it improves elsewhere. Floors are set relative to the published baseline, not to absolute targets pulled from thin air.
- **Tripwires** on the deterministic suite run on every change; judge-based gates run at milestones.
- **No silent trade-offs:** any accepted regression on one axis in exchange for a gain on another is recorded in the devlog with the numbers.

### 8.3 Regression tracking
Every run appends to a results history keyed by pipeline SHA + eval-set version. The unit of progress is a **diff between two runs**, with per-case win/loss lists — not a single headline number. We can always answer "which specific cases did this change break?"

---

## 9. Failure Taxonomy

Every failing case is labeled with a root-cause category, so aggregate scores translate into a prioritized fix list:

| Category | Stage | Symptom | Typical fix direction |
|---|---|---|---|
| **Retrieval miss** | Retrieval | Gold chunk absent from top-k | Chunking, embedding model, k, query rewriting |
| **Retrieval dilution** | Retrieval | Gold chunk present but low-ranked among noise | Reranking, precision tuning |
| **Hallucination** | Generation | Claim unsupported by provided context | Prompt constraints, grounding, model |
| **Citation error** | Generation | Wrong or missing article citation | Citation prompting, structured output |
| **Over-answering / drift** | Generation | Correct but off-question or padded | Relevance prompting, scope control |
| **Under-answering** | Generation | Incomplete; misses part of a multi-part answer | Completeness prompting, context window |
| **Failure to abstain** | Generation | Answers confidently when context is insufficient | Abstention prompting, score thresholding |
| **Golden-set defect** | Data | The "failure" is actually a bad test case | Fix/remove the test case (§7.3) |

The last row matters: some fraction of early "failures" will be eval-set bugs, and the taxonomy forces us to check rather than chase phantom regressions.

---

## 10. Reporting

Each evaluation run produces:

1. **Scorecard** — per tier, per dimension, sliced by `answer_type`, with `top_k` sweep for retrieval. Primary metrics highlighted.
2. **Diff vs. previous baseline** — per-case win/loss, so improvements and regressions are concrete.
3. **Failure gallery** — worst cases per failure category, with the retrieved context and the answer, for qualitative inspection.
4. **Operational summary** — latency and cost distributions.
5. **Run manifest** — all reproducibility metadata from §6.3.

Consistent with the README's "no performance claims before the numbers that back them," reports **publish the failures alongside the wins**, including a plain-language list of what the system currently gets wrong.

---

## 11. Roadmap (maps to README milestones)

| Phase | Deliverable | Dimensions activated |
|---|---|---|
| **P0 — Foundations** | Golden-set QA (§7.3); deterministic retrieval + lexical scorers; run harness & manifest | Context Recall/Precision/Rank, Key-Phrase Coverage, Citation article-match, Latency, Cost |
| **P1 — Baseline published** | Judge scorers calibrated; full Tier-1 scorecard incl. failures | + Groundedness, Citation Correctness, Answer Correctness, Relevance, Abstention |
| **P2 — Negative & robustness** | Out-of-scope + paraphrase slices | + Abstention Correctness, Robustness/Consistency |
| **P3 — Tier 2** | Multi-hop eval set + multi-chunk retrieval metrics | Multi-hop recall, synthesis-without-conflation |
| **P4 — Tier 3** | Realistic/vague query set | Query understanding, graceful partial answers |

P0 and P1 together produce the README's "baseline numbers published, including exactly what the system gets wrong" milestone.

---

## 12. Open Questions

Decisions deferred until baseline data exists (deciding them earlier is guessing):

- Composite-score weights (§8.1) — set after we see the score distribution.
- Judge model choice and panel size (§6.2) — pending calibration results.
- Chunk granularity for retrieval ground-truth matching — article-level vs. sub-article; may need finer `supporting_quote` localization for long articles.
- Absolute floor values for gates (§8.2) — set relative to the first published baseline.
- Whether robustness/paraphrase warrants a judge or a cheaper embedding-similarity consistency check.

---

*This plan defines the measurement framework. Scoring implementations and judge prompts are intentionally out of scope here and will be specified in follow-up documents, each itself validated against the principles above.*
# Devlog — 2026-08-03 · session 1

**Branch:** `dev-02` · `a47555c` → `HEAD` (5 commits this session)
**Theme:** Both question-side defect classes closed — and the discovery that the
gate's real acceptance criterion is not the one it measures
**Tests:** 64 passed / 1 xfailed → **81 passed**, no xfails
**Gate:** leakage 17 → **0**, self-containment (unmeasured, 8 latent) → **0**,
quote grounding unchanged at 134. Clean cases 285 → **299**. Gate still FAIL.

---

## The leakage rule was wrong in a way that had to be fixed before the data could be

`check_leakage` flagged any `article|paragraph|recital|section|point` followed by a
number, regardless of which article the case belonged to. That is a location-reference
detector, not a leakage detector. The previous session had already established the
discriminator is **self-reference** — a question leaks when it names the article its own
answer lives in — but the checker still carried the old rule.

Replacing it was a precondition for the rewrites, not independent cleanup. Two of the 17
questions need to keep a cross-reference: `art10_case2` retains `Article 6(1)`, which its
`key_phrases` require, and `art93_case2` retains `Article 5 of Regulation (EU) No
182/2011`. Under the old rule both would still be flagged after rewriting.

**The rule change moved the count by zero** — all 17 named their own gold article. That
property is the evidence it was a correction rather than a relaxation; the 17 → 0 came
entirely from editing questions. → `061f0f5`, `b3e3fdb`

### The assistant over-built it twice before measuring

The first implementation added a second rule that flagged a bare `paragraph 2` on the
theory that, in a question about Article 13, it can only mean 13(2). Bertan rejected it:
*"We want to target only the articles that reference to themselves."* The second attempt
still carried run-parsing for multi-article lists (`Articles 13 and 14`).

Both were built for cases that do not exist. A sweep of all 433 questions found **23
`article` references and no `paragraph`/`recital`/`section` reference with a number at
all** — the only other keyword hits are "contact point" and "Chapter V", neither followed
by a digit. Bertan asked for the reasoning before accepting either edit, which is what
surfaced this. The shipped matcher is one line, handles `Article 93(2)` correctly, and its
comment records that multi-article runs are deliberately unhandled.

The dropped `paragraph` arm cost no live coverage, and its test was deleted rather than
left asserting a rule that no longer holds.

---

## A second defect class: questions that leak nothing but cannot be read alone

Surveying the rewrites turned up five questions saying *"this article"* with no
antecedent. They leak no location — nothing can be looked up by citation, so
`check_leakage` was right to pass them — but *"Does this article apply to all personal
data held by a public body?"* is not a usable retrieval query.

### The count went 5 → 7 → 8, and that is the finding

The assistant's first sweep grepped `"this article"` and reported 5. A broader sweep over
a list of legal-unit nouns found 7, adding `art48_case3` ("this **rule**") and
`art96_case1` ("this **provision**"). Bertan asked the right question — *"how can we test
all of the endless possibilities?"* — and the answer came out of the failure itself:
**both sweeps enumerated nouns, which is an open class.**

Anchoring on the **determiner** instead, and leaving the noun a wildcard, found the 8th:
`art49_case4`, *"Do these **derogations** apply…"* — a word no list had thought to
include. That is the general rule now recorded in the plan: *enumerate the construction,
not the vocabulary.* Closed classes (determiners, auxiliaries) are finite and stable; the
nouns they attach to are not.

Measured cost of including bare `that`: **29 flags to find 8**, because `that` is
ambiguous with the relative pronoun (*"activities that fall outside the scope of EU
law"*). Separating those is a part-of-speech judgement, not a lexical one, so `that` is
excluded and the comment says why. Two closed-class exemptions hold precision at 9/9 —
`this Regulation` (a term of art) and a demonstrative followed by an auxiliary
(*"can this be extended?"*, a pronoun rather than a determiner). → `061f0f5`, `b3e3fdb`

The gate was added **after** the 8 were rewritten, so it reports 0 on arrival. Rows 0–7 of
the ledger therefore read *unmeasured*, not *clean* — recorded as a footnote in the report
rather than left to imply coverage.

---

## Both regression tests were mutation-checked, not assumed

`test_no_golden_case_names_its_own_article` and
`test_no_golden_case_refers_to_absent_context` run over the real set. Each was verified by
restoring the old wording (`art87_case1`, `art86_case3`), confirming the test failed, and
restoring. A gate that has never been observed to fail is not known to work.

---

## §7.3 specified two of the five gates, and both wrongly

Bertan asked whether the checks in `run_golden_qa` were defined anywhere as principles.
They were not. `docs/evaluation-plan.md` §7.3 is the only spec, and of the five
implemented checks:

- `check_quote_grounding` ← bullet 1, which still said *"exact substring… any miss is a
  broken test case"*. It has reported three tiers since 2026-08-02.
- `check_leakage` ← bullet 4, which still said *"must not name article/paragraph
  numbers"*. Narrowed to self-reference this session.
- `check_self_containment` — absent from the plan entirely; added this session.
- `check_required_fields`, `check_answer_type` — never specified as gates at all.

The module docstring, not the plan, was the specification. §7.3 was rewritten into four
parts: deterministic gates, judge/manual gates (explicitly P1), known limits, and *how
these checks are meant to be built*. §7.1's stale *"~38 articles"* was corrected to 433
cases across all 99. → `b99333c`

**§3.1 remains unreconciled** and matters more: it still does not say that Context
Recall — its primary retrieval metric — is scored by matching `supporting_quote` against
retrieved chunks, so an ungrounded quote registers as a retriever failure whatever the
retriever did.

---

## Context Recall: article-level scoring cannot measure what this project tests

Bertan raised the granularity question and identified the caveat himself — for long
articles, a chunk from the right article may be irrelevant to the question. Measured, the
caveat is the dominant case, not an edge case:

| | |
|---|---|
| cases whose gold article is a single chunk | 125 / 433 (28.9%) — both scorings identical |
| cases in multi-chunk articles | 308 / 433 (71.1%) |
| mean chunks in a case's gold article | **6.5** (median 6, max 28) |

The decisive argument is different from precision, though: **article-level Hit@k is blind
to the variable under test.** Re-chunking changes which chunk is retrieved, rarely which
article, so the metric would sit flat across exactly the experiments the roadmap is built
around.

Neither option Bertan posed is the best available. Comparing quote text against chunk text
*at scoring time* has a false-positive mode found while measuring: every chunk is built as
`f"Article {n}.{i}: {title}\n\n{para}"`, so a quote overlapping the article **title**
matches every chunk of that article — `art14_case1` matches all 10 chunks of Article 14.

Proposed instead, and accepted by Bertan as worth keeping: **resolve the quote to gold
chunk ID(s) once at eval-set build time, score by ID at run time.** Measured feasibility
on current data — **294 of 299 grounded cases pin exactly one chunk**; 3 span a chunk
boundary, 2 are ambiguous. Ungrounded quotes then fail loudly at build time instead of
silently depressing every run. Not yet implemented.

---

## 26 of the remaining 134 errors are a corpus artifact, not test-case defects

The corpus carries line numbering interleaved into article content — docling numbered the
first sub-items of an enumeration `2. 3. 4.`, continuing the paragraph count, then
switched to bullets partway through the same list:

```
1. Where personal data ... are collected from the data subject, the controller shall ...
2. (a) the identity and the contact details of the controller ...
3. (b) the contact details of the data protection officer ...
- (d) where the processing is based on point (f) of Article 6(1) ...
```

Stripping those indices grounds **26 of the 134, all 26 contiguous verbatim** — no false
clears. Same shape as the previous session's finding: a corpus fault reported in
test-case vocabulary.

**Deliberately not fixed.** Corpus formatting changes are deferred to the planned
chunking/embedding rework, so this is recorded with its size rather than patched
piecemeal.

---

## The classification could not be reproduced from the previous report

The 2026-08-02 report recorded 76 elision / 37 altered / 20 absent / 1 punctuation, from
an analysis script that was never committed. Re-deriving it with an explicit criterion
gave **77 elision / 56 altered / 1 punctuation**. The `absent` category could not be
reproduced because the threshold that produced it is not recorded anywhere.

The signal itself does reproduce — `art41_case3` shows an 11-word run with no matching
bigram in its article, matching the earlier note exactly. The new classifier is still
uncommitted, so this gap is not yet closed.

Inspection showed "altered" is three defects wearing one label:

- **The generator tidied the statute.** `art32_case4` writes *"shall not process them"*
  for *"does not process them"*; `art38_case2` writes *"performing his or her tasks"*
  where the regulation genuinely says *"performing his tasks"*. Same class as
  `art36_case4`.
- **Substantive alteration.** `art37_case1` turns *"Article 9 **and** personal data"* into
  *"Article 9 **or** personal data"* — a conjunction governing when a DPO must be
  designated.
- **Invalid case, not a quote defect.** `art41_case3` asks how long accreditation lasts;
  Article 41 contains no *"five years"*, no *"maximum period"*, no *"renewed"*, and it is
  the only case where **none** of its `key_phrases` appear in its gold article.
  `art8_case5` quotes **Recital 38**, not Article 8. Writing a quote for these would
  launder an unanswerable question into a clean-looking case.

Both were verified against the corpus only, not the source PDF. Per the previous
session's `art36_case4` lesson, that rules out one link in the chain and no more.

---

## The gate does not measure the property that matters

Bertan set the acceptance criterion: **every one of the 433 questions must be answerable
using only its `supporting_quote`.** That is not what the gate checks. Two independent
properties:

- **Provenance** — `quote ⊆ article`. What the gate checks today.
- **Sufficiency** — the quote answers the question. What actually matters.

They are uncorrelated. `art2_case4` grounds **exact** and passes cleanly today:

> **Q:** Does GDPR apply to law enforcement agencies investigating criminal offences?
> **A:** *No, GDPR **does not apply** when competent authorities process…*
> **Quote:** *"by competent authorities for the purposes of the prevention,
> investigation, detection or prosecution of criminal offences…"*

A verbatim fragment of Article 2 that never contains the negation. Perfect provenance,
zero sufficiency.

A deterministic screen was built and then rejected as a gate. Matching `key_phrases`
literally against the quote flagged 57 cases, mostly word-order noise
(`'monitoring of behaviour'` vs *"the monitoring of their behaviour"*). Matching the
phrase's words **in order, gaps allowed** cut that to 35. It still cannot be a gate:
`art8_case1` is flagged for missing `'parental consent'` though its quote fully answers
*"what is the minimum age?"* — key phrases include glosses and terms of art that
legitimately never appear in the evidence.

| | quote covers keys | key content absent |
|---|---:|---:|
| grounded | **264** | **35** |
| ungrounded | 110 | 24 |

**The repair set is therefore 169 cases, not 134** — 35 pass the gate today and fail the
criterion.

Bertan settled the approach: sufficiency is semantic and will be judged by an LLM judge or
a panel, not measured deterministically. He also framed it as two-sided — a quote that
cannot answer the question is **useless**, while one carrying far more than needed is
**not useless but devalued**. The screen's role is triage and judge calibration, nothing
more.

Design was in progress when the session ended. Nothing was built.

---

## Decisions

- **Self-reference only** for leakage, at Bertan's direction — a test case for Article N
  may cite any other article; only naming N is prohibited.
- **Drop the bare-`paragraph` arm** rather than port it. Only self-reference is
  prohibited, and no question in the 433 contains such a reference.
- **Exclude bare `that`** from the demonstrative check. Ambiguous with the relative
  pronoun; including it cost 29 flags to find 8.
- **Add the self-containment gate after fixing the data**, so it reports 0 on arrival —
  and footnote the ledger so earlier rows read *unmeasured* rather than *clean*.
- **Leave the 2026-08-02 report's analysis as written**, marking overtaken passages rather
  than rewriting them; extend its ledger, since it is explicitly a running one.
- **Defer the corpus line-numbering fix** to the chunking/embedding rework.
- **Sufficiency is judge-tier**, not deterministic. The key-phrase screen is triage.
- **Commits split code / data / docs**, continuing the convention.

---

## Mistakes made this session

Attributed, per this log's convention. All are the assistant's unless stated.

- **Over-built the leakage matcher twice** — a bare-`paragraph` rule and multi-article run
  parsing, both for cases that do not exist in the data. Bertan rejected both and asked
  for the reasoning before accepting any edit, which is what forced the measurement.
- **Reported 5 "this article" cases from a `grep`**, then 7 from a noun list, when the
  real count was 8. Two successive under-counts from enumerating an open class — the
  session's most instructive error, since the fix generalised into a rule.
- **Duplicated a backlog entry** while editing `todo.md`, leaving two copies of the
  parametric-answerability item. Caught by re-reading the file, not by any check.
- **Claimed the eval-report classification would reproduce.** It did not — the previous
  script was never committed, so 37/20 could not be re-derived.
- **Stated the 2026-08-02 report should not be updated**, then updated it when asked. The
  point-in-time framing was the assistant's inference, not a recorded convention.

Bertan's catches this session were all scope corrections — rejecting speculative
generality twice, and reframing the whole quote-repair effort around sufficiency rather
than the categories the assistant had been sorting into.

---

## State handed to the next session

| | |
|---|---|
| Corpus | 99 articles, 187,287 chars — **26 gate errors traceable to line-numbering artifacts** |
| Qdrant | `compliance_docs`, **still stale** — 14 articles changed on 2026-08-02, never re-indexed |
| Golden set | 285 exact · 14 normalized · 134 ungrounded · **0 leakage** · **0 self-containment** · 299/433 clean |
| Sufficiency | **unmeasured** — screen flags 169 of 433 as needing work |
| Gate | **FAIL** (correct — all remaining errors are quote grounding) |
| Tests | **81 passed**, no xfails |

**Open, roughly in order:**

- **Re-index Qdrant.** Carried over untouched from the previous session and still the only
  item leaving the system inconsistent. ~$0.001, idempotent.
- **Build the answer-vs-quote sufficiency judge.** Design was under way at session end:
  blind protocol (the judge answers from the quote alone, without seeing the article or
  the gold answer, and a second stage compares), a panel for the verdict, and a human
  calibration sample as §6.2 and §7.3 already require. The project uses OpenRouter via
  `ai_common`; `gdpr_test_data_generation.py` already has the async multi-model pattern to
  follow. **Undecided:** whether the target is *question answerable from quote* or the
  stronger *answer entailed by quote* — they disagree on real cases (`art7_case3`).
- **Gold chunk IDs** — resolve each quote to its chunk(s) at build time, score by ID.
  294/299 pin exactly one chunk today.
- **58 quotes to rewrite**, now understood as three separate jobs: restore tidied text,
  fix substantive alterations, and triage invalid cases (`art41_case3`, `art8_case5`)
  against the **source PDF**, not just the corpus.
- **Elision (51 genuine + 26 corpus-blocked)** — the span-list design, still undecided.
  Sufficiency is the argument for it: `art2_case4` shows what truncating a span costs.
- **Commit the quote classifier**, so the 77/56/1 split is reproducible.
- **Reconcile §3.1** with how Context Recall is actually scored.
- **Constrain the generator** — both classes closed today are producer faults.
- **Systematise mutation testing** so check recall is a number, not a feeling.
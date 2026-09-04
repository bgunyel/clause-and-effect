# Dev Log

One entry per working session, written at the end of it. The log records what
happened and why — decisions taken, things tried that did not work, and the
state the next session inherits. It is the *reasoning* companion to `git log`,
not a replacement: commits say what changed, these say why.

**This directory is public and is read by people evaluating the work.** An entry
is a technical record, not a diary. It is also the source material for the
session's public write-ups, so accuracy about *who did what* is not a stylistic
preference — it is the difference between evidence and noise.

## Voice and attribution

Sessions here are worked jointly by a human engineer and an AI assistant. An
entry that blurs the two is worse than useless: it hands the assistant's errors
to the engineer and deletes the engineer's catches, which are the most valuable
thing in the record.

- **Never write a bare "I".** There is no single narrator. Name the agent:
  *"the assistant"* and *"Bertan"* (or *"the engineer"*).
- **Passive voice is correct when the agent carries no information** — facts
  about the system. *"99 articles were extracted."* *"The gate was reproduced
  against the pre-fix corpus."* Most of an entry should read this way.
- **Active voice with a named agent is required when attribution carries
  information** — decisions, errors, corrections, and anything a reader would
  otherwise misassign. *"The assistant classified six cases as failures; Bertan
  read Article 53 and established the rule was wrong, not the data."*
- **Never use passive to soften an error.** *"An error was made"* records
  nothing. Say who, and what the reasoning was that produced it.

## Register

- **Lead with the finding, not the chronology.** *"The grounding rule produced
  false positives on six cases"* — not *"the session opened with a question
  about..."*. Sequence only where causality depends on it.
- No suspense, no reveals, no exclamation. A reader skimming for the state of
  the system should get it from the headings.
- Section titles state findings, not events.

## Conventions

- File name: `devlog_YYYY-MM-DD_session-N.md`, where `N` counts sessions within
  that day starting at 1 (multiple sessions per day are expected).
- Open with the date, branch, commit range, and how far ahead of `main` the
  branch ended up.
- Written for technical readers who know the codebase. Prefer measured numbers
  and commit SHAs over recollection — and say which figures were measured versus
  recalled.
- Record dead ends and mistakes, not just the path that worked — a session that
  only lists successes hides the expensive part. Attribute each one.
- Where a claim was checked against a primary source (the PDF, the regulation,
  a module's actual code), say so. Verification that only ruled out one link in
  the chain is not verification, and the entry should make that distinction.
- Close with what is still open and what the next session should pick up.

## Entries

- [2026-08-01 · session 1](devlog_2026-08-01_session-1.md) — GDPR corpus
  regeneration: docling accelerator pin, article-header collapse, chapter
  scaffolding leak, Qdrant point-ID rework, re-index.
- [2026-08-02 · session 1](devlog_2026-08-02_session-1.md) — golden-set QA
  baseline, OCR soft hyphens, cached docling-export pipeline, tier-5 grounding
  normalization, and the discovery that the grounding rule was itself producing
  false positives.
- [2026-08-03 · session 1](devlog_2026-08-03_session-1.md) — leakage keyed on
  self-reference, a new self-containment gate, 25 questions reworded, §7.3
  reconciled with the gates that exist, and the finding that provenance and
  sufficiency are uncorrelated.
- [2026-08-05 · session 1](devlog_2026-08-05_session-1.md) — sufficiency criterion
  settled on `art7_case3`, stages A and B of the judge built, and the discovery
  that docling's markdown serializer destroys the paragraph hierarchy in 43 of 99
  articles — severing stems from their sub-items in the index.
- [2026-08-06 · session 1](devlog_2026-08-06_session-1.md) — corpus rebuilt from
  the docling document tree (grounding 299 → 319 clean, zero regressions), the
  same defect found one layer down in the chunker with Article 4 as the worked
  example, and chunk sets made a hashed, provenance-carrying artifact.
- [2026-08-07 · session 1](devlog_2026-08-07_session-1.md) — priority reset to
  the evaluation pipeline under the rule that the eval must be flawless while the
  algorithm need not be; first two chunk snapshots written and indexed (196
  orphaned points deleted, every point now stamped with its chunk set); tests
  81 → 180, of which the interesting result is the four mutations that survived
  because the tests were green for the wrong reasons.
- [2026-08-07 · session 2](devlog_2026-08-07_session-2.md) — the `index_chunks`
  seam split from the write primitive, a `chunking` package extracted (a
  three-field dataclass was costing 9.78s to import), `Chunk` retyped and the
  chunker lifted out of the parser, a circular import held closed by two dead
  lines, and regulation constants collapsed from three free parameters to one
  lookup. Ends mid-refactor with 58 failing tests, enumerated.
- [2026-08-09 · session 1](devlog_2026-08-09_session-1.md) — the chunking
  refactor finished and the `vector_db` source side reviewed item by item; the
  digest became caller-supplied (a recorded property deliberately reversed);
  output routed through logging, with `RichHandler` tried and rejected for
  breaking a hash across two lines. Ends with 24 failing tests in
  `test_vector_db.py`.
- [2026-08-10 · session 1](devlog_2026-08-10_session-1.md) — `test_vector_db.py`
  repaired 24 → 0 with every rewrite mutation-checked, two of the three handover
  predictions found wrong, and the first baseline snapshot (`5caac594…`) written
  against a clean tree and merged to `main`. The sufficiency judge documented and
  split into a package — where a claimed import-cost property was measured and
  found absent. Golden-set provenance established after the assistant concluded
  it wrongly from git twice. `ai_common`'s fix order shown to be forced: two of
  three candidate optimisations measure as worth zero until the package
  `__init__` is fixed.
- [2026-08-10 · session 2](devlog_2026-08-10_session-2.md) — spent entirely in
  the **`ai-common`** repo. The `__init__` fix landed in an hour (`from
  ai_common.enums import …` 4.11s → 0.14s); the rest went to the GuardDog
  wrapper sitting uncommitted beside it, where the tier-2 gate turned out never
  to have gated — `guarddog pypi scan` exits 0 whether it found nothing, found
  malicious indicators, or never downloaded the package. Rebuilt to derive its
  own verdict from JSON, with a machine-wide cache that concurrent projects no
  longer clobber and an `upgrade-safe` that no longer leaves `uv.lock` upgraded
  and unverified on Ctrl-C. Then guarddog 2.10.0 → 3.1.0, and a one-minute smoke
  scan produced three blockers — a dead sandbox, 61 renamed rules, and a guard
  that eats the error it was written to surface — so the hour-long sweep was not
  started.
- [2026-08-11 · session 1](devlog_2026-08-11_session-1.md) — all three GuardDog
  3.1.0 blockers closed: the "sandbox cannot get entropy" failure turned out to
  be a Landlock filesystem denial wearing an entropy error's clothing, settled by
  one `strace` line. The tier-2 gate re-based off rule names onto risk severity
  and the new threshold measured against 74 real dependencies; three Makefile
  defects the measurement exposed tightened. Tests 92 → 103, 13 mutants killed
  with no survivors.
- [2026-08-12 · session 1](devlog_2026-08-12_session-1.md) — the high-severity
  `google-genai` finding shown to be `eval(` matching inside the word
  `Retrieval(`, an unguarded JavaScript pattern applied to Python source, with
  `pillow` blocking on the same upstream defect. Because the cache could not have
  answered that question, a report store, a review ledger and a backfill of 74
  calibration reports were built around it; four waivers written, and the pyyaml
  assessment corrected in the package's favour. Tests 103 → 127, 19 mutants, 0
  survivors.
- [2026-08-13 · session 1](devlog_2026-08-13_session-1.md) — tier 1 found red on
  the committed lock and taken 5 advisories → 3; `ai-common` PR #24 merged and
  Dependabot alert #33 identified; lockfile independence measured — a merge that
  moved 25 packages there moved none here; `make test` found to have been running
  nothing since `57c37a5`; the two langchain versions shown by experiment to be a
  stale fork rather than a platform requirement; a 66-minute sweep aborted on
  Bertan's question and the abort vindicated by the candidate lock; and Python
  found 12 patch releases stale, with 30 advisories neither tier of the gate can
  see.
- [2026-08-13 · session 2](devlog_2026-08-13_session-2.md) — `cuda-toolkit`
  shown not to be unscannable at all: uv reads a version from the wheel
  filename, PyPI keys its index on the canonical form, and the two disagree on
  4 of 39 releases. Fixed in `ai-common` PR #25, which let tier 2 reach a
  verdict on every package for the first time — 178 packages, INCOMPLETE 0,
  eight blockers. Six of the eight are one rule firing outside its declared
  scope; four waived, and session 1's reading of `docling-slim` found inverted —
  its `curl … | sh` is a log message, while the two packages that really do
  fetch-and-execute were never reached by the aborted sweep. Underneath it,
  uv found 16 months stale, which blocks the interpreter upgrade and puts the
  resolver that writes `uv.lock` in the same blind spot as the interpreter;
  plan written, not executed.
- [2026-08-16 · session 1](devlog_2026-08-16_session-1.md) — the uv plan
  executed end to end: both repositories on uv 0.12.5 and CPython 3.13.15,
  pinned and committed, with the old resolver now refusing to run in either.
  Two of phase 5's three exit criteria turned out to have been unsatisfiable
  before the upgrade began, and the sweep that replaced them produced the first
  complete committed-lock tier-2 baseline the project has — 180 packages,
  INCOMPLETE 0, eight blockers, none attributable to the upgrade. The larger
  finding came from a phase-1 side effect: **the sweep installs the candidate
  it is about to judge, and a rejected candidate stays installed**, in the
  environment that runs the code and in no artifact either tier examines.
  Demonstrated, fixed with `uv run --frozen --no-sync`, given a test in both
  suites, and documented — and the test then caught the same drift again on its
  first run.
- [2026-08-17 · session 1](devlog_2026-08-17_session-1.md) — an `upgrade-safe`
  found stalled at 85 minutes on a dead socket nothing was watching for:
  `pygit2` clones with no timeout, and `_scan_once` ran `subprocess.run` with
  none either, so one silently-dropped connection held the sweep open
  indefinitely. Bounded in `ai-common` #28 and #29, both mutation-verified by
  wall clock. The gate's remaining eight blockers were then cleared by twenty
  individually-approved decisions — and the method changed halfway through, when
  comparing *reported* findings across versions was shown unsound: GuardDog's
  `max_hits` truncates the evidence, and `transformers` reported one qualifying
  file out of ten. Both tiers now pass and `make verify`, structurally unusable
  here while tier 1 was red, exits 0. Also found: the installed GuardDog is not
  the stock 3.1.0 wheel.- [2026-08-17 · session 2](devlog_2026-08-17_session-2.md) — stage C built and
  tested (suite 249 → 298), the full A→B→C chain running over the eight probe
  cases, and core-claims-only settled by Bertan on evidence rather than cost:
  stage B answers only what was asked, so an auxiliary claim comes back `absent`
  almost by construction. The finding that outranks the code came from running
  it — **stage A is not stable at temperature 0, and the instability reaches the
  verdict**: `art8_case1` returned 1, 1, 2 and 1 core claims across four
  identical runs, and the two-claim run flips the case from `sufficient` to
  `insufficient`. Two rounds of prompt work took the observed failures to zero
  and introduced a new one.
- [2026-08-22 · session 1](devlog_2026-08-22_session-1.md) — stage A split into
  two independent calls (A1 writes the shortest sufficient answer, A2 tags the
  claims, neither sees the other's output), six probe scripts, and 60 stability
  calls. A1 measured clean everywhere it was pointed; A2 unstable on 3–4 of 6
  cases, two of those failures degenerate output rather than disagreement. A
  transport failure latent in all five stages was found and guarded —
  `with_structured_output` returns `None` when output will not coerce, and every
  stage read a field straight off it. Both of the session's larger results are
  Bertan's reframings: **the judge is a defect finder for the golden set, not a
  classifier fitted to it**, which removes the train/test framing entirely, and
  **granularity is soft while the core/auxiliary boundary is hard**, which
  invalidates the metric §4.6 uses.
- [2026-08-23 · session 1](devlog_2026-08-23_session-1.md) — a judge run made
  auditable: every stage now returns what its call cost, read off the raw message
  that `include_raw=True` keeps, and every A2 stability sample writes a
  provenance-carrying record into `docs/eval-reports/`. Eight OpenRouter models
  added to `ai-common` (#31) and the config rebuilt from a list of names — where
  a shared `model_args` dict would have let the Gemini panelist rewrite the
  sampling of the other eight, since `ai_common.get_llm` mutates what it is
  handed. The larger result is about the instrument: **two more stability samples
  came back 0 of 6**, putting four samples of the same prompt and model at 4/6,
  3/6, 0/6, 0/6 — N=5 cannot support the comparison the next measurement was
  going to make.
- [2026-08-23 · session 2](devlog_2026-08-23_session-2.md) — the panel stood up,
  and almost everything found was about the instrument rather than the judges:
  reasoning effort silently lost after the first call, no timeout anywhere, and
  structured output failing for reasons unrelated to judgement — so each panelist
  now gets its own measured channel, at the cost of the uniformity the config
  otherwise keeps. The panel does agree, 4–5 of 6 cases unanimous, but every run
  disagreed with the one before it by about as much as the panelists disagreed
  with each other. The most consequential finding is Bertan's, from the
  OpenRouter console rather than the code: **MiniMax's "failures" were
  successful, billed generations that we discarded.**
- [2026-08-25 · session 1](devlog_2026-08-25_session-1.md) — three facts the code
  was holding at the moment of failure and throwing away — the price of a failed
  call, the generation id, the reasoning budget — recorded as
  `CallRecord(generation_id, cost, reasoning_tokens)`. Once recorded, two beliefs
  about the panel proved wrong: the reasoning-suppression suspicion **does not
  reproduce** on the model that raised it, and A2 stability at 25 runs reads a
  substantive **0 of 6**, the one flagged case differing by the word `and`.
  Bertan's catch changed the most code — `[0]` on the roster at ten call sites
  makes the subject of a measurement a consequence of list order.
- [2026-08-25 · session 2](devlog_2026-08-25_session-2.md) — no code, by intent.
  MiniMax's channel failure was traced to its root and is **not about MiniMax**:
  OpenRouter routes one model id to whichever upstream provider it picks, those
  providers differ in what they can do, and nothing recorded which one answered.
  Every MiniMax success on record came from a provider reached by **falling back
  from one that returned 429** — the channel assignment was decided by a rate
  limiter. The premise `llm_config.py` rests on is broken one layer below the
  configuration. Bertan directed that calls be logged to a database; the session
  closed with a draft design document and eleven open questions.
- [2026-08-26 · session 1](devlog_2026-08-26_session-1.md) — the call-log design
  was finished, and the measurement taken to finish it changed what is being
  built. **A retried call makes an unbounded number of billed generations and
  nothing above the socket could name more than one of them** — 67% of one
  call's cost unaccounted in the mild case, 100% in the exhausted one.
  `max_retries` turns out to be a 300-second time budget rather than a count, so
  one logical call has a fifteen-minute worst case; a callback handler was
  proposed as the capture mechanism and **rejected on measurement**, because it
  sees no more of the retries than the call site does. The served provider,
  meanwhile, is free in the raw response body. The log became three tables with
  a socket-level attempt row, and Bertan's clarification that **the LLM server is
  not the provider** exposed a column the assistant had misnamed.
- [2026-08-26 · session 2](devlog_2026-08-26_session-2.md) — the call log built
  as far as its schema: dependencies, two engines, three tables, 141 new tests,
  and nothing written to the database. Two findings, both about the gap between
  a decision and its effect. **The statement timeout was never in force** —
  Supabase's pooler consumes the startup packet, so `pg_sleep(30)` ran to
  completion while the code read as correct; the repair needs a `SET` *and* a
  commit, because both drivers leave it in a transaction they never end. And
  **the same one-row write costs 47 ms or 141 ms** depending only on whether
  SQLAlchemy wrapped it in a transaction. A trigger proposed for `updated_at`
  was measured out of existence when Bertan's two questions exposed a third
  option the assistant's framing had hidden. Bertan's reading of OpenRouter's
  documentation gave the design its strongest argument: **an uncaptured
  generation id is unreachable by API, permanently.**
- [2026-08-26 · session 3](devlog_2026-08-26_session-3.md) — the call log becomes
  a mechanism: Alembic applied to the live instance, the repository layer, and
  `llm_call()` wrapped around all five judge stages, at a spend of $0.00.
  **`pool_pre_ping` costs a quarter of what session 2 recorded** — 43.4 ms per
  write against the real insert, not 155 ms — and the row shape turns out to
  cost nothing at all. **`include_object` was measured in both directions**: on a
  shared Supabase project, autogenerate without it writes a migration that
  applies cleanly and drops somebody else's table. Bertan established that
  `llm_call()` belongs in a shared tier rather than inside the judge, and his
  second observation — that none of the four call statuses is judge-specific —
  removed a callback hook the assistant was about to design. Looking for the
  product path's call sites turned up **a second billed model call per answer,
  discarded**.
- [2026-09-04 · session 1](devlog_2026-09-04_session-1.md) — the model-call
  machinery lifted out of the judge into a shared `src/llm/` tier, on Bertan's
  constraint that **every LLM call in the repository goes through the logged
  wrapper**, not only the judge's. `src/eval/sufficiency/llm.py` is 158 lines
  against 695 and holds only the judge's vocabulary. Two departures from the
  recorded plan, both the assistant's: `StageResponse` subclasses the shared
  response rather than restating it, which makes a judge failure catchable as
  the shared one, and the log row's `error_message` drops the stage prefix
  because the row already has a `stage` column. One deferral could be deleted
  rather than moved — the channel constants no longer sit behind a module that
  imports `ai_common`. Also found: **`src/config.py` modified by nobody this
  session**, committed separately rather than folded into the refactor.


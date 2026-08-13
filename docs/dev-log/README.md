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
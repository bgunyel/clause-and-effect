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
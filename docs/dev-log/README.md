# Dev Log

One entry per working session, written at the end of it. The log records what
happened and why — decisions taken, things tried that did not work, and the
state the next session inherits. It is a narrative companion to `git log`, not
a replacement: commits say what changed, these say what was going on.

## Conventions

- File name: `devlog_YYYY-MM-DD_session-N.md`, where `N` counts sessions within
  that day starting at 1 (multiple sessions per day are expected).
- Open with the date, branch, commit range, and how far ahead of `main` the
  branch ended up.
- Written for technical readers who know the codebase. Prefer measured numbers
  and commit SHAs over recollection.
- Record dead ends and mistakes, not just the path that worked — a session that
  only lists successes hides the expensive part.
- Close with what is still open and what the next session should pick up.

## Entries

- [2026-08-01 · session 1](devlog_2026-08-01_session-1.md) — GDPR corpus
  regeneration: docling accelerator pin, article-header collapse, chapter
  scaffolding leak, Qdrant point-ID rework, re-index.
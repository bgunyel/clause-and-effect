# Lessons Learned

Detailed post-mortems of bugs, errors, and problems that cost real effort to
diagnose. The goal is not to record *that* something broke — git history does
that — but to capture the reasoning that was expensive to reconstruct: why the
defect was invisible, what evidence eventually located it, and which assumption
turned out to be false.

## Conventions

- One file per incident, named `YYYY-MM-DD-short-slug.md`.
- Written for technical readers who know the codebase. Be specific: exact
  regexes, line references, character counts, command output. Vague summaries
  ("fixed a parsing issue") defeat the purpose.
- Cover, at minimum: symptom, root cause, why existing tests/checks missed it,
  how it was diagnosed, verification evidence, and the generalisable lesson.
- Prefer verified numbers over recollection. If a figure was not measured, say
  so rather than estimating silently.

## Index

- [2026-08-01 — GDPR article-header collapse](2026-08-01-gdpr-article-header-collapse.md)
  — a parser and its test fixture agreed with each other but not with docling,
  collapsing all 99 GDPR articles into one 137k-character record.
- [2026-08-11 — GuardDog's sandbox and `/dev/urandom`](2026-08-11-guarddog-sandbox-dev-urandom.md)
  — an error message naming the random-number subsystem was a Landlock file
  denial; GuardDog scanned 0 of 61 rules and reported "No risks found", exit 0.
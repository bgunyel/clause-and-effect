# Clause and Effect

A question-answering system over regulatory text, built evaluation-first: an
architecture decision is measured before it is kept. A check asserts, a probe
asks, and the two must not borrow each other's name. This glossary is written
lazily — a term is added when a collision has actually been resolved in the
repository, not in advance of one.

## Language

**Check**:
An assertion whose expected verdict is written out in advance, so running it can
only agree or disagree with what was already claimed. Every assertion in
`.claude/hooks/check-hooks.sh` is a check.
_Avoid_: probe

**Probe**:
An empirical measurement whose answer is not known until it runs. Each
`scripts/probe_*.py` is a probe — one measurement, its output landing in
`docs/eval-reports/`.
_Avoid_: check

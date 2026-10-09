# Research

What is true **outside** this repository: a provider's response body, a
library's behaviour, a specification's wording. One document per question,
answered against primary sources, with every claim attributed to the source it
came from.

These are the answer to *"before we build this, what does the thing we do not
control actually do?"* — the reading legwork that would otherwise be redone by
each person who needs it, or, worse, guessed at once and then quoted forever.

A document here is the output of a `wayfinder:research` ticket. The ticket asks
a question and forbids answering the decision it unblocks; the document keeps
that separation.

## What belongs here, and what does not

The boundary is ownership, not subject matter:

| directory | question it answers | dated? |
|---|---|---|
| **`research/`** | **what is true outside this repository** | **no, revised in place** |
| `design/` | how a mechanism **here** works today | no, revised in place |
| `adr/` | why a decision was taken, and what was rejected | no, superseded |
| `eval-reports/` | what the numbers were at a point in time | yes, append-only |

- **Against `design/`.** The boundary is ownership: a design document describes
  code this repository owns, a research document describes something it does
  not. `docs/design/README.md` draws the line in full, including what each kind
  can be checked against; it is stated once, there. What matters at this end:
  when a finding here changes how a mechanism is built, the finding stays here
  and the design document cites it — copying it across leaves two claims that
  drift apart.
- **Against `adr/`.** Research establishes what is true; an ADR records what
  was decided in the light of it. A research document that ends in a
  recommendation has stopped being research.
- **Against `eval-reports/`.** An eval report is a measurement of *this*
  system, taken once, and is append-only for that reason — re-running the eval
  produces a new report, not an edit to the old one. A research document is not
  a measurement of this system and is not frozen; see below.

## Undated, and not append-only

Filenames are **undated** and a document is **revised in place**.

That is a deliberate exception to the rule that evidence gathered at a point in
time is append-only, and the reason is the marker convention. A research
document marks every claim it has not actually observed:

- **`[NEEDS OBSERVATION]`** — documented, or inferred from documentation, but
  not seen.
- **`[DOCS SILENT]`** — the source does not answer the question. A gap recorded
  as a gap, which is not the same as the field being absent.

The markers exist so a later session can grep the file and get a checklist.
Clearing one *is* the intended edit. Freezing the document would make the
checklist unworkable, and would leave the repository quoting a provider's
documentation from a date at which it has since changed. The history lives in
git, which is where a rewritten document's history belongs.

The cost of that choice, stated because it is real: a reader cannot tell from
the file alone what it said last month. If a claim's *former* wording is what
matters — because a decision was taken on it and later went wrong — that
belongs in `dev-log/` or `lessons-learned/`, which are append-only precisely so
they can be quoted.

## Register

**This directory is public and is read by people evaluating the work.** The
standing rule this project applies to its own gates applies here with more
force, because the subject is someone else's system:

> A claim about a layer's behaviour is worth nothing until the layer has been
> observed doing it.

- **Separate what was read from what was seen.** A quotation from a provider's
  documentation and a response body captured from that provider are different
  kinds of evidence. Mark the first; do not present it as the second. Reading
  library source produced a wrong claim twice on 2026-08-25 — that
  `response_metadata["provider"]` was available for free, asserted from
  `langchain_openrouter/chat_models.py:870` and absent when measured
  (`docs/dev-log/devlog_2026-08-25_session-2.md`, "The served provider does not
  reach the message"). That is why the markers are not optional.
- **Attribute at the point of the claim**, not in a bibliography at the end —
  a reader checking one row should not have to guess which source it came from.
  Name the version, revision or read date of what was read.
- **Record a gap as a gap.** "The documentation does not say" is a finding.
  Silently omitting the question is not.
- **Decide nothing.** State what the decision would turn on, and stop.

## Conventions

- File name: kebab-case, **undated**, e.g. `non-openrouter-response-bodies.md`.
- Open with the ticket the research answers, the date the sources were read,
  and what kind of evidence the document contains — in particular, whether
  anything was observed rather than read.
- State the marker convention in the document itself, so it is readable without
  this README.
- Close with **What would need to be observed** — the `[NEEDS OBSERVATION]`
  markers gathered into a checklist — and **Sources**.
- Prefer a comparison table where the question is "which of these does what".
  It makes an omission visible as an empty cell rather than an absent
  paragraph.

## Documents

- [What a non-OpenRouter completions body actually contains](non-openrouter-response-bodies.md)
  — for five of the seven servers in `ai_common.enums.LlmServers` (`OPENROUTER`
  is the baseline the others are measured against; `GOOGLE` was outside the
  ticket's scope), what the response body carries: cost, identifier, usage
  shape, and whether anything names the machine that served it. Read against
  each provider's documentation on
  2026-09-04; **no live API call was made**, and every claim is marked
  accordingly. Feeds `docs/design/llm-call-log.md`, whose socket patch filters
  on the completions path — the document's first finding is that three of the
  five servers do not use that path at all.

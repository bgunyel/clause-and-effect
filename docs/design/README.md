# Design

Durable descriptions of how a mechanism in this repository works, and why it was
built that way. One document per mechanism.

These are the answer to *"how does this actually work, and what is it protecting
against?"* — the reasoning that would otherwise survive only in commit messages,
comments, and whoever was in the room.

## What belongs here, and what does not

This directory is different in kind from its neighbours, and the difference is
easy to erode:

| directory | question it answers | dated? |
|---|---|---|
| `dev-log/` | what happened in a session, and why | yes, append-only |
| `lessons-learned/` | how a specific failure happened | yes, append-only |
| `eval-reports/` | what the numbers were at a point in time | yes, append-only |
| **`design/`** | **how a mechanism works today** | **no, revised in place** |

Everything above `design/` is a **record**: written once, never edited, because
editing history destroys its value. A design document is the opposite — it is
**current state**, and when the mechanism changes the document is rewritten to
match. Its history lives in git, not in the filename.

Two documents this is also not:

- `evaluation-plan.md` states what the evaluation framework *should* become.
  Design documents describe what *exists*. When they disagree, the design
  document is wrong or the code is — the plan is not evidence of either.
- `todo.md` is the backlog. A design document may note a known gap and link to
  its backlog entry, but it is not where work gets tracked.

## Register

**This directory is public and is read by people evaluating the work.** A
document here is a technical description, not advocacy for a design. If a
mechanism has a weakness, the document says so — a description that only lists
strengths tells a reader nothing they can rely on.

- **Lead with the mechanism, not the history.** How it works comes first; why
  the alternatives were rejected comes after, and only where the reasoning is
  load-bearing.
- **Separate what is observed from what is argued.** This project's standing
  rule is that a gate never seen to fail is unverified, and it applies to
  documentation: say which properties were *measured*, which were *reasoned*,
  and quote the evidence for the first. "SHA-256 is deterministic" is an
  argument; "three runs with randomized `PYTHONHASHSEED` produced the same
  digest" is an observation.
- **State the scope limits explicitly.** What a mechanism does *not* protect
  against is usually more valuable than what it does, because that is where the
  next failure comes from.
- Written for technical readers who know the codebase. Name the code —
  `module.py:function` — so a reader can check the document against it.

## Conventions

- File name: kebab-case, **undated**, e.g. `chunk-snapshot-reproducibility.md`.
  The file describes the mechanism as it stands; a dated name would imply
  otherwise.
- Open with a one-paragraph statement of what the mechanism is for and what
  failure it exists to prevent.
- Close with **Known gaps** — the scope limits, each linked to its `todo.md`
  entry where one exists.
- Carry a **"Verified against"** line naming the commit the document was last
  checked against the code at. These drift silently otherwise, and a design
  document that quietly stops matching the code is worse than none, because it
  is trusted.
- Prefer real output — actual terminal transcripts, actual hashes, actual
  counts — over illustrative examples. Invented examples drift without anyone
  noticing; real ones can be re-run.

## Documents

- [What the dependency gate actually scans](dependency-scanning-scope.md) — the
  scope of the two-tier supply-chain gate: that a dependency's own dependencies
  are fully covered, that a consumed lockfile has no authority over ours, and
  that first-party source is scanned by nobody — deliberately, but silently.
- [Keeping the environment coupled to the lock](environment-lock-coupling.md) —
  why a package can be installed without being locked, and so scanned by
  neither tier; the recipe flags that stop the sweep installing a candidate it
  is about to reject, and the test that catches the drift arriving by any other
  route.
- [Chunk snapshot reproducibility](chunk-snapshot-reproducibility.md) — how a
  chunk set becomes a named, hashed, provenance-carrying artifact, so that "is
  the vector index stale?" becomes a comparison rather than a recollection.
- [The answer-vs-quote sufficiency judge](sufficiency-judge.md) — how the golden
  set is checked for whether each `supporting_quote` actually answers its
  question, as opposed to merely coming from the right article. Half built; the
  document marks which sections describe code and which specify unbuilt work.
- [The LLM call log](llm-call-log.md) — recording which upstream provider
  answered each model call, at what price, and whether it got there by falling
  back from one that refused. **Half built**: the engines, the tables, the
  migrations and the repository layer exist and are verified against the live
  instance; nothing captures anything yet. The document marks which sections describe code and which
  specify unbuilt work, and collects the corrections the build forced.
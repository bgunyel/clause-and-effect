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

- File name: `devlog_YYYY-MM-DD_SESSION-NAME.md`, where `SESSION-NAME` is the
  session name of the agent writing the dev-log.
- The name is never a number counted from the entries that already exist. A
  worktree branch sees only the dev branch and itself, so two branches writing
  on the same day count to the same number, and an entry cannot be renamed
  once it exists (#157). Entries named under the earlier numbered convention
  keep their names: they are history.
- If the agent does not know its session name, or it is in doubt, it should call
  the `ListAgents` function to see its session name.
- A dev-log entry should start with date and time of the entry. Open with
  branch, commit range, and how far ahead of its root branch the current branch
  ended up.
- If the dev-log file that the agent is trying to write already exists,
  the agent should append a new dev-log entry to the file with a date and time.
- An append is made with `>>` from Bash, and an entry that exists is never
  edited with the Edit or Write tool, except to correct the session segment of
  its heading onto its file name, which ADR 0003 permits (#177).
  `append-only-docs.sh` reads a heredoc's
  text as part of the command, so a heredoc append whose prose reads as a
  command that rewrites an entry can be refused: a `sed -i` anywhere in the
  text, for example, or an `rm` or an `mv` followed on its line by a path under
  this directory (#237), or a `>` followed on its line by such a path (#176).
  Write the text to a scratch file with the Write tool first, and append it
  with `cat <file> >> <entry>`.
  `append-only-docs-edit.sh` does not yet refuse Edit or Write on an entry
  outside the session's project directory, in another checkout of this
  repository: a linked worktree's entry when the project directory is the main
  checkout, or the main checkout's when it is the worktree (#159). There this
  rule is held by the agent and not by a guard.
- Written for technical readers who know the codebase. Prefer measured numbers
  and commit SHAs over recollection — and say which figures were measured versus
  recalled.
- Record dead ends and mistakes, not just the path that worked — a session that
  only lists successes hides the expensive part. Attribute each one.
- Where a claim was checked against a primary source (the PDF, the regulation,
  a module's actual code), say so. Verification that only ruled out one link in
  the chain is not verification, and the entry should make that distinction.
- Close with what is still open and what the next session should pick up.
- Do not add the entries in this file.


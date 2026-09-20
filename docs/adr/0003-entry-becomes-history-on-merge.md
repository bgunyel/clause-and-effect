# An entry becomes history when it reaches the active dev branch

`docs/dev-log/`, `docs/lessons-learned/` and `docs/eval-reports/` are
append-only: old entries are history, and a correction goes in the newest entry.
What that rule never said is *when* an entry becomes old. This decision says: a
file is a **history entry** once it is present on the active dev branch at the
merge base of the working branch with that branch's tip, and a **draft** before
that (`CONTEXT.md` carries both terms). A draft may be rewritten; a history
entry may not.

The rule is also stated by its effect, following ADR 0002, which was written
for the agent boundary and is applied here to a convention hook for the same
reason: a history entry of which the merge base's copy is no longer a byte
prefix has been rewritten, whichever tool did it. A pure append leaves the
recorded bytes as they were, so it is not a rewrite, and that is why the
text-level rule that stands in for the effect in a Bash command can be an
allowlist of reads and `>>` appends with a default-deny rather than a list of
the editors that can overwrite a file. Appending to a history entry is still
not how a correction is made — CLAUDE.md puts corrections in the newest entry,
and that convention is left to the author, not to a hook. The Edit companion
refuses a history entry whole, an append included: it decides by the file, not
by what the payload would do to it, and `>>` is the route for an append.

## The one line of an entry that is metadata, not history (#177)

This decision drew the draft/history line by *when* a file becomes history and
said nothing about *which part of the file* the history is. #177 found the case
where that silence has an answer. `docs/dev-log/devlog_2026-09-17_session-5.md`
carried the heading `# 2026-09-17 · session 2 — …`: the entry had been renamed
to resolve a collision and its heading had not been moved with it, so the file
name and the heading disagreed, and the heading collided with a different
entry's.

A heading that contradicts its own file name is **metadata about the entry that
is obliged to agree with the name, not a statement of history a reader is
entitled to rely on**. Nobody relies on it: it is not a claim about the system,
a measurement, an attribution or a decision. It is the entry's label, and a
label that disagrees with the name it labels records nothing — it only misfiles
the record. So that one line may be corrected in place, on the entry itself,
rather than through a correction in a newer entry.

**This is not a general licence to edit a history entry, and nothing else in
this decision moves.** The scope is exactly one line and exactly one part of it:
the session segment of an entry's `# <date> · <session> — <rest>` heading, in
`docs/dev-log/`, changed only to the session name the file is named for. The
date, the rest of the heading and every byte of the body stay as they were, and
an edit that touches any of them is refused as before. A correction to anything
an entry *says* still goes in the newest entry, and that is unchanged.

The narrowness is not left to the author. `append-only-docs-edit.sh` permits the
correction only when the edit's `old_string` is the file's current first line and
occurs in it exactly once, its `new_string` is a single line, the two differ in
the session segment alone, and the new segment agrees with the file name where
the old one does not. Everything else about a history entry is refused exactly as
it was. Stating the exception in the rule and then in the guard, rather than
making it once by hand, is ADR 0002's shape: the boundary is what the hook
computes, not what a document asks an author to remember.

## Why

#149 found the two halves of the guard asking different questions. The Edit
companion froze a file the moment it existed on disk; the Bash hook refused a
listed verb only when the command text named the path. Two things followed.

- **A draft froze as it was written.** Both sessions in #149 wrote a dev-log
  entry mid-session, needed to correct it after review, and were refused. One
  went around the refusal with a script, the other left four stale counts in a
  pushed entry. The rule had no answer for the ordinary case, correcting your
  own unmerged work, so it had to be broken or worked around.
- **The Bash half guarded spellings.** `python3 -c "open('<entry>','w')"`,
  `awk -i inplace`, `ex`, `ed`, `ruby -i` and `perl -pi` were each permitted on
  an existing entry, and `python3 rewrite_entry.py` names no path at all. That
  last case is out of reach of any rule that reads a command's text, so it
  will be detected after the fact against the merge base rather than
  prevented, and is to be listed in CLAUDE.md among the consequences left
  open. Neither is built by this decision; #149 builds both.

## Considered Options

- **Existence on disk** — the previous answer. Rejected: it freezes drafts,
  which is the defect.
- **Committed on the current branch** (`HEAD`). Rejected: a worktree branch's
  commits are still under review, and review is when corrections arrive.
- **Pushed to the worktree branch.** Rejected for the same reason; a push is how
  a draft gets reviewed, not a publication.
- **The live tip of the active dev branch**, rather than the merge base.
  Rejected: an entry merged after a branch forked would read as deleted on that
  branch, which never had it.

On #177's question — whether a heading that contradicts its file name may be
corrected — the option rejected was **leaving it and correcting forward**, which
is what the rule as written already said and what the record already did. The
README index labelled the entry `session 5` and recorded that its own heading
still read `session 2`, and the 2026-09-20 session 3 entry recorded the
disagreement and why it was not touched. So the cost of that option was not a
broken record; it was two entries headed `session 2` for one day, for as long as
the directory exists, and a reader having to reach the index or a later entry to
learn which is which. It was rejected because the heading is the thing a reader
navigates by, and a label that has to be corrected elsewhere is a label that has
stopped working.

Rejected with it: **widening the guard to permit any edit to a history entry
whose file name and heading disagree.** That would have been the cheap
implementation of the same decision, and it hands over the whole file on the
strength of one wrong line.

## Consequences

The Edit companion permits an existing file that is absent from the merge base,
and still refuses every existing file when the reference cannot be resolved,
following #95. A draft is edited through `Edit`/`Write`; the Bash rule cannot
tell a draft from history without parsing paths out of shell text, which ADR
0002 rejects, so it applies its allowlist to both.

The heading exception is the Edit companion's alone, and the asymmetry is the
one above rather than a new one. `append-only-docs.sh` reads a command's text,
so it cannot see that a command would change one line of a heading and nothing
else; it keeps its allowlist unchanged and refuses the correction in every Bash
spelling. The correction is made through `Edit`, where the payload says what it
would do. A reader who finds the Bash half refusing what the Edit half permits
is looking at that asymmetry and not at a defect.

Two consequences of the exception, both accepted. **A heading whose *date*
contradicts the file name is still not correctable** — the exception moves the
session segment only, so that case goes back to correcting forward, and it is
narrow on purpose rather than by oversight. And **the guard permits the
correction whether or not the heading is actually wrong in the way #177 found**,
provided the new segment agrees with the file name and the old one does not: it
judges agreement with the name, which is the property the decision is about, and
not the history of how the disagreement arose.

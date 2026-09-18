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
reason: a history entry that differs from the merge base's copy has been
rewritten, whichever tool did it. The text-level rule that stands in for that
effect in a Bash command is an allowlist of reads and `>>` appends with a
default-deny, not a list of the editors that can overwrite a file.

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
  last case is out of reach of any rule that reads a command's text, so it is
  detected after the fact against the merge base rather than prevented, and
  CLAUDE.md lists it among the consequences left open.

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

## Consequences

The Edit companion permits an existing file that is absent from the merge base,
and still refuses every existing file when the reference cannot be resolved,
following #95. A draft is edited through `Edit`/`Write`; the Bash rule cannot
tell a draft from history without parsing paths out of shell text, which ADR
0002 rejects, so it applies its allowlist to both.

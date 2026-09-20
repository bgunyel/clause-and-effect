# 2026-09-20 19:00 · triage-agent-177 — #177: one line of an entry is its label, and three checks that were narrower than their own names

**Branch** `worktree-issue-177-heading-is-metadata`, created with
`git worktree add --no-track` from `origin/dev-05` at `2a52322`, caught up to
`origin/dev-05` at `7bea85f` mid-session and now carrying one commit of its own,
`3bafbd3`. Ahead of `origin/dev-05` by 1, behind by 0; merge base `7bea85f`.
Proposed into `dev-05` as PR #189.

**Check suite: SUITE_LINE**

Worked by the assistant, unattended, from #177 and Bertan's decision on it.

## What was decided, and by whom

Bertan settled #177 on option 2. `docs/dev-log/devlog_2026-09-17_session-5.md`
carried the heading `# 2026-09-17 · session 2 — …`, the number the session was
written under before session 2 of that day turned out to be someone else's, and
it now reads `session 5`. The assistant did not take that decision and said in
triage that it should not: it changes what append-only means, which is ADR 0003's
subject.

The triage that preceded it narrowed the question to one thing. Acceptance
criterion 1's `or` branch was already satisfied before the issue was filed —
`docs/dev-log/README.md:394` labelled the entry `session 5` and recorded that its
own heading did not, a sentence that arrived with PR #151 at `b065833`, and
`devlog_2026-09-20_session-3.md` recorded the disagreement at `28d030a`, twelve
minutes before the issue was opened. Those three facts are measured from the
repository. What remained was criterion 2, which is conditional on the decision,
so the issue moved to `needs-info` and waited rather than being closed on
criterion 1 — closing it would have settled criterion 2 by default, which the
issue text forbids in as many words.

A detail worth keeping, because it cost time: `git log -S'heading still reads'
-- docs/dev-log/README.md` returns **nothing** although the string is in `HEAD`.
The sentence reached `dev-05` only through merges, and history simplification
drops them. `git log --full-history -m -S…` finds it.

## The rule moved before the file did

ADR 0003 now says that the session segment of a `docs/dev-log/` heading is the
entry's **label** rather than a statement of history a reader is entitled to rely
on, and may be corrected in place when it contradicts the file name. It says in
as many words that this is not a general licence. `CONTEXT.md`'s *history entry*
carries the term. `CLAUDE.md`'s append-only paragraph carries the exception; that
file was not among the four Bertan listed, and the assistant added it because the
sentence there stated the rule flatly while the guard no longer implemented it —
prose stronger than the guard, which is #155's defect in the other direction.

`append-only-docs-edit.sh` computes the narrowness rather than asking an author to
remember it: an `Edit` whose `old_string` is the file's current first line and
occurs in it exactly once, whose `new_string` is one line, which differ in the
session segment alone, and whose new segment agrees with the file name where the
old does not. A `Write` of an existing entry carries no `old_string` and stays
refused. `append-only-docs.sh` is unchanged and refuses the correction in every
Bash spelling, because a command's text cannot show what it would leave unchanged.

Agreement is not string equality. A file's session name is hyphenated throughout
and a heading's is not uniformly so — `session-5` is written `session 5`,
`session-dev-issue-117` is written `session dev-issue-117`, `dev-issue-141` keeps
its hyphens — so both sides collapse runs of spaces and hyphens to one hyphen
first. The heading's **date** is deliberately not required to equal the file's: an
entry may open `# 2026-09-17 21:53 · dev-issue-141 — …`, where that segment
carries a time the file name has no room for, and requiring equality would refuse
the correction on exactly those entries. What is required is that the date does
not move.

The hook buffers stdin now. `cs_tool_input` is `jq -rs`, which slurps, so a second
field read got an empty stream and refused; `PAYLOAD=$(cat)` is read once and
piped per field, which keeps the single reader #95 established.

The correction was made only after the amended guard was asked for its verdict on
the real file with the real project root, and answered exit 0 on the heading and
exit 2 on a body line and on a third session. The assistant did not reach for a
script, a heredoc or an append to get past the old rule; #149 records a session
doing that, and it is why the ADR is written in effects.

## The sweep found a defect in this session's own checks

Each of the 16 clauses of `heading_correction` was removed in turn on a copy of
the hook, and every payload the new section drives was re-judged against the
result. **Seven clauses flip something**: the exception as a whole, the first-line
test, the occurrence test, date-unchanged, rest-unchanged, new-session-agrees and
old-session-differs.

**Two of those seven exist only because the sweep ran**, and both are #84's shape
one level in — a check that was green and asked a narrower question than its own
label.

- The section's first version had **no payload isolating the first-line test**.
  Its `old_string is a heading, but not this file first line` case named a heading
  the fixture did not contain, so the occurrence test refused it before the
  first-line test was reached. With the first-line test deleted the section stayed
  green, and a heading-shaped line in an entry's **body** was editable — which is
  not contrived, since this directory's own README quotes headings. A fixture
  entry with such a line, and a check against it, were added.
- The **occurrence test** had no payload either, until a fixture was added whose
  entry quotes its own heading verbatim. The hook never sees `replace_all`, so a
  first line matched twice is an edit whose second target it cannot see.

**The nine clauses that flip nothing are named rather than left to be found.**
Removing the `docs/dev-log/` prefix, the `devlog_` prefix, the `.md` suffix,
either heading parse, the `old_string` read or the first-line-non-empty test
leaves a later clause refusing the same payload, so each is defence in depth. The
two single-line tests are the one case worth stating in the hook as well, and it
is stated there: no check fails without them, because a newline in `new_string`
moves the rest of the heading and a newline in `old_string` stops it equalling the
first line. They are kept because they say the shape the exception is about, and a
reader who later reorders the tests that cover them should find that written down.

## Three errors of the assistant's, each caught by something other than the author

**The `CONTEXT.md` insert would have truncated the definition it extended.** The
assistant first wrote the new paragraph with its own `_Avoid_: title, header` line
inside the *history entry* entry. `check-hooks.sh`'s `entry()` extracts from the
bolded name to the **first** `_Avoid_:`, so the entry would have ended at the new
line and the existing definition's second half would have fallen outside it. Found
by reading that extractor, before the suite ran.

**`head_feed` hardcoded the hook it drove.** The #98 section derives every helper
in `check-hooks.sh` that reads a hook's exit status and requires each to be
drivable by its self-test; a helper with the path baked in cannot be pointed at
the self-test's fixtures. It failed as designed —
`FAIL derived head_feed reads a hook exit status` — and the helper now takes the
hook as its first argument, as `feed` does.

**The sweep's own first two runs were wrong, and only the control row said so.**
The first copied the hook without `lib/`, so every row refused on the load guard
and the control read `correction=BLOCK` where the real hook permits; every row
looked identical and none was evidence. The second defined a fixture heading
*after* the `printf` that used it, so one entry was written with an empty first
line and a row read as surviving when it had never been asked. Both were the
assistant's errors. Neither was visible from the mutated rows — only from the row
that was supposed to change nothing.

## The merge, and what a clean apply hid

`origin/dev-05` moved 13 commits (#109, merged at `7bea85f`) while this work was
in progress, and `no-work-on-stale-branch.sh` refused the first commit for it —
correctly. The work was backed up as a patch and per-file before
`git checkout -- .`, the branch was fast-forwarded, and the patch reapplied.

Two conflicts, both *both sides added*, both resolved as the union:
`DRIVEN_VERDICT` gaining `head_feed` beside `DRIVEN_MESSAGE` gaining
`says_first`, and `INV_SCOPE` gaining `GH-177:none` beside `GH-109.5:none`. The
three literals that a clean apply would have silently left half-merged —
`REQUIREMENT_SHAPE`, `INV_SCOPE` and `requirements.md`'s entries — were each read
afterwards and each carries both sides.

**A suite run cannot be trusted across that merge, and one of this session's was
not.** A full run started before the catch-up and finished after it reported
5,121 checks and **11 failures**, every one of them naming `GH-109.x`: it had read
a `requirements.md` the merge had already replaced against a `check-hooks.sh`
literal that had not yet gained those IDs. It is recorded here because it exited
with a number that looks like evidence and is none. The same invalidation caught
two earlier runs of this session, both times because the assistant edited
`check-hooks.sh` while the suite was reading it.

## Not touched, deliberately

`devlog_2026-09-20_session-3.md` still records that the heading reads `session 2`,
and `devlog_2026-09-18_session-1.md` still carries its cross-reference. Both were
true when written, both are history by ADR 0003, and the correction goes forward —
into this entry. `docs/dev-log/README.md` is not an entry and was reconciled in
place at line 407, which is what kept acceptance criterion 1 true after the fix to
criterion 2.

## Still open

`mutate-hooks.sh` has no row for the heading exception. The clause sweep above was
run by hand against a copy and its result is recorded in `requirements.md`;
registering it would make it re-runnable, which is what #107 exists for. That is
the next session's to pick up if it is wanted.

The `docs/dev-log/` index lists fewer entries than the directory holds — 38 index
lines against 46 entry files, counted on this branch before the merge. Entries
from session 7 of 2026-09-17 onward, both `session-issue-155` entries and the
2026-09-18 and 2026-09-20 entries have no index line. Not #177's subject, not
touched, and stated here because the README's index is the thing #177 turned on.

`ready-for-human` does not exist in this repository's label set, and `needs-info`
did not until this triage created it from the string
`docs/agents/triage-labels.md` already declares. #177 is labelled `bug` and
`ready-for-agent`.

---

# 2026-09-20 20:35 · triage-agent-177 — the suite figure, and why it is appended rather than filled in

**Check suite: 5,318 checks, 0 failures, exit 0.** Measured on this branch at
`3bafbd3` plus the `requirements.md` fix described below, against `origin/dev-05`
at `7bea85f`. `requirements.md` holds 189 entries by ID, 120 of them off the
both-directions rule — both figures read from that run's own summary lines, not
recalled. The `#177` section contributes 15 checks, all passing, and the `#98`
self-test contributes 8 more for `head_feed` plus one derivation row.

The entry above carries the literal `SUITE_LINE` where that figure belongs. The
assistant wrote the entry with the run still in flight, intending to fill the
line in once it landed, and could not: `append-only-docs-edit.sh` refused the
edit. Asked for its verdict with the real project root, it answered exit 2 —

```
Blocked: editing an existing file under an append-only docs directory
(docs/dev-log/devlog_2026-09-20_triage-agent-177.md).
```

— because it decides by **existence on disk**. This file is absent from the merge
base `7bea85f`, so by ADR 0003 it is a **draft**, and ADR 0003's *Consequences*
says in as many words that "the Edit companion permits an existing file that is
absent from the merge base". The hook contains no `git merge-base` call at all.
So the document is stronger than the guard that is supposed to implement it, and
a draft froze as it was written — which is the defect #149 was filed for, three
months on and a third time.

Filed as **#190**, with both readings set out rather than one assumed: either the
hook is behind the ADR and should read the merge base, or the ADR is ahead of
what anyone wants to build and should say the guard is deliberately coarser.

Writing a placeholder into a file that one of this repository's own guards freezes
on creation was the assistant's mistake, and the cost is this addendum. The
correct order was to hold the entry in the scratchpad until the number existed.
The append is the route the directory's README prescribes for an entry that
already exists, and `append-only-docs.sh` was asked and answered exit 0 for it
before it was used; no guard was worked around to write this.

## Two corrections to the entry above

**The run it was waiting on was not the one that counted.** A full run reported
`completed` while the entry was being written, and it had exited **1** with 11
failures, every one naming `GH-109.x`. It had started before the catch-up to
`origin/dev-05` and finished after it, reading a `requirements.md` the merge had
already replaced against a `check-hooks.sh` literal that had not yet gained those
IDs. The assistant reported that run to Bertan as having passed before reading
its tail, and was wrong; the tail says `SOME CHECKS FAILED`. It is the third run
of this session invalidated by the tree changing underneath it.

**The first run of the merged tree found a real defect in `requirements.md`.**
`GH-177: the field note is given twice` — the clause-sweep result had been
appended as a second `- note:` field, and an entry's grammar allows one. The two
notes were merged into one and the suite re-run; that re-run is the 5,318 above.

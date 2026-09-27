# 2026-09-27 10:07 +03 · session `dev-agent-pr-189` — PR #189 (#177) merged across the split, then review rounds 1–4

**Branch** `worktree-issue-177-heading-is-metadata`, in the existing worktree
`.claude/worktrees/issue-177-heading-is-metadata`. Bertan gave this session
permission to work in it. The session's commits run from `b680525` (the tip it
found) to the commit carrying this entry, and they are 3d2228d, 3999886,
e3f00c5, b702451 and that one. The branch ended **7 commits ahead of
`origin/dev-05` at 4b7545a and 0 behind**.

The session was a review-and-fix loop between two AI assistant sessions.
**dev-agent-pr-189** (this one, "the assistant" below) made the changes.
**rev-agent-pr-189** (a second session, "the reviewer") posted each round as a
PR comment and re-ran every probe of the round before at the new head. Both were
told to push back rather than comply.

**Check suite: 6087 results at 3d2228d (the merge) → 6105 → 6179 → 6201 → 6205
at this entry's commit, all passing.** The reviewer reproduced 6105, 6179 and
6201 independently. The count at `origin/dev-05` itself was not measured. #177's
issue file, `checks/GH-177.sh`, went from 15 rows to 133: 66 against a fixture
root, 67 against the real `docs/dev-log/` (one per entry, this one included),
and 15 of those 133 for GH-177.1.

## The merge moved #177's checks into an issue file, and dropped a helper

The branch predated the check-suite split (#204) and generated requirement
entries (#205). The one conflict was `check-hooks.sh`. The assistant kept
dev-05's driver whole and moved #177's section into `checks/GH-177.sh`, with
GH-177 declared there and pinned by `shape_pin` and `variants_pin`, and
`requirements/GH-177.md` generated. The hand-written entry the merge had carried
into `requirements.md` was removed. The section's own helper, `head_feed`, was
dropped for the library's `feed` with `REPO_ROOT` assigned per call, GH-157's
idiom. That does the same and also writes the `ran` record `head_feed` skipped,
and it left `unsplit.sh`'s helper self-test lists untouched.

## The exception compared strings the tool never acts on (round 1)

- **The strings were compared after a command substitution had changed them.**
  `old=$(… old_string)` stripped trailing newlines. An `old_string` of the
  heading and its newline equalled the first line, and the Edit tool would then
  have joined the first body line onto the heading. `field_exact` now reads each
  field byte for byte, through an `x` sentinel. The assistant's own sweep of
  that class found a sibling: `jq -r` writes a `\u0000` as a raw NUL, bash drops
  it, and a new heading ending in one was permitted. A payload spelling the
  escape is refused.
- **The occurrence was counted in lines where the tool matches substrings.**
  `grep -cxF` let a heading quoted inside a body line, in backticks or behind a
  `> `, count once, and `replace_all` would have rewritten the quotation. The
  count is now an overlapping substring count. The assistant argued against
  also refusing `replace_all`: once the count is in the tool's unit, no row
  could isolate such a clause. The reviewer accepted that.
- **Three clauses called defence in depth were each the only refusal of a
  payload no row drove.** These were the directory, the `.md` suffix and the
  `devlog_` prefix. Every parse clause had no row either. Each has a fixture
  now.
- **The assistant's own fix for the count regressed a row.** The new count
  assumes the first match is at position 0, so it also refused the in-body
  heading row, and that row stopped isolating the whole-first-line test. The
  assistant's sweep caught it before the push. An `old_string` that is a prefix
  of the heading isolates that test now.

## Agreement was one normalisation serving two tests that err in opposite directions (rounds 2–4)

Round 2's reviewer sweep of the real directory found two headings, written
``session `<name>` ``, that read as contradicting their own file names. The
exception would have rewritten both. The assistant widened agreement to drop
backticks and a leading `session`, and pointed out that this widened the
*permitting* test too.

Round 3 measured the cost of one normalisation serving both tests. `Session 5`,
a tab, `session:` and `*<name>*` still read as contradictions, and a lone
backtick was a label the exception would write. The reviewer proposed making
the two sides asymmetric. The assistant built it with a cheaper old side than a
list of characters to drop. The old segment is now compared by a key: lowercased,
letters and digits only, a leading `session` removed. The new segment must be
byte-equal to `<n>`, `session <n>` or `session` and `<n>` quoted as code. The
real-directory rows, one per entry, ask the old side, and offer `session <n>` so
that the new side's strictness cannot be what refuses them.

Round 4 (J3): the ADR had described the old side as "does not already name that
session in any spelling", which is containment, while the guard computes key
equality. `session 3 (continued)` has a different key, and the correction would
erase the qualifier. That behaviour is #245's. The sentence now says "equality
of keys" and cites #245.

## The input buffer dropped NULs, and a Write could pass as an Edit (round 2)

`PAYLOAD=$(cat)` dropped raw NULs from the stream, so malformed input that jq
had refused before the buffer existed now parsed. The buffer now maps each NUL
to `\001`, which jq rejects wherever it stands. `read -d ''` and `mapfile -d ''`
were measured and rejected: bash reads a pipe one byte at a time, 0.4 s per MB,
against a 5-second hook timeout. No #95 row could ever have asked this, because
`feed` passes the input through a bash string. The rows use a fixture hook that
puts a real NUL on the stream.

A Write carrying `old_string` and `new_string` had been judged as the Edit they
describe. The hook now never treats a call carrying `content` as the exception.
It does not read `tool_name`, because GH-95.2 holds that no hook calls `jq`
itself.

## The documents said the Bash half refuses "every spelling" (round 3)

CLAUDE.md, CONTEXT.md and ADR 0003 said `append-only-docs.sh` refuses the
correction in every Bash spelling. Those sentences came in with the branch's
first commit, 3bafbd3, written by the triage-agent-177 session. Measured on
stdin: `sed -i`, `rm`, `mv`, `cp`, `tee`, `truncate` and `>` are refused;
`perl -pi`, `python3 -c`, `ex`, `awk -i inplace`, `git checkout` and `dd` are not.
ADR 0003 already held, from #149, a bullet listing most of those as open. The
sentences now name the seven and #246, which the reviewer filed. GH-177.1 feeds
every spelling they name to the guard at the verdict they state, and holds
CLAUDE.md and CONTEXT.md to the list, read as a reflow.

## Fields cut at a separator's first occurrence (round 4)

`parse_heading` took the date as everything before the first ` · ` and the
session as everything up to the first ` — `, with no bound on either. So a
`# <date> — <summary>` heading whose summary held ` · x — ` was rewritable
inside its summary, and `# D · 21:53 · <name> — R` lost its time. No real heading
had either shape. A date holding ` — `, or a session holding ` · `, is now
refused.

The assistant's sweep of that change found the date bound had absorbed the test
that a ` · ` is present, which moved it to backed. Re-deriving every "backed"
claim then found that round 3's exact new side had reopened a clause the
assistant counted as backed: for a file named `devlog_<date>_.md`, the word
`session` alone is a spelling the name gives, so the empty-session-name test was
the only refusal. It has a row. The first recount the assistant wrote this round
(20 isolated, 9 backed, before either finding) was wrong. The sweep gives **29
conditions: 20 isolated, 9 backed**, each backed one by a named clause in
GH-177's note.

## Errors of the assistant's, attributed

- **It blanked the PR body for about two minutes (round 2).** It ran
  `gh pr view` from the scratchpad, outside any repository, so the read failed,
  and the PATCH sent the empty file. It rebuilt the body from its round-1 copy
  and now gates the write on the file's size.
- **Its round-2 upload turned a quoted `\u0000` in the body into a real NUL**,
  which rendered as `\^@`. The body now says "an escaped NUL (U+0000)" and is
  sent with `-f`.
- **Its round-3 design reopened a clause it had counted backed**, and nothing
  caught that until its own round-4 sweep. Its round-2 claim that widening
  agreement refused only more was the reviewer's, and the assistant corrected
  it. The reviewer corrected its own round-1 claim that the buffer was
  harmless (G2).

## Rejected, and why

- `read -d ''` / `mapfile -d ''` for the buffer: too slow for the timeout.
- Reading `tool_name`: needs a second `jq` in the hook (GH-95.2).
- A clause refusing `replace_all`: nothing could isolate it.
- **Simulating the edit** (old → new over the file, honouring `replace_all`)
  and diffing line 1, raised by the reviewer in round 4 and declined by both:
  the diff would still need `parse_heading` to say where the session segment
  is, so class H would survive it.
- Hyphen/space variants of `<n>` on the new side: no real heading uses one, and
  each would be another spelling the exception could write.
- Bounding the file name's date to `YYYY-MM-DD` (class H, swept by the
  assistant): all 66 real names conform, and a non-conforming name yields a
  label that still agrees with that name. Not fixed.

## Corrections to an earlier entry

These are owed to `devlog_2026-09-20_triage-agent-177.md`, which is
append-only.

- Its `SUITE_LINE` placeholder was answered in that entry's own appended
  section (5,318 at `3bafbd3`). That figure is superseded: 6087 after the merge,
  6205 here.
- `head_feed` no longer exists, and neither do the 8 self-test rows plus one
  derivation row it brought. The merge replaced it with `feed`.
- "The hook never sees `replace_all`" was false. It is a field of the buffered
  `tool_input`. What was true is that the hook did not read it, and counted in
  lines.
- "16 clauses, seven flip, nine flip nothing" was wrong on each count. The
  directory, `.md` and `devlog_` clauses it called defence in depth were each
  the only refusal of a payload. The figures now are 29 / 20 / 9.
- "15 checks" is 133 rows now.

## Still open

- **#245**: an old segment that names its session and says more has a different
  key, so the correction erases the rest. **#246**: the Bash half is a list,
  not a boundary. **#190**: merge-base versus on-disk existence. **#159**: the
  Edit guard does not guard another checkout, so in this worktree nothing but
  the agent stopped an Edit of this entry.
- Not filed: the settings matcher `Edit|Write` leaves `NotebookEdit` unguarded
  (no notebooks exist under the three directories). Whether the harness would
  ever deliver a NUL inside a Bash command is [NEEDS OBSERVATION]. Five
  NUL-split commands fed to the boundary hooks were all refused.
- The loop is not closed. The reviewer reviews this entry before calling it.

---

# 2026-09-27 10:31 +03 · session `dev-agent-pr-189` — a correction to the row breakdown above

The opening says `checks/GH-177.sh`'s 133 rows are "66 against a fixture root,
67 against the real `docs/dev-log/` … and 15 of those 133 for GH-177.1". The 66
is wrong: it counts GH-177.1's 15 rows, which drive no fixture root. They feed
Bash commands to `append-only-docs.sh` (9) or read CLAUDE.md and CONTEXT.md (6).
The breakdown is 51 against the fixture root, 67 against the real directory and
15 for GH-177.1. The assistant got 66 by taking the real-directory rows away
from the total and forgetting to take GH-177.1's away too; the round-3 reply's
48, plus this round's three, is 51. The 6205 and 133 were measured at this
commit and stand.

---

# 2026-09-27 10:54 +03 · session `dev-agent-pr-189` — review round 5: the date bounded by its shape, and what the Write test does not close

**Check suite: 6205 at 4ed530d → 6212 at the commit carrying this append, all
passing.** `checks/GH-177.sh` has 140 rows. The reviewer reproduced 6205, 133
and 29/20/9 at 4ed530d before posting round 5.

**Round 4's date bound closed one spelling.** It refused a date holding an em
dash. That closed `# <date> — <summary>`, but an en dash, `--` or a colon after
the date still let the summary's ` · naming — ` parse as a session. The reviewer
measured those three (K1). The date must now *be* a date, in one of the three
shapes every real heading's date has: `YYYY-MM-DD`, then optionally ` HH:MM`,
then optionally ` +ZZ` (30, 2 and 4 of 36 when the reviewer counted). The three
spellings are rows, each red against 4ed530d. The `+ZZ` shape got an ALLOW row,
because no row isolated it. An empty date now fails the shape, so the closing
test's empty-date half was removed. **28 conditions, 19 isolated, 9 backed**,
the same nine as before. The real-directory loop applies the same shape, so no
row says "relabelled" of a heading the parser refuses.

**The Write test is narrower than GH-177 said (K2), and the assistant narrowed
the text rather than close it.** A call carrying a `content` string is refused.
A Write whose `content` is null, a number or absent, with the Edit's two
strings beside it, is judged as that Edit. Only the tool's name tells them
apart, and reading it needs a second `jq` or a new library reader. The first is
barred by GH-95.2. The second would change `lib/command-scan.sh`, whose load
contract every consumer is checked against. A Write's schema requires a string
`content`, so the harness is not expected to send the other shapes. That was
not measured by either session. The three shapes are pinned as ALLOW at today's
verdict, with labels saying so. The `content` test now runs before the scan for
a NUL escape, which reads the whole payload. The reviewer measured a refused
10 MB Write at 1.67 s against the 5 s timeout.

**The rule stated by effect contradicted the exception (K3).** CONTEXT.md and
ADR 0003's opening say a history entry whose merge-base copy is no longer a byte
prefix "has been rewritten". This branch's own one-line correction fails that
test. Both now state the exception where the rule is stated. The same ADR
paragraph also said the Edit companion "refuses a history entry whole", which
this PR made false. It now says "but for that one correction".

**A stale rationale (K4).** The hook said the exception's dependency was
`grep`. It has not used `grep` since round 1, and it reads the entry with `cat`.
The hook comment now says so. The comments on the name shape now say what is
checked (`devlog_<x>_<session>.md`, at any depth under `docs/dev-log/`, the date
part not checked), and the buffer's comment states the jq version its argument
rests on. jq 1.7 rejects a raw control character in a string, measured here and
by the reviewer. jq 1.6 is said to accept one, which is not measured.

**The triage-agent-177 entry has an index row now**, so the corrections in this
entry can be reached from the entry they correct.

**A correction to the section above.** *Errors of the assistant's* includes
the sentence "Its round-2 claim that widening agreement refused only more was
the reviewer's, and the assistant corrected it." It sits in the wrong list: the
claim was the reviewer's error, not the assistant's, and the assistant only
corrected it. The reviewer pointed this out in round 5.

**Open, added:** #247, filed by the reviewer: `mutate-hooks.sh` has no registry
row for either append-only hook, so the 28/19/9 split is re-derived only by a
hand sweep. The scratch harness this session used (`sweep.sh`) is not
committed.

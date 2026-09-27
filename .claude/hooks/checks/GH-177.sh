#!/bin/bash
# THE ISSUE FILE OF #177: the session segment of a dev-log heading, when it
# contradicts the session the file is named for, is the entry's label and not
# its history, and append-only-docs-edit.sh permits that one correction.
#
# ADR 0003 decides that one part of one line of a history entry is the entry's
# label rather than its history: the session segment of a docs/dev-log/ heading,
# when it contradicts the session the file is named for. The hook permits that
# one correction and refuses everything else about an existing entry, as before.
#
# Most of these drive a project root of their own. The reason is the branch that
# adds them: after it, docs/dev-log/ holds no entry whose heading contradicts its
# file name -- that is what the branch fixes -- so there is nothing here to ask
# the permitting question of. A fixture root also reaches the shapes this
# repository will never hold: a heading corrected to a third session, a whole
# entry rewritten by Write, a second line smuggled into the replacement.
# The branch first went further and said the REFUSING cases would have no
# subject here either, so no row asked the real directory anything. That was
# false by the hook's own test: two real headings, naming their session as code,
# read as contradicting their names and were relabel-able (review of #189, round
# 2). So the real directory is asked too, every entry of it, in the refusing
# direction, below. The refusing cases against real files under GH-69.3 stay in
# the unsplit file.
#
# Each row runs through `feed`, with REPO_ROOT assigned for that call alone so
# the hook reads the fixture root as its project directory -- the idiom
# GH-157's issue file uses. The branch first carried a helper of its own,
# `head_feed`, written before the split, that did the same and skipped the
# `ran` record `feed` keeps; the port onto the split suite (the merge of
# dev-05 at #184) replaced it rather than register a second helper for one
# spelling.

section "=== #177: the session segment of a dev-log heading, corrected onto its file name ==="

requirement GH-177 <<'REQ'
- text: `append-only-docs-edit.sh` permits exactly one edit to a history entry, and
  refuses every other one as it did. The permitted edit is an `Edit` -- a call
  carrying no `content`, which every `Write` carries -- of a
  `docs/dev-log/` entry named `devlog_<date>_<session>.md`, whose `old_string` is
  the file's current first line and occurs in the file exactly once, counted as the
  Edit tool matches it -- a substring anywhere, overlapping, so `replace_all` has
  nothing to widen -- whose `new_string` is a single line, which parse as
  `# <date> · <session> — <rest>` with a date and a session that are not empty and
  are byte-identical in date and rest, and whose new session segment is one of
  the three spellings the file name gives where the old segment does not already
  name that session. Both strings
  are compared exactly as the tool call carries them, trailing newlines included,
  and a tool call spelling a NUL (`\u0000`) is refused, since a bash string cannot
  hold one. The two session tests are asked differently. The old segment names
  the file's session when their keys match -- each lowercased, reduced to its
  letters and digits, and less a leading `session` -- so `Session 5`,
  `session: 5` and `*5*` all name `session-5`, and ``session `clause-and-effect-37` ``
  names `clause-and-effect-37`. The new segment must be byte-equal to `<n>`,
  `session <n>` or `session` and `<n>` quoted as code, with `<n>` the file's
  session less a leading `session-`, so a lone backtick or a name in hyphens is
  never written. Every real entry's heading, relabelled onto `session <n>`, is
  refused. A
  `Write` of an existing entry is refused, whatever else it carries; so is a body edit, a rest
  or date that moves with the session, a new segment agreeing with nothing, an
  `old_string` that is not the whole first line, a trailing newline on either
  string, a second line smuggled into `new_string`, a heading that already agrees,
  a heading quoted again anywhere in the entry, and the same shape under
  `docs/lessons-learned/` or `docs/eval-reports/`, on a file that is not `.md`, or
  on one not named `devlog_`.
- from: #177, deciding what ADR 0003 left open, and ADR 0003 as amended
- kind: defect-refusing
- status: active
- variants: none: the hook reads a file path and two strings out of an Edit, not a
  command, so there is no command spelling to vary
- note: the heading's date segment is deliberately not required to equal the file
  name's date. An entry may open `# 2026-09-17 21:53 · dev-issue-141 — …`, where
  that segment carries a time the file name has no room for, and requiring equality
  would refuse the correction on exactly those entries. What is required is that the
  segment does not move, which is what holds the exception to one part of one line.
  The permitting checks drive a fixture root rather than this repository, for the
  reason the section says: after this branch `docs/dev-log/` holds no entry whose
  heading contradicts its name, which is the branch's point, so the permitting
  direction has no subject here. The refusing direction does, and every real entry
  is asked it: its heading relabelled onto its own file's session is refused. The
  branch first said that direction had no subject either, and two real headings,
  which name their session as code, were relabel-able until agreement dropped
  backticks and a leading `session` word (review of #189, round 2).
  WHAT THE SECTION IS EVIDENCE ABOUT, MEASURED RATHER THAN ASSUMED. The
  exception was swept a clause at a time, in review of #189's first and second
  rounds and after it: each of its 29 refusing conditions -- 27 `return 1`
  clauses across `heading_correction`, `parse_heading` and `canonical_session`,
  and the two halves of `parse_heading`'s closing test -- removed on a copy, and
  every row of this section re-judged against the result. Twenty have a row
  that turns red when they are removed, and so do the call site, each step of
  the old side's key, each of the new side's three spellings, and the pinned
  sentence of the refusal: the directory, the `.md` suffix, the `devlog_`
  prefix, the empty-session-name test, the NUL refusal, the `Write` exclusion,
  the whole-first-line test, the count, `canonical_session`'s refusal, the two
  field bounds of `parse_heading`, the parse of `old_string`, the `#` and ` — `
  tests, the empty date and the empty session, date-unchanged, rest-unchanged,
  new-session-agrees and old-session-differs. Nine turn nothing red, and each is
  backed by a named clause rather than dead: the ` · ` test by the date bound
  and the ` — ` test together; the `_` in the name by the empty-session-name
  test; the `old_string`
  read by the whole-first-line test, and the `new_string` read by the parse of
  `new_string`, which is backed in turn by new-session-agrees and
  old-session-differs, because a parse that fails leaves `old_string`'s session in
  place and the two cannot both hold of one session; the two single-line tests,
  by the first-line and date, rest and session tests, as the hook says beside
  them; the empty-first-line test by the whole-first-line test; and the file's
  read, by nothing but the race of a file readable by `read` and not by `cat`.
  The empty-session-name test was on that list until round 4, backed by
  new-session-agrees because a session that is not empty never normalised to
  empty; round 3's exact new side broke that without a row noticing, since for a
  file named `devlog_<date>_.md` the word `session` alone is a spelling the name
  gives. It has its row now.
  WHAT THE FIRST SWEEP GOT WRONG. The branch's first sweep counted 16 conditions
  and seven that flip, and called the directory, `.md` and `devlog_` clauses
  defence in depth. Each was the only thing refusing a payload no row drove, and
  the lessons-learned row that seemed to drive the directory was refused by its
  `lesson_` name first; and the parse clauses had no rows at all. Worse, the
  strings were read through a command substitution, which strips trailing
  newlines, and the occurrence was counted in whole lines, so an `old_string` of
  the heading and its newline, and a heading quoted inside a body line under
  `replace_all`, were permitted with every row green. Both are the shape #84 is
  about, one level in: the check existed, was green, and asked a narrower
  question than its own label.
REQ
requirement GH-177.1 <<'REQ'
- text: `CLAUDE.md`, `CONTEXT.md` and ADR 0003 say which Bash spellings
  `append-only-docs.sh` refuses on an existing entry, and so refuses for the
  heading correction too -- `sed -i`, `rm`, `mv`, `cp`, `tee`, `truncate` and a
  `>` -- and that an interpreter or another in-place editor, `perl -pi` or
  `python3 -c` among them, is not refused at all, naming #246; and not that the
  correction is refused in every Bash spelling. Every spelling they name is fed
  to the guard at the verdict they state. `CLAUDE.md`'s paragraph and
  `CONTEXT.md` are read as a reflow and hold the list and the pointer to #246,
  and lack the claim.
- from: #177, and review of #189, round 3
- kind: doc-claim
- status: active
- note: The permitted rows are #246's gap and not this requirement's: this is what
  the documents say, and they say those spellings are permitted today, so ALLOW
  is its right verdict, for the reason GH-157.3 gives for #159's rows. When #246
  closes them the rows go red, and the documents are what changes with them. ADR
  0003 is not read, because this suite's header names every document the suite
  reads and does not name it; its sentence is held by review. The documents
  first said "every Bash spelling", which review measured false on five
  spellings: the #84 shape, in prose about a sibling guard.
REQ
shape_pin 'GH-177 GH-177.1'
variants_pin 'GH-177:none'

HEAD_FIX="$FIXTURES/heading-fixture"
mkdir -p "$HEAD_FIX/docs/dev-log" "$HEAD_FIX/docs/lessons-learned"
# Written as literals, not derived from the entries this repository holds:
# a check that read the real heading would stop asking the question the moment
# the heading was corrected, which is the defect that produced this section.
H_WRONG='# 2026-09-17 · session 2 — #128: a continued heredoc opener hid the command after its terminator'
H_RIGHT='# 2026-09-17 · session 5 — #128: a continued heredoc opener hid the command after its terminator'
H_OTHER='# 2026-09-17 · session 2 — the boundary was written in a command spelling'
H_TIMED='# 2026-09-17 21:53 · dev-issue-140 — #141: which requirements the invariance families seed'
H_TIMEDOK='# 2026-09-17 21:53 · dev-issue-141 — #141: which requirements the invariance families seed'
# The body carries a heading-shaped line of its own. That is not contrived: an
# entry that discusses another entry quotes its heading, and this repository's
# own dev-log README does exactly that. It is the only payload that isolates the
# first-line test -- with that test gone, every other clause still passes on this
# line, and the guard edits a line of the body. Found by hand-mutating the hook,
# not by this suite, which had no such payload when it was first written.
H_INBODY='# 2026-09-17 · session 4 — a heading this entry quotes in its body'
printf '%s\n\nBody line one.\n%s\nBody line two.\n' "$H_WRONG" "$H_INBODY" \
  > "$HEAD_FIX/docs/dev-log/devlog_2026-09-17_session-5.md"
printf '%s\n\nBody.\n' "$H_OTHER" \
  > "$HEAD_FIX/docs/dev-log/devlog_2026-09-17_session-2.md"
printf '%s\n\nBody.\n' "$H_TIMED" \
  > "$HEAD_FIX/docs/dev-log/devlog_2026-09-17_dev-issue-141.md"
# An entry that quotes its OWN heading in its body, so the first line occurs
# twice. `old == first line` passes on it, and the occurrence test is the only
# thing left. Named because the clause sweep found this the one clause with no
# payload of its own. This comment first said the hook "never sees
# `replace_all`", and that was false: it is a field of the tool_input the hook
# buffers. What was true is that the hook did not read it, and counted in lines
# where the tool matches substrings, so a quotation of the heading inside a body
# line counted for nothing and `replace_all` rewrote it (review of #189, round
# 1). The count is now in the tool's unit, and the quotations are fixtures below.
printf '%s\n\nAs its own heading says:\n%s\n' "$H_WRONG" "$H_WRONG" \
  > "$HEAD_FIX/docs/dev-log/devlog_2026-09-17_session-3.md"
printf '# Dev Log\n\nindex\n' > "$HEAD_FIX/docs/dev-log/README.md"
printf '%s\n\nBody.\n' "$H_WRONG" \
  > "$HEAD_FIX/docs/lessons-learned/lesson_2026-09-17_session-5.md"
# The same heading quoted INSIDE a body line, twice over: in backticks, and
# behind a Markdown quote marker. Neither line equals the heading, so a count of
# whole lines found one occurrence in each file; the Edit tool finds two.
printf '%s\n\nThe heading read `%s` before.\n' "$H_WRONG" "$H_WRONG" \
  > "$HEAD_FIX/docs/dev-log/devlog_inline_session-5.md"
printf '%s\n\n> %s\n' "$H_WRONG" "$H_WRONG" \
  > "$HEAD_FIX/docs/dev-log/devlog_quoted_session-5.md"
# THE FILE-NAME CLAUSES, EACH GIVEN A FILE ONLY IT REFUSES (review of #189,
# round 1). A heading correction on an entry named for session-5, where the one
# thing wrong is the directory, the extension or the prefix. The first version
# of this section drove the lessons-learned case with a `lesson_` name, which
# the `devlog_` clause refuses before the directory is asked, so deleting the
# directory clause left every row green.
mkdir -p "$HEAD_FIX/docs/eval-reports"
for f in docs/lessons-learned/devlog_2026-09-17_session-5.md \
         docs/eval-reports/devlog_2026-09-17_session-5.md \
         docs/dev-log/devlog_2026-09-17_session-5.txt \
         docs/dev-log/notes_2026-09-17_session-5.md; do
  printf '%s\n\nBody.\n' "$H_WRONG" > "$HEAD_FIX/$f"
done
# THE HEADING-SHAPE CLAUSES, likewise: a first line that is almost a heading,
# each file named for session-5 so that the session test would pass. Found by
# the author's sweep of the same round, which removed each clause of
# `parse_heading` and of its two call sites in turn: every one flipped no row
# above, and each had a payload that only it refused. One no longer does: since
# round 4 bounds the date, a first line with no ` · ` parses its whole body as
# the date, which the date bound refuses when it holds a ` — ` and the session
# test refuses when it does not. The `nodot` row below is refused by both, and
# the ` · ` test is backed rather than isolated.
printf '%s\n\nBody.\n' '2026-09-17 · session 2 — R' \
  > "$HEAD_FIX/docs/dev-log/devlog_nohash_session-5.md"
printf '%s\n\nBody.\n' '# 2026-09-17 — R' \
  > "$HEAD_FIX/docs/dev-log/devlog_nodot_session-5.md"
printf '%s\n\nBody.\n' '# 2026-09-17 · session 2' \
  > "$HEAD_FIX/docs/dev-log/devlog_nodash_session-5.md"
printf '%s\n\nBody.\n' '#  · session 2 — R' \
  > "$HEAD_FIX/docs/dev-log/devlog_nodate_session-5.md"
printf '%s\n\nBody.\n' '# 2026-09-17 ·  — R' \
  > "$HEAD_FIX/docs/dev-log/devlog_nosess_session-5.md"

head_edit() {  # head_edit <path> <old> <new>
  jq -cn --arg p "$1" --arg o "$2" --arg n "$3" \
    '{tool_name:"Edit",tool_input:{file_path:$p,old_string:$o,new_string:$n}}'
}
head_edit_all() {  # head_edit_all <path> <old> <new> -- the same, with replace_all
  jq -cn --arg p "$1" --arg o "$2" --arg n "$3" \
    '{tool_name:"Edit",tool_input:{file_path:$p,old_string:$o,new_string:$n,replace_all:true}}'
}
head_write() {  # head_write <path> <content>
  jq -cn --arg p "$1" --arg c "$2" \
    '{tool_name:"Write",tool_input:{file_path:$p,content:$c}}'
}
E_WRONG="$HEAD_FIX/docs/dev-log/devlog_2026-09-17_session-5.md"
E_OTHER="$HEAD_FIX/docs/dev-log/devlog_2026-09-17_session-2.md"
E_TIMED="$HEAD_FIX/docs/dev-log/devlog_2026-09-17_dev-issue-141.md"

req GH-177
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh ALLOW 'the correction itself: session 2 becomes session 5 on the file named session-5' \
  "$(head_edit "$E_WRONG" "$H_WRONG" "$H_RIGHT")"
# The date segment may carry a time the file name has no room for, so agreement
# is asked of the session and never of the date. This entry is why the hook does
# not simply compare the heading's date with the file's.
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh ALLOW 'the same, where the date segment carries a time the file name lacks' \
  "$(head_edit "$E_TIMED" "$H_TIMED" "$H_TIMEDOK")"

# Everything the exception is bounded by. Each of these was ALLOW under a guard
# that asked only "does the file name disagree with the heading", which was the
# cheap way to implement the same decision and hands over the whole file.
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'an ordinary body edit of the entry whose heading is wrong' \
  "$(head_edit "$E_WRONG" 'Body line one.' 'Body line ONE.')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a new session agreeing with neither heading nor file name' \
  "$(head_edit "$E_WRONG" "$H_WRONG" '# 2026-09-17 · session 9 — #128: a continued heredoc opener hid the command after its terminator')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'the rest of the heading moved along with the session' \
  "$(head_edit "$E_WRONG" "$H_WRONG" '# 2026-09-17 · session 5 — #128: a rewritten summary')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'the date moved along with the session' \
  "$(head_edit "$E_WRONG" "$H_WRONG" '# 2026-09-18 · session 5 — #128: a continued heredoc opener hid the command after its terminator')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'old_string is a heading, but not this file first line' \
  "$(head_edit "$E_WRONG" "$H_OTHER" "$H_RIGHT")"
# The one above names a heading the file does not hold at all, so the first-line
# test refuses it and so does the count, which finds it nowhere. This one names
# a line the file really holds, in its body, and corrects it exactly as the
# exception would correct a real heading. When the count was of whole lines, only
# the first-line test stood between it and a permitted edit to the body of a
# history entry. The count now asks for no match after the file's first
# character, which assumes the first-line test has passed, so it refuses this
# row too, and the row no longer isolates anything (the author's sweep in
# #189's first round, which found it).
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a heading-shaped line the file holds, but in its body rather than line 1' \
  "$(head_edit "$E_WRONG" "$H_INBODY" "${H_INBODY/session 4/session 5}")"
# What the first-line test alone refuses now: an old_string that is a PREFIX of
# the first line, so its one match is at the file's start and the count passes.
# The edit it would make changes only the session, so the verdict holds the
# exception to its stated shape -- the whole first line -- and not to its effect.
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'old_string is a prefix of the first line, not the whole of it' \
  "$(head_edit "$E_WRONG" "${H_WRONG%%: a continued*}" "${H_RIGHT%%: a continued*}")"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a second line smuggled into new_string behind a correct heading' \
  "$(head_edit "$E_WRONG" "$H_WRONG" "$H_RIGHT"$'\nand a line the entry never had')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a Write of the whole entry, its heading corrected and all' \
  "$(head_write "$E_WRONG" "$H_RIGHT"$'\n\nBody line one.\nBody line two.\n')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a heading that already agrees with its file name, so nothing to correct' \
  "$(head_edit "$E_OTHER" "$H_OTHER" "$H_OTHER")"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'the first line is correct, but the entry quotes it again in its body' \
  "$(head_edit "$HEAD_FIX/docs/dev-log/devlog_2026-09-17_session-3.md" "$H_WRONG" '# 2026-09-17 · session 3 — #128: a continued heredoc opener hid the command after its terminator')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'the same correction under docs/lessons-learned/, on a file named as that directory names them' \
  "$(head_edit "$HEAD_FIX/docs/lessons-learned/lesson_2026-09-17_session-5.md" "$H_WRONG" "$H_RIGHT")"

# CLASS A OF #189's FIRST ROUND: the strings compared are the strings the tool
# acts on. Each of these read, through a command substitution, as the plain
# correction above and was permitted; the tool would then have moved a byte of
# the body or of the heading's rest.
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'old_string is the heading and its newline, so the tool joins the first body line onto it' \
  "$(head_edit "$E_WRONG" "$H_WRONG"$'\n' "$H_RIGHT")"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'old_string is the heading and two newlines, so the tool deletes the blank line under it' \
  "$(head_edit "$E_WRONG" "$H_WRONG"$'\n\n' "$H_RIGHT")"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'new_string is the corrected heading and newlines, so the tool inserts blank lines into the body' \
  "$(head_edit "$E_WRONG" "$H_WRONG" "$H_RIGHT"$'\n\n\n')"
# jq's --arg cannot carry a NUL, so the payload appends one in the program.
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'new_string is the corrected heading and a \u0000, which a bash string drops and the tool writes' \
  "$(jq -cn --arg p "$E_WRONG" --arg o "$H_WRONG" --arg n "$H_RIGHT" \
       '{tool_name:"Edit",tool_input:{file_path:$p,old_string:$o,new_string:($n + "\u0000")}}')"

# CLASS B OF THE SAME ROUND: the occurrence is counted as the tool matches, a
# substring, and `replace_all` -- which widens the edit to every match -- finds
# nothing left to widen.
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'the entry quotes its heading in backticks inside a body line, with replace_all' \
  "$(head_edit_all "$HEAD_FIX/docs/dev-log/devlog_inline_session-5.md" "$H_WRONG" "$H_RIGHT")"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'the entry quotes its heading behind a > marker, with replace_all' \
  "$(head_edit_all "$HEAD_FIX/docs/dev-log/devlog_quoted_session-5.md" "$H_WRONG" "$H_RIGHT")"

# CLASS C: each clause that reads the file's name, with the file only it refuses.
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a devlog_-named entry under docs/lessons-learned/, refused for its directory' \
  "$(head_edit "$HEAD_FIX/docs/lessons-learned/devlog_2026-09-17_session-5.md" "$H_WRONG" "$H_RIGHT")"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a devlog_-named entry under docs/eval-reports/, refused for its directory' \
  "$(head_edit "$HEAD_FIX/docs/eval-reports/devlog_2026-09-17_session-5.md" "$H_WRONG" "$H_RIGHT")"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a dev-log file that is not .md, its session corrected onto its whole name' \
  "$(head_edit "$HEAD_FIX/docs/dev-log/devlog_2026-09-17_session-5.txt" "$H_WRONG" "${H_WRONG/session 2/session 5.txt}")"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a dev-log file not named devlog_, its session corrected onto what follows its prefix' \
  "$(head_edit "$HEAD_FIX/docs/dev-log/notes_2026-09-17_session-5.md" "$H_WRONG" "${H_WRONG/session 2/2026-09-17_session-5}")"

# And each clause that reads the heading's shape, likewise.
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a first line with no leading # corrected onto the file name' \
  "$(head_edit "$HEAD_FIX/docs/dev-log/devlog_nohash_session-5.md" '2026-09-17 · session 2 — R' '2026-09-17 · session 5 — R')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'the correction that also takes the # off the heading' \
  "$(head_edit "$E_WRONG" "$H_WRONG" "${H_RIGHT#\# }")"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a heading with no · segment, given one' \
  "$(head_edit "$HEAD_FIX/docs/dev-log/devlog_nodot_session-5.md" '# 2026-09-17 — R' '# 2026-09-17 — R · session 5 — R')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a heading with no — segment, given one that repeats its session' \
  "$(head_edit "$HEAD_FIX/docs/dev-log/devlog_nodash_session-5.md" '# 2026-09-17 · session 2' '# 2026-09-17 · session 5 — session 2')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a heading with no — segment, given an empty one' \
  "$(head_edit "$HEAD_FIX/docs/dev-log/devlog_nodash_session-5.md" '# 2026-09-17 · session 2' '# 2026-09-17 · session 5 — ')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a heading whose date segment is empty' \
  "$(head_edit "$HEAD_FIX/docs/dev-log/devlog_nodate_session-5.md" '#  · session 2 — R' '#  · session 5 — R')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a heading whose session segment is empty, given one' \
  "$(head_edit "$HEAD_FIX/docs/dev-log/devlog_nosess_session-5.md" '# 2026-09-17 ·  — R' '# 2026-09-17 · session 5 — R')"
# The two controls of the section: the exception must not have widened what the
# hook already permitted, nor narrowed it.
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh ALLOW 'control: the directory README stays revisable in place' \
  "$(head_edit "$HEAD_FIX/docs/dev-log/README.md" 'index' 'the index')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh ALLOW 'control: an entry that is not there yet is still writable' \
  "$(head_write "$HEAD_FIX/docs/dev-log/devlog_2026-09-21_session-1.md" '# 2026-09-21 · session 1 — new')"

# THE REFUSAL NAMES THE EXCEPTION, pinned whole. Every row above reads a
# verdict, so deleting the sentence that tells an agent what IS permitted left
# the suite green (review of #189, round 2). The whole sentence and not a
# fragment of it, because a prefix keeps matching after the rest is deleted.
REPO_ROOT="$HEAD_FIX" feed_says "$PATH" append-only-docs-edit.sh \
  "The one exception (ADR 0003, #177) is an Edit that changes only the session segment of a docs/dev-log/ entry's first-line heading, to agree with the session the file is named for." \
  'and the refusal of a body edit names the one exception, whole' \
  "$(head_edit "$E_WRONG" 'Body line one.' 'Body line ONE.')"

# CLASS E OF #189's SECOND ROUND: agreement as narrow as the prose's notion of it.
# Two spellings of a session the real directory holds, each on a file named for
# that session, so the heading already agrees and there is nothing to correct:
# the session quoted as code, which the newest entries write, and the word
# `session` in front of a name the file carries without it. Each isolates one
# step of the old side's key, and the third row is the correction written in the
# newest style, one of the three spellings the new side accepts.
printf '%s\n\nBody.\n' '# 2026-09-20 · `clause-and-effect-37` — R' \
  > "$HEAD_FIX/docs/dev-log/devlog_backtick_clause-and-effect-37.md"
printf '%s\n\nBody.\n' '# 2026-09-20 · session clause-and-effect-37 — R' \
  > "$HEAD_FIX/docs/dev-log/devlog_word_clause-and-effect-37.md"
printf '%s\n\nBody.\n' '# 2026-09-27 · session `dev-agent-2` — R' \
  > "$HEAD_FIX/docs/dev-log/devlog_newstyle_dev-agent-7.md"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a heading naming its session as code already agrees, so relabelling it is refused' \
  "$(head_edit "$HEAD_FIX/docs/dev-log/devlog_backtick_clause-and-effect-37.md" '# 2026-09-20 · `clause-and-effect-37` — R' '# 2026-09-20 · clause-and-effect-37 — R')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a heading naming its session after the word session already agrees, so relabelling it is refused' \
  "$(head_edit "$HEAD_FIX/docs/dev-log/devlog_word_clause-and-effect-37.md" '# 2026-09-20 · session clause-and-effect-37 — R' '# 2026-09-20 · clause-and-effect-37 — R')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh ALLOW 'the correction written as code, as the newest entries write it' \
  "$(head_edit "$HEAD_FIX/docs/dev-log/devlog_newstyle_dev-agent-7.md" '# 2026-09-27 · session `dev-agent-2` — R' '# 2026-09-27 · session `dev-agent-7` — R')"

# CLASS E AGAIN, IN ROUND 2's FIX FOR IT (review of #189, round 3). One
# normalisation served both tests, so what it missed on the old side permitted
# rewriting a right heading, and what it accepted on the new side was a label the
# exception would write. The old side now compares keys -- lowercased letters and
# digits, less a leading `session` -- and the new side must be one of three exact
# spellings. The four old spellings review measured as contradictions: each
# isolates the case fold or the reduction to letters and digits. The two new
# labels it measured: a lone backtick, which pairs with the one in the rest and
# renders a code span across the separator, and a bare name wrapped in hyphens.
r177_old() {  # r177_old <file session> <old segment> -- a fixture entry, and the relabel of it onto the file's name
  local f="$HEAD_FIX/docs/dev-log/devlog_old_$1.md"
  printf '# 2026-09-27 · %s — #155: a `gh` rest\n\nBody.\n' "$2" > "$f"
  head_edit "$f" "# 2026-09-27 · $2 — #155: a \`gh\` rest" "# 2026-09-27 · session ${1#session-} — #155: a \`gh\` rest"
}
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'an old segment that names the session in capitals already agrees' \
  "$(r177_old session-5 'Session 5')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'an old segment with a tab for its space already agrees' \
  "$(r177_old session-6 $'session\t6')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'an old segment with a colon after the word session already agrees' \
  "$(r177_old dev-agent-9 'session: dev-agent-9')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'an old segment naming the session in emphasis already agrees' \
  "$(r177_old dev-agent-10 '*dev-agent-10*')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a new segment of a lone backtick and the name, which is no spelling the name gives' \
  "$(head_edit "$E_WRONG" "$H_WRONG" "${H_WRONG/session 2/\`5}")"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a new segment of the bare name wrapped in hyphens' \
  "$(head_edit "$E_WRONG" "$H_WRONG" "${H_WRONG/session 2/-5-}")"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh ALLOW 'the correction to the bare name, the third spelling the name gives' \
  "$(head_edit "$E_WRONG" "$H_WRONG" "${H_WRONG/session 2/5}")"

# CLASS H OF #189's FOURTH ROUND: a field cut at a separator's first occurrence
# holds whatever lies before it, so a separator inside one field moved another
# field's boundary. A heading of the `# <date> — <summary>` shape the newest
# entries open with, whose summary holds a ` · x — `, parsed as a date running
# into the summary and a session of summary text; and a time written between two
# ` · ` parsed as part of the session. No real heading had either shape when
# review swept all 66, and the real-directory rows below cannot see it, since
# their own shape test offers such a heading unchanged.
printf '%s\n\nBody.\n' '# 2026-09-25 21:16 +03 — #157: rules · naming — pinned' \
  > "$HEAD_FIX/docs/dev-log/devlog_summary_dev-agent-157.md"
printf '%s\n\nBody.\n' '# 2026-09-25 · 21:53 · dev-issue-141 — R' \
  > "$HEAD_FIX/docs/dev-log/devlog_time_dev-issue-141.md"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a date-and-summary heading whose summary holds a · x — is not rewritten inside the summary' \
  "$(head_edit "$HEAD_FIX/docs/dev-log/devlog_summary_dev-agent-157.md" '# 2026-09-25 21:16 +03 — #157: rules · naming — pinned' '# 2026-09-25 21:16 +03 — #157: rules · dev-agent-157 — pinned')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a time between two · separators is not taken for part of the session and deleted' \
  "$(head_edit "$HEAD_FIX/docs/dev-log/devlog_time_dev-issue-141.md" '# 2026-09-25 · 21:53 · dev-issue-141 — R' '# 2026-09-25 · dev-issue-141 — R')"

# A FILE NAME THAT CARRIES NO SESSION. Its session is empty, so the three
# spellings it gives are the empty string, the word `session` alone, and the
# word before an empty code span; the empty-session-name test is all that stands
# between that file and a heading relabelled onto the word alone. It was counted
# backed until round 4's sweep, which found round 3's exact new side had made it
# the only refusal.
printf '%s\n\nBody.\n' "$H_WRONG" > "$HEAD_FIX/docs/dev-log/devlog_2026-09-17_.md"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a file whose name carries no session, relabelled onto the word session alone' \
  "$(head_edit "$HEAD_FIX/docs/dev-log/devlog_2026-09-17_.md" "$H_WRONG" "${H_WRONG/session 2/session }")"

# AND THE REAL DIRECTORY, every entry of it: the relabel of its heading onto its
# own file's session name is refused, because no entry here contradicts its name
# once this branch has corrected the one that did. The payload is derived from
# the entry -- its first line, and that line with the session segment replaced
# by `session <n>`, a spelling the new side accepts, so that what refuses it is
# the old side's agreement and not the new side's strictness -- and the verdict
# is the literal. A first line not of the correctable shape is offered unchanged
# and refused, under a label that says so: 31 of 66 entries when review of #189
# counted them in its third round.
# WHAT A RED ROW HERE MEANS: that entry's heading reads, to the hook, as
# contradicting its file name. Either it does, and ADR 0003 says to correct it,
# which this exception permits; or it names its session in a spelling the
# agreement test does not know, and the test is what needs widening. Two
# entries were the second case when review of #189 swept the directory in its
# second round, and no row asked, because the section's premise was that the
# directory held nothing to ask about.
for r177_entry in "$REPO_ROOT"/docs/dev-log/devlog_*.md; do
  r177_name=${r177_entry##*/}
  r177_stem=${r177_name%.md}; r177_stem=${r177_stem#devlog_}
  IFS= read -r r177_first < "$r177_entry"
  r177_sess=${r177_stem#*_}
  case "$r177_first" in
    '# '*' · '*' — '*)
      r177_after=${r177_first#*' · '}
      r177_new="${r177_first%%' · '*} · session ${r177_sess#session-} — ${r177_after#*' — '}"
      r177_label="a real entry, $r177_name, relabelled onto its own file's session name" ;;
    *)
      r177_new=$r177_first
      r177_label="a real entry, $r177_name, whose first line is not of the correctable shape, offered unchanged" ;;
  esac
  feed "$PATH" append-only-docs-edit.sh BLOCK "$r177_label" \
    "$(head_edit "$r177_entry" "$r177_first" "$r177_new")"
done

# CLASS F OF THE SAME ROUND: the tool is not inferred from the payload's shape. A
# Write that also carries the two strings of the plain correction.
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a Write carrying old_string and new_string of the plain correction' \
  "$(jq -cn --arg p "$E_WRONG" --arg o "$H_WRONG" --arg n "$H_RIGHT" \
       '{tool_name:"Write",tool_input:{file_path:$p,content:"x",old_string:$o,new_string:$n}}')"

# A RAW NUL ON THE STREAM (GH-95.1's malformed input), which a bash string cannot
# carry, so no row fed through one could ever have asked. The fixture is a hook
# in front of the hook: it turns each \001 on its stdin into a NUL and runs the
# real hook -- the one under judgment, mutated copy included -- on the result.
# The control says the fixture delivers a correction the hook permits; each
# refusing row is that correction with a NUL added, and was measured ALLOW
# against the buffer that dropped NULs.
R177_NUL="$FIXTURES/r177-nul-hook.sh"
printf '#!/bin/bash\ntr '"'"'\\001'"'"' '"'"'\\000'"'"' | exec %q\n' "$(hook_path append-only-docs-edit.sh)" > "$R177_NUL"
chmod +x "$R177_NUL"
R177_FIX=$(head_edit "$E_WRONG" "$H_WRONG" "$H_RIGHT")
REPO_ROOT="$HEAD_FIX" feed "$PATH" "$R177_NUL" ALLOW 'control: the NUL fixture passes the plain correction through, and it is permitted' \
  "$R177_FIX"
req GH-95.1
REPO_ROOT="$HEAD_FIX" feed "$PATH" "$R177_NUL" BLOCK 'the plain correction followed by a raw NUL on the stream' \
  "$R177_FIX"$'\001'
REPO_ROOT="$HEAD_FIX" feed "$PATH" "$R177_NUL" BLOCK 'the plain correction with a raw NUL inside the file_path string' \
  "${R177_FIX/"$E_WRONG"/"$E_WRONG"$'\001'}"

# CLASS G OF #189's THIRD ROUND: prose about a sibling guard is held to that
# guard. CLAUDE.md, CONTEXT.md and ADR 0003 said the Bash half refuses the
# correction "in every Bash spelling"; it is a list of seven, review measured
# five spellings past it, and the author a sixth, `dd`. So every spelling the
# documents now name is fed to the guard at the verdict they state, as GH-157.3
# feeds the dev-log README's, and the two documents the suite already reads are
# held to naming the list.
req GH-177.1
R177_E=docs/dev-log/devlog_2026-09-17_session-5.md
check append-only-docs.sh BLOCK 'the documents name sed -i as refused on an entry' "sed -i 's/session 2/session 5/' $R177_E"
check append-only-docs.sh BLOCK 'and rm' "rm $R177_E"
check append-only-docs.sh BLOCK 'and mv' "mv $R177_E x"
check append-only-docs.sh BLOCK 'and cp' "cp x $R177_E"
check append-only-docs.sh BLOCK 'and tee' "echo x | tee $R177_E"
check append-only-docs.sh BLOCK 'and truncate' "truncate -s0 $R177_E"
check append-only-docs.sh BLOCK 'and a >' "echo x > $R177_E"
check append-only-docs.sh ALLOW 'and perl -pi as not refused (#246 decides this verdict)' "perl -pi -e 's/2/5/' $R177_E"
check append-only-docs.sh ALLOW 'and python3 -c as not refused (#246 decides this verdict)' \
  "python3 -c \"import pathlib; pathlib.Path('$R177_E').write_text('x')\""
R177_CLAUDE=$(awk '/^One exception, and it is one part of one line\./ { f = 1 } f && /^`ls docs\/`/ { exit } f' \
  "$SUITE_DIR/../../CLAUDE.md" | comment_reflow)
holds 'CLAUDE.md names the spellings the Bash half refuses' \
  "$R177_CLAUDE" 'the Bash spellings it refuses on an entry — `sed -i`, `rm`, `mv`, `cp`, `tee`, `truncate` and a `>` — it refuses for the correction too.'
holds 'and says the rest are open, and whose to close' \
  "$R177_CLAUDE" 'is not refused at all, which is #246'"'"'s to close.'
lacks 'and does not say the correction is refused in every Bash spelling' "$R177_CLAUDE" 'every Bash spelling'
R177_CONTEXT=$(comment_reflow < "$SUITE_DIR/../../CONTEXT.md")
holds 'CONTEXT.md names the spellings the Bash half refuses' \
  "$R177_CONTEXT" 'the spellings it refuses on an entry — `sed -i`, `rm`, `mv`, `cp`, `tee`, `truncate` and a `>` — it refuses for the correction too,'
holds 'and says the rest are open, and whose to close' \
  "$R177_CONTEXT" 'which it does not refuse at all, is #246'"'"'s to close.'
lacks 'and does not say the correction is refused in every spelling' "$R177_CONTEXT" 'refuses the correction in every spelling'

sourced_to_end

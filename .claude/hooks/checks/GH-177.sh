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
# These drive a project root of their own. The reason is the branch that adds
# them: after it, docs/dev-log/ holds no entry whose heading contradicts its file
# name -- that is what the branch fixes -- so there is nothing here to ask the
# permitting question of, and the refusing cases that bound it would have no
# subject either. A fixture root also reaches the shapes this repository will
# never hold: a heading corrected to a third session, a whole entry rewritten by
# Write, a second line smuggled into the replacement. The refusing cases against
# real files stay in the unsplit file, under GH-69.3, so the hook is still asked
# about this repository as well as about the fixture.
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
  refuses every other one as it did. The permitted edit is an `Edit` of a
  `docs/dev-log/` entry named `devlog_<date>_<session>.md`, whose `old_string` is
  the file's current first line and occurs in the file exactly once, counted as the
  Edit tool matches it -- a substring anywhere, overlapping, so `replace_all` has
  nothing to widen -- whose `new_string` is a single line, which parse as
  `# <date> · <session> — <rest>` with a date and a session that are not empty and
  are byte-identical in date and rest, and whose new session segment agrees with
  the session the file is named for where the old segment does not. Both strings
  are compared exactly as the tool call carries them, trailing newlines included,
  and a tool call spelling a NUL (`\u0000`) is refused, since a bash string cannot
  hold one. Agreement collapses runs of spaces and hyphens on both sides, so
  `session-5` agrees with `session 5` and contradicts `session 2`. A `Write` of an
  existing entry carries no `old_string` and is refused; so is a body edit, a rest
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
  The checks drive a fixture root rather than this repository, for the reason the
  section says: after this branch `docs/dev-log/` holds no entry whose heading
  contradicts its name, which is the branch's point, so the permitting direction has
  no subject here and the refusing cases it is bounded by have none either.
  WHAT THE SECTION IS EVIDENCE ABOUT, MEASURED RATHER THAN ASSUMED. The
  exception was swept a clause at a time, in review of #189's first round: each
  of its 25 refusing conditions -- 23 `return 1` clauses across
  `heading_correction` and `parse_heading`, and the two halves of the latter's
  closing test -- removed on a copy, and every row of this section re-judged
  against the result. Sixteen have a row that turns red when they are removed,
  and so does the call site: the directory, the `.md` suffix, the `devlog_`
  prefix, the NUL refusal, the whole-first-line test, the count, the parse of
  `old_string`, the three separator tests, the empty date and the empty session,
  date-unchanged, rest-unchanged, new-session-agrees and old-session-differs. Nine
  turn nothing red, and each is backed by a named clause rather than dead: the
  `_` in the name by the empty-session-name test, and that by new-session-agrees,
  since a session that is not empty never normalises to empty; the `old_string`
  read by the whole-first-line test, and the `new_string` read by the parse of
  `new_string`, which is backed in turn by new-session-agrees and
  old-session-differs, because a parse that fails leaves `old_string`'s session in
  place and the two cannot both hold of one session; the two single-line tests,
  by the first-line and date, rest and session tests, as the hook says beside
  them; the empty-first-line test by the whole-first-line test; and the file's
  read, by nothing but the race of a file readable by `read` and not by `cat`.
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
shape_pin 'GH-177'
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
# above, and each has a payload that only it refuses.
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

sourced_to_end

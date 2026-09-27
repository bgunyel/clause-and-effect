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
  `docs/dev-log/` entry whose `old_string` is the file's current first line and
  occurs in the file exactly once, whose `new_string` is a single line, which parse
  as `# <date> · <session> — <rest>` and are byte-identical in date and rest, and
  whose new session segment agrees with the session the file is named for where the
  old segment does not. Agreement collapses runs of spaces and hyphens on both
  sides, so `session-5` agrees with `session 5` and contradicts `session 2`. A
  `Write` of an existing entry carries no `old_string` and is refused; so is a body
  edit, a rest or date that moves with the session, a new segment agreeing with
  nothing, an `old_string` that is not the first line, a second line smuggled into
  `new_string`, a heading that already agrees, and the same shape under
  `docs/lessons-learned/` or `docs/eval-reports/`.
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
  exception was hand-swept a clause at a time — each of the 16 conditions in
  `heading_correction` removed on a copy, and every payload the section drives
  re-judged against the result. Seven clauses have a payload that flips when they
  are removed: the first-line test, the occurrence test, date-unchanged,
  rest-unchanged, new-session-agrees, old-session-differs, and the exception as a
  whole. The rest flip nothing, and the sweep says why rather than leaving it to be
  discovered: removing the `docs/dev-log/` prefix, the `devlog_` prefix, the `.md`
  suffix, either heading parse or the `old_string` read leaves some later clause
  refusing the same payload, so they are defence in depth and not dead. The two
  single-line tests are the one case where that is worth stating in the hook as
  well, and it is stated there. TWO OF THOSE SEVEN ARE ONLY THERE BECAUSE THE SWEEP
  RAN. The first version of this section had no payload that isolated the
  first-line test — its `not-first-line` case named a heading the fixture did not
  contain, so the occurrence test refused it first, and a heading-shaped line in an
  entry's BODY was editable with that test deleted. The occurrence test had none
  either, until a fixture was added whose entry quotes its own heading. Both are
  the shape #84 is about, one level in: the check existed, was green, and asked a
  narrower question than its own label.
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
# thing left: the hook never sees `replace_all`, so a first line matched twice is
# an edit whose second target it cannot see. Named because the clause sweep
# found this the one clause with no payload of its own.
printf '%s\n\nAs its own heading says:\n%s\n' "$H_WRONG" "$H_WRONG" \
  > "$HEAD_FIX/docs/dev-log/devlog_2026-09-17_session-3.md"
printf '# Dev Log\n\nindex\n' > "$HEAD_FIX/docs/dev-log/README.md"
printf '%s\n\nBody.\n' "$H_WRONG" \
  > "$HEAD_FIX/docs/lessons-learned/lesson_2026-09-17_session-5.md"

head_edit() {  # head_edit <path> <old> <new>
  jq -cn --arg p "$1" --arg o "$2" --arg n "$3" \
    '{tool_name:"Edit",tool_input:{file_path:$p,old_string:$o,new_string:$n}}'
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
# The one above names a heading the file does not hold at all, so the occurrence
# test refuses it before the first-line test is reached. This one names a line
# the file really holds, in its body, and corrects it exactly as the exception
# would correct a real heading. Only the first-line test stands between it and a
# permitted edit to the body of a history entry.
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a heading-shaped line the file holds, but in its body rather than line 1' \
  "$(head_edit "$E_WRONG" "$H_INBODY" "${H_INBODY/session 4/session 5}")"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a second line smuggled into new_string behind a correct heading' \
  "$(head_edit "$E_WRONG" "$H_WRONG" "$H_RIGHT"$'\nand a line the entry never had')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a Write of the whole entry, its heading corrected and all' \
  "$(head_write "$E_WRONG" "$H_RIGHT"$'\n\nBody line one.\nBody line two.\n')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'a heading that already agrees with its file name, so nothing to correct' \
  "$(head_edit "$E_OTHER" "$H_OTHER" "$H_OTHER")"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'the first line is correct, but the entry quotes it again in its body' \
  "$(head_edit "$HEAD_FIX/docs/dev-log/devlog_2026-09-17_session-3.md" "$H_WRONG" '# 2026-09-17 · session 3 — #128: a continued heredoc opener hid the command after its terminator')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh BLOCK 'the same correction shape under docs/lessons-learned/' \
  "$(head_edit "$HEAD_FIX/docs/lessons-learned/lesson_2026-09-17_session-5.md" "$H_WRONG" "$H_RIGHT")"
# The two controls of the section: the exception must not have widened what the
# hook already permitted, nor narrowed it.
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh ALLOW 'control: the directory README stays revisable in place' \
  "$(head_edit "$HEAD_FIX/docs/dev-log/README.md" 'index' 'the index')"
REPO_ROOT="$HEAD_FIX" feed "$PATH" append-only-docs-edit.sh ALLOW 'control: an entry that is not there yet is still writable' \
  "$(head_write "$HEAD_FIX/docs/dev-log/devlog_2026-09-21_session-1.md" '# 2026-09-21 · session 1 — new')"

sourced_to_end

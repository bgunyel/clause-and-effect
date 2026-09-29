#!/bin/bash
# THE ISSUE FILE OF #162: a dev-log entry's heading does not contradict the
# file name it lives under.
#
# Why: renaming an entry was a manual act in three parts -- the file name, the
# heading and the README's index -- and the fourth time it was done, in two
# days, it dropped the heading. `devlog_2026-09-17_session-5.md` opened
# `# 2026-09-17 · session 2 — …`, which is a different entry's label, and
# nothing read an entry's first line against its name, so the drift was
# silent. #177 corrected that heading in place, under ADR 0003, and GH-177's
# real-directory loop asks the Edit guard about every entry since. That loop
# is evidence about the guard, not about the entries: it reads a contradiction
# only on a heading of the one shape the guard can correct,
# `# <date> · <session> — <rest>`, and only as the guard's verdict. This is
# the property itself, read off every entry whatever its heading's shape.
#
# WHAT CHANGED BETWEEN THE ISSUE AND THIS FILE, measured on dev-05 at abffdbf
# with 75 entries on disk. The heading #162 was filed against had been
# corrected. The README's index is gone -- #157's Conventions end on "Do not
# add the entries in this file" -- so the triage's two README properties,
# bullet text and completeness, have nothing left to read. And four entries,
# written after the triage under #157's convention, open
# `# <date> <time> +03 — #<n>: …` and name no session at all. The triage's
# rule, that a heading CONTAINS its file's session, is red on those four for
# ever: they are history, and ADR 0003's exception moves a session segment
# that is there and cannot insert one that is not. So Bertan decided the rule
# is CONTRADICTION ONLY, which is the property ADR 0003 names: a heading that
# names a session names its file's, and a heading that names none is not held
# to one.
#
# THE RULE, per entry, in the order `r162_judge` asks it; the first failure is
# the one reported:
#   - the name is `devlog_<YYYY-MM-DD>_<session>.md`, <session> not empty;
#   - its first line opens with `# `;
#   - the first `YYYY-MM-DD` on that line is the file's date;
#   - after that date, a ` HH:MM` and then a ` +ZZ` or ` -ZZ` are taken off
#     when they are there, and what is left up to the first ` — ` -- em dash,
#     one blank each side -- is the heading's LABEL. Its key is its letters and
#     digits, lowercased, less a leading `session`, which is the Edit guard's
#     `session_key`. An empty key names no session and passes; any other must
#     equal the key of the file's <session>.
# Equality of keys and not containment: `session 50` on `session-5` is red, as
# `session 2` was.
#
# THE SHAPES IT READS, each an entry on disk today and each a fixture row:
# `# Devlog — <date> · session <n>`, `# <date> · session <n>` with no rest,
# `# <date> · <session> — <rest>` with the session bare, after the word
# `session`, or quoted as code, the date with a time and with a time and an
# offset, `# Dev log — <date>, session `<name>`` and
# `# <date> <time> +03 — <rest>`, which names none.
#
# WHAT IT DOES NOT SEE, named, and each pinned as a verdict below:
#   - a session written AFTER the ` — `. `# Dev-log — <date> — dev-agent-204`
#     has an empty label, so it names no session to this rule, and the same
#     heading naming another session is green too. Two entries are that shape.
#     Reading the rest for a session would make every summary a label.
#   - a rest opened with anything but ` — `. `# <date> <time> +03 – #205: …`,
#     with an en dash, reads the summary as the label and is red, a refusal
#     where the heading is right. No entry is that shape; the correction is to
#     write the dash the others are written with.
#   - the date of an entry appended to a file after its first: only the first
#     line is read, and an append opens with its own date, which is later.
#
# WHY A RED ROW STAYS RED UNTIL SOMEONE ACTS. An entry that has reached the
# active dev branch is history. A wrong session segment in the guard's shape is
# corrected with the Edit ADR 0003 permits, and GH-177's loop then agrees with
# this one. A wrong date, or a wrong session in any other shape, cannot be
# corrected by an agent at all, and is Bertan's to settle; the row names the
# entry and what is wrong with it. On a draft it is one edit.
#
# THE DIRECTORY IS AN ARGUMENT, because the real entries cannot be broken to
# see a row go red: both append-only guards refuse the edit, and
# mutate-hooks.sh copies .claude/hooks/ and nothing under docs/. So every
# property is driven against fixture directories first, each asserted whole as
# a literal, through the one function the real rows are made from, and the
# real directory is then read by that same function. Its list is derived from
# the directory -- every name in it but README.md, a subdirectory or a dotfile
# included -- so an entry added is an entry asked, and a file the rule cannot
# read as an entry is red rather than passed over.

section "=== issue #162: a dev-log entry's heading does not contradict its file name ==="

requirement GH-162 <<'REQ'
- text: Every name in `docs/dev-log/` but `README.md` is an entry named
  `devlog_<YYYY-MM-DD>_<session>.md`, with <session> not empty, whose first
  line opens with `# ` and whose first `YYYY-MM-DD` is the file's date. When
  the heading names a session, it names the file's: the label -- what follows
  that date, less a ` HH:MM` and then a ` +ZZ` or ` -ZZ` where they stand,
  up to the first ` — ` -- has the key of the file's <session>, a key being
  the letters and digits lowercased, less a leading `session`. A label whose
  key is empty names no session and is not held to one. The list of entries
  is derived from the directory, so an entry added is asked with nothing else
  changed, and the rule is driven against fixture directories, each asserted
  whole as a literal, through the function the real rows are made from.
  The Conventions of `docs/dev-log/README.md` state the rule once, in a
  bullet pinned whole.
- from: #162, and Bertan's decision on it that the rule is contradiction only
- kind: doc-claim
- status: active
- direction: static: it reads documents against their own file names, and
  decides nothing about a command, so it has no verdict to have two
  directions of
- note: The triage asked that a heading CONTAIN its session. Four entries,
  each dated after it and following #157's convention, open
  `# <date> <time> +03 — #<n>:` and name none; they are history, ADR 0003's correction cannot insert a
  segment, and that rule would be red on them for ever. Not seen, and pinned
  as verdicts: a session written after the ` — `, which the label never
  reaches (two entries are that shape), and a rest opened by any other dash,
  which is read as the label and refused. The README bullets the triage also
  asked about are gone: #157's README indexes no entries. Where the real
  directory cannot be broken, the fixtures are the evidence that a row can go
  red; the real rows are the evidence that the entries agree today.
REQ
shape_pin 'GH-162:static'

r162_key() {  # r162_key <text> -- its letters and digits, lowercased, less a leading `session`
  local s=${1,,}
  s=${s//[^[:alnum:]]/}
  case "$s" in session?*) s=${s#session} ;; esac
  printf '%s' "$s"
}

r162_judge() {  # r162_judge <path> -- `names its session`, `names no session`, or what is wrong
  local name=${1##*/} date sess first label
  if ! [[ $name =~ ^devlog_([0-9]{4}-[0-9]{2}-[0-9]{2})_(.+)[.]md$ ]]; then
    printf 'its name is not devlog_<date>_<session>.md'; return
  fi
  date=${BASH_REMATCH[1]} sess=${BASH_REMATCH[2]}
  [ -f "$1" ] && [ -r "$1" ] || { printf 'it is not a readable file'; return; }
  first=
  IFS= read -r first < "$1"
  case "$first" in '# '*) ;; *) printf 'its first line is not a heading'; return ;; esac
  [[ $first =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]] || { printf 'its heading carries no date'; return; }
  [ "${BASH_REMATCH[0]}" = "$date" ] || {
    printf 'its heading is dated %s, and its name %s' "${BASH_REMATCH[0]}" "$date"; return
  }
  label=${first#*"$date"}
  [[ $label =~ ^\ [0-9]{2}:[0-9]{2} ]] && label=${label#"${BASH_REMATCH[0]}"}
  [[ $label =~ ^\ [+-][0-9]{2} ]] && label=${label#"${BASH_REMATCH[0]}"}
  label=${label%%' — '*}
  if [ -z "$(r162_key "$label")" ]; then
    printf 'names no session'
  elif [ "$(r162_key "$label")" = "$(r162_key "$sess")" ]; then
    printf 'names its session'
  else
    printf 'its heading names |%s|, and its name %s' "$label" "$sess"
  fi
}

r162_report() {  # r162_report <dir> -- `<name>: <judgement>` for every name in it but README.md, sorted
  local path
  while IFS= read -r -d '' path; do
    printf '%s: %s\n' "${path##*/}" "$(r162_judge "$path")"
  done < <(find "$1" -mindepth 1 -maxdepth 1 ! -name README.md -print0 2>/dev/null | LC_ALL=C sort -z)
}

# THE KEY, against literals: the two spellings of a name the file names carry,
# a `session-` name that is not a number, and a heading's label with its
# separator, its word `session` and its code quotes.
req GH-162
tok 'the key of a numbered name is its number' '5' "$(r162_key 'session-5')"
tok 'the key of a session- name that is not a number is the rest' 'devissue117' "$(r162_key 'session-dev-issue-117')"
tok 'the key of a name with no session- is the name' 'devissue141' "$(r162_key 'dev-issue-141')"
tok 'the key of a label drops its separator, the word session and the code quotes' \
    'clauseandeffect37' "$(r162_key ' · Session `clause-and-effect-37`')"

# THE SHAPES THAT AGREE, one a fixture each, and the two that are read as
# naming no session. Every entry but the last two has its heading as an entry
# on disk writes it.
R162_OK="$FIXTURES/r162-agree"
mkdir -p "$R162_OK"
r162_entry() {  # r162_entry <dir> <name> <first line> -- an entry with a body
  printf '%s\n\nBody.\n' "$3" > "$1/$2"
}
r162_entry "$R162_OK" devlog_2026-08-01_session-1.md '# Devlog — 2026-08-01 · session 1'
r162_entry "$R162_OK" devlog_2026-08-10_session-2.md '# 2026-08-10 · session 2'
r162_entry "$R162_OK" devlog_2026-09-17_session-5.md '# 2026-09-17 · session 5 — #128: a continued heredoc opener'
r162_entry "$R162_OK" devlog_2026-09-17_dev-issue-141.md '# 2026-09-17 21:53 · dev-issue-141 — #141: which requirements'
r162_entry "$R162_OK" devlog_2026-09-17_session-dev-issue-117.md '# 2026-09-17 · session dev-issue-117 — #117: a word recognised by name'
r162_entry "$R162_OK" devlog_2026-09-20_clause-and-effect-37.md '# 2026-09-20 17:22 +03 · session `clause-and-effect-37` — #118: an option'
r162_entry "$R162_OK" devlog_2026-09-20_dev-agent-130.md '# Dev log — 2026-09-20, session `dev-agent-130`'
r162_entry "$R162_OK" devlog_2026-09-24_dev-agent-205.md '# 2026-09-24 18:55 +03 — #205: new `GH-` entries declared'
r162_entry "$R162_OK" devlog_2026-09-23_dev-agent-204.md '# Dev-log — 2026-09-23 — dev-agent-204'
r162_entry "$R162_OK" devlog_2026-09-23_dev-agent-9.md '# Dev-log — 2026-09-23 — dev-agent-204'
printf '# Dev Log\n\nNo entry.\n' > "$R162_OK/README.md"
tok 'every shape an entry is written in agrees, and README.md is not an entry' \
'devlog_2026-08-01_session-1.md: names its session
devlog_2026-08-10_session-2.md: names its session
devlog_2026-09-17_dev-issue-141.md: names its session
devlog_2026-09-17_session-5.md: names its session
devlog_2026-09-17_session-dev-issue-117.md: names its session
devlog_2026-09-20_clause-and-effect-37.md: names its session
devlog_2026-09-20_dev-agent-130.md: names its session
devlog_2026-09-23_dev-agent-204.md: names no session
devlog_2026-09-23_dev-agent-9.md: names no session
devlog_2026-09-24_dev-agent-205.md: names no session' \
    "$(r162_report "$R162_OK")"

# THE SHAPES THAT CONTRADICT, each the agreeing fixture above with its session
# or date moved, so that what turns each red is that one move; and the files
# the rule cannot read as entries at all. The first is #162's own entry as it
# stood. `session 50` is there because containment would pass it.
R162_BAD="$FIXTURES/r162-contradict"
mkdir -p "$R162_BAD/devlog_2026-09-17_session-7.md"
r162_entry "$R162_BAD" devlog_2026-09-17_session-5.md '# 2026-09-17 · session 2 — #128: a continued heredoc opener'
r162_entry "$R162_BAD" devlog_2026-09-17_session-6.md '# 2026-09-17 · session 60 — #133: a refused retarget'
r162_entry "$R162_BAD" devlog_2026-08-01_session-1.md '# Devlog — 2026-08-01 · session 2'
r162_entry "$R162_BAD" devlog_2026-08-10_session-2.md '# 2026-08-10 · session 1'
r162_entry "$R162_BAD" devlog_2026-09-17_dev-issue-141.md '# 2026-09-17 21:53 · dev-issue-142 — #141: which requirements'
r162_entry "$R162_BAD" devlog_2026-09-20_clause-and-effect-37.md '# 2026-09-20 17:22 +03 · session `clause-and-effect-38` — #118: an option'
r162_entry "$R162_BAD" devlog_2026-09-20_dev-agent-130.md '# Dev log — 2026-09-20, session `dev-agent-131`'
r162_entry "$R162_BAD" devlog_2026-09-24_dev-agent-205.md '# 2026-09-24 18:55 +03 – #205: new `GH-` entries declared'
r162_entry "$R162_BAD" devlog_2026-09-18_session-1.md '# 2026-09-17 · session 1 — the follow-up review'
r162_entry "$R162_BAD" devlog_2026-09-18_session-2.md '# session 2 — the follow-up review'
r162_entry "$R162_BAD" devlog_2026-09-18_session-3.md '2026-09-18 · session 3 — the follow-up review'
: > "$R162_BAD/devlog_2026-09-18_session-4.md"
r162_entry "$R162_BAD" devlog_2026-09-18.md '# 2026-09-18 · session 1'
r162_entry "$R162_BAD" notes_2026-09-18_session-1.md '# 2026-09-18 · session 1'
r162_entry "$R162_BAD" .devlog_2026-09-18_session-1.md '# 2026-09-18 · session 1'
tok 'a moved session, a moved date, and a file that is not an entry are each red, with the reason' \
'.devlog_2026-09-18_session-1.md: its name is not devlog_<date>_<session>.md
devlog_2026-08-01_session-1.md: its heading names | · session 2|, and its name session-1
devlog_2026-08-10_session-2.md: its heading names | · session 1|, and its name session-2
devlog_2026-09-17_dev-issue-141.md: its heading names | · dev-issue-142|, and its name dev-issue-141
devlog_2026-09-17_session-5.md: its heading names | · session 2|, and its name session-5
devlog_2026-09-17_session-6.md: its heading names | · session 60|, and its name session-6
devlog_2026-09-17_session-7.md: it is not a readable file
devlog_2026-09-18.md: its name is not devlog_<date>_<session>.md
devlog_2026-09-18_session-1.md: its heading is dated 2026-09-17, and its name 2026-09-18
devlog_2026-09-18_session-2.md: its heading carries no date
devlog_2026-09-18_session-3.md: its first line is not a heading
devlog_2026-09-18_session-4.md: its first line is not a heading
devlog_2026-09-20_clause-and-effect-37.md: its heading names | · session `clause-and-effect-38`|, and its name clause-and-effect-37
devlog_2026-09-20_dev-agent-130.md: its heading names |, session `dev-agent-131`|, and its name dev-agent-130
devlog_2026-09-24_dev-agent-205.md: its heading names | – #205: new `GH-` entries declared|, and its name dev-agent-205
notes_2026-09-18_session-1.md: its name is not devlog_<date>_<session>.md' \
    "$(r162_report "$R162_BAD")"

# AN ENTRY ADDED IS AN ENTRY ASKED: the agreeing directory with one entry more,
# and nothing else changed, is red on that entry.
r162_entry "$R162_OK" devlog_2026-09-29_dev-agent-162.md '# 2026-09-29 · dev-agent-161 — #162'
holds 'an entry added to a directory is read with nothing else changed' \
    "$(r162_report "$R162_OK")" \
    'devlog_2026-09-29_dev-agent-162.md: its heading names | · dev-agent-161|, and its name dev-agent-162'

# THE REAL DIRECTORY, a row an entry. Guarded first: a read that found nothing,
# or not the entry #162 was filed against, would leave every row below unasked
# and the section green.
R162_DIR="$SUITE_DIR/../../docs/dev-log"
R162_REAL=$(r162_report "$R162_DIR")
holds 'the real dev-log was read, the entry #162 was filed against among it' "$R162_REAL" \
    'devlog_2026-09-17_session-5.md: '
[ -n "$R162_REAL" ] && while IFS= read -r r162_line; do
  case "$r162_line" in
    *': names its session') pass static '%s: its heading is dated and named as its file is' "${r162_line%%: *}" ;;
    *': names no session') pass static '%s: its heading is dated as its file is, and its label names no session' "${r162_line%%: *}" ;;
    *) fail static '%s\n         its heading contradicts its file name' "$r162_line" ;;
  esac
done <<< "$R162_REAL"

# THE README SAYS SO, where an entry is written: the whole bullet, once.
R162_README="$SUITE_DIR/../../docs/dev-log/README.md"
tok 'the dev-log README states the rule where an entry is written, once' '1' \
    "$(prose_occurrences "$R162_README" "- An entry's first line is its heading. It carries the date its file name carries, and when it names a session it names the one the file is named for; it may name none. \`check-hooks.sh\` reads every entry's first line against its name and is red on one that contradicts it (#162).")"

sourced_to_end

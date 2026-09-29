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
# with 74 entries on disk beside the README. The heading #162 was filed against had been
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
# THE KEY of a text is its letters and digits, lowercased, less a leading
# `session` with something after it: the Edit guard's `session_key`, copied
# and not called, because sourcing a hook runs it. The copy is held to the
# guard's body by a row below, so the two cannot come to disagree about which
# spellings name one session -- which is what lets a correction the guard
# permits turn a row here green.
#
# THE RULE, per entry, in the order `r162_judge` asks it; the first failure is
# the one reported:
#   - the name is `devlog_<YYYY-MM-DD>_<session>.md`, <session> not empty;
#   - it is a file that can be read, and not a directory or anything else;
#   - its first line opens with `# `;
#   - that line carries a `YYYY-MM-DD`, and the first it carries is the
#     file's date;
#   - what stands between the `# ` and that date, its key less a leading
#     `devlog` -- the title `Devlog —`, `Dev log —` or `Dev-log —` -- and then
#     keyed again, which takes off a leading `session` with something after it,
#     is the TITLE, and names no session, or names the file's. Keyed again and
#     not stripped here, so the one copy of the guard's strip is the pinned one
#     (#354);
#   - after that date a ` HH:MM` or a ` HH:MM:SS`, or either after a `T`, is
#     taken off when it is there; then a zone, whether a time came before it
#     or not, with a blank before it or none and a blank or the end after it:
#     `Z`, `UTC`, or a `+` or `-` with two digits and, optionally, two more,
#     a colon before them or none. What is left up to the first
#     ` — ` -- em dash, one blank each side -- is the heading's LABEL.
#   - when neither the title nor the label names a session, the REST after that
#     ` — ` is read: its first word, blanks around it dropped, or its first two
#     when the first is the word `session`. A rest opened with `#` names none,
#     as the #157 entries' `#<n>:` does. That is the session a title-first
#     heading writes last, and any heading that uses the dash where the others
#     use a ` · `.
#   - an empty key names no session; any other must equal the key of the
#     file's <session>.
# Equality of keys and not containment: `session 60` on `session-6` is red, as
# `session 2` on `session-5` was. The rest is read only when nothing before it
# named a session, because once one has, the rest is the summary, and a summary
# names other sessions: `session 2 — … a correction to session 1` is on disk.
# A trailing CR is taken off the line before any of it is read.
#
# THE SHAPES IT READS, each an entry on disk today and each a fixture row:
# `# Devlog — <date> · session <n>`, `# <date> · session <n>` with no rest,
# `# <date> · <session> — <rest>` with the session bare, after the word
# `session`, or quoted as code, the date with a time and with a time and an
# offset, `# Dev log — <date>, session `<name>``,
# `# Dev-log — <date> — <name>`, and `# <date> <time> +03 — #<n>: <rest>`,
# which names none. The spellings of a time and a zone above that no entry
# uses, a CR, and #344's two title-first shapes are fixture rows too.
#
# WHAT IT DOES NOT SEE, OR SEES WRONGLY, named, and each pinned by a row below:
#   - a rest opened by a word, on a heading that names no session in its title
#     or its label, reads that word as a session, so
#     `# <date> <time> +03 — WIP` and `# <date> <time> +03 — the summary` are
#     red. No entry is that shape. It is the price of reading a session written
#     after the dash in more than one word -- `session 2 — #128: …`,
#     `dev-agent-9 (continued)` -- which the reading of one word passed green;
#     a false red is visible, and a false green is not. Open the rest with
#     `#<n>`, or name the session before the dash.
#   - a title before the date other than the three spellings of `Devlog` is
#     read as a session, so `# Notes — <date> · session 9 — …` is red. No entry
#     is that shape.
#   - a rest opened with anything but ` — `. `# <date> <time> +03 – #205: …`,
#     with an en dash, reads the summary as the label and is red, a refusal
#     where the heading is right. No entry is that shape; the correction is to
#     write the dash the others are written with.
#   - the heading of an entry appended to a file after its first: only the
#     file's first line is read, so a file is read as the entry it opens with.
#   - a session spelled in letters outside ASCII. `${1,,}` and `[[:alnum:]]`
#     read by the locale, so under `C` such letters are dropped from the key,
#     and two names differing only there agree. The guard's key reads the same
#     way, and the copy stays the guard's rather than fixing it alone. Every
#     session name an agent has written is ASCII.
#
# WHY A RED ROW STAYS RED UNTIL SOMEONE ACTS. An entry exists from its first
# write, a draft on a worktree branch included (#190), so no row here is red
# on something an agent can simply re-edit. A wrong session segment in the
# guard's shape is corrected with the Edit ADR 0003 permits, and GH-177's loop
# then agrees with this one. A wrong date, or a wrong session in any other
# shape, cannot be corrected by an agent at all, and is Bertan's to settle;
# the row names the entry and what is wrong with it. That is why the correct
# spellings named above that no entry uses yet are fixtures that agree, beside
# the ones on disk; a correct spelling not named there may still be red.
#
# THE DIRECTORY IS AN ARGUMENT, because the real entries cannot be broken to
# see a row go red: both append-only guards refuse the edit, and
# mutate-hooks.sh copies .claude/hooks/ and nothing under docs/. So every
# property is driven against fixture directories first, each asserted whole as
# a literal, through r162_judge over the list r162_names derives; the rows are
# made by r162_rows, which classes each judgement whole by r162_class and is
# itself asserted whole, FAIL rows included, over a fixture directory; and the
# real directory is then read by that same r162_rows. Its list is derived from
# the directory -- every name in it but README.md, a subdirectory or a dotfile
# included -- so an entry added is an entry asked, and a file the rule cannot
# read as an entry is red rather than passed over.

section "=== issue #162: a dev-log entry's heading does not contradict its file name ==="

requirement GH-162 <<'REQ'
- text: Every name in `docs/dev-log/` but `README.md` is an entry named
  `devlog_<YYYY-MM-DD>_<session>.md`, with <session> not empty, whose first
  line opens with `# ` and whose first `YYYY-MM-DD` is the file's date. When
  the heading names a session, it names the file's, a key being the letters
  and digits lowercased, less a leading `session`, as the Edit guard's
  `session_key` computes it and held to that function's body. It is read in
  three places: before the date, less a leading `devlog` and then a leading
  `session`; in the label -- what follows the date, less a time with or
  without seconds and then a zone, each where it stands, up to the first
  ` — `; and, when neither of those names one, in the rest after that dash,
  whose first word is read, or its first two when the first is `session`,
  and which names none when it opens with `#`. A heading naming no session
  in any of the three is not held to one. The list of entries
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
  `# <date> <time> +03 — #<n>:` and name none; they are history, ADR
  0003's correction cannot insert a segment, and that rule would be red on
  them for ever. Pinned as verdicts: a rest opened by a word, on a heading
  naming no session before it, has that word read as a session and refused,
  and so is a rest opened by any other dash; only a file's first line is
  read, so an entry appended after it is not. The README bullets the triage also
  asked about are gone: #157's README indexes no entries. Where the real
  directory cannot be broken, the fixtures are the evidence that a row can go
  red; the real rows are the evidence that the entries agree today.
REQ
shape_pin 'GH-162:static'

r162_key() {  # r162_key <text> -- the Edit guard's session_key, copied: its letters and digits, lowercased, less a leading `session`
  local s=${1,,}
  s=${s//[^[:alnum:]]/}
  case "$s" in session?*) s=${s#session} ;; esac
  printf '%s' "$s"
}

r162_judge() {  # r162_judge <path> -- `names its session`, `names no session`, or what is wrong
  local name=${1##*/} date sess first title label rest _
  if ! [[ $name =~ ^devlog_([0-9]{4}-[0-9]{2}-[0-9]{2})_(.+)[.]md$ ]]; then
    printf 'its name is not devlog_<date>_<session>.md'; return
  fi
  date=${BASH_REMATCH[1]} sess=${BASH_REMATCH[2]}
  [ -f "$1" ] && [ -r "$1" ] || { printf 'it is not a readable file'; return; }
  first=
  IFS= read -r first < "$1"
  first=${first%$'\r'}
  case "$first" in '# '*) ;; *) printf 'its first line is not a heading'; return ;; esac
  [[ $first =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]] || { printf 'its heading carries no date'; return; }
  [ "${BASH_REMATCH[0]}" = "$date" ] || {
    printf 'its heading is dated %s, and its name %s' "${BASH_REMATCH[0]}" "$date"; return
  }
  title=${first#'# '}; title=${title%%"$date"*}
  title=$(r162_key "$title"); title=$(r162_key "${title#devlog}")
  if [ -n "$title" ] && [ "$title" != "$(r162_key "$sess")" ]; then
    printf 'its heading names |%s| before its date, and its name %s' "${first%%"$date"*}" "$sess"; return
  fi
  label=${first#*"$date"}
  [[ $label =~ ^[\ T][0-9]{2}:[0-9]{2}(:[0-9]{2})? ]] && label=${label#"${BASH_REMATCH[0]}"}
  [[ $label =~ ^(\ ?(Z|UTC|[+-][0-9]{2}(:?[0-9]{2})?))([[:space:]]|$) ]] && label=${label#"${BASH_REMATCH[1]}"}
  rest=
  case "$label" in *' — '*) rest=${label#*' — '} label=${label%%' — '*} ;; esac
  if [ -z "$title" ] && [ -z "$(r162_key "$label")" ]; then
    local w1= w2=
    read -r w1 w2 _ <<< "$rest"
    case "$w1" in
      '#'*) ;;
      *) [ "$(r162_key "$w1")" = session ] && [ -n "$w2" ] && w1="$w1 $w2"
         label=" — $w1" ;;
    esac
  fi
  if [ -z "$(r162_key "$label")" ]; then
    if [ -n "$title" ]; then printf 'names its session'; else printf 'names no session'; fi
  elif [ "$(r162_key "$label")" = "$(r162_key "$sess")" ]; then
    printf 'names its session'
  else
    printf 'its heading names |%s|, and its name %s' "$label" "$sess"
  fi
}

r162_names() {  # r162_names <dir> -- every path in it but README.md, sorted, each ended by a NUL
  find "$1" -mindepth 1 -maxdepth 1 ! -name README.md -print0 2>/dev/null | LC_ALL=C sort -z
}

r162_report() {  # r162_report <dir> -- `<name>: <judgement>` for every name in it but README.md, sorted
  local path
  while IFS= read -r -d '' path; do
    printf '%s: %s\n' "${path##*/}" "$(r162_judge "$path")"
  done < <(r162_names "$1")
}

r162_class() {  # r162_class <judgement> -- `named`, `none` or `contradicts`, the judgement compared whole
  case "$1" in
    'names its session') printf 'named' ;;
    'names no session') printf 'none' ;;
    *) printf 'contradicts' ;;
  esac
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
tok 'the key of the word session alone is the word' 'session' "$(r162_key 'session')"
tok 'under C a letter outside ASCII is dropped from the key, so two names differing only there agree' \
    'dvagent:dvagent' "$(export LC_ALL=C; r162_key 'dév-agent'):$(export LC_ALL=C; r162_key 'dāv-agent')"

# THE COPY IS THE GUARD'S: r162_key's body, line for line, is session_key's in
# append-only-docs-edit.sh. Read off $HOOKS, so a mutated copy of the guard's
# key under mutate-hooks.sh turns this red too, and guarded against a read of
# nothing, where two empty bodies would be equal.
r162_body() {  # r162_body <file> <function> -- the lines between its opening line and its closing brace
  awk -v f="$2() {" 'index($0, f) == 1 { on = 1; next } on && /^}/ { exit } on' "$1" 2>/dev/null
}
R162_GUARD_KEY=$(r162_body "$HOOKS/append-only-docs-edit.sh" session_key)
holds 'the guard'"'"'s session_key was read' "$R162_GUARD_KEY" 's=${s//[^[:alnum:]]/}'
tok 'r162_key is the guard'"'"'s session_key, line for line' \
    "$R162_GUARD_KEY" "$(r162_body "$SUITE_DIR/checks/GH-162.sh" r162_key)"

# THE SHAPES THAT AGREE, one a fixture each, written as an entry on disk
# writes it, but the last two: a session written before the date, and an entry
# appended to, whose later heading is not read.
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
r162_entry "$R162_OK" devlog_2026-09-17_session-8.md '# Session 8 — 2026-09-17 — the follow-up review'
printf '%s\n\nBody.\n\n%s\n\nMore.\n' '# 2026-09-27 · dev-agent-110 — #110: the runbook' \
  '# 2026-09-28 · dev-agent-111 — the second entry, appended' > "$R162_OK/devlog_2026-09-27_dev-agent-110.md"
printf '# Dev Log\n\nNo entry.\n' > "$R162_OK/README.md"
# And the spellings no entry uses yet, each one an agent could write and could
# not then correct, because a draft is frozen from its first write (#190): a
# one-word summary after a title that named the session and a `Devlog` title
# with the word `session` in it (#344), a time with seconds, an offset of four
# digits, with a colon, written after a `T`, a `Z` or a `UTC`, a heading ended
# by a CR, a rest that names another session after a label that named this
# one, and a session whose name opens with a `Z`, which a zone read without the
# blank after it would cut.
r162_entry "$R162_OK" devlog_2026-09-18_session-8.md '# Session 8 — 2026-09-18 — follow-up'
r162_entry "$R162_OK" devlog_2026-09-17_session-3.md '# Devlog session 3 — 2026-09-17'
r162_entry "$R162_OK" devlog_2026-09-29_dev-agent-164.md '# 2026-09-29 06:55:12 +03 · dev-agent-164 — a time with seconds'
r162_entry "$R162_OK" devlog_2026-09-29_dev-agent-163.md '# 2026-09-29 06:55 +0300 · dev-agent-163 — an offset of four digits'
r162_entry "$R162_OK" devlog_2026-09-25_dev-agent-207.md '# 2026-09-25 14:09 +0300 — #205: an offset of four digits, and no session'
r162_entry "$R162_OK" devlog_2026-09-25_dev-agent-215.md '# 2026-09-25T15:30:00+03:00 — #205: a time after a T, and no session'
r162_entry "$R162_OK" devlog_2026-09-26_dev-agent-216.md '# 2026-09-26 15:30Z · dev-agent-216 — a zone of Z'
r162_entry "$R162_OK" devlog_2026-09-26_dev-agent-217.md '# 2026-09-26 15:30 UTC · dev-agent-217 — a zone of UTC'
r162_entry "$R162_OK" devlog_2026-09-26_dev-agent-218.md $'# 2026-09-26 · dev-agent-218 — written with CRLF\r'
r162_entry "$R162_OK" devlog_2026-09-26_session-2.md '# 2026-09-26 · session 2 — a correction to session 1'
r162_entry "$R162_OK" devlog_2026-09-26_zulu-1.md '# 2026-09-26 15:30 Zulu-1 — a session whose name opens as a zone does'
tok 'every shape an entry is written in agrees, and README.md is not an entry' \
'devlog_2026-08-01_session-1.md: names its session
devlog_2026-08-10_session-2.md: names its session
devlog_2026-09-17_dev-issue-141.md: names its session
devlog_2026-09-17_session-3.md: names its session
devlog_2026-09-17_session-5.md: names its session
devlog_2026-09-17_session-8.md: names its session
devlog_2026-09-17_session-dev-issue-117.md: names its session
devlog_2026-09-18_session-8.md: names its session
devlog_2026-09-20_clause-and-effect-37.md: names its session
devlog_2026-09-20_dev-agent-130.md: names its session
devlog_2026-09-23_dev-agent-204.md: names its session
devlog_2026-09-24_dev-agent-205.md: names no session
devlog_2026-09-25_dev-agent-207.md: names no session
devlog_2026-09-25_dev-agent-215.md: names no session
devlog_2026-09-26_dev-agent-216.md: names its session
devlog_2026-09-26_dev-agent-217.md: names its session
devlog_2026-09-26_dev-agent-218.md: names its session
devlog_2026-09-26_session-2.md: names its session
devlog_2026-09-26_zulu-1.md: names its session
devlog_2026-09-27_dev-agent-110.md: names its session
devlog_2026-09-29_dev-agent-163.md: names its session
devlog_2026-09-29_dev-agent-164.md: names its session' \
    "$(r162_report "$R162_OK")"

# THE SHAPES THAT CONTRADICT: most are an agreeing fixture above with its
# session or its date moved, so that what turns each red is that one move; the
# rest are the refusals the header names as trades, and the files the rule
# cannot read as entries at all. The first is #162's own entry as it stood.
# `session 60` on `session-6` is there because containment would pass it, and
# `session 8` after a `Session 2` title because the label agreeing does not
# excuse the title.
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
r162_entry "$R162_BAD" devlog_2026-09-23_dev-agent-9.md '# Dev-log — 2026-09-23 — dev-agent-204'
r162_entry "$R162_BAD" devlog_2026-09-17_session-8.md '# Session 2 — 2026-09-17 · session 8 — the follow-up review'
r162_entry "$R162_BAD" devlog_2026-09-17_session-9.md '# Notes — 2026-09-17 · session 9 — the follow-up review'
r162_entry "$R162_BAD" devlog_2026-09-25_dev-agent-207.md '# 2026-09-25 14:09 +03 — WIP'
r162_entry "$R162_BAD" devlog_2026-09-18_session-1.md '# 2026-09-17 · session 1 — the follow-up review'
r162_entry "$R162_BAD" devlog_2026-09-18_session-2.md '# session 2 — the follow-up review'
r162_entry "$R162_BAD" devlog_2026-09-18_session-3.md '2026-09-18 · session 3 — the follow-up review'
: > "$R162_BAD/devlog_2026-09-18_session-4.md"
r162_entry "$R162_BAD" devlog_2026-09-18.md '# 2026-09-18 · session 1'
r162_entry "$R162_BAD" notes_2026-09-18_session-1.md '# 2026-09-18 · session 1'
r162_entry "$R162_BAD" .devlog_2026-09-18_session-1.md '# 2026-09-18 · session 1'
# A session written after the date's ` — ` in more than one word, each a shape
# the one-word reading passed green: the word `session` in front of it, quoted
# or not, a summary after it, a blank or a CR after it, or a parenthesis. And
# the price of reading those: a summary opened by a word, where nothing before
# the dash named a session, reads that word as one.
r162_entry "$R162_BAD" devlog_2026-09-23_dev-agent-210.md '# Dev-log — 2026-09-23 — session dev-agent-999'
r162_entry "$R162_BAD" devlog_2026-09-24_dev-agent-211.md '# 2026-09-24 18:55 +03 — dev-agent-999 — #205: new entries'
r162_entry "$R162_BAD" devlog_2026-09-19_session-5.md '# 2026-09-19 — session 2 — #128: a continued heredoc opener'
r162_entry "$R162_BAD" devlog_2026-09-20_dev-agent-212.md '# Dev log — 2026-09-20 — session `dev-agent-999`'
r162_entry "$R162_BAD" devlog_2026-09-23_dev-agent-213.md '# Dev-log — 2026-09-23 — dev-agent-999 '
r162_entry "$R162_BAD" devlog_2026-09-23_dev-agent-214.md $'# Dev-log — 2026-09-23 — dev-agent-999\r'
r162_entry "$R162_BAD" devlog_2026-09-23_dev-agent-215.md '# Dev-log — 2026-09-23 — dev-agent-999 (continued)'
r162_entry "$R162_BAD" devlog_2026-09-25_dev-agent-216.md '# 2026-09-25 14:09 +03 — the check-hooks summary'
r162_entry "$R162_BAD" devlog_2026-09-19_session-6.md '# Devlog session 7 — 2026-09-19'
tok 'a moved session, a moved date, a named trade, and a file that is not an entry are each red, with the reason' \
'.devlog_2026-09-18_session-1.md: its name is not devlog_<date>_<session>.md
devlog_2026-08-01_session-1.md: its heading names | · session 2|, and its name session-1
devlog_2026-08-10_session-2.md: its heading names | · session 1|, and its name session-2
devlog_2026-09-17_dev-issue-141.md: its heading names | · dev-issue-142|, and its name dev-issue-141
devlog_2026-09-17_session-5.md: its heading names | · session 2|, and its name session-5
devlog_2026-09-17_session-6.md: its heading names | · session 60|, and its name session-6
devlog_2026-09-17_session-7.md: it is not a readable file
devlog_2026-09-17_session-8.md: its heading names |# Session 2 — | before its date, and its name session-8
devlog_2026-09-17_session-9.md: its heading names |# Notes — | before its date, and its name session-9
devlog_2026-09-18.md: its name is not devlog_<date>_<session>.md
devlog_2026-09-18_session-1.md: its heading is dated 2026-09-17, and its name 2026-09-18
devlog_2026-09-18_session-2.md: its heading carries no date
devlog_2026-09-18_session-3.md: its first line is not a heading
devlog_2026-09-18_session-4.md: its first line is not a heading
devlog_2026-09-19_session-5.md: its heading names | — session 2|, and its name session-5
devlog_2026-09-19_session-6.md: its heading names |# Devlog session 7 — | before its date, and its name session-6
devlog_2026-09-20_clause-and-effect-37.md: its heading names | · session `clause-and-effect-38`|, and its name clause-and-effect-37
devlog_2026-09-20_dev-agent-130.md: its heading names |, session `dev-agent-131`|, and its name dev-agent-130
devlog_2026-09-20_dev-agent-212.md: its heading names | — session `dev-agent-999`|, and its name dev-agent-212
devlog_2026-09-23_dev-agent-210.md: its heading names | — session dev-agent-999|, and its name dev-agent-210
devlog_2026-09-23_dev-agent-213.md: its heading names | — dev-agent-999|, and its name dev-agent-213
devlog_2026-09-23_dev-agent-214.md: its heading names | — dev-agent-999|, and its name dev-agent-214
devlog_2026-09-23_dev-agent-215.md: its heading names | — dev-agent-999|, and its name dev-agent-215
devlog_2026-09-23_dev-agent-9.md: its heading names | — dev-agent-204|, and its name dev-agent-9
devlog_2026-09-24_dev-agent-205.md: its heading names | – #205: new `GH-` entries declared|, and its name dev-agent-205
devlog_2026-09-24_dev-agent-211.md: its heading names | — dev-agent-999|, and its name dev-agent-211
devlog_2026-09-25_dev-agent-207.md: its heading names | — WIP|, and its name dev-agent-207
devlog_2026-09-25_dev-agent-216.md: its heading names | — the|, and its name dev-agent-216
notes_2026-09-18_session-1.md: its name is not devlog_<date>_<session>.md' \
    "$(r162_report "$R162_BAD")"

# AN ENTRY ADDED IS AN ENTRY ASKED: the agreeing directory with one entry more,
# and nothing else changed, is red on that entry.
r162_entry "$R162_OK" devlog_2026-09-29_dev-agent-162.md '# 2026-09-29 · dev-agent-161 — #162'
holds 'an entry added to a directory is read with nothing else changed' \
    "$(r162_report "$R162_OK")" \
    'devlog_2026-09-29_dev-agent-162.md: its heading names | · dev-agent-161|, and its name dev-agent-162'

# A JUDGEMENT IS CLASSED WHOLE (#354). The real rows once read `<name>:
# <judgement>` lines by their end, and a name is text the judgement repeats:
# `devlog_<date>_x: names its session.md` headed `# <date> · y` is judged
# `… and its name x: names its session`, and was passed. So each real row
# takes its judgement from r162_judge alone and classes it by equality.
tok 'a judgement ending as a passing one does is classed by the whole of it' \
    'contradicts:named:none' \
    "$(r162_class 'its heading names | · y|, and its name x: names its session'):$(r162_class 'names its session'):$(r162_class 'names no session')"

# THE ROWS, one an entry, made by one function for the fixtures and the real
# directory alike, so the arm that fails is driven and not only written. A row
# printed inside `$( )` is not recorded -- `record` returns in a subshell, and
# its FAILED dies with it -- so the rows over a fixture directory are asserted
# whole as a literal, FAIL lines included, and only the real directory's are
# made in this shell.
r162_rows() {  # r162_rows <dir> -- an ok or a FAIL row for every name in it but README.md, counted in R162_MADE
  local path said
  while IFS= read -r -d '' path; do
    R162_MADE=$((R162_MADE + 1))
    said=$(r162_judge "$path")
    case "$(r162_class "$said")" in
      named) pass static '%s: its heading is dated and named as its file is' "${path##*/}" ;;
      none) pass static '%s: its heading is dated as its file is, and names no session' "${path##*/}" ;;
      *) fail static '%s: %s\n         its heading contradicts its file name' "${path##*/}" "$said" ;;
    esac
  done < <(r162_names "$1")
}
R162_ROWS="$FIXTURES/r162-rows"
mkdir -p "$R162_ROWS"
r162_entry "$R162_ROWS" devlog_2026-09-17_session-5.md '# 2026-09-17 · session 5 — #128: a continued heredoc opener'
r162_entry "$R162_ROWS" devlog_2026-09-24_dev-agent-205.md '# 2026-09-24 18:55 +03 — #205: new `GH-` entries declared'
r162_entry "$R162_ROWS" devlog_2026-09-17_session-6.md '# 2026-09-17 · session 2 — #133: a refused retarget'
r162_entry "$R162_ROWS" 'devlog_2026-09-23_x: names its session.md' '# 2026-09-23 · y'
tok 'a row an entry: ok where it names its session or none, FAIL where it contradicts, and a name is not a verdict' \
'  ok   devlog_2026-09-17_session-5.md: its heading is dated and named as its file is
  FAIL devlog_2026-09-17_session-6.md: its heading names | · session 2|, and its name session-6
                its heading contradicts its file name
  FAIL devlog_2026-09-23_x: names its session.md: its heading names | · y|, and its name x: names its session
                its heading contradicts its file name
  ok   devlog_2026-09-24_dev-agent-205.md: its heading is dated as its file is, and names no session' \
    "$(r162_rows "$R162_ROWS")"

# THE REAL DIRECTORY, a row an entry, off the root the suite derives once.
# Guarded on both sides: a read that found nothing, or not the entry #162 was
# filed against as a whole name, would leave every row below unasked; and rows
# not made for every name read would leave the rest unasked. Either is a green
# section that asked nothing.
R162_DIR="$REPO_ROOT/docs/dev-log"
R162_READ=$(r162_names "$R162_DIR" | tr '\0' '\n' | sed 's|.*/||')
holds 'the real dev-log was read, the entry #162 was filed against among it' \
    $'\n'"$R162_READ"$'\n' $'\ndevlog_2026-09-17_session-5.md\n'
R162_MADE=0
r162_rows "$R162_DIR"
tok 'a row was made for every name the real dev-log was read to hold' \
    "$(printf '%s\n' "$R162_READ" | grep -c .)" "$R162_MADE"

# THE README SAYS SO, where an entry is written: the whole bullet, once.
R162_README="$REPO_ROOT/docs/dev-log/README.md"
tok 'the dev-log README states the rule where an entry is written, once' '1' \
    "$(prose_occurrences "$R162_README" "- An entry's first line is its heading. It carries the date its file name carries, and when it names a session it names the one the file is named for; it may name none. \`check-hooks.sh\` reads every entry file's first line against its name and is red on one that contradicts it; an entry appended after the first is not read (#162). A session is read in three places: before the date, less a \`Devlog\` title; after the date, its time and its zone, up to the first \` — \`; and, only when neither of those names one, after that dash, where the first word, or \`session\` and the word after it, is read as the session unless it opens with \`#\`. So \`# <date> <time> +03 — #<n>: …\` names none, and \`# <date> <time> +03 — WIP\` names \`WIP\`. An entry exists from its first write, so write the heading right the first time.")"

sourced_to_end

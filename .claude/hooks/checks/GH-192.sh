#!/bin/bash
# THE ISSUE FILE OF #192: a pin on prose reads the prose, not the lines.
#
# Why: `written`, `unarmed` and `prose_count` grep a file's lines, and `holds`
# and `lacks` a string read line by line, so a literal with a blank in it
# matched only where the wrap happened not to fall inside it. GH-70.3's
# `unarmed ... 'four acts'` read ok with `four` ending one line of the
# branch-hygiene skill and `acts` opening the next, and the whole suite passed
# (#192, measured on PR #183's branch at d86223b); GH-99.1's two `'0'` counts
# over CLAUDE.md and its absence over this suite's own text were the same shape.
# All three are the permitting direction, and silent. A presence pin was the
# other half: a rewrap that changed no word turned it red.
#
# The reader is the library's `prose`, over comment_reflow, and the rule is
# written once, beside it. This file drives the two helpers #192 adds and the
# one it moves onto the reader, against fixtures of its own, and then audits
# the suite's own text for a pin the rule reaches that still reads the lines.
#
# WHAT IS DRIVEN is each helper inside $( ), where its `pass` or `fail` is not
# recorded and its FAILED does not reach this shell, so a helper that fails
# here, as it should, is this file's evidence and not a red row -- #219's
# convention. What each row asserts is the whole of what the helper printed,
# as a literal.

section "=== issue #192: a pin on prose reads the prose, not the lines ==="

requirement GH-192.1 <<'REQ'
- text: `prose <file>` writes the file as `comment_reflow` reads it -- a
  column-0 `#` and up to three blanks off each line, a word broken at a hyphen
  rejoined, the lines joined, every run of spaces one -- to a fixture under
  `$FIXTURES/prose` at the file's own path, and prints that path. So a phrase
  wrapped across a line break of Markdown, or across two column-0 comment
  lines, is found there by `written` and makes `unarmed` fail, where over the
  file's lines `written` fails and `unarmed` reads ok. From a directory, a path
  that is not there, an empty file, a file of blank lines or a relative name
  it writes nothing, so `written` and `unarmed` over the path it prints both
  fail and name grep's status 2.
- from: #192
- kind: defect-permitting
- status: active
- direction: static: a property of the suite's helpers
- note: What it cannot read is recorded as a check, not only in the library.
  An indented comment keeps its `#`, so a phrase wrapped across two indented
  comment lines is not found, and a heading's `#` is taken off, so a pin whose
  literal needs one stays on the lines.
REQ
requirement GH-192.2 <<'REQ'
- text: `prose_occurrences <file> <literal>` prints how many times the literal
  occurs in the file as `prose` reads it, counting a wrapped occurrence and
  each of two on one line, where `prose_count` counts matching lines. A literal
  that does not occur prints `0`; a directory or a path that is not there
  prints `unread: grep exited 2 on <the prose path>`, which no count equals.
- from: #192
- kind: defect-permitting
- status: active
- direction: static: a property of the suite's helpers
REQ
requirement GH-192.3 <<'REQ'
- text: No pin in the suite's text reads the lines of a prose file with a
  literal that holds a blank. A prose file here is a variable assigned a
  Markdown path, derived off the text, or one of the header extracts, the
  suite's own text and the left-open string named in this file. A pin is a
  `written`, `unarmed`, `holds` or `lacks` call, its continuation lines joined,
  or a `prose_count`; one naming such a variable directly, rather than through
  `prose`, fails the audit unless its literal opens with a `#`, the one a
  heading's pin needs and `prose` would take off. `beside` reads the
  comment block it is given through `comment_reflow`.
- from: #192
- kind: defect-permitting
- status: active
- direction: static: a property of the suite's own text
- note: The audit reads text, so it reaches the pins that name one of those
  variables in a `"$NAME" '<literal>'` shape and nothing else. The pins on a
  hook file's comments are the other half of #192's sweep and are not audited:
  whether a literal there is prose or code is a judgement per pin, made in the
  sweep and written beside the pins that stayed on the lines.
REQ
shape_pin 'GH-192.1:static GH-192.2:static GH-192.3:static'

# What a helper prints opens with two blanks, held in a variable so that no
# quoted string here opens with a result's prefix: #104's audit at the foot of
# the suite reads every such string as a result printed around pass and fail.
R192_INDENT='  '
# THE FIXTURES. Each phrase below is written wrapped, on purpose, and the
# guard after them asks each file for its line count -- a fixture built
# otherwise would let a row pass over text that is not the case it names. The
# Markdown ones are named `.txt`, because the audit at the foot of this file
# derives its prose variables from `.md` paths, and a row here that reads
# their lines on purpose would be its finding.
R192_MD="$FIXTURES/r192-skill.txt"
R192_SH="$FIXTURES/r192-header.sh"
R192_TWICE="$FIXTURES/r192-twice.txt"
R192_EMPTY="$FIXTURES/r192-empty.txt"
R192_BLANK="$FIXTURES/r192-blank.txt"
R192_DIR="$FIXTURES/r192-dir"
R192_GONE="$FIXTURES/r192-no-such-file"
printf '%s\n' '## A heading' 'The reserved acts below are the four' \
  'acts the rotation may not take, pre-' 'built.' > "$R192_MD"
printf '%s\n' '#!/bin/bash' '# The count is gone: no second' '#   pointer named here.' \
  'code=1' '  # an indented' '  # phrase wrapped' > "$R192_SH"
printf '%s\n' 'four acts, and four acts; the four' 'acts' > "$R192_TWICE"
: > "$R192_EMPTY"
printf '\n\n' > "$R192_BLANK"
mkdir -p "$R192_DIR"
printf '%s\n' 'four acts' > "$R192_DIR/inside.txt"
rm -f "$R192_GONE"
[ "$(wc -l < "$R192_MD")" = 4 ] && [ "$(wc -l < "$R192_SH")" = 6 ] \
  && [ "$(wc -l < "$R192_TWICE")" = 2 ] && [ ! -s "$R192_EMPTY" ] \
  && [ "$(wc -c < "$R192_BLANK")" = 2 ] \
  && [ -d "$R192_DIR" ] && [ ! -e "$R192_GONE" ] \
  && ! grep -qF 'four acts the' "$R192_MD" && ! grep -qF 'pre-built' "$R192_MD" \
  && ! grep -qF 'second pointer' "$R192_SH" && ! grep -qF 'indented phrase' "$R192_SH" \
  && [ "$(grep -c 'four acts' "$R192_TWICE")" = 1 ] || {
  echo "the #192 fixtures were not created as written, each phrase wrapped where its row says; the checks against them prove nothing" >&2
  exit 1
}
# The paths the fixtures' reflows are written to, composed here rather than
# asked of `prose`: the path is part of what is under test.
R192_MD_PROSE="$FIXTURES/prose${R192_MD}"
R192_DIR_PROSE="$FIXTURES/prose${R192_DIR}"
R192_GONE_PROSE="$FIXTURES/prose${R192_GONE}"
R192_EMPTY_PROSE="$FIXTURES/prose${R192_EMPTY}"

req GH-192.1
tok 'prose prints the path of its fixture, the source path under $FIXTURES/prose' \
    "$R192_MD_PROSE" "$(prose "$R192_MD")"
tok 'and writes there the file as comment_reflow reads it, a heading'"'"'s first # and a hyphen break included' \
    '# A heading The reserved acts below are the four acts the rotation may not take, pre-built. ' \
    "$(cat "$R192_MD_PROSE")"
tok 'over the lines, a phrase wrapped in Markdown reads as absent, which is the defect' \
    "${R192_INDENT}ok   armed r192 driven check" \
    "$(unarmed 'r192 driven check' "$R192_MD" 'four acts')"
tok 'through prose the same absence fails' \
"${R192_INDENT}FAIL r192 driven check
                $R192_MD_PROSE must not contain |four acts|" \
    "$(unarmed 'r192 driven check' "$(prose "$R192_MD")" 'four acts')"
tok 'and the same presence is found' \
    "${R192_INDENT}ok   written r192 driven check" \
    "$(written 'r192 driven check' "$(prose "$R192_MD")" 'the four acts the rotation')"
tok 'a phrase wrapped across two comment lines, the second indented after its #, is found too' \
    "${R192_INDENT}ok   written r192 driven check" \
    "$(written 'r192 driven check' "$(prose "$R192_SH")" 'no second pointer named here.')"
# THE LIMIT, pinned rather than only written down: an indented comment keeps
# its `#`, so a phrase wrapped across two of them reads with a `#` inside it.
# A fix that reached it would turn this red, which is the moment to reword the
# library's paragraph on it.
tok 'but not one wrapped across two indented comment lines, which keep their #' \
"${R192_INDENT}FAIL r192 driven check
                expected $FIXTURES/prose${R192_SH} to still say |an indented phrase wrapped|" \
    "$(written 'r192 driven check' "$(prose "$R192_SH")" 'an indented phrase wrapped')"
# An empty extraction, a directory and a path that is not there reach grep's
# status 2 and not an empty reflow, over which `unarmed` would read ok.
tok 'from an empty file prose writes nothing, so unarmed over its path fails and says grep exited 2' \
"${R192_INDENT}FAIL r192 driven check
                grep exited 2 on $R192_EMPTY_PROSE, so it was not read and the absence of |four acts| is evidence of nothing" \
    "$(unarmed 'r192 driven check' "$(prose "$R192_EMPTY")" 'four acts')"
tok 'and from a file of blank lines, which comment_reflow would turn into a blank' \
"${R192_INDENT}FAIL r192 driven check
                grep exited 2 on $FIXTURES/prose${R192_BLANK}, so it was not read and the absence of |four acts| is evidence of nothing" \
    "$(unarmed 'r192 driven check' "$(prose "$R192_BLANK")" 'four acts')"
# A relative name is read from this suite's directory, not from the hooks under
# judgment; `absolute_or_fail` refuses one in `written` and `unarmed`, and
# behind `prose` they see only the fixture's absolute path, so `prose` refuses.
# Run from $FIXTURES, where the name does resolve, so that it is the spelling
# and not a missing file that is refused.
tok 'and from a relative name, though it names a file in the directory it runs in' \
"${R192_INDENT}FAIL r192 driven check
                grep exited 2 on $FIXTURES/prose/r192-skill.txt, so it was not read and the absence of |four acts| is evidence of nothing" \
    "$(cd "$FIXTURES" && unarmed 'r192 driven check' "$(prose r192-skill.txt)" 'four acts')"
tok 'and from a directory, though one inside it says the literal' \
"${R192_INDENT}FAIL r192 driven check
                grep exited 2 on $R192_DIR_PROSE, so it was not read and the absence of |four acts| is evidence of nothing" \
    "$(unarmed 'r192 driven check' "$(prose "$R192_DIR")" 'four acts')"
tok 'and from a path that is not there' \
"${R192_INDENT}FAIL r192 driven check
                grep exited 2 on $R192_GONE_PROSE, so it was not read and the absence of |four acts| is evidence of nothing" \
    "$(unarmed 'r192 driven check' "$(prose "$R192_GONE")" 'four acts')"
tok 'and written over that path fails as well' \
"${R192_INDENT}FAIL r192 driven check
                expected $R192_GONE_PROSE to still say |four acts|" \
    "$(written 'r192 driven check' "$(prose "$R192_GONE")" 'four acts')"
# A reflow left behind by an earlier call is removed, not read: with the
# source emptied since, the path must not still hold the text it held.
R192_EMPTIED="$FIXTURES/r192-emptied.txt"
cp "$R192_MD" "$R192_EMPTIED"
prose "$R192_EMPTIED" > /dev/null
[ -s "$FIXTURES/prose$R192_EMPTIED" ] || {
  echo "the #192 fixture for an emptied source was not reflowed first; the check against it proves nothing" >&2
  exit 1
}
: > "$R192_EMPTIED"
prose "$R192_EMPTIED" > /dev/null
tok 'and a reflow an earlier call wrote is removed once the source is empty' \
    'absent' "$([ -e "$FIXTURES/prose$R192_EMPTIED" ] && echo present || echo absent)"

req GH-192.2
tok 'prose_occurrences counts a wrapped occurrence and each of two on one line: three' \
    '3' "$(prose_occurrences "$R192_TWICE" 'four acts')"
tok 'where prose_count, counting lines, says one' \
    '1' "$(prose_count "$R192_TWICE" 'four acts')"
tok 'a literal that does not occur counts 0' \
    '0' "$(prose_occurrences "$R192_TWICE" 'five acts')"
tok 'a directory prints no count, and says grep exited 2 on the prose path' \
    "unread: grep exited 2 on $R192_DIR_PROSE" "$(prose_occurrences "$R192_DIR" 'four acts')"
tok 'and so does a path that is not there' \
    "unread: grep exited 2 on $R192_GONE_PROSE" "$(prose_occurrences "$R192_GONE" 'four acts')"

req GH-192.3
# `beside`, driven: the comment block above a derivation, with the literal
# wrapped across its two lines.
R192_BESIDE="$FIXTURES/r192-beside.sh"
printf '%s\n' '#!/bin/bash' '# the pairing: check-hooks.sh holds the three' \
  '# equal, so a change here is a change there' \
  'X=$(git for-each-ref refs/remotes/origin/dev-*)' > "$R192_BESIDE"
tok 'beside reads the comment block it is given through comment_reflow, so a wrapped literal is beside' \
    "${R192_INDENT}ok   beside r192 driven check" \
    "$(beside 'r192 driven check' "$R192_BESIDE" 'holds the three equal, so a change')"

# THE AUDIT. A pin line, its continuation lines joined, that names one of the
# prose variables directly and then, after blanks, a quoted literal holding a
# blank and not opening with `#`, is printed as `<variable> |<literal>|`. The
# blanks may be a continuation's, the literal opening the next line. A `#`
# inside a literal exempts nothing: `prose` keeps it. A line whose first word
# is not a pin is not one, so an extraction such as `entry "$CONTEXT_MD"
# 'Worktree branch'` is not read as a pin; `prose_count` is asked wherever it stands,
# since it sits inside a `tok`. A comment line is skipped before joining. A pin
# called inside `$( )`, as this file's own rows call them, is not a line's
# first word and is not audited: the suite's pins stand at a line's start.
r192_raw_prose_pins() {  # r192_raw_prose_pins <text file> <variable names> -- each pin that reads a prose file's lines
  awk -v vars="$2" '
    BEGIN { n = split(vars, v, " ") }
    /^[ \t]*#/ { next }
    {
      line = $0
      while (line ~ /\\$/ && (getline nxt) > 0)
        line = substr(line, 1, length(line) - 1) " " nxt
      pin = (line ~ /^[ \t]*(written|unarmed|holds|lacks) /)
      for (i = 1; i <= n; i++) {
        pat = "\"$" v[i] "\""
        rest = line
        before = ""
        while ((p = index(rest, pat)) > 0) {
          before = before substr(rest, 1, p - 1)
          rest = substr(rest, p + length(pat))
          if (rest !~ /^[ \t]+/) continue
          sub(/^[ \t]+/, "", rest)
          q = substr(rest, 1, 1)
          if (q != "\047" && q != "\"") continue
          if (!pin && before !~ /prose_count $/) continue
          lit = substr(rest, 2)
          e = index(lit, q)
          if (e) lit = substr(lit, 1, e - 1)
          if (lit ~ /[ \t]/ && lit !~ /^#/) print v[i] " |" lit "|"
        }
      }
    }' "$1"
}
# Driven first, against a text of its own, with a variable name no pin in the
# suite uses, so that this text is not itself a finding when the suite's own is
# audited below.
R192_AUDIT_FIX="$FIXTURES/r192-audit.txt"
printf '%s\n' \
  "written 'raw, one line' \"\$R192_V\" 'four acts'" \
  "written 'raw, continued' \\" \
  "  \"\$R192_V\" 'five acts'" \
  "holds 'literal on the next line' \"\$R192_V\" \\" \
  "    'six acts'" \
  "written 'a # inside' \"\$R192_V\" 'pull request #N'" \
  "unarmed 'through prose' \"\$(prose \"\$R192_V\")\" 'four acts'" \
  "# written 'a comment' \"\$R192_V\" 'four acts'" \
  "written 'a heading' \"\$R192_V\" '## A heading'" \
  "written 'one word' \"\$R192_V\" 'acts'" \
  "tok 'a count' '0' \"\$(prose_count \"\$R192_V\" 'git branch -f')\"" \
  "entry \"\$R192_V\" 'Worktree branch' > out" \
  "holds 'double quoted' \"\$R192_V\" \"three citations\"\" named below\"" > "$R192_AUDIT_FIX"
[ "$(wc -l < "$R192_AUDIT_FIX")" = 13 ] || {
  echo "the #192 audit fixture was not written as thirteen lines; the check against it proves nothing" >&2
  exit 1
}
tok 'the audit reports a raw prose pin on one line, continued, with its literal on the next line, holding a # inside, counted, and double-quoted, and nothing else' \
'R192_V |four acts|
R192_V |five acts|
R192_V |six acts|
R192_V |pull request #N|
R192_V |git branch -f|
R192_V |three citations|' \
    "$(r192_raw_prose_pins "$R192_AUDIT_FIX" 'R192_V')"

# THE PROSE VARIABLES. Every one assigned a Markdown path is derived off the
# text, so a Markdown fixture added later is audited without anyone naming it
# here. The rest are prose held in a file or string with no `.md` in its name,
# and are named: the three header extracts, the suite's own text and the
# left-open list. A prose fixture of that kind added later is not audited until
# it is added to this list, which is the trade the derivation leaves.
R192_NAMED='REPORT_HEADER SELF_PARAGRAPH SELF_WHOLE_HEADER SUITE_TEXT LEFT_OPEN'
R192_DERIVED=$(grep -oE '^[A-Z0-9_]+="[^"]*\.md"$' "$SUITE_TEXT" | cut -d= -f1 | sort -u | tr '\n' ' ')
# The derivation asked for what it has to have found, as literals, so that a
# grep that matched nothing does not leave the audit asking about nothing.
present 'the derived prose variables hold the branch-hygiene skill' SKILL_MD "$R192_DERIVED"
present 'and CLAUDE.md' CLAUDE_MD "$R192_DERIVED"
present 'and the boundary section extracted from it' SECTION "$R192_DERIVED"
R192_UNSET=
for v in $R192_NAMED; do
  [ -n "${!v}" ] || R192_UNSET="$R192_UNSET $v"
done
tok 'each prose variable named here is set, so the audit asks about text that exists' \
    '' "$R192_UNSET"
tok 'no pin in the suite reads the lines of a prose file with a literal that holds a blank' \
    '' "$(r192_raw_prose_pins "$SUITE_TEXT" "$R192_DERIVED $R192_NAMED")"

sourced_to_end

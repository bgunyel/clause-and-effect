#!/usr/bin/env bash
# Write the `GH-` entries the issue files declare into requirements/, one file
# each (#205). Not a hook: settings.json does not run it, and nothing runs it
# for you. The check suite runs it with --check against fixtures and against
# this repository.
#
#   bash .claude/hooks/generate-requirements.sh [--check] [<hooks directory>]
#
# WHY AN ENTRY IS GENERATED. A requirement's `text` was a sentence written by
# hand beside the checks that establish it, in a file of its own, and nothing
# held the two to each other: keeping two copies of one fact in step by hand is
# the class of defect #200 was filed about. So a `GH-` entry written after #205
# is declared once, in the issue file whose checks establish it, and its file
# under requirements/ is written from that declaration by this script rather
# than by hand. The entries written before it -- the legacy set, which the
# driver holds as REQUIREMENTS_LEGACY -- stay hand-written, and none is
# rewritten or migrated.
#
# A DECLARATION is a heredoc in an issue file, `checks/GH-<n>.sh`, at the start
# of a line:
#
#     requirement GH-<n>.<m> <<'REQ'
#     - text: ...
#     - from: #<n>
#     ...
#     REQ
#
# The body is the entry's fields, in the grammar requirements.md states, and
# nothing else: every line opens a field, continues one, or is blank, which the
# suite's reader of requirements/ skips and two legacy files hold. Its file is
# the heading, the body byte for byte, and a last field naming where it was
# declared -- `- generated: checks/GH-<n>.sh` -- which is what tells a reader
# not to edit it.
#
# WHICH FILE IS ITS OWN is decided by the legacy set and never by the file
# (#223). The set is REQUIREMENTS_LEGACY, read by name out of check-hooks.sh
# beside checks/, as split-requirements.sh reads SPLIT_MOVED: a legacy entry's
# file is never written, whatever it carries, and every other `GH-` file under
# requirements/ is this script's to replace, whether or not it carries the
# `generated` field. It decided by that field until #223, so a generated file
# whose field was deleted by hand was refused as hand-written from then on, and
# a legacy file that gained one was taken for its own and overwritten. These
# are the rules the suite's `generated_bad` holds, and they are spelled here in
# its words but one: a file nothing declares is one "no issue file declares",
# where the suite says no issue file IT RAN declares it, since this reads the
# issue files and never runs them.
#
# WHAT IT REFUSES, before it writes anything: a line whose first word, after
# any indentation, is `requirement` followed by `GH-`, spelled any other way --
# indented, unquoted, a delimiter other than REQ, a second word after the ID,
# whether a space or a tab stands before it --
# because the suite runs the file and reads what
# bash read, and a spelling this reads differently from bash is a second
# parser that can disagree with the first; an ID outside the grammar; an ID
# declared twice; a declaration never closed; a body that opens no field,
# holds a line that is no field, gives one field twice, or carries a
# `generated` field of its own; an ID declared in an issue file that is not
# its own issue's, `checks/GH-<n>.sh` for an entry of #<n>; a legacy ID
# declared at all; a legacy file carrying a `generated` field; a file outside
# the legacy set that no issue file declares, which a declaration taken away
# has left behind; and a check-hooks.sh with no REQUIREMENTS_LEGACY literal to
# read, since with no set to read every file would be this script's.
#
# THE GRAMMARS ARE COPIES, and the suite pins them. The ID grammar and the
# field grammar below are spelled again in split-requirements.sh, in the
# suite's reader of requirements/ and in its library, and each is a program of
# its own, so no one definition can be read by all of them. The #223 issue
# file counts every copy in every file, so a copy changed in one place is red.
#
# WRITES ARE ONE FILE AT A TIME, AND EACH IS WHOLE (#223): a file is written to
# a temporary name in requirements/ and moved over its destination, so a
# destination holds its old bytes or its new ones, never part of either. A
# failure stops the run, names the file, and leaves no temporary file, and so
# does a TERM or an interrupt, since the EXIT trap removes it; the files written before
# either are written, and a second run writes the rest. The trade, taken
# knowingly: a file it rewrites takes the mode a new file takes under the
# caller's umask, where the `cp` over it kept the mode the file had. Git keeps
# no mode but the executable bit, which neither gives an entry.
#
# WHAT IT DOES NOT SEE, named: a call whose first word is not `requirement` --
# `x=1 requirement GH-7 <<'REQ'` -- or whose ID is quoted or built by another
# command. Such a line is none of this script's; bash still runs it, and the
# suite, which records what bash declared, finds the entry declared and not
# written.
#
# WHAT IT DOES NOT DECIDE, named. Whether the legacy set is the one it was --
# the #205 issue file holds the literal to its count and checksum. Whether a
# legacy entry has kept its file, which is the suite's. And whether bash reads
# a declaration the way this does: the suite records every `requirement` call
# it runs and holds each file to that record too, so the two readings meet in
# the files.
#
# --check writes nothing. It prints what a run would refuse, and exits 1; a
# refusal is reported alone, because the declarations a refused run would
# write are not settled until it is answered. With no refusal it prints every
# file that is not what its declaration would write, and exits 1; otherwise it
# names the generated entries, one line, and exits 0.
set -u

usage() {
  echo "usage: bash .claude/hooks/generate-requirements.sh [--check] [<hooks directory>]" >&2
  exit 64
}
CHECK=
DIR=
while [ $# -gt 0 ]; do
  case $1 in
    --check) CHECK=1; shift ;;
    -*) usage ;;
    *) [ -z "$DIR" ] && [ -n "$1" ] || usage; DIR=$1; shift ;;
  esac
done
# An empty argument is a usage error and not the default: a caller whose
# directory came out empty would otherwise be answered about this script's own.
[ -n "$DIR" ] || DIR=$(dirname -- "$0")
NAME=generate-requirements.sh
# A directory that is not there, or holds no checks/, is refused rather than
# read: its listing would be empty, and an empty reading is what a directory
# with nothing to generate looks like, so it would pass (review of PR #222,
# round 3). The directory is made absolute here, so that no operand handed to
# awk below reads as a `var=value` assignment, which a relative path whose
# first segment holds a `=` would.
GIVEN=$DIR
DIR=$(CDPATH= cd -- "$GIVEN" 2>/dev/null && pwd) && [ -d "$DIR/checks" ] || {
  echo "$NAME: refused, and nothing was written:"
  echo "  $GIVEN is not a directory holding checks/, so there is no issue file to read"
  exit 1
}
SPLIT="$DIR/requirements"
# Globbing off for every unquoted list below; the two listings that need a
# glob turn it on in their own subshell. And the lists are split on blanks
# whatever IFS this was started under.
set -f
IFS=$' \t\n'

# The issue files, in version order on the issue number, so that what this
# prints is in one order whatever the directory listing says.
ISSUE_FILES=()
while IFS= read -r f; do
  [ -n "$f" ] && ISSUE_FILES+=("$DIR/checks/$f")
done < <( (set +f; cd -- "$DIR/checks" 2>/dev/null && for f in GH-*.sh; do [ -f "$f" ] && printf '%s\n' "$f"; done) | LC_ALL=C sort -V)

STAGE=$(mktemp -d) || exit 1
# The write loop's temporary file, if one is standing, is removed with the
# stage, whatever ends the run: bash runs this trap on a TERM or an interrupt
# too, measured with a TERM sent mid-write and no trap of its own for it.
TMP=
trap 'rm -rf "$STAGE"; [ -z "$TMP" ] || rm -f -- "$TMP"' EXIT

# One awk program reads every issue file. Each declaration it accepts is staged
# as $STAGE/<ID>, the file it would write; each thing it refuses is a line of
# $STAGE/.problems. `rel` is the issue file's path relative to the hooks
# directory, which is what the `generated` field names.
#
# The stage's path reaches awk through its environment and not through `-v`,
# which reads backslash escapes in the value: a TMPDIR holding `\t` made the
# path one awk could not open (review of PR #222, round 3). And awk's status is
# read, because an awk that died has staged nothing and refused nothing, which
# is what a clean reading looks like.
STAGE="$STAGE" awk '
  BEGIN { stage = ENVIRON["STAGE"] }
  function problem(s) { print s >> (stage "/.problems") }
  FNR == 1 {
    if (open != "") problem(rel ": " openid " is declared at line " openline " and never closed by a line reading REQ")
    open = ""; rel = FILENAME; sub(/^.*\/checks\//, "checks/", rel)
  }
  # A body line opens a field, continues the field before it, or is blank; the
  # reader of requirements/ in the suite takes the same three, skips a blank
  # line without ending the field before it, and refuses a field given twice,
  # so a body this accepts is one that reader accepts (#223). The generator
  # refused a blank line and wrote a field given twice until then.
  open != "" {
    if ($0 == "REQ") {
      if (nfield == 0) problem(rel ": line " openline ": " openid " is declared with no fields")
      else if (!(openid in seen)) { seen[openid] = rel; ids[++nids] = openid; doc[openid] = "### " openid "\n" body "- generated: " rel "\n" }
      else problem(openid ": declared twice, in " seen[openid] " and in " rel)
      open = ""; next
    }
    if ($0 ~ /^- generated:/) problem(rel ": line " FNR ": " openid " carries a generated field of its own, which is this script'"'"'s to write")
    else if ($0 ~ /^- [a-z-]+:/) {
      key = $0; sub(/^- /, "", key); sub(/:.*$/, "", key)
      if (key in given) problem(rel ": line " FNR ": " openid ": the field " key " is given twice")
      given[key] = 1; nfield++
    }
    else if ($0 !~ /^[ \t]*$/ && !(nfield > 0 && $0 ~ /^  [^ ]/)) problem(rel ": line " FNR ": " openid ": a line that is no field of the entry: " $0)
    body = body $0 "\n"; next
  }
  /^[ \t]*requirement[ \t]+GH-/ {
    if ($0 !~ /^requirement GH-[^ \t]+ <<'"'"'REQ'"'"'$/) { problem(rel ": line " FNR ": a declaration spelled other than requirement <ID> <<'"'"'REQ'"'"': " $0); next }
    openid = $2
    if (openid !~ /^GH-[1-9][0-9]*(\.[1-9][0-9]*)?$/) { problem(rel ": line " FNR ": " openid " is not an ID of the grammar GH-<n> or GH-<n>.<m>"); openid = "(" openid ")" }
    open = "y"; openline = FNR; body = ""; nfield = 0; split("", given)
    next
  }
  END {
    if (open != "") problem(rel ": " openid " is declared at line " openline " and never closed by a line reading REQ")
    for (i = 1; i <= nids; i++) if (ids[i] !~ /^\(/) { f = stage "/" ids[i]; printf "%s", doc[ids[i]] > f; close(f) }
  }
' ${ISSUE_FILES[@]+"${ISSUE_FILES[@]}"} </dev/null
AWK_STATUS=$?
if [ "$AWK_STATUS" != 0 ]; then
  echo "$NAME: reading the issue files failed, awk exit $AWK_STATUS; nothing was written"
  exit 1
fi

# THE LEGACY SET, read out of check-hooks.sh by name once the issue files are
# read: from the line opening `REQUIREMENTS_LEGACY='` to the quote that closes
# it. A literal that is not there, or never closes, is refused rather than read
# as an empty set, which would make every legacy file this script's to
# replace; and an awk that died here is a failed reading, as it is above.
LEGACY=$(awk '
  !on && /^REQUIREMENTS_LEGACY=\047/ { on = 1; found = 1; sub(/^REQUIREMENTS_LEGACY=\047/, "") }
  on {
    if (index($0, "\047")) { sub(/\047.*$/, ""); print; on = 0; exit }
    print
  }
  END { if (!found || on) exit 3 }
' "$DIR/check-hooks.sh" 2>/dev/null)
LEGACY_STATUS=$?
if [ "$LEGACY_STATUS" = 3 ] || [ ! -f "$DIR/check-hooks.sh" ]; then
  echo "$NAME: refused, and nothing was written:"
  echo "  $GIVEN/check-hooks.sh holds no REQUIREMENTS_LEGACY literal, so which entries stay hand-written cannot be read"
  exit 1
elif [ "$LEGACY_STATUS" != 0 ]; then
  echo "$NAME: reading check-hooks.sh failed, awk exit $LEGACY_STATUS; nothing was written"
  exit 1
fi
LEGACY=" $(printf '%s ' $LEGACY)"

DECLARED=$( (set +f; cd -- "$STAGE" && for f in GH-*; do [ -f "$f" ] && printf '%s\n' "$f"; done) | LC_ALL=C sort -V)

# WHOSE EACH FILE IS, by the legacy set, in `generated_bad`'s words: a legacy
# ID declared, an ID declared outside its own issue's file, a legacy file
# carrying the generated field, and a file outside the legacy set that nothing
# declares. A declared ID whose file lacks the field is none of these: it is
# stale, and a run writes it.
for id in $DECLARED; do
  rel=$(sed -n '$s/^- generated: //p' "$STAGE/$id")
  n=${id#GH-}; n=${n%%.*}
  case "$LEGACY" in
    *" $id "*) printf '%s\n' "$id: declared in $rel, and a legacy entry, which stays hand-written" >> "$STAGE/.problems"; continue ;;
  esac
  [ "$rel" = "checks/GH-$n.sh" ] \
    || printf '%s\n' "$id: declared in $rel, where an entry of #$n is declared in checks/GH-$n.sh" >> "$STAGE/.problems"
done
if [ -d "$SPLIT" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    id=${f%.md}
    case "$LEGACY" in
      *" $id "*) grep -q '^- generated:' -- "$SPLIT/$f" \
                   && printf '%s\n' "requirements/$f: a legacy entry carrying a generated field, which only a declared entry's file carries" >> "$STAGE/.problems" ;;
      *) [ -f "$STAGE/$id" ] \
           || printf '%s\n' "requirements/$f: outside the legacy set, and no issue file declares it" >> "$STAGE/.problems" ;;
    esac
  done < <( (set +f; cd -- "$SPLIT" && for f in GH-*.md; do [ -f "$f" ] && printf '%s\n' "$f"; done) | LC_ALL=C sort -V)
fi

if [ -s "$STAGE/.problems" ]; then
  echo "$NAME: refused, and nothing was written:"
  sed 's/^/  /' "$STAGE/.problems"
  exit 1
fi

# What differs: a declared entry whose file is not there, or is not byte for
# byte what its declaration would write.
STALE=
for id in $DECLARED; do
  cmp -s -- "$STAGE/$id" "$SPLIT/$id.md" || STALE="$STALE $id"
done

if [ -n "$CHECK" ]; then
  if [ -n "$STALE" ]; then
    echo "$NAME: not what the issue files declare:"
    for id in $STALE; do
      if [ -e "$SPLIT/$id.md" ]; then
        printf '  requirements/%s.md differs from its declaration in %s\n' "$id" "$(sed -n '$s/^- generated: //p' "$STAGE/$id")"
      else
        printf '  requirements/%s.md is not written; %s declares it\n' "$id" "$(sed -n '$s/^- generated: //p' "$STAGE/$id")"
      fi
    done
    exit 1
  fi
  if [ -n "$DECLARED" ]; then
    printf '%s: every generated entry is its declaration: %s\n' "$NAME" "$(printf '%s' "$DECLARED" | tr '\n' ' ')"
  else
    printf '%s: no issue file declares an entry\n' "$NAME"
  fi
  exit 0
fi

if [ -z "$STALE" ]; then
  echo "$NAME: every generated entry is its declaration; nothing was written"
  exit 0
fi
mkdir -p -- "$SPLIT" || exit 1
# Each file through a temporary one beside it, moved into place: a rename in
# one directory replaces the destination whole, where a `cp` over it -- what
# this did until #223 -- leaves it truncated when it fails midway. The mode is
# the one a `cp` would have given a new file, since mktemp's is 0600.
MODE=$(printf '%o' "$(( 0666 & ~0$(umask) ))")
for id in $STALE; do
  TMP=$(mktemp "$SPLIT/.$id.md.XXXXXX") \
    && cp -- "$STAGE/$id" "$TMP" && chmod "$MODE" "$TMP" && mv -f -- "$TMP" "$SPLIT/$id.md" || {
    echo "$NAME: writing requirements/$id.md failed, and it holds what it held before; the files named above were written"
    exit 1
  }
  TMP=
  printf 'wrote requirements/%s.md\n' "$id"
done
exit 0

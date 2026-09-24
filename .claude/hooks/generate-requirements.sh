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
# nothing else: every line opens a field or continues one. Its file is the
# heading, the body byte for byte, and a last field naming where it was
# declared -- `- generated: checks/GH-<n>.sh` -- which is what tells a reader
# not to edit it, and what tells this script the file is its own to rewrite.
#
# WHAT IT REFUSES, before it writes anything: a line whose first word, after
# any indentation, is `requirement` followed by `GH-`, spelled any other way --
# indented, unquoted, a delimiter other than REQ, a second word after the ID,
# whether a space or a tab stands before it --
# because the suite runs the file and reads what
# bash read, and a spelling this reads differently from bash is a second
# parser that can disagree with the first; an ID outside the grammar; an ID
# declared twice; a declaration never closed; a body that is empty, holds a
# line that is no field, or carries a `generated` field of its own; a declared
# ID whose file is there and is not generated, which is hand-written and not
# this script's to replace; and a generated file whose ID no issue file
# declares any more, which a declaration taken away has left behind.
#
# WHAT IT DOES NOT SEE, named: a call whose first word is not `requirement` --
# `x=1 requirement GH-7 <<'REQ'` -- or whose ID is quoted or built by another
# command. Such a line is none of this script's; bash still runs it, and the
# suite, which records what bash declared, finds the entry declared and not
# written.
#
# WHAT IT DOES NOT DECIDE, named. Whether an entry outside the legacy set is
# generated at all, and whether a legacy ID is declared -- the set is the
# suite's, and the suite asks both. And whether bash reads a declaration the
# way this does: the suite records every `requirement` call it runs and holds
# each file to that record too, so the two readings meet in the files.
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
    *) [ -z "$DIR" ] || usage; DIR=$1; shift ;;
  esac
done
[ -n "$DIR" ] || DIR=$(dirname -- "$0")
SPLIT="$DIR/requirements"
NAME=generate-requirements.sh
# Globbing off for every unquoted list below; the two listings that need a
# glob turn it on in their own subshell.
set -f

# The issue files, in version order on the issue number, so that what this
# prints is in one order whatever the directory listing says.
ISSUE_FILES=()
while IFS= read -r f; do
  [ -n "$f" ] && ISSUE_FILES+=("$DIR/checks/$f")
done < <( (set +f; cd -- "$DIR/checks" 2>/dev/null && for f in GH-*.sh; do [ -f "$f" ] && printf '%s\n' "$f"; done) | LC_ALL=C sort -V)

STAGE=$(mktemp -d) || exit 1
trap 'rm -rf "$STAGE"' EXIT

# One awk program reads every issue file. Each declaration it accepts is staged
# as $STAGE/<ID>, the file it would write; each thing it refuses is a line of
# $STAGE/.problems. `rel` is the issue file's path relative to the hooks
# directory, which is what the `generated` field names.
awk -v stage="$STAGE" '
  function problem(s) { print s >> (stage "/.problems") }
  FNR == 1 {
    if (open != "") problem(rel ": " openid " is declared at line " openline " and never closed by a line reading REQ")
    open = ""; rel = FILENAME; sub(/^.*\/checks\//, "checks/", rel)
  }
  open != "" {
    if ($0 == "REQ") {
      if (nbody == 0) problem(rel ": line " openline ": " openid " is declared with no fields")
      else if (!(openid in seen)) { seen[openid] = rel; ids[++nids] = openid; doc[openid] = "### " openid "\n" body "- generated: " rel "\n" }
      else problem(openid ": declared twice, in " seen[openid] " and in " rel)
      open = ""; next
    }
    if ($0 ~ /^- generated:/) problem(rel ": line " FNR ": " openid " carries a generated field of its own, which is this script'"'"'s to write")
    else if ($0 ~ /^[ \t]*$/) problem(rel ": line " FNR ": " openid ": a blank line, where every line opens a field or continues one")
    else if ($0 !~ /^- [a-z-]+:/ && !(nbody > 0 && $0 ~ /^  [^ ]/)) problem(rel ": line " FNR ": " openid ": a line that is no field of the entry: " $0)
    body = body $0 "\n"; nbody++; next
  }
  /^[ \t]*requirement[ \t]+GH-/ {
    if ($0 !~ /^requirement GH-[^ \t]+ <<'"'"'REQ'"'"'$/) { problem(rel ": line " FNR ": a declaration spelled other than requirement <ID> <<'"'"'REQ'"'"': " $0); next }
    openid = $2
    if (openid !~ /^GH-[1-9][0-9]*(\.[1-9][0-9]*)?$/) { problem(rel ": line " FNR ": " openid " is not an ID of the grammar GH-<n> or GH-<n>.<m>"); openid = "(" openid ")" }
    open = "y"; openline = FNR; body = ""; nbody = 0
    next
  }
  END {
    if (open != "") problem(rel ": " openid " is declared at line " openline " and never closed by a line reading REQ")
    for (i = 1; i <= nids; i++) if (ids[i] !~ /^\(/) { f = stage "/" ids[i]; printf "%s", doc[ids[i]] > f; close(f) }
  }
' ${ISSUE_FILES[@]+"${ISSUE_FILES[@]}"} </dev/null

DECLARED=$( (set +f; cd -- "$STAGE" && for f in GH-*; do [ -f "$f" ] && printf '%s\n' "$f"; done) | LC_ALL=C sort -V)

# A declared ID whose file is hand-written, and a generated file nothing
# declares. A file is generated when a line of it opens the generated field.
for id in $DECLARED; do
  f="$SPLIT/$id.md"
  if [ -e "$f" ] && ! grep -q '^- generated:' -- "$f"; then
    printf '%s\n' "$id: declared in $(sed -n 's/^- generated: //p' "$STAGE/$id"), and requirements/$id.md is hand-written, which this does not replace" >> "$STAGE/.problems"
  fi
done
if [ -d "$SPLIT" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    id=${f%.md}
    [ -f "$STAGE/$id" ] || printf '%s\n' "requirements/$f: generated from $(sed -n 's/^- generated: //p' "$SPLIT/$f" | head -n 1), which no longer declares $id" >> "$STAGE/.problems"
  done < <( (set +f; cd -- "$SPLIT" && for f in GH-*.md; do [ -f "$f" ] && grep -q '^- generated:' -- "$f" && printf '%s\n' "$f"; done) | LC_ALL=C sort -V)
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
        printf '  requirements/%s.md differs from its declaration in %s\n' "$id" "$(sed -n 's/^- generated: //p' "$STAGE/$id")"
      else
        printf '  requirements/%s.md is not written; %s declares it\n' "$id" "$(sed -n 's/^- generated: //p' "$STAGE/$id")"
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
for id in $STALE; do
  cp -- "$STAGE/$id" "$SPLIT/$id.md" || exit 1
  printf 'wrote requirements/%s.md\n' "$id"
done
exit 0

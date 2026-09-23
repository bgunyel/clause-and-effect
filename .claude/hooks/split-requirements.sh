#!/usr/bin/env bash
# Move every `GH-` entry out of requirements.md into a file of its own under
# requirements/, named by its ID (#200). Not a hook: settings.json does not run
# it, and nothing runs it for you.
#
#   bash .claude/hooks/split-requirements.sh [<hooks directory>]
#
# WHY THE LEDGER IS SPLIT. requirements.md held two populations with opposite
# write patterns: the stated boundary (`US-`, `FR-`), written rarely and on
# purpose, and the `GH-` defect ledger, appended by every review loop. Holding
# both in one file made every pair of concurrent worktree branches competing
# writers of one hunk -- six merges of six on 2026-09-20 conflicted there, and
# none of them on code. A `GH-` ID is unique and issue-derived, so one file per
# ID cannot collide unless two loops mint the same ID, and then git reports an
# add/add conflict on one path, which is the informative kind.
#
# WHY THIS IS A SCRIPT AND NOT ONLY A COMMIT. The split was made while three
# pull requests that append `GH-` entries to requirements.md were still open.
# Each of them, once it merges the dev branch that carries the split, holds its
# own entries in requirements.md again, and this is what moves them: it is
# re-runnable, and running it on a tree already split does nothing.
#
# WHAT IT DOES, and nothing else. Every `### GH-` heading under one of the three
# `##` sections that hold requirements opens a block, which runs to the line
# before the next `### ` or `## ` heading; trailing blank lines are the
# separator between entries and belong to neither. The block is written to
# requirements/<ID>.md byte for byte, and it and its separator are taken out of
# requirements.md. No entry is reworded, reordered internally or corrected.
# Byte for byte with one exception, taken knowingly: awk ends every line it
# prints with a newline, so a requirements.md whose last line has none gains one
# in whichever file that line lands. The suite reads the two alike, and pins it.
#
# WHAT IT REFUSES, before it writes anything. Everything the suite's reader
# (FR-45, REQUIREMENTS_AWK's `take`) would refuse in a file this writes, and
# three things of its own. Of the reader's: a heading that is more than its ID
# -- `### GH-7 (reopened)` would be written to GH-7.md, and the reader reads the
# whole heading -- and a line inside the block that is neither a `- key:` field,
# nor the continuation of one, nor blank. The second is the one a merge makes:
# an entry appended directly under `## Boundary issues` sits above the pointer
# paragraph there, the block runs to the next heading, and moving it would carry
# the paragraph into the entry's file, out of requirements.md, where the reader
# goes red on the entry file and the repair it invites deletes the paragraph for
# good (rev-agent-200, round 1 of PR #210). The reader's other split-set rules
# are ones this cannot produce: a block opens at its heading, so nothing stands
# before it, and ends at the next `###` or `##`, so a file holds one entry and
# no `##` heading. And the one rule the reader keeps about requirements.md
# itself that a `GH-` heading can break: it reads entries under the three
# requirement sections only, so a `### GH-` heading under any other `##`
# heading, or before the first, is refused here too, with where it stands,
# rather than passed over with "nothing to move" (rev-agent-200, round 2 of
# PR #210). Of its own: an ID outside the grammar *The families* states,
# an ID moved twice, and a file already under requirements/ whose content
# differs from the block that would replace it -- the last is two loops having
# written one ID, and which of them is right is a person's call. A file that
# already holds exactly that block is left alone, which is what makes a second
# run a no-op.
set -u

DIR=${1:-$(dirname -- "$0")}
REQS="$DIR/requirements.md"
SPLIT="$DIR/requirements"
[ -r "$REQS" ] || { echo "split-requirements.sh: $REQS is not a readable file; nothing was moved" >&2; exit 1; }
[ ! -e "$SPLIT" ] || [ -d "$SPLIT" ] || { echo "split-requirements.sh: $SPLIT is there and is not a directory; nothing was moved" >&2; exit 1; }

STAGE=$(mktemp -d) || { echo "split-requirements.sh: mktemp -d failed; nothing was moved" >&2; exit 1; }
trap 'rm -rf -- "$STAGE"' EXIT
mkdir -- "$STAGE/entries"

# Blank lines are held back rather than printed, so that a run of them is given
# to whatever comes next: to the file when the next line is the file's, and to
# nothing when the next line opens a `GH-` entry or ends one.
awk -v stage="$STAGE" '
  function flush_entry() {
    # Nothing is written once an ID has been refused, and a refused ID never
    # names a file: it is outside the grammar, so it could name any path.
    if (id == "" || bad) { id = ""; body = ""; return }
    printf "%s", body > (stage "/entries/" id ".md"); close(stage "/entries/" id ".md")
    print id > (stage "/moved"); id = ""; body = ""
  }
  /^## / {
    flush_entry()
    part = ($0 ~ /^## (User stories|Functional requirements|Boundary issues)$/) ? "req" : "other"
    heading = $0
  }
  # A `GH-` heading anywhere else is refused, not moved and not passed over: the
  # reader refuses it under every other heading and before the first, and a
  # run that said "no GH- entry; nothing to move" of a file holding one sent
  # the person to a red it did not explain. It is where a merge lands an entry
  # it resolved by hand, `## Provenance` being the heading after
  # `## Boundary issues` (rev-agent-200, round 2 of PR #210).
  /^### / && part != "req" && $2 ~ /^GH-/ {
    print "line " NR ": " $2 ": a GH- entry " (heading == "" ? "before the first ## heading" : "under \"" heading "\"") ", where the reader reads none; move it to the end of ## Boundary issues and run this again" > (stage "/refused"); bad = 1
    next
  }
  /^### / {
    flush_entry()
    if (part == "req" && $2 ~ /^GH-/) {
      # The whole heading, trimmed, as the reader reads it -- not the word awk
      # splits off it.
      hid = substr($0, 5); sub(/^[ \t]+/, "", hid); sub(/[ \t]+$/, "", hid)
      if (hid != $2) { print "line " NR ": " hid ": a heading is its ID and nothing else, and the file would be named " $2 ".md" > (stage "/refused"); bad = 1 }
      else if ($2 !~ /^GH-[1-9][0-9]*(\.[1-9][0-9]*)?$/) { print $2 ": not an ID of the GH family grammar, ^GH-[1-9][0-9]*(\\.[1-9][0-9]*)?$" > (stage "/refused"); bad = 1 }
      else if ($2 in seen) { print $2 ": the ID is used twice" > (stage "/refused"); bad = 1 }
      seen[$2] = 1; id = $2; body = $0 "\n"; held = ""; field = 0; stray = 0; next
    }
  }
  /^[ \t]*$/ { held = held $0 "\n"; next }
  # The field grammar the reader holds: `- key:` opens a field, two spaces and
  # then a non-space continue the one before, and anything else after the
  # heading is a line that is no field of the entry. One report per entry: the
  # first line of a paragraph says where it is, and the rest says nothing more.
  id != "" {
    if ($0 ~ /^- [a-z-]+:/) field = 1
    else if (!(field && $0 ~ /^  [^ ]/)) {
      field = 0
      if (!stray++) { print "line " NR ": " id ": a line that is no field of the entry, which would be moved into requirements/" id ".md with it; move the line above the heading of the entry: " $0 > (stage "/refused"); bad = 1 }
    }
    body = body held $0 "\n"; held = ""; next
  }
  { printf "%s%s\n", held, $0 > (stage "/requirements.md"); held = "" }
  END {
    flush_entry()
    if (held != "") printf "%s", held > (stage "/requirements.md")
    exit bad
  }' "$REQS" || {
  if [ -s "$STAGE/refused" ]; then
    echo "split-requirements.sh: refused, and nothing was moved:" >&2
    sed 's/^/  /' "$STAGE/refused" >&2
  else
    echo "split-requirements.sh: awk could not read $REQS; nothing was moved" >&2
  fi
  exit 1
}

if [ ! -s "$STAGE/moved" ]; then
  echo "requirements.md holds no GH- entry; nothing to move"
  exit 0
fi

CONFLICTS=
while IFS= read -r id; do
  if [ -e "$SPLIT/$id.md" ] && ! cmp -s -- "$STAGE/entries/$id.md" "$SPLIT/$id.md"; then
    CONFLICTS="$CONFLICTS  $id: requirements/$id.md is there already and holds something else
"
  fi
done < "$STAGE/moved"
if [ -n "$CONFLICTS" ]; then
  printf 'split-requirements.sh: refused, and nothing was moved:\n%s' "$CONFLICTS" >&2
  exit 1
fi

mkdir -p -- "$SPLIT" || { echo "split-requirements.sh: could not make $SPLIT; nothing was moved" >&2; exit 1; }
# Which files are new is said apart from which were there already, because a
# branch merging the split holds some of each, and the new ones are the ones it
# has to look at. One line saying "moved" of both hid that.
WRITTEN=
KEPT=
while IFS= read -r id; do
  if [ -e "$SPLIT/$id.md" ]; then
    KEPT="$KEPT $id"
    continue
  fi
  cp -- "$STAGE/entries/$id.md" "$SPLIT/$id.md" || {
    echo "split-requirements.sh: could not write requirements/$id.md; requirements.md is unchanged, and the files written before it stay" >&2
    exit 1
  }
  WRITTEN="$WRITTEN $id"
done < "$STAGE/moved"
cp -- "$STAGE/requirements.md" "$REQS" || { echo "split-requirements.sh: could not rewrite $REQS; every entry is in requirements/ and also still in it" >&2; exit 1; }
printf 'taken out of requirements.md: %s\n' "$(paste -sd ' ' "$STAGE/moved")"
[ -z "$WRITTEN" ] || printf 'files written to requirements/:%s\n' "$WRITTEN"
[ -z "$KEPT" ] || printf 'already in requirements/ with the same bytes, and left as it was:%s\n' "$KEPT"

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
#
# WHAT IT REFUSES, before it writes anything. An ID outside the grammar *The
# families* states, an ID moved twice, and a file already under requirements/
# whose content differs from the block that would replace it -- the last is two
# loops having written one ID, and which of them is right is a person's call. A
# file that already holds exactly that block is left alone, which is what makes
# a second run a no-op.
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
  }
  /^### / {
    flush_entry()
    if (part == "req" && $2 ~ /^GH-/) {
      if ($2 !~ /^GH-[1-9][0-9]*(\.[1-9][0-9]*)?$/) { print $2 ": not an ID of the GH family grammar, ^GH-[1-9][0-9]*(\\.[1-9][0-9]*)?$" > (stage "/refused"); bad = 1 }
      else if ($2 in seen) { print $2 ": the ID is used twice" > (stage "/refused"); bad = 1 }
      seen[$2] = 1; id = $2; body = $0 "\n"; held = ""; next
    }
  }
  /^[ \t]*$/ { held = held $0 "\n"; next }
  id != "" { body = body held $0 "\n"; held = ""; next }
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
while IFS= read -r id; do
  [ -e "$SPLIT/$id.md" ] || cp -- "$STAGE/entries/$id.md" "$SPLIT/$id.md" || {
    echo "split-requirements.sh: could not write requirements/$id.md; requirements.md is unchanged, and the files written before it stay" >&2
    exit 1
  }
done < "$STAGE/moved"
cp -- "$STAGE/requirements.md" "$REQS" || { echo "split-requirements.sh: could not rewrite $REQS; every entry is in requirements/ and also still in it" >&2; exit 1; }
printf 'moved %s GH- entries into requirements/: %s\n' "$(grep -c . "$STAGE/moved")" "$(paste -sd ' ' "$STAGE/moved")"

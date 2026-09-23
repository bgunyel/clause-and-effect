#!/usr/bin/env bash
# Move every `GH-` entry out of requirements.md into a file of its own under
# requirements/, named by its ID (#200). Not a hook: settings.json does not run
# it, and nothing runs it for you.
#
#   bash .claude/hooks/split-requirements.sh [--base <rev> --branch <rev>] [--resolved <ID>]... [<hooks directory>]
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
# THREE WAYS, ON THE MERGE THAT BRINGS THE SPLIT. Such a merge is a content
# conflict on requirements.md, the branch's whole `GH-` section against the dev
# side's pointer paragraph, and neither way of resolving it by hand is safe on
# its own. Keeping the dev side throws away every edit the branch made to an
# entry that already existed, silently, and a two-way run then says there is
# nothing to move while GH-200.4's literal vouches for the stale file. Keeping
# the branch side refuses every entry that differs from its file, but half of
# those are the branch's stale copies of entries the dev side changed, and two
# sides cannot say which is newer. Measured on #158 and #184 (rev-agent-200,
# round 4 of PR #210). So during a merge this reads the base and the branch
# side out of git, whatever the working tree was resolved to, and for each
# `GH-` entry of the branch asks who changed it since the base: the branch
# only, and its version is written, with the SPLIT_MOVED token that has to
# move; the dev side only, and its file is kept; both, and it is refused.
#
# "Whatever the working tree was resolved to" is true of the entries and of
# nothing else in requirements.md. Resolve that file hunk by hunk: a side kept
# whole drops the other side's changes outside the entries, and a run that
# sees requirements.md differ from the dev side's there says so.
#
# WHEN IT COMPARES THREE WAYS is decided by the state of the repository, not by
# how this was called -- a directory argument and a rebase each fell through to
# the two-way run once, with the edits lost (rev-agent-200, round 5): during a
# merge; on a last commit that is the merge that brought the split; and with
# `--base <where the branch forked> --branch <the branch as it was before>`,
# which is how a merge finished earlier, or a rebase, is asked. A rebase,
# cherry-pick, revert or squash merge in progress is refused, and so is an
# unmerged requirements.md. Otherwise it is the two-way run the rest of this
# header describes. Every refusal of an entry whose file differs -- the four
# three-way ones, and the two-way conflict -- ends in a step a second run
# accepts: make requirements/<ID>.md right by hand and name the entry with
# `--resolved <ID>`, which leaves that file as it is.
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
# differs from the block that would replace it -- in a two-way run, and in a
# three-way run where the base does not hold the ID, that is two loops having
# written one ID, and which of them is right is a person's call. A three-way run
# also refuses an entry changed on both sides since the base, an entry the base
# holds and the branch does not, and an entry requirements.md holds in a version
# the branch never committed, which a run that writes the branch's would lose.
# A file that already holds exactly that block is left alone, which is what
# makes a second run a no-op.
set -u

usage() {
  echo "usage: bash .claude/hooks/split-requirements.sh [--base <rev> --branch <rev>] [--resolved <ID>]... [<hooks directory>]" >&2
  exit 64
}
BASE_REV=
BRANCH_REV=
DIR=
RESOLVED=' '
while [ $# -gt 0 ]; do
  case $1 in
    --base) [ $# -ge 2 ] || usage; BASE_REV=$2; shift 2 ;;
    --branch) [ $# -ge 2 ] || usage; BRANCH_REV=$2; shift 2 ;;
    --resolved) [ $# -ge 2 ] || usage; RESOLVED="$RESOLVED$2 "; shift 2 ;;
    -*) usage ;;
    *) [ -z "$DIR" ] || usage; DIR=$1; shift ;;
  esac
done
# Both or neither: a base with no branch, or a branch with no base, is half of
# a three-way comparison, and there is no half that means anything.
if { [ -n "$BASE_REV" ] && [ -z "$BRANCH_REV" ]; } || { [ -z "$BASE_REV" ] && [ -n "$BRANCH_REV" ]; }; then
  usage
fi
[ -n "$DIR" ] || DIR=$(dirname -- "$0")
REQS="$DIR/requirements.md"
SPLIT="$DIR/requirements"
[ -r "$REQS" ] || { echo "split-requirements.sh: $REQS is not a readable file; nothing was moved" >&2; exit 1; }
[ ! -e "$SPLIT" ] || [ -d "$SPLIT" ] || { echo "split-requirements.sh: $SPLIT is there and is not a directory; nothing was moved" >&2; exit 1; }

g() { git -C "$DIR" "$@"; }
resolved() { case $RESOLVED in *" $1 "*) return 0 ;; esac; return 1; }
holds_gh() { g show "$1:./requirements.md" 2> /dev/null | grep -q '^### GH-'; }
stop() { echo "split-requirements.sh: $*; nothing was moved" >&2; exit 1; }

# HOW THE SPLIT ARRIVES decides how it is compared, and every way is asked
# before a line is read -- whatever the directory argument says, because the
# state of the repository is what makes a two-way run wrong, not how this was
# called. The first version asked only about a merge in progress, and only
# with no directory given; a directory given during a merge, and a rebase,
# each fell through to the two-way run and its "nothing to move", exit 0, with
# the branch's edits lost (rev-agent-200, round 5 of PR #210). So:
#   - requirements.md unmerged: refused. The branch's entries are read out of
#     git, so which side of them is kept does not matter, but the conflict
#     markers would be read as stray lines inside an entry, and the remedy that
#     refusal gives is the wrong one here.
#   - a rebase, cherry-pick, revert or squash merge in progress: refused. Each
#     replays commits one at a time, and this compares an entry across one
#     merge; finish it with a merge instead, or finish it and name the base and
#     the branch.
#   - a merge in progress: three ways, the branch being whichever side still
#     holds `GH-` entries in its requirements.md.
#   - the last commit a merge that brought the split: three ways the same,
#     which is what a merge resolved in a web page leaves behind.
#   - --base and --branch: three ways, as given.
#   - none of these: two ways.
# Outside a git repository -- the suite's fixtures -- only the last applies.
DEV_REV=
MODE=
if g rev-parse --git-dir > /dev/null 2>&1; then
  [ -z "$(g ls-files -u -- requirements.md)" ] || stop "requirements.md is unmerged. Resolve it first, hunk by hunk: the GH- entries are read out of git, so either side of those will do, but keep the dev side's pointer paragraph and whatever else either side changed outside them; then run this again"
  GITDIR=$(g rev-parse --absolute-git-dir)
  if [ -z "$BASE_REV" ]; then
    INFLIGHT=
    if [ -e "$GITDIR/rebase-merge" ] || [ -e "$GITDIR/rebase-apply" ] || g rev-parse -q --verify REBASE_HEAD > /dev/null 2>&1; then INFLIGHT="a rebase"
    elif g rev-parse -q --verify CHERRY_PICK_HEAD > /dev/null 2>&1; then INFLIGHT="a cherry-pick"
    elif g rev-parse -q --verify REVERT_HEAD > /dev/null 2>&1; then INFLIGHT="a revert"
    elif [ -e "$GITDIR/SQUASH_MSG" ] && ! g rev-parse -q --verify MERGE_HEAD > /dev/null 2>&1; then INFLIGHT="a squash merge"
    fi
    [ -z "$INFLIGHT" ] || stop "$INFLIGHT is in progress, and this compares a GH- entry across one merge, not across commits replayed one at a time. Abort it and bring the dev branch in with a merge, then run this during that merge; or finish it and run this with --base <where the branch forked> --branch <the branch as it was before>"
    if g rev-parse -q --verify MERGE_HEAD > /dev/null 2>&1; then
      if holds_gh HEAD && ! holds_gh MERGE_HEAD; then BRANCH_REV=HEAD; DEV_REV=MERGE_HEAD
      elif holds_gh MERGE_HEAD && ! holds_gh HEAD; then BRANCH_REV=MERGE_HEAD; DEV_REV=HEAD
      fi
      if [ -n "$BRANCH_REV" ]; then
        BASE_REV=$(g merge-base HEAD MERGE_HEAD) || stop "a merge is in progress and git names no merge base for it"
        MODE="a merge is in progress"
      fi
    elif g rev-parse -q --verify HEAD^2 > /dev/null 2>&1 && ! holds_gh HEAD; then
      if holds_gh HEAD^1 && ! holds_gh HEAD^2; then BRANCH_REV=HEAD^1; DEV_REV=HEAD^2
      elif holds_gh HEAD^2 && ! holds_gh HEAD^1; then BRANCH_REV=HEAD^2; DEV_REV=HEAD^1
      fi
      if [ -n "$BRANCH_REV" ]; then
        BASE_REV=$(g merge-base HEAD^1 HEAD^2) || stop "the last commit is a merge and git names no merge base for it"
        MODE="the last commit is a merge that brought the split"
      fi
    fi
    [ -z "$MODE" ] || echo "$MODE: each GH- entry is compared three ways, against the merge base $(g rev-parse --short "$BASE_REV") and $BRANCH_REV at $(g rev-parse --short "$BRANCH_REV")"
  fi
fi
if [ -n "$BASE_REV" ]; then
  for rev in "$BASE_REV" "$BRANCH_REV"; do
    g rev-parse -q --verify "$rev^{commit}" > /dev/null 2>&1 || stop "$rev is not a commit in the repository that holds $DIR"
  done
fi

STAGE=$(mktemp -d) || { echo "split-requirements.sh: mktemp -d failed; nothing was moved" >&2; exit 1; }
trap 'rm -rf -- "$STAGE"' EXIT

# Blank lines are held back rather than printed, so that a run of them is given
# to whatever comes next: to the file when the next line is the file's, and to
# nothing when the next line opens a `GH-` entry or ends one.
EXTRACT=$(cat <<'AWK'
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
  # The remedy takes the line clear of every entry at once. It said "above the
  # heading of the entry", which only moves the line into the entry before: with
  # two entries appended above a paragraph, each run refused the next one up,
  # one run per entry (rev-agent-200, round 3 of PR #210).
  id != "" {
    if ($0 ~ /^- [a-z-]+:/) field = 1
    else if (!(field && $0 ~ /^  [^ ]/)) {
      field = 0
      if (!stray++) { print "line " NR ": " id ": a line that is no field of the entry, which would be moved into requirements/" id ".md with it; take the line out of every entry: put the GH- entries of this section below it, or it above the first of them: " $0 > (stage "/refused"); bad = 1 }
    }
    body = body held $0 "\n"; held = ""; next
  }
  { printf "%s%s\n", held, $0 > (stage "/requirements.md"); held = "" }
  END {
    flush_entry()
    if (held != "") printf "%s", held > (stage "/requirements.md")
    exit bad
  }
AWK
)
extract() {  # extract <requirements.md> <stage> -- its GH- entries under <stage>/entries, in order in <stage>/moved
  mkdir -p -- "$2/entries" && : > "$2/moved" && awk -v stage="$2" "$EXTRACT" "$1"
}
refused() {  # refused <file of refusals> -- prints them and stops
  echo "split-requirements.sh: refused, and nothing was moved:" >&2
  sed 's/^/  /' "$1" >&2
  exit 1
}

extract "$REQS" "$STAGE/w" || {
  [ -s "$STAGE/w/refused" ] && refused "$STAGE/w/refused"
  echo "split-requirements.sh: awk could not read $REQS; nothing was moved" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# TWO WAYS: requirements.md against the files. What it holds is what moves.
# ---------------------------------------------------------------------------
if [ -z "$BASE_REV" ]; then
  if [ ! -s "$STAGE/w/moved" ]; then
    echo "requirements.md holds no GH- entry; nothing to move"
    # Not a reassurance about a merge or rebase already finished: its branch
    # side is in git, and only a three-way run reads it there. A merge in
    # progress, or one that is the last commit, never reaches this line.
    echo "(a merge of the split finished before the last commit, or a rebase, is compared three ways with --base <where the branch forked> --branch <the branch as it was before>)"
    exit 0
  fi
  CONFLICTS=
  while IFS= read -r id; do
    if [ -e "$SPLIT/$id.md" ] && ! resolved "$id" && ! cmp -s -- "$STAGE/w/entries/$id.md" "$SPLIT/$id.md"; then
      CONFLICTS="$CONFLICTS$id: requirements/$id.md is there already and holds something else. Two loops wrote this ID, or a merge or rebase of the split finished earlier, which --base and --branch compare three ways; once the file is the right one, run this again with --resolved $id
"
    fi
  done < "$STAGE/w/moved"
  if [ -n "$CONFLICTS" ]; then
    printf '%s' "$CONFLICTS" > "$STAGE/refused"
    refused "$STAGE/refused"
  fi
  for id in $RESOLVED; do
    [ -f "$SPLIT/$id.md" ] || stop "--resolved $id names no file requirements/$id.md, which is what it leaves as it is"
  done
  mkdir -p -- "$SPLIT" || { echo "split-requirements.sh: could not make $SPLIT; nothing was moved" >&2; exit 1; }
  # Which files are new is said apart from which were there already, because a
  # branch merging the split holds some of each, and the new ones are the ones
  # it has to look at. One line saying "moved" of both hid that.
  WRITTEN=
  KEPT=
  RES=${RESOLVED% }
  while IFS= read -r id; do
    resolved "$id" && continue
    if [ -e "$SPLIT/$id.md" ]; then
      KEPT="$KEPT $id"
      continue
    fi
    cp -- "$STAGE/w/entries/$id.md" "$SPLIT/$id.md" || {
      echo "split-requirements.sh: could not write requirements/$id.md; requirements.md is unchanged, and the files written before it stay" >&2
      exit 1
    }
    WRITTEN="$WRITTEN $id"
  done < "$STAGE/w/moved"
  cp -- "$STAGE/w/requirements.md" "$REQS" || { echo "split-requirements.sh: could not rewrite $REQS; every entry is in requirements/ and also still in it" >&2; exit 1; }
  printf 'taken out of requirements.md: %s\n' "$(paste -sd ' ' "$STAGE/w/moved")"
  [ -z "$WRITTEN" ] || printf 'files written to requirements/:%s\n' "$WRITTEN"
  [ -z "$KEPT" ] || printf 'already in requirements/ with the same bytes, and left as it was:%s\n' "$KEPT"
  [ -z "$RES" ] || printf 'resolved by hand, and left as it was:%s\n' "$RES"
  exit 0
fi

# ---------------------------------------------------------------------------
# THREE WAYS: the base, the branch, and the file the dev side holds.
# ---------------------------------------------------------------------------
# Both sides of the comparison are read out of git, never out of the working
# tree: a merge resolved by keeping the dev side of requirements.md has thrown
# the branch's entries away there, and they are still in the branch's commit.
g show "$BASE_REV:./requirements.md" > "$STAGE/base.md" 2> /dev/null \
  || { echo "split-requirements.sh: $BASE_REV holds no requirements.md at the path of $DIR; nothing was moved" >&2; exit 1; }
g show "$BRANCH_REV:./requirements.md" > "$STAGE/branch.md" 2> /dev/null \
  || { echo "split-requirements.sh: $BRANCH_REV holds no requirements.md at the path of $DIR; nothing was moved" >&2; exit 1; }
extract "$STAGE/base.md" "$STAGE/b" || {
  echo "split-requirements.sh: the base's requirements.md is one this cannot read into entries, so nothing can be compared with it; nothing was moved" >&2
  [ ! -s "$STAGE/b/refused" ] || sed 's/^/  /' "$STAGE/b/refused" >&2
  exit 1
}
extract "$STAGE/branch.md" "$STAGE/r" || {
  [ -s "$STAGE/r/refused" ] && { sed "s/^/$BRANCH_REV: /" "$STAGE/r/refused" > "$STAGE/refused"; refused "$STAGE/refused"; }
  echo "split-requirements.sh: awk could not read $BRANCH_REV's requirements.md; nothing was moved" >&2
  exit 1
}
if [ ! -s "$STAGE/w/moved" ] && [ ! -s "$STAGE/r/moved" ]; then
  echo "neither requirements.md nor $BRANCH_REV holds a GH- entry; nothing to move"
  exit 0
fi

: > "$STAGE/refused"
# What requirements.md holds is taken out of it and never written anywhere:
# each entry there must be the branch's own, because a version the branch never
# committed would be lost by a run that writes the branch's.
#
# EVERY REFUSAL HERE NAMES A WAY OUT THAT A SECOND RUN ACCEPTS. The branch side
# is read out of git on every run, so a remedy of "fix it by hand and run this
# again" is refused again for the same reason; each says what to carry by hand
# and then to name the entry with --resolved, which leaves requirements/<ID>.md
# as the person left it (rev-agent-200's round 5 asked that every message
# sending the person somewhere be swept; these four did not converge).
while IFS= read -r id; do
  resolved "$id" && continue
  if [ ! -e "$STAGE/r/entries/$id.md" ]; then
    echo "$id: requirements.md holds it and $BRANCH_REV does not. Carry it into requirements/$id.md by hand, then run this again with --resolved $id" >> "$STAGE/refused"
  elif ! cmp -s -- "$STAGE/w/entries/$id.md" "$STAGE/r/entries/$id.md"; then
    echo "$id: requirements.md holds a version of it that $BRANCH_REV does not. Carry that version into requirements/$id.md by hand, then run this again with --resolved $id" >> "$STAGE/refused"
  fi
done < "$STAGE/w/moved"
while IFS= read -r id; do
  [ -e "$STAGE/r/entries/$id.md" ] || resolved "$id" \
    || echo "$id: in the base and not on $BRANCH_REV, and a ledger entry is marked rather than deleted. Restore it on the branch; or, if requirements/$id.md is right as it is, run this again with --resolved $id" >> "$STAGE/refused"
done < "$STAGE/b/moved"
# Per entry of the branch, whose side moved since the base.
WRITE=
OURS=
THEIRS=
KEPT=
RES=
SAME=0
while IFS= read -r id; do
  R="$STAGE/r/entries/$id.md"; B="$STAGE/b/entries/$id.md"; F="$SPLIT/$id.md"
  if resolved "$id"; then :
  elif [ -e "$B" ] && cmp -s -- "$R" "$B"; then
    # Unchanged on the branch: whatever the dev side holds stands.
    if [ ! -e "$F" ]; then WRITE="$WRITE $id"
    elif cmp -s -- "$F" "$B"; then SAME=$((SAME + 1))
    else THEIRS="$THEIRS $id"
    fi
  elif [ ! -e "$F" ]; then WRITE="$WRITE $id"
  elif cmp -s -- "$F" "$R"; then KEPT="$KEPT $id"
  elif [ -e "$B" ] && cmp -s -- "$F" "$B"; then WRITE="$WRITE $id"; OURS="$OURS $id"
  elif [ -e "$B" ]; then
    echo "$id: changed on $BRANCH_REV and on the dev side since the base. Carry both changes into requirements/$id.md by hand, then run this again with --resolved $id" >> "$STAGE/refused"
  else
    echo "$id: requirements/$id.md is there already and holds something else; two loops wrote this ID. Make the file the right one, then run this again with --resolved $id" >> "$STAGE/refused"
  fi
done < "$STAGE/r/moved"
[ ! -s "$STAGE/refused" ] || refused "$STAGE/refused"
for id in $RESOLVED; do
  [ -f "$SPLIT/$id.md" ] || stop "--resolved $id names no file requirements/$id.md, which is what it leaves as it is"
done
# Every ID named is said back, reached by the comparison or not: one the branch
# dropped is never among the branch's entries, and a name it did not echo would
# leave the person to wonder whether it was read.
RES=${RESOLVED% }

mkdir -p -- "$SPLIT" || { echo "split-requirements.sh: could not make $SPLIT; nothing was moved" >&2; exit 1; }
for id in $WRITE; do
  cp -- "$STAGE/r/entries/$id.md" "$SPLIT/$id.md" || {
    echo "split-requirements.sh: could not write requirements/$id.md; requirements.md is unchanged, and the files written before it stay" >&2
    exit 1
  }
done
if [ -s "$STAGE/w/moved" ]; then
  cp -- "$STAGE/w/requirements.md" "$REQS" || { echo "split-requirements.sh: could not rewrite $REQS; every entry is in requirements/ and also still in it" >&2; exit 1; }
  printf 'taken out of requirements.md: %s\n' "$(paste -sd ' ' "$STAGE/w/moved")"
fi
[ -z "$WRITE" ] || printf 'files written to requirements/:%s\n' "$WRITE"
# An entry the branch changed is one GH-200.4's literal holds still, if it is
# one of the 117 the split moved, and its token has to move with it: said
# here, with both tokens, because the suite's red would otherwise be the first
# anyone heard of it.
#
# The old token is read from the dev side's check-hooks.sh in git when there is
# a dev side to read, because the working tree's is conflicted in any merge
# that brings the split, and resolved to the branch's it holds no token at all.
if [ -n "$DEV_REV" ]; then
  g show "$DEV_REV:./check-hooks.sh" > "$STAGE/check-hooks.sh" 2> /dev/null || : > "$STAGE/check-hooks.sh"
else
  cat -- "$DIR/check-hooks.sh" > "$STAGE/check-hooks.sh" 2> /dev/null || : > "$STAGE/check-hooks.sh"
fi
token_line() {  # token_line <id> <what happened> -- the SPLIT_MOVED token that has to move, if one does
  local new old
  new="$1:$(cksum < "$SPLIT/$1.md" | awk '{ print $1 ":" $2 }')"
  old=$(grep -oE "(^|[[:space:]])${1//./\\.}:[0-9]+:[0-9]+" "$STAGE/check-hooks.sh" | head -n 1 | tr -d '[:space:]')
  if [ -z "$old" ]; then
    printf '%s: %s; check-hooks.sh holds no SPLIT_MOVED token for it\n' "$1" "$2"
  elif [ "$old" != "$new" ]; then
    printf '%s: %s, so its SPLIT_MOVED token in check-hooks.sh moves from %s to %s\n' "$1" "$2" "$old" "$new"
  fi
}
for id in $OURS; do token_line "$id" "changed on $BRANCH_REV only since the base"; done
[ -z "$RES" ] || printf 'resolved by hand, and left as it was:%s\n' "$RES"
for id in $RES; do token_line "$id" "resolved by hand"; done
[ -z "$THEIRS" ] || printf 'changed on the dev side only since the base, and left as it was:%s\n' "$THEIRS"
[ -z "$KEPT" ] || printf 'already in requirements/ with the same bytes, and left as it was:%s\n' "$KEPT"
[ "$SAME" = 0 ] || printf 'unchanged on both sides since the base, and left as it was: %s\n' "$SAME"
# The entries are the same whichever side of requirements.md the merge kept,
# and nothing else in it is: a side kept whole drops the other side's changes
# outside the entries -- the dev side's pointer paragraph and citations, or a
# citation the branch added. A warning and not a refusal, because a branch may
# change that part on purpose (rev-agent-200, round 5 of PR #210).
# Both directions are asked, because each side kept whole drops the other's:
# the dev side's, against the dev side in git; and the branch's, as the lines it
# added outside the entries since the base that requirements.md no longer
# holds -- #158 and #184 each add citations there, which the dev side kept
# whole drops without a word from the first question.
if [ -n "$DEV_REV" ] && g show "$DEV_REV:./requirements.md" > "$STAGE/dev.md" 2> /dev/null; then
  NDIFF=$(diff -- "$STAGE/dev.md" "$REQS" | grep -c '^[<>]')
  [ "$NDIFF" = 0 ] || printf 'requirements.md differs from %s outside the GH- entries, lines that differ: %s -- a side the merge kept whole drops the other side'"'"'s changes there, and git diff %s -- requirements.md says which\n' "$DEV_REV" "$NDIFF" "$DEV_REV"
fi
diff -- "$STAGE/b/requirements.md" "$STAGE/r/requirements.md" | sed -n 's/^> //p' > "$STAGE/branch-added"
if [ -s "$STAGE/branch-added" ]; then
  NMISS=$(grep -Fxvc -f "$REQS" "$STAGE/branch-added")
  [ "$NMISS" = 0 ] || printf 'requirements.md lacks lines %s added outside the GH- entries since the base, lines missing: %s -- a side the merge kept whole drops the other side'"'"'s changes there, and git diff %s %s -- requirements.md says which\n' "$BRANCH_REV" "$NMISS" "$(g rev-parse --short "$BASE_REV")" "$BRANCH_REV"
fi
exit 0

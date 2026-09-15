#!/bin/bash
# Prints the housekeeping commands this repository currently needs -- the sweep
# and the rotation from the branch-hygiene skill, filled in with names and
# paths -- and runs none of them.
#
# READ-ONLY, and the reason is the same as report-stale-branches.sh's: removing
# a worktree, deleting a worktree branch and rotating the dev branch are each a
# reserved act in CONTEXT.md. What an agent may do is read and report; this
# file makes the report specific enough to paste. Every line that is not a
# command begins with `#`, so a block can be copied whole.
#
# ONE CLASSIFICATION, NOT TWO. Which worktree branch is stale is decided by
# report-stale-branches.sh, whose rules -- the pull request that decides a
# branch, and the ancestry test against its head -- are argued in its header
# and were found wrong on review more than once. This file runs that report and
# reads its lines rather than re-deriving them, so a correction there is a
# correction here. It is run fresh rather than taken from the session start,
# because a pull request merged since then is a branch the start-of-session
# report has not reclassified. The coupling is to the report's wording:
# check-hooks.sh holds every phrase read below equal in both files, and drives
# this file against the real report in a fixture repository.
#
# WHAT IT ADDS is only what the sweep asks a person to check before a removal
# and the report does not print:
#   - a lock whose session is alive. A lock reason carries the pid and that
#     process's start time (field 22 of /proc/<pid>/stat); a pid that exists
#     with a different start time was handed to something else, and the lock is
#     stale. Where either cannot be read the session is taken as live.
#   - a worktree with uncommitted or untracked files, or whose status cannot be
#     read -- `git worktree remove` refuses the first, and the second is not
#     evidence of the first's absence.
#   - a branch checked out in the main checkout, which no worktree removal
#     reaches.
#   - worktree entries whose directory is gone. `git worktree prune` skips a
#     locked entry and exits 0, so every stale unlock is printed before the one
#     prune, never after it. Review of #126 found a second unlock landing after
#     the prune and its entry left behind.
#
# A DEV BRANCH IS DELETED ON THE SAME EVIDENCE WHETHER IT IS ACTIVE OR NOT. The
# report calls every local dev-NN below the highest origin/dev-* `rotated past`,
# which is true as soon as the next one is pushed -- before the old one's pull
# request into main has merged. Review of #126 found the first version printing
# `git branch -d` and `git push origin --delete` for such a branch on the
# report's word alone, and `-d` did not catch it: it accepts a branch merged
# into its own upstream. So `hold` below asks the same four questions of the
# active dev branch before a rotation and of every rotated-past one before its
# delete: its newest pull request into main merged; both its local and its
# remote copy contained in origin/main; nothing open against it; not checked
# out in a worktree the commands cannot move off it.
#
# WHAT IT DECLINES. A branch whose pull request closed without merging is
# listed with no command, because its commits may exist nowhere else and the
# sweep makes that a decision. An unclassified branch gets nothing, including
# an unlock of its worktree. Where anything cannot be read -- the fetch, the
# report's pull requests, or this file's own pull request read -- nothing is
# printed but the reason: the sweep takes no list from a report it cannot trust,
# and a plan that silently omits the rotation reads as "not due".
#
# Exits 0 when it printed a plan (possibly an empty one) and 1 when it declined
# to, so a caller can tell "nothing to do" from "could not tell".
PRS_TIMEOUT=10

ROOT=$(cd "$(dirname "$0")/../../.." && pwd) || exit 1
cd "$ROOT" || exit 1

REPORT=$(bash "$ROOT/.claude/hooks/report-stale-branches.sh" 2>/dev/null)

if printf '%s\n' "$REPORT" | grep -q -e '^fetch: FAILED' -e '^fetch: SKIPPED'; then
  echo "# No commands: the fetch did not complete, so the report classified against"
  echo "# stale remote-tracking refs. Re-run when origin is reachable."
  exit 1
fi
if printf '%s\n' "$REPORT" | grep -q '^pull requests: NOT READ'; then
  echo "# No commands: the report could not read pull requests, and the sweep takes"
  echo "# no list from a report classified by ref state alone. Re-run when gh works."
  exit 1
fi
if ! printf '%s\n' "$REPORT" | grep -q '^pull requests: read'; then
  echo "# No commands: the report did not say it read pull requests, so its classes"
  echo "# are not the sweep's. Its output was:"
  printf '%s\n' "$REPORT" | sed 's/^/#   /'
  exit 1
fi

# Number, head, base, state. The report's own read has no base, and every dev
# branch question below is a question about a base.
if ! PRS=$(timeout "$PRS_TIMEOUT" gh pr list --state all --limit 1000 \
     --json number,headRefName,baseRefName,state \
     --jq '.[] | "\(.number)\t\(.headRefName)\t\(.baseRefName)\t\(.state)"' 2>/dev/null); then
  echo "# No commands: the pull request read for the dev branch checks failed or timed"
  echo "# out after ${PRS_TIMEOUT}s. Re-run when gh works."
  exit 1
fi

# path, branch, lock reason (empty when unlocked), one per worktree. The first
# is the main checkout.
WORKTREES=$(git worktree list --porcelain | awk '
  function flush() { if (path != "") print path "\t" branch "\t" lock }
  /^worktree / { flush(); path = substr($0, 10); branch = ""; lock = "" }
  /^branch /   { branch = substr($0, 8); sub(/^refs\/heads\//, "", branch) }
  /^locked/    { lock = substr($0, 8); if (lock == "") lock = "(no reason)" }
  END { flush() }')
MAIN_CHECKOUT=$(printf '%s\n' "$WORKTREES" | head -1 | cut -f1)

# live <lock reason> -- 0 when the session named in the lock may be running.
live() {
  local pid start stat
  pid=$(printf '%s' "$1" | sed -n 's/.*(pid \([0-9][0-9]*\) start \([0-9][0-9]*\)).*/\1/p')
  start=$(printf '%s' "$1" | sed -n 's/.*(pid \([0-9][0-9]*\) start \([0-9][0-9]*\)).*/\2/p')
  [ -n "$pid" ] && [ -n "$start" ] || return 0
  [ -d /proc ] || return 0
  stat=$(cat "/proc/$pid/stat" 2>/dev/null) || return 1
  # The command name is parenthesised and may hold spaces; count from after it.
  [ "$(printf '%s' "${stat##*) }" | awk '{print $20}')" = "$start" ]
}

q() { printf '%q' "$1"; }

# hold <dev-NN> <main checkout may hold it: yes|no> -- why the branch may not be
# deleted, or nothing. The header says why the active and the rotated-past dev
# branches are asked the same questions. The active one may stand in the main
# checkout, because the rotation's first command moves that checkout to main.
hold() {
  local dev=$1 into n s ref rc open at
  into=$(printf '%s\n' "$PRS" | awk -F'\t' -v d="$dev" \
    '$2 == d && $3 == "main" && $1 + 0 > n { n = $1 + 0; s = $4 } END { if (n) print n "\t" s }')
  if [ -z "$into" ]; then
    echo "it has no pull request into main"; return
  fi
  n=${into%%$'\t'*}
  s=${into#*$'\t'}
  if [ "$s" != MERGED ]; then
    echo "its pull request into main, #$n, is $(printf '%s' "$s" | tr 'A-Z' 'a-z')"; return
  fi
  for ref in "refs/remotes/origin/$dev" "refs/heads/$dev"; do
    git rev-parse -q --verify "$ref^{commit}" >/dev/null || continue
    git merge-base --is-ancestor "$ref" refs/remotes/origin/main 2>/dev/null
    rc=$?
    case "$rc" in
      0) ;;
      1) echo "${ref#refs/} has commits that are not in origin/main"; return ;;
      *) echo "${ref#refs/} could not be compared with origin/main"; return ;;
    esac
  done
  open=$(printf '%s\n' "$PRS" | awk -F'\t' -v d="$dev" \
    '$3 == d && $4 == "OPEN" { printf "%s#%s", sep, $1; sep = " " }')
  if [ -n "$open" ]; then
    echo "pull requests are open against it ($open), and deleting it would close them"; return
  fi
  at=$(printf '%s\n' "$WORKTREES" | awk -F'\t' -v b="$dev" -v m="$2" \
    'NR == 1 && m == "yes" { next } $2 == b { print $1; exit }')
  if [ -n "$at" ]; then
    echo "it is checked out at $at"; return
  fi
}

SWEEP=
NOTES=
GONE_UNLOCKS=
GONE_DELETES=
PRUNE=
ROTATED_PAST=
HANDLED=

while IFS= read -r LINE; do
  case "$LINE" in '  '*' -- '*) ;; *) continue ;; esac
  BODY=${LINE#  }
  BRANCH=${BODY%% -- *}
  REST=${BODY#* -- }
  WT=
  case "$REST" in *'   [worktree: '*']')
    WT=${REST##*'   [worktree: '}
    WT=${WT%]}
    REST=${REST%'   [worktree: '*} ;;
  esac
  [ -n "$WT" ] && HANDLED="$HANDLED
$WT"

  case "$REST" in
    'merged: pull request'*) ;;
    'closed without merging: pull request'*)
      NOTES="$NOTES
#   $BRANCH -- ${REST%%;*}. Its commits may exist nowhere else: decide, then sweep it by hand."
      continue ;;
    'rotated past'*)
      ROTATED_PAST="$ROTATED_PAST $BRANCH"
      continue ;;
    *) continue ;;
  esac
  PR=${REST#merged: }

  if [ -z "$WT" ]; then
    SWEEP="$SWEEP
# $BRANCH -- $PR, no worktree
git branch -d $(q "$BRANCH")"
    continue
  fi

  if [ "$WT" = "$MAIN_CHECKOUT" ]; then
    NOTES="$NOTES
#   $BRANCH -- $PR, but it is checked out in the main checkout; switch that off it first."
    continue
  fi

  LOCK=$(printf '%s\n' "$WORKTREES" | awk -F'\t' -v p="$WT" '$1 == p { print $3 }')
  if [ -n "$LOCK" ] && live "$LOCK"; then
    NOTES="$NOTES
#   $BRANCH -- $PR, but its worktree is locked by a session that may still be running:
#     $LOCK"
    continue
  fi

  if [ ! -d "$WT" ]; then
    PRUNE=1
    [ -n "$LOCK" ] && GONE_UNLOCKS="$GONE_UNLOCKS
git worktree unlock $(q "$WT")"
    GONE_DELETES="$GONE_DELETES
git branch -d $(q "$BRANCH")"
    continue
  fi

  if ! STATUS=$(git -C "$WT" status --porcelain 2>/dev/null) || [ -n "$STATUS" ]; then
    NOTES="$NOTES
#   $BRANCH -- $PR, but $WT holds uncommitted or untracked files, or its status could not be read; look before --force."
    continue
  fi

  UNLOCK=
  [ -n "$LOCK" ] && UNLOCK="git worktree unlock $(q "$WT")
"
  SWEEP="$SWEEP
# $BRANCH -- $PR
${UNLOCK}git worktree remove $(q "$WT")
git branch -d $(q "$BRANCH")"
done <<REPORT_LINES
$REPORT
REPORT_LINES

# A detached worktree whose directory is gone. The report lists branches, so it
# never names one, and there is no branch to classify: its entry is all there
# is. An entry holding a branch the report did not call merged is left alone.
#
# The fields are split by hand. `IFS=$'\t' read` collapses the two tabs around
# a detached entry's empty branch, so its lock reason was read as a branch and
# the entry skipped; found by check-hooks.sh on its first run, not by eye.
while IFS= read -r ENTRY; do
  WT=${ENTRY%%$'\t'*}
  REST=${ENTRY#*$'\t'}
  BRANCH=${REST%%$'\t'*}
  LOCK=${REST#*$'\t'}
  [ -n "$WT" ] && [ -z "$BRANCH" ] && [ ! -d "$WT" ] || continue
  printf '%s\n' "$HANDLED" | grep -qxF -- "$WT" && continue
  if [ -n "$LOCK" ]; then
    if live "$LOCK"; then
      NOTES="$NOTES
#   $WT -- detached, directory gone, but locked by a session that may still be running."
      continue
    fi
    GONE_UNLOCKS="$GONE_UNLOCKS
git worktree unlock $(q "$WT")"
  fi
  PRUNE=1
done <<WT_LINES
$(printf '%s\n' "$WORKTREES" | tail -n +2)
WT_LINES
if [ -n "$PRUNE" ]; then
  SWEEP="$SWEEP
# worktree entries whose directory is gone: every unlock before the one prune$GONE_UNLOCKS
git worktree prune$GONE_DELETES"
fi

# The rotation of the active dev branch.
DEV=$(printf '%s\n' "$REPORT" | sed -n 's/^active dev branch: origin\/\(dev-[0-9][0-9]*\)$/\1/p')
ROTATION=
if [ -z "$DEV" ]; then
  ROTATION="# no active dev branch found; nothing to check"
else
  WHY=$(hold "$DEV" yes)
  if [ -n "$WHY" ]; then
    ROTATION="# $DEV is not due to rotate: $WHY."
  else
    NEXT=$(printf 'dev-%02d' $((10#${DEV#dev-} + 1)))
    LOCAL_DELETE=
    git show-ref --verify --quiet "refs/heads/$DEV" && LOCAL_DELETE="
git branch -d $DEV"
    ROTATION="# $DEV is due: merged into main, contained in origin/main, nothing open against it.
git checkout main
git pull --ff-only origin main
git checkout -b $NEXT
git push -u origin $NEXT
git branch --show-current   # must print $NEXT before the deletes$LOCAL_DELETE
git push origin --delete $DEV"
  fi
fi
for OLD in $ROTATED_PAST; do
  WHY=$(hold "$OLD" no)
  if [ -n "$WHY" ]; then
    NOTES="$NOTES
#   $OLD -- rotated past, held: $WHY."
    continue
  fi
  ROTATION="$ROTATION
# $OLD -- rotated past: merged into main, contained in origin/main, nothing open against it
git branch -d $OLD"
  git show-ref --verify --quiet "refs/remotes/origin/$OLD" && ROTATION="$ROTATION
git push origin --delete $OLD"
done

echo "# Housekeeping for $(basename "$MAIN_CHECKOUT"), from a report run just now."
echo "# Nothing has been run. Run these from your own terminal."
if [ -n "$SWEEP" ] || printf '%s\n' "$ROTATION" | grep -q '^git '; then
  echo "cd $(q "$MAIN_CHECKOUT")"
fi
echo
echo "# == sweep: merged worktree branches =="
if [ -n "$SWEEP" ]; then
  printf '%s\n' "${SWEEP#?}"
else
  echo "# nothing to sweep"
fi
if [ -n "$NOTES" ]; then
  echo
  echo "# == held back, with the reason =="
  printf '%s\n' "${NOTES#?}"
fi
echo
echo "# == rotation =="
printf '%s\n' "$ROTATION"
if [ -n "$SWEEP" ] || printf '%s\n' "$ROTATION" | grep -q '^git '; then
  echo
  echo "# == verify =="
  echo "git fetch --prune"
  echo "git branch -a"
  echo "git worktree list"
fi
echo
printf '%s\n' "$REPORT" | grep '^[0-9]* other branch' | sed 's/^/# report: /'
exit 0

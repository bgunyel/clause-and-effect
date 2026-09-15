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
# ONE CLASSIFICATION, NOT TWO. Which branch is stale is decided by
# report-stale-branches.sh, whose rules -- the pull request that decides a
# branch, and the ancestry test against its head -- are argued in its header
# and were found wrong on review more than once. This file runs that report and
# reads its lines rather than re-deriving them, so a correction there is a
# correction here. It is run fresh rather than taken from the session start,
# because a pull request merged since then is a branch the start-of-session
# report has not reclassified. The coupling is to the report's wording, which
# check-hooks.sh already pins against the sweep's definitions.
#
# WHAT IT ADDS is only what the sweep asks a person to check before a removal
# and the report does not print:
#   - a lock whose session is alive. A lock reason carries the pid and that
#     process's start time (field 22 of /proc/<pid>/stat); a pid that exists
#     with a different start time was handed to something else, and the lock is
#     stale. Where either cannot be read the session is taken as live, so the
#     unknown case prints no removal.
#   - a worktree with uncommitted or untracked files, which `git worktree
#     remove` refuses and which is somebody's unread work.
#   - a branch checked out in the main checkout, which no worktree removal
#     reaches.
#   - worktree entries whose directory is gone, which `git worktree prune`
#     clears -- unless locked, when prune skips them and exits 0.
#   - whether the active dev branch is due to rotate: its newest pull request
#     into main is merged, the branch is contained in origin/main, and nothing
#     is open against it.
#
# WHAT IT DECLINES. A branch whose pull request closed without merging is
# listed with no command, because its commits may exist nowhere else and the
# sweep makes that a decision. An unclassified branch is not mentioned beyond
# the count. When the report could not read pull requests or could not fetch,
# nothing is printed but the reason: the sweep says to take no list from that
# report.
#
# Exits 0 when it printed a plan (possibly an empty one) and 1 when it declined
# to, so a caller can tell "nothing to do" from "could not tell".
PRS_TIMEOUT=10

ROOT=$(cd "$(dirname "$0")/../../.." && pwd) || exit 1
cd "$ROOT" || exit 1
REPORT_SH="$ROOT/.claude/hooks/report-stale-branches.sh"

REPORT=$(bash "$REPORT_SH" 2>/dev/null)

if printf '%s\n' "$REPORT" | grep -q '^fetch: \(FAILED\|SKIPPED\)'; then
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

# path, branch, locked (reason or empty), one per worktree. The first is the
# main checkout.
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

SWEEP=
NOTES=
PRUNE=
DEV_LOCAL_DELETE=
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

  case "$REST" in
    'merged: pull request #'*) ;;
    'closed without merging: pull request #'*)
      NOTES="$NOTES
#   $BRANCH -- ${REST%%;*}. Its commits may exist nowhere else: decide, then sweep it by hand."
      continue ;;
    'rotated past'*)
      DEV_LOCAL_DELETE="$DEV_LOCAL_DELETE $BRANCH"
      continue ;;
    *) continue ;;
  esac
  PR=${REST#merged: }
  [ -n "$WT" ] && HANDLED="$HANDLED
$WT"

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

  UNLOCK=
  [ -n "$LOCK" ] && UNLOCK="git worktree unlock $(q "$WT")
"
  if [ ! -d "$WT" ]; then
    # A directory already gone: prune clears the entry, once it is unlocked.
    PRUNE=1
    SWEEP="$SWEEP
# $BRANCH -- $PR, worktree directory already gone
${UNLOCK}git worktree prune
git branch -d $(q "$BRANCH")"
    continue
  fi

  if [ -n "$(git -C "$WT" status --porcelain 2>/dev/null)" ]; then
    NOTES="$NOTES
#   $BRANCH -- $PR, but $WT holds uncommitted or untracked files; look before --force."
    continue
  fi

  SWEEP="$SWEEP
# $BRANCH -- $PR
${UNLOCK}git worktree remove $(q "$WT")
git branch -d $(q "$BRANCH")"
done <<REPORT_LINES
$REPORT
REPORT_LINES

# Worktree entries whose directory is gone and whose branch was not handled
# above. A locked one needs its unlock written out, because prune skips it
# silently.
while IFS=$'\t' read -r WT BRANCH LOCK; do
  [ -n "$WT" ] && [ ! -d "$WT" ] || continue
  printf '%s\n' "$HANDLED" | grep -qxF -- "$WT" && continue
  if [ -n "$LOCK" ]; then
    if live "$LOCK"; then
      NOTES="$NOTES
#   $WT -- directory gone, but locked by a session that may still be running."
      continue
    fi
    SWEEP="$SWEEP
# $WT -- directory gone, lock stale
git worktree unlock $(q "$WT")"
  fi
  PRUNE=1
done <<WT_LINES
$(printf '%s\n' "$WORKTREES" | tail -n +2)
WT_LINES
if [ -n "$PRUNE" ]; then
  case "$SWEEP" in *'git worktree prune'*) ;; *)
    SWEEP="$SWEEP
# worktree entries whose directory is gone
git worktree prune" ;;
  esac
fi

# The rotation. Due only when all three hold; each one that does not is said.
DEV=$(printf '%s\n' "$REPORT" | sed -n 's/^active dev branch: origin\/\(dev-[0-9][0-9]*\)$/\1/p')
ROTATION=
if [ -n "$DEV" ]; then
  if PRS=$(timeout "$PRS_TIMEOUT" gh pr list --state all --limit 1000 \
       --json number,headRefName,baseRefName,state \
       --jq '.[] | "\(.number)\t\(.headRefName)\t\(.baseRefName)\t\(.state)"' 2>/dev/null); then
    INTO_MAIN=$(printf '%s\n' "$PRS" | awk -F'\t' -v d="$DEV" \
      '$2 == d && $3 == "main" && $1 > n { n = $1; s = $4 } END { if (n) print n "\t" s }')
    OPEN_ON_DEV=$(printf '%s\n' "$PRS" | awk -F'\t' -v d="$DEV" \
      '$3 == d && $4 == "OPEN" { printf "%s#%s", sep, $1; sep = " " }')
    if [ -z "$INTO_MAIN" ]; then
      ROTATION="# $DEV has no pull request into main; not due."
    elif [ "$(printf '%s' "$INTO_MAIN" | cut -f2)" != MERGED ]; then
      ROTATION="# $DEV -> main is pull request #$(printf '%s' "$INTO_MAIN" | cut -f1), $(printf '%s' "$INTO_MAIN" | cut -f2 | tr 'A-Z' 'a-z'); not due."
    elif ! git merge-base --is-ancestor "origin/$DEV" origin/main 2>/dev/null; then
      ROTATION="# $DEV -> main merged as #$(printf '%s' "$INTO_MAIN" | cut -f1), but origin/$DEV has commits since that are not in origin/main; not due."
    elif [ -n "$OPEN_ON_DEV" ]; then
      ROTATION="# $DEV -> main merged, but these pull requests are open against $DEV: $OPEN_ON_DEV
# Merge or retarget them first; deleting $DEV would close them."
    else
      NUM=${DEV#dev-}
      NEXT=$(printf 'dev-%02d' $((10#$NUM + 1)))
      ROTATION="# $DEV -> main merged as #$(printf '%s' "$INTO_MAIN" | cut -f1), and nothing is open against it.
cd $(q "$MAIN_CHECKOUT")
git checkout main
git pull --ff-only origin main
git checkout -b $NEXT
git push -u origin $NEXT
git branch --show-current   # must print $NEXT before the next two
git branch -d $DEV
git push origin --delete $DEV"
    fi
  else
    ROTATION="# Could not read pull requests for the rotation check; no rotation commands."
  fi
fi
for OLD in $DEV_LOCAL_DELETE; do
  if git show-ref --verify --quiet "refs/remotes/origin/$OLD"; then
    ROTATION="$ROTATION
# $OLD -- rotated past, still on origin
git branch -d $OLD
git push origin --delete $OLD"
  else
    ROTATION="$ROTATION
# $OLD -- rotated past
git branch -d $OLD"
  fi
done

echo "# Housekeeping for $(basename "$MAIN_CHECKOUT"), from a report run just now."
echo "# Nothing has been run. Run these from your own terminal."
echo
echo "# == sweep: merged worktree branches =="
if [ -n "$SWEEP" ]; then
  echo "cd $(q "$MAIN_CHECKOUT")"
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
printf '%s\n' "${ROTATION:-# no active dev branch found; nothing to check}"
if [ -n "$SWEEP" ] || [ -n "$DEV_LOCAL_DELETE" ] || printf '%s' "$ROTATION" | grep -q '^git '; then
  echo
  echo "# == verify =="
  echo "git fetch --prune"
  echo "git branch -a"
  echo "git worktree list"
fi
echo
printf '%s\n' "$REPORT" | grep '^[0-9]* other branch' | sed 's/^/# report: /'
exit 0

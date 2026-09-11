#!/bin/bash
# The read-only half of the branch-hygiene sweep, run at SessionStart -- and the
# thing that arms no-work-on-stale-branch.sh.
#
# That guard has two detectors and both read remote-tracking refs: a branch
# whose upstream is gone, and a branch at ahead == 0 behind > 0 against
# origin/dev-NN. Remote-tracking refs are exactly as fresh as the last fetch,
# and a PreToolUse hook has five seconds and cannot fetch. So the fetch happens
# here, once, before the session starts: the read-only half of the sweep is what
# arms the enforcing half.
#
# It prunes explicitly rather than relying on fetch.prune, because a guard whose
# soundness depends on per-clone configuration is no-git-push.sh's own objection
# pointed inward -- and per-clone configuration is missing on exactly the clone
# where it matters. Without --prune the remote-tracking ref of a merged branch
# survives its deletion on the remote, `[gone]` never appears, and the first
# detector silently never fires.
#
# READ-ONLY, by name and by content. Removing a worktree or a branch is Bertan's
# -- a reserved act in CONTEXT.md, and issue #41 declined to carve a hook
# exception for the sweep. The name is report- and never sweep- because the
# filename is where that constraint survives the next reader. The only thing
# here that writes anything is `git fetch --prune`, which writes
# remote-tracking refs and nothing else: no local branch, no worktree, no
# checkout.
#
# THE ARMING PROPERTY IS NOT SELF-ANNOUNCING. Issue #36 leaves `.claude/`
# unguarded on the grounds that an agent does not *mistakenly* rewrite the hook
# that just refused it -- breakage announces itself, because the refusal stops
# coming. This file breaks that reasoning: it arms enforcement rather than
# performing it, so dropping --prune from the line below changes nothing
# visible. The exclusion is not reopened; it is re-argued. Anything in
# `.claude/` that arms enforcement rather than performing it carries a check
# asserting its arming property, and check-hooks.sh asserts as literals what
# this file must do: that its fetch prunes, that it reads the merge settings
# rather than recording them, and that settings.json still runs it. That check
# announces at the next review rather than on the next push, because this
# repository has no CI: there is no .github/workflows/, so the suite runs when
# someone runs it. That is how all the existing checks already behave.
#
# FAILS OPEN, WITH A TIMEOUT. An offline or slow session must start. When the
# fetch fails or times out the report says so in as many words, because the
# consequence is not cosmetic: neither detector is armed for that session, and
# the guard will read whatever the last successful fetch left behind.
#
# IT READS THE MERGE SETTINGS, BECAUSE IT IS THE ONLY PLACE THAT CAN. Both of
# that guard's detectors rest on a repository setting no bash hook can assert,
# and #36's Amendment recorded the three values in prose instead. Why they are
# read here rather than recorded anywhere, and what the recorded version cost,
# is in no-work-on-stale-branch.sh's header -- once, rather than twice here in
# different words, for the reason given beside the dev-branch derivation below.
# check-hooks.sh counts both copies, so a retelling here turns the suite red.
#
# What this file adds is only the opportunity: it already opens with a network
# call and has a SessionStart budget to spend, so here the claim can be a check
# instead of a sentence. What it reports is drift, and only drift -- changing a
# repository setting is Bertan's, like every other reserved act this file
# declines to perform.
#
# Exits 0 always. A SessionStart hook that fails is a session that does not
# start, and nothing here is worth that.
FETCH_TIMEOUT=15
# Its own budget rather than the fetch's, and smaller: one small API request
# against a fetch of every ref. The two are spent in series and the hook's own
# timeout in settings.json has to outlast their sum, which check-hooks.sh
# asserts from these two lines rather than from a third copy of the numbers.
SETTINGS_TIMEOUT=10

cd "$(dirname "$0")/../.." || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

echo "== branch lifecycle =="

if ! git remote | grep -qxF origin; then
  echo "fetch: SKIPPED -- this repository has no remote named origin, so neither"
  echo "       staleness detector in no-work-on-stale-branch.sh is armed."
  FETCHED=
else
  # --prune written out rather than left to fetch.prune. See the header: this is
  # the arming property, and check-hooks.sh asserts this line as a literal.
  if timeout "$FETCH_TIMEOUT" git fetch --prune --quiet origin 2>/dev/null; then
    echo "fetch: pruned origin"
    FETCHED=1
  else
    echo "fetch: FAILED or timed out after ${FETCH_TIMEOUT}s -- remote-tracking refs are"
    echo "       as stale as the last successful fetch, so no-work-on-stale-branch.sh"
    echo "       is not armed for this session."
    FETCHED=
  fi
fi

# Drift from the branch lifecycle rule in #36's Amendment, named with the
# detector that rests on each one, because a reader who has to work that out
# will not. Reported and never changed: a repository setting is Bertan's, and a
# file called report- alters nothing. A value the API did not report is its own
# sentence -- a fine-grained token can be denied these fields, and "is null" put
# beside "requires false" reads as a setting rather than as a missing answer. An
# empty field is the same answer arriving a different way (a read that exited 0
# with nothing behind it), so it takes the same sentence rather than printing
# "is " and a blank.
drift() {  # drift <setting> <actual> <required> <what rests on it>
  [ "$2" = "$3" ] && return 0
  case "$2" in
    ''|null) DRIFTED="$DRIFTED
  $1 was not reported by the API; the rule requires $3 -- otherwise $4" ;;
    *) DRIFTED="$DRIFTED
  $1 is $2; the rule requires $3 -- otherwise $4" ;;
  esac
}

FALLBACK='a squashed or rebased branch is no ancestor and reads as ahead > 0'
# Two ways not to get an answer, one sentence about what that costs. Written as
# a reason and one message rather than as two messages, because the second was a
# reworded copy of the first the moment it was typed, and this file's own
# objection to a second copy of an argument is four paragraphs down.
if ! command -v gh >/dev/null 2>&1; then
  UNREAD='no gh on PATH'
elif ! MERGE=$(timeout "$SETTINGS_TIMEOUT" gh api 'repos/{owner}/{repo}' \
     --jq '[.allow_squash_merge, .allow_rebase_merge, .delete_branch_on_merge] | map(tostring) | @tsv' \
     2>/dev/null); then
  UNREAD="gh api failed or timed out after ${SETTINGS_TIMEOUT}s"
else
  UNREAD=
fi

if [ -n "$UNREAD" ]; then
  echo "merge settings: NOT READ -- ${UNREAD}, so whether either detector in"
  echo "       no-work-on-stale-branch.sh rests on a true assumption is unknown."
else
  SQUASH=$(printf '%s' "$MERGE" | cut -f1)
  REBASE=$(printf '%s' "$MERGE" | cut -f2)
  DELETE=$(printf '%s' "$MERGE" | cut -f3)
  DRIFTED=
  drift allow_squash_merge "$SQUASH" false "$FALLBACK"
  drift allow_rebase_merge "$REBASE" false "$FALLBACK"
  drift delete_branch_on_merge "$DELETE" true 'a merged branch is never seen as one whose upstream is gone'
  if [ -n "$DRIFTED" ]; then
    echo "merge settings: DRIFTED from what the branch lifecycle rule requires:$DRIFTED"
    echo "       Reported, not fixed -- changing a repository setting is Bertan's."
  else
    echo "merge settings: as required (squash off, rebase off, delete-on-merge on)"
  fi
fi

# The active dev branch: the highest-numbered refs/remotes/origin/dev-*. Why the
# digit filter and the version sort are both load-bearing is argued once, in
# no-work-on-stale-branch.sh's header, rather than twice here in different words
# -- a second copy of an argument goes stale in silence when the first one is
# corrected. The next two lines stand verbatim in that file as well:
# check-hooks.sh holds the two equal, so a change here is a change there.
DEV=$(git for-each-ref --format='%(refname:short)' 'refs/remotes/origin/dev-*' 2>/dev/null \
      | grep -E '^origin/dev-[0-9]+$' | sort -V | tail -1)
if [ -n "$DEV" ]; then
  echo "active dev branch: $DEV"
else
  echo "active dev branch: none -- no refs/remotes/origin/dev-* exists, so"
  echo "       no-work-on-stale-branch.sh abstains rather than refusing."
fi

# Which branch is checked out in which worktree, so a stale branch can be
# reported with the directory somebody is standing in.
WT=$(git worktree list --porcelain 2>/dev/null | awk '
  /^worktree /  { path = substr($0, 10) }
  /^branch /    { ref = substr($0, 8); sub(/^refs\/heads\//, "", ref); print ref "\t" path }')

STALE=0
UNCLASSIFIED=0
CLEAR=0
REPORT=

while IFS=$'\t' read -r BRANCH TRACK; do
  [ -n "$BRANCH" ] || continue
  case "$BRANCH" in main) CLEAR=$((CLEAR + 1)); continue ;; esac

  HERE=$(printf '%s\n' "$WT" | awk -F'\t' -v b="$BRANCH" '$1 == b { print $2 }')
  [ -n "$HERE" ] && HERE="   [worktree: $HERE]"

  # A dev-NN that is not the active one has been rotated past. That is the
  # branch-hygiene skill's own definition of stale, not this file's.
  if printf '%s' "$BRANCH" | grep -qE '^dev-[0-9]+$'; then
    if [ "origin/$BRANCH" != "$DEV" ]; then
      REPORT="$REPORT
  $BRANCH -- rotated past; the active dev branch is ${DEV:-unknown}$HERE"
      STALE=$((STALE + 1))
    else
      CLEAR=$((CLEAR + 1))
    fi
    continue
  fi

  if [ "$TRACK" = "[gone]" ]; then
    REPORT="$REPORT
  $BRANCH -- merged: its branch on the remote is gone$HERE"
    STALE=$((STALE + 1))
    continue
  fi

  if [ -z "$DEV" ]; then
    CLEAR=$((CLEAR + 1))
    continue
  fi

  COUNTS=$(git rev-list --left-right --count "$DEV...refs/heads/$BRANCH" 2>/dev/null)
  BEHIND=$(printf '%s' "$COUNTS" | cut -f1)
  AHEAD=$(printf '%s' "$COUNTS" | cut -f2)
  if [ -z "$AHEAD" ]; then
    CLEAR=$((CLEAR + 1))
    continue
  fi

  if [ "$AHEAD" -eq 0 ] && [ "$BEHIND" -gt 0 ]; then
    # The branch-hygiene skill is explicit that ahead/behind cannot tell a
    # merged branch from one freshly cut before the dev branch moved. Reported
    # as state, and called unclassified rather than stale, for that reason.
    REPORT="$REPORT
  $BRANCH -- no work of its own; $DEV is $BEHIND ahead of it (unclassified: merged, or cut and not yet worked)$HERE"
    UNCLASSIFIED=$((UNCLASSIFIED + 1))
  else
    CLEAR=$((CLEAR + 1))
  fi
done <<BRANCHES
$(git for-each-ref --format='%(refname:short)%09%(upstream:track)' refs/heads/ 2>/dev/null)
BRANCHES

if [ -n "$REPORT" ]; then
  echo "branches whose work may be over:$REPORT"
else
  echo "branches whose work may be over: none"
fi
echo "$CLEAR other branch(es) are clear; $STALE stale, $UNCLASSIFIED unclassified."

if [ -n "$FETCHED" ]; then
  echo "Nothing was removed. Deleting a branch or a worktree is a reserved act --"
  echo "report it and stop; see the branch-hygiene skill."
fi

exit 0

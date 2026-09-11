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
# filename is where that constraint survives the next reader. The half that does
# remove things is "The sweep" in the branch-hygiene skill, run by hand off this
# file's output; what is printed here is the whole of what runs automatically. The only thing
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
# asserting its arming property, and check-hooks.sh asserts as a literal that
# this file's fetch prunes and that settings.json still runs it. That check
# announces at the next review rather than on the next push, because this
# repository has no CI: there is no .github/workflows/, so the suite runs when
# someone runs it. That is how all the existing checks already behave.
#
# FAILS OPEN, WITH A TIMEOUT. An offline or slow session must start. When the
# fetch fails or times out the report says so in as many words, because the
# consequence is not cosmetic: neither detector is armed for that session, and
# the guard will read whatever the last successful fetch left behind.
#
# Exits 0 always. A SessionStart hook that fails is a session that does not
# start, and nothing here is worth that.
FETCH_TIMEOUT=15

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

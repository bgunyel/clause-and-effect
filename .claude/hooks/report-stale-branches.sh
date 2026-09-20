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
# remove things is "The sweep" in the branch-hygiene skill, which reads the
# report below; what is printed here is the whole of what runs automatically.
# The only thing here that writes anything is `git fetch --prune`, which writes
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
# IT CLASSIFIES BY PULL REQUEST, BECAUSE THE SWEEP DOES. "The sweep" defines
# stale as a worktree branch whose pull request merged or closed, clear as one
# whose pull request is open, and unclassified as one with none -- and until
# #100 this file never read a pull request. It classified by ref state instead,
# and the two disagreed in exactly the cases the sweep acts on. Here they
# disagreed on nearly every merged branch. A worktree branch is pushed as
# `git push origin <branch>`, which sets no upstream -- on 2026-09-15 three
# branches present on origin had none locally, and the two that had one tracked
# origin/dev-05, which never goes away -- so there is no upstream to go
# `[gone]`, and a merged branch read as unclassified, the class the sweep leaves
# alone. Changing the skill to describe the ref-state classes was the other fix
# #100 offered, and was not taken for that reason: the sweep would have had
# almost nothing to act on. This is the one place that argument is made; the
# skill points here.
#
# One read of every pull request, bounded, after the settings read, and skipped
# when that read found gh missing or unreachable -- an offline session already
# waits out the fetch, and should not wait out two gh calls behind it as well.
# It fails open the way the settings read does: when the pull requests could not
# be read, the report says so and falls back to the ref-state classes it
# computed before, worded as ref state so that they are not read under the
# pull-request meanings. The sweep's definitions name both.
#
# WHICH PULL REQUEST DECIDES, AND WHEN IT MAY NOT. A branch with an open pull
# request is in flight whatever else it has. Otherwise the newest by number
# decides, so a branch closed after it merged carries the closed one's warning
# that its commits may exist nowhere else. By number and not by list position,
# so nothing rests on the order gh returns them in.
#
# A merged or closed pull request calls a branch stale only if the branch is at
# or behind that pull request's head commit. Pull requests are matched to
# branches by head name, and without this test a branch cut fresh under a name
# an earlier pull request had used read as that pull request's: stale, the one
# class the sweep deletes, and the lowercase branch delete would not have stopped
# it, because a branch with no commit of its own is exactly what that flag
# permits. Found on review of this change. A branch that is not at or behind the
# head -- a reused name, work committed after the merge, a fork's pull request
# under the same name -- is unclassified, and the line says why.
#
# Two limits. The read stops at the newest 1000 pull requests, so a branch whose
# only pull request is older reads as having none: unclassified, the safe
# direction. And the head test is ancestry, not identity, so a branch cut under a
# reused name at a commit the earlier head already contains, and never worked
# on, still reads as stale -- the permitting direction, taken knowingly. Every
# commit on such a branch is already in that head, so a sweep of it loses the
# name and not a commit; and identity would call unclassified every merged branch
# whose local copy lagged its remote.
#
# WHERE A NEW WORKTREE BRANCH STARTS is a rule in CLAUDE.md, not argued here.
# It starts at the remote-tracking ref the fetch below writes, and why that ref
# and never the local dev-NN is CONTEXT.md's *active dev branch* entry.
#
# Exits 0 always. A SessionStart hook that fails is a session that does not
# start, and nothing here is worth that.
#
# IT NEVER EXITS WITHOUT SAYING WHY. Issue #108 audited what this file does in a
# broken environment and found the one path that said nothing at all: with git
# off PATH, or run from a tree that is not a repository, it exited 0 above the
# heading, and the session began with an empty report. An empty report reads as
# nothing to report; what is true is that nothing was read. That is the same
# conflation the two counts under the drift heading were split to remove, and
# the argument for splitting them holds harder here, because this is the line a
# reader skims rather than one under a heading.
#
# It matters for the reason under THE ARMING PROPERTY IS NOT SELF-ANNOUNCING.
# Neither detector in no-work-on-stale-branch.sh is armed for such a session, and
# that guard's silence is what a clean tree looks like too -- so a session whose
# refs were never read is indistinguishable, from the inside, from one with
# nothing stale in it. Every other unread thing here already says so in as many
# words: the fetch, the merge settings, the pull requests, the main ancestry.
# These two were the exception, and there is no reason for them to be one.
#
# So the heading is printed before the first thing that can fail, and each exit
# below it names its cause. The exit status stays 0: what changes is that the
# report says the branches were not read, not the behaviour of the session.
FETCH_TIMEOUT=15
# Its own budget rather than the fetch's, and smaller: one small API request
# against a fetch of every ref. The calls are spent in series and the hook's own
# timeout in settings.json has to outlast their sum, which check-hooks.sh
# asserts from these lines rather than from another copy of the numbers.
SETTINGS_TIMEOUT=10
# The pull request read. It measured 0.60-0.80s over five runs against the 38
# pull requests this repository had on 2026-09-15; the budget is for a slow
# network, not for the read.
PRS_TIMEOUT=10

echo "== branch lifecycle =="

# The three ways this file can have nothing to report, each said out loud. See
# IT NEVER EXITS WITHOUT SAYING WHY above. The git test is `command -v` and not
# the rev-parse below it, because the two causes are different sentences: a
# machine with no git is one install away from a report, a directory that is not
# a repository is not.
cd "$(dirname "$0")/../.." || {
  echo "branches: NOT READ -- this file could not reach the repository root from its"
  echo "          own location, so neither staleness detector in"
  echo "          no-work-on-stale-branch.sh is armed for this session."
  exit 0
}
if ! command -v git >/dev/null 2>&1; then
  echo "branches: NOT READ -- git is not on PATH, so neither staleness detector in"
  echo "          no-work-on-stale-branch.sh is armed for this session."
  exit 0
fi
git rev-parse --git-dir >/dev/null 2>&1 || {
  echo "branches: NOT READ -- this is not a git repository, so neither staleness"
  echo "          detector in no-work-on-stale-branch.sh is armed for this session."
  exit 0
}

if ! git remote | grep -qxF origin; then
  echo "fetch: SKIPPED -- this repository has no remote named origin, so neither"
  echo "       staleness detector in no-work-on-stale-branch.sh is armed."
  FETCHED=
  # Set with the fetch's outcome, for the main ancestry line below: a fetch that
  # never ran did not fail, and saying so would be a claim about an attempt.
  STALE_REFS=' (read against refs no fetch refreshed)'
else
  # --prune written out rather than left to fetch.prune. See the header: this is
  # the arming property, and check-hooks.sh asserts this line as a literal.
  if timeout "$FETCH_TIMEOUT" git fetch --prune --quiet origin 2>/dev/null; then
    echo "fetch: pruned origin"
    FETCHED=1
    STALE_REFS=
  else
    echo "fetch: FAILED or timed out after ${FETCH_TIMEOUT}s -- remote-tracking refs are"
    echo "       as stale as the last successful fetch, so no-work-on-stale-branch.sh"
    echo "       is not armed for this session."
    FETCHED=
    STALE_REFS=' (read against refs the failed fetch left behind)'
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
#
# The two cases are counted apart as well as worded apart, because the heading
# over them is read by people who do not read the lines. A field the API did not
# report under a heading that says DRIFTED tells a skimmer that a setting
# changed, when what is true is that it is unknown -- the same shape of error
# this whole change exists to remove, one level up from the sentence that was
# careful about it. MISMATCHED is set only where a value came back and was the
# wrong one.
drift() {  # drift <setting> <actual> <required> <what rests on it>
  [ "$2" = "$3" ] && return 0
  case "$2" in
    ''|null) DRIFTED="$DRIFTED
  $1 was not reported by the API; the rule requires $3 -- otherwise $4" ;;
    *) MISMATCHED=1
       DRIFTED="$DRIFTED
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
  MISMATCHED=
  drift allow_squash_merge "$SQUASH" false "$FALLBACK"
  drift allow_rebase_merge "$REBASE" false "$FALLBACK"
  drift delete_branch_on_merge "$DELETE" true 'a merged branch is never seen as one whose upstream is gone'
  if [ -n "$MISMATCHED" ]; then
    echo "merge settings: DRIFTED from what the branch lifecycle rule requires:$DRIFTED"
    echo "       Reported, not fixed -- changing a repository setting is Bertan's."
  elif [ -n "$DRIFTED" ]; then
    echo "merge settings: NOT FULLY READ -- the API answered without these, so what"
    echo "       rests on them is unknown rather than wrong:$DRIFTED"
  else
    echo "merge settings: as required (squash off, rebase off, delete-on-merge on)"
  fi
fi

# Every pull request, as head, state, number and head commit. See the header for
# why it is read at all and why it is skipped when the settings read could not
# reach gh; the settings read's reason is then this one's too.
PRS=
PRS_READ=
PRS_UNREAD=$UNREAD
if [ -z "$PRS_UNREAD" ]; then
  if PRS=$(timeout "$PRS_TIMEOUT" gh pr list --state all --limit 1000 \
       --json headRefName,state,number,headRefOid \
       --jq '.[] | "\(.headRefName)\t\(.state)\t\(.number)\t\(.headRefOid)"' \
       2>/dev/null); then
    PRS_READ=1
  else
    PRS_UNREAD="gh pr list failed or timed out after ${PRS_TIMEOUT}s"
  fi
fi
if [ -n "$PRS_READ" ]; then
  echo "pull requests: read -- branches are classified by their pull request's state"
else
  echo "pull requests: NOT READ -- ${PRS_UNREAD}, so branches are"
  echo "       classified by ref state alone, which cannot see a pull request."
fi

# The pull request that decides a branch, as the line gh printed for it, or
# nothing when the branch has none: an open one if there is one, and otherwise
# the newest by number. The header says why.
pr_of() {  # pr_of <branch>
  printf '%s\n' "$PRS" | awk -F'\t' -v b="$1" '
    $1 != b { next }
    { k = ($2 == "OPEN") * 1000000000 + $3 }
    k > best { best = k; line = $0 }
    END { if (best) print line }'
}

# The active dev branch: the highest-numbered refs/remotes/origin/dev-*. Why the
# digit filter and the version sort are both load-bearing is argued once, in
# no-work-on-stale-branch.sh's header, rather than twice here in different words
# -- a second copy of an argument goes stale in silence when the first one is
# corrected. The next two lines stand verbatim in that file and in
# no-pr-decisions.sh as well:
# check-hooks.sh holds the three equal, so a change here is a change there.
DEV=$(git for-each-ref --format='%(refname:short)' 'refs/remotes/origin/dev-*' 2>/dev/null \
      | grep -E '^origin/dev-[0-9]+$' | sort -V | tail -1)
if [ -n "$DEV" ]; then
  echo "active dev branch: $DEV"
else
  echo "active dev branch: none -- no refs/remotes/origin/dev-* exists, so"
  echo "       no-work-on-stale-branch.sh abstains rather than refusing."
fi

# Whether origin/main is an ancestor of the active dev branch. This is the one
# place the argument for reading it is made; check-hooks.sh and CLAUDE.md point
# here. A worktree whose creation skipped the step that sets its fork point
# starts wherever worktree.baseRef in settings.json puts it, and `fresh` puts it
# at origin/main -- behind the dev branch, and refused at its first commit by
# the ahead/behind test. That holds only while origin/main is an ancestor. A
# dev-NN merged into main before rotation, or any change landed on main another
# way, turns it false, and then the same branch starts ahead and is permitted in
# silence. So the assumption is read here each session rather than written down
# anywhere it could go stale.
#
# Three outcomes, because `git merge-base --is-ancestor` has three answers: 0 is
# yes, 1 is no, and anything else -- 128 when a ref does not resolve, or a
# repository git cannot read -- is no answer. An unanswered question printed as
# NOT would be a warning about an ancestry nobody saw. No network: it reads refs
# already on disk, so none of the three budgets above is spent on it. When no fetch
# succeeded those refs are whatever the last successful one left, and every
# outcome says so, the positive one most of all -- an ancestry that has since
# broken still reads as intact.
if [ -n "$DEV" ]; then
  git merge-base --is-ancestor refs/remotes/origin/main "refs/remotes/$DEV" 2>/dev/null
  ANCESTRY=$?
  case "$ANCESTRY" in
    0) echo "main ancestry: origin/main is an ancestor of $DEV$STALE_REFS" ;;
    1) echo "main ancestry: origin/main is NOT an ancestor of $DEV -- a branch cut"
       echo "       from origin/main starts ahead of the active dev branch, and the ahead/behind"
       echo "       test in no-work-on-stale-branch.sh passes a branch that is ahead.$STALE_REFS" ;;
    *) echo "main ancestry: NOT READ -- git merge-base --is-ancestor exited $ANCESTRY rather"
       echo "       than answering; 128 is a ref that does not resolve to a commit$STALE_REFS" ;;
  esac
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

  AHEAD=
  BEHIND=
  if [ -n "$DEV" ]; then
    COUNTS=$(git rev-list --left-right --count "$DEV...refs/heads/$BRANCH" 2>/dev/null)
    BEHIND=$(printf '%s' "$COUNTS" | cut -f1)
    AHEAD=$(printf '%s' "$COUNTS" | cut -f2)
  fi

  # The sweep's three classes, as it defines them.
  if [ -n "$PRS_READ" ]; then
    PR=$(pr_of "$BRANCH")
    PR_STATE=$(printf '%s' "$PR" | cut -f2)
    PR_NUM=$(printf '%s' "$PR" | cut -f3)
    PR_HEAD=$(printf '%s' "$PR" | cut -f4)
    # At or behind the pull request's head, or that pull request is not this
    # branch's to decide. A head this clone does not have is not an ancestor.
    AT_HEAD=
    case "$PR_STATE" in MERGED|CLOSED)
      [ -n "$PR_HEAD" ] \
        && git merge-base --is-ancestor "refs/heads/$BRANCH" "$PR_HEAD" 2>/dev/null \
        && AT_HEAD=1 ;;
    esac
    if [ -n "$AHEAD" ]; then
      AHEAD_BEHIND="; $AHEAD ahead of $DEV, $BEHIND behind it"
    else
      AHEAD_BEHIND=
    fi
    case "$PR_STATE" in
      OPEN)
        CLEAR=$((CLEAR + 1)) ;;
      MERGED|CLOSED)
        if [ -z "$AT_HEAD" ]; then
          REPORT="$REPORT
  $BRANCH -- pull request #$PR_NUM is $(printf '%s' "$PR_STATE" | tr 'A-Z' 'a-z'), but this branch is not at or behind its head$AHEAD_BEHIND (unclassified: a reused name, or work after it)$HERE"
          UNCLASSIFIED=$((UNCLASSIFIED + 1))
        elif [ "$PR_STATE" = MERGED ]; then
          REPORT="$REPORT
  $BRANCH -- merged: pull request #$PR_NUM$HERE"
          STALE=$((STALE + 1))
        else
          REPORT="$REPORT
  $BRANCH -- closed without merging: pull request #$PR_NUM; its commits may exist nowhere else$HERE"
          STALE=$((STALE + 1))
        fi ;;
      *)
        REPORT="$REPORT
  $BRANCH -- no pull request$AHEAD_BEHIND (unclassified: cut and not yet worked, or abandoned)$HERE"
        UNCLASSIFIED=$((UNCLASSIFIED + 1)) ;;
    esac
    continue
  fi

  # Ref state alone, when the pull requests could not be read. A gone upstream
  # is what delete_branch_on_merge leaves, and also what deleting the branch of
  # a closed pull request by hand leaves, so it is not called merged.
  if [ "$TRACK" = "[gone]" ]; then
    REPORT="$REPORT
  $BRANCH -- stale by ref state: its branch on the remote is gone (merged, or closed and deleted)$HERE"
    STALE=$((STALE + 1))
    continue
  fi

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

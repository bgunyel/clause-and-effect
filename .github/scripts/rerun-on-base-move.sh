#!/bin/bash
# Re-run check-hooks on every open pull request into a dev branch that has just
# moved -- #199's requirement 4, option (b). Run by check-hooks-base-moved.yml.
#
# WHY. A pull_request run tests the merge GitHub computed when it started. When
# the base moves nothing re-runs it, so the check stays green on a merge that no
# longer exists: on PR #196 that lasted 51 minutes, seven commits behind dev-05.
# This reports the staleness; it blocks nothing, because a ruleset that could
# block (option (a)) is ADR 0001's question and #203's, not #199's.
#
# WHY A RE-RUN, AND WHY IT IS NOT PINNED TO THE OLD MERGE. Re-running a run
# replays its event, so `github.sha` stays the old merge commit. check-hooks.yml
# does not check out `github.sha`: it checks out `refs/pull/N/merge` by name,
# which a re-run fetches as it stands now, and its verify-merge step then fails
# unless that commit's first parent is the base's current tip. So a re-run tests
# the rebuilt merge or goes red saying why -- never the old merge in silence.
# The re-run replaces the stale check on the pull request in place: same run,
# same check name, a new attempt.
#
# The rejected alternative is a workflow_dispatch on each head branch. It runs
# the workflow file of that branch, and a branch cut before check-hooks.yml
# existed has none, so every pull request already open when this landed would be
# skipped. What a re-run gives up for that: it replays the workflow file of the
# run it repeats, taken from the merge commit that run was first triggered on.
# An edit to check-hooks.yml on dev-NN therefore reaches a pull request's check
# at its next push, not at its next re-run. The suite and verify-merge are read
# from the fresh checkout, so they are always current.
#
# WHAT IT CANNOT RE-RUN. GitHub refuses a re-run 30 days after a run started,
# and after a run's 50th attempt. The refusal fails this job, naming the pull
# request, but that pull request's own check stays green on the old merge until
# a push to its branch starts a new run. That is the defect this script exists
# for, left open for those pull requests, so the error says what closes it.
#
# WHY IT WAITS. GitHub rebuilds refs/pull/N/merge asynchronously after a push to
# the base, and reading the pull request is what asks it to. A re-run before the
# rebuild would test the old merge and fail verify-merge for a reason that goes
# away seconds later. It never rebuilds a pull request that conflicts with its
# base, so that one is re-run at once, and its red check is the report.
#
# A run still in progress may already have fetched the old merge, so it is
# cancelled, and the re-run is asked for once it has stopped, or once the wait
# runs out. GitHub refuses to re-run a run that has not stopped, and that
# refusal fails this job like any other.
#
# Every API failure is loud. A read that fails is an error for that pull
# request and fails the job, and never reads as "nothing to do": an empty list
# of runs and a failed request for it are not the same answer.
#
# Needs: REPO (owner/name), BASE (the branch pushed), TIP (its new commit), and
# GH_TOKEN with actions:write, pull-requests:read and contents:read -- the last
# for reading a merge commit's parents. POLL_SECONDS and WAIT_TRIES bound each
# wait; the tests set the first to 0.
set -uo pipefail
: "${REPO:?}" "${BASE:?}" "${TIP:?}"
WORKFLOW=check-hooks.yml
POLL_SECONDS=${POLL_SECONDS:-5}
WAIT_TRIES=${WAIT_TRIES:-36}

prs=$(gh api --paginate "repos/$REPO/pulls?state=open&base=$BASE&per_page=100" \
        --jq '.[] | "\(.number) \(.head.sha)"') || {
  echo "::error::could not list the open pull requests into $BASE"
  exit 1
}
if [ -z "$prs" ]; then
  echo "no open pull request targets $BASE"
  exit 0
fi

status=0
# The list is read on fd 3, so nothing in the loop can consume it from stdin.
while read -r pr head <&3; do
  echo "::group::#$pr, head $head"

  rebuilt=
  for ((i = 0; i < WAIT_TRIES; i++)); do
    read -r mergeable merge_sha < <(gh api "repos/$REPO/pulls/$pr" \
                                      --jq '"\(.mergeable) \(.merge_commit_sha)"')
    if [ "$mergeable" = false ]; then
      echo "::warning::#$pr conflicts with $BASE at $TIP, so GitHub will not rebuild its merge ref; the re-run will fail on that"
      rebuilt=conflict
      break
    fi
    if [ "$mergeable" = true ] && [ -n "$merge_sha" ] && [ "$merge_sha" != null ] \
       && [ "$(gh api "repos/$REPO/commits/$merge_sha" --jq '.parents[0].sha')" = "$TIP" ]; then
      echo "#$pr: the merge ref is rebuilt on $TIP"
      rebuilt=yes
      break
    fi
    sleep "$POLL_SECONDS"
  done
  [ -n "$rebuilt" ] \
    || echo "::warning::#$pr: GitHub did not rebuild the merge ref on $TIP within the wait; the re-run will fail if it still has not"

  if ! run=$(gh api "repos/$REPO/actions/workflows/$WORKFLOW/runs?event=pull_request&head_sha=$head&per_page=1" \
               --jq '.workflow_runs[0] | select(. != null) | "\(.id) \(.status)"'); then
    echo "::error::#$pr: could not list its $WORKFLOW runs, so its check was not re-run"
    status=1
    echo "::endgroup::"
    continue
  fi
  if [ -z "$run" ]; then
    echo "::warning::#$pr has no $WORKFLOW run for its head $head, so there is nothing to re-run; a push to its branch starts one"
    echo "::endgroup::"
    continue
  fi
  read -r run_id run_status <<< "$run"
  url="https://github.com/$REPO/actions/runs/$run_id"

  if [ "$run_status" != completed ]; then
    echo "#$pr: $url is $run_status and may have fetched the old merge; cancelling it"
    gh api -X POST "repos/$REPO/actions/runs/$run_id/cancel" >/dev/null \
      || echo "::warning::#$pr: the cancel of $url was refused; it may have finished meanwhile"
    for ((i = 0; i < WAIT_TRIES; i++)); do
      [ "$(gh api "repos/$REPO/actions/runs/$run_id" --jq .status)" = completed ] && break
      sleep "$POLL_SECONDS"
    done
  fi

  if gh api -X POST "repos/$REPO/actions/runs/$run_id/rerun" >/dev/null; then
    echo "#$pr: re-ran $url"
  else
    echo "::error::#$pr: the re-run of $url was refused, so its check still stands on the old merge; a push to its branch starts a new run"
    status=1
  fi
  echo "::endgroup::"
done 3<<< "$prs"
exit $status

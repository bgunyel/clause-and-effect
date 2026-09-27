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
# THE GOVERNING CONSTRAINT (#208). A misfire of this job may end in a red check,
# a cancelled check or a warning. It must never leave a green check-hooks
# standing on a merge that is no longer the merge on the base's tip. Where a
# rule below has to choose, it chooses the re-run.
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
# WHOSE RUN IT IS (#208, item 2). The runs are listed by head SHA, and two open
# pull requests can share a head, so the first run for a head can be the other
# pull request's. A run's REST record does not say which pull request started
# it: its `pull_requests` is, in GitHub's own words, the pull requests "that are
# open with a head_sha or head_branch that matches the workflow run", which "do
# not necessarily indicate pull requests that triggered the run" -- so two runs
# of one shared head both list both pull requests. check-hooks.yml therefore
# stamps the number into the run's title (`run-name: '#N <title>'`), which the
# record carries as `display_title`, and a run is this pull request's when its
# title opens with `#N `. A run started before the stamp existed has none; it
# is taken only when its `pull_requests` is exactly this one pull request.
#
# THE TRADE, for those unstamped runs only. GitHub leaves `pull_requests` empty
# on a run for a pull request from a fork, so an unstamped fork run matches
# nothing and gets the "nothing to re-run" warning instead of a re-run: its
# check stays green on the old merge until a push to its branch starts a
# stamped run. A stamped fork run is found by its title and re-run like any
# other. An unstamped run whose pull request's title itself opened with `#N `
# would be read as N's; no title here has that shape.
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
# THE WAITS ARE SHARED, AND BOUNDED IN TOTAL (#208, item 3). Every pull request
# is read before any is waited on -- the first reads are what start GitHub's
# mergeability computation for all of them -- and the ones not yet rebuilt are
# then polled together, round by round, as the cancelled runs are later. So a
# slow pull request costs the others nothing. Each pull request is read at most
# WAIT_TRIES times in each wait, and no wait sleeps past DEADLINE_SECONDS after
# the job started. The default 600 is half the job's 20-minute timeout: the two
# waits at their default tries take 2 x 36 x 5 = 360 s of sleep, and what the
# deadline leaves is for the requests, a handful per pull request, which it does
# not bound. A pull request still unresolved when a wait ends is re-run anyway,
# with a warning that says which bound ended it.
#
# A RUN ALREADY PROVEN CURRENT IS LEFT ALONE (#208, item 4), to save the
# runner-time of repeating it -- 308 s for run 35836366963. The proof has to be
# positive, because a wrong skip is a stale green: the run completed with
# success or failure, so the suite ran to its end, and the commit it tested is
# the pull request's merge commit as it stands, whose first parent is TIP and
# whose second is the head the pull request has now. The tested commit is not
# on the run's record; the run writes it into check-hooks.json in its
# check-hooks-attempt-<n> artifact, which is read for the run's latest attempt.
# No artifact, two of them, an expired one, a JSON without the commit, or any
# commit but the merge means a re-run.
#
# THE HEAD IS READ AGAIN BEFORE EVERY WRITE (#208, item 1). If the author pushed
# after the list was read, the listed head's run is not this pull request's
# check any more, and cancelling or re-running it would join check-hooks'
# per-pull-request concurrency group and cancel the new head's run. So it is
# left alone. That leaves no stale green, because the new head's push started
# its own run after TIP was pushed -- this job runs on that push, and the list
# was read after it -- and that run's verify-merge refuses any merge not built
# on the base's tip at the time it checks. The window between the read and the
# write is one request wide, and is not closed.
#
# Every API failure is loud. A read that fails is an error for that pull
# request and fails the job, and never reads as a routine answer: an empty list
# of runs and a failed request for it are not the same answer, and neither are
# a merge ref GitHub has not rebuilt yet, or a run that has not stopped yet, and
# a failed request to find out. Where a failed read leaves the re-run still
# possible, it is still asked for, because skipping it would leave the stale
# green standing; the job is red either way. Two reads leave nothing to ask
# for: the list of open pull requests, whose failure fails the job before any
# pull request is looked at, and a pull request's list of runs, whose failure
# leaves no run to re-run.
#
# Needs: REPO (owner/name), BASE (the branch pushed), TIP (its new commit), and
# GH_TOKEN with actions:write, pull-requests:read and contents:read -- the last
# for reading a merge commit's parents; actions covers reading an artifact.
# POLL_SECONDS is the sleep between rounds of a wait, WAIT_TRIES the reads of
# one pull request or run in one wait, DEADLINE_SECONDS the total; python3
# reads the artifact. The tests put a fake `date` and `sleep` first on PATH.
set -uo pipefail
: "${REPO:?}" "${BASE:?}" "${TIP:?}"
WORKFLOW=check-hooks.yml
POLL_SECONDS=${POLL_SECONDS:-5}
WAIT_TRIES=${WAIT_TRIES:-36}
DEADLINE_SECONDS=${DEADLINE_SECONDS:-600}
deadline=$(( $(date +%s) + DEADLINE_SECONDS ))
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

prs=$(gh api --paginate "repos/$REPO/pulls?state=open&base=$BASE&per_page=100" \
        --jq '.[] | "\(.number) \(.head.sha)"') || {
  echo "::error::could not list the open pull requests into $BASE"
  exit 1
}
if [ -z "$prs" ]; then
  echo "no open pull request targets $BASE"
  exit 0
fi

status=0 ended_by= head_read= tested=
order=()
declare -A head rebuilt merge merged_head run_id run_url
while read -r pr sha; do
  order+=("$pr")
  head[$pr]=$sha
done <<< "$prs"

# One round of a shared wait is over: sleep until the next, unless a bound says
# stop. Prints what ended the wait, if one did.
next_round() {  # round
  local now left
  if (( $1 + 1 >= WAIT_TRIES )); then echo tries; return 1; fi
  now=$(date +%s)
  left=$(( deadline - now ))
  if (( left <= 0 )); then echo deadline; return 1; fi
  sleep $(( left < POLL_SECONDS ? left : POLL_SECONDS ))
}

# Whether the pull request's head is still the one listed, read just before a
# write. Returns 1 when it moved, and the write must not happen. Sets head_read
# to ok, or to failed when the read failed and the write goes ahead unproven.
head_still() {  # pr what
  local pr=$1 now
  if ! now=$(gh api "repos/$REPO/pulls/$pr" --jq .head.sha); then
    echo "::error::#$pr: could not re-read its head, so whether ${head[$pr]} is still it is unknown; the $2 goes ahead"
    status=1 head_read=failed
    return 0
  fi
  head_read=ok
  [ "$now" = "${head[$pr]}" ] && return 0
  echo "#$pr: its head moved from ${head[$pr]} to $now after it was listed, so ${run_url[$pr]} is not its check any more; its new head's own run tests the merge on $TIP, and the $2 is not asked for"
  return 1
}

# Sets `tested` to the commit a completed run tested, read from its latest
# attempt's artifact, or to nothing when the run left no single readable
# record of it, and says why.
read_tested_commit() {  # pr id attempt
  local pr=$1 id=$2 attempt=$3 listed zip=$scratch/$2.zip
  local -a ids
  tested=
  if ! listed=$(gh api "repos/$REPO/actions/runs/$id/artifacts?name=check-hooks-attempt-$attempt" \
                  --jq '[.artifacts[] | select(.expired | not) | .id | tostring] | join(" ")'); then
    echo "::error::#$pr: could not list the artifacts of ${run_url[$pr]}, so what it tested is unknown; re-running it"
    status=1
    return
  fi
  read -ra ids <<< "$listed"
  if [ "${#ids[@]}" -ne 1 ]; then
    echo "#$pr: ${run_url[$pr]} has ${#ids[@]} unexpired check-hooks-attempt-$attempt artifacts, not one, so what it tested is unknown; re-running it"
    return
  fi
  if ! gh api "repos/$REPO/actions/artifacts/${ids[0]}/zip" > "$zip" \
     || ! tested=$(python3 -c 'import json, sys, zipfile
print(json.load(zipfile.ZipFile(sys.argv[1]).open("check-hooks.json")).get("tested_commit") or "")' "$zip"); then
    echo "::error::#$pr: could not read check-hooks.json from artifact ${ids[0]} of ${run_url[$pr]}, so what it tested is unknown; re-running it"
    status=1 tested=
    return
  fi
  [ -n "$tested" ] \
    || echo "#$pr: check-hooks.json of ${run_url[$pr]} names no tested commit; re-running it"
}

echo "::group::waiting for GitHub to rebuild each merge ref on $TIP"
pending=("${order[@]}")
for ((round = 0; ; round++)); do
  still=()
  for pr in "${pending[@]}"; do
    if ! state=$(gh api "repos/$REPO/pulls/$pr" --jq '"\(.mergeable) \(.merge_commit_sha)"'); then
      echo "::error::#$pr: could not read the pull request, so whether its merge ref is rebuilt on $TIP is unknown; re-running it anyway"
      status=1 rebuilt[$pr]=unread
      continue
    fi
    read -r mergeable merge_sha <<< "$state"
    if [ "$mergeable" = false ]; then
      echo "::warning::#$pr conflicts with $BASE at $TIP, so GitHub will not rebuild its merge ref; the re-run will fail on that"
      rebuilt[$pr]=conflict
      continue
    fi
    if [ "$mergeable" = true ] && [ -n "$merge_sha" ] && [ "$merge_sha" != null ]; then
      if ! parents=$(gh api "repos/$REPO/commits/$merge_sha" --jq '"\(.parents[0].sha) \(.parents[1].sha)"'); then
        echo "::error::#$pr: could not read the parents of its merge commit $merge_sha, so whether its merge ref is rebuilt on $TIP is unknown; re-running it anyway"
        status=1 rebuilt[$pr]=unread
        continue
      fi
      read -r first_parent second_parent <<< "$parents"
      if [ "$first_parent" = "$TIP" ]; then
        echo "#$pr: the merge ref is rebuilt on $TIP"
        rebuilt[$pr]=yes merge[$pr]=$merge_sha merged_head[$pr]=$second_parent
        continue
      fi
    fi
    still+=("$pr")
  done
  pending=("${still[@]}")
  [ "${#pending[@]}" -eq 0 ] && break
  ended_by=$(next_round "$round") || break
done
for pr in "${pending[@]}"; do
  if [ "$ended_by" = deadline ]; then
    echo "::warning::#$pr: the job's ${DEADLINE_SECONDS} s of waiting ran out before GitHub rebuilt the merge ref on $TIP; re-running it anyway, and the re-run will fail if it still has not"
  else
    echo "::warning::#$pr: GitHub did not rebuild the merge ref on $TIP within the wait; the re-run will fail if it still has not"
  fi
done
echo "::endgroup::"

echo "::group::finding each pull request's own run"
rerun=()
stopping=()
for pr in "${order[@]}"; do
  # Newest first, and a head's runs are few, so the first page holds its latest.
  if ! run=$(gh api "repos/$REPO/actions/workflows/$WORKFLOW/runs?event=pull_request&head_sha=${head[$pr]}&per_page=100" \
               --jq "[.workflow_runs[] | select((.display_title | startswith(\"#$pr \"))
                      or ((.display_title | test(\"^#[0-9]+ \") | not) and [.pull_requests[].number] == [$pr]))][0]
                     | select(. != null) | \"\(.id) \(.status) \(.conclusion) \(.run_attempt)\""); then
    echo "::error::#$pr: could not list its $WORKFLOW runs, so its check was not re-run"
    status=1
    continue
  fi
  if [ -z "$run" ]; then
    echo "::warning::#$pr has no $WORKFLOW run for its head ${head[$pr]} that is known to be its own, so there is nothing to re-run; a push to its branch starts one"
    continue
  fi
  read -r id run_status conclusion attempt <<< "$run"
  run_id[$pr]=$id
  run_url[$pr]="https://github.com/$REPO/actions/runs/$id"

  if [ "$run_status" = completed ] && [ "${rebuilt[$pr]:-}" = yes ] \
     && { [ "$conclusion" = success ] || [ "$conclusion" = failure ]; }; then
    read_tested_commit "$pr" "$id" "$attempt"
    if [ -z "$tested" ]; then
      :  # read_tested_commit said why
    elif [ "$tested" != "${merge[$pr]}" ]; then
      echo "#$pr: ${run_url[$pr]} tested $tested, not ${merge[$pr]}, its merge on $TIP; re-running it"
    elif [ "${merged_head[$pr]}" != "${head[$pr]}" ]; then
      echo "#$pr: its merge ${merge[$pr]} merges ${merged_head[$pr]}, not its head ${head[$pr]}; re-running it"
    elif ! head_still "$pr" re-run; then
      continue
    elif [ "$head_read" = ok ]; then
      echo "#$pr: ${run_url[$pr]} already tested ${merge[$pr]}, the merge of its head ${head[$pr]} on $TIP, so it is not re-run"
      continue
    fi
  fi

  if [ "$run_status" != completed ]; then
    head_still "$pr" cancel || continue
    echo "#$pr: ${run_url[$pr]} is $run_status and may have fetched the old merge; cancelling it"
    gh api -X POST "repos/$REPO/actions/runs/$id/cancel" >/dev/null \
      || echo "::warning::#$pr: the cancel of ${run_url[$pr]} was refused; it may have finished meanwhile"
    stopping+=("$pr")
  fi
  rerun+=("$pr")
done
echo "::endgroup::"

if [ "${#stopping[@]}" -gt 0 ]; then
  echo "::group::waiting for the cancelled runs to stop"
  for ((round = 0; ; round++)); do
    still=()
    for pr in "${stopping[@]}"; do
      if ! now=$(gh api "repos/$REPO/actions/runs/${run_id[$pr]}" --jq .status); then
        echo "::error::#$pr: could not read the status of ${run_url[$pr]}, so whether it has stopped is unknown; asking for its re-run anyway"
        status=1
        continue
      fi
      [ "$now" = completed ] || still+=("$pr")
    done
    stopping=("${still[@]}")
    [ "${#stopping[@]}" -eq 0 ] && break
    ended_by=$(next_round "$round") || break
  done
  for pr in "${stopping[@]}"; do
    if [ "$ended_by" = deadline ]; then
      echo "::warning::#$pr: the job's ${DEADLINE_SECONDS} s of waiting ran out before ${run_url[$pr]} stopped, and GitHub refuses to re-run a run that has not stopped"
    else
      echo "::warning::#$pr: ${run_url[$pr]} did not stop within the wait, and GitHub refuses to re-run a run that has not stopped"
    fi
  done
  echo "::endgroup::"
fi

for pr in "${rerun[@]}"; do
  head_still "$pr" re-run || continue
  if gh api -X POST "repos/$REPO/actions/runs/${run_id[$pr]}/rerun" >/dev/null; then
    echo "#$pr: re-ran ${run_url[$pr]}"
  else
    echo "::error::#$pr: the re-run of ${run_url[$pr]} was refused, so its check still stands on the old merge; a push to its branch starts a new run"
    status=1
  fi
done
exit $status

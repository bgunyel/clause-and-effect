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
# record carries as `display_title`, and the newest run whose title opens with
# `#N ` is this pull request's own, and the one run taken.
#
# A run started before the stamp existed has none, and nothing on it says whose
# it is. When no run of the head is stamped as this pull request's, every
# unstamped run that lists it in `pull_requests` is taken, since any of them
# may be its own: of two pull requests sharing a head, the newest unstamped run
# can be the other's, and leaving the rest would leave this one's check green
# on the old merge. A run two pull requests take is handled once, and judged
# for all of them: it is left alone only when every one has moved its head, or
# when it is proven current (review round 2, G5). They are re-run oldest
# first, because a pull request's runs share its concurrency group, where each
# re-run queued cancels the one before it; the newest run's event is the one
# left standing. A run stamped as another pull request's is never taken, even
# when it lists only this one.
#
# What that costs, all of it gone once each pull request has pushed a stamped
# run. Red or cancelled: an older run's re-run is started and cancelled; a run
# taken by a pull request that has since moved its head is still re-run while
# another that took it has not, and if it was the moved one's, it cancels that
# one's newer run and fails its verify-merge; and a run past GitHub's 30 days
# is refused, which fails this job. Not established, and possibly a stale
# green (#269): a closed pull request's run on the same head lists this one --
# the field names open ones only -- and is re-run as the closed one's. It is
# red if its merge ref is gone or its base has moved; otherwise it may go green
# on this pull request's head commit under the same check name, and which of
# the two check runs this pull request then shows was not observed. The case
# predates #208: the newest run for the head was re-run whatever it was.
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
# cancelled once every pull request's runs are listed -- so that a run two of
# them took is judged for both -- and before any wait, and the re-run is asked
# for once it has stopped, or once the wait runs out. GitHub refuses to re-run
# a run that has not stopped, and that refusal fails this job like any other.
#
# ONE WAIT, SHARED, AND BOUNDED IN TOTAL (#208, item 3). Every pull request that
# took a run to re-run is read before any is waited on -- the first reads are what
# start GitHub's mergeability computation for all of them -- and each round of
# the one wait then reads every merge ref not yet rebuilt and every cancelled
# run not yet stopped. So a slow pull request delays the others' re-runs by at
# most the wait, and takes none of their waiting: a merge ref that never
# rebuilds cannot spend the rounds another pull request's run needs to stop.
# The wait has at most WAIT_TRIES rounds, and none starts after
# DEADLINE_SECONDS from this script's start: the deadline is read off the
# clock, so it counts the rounds' own requests as well as their sleeps, and the
# last sleep is cut to it. A round started just before it still makes its
# requests after it. The default 600 is half the job's 20-minute timeout. At
# its default tries the wait sleeps at most 35 x 5 = 175 s, and what the
# deadline leaves is for the requests after the wait, a handful per run, which
# nothing bounds but the job's timeout. A pull request still unresolved when
# the wait ends is re-run anyway, with a warning that says which bound ended it.
#
# A RUN ALREADY PROVEN CURRENT IS LEFT ALONE (#208, item 4), to save the
# runner-time of repeating it -- 308 s for run 35836366963 (#206,
# 2026-09-23). The proof has to be positive, because a wrong skip is a stale
# green: the run completed with success or failure; its suite ran to its end,
# which check-hooks.json records as `ended: exited` -- the conclusion alone
# does not say it, because a suite step's timeout also concludes `failure`
# (run 36320798357); and the commit it tested is the pull request's merge
# commit as it stands, whose first parent is TIP and whose second is the head
# the pull request has now. Neither the ending nor the tested commit is on the
# run's record; the run writes both into check-hooks.json in its
# check-hooks-attempt-<n> artifact, which is read for the run's latest attempt.
# No artifact, two of them, an expired one, a JSON with no ending or any ending
# but exited -- a record from before #208 has none -- a JSON without the
# commit, or any commit but the merge means a re-run.
#
# THE HEAD IS READ AGAIN BEFORE EVERY WRITE (#208, item 1). If the author pushed
# after the list was read, the listed head's run is not this pull request's
# check any more, and cancelling or re-running it would join check-hooks'
# per-pull-request concurrency group and cancel the new head's run. So it is
# left alone. That leaves no stale green, because the new head's push started
# its own run after TIP was pushed -- this job runs on that push, and the list
# was read after it -- and that run's verify-merge refuses any merge not built
# on the base's tip at the time it checks. The window between the read and the
# write is one request wide, and is not closed. An unstamped run that several
# pull requests took is left alone only when every one of them has moved.
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
# POLL_SECONDS is the sleep between rounds of the wait, WAIT_TRIES its rounds,
# which is the reads of one pull request or run in it -- what it meant before
# the two waits became one -- and DEADLINE_SECONDS its bound in time; python3
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
order=() runs=() stopping=()
declare -A head rebuilt merge merged_head
# Keyed by run id: the pull request it was found for, and its listed state.
# `takers` lists every pull request that took the run, the first of them
# being `found_for`: more than one only for an unstamped run.
declare -A found_for takers run_status conclusion attempt run_url
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

# Whether a pull request that took run `id` still has the head it was listed
# with, read just before a write to the run. An unstamped run that two pull
# requests took may be either one's own, so the write is dropped only when
# every one of them has moved (review round 2, G5); the first one found
# unmoved is enough to write. A moved taker's line says only that the run is
# still handled, because the caller may yet leave it alone as proven current,
# and the line after it says which. Returns 1 when all moved. Sets head_read to ok
# when a head was read unmoved, or to failed when a read failed and the write
# goes ahead unproven.
taker_still() {  # id what
  local id=$1 pr now line
  local -a moved=()
  for pr in ${takers[$id]}; do
    if ! now=$(gh api "repos/$REPO/pulls/$pr" --jq .head.sha); then
      for line in "${moved[@]}"; do
        echo "$line; whether #$pr, which took it too, still has that head is unknown, so the run is still handled for it"
      done
      echo "::error::#$pr: could not re-read its head, so whether ${head[$pr]} is still it is unknown; the $2 goes ahead"
      status=1 head_read=failed
      return 0
    fi
    if [ "$now" = "${head[$pr]}" ]; then
      for line in "${moved[@]}"; do
        echo "$line; #$pr took it too and still has that head, so the run is still handled for it"
      done
      head_read=ok
      return 0
    fi
    moved+=("#$pr: its head moved from ${head[$pr]} to $now after it was listed, so ${run_url[$id]} is not its check any more; its new head's own run tests the merge on $TIP")
  done
  for line in "${moved[@]}"; do
    echo "$line, and the $2 is not asked for"
  done
  return 1
}

# Sets `tested` to the commit a completed run's suite ran to its end on, read
# from its latest attempt's artifact, or to nothing when the run left no single
# readable record of both, and says why.
read_tested_commit() {  # pr id
  local pr=$1 id=$2 listed record ended zip=$scratch/$2.zip
  local -a ids
  tested=
  if ! listed=$(gh api "repos/$REPO/actions/runs/$id/artifacts?name=check-hooks-attempt-${attempt[$id]}" \
                  --jq '[.artifacts[] | select(.expired | not) | .id | tostring] | join(" ")'); then
    echo "::error::#$pr: could not list the artifacts of ${run_url[$id]}, so what it tested is unknown; re-running it"
    status=1
    return
  fi
  read -ra ids <<< "$listed"
  if [ "${#ids[@]}" -ne 1 ]; then
    echo "#$pr: ${run_url[$id]} has ${#ids[@]} unexpired check-hooks-attempt-${attempt[$id]} artifacts, not one, so what it tested is unknown; re-running it"
    return
  fi
  if ! gh api "repos/$REPO/actions/artifacts/${ids[0]}/zip" > "$zip" \
     || ! record=$(python3 -c 'import json, sys, zipfile
record = json.load(zipfile.ZipFile(sys.argv[1]).open("check-hooks.json"))
print(record.get("ended") or "null", record.get("tested_commit") or "null")' "$zip"); then
    echo "::error::#$pr: could not read check-hooks.json from artifact ${ids[0]} of ${run_url[$id]}, so what it tested is unknown; re-running it"
    status=1
    return
  fi
  read -r ended tested <<< "$record"
  if [ "$ended" = null ]; then
    echo "#$pr: check-hooks.json of ${run_url[$id]} records no ending, so whether its suite ran to its end is unknown; re-running it"
    tested=
  elif [ "$ended" != exited ]; then
    echo "#$pr: check-hooks.json of ${run_url[$id]} records that its suite ended $ended, not exited; re-running it"
    tested=
  elif [ "$tested" = null ]; then
    echo "#$pr: check-hooks.json of ${run_url[$id]} names no tested commit; re-running it"
    tested=
  fi
}

echo "::group::finding each pull request's own runs"
for pr in "${order[@]}"; do
  # Newest first, and a head's runs are few, so the first page holds its latest.
  # The newest run stamped as this pull request's; else every unstamped run that
  # lists it, oldest first, so that of two in one concurrency group the newer
  # re-run is the one left standing.
  filter='[.workflow_runs[] | select(.display_title | startswith("#@N@ "))][0:1] as $own
    | if $own != [] then $own[] | "\(.id) \(.status) \(.conclusion) \(.run_attempt) stamped"
      else [.workflow_runs[] | select((.display_title | test("^#[0-9]+ ") | not)
                                      and any(.pull_requests[]; .number == @N@))]
           | reverse | .[] | "\(.id) \(.status) \(.conclusion) \(.run_attempt) unstamped"
      end'
  if ! found=$(gh api "repos/$REPO/actions/workflows/$WORKFLOW/runs?event=pull_request&head_sha=${head[$pr]}&per_page=100" \
                 --jq "${filter//@N@/$pr}"); then
    echo "::error::#$pr: could not list its $WORKFLOW runs, so its check was not re-run"
    status=1
    continue
  fi
  if [ -z "$found" ]; then
    echo "::warning::#$pr has no $WORKFLOW run for its head ${head[$pr]} that is known to be its own, so there is nothing to re-run; a push to its branch starts one"
    continue
  fi
  while read -r id st concl att kind; do
    if [ -n "${found_for[$id]:-}" ]; then
      takers[$id]+=" $pr"
      echo "#$pr: ${run_url[$id]} is unstamped and #${found_for[$id]} took it too; it is handled once for every pull request that took it, and left alone only if all their heads have moved or it is proven current"
      continue
    fi
    found_for[$id]=$pr takers[$id]=$pr
    run_status[$id]=$st conclusion[$id]=$concl attempt[$id]=$att
    run_url[$id]="https://github.com/$REPO/actions/runs/$id"
    [ "$kind" = unstamped ] \
      && echo "#$pr: no run of its head is stamped as its own, and ${run_url[$id]} is unstamped and lists it, so it may be its own; it is taken"
    runs+=("$id")
  done <<< "$found"
done
echo "::endgroup::"

# The cancels wait until every pull request's runs are listed, so that a run
# two of them took is judged by both.
kept=()
for id in "${runs[@]}"; do
  if [ "${run_status[$id]}" != completed ]; then
    taker_still "$id" cancel || continue
    echo "#${takers[$id]// / and #}: ${run_url[$id]} is ${run_status[$id]} and may have fetched the old merge; cancelling it"
    gh api -X POST "repos/$REPO/actions/runs/$id/cancel" >/dev/null \
      || echo "::warning::#${takers[$id]// / and #}: the cancel of ${run_url[$id]} was refused; it may have finished meanwhile"
    stopping+=("$id")
  fi
  kept+=("$id")
done
runs=("${kept[@]}")

# One wait for both things a re-run waits on, so that neither can spend the
# other's time: a pull request's merge ref, rebuilt on TIP, and a cancelled run,
# stopped. Only a pull request that took a run to re-run is waited on, and
# every one that took it, since the run may be any of theirs.
declare -A waited
pending=()
for id in "${runs[@]}"; do
  for pr in ${takers[$id]}; do
    [ -n "${waited[$pr]:-}" ] && continue
    waited[$pr]=1
    pending+=("$pr")
  done
done
echo "::group::waiting for GitHub to rebuild each merge ref on $TIP, and for each cancelled run to stop"
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
  still=()
  for id in "${stopping[@]}"; do
    if ! now=$(gh api "repos/$REPO/actions/runs/$id" --jq .status); then
      echo "::error::#${takers[$id]// / and #}: could not read the status of ${run_url[$id]}, so whether it has stopped is unknown; asking for its re-run anyway"
      status=1
      continue
    fi
    [ "$now" = completed ] || still+=("$id")
  done
  stopping=("${still[@]}")
  [ $(( ${#pending[@]} + ${#stopping[@]} )) -eq 0 ] && break
  ended_by=$(next_round "$round") || break
done
for pr in "${pending[@]}"; do
  if [ "$ended_by" = deadline ]; then
    echo "::warning::#$pr: the job's ${DEADLINE_SECONDS} s of waiting ran out before GitHub rebuilt the merge ref on $TIP; re-running it anyway, and the re-run will fail if it still has not"
  else
    echo "::warning::#$pr: GitHub did not rebuild the merge ref on $TIP within the wait; the re-run will fail if it still has not"
  fi
done
for id in "${stopping[@]}"; do
  if [ "$ended_by" = deadline ]; then
    echo "::warning::#${takers[$id]// / and #}: the job's ${DEADLINE_SECONDS} s of waiting ran out before ${run_url[$id]} stopped, and GitHub refuses to re-run a run that has not stopped"
  else
    echo "::warning::#${takers[$id]// / and #}: ${run_url[$id]} did not stop within the wait, and GitHub refuses to re-run a run that has not stopped"
  fi
done
echo "::endgroup::"

for id in "${runs[@]}"; do
  pr=${found_for[$id]}
  if [ "${run_status[$id]}" = completed ] && [ "${rebuilt[$pr]:-}" = yes ] \
     && { [ "${conclusion[$id]}" = success ] || [ "${conclusion[$id]}" = failure ]; }; then
    read_tested_commit "$pr" "$id"
    if [ -z "$tested" ]; then
      :  # read_tested_commit said why
    elif [ "$tested" != "${merge[$pr]}" ]; then
      echo "#$pr: ${run_url[$id]} tested $tested, not ${merge[$pr]}, its merge on $TIP; re-running it"
    elif [ "${merged_head[$pr]}" != "${head[$pr]}" ]; then
      echo "#$pr: its merge ${merge[$pr]} merges ${merged_head[$pr]}, not its head ${head[$pr]}; re-running it"
    elif ! taker_still "$id" re-run; then
      continue
    elif [ "$head_read" = ok ]; then
      echo "#$pr: ${run_url[$id]} already tested ${merge[$pr]}, the merge of its head ${head[$pr]} on $TIP, so it is not re-run"
      continue
    fi
  fi
  taker_still "$id" re-run || continue
  if gh api -X POST "repos/$REPO/actions/runs/$id/rerun" >/dev/null; then
    echo "#${takers[$id]// / and #}: re-ran ${run_url[$id]}"
  else
    echo "::error::#${takers[$id]// / and #}: the re-run of ${run_url[$id]} was refused, so its check still stands on the old merge; a push to its branch starts a new run"
    status=1
  fi
done
exit $status

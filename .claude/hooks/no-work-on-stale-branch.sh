#!/bin/bash
# A worktree branch exists for one pull request. When that pull request merges,
# the branch has served its purpose: remotely `delete_branch_on_merge` removes
# it, locally "The sweep" in the branch-hygiene skill does. Nothing stopped work
# continuing on that branch in the meantime, and that failure has fired twice --
# the probe->check rename was committed onto hooks-push-and-pr-guards after
# PR #35 had already merged it, and research/non-openrouter-response-bodies sat
# one commit ahead and nineteen behind with no pull request, loaded to revert
# nineteen commits the moment anyone proposed it.
#
# How often the sweep runs is that section's question and it answers it there;
# what belongs here is the consequence. The sweep is not triggered by the merge,
# so the window this guard covers opens when the pull request merges and closes
# only when someone gets round to sweeping -- it is bounded by nothing, and the
# guard is what makes that safe rather than merely untidy. CONTEXT.md's
# *worktree branch* entry carries the lifetime the two halves enforce together.
#
# Keyed on running in a linked worktree, the same keying no-git-push.sh uses and
# deliberately not on the branch's name. CONTEXT.md's *worktree branch* entry
# says why at length: worktrees are made two ways here and only one of them
# prefixes the branch, and a branch in the main checkout can be given whatever
# name a rule looks for.
#
# TWO DETECTORS, EACH COVERING THE OTHER'S BLIND SPOT.
#
# *The upstream is gone.* With delete_branch_on_merge on, a merged worktree
# branch is exactly a branch whose upstream has been pruned away. This reads the
# remote's existence rather than the commits' ancestry, so no merge style
# defeats it. `%(upstream:track)` reports `[gone]` for precisely that state --
# upstream configured, remote-tracking ref absent -- and `%(upstream)` does not,
# because it keeps naming the ref after the ref is gone. Measured on a fixture.
#
# *ahead == 0 && behind > 0* against the active dev branch, as the fallback for
# when nobody has pruned yet. This one rests on *merged implies ancestor*, which
# is a property of merge style rather than of git: a squash or a rebase merge
# rewrites the commits and leaves the branch no ancestor of anything.
#
# So the fallback REQUIRES allow_squash_merge and allow_rebase_merge to be
# disabled on the repository, which makes the assumption true by configuration
# rather than by habit. An assumption a repository setting can silently break is
# not an assumption; it is a bug with a delay.
#
# That is a repository setting and not something this file can assert: a
# PreToolUse hook has five seconds and cannot make a network call. It is also
# not something to write down here. This paragraph stated the value twice and
# was wrong both times -- it asserted both settings disabled before they were,
# corrected on d840e57, and then asserted them unapplied after they had been,
# which is #71. Neither error was noticed by anything; the second survived three
# commits to this file in one day. A hand-kept record of live remote state is
# the sentence above turned on its own mitigation: a record a repository setting
# can silently falsify is the same bug with the same delay.
#
# So the value is read rather than recorded. report-stale-branches.sh runs at
# SessionStart, is the one component here allowed a network call, and reports
# allow_squash_merge, allow_rebase_merge and delete_branch_on_merge whenever any
# has drifted from what this rule requires -- or reports that it could not read
# them. That report is the live answer, and nothing in this file is.
#
# Which detector a drift costs depends on which setting drifted, and saying
# "the other one still catches it" without that distinction is false in one of
# the three cases. Squash or rebase merging back on rewrites a merged branch's
# commits, so it is no ancestor and the fallback reads it as ahead > 0 -- there
# the gone detector still catches it, which is the point of having two.
# delete_branch_on_merge back off removes the gone detector itself, and the
# fallback is then the only one left rather than the backstop. Two detectors
# cover each other, but one at a time.
#
# THE ACTIVE DEV BRANCH is the highest-numbered refs/remotes/origin/dev-*, read
# with no network because a hook has five seconds. Sorted with `sort -V` and
# filtered to `^origin/dev-[0-9]+$`, and both halves earn their place: a lexical
# sort makes dev-09 beat dev-10, and an unfiltered glob lets origin/dev-foo --
# or origin/dev-05-backup -- win outright. Both were measured on a fixture
# rather than assumed. The branch-hygiene skill mandates two-digit
# zero-padding, so a lexical sort would be correct today and wrong at dev-10;
# the version sort does not depend on that mandate holding.
#
# report-stale-branches.sh derives the same branch from the same two lines and
# does not re-argue any of this: one argument, for both copies. Why a copy is
# preferred to a shared helper, and what holds the two copies equal, is in
# check-hooks.sh at the arming section.
#
# When no such ref exists -- a fresh clone, or the rotation window after the
# merged dev-NN is deleted and its successor is not yet pushed -- the guard
# ABSTAINS rather than refuses. These stop mistakes, not adversaries.
#
# THE MESSAGES STATE WHAT THE HOOK CAN SEE. `upstream: gone` fires only on the
# genuinely merged case, so that message says "merged" and means it. The
# fallback cannot distinguish a merged branch from a brand-new worktree branch
# that has not committed while dev-NN moved on -- the two are topologically
# identical and only a network call would separate them -- so its message is
# about state: this branch has no work of its own and the active dev branch has
# moved past it. check-hooks.sh pins both messages, because a change routing
# both states through one wording would leave the verdicts green and the claim
# false.
#
# WHICH COMMANDS. Any command that adds a commit makes ahead > 0 and retires the
# fallback for that branch permanently, so the test is not "would an agent
# plausibly write this" but "would this silently disable the rule". That is
# commit, cherry-pick, revert, merge and `am`. cherry-pick is not marginal -- it
# is the command in this repository's own recovery procedure. rebase is here
# too, not because it is in that list but because the carve-out below has to
# answer for it: a rebase onto anything but the active dev branch writes new
# commits onto this branch exactly as a merge would.
#
# Mid-operation continuations -- --continue, --abort, --skip, --quit -- are
# excluded, and the reason belongs here: a refusal mid-rebase strands state the
# agent cannot exit, and a guard that leaves the repository in a condition only
# a human can clear is worse than the mistake it prevents.
#
# THE ONE CARVE-OUT. Under the fallback, ahead == 0 means the branch is a strict
# ancestor of the active dev branch, so merging or rebasing onto that branch is
# a fast-forward: it creates no commit and masks nothing. Merge was in the set
# for a hazard unreachable in that exact state, and refusing it there deadlocks
# the branch -- no commit, no catch-up, and removing a worktree is a reserved
# act, so a timing race becomes a hand-off to a human. So under the fallback a
# merge or rebase naming the active dev branch is permitted, and one naming
# anything else is refused, because that one would create a real commit and
# would mask. Under `upstream: gone` both are refused: merging into a branch
# that no longer exists on the remote is meaningless.
#
# The carve-out is the only permitting path in a refused state, so it is a
# whitelist rather than a blacklist. Every token has to be either the active dev
# branch under one of its four spellings or an option from a short list that
# takes no value and creates no commit. --no-ff is not on that list and never
# will be: it is the spelling whose whole purpose is to write a merge commit
# where a fast-forward would do.
#
# A SPELLING IS NOT A COMMIT. Two of those four -- dev-NN and refs/heads/dev-NN
# -- name a local branch, while the ancestry above was read against
# refs/remotes/origin/dev-NN and against that ref alone. Git does not guarantee
# the two agree, and in this repository they routinely do not: worktree pull
# requests merge into dev-NN on GitHub, so origin/dev-NN moves while the local
# branch sits still, and the pruning fetch that report-stale-branches.sh
# performs updates refs/remotes/origin/* and leaves refs/heads/* exactly where
# they were. Nobody checks out and pulls dev-NN in a linked worktree. So each
# whitelisted token is resolved and required to name the commit the ancestry was
# read against; the equality is a condition this file checks, not a fact it may
# assert. Left unchecked, `git merge dev-NN` against a local branch that has
# forked -- not merely run ahead, since a branch ahead of origin/dev-NN still
# has this one as an ancestor and the merge still fast-forwards -- writes a real
# merge commit. ahead becomes > 0, and the fallback detector is retired for that
# branch permanently: silent, and in the permitting direction, which is the test
# for inclusion stated above.
#
# THE TRADE THAT MAKES, RECORDED. The test is an identity, so it refuses the
# short spelling whenever local dev-NN is not exactly origin/dev-NN -- not only
# when it has forked. TWO HARMLESS CASES ARE GIVEN UP WITH IT, and both are
# named here rather than left to be discovered:
#
# *No local dev-NN at all*, which is what a linked worktree normally sees.
# `git merge dev-NN` was permitted and is now refused. Nothing is lost: run for
# real in that state the command fails in git anyway, because dev-NN resolves
# through refs/heads/, refs/tags/ and refs/remotes/<name>/ and a remote-tracking
# origin/dev-NN is none of those.
#
# *A local dev-NN merely BEHIND origin/dev-NN*, which is the ordinary state here
# and becomes the common one the moment a pull request lands on GitHub: the
# remote half moves and the local branch sits still. That merge is a no-op or a
# fast-forward to a commit this branch is already an ancestor of, so it writes
# nothing and masks nothing, and it is refused all the same. This is the case
# the identity test cannot separate from the forked one without asking a
# question about ancestry that the whitelist exists to not ask -- a hook that
# rev-parses its way to a merge-base decision is a larger claim than this
# defect needs.
#
# Both refusals cost one edit: the message already names origin/dev-NN, which is
# the spelling that works in every one of these states.
#
# ARMED BY report-stale-branches.sh. Both detectors read remote-tracking refs
# and are exactly as fresh as the last fetch -- the fallback no less than the
# gone test, since origin/dev-NN is a remote-tracking ref too. A hook cannot
# fetch, so a SessionStart hook does it, with an explicit --prune. Two soft
# edges follow and both are deliberate. The fetch fails open, so an offline or
# slow session proceeds with neither detector armed; that is announced by the
# report, which says the fetch failed. And permitting the catch-up merge means a
# genuinely merged branch can be fast-forwarded to the tip, after which both
# detectors read clean -- a window lasting only a session, in which a merge
# lands after that session's fetch, closed at the next session start.
#
# NOT COVERED, AND DELIBERATELY. `git pull` is fetch plus merge and can write a
# merge commit; it is not matched here. On a gone branch it fails of its own
# accord, and on the fallback it is the catch-up the carve-out exists to permit.
# `git stash pop`, `git apply` and `git checkout -- .` change the working tree
# and write no commit, so they do not move ahead and do not disable the rule.
# `git reset` and `git branch -f` can move the branch and are not matched: they
# are the shapes of a recovery, not of work continuing by mistake.
#
# STOPPING RULE, inherited from no-git-push.sh. A newly found evasion earns a
# fix only if it is a shape an agent would plausibly write, not one it would
# have to construct. A wrapper's payload sits in quotes where no command
# position exists, so wrappers are refused outright rather than parsed.
#
# This stops mistakes, not adversaries.

set -f

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# Every command this file refuses is a git subcommand, so text with no `git` in
# it anywhere cannot hold one -- a wrapped payload included, since the payload
# still carries the word. This bail runs before the library is needed and before
# any git process is started, so `ls` in a stale worktree costs one grep.
echo "$COMMAND" | grep -q 'git' || exit 0

# The exception is keyed on where the command runs, not on what the branch is
# called: in a linked worktree --git-dir is .git/worktrees/<name> while
# --git-common-dir is .git; in the main checkout the two are equal. The main
# checkout is unaffected by this file.
GIT_DIR_PATH=$(git rev-parse --git-dir 2>/dev/null)
GIT_COMMON_PATH=$(git rev-parse --git-common-dir 2>/dev/null)
[ -n "$GIT_DIR_PATH" ] || exit 0
[ "$GIT_DIR_PATH" = "$GIT_COMMON_PATH" ] && exit 0

CURRENT=$(git branch --show-current 2>/dev/null)
# A detached HEAD has no branch, so neither detector has anything to read.
[ -n "$CURRENT" ] || exit 0

# The active dev branch. See the header for why the filter and the version sort
# are both load-bearing. The next two lines stand verbatim in
# report-stale-branches.sh as well:
# check-hooks.sh holds the two equal, so a change here is a change there.
DEV=$(git for-each-ref --format='%(refname:short)' 'refs/remotes/origin/dev-*' 2>/dev/null \
      | grep -E '^origin/dev-[0-9]+$' | sort -V | tail -1)

TRACK=$(git for-each-ref --format='%(upstream:track)' "refs/heads/$CURRENT" 2>/dev/null)

STATE=CLEAR
BEHIND=0
if [ "$TRACK" = "[gone]" ]; then
  STATE=GONE
elif [ -n "$DEV" ] && [ "origin/$CURRENT" != "$DEV" ]; then
  COUNTS=$(git rev-list --left-right --count "$DEV...refs/heads/$CURRENT" 2>/dev/null)
  BEHIND=$(printf '%s' "$COUNTS" | cut -f1)
  AHEAD=$(printf '%s' "$COUNTS" | cut -f2)
  # An unreadable count is not a stale branch. Abstaining is the same answer
  # this file gives when there is no dev ref at all.
  if [ -n "$AHEAD" ] && [ "$AHEAD" -eq 0 ] && [ "$BEHIND" -gt 0 ]; then
    STATE=STALE
  fi
fi

# A branch carrying work of its own, a fresh branch at the dev tip, and every
# branch in a repository with no origin/dev-* ref at all leave here without an
# opinion. That is most sessions, and it costs four git reads.
[ "$STATE" = "CLEAR" ] && exit 0

GONE_REFUSE="Blocked: this worktree branch has been merged. Its branch on the remote is gone, which is what delete_branch_on_merge does when a pull request lands, so work added here now sits on a branch nothing will merge again. Make a new worktree from ${DEV:-the active dev branch} and move the work there."
STALE_REFUSE="Blocked: this worktree branch has no work of its own and ${DEV:-the active dev branch} is $BEHIND commit(s) ahead of it. A commit here would be the first thing on a branch the active dev branch has already moved past. Catch up first -- git merge ${DEV:-the active dev branch} is permitted from here -- or make a new worktree."

refuse() {
  if [ "$STATE" = "GONE" ]; then echo "$GONE_REFUSE $1" >&2; else echo "$STALE_REFUSE $1" >&2; fi
  exit 2
}

# The branch is stale or gone, so from here the file has an opinion and must be
# able to read the command to hold it. Without the tokeniser it cannot find a
# command word at all, and every commit on a merged branch would be permitted.
# A guard's own breakage refuses; it does not wave things through. Tested for
# before it is sourced and the functions after: a missing file makes `.` end the
# shell where an `if` around it never runs, so the guard would have been a
# comment.
LIB="$(dirname "$0")/lib/command-scan.sh"
[ -r "$LIB" ] && . "$LIB"
#
# All three functions are probed, not one. cs_git_args is the one whose absence
# would be silent and permitting: `RAW=$(cs_git_args "$VERB") || continue`
# cannot tell "not this verb" from "no such function", so a library holding
# cs_split but not cs_git_args would leave every verb permitted through the very
# check written to stop that.
if ! command -v cs_split >/dev/null 2>&1 \
   || ! command -v cs_normalise >/dev/null 2>&1 \
   || ! command -v cs_git_args >/dev/null 2>&1; then
  refuse "(This hook could not load lib/command-scan.sh, so it cannot read what this command does. Refusing rather than permitting.)"
fi

SCAN=$(printf '%s\n' "$COMMAND" | cs_normalise)
CMDS=$(printf '%s\n' "$SCAN" | cs_split)

VERBS="commit cherry-pick revert merge am rebase"

# A wrapper's payload sits in quotes, where no command position exists and the
# tokeniser finds nothing -- so this runs on the raw text and before the search
# for a command word, exactly as the three sibling hooks do. Ordering it the
# other way would let every wrapped commit through.
if echo "$COMMAND" | grep -qE '(^[[:space:]]*|[;&|(`][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*((ba|z|)sh[[:space:]]+(-c|<<)|eval([^-A-Za-z0-9_]|$))' \
   && echo "$COMMAND" | grep -qE 'git[[:space:]]+([^;&|]*[[:space:]])?(commit|cherry-pick|revert|merge|am|rebase)([^-A-Za-z0-9_]|$)'; then
  refuse "(That command is wrapped in a shell, so what it would write cannot be read through a quoted payload. Run it plainly.)"
fi

# Whether the carve-out may be taken at all. Everything here moves git somewhere
# else, or moves the branch under it, so the state read above would not be the
# state the command runs against -- and the carve-out is the one path out of a
# refused state. Refusing rather than assessing is what makes the read sound;
# it is the answer issue #43 gave in no-commit-to-main.sh, and this file is
# blocked on that one for exactly this reason. The environment spellings come
# from the un-split text, because cs_split removes assignments to find the
# command word behind them.
CARVE=1
if printf '%s\n' "$CMDS" | grep -qE '^(cd|pushd|popd)([^-A-Za-z0-9_]|$)'; then CARVE=; fi
if echo "$SCAN" | grep -qE '(GIT_DIR|GIT_WORK_TREE|GIT_COMMON_DIR)='; then CARVE=; fi
if printf '%s\n' "$CMDS" | grep -qE '^git[[:space:]]+([^[:space:]]+[[:space:]]+)*(-C|--git-dir|--work-tree)([[:space:]]|=)'; then CARVE=; fi
while IFS= read -r CMD; do
  if cs_git_args checkout <<<"$CMD" >/dev/null || cs_git_args switch <<<"$CMD" >/dev/null; then
    CARVE=
    break
  fi
done <<CMDLIST
$CMDS
CMDLIST

# The four spellings of the active dev branch, and the commit every one of them
# has to name. DEV is origin/dev-NN, a remote-tracking ref, and the ancestry
# above was read against it: ahead == 0 says this branch is a strict ancestor of
# refs/remotes/origin/dev-NN, and that -- and only that -- is what makes the
# fast-forward claim true. Two of the four spellings name a local branch
# instead, which a pruning fetch never moves; see the header for why they
# routinely disagree here, and for the case this now refuses.
#
# Resolved here rather than beside DEV because the common path exits above
# without ever needing it. Exactly what that costs, since this placement is the
# argument for it: one rev-parse here, paid once per command in an
# already-refused state -- `git status` in a stale worktree pays it too, not
# only a merge -- and one more per whitelisted token inside names_dev, paid only
# where the carve-out is actually considered.
DEV_SHORT=${DEV#origin/}
DEV_OID=$(git rev-parse --verify --quiet "refs/remotes/$DEV^{commit}" 2>/dev/null)
names_dev() {
  local TOK_OID
  case "$1" in
    "$DEV"|"$DEV_SHORT"|"refs/remotes/$DEV"|"refs/heads/$DEV_SHORT") ;;
    *) return 1 ;;
  esac
  # The whitelist stays the outer gate: this resolves four fixed strings, never
  # arbitrary command text.
  #
  # The emptiness test is REDUNDANT WITH THE COMPARISON BELOW and is kept as a
  # statement of intent, not as a guard that decides anything. Saying so
  # plainly, because the first version of this file justified it as load-bearing
  # and that was false: the rev-parse below returns on failure, and on success
  # prints an OID, so TOK_OID is never empty where the comparison runs, and an
  # unreadable DEV_OID already fails that comparison. Delete this line and no
  # outcome changes. An asserted claim about what a guard does is the defect
  # this whole file was rewritten to stop making.
  [ -n "$DEV_OID" ] || return 1
  TOK_OID=$(git rev-parse --verify --quiet "$1^{commit}" 2>/dev/null) || return 1
  # This is what refuses an unreadable dev tip: with DEV_OID empty, no resolved
  # token equals it, so the carve-out is not taken and the command is refused
  # with the rest.
  [ "$TOK_OID" = "$DEV_OID" ]
}

# A merge or rebase that is a fast-forward onto the active dev branch and
# nothing else. A whitelist: every token must be one of a short list of options
# that take no value and create no commit, or a name of that branch, and at
# least one name must be present. A bare `git merge` takes its argument from
# configuration and names nothing, so it is refused with the rest.
is_catch_up() {
  local ARGS="$1" TOK NAMED=
  for TOK in $ARGS; do
    case "$TOK" in
      --ff|--ff-only|-q|--quiet|-v|--verbose|--stat|--no-stat|--progress|--no-progress|--no-edit) continue ;;
      -*) return 1 ;;
    esac
    names_dev "$TOK" || return 1
    NAMED=1
  done
  [ -n "$NAMED" ]
}

# Every command, not the first: `git merge dev-05 && git commit -m x` is refused
# on its second half. Scoping to one occurrence is the fifth defect in
# lib/command-scan.sh's own list.
while IFS= read -r CMD; do
  for VERB in $VERBS; do
    RAW=$(cs_git_args "$VERB" <<<"$CMD") || continue
    ARGS=$(printf '%s' "$RAW" | tr -d '\042\047')

    # Mid-operation continuations. See the header: a refusal here strands state
    # the agent cannot exit.
    #
    # Matched as the first argument and nowhere else, and never for commit,
    # which has no continuation at all. Scanning the whole argument list for the
    # flag is what the first version did, and it read the text of a commit
    # message as an option: `git commit -m "permit rebase --continue"` -- the
    # shape of a message written while working on this very hook -- permitted a
    # commit on a merged branch. Silent, and in the permitting direction. The
    # quotes have already been stripped by then, so there is no quoting left to
    # look at; the answer is the position instead.
    #
    # A real continuation is the sole argument of the command, so this costs
    # `git rebase --quiet --continue`, which is refused. Visible, and one edit
    # away.
    if [ "$VERB" != "commit" ]; then
      case "${RAW%%[[:space:]]*}" in
        --continue|--abort|--skip|--quit) continue ;;
      esac
    fi

    if [ "$STATE" = "STALE" ] && { [ "$VERB" = "merge" ] || [ "$VERB" = "rebase" ]; }; then
      if [ -n "$CARVE" ] && is_catch_up "$ARGS"; then
        continue
      fi
      refuse "(A $VERB naming $DEV would be a fast-forward and is permitted; this one is not that.)"
    fi

    refuse "(Refused command: git $VERB.)"
  done
done <<CMDLIST
$CMDS
CMDLIST

exit 0

#!/bin/bash
# CLAUDE.md: "Sequential dev-NN branches; merge into main by PR only, never
# commit to main."
#
# Two ways to violate that from a shell: commit while standing on main, or push
# a refspec whose destination is main. Pushing a dev-NN branch from any branch
# is fine and is not matched here.
#
# no-git-push.sh refuses far more pushes than this file does, and would refuse
# every one this file refuses. This file is kept anyway, for the two reasons it
# was kept when its siblings were rebuilt on PR #35: the refusal names main and
# says why main in particular is closed, and it still stands if the broader hook
# is disabled. Neither reason licensed answering the command-position question
# here, which is what this file did until issue #43, and what its four defects
# were made of:
#
#   - the anchor was a bare preceding space, so `git commit` inside a quoted
#     string was a command position -- the same false positive the siblings were
#     rebuilt to stop
#   - heredoc bodies were scanned, so a dev-log entry or a ticket quoting
#     `git push origin main` read as that push. That is not hypothetical: it
#     blocked the writing of issue #36, which is about these hooks
#   - no shell wrapper and no directory change was refused, and yet the branch
#     was read with `git branch --show-current` in the hook's own working
#     directory rather than the command's
#   - main was matched by name, so a spelling naming no branch was invisible:
#     `git push --all origin` advances main from any branch and was permitted
#
# The third of those is why the migration was scheduled rather than left
# unscheduled. #40 refused to compute a merge base in a hook for exactly that
# reason -- the hook's directory is the session's and not necessarily the
# command's. Refusing what moves the command elsewhere is what makes reading the
# branch here sound at all, and it is what the two siblings already do.
#
# Behaviour is not preserved by that migration, because this file's behaviour
# included those defects. What is preserved is its purpose, and the classes of
# check in check-hooks.sh are the difference: sixteen invariants written in
# identical literals on both sides, eighteen verdicts that flipped, and four that
# name the refusal it has to give. What this file does when its library is not
# beside it was two checks here and is the load-contract section now; see the
# guard below.
#
# Not covered, and deliberately: `git merge`, `git rebase`, `git cherry-pick`
# and `git revert` put commits on main without a `git commit`, and none of them
# is matched here or was before. `git merge --no-ff dev-NN` on main is the
# nearest miss -- it is the thing the file is named after, and it is the
# server-side ruleset on main, not this hook, that refuses it.
#
# This stops mistakes, not adversaries. The stopping rule in no-git-push.sh
# governs here too: a shape an agent would plausibly write earns a fix, a
# payload it would have to construct does not.
#
# Sourced, not assumed. All four boundary hooks rest on lib/command-scan.sh now,
# and this one is kept in the tree because it still stands when the broader hook
# is disabled --
# which it would not if an unreadable library left cs_split undefined, the
# command list empty and every commit on main permitted. A guard's own breakage
# refuses; it does not wave things through.
#
# The file is tested for before it is sourced, and the functions after: a
# missing file makes `.` end the shell where an `if` around it never runs, so
# the guard would have been a comment.
#
# All three functions this file calls are probed, not cs_split alone. Issue #84
# found the narrow version, and the narrow version is worse than none: it reads
# as a guard and it permitted `git push origin HEAD:main` the moment cs_git_args
# was renamed, because `cs_git_args commit` and `cs_git_args push` fail the same
# way a command with neither in it does. The sibling hook had already learned
# this and written it down; the lesson was not carried here.
# See THE LOAD CONTRACT in lib/command-scan.sh.
LIB="$(dirname "$0")/lib/command-scan.sh"
[ -r "$LIB" ] && . "$LIB"
if ! command -v cs_normalise >/dev/null 2>&1 \
   || ! command -v cs_split >/dev/null 2>&1 \
   || ! command -v cs_git_args >/dev/null 2>&1; then
  echo "Blocked: no-commit-to-main.sh could not load lib/command-scan.sh, so it cannot tell whether this command touches main. Refusing rather than permitting." >&2
  exit 2
fi

# The refspec loop below splits with `for TOK in $ARGS`, unquoted because the
# split is the point; that would also glob the tokens against the worktree.
# Nothing here needs pathname expansion.
set -f

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
SCAN=$(printf '%s\n' "$COMMAND" | cs_normalise)
CMDS=$(printf '%s\n' "$SCAN" | cs_split)

COMMIT_REFUSE="Blocked: committing to main. CLAUDE.md requires sequential dev-NN branches, merged into main by PR only. Create or switch to a dev-NN branch first."
PUSH_REFUSE="Blocked: pushing to main. CLAUDE.md requires that main is only ever updated by pull request. Push your dev-NN branch and open a PR instead."
ELSEWHERE_REFUSE="Blocked: this command moves git somewhere else before committing or pushing, so whether it lands on main cannot be judged from here. CLAUDE.md closes main to everything but a pull request. Run it plainly, from the branch it belongs on."

# A commit or a push inside a wrapper is refused outright, as in both siblings.
# The payload sits in quotes where no command position exists, so neither a
# push's destination nor the directory a commit would run in can be read, and
# main cannot be ruled out. Matched on the raw command -- quotes and heredoc
# bodies included -- because that is where the payload still is, and asked
# before whether there is a commit or a push at all, because a wrapped one has
# no command word for the tokeniser to find.
#
# The trade, taken knowingly: an `sh -c` anywhere in a command that also commits
# plainly is refused for the company it keeps. That is the direction this file
# takes throughout -- a blocked command is visible and one edit away.
if echo "$COMMAND" | grep -qE '(^[[:space:]]*|[;&|(`][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*((ba|z|)sh[[:space:]]+(-c|<<)|eval([^-A-Za-z0-9_]|$))' \
   && echo "$COMMAND" | grep -qE 'git[[:space:]]+([^;&|]*[[:space:]])?(commit|push)([^-A-Za-z0-9_]|$)'; then
  echo "Blocked: git commit or push inside a shell wrapper. Whether it lands on main cannot be read through a quoted payload. Run it plainly." >&2
  exit 2
fi

# Is there a commit or a push here at all? Anything else costs one pass and
# leaves without an opinion -- including every `cd` this file has no business
# refusing.
HAVE=
while IFS= read -r CMD; do
  if cs_git_args commit <<<"$CMD" >/dev/null || cs_git_args push <<<"$CMD" >/dev/null; then
    HAVE=1
    break
  fi
done <<CMDLIST
$CMDS
CMDLIST
[ -n "$HAVE" ] || exit 0

# The branch below is read where this hook runs, which is the session's
# directory and not necessarily the command's. Everything that could make those
# two differ is refused first, which is what makes the read sound. The
# environment spellings come from the un-split text, because cs_split removes
# assignments to find the command word behind them.
if printf '%s\n' "$CMDS" | grep -qE '^(cd|pushd|popd)([^-A-Za-z0-9_]|$)'; then
  echo "$ELSEWHERE_REFUSE" >&2
  exit 2
fi
if echo "$SCAN" | grep -qE '(GIT_DIR|GIT_WORK_TREE|GIT_COMMON_DIR)='; then
  echo "$ELSEWHERE_REFUSE" >&2
  exit 2
fi

# Changing branch defeats the branch read exactly as changing directory does,
# and is much the likelier of the two: `git checkout main && git commit` is a
# shape an agent writes without meaning anything by it. Refusing the directory
# half while permitting this one left the soundness claim above half-made.
#
# The trade: `git checkout -b spike && git commit -m x` is refused although it
# lands nowhere near main. Two commands instead of one, and visible.
while IFS= read -r CMD; do
  if cs_git_args checkout <<<"$CMD" >/dev/null || cs_git_args switch <<<"$CMD" >/dev/null; then
    echo "$ELSEWHERE_REFUSE" >&2
    exit 2
  fi
done <<CMDLIST
$CMDS
CMDLIST

# git's own directory options, matched only where git accepts them -- in front
# of the subcommand. Matching them anywhere on the line, which is what the
# sibling does for a push, would read `git commit -m "drop the -C flag"` as a
# redirection; a commit message is the one argument on this path that carries
# arbitrary prose.
ELSEWHERE_OPT='^git[[:space:]]+(-[cC][[:space:]]+[^[:space:]]+[[:space:]]+|--(git-dir|work-tree|namespace|exec-path)=[^[:space:]]*[[:space:]]+|-[^[:space:]]+[[:space:]]+)*(-C|--git-dir|--work-tree)([[:space:]]|=)'

BRANCH=$(git branch --show-current 2>/dev/null)

# One push's arguments. Returns 1 with a reason on stderr if its destination is
# main, or cannot be shown not to be.
check_push() {
  local ARGS="$1" TOK SPEC DST SKIP REMOTE_SEEN REFSPEC_SEEN

  # These name no branch and advance every one, main included. Refusing main by
  # name could not see them, which is the same hole PR #35 closed in
  # no-git-push.sh; --tags is left alone, because it cannot move a branch.
  if printf ' %s ' "$ARGS" | grep -qE '[[:space:]](--all|--mirror)([[:space:]]|=|$)'; then
    echo "$PUSH_REFUSE That form pushes every branch, main among them." >&2
    return 1
  fi

  # A backslash the join did not consume means the arguments continue past
  # where this can read them. An unreadable argument list must not be allowed
  # to look like an empty one, which is the bare push judged on the branch.
  if printf '%s' "$ARGS" | grep -q '\\[[:space:]]*$'; then
    echo "$PUSH_REFUSE The arguments continue past where this check can read them." >&2
    return 1
  fi

  if printf '%s' "$ARGS" | grep -q '[*]'; then
    echo "$PUSH_REFUSE A wildcard refspec does not rule main out." >&2
    return 1
  fi

  SKIP=
  REMOTE_SEEN=
  REFSPEC_SEEN=
  for TOK in $ARGS; do
    if [ -n "$SKIP" ]; then SKIP=; continue; fi
    case "$TOK" in
      -o|--push-option|--repo|--receive-pack|--exec) SKIP=1; continue ;;
      -*) continue ;;
    esac
    # The first bare token is the remote. Which remote it is belongs to
    # no-git-push.sh; this file only asks what the refspecs name.
    if [ -z "$REMOTE_SEEN" ]; then REMOTE_SEEN=1; continue; fi
    REFSPEC_SEEN=1
    # A leading + forces; the destination is what it says either way. The
    # destination is the half after the colon, so `main:spike` names spike and
    # `HEAD:main`, `:main` and `refs/heads/main` all name main.
    SPEC=${TOK#+}
    case "$SPEC" in
      *:*) DST=${SPEC#*:} ;;
      *)   DST=$SPEC ;;
    esac
    # HEAD names whatever is checked out, so on main it names main. Comparing
    # the literal text let `git push -u origin HEAD` through from main -- and
    # worse, HEAD counts as a refspec, so it also switched off the bare-push
    # case below that would otherwise have caught the same push.
    case "$DST" in
      HEAD|@|refs/heads/HEAD) DST=$BRANCH ;;
    esac
    case "${DST#refs/heads/}" in
      main)
        echo "$PUSH_REFUSE" >&2
        return 1 ;;
    esac
  done

  # A push naming no refspec takes its destination from configuration, and on
  # main every default spelling of it pushes main. Off main this file says
  # nothing: a configured refspec could still name main, and answering that
  # would mean reading configuration a command can set for itself. That is
  # no-git-push.sh's answer to make -- it requires the branch to be named
  # outright -- and this file is not the place to re-derive it.
  if [ -z "$REFSPEC_SEEN" ] && [ "$BRANCH" = "main" ]; then
    echo "Blocked: bare 'git push' while on main pushes main. CLAUDE.md requires that main is only ever updated by pull request." >&2
    return 1
  fi

  return 0
}

# Every commit and every push, not the first of each: `git push origin spike &&
# git push origin main` is refused on its second half.
while IFS= read -r CMD; do
  if cs_git_args commit <<<"$CMD" >/dev/null; then
    if printf '%s' "$CMD" | grep -qE "$ELSEWHERE_OPT"; then
      echo "$ELSEWHERE_REFUSE" >&2
      exit 2
    fi
    if [ "$BRANCH" = "main" ]; then
      echo "$COMMIT_REFUSE" >&2
      exit 2
    fi
  fi
  if ARGS=$(cs_git_args push <<<"$CMD"); then
    if printf '%s' "$CMD" | grep -qE "$ELSEWHERE_OPT"; then
      echo "$ELSEWHERE_REFUSE" >&2
      exit 2
    fi
    # -c and --config-env set configuration for this one command, including the
    # push defaults the bare-push case rests on: `git -c push.default=matching
    # push` advances main from a dev branch. Reading the value back cannot close
    # that, because the command has already replaced it.
    if printf '%s' "$CMD" | grep -qE '^git[[:space:]]+(-[^[:space:]]+[[:space:]]+[^[:space:]-][^[:space:]]*[[:space:]]+|-[^[:space:]]+[[:space:]]+)*(-c|--config-env)([[:space:]]|=)'; then
      echo "$PUSH_REFUSE This command sets git configuration for itself, which decides where a push lands." >&2
      exit 2
    fi
    check_push "$(printf '%s' "$ARGS" | tr -d '\042\047')" || exit 2
  fi
done <<CMDLIST
$CMDS
CMDLIST

exit 0

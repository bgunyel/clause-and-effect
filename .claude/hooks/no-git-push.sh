#!/bin/bash
# Pushing is Bertan's, with one exception: an agent may push the branch of the
# linked worktree it is working in, which is what lets it open a pull request at
# all -- gh pr create needs the branch on the remote first. Everything else is
# refused, and Bertan's own pushes are made from a separate terminal where no
# hook runs.
#
# The exception is keyed on where the command runs, not on what the branch is
# called. Worktrees are made two ways here -- EnterWorktree, which prefixes the
# branch `worktree-`, and `git worktree add -b`, which does not -- so a name
# rule would be inconsistent between them, and a name can be chosen to match
# anyway. In a linked worktree `git rev-parse --git-dir` is .git/worktrees/<name>
# while --git-common-dir is .git; in the main checkout the two are equal.
#
# That check is the only signal that separates Bertan from an agent, because an
# agent pushes as bgunyel. A server-side ruleset cannot tell them apart: on
# dev-* it would block both or allow both, and naming him a bypass actor hands
# the agent the bypass. So for dev-NN this file is the enforcement, not a
# convenience in front of one. main is different -- there the policy is the same
# for both, and the branch ruleset is the right mechanism.
#
# Finding commands in the text is lib/command-scan.sh's job, not this file's.
# Every defect found in PR #35 was that question answered differently in a
# different place; it is answered once there now.
#
# no-commit-to-main.sh independently refuses pushes whose destination is main.
# It is left in place: it carries the narrower message, and it still stands if
# this file is disabled.
#
# This stops mistakes, not adversaries.
. "$(dirname "$0")/lib/command-scan.sh"

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
SCAN=$(printf '%s\n' "$COMMAND" | cs_normalise)
CMDS=$(printf '%s\n' "$SCAN" | cs_split)

REFUSE="Blocked: git push. An agent may push only the branch of the linked worktree it is working in, so that it can open a pull request."

# A push inside a wrapper is refused outright, with no worktree exception. The
# payload sits in quotes where no command position exists, so the destination
# cannot be read; permitting a push whose target is unknown is not the same as
# permitting this branch. Matched on the raw command, quotes and heredoc bodies
# included, because that is where the payload still is.
#
# This runs before asking whether there is a push, and must: a wrapped push has
# no command word for the tokeniser to find, so the question would answer no and
# the hook would leave. Ordering it the other way let all four wrapper forms
# through, which the probe suite caught.
if echo "$COMMAND" | grep -qE '(^[[:space:]]*|[;&|(`][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*((ba|z|)sh[[:space:]]+(-c|<<)|eval([^-A-Za-z0-9_]|$))' \
   && echo "$COMMAND" | grep -qE 'git[[:space:]]+([^;&|]*[[:space:]])?push([^-A-Za-z0-9_]|$)'; then
  echo "Blocked: git push inside a shell wrapper. The destination cannot be read through a quoted payload, so the worktree exception does not apply. Push plainly from the worktree, or leave it to Bertan." >&2
  exit 2
fi

# Is there a push here at all? A command with no push in it costs one pass and
# leaves without an opinion.
HAVE_PUSH=
while IFS= read -r CMD; do
  if cs_git_args push <<<"$CMD" >/dev/null; then HAVE_PUSH=1; break; fi
done <<CMDLIST
$CMDS
CMDLIST
[ -n "$HAVE_PUSH" ] || exit 0

# Where the hook runs is the session's directory, which is not necessarily where
# the command will run. Anything that moves the push elsewhere is refused rather
# than assessed. The environment spellings are read from the un-split text,
# because cs_split removes assignments to find the command word behind them.
if printf '%s\n' "$CMDS" | grep -qE '^(cd|pushd|popd)([^-A-Za-z0-9_]|$)'; then
  echo "$REFUSE This command changes directory first, so where the push would land cannot be judged from here." >&2
  exit 2
fi
if echo "$SCAN" | grep -qE '(GIT_DIR|GIT_WORK_TREE|GIT_COMMON_DIR)='; then
  echo "$REFUSE This command points git at another directory, so where the push would land cannot be judged from here." >&2
  exit 2
fi

GIT_DIR_PATH=$(git rev-parse --git-dir 2>/dev/null)
GIT_COMMON_PATH=$(git rev-parse --git-common-dir 2>/dev/null)
if [ -z "$GIT_DIR_PATH" ] || [ "$GIT_DIR_PATH" = "$GIT_COMMON_PATH" ]; then
  echo "$REFUSE This is the main checkout, not a linked worktree. Leave the commits on the branch and say what is ready to push." >&2
  exit 2
fi

CURRENT=$(git branch --show-current 2>/dev/null)
if [ -z "$CURRENT" ]; then
  echo "$REFUSE This worktree has no branch checked out." >&2
  exit 2
fi
if [ "$CURRENT" = "main" ] || echo "$CURRENT" | grep -qE '^dev-[0-9]+$'; then
  echo "$REFUSE This worktree is on $CURRENT, which is Bertan's to push." >&2
  exit 2
fi

names_this_branch() {
  case "$1" in
    HEAD|"$CURRENT"|"refs/heads/$CURRENT") return 0 ;;
    *) return 1 ;;
  esac
}

# One push's arguments. Returns 1 with a reason on stderr if it is not a plain,
# unforced push naming this branch.
check_push() {
  local CMD="$1" ARGS="$2" TOK SPEC SRC DST SKIP REMOTE_SEEN REFSPEC_SEEN

  if printf '%s' "$CMD" | grep -qE '(^|[[:space:]])(-C|--git-dir|--work-tree)([[:space:]]|=)'; then
    echo "$REFUSE This command points git at another directory, so where the push would land cannot be judged from here." >&2
    return 1
  fi

  # Joining consumes a backslash that ends a line, including one with nothing
  # after it, which is a bare push and stays permitted. A backslash surviving
  # here is one the join did not recognise, and what follows cannot be read. An
  # empty argument list is the permitted case, so an unreadable one is refused
  # rather than left to look empty.
  if printf '%s' "$ARGS" | grep -q '\\[[:space:]]*$'; then
    echo "$REFUSE The arguments continue past where this check can read them." >&2
    return 1
  fi

  # Whole-repository and tag forms name no branch at all, and refusing branches
  # by name -- the shape of this check before PR #35 -- could not see a spelling
  # that named none. `git push --all origin` advanced main and dev-05 from any
  # worktree, and --mirror deleted every remote branch absent locally.
  if printf ' %s ' "$ARGS" | grep -qE '[[:space:]](--all|--mirror|--tags|--follow-tags|--prune|--delete|-d)([[:space:]]|=|$)'; then
    echo "$REFUSE That form pushes or deletes refs wholesale rather than naming this branch." >&2
    return 1
  fi

  # Forcing rewrites what the remote already has, which for this branch is the
  # history the open pull request is showing. --force-with-lease is refused with
  # the rest: it guards against clobbering another person's work, not against
  # rewriting a branch under its reviewer. The short form may be bundled with
  # other single-letter options, as -fu.
  if printf ' %s ' "$ARGS" | grep -qE '[[:space:]](--force|--force-with-lease|--force-if-includes|-[A-Za-z]*f[A-Za-z]*)([[:space:]]|=|$)'; then
    echo "$REFUSE That is a forced push, which rewrites history the open pull request is showing. Add a commit instead." >&2
    return 1
  fi

  if printf '%s' "$ARGS" | grep -q '[*]'; then
    echo "$REFUSE A wildcard refspec does not name this branch." >&2
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
    # The first bare token is the remote. Nothing required it to be one, so a
    # URL or a typo was admitted whenever the refspec named this branch.
    if [ -z "$REMOTE_SEEN" ]; then
      REMOTE_SEEN=1
      if ! git remote | grep -qxF "$TOK"; then
        echo "$REFUSE $TOK is not a remote of this repository." >&2
        return 1
      fi
      continue
    fi
    REFSPEC_SEEN=1
    case "$TOK" in
      +*)
        echo "$REFUSE A leading + forces the push, which rewrites history the open pull request is showing." >&2
        return 1 ;;
    esac
    case "$TOK" in
      *:*) SRC=${TOK%%:*}; DST=${TOK#*:} ;;
      *)   SRC=$TOK; DST=$TOK ;;
    esac
    if ! names_this_branch "$SRC" || ! names_this_branch "$DST"; then
      echo "$REFUSE This names $TOK, not $CURRENT." >&2
      return 1
    fi
  done

  # With no refspec the destination comes from push.default. Every value but
  # matching pushes the current branch alone; matching pushes every branch whose
  # name exists on both sides, which would carry dev-NN along without naming it.
  if [ -z "$REFSPEC_SEEN" ] && [ "$(git config --get push.default 2>/dev/null)" = "matching" ]; then
    echo "$REFUSE push.default is matching, so a push naming no refspec would carry other branches with it." >&2
    return 1
  fi

  return 0
}

# Every push, not the first. Scoping to one occurrence meant
# `git push origin my-branch && git push --all origin` passed on the strength of
# its first half. Reported on PR #35.
while IFS= read -r CMD; do
  if ARGS=$(cs_git_args push <<<"$CMD"); then
    ARGS=$(printf '%s' "$ARGS" | tr -d '\042\047')
    check_push "$CMD" "$ARGS" || exit 2
  fi
done <<CMDLIST
$CMDS
CMDLIST

exit 0

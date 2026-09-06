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
# no-commit-to-main.sh independently refuses pushes whose destination is main.
# It is left in place: it carries the narrower message, and it still stands if
# this file is disabled.
#
# This stops mistakes, not adversaries.
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# A heredoc body is data, not commands. This repository writes dev-log entries
# and commit messages through a quoted heredoc, and those texts name the very
# commands refused here. grep anchors ^ per line, so a line of prose beginning
# with one of them read as a command position, and an earlier version of this
# hook refused the commit that introduced it. Bodies are dropped before
# matching.
SCAN=$(echo "$COMMAND" | awk '
  ind { if ($0 == d) ind = 0; next }
  {
    if (match($0, /<<-?[[:space:]]*[^[:space:];|&<>()]+/)) {
      d = substr($0, RSTART, RLENGTH)
      sub(/^<<-?[[:space:]]*/, "", d)
      gsub(/[\047"]/, "", d)
      ind = 1
    }
    print
  }')

# A backslash-newline is a line continuation, not a command separator. The
# argument scope further down runs from push to the next separator, a newline
# ended it, and an empty scope fell through to the bare-push case -- the
# permitted one. So `git push \` followed by `--mirror origin` read as an
# ordinary bare push and would have deleted every remote branch absent locally.
# Continuations are joined before anything is matched. Reported on PR #35.
SCAN=$(printf '%s\n' "$SCAN" | awk '
  {
    line = $0
    while (line ~ /\\$/) {
      sub(/\\$/, "", line)
      if ((getline nxt) > 0) line = line nxt; else break
    }
    print line
  }')

# Dropping bodies is itself a bypass: `sh -c "..."` and a heredoc fed to a shell
# both carry real commands inside text that was just discarded.
WRAPPED=
if echo "$COMMAND" | grep -qE '(^[[:space:]]*|[;&|(][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*((ba|z|)sh[[:space:]]+(-c|<<)|eval([^-A-Za-z0-9_]|$))'; then
  WRAPPED=1
fi

# A push inside a wrapper is refused outright, with no worktree exception. The
# payload sits in quotes where no command position exists, so the destination
# cannot be read; permitting a push whose target is unknown is not the same as
# permitting this branch.
if [ -n "$WRAPPED" ] \
   && echo "$COMMAND" | grep -qE 'git[[:space:]]+([^;&|]*[[:space:]])?push([^-A-Za-z0-9_]|$)'; then
  echo "Blocked: git push inside a shell wrapper. The destination cannot be read through a quoted payload, so the worktree exception does not apply. Push plainly from the worktree, or leave it to Bertan." >&2
  exit 2
fi

# A command sits at a command position: the start of a line -- leading
# whitespace included -- or after ; && || | or an opening paren.
#
# Leading whitespace is load-bearing. The anchor first written here required
# column zero, which fixed the heredoc false positive and silently gave up every
# indented push: a push inside an if or a for loop is written indented, and that
# is the accident this hook exists to stop. Reported on PR #35 and fixed there.
#
# The cost is one false positive, accepted knowingly: a quoted multi-line string
# that is not a heredoc, whose continuation line begins with the command. A
# blocked comment is visible and one edit away; a permitted push is neither.
#
# The -c/-C branch lets `git -C /path push` through the global-option run;
# without it the option's separate value ends the match before push is reached.
if ! echo "$SCAN" | grep -qE '(^[[:space:]]*|[;&|(][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*git[[:space:]]+((-[cC][[:space:]]+[^ ]+|-[^ ]+)[[:space:]]+)*push([^-A-Za-z0-9_]|$)'; then
  exit 0
fi

REFUSE="Blocked: git push. An agent may push only the branch of the linked worktree it is working in, so that it can open a pull request."

# Where the hook runs is the session's directory, which is not necessarily where
# the command will run. Anything that moves the push elsewhere is refused rather
# than assessed: cd and pushd, and git redirected by option or by environment.
# GIT_DIR= and GIT_WORK_TREE= are the environment spelling of --git-dir and
# --work-tree and were missed when only the option form was refused.
if echo "$SCAN" | grep -qE '(^[[:space:]]*|[;&|(][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*(cd|pushd|popd)([^-A-Za-z0-9_]|$)'; then
  echo "$REFUSE This command changes directory first, so where the push would land cannot be judged from here." >&2
  exit 2
fi
if echo "$SCAN" | grep -qE '(GIT_DIR|GIT_WORK_TREE|GIT_COMMON_DIR)=' \
   || echo "$SCAN" | grep -qE 'git[[:space:]]+([^;&|]*[[:space:]])?(-C|--git-dir|--work-tree)([[:space:]]|=)'; then
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

# Everything after the first push on the matched line, up to the next shell
# separator, is the push's own arguments. Every check below reads these rather
# than the whole command, so an unrelated flag elsewhere on the line -- the -f
# of `rm -f x && git push` -- is not mistaken for the push's own.
PUSH_LINE=$(echo "$SCAN" | grep -m1 -E '(^[[:space:]]*|[;&|(][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*git[[:space:]]+((-[cC][[:space:]]+[^ ]+|-[^ ]+)[[:space:]]+)*push([^-A-Za-z0-9_]|$)')
ARGS=${PUSH_LINE#*push}
# The scope ends at a shell separator, and a closing paren is one: without it
# the ) of `(git push)` was read as the push's remote.
ARGS=$(printf '%s' "$ARGS" | sed 's/[;&|)].*//' | tr -d '\042\047')

# Joining above consumes a backslash that ends a line, including one with no
# continuation line after it, which is simply a bare push. A backslash surviving
# here is one the join did not recognise -- trailed by whitespace, say -- and
# what follows it cannot be read. An empty scope is the permitted case, so an
# unreadable one is refused rather than allowed to look empty.
if printf '%s' "$ARGS" | grep -q '\\[[:space:]]*$'; then
  echo "$REFUSE The arguments continue past where this check can read them." >&2
  exit 2
fi

# Whole-repository and tag forms name no branch at all. Refusing branches by
# name was the shape of this check before, and a denylist cannot see a spelling
# that names nothing: `git push --all origin` advanced main and dev-05 from any
# worktree, and --mirror deleted every remote branch absent locally, closing
# open pull requests. Reported on PR #35.
if printf ' %s ' "$ARGS" | grep -qE '[[:space:]](--all|--mirror|--tags|--follow-tags|--prune|--delete|-d)([[:space:]]|=|$)'; then
  echo "$REFUSE That form pushes or deletes refs wholesale rather than naming this branch." >&2
  exit 2
fi

# A forced push rewrites what the remote already has, which for this branch is
# the history an open pull request is showing. --force-with-lease is refused
# with the rest: it makes the rewrite safe against clobbering someone else's
# work, not against rewriting a PR under its reviewer. The short form may be
# bundled with other single-letter options, as -fu, so any single-dash token
# containing f counts.
if printf ' %s ' "$ARGS" | grep -qE '[[:space:]](--force|--force-with-lease|--force-if-includes|-[A-Za-z]*f[A-Za-z]*)([[:space:]]|=|$)'; then
  echo "$REFUSE That is a forced push, which rewrites history the open pull request is showing. Add a commit instead." >&2
  exit 2
fi

if printf '%s' "$ARGS" | grep -q '[*]'; then
  echo "$REFUSE A wildcard refspec does not name this branch." >&2
  exit 2
fi

# What remains must positively name this branch: the first bare token is the
# remote and every later one is a refspec, whose source and destination must
# both be this branch or HEAD.

names_this_branch() {
  case "$1" in
    HEAD|"$CURRENT"|"refs/heads/$CURRENT") return 0 ;;
    *) return 1 ;;
  esac
}

SKIP=
REMOTE_SEEN=
REFSPEC_SEEN=
for TOK in $ARGS; do
  if [ -n "$SKIP" ]; then SKIP=; continue; fi
  case "$TOK" in
    -o|--push-option|--repo|--receive-pack|--exec) SKIP=1; continue ;;
    -*) continue ;;
  esac
  # The first bare token is the remote. Nothing required it to be one, so a URL
  # or a typo'd name was admitted whenever the refspec happened to name this
  # branch. It reaches none of Bertan's branches, but an invented remote is the
  # shape of mistake this file is for. Raised on PR #35.
  if [ -z "$REMOTE_SEEN" ]; then
    REMOTE_SEEN=1
    if ! git remote | grep -qxF "$TOK"; then
      echo "$REFUSE $TOK is not a remote of this repository." >&2
      exit 2
    fi
    continue
  fi
  REFSPEC_SEEN=1
  # A leading + on a refspec is the other spelling of --force.
  case "$TOK" in
    +*)
      echo "$REFUSE A leading + forces the push, which rewrites history the open pull request is showing." >&2
      exit 2 ;;
  esac
  SPEC=$TOK
  case "$SPEC" in
    *:*) SRC=${SPEC%%:*}; DST=${SPEC#*:} ;;
    *)   SRC=$SPEC; DST=$SPEC ;;
  esac
  if ! names_this_branch "$SRC" || ! names_this_branch "$DST"; then
    echo "$REFUSE This names $SPEC, not $CURRENT." >&2
    exit 2
  fi
done

# With no refspec the destination comes from push.default. Every value but
# matching pushes the current branch alone; matching pushes every branch whose
# name exists on both sides, which would carry dev-NN along without naming it.
if [ -z "$REFSPEC_SEEN" ] && [ "$(git config --get push.default 2>/dev/null)" = "matching" ]; then
  echo "$REFUSE push.default is matching, so a push naming no refspec would carry other branches with it." >&2
  exit 2
fi

exit 0

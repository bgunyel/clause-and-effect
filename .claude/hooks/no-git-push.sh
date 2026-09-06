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

# Dropping bodies is itself a bypass: `sh -c "..."` and a heredoc fed to a shell
# both carry real commands inside text that was just discarded.
WRAPPED=
if echo "$COMMAND" | grep -qE '(^[[:space:]]*|[;&|(][[:space:]]*)((ba|z|)sh[[:space:]]+(-c|<<)|eval([^-A-Za-z0-9_]|$))'; then
  WRAPPED=1
fi

# A push inside a wrapper is refused outright, with no worktree exception. The
# payload sits in quotes where no command position exists, so the destination
# cannot be read; permitting it would mean permitting a push whose target is
# unknown. Re-admission is enough to find it, not to judge it.
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
# is the accident this hook exists to stop. no-commit-to-main.sh, with the
# looser anchor, still caught it. Reported on PR #35 and fixed there.
#
# The cost is one false positive, accepted knowingly: a quoted multi-line string
# that is not a heredoc, whose continuation line begins with the command, as in
# `gh issue comment -b "...\n  git push ..."`. A blocked comment is visible and
# one edit away; a silently permitted push is neither.
#
# The -c/-C branch lets `git -C /path push` through the global-option run;
# without it the option's separate value ends the match before push is reached.
if ! echo "$SCAN" | grep -qE '(^[[:space:]]*|[;&|(][[:space:]]*)git[[:space:]]+((-[cC][[:space:]]+[^ ]+|-[^ ]+)[[:space:]]+)*push([^-A-Za-z0-9_]|$)'; then
  exit 0
fi

REFUSE="Blocked: git push. An agent may push only the branch of the linked worktree it is working in, so that it can open a pull request."

# Where the hook runs is the session's directory, which is not necessarily where
# the command will run. A cd, or a git redirected with -C / --git-dir /
# --work-tree, moves the push somewhere this check did not look at, so both are
# refused rather than assessed. no-commit-to-main.sh has the same blind spot and
# does not close it; here the exception makes it worth closing.
if echo "$SCAN" | grep -qE '(^[[:space:]]*|[;&|(][[:space:]]*)cd([^-A-Za-z0-9_]|$)'; then
  echo "$REFUSE This command changes directory first, so where the push would land cannot be judged from here." >&2
  exit 2
fi
if echo "$SCAN" | grep -qE 'git[[:space:]]+([^;&|]*[[:space:]])?(-C|--git-dir|--work-tree)([[:space:]]|=)'; then
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

# A worktree may still push somebody else's branch. Every local branch except
# the current one is refused wherever it appears as a whole token, which covers
# `git push origin main`, `git push origin dev-05` and `git push origin
# HEAD:main` without parsing a refspec.
#
# Splitting is on everything a branch name cannot contain, rather than on a list
# of separators: a quote left attached to the token, as in a push named inside
# `-b "...main"`, made an exact match miss. The keep set holds / because branch
# names use it, so a fully qualified refs/heads/<name> is checked separately.
for BRANCH in $(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null); do
  [ "$BRANCH" = "$CURRENT" ] && continue
  TOKENS=$(echo "$SCAN" | tr -c 'A-Za-z0-9_./-' '\n')
  if echo "$TOKENS" | grep -qxF "$BRANCH" || echo "$TOKENS" | grep -qxF "refs/heads/$BRANCH"; then
    echo "$REFUSE This names $BRANCH, which is not this worktree's branch." >&2
    exit 2
  fi
done

exit 0

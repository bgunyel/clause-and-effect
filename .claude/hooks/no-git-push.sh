#!/bin/bash
# Pushes to the remote are made by Bertan from a separate terminal, outside
# Claude Code. Nothing an agent does in this repository needs to reach the
# remote, so every push is refused here rather than judged case by case.
#
# no-commit-to-main.sh already refuses pushes whose destination is main. That
# rule is deliberately left in place rather than folded into this one: it
# carries the narrower message, and it still stands if this file is disabled.
#
# This stops mistakes, not adversaries. A caller who wants to push can spell it
# in ways this regex does not match; the point is that none of them happen by
# accident.
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
# both carry real commands inside text that was just discarded. For those shapes
# the raw command is appended back, so what the drop hides is still matched.
# no-pr-decisions.sh carries the same block; the two must stay in step.
WRAPPED=
if echo "$COMMAND" | grep -qE '(^[[:space:]]*|[;&|(][[:space:]]*)((ba|z|)sh[[:space:]]+(-c|<<)|eval([^-A-Za-z0-9_]|$))'; then
  WRAPPED=1
  SCAN="$SCAN
$COMMAND"
fi

# Re-admitting the text is enough for a heredoc, whose payload sits at the start
# of a line, and not for `sh -c "..."`, whose payload sits inside quotes where no
# command position exists. Inside a wrapper the anchor is therefore dropped
# entirely. Narrow on purpose: the unanchored pattern runs only once a wrapper
# has already been found, never over an ordinary command.
if [ -n "$WRAPPED" ] \
   && echo "$COMMAND" | grep -qE 'git[[:space:]]+([^;&|]*[[:space:]])?push([^-A-Za-z0-9_]|$)'; then
  echo "Blocked: git push inside a shell wrapper. Pushes to the remote are Bertan's, made from a separate terminal." >&2
  exit 2
fi

# A command sits at a command position: the start of a line -- leading
# whitespace included -- or after ; && || | or an opening paren.
#
# Leading whitespace is load-bearing. The anchor first written here required
# column zero, which fixed the heredoc false positive and silently gave up every
# indented push: a push inside an if or a for loop is written indented, and that
# is the accident this hook exists to stop. no-commit-to-main.sh, with the
# looser anchor, still caught it. Reported on PR #35 and fixed here.
#
# The cost is one false positive, accepted knowingly: a quoted multi-line string
# that is not a heredoc, whose continuation line begins with the command, as in
# `gh issue comment -b "...\n  git push ..."`. A blocked comment is visible and
# one edit away; a silently permitted push is neither.
#
# The -c/-C branch lets `git -C /path push` through the global-option run;
# without it the option's separate value ends the match before push is reached.
if echo "$SCAN" | grep -qE '(^[[:space:]]*|[;&|(][[:space:]]*)git[[:space:]]+((-[cC][[:space:]]+[^ ]+|-[^ ]+)[[:space:]]+)*push([^-A-Za-z0-9_]|$)'; then
  echo "Blocked: git push. Pushes to the remote are Bertan's, made from a separate terminal. Leave the commits on the branch and say what is ready to push." >&2
  exit 2
fi

exit 0

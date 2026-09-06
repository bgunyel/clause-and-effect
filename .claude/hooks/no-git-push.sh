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
# commands refused here. grep anchors ^ per line, so a wrapped line of prose
# beginning with one of them read as a command position and the rule forbade
# writing about itself -- observed when an earlier version of this hook blocked
# the commit that introduced it. Bodies are dropped before matching; a heredoc
# fed to a shell is caught by the wrapper rule below, on the raw command.
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

# A real command sits at a command position: start of line, or after ; && || |
# or an opening paren. Matching after a bare space instead would block a commit
# message that merely mentions the command. The -c/-C branch is what lets
# `git -C /path push` through the global-option run; without it the option's
# separate value ends the match before push is reached.
if echo "$SCAN" | grep -qE '(^|[;&|(]\s*)git\s+((-[cC]\s+[^ ]+|-[^ ]+)\s+)*push([^-A-Za-z0-9_]|$)'; then
  echo "Blocked: git push. Pushes to the remote are Bertan's, made from a separate terminal. Leave the commits on the branch and say what is ready to push." >&2
  exit 2
fi

# The anchor above ignores quoted text and heredoc bodies, which would otherwise
# hide a real push inside a shell wrapper. Wrappers are matched on the whole raw
# command, quotes and bodies included.
if echo "$COMMAND" | grep -qE '(^|[;&|(]\s*)(ba|z|)sh\s+(-c|<<)|(^|[;&|(]\s*)eval([^-A-Za-z0-9_]|$)'; then
  if echo "$COMMAND" | grep -qE 'git\s+([^;&|]*\s)?push([^-A-Za-z0-9_]|$)'; then
    echo "Blocked: git push inside a shell wrapper. Pushes to the remote are Bertan's, made from a separate terminal." >&2
    exit 2
  fi
fi

exit 0

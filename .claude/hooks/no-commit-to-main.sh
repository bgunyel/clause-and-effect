#!/bin/bash
# CLAUDE.md: "Sequential dev-NN branches; merge into main by PR only, never
# commit to main."
#
# Two ways to violate that from a shell: commit while standing on main, or
# push a refspec whose destination is main. Pushing a dev-NN branch from any
# branch is fine and is not matched here.
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

BRANCH=$(git branch --show-current 2>/dev/null)

if echo "$COMMAND" | grep -qE '(^|[;&|]|\s)git\s+(-[^ ]+\s+)*commit(\s|$)'; then
  if [ "$BRANCH" = "main" ]; then
    echo "Blocked: committing to main. CLAUDE.md requires sequential dev-NN branches, merged into main by PR only. Create or switch to a dev-NN branch first." >&2
    exit 2
  fi
fi

# Destination-side match: `git push origin main`, `git push origin HEAD:main`,
# `git push -f origin main`. The refspec's destination is what matters, so a
# trailing :main counts and a leading main: (source side) does not.
if echo "$COMMAND" | grep -qE '(^|[;&|]|\s)git\s+(-[^ ]+\s+)*push(\s|$)'; then
  if echo "$COMMAND" | grep -qE '(\s|:)main(\s|$)'; then
    echo "Blocked: pushing to main. CLAUDE.md requires that main is only ever updated by pull request. Push your dev-NN branch and open a PR instead." >&2
    exit 2
  fi
  if [ "$BRANCH" = "main" ] && echo "$COMMAND" | grep -qE 'git\s+(-[^ ]+\s+)*push\s*($|[;&|])'; then
    echo "Blocked: bare 'git push' while on main pushes main. CLAUDE.md requires that main is only ever updated by pull request." >&2
    exit 2
  fi
fi

exit 0

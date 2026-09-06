#!/bin/bash
# Agents may open pull requests and talk on them; they may not decide them.
# Accepting, rejecting, merging or reopening a PR is Bertan's call, and so is
# publishing a release.
#
# CLAUDE.md: "merge into main by PR only, never commit to main." Opening the
# pull request is the agent's half of that sentence; closing it is not.
#
# Still allowed: creating a PR, commenting on one, editing one, viewing,
# listing, diffing and checking one, reviewing with --comment, and every
# gh issue subcommand.
#
# The convenient spelling is only one way in. The same merge is one REST call
# (PUT /repos/O/R/pulls/N/merge) or one graphql mutation away, and gh api is
# allowlisted in settings.local.json, so those two shapes are matched too. URLs
# have many spellings and this is not airtight -- it closes the ordinary paths.
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# A heredoc body is data, not commands: a commit message or dev-log entry that
# names these commands must not be refused by them.
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

# Dropping bodies is itself a bypass, and this file lacked the guard its sibling
# had -- reported on PR #35, where `bash -c 'gh pr merge 35'` and a graphql
# mutation sent through a heredoc both passed. Two shapes re-admit the raw
# command: a shell wrapper, and gh api reading a heredoc, which is the ordinary
# way a mutation is sent and so is a decision hiding in dropped text.
DECIDE="Blocked: deciding a pull request is Bertan's call, not an agent's. Opening a PR, commenting on it and editing it are allowed; accepting, rejecting, merging and reopening are not."

WRAPPED=
if echo "$COMMAND" | grep -qE '(^[[:space:]]*|[;&|(][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*((ba|z|)sh[[:space:]]+(-c|<<)|eval([^-A-Za-z0-9_]|$))'; then
  WRAPPED=1
  SCAN="$SCAN
$COMMAND"
elif echo "$COMMAND" | grep -qE '(^[[:space:]]*|[;&|(][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*gh[[:space:]]+api' \
     && echo "$COMMAND" | grep -q '<<'; then
  SCAN="$SCAN
$COMMAND"
fi

# Re-admitting the text is enough for a heredoc, whose payload sits at the start
# of a line, and not for `sh -c "..."`, whose payload sits inside quotes where no
# command position exists. Inside a wrapper the anchor is dropped entirely, for
# every decision this file refuses. Narrow on purpose: the unanchored patterns
# run only once a wrapper has already been found.
if [ -n "$WRAPPED" ]; then
  if echo "$COMMAND" | grep -qE 'gh[[:space:]]+pr[[:space:]]+(merge|close|reopen)([^-A-Za-z0-9_]|$)' \
     || echo "$COMMAND" | grep -qE 'gh[[:space:]]+release[[:space:]]+(create|delete|delete-asset)([^-A-Za-z0-9_]|$)' \
     || echo "$COMMAND" | grep -qE '/pulls/[^ ]*/(merge|reviews)' \
     || echo "$COMMAND" | grep -qE 'mergePullRequest|addPullRequestReview'; then
    echo "$DECIDE A shell wrapper does not change what the command decides." >&2
    exit 2
  fi
  if echo "$COMMAND" | grep -qE 'gh[[:space:]]+pr[[:space:]]+review([^-A-Za-z0-9_]|$)' \
     && echo "$COMMAND" | grep -qE '[[:space:]](--approve|--request-changes|-a|-r)([[:space:]]|=|"|$)'; then
    echo "$DECIDE A shell wrapper does not change what the command decides." >&2
    exit 2
  fi
fi

# A command sits at a command position: the start of a line -- leading
# whitespace included, because `gh pr merge` inside an if or a for loop is
# written indented -- or after ; && || | or an opening paren. Requiring column
# zero, as this file first did, missed every indented decision. The cost is a
# quoted multi-line string whose continuation line begins with one of these
# commands; that false positive is accepted, being visible and one edit away.
if echo "$SCAN" | grep -qE '(^[[:space:]]*|[;&|(][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*gh[[:space:]]+pr[[:space:]]+merge([^-A-Za-z0-9_]|$)'; then
  echo "$DECIDE Leave the PR open and say it is ready to merge." >&2
  exit 2
fi

# Only the verdict flags. Reviewing with --comment leaves remarks without a
# verdict and stays allowed, so the subcommand alone is not enough to block on.
if echo "$SCAN" | grep -qE '(^[[:space:]]*|[;&|(][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*gh[[:space:]]+pr[[:space:]]+review([^-A-Za-z0-9_]|$)' \
   && echo "$SCAN" | grep -qE '[[:space:]](--approve|--request-changes|-a|-r)([[:space:]]|=|$)'; then
  echo "$DECIDE Review with --comment to leave remarks without a verdict." >&2
  exit 2
fi

# Rejecting a pull request by outcome rather than by verdict.
if echo "$SCAN" | grep -qE '(^[[:space:]]*|[;&|(][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*gh[[:space:]]+pr[[:space:]]+(close|reopen)([^-A-Za-z0-9_]|$)'; then
  echo "$DECIDE Closing a PR rejects it; say why it should be closed instead." >&2
  exit 2
fi

# Outward-facing publication. This repository is public.
if echo "$SCAN" | grep -qE '(^[[:space:]]*|[;&|(][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*gh[[:space:]]+release[[:space:]]+(create|delete|delete-asset)([^-A-Za-z0-9_]|$)'; then
  echo "Blocked: publishing or deleting a GitHub release is Bertan's call. This repository is public; a release is visible the moment it exists." >&2
  exit 2
fi

# The REST endpoints behind the two blocked pull-request commands.
if echo "$SCAN" | grep -qE '(^[[:space:]]*|[;&|(][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*gh[[:space:]]+api([^-A-Za-z0-9_]|$)' \
   && echo "$SCAN" | grep -qE '/pulls/[^ ]*/(merge|reviews)'; then
  echo "$DECIDE Reaching the merge or review endpoint through gh api is the same decision by another name." >&2
  exit 2
fi

# The same two decisions expressed as graphql mutations.
if echo "$SCAN" | grep -qE '(^[[:space:]]*|[;&|(][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*gh[[:space:]]+api([^-A-Za-z0-9_]|$)' \
   && echo "$SCAN" | grep -qE 'mergePullRequest|addPullRequestReview'; then
  echo "$DECIDE Reaching the merge or review mutation through graphql is the same decision by another name." >&2
  exit 2
fi

exit 0

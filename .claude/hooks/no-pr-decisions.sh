#!/bin/bash
# Agents may open pull requests and talk on them; they may not decide them.
# Accepting, rejecting, merging or reopening a PR is Bertan's call, and so is
# publishing a release.
#
# CLAUDE.md: "merge into main by PR only, never commit to main." Opening the
# pull request is the agent's half of that sentence; closing it is not.
#
# Still allowed: creating a PR, commenting on one, editing one, viewing,
# listing, diffing and checking one, reviewing with --comment, every gh issue
# subcommand, and reading a PR through gh api -- including the two endpoints
# that decide one when they are written to. GET /pulls/N/reviews lists reviews
# and GET /pulls/N/merge reports whether the PR is merged; refusing those by
# endpoint refused a listing, not a decision, which the review on PR #35 caught.
# The method is what separates them, so the method is what is tested.
#
# The convenient spelling is only one way in. The same merge is one REST call
# (PUT /repos/O/R/pulls/N/merge) or one graphql mutation away, and gh api is
# allowlisted in settings.local.json, so those two shapes are matched too. URLs
# have many spellings and this is not airtight -- it closes the ordinary paths.
#
# The wrapper rule below is the exception to the method test, and stays blunt on
# purpose: inside `bash -c '...'` the payload is quoted text, so neither the
# method nor anything else can be read out of it. A read of a PR wrapped in a
# shell is refused with the writes. Run it unwrapped.
#
# Finding commands in the text is lib/command-scan.sh's job. Each line it
# returns is one command with everything before the command word removed, so
# every rule below anchors at ^ and none of them describes a command position.
# That is where all of PR #35's defects lived, this file's included: it was the
# sibling that had the wrapper rule, and this one that did not.
. "$(dirname "$0")/lib/command-scan.sh"

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
SCAN=$(printf '%s\n' "$COMMAND" | cs_normalise)

# gh api reading a heredoc is a decision hiding in text that was just dropped --
# a heredoc is the ordinary way to send a graphql mutation. The raw command is
# re-admitted for that shape alone.
if printf '%s\n' "$SCAN" | cs_split | grep -qE '^gh[[:space:]]+api([^-A-Za-z0-9_]|$)' \
   && echo "$COMMAND" | grep -q '<<'; then
  SCAN="$SCAN
$COMMAND"
fi
CMDS=$(printf '%s\n' "$SCAN" | cs_split)

DECIDE="Blocked: deciding a pull request is Bertan's call, not an agent's. Opening a PR, commenting on it and editing it are allowed; accepting, rejecting, merging and reopening are not."

# `gh pr merge` is not the only way to write `gh pr merge`. Cobra resolves the
# subcommand at the first non-flag argument, so a flag may sit in front of it:
# `gh pr --repo o/r merge 35` merges, and every rule here wanted the subcommand
# as the third word. -R/--repo takes its value as a separate token and has to
# consume it, or the value would be read as the subcommand. Written once and
# interpolated, so the group and the verb are still all a rule has to name.
GHPR='^gh[[:space:]]+pr([[:space:]]+((-R|--repo|--hostname)[[:space:]]+[^[:space:]]+|-[^[:space:]]+))*[[:space:]]+'
GHRELEASE='^gh[[:space:]]+release([[:space:]]+((-R|--repo|--hostname)[[:space:]]+[^[:space:]]+|-[^[:space:]]+))*[[:space:]]+'

# The verdict flags, bundled or not. gh takes shorthand flags together, so
# `gh pr review -ab "lgtm" 35` is --approve --body and was allowed while
# `-a` alone was refused. no-git-push.sh had already answered this for -fu and
# this file had not -- the same asymmetry twice. Only single-dash bundles are
# scanned for a or r: a long flag would match on any letter it happens to
# contain, and --repo would read as --request-changes.
VERDICT='[[:space:]](--approve|--request-changes|-[A-Za-z]*[ar][A-Za-z]*)([[:space:]]|=|"|$)'

# A wrapper's payload sits inside quotes, where there is no command word for the
# tokeniser to find, so these run unanchored over the raw text -- and only once
# a wrapper has been found, never over an ordinary command.
if echo "$COMMAND" | grep -qE '(^[[:space:]]*|[;&|(`][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*((ba|z|)sh[[:space:]]+(-c|<<)|eval([^-A-Za-z0-9_]|$))'; then
  if echo "$COMMAND" | grep -qE 'gh[[:space:]]+pr[[:space:]]+.*(merge|close|reopen)([^-A-Za-z0-9_]|$)' \
     || echo "$COMMAND" | grep -qE 'gh[[:space:]]+release[[:space:]]+.*(create|delete|delete-asset)([^-A-Za-z0-9_]|$)' \
     || echo "$COMMAND" | grep -qE '/pulls/[^ ]*/(merge|reviews)' \
     || echo "$COMMAND" | grep -qE '/releases([^A-Za-z0-9_-]|$)' \
     || echo "$COMMAND" | grep -qiE 'state[[:space:]]*[=:][[:space:]]*"?(closed|open)"?' \
     || echo "$COMMAND" | grep -qE 'mergePullRequest|addPullRequestReview|closePullRequest|reopenPullRequest|createRelease|updateRelease|deleteRelease'; then
    echo "$DECIDE A shell wrapper does not change what the command decides." >&2
    exit 2
  fi
  if echo "$COMMAND" | grep -qE 'gh[[:space:]]+pr[[:space:]]+review([^-A-Za-z0-9_]|$)' \
     && echo "$COMMAND" | grep -qE "$VERDICT"; then
    echo "$DECIDE A shell wrapper does not change what the command decides." >&2
    exit 2
  fi
fi

if printf '%s\n' "$CMDS" | grep -qE "${GHPR}merge([^-A-Za-z0-9_]|\$)"; then
  echo "$DECIDE Leave the PR open and say it is ready to merge." >&2
  exit 2
fi

# Only the verdict flags, and only in the same command as the subcommand.
# Reviewing with --comment leaves remarks without a verdict and stays allowed.
if printf '%s\n' "$CMDS" | grep -qE "${GHPR}review([[:space:]].*)?${VERDICT}"; then
  echo "$DECIDE Review with --comment to leave remarks without a verdict." >&2
  exit 2
fi

# Rejecting a pull request by outcome rather than by verdict.
if printf '%s\n' "$CMDS" | grep -qE "${GHPR}(close|reopen)([^-A-Za-z0-9_]|\$)"; then
  echo "$DECIDE Closing a PR rejects it; say why it should be closed instead." >&2
  exit 2
fi

# Outward-facing publication. This repository is public.
if printf '%s\n' "$CMDS" | grep -qE "${GHRELEASE}(create|delete|delete-asset)([^-A-Za-z0-9_]|\$)"; then
  echo "Blocked: publishing or deleting a GitHub release is Bertan's call. This repository is public; a release is visible the moment it exists." >&2
  exit 2
fi

# Is this gh api call a write? Succeeds if it is, or if that cannot be told.
#
# gh sends GET unless told otherwise, and switches to POST the moment a field or
# input flag appears, so a call carrying neither is a read. The test is the
# method and not the endpoint because the endpoint does not distinguish them:
# GET /pulls/N/reviews lists reviews and GET /pulls/N/merge reports whether the
# PR is merged. Both are reading a pull request, which CLAUDE.md allows in the
# same sentence that forbids deciding one.
#
# Any token beginning -f or -F counts, not just `-f x=y`: gh accepts the value
# attached, and `-fevent=APPROVE` is the same request as `-f event=APPROVE`.
# A method that cannot be parsed is treated as a write.
gh_api_is_write() {
  local CMD="$1" METHOD
  METHOD=$(printf '%s' "$CMD" | sed -nE 's/.*(^|[[:space:]])(-X|--method)[[:space:]=]*([A-Za-z]+).*/\3/p')
  if [ -n "$METHOD" ]; then
    case "$METHOD" in
      GET|get|Get|HEAD|head|Head) ;;
      *) return 0 ;;
    esac
  elif printf '%s' "$CMD" | grep -qE '(^|[[:space:]])(-X|--method)([[:space:]]|=|$)'; then
    return 0
  fi
  if printf '%s' "$CMD" | grep -qE '(^|[[:space:]])(-[fF]|--field|--raw-field|--input)'; then
    return 0
  fi
  return 1
}

# The REST endpoints and the graphql mutations behind those commands. The
# command word and the payload can be separated by the tokeniser -- a mutation
# body splits on its own braces and parens -- so gh api is looked for among the
# commands and what it carries anywhere in the text.
API_WRITE=
while IFS= read -r CMD; do
  printf '%s\n' "$CMD" | grep -qE '^gh[[:space:]]+api([^-A-Za-z0-9_]|$)' || continue
  if gh_api_is_write "$CMD"; then API_WRITE=1; break; fi
done <<CMDLIST
$CMDS
CMDLIST

if [ -n "$API_WRITE" ]; then
  if echo "$SCAN" | grep -qE '/pulls/[^ ]*/(merge|reviews)'; then
    echo "$DECIDE Reaching the merge or review endpoint through gh api is the same decision by another name." >&2
    exit 2
  fi
  # Closing and reopening were refused in the gh pr spelling and open through
  # gh api, so the boundary was spelling-dependent where it claimed not to be.
  # They are a write to the pull request itself rather than to a subpath, and
  # the same PATCH is how `gh pr edit` retitles one, which stays allowed -- so
  # the endpoint cannot decide this and the field has to. graphql spells the
  # same change as a state on updatePullRequest.
  if echo "$SCAN" | grep -qiE '(/pulls/|updatePullRequest)' \
     && echo "$SCAN" | grep -qiE 'state[[:space:]]*[=:][[:space:]]*"?(closed|open)"?'; then
    echo "$DECIDE Setting a pull request's state through gh api closes or reopens it, which is the same decision by another name." >&2
    exit 2
  fi
  if echo "$SCAN" | grep -qE '/releases([^A-Za-z0-9_-]|$)'; then
    echo "Blocked: publishing or deleting a GitHub release is Bertan's call, reached through gh api no less than through gh release. This repository is public; a release is visible the moment it exists." >&2
    exit 2
  fi
  if echo "$SCAN" | grep -qE 'mergePullRequest|addPullRequestReview|closePullRequest|reopenPullRequest|createRelease|updateRelease|deleteRelease'; then
    echo "$DECIDE Reaching the same decision through a graphql mutation is the same decision by another name." >&2
    exit 2
  fi
fi

exit 0

#!/bin/bash
# Agents may open pull requests and talk on them; they may not decide them, and
# may propose one only into the active dev branch. Accepting, rejecting, merging
# or reopening a PR is Bertan's call, and so is publishing a release.
#
# CLAUDE.md: "merge into main by PR only, never commit to main." Opening the
# pull request is the agent's half of that sentence; closing it is not. Where
# the pull request goes is the other half of it, and that is the base rule.
#
# THE BASE IS A REQUIRED, CHECKED ARGUMENT. `gh pr create` with no base sends
# the pull request to the repository's default branch, which is main. That is
# not an evasion; it is the shape of an ordinary mistake, which is the thing
# these hooks exist to stop, and it is the quietest of the four spellings
# because nothing in the command mentions main at all. The reasoning is the one
# already settled for pushes in the sibling hook: a destination that comes from
# configuration cannot be judged from here, because an agent can set
# configuration, so the command has to say where it is going.
#
# All four spellings that create or retarget a pull request are answered in one
# place -- gh pr create, gh pr edit --base, the REST write and the graphql
# mutation. Closing the convenient one alone would leave this branch in the
# state that was filed as a defect against it: the ordinary command refused
# while the API route stayed open.
#
# "Active dev branch" is read as the dev-NN shape and not as a particular
# branch. Naming the one live dev branch would mean reading repository state --
# which branches exist, or which is newest -- and repository state is what the
# sibling hook declines to rest on, for the reason it declines to rest on
# configuration: an agent can make a branch. The trade, taken knowingly: a pull
# request into a dev branch that is no longer the active one is permitted. main,
# master, a worktree branch and a typo are all refused, and those are the
# mistakes in question.
#
# Still allowed: creating a PR into a dev-NN branch, commenting on one, editing
# one without moving its base, viewing, listing, diffing and checking one,
# reviewing with --comment, every gh issue subcommand, and reading a PR through
# gh api -- including the two endpoints that decide one when they are written
# to. GET /pulls/N/reviews lists reviews and GET /pulls/N/merge reports whether
# the PR is merged; refusing those by endpoint refused a listing, not a
# decision, which the review on PR #35 caught. The method is what separates
# them, so the method is what is tested -- and it is what gates the base rule
# too, for the same reason: a read names no destination to check.
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
#
# STOPPING RULE. A newly found evasion earns a fix only if it is a shape an
# agent would plausibly write, not one it would have to construct. A flag
# sitting in front of the subcommand, a bundled shorthand flag, a graphql
# mutation in a heredoc: all shapes an agent writes without meaning to evade
# anything, and all fixed here for that reason. A payload quoted inside eval or
# a shell wrapper is not, which is why wrappers are refused outright rather than
# parsed -- that is the designed answer, not a limitation to be closed later.
# The endpoint list above is a list and will never be a principle; it stops
# growing when the spellings stop being ones an agent would plausibly write.
. "$(dirname "$0")/lib/command-scan.sh"

# The base rule splits a scoped argument list with `for TOK in $ARGS`, unquoted
# because the split is the point. That also globs the tokens against the
# worktree, so a base spelled `*` or `[a-z]*` would be read as whatever file sat
# beside it. The sibling hook answered this for the push refspec; the same
# asymmetry between the two, a third time, is not worth having.
set -f

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

BASE="Blocked: a pull request may be proposed only into the active dev branch, and the base has to be named in the command. Write: gh pr create --base dev-NN --title ... --body ..."

# The base named in one gh pr command's arguments. Prints it and succeeds;
# prints nothing and fails if no base flag is there at all, which is the shape
# that lets gh pick the repository's default branch for itself.
#
# -B is the shorthand, and gh takes shorthand flags bundled with their value
# attached or separate, so `-B main`, `-Bmain`, `-dB main` and `-dBmain` are one
# flag written four ways -- the same bundling that let `-ab` approve a pull
# request while `-a` alone was refused. Only single-dash tokens are scanned for
# B: a long flag would match on any letter it happens to contain, and --body is
# not --base.
#
# A flag whose value never arrives -- `gh pr create -B` at the end of the line
# -- reports no base, and the caller refuses that as a create naming none. An
# unreadable destination is refused rather than left to look like the permitted
# shape, which is the answer the bare push already has.
#
# The trade: quotes are stripped before this runs, so `--title "-B main"` reads
# as a base of main and is refused. A blocked title is visible and one edit
# away; this file has taken that direction throughout.
gh_pr_base() {
  local TOK WANT=
  for TOK in $1; do
    if [ -n "$WANT" ]; then printf '%s' "$TOK"; return 0; fi
    case "$TOK" in
      --base=*) printf '%s' "${TOK#--base=}"; return 0 ;;
      --base)   WANT=1 ;;
      --*)      ;;
      -*B)      WANT=1 ;;
      -*B*)     printf '%s' "${TOK#*B}"; return 0 ;;
    esac
  done
  return 1
}

# Does this gh pr create hand the pull request off to a browser? The web form
# creates nothing: it opens a prefilled page where a person chooses the base and
# confirms, so gh choosing a default is not this command choosing a destination.
# The exemption covers a missing base and nothing else -- a --base written into
# the command is still that command naming a destination, and --web does not
# launder it.
gh_pr_web() {
  local TOK
  for TOK in $1; do
    case "$TOK" in
      --web)      return 0 ;;
      --*)        ;;
      -*w*)       return 0 ;;
    esac
  done
  return 1
}

is_dev_base() {
  printf '%s' "$1" | grep -qE '^dev-[0-9]+$'
}

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

# A base carried in a gh api call: `-f base=dev-05`, `-fbase=dev-05`, and the
# graphql field `baseRefName: "dev-05"`. Two patterns rather than one negated
# one -- is a base named here at all, and is the one named a dev branch --
# because they answer different questions, and a base that matches the first and
# not the second is a destination this file cannot read, which is refused.
#
# The alternation puts baseRefName first: POSIX matching is leftmost-longest and
# would take it anyway, but a rule this file rests on should not need that to be
# recalled. The character before `base` is required to be a non-word one, or the
# `-f`/`-F` it can be written against, so that `rebase` and `database` are the
# words they are and not this field.
API_BASE_ANY='(^|[^A-Za-z0-9_]|-[fF])(baseRefName|base)[[:space:]]*[=:]'
API_BASE_DEV="(^|[^A-Za-z0-9_]|-[fF])(baseRefName|base)[[:space:]]*[=:][[:space:]]*[\"']?dev-[0-9]+[\"']?([^A-Za-z0-9_.-]|\$)"

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
  # Making or retargeting a pull request inside a wrapper is refused outright,
  # for the reason the sibling hook refuses a wrapped push: the destination sits
  # in quotes, where there is no command position for the tokeniser to find, so
  # the base cannot be read at all. Permitting a pull request whose destination
  # is unknown is not the same as permitting one into the active dev branch.
  # This refuses a wrapped listing of pull requests along with the writes, as
  # the wrapped read of one is already refused above. Run it unwrapped.
  if echo "$COMMAND" | grep -qE 'gh[[:space:]]+pr[[:space:]]+([^;&|]*[[:space:]])?(create|edit)([^-A-Za-z0-9_]|$)' \
     || echo "$COMMAND" | grep -qE '/pulls([^/A-Za-z0-9_-]|$)' \
     || echo "$COMMAND" | grep -q 'createPullRequest'; then
    echo "$BASE A shell wrapper hides the base behind quotes, so where this would go cannot be read. Run it unwrapped." >&2
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

# The base of every create and every retarget on the line, not the first.
# cs_gh_args answers about the first match in what it is handed and stops, so it
# is handed one command at a time -- the fifth defect in lib/command-scan.sh's
# list, where a second command after ; or && was never examined at all. The
# scoping is that helper's job rather than a regular expression here: asking
# whether a flag belongs to *this* command is the question two of the five
# defects came from being answered ad hoc.
while IFS= read -r CMD; do
  if ARGS=$(cs_gh_args 'pr create' <<<"$CMD"); then
    ARGS=$(printf '%s' "$ARGS" | tr -d '\042\047')
    if BASE_NAMED=$(gh_pr_base "$ARGS"); then
      if ! is_dev_base "$BASE_NAMED"; then
        echo "$BASE This names $BASE_NAMED, which is not a dev-NN branch." >&2
        exit 2
      fi
    elif ! gh_pr_web "$ARGS"; then
      echo "$BASE No base is named here, so this would go to the repository's default branch." >&2
      exit 2
    fi
  fi
  # An accepted false positive, and the reason the missing-base message is worth
  # reading rather than working around: cs_split cuts on the parens of a command
  # substitution, so a base written after one sits in a later fragment and this
  # scope does not hold it. Refusing more than a shell would is the direction
  # lib/command-scan.sh takes throughout, and the remedy is one edit -- put the
  # base ahead of the substitution. The alternative is a rule that reaches
  # across the cut for a base that may belong to a different command entirely.
  #
  # Editing a pull request stays allowed; moving its base is the same choice of
  # destination made a second time, so it is checked, and only when it is there.
  if ARGS=$(cs_gh_args 'pr edit' <<<"$CMD"); then
    ARGS=$(printf '%s' "$ARGS" | tr -d '\042\047')
    if BASE_NAMED=$(gh_pr_base "$ARGS") && ! is_dev_base "$BASE_NAMED"; then
      echo "$BASE Retargeting to $BASE_NAMED chooses that destination just as creating it there would. Edit anything else you like." >&2
      exit 2
    fi
  fi
done <<CMDLIST
$CMDS
CMDLIST

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
API_CREATE=
while IFS= read -r CMD; do
  printf '%s\n' "$CMD" | grep -qE '^gh[[:space:]]+api([^-A-Za-z0-9_]|$)' || continue
  gh_api_is_write "$CMD" || continue
  API_WRITE=1
  # The collection endpoint is where a pull request is made; /pulls/N is one
  # that already exists. Asked of the writing command's own arguments rather
  # than of the whole line, so that listing pull requests beside an unrelated
  # write is still a listing. The loop no longer stops at the first write for
  # that reason.
  if printf '%s\n' "$CMD" | grep -qE '/pulls([^/A-Za-z0-9_-]|$)'; then API_CREATE=1; fi
done <<CMDLIST
$CMDS
CMDLIST
# The graphql spelling cannot be scoped the same way: cs_split cuts a mutation
# body on its own braces and parens, so the verb and the command word are not
# in the same fragment. It is looked for in the text, as the other mutations are.
if printf '%s\n' "$SCAN" | grep -q 'createPullRequest'; then API_CREATE=1; fi

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

  # Where a pull request is going, reached through gh api rather than gh pr.
  # gh_api_is_write is the gate and the endpoint is not: refusing by endpoint is
  # what once refused a read of a pull request as though it were a decision, and
  # a read names no destination to check.
  #
  # A base written into a write is that command choosing a destination, whatever
  # the endpoint carrying it -- POST to the collection creates there, PATCH on
  # one retargets it, and graphql spells the same field baseRefName. Retitling
  # through that same PATCH names no base and stays allowed, so the field
  # decides this as it already decides state.
  #
  # A base that is present but not readable as dev-NN is refused: an unreadable
  # destination must not be able to look like the permitted one, which is the
  # answer the bare push already has. Accepted with it: prose in a written field
  # spelling `base:` reads as a base and is refused.
  if echo "$SCAN" | grep -qiE "$API_BASE_ANY" && ! echo "$SCAN" | grep -qiE "$API_BASE_DEV"; then
    echo "$BASE Naming it through gh api makes it the same destination under another spelling." >&2
    exit 2
  fi
  if [ -n "$API_CREATE" ] && ! echo "$SCAN" | grep -qiE "$API_BASE_ANY"; then
    echo "$BASE No base is named here, so this would go to the repository's default branch." >&2
    exit 2
  fi
fi

exit 0

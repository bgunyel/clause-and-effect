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

# Every base named in one gh pr command's arguments, one per line. Prints
# nothing when no base flag is there at all, which is the shape that lets gh
# pick the repository's default branch for itself.
#
# Every, not the first, and not the last. gh takes the last of a repeated flag,
# so a rule reading one occurrence can be answered by the other: reading the
# first, `--base dev-05 -B main` opened into main while satisfying a check that
# had already seen a dev branch. Reading the last would only move which half
# lies. Requiring all of them to be dev-NN is the answer that does not depend on
# knowing gh's precedence, and it is the refusing direction when they disagree.
# Found by review of be0e3c7, not by the suite.
#
# -B is the shorthand, and gh takes shorthand flags bundled with their value
# attached or separate, so `-B main`, `-Bmain`, `-dB main` and `-dBmain` are one
# flag written four ways -- the same bundling that let `-ab` approve a pull
# request while `-a` alone was refused. Only single-dash tokens are scanned for
# B: a long flag would match on any letter it happens to contain, and --body is
# not --base.
#
# A flag whose value never arrives -- `gh pr create -B` at the end of the line
# -- names no base, and the caller refuses it as a create naming none, which is
# what it is.
#
# The trade: quotes are stripped before this runs, so `--title "-B main"` reads
# as a base of main and is refused. A blocked title is visible and one edit
# away; this file has taken that direction throughout. The opposite direction is
# not symmetrical and is not taken -- see gh_pr_web.
gh_pr_bases() {
  local TOK WANT=
  for TOK in $1; do
    if [ -n "$WANT" ]; then printf '%s\n' "$TOK"; WANT=; continue; fi
    case "$TOK" in
      --base=*) printf '%s\n' "${TOK#--base=}" ;;
      --base)   WANT=1 ;;
      --*)      ;;
      -*B)      WANT=1 ;;
      -*B*)     printf '%s\n' "${TOK#*B}" ;;
    esac
  done
}

# Does this gh pr create hand the pull request off to a browser? The web form
# creates nothing: it opens a prefilled page where a person chooses the base and
# confirms, so gh choosing a default is not this command choosing a destination.
# The exemption covers a missing base and nothing else -- a --base written into
# the command is still that command naming a destination, and --web does not
# launder it.
#
# Two narrowings, both because this is the one test here that PERMITS, so a
# token read too generously is a pull request into main rather than a refusal
# someone can see. It was written both ways round first, and both were holes
# found by review of be0e3c7:
#
#   - only `--web` and exactly `-w` count, where any single-dash token holding a
#     w counted before. A label value of `-wip` and an assignee of `-w` are not
#     the web form, and `gh pr create -l -wip` opened into main.
#   - the caller hands this the arguments with QUOTED SPANS REMOVED, not merely
#     unquoted. `--title "Handle -w in gh_pr_web"` is prose, and prose in this
#     repository names flags -- that title is one a session on this very file
#     would write. Deleting the span cannot invent a flag; unquoting one can.
#
# The asymmetry with gh_pr_bases is deliberate and is the whole point: quoted
# text may still trigger a refusal there, and may not grant an exemption here.
gh_pr_web() {
  local TOK
  for TOK in $1; do
    case "$TOK" in
      --web|-w) return 0 ;;
    esac
  done
  return 1
}

is_dev_base() {
  printf '%s' "$1" | grep -qE '^dev-[0-9]+$'
}

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
#
# It is defined here, above every rule, rather than beside the gh api rules it
# was written for: the wrapper rule calls it too and runs first.
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

# Refuse unless every base in a newline-separated list is a dev-NN branch. The
# offending one is left in BAD_BASE for the caller's message. An empty list is
# no bases, which is a different question and the caller's to ask.
bases_all_dev() {
  local B
  BAD_BASE=
  [ -n "$1" ] || return 0
  while IFS= read -r B; do
    if ! is_dev_base "$B"; then BAD_BASE=$B; return 1; fi
  done <<BASELIST
$1
BASELIST
  return 0
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

# Every base a gh api call names, in the two shapes gh accepts one. Both print
# the values, one per line, for bases_all_dev -- the same "every, not the last"
# answer gh_pr_bases gives, and for the same reason: `-f base=dev-05 -f
# base=main` must not be answered by whichever occurrence a rule happened to
# look at.
#
# REST: the value is a FIELD, so the field flag is part of the pattern. Matching
# the bare word instead read `-f title="base: dev-05"` as a base, so a create
# naming none of its own was permitted. Reported on the review of be0e3c7.
# `-f base=x`, `-fbase=x` and `--field base=x` are one request written three
# ways; anchoring on the flag is also what keeps `rebase` and `database` the
# words they are.
rest_bases() {
  printf '%s\n' "$1" \
    | grep -oiE "(-[fF]|--field|--raw-field)[[:space:]]*base[[:space:]]*=[[:space:]]*[\"']?[^[:space:]\"',}]*" \
    | sed -E "s/.*=[[:space:]]*[\"']?//"
}

# graphql: baseRefName stands on its own, and has to. cs_split cuts a mutation
# body on its own braces and parens, so the field and the command word are never
# in the same fragment -- which is why this one is asked of the whole normalised
# text where the REST pair is asked of a single command. The cost is the bleed
# the REST rule no longer has: a mutation on one command and a baseRefName on
# another read as one. Accepted, because scoping it would mean re-deriving the
# split this file delegates to lib/command-scan.sh, and the shape is not one an
# agent writes by accident.
gql_bases() {
  printf '%s\n' "$1" \
    | grep -oiE "baseRefName[[:space:]]*:[[:space:]]*[\"']?[^[:space:]\"',})]*" \
    | sed -E "s/.*:[[:space:]]*[\"']?//"
}

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
  #
  # It reaches only as far as that, and no further -- each of these three names
  # a create or a retarget, not a pull request. A first version refused any
  # wrapped /pulls, which took a wrapped LISTING with it, and justified itself
  # by saying the wrapped read of one was already refused. That was not true:
  # `bash -c 'gh api repos/o/r/pulls/35'` is permitted here and was before. A
  # comment that argues from a false premise is worse than none, so the premise
  # is gone and the rule is narrowed to what the ticket asked for. Reported on
  # the review of be0e3c7. The write test is reused for the REST shape rather
  # than a second guess at what a write looks like.
  if echo "$COMMAND" | grep -qE 'gh[[:space:]]+pr[[:space:]]+([^;&|]*[[:space:]])?create([^-A-Za-z0-9_]|$)' \
     || { echo "$COMMAND" | grep -qE 'gh[[:space:]]+pr[[:space:]]+([^;&|]*[[:space:]])?edit([^-A-Za-z0-9_]|$)' \
          && echo "$COMMAND" | grep -qE '(--base|[[:space:]]-[A-Za-z]*B)([[:space:]]|=|$)'; } \
     || { echo "$COMMAND" | grep -qE '/pulls([^/A-Za-z0-9_-]|$)' \
          && gh_api_is_write "$COMMAND"; } \
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
  if RAW=$(cs_gh_args 'pr create' <<<"$CMD"); then
    # Two readings of one argument list, because the two questions want opposite
    # errors. Unquoting exposes prose as tokens, which can only add a refusal;
    # deleting the quoted span cannot invent the flag that would remove one.
    ARGS=$(printf '%s' "$RAW" | tr -d '\042\047')
    WEBARGS=$(printf '%s' "$RAW" | sed -e 's/"[^"]*"//g' -e "s/'[^']*'//g")
    BASES=$(gh_pr_bases "$ARGS")
    if [ -n "$BASES" ]; then
      if ! bases_all_dev "$BASES"; then
        echo "$BASE This names $BAD_BASE, which is not a dev-NN branch." >&2
        exit 2
      fi
    elif ! gh_pr_web "$WEBARGS"; then
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
  if RAW=$(cs_gh_args 'pr edit' <<<"$CMD"); then
    ARGS=$(printf '%s' "$RAW" | tr -d '\042\047')
    if ! bases_all_dev "$(gh_pr_bases "$ARGS")"; then
      echo "$BASE Retargeting to $BAD_BASE chooses that destination just as creating it there would. Edit anything else you like." >&2
      exit 2
    fi
  fi
done <<CMDLIST
$CMDS
CMDLIST

# gh_api_is_write is defined with the other helpers at the top of this file. It
# used to sit here, where it reads most naturally -- but the wrapper rule calls
# it, and the wrapper rule runs first, so a definition here was not yet in scope
# when it was wanted and the call would have failed quietly to "not a write".
# That is the permitting direction, and it would not have shown as an error.

# The REST endpoints and the graphql mutations behind those commands. The
# command word and the payload can be separated by the tokeniser -- a mutation
# body splits on its own braces and parens -- so gh api is looked for among the
# commands and what it carries anywhere in the text.
# Every question here is asked of ONE writing command's own text, never of the
# line. Asked of the line, a base on a neighbouring command answered for this
# one in both directions: a create naming no base was permitted because
# something else on the line said dev-05, and an unrelated issue write was
# refused because something else said main. That is the first of the five
# defects lib/command-scan.sh exists to end, reintroduced here for gh api after
# being fixed for gh pr -- exactly the split between the two spellings that this
# rule was written to close. Reported on the review of be0e3c7. The loop no
# longer stops at the first write, because a second write is a second command.
API_WRITE=
API_BAD_BASE=
API_NO_BASE=
while IFS= read -r CMD; do
  printf '%s\n' "$CMD" | grep -qE '^gh[[:space:]]+api([^-A-Za-z0-9_]|$)' || continue
  gh_api_is_write "$CMD" || continue
  API_WRITE=1
  CMD_BASES=$(rest_bases "$CMD")
  if [ -n "$CMD_BASES" ]; then
    bases_all_dev "$CMD_BASES" || API_BAD_BASE=${BAD_BASE:-nothing readable}
  # The collection endpoint is where a pull request is made; /pulls/N is one
  # that already exists and is not asked for a base it already has.
  elif printf '%s\n' "$CMD" | grep -qE '/pulls([^/A-Za-z0-9_-]|$)'; then
    API_NO_BASE=1
  fi
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
  # answer the bare push already has.
  #
  # The graphql half is settled here rather than in the loop above, on the whole
  # text, for the reason gql_bases gives. It covers the retarget as well as the
  # create: updatePullRequest carries the same field, and a rule keyed on the
  # verb would have answered for one and not the other.
  GQL_BASES=$(gql_bases "$SCAN")
  if [ -n "$GQL_BASES" ]; then
    bases_all_dev "$GQL_BASES" || API_BAD_BASE=${BAD_BASE:-nothing readable}
  elif echo "$SCAN" | grep -q 'createPullRequest'; then
    API_NO_BASE=1
  fi

  if [ -n "$API_BAD_BASE" ]; then
    echo "$BASE This names $API_BAD_BASE; reaching it through gh api makes it the same destination under another spelling." >&2
    exit 2
  fi
  if [ -n "$API_NO_BASE" ]; then
    echo "$BASE No base is named here, so this would go to the repository's default branch." >&2
    exit 2
  fi
fi

exit 0

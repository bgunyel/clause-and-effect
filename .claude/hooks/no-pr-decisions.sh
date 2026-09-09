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
# method nor the subcommand nor anything else can be read out of it. A read of a
# PR wrapped in a shell is refused with the writes, and so is every wrapped
# `gh pr`, `gh release` and `gh api` whatever verb follows. Run it unwrapped.
#
# Finding commands in the text is lib/command-scan.sh's job, and so is finding
# the subcommand inside one: cs_split returns one command per line with
# everything before the command word removed, and cs_gh_args then names a gh
# subcommand by its whole path and hands back that command's own arguments. No
# rule that goes through gh_rule describes a command position or anchors at ^.
# That is where all of PR #35's defects lived, this file's included: it was the
# sibling that had the wrapper rule, and this one that did not. It was also, for
# longer, the file that answered the position question one word too late; see
# gh_rule.
#
# Two things here are still position-dependent, and neither is an oversight of
# the same kind. VERDICT anchors at ^, but at the start of a command's own
# argument list rather than at a command word -- the opposite of a position
# question, and why it can be written there at all. The wrapper rules below do
# describe one, and that is a known open hole rather than a design: they require
# the group to follow gh immediately, so `bash -c "gh -R o/r pr merge 5"` is
# permitted while `bash -c "gh pr merge 5"` is refused. Measured, pre-existing,
# and not fixable the way the rules above were -- a quoted payload has no
# command word for cs_gh_args to find, which is the whole reason these are a
# blunt text match. Issue #51 carries it, and the question it has to settle is
# whether naming the verb inside a wrapper is worth doing at all.
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

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
SCAN=$(printf '%s\n' "$COMMAND" | cs_normalise)
CMDS=$(printf '%s\n' "$SCAN" | cs_split)

DECIDE="Blocked: deciding a pull request is Bertan's call, not an agent's. Opening a PR, commenting on it and editing it are allowed; accepting, rejecting, merging and reopening are not."

# Every rule over an ordinary command asks through here, and none of them
# describes where in a command the subcommand sits. The two that do not are the
# wrapper block, which has no command word to find and is discussed in the
# header, and the API_WRITE loop, which needs the command itself and says why.
#
# cs_gh_args answers the position question: it skips options before every word
# of the path, so `gh -R o/r pr merge 5`, `gh pr --repo o/r merge 5` and
# `gh pr merge 5` are one command to every rule below.
#
# That is what this file got wrong for as long as it had rules. GHPR and
# GHRELEASE skipped options between the group and the verb and never before it,
# and the two gh api matches were raw `^gh[[:space:]]+api` skipping none at all,
# so a single flag written first walked past all four rules -- six of the nine
# shapes in #47's table were a merge. The comment above GHPR stated the
# principle that GHPR then applied at one level only. The helper is #39's.
#
# One command at a time, because cs_gh_args answers about the first match and
# stops. Worth being exact about when that matters, because three checks were
# written here believing it mattered always: the helper scans past a command
# that is not a match, so for a rule with no ARGRE the loop and one whole-list
# call find the same thing. It is a rule *with* ARGRE that needs the loop --
# there the first match's arguments come back and a later command's are never
# seen, so `gh pr review --comment -b x 5 && gh pr review -a 6` would read as
# the comment alone. no-git-push.sh loops the same way over cs_git_args.
#
# ARGRE, when given, is matched against the arguments cs_gh_args returns -- and
# those are that command's own, so a rule that used to have to express "in the
# same command as the subcommand" as a regular expression now expresses nothing
# about position at all.
gh_rule() {  # gh_rule <subcommand path> [<extended regex over that command's arguments>]
  local WANT="$1" ARGRE="$2" CMD ARGS
  while IFS= read -r CMD; do
    ARGS=$(cs_gh_args "$WANT" <<<"$CMD") || continue
    if [ -n "$ARGRE" ]; then
      printf '%s\n' "$ARGS" | grep -qE "$ARGRE" || continue
    fi
    return 0
  done <<CMDLIST
$CMDS
CMDLIST
  return 1
}

# gh api reading a heredoc is a decision hiding in text that was just dropped --
# a heredoc is the ordinary way to send a graphql mutation. The raw command is
# re-admitted for that shape alone, and the split redone over what it added.
if gh_rule api && echo "$COMMAND" | grep -q '<<'; then
  SCAN="$SCAN
$COMMAND"
  CMDS=$(printf '%s\n' "$SCAN" | cs_split)
fi

# The verdict flags, bundled or not. gh takes shorthand flags together, so
# `gh pr review -ab "lgtm" 35` is --approve --body and was allowed while
# `-a` alone was refused. no-git-push.sh had already answered this for -fu and
# this file had not -- the same asymmetry twice. Only single-dash bundles are
# scanned for a or r: a long flag would match on any letter it happens to
# contain, and --repo would read as --request-changes.
#
# It is matched against the review's own arguments, where the flag may be the
# very first token -- `gh pr review -a 35` returns `-a 35` -- so ^ is an
# alternative to the leading space. Against a whole command there was always a
# space in front of it and the anchor was not needed.
VERDICT='(^|[[:space:]])(--approve|--request-changes|-[A-Za-z]*[ar][A-Za-z]*)([[:space:]]|=|"|$)'

# Once a wrapper is on the line, the group is the whole of what a rule can
# honestly name. These ran unanchored over the raw text and still wanted `pr`
# to follow `gh` immediately, so `gh -R o/r pr merge 5` was permitted while
# `gh pr --repo o/r merge 5` was refused -- the command-position question again,
# one word later, in the sixth place. It is also the one place cs_gh_args cannot
# answer it: the payload is quoted text with no command word for the tokeniser
# to find, which is why these rules are a blunt text match to begin with.
#
# So the verb is not read at all. Anything on the line may stand between `gh`
# and the group, and whatever follows the group is not looked at. That is the
# answer the note at the top of this file already gives -- if nothing can be
# read out of a wrapped payload, then naming merge|close|reopen inside one is
# reading it, and the table on issue #51 is what reading it badly looked like.
#
# The name says surface rather than wrapper because a group is what it matches,
# and says anywhere because that is where it looks: these rules read the whole
# command and not the payload, there being nothing here that tells the two
# apart. That is the third part of the trade below.
#
# The trade, taken knowingly, in three parts.
#
#   1. Every wrapped `gh pr`, `gh release` and `gh api` is refused whatever it
#      goes on to say: `bash -c "gh pr view 5"`, `bash -c "gh release list"`,
#      every wrapped read through `gh api`.
#   2. So is a wrapped `gh` command that is none of the three but whose text
#      carries one of the words anyway -- an issue comment whose body says
#      `pr`, `release` or `api` -- because quoted text has no argument
#      structure to say whether a word is a subcommand or prose.
#   3. So is an entirely unwrapped one that merely shares a line with a
#      wrapper: `bash -c "make test" && gh pr view 5`. Under the old rules only
#      merge|close|reopen reached across the line this way; naming the group
#      widens the reach to the reads. Matching inside the wrapper's own quotes
#      is what would narrow it, and reading inside those quotes is the thing
#      this entire section says cannot be done.
#
# All three are reads or ordinary edits, all are refused with the writes for the
# same reason the method of a wrapped `gh api` was already not read, and all are
# one edit away from working. Run them unwrapped, on a line of their own.
GH_SURFACE_ANYWHERE='gh[[:space:]]+(.*[^-A-Za-z0-9_])?(pr|release|api)([^-A-Za-z0-9_]|$)'

# A wrapper's payload sits inside quotes, where there is no command word for the
# tokeniser to find, so these run unanchored over the text -- and only once a
# wrapper has been found, never over an ordinary command.
#
# Raw text rather than $SCAN, because cs_normalise drops heredoc bodies and
# `bash <<EOF` is itself one of the wrappers: its payload would go with the
# body. But grep matches within a line, so a backslash continuation between
# `gh` and the group hid the group from these rules while the ordinary ones,
# reading $SCAN, saw through it. Joining is the half of cs_normalise these rules
# do want, and cs_join is that half on its own.
WRAPTEXT=$(printf '%s\n' "$COMMAND" | cs_join)

if echo "$WRAPTEXT" | grep -qE '(^[[:space:]]*|[;&|(`][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*((ba|z|)sh[[:space:]]+(-c|<<)|eval([^-A-Za-z0-9_]|$))'; then
  if echo "$WRAPTEXT" | grep -qE "$GH_SURFACE_ANYWHERE" \
     || echo "$WRAPTEXT" | grep -qE '/pulls/[^ ]*/(merge|reviews)' \
     || echo "$WRAPTEXT" | grep -qE '/releases([^A-Za-z0-9_-]|$)' \
     || echo "$WRAPTEXT" | grep -qiE 'state[[:space:]]*[=:][[:space:]]*"?(closed|open)"?' \
     || echo "$WRAPTEXT" | grep -qE 'mergePullRequest|addPullRequestReview|closePullRequest|reopenPullRequest|createRelease|updateRelease|deleteRelease'; then
    echo "$DECIDE A shell wrapper does not change what the command decides, and its payload cannot be read. Run it unwrapped." >&2
    exit 2
  fi
fi

if gh_rule 'pr merge'; then
  echo "$DECIDE Leave the PR open and say it is ready to merge." >&2
  exit 2
fi

# Only the verdict flags. The arguments gh_rule matches VERDICT against are the
# review's own, so nothing here has to say so. Reviewing with --comment leaves
# remarks without a verdict and stays allowed.
if gh_rule 'pr review' "$VERDICT"; then
  echo "$DECIDE Review with --comment to leave remarks without a verdict." >&2
  exit 2
fi

# Rejecting a pull request by outcome rather than by verdict.
if gh_rule 'pr close' || gh_rule 'pr reopen'; then
  echo "$DECIDE Closing a PR rejects it; say why it should be closed instead." >&2
  exit 2
fi

# Outward-facing publication. This repository is public. delete-asset is named
# separately because a path word is matched whole: `release delete` does not
# match `gh release delete-asset`, which is the same shape that keeps
# `gh pr create` out of the `pr close` rule.
if gh_rule 'release create' || gh_rule 'release delete' || gh_rule 'release delete-asset'; then
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
#
# This is the one gh rule gh_rule cannot express: the question is about the
# command, not about a pattern over its arguments. Finding the call still goes
# through cs_gh_args, so `gh --hostname h api -X PUT ...` is an api call here as
# it is everywhere else. The method is then read from the whole command rather
# than from the returned arguments -- cs_split has already scoped it to this one
# invocation, and every option that can precede `api` is a global one carrying
# neither a method nor a field.
API_WRITE=
while IFS= read -r CMD; do
  cs_gh_args api <<<"$CMD" >/dev/null || continue
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

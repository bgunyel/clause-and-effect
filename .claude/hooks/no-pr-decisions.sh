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
# question, and why it can be written there at all. The wrapper rules below no
# longer describe one. They used to: the group had to follow gh immediately, so
# `bash -c "gh -R o/r pr merge 5"` was permitted while `bash -c "gh pr merge 5"`
# was refused. That was never fixable the way the rules above were -- a quoted
# payload has no command word for cs_gh_args to find, which is the whole reason
# these are a blunt text match. Issue #51 settled it the only other way, by not
# reading the verb at all, so what these rules name now is a group standing
# anywhere on the line and nothing after it.
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
# Guarded under THE LOAD CONTRACT in lib/command-scan.sh, which is where the
# argument lives rather than in four copies of it.
#
# What it cost in this file, and why the probe list below is this file's own and
# not a list shared with its siblings. Issue #84 found this line bare here too,
# and this hook's set is the one that makes a shared list wrong: it calls
# cs_gh_args and cs_join, and no cs_git_args at all. Every rule in this file reads
# its arguments through cs_gh_args, so renaming that one permitted `gh pr merge`
# and `gh pr create --base main` alike.
LIB="$(dirname "$0")/lib/command-scan.sh"
[ -r "$LIB" ] && . "$LIB"
if ! command -v cs_normalise >/dev/null 2>&1 \
   || ! command -v cs_split >/dev/null 2>&1 \
   || ! command -v cs_gh_args >/dev/null 2>&1 \
   || ! command -v cs_join >/dev/null 2>&1; then
  echo "Blocked: no-pr-decisions.sh could not load lib/command-scan.sh, so it cannot tell whether this command decides a pull request or a release. Refusing rather than permitting." >&2
  exit 2
fi

# The base rule splits a scoped argument list with `for TOK in $ARGS`, unquoted
# because the split is the point. That also globs the tokens against the
# worktree, so a base spelled `*` or `[a-z]*` would be read as whatever file sat
# beside it. The sibling hook answered this for the push refspec; the same
# asymmetry between the two, a third time, is not worth having.
set -f

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
SCAN=$(printf '%s\n' "$COMMAND" | cs_normalise)
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
# The arguments a base is read out of, with quoted text taken out of them but a
# quoted base value kept.
#
# `tr -d` over the quotes was doing the opposite of what the comment below the
# create rule claimed. Deleting the quote characters and keeping what stood
# between them turns prose into tokens, so `--body "--base dev-05"` named a base
# in a command that named none, and the create went to the default branch with
# the hook satisfied -- the one shape issue #40 exists to refuse, arriving
# through a body. It is not only an added refusal: where no base is named at
# all, prose is what supplies one.
#
# So a base flag has its own value unquoted first, and every remaining quoted
# span is then dropped whole, which is what gh_pr_web already did for -w and
# what rest_bases already did by anchoring on the field flag. Three readers of
# the same argument list, and this was the one that still read prose.
base_args() {
  printf '%s' "$1" \
    | sed -E "s/(--base|-[A-Za-z]*B)([[:space:]]*=?[[:space:]]*)[\"']([^\"']*)[\"']/\1\2\3/g" \
    | sed -e 's/"[^"]*"//g' -e "s/'[^']*'//g"
}

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
#
# What is NOT part of that trade: `gh` had no left boundary, so any word ending
# in gh was a gh -- high, enough, through, sigh, dough -- and a wrapped
# `git commit -m 'refactor high level api client'` was refused as a PR decision
# though it names no gh and decides nothing. All three parts above presuppose a
# gh on the line, so that command fell outside every one of them, and the
# refusal text was false rather than conservative. #72. The left boundary is the
# one every other token here already has, argued for in as many words: the
# group's own right edge below, `eval` in the wrapper detector, `release delete`
# against `release delete-asset`, `rest_bases` anchoring on its field flag to
# keep `rebase` and `database` the words they are. The pattern is only ever used
# under `grep -qE` as a boolean, so consuming the boundary character costs
# nothing.
#
# Three shapes stop matching, and they have two different causes -- worth
# keeping apart, because only one of them is a choice this file made.
#
# The boundary EXISTING narrows a literal `\n` escape written immediately before
# gh: the character in front is then `n`, which no class this file would write
# admits. `printf 'summary\ngh pr review --approve 5'` inside a wrapper matched
# before and does not now. That is the single verdict the fix changes across the
# 7,621-command corpus #72 sampled, and it follows from having a left boundary
# at all rather than from which one -- measured, both candidate classes agree.
#
# The class EXCLUDING `-` and `_`, as every other token here does, separately
# narrows `my-gh pr merge 5` and `my_gh pr merge 5`.
#
# All three are evasion shapes rather than mistakes -- `./gh` and `/usr/bin/gh`
# still refuse, a path ending in a character that is none of gh's own -- and
# they are accepted under the same "these stop mistakes, not adversaries" that
# decides the rest, stated here rather than left for a later review to find.
# All three are pinned under REGRESSION: #72 in check-hooks.sh.
GH_SURFACE_ANYWHERE='(^|[^-A-Za-z0-9_])gh[[:space:]]+(.*[^-A-Za-z0-9_])?(pr|release|api)([^-A-Za-z0-9_]|$)'

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
    | sed -E 's/\\(["'"'"'])/\1/g' \
    | grep -oiE "baseRefName[[:space:]]*:[[:space:]]*[\"']?[^[:space:]\"',})]*" \
    | sed -E "s/.*:[[:space:]]*[\"']?//"
}

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

# The base of every create and every retarget on the line, not the first.
# cs_gh_args answers about the first match in what it is handed and stops, so it
# is handed one command at a time -- the fifth defect in lib/command-scan.sh's
# list, where a second command after ; or && was never examined at all. The
# scoping is that helper's job rather than a regular expression here: asking
# whether a flag belongs to *this* command is the question two of the five
# defects came from being answered ad hoc.
while IFS= read -r CMD; do
  if RAW=$(cs_gh_args 'pr create' <<<"$CMD"); then
    # Two readings of one argument list. Both drop quoted spans; the base reader
    # keeps a base flag's own quoted value, which is the only quoted text either
    # question wants.
    ARGS=$(base_args "$RAW")
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
    ARGS=$(base_args "$RAW")
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
#
# This is the one gh rule gh_rule cannot express: the question is about the
# command, not about a pattern over its arguments. Finding the call still goes
# through cs_gh_args, so `gh --hostname h api -X PUT ...` is an api call here as
# it is everywhere else. The method is then read from the whole command rather
# than from the returned arguments -- cs_split has already scoped it to this one
# invocation, and every option that can precede `api` is a global one carrying
# neither a method nor a field.
API_WRITE=
API_BAD_BASE=
API_NO_BASE=
while IFS= read -r CMD; do
  cs_gh_args api <<<"$CMD" >/dev/null || continue
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

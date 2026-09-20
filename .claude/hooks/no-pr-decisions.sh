#!/bin/bash
# Agents may open pull requests and talk on them; they may not decide them, and
# may propose one only into the active dev branch. Accepting, rejecting, merging
# or reopening a PR is Bertan's call, and so is any write to a release.
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
# reviewing with --comment, every gh issue subcommand, reading a release through
# gh release list, view, download, verify and verify-asset, and reading a PR
# through gh api -- including the two endpoints that decide one when they are
# written to. GET /pulls/N/reviews lists reviews and GET /pulls/N/merge reports whether
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
# What it cost in this file, and why the required list below is its own and
# not a list shared with its siblings. Issue #84 found this line bare here too,
# and this hook's set is the one that makes a shared list wrong: it calls
# cs_gh_args, cs_gh_opaque and cs_join, and no cs_git_args at all. Every rule in
# this file reads its arguments through cs_gh_args, so renaming that one
# permitted `gh pr merge` and `gh pr create --base main` alike.
#
# cs_gh_opaque is #118's and is required here for a reason of its own. It is the
# one function this file calls whose SUCCESS is a refusal, so a call to a name
# that is not there fails and the rule it carries simply does not fire: the
# unreadable pass below would find nothing, and release_is_read would grant the
# read it exists to withhold. Neither is loud. cs_gh_args asks the same function
# and answers for its absence itself, by reading every path as unreadable and so
# refusing every gh command this file judges -- which is loud, and is the
# library's own fail-closed default rather than a substitute for requiring the
# name here. A guard that leans on another file's default is #84's finding in
# one line.
LIB="$(dirname "$0")/lib/command-scan.sh"
[ -r "$LIB" ] && . "$LIB"
if ! command -v cs_normalise >/dev/null 2>&1 \
   || ! command -v cs_split >/dev/null 2>&1 \
   || ! command -v cs_gh_args >/dev/null 2>&1 \
   || ! command -v cs_gh_opaque >/dev/null 2>&1 \
   || ! command -v cs_join >/dev/null 2>&1 \
   || ! command -v cs_tool_input >/dev/null 2>&1 \
   || ! command -v cs_within_cap >/dev/null 2>&1; then
  echo "Blocked: no-pr-decisions.sh could not load lib/command-scan.sh, so it cannot tell whether this command decides a pull request or a release. Refusing rather than permitting." >&2
  exit 2
fi

# The base rule splits a scoped argument list with `for TOK in $ARGS`, unquoted
# because the split is the point. That also globs the tokens against the
# worktree, so a base spelled `*` or `[a-z]*` would be read as whatever file sat
# beside it. The sibling hook answered this for the push refspec; the same
# asymmetry between the two, a third time, is not worth having.
set -f

# A tool call that cannot be read refuses; see THE INPUT READ in the library.
COMMAND=$(cs_tool_input command) || exit 2
# THE LINE CAP, in lib/command-scan.sh: a line longer than 16 KB is refused
# before any pass reads it, because a hook still reading when the harness
# timeout kills it permits. Issue #96.
if ! printf '%s\n' "$COMMAND" | cs_within_cap; then
  echo "Blocked: no-pr-decisions.sh: $CS_LINE_CAP_REFUSAL" >&2
  exit 2
fi
SCAN=$(printf '%s\n' "$COMMAND" | cs_normalise)
CMDS=$(printf '%s\n' "$SCAN" | cs_split)

DECIDE="Blocked: deciding a pull request is Bertan's call, not an agent's. Opening a PR, commenting on it and editing it are allowed; accepting, rejecting, merging and reopening are not."

BASE="Blocked: a pull request may be proposed only into the active dev branch, and the base has to be named in the command. Write: gh pr create --base dev-NN --title ... --body ..."

# The two arms share the reason and each writes its own tail, as the other base
# refusals do. See quoted_base_flag.
QUOTED_FLAG="A base flag is written with a quote or a backslash in its name"

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
# What this reads is base_args' output, with every quoted span dropped but a
# base flag's own quoted value, so `--title "-B main"` names no base here: it is
# prose, and on a create that names a dev base it is permitted. This sentence
# used to say the opposite, from when quotes were stripped rather than dropped.
# A flag whose NAME is quoted never reaches this function -- quoted_base_flag
# refuses it first, for the reason written there.
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
# The asymmetry is deliberate and is the whole point: quoted text may still
# trigger a refusal -- quoted_base_flag refuses a base flag whose name is quoted
# -- and may not grant an exemption here.
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
#
# WHAT THE DROP COSTS, and it is not only an added refusal. #139. The argument
# above -- deleting a span cannot invent a flag -- is true, and was read as
# though it made deleting one safe. It does not: a span that WAS a base flag,
# `"--base" main`, is deleted with the rest, and the command then names no base.
# On a plain create that is refused for naming none, which is why this stood.
# On a retarget and under --web naming none is permitted, so the drop removed
# the refusal that `--base main` meets; and beside an unquoted `--base dev-05` it
# removed a SECOND base, the one gh takes, being the last. quoted_base_flag below
# is the answer, and it refuses rather than reads -- reading the flag back out of
# the quotes is the unquoting this comment already rejected.
base_args() {
  printf '%s' "$1" \
    | sed -E "s/(--base|-[A-Za-z]*B)([[:space:]]*=?[[:space:]]*)[\"']([^\"']*)[\"']/\1\2\3/g" \
    | sed -e 's/"[^"]*"//g' -e "s/'[^']*'//g"
}

# Is a base flag's NAME written with a quote or a backslash in it? Prints the
# first such argument, as bash would pass it, and succeeds; fails if there is
# none. Every arm refuses on it, before any base is read. #139.
#
# Refused and not read, because reading it is unquoting, and unquoting is what
# let `--body "--base dev-05"` name a base in a command that named none. A
# refusal cannot open a pull request anywhere, so it is the direction this file
# takes whenever a spelling cannot be judged. On a create that stood alone it
# changes no verdict -- `gh pr create "--base" dev-05` was already refused, for
# naming no base -- and it changes the message to the true one.
#
# What makes an argument one, and each clause is there because the next
# argument over is prose that must stay permitted:
#
#   - it is split and dequoted as bash would, so `"--base"`, `'--base'`,
#     `--"base"`, `"--base"=main`, `\--base` and `"-B"` are all `--base` or
#     `-B` by the time gh sees them. A span is read as part of the argument it
#     sits in, not as a token of its own, which is what the drop above does not
#     do and why `--"base" main` slipped past it as `-- main`. The `$` of
#     bash's `$'...'` and `$"..."` goes with its quote, found by review of this
#     fix: counted as a character, it hid `$'--base' main` as `$--base`. And
#     the escapes `$'...'` interprets are decoded as bash decodes them -- \xHH,
#     octal, \u and \U, \cX and the one-letter ones -- because each is a
#     spelling of a character gh receives: `$'\x2d-base'` and `$'\055\055base'`
#     are `--base`. The first version left them as written and called them a
#     construction rather than a spelling; Bertan's review of PR #173 retargeted
#     onto main with both. A character outside ASCII decodes to `?`, which is no
#     character of any flag, so only its not being one is read. A NUL -- `\0`,
#     `\x00`, `\u0000`, `\c@` -- is not a character at all: bash drops the rest
#     of that `$'...'` span at it and joins what follows the closing quote, so
#     `$'--base\0' main` is `--base main` and `$'--base\0'x` is `--basex`.
#     Decoded to `?`, the first was permitted; Bertan's second review of #173.
#     That review also named `\^@`, which bash 5.2 does not decode.
#
#     `\c` IS NOT DECODED BUT REFUSED, and that is the third review's answer.
#     Copying bash one escape at a time opened a hole beside each one it
#     closed: `\c` took the next character as its argument even where bash's
#     parser had already paired it -- a closing quote, or the first half of
#     `\\` -- so the span ran on past where bash ends it; and what `\c` makes
#     is the next BYTE masked to five bits, so `\cअ` is a NUL while `\cA` is
#     not. So every `\c` is taken as a possible NUL: it cuts the span, only
#     the `c` is consumed, and what follows is paired by the ordinary rules.
#     The word is judged as cut, which is the only reading that can be a flag
#     -- a control character is not a flag character. The trade: `$'--base\cA'`
#     names no base in bash and is refused here. A string nobody writes.
#   - the quote or backslash comes AT OR BEFORE the end of the flag's name. A
#     quote after it is round the value, `--base="dev-05"` and `-B"dev-05"`,
#     which base_args already reads and this must not refuse. What counts is
#     the first quote that YIELDS a character: an empty span -- `''`, `""`,
#     `$''`, `$""`, or one a NUL cuts to nothing -- holds no value to be round,
#     so one standing at or just past the end of the name refuses too.
#     `--base$'' main` is `--base main`, and was permitted as a quote round a
#     value until Bertan's fourth review of PR #173. And the `=` of `--base=`
#     counts as part of the name: a quoted or escaped `=` refuses, because the
#     value after it is read by base_args, which knows `"` and `'` and neither
#     `$'...'` nor a backslash -- `--base$'=main'` and `--base\=main` named no
#     base at all until the fifth review. The trade: `--base"=dev-05"`, which
#     base_args could read, is refused with them; `--base="dev-05"` is not.
#     `-B` needs no such clause: gh_pr_bases reads what follows its B as the
#     value, so a leading `=` is part of a value that is no dev branch.
#   - the argument holds no whitespace. gh reads `--base dev-05` as one argument
#     as an unknown flag and `-B main` as a base of ` main`, and neither names a
#     branch, a git ref being unable to hold a space. So `--title "-B main"` and
#     `--body "--base dev-05 is the base"` are prose and stay permitted. A
#     quote still open where the line ends is an argument holding a newline --
#     cs_split hands this one line of a command, and bash carries the quote on
#     to the next -- so `--body "--base` followed by a newline is prose too.
#     The first version saw only the line and refused it; Bertan's review of
#     PR #173. Unless a NUL has cut that span: the newline is dropped with the
#     rest of it, and the span closes on a later line and the word goes on
#     there, where one line cannot follow it -- `$'--ba\0`, newline, `'se main`
#     is `--base main`, and was permitted on its first line alone (the third
#     review). The next line can only EXTEND the word, so it can become a flag
#     only if it is empty so far, or begins with a dash and holds no
#     whitespace yet; those refuse, and anything else is judged as it stands.
#     Refusing every cut span there refused an ordinary multi-line body with a
#     `\c` in it (the fourth review).
#
# The trade, taken knowingly: a whitespace-free quoted argument that merely
# begins like the flag is refused wherever it stands, value or not, since
# which flags take a value is gh's to know and not this file's. `--body
# "--base"` and `--label "-Blocked"` are refused on every arm. A refusal is
# visible and one edit away.
quoted_base_flag() {
  printf '%s\n' "$1" | awk '
    # q is where the first quote or escape that YIELDS a character opened, and
    # qe where the first span that yields none did. A span with a character in
    # it that opens past the name is round the value; an empty one cannot be,
    # holding nothing, so one at or just past the end of the name refuses.
    function judge(   b) {
      if (w !~ /[[:space:]]/ && (q || qe)) {
        if (w ~ /^--base(=|$)/ && ((q && q <= length("--base") + (w ~ /^--base=/)) || (qe && qe <= length("--base") + 1))) { print w; found = 1; exit }
        if (w ~ /^-[A-Za-z]*B/) { b = index(w, "B"); if ((q && q <= b) || (qe && qe <= b + 1)) { print w; found = 1; exit } }
      }
      w = ""; q = 0; qe = 0; inw = 0; cut = 0
    }
    function open(t) { st = t; op = length(w) + 1; emp = 1 }
    function shut() { if (emp && !qe) qe = op; st = 0; cut = 0 }
    # The value of up to MAX digits of BASE at s[i+1], consumed by advancing i.
    function digits(base, max,   k, d, v) {
      v = 0
      for (k = 0; k < max && i < n; k++) {
        d = index("0123456789abcdef", tolower(substr(s, i + 1, 1))) - 1
        if (d < 0 || d >= base) break
        v = v * base + d; i++
      }
      nd = k
      return v
    }
    function chr(v) { return (v > 0 && v < 128) ? sprintf("%c", v) : "?" }
    # Append the character V decodes to. A NUL is not a character bash can pass:
    # it ends what the span contributes, and cut holds the word at that length
    # until the closing quote.
    function put(v) { if (v == 0) { if (!cut) { cut = 1; cutw = w } } else w = w chr(v) }
    # One escape inside $'"'"'...'"'"', the backslash at s[i]. Appends what bash makes of it.
    function ansi(   e, v) {
      if (i >= n) { w = w "\\"; return }
      e = substr(s, ++i, 1)
      if (e == "x") { v = digits(16, 2); if (nd) put(v); else w = w "\\x"; return }
      if (e == "u") { v = digits(16, 4); if (nd) put(v); else w = w "\\u"; return }
      if (e == "U") { v = digits(16, 8); if (nd) put(v); else w = w "\\U"; return }
      if (e ~ /[0-7]/) { i--; v = digits(8, 3); put(v % 256); return }
      if (e == "c") { put(0); return }
      if (e == "n") { w = w "\n"; return }
      if (e == "t") { w = w "\t"; return }
      if (e == "r") { w = w "\r"; return }
      if (e == "v") { w = w "\v"; return }
      if (e == "f") { w = w "\f"; return }
      if (e ~ /[abeE]/) { w = w "?"; return }
      if (e ~ /[\\"?\047]/) { w = w e; return }
      w = w "\\" e
    }
    {
      s = $0; n = length(s); st = 0
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (st) {
          len = length(w)
          if (st == 1) { if (c == "\047") { shut(); continue } w = w c }
          else if (st == 3) {
            if (c == "\047") { shut(); continue }
            if (c == "\\") ansi(); else w = w c
            if (cut) w = cutw
          } else {
            if (c == "\"") { shut(); continue }
            if (c == "\\" && i < n && substr(s, i + 1, 1) ~ /[\\"$`]/) { w = w substr(s, i + 1, 1); i++ } else w = w c
          }
          if (length(w) > len) { emp = 0; if (!q) q = op }
          continue
        }
        if (c == " " || c == "\t") { if (inw) judge(); continue }
        inw = 1
        if (c == "$" && i < n && substr(s, i + 1, 1) == "\047") { i++; open(3); continue }
        if (c == "$" && i < n && substr(s, i + 1, 1) == "\"") continue
        if (c == "\047" || c == "\"") { open(c == "\"" ? 2 : 1); continue }
        if (c == "\\" && i < n) { if (!q) q = length(w) + 1; w = w substr(s, i + 1, 1); i++; continue }
        w = w c
      }
      if (inw) {
        if (cut) { if (w == "" || (w ~ /^-/ && w !~ /[[:space:]]/)) { print (w == "" ? "a span cut to nothing" : w); found = 1; exit } }
        else if (st) w = w "\n"; judge()
      }
    }
    END { exit found ? 0 : 1 }'
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
# describes where in a command the subcommand sits. The three that do not are
# the wrapper block, which has no command word to find and is discussed in the
# header; the API_WRITE loop, which needs the command itself and says why; and
# the release loop, which asks which of five reads a command is, where gh_rule
# asks whether it is one subcommand. The last two still find the subcommand
# through cs_gh_args, so only the wrapper block answers the position question
# itself.
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
# group's own right edge below, `eval` in the wrapper detector, a release verb
# compared whole so that `verify` is not `verify-and-anything`, `rest_bases`
# anchoring on its field flag to keep `rebase` and `database` the words they
# are. The pattern is only ever used under `grep -qE` as a boolean, so consuming
# the boundary character costs nothing.
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
# still refuse HERE, a path ending in a character that is none of gh's own --
# and they are accepted under the same "these stop mistakes, not adversaries"
# that decides the rest, stated here rather than left for a later review to
# find. All three are pinned under REGRESSION: #72 in check-hooks.sh.
#
# HERE, and this is the word the sentence above lacked for two issues. It is a
# claim about THIS PATTERN, which matches raw text with a left boundary, and it
# read as a claim about the hook. It was not one: every rule outside this
# wrapper block found `gh` by the bare name at the head of a command cs_split
# emits, so `/usr/bin/gh pr merge 5` unwrapped was permitted, and so was the
# same command under each of the other four spellings. Issue #117 fixed that in
# lib/command-scan.sh -- in cs_split for the ordinary rules and in
# CS_WRAPPER_RE for this one, which had the identical hole one word further
# left, `/usr/bin/bash -c "gh pr merge 5"` reaching no wrapper rule at all.
# THE SECOND QUESTION READS A NAME TOO, and #117 reached it a round late. This
# pattern is the loose half of the wrapper rule -- does the line carry the
# surface this hook guards -- and it matched `gh` by its bare spelling only. So
# `bash -c "gh pr merge 5"` was refused while `bash -c '"gh" pr merge 5"'` was
# not, and the quoting half of #117 leaked at exactly the place the wrapper rule
# exists to close. The path and backslash spellings already passed, because the
# left boundary admits `/` and `\`; it is quotes alone that never produce the
# `gh` followed by whitespace this wanted.
#
# The class is written here rather than taken from the library, for the reason
# THE WORD LIST IS PART OF THE LOAD gives one level down: a shared variable that
# came back empty would degrade this to its old spelling silently, in the
# permitting direction, and no guard can tell an empty variable from a narrow
# one. Four copies that check-hooks.sh derives off the files and holds to each
# other is the answer this repository already gives for these four patterns.
#
# Measured before it was taken: across the 476 wrapper-carrying commands in a
# 75,346-command corpus, widening all four changed no verdict at all. It closes
# `"gh"` and `'gh'`; `g"h"` stays open, the same accepted gap CS_WORD_SPELLING
# names one level up, and it is pinned.
GH_SURFACE_ANYWHERE='(^|[^-A-Za-z0-9_])["'"'"']*gh["'"'"']*[[:space:]]+(.*[^-A-Za-z0-9_])?(pr|release|api)([^-A-Za-z0-9_]|$)'

# A pull request's state, in every spelling of the quoting AROUND the value --
# not inside the name or the value, which is #163.
# Two rules read it -- the wrapper arm below and the gh api write block near the
# foot of this file -- and the pattern is written ONCE because it was written
# twice: two copies of `"?(closed|open)"?`, each admitting a double quote and
# not a single one, so `-f state='closed'` closed a pull request through both.
# Two copies can be fixed apart, and a fix applied to one of them reads exactly
# like a fix. #137. check-hooks.sh pins each call site on its own, so a copy
# reintroduced and then corrected in one place is red rather than silent.
#
# NOT anchored on the field flag, where rest_bases below is. The two rules are
# triggered oppositely and that decides it: state refuses on PRESENCE, so a
# spelling it cannot see is a refusal that does not happen, and it has to reach
# the graphql `state:CLOSED` inside a mutation body and a bare `state=closed`
# sitting in a wrapped line's text, neither of which carries a flag at all.
# Anchoring would have narrowed a rule whose whole job is to be wide. base
# refuses on ABSENCE, so width there is what invents a base out of prose.
#
# What the widening costs, named: `state='open'` written in prose on a line that
# already reaches these rules is now refused, where `state="open"` and
# `state=open` in the same prose already were. That is CLAUDE.md's left-open
# item 2 -- quoted text has no argument structure to say whether a word is a
# value or prose -- and it is one edit away, not a decision that goes wrong.
STATE_FIELD_RE='state[[:space:]]*[=:][[:space:]]*["'"'"']?(closed|open)["'"'"']?'

# Every base a gh api call names, in the two shapes gh accepts one. Both print
# the values, one per line, for bases_all_dev -- the same "every, not the last"
# answer gh_pr_bases gives, and for the same reason: `-f base=dev-05 -f
# base=main` must not be answered by whichever occurrence a rule happened to
# look at.
#
# REST: the value is a FIELD, so the field flag is part of the pattern. This is
# the FOURTH answer to "where does the field begin", and the first three are
# kept here because each was right about the one it replaced, and because the
# shape of being wrong four times is the thing worth reading.
#
# 1. The bare word. It read `-f title="base: dev-05"` as a base, so a create
#    naming none of its own was permitted. Reported on the review of be0e3c7.
# 2. The flag, with the field name immediately after it. That fixed 1 and is
#    what keeps `rebase` and `database` the words they are -- but the quote gh
#    accepts round a whole field goes BETWEEN the flag and the name, and the
#    pattern had no room for it. `-f "base=dev-05"` therefore read as a create
#    that named no base, and the single permitted destination was refused with
#    the message that none was given. #137.
# 3. The flag, an optional quote, then the name. That fixed 2 and left the
#    separator itself unasked about: pflag accepts `--field=value` for a long
#    flag and `-f=value` for a short one, so `--field=base=main` and
#    `-f=base=main` reached GitHub with nothing here seeing a base at all.
#    Found by Bertan's review of PR #153, in the change that answered 2.
# 4. The flag, ANY separator gh accepts, an optional quote, then the name. The
#    separator between a flag and its value is exactly three things -- nothing,
#    whitespace, `=` -- so `[[:space:]=]*` is the closure and not another guess,
#    and the quote is admitted in the one position after it. `-f base=x`,
#    `-fbase=x`, `--field base=x`, `--field=base=x`, `-f "base=x"` and
#    `-f='base=x'` are one request. The anchor that answers 1 is untouched:
#    `--field=database=x` still begins `d` after the separator, and a `base`
#    reached through no flag at all is still not a base.
#
#    That is a closure of the SEPARATOR, not of the field, and an earlier
#    wording of this item claimed the second. Quoting and escaping INSIDE the
#    name or value -- `-f ba"se"=main`, `-f base\=main`, `-f \base=main` -- is
#    still unread, and on a retarget still permitted; so are `st"ate"=closed`
#    and `state=clo"sed"` in STATE_FIELD_RE above. Found by the follow-up
#    review of PR #153. A fifth regex guess is the wrong answer: the fix is to
#    dequote each argument before reading it, and the state half of that
#    stands on #130's per-command move. #163.
#
# WHICH WAY AN UNREAD SPELLING FAILS, and it is not one way. The first version
# of this comment said a spelling this rule cannot read is only ever a permitted
# create turned into a false refusal, never a bad base let through. That is
# false, and finding 1 above is what it hid: the no-base arm that produces the
# refusal is keyed on the COLLECTION endpoint, so on `PATCH /pulls/N` -- a
# retarget -- an unread base is matched by nothing and the command is permitted.
# So this rule fails REFUSING on a create and PERMITTING on a retarget, and only
# the create half is the "widening is safe here" that state's comment is
# contrasted with. Both halves are checked, in the #137 section.
rest_bases() {
  printf '%s\n' "$1" \
    | grep -oiE "(-[fF]|--field|--raw-field)[[:space:]=]*[\"']?base[[:space:]]*=[[:space:]]*[\"']?[^[:space:]\"',}]*" \
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

# Whether there is a wrapper at all is CS_WRAPPER_RE, derived once in
# lib/command-scan.sh since #79 -- one copy where all four hooks carried their
# own, and none of the four admitted the prefix words cs_split already strips,
# so `timeout 5 sh -c 'gh pr merge 5'` was permitted. The rules below are still
# this file's own, and still answer the subcommand question one level too late;
# issue #51 carries that and the header says so.
if echo "$WRAPTEXT" | grep -qE "$CS_WRAPPER_RE"; then
  if echo "$WRAPTEXT" | grep -qE "$GH_SURFACE_ANYWHERE" \
     || echo "$WRAPTEXT" | grep -qE '/pulls/[^ ]*/(merge|reviews)' \
     || echo "$WRAPTEXT" | grep -qE '/releases([^A-Za-z0-9_-]|$)' \
     || echo "$WRAPTEXT" | grep -qiE "$STATE_FIELD_RE" \
     || echo "$WRAPTEXT" | grep -qE 'mergePullRequest|addPullRequestReview|closePullRequest|reopenPullRequest|createRelease|updateRelease|deleteRelease'; then
    echo "$DECIDE A shell wrapper does not change what the command decides, and its payload cannot be read. Run it unwrapped." >&2
    exit 2
  fi
fi

# THE UNREADABLE PASS, #118, and the one rule in this file that refuses without
# naming a verb. An option written before a gh subcommand takes the next word as
# its value unless gh knows it as a boolean, so the verb a rule below would read
# is not the verb gh runs: `gh pr -t view merge 5` is a merge and
# `gh release -t list create v1` is a create, which is how a review of #118 came
# to create a real release on this repository. THE UNREADABLE GH SHAPE in
# lib/command-scan.sh is the whole of the rule and its trade; nothing is
# re-derived here, and this loop only says which paths this file judges.
#
# It stands after the wrapper block so that a wrapped command keeps the wrapper's
# refusal -- both say the same thing, that a payload which cannot be read is not
# guessed at -- and before every rule that names a verb, so that none of them
# reads one that was never there. Not before everything: the heredoc
# re-admission above asks `gh_rule api` earlier still, and an unreadable command
# carrying `<<` now satisfies it and has its raw text re-split. That is harmless
# -- re-admission only adds text for the rules below to see, and this loop
# refuses before any of them reads it -- and it is named because "before every
# rule below" is the sentence a reader would otherwise carry away.
#
# WHAT IT IS AND IS NOT LOAD-BEARING FOR, measured rather than assumed, because
# the first draft of this comment claimed the refusal and the refusal is not
# its. cs_gh_args signals "cannot tell" as success with no arguments, so an
# unreadable command already matches `gh_rule 'pr merge'` below and is refused
# there -- with this loop disabled, every command the #118 section of
# check-hooks.sh names is still BLOCK. What this loop adds is WHICH refusal.
# Without it `gh --squash view issue list` is refused by the merge rule and told
# that deciding a pull request is Bertan's call, which is not true of it and
# names no correction it can act on. The message is the whole of what is here,
# so the message is what `says` pins below it.
#
# ONE PATH PER GUARDED POSITION, not one per rule. cs_gh_opaque decides the
# position before a verb without reading the verb, so `pr merge` answers for
# `pr review`, `pr close`, `pr reopen`, `pr create` and `pr edit` alike, and
# `release view` for the four other release reads and every release write. `api`
# takes no verb, so the only position it has is the one before it, which both of
# the others already ask about; it is named anyway, because a reader checking
# that this list covers what the file judges should find all three surfaces
# here rather than have to know that one of them is subsumed.
GH_OPAQUE_PATHS=('pr merge' 'release view' 'api')
while IFS= read -r CMD; do
  for GHPATH in "${GH_OPAQUE_PATHS[@]}"; do
    if cs_gh_opaque "$GHPATH" <<<"$CMD"; then
      echo "$CS_GH_OPAQUE_REFUSAL" >&2
      exit 2
    fi
  done
done <<CMDLIST
$CMDS
CMDLIST

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

# A release may be read and not written, and the rule is an ALLOWLIST OF READ
# VERBS. It was a denylist -- create, delete, delete-asset -- and the list was
# short by two writes an agent writes without meaning anything by them: `gh
# release edit v1 --draft=false` publishes a draft, and `gh release upload`
# changes a published release's assets. It was short by a third nobody had
# counted: `new` is gh's own alias for create (gh 2.45.0, `gh help release
# create`). #97, decided as Q26 of #103.
#
# Lengthening the list was the rejected answer. A list of writes has to be kept
# in step with gh, and misses a subcommand a future gh adds; refusing only what
# publishes or destroys means reading per-flag release state -- is this edit
# setting --draft=false? -- and argument parsing is where most of this file's
# defects have lived. No agent here has a release-shaped task, so the list worth
# keeping is the short one of what reads.
#
# The trade, taken knowingly, in three parts. Each is a read or a help page, each
# is refused, and each is one edit away.
#
#   1. `ls` is gh's alias for list. The five below are the five decided, not the
#      five plus whatever gh aliases them to, which would be a list tracking
#      gh's again. The refusal names the five.
#   2. No verb at all -- `gh release`, `gh release --help`, `gh release -R o/r` --
#      is refused, and so is a write verb asking for its help page, `gh release
#      upload --help`. Neither writes anything, and telling "no subcommand" apart
#      from "some other subcommand" means skipping options outside cs_gh_args.
#      The first version of this rule did that, in a copy of the library's own
#      skip list, and review of it found the copy: lib/command-scan.sh answers
#      that question in one place and says so. Group help is `gh help release`
#      and a verb's is `gh help release upload`; neither is a gh release
#      command, and neither is refused. The refusal says so.
#   3. A quoted verb, `gh release "view" v1`, is refused with the writes. The
#      verb is matched as written, and unquoting a word to grant a read is the
#      generous reading gh_pr_web gives its reasons for not taking.
#
# The verb is the subcommand word and nothing else: each read is asked of
# cs_gh_args as a whole path, `release view`, which skips options before each
# word of it, so `gh release -R o/r view v1` and `gh -R o/r release view v1` are
# one read. A read verb anywhere in the arguments would be satisfied by a tag,
# and tags are free text -- `gh release upload view a.tgz` uploads to a tag
# named view. A path word is matched whole, so `verify` does not admit
# `verify-and-anything`.
RELEASE_READ_VERBS="list view download verify verify-asset"
RELEASE_WRITE="any write to a release is Bertan's call"
RELEASE="Blocked: $RELEASE_WRITE, and this repository is public, so a release is visible the moment it changes. Reading one is permitted, as gh release followed by one of: $RELEASE_READ_VERBS. Help is gh help release, or gh help release <verb>."

# Is this one command a gh release read? Asked of cs_gh_args once per verb, so
# the option-position question stays answered in the library and nowhere here.
release_is_read() {  # release_is_read <one command>
  local VERB
  # THE ONE CALLER WHOSE SUCCESS MEANS PERMIT, which is why #118's third outcome
  # is asked about here and nowhere else in this file. cs_gh_args signals
  # "cannot tell" as success with no arguments, so that a caller reading only
  # its status refuses -- and every other caller here does refuse on a match.
  # This one grants a read on one, so spelled that way it would grant the read
  # to `gh release -t list view v1`, whose verb gh never sees. The unreadable
  # pass above has already refused that command; this asks again rather than
  # rest on the order of two rules, since the question here is not "did some
  # earlier loop run" but "is this a read", and an unreadable command is not.
  #
  # ONLY A 1 LETS THE READ PROCEED, and the status is read that way rather than
  # with `&& return 1` because this is the one place where a call that does not
  # run at all is the permitting answer. cs_gh_opaque exits 0 for unreadable and
  # 1 for readable; a missing function exits 127, and `&& return 1` reads that
  # as readable and grants the read -- #84's shape, in the file that requires
  # the name at the top precisely so this cannot happen. Requiring it there is
  # still the guard; this is the arm that must not depend on that guard being
  # right, because it is the arm where being wrong permits.
  cs_gh_opaque 'release view' <<<"$1"
  case $? in 1) ;; *) return 1 ;; esac
  for VERB in $RELEASE_READ_VERBS; do
    cs_gh_args "release $VERB" <<<"$1" >/dev/null && return 0
  done
  return 1
}

# One command at a time, for the reason gh_rule gives: cs_gh_args answers about
# the first match and stops, so asked once over the line it finds the `gh
# release view v1` and never sees the `gh release upload` after it. gh_rule
# cannot express this one, being a question with five right answers and not one
# -- the third exception the note above gh_rule names.
while IFS= read -r CMD; do
  cs_gh_args release <<<"$CMD" >/dev/null || continue
  if ! release_is_read "$CMD"; then
    echo "$RELEASE" >&2
    exit 2
  fi
done <<CMDLIST
$CMDS
CMDLIST

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
    # question wants. A quoted flag NAME is refused before either reading runs,
    # since both would drop it. #139.
    if QFLAG=$(quoted_base_flag "$RAW"); then
      echo "$BASE $QUOTED_FLAG ($QFLAG here), so the base this names cannot be checked. Write the flag unquoted." >&2
      exit 2
    fi
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
  #
  # THE TAIL NAMES A RETARGET, NOT A CREATE, and #133 is the whole of why. $BASE
  # is one constant for four refusals because FR-23 asks the base rule's messages
  # to be consistent with each other -- #40 was a rule that held for
  # `gh pr create` and not for `gh api`, and one sentence is how that is kept
  # from happening in prose. For the three creating arms that constant is also
  # US-7's one-step correction. For this one it is not: a retarget to the active
  # dev branch is permitted, so the correction to `gh pr edit 5 --base main` is
  # `gh pr edit 5 --base dev-05`, one word of the command already written. A
  # create is not a correction of that command at all -- acted on literally it
  # leaves the mis-targeted pull request open and opens a second beside it.
  #
  # So the constant stays and the tail, which is already per-arm, names this
  # arm's own correction. The tail this replaced was "Edit anything else you
  # like", which read against a refusal whose subject is the base says the base
  # is the one thing that may not be edited -- when editing it to dev-NN is
  # exactly what is allowed.
  #
  # THE TRADE THIS LEAVES, named rather than left to be found. $BASE still opens
  # with `Write: gh pr create --base dev-NN --title ... --body ...`, so a refused
  # retarget carries TWO imperatives and the wrong one comes first: an agent that
  # acts on the first `Write:` it reads still opens a second pull request beside
  # the mis-targeted one, which is the exact failure #133 was filed about. What
  # #133 fixes is that the right correction is now there at all; it does not fix
  # the order. Keeping one constant is FR-23's own requirement and is what #133
  # asked for in as many words -- "the fix is not to break the constant" -- and
  # the alternative, a per-arm `Write:` line, would satisfy both but rewrites all
  # four base refusals and moves the pins on three arms this issue is not about.
  # So it is left, deliberately, and filed as #154 rather than traded in silence;
  # #109 owns message content. Raised by Bertan's review of PR #147.
  #
  # NOTHING STANDS IN THAT SENTENCE'S PLACE, and the first draft of this fix got
  # that wrong. It ended "No other edit is checked here", which is true of this
  # arm and not of this file: an edit sharing a line with a shell wrapper is
  # refused, which is CLAUDE.md's left-open item 2 and applies to every command
  # on the line. A message that has to be read against that caveat is a message
  # an agent corrects itself from in two steps, which is the opposite of what
  # US-7 asks. Nothing is lost by dropping it either: a refusal that names
  # `gh pr edit <n> --base dev-NN` as the thing to write has already said that
  # `gh pr edit` is not what is refused.
  if RAW=$(cs_gh_args 'pr edit' <<<"$CMD"); then
    if QFLAG=$(quoted_base_flag "$RAW"); then
      echo "$BASE $QUOTED_FLAG ($QFLAG here), so where this retargets to cannot be checked. Write the flag unquoted: gh pr edit <n> --base dev-NN." >&2
      exit 2
    fi
    ARGS=$(base_args "$RAW")
    if ! bases_all_dev "$(gh_pr_bases "$ARGS")"; then
      echo "$BASE Retargeting to $BAD_BASE chooses that destination just as creating it there would. Retarget to the active dev branch instead: gh pr edit <n> --base dev-NN." >&2
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
  # same change as a state on updatePullRequest. Which spellings of the field
  # count is STATE_FIELD_RE's, at the head of this file and shared with the
  # wrapper arm, for the reason written there: the two copies of it disagreed.
  if echo "$SCAN" | grep -qiE '(/pulls/|updatePullRequest)' \
     && echo "$SCAN" | grep -qiE "$STATE_FIELD_RE"; then
    echo "$DECIDE Setting a pull request's state through gh api closes or reopens it, which is the same decision by another name." >&2
    exit 2
  fi
  # The gh api spelling of the release rule above. It already refused a write
  # and permitted a read before #97 brought the gh release spelling to the same
  # rule, because this block is reached only once gh_api_is_write has found a
  # write. Found on the line and not on this command, though: the endpoint is
  # asked of the whole text, so a read of /releases beside a write to an issue is
  # refused with it. The bleed the base rule no longer has, still here, in the
  # refusing direction; #97 did not ask for it and did not change it.
  if echo "$SCAN" | grep -qE '/releases([^A-Za-z0-9_-]|$)'; then
    echo "Blocked: $RELEASE_WRITE, reached through gh api no less than through gh release. Reading one is permitted: a gh api request to /releases that does not write, or gh release followed by one of: $RELEASE_READ_VERBS." >&2
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

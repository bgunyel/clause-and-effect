#!/bin/bash
# THE HELPER LIBRARY of the hook check suite. check-hooks.sh sources it, from
# its own directory and never from one CHECK_HOOKS_DIR names: this is part of
# the suite that runs, not of the hooks it judges.
#
# WHAT BELONGS HERE: a function with callers in more than one file of the
# suite. It counts calling files, not sections: each issue file is one caller
# and so is the end-of-run file, and so is the driver's prelude. While a caller
# is still in the unsplit file, each section of that file counts as a caller of
# its own, which is what gives the rule a meaning before any issue file holds
# the section that calls. A call made from inside a function here counts for
# every caller of that function, so `record` is here because `pass` is. A
# helper with one caller stays beside that caller, and comes here when a second
# one appears; two sections of one issue file are one caller, because only one
# issue's work edits them. The #204 section in the unsplit file derives the set
# from the code and fails on a function on the wrong side, in either
# direction. Why it counts files and not sections is
# docs/adr/0004-check-suite-split-by-issue.md.
#
# WHAT IT DOES: it defines functions and nothing else. Sourcing it runs no
# check, prints nothing and records nothing; the variables its functions read
# -- $LEDGER, $REQ, $RAN, $HOOKS, $FIXTURES, $SUITE_DIR, $DECLARED, $PINNED and
# the fixtures' own -- are set by check-hooks.sh, before the call that reads
# them.
#
# THE COMMENTS MOVED HERE WITH THEIR FUNCTIONS, and they kept the positional
# words they were written with. "Above", "below", "the foot of this suite" and
# "this file" in a function's comment mean the suite as one text, its files in
# the order the driver sources them, around where that function stood.

# EVERY RESULT IS RECORDED, WITH THE REQUIREMENTS IT ESTABLISHES. Issue #104.
# Nothing connected the requirements in requirements.md to the checks meant to
# verify them, so "is this requirement verified?" had no answer short of reading
# this file, and a requirement no check names was invisible. Each check now
# carries the IDs it establishes, and the suite reads them back at its foot: an
# active requirement with no covering check fails it, and --matrix prints every
# ID with its checks and their results.
#
# A tag is the value of REQ when a check prints its result, set by `req` and
# cleared by `section`, so a new section cannot inherit the tags of the one above
# it: a check written under a fresh heading with no `req` is untagged, and an
# untagged check fails. The association is made at runtime, by the one call that
# prints the result, rather than by a comment nothing reads (#103 Q2).
#
# `pass` and `fail` are that call, and nothing else prints a result: the #104
# section derives that from this suite's text. Each takes the direction of the check,
# which requirements.md defines -- refuse for a BLOCK or a refusal's message,
# permit for an ALLOW, static for a check that reads no verdict -- because a
# requirement is covered by a refusing and a permitting check, not by a count.
#
# A result printed by a subshell is not recorded. The #98 self-test drives each
# helper inside one, against hooks built to crash, and what it asserts is the
# helper's own result, which is recorded where it prints; the helper's inner
# line is about a fixture and establishes nothing. The limit, named: a real check
# run inside a subshell would print and go uncounted, so it would neither cover
# its tags nor be refused for having none.
record() {  # record <refuse|permit|static> <ok|FAIL> <label>
  [ -n "$LEDGER" ] && [ "$BASHPID" = "$$" ] || return 0
  printf '%s\t%s\t%s\t%s\n' "$REQ" "$1" "$2" "${3//$'\t'/ }" >> "$LEDGER"
}
pass() {  # pass <refuse|permit|static> <format> [arguments...] -- an ok line, recorded
  local dir="$1" fmt="$2" line
  shift 2
  printf -v line "$fmt" "$@"
  printf '  ok   %s\n' "$line"
  record "$dir" ok "${line%%$'\n'*}"
}
fail() {  # fail <refuse|permit|static> <format> [arguments...] -- a FAIL line, recorded
  local dir="$1" fmt="$2" line
  shift 2
  printf -v line "$fmt" "$@"
  printf '  FAIL %s\n' "$line"
  FAILED=1
  record "$dir" FAIL "${line%%$'\n'*}"
}
req() {  # req <ID>... -- the requirements the checks after this establish
  REQ="$*"
}
section() {  # section <heading> -- print it, and let no tag carry across it
  REQ=
  printf '%s\n' "$1"
  heading_mark "$1"
}
# Where a hook is, given what a check names: a bare filename is one of this
# repository's, an absolute path is a fixture copy of one. Written once because
# three helpers below asked it, and they answered it in three identical `case`
# statements until the load-contract section gave `says` its first fixture; five
# ask it now, `feed` and `feed_says` having come with #95.
#
# It resolves and nothing else. Which hook a check ran is recorded by `ran`
# below, and the two were one function until review of PR #169 separated them;
# see there for why resolving is not running.
hook_path() {  # hook_path <script|/absolute/hook>
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s\n' "$HOOKS/$1" ;;
  esac
}
# ran <script|/absolute/hook> <exit status> -- a tagged check ran it, and it ran.
# #109's configuration section reads the record back and requires every hook
# settings.json registers to have been run by at least one tagged check.
#
# IT IS CALLED AFTER THE STATUS IS READ, never at path resolution, and review of
# PR #169 is why. `hook_path` recorded it, and a hook that is not there or is not
# executable resolves exactly as one that is: the path is built by string
# concatenation, nothing tests it, and bash reports 127 having run nothing. So a
# deleted or chmod-ed hook that every check still named would have printed
# `derived <hook> was run N times under a tag` -- a green row, under GH-109.4's
# tag, for a file that never started. The other checks of that hook would each
# have gone red, loudly, by the exit-status contract below; this row would have
# been the one place the suite said the opposite.
#
# So the status is the evidence, and only a status the hook itself can have
# produced counts: 0 or 2, the two that contract accepts as a verdict. Every
# other status FAILs the check that read it, and leaves this row saying the hook
# was never run, which is what happened. THE LIMIT: 0 and 2 are what a running
# hook exits with, not proof that one did -- 0 is also `true`, and a bash syntax
# error exits 2, the case the contract below already names. This says a tagged
# check ran the hook and got a verdict out of it, not that any check of it can
# fail. That is mutation's question.
#
# AND THE RUN HAS TO BE A CHECK'S, not the registration's. `every_hook` runs
# every hook settings.json registers under Bash, so its runs say nothing about
# whether anyone wrote a check for one; it is the only caller that does not
# record, and it says why where it runs them. Everything else here is named by
# the check that runs it.
#
# An absolute path is a fixture copy -- a hook with its library taken away, or
# one built to crash -- and is not the registered hook, so it is not recorded.
# The one exception is the session report, which reads the repository it sits in
# and so is only ever run as a byte copy placed in a fixture repository:
# `report_says` records that copy as the report, by name, and nothing here
# records a modified one. `anc_report` runs a copy too and records nothing; see
# there for why.
#
# Written from a subshell as often as not -- `cap_timed` is called inside $( ),
# and the #98 self-test runs every helper in one -- so it appends to a file
# rather than setting a variable. An untagged run is not recorded: the #104
# section already fails the check, and it would cover nothing here either.

ran() {
  case "$1" in /*) return 0 ;; esac
  [ -n "$RAN" ] && [ -n "$REQ" ] || return 0
  [ "$2" = 0 ] || [ "$2" = 2 ] || return 0
  printf '%s\t%s\n' "$REQ" "$1" >> "$RAN"
}
# What a hook's exit status means, answered once for every helper that runs a
# hook and reads one: exit 0 is ALLOW, exit 2 is BLOCK, and anything else FAILs
# the check whatever it expected. `says`, `says_not` and `feed_says` ask only for
# 2, because every one of their claims is about a refusal.
#
# Until #98 each helper read the status as one bit -- 2 was BLOCK and everything
# else ALLOW -- and `says_not` did not read it at all. So a hook that did not run
# passed every ALLOW-expecting check it was given, and every message a crashed
# hook's stderr happened not to contain: 127 for a hook, interpreter or tool that
# is not there, 1 for a `cd` into a fixture that is not there. Several fixture
# guards below carry their own account of one of those causes; this is the class.
# The #103 audit found every committed hook exiting only 0 or 2, and tightening
# the reading turned no check here red.
#
# The failure line carries the exit status and what the hook wrote to stderr,
# because FAIL alone names no cause and a crash is the case where the cause is the
# whole finding. The self-test at the foot of this suite drives every such helper
# with a hook that exits 1 and one that exits 127.
#
# One case this does not close, measured rather than reasoned: a bash syntax
# error exits 2, not 1, so a hook that does not parse reads as BLOCK and passes
# every BLOCK-expecting `check` against it. `says` is what separates the two,
# where a check has one beside it.
verdict() {  # verdict <want> <exit status> <stderr> <label>
  local want="$1" rc="$2" err="$3" label="$4" got dir
  case "$rc" in 0) got=ALLOW ;; 2) got=BLOCK ;; *) got=FAIL ;; esac
  case "$want" in BLOCK) dir=refuse ;; ALLOW) dir=permit ;; *) dir=static ;; esac
  if [ "$got" = "$want" ]; then
    pass "$dir" '%-5s %s' "$got" "$label"
  else
    fail "$dir" 'want=%s got=%s exit=%s  %s\n         stderr |%s|' \
      "$want" "$got" "$rc" "$label" "$err"
  fi
}
check() {  # check <script|/absolute/hook> <want> <label> <cmd>, run in $SUITE_DIR
  local script="$1" want="$2" label="$3" cmd="$4" rc err hook
  hook=$(hook_path "$script")
  err=$(printf '%s' "$cmd" | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' | "$hook" 2>&1 >/dev/null)
  rc=$?
  ran "$script" "$rc"
  verdict "$want" "$rc" "$err" "$label"
}

# check, with the hook's working directory named rather than inherited. The
# hook is invoked by absolute path because it sources lib/ relative to $0.
check_in() {  # check_in <dir> <script|/absolute/hook> <want> <label> <cmd>
  local dir="$1" script="$2" want="$3" label="$4" cmd="$5" rc err hook
  hook=$(hook_path "$script")
  err=$(printf '%s' "$cmd" | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' \
    | ( cd "$dir" && "$hook" ) 2>&1 >/dev/null)
  rc=$?
  ran "$script" "$rc"
  verdict "$want" "$rc" "$err" "$label"
}

# A check whose verdict the #43 migration changed. Both verdicts are literals:
# `was` is what the file returned before it, `want` what it returns after, and
# the run prints both so the flip is visible rather than inferred. Reverting
# the migration fails exactly these, reporting got=<was>.
flip() {  # flip <dir> <script> <was> <want> <label> <cmd>
  check_in "$1" "$2" "$4" "$5 (was $3)" "$6"
}

# A check whose verdict is WRONG today, and whose right verdict is written down
# beside it. Issue #106's invariance families generate variants faster than the
# defects they find can be fixed, and #103's Q18 says what to do with one: file
# it, write the check at the correct verdict, and mark it a gap -- never declare
# it an exception, which is what silencing it would look like.
#
# Both verdicts are literals, as `flip`'s are, and the difference between the
# two helpers is which way the arrow points. `flip` records a verdict a change
# deliberately moved, correct on both sides of it. `gap` records one that is
# wrong now: `right` is what the hook should return and `today` what it does, so
# the run asserts `today` and says in its own line that it is not the answer. The
# issue closing turns exactly these red, with got equal to `right`, and the fix
# rewrites them as ordinary checks. That is the intended outcome and not a
# regression, in the manner of the accepted-gap sections above.
#
# It covers nothing. A gap's tags are the requirement its issue owns, which its
# entry marks `gap → #<n>`, so the #104 coverage check does not ask
# about it; and the direction it records is the one it actually reads, which is
# today's verdict, because a matrix saying a permitted command is refused
# somewhere would be this file lying in the permitting direction.
gap() {  # gap <dir> <script> <right> <today> <label> <cmd>
  check_in "$1" "$2" "$4" "$5 [gap: $3 is the right verdict, $4 is today's]" "$6"
}

# Which refusal fired, not just that one did. no-commit-to-main.sh is kept
# beside a hook that would refuse most of the same commands only because its
# message names main and says why main is closed; nothing above can tell the
# three messages apart, so a change routing every path through one of them
# would leave the suite green and the file pointless.
# Both take a fixture path through hook_path, as check_in does: the load-contract
# section at the foot of this suite drives copies of a hook that sit outside
# $HOOKS, and which refusal one of those gives is the claim there. says_not has no
# such caller today and resolves one anyway, because the pair diverging is how the
# next reader learns the wrong rule about which of the two can be pointed at a
# fixture.
# Both FAIL unless the hook refused, with exit 2: see `verdict`. A crashed hook's
# stderr is not a refusal, and it passed `says_not` whenever it lacked the fragment.
says() {  # says <dir> <script|/absolute/hook> <fragment> <label> <cmd>
  local dir="$1" script="$2" want="$3" label="$4" cmd="$5" err rc hook
  hook=$(hook_path "$script")
  err=$(printf '%s' "$cmd" | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' \
        | ( cd "$dir" && "$hook" ) 2>&1 >/dev/null)
  rc=$?
  ran "$script" "$rc"
  if [ "$rc" != 2 ]; then
    fail refuse '%s\n         wanted a refusal saying |%s|, got exit=%s\n         stderr |%s|' \
      "$label" "$want" "$rc" "$err"
    return
  fi
  case "$err" in
    *"$want"*) pass refuse 'says  %s' "$label" ;;
    *) fail refuse '%s\n         wanted the refusal to say |%s|\n         it said |%s|' \
         "$label" "$want" "$err" ;;
  esac
}

# The other half of says: a refusal that must not say something. The fallback
# detector cannot tell a merged branch from one cut before the dev branch moved,
# so a message claiming a merge there would be a claim the hook cannot support.
# Nothing above can catch a message saying too much.
# The third of the family: a refusal that must BEGIN with something. `says` and
# `says_not` both ask about containment, which is the right question for a tail
# -- an arm's own sentence can sit anywhere in its message and still be the thing
# that tells the arm from its neighbours. It is the wrong question for an
# opening. Sixteen rows below are labelled "opens with the rule", and until the
# third review of PR #169 every one of them passed for a message carrying the
# rule ANYWHERE, including appended after the arm's tail -- which is the order
# #154 is filed about, at the other constant. The mutation behind them deletes
# the constant, so it proved the deletion and never the order its own id claims.
#
# Position is all that separates this from `says`, so it reads the exit status
# the same way and is driven by the same self-test list.
says_first() {  # says_first <dir> <script|/absolute/hook> <opening> <label> <cmd>
  local dir="$1" script="$2" want="$3" label="$4" cmd="$5" err rc hook
  hook=$(hook_path "$script")
  err=$(printf '%s' "$cmd" | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' \
        | ( cd "$dir" && "$hook" ) 2>&1 >/dev/null)
  rc=$?
  ran "$script" "$rc"
  if [ "$rc" != 2 ]; then
    fail refuse '%s\n         wanted a refusal opening with |%s|, got exit=%s\n         stderr |%s|' \
      "$label" "$want" "$rc" "$err"
    return
  fi
  case "$err" in
    "$want"*) pass refuse 'says  %s' "$label" ;;
    *"$want"*) fail refuse '%s\n         the refusal says |%s| but does not open with it\n         it said |%s|' \
         "$label" "$want" "$err" ;;
    *) fail refuse '%s\n         wanted the refusal to open with |%s|\n         it said |%s|' \
         "$label" "$want" "$err" ;;
  esac
}
says_not() {  # says_not <dir> <script|/absolute/hook> <fragment> <label> <cmd>
  local dir="$1" script="$2" unwanted="$3" label="$4" cmd="$5" err rc hook
  hook=$(hook_path "$script")
  err=$(printf '%s' "$cmd" | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' \
        | ( cd "$dir" && "$hook" ) 2>&1 >/dev/null)
  rc=$?
  ran "$script" "$rc"
  if [ "$rc" != 2 ]; then
    fail refuse '%s\n         wanted a refusal not saying |%s|, got exit=%s\n         stderr |%s|' \
      "$label" "$unwanted" "$rc" "$err"
    return
  fi
  case "$err" in
    *"$unwanted"*) fail refuse '%s\n         the refusal must not say |%s|\n         it said |%s|' \
         "$label" "$unwanted" "$err" ;;
    *) pass refuse 'says  %s' "$label" ;;
  esac
}

# A property of a file rather than of a process. See the arming section at the
# foot of this suite for why one file in .claude/ needs this and the others do
# not. Fixed strings, not patterns: the expectation is the line as written.
# Comments are stripped before the search, and that is the whole point rather
# than a detail: `grep -qF` over raw file text matches a literal that has been
# commented OUT, so every one of these stayed green while the line it names did
# nothing. Found by review of PR #64, not by this suite. Comment-out-and-leave
# is how a shell script ordinarily gets edited, not a constructed evasion, so
# this is the permitting-direction defect these checks exist to catch, in the
# checks themselves. None of the literals below contains a `#`, so stripping
# from the first one is safe for them.
# THE FILE HAS TO BE NAMED ABSOLUTELY, asked of all three of these helpers by the
# one below. A relative name -- a bare `no-git-push.sh`, or a `$hook` holding
# one -- is read from this process's working directory, which is $SUITE_DIR, so
# under a $CHECK_HOOKS_DIR override the check reads this repository's own hooks
# and says nothing whatever about the copy under judgment. Sixty-nine calls were
# spelled that way, among them every pin that a hook does not source the library
# unguarded: a copy with the guard deleted printed ok for all of them, which is
# #84's defect with nothing at all watching for it. Bertan's review of PR #142.
#
# Asked here, at the moment the file is read, because that is the only question
# no spelling can hide from: the derivation in the #107 section reads this suite's
# text and cannot see through a variable, and it was a variable holding a bare
# name that the first version of this fix left behind.
absolute_or_fail() {  # absolute_or_fail <label> <file> -- 0 when absolute
  case "$2" in
    /*) return 0 ;;
    *) fail static '%s\n         %s is not an absolute path, so it is read from this suite'"'"'s own directory and not from the hooks under judgment' \
         "$1" "$2"
       return 1 ;;
  esac
}

armed() {  # armed <label> <file> <literal>
  absolute_or_fail "$1" "$2" || return
  if sed 's/[[:space:]]*#.*$//' "$2" 2>/dev/null | grep -qF -- "$3"; then
    pass static 'armed %s' "$1"
  else
    fail static '%s\n         expected %s to contain |%s|' "$1" "$2" "$3"
  fi
}

# A fixture guard rather than a check, and it stops the suite rather than
# failing one line. An unmade worktree makes ( cd "$dir" && hook ) return 1,
# which `verdict` FAILs; this names the cause once, where a column of FAILs would
# each blame its own check. Said once here rather than three times below.
need_worktree() {  # need_worktree <dir> <fixture name>
  [ -d "$1" ] && return 0
  echo "the $2 worktree was not created; the checks against it prove nothing" >&2
  exit 1
}

# `armed` strips a shell comment before it looks, so that commenting a line out
# can no longer satisfy a pin. That makes it a pin on code, and its header says
# so: none of its literals carries a `#`. Two kinds of file here are not code.
# Prose in a comment is the whole of what some pins assert -- an argument the
# other file points at, which lives nowhere but a comment -- and a markdown
# fixture opens its headings with the same character, so stripping erases the
# line rather than a trailing remark. Routed through `armed`, such a pin cannot
# pass: measured, not reasoned, on the boundary-section check that dev-05 is
# red on today. This reads the file as written, and the name says which.
prose_count() {  # prose_count <file> <literal> -- how many lines say it
  grep -cF -- "$2" "$1" 2>/dev/null
}

written() {  # written <label> <file> <literal> -- the file as written, # and all
  absolute_or_fail "$1" "$2" || return
  if grep -qF -- "$3" "$2" 2>/dev/null; then
    pass static 'written %s' "$1"
  else
    fail static '%s\n         expected %s to still say |%s|' "$1" "$2" "$3"
  fi
}

# The absence has to be an absence IN a file that was read. `grep -qF` on a file
# that is not there exits 2, which fell into the else arm and reported ok -- so
# every pin below would have passed for a file renamed or deleted away, which is
# the permitting direction and the same shape as the #84 defect these were added
# for. Found by review of that change, not by this suite.
unarmed() {  # unarmed <label> <file> <literal>
  absolute_or_fail "$1" "$2" || return
  if [ ! -r "$2" ]; then
    fail static '%s\n         %s cannot be read, so the absence of |%s| is evidence of nothing' \
      "$1" "$2" "$3"
  elif grep -qF -- "$3" "$2" 2>/dev/null; then
    fail static '%s\n         %s must not contain |%s|' "$1" "$2" "$3"
  else
    pass static 'armed %s' "$1"
  fi
}

tok() {  # tok <label> <expected> <actual>
  if [ "$3" = "$2" ]; then
    pass static '%s' "$1"
  else
    fail static '%s\n         want |%s|\n         got  |%s|' "$1" "$2" "$3"
  fi
}

check_file() {  # check_file <script|/absolute/hook> <want> <label> <path relative to the repo>
  local script="$1" want="$2" label="$3" path="$4" rc err hook
  hook=$(hook_path "$script")
  err=$(printf '%s' "$path" | jq -Rs '{tool_name:"Edit",tool_input:{file_path:.}}' \
    | CLAUDE_PROJECT_DIR="$REPO_ROOT" "$hook" 2>&1 >/dev/null)
  rc=$?
  ran "$script" "$rc"
  verdict "$want" "$rc" "$err" "$label"
}

# feed and feed_says: a hook handed raw stdin rather than a command. Every
# helper above builds its payload with jq from a string, so none of them can hand
# a hook a tool call that is not JSON, or one whose field is not a string --
# which is the seam issue #95 is about, and its section at the foot of this suite
# is where these are mostly driven. The hook runs in $ON_DEV with
# CLAUDE_PROJECT_DIR naming this repository, so one helper serves the Bash hooks
# and the Edit hook alike, and PATH is an argument so that jq can be taken off it.
#
# Both read the exit status as every helper above does since #98, `feed` through
# `verdict` and `feed_says` as `says` does. That matters more here than anywhere.
# A hook that dies on malformed input exits 1 or 127, the harness treats that as a
# non-blocking error and runs the command, and a helper reading "not 2" as ALLOW
# would pass it as a permit nobody looks at twice.
#
# They were written for #95 with a reading of their own, and merged with #98's
# beside it rather than under it (#124): `feed` mapped the status itself and threw
# the hook's stderr away, so its failure line named no cause, and `feed_says` did
# not read the status at all, so a hook that crashed printing the fragment passed.
# That second shape is the one #98 removed from `says`.
feed() {  # feed <PATH> <script|/absolute/hook> <ALLOW|BLOCK> <label> <raw stdin>
  local path="$1" script="$2" want="$3" label="$4" payload="$5" rc err hook
  hook=$(hook_path "$script")
  err=$(printf '%s' "$payload" \
        | ( cd "$ON_DEV" && PATH="$path" CLAUDE_PROJECT_DIR="$REPO_ROOT" "$hook" ) 2>&1 >/dev/null)
  rc=$?
  ran "$script" "$rc"
  verdict "$want" "$rc" "$err" "$label"
}
feed_says() {  # feed_says <PATH> <script|/absolute/hook> <fragment> <label> <raw stdin>
  local path="$1" script="$2" want="$3" label="$4" payload="$5" err rc hook
  hook=$(hook_path "$script")
  err=$(printf '%s' "$payload" \
        | ( cd "$ON_DEV" && PATH="$path" CLAUDE_PROJECT_DIR="$REPO_ROOT" "$hook" ) 2>&1 >/dev/null)
  rc=$?
  ran "$script" "$rc"
  if [ "$rc" != 2 ]; then
    fail refuse '%s\n         wanted a refusal saying |%s|, got exit=%s\n         stderr |%s|' \
      "$label" "$want" "$rc" "$err"
    return
  fi
  case "$err" in
    *"$want"*) pass refuse 'says  %s' "$label" ;;
    *) fail refuse '%s\n         wanted the refusal to say |%s|\n         it said |%s|' \
         "$label" "$want" "$err" ;;
  esac
}

# env_feed, env_cmd, env_says and report_says: issue #108, where a hook's verdict
# is read against an ENVIRONMENT this suite built -- git off PATH, a directory
# that is no repository, a detached HEAD, no origin, no dev-NN ref or two. Every
# helper above fixes one half of that and leaves the other to the invoker:
# check_in names a directory and takes the suite's PATH, feed names a PATH and
# runs in $ON_DEV. These name both, which is what each row of #108's table needs.
# They were defined beside the others rather than in that section because the
# #98 self-test drives every helper that reads a hook's exit status, and a
# function defined after it had not been defined when it ran. Here, every one of
# them is defined before any section runs.
env_feed() {  # env_feed <dir> <PATH> <script|/absolute/hook> <ALLOW|BLOCK> <label> <raw stdin>
  local dir="$1" path="$2" script="$3" want="$4" label="$5" payload="$6" rc err hook
  hook=$(hook_path "$script")
  err=$(printf '%s' "$payload" \
        | ( cd "$dir" && PATH="$path" CLAUDE_PROJECT_DIR="$REPO_ROOT" "$hook" ) 2>&1 >/dev/null)
  rc=$?
  ran "$script" "$rc"
  verdict "$want" "$rc" "$err" "$label"
}

env_says() {  # env_says <dir> <PATH> <script|/absolute/hook> <fragment> <label> <command>
  local dir="$1" path="$2" script="$3" want="$4" label="$5" cmd="$6" rc err hook
  hook=$(hook_path "$script")
  err=$(printf '%s' "$cmd" | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' \
        | ( cd "$dir" && PATH="$path" CLAUDE_PROJECT_DIR="$REPO_ROOT" "$hook" ) 2>&1 >/dev/null)
  rc=$?
  ran "$script" "$rc"
  if [ "$rc" != 2 ]; then
    fail refuse '%s\n         wanted a refusal saying |%s|, got exit=%s\n         stderr |%s|' \
      "$label" "$want" "$rc" "$err"
    return
  fi
  case "$err" in
    *"$want"*) pass refuse 'says  %s' "$label" ;;
    *) fail refuse '%s\n         wanted the refusal to say |%s|\n         it said |%s|' \
         "$label" "$want" "$err" ;;
  esac
}
# The one helper here that runs no hook: report-stale-branches.sh is a
# SessionStart report, so what is asked of it is that it exited 0 AND said a
# literal -- #108's GH-108.9, where the failure it pins was a silent exit 0. Both
# halves are in one helper because either alone passes the thing the other
# catches: a report that says the right sentence and then exits 1 stops the
# session, and one that exits 0 having said nothing is the defect itself. The
# script is a parameter so that the #98 self-test can point it at a fixture; the
# section that uses it passes a copy of the file outside any repository. Its
# argument order is the family's -- the environment first, then what is run, then
# what is expected of it, then the label -- so that a reader moving between these
# helpers does not have to check.
report_says() {  # report_says <PATH> <script> <literal> <label>
  local path="$1" script="$2" want="$3" label="$4" out rc
  out=$( cd "$(dirname "$script")" && PATH="$path" bash "$script" 2>&1 )
  rc=$?
  # A copy of the registered report, placed in a fixture repository because the
  # report reads the repository it sits in; the #98 self-test's crashing
  # fixtures carry other names. Recorded after the run, and by name rather than
  # through `hook_path`, which never sees this one. See `ran`.
  #
  # THE NAME IS THE WHOLE TEST, and #187 owns what that costs. `ran` refuses an
  # absolute path because a fixture copy is not the registered hook; this steps
  # around that rule on the strength of an invariant -- every fixture carrying
  # this name is a byte copy -- which is written here and enforced nowhere, while
  # `nolib_path` and `halflib_path` build modified copies of other hooks a few
  # hundred lines down. A modified copy keeping the name would make GH-109.4
  # green for a hook no check ran, which is what the first review of PR #169 had
  # this record rewritten to stop.
  [ "${script##*/}" = report-stale-branches.sh ] && ran report-stale-branches.sh "$rc"
  if [ "$rc" != 0 ]; then
    fail static '%s\n         a SessionStart report must exit=%s, got exit=%s\n         output |%s|' \
      "$label" 0 "$rc" "$out"
  elif [ "${out#*"$want"}" = "$out" ]; then
    fail static '%s\n         wanted the report to say |%s|\n         it said |%s|' "$label" "$want" "$out"
  else
    pass static 'report %s' "$label"
  fi
}

# every_hook: issue #109. One command through every hook named in $XH_HOOKS, in
# that order -- the Bash hooks settings.json registers, read in #109's section --
# and a pass only if every one exits exactly 0, which is how the harness decides
# whether a command runs at all. Every helper above runs one hook; this is the
# one question none of them can ask. The #98 self-test drives it, and runs before
# #109's section does, which is why it was defined with the others.
#
# The failure line names every hook that did not exit 0, each with its status and
# its stderr in the spelling `verdict` uses, since the case it exists for is a
# second hook refusing what the first permits and the name is the whole finding.
# ON AN EMPTY LIST IT PASSES, which is #186. The loop body would not run,
# `refused` would stay empty, and this would print `ok ALLOW by all` for a
# command no hook had judged -- recording permit-direction coverage for six
# requirements on nothing. The guard that answers it today is an external one
# beside the derivation that reads settings.json, so it covers that producer and
# not this consumer, and `drive_helper` and `every_hook_of` already set
# `XH_HOOKS` from elsewhere. That is the first review of PR #169's finding at a
# second call site, and the sixth's: the guard belongs in here, as a failing
# verdict rather than an abort.
every_hook() {  # every_hook <dir> <label> <cmd> -- permit, by every Bash hook
  local dir="$1" label="$2" cmd="$3" hook rc err refused=
  for hook in $XH_HOOKS; do
    err=$(printf '%s' "$cmd" | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' \
          | ( cd "$dir" && CLAUDE_PROJECT_DIR="$dir" "$(hook_path "$hook")" ) 2>&1 >/dev/null)
    rc=$?
    # IT DOES NOT RECORD, and the third review of PR #169 is why. This loop runs
    # whatever settings.json registers under Bash, so a run of it is derived from
    # the registration and not from anyone having written a check. Feeding the
    # GH-109.4 record from here made that row self-satisfying for the seven Bash
    # hooks: register one, write no checks for it, and the row printed `was run
    # 41 times under a tag` -- which is the case the audit filed it for, "a
    # registered hook with zero checks passes", passing. The same shape the first
    # review found one level down, where `ran` was fed from `hook_path` and a
    # resolution counted as a run. A record has to come from something other than
    # the fact it attests.
    [ "$rc" = 0 ] || refused="$refused
         ${hook##*/} exit=$rc stderr |$err|"
  done
  if [ -z "$refused" ]; then
    pass permit 'ALLOW by all  %s' "$label"
  else
    fail permit '%s\n         wanted every Bash hook to exit 0; these did not:%s' "$label" "$refused"
  fi
}

holds() {  # holds <label> <text> <literal>
  case "$2" in
    *"$3"*) pass static 'holds %s' "$1" ;;
    *) fail static '%s\n         expected |%s|\n         in |%s|' "$1" "$3" "$2" ;;
  esac
}
# The absence has to be an absence in something that was read, for the reason
# `unarmed` gives: an empty line is what a deleted read prints.
lacks() {  # lacks <label> <text> <literal>
  if [ -z "$2" ]; then
    fail static '%s\n         nothing was read, so the absence of |%s| is evidence of nothing' "$1" "$3"
  else
    case "$2" in
      *"$3"*) fail static '%s\n         must not contain |%s|\n         in |%s|' "$1" "$3" "$2" ;;
      *) pass static 'lacks %s' "$1" ;;
    esac
  fi
}

# A third helper, because the two above read a file and this asks about a list
# this suite has computed. One membership convention, written once: the spaces
# belong to the pattern, so no literal carries its own.
present() {  # present <label> <needle> <space-separated haystack>
  case " $3 " in
    *" $2 "*) pass static '%s' "$1" ;;
    *) fail static '%s' "$1" ;;
  esac
}

# Written once, because this suite's own header is audited the same way below.
first_comment_block() {  # first_comment_block <file> -- after the shebang, up to the first bare #
  awk 'NR == 1 { next } /^#$/ { exit } /^#/ { print; next } { exit }' "$1" 2>/dev/null
}

# GH IN THE FARM, the host's or one synthesised here (#155). The farm is the
# invoker's PATH, so what it holds depends on the machine -- and the #108 section
# below builds its `gh`-less environment as THIS FARM MINUS `gh`, which on a
# machine with no `gh` was the farm minus nothing. The first guard there demanded
# a one-name difference and aborted the whole suite on such a machine; the fix
# that followed tolerated a no-difference copy, and bought the machine-
# independence by leaving the GH-108.6 checks no `gh` to be evidence about on
# exactly the machines that had none. Giving the farm one here removes the
# choice: the difference is always one name, the guard requires it
# unconditionally, and those checks are evidence about `gh` wherever they run.
#
# A STUB IS RIGHT FOR GH AND WRONG FOR GIT, and the difference is whether the
# SUITE needs the tool or only its name. `gh` is a dependency of no hook, and
# report-stale-branches.sh is the only file in .claude/hooks/ that calls it at
# all -- but what the stub rests on is not that no check drives that file, it is
# that no run of it ever executes a `gh`, and those are not the same sentence.
# Of the four PATHs it is driven under below, two carry no `gh` of the farm's to
# run and one stops at the not-a-repository guard before it would; the fourth is
# the farm minus `git`, which does carry the farm's `gh`, and stops at the
# `command -v git` guard standing above the first call. That last one is a
# property of report-stale-branches.sh and not of this farm -- an edit there
# reading `gh` before `git` would have this stub answering for a real one -- so
# it is checked beside that run, under GH-155.1, rather than asserted here. A
# name is then the whole of what the fixture wants from it.
#
# `git` is a dependency of this suite: every repository fixture above was built
# with it, so a farm without a `git` is a machine this suite cannot run on rather
# than a gap to synthesise over, and a fake `git` would be answering the very
# questions the hooks' verdicts are read off. `git` is therefore never stubbed --
# the farm's entry for it is the host's or the suite has already failed -- and
# the guard in #108 says so where it treats the two alike.
#
# SO THE STUB EXISTS TO BE A NAME AND NOT A PROGRAM, and it says so when run
# rather than pretending to be `gh`. A stub that exited 0 in silence would let a
# later check read its silence as gh's answer, which is #108's own failure shape
# arriving through the fixture instead of through a hook.
#
# A NAME IN THE FARM IS A FILE IN A DIRECTORY, and `command -v` answers a
# different question. It resolves shell FUNCTIONS ahead of PATH, and bash imports
# exported ones -- `BASH_FUNC_gh%%` in the environment -- into a non-interactive
# script like this one. So on a host whose environment exports a `gh` wrapper,
# `PATH=<farm>; command -v gh` says yes where the farm holds nothing: the
# synthesis returns having written no stub, and the guard in #108, unconditional
# as of this branch, aborts the whole suite before #104's coverage derivations
# are reached. That is the abort-on-some-machines failure #155 exists to remove,
# arriving by a rarer route -- found by review of PR #161 and not by a machine.
# Every question this suite asks of a farm is asked of the directory from here
# on, the guard below included, because the two are one rule read twice and a
# `command -v` left in either is that abort.
farm_has() {  # farm_has <dir> <name> -- is that name in the farm? asked of the directory
  [ -x "$1/$2" ]
}

farm_stub_gh() {  # farm_stub_gh <farm dir> -- give it a gh if the host gave none
  local dir="$1"
  farm_has "$dir" gh && return 0
  # THE UNLINK IS NOT REDUNDANT WITH THE RETURN ABOVE, and this is the one line
  # here that could have damaged the invoker's machine. Every other entry in the
  # farm is a SYMLINK to a host binary, so `>` on one of them writes THROUGH the
  # link and truncates the file it points at -- the host's own `gh`. The return
  # above means the entry is normally not there at all, but a dangling link
  # reaches this line too, and so would any later edit that moved the return.
  # Found by mutation rather than by reading: with the return taken out, this line
  # tried to write /usr/bin/gh and was refused only because that file is root's.
  #
  # NO CHECK COVERS THIS LINE, and taking it out is a mutation that survives --
  # measured, not assumed. It can only be reached when the return above is wrong,
  # so a suite in which the return is right cannot tell the two spellings apart.
  # What the pair of mutations says is the whole of what is known: with the return
  # gone and this line present, the host's gh is left alone and the check below
  # names the defect; with both gone, the suite aborts at the fixture guard having
  # tried to truncate a file it does not own.
  rm -f "$dir/gh"
  printf '#!/bin/bash\necho "%s" >&2\nexit 1\n' "$FARM_STUB_SAYS" > "$dir/gh" || return 1
  chmod +x "$dir/gh"
}

# Where each hook holds an opinion, and one short command it refuses on its
# content. Literals per hook, so that an at-the-cap refusal can be told apart
# from the cap's; a hook added to settings.json with no row here fails below
# rather than going unasked.
cap_dir() {  # cap_dir <hook>
  case "$1" in
    no-commit-to-main.sh) printf '%s\n' "$ON_MAIN" ;;
    no-work-on-stale-branch.sh) printf '%s\n' "$WT_STALE" ;;
    # Every no-git-push.sh check runs in the push fixture #94 built, so that
    # where the command runs is a named directory and not the suite's own.
    no-git-push.sh) printf '%s\n' "$PUSH_WT" ;;
    *) printf '%s\n' "$ON_DEV" ;;
  esac
}
cap_refused() {  # cap_refused <hook>
  case "$1" in
    no-git-push.sh) printf '%s' 'git push --force origin main' ;;
    no-pr-decisions.sh) printf '%s' 'gh pr merge 5' ;;
    no-commit-to-main.sh|no-work-on-stale-branch.sh) printf '%s' 'git commit -m wip' ;;
    pytest-via-uv-group.sh) printf '%s' 'pytest tests/' ;;
    alembic-via-uv-group.sh) printf '%s' 'alembic upgrade head' ;;
    append-only-docs.sh) printf '%s' 'rm -rf docs/dev-log' ;;
  esac
}

# check_in, encoding the command with --rawfile rather than -Rs, and used only by
# the two wide checks below. jq 1.7's -Rs -- which every other helper here
# encodes with -- splits a multibyte character near its read-buffer boundary into
# two U+FFFD: measured, the 16384-byte wide line reached the hook as 16392 bytes,
# over the cap, and was refused for that. Aligning the characters to an even
# offset did not avoid it, and --rawfile and --arg both hand it over intact. The
# hooks' own `jq -r` decodes the harness's JSON intact too, so the defect is in
# this suite's encode alone, and no check before this section carries a multibyte
# command long enough to meet it.
#
# It reads the status through `verdict`, as check_in does. Its first version read
# it as one bit, the #98 defect itself: a crashed hook passed the wide ALLOW.
# Found by review of PR #123 once #98 was merged in, not by this suite.
check_rawfile_in() {  # check_rawfile_in <dir> <script> <want> <label> <cmd>
  local dir="$1" script="$2" want="$3" label="$4" cmd="$5" rc err
  printf '%s' "$cmd" > "$FIXTURES/rawfile.txt"
  err=$(jq -n --rawfile c "$FIXTURES/rawfile.txt" '{tool_name:"Bash",tool_input:{command:$c}}' \
    | ( cd "$dir" && "$(hook_path "$script")" ) 2>&1 >/dev/null)
  rc=$?
  ran "$script" "$rc"
  verdict "$want" "$rc" "$err" "$label"
}

cap_guard() {  # cap_guard <fixture> <want> <got>
  [ "$2" = "$3" ] && return 0
  echo "the $1 fixture measures $3 where it was built to be $2; the checks using it prove nothing" >&2
  exit 1
}

# The fastest of three runs, stopping at the first one under the bound, since
# the fastest is then under it too. Only a run that refused is timed: a hook
# that dies before reading anything is fast as well, so a time with no verdict
# beside it would pass for a hook that is not there.
cap_timed() {  # cap_timed <dir> <hook|/absolute/hook> <cmd> -- "<ms>", or "exit <rc>" for a run that did not refuse
  local i s e ms rc best=
  printf '%s' "$3" | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' > "$FIXTURES/timed.json"
  for i in 1 2 3; do
    s=$(date +%s%N)
    ( cd "$1" && "$(hook_path "$2")" ) < "$FIXTURES/timed.json" >/dev/null 2>&1
    rc=$?
    e=$(date +%s%N)
    # After the end timestamp, not before it: this is the one helper whose claim
    # is a duration, and a record written between the run and the read would be
    # measured as the hook's.
    ran "$2" "$rc"
    [ $rc -eq 2 ] || { printf 'exit %s\n' "$rc"; return; }
    ms=$(( (e - s) / 1000000 ))
    if [ -z "$best" ] || [ "$ms" -lt "$best" ]; then best=$ms; fi
    [ "$best" -lt 1000 ] && break
  done
  printf '%s\n' "$best"
}
under_a_second() {  # under_a_second <label> <cap_timed output>
  case "$2" in
    exit*) fail static '%s\n         the timed command was not refused (%s), so its time is not the judged path' "$1" "$2" ;;
    *) if [ "$2" -lt 1000 ]; then
         pass static 'timed %s: fastest %s ms' "$1" "$2"
       else
         fail static '%s\n         fastest of three was %s ms; the bound is 1000' "$1" "$2"
       fi ;;
  esac
}

# One helper for every library timing below. It prints "<ms> <exit>" for the
# fastest of three runs, leaves the last run's output in the named file, and
# cuts a run off at 20 s. The exit status is printed because a time with no
# verdict beside it would pass for a function that is not there: renamed away,
# a call fails in a few milliseconds at every size, and the first version of the
# scaling checks below reported that as linear. Found by review, not by this
# suite.
lib_run() {  # lib_run <input> <out> <call> -- "<ms> <exit>", fastest of three
  local i s e ms rc best= bestrc=
  for i in 1 2 3; do
    s=$(date +%s%N)
    timeout 20 bash -c ". '$HOOKS/lib/command-scan.sh' && $3" < "$1" > "$2" 2>/dev/null
    rc=$?
    e=$(date +%s%N)
    ms=$(( (e - s) / 1000000 ))
    if [ -z "$best" ] || [ "$ms" -lt "$best" ]; then best=$ms bestrc=$rc; fi
  done
  printf '%s %s\n' "$best" "$bestrc"
}
library_under_a_second() {  # library_under_a_second <label> <call> <out>
  local r
  r=$(lib_run "$LIB_LONG" "$3" "$2")
  if [ "${r#* }" != 0 ]; then
    fail static '%s\n         %s exited %s, so its time is not the time of the pass' "$1" "$2" "${r#* }"
  else
    under_a_second "$1" "${r% *}"
  fi
}

# WHERE THE `GH-` ENTRIES ARE, answered once (#200). They are not in
# requirements.md: each is a file of its own under requirements/ beside it, named
# by its ID, because every review loop appended to one section of one file and
# every pair of concurrent branches conflicted there. Every reader in this suite
# reads the union, and every one of them asks this function for the second half
# of it, so that there is one answer to which files and in which order.
#
# THE SPLIT SET IS FOUND BESIDE THE requirements.md IT IS GIVEN, never at a
# fixed path. That is what lets a fixture carry a split set of its own, and what
# makes a mutated copy under CHECK_HOOKS_DIR -- where mutate-hooks.sh edits a
# `GH-` file -- the one that is read, with no caller having to pass a second
# path and no caller able to forget to.
#
# VERSION ORDER ON THE ID, which is `sort -V`: numeric by issue and then by
# sub-ID, a bare `GH-<n>` before its `GH-<n>.1`, and `GH-108.10` after
# `GH-108.9`. The file system's order is the byte order of the names, which puts
# `GH-100` before `GH-43.1`, and the order the entries used to have was the
# order they were appended in -- neither is a stated sort. The matrix presents
# the entries in the order this prints them, and the #200 checks hold it to that.
#
# EVERY NAME IN THE DIRECTORY, not every `GH-*.md`, so that a file misnamed out
# of the pattern is read and found malformed rather than never read at all -- a
# narrower glob fails silent, in the permitting direction. Dotfiles are left
# out, because vim's swap file is one and is not an entry. An editor's backup
# that is not a dotfile -- emacs's `GH-5.md~` -- is read, and turns the suite red
# for as long as it is there, which is the failing direction and is taken.
#
# REGULAR FILES ONLY, AND THE REST NAMED BY requirements_split_other. A name
# that is not a regular file -- a directory, a dangling link -- was handed to
# awk with the rest, on the argument that the canonical reader reports a file
# it cannot read. Under mawk, which is the awk here and on the CI runner, it
# does not: `getline` on a directory aborts the program ("read error (Is a
# directory)"), so the suite went red with seven findings and none of them named
# the directory (rev-agent-200, round 4 of PR #210, measured on mawk 1.3.4). So
# no reader is given one, and the canonical reader names each one instead.
requirements_split() {  # requirements_split <requirements.md> -- the split set beside it, one path a line
  local dir
  dir="$(dirname -- "$1")/requirements"
  [ -d "$dir" ] || return 0
  # The path is printed here, by the shell, and never handed to `awk -v`, which
  # reads a backslash in it as an escape; requirements_read takes the list
  # through the environment for the same reason.
  #
  # Globbing on in the subshell, whatever the caller left it: this file turns it
  # off around its splits, and under `set -f` the `*` below is the one name `*`,
  # which is no file, so the split set would be read as empty. No caller does so
  # today (rev-agent-200 logged every call over a whole run: none under `-f`),
  # and that is a reason this has not bitten rather than a guard.
  ( set +f; cd -- "$dir" && for f in *; do
      [ -f "$f" ] && printf '%s\t%s\n' "${f%.md}" "$dir/$f"
    done ) | LC_ALL=C sort -t "$(printf '\t')" -k1,1V | cut -f2-
}

# A RANGE OF THE SUITE'S OWN TEXT, from one sed address to the next, into the
# named variable -- the way every check here reads part of this suite rather
# than all of it, beside $SUITE_TEXT, which is all of it. A range is read where
# a literal asserted of the whole text would match the check's own argument, so
# it is read from where the code it pins stands.
#
# IT FAILS ON A RANGE THAT MATCHED NOTHING. `sed -n '/a/,/b/p'` whose first
# address has moved prints nothing and exits 0, and what is asked of an empty
# range afterwards is mostly an absence, which an empty text satisfies. So the
# empty range is a FAIL here, whatever is asked of it next. It is called in the
# main shell and not inside $( ), so that the FAIL is recorded and counted.
suite_range() {  # suite_range <variable> <sed address> <sed address> -- 1 on an empty range
  printf -v "$1" '%s' "$(sed -n "$2,$3p" "$SUITE_TEXT" 2>/dev/null)"
  [ -n "${!1}" ] && return 0
  fail static 'the suite text from %s to %s is empty, so what is asked of it is asked of nothing' \
    "$2" "$3"
  return 1
}
# What sourcing <file> alone defines, with an empty environment, written to
# <out> as NUL-separated name/definition pairs by the program in $LOADED_CHILD;
# 1 if that is nothing. The head of check-hooks.sh records what it runs against
# this way, and the #204 section drives it: an exported function kept out, a
# file that defines nothing refused.
record_of() {  # record_of <file> <out> -- 1 if sourcing <file> alone defined nothing
  env -i PATH="$PATH" "$BASH" -c "$LOADED_CHILD" _ "$1" > "$2"
  [ -s "$2" ]
}

# THE SOURCING ROUTINE (#204). check-hooks.sh sources every file of checks/ but
# this one through it, once, in the order of one list the driver writes. It asks
# five things, failing the run on each, in this order. First, once: that every
# file under the directory is on the list or is this library, so an issue file
# added and not listed is a FAIL rather than a file whose checks never ran. Then
# for each file, which it opens by clearing REQ: that the file is there; that
# its last line is `sourced_to_end`; and, once it has recorded a start marker,
# sourced the file into this shell and cleared REQ again, that the file left the
# shell's options, working directory, umask and traps as it found them, and
# that it ran to its last line in this shell.
#
# REQ IS CLEARED AT EVERY FILE BOUNDARY, as `section` clears it at a heading:
# a file that ended inside a `req` would otherwise tag the first rows of the
# next one with requirements they do not establish (#212's class, closed here
# at the boundary only).
#
# THE END MARKER IS WRITTEN BY THE FILE, not by this routine: every file's last
# line is `sourced_to_end`. Bash returns from `.` the same way whether the file
# reached its end or ran a `return` halfway through it -- measured, bash 5.2:
# the status and everything after the `.` are the same -- so a marker written
# here after the `.` would say a file that returned early had run whole. The
# marker carries the line it was written from, and what is asked is that the
# last marker recorded is the file's own, written from its last line. A marker
# asked only for its presence would pass a file that wrote one early and then
# returned (round 1 of the review of PR #220). Counting the lines that read
# `sourced_to_end` would not close that: `sourced_to_end; return 0` is not such
# a line, and it returns early all the same. The line the call was made from is
# what the marker is meant to attest, so it is the thing asked. An `exit` ends the run before anything here can ask, so the driver's
# EXIT trap asks it (SUITE_EXIT_CODE). A file sourced outside this shell --
# inside a ( ) or a $( ) -- writes no marker, because `sourced_mark` writes only
# from $SOURCED_SHELL, the shell the driver runs in, as `record` does; so its
# checks, which would print and go uncounted, are a FAIL instead.
#
# The names it keeps are prefixed, because a file it sources shares them: a
# check file assigning `f` at its top level, as several do, would otherwise
# change which file this routine asks about next. What a file does to this
# routine's positional parameters it does to its own: `.` hands the file this
# function's, so a check file reads no `$1` at its top level. And a `declare`
# at a file's top level declares a variable local to this routine, not a global:
# the #106 section's `declare -A INV_DEP` and its three siblings are such, and
# they work because every reader of them runs inside this call. A variable
# read after the last file has run -- by the driver's verdict, say -- has to be
# declared in the driver or with `declare -g`.
source_checks() {  # source_checks <dir> <file>... -- source each file of <dir>, in order, into this shell
  local sc_dir=$1 sc_file
  shift
  [ -n "$SOURCED" ] || { sourcing_fail 'there is no sourcing record, so nothing can say what ran'; return 1; }
  while IFS= read -r sc_file; do
    case " $* $SUITE_LIBRARY " in *" $sc_file "*) continue ;; esac
    sourcing_fail '%s is under %s and on no list the driver sources, so no check in it runs' \
      "$sc_file" "$sc_dir"
  done < <(cd -- "$sc_dir" 2>/dev/null && find . ! -type d | sed 's|^\./||' | LC_ALL=C sort)
  for sc_file; do
    REQ=
    if [ ! -f "$sc_dir/$sc_file" ]; then
      sourcing_fail '%s is on the list the driver sources and is not a file in %s, so no check in it ran' \
        "$sc_file" "$sc_dir"
      continue
    fi
    [ "$(tail -n 1 -- "$sc_dir/$sc_file")" = sourced_to_end ] \
      || sourcing_fail '%s does not end with the line sourced_to_end, so nothing can say it ran to its end' \
           "$sc_file"
    shell_state "$SOURCED.before"
    sourced_mark start "$sc_dir/$sc_file"
    . "$sc_dir/$sc_file"
    REQ=
    shell_state "$SOURCED.after"
    cmp -s "$SOURCED.before" "$SOURCED.after" \
      || sourcing_fail '%s left the shell changed:\n%s' "$sc_file" \
           "$(diff "$SOURCED.before" "$SOURCED.after" | sed -n 's/^< /         was: /p; s/^> /         now: /p')"
    [ "$(tail -n 1 -- "$SOURCED" 2>/dev/null)" = "end $sc_dir/$sc_file $(sed -n '$=' -- "$sc_dir/$sc_file")" ] \
      || sourcing_fail '%s did not run to its last line in this shell: it returned early, or was sourced in a subshell, and the last marker recorded is not its end marker written from its last line' \
           "$sc_file"
  done
}
# A FAIL of the routine's, under its own requirement and no other, which it
# leaves untagged after -- the file after it opens untagged anyway.
sourcing_fail() {  # sourcing_fail <format> [arguments...]
  REQ=GH-204.6
  fail static "$@"
  REQ=
}
# What a file the routine sources must leave as it found it, a line each:
# every `set -o` and `shopt` option, the working directory, the umask and every
# trap. The driver's `trap ... EXIT` is in it before every file and after, so it
# is expected state and not a change. Written to a file by this shell, in a
# group and not through a $( ): a command substitution reads errexit as off
# whatever this shell has it set to (measured, bash 5.2; a ( ) subshell keeps
# it), so a `set -e` left behind would not show.
shell_state() {  # shell_state <out> -- `set +o`, `shopt -p`, the directory, the umask and `trap -p`
  { set +o; shopt -p; printf 'directory %s\n' "$PWD"; umask; trap -p; } > "$1"
}
# The sourcing record, $SOURCED: "start <file>" and "end <file> <line>", a line
# each, written from $SOURCED_SHELL and from no subshell of it.
sourced_mark() {  # sourced_mark <start|end> <file>
  [ -n "$SOURCED" ] && [ "$BASHPID" = "$SOURCED_SHELL" ] || return 0
  printf '%s %s\n' "$1" "$2" >> "$SOURCED"
}
# THE LAST LINE OF EVERY FILE source_checks SOURCES, and nothing else: the file
# that calls it, and the line it was called from, which is that file's last
# only if the file reached its end. BASH_LINENO[0] is the line in the sourced
# file, not in the driver (measured, bash 5.2).
sourced_to_end() {  # sourced_to_end -- the end marker of the file that calls it
  sourced_mark end "${BASH_SOURCE[1]} ${BASH_LINENO[0]}"
}

# EVERY SECTION HEADING HAS A ROW UNDER IT. `section` writes each heading down
# with the number of rows the ledger held when it was printed, and a heading
# the next one follows with no row recorded between them -- or that the ledger
# ends on -- is a heading of nothing. A `---` subheading is printed with `echo`
# and is not written down, so its rows count for the `===` heading above it.
heading_mark() {  # heading_mark <heading>
  [ -n "$HEADINGS" ] && [ -n "$LEDGER" ] && [ "$BASHPID" = "$$" ] || return 0
  printf '%s\t%s\n' "$(wc -l < "$LEDGER")" "$1" >> "$HEADINGS"
}
sections_without_rows() {  # sections_without_rows <headings record> <ledger> -- each heading with no row under it
  awk -F'\t' -v total="$(wc -l < "$2")" '
    { at[NR] = $1; name[NR] = $2 }
    END { for (i = 1; i <= NR; i++) if (((i < NR) ? at[i + 1] : total) == at[i]) print name[i] }' "$1"
}

# THE GENERATED ENTRIES (#205). A `GH-` entry outside the legacy set is declared
# by `requirement` in an issue file, and its file under requirements/ is written
# from that declaration by generate-requirements.sh. These two read the record
# the run kept of what it declared and pinned -- $DECLARED, a record per
# `requirement` call, `<ID> TAB <issue file> TAB <body>` ended by a NUL, and
# $PINNED, a line per `shape_pin` or `variants_pin` call, `<shape|variants> TAB
# <issue file> TAB <tokens>` -- and print what does not hold, a line each,
# sorted, and nothing when all of it does. Each is driven against a fixture in
# the #205 issue file, and against this repository at the end of the run.
#
# Each file is held to the declaration as BASH read it when the suite ran the
# issue file, not as the generator reads the text, so the generator's reading
# is not the expectation its output is held to; the generator's own check,
# beside this one, is where the two readings meet.
# The grammar of a generated entry's ID, for the two helpers below; the
# generator's awk spells it again, since it is a program of its own (#223). A
# function and not a variable, since the library defines functions and nothing
# else.
generated_id() {  # generated_id <ID> -- true when it is GH-<n> or GH-<n>.<m>
  local re='^GH-[1-9][0-9]*([.][1-9][0-9]*)?$'
  [[ $1 =~ $re ]]
}
generated_bad() {  # generated_bad <declared record> <requirements dir> <legacy literal>
  local - rec id file body want seen=' ' legacy f n
  set -f
  legacy=" $(printf '%s ' $3)"
  {
    while IFS= read -r -d '' rec; do
      id=${rec%%$'\t'*}; rec=${rec#*$'\t'}
      file=${rec%%$'\t'*}; body=${rec#*$'\t'}
      if ! generated_id "$id"; then
        printf '%s: declared in %s, and not an ID of the grammar GH-<n> or GH-<n>.<m>\n' "$id" "$file"; continue
      fi
      case "$seen" in *" $id "*) printf '%s: declared a second time, in %s\n' "$id" "$file"; continue ;; esac
      seen="$seen$id "
      case "$legacy" in *" $id "*) printf '%s: declared in %s, and a legacy entry, which stays hand-written\n' "$id" "$file"; continue ;; esac
      # An entry of #<n> is declared in #<n>'s issue file and in no other, which
      # is what "its issue file" means (review of PR #222, round 5).
      n=${id#GH-}; n=${n%%.*}
      if [[ $file != "checks/GH-$n.sh" ]]; then
        printf '%s: declared in %s, where an entry of #%s is declared in checks/GH-%s.sh\n' "$id" "$file" "$n" "$n"; continue
      fi
      want="### $id"$'\n'"$body- generated: $file"$'\n'
      # Compared with cmp and not in a command substitution, which drops a NUL:
      # a file with one inserted read as its declaration (review of PR #222,
      # round 5).
      if [ ! -f "$2/$id.md" ]; then
        printf 'requirements/%s.md: declared in %s, and not written\n' "$id" "$file"
      elif ! cmp -s -- "$2/$id.md" <(printf '%s' "$want"); then
        printf 'requirements/%s.md: not, byte for byte, its declaration in %s\n' "$id" "$file"
      fi
    done < "$1"
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      id=${f%.md}
      case "$legacy" in
        *" $id "*) grep -q '^- generated:' -- "$2/$f" \
                     && printf 'requirements/%s: a legacy entry carrying a generated field, which only a declared entry'"'"'s file carries\n' "$f" ;;
        *) case "$seen" in
             *" $id "*) ;;
             *) printf 'requirements/%s: outside the legacy set, and no issue file the suite ran declares it\n' "$f" ;;
           esac ;;
      esac
    done < <(set +f; cd -- "$2" 2>/dev/null && for f in GH-*.md; do [ -f "$f" ] && printf '%s\n' "$f"; done)
    for id in $3; do
      [ -f "$2/$id.md" ] || printf '%s: a legacy entry with no file, where an ID is never deleted\n' "$id"
    done
  } | LC_ALL=C sort
}
# What the pins get wrong: a generated entry in either shared literal, which is
# the hunk every loop edited until the pins (#211); a pin naming an entry no
# issue file declares, or one another issue file declares; an entry pinned twice
# of one kind; and a declared entry with no shape pin. Whether the pinned tokens
# are what the entries say is the comparison each shared literal already had,
# which the end of the run hands them to.
pins_bad() {  # pins_bad <declared record> <pinned record> <shape literal> <scope literal> <legacy literal>
  local - rec id file kind tok legacy
  local -A declared=() pinned=()
  set -f
  legacy=" $(printf '%s ' $5)"
  {
    # A declaration whose ID is out of grammar is skipped, since
    # `generated_bad` names it and no pin can make it right. The empty ID among
    # them has to be: made a subscript it is `bad array subscript`, which ends
    # this group before it has printed a line, so every finding below goes
    # unprinted and the run reads it as none.
    while IFS= read -r -d '' rec; do
      id=${rec%%$'\t'*}; rec=${rec#*$'\t'}
      generated_id "$id" || continue
      [[ -n ${declared[$id]+set} ]] || declared[$id]=${rec%%$'\t'*}
    done < "$1"
    for tok in $3; do
      id=${tok%%:*}
      [[ $id == GH-* && $legacy != *" $id "* ]] \
        && printf '%s: in REQUIREMENT_SHAPE, which holds the legacy entries; a generated entry'"'"'s shape is pinned in the issue file that declares it\n' "$id"
    done
    for tok in $4; do
      id=${tok%%:*}
      [[ $id == GH-* && $legacy != *" $id "* ]] \
        && printf '%s: in INV_SCOPE, which holds the legacy entries; a generated entry'"'"'s variants are pinned in the issue file that declares it\n' "$id"
    done
    while IFS=$'\t' read -r kind file rec; do
      for tok in $rec; do
        id=${tok%%:*}
        if [[ -z $id ]]; then
          printf '%s: a pin with no ID, in %s\n' "$tok" "$file"; continue
        fi
        if [[ -z ${declared[$id]+set} ]]; then
          printf '%s: its %s pinned in %s, and no issue file declares it\n' "$id" "$kind" "$file"
        elif [[ ${declared[$id]} != "$file" ]]; then
          printf '%s: its %s pinned in %s, and declared in %s, where its pin belongs\n' "$id" "$kind" "$file" "${declared[$id]}"
        fi
        if [[ -n ${pinned[$kind:$id]+set} ]]; then
          printf '%s: its %s pinned a second time, in %s\n' "$id" "$kind" "$file"
        fi
        pinned[$kind:$id]=1
      done
    done < "$2"
    for id in "${!declared[@]}"; do
      [[ $legacy == *" $id "* || -n ${pinned[shape:$id]+set} ]] \
        || printf '%s: declared in %s, and its shape pinned nowhere\n' "$id" "${declared[$id]}"
    done
  } | LC_ALL=C sort
}
# The tokens of a shape or scope literal whose ID is in the legacy set, or is
# not, sorted and a space after each: how the #141 comparison keeps to the
# legacy entries and the end of the run to the generated ones, since the
# derivation reads both.
legacy_tokens() {  # legacy_tokens <in|out> <legacy literal> <tokens>
  local - tok legacy
  set -f
  legacy=" $(printf '%s ' $2)"
  for tok in $3; do
    if [[ $legacy == *" ${tok%%:*} "* ]]; then
      [ "$1" = in ] && printf '%s\n' "$tok"
    else
      [ "$1" = out ] && printf '%s\n' "$tok"
    fi
  done | LC_ALL=C sort | tr '\n' ' '
}
# The directory generate-requirements.sh is run over when it is held to this
# suite: the issue files from the suite's side and requirements/ from the
# judged side, each a symbolic link. The script reads both out of one hooks
# directory, and the two sides are one directory until an override parts them.
# Under CHECK_HOOKS_DIR the issue files are the tooling, whose text is read off
# $SUITE_DIR and never off the copy, and they are what this run sourced and
# declared. Reading the copy's instead asks the copy for a checks/ directory
# the override guard does not require, and a copy without one turned the
# GH-205.2 row red for that reason alone (review of PR #222, round 3). Prints
# the directory.
generator_view() {  # generator_view <suite dir> <hooks dir> <into>
  rm -rf -- "$3" && mkdir -p -- "$3" \
    && ln -s -- "$1/checks" "$3/checks" && ln -s -- "$2/requirements" "$3/requirements" \
    && printf '%s' "$3"
}
# THE DECLARATION, as bash reads it (#205; here since #215's issue file became
# its second caller). The fields arrive on stdin from a quoted heredoc, so
# nothing in them is expanded, and they are recorded with the issue file that
# declared them -- the path under .claude/hooks/, which is what the `generated`
# field of the file names. BASH_SOURCE[1] is the file the call was made from,
# wherever this function is defined. Nothing is judged here: an ID out of
# grammar or declared twice is recorded all the same, and the end of the run
# says so, with its tag, where a `fail` here would carry whatever tag stood
# before the declaration.
requirement() {  # requirement <ID> -- declare a generated GH- entry; its fields on stdin
  local body=
  # A call with no heredoc would read the terminal and wait; it records an
  # empty body instead, which the end of the run reports as not its file.
  [ -t 0 ] || IFS= read -r -d '' body
  printf '%s\t%s\t%s\0' "$*" "${BASH_SOURCE[1]#"$SUITE_DIR"/}" "$body" >> "$DECLARED"
}
# THE PINS, #211's decision: the second copy of an entry's shape, and of its
# variants keyword when it is in the invariance families' scope, written in the
# issue file that declares it rather than in REQUIREMENT_SHAPE and INV_SCOPE,
# which every loop used to edit. The tokens are those literals' own,
# `<ID>[:<keyword>]`, and are recorded one line per call, whitespace folded.
# `variants_pin`, its twin for the variants keyword, is in the #205 issue file
# while that file is its one caller.
shape_pin() {  # shape_pin '<ID>[:<shape>]...' -- the shape of entries this issue file declares
  local -
  set -f
  printf 'shape\t%s\t%s\n' "${BASH_SOURCE[1]#"$SUITE_DIR"/}" "$(printf '%s ' $*)" >> "$PINNED"
}
# THE READER OF A HEADER'S PROSE (#183's, a function since #215's issue file
# became its second caller). Comment lines on stdin, one line of prose out: the
# `#` and up to three blanks after it taken off each line, the lines joined, and
# every run of spaces squeezed to one. A pin on hand-wrapped prose reads this and
# not the file, because a phrase crosses a line break wherever the wrap falls;
# and it reads it through this one function, because a second copy of the
# reader is a second rule of what rewrapping may do. #215's first reader took
# `# ?` off and squeezed nothing, so a trailing blank or a deeper indent turned
# its pins red where $MUT_PROSE's stayed green; review of #215's pull request
# measured both.
#
# A WORD BROKEN AT A HYPHEN IS REJOINED. A line that ends in a letter or digit
# and a hyphen, blanks after it allowed, is joined to the next with no blank,
# so `2026-09-` over `26` reads as a date and `byte-` over `identical` as one
# word; the join with a blank split both, a record written that way passed
# GH-215's counts, and a rewrap that broke `DEV-LOG` turned its paragraph pin
# red (review of #215's pull request, fourth round). Only at a line's end, so a
# hyphen followed by a blank inside a line stays as written; and not after a
# hyphen, so ` --` ending a line is still a dash. The trade: a suspended hyphen
# at a line's end, `pre-` over `and post-`, reads as `pre-and`. None stood in
# the harness's header when this was written.
comment_reflow() {  # comment_reflow -- comment lines on stdin, their prose on one line out
  sed -e 's/^#[ \t]\{0,3\}//' \
    | sed -e ':a' -e '/[[:alnum:]]-[ \t]*$/{N;s/-[ \t]*\n[ \t]*/-/;ba' -e '}' \
    | tr '\n' ' ' | tr -s ' '
}

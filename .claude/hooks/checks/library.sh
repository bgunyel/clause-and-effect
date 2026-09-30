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
# -- $LEDGER, $REQ, $RAN, $HOOKS, $FIXTURES, $SUITE_DIR, $SUITE_DECLARED,
# $SUITE_PINNED and the fixtures' own -- are set by check-hooks.sh, before the
# call that reads them; and $STDERR_WRITE, which `arms` and `fn_writes` read, by the unsplit
# file's #109 section, which is sourced before any issue file that calls them.
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
# A FAIL LINE MARKS ITS OWN DETAIL (#224). Every line of the message after the
# first is printed with `indent`, seven spaces, the width of `  FAIL `,
# whatever the line already starts with: a line at column 0 gets them, one that
# opens with spaces gets them added to its own, and a blank line is printed as
# the seven spaces alone. A message embeds a hook's stderr verbatim, and before
# #224 a line of it stood wherever the hook put it, so the log did not say which
# lines were a row's. The `check-hooks` job summary guessed, and took a
# library's stray stderr at column 0 as the detail of the failing row above it,
# and cut a stderr short at a blank line or at one opening `---`.
# .github/scripts/check_hooks_ci.py takes a failing row's detail by these seven
# spaces, as DETAIL_INDENT, and tests/test_check_hooks_ci.py runs this function
# into that parser, so the two spellings cannot drift apart with the tests
# green. The ledger records the first line, which the indent never reaches.
#
# LINEAR IN THE MESSAGE, AND WHY NO LINE OF IT IS CUT BY A PATTERN (#293). The
# indent was first written as `${line//$'\n'/$'\n'$indent}`, and under a UTF-8
# locale bash's substitution grows with the square of the message: one `fail`
# over a 10,000-line message of 580 KB took 6.8 s, against 0.06 s before #224.
# The second form cut the first line off with `${line%%$'\n'*}` and the rest
# with `${line#*$'\n'}`, and both strips grow with the square of the FIRST
# line, however few lines follow it: 887 ms of CPU for a 40,000-byte first
# line, against 55 ms at 10,000 (review of PR #285, round 3). So the whole
# message is read into an array by `mapfile`, element 0 is the first line and
# the rest are given the indent, which is linear in both shapes: 13 ms for a
# 40,000-byte first line and 15 ms at 160,000; 70 ms for 10,000 lines of 58
# bytes and 299 ms for 40,000. The here-string adds one newline and
# `mapfile -t` takes one off, so a message ending in a newline still ends in an
# indent-only line, and an empty message is one empty element, printed as
# `  FAIL ` alone, as the substitution printed both. `record`'s own tab
# substitution is #300's.
fail() {  # fail <refuse|permit|static> <format> [arguments...] -- a FAIL line, recorded
  local dir="$1" fmt="$2" line first indent='       '
  local -a rest
  shift 2
  printf -v line "$fmt" "$@"
  mapfile -t rest <<< "$line"
  first=${rest[0]}
  unset 'rest[0]'
  printf '  FAIL %s\n' "$first"
  if (( ${#rest[@]} )); then
    printf '%s\n' "${rest[@]/#/$indent}"
  fi
  FAILED=1
  record "$dir" FAIL "$first"
}
req() {  # req <ID>... -- the requirements the checks after this establish
  # Joined on a space whatever IFS the caller has: "$*" joins on its first
  # character, and a tag list joined on a colon is one tag no entry has (#223).
  local IFS=' '
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
# and so is only ever run as a copy placed in a fixture directory: `report_says`
# records a copy as the report only when `cmp -s` finds it byte-identical to
# $HOOKS/report-stale-branches.sh, so a modified copy is not recorded, under
# the report's name or any other (#187; until then the name was the whole
# test). `anc_report` runs a copy too and records nothing; see there for why.
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
# the check whatever it expected. The helpers that read a message -- `says` and
# its siblings, `feed_says` and `env_says` -- ask only for 2, because
# every one of their claims is about a refusal.
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
# The fourth: a refusal that is <message> and nothing else, compared for
# equality. `says`, `says_first` and `says_not` ask about a fragment, and no
# pair of them can say "nothing else": #164's first version pinned a message as
# `says_first` on it plus `says_not` on it with a space after, and a second
# `echo >&2` after the arm's own -- a newline, not a space -- passed both,
# carrying a push remedy back into the message those rows called whole. Found
# by review of PR #291, with that mutant. Hook stderr captured through $( )
# loses its trailing newlines and nothing else, so equality needs no allowance.
says_exactly() {  # says_exactly <dir> <script|/absolute/hook> <message> <label> <cmd>
  local dir="$1" script="$2" want="$3" label="$4" cmd="$5" err rc hook
  hook=$(hook_path "$script")
  err=$(printf '%s' "$cmd" | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' \
        | ( cd "$dir" && "$hook" ) 2>&1 >/dev/null)
  rc=$?
  ran "$script" "$rc"
  if [ "$rc" != 2 ]; then
    fail refuse '%s\n         wanted a refusal saying exactly |%s|, got exit=%s\n         stderr |%s|' \
      "$label" "$want" "$rc" "$err"
    return
  fi
  case "$err" in
    "$want") pass refuse 'says  %s' "$label" ;;
    "$want"*) fail refuse '%s\n         the refusal says |%s| and then more\n         it said |%s|' \
         "$label" "$want" "$err" ;;
    *) fail refuse '%s\n         wanted the refusal to say exactly |%s|\n         it said |%s|' \
         "$label" "$want" "$err" ;;
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
#
# A COUNT ONLY FROM A FILE THAT WAS READ, for the reason `unarmed` gives below
# (#219). On a directory grep prints `0` and exits 2, so a `tok ... '0'` over
# this read an unread directory as a phrase said nowhere. So grep's status is
# asked: 0 and 1 are counts -- `grep -c` exits 1 when the count is zero, and
# that `0` is a real one -- and any other status prints a line naming it and
# the file, which no count equals. On a zero-byte file grep prints `0` and
# exits 1, and that `0` is a real count too, for the reason `unarmed` gives for
# passing one (#256).
prose_count() {  # prose_count <file> <literal> -- how many lines say it
  local n grep_status
  n=$(grep -cF -- "$2" "$1" 2>/dev/null)
  grep_status=$?
  case $grep_status in
    0|1) printf '%s\n' "$n" ;;
    *) printf 'unread: grep exited %s on %s\n' "$grep_status" "$1" ;;
  esac
}

written() {  # written <label> <file> <literal> -- the file as written, # and all
  absolute_or_fail "$1" "$2" || return
  if grep -qF -- "$3" "$2" 2>/dev/null; then
    pass static 'written %s' "$1"
  else
    fail static '%s\n         expected %s to still say |%s|' "$1" "$2" "$3"
  fi
}

# The absence has to be an absence IN a file that was read, so grep's exit
# status is what decides: 0 is the literal found, 1 is the file read and the
# literal not in it, and anything else is a file grep could not read, which
# fails and names the status and the file. Only 1 passes.
#
# AND 1 PASSES ON A ZERO-BYTE FILE, deliberately (#256). An empty file is read,
# and nothing is in it, so the absence is true; a `[ -s ]` question after the
# status would refuse that true absence. What it tells apart is a file with
# bytes from one without -- grep exits 1 on both when the literal is not there
# -- and whether a file has bytes is not what an absence pin asks (review of
# #256's branch). A file emptied by a failed write is a presence question, and
# a pin that must not read a truncation as evidence pairs its `unarmed` with a
# presence check. `lacks` is handed text and not a file, which is why it
# refuses an empty one and this does not.
#
# THE PRESENCE CHECKS, listed here and pointed to from elsewhere, so the list
# is written once: over a file, an `armed` or a `written` over the same file,
# which goes red, or a fixture guard that stops the suite when the file does
# not say what it must -- the report fixture's in unsplit.sh, ahead of its
# `unarmed` pins, is one; over text, a `holds` over the same text.
#
# It was an `else` after the grep, and that is the defect twice over. First a
# file that is not there: grep exits 2, which fell into the else arm and
# reported ok -- so every pin below would have passed for a file renamed or
# deleted away, which is the permitting direction and the same shape as the
# #84 defect these were added for. Found by review of that change, not by this
# suite. Its fix was a `[ ! -r ]` arm in front of the grep, and `[ -r ]` is
# true of a directory: grep exits 2 on one, `Is a directory`, the else arm
# read that as absent too, and a pin aimed at `$HOOKS/lib`, or at a directory
# spelled with a trailing `/`, printed ok having read nothing (#219, found by
# review of PR #216). So there is no readability test in front of the grep now:
# a test is a guess at what grep will manage, and the status is what it did.
#
# THE STATUS IS grep_status AND NOT rc, here and in `prose_count`, because the
# #98 self-test derives its list of hook-status readers from `rc=$?` and would
# then ask to drive these two against hooks that crash. They run no hook; what
# they read is grep's status, and #219's issue file drives them against a
# directory, a file that is not there and a readable file instead.
unarmed() {  # unarmed <label> <file> <literal>
  absolute_or_fail "$1" "$2" || return
  local grep_status
  grep -qF -- "$3" "$2" 2>/dev/null
  grep_status=$?
  case $grep_status in
    0) fail static '%s\n         %s must not contain |%s|' "$1" "$2" "$3" ;;
    1) pass static 'armed %s' "$1" ;;
    *) fail static '%s\n         grep exited %s on %s, so it was not read and the absence of |%s| is evidence of nothing' \
         "$1" "$grep_status" "$2" "$3" ;;
  esac
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
# A lifecycle repository for the #108 dev-ref fixtures: a stale worktree branch
# at base and a merged one whose upstream is gone, under the origin/dev-NN refs
# given, each at base or at the tip. The unsplit file's #108 section says why
# the refs are placed so; here since #144's issue file built a fixture with it.
env_lifecycle() {  # env_lifecycle <dir> <ref at base>... -- with <ref at tip> last
  local dir="$1" base tip r
  git init -q -b main "$dir"
  git -C "$dir" remote add origin "$FIXTURES/unreachable-remote.git"
  git -C "$dir" $GE commit -q --allow-empty -m base
  base=$(git -C "$dir" rev-parse HEAD)
  git -C "$dir" $GE commit -q --allow-empty -m advance
  tip=$(git -C "$dir" rev-parse HEAD)
  shift
  for r in "$@"; do
    case "$r" in
      *:tip) git -C "$dir" update-ref "refs/remotes/origin/${r%:tip}" "$tip" ;;
      *) git -C "$dir" update-ref "refs/remotes/origin/${r%:base}" "$base" ;;
    esac
  done
  # ahead == 0, behind == 1 against any ref at the tip: the fallback detector's case.
  git -C "$dir" branch stale-branch "$base"
  git -C "$dir" worktree add -q "$dir/wt-stale" stale-branch
  # upstream configured, remote-tracking ref absent: the gone detector's case,
  # placed at the tip so the fallback cannot fire here and a refusal is the gone
  # detector's alone.
  git -C "$dir" branch gone-branch "$tip"
  git -C "$dir" config -f "$dir/.git/config" branch.gone-branch.remote origin
  git -C "$dir" config -f "$dir/.git/config" branch.gone-branch.merge refs/heads/gone-branch
  git -C "$dir" worktree add -q "$dir/wt-gone" gone-branch
}
# Here since #144's issue file became its second caller, beside the one it
# delegates to; a command where env_feed takes raw stdin.
env_cmd() {  # env_cmd <dir> <PATH> <script|/absolute/hook> <ALLOW|BLOCK> <label> <command>
  local dir="$1" path="$2" script="$3" want="$4" label="$5" cmd="$6"
  env_feed "$dir" "$path" "$script" "$want" "$label" \
    "$(printf '%s' "$cmd" | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}')"
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
  # Recorded after the run, and under the registered name, since this helper
  # runs the script itself and does not call `hook_path`. See `ran`.
  #
  # THE BYTES ARE THE TEST, and not the name (#187). `ran` refuses an absolute
  # path because a fixture copy is not the registered hook; this steps around
  # that rule only for a script `cmp -s` finds byte-identical to
  # $HOOKS/report-stale-branches.sh. Until #187 the name alone was the test, on
  # an invariant nothing enforced; checks/GH-187.sh says what that cost, and why
  # no name test is kept beside the bytes.
  cmp -s "$script" "$HOOKS/report-stale-branches.sh" && ran report-stale-branches.sh "$rc"
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
# that order -- in #109's section the Bash hooks settings.json registers, and in
# the self-tests of #98 and #186 their fixtures -- and a pass only if the list
# names at least one and every one exits exactly 0, which is how the harness
# decides whether a command runs at all. Every helper above runs one hook; this is the
# one question none of them can ask. The #98 self-test drives it, and runs before
# #109's section does, which is why it was defined with the others.
#
# The failure line names every hook that did not exit 0, each with its status and
# its stderr in the spelling `verdict` uses, since the case it exists for is a
# second hook refusing what the first permits and the name is the whole finding.
# IT FAILS WHEN IT RUNS NO HOOK, which is #186. Without that, a list the loop
# consumed nothing from would leave `refused` empty and print `ok ALLOW by all`
# for a command no hook had judged -- recording permit-direction coverage for
# six requirements on nothing. The count is of the names the loop consumed and
# not a test of the string, because a list of blanks, whether spaces, tabs or
# newlines, is not empty and gives the loop no name all the same, which #186's
# triage measured. A name that is no hook is counted, and fails on its exit
# status instead, 127 for a path that is not there. It is a failing verdict and
# not an abort: one caller's empty list is that check's defect, not the run's.
# And it is in here, the consumer, because the guard that first answered it
# stood beside one producer, the derivation that reads settings.json, while
# `drive_helper` and `every_hook_of` set `XH_HOOKS` from elsewhere -- the first
# review of PR #169's finding at a second call site, filed by the sixth. That
# guard stays, naming its own cause.
every_hook() {  # every_hook <dir> <label> <cmd> -- permit, by every hook in $XH_HOOKS, of at least one
  local - dir="$1" label="$2" cmd="$3" hook rc err refused= runs=0 IFS=$' \t\n'
  # The list split on blanks, and not globbed, whatever the caller left (#223).
  set -f
  for hook in $XH_HOOKS; do
    runs=$((runs + 1))
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
  if [ "$runs" = 0 ]; then
    fail permit '%s\n         no hooks to run it through' "$label"
  elif [ -z "$refused" ]; then
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
# The absence has to be an absence in something that was read -- the rule
# `unarmed` applies too, asked of different evidence (#256). `lacks` is handed a
# STRING, and a read that failed or was deleted prints an empty line, which is
# also what an empty file reads as: once they are text the two cannot be told
# apart, so an empty string is refused as nothing read. `unarmed` and
# `prose_count` are handed a PATH, and grep's status already tells an unread
# file (2) from a read one with nothing in it (1), so an empty FILE is a read
# file there and its absences are real ones. A truncated file is a presence
# question, for the presence checks `unarmed`'s header lists.
# `prose_occurrences` is handed a path and still takes this side, because it
# reads through `prose`, which writes nothing for a reflow with no word in it,
# so grep finds no file and it prints `unread`.
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
# <out> as NUL-separated name/definition pairs by `record_dump` below, from
# the listings the program in $LOADED_CHILD dumps beside <out>, and the status
# sourcing returned, which the child writes to <out>.sourced. 1 if it defined
# nothing; 2 if the child did not finish -- it wrote no status, as a file that
# runs `exit` leaves it, or it exited non-zero, was killed, or dumped
# something `record_dump` refuses -- and <out> is then left empty; 3 if
# sourcing returned non-zero and still defined something.
# Why, in words, on stdout, for 2 and 3, and for 1 when sourcing returned
# non-zero. The three are apart because the head treats them apart (#279): see
# `record_loaded` below. The #204 section drives it with an exported function
# kept out and a file that defines nothing refused, and #279's issue file with
# each of the other outcomes.
record_of() {  # record_of <file> <out> -- 1 defined nothing, 2 the child did not finish, 3 sourcing returned non-zero; why on stdout
  local child_status sourced why
  : > "$2"
  env -i PATH="$PATH" "$BASH" -c "$LOADED_CHILD" _ "$1" > /dev/null 3> "$2.sourced" 4> "$2.before" \
    5> "$2.names" 6> "$2.functions" 7> "$2.variables"
  child_status=$?
  sourced=$(< "$2.sourced")
  if [ -z "$sourced" ]; then
    printf 'the child that records it wrote no status for it: it ended before sourcing it returned, or could not write one'
    return 2
  elif [ "$child_status" != 0 ]; then
    printf 'the child that records it exited %s' "$child_status"
    return 2
  elif [[ ! $sourced =~ ^[0-9]+$ ]]; then
    printf 'the child that records it wrote a status that is not one'
    return 2
  elif ! why=$(record_dump "$2"); then
    rm -f -- "$2.part"
    printf 'the dump of its %s is not whole, or holds text the child did not write there' "$why"
    return 2
  elif [ "$sourced" != 0 ]; then
    printf 'sourcing it returned %s' "$sourced"
    [ -s "$2" ] || return 1
    return 3
  fi
  [ -s "$2" ]
}
# Whether the last line of one function of the dump closes it: `}`, or `}`
# and the redirections the function was written with, `} > /dev/null`, as
# `declare -f` prints them (round 4 of the review of PR #330, which measured
# the first version refusing both).
record_closed() {  # record_closed <chunk> -- 0 when its last line closes a function
  local last=${1##*$'\n'}
  [[ $1 == *$'\n'* ]] && [[ $last == '}' || $last == '} '?* ]]
}
# One function of the dump, cut at its header, written to <out>.part unless
# the child started with it; 1 when it does not end on its closing line.
record_chunk() {  # record_chunk <out> <name> <chunk> <started-with> -- 1 when <chunk> is not closed
  record_closed "$3" || return 1
  [ -n "$4" ] || printf '%s\0%s\0' "$2" "$3" >> "$1.part"
}
# THE RECORD, MADE IN THIS SHELL FROM WHAT THE CHILD DUMPED (#279, round 3 of
# the review of PR #330). The child does no more after the source than write
# bash's own listings, each to a descriptor of its own, so that nothing the
# file left in its shell has a program to act on; the reading is done here,
# where the file never ran. Every line of every dump has to be accounted for,
# or the record is not made and <out> is left empty: the names the child
# started with are the same two listings, each ended by `e:`; each function name is a line `declare -f<flags>
# <name>`; the functions are cut at each name's header, `<name> () `, in the
# order the names came, and each has to end on its closing line, `}` or `}`
# and its redirections, which a line `declare -f<flags> <name>` may follow for
# the function it closes; and each variable is a line `declare -<flags>
# <name>[=<value>]`, one a line because bash quotes a newline in a value,
# ending in `e:`. So text the file got into a dump that is not in bash's shape
# is refused rather than read as a name; a line in bash's shape is read as
# bash's, which is the forgery limit the driver names beside $LOADED_CHILD.
# Written to <out> as the child before this wrote it: `<name>` and `$<name>`,
# each with its definition, NUL after each; a name the child started with,
# `_` and `BASH_*` left out. What it does not reach, named: a function whose
# body holds a heredoc line that is the next function's header and a `}` line
# before it, which cuts there; and a variable whose value holds a newline,
# should a bash print one unquoted. Prints which dump, and returns 1, when one
# is not whole, and then leaves <out> as it found it: the record is written to
# <out>.part and moved over <out> only once every dump has been read.
record_dump() {  # record_dump <out> -- <out> from the dumps the child wrote beside it; 1 and which dump on stdout when one is not whole
  local line name chunk listing=functions k=-1 fn_re='^declare -f[a-z]* (.+)$' trailer_re='^declare -f[a-z]+ (.+)$' var_re='^declare -[a-zA-Z-]+ ([A-Za-z_][A-Za-z0-9_]*)(=|$)'
  local -a lines=() names=()
  local -A was_f=() was_v=()
  : > "$1.part"
  mapfile -t lines < "$1.before"
  [ "${#lines[@]}" -gt 0 ] && [ "${lines[-1]}" = e: ] || { printf 'starting names'; return 1; }
  unset 'lines[-1]'
  for line in "${lines[@]}"; do
    if [ "$listing" = variables ]; then
      [[ $line =~ $var_re ]] || { printf 'starting names'; return 1; }
      was_v[${BASH_REMATCH[1]}]=1
    elif [ "$line" = e: ]; then
      listing=variables
    else
      [[ $line =~ $fn_re ]] || { printf 'starting names'; return 1; }
      was_f[${BASH_REMATCH[1]}]=1
    fi
  done
  [ "$listing" = variables ] || { printf 'starting names'; return 1; }
  mapfile -t lines < "$1.names"
  for line in "${lines[@]}"; do
    [[ $line =~ $fn_re ]] || { printf 'function names'; return 1; }
    names+=("${BASH_REMATCH[1]}")
  done
  mapfile -t lines < "$1.functions"
  for line in "${lines[@]}"; do
    if [ $((k + 1)) -lt "${#names[@]}" ] && [ "$line" = "${names[k + 1]} () " ]; then
      if [ "$k" -ge 0 ]; then
        record_chunk "$1" "${names[k]}" "$chunk" "${was_f[${names[k]}]-}" || { printf 'functions'; return 1; }
      fi
      k=$((k + 1))
      chunk=$line
    elif [ "$k" -lt 0 ]; then
      printf 'functions'; return 1
    elif [[ $line =~ $trailer_re && ${BASH_REMATCH[1]} == "${names[k]}" ]] && record_closed "$chunk"; then
      continue
    else
      chunk+=$'\n'$line
    fi
  done
  [ $((k + 1)) = "${#names[@]}" ] || { printf 'functions'; return 1; }
  if [ "$k" -ge 0 ]; then
    record_chunk "$1" "${names[k]}" "$chunk" "${was_f[${names[k]}]-}" || { printf 'functions'; return 1; }
  fi
  mapfile -t lines < "$1.variables"
  [ "${#lines[@]}" -gt 0 ] && [ "${lines[-1]}" = e: ] || { printf 'variables'; return 1; }
  unset 'lines[-1]'
  for line in "${lines[@]}"; do
    [[ $line =~ $var_re ]] || { printf 'variables'; return 1; }
    name=${BASH_REMATCH[1]}
    [[ -n ${was_v[$name]-} || $name == BASH_* || $name == _ ]] && continue
    printf '$%s\0%s\0' "$name" "${line#declare -* }" >> "$1.part"
  done
  mv -f -- "$1.part" "$1"
}
# THE HEAD'S RECORD OF ONE FILE (#279): `record_of`, and what the head does
# with each outcome. A file whose sourcing defined nothing gives the foot
# nothing to compare, so it stops the run, as `052cc89` decided, saying why --
# the status too, when sourcing returned non-zero. Any other outcome is
# recorded as it stands and the run goes on: a file that sourced non-zero, or
# a child that did not finish, is a FAIL row here, under GH-279.1, naming the
# file and why, and not an abort. A file that sourced non-zero leaves a whole
# record, which is compared; a child that did not finish leaves none, so
# nothing of that file is compared at the foot. The row says which, and it
# fails the run (round 4 of the review of PR #330, which found the one text
# the two shared saying the second was compared in part). Written to LOADED_BODY and LOADED_FROM,
# which the driver declares, and the outcome to LOADED_STATUS, keyed by the
# file, so that a check can read what the head found rather than record the
# file again (round 1 of the review of PR #330). The FAIL row is tagged through
# a `local` REQ, so a caller's tag is the same after it as before. Called by
# the driver's prelude, and by #279's issue file in a subshell of its own for
# each outcome.
record_loaded() {  # record_loaded <file> <out> -- record it into LOADED_BODY, LOADED_FROM and LOADED_STATUS; 1 if it defined nothing
  local why record_status k v
  why=$(record_of "$1" "$2")
  record_status=$?
  case $record_status in
    0) ;;
    1) printf 'sourcing %s alone defined nothing%s, so nothing of it can be compared at the foot; nothing was judged\n' \
         "$1" "${why:+ ($why)}" >&2
       return 1 ;;
    3) local REQ=GH-279.1
       fail static 'the record of %s is whole, but %s; what it defined is compared at the foot' \
         "$1" "$why" ;;
    *) local REQ=GH-279.1
       fail static 'the record of %s was not made: %s; nothing of it is compared at the foot' \
         "$1" "$why" ;;
  esac
  LOADED_STATUS[$1]=$record_status
  while IFS= read -r -d '' k && IFS= read -r -d '' v; do
    LOADED_BODY[$k]=$v
    LOADED_FROM[$k]=$1
  done < "$2"
}

# THE ROWS THAT END THE LEDGER (#279). The end-of-run file's last check before
# the matrix asks that the ledger ends on the heading question's row and on a
# row for each clause of the final verdict that writes one, each under its own
# tags and its own label. That was `tail -n 4` and a literal of four tags with
# one label, so a verdict row replaced by another of the same tag read green,
# and so did a clause added to the verdict with no row. So the rows are derived
# from the verdict code the driver ends on: every evaluation of a
# `<NAME>_VERDICT_CODE` on a line of the driver that is not a comment, braces
# or none, in order, and for each the clauses of that code. The names are read
# off the driver's text and the code off this shell, `${!name}`: the two are
# one only because the driver defines each verdict's code before it takes it,
# and a fixture that hands in another driver's text is asking about this
# shell's code under that driver's names.
#
# WHICH CLAUSES WRITE A ROW is the one thing written here and not derived, and
# it is written as the table below, keyed by the clause's condition as the
# verdict code spells it. FOOT_VERDICT_CODE writes one row per clause, in
# clause order: the end-of-run file asks the same condition just before, as a
# row. SOURCED_VERDICT_CODE writes none to the tail: its row is the driver's,
# after the last file, and it prints only when it fails, so a green run has no
# such row at all. LEDGER_VERDICT_CODE writes none by design: it reads the
# rows, and there is no question of its own a row could answer. Each of those
# two is held to the one clause it has. A verdict variable the table does not
# know, a clause it does not know, and a line of FOOT_VERDICT_CODE naming
# FAILED beyond one per clause of the `if <condition>; then` form are each a
# line in place of a row, which no ledger ends on, so the check goes red until
# the table says what the new clause writes. A clause is counted by the lines
# that name FAILED, however the assignment is spelt -- `FAILED=1`,
# `(( FAILED = 1 ))`, `let` or `printf -v` -- because counting `FAILED=` let
# the others by (review of #279's first round). What it does not see, named: a
# clause that sets the failure without naming FAILED on its line, through
# another variable or text it evaluates.
verdict_tail_want() {  # verdict_tail_want <driver> -- "<tags> TAB <label>" of each row the ledger ends on, or a line for what has none
  local name code cond clauses
  printf 'GH-204.8\t%s\n' 'every heading section wrote down has at least one row under it'
  for name in $(grep -v '^[[:space:]]*#' "$1" | grep -oE 'eval "\$\{?[A-Za-z0-9_]+_VERDICT_CODE\}?"' \
                 | sed -E 's/^eval "\$\{?([A-Za-z0-9_]+)\}?"$/\1/'); do
    code=${!name}
    clauses=$(grep -c 'FAILED' <<< "$code")
    case $name in
      SOURCED_VERDICT_CODE|LEDGER_VERDICT_CODE)
        [ "$clauses" = 1 ] \
          || printf '%s names FAILED on %s lines, and one clause is all it is known to write no row for\n' "$name" "$clauses"
        continue ;;
      FOOT_VERDICT_CODE) ;;
      *) printf '%s is taken at the end of the driver, and which rows it writes is not known\n' "$name"
         continue ;;
    esac
    [ "$clauses" = "$(grep -c '^if .*; then$' <<< "$code")" ] \
      || printf '%s names FAILED on %s lines, and not each in a clause of its own\n' "$name" "$clauses"
    while IFS= read -r cond; do
      case $cond in
        '[[ -n $LOADED_CHANGED ]]')
          printf 'GH-204.1\t%s\n' 'every function and tokeniser variable this run started with is the one it ended with' ;;
        '[[ -s $NOT_FOUND ]]')
          printf 'GH-204.5\t%s\n' 'no command this suite called was missing, in this shell or in any subshell of it' ;;
        '[[ $NOT_FOUND != "$NOT_FOUND_AT_HEAD" ]]')
          printf 'GH-204.5\t%s\n' 'the not-found record is where the head put it, so what the handler wrote is what the verdict reads' ;;
        *) printf '%s has a clause with no row known for it: if %s\n' "$name" "$cond" ;;
      esac
    done < <(sed -n 's/^if \(.*\); then$/\1/p' <<< "$code")
  done
}
verdict_tail_read() {  # verdict_tail_read <driver> <ledger> -- nothing when the ledger ends on the rows derived, else both
  local want got
  want=$(verdict_tail_want "$1")
  got=$(tail -n "$(printf '%s\n' "$want" | wc -l)" "$2" | cut -f1,4)
  [ "$want" = "$got" ] || printf 'derived:\n%s\nthe ledger ends:\n%s' "$want" "$got"
}

# THE VERDICT FIXTURES, ENUMERATED BY WHERE THEY STAND (#279). The rows that
# drive the final verdict's code are read back from the ledger with their tags,
# because a row under the wrong `req` covers the wrong requirement and nothing
# else says so. The read chose them by label -- a label beginning `the final
# verdict `, or `and says why on stderr` -- so a fixture row with any other
# label was never read; and it ran before GH-204.7's fixtures, so theirs were
# never read either. Now each block of them is opened with
# `verdict_fixtures begin` and closed with `verdict_fixtures end`, which write
# down how many rows the ledger held, and every row between the two is read,
# whatever it says; the end-of-run file reads them once every block has run.
# A mark written from a subshell is not written, as a row printed there is not
# recorded. A fixture evaluated outside any block is what this cannot see by
# itself, so `verdict_evals_outside` reads the check files for one.
verdict_fixtures() {  # verdict_fixtures <begin|end> -- write down where a block of verdict fixtures begins or ends
  [ -n "$VERDICT_MARKS" ] && [ -n "$LEDGER" ] && [ "$BASHPID" = "$$" ] || return 0
  printf '%s\t%s\t%s\n' "$1" "$(wc -l < "$LEDGER")" "${BASH_SOURCE[1]#"$SUITE_DIR"/}" >> "$VERDICT_MARKS"
}
# Each row inside a block, as `<tags> | <label>`, and a line for a mark out of
# place: an `end` with no `begin` open in its file, a `begin` inside a block,
# and a block never ended.
verdict_fixture_rows() {  # verdict_fixture_rows <marks> <ledger> -- each row inside a block, and a line for each mark out of place
  awk -F'\t' '
    FILENAME == ARGV[1] {
      if ($1 == "begin" && open == "") { open = $3; from = $2 }
      else if ($1 == "end" && open == $3) { for (i = from + 1; i <= $2; i++) row[i] = 1; open = "" }
      else printf "a %s mark in %s out of place, after row %s\n", $1, $3, $2
      next
    }
    FNR in row { print $1 " | " $4 }
    END { if (open != "") printf "a block begun in %s after row %s and never ended\n", open, from }' "$1" "$2"
}
# Every line of the named files that evaluates a verdict's code -- `eval
# "$<NAME>_VERDICT_CODE"`, braces or none -- outside a block, as <file>:<line>;
# a block opens and closes at a `verdict_fixtures` call starting a line, after
# any indentation.
# Read as text, so a spelling through another variable, or an `eval` of text
# built some other way, is not seen; the fixtures written so far are all this
# one spelling.
verdict_evals_outside() {  # verdict_evals_outside <file>... -- <file>:<line> of each verdict evaluated outside a block
  local out awk_status
  [ "$#" -gt 0 ] || { echo 'unread: no file was named'; return; }
  out=$(awk '
    FNR == 1 { inside = 0 }
    /^[[:space:]]*verdict_fixtures begin([[:space:]]|$)/ { inside = 1 }
    /^[[:space:]]*verdict_fixtures end([[:space:]]|$)/ { inside = 0 }
    !inside && /eval "\$\{?[A-Za-z0-9_]+_VERDICT_CODE\}?"/ { print FILENAME ":" FNR }' "$@" 2>/dev/null)
  awk_status=$?
  if [ "$awk_status" = 0 ]; then printf '%s' "$out"; else echo "unread: awk exited $awk_status"; fi
}

# THE SOURCING ROUTINE (#204). check-hooks.sh sources every file of checks/ but
# this one through it, once, in the order of one list the driver derives (#295,
# `suite_checks` below). It asks
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
# THE ROUTINE, DRIVEN AGAINST FIXTURES (#204's, here since #295's issue file
# became its second caller). Each fixture runs `source_checks` in a subshell of
# its own, with a record of its own, and names that subshell as the one that
# records -- the driver's $SOURCED_SHELL is this shell -- so what it writes is
# its own, and a FAIL it
# prints is the one asserted and is not recorded, as in the #98 self-test. The
# FAIL prefix is rewritten on the way out, because the #104 section reads this
# suite for a quoted line opening with a result word.
sourcing_run() {  # sourcing_run <dir> <file>... -- what source_checks printed, REQ after it, and its record
  ( cd -- "$(dirname -- "$1")" || exit 1
    umask 022
    # A trap of its own, because a subshell shows its parent's traps only until
    # it sets one, and then drops them all from `trap -p` (measured, bash 5.2):
    # the first trap a fixture set would otherwise read as every other removed.
    trap ':' EXIT
    SOURCED="$1.record"; : > "$SOURCED"; SOURCED_SHELL=$BASHPID; SUITE_LIBRARY=library.sh
    # Entered with a tag already set, as a driver that left one would: the first
    # file must open without it, which only the clear before each file gives --
    # the one after each file cannot reach the first.
    REQ=GH-0
    source_checks "$@" > "$1.out"
    sed 's/^  FAIL /FAIL: /' "$1.out"
    printf 'REQ=[%s] after the last file\n' "$REQ"
    sed 's/^/record: /' "$SOURCED" )
}

# THE LIST THE DRIVER HANDS source_checks, derived and never written (#295): the
# unsplit file, then every issue file of <dir> -- `GH-<n>.sh`, <n> digits with
# no leading zero -- in ascending numeric order of <n>, a name a line. The
# end-of-run file is not on it; the driver names that one after it. Nothing else
# in <dir> is: a merge's `GH-166.sh.orig`, an editor's swap file, `GH-12a.sh`,
# `GH-012.sh` and `notes.sh` are left off, so `source_checks` fails the run on
# each as a file on no list and never sources it. That refusal is the guard; a
# glob handed straight to the routine would have sourced whatever lay there.
#
# It was a line of the driver's, SUITE_CHECKS, that every branch adding an issue
# file appended to, so any two such branches conflicted on it. Sorted by number
# the order is one nobody chose, which is why ADR 0004 had rejected a listing;
# it is fixed, though, so a file that depends on it is red on the pull request
# that adds it and never a flake, and before it was taken the whole suite ran in
# the list's order, ascending and descending, and agreed row for row (ADR 0006).
#
# A directory it cannot list returns 1 and prints nothing, so the driver can
# stop rather than source the unsplit file alone: `source_checks` lists the
# same directory to find strays, and would find none there either. So does a
# stage of the pipeline that fails, which pipefail -- local to this function
# through `local -` -- turns into the function's status rather than a list cut
# short (review of this change).
#
# WHAT IT GIVES UP, named. The hand-written list failed the run on an issue
# file it named that was not there; a derived list cannot name a file that is
# gone, so deleting an issue file is silent here. What is left to see it is
# the #205 check that every generated entry is declared by a file the run
# sourced, which reaches only a file that declared one -- and the old list was
# silent too whenever the deletion took the name off the list with it. And a
# symlink or other non-directory named `GH-<n>.sh` is sourced like a file.
suite_checks() {  # suite_checks <dir> -- the unsplit file, then every issue file of <dir> by number
  local - sc_names sc_issues
  set -o pipefail
  sc_names=$(cd -- "$1" 2>/dev/null && find . -mindepth 1 -maxdepth 1 ! -type d -name 'GH-*.sh') || return 1
  sc_issues=$(printf '%s\n' "$sc_names" | sed -n 's|^\./GH-\([1-9][0-9]*\)\.sh$|\1|p' \
                | LC_ALL=C sort -n | sed 's|.*|GH-&.sh|') || return 1
  printf '%s\n' unsplit.sh
  [ -z "$sc_issues" ] || printf '%s\n' "$sc_issues"
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
# the run kept of what it declared and pinned -- $SUITE_DECLARED, a record per
# `requirement` call, `<ID> TAB <issue file> TAB <body>` ended by a NUL, and
# $SUITE_PINNED, a line per `shape_pin` or `variants_pin` call, `<shape|variants> TAB
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
  local - rec id file body want seen=' ' legacy f n IFS=$' \t\n'
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
      # An empty body is what `requirement` records when it is called with no
      # heredoc, since the driver's stdin is /dev/null (#223); named as what it
      # is, and not as a file that is not its declaration. Empty and not "no
      # field", which would be a copy of the field grammar GH-223.2 counts.
      if [[ -z $body ]]; then
        printf '%s: declared in %s with no fields\n' "$id" "$file"; seen="$seen$id "; continue
      fi
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
# THE CHECKSUM LITERALS (#200's, here since #223's issue file became its
# second caller). Each token that the split set beside <dir> does not bear out,
# as ` ID:absent` or ` ID:changed(now ID:<cksum>:<length>)`. A changed entry
# says the token it has now, so that the red says how to move it (rev-agent-200,
# round 4 of PR #210); whether the change was meant is the reviewer's to say,
# not this line's. A function so that a fixture can ask it that, which a loop
# over this repository's own entries -- none of them changed -- never could.
# The literal is split on blanks and not globbed, whatever the caller left
# (#223); it turned globbing back on at its end whatever it found until then.
split_moved_bad() {  # split_moved_bad <requirements dir> <literal>
  local - tok id now bad= IFS=$' \t\n'
  set -f
  for tok in $2; do
    id=${tok%%:*}
    if [ ! -f "$1/$id.md" ]; then
      bad="$bad $id:absent"
    else
      now=$(cksum < "$1/$id.md" | awk '{ print $1 ":" $2 }')
      [ "$now" = "${tok#*:}" ] || bad="$bad $id:changed(now $id:$now)"
    fi
  done
  printf '%s' "$bad"
}
# What the pins get wrong: a generated entry in either shared literal, which is
# the hunk every loop edited until the pins (#211); a pin naming an entry no
# issue file declares, or one another issue file declares; an entry pinned twice
# of one kind; and a declared entry with no shape pin. Whether the pinned tokens
# are what the entries say is the comparison each shared literal already had,
# which the end of the run hands them to.
pins_bad() {  # pins_bad <declared record> <pinned record> <shape literal> <scope literal> <legacy literal>
  local - rec id file kind tok legacy IFS=$' \t\n'
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
  local - tok legacy IFS=$' \t\n'
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
# GH-205.2 row red for that reason alone (review of PR #222, round 3). And
# check-hooks.sh from the suite's side too, since #223: the script reads the
# legacy set out of it, and the driver is the tooling as the issue files are.
# Prints the directory.
generator_view() {  # generator_view <suite dir> <hooks dir> <into>
  rm -rf -- "$3" && mkdir -p -- "$3" \
    && ln -s -- "$1/checks" "$3/checks" && ln -s -- "$1/check-hooks.sh" "$3/check-hooks.sh" \
    && ln -s -- "$2/requirements" "$3/requirements" \
    && printf '%s' "$3"
}
# GENERATOR FIXTURES, for the issue files that drive generate-requirements.sh
# against a hooks directory of their own: #205's, and #223's, which made them
# library functions as their second caller. A fixture's declarations are
# written with an `@` in front of the word, taken off as the file is made, so
# that no line of the calling file opens a declaration it does not mean.
issue_fixture() {  # issue_fixture <file> -- stdin, with the @ taken off each @requirement
  mkdir -p "$(dirname -- "$1")"
  sed 's/@requirement/requirement/' > "$1"
}
generator_run() {  # generator_run [--check] <dir> -- what the script printed, and its status
  bash "$HOOKS/generate-requirements.sh" "$@" 2>&1; printf 'exit %s' "$?"
}
# The legacy set the script reads, by name, out of the check-hooks.sh beside
# checks/ (#223), written the one way the driver writes it. A fixture that
# means a malformed literal writes its own.
legacy_fixture() {  # legacy_fixture <dir> <legacy IDs> -- <dir>/check-hooks.sh, holding only the literal
  printf "REQUIREMENTS_LEGACY='\n%s\n'\n" "$2" > "$1/check-hooks.sh"
}
# A COPY OF THE MUTATION HARNESS WHOSE REGISTRY IS THE ROWS GIVEN, and nothing
# else of it changed, for the #193 and #272 issue files to drive against files of
# their own (#193). The harness reads everything relative to its own directory,
# so a copy in a fixture directory applies its rows to that directory's files and
# runs the check-hooks.sh written beside it. What is beside it is the caller's to
# write. The rows replace the registry heredoc's body whole; a copy that still
# holds a line of the real registry, or none of the rows, would drive the real
# rows or nothing, so the caller holds the copy's registry to its literal before
# reading anything the copy prints.
harness_fixture() {  # harness_fixture <dir> <rows> -- <dir>/mutate-hooks.sh, registering <rows> alone
  mkdir -p "$1" || return 1
  HF_ROWS=$2 awk '
    /^MUTATIONS=\$\(cat <</ { print; print ENVIRON["HF_ROWS"]; body = 1; next }
    body && /^MUTATIONS$/ { body = 0 }
    !body' "$SUITE_DIR/mutate-hooks.sh" > "$1/mutate-hooks.sh"
}
# The registry of such a copy, read the way the #107 section reads the real one.
harness_rows() {  # harness_rows <harness> -- the body of its registry heredoc
  awk '/^MUTATIONS=\$\(cat <</ { f = 1; next }
       f && /^MUTATIONS$/ { exit }
       f' "$1"
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
  # A call with no heredoc reads the stdin the call inherits. Under the driver
  # that is /dev/null, which the driver makes it before any issue file is
  # sourced (#223), so the call records an empty body and the end of the run
  # names the entry as declared with no fields; before that it read whatever
  # the suite was started with -- the rest of the registry, under
  # mutate-hooks.sh -- or waited on a pipe that stayed open. A terminal is still
  # not read, for a caller outside the driver.
  [ -t 0 ] || IFS= read -r -d '' body
  printf '%s\t%s\t%s\0' "$*" "${BASH_SOURCE[1]#"$SUITE_DIR"/}" "$body" >> "$SUITE_DECLARED"
}
# THE PINS, #211's decision: the second copy of an entry's shape, and of its
# variants keyword when it is in the invariance families' scope, written in the
# issue file that declares it rather than in REQUIREMENT_SHAPE and INV_SCOPE,
# which every loop used to edit. The tokens are those literals' own,
# `<ID>[:<keyword>]`, and are recorded one line per call, whitespace folded.
# `variants_pin`, its twin for the variants keyword, came here from the #205
# issue file when #144's issue file became its second caller.
shape_pin() {  # shape_pin '<ID>[:<shape>]...' -- the shape of entries this issue file declares
  local - IFS=$' \t\n'
  set -f
  printf 'shape\t%s\t%s\n' "${BASH_SOURCE[1]#"$SUITE_DIR"/}" "$(printf '%s ' $*)" >> "$SUITE_PINNED"
}
variants_pin() {  # variants_pin '<ID>:<keyword>...' -- the variants of entries this issue file declares
  local - IFS=$' \t\n'
  set -f
  printf 'variants\t%s\t%s\n' "${BASH_SOURCE[1]#"$SUITE_DIR"/}" "$(printf '%s ' $*)" >> "$SUITE_PINNED"
}
# THE READER OF A HEADER'S PROSE (#183's, a function since #215's issue file
# became its second caller). Comment lines on stdin, one line of prose out: the
# `#` and up to three blanks after it taken off each line, the lines joined, and
# every run of spaces squeezed to one. A pin on hand-wrapped prose reads a
# reflow and not the file, because a phrase crosses a line break wherever the
# wrap falls; and every reflow ends in this one function, because a second copy
# of the reader is a second rule of what rewrapping may do. Since #192 a pin on
# prose reads `prose_reflow` below, which normalises blanks and then calls this,
# so what rewrapping may do is this function plus that one line; the readers
# that still pipe into this directly are #323's. #215's first reader took
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

# THE RULE FOR A PIN ON PROSE (#192), stated here once: a pin whose literal
# holds a blank and whose file is prose -- Markdown, or a comment -- reads the
# file through `prose`, while a pin on code reads the lines, and so does a pin
# on prose whose literal needs a line's opening `#`, with a comment saying so.
#
# Why: `written`, `unarmed` and `prose_count` grep a file's lines, so a phrase
# matches only where the wrap happens not to fall inside it. An absence pin
# then reads ok with the phrase standing in the file, the permitting direction
# and silent; a presence pin goes red on a rewrap that changed no word. GH-70.3
# was the instance: `four acts` re-added to the branch-hygiene skill across a
# line break, and the whole suite passed (#192, measured on PR #183's branch at
# d86223b). The suite had found the class three times before and fixed the
# instance each time -- a `flatten` helper beside GH-97.2, $MUT_PROSE, and the
# left-open pins of #184 -- which is why it is a rule here and not a fourth
# fix.
#
# WHAT `prose` READS THAT comment_reflow ALONE DOES NOT. Before the reflow,
# `prose_reflow` turns a tab, a carriage return, a vertical tab and a form feed
# into a blank, and takes the blanks off each line's start. The first is what
# `flatten` did, `tr -s '[:space:]'`, before #192 retired it: comment_reflow
# squeezes only spaces, so a tab inside a wrapped phrase split it, and GH-97.2's
# absence over CONTEXT.md read ok with the phrase standing there (review of
# #192's branch, round 1: red on origin/dev-05, green on the branch). The second
# is what makes an INDENTED comment prose: comment_reflow takes a `#` only at
# column 0, so a phrase wrapped across two comment lines inside a function read
# with a `#` in it, and an absence pin on a hook's prose read ok with the
# phrase re-added there (same review, over report-stale-branches.sh and
# no-work-on-stale-branch.sh). A presence pin may name where today's text sits;
# an absence pin has to read wherever the text can be put back, which is any
# comment. comment_reflow itself is left as it was: #192 keeps its behaviour,
# and its other readers are held to it.
#
# WHAT `prose` CANNOT READ. It takes a `#` off a line opening with one, blanks
# before it or not, so a heading's `##` loses a mark and a pin on it goes red;
# a heading is one line, which is why such a pin stays on the lines. The same
# holds of a `#` a wrap puts at a line's start in the middle of a sentence,
# `pull request` over `#N`, which reads as `pull request N`: a literal holding
# a `#` is found only where no wrap falls just before it, so a presence pin on
# one can go red on a rewrap, and an absence pin on one would read ok. None of
# the latter stood in the suite when this was written.
#
# THE FIXTURE IS WRITTEN ONLY WHEN ITS PROSE HOLDS A WORD, and otherwise
# removed, so `written` and `unarmed` over it find no file: `unarmed` fails
# naming grep's status 2, and `written` fails as it does for a literal not
# found. An extraction that found nothing, a file of blank lines, a
# directory and a path that is not there all reach that arm rather than a
# reflow of blanks, over which `unarmed` would read ok. An empty file, a file
# with no prose in it and a failed extraction all reflow alike, so once
# reflowed the difference is gone; `unarmed` passes a zero-byte file it was
# handed, by design (#256), and so is never handed one from here.
# comment_reflow turns an empty line into one blank, which is why the question
# is a word and not a size (review of #192's branch). The path mirrors the
# source's under $FIXTURES/prose, so a failure names the file it read.
#
# AND ONLY FROM AN ABSOLUTE PATH. `written` and `unarmed` refuse a relative
# name through `absolute_or_fail`, since one is read from this suite's own
# directory and not from the hooks under judgment (#142); behind `prose` they
# are handed the fixture's path, which is always absolute, so the refusal has
# to be made here. A relative source touches nothing and writes nothing, and
# the path printed for it is one nothing writes: under $FIXTURES/prose-refused,
# the name after `relative:` with each `/` spelled `%2F`, so it is one path
# component and never `.` or `..` -- `prose ..` without the prefix printed
# `prose-refused/..`, which stayed unresolved only while nothing had made that
# directory (review of #192's branch, round 5).
# Two earlier shapes were each wrong. The first ran `mkdir` and `rm -f` on the
# mirrored path before asking whether the source was absolute, so `prose
# ../suite-text`, from any directory, deleted $SUITE_TEXT (review of #192's
# branch, round 4, measured). Moving the `rm` inside the absolute arm alone
# would have left the mirrored path standing: a relative `tmp/x` names the
# fixture an earlier `prose /tmp/x` wrote, and `written` would read that.
prose_reflow() {  # prose_reflow -- prose on stdin, one line out: blanks normalised, then comment_reflow
  tr '\t\r\v\f' '    ' | sed -e 's/^ *//' | comment_reflow
}
prose() {  # prose <file> -- the path of <file> as prose_reflow reads it, written under $FIXTURES/prose
  local out
  case "$1" in
    /*) out="$FIXTURES/prose/${1#/}"
        mkdir -p -- "${out%/*}"
        rm -f -- "$out"
        if [ -f "$1" ]; then
          prose_reflow < "$1" > "$out"
          grep -q '[^[:space:]]' "$out" 2>/dev/null || rm -f -- "$out"
        fi ;;
    *) out="$FIXTURES/prose-refused/relative:${1//\//%2F}" ;;
  esac
  printf '%s\n' "$out"
}
# `prose_count` counts LINES, and a reflow is one line, so over `prose` it
# could no longer tell one saying from two. This counts OCCURRENCES of the
# literal in the reflow instead, so a pin that holds a count at 1 still goes
# red on a second copy. A status other than 0 and 1 prints the line
# `prose_count` prints for it, which no count equals.
prose_occurrences() {  # prose_occurrences <file> <literal> -- how many times its prose says it
  local reflowed found grep_status
  reflowed=$(prose "$1")
  found=$(grep -oF -- "$2" "$reflowed" 2>/dev/null)
  grep_status=$?
  case $grep_status in
    0) printf '%s\n' "$found" | grep -c '' ;;
    1) printf '0\n' ;;
    *) printf 'unread: grep exited %s on %s\n' "$grep_status" "$reflowed" ;;
  esac
}

# THE POINTER BESIDE THE DEV-BRANCH DERIVATION, the `for-each-ref` over
# refs/remotes/origin/dev- that three hooks share, read by #62's checks in the
# unsplit file; in the library since #192's issue file drives `beside` too.
#
# The comment block standing immediately above the derivation. `armed` would
# ask only whether a literal is somewhere in a file, and somewhere is not
# beside: a pointer that drifted to the head of either file would still satisfy
# grep while no longer standing where the derivation is read and edited, which
# is the whole of what a pointer is for. A blank line ends the block, so a
# pointer separated from the derivation does not count as beside it.
dev_pointer() {  # dev_pointer <file> -- the comment block above the derivation
  awk '/^#/ { block = block $0 "\n"; next }
       /for-each-ref.*refs\/remotes\/origin\/dev-/ { printf "%s", block; exit }
       { block = "" }' "$1" 2>/dev/null
}

# The block is prose, so it is read through prose_reflow, by the rule for a
# pin on prose above: the two literals the unsplit file gives it are clauses of
# a wrapped comment, and each matched only while the wrap fell outside it.
beside() {  # beside <label> <file> <literal>
  if dev_pointer "$2" | prose_reflow | grep -qF -- "$3"; then
    pass static 'beside %s' "$1"
  else
    fail static '%s\n         expected the comment above the derivation in %s\n         to contain |%s|' \
           "$1" "$2" "$3"
  fi
}

# WHETHER A COPY OF THE TOKENISER SOURCES AS ITS ORIGINAL DOES: the status
# sourcing each returns, taken the same way, and the two compared. A fixture
# guard that loads a copy asks this, and not whether sourcing the copy returned
# 0 (#279): the tokeniser under check may itself source non-zero -- the
# registry row tokeniser-sources-non-zero is one that does -- and its copy is
# then a fixture working and not a fixture broken, and its own checks say what
# is wrong with it. Nor only whether a name is defined, which is what the
# two guards asked on this branch until round 1 of the review of PR #330
# measured the cost: a copy its builder broke -- an unterminated `if`
# appended, where every function is defined and sourcing returns 2 -- passed
# every half-library guard, and every check driving one was green. A copy the builder broke into the status its original
# already returns is not told apart from it; that is the limit, named.
copy_sources_as() {  # copy_sources_as <copy> <original> -- 1 and why on stdout when they source with different statuses
  local copy_status original_status
  bash -c '. "$1"' _ "$1" > /dev/null 2>&1
  copy_status=$?
  bash -c '. "$1"' _ "$2" > /dev/null 2>&1
  original_status=$?
  [ "$copy_status" = "$original_status" ] && return 0
  printf 'it sources with status %s, and the tokeniser it was copied from with %s' \
    "$copy_status" "$original_status"
  return 1
}

# The library present and loading, with exactly one function renamed away. Built
# by a call at the top level and named by convention, rather than returned from a
# substitution: an `exit 1` inside `$( )` kills the subshell and leaves the suite
# running, so a fixture guard written that way would report and then be ignored.
#
# Where the fixture goes, derived once. The builder below takes its directory
# from this rather than composing the same path a second time, and that is not
# tidiness: the first version of mk_halflib wrote
# `local hook="$1" fn="$2" dir="$FIXTURES/halflib-$fn-$hook"`, and `local`
# expands all of its arguments before it assigns any of them, so $fn and $hook
# were still empty and every fixture was built in one directory named
# `halflib--`. All four fixture guards passed -- they were asked about the
# directory that had been built, not about the one the checks would drive -- and
# thirteen checks reported ALLOW against a hook that was not there, which
# check_in read as permitted because it was not exit 2 (see `verdict`, where
# those thirteen would each FAIL today). A fixture guard that
# derives its own path proves nothing about the check beside it.
halflib_path() {  # halflib_path <hook> <cs_function> -- where that fixture sits
  printf '%s\n' "$FIXTURES/halflib-$1-$2/$1"
}
mk_halflib() {  # mk_halflib <hook> <cs_function>
  local hook="$1"
  local fn="$2"
  local target dir why
  target=$(halflib_path "$hook" "$fn")
  dir=$(dirname "$target")
  mkdir -p "$dir/lib"
  cp "$HOOKS/$hook" "$dir/"
  sed "s/^$fn()/cs_renamed_away()/" "$HOOKS/lib/command-scan.sh" > "$dir/lib/command-scan.sh"
  # Both directions on the rename, because a sed that matched nothing leaves a
  # complete library behind and the check using it would pass with no guard at
  # all -- which is how these hooks reached dev-05 in the first place.
  grep -q '^cs_renamed_away()' "$dir/lib/command-scan.sh" || {
    echo "the half-library for $hook did not rename $fn away; the check using it proves nothing" >&2
    exit 1
  }
  ! grep -q "^$fn()" "$dir/lib/command-scan.sh" || {
    echo "the half-library for $hook still defines $fn; the check using it proves nothing" >&2
    exit 1
  }
  # And that what is left still loads. A fixture broken some other way would
  # refuse for a reason this section does not name, and would read as evidence
  # for the guard. First, that it sources as the tokeniser it was copied from
  # does -- asked before the load below, so that what it says on a refusal is
  # this guard's line alone. See `copy_sources_as`.
  why=$(copy_sources_as "$dir/lib/command-scan.sh" "$HOOKS/lib/command-scan.sh") || {
    echo "the half-library for $hook does not source as the tokeniser it was copied from: $why; the check using it proves nothing" >&2
    exit 1
  }
  # The one line filtered out of its stderr is the library's own report of a
  # withdrawal (#182's, for a library missing cs_drop_heredocs), which is the
  # fixture working and in a green log reads as a failure. Anything else it
  # says is kept, so a fixture that fails to load for a reason of its own still
  # shows bash's diagnostic; review of #182's pull request found the first
  # version dropping all of it.
  # Loading is judged by what sourcing defined, and its status by the one
  # above, and not by `&&` (#279): asked that way, a tokeniser copy that
  # sources non-zero stopped the run here, unjudged, which is how the registry
  # row tokeniser-sources-non-zero first came back did-not-complete.
  bash -c ". '$dir/lib/command-scan.sh'; command -v cs_renamed_away >/dev/null 2>&1" \
    2> >(grep -vF 'cs_drop_heredocs is not defined, and cs_normalise calls it' >&2) || {
    echo "the half-library for $hook does not load at all; the check using it proves nothing" >&2
    exit 1
  }
  # The last guard asks about the path the checks will actually drive, which is
  # the one the `halflib--` bug got wrong.
  [ -x "$target" ] || {
    echo "the half-library fixture for $hook is not at $target, or is not executable; the check using it proves nothing" >&2
    exit 1
  }
}

# The library present and loading, with both halves of the prefix-word list
# emptied, for every consumer that calls cs_split. The unsplit file's #79
# section says what it is for and drives it; #279's issue file drives the
# builder itself, which is why it is here.
emptylist_path() {  # emptylist_path <hook> -- where the emptied-list copy of it sits
  printf '%s\n' "$FIXTURES/emptylist-$1/$1"
}
mk_emptylist() {  # mk_emptylist <hook>
  local hook="$1"
  local target dir why
  target=$(emptylist_path "$hook")
  dir=$(dirname "$target")
  mkdir -p "$dir/lib"
  cp "$HOOKS/$hook" "$dir/"
  # Emptied IN PLACE. Appending would land after CS_WRAPPER_RE is derived and
  # after the withdrawal has already run against a full list, so the fixture
  # would test nothing the library does on load; the first version of these
  # appended, and was green for that reason.
  sed -E 's/^CS_WRAP_OPTION_WORDS=.*/CS_WRAP_OPTION_WORDS=""/;
          s/^CS_WRAP_OPERAND_WORDS=.*/CS_WRAP_OPERAND_WORDS=""/' \
      "$HOOKS/lib/command-scan.sh" > "$dir/lib/command-scan.sh"
  # Both directions on the edit, as mk_halflib does on its rename: a sed that
  # matched nothing leaves a complete library, and the checks against it pass.
  grep -q '^CS_WRAP_OPTION_WORDS=""$' "$dir/lib/command-scan.sh" \
    && grep -q '^CS_WRAP_OPERAND_WORDS=""$' "$dir/lib/command-scan.sh" || {
    echo "the emptied-list library for $hook did not empty both halves; the checks using it prove nothing" >&2
    exit 1
  }
  ! grep -qE "^CS_WRAP_(OPTION|OPERAND)_WORDS='" "$dir/lib/command-scan.sh" || {
    echo "the emptied-list library for $hook still assigns a full list; the checks using it prove nothing" >&2
    exit 1
  }
  # And that it still loads with every OTHER function defined, so a refusal
  # against it is the list's doing and not a library broken some other way.
  # cs_split is deliberately not asked here: whether it is withdrawn is the
  # mechanism, and a fixture guard exits the suite rather than failing a check,
  # which would report a removed mechanism as an aborted run instead of as red.
  # By what sourcing defined, and a status that is the original's, as
  # mk_halflib asks (#279); see `copy_sources_as` in the library.
  why=$(copy_sources_as "$dir/lib/command-scan.sh" "$HOOKS/lib/command-scan.sh") || {
    echo "the emptied-list library for $hook does not source as the tokeniser it was copied from: $why; the checks using it prove nothing" >&2
    exit 1
  }
  bash -c ". '$dir/lib/command-scan.sh'; command -v cs_normalise && command -v cs_git_args \
           && command -v cs_gh_args && command -v cs_join" >/dev/null 2>&1 || {
    echo "the emptied-list library for $hook does not load with its other functions; the checks using it prove nothing" >&2
    exit 1
  }
  [ -x "$target" ] || {
    echo "the emptied-list fixture for $hook is not at $target, or is not executable; the checks using it prove nothing" >&2
    exit 1
  }
}

# THE REFUSAL-ARM COUNTERS: `arms`, `fn_writes` and `fn_calls`, here since
# #182, whose issue file became their second caller after the #109 section in
# the unsplit file. Their argument -- what each counts and the shapes it cannot
# reach -- stayed in that section, above `STDERR_WRITE`, which it sets and
# `arms` and `fn_writes` read; it is written beside the fixtures and pins it is
# argued with, and moving it would cut it from them.
#
# WHAT ALL THREE READ is `hook_text`, and the order is written there once: a
# whole-line comment blanked, then heredoc bodies dropped by the tokeniser's own
# `cs_drop_heredocs`, then backslash continuations folded. Three copies of that
# pipeline were how the three came to disagree -- #169's review found a fix made
# in one of them and not the one beside it three times -- and the order is the
# half of #182 that could hide an arm: folding first lets a body line ending in
# a backslash carry its terminator away, and dropping first lets a comment
# naming `<<END` open a body. checks/GH-182.sh drives both, and holds each
# counter to reading the hook through this and nothing else.
#
# WHAT THE DROP TAKES IS ALSO A QUESTION, and `hook_dropped` in
# checks/GH-182.sh answers it. The drop is the tokeniser's, and the tokeniser
# does not read quotes: a `<<` inside a string or a trailing comment opens a
# body, and when a line that terminates it does arrive -- the real delimiter
# further down, or for `'<<'`, whose delimiter is empty once its quotes are
# gone, the first blank line -- the real code in between is dropped as a body
# and its arms are never counted. Only a body whose terminator never arrives is
# given back. #289 owns that in the tokeniser; review of #182's pull request
# found it hiding five lines of no-pr-decisions.sh here, and GH-182.3 holds
# what is dropped from each counted hook to a heredoc's shape. So the first two
# stages are helpers of their own, and `hook_dropped` diffs one against the
# other: the text `hook_text` folds is `hook_bodiless`'s, exactly, and not a
# second copy of the pipeline that a counter-side filter or a route round #289
# added to one of them would leave behind. It was a copy in the commit that
# added it, and review of #182's pull request found it. The fold is the only
# stage after it, and GH-182.3 pins `hook_text` as written, so a stage added
# there is a red run and not text the counters read that no row judges.
hook_uncommented() {  # hook_uncommented <file> -- its whole-line comments blanked
  sed 's/^[[:space:]]*#.*$//' "$1"
}
hook_bodiless() {  # hook_bodiless <file> -- that, with heredoc bodies dropped
  hook_uncommented "$1" | cs_drop_heredocs
}
hook_text() {  # hook_text <file> -- a hook's text as the refusal-arm counters read it
  hook_bodiless "$1" \
    | sed ':a;/\\$/{N;s/\\\n//;ba}'
}
# WHICH READS A HELPER MAKES OF ITS FILE, asked by checks/GH-182.sh of the
# three counters and by checks/GH-181.sh of `writer_callers` and `odd_defs`,
# and here since #181 made it two callers. True when the function's
# definition, as bash holds it, passes its file argument to each helper named,
# as `<helper> "$1"` in a command's first word, and with those calls taken out
# names no `$1`, `$@` or `$*`, braced or not, no indirection `${!...}` and no
# `BASH_ARGV`, and no drop or `sed` of its own. GH-182.sh argues the two
# halves #182 asked -- a read through the helper, and nothing else read -- and
# the review of #182's pull request that found their first two versions short.
# What review of #181's pull request added, where the call is read and the two
# further names refused, is argued here, since it is this function's and not
# any one caller's.
#
# THE CALL IS READ WHERE A COMMAND STARTS, NOT BOUNDED BY WHAT MAY NOT STAND
# BESIDE IT, and two rounds of review of #181's pull request are why. The first
# answer bounded the name on the left by `[^A-Za-z0-9_]`, which closed
# `raw_hook_text "$1"` and left `raw-hook_text "$1"` and `./hook_text "$1"`
# passing: a guard against one spelling of a class, exhibiting the class. A list
# of characters barred in front of the name cannot be completed, since `-`,
# `/`, `+` and `:` all build another command word, and no such list refuses
# `cat hook_text "$1"` at all, since what stands in front of the name there is
# a blank and the helper is only an argument. So the call must start a line,
# follow `;`, `|` or `&`, or follow a `(` that opens a command substitution, a
# process substitution or a subshell -- one after `$`, `<`, `>` or a blank --
# with blanks between; and `"$1"` must be a whole word, ending at a blank, `;`
# or `)`. Each call is taken out with what stood before it, and the character
# after it is kept, since that character can be where the next call starts: a
# newline between two calls inside one `$(...)`, which the first version of
# this took out with the first call, refusing the second.
#
# THE LISTS ARE WHAT `declare -f` PRINTS, AND NOTHING WIDER, because a member
# no definition can put beside a call is a member no fixture can hold. It
# spaces `|`, `&` and a redirect off the word before them, so none stands after
# `"$1"`, and a body ends at `}`, never at a call; review of #181's pull
# request, round 3, measured those members changing no verdict. It breaks a
# list onto lines at the top of a body but not inside `$(...)`, `<(...)` or
# `>(...)`, where bash 5.2 prints `x=$(true; hook_text "$1")` on one line, so
# `;` stays before a call: round 3 removed it with the others and round 4
# measured that shape refused. Each member left is the only way at least one
# reader in checks/GH-181.sh passes, and the respacing it rests on was
# measured with bash 5.2 and no older bash. A `(` after `=` is an array, and
# `local -a f=(hook_text "$1")` holds the file's name as data, which is why the
# `(` is asked for its left side.
#
# THE TRADES, two classes and not two lists, since each round of review of
# #181's pull request found another member of each, and each widening of the
# rule here opened a spelling of the second. Neither is closed here: the text
# rule is the wrong tool for a behavioural question, and #362 is filed for the
# probe that answers it -- stub the helpers, point `$1` at a path that is not
# there, and fail on any read of it. checks/GH-181.sh asserts members of each
# class as rows, as examples of it and not as its extent.
#   - REFUSED, a false red, visible and one edit away: a call after any
#     keyword or prefix word the lists do not name -- `if`, `while`, `until`,
#     `elif`, `!`, `time`, `command`, `coproc`, `exec`, an assignment such as
#     `LC_ALL=C`, a `{` group, and whatever else can stand before a command --
#     and a call inside backticks, which `declare -f` prints as written. So is
#     any `${!...}` in the reader, `${!seen[@]}` included, since an
#     indirection is refused wherever it stands.
#   - PASSED, a construction rather than a mistake: any text the rule reads as
#     a command start that bash reads as data -- a string of one line or
#     several, a heredoc body, a separator escaped as `\;` -- so the file's name
#     can be held there and read by something else; and any name the text does
#     not spell, taken from `$_` after the call or rebuilt by `eval`. A filter
#     of the reader's own other than `sed`, a `perl -pe` before its `awk`,
#     passes too: the readers run awk programs of their own, which can rewrite
#     any line they are given, so no list of filter names can say that none
#     was applied, and `sed` is refused because it is the fold's own tool, the
#     one a second fold would be written with.
reads_only_through() {  # reads_only_through <function> <helper>... -- its file argument read through each helper, and nowhere else
  local body rest h re
  body=$(declare -f "$1") || return 1
  rest=$body
  shift
  for h in "$@"; do
    re=$'(\n|[;|&]|[$<>[:space:]]\\()[[:space:]]*'"$h"$' "\\$1"[[:space:];)]'
    [[ $body =~ $re ]] || return 1
    while [[ $rest =~ $re ]]; do
      rest=${rest/"${BASH_REMATCH[0]}"/" ${BASH_REMATCH[0]: -1}"}
    done
  done
  [[ $rest != *cs_drop_heredocs* && $rest != *'sed '* && $rest != *BASH_ARGV* ]] \
    && ! [[ $rest =~ \$\{?(1|[@*]) || $rest =~ \$\{! ]]
}
arms() {  # arms <file> -- in how many places it writes a refusal to stderr
  hook_text "$1" | grep -oE "$STDERR_WRITE" | wc -l | tr -d ' '
}
fn_writes() {  # fn_writes <file> -- "<function> writes|silent" a line, sorted
  hook_text "$1" \
    | awk -v W="$STDERR_WRITE" '
        /^function[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/ || /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)/ {
          fn = $0; sub(/^function[[:space:]]+/, "", fn); sub(/[[:space:](){].*/, "", fn)
          seen[fn] = 1
          if ($0 ~ /;[[:space:]]*\}[[:space:]]*$/) { if ($0 ~ W) w[fn] = 1; fn = ""; next }
          next
        }
        /^\}/ { fn = ""; next }
        fn != "" && $0 ~ W { w[fn] = 1 }
        END { for (f in seen) print f, (f in w ? "writes" : "silent") }' \
    | LC_ALL=C sort
}
fn_calls() {  # fn_calls <file> <function> -- how many times it appears as a call
  hook_text "$1" \
    | grep -vE "^(function[[:space:]]+)?$2[[:space:]]*\(\)" \
    | tr -c 'A-Za-z0-9_$-' '\n' \
    | grep -cxF -- "$2"
}
# THE DUPLICATED DESCRIPTOR, which the three counters above cannot see through,
# so the #109 section in the unsplit file refuses it in both hooks rather than
# counting it; that section argues why. Here since #185, whose issue file became
# its second caller, and widened by it: the pattern reached one spelling, a
# single-digit fd written `N>&2`, of a contract that says any fd but 1.
#
# WHAT IT REACHES, read off the text as three parts. A SOURCE fd written
# explicitly -- a number whose value is not 1, leading zeros read as bash reads
# them, so `02` is fd 2 and `01` is fd 1, or a `{name}`, a subscript allowed
# and one subscript nested in it, each holding a character or more, since bash
# reads an empty one as no name -- or left implicit on an input operator, where
# it is 0. Bash reads digits or a `{name}` in front of an operator as its fd
# only when they are the whole word, so a written source is read only where a
# word starts: after a character of `end`, below, or after a quote, which may
# open a string `eval` or `sh -c` runs -- `eval "3>&2 exec"`, which the pattern
# before #185 reported and round 4 of review hid until the sixth found it -- or
# close one, `"$x"3>&2`, which is then a trade. `a3>&2`, `$sha256>&2` and
# `${msg}>&2` are fd 1, and are not reported; until the fourth review of #185's
# pull request a source was read after anything but a digit or a `$`, `a3>&2`
# and `"$x"3>&2` were recorded as refusing-direction trades, and `$sha256>&2`
# was reported against the requirement's own word that fd 1 never is. After `<`
# or `>` bash reads the digits as that operator's fd and stops on a syntax
# error, so no line tells those two word starts apart; they are read because
# the source reads `end` whole. For the same reason the implicit fd is found
# after anything but `<` and a word of digits alone: `}<&2` and `a1<&2` are fd
# 0, and ` 1<&2` and `` `1<&2 `` are fd 1. The digits after `>&` or `<&` are
# the exception: bash reads them as that operator's target and never as the
# next one's fd, so `>&1<&2` is fd 0; after any other operator they are the fd,
# and `>1<&2` is a syntax error. A TARGET that is fd 2, leading zeros allowed,
# after `>&` or `<&`; or, after `>`, `>>`, `>|`, `<` or `<>`, a path whose last
# component is `stderr` or whose last two are `fd/2` -- which reaches
# `/dev/stderr`, `/dev/fd/2` and every `/proc/.../fd/2` naming this process
# without listing them, and reports `/proc/$PPID/fd/2` too, the parent's, a
# trade GH-185's note lists -- or, after any of those but `<`, which opens it
# read-only, a process substitution, `>(`, whatever the command in it writes to.
# Blanks allowed in front of the target.
#
# WHERE A WORD ENDS is `end`, one set that every part reads: a blank, which is a
# space or a tab as bash's blanks are, one of `;&|()<>`, and a backtick. It read
# `[:space:]` until the sixth review of #185's pull request, which let a form
# feed end a word, so `x=<FF>1<&2`, fd 0 to bash, read as fd 1; every blank in
# the pattern is `[:blank:]` now. That set is where bash ends a word in the text
# alone, and not everywhere: a substitution's closing `)` or backtick ends no
# word, so `$(:)1` is one word, an escaped blank joins one, so `a\ 1` is one,
# and an extglob pattern's close ends none, so `!(x)1` is one; an alias is
# expanded as bash reads the line, into text this one never sees; which a
# character is depends on the state bash is in when it reads it, which the text
# does not carry. GH-185's note names that class and pins its representatives,
# and the fifth review set the line there: named, not reached, since reaching it
# is a lexer. It was three copies until the second review found two of them
# without the backtick, so a path closing a substitution was never bounded. It
# is the tokeniser's BOUND in lib/command-scan.sh, and is not read from there:
# that is a string inside an awk program there, not a value to import, and a
# guard asked of the hooks that shares their tokeniser's text shares its
# defects. The second reading's target word stops at a backtick too, and round 2
# of that review said this could not be observed; round 3 observed it: without
# the stop, ``x=`: >a`$'3'>&2`` has `$'3'` taken out of the quotes of a word
# that is not a target, and reads as fd 3, where bash reads fd 1. Whether that
# word matches an empty run or fails to match one cannot be observed, since
# awk's `substr` gives the same word and the same rest either way.
#
# The implicit fd on an output operator is 1, which is an ordinary refusal and
# is never reported however it is spelled; `<<` and `<<<` are not input
# operators and are stepped over.
#
# EACH LINE IS READ TWICE: as written, and with the quotes, the backslashes and
# the repeated `/` and `./` segments taken out of every redirection's target
# word, so `>&\2`, `>&''2`, `>&$'2'` and `>"/dev/"stderr` read as the bare
# spellings they are. The two readings are joined on one line, split by a `;`
# that ends every part of the pattern, and a line either one matches is
# reported as written. Both readings are needed: a quote taken out can leave
# a word of digits alone in front of the next operator, so `>"1"<&2`, fd 0
# onto stderr, reads as fd 1 without its quotes. What an escape or an
# expansion in a target stands for is not read; GH-185's note names what that
# leaves.
#
# The `;` is also the second reading's start of line, which is why no part of
# the pattern has a `^`: the two readings agree on everything in front of a
# line's first target word, so a source or an implicit fd at the start of a
# line is read after the `;`, and a `^` could never be the reason a line
# matched (the third review found it dead). The second reading finds an
# operator as `<` or `>` and then an `&` or `|` if one follows; `>>` and `<>`
# are two operators to it, and the word after the second is the one it reads,
# so a `>` in that class could not be observed either.
#
# Where the ends are loose, they are loose in the refusing direction: the
# digits after `>&` are a word start to the source, so `>&13>&2`, a target of
# 13 and then fd 1, is reported; the fd target is not bounded on its right, so
# `>&20` is reported; and a path is read by its end in any directory, so a
# log file named `stderr` is reported. GH-185's note lists every trade, and a
# row pins each. A path is bounded on its
# right, since read by its end it would otherwise reach `2>/tmp/stderr.log`.
# The second reading takes quotes out without reading which quote holds which,
# so `3>\&2`, a file named `&2`, is reported.
#
# THE TOOLS READ THE FILE, and until the seventh review of #185's pull request
# they read it by the caller's locale and their own operand rules, not as bash
# does: under a UTF-8 locale GNU grep took a file holding a NUL, or a line with
# a byte that is not UTF-8, as binary and printed nothing, and `[:blank:]` took
# in an EM SPACE; and awk took a file named `x=1.sh` as an assignment and one
# named `-` as stdin, and read stdin instead. The same file was red on one
# machine and green on another. So the whole pipeline runs under `LC_ALL=C`,
# exported to its tools and local to the call, and awk reads the file on stdin,
# never as an operand. The class is the tools' semantics, where every earlier
# class was the pattern's, and checks/GH-185.sh pins a row for each member,
# called under `C.UTF-8`, the locale CI gives the suite, so each tells the fix
# from its absence wherever it runs. The eighth review found one more, in bash
# rather than the tools: bash drops every NUL from the text it reads, so
# `exec 3>&<NUL>2` is `exec 3>&2` to it, and the pipeline read it with the NUL
# kept. `tr` takes each NUL out first, which leaves every line's number as it
# was. grep read with `-a` until then, for a file holding a NUL; under
# `LC_ALL=C` a file with none is never binary to it, so `-a` went, since no
# row could tell it from its absence, and the NUL rows go red without the
# `tr`, since grep then reads the file as binary.
#
# A FILE IT CANNOT READ is reported as `UNREADABLE`, with the reason on stderr,
# and never as the empty string a clean file gives: every row that asks a real
# file would pass on an absent one otherwise. A directory is not a regular
# file, and a row drives that half. The readable half has no row: a file of
# mode 000 is readable by root, so the row would pass or fail by who runs it.
#
# A RUN OF CONTINUED LINES -- each but its last ending in a backslash -- is
# read joined from every line of it to its end, each join under its own first
# line's number, and a join whose first non-blank is `#` is a comment and is
# blanked. Which of those lines starts bash's logical line depends on whether a
# backslash is escaped or inside a trailing comment, which is the state the
# text does not carry, and one of the joins is bash's whichever it is: `: #
# note\`, `3>\`, `/dev/stderr f` is the comment and then `3>/dev/stderr f`,
# reported under its own line, and `: x\` then `#y; exec 3>&2` is one line to
# bash, whose `#` is inside a word. That is the sixth review's fix for the
# family of joins the fold started too early. It replaced three narrower ones:
# until the fourth review the fold blanked comments before it joined and
# continued a comment, and `: # price in $\` then `3>&2 exec` read as the
# parameter `$3`, which the pattern before #185 had reported; the fourth added
# a reading of each continued line alone, and the fifth a rule that a comment
# at a logical line's start continues nothing, and each was one member of the
# family. Reading more joins can only add a report, and the joins bash does not
# make are the refusing-direction trades GH-185's note lists, #315's escaped
# backslash among them. The fold is its own and not `hook_text`'s, for two
# reasons: `hook_text` drops heredoc bodies with the tokeniser's pass, and
# #289's misread `<<` drops real code with them, which is the permitting
# direction here; and its fold joins lines, so the numbers `grep -n` prints
# stop being the file's. Heredoc bodies stay, so a body line naming the shape
# is a red -- the refusing direction. checks/GH-185.sh drives each part against
# a fixture and argues what it does not reach.
dup_stderr() {  # dup_stderr <file> -- any fd but 1 pointed at 2, which a duplication writes
  local end src imp fd path proc sep
  local -x LC_ALL=C
  [ -f "$1" ] && [ -r "$1" ] || {
    echo "dup_stderr: $1 is not a readable file, so nothing in it was asked" >&2
    echo UNREADABLE
    return 1
  }
  end='[:blank:];&|()<>`'
  src="[${end}\"']((0+|0*[2-9]|0*[1-9][0-9]+)|[{][A-Za-z_][A-Za-z0-9_]*([[]([^][]|[[][^][]+[]])+[]])?[}])"
  imp="([^0-9<]|[^${end}0-9][0-9]+|[<>]&[[:blank:]]*[0-9]+)"
  fd='&[[:blank:]]*0*2'
  path="[[:blank:]]*[^${end}]*/(stderr|fd/2)([${end}]|\$)"
  proc='[[:blank:]]*>[(]'
  sep=$(printf ';\001;')
  tr -d '\000' < "$1" \
    | awk -v sep="$sep" -v word="^[^${end}]*" '
        function unquoted(s,   out, w) {
          out = ""
          while (match(s, /[<>][&|]?[[:blank:]]*/)) {
            out = out substr(s, 1, RSTART + RLENGTH - 1); s = substr(s, RSTART + RLENGTH)
            match(s, word); w = substr(s, 1, RLENGTH); s = substr(s, RLENGTH + 1)
            gsub(/\$["\047]|["\047\\]/, "", w); gsub(/\/+/, "/", w)
            while (sub(/\/\.\//, "/", w)) ;
            out = out w
          }
          return out s
        }
        function emit(l) { if (l ~ /^[[:blank:]]*#/) l = ""; print l sep unquoted(l) }
        function flush(   k, i, t, l) {
          for (k = 1; k <= n; k++) {
            t = ""
            for (i = k; i <= n; i++) { l = run[i]; sub(/\\$/, "", l); t = t l }
            emit(t)
          }
          n = 0
        }
        { run[++n] = $0; if ($0 ~ /\\$/) next; flush() }
        END { flush() }' \
    | grep -nE "${src}([<>]${fd}|(>|>>|<|<>|>[|])${path}|(>|>>|<>|>[|])${proc})|${imp}(<${fd}|(<|<>)${path}|<>${proc})" \
    | sed "s/${sep}.*//" | tr '\n' ' ' | sed 's/ $//'
}

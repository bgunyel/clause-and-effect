#!/bin/bash
# Regression checks for the hooks under .claude/hooks/ and what they rest on.
# The boundary hooks: no-git-push.sh, no-pr-decisions.sh, no-commit-to-main.sh
# and no-work-on-stale-branch.sh. The convention hooks: pytest-via-uv-group.sh,
# alembic-via-uv-group.sh, append-only-docs.sh and append-only-docs-edit.sh.
# The session report, report-stale-branches.sh, and the tokeniser most of them
# source, lib/command-scan.sh. And the files that run or describe them: the
# settings.json that registers them, and CLAUDE.md, CONTEXT.md and the
# branch-hygiene skill's SKILL.md. And the one script outside .claude/hooks/
# that reads the session report, the housekeeping skill's
# housekeeping-commands.sh. And the one file beside this suite that nothing here
# runs, mutate-hooks.sh, which runs THIS suite against a mutated copy of the
# hooks: its registry and its guards are checked as text, in the #107 section,
# and its own runs are the evidence that the checks tagged with the requirements
# its registry names can fail. Not the checks here, which is a larger claim than
# any run of it makes: its header counts what its rows reach and names two kinds
# of rule they cannot reach at all. The unqualified sentence stood here until
# Bertan's review of PR #142, contradicting the harness's own header and
# CLAUDE.md both.
# Most checks run a hook as a process and read
# its verdict; the rest read one of these files, and each kind is introduced
# where it begins. Every check carries the IDs of the requirements it
# establishes, which requirements.md beside this suite defines, and a requirement
# no check reaches points at the runbook.md it is verified by once that is
# written. The section "this suite's header names every file it checks" holds
# this paragraph to settings.json, to the disk and to what the suite reads.
#
# A hook is a process, so the only way to test its verdict is to run it; what
# the rule against calling the function under test forbids is deriving the
# expectation from it. So every verdict below is written as a literal BLOCK or
# ALLOW, and every check that reads a file instead holds it to a literal
# written here or to another file it must agree with.
#
# Check, not probe: every expected verdict is written out in advance, so this
# suite asserts rather than measures. The measuring is scripts/probe_*.py, whose
# answers are not known until they run. CONTEXT.md holds the distinction.
#
# The heredoc checks exist because an earlier version of these hooks blocked the
# commit that introduced them: grep anchors ^ per line, so a wrapped line of a
# commit message naming a refused command read as a command position. The
# indentation and wrapper checks come from the review on PR #35.
#
# The control-word, here-string, <<- , bare-push and gh api checks come from a
# second review of the same branch, and the quoted-<<, bundled-flag,
# flag-before-subcommand and gh api close/release checks from a third. Between
# them those reviews found eight ways past the boundary that this suite did not
# ask about, and it was green before each round. Worth saying plainly rather
# than counting: the suite passed while `if true; then git push --mirror origin;
# fi` was permitted, and passed again while a commit message mentioning `<<EOF`
# blinded both hooks for the rest of the command.
#
# The redirect checks come from a fourth review, of PR #48, and are the first
# of these to name a defect in the refusing direction rather than the
# permitting one: every redirect on an otherwise permitted push was refused,
# because nothing removed redirections and the operator read as a refspec. It
# survived three rounds of review for that reason -- it refuses too much, and
# the workaround is to drop the redirect -- and was filed anyway, because the
# question it gets wrong is the one lib/command-scan.sh exists to answer once.
#
# The quoted-separator checks come from a fifth review, of dev-05, and are the
# second group to name a defect in the refusing direction. They are also the
# first whose cost lands on the work of editing these files: cs_split cut on a
# separator inside quotes, so an ordinary `sed -i` substitution written with |
# as its delimiter yielded a push that does not exist, and it fired twice in a
# live session against that session's own edits. The pairs matter more than the
# individual verdicts there -- the anchored and unanchored spellings of one
# substitution are pinned side by side, because it was the anchor that decided
# the verdict and that is the part that reads as arbitrary.
#
# Issue #69 brought the first checks here that are not about the boundary at
# all. Four hooks carry a CLAUDE.md convention rather than the agent boundary --
# pytest-via-uv-group.sh, alembic-via-uv-group.sh, append-only-docs.sh and its
# Edit companion -- and three of the four had no coverage whatever. What the
# sweep found in them is the finding this suite keeps making: the reported
# defect was in the refusing direction, and the serious ones were in the other.
#
# The refusing one is that neither uv-group hook sourced lib/command-scan.sh,
# so a name matched as an argument or as prose and an ordinary
# `grep -rn pytest docs/` was refused. Intermittently, which is the part worth
# pinning: the match needed a separator before the name, so a quoted mention
# was permitted or refused according to whether a quote or a space happened to
# sit in front of it. Those pairs are checked side by side.
#
# The permitting ones were in the append-only guarantee. `rm -rf docs/dev-log`
# was permitted while `rm -rf docs/dev-log/`, one character away, was refused;
# truncate and tee overwrote an entry without naming a redirect; and every
# spelling of an entry's path that did not reduce to the one literal prefix the
# Edit companion stripped was permitted on a file that exists. None of the
# three was in the original report of that issue, and none had a check.
#
# So a green run is not a measure of the boundary. A check suite is evidence
# about the cases it names and about nothing else, and every case here was
# named by someone who went looking for one it had missed.
#
# Issue #106 is the first attempt to widen that sentence rather than repeat it.
# Nearly every defect above was a SPELLING of a command already judged correctly
# -- indentation, a flag before the subcommand, a redirect read as a refspec, a
# separator inside quotes, sudo in front of a wrapper -- so the invariance
# families near the foot of this suite take a seed command with a literal verdict,
# rewrite it under a fixed list of transformations, and assert that every variant
# reaches the seed's verdict or one declared beside it with its reason. It is
# still evidence about the cases it names: the transformations are a list someone
# wrote. What it changes is the cost of the next one, which is asked of every seed
# at once rather than of the command whose review found it. Its first run found
# four defects -- #134, #135, #136 and #139, three of them in the permitting
# direction -- and this suite was green before each. Two of the four needed a
# transformation widened before they appeared, which is this section's own
# thesis one level up and is recorded where each widening stands.
#
# The base checks come from issue #40 rather than from a review: all four
# spellings that create or retarget a pull request were permitted, and the
# quietest of them named nothing at all -- with no base given, a pull request
# goes to the repository's default branch, which is main. They are grouped by
# what they establish rather than by spelling, because a rule that held for
# gh pr create and not for gh api would be the defect that ticket was filed
# against. Each was mutation-checked: weakening the dev-NN test, dropping the
# missing-base refusal, dropping either gh api rule, and dropping the wrapper
# rule each turn a named group of them red.
#
# No expectation here depends on where the suite is run. One used to: whether
# pushing "this branch" was permitted was read off the invoker's own checkout,
# held in a variable and announced by a banner, and most no-git-push.sh checks
# ran with the invoker's working directory. Issue #94 is what that cost. Run
# from the main checkout, which normally sits on a reserved branch, every own-branch
# push was refused by the reserved-branch rule as well, so a mutant that
# permitted the main checkout outright left this suite green; and the rules
# behind that refusal were exercised only when someone happened to run the
# suite from a linked worktree, where the issue's mutants turned it red 95
# times against 0 from the main checkout. The banner decided which run had
# happened by comparing `git rev-parse --git-dir` with `--git-common-dir` as
# strings, the very comparison the defect was in.
#
# So every no-git-push.sh check now runs in a named directory of one fixture
# this suite builds -- a main checkout on an ordinary branch and a linked
# worktree, with a subdirectory two levels deep in each, and a symlink to each
# -- which is PUSH_MAIN and PUSH_WT below. no-work-on-stale-branch.sh checks
# already ran in named fixtures of their own, one per lifecycle state, because
# a stale branch, a merged one and a diverged dev branch cannot share one
# repository; #94 adds the subdirectories and the symlink to the lifecycle
# fixture, where the main checkout and the stale worktree stand.
#
# no-commit-to-main.sh is checked in two classes, because issue #43 rebuilt it
# on lib/command-scan.sh and did not preserve its behaviour -- that file's
# behaviour included its defects. The invariant class is written in identical
# literals on both sides of the migration and pins what was preserved, which is
# the file's purpose. The defective class names what it got wrong before, and
# each of those checks carries the verdict it used to return: `ok ALLOW (was
# BLOCK)` is the migration's evidence, and reverting the file turns exactly
# those red with `got` equal to the recorded `was`. An all-green run on both
# sides would have been evidence that the migration changed nothing. Sixteen
# invariants, eighteen flips, and four that name which refusal fired. The two
# that had this file fail closed without its library are no longer in that class
# or in this section: issue #84 found the same question asked of one hook of four
# and one function of three, and moved it to the load-contract section at the foot
# of this suite, which drives six checks for this file alone.
#
# A review of the migration found eight more permitting verdicts of the same
# kind, seven of them shapes an agent writes without meaning anything by them:
# `git push -u origin HEAD` from main, `git checkout main && git commit`,
# `sudo` and `timeout` in front of either, `git --git-dir <path>` in its
# separated spelling, and the file permitting everything when its library was
# not beside it. Four of those were fixed in lib/command-scan.sh rather than
# here, and they were holes in no-git-push.sh too. That is the ninth review
# round on these files to find something the suite did not ask about.
#
# Some of those checks depend on which branch is checked out where the hook
# runs, and one on the difference between that and where the command would run.
# They are run with the hook's working directory inside a throwaway repository
# on main or on a dev branch rather than in this one, because this one is
# neither. `git branch --show-current` reports an unborn branch, so the
# fixtures need no commits.
#
# Issue #98 is about the evidence rather than the hooks: a hook that crashed, or
# was never found, passed every ALLOW-expecting check here. The comments beside
# several fixture guards named that for the one cause each guarded; nothing named
# the class. Every helper that runs a hook now reads its exit status one way --
# exit 0 is ALLOW, exit 2 is BLOCK, anything else FAILs the check whatever it
# expected -- and `verdict`, below, is where that is answered and argued.
#
# Run: bash .claude/hooks/check-hooks.sh
#      bash .claude/hooks/check-hooks.sh --matrix   the requirements matrix, issue #104
#      CHECK_HOOKS_DIR=<dir> bash .claude/hooks/check-hooks.sh
#          judge the hooks in <dir> instead of the ones beside this file, which is
#          how mutate-hooks.sh runs this suite against a mutated copy (#107).
#          A relative path is read from where the caller stood, not from here.
#
# WHERE THE CALLER STOOD, kept before the cd below moves this process into
# .claude/hooks/. An override spelled relatively means "relative to me", and
# resolving it after that cd made `CHECK_HOOKS_DIR=lib` name this repository's
# own lib/ -- a directory that is there, so the run would have gone on and
# judged it. Found by Bertan's review of PR #142. mutate-hooks.sh passes an
# absolute path and never saw it, which is the half of this override no harness
# exercises.
INVOKED_FROM=$PWD
cd "$(dirname "$0")" || exit 1
# TWO DIRECTORIES, ONE OF THEM BY DEFAULT THE OTHER. $HOOKS is what is JUDGED:
# the hook files run as processes, the library they source, the text of each and
# requirements.md beside them. $SUITE_DIR is what they are judged AGAINST and
# where this file itself lives: settings.json, CLAUDE.md, CONTEXT.md, the two
# skills, and this suite's own text. Every path below is one or the other on
# purpose, and the split is what #107's harness needs -- it copies the hooks to
# a temporary directory, breaks one rule there and asks this suite whether
# anything goes red, and the documents that copy is held to have to be this
# repository's rather than copies nobody edits.
#
# Three things stay on the SUITE side that read as though they belong on the
# other, and each would be a check about a file nothing ran:
#   - this file. $HOOKS/check-hooks.sh under an override is a copy that is not
#     the program running, so the self-audits below -- the header naming every
#     file, `pass` and `fail` being the only printers -- would be evidence about
#     text nobody executed.
#   - the working directory a hook is run in. It has to be inside a git
#     repository, because half the verdicts here are read off `git branch
#     --show-current` and the branch state around it; a temporary copy is not
#     one. So `check` and `inv_dir hooks` run in this directory and invoke the
#     hook out of $HOOKS.
#   - $REPO_ROOT and every document derived from it.
SUITE_DIR=$(pwd)
HOOKS=$SUITE_DIR
# THE TOOLING BESIDE THE HOOKS: the files in .claude/hooks/ that are not hooks
# and are not judged as ones. This suite, and the harness that runs it against a
# copy of the rest. One list, because three questions that read it are one fact
# -- neither file is executed from $HOOKS, whatever an override says. Neither is
# a tokeniser consumer though both name the library in code; neither can be a
# mutation target, because the copy's text of either would be read and never
# run; and the text of both is read off $SUITE_DIR below rather than off $HOOKS.
# It was three separate spellings of that one fact before Bertan's review of
# PR #142, and the one it did not have was the middle one: mutate-hooks.sh was
# an accepted mutation target, judged on text nobody executed.
TOOLING="check-hooks.sh mutate-hooks.sh"
# An override that names a directory missing one of the files beside this suite
# would turn most of this suite red for that reason, and a harness reading the
# result would count every mutation as caught -- its permitting direction. So
# the files are derived off this directory and each one required over there,
# and a missing one stops the run rather than failing a check.
if [ -n "${CHECK_HOOKS_DIR:-}" ]; then
  # CDPATH is cleared for both steps and both are `cd --`: a bare `cd` consults
  # $CDPATH and lands wherever that says, and `cd -` prints $OLDPWD, which would
  # leave $HOOKS a two-line string rather than a path.
  HOOKS=$(CDPATH= cd -- "$INVOKED_FROM" 2>/dev/null \
          && CDPATH= cd -- "$CHECK_HOOKS_DIR" 2>/dev/null && pwd) || {
    echo "CHECK_HOOKS_DIR=$CHECK_HOOKS_DIR is not a directory; nothing was judged" >&2
    exit 1
  }
  for f in "$SUITE_DIR"/*.sh "$SUITE_DIR"/lib/*.sh "$SUITE_DIR"/*.md; do
    [ -r "$f" ] || continue
    [ -r "$HOOKS/${f#"$SUITE_DIR"/}" ] || {
      echo "CHECK_HOOKS_DIR=$HOOKS does not hold ${f#"$SUITE_DIR"/}, which is beside this suite; the checks against it would prove nothing" >&2
      exit 1
    }
  done
fi

case "${1:-}" in
  '') MATRIX= ;;
  --matrix) MATRIX=1 ;;
  *) echo "usage: bash .claude/hooks/check-hooks.sh [--matrix]" >&2; exit 64 ;;
esac
# With --matrix the check lines go nowhere and the matrix is what is printed, on
# the stdout this line keeps as fd 3. A fixture guard still speaks on stderr.
if [ -n "$MATRIX" ]; then exec 3>&1 >/dev/null; fi

FAILED=0
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
# section derives that from this file. Each takes the direction of the check,
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
LEDGER=
REQ=
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
RAN=
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

# Two throwaway repositories, one on main and one on a dev branch, so that a
# hook reading `git branch --show-current` can be asked both questions from a
# suite that runs on neither. They hold no commits and no remotes: an unborn
# branch is still reported by name, and nothing here reaches a remote.
FIXTURES=$(mktemp -d)
trap 'rm -rf "$FIXTURES"' EXIT
LEDGER="$FIXTURES/ledger"
: > "$LEDGER"
RAN="$FIXTURES/ran"
: > "$RAN"
git init -q -b main "$FIXTURES/on-main"
git init -q -b dev-99 "$FIXTURES/on-dev"
ON_MAIN="$FIXTURES/on-main"
ON_DEV="$FIXTURES/on-dev"
# An unmade fixture makes ( cd "$dir" && hook ) return 1, which `verdict` FAILs
# (see there for when it did not). The guard stays so that it is reported once,
# as what it is, rather than as a column of FAILs each blaming its own check.
# `git init -b` needs git 2.28.
[ -d "$ON_MAIN/.git" ] && [ -d "$ON_DEV/.git" ] || {
  echo "fixtures were not created; git init -b needs git 2.28 or newer" >&2
  exit 1
}

# Where no-git-push.sh checks run: issue #94. A main checkout and a linked
# worktree of one repository, each with a subdirectory two levels deep, so that
# the one thing that separates a permitted push from a refused one -- where the
# command runs -- is a named directory rather than wherever the suite was
# started from.
#
# The main checkout is on an ordinary branch and not on main. On main a push is
# refused by the reserved-branch rule as well, so a main checkout mistaken for a
# linked worktree would still be refused and the mistake would not show; on
# feature-x the main-checkout refusal is the only thing standing between the
# command and a permitted push, which is what makes a check of it evidence.
#
# origin exists because the hook requires the first bare argument of a push to
# be a remote of this repository. Nothing here ever reaches its URL. One commit,
# because `git worktree add` needs something to check out.
PUSH_MAIN="$FIXTURES/push-main"
PUSH_WT="$FIXTURES/push-wt"
PUSH_BRANCH=wt-branch
git init -q -b feature-x "$PUSH_MAIN"
GP="git -C $PUSH_MAIN -c user.email=checks@example.invalid -c user.name=checks"
$GP remote add origin "$FIXTURES/unreachable-remote.git"
$GP commit -q --allow-empty -m base
$GP worktree add -q -b "$PUSH_BRANCH" "$PUSH_WT"
mkdir -p "$PUSH_MAIN/src/deep" "$PUSH_WT/src/deep"
# TWO MORE LINKED WORKTREES, STANDING ON THE BRANCHES AN AGENT MAY NOT PUSH.
# Every refusal of main or of a dev branch above comes from the command NAMING a
# branch that is not this worktree's, and none of those worktrees stands on one --
# so the hook's own test of $CURRENT, the two lines that refuse a push from a
# worktree that IS on main or on dev-NN, was reached by no check here. Found by
# registering that rule as a mutation (#107): it survived, with the whole of this
# suite green and 36 checks tagged US-2 among them. Bertan's review of PR #142 is
# why the registry had a row for it to survive.
PUSH_WT_DEV="$FIXTURES/push-wt-dev"
PUSH_WT_MAIN="$FIXTURES/push-wt-main"
$GP branch main
$GP worktree add -q -b dev-05 "$PUSH_WT_DEV"
$GP worktree add -q "$PUSH_WT_MAIN" main
# The same two checkouts reached through a symlink. check_in's `cd` is logical,
# so the hook starts with $PWD naming the link while git reports the real path:
# a canonicalisation that followed $PWD rather than the directory would compare
# the one against the other and read the main checkout as a worktree again.
PUSH_MAIN_LINK="$FIXTURES/push-main-link"
PUSH_WT_LINK="$FIXTURES/push-wt-link"
ln -s "$PUSH_MAIN" "$PUSH_MAIN_LINK"
ln -s "$PUSH_WT" "$PUSH_WT_LINK"
# Every directory guarded: a check against a directory that is not there exits 1
# from the cd, which `verdict` FAILs; this names the directory once, where a
# column of FAILs would each blame its own check. The branch halves are guarded
# too, because a worktree on the wrong branch turns every own-branch ALLOW into a
# refusal for a reason no check names.
for d in "$PUSH_MAIN" "$PUSH_MAIN/src" "$PUSH_MAIN/src/deep" \
         "$PUSH_WT" "$PUSH_WT/src" "$PUSH_WT/src/deep" \
         "$PUSH_MAIN_LINK/src/deep" "$PUSH_WT_LINK/src/deep"; do
  [ -d "$d" ] || {
    echo "the push fixture directory $d was not created; the checks against it prove nothing" >&2
    exit 1
  }
done
# And origin: without it every push is refused as naming no remote, so each
# BLOCK below would pass for that reason rather than the one it names.
[ "$(git -C "$PUSH_MAIN" branch --show-current)" = feature-x ] \
  && [ "$(git -C "$PUSH_WT" branch --show-current)" = "$PUSH_BRANCH" ] \
  && git -C "$PUSH_WT" remote | grep -qx origin || {
  echo "the push fixture is not on feature-x and $PUSH_BRANCH with an origin remote; the checks against it prove nothing" >&2
  exit 1
}
# And the two that stand on the withheld branches. A worktree on the wrong branch
# would turn each refusal below into one for a reason no check names, which is
# the whole shape those checks exist to rule out.
[ "$(git -C "$PUSH_WT_DEV" branch --show-current)" = dev-05 ] \
  && [ "$(git -C "$PUSH_WT_MAIN" branch --show-current)" = main ] || {
  echo "the push fixtures standing on dev-05 and main are not on those branches; the checks against them prove nothing" >&2
  exit 1
}
# The nolib and halflib fixtures are built beside the checks that drive them, at
# the foot of this suite. They were here, and one hook of four was copied into
# them; see the load-contract section for why that question is asked in one place
# now.

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
# It covers nothing. A gap's tags are the requirement its issue owns, which
# requirements.md marks `gap → #<n>`, so the #104 coverage check does not ask
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
# no spelling can hide from: the derivation in the #107 section reads this file's
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

# The library UNDER CHECK, not the one beside this file: the checks below call
# its functions directly, and under #107's override the copy being judged is the
# one they have to call.
. "$HOOKS/lib/command-scan.sh"

# A property of two files at once, which is what `armed` cannot express: it
# asks whether a file contains a constant, never whether two files agree. These
# two read what a file actually derives, so the copies can be compared with each
# other. Anchored on content rather than on a line range -- a line range goes
# stale the moment either file gains a line above it, and goes stale silently --
# and on what the derivation reads rather than on the name it assigns, so a
# second reader of those refs is counted rather than hidden behind the first.
#
# Two limits, both named because a check is evidence about what it names. The
# count finds readers spelled with for-each-ref, so one written as
# `git branch -r` would read the same refs uncounted -- the permitting
# direction, and the reason the pin below is there too. And it counts matching
# lines anywhere in the file, comments included, so quoting the pipeline in
# either hook's header turns the suite red although nothing has changed: the
# refusing direction, visible and one edit away.
dev_read_count() {  # dev_read_count <file> -- how many lines read the dev refs
  grep -cE 'for-each-ref.*refs/remotes/origin/dev-' "$1" 2>/dev/null
}

# `drift`'s "not reported" case arm, as written. Anchored on `null) ` rather
# than on the whole pattern so that a mutated arm is still extracted and shown
# in the diff, instead of extracting to nothing and failing as an absence.
unread_arm() {  # unread_arm <file> -- the arm that records a gap, as written
  awk '/null\) / { a = 1 }
       a          { print }
       a && /;;$/ { exit }' "$1" 2>/dev/null
}

dev_derivation() {  # dev_derivation <file> -- the derivation, as written
  awk '/for-each-ref.*refs\/remotes\/origin\/dev-/ { inblock = 1 }
       inblock                                      { print }
       inblock && /tail -1\)/                       { inblock = 0 }' \
      "$1" 2>/dev/null
}

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

beside() {  # beside <label> <file> <literal>
  if dev_pointer "$2" | grep -qF -- "$3"; then
    pass static 'beside %s' "$1"
  else
    fail static '%s\n         expected the comment above the derivation in %s\n         to contain |%s|' \
           "$1" "$2" "$3"
  fi
}

# A guard for the one check below that compares two numbers rather than
# matching a literal. An absent derivation must not reach `[ -gt ]`, which
# errors rather than answering.
numeric() { case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }

tok() {  # tok <label> <expected> <actual>
  if [ "$3" = "$2" ]; then
    pass static '%s' "$1"
  else
    fail static '%s\n         want |%s|\n         got  |%s|' "$1" "$2" "$3"
  fi
}

section "=== the tokeniser itself ==="
# Every defect on PR #35 was one question -- how far around a matched token to
# look -- answered differently in a different place. It is answered once in
# lib/command-scan.sh, so these aim at it rather than through a hook.
req FR-3
tok 'split on ; && || |' \
    'a
b
c
d' \
    "$(printf 'a && b; c | d\n' | cs_split)"
tok 'split on a subshell paren' \
    'a
b' \
    "$(printf 'a && (b)\n' | cs_split)"
tok 'split on backticks, the twin of $( )' \
    'echo
git push --mirror origin' \
    "$(printf 'echo `git push --mirror origin`\n' | cs_split)"
tok 'environment assignments removed' \
    'git push' \
    "$(printf 'GIT_DIR=/x FOO=1 git push\n' | cs_split)"
# The wrapper word and its options go, and the tail follows as further
# candidates -- see the note in cs_split. They cost nothing here: a line that
# does not begin with a command word matches no rule.
tok 'wrapper word and its options removed' \
    'git push --mirror
push --mirror
--mirror' \
    "$(printf 'xargs -n1 git push --mirror\n' | cs_split)"
# The value of a wrapper option that takes one is not an option, so the strip
# stops in front of it and the command word is no longer at ^. The tail is what
# finds it.
tok 'a wrapper option value does not hide the command' \
    'root git push --all origin
git push --all origin
push --all origin
--all origin' \
    "$(printf 'sudo -u root git push --all origin\n' | cs_split)"
# The tail stops at a token opening a quote: what follows is the text of an
# argument, and a commit message naming a push is not a push.
tok 'the tail stops where a quoted argument starts' \
    'git commit -m "git push --all origin"
commit -m "git push --all origin"
-m "git push --all origin"' \
    "$(printf 'sudo git commit -m "git push --all origin"\n' | cs_split)"
tok 'continuation joined before anything else' \
    'git push   --all origin' \
    "$(printf 'git push \\\n  --all origin\n' | cs_normalise)"
# The joining half on its own, for a caller that wants it without the heredoc
# drop -- no-pr-decisions.sh reads raw text because `bash <<EOF` is a wrapper
# whose payload the drop would take with the body. Same joining as the line
# above, written as the same literal, because it is the same code.
tok 'cs_join joins a continuation' \
    'git push   --all origin' \
    "$(printf 'git push \\\n  --all origin\n' | cs_join)"
# And leaves a heredoc body where it stands, which is the whole difference.
tok 'cs_join keeps a heredoc body' \
    'cat > f <<EOF
gh pr merge 5
EOF' \
    "$(printf 'cat > f <<EOF\ngh pr merge 5\nEOF\n' | cs_join)"
# The one expectation issue #50 changed. It pins that the body is dropped and
# that `echo after` survives, which is what it has always been about; the `> f`
# is gone from the opener because cs_normalise now drops redirections too.
tok 'heredoc body dropped' \
    'cat <<EOF
echo after' \
    "$(printf 'cat > f <<EOF\ngit push origin main\nEOF\necho after\n' | cs_normalise)"
tok 'here-string is not a heredoc' \
    'cat <<< "hello"
gh pr merge 35' \
    "$(printf 'cat <<< "hello"\ngh pr merge 35\n' | cs_normalise)"
tok 'dash-heredoc ends on a tab-indented terminator' \
    'cat <<-EOF
gh pr merge 35' \
    "$(printf 'cat <<-EOF\n\thello\n\tEOF\ngh pr merge 35\n' | cs_normalise)"
tok 'unterminated heredoc gives its lines back' \
    'git commit -m "fix <<EOF handling"
    git push --all origin' \
    "$(printf 'git commit -m "fix <<EOF handling"\n    git push --all origin\n' | cs_normalise)"
# Issue #128, read here as output before it is read below as verdicts. An opener
# whose own line ends in a backslash is a continued line to bash, which joins it
# before the body begins -- so the body of `cat <<E \` / `x` / `E` is empty and
# the command after `E` runs. The drop took `x` for the body, ended it at `E`,
# and cs_join then glued that command onto the opener line, where it stands at
# no command position: this output was `cat <<E git push --force origin main`,
# one line, and every hook reading it permitted the push.
#
# The push standing at the head of a line of its own is the whole of the fix,
# and each of these says which line it is on.
req GH-128
tok 'a continued opener ends its logical line before the body begins' \
    'cat <<E x
git push --force origin main' \
    "$(printf 'cat <<E \\\nx\nE\ngit push --force origin main\n' | cs_normalise)"
tok 'an opener continued twice, and the body still starts after the line' \
    'cat <<E -n -E
git push --force origin main' \
    "$(printf 'cat <<E \\\n-n \\\n-E\nx\nE\ngit push --force origin main\n' | cs_normalise)"
# The body is still dropped, so the fix did not simply stop dropping: a quoted
# body whose lines end in a backslash ends at its terminator, where bash ends it
# too, and cs_join never sees those lines to join them.
tok 'a body line ending in a backslash is not joined past its terminator' \
    "cat <<'E'
git push --force origin main" \
    "$(printf "cat <<'E'\nprose \\\\\nE\ngit push --force origin main\n" | cs_normalise)"
tok 'a body naming a push on a continued line is still dropped' \
    "cat <<'E'" \
    "$(printf "cat <<'E'\ngit push --force origin main \\\\\nE\n" | cs_normalise)"
# THE TWO PLACES A TRAILING BACKSLASH IS READ, and what happens where they
# disagree. cs_join joins a line ending in ANY backslash, deliberately and
# unchanged; bash continues a line only when the run is ODD. The drop follows
# bash, so the two disagree exactly on an even run -- and an even run is then
# the line a body starts after, which is the one line where cs_join could glue
# the first line past the terminator onto it. So the drop takes the run off.
#
# The first version of this fix used cs_join's looser rule in the drop instead
# and argued that looser was the safe side. It is not: holding the line open
# moves the terminator search forward, a delimiter line bash took as the whole
# terminator is scanned past, and the body runs to the NEXT delimiter, dropping
# what lies between. The shape below is that defect, measured at exit 0 on the
# first version and exit 2 on dev-05, and it is checked here as output and
# below as verdicts.
#
# Each pair is the same run read twice, once through cs_join and once through
# cs_normalise, so a change to either rule moves one literal of a pair.
tok 'cs_join joins an even run, which bash does not' \
    'cat <<E \x' \
    "$(printf 'cat <<E \\\\\nx\n' | cs_join)"
tok 'so the drop ends the logical line there and takes the run off' \
    'cat <<E
git push --force origin main' \
    "$(printf 'cat <<E \\\\\nE\ngit push --force origin main\n' | cs_normalise)"
tok 'the swallowed-terminator shape, which the first fix emptied' \
    'cat <<E
echo after
git push --force origin main
E' \
    "$(printf 'cat <<E \\\\\nE\necho after\ngit push --force origin main\nE\n' | cs_normalise)"
tok 'an odd run of three is a continuation to both of them' \
    'cat <<E \\x' \
    "$(printf 'cat <<E \\\\\\\nx\n' | cs_join)"
tok 'and the drop defers the body over it' \
    'cat <<E \\x
git push --force origin main' \
    "$(printf 'cat <<E \\\\\\\nx\nE\ngit push --force origin main\n' | cs_normalise)"
# Redirections. A redirect is not an argument, and nothing removed it, so its
# operator or its target was read as a refspec and every redirect on an
# otherwise permitted push was refused. Issue #50.
#
# The two that come first are the ones the drop must not get wrong, because
# they are the ones where it would hide something: a process substitution
# carries a command, and a redirect inside quotes is text. Both are written
# before the drops themselves for that reason.
req GH-50.2
tok 'process substitution is not a redirect, <(' \
    'cat <(git push --all origin)' \
    "$(printf 'cat <(git push --all origin)\n' | cs_normalise)"
tok 'process substitution is not a redirect, >(' \
    'tee >(git push --all origin)' \
    "$(printf 'tee >(git push --all origin)\n' | cs_normalise)"
# The process substitution is tested before the fd digits are taken, so a digit
# standing in front of one does not turn it into a redirect and take the
# command with it.
tok 'process substitution behind an fd digit' \
    'cat 2>(git push --all origin)' \
    "$(printf 'cat 2>(git push --all origin)\n' | cs_normalise)"
tok 'a redirect inside double quotes is text' \
    'git commit -m "redirect 2>/dev/null in the notes"' \
    "$(printf 'git commit -m "redirect 2>/dev/null in the notes"\n' | cs_normalise)"
tok 'a redirect inside single quotes is text' \
    "git commit -m 'see > out.txt and 2>&1'" \
    "$(printf "git commit -m 'see > out.txt and 2>&1'\n" | cs_normalise)"
tok 'an escaped operator is not a redirect' \
    'echo a \> b' \
    "$(printf 'echo a \\> b\n' | cs_normalise)"
# A target that is a command substitution is not a target at all. Without the
# backtick and the paren ending the target scan, the command inside would be
# swallowed with it -- the same mistake as hiding a process substitution.
tok 'a backticked target ends the target scan' \
    'echo `git push --all origin`' \
    "$(printf 'echo > `git push --all origin`\n' | cs_normalise)"
tok 'a $( ) target ends the target scan' \
    'echo $(git push --all origin)' \
    "$(printf 'echo > $(git push --all origin)\n' | cs_normalise)"
# Now the drops. Every spelling, with and without a space before the target.
req GH-50.1
tok 'redirect dropped, > with a space' \
    'git push origin b' \
    "$(printf 'git push origin b > out.txt\n' | cs_normalise)"
tok 'redirect dropped, > with no space' \
    'git push origin b' \
    "$(printf 'git push origin b >out.txt\n' | cs_normalise)"
tok 'redirect dropped, >> with a space' \
    'git push origin b' \
    "$(printf 'git push origin b >> push.log\n' | cs_normalise)"
tok 'redirect dropped, >> with no space' \
    'git push origin b' \
    "$(printf 'git push origin b >>push.log\n' | cs_normalise)"
tok 'redirect dropped, 2> with a space' \
    'git push origin b' \
    "$(printf 'git push origin b 2> /dev/null\n' | cs_normalise)"
tok 'redirect dropped, 2> with no space' \
    'git push origin b' \
    "$(printf 'git push origin b 2>/dev/null\n' | cs_normalise)"
tok 'redirect dropped, 2>> with a space' \
    'git push origin b' \
    "$(printf 'git push origin b 2>> push.log\n' | cs_normalise)"
tok 'redirect dropped, 2>> with no space' \
    'git push origin b' \
    "$(printf 'git push origin b 2>>push.log\n' | cs_normalise)"
tok 'redirect dropped, &> with a space' \
    'git push origin b' \
    "$(printf 'git push origin b &> out.txt\n' | cs_normalise)"
tok 'redirect dropped, &> with no space' \
    'git push origin b' \
    "$(printf 'git push origin b &>out.txt\n' | cs_normalise)"
tok 'redirect dropped, >& with a space' \
    'git push origin b' \
    "$(printf 'git push origin b >& out.txt\n' | cs_normalise)"
tok 'redirect dropped, >& with no space' \
    'git push origin b' \
    "$(printf 'git push origin b >&out.txt\n' | cs_normalise)"
tok 'redirect dropped, a leading < with a space' \
    'cat' \
    "$(printf 'cat < input.txt\n' | cs_normalise)"
tok 'redirect dropped, a leading < with no space' \
    'cat' \
    "$(printf 'cat <input.txt\n' | cs_normalise)"
tok 'redirect dropped, two of them' \
    'git push origin b' \
    "$(printf 'git push origin b >/dev/null 2>&1\n' | cs_normalise)"
# The fd belongs to the operator, so it goes with it; the pipe does not, and
# staying is the whole point -- it is what still shows tail as a command.
tok 'the pipe after 2>&1 survives the drop' \
    'git push origin b | tail -3' \
    "$(printf 'git push origin b 2>&1 | tail -3\n' | cs_normalise)"
# A digit is an fd only when it is a word of its own. `origin b2` is a token
# that happens to end in one, and taking the 2 would change the refspec.
tok 'a digit attached to a word is not an fd' \
    'git push origin b2' \
    "$(printf 'git push origin b2>out.txt\n' | cs_normalise)"
# && is a separator, not the & of &>. The strip only reaches a & that touches
# the operator, so the spelling that exercises the guard is the adjacent one --
# and the spaced spelling is here beside it to say the strip never fires there.
# No hook verdict turns on this pair: cs_split breaks on a single & as readily
# as on a double one, so a separator half-eaten still ends the command. It is
# pinned at the tokeniser because that is where the rule is written, and the
# rule is that the strip takes the & of &> and never a separator.
tok 'an adjacent && is not the & of &>' \
    'git push origin b &&' \
    "$(printf 'git push origin b &&> out.txt\n' | cs_normalise)"
tok 'a spaced && is not touched at all' \
    'git push origin b &&' \
    "$(printf 'git push origin b && > out.txt\n' | cs_normalise)"
# << <<- <<< are the heredoc pass's question, answered above. This pass leaves
# them alone rather than answering it a second time and differently.
# Quote state is per line, so a string left open at a newline protects nothing
# on the line after it. That can only drop more, never less, and dropping more
# of a line already inside quotes changes no verdict -- but it is behaviour, so
# it is named rather than left to be discovered.
tok 'quote state does not carry across a newline' \
    'echo "unclosed
cat' \
    "$(printf 'echo "unclosed\ncat > f\n' | cs_normalise)"
# >| is the clobber operator. The | is not consumed with it, so the target
# becomes a command candidate of its own -- over-splitting, which can only
# refuse more, and preferred to eating a | that is a separator everywhere else.
tok '>| leaves its pipe standing' \
    'git push origin b | out.txt' \
    "$(printf 'git push origin b >| out.txt\n' | cs_normalise)"
req GH-50.2 FR-3
tok 'the heredoc operator survives the redirect drop' \
    'cat <<EOF' \
    "$(printf 'cat <<EOF\nbody\nEOF\n' | cs_normalise)"
tok 'the here-string operator survives the redirect drop' \
    'cat <<< "hello"' \
    "$(printf 'cat <<< "hello"\n' | cs_normalise)"
req FR-3
tok 'control word removed, then/fi' \
    'true
git push --mirror origin' \
    "$(printf 'if true; then git push --mirror origin; fi\n' | cs_split)"
tok 'control word removed, brace group' \
    'git push --mirror origin' \
    "$(printf '{ git push --mirror origin; }\n' | cs_split)"
# Issue #68. The separator pass cut with a plain character class that knew
# nothing about quoting, so a | inside a quoted argument was a fragment
# boundary like any other and the second fragment of a sed substitution was a
# push standing at the head of its own line. Each of these is one fragment now.
#
# The firing and the non-firing spellings are pinned side by side because the
# pair is the evidence: the fragment had to BEGIN with the command word, so a ^
# in the pattern saved the command by accident and a leading space did not.
# Two commands doing the same job, one refused and one not, on a difference
# that has nothing to do with what either would run.
req GH-68.1
tok 'a sed delimiter is not a separator' \
    "sed -i 's|git push --all origin|X|' f.sh" \
    "$(printf "sed -i 's|git push --all origin|X|' f.sh\n" | cs_split)"
tok 'the anchored spelling is the same one fragment' \
    "sed -i 's|^git push --all origin|X|' f.sh" \
    "$(printf "sed -i 's|^git push --all origin|X|' f.sh\n" | cs_split)"
tok 'and so is the leading-space spelling that used to fire' \
    "sed -i 's| git push --all origin|X|' f.sh" \
    "$(printf "sed -i 's| git push --all origin|X|' f.sh\n" | cs_split)"
tok 'a grep alternation is not a separator' \
    "grep -rn 'git push --all|git push -f' .claude/" \
    "$(printf "grep -rn 'git push --all|git push -f' .claude/\n" | cs_split)"
tok 'the commit spelling of the same shape' \
    "sed -i 's|git commit -m x|X|' f.sh" \
    "$(printf "sed -i 's|git commit -m x|X|' f.sh\n" | cs_split)"
tok 'the anchored commit spelling, likewise one fragment' \
    "sed -i 's|^git commit -m x|X|' f.sh" \
    "$(printf "sed -i 's|^git commit -m x|X|' f.sh\n" | cs_split)"
tok 'the forced-push spelling' \
    "sed -i 's|git push -f origin main|X|' f.sh" \
    "$(printf "sed -i 's|git push -f origin main|X|' f.sh\n" | cs_split)"
tok 'the bare-push spelling' \
    "sed -i 's|git push|X|' f.sh" \
    "$(printf "sed -i 's|git push|X|' f.sh\n" | cs_split)"
tok 'the grep alternation over a commit and a push' \
    "grep -n 'git commit|git push origin main' *.sh" \
    "$(printf "grep -n 'git commit|git push origin main' *.sh\n" | cs_split)"
# The checks above exercise | ; ( and ). The other two separators were right and
# unpinned, and both have a real spelling: & is a legal sed delimiter, and a
# backtick inside SINGLE quotes is text to bash, where inside double quotes it
# would run. Found by review of this change.
tok 'an ampersand inside quotes is not a separator' \
    "sed -i 's&git push --all origin&X&' f.sh" \
    "$(printf "sed -i 's&git push --all origin&X&' f.sh\n" | cs_split)"
tok 'a backtick inside single quotes is not a separator' \
    "grep -rn '\`git push --all origin\`' docs/" \
    "$(printf "grep -rn '\`git push --all origin\`' docs/\n" | cs_split)"
# Double quotes protect a delimiter too. They protect only the separators,
# never a substitution -- see the two below.
tok 'a delimiter written with double quotes' \
    'sed -i "s|git push --all origin|X|" f.sh' \
    "$(printf 'sed -i "s|git push --all origin|X|" f.sh\n' | cs_split)"
# A closed quote restores the separator. A tracker that treated everything
# after the first quote as quoted would convert issue #68 into a real hole.
req GH-68.2
tok 'a closed quote reopens the separator' \
    'echo "a"
git push --all origin' \
    "$(printf 'echo "a" | git push --all origin\n' | cs_split)"
# The two fallbacks, both of which split exactly as the plain character class
# did. Unbalanced quoting is text this cannot read.
tok 'unbalanced quoting falls back to the old splitting' \
    "echo 'unclosed
git push --all origin" \
    "$(printf "echo 'unclosed | git push --all origin\n" | cs_split)"
# And a double-quoted span is not inert: a command substitution inside one RUNS,
# so a line carrying one goes to the same fallback rather than being protected.
# Getting this wrong would have hidden every command written that way, silently
# and in the permitting direction.
tok 'a substitution in double quotes still splits out' \
    'echo "$
gh pr merge 5
"' \
    "$(printf 'echo "$(gh pr merge 5)"\n' | cs_split)"
tok 'a backticked span in double quotes still splits out' \
    'echo "
git push --all origin
"' \
    "$(printf 'echo "`git push --all origin`"\n' | cs_split)"
# Single quotes need no such exception -- bash runs nothing inside them -- and
# an escaped substitution in double quotes is text, which is why the backslash
# is read before the substitution is looked for.
req GH-68.1
tok 'a substitution inside single quotes is text' \
    "grep -n 'git push|\$(x)' ." \
    "$(printf "grep -n 'git push|\$(x)' .\n" | cs_split)"
tok 'an escaped substitution in double quotes is text' \
    'git commit -m "release \$(date) notes"' \
    "$(printf 'git commit -m "release \\$(date) notes"\n' | cs_split)"
# The backslash is read for that one purpose. An escaped separator outside
# quotes still cuts, exactly as it did before, which is the refusing direction.
req GH-68.2
tok 'an escaped separator outside quotes still cuts' \
    'echo a \
git push --all origin' \
    "$(printf 'echo a \\| git push --all origin\n' | cs_split)"
# The other arm of that branch, which the check above does not reach: an escaped
# quote outside quotes must not OPEN one. Without this the sed argument that
# follows sits inside a double quote that never closes, the line is unbalanced,
# and the fallback splits it into a bare push -- so this pair is the check that
# fails without the escape branch. Every other escape shape tried gave the same
# answer with the branch and without it, because the fallback agrees with the
# protected split whenever the quoting is simple.
tok 'an escaped quote outside quotes does not open one' \
    'sed -e s/\"/Q/ -e '"'"'s|git push|X|'"'"' f.sh' \
    "$(printf 'sed -e s/\\"/Q/ -e %ss|git push|X|%s f.sh\n' "'" "'" | cs_split)"
req GH-68.1
check_in "$PUSH_WT" no-git-push.sh ALLOW 'and the same command is not a push' \
         'sed -e s/\"/Q/ -e '"'"'s|git push|X|'"'"' f.sh'
req FR-3 US-3
tok 'git args, plain' 'origin main' "$(printf 'git push origin main\n' | cs_git_args push)"
tok 'git args, global option with a separate value' \
    '--all' "$(printf 'git -C /x push --all\n' | cs_git_args push)"
tok 'git args, empty for a bare push' '' "$(printf 'git push\n' | cs_git_args push)"
if printf 'git push\n' | cs_git_args push >/dev/null; then
  tok 'bare push succeeds, so empty args mean a push' 'found' 'found'
else
  tok 'bare push succeeds, so empty args mean a push' 'found' 'not found'
fi
if printf 'git status\n' | cs_git_args push >/dev/null; then
  tok 'git status is not a push' 'not found' 'found'
else
  tok 'git status is not a push' 'not found' 'not found'
fi

# The gh helper answers the same question one level deeper: gh nests its verbs
# under a group, so the subcommand is a path, and an option sitting between its
# words has to be skipped or the verb is never reached at all. Nothing uses this
# yet -- it is the footing the base rule is built on, rather than a fourth raw
# match over the whole line, which is the shape that produced two of the five
# defects listed at the top of lib/command-scan.sh.
req FR-22
tok 'gh args, plain' '--base dev-05 --title x' \
    "$(printf 'gh pr create --base dev-05 --title x\n' | cs_gh_args 'pr create')"
# Skipping happens before every word of the path, so the two positions are
# pinned separately: a flag before the group, and a flag between the group and
# the verb. Without the first of these, a helper that skipped options only from
# the second word onward passed this whole suite while `gh -R o/r pr create` --
# an ordinary way to work on a repository from another directory -- became
# invisible to it, which is the permitting direction.
tok 'gh args, a flag before the group' \
    '--base main' "$(printf 'gh -R o/r pr create --base main\n' | cs_gh_args 'pr create')"
tok 'gh args, a flag between the group and the verb' \
    '--base main' "$(printf 'gh pr --repo o/r create --base main\n' | cs_gh_args 'pr create')"
tok 'gh args, the repo value attached rather than separate' \
    '35 --base main' "$(printf 'gh pr --repo=o/r edit 35 --base main\n' | cs_gh_args 'pr edit')"
tok 'gh args, a one-word subcommand path' \
    'repos/o/r/pulls -f base=main' \
    "$(printf 'gh api repos/o/r/pulls -f base=main\n' | cs_gh_args api)"
tok 'gh args, empty for a bare create' '' "$(printf 'gh pr create\n' | cs_gh_args 'pr create')"
# An option on a neighbouring command is not this command's own. Scoping that
# question to the whole line is the first of the two defects named above, and
# the neighbour here carries the very flag the base rule will look for.
tok 'gh args, an option on a neighbouring command' '--base dev-05' \
    "$(printf 'gh pr view 35 --base main\ngh pr create --base dev-05\n' | cs_gh_args 'pr create')"
# It answers about the first match and stops, so a caller handed a whole command
# list would never see the second -- the fifth defect in command-scan.sh's list.
# no-git-push.sh loops per command over cs_split's output for exactly that
# reason; this is what obliges the base rule to do the same.
req FR-22 GH-47.2
tok 'gh args, the first match only, and the rest unseen' '' \
    "$(printf 'gh pr create\ngh pr create --base dev-05\n' | cs_gh_args 'pr create')"
req FR-22
if printf 'gh pr create\n' | cs_gh_args 'pr create' >/dev/null; then
  tok 'bare create succeeds, so empty args mean a create' 'found' 'found'
else
  tok 'bare create succeeds, so empty args mean a create' 'found' 'not found'
fi
if printf 'gh pr view 35\n' | cs_gh_args 'pr create' >/dev/null; then
  tok 'gh pr view is not a create' 'not found' 'found'
else
  tok 'gh pr view is not a create' 'not found' 'not found'
fi
# The group is part of the path, so a verb of the same name under another group
# is a different command.
if printf 'gh issue create\n' | cs_gh_args 'pr create' >/dev/null; then
  tok 'gh issue create is not a pr create' 'not found' 'found'
else
  tok 'gh issue create is not a pr create' 'not found' 'not found'
fi
if printf 'git status\n' | cs_gh_args 'pr create' >/dev/null; then
  tok 'a command that is not gh at all' 'not found' 'found'
else
  tok 'a command that is not gh at all' 'not found' 'not found'
fi
# The command word is `gh`, not a prefix of one. Without the word boundary the
# first two letters of `ghpr` are stripped and the rest reads as `pr create`.
if printf 'ghpr create\n' | cs_gh_args 'pr create' >/dev/null; then
  tok 'ghpr is not gh' 'not found' 'found'
else
  tok 'ghpr is not gh' 'not found' 'not found'
fi
# The one-word path needs its exit status pinned too: it is the shape the two
# gh api spellings of the base rule will ask about.
if printf 'gh pr create --base main\n' | cs_gh_args api >/dev/null; then
  tok 'a pr create is not a gh api call' 'not found' 'found'
else
  tok 'a pr create is not a gh api call' 'not found' 'not found'
fi

# THE COMMAND WORD ITSELF, issue #117. Every rule in every hook recognises a
# command by the bare name at the head of what cs_split emits -- `^git`, `^gh`,
# `^pytest`, `^alembic`, `^uv` -- and bash runs the same program when that name
# is spelled as a path, in quotes or behind a backslash. All five spellings of
# all seven refused shapes in #117's table were ALLOW. In six hooks of seven and
# not in every one: the issue says so of `no-work-on-stale-branch.sh` -- "was not
# measured, since it needs a stale-branch fixture" -- and the count is written
# out here because the sentence that said "every hook" was the #84 shape in
# miniature, a claim one hook wider than the measurement behind it. That hook
# reads its git commands through the same `^git` anchor, so the defect was there
# too; it is checked in its own section, beside the fixture it needs.
#
# Answered here and in no second place, which is what the issue means by "one
# place": the anchors stay exactly as they are, and every consumer of cs_split
# gets the fix without knowing it happened. The rule is the word's BASENAME
# AFTER UNQUOTING AND UNESCAPING, so a program of another name keeps it -- #72
# decided that `my-gh` is not `gh`, and the permitting rows below hold that
# decision against this change.
#
# It is checked here rather than only through the hooks because a check through
# a hook cannot tell this transformation from the anchor being widened, and a
# widened anchor is how `my-gh` would quietly become `gh`.
req GH-117
tok 'the command word as an absolute path' \
    'git push --all origin' \
    "$(printf '/usr/bin/git push --all origin\n' | cs_split)"
tok 'the command word as a relative path' \
    'gh pr merge 5' \
    "$(printf './gh pr merge 5\n' | cs_split)"
tok 'the command word as a path under the home directory' \
    'gh pr merge 5' \
    "$(printf '~/bin/gh pr merge 5\n' | cs_split)"
tok 'the command word in double quotes' \
    'git push origin main' \
    "$(printf '"git" push origin main\n' | cs_split)"
tok 'the command word in single quotes' \
    'git push origin main' \
    "$(printf "'git' push origin main\n" | cs_split)"
tok 'the command word behind a backslash' \
    'git push origin main' \
    "$(printf '\\git push origin main\n' | cs_split)"
# Quoting part of a word is the same word to bash, and the spellings compose:
# a quoted span inside a path, and a path whose own name is quoted.
tok 'a quote inside the command word' \
    'gh pr merge 5' \
    "$(printf 'g"h" pr merge 5\n' | cs_split)"
tok 'a quoted name at the end of a path' \
    'gh pr merge 5' \
    "$(printf '/usr/bin/"gh" pr merge 5\n' | cs_split)"
# The permitting direction, and the half that makes the rows above evidence.
# A basename is not a substring match: three of these four have a guarded name
# inside them and none of them IS that name.
tok 'a program whose name merely ends in the guarded one' \
    'my-gh pr merge 5' \
    "$(printf 'my-gh pr merge 5\n' | cs_split)"
tok 'a program whose name merely ends in the guarded one, underscored' \
    'my_gh pr merge 5' \
    "$(printf 'my_gh pr merge 5\n' | cs_split)"
tok 'a directory named for the command is not the command' \
    'ls /usr/bin/git' \
    "$(printf 'ls /usr/bin/git\n' | cs_split)"
tok 'a bare command word is handed back unchanged' \
    'git push --all origin' \
    "$(printf 'git push --all origin\n' | cs_split)"
# A word whose basename is empty is not a name, so it is left exactly as it
# stands: rewriting it to nothing would put its first ARGUMENT where the command
# word goes, and `/usr/bin/ git push` would read as a push.
tok 'a word with no basename is left alone' \
    '/usr/bin/ git push --all origin' \
    "$(printf '/usr/bin/ git push --all origin\n' | cs_split)"
# The normalisation runs after the prefix strip and on every candidate the strip
# offers, not only the first. Without that, `sudo /usr/bin/git` is normalised
# nowhere, because at the point the prefix words are read the command word is
# still behind them.
tok 'the command word behind a prefix word, and every tail candidate' \
    'git push --mirror
push --mirror
--mirror' \
    "$(printf 'sudo /usr/bin/git push --mirror\n' | cs_split)"
# And after the split, so that the second command on a line is reached. The
# first defect in this file was a scope that answered about the first command
# and stopped, and a transformation applied before the split would repeat it.
tok 'the command word of the second command on a line' \
    'echo x
git push origin main' \
    "$(printf 'echo x && /usr/bin/git push origin main\n' | cs_split)"

section "=== REGRESSION: PR #35, only the first push on a line was validated ==="
# The scope found the first push, validated its arguments, and stopped. So a
# legitimate push carried an illegitimate one after ; or && on its coat-tails.
req FR-3 US-3
check_in "$PUSH_WT" no-git-push.sh BLOCK 'legit push ; push origin main'  "git push origin $PUSH_BRANCH; git push origin main"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'legit push && push --all'       "git push origin $PUSH_BRANCH && git push --all origin"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'bare push && forced push'       "git push && git push --force origin $PUSH_BRANCH"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'three pushes, last one bad'     "git push; git push origin $PUSH_BRANCH; git push --mirror origin"
req FR-3 US-15
check no-pr-decisions.sh BLOCK 'gh pr view ; gh pr merge'   'gh pr view 5; gh pr merge 5'

section "=== REGRESSION: PR #35, backticks and command prefixes ==="
# $( ) was closed by the paren in the separator class and its twin was not --
# the same asymmetry GIT_DIR= had against --git-dir. Both hooks were open.
req FR-3 US-3
check_in "$PUSH_WT" no-git-push.sh BLOCK 'backticked push'      'echo `git push --mirror origin`'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'dollar-paren push'    'echo $(git push --mirror origin)'
req FR-3 US-15
check no-pr-decisions.sh BLOCK 'backticked merge'     'echo `gh pr merge 35`'
check no-pr-decisions.sh BLOCK 'dollar-paren merge'   'echo $(gh pr merge 35)'
req FR-3 US-3
check_in "$PUSH_WT" no-git-push.sh BLOCK 'push through xargs'   'echo origin | xargs git push --mirror'
req FR-3 US-15
check no-pr-decisions.sh BLOCK 'merge through xargs'  'echo 35 | xargs gh pr merge'

section "=== REGRESSION: heredoc prose that blocked its own commit ==="
req FR-3
COMMIT_MSG=$'git commit -q -F - <<\'EOF\'\nLeave pushing and deciding a PR to Bertan\n\nno-git-push.sh refuses every push; no-pr-decisions.sh refuses\ngh pr review --approve and --request-changes, gh pr close and reopen.\ngit push origin main is refused in every form.\ngh pr merge 5 would also be refused.\nEOF'
check_in "$PUSH_WT" no-git-push.sh ALLOW 'commit msg naming git push in heredoc' "$COMMIT_MSG"
check no-pr-decisions.sh ALLOW 'commit msg naming gh pr verbs in heredoc' "$COMMIT_MSG"
NOTE=$'cat > /tmp/note.md <<\'MD\'\ngh pr merge is now refused by a hook.\ngit push origin main likewise.\nMD'
check_in "$PUSH_WT" no-git-push.sh ALLOW 'heredoc body naming git push' "$NOTE"
check no-pr-decisions.sh ALLOW 'heredoc body naming gh pr merge' "$NOTE"

section "=== REGRESSION: PR #35, indentation defeated the anchor ==="
# Each names a refused destination, so these assert that the command is still
# *found* when indented, independently of the worktree exception.
req FR-3 US-3 US-2
check_in "$PUSH_WT" no-git-push.sh BLOCK 'if/then + indented push to dev-05' $'if true; then\n    git push origin dev-05\nfi'
req FR-3 US-3 US-1
check_in "$PUSH_WT" no-git-push.sh BLOCK 'for loop + indented push to main'  $'for r in a b; do\n  git push origin main\ndone'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'deeply indented push to main'      $'if true; then\n  if true; then\n        git push origin main\n  fi\nfi'
req FR-3 US-15
check no-pr-decisions.sh BLOCK 'if/then + indented merge'          $'if true; then\n    gh pr merge 35\nfi'
check no-pr-decisions.sh BLOCK 'for loop + indented close'         $'for n in 1 2; do\n  gh pr close $n\ndone'

section "=== REGRESSION: PR #35, no-pr-decisions.sh had no wrapper rule ==="
req FR-4 US-15
check no-pr-decisions.sh BLOCK 'bash -c gh pr merge'  "bash -c 'gh pr merge 35'"
check no-pr-decisions.sh BLOCK 'sh -c gh pr merge'    'sh -c "gh pr merge 35"'
check no-pr-decisions.sh BLOCK 'eval gh pr merge'     "eval 'gh pr merge 35'"
check no-pr-decisions.sh BLOCK 'graphql mutation via heredoc' $'gh api graphql -f query=@- <<EOF\nmutation { mergePullRequest(input:{pullRequestId:"x"}) { clientMutationId } }\nEOF'
check no-pr-decisions.sh BLOCK 'REST merge via heredoc body'  $'gh api -X PUT --input - <<EOF\n{"path":"/repos/o/r/pulls/5/merge"}\nEOF'

section "=== ACCEPTED false positive: quoted multi-line string, not a heredoc ==="
# The price of allowing leading whitespace in the anchor. Kept on purpose: a
# blocked comment is visible and one edit away, a silently permitted push is
# neither. If a later change makes these ALLOW, that is a decision to take
# knowingly, not a bug fix.
req FR-3
check_in "$PUSH_WT" no-git-push.sh BLOCK 'multi-line -b string continuing with a push' $'gh issue comment 27 -b "to release:\n  git push origin main"'
check no-pr-decisions.sh BLOCK 'multi-line -b string continuing with a merge' $'gh issue comment 27 -b "to land it:\n  gh pr merge 35"'
# The single-line half of that trade is no longer paid, and the two checks that
# used to sit here now sit in the issue #68 section below -- an `ALLOW (was
# BLOCK)` is neither accepted nor a false positive, and leaving them under this
# heading would have made the heading a lie. The multi-line pair above stays,
# and stays accepted: quote state is per line, so an unbalanced line falls back
# to the old splitting and the continuation still reads as a command position.

section "=== REGRESSION: issue #68, a quoted separator refused ordinary sed and grep ==="
# The six measured over-refusals from the ticket, now ALLOW. Every one is a
# command that edits or searches text; none of them pushes or commits anything.
# It fired twice in a live session against that session's own edits to these
# hooks, which is what makes it worth a suite entry rather than a note: editing
# the hooks is exactly the work that trips it.
req GH-68.1
check_in "$PUSH_WT" no-git-push.sh ALLOW 'sed over a push --all (was BLOCK)'  "sed -i 's|git push --all origin|X|' f.sh"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'sed over a forced push (was BLOCK)' "sed -i 's|git push -f origin main|X|' f.sh"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'sed over a bare push (was BLOCK)'   "sed -i 's|git push|X|' f.sh"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'grep alternation over pushes (was BLOCK)' "grep -rn 'git push --all|git push -f' .claude/"
check_in "$ON_MAIN" no-commit-to-main.sh ALLOW 'sed over a commit, on main (was BLOCK)' \
         "sed -i 's|git commit -m x|X|' f.sh"
check_in "$ON_MAIN" no-commit-to-main.sh ALLOW 'grep alternation over commit and push, on main (was BLOCK)' \
         "grep -n 'git commit|git push origin main' *.sh"
# The four no-git-push.sh checks above the two no-commit-to-main.sh ones run in
# the fixture worktree, which is where the ticket measured them. Asked again
# from the fixture's main checkout, where every real push is refused before the
# worktree exception is reached: an ALLOW there says no push was seen at all,
# rather than that one was seen and permitted. Both contexts, because the whole
# complaint is that the verdict turned on something irrelevant to what the
# command runs.
check_in "$PUSH_MAIN" no-git-push.sh ALLOW 'sed over a push --all, from the main checkout (was BLOCK)\' \
         "sed -i 's|git push --all origin|X|' f.sh"
check_in "$PUSH_MAIN" no-git-push.sh ALLOW 'sed over a forced push, from the main checkout (was BLOCK)\' \
         "sed -i 's|git push -f origin main|X|' f.sh"
check_in "$PUSH_MAIN" no-git-push.sh ALLOW 'sed over a bare push, from the main checkout (was BLOCK)\' \
         "sed -i 's|git push|X|' f.sh"
check_in "$PUSH_MAIN" no-git-push.sh ALLOW 'grep alternation over pushes, from the main checkout (was BLOCK)\' \
         "grep -rn 'git push --all|git push -f' .claude/"
# Two more verdicts the fix changed, found by sweeping a corpus of commands
# against both versions of cs_split rather than by this suite -- which is the
# reason to write them down here: a check suite is evidence about the cases it
# names, and neither of these was named. The delimiter spelled with double
# quotes is the same defect as the six above; a substitution in single quotes
# runs nothing, because bash expands nothing inside them.
check_in "$PUSH_WT" no-git-push.sh ALLOW 'sed over a push, double-quoted delimiter (was BLOCK)' \
         'sed -i "s|git push --all origin|X|" f.sh'
# The other two separators, as verdicts rather than only as fragment lists.
check_in "$PUSH_WT" no-git-push.sh ALLOW 'sed with & as its delimiter (was BLOCK)' \
         "sed -i 's&git push --all origin&X&' f.sh"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'grep for a backticked push in prose (was BLOCK)' \
         "grep -rn '\`git push --all origin\`' docs/"
req GH-68.1 GH-68.2
check no-pr-decisions.sh ALLOW 'a merge quoted in single quotes is inert (was BLOCK)' \
         "echo '\$(gh pr merge 5)'"
# And its control, one character different: in double quotes that substitution
# RUNS, so the line goes to the fallback and the merge is found. This pair is
# what the substitution fallback exists for, and it is asked as a verdict rather
# than only as a fragment list -- pinning the split alone would let a hook stop
# refusing these without anything going red.
req GH-68.2
check no-pr-decisions.sh BLOCK 'the same substitution in double quotes' \
         'echo "$(gh pr merge 5)"'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a push substituted inside double quotes' \
         'echo "$(git push --all origin)"'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a push backticked inside double quotes' \
         'echo "`git push --all origin`"'
req GH-68.2 GH-43.1
check_in "$ON_MAIN" no-commit-to-main.sh BLOCK 'a commit substituted inside double quotes' \
         'echo "$(git commit -m x)"'
# The trade above cs_split, partly repaid. A quoted string holding a separator
# and then a control word in front of a refused command used to read as that
# command; on one line it is text again. These were written as accepted false
# positives in the section above and are moved here with the verdict they now
# return, because that is where the reason for the change is written down.
req GH-68.1 FR-3
check_in "$PUSH_WT" no-git-push.sh ALLOW 'quoted "; then" before a push (was BLOCK)'  'git commit -m "wait; then git push --all origin"'
check no-pr-decisions.sh ALLOW 'quoted "; then" before a merge (was BLOCK)' 'git commit -m "wait; then gh pr merge 35"'
# What did not flip with them, and the reason: the multi-line spelling of the
# same string leaves a quote open at the newline, so each line falls back and
# the continuation reads as a command position. Pinned here beside the flip so
# the two are read together rather than as a contradiction.
req GH-68.2
check_in "$PUSH_WT" no-git-push.sh BLOCK 'the multi-line spelling still refused' \
         $'gh issue comment 27 -b "to release:\n  git push origin main"'
# The intermittency, which is the part that reads as arbitrary from inside a
# session: the anchored spelling was permitted all along and the spelling with a
# leading space was refused, on a difference that decides nothing about what
# either command runs. They agree now, and the pair is pinned so that a
# regression shows up as the disagreement rather than as one lost verdict.
req GH-68.1
check_in "$PUSH_WT" no-git-push.sh ALLOW 'the anchored spelling, permitted before and after' \
         "sed -i 's|^git push --all origin|X|' f.sh"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'the leading-space spelling (was BLOCK)' \
         "sed -i 's| git push --all origin|X|' f.sh"
# The controls. A quote-aware split must not have cost a single real refusal,
# and these are the three commands the six above only ever mentioned.
req GH-68.1 US-3
check_in "$PUSH_WT" no-git-push.sh BLOCK 'the control: a real push --all'   'git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'the control: a real forced push'  'git push -f origin main'
req GH-68.1 US-1
check_in "$ON_MAIN" no-commit-to-main.sh BLOCK 'the control: a real commit on main' 'git commit -m x'
check_in "$ON_MAIN" no-commit-to-main.sh BLOCK 'the control: a real push --all on main' 'git push --all origin'
# The wrapper detections read the RAW command text, before the split and not
# from it, and that ordering is load-bearing here: quote-aware splitting means a
# single-quoted payload is now one fragment with no command position in it at
# all, so nothing but the raw match can still see these. A BLOCK is therefore
# evidence about where the rule reads from, which is what makes them checks
# about issue #68 rather than repeats of the wrapper checks above.
req GH-68.3 FR-4
check_in "$PUSH_WT" no-git-push.sh BLOCK 'wrapped push, invisible to the split' "bash -c 'git push --all origin'"
check no-pr-decisions.sh BLOCK 'wrapped merge, invisible to the split' "eval 'gh pr merge 5'"
# On a dev branch, not main, so that the refusal cannot be the branch answering
# for the wrapper rule.
check_in "$ON_DEV" no-commit-to-main.sh BLOCK 'wrapped commit, invisible to the split' \
         "sh -c 'git commit -m x'"
# And the same claim asserted as a property of the files rather than inferred
# from three verdicts. Each literal below pins both which rule it is and what
# that rule is handed -- the raw command, never the fragments.
#
# Since #79 the expression itself is CS_WRAPPER_RE, derived once in
# lib/command-scan.sh, so the literal names the shared variable rather than the
# head of a regex each hook carried its own copy of. What is pinned is
# unchanged: which text the rule reads.
req GH-68.3 GH-79.4
armed 'no-git-push.sh matches the shared wrapper rule on the raw command' \
      "$HOOKS/no-git-push.sh" 'if echo "$COMMAND" | grep -qE "$CS_WRAPPER_RE"'
armed 'no-commit-to-main.sh matches the shared wrapper rule on the raw command' \
      "$HOOKS/no-commit-to-main.sh" 'if echo "$COMMAND" | grep -qE "$CS_WRAPPER_RE"'
# no-pr-decisions.sh joins continuations first and matches on that, which is the
# half of cs_normalise its wrapper rules do want; both halves are pinned.
armed 'no-pr-decisions.sh derives its wrapper text from the raw command' \
      "$HOOKS/no-pr-decisions.sh" "WRAPTEXT=\$(printf '%s\\n' \"\$COMMAND\" | cs_join)"
armed 'no-pr-decisions.sh matches the shared wrapper rule on that text' \
      "$HOOKS/no-pr-decisions.sh" 'if echo "$WRAPTEXT" | grep -qE "$CS_WRAPPER_RE"'
unarmed 'no-git-push.sh does not match its wrapper rule on the fragments' \
        "$HOOKS/no-git-push.sh" 'echo "$CMDS" | grep -qE "$CS_WRAPPER_RE"'
unarmed 'no-commit-to-main.sh does not match its wrapper rule on the fragments' \
        "$HOOKS/no-commit-to-main.sh" 'echo "$CMDS" | grep -qE "$CS_WRAPPER_RE"'
unarmed 'no-pr-decisions.sh does not match its wrapper rule on the fragments' \
        "$HOOKS/no-pr-decisions.sh" 'echo "$CMDS" | grep -qE "$CS_WRAPPER_RE"'
# The fourth consumer. It was covered behaviourally by the stale-branch section
# below and not by a literal, which left "each wrapper detection" met in
# substance and not in letter -- and this is the one hook where a lost fragment
# retains a carve-out instead of dropping a refusal, so it is the last one that
# should rest on an argument rather than a pin. See the header of
# lib/command-scan.sh for why that shape is still safe.
armed 'no-work-on-stale-branch.sh matches the shared wrapper rule on the raw command' \
      "$HOOKS/no-work-on-stale-branch.sh" 'if echo "$COMMAND" | grep -qE "$CS_WRAPPER_RE"'
unarmed 'no-work-on-stale-branch.sh does not match its wrapper rule on the fragments' \
        "$HOOKS/no-work-on-stale-branch.sh" 'echo "$CMDS" | grep -qE "$CS_WRAPPER_RE"'
# And that no hook carries its own copy of the anchor any more. WRAPRE is the
# head each of the four wrote out before #79; four copies of one expression, in
# the file whose header names that as the defect. A hook that re-derives it
# would pass every check above and answer the list differently again.
req GH-79.4
WRAPRE='(^[[:space:]]*|[;&|(`][[:space:]]*)'
unarmed 'no-git-push.sh does not carry its own copy of the anchor' \
        "$HOOKS/no-git-push.sh" "grep -qE '$WRAPRE"
unarmed 'nor no-commit-to-main.sh' \
        "$HOOKS/no-commit-to-main.sh" "grep -qE '$WRAPRE"
unarmed 'nor no-pr-decisions.sh' \
        "$HOOKS/no-pr-decisions.sh" "grep -qE '$WRAPRE"
unarmed 'nor no-work-on-stale-branch.sh' \
        "$HOOKS/no-work-on-stale-branch.sh" "grep -qE '$WRAPRE"
# In either spelling. The four pins above name the single-quoted one, which is
# how all four hooks wrote it; a re-derivation reached for with double quotes
# would satisfy every one of them and answer the list a second time anyway.
# Found by review of this change: a pin on one spelling of a literal is
# evidence about that spelling and about nothing else.
unarmed 'no-git-push.sh does not carry it double-quoted either' \
        "$HOOKS/no-git-push.sh" "grep -qE \"$WRAPRE"
unarmed 'nor no-commit-to-main.sh' \
        "$HOOKS/no-commit-to-main.sh" "grep -qE \"$WRAPRE"
unarmed 'nor no-pr-decisions.sh' \
        "$HOOKS/no-pr-decisions.sh" "grep -qE \"$WRAPRE"
unarmed 'nor no-work-on-stale-branch.sh' \
        "$HOOKS/no-work-on-stale-branch.sh" "grep -qE \"$WRAPRE"

section "=== REGRESSION: issue #79, the wrapper rules did not know the prefix words ==="
# cs_split has always stripped the words that run another command -- sudo, env,
# xargs, nohup, nice, time, stdbuf, ionice, command, doas, setsid, chronic, and
# timeout and flock with their operand. The four wrapper regexes did not consult
# that list; they answered "is this a wrapper?" independently and anchored on ^
# or on a separator, so sudo was recognised in one half of the library and
# invisible in the other:
#
#   BLOCK   sudo git push --all origin            the push is at a command position
#   ALLOW   sudo sh -c 'git push --all origin'    the wrapper is not at ^
#
# Every check in the first group below was ALLOW before the anchor was widened
# to admit that list. They are asked of no-git-push.sh and of
# no-commit-to-main.sh both, because the defect was in an expression all four
# hooks carried a copy of, and a fix that reached one file would be the shape
# this suite exists to catch.
req GH-79.1 FR-4
check_in "$PUSH_WT" no-git-push.sh BLOCK 'sudo + wrapped push'            "sudo sh -c 'git push --all origin'"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'timeout + wrapped push'         "timeout 5 bash -c 'git push --all origin'"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'xargs + wrapped push'           "xargs sh -c 'git push --all origin'"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'env + wrapped push'             "env FOO=1 sh -c 'git push --all origin'"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'nohup + wrapped push'           "nohup sh -c 'git push --all origin'"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'sudo + wrapped eval push'       "sudo eval 'git push --all origin'"
# The separated option value, which is the shape cs_split answers by offering
# its tail as further candidates rather than by trimming its head. The anchor
# admits three further tokens for the same reason and to the same bound: `-u`,
# `-n` and `-s` are consumed as options and leave `root`, `10` and `KILL 30`
# standing where the wrapper word has to be.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'sudo -u root + wrapped push'    "sudo -u root sh -c 'git push --all origin'"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'nice -n 10 + wrapped push'      "nice -n 10 sh -c 'git push --all origin'"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'timeout -s KILL 30 + wrapped'   "timeout -s KILL 30 bash -c 'git push --all origin'"
# And where that run stops, pinned from both sides. Three is the bound cs_split
# already offers its tail to, and a bound is only a claim if the check names the
# token past it: neither of these two is a shape anyone writes, and that is the
# point -- they measure the number rather than a command.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'three tokens before the wrapper'     "sudo a b c sh -c 'git push --all origin'"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'and four is past where it looks'     "sudo a b c d sh -c 'git push --all origin'"
# An OPTION standing after a separated option value. The options loop stops at
# the first token that is not an option, so a second option behind the operand
# falls to the token class -- and that class excluded a leading dash until
# review of this branch, which made the anchor stop dead where cs_split walks
# past and finds the command. Each pair below was BLOCK unwrapped and ALLOW
# wrapped, which is #79's own asymmetry one option deeper and in the permitting
# direction, inside the change that fixes it. The unwrapped halves are here too
# because the pair is the evidence: a single verdict says nothing about which
# half moved.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'sudo -n after a separated value, unwrapped' \
         'sudo -u root -n git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'sudo -n after a separated value, wrapped' \
         "sudo -u root -n sh -c 'git push --all origin'"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'the bare -- after a separated value, unwrapped' \
         'nice -n 10 -- git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'the bare -- after a separated value, wrapped' \
         "nice -n 10 -- sh -c 'git push --all origin'"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a long option after an operand, unwrapped' \
         'timeout -s KILL 30 --preserve-status git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a long option after an operand, wrapped' \
         "timeout -s KILL 30 --preserve-status bash -c 'git push --all origin'"
# The control that was never broken: with no operand consumed yet, the options
# loop still has the dash, so this was BLOCK throughout. It is what says the
# three above are about the token class and not about `--`.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a bare -- with no operand before it' \
         "sudo -- sh -c 'git push --all origin'"
# What that run admits, where cs_split's tail would stop. The class is now
# cs_split's exactly; what still differs is the LOOP -- cs_split breaks at a
# token opening a quote, because it offers candidates to read as commands, and
# this does not, because nothing here reads a token at all. Deliberate, argued
# at CS_WRAP_TOKEN, in the refusing direction, and pinned so that it is not
# rediscovered as a divergence.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a quoted token does not end the run' \
         "sudo \"x\" sh -c 'git push --all origin'"
# On a dev branch, so that the branch cannot be what answers for the wrapper
# rule -- the same care the #68 wrapped-commit check takes above.
req GH-79.1 FR-4 GH-43.3
check_in "$ON_DEV" no-commit-to-main.sh BLOCK 'sudo + wrapped commit' \
         "sudo sh -c 'git commit -m x'"
check_in "$ON_DEV" no-commit-to-main.sh BLOCK 'timeout + wrapped commit' \
         "timeout 5 bash -c 'git commit -m x'"
check_in "$ON_DEV" no-commit-to-main.sh BLOCK 'xargs + wrapped push' \
         "xargs sh -c 'git push --all origin'"
check_in "$ON_DEV" no-commit-to-main.sh BLOCK 'env + wrapped push' \
         "env FOO=1 sh -c 'git push --all origin'"
check_in "$ON_DEV" no-commit-to-main.sh BLOCK 'nohup + wrapped push' \
         "nohup sh -c 'git push --all origin'"
# The third consumer. A decision is what this hook answers for, and it carried
# the same blind spot.
#
# The fourth is no-work-on-stale-branch.sh, and it is NOT here: its verdicts
# need a worktree on a branch whose life is over, and those fixtures are built
# further down. Its prefix-word checks are in that section, beside its other
# wrapper ones. This comment said "the third and fourth consumers" with three
# no-pr-decisions checks under it and nothing for the fourth anywhere -- found
# by review of this change, which is the letter of "no fix lands without a
# check that fails without the fix" going unmet while an armed pin on
# CS_WRAPPER_RE carried the substance.
req GH-79.1 FR-4 US-15
check no-pr-decisions.sh BLOCK 'timeout + wrapped merge'    "timeout 5 sh -c 'gh pr merge 5'"
check no-pr-decisions.sh BLOCK 'sudo + wrapped release'     "sudo bash -c 'gh release create v1'"
check no-pr-decisions.sh BLOCK 'nohup + wrapped eval merge' "nohup eval 'gh pr merge 5'"
# The controls: the unwrapped shape the list already reached, and the wrapped
# shape with no prefix in front of it. Both were BLOCK before and must stay so,
# or the widening has moved the rule rather than extended it.
req GH-79.1 FR-3
check_in "$PUSH_WT" no-git-push.sh BLOCK 'the control: sudo + a bare push'   'sudo git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'the control: timeout + a push'     'timeout 30 git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'the control: a wrapper on its own' "bash -c 'git push --all origin'"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'the control: an assignment prefix' "FOO=1 sh -c 'git push --all origin'"

section "=== issue #79: the anchor was widened and not dropped ==="
# The constraint that decides this fix. Dropping the anchor would pass every
# check above and refuse a wrapper word named anywhere on a line that also names
# a refused command -- which is exactly what a session working on these hooks
# writes. The obvious example does not show it: `grep -rn "sh -c" .claude/` is
# ALLOW either way, because the rule is a conjunction and that command names no
# push. The shapes that regress name a wrapper word and a push on one line, and
# each of these three is ALLOW with the anchor and BLOCK without it.
req GH-79.2
check_in "$PUSH_WT" no-git-push.sh ALLOW 'grepping for the sh -c rule'  "grep -rn 'sh -c .*git push' .claude/hooks/"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'grepping for the eval rule'   "grep -rn 'eval .*git push' .claude/hooks/"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'a note about what eval does'  "echo 'the eval rule refuses git push --all origin' >> notes.md"
req GH-79.2 GH-43.3
check_in "$ON_DEV" no-commit-to-main.sh ALLOW 'grepping for the sh -c rule' \
         "grep -rn 'sh -c .*git commit' .claude/hooks/"

section "=== issue #79: named and not closed -- the list cannot be complete ==="
# A word that runs a command and is not a prefix word is out of reach, and the
# header of lib/command-scan.sh says so rather than implying the set is
# exhaustive. These are ALLOW and are pinned as ALLOW: a check that named them
# and wanted BLOCK would be a claim the fix does not make.
req GH-79.3
check_in "$PUSH_WT" no-git-push.sh ALLOW 'python3 -c is out of reach' \
         "python3 -c 'import os; os.system(\"git push --all origin\")'"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'perl -e is out of reach' \
         "perl -e 'system(\"git push --all origin\")'"
# find runs its operand after -exec rather than as a prefix, so it is not one of
# cs_split's words and adding it there would strip find and leave the path where
# the command word has to be. Named with the family above rather than closed.
check_in "$PUSH_WT" no-git-push.sh ALLOW 'find -exec sh -c is out of reach' \
         "find . -exec sh -c 'git push --all origin' \\;"

section "=== issue #79: the soft spot the anchor keeps, and what widening cost it ==="
# The anchor carries its own separator class, and that class knows nothing about
# quoting -- so a verdict still turns on a sed delimiter, which is the complaint
# #68 was filed about. It is deferred rather than impossible, and the reason is
# argued once, at CS_WRAPPER_RE in lib/command-scan.sh: asking cs_split WOULD
# answer it, and what stops this rule asking is that the pins above assert it is
# handed the raw command. This banner said "cannot fix it here" and gave the
# raw-text reason, which is the version that header examines and rejects --
# found by review of this change, one file asserting what the other disowns,
# which is the shape #63 found in CLAUDE.md and the header found in itself.
# Both spellings are pinned side by side, because it is the delimiter that
# decides the verdict and that is the part that reads as arbitrary in session.
req GH-79.2
check_in "$PUSH_WT" no-git-push.sh BLOCK 'the pipe delimiter satisfies the anchor' \
         "sed -i 's|sh -c git push --all|X|' f.sh"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'the slash delimiter does not' \
         "sed -i 's/sh -c git push --all/X/' f.sh"
# And the cost of widening, named so that it is a known trade rather than a
# discovery: the prefix words are admitted after that same quote-blind
# separator, so prose naming one of them in front of a wrapper is refused where
# it was not before. It costs a refusal and never a permission, and the refusal
# is visible and one edit away.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a prefix word in prose, after a pipe (was ALLOW)' \
         "sed -i 's|sudo sh -c git push --all|X|' f.sh"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'the same prose with the other delimiter' \
         "sed -i 's/sudo sh -c git push --all/X/' f.sh"

section "=== issue #79: the prefix words are written once ==="
# The point of the fix, asserted as a property of the file rather than inferred
# from the verdicts above. A second copy of those fourteen words in four hook
# regexes would be the same defect one more time, so the list is a variable that
# cs_split reads through awk's -v and the anchor interpolates.
#
# `stdbuf` and `ionice` are counted because they appear in the assignment and
# nowhere in the prose around it: sudo, timeout, xargs, nohup and env are named
# in the header's worked example, so counting one of those would count the
# explanation as a copy.
req GH-79.4
tok 'the option words are written once in the library' \
    '1' "$(prose_count "$HOOKS/lib/command-scan.sh" 'stdbuf')"
tok 'and so is the second of them' \
    '1' "$(prose_count "$HOOKS/lib/command-scan.sh" 'ionice')"
armed 'the union is derived rather than written a third time' \
      "$HOOKS/lib/command-scan.sh" 'CS_WRAP_WORDS="$CS_WRAP_OPTION_WORDS|$CS_WRAP_OPERAND_WORDS"'
armed 'cs_split reads the option words as a variable' \
      "$HOOKS/lib/command-scan.sh" '-v wrapwords="$CS_WRAP_OPTION_WORDS"'
armed 'and the operand words the same way' \
      "$HOOKS/lib/command-scan.sh" '-v operandwords="$CS_WRAP_OPERAND_WORDS"'
# The literal moved in #96, not the claim. The strip used to match the list at the
# head of the line and cut the line after it, and each cut copied the rest of the
# line; it now asks the same list of the one token at the head and moves past it.
# Whether that is the same question is argued in cs_split and was fuzzed there,
# byte for byte against the version before.
armed 'cs_split strips whatever that variable holds' \
      "$HOOKS/lib/command-scan.sh" '~ ("^(" wrapwords ")$")'
armed 'and whatever the operand variable holds' \
      "$HOOKS/lib/command-scan.sh" '~ ("^(" operandwords ")$")'
# The literal moved again in #117, and the claim did not. A prefix word is
# admitted in every spelling now, so the spelling prefix stands in front of the
# union and a run of quotes behind it; what is pinned is still that the anchor
# reads the shared variable rather than a copy of the words, which is the whole
# of GH-79.4. Both halves of the new spelling are named, so the union cannot be
# quietly wrapped in something that changes which words it admits.
armed 'and the anchor admits whatever the union holds' \
      "$HOOKS/lib/command-scan.sh" '($CS_WRAP_WORDS)[\\\\\"'"'"']*[[:space:]]+'
armed 'and reaches it through the same spelling prefix the command word uses' \
      "$HOOKS/lib/command-scan.sh" '$CS_WORD_SPELLING($CS_WRAP_WORDS)'
armed 'the intervening token is named once and used once' \
      "$HOOKS/lib/command-scan.sh" '($CS_WRAP_TOKEN){0,3}'
# What an empty list does is not pinned here. It is part of the load, so it is
# driven where the load is driven: the word-list block of the load-contract
# section at the foot of this suite, per consumer, with the rest of the contract.
#
# This comment and two pins used to stand here for a different mechanism -- an
# empty CS_WRAPPER_RE, justified as answering for "the two hooks that do not
# guard their own load". #84 guarded all six and pinned the opposite, and the
# anchor never reached the two convention hooks at all. Both pins went with the
# mechanism; see THE WORD LIST IS PART OF THE LOAD in lib/command-scan.sh.
# The literal cs_split carried before #79. It is the second copy this fix
# removes, and a re-derivation would restore it.
unarmed 'cs_split no longer carries the list as a literal' \
        "$HOOKS/lib/command-scan.sh" '/^(env|command|xargs'
# What these pins are NOT evidence of, named because a check is evidence about
# what it names: they read the derivation, not the verdict. A list that is
# written once and is wrong is wrong in both places at once, which is what the
# header of lib/command-scan.sh says this file keeps costing. The behavioural
# groups above are what say the list is right for the words they name.

section "=== REGRESSION: PR #35 review, a command after a control word ==="
# A separator is not the only thing a command can follow. Splitting on ; left
# `then` in front of the command word, so the anchor never saw the command at
# all, and `do`, `else`, `elif`, `{` and `!` did the same. Every check here was
# ALLOW before the control words were removed in cs_split.
req FR-3 US-3
check_in "$PUSH_WT" no-git-push.sh BLOCK 'then + push --mirror'     'if true; then git push --mirror origin; fi'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'do + push --all'          'while true; do git push --all origin; done'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'brace group + push'       '{ git push --mirror origin; }'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'then + push to dev-05'    'if true; then git push origin dev-05; fi'
req FR-3 US-15
check no-pr-decisions.sh BLOCK 'then + gh pr merge'       'if true; then gh pr merge 35; fi'
check no-pr-decisions.sh BLOCK 'do + gh pr merge'         'for x in a; do gh pr merge 35; done'
check no-pr-decisions.sh BLOCK 'until/do + gh pr merge'   'until false; do gh pr merge 35; done'
check no-pr-decisions.sh BLOCK 'else + gh pr merge'       'if true; then :; else gh pr merge 35; fi'
check no-pr-decisions.sh BLOCK 'elif + gh pr merge'       'if true; then :; elif true; then gh pr merge 35; fi'
check no-pr-decisions.sh BLOCK '! negation + gh pr merge' '! gh pr merge 35'
check no-pr-decisions.sh BLOCK 'brace group + gh pr close' '{ gh pr close 35; }'
# The words are removed at the start of a command only, so an ordinary sentence
# that happens to contain one is untouched.
req FR-3
check no-pr-decisions.sh ALLOW 'a control word mid-sentence' 'echo "then run gh pr merge 35" >> notes.md'

section "=== REGRESSION: PR #35 review, heredoc detection dropped live commands ==="
# Dropping a heredoc body is the one step that hides commands, so both ends of
# it have to be exact. `<<<` is a here-string and was read as a heredoc whose
# terminator never arrives; `<<-` ends on a tab-indented terminator that an
# exact comparison never matched. Either one discarded every following line, so
# the hook saw an empty command and returned 0.
req FR-3
check no-pr-decisions.sh BLOCK 'here-string then a merge'  $'cat <<< "hello"\ngh pr merge 35'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'here-string then a push'   $'cat <<< "hello"\ngit push --mirror origin'
check no-pr-decisions.sh BLOCK '<<- tab terminator, then a merge' $'cat <<-EOF\n\thello\n\tEOF\ngh pr merge 35'
check_in "$PUSH_WT" no-git-push.sh BLOCK '<<- tab terminator, then a push'  $'cat <<-EOF\n\thello\n\tEOF\ngit push --mirror origin'
# The body of a real heredoc is still data, tab-indented or not.
check no-pr-decisions.sh ALLOW '<<- body naming a merge'   $'cat <<-EOF\n\tgh pr merge 35 would be refused\n\tEOF\necho done'
check_in "$PUSH_WT" no-git-push.sh ALLOW '<<- body naming a push'    $'cat <<-EOF\n\tgit push --all origin is refused\n\tEOF\necho done'

section "=== REGRESSION: PR #35 review, reading a PR through gh api ==="
# The endpoint does not say whether a call decides anything. GET /pulls/N/reviews
# lists reviews and GET /pulls/N/merge reports whether the PR is merged; both are
# reading a pull request, which CLAUDE.md allows in the sentence that forbids
# deciding one, and both were refused. The method separates them, so the method
# is what is tested -- gh sends GET unless a --method or a field flag says
# otherwise.
req FR-20 US-13
check no-pr-decisions.sh ALLOW 'GET the reviews list'    'gh api repos/bgunyel/clause-and-effect/pulls/35/reviews'
check no-pr-decisions.sh ALLOW 'GET the merge state'     'gh api repos/bgunyel/clause-and-effect/pulls/35/merge'
check no-pr-decisions.sh ALLOW 'GET named explicitly'    'gh api -X GET repos/bgunyel/clause-and-effect/pulls/35/reviews'
check no-pr-decisions.sh ALLOW 'GET with --paginate'     'gh api --paginate repos/bgunyel/clause-and-effect/pulls/35/reviews'
check no-pr-decisions.sh ALLOW 'GET with --jq'           'gh api repos/bgunyel/clause-and-effect/pulls/35/reviews --jq ".[].state"'
# The writes to those same endpoints are refused exactly as before.
req US-15 FR-20
check no-pr-decisions.sh BLOCK 'POST a review verdict'   'gh api repos/bgunyel/clause-and-effect/pulls/35/reviews -f event=APPROVE'
check no-pr-decisions.sh BLOCK 'value attached to -f'    'gh api repos/bgunyel/clause-and-effect/pulls/35/reviews -fevent=APPROVE'
check no-pr-decisions.sh BLOCK 'method attached to -X'   'gh api -XPUT repos/bgunyel/clause-and-effect/pulls/35/merge'
check no-pr-decisions.sh BLOCK '--method=PUT'            'gh api --method=PUT repos/bgunyel/clause-and-effect/pulls/35/merge'
check no-pr-decisions.sh BLOCK 'a review body by --input' 'gh api repos/bgunyel/clause-and-effect/pulls/35/reviews --input body.json'
check no-pr-decisions.sh BLOCK 'DELETE a review'         'gh api -X DELETE repos/bgunyel/clause-and-effect/pulls/35/reviews'
# A read wrapped in a shell is still refused: inside quotes the method cannot be
# read any more than the endpoint can. Run it unwrapped.
req FR-4 GH-51.2
check no-pr-decisions.sh BLOCK 'a GET inside bash -c'    "bash -c 'gh api repos/bgunyel/clause-and-effect/pulls/35/reviews'"

section "=== REGRESSION: review of 02a14d8, a heredoc that never was ==="
# `<<` inside double quotes is text, not a redirection, and the opener was
# matched anywhere on the line. The terminator it took never arrives, so every
# following line was dropped and both hooks went blind for the rest of the
# command -- reachable by writing a commit message about this very file. Third
# wrong answer to what counts as a heredoc, so the drop is no longer trusted:
# lines held for a heredoc that does not terminate are given back at END.
req FR-3
check_in "$PUSH_WT" no-git-push.sh BLOCK 'commit msg naming <<EOF, then --all'    $'git commit -m "hooks: fix <<EOF handling in cs_normalise"\n    git push --all origin'
check no-pr-decisions.sh BLOCK 'pr comment naming <<, then a merge'     $'gh pr comment 35 -b "the << operator confused it"\n    gh pr merge 35'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'left shift << in a message, then --all' $'git commit -m "left shift << done"\n    git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'issue comment naming <<, then --mirror' $'gh issue comment 1 -b "see << notes"\n    git push --mirror origin'
# A heredoc that does terminate is still data, so the older checks above still
# ALLOW -- that is what says the fail-safe did not simply disable the drop.

section "=== REGRESSION: issue #128, a continued opener hid the command after the terminator ==="
# The fifth answer to where a heredoc body begins and the fourth wrong one, and
# the first of them about the OPENER's own line. Bash joins a line ending in a backslash before
# the body starts, so `cat <<E \` / `x` / `E` is `cat <<E x` with an empty body
# and the next command runs -- measured with `echo RAN-AFTER` in its place,
# which printed after cat's complaint about the file `x`. The drop read `x` as
# the body instead, ended it at `E`, and the join then put the command after the
# terminator on the opener's line, at no command position: exit 0 from both
# hooks, where the same command without the backslash was exit 2.
#
# Every spelling of the opener is asked, because the spellings are where this
# question has gone wrong before: `<<-` and `<<<` were the second and third
# wrong answers and each was a spelling the comparison did not match. #106's
# families ask the seven of them of every seed; these are the two hooks and the
# two directions the issue measured, written out.
#
# THE EVEN RUN is here too, and it is not the issue's shape but the first fix's.
# Bash continues a line only on an ODD run of trailing backslashes, and that fix
# held the line open on any run at all -- which moved the terminator search
# forward, let the body swallow the terminator, and dropped every line up to the
# next one. `cat <<E \\` / `E` / `echo after` / *push* / `E` runs that push
# under bash and was permitted, exit 0, where dev-05 refused it. Found by review
# of this pull request. A generated run of 2,580 shapes, each executed under
# bash with a harmless payload to decide what really runs, puts dev-05 at 198
# hidden pushes, that fix at 40, and this one at 0.
req GH-128
check_in "$PUSH_MAIN" no-git-push.sh BLOCK 'continued opener, then a forced push' \
  $'cat <<E \\\nx\nE\ngit push --force origin main'
check_in "$ON_MAIN" no-commit-to-main.sh BLOCK 'continued opener, then a commit on main' \
  $'cat <<E \\\nx\nE\ngit commit -m wip'
check_in "$PUSH_MAIN" no-git-push.sh BLOCK 'the <<-E spelling, tab-indented terminator' \
  $'cat <<-E \\\n\tx\n\tE\ngit push --force origin main'
check_in "$PUSH_MAIN" no-git-push.sh BLOCK "the <<'E' spelling" \
  $'cat <<\'E\' \\\nx\nE\ngit push --force origin main'
check_in "$PUSH_MAIN" no-git-push.sh BLOCK 'the <<"E" spelling' \
  $'cat <<"E" \\\nx\nE\ngit push --force origin main'
check_in "$PUSH_MAIN" no-git-push.sh BLOCK 'the << E spelling, a space after the operator' \
  $'cat << E \\\nx\nE\ngit push --force origin main'
check_in "$PUSH_MAIN" no-git-push.sh BLOCK 'an opener continued over three lines' \
  $'cat <<E \\\n-n \\\n-E\nx\nE\ngit push --force origin main'
check_in "$PUSH_MAIN" no-git-push.sh BLOCK 'a redirect in front of the continued opener' \
  $'cat > f <<E \\\nx\nE\ngit push --force origin main'
# A quoted body whose lines end in a backslash still ends at its terminator, so
# the push after it is read. Bash does not join inside a quoted body either.
check_in "$PUSH_MAIN" no-git-push.sh BLOCK 'a slashed body line, then a push' \
  $'cat <<\'E\'\nprose \\\nE\ngit push --force origin main'
# The even run, which bash does not continue: the terminator on the next line
# ends an empty body, and what follows it runs.
check_in "$PUSH_MAIN" no-git-push.sh BLOCK 'an even run, terminator, then a push' \
  $'cat <<E \\\\\nE\ngit push --force origin main'
check_in "$ON_MAIN" no-commit-to-main.sh BLOCK 'an even run, terminator, then a commit on main' \
  $'cat <<E \\\\\nE\ngit commit -m wip'
check_in "$PUSH_MAIN" no-git-push.sh BLOCK 'an even run whose body would have swallowed the terminator' \
  $'cat <<E \\\\\nE\necho after\ngit push --force origin main\nE'
check_in "$ON_MAIN" no-commit-to-main.sh BLOCK 'the same shape on main' \
  $'cat <<E \\\\\nE\necho after\ngit commit -m wip\nE'
check_in "$PUSH_MAIN" no-git-push.sh BLOCK 'an even run of four' \
  $'cat <<E \\\\\\\\\nE\ngit push --force origin main'
# And the permitting direction, which is what says the fix exposed a command
# rather than stopping the drop: the shape the issue ran with `echo RAN-AFTER`
# in place of the push, and a body that merely names one on a continued line.
check_in "$PUSH_MAIN" no-git-push.sh ALLOW 'the same shape, with nothing to refuse after it' \
  $'cat <<E \\\nx\nE\necho RAN-AFTER'
check_in "$ON_MAIN" no-commit-to-main.sh ALLOW 'the same shape on main, with nothing to refuse' \
  $'cat <<E \\\nx\nE\necho RAN-AFTER'
check_in "$PUSH_MAIN" no-git-push.sh ALLOW 'a body naming a push on a continued line' \
  $'cat <<\'E\'\ngit push --force origin main \\\nE'
check_in "$ON_MAIN" no-commit-to-main.sh ALLOW 'a body naming a commit on a continued line' \
  $'cat <<\'E\'\ngit commit -m wip \\\nE'
# What the fix COSTS, which no check above can show: the same 2,580-shape run
# read backwards counts pushes bash never runs that the hook refuses anyway,
# and this change raises that count. Raised on review of this pull request and
# kept. `written`, because it is a measurement in prose and the file is where
# it has to stay true; each pin carries its whole claim on one line, since a
# pin that is a prefix goes on passing after the rest of the sentence is gone.
req GH-128
written 'the library counts what the direction of the fix costs' \
  "$HOOKS/lib/command-scan.sh" \
  '750 such shapes on dev-05, 816 on the first fix, 848 here, of 2,100.'
written 'and decomposes the rise into the two departures already named' \
  "$HOOKS/lib/command-scan.sh" \
  'of the 124 that arrive, 108 are the END give-back and 16 the unquoted-body'

section "=== REGRESSION: review of 02a14d8, bundled gh shorthand flags ==="
# gh takes shorthand flags together, so -ab is --approve --body and approves.
# no-git-push.sh had already answered this for -fu and this file had not: the
# same asymmetry between the siblings, in a second place.
req US-15
check no-pr-decisions.sh BLOCK 'gh pr review -ab "lgtm" 35'  'gh pr review -ab "lgtm" 35'
check no-pr-decisions.sh BLOCK 'gh pr review 35 -ab lgtm'    'gh pr review 35 -ab lgtm'
check no-pr-decisions.sh BLOCK 'gh pr review -rb "no" 35'    'gh pr review -rb "no" 35'
check no-pr-decisions.sh BLOCK 'verdict letter last, -ba'    'gh pr review -ba "lgtm" 35'
# A bundle carrying no verdict letter is still a comment, and a long flag must
# not match on a letter it happens to contain -- --repo is not --request-changes.
req US-15 US-13
check no-pr-decisions.sh ALLOW 'gh pr review -cb "a remark"' 'gh pr review -cb "a remark" 35'
check no-pr-decisions.sh ALLOW 'review --comment with --repo' 'gh pr review --comment --repo o/r -b x 35'

section "=== REGRESSION: review of 02a14d8, a flag before the subcommand ==="
# Cobra resolves the subcommand at the first non-flag argument, so a flag may
# sit in front of it and every rule here wanted it as the third word. -R/--repo
# takes its value as a separate token, which would otherwise be read as the
# subcommand and hide it just as effectively.
req GH-47.1 US-15
check no-pr-decisions.sh BLOCK 'gh pr --repo o/r merge 35'      'gh pr --repo o/r merge 35'
check no-pr-decisions.sh BLOCK 'gh pr -R o/r close 35'          'gh pr -R o/r close 35'
check no-pr-decisions.sh BLOCK 'gh pr --repo=o/r reopen 35'     'gh pr --repo=o/r reopen 35'
check no-pr-decisions.sh BLOCK 'gh pr --repo o/r review -a 35'  'gh pr --repo o/r review -a 35'
check no-pr-decisions.sh BLOCK 'gh release --repo o/r create v1' 'gh release --repo o/r create v1'
# An ordinary subcommand behind a flag is still ordinary.
req GH-47.1 US-13
check no-pr-decisions.sh ALLOW 'gh pr --repo o/r view 35'       'gh pr --repo o/r view 35'
check no-pr-decisions.sh ALLOW 'gh pr --repo o/r list'          'gh pr --repo o/r list'

section "=== REGRESSION: #47, a flag before the group evaded every gh rule ==="
# The same question one level up, and it had been applied at one level only.
# GHPR and GHRELEASE skipped options between the group and the verb and never
# before the group; the two gh api matches skipped none at all. Every BLOCK in
# this block was PERMITTED by the hook on dev-05, and all but the release are a
# decision on a pull request. -R/--repo before the group is not an evasion an
# agent has to construct -- it is the ordinary way to work on a repository from
# elsewhere. The same flag in front of a wrapped command was permitted too;
# that is issue #51, and the sections below close it.
req GH-47.1 US-15
check no-pr-decisions.sh BLOCK 'gh -R o/r pr merge 5'          'gh -R o/r pr merge 5'
check no-pr-decisions.sh BLOCK 'gh --repo o/r pr merge 5'      'gh --repo o/r pr merge 5'
check no-pr-decisions.sh BLOCK 'gh -R o/r pr close 5'          'gh -R o/r pr close 5'
check no-pr-decisions.sh BLOCK 'gh -R o/r pr reopen 5'         'gh -R o/r pr reopen 5'
check no-pr-decisions.sh BLOCK 'gh -R o/r pr review 5 --approve' 'gh -R o/r pr review 5 --approve'
check no-pr-decisions.sh BLOCK 'gh -R o/r release create v1'   'gh -R o/r release create v1'
check no-pr-decisions.sh BLOCK 'gh --hostname h api -X PUT merge' 'gh --hostname h api -X PUT repos/o/r/pulls/5/merge'
check no-pr-decisions.sh BLOCK 'gh -R o/r api graphql merge in a heredoc' $'gh -R o/r api graphql -f query=@- <<EOF\nmutation { mergePullRequest(input:{pullRequestId:"x"}) { clientMutationId } }\nEOF'
# The verdict is matched against the arguments cs_gh_args returns, which are
# this command's own, so it no longer has to say "in the same command as the
# subcommand" as a regular expression -- and the flag may be the first argument
# with no space in front of it, which a pattern requiring one would miss.
check no-pr-decisions.sh BLOCK 'verdict as the first argument'    'gh -R o/r pr review -a 5'
check no-pr-decisions.sh BLOCK 'bundled verdict, first argument'  'gh -R o/r pr review -ab lgtm 5'
# A flag before the group does not make an ordinary subcommand a decision.
req GH-47.1 US-13
check no-pr-decisions.sh ALLOW 'gh -R o/r pr view 5'           'gh -R o/r pr view 5'
check no-pr-decisions.sh ALLOW 'gh -R o/r pr list'             'gh -R o/r pr list'
req GH-47.1 FR-16
check no-pr-decisions.sh ALLOW 'gh -R o/r pr create, based' 'gh -R o/r pr create --base dev-05 --fill'
# The baseless spelling made this point until #40 gave a create a base to
# name. It is refused now, and for the base rather than for the flag, which
# is what the line above still has to show.
req GH-47.1 FR-14
check no-pr-decisions.sh BLOCK 'gh -R o/r pr create --fill'  'gh -R o/r pr create --fill'
req GH-47.1 US-13
check no-pr-decisions.sh ALLOW 'gh -R o/r pr edit 5 --title x' 'gh -R o/r pr edit 5 --title x'
check no-pr-decisions.sh ALLOW 'gh -R o/r pr review --comment' 'gh -R o/r pr review --comment -b x 5'
req GH-47.1 FR-48
check no-pr-decisions.sh ALLOW 'gh -R o/r release list'        'gh -R o/r release list'
# A path word is matched whole, so `release delete` does not cover
# `release delete-asset` the way the old alternation did. The regular
# expression carried delete-asset and nothing asked about it; the rule that
# replaced it named it separately, and these were what would notice if it
# stopped. #97 replaced that rule in turn with an allowlist of read verbs, which
# names no write at all, so these now ask whether delete-asset is still outside
# the list -- and #97's section below asks the rest.
req GH-97.1 FR-48 US-15
check no-pr-decisions.sh BLOCK 'gh release delete-asset'       'gh release delete-asset v1.0.0 file.tgz'
check no-pr-decisions.sh BLOCK 'gh -R o/r release delete-asset' 'gh -R o/r release delete-asset v1.0.0 file.tgz'
req GH-47.1 FR-20
check no-pr-decisions.sh ALLOW 'gh -R o/r api reads a PR'      'gh -R o/r api repos/o/r/pulls/5'
req GH-47.1 US-14
check no-pr-decisions.sh ALLOW 'gh -R o/r issue close 27'      'gh -R o/r issue close 27'

section "=== REGRESSION: #47, a second gh command after ; or && is examined ==="
# Every rule feeds cs_gh_args one command at a time. These three pin that a
# second command is reached at all: a loop that stopped at the first command,
# or at the first that is not a match, permits every one of them.
req GH-47.2 US-15
check no-pr-decisions.sh BLOCK 'a release list, then a create'      'gh release list; gh release create v1'
check no-pr-decisions.sh BLOCK 'a read api call, then a write'      'gh api repos/o/r/pulls/5 && gh api -X PUT repos/o/r/pulls/5/merge'
check no-pr-decisions.sh BLOCK 'a pr create, then a merge'          'gh pr create --fill && gh pr merge 5'

section "=== REGRESSION: #47, cs_gh_args answers about the first match and stops ==="
# What the three above do NOT pin, and were written believing they did. The
# helper scans past a command that is not a match, so for a rule with no
# argument expression the per-command loop and one whole-list call find the
# same thing and the mutation is invisible. It is a rule *with* one that needs
# the loop: the first match's arguments come back and a later command's are
# never seen, so handing cs_gh_args the whole list reads this as the --comment
# alone and permits the approval. Measured, not reasoned -- the whole-list
# mutation fails this line and only this line.
req GH-47.2 US-15
check no-pr-decisions.sh BLOCK 'a comment review, then an approval' 'gh pr review --comment -b x 5 && gh pr review -a 6'

section "=== REGRESSION: #51, a flag before the group evaded the wrapper rules ==="
# The wrapper rules carried the blind spot the section above removed from the
# ordinary ones, one word earlier. They are unanchored, but `pr` still had to
# follow `gh` immediately, so a global flag in front of the group hid it and
# every shape refused above came back the moment it was wrapped. Each of the
# eight rows below was PERMITTED by no-pr-decisions.sh on dev-05 (6f2434c),
# measured before the fix; each is a reserved act. The ninth row is the boundary
# they marked and was refused there already.
req GH-51.1 FR-4 US-15
check no-pr-decisions.sh BLOCK 'bash -c gh -R o/r pr merge'       'bash -c "gh -R o/r pr merge 5"'
check no-pr-decisions.sh BLOCK 'bash -c gh --repo o/r pr merge'   'bash -c "gh --repo o/r pr merge 5"'
check no-pr-decisions.sh BLOCK 'bash -c gh --hostname h pr merge' 'bash -c "gh --hostname h pr merge 5"'
check no-pr-decisions.sh BLOCK 'bash -c gh -R o/r pr close'       'bash -c "gh -R o/r pr close 5"'
check no-pr-decisions.sh BLOCK 'bash -c gh -R o/r pr review -a'   'bash -c "gh -R o/r pr review 5 --approve"'
check no-pr-decisions.sh BLOCK 'bash -c gh -R o/r release create' 'bash -c "gh -R o/r release create v1"'
check no-pr-decisions.sh BLOCK 'sh -c gh -R o/r pr reopen'        'sh -c "gh -R o/r pr reopen 5"'
check no-pr-decisions.sh BLOCK 'eval gh -R o/r release delete'    'eval "gh -R o/r release delete v1"'
# The boundary the table marked: a flag *between* the group and the verb was
# caught by the `.*` all along, so it was the flag before the group alone that
# escaped. Kept so a later change cannot lose the half that worked.
check no-pr-decisions.sh BLOCK 'bash -c gh pr --repo o/r merge'   'bash -c "gh pr --repo o/r merge 5"'

section "=== REGRESSION: review of #51, a continuation split the payload ==="
# These rules read raw text, because cs_normalise drops heredoc bodies and
# `bash <<EOF` is a wrapper. Raw text is line-oriented and grep matches within a
# line, so a backslash continuation between the command word and the group hid
# the group -- from these rules only: the ordinary rules read $SCAN, where
# cs_normalise had already joined it. Found by the Standards review of 48ca05d,
# which measured the claim "anything may stand between gh and the group" rather
# than taking it. The joining half of cs_normalise is cs_join now, and these
# rules call it.
req GH-51.1
check no-pr-decisions.sh BLOCK 'continuation between gh and pr'   $'bash -c "gh \\\n pr merge 5"'
check no-pr-decisions.sh BLOCK 'continuation after a repo flag'   $'bash -c "gh -R o/r \\\n pr merge 5"'
check no-pr-decisions.sh BLOCK 'continuation before the wrapper'  $'bash \\\n -c "gh pr merge 5"'
# The ordinary rules were never blind to this, and still are not.
req FR-3 US-15
check no-pr-decisions.sh BLOCK 'continuation, unwrapped merge'    $'gh \\\n pr merge 5'
# Joining is not dropping: a continuation inside heredoc prose is still prose.
req FR-3 GH-51.1
check no-pr-decisions.sh ALLOW 'a continuation in heredoc prose'  $'cat > /tmp/n.md <<\'MD\'\nthe hook refuses a wrapped \\\ngh pr merge 5\nMD'

section "=== ACCEPTED false positive: #51, the verb is not read inside a wrapper ==="
# What refusing the group outright gives up. These are reads and ordinary edits,
# refused with the writes because a wrapped payload is quoted text with no
# command word in it -- the same reason the method of a wrapped `gh api` is not
# read either, which is the check at 'a GET inside bash -c' above. Every one is
# one edit away from working: run it unwrapped.
req GH-51.2 FR-4
check no-pr-decisions.sh BLOCK 'bash -c gh pr view'          'bash -c "gh pr view 5"'
check no-pr-decisions.sh BLOCK 'bash -c gh pr list'          'bash -c "gh pr list"'
check no-pr-decisions.sh BLOCK 'bash -c gh release list'     'bash -c "gh release list"'
check no-pr-decisions.sh BLOCK 'eval gh api on an issue'     'eval "gh api repos/o/r/issues/27"'
# And the word alone is enough, wherever it sits: inside a wrapper there is no
# argument structure to say whether it is a subcommand or prose. All three
# words, not just the one that names this file's subject.
check no-pr-decisions.sh BLOCK 'bash -c a comment naming pr' 'bash -c "gh issue comment 5 -b \"the pr looks fine\""'
check no-pr-decisions.sh BLOCK 'bash -c a comment naming release' "bash -c \"gh issue comment 5 --body 'approved release notes'\""
check no-pr-decisions.sh BLOCK 'bash -c a comment naming api'     "bash -c \"gh issue comment 5 --body 'the api is down'\""
# The third part of the trade: these rules read the whole command rather than
# the payload, because nothing here can tell the two apart, so an entirely
# unwrapped gh command sharing a line with a wrapper is refused with it. Under
# the old rules only merge|close|reopen reached across the line like this;
# naming the group widens the reach to the reads. Measured dev-05 -> here, each
# of these went ALLOW -> BLOCK.
req GH-51.2 GH-73
check no-pr-decisions.sh BLOCK 'a wrapper elsewhere, then a view'  'bash -c "make test" && gh pr view 5'
check no-pr-decisions.sh BLOCK 'a wrapper elsewhere, then an api'  'bash -c "echo hi"; gh api repos/o/r/issues/27'
# Order does not matter, and CLAUDE.md now says so. Both greps are asked of the
# whole joined command, so neither one knows which side of the line it matched
# on; a rule that looked only ahead of the wrapper would pass the two above and
# fail these, which is what this pair is here to catch. The ALLOW two lines
# down is their arming evidence as much as it is the arming evidence for the
# pair above: same view, wrapper off the line, permitted.
check no-pr-decisions.sh BLOCK 'a view, then a wrapper elsewhere'  'gh pr view 5 && bash -c "make test"'
check no-pr-decisions.sh BLOCK 'an api call, then a wrapper'       'gh api repos/o/r/issues/27; bash -c "echo hi"'
# The reach needs a wrapper on the line to begin with. Without one these rules
# never run, which is what keeps the cost to lines that have both.
req GH-51.2 GH-73 US-13
check no-pr-decisions.sh ALLOW 'the same view with no wrapper'     'make test && gh pr view 5'
# And it needs a wrapper in a COMMAND position, not the word in passing. Only
# the surface half of the pair is the loose one; the wrapper half is anchored,
# and CLAUDE.md says so rather than calling both of them "anywhere".
req GH-51.2 GH-73
check no-pr-decisions.sh ALLOW 'a wrapper named in passing, then a view' \
  'echo "run bash -c later" && gh pr view 5'
check no-pr-decisions.sh ALLOW 'a wrapper named in a comment body' \
  'gh issue comment 5 -b "try bash -c next" && gh pr view 5'
# The surface half is wider than the gh group: the REST and graphql spellings
# of the same decisions name no gh at all, so the reach lands on them too. These
# are what make "asks for the group name and never looks at the verb" the wrong
# description of this block -- three of its five alternatives are verbs.
req GH-51.2
check no-pr-decisions.sh BLOCK 'a wrapper, then a bare state=closed' 'bash -c "make test" && echo state=closed'
check no-pr-decisions.sh BLOCK 'a wrapper, then a bare mutation name' 'bash -c "make test" && echo mergePullRequest'
check no-pr-decisions.sh BLOCK 'a wrapper, then a bare /releases'     'bash -c "make test" && echo /releases'
# And it stops there: a wrapper beside something that decides nothing is not
# this file's business, which is what keeps the four BLOCKs above a reach rather
# than a blanket refusal of every wrapped line.
req GH-51.2 FR-4
check no-pr-decisions.sh ALLOW 'a wrapper, then an ordinary echo'     'bash -c "make test" && echo hello'
# The rule reaches gh's three deciding surfaces and stops there. A wrapped
# command that is none of them is answered by whatever else covers it, and by
# this file not at all.
req FR-4 US-14 GH-51.2
check no-pr-decisions.sh ALLOW 'bash -c gh issue close'      'bash -c "gh issue close 27"'
check no-pr-decisions.sh ALLOW 'bash -c gh issue list'       'bash -c "gh issue list"'
req FR-4
check no-pr-decisions.sh ALLOW 'bash -c an ordinary command' 'bash -c "make test"'

section "=== REGRESSION: #72, gh is a word here and not a suffix ==="
# "The rule reaches gh's three deciding surfaces and stops there" -- the comment
# heading the block above -- is the spec, and the pattern did not implement it.
# (Named rather than pointed at by line count, which any insertion would make
# wrong.) `gh` was the one token in this file matched unbounded on its left, so any
# word ENDING in gh satisfied it -- high, enough, through, sigh, dough -- and
# once a wrapper was on the line, one of those followed by a delimited pr,
# release or api anywhere later was refused. The first row is the one that
# matters: it names no gh, calls no GitHub surface, and is the shape of an
# ordinary commit from inside a wrapper. It was refused with a reason that was
# false rather than merely conservative -- "a shell wrapper does not change what
# the command decides" said to a commit that decides nothing.
#
# The ALLOW directly above was the only fixture guarding this path, and it
# carries neither a gh-ending word nor a trigger token, so no regex could have
# tripped it; its two neighbours exercise the subcommand dimension, not this
# one. That is the hole this section fills. Measured before the one-line fix:
# every ALLOW below was BLOCK.
req GH-72
check no-pr-decisions.sh ALLOW 'bash -c a commit message saying high' \
  "bash -c \"git commit -m 'refactor high level api client'\""
check no-pr-decisions.sh ALLOW 'bash -c grep high pr.txt'      'bash -c "grep high pr.txt"'
check no-pr-decisions.sh ALLOW 'bash -c cat sigh api.md'       'bash -c "cat sigh api.md"'
check no-pr-decisions.sh ALLOW 'bash -c ls dough api'          'bash -c "ls dough api"'
check no-pr-decisions.sh ALLOW 'bash -c echo through pr'       'bash -c "echo through pr"'
check no-pr-decisions.sh ALLOW 'bash -c cat enough release.md' 'bash -c "cat enough release.md"'
# A left boundary, not a left anchor. A path ends in a character that is none of
# gh's own, so an invoked gh still matches wherever it is spelled from. Without
# this pair the boundary could be tightened to `(^|[[:space:]])` -- or the whole
# group anchored -- and nothing in this suite would notice.
check no-pr-decisions.sh BLOCK 'bash -c ./gh pr merge'         'bash -c "./gh pr merge 5"'
check no-pr-decisions.sh BLOCK 'bash -c /usr/bin/gh pr merge'  'bash -c "/usr/bin/gh pr merge 5"'
# The narrowing the boundary accepts, pinned rather than left for a later review
# to find. The character class excludes - and _ as every other token in this
# file does, so a command whose NAME ends in gh behind one of those stops
# matching. Both are evasion shapes rather than mistakes, and the two BLOCKs
# above show the spellings that reach gh itself still refuse; accepted under
# "these stop mistakes, not adversaries". Measured before the fix: both BLOCK.
# This pair is what would notice if the trade were quietly taken back, or
# quietly widened past what the comment on the pattern claims.
check no-pr-decisions.sh ALLOW 'bash -c my-gh pr merge'        'bash -c "my-gh pr merge 5"'
check no-pr-decisions.sh ALLOW 'bash -c my_gh pr merge'        'bash -c "my_gh pr merge 5"'
# The third narrowed shape, and the one with the other cause: a literal \n
# escape puts `n` in front of gh, which no class this file would write admits,
# so this follows from having a left boundary at all rather than from which one.
# It is the single verdict the fix changed across the 7,621-command corpus #72
# sampled. Pinned because the comment on the pattern claims all three are, and a
# check suite is evidence about the cases it names and about nothing else -- the
# two rows above cannot speak for this one, having a different cause.
check no-pr-decisions.sh ALLOW 'bash -c a \n escape before gh' \
  "bash -c \"printf 'summary\\ngh pr review --approve 5' > /tmp/x\""

section "=== issue #117: the command word as a path, quoted or escaped ==="
# The section above accepts three narrowings of GH_SURFACE_ANYWHERE and says, as
# its reason, that `./gh` and `/usr/bin/gh` still refuse. That was true of the
# WRAPPER rule and of nothing else. Outside a wrapper every hook found its
# command by the bare name at ^, so all five spellings of all seven refused
# shapes in #117's table were ALLOW -- `/usr/bin/gh pr merge 5` among them,
# measured at origin/dev-05 d71ab1c.
#
# TWO HALVES, because there are two places a command word is read. cs_split
# normalises the one it emits, which is what every ordinary rule matches on; and
# the wrapper detector reads raw text, where there is no command word to
# normalise, so CS_WRAPPER_RE admits the spellings itself. `/usr/bin/bash -c
# "gh pr merge 5"` was permitted by the same defect wearing the other hat, and
# the rows below hold both halves. Both changes are in lib/command-scan.sh, so
# there is still one answer to where a command word is.
#
# Not an evasion shape only, which is why it is fixed rather than accepted into
# CLAUDE.md's deliberately-left-open list: an agent whose PATH does not carry
# gh, or that copied a path out of `command -v`, writes `/usr/bin/gh` meaning
# nothing by it.
req GH-117
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'gh pr merge as an absolute path' \
  '/usr/bin/gh pr merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'gh pr merge as a relative path' \
  './gh pr merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'gh pr merge, the name double quoted' \
  '"gh" pr merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'gh pr merge, the name single quoted' \
  "'gh' pr merge 5"
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'gh pr merge, the name behind a backslash' \
  '\gh pr merge 5'
# A create naming no base is the other arm of that hook, and it fails open in a
# way the merge rule does not: nothing is matched, so nothing objects.
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'gh pr create naming no base, as an absolute path' \
  '/usr/bin/gh pr create --title t --body b'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'gh pr create --base main, as an absolute path' \
  '/usr/bin/gh pr create --base main --title t'
# The push hook, from the linked worktree, so that the branch named is the one
# thing deciding the verdict. main and --all are refused whoever asks.
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'git push origin main as an absolute path' \
  '/usr/bin/git push origin main'
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'git push origin main as a relative path' \
  './git push origin main'
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'git push origin main, the name double quoted' \
  '"git" push origin main'
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'git push origin main, the name single quoted' \
  "'git' push origin main"
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'git push origin main, the name behind a backslash' \
  '\git push origin main'
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'git push --all as an absolute path' \
  '/usr/bin/git push --all origin'
# The commit hook, in a checkout that is on main, where the bare spelling is the
# refusal the whole file exists for.
flip "$ON_MAIN" no-commit-to-main.sh ALLOW BLOCK 'git commit on main as an absolute path' \
  '/usr/bin/git commit -m wip'
flip "$ON_MAIN" no-commit-to-main.sh ALLOW BLOCK 'git commit on main, the name behind a backslash' \
  '\git commit -m wip'
flip "$ON_MAIN" no-commit-to-main.sh ALLOW BLOCK 'git commit on main, the name single quoted' \
  "'git' commit -m wip"
# The two convention hooks. They are not part of the agent boundary and had the
# identical defect, which is the evidence that this was one question answered in
# one place and not four coincidences.
flip "$SUITE_DIR" pytest-via-uv-group.sh ALLOW BLOCK 'bare pytest as an absolute path' \
  '/usr/bin/pytest tests/'
flip "$SUITE_DIR" pytest-via-uv-group.sh ALLOW BLOCK 'bare pytest, the name double quoted' \
  '"pytest" tests/'
flip "$SUITE_DIR" pytest-via-uv-group.sh ALLOW BLOCK 'python -m pytest as an absolute path' \
  '/usr/bin/python -m pytest tests/'
flip "$SUITE_DIR" pytest-via-uv-group.sh ALLOW BLOCK 'python3 -m pytest as an absolute path' \
  '/usr/bin/python3 -m pytest tests/'
flip "$SUITE_DIR" alembic-via-uv-group.sh ALLOW BLOCK 'bare alembic as an absolute path' \
  '/usr/bin/alembic upgrade head'
flip "$SUITE_DIR" alembic-via-uv-group.sh ALLOW BLOCK 'bare alembic, the name behind a backslash' \
  '\alembic upgrade head'
# A runner that cannot name a dependency group, reached by path. This one is
# worth its own row: the refusal comes from OTHER_RUNNER, which is anchored at ^
# like the rest, while the `pytest` NAME rule beside it is not anchored at all --
# so the fragment already matched the name and stopped, and the hook read a
# command it had already recognised as reaching pytest and let it go.
flip "$SUITE_DIR" pytest-via-uv-group.sh ALLOW BLOCK 'uvx pytest as an absolute path' \
  '/usr/bin/uvx pytest tests/'
# THE TWO TABLE ROWS THE ISSUE BODY DOES NOT CARRY. #117's triage comment
# measured nine seeds where the body measured seven, and the two it added are
# the surfaces no-pr-decisions.sh guards through cs_gh_args rather than through
# the base rule.
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'gh pr review --approve as an absolute path' \
  '/usr/bin/gh pr review --approve 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'gh pr review --approve, the name double quoted' \
  '"gh" pr review --approve 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a merge through gh api, as an absolute path' \
  '/usr/bin/gh api -X PUT repos/o/r/pulls/5/merge'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a merge through gh api, the name behind a backslash' \
  '\gh api -X PUT repos/o/r/pulls/5/merge'
# The two spellings the triage comment names as its own acceptance criterion,
# at the hook rather than only at the tokeniser: partial quoting and a tilde
# path. Neither is one of the five, and both are what bash runs.
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a quote inside the command word' \
  'g"h" pr merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a path under the home directory' \
  '~/bin/gh pr merge 5'
# `python -m pytest` in the spellings the rows above leave. The seed is not one
# of #106's, so the families never reach it, and without these the table row
# would be pinned in two spellings of five. Found by review of this branch.
flip "$SUITE_DIR" pytest-via-uv-group.sh ALLOW BLOCK 'python -m pytest as a relative path' \
  './python -m pytest tests/'
flip "$SUITE_DIR" pytest-via-uv-group.sh ALLOW BLOCK 'python -m pytest, the name double quoted' \
  '"python" -m pytest tests/'
flip "$SUITE_DIR" pytest-via-uv-group.sh ALLOW BLOCK 'python -m pytest, the name single quoted' \
  "'python' -m pytest tests/"
flip "$SUITE_DIR" pytest-via-uv-group.sh ALLOW BLOCK 'python -m pytest, the name behind a backslash' \
  '\python -m pytest tests/'
flip "$SUITE_DIR" pytest-via-uv-group.sh ALLOW BLOCK 'a versioned python by path, -m pytest' \
  '/usr/bin/python3.12 -m pytest tests/'
flip "$SUITE_DIR" alembic-via-uv-group.sh ALLOW BLOCK 'bare alembic as a relative path' \
  './alembic upgrade head'
flip "$SUITE_DIR" alembic-via-uv-group.sh ALLOW BLOCK 'bare alembic, the name single quoted' \
  "'alembic' upgrade head"
# A PREFIX WORD IS MATCHED BY NAME TOO, which is what #117's triage means by
# "the gap is wider than the issue states". `cs_split` strips `sudo`, `env` and
# `timeout` by comparing a token against a list, so every spelling reached them
# exactly as it reached the command word -- and the bare `sudo gh pr merge 5` is
# refused, so the contrast was already in the suite with nothing testing it.
#
# Fixing the command word alone would have left all three, and the triage says
# in as many words what happens then: "the next review round finds it".
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'the prefix word env, as an absolute path' \
  '/usr/bin/env gh pr merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'the prefix word sudo, as an absolute path' \
  '/usr/bin/sudo gh pr merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'the prefix word sudo, as a relative path' \
  './sudo gh pr merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'the prefix word sudo, behind a backslash' \
  '\sudo gh pr merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'the operand word timeout, double quoted' \
  '"timeout" 30 gh pr merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'the prefix word and the command word, both as paths' \
  '/usr/bin/sudo /usr/bin/gh pr merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a prefix word by path in front of a wrapper' \
  '/usr/bin/env bash -c "gh pr merge 5"'
# And the permitting half of that, which is the reason the reduction is bounded
# rather than applied to any token: an ordinary command behind a prefix word
# keeps its verdict, and so does a prefix word whose payload decides nothing.
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'a prefix word in front of an ordinary command' \
  'sudo apt-get install jq'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'env by path in front of an ordinary command' \
  '/usr/bin/env python3 -c "print(1)"'
# THE WRAPPER RULE'S SECOND QUESTION, which is the half #117 reached a round
# late. The block is an `and`: is a wrapper in a command position, and does the
# line carry the surface this hook guards. The first question is
# CS_WRAPPER_RE's and was answered above; the second is each hook's own pattern,
# and every one of the four matched its guarded name by the BARE spelling only.
#
# So the quoting half of #117 leaked at exactly the place the wrapper rule
# exists to close: `bash -c "gh pr merge 5"` refused, `bash -c '"gh" pr merge
# 5'` permitted. The path and backslash spellings already passed, because those
# patterns have a left boundary that admits `/` and `\` -- it is quotes alone
# that never produce the name-then-whitespace the pattern wanted. Found by
# review of this branch, not by this suite, and the requirements entry had
# already been flipped to `active` claiming these spellings reach the bare-name
# verdict in every hook.
#
# Measured before it was taken: across the 476 wrapper-carrying commands in a
# 75,346-command corpus, widening all four patterns changed no verdict at all.
req GH-117
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a wrapped gh pr merge, the name double quoted inside the payload' \
  'bash -c '"'"'"gh" pr merge 5'"'"''
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a wrapped gh pr merge, the name single quoted inside the payload' \
  'bash -c "'"'"'gh'"'"' pr merge 5"'
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'a wrapped push, the name double quoted inside the payload' \
  'bash -c '"'"'"git" push --all origin'"'"''
flip "$ON_MAIN" no-commit-to-main.sh ALLOW BLOCK 'a wrapped commit, the name double quoted inside the payload' \
  'bash -c '"'"'"git" commit -m wip'"'"''
# The spellings that already passed, kept so that widening for quotes cannot be
# mistaken for the whole of what these patterns admit.
check_in "$SUITE_DIR" no-pr-decisions.sh BLOCK 'a wrapped gh pr merge, the name as a path inside the payload' \
  'bash -c "/usr/bin/gh pr merge 5"'
check_in "$SUITE_DIR" no-pr-decisions.sh BLOCK 'a wrapped gh pr merge, the name behind a backslash inside the payload' \
  'bash -c "\gh pr merge 5"'
# ACCEPTED GAP, the same one CS_WORD_SPELLING names one level up: a quoted span
# in the MIDDLE of the word. A character class cannot see that `g"h"` is `gh`,
# and the payload is quoted text, so there is no word to reduce.
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'ACCEPTED gap: a quoted span in the middle of the guarded name, wrapped' \
  'bash -c '"'"'g"h" pr merge 5'"'"''
# #72's decision, held against this widening. A program whose name merely ends
# in the guarded one is a different program, and a quote class in front of the
# name must not turn the left boundary into one that admits `-`.
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'a wrapped my-gh is still a different program' \
  'bash -c "my-gh pr merge 5"'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'and a wrapped my-gh whose name is quoted' \
  'bash -c '"'"'"my-gh" pr merge 5'"'"''
# The permitting direction of the wrapper rule itself: a wrapper whose payload
# decides nothing stays permitted, which is the row CLAUDE.md names in
# consequence 1.
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'a wrapped gh issue list, the name double quoted' \
  'bash -c '"'"'"gh" issue list'"'"''
check_in "$PUSH_WT" no-git-push.sh ALLOW 'a wrapper carrying no push at all' \
  'bash -c "make test"'
# THE OVER-REFUSAL THE PATH SPELLING BROUGHT, recorded rather than fixed. The
# spelling prefix in CS_WRAPPER_RE reaches into quoted text, because a regular
# expression over raw text has no idea what a quote is -- so a sed script whose
# PATTERN names a wrapper is now read as one. Permitted at origin/dev-05,
# refused here. Refusing direction, one edit away, and in the same family as
# consequence 3: a hook cannot tell a command from prose that quotes one.
check_in "$SUITE_DIR" no-git-push.sh BLOCK 'ACCEPTED false positive: a sed script whose pattern names a wrapper and a push' \
  "sed -i 's|/bin/sh -c git push --all origin|X|' hooks.sh"
check_in "$SUITE_DIR" no-git-push.sh ALLOW 'the same sed with no wrapper named in its pattern' \
  "sed -i 's|X|Y|' hooks.sh"
# THE WRAPPER HALF. The payload cannot be read, so the wrapper itself is what is
# recognised -- and it was recognised by the same bare name at a command
# position that everything else used.
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a wrapped gh pr merge, bash as an absolute path' \
  '/usr/bin/bash -c "gh pr merge 5"'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a wrapped gh pr merge, bash as a relative path' \
  './bash -c "gh pr merge 5"'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a wrapped gh pr merge, bash double quoted' \
  '"bash" -c "gh pr merge 5"'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a wrapped gh pr merge, bash single quoted' \
  "'bash' -c \"gh pr merge 5\""
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a wrapped gh pr merge, bash behind a backslash' \
  '\bash -c "gh pr merge 5"'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a wrapped gh pr merge, sh as an absolute path' \
  '/bin/sh -c "gh pr merge 5"'
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'a wrapped push, bash as an absolute path' \
  '/usr/bin/bash -c "git push origin wt-branch"'
flip "$ON_MAIN" no-commit-to-main.sh ALLOW BLOCK 'a wrapped commit on main, bash as an absolute path' \
  '/usr/bin/bash -c "git commit -m wip"'
# THE PERMITTING DIRECTION, and the half that makes the rows above evidence
# rather than a report that these hooks got stricter. Each is a command an agent
# is entitled to run, written in one of the five spellings.
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'gh pr view as an absolute path' \
  '/usr/bin/gh pr view 5'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'gh pr create --base dev-05 as an absolute path' \
  '/usr/bin/gh pr create --base dev-05 --title x'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'gh issue list, the name double quoted' \
  '"gh" issue list'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'a wrapped gh issue list, bash as an absolute path' \
  '/usr/bin/bash -c "gh issue list"'
check_in "$PUSH_WT" no-git-push.sh ALLOW 'this worktree pushing its own branch, as an absolute path' \
  '/usr/bin/git push origin wt-branch'
check_in "$PUSH_WT" no-git-push.sh ALLOW 'this worktree pushing its own branch, the name double quoted' \
  '"git" push origin wt-branch'
check_in "$PUSH_WT" no-git-push.sh ALLOW 'this worktree pushing its own branch, behind a backslash' \
  '\git push origin wt-branch'
check_in "$SUITE_DIR" pytest-via-uv-group.sh ALLOW 'uv run --group test, as an absolute path' \
  '/usr/bin/uv run --group test pytest tests/'
check_in "$SUITE_DIR" alembic-via-uv-group.sh ALLOW 'uv run --group migrations, as an absolute path' \
  '/usr/bin/uv run --group migrations alembic upgrade head'
# A BASENAME IS NOT A SUBSTRING. #72 decided that a program whose name merely
# ends in a guarded one is a different program, and this change could have
# revoked that decision silently -- normalising to "the guarded name appears in
# the word" rather than to the basename would refuse all four of these, and no
# row above would have noticed.
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'a different program named my-gh' \
  'my-gh pr merge 5'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'a different program named my-gh, reached by path' \
  '/usr/local/bin/my-gh pr merge 5'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'a different program named my_gh' \
  'my_gh pr merge 5'
check_in "$PUSH_WT" no-git-push.sh ALLOW 'a directory named for the command is not the command' \
  'ls /usr/bin/git'
# A wrapper word is not a wrapper, and a path ending in one is not either. The
# widened CS_WRAPPER_RE must not read `mybash` as bash, nor a bare path that
# merely holds the letters.
# CONSEQUENCE 6 OF CLAUDE.md's DELIBERATELY-LEFT-OPEN LIST, as verdicts. A
# command word that is a parameter or a command substitution is not resolved,
# and these are the commands that says are permitted. They are checks and not
# just a paragraph because #117's triage raised the question as one to settle
# before implementing, and a decision that lives only in prose is one the next
# review reopens.
#
# PERMIT-ONLY, and it has to be: there is no refusing half of an accepted gap,
# and writing one would be this suite claiming a refusal that does not happen.
# requirements.md carries the direction and the reason with it.
#
# Each of the three was measured across 75,346 commands before it was accepted,
# and the paragraph holds the numbers. The one thing these rows add over the
# paragraph is that they go red if a later change closes a shape by accident --
# which is how a gap stops being a decision and becomes a surprise.
req GH-117.1
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'a command substitution in command position' \
  '$(command -v gh) pr merge 5'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'a backticked command substitution in command position' \
  '`command -v gh` pr merge 5'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'a parameter in command position' \
  '$GH pr merge 5'
check_in "$PUSH_WT" no-git-push.sh ALLOW 'a command substitution in command position, before a push' \
  '$(command -v git) push origin main'
check_in "$PUSH_WT" no-git-push.sh ALLOW 'a parameter in command position, before a push' \
  '$GIT push origin main'
check_in "$ON_MAIN" no-commit-to-main.sh ALLOW 'a command substitution in command position, before a commit on main' \
  '$(command -v git) commit -m wip'
# The line the item draws, as verdicts. A variable that is the whole word is
# unresolved and permitted; a path whose last component is written out is the
# name it spells, whatever the directory part expands to, and is refused. The
# pair is what makes the sentence in CLAUDE.md a measurement rather than a
# guess -- its first draft had the second row the other way round.
check_in "$SUITE_DIR" no-pr-decisions.sh BLOCK 'a variable directory with the guarded name written out' \
  '"$VENV/bin/gh" pr merge 5'
check_in "$SUITE_DIR" pytest-via-uv-group.sh BLOCK 'and the same shape reaching pytest' \
  '"$VENV/bin/pytest" tests/'
check_in "$SUITE_DIR" pytest-via-uv-group.sh ALLOW 'a variable that is the whole word, reaching pytest' \
  '$PYTHON -m pytest tests/'
# The line the rejected close would have refused, and the reason the close was
# rejected: it is a line of this suite being edited, not a command anyone runs
# against GitHub. Kept as a check so that a later attempt at the same close
# fails here rather than in a review.
check_in "$SUITE_DIR" no-git-push.sh ALLOW 'a suite line quoting a push, edited through a command substitution' \
  "\"\$(printf 'sudo git commit -m \"git push --all origin\"\\n' | cs_split)\""
# Back to the reduction itself, which is the rest of this section.
req GH-117
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'a different program named mybash' \
  'mybash -c "gh pr merge 5"'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'a path naming bash as an argument, not as the command' \
  'ls -l /usr/bin/bash'
# WHERE THE TWO HALVES DISAGREE, pinned in both directions rather than described.
# CS_WORD_SPELLING is a regular expression and cw_reduce is a walk, so they do
# not reach the same set, and the comment above CS_WORD_SPELLING says which shape
# each reaches. It said two shapes until Bertan's review of this branch measured
# them and found one: a backslash is not excluded from the run, so an escaped
# slash inside the path IS reached. The pair below is why that cannot go stale
# again -- the spelling that matches and the spelling that does not, each a
# literal verdict.
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a wrapped gh pr merge, an escaped slash inside the path' \
  '/usr\/bin\/bash -c "gh pr merge 5"'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'ACCEPTED gap: a quoted span in the middle of the wrapper name' \
  'b"a"sh -c "gh pr merge 5"'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'ACCEPTED gap: a quoted span in the middle of the wrapper path' \
  '/usr/"bin"/bash -c "gh pr merge 5"'
# THE TRADE THE TAIL CANDIDATES TAKE. Reducing every candidate the prefix strip
# offers -- not only the first -- is what makes `sudo /usr/bin/git push` visible,
# and it also turns a path-shaped ARGUMENT into a name a rule reads. The pair is
# what says this is a decision: behind a prefix word the copy is refused, and
# without one the same command offers no tail and is permitted. Refusing
# direction, recorded at the call site in lib/command-scan.sh.
flip "$SUITE_DIR" pytest-via-uv-group.sh ALLOW BLOCK 'copying the pytest binary, behind a prefix word' \
  'sudo cp /usr/bin/pytest /tmp/'
check_in "$SUITE_DIR" pytest-via-uv-group.sh ALLOW 'copying the pytest binary, with no prefix word' \
  'cp /usr/bin/pytest /tmp/'

section "=== REGRESSION: review of 02a14d8, close and release through gh api ==="
# Closing a PR and publishing a release were refused in the gh spelling and open
# through gh api, so the boundary was spelling-dependent exactly where the file
# says it is not. PATCH /pulls/N is also how gh pr edit retitles, which stays
# allowed, so the field decides this one rather than the endpoint.
req US-15
check no-pr-decisions.sh BLOCK 'PATCH a PR to state=closed'  'gh api -X PATCH repos/o/r/pulls/35 -f state=closed'
check no-pr-decisions.sh BLOCK 'PATCH a PR to state=open'    'gh api -X PATCH repos/o/r/pulls/35 -f state=open'
req US-15 FR-48
check no-pr-decisions.sh BLOCK 'POST a release'              'gh api -X POST repos/o/r/releases -f tag_name=v1'
check no-pr-decisions.sh BLOCK 'DELETE a release'            'gh api -X DELETE repos/o/r/releases/123'
req US-15
check no-pr-decisions.sh BLOCK 'graphql closePullRequest'    'gh api graphql -f query="mutation{closePullRequest(input:{x:1})}"'
req US-15 FR-48
check no-pr-decisions.sh BLOCK 'graphql createRelease'       'gh api graphql -f query="mutation{createRelease(input:{x:1})}"'
req US-15
check no-pr-decisions.sh BLOCK 'graphql state on updatePR'   'gh api graphql -f query="mutation{updatePullRequest(input:{state:CLOSED})}"'
# Retitling through that same endpoint is editing, and listing releases is
# reading. Both stay allowed, which is what makes the field test worth having.
req US-13 FR-20
check no-pr-decisions.sh ALLOW 'PATCH a PR title'            'gh api -X PATCH repos/o/r/pulls/35 -f title=newtitle'
req FR-48
check no-pr-decisions.sh ALLOW 'GET the releases list'       'gh api repos/o/r/releases'
req US-13
check no-pr-decisions.sh ALLOW 'gh pr edit retitles'         'gh pr edit 35 --title newtitle'

section "=== issue #97, a release may be read and not written ==="
# Release actions were refused by name -- create, delete, delete-asset -- and the
# list was a denylist with two writes missing from it. `gh release edit v1
# --draft=false` publishes a draft and `gh release upload` changes a published
# release's assets, and both were permitted. #103's grilling (Q26) settled the
# rule the other way round rather than lengthening the list: the read verbs
# list, view, download, verify and verify-asset are permitted, and every other
# `gh release` subcommand is refused, including one a future gh adds. What was
# rejected is refusing only the acts that publish or destroy, because that means
# reading per-flag release state out of the arguments, and argument parsing is
# where most of this boundary's defects have lived.
#
# The rows that `flip` records were measured against no-pr-decisions.sh at
# origin/dev-05 e8c132f before any fix, and each prints the verdict it had then.
# Reverting the fix fails exactly those, with got equal to the recorded was. The
# `check` rows are the same verdict on both sides and are not evidence about the
# fix. They are what an allowlist has to keep: the reads it must not refuse, the
# refusals the denylist already had, and the gh api half, which already refused
# a write to /releases and permitted a read through gh_api_is_write.
#
# graphql has nothing to check here. The issue refuses a release write through a
# mutation "if one exists", and none does: GitHub's graphql schema listed 259
# mutations on 2026-09-15 and no name among them contains "release", read with
# `gh api graphql -f query='{__schema{mutationType{fields{name}}}}' --jq
# '.data.__schema.mutationType.fields[].name'`. The
# createRelease, updateRelease and deleteRelease names this hook matches are
# refused text rather than mutations, and the check above that pins one of them
# is evidence about the text.
echo "--- every write verb is refused, and so is a verb gh does not have yet ---"
req GH-97.1 FR-48 US-15
check no-pr-decisions.sh BLOCK 'gh release create'                   'gh release create v1'
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'gh release edit --draft=false publishes a draft' \
  'gh release edit v1 --draft=false'
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'gh release edit without --draft=false' \
  'gh release edit v1 --title x'
check no-pr-decisions.sh BLOCK 'gh release delete'                   'gh release delete v1 --yes'
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'gh release upload' \
  'gh release upload v1 a.tgz'
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'gh release upload --clobber replaces an asset' \
  'gh release upload v1 a.tgz --clobber'
check no-pr-decisions.sh BLOCK 'gh release delete-asset'             'gh release delete-asset v1 a.tgz'
# The row that shows the rule is an allowlist and not a longer denylist: no list
# of writes can name a subcommand that does not exist yet.
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'an unknown gh release subcommand' \
  'gh release frobnicate v1'
# And a write the denylist never knew it had: `new` is gh's alias for create
# (gh 2.45.0, `gh help release create`), so the list named create and missed it.
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'gh release new, the alias of create' \
  'gh release new v1'
echo "--- every read verb is permitted ---"
req GH-97.1 FR-48
check no-pr-decisions.sh ALLOW 'gh release list'                     'gh release list'
check no-pr-decisions.sh ALLOW 'gh release view'                     'gh release view v1'
check no-pr-decisions.sh ALLOW 'gh release download'                 "gh release download v1 -p '*.tgz'"
check no-pr-decisions.sh ALLOW 'gh release verify'                   'gh release verify v1'
check no-pr-decisions.sh ALLOW 'gh release verify-asset'             'gh release verify-asset v1 a.tgz'
echo "--- the trade: three reads that are refused, and where to go instead ---"
# The hook's comment above its release rule names these as its three-part trade,
# and a trade written down without a check is a claim, so each part is pinned.
# None of them writes, all are refused, and each is one edit away.
#
# 1. `ls` is gh's alias for list. The allowlist is the five verbs #103 decided,
#    not the five plus whatever gh aliases them to, which is a list that has to
#    track gh's own. The refusal names the five.
req GH-97.1 FR-48
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'gh release ls, an alias of a read, is refused' \
  'gh release ls'
# 2. No subcommand, and a write verb's help page. Allowing these means telling
#    "no subcommand" from "some other subcommand", which means skipping options
#    outside cs_gh_args. The first version of the rule did, with its own copy of
#    the library's skip list, and review of it found the copy. `gh release
#    create --help` was already refused by the denylist, so it is a check.
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'gh release with no subcommand' \
  'gh release'
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'gh release --help' \
  'gh release --help'
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'gh release -R o/r, no subcommand' \
  'gh release -R o/r'
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'a write verb'"'"'s help page' \
  'gh release upload --help'
check no-pr-decisions.sh BLOCK 'a help page the denylist already refused' \
  'gh release create --help'
#    Help is somewhere else, and that has to stay permitted or the trade is not
#    one edit away: `gh help` is not a gh release command at all.
check no-pr-decisions.sh ALLOW 'gh help release'                     'gh help release'
check no-pr-decisions.sh ALLOW 'gh help release upload'              'gh help release upload'
req GH-97.2 US-7
says "$ON_DEV" no-pr-decisions.sh 'gh help release' \
  'the refusal of bare gh release says where help is' 'gh release'
# 3. A quoted verb is matched as written and refused, rather than unquoted into
#    a read -- the generous reading gh_pr_web gives its reasons for not taking.
req GH-97.1 FR-48
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'a quoted read verb' \
  'gh release "view" v1'
echo "--- a flag before the subcommand does not change the verdict ---"
# cs_gh_args skips options before every word of a path, and a subcommand read
# some other way skips none. -R/--repo is the ordinary way to name a repository
# from elsewhere, so each group has both verdicts here, with the flag before the
# verb and with it before the group.
req GH-97.1 GH-47.1
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'gh release -R o/r edit' \
  'gh release -R o/r edit v1'
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'gh release --repo o/r upload' \
  'gh release --repo o/r upload v1 a.tgz'
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'gh release --repo=o/r edit --draft=false' \
  'gh release --repo=o/r edit v1 --draft=false'
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'gh -R o/r release upload' \
  'gh -R o/r release upload v1 a.tgz'
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'gh release -R o/r with an unknown subcommand' \
  'gh release -R o/r frobnicate v1'
check no-pr-decisions.sh ALLOW 'gh release -R o/r view'              'gh release -R o/r view v1'
check no-pr-decisions.sh ALLOW 'gh -R o/r release download'          'gh -R o/r release download v1'
check no-pr-decisions.sh ALLOW 'gh release --repo o/r verify-asset'  'gh release --repo o/r verify-asset v1 a.tgz'
echo "--- the verb is the subcommand word, matched whole, and not any word ---"
# An allowlist asked whether a read verb appears ANYWHERE in the arguments would
# be satisfied by a tag. Release tags are free text, so a tag named view or list
# is an ordinary one to write. The first two rows are the permitting direction.
req GH-97.1
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'an upload to a tag named view' \
  'gh release upload view a.tgz'
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'an edit of a tag named list' \
  'gh release edit list --draft=false'
# The same rule from the other side: a read of a tag named upload is a read.
check no-pr-decisions.sh ALLOW 'a view of a tag named upload'        'gh release view upload'
# A read verb matched as a prefix permits whatever begins with it -- verify
# matched without a right edge also matches verify-asset, and so matches a
# subcommand that is neither. The row is invented because an unknown subcommand
# is the case the rule exists for.
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'a subcommand that only begins with a read verb' \
  'gh release verify-and-publish v1'
echo "--- every gh release command on the line is judged ---"
# cs_gh_args answers about the first match and stops, so a rule that asks it
# about `release` once, over the whole line, reads the first command's verb and
# never sees the second. A read in front of a write is the ordinary shape of
# "look, then change it".
req GH-97.1 GH-47.2
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'a view, then an upload' \
  'gh release view v1 && gh release upload v1 a.tgz'
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'a list, then an edit that publishes' \
  'gh release list; gh release edit v1 --draft=false'
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'a PR read, then an unknown release subcommand' \
  'gh pr view 5 && gh release frobnicate v1'
# The allowlist is about subcommands of gh release, not about text that names one.
req GH-97.1 US-14
check no-pr-decisions.sh ALLOW 'an issue comment naming a release upload' \
  'gh issue comment 97 --body "gh release upload v1 a.tgz is refused now"'
echo "--- the gh api spelling: a write to /releases is refused, a read is not ---"
req GH-97.1 FR-20 US-15
check no-pr-decisions.sh BLOCK 'POST to the releases collection'     'gh api -X POST repos/o/r/releases'
check no-pr-decisions.sh BLOCK 'PATCH a release'                     'gh api -X PATCH repos/o/r/releases/1'
check no-pr-decisions.sh BLOCK 'DELETE a release'                    'gh api -X DELETE repos/o/r/releases/1'
# No method written, and still a write: a field flag makes gh send POST. This is
# gh_api_is_write's question, and the row is what fails if the rule asks -X alone.
check no-pr-decisions.sh BLOCK 'a field makes a releases call a write' \
  'gh api repos/o/r/releases/1 -f draft=false'
# gh release upload's own request, written out. The host is uploads.github.com and
# not api.github.com, so a rule anchored on the API host misses it.
check no-pr-decisions.sh BLOCK 'POST an asset to the uploads host' \
  "gh api --method POST 'https://uploads.github.com/repos/o/r/releases/1/assets?name=a.tgz' --input a.tgz"
check no-pr-decisions.sh BLOCK 'DELETE a release asset'              'gh api -X DELETE repos/o/r/releases/assets/7'
check no-pr-decisions.sh BLOCK 'gh -R o/r api PATCH a release'       'gh -R o/r api -X PATCH repos/o/r/releases/1 -F draft=false'
check no-pr-decisions.sh BLOCK 'a releases read, then a releases write' \
  'gh api repos/o/r/releases && gh api -X PATCH repos/o/r/releases/1 -F draft=false'
req GH-97.1 FR-20
check no-pr-decisions.sh ALLOW 'GET the releases collection'         'gh api repos/o/r/releases'
check no-pr-decisions.sh ALLOW 'GET the latest release'              'gh api repos/o/r/releases/latest'
check no-pr-decisions.sh ALLOW 'GET a release by tag, method named'  'gh api -X GET repos/o/r/releases/tags/v1'
check no-pr-decisions.sh ALLOW 'GET a release'"'"'s assets'          'gh api repos/o/r/releases/1/assets'
echo "--- the refusal says what the rule is ---"
# A refusal that names only publishing and deleting is false for an upload, and
# says nothing about what an agent may still do. The literals below are the
# wording #97 settled on for CLAUDE.md and CONTEXT.md, so the message and the
# documents say the same thing. Every `says` is red on the dev-05 hook, whose
# message is "publishing or deleting a GitHub release is Bertan's call". The
# `says_not` is green there for no good reason, since nothing refused the upload
# at all. It is the pair with the `says` above it that means something.
req GH-97.2 US-7
says "$ON_DEV" no-pr-decisions.sh "any write to a release is Bertan's" \
  'gh release refusal: a release write is Bertan'"'"'s' 'gh release upload v1 a.tgz'
says "$ON_DEV" no-pr-decisions.sh 'Reading one is permitted' \
  'gh release refusal: reading is permitted' 'gh release upload v1 a.tgz'
says_not "$ON_DEV" no-pr-decisions.sh 'publishing or deleting' \
  'gh release refusal: an upload is not described as publishing or deleting' 'gh release upload v1 a.tgz'
says "$ON_DEV" no-pr-decisions.sh "any write to a release is Bertan's" \
  'unknown subcommand refusal: a release write is Bertan'"'"'s' 'gh release frobnicate v1'
says "$ON_DEV" no-pr-decisions.sh 'Reading one is permitted' \
  'unknown subcommand refusal: reading is permitted' 'gh release frobnicate v1'
says "$ON_DEV" no-pr-decisions.sh "any write to a release is Bertan's" \
  'gh api refusal: a release write is Bertan'"'"'s' 'gh api -X PATCH repos/o/r/releases/1'
says "$ON_DEV" no-pr-decisions.sh 'Reading one is permitted' \
  'gh api refusal: reading is permitted' 'gh api -X PATCH repos/o/r/releases/1'
# Unlike the upload's, this `says_not` is red on dev-05: the gh api spelling was
# refused there, in the old words, so a revert of this message alone shows here.
says_not "$ON_DEV" no-pr-decisions.sh 'publishing or deleting' \
  'gh api refusal: a PATCH is not described as publishing or deleting' 'gh api -X PATCH repos/o/r/releases/1'

section "=== issue #40, a pull request must name an active dev branch as its base ==="
# The quietest of the four spellings names nothing at all: with no base given,
# gh sends the pull request to the repository's default branch, which is main.
# Nothing in the command mentions main, so a denylist over the text could not
# have seen it -- the same shape as the bare push, which is answered the same
# way. The four spellings are checked together because closing one and leaving
# the others is the defect this ticket was filed against.
req FR-16 FR-15 US-8
check no-pr-decisions.sh BLOCK 'create into main'                'gh pr create --base main --title x'
check no-pr-decisions.sh BLOCK 'create into main, --base='       'gh pr create --base=main --title x'
check no-pr-decisions.sh BLOCK 'create into main, -B'            'gh pr create -B main --title x'
check no-pr-decisions.sh BLOCK 'create into main, -B attached'   'gh pr create -Bmain --title x'
check no-pr-decisions.sh BLOCK 'create into main, bundled -dB'   'gh pr create -dB main --title x'
check no-pr-decisions.sh BLOCK 'create into main, bundled -dBmain' 'gh pr create -dBmain --title x'
req FR-14 FR-16 US-9
check no-pr-decisions.sh BLOCK 'create naming no base at all'    'gh pr create --title x --body y'
check no-pr-decisions.sh BLOCK 'a bare create'                   'gh pr create'
check no-pr-decisions.sh BLOCK 'create with --fill and no base'  'gh pr create --fill'
check no-pr-decisions.sh BLOCK 'a base flag whose value never came' 'gh pr create --title x -B'
req FR-15 FR-16 US-8
check no-pr-decisions.sh BLOCK 'create into master'              'gh pr create --base master --title x'
check no-pr-decisions.sh BLOCK 'create into a worktree branch'   'gh pr create --base worktree-issue-40-pr-base'
check no-pr-decisions.sh BLOCK 'create into dev-05-ish, not dev-NN' 'gh pr create --base dev-05-old'
# A flag may sit in front of the verb, which is what cs_gh_args is for; and the
# check is of every create on the line rather than the first, which is what
# obliges the loop to hand it one command at a time.
req FR-14 GH-47.1
check no-pr-decisions.sh BLOCK 'flag before the verb, no base'   'gh pr --repo o/r create --title x'
req FR-15 GH-47.2
check no-pr-decisions.sh BLOCK 'a good create, then one into main' 'gh pr create --base dev-05 --title x && gh pr create --base main --title y'
# Retargeting is choosing the destination a second time.
req FR-17 FR-15 US-10
check no-pr-decisions.sh BLOCK 'retarget to main'                'gh pr edit 35 --base main'
check no-pr-decisions.sh BLOCK 'retarget to main, -B'            'gh pr edit 35 -B main'
check no-pr-decisions.sh BLOCK 'retarget, flag before the verb'  'gh pr --repo o/r edit 35 --base main'
# The API forms. The gate is the write test the file already had, not the
# endpoint: matching an endpoint is what once refused a read of a pull request
# as though it were a decision.
req FR-18 FR-15 US-11
check no-pr-decisions.sh BLOCK 'REST create into main'           'gh api -X POST repos/o/r/pulls -f base=main -f head=x'
check no-pr-decisions.sh BLOCK 'REST create, value attached'     'gh api -X POST repos/o/r/pulls -fbase=main'
req FR-18 FR-14 US-11
check no-pr-decisions.sh BLOCK 'REST create naming no base'      'gh api -X POST repos/o/r/pulls -f head=x -f title=y'
req FR-18 FR-17 US-10
check no-pr-decisions.sh BLOCK 'REST retarget to main'           'gh api -X PATCH repos/o/r/pulls/35 -f base=main'
req FR-19 FR-15 US-11
check no-pr-decisions.sh BLOCK 'graphql create into main'        'gh api graphql -f query="mutation{createPullRequest(input:{baseRefName:main})}"'
check no-pr-decisions.sh BLOCK 'graphql create, base quoted'     "gh api graphql -f query='mutation{createPullRequest(input:{baseRefName:\"main\"})}'"
req FR-19 FR-14 US-11
check no-pr-decisions.sh BLOCK 'graphql create naming no base'   'gh api graphql -f query="mutation{createPullRequest(input:{headRefName:x})}"'
# A wrapper hides the base behind quotes, where there is no command position to
# find and nothing to read. Refused outright, as a wrapped push and a wrapped
# read of a pull request already are.
req FR-4 GH-51.2
check no-pr-decisions.sh BLOCK 'a good create inside bash -c'    "bash -c 'gh pr create --base dev-05 --title x'"
check no-pr-decisions.sh BLOCK 'a REST create inside bash -c'    "bash -c 'gh api -X POST repos/o/r/pulls -f base=dev-05'"
# The accepted false positive, recorded rather than worked around: cs_split cuts
# on the parens of a command substitution, so a base written after one lands in
# a later fragment and the create no longer names one. Put the base first.
req FR-14
check no-pr-decisions.sh BLOCK 'base written after a substitution' 'gh pr create --title x --body "$(cat b.md)" --base dev-05'

section "=== issue #40, a base naming a dev branch is permitted in every spelling ==="
req FR-14 FR-15 FR-16 US-8 US-9
check no-pr-decisions.sh ALLOW 'create into the dev branch'      'gh pr create --base dev-05 --title x --body y'
check no-pr-decisions.sh ALLOW 'create into dev, --base='        'gh pr create --base=dev-05 --title x'
check no-pr-decisions.sh ALLOW 'create into dev, -B'             'gh pr create -B dev-05 --title x'
check no-pr-decisions.sh ALLOW 'create into dev, -B attached'    'gh pr create -Bdev-05 --title x'
check no-pr-decisions.sh ALLOW 'create into an older dev-NN'     'gh pr create --base dev-04 --title x'
check no-pr-decisions.sh ALLOW 'flag before the verb, good base' 'gh pr --repo o/r create --base dev-05 --title x'
check no-pr-decisions.sh ALLOW 'base first, then a substitution' 'gh pr create --base dev-05 --body "$(cat b.md)"'
# The browser hand-off creates nothing: a person on the prefilled page chooses
# the base and confirms. That exempts a missing base and nothing else.
req FR-21 US-12
check no-pr-decisions.sh ALLOW 'browser hand-off, --web'         'gh pr create --web'
check no-pr-decisions.sh ALLOW 'browser hand-off, -w'            'gh pr create -w'
check no-pr-decisions.sh BLOCK '--web does not launder a base'   'gh pr create --web --base main'
req FR-17 US-10 FR-15
check no-pr-decisions.sh ALLOW 'retarget to the dev branch'      'gh pr edit 35 --base dev-05'
req US-13 FR-17
check no-pr-decisions.sh ALLOW 'edit without touching the base'  'gh pr edit 35 --add-label bug'
req FR-18 US-11 FR-15
check no-pr-decisions.sh ALLOW 'REST create into dev'            'gh api -X POST repos/o/r/pulls -f base=dev-05 -f head=x'
req FR-19 US-11 FR-15
check no-pr-decisions.sh ALLOW 'graphql create into dev'         "gh api graphql -f query='mutation{createPullRequest(input:{baseRefName:\"dev-05\"})}'"
# Reads name no destination and are not asked for one, which is what keeps the
# write test doing this work rather than the endpoint.
req FR-20 US-13
check no-pr-decisions.sh ALLOW 'listing pull requests'           'gh api repos/o/r/pulls'
check no-pr-decisions.sh ALLOW 'reading one pull request'        'gh api repos/o/r/pulls/35'
check no-pr-decisions.sh ALLOW 'listing beside another write'    'gh api -X POST repos/o/r/issues -f title=x && gh api repos/o/r/pulls'
# A write that names no base and creates nothing is not a pull request at all.
check no-pr-decisions.sh ALLOW 'PATCH a PR body, the -F habit'   'gh api -X PATCH repos/o/r/pulls/35 -F body=@body.md'
req FR-20 US-14
check no-pr-decisions.sh ALLOW 'creating an issue'               'gh api -X POST repos/o/r/issues -f title=x'
req US-14 FR-14
check no-pr-decisions.sh ALLOW 'gh issue create names no base'   'gh issue create --title x --body y'

section "=== REGRESSION: review of be0e3c7, the base rule's own permitting holes ==="
# Four found by review, none of them named by the section above, which was green.
# The pattern of this repository holds a fifth time: every one was silent and in
# the permitting direction.
#
# 1. A repeated flag. gh takes the last; the rule read the first, so a create
# that had already shown a dev branch could name main after it and go there.
# Every base must now be dev-NN, which does not depend on knowing gh's
# precedence.
req FR-15 FR-16
check no-pr-decisions.sh BLOCK 'good base, then a bad one'   'gh pr create --base dev-05 -B main'
check no-pr-decisions.sh BLOCK 'bad base, then a good one'   'gh pr create -B main --base dev-05'
check no-pr-decisions.sh BLOCK 'two long bases disagreeing'  'gh pr create --base dev-05 --base main'
# 2. The web exemption read any single-dash token holding a w, and read it out of
# quoted prose. Both halves mattered: a label value, and a title naming a flag --
# a title a session working on this very file would write.
req FR-21 FR-14
check no-pr-decisions.sh BLOCK 'a label value beginning -w'  'gh pr create -l -wip --title x'
check no-pr-decisions.sh BLOCK 'a bundle holding w'          'gh pr create -twibble --body y'
check no-pr-decisions.sh BLOCK 'a title naming -w'           'gh pr create --title "Handle -w in gh_pr_web" --body y'
check no-pr-decisions.sh BLOCK 'a body naming -watch'        'gh pr create --title x --body "adds -watch mode"'
# The exemption itself still works. The asymmetry that used to be recorded here
# is gone: both readers drop a quoted span whole now. Unquoting one can invent a
# flag, and inventing a --base in a command that named none removes a refusal
# just as inventing a -w does, which is the half this comment used to miss. See
# base_args, and group 5.
req FR-21 US-12
check no-pr-decisions.sh ALLOW 'the web form, unbundled'     'gh pr create -w --title x'
check no-pr-decisions.sh ALLOW 'the web form, long'          'gh pr create --web --title x'
# Still refused, and now for naming no base rather than for naming a bad one.
req FR-14
check no-pr-decisions.sh BLOCK 'a title naming -B main'      'gh pr create --title "-B main" --body y'

# 5. A base read out of prose. `tr -d` deleted the quote characters and kept
# what stood between them, so a body naming the flag named a base in a command
# that named none -- and gh would have sent that create to the repository
# default branch with this hook satisfied, which is the one shape #40 exists to
# refuse, arriving through a body. The trigger is not contrived: a body quoting
# the command it is about is how the pull requests in this repository are
# written. base_args drops a quoted span whole and unquotes only a base flag own
# value.
req FR-14
check no-pr-decisions.sh BLOCK 'a base named only in a body'      'gh pr create --title t --body "--base dev-05"'
check no-pr-decisions.sh BLOCK 'a base named only in a title'     'gh pr create --title "--base dev-05" --body b'
check no-pr-decisions.sh BLOCK 'a body quoting the command'       'gh pr create --title x --body "Write: gh pr create --base dev-05 --title ..."'
check no-pr-decisions.sh BLOCK 'a shorthand base in a body'       'gh pr create --title t --body "-B dev-05"'
# The other direction, which the same defect caused: prose naming the flag made
# a correct create refuse.
req FR-14 FR-15
check no-pr-decisions.sh ALLOW 'a body naming the base flag'      'gh pr create --base dev-05 --title t --body "the --base flag"'
check no-pr-decisions.sh ALLOW 'a body naming a main retarget'    'gh pr create --base dev-05 --title t --body "use -B main to retarget"'
check no-pr-decisions.sh ALLOW 'an edit titled after the flag'    'gh pr edit 5 --title "--base main"'
# A base flag own value is the one quoted span that is kept, in either quote,
# because gh takes either. Dropping it would refuse a correctly based create.
req FR-15
check no-pr-decisions.sh ALLOW 'a double-quoted base value'       'gh pr create --base "dev-05" --title t'
check no-pr-decisions.sh ALLOW 'a single-quoted base value'       "gh pr create --base 'dev-05' --title t"
check no-pr-decisions.sh BLOCK 'a quoted base naming main'        'gh pr create --base "main" --title t'
check no-pr-decisions.sh BLOCK 'a quoted retarget to main'        'gh pr edit 5 --base "main"'
# 6. A graphql string value is quoted, and the shell quoting around the query
# commonly escapes those quotes. gql_bases read the backslash as the whole value
# and refused a dev-NN base for not being one. Refusing direction, so it sat
# behind the two spellings that did work, both of which are pinned above.
req FR-19 FR-15
check no-pr-decisions.sh ALLOW 'graphql into dev, escaped'        'gh api graphql -f query="mutation{createPullRequest(input:{baseRefName:\"dev-05\"})}"'
check no-pr-decisions.sh BLOCK 'graphql into main, escaped'       'gh api graphql -f query="mutation{createPullRequest(input:{baseRefName:\"main\"})}"'
# 3. The gh api base was read from the whole line, so a neighbouring command
# answered for this one -- in both directions. This is the first of the five
# defects lib/command-scan.sh exists to end, reintroduced for gh api after being
# fixed for gh pr.
req FR-18 GH-47.2 FR-14
check no-pr-decisions.sh BLOCK 'a base on a neighbour'       'echo base=dev-05 && gh api -X POST repos/o/r/pulls -f head=x'
check no-pr-decisions.sh BLOCK 'good create, then one to main' 'gh api -X POST repos/o/r/pulls -f base=dev-05 && gh api -X POST repos/o/r/pulls -f base=main'
check no-pr-decisions.sh BLOCK 'a dev base hidden in a title' 'gh api -X POST repos/o/r/pulls -f base=main -f title="retarget of base=dev-05"'
check no-pr-decisions.sh BLOCK 'a title standing in for a base' 'gh api -X POST repos/o/r/pulls -f head=x -f title="base: dev-05"'
check no-pr-decisions.sh BLOCK 'two REST bases disagreeing'  'gh api -X POST repos/o/r/pulls -f base=dev-05 -f base=main'
# This one is what makes the scoping load-bearing rather than merely tidy. The
# base belongs to the issue write; the create beside it names none of its own,
# and a rule reading the line would let that base answer for both. Anchoring on
# the field flag and requiring every base to be dev-NN fixes the other leaks
# whatever the scope, so without this case the scope could be widened again and
# the suite would not notice -- which is exactly what a mutation run showed.
check no-pr-decisions.sh BLOCK 'a base belonging to another write' 'gh api -X POST repos/o/r/issues -f base=dev-05 && gh api -X POST repos/o/r/pulls -f head=x'
# ... and an unrelated write must not be refused by a neighbour either.
req FR-20 US-14
check no-pr-decisions.sh ALLOW 'an issue write beside prose' 'gh api -X POST repos/o/r/issues -f title=x && echo "base=main"'
check no-pr-decisions.sh ALLOW 'an issue write naming rebase' 'gh api -X POST repos/o/r/issues -f title="rebase onto main"'
# The graphql retarget carries the same field as the create, and is refused with
# it rather than by naming the verb.
req FR-19 FR-17
check no-pr-decisions.sh BLOCK 'graphql retarget to main'    'gh api graphql -f query="mutation{updatePullRequest(input:{baseRefName:main})}"'
# 4. These two were pinned ALLOW while #40 carried a wrapper rule of its own,
# which read the payload far enough to tell a listing from a create. #51
# settled that the payload cannot be read at all and refuses every wrapped
# gh pr, gh release and gh api whatever follows, so #40 no longer has a
# wrapper rule and these are refused with the rest of that surface. Both are
# one edit away from working: run them unwrapped.
req GH-51.2 FR-4
check no-pr-decisions.sh BLOCK 'a wrapped listing'           "bash -c 'gh api repos/o/r/pulls'"
check no-pr-decisions.sh BLOCK 'a wrapped label edit'        "bash -c 'gh pr edit 35 --add-label bug'"
check no-pr-decisions.sh BLOCK 'a wrapped retarget'          "bash -c 'gh pr edit 35 --base main'"
check no-pr-decisions.sh BLOCK 'a wrapped REST create'       "bash -c 'gh api -X POST repos/o/r/pulls -f base=dev-05'"
# What #40's own wrapper rule used to refuse, still refused, by #51 naming the
# surface rather than by anything reading a base out of quoted text.
check no-pr-decisions.sh BLOCK 'a wrapped create into main'  'bash -c "gh pr create --base main"'
check no-pr-decisions.sh BLOCK 'a wrapped create, flag first' 'bash -c "gh -R o/r pr create --base main"'
check no-pr-decisions.sh BLOCK 'a wrapped baseless create'   'bash -c "gh pr create --fill"'

section "=== issue #137, the field readers knew one quote spelling of their own field ==="
# Two rules in no-pr-decisions.sh read the value of a named FIELD rather than an
# endpoint: `state` decides whether a gh api write closes or reopens a pull
# request, and `base` decides where one is proposed. Each knew one spelling of
# the quoting round its own field, and the gap ran in OPPOSITE DIRECTIONS
# because the two are triggered oppositely. State refuses on PRESENCE, so a
# spelling it could not see was a refusal that did not happen: `-f
# state='closed'` closed a pull request. Base refuses on ABSENCE, so a spelling
# it could not see was a base that was not there: `-f "base=dev-05"` was refused
# for naming no base, into the one branch an agent may propose into.
#
# Found while grilling #130's fix design, not by this suite, which was green.
# It pinned `state=closed` and `state=open` bare and nothing else, and `-f
# base=dev-05` bare and nothing else. A check suite is evidence about the cases
# it names and about nothing else. No ordinal is written here on purpose: the
# section two above counts "a fifth time" and nothing counts either, so a second
# uncounted counter would be one more number to go stale unwatched.
#
# WHICH OF THESE 41 ROWS CAN FAIL, measured rather than argued, by judging three
# broken copies of .claude/hooks/ through $CHECK_HOOKS_DIR -- this repository's
# own hooks were never edited. Eighteen distinct rows go red:
#
#   STATE_FIELD_RE back to `"?(closed|open)"?`        6 rows
#     the four single-quoted spellings below, and the two wrapper rows.
#   rest_bases back to no quote between flag and name 10 rows
#     the six dev-05 creates, the two retargets to main, and both message rows.
#   the fix applied to the write block and not to the wrapper arm  4 rows
#     the two wrapper rows again, and the static pair.
#
# The other twenty-three reach the same verdict with the fix reverted, and each
# block below says which kind it is rather than leaving a reader to assume they
# all go red. Fourteen are CONTRAST rows -- spellings the old patterns already
# reached, three of them reaching the right verdict for the wrong reason, which
# is what the two message rows exist to separate. Nine are ARMING and PROPERTY
# rows: that the widening did not swallow an ordinary retitle, that the value
# alternation still bites, and that the flag anchor still keeps `rebase`,
# `database` and a quoted title out of the base.
#
# THE STATE READER, at the gh api write block. Rows 1 and 2 are CONTRAST and
# stay green on revert: the old pattern admitted a double quote round the value
# and not a single one, so they are the shape the hole is read against. Rows 3
# and 4 are the hole, and go red.
req US-15 GH-137.1
check no-pr-decisions.sh BLOCK 'PATCH to state, value bare'        'gh api -X PATCH repos/o/r/pulls/5 -f state=closed'
check no-pr-decisions.sh BLOCK 'PATCH to state, value double-quoted' 'gh api -X PATCH repos/o/r/pulls/5 -f state="closed"'
check no-pr-decisions.sh BLOCK 'PATCH to state, value single-quoted' "gh api -X PATCH repos/o/r/pulls/5 -f state='closed'"
check no-pr-decisions.sh BLOCK 'PATCH to state=open, single-quoted'  "gh api -X PATCH repos/o/r/pulls/5 -f state='open'"
# The quote round the WHOLE field rather than round the value, in both styles,
# on the long flag and with the field attached to the short one. gh reads all of
# these as the one request. The first two -- one double-quoted, one single --
# pass BEFORE this fix as well as after, through the raw grep alone, and are
# pinned for what they would catch later: re-anchoring this reader on its field
# flag, which is the shape rest_bases has and the obvious next refactor, turns
# them red instead of inheriting the gap this issue closed in base. The other
# two go red on revert.
check no-pr-decisions.sh BLOCK 'the whole state field double-quoted' 'gh api -X PATCH repos/o/r/pulls/5 -f "state=closed"'
check no-pr-decisions.sh BLOCK 'the whole state field single-quoted' "gh api -X PATCH repos/o/r/pulls/5 -f 'state=closed'"
check no-pr-decisions.sh BLOCK '--field, state value single-quoted'  "gh api -X PATCH repos/o/r/pulls/5 --field state='closed'"
check no-pr-decisions.sh BLOCK 'short flag with the field attached'  "gh api -X PATCH repos/o/r/pulls/5 -fstate='closed'"
# THE SAME READER AT ITS OTHER CALL SITE. The wrapper arm asks the same question
# and carried its own copy of the pattern, so a fix applied to one call site and
# not the other would leave this green. These reach that arm with NO gh on the
# line: the surface alternative beside it would answer for a wrapped `gh api`
# whatever the state rule said, which is what makes these rows evidence about
# the state arm rather than about the wrapper rule. Same shape as the bare
# `echo state=closed` row under ACCEPTED false positive: #51. The first two go
# red twice over -- on the state revert and on the one-call-site revert, which
# is what makes them the rows that tell the two apart. The third is CONTRAST.
req GH-51.2 GH-137.1
check no-pr-decisions.sh BLOCK 'a wrapper, then a single-quoted state' \
  "bash -c \"make test\" && echo state='closed'"
check no-pr-decisions.sh BLOCK 'a wrapper, then a single-quoted open' \
  "bash -c \"make test\" && echo state='open'"
check no-pr-decisions.sh BLOCK 'a wrapper, then the whole field quoted' \
  "bash -c \"make test\" && echo 'state=closed'"
# The pattern is written once and both call sites read it, which is the half of
# this fix no verdict above can see: two copies that agree today are two copies
# that can be fixed apart tomorrow, and that is how this defect was made. Both
# go red on the one-call-site revert and on nothing else.
#
# OCCURRENCES, not matching lines, and FULL-LINE comments stripped rather than
# everything after the first `#`. Bertan's review of PR #153 found both halves
# loose in the permitting direction: `grep -c` counts lines, so two copies
# written on one line read as one, and a stripper cutting at the first `#`
# anywhere cuts into live code -- this file already carries `${TOK#--base=}` --
# so a copy written after a `#` on a code line was invisible to the count. A
# trailing comment that quotes the pattern now counts against the total, which
# is the refusing direction and one edit away.
req GH-137.1
tok 'no-pr-decisions.sh: the state pattern is written once, not once per call site' \
    '1' "$(sed 's/^[[:space:]]*#.*$//' "$HOOKS/no-pr-decisions.sh" \
          | grep -o 'closed|open' | wc -l | tr -d '[:space:]')"
tok 'no-pr-decisions.sh: both state call sites read that one pattern' \
    '2' "$(sed 's/^[[:space:]]*#.*$//' "$HOOKS/no-pr-decisions.sh" \
          | grep -oF 'grep -qiE "$STATE_FIELD_RE"' | wc -l | tr -d '[:space:]')"
# The arming evidence. The state rule is keyed on the field and not on the
# endpoint, for the reason its own comment gives -- the same PATCH is how `gh pr
# edit` retitles a pull request -- so a widened quote class that swallowed an
# ordinary edit would be this fix going wrong in the refusing direction. And the
# value alternation still bites: a quote round the value is not a licence for
# any value. All three are ARMING and stay green on revert, as arming evidence
# must: they say the fix did not break what was already right.
req US-13 FR-20 GH-137.1
check no-pr-decisions.sh ALLOW 'PATCH a title, whole field quoted'  'gh api -X PATCH repos/o/r/pulls/35 -f "title=newtitle"'
check no-pr-decisions.sh ALLOW 'PATCH a title, value single-quoted' "gh api -X PATCH repos/o/r/pulls/35 -f title='newtitle'"
check no-pr-decisions.sh ALLOW 'a quoted state that is neither'     "gh api -X PATCH repos/o/r/pulls/35 -f state='draft'"

# THE BASE READER. rest_bases anchors on the field flag, and the field name had
# to follow it immediately -- so the quote gh accepts round a whole field hid
# the base entirely and the no-base arm fired. Five spellings of one request;
# the first three go red on revert, and the last two are CONTRAST -- the
# value-quoted pair the old pattern already read, kept as the contrast that says
# where the hole was.
req FR-18 FR-15 US-11 GH-137.2
check no-pr-decisions.sh ALLOW 'REST create, whole field double-quoted' 'gh api -X POST repos/o/r/pulls -f "base=dev-05" -f head=x'
check no-pr-decisions.sh ALLOW 'REST create, whole field single-quoted' "gh api -X POST repos/o/r/pulls -f 'base=dev-05' -f head=x"
check no-pr-decisions.sh ALLOW '--field, whole field double-quoted'     'gh api -X POST repos/o/r/pulls --field "base=dev-05" -f head=x'
check no-pr-decisions.sh ALLOW 'REST create, value double-quoted'       'gh api -X POST repos/o/r/pulls -f base="dev-05" -f head=x'
check no-pr-decisions.sh ALLOW 'REST create, value single-quoted'       "gh api -X POST repos/o/r/pulls -f base='dev-05' -f head=x"
req FR-17 US-10 FR-15 GH-137.2
check no-pr-decisions.sh ALLOW 'REST retarget to dev, field quoted'     'gh api -X PATCH repos/o/r/pulls/35 -f "base=dev-05"'
# The other direction of the same read, and the one that makes this a hole in
# both: a base the reader cannot see is not only a permitted create refused, it
# is a BAD base unseen. The POST was refused before this fix and the PATCH was
# not -- the no-base arm the POST fell into is keyed on the collection endpoint,
# and /pulls/35 is not one. So a retarget to main with the field quoted was
# permitted, a consequence the issue's own table does not name. The two creates
# are CONTRAST of the third kind: refused before this fix and refused after, but
# before it for naming NO base, which is what the message rows below separate.
# The two retargets go red.
req FR-18 FR-15 US-11 GH-137.2
check no-pr-decisions.sh BLOCK 'REST create into main, field quoted'   'gh api -X POST repos/o/r/pulls -f "base=main" -f head=x'
check no-pr-decisions.sh BLOCK 'REST create into main, single-quoted'  "gh api -X POST repos/o/r/pulls -f 'base=main' -f head=x"
req FR-18 FR-17 US-10 GH-137.2
check no-pr-decisions.sh BLOCK 'REST retarget to main, field quoted'   'gh api -X PATCH repos/o/r/pulls/35 -f "base=main"'
check no-pr-decisions.sh BLOCK 'REST retarget to main, single-quoted'  "gh api -X PATCH repos/o/r/pulls/35 -f 'base=main'"
# WHICH refusal fires, not just that one does. Before the fix the quoted create
# into main was refused for naming NO base, so the message told an agent to name
# a base it had already named -- the same two halves of #40 that the messages
# above are kept apart for. Both go red on revert, and they are the only rows
# that see this half of the defect: the verdict was right throughout.
req US-7 FR-23 GH-137.2
says "$ON_DEV" no-pr-decisions.sh 'This names main;' \
  'a quoted base into main says which branch it named' \
  'gh api -X POST repos/o/r/pulls -f "base=main" -f head=x'
says_not "$ON_DEV" no-pr-decisions.sh 'No base is named here' \
  'and does not say that no base was named' \
  'gh api -X POST repos/o/r/pulls -f "base=main" -f head=x'
# rest_bases' existing property, asked again with the quote in it. The flag
# anchor is what keeps `rebase` and `database` the words they are, and what
# keeps a base out of prose; admitting a quote in ONE position between the flag
# and the name leaves all of that where it was. PROPERTY rows, green on revert:
# what they assert is what must not have changed.
req FR-14 GH-137.2
check no-pr-decisions.sh BLOCK 'a quoted title is still not a base'    'gh api -X POST repos/o/r/pulls -f head=x -f title="base: dev-05"'
check no-pr-decisions.sh BLOCK 'a quoted title naming the flag'        'gh api -X POST repos/o/r/pulls -f head=x -f "title=base=dev-05"'
req FR-20 US-14 GH-137.2
check no-pr-decisions.sh ALLOW 'a quoted database field on an issue'   'gh api -X POST repos/o/r/issues -f "database=main"'
check no-pr-decisions.sh ALLOW 'a quoted rebase field on an issue'     'gh api -X POST repos/o/r/issues -f "rebase=main"'
# EVERY FLAG THE ANCHOR ADMITS, with the quote in it. rest_bases names three
# flags and the comment beside it now claims five spellings of one request, so
# each is asked here in both directions rather than left to the two that happen
# to be pinned. Two of the three flags reached no row at all before this. They
# pair as `gh api --help` gives them -- -F/--field is the TYPED parameter and
# -f/--raw-field the STRING one -- which this comment had backwards until
# Bertan's review of PR #153; the rows were right and the sentence was not.
# `-f"base=x"` closes the flag-attached case with a quote in it, which is the
# one the old pattern would have hidden twice over. The three dev-05 rows go red on revert; the
# three naming main are CONTRAST of the third kind, refused before for naming no
# base and after for naming main.
req FR-18 FR-15 US-11 GH-137.2
check no-pr-decisions.sh BLOCK 'attached flag, quoted field, main'     'gh api -X POST repos/o/r/pulls -f"base=main" -f head=x'
check no-pr-decisions.sh BLOCK '-F, quoted field, main'               'gh api -X POST repos/o/r/pulls -F "base=main" -f head=x'
check no-pr-decisions.sh BLOCK '--raw-field, quoted field, main'      'gh api -X POST repos/o/r/pulls --raw-field "base=main" -f head=x'
check no-pr-decisions.sh ALLOW 'attached flag, quoted field, dev'      'gh api -X POST repos/o/r/pulls -f"base=dev-05" -f head=x'
check no-pr-decisions.sh ALLOW '-F, quoted field, dev'                'gh api -X POST repos/o/r/pulls -F "base=dev-05" -f head=x'
check no-pr-decisions.sh ALLOW '--raw-field, quoted field, dev'       'gh api -X POST repos/o/r/pulls --raw-field "base=dev-05" -f head=x'
# And the anchor still holds for the two flags it had never been asked about.
req FR-20 US-14 GH-137.2
check no-pr-decisions.sh ALLOW '-F on a database field'               'gh api -X POST repos/o/r/issues -F "database=main"'
check no-pr-decisions.sh ALLOW '--raw-field on a rebase field'        'gh api -X POST repos/o/r/issues --raw-field "rebase=main"'
# The state reader is the contrast, and this row is what says so: the flag is
# irrelevant to it BY DESIGN, because it is not anchored on one. -F reaches the
# same refusal -f does, for the reason STATE_FIELD_RE's comment gives -- a rule
# that must also see a flagless `state:CLOSED` cannot be keyed on a flag. So it
# is CONTRAST and green on revert, and that is the point of it: a flag spelling
# that changes nothing for this reader is the evidence it is not flag-anchored.

# THE SEPARATOR, which the first fix for #137 did not ask about. Found by
# Bertan's review of PR #153, in the change that closed the quote gap -- the
# fourth wrong answer to where a field begins, and the second one found by
# review rather than by this suite. pflag takes `--field=value` for a long flag
# and `-f=value` for a short one, and the pattern required whitespace or a quote
# after the flag, so `--field=base=main` named a base nothing here could read.
#
# THE PERMITTING HALF, and it is the one that matters: on PATCH /pulls/N the
# no-base arm is keyed on the collection endpoint and does not fire, so an
# unread base is not a false refusal but a retarget onto main, permitted. That
# is the same consequence this section already records for the quote gap,
# surviving one spelling further along. All six rows below go red without the
# separator class -- the four flag spellings, and the two that reach it through
# a quote as well, the separator and the quote being independent.
req FR-18 FR-17 US-10 GH-137.2
check no-pr-decisions.sh BLOCK 'retarget to main, --field='        'gh api -X PATCH repos/o/r/pulls/35 --field=base=main'
check no-pr-decisions.sh BLOCK 'retarget to main, -f='             'gh api -X PATCH repos/o/r/pulls/35 -f=base=main'
check no-pr-decisions.sh BLOCK 'retarget to main, -F='             'gh api -X PATCH repos/o/r/pulls/35 -F=base=main'
check no-pr-decisions.sh BLOCK 'retarget to main, --raw-field='    'gh api -X PATCH repos/o/r/pulls/35 --raw-field=base=main'
# The separator and the quote are independent, so both orders are asked: a
# quoted field reached through `=` is the two gaps of this issue in one command.
check no-pr-decisions.sh BLOCK 'retarget to main, = then a quote'  'gh api -X PATCH repos/o/r/pulls/35 --field="base=main"'
check no-pr-decisions.sh BLOCK "retarget to main, = then a ' quote" "gh api -X PATCH repos/o/r/pulls/35 --field='base=main'"
# THE REFUSING HALF, which is how the gap showed on a create: the base was
# unread, so the create was refused for naming none. The permitted destination
# was the one refused, and `create into dev, --field=` is the row that says so
# -- it goes red the other way without the separator, want=ALLOW got=BLOCK. The
# two beside it are CONTRAST: `retarget to dev` was permitted before for seeing
# no base rather than a good one, and `create into main` refused before for
# naming none rather than for naming main. Right verdict, wrong reason, both.
req FR-18 FR-15 US-11 GH-137.2
check no-pr-decisions.sh ALLOW 'create into dev, --field='         'gh api -X POST repos/o/r/pulls --field=base=dev-05 -f head=x'
check no-pr-decisions.sh ALLOW 'retarget to dev, --field='         'gh api -X PATCH repos/o/r/pulls/35 --field=base=dev-05'
check no-pr-decisions.sh BLOCK 'create into main, --field='        'gh api -X POST repos/o/r/pulls --field=base=main -f head=x'
# And the anchor survives the widened separator, which is the whole question a
# separator class raises: `[[:space:]=]*` must not let the flag reach a word
# that merely ends in base. It does not -- after the separator the next
# character is still `d` or `r`, and still `t` for a title carrying a base.
req FR-20 US-14 GH-137.2
check no-pr-decisions.sh ALLOW '--field= on a database field'      'gh api -X POST repos/o/r/issues --field=database=main'
check no-pr-decisions.sh ALLOW '--field= on a rebase field'        'gh api -X POST repos/o/r/issues --field=rebase=main'
req FR-14 GH-137.2
check no-pr-decisions.sh BLOCK 'a title reached through =, no base' 'gh api -X POST repos/o/r/pulls -f head=x -f=title=base=dev-05'
# The state reader is unanchored, so the separator is nothing to it either. The
# contrast row for the separator, as the -F row above is for the flag.
req US-15 GH-137.1
check no-pr-decisions.sh BLOCK '--field= on a state field'         'gh api -X PATCH repos/o/r/pulls/5 --field=state=closed'
req US-15 GH-137.1
check no-pr-decisions.sh BLOCK '-F, quoted state field'               'gh api -X PATCH repos/o/r/pulls/5 -F "state=closed"'

section "=== REGRESSION: #139, a quoted base flag removed the refusal it should trigger ==="
# base_args drops every quoted span whole, and on the two arms where naming no
# base is permitted -- a retarget, and a create under --web -- the drop removed
# the one refusal a base of main would have met. The issue's table, every row of
# which went red before the fix: the quote round the flag's NAME is what hid it.
req FR-17 FR-15 US-10 GH-139
check no-pr-decisions.sh BLOCK 'retarget, flag double-quoted'       'gh pr edit 35 "--base" main'
check no-pr-decisions.sh BLOCK 'retarget, flag single-quoted'       "gh pr edit 35 '--base' main"
check no-pr-decisions.sh BLOCK 'retarget, flag=value quoted whole'  'gh pr edit 35 "--base=main"'
check no-pr-decisions.sh BLOCK 'retarget, shorthand quoted'         'gh pr edit 35 "-B" main'
req FR-21 FR-15 GH-139
check no-pr-decisions.sh BLOCK 'web create, flag double-quoted'     'gh pr create --web "--base" main'
check no-pr-decisions.sh BLOCK 'web create, flag=value quoted whole' 'gh pr create --web "--base=main"'
# Quoting that touches the flag name without standing round it, and a backslash,
# which bash removes as it removes a quote. Not in the issue's table; each was
# permitted on the retarget arm before the fix, for the same reason.
req FR-17 FR-15 US-10 GH-139
check no-pr-decisions.sh BLOCK 'retarget, quote inside the name'    'gh pr edit 35 --"base" main'
check no-pr-decisions.sh BLOCK 'retarget, quote before the ='       'gh pr edit 35 "--base"=main'
check no-pr-decisions.sh BLOCK 'retarget, name backslash-escaped'   'gh pr edit 35 \--base main'
check no-pr-decisions.sh BLOCK 'retarget, bundled shorthand quoted' 'gh pr edit 35 "-dB" main'
# bash's $'...' and $"..." quoting, which the first version of the fix counted
# the $ of as a character. Found by review of the fix; all three were permitted.
check no-pr-decisions.sh BLOCK "retarget, flag in \$'...'"          "gh pr edit 35 \$'--base' main"
check no-pr-decisions.sh BLOCK 'retarget, flag in $"..."'           'gh pr edit 35 $"--base" main'
check no-pr-decisions.sh BLOCK "web create, shorthand in \$'...'"   "gh pr create --web \$'-B' main"
# The escapes $'...' decodes, which the first version of that answer left as
# written and called a construction rather than a spelling. Bertan's review of
# PR #173: bash hands gh `--base main` for each of these, and each was permitted.
check no-pr-decisions.sh BLOCK "retarget, \\x escape in \$'...'"     "gh pr edit 35 \$'\\x2d-base' main"
check no-pr-decisions.sh BLOCK "retarget, octal escapes in \$'...'"  "gh pr edit 35 \$'\\055\\055base' main"
check no-pr-decisions.sh BLOCK "retarget, \\u escape in \$'...'"     "gh pr edit 35 \$'\\u002d-base' main"
check no-pr-decisions.sh BLOCK "web create, \\x escape shorthand"    "gh pr create --web \$'\\x2dB' main"
# A NUL the escapes produce, which the decoder turned into `?`. bash stops the
# $'...' span at a NUL and drops what is left of it up to the closing quote, so
# `$'--base\0' main` is `--base main`. Bertan's second review of PR #173; each of
# these was permitted. bash 5.2 was asked what each spelling becomes before the
# rows were written: `\c@` is a NUL, and `\^@` -- also named by that review -- is
# not an escape at all and stays four characters, which the ALLOW row below pins.
check no-pr-decisions.sh BLOCK "retarget, \\0 ends the \$'...' span"     "gh pr edit 35 \$'--base\\0' main"
check no-pr-decisions.sh BLOCK "retarget, \\x00 and text after it"      "gh pr edit 35 \$'--base\\x00junk' main"
check no-pr-decisions.sh BLOCK "retarget, \\c@ is a NUL"                "gh pr edit 35 \$'--base\\c@x' main"
check no-pr-decisions.sh BLOCK "retarget, NUL span then the rest"      "gh pr edit 35 \$'--ba\\0'se main"
check no-pr-decisions.sh BLOCK "web create, \\u0000 in the flag"        "gh pr create --web \$'--base\\u0000' main"
check no-pr-decisions.sh BLOCK "dev base, then a NUL-cut second base"  "gh pr create --base dev-05 --title x --body y \$'--base\\x00' main"
# A cut span still open at the end of the line. The newline is inside the span
# after the NUL, so bash drops it with the rest -- the argument is `--base`, not
# prose holding a newline. Found while answering that review, not by it.
check no-pr-decisions.sh BLOCK "a NUL-cut span open past the line end" $'gh pr edit 35 $\'--base\\0\n\' main'
# Bertan's third review of PR #173: four more holes, all from copying bash's
# decoding one escape at a time. `\c` took the character after it as its
# argument even when that was the closing quote or the first of a `\\` pair,
# which bash's parser pairs first -- so the span never closed where bash closes
# it, and everything after was misread. And a cut span open at the line end was
# judged on its first line, where bash closes it on the next and the word goes
# on. The answer is the conservative one that review suggested: every `\c` is
# taken as a possible NUL, since what it masks is a byte and bytes are not this
# decoder's business, and a cut span that runs past the line is refused.
check no-pr-decisions.sh BLOCK "\\c before the closing quote"          "gh pr edit 35 \$'x\\c' \$'--base' main"
check no-pr-decisions.sh BLOCK "web create, \\c before the quote"      "gh pr create --web \$'x\\c' \$'--base' main"
check no-pr-decisions.sh BLOCK "\\c before a backslash pair"           "gh pr edit 35 \$'x\\c\\\\' \$'--base' main"
check no-pr-decisions.sh BLOCK "dev base, \\c\\\\ then a quoted second" "gh pr create --base dev-05 --title x --body y \$'z\\c\\\\' '--base' main"
check no-pr-decisions.sh BLOCK "\\c on a byte that masks to NUL"       "gh pr edit 35 \$'--base\\cअ' main"
check no-pr-decisions.sh BLOCK "a cut span closing on the next line"  $'gh pr edit 35 $\'--ba\\0\n\'se main'
# THE TRADE, pinned: `\cA` is byte 0x01 and no NUL, so bash passes `--base` and
# a control character, which is no flag -- and it is refused, as every `\c`
# after a flag's name is. Nobody writes a branch or a title that way. A `\c` in
# a word that cannot be a flag is untouched.
check no-pr-decisions.sh BLOCK "\\cA after the flag name, refused"     "gh pr edit 35 \$'--base\\cA' main"
check no-pr-decisions.sh ALLOW "\\c in a word that is no flag"         "gh pr edit 35 --label \$'x\\cAy'"
# Bertan's fourth review of PR #173. An EMPTY span right after the flag's name
# was read as a quote round the value, which it cannot be -- it holds nothing --
# so `--base$'' main` passed, and base_args, which does not know `$`, read
# `--base$` as some other flag. What decides now is where the first span that
# yields a character opens, and separately where the first span that yields
# none does: an empty one at or just past the name's end refuses.
check no-pr-decisions.sh BLOCK "an empty \$'' after the name"          "gh pr edit 5 --base\$'' main"
check no-pr-decisions.sh BLOCK 'an empty $"" after the name'          'gh pr edit 5 --base$"" main'
check no-pr-decisions.sh BLOCK "web create, an empty \$'' after it"    "gh pr create --web --base\$'' main"
check no-pr-decisions.sh BLOCK "an empty \$'' before the ="            "gh pr edit 5 --base\$''=main"
check no-pr-decisions.sh BLOCK "an empty \$'' inside the shorthand"    "gh pr edit 5 -B\$''main"
check no-pr-decisions.sh BLOCK "a span cut to nothing after the name" "gh pr edit 5 --base\$'\\0' main"
# Refused before this fix too, but by base_args' first sed and not by the rule
# written for it -- the review called it luck. Pinned here so that it is not.
check no-pr-decisions.sh BLOCK 'an empty "" after the name'           'gh pr edit 5 --base"" main'
# Bertan's fifth review of PR #173. A span that yields a character just past
# the name was taken as round the value, which assumed base_args could read the
# value there -- and it can for `"="` and `'='`, but not for `$'='`, `$"="` or
# `\=`, so `--base$'=main'` named no base at all. A quoted or escaped `=` is now
# part of the name, and each of these, permitted before, is refused.
check no-pr-decisions.sh BLOCK "an = in \$'...' after the name"         "gh pr edit 5 --base\$'=main'"
check no-pr-decisions.sh BLOCK "an = alone in \$'...'"                   "gh pr edit 5 --base\$'='main"
check no-pr-decisions.sh BLOCK 'an = alone in $"..."'                   'gh pr edit 5 --base$"="main'
check no-pr-decisions.sh BLOCK 'an = and part of the value in $"..."'   'gh pr edit 5 --base$"=m"ain'
check no-pr-decisions.sh BLOCK "an = as \\x3d"                          "gh pr edit 5 --base\$'\\x3d'main"
check no-pr-decisions.sh BLOCK "an = as \\075"                          "gh pr edit 5 --base\$'\\075'main"
check no-pr-decisions.sh BLOCK 'a backslash-escaped ='                  'gh pr edit 5 --base\=main'
check no-pr-decisions.sh BLOCK "web create, an = in \$'...'"            "gh pr create --web --base\$'=main'"
check no-pr-decisions.sh BLOCK "dev base, then an = in \$'...'"         "gh pr create --base dev-05 --title x --body y --base\$'=main'"
# THE TRADE, and it moves a row: `--base"=dev-05"` was pinned ALLOW here as a
# quoted value holding the =. Its = is quoted too, so it is refused with the
# rest -- a spelling nobody writes for a base that could be written plainly.
# The = OUTSIDE the quote is still a quoted value, `--base="dev-05"`, above.
check no-pr-decisions.sh BLOCK 'a quoted = before a dev value'          'gh pr edit 5 --base"=dev-05"'
# The line-end rule refused every cut span open at a line's end, and a body is
# the ordinary thing to write across lines. A word the next line can only
# extend can become a flag only if it is empty or begins with a dash and holds
# no whitespace yet, so only that is refused. Red before the fix.
check no-pr-decisions.sh ALLOW "a multi-line \$'...' body with a \\c"   $'gh pr edit 5 --body $\'Adds C:\\cache support\nsecond line\''
check no-pr-decisions.sh BLOCK "a span cut to nothing, open at the end" $'gh pr edit 5 $\'\\c\n\'--base main'
# Only the SPAN is cut, not the argument: text after the closing quote joins on,
# so `$'--base\0'x` is `--basex`, which is no flag. The review proposed ending
# the word at the NUL, which would refuse this; bash does not end it there.
check no-pr-decisions.sh ALLOW "a NUL span, then more of the word"     "gh pr edit 35 --label \$'--base\\0'x"
check no-pr-decisions.sh ALLOW "\\^@ is not an escape in bash"          "gh pr edit 35 --label \$'--base\\^@x'"
# THE CREATE ARM, which the issue called safe and is not wholly. A create naming
# no base is refused, so a quoted flag standing alone was refused for naming
# none -- but beside an unquoted dev base it is a SECOND base, the unquoted one
# satisfied the rule, and gh takes the last. Found while writing this fix.
req FR-15 FR-16 GH-139
check no-pr-decisions.sh BLOCK 'dev base, then a quoted main'       'gh pr create --base dev-05 "--base" main --title x'
check no-pr-decisions.sh BLOCK 'dev base, then a quoted shorthand'  'gh pr create --base dev-05 --title x "-B" main'
# The refusal names what it refused, and not the missing base it used to report
# for a quoted flag standing alone on a create.
req US-7 FR-23 GH-139
says "$ON_DEV" no-pr-decisions.sh 'a quote or a backslash in its name' \
  'a quoted base flag says it was quoted' \
  'gh pr edit 35 "--base" main'
says_not "$ON_DEV" no-pr-decisions.sh 'No base is named here' \
  'and a quoted flag on a create is not reported as no base' \
  'gh pr create "--base" dev-05 --title x'
# THE CONTROLS the issue names, and the prose the quote-drop exists for. A quote
# round a VALUE is still read -- base_args' own unquoting, which this fix does
# not touch -- and a quoted word holding whitespace is one argument that no
# branch can be named, git refusing a space in a ref, so a title or body that
# begins with the flag is prose and stays permitted. CONTRAST rows: every one is
# green with the fix reverted, and says the fix did not widen past the name.
req FR-17 FR-15 US-10 US-13 GH-139
check no-pr-decisions.sh ALLOW 'retarget to dev, unquoted'          'gh pr edit 35 --base dev-05'
check no-pr-decisions.sh ALLOW 'an edit naming no base'             'gh pr edit 35 --add-label bug'
check no-pr-decisions.sh ALLOW 'retarget to dev, value quoted'      'gh pr edit 35 --base "dev-05"'
check no-pr-decisions.sh ALLOW 'retarget to dev, = then a quote'    'gh pr edit 35 --base="dev-05"'
check no-pr-decisions.sh ALLOW 'retarget to dev, -B then a quote'   'gh pr edit 35 -B"dev-05"'
check no-pr-decisions.sh ALLOW 'an edit titled -B and a branch'     'gh pr edit 35 --title "-B main"'
check no-pr-decisions.sh ALLOW 'an edit whose body opens --base'    'gh pr edit 35 --body "--base dev-05 is the base"'
# The same prose split by a newline instead of a space. The hook reads one line
# of a command at a time, so the quote is still open where the line ends -- and
# the argument bash builds holds that newline, so it is prose as the space made
# it. Refused by the first version of the fix. Bertan's review of PR #173.
check no-pr-decisions.sh ALLOW 'an edit whose body opens --base, then a newline' $'gh pr edit 35 --base dev-05 --body "--base\nmore text"'
# And a decoded \n inside $'...' is whitespace in the argument too. Green before
# the escape decoding above existed, when `\n` was two characters; it is here so
# that decoding one spelling of prose into a flag would go red.
check no-pr-decisions.sh ALLOW "a \$'...' body opening --base, then \\n" "gh pr edit 35 --body \$'--base\\nmore text'"
req FR-21 US-12 GH-139
check no-pr-decisions.sh ALLOW 'the web form, no base'              'gh pr create --web'
req FR-14 FR-15 GH-139
check no-pr-decisions.sh ALLOW 'a body naming the flag, dev base'   'gh pr create --base dev-05 --title t --body "the --base flag"'

section "=== the push argument split does not glob against the worktree ==="
# `for TOK in $ARGS` is unquoted because the split is the point; set -f stops
# the same line expanding ? and [...] against the files sitting next to it.
req US-3
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a ? wildcard refspec'     'git push origin ?'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a [...] wildcard refspec' 'git push origin [a-z]*'

section "=== worktree exception: pushing this worktree's own branch ==="
# Every permitted push names the branch. That is the whole exception: a push
# that does not name it is answered by configuration instead, and configuration
# is not a thing this hook can hold still. See the bare-push section below.
req US-3 US-4
check_in "$PUSH_WT" no-git-push.sh ALLOW 'push naming this branch'          "git push origin $PUSH_BRANCH"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'push after a commit'              "git commit -m msg && git push origin $PUSH_BRANCH"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'push in a subshell'               "(git push origin $PUSH_BRANCH)"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'push with a trailing ;'           "git push origin $PUSH_BRANCH;"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'git push -u origin <this branch>' "git push -u origin $PUSH_BRANCH"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'indented push, own branch'        $'if true; then\n    git push origin '"$PUSH_BRANCH"$'\nfi'
# An unrelated -f elsewhere on the line is not the push's own flag. Every option
# check reads the push's arguments, not the whole command, so this still passes.
check_in "$PUSH_WT" no-git-push.sh ALLOW 'rm -f before an ordinary push'    "rm -f notes.md && git push origin $PUSH_BRANCH"

section "=== REGRESSION: issue #50, a redirect was read as a refspec ==="
# Nothing removed redirections, so `2>/dev/null` was the refspec and the message
# said so in as many words. A stderr redirect is a shape an agent writes without
# meaning anything by it -- `2>&1 | tail -3` on a push is how you read the result
# of one -- so by the stopping rule in no-git-push.sh that is a defect.
#
# PR #48 reported the `2>&1` spelling and blamed the split on &. That is true of
# that spelling and was not the cause: `2>/dev/null` holds no & and was refused
# just the same. cs_normalise drops the redirection now, before cs_split sees it.
req GH-50.1 US-4
check_in "$PUSH_WT" no-git-push.sh ALLOW 'push with 2>/dev/null'     "git push origin $PUSH_BRANCH 2>/dev/null"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'push with > out.txt'       "git push origin $PUSH_BRANCH > out.txt"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'push with 2>> push.log'    "git push origin $PUSH_BRANCH 2>> push.log"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'push with >/dev/null 2>&1' "git push origin $PUSH_BRANCH >/dev/null 2>&1"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'push with 2>&1 | tail -3'  "git push origin $PUSH_BRANCH 2>&1 | tail -3"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'push with &> out.txt'      "git push origin $PUSH_BRANCH &> out.txt"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'push with >& out.txt'      "git push origin $PUSH_BRANCH >& out.txt"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'push with a redirect first' "git push origin >out.txt $PUSH_BRANCH"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'push with >| out.txt'      "git push origin $PUSH_BRANCH >| out.txt"
# The redirect changes what the hook can see, never what it decides. Every
# refused destination is still refused wearing one, and so is every refused
# form -- the drop must not carry the flag off with the redirect.
req GH-50.1 US-3
check_in "$PUSH_WT" no-git-push.sh BLOCK 'push to main with 2>/dev/null'    'git push origin main 2>/dev/null'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'push to dev-05 with > out.txt'    'git push origin dev-05 > out.txt'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'push to main with 2>> push.log'   'git push origin main 2>> push.log'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'push to dev-05, >/dev/null 2>&1'  'git push origin dev-05 >/dev/null 2>&1'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'push to main with 2>&1 | tail'    'git push origin main 2>&1 | tail -3'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'push --all with a redirect'       'git push --all origin >/dev/null 2>&1'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'push --mirror with a redirect'    'git push --mirror origin 2>&1'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'forced push of own branch, redirected' "git push -f origin $PUSH_BRANCH 2>/dev/null"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'bare push with a redirect'        'git push 2>/dev/null'
# A pipe is not a redirect and still ends the command, so what follows one is
# still a command. Dropping must never hide it.
req GH-50.2 US-3
check_in "$PUSH_WT" no-git-push.sh BLOCK 'legit push 2>&1 then push --all'  "git push origin $PUSH_BRANCH 2>&1 | tail -3; git push --all origin"
req GH-50.1 US-15
check no-pr-decisions.sh BLOCK 'gh pr merge with a redirect'  'gh pr merge 35 >/dev/null 2>&1'
check no-pr-decisions.sh BLOCK 'gh pr review -a, redirected'  'gh pr review -a 35 2>&1 | tail -1'
req GH-50.1 US-13
check no-pr-decisions.sh ALLOW 'gh pr view with a redirect'   'gh pr view 35 > /tmp/pr.json'

section "=== ACCEPTED false positive: a quoted redirect target ==="
# The target scan stops at a quote, so a quoted target is not consumed and its
# text stays in the push's arguments, where it reads as a refspec. Issue #50
# asked for every redirect on a permitted push to be allowed and granted no
# exception, so this is a shortfall against it rather than a decision the issue
# made -- taken because consuming a quoted target would mean the drop swallowing
# text it cannot see the end of, which is the direction that has gone wrong
# four times in this file. The targets an agent writes -- /dev/null, out.txt,
# push.log -- carry no quotes.
#
# Pinned in both directions so a later change cannot move it silently. If these
# become ALLOW, that is a decision to take knowingly, not a bug fix.
req GH-50.3
tok 'a quoted target is left in the arguments' \
    'git push origin b "push log"' \
    "$(printf 'git push origin b 2> "push log"\n' | cs_normalise)"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'push with a quoted redirect target' "git push origin $PUSH_BRANCH 2> \"push log\""
check_in "$PUSH_WT" no-git-push.sh ALLOW 'the same target unquoted' "git push origin $PUSH_BRANCH 2> push.log"

section "=== REGRESSION: issue #50, the drop must not hide a command ==="
# Dropping is the one step in cs_normalise that hides text rather than exposing
# it, and the heredoc question was got wrong four times in exactly that
# direction. A process substitution carries a command, so it is not a redirect;
# a command substitution used as a target is not a target. Both are pinned here
# with a refused command inside, so hiding one would show up as ALLOW.
req GH-50.2
check_in "$PUSH_WT" no-git-push.sh BLOCK 'push inside <( )'             'cat <(git push --all origin)'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'push inside >( )'             'tee >(git push --all origin)'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'push as a backticked target'  'echo > `git push --all origin`'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'push as a $( ) target'        'echo > $(git push --all origin)'
check no-pr-decisions.sh BLOCK 'merge inside <( )'            'cat <(gh pr merge 35)'
check no-pr-decisions.sh BLOCK 'merge as a $( ) target'       'echo > $(gh pr merge 35)'

section "=== REGRESSION: PR #35 review, a bare push is answered by configuration ==="
# A push naming no refspec is sent where push.default, a remote.<name>.push
# refspec, or the branch's upstream says -- and -c sets any of those for one
# command, past whatever this hook reads back afterwards. The old check read
# push.default alone, so `git -c push.default=matching push` was ALLOW: it would
# have carried every branch whose name exists on both sides, dev-05 included.
#
# The trade, taken knowingly: `git push` and `git push origin` were permitted
# and are refused now. The destination has to be in the command, which is what
# CLAUDE.md already asked for -- a push "positively naming that branch".
req US-3
check_in "$PUSH_WT" no-git-push.sh BLOCK 'bare git push'                     'git push'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'push naming only the remote'       'git push origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'bare push after a commit'          'git commit -m msg && git push'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'bare push in a subshell'           '(git push)'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'push.default set for this command' 'git -c push.default=matching push'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'push.default=upstream for one'     'git -c push.default=upstream push origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'config set by --config-env'        'git --config-env=push.default=PD push'
# -c is refused even alongside a refspec that does name this branch: the hook
# cannot know which setting the override was for.
check_in "$PUSH_WT" no-git-push.sh BLOCK '-c with an explicit refspec'       "git -c http.sslVerify=false push origin $PUSH_BRANCH"

section "=== forced pushes, refused in every spelling ==="
# Forcing rewrites what the remote already has, which for this branch is the
# history an open pull request is showing. --force-with-lease is refused with
# the rest: it guards against clobbering another person's work, not against
# rewriting a PR under its reviewer.
req US-3
check_in "$PUSH_WT" no-git-push.sh BLOCK 'git push -f'                   'git push -f'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'git push --force'              'git push --force'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'git push --force-with-lease'   'git push --force-with-lease'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'lease with a value'            "git push --force-with-lease=$PUSH_BRANCH origin"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'git push --force-if-includes'  'git push --force-if-includes origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'bundled short flags -fu'       "git push -fu origin $PUSH_BRANCH"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'forced by leading + on refspec' "git push origin +$PUSH_BRANCH"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'forced push of own branch'     "git push -f origin $PUSH_BRANCH"

section "=== worktree exception does not extend to ==="
req US-3 US-1
check_in "$PUSH_WT" no-git-push.sh BLOCK 'another branch by name: main'      'git push origin main'
req US-3 US-2
check_in "$PUSH_WT" no-git-push.sh BLOCK 'another branch by name: dev-05'    'git push origin dev-05'
req US-3 US-1
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a refspec destination: HEAD:main'  'git push origin HEAD:main'
req US-3 US-2
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a forced push to dev-05'           'git push -f origin dev-05'
req US-3
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a cd before the push'              'cd /tmp && git push'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a cd before the push, with ;'      'cd /tmp; git push'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'git redirected with -C'            'git -C /home/bgunyel/source/ai/clause-and-effect push'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'git redirected with --git-dir'     'git --git-dir=/elsewhere/.git push'
req US-3 FR-4
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a push inside sh -c'               'sh -c "git push"'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a push inside bash -c'             'bash -c "git push origin dev-05"'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a push inside eval'                'eval "git push"'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a push inside a heredoc fed to sh' $'bash <<\'EOF\'\ngit push\nEOF'

section "=== ACCEPTED false positive: the wrapper rule reaches across the line here too ==="
# This hook's wrapper rule is the same two-grep shape as no-pr-decisions.sh's --
# a wrapper in a command position, a push anywhere on the line -- and neither
# grep asks whether the two are the same command. So an otherwise correct push
# is refused for a wrapper that has nothing to do with it, in either order.
# Only the second grep is the loose one: the wrapper half is anchored, and a
# wrapper merely named in passing is pinned below as ALLOW.
#
# Run from a linked worktree the third line is ALLOW, and that is the arming
# evidence for the first two rather than an assertion about them: the same push
# with the wrapper taken off the line is permitted, so the wrapper is the only
# thing that differs and it is the wrapper answering rather than the worktree
# exception. A rule that stopped reaching across the line would land all three
# on ALLOW. These used to run wherever the suite was started, and from the main
# checkout all three were BLOCK and the pair showed nothing; since #94 they run
# in the fixture worktree, so the discrimination is made on every run.
req GH-73 FR-4
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a wrapper elsewhere, then a legit push' \
  "bash -c \"make test\" && git push origin $PUSH_BRANCH"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a legit push, then a wrapper elsewhere' \
  "git push origin $PUSH_BRANCH && bash -c \"make test\""
check_in "$PUSH_WT" no-git-push.sh ALLOW 'the same push with no wrapper' \
  "make test && git push origin $PUSH_BRANCH"
# And what keeps the two halves different, which CLAUDE.md now claims: the
# second grep here asks for a push, where no-pr-decisions.sh asks for every
# surface that decides a pull request or a release. So an ordinary read beside a
# wrapper is untouched on this side and refused on that one. These two are the
# measurement behind that sentence; if they ever go BLOCK, the sentence is wrong.
check_in "$PUSH_WT" no-git-push.sh ALLOW 'a wrapper elsewhere, then git status' 'bash -c "make test" && git status'
check_in "$PUSH_WT" no-git-push.sh ALLOW 'a wrapper elsewhere, then git log'    'bash -c "make test" && git log --oneline'
# The wrapper half is anchored at a command position in both hooks, so a wrapper
# only spoken about is not one. Without this the sentence above could be read as
# a bare substring match, which is what "anywhere" would mean if it covered both
# greps rather than the second alone.
check_in "$PUSH_WT" no-git-push.sh ALLOW 'a wrapper named in passing, then a push' \
  "echo \"use bash -c\" && git push origin $PUSH_BRANCH"

section "=== REGRESSION: PR #35, a denylist could not see a push naming no branch ==="
# The check refused branches by name, so any spelling that named none was
# invisible: --all advanced main and dev-05 from any worktree, and --mirror
# deleted every remote branch absent locally, closing open pull requests. The
# check is now an allowlist -- the push must positively name this branch.
req US-3
check_in "$PUSH_WT" no-git-push.sh BLOCK 'git push --all origin'      'git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'git push --mirror origin'   'git push --mirror origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'git push --prune origin'    'git push --prune origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'git push origin --tags'     'git push origin --tags'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'git push --follow-tags'     'git push --follow-tags origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'wildcard refspec, forced'   'git push origin +refs/heads/*:refs/heads/*'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'deleting a remote branch'   "git push origin --delete $PUSH_BRANCH"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'deleting by empty source'   'git push origin :main'

section "=== REGRESSION: PR #35, redirects and cd forms the rules did not reach ==="
# An environment assignment precedes the command, so git was not at a command
# position and the push was never even detected; the anchors now allow a VAR=
# prefix. pushd changes directory exactly as cd does.
req US-3 FR-3
check_in "$PUSH_WT" no-git-push.sh BLOCK 'GIT_DIR= prefix'     'GIT_DIR=/other/.git git push origin main'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'GIT_WORK_TREE= prefix' 'GIT_WORK_TREE=/other git push'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'pushd before a push'  'pushd /some/repo && git push'
req FR-3 US-15
check no-pr-decisions.sh BLOCK 'env prefix before gh' 'FOO=1 gh pr merge 35'

section "=== the allowlist still admits an ordinary push of this branch ==="
req US-3 US-4
check_in "$PUSH_WT" no-git-push.sh ALLOW 'git push origin HEAD'           "git push origin HEAD"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'git push origin HEAD:<branch>'  "git push origin HEAD:$PUSH_BRANCH"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'git push origin <b>:<b>'        "git push origin $PUSH_BRANCH:$PUSH_BRANCH"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'push option with a value'       "git push -o ci.skip origin $PUSH_BRANCH"

section "=== REGRESSION: PR #35, a line continuation emptied the argument scope ==="
# The scope ran from push to the next shell separator; a newline ended it, and
# an empty scope fell through to the bare-push case, the permitted one. So one
# wrapped line turned any push into an ordinary one -- --mirror included, which
# deletes remote branches and closes open PRs. Continuations are now joined
# before anything is matched.
req FR-3 US-3
check_in "$PUSH_WT" no-git-push.sh BLOCK 'continued --mirror'  $'git push \\\n  --mirror origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'continued --all'     $'git push \\\n  --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'continued force'     $'git push \\\n  --force-with-lease origin main'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'continued origin main' $'git push \\\n  origin main'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'continuation over three lines' $'git push \\\n  --all \\\n  origin'
# A trailing backslash with nothing after it is not a continuation of anything.
# The command is a bare push, which used to be the permitted shape and is now
# refused for naming no destination -- the join still has to consume the
# backslash, or this would be refused for being unreadable instead.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'trailing backslash, nothing after' $'git push \\'
req FR-3 US-4
check_in "$PUSH_WT" no-git-push.sh ALLOW 'continued push of this branch'     $'git push \\\n  origin '"$PUSH_BRANCH"

section "=== the remote must be a remote of this repository ==="
# Nothing required the first bare token to be a remote, so a URL or a typo was
# admitted whenever the refspec named this branch. Raised on PR #35.
req US-3
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a foreign remote URL'    'git push git@github.com:someone/else.git HEAD'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'an undefined remote name' 'git push upstream HEAD'
check_in "$PUSH_WT" no-git-push.sh ALLOW 'origin is a real remote' "git push origin $PUSH_BRANCH"

section "=== no-git-push.sh : not a push at all ==="
req US-3
for c in 'git status' \
         'git commit -m "explain how to git push later"' \
         'echo "run git push when ready" >> notes.md' \
         'git log --oneline' \
         'git fetch origin' \
         'gh pr create --fill' \
         'grep -rn "git push" src/' \
         'git pull --rebase' \
         'make test'
do check_in "$PUSH_WT" no-git-push.sh ALLOW "$c" "$c"; done

section "=== REGRESSION: issue #94, a subdirectory of the main checkout read as a linked worktree ==="
# no-git-push.sh tells the main checkout from a linked worktree by comparing
# `git rev-parse --git-dir` with `--git-common-dir`, and compared them as
# strings. At the root of a checkout git 2.43 prints both relatively, `.git` and
# `.git`. Below the root it prints --git-dir absolute and --git-common-dir
# relative, `/.../r/.git` against `../.git`, so the two never compare equal and
# the main checkout read as a linked worktree: a push of the checked-out branch
# was refused at the root and permitted from `src/` and from `src/deep/`.
# Silent, and in the permitting direction.
#
# Nothing here could see it. The push checks ran from .claude/hooks, which is
# below the root and so was already a place the defect showed -- but in the
# main checkout this suite normally runs from, the branch is dev-NN or main,
# and every push of it was refused by the reserved-branch rule whether or not
# the main checkout was recognised. So each location is asked both ways, and
# the fixture's main checkout sits on feature-x, where the main-checkout
# refusal is the only one standing.
#
# Whether this git still prints the two differently is a fact about git rather
# than about the hook, so it is reported rather than asserted: if a later git
# prints them equal, these checks still pin the verdicts, but no longer
# reproduce the defect they were written against.
if [ "$(cd "$PUSH_MAIN/src/deep" && git rev-parse --git-dir)" = \
     "$(cd "$PUSH_MAIN/src/deep" && git rev-parse --git-common-dir)" ]; then
  echo "  note this git prints --git-dir and --git-common-dir identically below the root, so the #94 checks do not reproduce the string mismatch"
fi
echo "--- the main checkout, at its root and below it ---"
req GH-94.1 US-3 US-25
check_in "$PUSH_MAIN"          no-git-push.sh BLOCK 'main checkout, root: a push of its own branch' \
  'git push origin feature-x'
check_in "$PUSH_MAIN/src"      no-git-push.sh BLOCK 'main checkout, src/: a push of its own branch' \
  'git push origin feature-x'
check_in "$PUSH_MAIN/src/deep" no-git-push.sh BLOCK 'main checkout, src/deep/: a push of its own branch' \
  'git push origin feature-x'
# Which refusal, and not merely that one fired: below the root the command is
# otherwise a plain push naming the checked-out branch, so a message from any
# other rule would mean the main checkout was still not recognised.
req GH-94.1
says "$PUSH_MAIN/src/deep" no-git-push.sh 'This is the main checkout, not a linked worktree' \
  'main checkout, src/deep/: refused as the main checkout' 'git push origin feature-x'
# The permitting half at the same three depths. What the directory decides is
# whether a push is permitted, not whether git may be used at all.
req GH-94.1 US-25
check_in "$PUSH_MAIN"          no-git-push.sh ALLOW 'main checkout, root: a fetch is not a push' \
  'git fetch origin'
check_in "$PUSH_MAIN/src"      no-git-push.sh ALLOW 'main checkout, src/: a fetch is not a push' \
  'git fetch origin'
check_in "$PUSH_MAIN/src/deep" no-git-push.sh ALLOW 'main checkout, src/deep/: a fetch is not a push' \
  'git fetch origin'
echo "--- the linked worktree, at its root and below it ---"
# A fix that canonicalised the main checkout into equality and the worktree
# with it would refuse every push an agent is allowed; these are what say it
# did not.
req GH-94.1 US-4 US-25
check_in "$PUSH_WT"            no-git-push.sh ALLOW 'linked worktree, root: a push naming its own branch' \
  "git push origin $PUSH_BRANCH"
check_in "$PUSH_WT/src"        no-git-push.sh ALLOW 'linked worktree, src/: a push naming its own branch' \
  "git push origin $PUSH_BRANCH"
check_in "$PUSH_WT/src/deep"   no-git-push.sh ALLOW 'linked worktree, src/deep/: a push naming its own branch' \
  "git push origin $PUSH_BRANCH"
req GH-94.1 US-1
check_in "$PUSH_WT"            no-git-push.sh BLOCK 'linked worktree, root: a push of main' \
  'git push origin main'
check_in "$PUSH_WT/src"        no-git-push.sh BLOCK 'linked worktree, src/: a push of main' \
  'git push origin main'
check_in "$PUSH_WT/src/deep"   no-git-push.sh BLOCK 'linked worktree, src/deep/: a push of main' \
  'git push origin main'
req GH-94.1 US-2
check_in "$PUSH_WT"            no-git-push.sh BLOCK 'linked worktree, root: a push of a dev branch' \
  'git push origin dev-99'
check_in "$PUSH_WT/src"        no-git-push.sh BLOCK 'linked worktree, src/: a push of a dev branch' \
  'git push origin dev-99'
check_in "$PUSH_WT/src/deep"   no-git-push.sh BLOCK 'linked worktree, src/deep/: a push of a dev branch' \
  'git push origin dev-99'
echo "--- a linked worktree standing on a branch that is Bertan's ---"
# The command names nothing this worktree does not own: a bare push, and then the
# branch by its own name. Every other refusal here would permit both, so a
# refusal can only be the test of $CURRENT, and `says` pins which one spoke.
req GH-94.1 US-2
check_in "$PUSH_WT_DEV"  no-git-push.sh BLOCK 'a worktree on a dev branch: a bare push' \
  'git push'
check_in "$PUSH_WT_DEV"  no-git-push.sh BLOCK 'a worktree on a dev branch: a push naming its own branch' \
  'git push origin dev-05'
says "$PUSH_WT_DEV" no-git-push.sh 'This worktree is on dev-05, which is Bertan' \
  'and refused for standing on it, not for naming something else' 'git push'
req GH-94.1 US-1
check_in "$PUSH_WT_MAIN" no-git-push.sh BLOCK 'a worktree on main: a bare push' \
  'git push'
check_in "$PUSH_WT_MAIN" no-git-push.sh BLOCK 'a worktree on main: a push naming its own branch' \
  'git push origin main'
says "$PUSH_WT_MAIN" no-git-push.sh 'This worktree is on main, which is Bertan' \
  'and refused for standing on it, not for naming something else' 'git push'
echo "--- both, reached through a symlink ---"
# Resolving each path by the directory it names, and not by the spelling $PWD
# gives it, is half of the fix; these are what fail if the -P on pwd is dropped.
req GH-94.1 US-3 US-25
check_in "$PUSH_MAIN_LINK/src/deep" no-git-push.sh BLOCK 'main checkout through a symlink, src/deep/: a push of its own branch' \
  'git push origin feature-x'
req GH-94.1 US-4 US-25
check_in "$PUSH_WT_LINK/src/deep"   no-git-push.sh ALLOW 'linked worktree through a symlink, src/deep/: a push naming its own branch' \
  "git push origin $PUSH_BRANCH"

section "=== issue #105: a refusal names the permitted spelling ==="
# US-7 and FR-23. Every refusal in these two files was read for its verdict, and
# only the release rule's was read for its words, by #97's `says` block above.
# So the base rule's message and the bare push's could each have been emptied to
# "Blocked." and this suite would have stayed green: the verdict is what it asked
# about, and the verdict would not have moved.
#
# Two claims per message, and they fail apart. The SPELLING is the constant half
# and is what the story asks for -- `gh pr create --base dev-NN`, and
# `git push <remote> <branch>`. The TAIL is what separates one refusal from the
# three beside it, so a change routing every base refusal through one sentence
# leaves the spelling checks green and turns the tails red. That is the shape
# no-commit-to-main.sh's three messages are already pinned against, and for the
# same reason: nothing else here can tell one refusal from another.
#
# The four base spellings are asked separately because #40's finding was a rule
# that held for `gh pr create` and not for `gh api`. A message that held for one
# spelling and not the others is that defect arriving as prose.
#
# The retarget's constant-half row is tagged FR-23 and not US-7, and #133 is why.
# One constant for four refusals is what FR-23 asks for, and for three of the
# four it is also the one-step correction US-7 asks for. For a retarget it is
# not: `gh pr edit 5 --base dev-05` is permitted, so the correction is one word
# of the command already written, and a create -- acted on -- leaves the
# mis-targeted pull request open and opens a second beside it. The same fact is
# evidence for one requirement and against the other, so this row says only the
# half that holds, and it stays, because FR-23's claim is true and is the claim
# that would go if the constant were split per arm.
#
# US-7's half is carried by the retarget's own tail, below, which #133 added and
# which names `gh pr edit <n> --base dev-NN`. Before that the story went
# uncovered here and requirements.md carried GH-133 as a gap: pinning US-7 on the
# constant would have made this suite evidence that the message answers a story
# it does not answer, which is what #103's Q18 forbids and what #130 and #131
# were filed rather than pinned for.
req US-7 FR-23
says "$ON_DEV" no-pr-decisions.sh 'Write: gh pr create --base dev-NN' \
  'gh pr create with no base names the permitted spelling' \
  'gh pr create --title x --body y'
says "$ON_DEV" no-pr-decisions.sh 'Write: gh pr create --base dev-NN' \
  'gh pr create into main names the permitted spelling' \
  'gh pr create --base main --title x'
req FR-23
says "$ON_DEV" no-pr-decisions.sh 'Write: gh pr create --base dev-NN' \
  'a retarget to main names the permitted spelling' \
  'gh pr edit 5 --base main'
req US-7 FR-23
says "$ON_DEV" no-pr-decisions.sh 'Write: gh pr create --base dev-NN' \
  'the REST spelling names the permitted spelling' \
  'gh api -X POST repos/o/r/pulls -f base=main'
says "$ON_DEV" no-pr-decisions.sh 'Write: gh pr create --base dev-NN' \
  'the graphql spelling names the permitted spelling' \
  'gh api graphql -f query="mutation{createPullRequest(input:{baseRefName:\"main\"})}"'
# And the tails: which of the four refusals fired, and what it says is wrong. A
# create that named no base and one that named main are the two halves of #40,
# and a message that cannot tell them apart tells an agent to name a base it has
# already named.
says "$ON_DEV" no-pr-decisions.sh 'No base is named here' \
  'a create with no base says the base is missing' \
  'gh pr create --title x --body y'
says "$ON_DEV" no-pr-decisions.sh 'This names main, which is not a dev-NN branch' \
  'a create into main says which branch it named' \
  'gh pr create --base main --title x'
# The retarget's tail, in two rows because it makes two claims that fail apart.
# The first says which branch was named and that naming it is the choice the rule
# refuses -- the half that tells this refusal from the three beside it.
#
# THE FRAGMENT IS THE WHOLE SENTENCE, and the first version of this row stopped at
# `chooses that destination`. `just as creating it there would` is the clause that
# ties a retarget to a create, which is the entire reason an edit is refused at
# all -- and a prefix fragment still matches once it is deleted, so that clause
# could have gone with this suite green. Bertan's review of this pull request.
# `retarget-refusal-drops-the-create-comparison` in the registry deletes exactly
# that clause, so the question of whether this row can fail is re-runnable rather
# than argued.
req FR-23
says "$ON_DEV" no-pr-decisions.sh 'Retargeting to main chooses that destination just as creating it there would' \
  'a retarget says which branch it named, and that naming it is the same choice' \
  'gh pr edit 5 --base main'
# The second is #133's fix, and the one row in this section that reads US-7 for a
# retarget. The correction for `gh pr edit 5 --base main` is `gh pr edit 5 --base
# dev-05`: one word of the command already written, and permitted -- pinned as
# such by the ALLOW row on `gh pr edit 35 --base dev-05` above. Until #133 this
# tail said "Edit anything else you like", which, read against a refusal whose
# subject is the base, says the base is the one thing that may not be edited,
# when editing it to dev-NN is what is allowed. The fragment is the whole
# spelling and not the word `retarget`: a message naming the act without naming
# what to write is the guessing US-7 exists to end.
req US-7 FR-23 GH-133
says "$ON_DEV" no-pr-decisions.sh 'Retarget to the active dev branch instead: gh pr edit <n> --base dev-NN' \
  'a retarget names the retarget that would correct it' \
  'gh pr edit 5 --base main'
# And the phrase it replaced is gone rather than joined, because the two read
# against each other: one sentence naming the permitted base beside another
# saying the base may not be edited is US-7's guessing with a step added. Two
# rows and a says_not are every clause of this tail, which is the property the
# first draft of #133 did not have -- it ended in a third sentence, "No other
# edit is checked here", that no row named and that could have been deleted with
# this suite green. Found by review, not by the suite.
says_not "$ON_DEV" no-pr-decisions.sh 'Edit anything else you like' \
  'and does not also say the base is the one thing not to edit' \
  'gh pr edit 5 --base main'
req US-7 FR-23
says "$ON_DEV" no-pr-decisions.sh 'the same destination under another spelling' \
  'the REST spelling says it is the same destination named differently' \
  'gh api -X POST repos/o/r/pulls -f base=main'
# Four spellings, four tails, and seven rows -- five before #133, and the count is
# here so that a tail losing its row is visible. Two tails are read by more than
# one row: the retarget's by three, its two claims failing apart and a says_not
# holding out the phrase #133 removed, and the API tail by two, because the REST
# and graphql spellings reach one sentence, both setting API_BAD_BASE, so this
# asks whether graphql arrives at the informative one rather than at some bare
# refusal of its own. The first
# version of this block pinned the constant half for graphql and left the tail to
# the REST row -- an asymmetry review found, and the shape #40 was filed for: a
# rule, or here a message, that holds for one spelling and not another.
says "$ON_DEV" no-pr-decisions.sh 'the same destination under another spelling' \
  'and the graphql spelling reaches that same sentence' \
  'gh api graphql -f query="mutation{createPullRequest(input:{baseRefName:\"main\"})}"'

# no-git-push.sh's bare-push refusal, the other message #105 found unread. It
# interpolates the branch the worktree is actually on, and that is the whole of
# what makes the correction one step: an agent reading `git push <remote>
# <branch>` still has to work out what <branch> is here, and one reading the
# name does not. The literal carries $PUSH_BRANCH, so a message reverted to a
# placeholder -- or naming some other branch -- turns this red.
req US-7
says "$PUSH_WT" no-git-push.sh "Name the branch: git push <remote> $PUSH_BRANCH." \
  'a push naming no refspec names this worktree'"'"'s own branch' 'git push'
says "$PUSH_WT" no-git-push.sh "Name the branch: git push <remote> $PUSH_BRANCH." \
  'a push naming a remote and no refspec names it too' 'git push origin'
# And the reason, which is what stops an agent answering the refusal with
# `git config` instead of with a branch name.
says "$PUSH_WT" no-git-push.sh 'takes its destination from configuration, which this command could have set for itself' \
  'the bare-push refusal says why configuration is not read' 'git push'

section "=== no-pr-decisions.sh : must BLOCK ==="
req US-15
for c in 'gh pr merge 5' \
         'gh pr merge --auto --squash 5' \
         'cd /tmp && gh pr merge 5' \
         '(gh pr merge 5)' \
         'gh pr review --approve 5' \
         'gh pr review -a 5' \
         'gh pr review --request-changes -b "no"' \
         'gh pr close 5' \
         'gh pr reopen 5' \
         'gh release create v1.0.0' \
         'gh release delete v1.0.0' \
         'gh api -X PUT repos/bgunyel/clause-and-effect/pulls/5/merge' \
         'gh api --method POST /repos/bgunyel/clause-and-effect/pulls/5/reviews -f event=APPROVE' \
         'gh api https://api.github.com/repos/bgunyel/clause-and-effect/pulls/5/merge -X PUT' \
         'gh api graphql -f query="mutation { mergePullRequest(input:{x:1}) }"' \
         'gh api graphql -f query="mutation { addPullRequestReview(input:{event:APPROVE}) }"'
do check no-pr-decisions.sh BLOCK "$c" "$c"; done

section "=== no-pr-decisions.sh : must ALLOW ==="
for c in 'gh pr create --base dev-05 --title x --body y' \
         'gh pr comment 5 --body "looks fine"' \
         'gh pr review --comment -b "a remark"' \
         'gh pr view 5' \
         'gh pr list' \
         'gh pr diff 5' \
         'gh pr checks 5' \
         'gh pr edit 5 --add-label bug' \
         'gh pr ready 5' \
         'gh issue close 27' \
         'gh issue comment 27 --body x' \
         'gh release list' \
         'gh api repos/bgunyel/clause-and-effect/pulls/5' \
         'gh api repos/bgunyel/clause-and-effect/issues/27/comments' \
         'echo "then run gh pr merge 5 to land it" >> notes.md' \
         'git push'
do
  # One loop, several requirements: each spelling is tagged with the one it keeps.
  case "$c" in
    'gh issue '*)     req US-14 ;;
    'gh release '*)   req FR-48 ;;
    'gh api '*)       req FR-20 US-13 ;;
    'gh pr create '*) req FR-15 FR-16 US-8 ;;
    'gh pr review '*) req US-13 US-15 ;;
    'gh pr '*)        req US-13 ;;
    *)                req FR-3 ;;
  esac
  check no-pr-decisions.sh ALLOW "$c" "$c"
done

section "=== issue #105: every gh issue subcommand stays available ==="
# US-14, asked of the whole story rather than of the three spellings that
# happened to get written down in the loop above. no-pr-decisions.sh reaches gh
# through the group `pr|release|api`, so `gh issue` is untouched by
# construction -- and by construction is what this suite exists not to take on
# trust. #69 is the precedent: a command name matched as a substring refused
# ordinary greps, and nothing in a group's spelling says that `issue` cannot be
# reached the same way by the next edit.
#
# The list is gh's own, off `gh issue --help`: fifteen verbs, of which create,
# close and comment are pinned above and develop is answered below rather than
# here. These are the other eleven, plus develop's read spelling. A verb gh adds
# later is one line here.
#
# Two reasons for one verdict, worth separating because they would fail apart.
# A read -- list, status, view -- names no decision at all. A write -- delete,
# transfer, lock -- IS a decision, and it is an issue's, which is not what this
# boundary reserves: nothing here is a pull request or a release.
#
# Measured rather than reasoned, on the three mutations an edit to this file
# would plausibly make. `gh_rule issue` added beside the rules above -- a
# subcommand path one word short of the verb whoever added it meant to name --
# turns 18 checks red: every one of the twelve below, and six gh issue commands
# already pinned elsewhere in this suite. Nothing that is not a gh issue command
# goes red, which is the half that says the rows are asking about this and not
# about the hook generally. The narrower accident,
# `gh_rule 'issue delete' || gh_rule 'issue transfer'`, turns exactly two of the
# twelve. And widening the WRAPPER rule's group to `pr|release|api|issue` turns
# none of them: that rule reads only a wrapped line, so it is the two wrapped
# issue commands in the #51 section above that go red instead -- worth recording
# because it is the mutation a reader guesses first, and it is the wrong one.
req US-14
for c in 'gh issue list' \
         'gh issue status' \
         'gh issue view 27' \
         'gh issue reopen 27' \
         'gh issue edit 27 --add-label bug' \
         'gh issue delete 27 --yes' \
         'gh issue transfer 27 o/other' \
         'gh issue lock 27' \
         'gh issue unlock 27' \
         'gh issue pin 27' \
         'gh issue unpin 27' \
         'gh issue develop --list 27'
do check no-pr-decisions.sh ALLOW "$c" "$c"; done
# THE ONE VERB THIS SECTION DOES NOT PIN, and why the absence is written down
# rather than left as a gap in a list. `gh issue develop 27` creates a linked
# branch ON THE REMOTE: an issue subcommand by name, a ref-creating write by
# effect, and permitted today by every hook because none of them matches
# anything but `git push`. CLAUDE.md says pushing this worktree's branch "is the
# whole of what it may push", so the verdict may be wrong, and #103 Q18 forbids
# pinning a verdict that may be wrong -- a check written to keep today's answer
# is how a defect stops being visible. Filed as #131, which sets out the three
# answers available and whose they are; the check that pins the one taken
# arrives with it. `--list` above is a read and is pinned as one.
#
# US-14 is covered either way: coverage is one bit per requirement, and the
# twelve rows above carry it. So the matrix does not hide this, and neither
# does this file.

section "=== REGRESSION: review of #43, prefixes and separated options hid commands ==="
# Found by reviewing the #43 migration, fixed in lib/command-scan.sh, and
# therefore not about no-commit-to-main.sh: every hook was blind to these.
# cs_split stripped a wrapper word and its options but not an operand, so
# `timeout 30` left a bare 30 where the command word had to be; sudo, doas,
# setsid and chronic were not wrapper words at all; and cs_git_args skipped
# --git-dir only in its = form, so the separated one hid the subcommand behind
# its own value.
req GH-43.6 US-3
check_in "$PUSH_WT" no-git-push.sh BLOCK 'timeout before a wholesale push' 'timeout 5 git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'sudo before a mirror push'       'sudo git push --mirror origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'separated --git-dir before a push' 'git --git-dir /tmp/other/.git push --all origin'
req GH-43.6 US-15
check no-pr-decisions.sh BLOCK 'setsid before a merge'           'setsid gh pr merge 5'
check no-pr-decisions.sh BLOCK 'sudo before a merge'             'sudo gh pr merge 5'
# The operand strip takes one token and only if it is not an option, so an
# ordinary command that begins with one of these words is still itself.
req GH-43.6
check_in "$PUSH_WT" no-git-push.sh ALLOW 'timeout in front of something else' 'timeout 5 make test'
check_in "$PUSH_WT" no-git-push.sh ALLOW 'sudo in front of something else'    'sudo apt-get install jq'

# Found by reviewing PR #49, and the same defect one turn further on. Stripping
# a wrapper word and its options leaves the value of any option that took one
# where the command word has to be, so the operand rule above closes `timeout
# 30` and not `timeout -s KILL 30`, and closes nothing at all for the wrapper
# words that have no operand rule. cs_split offers the tail as further
# candidates rather than keeping a third list of which options take a value.
req GH-43.6 US-3
check_in "$PUSH_WT" no-git-push.sh BLOCK 'sudo with a separated option value'   'sudo -u root git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'nice with a separated niceness'       'nice -n 10 git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'ionice with a separated class'        'ionice -c 2 git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'timeout whose signal took the operand' 'timeout -s KILL 30 git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'xargs with a separated count'         'xargs -n 1 git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'env with a separated directory'       'env -C /tmp git push --all origin'
req GH-43.6 US-15
check no-pr-decisions.sh BLOCK 'sudo with a separated option value, before a merge' \
  'sudo -u root gh pr merge 5'
# The tail only ever adds candidates, so an ordinary command that begins with a
# wrapper word still yields itself and the additions refuse nothing.
req GH-43.6 FR-3
check_in "$PUSH_WT" no-git-push.sh ALLOW 'a wrapper option value in front of something else' \
  'sudo -u root apt-get install jq'
check_in "$PUSH_WT" no-git-push.sh ALLOW 'a commit whose message quotes a push, behind a wrapper' \
  'sudo git commit -m "git push --all origin"'

section "=== no-commit-to-main.sh : invariants, identical literals across #43 ==="
# What the migration preserved. These six were written before it, are green on
# both sides of it, and are the whole of what this file is for: main is not
# committed to, and main is not pushed to.
req US-1
check_in "$ON_MAIN" no-commit-to-main.sh BLOCK 'commit while standing on main' \
  'git commit -m "wip"'
check_in "$ON_DEV"  no-commit-to-main.sh ALLOW 'commit on a dev branch' \
  'git commit -m "wip"'
check_in "$ON_DEV"  no-commit-to-main.sh BLOCK 'push naming main' \
  'git push origin main'
check_in "$ON_DEV"  no-commit-to-main.sh BLOCK 'the HEAD:main refspec' \
  'git push origin HEAD:main'
check_in "$ON_DEV"  no-commit-to-main.sh ALLOW 'main on the source side only' \
  'git push origin main:spike'
req US-1 GH-43.4
check_in "$ON_MAIN" no-commit-to-main.sh BLOCK 'a bare push while on main' \
  'git push'
# The other side of the bare push, and the commands this file has no opinion
# about at all. Also invariant: a commit message may name a push, and a push of
# a dev branch is no business of this file's.
req US-1 GH-43.4
check_in "$ON_DEV"  no-commit-to-main.sh ALLOW 'a bare push on a dev branch' \
  'git push'
check_in "$ON_DEV"  no-commit-to-main.sh ALLOW 'push of a dev branch' \
  'git push origin dev-99'
req GH-43.1
check_in "$ON_DEV"  no-commit-to-main.sh ALLOW 'commit message naming a push' \
  'git commit -m "explain how to git push later"'
req US-1
check_in "$ON_MAIN" no-commit-to-main.sh ALLOW 'neither a commit nor a push' \
  'git status'
req FR-3 US-1 GH-43.1
check_in "$ON_MAIN" no-commit-to-main.sh BLOCK 'commit after a control word' \
  'if true; then git commit -m "wip"; fi'
# A commit message is the one argument here that carries arbitrary prose, so
# the directory options are matched only where git accepts them. Permitted
# before the migration for a weaker reason -- they were not matched at all.
req GH-43.2
check_in "$ON_DEV"  no-commit-to-main.sh ALLOW 'a commit message naming -C' \
  'git commit -m "stop matching -C everywhere"'
# A prefix word the old anchor did not care about, because it looked only for a
# space in front of `git`. cs_split strips a known wrapper word and its
# options, and these were not in its list -- so the migration first lost these
# four, in the permitting direction, and lib/command-scan.sh was corrected
# rather than the loss being recorded. Found reviewing the migration.
req GH-43.6 US-1
check_in "$ON_MAIN" no-commit-to-main.sh BLOCK 'sudo in front of a commit on main' \
  'sudo git commit -m "wip"'
check_in "$ON_MAIN" no-commit-to-main.sh BLOCK 'timeout, whose operand is not an option' \
  'timeout 30 git commit -m "wip"'
check_in "$ON_DEV"  no-commit-to-main.sh BLOCK 'timeout in front of a push to main' \
  'timeout 30 git push origin main'
check_in "$ON_DEV"  no-commit-to-main.sh BLOCK 'sudo in front of a push to main' \
  'sudo git push origin main'

section "=== no-commit-to-main.sh : what #43 changed, verdict by verdict ==="
# Written before the migration against the file as it stood, so each `was` is
# a measurement of the old file and not a guess about it. Reverting the
# migration fails exactly this section.
#
# The first three are the same defect from three directions: the file answered
# the command-position question itself, with a bare preceding space for an
# anchor and no notion of a heredoc body. The heredoc case is the one that
# blocked the writing of issue #36 -- a ticket cannot quote the command it is
# about. The quoted-string cases are the same false positive the sibling hooks
# were rebuilt to stop.
req GH-43.1
flip "$ON_DEV"  no-commit-to-main.sh BLOCK ALLOW 'heredoc body quoting a push to main' \
  $'cat >> notes.md <<EOF\ngit push origin main is refused here\nEOF\necho written'
flip "$ON_MAIN" no-commit-to-main.sh BLOCK ALLOW 'a commit named inside a quoted string' \
  'echo "never git commit while standing on main"'
flip "$ON_DEV"  no-commit-to-main.sh BLOCK ALLOW 'a push named inside a quoted string' \
  'echo "never git push origin main from here"'
# The branch was read with `git branch --show-current` in the hook's own
# working directory, which is the session's and not necessarily the command's,
# while nothing refused a command that changed directory. #40 refused to
# compute a merge base here for exactly this reason.
req GH-43.2
flip "$ON_DEV"  no-commit-to-main.sh ALLOW BLOCK 'cd into a repository on main, then commit' \
  "cd $ON_MAIN && git commit -m 'on main'"
flip "$ON_DEV"  no-commit-to-main.sh ALLOW BLOCK 'GIT_DIR pointed at a repository on main' \
  "GIT_DIR=$ON_MAIN/.git git commit -m 'on main'"
flip "$ON_DEV"  no-commit-to-main.sh ALLOW BLOCK 'git -C into another repository' \
  "git -C $ON_MAIN commit -m 'on main'"
# A wrapper's payload sits in quotes, where the old anchor found no command at
# all: a wrapped commit was permitted on main itself. Refused outright now,
# as in both sibling hooks.
req GH-43.3 FR-4
flip "$ON_MAIN" no-commit-to-main.sh ALLOW BLOCK 'sh -c wrapping a commit, on main' \
  "sh -c 'git commit -m \"wip\"'"
flip "$ON_DEV"  no-commit-to-main.sh ALLOW BLOCK 'eval wrapping a push to main' \
  'eval "git push origin main"'
# Matching main by name could not see a spelling that named no branch, which is
# the hole PR #35 closed in no-git-push.sh and left open here. Both of these
# advance main from a dev branch.
req GH-43.4 US-1
flip "$ON_DEV"  no-commit-to-main.sh ALLOW BLOCK 'push --all advances main too' \
  'git push --all origin'
flip "$ON_DEV"  no-commit-to-main.sh ALLOW BLOCK 'push --mirror advances main too' \
  'git push --mirror origin'
# The bare-push case rests on configuration, and -c replaces it for this one
# command: push.default=matching advances main from a dev branch.
flip "$ON_DEV"  no-commit-to-main.sh ALLOW BLOCK 'push with configuration set inline' \
  'git -c push.default=matching push'
# HEAD names whatever is checked out, so on main it names main -- and it also
# counts as a refspec, which switched off the bare-push case that would have
# caught the same push. `git push -u origin HEAD` is a shape written daily.
# Found reviewing the migration; no-git-push.sh already resolves HEAD, and
# this file did not.
flip "$ON_MAIN" no-commit-to-main.sh ALLOW BLOCK 'push origin HEAD while on main' \
  'git push origin HEAD'
flip "$ON_MAIN" no-commit-to-main.sh ALLOW BLOCK 'push -u origin HEAD while on main' \
  'git push -u origin HEAD'
flip "$ON_MAIN" no-commit-to-main.sh ALLOW BLOCK 'the @ spelling of HEAD' \
  'git push origin @'
req GH-43.4
check_in "$ON_DEV" no-commit-to-main.sh ALLOW 'HEAD off main still names a dev branch' \
  'git push origin HEAD'
# Changing branch defeats the branch read exactly as changing directory does,
# and is the likelier of the two. Refusing directory moves while permitting
# this left the soundness claim half-made. Found reviewing the migration.
req GH-43.2
flip "$ON_DEV"  no-commit-to-main.sh ALLOW BLOCK 'checkout main, then commit' \
  'git checkout main && git commit -m "wip"'
flip "$ON_DEV"  no-commit-to-main.sh ALLOW BLOCK 'switch to main, then commit' \
  'git switch main && git commit -m "wip"'
# git's directory options in their separated spelling. cs_git_args skipped
# --git-dir only in its = form, so the separated one left the path at the head
# of the line, the subcommand was never found, and this file left without an
# opinion -- with `main` written in the command. Found reviewing the migration.
req GH-43.2 GH-43.6
flip "$ON_DEV"  no-commit-to-main.sh ALLOW BLOCK 'separated --git-dir before commit' \
  "git --git-dir $ON_MAIN/.git commit -m 'on main'"
flip "$ON_DEV"  no-commit-to-main.sh ALLOW BLOCK 'separated --namespace before a push to main' \
  'git --namespace n push origin main'

# What this file does when lib/command-scan.sh is not loadable is checked in the
# load-contract section at the foot of this suite, with the same question asked of
# the other three hooks. It was asked here, of this hook alone, and issue #84
# found two hooks with no guard at all and a third requiring one function of three
# while both blocks stayed green.

section "=== the refusals still name main, which is why this file is kept ==="
req GH-43.5
says "$ON_MAIN" no-commit-to-main.sh 'Blocked: committing to main.' \
  'a commit on main is refused as a commit on main' 'git commit -m "wip"'
says "$ON_DEV"  no-commit-to-main.sh 'Blocked: pushing to main.' \
  'a push to main is refused as a push to main' 'git push origin main'
says "$ON_MAIN" no-commit-to-main.sh "bare 'git push' while on main" \
  'the bare push keeps its own wording' 'git push'
req GH-43.5 GH-43.2
says "$ON_DEV"  no-commit-to-main.sh 'whether it lands on main' \
  'a directory move says what cannot be judged' "cd $ON_MAIN && git commit -m 'wip'"

section "=== no-work-on-stale-branch.sh: a branch whose life is over ==="
# Three lifecycle states in one throwaway repository, all built locally: the
# remote-tracking refs are written with update-ref, so nothing here reaches a
# network. Unlike the fixtures above, these need real commits -- ahead/behind
# is the whole question -- so an identity is set on each commit rather than
# borrowed from whatever global configuration the runner happens to have.
LIFE="$FIXTURES/lifecycle"
git init -q -b main "$LIFE"
GL="git -C $LIFE -c user.email=checks@example.invalid -c user.name=checks"
# A remote named origin has to exist for git to resolve an upstream at all --
# without one, `%(upstream:track)` is empty rather than `[gone]` and the first
# detector cannot fire. Nothing here ever reaches the URL; the fetch refspec it
# brings is what maps refs/heads/x to refs/remotes/origin/x.
$GL remote add origin "$FIXTURES/unreachable-remote.git"
$GL commit -q --allow-empty -m base
LIFE_BASE=$($GL rev-parse HEAD)
$GL commit -q --allow-empty -m advance
LIFE_TIP=$($GL rev-parse HEAD)
# The active dev branch, one commit ahead of base. Two decoys stand beside it:
# origin/dev-foo would win a lexical sort of the glob, and origin/dev-4 would
# win one against dev-05 unless the sort is a version sort.
$GL update-ref refs/remotes/origin/dev-05 "$LIFE_TIP"
$GL update-ref refs/remotes/origin/dev-foo "$LIFE_BASE"
$GL update-ref refs/remotes/origin/dev-4 "$LIFE_BASE"
# A local dev-05 at the same commit, which is the state a checkout-and-pull
# leaves. Without it the short-spelling and refs/heads/ catch-up checks below
# were green for the wrong reason: the hook compared two strings against a ref
# that did not exist here at all, and `git merge dev-05` run for real in this
# fixture fails in git. The sibling fixtures hold the other two states.
$GL branch dev-05 "$LIFE_TIP"

# ahead == 0, behind == 1. The fallback detector's case, and nothing else: this
# branch has no upstream configured, so `[gone]` cannot be what refuses it.
$GL branch stale-branch "$LIFE_BASE"
$GL worktree add -q "$LIFE/wt-stale" stale-branch

# upstream configured, remote-tracking ref absent -- what a pruning fetch leaves
# behind after delete_branch_on_merge removes the branch. Placed at the dev tip
# so ahead == 0 and behind == 0: the fallback cannot fire here, and a refusal is
# the gone detector's alone.
$GL branch gone-branch "$LIFE_TIP"
$GL config -f "$LIFE/.git/config" branch.gone-branch.remote origin
$GL config -f "$LIFE/.git/config" branch.gone-branch.merge refs/heads/gone-branch
$GL worktree add -q "$LIFE/wt-gone" gone-branch

# A fresh worktree branch at the dev tip: ahead == 0, behind == 0.
$GL branch fresh-branch "$LIFE_TIP"
$GL worktree add -q "$LIFE/wt-fresh" fresh-branch

# A worktree branch carrying work of its own: ahead == 1.
$GL branch work-branch "$LIFE_TIP"
$GL worktree add -q "$LIFE/wt-work" work-branch
git -C "$LIFE/wt-work" -c user.email=checks@example.invalid -c user.name=checks \
  commit -q --allow-empty -m own

# The main checkout is moved to the same commit as the stale worktree branch, so
# the two differ in exactly one thing: where the command runs. An identical
# command is BLOCK in one and ALLOW in the other, which is the keying claim
# stated as a check rather than as a sentence in a header.
$GL update-ref refs/heads/main "$LIFE_BASE"

WT_STALE="$LIFE/wt-stale"
WT_GONE="$LIFE/wt-gone"
WT_FRESH="$LIFE/wt-fresh"
WT_WORK="$LIFE/wt-work"
# Two levels below the root of the main checkout and of the stale worktree, for
# issue #94: below the root is where git stops printing --git-dir and
# --git-common-dir in the same form.
mkdir -p "$LIFE/src/deep" "$WT_STALE/src/deep"
LIFE_LINK="$FIXTURES/lifecycle-link"
ln -s "$LIFE" "$LIFE_LINK"

[ -d "$WT_STALE" ] && [ -d "$WT_GONE" ] && [ -d "$WT_WORK" ] && [ -d "$WT_FRESH" ] \
  && [ -d "$LIFE/src/deep" ] && [ -d "$WT_STALE/src/deep" ] && [ -d "$LIFE_LINK/src/deep" ] \
  && [ -d "$LIFE_LINK/wt-stale/src/deep" ] || {
  echo "the lifecycle worktrees were not created; every check below would pass without running the hook" >&2
  exit 1
}

echo "--- upstream gone: the branch was merged and its remote half is pruned ---"
req GH-44.1 FR-38
check_in "$WT_GONE" no-work-on-stale-branch.sh BLOCK 'commit on a merged branch' \
  'git commit -m "wip"'
check_in "$WT_GONE" no-work-on-stale-branch.sh BLOCK 'cherry-pick, the recovery procedure own command' \
  'git cherry-pick 1234abc'
check_in "$WT_GONE" no-work-on-stale-branch.sh BLOCK 'revert on a merged branch' \
  'git revert HEAD'
check_in "$WT_GONE" no-work-on-stale-branch.sh BLOCK 'am on a merged branch' \
  'git am /tmp/patch.mbox'
# Merging into a branch that no longer exists on the remote is meaningless, so
# the carve-out that exists under the fallback does not exist here.
req GH-44.3 GH-44.1
check_in "$WT_GONE" no-work-on-stale-branch.sh BLOCK 'merge naming the dev branch is still refused' \
  'git merge origin/dev-05'
check_in "$WT_GONE" no-work-on-stale-branch.sh BLOCK 'rebase naming the dev branch is still refused' \
  'git rebase origin/dev-05'
# A refusal mid-rebase strands state the agent cannot exit.
req GH-44.4
check_in "$WT_GONE" no-work-on-stale-branch.sh ALLOW 'rebase --continue' \
  'git rebase --continue'
check_in "$WT_GONE" no-work-on-stale-branch.sh ALLOW 'merge --abort' \
  'git merge --abort'
check_in "$WT_GONE" no-work-on-stale-branch.sh ALLOW 'cherry-pick --skip' \
  'git cherry-pick --skip'
# A commit message is the one argument on this path that carries arbitrary
# prose, and the arguments are stripped of their quotes before the continuation
# flags are looked for. So the text of a message read as an option, and
# `git commit -m "permit rebase --continue"` -- the shape of a message written
# while working on this very hook -- permitted a commit on a merged branch.
# Silent, and in the permitting direction. Found by review, not by this suite:
# every continuation check here drove the bare flag, which is exactly the case
# that already worked.
req GH-44.4
check_in "$WT_GONE" no-work-on-stale-branch.sh BLOCK 'a commit message naming a continuation flag' \
  'git commit -m "permit rebase --continue"'
check_in "$WT_GONE" no-work-on-stale-branch.sh BLOCK 'a commit message naming --skip' \
  'git commit -m "handle --skip in the guard"'
check_in "$WT_GONE" no-work-on-stale-branch.sh BLOCK 'a merge message naming a continuation flag' \
  'git merge -m "wip --continue" some-other-branch'
# An unterminated quote is argument text past the point this can read, and
# reading argument text as a flag is what permits here, so the ambiguous case
# must not.
check_in "$WT_GONE" no-work-on-stale-branch.sh BLOCK 'an unterminated quote before a continuation flag' \
  'git commit -m "wip --continue'
# A continuation flag anywhere but the first argument is not a continuation.
check_in "$WT_GONE" no-work-on-stale-branch.sh BLOCK 'a continuation flag trailing a real commit' \
  'git commit -m "wip" --skip'
check_in "$WT_GONE" no-work-on-stale-branch.sh BLOCK 'a continuation flag trailing a cherry-pick' \
  'git cherry-pick 1234abc --continue'
check_in "$WT_GONE" no-work-on-stale-branch.sh BLOCK 'a continuation flag behind an option' \
  'git rebase --quiet --continue'
req GH-44.1 FR-38
check_in "$WT_GONE" no-work-on-stale-branch.sh ALLOW 'a read is not work' \
  'git log --oneline -5'
check_in "$WT_GONE" no-work-on-stale-branch.sh ALLOW 'a command with no git in it at all' \
  'ls -la'
req FR-4 GH-44.1
check_in "$WT_GONE" no-work-on-stale-branch.sh BLOCK 'a commit wrapped in a shell' \
  "sh -c 'git commit -m \"wip\"'"
check_in "$WT_GONE" no-work-on-stale-branch.sh BLOCK 'a cherry-pick wrapped in eval' \
  'eval "git cherry-pick 1234abc"'
# The fourth consumer's share of issue #79: the same two commands behind a
# prefix word this hook's wrapper rule could not see. Each was ALLOW before the
# anchor was widened, and the #79 section above says these live here rather
# than beside its own checks, because the verdicts need these fixtures.
req GH-79.1
check_in "$WT_GONE" no-work-on-stale-branch.sh BLOCK 'sudo + a wrapped commit' \
  "sudo sh -c 'git commit -m \"wip\"'"
check_in "$WT_GONE" no-work-on-stale-branch.sh BLOCK 'timeout + a wrapped commit' \
  "timeout 5 bash -c 'git commit -m \"wip\"'"
check_in "$WT_GONE" no-work-on-stale-branch.sh BLOCK 'xargs + a wrapped cherry-pick' \
  "xargs sh -c 'git cherry-pick 1234abc'"
check_in "$WT_GONE" no-work-on-stale-branch.sh BLOCK 'nohup + a wrapped eval merge' \
  "nohup eval 'git merge other-branch'"
# And the control from the same section: a wrapper named in prose is not one,
# so the widening did not cost this hook a read either.
req GH-79.2
check_in "$WT_GONE" no-work-on-stale-branch.sh ALLOW 'grepping for the sudo sh -c rule' \
  "grep -rn 'sudo sh -c .*git commit' .claude/hooks/"

echo "--- the fallback: ahead == 0, behind > 0 against the active dev branch ---"
req GH-44.2 FR-38
check_in "$WT_STALE" no-work-on-stale-branch.sh BLOCK 'commit on a branch dev has moved past' \
  'git commit -m "wip"'
check_in "$WT_STALE" no-work-on-stale-branch.sh BLOCK 'cherry-pick' \
  'git cherry-pick 1234abc'
check_in "$WT_STALE" no-work-on-stale-branch.sh BLOCK 'revert' \
  'git revert HEAD'
check_in "$WT_STALE" no-work-on-stale-branch.sh BLOCK 'am' \
  'git am /tmp/patch.mbox'
# ahead == 0 means this branch is a strict ancestor of the dev branch, so this
# is a fast-forward: it creates no commit and masks nothing. Refusing it would
# deadlock the branch -- no commit, no catch-up, and removing a worktree is a
# reserved act.
req GH-44.3
check_in "$WT_STALE" no-work-on-stale-branch.sh ALLOW 'the catch-up merge, remote spelling' \
  'git merge origin/dev-05'
check_in "$WT_STALE" no-work-on-stale-branch.sh ALLOW 'the catch-up merge, short spelling' \
  'git merge dev-05'
check_in "$WT_STALE" no-work-on-stale-branch.sh ALLOW 'the catch-up merge, full ref' \
  'git merge refs/remotes/origin/dev-05'
check_in "$WT_STALE" no-work-on-stale-branch.sh ALLOW 'the catch-up merge, local full ref' \
  'git merge refs/heads/dev-05'
check_in "$WT_STALE" no-work-on-stale-branch.sh ALLOW 'the catch-up merge, --ff-only' \
  'git merge --ff-only origin/dev-05'
check_in "$WT_STALE" no-work-on-stale-branch.sh ALLOW 'the catch-up rebase' \
  'git rebase origin/dev-05'
# Anything else a merge or rebase can name would write a real commit here.
check_in "$WT_STALE" no-work-on-stale-branch.sh BLOCK 'a merge naming another branch' \
  'git merge some-other-branch'
check_in "$WT_STALE" no-work-on-stale-branch.sh BLOCK 'a rebase naming another branch' \
  'git rebase some-other-branch'
# --no-ff exists to write a merge commit where a fast-forward would do, which is
# the one thing the carve-out is for not doing.
check_in "$WT_STALE" no-work-on-stale-branch.sh BLOCK 'the catch-up merge forced to commit' \
  'git merge --no-ff origin/dev-05'
# --onto is where a rebase's destination really is; naming the dev branch after
# it names it as the source.
check_in "$WT_STALE" no-work-on-stale-branch.sh BLOCK 'rebase --onto somewhere else' \
  'git rebase --onto some-other-branch origin/dev-05'
# A bare merge takes its argument from configuration and names nothing.
check_in "$WT_STALE" no-work-on-stale-branch.sh BLOCK 'a merge naming nothing at all' \
  'git merge'
check_in "$WT_STALE" no-work-on-stale-branch.sh BLOCK 'a rebase naming nothing at all' \
  'git rebase'
# The carve-out is the only permitting path out of a refused state, so anything
# that moves git elsewhere or moves the branch underneath it withdraws it: the
# state was read here, and these make here the wrong place to have read it.
check_in "$WT_STALE" no-work-on-stale-branch.sh BLOCK 'the catch-up merge after a directory change' \
  "cd $WT_WORK && git merge origin/dev-05"
check_in "$WT_STALE" no-work-on-stale-branch.sh BLOCK 'the catch-up merge after a checkout' \
  'git checkout fresh-branch && git merge origin/dev-05'
check_in "$WT_STALE" no-work-on-stale-branch.sh BLOCK 'the catch-up merge with git pointed elsewhere' \
  'git --git-dir /elsewhere/.git merge origin/dev-05'
# Issue #68 reaches this file here, and this is the one place in the boundary
# where a lost fragment RETAINS an exception rather than dropping a refusal --
# the three tests above set CARVE= from the fragment list. The merge itself
# carries no free-text argument that could hold a quoted cd, because -m
# withdraws the carve-out on its own; the shape that reaches it is a quoted
# separator in a SIBLING command on the same line, which used to produce a
# fragment headed by cd and refuse the catch-up merge on the strength of a
# directory change bash would never have made. Measured on this fixture, old
# split against new.
#
# The unquoted control below is what says the withdrawal itself still works.
# See the header of lib/command-scan.sh for why this direction is safe: not
# because a cut can only refuse more -- that argument does not hold in this
# file -- but because the fallback catches every line the tracker cannot read,
# so a cd bash would actually run is still cut out.
req GH-44.3 GH-68.1
check_in "$WT_STALE" no-work-on-stale-branch.sh ALLOW 'a cd quoted in a sibling command (was BLOCK)' \
  "git merge origin/dev-05 && echo 'x; cd /tmp'"
check_in "$WT_STALE" no-work-on-stale-branch.sh ALLOW 'a checkout quoted in a sibling command (was BLOCK)' \
  "git merge origin/dev-05 && echo 'x; git checkout main'"
req GH-44.3
check_in "$WT_STALE" no-work-on-stale-branch.sh BLOCK 'an unquoted cd still withdraws the carve-out' \
  'cd /tmp && git merge origin/dev-05'
check_in "$WT_STALE" no-work-on-stale-branch.sh BLOCK 'an unquoted checkout still withdraws it' \
  'git checkout main && git merge origin/dev-05'
# Every command, not the first: the permitted half does not license the second.
req GH-44.3 GH-44.2
check_in "$WT_STALE" no-work-on-stale-branch.sh BLOCK 'a permitted merge followed by a commit' \
  'git merge origin/dev-05 && git commit -m "wip"'
req GH-44.4
check_in "$WT_STALE" no-work-on-stale-branch.sh ALLOW 'rebase --continue' \
  'git rebase --continue'
check_in "$WT_STALE" no-work-on-stale-branch.sh BLOCK 'a commit message naming a continuation flag' \
  'git commit -m "permit rebase --continue"'
check_in "$WT_STALE" no-work-on-stale-branch.sh BLOCK 'a merge message naming a continuation flag' \
  'git merge -m "wip --continue" some-other-branch'
req GH-44.2
check_in "$WT_STALE" no-work-on-stale-branch.sh ALLOW 'a read is not work' \
  'git status'

echo "--- the catch-up must name the commit the ancestry was read against ---"
# The whitelist accepts four spellings, and two of them -- dev-NN and
# refs/heads/dev-NN -- name a local branch, while ahead == 0 was measured
# against refs/remotes/origin/dev-NN. A pruning fetch moves the second and never
# the first, so the two disagree as a matter of course here: worktree pull
# requests merge into dev-NN on GitHub while the local branch sits still.
#
# One repository cannot hold the three states, so there are three. Rejected
# alternative: `git branch -f dev-05 <other>` partway down the list above -- two
# lines instead of twenty, but it makes check ORDER load-bearing, and an
# order-dependent suite quietly stops meaning what it says.

# STATE ONE: a local dev-05 that has diverged from origin/dev-05.
#
# Diverged means forked, not merely unequal. A local dev-05 sitting one commit
# AHEAD of origin/dev-05 is unequal and harmless: the worktree branch is an
# ancestor of both, so the short spelling is still a fast-forward. The harm
# needs the worktree branch to be an ancestor of origin/dev-05 and of nothing
# else, which takes a fork:
#
#   root ---- div-stale ---- origin/dev-05        (the ancestry the hook reads)
#     \
#      ---- dev-05                                (the local branch, forked off)
#
# From div-stale, `git merge dev-05` then writes a real merge commit, ahead
# becomes > 0, and the fallback detector is retired for this branch
# permanently. A fixture built linearly instead would pass these checks while
# proving only that two strings differ.
DIV="$FIXTURES/diverged-dev"
git init -q -b main "$DIV"
GD="git -C $DIV -c user.email=checks@example.invalid -c user.name=checks"
$GD remote add origin "$FIXTURES/unreachable-remote.git"
$GD commit -q --allow-empty -m root
DIV_ROOT=$($GD rev-parse HEAD)
$GD commit -q --allow-empty -m "where the worktree branch was cut"
DIV_BASE=$($GD rev-parse HEAD)
$GD commit -q --allow-empty -m advance
$GD update-ref refs/remotes/origin/dev-05 "$($GD rev-parse HEAD)"
# The local branch's own commit, written with commit-tree so that building the
# fork needs no checkout of a second branch.
DIV_FORK=$($GD commit-tree -p "$DIV_ROOT" -m "local dev-05 forked before the worktree branch was cut" \
           "$($GD rev-parse "$DIV_ROOT^{tree}")")
$GD branch dev-05 "$DIV_FORK"
$GD branch div-stale "$DIV_BASE"
$GD worktree add -q "$DIV/wt-div" div-stale
WT_DIV="$DIV/wt-div"
need_worktree "$WT_DIV" diverged-dev
# The two halves of the shape drawn above, asserted rather than assumed: the
# worktree branch is an ancestor of the remote dev tip, and is not an ancestor
# of the local branch of the same name. The second is what makes the refused
# merge a real merge commit rather than a fast-forward.
$GD merge-base --is-ancestor refs/heads/div-stale refs/remotes/origin/dev-05 || {
  echo "div-stale is not an ancestor of origin/dev-05, so the fallback will not fire; the checks below prove nothing" >&2
  exit 1
}
$GD merge-base --is-ancestor refs/heads/div-stale refs/heads/dev-05 && {
  echo "div-stale is an ancestor of local dev-05, so the short spelling would be a fast-forward; the checks below prove nothing" >&2
  exit 1
}
req GH-58.1
check_in "$WT_DIV" no-work-on-stale-branch.sh ALLOW 'diverged local dev-05: the remote spelling is still the fast-forward' \
  'git merge origin/dev-05'
check_in "$WT_DIV" no-work-on-stale-branch.sh ALLOW 'diverged local dev-05: and so is its full ref' \
  'git merge refs/remotes/origin/dev-05'
check_in "$WT_DIV" no-work-on-stale-branch.sh BLOCK 'diverged local dev-05: the short spelling would write a merge commit' \
  'git merge dev-05'
# A rebase writes no merge commit; it replays this branch's commits onto the
# named branch, which is just as much work on a branch the dev tip has moved
# past, and it moves ahead the same way.
check_in "$WT_DIV" no-work-on-stale-branch.sh BLOCK 'diverged local dev-05: a rebase onto its full ref is not the catch-up either' \
  'git rebase refs/heads/dev-05'

# STATE TWO: no local dev-05 at all, which is what a linked worktree normally
# sees -- nobody checks out and pulls dev-NN in one. THE TRADE THIS FIX MAKES IS
# HERE: the short spelling used to be permitted in this state and is now
# refused. Nothing is lost. Run for real, `git merge dev-05` fails in git
# anyway, because dev-05 resolves through refs/heads/, refs/tags/ and
# refs/remotes/<name>/, and a remote-tracking origin/dev-05 is none of those.
# The refusal names origin/dev-05, which is the spelling that works.
NOLOC="$FIXTURES/no-local-dev"
git init -q -b main "$NOLOC"
GX="git -C $NOLOC -c user.email=checks@example.invalid -c user.name=checks"
$GX remote add origin "$FIXTURES/unreachable-remote.git"
$GX commit -q --allow-empty -m base
NOLOC_BASE=$($GX rev-parse HEAD)
$GX commit -q --allow-empty -m advance
$GX update-ref refs/remotes/origin/dev-05 "$($GX rev-parse HEAD)"
$GX branch noloc-stale "$NOLOC_BASE"
$GX worktree add -q "$NOLOC/wt-noloc" noloc-stale
WT_NOLOC="$NOLOC/wt-noloc"
need_worktree "$WT_NOLOC" no-local-dev
$GX rev-parse --verify --quiet refs/heads/dev-05 >/dev/null && {
  echo "a local dev-05 exists in the no-local-dev fixture; the trade check below proves nothing" >&2
  exit 1
}
check_in "$WT_NOLOC" no-work-on-stale-branch.sh ALLOW 'no local dev-05: the remote spelling is the catch-up' \
  'git merge origin/dev-05'
check_in "$WT_NOLOC" no-work-on-stale-branch.sh BLOCK 'no local dev-05: the short spelling is refused, and used to be permitted' \
  'git merge dev-05'
check_in "$WT_NOLOC" no-work-on-stale-branch.sh BLOCK 'no local dev-05: refs/heads/dev-05 names nothing either' \
  'git merge refs/heads/dev-05'

# STATE THREE: a local dev-05 merely BEHIND origin/dev-05 -- not forked, just
# not pulled. THE SECOND HARMLESS CASE THIS FIX GIVES UP, and the one that
# starts firing as soon as it lands: worktree pull requests merge into dev-05 on
# GitHub, so origin/dev-05 moves while the local branch sits still, and that is
# the ordinary state of this repository rather than an edge of it.
#
#   root ---- beh-stale, dev-05 ---- origin/dev-05
#
# From beh-stale, `git merge dev-05` is `Already up to date.` -- it writes
# nothing and masks nothing. It is refused anyway, because the test is an
# identity and the local branch is not origin/dev-05. Separating this case from
# the forked one means asking about ancestry, and a hook that rev-parses its way
# to a merge-base decision is a larger claim than this defect needs. Recorded
# here, in the file header and in the commit message, per the repository's rule
# that a fix giving up a case says so in all three.
BEH="$FIXTURES/behind-dev"
git init -q -b main "$BEH"
GH_="git -C $BEH -c user.email=checks@example.invalid -c user.name=checks"
$GH_ remote add origin "$FIXTURES/unreachable-remote.git"
$GH_ commit -q --allow-empty -m root
$GH_ commit -q --allow-empty -m "where local dev-05 stopped"
BEH_LOCAL=$($GH_ rev-parse HEAD)
$GH_ commit -q --allow-empty -m "where origin/dev-05 went without it"
$GH_ update-ref refs/remotes/origin/dev-05 "$($GH_ rev-parse HEAD)"
$GH_ branch dev-05 "$BEH_LOCAL"
$GH_ branch beh-stale "$BEH_LOCAL"
$GH_ worktree add -q "$BEH/wt-beh" beh-stale
WT_BEH="$BEH/wt-beh"
need_worktree "$WT_BEH" behind-dev
# Behind, not forked: the worktree branch IS an ancestor of the local branch, so
# the merge given up here is a no-op rather than a merge commit. That is the
# difference from STATE ONE, and asserting it is what stops this fixture
# quietly turning into a copy of that one.
$GH_ merge-base --is-ancestor refs/heads/beh-stale refs/heads/dev-05 || {
  echo "beh-stale is not an ancestor of local dev-05, so this is the forked case again; the checks below prove nothing" >&2
  exit 1
}
$GH_ merge-base --is-ancestor refs/heads/dev-05 refs/remotes/origin/dev-05 || {
  echo "local dev-05 is not behind origin/dev-05; the checks below prove nothing" >&2
  exit 1
}
check_in "$WT_BEH" no-work-on-stale-branch.sh ALLOW 'local dev-05 behind: the remote spelling is the catch-up' \
  'git merge origin/dev-05'
check_in "$WT_BEH" no-work-on-stale-branch.sh BLOCK 'local dev-05 behind: a harmless no-op merge, refused, and recorded as given up' \
  'git merge dev-05'

# STATE FOUR: the dev tip does not resolve to a commit. The hook holds
# `[ -n "$DEV_OID" ] || return 1` for it, and that line cannot be reached by
# running the hook: DEV is the short name of the very ref DEV_OID is read from,
# so a dev tip that will not resolve is one `git rev-list` cannot read either,
# and the file abstains above before the carve-out is ever considered. So this
# is checked twice and in two different ways -- the abstention as a process
# below, and the guard behind it as a property of the file, at the foot of this
# suite. Saying which is which is the point: a check is evidence about the case
# it names.
BADDEV="$FIXTURES/bad-dev-ref"
git init -q -b main "$BADDEV"
GB="git -C $BADDEV -c user.email=checks@example.invalid -c user.name=checks"
$GB remote add origin "$FIXTURES/unreachable-remote.git"
$GB commit -q --allow-empty -m base
BAD_BASE=$($GB rev-parse HEAD)
$GB commit -q --allow-empty -m advance
$GB branch bad-stale "$BAD_BASE"
$GB worktree add -q "$BADDEV/wt-bad" bad-stale
# A ref pointing at a blob: the ref exists, so for-each-ref names it and DEV is
# set, and nothing it points at is a commit. Written as a loose ref file rather
# than through update-ref, because update-ref's object-type check is the thing
# being worked around and its behaviour on refs/remotes/ is a git version
# detail this fixture should not depend on.
BAD_BLOB=$(printf 'not a commit' | $GB hash-object -w --stdin)
mkdir -p "$BADDEV/.git/refs/remotes/origin"
printf '%s\n' "$BAD_BLOB" > "$BADDEV/.git/refs/remotes/origin/dev-05"
WT_BAD="$BADDEV/wt-bad"
need_worktree "$WT_BAD" bad-dev-ref
[ "$($GB for-each-ref --format='%(refname:short)' 'refs/remotes/origin/dev-*' 2>/dev/null)" = "origin/dev-05" ] || {
  echo "the bad dev ref is not visible to for-each-ref; the check below proves nothing" >&2
  exit 1
}
$GB rev-parse --verify --quiet 'refs/remotes/origin/dev-05^{commit}' >/dev/null 2>&1 && {
  echo "the bad dev ref resolves to a commit; the check below proves nothing" >&2
  exit 1
}
# An unreadable count is not a stale branch: the file abstains, which is the
# same answer it gives when there is no dev ref at all.
req GH-58.2 GH-44.6
check_in "$WT_BAD" no-work-on-stale-branch.sh ALLOW 'a dev tip that is not a commit: the ancestry is unreadable, so the guard abstains' \
  'git commit -m "wip"'

echo "--- branches whose life is not over, and the main checkout ---"
req GH-44.5 FR-38
check_in "$WT_WORK"  no-work-on-stale-branch.sh ALLOW 'a branch carrying work of its own, ahead == 1' \
  'git commit -m "wip"'
check_in "$WT_FRESH" no-work-on-stale-branch.sh ALLOW 'a fresh branch at the dev tip, ahead == 0 behind == 0' \
  'git commit -m "wip"'
# The same commit, the same state, the same command -- and the main checkout is
# unaffected, because the guard keys on the linked worktree.
req GH-44.5 US-25
check_in "$LIFE" no-work-on-stale-branch.sh ALLOW 'the main checkout at the stale branch own commit' \
  'git commit -m "wip"'
# Issue #94, the refusing half. This file made the same string comparison as
# no-git-push.sh and failed the other way: below the root of the main checkout
# --git-dir and --git-common-dir printed differently, the main checkout read as
# a linked worktree, and the lifecycle rules refused an ordinary commit there --
# this checkout stands exactly where the stale worktree branch does, so the
# fallback fired on it. The check above is at the root, the one depth where the
# strings happened to agree. The worktree half at the same depths is what says
# the fix did not buy this by switching the guard off.
req GH-94.2 US-25
check_in "$LIFE/src"          no-work-on-stale-branch.sh ALLOW 'main checkout, src/: an ordinary commit is not lifecycle work' \
  'git commit -m "wip"'
check_in "$LIFE/src/deep"     no-work-on-stale-branch.sh ALLOW 'main checkout, src/deep/: an ordinary commit is not lifecycle work' \
  'git commit -m "wip"'
req GH-94.2 GH-44.2 GH-44.5
check_in "$WT_STALE/src"      no-work-on-stale-branch.sh BLOCK 'stale worktree, src/: a commit is still refused' \
  'git commit -m "wip"'
check_in "$WT_STALE/src/deep" no-work-on-stale-branch.sh BLOCK 'stale worktree, src/deep/: a commit is still refused' \
  'git commit -m "wip"'
req GH-94.2 US-25
check_in "$LIFE_LINK/src/deep" no-work-on-stale-branch.sh ALLOW 'main checkout through a symlink, src/deep/: an ordinary commit' \
  'git commit -m "wip"'
req GH-94.2 GH-44.2
check_in "$LIFE_LINK/wt-stale/src/deep" no-work-on-stale-branch.sh BLOCK 'stale worktree through a symlink, src/deep/: a commit is still refused' \
  'git commit -m "wip"'

# ISSUE #117 IN THIS HOOK TOO, and it is here rather than in #117's own section
# for one reason: that section stands above the line where $WT_STALE is built,
# and a check cannot name a fixture that does not exist yet.
#
# Written out because the issue measured six hooks of seven and said so -- "was
# not measured, since it needs a stale-branch fixture" -- and a fix whose
# evidence stops where the measurement stopped is #84 exactly: the question
# asked of the consumers that happened to be convenient. This hook reads every
# git command through cs_git_args, whose `^git` anchor is the one #117 is about,
# so the defect was here whether anyone measured it or not.
#
# #106's families do reach it, through the `commit-stale` seed, and that is why
# these are not the only thing standing between the hook and a regression. But
# those variants carry FR-38, the seed's tag, and a requirement is covered by
# the checks that NAME it; GH-117 had no check against this hook at all.
req GH-117
flip "$WT_STALE" no-work-on-stale-branch.sh ALLOW BLOCK 'a commit on a stale branch, as an absolute path' \
  '/usr/bin/git commit -m wip'
flip "$WT_STALE" no-work-on-stale-branch.sh ALLOW BLOCK 'a commit on a stale branch, the name double quoted' \
  '"git" commit -m wip'
flip "$WT_STALE" no-work-on-stale-branch.sh ALLOW BLOCK 'a commit on a stale branch, the name behind a backslash' \
  '\git commit -m wip'
flip "$WT_STALE" no-work-on-stale-branch.sh ALLOW BLOCK 'a cherry-pick on a stale branch, as an absolute path' \
  '/usr/bin/git cherry-pick abc1234'
# The wrapper rule's second question, in this hook too. The pattern here names
# its own verb list and so is a fourth copy of the shape, and #117's widening
# has to reach all four or the claim is one hook short again.
flip "$WT_STALE" no-work-on-stale-branch.sh ALLOW BLOCK 'a wrapped commit on a stale branch, the name double quoted' \
  'bash -c '"'"'"git" commit -m wip'"'"''
check_in "$WT_WORK" no-work-on-stale-branch.sh ALLOW 'the same wrapped commit on a live branch, which decides nothing' \
  'bash -c '"'"'"git" commit -m wip'"'"''
# And the permitting half, in the worktree whose branch is still live, so that
# the reduction is not what decides the verdict here either.
check_in "$WT_WORK" no-work-on-stale-branch.sh ALLOW 'a commit on a live branch, as an absolute path' \
  '/usr/bin/git commit -m wip'
check_in "$WT_WORK" no-work-on-stale-branch.sh ALLOW 'a commit on a live branch, the name double quoted' \
  '"git" commit -m wip'

section "=== review of #111: the #94 comparison when it has nothing to compare, and its two copies ==="
# Three points from the review of the #94 pull request, each checked here.
#
# ONE. A --git-common-dir that will not resolve. no-git-push.sh refused it, which
# is the right direction, but through the main-checkout message, which is a claim
# it could not support on that path -- and the #94 pull request recorded the path
# as reached by no check. No repository reaches it: git that cannot find its
# common directory cannot find the repository either. So git is made to report
# one: a shim first on PATH answers --git-common-dir with a directory that does
# not exist and hands every other call to the real git. It is a fixture of the
# kind halflib is, a component made to fail one way at a time, and it is driven
# in the linked worktree, where a hook that read the unresolved path as a
# worktree would permit the push -- so the BLOCK there is the guard and nothing
# else.
REAL_GIT=$(command -v git)
GIT_SHIM="$FIXTURES/git-shim"
mkdir -p "$GIT_SHIM"
printf '#!/bin/bash\nfor a in "$@"; do\n  [ "$a" = --git-common-dir ] && { echo /nonexistent-111/.git; exit 0; }\ndone\nexec %s "$@"\n' \
  "$REAL_GIT" > "$GIT_SHIM/git"
chmod +x "$GIT_SHIM/git"
# Both halves of the shim, asserted: the one answer it fakes, and the answers it
# must not, or the checks below would be refused for a reason they do not name.
[ "$(cd "$PUSH_WT" && PATH="$GIT_SHIM:$PATH" git rev-parse --git-common-dir)" = /nonexistent-111/.git ] \
  && [ -d "$(cd "$PUSH_WT" && PATH="$GIT_SHIM:$PATH" git rev-parse --git-dir)" ] \
  && [ "$(cd "$PUSH_WT" && PATH="$GIT_SHIM:$PATH" git branch --show-current)" = "$PUSH_BRANCH" ] || {
  echo "the git shim does not fake --git-common-dir alone; the checks using it prove nothing" >&2
  exit 1
}
# A variable set in front of a function call reaches the processes it starts, so
# the hook check_in runs sees the shim first.
req GH-94.4
PATH="$GIT_SHIM:$PATH" check_in "$PUSH_WT" no-git-push.sh BLOCK \
  'an unresolvable --git-common-dir, in a linked worktree: a push of its own branch is refused' \
  "git push origin $PUSH_BRANCH"
PATH="$GIT_SHIM:$PATH" says "$PUSH_WT" no-git-push.sh 'could not be resolved' \
  'and the refusal says what it could not resolve' "git push origin $PUSH_BRANCH"
PATH="$GIT_SHIM:$PATH" says_not "$PUSH_WT" no-git-push.sh 'This is the main checkout' \
  'and does not claim this is the main checkout' "git push origin $PUSH_BRANCH"
# The stale guard abstains on the same path, as it always did on an empty one.
# In the stale worktree a guard that read the unresolved path as a worktree would
# refuse, so the ALLOW is the abstention.
req GH-94.4 GH-44.6
PATH="$GIT_SHIM:$PATH" check_in "$WT_STALE" no-work-on-stale-branch.sh ALLOW \
  'an unresolvable --git-common-dir, in a stale worktree: the guard abstains' \
  'git commit -m "wip"'
# Outside any repository --git-dir is empty too, and that was the main-checkout
# message as well. Guarded, because a directory that turned out to sit inside a
# repository would be refused for a different reason.
NOT_A_REPO="$FIXTURES/not-a-repo"
mkdir -p "$NOT_A_REPO"
! git -C "$NOT_A_REPO" rev-parse --git-dir >/dev/null 2>&1 || {
  echo "$NOT_A_REPO is inside a git repository; the checks using it prove nothing" >&2
  exit 1
}
req GH-94.4
check_in "$NOT_A_REPO" no-git-push.sh BLOCK 'outside any repository: a push is refused' \
  'git push origin feature-x'
says "$NOT_A_REPO" no-git-push.sh 'could not be resolved' \
  'and the refusal does not call it the main checkout' 'git push origin feature-x'

# TWO AND THREE. canonical_dir is a copy in each hook -- the stale guard compares
# before it loads lib/command-scan.sh, so a shared function would cost a library
# load on every git command -- and the behavioural checks above held the copies
# to one answer only at the cases they name. So the text is held too, the way the
# dev-branch derivation is: each file defines it once, the two are equal, and
# each is the function as pinned here.
#
# CDPATH is why the text matters. git prints `.git` at the root of a checkout,
# and `cd .git` looks that name up through CDPATH before the working directory,
# so a CDPATH holding a directory with a .git in it moved the cd somewhere else.
# No verdict ever turned on it -- both halves are `.git` at the root and moved
# alike, and below the root git prints ../.git or an absolute path, which CDPATH
# does not consult -- so no check that runs a hook can see it. The function is
# run on its own instead: extracted from each hook, evaluated in a subshell, and
# pointed at a decoy. That is not seam 1, and it is said so here rather than left
# to be noticed.
canonical_dir_text() {  # canonical_dir_text <file> -- the function, as written
  awk '/^canonical_dir\(\) \{$/ { f = 1 }
       f                        { print }
       f && /^\}$/              { exit }' "$1" 2>/dev/null
}
CANONICAL_DIR=$(cat <<'CANONICAL'
canonical_dir() {
  [ -n "$1" ] || return 1
  (CDPATH= cd -- "$1" >/dev/null 2>&1 && pwd -P)
}
CANONICAL
)
tok 'no-git-push.sh defines canonical_dir exactly once' \
    '1' "$(grep -c '^canonical_dir() {$' "$HOOKS/no-git-push.sh")"
tok 'and no-work-on-stale-branch.sh defines it exactly once' \
    '1' "$(grep -c '^canonical_dir() {$' "$HOOKS/no-work-on-stale-branch.sh")"
tok 'the two copies of canonical_dir are identical' \
    "$(canonical_dir_text "$HOOKS/no-git-push.sh")" \
    "$(canonical_dir_text "$HOOKS/no-work-on-stale-branch.sh")"
tok 'no-git-push.sh holds canonical_dir as pinned here' \
    "$CANONICAL_DIR" "$(canonical_dir_text "$HOOKS/no-git-push.sh")"
tok 'and no-work-on-stale-branch.sh does too' \
    "$CANONICAL_DIR" "$(canonical_dir_text "$HOOKS/no-work-on-stale-branch.sh")"

CDPATH_DECOY="$FIXTURES/cdpath-decoy"
mkdir -p "$CDPATH_DECOY/.git"
# The hazard reproduced before it is checked for: a plain cd at the fixture's
# root does follow CDPATH to the decoy. readlink rather than pwd -P for the
# expected paths, so the expectation is not read through the mechanism under
# test.
[ "$(export CDPATH="$CDPATH_DECOY"; cd "$PUSH_MAIN" && cd -- .git >/dev/null 2>&1 && pwd -P)" \
  = "$(readlink -f "$CDPATH_DECOY/.git")" ] || {
  echo "a plain cd does not follow CDPATH to the decoy here; the CDPATH checks prove nothing" >&2
  exit 1
}
canonical_dir_under_cdpath() {  # canonical_dir_under_cdpath <hook> -- .git at the push fixture's root
  (
    eval "$(canonical_dir_text "$HOOKS/$1")"
    export CDPATH="$CDPATH_DECOY"
    cd "$PUSH_MAIN" && canonical_dir .git
  )
}
tok 'no-git-push.sh: canonical_dir resolves .git in the working directory, not through CDPATH' \
    "$(readlink -f "$PUSH_MAIN/.git")" "$(canonical_dir_under_cdpath no-git-push.sh)"
tok 'no-work-on-stale-branch.sh: likewise' \
    "$(readlink -f "$PUSH_MAIN/.git")" "$(canonical_dir_under_cdpath no-work-on-stale-branch.sh)"

echo "--- abstaining when there is no active dev branch to compare against ---"
# A fresh clone, or the rotation window after the merged dev-NN is deleted and
# its successor is not yet pushed.
NODEV="$FIXTURES/nodev"
git init -q -b main "$NODEV"
GN="git -C $NODEV -c user.email=checks@example.invalid -c user.name=checks"
$GN remote add origin "$FIXTURES/unreachable-remote.git"
$GN commit -q --allow-empty -m base
NODEV_BASE=$($GN rev-parse HEAD)
$GN commit -q --allow-empty -m advance
$GN branch behind-branch "$NODEV_BASE"
$GN worktree add -q "$NODEV/wt-behind" behind-branch
$GN branch nodev-gone-branch "$NODEV_BASE"
$GN config -f "$NODEV/.git/config" branch.nodev-gone-branch.remote origin
$GN config -f "$NODEV/.git/config" branch.nodev-gone-branch.merge refs/heads/nodev-gone-branch
$GN worktree add -q "$NODEV/wt-nodev-gone" nodev-gone-branch
req GH-44.6
check_in "$NODEV/wt-behind" no-work-on-stale-branch.sh ALLOW 'no origin/dev-* ref, so the fallback abstains' \
  'git commit -m "wip"'
# The gone detector reads the remote's existence, not ancestry against a dev
# branch, so it is not the fallback and does not abstain with it. A branch whose
# remote half has been pruned away is merged whether or not this clone has ever
# seen a dev branch.
req GH-44.6 GH-44.1
check_in "$NODEV/wt-nodev-gone" no-work-on-stale-branch.sh BLOCK 'upstream gone still refuses with no dev ref' \
  'git commit -m "wip"'

echo "--- the two refusals say different things, because they know different things ---"
# `upstream: gone` fires only on the genuinely merged case, so it may say
# merged. The fallback cannot tell a merged branch from one cut before the dev
# branch moved, so it must not.
req GH-44.1
says "$WT_GONE"  no-work-on-stale-branch.sh 'has been merged' \
  'the gone refusal names the merge' 'git commit -m "wip"'
req GH-44.2
says "$WT_STALE" no-work-on-stale-branch.sh 'no work of its own' \
  'the fallback refusal is about state' 'git commit -m "wip"'
says_not "$WT_STALE" no-work-on-stale-branch.sh 'merged' \
  'the fallback refusal does not claim a merge' 'git commit -m "wip"'
# The deadlock the carve-out exists to avoid is named in the refusal that would
# otherwise cause it.
req GH-44.3 US-7
says "$WT_STALE" no-work-on-stale-branch.sh 'git merge origin/dev-05 is permitted' \
  'the fallback refusal says how to get out' 'git commit -m "wip"'

# The nolib and halflib checks for this hook, including the scoping that makes a
# healthy worktree ALLOW with no library at all, moved to the load-contract
# section at the foot of this suite. They were the only ones of their kind that
# covered every function a hook requires, and #84's finding was that the lesson
# stayed in this one file: keeping them here, where the three hooks that had it
# wrong have no section, is what let that happen.

section "=== REGRESSION: #69, a command name matched as a substring ==="
# First coverage of any kind for these two hooks. Neither sourced
# lib/command-scan.sh, so neither knew where a command word was, and the name
# matched as an argument and as prose. Every verdict here was measured on
# dev-05 at 7cb4891, where the six below were BLOCK -- ordinary greps and
# git log invocations, refused for naming the tool they search for.
req GH-69.1
check pytest-via-uv-group.sh ALLOW 'grep for pytest in the docs' \
  'grep -rn pytest docs/'
check pytest-via-uv-group.sh ALLOW 'grep for pytest after a pipe' \
  'ls tests/ | grep pytest'
check pytest-via-uv-group.sh ALLOW 'git log searching for pytest' \
  'git log --grep pytest'
check alembic-via-uv-group.sh ALLOW 'grep for alembic in the docs' \
  'grep -rn alembic docs/'
check alembic-via-uv-group.sh ALLOW 'git log searching for alembic' \
  'git log --grep alembic'
check alembic-via-uv-group.sh ALLOW 'prose naming the sanctioned invocation' \
  'echo "we run alembic upgrade head via the group"'
# The pair that made the old behaviour intermittent, kept side by side. Both
# were prose; the first was permitted only because a quote sat in front of the
# name and a quote is not in the separator class, and the second was refused
# because a space did. Same sentence shape, opposite verdicts. They are one
# verdict now, and it is the pair rather than either one that says so.
check pytest-via-uv-group.sh ALLOW 'prose, name straight after the quote' \
  'echo "pytest lives in the test group"'
check pytest-via-uv-group.sh ALLOW 'prose, name after a space' \
  'echo "we run pytest via the test group"'

section "=== the controls those two hooks are for, which keep their verdicts ==="
req GH-69.1
check pytest-via-uv-group.sh BLOCK 'bare pytest' \
  'pytest tests/'
check pytest-via-uv-group.sh BLOCK 'bare python -m pytest' \
  'python -m pytest tests/'
check pytest-via-uv-group.sh ALLOW 'the sanctioned invocation' \
  'uv run --group test pytest tests/'
check pytest-via-uv-group.sh ALLOW 'make test, which is that invocation' \
  'make test'
check alembic-via-uv-group.sh BLOCK 'bare alembic' \
  'alembic upgrade head'
check alembic-via-uv-group.sh BLOCK 'bare alembic as the second command' \
  'cd x && alembic upgrade head'
check alembic-via-uv-group.sh ALLOW 'the sanctioned invocation' \
  'uv run --group migrations alembic upgrade head'
# A command word is a command word wherever cs_split finds one. These are the
# shapes that library was written for, asked of these two hooks for the first
# time.
check pytest-via-uv-group.sh BLOCK 'bare pytest behind a wrapper word' \
  'sudo pytest tests/'
check pytest-via-uv-group.sh BLOCK 'bare pytest behind a wrapper with an operand' \
  'timeout 30 pytest tests/'
check pytest-via-uv-group.sh BLOCK 'bare pytest after a control word' \
  'if true; then pytest tests/; fi'
check pytest-via-uv-group.sh ALLOW 'the sanctioned invocation behind a wrapper' \
  'timeout 300 uv run --group test pytest tests/'
check pytest-via-uv-group.sh ALLOW 'and behind a wrapper whose option takes a value' \
  'sudo -u me uv run --group test pytest tests/'

section "=== #69, what the deleted allowlist covered, asked of the rule that replaced it ==="
req GH-69.1
# The allowlist is gone: with the command word at ^, `uv run --group test
# pytest` never matches the first rule, so there was nothing left to rescue.
# But `uv run pytest` was refused by it and has to stay refused -- it runs
# pytest outside the group, which is the failure these hooks are about. The
# group is asked for on the `uv run` fragment now rather than anywhere on the
# line, which is the part the allowlist got wrong and which the last two of
# these pin.
check pytest-via-uv-group.sh BLOCK 'uv run reaching pytest with no group named' \
  'uv run pytest tests/'
check pytest-via-uv-group.sh BLOCK 'uv run naming the wrong group' \
  'uv run --group dev pytest tests/'
check pytest-via-uv-group.sh BLOCK 'uv run reaching python -m pytest with no group' \
  'uv run python -m pytest tests/'
check alembic-via-uv-group.sh BLOCK 'uv run reaching alembic with no group named' \
  'uv run alembic upgrade head'
check pytest-via-uv-group.sh ALLOW 'uv run naming the group, reaching python -m pytest' \
  'uv run --group test python -m pytest tests/test_chunker.py'
# uv subcommands that are not `run` install or add a package rather than
# running one, and naming pytest is what they are for.
check pytest-via-uv-group.sh ALLOW 'uv pip install, which is not uv run' \
  'uv pip install pytest'
check pytest-via-uv-group.sh ALLOW 'uv add, which is not uv run' \
  'uv add --group test pytest'
check alembic-via-uv-group.sh ALLOW 'uv add, which is not uv run' \
  'uv add --group migrations alembic'

section "=== REGRESSION: review of #69, ^ narrowed the guard to one runner ==="
req GH-69.1
# The first version of the rule above asked only about `uv run`, and review
# measured five silent permits against the file it replaced: each of these was
# BLOCK before the migration, by the substring match, and ALLOW after it. Each
# really does run the tool outside the group, which is the failure these hooks
# are for. A runner is a runner however it is spelled, and the list in the
# hooks is checked member by member here rather than read and believed.
check pytest-via-uv-group.sh BLOCK 'poetry run' 'poetry run pytest tests/'
check pytest-via-uv-group.sh BLOCK 'uvx'        'uvx pytest'
check pytest-via-uv-group.sh BLOCK 'uv tool run' 'uv tool run pytest'
check pytest-via-uv-group.sh BLOCK 'hatch run'  'hatch run pytest'
check pytest-via-uv-group.sh BLOCK 'pdm run'    'pdm run pytest'
check pytest-via-uv-group.sh BLOCK 'pipenv run' 'pipenv run pytest'
check pytest-via-uv-group.sh BLOCK 'rye run'    'rye run pytest'
check pytest-via-uv-group.sh BLOCK 'conda run'  'conda run pytest'
check pytest-via-uv-group.sh BLOCK 'nix run'    'nix run pytest'
check alembic-via-uv-group.sh BLOCK 'poetry run, alembic' 'poetry run alembic upgrade head'
check alembic-via-uv-group.sh BLOCK 'uvx, alembic'        'uvx alembic upgrade head'

section "=== REGRESSION: review of the #69 PR, the list stopped one family early ==="
req GH-69.1
# Review of the fix above found three more, each the sibling of something
# already on the list: pipx run beside uvx and uv tool run, micromamba run
# beside conda run, pixi run beside poetry run. All three were BLOCK on dev-05
# by the substring match and ALLOW once the rule became a list. Recorded as the
# same finding twice, because that is what it is: narrowing a substring match
# to a list costs whatever the list omits, and what it omits is found by
# someone asking rather than by the rule.
check pytest-via-uv-group.sh BLOCK 'pipx run'       'pipx run pytest'
check pytest-via-uv-group.sh BLOCK 'micromamba run' 'micromamba run pytest'
check pytest-via-uv-group.sh BLOCK 'pixi run'       'pixi run pytest'
check alembic-via-uv-group.sh BLOCK 'pipx run, alembic'       'pipx run alembic upgrade head'
check alembic-via-uv-group.sh BLOCK 'micromamba run, alembic' 'micromamba run alembic upgrade head'
check alembic-via-uv-group.sh BLOCK 'pixi run, alembic'       'pixi run alembic upgrade head'

section "=== ACCEPTED gap: a wrapper word is not a runner, and belongs in #79 ==="
req GH-69.1 GH-79.3
# These two reach pytest as well, and neither is a runner in the sense the list
# above means: they take no subcommand and simply run the words after them,
# which is what cs_split calls a wrapper word and already strips for `time`,
# `sudo` and the rest. Naming them in the runner list would answer "what is a
# wrapper word" in a third place -- the habit lib/command-scan.sh exists to end
# -- and would fix these two hooks while leaving the four boundary hooks just
# as blind to `xvfb-run git push --all origin`.
#
# So they are pinned as permitted rather than fixed here, and the pin is the
# point: when #79 adds them to cs_split's wrapper list these two flip to BLOCK,
# and that is the intended outcome rather than a regression. Change them there.
check pytest-via-uv-group.sh ALLOW 'xvfb-run, a wrapper word cs_split does not strip' \
  'xvfb-run pytest tests/'
check pytest-via-uv-group.sh ALLOW 'watch, the same shape' \
  'watch pytest'
# The contrast that says why those two are a wrapper question and not a runner
# question: a wrapper word cs_split DOES strip leaves the command word at ^,
# and the first rule refuses it with no list involved.
check pytest-via-uv-group.sh BLOCK 'time, which cs_split does strip' \
  'time pytest tests/'

section "=== REGRESSION: #69, the allowlist was matched against the whole string ==="
req GH-69.1
# Not named in the PR body, and a silent permit on dev-05 rather than a false
# refusal: the old allowlist asked whether `uv run ... --group test` appeared
# anywhere in the command, so one sanctioned invocation rescued a bare one
# beside it, and a `cd` in front of a bare one did too. Both were ALLOW there.
# cs_split judges each command on its own, so neither rescue survives.
check pytest-via-uv-group.sh BLOCK 'a cd in front of a bare pytest' \
  'cd tests && pytest'
check pytest-via-uv-group.sh BLOCK 'a sanctioned invocation rescuing a bare one' \
  'uv run --group test pytest && pytest tests/'
check alembic-via-uv-group.sh BLOCK 'the same rescue, alembic' \
  'uv run --group migrations alembic upgrade head && alembic downgrade -1'

section "=== REGRESSION: review of #69, the group was matched after the tool ==="
req GH-69.1
# `--group test` was looked for anywhere in the fragment, so the tool's own
# argument rescued the command and the comment claiming the group had to be
# named by the runner was false. It is named before the tool now: the fragment
# is cut at the name and only what precedes it is searched. Both were ALLOW.
check pytest-via-uv-group.sh BLOCK 'the group as an argument of pytest' \
  'uv run pytest --group test'
check alembic-via-uv-group.sh BLOCK 'the group as an argument of alembic' \
  'uv run alembic upgrade head --group migrations'

section "=== REGRESSION: review of #69, the intermittency survived inside the rule ==="
req GH-69.1
# The same quote-versus-space split the migration was supposed to end, one rule
# further down: the second rule re-matched the name as an argument with a
# whitespace-only boundary, so `uv run echo "pytest ..."` was ALLOW or BLOCK
# according to which character preceded the name. A quote is a word boundary
# now and the pair agrees. It agrees in the refusing direction, which is the
# trade the hook's header states: treating quoted text as data would permit
# `uv run "pytest"`, and that really does run pytest.
check pytest-via-uv-group.sh BLOCK 'runner, name straight after the quote' \
  'uv run echo "pytest lives in the test group"'
check pytest-via-uv-group.sh BLOCK 'runner, name after a space' \
  'uv run echo "we run pytest via the test group"'
# The pair the issue reported is at top level, where no rule here reaches it,
# and it stays permitted. Both halves, because it was the disagreement rather
# than either verdict that was the defect.
check pytest-via-uv-group.sh ALLOW 'prose is still prose, name after the quote' \
  'echo "pytest lives in the test group"'
check pytest-via-uv-group.sh ALLOW 'prose is still prose, name after a space' \
  'echo "we run pytest via the test group"'

section "=== ACCEPTED gap: #69, these two carry no wrapper rule ==="
req GH-69.1
# The four boundary hooks refuse a wrapped command outright, because nothing
# can be read out of a quoted payload. These two do not, and both verdicts
# below were ALLOW before this change as well -- by accident rather than by
# decision, on the same quote that made the prose pair above disagree. It stays
# a gap rather than becoming a rule: CLAUDE.md's boundary is what a wrapper
# rule protects, and a dependency group is a convention, so refusing every
# `bash -c` in the repository would cost more than the convention is worth.
check pytest-via-uv-group.sh ALLOW 'a wrapped bare pytest is not read' \
  'bash -c "pytest tests/"'
check alembic-via-uv-group.sh ALLOW 'a wrapped bare alembic is not read' \
  'sh -c "alembic upgrade head"'

# What these two do when lib/command-scan.sh is not loadable is checked in the
# load-contract section at the foot of this suite, with the same question asked of
# every file that sources the tokeniser. #69 asked it here, of these two, with its
# own fixtures and for one of the two functions each calls; #84 found the same
# question answered three ways in the four boundary hooks at the same time. One
# question, one place -- and cs_split, which had no fixture here, has one there.

section "=== append-only: which docs directories are guarded, and which are not ==="
# First coverage for append-only-docs.sh and its Edit/Write companion. It was
# added with issue #61, which put a comment in both files saying docs/research/
# is deliberately outside the guarded set -- and a comment is not evidence. The
# refusing direction is checked alongside it, because an ALLOW for research/
# that came from the guard having stopped working altogether would look
# identical to the one intended.
req GH-69.2
check append-only-docs.sh BLOCK 'sed -i over a dev-log entry' \
  "sed -i 's/a/b/' docs/dev-log/devlog_2026-08-25_session-2.md"
check append-only-docs.sh BLOCK 'rm of an eval report' \
  'rm docs/eval-reports/some-report.md'
check append-only-docs.sh BLOCK 'truncating redirect into a lessons-learned entry' \
  'echo x > docs/lessons-learned/some-lesson.md'
check append-only-docs.sh ALLOW 'appending to a dev-log entry' \
  'echo x >> docs/dev-log/devlog_2026-08-25_session-2.md'
req GH-69.2
check append-only-docs.sh ALLOW 'sed -i over a research document' \
  "sed -i 's/a/b/' docs/research/non-openrouter-response-bodies.md"
check append-only-docs.sh ALLOW 'sed -i over a design document' \
  "sed -i 's/a/b/' docs/design/llm-call-log.md"

section "=== REGRESSION: #69, the whole-directory case the slash hid ==="
# The pattern required a trailing slash, so the outer guard never fired on the
# directory itself and the removal that destroys the most history was the one
# that passed. Every verdict here was measured on dev-05 at 7cb4891, where the
# first four were ALLOW. The fifth is the control they sit one character away
# from, and it was already BLOCK: same command, opposite verdict, on a
# difference that has nothing to do with what it would run.
req GH-69.2
check append-only-docs.sh BLOCK 'rm -rf of the dev-log directory, no trailing slash' \
  'rm -rf docs/dev-log'
check append-only-docs.sh BLOCK 'rm -rf of the lessons-learned directory' \
  'rm -rf docs/lessons-learned'
check append-only-docs.sh BLOCK 'rm -rf of the eval-reports directory' \
  'rm -rf docs/eval-reports'
check append-only-docs.sh BLOCK 'mv of the dev-log directory out from under its name' \
  'mv docs/dev-log docs/archive'
check append-only-docs.sh BLOCK 'the control it is one character from' \
  'rm -rf docs/dev-log/'
# The issue's other control on this rule. An equivalent shape is pinned above
# on docs/eval-reports/, and it is written out here as well because stage 3
# asked for the verdicts as the issue measured them: an equivalent is evidence
# about the rule, and the line is evidence about the report.
check append-only-docs.sh BLOCK 'rm of a single dev-log entry' \
  'rm docs/dev-log/x.md'
# The boundary is written out rather than made optional, because a directory
# whose name merely starts with a guarded one is a different directory. These
# two are what would break if the fix had been `/?`.
check append-only-docs.sh ALLOW 'a directory whose name only begins with a guarded one' \
  'rm -rf docs/dev-logbook'
check append-only-docs.sh ALLOW 'a sibling file whose name begins with a guarded one' \
  'rm docs/dev-log.bak'
check append-only-docs.sh ALLOW 'reading the directory is not removing it' \
  'ls docs/dev-log'

section "=== REGRESSION: review of #69, the spellings the Bash side still compared ==="
req GH-69.2
# The Edit companion was normalised and this one was not, so the same finding
# stood on this side of the pair: a spelling a shell reduces to the guarded
# directory was permitted. All four were ALLOW after the first fix. Nothing
# here can normalise the way the companion does -- the path is embedded in a
# command rather than handed over as one -- so the two spellings a reader
# actually writes are matched where they stand, and `docs/foo/../dev-log`
# stays permitted, which the hook's comment says in as many words.
check append-only-docs.sh BLOCK 'a doubled slash before the directory' \
  'rm -rf docs//dev-log'
check append-only-docs.sh BLOCK 'a dot segment before the directory' \
  'rm -rf docs/./dev-log'
check append-only-docs.sh BLOCK 'a doubled slash on the truncate route' \
  'truncate -s 0 docs//dev-log/x.md'
check append-only-docs.sh BLOCK 'a dot segment on the in-place edit route' \
  'sed -i s/a/b/ docs/./dev-log/x.md'
# What that widening must not swallow. `docs` and the directory name have to
# stay two path segments with only slashes and dot segments between them.
check append-only-docs.sh ALLOW 'no separator at all is a different name' \
  'rm -rf docsdev-log'
check append-only-docs.sh ALLOW 'a hyphen is not a path separator' \
  'rm -rf other/docs-dev-log'

section "=== REGRESSION: #69, overwriting an entry without naming a redirect ==="
req GH-69.2
# Both routes overwrite an existing entry in place and neither was reached by
# the rm/mv/cp list or by the redirect rule, so both were ALLOW at 7cb4891.
# The third is the control that was already BLOCK.
check append-only-docs.sh BLOCK 'truncate over a dev-log entry' \
  'truncate -s 0 docs/dev-log/devlog_2026-08-25_session-2.md'
check append-only-docs.sh BLOCK 'tee over a dev-log entry' \
  'tee docs/dev-log/devlog_2026-08-25_session-2.md < new.md'
check append-only-docs.sh BLOCK 'the control it sits beside' \
  ': > docs/dev-log/devlog_2026-08-25_session-2.md'

section "=== ACCEPTED false positive: #69, tee -a appends and is refused anyway ==="
req GH-69.2
# The verb is read and its options are not, so the appending spelling of tee
# goes with the truncating one. `>>` is the documented way to append and stays
# permitted, which is the check beneath this one. Written down because a fix
# that gives up a case has to say which case.
check append-only-docs.sh BLOCK 'tee -a, which appends, refused with the rest of tee' \
  'tee -a docs/dev-log/devlog_2026-08-25_session-2.md < new.md'
check append-only-docs.sh ALLOW 'the append that is documented is still permitted' \
  'echo x >> docs/dev-log/devlog_2026-08-25_session-2.md'

# The Edit/Write companion reads tool_input.file_path rather than .command, and
# its verdict turns on whether the file already exists -- so it is asked about
# real paths in this repository, with CLAUDE_PROJECT_DIR naming the root it
# anchors to. A new seam in this suite, named as one.
REPO_ROOT=$(cd "$SUITE_DIR/../.." && pwd)
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
# They are up here with the others rather than in that section because the #98
# self-test below drives every helper that reads a hook's exit status, and a
# function defined after it has not been defined when it runs.
env_feed() {  # env_feed <dir> <PATH> <script|/absolute/hook> <ALLOW|BLOCK> <label> <raw stdin>
  local dir="$1" path="$2" script="$3" want="$4" label="$5" payload="$6" rc err hook
  hook=$(hook_path "$script")
  err=$(printf '%s' "$payload" \
        | ( cd "$dir" && PATH="$path" CLAUDE_PROJECT_DIR="$REPO_ROOT" "$hook" ) 2>&1 >/dev/null)
  rc=$?
  ran "$script" "$rc"
  verdict "$want" "$rc" "$err" "$label"
}
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
  # A copy of the registered report, placed in a fixture repository because the
  # report reads the repository it sits in; the #98 self-test's crashing
  # fixtures carry other names. Recorded after the run, and by name rather than
  # through `hook_path`, which never sees this one. See `ran`.
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
# one question none of them can ask. It is defined here, with the others, because
# the #98 self-test below drives it and runs before #109's section does.
#
# The failure line names every hook that did not exit 0, each with its status and
# its stderr in the spelling `verdict` uses, since the case it exists for is a
# second hook refusing what the first permits and the name is the whole finding.
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

# An ALLOW that came from the path simply not being there would say nothing
# about docs/research/, and a BLOCK-expecting case needs its file present for
# the same reason. Both are asserted rather than assumed.
[ -e "$REPO_ROOT/docs/dev-log/devlog_2026-08-25_session-2.md" ] \
  && [ -e "$REPO_ROOT/docs/dev-log/README.md" ] \
  && [ -e "$REPO_ROOT/docs/research/non-openrouter-response-bodies.md" ] || {
  echo "the append-only Edit cases name files that are not there; they would prove nothing" >&2
  exit 1
}
req GH-69.3
check_file append-only-docs-edit.sh BLOCK 'Edit of an existing dev-log entry' \
  'docs/dev-log/devlog_2026-08-25_session-2.md'
check_file append-only-docs-edit.sh ALLOW 'Write of a dev-log entry not yet there' \
  'docs/dev-log/devlog_2099-01-01_session-1.md'
check_file append-only-docs-edit.sh ALLOW 'Edit of a dev-log README that does exist' \
  'docs/dev-log/README.md'
req GH-69.3
check_file append-only-docs-edit.sh ALLOW 'Edit of an existing research document' \
  'docs/research/non-openrouter-response-bodies.md'

section "=== REGRESSION: #69, a spelling of the path that was not the literal prefix ==="
# The root was stripped by string prefix and the remainder anchored at ^docs/,
# so the comparison was between spellings rather than between paths. The first
# two were ALLOW at 7cb4891, on a file that exists. A leading ./ is not an
# evasion -- it is an ordinary way to write a relative path, which is the shape
# of the ordinary mistake this hook is for. The absolute spelling is the
# control that already worked.
req GH-69.3
check_file append-only-docs-edit.sh BLOCK 'Edit of an existing entry written with a leading ./' \
  './docs/dev-log/devlog_2026-08-25_session-2.md'
check_file append-only-docs-edit.sh BLOCK 'Edit of an existing entry reached through ..' \
  'docs/../docs/dev-log/devlog_2026-08-25_session-2.md'
check_file append-only-docs-edit.sh BLOCK 'Edit of an existing entry with a doubled slash' \
  'docs//dev-log/devlog_2026-08-25_session-2.md'
check_file append-only-docs-edit.sh BLOCK 'Edit of an existing entry, absolute spelling' \
  "$REPO_ROOT/docs/dev-log/devlog_2026-08-25_session-2.md"
# Normalising must not widen the guarded set: the directories left out of it
# stay out however the path is written, and a new entry stays writable.
check_file append-only-docs-edit.sh ALLOW 'Edit of a research document written with a leading ./' \
  './docs/research/non-openrouter-response-bodies.md'
check_file append-only-docs-edit.sh ALLOW 'Write of a new entry written with a leading ./' \
  './docs/dev-log/devlog_2099-01-01_session-1.md'
check_file append-only-docs-edit.sh ALLOW 'Edit of a README written with a leading ./' \
  './docs/dev-log/README.md'

section "=== the arming properties, asserted as literals ==="
# A second kind of check: the ones above drive a hook as a process and read its
# exit code, and these read a file. It is a new seam in this suite and is named
# as one.
#
# It exists because report-stale-branches.sh arms enforcement rather than
# performing it. Issue #36 leaves `.claude/` unguarded on the grounds that
# breakage announces itself -- the refusal stops coming -- and that reasoning
# does not hold for a file whose failure is that two detectors quietly read
# stale refs. Dropping --prune from that script changes nothing visible, so
# these say what must be true of it.
#
# This announces at the next review rather than on the next push: the repository
# has no CI, so the suite runs when someone runs it. That is how every check
# above already behaves.
req GH-44.7 FR-40
armed 'the report fetches with an explicit prune' \
  "$HOOKS/report-stale-branches.sh" 'git fetch --prune --quiet origin'
armed 'the fetch is bounded, so an offline session still starts' \
  "$HOOKS/report-stale-branches.sh" 'timeout "$FETCH_TIMEOUT" git fetch'
armed 'a failed fetch says so, because neither detector is armed after one' \
  "$HOOKS/report-stale-branches.sh" 'FAILED or timed out'

# THE MERGE SETTINGS, READ RATHER THAN RECORDED. Both detectors rest on a
# repository setting no bash hook can assert, so #36's Amendment recorded the
# three values in prose -- "these have no check behind them and this map plus
# the guard's header are their only durable record." Why that was the wrong
# answer is argued in no-work-on-stale-branch.sh's header and is not retold
# here; the pins below hold it where it now lives.
#
# Be exact about what these are: pins on the report's code, in the same manner
# as the fetch pins above. They are not evidence about the repository's
# settings and cannot be. Nothing in `.claude/` can be that evidence, and a
# file claiming to be is the defect these replace.
req FR-41 FR-43 GH-71
armed 'the report reads the merge settings rather than trusting a record of them' \
  "$HOOKS/report-stale-branches.sh" "gh api 'repos/{owner}/{repo}'"
armed 'and reads all three the branch lifecycle rule depends on' \
  "$HOOKS/report-stale-branches.sh" \
  '[.allow_squash_merge, .allow_rebase_merge, .delete_branch_on_merge]'
req FR-42 FR-43
armed 'the settings read is bounded, so an unreachable API still starts the session' \
  "$HOOKS/report-stale-branches.sh" 'timeout "$SETTINGS_TIMEOUT" gh api'
armed 'a settings read that did not happen says so, rather than reading as fine' \
  "$HOOKS/report-stale-branches.sh" 'merge settings: NOT READ'
# And a read that half happened is not reported as a read that disagreed. The
# per-setting line was already careful to say "was not reported by the API"; the
# heading over it said DRIFTED, which is what a skimmer takes away. Found on
# review of PR #77, not by this suite -- the pins above all stayed green,
# because each one asks about a line and none asks what the lines are filed
# under.
req FR-41 FR-42
armed 'an unread setting is reported as unknown, not as a changed one' \
  "$HOOKS/report-stale-branches.sh" 'merge settings: NOT FULLY READ'
armed 'and the DRIFTED heading is reached only by a value that came back wrong' \
  "$HOOKS/report-stale-branches.sh" 'if [ -n "$MISMATCHED" ]; then'
# Neither of those two notices the mutation that matters most here, which adds
# a line rather than removing one: setting MISMATCHED on the unread arm as well
# puts an unknown back under the DRIFTED heading, and both pins above stayed
# green through it -- measured on this branch, not reasoned. `armed` asks
# whether a literal is somewhere in a file and cannot ask what else is there.
# So the arm is extracted and compared as a string, the way the dev derivation
# is, that being the only shape of pin here that sees an addition.
UNREAD_ARM=$(cat <<'ARM'
    ''|null) DRIFTED="$DRIFTED
  $1 was not reported by the API; the rule requires $3 -- otherwise $4" ;;
ARM
)
tok 'the unread arm records a gap without also calling it a mismatch' \
    "$UNREAD_ARM" "$(unread_arm "$HOOKS/report-stale-branches.sh")"
# What the pins above are worth, measured rather than reasoned: commenting out
# the read turns the first and the third red and leaves the second -- the
# settings list -- green, because `armed` strips from a `#` on the line it is
# reading and the jq filter sits on a continuation line that no one commented.
# That is why the read and its bound are pinned on their own line rather than
# the settings list being trusted to stand for all three.
#
# The required values, one line each, because the read alone says nothing about
# what it is compared against -- and a fixed string spanning two lines is
# satisfied by a file holding either one, measured on a two-line fixture for the
# derivation pins below.
req FR-41 FR-43
armed 'squash merging must be off, or the fallback detector is unsound' \
  "$HOOKS/report-stale-branches.sh" 'drift allow_squash_merge "$SQUASH" false'
armed 'rebase merging must be off, for the same reason' \
  "$HOOKS/report-stale-branches.sh" 'drift allow_rebase_merge "$REBASE" false'
armed 'and delete_branch_on_merge must be on, which is what the gone detector reads' \
  "$HOOKS/report-stale-branches.sh" 'drift delete_branch_on_merge "$DELETE" true'
# The guard's end of it. Its header carried the value in prose and drifted
# twice; what replaces that is a pointer to the read above, and a pointer is the
# thing a later edit deletes on its way to writing a value back down. `written`
# rather than `armed`: this is prose in a comment, which is the whole of what it
# asserts, and stripping comments would erase the line rather than a remark.
req FR-44 GH-71
written 'and the guard points at that report instead of recording a value itself' \
  "$HOOKS/no-work-on-stale-branch.sh" 'That report is the live answer, and'
# And the same counting the dev-branch argument gets below, for the same reason
# and against the same failure. This history is the one thing in the change that
# is prose rather than code, which is what the last two records of it were --
# a third copy would be the defect the ticket is about, arriving inside its own
# fix. It is told in the guard, counted at one there and at zero in the report,
# and the report carries the pointer instead. This suite tells it nowhere, so
# there is nothing here to count: a literal written out below would count
# itself.
HISTORY='it asserted both settings disabled before they were'
tok 'the history of the recorded version is told in the guard, once' \
    '1' "$(prose_count "$HOOKS/no-work-on-stale-branch.sh" "$HISTORY")"
tok 'and the report does not tell it a second time' \
    '0' "$(prose_count "$HOOKS/report-stale-branches.sh" "$HISTORY")"
written 'the report says where that argument lives instead' \
  "$HOOKS/report-stale-branches.sh" "is in no-work-on-stale-branch.sh's header"
# What these six pins are NOT evidence of, named because the suite is evidence
# about the cases it names and nothing else: they read the call sites, not
# `drift` itself. Mutate that function to return early and all six stay green.
# Pinning its body was considered and rejected -- the only seam that would drive
# it is sourcing the report, and sourcing the report runs the fetch.
# Read-only by name and by content. The name is checked by being the path above;
# the content is checked here.
req GH-44.7
unarmed 'the report removes no worktree' \
  "$HOOKS/report-stale-branches.sh" 'worktree remove'
unarmed 'the report deletes no branch' \
  "$HOOKS/report-stale-branches.sh" 'branch -d'
unarmed 'the report force-deletes no branch' \
  "$HOOKS/report-stale-branches.sh" 'branch -D'
unarmed 'the report deletes nothing on the remote' \
  "$HOOKS/report-stale-branches.sh" 'push origin --delete'

# The active dev branch is derived in both files, and the copies are identical
# by hand. lib/command-scan.sh's own header names this failure mode -- the same
# question answered differently in a different place -- and the library is right
# there, so the duplication is a decision and not an oversight: the guard must
# read its state before it may depend on lib/ at all. That is what lets it fail
# closed only on a branch it has an opinion about, rather than refusing every
# command in every worktree whenever a library is missing. The cost of that
# ordering is two copies, so the copies are pinned instead of shared. A
# divergence here silently unarms the guard or misreports the branch.
#
# Issue #62: that pin used to be `armed` against the tail of the pipeline,
# "| grep -E ... | sort -V | tail -1)". Everything left of the first pipe -- the
# command, the --format, and the ref glob 'refs/remotes/origin/dev-*' -- was
# pinned in neither file, and the glob is the half most likely to move: it is
# what keeps origin/dev-foo and origin/dev-05-backup from winning, so a change
# to which refs count is a change to it. Changing the glob in one file only left
# the whole suite green, the second of those two checks labelled "derives it
# identically".
#
# Extending that literal to both lines would not have closed it. `armed` is
# grep -qF, and grep reads a pattern containing a newline as two patterns, so a
# two-line fixed string is satisfied by a file holding either line alone --
# measured on a two-line fixture, not assumed. The derivations are extracted and
# compared as strings instead, three ways: each file holds exactly one, the two
# are equal to each other, and each is the derivation as pinned here. The counts
# ask a question `armed` cannot ask at all -- it wants a constant somewhere in a
# file, so a second derivation added to either file would have been satisfied by
# the first -- and they are what closes the case, because two files that both
# extract to nothing are equal to each other and to nothing else.
#
# Be exact about which of the three carry the weight: with both files pinned to
# the literal, the guard-equals-report check follows by transitivity and proves
# nothing the pins do not. It is kept as the one line that states the property
# the duplication actually needs, and because it is the check that still holds
# the two together the day someone re-pins the literal on purpose -- a
# coordinated change turns both pins red and leaves it green, which is the pair
# of answers that says what happened. Each of the five was mutated to confirm it
# fails for its own reason, and the two counts were mutated to confirm they fail
# for theirs.
DEV_DERIVATION=$(cat <<'DERIVATION'
DEV=$(git for-each-ref --format='%(refname:short)' 'refs/remotes/origin/dev-*' 2>/dev/null \
      | grep -E '^origin/dev-[0-9]+$' | sort -V | tail -1)
DERIVATION
)
GUARD_DERIVATION=$(dev_derivation "$HOOKS/no-work-on-stale-branch.sh")
REPORT_DERIVATION=$(dev_derivation "$HOOKS/report-stale-branches.sh")
req GH-62
tok 'the guard reads the dev refs in exactly one place' \
    '1' "$(dev_read_count "$HOOKS/no-work-on-stale-branch.sh")"
tok 'and the report reads them in exactly one place' \
    '1' "$(dev_read_count "$HOOKS/report-stale-branches.sh")"
tok 'the guard and the report derive the active dev branch identically' \
    "$GUARD_DERIVATION" "$REPORT_DERIVATION"
tok 'the guard derives it as pinned here, glob and --format included' \
    "$DEV_DERIVATION" "$GUARD_DERIVATION"
tok 'and the report derives it as pinned here too' \
    "$DEV_DERIVATION" "$REPORT_DERIVATION"

# The filter and the version sort were argued twice, in different words, at the
# head of each file, and nothing held those two to each other either: correct
# one and the other goes on asserting the superseded reason, which CLAUDE.md
# counts as a defect in its own right. The argument is made once now, in
# no-work-on-stale-branch.sh's header, and each file carries the same one-line
# pointer to the pairing in place of its own copy of the reasoning. The pointer
# is one line because grep is: a literal spanning a line break would match
# neither file.
PAIRING='check-hooks.sh holds the two equal, so a change here is a change there'
beside 'the guard names the pairing beside its derivation' \
  "$HOOKS/no-work-on-stale-branch.sh" "$PAIRING"
beside 'and the report names it identically' \
  "$HOOKS/report-stale-branches.sh" "$PAIRING"
# A pointer to an argument is worth what the argument is worth, and the report's
# now points at prose in another file. Two ways that goes wrong, and the second
# is the one this branch would otherwise have left open.
#
# Delete the guard's header and the report cites a reason no longer written
# anywhere: the stale-docstring defect moved rather than fixed. Re-add a second
# copy to the report and the defect is back exactly as it was -- two arguments,
# nothing holding them to each other -- which is what the report's own new
# comment says is wrong: "a second copy of an argument goes stale in silence
# when the first one is corrected." The code duplication got a count for that
# reason; the prose duplication fixed in the same breath did not, and the
# asymmetry was the gap. Both directions are counted now, the same shape as the
# two counts above, and both halves of the claim are in the literal.
#
# The limit is the one the counts above have: this finds the argument as
# written, so a reworded second copy is a second copy uncounted.
ARGUMENT='sort makes dev-09 beat dev-10, and an unfiltered glob lets origin/dev-foo'
tok 'the argument the report points at is made in the guard, once' \
    '1' "$(prose_count "$HOOKS/no-work-on-stale-branch.sh" "$ARGUMENT")"
tok 'and the report does not argue it a second time' \
    '0' "$(prose_count "$HOOKS/report-stale-branches.sh" "$ARGUMENT")"
# And the sentence that does the pointing: without it the report holds a bare
# pairing pointer and no trace of where its reasoning went. `beside` rather than
# `written`, because a pointer that is not beside the derivation is not doing
# the job the pointer exists for -- the same standard the pairing line is held
# to four lines above.
POINTER="no-work-on-stale-branch.sh's header, rather than twice here in different words"
beside 'the report says where the argument was moved to' \
  "$HOOKS/report-stale-branches.sh" "$POINTER"

# The carve-out's identity test, pinned as three lines rather than driven as a
# process. Two of them are driven, by the diverged and no-local fixtures above;
# the third -- an unresolvable dev tip -- is not reachable by running this hook,
# because the ancestry read fails first and the file abstains.
#
# The guard line is also redundant with the comparison that follows it, and the
# first version of this suite claimed otherwise -- that dropping it would let an
# empty TOK_OID equal an empty DEV_OID. That was false: the rev-parse above the
# comparison returns on failure and prints an OID on success, so TOK_OID is
# never empty there. What these three lines pin is that the identity test is
# spelled the way the file says it is; they are not evidence that any one of
# them decides an outcome, and the middle one does not.
req GH-58.2
armed 'the dev tip is resolved to a commit, from the ref the ancestry was read against' \
  "$HOOKS/no-work-on-stale-branch.sh" \
  'DEV_OID=$(git rev-parse --verify --quiet "refs/remotes/$DEV^{commit}" 2>/dev/null)'
armed 'an unresolvable dev tip withdraws the carve-out rather than widening it' \
  "$HOOKS/no-work-on-stale-branch.sh" '[ -n "$DEV_OID" ] || return 1'
armed 'and a whitelisted spelling must resolve to that same commit' \
  "$HOOKS/no-work-on-stale-branch.sh" '[ "$TOK_OID" = "$DEV_OID" ]'

# settings.json is what actually runs either file, so a hook present in the tree
# and absent from the configuration is a hook that does nothing. jq reads it;
# the expectation is a literal.
SETTINGS="$SUITE_DIR/../settings.json"
req GH-44.7 FR-40
tok 'settings.json runs the report at SessionStart' \
    '"$CLAUDE_PROJECT_DIR"/.claude/hooks/report-stale-branches.sh' \
    "$(jq -r '.hooks.SessionStart[]?.hooks[]?.command' "$SETTINGS" 2>/dev/null | grep report-stale-branches)"
tok 'settings.json runs the guard on every Bash command' \
    '"$CLAUDE_PROJECT_DIR"/.claude/hooks/no-work-on-stale-branch.sh' \
    "$(jq -r '.hooks.PreToolUse[]? | select(.matcher == "Bash") | .hooks[]?.command' "$SETTINGS" 2>/dev/null | grep no-work-on-stale-branch)"
# The report's timeout must outlast the network calls it waits on, or the hook
# is killed before it can say that one of them failed -- and a killed
# SessionStart hook takes the whole report with it, not only the line that was
# pending. There are three such calls now, so the claim is no longer about the
# fetch alone, and the budgets are read off the file rather than restated.
#
# 40 rather than the 30 this was: the second call took the margin over the two
# budgets from 15s down to 5s, and what has to happen inside that margin is the
# whole local half of the report -- a worktree listing and an ancestry read per
# branch. Raising the cap costs nothing the budgets do not already cost, because
# it is a cap and not a wait: the hook exits the moment it is done, and the
# `timeout` calls are what actually bound a dead network.
#
# 50 rather than 40: #100 added a third call, the pull request read, and the
# same 15s margin is kept over the three budgets for the same reason.
REPORT_TIMEOUT=$(jq -r '.hooks.SessionStart[]?.hooks[]? | select(.command | contains("report-stale-branches")) | .timeout' "$SETTINGS" 2>/dev/null)
req FR-43
tok 'the report hook outlasts its own network calls' '50' "$REPORT_TIMEOUT"
# All three budgets, summed off the script. The END guard makes a renamed or
# deleted budget print nothing rather than a smaller sum, which is the permitting
# direction: a sum that lost a term would compare favourably and say nothing.
BUDGET_SUM=$(awk -F= '/^FETCH_TIMEOUT=[0-9]+$/ || /^SETTINGS_TIMEOUT=[0-9]+$/ || /^PRS_TIMEOUT=[0-9]+$/ { s += $2; n += 1 }
                      END { if (n == 3) print s }' "$HOOKS/report-stale-branches.sh")
tok 'the report sets three budgets, and this is their sum' '35' "$BUDGET_SUM"
# Redundant with the two literals above by arithmetic, and kept for the reason
# the guard-equals-report check above is kept: it is the line that states the
# property the other two only imply, and it is the one still standing the day
# someone raises a budget and re-pins its literal in the same breath.
# Each side tested on its own with `numeric`: concatenating them first lets a
# present number and an absent one read as one number, and `[ 30 -gt "" ]` is a
# shell error rather than a verdict. Found by running this before the read
# existed.
OUTLASTS=unreadable
if numeric "$REPORT_TIMEOUT" && numeric "$BUDGET_SUM"; then
  if [ "$REPORT_TIMEOUT" -gt "$BUDGET_SUM" ]; then OUTLASTS=yes; else OUTLASTS=no; fi
fi
tok 'and it outlasts them by arithmetic, not by both literals happening to agree' \
    'yes' "$OUTLASTS"
# The main ancestry line below adds a read and no budget: it asks git about two
# refs already on disk, so neither number above moves and neither literal does.

# worktree.baseRef, which decides where EnterWorktree forks a new branch when
# the agent skips the step CLAUDE.md's boundary section gives it: a new worktree
# branch is set to origin/dev-NN at creation. With that step taken the value
# decides nothing, so what it is chosen for is the direction it fails in when
# the step is skipped, and the two values the harness offers fail in opposite
# ones.
#
# `head` forks from the session's own HEAD -- inside a worktree, that worktree's
# HEAD, not the main checkout's. So it starts ahead of the active dev branch
# whenever that HEAD carries commits origin/dev-NN lacks: Bertan's unpushed
# commits on local dev-NN, another branch checked out, or any worktree session.
# no-work-on-stale-branch.sh refuses only a branch with nothing of its own, so a
# branch that starts ahead is permitted in silence, and its pull request carries
# someone else's commits under the agent's number. `fresh` forks from
# origin/HEAD, which is origin/main: behind, and refused at the first commit --
# on one assumption, which the report reads rather than this suite restating
# it; the comment above its main ancestry line argues it, once. #36 Stage 0
# chose `head` before the ahead case was seen; #99 Q5 reverses it.
#
# THE TRADE, taken knowingly: a skipped step now starts from a much staler base.
# origin/dev-05 was 115 commits ahead of origin/main when #99 was triaged and 118
# by the time this line was written, on the same day. Nothing pins that number,
# because it moves with every merge; a skipped step shows it as a large behind
# count in the refusal, which is where it costs anything.
#
# TWO LIMITS, named because this is a check on configuration and not on
# behaviour. It cannot show the harness honours the value; the live runbook
# does that (#110 section 1). And it cannot see .claude/settings.local.json,
# which is gitignored and overrides this file on the one machine that has it.
# #36 said changing baseRef "leaves the suite green", which was true of the
# harness's behaviour and is false of this file now, which is the half this pins.
req GH-99.2
tok 'settings.json forks a worktree from origin/main, which is refused, and not from HEAD' \
    'fresh' "$(jq -r '.worktree.baseRef' "$SETTINGS" 2>/dev/null)"

section "=== #99: the report reads whether a branch cut from origin/main fails closed ==="
# Why the report reads this is argued once, in the comment above the read in
# report-stale-branches.sh, and not retold here. What this section holds is the
# three outcomes that comment names, a fourth case with no line, and the suffix
# on refs no fetch refreshed -- #99 Q11 and Q12.
#
# Driven rather than pinned, because the outcomes are the claim and a literal
# on the read says nothing about which exit code prints which sentence. Each
# fixture is its own repository with a copy of the report beside it, so the
# report's own `cd` lands in the fixture. Origin is a local repository and the
# refs are fetched before the report runs, so a fixture is in the state it names
# whatever the report does with its own fetch. gh is a stub that fails: the
# merge settings read has an answer of its own, and nothing here reaches an API.
#
# Present, not only absent. A deleted read prints no line at all, so every
# "does not say NOT" below would pass against a report that reads nothing; each
# fixture with a dev ref asserts the line it expects to be there.
ANC_BIN="$FIXTURES/ancestry-bin"
mkdir -p "$ANC_BIN"
printf '#!/bin/sh\nexit 1\n' > "$ANC_BIN/gh"
chmod +x "$ANC_BIN/gh"

anc_commit() {  # anc_commit <repo> <message> [parent...] -- an empty-tree commit's OID
  local repo="$1" msg="$2" parents=() p
  shift 2
  for p in "$@"; do parents+=(-p "$p"); done
  git -C "$repo" -c user.email=checks@example.invalid -c user.name=checks \
    commit-tree "$(git -C "$repo" mktree </dev/null)" "${parents[@]}" -m "$msg"
}
anc_fixture() {  # anc_fixture <dir> <origin url> -- a repository with the report in it
  git init -q -b scratch "$1"
  git -C "$1" remote add origin "$2"
  mkdir -p "$1/.claude/hooks"
  cp -p "$HOOKS/report-stale-branches.sh" "$1/.claude/hooks/"
}
# IT RECORDS NOTHING, and review of PR #169 is why. `ran` takes the status the
# hook exited with, because a hook that was never there is resolved exactly as
# one that was; this helper takes no verdict and reads no status, so it has
# nothing to give it. Reading one here to feed the record would put a status
# reader in this file that the #98 self-test cannot drive -- there is no
# expectation of its to fail -- and an undriven reader is what that self-test's
# derivation exists to refuse. The report's record comes from `report_says`,
# nine times under GH-108.9, which asks for the status and the sentence both.
anc_report() {  # anc_report <repo> -- the report's output, run as that repository's hook
  ( cd / && PATH="$ANC_BIN:$PATH" "$1/.claude/hooks/report-stale-branches.sh" ) 2>/dev/null
}
# The line and its indented continuations, and nothing after them: a NOT is
# three lines, and a phrase from the line after it must not count as its own.
anc_line() {  # anc_line <report output>
  printf '%s\n' "$1" | awk '/^main ancestry: / { f = 1; print; next }
                            f && /^       [^ ]/  { print; next }
                            f                    { exit }'
}
anc_count() {  # anc_count <report output> -- how many main ancestry lines it printed
  printf '%s\n' "$1" | grep -c '^main ancestry: '
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
anc_need() {  # anc_need <repo> <ref>... -- a fixture guard, as need_worktree is
  local repo="$1" ref
  shift
  for ref in "$@"; do
    git -C "$repo" rev-parse --verify --quiet "$ref^{commit}" >/dev/null && continue
    echo "the ancestry fixture $repo has no $ref; the checks against it prove nothing" >&2
    exit 1
  done
}
anc_lack() {  # anc_lack <repo> <ref> -- the guard's other half: a ref that must be absent
  git -C "$1" rev-parse --verify --quiet "$2" >/dev/null || return 0
  echo "the ancestry fixture $1 has $2; the checks against it prove nothing" >&2
  exit 1
}
STALE_SUFFIX='(read against refs the failed fetch left behind)'
NOT_LINE='main ancestry: origin/main is NOT an ancestor of origin/dev-05'
IS_LINE='main ancestry: origin/main is an ancestor of origin/dev-05'
UNREAD_LINE='main ancestry: NOT READ -- '

# NOT: main carries a merge commit the dev branch lacks. A decoy dev-4 stands
# beside it for a report that sorted the dev refs any other way than the pinned
# version sort. What catches that report is the name -- every line literal here
# says origin/dev-05 -- and not the graph, measured by sorting lexically: three
# checks turned red on the name. The decoy has main in its history anyway, so
# that report's answer is wrong as well as misnamed, and a line rewritten not to
# name the dev branch would still be caught.
ANC_NOT_ORIGIN="$FIXTURES/ancestry-not-origin"
git init -q -b main "$ANC_NOT_ORIGIN"
A=$(anc_commit "$ANC_NOT_ORIGIN" base)
A_DEV=$(anc_commit "$ANC_NOT_ORIGIN" dev "$A")
A_SIDE=$(anc_commit "$ANC_NOT_ORIGIN" side "$A")
A_MERGE=$(anc_commit "$ANC_NOT_ORIGIN" 'merge into main' "$A" "$A_SIDE")
git -C "$ANC_NOT_ORIGIN" update-ref refs/heads/main "$A_MERGE"
git -C "$ANC_NOT_ORIGIN" update-ref refs/heads/dev-05 "$A_DEV"
git -C "$ANC_NOT_ORIGIN" update-ref refs/heads/dev-4 "$A_MERGE"
ANC_NOT="$FIXTURES/ancestry-not"
anc_fixture "$ANC_NOT" "$ANC_NOT_ORIGIN"
git -C "$ANC_NOT" fetch -q origin
anc_need "$ANC_NOT" refs/remotes/origin/main refs/remotes/origin/dev-05 refs/remotes/origin/dev-4
OUT=$(anc_report "$ANC_NOT")
LINE=$(anc_line "$OUT")
req GH-99.3
holds 'main with a merge the dev branch lacks is reported as NOT an ancestor' "$LINE" "$NOT_LINE"
holds 'and the report says what that costs, in the guard it costs it in' "$LINE" \
  'passes a branch that is ahead'
lacks 'and it is not called unread' "$LINE" 'NOT READ'
lacks 'and a fetch that succeeded does not say it failed' "$LINE" "$STALE_SUFFIX"
tok 'and the report prints one main ancestry line, not one per outcome' '1' "$(anc_count "$OUT")"

# The ancestor case, asserted as the whole line: presence is the evidence that
# the read ran, and equality is what rules out a NOT, a suffix, or both. The
# decoy is reversed -- dev-4 is an unrelated root, so a report reading it says
# NOT here.
ANC_IS_ORIGIN="$FIXTURES/ancestry-is-origin"
git init -q -b main "$ANC_IS_ORIGIN"
A=$(anc_commit "$ANC_IS_ORIGIN" base)
A_DEV=$(anc_commit "$ANC_IS_ORIGIN" dev "$A")
A_ROOT=$(anc_commit "$ANC_IS_ORIGIN" 'unrelated root')
git -C "$ANC_IS_ORIGIN" update-ref refs/heads/main "$A"
git -C "$ANC_IS_ORIGIN" update-ref refs/heads/dev-05 "$A_DEV"
git -C "$ANC_IS_ORIGIN" update-ref refs/heads/dev-4 "$A_ROOT"
ANC_IS="$FIXTURES/ancestry-is"
anc_fixture "$ANC_IS" "$ANC_IS_ORIGIN"
git -C "$ANC_IS" fetch -q origin
anc_need "$ANC_IS" refs/remotes/origin/main refs/remotes/origin/dev-05 refs/remotes/origin/dev-4
OUT=$(anc_report "$ANC_IS")
tok 'main as an ancestor is reported in exactly the positive line' "$IS_LINE" "$(anc_line "$OUT")"

# No origin/main at all: `git merge-base --is-ancestor` exits 128 rather than 1,
# and an unanswered question is not a negative answer. A report that read every
# nonzero exit as NOT would print a warning about an ancestry it never saw.
ANC_NOMAIN_ORIGIN="$FIXTURES/ancestry-nomain-origin"
git init -q -b dev-05 "$ANC_NOMAIN_ORIGIN"
A=$(anc_commit "$ANC_NOMAIN_ORIGIN" base)
git -C "$ANC_NOMAIN_ORIGIN" update-ref refs/heads/dev-05 "$A"
ANC_NOMAIN="$FIXTURES/ancestry-nomain"
anc_fixture "$ANC_NOMAIN" "$ANC_NOMAIN_ORIGIN"
git -C "$ANC_NOMAIN" fetch -q origin
anc_need "$ANC_NOMAIN" refs/remotes/origin/dev-05
anc_lack "$ANC_NOMAIN" refs/remotes/origin/main
OUT=$(anc_report "$ANC_NOMAIN")
LINE=$(anc_line "$OUT")
holds 'no origin/main is reported as NOT READ' "$LINE" "$UNREAD_LINE"
lacks 'and not as NOT an ancestor, which is an answer' "$LINE" 'is NOT an ancestor'
lacks 'and not as an ancestor either' "$LINE" 'is an ancestor of'

# No dev ref: nothing to be an ancestor of, and no line. The first check is what
# makes the second one evidence -- a report that did not run also prints no line.
ANC_NODEV_ORIGIN="$FIXTURES/ancestry-nodev-origin"
git init -q -b main "$ANC_NODEV_ORIGIN"
A=$(anc_commit "$ANC_NODEV_ORIGIN" base)
git -C "$ANC_NODEV_ORIGIN" update-ref refs/heads/main "$A"
ANC_NODEV="$FIXTURES/ancestry-nodev"
anc_fixture "$ANC_NODEV" "$ANC_NODEV_ORIGIN"
git -C "$ANC_NODEV" fetch -q origin
anc_need "$ANC_NODEV" refs/remotes/origin/main
OUT=$(anc_report "$ANC_NODEV")
holds 'with no dev ref the report ran and says it found none' "$OUT" 'active dev branch: none'
tok 'and it prints no main ancestry line' '0' "$(anc_count "$OUT")"

# After a failed fetch every outcome says the refs it read are the ones the last
# successful fetch left, because each of the three can be stale: an ancestry
# that has since broken reads as intact. Origin names a path that does not exist,
# so the fetch fails at once, and the refs are written with update-ref. The
# suffix is asserted anywhere in the line, not at its end: where a three-line NOT
# carries it is the report's to decide.
ANC_GONE_REMOTE="$FIXTURES/ancestry-no-such-remote.git"
[ ! -e "$ANC_GONE_REMOTE" ] || {
  echo "$ANC_GONE_REMOTE exists, so the failed-fetch fixtures would fetch; the checks against them prove nothing" >&2
  exit 1
}
anc_stale() {  # anc_stale <dir> <main: merged|ancestor|none> -- origin refs by update-ref
  local dir="$1" base dev side
  anc_fixture "$dir" "$ANC_GONE_REMOTE"
  base=$(anc_commit "$dir" base)
  dev=$(anc_commit "$dir" dev "$base")
  git -C "$dir" update-ref refs/remotes/origin/dev-05 "$dev"
  case "$2" in
    merged)   side=$(anc_commit "$dir" side "$base")
              git -C "$dir" update-ref refs/remotes/origin/main \
                "$(anc_commit "$dir" 'merge into main' "$base" "$side")" ;;
    ancestor) git -C "$dir" update-ref refs/remotes/origin/main "$base" ;;
  esac
}
anc_stale "$FIXTURES/ancestry-stale-not" merged
anc_need "$FIXTURES/ancestry-stale-not" refs/remotes/origin/main refs/remotes/origin/dev-05
OUT=$(anc_report "$FIXTURES/ancestry-stale-not")
LINE=$(anc_line "$OUT")
holds 'after a failed fetch, NOT is still reported' "$LINE" "$NOT_LINE"
holds 'and says which refs it was read against' "$LINE" "$STALE_SUFFIX"

anc_stale "$FIXTURES/ancestry-stale-is" ancestor
anc_need "$FIXTURES/ancestry-stale-is" refs/remotes/origin/main refs/remotes/origin/dev-05
OUT=$(anc_report "$FIXTURES/ancestry-stale-is")
LINE=$(anc_line "$OUT")
holds 'after a failed fetch, an ancestor is still reported' "$LINE" "$IS_LINE"
holds 'and says which refs it was read against, which matters most here' "$LINE" "$STALE_SUFFIX"

anc_stale "$FIXTURES/ancestry-stale-nomain" none
anc_need "$FIXTURES/ancestry-stale-nomain" refs/remotes/origin/dev-05
anc_lack "$FIXTURES/ancestry-stale-nomain" refs/remotes/origin/main
OUT=$(anc_report "$FIXTURES/ancestry-stale-nomain")
LINE=$(anc_line "$OUT")
holds 'after a failed fetch, NOT READ is still reported' "$LINE" "$UNREAD_LINE"
holds 'and says which refs it was read against' "$LINE" "$STALE_SUFFIX"

# A fetch that never ran did not fail. With no remote named origin the report
# skips its fetch, and refs under refs/remotes/origin/ can still be there from a
# remote since removed or renamed. Those are unrefreshed too, so the line still
# says so -- but not that a fetch failed, which is a claim about an attempt.
# Found on review of the first version, which printed the failed-fetch suffix
# for both.
ANC_SKIPPED="$FIXTURES/ancestry-skipped"
git init -q -b scratch "$ANC_SKIPPED"
mkdir -p "$ANC_SKIPPED/.claude/hooks"
cp -p "$HOOKS/report-stale-branches.sh" "$ANC_SKIPPED/.claude/hooks/"
A=$(anc_commit "$ANC_SKIPPED" base)
git -C "$ANC_SKIPPED" update-ref refs/remotes/origin/main "$A"
git -C "$ANC_SKIPPED" update-ref refs/remotes/origin/dev-05 "$(anc_commit "$ANC_SKIPPED" dev "$A")"
anc_need "$ANC_SKIPPED" refs/remotes/origin/main refs/remotes/origin/dev-05
git -C "$ANC_SKIPPED" remote | grep -q . && {
  echo "the skipped-fetch fixture has a remote, so the report would fetch; the checks against it prove nothing" >&2
  exit 1
}
OUT=$(anc_report "$ANC_SKIPPED")
LINE=$(anc_line "$OUT")
holds 'with no origin remote, the ancestry is still reported' "$LINE" "$IS_LINE"
holds 'and says no fetch refreshed the refs' "$LINE" '(read against refs no fetch refreshed)'
lacks 'and does not say a fetch failed that never ran' "$LINE" "$STALE_SUFFIX"

# The read as a literal as well, beside the arming pins above: the fixtures say
# what each outcome prints, and this says the answer is git's and not a record.
# The literal runs on to the ref: the NOT READ message names the command too,
# and is not a comment `armed` strips, so the bare command stayed green with the
# read replaced by `true`.
req GH-99.3 FR-40
armed 'the report reads the ancestry with git rather than recording it' \
  "$HOOKS/report-stale-branches.sh" 'git merge-base --is-ancestor refs/remotes/origin/main'
# #99 Q16: the report cites nothing new for this line -- the reasoning is beside
# the read, and the decisions it rests on are cited from the documents.
unarmed 'the report cites no issue for the ancestry line' \
  "$HOOKS/report-stale-branches.sh" '#99'

section "=== issue #100: the report classifies by pull request, as the sweep does ==="
# The branch-hygiene sweep defines its three classes by pull request state and
# acts on one of them; the report it acts on classified by ref state and never
# read a pull request. Why the report was the side changed is argued in its
# header, once.
#
# These drive the report as a process rather than pinning its lines, because the
# claim is about what it prints for a given state. The report cds to the
# repository it sits in, so a copy of it is placed in a fixture repository; that
# repository's origin is a bare repository beside it, so the pruning fetch runs
# for real and reaches nothing; and gh is a stand-in on PATH that answers the two
# reads the report makes with what the real reads' --jq filters print. That last
# part is a limit and is named: the filters themselves are not run here, so they
# are pinned as literals below instead.
REPORT_FIX="$FIXTURES/report"
REPORT_ORIGIN="$FIXTURES/report-origin.git"
FAKE_GH="$FIXTURES/fake-gh"
git init -q -b main "$REPORT_FIX"
GR="git -C $REPORT_FIX -c user.email=checks@example.invalid -c user.name=checks"
$GR commit -q --allow-empty -m base
REPORT_BASE=$($GR rev-parse HEAD)
$GR commit -q --allow-empty -m advance
REPORT_TIP=$($GR rev-parse HEAD)
$GR branch dev-05 "$REPORT_TIP"
# A commit of a branch's own, made without a checkout, so that no worktree is
# needed for a branch to be ahead of the dev branch.
own_commit() { $GR commit-tree -p "$REPORT_TIP" -m "$1" "$REPORT_TIP^{tree}"; }
# The table in #100, one branch per row. merged-branch has no commit of its own
# and is behind the dev branch -- what a merge commit leaves -- and closed-branch
# carries a commit nothing else has. Both track a remote branch that is still
# there, which is what the table's first two rows say.
CLOSED_OWN=$(own_commit closed)
$GR branch merged-branch "$REPORT_BASE"
$GR branch closed-branch "$CLOSED_OWN"
$GR branch nopr-branch "$(own_commit nopr)"
# The class the sweep must not touch.
$GR branch open-branch "$(own_commit open)"
# Branches with two pull requests each, one per ordering the decision has to get
# right: an open one beside a closed one and beside a newer merged one -- open
# decides both -- and a merged one beside a closed one in each order, where the
# newer decides. A decision by list position, or by merged over closed, or by
# merged over open, turns one of these red.
REOPENED_OWN=$(own_commit reopened)
TWICE_OWN=$(own_commit twice)
LATE_CLOSED_OWN=$(own_commit late-closed)
OPEN_MERGED_OWN=$(own_commit open-merged)
$GR branch reopened-branch "$REOPENED_OWN"
$GR branch twice-branch "$TWICE_OWN"
$GR branch late-closed-branch "$LATE_CLOSED_OWN"
$GR branch open-merged-branch "$OPEN_MERGED_OWN"
# A name reused: cut fresh at the dev tip under the name of a branch whose pull
# request merged at the base commit. Matched by name it is that pull request's,
# and stale; it is not at or behind that head, so it is not.
$GR branch reused-branch "$REPORT_TIP"
# The same after a closed pull request, carrying a commit of its own -- the case
# where getting it wrong deletes commits that exist nowhere else. Review of #120
# found the head test skippable for CLOSED alone with every check green, because
# reused-branch is merged.
$GR branch reclosed-branch "$(own_commit reclosed)"
# Strictly behind its merged pull request's head, which is what a local copy
# that never pulled the last push looks like. Stale: the report's header rejects
# an identity test because it would call this unclassified, and until review of
# #120 no branch here said so.
$GR branch lagging-branch "$REPORT_BASE"
# And the ref-state detector's own case with no pull request behind it: an
# upstream configured whose remote half is gone. Stale by ref state,
# unclassified by pull request, because nothing says a pull request ever merged.
$GR branch gone-nopr-branch "$REPORT_TIP"
git clone -q --bare "$REPORT_FIX" "$REPORT_ORIGIN"
git -C "$REPORT_ORIGIN" update-ref -d refs/heads/gone-nopr-branch
$GR remote add origin "$REPORT_ORIGIN"
for b in gone-nopr-branch merged-branch closed-branch; do
  $GR config "branch.$b.remote" origin
  $GR config "branch.$b.merge" "refs/heads/$b"
done
# Four of them checked out in worktrees, so that the lines the sweep's step 2
# reads a worktree path from are asserted with that path. The suffix was
# droppable from any of them with the suite green; found on review of #120. The
# second review found it droppable still from the `not at or behind its head`
# line, whose one fixture was in no worktree; reclosed-branch now is. The path
# is resolved with cd -P because git records the physical one.
REPORT_WT_MERGED="$FIXTURES/report-wt-merged"
REPORT_WT_CLOSED="$FIXTURES/report-wt-closed"
REPORT_WT_GONE="$FIXTURES/report-wt-gone"
REPORT_WT_RECLOSED="$FIXTURES/report-wt-reclosed"
$GR worktree add -q "$REPORT_WT_MERGED" merged-branch
$GR worktree add -q "$REPORT_WT_CLOSED" closed-branch
$GR worktree add -q "$REPORT_WT_GONE" gone-nopr-branch
$GR worktree add -q "$REPORT_WT_RECLOSED" reclosed-branch
for d in "$REPORT_WT_MERGED" "$REPORT_WT_CLOSED" "$REPORT_WT_GONE" "$REPORT_WT_RECLOSED"; do
  [ -d "$d" ] || {
    echo "the report worktree $d was not created; the checks against it prove nothing" >&2
    exit 1
  }
done
REPORT_WT_MERGED=$(cd -P "$REPORT_WT_MERGED" && pwd)
REPORT_WT_CLOSED=$(cd -P "$REPORT_WT_CLOSED" && pwd)
REPORT_WT_GONE=$(cd -P "$REPORT_WT_GONE" && pwd)
REPORT_WT_RECLOSED=$(cd -P "$REPORT_WT_RECLOSED" && pwd)
mkdir -p "$REPORT_FIX/.claude/hooks" "$FAKE_GH"
cp "$HOOKS/report-stale-branches.sh" "$REPORT_FIX/.claude/hooks/"
cat > "$FAKE_GH/gh" <<'GH'
#!/bin/bash
# The merge settings as required -- or a failed read when FAKE_GH_API_FAIL is
# set -- and the pull request list from the file named by FAKE_GH_PRS, or a
# failed read when none is named.
case "$1" in
  api) [ -z "$FAKE_GH_API_FAIL" ] && printf 'false\tfalse\ttrue\n' ;;
  pr)  [ -n "$FAKE_GH_PRS" ] && cat "$FAKE_GH_PRS" ;;
  *)   exit 1 ;;
esac
GH
chmod +x "$FAKE_GH/gh"
# Head, state, number, head commit -- the real read's four columns. Not in
# number order, so that nothing passes by the order gh happens to list them in.
# An older pull request on a branch points at the base commit, which the branch
# is not behind: were it allowed to decide, it would read as a reused name.
REPORT_PRS="$FIXTURES/report-prs.tsv"
printf '%s\t%s\t%s\t%s\n' \
  twice-branch CLOSED 6 "$REPORT_BASE" \
  merged-branch MERGED 1 "$REPORT_BASE" \
  dev-05 MERGED 13 "$REPORT_TIP" \
  reopened-branch OPEN 5 "$REOPENED_OWN" \
  late-closed-branch CLOSED 9 "$LATE_CLOSED_OWN" \
  open-branch OPEN 3 "$REPORT_TIP" \
  reopened-branch CLOSED 4 "$REPORT_BASE" \
  open-merged-branch MERGED 11 "$OPEN_MERGED_OWN" \
  twice-branch MERGED 7 "$TWICE_OWN" \
  closed-branch CLOSED 2 "$CLOSED_OWN" \
  late-closed-branch MERGED 8 "$REPORT_BASE" \
  reused-branch MERGED 12 "$REPORT_BASE" \
  lagging-branch MERGED 15 "$REPORT_TIP" \
  reclosed-branch CLOSED 14 "$REPORT_BASE" \
  open-merged-branch OPEN 10 "$REPORT_BASE" > "$REPORT_PRS"

REPORT_READ="$FIXTURES/report-read.txt"
REPORT_UNREAD="$FIXTURES/report-unread.txt"
PATH="$FAKE_GH:$PATH" FAKE_GH_PRS="$REPORT_PRS" \
  "$REPORT_FIX/.claude/hooks/report-stale-branches.sh" > "$REPORT_READ" 2>&1
PATH="$FAKE_GH:$PATH" FAKE_GH_PRS= \
  "$REPORT_FIX/.claude/hooks/report-stale-branches.sh" > "$REPORT_UNREAD" 2>&1
# gh unreachable for the settings read, and a pull request list that would have
# answered: the second read is skipped, not merely failed.
REPORT_NOAPI="$FIXTURES/report-noapi.txt"
PATH="$FAKE_GH:$PATH" FAKE_GH_PRS="$REPORT_PRS" FAKE_GH_API_FAIL=1 \
  "$REPORT_FIX/.claude/hooks/report-stale-branches.sh" > "$REPORT_NOAPI" 2>&1
grep -qxF 'fetch: pruned origin' "$REPORT_NOAPI" \
  && grep -qxF 'active dev branch: origin/dev-05' "$REPORT_NOAPI" || {
  echo "the report fixture did not fetch and find its dev branch with the settings read failing; the checks against it prove nothing" >&2
  cat "$REPORT_NOAPI" >&2
  exit 1
}
# Every `unarmed` below passes on an empty file, and every classification below
# is a different one if the fetch did not run or the dev branch was not found.
for out in "$REPORT_READ" "$REPORT_UNREAD"; do
  grep -qxF 'fetch: pruned origin' "$out" \
    && grep -qxF 'active dev branch: origin/dev-05' "$out" \
    && grep -qxF 'merge settings: as required (squash off, rebase off, delete-on-merge on)' "$out" || {
    echo "the report fixture did not fetch, find its dev branch and read its settings; the checks against it prove nothing" >&2
    cat "$out" >&2
    exit 1
  }
done

echo "--- pull requests read: each row of the table in #100 ---"
req GH-100
written 'the report says it read the pull requests' \
  "$REPORT_READ" 'pull requests: read'
written 'row 1: a pull request closed unmerged, remote branch present, is stale' \
  "$REPORT_READ" "  closed-branch -- closed without merging: pull request #2; its commits may exist nowhere else   [worktree: $REPORT_WT_CLOSED]"
written 'row 2: a pull request merged, remote branch not yet pruned, is stale' \
  "$REPORT_READ" "  merged-branch -- merged: pull request #1   [worktree: $REPORT_WT_MERGED]"
written 'row 3: commits of its own and no pull request ever opened is unclassified' \
  "$REPORT_READ" '  nopr-branch -- no pull request; 1 ahead of origin/dev-05, 0 behind it (unclassified: cut and not yet worked, or abandoned)'
written 'an upstream gone with no pull request is unclassified, not stale' \
  "$REPORT_READ" "  gone-nopr-branch -- no pull request; 0 ahead of origin/dev-05, 0 behind it (unclassified: cut and not yet worked, or abandoned)   [worktree: $REPORT_WT_GONE]"
written 'a merge by a newer pull request decides over an older closed one' \
  "$REPORT_READ" '  twice-branch -- merged: pull request #7'
written 'and a close by a newer one decides over an older merge, keeping its warning' \
  "$REPORT_READ" '  late-closed-branch -- closed without merging: pull request #9; its commits may exist nowhere else'
written 'a reused name is not stale off a pull request whose head it is not behind' \
  "$REPORT_READ" '  reused-branch -- pull request #12 is merged, but this branch is not at or behind its head; 0 ahead of origin/dev-05, 0 behind it (unclassified: a reused name, or work after it)'
written 'and not stale off a closed one either, where its commits exist nowhere else' \
  "$REPORT_READ" "  reclosed-branch -- pull request #14 is closed, but this branch is not at or behind its head; 1 ahead of origin/dev-05, 0 behind it (unclassified: a reused name, or work after it)   [worktree: $REPORT_WT_RECLOSED]"
written 'a branch strictly behind its merged pull request head is stale, not only one at it' \
  "$REPORT_READ" '  lagging-branch -- merged: pull request #15'
unarmed 'an open pull request is in flight and is not listed' \
  "$REPORT_READ" '  open-branch --'
unarmed 'nor is a branch with an open pull request beside an older closed one' \
  "$REPORT_READ" '  reopened-branch --'
unarmed 'nor one with an open pull request beside a newer merged one' \
  "$REPORT_READ" '  open-merged-branch --'
unarmed 'and the active dev branch is not called stale off its own merged pull request' \
  "$REPORT_READ" '  dev-05 --'
# The counts line is what decides each class exactly: main, dev-05, open-branch,
# reopened-branch and open-merged-branch clear; five stale; four unclassified.
written 'and every branch lands in the class the sweep defines' \
  "$REPORT_READ" '5 other branch(es) are clear; 5 stale, 4 unclassified.'

echo "--- pull requests not read: the report falls back to ref state and says so ---"
# Fails open, as the settings read does: a session whose gh cannot answer still
# starts, and the report says which computation it ran rather than printing the
# ref-state classes under the pull-request meanings.
written 'a pull request read that failed says so' \
  "$REPORT_UNREAD" 'pull requests: NOT READ'
written 'and names the computation it ran instead' \
  "$REPORT_UNREAD" 'classified by ref state alone'
written 'by ref state, an upstream gone is stale, without claiming it merged' \
  "$REPORT_UNREAD" "  gone-nopr-branch -- stale by ref state: its branch on the remote is gone (merged, or closed and deleted)   [worktree: $REPORT_WT_GONE]"
written 'and no work of its own is unclassified' \
  "$REPORT_UNREAD" '  merged-branch -- no work of its own; origin/dev-05 is 1 ahead of it (unclassified: merged, or cut and not yet worked)'
unarmed 'a closed branch with commits of its own reads as clear by ref state' \
  "$REPORT_UNREAD" '  closed-branch --'
written 'the ref-state counts, which are the ones #100 found disagreeing' \
  "$REPORT_UNREAD" '11 other branch(es) are clear; 1 stale, 2 unclassified.'
# The settings read could not reach gh, so the pull request read is not
# attempted, and the report gives the settings read's reason for both.
written 'a settings read that failed skips the pull request read and says why' \
  "$REPORT_NOAPI" 'pull requests: NOT READ -- gh api failed or timed out after 10s, so branches are'
written 'and the classes are the ref-state ones, though the list would have answered' \
  "$REPORT_NOAPI" '11 other branch(es) are clear; 1 stale, 2 unclassified.'

# The filters the stand-in does not run, pinned as they are written, one line
# each for the reason the settings list above is.
armed 'the report reads every pull request, closed and merged included' \
  "$HOOKS/report-stale-branches.sh" 'timeout "$PRS_TIMEOUT" gh pr list --state all --limit 1000'
armed 'and reads the head, the state, the number and the head commit of each' \
  "$HOOKS/report-stale-branches.sh" '--json headRefName,state,number,headRefOid'
armed 'in the column order the stand-in above answers in' \
  "$HOOKS/report-stale-branches.sh" "--jq '.[] | \"\\(.headRefName)\\t\\(.state)\\t\\(.number)\\t\\(.headRefOid)\"'"
# The skill's side of #100 is asserted with the rest of the sweep's text, below,
# where that section is extracted.

section "=== CLAUDE.md names every hook that carries the boundary ==="
# A third kind of check, and the second here that reads a file rather than
# driving a process: this one asks whether the document agrees with the
# configuration.
#
# CLAUDE.md's boundary section exists so that the boundary can be audited
# without reading the hooks, which only works while the section names all of
# them. Issue #63 found it naming two of four: #43 rebuilt no-commit-to-main.sh
# on lib/command-scan.sh and #44 added no-work-on-stale-branch.sh, and neither
# revised the section. That is the ordinary way this kind of claim goes stale,
# and it goes stale in the direction that matters -- a reader who audits the
# named files has audited less than half of what runs, and cannot tell from the
# text that they have.
#
# The direction of the check matters too. settings.json is the fact, because it
# is what actually runs a hook; the section is the claim. So the registered
# hooks are derived and the section is asserted against them, rather than one
# list of names being written out here a second time. The single literal is the
# opposite list: the registered hooks whose subject is not the boundary, which
# the section is right not to name. Adding a boundary hook and not the sentence
# turns this red; adding a hook about documents or commands means adding it
# here, deliberately, with a reason.
# A third helper, because the two above read a file and this asks about a list
# this suite has computed. One membership convention, written once: the spaces
# belong to the pattern, so no literal carries its own.
present() {  # present <label> <needle> <space-separated haystack>
  case " $3 " in
    *" $2 "*) pass static '%s' "$1" ;;
    *) fail static '%s' "$1" ;;
  esac
}

CLAUDE_MD="$SUITE_DIR/../../CLAUDE.md"
SECTION="$FIXTURES/boundary-section.md"
# awk rather than `sed -n '/start/,/^## /p' | sed '$d'`: that pair drops the last
# line unconditionally, and when the boundary section is the last in the file
# there is no following heading to drop -- so it would eat a real line of the
# section, silently, in the permitting direction.
awk '/^## What an unattended agent may do to this repository$/ {f=1; print; next}
     f && /^## / {exit}
     f {print}' "$CLAUDE_MD" > "$SECTION"
# The extraction is itself a claim about a heading that can be renamed, so it is
# checked from both ends before anything is asserted against it: the heading is
# in what came out, and a line from another section is not.
req GH-63 US-16
written 'the extracted section is the boundary section' \
  "$SECTION" 'What an unattended agent may do to this repository'
unarmed 'and it is that section rather than the whole file' \
  "$SECTION" 'Import cost is a design constraint'

# Narrowed again, to the paragraph that says what is enforced. The section's last
# paragraph is about what is deliberately NOT guarded, and it discusses
# .claude/ by name; a hook named only there would satisfy a section-wide grep
# while telling a reader the opposite of what the grep was taken to prove. This
# is also what CLAUDE.md now claims -- "this paragraph names every hook that
# carries it" -- and a check that asserted something wider would be the same
# drift one paragraph along.
PARAGRAPH="$FIXTURES/boundary-paragraph.md"
awk -v RS= '/Enforced by/' "$SECTION" > "$PARAGRAPH"
written 'and the paragraph taken from it is the one that says what is enforced' \
  "$PARAGRAPH" 'Enforced by'
unarmed 'and it stops short of what is deliberately left unguarded' \
  "$PARAGRAPH" 'Deliberately left open'

# Registered on Bash or at SessionStart, but about documents or commands rather
# than about what an agent may do to this repository. Each name here is a
# decision: these are the hooks the paragraph is correct to leave out.
NOT_THE_BOUNDARY="append-only-docs.sh alembic-via-uv-group.sh pytest-via-uv-group.sh"
# Space-separated, because `present` separates on spaces and a newline between
# two names is not the separator its pattern looks for -- every name but the
# first would read as absent. The second sed drops anything after the path, so
# a hook registered with an argument is still named by its file.
REGISTERED=$(jq -r '
    (.hooks.PreToolUse[]? | select(.matcher == "Bash") | .hooks[]?.command),
    (.hooks.SessionStart[]?.hooks[]?.command)' "$SETTINGS" 2>/dev/null \
  | sed 's|.*/||; s|[[:space:]].*||' | sort -u | tr '\n' ' ')
# Every .sh beside this suite, for the other direction below.
HOOK_FILES=$(ls "$HOOKS"/*.sh "$HOOKS"/lib/*.sh 2>/dev/null | sed 's|.*/||' | sort -u | tr '\n' ' ')
# An empty derivation would pass every loop below without asking anything.
[ -n "$REGISTERED" ] && [ -n "$HOOK_FILES" ] || {
  echo "no hooks were read out of settings.json or off the disk; the checks below prove nothing" >&2
  exit 1
}
# Unglobbed: a name is a word here, never a pattern to expand against the tree.
set -f
for hook in $REGISTERED; do
  case " $NOT_THE_BOUNDARY " in *" $hook "*) continue ;; esac
  written "the paragraph names $hook, which settings.json runs" "$PARAGRAPH" "$hook"
done

# The other direction: a name in the paragraph that nothing runs any more. Every
# .sh it names must exist, which catches a rename that updated the tree and left
# the sentence behind; and every one named as a no-*.sh guard must still be
# registered, which catches a guard quietly dropped from settings.json while the
# document goes on promising it.
for hook in $(grep -oE '[A-Za-z0-9_-]+\.sh' "$PARAGRAPH" | sort -u); do
  present "the paragraph names $hook, and that file exists" "$hook" "$HOOK_FILES"
  case "$hook" in
    no-*.sh) present "the paragraph names $hook, and settings.json runs it" \
                     "$hook" "$REGISTERED" ;;
  esac
done
set +f

# The section also makes a claim of count -- "the only Edit|Write hook" -- and a
# second one would falsify it as quietly as a fourth Bash hook falsified the
# sentence above. The question is how many hooks would run on an Edit, not how
# many are registered under that one spelling of the matcher: `Edit`, `*` and an
# absent matcher all reach the Edit tool, and asking for the literal string
# "Edit|Write" would answer 1 while a second hook guarded edits under any of
# them. So the matcher is used as what it is, a pattern, and the expectation is
# the literal 1.
req FR-6 US-19
tok 'one hook runs on an Edit, which is the number the section claims' \
    '1' \
    "$(jq -r '[.hooks.PreToolUse[]? | select((.matcher // "*") as $m
                | $m == "*" or $m == "" or ("Edit" | test($m)))
              | .hooks[]?] | length' "$SETTINGS" 2>/dev/null)"

# The left-open list states a count at its head, and that count is what went
# stale: it said four while describing what are really five, because a rule was
# widened and the sentence describing it was not revised with it (#73). The list
# is numbered now, so the claim can be checked instead of believed.
#
# This asserts the head count against the items and nothing whatever about what
# the items say. A prose list cannot be checked for being right; it can be
# checked for being self-consistent, and the arithmetic is the half that has
# actually drifted. The narrowing above still keeps the hook-name audit off this
# paragraph, which is a separate question and stays answered the same way.
LEFT_OPEN=$(awk '/^\*\*Deliberately left open\.\*\*/ {f=1} f' "$SECTION")
CLAIMED_WORD=$(printf '%s\n' "$LEFT_OPEN" \
  | sed -n 's/.*[^A-Za-z]\([A-Za-z][a-z]*\) consequences.*/\1/p' | head -1)
# Spelled out rather than a numeral, so the word is what has to be read. An
# unrecognised word fails rather than passing as zero: a renamed heading or a
# reworded head sentence must not answer this check by making it vacuous.
case "$CLAIMED_WORD" in
  Two) CLAIMED=2 ;;  Three) CLAIMED=3 ;;  Four) CLAIMED=4 ;;
  Five) CLAIMED=5 ;; Six) CLAIMED=6 ;;    Seven) CLAIMED=7 ;;
  *) CLAIMED="no count read from the list head" ;;
esac
# Top-level items only: the second consequence carries an indented continuation
# paragraph, which is part of that item and not a sixth one.
req GH-73
tok 'the left-open list numbers as many consequences as its head claims' \
    "$CLAIMED" \
    "$(printf '%s\n' "$LEFT_OPEN" | grep -cE '^[0-9]+\. ')"

section "=== issue #105: the boundary hooks carry the stopping rule ==="
# US-20 and FR-2. The rule that says when to stop fixing evasions is the reason
# this suite is finite rather than a race, and it lives in a comment -- which is
# the one thing `armed` cannot pin, because it strips a comment before it looks.
# `written` reads the file as written, and here the file's argument IS the
# requirement.
#
# The four files are derived rather than listed again, by the same subtraction
# the paragraph audit immediately above makes: what settings.json registers, less
# the hooks that are about documents or commands, less the one that judges no
# command. That audit holds the paragraph and settings.json to each other in both
# directions, so the set derived here is the set the paragraph names, and a
# boundary hook arrives here whatever it is called.
#
# It was derived off the paragraph, by a `no-` prefix, until Bertan's review of
# #132. That reads as equivalent and is not. A boundary hook named under some
# other prefix passes the paragraph audit and then drops out of this loop in
# silence -- never asked for the rule, no check missing that anything counts,
# while the comment above goes on saying it arrives. The prefix was doing the
# work of a decision without being one, which is the shape #84 was filed against:
# a question asked of two hooks of four. The exclusion is a named list now, for
# the reason NOT_THE_BOUNDARY is one.
#
# The loop asks for the test itself, in the two short spellings every one of
# them carries, because the four word the rule differently on purpose: two state
# it and two cite no-git-push.sh for it. A citation whose referent has gone is
# exactly the drift this part of the suite exists for, so the citations are
# checked below against the file the loop has just asked.
# Registered, named in the paragraph, and judging no command: it prunes the refs
# the fourth hook reads each session. There is no evasion for it to stop fixing,
# so there is no stopping rule for it to carry.
JUDGES_NO_COMMAND="report-stale-branches.sh"
set -f
BOUNDARY_HOOKS=$(for hook in $REGISTERED; do
    case " $NOT_THE_BOUNDARY $JUDGES_NO_COMMAND " in *" $hook "*) continue ;; esac
    printf '%s\n' "$hook"
  done | sort -u | tr '\n' ' ')
[ -n "$BOUNDARY_HOOKS" ] || {
  echo "no boundary hooks were derived from settings.json; the checks below prove nothing" >&2
  exit 1
}
req US-20 FR-2
for hook in $BOUNDARY_HOOKS; do
  written "$hook carries the test a fix has to pass" \
    "$HOOKS/$hook" 'would plausibly write'
  written "and the shape that does not earn one, in $hook" \
    "$HOOKS/$hook" 'have to construct'
done
# AND EVERY ONE OF THEM ADMITS A QUOTED GUARDED NAME, issue #117. The second
# question of each boundary hook's wrapper rule is that hook's own pattern, so
# there are four of them, and all four matched the guarded name by its bare
# spelling until this branch. Asked of the DERIVED set rather than of a list
# written here, which is the whole of #84: a list names the hooks someone
# remembered, and a boundary hook added later joins the derivation without
# anyone revising a sentence.
#
# The class itself is the literal, not the pattern around it, because the four
# patterns differ in the name they guard and in their verb lists. What is held
# is that each carries the class at all -- narrowing any one of them back is
# then a red check here rather than a review finding.
#
# The literal is the class AS THE FILES SPELL IT, which is the shell-escaped
# form and not the regular expression it becomes: a single shell word cannot
# hold both quote characters, so the four files write the apostrophe by closing
# the quote and reopening it, and so does this. Assembled with printf rather
# than quoted, because the quoted spelling of the quoted spelling is where a
# reader stops being able to check it by eye.
req GH-117
QUOTE_ADMISSION=$(printf '[%s%s%s%s%s%s]*' '"' "'" '"' "'" '"' "'")
for hook in $BOUNDARY_HOOKS; do
  written "$hook admits a quoted spelling of the name its wrapper rule guards" \
    "$HOOKS/$hook" "$QUOTE_ADMISSION"
done
set +f
# The two that state it in full, named because a check is evidence about what it
# names and the loop above is satisfied by the phrase alone.
written 'no-git-push.sh writes the rule out under its own heading' \
  "$HOOKS/no-git-push.sh" 'STOPPING RULE. A newly found evasion earns a fix only if it is a shape an'
written 'and says where to stop' \
  "$HOOKS/no-git-push.sh" 'closed. Stop when the shapes stop being ones an agent would plausibly write.'
written 'no-pr-decisions.sh writes it out too' \
  "$HOOKS/no-pr-decisions.sh" 'STOPPING RULE. A newly found evasion earns a fix only if it is a shape an'
written 'and applies it to the endpoint list that is its own growth' \
  "$HOOKS/no-pr-decisions.sh" 'growing when the spellings stop being ones an agent would plausibly write.'
# The two that cite rather than restate. Both name no-git-push.sh, which the
# loop above has just asked for the rule, so a citation and its referent are
# checked together rather than one at a time -- the #84 shape, one level out.
written 'no-commit-to-main.sh cites the rule rather than restating it' \
  "$HOOKS/no-commit-to-main.sh" 'This stops mistakes, not adversaries. The stopping rule in no-git-push.sh'
written 'no-work-on-stale-branch.sh inherits it by name' \
  "$HOOKS/no-work-on-stale-branch.sh" 'STOPPING RULE, inherited from no-git-push.sh. A newly found evasion earns a'
# What the rule is for, in the sentence the four exist under. Not derived off the
# loop: no-pr-decisions.sh does not carry it, and a loop asking for it would pin
# three files and a hole.
written 'no-git-push.sh says what standard it is held to' \
  "$HOOKS/no-git-push.sh" 'This stops mistakes, not adversaries.'
written 'and so does no-work-on-stale-branch.sh' \
  "$HOOKS/no-work-on-stale-branch.sh" 'This stops mistakes, not adversaries.'

section "=== the documents answer the citations the hooks make into them ==="
# A fourth kind of check, and the section above with its direction reversed:
# there settings.json is the fact and CLAUDE.md the claim; here the hooks are
# the fact -- they ship, they run, and their headers send a reader somewhere --
# and the documents are what has to be there when the reader arrives. Issue #70
# found three such citations landing nowhere. Each had shipped; each is read at
# the moment a reader has just been refused something; and none of them was
# wrong in a way this suite could see, because nothing held a hook's pointer to
# the thing it points at.
#
# These are evidence about the citations named below and nothing else. A pointer
# added to a hook tomorrow is uncounted here, and so is any of these reworded,
# because every literal is the sentence as written. The count that sentence
# carried is gone rather than raised: #99 added a fourth citation, and a count
# corrected to four is the skill's `four acts` again, one file along.
#
# CONTEXT.md's entries are extracted rather than grepped whole, for the reason
# the boundary paragraph is narrowed above: a glossary-wide grep is satisfied by
# the word turning up in a neighbouring entry, which is the failure being fixed
# rather than a check on it -- #70's finding was that the lifetime rule was
# written down twice, in neither place a reader looking for vocabulary would go.
# An entry runs from its bolded name to its `_Avoid_:` line, and the extraction
# is checked from both ends before anything is asserted against it -- with one
# limit named, because the extractions below are not equally evidenced.
# *Reserved act* has an entry after it, so its `unarmed` is real evidence that
# the `_Avoid_:` stop fires. *Worktree branch* is the last entry in the file:
# nothing follows it for an over-run to swallow, so its `unarmed` tests only
# that the extraction did not begin too early, and the `_Avoid_:` stop is
# evidenced there by the other extraction rather than by its own. *Active dev
# branch* is the first entry, the mirror case: its `unarmed` is real evidence of
# the stop, and nothing before it can show a start that came too early.
CONTEXT_MD="$SUITE_DIR/../../CONTEXT.md"
SKILL_MD="$SUITE_DIR/../skills/branch-hygiene/SKILL.md"
entry() {  # entry <file> <bolded name> -- one glossary entry, name to _Avoid_
  awk -v name="**$2**:" '$0 == name {f=1} f {print} f && /^_Avoid_:/ {exit}' "$1" 2>/dev/null
}

WORKTREE_ENTRY="$FIXTURES/context-worktree-branch.md"
entry "$CONTEXT_MD" 'Worktree branch' > "$WORKTREE_ENTRY"
req GH-70.1 FR-27 US-24 FR-37
written 'the extracted entry is the worktree branch entry' \
  "$WORKTREE_ENTRY" '**Worktree branch**:'
unarmed 'and it is that entry rather than the whole glossary' \
  "$WORKTREE_ENTRY" '**Reserved act**:'

# no-work-on-stale-branch.sh sends a reader here for what a worktree branch is,
# and what that hook refuses is a commit on one whose pull request has merged.
# Before #70 the entry defined the branch and stopped, so a reader who followed
# the pointer learned everything about it except the fact the refusal turns on.
written 'the entry says the branch lives for one pull request' \
  "$WORKTREE_ENTRY" 'exists for exactly one pull request'
written 'and that the worktree it was made in is not reused after it' \
  "$WORKTREE_ENTRY" 'is not reused'

RESERVED_ENTRY="$FIXTURES/context-reserved-act.md"
entry "$CONTEXT_MD" 'Reserved act' > "$RESERVED_ENTRY"
req GH-70.3 FR-27 US-26
written 'the extracted entry is the reserved act entry' \
  "$RESERVED_ENTRY" '**Reserved act**:'
unarmed 'and it is that entry rather than the whole glossary' \
  "$RESERVED_ENTRY" '**Worktree branch**:'

# report-stale-branches.sh calls removing a worktree "a reserved act in
# CONTEXT.md" in its header, and prints the same claim into every session's
# transcript. The enumeration named four acts and that was not one of them.
req GH-70.3 FR-29 US-26
written 'the enumeration names the act the report cites' \
  "$RESERVED_ENTRY" 'removing a worktree or deleting a worktree branch'

# #97 widened the release rule from publishing and deleting to any write, and
# the two documents that state the rule are widened with it -- no-pr-decisions.sh
# refuses in their words, and a refusal narrower or wider than the document it
# points a reader to is the drift this section exists for. Both the new phrase
# and the absence of each old one are asserted, because a document that gained
# the new phrase and kept the old would state two rules.
#
# Asserted against the text with its line breaks joined. `written` and `unarmed`
# match within a line, and CLAUDE.md wraps "create or delete a" and "release"
# onto two lines, so an `unarmed` over the paragraph as written passes while the
# phrase still stands in it. Measured on dev-05: the absence check read ok there
# unjoined, and is red joined.
# An extraction that found nothing flattens to an empty file, and `unarmed` over
# an empty file reads ok. Each `unarmed` below is therefore paired with a
# `written` over the same file, which is the one that fails then.
flatten() {  # flatten <file> -- one line, every run of whitespace one space
  tr -s '[:space:]' ' ' < "$1"
}
RESERVED_FLAT="$FIXTURES/context-reserved-act.flat"
flatten "$RESERVED_ENTRY" > "$RESERVED_FLAT"
PARAGRAPH_FLAT="$FIXTURES/boundary-paragraph.flat"
flatten "$PARAGRAPH" > "$PARAGRAPH_FLAT"
req GH-97.2 FR-29
written 'the reserved act entry reserves any write to a release' \
  "$RESERVED_FLAT" 'any write to a release'
unarmed 'and no longer narrows it to publishing one' \
  "$RESERVED_FLAT" 'publishing a release'
written 'the boundary paragraph refuses any write to a release' \
  "$PARAGRAPH_FLAT" 'any write to a release'
unarmed 'and no longer narrows it to creating or deleting one' \
  "$PARAGRAPH_FLAT" 'create or delete a release'

# The skill read that enumeration as closed and counted it -- "one of the four
# acts CONTEXT.md names" -- and #70 found the count stale the moment a fifth act
# was needed. Correcting the number to five would have left the same defect with
# a later expiry date, so the count is gone from the skill altogether and the
# enumeration is cited instead of counted. CONTEXT.md holds the list, once. That
# is the pairing convention above -- argue once, point from the other place --
# applied to prose in a second file.
#
# Both spellings are refused, the stale one and the corrected one. Refusing
# `five acts` is the refusing direction on purpose: re-adding a count that is
# accurate today turns this red although nothing is wrong yet, and that is a
# failure which is visible and one edit away. A second copy of a count that is
# allowed to stand goes stale in silence, which is the direction that matters.
req GH-70.3
unarmed 'the skill does not carry the count that went stale' \
  "$SKILL_MD" 'four acts'
unarmed 'nor a corrected one, which would go stale the same way' \
  "$SKILL_MD" 'five acts'
written 'it cites the enumeration instead of counting it' \
  "$SKILL_MD" 'entry holds the list'

# The third citation, and the one that had gone unwritten rather than merely
# undocumented: both hooks name a local sweep as what removes a merged worktree
# branch, and no such procedure existed. The hooks are read for the citation
# and the skill asserted to answer it, rather than the sweep's existence being
# asserted on its own -- a procedure nothing cites is a procedure that can go.
#
# The literal is the pointer and deliberately not the noun. The first version of
# this check asked whether each header contained `sweep`, and both contained it
# at dev-05 already -- once in the guard, three times in the report. That bare
# word IS the dangling citation #70 found, so the check was satisfied by the
# defect: it would have stayed green through a revert of every line these two
# headers gained. Measured on `git show origin/dev-05:` copies of both files,
# which carry the noun and not the pointer.
req GH-70.2 FR-38
CITATION='"The sweep" in the branch-hygiene skill'
for hook in no-work-on-stale-branch.sh report-stale-branches.sh; do
  written "$hook points at the sweep by name" "$HOOKS/$hook" "$CITATION"
done

# Extracted for the reason the glossary entries are: `git branch -d` is in this
# file already, in the rotation, so a file-wide grep for it would pass with no
# sweep written at all. Stopping at the next `## ` and not at the next heading
# of any depth, because the sweep is numbered into steps the way the rotation
# is -- a stop on `### ` would end the section at its own first step and assert
# the rest of it against nothing.
SWEEP_SECTION="$FIXTURES/branch-hygiene-sweep.md"
awk '/^## The sweep/ {f=1; print; next} f && /^## / {exit} f {print}' \
    "$SKILL_MD" > "$SWEEP_SECTION"
written 'the extracted section is the sweep' "$SWEEP_SECTION" 'The sweep'
unarmed 'and it is that section rather than the rotation beside it' \
  "$SWEEP_SECTION" 'Create the new branch'

# What a sweep has to say to be the thing those two headers name: it deletes the
# local branch, it removes the worktree standing on it -- the act CONTEXT.md now
# reserves, and one that no command in this repository's documents performed
# before #70 -- and it takes the rotation's care over the same flag.
written 'the sweep removes the worktree' "$SWEEP_SECTION" 'git worktree remove'
written 'and deletes the local branch' "$SWEEP_SECTION" 'git branch -d'
# And unlocks it first, without which the other two cannot run here at all.
# Review of the first two commits found the procedure unable to execute on this
# repository: EnterWorktree locks every worktree it creates, `git worktree
# remove` refuses a locked one and names `remove -f -f` as the way out, and
# `git worktree prune` is exempted from locked worktrees by design -- so it
# skips one, exits 0, and the closing invariant is never reached with nothing
# saying why. Reproduced: all four worktrees present at the time carried
# `locked claude session <name> (pid N start T)`.
#
# THE LIMIT, which is the one that let that ship. Every literal in this section
# asks whether the section CONTAINS a command. None of them runs one, so none is
# evidence that the procedure succeeds -- a sweep naming three commands that all
# refuse would pass every check here. What guards the difference is a person
# running it; these hold the text against the citations, and nothing more.
written 'and unlocks it first, which is what makes the other two possible' \
  "$SWEEP_SECTION" 'git worktree unlock'
written 'and warns that prune will not rescue a worktree still locked' \
  "$SWEEP_SECTION" 'exempt from pruning by design'
written 'with the care the rotation takes over the same flag' \
  "$SWEEP_SECTION" 'never `-D`'
# The report classifies three ways and only one of the three is the sweep's. A
# sweep that acted on `unclassified` would delete a branch freshly cut for work
# not yet started, which is the case that classification exists to protect. The
# literal is the instruction and not the word: `unclassified` alone is satisfied
# by a section that says to sweep those too.
written 'and leaves the unclassified alone' \
  "$SWEEP_SECTION" 'Leave every unclassified branch alone'

# The cadence is the half that makes both hook headers honest. #70's complaint
# was not that the sweep was undocumented but that it "is named as a thing that
# happens", so a sweep written without its cadence would answer the citation and
# leave the claim behind it as false as it was. Pinned for that reason.
written 'the sweep says how often it is run, which is by hand and never' \
  "$SWEEP_SECTION" 'Cadence: manual, and unscheduled'

# Issue #100: the sweep defined its classes by pull request state and the report
# it acts on computed them from refs. The report now reads pull requests, and
# the section above drives it; what is asserted here is that the sweep's
# definitions name the wording the report prints for each class, which the
# report fixture above asserts as well. A definition that drifts from what the
# report prints turns one side or the other red.
req GH-100
written 'the sweep defines stale by what the report prints for a merged pull request' \
  "$SWEEP_SECTION" '`merged: pull request #N`'
written 'and for a closed one' \
  "$SWEEP_SECTION" '`closed without merging: pull request #N`'
written 'and unclassified by what it prints for a branch with no pull request' \
  "$SWEEP_SECTION" '`no pull request`'
written 'and for one that is not at or behind its pull request head' \
  "$SWEEP_SECTION" '`not at or behind its head`'
written 'and says what the classes are when the report could not read pull requests' \
  "$SWEEP_SECTION" '`pull requests: NOT READ`'
written 'where a gone upstream is stale by ref state' \
  "$SWEEP_SECTION" '`stale by ref state`'

# The sweep is not the only place the skill defines stale. *Report what is
# stale*, which an agent follows to produce the report a person reads, kept the
# definition #100 replaced -- merged or closed, and nothing about the head --
# through the change that fixed the sweep, because the checks above extract the
# sweep alone. Found on the second review of #120. That sentence erred toward
# deletion: a reused name after a merged pull request was stale by it and
# unclassified by the report. Extracted for the reason the sweep is: the head
# test is stated in the sweep already, so a file-wide grep would pass with this
# section still saying the old thing. Stopped at the next heading of depth two
# or three, which is `## Bertan's procedure`.
STALE_SECTION="$FIXTURES/branch-hygiene-report.md"
awk '/^### 2\. Report what is stale/ {f=1; print; next} f && /^###? / {exit} f {print}' \
    "$SKILL_MD" > "$STALE_SECTION"
req GH-100 US-29
written 'the extracted section is Report what is stale' \
  "$STALE_SECTION" 'Report what is stale'
unarmed 'and it stops before the procedure that follows it' \
  "$STALE_SECTION" "Bertan's procedure"
written 'it defines stale with the head test the report applies' \
  "$STALE_SECTION" "at or behind that pull request's head commit"
written 'and calls a name matched off a head it is ahead of unclassified' \
  "$STALE_SECTION" 'is unclassified, not stale'
# It also says its commands cover the last commit dates, which none of them
# printed; the second review of #120 found that too.
written 'and one of its commands prints the commit dates it says they cover' \
  "$STALE_SECTION" '%(committerdate:short)'

# #99, the fourth citation: where a new worktree branch starts. The report's
# header points at the rule and at the glossary entry beside the fetch that
# makes origin/dev-NN what it is, and the documents are held to answering it.
# A pointer only -- the argument stays in CLAUDE.md, and the header is asserted
# not to carry the routes, which are the part a retelling would copy.
REPORT_HEADER="$FIXTURES/report-header.txt"
awk 'NR == 1 { next } /^#/ { print; next } { exit }' \
    "$HOOKS/report-stale-branches.sh" > "$REPORT_HEADER"
req GH-99.1
written 'the extracted header is the report header' \
  "$REPORT_HEADER" 'THE ARMING PROPERTY IS NOT SELF-ANNOUNCING'
unarmed 'and it stops at the first line of code' "$REPORT_HEADER" 'FETCH_TIMEOUT='
written 'the report points at the rule for where a worktree branch starts' \
  "$REPORT_HEADER" 'WHERE A NEW WORKTREE BRANCH STARTS is a rule in CLAUDE.md, not argued here'
written 'and at the glossary entry that says what the tip is' \
  "$REPORT_HEADER" "CONTEXT.md's *active dev branch* entry"
unarmed 'and does not carry the first route itself' "$REPORT_HEADER" '--no-track'
unarmed 'nor the second' "$REPORT_HEADER" 'reset --hard'

# #99 Q1: what the tip is. The entry is where a reader of the pointer arrives.
ACTIVE_ENTRY="$FIXTURES/context-active-dev-branch.md"
entry "$CONTEXT_MD" 'Active dev branch' > "$ACTIVE_ENTRY"
req GH-99.1 FR-27 US-24
written 'the extracted entry is the active dev branch entry' \
  "$ACTIVE_ENTRY" '**Active dev branch**:'
unarmed 'and it is that entry rather than the whole glossary' \
  "$ACTIVE_ENTRY" '**Check**:'
written 'the entry says the tip is the remote-tracking ref as the last fetch left it' \
  "$ACTIVE_ENTRY" 'as the last fetch left it'
written 'and that the local dev branch is a working copy' \
  "$ACTIVE_ENTRY" 'is a working copy'
written 'which a worktree branch is never cut from' \
  "$ACTIVE_ENTRY" 'never cut from'

# #99 Q2: moving a local main or dev-NN is reserved, and like the sweep it is
# reserved without being refused. The entry names what passes every hook, the
# way it names `git worktree remove`, because an act nothing refuses is only
# reserved in a document a reader can find. Written apart from the enumeration
# literal checked above, which has to survive the addition unbroken.
req GH-99.1 US-26
written 'the enumeration reserves moving a local main or dev branch' \
  "$RESERVED_ENTRY" 'moving a local `main` or `dev-NN`'
written 'and names moving the ref without a push, which passes every hook' \
  "$RESERVED_ENTRY" 'git branch -f'
written 'and a fetch into the local branch, which passes every hook too' \
  "$RESERVED_ENTRY" 'git fetch origin dev-NN:dev-NN'

# #143: the same shape one spelling out. The clause above reserves moving a LOCAL
# main or dev-NN; this one reserves moving the active dev branch's REMOTE ref any
# way but forward, and it sits beside the act it extends at the head of the
# enumeration rather than at the end of it. Named here for GH-99.1's reason, that
# an act nothing refuses is only reserved in a document a reader can find. The
# rule that would refuse any of it is GH-143.1 to GH-143.3 and is not written
# yet, so this pins the document half only.
#
# Asserted against the FLATTENED entry, for the reason recorded at GH-97.2 above:
# a literal matches within a line, so a check over the entry as written is partly
# a check on where the paragraph happens to wrap. These three read
# $RESERVED_ENTRY when they were first written, and adding the clause
# mid-paragraph re-wrapped two literals pinned elsewhere in this file and turned
# three passing checks red -- which decided where the clause went. That is a
# document shaped to fit its check, and the fix was already 200 lines up. It is
# also why the placement above is free to be the one the entry reads best as.
#
# No count of the spellings neither layer covers is asserted, and the `unarmed`
# holds the entry to not carrying one. There were two when #143 was filed, three
# by the end of the session that filed it, and four once review of that session's
# commit measured `POST /repos/O/R/merges` -- an endpoint no hook names at all,
# which with a base of dev-05 advances the very ref the head of this enumeration
# reserves. The sentence that said "those two" was already wrong in the paragraph
# it stood in, which named a third two sentences later. A count is the part that
# goes stale, so the document states none and this says so.
#
# That is also the GH-97.2 pairing, and it is the pairing the first spelling of
# this block lacked: what it pinned was the clause's placement -- the absence of
# the terminating period the enumeration used to end on -- so it went red on a
# correct document with the clause moved, and added nothing against a revert,
# which the two `written` checks already catch between them. `unarmed` over an
# empty file reads ok, which is why it sits beside `written` calls over the same
# fixture and not alone. It catches a count coming back, and deliberately not a
# later sentence that contradicts the clause while leaving its words intact --
# that is the half no text check reaches, and it is #145's.
req GH-143.4 US-26
written 'the enumeration reserves moving the remote dev ref another way, or deleting it' \
  "$RESERVED_FLAT" 'any way other than advancing it, or deleting that ref'
written 'and says nothing refuses either at all, which is what leaves them reserved only' \
  "$RESERVED_FLAT" 'Nothing refuses a remote force-move or deletion'
written 'and names the REST merge that advances the same ref under no rule at all' \
  "$RESERVED_FLAT" 'a REST merge of any'
unarmed 'and counts none of the acts that neither a hook nor the server covers' \
  "$RESERVED_FLAT" 'the only acts'

# CLAUDE.md's *Domain docs* section said "docs/adr/ holds one ADR", and the ADR
# that states the decision above made it false in the same commit. Nothing held
# it: a grep for docs/adr across this suite returned nothing at all, so the one
# sentence in CLAUDE.md that warns about a stale enumeration -- "the sentence
# that did named two terms of five and went stale without saying so" -- was
# carrying a count of its own, unpinned, one clause to the left. That is the
# drift class 0002 is about, arriving in the document that describes where 0002
# lives, which is why it is pinned here rather than left to the next reader.
#
# The pairing is GH-97.2's, and here the superseded wording is a narrower claim
# rather than a narrower rule: a section that gained the directory and kept the
# count would say both. Flattened for the same reason as the entry above.
DOMAIN_SECTION="$FIXTURES/claude-md-domain-docs.md"
awk '/^### Domain docs$/ {f=1; print; next}
     f && /^#/ {exit}
     f {print}' "$CLAUDE_MD" > "$DOMAIN_SECTION"
DOMAIN_FLAT="$FIXTURES/claude-md-domain-docs.flat"
flatten "$DOMAIN_SECTION" > "$DOMAIN_FLAT"
req GH-143.5
written 'the extracted section is the domain docs section' \
  "$DOMAIN_FLAT" '### Domain docs'
unarmed 'and it is that section rather than the whole file' \
  "$DOMAIN_FLAT" '### Triage labels'
written 'the domain docs section points at the ADR directory' \
  "$DOMAIN_FLAT" '`docs/adr/` holds the ADRs'
unarmed 'and states no count of what is in it' \
  "$DOMAIN_FLAT" 'holds one ADR'

# #99 Q9 and Q13: the rule, in the boundary section this suite already
# extracted and checked from both ends. Both routes, the qualifier that keeps
# the second one from discarding a worktree's commits, and the sentence saying
# nothing enforces it -- with the one assumption the refusal of a skipped step
# rests on, which is what the report's main ancestry line reads.
req GH-99.1 FR-37
written 'the boundary section gives the first route, untracked' \
  "$SECTION" 'git worktree add --no-track -b <branch> <path> origin/dev-NN'
written 'and the second' "$SECTION" 'git reset --hard origin/dev-NN'
written 'and confines the second to a worktree EnterWorktree has just created' \
  "$SECTION" 'just created'
written 'and says that nothing enforces the rule' "$SECTION" 'Nothing enforces'
written 'and what a skipped step rests on instead' \
  "$SECTION" 'only while `origin/main` is an ancestor'
written 'and points at the glossary rather than re-arguing it' \
  "$SECTION" '*active dev branch*'
# Pointing, not re-arguing, counted in the direction a retelling takes: the
# commands that pass every hook are the glossary's to list, once. Counted over
# the whole of CLAUDE.md rather than the section, which is stricter.
tok 'CLAUDE.md does not restate the glossary'"'"'s fetch into a local branch' \
    '0' "$(prose_count "$CLAUDE_MD" 'git fetch origin dev-NN:dev-NN')"
tok 'nor its forced branch move' \
    '0' "$(prose_count "$CLAUDE_MD" 'git branch -f')"
# #99 Q13: not a sixth consequence. Those are consequences of the hooks, and
# this rule has no hook. $LEFT_OPEN is a string, so the string helpers.
req GH-99.1 GH-73
holds 'the extracted list is the left-open list' "$LEFT_OPEN" 'Deliberately left open'
lacks 'and the unenforced rule is not one of its items' \
  "$LEFT_OPEN" 'git reset --hard origin/dev-NN'

# CONSEQUENCE 6, and the half of it that is not a count. The item above answers
# recommendation 4 of #117's triage, which called the question a judgement call
# to settle before implementing. It was settled by measuring, and what a later
# reader needs from this suite is that the paragraph still names the three
# shapes it decided about -- a sixth item that kept its number and lost
# `$VAR`, say, would pass the count check beside it and say something else.
#
# The verdicts themselves are pinned below rather than here, where they are
# what a hook answers rather than what a document says. Both halves are needed:
# the document without the verdicts is a claim nobody ran, and the verdicts
# without the document are three permitted commands with no reason attached.
req GH-117.1
holds 'consequence 6 names the command substitution spelling' \
  "$LEFT_OPEN" '$(command -v gh) pr merge 5'
holds 'and the backtick spelling' \
  "$LEFT_OPEN" '`command -v gh` pr merge 5'
holds 'and the parameter spelling' \
  "$LEFT_OPEN" '$GH pr merge 5'
# The measurement, not just the decision. #117 settled this by counting, and a
# claim without its number is a claim to re-measure -- so the corpus size is in
# the paragraph and is held there, which is what stops the item decaying into
# "we decided not to".
holds 'and says what corpus the decision was measured against' \
  "$LEFT_OPEN" '75,346'
# The rejected close, held in the paragraph for the reason every rejected
# alternative in this repository is written down: without it the next reviewer
# reads an accepted gap and proposes the one-line fix that was already measured
# and found to close nothing.
holds 'and records that the close was written and rejected on its numbers' \
  "$LEFT_OPEN" 'The close was written first and rejected on its own numbers.'
# THE LINE THE ITEM DRAWS, which its first draft drew in the wrong place: it
# offered `"$VENV/bin/gh"` as an example of a permitted variable, and the same
# commit refused it -- the reduction resets at each slash, so the word spells
# `gh`. A permitted `$VAR` is one that is the WHOLE word. The verdict is pinned
# below; this holds the document to saying which, so the example and the
# behaviour cannot drift apart again.
holds 'and draws the line at a variable that is the whole word' \
  "$LEFT_OPEN" 'A variable is only unresolved while it is the whole word.'

# #99 Q5 took `head` out of settings.json, and the branch-hygiene skill's notes
# went on arguing from it: every worktree made after a rotation branched from
# the new dev branch because it forked from HEAD. Found on review of #99, not by
# this suite. The value is refused
# rather than the sentence, because the sentence can be reworded around it.
req GH-99.2
unarmed 'the branch-hygiene skill does not describe worktrees forking from HEAD' \
  "$SKILL_MD" 'worktree.baseRef: head'

# The count removed from this section's head, held removed. Split across two
# quoted words so that this line does not contain the phrase it refuses.
req GH-99.1
unarmed 'this section'"'"'s head no longer counts its citations at three' \
  "$SUITE_DIR/check-hooks.sh" "three citations"" named below"
unarmed 'nor at four, the number a correction would have reached for' \
  "$SUITE_DIR/check-hooks.sh" "four citations"" named below"
echo "--- issue #105: CONTEXT.md defines check and probe against each other ---"
# FR-11. The distinction this suite's own header cites -- "Check, not probe" --
# and the collision CONTEXT.md was started for (#38). It is a PAIR of
# definitions, and a pair is what a one-sided pin cannot hold: either entry
# alone reads perfectly well with the other deleted, and the word this
# repository actually confused would be back in use the same week. So both are
# extracted, each is asked for its own test, and each is asked for the other's
# name in its `_Avoid_` line -- which is the half that makes them define each
# other rather than merely stand beside each other.
CHECK_ENTRY="$FIXTURES/context-check.md"
PROBE_ENTRY="$FIXTURES/context-probe.md"
entry "$CONTEXT_MD" 'Check' > "$CHECK_ENTRY"
entry "$CONTEXT_MD" 'Probe' > "$PROBE_ENTRY"
# Tagged FR-11 alone. FR-27 names *worktree branch*, *active dev branch* and
# *reserved act*, and US-24 asks for the branch words; neither is what these two
# entries say, and a check tagged with an ID it does not establish covers that ID
# all the same -- the one dilution requirements.md names and no check can catch.
# Found by review of this change.
req FR-11
written 'the extracted entry is the check entry' "$CHECK_ENTRY" '**Check**:'
unarmed 'and it is that entry rather than the pair' "$CHECK_ENTRY" '**Probe**:'
written 'the extracted entry is the probe entry' "$PROBE_ENTRY" '**Probe**:'
unarmed 'and it is that entry rather than the rest of the glossary' \
  "$PROBE_ENTRY" '**Reserved act**:'
written 'a check has its expected verdict written out in advance' \
  "$CHECK_ENTRY" 'written out in advance'
written 'so running it can only agree or disagree with what was already claimed' \
  "$CHECK_ENTRY" 'only agree or disagree with what was already claimed'
written 'and every assertion in this suite is one' \
  "$CHECK_ENTRY" '`.claude/hooks/check-hooks.sh` is a check.'
written 'a probe has no answer until it runs' \
  "$PROBE_ENTRY" 'not known until it runs'
written 'and each scripts/probe_*.py is one' "$PROBE_ENTRY" '`scripts/probe_*.py` is a probe'
written 'the check entry warns against calling one a probe' "$CHECK_ENTRY" '_Avoid_: probe'
written 'and the probe entry against calling one a check' "$PROBE_ENTRY" '_Avoid_: check'

echo "--- issue #105: the worktree branch entry records what the boundary keys on ---"
# FR-28. The same entry the #70 block above extracts, asked its other half --
# and the half a reader following no-git-push.sh's pointer arrives for. The rule
# keys on where the command runs, and the entry has to say so, and say why: "do
# not fix this into a rule about the name" holds only while the two reasons
# behind it are legible. A naming rule is what someone reaches for first, being
# shorter and reading as tidier, and the entry's answer is that it is wrong
# twice over. Both halves of that count are pinned, because one of them alone
# leaves the instruction looking like a preference.
#
# FR-28 alone. It was `req FR-28 US-24 FR-27` until Bertan's review of #132 --
# the same dilution found on the FR-11 block one round earlier, surviving one
# round of looking for it. These eight checks read the keying rationale, which is
# FR-28's text and no one else's; US-24 asks for the branch words and FR-27 names
# three terms this block does not establish, and both are covered by the #70
# block above, so the extra tags bought nothing and claimed something.
req FR-28
written 'the entry says the permission keys on where the command runs' \
  "$WORKTREE_ENTRY" 'keys on **where the command runs**'
written 'and deliberately not on what the branch is called' \
  "$WORKTREE_ENTRY" 'deliberately not on what the'
written 'it names the comparison the hook makes' \
  "$WORKTREE_ENTRY" 'compares `git rev-parse'
written 'against the other half of that comparison' \
  "$WORKTREE_ENTRY" '--git-dir` with `--git-common-dir`'
written 'and says a naming rule was available and is wrong twice over' \
  "$WORKTREE_ENTRY" 'naming rule was available and is wrong twice over'
written 'the first reason: the two ways a worktree is made here disagree on the prefix' \
  "$WORKTREE_ENTRY" 'so a prefix rule would disagree between them'
written 'the second: a branch in the main checkout can be given the name the rule looks for' \
  "$WORKTREE_ENTRY" 'can be given whatever name the rule looks for'
written 'and it tells the next reader not to fix it into one' \
  "$WORKTREE_ENTRY" '"fix" this into a rule about the name.'

echo "--- issue #105: the rotation is Bertan's, and the agent's half is reads ---"
# US-27, US-28, FR-24, FR-25 and FR-26. The sweep half of this skill is already
# checked, by #100's block above and by the housekeeping generator's section
# below; the rotation half and the invariant the file opens with were read by
# nothing. What US-27 asks is that an agent following the skill does not run a
# procedure whose middle steps are refused, so the strongest form of the check
# is not a literal at all: it is the skill's own commands, put through the hooks.
# That is what the last part of this block does. The literals before it are for
# the claims no command can carry -- whose the procedure is, and why.
HYGIENE_HEAD="$FIXTURES/branch-hygiene-head.md"
awk '/^# Branch hygiene$/ {f=1} f && /^## What an agent does$/ {exit} f {print}' \
    "$SKILL_MD" > "$HYGIENE_HEAD"
req FR-26 US-28 FR-24
written 'the extracted head is the opening of the skill' \
  "$HYGIENE_HEAD" '# Branch hygiene'
unarmed 'and it stops before what an agent does' \
  "$HYGIENE_HEAD" '## What an agent does'
# FR-26, the invariant. Three terms and a count, and the count is the part that
# reads as a mess to tidy when it is not written down.
#
# FR-26 says the invariant is one active dev branch PLUS `main`, with worktree
# branches in flight against the former, so each of those three components is
# asked for separately and each label names only what its own literal
# establishes. The first row used to read "names main and exactly one active dev
# branch" while asking only for the count: deleting `main` from the invariant
# left all 1987 checks green, under a label that said `main` was checked. Found
# by Bertan's second review of #132. The label described the requirement and the
# literal described less, which is the same defect as a tag naming a requirement
# its check does not establish -- one sentence further down.
written 'the invariant names main, and exactly one active dev branch beside it' \
  "$HYGIENE_HEAD" 'holds `main`, exactly one **active dev branch**'
written 'and gives that branch the name the rest of the file uses' \
  "$HYGIENE_HEAD" 'named `dev-NN`'
written 'with however many worktree branches in flight against it' \
  "$HYGIENE_HEAD" 'however many **worktree branches** are in flight against it'
written 'and sends a reader to CONTEXT.md for all three terms' \
  "$HYGIENE_HEAD" 'defines all three terms'
# US-28 and FR-24: whose the rotation is, and that it is reserved rather than
# merely discouraged.
written 'rotation is declared a reserved act in the skill'"'"'s own words' \
  "$HYGIENE_HEAD" '**Rotation is a reserved act, and so are the sweep'
written 'and the skill cites the entry that holds the list rather than counting it' \
  "$HYGIENE_HEAD" '*reserved act* entry holds the list'
written 'it says the hooks refuse both pushes a rotation needs, and are right to' \
  "$HYGIENE_HEAD" 'refuses both of the pushes a rotation needs'
written 'and that Bertan runs it where no hook applies' \
  "$HYGIENE_HEAD" 'Bertan runs the procedure'
written 'from his own terminal' "$HYGIENE_HEAD" 'from his own terminal, where no hook applies.'
# FR-25 and US-29: the half that stays, and that it is a read of the remote
# rather than of the command that ran.
AGENT_SECTION="$FIXTURES/branch-hygiene-agent.md"
awk '/^## What an agent does$/ {f=1} f && /^## Bertan/ {exit} f {print}' \
    "$SKILL_MD" > "$AGENT_SECTION"
req FR-25 US-27 US-29
written 'the extracted section is what an agent does' \
  "$AGENT_SECTION" '## What an agent does'
unarmed 'and it stops before the procedure that is not an agent'"'"'s' \
  "$AGENT_SECTION" "## Bertan's procedure"
written 'both steps are reads, and the agent stops after them' \
  "$AGENT_SECTION" 'Both steps are reads. Report the answers and stop'
written 'naming the four acts it is not to take, nor offer to' \
  "$AGENT_SECTION" 'push or delete anything, and do not offer to.'
written 'the merge is confirmed from the remote, never from the command that ran' \
  "$AGENT_SECTION" 'Never take "the merge command ran" as evidence'
written 'and the two fields that confirm it are named' \
  "$AGENT_SECTION" '`state` must be `MERGED` and `mergedAt` must be non-null'
written 'the sweep below is named as the other half, and not an agent'"'"'s' \
  "$AGENT_SECTION" 'an agent that has produced the'
# US-27 and FR-24, driven rather than read: every command the agent's half
# instructs is put through the two hooks that judge these surfaces, from a linked
# worktree, and must be permitted. A skill whose middle step is refused is the
# failure the story names, and no literal above would catch one arriving -- the
# commands sit in fenced blocks nothing reads. The blocks are fed whole, as a
# session would paste them, so a continuation line is judged joined to its
# opener the way the hook would see it.
#
# It reads $AGENT_SECTION, which the extraction above has already bounded and
# which the `written`/`unarmed` pair above has already checked from both ends --
# not $SKILL_MD with the heading pair written a second time. The first draft did
# walk it twice, with two awk programs carrying the same two headings, so one
# renaming would have had to be fixed in two places and the second copy would
# have gone on extracting whatever it still matched. That is #84's shape arriving
# in the change that cites it; found by review.
# The fence spellings this extraction reads. It read ```bash and nothing else
# until Bertan's second review of #132, and the defect was not that a spelling
# was missing -- it was that an unknown one was SKIPPED IN SILENCE. He put an
# ```sh block carrying `git push origin --delete dev-05` into the agent section
# and all 1987 checks stayed green, under a check whose own label reads "permits
# every command the agent half instructs". Spelled ```bash, the same line turns
# it red: the driven check was right and was simply never shown the command.
#
# Widening the list alone would move the hole rather than close it, ```console or
# a bare fence being the next one skipped. So the list is widened AND the
# extraction is made total by the guard below. A block the extraction cannot see
# is a block the hooks are never asked about, and a question asked of some of the
# material and reported as asked of all of it is #84's shape once more.
SHELL_FENCES='bash|sh|shell|zsh'
fenced_shell() {  # fenced_shell <langs> <file> -- the body of every shell block
  awk -v langs="$1" '
    BEGIN { n = split(langs, a, "|"); for (i = 1; i <= n; i++) ok["```" a[i]] = 1 }
    { if (inb) { if ($0 == "```") inb = 0; else print }
      else if ($0 in ok) inb = 1 }' "$2" 2>/dev/null
}
unread_fences() {  # unread_fences <langs> <file> -- the openers it would skip
  awk -v langs="$1" '
    BEGIN { n = split(langs, a, "|"); for (i = 1; i <= n; i++) ok["```" a[i]] = 1 }
    /^```/ { if (inb) { inb = 0; next }
             inb = 1
             if (!($0 in ok)) print (length($0) > 3 ? substr($0, 4) : "(bare)") }' \
    "$2" 2>/dev/null | sort -u | tr '\n' ' '
}
AGENT_CMDS=$(fenced_shell "$SHELL_FENCES" "$AGENT_SECTION")
# An empty extraction would pass both checks below without asking anything, and
# it is one renamed heading away.
printf '%s' "$AGENT_CMDS" | grep -q 'gh pr view' || {
  echo "no commands were read out of the branch-hygiene agent section; the checks below prove nothing" >&2
  exit 1
}
# And a partial extraction would pass them while asking less than it reports, so
# an opener this does not read stops the suite rather than failing one check.
# That is the idiom the two guards above use and it is the stronger answer: the
# trade, taken knowingly, is that a genuinely non-command fence added to this
# section -- sample output under ```text, say -- stops the suite until it is
# either named here or moved. The section is a procedure and its blocks are
# commands, so that is a cheap price for never silently reading part of it.
UNREAD_FENCES=$(unread_fences "$SHELL_FENCES" "$AGENT_SECTION")
[ -z "$UNREAD_FENCES" ] || {
  echo "the branch-hygiene agent section carries fenced blocks this extraction does not read: $UNREAD_FENCES-- the commands in them would never reach the hooks, so the checks below prove less than they say" >&2
  exit 1
}
req US-27 FR-24
check_in "$PUSH_WT" no-git-push.sh ALLOW \
  'no-git-push.sh permits every command the agent half instructs' "$AGENT_CMDS"
check_in "$PUSH_WT" no-pr-decisions.sh ALLOW \
  'no-pr-decisions.sh permits them too' "$AGENT_CMDS"
# The other direction, and the claim the head makes in as many words: the two
# pushes a rotation needs are refused, from a linked worktree as from anywhere.
#
# Written out here rather than extracted, and the reason is about WHERE the
# placeholder sits rather than about running anything -- nothing here is run, and
# the agent block above is fed `gh pr view <PR#>`, which no shell would accept
# either. `<PR#>` sits in an argument position no rule reads, so it is judged
# exactly as a number would be. `dev-NN+1` sits in the branch-name position,
# which is the one thing the push rule does read, so feeding the rotation block
# as written would ask these hooks about a branch name no rotation ever uses.
# These are what Bertan would run once he has substituted. Found by review, which
# read the first version of this comment and the agent block against each other.
req US-28 FR-24
check_in "$PUSH_WT" no-git-push.sh BLOCK \
  'the first push of the new dev branch is refused' 'git push -u origin dev-06'
check_in "$PUSH_WT" no-git-push.sh BLOCK \
  'and the remote deletion of the merged one' 'git push origin --delete dev-05'

section "=== the tokeniser's header names every hook that sources it ==="
# The same audit the section above gets, pointed at the one other sentence in
# this tree that claims to list the hooks. lib/command-scan.sh opens "which is
# every hook that reads a command", and that claim has now gone stale twice:
# #63 found it naming three of the four that sourced the file, and #69 found
# two more that read a command and were not on the list because they did not
# source it at all -- true of the hooks it knew about, false of the repository.
# A sentence that has gone stale twice is checked rather than maintained.
#
# It sits here, after the section above, because it uses that section's
# `present`. Written where it belongs by subject, it ran before the helper
# existed: twelve `present: command not found` lines, no FAILED set, and the
# suite green. A check that cannot fail is the thing this file is most for.
#
# The paragraph is the first comment block, which is where the claim is made;
# the rest of the header is history and names files for other reasons.
CS_LIB="$HOOKS/lib/command-scan.sh"
# Written once, because this suite's own header is audited the same way below.
first_comment_block() {  # first_comment_block <file> -- after the shebang, up to the first bare #
  awk 'NR == 1 { next } /^#$/ { exit } /^#/ { print; next } { exit }' "$1" 2>/dev/null
}
req GH-63
CS_HEADER=$(first_comment_block "$CS_LIB")
CS_NAMED=$(printf '%s\n' "$CS_HEADER" | grep -oE '[A-Za-z0-9_-]+\.sh' | sort -u | tr '\n' ' ')
# Who actually sources it, read off the disk rather than listed here.
#
# Two questions, answered in the order they bite. The needle is the bare file
# name rather than the path as a hook spells it when it assigns LIB, because
# keying on one spelling means a hook that sources it differently drops out of
# this audit silently -- which is the failure the audit exists for. But the
# loose needle then matches a file that only MENTIONS the library in a comment,
# and append-only-docs-edit.sh does exactly that: it says in prose why its path
# normaliser carries no cs_ prefix. So comments are stripped first, the way
# `armed` strips them, and what is left is the file as it runs.
CS_SOURCERS=$(for f in "$HOOKS"/*.sh; do
    sed 's/[[:space:]]*#.*$//' "$f" 2>/dev/null | grep -qF 'command-scan.sh' \
      && printf '%s\n' "${f##*/}"
  done | sort -u | tr '\n' ' ')
# The tooling beside the hooks NAMES that path without loading it, and neither
# file is a consumer. This suite reads it to run this audit; mutate-hooks.sh
# names it as the target of several registered mutations (#107). The exception is
# $TOOLING rather than a list written again here, for the reason the list exists:
# a second spelling of one fact is the one that goes stale. The needle stays the
# loose one -- a hook that sources the library by some other spelling has to stay
# in this audit, which is the failure it exists for -- so what is written down is
# who may mention the file without loading it.
CS_NOT_CONSUMERS=$TOOLING
CS_SOURCERS=$(for f in $CS_SOURCERS; do
    case " $CS_NOT_CONSUMERS " in *" $f "*) continue ;; esac
    printf '%s\n' "$f"
  done | tr '\n' ' ')
[ -n "$CS_NAMED" ] && [ -n "$CS_SOURCERS" ] || {
  echo "no hook names were read out of the tokeniser header or off the disk; the checks below prove nothing" >&2
  exit 1
}
set -f
for hook in $CS_SOURCERS; do
  present "the header names $hook, which sources the tokeniser" "$hook" "$CS_NAMED"
done
# The other direction: a name in the paragraph that no longer sources the file.
# check-hooks.sh is named in it as the thing running this audit, which is why it
# is dropped from the list above rather than from the paragraph.
for hook in $CS_NAMED; do
  case "$hook" in check-hooks.sh|command-scan.sh) continue ;; esac
  present "the header names $hook, and that file sources the tokeniser" \
          "$hook" "$CS_SOURCERS"
done
set +f

section "=== the housekeeping generator prints only what the sweep and rotation permit ==="
# .claude/skills/housekeeping/housekeeping-commands.sh turns the report into
# commands for Bertan to run: `git worktree remove`, `git branch -d` and
# `git push origin --delete`. It runs none of them, but a person pasting its
# output runs all of them, so what it prints is held here the way a hook's
# verdict is -- as a process, against a fixture, with the expected lines written
# out. Its header argues the rules; this section is their evidence.
#
# Review of #126 found two defects with the suite green, because nothing here
# ran the generator. A rotated-past dev branch was printed a local and a remote
# delete on the report's word alone, with its pull request into main still open
# and its commits in no other branch; `-d` let it through, because it accepts a
# branch merged into its own upstream. And a stale lock was unlocked after the
# one `git worktree prune`, so its entry was left behind. Both repros are rows
# of the fixture below, and the printed plan is executed at the end, because a
# check that a plan CONTAINS a command is no evidence that the plan succeeds --
# the limit the sweep section names for its own literals.
#
# The generator and the real report are copied into a fixture repository whose
# origin is a bare repository beside it, as the #100 section does. gh is a
# stand-in answering the report's read and the generator's read from separate
# files, dispatched on the fields asked for. The --jq filters are not run by it
# and are pinned as literals at the end.
HK_GEN="$SUITE_DIR/../skills/housekeeping/housekeeping-commands.sh"
HK="$FIXTURES/hk"
HK_ORIGIN="$FIXTURES/hk-origin.git"
HK_BIN="$FIXTURES/hk-bin"
HK_DIR="$FIXTURES/hk worktrees"
mkdir -p "$HK_BIN" "$HK_DIR"
git init -q -b main "$HK"
HG="git -C $HK -c user.email=checks@example.invalid -c user.name=checks"
$HG commit -q --allow-empty -m base
HK_BASE=$($HG rev-parse HEAD)
hk_commit() { $HG commit-tree -p "$2" -m "$1" "$HK_BASE^{tree}"; }
# dev-02, dev-03 and dev-05 are in main; dev-01 and dev-04 each carry a commit
# main does not. dev-04 is cut from dev-03, as each dev branch is cut after the
# one before it merged: the plan's `git branch -d dev-03` runs from a checkout
# standing on dev-04, and `-d` refuses a branch its HEAD does not contain.
HK_DEV01=$(hk_commit dev-01 "$HK_BASE")
HK_DEV02=$(hk_commit dev-02 "$HK_BASE")
HK_DEV03=$(hk_commit dev-03 "$HK_BASE")
HK_DEV04=$(hk_commit dev-04 "$HK_DEV03")
HK_DEV05=$(hk_commit dev-05 "$HK_BASE")
HK_MAIN=$($HG commit-tree -p "$HK_BASE" -p "$HK_DEV02" -p "$HK_DEV03" -p "$HK_DEV05" \
  -m "merge dev-02, dev-03 and dev-05" "$HK_BASE^{tree}")
$HG update-ref refs/heads/main "$HK_MAIN"
$HG branch dev-01 "$HK_DEV01"
$HG branch dev-02 "$HK_DEV02"
$HG branch dev-03 "$HK_DEV03"
$HG branch dev-04 "$HK_DEV04"
$HG branch dev-05 "$HK_DEV05"
for b in hk-merged hk-dirty hk-broken hk-live hk-plain hk-gone hk-gone-unclassified \
    hk-gone-open hk-closed; do
  $HG branch "$b" "$HK_BASE"
done
git clone -q --bare "$HK" "$HK_ORIGIN"
$HG remote add origin "$HK_ORIGIN"
$HG fetch -q origin
mkdir -p "$HK/.claude/hooks" "$HK/.claude/skills/housekeeping"
cp "$HOOKS/report-stale-branches.sh" "$HK/.claude/hooks/"
cp "$HK_GEN" "$HK/.claude/skills/housekeeping/"
echo '.claude/' >> "$HK/.git/info/exclude"
# The main checkout stands on dev-04, the shape of the #126 repro.
$HG checkout -q dev-04
for b in hk-merged hk-dirty hk-broken hk-live hk-gone hk-gone-unclassified hk-gone-open dev-02; do
  $HG worktree add -q "$HK_DIR/$b" "$b"
done
$HG worktree add -q --detach "$HK_DIR/detached" "$HK_BASE"
for d in hk-merged hk-dirty hk-broken hk-live hk-gone hk-gone-unclassified hk-gone-open \
    dev-02 detached; do
  need_worktree "$HK_DIR/$d" "housekeeping $d"
done
HK_DIR=$(cd -P "$HK_DIR" && pwd)
# Paths as the generator prints them: %q, and the only character in these that
# it escapes is the space.
HK_Q=${HK_DIR// /\\ }
touch "$HK_DIR/hk-dirty/untracked"
# A worktree whose status cannot be read: its .git file points nowhere, so
# `git -C <it> status` fails, and empty output from a failed read is not a clean
# tree. The first version read it as one.
echo 'gitdir: /nonexistent/hk-broken' > "$HK_DIR/hk-broken/.git"
# Live: this suite's own process and its real start time. Stale: the same pid
# with a start time it never had, which is a pid handed to something else; and a
# pid above any pid_max, which is a process that is gone.
HK_SELF_START=$(awk '{ sub(/^.*\) /, ""); print $20 }' "/proc/$$/stat" 2>/dev/null)
$HG worktree lock --reason "claude session live (pid $$ start $HK_SELF_START)" "$HK_DIR/hk-live"
$HG worktree lock --reason "claude session reused (pid $$ start 1)" "$HK_DIR/hk-merged"
# hk-gone-open is the case the report cannot help with: a branch with an open
# pull request is clear, so the report never names it, and only the generator's
# own test for a branch keeps its worktree's lock. A mutation that dropped that
# test passed the suite until this row was added; the unclassified row is named
# by the report and skipped before the test is reached.
for d in hk-gone hk-gone-unclassified hk-gone-open detached; do
  $HG worktree lock --reason "claude session gone (pid 4194399 start 1)" "$HK_DIR/$d"
  rm -rf "${HK_DIR:?}/$d"
done

cat > "$HK_BIN/gh" <<'GH'
#!/bin/bash
# The settings as required; the report's pull request read from HK_PRS_REPORT
# and the generator's from HK_PRS_GEN, told apart by the one field only the
# generator asks for. An unset file is a failed read.
case "$1" in
  api) printf 'false\tfalse\ttrue\n' ;;
  pr)
    case "$*" in
      *baseRefName*) [ -n "$HK_PRS_GEN" ] && cat "$HK_PRS_GEN" ;;
      *)             [ -n "$HK_PRS_REPORT" ] && cat "$HK_PRS_REPORT" ;;
    esac ;;
  *) exit 1 ;;
esac
GH
chmod +x "$HK_BIN/gh"
# The report's columns: head, state, number, head commit.
HK_PRS_R="$FIXTURES/hk-prs-report.tsv"
printf '%s\t%s\t%s\t%s\n' \
  hk-merged MERGED 1 "$HK_BASE" \
  hk-dirty MERGED 2 "$HK_BASE" \
  hk-live MERGED 3 "$HK_BASE" \
  hk-plain MERGED 4 "$HK_BASE" \
  hk-gone MERGED 5 "$HK_BASE" \
  hk-closed CLOSED 6 "$HK_BASE" \
  hk-broken MERGED 11 "$HK_BASE" \
  hk-gone-open OPEN 13 "$HK_BASE" > "$HK_PRS_R"
# The generator's columns: number, head, base, state. dev-04 is the #126 repro:
# its pull request into main open, and another open against it. dev-01's merged,
# and it carries a commit since that main does not have. dev-02 and dev-03 are
# merged and contained; dev-02 alone is checked out somewhere.
HK_PRS_BASE="$FIXTURES/hk-prs-gen-base.tsv"
printf '%s\t%s\t%s\t%s\n' \
  12 dev-01 main MERGED \
  7 dev-02 main MERGED \
  8 dev-03 main MERGED \
  9 dev-04 main OPEN \
  10 hk-on-dev-04 dev-04 OPEN > "$HK_PRS_BASE"
HK_PRS_HELD="$FIXTURES/hk-prs-gen-held.tsv"
HK_PRS_DUE="$FIXTURES/hk-prs-gen-due.tsv"
cp "$HK_PRS_BASE" "$HK_PRS_HELD"
printf '20\tdev-05\tmain\tMERGED\n21\thk-in-flight\tdev-05\tOPEN\n' >> "$HK_PRS_HELD"
cp "$HK_PRS_BASE" "$HK_PRS_DUE"
printf '20\tdev-05\tmain\tMERGED\n' >> "$HK_PRS_DUE"

hk_run() {  # hk_run <repo> <report prs file> <generator prs file> -- output, then the exit status
  ( cd / && PATH="$HK_BIN:$PATH" HK_PRS_REPORT="$2" HK_PRS_GEN="$3" \
      bash "$1/.claude/skills/housekeeping/housekeeping-commands.sh" 2>/dev/null
    echo "exit=$?" )
}
HK_NOTDUE=$(hk_run "$HK" "$HK_PRS_R" "$HK_PRS_BASE")
HK_HELD=$(hk_run "$HK" "$HK_PRS_R" "$HK_PRS_HELD")
HK_DUE=$(hk_run "$HK" "$HK_PRS_R" "$HK_PRS_DUE")
# Seven worktree branches and four rotated-past dev branches are stale; main,
# dev-05 and hk-gone-open are clear; hk-gone-unclassified has no pull request.
case "$HK_NOTDUE" in *'# report: 3 other branch(es) are clear; 11 stale, 1 unclassified.'*) ;; *)
  echo "the housekeeping fixture's report did not classify its branches as built; the checks against it prove nothing" >&2
  printf '%s\n' "$HK_NOTDUE" >&2
  exit 1 ;;
esac

echo "--- the sweep ---"
req GH-70.2
holds 'a merged worktree with a stale lock is unlocked, removed, then its branch deleted' "$HK_NOTDUE" \
"# hk-merged -- pull request #1
git worktree unlock $HK_Q/hk-merged
git worktree remove $HK_Q/hk-merged
git branch -d hk-merged"
holds 'a merged branch in no worktree is deleted' "$HK_NOTDUE" \
"# hk-plain -- pull request #4, no worktree
git branch -d hk-plain"
# The second #126 finding. Every unlock stands before the one prune: a merged
# branch's gone worktree and a detached one's, whose unlock the first version
# printed after that prune.
holds 'gone worktrees: every unlock, then one prune, then the branch deletes' "$HK_NOTDUE" \
"# worktree entries whose directory is gone: every unlock before the one prune
git worktree unlock $HK_Q/hk-gone
git worktree unlock $HK_Q/detached
git worktree prune
git branch -d hk-gone"
tok 'and the prune is printed once' '1' "$(printf '%s\n' "$HK_NOTDUE" | grep -cxF 'git worktree prune')"
lacks 'a gone worktree whose branch is not merged is not unlocked' "$HK_NOTDUE" \
  "git worktree unlock $HK_Q/hk-gone-unclassified"
lacks 'nor one whose branch has an open pull request, which the report never names' "$HK_NOTDUE" \
  "git worktree unlock $HK_Q/hk-gone-open"
holds 'a worktree with untracked files is held back' "$HK_NOTDUE" \
  '#   hk-dirty -- pull request #2, but '
lacks 'and not removed' "$HK_NOTDUE" "git worktree remove $HK_Q/hk-dirty"
lacks 'nor its branch deleted' "$HK_NOTDUE" 'git branch -d hk-dirty'
holds 'a worktree whose status cannot be read is held back, not read as clean' "$HK_NOTDUE" \
  '#   hk-broken -- pull request #11, but '
lacks 'and not removed' "$HK_NOTDUE" "git worktree remove $HK_Q/hk-broken"
lacks 'nor its branch deleted' "$HK_NOTDUE" 'git branch -d hk-broken'
holds 'a worktree locked by a live session is held back' "$HK_NOTDUE" \
  '#   hk-live -- pull request #3, but its worktree is locked by a session that may still be running:'
lacks 'and not unlocked' "$HK_NOTDUE" "git worktree unlock $HK_Q/hk-live"
lacks 'nor its branch deleted' "$HK_NOTDUE" 'git branch -d hk-live'
holds 'a closed pull request is a decision, not a command' "$HK_NOTDUE" \
  '#   hk-closed -- closed without merging: pull request #6. Its commits may exist nowhere else'
lacks 'so its branch is not deleted' "$HK_NOTDUE" 'git branch -d hk-closed'

echo "--- rotated-past dev branches: the first #126 finding ---"
req US-29 GH-100
holds 'a rotated-past branch whose pull request into main is open is held' "$HK_NOTDUE" \
  '#   dev-04 -- rotated past, held: its pull request into main, #9, is open.'
lacks 'and is not deleted locally' "$HK_NOTDUE" 'git branch -d dev-04'
lacks 'nor on origin' "$HK_NOTDUE" 'git push origin --delete dev-04'
holds 'one whose pull request merged but which carries commits since is held' "$HK_NOTDUE" \
  '#   dev-01 -- rotated past, held: remotes/origin/dev-01 has commits that are not in origin/main.'
lacks 'and is not deleted locally' "$HK_NOTDUE" 'git branch -d dev-01'
lacks 'nor on origin' "$HK_NOTDUE" 'git push origin --delete dev-01'
holds 'one merged and contained but checked out in a worktree is held' "$HK_NOTDUE" \
  "#   dev-02 -- rotated past, held: it is checked out at $HK_DIR/dev-02."
lacks 'and is not deleted' "$HK_NOTDUE" 'git branch -d dev-02'
holds 'one merged, contained, with nothing open and nowhere checked out, is deleted in both places' "$HK_NOTDUE" \
"# dev-03 -- rotated past: merged into main, contained in origin/main, nothing open against it
git branch -d dev-03
git push origin --delete dev-03"

echo "--- the rotation of the active dev branch ---"
req US-29 GH-100
holds 'no pull request into main is not due' "$HK_NOTDUE" \
  '# dev-05 is not due to rotate: it has no pull request into main.'
holds 'merged with a pull request open against it is not due' "$HK_HELD" \
  '# dev-05 is not due to rotate: pull requests are open against it (#21), and deleting it would close them.'
lacks 'and prints no rotation' "$HK_HELD" 'git checkout -b dev-06'
holds 'merged, contained and with nothing open, the rotation is printed' "$HK_DUE" \
"# dev-05 is due: merged into main, contained in origin/main, nothing open against it.
git checkout main
git pull --ff-only origin main
git checkout -b dev-06
git push -u origin dev-06
git branch --show-current   # must print dev-06 before the deletes
git branch -d dev-05
git push origin --delete dev-05"
for out in "$HK_NOTDUE" "$HK_HELD" "$HK_DUE"; do
  holds 'a plan printed exits 0' "$out" 'exit=0'
done

echo "--- the printed plan, executed ---"
req GH-70.2 US-29
# The not-due plan, run as Bertan would run it. What it removes and what it
# leaves are both asserted: a plan that stopped at its first command would pass
# every `holds` above.
HK_PLAN="$FIXTURES/hk-plan.sh"
printf '%s\n' "$HK_NOTDUE" | grep -v '^exit=' > "$HK_PLAN"
( cd / && bash -e "$HK_PLAN" ) >/dev/null 2>&1
tok 'the plan runs to its end under bash -e' '0' "$?"
tok 'the swept branches are gone, and dev-03 with them' '' \
  "$($HG branch --list hk-merged hk-plain hk-gone dev-03)"
tok 'every held-back branch is still there' \
  'dev-01 dev-02 dev-04 hk-broken hk-closed hk-dirty hk-gone-unclassified hk-live' \
  "$($HG for-each-ref --format='%(refname:short)' refs/heads/dev-01 refs/heads/dev-02 refs/heads/dev-04 \
      refs/heads/hk-broken refs/heads/hk-closed refs/heads/hk-dirty \
      refs/heads/hk-gone-unclassified refs/heads/hk-live \
      | sort | tr '\n' ' ' | sed 's/ $//')"
# A newline after each path, so hk-gone is not found inside hk-gone-unclassified.
HK_AFTER="$($HG worktree list --porcelain)"$'\n'
lacks 'the gone worktree of a merged branch is pruned' "$HK_AFTER" "worktree $HK_DIR/hk-gone"$'\n'
lacks 'and the detached one, unlocked before the prune' "$HK_AFTER" "worktree $HK_DIR/detached"$'\n'
holds 'the one whose branch is not merged is left as it was' "$HK_AFTER" "worktree $HK_DIR/hk-gone-unclassified"$'\n'
holds 'and so is the one whose pull request is open' "$HK_AFTER" "worktree $HK_DIR/hk-gone-open"$'\n'
tok 'dev-03 is deleted on origin, and dev-01 and dev-04 are not' 'dev-01 dev-04' \
  "$(git -C "$HK_ORIGIN" for-each-ref --format='%(refname:short)' refs/heads/dev-01 refs/heads/dev-03 refs/heads/dev-04 \
      | tr '\n' ' ' | sed 's/ $//')"

echo "--- where it cannot tell, it prints no command and exits 1 ---"
req GH-100
# A repository with no origin, one whose origin cannot be reached, a report
# that could not read pull requests, and a generator whose own read failed.
hk_bare_fixture() {  # hk_bare_fixture <dir> [origin url]
  git init -q -b main "$1"
  git -C "$1" -c user.email=checks@example.invalid -c user.name=checks commit -q --allow-empty -m base
  [ -n "$2" ] && git -C "$1" remote add origin "$2"
  mkdir -p "$1/.claude/hooks" "$1/.claude/skills/housekeeping"
  cp "$HOOKS/report-stale-branches.sh" "$1/.claude/hooks/"
  cp "$HK_GEN" "$1/.claude/skills/housekeeping/"
}
hk_bare_fixture "$FIXTURES/hk-noorigin"
hk_bare_fixture "$FIXTURES/hk-unreachable" "$FIXTURES/hk-no-such-origin.git"
HK_NOORIGIN=$(hk_run "$FIXTURES/hk-noorigin" "$HK_PRS_R" "$HK_PRS_BASE")
HK_UNREACHABLE=$(hk_run "$FIXTURES/hk-unreachable" "$HK_PRS_R" "$HK_PRS_BASE")
HK_REPORT_UNREAD=$(hk_run "$HK" '' "$HK_PRS_BASE")
HK_GEN_UNREAD=$(hk_run "$HK" "$HK_PRS_R" '')
holds 'no origin: the fetch did not complete' "$HK_NOORIGIN" '# No commands: the fetch did not complete'
holds 'an unreachable origin: the fetch did not complete' "$HK_UNREACHABLE" '# No commands: the fetch did not complete'
holds 'the report could not read pull requests' "$HK_REPORT_UNREAD" '# No commands: the report could not read pull requests'
holds 'its own pull request read failed, which was an exit 0 before review of #126' "$HK_GEN_UNREAD" \
  '# No commands: the pull request read for the dev branch checks failed'
for out in "$HK_NOORIGIN" "$HK_UNREACHABLE" "$HK_REPORT_UNREAD" "$HK_GEN_UNREAD"; do
  holds 'a declined plan exits 1' "$out" 'exit=1'
  tok 'and prints no command' '0' "$(printf '%s\n' "$out" | grep -c '^git ')"
done

echo "--- the report's wording, held equal in both files ---"
req GH-100
# The coupling the generator's header names. Each phrase is printed by the
# report and matched by the generator; a rewording on either side turns its own
# line red, where the fixture above would say only that some plan changed. The
# `#` after "pull request" is left off because `armed` strips from a spaced `#`.
for phrase in 'fetch: FAILED' 'fetch: SKIPPED' 'pull requests: NOT READ' \
    'pull requests: read' 'active dev branch: ' 'merged: pull request' \
    'closed without merging: pull request' 'rotated past' '   [worktree: '; do
  armed "the report prints |$phrase|" "$HOOKS/report-stale-branches.sh" "$phrase"
  armed "the generator reads |$phrase|" "$HK_GEN" "$phrase"
done
armed "the generator's own read asks for the base" "$HK_GEN" \
  '--json number,headRefName,baseRefName,state'
armed 'in the column order the stand-in above answers in' "$HK_GEN" \
  "--jq '.[] | \"\\(.number)\\t\\(.headRefName)\\t\\(.baseRefName)\\t\\(.state)\"'"

section "=== this suite's header names every file it checks ==="
# The same audit again, pointed at this file. Its header opened by naming four
# hooks while the suite also checked five more, the library, settings.json and
# three documents, and further down it pointed at "the number below" after the
# number had been removed (#102). Nothing had gone wrong in any one edit: each
# issue that widened the suite added its history to the header and left the
# first sentence as it was, which is how every list checked above went stale.
#
# The header enumerates rather than naming categories, so a reader learns what
# is covered without reading four thousand lines, and this is what keeps the
# enumeration true. The paragraph is the first comment block, as for the
# tokeniser: the rest of the header is history and names files for other
# reasons. That history names every one of these files too, so an extraction
# that ran on past the paragraph would answer every check below whatever the
# paragraph said -- which is why it is checked from both ends first, the way
# the boundary section's is. Uses SETTINGS, HOOK_FILES and `present` from the
# boundary-section audit above, so it has to stay below it.
req GH-102
SELF_PARAGRAPH="$FIXTURES/check-hooks-first-paragraph.txt"
first_comment_block "$SUITE_DIR/check-hooks.sh" > "$SELF_PARAGRAPH"
written 'the extracted paragraph is the one that states the scope' \
  "$SELF_PARAGRAPH" 'Regression checks for'
unarmed 'and it stops before the paragraph after it' \
  "$SELF_PARAGRAPH" 'A hook is a process'
SELF_NAMED=$(grep -oE '[A-Za-z0-9_.-]+\.(sh|json|md)' "$SELF_PARAGRAPH" | sort -u | tr '\n' ' ')
# Every hook settings.json runs, on any event and any matcher -- wider than
# REGISTERED above, which leaves out the Edit companion because the boundary
# paragraph is right to. This is the direction #102 asks for by name; the disk
# loop after it overlaps it, and differs by a hook registered with no file.
RUN_BY_SETTINGS=$(jq -r '.hooks[][]?.hooks[]?.command' "$SETTINGS" 2>/dev/null \
  | sed 's|.*/||; s|[[:space:]].*||' | sort -u | tr '\n' ' ')
# The documents this suite reads, derived off its own text: each is assigned
# from a quoted path under $SUITE_DIR/.. , or, since #104 read requirements.md
# and runbook.md beside this suite, under $HOOKS itself. Both spellings, because
# #107 split the two -- a document outside .claude/hooks/ is this repository's
# whatever is being judged, and the two files inside it follow what is judged.
# A document read through any other spelling -- $REPO_ROOT, say -- is not found
# here, and the header is not held to it; that limit is taken rather than
# closed, because every document read
# today is spelled this way and widening the pattern reaches the fixture paths
# the append-only checks name, which are not files this suite audits. The
# pattern carries a backslash, so this line is not among its own matches.
# `sh` is among the extensions because housekeeping-commands.sh is read from
# outside .claude/hooks/ and so is on no disk listing above; at the review of
# #126 it was the only `.sh` path spelled this way. Beside this suite, under
# $HOOKS itself, only `md` is read this way: every `.sh` there is on the disk
# listing already, this suite among them, and the header does not name itself.
READ_DOCS=$(grep -oE '"\$(SUITE_DIR/\.\./[^"]*\.(json|md|sh)|HOOKS/[^"/]*\.md)"' "$SUITE_DIR/check-hooks.sh" \
  | sed 's|.*/||; s|"$||' | sort -u | tr '\n' ' ')
[ -n "$SELF_NAMED" ] && [ -n "$RUN_BY_SETTINGS" ] && [ -n "$READ_DOCS" ] \
  && [ -n "$HOOK_FILES" ] || {
  echo "nothing was read out of this suite's header, settings.json, the disk or this suite's text; the checks below prove nothing" >&2
  exit 1
}
set -f
for hook in $RUN_BY_SETTINGS; do
  present "the header names $hook, which settings.json runs" "$hook" "$SELF_NAMED"
done
# The library and anything else beside the hooks that settings.json does not run.
for hook in $HOOK_FILES; do
  case "$hook" in check-hooks.sh) continue ;; esac
  present "the header names $hook, which is on the disk" "$hook" "$SELF_NAMED"
done
for doc in $READ_DOCS; do
  present "the header names $doc, which this suite reads" "$doc" "$SELF_NAMED"
done
# The other direction: a name in the paragraph that is neither a file beside
# this suite nor a document it reads, which is a rename the header was not
# revised with.
for name in $SELF_NAMED; do
  present "the header names $name, and this suite checks it" \
          "$name" "$HOOK_FILES $READ_DOCS"
done
set +f

# The other half of #102: the header's history said "the number below" after
# the number it meant had gone. A pin on that phrase, over the whole header
# rather than the paragraph, because that is where the sentence lived -- it
# says nothing about a pointer reworded some other way, and is here so that
# restoring the old sentence turns something red.
SELF_WHOLE_HEADER="$FIXTURES/check-hooks-header.txt"
awk 'NR == 1 { next } /^#/ { print; next } { exit }' "$SUITE_DIR/check-hooks.sh" > "$SELF_WHOLE_HEADER"
written 'the whole header runs on past the first paragraph' \
  "$SELF_WHOLE_HEADER" 'A hook is a process'
unarmed 'and it points at no number below it, since none is there' \
  "$SELF_WHOLE_HEADER" 'the number below'

# US-31 and FR-35: the header states what a green run is worth. Two sentences,
# and the suite would be no less green without either -- which is the point of
# pinning them. The first is the concrete one, and it is concrete on purpose: a
# reviewer who reads "evidence about the cases it names" and nothing else can
# take it as modesty, where `if true; then git push --mirror origin; fi` names
# the run that was green while a wholesale push was permitted. Both are on the
# whole header rather than the first paragraph, which is the scope enumeration
# and says nothing about worth.
req US-31 FR-35
written 'the header names the green run that permitted a wholesale push' \
  "$SELF_WHOLE_HEADER" 'the suite passed while `if true; then git push --mirror origin;'
written 'and the second occasion beside it' \
  "$SELF_WHOLE_HEADER" 'fi` was permitted, and passed again while a commit message mentioning `<<EOF`'
written 'and states what a check suite is evidence of' \
  "$SELF_WHOLE_HEADER" 'So a green run is not a measure of the boundary. A check suite is evidence'
written 'and of what it is not' \
  "$SELF_WHOLE_HEADER" 'about the cases it names and about nothing else'

section "=== issue #84: every hook refuses when lib/command-scan.sh does not load ==="
# THE LOAD CONTRACT, driven. lib/command-scan.sh states it; the hooks that
# source that file have to hold it, and before #84 three of the four there
# were then did not --
# no-git-push.sh and no-pr-decisions.sh had no guard at all, and
# no-commit-to-main.sh had one that required cs_split alone.
#
# Asked of all four in one place, rather than in each hook's own section, because
# what went wrong was exactly that the answer was given in one file and not
# carried to the others: no-work-on-stale-branch.sh got this right, wrote the
# trap down in its own comment, and the other three shipped past it. The two
# blocks this section replaces sat 500 lines apart and between them covered two
# hooks of four. An omission is visible in a matrix and invisible spread over
# 2000 lines, so a hook added to the boundary belongs here with the rest of them.
#
# Two fixtures, because there are two ways to not load. `nolib` is the file
# absent. `halflib` is the likelier failure in practice, and the one that found
# #84: the library present, complete, and loading, with one cs_* function renamed
# away -- which is what a refactor does rather than what an accident does.
#
# ONE FUNCTION AT A TIME is the whole point of halflib, and the reason there is a
# fixture per hook per function below rather than one per hook. A fixture that
# renamed every function at once would be satisfied by a guard that requires only
# the first of them, and requiring only one is the defect: no-commit-to-main.sh
# required cs_split, cs_split was still there, and `git push origin HEAD:main` was
# permitted.
#
# That is deliberately the inverse of what issue #84 asked for -- one halflib
# fixture renaming every function the hook under test requires -- and is recorded as
# a deviation rather than left to be read as one. One fixture with every name
# renamed is the weaker test, for the reason just given; thirteen fixtures each
# missing one name is the stronger, and the assertion the issue did ask for (that
# the rename took) is made on both directions in mk_halflib below.
#
# `ls` is the driving command for the three hooks whose guard is unconditional,
# and it is deliberately a command none of them has any opinion about: a BLOCK on
# it can only have come from the guard, where a BLOCK on a forced push or on a
# `gh pr merge` is over-determined the moment the fix lands and would go on
# passing if the guard were taken out again. Each is paired with the same command
# against the real hook, so the ALLOW half of the discrimination is on the page
# rather than assumed.

# EVERY file that sources the library, as a literal. It is the claim; the
# derivation at the end of this section is the fact, and asserts these are all of
# them. Everything between is driven per hook off this list.
#
# Six, not the four boundary hooks issue #84 was written about, and that is the
# merge of #69 talking. #69 rebuilt pytest-via-uv-group.sh and
# alembic-via-uv-group.sh on the tokeniser and gave each the same guard, having
# hit the same trap from the other end -- its comment says "Testing cs_split alone
# left cs_normalise unguarded", which is #84's finding in two more files, found
# independently and at the same time. Two issues answering one question in two
# places is what the question was about, so the answer is one section: a file that
# cannot load the tokeniser must refuse, and the list is whoever loads it.
#
# Eight since #95, which moved every hook's input read into cs_tool_input: the two
# append-only hooks source the library for that function alone, and are driven
# here with the rest because a file that cannot load its reader is the same
# question.
LIB_CONSUMERS="alembic-via-uv-group.sh append-only-docs-edit.sh append-only-docs.sh no-commit-to-main.sh no-git-push.sh no-pr-decisions.sh no-work-on-stale-branch.sh pytest-via-uv-group.sh"
# Since #96 every Bash hook among them calls cs_within_cap as well, and
# append-only-docs.sh takes that function from the library beside its reader.
# Which consumers call it is read off their code rather than listed, for the
# reason this list is checked against the files below: a list goes stale. The
# issue #96 section asserts that those are exactly the Bash hooks settings.json
# registers.
CAP_CONSUMERS=$(for hook in $LIB_CONSUMERS; do
    sed 's/[[:space:]]*#.*$//' "$HOOKS/$hook" 2>/dev/null | grep -q 'cs_within_cap' \
      && printf '%s\n' "$hook"
  done | tr '\n' ' ')
[ -n "$CAP_CONSUMERS" ] || {
  echo "no hook was read as calling cs_within_cap; the checks driven off that list prove nothing" >&2
  exit 1
}

# The library absent. One directory for all of them: what makes the fixture is the
# absence of lib/ beside the hook, not anything about the hook.
#
# Every copy is guarded, not one of them, and at the path the checks will drive.
# The first version of this asked `[ -f ]` about no-git-push.sh alone, which is the
# mistake mk_halflib records below with the consequence measured: a hook that is
# not there makes `( cd "$dir" && "$hook" )` exit 127, which check_in read as
# ALLOW before #98 (see `verdict`). So a missing copy turned every BLOCK here red
# -- visible -- but let `no lib/, on a branch carrying work` pass vacuously. The
# guard stays because it names the copy that is missing, which a FAIL on the
# check does not. Asking about one of four was itself the #84 shape,
# and it was not hypothetical: #69's own two checks copied their fixtures in with
# no guard at all, and this consolidation moved the mkdir below them, so both ran
# against a hook that was not there until the derivation at the end of this
# section went red.
nolib_path() {  # nolib_path <hook> -- where the library-absent copy of it sits
  printf '%s\n' "$FIXTURES/nolib/$1"
}
mkdir -p "$FIXTURES/nolib"
for hook in $LIB_CONSUMERS; do
  cp "$HOOKS/$hook" "$(nolib_path "$hook")"
  [ -x "$(nolib_path "$hook")" ] || {
    echo "the nolib fixture for $hook is not at $(nolib_path "$hook"), or is not executable; the checks using it prove nothing" >&2
    exit 1
  }
done
[ ! -d "$FIXTURES/nolib/lib" ] || {
  echo "the nolib fixture has a lib/ beside it, so it is not the library-absent case at all" >&2
  exit 1
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
  local target dir
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
  # for the guard.
  bash -c ". '$dir/lib/command-scan.sh' && command -v cs_renamed_away >/dev/null 2>&1" || {
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
# One call per pair the contract names, which is the required list of each hook. The
# sets differ, and that difference is the reason the guards cannot share a list:
# four want cs_git_args, no-pr-decisions.sh wants cs_gh_args and cs_join instead,
# and the two convention hooks want neither. Since #96 every one of them wants
# cs_within_cap, and append-only-docs.sh wants nothing else.
mk_halflib no-git-push.sh cs_normalise
mk_halflib no-git-push.sh cs_split
mk_halflib no-git-push.sh cs_git_args
mk_halflib no-pr-decisions.sh cs_normalise
mk_halflib no-pr-decisions.sh cs_split
mk_halflib no-pr-decisions.sh cs_gh_args
mk_halflib no-pr-decisions.sh cs_join
mk_halflib no-commit-to-main.sh cs_normalise
mk_halflib no-commit-to-main.sh cs_split
mk_halflib no-commit-to-main.sh cs_git_args
mk_halflib no-work-on-stale-branch.sh cs_normalise
mk_halflib no-work-on-stale-branch.sh cs_split
mk_halflib no-work-on-stale-branch.sh cs_git_args
mk_halflib pytest-via-uv-group.sh cs_normalise
mk_halflib pytest-via-uv-group.sh cs_split
mk_halflib alembic-via-uv-group.sh cs_normalise
mk_halflib alembic-via-uv-group.sh cs_split
# The input reader, which every consumer calls since #95 and two call alone.
for hook in $LIB_CONSUMERS; do
  mk_halflib "$hook" cs_tool_input
done
# The line cap, which every Bash hook calls since #96.
for hook in $CAP_CONSUMERS; do
  mk_halflib "$hook" cs_within_cap
done

echo "--- no-git-push.sh, which had no guard at all ---"
# The measured #84 case: with no guard, cs_git_args was undefined, the HAVE_PUSH
# loop found no push, and the hook left without an opinion on a forced push of a
# reserved branch.
req GH-84.1
check_in "$PUSH_WT" no-git-push.sh ALLOW 'a command with no push in it, library intact' \
  'ls'
check_in "$PUSH_WT" "$(nolib_path no-git-push.sh)" BLOCK 'no lib/, anything at all' \
  'ls'
check_in "$PUSH_WT" "$(halflib_path no-git-push.sh cs_normalise)" BLOCK 'a library missing only cs_normalise' \
  'ls'
check_in "$PUSH_WT" "$(halflib_path no-git-push.sh cs_split)" BLOCK 'a library missing only cs_split' \
  'ls'
check_in "$PUSH_WT" "$(halflib_path no-git-push.sh cs_git_args)" BLOCK 'a library missing only cs_git_args' \
  'ls'
check_in "$PUSH_WT" "$(halflib_path no-git-push.sh cs_within_cap)" BLOCK 'a library missing only cs_within_cap' \
  'ls'
req GH-84.1 US-3
check_in "$PUSH_WT" "$(halflib_path no-git-push.sh cs_git_args)" BLOCK 'a renamed cs_git_args does not permit a forced push' \
  'git push --force origin dev-05'
req GH-84.1
says "$PUSH_WT" "$(nolib_path no-git-push.sh)" 'no-git-push.sh could not load' \
  'the refusal names this hook and not one of its three siblings' 'ls'
says "$PUSH_WT" "$(nolib_path no-git-push.sh)" 'Refusing rather than permitting' \
  'and says that it is refusing rather than permitting' 'ls'

echo "--- no-pr-decisions.sh, which had no guard at all ---"
# This file's function set is what makes one shared required list wrong: cs_gh_args
# and cs_join, and no cs_git_args at all. Every rule in it reads its arguments
# through cs_gh_args, so renaming that one permitted `gh pr merge` and
# `gh pr create --base main` together.
req GH-84.1
check_in "$ON_DEV" no-pr-decisions.sh ALLOW 'a command with no gh in it, library intact' \
  'ls'
check_in "$ON_DEV" "$(nolib_path no-pr-decisions.sh)" BLOCK 'no lib/, anything at all' \
  'ls'
check_in "$ON_DEV" "$(halflib_path no-pr-decisions.sh cs_normalise)" BLOCK 'a library missing only cs_normalise' \
  'ls'
check_in "$ON_DEV" "$(halflib_path no-pr-decisions.sh cs_split)" BLOCK 'a library missing only cs_split' \
  'ls'
check_in "$ON_DEV" "$(halflib_path no-pr-decisions.sh cs_gh_args)" BLOCK 'a library missing only cs_gh_args' \
  'ls'
req GH-84.1 US-15
check_in "$ON_DEV" "$(halflib_path no-pr-decisions.sh cs_gh_args)" BLOCK 'a renamed cs_gh_args does not permit a merge' \
  'gh pr merge 81'
req GH-84.1 FR-15
check_in "$ON_DEV" "$(halflib_path no-pr-decisions.sh cs_gh_args)" BLOCK 'nor a pull request based on main' \
  'gh pr create --base main'
# cs_join is read late, by the wrapper rules alone, so a renamed cs_join is
# invisible to every check above it. It is required because the hook calls it and
# not because a rule was seen to break: the contract is the set, not whichever
# subset a driving command happens to reach.
req GH-84.1
check_in "$ON_DEV" "$(halflib_path no-pr-decisions.sh cs_join)" BLOCK 'a library missing only cs_join' \
  'ls'
check_in "$ON_DEV" "$(halflib_path no-pr-decisions.sh cs_within_cap)" BLOCK 'a library missing only cs_within_cap' \
  'ls'
says "$ON_DEV" "$(nolib_path no-pr-decisions.sh)" 'no-pr-decisions.sh could not load' \
  'the refusal names this hook and not one of its three siblings' 'ls'
says "$ON_DEV" "$(nolib_path no-pr-decisions.sh)" 'Refusing rather than permitting' \
  'and says that it is refusing rather than permitting' 'ls'

echo "--- no-commit-to-main.sh, which had a guard and permitted anyway ---"
# Why a guard naming one function is worse than none: it reads as the question
# answered. `cs_git_args commit` and `cs_git_args push` fail exactly as a command
# holding neither does, so with cs_git_args renamed away every commit and every
# push was permitted while cs_split -- the only name required -- was still there.
req GH-84.1
check_in "$ON_DEV" no-commit-to-main.sh ALLOW 'a command touching nothing, library intact' \
  'ls'
check_in "$ON_MAIN" "$(nolib_path no-commit-to-main.sh)" BLOCK 'no lib/, commit on main' \
  'git commit -m "wip"'
check_in "$ON_DEV"  "$(nolib_path no-commit-to-main.sh)" BLOCK 'no lib/, anything at all' \
  'ls'
check_in "$ON_DEV" "$(halflib_path no-commit-to-main.sh cs_normalise)" BLOCK 'a library missing only cs_normalise' \
  'ls'
check_in "$ON_DEV" "$(halflib_path no-commit-to-main.sh cs_split)" BLOCK 'a library missing only cs_split' \
  'ls'
check_in "$ON_DEV" "$(halflib_path no-commit-to-main.sh cs_git_args)" BLOCK 'a library missing only cs_git_args' \
  'ls'
check_in "$ON_DEV" "$(halflib_path no-commit-to-main.sh cs_within_cap)" BLOCK 'a library missing only cs_within_cap' \
  'ls'
# The #84 measurement itself, on the fixture that permitted it: a push landing on
# main, from a checkout that is not main, refused by the guard because the refspec
# rule that would otherwise catch it cannot run without the tokeniser.
req GH-84.1 US-1
check_in "$ON_DEV" "$(halflib_path no-commit-to-main.sh cs_git_args)" BLOCK 'a renamed cs_git_args does not permit a push to main' \
  'git push origin HEAD:main'
req GH-84.1
says "$ON_DEV" "$(nolib_path no-commit-to-main.sh)" 'no-commit-to-main.sh could not load' \
  'the refusal names this hook and not one of its three siblings' 'ls'
says "$ON_DEV" "$(nolib_path no-commit-to-main.sh)" 'Refusing rather than permitting' \
  'and says that it is refusing rather than permitting' 'ls'

echo "--- no-work-on-stale-branch.sh, the one that had it right ---"
# Its guard is the one that is scoped rather than unconditional, and the scope is
# the reason: this file has no opinion at all about a branch carrying work, so a
# missing library must not turn a healthy worktree into a refused one. That makes
# its driving command a real one on a stale branch rather than `ls`, and gives it
# the ALLOW half that the other three take from the intact-library control.
#
# Issue #95 took the first half of that back, and the flip below is the record.
# The tool call is read through cs_tool_input, which lives in the library, so a
# missing library leaves this file with no command to scope anything by, and it
# refuses on every branch like the other consumers. What that gives up is nothing
# an agent sees: with lib/ gone every other Bash hook refuses every command
# anyway. The scope survives where it still means something -- a library missing
# only a tokeniser function, or with its word list emptied, is still an ALLOW on
# a branch carrying work, and those checks are unchanged.
req GH-84.1 GH-95.2
check_in "$WT_STALE" "$(nolib_path no-work-on-stale-branch.sh)" BLOCK 'no lib/, on a stale branch' \
  'git status'
check_in "$WT_WORK" "$(halflib_path no-work-on-stale-branch.sh cs_tool_input)" BLOCK \
  'a library missing only cs_tool_input, on a branch carrying work' 'ls'
flip "$WT_WORK" "$(nolib_path no-work-on-stale-branch.sh)" ALLOW BLOCK 'no lib/, on a branch carrying work' \
  'git commit -m "wip"'
# WHAT THESE ARE AND ARE NOT. Every behavioural check in this block passes against
# the unfixed hook, because this hook was the one that had the guard right: the two
# nolib cases and the cs_git_args halflib case are the pre-existing ones moved
# here, and cs_normalise and cs_split were already required. So this block is pins,
# not evidence of a fix, and issue #84's "each failing without the fix" is not met
# here and cannot be. What did fail for this hook before the change is the pair
# below, which asked the refusal to name the file rather than say "this hook".
# cs_normalise and cs_split are driven anyway, because the contract is checked per
# function everywhere: a check written only where a defect was found is the check
# that will be missing at the next one.
req GH-84.1
check_in "$WT_STALE" "$(halflib_path no-work-on-stale-branch.sh cs_git_args)" BLOCK 'a library missing only cs_git_args' \
  'git commit -m "wip"'
check_in "$WT_STALE" "$(halflib_path no-work-on-stale-branch.sh cs_normalise)" BLOCK 'a library missing only cs_normalise' \
  'git commit -m "wip"'
check_in "$WT_STALE" "$(halflib_path no-work-on-stale-branch.sh cs_split)" BLOCK 'a library missing only cs_split' \
  'git commit -m "wip"'
check_in "$WT_STALE" "$(halflib_path no-work-on-stale-branch.sh cs_within_cap)" BLOCK 'a library missing only cs_within_cap' \
  'git status'
says "$WT_STALE" "$(nolib_path no-work-on-stale-branch.sh)" 'no-work-on-stale-branch.sh could not load' \
  'the refusal names this hook and not one of its three siblings' 'git status'
says "$WT_STALE" "$(nolib_path no-work-on-stale-branch.sh)" 'Refusing rather than permitting' \
  'and says that it is refusing rather than permitting' 'git status'

echo "--- pytest-via-uv-group.sh and alembic-via-uv-group.sh, from #69 ---"
# These two are here for the reason the other four are in one place: the question
# is one question. #69 asked it of them in their own section, with a third and a
# fourth copy of the fixture idiom, and covered cs_normalise of the two functions
# each calls -- which is the narrower set #84 is about, in the fixture rather
# than in the guard. Both are driven per function now.
#
# What these are: pins. Both guards were already right when #69 shipped them, so
# nothing here fails against the unfixed hooks, and the two nolib checks are that
# issue's own moved verbatim. cs_split is the fixture #69 did not build.
req GH-84.1
check_in "$ON_DEV" pytest-via-uv-group.sh ALLOW 'a command naming no runner, library intact' \
  'ls'
check_in "$ON_DEV" "$(nolib_path pytest-via-uv-group.sh)" BLOCK \
  'no lib/, pytest-via-uv-group.sh refuses anything at all' 'ls'
check_in "$ON_DEV" "$(halflib_path pytest-via-uv-group.sh cs_normalise)" BLOCK \
  'a library missing only cs_normalise, pytest-via-uv-group.sh' 'ls'
check_in "$ON_DEV" "$(halflib_path pytest-via-uv-group.sh cs_split)" BLOCK \
  'a library missing only cs_split, pytest-via-uv-group.sh' 'ls'
check_in "$ON_DEV" "$(halflib_path pytest-via-uv-group.sh cs_within_cap)" BLOCK \
  'a library missing only cs_within_cap, pytest-via-uv-group.sh' 'ls'
says "$ON_DEV" "$(nolib_path pytest-via-uv-group.sh)" 'pytest-via-uv-group.sh could not load' \
  'the refusal names this hook and not its companion' 'ls'
says "$ON_DEV" "$(nolib_path pytest-via-uv-group.sh)" 'Refusing rather than permitting' \
  'and says that it is refusing rather than permitting' 'ls'
check_in "$ON_DEV" alembic-via-uv-group.sh ALLOW 'a command naming no runner, library intact' \
  'ls'
check_in "$ON_DEV" "$(nolib_path alembic-via-uv-group.sh)" BLOCK \
  'no lib/, alembic-via-uv-group.sh refuses anything at all' 'ls'
check_in "$ON_DEV" "$(halflib_path alembic-via-uv-group.sh cs_normalise)" BLOCK \
  'a library missing only cs_normalise, alembic-via-uv-group.sh' 'ls'
check_in "$ON_DEV" "$(halflib_path alembic-via-uv-group.sh cs_split)" BLOCK \
  'a library missing only cs_split, alembic-via-uv-group.sh' 'ls'
check_in "$ON_DEV" "$(halflib_path alembic-via-uv-group.sh cs_within_cap)" BLOCK \
  'a library missing only cs_within_cap, alembic-via-uv-group.sh' 'ls'
says "$ON_DEV" "$(nolib_path alembic-via-uv-group.sh)" 'alembic-via-uv-group.sh could not load' \
  'the refusal names this hook and not its companion' 'ls'
says "$ON_DEV" "$(nolib_path alembic-via-uv-group.sh)" 'Refusing rather than permitting' \
  'and says that it is refusing rather than permitting' 'ls'

echo "--- cs_tool_input, the reader every consumer calls since #95 ---"
# The eighth function in the contract and the first every consumer shares. A
# library missing only it leaves COMMAND=$(cs_tool_input command) empty with a
# non-zero status, and the one thing between that and the #95 defect -- an empty
# command, exit 0 -- is the guard. So each consumer is driven with it renamed
# away, on a command every one of them otherwise permits. no-work-on-stale-branch.sh
# is driven in its own block above, on the branch where its scope used to permit.
req GH-84.1 GH-95.2
for hook in alembic-via-uv-group.sh no-commit-to-main.sh no-git-push.sh no-pr-decisions.sh pytest-via-uv-group.sh; do
  check_in "$ON_DEV" "$(halflib_path "$hook" cs_tool_input)" BLOCK \
    "a library missing only cs_tool_input, $hook" 'ls'
done
# The two #95 made consumers, whole: they had no library to fail to load before,
# so every check here is new. feed rather than check_in, because the Edit hook
# reads file_path. #95 gave a second, that feed's verdict was exact; #98 made
# every helper's exact, so it no longer separates the two.
req GH-84.1 GH-95.2
feed "$PATH" append-only-docs.sh ALLOW 'append-only-docs.sh, a command naming no guarded path, library intact' \
  '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
feed "$PATH" "$(nolib_path append-only-docs.sh)" BLOCK 'no lib/, append-only-docs.sh refuses anything at all' \
  '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
feed "$PATH" "$(halflib_path append-only-docs.sh cs_tool_input)" BLOCK 'a library missing only cs_tool_input, append-only-docs.sh' \
  '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
feed_says "$PATH" "$(nolib_path append-only-docs.sh)" 'append-only-docs.sh could not load' \
  'the refusal names this hook and not its Edit companion' \
  '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
feed_says "$PATH" "$(nolib_path append-only-docs.sh)" 'Refusing rather than permitting' \
  'and says that it is refusing rather than permitting' \
  '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
EDIT_CONTROL=$(jq -cn --arg p "$REPO_ROOT/src/config.py" '{tool_name:"Edit",tool_input:{file_path:$p}}')
feed "$PATH" append-only-docs-edit.sh ALLOW 'append-only-docs-edit.sh, an edit outside the guarded directories, library intact' \
  "$EDIT_CONTROL"
feed "$PATH" "$(nolib_path append-only-docs-edit.sh)" BLOCK 'no lib/, append-only-docs-edit.sh refuses any edit at all' \
  "$EDIT_CONTROL"
feed "$PATH" "$(halflib_path append-only-docs-edit.sh cs_tool_input)" BLOCK 'a library missing only cs_tool_input, append-only-docs-edit.sh' \
  "$EDIT_CONTROL"
feed_says "$PATH" "$(nolib_path append-only-docs-edit.sh)" 'append-only-docs-edit.sh could not load' \
  'the refusal names this hook and not its Bash companion' "$EDIT_CONTROL"
feed_says "$PATH" "$(nolib_path append-only-docs-edit.sh)" 'Refusing rather than permitting' \
  'and says that it is refusing rather than permitting' "$EDIT_CONTROL"

echo "--- cs_within_cap, the line cap every Bash hook calls since #96 ---"
# append-only-docs.sh takes this function from the library beside its reader, so
# it is driven here with the rest: the other consumers' halflib checks for it
# stand in their own blocks above.
req GH-84.1 GH-96.3
check_in "$ON_DEV" "$(halflib_path append-only-docs.sh cs_within_cap)" BLOCK \
  'a library missing only cs_within_cap, append-only-docs.sh' 'ls'
# Every halflib check for cs_within_cap is over-determined, and that is what
# this loop is for. Each hook calls it as `if ! ... | cs_within_cap`, so with the
# function renamed away the call exits 127 and the hook refuses -- with or
# without the probe. The BLOCK cannot tell a guard that names cs_within_cap from
# one that does not. Which message the refusal carries can: the guard says the
# library could not load, the fall-through says only that a line is long. One
# per hook that calls it, off the derived list, so the next one is asked too.
for hook in $CAP_CONSUMERS; do
  case "$hook" in
    no-git-push.sh) dir=$PUSH_WT ;;
    *) dir=$ON_DEV ;;
  esac
  says "$dir" "$(halflib_path "$hook" cs_within_cap)" "$hook could not load" \
    "$hook, a library missing only cs_within_cap, refused by its guard" 'ls'
done

echo "--- issue #79: the word list is part of the load ---"
# A third way to not load, beside nolib and halflib, and the one a guard on
# names cannot see. Issue #79 made cs_split read the prefix-word list through a
# variable, so a library can be present, define every cs_* function, and have
# that list empty -- and then cs_split runs and strips nothing. `sudo git push
# --all origin` has no command word at ^ and is permitted: the fourth review's
# fix, silently undone. lib/command-scan.sh answers it by withdrawing cs_split
# when either half of the list is empty, which reduces this state to a halflib
# one every consumer already refuses.
#
# HERE AND NOT IN EACH HOOK'S SECTION, for #84's reason. These checks were
# first written inside four per-hook sections, beside a fail-safe argued from
# "two hooks source the library unguarded". #84 moved every load check here,
# made that premise false, and resolving the merge the natural way -- taking
# #84's side of each hunk -- deleted all nine of them with the suite still
# green, because a deleted check cannot fail. Review of PR #89 measured that
# before it happened. They are rebuilt here, per consumer, off LIB_CONSUMERS.
#
# EVERY CONSUMER THAT CALLS cs_split, not the four boundary hooks, and that is
# a correction.
# The fail-safe these replace was an empty CS_WRAPPER_RE, which reached the four
# hooks that read the anchor and not the two convention hooks, which call
# cs_split and never the anchor: `sudo pytest tests/` and `sudo alembic upgrade
# head` were permitted by an emptied list the whole time that fail-safe was
# described as the answer. Driving the loop off LIB_CONSUMERS is what makes a
# seventh consumer land here without anyone remembering to add it.
#
# TWO KINDS OF CHECK PER CONSUMER, and neither is enough alone. A command none
# of the hooks has any opinion about -- `ls`, or `git status` on a stale branch
# for the scoped hook -- can only be refused by the guard, so it says the guard
# fired. A command the hook refuses ONLY through cs_split's prefix strip says
# what the state costs when nothing fires: each of those is BLOCK against the
# intact library too, so its discrimination is against a library that empties
# the list without withdrawing cs_split, which is the mutant that has to go red.
emptylist_path() {  # emptylist_path <hook> -- where the emptied-list copy of it sits
  printf '%s\n' "$FIXTURES/emptylist-$1/$1"
}
mk_emptylist() {  # mk_emptylist <hook>
  local hook="$1"
  local target dir
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
  bash -c ". '$dir/lib/command-scan.sh' && command -v cs_normalise && command -v cs_git_args \
           && command -v cs_gh_args && command -v cs_join" >/dev/null 2>&1 || {
    echo "the emptied-list library for $hook does not load with its other functions; the checks using it prove nothing" >&2
    exit 1
  }
  [ -x "$target" ] || {
    echo "the emptied-list fixture for $hook is not at $target, or is not executable; the checks using it prove nothing" >&2
    exit 1
  }
}
for hook in $LIB_CONSUMERS; do
  mk_emptylist "$hook"
done

# The mechanism itself, as a check rather than a fixture guard. Both halves, and
# each half alone: `unset -f` placed above cs_split's definition does nothing and
# the definition restores it, and a test written as `&&` instead of `||` would
# withdraw it only when both are empty.
cs_split_after_loading() {  # cs_split_after_loading <library> -- present or absent
  bash -c ". '$1'; command -v cs_split >/dev/null 2>&1 && echo present || echo absent"
}
req GH-79.4
tok 'the intact library defines cs_split' \
    'present' "$(cs_split_after_loading "$HOOKS/lib/command-scan.sh")"
tok 'a library with both halves of the word list empty withdraws it' \
    'absent' "$(cs_split_after_loading "$(dirname "$(emptylist_path no-git-push.sh)")/lib/command-scan.sh")"
sed -E 's/^CS_WRAP_OPTION_WORDS=.*/CS_WRAP_OPTION_WORDS=""/' "$HOOKS/lib/command-scan.sh" \
  > "$FIXTURES/emptylist-option-half.sh"
sed -E 's/^CS_WRAP_OPERAND_WORDS=.*/CS_WRAP_OPERAND_WORDS=""/' "$HOOKS/lib/command-scan.sh" \
  > "$FIXTURES/emptylist-operand-half.sh"
tok 'and so does one with only the option words empty' \
    'absent' "$(cs_split_after_loading "$FIXTURES/emptylist-option-half.sh")"
tok 'and one with only the operand words empty' \
    'absent' "$(cs_split_after_loading "$FIXTURES/emptylist-operand-half.sh")"

# no-git-push.sh: the measured #79 case. Intact, `ls` is ALLOW -- the #84 block
# above pins that -- so the BLOCK here is the guard. The prefixed push is the
# verdict an emptied list permits when cs_split is left running.
req GH-79.4 GH-84.1
check_in "$PUSH_WT" "$(emptylist_path no-git-push.sh)" BLOCK \
  'no-git-push.sh, a library with no wrapper words, anything at all' 'ls'
check_in "$PUSH_WT" "$(emptylist_path no-git-push.sh)" BLOCK \
  'no-git-push.sh, a library with no wrapper words, a prefixed push' 'sudo git push --all origin'
says "$PUSH_WT" "$(emptylist_path no-git-push.sh)" 'no-git-push.sh could not load' \
  'no-git-push.sh names itself for an emptied list, as for a missing function' 'ls'

check_in "$ON_DEV" "$(emptylist_path no-pr-decisions.sh)" BLOCK \
  'no-pr-decisions.sh, a library with no wrapper words, anything at all' 'ls'
check_in "$ON_DEV" "$(emptylist_path no-pr-decisions.sh)" BLOCK \
  'no-pr-decisions.sh, a library with no wrapper words, a prefixed merge' 'sudo gh pr merge 5'
says "$ON_DEV" "$(emptylist_path no-pr-decisions.sh)" 'no-pr-decisions.sh could not load' \
  'no-pr-decisions.sh names itself for an emptied list' 'ls'

check_in "$ON_DEV" "$(emptylist_path no-commit-to-main.sh)" BLOCK \
  'no-commit-to-main.sh, a library with no wrapper words, anything at all' 'ls'
check_in "$ON_MAIN" "$(emptylist_path no-commit-to-main.sh)" BLOCK \
  'no-commit-to-main.sh, a library with no wrapper words, a prefixed commit on main' 'sudo git commit -m "wip"'
says "$ON_DEV" "$(emptylist_path no-commit-to-main.sh)" 'no-commit-to-main.sh could not load' \
  'no-commit-to-main.sh names itself for an emptied list' 'ls'

# The scoped guard. `git status` on a stale branch, as in the #84 block, because
# a plain commit there is refused whatever the library holds and so says nothing
# about the guard -- measured: written that way first, it stayed green with the
# guard removed. And a healthy worktree is not refused for an emptied list, any
# more than for a missing one.
check_in "$WT_STALE" "$(emptylist_path no-work-on-stale-branch.sh)" BLOCK \
  'no-work-on-stale-branch.sh, a library with no wrapper words, on a stale branch' 'git status'
check_in "$WT_STALE" "$(emptylist_path no-work-on-stale-branch.sh)" BLOCK \
  'no-work-on-stale-branch.sh, a library with no wrapper words, a prefixed commit' 'sudo git commit -m "wip"'
check_in "$WT_WORK" "$(emptylist_path no-work-on-stale-branch.sh)" ALLOW \
  'no-work-on-stale-branch.sh, a library with no wrapper words, on a branch carrying work' 'sudo git commit -m "wip"'
says "$WT_STALE" "$(emptylist_path no-work-on-stale-branch.sh)" 'no-work-on-stale-branch.sh could not load' \
  'no-work-on-stale-branch.sh names itself for an emptied list' 'git status'

# The two the empty-anchor fail-safe never reached. Each prefixed runner is BLOCK
# against the intact library only because cs_split strips `sudo` and finds the
# runner behind it.
check_in "$ON_DEV" "$(emptylist_path pytest-via-uv-group.sh)" BLOCK \
  'pytest-via-uv-group.sh, a library with no wrapper words, anything at all' 'ls'
check_in "$ON_DEV" "$(emptylist_path pytest-via-uv-group.sh)" BLOCK \
  'pytest-via-uv-group.sh, a library with no wrapper words, a prefixed pytest' 'sudo pytest tests/'
check_in "$ON_DEV" pytest-via-uv-group.sh BLOCK \
  'pytest-via-uv-group.sh, and that prefixed pytest is refused intact' 'sudo pytest tests/'
says "$ON_DEV" "$(emptylist_path pytest-via-uv-group.sh)" 'pytest-via-uv-group.sh could not load' \
  'pytest-via-uv-group.sh names itself for an emptied list' 'ls'
check_in "$ON_DEV" "$(emptylist_path alembic-via-uv-group.sh)" BLOCK \
  'alembic-via-uv-group.sh, a library with no wrapper words, anything at all' 'ls'
check_in "$ON_DEV" "$(emptylist_path alembic-via-uv-group.sh)" BLOCK \
  'alembic-via-uv-group.sh, a library with no wrapper words, a prefixed alembic' 'sudo alembic upgrade head'
check_in "$ON_DEV" alembic-via-uv-group.sh BLOCK \
  'alembic-via-uv-group.sh, and that prefixed alembic is refused intact' 'sudo alembic upgrade head'
says "$ON_DEV" "$(emptylist_path alembic-via-uv-group.sh)" 'alembic-via-uv-group.sh could not load' \
  'alembic-via-uv-group.sh names itself for an emptied list' 'ls'

# And the one consumer the word list does not reach. append-only-docs.sh calls
# cs_within_cap and nothing else, so withdrawing cs_split leaves it loaded, and
# an emptied list must not become a refusal of every command there. The
# fixture is built for it by the loop above because it is on LIB_CONSUMERS;
# this is what that fixture is for.
check_in "$ON_DEV" "$(emptylist_path append-only-docs.sh)" ALLOW \
  'append-only-docs.sh, a library with no wrapper words, still permits ls: it calls no cs_split' 'ls'
check_in "$ON_DEV" "$(emptylist_path append-only-docs.sh)" BLOCK \
  'append-only-docs.sh, a library with no wrapper words, still holds its own rule' 'rm -rf docs/dev-log'

# The mechanism as text, beside the mechanism as verdicts. `armed`, so a withdrawal
# commented out during a debugging session and left that way does not satisfy it.
req GH-79.4
armed 'the library withdraws cs_split when the word list is incomplete' \
      "$HOOKS/lib/command-scan.sh" 'unset -f cs_split'
armed 'on either half, and not on the union' \
      "$HOOKS/lib/command-scan.sh" 'if [ -z "$CS_WRAP_OPTION_WORDS" ] || [ -z "$CS_WRAP_OPERAND_WORDS" ]; then'
# And that no guard learned about the list instead. A word-list guard in a hook
# is a second answer to a question the library now answers once, and it is the
# shape the first version of this took, in two hooks of six.
for hook in $LIB_CONSUMERS; do
  unarmed "$hook does not require the word list itself" "$HOOKS/$hook" 'CS_WRAP_OPTION_WORDS'
done
written 'the load contract says the word list is part of the load' \
  "$HOOKS/lib/command-scan.sh" 'THE WORD LIST IS PART OF THE LOAD'

echo "--- the contract is written where the rename is made ---"
# The checks above are evidence about four guards as they stand. They say nothing
# about the next cs_* rename, which is made in lib/command-scan.sh by someone who
# has no reason to open four hooks -- so the file being edited is where the
# consequence has to be written, and these hold it there. `written` rather than
# `armed`: this is prose, and stripping comments would leave nothing to match.
req GH-84.3
written 'the library states the load contract' \
  "$HOOKS/lib/command-scan.sh" 'THE LOAD CONTRACT'
written 'and says that a rename reaches every consumer and this suite' \
  "$HOOKS/lib/command-scan.sh" 'RENAMING A cs_* FUNCTION REACHES EVERY FILE THAT SOURCES THIS ONE'
written 'and records why this is not one sourced preamble' \
  "$HOOKS/lib/command-scan.sh" 'Not factored into one sourced preamble'
# The pointer, from each of the four. #84's finding was not that the argument was
# unwritten but that it was written in one hook and read by nobody editing the
# other three, so a guard that does not point at the shared statement is a guard
# whose reasoning is about to be re-derived or dropped.
for hook in no-git-push.sh no-pr-decisions.sh no-commit-to-main.sh no-work-on-stale-branch.sh; do
  written "$hook points at the contract by name" "$HOOKS/$hook" 'THE LOAD CONTRACT'
done
written 'append-only-docs.sh points at the contract by name, having taken a guard in #96' \
  "$HOOKS/append-only-docs.sh" 'THE LOAD CONTRACT'
# And that each guard is live code rather than a commented-out line. `armed`
# strips comments first, which is the difference that matters: every literal
# above would match a guard commented out during a debugging session and left
# that way, and review of PR #64 found exactly that shape in this suite. One
# literal per hook per function, because that is the claim being made.
req GH-84.2
armed 'no-git-push.sh requires cs_normalise' "$HOOKS/no-git-push.sh" 'command -v cs_normalise'
armed 'no-git-push.sh requires cs_split' "$HOOKS/no-git-push.sh" 'command -v cs_split'
armed 'no-git-push.sh requires cs_git_args' "$HOOKS/no-git-push.sh" 'command -v cs_git_args'
armed 'no-pr-decisions.sh requires cs_normalise' "$HOOKS/no-pr-decisions.sh" 'command -v cs_normalise'
armed 'no-pr-decisions.sh requires cs_split' "$HOOKS/no-pr-decisions.sh" 'command -v cs_split'
armed 'no-pr-decisions.sh requires cs_gh_args' "$HOOKS/no-pr-decisions.sh" 'command -v cs_gh_args'
armed 'no-pr-decisions.sh requires cs_join' "$HOOKS/no-pr-decisions.sh" 'command -v cs_join'
armed 'no-commit-to-main.sh requires cs_normalise' "$HOOKS/no-commit-to-main.sh" 'command -v cs_normalise'
armed 'no-commit-to-main.sh requires cs_split' "$HOOKS/no-commit-to-main.sh" 'command -v cs_split'
armed 'no-commit-to-main.sh requires cs_git_args' "$HOOKS/no-commit-to-main.sh" 'command -v cs_git_args'
armed 'no-work-on-stale-branch.sh requires cs_normalise' "$HOOKS/no-work-on-stale-branch.sh" 'command -v cs_normalise'
armed 'no-work-on-stale-branch.sh requires cs_split' "$HOOKS/no-work-on-stale-branch.sh" 'command -v cs_split'
armed 'no-work-on-stale-branch.sh requires cs_git_args' "$HOOKS/no-work-on-stale-branch.sh" 'command -v cs_git_args'
armed 'pytest-via-uv-group.sh requires cs_normalise' "$HOOKS/pytest-via-uv-group.sh" 'command -v cs_normalise'
armed 'pytest-via-uv-group.sh requires cs_split' "$HOOKS/pytest-via-uv-group.sh" 'command -v cs_split'
armed 'alembic-via-uv-group.sh requires cs_normalise' "$HOOKS/alembic-via-uv-group.sh" 'command -v cs_normalise'
armed 'alembic-via-uv-group.sh requires cs_split' "$HOOKS/alembic-via-uv-group.sh" 'command -v cs_split'
armed 'no-git-push.sh requires cs_within_cap' "$HOOKS/no-git-push.sh" 'command -v cs_within_cap'
armed 'no-pr-decisions.sh requires cs_within_cap' "$HOOKS/no-pr-decisions.sh" 'command -v cs_within_cap'
armed 'no-commit-to-main.sh requires cs_within_cap' "$HOOKS/no-commit-to-main.sh" 'command -v cs_within_cap'
armed 'no-work-on-stale-branch.sh requires cs_within_cap' "$HOOKS/no-work-on-stale-branch.sh" 'command -v cs_within_cap'
armed 'pytest-via-uv-group.sh requires cs_within_cap' "$HOOKS/pytest-via-uv-group.sh" 'command -v cs_within_cap'
armed 'alembic-via-uv-group.sh requires cs_within_cap' "$HOOKS/alembic-via-uv-group.sh" 'command -v cs_within_cap'
armed 'append-only-docs.sh requires cs_within_cap' "$HOOKS/append-only-docs.sh" 'command -v cs_within_cap'
for hook in $LIB_CONSUMERS; do
  armed "$hook requires cs_tool_input" "$HOOKS/$hook" 'command -v cs_tool_input'
done
# The readability test before the source, which no fixture above can tell apart:
# under bash a `.` of a missing file returns non-zero and carries on, so nolib
# behaves the same with it and without it. It is held as text for that reason,
# and because all four comments claim it.
armed 'no-git-push.sh tests the library before sourcing it' \
      "$HOOKS/no-git-push.sh" '[ -r "$LIB" ] && . "$LIB"'
armed 'no-pr-decisions.sh tests the library before sourcing it' \
      "$HOOKS/no-pr-decisions.sh" '[ -r "$LIB" ] && . "$LIB"'
armed 'no-commit-to-main.sh tests the library before sourcing it' \
      "$HOOKS/no-commit-to-main.sh" '[ -r "$LIB" ] && . "$LIB"'
armed 'no-work-on-stale-branch.sh tests the library before sourcing it' \
      "$HOOKS/no-work-on-stale-branch.sh" '[ -r "$LIB" ] && . "$LIB"'
armed 'pytest-via-uv-group.sh tests the library before sourcing it' \
      "$HOOKS/pytest-via-uv-group.sh" '[ -r "$LIB" ] && . "$LIB"'
armed 'alembic-via-uv-group.sh tests the library before sourcing it' \
      "$HOOKS/alembic-via-uv-group.sh" '[ -r "$LIB" ] && . "$LIB"'
armed 'append-only-docs.sh tests the library before sourcing it' \
      "$HOOKS/append-only-docs.sh" '[ -r "$LIB" ] && . "$LIB"'
armed 'append-only-docs-edit.sh tests the library before sourcing it' \
      "$HOOKS/append-only-docs-edit.sh" '[ -r "$LIB" ] && . "$LIB"'
echo "--- the required list is the call list, and these are all the consumers ---"
# THE ONE CHECK HERE THAT SURVIVES THE NEXT CHANGE. Every literal above names a
# file and a function, so all of them together say that these guards require
# these names -- and none of them says a required list is COMPLETE. #84 was
# a required list narrower than a call set. A fifth cs_* call added to a hook
# tomorrow, or another file that sources the library, leaves every check above
# green and is the same defect one turn later. That is not a hypothetical either:
# #69 added two sourcers while #84 was being written, and this pair of checks is
# what said so.
#
# So both sides are derived from the files and compared with each other, in the
# direction the boundary section at the foot of this suite uses: the code is the
# fact, the guard's required list is the claim asserted against it. Comments are
# stripped first, for the reason `armed` strips them -- these headers name these
# functions constantly, and a function named in prose is not a call.
cs_calls() {  # cs_calls <hook> -- the cs_* functions its code actually calls
  sed 's/[[:space:]]*#.*$//' "$HOOKS/$1" \
    | grep -v 'command -v cs_' \
    | grep -oE 'cs_[a-z_]+' | sort -u | tr '\n' ' '
}
cs_required() {  # cs_required <hook> -- the cs_* functions its load guard requires
  sed 's/[[:space:]]*#.*$//' "$HOOKS/$1" \
    | grep -oE 'command -v cs_[a-z_]+' | sed 's/command -v //' | sort -u | tr '\n' ' '
}
req GH-84.2
for hook in $LIB_CONSUMERS; do
  CALLS=$(cs_calls "$hook")
  REQUIRED=$(cs_required "$hook")
  # An empty derivation would make the comparison pass by matching nothing, which
  # is the permitting direction: a hook whose calls could not be read would report
  # as agreeing with a guard that requires nothing.
  if [ -z "$CALLS" ] || [ -z "$REQUIRED" ]; then
    fail static '%s: no cs_* calls or no required names were read out of the file at all' "$hook"
  elif [ "$CALLS" = "$REQUIRED" ]; then
    pass static 'derived %s requires exactly what it calls: %s' "$hook" "${CALLS% }"
  else
    fail static '%s requires a set other than the one it calls\n         calls:    |%s|\n         requires: |%s|' \
      "$hook" "$CALLS" "$REQUIRED"
  fi
done
# And that LIB_CONSUMERS is all of them -- a file that sources the library and
# guards nothing is #84 again, and nothing above would see it, because every
# literal above names a file.
#
# $CS_SOURCERS is the #69 audit's derivation, a few checks up: every .sh beside
# this suite whose code (comments stripped) loads the tokeniser, less the two
# that name the file without loading it -- this suite and mutate-hooks.sh --
# which are excluded there by name. It is reused rather than re-derived, because
# a second answer to "who sources this file" is the defect both of these sections are
# about. #69 asserts the tokeniser's header against it; #84 asserts the list of
# hooks whose load guard is driven above. Its spacing is its own -- leading and
# trailing -- so this normalises rather than assuming.
SOURCERS=$(printf '%s\n' $CS_SOURCERS | sort | tr '\n' ' ')
CLAIMED=$(printf '%s\n' $LIB_CONSUMERS | sort | tr '\n' ' ')
if [ -n "$SOURCERS" ] && [ "$SOURCERS" = "$CLAIMED" ]; then
  pass static 'derived the files that load the library are exactly the ones checked here: %s' "${SOURCERS% }"
else
  fail static 'the files that load the library are not the four this section checks\n         load it: |%s|\n         checked: |%s|' \
    "$SOURCERS" "$CLAIMED"
fi
# One property of this suite's own helpers, because nothing else here drives them
# and `unarmed` reporting ok for a file it never read would make four pins below
# vacuous. Run in a subshell so its FAILED cannot reach ours.
if ( FAILED=0; unarmed 'self-check' "$FIXTURES/no-such-file" 'anything'; exit $FAILED ) >/dev/null 2>&1
then
  fail static 'unarmed reports ok for a file that is not there, so every pin below is vacuous'
else
  pass static 'unarmed fails for a file that is not there, so the pins below are about a file that was read'
fi

# The refusing direction: a hook back to sourcing the library with nothing around
# it is the #84 shape exactly, and it would satisfy every `written` above. Asked
# of all four and not only of the two that had it, because a regression is not
# more likely in the files that carried the defect -- these four are edited
# together and the shape is one line long.
unarmed 'no-git-push.sh does not source the library unguarded' \
        "$HOOKS/no-git-push.sh" '. "$(dirname "$0")/lib/command-scan.sh"'
unarmed 'no-pr-decisions.sh does not source the library unguarded' \
        "$HOOKS/no-pr-decisions.sh" '. "$(dirname "$0")/lib/command-scan.sh"'
unarmed 'no-commit-to-main.sh does not source the library unguarded' \
        "$HOOKS/no-commit-to-main.sh" '. "$(dirname "$0")/lib/command-scan.sh"'
unarmed 'no-work-on-stale-branch.sh does not source the library unguarded' \
        "$HOOKS/no-work-on-stale-branch.sh" '. "$(dirname "$0")/lib/command-scan.sh"'
unarmed 'pytest-via-uv-group.sh does not source the library unguarded' \
        "$HOOKS/pytest-via-uv-group.sh" '. "$(dirname "$0")/lib/command-scan.sh"'
unarmed 'alembic-via-uv-group.sh does not source the library unguarded' \
        "$HOOKS/alembic-via-uv-group.sh" '. "$(dirname "$0")/lib/command-scan.sh"'
unarmed 'append-only-docs.sh does not source the library unguarded' \
        "$HOOKS/append-only-docs.sh" '. "$(dirname "$0")/lib/command-scan.sh"'
unarmed 'append-only-docs-edit.sh does not source the library unguarded' \
        "$HOOKS/append-only-docs-edit.sh" '. "$(dirname "$0")/lib/command-scan.sh"'

section "=== issue #95: every hook refuses when it cannot read its input ==="
# #84 made a hook that cannot load lib/command-scan.sh refuse. It did not reach
# the step before that: every hook read its input with its own `jq` call, and when
# the read failed the command was empty and the hook exited 0. Measured at
# dev-05 e8c132f, all eight hooks, each condition below: exit 0 in every cell,
# including `git push --force origin main` and `gh pr merge 5` with jq off PATH.
# No check asked, because every helper above builds its payload with jq from a
# command string -- none of them can hand a hook stdin that is not JSON, or a
# command that is not a string. The harness's half of the seam was assumed.
#
# The fail direction is #103's Q19, stated in #95: refuse when jq is absent, when
# stdin is not valid JSON, and when the field the hook reads is missing or not a
# string; permit only an empty command string, which has nothing to run. A change
# to the harness's payload then shows as every Bash call refused, not as every
# guard switched off without a word -- CLAUDE.md's left-open item 3.
#
# Both directions, and they do not fail the same way. Every BLOCK here fails at
# e8c132f. The ALLOWs pass there and are not evidence about the fix; they are
# evidence about the fix going too far, and each names the over-fix it catches.
#
# The checks drive feed and feed_says, which hand a hook raw stdin; they are
# defined beside check_file, because the load-contract section above needs them
# for the two consumers #95 added.

# jq off PATH, built here rather than assumed about the machine: a directory of
# symlinks to every executable on this suite's own PATH -- plus a `gh`, which GH
# IN THE FARM below synthesises if the host gave none -- and a copy of it with
# jq removed. Every tool, not the ones a hook is known to call today -- a list of
# those would be a claim, and the next hook to call a new tool would refuse
# without jq for a reason no check names.
#
# The with-jq twin is the control that makes the other one evidence. A hook that
# refuses under the jq-less PATH might be refusing because the fixture is broken
# -- a tool missing, a link dangling -- and that refusal would read as the fix. So
# every jq-less BLOCK below stands beside the same payload under the twin, which
# must ALLOW, and the guard asserts the two directories differ by jq and nothing
# else.
WITH_JQ_BIN="$FIXTURES/path-with-jq"
NO_JQ_BIN="$FIXTURES/path-without-jq"
mkdir -p "$WITH_JQ_BIN"
IFS=: read -ra SUITE_PATH_DIRS <<< "$PATH"
for d in "${SUITE_PATH_DIRS[@]}"; do
  [ -d "$d" ] || continue
  # ln -t without -f keeps the first of two same-named tools, which is the one
  # PATH lookup would have found; the "File exists" for the second is expected.
  find "$d" -maxdepth 1 \( -type f -o -type l \) -perm -u+x \
    -exec ln -s -t "$WITH_JQ_BIN" {} + 2>/dev/null
done

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
FARM_STUB_SAYS='gh: check-hooks.sh PATH-fixture stub, a name and not a program (GH-155.1)'
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
farm_stub_gh "$WITH_JQ_BIN" || {
  echo "no gh could be synthesised into the symlink farm; the #108 fixtures below prove nothing" >&2
  exit 1
}

cp -a "$WITH_JQ_BIN" "$NO_JQ_BIN"
rm -f "$NO_JQ_BIN/jq"
[ -n "$( PATH="$WITH_JQ_BIN"; command -v jq )" ] \
  && [ -z "$( PATH="$NO_JQ_BIN"; command -v jq )" ] \
  && [ "$(diff <(ls -A "$WITH_JQ_BIN") <(ls -A "$NO_JQ_BIN") | grep -c '^[<>]')" = 1 ] \
  && [ "$(diff <(ls -A "$WITH_JQ_BIN") <(ls -A "$NO_JQ_BIN") | grep '^[<>]')" = '< jq' ] || {
  echo "the jq-less PATH fixture is not the with-jq one minus jq; the checks using it prove nothing" >&2
  exit 1
}
[ -e "$REPO_ROOT/src/config.py" ] || {
  echo "src/config.py is not there, so the Edit hook's controls would permit for want of a file; they would prove nothing" >&2
  exit 1
}

# The hooks, as literals, split by the field they read. The derivation at the end
# of this section asserts these are every hook settings.json registers -- #84's
# lesson, that the literal list is the claim and the files are the fact.
INPUT_BASH_HOOKS="alembic-via-uv-group.sh append-only-docs.sh no-commit-to-main.sh no-git-push.sh no-pr-decisions.sh no-work-on-stale-branch.sh pytest-via-uv-group.sh"
INPUT_EDIT_HOOKS="append-only-docs-edit.sh"

echo "--- the seven Bash hooks, tool_input.command ---"
req GH-95.1 FR-49
for hook in $INPUT_BASH_HOOKS; do
  feed "$WITH_JQ_BIN" "$hook" ALLOW "$hook: control, the symlinked PATH with jq in it permits ls" \
    '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
  feed "$NO_JQ_BIN" "$hook" BLOCK "$hook: jq not on PATH, and the command is only ls" \
    '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
  feed_says "$NO_JQ_BIN" "$hook" 'jq is not on PATH' \
    "$hook: and the refusal names the cause, so the fix is one install away" \
    '{"tool_name":"Bash","tool_input":{"command":"ls"}}'

  # Not valid JSON. The trailing-text case is the one a reader that checks only
  # for output gets wrong: jq prints the command from the first value and then
  # exits non-zero on the rest.
  feed "$PATH" "$hook" BLOCK "$hook: stdin is plain text, not JSON" \
    'git push --force origin main'
  feed "$PATH" "$hook" BLOCK "$hook: stdin is JSON cut off before its closing braces" \
    '{"tool_name":"Bash","tool_input":{"command":"git push --force origin main"'
  feed "$PATH" "$hook" BLOCK "$hook: stdin is a JSON object with text after it" \
    '{"tool_name":"Bash","tool_input":{"command":"ls"}} trailing'
  # Two values is a stream jq reads happily, one command per value, and not one
  # tool call. The harness sends one; a reader that took the first would judge a
  # command other than the second, so neither is read.
  feed "$PATH" "$hook" BLOCK "$hook: stdin is two JSON objects, one after the other" \
    '{"tool_name":"Bash","tool_input":{"command":"ls"}}{"tool_name":"Bash","tool_input":{"command":"ls"}}'
  # Empty stdin is not an error to jq: it reads no values, prints nothing and
  # exits 0. A fix that trusts jq's exit status alone permits this one.
  feed "$PATH" "$hook" BLOCK "$hook: stdin is empty" \
    ''
  feed "$PATH" "$hook" BLOCK "$hook: stdin is the JSON value null" \
    'null'
  feed "$PATH" "$hook" BLOCK "$hook: stdin is a JSON array" \
    '[]'

  # Valid JSON, and the field is not there.
  feed "$PATH" "$hook" BLOCK "$hook: no tool_input at all" \
    '{"tool_name":"Bash"}'
  feed "$PATH" "$hook" BLOCK "$hook: tool_input is a string, not an object" \
    '{"tool_name":"Bash","tool_input":"ls"}'
  feed "$PATH" "$hook" BLOCK "$hook: tool_input with no command, the row #95 measured" \
    '{"tool_name":"Bash","tool_input":{}}'
  feed "$PATH" "$hook" BLOCK "$hook: an Edit payload, whose file_path is not the field this hook reads" \
    '{"tool_name":"Edit","tool_input":{"file_path":"ls"}}'

  # The field is there and is not a string.
  feed "$PATH" "$hook" BLOCK "$hook: command is null" \
    '{"tool_name":"Bash","tool_input":{"command":null}}'
  feed "$PATH" "$hook" BLOCK "$hook: command is a number" \
    '{"tool_name":"Bash","tool_input":{"command":42}}'
  feed "$PATH" "$hook" BLOCK "$hook: command is an array of words" \
    '{"tool_name":"Bash","tool_input":{"command":["git","push","--force","origin","main"]}}'
  feed "$PATH" "$hook" BLOCK "$hook: command is an object" \
    '{"tool_name":"Bash","tool_input":{"command":{"text":"ls"}}}'

  # The permitting direction. An empty string is the one fail-open condition #95
  # names: there is nothing to run. A fix that refuses whenever the command is
  # empty, rather than whenever it was not read, turns this red.
  feed "$PATH" "$hook" ALLOW "$hook: command is the empty string, which runs nothing" \
    '{"tool_name":"Bash","tool_input":{"command":""}}'
  # `jq -r` prints a JSON null as the four letters null. A fix that compares its
  # output to "null" refuses this string; one that does not compare permits the
  # null above. Only reading the type answers both.
  feed "$PATH" "$hook" ALLOW "$hook: command is the string \"null\", which is a string" \
    '{"tool_name":"Bash","tool_input":{"command":"null"}}'
done

echo "--- the trade, taken knowingly: without jq the convention hooks refuse what they permit ---"
# #95 records this rather than only the fix. With jq absent every Bash command is
# refused, the ones these two hooks exist to permit included. Each refusal stands
# beside its twin under the with-jq PATH, so the pair says the command is one the
# hook permits and that jq's absence alone is what turns it.
req GH-95.2 FR-49
feed "$WITH_JQ_BIN" pytest-via-uv-group.sh ALLOW 'pytest the way CLAUDE.md says to run it, jq on PATH' \
  '{"tool_name":"Bash","tool_input":{"command":"uv run --group test pytest tests/"}}'
feed "$NO_JQ_BIN" pytest-via-uv-group.sh BLOCK 'the same pytest, jq not on PATH' \
  '{"tool_name":"Bash","tool_input":{"command":"uv run --group test pytest tests/"}}'
feed "$WITH_JQ_BIN" alembic-via-uv-group.sh ALLOW 'alembic the way CLAUDE.md says to run it, jq on PATH' \
  '{"tool_name":"Bash","tool_input":{"command":"uv run --group migrations alembic upgrade head"}}'
feed "$NO_JQ_BIN" alembic-via-uv-group.sh BLOCK 'the same alembic, jq not on PATH' \
  '{"tool_name":"Bash","tool_input":{"command":"uv run --group migrations alembic upgrade head"}}'

echo "--- append-only-docs-edit.sh, tool_input.file_path ---"
# The Edit hook read `.tool_input.file_path // empty`, so null, false and a
# missing field all became "no file" and were permitted before the path was ever
# compared. The controls name a file that exists outside the guarded directories,
# by absolute path as the harness sends one, so their ALLOW is the hook's answer
# about the path and not about a file that is not there.
#
# An empty file_path string is permitted, and pinned below. #95 names the empty
# string as the fail-open case for a command and says nothing about a path, so
# the fix decided it: an empty path names no file, there is nothing to protect,
# and it is what the hook returned before. Recorded in the hook, and here.
# EDIT_CONTROL is built once, in the load-contract section above.
req GH-95.1 FR-49
for hook in $INPUT_EDIT_HOOKS; do
  feed "$WITH_JQ_BIN" "$hook" ALLOW "$hook: control, the symlinked PATH with jq in it permits an edit of src/config.py" \
    "$EDIT_CONTROL"
  feed "$NO_JQ_BIN" "$hook" BLOCK "$hook: jq not on PATH, and the file is outside every guarded directory" \
    "$EDIT_CONTROL"
  feed_says "$NO_JQ_BIN" "$hook" 'jq is not on PATH' \
    "$hook: and the refusal names the cause" \
    "$EDIT_CONTROL"

  feed "$PATH" "$hook" BLOCK "$hook: stdin is plain text, not JSON" \
    'docs/dev-log/devlog_2026-08-25_session-2.md'
  feed "$PATH" "$hook" BLOCK "$hook: stdin is JSON cut off before its closing braces" \
    '{"tool_name":"Edit","tool_input":{"file_path":"docs/dev-log/devlog_2026-08-25_session-2.md"'
  feed "$PATH" "$hook" BLOCK "$hook: stdin is a JSON object with text after it" \
    '{"tool_name":"Edit","tool_input":{"file_path":"src/config.py"}} trailing'
  feed "$PATH" "$hook" BLOCK "$hook: stdin is two JSON objects, one after the other" \
    '{"tool_name":"Edit","tool_input":{"file_path":"src/config.py"}}{"tool_name":"Edit","tool_input":{"file_path":"src/config.py"}}'
  feed "$PATH" "$hook" BLOCK "$hook: stdin is empty" \
    ''
  feed "$PATH" "$hook" BLOCK "$hook: stdin is the JSON value null" \
    'null'
  feed "$PATH" "$hook" BLOCK "$hook: stdin is a JSON array" \
    '[]'

  feed "$PATH" "$hook" BLOCK "$hook: no tool_input at all" \
    '{"tool_name":"Edit"}'
  feed "$PATH" "$hook" BLOCK "$hook: tool_input is a string, not an object" \
    '{"tool_name":"Edit","tool_input":"src/config.py"}'
  feed "$PATH" "$hook" BLOCK "$hook: tool_input with no file_path" \
    '{"tool_name":"Edit","tool_input":{}}'
  feed "$PATH" "$hook" BLOCK "$hook: a Bash payload, whose command is not the field this hook reads" \
    '{"tool_name":"Bash","tool_input":{"command":"docs/dev-log/devlog_2026-08-25_session-2.md"}}'

  feed "$PATH" "$hook" BLOCK "$hook: file_path is null" \
    '{"tool_name":"Edit","tool_input":{"file_path":null}}'
  feed "$PATH" "$hook" BLOCK "$hook: file_path is false, which // empty also swallowed" \
    '{"tool_name":"Edit","tool_input":{"file_path":false}}'
  feed "$PATH" "$hook" BLOCK "$hook: file_path is a number" \
    '{"tool_name":"Edit","tool_input":{"file_path":42}}'
  feed "$PATH" "$hook" BLOCK "$hook: file_path is an array" \
    '{"tool_name":"Edit","tool_input":{"file_path":["docs","dev-log"]}}'
  feed "$PATH" "$hook" BLOCK "$hook: file_path is an object" \
    '{"tool_name":"Edit","tool_input":{"file_path":{"path":"src/config.py"}}}'

  # The permitting direction, and the trade the fix decided: see the note above.
  feed "$PATH" "$hook" ALLOW "$hook: file_path is the empty string, which names no file" \
    '{"tool_name":"Edit","tool_input":{"file_path":""}}'
  feed "$PATH" "$hook" ALLOW "$hook: file_path is the string \"null\", which is a path that is not there" \
    '{"tool_name":"Edit","tool_input":{"file_path":"null"}}'
done

echo "--- every registered hook is one of these, and the read is written once ---"
# The two lists above are the claim; settings.json is the fact. A hook registered
# tomorrow with its own input read is #95 again, and every literal above would
# stay green, so the lists are derived from the registration and compared. A
# matcher is split on | so that a hook registered for Bash|Edit lands in both.
registered_for() {  # registered_for <tool> -- hook basenames whose matcher names it
  jq -r --arg t "$1" \
    '.hooks.PreToolUse[] | select(any(.matcher | split("|")[]; . == $t)) | .hooks[].command' \
    "$REPO_ROOT/.claude/settings.json" 2>/dev/null \
    | sed 's#^.*/##; s#"$##' | sort -u | tr '\n' ' '
}
req GH-95.2
for pair in "Bash:$INPUT_BASH_HOOKS" "Edit:$INPUT_EDIT_HOOKS" "Write:$INPUT_EDIT_HOOKS"; do
  tool=${pair%%:*}
  REGISTERED=$(registered_for "$tool")
  CLAIMED=$(printf '%s\n' ${pair#*:} | sort -u | tr '\n' ' ')
  # Empty is the permitting direction: a settings.json that could not be read
  # would agree with an empty list.
  if [ -n "$REGISTERED" ] && [ "$REGISTERED" = "$CLAIMED" ]; then
    pass static 'derived the hooks registered for %s are exactly the ones checked here: %s' "$tool" "${REGISTERED% }"
  else
    fail static 'the hooks registered for %s are not the ones this section checks\n         registered: |%s|\n         checked:    |%s|' \
      "$tool" "$REGISTERED" "$CLAIMED"
  fi
done
# #103's Q27: the read moves into one shared reader in lib/command-scan.sh, so
# that eight copies cannot disagree. Comments are stripped first, for the reason
# `armed` strips them. The Edit hook is asked too: #95 let it keep its own copy
# if the pull request recorded why, and it took the shared reader instead.
# The strip has `armed`'s soft spot, named rather than closed: it cuts at the
# `#` of a parameter expansion too, so a jq call later on a line holding `${x#y}`
# would be hidden from this text check. What would still hold is the behavioural
# half: the checks above take jq off PATH and feed malformed input whatever a
# hook's text says, so a hidden second copy could disagree with the reader only
# where they do not look.
for hook in $INPUT_BASH_HOOKS $INPUT_EDIT_HOOKS; do
  if sed 's/[[:space:]]*#.*$//' "$HOOKS/$hook" | grep -qw jq; then
    fail static '%s still calls jq itself rather than the shared reader' "$hook"
  else
    pass static 'derived %s does not call jq itself' "$hook"
  fi
done
# And the reader is the library's, in live code. `armed` strips comments, so a
# reader commented out would not satisfy it; the behavioural checks above would
# go red too, but this one names where.
armed 'the library defines the shared reader' "$HOOKS/lib/command-scan.sh" 'cs_tool_input() {'
# #95's acceptance: the fail direction for each condition stated in one place.
# `written`, because it is prose.
written 'the library states the fail direction of the input read' \
  "$HOOKS/lib/command-scan.sh" 'THE INPUT READ'
written 'and records the trade an environment without jq pays' \
  "$HOOKS/lib/command-scan.sh" 'THE TRADE, taken knowingly'

echo "--- issue #96: a line long enough to outlast the timeout ---"
# The harness kills a hook that runs past its "timeout" in settings.json, and a
# killed hook never exits 2 -- which is the only refusal `check` reads, because
# it is the only one the harness reads. So how long a hook runs is part of its
# verdict. The issue measured all three boundary hooks past their 5 s on one
# line of 300 KB, and `echo <300 KB>; git push --force origin main` was
# permitted by every one of them. The cost is cs_normalise and cs_split, each
# quadratic in the length of a single line: measured at e8c132f under mawk
# 1.3.4, LC_ALL=C, fastest of three, cs_normalise took 1.03 s at 200 KB, 1.9 s
# at 256 KB and 9.3 s at 512 KB, and cs_split 1.07, 1.9 and 10.8 s.
#
# Decided in the grilling recorded on #103 (Q28), and every number below is a
# literal from it: a line longer than 16 KB -- 16384 bytes -- is refused, with a
# message that says so and says to split the line or write the content to a
# file; the quadratic passes are made linear; and each hook finishes a command
# whose longest line sits at the cap in under 1 s, fastest of three runs.
#
# #96 asks that every new check fail with the fix reverted. Not all of these
# can, and which is which is the part worth reading. Measured, not reasoned:
# this suite was run against the hooks and library as they stood before the fix.
#
#   - RED against the unfixed hooks: every over-the-cap BLOCK and every cap
#     message, in every spelling below, the two library timings, the cap
#     succeeding at exactly 16384 bytes, and every load-contract check for
#     cs_within_cap and for append-only-docs.sh's new guard.
#   - PINS, green against them: the at-the-cap verdicts, the controls, the
#     200 KB heredoc, the timeout in settings.json, and the per-hook timing at
#     the cap. A 16 KB line costs the unfixed hooks about 0.1 s, so a 1 s bound
#     AT the cap cannot tell the fix from its absence. It is the bound the issue
#     decided, and it guards against the next pass that is slower again. What
#     holds the linear passes is the library timing, and it is here for that
#     reason. The output checks beside those timings are green unfixed too:
#     the passes were right and slow, and those checks are there for the cap
#     that would be fast by being wrong.
#   - GREEN FOR A REASON THAT IS NOT THE FIX: the three cs_within_cap checks
#     expecting `over`, since the function did not exist and bash -c answers
#     127. What they are evidence about is a wrong cs_within_cap rather than a
#     missing one, and that was measured by planting one: reading awk's status
#     alone turned the missing-cs_join check red and nothing else.
#
# Eight defects were planted to see each group go red, and each did: the cap
# written as >= (the at-the-cap verdicts), measured on raw lines (the continued
# pair), the pipeline status dropped (the missing-cs_join check), one hook's
# cs_within_cap guard removed (its guard message, its armed pin and its derived
# required set), a quadratic string build put back in the separator cut (the
# 512 KB cs_split timing), each old pass restored alone (its scaling check), a
# copied awk helper drifted (the identical-copies check), and cs_git_args
# renamed away under the scaling checks (their exit status). This comment
# said five until review of PR #123 counted the eight its description listed.
# A check suite is evidence about the cases it names; those are eight of them.
#
# TWO ADDITIONS TO THE ISSUE'S LIST, both measured before they were written.
#
# The cap is on the line the passes see, which is the line after cs_join and
# not the raw one. 3,800 lines of 84 bytes, each ending in a backslash, are one
# 300 KB line once joined, and with a push after them took the three boundary
# hooks 5.7 to 9.7 s. No raw line there is near 16 KB, so a cap that reads raw
# lines never fires on it. The criterion "200 KB spread across 80-column lines
# is judged on its content" is kept, in the shape the audit measured it in: a
# heredoc body, which is dropped rather than joined.
#
# The linear passes get checks of their own, aimed at the library rather than
# through a hook, because once the cap is in no hook can be handed a line long
# enough to show them. One long plain line holds cs_normalise and cs_split's
# separator cut. cs_join, the prefix strip and both argument readers were
# quadratic too, but in how many continuations, prefix words or options a line
# held, so they are held by the scaling checks at the end of this section. Each
# rewrite was also fuzzed against the version before it for identical output;
# that is recorded in the library, and is not something a check here repeats.
# Every one of these checks asserts what comes back as well as how fast, so a
# cap placed INSIDE cs_normalise or cs_split -- fast because it returns early
# -- turns them red rather than green. The cap belongs in front of those
# passes, not in them.
#
# EVERY BASH HOOK, read off settings.json rather than listed, which is the
# criterion's wording, and asserted below to be exactly the hooks whose code
# calls cs_within_cap. append-only-docs.sh takes the function from the library
# beside the reader #95 gave it; see its header.
#
# no-work-on-stale-branch.sh was first written to hold the cap only on a stale
# or gone branch, and only for a command naming git, because its library was
# loaded only past those two exits. #95 moved the load and the read to the top
# of that file, so the cap moved with them and now holds wherever the hook runs.
# Every fixture below that names nothing still says `git` in passing -- `echo
# git`, and a python3 string holding the word -- from when that mattered; it is
# harmless to every hook, and it keeps the stale branch's rules, which sit
# behind that bail, inside what these checks reach. It is asked on a stale
# branch for the same reason, and on a branch carrying work once, below.
#
# NOT HERE, and named because a check suite is evidence about what it names:
# the cost is per command as well as per line, and so THE CAP DOES NOT BOUND A
# HOOK'S RUNNING TIME -- only the length of a line. 2,500 lines of `echo <75 a>`
# and a `gh pr merge 5` -- 202 KB, no line over 80 bytes -- took
# no-pr-decisions.sh 5.9 s and no-commit-to-main.sh 4.4 s, fastest of three,
# and the harness permits past 5 s. It is linear, a few milliseconds a
# fragment, since each fragment cs_split emits starts an awk or more. That
# first made it look like a matter of size, which it is not: review of PR #123
# put the 2,500 on one line as `t;`, 5,014 bytes and a third of the cap, and
# no-pr-decisions.sh took 6.4 s idle; filled to the cap, 8,192 of them and a
# push outlasted all three boundary hooks. Neither remedy #96 decided reaches
# it, and a check for it would be a decision that issue did not take: it is
# #127. A first figure written here, 10 s for 250 lines, was taken on a loaded
# machine and did not reproduce: those 250 take 0.66 s.
#
# THE SECOND TRADE, found by review of this section: the cap joins
# continuations without knowing what a quoted heredoc is, so a body of short
# lines that each end in a backslash is refused as one long line, which bash
# would never read it as. Recorded in the library under THE LINE CAP, and
# pinned below.
BASH_HOOKS=$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[].command' \
               "$SUITE_DIR/../settings.json" 2>/dev/null | sed 's|.*/||' | sort | tr '\n' ' ')
[ -n "$BASH_HOOKS" ] || {
  echo "no Bash hooks were read out of settings.json; the checks below prove nothing" >&2
  exit 1
}
req GH-96.2
tok 'every Bash hook runs under the 5 s timeout the 1 s bound is set against' \
    '5' "$(jq -r '[.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[].timeout]
                  | unique | map(tostring) | join(" ")' "$SUITE_DIR/../settings.json")"

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
# The hooks that call cs_within_cap, derived off their code in the load-contract
# section, are the Bash hooks settings.json registers -- no more, since the Edit
# hook reads no command, and no fewer, which is the #84 shape.
req GH-96.1
CAPPED=$(printf '%s\n' $CAP_CONSUMERS | sort | tr '\n' ' ')
if [ "$CAPPED" = "$BASH_HOOKS" ]; then
  pass static 'derived the hooks that call cs_within_cap are exactly the Bash hooks: %s' "${CAPPED% }"
else
  fail static 'the hooks that call cs_within_cap are not the Bash hooks settings.json registers\n         call it: |%s|\n         Bash:    |%s|' \
    "$CAPPED" "$BASH_HOOKS"
fi
for hook in $BASH_HOOKS; do
  if [ ! -x "$HOOKS/$hook" ]; then
    fail static 'settings.json runs %s, which is not an executable file beside this suite' "$hook"
  elif [ -z "$(cap_refused "$hook")" ]; then
    fail static '%s is a Bash hook with no row in cap_refused, so the cap is not asked of it' "$hook"
  fi
done

# The fixtures. Each is built to a byte count and then measured, because a
# builder one byte out turns the 16384/16385 pair into 16383/16384 and every
# check below still runs -- against the wrong side of the cap.
cap_pad() {  # cap_pad <bytes> -- that many a's
  head -c "$1" /dev/zero | tr '\0' a
}
cap_line() {  # cap_line <bytes> [tail] -- `echo git `, padding, tail: exactly <bytes> bytes
  printf 'echo git %s%s' "$(cap_pad $(( $1 - 9 - $(printf '%s' "${2:-}" | wc -c) )))" "${2:-}"
}
cap_python() {  # cap_python <bytes> -- a python3 -c one-liner of exactly <bytes> bytes
  printf "python3 -c \"x = 'git %s'\"" "$(cap_pad $(( $1 - 23 )))"
}
cap_continued() {  # cap_continued <bytes> -- cap_line <bytes>, cut into 80-byte continued lines
  cap_line "$1" | fold -b -w 79 | sed '$!s/$/\\/'
}
cap_wide() {  # cap_wide <bytes> -- `echo git ` and two-byte characters, and an a if the count is odd
  local n=$(( $1 - 9 ))
  printf 'echo git %s' "$(printf '\303\251%.0s' $(seq 1 $(( n / 2 ))))"
  [ $(( n % 2 )) -eq 0 ] || printf a
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
cap_bytes() {  # cap_bytes <string>
  printf '%s' "$1" | wc -c | tr -d ' '
}
cap_guard() {  # cap_guard <fixture> <want> <got>
  [ "$2" = "$3" ] && return 0
  echo "the $1 fixture measures $3 where it was built to be $2; the checks using it prove nothing" >&2
  exit 1
}
AT_CAP=$(cap_line 16384)
OVER_CAP=$(cap_line 16385)
PY_AT=$(cap_python 16384)
PY_OVER=$(cap_python 16385)
CONT_AT=$(cap_continued 16384)
CONT_OVER=$(cap_continued 16385)
WIDE_AT=$(cap_wide 16384)
WIDE_OVER=$(cap_wide 16385)
HEREDOC_200K="cat <<'EOF'
$(for i in $(seq 1 2500); do cap_pad 79; printf '\n'; done)
EOF"
cap_guard 'at-the-cap line' 16384 "$(cap_bytes "$AT_CAP")"
cap_guard 'over-the-cap line' 16385 "$(cap_bytes "$OVER_CAP")"
cap_guard 'at-the-cap one-liner' 16384 "$(cap_bytes "$PY_AT")"
cap_guard 'over-the-cap one-liner' 16385 "$(cap_bytes "$PY_OVER")"
# A continued fixture is a long line only once joined, and short before it.
cap_guard 'at-the-cap continued, joined' 16384 "$(printf '%s' "$CONT_AT" | tr -d '\\\n' | wc -c | tr -d ' ')"
cap_guard 'over-the-cap continued, joined' 16385 "$(printf '%s' "$CONT_OVER" | tr -d '\\\n' | wc -c | tr -d ' ')"
cap_guard 'over-the-cap continued, longest raw line' 80 \
  "$(printf '%s\n' "$CONT_OVER" | LC_ALL=C awk '{ if (length($0) > m) m = length($0) } END { print m }')"
# A wide fixture is over the cap in bytes and well under it in characters, and
# that is only true where the locale counts characters; without C.UTF-8 the two
# counts agree and the pair would ask nothing.
cap_guard 'at-the-cap wide line' 16384 "$(cap_bytes "$WIDE_AT")"
cap_guard 'over-the-cap wide line' 16385 "$(cap_bytes "$WIDE_OVER")"
cap_guard 'over-the-cap wide line, in characters' 8197 \
  "$(printf '%s' "$WIDE_OVER" | LC_ALL=C.UTF-8 wc -m | tr -d ' ')"
# And as a hook receives it: check_rawfile_in's encode, the hooks' decode.
printf '%s' "$WIDE_AT" > "$FIXTURES/wide-at.txt"
printf '%s' "$WIDE_OVER" > "$FIXTURES/wide-over.txt"
cap_guard 'at-the-cap wide line, as a hook receives it' 16384 \
  "$(LC_ALL=C.UTF-8 jq -n --rawfile c "$FIXTURES/wide-at.txt" '{tool_input:{command:$c}}' \
     | LC_ALL=C.UTF-8 jq -j '.tool_input.command' | wc -c | tr -d ' ')"
cap_guard 'over-the-cap wide line, as a hook receives it' 16385 \
  "$(LC_ALL=C.UTF-8 jq -n --rawfile c "$FIXTURES/wide-over.txt" '{tool_input:{command:$c}}' \
     | LC_ALL=C.UTF-8 jq -j '.tool_input.command' | wc -c | tr -d ' ')"
# 300 lines of 80 bytes in a quoted heredoc, each ending in a backslash: 24 KB
# once joined, which bash never does to a quoted heredoc body.
HEREDOC_SLASHED="cat <<'EOF'
$(for i in $(seq 1 300); do printf 'echo git %s\\\n' "$(cap_pad 70)"; done)
EOF"
cap_guard 'slashed heredoc, longest line' 80 \
  "$(printf '%s\n' "$HEREDOC_SLASHED" | LC_ALL=C awk '{ if (length($0) > m) m = length($0) } END { print m }')"
cap_guard 'slashed heredoc, lines ending in a backslash' 300 \
  "$(printf '%s\n' "$HEREDOC_SLASHED" | grep -c '\\$')"
cap_guard '80-column heredoc, longest line' 79 \
  "$(printf '%s\n' "$HEREDOC_200K" | tail -n +2 | LC_ALL=C awk '{ if (length($0) > m) m = length($0) } END { print m }')"
cap_guard '80-column heredoc, body' 200000 \
  "$(printf '%s\n' "$HEREDOC_200K" | sed '1d;$d' | wc -c | tr -d ' ')"

# Issue #128's second consequence, which is a claim about the cap and not about
# a verdict: forty repeats of a 15,011-byte line whose opener is continued. It
# passes cs_within_cap, whose longest joined line is 15,011 bytes -- and
# cs_normalise emitted ONE line of 600,400 bytes from it, thirty-six times the
# cap, because the drop ended the body at each `E` and the join then glued all
# forty groups onto one line. So the cap did not bound what the passes were
# handed, which is what #96 claimed for it.
#
# Both numbers are literals, and the first is the one that says the fixture is
# the one described: a builder one byte out would leave every check below
# passing against a line that is not 15,011 bytes.
HEREDOC_CONT_40="$(for i in $(seq 1 40); do printf 'echo %s <<E \\\nx\nE\n' "$(cap_pad 15000)"; done)"
cap_guard 'the #128 shape, longest raw line' 15011 \
  "$(printf '%s\n' "$HEREDOC_CONT_40" | LC_ALL=C awk '{ if (length($0) > m) m = length($0) } END { print m }')"
cap_guard 'the #128 shape, groups' 40 \
  "$(printf '%s\n' "$HEREDOC_CONT_40" | grep -c '^E$')"
req GH-128
tok 'cs_normalise emits no line past the cap for #128 shape, longest line' \
    '15011' \
    "$(printf '%s\n' "$HEREDOC_CONT_40" | LC_ALL=C cs_normalise \
       | LC_ALL=C awk '{ if (length($0) > m) m = length($0) } END { print m }')"
tok 'cs_normalise emits one line per group rather than one line in all' \
    '40' \
    "$(printf '%s\n' "$HEREDOC_CONT_40" | LC_ALL=C cs_normalise | wc -l | tr -d ' ')"
# The input the cap is asked of, so the pair says what it is meant to say: the
# claim is that a command WITHIN the cap cannot be made to exceed it here, not
# that this one was refused at the door.
tok 'the #128 shape is within the cap' \
    'within' \
    "$(printf '%s\n' "$HEREDOC_CONT_40" | cs_within_cap && echo within || echo over)"
req GH-96.1

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

for hook in $BASH_HOOKS; do
  req GH-96.1
  dir=$(cap_dir "$hook")
  refused=$(cap_refused "$hook")
  [ -n "$refused" ] || continue
  # The controls: what this hook does with a short command either way, without
  # which neither verdict at the cap says whose it is.
  check_in "$dir" "$hook" ALLOW "$hook, control: a short echo" 'echo ok'
  check_in "$dir" "$hook" BLOCK "$hook, control: $refused" "$refused"

  # At the cap, judged on its content in both directions -- and the refusal is
  # the content's, which is what catches a cap written as >= instead of >.
  check_in "$dir" "$hook" ALLOW "$hook, one line of exactly 16384 bytes naming nothing" "$AT_CAP"
  check_in "$dir" "$hook" BLOCK "$hook, one line of exactly 16384 bytes ending in $refused" \
    "$(cap_line 16384 "; $refused")"
  says_not "$dir" "$hook" 'longer than 16 KB' "$hook, and that refusal is the content's rather than the cap's" \
    "$(cap_line 16384 "; $refused")"

  # One byte over, on a line that names nothing, so the BLOCK is the cap's.
  check_in "$dir" "$hook" BLOCK "$hook, one line of 16385 bytes naming nothing" "$OVER_CAP"
  says "$dir" "$hook" 'longer than 16 KB' "$hook, the cap's refusal says the line is over 16 KB" "$OVER_CAP"
  says "$dir" "$hook" 'split the line' "$hook, and says to split it" "$OVER_CAP"
  says "$dir" "$hook" 'to a file' "$hook, or to write the content to a file" "$OVER_CAP"

  # Wherever the line sits. A cap that reads the first line, or the text left
  # after cs_normalise has dropped heredoc bodies, passes the check above.
  check_in "$dir" "$hook" BLOCK "$hook, the 16385-byte line second of three" "echo first
$OVER_CAP
echo last"
  check_in "$dir" "$hook" BLOCK "$hook, the 16385-byte line inside a heredoc body" "cat <<'EOF'
$OVER_CAP
EOF"

  # The line the passes see. Every raw line of these is 80 bytes.
  check_in "$dir" "$hook" ALLOW "$hook, 16384 bytes once joined, as 80-byte continued lines" "$CONT_AT"
  check_in "$dir" "$hook" BLOCK "$hook, 16385 bytes once joined, as 80-byte continued lines" "$CONT_OVER"
  says "$dir" "$hook" 'longer than 16 KB' "$hook, and that refusal is the cap's" "$CONT_OVER"

  # Bytes, as the issue writes it -- 16 KB and one byte. In a UTF-8 locale a
  # character count of the over-the-cap line is 8197, well under the cap.
  LC_ALL=C.UTF-8 check_rawfile_in "$dir" "$hook" ALLOW \
    "$hook, 16384 bytes of two-byte characters, in a UTF-8 locale" "$WIDE_AT"
  LC_ALL=C.UTF-8 check_rawfile_in "$dir" "$hook" BLOCK \
    "$hook, 16385 bytes of two-byte characters, 8197 characters, in a UTF-8 locale" "$WIDE_OVER"

  # THE TRADE, taken knowingly in #96: a legitimate one-liner over the cap is
  # refused, and the remedy is to split it or write it to a file.
  check_in "$dir" "$hook" ALLOW "$hook, a python3 -c one-liner of 16384 bytes" "$PY_AT"
  check_in "$dir" "$hook" BLOCK "$hook, a python3 -c one-liner of 16385 bytes, refused: the trade" "$PY_OVER"

  # THE SECOND TRADE: short lines in a quoted heredoc, each ending in a
  # backslash, are joined by the cap though bash does not join them.
  check_in "$dir" "$hook" BLOCK "$hook, a quoted heredoc of 80-byte lines ending in backslashes, refused: the second trade" \
    "$HEREDOC_SLASHED"
  says "$dir" "$hook" 'longer than 16 KB' "$hook, and that refusal is the cap's" "$HEREDOC_SLASHED"

  # 200 KB spread across 80-column lines is judged on its content, not capped.
  check_in "$dir" "$hook" ALLOW "$hook, 200 KB of heredoc in 80-column lines" "$HEREDOC_200K"
  check_in "$dir" "$hook" BLOCK "$hook, 200 KB of heredoc in 80-column lines, then $refused" "$HEREDOC_200K
$refused"
  says_not "$dir" "$hook" 'longer than 16 KB' "$hook, and that refusal is the content's" "$HEREDOC_200K
$refused"

  # The bound. Against the unfixed hooks this is green -- see the header.
  req GH-96.2
  under_a_second "$hook, a command whose longest line is exactly 16384 bytes" \
    "$(cap_timed "$dir" "$hook" "$(cap_line 16384 "; $refused")")"
done

# no-work-on-stale-branch.sh on a branch carrying work, where it has no other
# opinion: the cap holds there too since #95 moved the read to the top.
req GH-96.1
check_in "$WT_WORK" no-work-on-stale-branch.sh ALLOW \
  'no-work-on-stale-branch.sh, control: a commit on a branch carrying work' 'git commit -m wip'
check_in "$WT_WORK" no-work-on-stale-branch.sh BLOCK \
  'no-work-on-stale-branch.sh, one line of 16385 bytes, on a branch carrying work' "$OVER_CAP"

# The linear passes, through the library and past the cap: 512 KB, thirty-two
# times it, where the quadratic passes take seconds apiece and linear ones take
# a fraction of the bound. Loaded fresh in a subshell, so nothing an earlier
# section did to this shell's copy of the functions is what is timed.
LIB_LONG="$FIXTURES/line-512k.txt"
{ cap_line 524288 '; git push --force origin main'; printf '\n'; } > "$LIB_LONG"
cap_guard '512 KB library line' 524289 "$(wc -c < "$LIB_LONG" | tr -d ' ')"
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
req GH-96.2
library_under_a_second 'cs_normalise over one 512 KB line' cs_normalise "$FIXTURES/normalised.txt"
tok 'cs_normalise hands that line back whole, rather than capping it' \
    'whole' "$(cmp -s "$LIB_LONG" "$FIXTURES/normalised.txt" && echo whole || echo changed)"
library_under_a_second 'cs_split over one 512 KB line' cs_split "$FIXTURES/split.txt"
tok 'cs_split still finds the push behind that line' \
    'git push --force origin main' "$(sed -n 2p "$FIXTURES/split.txt")"
tok 'in two fragments, and not one or none' \
    '2' "$(wc -l < "$FIXTURES/split.txt" | tr -d ' ')"

# The shapes the plain line above does not have. cs_join, cs_split's prefix
# strip and both argument readers were quadratic in how MANY continuations,
# prefix words, options, assignments or blanks a line held, not in how long it
# was, so a long line of a's passes through them in one step and says nothing
# about them. Each shape is timed at 128 KB and at 512 KB, and the check is on
# the ratio rather than on a bound: four times the input costs a linear pass
# about four times as much and a quadratic one about sixteen, so 8 is the line
# between them, and a ratio does not move with the speed of the machine the way
# a bound does. Measured, against libraries with just that one pass put back as
# it was: every shape here went past 8 on its old pass -- 10.5 for the prefix
# words, the lowest -- where the new ones stay near 4 or under, under where
# process start-up is most of what is timed. One shape was written and
# dropped: a line of redirects does not separate the old cs_normalise from the
# new, because the old pass dropped each target and its output never grew.
# The 512 KB line above is what holds that pass.
#
# Each check also asks what came back, at both sizes: the exit status, and the
# last line of the output with runs of blanks squeezed and cut to its last 24
# characters -- enough to say the prefixes were stripped, the continuations
# joined, the options skipped. Each shape is built of whole words, counted,
# rather than cut to a byte count: cut, the prefix shape ended in `sugit push`,
# and the check was timing a strip that had nothing left to strip. Found by
# review.
#
# Each size's fastest of three is taken; a pass that runs past 20 s at either
# size is cut off and fails. A ratio over a small denominator is noise, so the
# smaller time is floored at 10 ms before dividing.
shape_prefixes() { yes sudo | head -n $(( $1 / 5 )) | tr '\n' ' '; printf 'git push --all origin\n'; }
shape_options() { printf 'sudo '; yes -- -a | head -n $(( $1 / 3 )) | tr '\n' ' '; printf 'git push\n'; }
shape_assigns() { yes A=1 | head -n $(( $1 / 4 )) | tr '\n' ' '; printf 'git push\n'; }
shape_trailing() { printf 'git push'; head -c "$1" /dev/zero | tr '\0' ' '; printf 'origin\n'; }
shape_continued() { yes 'aaaaaaa \' | head -n $(( $1 / 10 )); printf 'git push\n'; }
shape_gitglobals() { printf 'git '; yes -- '-c a=b' | head -n $(( $1 / 7 )) | tr '\n' ' '; printf 'push origin x\n'; }
shape_ghglobals() { printf 'gh '; yes -- '-R o/r' | head -n $(( $1 / 7 )) | tr '\n' ' '; printf 'pr merge 5\n'; }
# Issue #117's pass, in the one shape that separates a string from an array of
# cells: a command word that is a SINGLE path component, so nothing resets the
# count and the whole of it is both walked and printed. Quoted rather than left
# bare, because the bare spelling carries no slash either and would be handed
# straight back by the test that keeps this pass off ordinary commands -- the
# check would then time a reduction that never ran, which is the mistake the
# `shape_prefixes` note above records in its own form.
shape_cmdword() { printf '"'; head -c "$1" /dev/zero | tr '\0' 'a'; printf '" push origin x\n'; }
shape_tail() {  # shape_tail <file> -- the last line, blanks squeezed, last 24 characters
  awk 'END { s = $0; gsub(/[ \t]+/, " ", s); n = length(s); print substr(s, n > 24 ? n - 23 : 1) }' "$1"
}
scales_linearly() {  # scales_linearly <shape> <call> <expected tail>
  local small large tsmall tlarge
  "shape_$1" 128000 > "$FIXTURES/shape-small.txt"
  "shape_$1" 512000 > "$FIXTURES/shape-large.txt"
  small=$(lib_run "$FIXTURES/shape-small.txt" "$FIXTURES/shape-small.out" "$2")
  large=$(lib_run "$FIXTURES/shape-large.txt" "$FIXTURES/shape-large.out" "$2")
  tsmall=$(shape_tail "$FIXTURES/shape-small.out")
  tlarge=$(shape_tail "$FIXTURES/shape-large.out")
  if [ "${small#* }" != 0 ] || [ "${large#* }" != 0 ]; then
    fail static '%s over the %s shape did not run: exit %s at 128 KB, %s at 512 KB' \
      "$2" "$1" "${small#* }" "${large#* }"
    return
  fi
  if [ "$tsmall" != "$3" ] || [ "$tlarge" != "$3" ]; then
    fail static '%s over the %s shape returned the wrong thing\n         want |%s|\n         got  |%s| at 128 KB, |%s| at 512 KB' \
      "$2" "$1" "$3" "$tsmall" "$tlarge"
    return
  fi
  small=${small% *} large=${large% *}
  [ "$small" -ge 10 ] || small=10
  if [ $(( large * 10 / small )) -lt 80 ]; then
    pass static 'scaled %s over %s shape: %s ms at 128 KB, %s ms at 512 KB' "$2" "$1" "$small" "$large"
  else
    fail static '%s over the %s shape is not linear\n         %s ms at 128 KB, %s ms at 512 KB; four times the input may cost at most eight times' \
      "$2" "$1" "$small" "$large"
  fi
}
scales_linearly prefixes cs_split 'origin'
scales_linearly options cs_split 'push'
scales_linearly assigns cs_split 'git push'
scales_linearly trailing cs_split 'git push origin'
scales_linearly continued cs_join 'aaaaaaa aaaaaaa git push'
scales_linearly gitglobals 'cs_git_args push' 'origin x'
scales_linearly ghglobals "cs_gh_args 'pr merge'" '5'
req GH-117
scales_linearly cmdword cs_split 'aaaaaaaaaa push origin x'

# The option skip in both argument readers looks a token up in its list of
# valued options with index(), which finds `-c|-C` in `|-c|-C|...|` as readily
# as `-c`. The expression it replaced matched one name, so such a token was
# skipped alone there, and here it took the word after it -- the subcommand --
# as its value, and the reader answered "not a push". Not a hole: through
# cs_split a token holding `|` stands only inside quotes, and the same quotes
# cover the verb, so bash runs no push there either. But the rewrite is claimed
# identical, and this is where it was not. Found by review of PR #123, by
# reading the diff; the differential fuzz did not reach it. Every expected value
# is what the reader at dev-05 870bb3f printed for the same line, and each one
# was empty before the fix.
req GH-96.3
PIPED_GIT_C=$(printf 'git -c|-C push origin main\n' \
  | bash -c ". '$HOOKS/lib/command-scan.sh' && cs_git_args push" 2>/dev/null)
PIPED_GIT_LONG=$(printf 'git --work-tree|--namespace push origin main\n' \
  | bash -c ". '$HOOKS/lib/command-scan.sh' && cs_git_args push" 2>/dev/null)
PIPED_GH_R=$(printf 'gh -R|--repo pr merge 5\n' \
  | bash -c ". '$HOOKS/lib/command-scan.sh' && cs_gh_args 'pr merge'" 2>/dev/null)
PIPED_GH_LONG=$(printf 'gh --repo|--hostname pr merge 5\n' \
  | bash -c ". '$HOOKS/lib/command-scan.sh' && cs_gh_args 'pr merge'" 2>/dev/null)
tok 'cs_git_args reads -c|-C as one option taking no value, as before #96' \
    'origin main' "$PIPED_GIT_C"
tok 'and --work-tree|--namespace' 'origin main' "$PIPED_GIT_LONG"
tok 'cs_gh_args reads -R|--repo as one option taking no value, as before #96' \
    '5' "$PIPED_GH_R"
tok 'and --repo|--hostname' '5' "$PIPED_GH_LONG"

# The linear passes carry copies of two awk helpers -- tokend and skipblank in
# three programs, skipopts in two -- because an awk program cannot source
# another. A rule written twice is answered twice, which is the sentence
# lib/command-scan.sh opens with, so the copies are held to each other here:
# every definition of each is extracted off the file and all must be identical.
# Derived rather than counted, so a fourth copy is compared with the rest.
awk_copies() {  # awk_copies <function> -- each definition, one per line, newlines as |
  awk -v fn="$1" '
    $0 ~ "^[[:space:]]*function " fn "\\(" { body = ""; grab = 1; indent = match($0, /[^[:space:]]/) }
    grab { body = body substr($0, indent) "|"; if ($0 ~ /}[[:space:]]*$/ && (match($0, /[^[:space:]]/) == indent)) { print body; grab = 0 } }
  ' "$HOOKS/lib/command-scan.sh"
}
for fn in tokend skipblank skipopts; do
  total=$(awk_copies "$fn" | wc -l | tr -d ' ')
  distinct=$(awk_copies "$fn" | sort -u | wc -l | tr -d ' ')
  if [ "$total" -lt 2 ]; then
    fail static '%s: fewer than two definitions were read out of the library (%s), so there is nothing to compare' "$fn" "$total"
  elif [ "$distinct" = 1 ]; then
    pass static 'derived every copy of the awk helper %s is identical (%s copies)' "$fn" "$total"
  else
    fail static 'the %s copies of the awk helper %s have drifted apart into %s versions' "$total" "$fn" "$distinct"
  fi
done

# Where the argument is written. Prose, so `written`: the header that states the
# cap is where someone raising it will look for what it gives up.
req GH-96.1
written 'the library states the line cap' "$HOOKS/lib/command-scan.sh" 'THE LINE CAP'

# cs_within_cap, as a function rather than through a hook. Fail-closed is the
# claim that matters most here and no hook check can make it: every consumer
# requires cs_within_cap, but none requires cs_join, which cs_within_cap calls.
# A version reading only awk's status counts the lines of no input when cs_join
# is gone and succeeds -- the whole cap switched off by a rename one function
# away, and every check above still green, because each consumer's own load
# guard is satisfied.
within_cap() {  # within_cap <library> <input file> -- within, or over
  bash -c ". '$1' && cs_within_cap < '$2'" >/dev/null 2>&1 && echo within || echo over
}
req GH-96.3
printf '%s\n' "$AT_CAP" > "$FIXTURES/cap-at.txt"
printf '%s\n' "$OVER_CAP" > "$FIXTURES/cap-over.txt"
printf 'ls\n' > "$FIXTURES/cap-short.txt"
tok 'cs_within_cap succeeds on a line of exactly 16384 bytes' \
    'within' "$(within_cap "$HOOKS/lib/command-scan.sh" "$FIXTURES/cap-at.txt")"
tok 'and fails on one of 16385' \
    'over' "$(within_cap "$HOOKS/lib/command-scan.sh" "$FIXTURES/cap-over.txt")"
sed 's/^cs_join()/cs_renamed_away()/' "$HOOKS/lib/command-scan.sh" > "$FIXTURES/cap-no-join.sh"
grep -q '^cs_renamed_away()' "$FIXTURES/cap-no-join.sh" || {
  echo "the cs_join-less library was not built; the check using it proves nothing" >&2
  exit 1
}
tok 'and fails on a short command when the library is missing cs_join, which it calls' \
    'over' "$(within_cap "$FIXTURES/cap-no-join.sh" "$FIXTURES/cap-short.txt")"
sed 's/^CS_LINE_CAP=.*/CS_LINE_CAP=/' "$HOOKS/lib/command-scan.sh" > "$FIXTURES/cap-empty.sh"
grep -q '^CS_LINE_CAP=$' "$FIXTURES/cap-empty.sh" || {
  echo "the empty-cap library was not built; the check using it proves nothing" >&2
  exit 1
}
tok 'and on a short command when the cap itself is empty' \
    'over' "$(within_cap "$FIXTURES/cap-empty.sh" "$FIXTURES/cap-short.txt")"
armed 'the cap is 16384 bytes, written as the literal the issue decided' \
      "$HOOKS/lib/command-scan.sh" 'CS_LINE_CAP=16384'

section "=== the exit-status helpers themselves: #98 ==="
# The rule, and what it replaced, is written above `verdict`. Nothing else in this
# suite drives a helper with a hook that crashes, so these ask the helpers
# directly, in the manner of the `unarmed` self-test above: the helper runs in a
# subshell with its own FAILED, and what is asserted is the FAILED it leaves --
# the helper's result, not the fixture's exit status. The crash-1 fixture gets its
# 1 from `set -e`, which no hook uses; it stands for any exit that is neither 0
# nor 2, and 1 is the one the old reading and the new disagree about.
#
# Each fixture leaves a marker before it exits, and the marker is asserted too.
# A fixture the helper could not find would exit 127 on its own account, and a
# crash-1 case would then FAIL for that reason rather than the one it names.
#
# The passing cases per helper are about this harness rather than the rule:
# without them a harness that reported FAIL for everything would pass every
# crash case below. And the crash cases that expect BLOCK are not evidence
# against a revert -- the one-bit reading failed those too -- but against the
# other wrong reading, every nonzero exit as BLOCK, which they were measured to
# catch.
EXITS="$FIXTURES/exits"
mkdir -p "$EXITS"
printf '#!/bin/bash\n: > "$(dirname "$0")/ran-allow-0"\nexit 0\n' > "$EXITS/allow-0.sh"
printf '#!/bin/bash\n: > "$(dirname "$0")/ran-block-2"\necho "block-2 refuses" >&2\nexit 2\n' > "$EXITS/block-2.sh"
printf '#!/bin/bash\n: > "$(dirname "$0")/ran-crash-1"\necho "crash-1 fixture stderr" >&2\nset -e\nfalse\nexit 0\n' > "$EXITS/crash-1.sh"
printf '#!/bin/bash\n: > "$(dirname "$0")/ran-crash-127"\necho "crash-127 fixture stderr" >&2\nno-such-tool-for-check-hooks\n' > "$EXITS/crash-127.sh"
# A fifth fixture, for report_says alone: it exits 0 AND says something. Every
# helper above it reads a verdict, for which exit 0 is the whole answer, so a
# silent allow-0 is their passing case. report_says asks for a status and a
# sentence together -- #108's silent exit 0 is the defect it exists to catch --
# and allow-0 is indistinguishable from that defect, so it is this helper's
# FAILING case and this one is its passing one.
printf '#!/bin/bash\n: > "$(dirname "$0")/ran-speak-0"\necho "speak-0 reports something"\nexit 0\n' > "$EXITS/speak-0.sh"
chmod +x "$EXITS"/*.sh
for f in allow-0 block-2 crash-1 crash-127 speak-0; do
  [ -x "$EXITS/$f.sh" ] || {
    echo "the exit-status fixture $f.sh was not created; the self-test using it proves nothing" >&2
    exit 1
  }
done

# Where drive_helper leaves what the helper printed, for failure_line_says to read.
# Only its stdout: stderr goes to a file nothing reads, so a helper that let the
# hook's stderr through instead of printing it cannot pass for having printed it.
# Found by review of #98, which had both in one file.
EXITS_OUTPUT="$EXITS/output"

# Run one helper against one fixture in a subshell, and print ok or FAIL for the
# FAILED it left. Every helper takes its hook the same way since #107 -- through
# `hook_path`, so an absolute path is the fixture's and a bare name is one of
# $HOOKS's -- and each is given the absolute path of its fixture here.
# `feed` and `feed_says` take a PATH and a raw payload
# rather than a command; the PATH is the suite's own, because the fixtures call
# `dirname` to leave their marker. `says`, `says_not` and `feed_says` take a
# fragment where the others take a verdict: the fixture's own name, which is in
# everything a fixture says, so `says` and `feed_says` have something to find --
# a crashed fixture included, which is what makes their crash cases evidence --
# and `says_not` is given something it never sees. `cap_timed` and `lib_run` are
# driven through the helper that reads what they return, under_a_second and
# library_under_a_second, since neither reads a verdict of its own.
drive_helper() {  # drive_helper <helper> <fixture> <want>
  local helper="$1" fixture="$2" want="$3" result
  rm -f "$EXITS/ran-$fixture"
  if ( FAILED=0
       cd "$EXITS" || exit 3
       case "$helper" in
         check)      check "$EXITS/$fixture.sh" "$want" 'self-test' 'true' ;;
         check_in)   check_in "$EXITS" "$EXITS/$fixture.sh" "$want" 'self-test' 'true' ;;
         check_rawfile_in) check_rawfile_in "$EXITS" "$EXITS/$fixture.sh" "$want" 'self-test' 'true' ;;
         cap_timed)  under_a_second 'self-test' "$(cap_timed "$EXITS" "$EXITS/$fixture.sh" 'true')" ;;
         lib_run)    library_under_a_second 'self-test' "$EXITS/$fixture.sh" "$EXITS/lib-run-out" ;;
         flip)       flip "$EXITS" "$EXITS/$fixture.sh" ALLOW "$want" 'self-test' 'true' ;;
         gap)        gap "$EXITS" "$EXITS/$fixture.sh" BLOCK "$want" 'self-test' 'true' ;;
         check_file) check_file "$EXITS/$fixture.sh" "$want" 'self-test' 'docs/x.md' ;;
         says)       says "$EXITS" "$EXITS/$fixture.sh" "$fixture" 'self-test' 'true' ;;
         says_first) says_first "$EXITS" "$EXITS/$fixture.sh" "$fixture" 'self-test' 'true' ;;
         says_not)   says_not "$EXITS" "$EXITS/$fixture.sh" 'never-said' 'self-test' 'true' ;;
         feed)       feed "$PATH" "$EXITS/$fixture.sh" "$want" 'self-test' '{}' ;;
         feed_says)  feed_says "$PATH" "$EXITS/$fixture.sh" "$fixture" 'self-test' '{}' ;;
         env_feed)   env_feed "$EXITS" "$PATH" "$EXITS/$fixture.sh" "$want" 'self-test' '{}' ;;
         env_says)   env_says "$EXITS" "$PATH" "$EXITS/$fixture.sh" "$fixture" 'self-test' 'true' ;;
         report_says) report_says "$PATH" "$EXITS/$fixture.sh" "$fixture" 'self-test' ;;
         every_hook) XH_HOOKS="$EXITS/$fixture.sh" every_hook "$EXITS" 'self-test' 'true' ;;
         *)          exit 3 ;;
       esac
       exit $FAILED ) >"$EXITS_OUTPUT" 2>"$EXITS/stray-stderr"
  then result=ok; else result=FAIL; fi
  [ -e "$EXITS/ran-$fixture" ] || result="$result, and the fixture never ran"
  printf '%s\n' "$result"
}

# The failure line names what happened: the exit status, and what the hook said.
# `exit=<status>` and `stderr |<what it said>` are the spellings pinned here.
failure_line_says() {  # failure_line_says <label> <status> <stderr literal>
  if grep -qE "exit=$2([^0-9]|\$)" "$EXITS_OUTPUT" \
     && grep -qF -- "stderr |$3" "$EXITS_OUTPUT"; then
    pass static '%s' "$1"
  else
    fail static '%s\n         wanted exit=%s and |stderr |%s| on the failure line\n         it said |%s|' \
      "$1" "$2" "$3" "$(cat "$EXITS_OUTPUT")"
  fi
}

# The helpers this self-test drives, named once: each loop below runs off its list,
# and the derivation at the end of this section is asserted against both. A
# helper added to neither is red there; one added to a list is driven.
DRIVEN_VERDICT='check check_in flip gap check_file feed check_rawfile_in env_feed'
DRIVEN_MESSAGE='says says_first says_not feed_says env_says'
DRIVEN_TIMED='cap_timed lib_run'
# report_says is the fourth list because it is the only helper that asks for a
# status and a sentence at once, so neither loop above states its cases. #108.
DRIVEN_REPORT='report_says'
# every_hook is the fifth, #109's: it expects ALLOW of every hook it runs and
# takes no verdict, so the first loop cannot drive it, and it runs more than one
# hook, which is the case none of the others has.
DRIVEN_ALL='every_hook'

req GH-98 GH-124
for helper in $DRIVEN_VERDICT; do
  tok "$helper: a hook that exits 0 passes an ALLOW expectation" \
      'ok' "$(drive_helper "$helper" allow-0 ALLOW)"
  tok "$helper: a hook that exits 2 passes a BLOCK expectation" \
      'ok' "$(drive_helper "$helper" block-2 BLOCK)"
  tok "$helper: a hook that exits 1 fails an ALLOW expectation" \
      'FAIL' "$(drive_helper "$helper" crash-1 ALLOW)"
  failure_line_says "$helper: that failure line names exit 1 and the hook's stderr" \
      1 'crash-1 fixture stderr'
  tok "$helper: a hook that exits 1 fails a BLOCK expectation" \
      'FAIL' "$(drive_helper "$helper" crash-1 BLOCK)"
  tok "$helper: a hook that exits 127 fails an ALLOW expectation" \
      'FAIL' "$(drive_helper "$helper" crash-127 ALLOW)"
  failure_line_says "$helper: that failure line names exit 127 and the hook's stderr" \
      127 'crash-127 fixture stderr'
  tok "$helper: a hook that exits 127 fails a BLOCK expectation" \
      'FAIL' "$(drive_helper "$helper" crash-127 BLOCK)"
done

# The message helpers. A refusal is the only thing any of them can pass on, so
# the passing case is exit 2 alone.
for helper in $DRIVEN_MESSAGE; do
  tok "$helper: a hook that exits 2 passes" \
      'ok' "$(drive_helper "$helper" block-2 -)"
  tok "$helper: a hook that exits 1 fails, whatever its stderr says" \
      'FAIL' "$(drive_helper "$helper" crash-1 -)"
  failure_line_says "$helper: that failure line names exit 1 and the hook's stderr" \
      1 'crash-1 fixture stderr'
  tok "$helper: a hook that exits 127 fails, whatever its stderr says" \
      'FAIL' "$(drive_helper "$helper" crash-127 -)"
  failure_line_says "$helper: that failure line names exit 127 and the hook's stderr" \
      127 'crash-127 fixture stderr'
done

# The timed helpers, from #96. Each times one outcome and hands any other back as
# the status it saw: cap_timed times only a refusal, lib_run only a function that
# succeeded. So each has one passing exit, and every other exit -- 0 or 2 among
# them -- must fail with its status on the failure line, since a time with no
# verdict beside it would pass for a hook or a function that is not there. Their
# failure lines carry no stderr, so only the status is asked for.
timed_line_says() {  # timed_line_says <label> <literal>
  if grep -qF -- "$2" "$EXITS_OUTPUT"; then
    pass static '%s' "$1"
  else
    fail static '%s\n         wanted |%s| on the failure line\n         it said |%s|' \
      "$1" "$2" "$(cat "$EXITS_OUTPUT")"
  fi
}
for helper in $DRIVEN_TIMED; do
  case "$helper" in
    cap_timed) passes=block-2 fails='allow-0:0 crash-1:1 crash-127:127' spelled='(exit %s)' ;;
    lib_run)   passes=allow-0 fails='block-2:2 crash-1:1 crash-127:127' spelled='exited %s,' ;;
    *) fail static '%s is in DRIVEN_TIMED with no case here, so nothing drives it' "$helper"
       continue ;;
  esac
  tok "$helper: the $passes hook passes" 'ok' "$(drive_helper "$helper" "$passes" -)"
  for f in $fails; do
    tok "$helper: a hook that exits ${f#*:} fails" 'FAIL' "$(drive_helper "$helper" "${f%:*}" -)"
    timed_line_says "$helper: that failure line names exit ${f#*:}" "$(printf "$spelled" "${f#*:}")"
  done
done

# The report helper, #108. Its passing case needs both halves at once, so the
# fixtures separate them: speak-0 exits 0 and speaks, allow-0 exits 0 and is
# silent, and the three non-zero fixtures all speak. A helper that dropped the
# status test passes the allow-0 case; one that dropped the text test passes the
# silent one. Both were written and both were measured to fail exactly here.
for helper in $DRIVEN_REPORT; do
  tok "$helper: a report that exits 0 and says the literal passes" \
      'ok' "$(drive_helper "$helper" speak-0 -)"
  tok "$helper: a report that exits 0 saying nothing fails, which is the defect it is for" \
      'FAIL' "$(drive_helper "$helper" allow-0 -)"
  tok "$helper: a report that says the literal and then exits 2 fails" \
      'FAIL' "$(drive_helper "$helper" block-2 -)"
  timed_line_says "$helper: that failure line names the status it wanted and the one it got" \
      'must exit=0, got exit=2'
  tok "$helper: a report that exits 1 fails" 'FAIL' "$(drive_helper "$helper" crash-1 -)"
  timed_line_says "$helper: that failure line names exit 1" 'got exit=1'
  tok "$helper: a report that exits 127 fails" 'FAIL' "$(drive_helper "$helper" crash-127 -)"
  timed_line_says "$helper: that failure line names exit 127" 'got exit=127'
done

# The all-hooks helper, #109. Exit 0 is its only passing status, a refusal is a
# failure like any crash, and the failure line names the status and the stderr.
req GH-98 GH-109.5
for helper in $DRIVEN_ALL; do
  tok "$helper: a hook that exits 0 passes" 'ok' "$(drive_helper "$helper" allow-0 -)"
  tok "$helper: a hook that exits 2 fails" 'FAIL' "$(drive_helper "$helper" block-2 -)"
  failure_line_says "$helper: that failure line names exit 2 and the hook's stderr" \
      2 'block-2 refuses'
  tok "$helper: a hook that exits 1 fails" 'FAIL' "$(drive_helper "$helper" crash-1 -)"
  failure_line_says "$helper: that failure line names exit 1 and the hook's stderr" \
      1 'crash-1 fixture stderr'
  tok "$helper: a hook that exits 127 fails" 'FAIL' "$(drive_helper "$helper" crash-127 -)"
  failure_line_says "$helper: that failure line names exit 127 and the hook's stderr" \
      127 'crash-127 fixture stderr'
done
# And the property it exists for: ONE refusing hook of several fails it, in
# either position. A helper that kept only the last status, or only the first,
# passes one of these two and not the other.
every_hook_of() {  # every_hook_of <fixture>... -- ok or FAIL, for every_hook over those
  local list= f
  for f in "$@"; do list="$list $EXITS/$f.sh"; done
  if ( FAILED=0
       XH_HOOKS="$list" every_hook "$EXITS" 'self-test' 'true'
       exit $FAILED ) >/dev/null 2>&1
  then echo ok; else echo FAIL; fi
}
tok 'every_hook: a refusing hook after a permitting one fails' 'FAIL' "$(every_hook_of allow-0 block-2)"
tok 'every_hook: a refusing hook before a permitting one fails' 'FAIL' "$(every_hook_of block-2 allow-0)"
tok 'every_hook: two permitting hooks pass' 'ok' "$(every_hook_of allow-0 allow-0)"

# And that the helpers driven above are all of them. The helpers that read a hook's
# exit status are derived from this file, and each must be in one of the three lists
# the loops above run off -- so a new reader is either driven or red here. `flip`
# and `gap` read no status of their own -- each hands its verdict to check_in -- so
# neither is in the derived set: `flip` is driven because #98 names it, and `gap`
# because a helper this suite writes a verdict through is one this self-test should
# have found had it crashed, whether or not the derivation can reach it.
#
# The first version compared the derivation with a third literal, which nothing
# tied to the loops: a one-bit reader added to that literal alone left the suite
# green and the reader undriven. Found by review of PR #116, not by this suite.
#
# What the derivation does not find, named because a check is evidence about what
# it names: a reader spelled other than `rc=$?`, such as `if "$hook"; then`; and a
# function defined indented, whose body therefore has no `}` at the start of a
# line to end it. Both are the permitting direction. It does find names with
# capitals or digits, and the `function` keyword with or without parens. Comments
# are stripped first, as cs_calls strips them.
STATUS_READERS=$(sed 's/[[:space:]]*#.*$//' "$SUITE_DIR/check-hooks.sh" \
  | awk '/^function[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/ || /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)/ {
           fn = $0; sub(/^function[[:space:]]+/, "", fn); sub(/[[:space:](){].*/, "", fn)
         }
         /^\}/                 { fn = "" }
         fn != "" && /rc=\$\?/ { print fn }' \
  | sort -u | tr '\n' ' ')
# An empty derivation would make every membership below pass by asking nothing.
if [ -z "$STATUS_READERS" ]; then
  fail static 'no helper that reads a hook exit status was derived from this file at all'
fi
for reader in $STATUS_READERS; do
  present "derived $reader reads a hook exit status, and the #98 self-test drives it" \
          "$reader" "$DRIVEN_VERDICT $DRIVEN_MESSAGE $DRIVEN_TIMED $DRIVEN_REPORT $DRIVEN_ALL"
done

echo "--- issue #101: a load guard requires a function ---"
# CONTEXT.md keeps "check" for an assertion written out in advance and "probe"
# for a measurement whose answer is not known until it runs, and #38 renamed this
# suite for that reason. #84 then wrote "probe" for a `command -v` test in the
# library and every guard, which is neither, and #101 renamed it "requires". The
# drift arrived with the contract's own prose, so the prose is what is held:
# the library and each consumer, read as written with comments included, since
# nearly every use was in a comment. Case-folded, and "probing" as well as
# "probe", because the drift reached CLAUDE.md in that spelling.
#
# One use in these files is correct and stays: no-work-on-stale-branch.sh's
# header names the probe->check rename itself. It is exempt as that whole line
# in that one file, rather than by line number, which goes stale the moment a
# line is added above; a copy of it elsewhere, or a word appended to it, is not
# exempt. Text that stops matching exempts nothing, and the scan then fails on
# that file: the refusing direction, visible and one edit away.
#
# Two files are not scanned, and that is a trade rather than an oversight. This
# suite's own header uses the word correctly, and the block holding the rule
# cannot avoid naming the word it rules on, so its check labels are held by
# review. Naming is all it may do: review of PR #119 found the heading and the
# ok label using the word for a load guard ("does not probe one"), which a scan
# of this file would have caught and this block's own text did not. The word is
# not retired -- CONTEXT.md still means a measurement by it -- only that use is.
# Review of the merge across #95 found a second: a #95 comment calling the
# cs_tool_input guard "the probe", reachable by no check because it is here.
# CLAUDE.md carries correct uses (the judge's probe harness, scripts/probe_*.py)
# beside the #84 paragraph, so the same scan there would need an exemption per
# correct use, and #101 names .claude/hooks/ as its scope.
#
# The file list is $LIB_CONSUMERS. It is written by hand, but the #84 section
# asserts it equal to the files that actually source the library, so a seventh
# consumer turns that check red until it is added -- and is then scanned here.
#
# awk rather than grep, for two reasons. The exemption has to be a whole line
# in one file, which a grep -v filter over "N:text" output cannot say. And a
# read error has to fail: grep exits 2 into a pipeline that reads as "no hits",
# which is the permitting direction, where awk's status is kept and asked.
req GH-101 US-22 US-23
VOCAB_EXEMPT_FILE=no-work-on-stale-branch.sh
VOCAB_EXEMPT='# the probe->check rename was committed onto hooks-push-and-pr-guards after'
for f in lib/command-scan.sh $LIB_CONSUMERS; do
  EXEMPT=
  [ "$f" = "$VOCAB_EXEMPT_FILE" ] && EXEMPT=$VOCAB_EXEMPT
  if [ ! -r "$HOOKS/$f" ] || [ -d "$HOOKS/$f" ]; then
    fail static '%s cannot be read, so the absence of "probe" in it is evidence of nothing' "$f"
    continue
  fi
  if ! HITS=$(awk -v ex="$EXEMPT" \
      'tolower($0) ~ /prob(e|ing)/ && !(ex != "" && $0 == ex) { print FNR ": " $0 }' \
      "$HOOKS/$f" 2>/dev/null); then
    fail static '%s could not be scanned, so the absence of "probe" in it is evidence of nothing' "$f"
  elif [ -z "$HITS" ]; then
    pass static 'written %s says a guard requires a function' "$f"
  else
    fail static '%s uses "probe", which CONTEXT.md keeps for a measurement:\n%s' \
      "$f" "$(printf '%s\n' "$HITS" | sed 's/^/         /')"
  fi
done

section "=== issue #106: every spelling of a judged command reaches its verdict ==="
# THE FAMILIES. Almost every defect this boundary has had in the permitting
# direction was a spelling variant of a command the suite already judged
# correctly: indentation inside an `if`, a flag before the subcommand, a
# redirect read as a refspec, a separator inside quotes, `sudo sh -c`, a
# `--base` scoped to the wrong command. Each was fixed with a check naming that
# one variant, so the next variant was caught only if someone happened to think
# of it, and nine rounds of review found nine of them with the suite green
# before each round.
#
# This section asks generatively what those checks each asked once. A seed is a
# command with a literal verdict; a transformation rewrites its text without
# changing which command runs; and the invariance is that every variant reaches
# the seed's verdict. Where a variant legitimately reaches a different one the
# pair is declared below with that verdict and the reason; where it reaches the
# WRONG one the pair is declared a gap naming the issue that owns it, never a
# design exception, since declaring one is what silencing a defect would look
# like (#103 Q18).
#
# WHAT IS LITERAL HERE, the rule this whole file rests on. The seed verdicts are
# written out. The invariance -- variant reaches seed -- is written out, as this
# paragraph. Every departure from it is written out with its reason. Nothing
# below asks a hook what it returns and then expects that.
#
# WHAT A GREEN RUN HERE IS NOT EVIDENCE OF. The transformations are a list
# someone wrote, so this is still evidence about the cases it names: wider than
# the one-variant checks above it by the number of transformations, and no wider
# than that. The next transformation is the one nobody has thought of, and four
# of the fourteen here arrived that way -- #117 and #118 came out of Bertan's
# review of PR #115, after the first ten had been settled, and #128 and #117's
# triage after those. What changes is the
# cost of the next one: a transformation added to the list below is asked of
# every seed at once, rather than of the one command whose review found it.
#
# MUTATION, which is the only thing that says these can fail. Three historical
# defects were re-introduced in lib/command-scan.sh, one at a time, each restored
# from a copy taken beside the run rather than from git -- `git checkout --` in a
# throwaway harness eats whatever else is uncommitted in the worktree. Each is
# one edit, written out so the run is reproducible from this file rather than
# from a harness that no longer exists (a standing one is #107's):
#
#   1. delete `sudo|` from CS_WRAP_OPTION_WORDS
#   2. delete `nohup|` from CS_WRAP_OPTION_WORDS
#   3. in cs_split's prefix pass, replace the control-word alternation
#      `^([{}!]|if|then|…|coproc)$` with one that matches nothing
#
# The counts are family rows against the rest of this suite:
#
#   drop `sudo` from the prefix words (#79's fix)        48 FAIL, 22 here
#   drop `nohup` from the same list                      26 FAIL, 22 here
#   stop stripping the shell control words in cs_split   72 FAIL, 57 here
#
# The middle one is the one worth reading. `nohup` was covered by four checks in
# the whole of the rest of this suite; the families ask it of every seed, and the
# same holds for every other word on that list -- which is the shape of #79
# itself, a fix that handled `sh -c`, then `sudo sh -c`, one word per round.
# The tree was green before each mutation and green after each restore.
#
# The guards this section carries about ITSELF are mutation-checked the same
# way, each by one edit, and each fires: a name dropped from INV_TRANSFORMS
# while its `inv_apply` arm stays; a transformation added that applies to no
# seed; a departure row naming a seed that does not exist; a gap row whose right
# verdict is dropped so it becomes the one it asserts; a right verdict added to
# a design row; and a seed re-spelled so a transformation only ever regenerates
# another seed's command.
#
# Two of those mutations did not apply on their first attempt -- the patch text
# did not match, and a third reverted one of the two seeds it needed to revert.
# Each run was green for that reason and not for the one it claimed. A mutation
# that silently fails to apply reads exactly like evidence and is none, so the
# harness now asserts its own edit landed before it trusts the run.

# WHERE A SEED RUNS. A symbolic name rather than a path, so the table below can
# be a quoted heredoc and hold every command exactly as written -- a `$` or a
# backtick in a seed would be text and not an expansion.
inv_dir() {  # inv_dir <name> -- the fixture directory a seed names
  case "$1" in
    # A working directory inside this repository, which is what `hooks` is here
    # for -- the hook run in it is still $HOOKS's. Under #107's override a copy
    # in /tmp is not a git repository, and the seeds run here read the branch
    # they are standing on.
    hooks)     printf '%s' "$SUITE_DIR" ;;
    push-wt)   printf '%s' "$PUSH_WT" ;;
    push-main) printf '%s' "$PUSH_MAIN" ;;
    on-main)   printf '%s' "$ON_MAIN" ;;
    on-dev)    printf '%s' "$ON_DEV" ;;
    wt-stale)  printf '%s' "$WT_STALE" ;;
    wt-work)   printf '%s' "$WT_WORK" ;;
    *)         return 1 ;;
  esac
}

# THE SEEDS, one per line: <fixture>|<hook>|<verdict>|<tags>|<key>|<command>.
# Both directions for every FUNCTIONAL requirement with a command spelling,
# because a permitting seed is as much of the family as a refusing one: two of
# the defect rounds these families generalise were refusals of ordinary
# commands, and a generator run only against refusals would have reported
# neither.
#
# FUNCTIONAL, and the word carries the whole of the difference between the two
# halves of this table. The `GH-` half #141 added allows one direction, and says
# so where its rule is written: the both-directions rule is #104's coverage
# rule, and a `GH-` entry's other direction is often met by a named check above
# rather than by a seed. GH-43.1, GH-68.1 and GH-72 are seeded ALLOW alone for
# that reason, and the derivation's literal is where which-direction is visible.
# This sentence said "every requirement" for one revision, with the FR-only
# derivation underneath it, and the `GH-` seeds then contradicted it.
#
# Two requirements name commands and are not seeded. FR-13 says the base rule
# lives in the pull-request hook and adds no seventh hook, which is a claim
# about where code sits and carries `seam: none`; a check tagged with it would
# fail the #104 section rather than cover it. FR-49's subject is not a spelling
# but what a hook does when it cannot read its input at all -- no jq, stdin that
# is not JSON, no command field -- and its permitting half is the empty command
# string, which has no variant; the #95 section above holds it. Every other
# FUNCTIONAL requirement whose text names a command is seeded here in both
# directions, and the derivation at the foot of this section holds the table to
# that.
#
# THE `GH-` FAMILY IS SEEDED BY A RULE, WHICH IS #141'S. The paragraph above is
# the FR half, and until #141 it was the whole of the table's scope: the
# derivation read `FR-` tags and nothing else, so GH-43.6, GH-68.1, GH-72 and
# the GH-79 family named commands and no transformation was ever asked of them,
# and GH-94.1 was seeded in one direction. That is the scope #106 asked for
# ("at least one per FR with a command spelling"), and it is where the
# specification happened to land in 2026-09 rather than where the defects have
# been: requirements.md holds 95 `GH-` entries to 49 FRs, and the `GH-` ones are
# the ones written FROM defects. (Measured 2026-09-17. #141's own text says
# "60-odd entries against 49 FRs", which was two different bases -- all FRs
# against some `GH-` entries -- and is not repeated here for that reason.)
#
# The rule is in requirements.md, under *What the invariance families seed*,
# because it is a rule about requirements and that file is where a requirement's
# fields are defined. In one sentence: every `GH-` entry that is behavioural,
# active and not `static` declares in a `variants` field whether the families
# seed it, transform it, or reach it not at all with a reason. The derivation at
# the foot of this section holds all three to the tables here, and the answer is
# not a dozen more rows -- several of those entries name a TRANSFORMATION and
# not a seed, GH-79.x being transformation 4, and asking one of those as a seed
# would be a category error.
#
# How many entries are in scope and how they divide between the three values is
# a line this section PRINTS, beside the derivation. It is deliberately not
# written here: the four numbers stood in this comment for one revision, in the
# same commit whose other file argues that a count in a comment is the thing
# #107 was filed about.
#
# TWO THINGS ABOUT THE NEW ROWS THAT READ LIKE MISTAKES AND ARE NOT.
#
# `commit-push-all` and `push-all` carry the SAME command text, `git push --all
# origin`, and that is the point of it: one is judged by no-git-push.sh in a
# linked worktree and the other by no-commit-to-main.sh on `main`, which have
# separate rules for a push that reaches main without naming it (FR-3 and
# GH-43.4). Two hooks reading one command is two claims, and the table keys a
# seed by its own name rather than by its text, so both are asked.
#
# GH-68.1's seed is not GH-68.1's own example. The issue's example is
# `sed -i 's/a\|b/c/'` and the field separator here is `|`, which no seed
# command may contain -- the loop below would read the row as cut in half. So
# the seed carries the same shape with a `;` inside the quotes, which is the
# separator the tokeniser's first pass cuts on anyway. The constraint is worth
# naming rather than working around: a requirement whose only command contains a
# `|` cannot be seeded in this table at all, and would be `variants: none` with
# that as its reason.
#
# `|` is the field separator and no seed command contains one; the loop below
# fails on a seed whose command field came out empty rather than leaving one
# silently cut in half.
INV_SEEDS=$(cat <<'SEEDS'
push-wt|no-git-push.sh|BLOCK|FR-3 US-2|push-all|git push --all origin
push-wt|no-git-push.sh|BLOCK|FR-3 US-1|push-main|git push origin main
push-wt|no-git-push.sh|BLOCK|FR-3 US-3|push-force|git push --force origin wt-branch
push-wt|no-git-push.sh|BLOCK|FR-4|push-wrapped|bash -c "git push origin wt-branch"
push-wt|no-git-push.sh|ALLOW|FR-3 US-3 US-4 GH-94.1|push-own|git push origin wt-branch
push-wt|no-git-push.sh|ALLOW|FR-3|push-status|git status
push-wt|no-git-push.sh|ALLOW|GH-68.1|push-prose-quoted|grep 'x ; git push --all origin' f
push-main|no-git-push.sh|BLOCK|GH-94.1 US-3|push-from-main-checkout|git push origin feature-x
hooks|no-pr-decisions.sh|BLOCK|US-15|pr-merge|gh pr merge 5
hooks|no-pr-decisions.sh|BLOCK|FR-4 GH-51.1|pr-merge-wrapped|bash -c "gh pr merge 5"
hooks|no-pr-decisions.sh|BLOCK|GH-51.2|pr-view-wrapped|bash -c "gh pr view 5"
hooks|no-pr-decisions.sh|BLOCK|FR-15 FR-16 US-8|pr-base-main|gh pr create --base main --title x
hooks|no-pr-decisions.sh|BLOCK|FR-15 FR-16 US-8|pr-base-main-eq|gh pr create --base=main --body y
hooks|no-pr-decisions.sh|BLOCK|FR-15 FR-16 US-8|pr-bundled|gh pr create -dB main --body y
hooks|no-pr-decisions.sh|BLOCK|FR-15 FR-16 US-8|pr-short-flags|gh pr create -d -B main --title x
hooks|no-pr-decisions.sh|BLOCK|FR-14 FR-16 US-9|pr-no-base|gh pr create --title x --body y
hooks|no-pr-decisions.sh|BLOCK|FR-17 FR-15 US-10|pr-retarget|gh pr edit 35 --base main
hooks|no-pr-decisions.sh|BLOCK|FR-21 FR-15|pr-web-main|gh pr create --web --base main
hooks|no-pr-decisions.sh|BLOCK|FR-18 FR-20 FR-15 US-11|api-rest-main|gh api -X POST repos/o/r/pulls -f base=main -f head=x
hooks|no-pr-decisions.sh|BLOCK|FR-19 FR-15 US-11|api-graphql-main|gh api graphql -f query='mutation{createPullRequest(input:{baseRefName:main})}'
hooks|no-pr-decisions.sh|BLOCK|FR-48 US-15 GH-97.1|release-create|gh release create v1
hooks|no-pr-decisions.sh|ALLOW|FR-14 FR-15 FR-16 US-8|pr-base-dev|gh pr create --base dev-05 --title x
hooks|no-pr-decisions.sh|ALLOW|FR-14 FR-15 FR-16 US-8|pr-base-dev-eq|gh pr create --base=dev-05 --body y
hooks|no-pr-decisions.sh|ALLOW|FR-17 FR-15 US-10|pr-retarget-dev|gh pr edit 35 --base dev-05
hooks|no-pr-decisions.sh|ALLOW|US-13|pr-view|gh pr view 5
hooks|no-pr-decisions.sh|ALLOW|FR-21 US-12|pr-web|gh pr create --web
hooks|no-pr-decisions.sh|ALLOW|FR-20 US-13|api-read|gh api repos/o/r/pulls/35
hooks|no-pr-decisions.sh|ALLOW|FR-18 FR-15 US-11|api-rest-dev|gh api -X POST repos/o/r/pulls -f base=dev-05 -f head=x
hooks|no-pr-decisions.sh|ALLOW|FR-19 FR-15 US-11|api-graphql-dev|gh api graphql -f query='mutation{createPullRequest(input:{baseRefName:"dev-05"})}'
hooks|no-pr-decisions.sh|BLOCK|GH-137.1|api-state-quoted|gh api -X PATCH repos/o/r/pulls/5 -f "state=closed"
hooks|no-pr-decisions.sh|BLOCK|GH-137.2|api-base-quoted-main|gh api -X POST repos/o/r/pulls -f "base=main" -f head=x
hooks|no-pr-decisions.sh|ALLOW|GH-137.2|api-base-quoted-dev|gh api -X POST repos/o/r/pulls -f "base=dev-05" -f head=x
hooks|no-pr-decisions.sh|ALLOW|FR-48 GH-97.1|release-view|gh release view v1
hooks|no-pr-decisions.sh|ALLOW|US-14|issue-list|gh issue list
hooks|no-pr-decisions.sh|ALLOW|FR-4|wrap-benign|bash -c "gh issue list"
hooks|no-pr-decisions.sh|ALLOW|GH-72|wrap-suffix-word|bash -c "echo high"
hooks|append-only-docs.sh|BLOCK|GH-69.2|docs-truncate|truncate -s 0 docs/dev-log/devlog_2026-08-01_session-1.md
hooks|append-only-docs.sh|ALLOW|GH-69.2|docs-truncate-revisable|truncate -s 0 docs/design/dependency-scanning-scope.md
on-main|no-commit-to-main.sh|BLOCK|US-1|commit-main|git commit -m wip
on-main|no-commit-to-main.sh|BLOCK|FR-4 GH-43.3|commit-wrapped|bash -c "git commit -m wip"
on-main|no-commit-to-main.sh|BLOCK|GH-43.4|commit-push-all|git push --all origin
on-main|no-commit-to-main.sh|ALLOW|GH-43.1|commit-prose|echo "git push origin main"
on-dev|no-commit-to-main.sh|ALLOW|US-4|commit-dev|git commit -m wip
wt-stale|no-work-on-stale-branch.sh|BLOCK|FR-38|commit-stale|git commit -m wip
wt-work|no-work-on-stale-branch.sh|ALLOW|FR-38|commit-work|git commit -m wip
hooks|pytest-via-uv-group.sh|BLOCK|GH-69.1|pytest-bare|pytest tests/
hooks|pytest-via-uv-group.sh|ALLOW|GH-69.1|pytest-uv|uv run --group test pytest tests/
hooks|alembic-via-uv-group.sh|BLOCK|GH-69.1|alembic-bare|alembic upgrade head
hooks|alembic-via-uv-group.sh|ALLOW|GH-69.1|alembic-uv|uv run --group migrations alembic upgrade head
SEEDS
)

# THE TRANSFORMATIONS, #103's ten, the two Bertan's review of PR #115 added, and
# two since, each family spelled out one variant per spelling it has:
#
#   1 leading indentation      indent-spaces indent-tab
#   2 separators               before-* after-*, one per separator and side
#   3 control words            word-if word-for word-brace word-subshell
#   4 prefix words cs_split strips   pre-sudo pre-env pre-command pre-nohup
#                                     pre-time pre-timeout pre-nice-opt
#   5 --flag=value / --flag value    flag-attached flag-separated
#   6 bundled / separate short flags short-bundled short-separate
#   7 a global flag before the subcommand   global-flag global-flag-gitdir
#   8 quoted / unquoted arguments    quote-double-* quote-single-*, by position
#   9 a line continuation between arguments  continuation
#  10 a trailing redirection          redirect-null redirect-dup
#                                     redirect-quoted
#  11 the command word itself (#117)  word-path word-dot word-dquoted
#                                     word-squoted word-escaped
#  12 an option before the subcommand that consumes the next word (#118)
#                                     option-eats-verb
#  13 a heredoc in front of it whose opener line is continued (#128)
#                                     heredoc-cont heredoc-cont-dash
#                                     heredoc-cont-squote heredoc-cont-dquote
#                                     heredoc-cont-space heredoc-cont-twice
#                                     heredoc-cont-redirect
#  14 a prefix word spelled otherwise (#117)  pre-sudo-path pre-env-path
#                                     pre-timeout-quoted
#
# The thirteenth is seven spellings where the others are one or two, and that is
# #128 rather than thoroughness for its own sake: the spellings of the heredoc
# opener are where this question has gone wrong four times, twice on a spelling
# the terminator comparison did not match. #128's own section writes the two
# hooks and the two directions it measured; these ask the same seven of every
# seed, which is the whole reason the families exist.
#
# Four of those spellings are #141's, added because a `GH-` entry named the
# shape and the list did not have it -- which is the whole of what a
# `variants: transformation:` value claims, and the derivation at the foot of
# this section is what holds each to the list. `pre-timeout` is a prefix word
# with an OPERAND of its own (CS_WRAP_OPERAND_WORDS, not the option words every
# other `pre-*` here comes from) and `pre-nice-opt` a prefix word with a
# SEPARATED OPTION VALUE, the two shapes GH-43.6 names that `pre-sudo` and
# `env X=1` between them do not reach; `global-flag-gitdir` is its third,
# `git --git-dir` beside the `-C` that `global-flag` already covers, and it
# departs by design on the two seeds it moves; `redirect-quoted` is the quoted redirect
# target GH-50.3 records as a knowingly-taken shortfall, and it is a shortfall
# of the push hook alone, which is a thing one row can now say of every seed
# rather than of the one command #50's review happened to write.
#
# The fourteenth is the one the triage of #117 asked for by name: a prefix word
# is matched against a list BY NAME, exactly as the command word is matched by
# its anchor, so every spelling reached it too. Transformation 4 prepends those
# words BARE and so could never have found it -- which is the point the list
# itself makes about why a family is worth having. The wrapper words the same
# triage names need no row of their own: a wrapped seed carries the wrapper AS
# its command word, so transformation 11 already rewrites it, and adding a
# fifteenth would be the same question asked twice.
#
# A transformation that cannot apply to a seed -- no value-taking long flag, no
# second short flag to bundle with, no subcommand to put a global flag before --
# emits nothing, and that skip is counted. A transformation that applies to NO
# seed at all is a check that has silently stopped existing, so it is failed by
# name at the foot of this section rather than counted into an aggregate.
#
# That guard is here because this comment claimed it before it was written, and
# the claim was found by review rather than by the suite. The aggregate count
# that stood here said how many variants were skipped and never which
# transformation did no work, and a transformation applying to nothing is
# exactly the case the aggregate cannot show: it is one more number in a total
# of 269.
INV_TRANSFORMS='
  indent-spaces indent-tab
  before-semi before-and before-or before-pipe before-newline
  after-semi after-and after-or after-pipe after-newline
  word-if word-for word-brace word-subshell
  pre-sudo pre-env pre-command pre-nohup pre-time pre-timeout pre-nice-opt
  flag-attached flag-separated short-bundled short-separate
  global-flag global-flag-gitdir option-eats-verb
  quote-double-2 quote-double-3 quote-double-4 quote-double-5 quote-double-last
  quote-single-2 quote-single-3 quote-single-4 quote-single-5 quote-single-last
  continuation
  redirect-null redirect-dup redirect-quoted
  word-path word-dot word-dquoted word-squoted word-escaped
  heredoc-cont heredoc-cont-dash heredoc-cont-squote heredoc-cont-dquote
  heredoc-cont-space heredoc-cont-twice heredoc-cont-redirect
  pre-sudo-path pre-env-path pre-timeout-quoted
'

# A rewrite that prints nothing when it changed nothing, which is how a
# transformation says it does not apply to this seed.
inv_rewrite() {  # inv_rewrite <command> <sed -E script>
  local out
  out=$(printf '%s' "$1" | sed -E "$2")
  [ "$out" != "$1" ] && printf '%s' "$out"
  return 0
}
# The value-taking long flags the seeds use, named rather than derived: a
# transformation that attached a value to a flag which takes none would write a
# command git or gh rejects, and a verdict on one of those says less than it
# looks like it says.
INV_VALUE_FLAGS='base|title|body|group'
# A global option before the subcommand, in the spelling each tool takes.
inv_global() {  # inv_global <command>
  case "$1" in
    'gh '*)  printf 'gh -R o/r %s' "${1#gh }" ;;
    'git '*) printf 'git -C . %s' "${1#git }" ;;
  esac
}
# The OTHER directory option, in its separated spelling. GH-43.6 names "git's
# directory options in their separated spelling" and `inv_global` writes one of
# them, `-C`, so a `variants: transformation: global-flag` on that entry claimed
# a shape no variant wrote. Measured on this branch, each fed to the hook on
# stdin: `git --git-dir .git push …` and `git --work-tree . push …` are refused
# exactly as `git -C . push …` is, and `git --git-dir .git status` is permitted
# exactly as `git -C . status` is -- so the departures this transformation needs
# are the departures `global-flag` already has, one option along. One of the two
# rather than both, for the class rows' reason: two rows asserting one thing of
# one shape is not a stronger claim than one. Found by review of this branch.
inv_global_gitdir() {  # inv_global_gitdir <command>
  case "$1" in
    'git '*) printf 'git --git-dir .git %s' "${1#git }" ;;
  esac
}
# #118: an option before the subcommand that takes a value consumes the next
# word, so a read verb written after it is eaten and the verb after THAT is what
# runs.
#
# `-t`, a SHORTHAND, and not #118's own `--squash`. That spelling was written
# here first, straight out of the issue, and it is a command gh rejects: cobra
# treats an unknown longhand as a boolean, so `gh pr --squash view 5` returns
# `unknown flag: --squash` and no verb is eaten. Measured on gh 2.45.0. An
# unknown or value-taking SHORTHAND does consume the next word, and `-t`
# (`--template`) is one at each of the three group levels: `gh pr -t view view 5`
# runs `gh pr view 5`, which then complains that `--template` needs `--json` --
# the complaint is the evidence, since it proves the second `view` became the
# subcommand.
#
# The distinction is not pedantry, and this file sets the bar for it one screen
# up, at INV_VALUE_FLAGS: a variant gh will not execute is a variant whose
# verdict says less than it looks like it says. A gap row pinning one would
# claim a permitted command that cannot be run.
#
# `gh release -t list create v1` is the shape at its worst, and it is permitted:
# a review of this branch ran it and it created a real release on this
# repository. That is not a hypothetical about what gh would do.
inv_eats() {  # inv_eats <command>
  case "$1" in
    'gh pr '*)      printf 'gh pr -t view %s' "${1#gh pr }" ;;
    'gh release '*) printf 'gh release -t list %s' "${1#gh release }" ;;
    'gh issue '*)   printf 'gh issue -t list %s' "${1#gh issue }" ;;
  esac
}
# One argument quoted, by position. Not the command word, which is #117's
# transformation and is asked separately.
#
# By POSITION and not just the last argument, which is what the first version of
# this did and is the reason this comment is here: quoting the last argument of
# `gh pr merge 5` quotes the number, and the number is not what any rule reads.
# The word a rule does read is the subcommand, two and three words in, and
# `gh pr "merge" 5` and `git "push" --all origin` are permitted. Found by hand
# after this transformation had been written and run, which is the shape this
# whole section is about: the family asked the right question of the wrong word.
#
# Five fixed positions and not four, for the same reason one position further
# out: position 5 is a flag's VALUE in the longest seeds -- `gh pr create --base
# dev-05 --title x` -- and a quoted base value is the contrast GH-135's entry
# rests on, `--base "dev-05"` being read correctly where `"--base" dev-05` is
# not. With four, the families generated the half of that contrast that fails
# and not the half that passes. Also found by review rather than here.
#
# A command carrying a quote already is skipped whole rather than at the target
# word. The rejoin below splits on whitespace, so a quoted span is several words
# to it, and quoting one of them would put a quote inside a payload -- a command
# nobody would write, whose verdict says nothing.
inv_quote_at() {  # inv_quote_at <command> <quote character> <index, or "last">
  local cmd="$1" q="$2" want="$3" n target i=0 w out=
  case "$cmd" in *\'*|*\"*) return 0 ;; esac
  # Split on whitespace with globbing off, and put globbing back: every other
  # `set -f` in this file is paired, and a caller that reached this one through
  # something other than a command substitution would otherwise leave it off for
  # the rest of the run. That every caller today is `$(inv_apply …)` is a reason
  # this has not bitten, not a reason to leave it unpaired.
  set -f
  set -- $cmd
  set +f
  n=$#
  case "$want" in
    # `last` is for the arguments the fixed positions do not reach, and is
    # skipped where it would be one of them: the same command checked twice
    # under two names reads in the matrix as two checks and is one.
    last) target=$n; [ "$n" -gt 5 ] || return 0 ;;
    *)    target=$want; [ "$n" -ge "$target" ] || return 0 ;;
  esac
  [ "$target" -gt 1 ] || return 0
  for w in "$@"; do
    i=$((i + 1))
    [ "$i" = "$target" ] && w="$q$w$q"
    out="${out:+$out }$w"
  done
  printf '%s' "$out"
}
# A line continuation between the last two arguments.
inv_continuation() {  # inv_continuation <command>
  local head="${1% *}" last="${1##* }"
  [ "$head" != "$1" ] || return 0
  printf '%s \\\n  %s' "$head" "$last"
}
# #117: the command word as a path, quoted or escaped. bash runs all five, and
# not one of the other eleven transformations changes the command word at all.
inv_cmdword() {  # inv_cmdword <command> <prefix> <suffix>
  local word="${1%% *}" rest="${1#* }"
  case "$word" in */*|*\'*|*\"*|'') return 0 ;; esac
  [ "$rest" != "$1" ] || rest=
  printf '%s%s%s%s' "$2" "$word" "$3" "${rest:+ $rest}"
}
# #128: a heredoc in front of the command, whose OPENER line ends in a
# backslash. Bash joins that line before the body begins, so the body of each of
# these is empty, the terminator is the line after the opener, and the seed on
# the line after THAT is the command that runs -- which is why the verdict must
# be the seed's. The drop read the joined-on word as the body instead and the
# join then glued the seed onto the opener line, at no command position.
#
# `x` is the word joined onto the opener, and it is a word bash hands to cat as a
# filename rather than anything a rule reads. The twice-continued spelling joins
# two of cat's own options instead, which is the shape an agent would actually
# write across a continuation.
# Each spelling is written out whole rather than assembled from an opener and a
# body: the tab of the `<<-` spelling and the backslash of every one of them are
# the characters under test, and a builder that dropped one would leave seven
# variants passing that are not the seven named.
inv_heredoc() {  # inv_heredoc <command> <heredoc, terminator included>
  printf '%s\n%s' "$2" "$1"
}
inv_apply() {  # inv_apply <transformation> <command> -- the variant, or nothing
  case "$1" in
    indent-spaces)    printf '    %s' "$2" ;;
    indent-tab)       printf '\t%s' "$2" ;;
    before-semi)      printf 'echo x ; %s' "$2" ;;
    before-and)       printf 'echo x && %s' "$2" ;;
    before-or)        printf 'echo x || %s' "$2" ;;
    before-pipe)      printf 'echo x | %s' "$2" ;;
    before-newline)   printf 'echo x\n%s' "$2" ;;
    after-semi)       printf '%s ; echo x' "$2" ;;
    after-and)        printf '%s && echo x' "$2" ;;
    after-or)         printf '%s || echo x' "$2" ;;
    after-pipe)       printf '%s | cat' "$2" ;;
    after-newline)    printf '%s\necho x' "$2" ;;
    word-if)          printf 'if true; then %s; fi' "$2" ;;
    word-for)         printf 'for x in 1; do %s; done' "$2" ;;
    word-brace)       printf '{ %s; }' "$2" ;;
    word-subshell)    printf '( %s )' "$2" ;;
    pre-sudo)         printf 'sudo %s' "$2" ;;
    pre-env)          printf 'env X=1 %s' "$2" ;;
    pre-command)      printf 'command %s' "$2" ;;
    pre-nohup)        printf 'nohup %s' "$2" ;;
    pre-time)         printf 'time %s' "$2" ;;
    pre-timeout)      printf 'timeout 30 %s' "$2" ;;
    pre-nice-opt)     printf 'nice -n 5 %s' "$2" ;;
    flag-attached)    inv_rewrite "$2" "s/(--($INV_VALUE_FLAGS)) ([^ -][^ ]*)/\\1=\\3/" ;;
    flag-separated)   inv_rewrite "$2" "s/(--($INV_VALUE_FLAGS))=([^ ]+)/\\1 \\3/" ;;
    short-bundled)    inv_rewrite "$2" 's/ -([A-Za-z]) -([A-Za-z]) / -\1\2 /' ;;
    short-separate)   inv_rewrite "$2" 's/ -([A-Za-z])([A-Za-z]) / -\1 -\2 /' ;;
    global-flag)      inv_global "$2" ;;
    global-flag-gitdir) inv_global_gitdir "$2" ;;
    option-eats-verb) inv_eats "$2" ;;
    quote-double-2)   inv_quote_at "$2" '"' 2 ;;
    quote-double-3)   inv_quote_at "$2" '"' 3 ;;
    quote-double-4)   inv_quote_at "$2" '"' 4 ;;
    quote-double-5)   inv_quote_at "$2" '"' 5 ;;
    quote-double-last) inv_quote_at "$2" '"' last ;;
    quote-single-2)   inv_quote_at "$2" "'" 2 ;;
    quote-single-3)   inv_quote_at "$2" "'" 3 ;;
    quote-single-4)   inv_quote_at "$2" "'" 4 ;;
    quote-single-5)   inv_quote_at "$2" "'" 5 ;;
    quote-single-last) inv_quote_at "$2" "'" last ;;
    continuation)     inv_continuation "$2" ;;
    redirect-null)    printf '%s >/dev/null' "$2" ;;
    redirect-dup)     printf '%s 2>&1' "$2" ;;
    redirect-quoted)  printf '%s > "out.txt"' "$2" ;;
    pre-sudo-path)    printf '/usr/bin/sudo %s' "$2" ;;
    pre-env-path)     printf '/usr/bin/env X=1 %s' "$2" ;;
    pre-timeout-quoted) printf '"timeout" 30 %s' "$2" ;;
    word-path)        inv_cmdword "$2" '/usr/bin/' '' ;;
    word-dot)         inv_cmdword "$2" './' '' ;;
    word-dquoted)     inv_cmdword "$2" '"' '"' ;;
    word-squoted)     inv_cmdword "$2" "'" "'" ;;
    word-escaped)     inv_cmdword "$2" '\' '' ;;
    heredoc-cont)          inv_heredoc "$2" $'cat <<E \\\nx\nE' ;;
    heredoc-cont-dash)     inv_heredoc "$2" $'cat <<-E \\\n\tx\n\tE' ;;
    heredoc-cont-squote)   inv_heredoc "$2" $'cat <<\'E\' \\\nx\nE' ;;
    heredoc-cont-dquote)   inv_heredoc "$2" $'cat <<"E" \\\nx\nE' ;;
    heredoc-cont-space)    inv_heredoc "$2" $'cat << E \\\nx\nE' ;;
    heredoc-cont-twice)    inv_heredoc "$2" $'cat <<E \\\n-n \\\n-E\nx\nE' ;;
    heredoc-cont-redirect) inv_heredoc "$2" $'cat > f <<E \\\nx\nE' ;;
    *)                return 1 ;;
  esac
  return 0
}
# A variant on one line, for a label and for the ledger. `record` keeps only what
# precedes the first newline, so a variant carrying one would reach the matrix as
# half of itself and two variants would read there as the same check.
inv_show() {  # inv_show <variant>
  local s=${1//$'\n'/\\n}
  printf '%s' "${s//$'\t'/\\t}"
}

# THE DECLARED DEPARTURES, one per line:
# <seed keys or verdict class>|<transformation>|<verdict>|<kind>|<tags>|<reason>
# and, for a gap whose right verdict is not the seed's, a seventh field holding
# that verdict.
#
# `design` is a variant that reaches a different verdict and is right to: the
# transformation changed what the command does, or it put the command where
# CLAUDE.md's deliberately-left-open list says a hook stops reading. Its verdict
# is a literal and its reason names what decides it.
#
# `gap` is a variant that reaches the WRONG verdict today. The check is written
# at the correct verdict, which `gap` prints, and asserts the wrong one until
# the issue named closes, at which point it goes red and is rewritten as an
# ordinary check. Its tags are the gap's own requirement ID and never the
# seed's, so a gap covers nothing: requirements.md marks those entries
# `gap → #<n>` and the coverage check does not ask about them.
#
# A SEVENTH FIELD carries the right verdict where it is not the seed's, and this
# is the case the first version of this table could not say at all. A gap was
# "wrong today, and the seed's verdict is the right one", because `gap` was
# handed `$swant`. #118's triage decision is not of that shape: on a guarded
# group, ANY option before a subcommand word makes the command unreadable and
# must be refused, so the right verdict is BLOCK for a permitted seed as much as
# for a refused one. `gh pr -t view view 5` is a read of a pull request that the
# hook must refuse once #118 lands, and its seed `gh pr view 5` is ALLOW.
#
# Without the field those six rows carried no departure at all, so they asserted
# ALLOW as the invariant and would have gone red on #118's fix looking like
# regressions rather than like gaps closing. The transformation is not
# verdict-preserving on a guarded group in EITHER direction, and a table that
# can only express one of the two directions hides the other. Found by Bertan's
# review of PR #140; the check's own definition of a gap was narrower than the
# defects it was finding.
#
# The first field is either a space-separated list of seed keys, or a verdict
# class -- `BLOCK:*` or `ALLOW:*` -- which declares the departure for every seed
# of that direction at once. A class is used where the finding is about the
# class rather than about particular commands. #117 is exactly that: every
# refused seed of every hook is permitted under all five spellings of its
# command word. One row is a stronger claim than thirty-eight copies of it and
# not a weaker one -- a refused seed that turned out to be refused under
# `/usr/bin/` after all fails this row, where its own row would have passed and
# said nothing. #135 is deliberately NOT a class: the word two in is the group
# for `git push` and `gh pr` and an ordinary argument for `pytest tests/`, so a
# class there would claim something of `pytest "tests/"` that is not true of it.
#
# An exact key wins over a class, and a class applies only where no exact key
# does. Every row must be used: a seed renamed or a transformation that has
# stopped applying leaves a row declaring nothing, and the guard below fails on
# it rather than letting the table rot into a list of things that were once so.
INV_DEPARTURES=$(cat <<'EX'
push-own|global-flag|BLOCK|design|US-3|git -C moves git's working directory, so where the push would land cannot be judged from here
push-own|global-flag-gitdir|BLOCK|design|GH-43.6|git --git-dir moves which repository git acts on, so where the push would land cannot be judged from here
push-own|redirect-quoted|BLOCK|design|GH-50.3|a quoted redirect target is left in the arguments and read as a second refspec, which GH-50.3 records as a knowingly-taken shortfall against #50; it is the push hook's alone, and `git status` and an ordinary `grep` wearing the same target are permitted
commit-dev|global-flag|BLOCK|design|GH-43.2|git -C moves git's working directory, so whether the commit lands on main cannot be judged from here
commit-dev|global-flag-gitdir|BLOCK|design|GH-43.6|git --git-dir moves which repository git acts on, so whether the commit lands on main cannot be judged from here
pr-web|quote-double-4|BLOCK|design|FR-21 FR-14|base_args drops a quoted span whole, and quoted text may not grant an exemption
pr-web|quote-single-4|BLOCK|design|FR-21 FR-14|base_args drops a quoted span whole, and quoted text may not grant an exemption
pr-base-dev pr-base-dev-eq|quote-double-4|BLOCK|design|FR-14 GH-139|a base flag with a quote in its name is refused rather than read, because reading it is unquoting and unquoting could invent a base
pr-base-dev pr-base-dev-eq|quote-single-4|BLOCK|design|FR-14 GH-139|a base flag with a quote in its name is refused rather than read, because reading it is unquoting and unquoting could invent a base
pr-retarget-dev|quote-double-5|BLOCK|design|FR-17 GH-139|a base flag with a quote in its name is refused rather than read, on the retarget arm as on the creating ones, even where the base it names is dev-NN
pr-retarget-dev|quote-single-5|BLOCK|design|FR-17 GH-139|a base flag with a quote in its name is refused rather than read, on the retarget arm as on the creating ones, even where the base it names is dev-NN
release-view|quote-double-3|BLOCK|gap|GH-135|the release verb in double quotes, refused by the allowlist that cannot read it
release-view|quote-single-3|BLOCK|gap|GH-135|the release verb in single quotes, refused by the allowlist that cannot read it
BLOCK:*|option-eats-verb|ALLOW|gap|GH-118|an option before the subcommand eats the read verb after it
pr-view pr-base-dev pr-base-dev-eq pr-retarget-dev pr-web release-view|option-eats-verb|ALLOW|gap|GH-118|an option before the subcommand makes a guarded path unreadable, and the right verdict is a refusal whatever the seed's is|BLOCK
push-wrapped pr-merge-wrapped pr-view-wrapped commit-wrapped|word-if|ALLOW|gap|GH-134|a wrapper after a control word
push-wrapped pr-merge-wrapped pr-view-wrapped commit-wrapped|word-for|ALLOW|gap|GH-134|a wrapper after a control word
push-wrapped pr-merge-wrapped pr-view-wrapped commit-wrapped|word-brace|ALLOW|gap|GH-134|a wrapper after a control word
push-all push-main push-force push-from-main-checkout commit-main commit-push-all commit-stale api-rest-main release-create pr-merge pr-base-main pr-base-main-eq pr-bundled pr-short-flags pr-no-base pr-retarget pr-web-main|quote-double-2|ALLOW|gap|GH-135|the group word in double quotes
push-all push-main push-force push-from-main-checkout commit-main commit-push-all commit-stale api-rest-main release-create pr-merge pr-base-main pr-base-main-eq pr-bundled pr-short-flags pr-no-base pr-retarget pr-web-main|quote-single-2|ALLOW|gap|GH-135|the group word in single quotes
pr-merge pr-base-main pr-base-main-eq pr-bundled pr-short-flags pr-no-base pr-retarget pr-web-main|quote-double-3|ALLOW|gap|GH-135|the subcommand verb in double quotes
pr-merge pr-base-main pr-base-main-eq pr-bundled pr-short-flags pr-no-base pr-retarget pr-web-main|quote-single-3|ALLOW|gap|GH-135|the subcommand verb in single quotes
pytest-uv alembic-uv|flag-attached|BLOCK|gap|GH-136|the dependency group named with an attached value
pytest-uv alembic-uv|quote-double-3|BLOCK|gap|GH-136|the group flag in double quotes
pytest-uv alembic-uv|quote-single-3|BLOCK|gap|GH-136|the group flag in single quotes
pytest-uv alembic-uv|quote-double-4|BLOCK|gap|GH-136|the group value in double quotes
pytest-uv alembic-uv|quote-single-4|BLOCK|gap|GH-136|the group value in single quotes
docs-truncate|continuation|ALLOW|gap|GH-156|the verb and the path on either side of a backslash, which this hook's greps read as two lines and a shell runs as one
docs-truncate|word-path|ALLOW|gap|GH-171|a command word spelled as a path, which this hook's verb grep does not reduce to the name it spells
docs-truncate|word-dot|ALLOW|gap|GH-171|a command word spelled with ./, which this hook's verb grep does not reduce to the name it spells
docs-truncate|word-dquoted|ALLOW|gap|GH-171|a double-quoted command word, which this hook's verb grep does not reduce to the name it spells
docs-truncate|word-squoted|ALLOW|gap|GH-171|a single-quoted command word, which this hook's verb grep does not reduce to the name it spells
docs-truncate|word-escaped|ALLOW|gap|GH-171|a backslash-escaped command word, which this hook's verb grep does not reduce to the name it spells
EX
)

# Tagged before the table is read, not after. Every check this section prints is
# one of its own claims about its own tables, and the two loops below print one
# before any seed has been reached -- so without this they are untagged, the #104
# tag check reports each a second time as carrying no tag, and a reader chasing
# two red lines finds one defect. Bertan's round-two review of PR #140 found it
# by mutating a design row and reading what came back.
req GH-106
declare -A INV_DEP
declare -A INV_DEP_USED
INV_DEP_ROWS=0
while IFS='|' read -r dkeys dtrans dwant dkind dtags dreason dright; do
  [ -n "$dkeys" ] || continue
  INV_DEP_ROWS=$((INV_DEP_ROWS + 1))
  case "$dkind" in
    design)
      [ -z "$dright" ] || fail static \
        'the departure %s + %s is a design row with a right verdict; a design row IS the right verdict' \
        "$dkeys" "$dtrans" ;;
  esac
  # Globbing off for the split: a class key is the literal `BLOCK:*`, and with
  # globbing on a file named `BLOCK:x` beside this suite would expand it and
  # silently retarget the row at a seed key that is not a class at all.
  set -f
  for dkey in $dkeys; do
    INV_DEP["$dkey|$dtrans"]="$dwant|$dkind|$dtags|$dreason|$dright"
    INV_DEP_USED["$dkey|$dtrans"]=0
  done
  set +f
done <<< "$INV_DEPARTURES"

# The generator. One seed at a time: its own verdict first, since the invariance
# is about reaching that verdict and a family whose seed is wrong establishes
# nothing, and then every transformation that applies to it.
declare -A INV_APPLIED
# Every seed's command, so a variant that IS another seed's command can be
# skipped rather than checked twice under two names: both are already checked as
# seeds, and the ledger would carry one command as two results. `quote-*-last`
# took this trouble from the start and the other transformations did not, which
# is one rule applied unevenly -- Bertan's review of PR #140 named it.
#
# KEYED BY FIXTURE AND HOOK AS WELL AS BY TEXT, which the first version was not,
# and #141 is why. The skip's premise is that the regenerated command "is
# already checked as a seed, with the same verdict" -- and a command's verdict
# is a property of the text TOGETHER WITH the directory it runs in and the hook
# that judges it. #141 seeds `git push --all origin` twice on purpose,
# `push-all` against no-git-push.sh in a worktree and `commit-push-all` against
# no-commit-to-main.sh on `main`, because two hooks reading one command is two
# claims. Both are BLOCK, so keying on text alone skips nothing wrongly today;
# it would the first time two fixtures held one command at two verdicts, and it
# would do it by declaring a check already made. Found by review of this branch.
#
# The two examples this comment used to give -- `flag-separated` on
# `pr-base-main-eq` regenerating `pr-base-main`, and `short-bundled` on
# `pr-short-flags` regenerating `pr-bundled` -- no longer regenerate anything:
# their tails diverged (`--body y` against `--title x`), and the counter this
# section prints has read 0 ever since. The guard is kept because the next pair
# of seeds that collides will collide silently, and the count is what says
# whether it ever fires.
declare -A INV_IS_SEED
while IFS='|' read -r sdir0 shook0 _ _ _ scmd0; do
  [ -n "$scmd0" ] && INV_IS_SEED["$sdir0|$shook0|$scmd0"]=1
done <<< "$INV_SEEDS"
INV_SEED_COUNT=0
INV_VARIANTS=0
INV_SKIPPED=0
INV_REGENERATED=0
INV_DESIGN=0
INV_GAPS=0
while IFS='|' read -r sdir shook swant stags skey scmd; do
  [ -n "$skey" ] || continue
  # And again per seed, before the two guards below, since `req $stags` is set
  # only once a seed has survived them: on the first iteration REQ would be the
  # departure loop's, and on any later one the PREVIOUS seed's tags, which is
  # worse than none -- a malformed seed would be reported as evidence about
  # whatever requirement the seed before it established.
  req GH-106
  if ! sfix=$(inv_dir "$sdir"); then
    fail static 'the seed %s names the fixture %s, which inv_dir does not resolve' "$skey" "$sdir"
    continue
  fi
  if [ -z "$scmd" ]; then
    fail static 'the seed %s has no command, so the field separator has cut it' "$skey"
    continue
  fi
  INV_SEED_COUNT=$((INV_SEED_COUNT + 1))
  req $stags
  check_in "$sfix" "$shook" "$swant" "seed $skey: $scmd" "$scmd"
  for trans in $INV_TRANSFORMS; do
    # And a third time per variant, for the same reason one loop further in.
    # Three guards below fire before the `req` of the branch they sit in -- the
    # transformation with no rewrite, the gap whose right verdict is the one it
    # asserts, and the kind that is neither. Each would otherwise carry the tags
    # of the PREVIOUS variant's check_in, or of this seed's own, and a table
    # defect would be filed as evidence about FR-14 or FR-48. The three `req`s
    # below this line stay where they are: they must win for the verdict checks.
    req GH-106
    if ! variant=$(inv_apply "$trans" "$scmd"); then
      fail static 'the transformation %s is in the list with no rewrite of its own' "$trans"
      continue
    fi
    if [ -z "$variant" ]; then
      INV_SKIPPED=$((INV_SKIPPED + 1))
      continue
    fi
    # A variant that is another seed's command, IN THIS FIXTURE AND FOR THIS
    # HOOK, is that seed's check and not a variant of this one. Its own seed row
    # asserts it, with the same verdict -- which is only true when all three
    # agree, for the reason the key above gives.
    if [ "$variant" != "$scmd" ] && [ -n "${INV_IS_SEED["$sdir|$shook|$variant"]:-}" ]; then
      INV_REGENERATED=$((INV_REGENERATED + 1))
      continue
    fi
    INV_VARIANTS=$((INV_VARIANTS + 1))
    INV_APPLIED["$trans"]=$(( ${INV_APPLIED["$trans"]:-0} + 1 ))
    dep=${INV_DEP["$skey|$trans"]:-}
    if [ -n "$dep" ]; then
      INV_DEP_USED["$skey|$trans"]=1
    else
      dep=${INV_DEP["$swant:*|$trans"]:-}
      [ -z "$dep" ] || INV_DEP_USED["$swant:*|$trans"]=1
    fi
    if [ -z "$dep" ]; then
      req $stags
      check_in "$sfix" "$shook" "$swant" "$skey + $trans: $(inv_show "$variant")" "$variant"
      continue
    fi
    IFS='|' read -r dwant dkind dtags dreason dright <<< "$dep"
    case "$dkind" in
      design)
        INV_DESIGN=$((INV_DESIGN + 1))
        req ${dtags:-$stags}
        check_in "$sfix" "$shook" "$dwant" \
          "$skey + $trans, by design ($dreason): $(inv_show "$variant")" "$variant" ;;
      gap)
        # A gap whose right verdict is the one it asserts is not a gap, and it
        # would pass for as long as the defect it names survives the fix.
        if [ "${dright:-$swant}" = "$dwant" ]; then
          fail static 'the departure %s + %s is a gap whose right verdict is the one it asserts' \
            "$skey" "$trans"
          continue
        fi
        INV_GAPS=$((INV_GAPS + 1))
        req $dtags
        gap "$sfix" "$shook" "${dright:-$swant}" "$dwant" \
          "$skey + $trans, $dreason: $(inv_show "$variant")" "$variant" ;;
      *)
        fail static 'the departure %s + %s has the kind %s, which is neither design nor gap' \
          "$skey" "$trans" "$dkind" ;;
    esac
  done
done <<< "$INV_SEEDS"

# THE SEED TABLE COVERS WHAT IT CLAIMS TO. Derived off the table, held to a
# literal: every functional requirement the table seeds, and both verdicts
# beside each. A seed deleted, retagged or flipped to one direction moves this.
# FR-13 and FR-49 are absent for the two reasons given where the table stands.
#
# WHAT THIS DOES NOT SAY, since the first version of this comment said it. The
# literal is the set someone chose, so this catches a table that has drifted
# from the choice and cannot catch the choice being wrong -- an FR that names a
# command and was never seeded is missing from both sides at once. What stands
# behind the choice is a reading of FR-1 to FR-49, done twice: once writing the
# table, and once by a reviewer of this branch who was asked to derive the set
# independently and got the same twelve.
req GH-106
tok 'the seeds cover every functional requirement (FR-) with a command spelling, in both directions' \
  'FR-14 ALLOW BLOCK;FR-15 ALLOW BLOCK;FR-16 ALLOW BLOCK;FR-17 ALLOW BLOCK;FR-18 ALLOW BLOCK;FR-19 ALLOW BLOCK;FR-20 ALLOW BLOCK;FR-21 ALLOW BLOCK;FR-3 ALLOW BLOCK;FR-38 ALLOW BLOCK;FR-4 ALLOW BLOCK;FR-48 ALLOW BLOCK;' \
  "$(printf '%s\n' "$INV_SEEDS" \
     | awk -F'|' 'NF >= 6 { n = split($4, t, " "); for (i = 1; i <= n; i++) if (t[i] ~ /^FR-/) print t[i], $3 }' \
     | LC_ALL=C sort -u \
     | awk '{ v[$1] = v[$1] " " $2 } END { for (k in v) print k v[k] }' \
     | LC_ALL=C sort | tr '\n' ';')"

# AND THE `GH-` FAMILY, WHICH IS A RULE AND NOT A LITERAL. #141.
#
# The FR check above is a literal, and its own comment says what that cannot do:
# the literal is the set someone chose, so an FR that names a command and was
# never seeded is missing from both sides at once. For the `GH-` family that
# blind spot was the whole family -- 95 entries when measured on 2026-09-17,
# the ones written FROM defects rather than from the specification, and not
# one of them asked for.
#
# So the scope is derived off requirements.md instead. Each entry in it declares
# what the families do with it, and these three checks hold that declaration to
# the tables above: a seed to a tagged row, a named transformation to
# INV_TRANSFORMS, and a `none` to a reason. The rule and the argument for it are
# in requirements.md under *What the invariance families seed*; what is here is
# the derivation.
#
# WHAT IS LITERAL, since this is the check that changes what a table has to
# hold. INV_SCOPE is the in-scope set with each entry's answer, and it is the
# second copy #104's shape literal exists for: without it a new `GH-` entry
# could arrive declaring `none: <plausible reason>`, or an existing one move
# from `seed` to `none`, and nothing here would move. With it, both go red until
# this line moves too, which is the edit a reviewer reads. The seed verdicts are
# a literal for the same reason they are on the FR side.
#
# WHAT IT STILL CANNOT DO is argued where the rule is, under *The trade, taken
# knowingly* in requirements.md, and is not restated here: `none` is a
# declaration, and this check asks only that the reason is there. The pointer
# rather than a fourth copy -- the trade was written out in three places on this
# branch before review counted them.
INV_SCOPE='
GH-43.1:seed GH-43.2:transformation GH-43.3:seed GH-43.4:seed
GH-43.6:transformation GH-44.1:none GH-44.2:none GH-44.3:none GH-44.4:none
GH-44.5:none GH-44.6:none GH-47.1:transformation GH-47.2:transformation
GH-50.1:transformation GH-50.2:none GH-50.3:transformation GH-51.1:seed
GH-51.2:seed GH-58.1:none GH-68.1:seed GH-68.2:none GH-68.3:none GH-69.1:seed
GH-69.2:seed GH-69.3:none GH-72:seed GH-79.1:transformation GH-79.2:none
GH-79.3:none GH-79.4:none GH-84.1:none GH-94.1:seed GH-94.2:none GH-94.4:none
GH-95.1:none GH-95.2:none GH-96.1:none GH-97.1:seed GH-128:transformation
GH-117:transformation GH-133:none GH-137.1:seed GH-137.2:seed
GH-139:transformation GH-109.5:none
'
# One row per entry that is either in scope or carries the field: `<ID>|in|out`,
# the `variants` keyword, and whatever follows it. An entry out of scope is
# emitted only when it carries the field, which is how a field written on an
# entry that has no business with it is caught rather than ignored.
# HOW A FIELD'S VALUE SPLITS, answered once. requirements.md's grammar says a
# field is `- key: value` and that a value's first word may be a keyword with a
# payload after a colon -- `refuse-only: <reason>`, `gap → #<n>`,
# `none: <reason>` -- and two awk programs in this file have to read it: this
# section's, and the #104 coverage machinery's a thousand lines below. It was
# written twice the first time, which is the defect class lib/command-scan.sh's
# header opens by naming, so it is one variable prepended to both programs
# instead. Found by review of this branch.
#
# Prepended rather than sourced because awk has no include: `awk
# "$REQ_FIELD_AWK$OTHER" file` is one program built from two strings, and the
# functions have to come first for neither program to redefine them.
REQ_FIELD_AWK=$(cat <<'AWK'
  function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
  function keyword(v) { sub(/[: ].*$/, "", v); return v }
  function after_colon(v) { if (index(v, ":") == 0) return ""; return trim(substr(v, index(v, ":") + 1)) }
AWK
)
INV_VARIANTS_AWK=$(cat <<'AWK'
  function flush(   inscope) {
    if (id == "") return
    # `id ~ /^GH-/` says what the rule says. requirements.md forbids a `kind` on
    # an entry that is not a `GH-` one, so no US- or FR- entry reaches the rest
    # of this line today (measured: 0). That is a second file's rule holding this
    # one's condition together, which is the coupling #84 is about, so the
    # condition carries its own copy.
    inscope = id ~ /^GH-/ \
              && (kind == "defect-permitting" || kind == "defect-refusing") \
              && status == "active" && keyword(direction) != "static" && seam != "none"
    if (inscope || variants != "")
      printf "%s|%s|%s|%s\n", id, (inscope ? "in" : "out"), keyword(variants), after_colon(variants)
    id = ""
  }
  /^### / { flush(); id = $2; kind = ""; status = ""; direction = ""; seam = ""; variants = ""; lastkey = ""; next }
  /^## /  { flush(); next }
  id != "" && /^- [a-z-]+:/ {
    key = $0; sub(/^- /, "", key); sub(/:.*$/, "", key)
    val = $0; sub(/^- [a-z-]+:[ \t]*/, "", val)
    if (key == "kind") kind = val
    else if (key == "status") status = val
    else if (key == "direction") direction = val
    else if (key == "seam") seam = val
    else if (key == "variants") variants = val
    lastkey = key
    next
  }
  id != "" && lastkey == "variants" && /^  [^ ]/ { variants = variants " " trim($0); next }
  END { flush() }
AWK
)
# Sorted, one space between, for a comparison that reads as a set rather than as
# whatever order a file happens to be in. Defined above the `req` below rather
# than between it and the check it serves: a definition sets no requirement, and
# a reader following a tag down the file should not have to step over one.
inv_sorted() {  # inv_sorted <space-separated tokens> -- sorted, one space between
  local out
  # Globbing off for the split, as every other split in this section pairs it:
  # the tokens here are `GH-<n>:<keyword>` and carry no glob character today,
  # which is a reason this has not bitten and not a reason to leave it unpaired.
  # The pairing is the rule; #106's own `inv_quote_at` argues it one screen up.
  set -f
  out=$(printf '%s ' $1 | tr ' ' '\n' | grep -v '^$' | LC_ALL=C sort | tr '\n' ' ')
  set +f
  printf '%s' "$out"
}

# Tagged before the loop, for the reason the departure loop above is: every
# guard below can print before any entry has survived, and an untagged check is
# reported by the #104 section as a second defect.
req GH-141
INV_SCOPE_DERIVED=
INV_SEEDS_DECLARED=
INV_SCOPE_BAD=0
set -f
INV_TRANS_LIST=" $(printf '%s ' $INV_TRANSFORMS) "
set +f
while IFS='|' read -r vid vin vkw vpay; do
  [ -n "$vid" ] || continue
  if [ "$vin" != in ]; then
    INV_SCOPE_BAD=$((INV_SCOPE_BAD + 1))
    fail static 'the entry %s carries a variants field and is not in the families scope, which is where that field belongs' "$vid"
    continue
  fi
  INV_SCOPE_DERIVED="$INV_SCOPE_DERIVED $vid:$vkw"
  case "$vkw" in
    seed) INV_SEEDS_DECLARED="$INV_SEEDS_DECLARED $vid" ;;
    transformation)
      if [ -z "$vpay" ]; then
        INV_SCOPE_BAD=$((INV_SCOPE_BAD + 1))
        fail static 'the entry %s declares variants: transformation and names none' "$vid"
      else
        # Globbing off: a `none:` reason may hold `pre-*` and one day a
        # transformation list could too, and a file named `pre-x` beside this
        # suite would expand it into a name nothing holds.
        set -f
        for vname in $vpay; do
          case "$INV_TRANS_LIST" in
            *" $vname "*) : ;;
            *) INV_SCOPE_BAD=$((INV_SCOPE_BAD + 1))
               fail static 'the entry %s names the transformation %s, which INV_TRANSFORMS does not have' \
                 "$vid" "$vname" ;;
          esac
        done
        set +f
      fi ;;
    none)
      [ -n "$vpay" ] || { INV_SCOPE_BAD=$((INV_SCOPE_BAD + 1))
        fail static 'the entry %s declares variants: none and gives no reason' "$vid"; } ;;
    '')
      INV_SCOPE_BAD=$((INV_SCOPE_BAD + 1))
      fail static 'the entry %s is in the families scope and declares no variants field at all' "$vid" ;;
    *)
      INV_SCOPE_BAD=$((INV_SCOPE_BAD + 1))
      fail static 'the entry %s declares variants: %s, which is none of seed, transformation and none' \
        "$vid" "$vkw" ;;
  esac
done <<< "$(awk "$REQ_FIELD_AWK$INV_VARIANTS_AWK" "$HOOKS/requirements.md")"
# Nothing read is a defect of its own AND counts itself in, because the line
# below is a claim about every entry in scope and an empty read makes it a claim
# about none. Written as two statements the first time and found by review of
# this branch: the `ok` printed beside the failure, which is the shape #98's
# section is about -- a check that passes by computing nothing.
if [ -z "$INV_SCOPE_DERIVED" ]; then
  INV_SCOPE_BAD=$((INV_SCOPE_BAD + 1))
  fail static 'no GH- entry was read out of requirements.md at all, so the three checks below say nothing'
fi
[ "$INV_SCOPE_BAD" -gt 0 ] \
  || pass static 'every GH- entry in the families scope declares a variants value this suite can act on'

# THE COUNTS, printed rather than written in a comment. The first version of
# this section put "38 entries in scope, 11 seeds, 7 transformations, 20 none"
# in the prose above, in the same commit whose other file argues that a count in
# a comment is what #107 was filed about. Four numbers nothing derived, stale on
# the next `GH-` entry. This line derives them; nothing restates them.
req GH-141
INV_SCOPE_N=0; INV_SCOPE_SEED=0; INV_SCOPE_TRANS=0; INV_SCOPE_NONE=0
set -f
for vtok in $INV_SCOPE_DERIVED; do
  INV_SCOPE_N=$((INV_SCOPE_N + 1))
  case "${vtok#*:}" in
    seed)           INV_SCOPE_SEED=$((INV_SCOPE_SEED + 1)) ;;
    transformation) INV_SCOPE_TRANS=$((INV_SCOPE_TRANS + 1)) ;;
    none)           INV_SCOPE_NONE=$((INV_SCOPE_NONE + 1)) ;;
  esac
done
set +f
pass static 'the families scope holds %d GH- entries: %d seeded, %d naming a transformation, %d with no command spelling to vary' \
  "$INV_SCOPE_N" "$INV_SCOPE_SEED" "$INV_SCOPE_TRANS" "$INV_SCOPE_NONE"

req GH-141
tok 'the GH- entries in the families scope are these, each with what it says the families do with it' \
  "$(inv_sorted "$INV_SCOPE")" "$(inv_sorted "$INV_SCOPE_DERIVED")"

# The two halves of one claim, and it is deliberately an equality and not an
# inclusion: an entry declaring `seed` and tagged on no seed is a scope decision
# nothing carries out, and a seed tagged with an entry that declares something
# else is a row whose requirement disowns it. Either way one of the two is
# wrong, and which is not this check's to say.
req GH-141
tok 'every GH- entry declaring variants: seed is tagged on a seed, and every GH- tag in the seed table belongs to one' \
  "$(inv_sorted "$INV_SEEDS_DECLARED")" \
  "$(printf '%s\n' "$INV_SEEDS" \
     | awk -F'|' 'NF >= 6 { n = split($4, t, " "); for (i = 1; i <= n; i++) if (t[i] ~ /^GH-/) print t[i] }' \
     | LC_ALL=C sort -u | tr '\n' ' ')"

# The verdicts, as the FR check holds its own. One direction is allowed here and
# the literal is where that shows: GH-43.1 is seeded ALLOW alone because its
# subject is that prose naming a push is not a push, and GH-72 ALLOW alone
# because the refusing half of it -- `./gh` and `/usr/bin/gh` still refused --
# is GH-117's open gap, which the class rows above already assert.
req GH-141
tok 'the GH- seeds are tagged in the directions the table holds' \
  'GH-137.1 BLOCK;GH-137.2 ALLOW BLOCK;GH-43.1 ALLOW;GH-43.3 BLOCK;GH-43.4 BLOCK;GH-51.1 BLOCK;GH-51.2 BLOCK;GH-68.1 ALLOW;GH-69.1 ALLOW BLOCK;GH-69.2 ALLOW BLOCK;GH-72 ALLOW;GH-94.1 ALLOW BLOCK;GH-97.1 ALLOW BLOCK;' \
  "$(printf '%s\n' "$INV_SEEDS" \
     | awk -F'|' 'NF >= 6 { n = split($4, t, " "); for (i = 1; i <= n; i++) if (t[i] ~ /^GH-/) print t[i], $3 }' \
     | LC_ALL=C sort -u \
     | awk '{ v[$1] = v[$1] " " $2 } END { for (k in v) print k v[k] }' \
     | LC_ALL=C sort | tr '\n' ';')"

# EVERY TRANSFORMATION DOES WORK, and the list is the same list twice over.
#
# Two questions, and the second is #84's shape: a literal list beside the code it
# names goes stale, and the stale half is the one nobody reads. `inv_apply`'s
# case arms are what can actually rewrite a command, so they are the truth and
# INV_TRANSFORMS is derived against them -- an arm never listed is dead code that
# runs for nobody, and a name listed with no arm is caught by `inv_apply`'s own
# `*) return 1`, which the loop above fails on. The `*` arm and the case's own
# closing are excluded by name.
#
# Comments are stripped first, as cs_calls and STATUS_READERS strip them, so an
# arm named in the prose above does not count as one.
req GH-106
INV_ARMS=$(sed -n '/^inv_apply() {/,/^}/p' "$SUITE_DIR/check-hooks.sh" \
  | sed 's/[[:space:]]*#.*$//' \
  | awk 'match($0, /^[[:space:]]+[a-z0-9-]+\)/) {
           a = substr($0, RSTART, RLENGTH); sub(/[[:space:]]*/, "", a); sub(/\)$/, "", a)
           if (a != "*") print a }' \
  | LC_ALL=C sort | tr '\n' ' ')
tok 'the transformation list is exactly the rewrites inv_apply has arms for' \
  "$(printf '%s ' $INV_TRANSFORMS | tr ' ' '\n' | grep -v '^$' | LC_ALL=C sort | tr '\n' ' ')" \
  "$INV_ARMS"
[ -n "$INV_ARMS" ] || fail static 'no transformation arm was derived from inv_apply at all'
for trans in $INV_TRANSFORMS; do
  [ "${INV_APPLIED["$trans"]:-0}" -gt 0 ] \
    && pass static 'the transformation %s applied to %s seeds' "$trans" "${INV_APPLIED["$trans"]}" \
    || fail static 'the transformation %s applied to no seed at all, so it checks nothing' "$trans"
done

# EVERY DECLARED DEPARTURE IS USED. A departure is a claim about a variant this
# generator produces, so one naming a seed that has been renamed or a
# transformation that no longer applies to it claims nothing -- and claims it
# silently, in the permitting direction, since a gap left unreachable is a defect
# nothing asks about any more. Each pair is asked for by key, so the row that
# declares a whole verdict class is satisfied by the first seed it reaches and
# says nothing about the rest; that is what the class rows' own reasoning above
# rests on instead.
req GH-106
for key in "${!INV_DEP_USED[@]}"; do
  [ "${INV_DEP_USED[$key]}" = 1 ] \
    && pass static 'the departure %s is declared and reached' "$key" \
    || fail static 'the departure %s is declared and no variant reaches it' "$key"
done

# What the families came to. Not a verdict of its own -- a count cannot say a
# check is right -- but a transformation that applies to nothing, and a seed
# table an edit has cut in half, are both invisible without it.
#
# WHAT IT COSTS, which #141's fourth acceptance criterion asks for. Measured on
# 2026-09-17, on one machine, in one worktree, all runs green:
#
#   before #141  118.6 s                             39 seeds, 1436 variants
#   after        116.8 117.1 118.4 119.9 122.6       46 seeds, 1807 variants
#                133.1                               (n=6)
#
# 371 more variants, 26% more of them, and the difference between the two rows
# is smaller than the range WITHIN the second: the six after-runs span 16.3 s
# and their median is 119.2 s, against a single before-run of 118.6 s. So this
# measurement supports "the addition did not move the run time by anything this
# suite can resolve" and does not support a figure for how much it moved it by.
# A second before-run was not taken and should have been; the numbers above are
# what there is.
#
# The range is the finding rather than noise around one. The 133.1 s run and a
# 116.8 s run are the same tree minutes apart, with other worktree sessions on
# the machine -- so a few seconds read off one run of each tree, which is how
# #140's recorded number and this branch's would have been compared, says
# nothing at all.
#
# The per-variant model over-predicts, and that is worth writing down because
# #141's cost paragraph reasons from one. Timed directly, n=100 each, one hook
# invocation exactly as check_in makes it: 10.9 ms for append-only-docs.sh,
# 16.0 ms for no-commit-to-main.sh, 29.8 ms for no-pr-decisions.sh. At those
# rates 371 variants would be 5-7 s, and the suite does not show it -- a cold
# invocation from a shell loop is not what a variant costs in the middle of a
# run that has already paged everything in. Plan with the measured suite, not
# with the product.
#
# #140's 94.0 s, which #141 reasons from, is NOT comparable with any of these:
# the commit this branch starts from measures 118.6 s here. A budget decision
# has to be baseline-to-after on one machine, and #141's "the same again would
# want a decision about the budget rather than a drift into it" is about the
# 53 s #140 added -- which this is not, on this evidence, at all.
req GH-106
[ "$INV_SEED_COUNT" -gt 0 ] || fail static 'the seed table yielded no seed at all'
[ "$INV_VARIANTS" -gt 0 ] || fail static 'the transformations yielded no variant at all'
[ "$INV_DEP_ROWS" -gt 0 ] || fail static 'the departure table yielded no row at all'
pass static 'invariance families: %d seeds, %d variants (%d not applicable, %d another seed), %d by design, %d a gap' \
  "$INV_SEED_COUNT" "$INV_VARIANTS" "$INV_SKIPPED" "$INV_REGENERATED" "$INV_DESIGN" "$INV_GAPS"
section "=== issue #107: the mutation harness, and the hooks directory it judges ==="
# The claims this suite makes about its own mutation-checking are prose: about
# two dozen of them, each a run someone did by hand against a harness that no
# longer exists. #107 makes them re-runnable, and what it added is two things
# that can go wrong independently of each other.
#
# GH-107.1 is the alternative hooks directory. $CHECK_HOOKS_DIR moves what this
# suite JUDGES -- the hook files, the library, their text, requirements.md --
# and moves nothing it judges them AGAINST, which stays this repository's:
# settings.json, CLAUDE.md, CONTEXT.md, the two skills, the working directory a
# hook is run in, and this file. The head of this suite argues that split; what
# is checked here is the guard on it, in the refusing direction, because the
# permitting direction is a full run of this suite against a copy and this
# suite cannot ask for one of itself. That run is mutate-hooks.sh's baseline,
# which is where the evidence for it is, and it is evidence made outside this
# file rather than in it. Named rather than left as a silence.
#
# THE RECURSION, and why it is bounded. The two checks below run this suite
# again, with an override the guard must refuse, so they cost what the guard
# costs and nothing more -- it exits before the first fixture is made. A guard
# that did NOT refuse would run the whole suite instead, which would reach this
# section, which would run it again: unbounded, at 95 s a level. So the inner
# run is marked, this section asks its two questions only when unmarked, and
# each check asserts the guard's MESSAGE and not merely a non-zero exit -- an
# inner run that went the whole way would exit 1 for its own uncovered
# requirement and say nothing about a directory.
#
# GH-107.2 is the harness itself, held here as text: it never edits this
# repository's hooks, a mutation that does not apply is a failure rather than a
# pass, the baseline has to be green, and its registry names files and
# requirement IDs that exist. That last one is what keeps the registry from
# rotting quietly -- a row naming a renamed file reports did-not-apply, which is
# loud, but a row naming a requirement that has been retired would report
# `survived` for ever and read as a defect in the hooks rather than in the row.
# Read off $SUITE_DIR and not $HOOKS. Under an override $HOOKS/mutate-hooks.sh
# is a copy of this harness that no run executes -- the harness that runs is the
# one a person started, from this directory -- so pinning the copy's text would
# be the "evidence about text nobody executed" argument that keeps check-hooks.sh
# off the registry, made about the other half of $TOOLING. A row targeting
# mutate-hooks.sh could turn one of these pins red and be reported as caught.
# Bertan's review of PR #142; the registry audit below refuses such a row.
MUT="$SUITE_DIR/mutate-hooks.sh"
req GH-107.1
if [ -n "${CHECK_HOOKS_NESTED:-}" ]; then
  pass static 'the override guard is not asked of a run that is already one, so nothing recurses'
else
  # Each of the three runs below asserts the guard's MESSAGE and not merely a
  # non-zero exit: an inner run that went the whole way would exit 1 for its own
  # uncovered requirement and say nothing about a directory. Said once here
  # rather than three times, which is this suite's idiom for a shape it repeats.
  override_refused() {  # override_refused <label> <expected text> <cwd> <override>
    local ERR STATUS
    ERR=$(cd "$3" && CHECK_HOOKS_NESTED=1 CHECK_HOOKS_DIR="$4" \
          bash "$SUITE_DIR/check-hooks.sh" 2>&1 >/dev/null)
    STATUS=$?
    case "$STATUS:$ERR" in
      1:*"$2"*) pass static '%s' "$1" ;;
      *) fail static '%s\n         expected exit 1 and |%s|\n         exit=%s stderr |%s|' \
           "$1" "$2" "$STATUS" "$ERR" ;;
    esac
  }
  override_refused 'an override naming no directory stops the suite, saying so' \
    'is not a directory' "$SUITE_DIR" "$FIXTURES/no-such-directory-at-all"

  # A directory that is there and is missing one of the files beside this suite.
  # Built by subtraction -- the whole of .claude/hooks/ and then one file taken
  # off -- so that the file the refusal names is the one removed. Built by
  # addition it was "one file short" only while lib/ held exactly one file, and a
  # second lib/*.sh sorting earlier would have turned this check red about the
  # order of a glob. Bertan's review of PR #142.
  PARTIAL="$FIXTURES/partial-hooks"
  rm -rf "$PARTIAL"
  cp -a "$SUITE_DIR" "$PARTIAL"
  rm -f "$PARTIAL/lib/command-scan.sh"
  [ -r "$PARTIAL/check-hooks.sh" ] && [ ! -e "$PARTIAL/lib/command-scan.sh" ] || {
    echo "the partial hooks fixture was not built as one file short; the check against it proves nothing" >&2
    exit 1
  }
  override_refused 'an override missing a file beside this suite stops it, naming the file' \
    'does not hold lib/command-scan.sh' "$SUITE_DIR" "$PARTIAL"

  # A RELATIVE OVERRIDE IS READ FROM WHERE THE CALLER STOOD. Resolved after the
  # cd at the head of this file it was read from .claude/hooks/ instead, so
  # `CHECK_HOOKS_DIR=lib` from anywhere at all named this repository's own lib/ --
  # a directory that is there, so nothing stopped and the run went on to judge
  # it. The fixture directory below holds no lib/, so the refusal is the answer
  # only while the resolution is the caller's. Bertan's review of PR #142.
  RELATIVE_CWD="$FIXTURES/relative-override"
  mkdir -p "$RELATIVE_CWD"
  [ -e "$RELATIVE_CWD/lib" ] && {
    echo "the relative-override fixture holds a lib/, so the check against it proves nothing" >&2
    exit 1
  }
  override_refused 'a relative override is read from where the caller stood, not from beside this suite' \
    'is not a directory' "$RELATIVE_CWD" lib
fi
# And the two assignments themselves, so that a default quietly changed to
# something other than "the files beside this file" is visible here.
#
# Each literal is written in two quoted halves that bash joins, so that the line
# making the claim does not contain the text it looks for -- the idiom the
# citation pins above use, and for the same reason: `armed` greps this file, so a
# needle spelled whole here would be found on this line and both checks would
# stay green with the assignments deleted. Measured rather than reasoned: with
# the halves joined, `sed 's/#.*//' check-hooks.sh | grep -c` answers 2 for each
# needle, and 1 with them split.
#
# These two cannot be mutation-checked by mutate-hooks.sh, which refuses to
# mutate this file for the reason its registry states. They are held by the split
# above and by review, which is what the harness's own limit paragraph says of
# every rule that lives in this file.
armed 'the hooks under check default to the ones beside this suite' \
      "$SUITE_DIR/check-hooks.sh" 'HOOKS=$SUITE''_DIR'
armed 'and $CHECK_HOOKS_DIR is what moves them' \
      "$SUITE_DIR/check-hooks.sh" 'CDPATH= cd -- "$CHECK_HOOKS''_DIR" 2>/dev/null && pwd)'


# AND THAT EVERY TEXT CHECK READS THE DIRECTORY UNDER JUDGMENT. `armed`,
# `unarmed` and `written` take a file path and grep it, so a bare name in that
# position resolves against this process's working directory, which is
# $SUITE_DIR -- and under an override those checks read this repository's own
# hooks and say nothing whatever about the copy. Sixty-nine of them were spelled
# that way when the two directories were first split, among them every "does not
# source the library unguarded" pin: a copy with a guard deleted and an unguarded
# load appended printed `ok` for all of them, which is #84's defect exactly,
# caught by nothing. Found by Bertan's review of PR #142, and the row
# `library-loaded-unguarded` in mutate-hooks.sh's registry is the mutation that
# now asks it.
#
# So the file argument of every one of those calls is held to a rule, and the
# rule is the two-directory split written out: a name spelled with a path has to
# be under $HOOKS if it is a hook and under $SUITE_DIR if it is the tooling
# beside them, and anything else has to be a variable that resolves somewhere
# already argued. "A variable" alone would not have been enough -- it accepts
# "$SUITE_DIR/no-git-push.sh", which is the same defect one door along.
#
# Derived off this file's text rather than listed, for the reason every derived
# list here carries: a list is what the next call added would not be on.
# Continuation lines are joined, the call is cut into shell words, and the third
# word is the one asked. The count is pinned beside it, so a derivation that
# stopped matching is red rather than empty.
TEXT_CHECK_ARGS=$(awk -v tooling="$TOOLING" '
  function toks(s,   i, n, c, q, start) {
    ntok = 0; i = 1; n = length(s)
    while (i <= n) {
      while (i <= n && substr(s, i, 1) ~ /[ \t]/) i++
      if (i > n) break
      start = i; q = ""
      while (i <= n) {
        c = substr(s, i, 1)
        if (q != "") { if (c == q) q = ""; i++ }
        else if (c == "'"'"'" || c == "\"") { q = c; i++ }
        else if (c ~ /[ \t]/) break
        else i++
      }
      tok[++ntok] = substr(s, start, i - start)
    }
  }
  { line = $0; sub(/[ \t]+$/, "", line) }
  line ~ /\\$/ { sub(/\\$/, "", line); if (!open) open = NR; buf = buf line; next }
  { full = buf line; buf = ""; start = open ? open : NR; open = 0 }
  full !~ /^[ \t]*(armed|unarmed|written)[ \t]/ { next }
  { seen++
    toks(full)
    if (ntok < 3) { print start ": fewer than three arguments"; next }
    a = tok[3]
    gsub(/"/, "", a)
    base = a
    sub(/.*\//, "", base)
    if (a !~ /^\$/)
      print start ": " tok[3] " is a bare name, read from the directory this suite runs in"
    else if (index(" " tooling " ", " " base " ") > 0) {
      if (a !~ /^\$SUITE_DIR\//)
        print start ": " tok[3] " is the tooling beside the hooks and is read from $SUITE_DIR"
    }
    else if (a ~ /\.sh$/ && a !~ /^\$HOOKS\//)
      print start ": " tok[3] " names a hook and is read from $HOOKS" }
  END { print "COUNT " seen + 0 }
' "$SUITE_DIR/check-hooks.sh")
TEXT_CHECK_BAD=$(printf '%s\n' "$TEXT_CHECK_ARGS" | grep -v '^COUNT ')
tok 'this suite makes as many text checks as it expects' \
    '291' "${TEXT_CHECK_ARGS##*COUNT }"
if [ -z "$TEXT_CHECK_BAD" ]; then
  pass static 'every text check names its file through a variable, so an override moves what it reads'
else
  fail static 'a text check names a file that does not move with $HOOKS:\n%s' \
    "$(printf '%s' "$TEXT_CHECK_BAD" | sed 's/^/       /')"
fi


# AND THAT THE GUARD FIRES, asked of each of the three helpers with a needle
# chosen so that the answer without the guard is the opposite of the answer with
# it. Each is handed `check-hooks.sh`, a relative name that does resolve here and
# would resolve here under any override -- the shape the rule is about -- and the
# literal is one the file does hold for the two that look for presence and one it
# does not for the one that looks for absence. A guard that reported ok would
# leave the derivation above a comment about a rule nothing enforces.
if ( FAILED=0; armed 'self-check' check-hooks.sh 'FAILED=0'; exit $FAILED ) >/dev/null 2>&1
then
  fail static 'armed reads a relative file name, so under an override it reads this directory rather than the hooks under judgment'
else
  pass static 'armed refuses a relative file name, which under an override is the wrong directory'
fi
if ( FAILED=0; written 'self-check' check-hooks.sh 'FAILED=0'; exit $FAILED ) >/dev/null 2>&1
then
  fail static 'written reads a relative file name, so under an override it reads this directory rather than the hooks under judgment'
else
  pass static 'written refuses a relative file name, which under an override is the wrong directory'
fi
# The literal is written in two quoted halves that bash joins, so that this line
# does not itself hold the text `unarmed` is being asked not to find -- it greps
# this file, and a needle spelled whole here would make the check fail for the
# needle's sake rather than for the guard's.
if ( FAILED=0; unarmed 'self-check' check-hooks.sh 'CS_NO_SUCH_LITERAL''_IS_WRITTEN_ANYWHERE'; exit $FAILED ) >/dev/null 2>&1
then
  fail static 'unarmed reads a relative file name, so under an override it reads this directory rather than the hooks under judgment'
else
  pass static 'unarmed refuses a relative file name, which under an override is the wrong directory'
fi

req GH-107.2
# The harness is not a hook. It runs this suite; nothing runs it but a person.
# An absence, so it is asked of the derivation `present` reads rather than
# through it -- that helper answers membership, and there is no spelling of it
# that means "and not this one".
case " $RUN_BY_SETTINGS " in
  *" mutate-hooks.sh "*)
    fail static 'settings.json registers mutate-hooks.sh, which judges no command and runs this suite' ;;
  *)
    pass static 'settings.json does not register the mutation harness' ;;
esac
written 'the harness says how it is run' "$MUT" 'bash .claude/hooks/mutate-hooks.sh'
# A RATE, NOT A TOTAL, and review of PR #169 is why: the heading said ABOUT AN
# HOUR while the paragraph under it said ninety minutes, and this pin held the
# file to the stale half of its own contradiction. A total moves every time a
# row is registered -- the thing #148 is filed about -- and the measurement the
# heading rests on is a rate, so the rate is what is pinned.
written 'and roughly what it costs, which is why nothing runs it for you' \
        "$MUT" 'TWO MINUTES A ROW'
written 'and what its exit status means, the two self-tests included' \
        "$MUT" 'EXIT STATUS: non-zero when any row reports something other than'
written 'the harness refuses to mutate the hooks directory it stands in' \
        "$MUT" 'refusing to mutate it'
armed 'and asks that before the first delete, of the resolved paths and of the filesystem' \
      "$MUT" '[ "$WORK_REAL" = "$SRC_REAL" ] || [ "$WORK" -ef "$SRC" ]'
# Neither directory inside the other, which the equality above does not answer:
# mktemp reads $TMPDIR, and a temporary directory under .claude/hooks/ is not the
# same directory as it. Both spellings, since the containment can be either way
# round.
armed 'and that neither directory is inside the other, which equality does not say' \
      "$MUT" 'case "$WORK_REAL/" in "$SRC_REAL"/*)'
armed 'in both directions' \
      "$MUT" 'case "$SRC_REAL/" in "$WORK_REAL"/*)'
# And that a row cannot name its way out of the copy. The audit below asks the
# same of the registry as written; this asks whether the harness would refuse one
# that got there another way, which is the half a static read of the table cannot
# answer.
armed 'a row naming an absolute path or climbing out with .. is refused before the write' \
      "$MUT" '/*|*/../*|../*|*/..|..)'
# And that neither half of $TOOLING can be a target. check-hooks.sh was refused
# by name from the start; mutate-hooks.sh was not, though $MUT above used to read
# the copy's text -- so a row editing the harness's own header could turn one of
# these pins red and be reported as caught, for a file whose running instance was
# never touched. One list, read here and there. Bertan's review of PR #142.
armed 'and a row targeting the tooling beside the hooks, which runs from the repository' \
      "$MUT" 'case " $TOOLING " in *" $FILE "*)'
armed 'which the harness reads from the same list this suite does' \
      "$MUT" 'TOOLING="check-hooks.sh mutate-hooks.sh"'
# THE OUTCOME FIELD IS TIED TO THE ID. Every real mutation expects `caught`, and
# the other two words belong to rows whose id says they are self-tests. Untied,
# the field was also how a real survivor could be declared expected: the row
# reported ok, the counts below still held, and the harness exited 0 with a
# registered mutation alive. The refusing direction, one line long, found by
# Bertan's review of PR #142.
armed 'only a selftest-* row may expect anything but caught' \
      "$MUT" 'caught:*|survived:selftest-*|did-not-apply:selftest-*) ;;'
armed 'and a whole-registry run requires both self-tests to be there' \
      "$MUT" '$1 ~ /^selftest-/ && $5 == w'
# The registry is read before the baseline is run. A mistyped id used to pay 95 s
# for nothing and then report twice -- once for the row it refused and once for
# having run none -- which is the double-report the selection order exists to
# avoid, arriving by the other door.
armed 'the registry is read before anything is copied or run' \
      "$MUT" '[ -n "$RUNNABLE" ] || {'
armed 'and a name that matches no row stops the run there' \
      "$MUT" 'if [ -n "$SELECTED" ] && [ "$MATCHED" = 0 ]; then'
armed 'an edit that leaves its target byte-identical is did-not-apply' \
      "$MUT" 'if cmp -s "$TARGET" "$WORK_ROOT/mutated"; then'
written 'and that is a failure rather than a pass, with the reason' \
        "$MUT" 'A MUTATION THAT DOES NOT APPLY IS A FAILURE'
armed 'an unmutated copy has to be green before any mutation is believed' \
      "$MUT" 'if [ "$BASELINE_STATUS" != 0 ] || [ "$(matrix_size "$RUN_OUT")" = 0 ]; then'
armed 'and the hooks directory is summed before and after the whole run' \
      "$MUT" 'if [ -n "$SUM_AFTER" ] && [ "$SUM_BEFORE" = "$SUM_AFTER" ]; then'
# The sum's own three holes, each one line and each in the permitting direction.
# Without -mindepth 1 `find` always emits `.`, so the guard on an empty listing
# could never fire; without %l a symlink repointed at another file in the tree
# left the sum where it was; and without -r on xargs a tree with no regular files
# ran sha256sum with no arguments, which reads stdin and succeeds. This is the
# harness's last line of defence on the files it is meant not to touch, and its
# guard was inert. Bertan's review of PR #142.
armed 'the sum reads every entry type, mode and symlink target, not only file contents' \
      "$MUT" "find . -mindepth 1 -printf '%y %m %P -> %l"
armed 'and hashes nothing when there is nothing to hash, rather than reading stdin' \
      "$MUT" 'xargs -0 -r sha256sum'
# A run that hangs is not a run that caught anything. Nothing in this suite bounds
# a hook it runs, so a mutation that left one looping would stop the harness
# rather than be reported by it.
armed 'and each run of this suite is bounded, a killed one printing no matrix' \
      "$MUT" 'timeout "$RUN_BOUND" env CHECK_HOOKS_DIR="$WORK" bash "$SUITE" --matrix'

# THE REGISTRY, held to this repository. Read out of the harness rather than
# listed again here: a row names a file, the requirement IDs whose checks must go
# red, and what the harness must then report.
MUT_ROWS=$(awk '/^MUTATIONS=\$\(cat <</ { f = 1; next }
                f && /^MUTATIONS$/ { exit }
                f' "$MUT")
[ -n "$MUT_ROWS" ] || {
  echo "no mutation rows were read out of mutate-hooks.sh; the checks below prove nothing" >&2
  exit 1
}
# A count, as a literal, for the reason every derived list here carries one: a
# heredoc whose marker moved would otherwise shorten this audit in silence. It
# moves when a mutation is registered, which is the edit it is here to make
# visible.
tok 'the registry holds as many mutations as this suite expects' \
    '63' "$(printf '%s\n' "$MUT_ROWS" | grep -c '%')"
MUT_BAD=
MUT_OUTCOMES=
while IFS='%' read -r MID MFILE MEDIT MREQS MWANT; do
  [ -n "$MID" ] || continue
  MUT_OUTCOMES="$MUT_OUTCOMES$MWANT
"
  [ -n "$MFILE" ] && [ -n "$MEDIT" ] && [ -n "$MREQS" ] && [ -n "$MWANT" ] \
    || { MUT_BAD="$MUT_BAD  $MID: the row does not split into five fields
"; continue; }
  case " $TOOLING " in *" $MFILE "*)
    MUT_BAD="$MUT_BAD  $MID: targets $MFILE, which the harness runs rather than judges
" ;; esac
  # A path INSIDE the hooks directory, asked of the table as written. An absolute
  # one, or one climbing out with .., names a file the copy does not hold and the
  # edit would land wherever it points. The harness refuses such a row itself;
  # this is the same question asked of the registry rather than of the run, so a
  # row of that shape is red here without anyone running it.
  case "$MFILE" in /*|*/../*|../*|*/..|..)
    MUT_BAD="$MUT_BAD  $MID: names $MFILE, which is not a path inside the hooks directory
" ;; esac
  [ -r "$HOOKS/$MFILE" ] || MUT_BAD="$MUT_BAD  $MID: names $MFILE, which is not a file in the hooks directory
"
  # A requirement that EXISTS AND IS ACTIVE. Asking only whether the heading is
  # there accepted `### FR-12`, which is retired, and `### FR-1`, which is
  # superseded -- both have entries, neither has a covering check, so a row
  # naming one would report `survived` on every run for ever and read as a defect
  # in the hooks rather than in the row. That is the case this audit's own
  # paragraph says it exists to prevent, and it did not ask it. Bertan's review
  # of PR #142. A `gap` is refused by the same rule and for the same reason: the
  # entry names the issue that owes it a check, so there is nothing to go red.
  for MR in $MREQS; do
    if ! grep -qx -- "### $MR" "$HOOKS/requirements.md"; then
      MUT_BAD="$MUT_BAD  $MID: names $MR, which requirements.md has no entry for
"
      continue
    fi
    MR_STATUS=$(awk -v h="### $MR" '
      $0 == h { f = 1; next }
      f && /^### / { exit }
      f && /^- status:/ { sub(/^- status:[ \t]*/, ""); print; exit }' "$HOOKS/requirements.md")
    case "${MR_STATUS%%[ :]*}" in
      active) ;;
      *) MUT_BAD="$MUT_BAD  $MID: names $MR, whose status is ${MR_STATUS%%[ :]*} rather than active, so no check covers it
" ;;
    esac
  done
done <<< "$MUT_ROWS"
if [ -z "$MUT_BAD" ]; then
  pass static 'every registered mutation names a file and requirements that exist'
else
  fail static 'a registered mutation names something that is not there:\n%s' \
    "$(printf '%s' "$MUT_BAD" | sed 's/^/       /')"
fi
# THE SELF-TESTS ARE REGISTERED, which is #107's acceptance criterion and the
# only thing that says the two words this harness reports are read off anything.
# One row whose edit matches nothing, one registered against a requirement its
# edit cannot reach, and every other row expecting to be caught.
tok 'one registered mutation is expected not to apply' \
    '1' "$(printf '%s' "$MUT_OUTCOMES" | grep -c '^did-not-apply$')"
tok 'and one is expected to survive, being registered against the wrong requirement' \
    '1' "$(printf '%s' "$MUT_OUTCOMES" | grep -c '^survived$')"
tok 'and every other registered mutation is expected to be caught' \
    '61' "$(printf '%s' "$MUT_OUTCOMES" | grep -c '^caught$')"

section "=== issue #108: what every hook decides when its environment is broken ==="
# #95 pinned the step where a hook reads its input. This is the step after it:
# what the hooks decide once the input has been read and the environment they
# read the ANSWER out of is not the ordinary one. #103's audit wrote the table --
# git off PATH, a directory that is no repository, a detached HEAD, no origin, no
# dev-NN ref or two of them, gh off PATH, and bytes in the command nobody meant
# to send -- and found some cells failing open, some closed, some by design and
# some by accident, with no check anywhere naming any of them.
#
# THE QUESTION THAT DECIDES WHETHER AN OPEN CELL IS A HOLE, asked of every row
# before any of this was written down: is there a case where the hook's read of
# the environment fails while the command would still reach a repository? Every
# such spelling -- `git -C`, `git --git-dir`, a `cd` or a `git checkout main`
# before the commit -- was driven under each environment below, and every one is
# refused, because those refusals are read off the text of the command and never
# off the environment. So the permits here are the cases where the command cannot
# run either, and that is what makes them safe to pin as intended rather than
# tolerated. They are pinned all the same: a hook that starts reading the
# environment for one of those decisions turns them red, which is the point.
#
# The fail direction is #103's Q19 and #95's, and one row needed it applied
# rather than recorded: report-stale-branches.sh exited 0 with no output at all
# when git was off PATH or it stood outside a repository. It now says why, and
# the argument is in its own header under IT NEVER EXITS WITHOUT SAYING WHY.
#
# Every environment here is a fixture this suite builds -- Q21 -- so nothing
# depends on the machine the suite is run on. The two PATH fixtures are the #95
# section's symlink farm with one tool removed, which is why this section stands
# below it.

# --- the environments, each built and then asserted to be what it claims ------
ENV_NO_GIT_BIN="$FIXTURES/path-without-git"
ENV_NO_GH_BIN="$FIXTURES/path-without-gh"
cp -a "$WITH_JQ_BIN" "$ENV_NO_GIT_BIN"
cp -a "$WITH_JQ_BIN" "$ENV_NO_GH_BIN"
rm -f "$ENV_NO_GIT_BIN/git"
rm -f "$ENV_NO_GH_BIN/gh"
# The same guard #95 puts on its jq-less twin, for the same reason: a hook that
# refuses under one of these might be refusing because the fixture is broken, and
# that refusal would read as the property being checked. What has to be true is
# that the tool cannot be found under $dir, and that $dir is otherwise the farm.
#
# HOW IT GOT THAT WAY USED TO DEPEND ON THE MACHINE, and no longer does. With the
# tool installed, the farm holds it, `rm` took it out, and the two directories
# differ by exactly that one name. WITHOUT it, the farm never held it, `rm -f`
# removed nothing, and the two were identical -- so the first version of this
# guard, demanding a one-name difference, aborted the whole suite on any machine
# with no `gh`, at this section, skipping every section below it including #104's
# coverage derivations. That is a dependence on the invoker's machine, which is
# the one thing #103's Q21 and this section's own preamble say there must not be,
# and the abort blamed the fixture for what was true of the machine. Found by
# Bertan's review of PR #150; reproduced by building a farm with no `gh` in it.
#
# The fix that answered that review tolerated the no-difference copy instead, and
# said so in a paragraph here. It ran everywhere, and it paid for that in the one
# currency this section deals in: on a machine with no `gh` the `gh`-less
# environment WAS the ordinary environment, so the GH-108.6 checks below asserted
# their verdicts twice rather than once and were evidence about `gh` on no such
# machine. #155 took the tolerance back out by removing what it tolerated. The
# farm is given a `gh` where it is built -- the host's, or a stub -- so the
# difference here is one name on every machine and this guard requires it
# unconditionally.
#
# WHICH TOOL MAY BE SYNTHESISED AND WHICH MAY NOT is argued in full where the stub
# is made, under GH IN THE FARM in the #95 section above; the short of it is that
# `gh` is a dependency of no hook, so a name is all the fixture wants of it, while
# `git` is a dependency of this suite, so a farm with no `git` is a machine this
# suite cannot run on and a fake one would answer the questions the hooks are
# judged on. `report-stale-branches.sh` is the only file in .claude/hooks/ that
# calls `gh` at all, and it degrades to `no gh on PATH` by design, which GH-108.10
# drives. The loop below is written for both tools because the RULE is the same --
# the farm minus exactly this one name -- and not because `git` could be stubbed
# to satisfy it.
for pair in "git:$ENV_NO_GIT_BIN" "gh:$ENV_NO_GH_BIN"; do
  tool=${pair%%:*}; dir=${pair#*:}
  # Asked separately from the difference below, because the two have different
  # causes and one message for both would misname either: a farm holding no `git`
  # is a machine without git, and a farm holding no `gh` is a stub that was not
  # made. Neither is the fixture being the wrong shape, which is what the second
  # message says.
  farm_has "$WITH_JQ_BIN" "$tool" || {
    echo "the symlink farm holds no $tool at all, so the $tool-less fixture is not it minus one name; the checks using it prove nothing" >&2
    exit 1
  }
  ! farm_has "$dir" "$tool" \
    && [ "$(diff <(ls -A "$WITH_JQ_BIN") <(ls -A "$dir") | grep '^[<>]')" = "< $tool" ] || {
    echo "the $tool-less PATH fixture is not the symlink farm minus $tool; the checks using it prove nothing" >&2
    exit 1
  }
done

echo "--- the farm's gh, which is what makes the fixture above machine-independent (#155) ---"
req GH-155.1
# The rule the guard above now rests on, asked of this machine AND of the machine
# this is not. What decides the fixture is whether the HOST's PATH held a `gh`:
# where it did there is nothing to synthesise, so a check that only looked at the
# farm as built would be green on any machine with `gh` installed and would say
# nothing whatever about the machine that found the defect. So that machine is
# built here -- the farm with `gh` taken out stands in for a PATH that never had
# one -- and the same synthesis is run against it. This is PR #150's manual
# reproduction, "reproduced by building a farm with no gh in it", written as a
# check instead of as a sentence in a comment.
#
# Every expectation is a literal, the stub's own line included: these read what
# the stub SAYS rather than asking the variable that wrote it, so an edit to that
# message is visible here rather than silently agreed with. The stub's line is
# pinned WHOLE and not by a leading fragment: a prefix goes on matching after the
# rest of the sentence has been deleted, which is how a `says` check comes to
# stand for less than its label claims.
#
# THE FARM BUILD CALLS THE SYNTHESIS, asked of the suite's text because on a host
# that HAS `gh` nothing can ask it of a run. The synthesis is a fallback, so with
# the host providing a `gh` its call is a no-op and deleting that one line leaves
# every other check here green while the machine-independence goes back to being
# an accident of the invoker's PATH. That is the direction #84 was filed in, one
# level out again.
#
# Read from the RANGE the farm is built in rather than from the whole file: a
# literal asserted of the file would match this check's own argument and pass with
# the call gone. `holds` fails on text it could not read, so an anchor that moves
# is red rather than vacuous.
FARM_BUILD=$(sed -n '/^WITH_JQ_BIN=/,/^cp -a /p' "$SUITE_DIR/check-hooks.sh" \
             | sed 's/[[:space:]]*#.*$//')
holds 'the farm build calls the synthesis, which a host with its own gh cannot show by running' \
      "$FARM_BUILD" 'farm_stub_gh "$WITH_JQ_BIN"'
tok 'the symlink farm holds a gh, so the gh-less fixture is one name short of it' \
    'gh' "$(farm_has "$WITH_JQ_BIN" gh && echo gh)"
FARM_HOST_HAD_NO_GH="$FIXTURES/farm-from-a-host-with-no-gh"
cp -a "$WITH_JQ_BIN" "$FARM_HOST_HAD_NO_GH"
rm -f "$FARM_HOST_HAD_NO_GH/gh"
tok 'a farm built from a host with no gh on PATH holds none to begin with' \
    '' "$(farm_has "$FARM_HOST_HAD_NO_GH" gh && echo gh)"
farm_stub_gh "$FARM_HOST_HAD_NO_GH"
tok 'and the synthesis gives it one' \
    'gh' "$(farm_has "$FARM_HOST_HAD_NO_GH" gh && echo gh)"
FARM_HOST_HAD_NO_GH_MINUS_GH="$FIXTURES/farm-from-a-host-with-no-gh-minus-gh"
cp -a "$FARM_HOST_HAD_NO_GH" "$FARM_HOST_HAD_NO_GH_MINUS_GH"
rm -f "$FARM_HOST_HAD_NO_GH_MINUS_GH/gh"
tok 'so on that machine too the gh-less copy differs from the farm by one name' \
    '< gh' "$(diff <(ls -A "$FARM_HOST_HAD_NO_GH") <(ls -A "$FARM_HOST_HAD_NO_GH_MINUS_GH") | grep '^[<>]')"
# What the stub does when something runs it, which nothing under the farm's PATH
# does. The status and the sentence are asked separately: a stub that printed the
# right line and exited 0 would be the silent permit this section is about,
# arriving through the fixture instead of through a hook.
#
# THE ARGUMENTS ARE `--version` AND NOT `pr merge 5`, and that is not cosmetic.
# The stub ignores argv entirely, so any arguments establish the same two things
# -- and these two lines, with the marker `gh` under this same requirement beside
# the report's own run further down, are the whole of what RUNS a `gh` in this
# suite rather than handing its text to a hook. What they rest on is that PATH
# names one directory holding a stub. Were that ever wrong, `gh --version`
# against a real gh exits 0 and prints no such sentence, so both checks go red;
# `gh pr merge 5` would have merged a pull request. The repository's own lesson
# is that a command run to learn something once created a real release.
tok 'the stub refuses rather than answering for gh' \
    '1' "$( PATH="$FARM_HOST_HAD_NO_GH"; gh --version >/dev/null 2>&1; echo $? )"
holds 'and names the fixture it is, so a check that came to depend on it says so' \
      "$( PATH="$FARM_HOST_HAD_NO_GH"; gh --version 2>&1 >/dev/null )" \
      'gh: check-hooks.sh PATH-fixture stub, a name and not a program (GH-155.1)'
# And it never stands in for a `gh` the host provided. Where the host has one the
# farm holds the host's, so the fixture is still the invoker's PATH -- which is
# what #95 builds the farm for, and the reason the synthesis is a fallback rather
# than an override. The marker in this fixture's `gh` is how the check tells the
# two apart; a stub that overwrote it would print the stub's line instead.
FARM_HOST_HAD_A_GH="$FIXTURES/farm-from-a-host-with-gh"
cp -a "$FARM_HOST_HAD_NO_GH_MINUS_GH" "$FARM_HOST_HAD_A_GH"
# THE SAME UNLINK, AND THE SAME REASON as the one inside the synthesis: `>` on a
# farm entry writes THROUGH the symlink and truncates the host binary it points
# at. This copy is taken from a farm that has already had `gh` removed, so there
# is no link here to write through -- but that is a property of the line above,
# and naming a different source there would turn the next line into the hazard
# the synthesis carries a paragraph about. The unlink makes it safe by
# construction rather than by which directory was copied.
rm -f "$FARM_HOST_HAD_A_GH/gh"
printf '#!/bin/bash\necho the-host-gh\n' > "$FARM_HOST_HAD_A_GH/gh"
chmod +x "$FARM_HOST_HAD_A_GH/gh"
farm_stub_gh "$FARM_HOST_HAD_A_GH"
tok 'a farm whose host had a gh keeps the one it had' \
    'the-host-gh' "$( PATH="$FARM_HOST_HAD_A_GH"; gh )"

# WHAT DECIDES THE SYNTHESIS IS THE DIRECTORY AND NOT THE CALLING SHELL, and the
# machine that tells those two apart is one whose environment exports a `gh`
# function -- a wrapper in a login profile, which bash hands to a script like
# this one as `BASH_FUNC_gh%%`. `command -v` resolves a function ahead of PATH,
# so the test this used to make read a `gh` the farm did not hold: no stub was
# written, and the guard above, which this branch made unconditional, aborted
# the whole suite. #155's own failure shape, arriving by a route nothing was
# asking about until PR #161 was reviewed.
#
# The function is defined and EXPORTED here because exporting is what puts it in
# reach of the subshell the old test used, and it is unset on the next line: a
# `gh` function left standing would be run by the checks above, which execute the
# stub, in place of the file they are about.
FARM_UNDER_A_GH_FUNCTION="$FIXTURES/farm-under-a-shell-that-defines-gh"
cp -a "$FARM_HOST_HAD_NO_GH_MINUS_GH" "$FARM_UNDER_A_GH_FUNCTION"
gh() { echo "a wrapper function in the invoker's environment, not a program in the farm"; }
export -f gh
farm_stub_gh "$FARM_UNDER_A_GH_FUNCTION"
unset -f gh
tok 'a gh the calling shell defines is not a gh in the farm, so the stub is written anyway' \
    'gh' "$(farm_has "$FARM_UNDER_A_GH_FUNCTION" gh && echo gh)"
# AND THE GUARD ASKS IT THE SAME WAY. The synthesis and the fixture guard are one
# rule read twice, so a `command -v` left in the guard is the same abort with the
# stub written: a `gh` function resolves under the `gh`-less PATH too, and the
# one-name difference the guard demands reads as absent. Asked of the suite's
# text because a guard whose failure is `exit 1` cannot be driven from inside the
# run it would end. `lacks` fails on text it could not read, so a range anchor
# that moves is red rather than vacuously green.
FARM_GUARD=$(sed -n '/^for pair in "git:\$ENV_NO_GIT_BIN"/,/^done$/p' "$SUITE_DIR/check-hooks.sh" \
             | sed 's/[[:space:]]*#.*$//')
holds 'the gh-less fixture guard asks the directory whether the farm holds the name' \
      "$FARM_GUARD" 'farm_has "$WITH_JQ_BIN" "$tool"'
lacks 'and asks the calling shell nothing, which would resolve a function ahead of PATH' \
      "$FARM_GUARD" 'command -v'

ENV_REPOS="$FIXTURES/env"
mkdir -p "$ENV_REPOS"
GE="-c user.email=checks@example.invalid -c user.name=checks"
# A directory that is no repository. Nothing is created in it on purpose: the
# absence is the fixture.
ENV_NOREPO="$ENV_REPOS/not-a-repository"
mkdir -p "$ENV_NOREPO"
# The control. An ordinary branch, an origin, one commit -- the environment the
# other five differ from in one named way each.
ENV_PLAIN="$ENV_REPOS/plain"
git init -q -b feature-x "$ENV_PLAIN"
git -C "$ENV_PLAIN" remote add origin "$FIXTURES/unreachable-remote.git"
git -C "$ENV_PLAIN" $GE commit -q --allow-empty -m base
# A detached HEAD: two commits, so detaching leaves a real one checked out.
ENV_DETACHED="$ENV_REPOS/detached-head"
git init -q -b feature-x "$ENV_DETACHED"
git -C "$ENV_DETACHED" remote add origin "$FIXTURES/unreachable-remote.git"
git -C "$ENV_DETACHED" $GE commit -q --allow-empty -m base
git -C "$ENV_DETACHED" $GE commit -q --allow-empty -m second
git -C "$ENV_DETACHED" checkout -q --detach HEAD
# No remote at all.
ENV_NO_ORIGIN="$ENV_REPOS/no-origin"
git init -q -b feature-x "$ENV_NO_ORIGIN"
git -C "$ENV_NO_ORIGIN" $GE commit -q --allow-empty -m base

# THE TWO DEV-REF FIXTURES, each a lifecycle repository in the shape the
# no-work-on-stale-branch.sh section builds: a stale worktree branch at base and
# a merged one whose upstream is gone. They differ from that one in how many
# origin/dev-NN refs stand over them -- none, and two -- which is the pair of
# cells #103's audit left unpinned.
#
# In the two-ref fixture dev-05 sits at base and dev-06 at the tip, so the two
# refs disagree about the stale branch: against dev-06 it is behind and stale,
# against dev-05 it is level and clear. A refusal there is evidence that the
# HIGHEST was taken, and the message names which. A fixture with both refs at the
# tip would refuse whichever was chosen and would be evidence about neither.
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
ENV_DEV_NONE="$ENV_REPOS/no-dev-ref"
ENV_DEV_TWO="$ENV_REPOS/two-dev-refs"
env_lifecycle "$ENV_DEV_NONE"
env_lifecycle "$ENV_DEV_TWO" dev-05:base dev-06:tip

# Each fixture asserted to be the thing its name claims, because every verdict
# below is read as evidence about that one difference. An unbuilt worktree or a
# HEAD that is still on a branch would leave a column of permits that read as the
# hooks abstaining when what abstained was the fixture.
[ -d "$ENV_PLAIN/.git" ] && [ -d "$ENV_NO_ORIGIN/.git" ] \
  && [ ! -e "$ENV_NOREPO/.git" ] \
  && [ -z "$(git -C "$ENV_DETACHED" branch --show-current)" ] \
  && [ "$(git -C "$ENV_PLAIN" branch --show-current)" = feature-x ] \
  && [ -z "$(git -C "$ENV_NO_ORIGIN" remote)" ] \
  && [ "$(git -C "$ENV_PLAIN" remote)" = origin ] \
  && [ -z "$(git -C "$ENV_DEV_NONE" for-each-ref --format='%(refname:short)' 'refs/remotes/origin/dev-*')" ] \
  && [ "$(git -C "$ENV_DEV_TWO" for-each-ref --format='%(refname:short)' 'refs/remotes/origin/dev-*' | sort -V | tr '\n' ' ')" = 'origin/dev-05 origin/dev-06 ' ] \
  && [ -d "$ENV_DEV_NONE/wt-stale" ] && [ -d "$ENV_DEV_NONE/wt-gone" ] \
  && [ -d "$ENV_DEV_TWO/wt-stale" ] && [ -d "$ENV_DEV_TWO/wt-gone" ] || {
  echo "the #108 environment fixtures are not what they claim; every verdict below would be evidence about the fixture" >&2
  exit 1
}
# AND THAT THE TWO REFS DISAGREE, asked separately because it is the whole of
# what makes a two-ref verdict evidence about WHICH ref was chosen rather than
# about there being one. dev-05 stands level with the stale branch and dev-06 one
# commit ahead of it, so a hook reading the lower ref calls that branch clear and
# one reading the higher calls it stale. With both at the tip the branch is stale
# either way, every check below still passes, and the mutation registered against
# this fixture -- sort -V | tail -1 replaced by sort | head -1 -- survives.
[ "$(git -C "$ENV_DEV_TWO" rev-parse refs/remotes/origin/dev-05)" \
  = "$(git -C "$ENV_DEV_TWO" rev-parse refs/heads/stale-branch)" ] \
  && [ "$(git -C "$ENV_DEV_TWO" rev-parse refs/remotes/origin/dev-06)" \
       != "$(git -C "$ENV_DEV_TWO" rev-parse refs/heads/stale-branch)" ] || {
  echo "the two dev refs do not disagree about the stale branch, so no verdict below says which was taken" >&2
  exit 1
}
# AND THAT THE NO-REF FIXTURE'S STALE BRANCH IS ACTUALLY BEHIND. Its permit is
# read as the fallback detector abstaining for want of a dev ref; a branch level
# with the tip would be permitted by a hook reading every ref there is, and the
# check could not tell the two apart. Asked of the branches rather than of the
# refs, because there are no refs over there to ask.
[ "$(GIT_DIR="$ENV_DEV_NONE/.git" git rev-list --count refs/heads/stale-branch..refs/heads/gone-branch)" = 1 ] || {
  echo "the no-dev-ref fixture's stale branch is not one commit behind, so its permit would not be the abstention it is read as" >&2
  exit 1
}

# env_feed, env_cmd and env_says are defined beside feed and feed_says above,
# with the reason they are not here: the #98 self-test drives every helper that
# reads a hook's exit status, and it runs long before this section.

echo "--- no hook reads tool_name: the matcher in settings.json is what filters ---"
# The row the audit wrote as "hooks ignore it". It is pinned in both directions
# and on both fields, so a tool_name test added to any hook -- the obvious way to
# make a hook "safer" that would in fact give the registration a second place to
# disagree with itself -- turns these red.
req GH-108.1
env_feed "$ENV_PLAIN" "$PATH" no-git-push.sh BLOCK 'a force push under tool_name Read is still a force push' \
  '{"tool_name":"Read","tool_input":{"command":"git push --force origin main"}}'
env_feed "$ENV_PLAIN" "$PATH" no-git-push.sh BLOCK 'a force push under no tool_name at all' \
  '{"tool_input":{"command":"git push --force origin main"}}'
env_feed "$ENV_PLAIN" "$PATH" no-pr-decisions.sh BLOCK 'gh pr merge under tool_name Edit' \
  '{"tool_name":"Edit","tool_input":{"command":"gh pr merge 5"}}'
env_feed "$ENV_PLAIN" "$PATH" no-commit-to-main.sh BLOCK 'a push to main under tool_name Write' \
  '{"tool_name":"Write","tool_input":{"command":"git push origin main"}}'
env_feed "$ENV_PLAIN" "$PATH" no-git-push.sh ALLOW 'ls under tool_name Read is still ls' \
  '{"tool_name":"Read","tool_input":{"command":"ls"}}'
env_feed "$ENV_PLAIN" "$PATH" no-pr-decisions.sh ALLOW 'gh issue list under a tool_name that is not Bash' \
  '{"tool_name":"WebFetch","tool_input":{"command":"gh issue list"}}'
# The Edit hook reads a different field, and is as indifferent to tool_name.
env_feed "$ENV_PLAIN" "$PATH" append-only-docs-edit.sh BLOCK 'an edit of a dev-log entry under tool_name Bash' \
  "$(printf '{"tool_name":"Bash","tool_input":{"file_path":"%s/docs/dev-log/devlog_2026-08-25_session-2.md"}}' "$REPO_ROOT")"
env_feed "$ENV_PLAIN" "$PATH" append-only-docs-edit.sh ALLOW 'an edit outside the guarded directories under tool_name Bash' \
  "$(printf '{"tool_name":"Bash","tool_input":{"file_path":"%s/src/config.py"}}' "$REPO_ROOT")"

echo "--- git off PATH, and a directory that is no repository ---"
# Both environments in one block because the hooks cannot tell them apart: each
# makes every `git rev-parse` and `git branch --show-current` come back empty,
# which is the whole of what the hooks read.
req GH-108.2
for env in "git off PATH:$ENV_PLAIN:$ENV_NO_GIT_BIN" "no repository:$ENV_NOREPO:$PATH"; do
  name=${env%%:*}; rest=${env#*:}; dir=${rest%%:*}; path=${rest#*:}
  env_cmd "$dir" "$path" no-git-push.sh BLOCK "$name: a force push to main is refused" \
    'git push --force origin main'
  env_cmd "$dir" "$path" no-commit-to-main.sh BLOCK "$name: a push naming main is refused" \
    'git push origin main'
  # The worktree exception cannot be verified without git, so it is not granted.
  # This is the fail direction chosen rather than found: the same command is
  # permitted in a linked worktree with git on PATH, and the #94 section is where.
  env_cmd "$dir" "$path" no-git-push.sh BLOCK "$name: a push of an ordinary branch is refused too" \
    'git push origin wt-branch'
  env_says "$dir" "$path" no-git-push.sh 'linked worktree' "$name: and the refusal says what it could not judge" \
    'git push origin wt-branch'
  # Every spelling that reaches another repository, which is the class that would
  # be a hole if it depended on the environment. It does not: these refusals are
  # read off the command's text.
  env_cmd "$dir" "$path" no-commit-to-main.sh BLOCK "$name: git -C elsewhere commit" \
    'git -C /elsewhere/repo commit -m "wip"'
  env_cmd "$dir" "$path" no-commit-to-main.sh BLOCK "$name: git --git-dir elsewhere commit" \
    'git --git-dir /elsewhere/repo/.git commit -m "wip"'
  env_cmd "$dir" "$path" no-commit-to-main.sh BLOCK "$name: cd elsewhere before the commit" \
    'cd /elsewhere/repo && git commit -m "wip"'
  env_cmd "$dir" "$path" no-commit-to-main.sh BLOCK "$name: git checkout main before the commit" \
    'git checkout main && git commit -m "wip"'
  # The permitting direction. A commit that names no reserved branch and no other
  # repository is permitted, and so is everything that is not a git command: the
  # environments that produce these permits are the ones where the command cannot
  # run either.
  env_cmd "$dir" "$path" no-commit-to-main.sh ALLOW "$name: a plain commit names no branch and is permitted" \
    'git commit -m "wip"'
  env_cmd "$dir" "$path" no-work-on-stale-branch.sh ALLOW "$name: the stale guard abstains, having no ref to read" \
    'git commit -m "wip"'
  env_cmd "$dir" "$path" no-git-push.sh ALLOW "$name: a command with no push in it" \
    'ls -la'
done

echo "--- a detached HEAD: the one permit here that is the answer the boundary wants ---"
# A commit on a detached HEAD lands on no branch, so it cannot land on main --
# which is what no-commit-to-main.sh exists to stop. The design is stated at
# CURRENT in no-work-on-stale-branch.sh, in as many words.
req GH-108.3
env_cmd "$ENV_DETACHED" "$PATH" no-git-push.sh BLOCK 'a force push from a detached HEAD is refused' \
  'git push --force origin main'
env_cmd "$ENV_DETACHED" "$PATH" no-commit-to-main.sh BLOCK 'a push naming main from a detached HEAD is refused' \
  'git push origin main'
env_cmd "$ENV_DETACHED" "$PATH" no-commit-to-main.sh ALLOW 'a commit on a detached HEAD lands on no branch' \
  'git commit -m "wip"'
env_cmd "$ENV_DETACHED" "$PATH" no-work-on-stale-branch.sh ALLOW 'neither staleness detector has a branch to read' \
  'git commit -m "wip"'
written 'the detached-HEAD design is stated where the hook reads the branch' \
  "$HOOKS/no-work-on-stale-branch.sh" \
  'A detached HEAD has no branch, so neither detector has anything to read.'

echo "--- no remote named origin ---"
req GH-108.4
env_cmd "$ENV_NO_ORIGIN" "$PATH" no-git-push.sh BLOCK 'a push naming origin, which is no remote of this repository' \
  'git push origin feature-x'
env_cmd "$ENV_NO_ORIGIN" "$PATH" no-git-push.sh BLOCK 'a force push is refused with no remote to push to' \
  'git push --force origin main'
env_cmd "$ENV_NO_ORIGIN" "$PATH" no-work-on-stale-branch.sh ALLOW 'the stale guard abstains: removing a remote removes its refs' \
  'git commit -m "wip"'
env_cmd "$ENV_NO_ORIGIN" "$PATH" no-commit-to-main.sh ALLOW 'a commit on an ordinary branch is permitted' \
  'git commit -m "wip"'

echo "--- no origin/dev-NN ref at all, and two of them ---"
# The fallback detector needs a dev ref and abstains without one; the gone
# detector needs none and refuses anyway. With two refs the highest by version
# sort is the active dev branch, and this fixture's two disagree about the stale
# branch so that the refusal names which one was taken.
req GH-108.5
env_cmd "$ENV_DEV_NONE/wt-stale" "$PATH" no-work-on-stale-branch.sh ALLOW 'no dev ref: the fallback detector abstains' \
  'git commit -m "wip"'
env_cmd "$ENV_DEV_NONE/wt-gone" "$PATH" no-work-on-stale-branch.sh BLOCK 'no dev ref: the gone detector refuses anyway' \
  'git commit -m "wip"'
env_says "$ENV_DEV_NONE/wt-gone" "$PATH" no-work-on-stale-branch.sh 'the active dev branch' \
  'no dev ref: and the refusal names no branch it could not find' \
  'git commit -m "wip"'
env_cmd "$ENV_DEV_TWO/wt-stale" "$PATH" no-work-on-stale-branch.sh BLOCK 'two dev refs: stale against the higher one' \
  'git commit -m "wip"'
env_says "$ENV_DEV_TWO/wt-stale" "$PATH" no-work-on-stale-branch.sh 'origin/dev-06' \
  'two dev refs: and the refusal names dev-06, the highest by version sort' \
  'git commit -m "wip"'
env_cmd "$ENV_DEV_TWO/wt-gone" "$PATH" no-work-on-stale-branch.sh BLOCK 'two dev refs: the gone detector is unaffected' \
  'git commit -m "wip"'
# no-pr-decisions.sh reads no git at all, so the base rule is a pattern and not a
# lookup: a dev-NN base is accepted whatever refs origin holds, and a base that
# is not dev-NN is refused for the same reason.
env_cmd "$ENV_DEV_NONE" "$PATH" no-pr-decisions.sh BLOCK 'a base of main is refused where origin holds no dev ref' \
  'gh pr create --base main --title t --body b'
env_cmd "$ENV_DEV_NONE" "$PATH" no-pr-decisions.sh ALLOW 'a dev-NN base is accepted where origin holds no dev ref' \
  'gh pr create --base dev-05 --title t --body b'
# THE GAP, at its measured verdict and named as one. dev-06 is the active dev
# branch in this fixture -- the check above reads the refusal that says so -- and
# a pull request based on dev-05 is permitted all the same. CLAUDE.md says "into
# the active dev branch", so this permits something the boundary refuses, and it
# is filed as #144, a sub-issue of #36, rather than fixed here: the fix is to have
# this one hook read refs, and a hook that reads refs fails open when it cannot,
# which is the failure mode this whole section exists to pin. The window is a
# rotation. The verdict below is the measured one and not the correct one, which
# is the one place this section departs from #103's Q18 -- so the fix turns this
# check red, and the check names the issue that owns it.
env_cmd "$ENV_DEV_TWO" "$PATH" no-pr-decisions.sh ALLOW 'ACCEPTED GAP: a base of dev-05 while dev-06 is the active dev branch' \
  'gh pr create --base dev-05 --title t --body b'

echo "--- gh off PATH, and every other environment: the pull request hook starts no process ---"
# It runs no git and no gh, so its verdict is a function of the command's text
# alone. That is checked as the property rather than as one absence: the same two
# payloads under every environment of this section.
#
# THE FARM IS THE ROW THAT MAKES THE GH-LESS ROW EVIDENCE, and `plain` cannot be
# it. `plain` is the invoker's PATH, so on a host with no `gh` it is itself a
# `gh`-less environment and the pair asserted the same thing twice -- which is
# what #155 was filed about and what the stub alone does not fix. The farm always
# holds a `gh`, the row below it is the farm minus that one name, and the contrast
# between the two is therefore a genuine one-name contrast on every machine.
# `plain` stays, because what it asks is the other question: that the invoker's
# own PATH, whatever is on it, moves no verdict either.
req GH-108.6
for env in "plain:$ENV_PLAIN:$PATH" "the farm, gh on PATH:$ENV_PLAIN:$WITH_JQ_BIN" \
           "gh off PATH:$ENV_PLAIN:$ENV_NO_GH_BIN" \
           "git off PATH:$ENV_PLAIN:$ENV_NO_GIT_BIN" "no repository:$ENV_NOREPO:$PATH" \
           "detached HEAD:$ENV_DETACHED:$PATH" "no origin:$ENV_NO_ORIGIN:$PATH" \
           "no dev ref:$ENV_DEV_NONE:$PATH" "two dev refs:$ENV_DEV_TWO:$PATH"; do
  name=${env%%:*}; rest=${env#*:}; dir=${rest%%:*}; path=${rest#*:}
  env_cmd "$dir" "$path" no-pr-decisions.sh BLOCK "$name: gh pr merge is refused" \
    'gh pr merge 5'
  env_cmd "$dir" "$path" no-pr-decisions.sh ALLOW "$name: gh issue list is permitted" \
    'gh issue list'
done
# "WORD FOR WORD" IS ASKED AS A COMPARISON, which it was not. What stood here was
# one `env_says` against the `gh`-less PATH, and `env_says` matches a FRAGMENT --
# so the label claimed the two refusals were identical while the check read three
# words of one of them and never read the other at all. Two refusals differing in
# every other word passed it. That is the defect this same section argues against
# a hundred lines up, where the stub's sentence is pinned whole.
#
# Three checks, because the claim has three parts. Each side is pinned to the
# refusal WHOLE, as a literal written from no-pr-decisions.sh rather than derived
# from a run; then the two runs are read and compared to each other, which is the
# only part that cannot be a literal because it is an equality between two
# measurements. The `gh`-on-PATH side is the farm and not the invoker's PATH, for
# the reason the loop above gives (#155).
env_stderr() {  # env_stderr <dir> <PATH> <script> <command> -- what the hook said
  local dir="$1" path="$2" script="$3" cmd="$4" hook
  hook=$(hook_path "$script")
  printf '%s' "$cmd" | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' \
    | ( cd "$dir" && PATH="$path" CLAUDE_PROJECT_DIR="$REPO_ROOT" "$hook" ) 2>&1 >/dev/null
}
PR_MERGE_REFUSAL="Blocked: deciding a pull request is Bertan's call, not an agent's. Opening a PR, commenting on it and editing it are allowed; accepting, rejecting, merging and reopening are not. Leave the PR open and say it is ready to merge."
env_says "$ENV_PLAIN" "$WITH_JQ_BIN" no-pr-decisions.sh "$PR_MERGE_REFUSAL" \
  'gh on PATH: the whole refusal, and it is this one the gh-less side is held to' \
  'gh pr merge 5'
env_says "$ENV_PLAIN" "$ENV_NO_GH_BIN" no-pr-decisions.sh "$PR_MERGE_REFUSAL" \
  'gh off PATH: the whole refusal again, not a fragment of it' \
  'gh pr merge 5'
GH_ON_SAID=$(env_stderr "$ENV_PLAIN" "$WITH_JQ_BIN" no-pr-decisions.sh 'gh pr merge 5')
GH_OFF_SAID=$(env_stderr "$ENV_PLAIN" "$ENV_NO_GH_BIN" no-pr-decisions.sh 'gh pr merge 5')
# Asked before the equality, for the reason `lacks` gives about absences: two
# hooks that crashed saying nothing compare equal, which is this check passing on
# the case it exists to catch.
tok 'both refusals were read, so what follows compares two texts and not two silences' \
    'read' "$( [ -n "$GH_ON_SAID" ] && [ -n "$GH_OFF_SAID" ] && echo read )"
tok 'and the two are word for word the same, which neither fragment above asks' \
    "$GH_ON_SAID" "$GH_OFF_SAID"

echo "--- bytes in the command nobody meant to send ---"
# A CRLF, a non-ASCII byte and an invalid UTF-8 sequence leave the verdict where
# it was. A NUL and a non-breaking space do not, and the pair is pinned with the
# mechanism rather than only the verdict: the NUL is STRIPPED by the command
# substitution that reads it, so what decides is whether stripping it joins two
# words. On one line it fuses `ls` and `git` into `lsgit` and the push is hidden;
# after a newline it fuses nothing and the push is refused as it always was.
#
# Both permits are accepted. Neither byte is whitespace to a shell -- `git<NBSP>push`
# is one word and there is no executable of that name -- and a NUL cannot survive
# the exec that would start the command, which truncates the string at it. So
# what is hidden from the hook is not a command that would have run.
#
# THE NUL IS SPELLED \u0000 AND NEVER EMBEDDED, and that is not a style choice.
# The first draft of this section carried the byte itself, and a NUL anywhere in
# this file makes GNU grep call the whole of it binary: `grep -o` then prints
# nothing, and READ_DOCS in the header section above -- a derivation that reads
# this suite's own text -- came back empty, which turned two of its checks red
# for a reason nowhere near them. Four other derivations read this file the same
# way. So every payload here that carries a byte outside ASCII is written as a
# JSON escape and jq does the decoding, which is also how the harness would
# deliver one: a tool call is JSON. For the NUL that is forced, since the byte
# cannot sit in this file at all. For the others -- the non-breaking space, the
# e-acute -- it is uniformity, so that the rule belongs to the section and not to
# one payload; an earlier draft embedded those two and left this paragraph
# claiming something true of the NUL alone. The one exception cannot be written
# as an escape: an invalid UTF-8 sequence is by definition not a character, so
# its payload is built with printf and carries the two bytes raw.
#
# It happened here more than once, this very paragraph included, whose first
# draft spelled the escape and embedded the byte instead -- and no count is
# written down, because the count is the part that goes stale and the shape is
# what matters. Nothing ever said NUL. What went red was two checks in the header
# section about names in a paragraph, four hundred lines away, and in the
# permitting direction for everything else that reads this file the same way. The
# cause is not carelessness: the escape travels through a JSON tool call, which
# decodes it once before it reaches the file, so spelling it and embedding it are
# the same keystrokes. That is the whole reason it is written down here rather
# than fixed quietly.
req GH-108.7
env_feed "$ENV_PLAIN" "$PATH" no-git-push.sh BLOCK 'a CRLF line ending does not hide the push' \
  '{"tool_name":"Bash","tool_input":{"command":"ls\r\ngit push --force origin main\r\n"}}'
env_feed "$ENV_PLAIN" "$PATH" no-git-push.sh BLOCK 'a carriage return at the end of the line' \
  '{"tool_name":"Bash","tool_input":{"command":"git push --force origin main\r"}}'
env_feed "$ENV_PLAIN" "$PATH" no-git-push.sh BLOCK 'a non-ASCII byte trailing the command' \
  '{"tool_name":"Bash","tool_input":{"command":"git push --force origin main \u00e9"}}'
env_feed "$ENV_PLAIN" "$PATH" no-commit-to-main.sh BLOCK 'a CRLF line ending, asked of the commit hook' \
  '{"tool_name":"Bash","tool_input":{"command":"ls\r\ngit push origin main\r\n"}}'
env_feed "$ENV_PLAIN" "$PATH" no-pr-decisions.sh BLOCK 'a CRLF line ending, asked of the pull request hook' \
  '{"tool_name":"Bash","tool_input":{"command":"ls\r\ngh pr merge 5\r\n"}}'
# Invalid UTF-8 cannot be written as a JSON escape, so the payload is built with
# printf and carries the two bytes raw. jq reads them; the suite's own source
# stays ASCII.
env_feed "$ENV_PLAIN" "$PATH" no-git-push.sh BLOCK 'an invalid UTF-8 sequence trailing the command' \
  "$(printf '{"tool_name":"Bash","tool_input":{"command":"git push --force origin main \377\376"}}')"
env_feed "$ENV_PLAIN" "$PATH" no-git-push.sh ALLOW 'the same invalid sequence on a command that is not a push' \
  "$(printf '{"tool_name":"Bash","tool_input":{"command":"ls \377\376"}}')"
env_feed "$ENV_PLAIN" "$PATH" no-git-push.sh BLOCK 'a NUL after a newline fuses nothing, and the push is refused' \
  '{"tool_name":"Bash","tool_input":{"command":"ls\n\u0000git push --force origin main"}}'
env_feed "$ENV_PLAIN" "$PATH" no-git-push.sh ALLOW 'ACCEPTED: a NUL on the line fuses lsgit, hiding a push that could not run' \
  '{"tool_name":"Bash","tool_input":{"command":"ls\u0000git push --force origin main"}}'
env_feed "$ENV_PLAIN" "$PATH" no-git-push.sh ALLOW 'ACCEPTED: a non-breaking space makes one word of git push' \
  '{"tool_name":"Bash","tool_input":{"command":"git\u00a0push --force origin main"}}'
env_feed "$ENV_PLAIN" "$PATH" no-pr-decisions.sh ALLOW 'ACCEPTED: the same two bytes, asked of the pull request hook' \
  '{"tool_name":"Bash","tool_input":{"command":"gh\u00a0pr merge 5"}}'

echo "--- every hook exits 0 or 2, in every environment and on every payload here ---"
# #98 made the suite read a third status as FAIL rather than as ALLOW. This asks
# the other half: that no case in this section produces one. A crash is what a
# third status means, and a hook that crashes on a payload the harness can send
# is a hook that is not there for that payload.
#
# One check per hook over the cross product, with the number of cases written out
# as a literal: a sweep that quietly stopped covering an environment would
# otherwise report the same ok line. The payloads include the malformed ones,
# because #95 fixed the verdict on those and said nothing about the status.
#
# THE CROSS PRODUCT IS THE WHOLE TABLE, which took a second pass to be true.
# The first version drove eight environments against seven payloads and called
# that the table. It left out three of the four byte classes of the row above --
# the CRLF, the non-ASCII byte and the invalid UTF-8 sequence, all three driven
# for their VERDICT a few lines up and none of them for their status -- and both
# merged worktrees, which is where the two dev-ref rows read their refusing
# verdicts. So the environments a hook was asked for a verdict in and the ones it
# was asked for a status in were different sets, and nothing showed it, because
# the count matched a literal written to match it. That is this section's own
# shape, found here by review rather than by the suite. Eleven environments
# against ten payloads now, and the rule the first version should have been
# written to: a case driven anywhere in this section is driven here. The eleventh
# is the symlink farm, which #155 added to the row above as the `gh`-on-PATH twin
# of the `gh`-less one; it is here because of that rule and not for a reason of
# its own.
ENV_STATUS_CASES="plain:$ENV_PLAIN:$PATH
the farm, gh on PATH:$ENV_PLAIN:$WITH_JQ_BIN
git off PATH:$ENV_PLAIN:$ENV_NO_GIT_BIN
gh off PATH:$ENV_PLAIN:$ENV_NO_GH_BIN
no repository:$ENV_NOREPO:$PATH
detached HEAD:$ENV_DETACHED:$PATH
no origin:$ENV_NO_ORIGIN:$PATH
no dev ref:$ENV_DEV_NONE/wt-stale:$PATH
no dev ref, merged branch:$ENV_DEV_NONE/wt-gone:$PATH
two dev refs:$ENV_DEV_TWO/wt-stale:$PATH
two dev refs, merged branch:$ENV_DEV_TWO/wt-gone:$PATH"
ENV_STATUS_PAYLOADS=(
  '{"tool_name":"Bash","tool_input":{"command":"git push --force origin main"}}'
  '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
  '{"tool_name":"Edit","tool_input":{"file_path":"docs/dev-log/devlog_2026-08-25_session-2.md"}}'
  'not json at all'
  '{"tool_name":"Bash","tool_input":{"command":42}}'
  '{"tool_name":"Bash","tool_input":{"command":"ls\u0000git push --force origin main"}}'
  '{"tool_name":"Nonesuch","tool_input":{"command":"gh pr merge 5"}}'
  '{"tool_name":"Bash","tool_input":{"command":"ls\r\ngit push --force origin main\r\n"}}'
  '{"tool_name":"Bash","tool_input":{"command":"git push --force origin main \u00e9"}}'
  "$(printf '{"tool_name":"Bash","tool_input":{"command":"git push --force origin main \377\376"}}')"
)
ENV_STATUS_EXPECTED=110
req GH-108.8
for hook in $INPUT_BASH_HOOKS $INPUT_EDIT_HOOKS; do
  bad= ; n=0
  while IFS= read -r env; do
    name=${env%%:*}; rest=${env#*:}; dir=${rest%%:*}; path=${rest#*:}
    for payload in "${ENV_STATUS_PAYLOADS[@]}"; do
      n=$((n + 1))
      err=$(printf '%s' "$payload" \
            | ( cd "$dir" && PATH="$path" CLAUDE_PROJECT_DIR="$REPO_ROOT" "$HOOKS/$hook" ) 2>&1 >/dev/null)
      rc=$?
      case "$rc" in
        0|2) ;;
        *) bad="$bad
         exit=$rc in [$name] on |$payload|
         stderr |$err|" ;;
      esac
    done
  done <<< "$ENV_STATUS_CASES"
  if [ -n "$bad" ]; then
    fail static '%s exits other than 0 or 2:%s' "$hook" "$bad"
  elif [ "$n" != "$ENV_STATUS_EXPECTED" ]; then
    fail static '%s: the sweep ran %s cases, not the %s written here' "$hook" "$n" "$ENV_STATUS_EXPECTED"
  else
    pass static 'status %s exits only 0 or 2, over %s cases' "$hook" "$n"
  fi
done

echo "--- report-stale-branches.sh says why it reported nothing ---"
# The row #108 left to this pull request to decide. It exited 0 with no output at
# all when git was off PATH or it stood outside a repository, and an empty report
# reads as nothing to report. Decided the way every other unread thing in that
# file already reads -- the fetch, the merge settings, the pull requests and the
# main ancestry all say so -- and the argument is in its header.
#
# Driven against a COPY of the file, in a tree that is not a repository, because
# the file cds to its own grandparent and this repository is one. The copy is the
# $HOOKS one, so an override judges the file it was pointed at.
req GH-108.9
ENV_REPORT_COPY="$ENV_REPOS/report-copy/.claude/hooks"
mkdir -p "$ENV_REPORT_COPY"
cp "$HOOKS/report-stale-branches.sh" "$ENV_REPORT_COPY/"
[ -s "$ENV_REPORT_COPY/report-stale-branches.sh" ] || {
  echo "the report copy was not made; the checks against it would prove nothing" >&2
  exit 1
}
report_says "$PATH" "$ENV_REPORT_COPY/report-stale-branches.sh" \
  'branches: NOT READ -- this is not a git repository' \
  'outside a repository it says the branches were not read'
report_says "$PATH" "$ENV_REPORT_COPY/report-stale-branches.sh" \
  '== branch lifecycle ==' \
  'outside a repository it still prints its heading first'
report_says "$PATH" "$ENV_REPORT_COPY/report-stale-branches.sh" \
  'no-work-on-stale-branch.sh is armed for this session.' \
  'outside a repository it names what is not armed'
report_says "$ENV_NO_GIT_BIN" "$ENV_REPORT_COPY/report-stale-branches.sh" \
  'branches: NOT READ -- git is not on PATH' \
  'with git off PATH it names git rather than the tree'
# The third cause, a root the file cannot reach, is checked as text and not as a
# run: a directory unsearchable enough to fail that cd is one the file cannot be
# read out of either, so bash exits 126 before the guard is reached. Measured, not
# assumed -- and it is why this one line is held to the file rather than to a
# verdict.
written 'the unreachable-root guard says why it reported nothing too' \
  "$HOOKS/report-stale-branches.sh" \
  'branches: NOT READ -- this file could not reach the repository root from its'
written 'the heading is printed before the first thing that can fail' \
  "$HOOKS/report-stale-branches.sh" \
  'echo "== branch lifecycle =="'
unarmed 'no exit above the heading survives, which is what made it silent' \
  "$HOOKS/report-stale-branches.sh" \
  'cd "$(dirname "$0")/../.." || exit 0'
unarmed 'nor the rev-parse that exited with nothing said' \
  "$HOOKS/report-stale-branches.sh" \
  'git rev-parse --git-dir >/dev/null 2>&1 || exit 0'

echo "--- and that run does not execute the gh standing beside the git it lacks (#155) ---"
# THE ROW ABOVE IS WHERE THE FARM'S STUB COULD GO WRONG, and until this block the
# only thing saying it does not was a sentence in the farm's own comment -- which
# was wrong about why, and was found wrong in review rather than by a check.
# $ENV_NO_GIT_BIN is the farm minus `git`, so it carries the farm's `gh` -- the
# host's, or the stub synthesised for it -- on the PATH of the one file in
# .claude/hooks/ that calls `gh` at all. What keeps that stub from ever answering
# for a real one is an ordering INSIDE report-stale-branches.sh: its
# `command -v git` guard exits above the first of those calls. That is a property
# of that file and not of this fixture, so an edit there reading `gh` before
# `git` would have the stub answering a question a verdict is read off, and the
# comment that used to assert it could not happen would still have been green.
#
# THE MARKER IS A FILE AND NOT A MESSAGE, which that file's own code forces: it
# reads `gh api` with 2>/dev/null, so a stub announcing itself on stderr would be
# silenced by the very line this exists to catch. A file written on exec is
# visible whatever the caller redirects. The control below runs the marker `gh`
# on purpose first, because an absence read off a marker that never worked is
# evidence of nothing -- the shape `lacks` refuses for text, asked here of a file.
req GH-155.1
ENV_NO_GIT_GH_MARKER="$FIXTURES/path-without-git-whose-gh-tells"
ENV_GH_WAS_RUN="$FIXTURES/the-report-ran-a-gh"
cp -a "$FARM_HOST_HAD_NO_GH" "$ENV_NO_GIT_GH_MARKER"
rm -f "$ENV_NO_GIT_GH_MARKER/git"
# THE SAME UNLINK AND THE SAME REASON the synthesis carries a paragraph about:
# `>` on a farm entry writes THROUGH the symlink and truncates the host binary it
# points at. The copy above is of a farm whose `gh` is already a written stub and
# not a link, so there is nothing here to write through -- but that is a property
# of the line above rather than of this one, which is exactly how the first
# instance of this hazard got written.
rm -f "$ENV_NO_GIT_GH_MARKER/gh"
printf '#!/bin/bash\n: > "%s"\nexit 1\n' "$ENV_GH_WAS_RUN" > "$ENV_NO_GIT_GH_MARKER/gh"
chmod +x "$ENV_NO_GIT_GH_MARKER/gh"
rm -f "$ENV_GH_WAS_RUN"
( PATH="$ENV_NO_GIT_GH_MARKER"; gh --version >/dev/null 2>&1 )
tok 'the marker gh records having been run, so the absence below is a measurement' \
    'ran' "$( [ -e "$ENV_GH_WAS_RUN" ] && echo ran )"
rm -f "$ENV_GH_WAS_RUN"
report_says "$ENV_NO_GIT_GH_MARKER" "$ENV_REPORT_COPY/report-stale-branches.sh" \
  'branches: NOT READ -- git is not on PATH' \
  'with a gh on PATH and no git it still names git as what it lacks'
tok 'and it never ran that gh, which is the whole of what lets the farm carry a stub' \
    '' "$( [ -e "$ENV_GH_WAS_RUN" ] && echo ran )"
# THE OTHER THREE PATHS, derived off the file rather than recited: two hold no
# `gh` at all and the third is the invoker's own, where the run stops at the
# not-a-repository guard above. What this asks is that none of them is
# $WITH_JQ_BIN, the farm itself -- the one PATH on which a `gh` would be both
# present and reached -- so a later check that drove the report under the farm
# would turn this line red rather than quietly making the stub load-bearing.
# #84's direction: the claim is about every consumer, so it is derived from
# every consumer it can read -- and what it cannot read is named below rather
# than left to be discovered.
#
# READ AT A CALL POSITION, AND THE POSITIONS ARE NAMED: the start of a line with
# any indentation, after a `;`, `&`, `|` or `)`, and after a `then`, `do` or
# `else`. The last two groups are not decoration. drive_helper dispatches this
# helper through a CASE ARM --
#
#     report_says) report_says "$PATH" "$EXITS/$fixture.sh" "$fixture" 'self-test' ;;
#
# -- where the line-start position reads the case LABEL, `report_says)`, and not
# the call. A derivation that only skipped indentation could not see the one call
# in this suite that is not a statement of its own, and `if ...; then report_says
# "$WITH_JQ_BIN" ...` was invisible to it as well. Round 2 of PR #161's review
# found the previous spelling claiming to read "anywhere on a line" while reading
# line-start-modulo-whitespace, and citing that case arm as its evidence -- the
# one line its own code could not read. The prose was stronger than the guard,
# which is the defect this whole section is about, arriving in the fix for it.
#
# WHAT IT STILL CANNOT READ is a call whose command word is a variable: no
# reading of the text can, because `$DRIVEN_REPORT "$WITH_JQ_BIN"` spells the
# name nowhere. That shape is not in this file -- DRIVEN_REPORT names the helper
# for the loop above, and the case arm is where it becomes a call, which is why
# covering the case position covers that route whole -- and if it is ever
# written, this derivation is evidence about the calls it can read and about
# nothing else.
#
# WHITESPACE IS NOT ONE OF THE SEPARATORS, and what that excludes is a
# `report_says "` sitting inside a quoted string -- payload rather than a call.
# MEASURED AGAINST THIS FILE AS IT STANDS, admitting whitespace would change
# nothing: the same twelve lines, the same four PATHs. So the exclusion is a rule
# about what may be written here later and not a description of something this
# file contains, and saying otherwise would be this section's own defect a third
# time. What made it a live hazard was the previous round's fixture, which wrote
# the call out as literal text inside an `echo`, indented, with the farm as its
# PATH -- payload that admitting whitespace would have read as a call, injecting
# the farm into the real derivation and turning the check red for a reason having
# nothing to do with the report. THAT EXAMPLE IS NOT SPELLED OUT HERE, and the
# omission is the point: a comment naming it in full would plant the thirteenth
# match itself, which is what happened on the first attempt at this paragraph and
# is why the claim above is a measurement and not a recollection. It is out of
# reach now by CONSTRUCTION rather than by the quote that happens to precede it:
# the fixtures below are written through a variable holding the helper's name, so
# this file carries no `report_says` of theirs in any position at all.
#
# A COMMENT IS READ AT A SEPARATOR POSITION, and the example six lines above is
# read: it is one of the twelve lines this derivation matches in this file, and
# it names $PATH, which is why the literal below is what it would be without it.
# Writing that down rather than filtering it out is the decision, and it rests on
# the direction. A comment can only ADD a PATH to the derived set, never hide a
# call from it, so the property this check exists for -- that no run under the
# farm goes unseen -- survives; a comment that named the farm would turn the
# check RED until it was reworded, which is a nuisance in the safe direction.
# Stripping comments first would buy the tidier claim at the price of the unsafe
# one: the strip cuts at the first `#` on a line, so a line carrying one before a
# call would lose the call and the check would go quietly green. The line-start
# position is the half that is closed, because a comment's first non-blank is
# `#`; the separator positions are not, and this paragraph is the record of it.
report_run_paths() {  # report_run_paths <file> -- every PATH the report is driven under in it
  grep -oE '(^|[;&|)]|[[:space:]](then|do|else))[[:space:]]*report_says "[^"]*"' "$1" \
    | sed 's/.*report_says "//; s/"$//' | sort -u | tr '\n' ' '
}
REPORT_RUN_PATHS=$(report_run_paths "$SUITE_DIR/check-hooks.sh")
tok 'every run of the report names one of four PATHs, and the farm is not among them' \
    '$ENV_NO_GH_BIN $ENV_NO_GIT_BIN $ENV_NO_GIT_GH_MARKER $PATH ' "$REPORT_RUN_PATHS"
# THE CASE ARM, READ OUT OF THIS FILE AS IT STANDS, and not a fixture resembling
# it: the sentence above cites it, so the citation is the thing to check. It is
# found by its shape rather than by a line number, and the count is asserted
# first because a derivation run over an empty extract returns the empty string,
# which would agree with nothing and pass.
REPORT_CASE_ARM="$FIXTURES/the-case-arm-as-this-file-writes-it"
grep -E '^[[:space:]]*report_says\)' "$SUITE_DIR/check-hooks.sh" > "$REPORT_CASE_ARM"
tok 'this suite holds one report_says call that is not a statement of its own, in drive_helper' \
    '1' "$(grep -c . "$REPORT_CASE_ARM")"
tok 'and the derivation reads that line as it stands, which the line-start spelling could not' \
    '$PATH ' "$(report_run_paths "$REPORT_CASE_ARM")"
# The three shapes a call is written in here, in a file whose every run is one of
# them: an indented loop body, a case arm, and a call after `then`. None is
# readable at the line-start position, so this fixture is red under the spelling
# the review found and is the whole of what makes the paragraph above a claim
# rather than a hope.
REPORT_SAYS_NAME='report_says'
REPORT_DERIVATION_FIXTURE="$FIXTURES/report-runs-in-the-shapes-this-suite-writes"
{ echo 'for d in one; do'
  echo "  $REPORT_SAYS_NAME \"\$WITH_JQ_BIN\" \"\$SOME_REPORT\" fragment label"
  echo 'done'
  echo 'case $h in'
  echo "  $REPORT_SAYS_NAME) $REPORT_SAYS_NAME \"\$ENV_NO_GH_BIN\" \"\$SOME_REPORT\" fragment label ;;"
  echo 'esac'
  echo "if true; then $REPORT_SAYS_NAME \"\$ENV_NO_GIT_BIN\" \"\$SOME_REPORT\" fragment label; fi"
} > "$REPORT_DERIVATION_FIXTURE"
tok 'and it sees an indented run, a case arm and a run after then, none of which begins its line' \
    '$ENV_NO_GH_BIN $ENV_NO_GIT_BIN $WITH_JQ_BIN ' "$(report_run_paths "$REPORT_DERIVATION_FIXTURE")"
# The two halves of what a comment does to it, asserted rather than asserted
# about: a commented-out call at the line-start position is not read, and one at
# a separator position is. The second is the quirk the paragraph above accepts,
# and it is pinned here so that accepting it is a decision on the record rather
# than something a later reader has to rediscover by measuring.
REPORT_COMMENT_FIXTURE="$FIXTURES/report-runs-that-are-only-prose"
{ echo "# $REPORT_SAYS_NAME \"\$A_PATH_ONLY_A_COMMENT_NAMES\" x y z"
  echo "# as in: $REPORT_SAYS_NAME) $REPORT_SAYS_NAME \"\$A_PATH_A_COMMENT_REACHES\" x y z ;;"
} > "$REPORT_COMMENT_FIXTURE"
tok 'a commented call is out of reach at the line-start position and in reach after a separator' \
    '$A_PATH_A_COMMENT_REACHES ' "$(report_run_paths "$REPORT_COMMENT_FIXTURE")"

echo "--- the degraded report, produced rather than described ---"
# The last row of #108's table: offline, the fetch reports FAILED, the settings
# read reports NOT READ, and the session still starts. It was already pinned --
# GH-100 asserts the file HOLDS each of those phrases -- but a file that never
# reaches a line holds its text just as well, and the phrases and the exit status
# had never been read off a run together.
#
# A repository whose origin is a path that is not there, under the gh-less PATH
# above. Both halves are deliberate and neither is a timeout: a fetch of a local
# path that does not exist fails at once, and the file's own header says the pull
# request read is skipped when the settings read found gh missing. So this is the
# degraded report in full, for no wall clock. A genuinely unreachable network
# would cost FETCH_TIMEOUT and is nobody's check.
req GH-108.10
ENV_OFFLINE="$ENV_REPOS/offline"
mkdir -p "$ENV_OFFLINE/.claude/hooks"
git init -q -b feature-x "$ENV_OFFLINE"
git -C "$ENV_OFFLINE" $GE commit -q --allow-empty -m base
git -C "$ENV_OFFLINE" remote add origin "$ENV_REPOS/there-is-no-remote-here.git"
cp "$HOOKS/report-stale-branches.sh" "$ENV_OFFLINE/.claude/hooks/"
[ -s "$ENV_OFFLINE/.claude/hooks/report-stale-branches.sh" ] \
  && [ ! -e "$ENV_REPOS/there-is-no-remote-here.git" ] \
  && [ "$(git -C "$ENV_OFFLINE" remote)" = origin ] || {
  echo "the offline report fixture is not a repository with an unreachable origin; the checks against it would prove nothing" >&2
  exit 1
}
ENV_OFFLINE_REPORT="$ENV_OFFLINE/.claude/hooks/report-stale-branches.sh"
report_says "$ENV_NO_GH_BIN" "$ENV_OFFLINE_REPORT" \
  'fetch: FAILED or timed out after 15s' \
  'a failed fetch is reported, and the session still starts'
report_says "$ENV_NO_GH_BIN" "$ENV_OFFLINE_REPORT" \
  'is not armed for this session.' \
  'and it says what that leaves unarmed'
report_says "$ENV_NO_GH_BIN" "$ENV_OFFLINE_REPORT" \
  'merge settings: NOT READ -- no gh on PATH' \
  'the merge settings are NOT READ rather than reported as drifted'
report_says "$ENV_NO_GH_BIN" "$ENV_OFFLINE_REPORT" \
  'pull requests: NOT READ -- no gh on PATH' \
  'the pull requests are NOT READ, and the classes say so'
report_says "$ENV_NO_GH_BIN" "$ENV_OFFLINE_REPORT" \
  'active dev branch: none' \
  'and with no dev ref fetched the active dev branch is none, not a guess'

section "=== issue #109: timing, what a refusal says, the registration, and all seven hooks at once ==="
# Four kinds of check #103's audit found the suite without (Q3), each of which
# had already let something through. They are grouped here by kind rather than
# spread over the sections of the hooks they read, because each asks one
# question of every hook and a reader auditing the question wants it in one
# place.

echo "--- a realistic worst case: a 200-line heredoc, several separators a line ---"
# #96 bounds a hook at the cap: a command whose longest line is 16 KB finishes in
# under 1 s, fastest of three. That is a claim about one long line. The shape an
# agent actually writes is many short ones, and the commonest carrier of many
# short lines is a heredoc -- a commit message, a file written with cat. So the
# same bound, the same fastest-of-three and the same refusal to time anything
# but a refusal (see cap_timed), asked of 200 body lines each holding four
# separators and a redirect, with each hook's own refused command after it.
#
# MEASURED BEFORE IT WAS WRITTEN, 2026-09-18, at 33f7129, fastest of three: 9 to
# 33 ms per hook, quoted opener or not, in a scratch fixture; the first run of
# this section, in the fixtures below, measured 12 to 57 ms. cs_normalise drops a heredoc body before
# any pass reads it, so its separators never become fragments. That is what this
# pins: a change that let a body through to cs_split would multiply the time by
# the number of fragments, which is the cost #127 is about.
#
# NOT HERE, and named for that reason. The same 200 lines as LIVE commands, with
# no heredoc around them, took no-pr-decisions.sh 3.1 s, no-commit-to-main.sh
# 2.1 s and no-git-push.sh 1.1 s on the same run -- over this bound, under the
# harness's 5 s. That is #127's per-fragment cost, which #96 left open, and a
# bound on it is #127's decision to take, not this section's.
XH_BODY=$(for i in $(seq 1 200); do
            printf 'echo step %s; cd src && git status | grep -v x || true; ls >> log\n' "$i"
          done)
cap_guard 'heredoc body, lines' 200 "$(printf '%s\n' "$XH_BODY" | wc -l | tr -d ' ')"
cap_guard 'heredoc body, lines holding four separators' 200 \
  "$(printf '%s\n' "$XH_BODY" | grep -c '; .* && .* | .* || ')"
req GH-109.1
for hook in $BASH_HOOKS; do
  dir=$(cap_dir "$hook")
  refused=$(cap_refused "$hook")
  [ -n "$refused" ] || continue
  under_a_second "$hook, a 200-line heredoc of separators, then $refused" \
    "$(cap_timed "$dir" "$hook" "cat <<'EOF'
$XH_BODY
EOF
$refused")"
  under_a_second "$hook, the same heredoc with an unquoted opener" \
    "$(cap_timed "$dir" "$hook" "cat <<EOF
$XH_BODY
EOF
$refused")"
done

echo "--- every refusal of no-git-push.sh says the rule it applies ---"
# US-7: a refusal tells an agent the permitted spelling or the reason. Before
# this, `says` read the bare push's message, the main checkout's and the
# reserved branch's, and nothing else in this file: every other arm could be
# emptied to "Blocked." with this suite green, since the verdict would not move.
#
# ONE ROW AN ARM, and the fragment is the arm's own tail, whole. A prefix keeps
# matching after the rest of the sentence is deleted, so each fragment runs to
# the end of the sentence that states the reason -- the lesson of the retarget
# row in #105's section. The shared opening, $REFUSE, which states the rule
# itself, is read on every arm that carries it, sixteen of the nineteen; the
# wrapper arm, the load guard and the cap do not carry it.
#
# READ ONCE WAS NOT ENOUGH, and the second review of PR #169 is why it is read
# sixteen times now. It read it once, and said so without an argument -- while
# $DECIDE, three screens down, was read on every arm with the argument spelled
# out. One row catches text deleted from the constant. It does not catch an arm
# that stops interpolating it: that arm loses the whole rule sentence, its own
# tail row still passes, and the count below does not move. Review found the
# same hole at $BASE and measured it; this is the third opening, closed on the
# same reasoning rather than waiting for a round that measures it too.
#
# All in the push fixture's linked worktree on $PUSH_BRANCH with an origin,
# where the push the arm refuses is otherwise the permitted one: so each refusal
# is the arm's and not the main checkout's or the reserved branch's.
req US-7 GH-109.2
says "$PUSH_WT" no-git-push.sh 'An agent may push only the branch of the linked worktree it is working in, so that it can open a pull request.' \
  'every push refusal opens with the rule it applies' 'git push --force origin wt-branch'
says "$PUSH_WT" no-git-push.sh 'The destination cannot be read through a quoted payload, so the worktree exception does not apply. Push plainly from the worktree, or leave it to Bertan.' \
  'a wrapped push says why, and to push plainly' "bash -c 'git push origin $PUSH_BRANCH'"
says "$PUSH_WT" no-git-push.sh 'This command changes directory first, so where the push would land cannot be judged from here.' \
  'a push after cd says the directory moved' "cd src && git push origin $PUSH_BRANCH"
says "$PUSH_WT" no-git-push.sh 'This command points git at another directory, so where the push would land cannot be judged from here.' \
  'a push under GIT_DIR= says git is pointed elsewhere' "GIT_DIR=/tmp/x git push origin $PUSH_BRANCH"
says "$PUSH_WT" no-git-push.sh 'This command points git at another directory, so where the push would land cannot be judged from here.' \
  'a push under git -C says the same, from its own arm' "git -C /tmp push origin $PUSH_BRANCH"
says "$PUSH_WT" no-git-push.sh 'This command sets git configuration for itself, which overrides what this check would read back.' \
  'a push under git -c says configuration was set for it' "git -c push.default=matching push origin $PUSH_BRANCH"
says "$PUSH_WT" no-git-push.sh 'That form pushes or deletes refs wholesale rather than naming this branch.' \
  'a push --all says it names no branch' 'git push --all origin'
says "$PUSH_WT" no-git-push.sh 'That is a forced push, which rewrites history the open pull request is showing. Add a commit instead.' \
  'a forced push says why, and to add a commit' "git push --force origin $PUSH_BRANCH"
says "$PUSH_WT" no-git-push.sh 'A wildcard refspec does not name this branch.' \
  'a wildcard refspec says it names no branch' "git push origin 'refs/heads/*'"
says "$PUSH_WT" no-git-push.sh 'upstream is not a remote of this repository.' \
  'a push to a remote that is not one says so, by name' "git push upstream $PUSH_BRANCH"
says "$PUSH_WT" no-git-push.sh 'A leading + forces the push, which rewrites history the open pull request is showing.' \
  'a + refspec says it forces' "git push origin +$PUSH_BRANCH"
says "$PUSH_WT" no-git-push.sh "This names feature-y, not $PUSH_BRANCH." \
  'a push of another branch names both' 'git push origin feature-y'
# The continuation arm: a backslash cs_join did not join. A backslash followed
# by a space ends no line, so it survives into the arguments.
says "$PUSH_WT" no-git-push.sh 'The arguments continue past where this check can read them.' \
  'a push whose arguments end in an unjoined backslash says it cannot read them' "git push origin $PUSH_BRANCH \\ "
# The detached arm needs a worktree with no branch, which no fixture above holds.
PUSH_WT_DETACHED="$FIXTURES/push-wt-detached"
$GP worktree add -q --detach "$PUSH_WT_DETACHED"
need_worktree "$PUSH_WT_DETACHED" 'detached push'
[ -z "$(git -C "$PUSH_WT_DETACHED" branch --show-current)" ] || {
  echo "the detached push worktree is on a branch; the check against it proves nothing" >&2
  exit 1
}
says "$PUSH_WT_DETACHED" no-git-push.sh 'This worktree has no branch checked out.' \
  'a push from a detached worktree says it has no branch' 'git push origin HEAD'
# The arms older sections read, read again here to the end of their sentence.
# #94 and #108 pinned each by the prefix that told it from its neighbours, which
# was their question; the half after it is the remedy or the reason, which is
# this one's, and a prefix keeps matching after that half is deleted.
says "$PUSH_MAIN" no-git-push.sh 'This is the main checkout, not a linked worktree. Leave the commits on the branch and say what is ready to push.' \
  'a push from the main checkout says what to do instead' 'git push origin feature-x'
says "$PUSH_WT_DEV" no-git-push.sh "This worktree is on dev-05, which is Bertan's to push." \
  'a push from a worktree on dev-05 says whose the branch is' 'git push origin dev-05'
says "$NOT_A_REPO" no-git-push.sh 'The repository directory git reports here could not be resolved, so whether this runs in a linked worktree cannot be judged from here.' \
  'a push where git reports no directory says what could not be judged' 'git push origin x'
# And the rule sentence itself, on each of the sixteen arms that carry it. The
# fragment is $REFUSE whole -- including the `Blocked: git push.` the earlier
# version left off -- and it is asked as an OPENING rather than as a fragment
# somewhere in the message, which is what the label has always said and what
# `says` could not ask. See `says_first`.
opens_with_rule() {  # opens_with_rule <dir> <label> <cmd>
  says_first "$1" no-git-push.sh 'Blocked: git push. An agent may push only the branch of the linked worktree it is working in, so that it can open a pull request.' \
    "$2: opens with the rule" "$3"
}
req US-7 GH-109.2
opens_with_rule "$PUSH_WT" 'a push after cd' "cd src && git push origin $PUSH_BRANCH"
opens_with_rule "$PUSH_WT" 'a push under GIT_DIR=' "GIT_DIR=/tmp/x git push origin $PUSH_BRANCH"
opens_with_rule "$PUSH_WT" 'a push under git -C' "git -C /tmp push origin $PUSH_BRANCH"
opens_with_rule "$PUSH_WT" 'a push under git -c' "git -c push.default=matching push origin $PUSH_BRANCH"
opens_with_rule "$PUSH_WT" 'a push whose arguments end in an unjoined backslash' "git push origin $PUSH_BRANCH \\ "
opens_with_rule "$PUSH_WT" 'a push --all' 'git push --all origin'
opens_with_rule "$PUSH_WT" 'a forced push' "git push --force origin $PUSH_BRANCH"
opens_with_rule "$PUSH_WT" 'a wildcard refspec' "git push origin 'refs/heads/*'"
opens_with_rule "$PUSH_WT" 'a push to a remote that is not one' "git push upstream $PUSH_BRANCH"
opens_with_rule "$PUSH_WT" 'a + refspec' "git push origin +$PUSH_BRANCH"
opens_with_rule "$PUSH_WT" 'a push of another branch' 'git push origin feature-y'
opens_with_rule "$PUSH_WT" 'a push naming no refspec' 'git push'
opens_with_rule "$PUSH_MAIN" 'a push from the main checkout' 'git push origin feature-x'
opens_with_rule "$PUSH_WT_DEV" 'a push from a worktree on dev-05' 'git push origin dev-05'
opens_with_rule "$PUSH_WT_DETACHED" 'a push from a detached worktree' 'git push origin HEAD'
opens_with_rule "$NOT_A_REPO" 'a push where git reports no directory' 'git push origin x'
# Two registry rows, because the claim has two halves and they fail apart.
# `push-refusal-stops-opening-with-the-rule` takes $REFUSE off the forced-push
# arm and leaves the arm's own tail, which is what an arm that stopped carrying
# the constant looks like. `push-refusal-moves-the-rule-to-the-end` leaves it
# carrying the constant and puts it last, which is what the label claims and
# what `says` could not tell from the right order -- the row the third review of
# PR #169 pointed out was missing, since a deletion proves a deletion. Both
# caught, 2026-09-20.

echo "--- every refusal of no-pr-decisions.sh says the rule it applies ---"
# The same question of the other boundary hook. #97 read the release refusals and
# #105 the four base refusals; the decision arms and the wrapper were read by
# nobody. Every decision arm opens with DECIDE, whose second sentence is the one
# that names what stays permitted -- opening, commenting, editing -- so it is
# read on every arm rather than once: the constant is interpolated per arm, and
# an arm that stopped using it would lose exactly that sentence.
req US-7 GH-109.2
for c in 'bash -c "gh pr merge 5"' \
         'gh pr merge 5' \
         'gh pr review --approve 5' \
         'gh pr close 5' \
         'gh pr reopen 5' \
         'gh api -X PUT repos/o/r/pulls/5/merge' \
         'gh api -X PATCH repos/o/r/pulls/5 -f state=closed' \
         'gh api graphql -f query="mutation { mergePullRequest(input:{x:1}) }"'
do
  says "$ON_DEV" no-pr-decisions.sh "Blocked: deciding a pull request is Bertan's call, not an agent's. Opening a PR, commenting on it and editing it are allowed; accepting, rejecting, merging and reopening are not." \
    "$c: says a decision is Bertan's, and what stays allowed" "$c"
done
says "$ON_DEV" no-pr-decisions.sh 'A shell wrapper does not change what the command decides, and its payload cannot be read. Run it unwrapped.' \
  'a wrapped decision says to run it unwrapped' 'bash -c "gh pr merge 5"'
says "$ON_DEV" no-pr-decisions.sh 'Leave the PR open and say it is ready to merge.' \
  'a merge says to leave it open and say it is ready' 'gh pr merge 5'
says "$ON_DEV" no-pr-decisions.sh 'Review with --comment to leave remarks without a verdict.' \
  'a verdict review names the review that is allowed' 'gh pr review --approve 5'
says "$ON_DEV" no-pr-decisions.sh 'Closing a PR rejects it; say why it should be closed instead.' \
  'a close says it rejects, and to say why instead' 'gh pr close 5'
says "$ON_DEV" no-pr-decisions.sh 'Closing a PR rejects it; say why it should be closed instead.' \
  'a reopen reaches the same sentence' 'gh pr reopen 5'
says "$ON_DEV" no-pr-decisions.sh 'Reaching the merge or review endpoint through gh api is the same decision by another name.' \
  'the merge endpoint says it is the same decision' 'gh api -X PUT repos/o/r/pulls/5/merge'
says "$ON_DEV" no-pr-decisions.sh "Setting a pull request's state through gh api closes or reopens it, which is the same decision by another name." \
  'a state write says it closes or reopens' 'gh api -X PATCH repos/o/r/pulls/5 -f state=closed'
says "$ON_DEV" no-pr-decisions.sh 'Reaching the same decision through a graphql mutation is the same decision by another name.' \
  'a decision mutation says it is the same decision' 'gh api graphql -f query="mutation { mergePullRequest(input:{x:1}) }"'
# The API arm of the missing base, whose sentence #105 read only for gh pr
# create and only as far as its first clause.
says "$ON_DEV" no-pr-decisions.sh "No base is named here, so this would go to the repository's default branch." \
  'a REST create naming no base says where it would go' 'gh api -X POST repos/o/r/pulls -f head=x -f title=t'
says "$ON_DEV" no-pr-decisions.sh "No base is named here, so this would go to the repository's default branch." \
  'a graphql create naming no base says the same' 'gh api graphql -f query="mutation{createPullRequest(input:{headRefName:\"x\"})}"'
# The release refusals, which #97 read for their verdict-bearing words and not to
# the end: the reason a write is Bertan's, and the read the gh api arm names.
says "$ON_DEV" no-pr-decisions.sh 'and this repository is public, so a release is visible the moment it changes.' \
  'the release refusal says why a write is not an agent'"'"'s' 'gh release upload v1 a.tgz'
says "$ON_DEV" no-pr-decisions.sh 'Reading one is permitted: a gh api request to /releases that does not write, or gh release followed by one of: list view download verify verify-asset.' \
  'the gh api release refusal names both reads that stay permitted' 'gh api -X PATCH repos/o/r/releases/1'
# THE THIRD SHARED OPENING, $BASE, and the second review of PR #169 is why it is
# here. This section disposed of two -- $REFUSE, read whole once above, and
# $DECIDE, read on every arm -- and said nothing about the third. Every check
# that read $BASE read `Write: gh pr create --base dev-NN` and stopped there,
# which is the prefix shape the paragraph at the head of this section was written
# to stop: it is the front of the remedy, so the rule sentence in front of it and
# the ` --title ... --body ...` behind it could both go with this suite green.
# Review measured exactly that, deleting each half in turn, and both survived.
#
# So the constant is read whole, on every arm that interpolates it, for $DECIDE's
# reason: an arm that stopped using it would lose the rule sentence and nothing
# here would say so. Seven arms carry it -- two creates, a create naming no base,
# two retargets, and the two gh api spellings -- where there were five before #139
# added the quoted-flag pair.
#
# The retarget rows are tagged FR-23 and not US-7, for the reason the base block
# above gives at length: one constant for four refusals is what FR-23 asks for,
# and for a retarget the constant's `gh pr create` is not the one-step correction
# US-7 asks for. That correction is in the retarget's own tail, which has its own
# row above.
BASE_WHOLE="Blocked: a pull request may be proposed only into the active dev branch, and the base has to be named in the command. Write: gh pr create --base dev-NN --title ... --body ..."
req US-7 FR-23 GH-109.2
for c in 'gh pr create --base main --title x' \
         'gh pr create --title x --body y' \
         'gh pr create --base"=dev-05" --title x' \
         'gh api -X POST repos/o/r/pulls -f base=main -f head=x' \
         'gh api -X POST repos/o/r/pulls -f head=x -f title=t'
do
  says "$ON_DEV" no-pr-decisions.sh "$BASE_WHOLE" \
    "$c: says the rule and names the spelling, both halves" "$c"
done
req FR-23 GH-109.2
for c in 'gh pr edit 5 --base main' \
         'gh pr edit 5 --base"=dev-05"'
do
  says "$ON_DEV" no-pr-decisions.sh "$BASE_WHOLE" \
    "$c: says the rule and names the spelling, both halves" "$c"
done
# And the three tails nothing read. The two quoted-flag arms came with #139 and
# were given no message row at all; the gh api arm that names a bad base was read
# for its opening and never for what it says about the spelling. Each names the
# thing that tells its arm from the six beside it, so a message routed to the
# wrong one of them would otherwise pass every row above.
req US-7 GH-109.2
says "$ON_DEV" no-pr-decisions.sh 'A base flag is written with a quote or a backslash in its name (--base=dev-05 here), so the base this names cannot be checked. Write the flag unquoted.' \
  'a quoted base flag on a create says what cannot be read, and to write it unquoted' \
  'gh pr create --base"=dev-05" --title x'
req US-7 FR-23 GH-109.2
says "$ON_DEV" no-pr-decisions.sh 'A base flag is written with a quote or a backslash in its name (--base=dev-05 here), so where this retargets to cannot be checked. Write the flag unquoted: gh pr edit <n> --base dev-NN.' \
  'a quoted base flag on a retarget says the same, and names the retarget' \
  'gh pr edit 5 --base"=dev-05"'
req US-7 GH-109.2
says "$ON_DEV" no-pr-decisions.sh 'This names main; reaching it through gh api makes it the same destination under another spelling.' \
  'the gh api arm says naming the base there is the same destination' \
  'gh api -X POST repos/o/r/pulls -f base=main -f head=x'
# MEASURED, and the two halves are separate rows because they fail apart.
# `base-refusal-drops-the-rule-sentence` takes the rule off the front of $BASE
# and `base-refusal-drops-the-remedy-spelling` takes ` --title ... --body ...`
# off the back; both survived the suite as it stood, which is how review found
# this, and both are caught as of 2026-09-20. The registry already held
# `base-refusal-drops-the-spelling`, which replaces the middle -- the prefix the
# older rows read -- so the constant now has a row for each of its three parts,
# and it had one for the only part anything read.
# NO ARM GOES UNREAD, asked of the files rather than of this list. Every write
# to stderr in either hook is a refusal, and a new arm is a new write; so each
# hook's count is a literal here, and adding an arm moves it -- which is the
# moment to write that arm's row above. The count is the arms above, the load
# guard, the cap, and the arms other sections read: the release refusals (#97),
# the four base refusals (#105), the bare push, the main checkout, the reserved
# branch and the unresolvable directory (#94, #108).
#
# WHAT SHAPE AN ARM HAS TO BE WRITTEN IN, because this count is what makes it
# load-bearing. `arms` reads a redirection to fd 2 on one logical line, whatever
# writes through it. It read `echo .*>&2` when this section was written, which is
# one builtin, before the redirection, on one physical line; the first review of
# PR #169 widened it to `(echo|printf)` with continuations folded, and the second
# measured what that still let through and found three shapes:
#
#   >&2 echo "..."            the redirection first, which bash reads the same
#   cat >&2 <<EOF ... EOF     a heredoc, which is neither builtin
#   msg() { echo "$1" >&2; }  a helper, called once per arm
#
# and it ran the first of them: appended to `no-git-push.sh` as a real refusal
# arm, the count stayed at 19 and the whole suite stayed green. So the pattern is
# now the redirection itself -- `>&2`, `1>&2`, `>& 2` and `> /dev/stderr` -- which
# closes the first two, and the helper is closed below rather than by counting,
# because a helper called twice is two arms and one line however the line is read.
# Both counts are what they were before either widening, which is the whole of
# what a widening should do to a file that is clean.
#
# TWO TRADES, taken knowingly, and neither is the permitting direction.
#
# Comments are stripped whole-line only. An `echo ... >&2` written as a trailing
# comment on a live line inflates the count and turns the run red for nothing.
# That is left, and it is the same trade CLAUDE.md's consequence 3 takes -- a
# false red is visible and one edit away, a new arm that nothing reads is neither
# -- and closing it means deciding where a `#` is a comment and where it is
# inside a string, which is the thing that cannot be read out of the text.
#
# A group redirected once -- `{ echo a; echo b; } >&2` -- is two arms on three
# lines and counts one. Neither hook writes one, nothing here stops one being
# written, and it is named because the count is evidence about the shapes it
# names and about nothing else.
#
# A HEREDOC BODY IS THE SECOND, and "one shape remains" stood here until the
# third review of PR #169 counted them. This pipeline strips whole-line comments
# and folds continuations; it does not know where a heredoc body begins. Both
# hooks use heredocs today -- `done <<BASELIST`, `done <<CMDLIST` -- with bodies
# that are a bare variable, so nothing is miscounted now, and it is one edit away
# rather than hypothetical. Three shapes, and the third is the one the first two
# do not prepare a reader for:
#
#   a body line carrying `>&2`                counts as an arm      (false red)
#   `cat >&2 <<EOF` whose body carries one    counts twice for one  (false red)
#   a body line ending in a backslash         swallows the line
#                                             after it, so two arms
#                                             read as one           (PERMITTING)
#
# `fn_writes` runs the same pipeline and inherits all three. #182 owns it, and
# says why it was not fixed beside the rest: the other shapes review raised were
# pattern-width and were fixed by widening the pattern, and this one needs the
# counter to track heredoc state, which is a parser rather than a pattern. There
# is already one of those in this repository, and CLAUDE.md records what review
# rather than the suite found in it.
STDERR_WRITE='>&[[:space:]]*2|>[[:space:]]*/dev/stderr'
arms() {  # arms <file> -- in how many places it writes a refusal to stderr
  sed 's/^[[:space:]]*#.*$//' "$1" \
    | sed ':a;/\\$/{N;s/\\\n//;ba}' \
    | grep -cE "$STDERR_WRITE"
}
# WHAT `arms` COUNTS, driven against files written for it. Neither hook can show
# this: both are clean of every shape the two widenings added, so the pair of
# literals below is the same either way, and what the count would miss is
# invisible in a green run -- the same reason `ran` is driven directly in #109's
# configuration section. Each fixture is one shape, named after it; the last two
# are the comment trade, asserted rather than assumed.
ARMS_FIXTURES="$FIXTURES/arms"
mkdir -p "$ARMS_FIXTURES"
cat > "$ARMS_FIXTURES/echo.sh" <<'ARMS_EOF'
echo "refused" >&2
ARMS_EOF
cat > "$ARMS_FIXTURES/printf.sh" <<'ARMS_EOF'
printf 'refused\n' >&2
ARMS_EOF
cat > "$ARMS_FIXTURES/continued.sh" <<'ARMS_EOF'
echo "refused" \
  >&2
ARMS_EOF
cat > "$ARMS_FIXTURES/redirect-first.sh" <<'ARMS_EOF'
>&2 echo "refused"
ARMS_EOF
cat > "$ARMS_FIXTURES/heredoc.sh" <<'ARMS_EOF'
cat >&2 <<INNER
refused
INNER
ARMS_EOF
cat > "$ARMS_FIXTURES/dev-stderr.sh" <<'ARMS_EOF'
echo "refused" > /dev/stderr
ARMS_EOF
cat > "$ARMS_FIXTURES/whole-line-comment.sh" <<'ARMS_EOF'
# echo "refused" >&2
ARMS_EOF
cat > "$ARMS_FIXTURES/trailing-comment.sh" <<'ARMS_EOF'
exit 0  # echo "refused" >&2
ARMS_EOF
req GH-109.2
tok 'arms counts an echo redirected to stderr' '1' "$(arms "$ARMS_FIXTURES/echo.sh")"
tok 'arms counts a printf redirected to stderr, which echo alone did not' \
    '1' "$(arms "$ARMS_FIXTURES/printf.sh")"
tok 'arms counts an echo whose redirection is on a continuation line' \
    '1' "$(arms "$ARMS_FIXTURES/continued.sh")"
tok 'arms counts a redirection written before the command, which the builtin-first pattern did not' \
    '1' "$(arms "$ARMS_FIXTURES/redirect-first.sh")"
tok 'arms counts a heredoc sent to stderr, which is neither builtin' \
    '1' "$(arms "$ARMS_FIXTURES/heredoc.sh")"
tok 'arms counts a write to /dev/stderr by name' '1' "$(arms "$ARMS_FIXTURES/dev-stderr.sh")"
tok 'arms does not count a commented-out line' '0' "$(arms "$ARMS_FIXTURES/whole-line-comment.sh")"
tok 'arms counts a trailing comment, which is the false red this trade accepts' \
    '1' "$(arms "$ARMS_FIXTURES/trailing-comment.sh")"

# THE ONE SHAPE COUNTING CANNOT REACH, closed here instead. A line stands for an
# arm only while every write to stderr is at its own site. A function that writes
# one and is called twice is two arms and one line, and no pattern over the text
# of that line can say otherwise. `no-git-push.sh` has such a function already --
# `check_push`, which carries ten of its nineteen writes -- so this is a live
# assumption and not a hypothetical one, and it holds because that function is
# called exactly once.
#
# Both halves are pinned: which functions each hook defines and which of them
# write, so a new helper moves a literal and is declared rather than absorbed;
# and the call count of each one that writes, which is the number the arm count
# actually rests on. A silent function's call count is not pinned -- it moves on
# refactors that cost this claim nothing, and a red there would be noise.
#
# Only a `}` in column 1 closes a function, which is this file's convention and
# the same one `STATUS_READERS` names its reliance on; a one-line definition is
# read as one.
fn_writes() {  # fn_writes <file> -- "<function> writes|silent" a line, sorted
  sed 's/^[[:space:]]*#.*$//' "$1" \
    | sed ':a;/\\$/{N;s/\\\n//;ba}' \
    | awk -v W="$STDERR_WRITE" '
        /^function[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/ || /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)/ {
          fn = $0; sub(/^function[[:space:]]+/, "", fn); sub(/[[:space:](){].*/, "", fn)
          seen[fn] = 1
          if ($0 ~ /\{.*\}/) { if ($0 ~ W) w[fn] = 1; fn = ""; next }
          next
        }
        /^\}/ { fn = ""; next }
        fn != "" && $0 ~ W { w[fn] = 1 }
        END { for (f in seen) print f, (f in w ? "writes" : "silent") }' \
    | LC_ALL=C sort
}
# Occurrences, not lines. `grep -c` counts matching lines, so `check_push a;
# check_push b` on one line would read as one call and ten writes would become
# twenty arms with both rows green -- the hole the third review of PR #169 found
# one level below the one the second closed. `grep -o` counts each occurrence.
#
# WHAT IT STILL CANNOT SEE, named because this number is what the arm count rests
# on: an indirect call. Move the call into another function that is itself called
# twice and the text here still reads one. That is a call graph and not a
# pattern, and #181 owns it; what keeps it from mattering today is the row above,
# which pins the whole function table of both hooks, so the second function has
# to be declared before it can hide anything.
fn_calls() {  # fn_calls <file> <function> -- how many times it appears as a call
  sed 's/^[[:space:]]*#.*$//' "$1" \
    | sed ':a;/\\$/{N;s/\\\n//;ba}' \
    | grep -vE "^(function[[:space:]]+)?$2[[:space:]]*\(\)" \
    | grep -oE "(^|[^A-Za-z0-9_\$])$2([^A-Za-z0-9_-]|\$)" \
    | wc -l | tr -d ' '
}
req GH-109.2
tok 'no-git-push.sh defines these functions, and this is which of them writes a refusal' \
    'canonical_dir silent
check_push writes
names_this_branch silent' "$(fn_writes "$HOOKS/no-git-push.sh")"
tok 'no-pr-decisions.sh defines these, and none of them writes one' \
    'base_args silent
bases_all_dev silent
gh_api_is_write silent
gh_pr_bases silent
gh_pr_web silent
gh_rule silent
gql_bases silent
is_dev_base silent
quoted_base_flag silent
release_is_read silent
rest_bases silent' "$(fn_writes "$HOOKS/no-pr-decisions.sh")"
tok 'check_push is called once, so each write inside it is one arm and one line' \
    '1' "$(fn_calls "$HOOKS/no-git-push.sh" check_push)"

tok 'no-git-push.sh refuses in as many places as this suite reads' '19' \
    "$(arms "$HOOKS/no-git-push.sh")"
tok 'no-pr-decisions.sh refuses in as many places as this suite reads' '18' \
    "$(arms "$HOOKS/no-pr-decisions.sh")"
# `a-new-refusal-arm-nothing-reads` in the registry adds a real arm to
# no-git-push.sh in the shape review measured -- the redirection before the
# command -- and requires this count to move. It survived the count as first
# widened and is caught as of 2026-09-20, which is the difference between a
# widening argued and a widening run.

echo "--- settings.json: what runs, on which tool, in what order, under what timeout ---"
# settings.json is what makes a hook run at all, and until this section the suite
# read two of its registrations -- the report's and the stale guard's -- and the
# Bash timeouts as a set. So the Edit hook's timeout, the matcher any other hook
# is registered under, and the path each command names were unread: a hook moved
# under the wrong matcher, or registered at a path that is not there, runs on no
# call and every check that drives it by name stays green.
#
# THE WHOLE TABLE, as a literal, one line a hook: event, matcher, type, the
# command exactly as written, timeout. Order is part of it on purpose. The
# cross-hook checks below run the Bash hooks in their registered order, and a
# reordering is a change a reviewer should see move here.
#
# Every PreToolUse timeout is 5. The 1 s bounds above and in #96's section are
# set against it, and a hook the harness kills is a hook that permits, so a
# timeout lowered to 1 turns a hook that is merely slow into one that permits.
# The report's 50 is argued in its own section (FR-43) and is held here too.
#
# `worktree.baseRef` is pinned by GH-99.2, in the report's section, to what #99
# decided -- `fresh` -- and is not asked twice.
#
# MUTATION-CHECKED BY HAND, 2026-09-18, because mutate-hooks.sh copies only
# .claude/hooks/ and settings.json is one directory up: each edit made to the
# file in place from a per-file backup, this suite run, and the backup restored
# and its sha256 compared. What each turned red, and what already caught it:
#   - no-git-push.sh's timeout set to 1: this table, and GH-96.2's timeout set,
#     which already caught it before #109.
#   - every PreToolUse timeout set to 1, the issue's own wording: the same, and
#     the Edit hook's row, which nothing read before #109.
#   - no-git-push.sh unregistered: this table and the seven-hook row below, and
#     three older checks -- the CLAUDE.md paragraph, the cap consumers and #95's
#     registered list -- which already caught it.
#   - a hook registered that no check runs, x-unchecked.sh under Edit|Write: the
#     derived row at the foot of this section, naming it, besides this table.
#   - THE SAME HOOK REGISTERED UNDER Bash, 2026-09-20, which is the case the row
#     is mostly about and the one the Edit|Write mutation does not reach. Until
#     the third review of PR #169 it could not fail: `every_hook` ran whatever
#     was registered under Bash and recorded it, so the row read `was run 41
#     times under a tag` for a hook nothing checked. With that record gone, the
#     row says `settings.json registers x-unchecked.sh, and no tagged check ran
#     it`, measured. Nine other checks went red with it, which is the point --
#     the two loops that would otherwise have run the new hook, at #96's cap and
#     #109's timing, are both gated on `cap_refused`, a hand-written table, and
#     the guard above fails on a Bash hook with no row in it rather than running
#     it silently. settings.json was edited in place from a backup, restored, and
#     its sha256 compared.
#   - two Bash hooks swapped in order: this table and the seven-hook row, and
#     nothing else in the suite.
#   - `ran` returning before it records: the foot of this section, once for each
#     of the nine registered hooks.
# The one kind of mutation the issue names that lives in a hook -- a second hook
# refusing a permitted spelling -- is a registry row,
# `second-hook-refuses-a-permitted-read`.
REGISTRATION_EXPECTED='PreToolUse|Bash|command|"$CLAUDE_PROJECT_DIR"/.claude/hooks/no-commit-to-main.sh|5
PreToolUse|Bash|command|"$CLAUDE_PROJECT_DIR"/.claude/hooks/alembic-via-uv-group.sh|5
PreToolUse|Bash|command|"$CLAUDE_PROJECT_DIR"/.claude/hooks/pytest-via-uv-group.sh|5
PreToolUse|Bash|command|"$CLAUDE_PROJECT_DIR"/.claude/hooks/append-only-docs.sh|5
PreToolUse|Bash|command|"$CLAUDE_PROJECT_DIR"/.claude/hooks/no-git-push.sh|5
PreToolUse|Bash|command|"$CLAUDE_PROJECT_DIR"/.claude/hooks/no-pr-decisions.sh|5
PreToolUse|Bash|command|"$CLAUDE_PROJECT_DIR"/.claude/hooks/no-work-on-stale-branch.sh|5
PreToolUse|Edit|Write|command|"$CLAUDE_PROJECT_DIR"/.claude/hooks/append-only-docs-edit.sh|5
SessionStart|-|command|"$CLAUDE_PROJECT_DIR"/.claude/hooks/report-stale-branches.sh|50'
REGISTRATION=$(jq -r '.hooks | to_entries[] | .key as $e | .value[] | (.matcher // "-") as $m
                      | .hooks[] | "\($e)|\($m)|\(.type)|\(.command)|\(.timeout)"' "$SETTINGS" 2>/dev/null)
[ -n "$REGISTRATION" ] || {
  echo "no registration was read out of settings.json; the checks below prove nothing" >&2
  exit 1
}
req GH-109.3
tok 'settings.json registers exactly these hooks, under these matchers, in this order, with these timeouts' \
    "$REGISTRATION_EXPECTED" "$REGISTRATION"
# The same table a line at a time, so that a failure names the hook rather than
# printing two tables to compare by eye. The whole-table row above stays: it is
# the only one of the three that sees order, since a swap leaves every line
# present and none unexpected. Both directions: an expected line that
# is missing, and a registered line nobody expected.
while IFS= read -r line; do
  present "settings.json has: $line" "$line" "$(printf '%s\n' "$REGISTRATION" | tr '\n' ' ')"
done <<< "$REGISTRATION_EXPECTED"
XH_UNEXPECTED=$(printf '%s\n' "$REGISTRATION" | grep -vxF -- "$REGISTRATION_EXPECTED")
if [ -z "$XH_UNEXPECTED" ]; then
  pass static 'settings.json registers nothing this table does not name'
else
  fail static 'settings.json registers what this table does not name:\n%s' \
    "$(printf '%s\n' "$XH_UNEXPECTED" | sed 's/^/         /')"
fi

echo "--- all seven Bash hooks at once: a permitted spelling is permitted by every one ---"
# Every check above runs ONE hook. The harness runs every hook registered for
# Bash on every command, and permits the command only if all of them do. So a
# spelling CLAUDE.md's boundary section tells an agent to use, or that a refusal
# message names as the thing to write, can be refused by a hook other than the
# one whose rule it satisfies, and no single-hook check would see it. This asks
# each such spelling of all seven, in their registered order, read off
# settings.json -- the table above holds what that order is -- and requires every
# one to exit exactly 0 (Q20). One line per spelling, naming every hook that did
# not.
#
# Each runs where it is meant to be permitted (Q21), in the lifecycle fixture:
# $WT_WORK is a linked worktree on its own branch, carrying a commit, with an
# origin and origin/dev-05 -- an agent's worktree mid-task. The two catch-up
# spellings run in $WT_STALE, a worktree branch the dev branch has moved past,
# which is where the stale guard's message names them -- and is the state
# EnterWorktree leaves under `baseRef: fresh`, a branch at an older commit with
# nothing of its own, which is where route 2's reset is written for. The route-1 worktree
# creation runs from the main checkout.
#
# THE LIST IS HAND-WRITTEN, AND NOT DERIVED OFF $SECTION. Everything else
# load-bearing in this suite is derived off its source -- BASH_HOOKS,
# REGISTRATION, XH_HOOKS, STATUS_READERS, CAP_CONSUMERS -- and the second review
# of PR #169 asked why this is not, since $SECTION is already extracted two
# thousand lines up. The answer is what is in that section, measured rather than
# argued. It holds 35 command-shaped spans, 27 of them distinct. Eleven are a
# bare tool name with no command after it and two more are the `gh)` of
# consequence 6's prose about command substitution, so they name no spelling at
# all; and of what is left, the majority are spellings the section REFUSES --
# the three wrapped forms consequence 1 lists, each named precisely because it
# names the right branch or the right base and is refused anyway.
#
# So a derivation would have to read grant from refusal out of the prose around
# each span, and that section is written to be full of near-misses: its whole
# second half is six numbered consequences whose subject is spellings that read
# as permitted and are not, or read as evasions and are permitted. A derivation
# that got one wrong in the permitting direction would put an `ALLOW by all` row
# here for a command CLAUDE.md refuses, which is this suite asserting the
# opposite of the rule it exists to hold. A hand-written list short of a
# spelling leaves that spelling unasked; a derived one wrong about a spelling
# answers for it falsely. Those are not the same cost, and the second is the one
# a green run hides.
#
# WHAT THAT LEAVES OPEN, named because a check is evidence about what it names: a
# spelling added to CLAUDE.md's boundary section, or named in a new refusal
# message, is outside this list until someone adds it here, and a second hook may
# refuse it with this suite green. That is the class #164 came from, and #164 was
# found by reading the messages by hand rather than by any check. Pinning a count
# of the section's command spans was measured as the cheap half of a fix and
# rejected: 11 of the 35 are a bare tool name, so the count moves whenever the
# prose is reflowed around one, which is a false red on CLAUDE.md edits that
# change no rule -- and it would still say nothing about which span is a grant.
# #180 owns what that leaves open, so the gap is tracked rather than only argued
# here; this paragraph is its reasoning and not its resolution.
#
# THE FIRST RUN FOUND ONE, #164. no-commit-to-main.sh refuses a push to main
# with "Push your dev-NN branch and open a PR instead", and no-git-push.sh
# refuses that push from every checkout an agent could stand in -- rightly, by
# US-2. The message is what is wrong, so the right verdict is not ALLOW and
# `gap` cannot express it. It is recorded as a row on the message instead,
# marked a gap: it asserts the sentence is still there, and #164's fix turns it
# red by removing it, which is the outcome `gap` describes. Every other spelling
# below was permitted by all seven on the first run, and so were the three that
# review of this section added: the two gh api creates and the plain commit.
XH_HOOKS=$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[].command' "$SETTINGS" 2>/dev/null \
             | sed 's|.*/||; s|"$||')
# The guard BASH_HOOKS and REGISTRATION both carry, and the one derivation in
# this section that was without it until review of PR #169. It fails green where
# the other two fail red: `every_hook` loops over this list, so an empty one runs
# no hook, leaves `refused` empty, and prints `ok ALLOW by all` for all 41
# spellings -- recording permit-direction coverage for GH-109.5, US-4, US-8,
# US-13, US-14 and FR-48 without a hook having started. The `tok` below would
# turn the run red, so the suite as a whole still catches it; the 41 rows would
# say the opposite anyway, and a row that says the opposite is the thing this
# suite is for. Unreachable today, since the two earlier guards read the same
# file.
[ -n "$XH_HOOKS" ] || {
  echo "no Bash hooks were read out of settings.json; the cross-hook checks below prove nothing" >&2
  exit 1
}
req GH-109.5
tok 'the cross-hook checks run seven hooks, in registered order' \
    'no-commit-to-main.sh alembic-via-uv-group.sh pytest-via-uv-group.sh append-only-docs.sh no-git-push.sh no-pr-decisions.sh no-work-on-stale-branch.sh' \
    "$(printf '%s\n' "$XH_HOOKS" | tr '\n' ' ' | sed 's/ $//')"
need_worktree "$WT_WORK" 'work'
need_worktree "$WT_STALE" 'stale'
[ "$(git -C "$WT_WORK" branch --show-current)" = work-branch ] || {
  echo "the work worktree is not on work-branch; the push spelling below would name the wrong branch" >&2
  exit 1
}
# The push CLAUDE.md grants, and the one no-git-push.sh's bare-push and wrapper
# refusals name.
req GH-109.5 US-4
every_hook "$WT_WORK" 'git push origin <branch> from a linked worktree' 'git push origin work-branch'
# And the commit that precedes it, which no-commit-to-main.sh's and the stale
# guard's refusals both tell an agent to make plainly, on the branch it belongs on.
req GH-109.5
every_hook "$WT_WORK" 'a plain commit on a worktree branch carrying work' 'git commit -m wip'
# CLAUDE.md's pull request grants, and the spellings the base, retarget, review
# and decision refusals name.
req GH-109.5 US-8
every_hook "$WT_WORK" 'gh pr create --base dev-NN' 'gh pr create --base dev-05 --title x --body y'
# CLAUDE.md grants the same base "in whichever of the four spellings is used",
# the two gh api forms included.
every_hook "$WT_WORK" 'the REST create, naming dev-NN' \
  'gh api -X POST repos/o/r/pulls -f base=dev-05 -f head=work-branch -f title=x'
every_hook "$WT_WORK" 'the graphql create, naming dev-NN' \
  'gh api graphql -f query="mutation{createPullRequest(input:{baseRefName:\"dev-05\"})}"'
req GH-109.5 US-13
for c in 'gh pr edit 5 --base dev-05' \
         'gh pr edit 5 --add-label x' \
         'gh pr view 5' \
         'gh pr comment 5 --body x' \
         'gh pr review --comment -b x' \
         'gh api repos/o/r/pulls/5'
do every_hook "$WT_WORK" "$c" "$c"; done
# The release reads CLAUDE.md lists, and the help pages the release refusal names.
req GH-109.5 FR-48
for c in 'gh release list' \
         'gh release view v1' \
         'gh release download v1' \
         'gh release verify v1' \
         'gh release verify-asset v1 a.tgz' \
         'gh help release' \
         'gh help release upload' \
         'gh api repos/o/r/releases'
do every_hook "$WT_WORK" "$c" "$c"; done
# Every gh issue subcommand, #105's twelve and the three pinned before them.
req GH-109.5 US-14
for c in 'gh issue create --title x --body y' \
         'gh issue close 27' \
         'gh issue comment 27 --body x' \
         'gh issue list' \
         'gh issue status' \
         'gh issue view 27' \
         'gh issue reopen 27' \
         'gh issue edit 27 --add-label bug' \
         'gh issue delete 27 --yes' \
         'gh issue transfer 27 o/other' \
         'gh issue lock 27' \
         'gh issue unlock 27' \
         'gh issue pin 27' \
         'gh issue unpin 27' \
         'gh issue develop --list 27'
do every_hook "$WT_WORK" "$c" "$c"; done
# The convention hooks' own remedies: pytest's two, alembic's, and the append the
# append-only refusal names -- into an entry not yet written.
req GH-109.5
for c in 'make test' \
         'uv run --group test pytest tests/test_chunker.py::test_name' \
         'uv run --group migrations alembic upgrade head' \
         'echo entry >> docs/dev-log/devlog_2099-01-01_session-1.md'
do every_hook "$WT_WORK" "$c" "$c"; done
# The two routes CLAUDE.md gives to a worktree branch that starts at the dev tip,
# and the catch-up the stale guard's refusal names -- each where it is written for.
every_hook "$LIFE" 'route 1: git worktree add --no-track -b <branch> <path> origin/dev-NN' \
  'git worktree add --no-track -b wt-new ../wt-new origin/dev-05'
every_hook "$WT_STALE" 'route 2: git reset --hard origin/dev-NN, first act in a new worktree' \
  'git reset --hard origin/dev-05'
every_hook "$WT_STALE" 'the stale guard names git merge <dev branch> as permitted from here' \
  'git merge origin/dev-05'
# #164, the one this section found. See above for why it is a row on the message.
req GH-164
says "$ON_MAIN" no-commit-to-main.sh 'Push your dev-NN branch and open a PR instead.' \
  'the push-to-main refusal names a push no-git-push.sh refuses [gap: #164 removes this sentence; today it is there]' \
  'git push origin main'

echo "--- every hook settings.json registers is run by a tagged check ---"
# A hook registered and never run by any check is a hook this suite says nothing
# about, and every count above would stay green -- the audit's finding, "a
# registered hook with zero checks passes".
#
# AND THE RUN HAS TO BE A CHECK'S OWN. `every_hook` runs whatever this file
# registers under Bash, so its runs are derived from the registration and say
# nothing about whether anyone wrote a check. It fed this record until the third
# review of PR #169, and while it did, this row could not fail for any of the
# seven Bash hooks: register one, write nothing for it, and the row printed `was
# run 41 times under a tag` -- the audit's finding, passing, in the check filed
# to catch it. The by-hand mutation below registered its unchecked hook under
# Edit|Write, the one matcher `every_hook` does not reach, so the evidence
# covered the two hooks this was never in doubt for. `every_hook` no longer
# records; the Bash case is measured below with the rest.
#
# Asked of what the checks actually
# ran, which `ran` records once a tagged check has run one of the hooks under
# judgment and read a verdict out of it, and not of this file's text, where a
# loop over a variable names no hook at all. So it reads the whole run and is
# the last check before #104's.
#
# THE LIMITS, named, both of them.
#
# First: this says a tagged check ran the hook, not that any check of it can
# fail. That is mutation's question.
#
# Second, found by review of PR #169: what `ran` can see is that the hook
# returned a status a running hook returns. It cannot see that the hook did the
# work -- 0 is also what `true` exits with, and a bash syntax error exits 2, the
# case the exit-status contract at the head of this suite already names. What it
# no longer says is the thing review found it saying: `ran` was called from
# `hook_path`, at path resolution, and a path is built by concatenation whether
# the file is there or not, so a deleted or unexecutable hook that checks still
# named was recorded as run and this row printed green over it. It is recorded
# after the status now, and 127 does not count.
#
# MEASURED, 2026-09-20, by hand: a copy of .claude/hooks/ with
# alembic-via-uv-group.sh's shebang pointed at an interpreter that is not there
# -- the file present and executable, and nothing of it ever running -- run
# through $CHECK_HOOKS_DIR. This row went red, "settings.json registers
# alembic-via-uv-group.sh, and no tagged check ran it", where before the change
# it read "was run 207 times under a tag". The other two shapes review named do
# not reach here at all, and that is a fixture guard's doing rather than this
# row's: a hook made unreadable stops the override's own pre-flight, and one
# made unexecutable stops #84's nolib fixture, each before this section runs.
# So the shape this row can be wrong about is the one that was measured, and it
# is the one that was fixed.
# WHAT `ran` RECORDS, asked of `ran` itself. The row below reads the record and
# nothing else, so what the record means is the whole of what that row claims,
# and review of PR #169 found it meaning less than the row said: `ran` was
# called from `hook_path`, before the hook was invoked, so a hook that was not
# there or not executable -- resolved by concatenation, run by nobody, reported
# 127 by bash -- counted as a run. No run of this suite could show that. Every
# other check of such a hook goes red and this row alone goes green, which is
# the shape a check has to be driven directly to catch.
#
# Driven against a scratch record, so the real one is untouched; each call is a
# command substitution and runs in a subshell besides. The expectations are
# literals: a tab, the tag `req` set on the line above, and the name as given.
ran_probe() {  # ran_probe <script|/absolute/hook> <exit status> -- what `ran` writes
  local saved="$RAN" out
  RAN="$FIXTURES/ran-probe"
  : > "$RAN"
  ran "$1" "$2"
  out=$(cat "$RAN")
  RAN="$saved"
  printf '%s\n' "$out"
}
req GH-109.4
tok 'ran records a hook that exited 0, against the tag then in force' \
    $'GH-109.4\tprobe.sh' "$(ran_probe probe.sh 0)"
tok 'ran records a hook that exited 2' \
    $'GH-109.4\tprobe.sh' "$(ran_probe probe.sh 2)"
tok 'ran records nothing for exit 127, which is a hook that never started' \
    '' "$(ran_probe probe.sh 127)"
tok 'ran records nothing for exit 1, which is no verdict either' \
    '' "$(ran_probe probe.sh 1)"
tok 'ran records nothing for a fixture copy, which is not the registered hook' \
    '' "$(ran_probe /nowhere/probe.sh 0)"
# The basename is read off the command field by its suffix rather than by field
# number, because a matcher such as Edit|Write carries the separator itself.
for hook in $(printf '%s\n' "$REGISTRATION" | grep -o '[A-Za-z0-9_.-]*\.sh' | sort -u); do
  n=$(awk -F'\t' -v h="$hook" '$2 == h' "$RAN" | wc -l | tr -d ' ')
  if [ "$n" -gt 0 ]; then
    # Runs, not checks: a timed check runs its hook up to three times, and a
    # cross-hook check runs seven.
    pass static 'derived %s was run %s times under a tag' "$hook" "$n"
  else
    fail static 'settings.json registers %s, and no tagged check ran it' "$hook"
  fi
done

section "=== issue #104: every requirement is covered, and every check says which ==="
# The suite reads requirements.md and the tags every check above carries, and
# fails when the two do not meet. requirements.md says what a requirement is,
# what its fields mean and what covers one; this section is where that is
# computed, and it is the only place.
#
# Every check above is recorded as it prints, with its tags and its direction --
# see `record` near the head of this suite. What is read here is that record,
# and nothing in it is derived by running a hook a second time.
#
# THE KNOWN GAPS ARE MARKED, NOT HIDDEN. An active requirement with no covering
# check fails the suite. #103's audit found several before this section existed,
# and #104 was told to land either with a failing count gated to a later issue
# or with each gap recorded. It records them: an entry whose status is `gap` and
# names the issue that owns it is listed by --matrix and not asked about here.
# The trade, taken knowingly: a gap that has since been covered stays marked
# until someone takes the marker off, which errs toward claiming less coverage
# than there is, and the matrix says of such a gap that its tags now meet
# coverage, so whoever owns it can see the marker is ready to come off. A check
# that failed a covered gap was considered and rejected,
# because a gap is often a requirement covered in part -- a story whose message
# is checked for one hook and not for two others -- and coverage here is one bit
# per ID.
#
# WHAT THIS IS NOT EVIDENCE OF, named because a check is evidence about what it
# names. A tag says a check establishes a requirement; nothing here can say the
# check is right about it, or that the checks tagged together are all of what the
# requirement asks. Coverage is the floor -- a refusing and a permitting check,
# or a declared direction -- and not the whole requirement. Whether the checks
# can fail is mutation's question, which this section does not ask.
#
# The logic is one awk program, run in two modes: `findings` prints one line per
# finding, each carrying the IDs it establishes, and `matrix` prints every
# requirement with its checks. It is driven below against a fixture first, with
# every expectation a literal, and only then against this repository -- so a
# finding that would pass by computing nothing is red before it is trusted.
#
# The number of acceptance criteria each of #36's stage tickets has, counted off
# the issues and not off requirements.md, which is what makes a criterion deleted
# from the provenance section fail rather than shorten the count it is held to.
PROVENANCE_COUNTS='37:8 38:6 39:6 40:13 41:8'
# THE SHAPE OF requirements.md, as a literal: every entry by ID, and beside each
# one whatever takes it off the both-directions rule -- a status other than
# active, a declared direction, and `seam: none` with the kind of its `verify`.
# Those three are everything the coverage check reads off an entry, so an edit
# to requirements.md that changes what the check asks of any requirement changes
# this literal: a marker added, taken off or moved to another entry, a direction
# declared, a move to no seam, a deletion. Each of those turned an uncovered
# requirement green with no finding at all.
#
# The first two versions of this held counts: of gaps and reviews, after review
# of #104, then of every family, status and verify kind, after Bertan's review
# of the pull request. Bertan's re-review found the two routes no count sees. A
# direction declared moved no number the literal held, and a gap marker moved
# from one entry to another leaves every count where it was. A count says how
# many entries are off the rule, and only a list says which. The change is
# written down twice, once in requirements.md and once here, and the second copy
# is the one a reviewer sees move in the diff. The refusing direction, one edit
# away.
#
# What it does not hold, named. The tags: a check tagged with an ID it does not
# establish covers that ID all the same, and only reading the check says so. And
# the direction each check records, which is this file's code, not
# requirements.md's.
REQUIREMENT_SHAPE='
US-1:refuse-only US-2:refuse-only US-3 US-4:permit-only US-5:gap,runbook
US-6:gap,runbook US-7:refuse-only US-8 US-9 US-10 US-11 US-12
US-13:permit-only US-14:permit-only US-15 US-16:static US-17:review
US-18:review US-19:static US-20:static US-21:review US-22:static
US-23:static US-24:static US-25 US-26:static US-27:static US-28:static
US-29:static US-30:review US-31:static US-32:review
FR-1:superseded-by FR-2:static FR-3 FR-4 FR-5:review FR-6:static
FR-7:drifted FR-8:review FR-9:review FR-10:review FR-11:static FR-12:retired
FR-13:review FR-14 FR-15 FR-16 FR-17 FR-18 FR-19 FR-20 FR-21 FR-22:static
FR-23:refuse-only FR-24:static FR-25:static FR-26:static
FR-27:static FR-28:static FR-29:static FR-30:review FR-31:drifted
FR-32:review FR-33:static FR-34:superseded-by FR-35:static FR-36:review
FR-37:static FR-38 FR-39:gap,runbook FR-40:static FR-41:static FR-42:static
FR-43:static FR-44:static FR-45:static FR-46:static FR-47:static FR-48 FR-49
GH-43.1 GH-43.2 GH-43.3 GH-43.4 GH-43.5:refuse-only GH-43.6 GH-44.1 GH-44.2
GH-44.3 GH-44.4 GH-44.5 GH-44.6 GH-44.7:static GH-47.1 GH-47.2:refuse-only
GH-50.1 GH-50.2:refuse-only GH-50.3 GH-51.1 GH-51.2 GH-58.1 GH-58.2:static
GH-61:tests GH-62:static GH-63:static GH-68.1 GH-68.2 GH-68.3:refuse-only
GH-69.1 GH-69.2 GH-69.3 GH-70.1:static GH-70.2:static GH-70.3:static
GH-71:static GH-72 GH-73 GH-79.1 GH-79.2 GH-79.3:permit-only GH-79.4 GH-84.1
GH-84.2:static GH-84.3:static GH-94.1 GH-94.2 GH-94.3:review GH-94.4 GH-95.1
GH-95.2 GH-96.1 GH-96.2:static GH-96.3:static GH-97.1 GH-97.2:refuse-only
GH-98:static GH-99.1:static GH-99.2:static GH-99.3:static GH-100:static
GH-101:static GH-102:static GH-104.1:static GH-104.2:static GH-104.3:static
GH-104.4:static GH-104.5:review GH-106:static GH-117 GH-117.1:permit-only
GH-118:gap
GH-124:static GH-127:gap GH-130:gap
GH-131:gap GH-133:refuse-only GH-134:gap GH-135:gap GH-136:gap GH-139                  
GH-107.1:static GH-107.2:static GH-137.1 GH-137.2 GH-143.4:static GH-143.5:static      
GH-108.1 GH-108.2 GH-108.3 GH-108.4 GH-108.5 GH-108.6 GH-108.7                         
GH-108.8:static GH-108.9:static GH-108.10:static GH-156:gap GH-141:static
GH-128 GH-171:gap
GH-155.1:static
GH-109.1:static GH-109.2:refuse-only GH-109.3:static GH-109.4:static
GH-109.5:permit-only GH-164:gap
'
# `trim`, `keyword` and `after_colon` are not here: they are requirements.md's
# field grammar, which the #106 section reads too, and they live in
# REQ_FIELD_AWK above, prepended to this program by `requirements_read`.
REQUIREMENTS_AWK=$(cat <<'AWK'
  function emit(res, tags, text) { printf "%s\t%s\t%s\n", res, tags, text }
  function get(id, key) { return ((id, key) in field) ? field[id, key] : "" }
  function open_entry(id) {
    cur = id; curpart = part; lastkey = ""
    if (part == "req") {
      if (id in isreq) problem[++nproblem] = id ": the ID is used twice"
      else { isreq[id] = 1; order[++nreq] = id }
      if (id ~ /^GH-[0-9]+\.[0-9]+$/) { b = id; sub(/^GH-/, "", b); sub(/\..*$/, "", b); ghbase[b] = 1 }
      else if (id ~ /^GH-[0-9]+$/) { b = id; sub(/^GH-/, "", b); ghbase[b] = 1 }
      else if (id !~ /^(US|FR)-[0-9]+$/) problem[++nproblem] = id ": not an ID of the US, FR or GH family"
    } else if (part == "prov") {
      if (id ~ /^#[0-9]+\.[0-9]+$/) {
        crit[++ncrit] = id
        b = id; sub(/^#/, "", b); sub(/\..*$/, "", b); ccount[b]++
      } else problem[++nproblem] = id ": a provenance heading that names no criterion"
    }
  }
  function covered(id,   d, r, p, s) {
    if (get(id, "seam") == "none") return 1
    d = keyword(get(id, "direction")); r = cnt[id, "refuse"] + 0; p = cnt[id, "permit"] + 0; s = cnt[id, "static"] + 0
    if (d == "refuse-only") return r > 0
    if (d == "permit-only") return p > 0
    if (d == "static") return r + p + s > 0
    return r > 0 && p > 0
  }
  function counts(id) {
    return (cnt[id, "refuse"] + 0) " refusing, " (cnt[id, "permit"] + 0) " permitting, " (cnt[id, "static"] + 0) " static"
  }
  BEGIN {
    H = "#"
    # --- the requirements file ---------------------------------------------------
    part = ""; cur = ""
    while ((getline line < reqs) > 0) {
      if (line ~ /^## /) {
        cur = ""; heading = substr(line, 4)
        if (line ~ /^## Provenance/) part = "prov"
        else if (line ~ /^## Citations that are not requirements/) part = "cite"
        else if (line ~ /^## (User stories|Functional requirements|Boundary issues)$/) part = "req"
        else part = "other"
        continue
      }
      if (line ~ /^### /) {
        if (part == "req" || part == "prov") open_entry(trim(substr(line, 5)))
        else {
          cur = ""; hid = trim(substr(line, 5))
          if (hid ~ /^(US|FR|GH)-[0-9]/ || hid ~ /^#[0-9]+\.[0-9]+$/)
            problem[++nproblem] = hid ": an entry under the heading \"" heading "\", where no entry is read"
        }
        continue
      }
      if (part == "cite" && line ~ /^- #[0-9]+: ./) {
        n = line; sub(/^- #/, "", n); sub(/:.*$/, "", n); exempt[n] = 1
        continue
      }
      if (cur != "" && line ~ /^- [a-z-]+:/) {
        key = line; sub(/^- /, "", key); sub(/:.*$/, "", key)
        val = line; sub(/^- [a-z-]+:/, "", val); val = trim(val)
        if ((cur, key) in field) problem[++nproblem] = cur ": the field " key " is given twice"
        field[cur, key] = val; lastkey = key
        continue
      }
      if (cur != "" && lastkey != "" && line ~ /^  [^ ]/) {
        field[cur, lastkey] = field[cur, lastkey] " " trim(line)
        continue
      }
      if (line !~ /^[ \t]*$/) lastkey = ""
    }
    close(reqs)
    runbook_read = 0
    while ((getline line < runbook) > 0) {
      runbook_read = 1
      if (line ~ /^## §[0-9]+( |$)/) { s = line; sub(/^## §/, "", s); sub(/[^0-9].*$/, "", s); rbsec[s] = 1 }
    }
    close(runbook)

    # --- the entries -------------------------------------------------------------
    for (i = 1; i <= nreq; i++) {
      id = order[i]
      if (get(id, "text") == "") problem[++nproblem] = id ": no text"
      if (get(id, "from") == "") problem[++nproblem] = id ": no from"
      st = get(id, "status"); kw = keyword(st)
      if (st == "") problem[++nproblem] = id ": no status"
      else if (kw == "active") { if (st != "active") problem[++nproblem] = id ": active carries nothing after it" }
      else if (kw == "retired" || kw == "drifted") { if (after_colon(st) == "") problem[++nproblem] = id ": " kw " with no reason" }
      else if (kw == "superseded-by") { tgt = after_colon(st); if (!(tgt in isreq)) problem[++nproblem] = id ": superseded by " tgt ", which is not a requirement" }
      else if (kw == "gap") { if (st !~ /^gap → #[0-9]+$/) problem[++nproblem] = id ": a gap names no issue that owns it" }
      else problem[++nproblem] = id ": the status " kw " is not one this file defines"
      k = get(id, "kind")
      if (id ~ /^GH-/) { if (k != "defect-permitting" && k != "defect-refusing" && k != "doc-claim") problem[++nproblem] = id ": the kind " (k == "" ? "is missing" : k " is not one this file defines") }
      else if ((id, "kind") in field) problem[++nproblem] = id ": a kind on an entry that is not a GH- one"
      if ((id, "direction") in field) {
        d = get(id, "direction"); dk = keyword(d)
        if (dk != "refuse-only" && dk != "permit-only" && dk != "static") problem[++nproblem] = id ": the direction " dk " is not one this file defines"
        else if (after_colon(d) == "") problem[++nproblem] = id ": the direction " dk " gives no reason"
      }
      hasseam = (id, "seam") in field; hasverify = (id, "verify") in field
      if (hasseam && get(id, "seam") != "none") problem[++nproblem] = id ": the seam is " get(id, "seam") ", and none is the only value"
      if (hasseam != hasverify) problem[++nproblem] = id ": seam and verify come together or not at all"
      if (hasseam && hasverify && kw != "gap") {
        v = get(id, "verify")
        if (v == "review") { }
        else if (v ~ /^tests\/[A-Za-z0-9_.-]+\.py$/) { vf = root "/" v; if ((getline x < vf) < 0) problem[++nproblem] = id ": verify names " v ", which is not there"; close(vf) }
        else if (v ~ /^runbook §[0-9]+$/) { s = v; sub(/^runbook §/, "", s); if (!(s in rbsec)) problem[++nproblem] = id ": verify names runbook §" s ", which " (runbook_read ? "has no such section" : "is not written") }
        else problem[++nproblem] = id ": verify is " v ", which is none of review, tests/<file>.py and runbook §<n>"
      }
    }

    # --- the provenance ----------------------------------------------------------
    for (i = 1; i <= ncrit; i++) {
      c = crit[i]
      if (get(c, "criterion") == "") provproblem[++nprov] = c " quotes no criterion"
      hasmaps = (c, "maps") in field; hasdropped = (c, "dropped") in field
      if (hasmaps && hasdropped) provproblem[++nprov] = c " is both mapped and dropped"
      else if (!hasmaps && !hasdropped) provproblem[++nprov] = c " is neither mapped nor dropped"
      else if (hasdropped && get(c, "dropped") == "") provproblem[++nprov] = c " is dropped with no reason"
      else if (hasmaps) {
        m = split(get(c, "maps"), ids, /, */)
        if (m == 0) provproblem[++nprov] = c " maps to nothing"
        for (j = 1; j <= m; j++) if (!(ids[j] in isreq)) provproblem[++nprov] = c " maps to " ids[j] ", which is not a requirement"
      }
    }
    m = split(counts_literal, pairs, " ")
    for (j = 1; j <= m; j++) {
      split(pairs[j], kv, ":")
      if ((ccount[kv[1]] + 0) != kv[2] + 0) provproblem[++nprov] = H kv[1] " has " (ccount[kv[1]] + 0) " criteria here, where the issue has " kv[2]
    }

    # --- the ledger --------------------------------------------------------------
    while ((getline line < ledger) > 0) {
      nres++
      split(line, f, "\t")
      if (f[1] == "") untagged[++nuntagged] = f[4]
      if (f[2] != "refuse" && f[2] != "permit" && f[2] != "static") baddir[++nbaddir] = f[2] ": " f[4]
      nt = split(f[1], t, " ")
      for (j = 1; j <= nt; j++) {
        if (t[j] in isreq) {
          cnt[t[j], f[2]]++
          checks[t[j]] = checks[t[j]] "\n    " (f[3] == "ok" ? "ok  " : "FAIL") " " f[4]
        } else if (!(t[j] in unknown)) { unknown[t[j]] = f[4]; unknownorder[++nunknown] = t[j] }
      }
    }
    close(ledger)
    # A requirement no check can reach that has checks after all is saying two
    # things, and the one that lets the coverage check pass is the one believed.
    for (i = 1; i <= nreq; i++) {
      id = order[i]
      if (get(id, "seam") == "none" && cnt[id, "refuse"] + cnt[id, "permit"] + cnt[id, "static"] > 0)
        problem[++nproblem] = id ": seam: none, and " counts(id) " are tagged with it"
    }
    # --- the shape -----------------------------------------------------------------
    # An entry is its ID, and beside it, comma-joined, whatever the coverage check
    # reads off it that departs from the both-directions rule: status, direction,
    # then the kind of verify a seam-less entry names. The two sides are compared
    # as sets, so a finding names the entries that changed and not the whole of
    # both.
    for (i = 1; i <= nreq; i++) {
      id = order[i]; marks = ""
      kw = keyword(get(id, "status"))
      if (kw != "active") marks = kw
      if ((id, "direction") in field) marks = marks (marks == "" ? "" : ",") keyword(get(id, "direction"))
      if (get(id, "seam") == "none") {
        v = get(id, "verify")
        if (v == "review") vk = "review"
        else if (v ~ /^tests\//) vk = "tests"
        else if (v ~ /^runbook /) vk = "runbook"
        else vk = "none"
        marks = marks (marks == "" ? "" : ",") vk
      }
      if (marks != "") noffrule++
      filetok[i] = id (marks == "" ? "" : ":" marks)
      infile[filetok[i]] = 1
    }
    lit = shape_literal; gsub(/^[ \t\n]+|[ \t\n]+$/, "", lit)
    nlit = (lit == "") ? 0 : split(lit, littok, /[ \t\n]+/)
    for (j = 1; j <= nlit; j++) inlit[littok[j]] = 1
    onlyfile = ""; onlylit = ""
    for (i = 1; i <= nreq; i++) if (!(filetok[i] in inlit)) onlyfile = onlyfile " " filetok[i]
    for (j = 1; j <= nlit; j++) if (!(littok[j] in infile)) onlylit = onlylit " " littok[j]

    # --- the citations -----------------------------------------------------------
    while ((getline line < suite) > 0) {
      s = line
      while (match(s, /#[0-9]+/)) {
        n = substr(s, RSTART + 1, RLENGTH - 1); s = substr(s, RSTART + RLENGTH)
        if (!(n in cited)) { cited[n] = 1; citedorder[++ncited] = n }
      }
    }
    close(suite)

    if (mode == "matrix") {
      ncovered = 0; nactive = 0; ngap = 0
      for (i = 1; i <= nreq; i++) {
        id = order[i]; kw = keyword(get(id, "status"))
        if (kw == "active") { nactive++; if (covered(id)) ncovered++ }
        if (kw == "gap") ngap++
      }
      printf "requirements matrix: %d requirements; %d active, %d of them covered; %d marked a gap; %d check results recorded\n", nreq, nactive, ncovered, ngap, nres
      for (i = 1; i <= nreq; i++) {
        id = order[i]; st = get(id, "status"); kw = keyword(st)
        if (kw == "active") mverdict = covered(id) ? "covered" : "NOT COVERED"
        else if (kw == "gap" && get(id, "seam") != "none" && covered(id)) mverdict = "not asked, though its tags now meet coverage"
        else mverdict = "not asked"
        extra = ""
        if ((id, "direction") in field) extra = extra ", " keyword(get(id, "direction"))
        if (get(id, "seam") == "none") extra = extra ", seam: none, verify: " get(id, "verify")
        printf "\n%s  %s  %s (%s%s)", id, st, mverdict, counts(id), extra
        printf "%s\n", checks[id]
      }
      exit
    }

    if (nreq == 0) emit("FAIL", "FR-45", "nothing was read out of the requirements file, so every finding below is evidence of nothing")
    else emit("ok", "FR-45", "the requirements file holds " nreq " requirements and " ncrit " criteria")
    if (nproblem == 0) emit("ok", "FR-45", "every requirement entry is well formed")
    for (i = 1; i <= nproblem; i++) emit("FAIL", "FR-45", problem[i])
    if (nunknown == 0) emit("ok", "GH-104.2", "every tag names a requirement")
    for (i = 1; i <= nunknown; i++) emit("FAIL", "GH-104.2", "a check is tagged " unknownorder[i] ", which is not in the requirements file: " unknown[unknownorder[i]])
    if (nres == 0) emit("FAIL", "GH-104.1", "no check result was recorded, so no tag was read")
    else if (nuntagged == 0 && nbaddir == 0) emit("ok", "GH-104.1", "every check carries a tag and a direction")
    for (i = 1; i <= nuntagged; i++) emit("FAIL", "GH-104.1", "a check carries no tag: " untagged[i])
    for (i = 1; i <= nbaddir; i++) emit("FAIL", "GH-104.1", "a check records a direction that is none of refuse, permit and static: " baddir[i])
    nuncovered = 0
    for (i = 1; i <= nreq; i++) {
      id = order[i]
      if (get(id, "status") != "active" || covered(id)) continue
      nuncovered++
      d = keyword(get(id, "direction"))
      emit("FAIL", "FR-46 FR-33", id " is active and not covered: " counts(id) (d == "" ? "" : ", declared " d))
    }
    if (nuncovered == 0) emit("ok", "FR-46 FR-33", "every active requirement is covered")
    if (onlyfile == "" && onlylit == "")
      emit("ok", "FR-45 FR-46", "requirements.md has the shape this suite holds: " nreq " entries by ID, " (noffrule + 0) " of them off the both-directions rule")
    else {
      shapemsg = "requirements.md has changed shape"
      if (onlyfile != "") shapemsg = shapemsg "; only it holds" onlyfile
      if (onlylit != "") shapemsg = shapemsg "; only this suite holds" onlylit
      emit("FAIL", "FR-45 FR-46", shapemsg)
    }
    if (nprov == 0) emit("ok", "FR-47", "every stage-ticket criterion is carried or dropped, and each ticket has all of its criteria")
    for (i = 1; i <= nprov; i++) emit("FAIL", "FR-47", provproblem[i])
    nbad = 0
    for (i = 1; i <= ncited; i++) {
      n = citedorder[i]
      if ((n in exempt) || (n in ghbase)) continue
      nbad++
      emit("FAIL", "GH-104.3", "the suite cites " H n ", which has no entry and no reason")
    }
    if (nbad == 0) emit("ok", "GH-104.3", "every issue the suite cites has an entry or a reason")
  }
AWK
)
requirements_read() {  # requirements_read <findings|matrix> <requirements> <ledger> <suite> <root> <runbook> <counts> <shape>
  awk -v mode="$1" -v reqs="$2" -v ledger="$3" -v suite="$4" -v root="$5" \
      -v runbook="$6" -v counts_literal="$7" -v shape_literal="$8" \
      "$REQ_FIELD_AWK$REQUIREMENTS_AWK" </dev/null
}

echo "--- the findings, against a fixture whose every answer is written here ---"
# The fixture holds one requirement of each shape the rules distinguish: a story
# covered in both directions, a one-sided one, a static one whose only check
# failed (a failed check still covers; its failure is its own line above), one
# with no seam, a gap, a superseded one, and a GH sub-issue that is permit-only.
# `#` is spelled through H wherever a number follows it, because this suite's
# own citations are read by the same program and a fixture citation is not one.
H='#'
REQ_FIX="$FIXTURES/requirements-fixture"
mkdir -p "$REQ_FIX/clean/root/tests"
: > "$REQ_FIX/clean/root/tests/present.py"
cat > "$REQ_FIX/clean/requirements.md" <<REQS
# A fixture

## What covers a requirement

### not an entry, because this section holds none

## User stories

### US-1
- text: a story covered in both directions
- from: the fixture
- status: active

### US-2
- text: a story that is one-sided
- from: the fixture
- status: active
- direction: refuse-only: a reason

## Functional requirements

### FR-1
- text: a requirement about what a file says,
  continued on a second line
- from: the fixture
- status: active
- direction: static: a reason

### FR-2
- text: a requirement no check reaches
- from: the fixture
- status: active
- seam: none
- verify: tests/present.py

### FR-3
- text: a gap
- from: the fixture
- status: gap → ${H}7

### FR-4
- text: a requirement replaced by another
- from: the fixture
- status: superseded-by: FR-1

## Boundary issues

### GH-5.1
- text: a sub-issue that is permit-only
- from: the fixture
- kind: defect-permitting
- status: active
- direction: permit-only: a reason

## Provenance: the fixture's criteria

### ${H}37.1
- criterion: a criterion
- maps: US-1, FR-1

### ${H}37.2
- criterion: another
- dropped: a reason

## Citations that are not requirements

- ${H}9: a reason
REQS
printf '%s\t%s\t%s\t%s\n' \
  'US-1' refuse ok 'BLOCK one' \
  'US-1 GH-5.1' permit ok 'ALLOW two' \
  'US-2' refuse ok 'says three' \
  'FR-1' static FAIL 'tok four' > "$REQ_FIX/clean/ledger"
printf 'a suite citing %s5 and %s9\n' "$H" "$H" > "$REQ_FIX/clean/suite"
FIX_SHAPE='US-1 US-2:refuse-only FR-1:static FR-2:tests FR-3:gap FR-4:superseded-by GH-5.1:permit-only'
req_fixture() {  # req_fixture <dir> -- the findings for the fixture in <dir>
  requirements_read findings "$1/requirements.md" "$1/ledger" "$1/suite" \
    "$1/root" "$1/runbook.md" '37:2' "$FIX_SHAPE"
}
# A mutant is the clean fixture with one file edited, and the edit is asserted to
# have taken: a sed that matched nothing leaves the clean fixture, and every FAIL
# expected of it would be missing for that reason rather than the one it names.
req_mutant() {  # req_mutant <name> <file> <sed script> -- prints the mutant's directory
  local dir="$REQ_FIX/$1"
  cp -r "$REQ_FIX/clean" "$dir"
  sed -i -e "$3" "$dir/$2"
  if cmp -s "$REQ_FIX/clean/$2" "$dir/$2"; then
    echo "the requirements mutant $1 did not change $2; the checks against it prove nothing" >&2
    exit 1
  fi
}
TAB=$'\t'

req GH-104.1 GH-104.2 GH-104.3 FR-45 FR-46 FR-47 FR-33
tok 'the clean fixture: every finding holds, one line each' \
"ok${TAB}FR-45${TAB}the requirements file holds 7 requirements and 2 criteria
ok${TAB}FR-45${TAB}every requirement entry is well formed
ok${TAB}GH-104.2${TAB}every tag names a requirement
ok${TAB}GH-104.1${TAB}every check carries a tag and a direction
ok${TAB}FR-46 FR-33${TAB}every active requirement is covered
ok${TAB}FR-45 FR-46${TAB}requirements.md has the shape this suite holds: 7 entries by ID, 6 of them off the both-directions rule
ok${TAB}FR-47${TAB}every stage-ticket criterion is carried or dropped, and each ticket has all of its criteria
ok${TAB}GH-104.3${TAB}every issue the suite cites has an entry or a reason" \
  "$(req_fixture "$REQ_FIX/clean")"

# The four mutations #104 names, each one edit to one file of the fixture.
req FR-46 FR-33
req_mutant drop-a-tag ledger 's/^US-1 GH-5.1\t/GH-5.1\t/'
OUT=$(req_fixture "$REQ_FIX/drop-a-tag")
holds 'a tag dropped from the only permitting check leaves its requirement uncovered' "$OUT" \
  "FAIL${TAB}FR-46 FR-33${TAB}US-1 is active and not covered: 1 refusing, 0 permitting, 0 static"
lacks 'and the suite does not also say every requirement is covered' "$OUT" 'every active requirement is covered'
req GH-104.2
req_mutant unknown-tag ledger 's/^US-2\t/US-9\t/'
OUT=$(req_fixture "$REQ_FIX/unknown-tag")
holds 'a tag naming an ID not in the file fails, and names the check carrying it' "$OUT" \
  "FAIL${TAB}GH-104.2${TAB}a check is tagged US-9, which is not in the requirements file: says three"
lacks 'and the suite does not also say every tag names a requirement' "$OUT" 'every tag names a requirement'
req FR-47
req_mutant delete-a-mapping requirements.md '/^- maps: US-1, FR-1$/d'
OUT=$(req_fixture "$REQ_FIX/delete-a-mapping")
holds 'a criterion whose mapping is deleted fails' "$OUT" \
  "FAIL${TAB}FR-47${TAB}${H}37.1 is neither mapped nor dropped"
lacks 'and the provenance is not called whole' "$OUT" 'every stage-ticket criterion is carried'
req GH-104.3
req_mutant cite-unknown suite "s/${H}9/${H}6/"
OUT=$(req_fixture "$REQ_FIX/cite-unknown")
holds 'a number the suite cites with no entry and no reason fails' "$OUT" \
  "FAIL${TAB}GH-104.3${TAB}the suite cites ${H}6, which has no entry and no reason"
lacks 'and the citations are not called answered' "$OUT" 'every issue the suite cites has an entry'

# The rest of what the file's rules say fails, one mutant each.
req GH-104.1
req_mutant untagged ledger 's/^FR-1\t/\t/'
OUT=$(req_fixture "$REQ_FIX/untagged")
holds 'a check with no tag fails, and is named' "$OUT" \
  "FAIL${TAB}GH-104.1${TAB}a check carries no tag: tok four"
lacks 'and the suite does not also say every check carries one' "$OUT" 'every check carries a tag'
printf '' > "$REQ_FIX/empty-ledger"
OUT=$(requirements_read findings "$REQ_FIX/clean/requirements.md" "$REQ_FIX/empty-ledger" \
        "$REQ_FIX/clean/suite" "$REQ_FIX/clean/root" "$REQ_FIX/clean/runbook.md" '37:2' "$FIX_SHAPE")
holds 'a ledger that recorded nothing fails, rather than having no untagged check in it' "$OUT" \
  "FAIL${TAB}GH-104.1${TAB}no check result was recorded, so no tag was read"
req FR-46 FR-33
req_mutant no-direction requirements.md '/^- direction: refuse-only: a reason$/d'
OUT=$(req_fixture "$REQ_FIX/no-direction")
holds 'a one-sided story that stops declaring it needs a permitting check' "$OUT" \
  "FAIL${TAB}FR-46 FR-33${TAB}US-2 is active and not covered: 1 refusing, 0 permitting, 0 static"
req_mutant permit-only-refused ledger 's/^US-1 GH-5.1\tpermit\t/US-1 GH-5.1\trefuse\t/'
OUT=$(req_fixture "$REQ_FIX/permit-only-refused")
holds 'a permit-only requirement is not covered by a refusing check' "$OUT" \
  "FAIL${TAB}FR-46 FR-33${TAB}GH-5.1 is active and not covered: 1 refusing, 0 permitting, 0 static, declared permit-only"
req_mutant static-unchecked ledger '/^FR-1\t/d'
OUT=$(req_fixture "$REQ_FIX/static-unchecked")
holds 'a static requirement with no check at all is not covered' "$OUT" \
  "FAIL${TAB}FR-46 FR-33${TAB}FR-1 is active and not covered: 0 refusing, 0 permitting, 0 static, declared static"
req_mutant gap-activated requirements.md "s/^- status: gap → ${H}7$/- status: active/"
OUT=$(req_fixture "$REQ_FIX/gap-activated")
holds 'a gap marked active is asked about like any other' "$OUT" \
  "FAIL${TAB}FR-46 FR-33${TAB}FR-3 is active and not covered: 0 refusing, 0 permitting, 0 static"
req FR-47
req_mutant map-unknown requirements.md 's/^- maps: US-1, FR-1$/- maps: US-1, FR-9/'
OUT=$(req_fixture "$REQ_FIX/map-unknown")
holds 'a mapping naming an ID not in the file fails' "$OUT" \
  "FAIL${TAB}FR-47${TAB}${H}37.1 maps to FR-9, which is not a requirement"
req_mutant criterion-deleted requirements.md "/^### ${H}37.2$/,/^- dropped: a reason$/d"
OUT=$(req_fixture "$REQ_FIX/criterion-deleted")
holds 'a criterion deleted whole fails on the count the issue has' "$OUT" \
  "FAIL${TAB}FR-47${TAB}${H}37 has 1 criteria here, where the issue has 2"
req FR-45
req_mutant used-twice requirements.md 's/^### US-2$/### US-1/'
OUT=$(req_fixture "$REQ_FIX/used-twice")
holds 'an ID used twice fails' "$OUT" "FAIL${TAB}FR-45${TAB}US-1: the ID is used twice"
req_mutant out-of-family requirements.md 's/^### FR-4$/### XR-4/'
OUT=$(req_fixture "$REQ_FIX/out-of-family")
holds 'a heading outside the three families fails' "$OUT" \
  "FAIL${TAB}FR-45${TAB}XR-4: not an ID of the US, FR or GH family"
req_mutant unknown-status requirements.md '0,/^- status: active$/s//- status: pending/'
OUT=$(req_fixture "$REQ_FIX/unknown-status")
holds 'a status the file does not define fails' "$OUT" \
  "FAIL${TAB}FR-45${TAB}US-1: the status pending is not one this file defines"
req_mutant superseded-unknown requirements.md 's/^- status: superseded-by: FR-1$/- status: superseded-by: FR-9/'
OUT=$(req_fixture "$REQ_FIX/superseded-unknown")
holds 'a supersession naming no entry fails' "$OUT" \
  "FAIL${TAB}FR-45${TAB}FR-4: superseded by FR-9, which is not a requirement"
req_mutant no-kind requirements.md '/^- kind: defect-permitting$/d'
OUT=$(req_fixture "$REQ_FIX/no-kind")
holds 'a GH entry with no kind fails' "$OUT" "FAIL${TAB}FR-45${TAB}GH-5.1: the kind is missing"
req_mutant no-reason requirements.md 's/^- direction: static: a reason$/- direction: static:/'
OUT=$(req_fixture "$REQ_FIX/no-reason")
holds 'a direction declared with no reason fails' "$OUT" \
  "FAIL${TAB}FR-45${TAB}FR-1: the direction static gives no reason"
req_mutant verify-absent requirements.md 's|^- verify: tests/present.py$|- verify: tests/absent.py|'
OUT=$(req_fixture "$REQ_FIX/verify-absent")
holds 'a seam-less requirement verified by a test that is not there fails' "$OUT" \
  "FAIL${TAB}FR-45${TAB}FR-2: verify names tests/absent.py, which is not there"
req_mutant verify-runbook requirements.md 's|^- verify: tests/present.py$|- verify: runbook §1|'
OUT=$(req_fixture "$REQ_FIX/verify-runbook")
holds 'a runbook section with no runbook written fails' "$OUT" \
  "FAIL${TAB}FR-45${TAB}FR-2: verify names runbook §1, which is not written"
printf '## §1 the fork point\n' > "$REQ_FIX/verify-runbook/runbook.md"
OUT=$(req_fixture "$REQ_FIX/verify-runbook")
lacks 'and passes once the runbook has that section' "$OUT" 'verify names runbook'
# Found by review of #104, each with the suite green before it.
req_mutant renamed-heading requirements.md 's/^## Functional requirements$/## Functional requirements (hooks)/'
OUT=$(req_fixture "$REQ_FIX/renamed-heading")
holds 'a renamed family heading does not make its entries vanish' "$OUT" \
  "FAIL${TAB}FR-45${TAB}FR-1: an entry under the heading \"Functional requirements (hooks)\", where no entry is read"
req_mutant seam-with-checks ledger 's/^FR-1\tstatic\t/FR-1 FR-2\tstatic\t/'
OUT=$(req_fixture "$REQ_FIX/seam-with-checks")
holds 'a requirement no check can reach, with a check tagged with it, fails' "$OUT" \
  "FAIL${TAB}FR-45${TAB}FR-2: seam: none, and 0 refusing, 0 permitting, 1 static are tagged with it"
req_mutant verify-a-directory requirements.md 's|^- verify: tests/present.py$|- verify: tests/|'
OUT=$(req_fixture "$REQ_FIX/verify-a-directory")
holds 'a verify naming a directory is refused before it is read, which would abort the program' "$OUT" \
  "FAIL${TAB}FR-45${TAB}FR-2: verify is tests/, which is none of review, tests/<file>.py and runbook §<n>"
req GH-104.1
req_mutant misspelled-direction ledger 's/^US-2\trefuse\t/US-2\trefues\t/'
OUT=$(req_fixture "$REQ_FIX/misspelled-direction")
holds 'a check recording a direction that is not one fails' "$OUT" \
  "FAIL${TAB}GH-104.1${TAB}a check records a direction that is none of refuse, permit and static: refues: says three"
# Every route out of the coverage check changes the shape, one mutant each. The
# first two were closed after review of #104, the next four after Bertan's
# review of its pull request, and the last two after Bertan's re-review found
# them green against a literal of counts: a direction declared, and a gap marker
# moved from one entry to another.
req FR-45 FR-46
req_mutant gap-added requirements.md 's/^- status: superseded-by: FR-1$/- status: gap → '"${H}"'8/'
OUT=$(req_fixture "$REQ_FIX/gap-added")
holds 'an entry marked a gap changes the shape this suite holds' "$OUT" \
  "FAIL${TAB}FR-45 FR-46${TAB}requirements.md has changed shape; only it holds FR-4:gap; only this suite holds FR-4:superseded-by"
req_mutant review-added requirements.md 's|^- verify: tests/present.py$|- verify: review|'
OUT=$(req_fixture "$REQ_FIX/review-added")
holds 'and so does an entry moved to verification by review' "$OUT" \
  "FAIL${TAB}FR-45 FR-46${TAB}requirements.md has changed shape; only it holds FR-2:review; only this suite holds FR-2:tests"
req_mutant retired-marked requirements.md '/^### GH-5.1$/,/^- direction:/s/^- status: active$/- status: retired: a reason/'
OUT=$(req_fixture "$REQ_FIX/retired-marked")
holds 'and an active entry marked retired' "$OUT" \
  "FAIL${TAB}FR-45 FR-46${TAB}requirements.md has changed shape; only it holds GH-5.1:retired,permit-only; only this suite holds GH-5.1:permit-only"
req_mutant drifted-marked requirements.md '/^### GH-5.1$/,/^- direction:/s/^- status: active$/- status: drifted: some evidence/'
OUT=$(req_fixture "$REQ_FIX/drifted-marked")
holds 'and one marked drifted' "$OUT" \
  "FAIL${TAB}FR-45 FR-46${TAB}requirements.md has changed shape; only it holds GH-5.1:drifted,permit-only; only this suite holds GH-5.1:permit-only"
req_mutant tests-verified requirements.md 's/^- direction: refuse-only: a reason$/- seam: none\n- verify: tests\/present.py/'
OUT=$(req_fixture "$REQ_FIX/tests-verified")
holds 'and one moved to no seam, verified by a test file that is there' "$OUT" \
  "FAIL${TAB}FR-45 FR-46${TAB}requirements.md has changed shape; only it holds US-2:tests; only this suite holds US-2:refuse-only"
req_mutant entry-deleted requirements.md '/^### US-2$/,/^- direction: refuse-only: a reason$/d'
OUT=$(req_fixture "$REQ_FIX/entry-deleted")
holds 'and an entry deleted outright, which the header forbids' "$OUT" \
  "FAIL${TAB}FR-45 FR-46${TAB}requirements.md has changed shape; only this suite holds US-2:refuse-only"
# A story covered in both directions declares itself one-sided, which no count
# held: every entry's direction is its own.
req_mutant direction-added requirements.md '/^### US-1$/,/^### US-2$/s/^- status: active$/&\n- direction: permit-only: a reason/'
OUT=$(req_fixture "$REQ_FIX/direction-added")
tok 'a direction declared changes the shape, and that is the only finding' \
  "FAIL${TAB}FR-45 FR-46${TAB}requirements.md has changed shape; only it holds US-1:permit-only; only this suite holds US-1" \
  "$(grep "^FAIL" <<< "$OUT")"
# A gap whose tags meet coverage is made active, and its marker is put on an
# entry that is active: the count of every status stays where it was. The ledger
# is the one that meets FR-3's coverage, so the coverage check has nothing to
# say, and the shape alone is what turns it red.
req_mutant gap-swapped ledger 's/^US-1\trefuse\t/US-1 FR-3\trefuse\t/; s/^US-1 GH-5.1\tpermit\t/US-1 GH-5.1 FR-3\tpermit\t/'
sed -i -e "/^### FR-3\$/,/^### FR-4\$/s/^- status: gap → ${H}7\$/- status: active/" \
       -e "/^### US-1\$/,/^### US-2\$/s/^- status: active\$/- status: gap → ${H}7/" "$REQ_FIX/gap-swapped/requirements.md"
if cmp -s "$REQ_FIX/clean/requirements.md" "$REQ_FIX/gap-swapped/requirements.md"; then
  echo "the requirements mutant gap-swapped did not change requirements.md; the checks against it prove nothing" >&2
  exit 1
fi
OUT=$(req_fixture "$REQ_FIX/gap-swapped")
tok 'a gap marker moved from one entry to another changes the shape, and that is the only finding' \
  "FAIL${TAB}FR-45 FR-46${TAB}requirements.md has changed shape; only it holds US-1:gap FR-3; only this suite holds US-1 FR-3:gap" \
  "$(grep "^FAIL" <<< "$OUT")"
req FR-45
printf '' > "$REQ_FIX/empty-requirements.md"
OUT=$(requirements_read findings "$REQ_FIX/empty-requirements.md" "$REQ_FIX/clean/ledger" \
        "$REQ_FIX/clean/suite" "$REQ_FIX/clean/root" "$REQ_FIX/clean/runbook.md" '37:2' "$FIX_SHAPE")
holds 'a requirements file that holds nothing fails, rather than covering everything' "$OUT" \
  "FAIL${TAB}FR-45${TAB}nothing was read out of the requirements file, so every finding below is evidence of nothing"

echo "--- the matrix, against the same fixture ---"
req GH-104.4
tok 'the matrix names each requirement, its status, its coverage and its checks' \
"requirements matrix: 7 requirements; 5 active, 5 of them covered; 1 marked a gap; 4 check results recorded

US-1  active  covered (1 refusing, 1 permitting, 0 static)
    ok   BLOCK one
    ok   ALLOW two

US-2  active  covered (1 refusing, 0 permitting, 0 static, refuse-only)
    ok   says three

FR-1  active  covered (0 refusing, 0 permitting, 1 static, static)
    FAIL tok four

FR-2  active  covered (0 refusing, 0 permitting, 0 static, seam: none, verify: tests/present.py)

FR-3  gap → ${H}7  not asked (0 refusing, 0 permitting, 0 static)

FR-4  superseded-by: FR-1  not asked (0 refusing, 0 permitting, 0 static)

GH-5.1  active  covered (0 refusing, 1 permitting, 0 static, permit-only)
    ok   ALLOW two" \
  "$(requirements_read matrix "$REQ_FIX/clean/requirements.md" "$REQ_FIX/clean/ledger" \
       "$REQ_FIX/clean/suite" "$REQ_FIX/clean/root" "$REQ_FIX/clean/runbook.md" '37:2' "$FIX_SHAPE")"

# A gap whose tags now meet coverage is not asked about, and the matrix says the
# tags meet it, so whoever owns the gap sees that the marker can come off.
req GH-104.4
req_mutant gap-covered ledger 's/^US-1\trefuse\t/US-1 FR-3\trefuse\t/; s/^US-1 GH-5.1\tpermit\t/US-1 GH-5.1 FR-3\tpermit\t/'
holds 'the matrix names a gap whose tags now meet coverage' \
  "$(requirements_read matrix "$REQ_FIX/gap-covered/requirements.md" "$REQ_FIX/gap-covered/ledger" \
       "$REQ_FIX/clean/suite" "$REQ_FIX/clean/root" "$REQ_FIX/clean/runbook.md" '37:2' "$FIX_SHAPE")" \
  "FR-3  gap → ${H}7  not asked, though its tags now meet coverage (1 refusing, 1 permitting, 0 static)"
# A gap no check can reach has no tags to meet anything with, and a first version
# of the line above said its tags met coverage all the same, because `seam: none`
# is covered by definition. Found reading this branch's own matrix.
req_mutant seam-gap requirements.md "s/^- status: active\$/&/; /^### FR-2\$/,/^- verify:/s/^- status: active\$/- status: gap → ${H}7/"
holds 'and does not say it of a gap no check can reach' \
  "$(requirements_read matrix "$REQ_FIX/seam-gap/requirements.md" "$REQ_FIX/clean/ledger" \
       "$REQ_FIX/clean/suite" "$REQ_FIX/clean/root" "$REQ_FIX/clean/runbook.md" '37:2' "$FIX_SHAPE")" \
  "FR-2  gap → ${H}7  not asked (0 refusing, 0 permitting, 0 static, seam: none, verify: tests/present.py)"

echo "--- every result goes through pass and fail ---"
# A result printed any other way is printed and not recorded, so it covers
# nothing and is refused for having no tag by nothing. The lines that print a
# result are read off this file, comments stripped, and must be exactly the two
# in pass and fail. Any quoted string opening with a result's prefix counts,
# whatever prints it, so `printf '%s\n' "  ok ..."` and `echo -e` are found too;
# the first version asked for printf or echo followed by the quote and missed
# both, found by review of #104. The limit, named: stripping comments cuts at a
# `#` inside a string, so a result printed on a line holding one before it is
# not seen. The pattern is split across two quoted words and each expected line
# breaks its word with a quote, so that neither is among its own matches.
req GH-104.1
tok 'the only lines that print a check result are the two in pass and fail' \
"  printf '  o"'k'"   %s\n' \"\$line\"
  printf '  F"'AIL'" %s\n' \"\$line\"" \
  "$(sed 's/[[:space:]]*#.*$//' "$SUITE_DIR/check-hooks.sh" | grep -E "['\"]  (ok   |FAI""L )")"

echo "--- this repository ---"
# The record is copied before it is read, because every line printed below is
# appended to it while the program runs. What these findings count is every
# check above this line; their own results reach the matrix and not this reading.
cp "$LEDGER" "$FIXTURES/ledger-read"
FINDINGS=$(requirements_read findings "$HOOKS/requirements.md" "$FIXTURES/ledger-read" \
             "$SUITE_DIR/check-hooks.sh" "$REPO_ROOT" "$HOOKS/runbook.md" "$PROVENANCE_COUNTS" "$REQUIREMENT_SHAPE")
FINDINGS_STATUS=$?
# An awk that failed may print nothing, or only the findings before the failure,
# and a loop over what it printed passes by asking too little -- the permitting
# direction. So its status is read as well as its output: under mawk a read of a
# directory aborts the program with exit 2, found by review of #104.
req FR-45 FR-46 GH-104.1
[ "$FINDINGS_STATUS" = 0 ] || fail static 'the requirements program exited %s, so its findings are not all of them' "$FINDINGS_STATUS"
[ -n "$FINDINGS" ] || fail static 'the requirements program printed no finding at all'
while IFS="$TAB" read -r RESULT TAGS TEXT; do
  req $TAGS
  case "$RESULT" in
    ok) pass static '%s' "$TEXT" ;;
    *)  fail static '%s' "$TEXT" ;;
  esac
done <<< "$FINDINGS"

# --matrix: every requirement, from the record as it stands now, the findings
# above included, and then the verdict line the run would have printed.
if [ -n "$MATRIX" ]; then
  requirements_read matrix "$HOOKS/requirements.md" "$LEDGER" "$SUITE_DIR/check-hooks.sh" \
    "$REPO_ROOT" "$HOOKS/runbook.md" "$PROVENANCE_COUNTS" "$REQUIREMENT_SHAPE" >&3
  MATRIX_STATUS=$?
  exec >&3
  if [ "$MATRIX_STATUS" != 0 ]; then
    echo "the matrix program exited $MATRIX_STATUS, so the matrix above is not the whole of it"
    FAILED=1
  fi
fi
echo
if [ $FAILED -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
exit $FAILED

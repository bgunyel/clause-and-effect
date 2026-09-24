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
# CLAUDE.md both. And split-requirements.sh, which moves `GH-` entries out of
# requirements.md into a file each and which nothing runs for you either: it is
# run here only against fixtures, in the #200 section.
# Most checks run a hook as a process and read
# its verdict; the rest read one of these files, and each kind is introduced
# where it begins. Every check carries the IDs of the requirements it
# establishes, which requirements.md and the requirements/ directory beside this
# suite define, and a requirement
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
# expected -- and `verdict`, in checks/library.sh, is where that is answered
# and argued.
#
# THE SUITE IS MORE THAN THIS FILE. The helpers that more than one section calls
# -- `check`, `says`, `tok`, `pass` and `fail` among them -- are in
# checks/library.sh beside it, which this file sources before its first check.
# Its header states which functions belong there.
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
# the hook files run as processes, the library they source, the text of each,
# and requirements.md and requirements/ beside them. $SUITE_DIR is what they are judged AGAINST and
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
# and are not judged as ones. This suite, the files it sources, and the harness
# that runs it against a copy of the rest. One rule, because three questions
# that read it are one fact -- none of them is executed from $HOOKS, whatever an
# override says. None is a tokeniser consumer though each of the two above names
# the library in code; none can be a mutation target, because the copy's text
# would be read and never run; and their text is read off $SUITE_DIR below
# rather than off $HOOKS.
# It was three separate spellings of that one fact before Bertan's review of
# PR #142, and the one it did not have was the middle one: mutate-hooks.sh was
# an accepted mutation target, judged on text nobody executed.
#
# IT IS A RULE AND NOT A LIST (#204): a regular expression over a path relative
# to .claude/hooks/, matching the two files above and every file under checks/,
# where the files this suite sources live. A list is what the next file is not
# on, and a file under checks/ is added by every loop that writes checks, so the
# rule is written for the directory and adding one never touches it.
#
# EVERY FILE UNDER checks/, AT ANY DEPTH, SPELLED PLAINLY. Each segment after
# `checks/` is a name that is not `.` and not `..`: one not opening with a dot,
# or a dot and then something other than a dot, or two dots and then anything
# at all -- so `.a.sh` and `...` are names and `.` and `..` are not. It was
# `checks/.+`, which took `checks/../no-git-push.sh`, a hook, as the tooling:
# a text check spelled `$SUITE_DIR/checks/../no-git-push.sh` was accepted and
# read this repository's hook under an override instead of the copy (review of
# PR #216, round 1). Its first fix was one level with no leading dot, which
# reopened the class from the other side (round 2): `checks/./library.sh`,
# `checks//library.sh` and `checks/sub/x.sh` were then not the tooling, so they
# were judged as hooks, and a hook is accepted when it is read from $HOOKS and
# runnable as a registry row. So the rule is exact, and the spellings it does
# not take are not left to fall through. A consumer that ACCEPTS on it -- the
# text-check rule, which takes a tooling file read off $SUITE_DIR, and the #204
# check that every file the driver sources is the tooling are the ones today --
# refuses an empty, `.` or `..` segment before it asks this, so a looser rule
# there could not accept one; each such refusal is driven by a fixture of its
# own. The harness's `row_fault` and this
# suite's audit of the registry ask this first, and refuse on every branch,
# this one included: their order decides which reason is printed, never
# whether the row runs (review of PR #216, round 3, which found this comment
# saying every consumer asked the segments first; round 4 found the second
# consumer that accepts, which asked none).
#
# It is spelled in bracket expressions rather than with backslashes because awk
# and [[ =~ ]] read it too, and `awk -v` would eat a backslash. mutate-hooks.sh
# spells it identically, and the #204 section holds the two to each other.
TOOLING='^(check-hooks[.]sh|mutate-hooks[.]sh|checks/([^/.][^/]*|[.][^/.][^/]*|[.][.][^/]+)(/([^/.][^/]*|[.][^/.][^/]*|[.][.][^/]+))*)$'
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
  for f in "$SUITE_DIR"/*.sh "$SUITE_DIR"/lib/*.sh "$SUITE_DIR"/*.md "$SUITE_DIR"/requirements/*; do
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
# The ledger, the tag and the record of which hooks ran. What each one is, and
# the functions that write them -- `record`, `pass`, `fail`, `req`, `section`
# and `ran` -- are in the helper library; the variables are set here because
# the library defines functions and nothing else.
LEDGER=
REQ=
RAN=
# THE HELPER LIBRARY, checks/library.sh: every function this suite calls from
# more than one of its sections, and nothing else. Its header states the rule.
#
# The files this driver sources, in the order it sources them: the library
# first, here, and then the checks, at the end of this prelude -- the unsplit
# file, and the end-of-run file last. $SUITE_SOURCED is all of them. Read off
# $SUITE_DIR and never off $HOOKS: they are the suite that runs, not the hooks
# it judges, which is the reason given for this file in the two-directories
# paragraph above. A library that did not load would leave every check below a
# `command not found`, which prints no FAIL and sets no FAILED -- a green run
# having asked nothing -- so it stops the run instead.
SUITE_LIBRARY="checks/library.sh"
SUITE_CHECKS="checks/unsplit.sh checks/end-of-run.sh"
SUITE_SOURCED="$SUITE_LIBRARY $SUITE_CHECKS"
for f in $SUITE_LIBRARY; do
  . "$SUITE_DIR/$f" || {
    echo "$f did not load; nothing was judged" >&2
    exit 1
  }
done
declare -F record pass fail req section >/dev/null || {
  echo "$SUITE_LIBRARY loaded without the functions every check prints through; nothing was judged" >&2
  exit 1
}
# AND A LIBRARY THAT LOADED WITHOUT ONE OF ITS OTHER FUNCTIONS is the same
# hazard one helper at a time, which the five names above do not ask about: with
# `lacks` deleted from the library the run printed 35 `command not found` lines
# on stderr, 35 fewer results, and ALL CHECKS PASSED. Found by review of PR
# #216. A list of the other names would be what the next helper is not on, so
# the question is asked of every command instead: bash calls this function for
# any command it cannot find, and it writes down which. That is all it can do.
# Bash runs it in an environment of its own -- a fork, even when the missing
# command was called from this shell -- so a FAILED it set would be lost and a
# `fail` it called would go unrecorded, and inside a $( ) anything it printed on
# stdout would become the captured value. So it writes one line, the one bash
# would have printed -- `<file>: line <n>: <command>: command not found`, the
# file as it was run or sourced -- to $NOT_FOUND and to stderr, and returns
# bash's own status, and the foot of this suite fails on anything in that file.
# Measured, both halves: the handler sets nothing a caller can see, and records
# from a $( ), a ( ), this shell and a function alike; and with the handler and
# without it, bash's stderr is byte for byte the same.
#
# WHAT IT DOES NOT REACH, named. $NOT_FOUND is set once the fixtures directory
# exists, so a command missing before then still prints and is not counted. A
# command missing in the --matrix program is counted: it runs after the foot's
# rows but before the final verdict, which reads the record last. And a child
# the suite runs with `bash -c` -- GH-204.2's library-alone
# legs among them -- is another shell, which does not inherit the handler.
# Exporting it is not the answer: the hooks this suite runs are such children
# too, and they would inherit it and change their own stderr (review of PR
# #216, round 2).
NOT_FOUND=
command_not_found_handle() {
  local line
  printf -v line '%s: line %s: %s: command not found' "${BASH_SOURCE[1]}" "${BASH_LINENO[0]}" "$1"
  [ -n "$NOT_FOUND" ] && printf '%s\n' "$line" >> "$NOT_FOUND"
  printf '%s\n' "$line" >&2
  return 127
}
# Recorded on the line after its definition, for the reason LOADED_BODY below
# gives: a redefinition of the handler would silence every missing command.
declare -A LOADED_BODY=()
LOADED_BODY[command_not_found_handle]=$(declare -f command_not_found_handle)

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
NOT_FOUND="$FIXTURES/not-found"
# Where the verdict expects the record to be. The GH-204.5 self-test points
# $NOT_FOUND elsewhere and puts it back. A section that copied that and did not
# put it back would leave the handler and the verdict both on the new file, and
# whatever the handler had written to this one before the move would never be
# read; the verdict fails on the two differing, and says so (round 6 of the
# review of PR #216; this comment had the hazard backwards until round 7).
NOT_FOUND_AT_HEAD=$NOT_FOUND
: > "$NOT_FOUND"
# THE SUITE'S OWN TEXT, which several checks below read: a pinned sentence, a
# derivation over every function, the header. It is more than this file, so no
# check names this file to read it -- a read of check-hooks.sh alone would miss
# whatever is in the library and pass for its absence. They read $SUITE_TEXT,
# every file of the suite in source order, or a range of it through
# `suite_range`, which fails on a range that matched nothing.
#
# SOURCE ORDER is this driver first and then each file in $SUITE_SOURCED in the
# order it is sourced -- the library, the unsplit file, the end-of-run file --
# so the header this suite opens with is still the first thing in it. $SUITE_FILES is that list, and the line that sets it is the one
# place code names this file by its path, other than to run it; the #204
# section holds the suite to that. A check that needs to know where one file
# ends and the next begins -- which function is defined where -- reads the
# files it lists.
SUITE_FILES=("$SUITE_DIR/check-hooks.sh")
for f in $SUITE_SOURCED; do
  SUITE_FILES+=("$SUITE_DIR/$f")
done
suite_text() {  # suite_text -- every file of this suite, in source order
  cat -- "${SUITE_FILES[@]}"
}
SUITE_TEXT="$FIXTURES/suite-text"
suite_text > "$SUITE_TEXT" || {
  echo "the suite's own text could not be read; the checks that read it would prove nothing" >&2
  exit 1
}
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

# The library UNDER CHECK, not the one beside this file: the checks below call
# its functions directly, and under #107's override the copy being judged is the
# one they have to call.
. "$HOOKS/lib/command-scan.sh"

# EVERY FUNCTION AND VARIABLE THE LIBRARY AND THE TOKENISER DEFINE, as bash
# holds them. The foot of this suite asks each one again and fails on any that
# was redefined or removed in between, which is how a helper written again in a
# later section -- the library's names are English words -- replaces the
# library's for every check after it without a word; and a tokeniser variable
# such as `CS_WRAPPER_RE` assigned again would change the tokeniser every later
# check asks about. The handler is recorded where it is defined, above.
#
# Read off bash and not off the text, because the text has had to be read three
# times: `name() {` alone, then with `name ()`, `function name` and
# `function name()`, and round 3 of the review of PR #216 found `holds() ( ... )`
# and `holds ( ) { ... }` passing all four. The body of a function is any
# compound command bash takes, so a reader of its text is always one spelling
# behind; `declare -f` is bash's own reading, and a body that changed changed
# whatever it was spelled as.
#
# AND READ OFF THE FILES, NOT OFF THIS SHELL AT SOME LINE. The record was taken
# of this shell once both were loaded, about 200 lines after the library, and a
# redefinition in between became the baseline itself: `holds ( ) { ... }` in the
# prelude survived green (round 4). So each file is sourced alone in a child
# with an empty environment, which defines what the file defines and nothing
# else, and what that child holds is the record -- there is no line of this
# file between the source and the record for anything to stand in. The empty
# environment is also why a function or a `CS_*` variable exported by whoever
# ran this suite is neither added to the record nor dropped from it. A
# variable's attributes are left out of the comparison, so an exported copy of
# one cannot make a false red: its value is what the tokeniser reads. Measured
# before it was relied on: for all 65 names, what the child prints is
# byte-identical to what a shell that sourced the same files prints.
#
# What it does not reach, named: a function the driver defines -- a prelude or
# section helper, not across the file boundary -- other than the handler; a
# redefinition that puts the same body back; and a builtin the comparison uses,
# `declare`, `printf` or `eval`, shadowed by a function of that name.
LOADED_CHILD='bf=" $(compgen -A function | tr "\n" " ") "; bv=" $(compgen -v | tr "\n" " ") bf bv n v "
. "$1" >/dev/null 2>&1 || exit 1
for n in $(compgen -A function); do
  [[ $bf == *" $n "* ]] && continue
  printf "%s\0%s\0" "$n" "$(declare -f "$n")"
done
for n in $(compgen -v); do
  [[ $bv == *" $n "* || $n == BASH_* || $n == _ ]] && continue
  v=$(declare -p "$n"); printf "\$%s\0%s\0" "$n" "${v#declare -* }"
done'
declare -A LOADED_FROM=()
for f in "$SUITE_DIR/$SUITE_LIBRARY" "$HOOKS/lib/command-scan.sh"; do
  record_of "$f" "$FIXTURES/record" || {
    echo "sourcing $f alone defined nothing, so nothing of it can be compared at the foot; nothing was judged" >&2
    exit 1
  }
  while IFS= read -r -d '' k && IFS= read -r -d '' v; do
    LOADED_BODY[$k]=$v
    LOADED_FROM[$k]=$f
  done < "$FIXTURES/record"
done
# The names sourcing the library defined, which the #204 section holds the
# scanner that reads its text to.
SUITE_LOADED=$(for k in "${!LOADED_FROM[@]}"; do
                 [[ $k != \$* && ${LOADED_FROM[$k]} != "$HOOKS/lib/command-scan.sh" ]] && printf '%s\n' "$k"
               done | LC_ALL=C sort)
# WHICH OF THEM BASH NOW HOLDS DIFFERENTLY, OR NOT AT ALL: a name a line, in no
# order. Code in a variable and not a function, because the foot of this suite
# runs it to decide whether a function was redefined, and a function it called
# could be the one redefined: round 4 of the review replaced `fail` with a
# no-op, and the foot's own verdict went with it. So nothing here calls a
# function. The #204 section runs the same text against a fixture.
LOADED_CHANGED_CODE='for LOADED_K in "${!LOADED_BODY[@]}"; do
  if [[ $LOADED_K == \$* ]]; then
    LOADED_NOW=$(declare -p "${LOADED_K#\$}" 2>/dev/null); LOADED_NOW=${LOADED_NOW#declare -* }
  else
    LOADED_NOW=$(declare -f "$LOADED_K" 2>/dev/null)
  fi
  [[ $LOADED_NOW == "${LOADED_BODY[$LOADED_K]}" ]] || printf "%s\n" "$LOADED_K"
done'
# AND THE VERDICT THOSE QUESTIONS GIVE -- a recorded function or variable
# changed, a command not found, the not-found record moved -- taken after every
# check and every helper, and followed only by LEDGER_VERDICT_CODE below, the
# blank `echo` and the `if` that print the summary line, and the exit. The foot of the #104 section records a row for each, but a row is
# printed and recorded through `pass` and `fail`, and a redefined helper can
# undo whatever FAILED said before it: `fail() { FAILED=0; }` exited 0 with the
# foot red (round 5 of the review). So the verdict is taken again after every
# helper has run, from this text, which calls none; it can set FAILED and cannot
# clear it. Code in a variable so that the #204 section can drive it with a
# fixture for each way it has to fail.
FOOT_VERDICT_CODE='LOADED_CHANGED=$(eval "$LOADED_CHANGED_CODE")
if [[ -n $LOADED_CHANGED ]]; then
  printf "%s\n" "a function or tokeniser variable this run started with was redefined or removed during it:" "$LOADED_CHANGED" >&2
  FAILED=1
fi
if [[ -s $NOT_FOUND ]]; then
  printf "%s\n" "a command this suite called was not found:" "$(< "$NOT_FOUND")" >&2
  FAILED=1
fi
if [[ $NOT_FOUND != "$NOT_FOUND_AT_HEAD" ]]; then
  printf "%s\n" "the not-found record was moved during the run, so what was written to $NOT_FOUND_AT_HEAD was not read:" "$NOT_FOUND" >&2
  FAILED=1
fi'
# AND A FAIL THE LEDGER HOLDS FAILS THE RUN, whatever FAILED says by then: a
# second source for the verdict, independent of the first. The #204 section
# drives the verdict above with a fixture that goes red if it clears a failure
# it was given, but that row can only print a FAIL; a verdict mutated to clear
# FAILED would clear the FAIL it had just caused, and a red run would exit 0 with
# ALL CHECKS PASSED (round 6 of the review of PR #216). Every FAIL printed in
# this shell is recorded, by `fail`, so the ledger is the record of what failed,
# and this reads it with builtins alone.
# A row is `tags TAB direction TAB result TAB label`, and neither the tags, the
# direction nor the label can hold a tab, so a FAIL result is the one row with
# TAB FAIL TAB in it; matched whole, because reading fields with IFS set to a tab
# would collapse an empty tag field and read the wrong column.
LEDGER_VERDICT_CODE='while IFS= read -r LEDGER_ROW; do
  if [[ $LEDGER_ROW == *$'"'"'\t'"'"'FAIL$'"'"'\t'"'"'* ]]; then FAILED=1; fi
done < "$LEDGER"'

# THE SPLIT_MOVED LITERAL, which the #200 checks in checks/end-of-run.sh hold
# the split set to; what it is, and the trade it makes, is written there. It is
# here and not beside them because split-requirements.sh reads each token out
# of check-hooks.sh by name, and tells whoever merges across the split to move
# the token in this file.
SPLIT_MOVED='
GH-43.1:3016071546:230 GH-43.2:3981155595:365 GH-43.3:3296458999:202
GH-43.4:1176774999:332 GH-43.5:2245854857:208 GH-43.6:2896846372:505
GH-44.1:2920400005:350 GH-44.2:685382692:425 GH-44.3:4195638298:507
GH-44.4:883040912:413 GH-44.5:2792005444:377 GH-44.6:2286241849:333
GH-44.7:2281562543:294 GH-47.1:3798972667:325 GH-47.2:3262982810:416
GH-50.1:963858542:304 GH-50.2:2971482831:527 GH-50.3:3158273160:290
GH-51.1:716105133:249 GH-51.2:3449319844:309 GH-58.1:2879788571:473
GH-58.2:4131600584:347 GH-61:1785465042:435 GH-62:2642290802:294
GH-63:977837279:276 GH-68.1:2776987324:213 GH-68.2:3577127727:364
GH-68.3:2786679676:404 GH-69.1:3360809505:349 GH-69.2:1687396498:282
GH-69.3:2307590211:365 GH-70.1:2457716069:251 GH-70.2:553276152:312
GH-70.3:1835051587:271 GH-71:1705493727:261 GH-72:2730174427:276
GH-73:1740680021:328 GH-79.1:1156543033:392 GH-79.2:2448772362:387
GH-79.3:1044006035:492 GH-79.4:4164888728:423 GH-84.1:1415289798:456
GH-84.2:1913130545:311 GH-84.3:3264922817:232 GH-94.1:1818629125:343
GH-94.2:871862042:365 GH-94.3:777013953:257 GH-94.4:2033462644:487
GH-95.1:2814035934:383 GH-95.2:1943897409:371 GH-96.1:2653392487:401
GH-96.2:2058708649:267 GH-96.3:2380602582:309 GH-97.1:1432229579:335
GH-97.2:3203520091:343 GH-98:2426143346:340 GH-99.1:529824382:413
GH-99.2:3044304870:258 GH-99.3:2321070265:293 GH-100:466656719:350
GH-101:3549404229:283 GH-102:4072209571:222 GH-104.1:673865969:159
GH-104.2:3422979425:190 GH-104.3:275267075:273 GH-104.4:1322410782:241
GH-104.5:3422391122:300 GH-106:3704976515:1535 GH-107.1:3959444618:2375
GH-107.2:2755331717:3017 GH-108.1:1735229711:765 GH-108.2:2104747290:1161
GH-108.3:3492012368:611 GH-108.4:272803982:544 GH-108.5:1162982285:1240
GH-108.6:1295126848:567 GH-108.7:132764282:816 GH-108.8:32710089:758
GH-108.9:1920560325:1237 GH-108.10:1327094914:1146 GH-109.1:722393216:550
GH-109.2:3501734001:2130 GH-109.3:655958765:398 GH-109.4:2245848118:874
GH-109.5:1126951843:1652 GH-117:149840679:3224 GH-117.1:2522200149:1957
GH-118:4142000930:1501 GH-124:95512510:244 GH-127:705289083:213
GH-128:3819682974:2698 GH-130:3976834831:1480 GH-130.1:2601395581:1689
GH-130.2:2650910486:1268 GH-130.3:3706264335:2146 GH-130.4:1739224337:1217
GH-130.5:423110139:3450 GH-130.6:3398838914:2836 GH-131:976030016:1610
GH-133:1655092711:1513 GH-134:2462285111:1737 GH-134.1:175342827:1850
GH-135:2245415987:1695 GH-136:1821333198:624 GH-137.1:2188355493:1363
GH-137.2:3816430604:1859 GH-139:2474037372:4416 GH-141:4095480653:1665
GH-143.4:1351248197:1919 GH-143.5:2325415628:855 GH-148:2277754167:7215
GH-155.1:3143088805:5291 GH-156:1579607799:1497 GH-164:1173286345:555
GH-167:3774825998:1365 GH-171:1548953849:1055 GH-175:1964502293:1348
'

# THE CHECKS, sourced into this shell in the order $SUITE_CHECKS gives: the
# unsplit file, which holds every check written before the suite was split, and
# the end-of-run file last, which reads the record every check before it wrote.
for f in $SUITE_CHECKS; do
  . "$SUITE_DIR/$f"
done

# The foot's questions, asked again after every helper has run, and then the
# ledger, for a FAIL the first verdict did not keep. Between
# them and the exit stand only `echo`, `[[ ]]` and `exit`, which are builtins and
# a keyword -- unless a function shadows a builtin of that name, the limit
# GH-204.1 names (round 6 of the review). See FOOT_VERDICT_CODE.
eval "$FOOT_VERDICT_CODE"
eval "$LEDGER_VERDICT_CODE"
echo
if [[ $FAILED -eq 0 ]]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
exit $FAILED

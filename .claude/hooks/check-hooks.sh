#!/bin/bash
# Regression checks for no-git-push.sh, no-pr-decisions.sh,
# no-commit-to-main.sh and no-work-on-stale-branch.sh.
#
# A hook is a process, so the only way to test one is to run it; what the rule
# against calling the function under test forbids is deriving the expectation
# from it, and every verdict below is written as a literal BLOCK or ALLOW.
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
# So the number below is not a measure of the boundary. A check suite is
# evidence about the cases it names and about nothing else, and every case here
# was named by someone who went looking for one it had missed.
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
cd "$(dirname "$0")" || exit 1
HOOKS=$(pwd)

FAILED=0
# Where a hook is, given what a check names: a bare filename is one of this
# repository's, an absolute path is a fixture copy of one. Written once because
# three helpers below ask it, and they answered it in three identical `case`
# statements until the load-contract section gave `says` its first fixture.
hook_path() {  # hook_path <script|/absolute/hook>
  case "$1" in /*) printf '%s\n' "$1" ;; *) printf '%s\n' "$HOOKS/$1" ;; esac
}
# What a hook's exit status means, answered once for every helper that runs a
# hook and reads one: exit 0 is ALLOW, exit 2 is BLOCK, and anything else FAILs
# the check whatever it expected. `says` and `says_not` ask only for 2, because
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
  local want="$1" rc="$2" err="$3" label="$4" got
  case "$rc" in 0) got=ALLOW ;; 2) got=BLOCK ;; *) got=FAIL ;; esac
  if [ "$got" = "$want" ]; then
    printf '  ok   %-5s %s\n' "$got" "$label"
  else
    printf '  FAIL want=%s got=%s exit=%s  %s\n         stderr |%s|\n' \
      "$want" "$got" "$rc" "$label" "$err"
    FAILED=1
  fi
}
check() {  # check <script> <want> <label> <cmd>, run from $HOOKS
  local script="$1" want="$2" label="$3" cmd="$4" rc err
  err=$(printf '%s' "$cmd" | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' | ./"$script" 2>&1 >/dev/null)
  rc=$?
  verdict "$want" "$rc" "$err" "$label"
}

# Two throwaway repositories, one on main and one on a dev branch, so that a
# hook reading `git branch --show-current` can be asked both questions from a
# suite that runs on neither. They hold no commits and no remotes: an unborn
# branch is still reported by name, and nothing here reaches a remote.
FIXTURES=$(mktemp -d)
trap 'rm -rf "$FIXTURES"' EXIT
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
  verdict "$want" "$rc" "$err" "$label"
}

# A check whose verdict the #43 migration changed. Both verdicts are literals:
# `was` is what the file returned before it, `want` what it returns after, and
# the run prints both so the flip is visible rather than inferred. Reverting
# the migration fails exactly these, reporting got=<was>.
flip() {  # flip <dir> <script> <was> <want> <label> <cmd>
  check_in "$1" "$2" "$4" "$5 (was $3)" "$6"
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
  if [ "$rc" != 2 ]; then
    printf '  FAIL %s\n         wanted a refusal saying |%s|, got exit=%s\n         stderr |%s|\n' \
      "$label" "$want" "$rc" "$err"
    FAILED=1
    return
  fi
  case "$err" in
    *"$want"*) printf '  ok   says  %s\n' "$label" ;;
    *) printf '  FAIL %s\n         wanted the refusal to say |%s|\n         it said |%s|\n' \
         "$label" "$want" "$err"
       FAILED=1 ;;
  esac
}

# The other half of says: a refusal that must not say something. The fallback
# detector cannot tell a merged branch from one cut before the dev branch moved,
# so a message claiming a merge there would be a claim the hook cannot support.
# Nothing above can catch a message saying too much.
says_not() {  # says_not <dir> <script|/absolute/hook> <fragment> <label> <cmd>
  local dir="$1" script="$2" unwanted="$3" label="$4" cmd="$5" err rc hook
  hook=$(hook_path "$script")
  err=$(printf '%s' "$cmd" | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' \
        | ( cd "$dir" && "$hook" ) 2>&1 >/dev/null)
  rc=$?
  if [ "$rc" != 2 ]; then
    printf '  FAIL %s\n         wanted a refusal not saying |%s|, got exit=%s\n         stderr |%s|\n' \
      "$label" "$unwanted" "$rc" "$err"
    FAILED=1
    return
  fi
  case "$err" in
    *"$unwanted"*) printf '  FAIL %s\n         the refusal must not say |%s|\n         it said |%s|\n' \
         "$label" "$unwanted" "$err"
       FAILED=1 ;;
    *) printf '  ok   says  %s\n' "$label" ;;
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
armed() {  # armed <label> <file> <literal>
  if sed 's/[[:space:]]*#.*$//' "$2" 2>/dev/null | grep -qF -- "$3"; then
    printf '  ok   armed %s\n' "$1"
  else
    printf '  FAIL %s\n         expected %s to contain |%s|\n' "$1" "$2" "$3"
    FAILED=1
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
  if grep -qF -- "$3" "$2" 2>/dev/null; then
    printf '  ok   written %s\n' "$1"
  else
    printf '  FAIL %s\n         expected %s to still say |%s|\n' "$1" "$2" "$3"
    FAILED=1
  fi
}

# The absence has to be an absence IN a file that was read. `grep -qF` on a file
# that is not there exits 2, which fell into the else arm and reported ok -- so
# every pin below would have passed for a file renamed or deleted away, which is
# the permitting direction and the same shape as the #84 defect these were added
# for. Found by review of that change, not by this suite.
unarmed() {  # unarmed <label> <file> <literal>
  if [ ! -r "$2" ]; then
    printf '  FAIL %s\n         %s cannot be read, so the absence of |%s| is evidence of nothing\n' \
      "$1" "$2" "$3"
    FAILED=1
  elif grep -qF -- "$3" "$2" 2>/dev/null; then
    printf '  FAIL %s\n         %s must not contain |%s|\n' "$1" "$2" "$3"
    FAILED=1
  else
    printf '  ok   armed %s\n' "$1"
  fi
}

. ./lib/command-scan.sh

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
    printf '  ok   beside %s\n' "$1"
  else
    printf '  FAIL %s\n         expected the comment above the derivation in %s\n         to contain |%s|\n' \
           "$1" "$2" "$3"
    FAILED=1
  fi
}

# A guard for the one check below that compares two numbers rather than
# matching a literal. An absent derivation must not reach `[ -gt ]`, which
# errors rather than answering.
numeric() { case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }

tok() {  # tok <label> <expected> <actual>
  if [ "$3" = "$2" ]; then
    printf '  ok   %s\n' "$1"
  else
    printf '  FAIL %s\n         want |%s|\n         got  |%s|\n' "$1" "$2" "$3"
    FAILED=1
  fi
}

echo "=== the tokeniser itself ==="
# Every defect on PR #35 was one question -- how far around a matched token to
# look -- answered differently in a different place. It is answered once in
# lib/command-scan.sh, so these aim at it rather than through a hook.
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
# Redirections. A redirect is not an argument, and nothing removed it, so its
# operator or its target was read as a refspec and every redirect on an
# otherwise permitted push was refused. Issue #50.
#
# The two that come first are the ones the drop must not get wrong, because
# they are the ones where it would hide something: a process substitution
# carries a command, and a redirect inside quotes is text. Both are written
# before the drops themselves for that reason.
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
tok 'the heredoc operator survives the redirect drop' \
    'cat <<EOF' \
    "$(printf 'cat <<EOF\nbody\nEOF\n' | cs_normalise)"
tok 'the here-string operator survives the redirect drop' \
    'cat <<< "hello"' \
    "$(printf 'cat <<< "hello"\n' | cs_normalise)"
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
tok 'a substitution inside single quotes is text' \
    "grep -n 'git push|\$(x)' ." \
    "$(printf "grep -n 'git push|\$(x)' .\n" | cs_split)"
tok 'an escaped substitution in double quotes is text' \
    'git commit -m "release \$(date) notes"' \
    "$(printf 'git commit -m "release \\$(date) notes"\n' | cs_split)"
# The backslash is read for that one purpose. An escaped separator outside
# quotes still cuts, exactly as it did before, which is the refusing direction.
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
check_in "$PUSH_WT" no-git-push.sh ALLOW 'and the same command is not a push' \
         'sed -e s/\"/Q/ -e '"'"'s|git push|X|'"'"' f.sh'
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
tok 'gh args, the first match only, and the rest unseen' '' \
    "$(printf 'gh pr create\ngh pr create --base dev-05\n' | cs_gh_args 'pr create')"
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

echo "=== REGRESSION: PR #35, only the first push on a line was validated ==="
# The scope found the first push, validated its arguments, and stopped. So a
# legitimate push carried an illegitimate one after ; or && on its coat-tails.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'legit push ; push origin main'  "git push origin $PUSH_BRANCH; git push origin main"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'legit push && push --all'       "git push origin $PUSH_BRANCH && git push --all origin"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'bare push && forced push'       "git push && git push --force origin $PUSH_BRANCH"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'three pushes, last one bad'     "git push; git push origin $PUSH_BRANCH; git push --mirror origin"
check no-pr-decisions.sh BLOCK 'gh pr view ; gh pr merge'   'gh pr view 5; gh pr merge 5'

echo "=== REGRESSION: PR #35, backticks and command prefixes ==="
# $( ) was closed by the paren in the separator class and its twin was not --
# the same asymmetry GIT_DIR= had against --git-dir. Both hooks were open.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'backticked push'      'echo `git push --mirror origin`'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'dollar-paren push'    'echo $(git push --mirror origin)'
check no-pr-decisions.sh BLOCK 'backticked merge'     'echo `gh pr merge 35`'
check no-pr-decisions.sh BLOCK 'dollar-paren merge'   'echo $(gh pr merge 35)'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'push through xargs'   'echo origin | xargs git push --mirror'
check no-pr-decisions.sh BLOCK 'merge through xargs'  'echo 35 | xargs gh pr merge'

echo "=== REGRESSION: heredoc prose that blocked its own commit ==="
COMMIT_MSG=$'git commit -q -F - <<\'EOF\'\nLeave pushing and deciding a PR to Bertan\n\nno-git-push.sh refuses every push; no-pr-decisions.sh refuses\ngh pr review --approve and --request-changes, gh pr close and reopen.\ngit push origin main is refused in every form.\ngh pr merge 5 would also be refused.\nEOF'
check_in "$PUSH_WT" no-git-push.sh ALLOW 'commit msg naming git push in heredoc' "$COMMIT_MSG"
check no-pr-decisions.sh ALLOW 'commit msg naming gh pr verbs in heredoc' "$COMMIT_MSG"
NOTE=$'cat > /tmp/note.md <<\'MD\'\ngh pr merge is now refused by a hook.\ngit push origin main likewise.\nMD'
check_in "$PUSH_WT" no-git-push.sh ALLOW 'heredoc body naming git push' "$NOTE"
check no-pr-decisions.sh ALLOW 'heredoc body naming gh pr merge' "$NOTE"

echo "=== REGRESSION: PR #35, indentation defeated the anchor ==="
# Each names a refused destination, so these assert that the command is still
# *found* when indented, independently of the worktree exception.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'if/then + indented push to dev-05' $'if true; then\n    git push origin dev-05\nfi'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'for loop + indented push to main'  $'for r in a b; do\n  git push origin main\ndone'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'deeply indented push to main'      $'if true; then\n  if true; then\n        git push origin main\n  fi\nfi'
check no-pr-decisions.sh BLOCK 'if/then + indented merge'          $'if true; then\n    gh pr merge 35\nfi'
check no-pr-decisions.sh BLOCK 'for loop + indented close'         $'for n in 1 2; do\n  gh pr close $n\ndone'

echo "=== REGRESSION: PR #35, no-pr-decisions.sh had no wrapper rule ==="
check no-pr-decisions.sh BLOCK 'bash -c gh pr merge'  "bash -c 'gh pr merge 35'"
check no-pr-decisions.sh BLOCK 'sh -c gh pr merge'    'sh -c "gh pr merge 35"'
check no-pr-decisions.sh BLOCK 'eval gh pr merge'     "eval 'gh pr merge 35'"
check no-pr-decisions.sh BLOCK 'graphql mutation via heredoc' $'gh api graphql -f query=@- <<EOF\nmutation { mergePullRequest(input:{pullRequestId:"x"}) { clientMutationId } }\nEOF'
check no-pr-decisions.sh BLOCK 'REST merge via heredoc body'  $'gh api -X PUT --input - <<EOF\n{"path":"/repos/o/r/pulls/5/merge"}\nEOF'

echo "=== ACCEPTED false positive: quoted multi-line string, not a heredoc ==="
# The price of allowing leading whitespace in the anchor. Kept on purpose: a
# blocked comment is visible and one edit away, a silently permitted push is
# neither. If a later change makes these ALLOW, that is a decision to take
# knowingly, not a bug fix.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'multi-line -b string continuing with a push' $'gh issue comment 27 -b "to release:\n  git push origin main"'
check no-pr-decisions.sh BLOCK 'multi-line -b string continuing with a merge' $'gh issue comment 27 -b "to land it:\n  gh pr merge 35"'
# The single-line half of that trade is no longer paid, and the two checks that
# used to sit here now sit in the issue #68 section below -- an `ALLOW (was
# BLOCK)` is neither accepted nor a false positive, and leaving them under this
# heading would have made the heading a lie. The multi-line pair above stays,
# and stays accepted: quote state is per line, so an unbalanced line falls back
# to the old splitting and the continuation still reads as a command position.

echo "=== REGRESSION: issue #68, a quoted separator refused ordinary sed and grep ==="
# The six measured over-refusals from the ticket, now ALLOW. Every one is a
# command that edits or searches text; none of them pushes or commits anything.
# It fired twice in a live session against that session's own edits to these
# hooks, which is what makes it worth a suite entry rather than a note: editing
# the hooks is exactly the work that trips it.
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
check no-pr-decisions.sh ALLOW 'a merge quoted in single quotes is inert (was BLOCK)' \
         "echo '\$(gh pr merge 5)'"
# And its control, one character different: in double quotes that substitution
# RUNS, so the line goes to the fallback and the merge is found. This pair is
# what the substitution fallback exists for, and it is asked as a verdict rather
# than only as a fragment list -- pinning the split alone would let a hook stop
# refusing these without anything going red.
check no-pr-decisions.sh BLOCK 'the same substitution in double quotes' \
         'echo "$(gh pr merge 5)"'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a push substituted inside double quotes' \
         'echo "$(git push --all origin)"'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a push backticked inside double quotes' \
         'echo "`git push --all origin`"'
check_in "$ON_MAIN" no-commit-to-main.sh BLOCK 'a commit substituted inside double quotes' \
         'echo "$(git commit -m x)"'
# The trade above cs_split, partly repaid. A quoted string holding a separator
# and then a control word in front of a refused command used to read as that
# command; on one line it is text again. These were written as accepted false
# positives in the section above and are moved here with the verdict they now
# return, because that is where the reason for the change is written down.
check_in "$PUSH_WT" no-git-push.sh ALLOW 'quoted "; then" before a push (was BLOCK)'  'git commit -m "wait; then git push --all origin"'
check no-pr-decisions.sh ALLOW 'quoted "; then" before a merge (was BLOCK)' 'git commit -m "wait; then gh pr merge 35"'
# What did not flip with them, and the reason: the multi-line spelling of the
# same string leaves a quote open at the newline, so each line falls back and
# the continuation reads as a command position. Pinned here beside the flip so
# the two are read together rather than as a contradiction.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'the multi-line spelling still refused' \
         $'gh issue comment 27 -b "to release:\n  git push origin main"'
# The intermittency, which is the part that reads as arbitrary from inside a
# session: the anchored spelling was permitted all along and the spelling with a
# leading space was refused, on a difference that decides nothing about what
# either command runs. They agree now, and the pair is pinned so that a
# regression shows up as the disagreement rather than as one lost verdict.
check_in "$PUSH_WT" no-git-push.sh ALLOW 'the anchored spelling, permitted before and after' \
         "sed -i 's|^git push --all origin|X|' f.sh"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'the leading-space spelling (was BLOCK)' \
         "sed -i 's| git push --all origin|X|' f.sh"
# The controls. A quote-aware split must not have cost a single real refusal,
# and these are the three commands the six above only ever mentioned.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'the control: a real push --all'   'git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'the control: a real forced push'  'git push -f origin main'
check_in "$ON_MAIN" no-commit-to-main.sh BLOCK 'the control: a real commit on main' 'git commit -m x'
check_in "$ON_MAIN" no-commit-to-main.sh BLOCK 'the control: a real push --all on main' 'git push --all origin'
# The wrapper detections read the RAW command text, before the split and not
# from it, and that ordering is load-bearing here: quote-aware splitting means a
# single-quoted payload is now one fragment with no command position in it at
# all, so nothing but the raw match can still see these. A BLOCK is therefore
# evidence about where the rule reads from, which is what makes them checks
# about issue #68 rather than repeats of the wrapper checks above.
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
armed 'no-git-push.sh matches the shared wrapper rule on the raw command' \
      no-git-push.sh 'if echo "$COMMAND" | grep -qE "$CS_WRAPPER_RE"'
armed 'no-commit-to-main.sh matches the shared wrapper rule on the raw command' \
      no-commit-to-main.sh 'if echo "$COMMAND" | grep -qE "$CS_WRAPPER_RE"'
# no-pr-decisions.sh joins continuations first and matches on that, which is the
# half of cs_normalise its wrapper rules do want; both halves are pinned.
armed 'no-pr-decisions.sh derives its wrapper text from the raw command' \
      no-pr-decisions.sh "WRAPTEXT=\$(printf '%s\\n' \"\$COMMAND\" | cs_join)"
armed 'no-pr-decisions.sh matches the shared wrapper rule on that text' \
      no-pr-decisions.sh 'if echo "$WRAPTEXT" | grep -qE "$CS_WRAPPER_RE"'
unarmed 'no-git-push.sh does not match its wrapper rule on the fragments' \
        no-git-push.sh 'echo "$CMDS" | grep -qE "$CS_WRAPPER_RE"'
unarmed 'no-commit-to-main.sh does not match its wrapper rule on the fragments' \
        no-commit-to-main.sh 'echo "$CMDS" | grep -qE "$CS_WRAPPER_RE"'
unarmed 'no-pr-decisions.sh does not match its wrapper rule on the fragments' \
        no-pr-decisions.sh 'echo "$CMDS" | grep -qE "$CS_WRAPPER_RE"'
# The fourth consumer. It was covered behaviourally by the stale-branch section
# below and not by a literal, which left "each wrapper detection" met in
# substance and not in letter -- and this is the one hook where a lost fragment
# retains a carve-out instead of dropping a refusal, so it is the last one that
# should rest on an argument rather than a pin. See the header of
# lib/command-scan.sh for why that shape is still safe.
armed 'no-work-on-stale-branch.sh matches the shared wrapper rule on the raw command' \
      no-work-on-stale-branch.sh 'if echo "$COMMAND" | grep -qE "$CS_WRAPPER_RE"'
unarmed 'no-work-on-stale-branch.sh does not match its wrapper rule on the fragments' \
        no-work-on-stale-branch.sh 'echo "$CMDS" | grep -qE "$CS_WRAPPER_RE"'
# And that no hook carries its own copy of the anchor any more. WRAPRE is the
# head each of the four wrote out before #79; four copies of one expression, in
# the file whose header names that as the defect. A hook that re-derives it
# would pass every check above and answer the list differently again.
WRAPRE='(^[[:space:]]*|[;&|(`][[:space:]]*)'
unarmed 'no-git-push.sh does not carry its own copy of the anchor' \
        no-git-push.sh "grep -qE '$WRAPRE"
unarmed 'nor no-commit-to-main.sh' \
        no-commit-to-main.sh "grep -qE '$WRAPRE"
unarmed 'nor no-pr-decisions.sh' \
        no-pr-decisions.sh "grep -qE '$WRAPRE"
unarmed 'nor no-work-on-stale-branch.sh' \
        no-work-on-stale-branch.sh "grep -qE '$WRAPRE"
# In either spelling. The four pins above name the single-quoted one, which is
# how all four hooks wrote it; a re-derivation reached for with double quotes
# would satisfy every one of them and answer the list a second time anyway.
# Found by review of this change: a pin on one spelling of a literal is
# evidence about that spelling and about nothing else.
unarmed 'no-git-push.sh does not carry it double-quoted either' \
        no-git-push.sh "grep -qE \"$WRAPRE"
unarmed 'nor no-commit-to-main.sh' \
        no-commit-to-main.sh "grep -qE \"$WRAPRE"
unarmed 'nor no-pr-decisions.sh' \
        no-pr-decisions.sh "grep -qE \"$WRAPRE"
unarmed 'nor no-work-on-stale-branch.sh' \
        no-work-on-stale-branch.sh "grep -qE \"$WRAPRE"

echo "=== REGRESSION: issue #79, the wrapper rules did not know the prefix words ==="
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
check no-pr-decisions.sh BLOCK 'timeout + wrapped merge'    "timeout 5 sh -c 'gh pr merge 5'"
check no-pr-decisions.sh BLOCK 'sudo + wrapped release'     "sudo bash -c 'gh release create v1'"
check no-pr-decisions.sh BLOCK 'nohup + wrapped eval merge' "nohup eval 'gh pr merge 5'"
# The controls: the unwrapped shape the list already reached, and the wrapped
# shape with no prefix in front of it. Both were BLOCK before and must stay so,
# or the widening has moved the rule rather than extended it.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'the control: sudo + a bare push'   'sudo git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'the control: timeout + a push'     'timeout 30 git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'the control: a wrapper on its own' "bash -c 'git push --all origin'"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'the control: an assignment prefix' "FOO=1 sh -c 'git push --all origin'"

echo "=== issue #79: the anchor was widened and not dropped ==="
# The constraint that decides this fix. Dropping the anchor would pass every
# check above and refuse a wrapper word named anywhere on a line that also names
# a refused command -- which is exactly what a session working on these hooks
# writes. The obvious example does not show it: `grep -rn "sh -c" .claude/` is
# ALLOW either way, because the rule is a conjunction and that command names no
# push. The shapes that regress name a wrapper word and a push on one line, and
# each of these three is ALLOW with the anchor and BLOCK without it.
check_in "$PUSH_WT" no-git-push.sh ALLOW 'grepping for the sh -c rule'  "grep -rn 'sh -c .*git push' .claude/hooks/"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'grepping for the eval rule'   "grep -rn 'eval .*git push' .claude/hooks/"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'a note about what eval does'  "echo 'the eval rule refuses git push --all origin' >> notes.md"
check_in "$ON_DEV" no-commit-to-main.sh ALLOW 'grepping for the sh -c rule' \
         "grep -rn 'sh -c .*git commit' .claude/hooks/"

echo "=== issue #79: named and not closed -- the list cannot be complete ==="
# A word that runs a command and is not a prefix word is out of reach, and the
# header of lib/command-scan.sh says so rather than implying the set is
# exhaustive. These are ALLOW and are pinned as ALLOW: a check that named them
# and wanted BLOCK would be a claim the fix does not make.
check_in "$PUSH_WT" no-git-push.sh ALLOW 'python3 -c is out of reach' \
         "python3 -c 'import os; os.system(\"git push --all origin\")'"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'perl -e is out of reach' \
         "perl -e 'system(\"git push --all origin\")'"
# find runs its operand after -exec rather than as a prefix, so it is not one of
# cs_split's words and adding it there would strip find and leave the path where
# the command word has to be. Named with the family above rather than closed.
check_in "$PUSH_WT" no-git-push.sh ALLOW 'find -exec sh -c is out of reach' \
         "find . -exec sh -c 'git push --all origin' \\;"

echo "=== issue #79: the soft spot the anchor keeps, and what widening cost it ==="
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

echo "=== issue #79: the prefix words are written once ==="
# The point of the fix, asserted as a property of the file rather than inferred
# from the verdicts above. A second copy of those fourteen words in four hook
# regexes would be the same defect one more time, so the list is a variable that
# cs_split reads through awk's -v and the anchor interpolates.
#
# `stdbuf` and `ionice` are counted because they appear in the assignment and
# nowhere in the prose around it: sudo, timeout, xargs, nohup and env are named
# in the header's worked example, so counting one of those would count the
# explanation as a copy.
tok 'the option words are written once in the library' \
    '1' "$(prose_count "$HOOKS/lib/command-scan.sh" 'stdbuf')"
tok 'and so is the second of them' \
    '1' "$(prose_count "$HOOKS/lib/command-scan.sh" 'ionice')"
armed 'the union is derived rather than written a third time' \
      lib/command-scan.sh 'CS_WRAP_WORDS="$CS_WRAP_OPTION_WORDS|$CS_WRAP_OPERAND_WORDS"'
armed 'cs_split reads the option words as a variable' \
      lib/command-scan.sh '-v wrapwords="$CS_WRAP_OPTION_WORDS"'
armed 'and the operand words the same way' \
      lib/command-scan.sh '-v operandwords="$CS_WRAP_OPERAND_WORDS"'
armed 'cs_split strips whatever that variable holds' \
      lib/command-scan.sh 'match(line, "^(" wrapwords ")[[:space:]]+")'
armed 'and the anchor admits whatever the union holds' \
      lib/command-scan.sh '($CS_WRAP_WORDS)[[:space:]]+'
armed 'the intervening token is named once and used once' \
      lib/command-scan.sh '($CS_WRAP_TOKEN){0,3}'
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
        lib/command-scan.sh '/^(env|command|xargs'
# What these pins are NOT evidence of, named because a check is evidence about
# what it names: they read the derivation, not the verdict. A list that is
# written once and is wrong is wrong in both places at once, which is what the
# header of lib/command-scan.sh says this file keeps costing. The behavioural
# groups above are what say the list is right for the words they name.

echo "=== REGRESSION: PR #35 review, a command after a control word ==="
# A separator is not the only thing a command can follow. Splitting on ; left
# `then` in front of the command word, so the anchor never saw the command at
# all, and `do`, `else`, `elif`, `{` and `!` did the same. Every check here was
# ALLOW before the control words were removed in cs_split.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'then + push --mirror'     'if true; then git push --mirror origin; fi'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'do + push --all'          'while true; do git push --all origin; done'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'brace group + push'       '{ git push --mirror origin; }'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'then + push to dev-05'    'if true; then git push origin dev-05; fi'
check no-pr-decisions.sh BLOCK 'then + gh pr merge'       'if true; then gh pr merge 35; fi'
check no-pr-decisions.sh BLOCK 'do + gh pr merge'         'for x in a; do gh pr merge 35; done'
check no-pr-decisions.sh BLOCK 'until/do + gh pr merge'   'until false; do gh pr merge 35; done'
check no-pr-decisions.sh BLOCK 'else + gh pr merge'       'if true; then :; else gh pr merge 35; fi'
check no-pr-decisions.sh BLOCK 'elif + gh pr merge'       'if true; then :; elif true; then gh pr merge 35; fi'
check no-pr-decisions.sh BLOCK '! negation + gh pr merge' '! gh pr merge 35'
check no-pr-decisions.sh BLOCK 'brace group + gh pr close' '{ gh pr close 35; }'
# The words are removed at the start of a command only, so an ordinary sentence
# that happens to contain one is untouched.
check no-pr-decisions.sh ALLOW 'a control word mid-sentence' 'echo "then run gh pr merge 35" >> notes.md'

echo "=== REGRESSION: PR #35 review, heredoc detection dropped live commands ==="
# Dropping a heredoc body is the one step that hides commands, so both ends of
# it have to be exact. `<<<` is a here-string and was read as a heredoc whose
# terminator never arrives; `<<-` ends on a tab-indented terminator that an
# exact comparison never matched. Either one discarded every following line, so
# the hook saw an empty command and returned 0.
check no-pr-decisions.sh BLOCK 'here-string then a merge'  $'cat <<< "hello"\ngh pr merge 35'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'here-string then a push'   $'cat <<< "hello"\ngit push --mirror origin'
check no-pr-decisions.sh BLOCK '<<- tab terminator, then a merge' $'cat <<-EOF\n\thello\n\tEOF\ngh pr merge 35'
check_in "$PUSH_WT" no-git-push.sh BLOCK '<<- tab terminator, then a push'  $'cat <<-EOF\n\thello\n\tEOF\ngit push --mirror origin'
# The body of a real heredoc is still data, tab-indented or not.
check no-pr-decisions.sh ALLOW '<<- body naming a merge'   $'cat <<-EOF\n\tgh pr merge 35 would be refused\n\tEOF\necho done'
check_in "$PUSH_WT" no-git-push.sh ALLOW '<<- body naming a push'    $'cat <<-EOF\n\tgit push --all origin is refused\n\tEOF\necho done'

echo "=== REGRESSION: PR #35 review, reading a PR through gh api ==="
# The endpoint does not say whether a call decides anything. GET /pulls/N/reviews
# lists reviews and GET /pulls/N/merge reports whether the PR is merged; both are
# reading a pull request, which CLAUDE.md allows in the sentence that forbids
# deciding one, and both were refused. The method separates them, so the method
# is what is tested -- gh sends GET unless a --method or a field flag says
# otherwise.
check no-pr-decisions.sh ALLOW 'GET the reviews list'    'gh api repos/bgunyel/clause-and-effect/pulls/35/reviews'
check no-pr-decisions.sh ALLOW 'GET the merge state'     'gh api repos/bgunyel/clause-and-effect/pulls/35/merge'
check no-pr-decisions.sh ALLOW 'GET named explicitly'    'gh api -X GET repos/bgunyel/clause-and-effect/pulls/35/reviews'
check no-pr-decisions.sh ALLOW 'GET with --paginate'     'gh api --paginate repos/bgunyel/clause-and-effect/pulls/35/reviews'
check no-pr-decisions.sh ALLOW 'GET with --jq'           'gh api repos/bgunyel/clause-and-effect/pulls/35/reviews --jq ".[].state"'
# The writes to those same endpoints are refused exactly as before.
check no-pr-decisions.sh BLOCK 'POST a review verdict'   'gh api repos/bgunyel/clause-and-effect/pulls/35/reviews -f event=APPROVE'
check no-pr-decisions.sh BLOCK 'value attached to -f'    'gh api repos/bgunyel/clause-and-effect/pulls/35/reviews -fevent=APPROVE'
check no-pr-decisions.sh BLOCK 'method attached to -X'   'gh api -XPUT repos/bgunyel/clause-and-effect/pulls/35/merge'
check no-pr-decisions.sh BLOCK '--method=PUT'            'gh api --method=PUT repos/bgunyel/clause-and-effect/pulls/35/merge'
check no-pr-decisions.sh BLOCK 'a review body by --input' 'gh api repos/bgunyel/clause-and-effect/pulls/35/reviews --input body.json'
check no-pr-decisions.sh BLOCK 'DELETE a review'         'gh api -X DELETE repos/bgunyel/clause-and-effect/pulls/35/reviews'
# A read wrapped in a shell is still refused: inside quotes the method cannot be
# read any more than the endpoint can. Run it unwrapped.
check no-pr-decisions.sh BLOCK 'a GET inside bash -c'    "bash -c 'gh api repos/bgunyel/clause-and-effect/pulls/35/reviews'"

echo "=== REGRESSION: review of 02a14d8, a heredoc that never was ==="
# `<<` inside double quotes is text, not a redirection, and the opener was
# matched anywhere on the line. The terminator it took never arrives, so every
# following line was dropped and both hooks went blind for the rest of the
# command -- reachable by writing a commit message about this very file. Third
# wrong answer to what counts as a heredoc, so the drop is no longer trusted:
# lines held for a heredoc that does not terminate are given back at END.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'commit msg naming <<EOF, then --all'    $'git commit -m "hooks: fix <<EOF handling in cs_normalise"\n    git push --all origin'
check no-pr-decisions.sh BLOCK 'pr comment naming <<, then a merge'     $'gh pr comment 35 -b "the << operator confused it"\n    gh pr merge 35'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'left shift << in a message, then --all' $'git commit -m "left shift << done"\n    git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'issue comment naming <<, then --mirror' $'gh issue comment 1 -b "see << notes"\n    git push --mirror origin'
# A heredoc that does terminate is still data, so the older checks above still
# ALLOW -- that is what says the fail-safe did not simply disable the drop.

echo "=== REGRESSION: review of 02a14d8, bundled gh shorthand flags ==="
# gh takes shorthand flags together, so -ab is --approve --body and approves.
# no-git-push.sh had already answered this for -fu and this file had not: the
# same asymmetry between the siblings, in a second place.
check no-pr-decisions.sh BLOCK 'gh pr review -ab "lgtm" 35'  'gh pr review -ab "lgtm" 35'
check no-pr-decisions.sh BLOCK 'gh pr review 35 -ab lgtm'    'gh pr review 35 -ab lgtm'
check no-pr-decisions.sh BLOCK 'gh pr review -rb "no" 35'    'gh pr review -rb "no" 35'
check no-pr-decisions.sh BLOCK 'verdict letter last, -ba'    'gh pr review -ba "lgtm" 35'
# A bundle carrying no verdict letter is still a comment, and a long flag must
# not match on a letter it happens to contain -- --repo is not --request-changes.
check no-pr-decisions.sh ALLOW 'gh pr review -cb "a remark"' 'gh pr review -cb "a remark" 35'
check no-pr-decisions.sh ALLOW 'review --comment with --repo' 'gh pr review --comment --repo o/r -b x 35'

echo "=== REGRESSION: review of 02a14d8, a flag before the subcommand ==="
# Cobra resolves the subcommand at the first non-flag argument, so a flag may
# sit in front of it and every rule here wanted it as the third word. -R/--repo
# takes its value as a separate token, which would otherwise be read as the
# subcommand and hide it just as effectively.
check no-pr-decisions.sh BLOCK 'gh pr --repo o/r merge 35'      'gh pr --repo o/r merge 35'
check no-pr-decisions.sh BLOCK 'gh pr -R o/r close 35'          'gh pr -R o/r close 35'
check no-pr-decisions.sh BLOCK 'gh pr --repo=o/r reopen 35'     'gh pr --repo=o/r reopen 35'
check no-pr-decisions.sh BLOCK 'gh pr --repo o/r review -a 35'  'gh pr --repo o/r review -a 35'
check no-pr-decisions.sh BLOCK 'gh release --repo o/r create v1' 'gh release --repo o/r create v1'
# An ordinary subcommand behind a flag is still ordinary.
check no-pr-decisions.sh ALLOW 'gh pr --repo o/r view 35'       'gh pr --repo o/r view 35'
check no-pr-decisions.sh ALLOW 'gh pr --repo o/r list'          'gh pr --repo o/r list'

echo "=== REGRESSION: #47, a flag before the group evaded every gh rule ==="
# The same question one level up, and it had been applied at one level only.
# GHPR and GHRELEASE skipped options between the group and the verb and never
# before the group; the two gh api matches skipped none at all. Every BLOCK in
# this block was PERMITTED by the hook on dev-05, and all but the release are a
# decision on a pull request. -R/--repo before the group is not an evasion an
# agent has to construct -- it is the ordinary way to work on a repository from
# elsewhere. The same flag in front of a wrapped command was permitted too;
# that is issue #51, and the sections below close it.
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
check no-pr-decisions.sh ALLOW 'gh -R o/r pr view 5'           'gh -R o/r pr view 5'
check no-pr-decisions.sh ALLOW 'gh -R o/r pr list'             'gh -R o/r pr list'
check no-pr-decisions.sh ALLOW 'gh -R o/r pr create, based' 'gh -R o/r pr create --base dev-05 --fill'
# The baseless spelling made this point until #40 gave a create a base to
# name. It is refused now, and for the base rather than for the flag, which
# is what the line above still has to show.
check no-pr-decisions.sh BLOCK 'gh -R o/r pr create --fill'  'gh -R o/r pr create --fill'
check no-pr-decisions.sh ALLOW 'gh -R o/r pr edit 5 --title x' 'gh -R o/r pr edit 5 --title x'
check no-pr-decisions.sh ALLOW 'gh -R o/r pr review --comment' 'gh -R o/r pr review --comment -b x 5'
check no-pr-decisions.sh ALLOW 'gh -R o/r release list'        'gh -R o/r release list'
# A path word is matched whole, so `release delete` does not cover
# `release delete-asset` the way the old alternation did. The regular
# expression carried delete-asset and nothing asked about it; the rule that
# replaced it named it separately, and these were what would notice if it
# stopped. #97 replaced that rule in turn with an allowlist of read verbs, which
# names no write at all, so these now ask whether delete-asset is still outside
# the list -- and #97's section below asks the rest.
check no-pr-decisions.sh BLOCK 'gh release delete-asset'       'gh release delete-asset v1.0.0 file.tgz'
check no-pr-decisions.sh BLOCK 'gh -R o/r release delete-asset' 'gh -R o/r release delete-asset v1.0.0 file.tgz'
check no-pr-decisions.sh ALLOW 'gh -R o/r api reads a PR'      'gh -R o/r api repos/o/r/pulls/5'
check no-pr-decisions.sh ALLOW 'gh -R o/r issue close 27'      'gh -R o/r issue close 27'

echo "=== REGRESSION: #47, a second gh command after ; or && is examined ==="
# Every rule feeds cs_gh_args one command at a time. These three pin that a
# second command is reached at all: a loop that stopped at the first command,
# or at the first that is not a match, permits every one of them.
check no-pr-decisions.sh BLOCK 'a release list, then a create'      'gh release list; gh release create v1'
check no-pr-decisions.sh BLOCK 'a read api call, then a write'      'gh api repos/o/r/pulls/5 && gh api -X PUT repos/o/r/pulls/5/merge'
check no-pr-decisions.sh BLOCK 'a pr create, then a merge'          'gh pr create --fill && gh pr merge 5'

echo "=== REGRESSION: #47, cs_gh_args answers about the first match and stops ==="
# What the three above do NOT pin, and were written believing they did. The
# helper scans past a command that is not a match, so for a rule with no
# argument expression the per-command loop and one whole-list call find the
# same thing and the mutation is invisible. It is a rule *with* one that needs
# the loop: the first match's arguments come back and a later command's are
# never seen, so handing cs_gh_args the whole list reads this as the --comment
# alone and permits the approval. Measured, not reasoned -- the whole-list
# mutation fails this line and only this line.
check no-pr-decisions.sh BLOCK 'a comment review, then an approval' 'gh pr review --comment -b x 5 && gh pr review -a 6'

echo "=== REGRESSION: #51, a flag before the group evaded the wrapper rules ==="
# The wrapper rules carried the blind spot the section above removed from the
# ordinary ones, one word earlier. They are unanchored, but `pr` still had to
# follow `gh` immediately, so a global flag in front of the group hid it and
# every shape refused above came back the moment it was wrapped. Each of the
# eight rows below was PERMITTED by no-pr-decisions.sh on dev-05 (6f2434c),
# measured before the fix; each is a reserved act. The ninth row is the boundary
# they marked and was refused there already.
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

echo "=== REGRESSION: review of #51, a continuation split the payload ==="
# These rules read raw text, because cs_normalise drops heredoc bodies and
# `bash <<EOF` is a wrapper. Raw text is line-oriented and grep matches within a
# line, so a backslash continuation between the command word and the group hid
# the group -- from these rules only: the ordinary rules read $SCAN, where
# cs_normalise had already joined it. Found by the Standards review of 48ca05d,
# which measured the claim "anything may stand between gh and the group" rather
# than taking it. The joining half of cs_normalise is cs_join now, and these
# rules call it.
check no-pr-decisions.sh BLOCK 'continuation between gh and pr'   $'bash -c "gh \\\n pr merge 5"'
check no-pr-decisions.sh BLOCK 'continuation after a repo flag'   $'bash -c "gh -R o/r \\\n pr merge 5"'
check no-pr-decisions.sh BLOCK 'continuation before the wrapper'  $'bash \\\n -c "gh pr merge 5"'
# The ordinary rules were never blind to this, and still are not.
check no-pr-decisions.sh BLOCK 'continuation, unwrapped merge'    $'gh \\\n pr merge 5'
# Joining is not dropping: a continuation inside heredoc prose is still prose.
check no-pr-decisions.sh ALLOW 'a continuation in heredoc prose'  $'cat > /tmp/n.md <<\'MD\'\nthe hook refuses a wrapped \\\ngh pr merge 5\nMD'

echo "=== ACCEPTED false positive: #51, the verb is not read inside a wrapper ==="
# What refusing the group outright gives up. These are reads and ordinary edits,
# refused with the writes because a wrapped payload is quoted text with no
# command word in it -- the same reason the method of a wrapped `gh api` is not
# read either, which is the check at 'a GET inside bash -c' above. Every one is
# one edit away from working: run it unwrapped.
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
check no-pr-decisions.sh ALLOW 'the same view with no wrapper'     'make test && gh pr view 5'
# And it needs a wrapper in a COMMAND position, not the word in passing. Only
# the surface half of the pair is the loose one; the wrapper half is anchored,
# and CLAUDE.md says so rather than calling both of them "anywhere".
check no-pr-decisions.sh ALLOW 'a wrapper named in passing, then a view' \
  'echo "run bash -c later" && gh pr view 5'
check no-pr-decisions.sh ALLOW 'a wrapper named in a comment body' \
  'gh issue comment 5 -b "try bash -c next" && gh pr view 5'
# The surface half is wider than the gh group: the REST and graphql spellings
# of the same decisions name no gh at all, so the reach lands on them too. These
# are what make "asks for the group name and never looks at the verb" the wrong
# description of this block -- three of its five alternatives are verbs.
check no-pr-decisions.sh BLOCK 'a wrapper, then a bare state=closed' 'bash -c "make test" && echo state=closed'
check no-pr-decisions.sh BLOCK 'a wrapper, then a bare mutation name' 'bash -c "make test" && echo mergePullRequest'
check no-pr-decisions.sh BLOCK 'a wrapper, then a bare /releases'     'bash -c "make test" && echo /releases'
# And it stops there: a wrapper beside something that decides nothing is not
# this file's business, which is what keeps the four BLOCKs above a reach rather
# than a blanket refusal of every wrapped line.
check no-pr-decisions.sh ALLOW 'a wrapper, then an ordinary echo'     'bash -c "make test" && echo hello'
# The rule reaches gh's three deciding surfaces and stops there. A wrapped
# command that is none of them is answered by whatever else covers it, and by
# this file not at all.
check no-pr-decisions.sh ALLOW 'bash -c gh issue close'      'bash -c "gh issue close 27"'
check no-pr-decisions.sh ALLOW 'bash -c gh issue list'       'bash -c "gh issue list"'
check no-pr-decisions.sh ALLOW 'bash -c an ordinary command' 'bash -c "make test"'

echo "=== REGRESSION: #72, gh is a word here and not a suffix ==="
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

echo "=== REGRESSION: review of 02a14d8, close and release through gh api ==="
# Closing a PR and publishing a release were refused in the gh spelling and open
# through gh api, so the boundary was spelling-dependent exactly where the file
# says it is not. PATCH /pulls/N is also how gh pr edit retitles, which stays
# allowed, so the field decides this one rather than the endpoint.
check no-pr-decisions.sh BLOCK 'PATCH a PR to state=closed'  'gh api -X PATCH repos/o/r/pulls/35 -f state=closed'
check no-pr-decisions.sh BLOCK 'PATCH a PR to state=open'    'gh api -X PATCH repos/o/r/pulls/35 -f state=open'
check no-pr-decisions.sh BLOCK 'POST a release'              'gh api -X POST repos/o/r/releases -f tag_name=v1'
check no-pr-decisions.sh BLOCK 'DELETE a release'            'gh api -X DELETE repos/o/r/releases/123'
check no-pr-decisions.sh BLOCK 'graphql closePullRequest'    'gh api graphql -f query="mutation{closePullRequest(input:{x:1})}"'
check no-pr-decisions.sh BLOCK 'graphql createRelease'       'gh api graphql -f query="mutation{createRelease(input:{x:1})}"'
check no-pr-decisions.sh BLOCK 'graphql state on updatePR'   'gh api graphql -f query="mutation{updatePullRequest(input:{state:CLOSED})}"'
# Retitling through that same endpoint is editing, and listing releases is
# reading. Both stay allowed, which is what makes the field test worth having.
check no-pr-decisions.sh ALLOW 'PATCH a PR title'            'gh api -X PATCH repos/o/r/pulls/35 -f title=newtitle'
check no-pr-decisions.sh ALLOW 'GET the releases list'       'gh api repos/o/r/releases'
check no-pr-decisions.sh ALLOW 'gh pr edit retitles'         'gh pr edit 35 --title newtitle'

echo "=== issue #97, a release may be read and not written ==="
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
says "$ON_DEV" no-pr-decisions.sh 'gh help release' \
  'the refusal of bare gh release says where help is' 'gh release'
# 3. A quoted verb is matched as written and refused, rather than unquoted into
#    a read -- the generous reading gh_pr_web gives its reasons for not taking.
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'a quoted read verb' \
  'gh release "view" v1'
echo "--- a flag before the subcommand does not change the verdict ---"
# cs_gh_args skips options before every word of a path, and a subcommand read
# some other way skips none. -R/--repo is the ordinary way to name a repository
# from elsewhere, so each group has both verdicts here, with the flag before the
# verb and with it before the group.
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
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'a view, then an upload' \
  'gh release view v1 && gh release upload v1 a.tgz'
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'a list, then an edit that publishes' \
  'gh release list; gh release edit v1 --draft=false'
flip "$ON_DEV" no-pr-decisions.sh ALLOW BLOCK 'a PR read, then an unknown release subcommand' \
  'gh pr view 5 && gh release frobnicate v1'
# The allowlist is about subcommands of gh release, not about text that names one.
check no-pr-decisions.sh ALLOW 'an issue comment naming a release upload' \
  'gh issue comment 97 --body "gh release upload v1 a.tgz is refused now"'
echo "--- the gh api spelling: a write to /releases is refused, a read is not ---"
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

echo "=== issue #40, a pull request must name an active dev branch as its base ==="
# The quietest of the four spellings names nothing at all: with no base given,
# gh sends the pull request to the repository's default branch, which is main.
# Nothing in the command mentions main, so a denylist over the text could not
# have seen it -- the same shape as the bare push, which is answered the same
# way. The four spellings are checked together because closing one and leaving
# the others is the defect this ticket was filed against.
check no-pr-decisions.sh BLOCK 'create into main'                'gh pr create --base main --title x'
check no-pr-decisions.sh BLOCK 'create into main, --base='       'gh pr create --base=main --title x'
check no-pr-decisions.sh BLOCK 'create into main, -B'            'gh pr create -B main --title x'
check no-pr-decisions.sh BLOCK 'create into main, -B attached'   'gh pr create -Bmain --title x'
check no-pr-decisions.sh BLOCK 'create into main, bundled -dB'   'gh pr create -dB main --title x'
check no-pr-decisions.sh BLOCK 'create into main, bundled -dBmain' 'gh pr create -dBmain --title x'
check no-pr-decisions.sh BLOCK 'create naming no base at all'    'gh pr create --title x --body y'
check no-pr-decisions.sh BLOCK 'a bare create'                   'gh pr create'
check no-pr-decisions.sh BLOCK 'create with --fill and no base'  'gh pr create --fill'
check no-pr-decisions.sh BLOCK 'a base flag whose value never came' 'gh pr create --title x -B'
check no-pr-decisions.sh BLOCK 'create into master'              'gh pr create --base master --title x'
check no-pr-decisions.sh BLOCK 'create into a worktree branch'   'gh pr create --base worktree-issue-40-pr-base'
check no-pr-decisions.sh BLOCK 'create into dev-05-ish, not dev-NN' 'gh pr create --base dev-05-old'
# A flag may sit in front of the verb, which is what cs_gh_args is for; and the
# check is of every create on the line rather than the first, which is what
# obliges the loop to hand it one command at a time.
check no-pr-decisions.sh BLOCK 'flag before the verb, no base'   'gh pr --repo o/r create --title x'
check no-pr-decisions.sh BLOCK 'a good create, then one into main' 'gh pr create --base dev-05 --title x && gh pr create --base main --title y'
# Retargeting is choosing the destination a second time.
check no-pr-decisions.sh BLOCK 'retarget to main'                'gh pr edit 35 --base main'
check no-pr-decisions.sh BLOCK 'retarget to main, -B'            'gh pr edit 35 -B main'
check no-pr-decisions.sh BLOCK 'retarget, flag before the verb'  'gh pr --repo o/r edit 35 --base main'
# The API forms. The gate is the write test the file already had, not the
# endpoint: matching an endpoint is what once refused a read of a pull request
# as though it were a decision.
check no-pr-decisions.sh BLOCK 'REST create into main'           'gh api -X POST repos/o/r/pulls -f base=main -f head=x'
check no-pr-decisions.sh BLOCK 'REST create, value attached'     'gh api -X POST repos/o/r/pulls -fbase=main'
check no-pr-decisions.sh BLOCK 'REST create naming no base'      'gh api -X POST repos/o/r/pulls -f head=x -f title=y'
check no-pr-decisions.sh BLOCK 'REST retarget to main'           'gh api -X PATCH repos/o/r/pulls/35 -f base=main'
check no-pr-decisions.sh BLOCK 'graphql create into main'        'gh api graphql -f query="mutation{createPullRequest(input:{baseRefName:main})}"'
check no-pr-decisions.sh BLOCK 'graphql create, base quoted'     "gh api graphql -f query='mutation{createPullRequest(input:{baseRefName:\"main\"})}'"
check no-pr-decisions.sh BLOCK 'graphql create naming no base'   'gh api graphql -f query="mutation{createPullRequest(input:{headRefName:x})}"'
# A wrapper hides the base behind quotes, where there is no command position to
# find and nothing to read. Refused outright, as a wrapped push and a wrapped
# read of a pull request already are.
check no-pr-decisions.sh BLOCK 'a good create inside bash -c'    "bash -c 'gh pr create --base dev-05 --title x'"
check no-pr-decisions.sh BLOCK 'a REST create inside bash -c'    "bash -c 'gh api -X POST repos/o/r/pulls -f base=dev-05'"
# The accepted false positive, recorded rather than worked around: cs_split cuts
# on the parens of a command substitution, so a base written after one lands in
# a later fragment and the create no longer names one. Put the base first.
check no-pr-decisions.sh BLOCK 'base written after a substitution' 'gh pr create --title x --body "$(cat b.md)" --base dev-05'

echo "=== issue #40, a base naming a dev branch is permitted in every spelling ==="
check no-pr-decisions.sh ALLOW 'create into the dev branch'      'gh pr create --base dev-05 --title x --body y'
check no-pr-decisions.sh ALLOW 'create into dev, --base='        'gh pr create --base=dev-05 --title x'
check no-pr-decisions.sh ALLOW 'create into dev, -B'             'gh pr create -B dev-05 --title x'
check no-pr-decisions.sh ALLOW 'create into dev, -B attached'    'gh pr create -Bdev-05 --title x'
check no-pr-decisions.sh ALLOW 'create into an older dev-NN'     'gh pr create --base dev-04 --title x'
check no-pr-decisions.sh ALLOW 'flag before the verb, good base' 'gh pr --repo o/r create --base dev-05 --title x'
check no-pr-decisions.sh ALLOW 'base first, then a substitution' 'gh pr create --base dev-05 --body "$(cat b.md)"'
# The browser hand-off creates nothing: a person on the prefilled page chooses
# the base and confirms. That exempts a missing base and nothing else.
check no-pr-decisions.sh ALLOW 'browser hand-off, --web'         'gh pr create --web'
check no-pr-decisions.sh ALLOW 'browser hand-off, -w'            'gh pr create -w'
check no-pr-decisions.sh BLOCK '--web does not launder a base'   'gh pr create --web --base main'
check no-pr-decisions.sh ALLOW 'retarget to the dev branch'      'gh pr edit 35 --base dev-05'
check no-pr-decisions.sh ALLOW 'edit without touching the base'  'gh pr edit 35 --add-label bug'
check no-pr-decisions.sh ALLOW 'REST create into dev'            'gh api -X POST repos/o/r/pulls -f base=dev-05 -f head=x'
check no-pr-decisions.sh ALLOW 'graphql create into dev'         "gh api graphql -f query='mutation{createPullRequest(input:{baseRefName:\"dev-05\"})}'"
# Reads name no destination and are not asked for one, which is what keeps the
# write test doing this work rather than the endpoint.
check no-pr-decisions.sh ALLOW 'listing pull requests'           'gh api repos/o/r/pulls'
check no-pr-decisions.sh ALLOW 'reading one pull request'        'gh api repos/o/r/pulls/35'
check no-pr-decisions.sh ALLOW 'listing beside another write'    'gh api -X POST repos/o/r/issues -f title=x && gh api repos/o/r/pulls'
# A write that names no base and creates nothing is not a pull request at all.
check no-pr-decisions.sh ALLOW 'PATCH a PR body, the -F habit'   'gh api -X PATCH repos/o/r/pulls/35 -F body=@body.md'
check no-pr-decisions.sh ALLOW 'creating an issue'               'gh api -X POST repos/o/r/issues -f title=x'
check no-pr-decisions.sh ALLOW 'gh issue create names no base'   'gh issue create --title x --body y'

echo "=== REGRESSION: review of be0e3c7, the base rule's own permitting holes ==="
# Four found by review, none of them named by the section above, which was green.
# The pattern of this repository holds a fifth time: every one was silent and in
# the permitting direction.
#
# 1. A repeated flag. gh takes the last; the rule read the first, so a create
# that had already shown a dev branch could name main after it and go there.
# Every base must now be dev-NN, which does not depend on knowing gh's
# precedence.
check no-pr-decisions.sh BLOCK 'good base, then a bad one'   'gh pr create --base dev-05 -B main'
check no-pr-decisions.sh BLOCK 'bad base, then a good one'   'gh pr create -B main --base dev-05'
check no-pr-decisions.sh BLOCK 'two long bases disagreeing'  'gh pr create --base dev-05 --base main'
# 2. The web exemption read any single-dash token holding a w, and read it out of
# quoted prose. Both halves mattered: a label value, and a title naming a flag --
# a title a session working on this very file would write.
check no-pr-decisions.sh BLOCK 'a label value beginning -w'  'gh pr create -l -wip --title x'
check no-pr-decisions.sh BLOCK 'a bundle holding w'          'gh pr create -twibble --body y'
check no-pr-decisions.sh BLOCK 'a title naming -w'           'gh pr create --title "Handle -w in gh_pr_web" --body y'
check no-pr-decisions.sh BLOCK 'a body naming -watch'        'gh pr create --title x --body "adds -watch mode"'
# The exemption itself still works. The asymmetry that used to be recorded here
# is gone: both readers drop a quoted span whole now. Unquoting one can invent a
# flag, and inventing a --base in a command that named none removes a refusal
# just as inventing a -w does, which is the half this comment used to miss. See
# base_args, and group 5.
check no-pr-decisions.sh ALLOW 'the web form, unbundled'     'gh pr create -w --title x'
check no-pr-decisions.sh ALLOW 'the web form, long'          'gh pr create --web --title x'
# Still refused, and now for naming no base rather than for naming a bad one.
check no-pr-decisions.sh BLOCK 'a title naming -B main'      'gh pr create --title "-B main" --body y'

# 5. A base read out of prose. `tr -d` deleted the quote characters and kept
# what stood between them, so a body naming the flag named a base in a command
# that named none -- and gh would have sent that create to the repository
# default branch with this hook satisfied, which is the one shape #40 exists to
# refuse, arriving through a body. The trigger is not contrived: a body quoting
# the command it is about is how the pull requests in this repository are
# written. base_args drops a quoted span whole and unquotes only a base flag own
# value.
check no-pr-decisions.sh BLOCK 'a base named only in a body'      'gh pr create --title t --body "--base dev-05"'
check no-pr-decisions.sh BLOCK 'a base named only in a title'     'gh pr create --title "--base dev-05" --body b'
check no-pr-decisions.sh BLOCK 'a body quoting the command'       'gh pr create --title x --body "Write: gh pr create --base dev-05 --title ..."'
check no-pr-decisions.sh BLOCK 'a shorthand base in a body'       'gh pr create --title t --body "-B dev-05"'
# The other direction, which the same defect caused: prose naming the flag made
# a correct create refuse.
check no-pr-decisions.sh ALLOW 'a body naming the base flag'      'gh pr create --base dev-05 --title t --body "the --base flag"'
check no-pr-decisions.sh ALLOW 'a body naming a main retarget'    'gh pr create --base dev-05 --title t --body "use -B main to retarget"'
check no-pr-decisions.sh ALLOW 'an edit titled after the flag'    'gh pr edit 5 --title "--base main"'
# A base flag own value is the one quoted span that is kept, in either quote,
# because gh takes either. Dropping it would refuse a correctly based create.
check no-pr-decisions.sh ALLOW 'a double-quoted base value'       'gh pr create --base "dev-05" --title t'
check no-pr-decisions.sh ALLOW 'a single-quoted base value'       "gh pr create --base 'dev-05' --title t"
check no-pr-decisions.sh BLOCK 'a quoted base naming main'        'gh pr create --base "main" --title t'
check no-pr-decisions.sh BLOCK 'a quoted retarget to main'        'gh pr edit 5 --base "main"'
# 6. A graphql string value is quoted, and the shell quoting around the query
# commonly escapes those quotes. gql_bases read the backslash as the whole value
# and refused a dev-NN base for not being one. Refusing direction, so it sat
# behind the two spellings that did work, both of which are pinned above.
check no-pr-decisions.sh ALLOW 'graphql into dev, escaped'        'gh api graphql -f query="mutation{createPullRequest(input:{baseRefName:\"dev-05\"})}"'
check no-pr-decisions.sh BLOCK 'graphql into main, escaped'       'gh api graphql -f query="mutation{createPullRequest(input:{baseRefName:\"main\"})}"'
# 3. The gh api base was read from the whole line, so a neighbouring command
# answered for this one -- in both directions. This is the first of the five
# defects lib/command-scan.sh exists to end, reintroduced for gh api after being
# fixed for gh pr.
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
check no-pr-decisions.sh ALLOW 'an issue write beside prose' 'gh api -X POST repos/o/r/issues -f title=x && echo "base=main"'
check no-pr-decisions.sh ALLOW 'an issue write naming rebase' 'gh api -X POST repos/o/r/issues -f title="rebase onto main"'
# The graphql retarget carries the same field as the create, and is refused with
# it rather than by naming the verb.
check no-pr-decisions.sh BLOCK 'graphql retarget to main'    'gh api graphql -f query="mutation{updatePullRequest(input:{baseRefName:main})}"'
# 4. These two were pinned ALLOW while #40 carried a wrapper rule of its own,
# which read the payload far enough to tell a listing from a create. #51
# settled that the payload cannot be read at all and refuses every wrapped
# gh pr, gh release and gh api whatever follows, so #40 no longer has a
# wrapper rule and these are refused with the rest of that surface. Both are
# one edit away from working: run them unwrapped.
check no-pr-decisions.sh BLOCK 'a wrapped listing'           "bash -c 'gh api repos/o/r/pulls'"
check no-pr-decisions.sh BLOCK 'a wrapped label edit'        "bash -c 'gh pr edit 35 --add-label bug'"
check no-pr-decisions.sh BLOCK 'a wrapped retarget'          "bash -c 'gh pr edit 35 --base main'"
check no-pr-decisions.sh BLOCK 'a wrapped REST create'       "bash -c 'gh api -X POST repos/o/r/pulls -f base=dev-05'"
# What #40's own wrapper rule used to refuse, still refused, by #51 naming the
# surface rather than by anything reading a base out of quoted text.
check no-pr-decisions.sh BLOCK 'a wrapped create into main'  'bash -c "gh pr create --base main"'
check no-pr-decisions.sh BLOCK 'a wrapped create, flag first' 'bash -c "gh -R o/r pr create --base main"'
check no-pr-decisions.sh BLOCK 'a wrapped baseless create'   'bash -c "gh pr create --fill"'

echo "=== the push argument split does not glob against the worktree ==="
# `for TOK in $ARGS` is unquoted because the split is the point; set -f stops
# the same line expanding ? and [...] against the files sitting next to it.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a ? wildcard refspec'     'git push origin ?'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a [...] wildcard refspec' 'git push origin [a-z]*'

echo "=== worktree exception: pushing this worktree's own branch ==="
# Every permitted push names the branch. That is the whole exception: a push
# that does not name it is answered by configuration instead, and configuration
# is not a thing this hook can hold still. See the bare-push section below.
check_in "$PUSH_WT" no-git-push.sh ALLOW 'push naming this branch'          "git push origin $PUSH_BRANCH"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'push after a commit'              "git commit -m msg && git push origin $PUSH_BRANCH"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'push in a subshell'               "(git push origin $PUSH_BRANCH)"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'push with a trailing ;'           "git push origin $PUSH_BRANCH;"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'git push -u origin <this branch>' "git push -u origin $PUSH_BRANCH"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'indented push, own branch'        $'if true; then\n    git push origin '"$PUSH_BRANCH"$'\nfi'
# An unrelated -f elsewhere on the line is not the push's own flag. Every option
# check reads the push's arguments, not the whole command, so this still passes.
check_in "$PUSH_WT" no-git-push.sh ALLOW 'rm -f before an ordinary push'    "rm -f notes.md && git push origin $PUSH_BRANCH"

echo "=== REGRESSION: issue #50, a redirect was read as a refspec ==="
# Nothing removed redirections, so `2>/dev/null` was the refspec and the message
# said so in as many words. A stderr redirect is a shape an agent writes without
# meaning anything by it -- `2>&1 | tail -3` on a push is how you read the result
# of one -- so by the stopping rule in no-git-push.sh that is a defect.
#
# PR #48 reported the `2>&1` spelling and blamed the split on &. That is true of
# that spelling and was not the cause: `2>/dev/null` holds no & and was refused
# just the same. cs_normalise drops the redirection now, before cs_split sees it.
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
check_in "$PUSH_WT" no-git-push.sh BLOCK 'legit push 2>&1 then push --all'  "git push origin $PUSH_BRANCH 2>&1 | tail -3; git push --all origin"
check no-pr-decisions.sh BLOCK 'gh pr merge with a redirect'  'gh pr merge 35 >/dev/null 2>&1'
check no-pr-decisions.sh BLOCK 'gh pr review -a, redirected'  'gh pr review -a 35 2>&1 | tail -1'
check no-pr-decisions.sh ALLOW 'gh pr view with a redirect'   'gh pr view 35 > /tmp/pr.json'

echo "=== ACCEPTED false positive: a quoted redirect target ==="
# The target scan stops at a quote, so a quoted target is not consumed and its
# text stays in the push's arguments, where it reads as a refspec. Issue #50
# asked for every redirect on a permitted push to be allowed and granted no
# exception, so this is a shortfall against it rather than a decision the issue
# made -- taken because consuming a quoted target would mean the drop swallowing
# text it cannot see the end of, which is the direction that has gone wrong
# three times in this file. The targets an agent writes -- /dev/null, out.txt,
# push.log -- carry no quotes.
#
# Pinned in both directions so a later change cannot move it silently. If these
# become ALLOW, that is a decision to take knowingly, not a bug fix.
tok 'a quoted target is left in the arguments' \
    'git push origin b "push log"' \
    "$(printf 'git push origin b 2> "push log"\n' | cs_normalise)"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'push with a quoted redirect target' "git push origin $PUSH_BRANCH 2> \"push log\""
check_in "$PUSH_WT" no-git-push.sh ALLOW 'the same target unquoted' "git push origin $PUSH_BRANCH 2> push.log"

echo "=== REGRESSION: issue #50, the drop must not hide a command ==="
# Dropping is the one step in cs_normalise that hides text rather than exposing
# it, and the heredoc question was got wrong three times in exactly that
# direction. A process substitution carries a command, so it is not a redirect;
# a command substitution used as a target is not a target. Both are pinned here
# with a refused command inside, so hiding one would show up as ALLOW.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'push inside <( )'             'cat <(git push --all origin)'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'push inside >( )'             'tee >(git push --all origin)'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'push as a backticked target'  'echo > `git push --all origin`'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'push as a $( ) target'        'echo > $(git push --all origin)'
check no-pr-decisions.sh BLOCK 'merge inside <( )'            'cat <(gh pr merge 35)'
check no-pr-decisions.sh BLOCK 'merge as a $( ) target'       'echo > $(gh pr merge 35)'

echo "=== REGRESSION: PR #35 review, a bare push is answered by configuration ==="
# A push naming no refspec is sent where push.default, a remote.<name>.push
# refspec, or the branch's upstream says -- and -c sets any of those for one
# command, past whatever this hook reads back afterwards. The old check read
# push.default alone, so `git -c push.default=matching push` was ALLOW: it would
# have carried every branch whose name exists on both sides, dev-05 included.
#
# The trade, taken knowingly: `git push` and `git push origin` were permitted
# and are refused now. The destination has to be in the command, which is what
# CLAUDE.md already asked for -- a push "positively naming that branch".
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

echo "=== forced pushes, refused in every spelling ==="
# Forcing rewrites what the remote already has, which for this branch is the
# history an open pull request is showing. --force-with-lease is refused with
# the rest: it guards against clobbering another person's work, not against
# rewriting a PR under its reviewer.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'git push -f'                   'git push -f'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'git push --force'              'git push --force'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'git push --force-with-lease'   'git push --force-with-lease'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'lease with a value'            "git push --force-with-lease=$PUSH_BRANCH origin"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'git push --force-if-includes'  'git push --force-if-includes origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'bundled short flags -fu'       "git push -fu origin $PUSH_BRANCH"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'forced by leading + on refspec' "git push origin +$PUSH_BRANCH"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'forced push of own branch'     "git push -f origin $PUSH_BRANCH"

echo "=== worktree exception does not extend to ==="
check_in "$PUSH_WT" no-git-push.sh BLOCK 'another branch by name: main'      'git push origin main'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'another branch by name: dev-05'    'git push origin dev-05'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a refspec destination: HEAD:main'  'git push origin HEAD:main'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a forced push to dev-05'           'git push -f origin dev-05'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a cd before the push'              'cd /tmp && git push'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a cd before the push, with ;'      'cd /tmp; git push'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'git redirected with -C'            'git -C /home/bgunyel/source/ai/clause-and-effect push'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'git redirected with --git-dir'     'git --git-dir=/elsewhere/.git push'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a push inside sh -c'               'sh -c "git push"'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a push inside bash -c'             'bash -c "git push origin dev-05"'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a push inside eval'                'eval "git push"'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a push inside a heredoc fed to sh' $'bash <<\'EOF\'\ngit push\nEOF'

echo "=== ACCEPTED false positive: the wrapper rule reaches across the line here too ==="
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

echo "=== REGRESSION: PR #35, a denylist could not see a push naming no branch ==="
# The check refused branches by name, so any spelling that named none was
# invisible: --all advanced main and dev-05 from any worktree, and --mirror
# deleted every remote branch absent locally, closing open pull requests. The
# check is now an allowlist -- the push must positively name this branch.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'git push --all origin'      'git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'git push --mirror origin'   'git push --mirror origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'git push --prune origin'    'git push --prune origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'git push origin --tags'     'git push origin --tags'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'git push --follow-tags'     'git push --follow-tags origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'wildcard refspec, forced'   'git push origin +refs/heads/*:refs/heads/*'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'deleting a remote branch'   "git push origin --delete $PUSH_BRANCH"
check_in "$PUSH_WT" no-git-push.sh BLOCK 'deleting by empty source'   'git push origin :main'

echo "=== REGRESSION: PR #35, redirects and cd forms the rules did not reach ==="
# An environment assignment precedes the command, so git was not at a command
# position and the push was never even detected; the anchors now allow a VAR=
# prefix. pushd changes directory exactly as cd does.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'GIT_DIR= prefix'     'GIT_DIR=/other/.git git push origin main'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'GIT_WORK_TREE= prefix' 'GIT_WORK_TREE=/other git push'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'pushd before a push'  'pushd /some/repo && git push'
check no-pr-decisions.sh BLOCK 'env prefix before gh' 'FOO=1 gh pr merge 35'

echo "=== the allowlist still admits an ordinary push of this branch ==="
check_in "$PUSH_WT" no-git-push.sh ALLOW 'git push origin HEAD'           "git push origin HEAD"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'git push origin HEAD:<branch>'  "git push origin HEAD:$PUSH_BRANCH"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'git push origin <b>:<b>'        "git push origin $PUSH_BRANCH:$PUSH_BRANCH"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'push option with a value'       "git push -o ci.skip origin $PUSH_BRANCH"

echo "=== REGRESSION: PR #35, a line continuation emptied the argument scope ==="
# The scope ran from push to the next shell separator; a newline ended it, and
# an empty scope fell through to the bare-push case, the permitted one. So one
# wrapped line turned any push into an ordinary one -- --mirror included, which
# deletes remote branches and closes open PRs. Continuations are now joined
# before anything is matched.
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
check_in "$PUSH_WT" no-git-push.sh ALLOW 'continued push of this branch'     $'git push \\\n  origin '"$PUSH_BRANCH"

echo "=== the remote must be a remote of this repository ==="
# Nothing required the first bare token to be a remote, so a URL or a typo was
# admitted whenever the refspec named this branch. Raised on PR #35.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'a foreign remote URL'    'git push git@github.com:someone/else.git HEAD'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'an undefined remote name' 'git push upstream HEAD'
check_in "$PUSH_WT" no-git-push.sh ALLOW 'origin is a real remote' "git push origin $PUSH_BRANCH"

echo "=== no-git-push.sh : not a push at all ==="
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

echo "=== REGRESSION: issue #94, a subdirectory of the main checkout read as a linked worktree ==="
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
check_in "$PUSH_MAIN"          no-git-push.sh BLOCK 'main checkout, root: a push of its own branch' \
  'git push origin feature-x'
check_in "$PUSH_MAIN/src"      no-git-push.sh BLOCK 'main checkout, src/: a push of its own branch' \
  'git push origin feature-x'
check_in "$PUSH_MAIN/src/deep" no-git-push.sh BLOCK 'main checkout, src/deep/: a push of its own branch' \
  'git push origin feature-x'
# Which refusal, and not merely that one fired: below the root the command is
# otherwise a plain push naming the checked-out branch, so a message from any
# other rule would mean the main checkout was still not recognised.
says "$PUSH_MAIN/src/deep" no-git-push.sh 'This is the main checkout, not a linked worktree' \
  'main checkout, src/deep/: refused as the main checkout' 'git push origin feature-x'
# The permitting half at the same three depths. What the directory decides is
# whether a push is permitted, not whether git may be used at all.
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
check_in "$PUSH_WT"            no-git-push.sh ALLOW 'linked worktree, root: a push naming its own branch' \
  "git push origin $PUSH_BRANCH"
check_in "$PUSH_WT/src"        no-git-push.sh ALLOW 'linked worktree, src/: a push naming its own branch' \
  "git push origin $PUSH_BRANCH"
check_in "$PUSH_WT/src/deep"   no-git-push.sh ALLOW 'linked worktree, src/deep/: a push naming its own branch' \
  "git push origin $PUSH_BRANCH"
check_in "$PUSH_WT"            no-git-push.sh BLOCK 'linked worktree, root: a push of main' \
  'git push origin main'
check_in "$PUSH_WT/src"        no-git-push.sh BLOCK 'linked worktree, src/: a push of main' \
  'git push origin main'
check_in "$PUSH_WT/src/deep"   no-git-push.sh BLOCK 'linked worktree, src/deep/: a push of main' \
  'git push origin main'
check_in "$PUSH_WT"            no-git-push.sh BLOCK 'linked worktree, root: a push of a dev branch' \
  'git push origin dev-99'
check_in "$PUSH_WT/src"        no-git-push.sh BLOCK 'linked worktree, src/: a push of a dev branch' \
  'git push origin dev-99'
check_in "$PUSH_WT/src/deep"   no-git-push.sh BLOCK 'linked worktree, src/deep/: a push of a dev branch' \
  'git push origin dev-99'
echo "--- both, reached through a symlink ---"
# Resolving each path by the directory it names, and not by the spelling $PWD
# gives it, is half of the fix; these are what fail if the -P on pwd is dropped.
check_in "$PUSH_MAIN_LINK/src/deep" no-git-push.sh BLOCK 'main checkout through a symlink, src/deep/: a push of its own branch' \
  'git push origin feature-x'
check_in "$PUSH_WT_LINK/src/deep"   no-git-push.sh ALLOW 'linked worktree through a symlink, src/deep/: a push naming its own branch' \
  "git push origin $PUSH_BRANCH"

echo "=== no-pr-decisions.sh : must BLOCK ==="
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

echo "=== no-pr-decisions.sh : must ALLOW ==="
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
do check no-pr-decisions.sh ALLOW "$c" "$c"; done

echo "=== REGRESSION: review of #43, prefixes and separated options hid commands ==="
# Found by reviewing the #43 migration, fixed in lib/command-scan.sh, and
# therefore not about no-commit-to-main.sh: every hook was blind to these.
# cs_split stripped a wrapper word and its options but not an operand, so
# `timeout 30` left a bare 30 where the command word had to be; sudo, doas,
# setsid and chronic were not wrapper words at all; and cs_git_args skipped
# --git-dir only in its = form, so the separated one hid the subcommand behind
# its own value.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'timeout before a wholesale push' 'timeout 5 git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'sudo before a mirror push'       'sudo git push --mirror origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'separated --git-dir before a push' 'git --git-dir /tmp/other/.git push --all origin'
check no-pr-decisions.sh BLOCK 'setsid before a merge'           'setsid gh pr merge 5'
check no-pr-decisions.sh BLOCK 'sudo before a merge'             'sudo gh pr merge 5'
# The operand strip takes one token and only if it is not an option, so an
# ordinary command that begins with one of these words is still itself.
check_in "$PUSH_WT" no-git-push.sh ALLOW 'timeout in front of something else' 'timeout 5 make test'
check_in "$PUSH_WT" no-git-push.sh ALLOW 'sudo in front of something else'    'sudo apt-get install jq'

# Found by reviewing PR #49, and the same defect one turn further on. Stripping
# a wrapper word and its options leaves the value of any option that took one
# where the command word has to be, so the operand rule above closes `timeout
# 30` and not `timeout -s KILL 30`, and closes nothing at all for the wrapper
# words that have no operand rule. cs_split offers the tail as further
# candidates rather than keeping a third list of which options take a value.
check_in "$PUSH_WT" no-git-push.sh BLOCK 'sudo with a separated option value'   'sudo -u root git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'nice with a separated niceness'       'nice -n 10 git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'ionice with a separated class'        'ionice -c 2 git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'timeout whose signal took the operand' 'timeout -s KILL 30 git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'xargs with a separated count'         'xargs -n 1 git push --all origin'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'env with a separated directory'       'env -C /tmp git push --all origin'
check no-pr-decisions.sh BLOCK 'sudo with a separated option value, before a merge' \
  'sudo -u root gh pr merge 5'
# The tail only ever adds candidates, so an ordinary command that begins with a
# wrapper word still yields itself and the additions refuse nothing.
check_in "$PUSH_WT" no-git-push.sh ALLOW 'a wrapper option value in front of something else' \
  'sudo -u root apt-get install jq'
check_in "$PUSH_WT" no-git-push.sh ALLOW 'a commit whose message quotes a push, behind a wrapper' \
  'sudo git commit -m "git push --all origin"'

echo "=== no-commit-to-main.sh : invariants, identical literals across #43 ==="
# What the migration preserved. These six were written before it, are green on
# both sides of it, and are the whole of what this file is for: main is not
# committed to, and main is not pushed to.
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
check_in "$ON_MAIN" no-commit-to-main.sh BLOCK 'a bare push while on main' \
  'git push'
# The other side of the bare push, and the commands this file has no opinion
# about at all. Also invariant: a commit message may name a push, and a push of
# a dev branch is no business of this file's.
check_in "$ON_DEV"  no-commit-to-main.sh ALLOW 'a bare push on a dev branch' \
  'git push'
check_in "$ON_DEV"  no-commit-to-main.sh ALLOW 'push of a dev branch' \
  'git push origin dev-99'
check_in "$ON_DEV"  no-commit-to-main.sh ALLOW 'commit message naming a push' \
  'git commit -m "explain how to git push later"'
check_in "$ON_MAIN" no-commit-to-main.sh ALLOW 'neither a commit nor a push' \
  'git status'
check_in "$ON_MAIN" no-commit-to-main.sh BLOCK 'commit after a control word' \
  'if true; then git commit -m "wip"; fi'
# A commit message is the one argument here that carries arbitrary prose, so
# the directory options are matched only where git accepts them. Permitted
# before the migration for a weaker reason -- they were not matched at all.
check_in "$ON_DEV"  no-commit-to-main.sh ALLOW 'a commit message naming -C' \
  'git commit -m "stop matching -C everywhere"'
# A prefix word the old anchor did not care about, because it looked only for a
# space in front of `git`. cs_split strips a known wrapper word and its
# options, and these were not in its list -- so the migration first lost these
# four, in the permitting direction, and lib/command-scan.sh was corrected
# rather than the loss being recorded. Found reviewing the migration.
check_in "$ON_MAIN" no-commit-to-main.sh BLOCK 'sudo in front of a commit on main' \
  'sudo git commit -m "wip"'
check_in "$ON_MAIN" no-commit-to-main.sh BLOCK 'timeout, whose operand is not an option' \
  'timeout 30 git commit -m "wip"'
check_in "$ON_DEV"  no-commit-to-main.sh BLOCK 'timeout in front of a push to main' \
  'timeout 30 git push origin main'
check_in "$ON_DEV"  no-commit-to-main.sh BLOCK 'sudo in front of a push to main' \
  'sudo git push origin main'

echo "=== no-commit-to-main.sh : what #43 changed, verdict by verdict ==="
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
flip "$ON_DEV"  no-commit-to-main.sh ALLOW BLOCK 'cd into a repository on main, then commit' \
  "cd $ON_MAIN && git commit -m 'on main'"
flip "$ON_DEV"  no-commit-to-main.sh ALLOW BLOCK 'GIT_DIR pointed at a repository on main' \
  "GIT_DIR=$ON_MAIN/.git git commit -m 'on main'"
flip "$ON_DEV"  no-commit-to-main.sh ALLOW BLOCK 'git -C into another repository' \
  "git -C $ON_MAIN commit -m 'on main'"
# A wrapper's payload sits in quotes, where the old anchor found no command at
# all: a wrapped commit was permitted on main itself. Refused outright now,
# as in both sibling hooks.
flip "$ON_MAIN" no-commit-to-main.sh ALLOW BLOCK 'sh -c wrapping a commit, on main' \
  "sh -c 'git commit -m \"wip\"'"
flip "$ON_DEV"  no-commit-to-main.sh ALLOW BLOCK 'eval wrapping a push to main' \
  'eval "git push origin main"'
# Matching main by name could not see a spelling that named no branch, which is
# the hole PR #35 closed in no-git-push.sh and left open here. Both of these
# advance main from a dev branch.
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
check_in "$ON_DEV" no-commit-to-main.sh ALLOW 'HEAD off main still names a dev branch' \
  'git push origin HEAD'
# Changing branch defeats the branch read exactly as changing directory does,
# and is the likelier of the two. Refusing directory moves while permitting
# this left the soundness claim half-made. Found reviewing the migration.
flip "$ON_DEV"  no-commit-to-main.sh ALLOW BLOCK 'checkout main, then commit' \
  'git checkout main && git commit -m "wip"'
flip "$ON_DEV"  no-commit-to-main.sh ALLOW BLOCK 'switch to main, then commit' \
  'git switch main && git commit -m "wip"'
# git's directory options in their separated spelling. cs_git_args skipped
# --git-dir only in its = form, so the separated one left the path at the head
# of the line, the subcommand was never found, and this file left without an
# opinion -- with `main` written in the command. Found reviewing the migration.
flip "$ON_DEV"  no-commit-to-main.sh ALLOW BLOCK 'separated --git-dir before commit' \
  "git --git-dir $ON_MAIN/.git commit -m 'on main'"
flip "$ON_DEV"  no-commit-to-main.sh ALLOW BLOCK 'separated --namespace before a push to main' \
  'git --namespace n push origin main'

# What this file does when lib/command-scan.sh is not loadable is checked in the
# load-contract section at the foot of this suite, with the same question asked of
# the other three hooks. It was asked here, of this hook alone, and issue #84
# found two hooks with no guard at all and a third requiring one function of three
# while both blocks stayed green.

echo "=== the refusals still name main, which is why this file is kept ==="
says "$ON_MAIN" no-commit-to-main.sh 'Blocked: committing to main.' \
  'a commit on main is refused as a commit on main' 'git commit -m "wip"'
says "$ON_DEV"  no-commit-to-main.sh 'Blocked: pushing to main.' \
  'a push to main is refused as a push to main' 'git push origin main'
says "$ON_MAIN" no-commit-to-main.sh "bare 'git push' while on main" \
  'the bare push keeps its own wording' 'git push'
says "$ON_DEV"  no-commit-to-main.sh 'whether it lands on main' \
  'a directory move says what cannot be judged' "cd $ON_MAIN && git commit -m 'wip'"

echo "=== no-work-on-stale-branch.sh: a branch whose life is over ==="
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
check_in "$WT_GONE" no-work-on-stale-branch.sh BLOCK 'merge naming the dev branch is still refused' \
  'git merge origin/dev-05'
check_in "$WT_GONE" no-work-on-stale-branch.sh BLOCK 'rebase naming the dev branch is still refused' \
  'git rebase origin/dev-05'
# A refusal mid-rebase strands state the agent cannot exit.
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
check_in "$WT_GONE" no-work-on-stale-branch.sh ALLOW 'a read is not work' \
  'git log --oneline -5'
check_in "$WT_GONE" no-work-on-stale-branch.sh ALLOW 'a command with no git in it at all' \
  'ls -la'
check_in "$WT_GONE" no-work-on-stale-branch.sh BLOCK 'a commit wrapped in a shell' \
  "sh -c 'git commit -m \"wip\"'"
check_in "$WT_GONE" no-work-on-stale-branch.sh BLOCK 'a cherry-pick wrapped in eval' \
  'eval "git cherry-pick 1234abc"'
# The fourth consumer's share of issue #79: the same two commands behind a
# prefix word this hook's wrapper rule could not see. Each was ALLOW before the
# anchor was widened, and the #79 section above says these live here rather
# than beside its own checks, because the verdicts need these fixtures.
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
check_in "$WT_GONE" no-work-on-stale-branch.sh ALLOW 'grepping for the sudo sh -c rule' \
  "grep -rn 'sudo sh -c .*git commit' .claude/hooks/"

echo "--- the fallback: ahead == 0, behind > 0 against the active dev branch ---"
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
check_in "$WT_STALE" no-work-on-stale-branch.sh ALLOW 'a cd quoted in a sibling command (was BLOCK)' \
  "git merge origin/dev-05 && echo 'x; cd /tmp'"
check_in "$WT_STALE" no-work-on-stale-branch.sh ALLOW 'a checkout quoted in a sibling command (was BLOCK)' \
  "git merge origin/dev-05 && echo 'x; git checkout main'"
check_in "$WT_STALE" no-work-on-stale-branch.sh BLOCK 'an unquoted cd still withdraws the carve-out' \
  'cd /tmp && git merge origin/dev-05'
check_in "$WT_STALE" no-work-on-stale-branch.sh BLOCK 'an unquoted checkout still withdraws it' \
  'git checkout main && git merge origin/dev-05'
# Every command, not the first: the permitted half does not license the second.
check_in "$WT_STALE" no-work-on-stale-branch.sh BLOCK 'a permitted merge followed by a commit' \
  'git merge origin/dev-05 && git commit -m "wip"'
check_in "$WT_STALE" no-work-on-stale-branch.sh ALLOW 'rebase --continue' \
  'git rebase --continue'
check_in "$WT_STALE" no-work-on-stale-branch.sh BLOCK 'a commit message naming a continuation flag' \
  'git commit -m "permit rebase --continue"'
check_in "$WT_STALE" no-work-on-stale-branch.sh BLOCK 'a merge message naming a continuation flag' \
  'git merge -m "wip --continue" some-other-branch'
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
check_in "$WT_BAD" no-work-on-stale-branch.sh ALLOW 'a dev tip that is not a commit: the ancestry is unreadable, so the guard abstains' \
  'git commit -m "wip"'

echo "--- branches whose life is not over, and the main checkout ---"
check_in "$WT_WORK"  no-work-on-stale-branch.sh ALLOW 'a branch carrying work of its own, ahead == 1' \
  'git commit -m "wip"'
check_in "$WT_FRESH" no-work-on-stale-branch.sh ALLOW 'a fresh branch at the dev tip, ahead == 0 behind == 0' \
  'git commit -m "wip"'
# The same commit, the same state, the same command -- and the main checkout is
# unaffected, because the guard keys on the linked worktree.
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
check_in "$LIFE/src"          no-work-on-stale-branch.sh ALLOW 'main checkout, src/: an ordinary commit is not lifecycle work' \
  'git commit -m "wip"'
check_in "$LIFE/src/deep"     no-work-on-stale-branch.sh ALLOW 'main checkout, src/deep/: an ordinary commit is not lifecycle work' \
  'git commit -m "wip"'
check_in "$WT_STALE/src"      no-work-on-stale-branch.sh BLOCK 'stale worktree, src/: a commit is still refused' \
  'git commit -m "wip"'
check_in "$WT_STALE/src/deep" no-work-on-stale-branch.sh BLOCK 'stale worktree, src/deep/: a commit is still refused' \
  'git commit -m "wip"'
check_in "$LIFE_LINK/src/deep" no-work-on-stale-branch.sh ALLOW 'main checkout through a symlink, src/deep/: an ordinary commit' \
  'git commit -m "wip"'
check_in "$LIFE_LINK/wt-stale/src/deep" no-work-on-stale-branch.sh BLOCK 'stale worktree through a symlink, src/deep/: a commit is still refused' \
  'git commit -m "wip"'

echo "=== review of #111: the #94 comparison when it has nothing to compare, and its two copies ==="
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
check_in "$NODEV/wt-behind" no-work-on-stale-branch.sh ALLOW 'no origin/dev-* ref, so the fallback abstains' \
  'git commit -m "wip"'
# The gone detector reads the remote's existence, not ancestry against a dev
# branch, so it is not the fallback and does not abstain with it. A branch whose
# remote half has been pruned away is merged whether or not this clone has ever
# seen a dev branch.
check_in "$NODEV/wt-nodev-gone" no-work-on-stale-branch.sh BLOCK 'upstream gone still refuses with no dev ref' \
  'git commit -m "wip"'

echo "--- the two refusals say different things, because they know different things ---"
# `upstream: gone` fires only on the genuinely merged case, so it may say
# merged. The fallback cannot tell a merged branch from one cut before the dev
# branch moved, so it must not.
says "$WT_GONE"  no-work-on-stale-branch.sh 'has been merged' \
  'the gone refusal names the merge' 'git commit -m "wip"'
says "$WT_STALE" no-work-on-stale-branch.sh 'no work of its own' \
  'the fallback refusal is about state' 'git commit -m "wip"'
says_not "$WT_STALE" no-work-on-stale-branch.sh 'merged' \
  'the fallback refusal does not claim a merge' 'git commit -m "wip"'
# The deadlock the carve-out exists to avoid is named in the refusal that would
# otherwise cause it.
says "$WT_STALE" no-work-on-stale-branch.sh 'git merge origin/dev-05 is permitted' \
  'the fallback refusal says how to get out' 'git commit -m "wip"'

# The nolib and halflib checks for this hook, including the scoping that makes a
# healthy worktree ALLOW with no library at all, moved to the load-contract
# section at the foot of this suite. They were the only ones of their kind that
# covered every function a hook requires, and #84's finding was that the lesson
# stayed in this one file: keeping them here, where the three hooks that had it
# wrong have no section, is what let that happen.

echo "=== REGRESSION: #69, a command name matched as a substring ==="
# First coverage of any kind for these two hooks. Neither sourced
# lib/command-scan.sh, so neither knew where a command word was, and the name
# matched as an argument and as prose. Every verdict here was measured on
# dev-05 at 7cb4891, where the six below were BLOCK -- ordinary greps and
# git log invocations, refused for naming the tool they search for.
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

echo "=== the controls those two hooks are for, which keep their verdicts ==="
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

echo "=== #69, what the deleted allowlist covered, asked of the rule that replaced it ==="
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

echo "=== REGRESSION: review of #69, ^ narrowed the guard to one runner ==="
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

echo "=== REGRESSION: review of the #69 PR, the list stopped one family early ==="
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

echo "=== ACCEPTED gap: a wrapper word is not a runner, and belongs in #79 ==="
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

echo "=== REGRESSION: #69, the allowlist was matched against the whole string ==="
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

echo "=== REGRESSION: review of #69, the group was matched after the tool ==="
# `--group test` was looked for anywhere in the fragment, so the tool's own
# argument rescued the command and the comment claiming the group had to be
# named by the runner was false. It is named before the tool now: the fragment
# is cut at the name and only what precedes it is searched. Both were ALLOW.
check pytest-via-uv-group.sh BLOCK 'the group as an argument of pytest' \
  'uv run pytest --group test'
check alembic-via-uv-group.sh BLOCK 'the group as an argument of alembic' \
  'uv run alembic upgrade head --group migrations'

echo "=== REGRESSION: review of #69, the intermittency survived inside the rule ==="
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

echo "=== ACCEPTED gap: #69, these two carry no wrapper rule ==="
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

echo "=== append-only: which docs directories are guarded, and which are not ==="
# First coverage for append-only-docs.sh and its Edit/Write companion. It was
# added with issue #61, which put a comment in both files saying docs/research/
# is deliberately outside the guarded set -- and a comment is not evidence. The
# refusing direction is checked alongside it, because an ALLOW for research/
# that came from the guard having stopped working altogether would look
# identical to the one intended.
check append-only-docs.sh BLOCK 'sed -i over a dev-log entry' \
  "sed -i 's/a/b/' docs/dev-log/devlog_2026-08-25_session-2.md"
check append-only-docs.sh BLOCK 'rm of an eval report' \
  'rm docs/eval-reports/some-report.md'
check append-only-docs.sh BLOCK 'truncating redirect into a lessons-learned entry' \
  'echo x > docs/lessons-learned/some-lesson.md'
check append-only-docs.sh ALLOW 'appending to a dev-log entry' \
  'echo x >> docs/dev-log/devlog_2026-08-25_session-2.md'
check append-only-docs.sh ALLOW 'sed -i over a research document' \
  "sed -i 's/a/b/' docs/research/non-openrouter-response-bodies.md"
check append-only-docs.sh ALLOW 'sed -i over a design document' \
  "sed -i 's/a/b/' docs/design/llm-call-log.md"

echo "=== REGRESSION: #69, the whole-directory case the slash hid ==="
# The pattern required a trailing slash, so the outer guard never fired on the
# directory itself and the removal that destroys the most history was the one
# that passed. Every verdict here was measured on dev-05 at 7cb4891, where the
# first four were ALLOW. The fifth is the control they sit one character away
# from, and it was already BLOCK: same command, opposite verdict, on a
# difference that has nothing to do with what it would run.
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

echo "=== REGRESSION: review of #69, the spellings the Bash side still compared ==="
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

echo "=== REGRESSION: #69, overwriting an entry without naming a redirect ==="
# Both routes overwrite an existing entry in place and neither was reached by
# the rm/mv/cp list or by the redirect rule, so both were ALLOW at 7cb4891.
# The third is the control that was already BLOCK.
check append-only-docs.sh BLOCK 'truncate over a dev-log entry' \
  'truncate -s 0 docs/dev-log/devlog_2026-08-25_session-2.md'
check append-only-docs.sh BLOCK 'tee over a dev-log entry' \
  'tee docs/dev-log/devlog_2026-08-25_session-2.md < new.md'
check append-only-docs.sh BLOCK 'the control it sits beside' \
  ': > docs/dev-log/devlog_2026-08-25_session-2.md'

echo "=== ACCEPTED false positive: #69, tee -a appends and is refused anyway ==="
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
REPO_ROOT=$(cd "$HOOKS/../.." && pwd)
check_file() {  # check_file <script> <want> <label> <path relative to the repo>
  local script="$1" want="$2" label="$3" path="$4" rc err
  err=$(printf '%s' "$path" | jq -Rs '{tool_name:"Edit",tool_input:{file_path:.}}' \
    | CLAUDE_PROJECT_DIR="$REPO_ROOT" ./"$script" 2>&1 >/dev/null)
  rc=$?
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
# The verdict is exact, which check and check_in are not yet (#98): 0 is ALLOW, 2
# is BLOCK, and any other exit is reported as itself and fails. That matters more
# here than anywhere. A hook that dies on malformed input exits 1 or 127, the
# harness treats that as a non-blocking error and runs the command, and a helper
# reading "not 2" as ALLOW would pass it as a permit nobody looks at twice.
feed() {  # feed <PATH> <script|/absolute/hook> <ALLOW|BLOCK> <label> <raw stdin>
  local path="$1" script="$2" want="$3" label="$4" payload="$5" got rc hook
  hook=$(hook_path "$script")
  printf '%s' "$payload" \
    | ( cd "$ON_DEV" && PATH="$path" CLAUDE_PROJECT_DIR="$REPO_ROOT" "$hook" ) >/dev/null 2>&1
  rc=$?
  case $rc in 0) got=ALLOW ;; 2) got=BLOCK ;; *) got="exit-$rc" ;; esac
  if [ "$got" = "$want" ]; then
    printf '  ok   %-5s %s\n' "$got" "$label"
  else
    printf '  FAIL want=%s got=%s  %s\n' "$want" "$got" "$label"
    FAILED=1
  fi
}
feed_says() {  # feed_says <PATH> <script|/absolute/hook> <fragment> <label> <raw stdin>
  local path="$1" script="$2" want="$3" label="$4" payload="$5" err hook
  hook=$(hook_path "$script")
  err=$(printf '%s' "$payload" \
        | ( cd "$ON_DEV" && PATH="$path" CLAUDE_PROJECT_DIR="$REPO_ROOT" "$hook" ) 2>&1 >/dev/null)
  case "$err" in
    *"$want"*) printf '  ok   says  %s\n' "$label" ;;
    *) printf '  FAIL %s\n         wanted the refusal to say |%s|\n         it said |%s|\n' \
         "$label" "$want" "$err"
       FAILED=1 ;;
  esac
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
check_file append-only-docs-edit.sh BLOCK 'Edit of an existing dev-log entry' \
  'docs/dev-log/devlog_2026-08-25_session-2.md'
check_file append-only-docs-edit.sh ALLOW 'Write of a dev-log entry not yet there' \
  'docs/dev-log/devlog_2099-01-01_session-1.md'
check_file append-only-docs-edit.sh ALLOW 'Edit of a dev-log README that does exist' \
  'docs/dev-log/README.md'
check_file append-only-docs-edit.sh ALLOW 'Edit of an existing research document' \
  'docs/research/non-openrouter-response-bodies.md'

echo "=== REGRESSION: #69, a spelling of the path that was not the literal prefix ==="
# The root was stripped by string prefix and the remainder anchored at ^docs/,
# so the comparison was between spellings rather than between paths. The first
# two were ALLOW at 7cb4891, on a file that exists. A leading ./ is not an
# evasion -- it is an ordinary way to write a relative path, which is the shape
# of the ordinary mistake this hook is for. The absolute spelling is the
# control that already worked.
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

echo "=== the arming properties, asserted as literals ==="
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
armed 'the report reads the merge settings rather than trusting a record of them' \
  "$HOOKS/report-stale-branches.sh" "gh api 'repos/{owner}/{repo}'"
armed 'and reads all three the branch lifecycle rule depends on' \
  "$HOOKS/report-stale-branches.sh" \
  '[.allow_squash_merge, .allow_rebase_merge, .delete_branch_on_merge]'
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
SETTINGS="$HOOKS/../settings.json"
tok 'settings.json runs the report at SessionStart' \
    '"$CLAUDE_PROJECT_DIR"/.claude/hooks/report-stale-branches.sh' \
    "$(jq -r '.hooks.SessionStart[]?.hooks[]?.command' "$SETTINGS" 2>/dev/null | grep report-stale-branches)"
tok 'settings.json runs the guard on every Bash command' \
    '"$CLAUDE_PROJECT_DIR"/.claude/hooks/no-work-on-stale-branch.sh' \
    "$(jq -r '.hooks.PreToolUse[]? | select(.matcher == "Bash") | .hooks[]?.command' "$SETTINGS" 2>/dev/null | grep no-work-on-stale-branch)"
# The report's timeout must outlast the network calls it waits on, or the hook
# is killed before it can say that one of them failed -- and a killed
# SessionStart hook takes the whole report with it, not only the line that was
# pending. There are two such calls now, so the claim is no longer about the
# fetch alone, and the budgets are read off the file rather than restated.
#
# 40 rather than the 30 this was: the second call took the margin over the two
# budgets from 15s down to 5s, and what has to happen inside that margin is the
# whole local half of the report -- a worktree listing and an ancestry read per
# branch. Raising the cap costs nothing the budgets do not already cost, because
# it is a cap and not a wait: the hook exits the moment it is done, and the two
# `timeout` calls are what actually bound a dead network.
REPORT_TIMEOUT=$(jq -r '.hooks.SessionStart[]?.hooks[]? | select(.command | contains("report-stale-branches")) | .timeout' "$SETTINGS" 2>/dev/null)
tok 'the report hook outlasts its own network calls' '40' "$REPORT_TIMEOUT"
# Both budgets, summed off the script. The END guard makes a renamed or deleted
# budget print nothing rather than a smaller sum, which is the permitting
# direction: a sum that lost a term would compare favourably and say nothing.
BUDGET_SUM=$(awk -F= '/^FETCH_TIMEOUT=[0-9]+$/ || /^SETTINGS_TIMEOUT=[0-9]+$/ { s += $2; n += 1 }
                      END { if (n == 2) print s }' "$HOOKS/report-stale-branches.sh")
tok 'the report sets two budgets, and this is their sum' '25' "$BUDGET_SUM"
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

echo "=== CLAUDE.md names every hook that carries the boundary ==="
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
    *" $2 "*) printf '  ok   %s\n' "$1" ;;
    *) printf '  FAIL %s\n' "$1"; FAILED=1 ;;
  esac
}

CLAUDE_MD="$HOOKS/../../CLAUDE.md"
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
tok 'the left-open list numbers as many consequences as its head claims' \
    "$CLAIMED" \
    "$(printf '%s\n' "$LEFT_OPEN" | grep -cE '^[0-9]+\. ')"
echo "=== the documents answer the citations the hooks make into them ==="
# A fourth kind of check, and the section above with its direction reversed:
# there settings.json is the fact and CLAUDE.md the claim; here the hooks are
# the fact -- they ship, they run, and their headers send a reader somewhere --
# and the documents are what has to be there when the reader arrives. Issue #70
# found three such citations landing nowhere. Each had shipped; each is read at
# the moment a reader has just been refused something; and none of them was
# wrong in a way this suite could see, because nothing held a hook's pointer to
# the thing it points at.
#
# These are evidence about the three citations named below and nothing else. A
# fourth pointer added to a hook tomorrow is uncounted here, and so is any of
# these three reworded, because every literal is the sentence as written.
#
# CONTEXT.md's entries are extracted rather than grepped whole, for the reason
# the boundary paragraph is narrowed above: a glossary-wide grep is satisfied by
# the word turning up in a neighbouring entry, which is the failure being fixed
# rather than a check on it -- #70's finding was that the lifetime rule was
# written down twice, in neither place a reader looking for vocabulary would go.
# An entry runs from its bolded name to its `_Avoid_:` line, and the extraction
# is checked from both ends before anything is asserted against it -- with one
# limit named, because the two extractions below are not equally evidenced.
# *Reserved act* has an entry after it, so its `unarmed` is real evidence that
# the `_Avoid_:` stop fires. *Worktree branch* is the last entry in the file:
# nothing follows it for an over-run to swallow, so its `unarmed` tests only
# that the extraction did not begin too early, and the `_Avoid_:` stop is
# evidenced there by the other extraction rather than by its own.
CONTEXT_MD="$HOOKS/../../CONTEXT.md"
SKILL_MD="$HOOKS/../skills/branch-hygiene/SKILL.md"
entry() {  # entry <file> <bolded name> -- one glossary entry, name to _Avoid_
  awk -v name="**$2**:" '$0 == name {f=1} f {print} f && /^_Avoid_:/ {exit}' "$1" 2>/dev/null
}

WORKTREE_ENTRY="$FIXTURES/context-worktree-branch.md"
entry "$CONTEXT_MD" 'Worktree branch' > "$WORKTREE_ENTRY"
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
written 'the extracted entry is the reserved act entry' \
  "$RESERVED_ENTRY" '**Reserved act**:'
unarmed 'and it is that entry rather than the whole glossary' \
  "$RESERVED_ENTRY" '**Worktree branch**:'

# report-stale-branches.sh calls removing a worktree "a reserved act in
# CONTEXT.md" in its header, and prints the same claim into every session's
# transcript. The enumeration named four acts and that was not one of them.
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
echo "=== the tokeniser's header names every hook that sources it ==="
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
CS_HEADER=$(awk 'NR == 1 { next } /^#$/ { exit } /^#/ { print; next } { exit }' "$CS_LIB")
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
# This suite reads that path too, to run this audit, and it is not a consumer.
# Named here for the reason NOT_THE_BOUNDARY is named above: the exception is
# the part that would otherwise be discovered rather than read.
CS_SOURCERS=$(printf '%s' " $CS_SOURCERS " | sed 's| check-hooks.sh | |')
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

echo "=== issue #84: every hook refuses when lib/command-scan.sh does not load ==="
# THE LOAD CONTRACT, driven. lib/command-scan.sh states it; the four hooks that
# source that file have to hold it, and before #84 three of them did not --
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
# and the two convention hooks want neither.
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

echo "--- no-git-push.sh, which had no guard at all ---"
# The measured #84 case: with no guard, cs_git_args was undefined, the HAVE_PUSH
# loop found no push, and the hook left without an opinion on a forced push of a
# reserved branch.
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
check_in "$PUSH_WT" "$(halflib_path no-git-push.sh cs_git_args)" BLOCK 'a renamed cs_git_args does not permit a forced push' \
  'git push --force origin dev-05'
says "$PUSH_WT" "$(nolib_path no-git-push.sh)" 'no-git-push.sh could not load' \
  'the refusal names this hook and not one of its three siblings' 'ls'
says "$PUSH_WT" "$(nolib_path no-git-push.sh)" 'Refusing rather than permitting' \
  'and says that it is refusing rather than permitting' 'ls'

echo "--- no-pr-decisions.sh, which had no guard at all ---"
# This file's function set is what makes one shared required list wrong: cs_gh_args
# and cs_join, and no cs_git_args at all. Every rule in it reads its arguments
# through cs_gh_args, so renaming that one permitted `gh pr merge` and
# `gh pr create --base main` together.
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
check_in "$ON_DEV" "$(halflib_path no-pr-decisions.sh cs_gh_args)" BLOCK 'a renamed cs_gh_args does not permit a merge' \
  'gh pr merge 81'
check_in "$ON_DEV" "$(halflib_path no-pr-decisions.sh cs_gh_args)" BLOCK 'nor a pull request based on main' \
  'gh pr create --base main'
# cs_join is read late, by the wrapper rules alone, so a renamed cs_join is
# invisible to every check above it. It is required because the hook calls it and
# not because a rule was seen to break: the contract is the set, not whichever
# subset a driving command happens to reach.
check_in "$ON_DEV" "$(halflib_path no-pr-decisions.sh cs_join)" BLOCK 'a library missing only cs_join' \
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
# The #84 measurement itself, on the fixture that permitted it: a push landing on
# main, from a checkout that is not main, refused by the guard because the refspec
# rule that would otherwise catch it cannot run without the tokeniser.
check_in "$ON_DEV" "$(halflib_path no-commit-to-main.sh cs_git_args)" BLOCK 'a renamed cs_git_args does not permit a push to main' \
  'git push origin HEAD:main'
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
check_in "$WT_STALE" "$(halflib_path no-work-on-stale-branch.sh cs_git_args)" BLOCK 'a library missing only cs_git_args' \
  'git commit -m "wip"'
check_in "$WT_STALE" "$(halflib_path no-work-on-stale-branch.sh cs_normalise)" BLOCK 'a library missing only cs_normalise' \
  'git commit -m "wip"'
check_in "$WT_STALE" "$(halflib_path no-work-on-stale-branch.sh cs_split)" BLOCK 'a library missing only cs_split' \
  'git commit -m "wip"'
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
check_in "$ON_DEV" pytest-via-uv-group.sh ALLOW 'a command naming no runner, library intact' \
  'ls'
check_in "$ON_DEV" "$(nolib_path pytest-via-uv-group.sh)" BLOCK \
  'no lib/, pytest-via-uv-group.sh refuses anything at all' 'ls'
check_in "$ON_DEV" "$(halflib_path pytest-via-uv-group.sh cs_normalise)" BLOCK \
  'a library missing only cs_normalise, pytest-via-uv-group.sh' 'ls'
check_in "$ON_DEV" "$(halflib_path pytest-via-uv-group.sh cs_split)" BLOCK \
  'a library missing only cs_split, pytest-via-uv-group.sh' 'ls'
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
for hook in alembic-via-uv-group.sh no-commit-to-main.sh no-git-push.sh no-pr-decisions.sh pytest-via-uv-group.sh; do
  check_in "$ON_DEV" "$(halflib_path "$hook" cs_tool_input)" BLOCK \
    "a library missing only cs_tool_input, $hook" 'ls'
done
# The two #95 made consumers, whole: they had no library to fail to load before,
# so every check here is new. feed rather than check_in, because the Edit hook
# reads file_path and because the verdict should be exact.
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
# ALL SIX CONSUMERS, not the four boundary hooks, and that is a correction.
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

# The mechanism as text, beside the mechanism as verdicts. `armed`, so a withdrawal
# commented out during a debugging session and left that way does not satisfy it.
armed 'the library withdraws cs_split when the word list is incomplete' \
      lib/command-scan.sh 'unset -f cs_split'
armed 'on either half, and not on the union' \
      lib/command-scan.sh 'if [ -z "$CS_WRAP_OPTION_WORDS" ] || [ -z "$CS_WRAP_OPERAND_WORDS" ]; then'
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
# And that each guard is live code rather than a commented-out line. `armed`
# strips comments first, which is the difference that matters: every literal
# above would match a guard commented out during a debugging session and left
# that way, and review of PR #64 found exactly that shape in this suite. One
# literal per hook per function, because that is the claim being made.
armed 'no-git-push.sh requires cs_normalise' no-git-push.sh 'command -v cs_normalise'
armed 'no-git-push.sh requires cs_split' no-git-push.sh 'command -v cs_split'
armed 'no-git-push.sh requires cs_git_args' no-git-push.sh 'command -v cs_git_args'
armed 'no-pr-decisions.sh requires cs_normalise' no-pr-decisions.sh 'command -v cs_normalise'
armed 'no-pr-decisions.sh requires cs_split' no-pr-decisions.sh 'command -v cs_split'
armed 'no-pr-decisions.sh requires cs_gh_args' no-pr-decisions.sh 'command -v cs_gh_args'
armed 'no-pr-decisions.sh requires cs_join' no-pr-decisions.sh 'command -v cs_join'
armed 'no-commit-to-main.sh requires cs_normalise' no-commit-to-main.sh 'command -v cs_normalise'
armed 'no-commit-to-main.sh requires cs_split' no-commit-to-main.sh 'command -v cs_split'
armed 'no-commit-to-main.sh requires cs_git_args' no-commit-to-main.sh 'command -v cs_git_args'
armed 'no-work-on-stale-branch.sh requires cs_normalise' no-work-on-stale-branch.sh 'command -v cs_normalise'
armed 'no-work-on-stale-branch.sh requires cs_split' no-work-on-stale-branch.sh 'command -v cs_split'
armed 'no-work-on-stale-branch.sh requires cs_git_args' no-work-on-stale-branch.sh 'command -v cs_git_args'
armed 'pytest-via-uv-group.sh requires cs_normalise' pytest-via-uv-group.sh 'command -v cs_normalise'
armed 'pytest-via-uv-group.sh requires cs_split' pytest-via-uv-group.sh 'command -v cs_split'
armed 'alembic-via-uv-group.sh requires cs_normalise' alembic-via-uv-group.sh 'command -v cs_normalise'
armed 'alembic-via-uv-group.sh requires cs_split' alembic-via-uv-group.sh 'command -v cs_split'
for hook in $LIB_CONSUMERS; do
  armed "$hook requires cs_tool_input" "$hook" 'command -v cs_tool_input'
done
# The readability test before the source, which no fixture above can tell apart:
# under bash a `.` of a missing file returns non-zero and carries on, so nolib
# behaves the same with it and without it. It is held as text for that reason,
# and because all four comments claim it.
armed 'no-git-push.sh tests the library before sourcing it' \
      no-git-push.sh '[ -r "$LIB" ] && . "$LIB"'
armed 'no-pr-decisions.sh tests the library before sourcing it' \
      no-pr-decisions.sh '[ -r "$LIB" ] && . "$LIB"'
armed 'no-commit-to-main.sh tests the library before sourcing it' \
      no-commit-to-main.sh '[ -r "$LIB" ] && . "$LIB"'
armed 'no-work-on-stale-branch.sh tests the library before sourcing it' \
      no-work-on-stale-branch.sh '[ -r "$LIB" ] && . "$LIB"'
armed 'pytest-via-uv-group.sh tests the library before sourcing it' \
      pytest-via-uv-group.sh '[ -r "$LIB" ] && . "$LIB"'
armed 'alembic-via-uv-group.sh tests the library before sourcing it' \
      alembic-via-uv-group.sh '[ -r "$LIB" ] && . "$LIB"'
armed 'append-only-docs.sh tests the library before sourcing it' \
      append-only-docs.sh '[ -r "$LIB" ] && . "$LIB"'
armed 'append-only-docs-edit.sh tests the library before sourcing it' \
      append-only-docs-edit.sh '[ -r "$LIB" ] && . "$LIB"'
echo "--- the required list is the call list, and these are all the consumers ---"
# THE ONE CHECK HERE THAT SURVIVES THE NEXT CHANGE. Every literal above names a
# file and a function, so all of them together say that these four guards require
# these thirteen names -- and none of them says a required list is COMPLETE. #84 was
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
for hook in $LIB_CONSUMERS; do
  CALLS=$(cs_calls "$hook")
  REQUIRED=$(cs_required "$hook")
  # An empty derivation would make the comparison pass by matching nothing, which
  # is the permitting direction: a hook whose calls could not be read would report
  # as agreeing with a guard that requires nothing.
  if [ -z "$CALLS" ] || [ -z "$REQUIRED" ]; then
    printf '  FAIL %s: no cs_* calls or no required names were read out of the file at all\n' "$hook"
    FAILED=1
  elif [ "$CALLS" = "$REQUIRED" ]; then
    printf '  ok   derived %s requires exactly what it calls: %s\n' "$hook" "${CALLS% }"
  else
    printf '  FAIL %s requires a set other than the one it calls\n         calls:    |%s|\n         requires: |%s|\n' \
      "$hook" "$CALLS" "$REQUIRED"
    FAILED=1
  fi
done
# And that LIB_CONSUMERS is all of them -- a file that sources the library and
# guards nothing is #84 again, and nothing above would see it, because every
# literal above names a file.
#
# $CS_SOURCERS is the #69 audit's derivation, a few checks up: every .sh beside
# this suite whose code (comments stripped) loads the tokeniser, with this suite
# itself excluded by name. It is reused rather than re-derived, because a second
# answer to "who sources this file" is the defect both of these sections are
# about. #69 asserts the tokeniser's header against it; #84 asserts the list of
# hooks whose load guard is driven above. Its spacing is its own -- leading and
# trailing -- so this normalises rather than assuming.
SOURCERS=$(printf '%s\n' $CS_SOURCERS | sort | tr '\n' ' ')
CLAIMED=$(printf '%s\n' $LIB_CONSUMERS | sort | tr '\n' ' ')
if [ -n "$SOURCERS" ] && [ "$SOURCERS" = "$CLAIMED" ]; then
  printf '  ok   derived the files that load the library are exactly the ones checked here: %s\n' "${SOURCERS% }"
else
  printf '  FAIL the files that load the library are not the four this section checks\n         load it: |%s|\n         checked: |%s|\n' \
    "$SOURCERS" "$CLAIMED"
  FAILED=1
fi
# One property of this suite's own helpers, because nothing else here drives them
# and `unarmed` reporting ok for a file it never read would make four pins below
# vacuous. Run in a subshell so its FAILED cannot reach ours.
if ( FAILED=0; unarmed 'self-check' "$FIXTURES/no-such-file" 'anything'; exit $FAILED ) >/dev/null 2>&1
then
  printf '  FAIL unarmed reports ok for a file that is not there, so every pin below is vacuous\n'
  FAILED=1
else
  printf '  ok   unarmed fails for a file that is not there, so the pins below are about a file that was read\n'
fi

# The refusing direction: a hook back to sourcing the library with nothing around
# it is the #84 shape exactly, and it would satisfy every `written` above. Asked
# of all four and not only of the two that had it, because a regression is not
# more likely in the files that carried the defect -- these four are edited
# together and the shape is one line long.
unarmed 'no-git-push.sh does not source the library unguarded' \
        no-git-push.sh '. "$(dirname "$0")/lib/command-scan.sh"'
unarmed 'no-pr-decisions.sh does not source the library unguarded' \
        no-pr-decisions.sh '. "$(dirname "$0")/lib/command-scan.sh"'
unarmed 'no-commit-to-main.sh does not source the library unguarded' \
        no-commit-to-main.sh '. "$(dirname "$0")/lib/command-scan.sh"'
unarmed 'no-work-on-stale-branch.sh does not source the library unguarded' \
        no-work-on-stale-branch.sh '. "$(dirname "$0")/lib/command-scan.sh"'
unarmed 'pytest-via-uv-group.sh does not source the library unguarded' \
        pytest-via-uv-group.sh '. "$(dirname "$0")/lib/command-scan.sh"'
unarmed 'alembic-via-uv-group.sh does not source the library unguarded' \
        alembic-via-uv-group.sh '. "$(dirname "$0")/lib/command-scan.sh"'
unarmed 'append-only-docs.sh does not source the library unguarded' \
        append-only-docs.sh '. "$(dirname "$0")/lib/command-scan.sh"'
unarmed 'append-only-docs-edit.sh does not source the library unguarded' \
        append-only-docs-edit.sh '. "$(dirname "$0")/lib/command-scan.sh"'

echo "=== issue #95: every hook refuses when it cannot read its input ==="
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
# symlinks to every executable on this suite's own PATH, and a copy of it with jq
# removed. Every tool, not the ones a hook is known to call today -- a list of
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
for pair in "Bash:$INPUT_BASH_HOOKS" "Edit:$INPUT_EDIT_HOOKS" "Write:$INPUT_EDIT_HOOKS"; do
  tool=${pair%%:*}
  REGISTERED=$(registered_for "$tool")
  CLAIMED=$(printf '%s\n' ${pair#*:} | sort -u | tr '\n' ' ')
  # Empty is the permitting direction: a settings.json that could not be read
  # would agree with an empty list.
  if [ -n "$REGISTERED" ] && [ "$REGISTERED" = "$CLAIMED" ]; then
    printf '  ok   derived the hooks registered for %s are exactly the ones checked here: %s\n' "$tool" "${REGISTERED% }"
  else
    printf '  FAIL the hooks registered for %s are not the ones this section checks\n         registered: |%s|\n         checked:    |%s|\n' \
      "$tool" "$REGISTERED" "$CLAIMED"
    FAILED=1
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
    printf '  FAIL %s still calls jq itself rather than the shared reader\n' "$hook"
    FAILED=1
  else
    printf '  ok   derived %s does not call jq itself\n' "$hook"
  fi
done
# And the reader is the library's, in live code. `armed` strips comments, so a
# reader commented out would not satisfy it; the behavioural checks above would
# go red too, but this one names where.
armed 'the library defines the shared reader' lib/command-scan.sh 'cs_tool_input() {'
# #95's acceptance: the fail direction for each condition stated in one place.
# `written`, because it is prose.
written 'the library states the fail direction of the input read' \
  "$HOOKS/lib/command-scan.sh" 'THE INPUT READ'
written 'and records the trade an environment without jq pays' \
  "$HOOKS/lib/command-scan.sh" 'THE TRADE, taken knowingly'

echo "=== the exit-status helpers themselves: #98 ==="
# The rule, and what it replaced, is written above `verdict`. Nothing else in this
# suite drives a helper with a hook that crashes, so these ask the helpers
# directly, in the manner of the `unarmed` self-test above: the helper runs in a
# subshell with its own FAILED, and what is asserted is the FAILED it leaves --
# the helper's result, not the fixture's exit status. The crash-1 fixture gets its
# 1 from `set -e`, which no hook uses; it stands for any exit that is neither 0
# nor 2, and 1 is the one the old reading and the new disagree about.
#
# Each fixture leaves a marker before it exits, and the marker is asserted too.
# `check` and `check_file` run `./<script>` from the working directory, so a
# fixture the helper could not find would exit 127 on its own account and a
# crash-1 case would FAIL for that reason rather than the one it names.
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
chmod +x "$EXITS"/*.sh
for f in allow-0 block-2 crash-1 crash-127; do
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
# FAILED it left. The call shapes differ because the helpers take their hook
# differently: check and check_file by a name run from the working directory, the
# rest by an absolute path. `says` and `says_not` take a fragment where the others
# take a verdict: the fixture's own name, which is in everything a fixture says, so
# `says` has something to find and `says_not` is given something it never sees.
drive_helper() {  # drive_helper <helper> <fixture> <want>
  local helper="$1" fixture="$2" want="$3" result
  rm -f "$EXITS/ran-$fixture"
  if ( FAILED=0
       cd "$EXITS" || exit 3
       case "$helper" in
         check)      check "$fixture.sh" "$want" 'self-test' 'true' ;;
         check_in)   check_in "$EXITS" "$EXITS/$fixture.sh" "$want" 'self-test' 'true' ;;
         flip)       flip "$EXITS" "$EXITS/$fixture.sh" ALLOW "$want" 'self-test' 'true' ;;
         check_file) check_file "$fixture.sh" "$want" 'self-test' 'docs/x.md' ;;
         says)       says "$EXITS" "$EXITS/$fixture.sh" "$fixture" 'self-test' 'true' ;;
         says_not)   says_not "$EXITS" "$EXITS/$fixture.sh" 'never-said' 'self-test' 'true' ;;
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
    printf '  ok   %s\n' "$1"
  else
    printf '  FAIL %s\n         wanted exit=%s and |stderr |%s| on the failure line\n         it said |%s|\n' \
      "$1" "$2" "$3" "$(cat "$EXITS_OUTPUT")"
    FAILED=1
  fi
}

# The helpers this self-test drives, named once: each loop below runs off its list,
# and the derivation at the end of this section is asserted against both. A
# helper added to neither is red there; one added to a list is driven.
DRIVEN_VERDICT='check check_in flip check_file'
DRIVEN_MESSAGE='says says_not'

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

# The message helpers. A refusal is the only thing either can pass on, so the
# passing case is exit 2 alone.
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

# And that the helpers driven above are all of them. The helpers that read a hook's
# exit status are derived from this file, and each must be in one of the two lists
# the loops above run off -- so a new reader is either driven or red here. `flip`
# reads no status of its own -- it hands its verdict to check_in -- so it is driven
# because #98 names it, and is not in the derived set.
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
STATUS_READERS=$(sed 's/[[:space:]]*#.*$//' "$HOOKS/check-hooks.sh" \
  | awk '/^function[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/ || /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)/ {
           fn = $0; sub(/^function[[:space:]]+/, "", fn); sub(/[[:space:](){].*/, "", fn)
         }
         /^\}/                 { fn = "" }
         fn != "" && /rc=\$\?/ { print fn }' \
  | sort -u | tr '\n' ' ')
# An empty derivation would make every membership below pass by asking nothing.
if [ -z "$STATUS_READERS" ]; then
  printf '  FAIL no helper that reads a hook exit status was derived from this file at all\n'
  FAILED=1
fi
for reader in $STATUS_READERS; do
  present "derived $reader reads a hook exit status, and the #98 self-test drives it" \
          "$reader" "$DRIVEN_VERDICT $DRIVEN_MESSAGE"
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
VOCAB_EXEMPT_FILE=no-work-on-stale-branch.sh
VOCAB_EXEMPT='# the probe->check rename was committed onto hooks-push-and-pr-guards after'
for f in lib/command-scan.sh $LIB_CONSUMERS; do
  EXEMPT=
  [ "$f" = "$VOCAB_EXEMPT_FILE" ] && EXEMPT=$VOCAB_EXEMPT
  if [ ! -r "$HOOKS/$f" ] || [ -d "$HOOKS/$f" ]; then
    printf '  FAIL %s cannot be read, so the absence of "probe" in it is evidence of nothing\n' "$f"
    FAILED=1
    continue
  fi
  if ! HITS=$(awk -v ex="$EXEMPT" \
      'tolower($0) ~ /prob(e|ing)/ && !(ex != "" && $0 == ex) { print FNR ": " $0 }' \
      "$HOOKS/$f" 2>/dev/null); then
    printf '  FAIL %s could not be scanned, so the absence of "probe" in it is evidence of nothing\n' "$f"
    FAILED=1
  elif [ -z "$HITS" ]; then
    printf '  ok   written %s says a guard requires a function\n' "$f"
  else
    printf '  FAIL %s uses "probe", which CONTEXT.md keeps for a measurement:\n%s\n' \
      "$f" "$(printf '%s\n' "$HITS" | sed 's/^/         /')"
    FAILED=1
  fi
done

echo
if [ $FAILED -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
exit $FAILED

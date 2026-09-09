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
# So the number below is not a measure of the boundary. A check suite is
# evidence about the cases it names and about nothing else, and every case here
# was named by someone who went looking for one it had missed.
#
# One expectation is not a literal but a context: whether pushing this branch is
# permitted depends on where the suite runs, because that is exactly what
# no-git-push.sh decides. Run from a linked worktree on a worktree branch, a push
# of that branch is ALLOW; run from the main checkout, the identical command is
# BLOCK. OWN_BRANCH_PUSH holds whichever applies, and the banner says which.
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
# invariants, eighteen flips, two that the file fails closed without its
# library, and four that name which refusal fired.
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
# Run: bash .claude/hooks/check-hooks.sh
cd "$(dirname "$0")" || exit 1
HOOKS=$(pwd)

CURRENT=$(git branch --show-current 2>/dev/null)
GIT_DIR_PATH=$(git rev-parse --git-dir 2>/dev/null)
GIT_COMMON_PATH=$(git rev-parse --git-common-dir 2>/dev/null)

if [ -n "$GIT_DIR_PATH" ] && [ "$GIT_DIR_PATH" != "$GIT_COMMON_PATH" ] \
   && [ -n "$CURRENT" ] && [ "$CURRENT" != "main" ] \
   && ! echo "$CURRENT" | grep -qE '^dev-[0-9]+$'; then
  OWN_BRANCH_PUSH=ALLOW
  CONTEXT="linked worktree on $CURRENT -- a push of this branch is permitted"
else
  OWN_BRANCH_PUSH=BLOCK
  CONTEXT="main checkout or a reserved branch (${CURRENT:-none}) -- every push is refused"
fi
echo "context: $CONTEXT"
echo

FAILED=0
check() {
  local script="$1" want="$2" label="$3" cmd="$4" got rc
  printf '%s' "$cmd" | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' | ./"$script" >/dev/null 2>&1
  rc=$?
  if [ $rc -eq 2 ]; then got=BLOCK; else got=ALLOW; fi
  if [ "$got" = "$want" ]; then
    printf '  ok   %-5s %s\n' "$got" "$label"
  else
    printf '  FAIL want=%s got=%s  %s\n' "$want" "$got" "$label"
    FAILED=1
  fi
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
# An unmade fixture would make ( cd "$dir" && hook ) return 1, which reads as
# ALLOW -- so every ALLOW-expecting check below would pass without running the
# hook at all. `git init -b` needs git 2.28.
[ -d "$ON_MAIN/.git" ] && [ -d "$ON_DEV/.git" ] || {
  echo "fixtures were not created; git init -b needs git 2.28 or newer" >&2
  exit 1
}
# A copy of each hook with no lib/ beside it, to ask what one does when the
# tokeniser it now depends on is not there.
mkdir -p "$FIXTURES/nolib"
cp no-commit-to-main.sh "$FIXTURES/nolib/"

# check, with the hook's working directory named rather than inherited. The
# hook is invoked by absolute path because it sources lib/ relative to $0.
check_in() {  # check_in <dir> <script|/absolute/hook> <want> <label> <cmd>
  local dir="$1" script="$2" want="$3" label="$4" cmd="$5" got rc hook
  case "$script" in /*) hook="$script" ;; *) hook="$HOOKS/$script" ;; esac
  printf '%s' "$cmd" | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' \
    | ( cd "$dir" && "$hook" ) >/dev/null 2>&1
  rc=$?
  if [ $rc -eq 2 ]; then got=BLOCK; else got=ALLOW; fi
  if [ "$got" = "$want" ]; then
    printf '  ok   %-5s %s\n' "$got" "$label"
  else
    printf '  FAIL want=%s got=%s  %s\n' "$want" "$got" "$label"
    FAILED=1
  fi
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
says() {  # says <dir> <script> <fragment> <label> <cmd>
  local dir="$1" script="$2" want="$3" label="$4" cmd="$5" err
  err=$(printf '%s' "$cmd" | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' \
        | ( cd "$dir" && "$HOOKS/$script" ) 2>&1 >/dev/null)
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
says_not() {  # says_not <dir> <script> <fragment> <label> <cmd>
  local dir="$1" script="$2" unwanted="$3" label="$4" cmd="$5" err
  err=$(printf '%s' "$cmd" | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' \
        | ( cd "$dir" && "$HOOKS/$script" ) 2>&1 >/dev/null)
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
armed() {  # armed <label> <file> <literal>
  if grep -qF -- "$3" "$2" 2>/dev/null; then
    printf '  ok   armed %s\n' "$1"
  else
    printf '  FAIL %s\n         expected %s to contain |%s|\n' "$1" "$2" "$3"
    FAILED=1
  fi
}

unarmed() {  # unarmed <label> <file> <literal>
  if grep -qF -- "$3" "$2" 2>/dev/null; then
    printf '  FAIL %s\n         %s must not contain |%s|\n' "$1" "$2" "$3"
    FAILED=1
  else
    printf '  ok   armed %s\n' "$1"
  fi
}

. ./lib/command-scan.sh

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
tok 'heredoc body dropped' \
    'cat > f <<EOF
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
tok 'control word removed, then/fi' \
    'true
git push --mirror origin' \
    "$(printf 'if true; then git push --mirror origin; fi\n' | cs_split)"
tok 'control word removed, brace group' \
    'git push --mirror origin' \
    "$(printf '{ git push --mirror origin; }\n' | cs_split)"
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
check no-git-push.sh BLOCK 'legit push ; push origin main'  "git push origin $CURRENT; git push origin main"
check no-git-push.sh BLOCK 'legit push && push --all'       "git push origin $CURRENT && git push --all origin"
check no-git-push.sh BLOCK 'bare push && forced push'       "git push && git push --force origin $CURRENT"
check no-git-push.sh BLOCK 'three pushes, last one bad'     "git push; git push origin $CURRENT; git push --mirror origin"
check no-pr-decisions.sh BLOCK 'gh pr view ; gh pr merge'   'gh pr view 5; gh pr merge 5'

echo "=== REGRESSION: PR #35, backticks and command prefixes ==="
# $( ) was closed by the paren in the separator class and its twin was not --
# the same asymmetry GIT_DIR= had against --git-dir. Both hooks were open.
check no-git-push.sh     BLOCK 'backticked push'      'echo `git push --mirror origin`'
check no-git-push.sh     BLOCK 'dollar-paren push'    'echo $(git push --mirror origin)'
check no-pr-decisions.sh BLOCK 'backticked merge'     'echo `gh pr merge 35`'
check no-pr-decisions.sh BLOCK 'dollar-paren merge'   'echo $(gh pr merge 35)'
check no-git-push.sh     BLOCK 'push through xargs'   'echo origin | xargs git push --mirror'
check no-pr-decisions.sh BLOCK 'merge through xargs'  'echo 35 | xargs gh pr merge'

echo "=== REGRESSION: heredoc prose that blocked its own commit ==="
COMMIT_MSG=$'git commit -q -F - <<\'EOF\'\nLeave pushing and deciding a PR to Bertan\n\nno-git-push.sh refuses every push; no-pr-decisions.sh refuses\ngh pr review --approve and --request-changes, gh pr close and reopen.\ngit push origin main is refused in every form.\ngh pr merge 5 would also be refused.\nEOF'
check no-git-push.sh     ALLOW 'commit msg naming git push in heredoc' "$COMMIT_MSG"
check no-pr-decisions.sh ALLOW 'commit msg naming gh pr verbs in heredoc' "$COMMIT_MSG"
NOTE=$'cat > /tmp/note.md <<\'MD\'\ngh pr merge is now refused by a hook.\ngit push origin main likewise.\nMD'
check no-git-push.sh     ALLOW 'heredoc body naming git push' "$NOTE"
check no-pr-decisions.sh ALLOW 'heredoc body naming gh pr merge' "$NOTE"

echo "=== REGRESSION: PR #35, indentation defeated the anchor ==="
# Each names a refused destination, so these assert that the command is still
# *found* when indented, independently of the worktree exception.
check no-git-push.sh     BLOCK 'if/then + indented push to dev-05' $'if true; then\n    git push origin dev-05\nfi'
check no-git-push.sh     BLOCK 'for loop + indented push to main'  $'for r in a b; do\n  git push origin main\ndone'
check no-git-push.sh     BLOCK 'deeply indented push to main'      $'if true; then\n  if true; then\n        git push origin main\n  fi\nfi'
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
check no-git-push.sh     BLOCK 'multi-line -b string continuing with a push' $'gh issue comment 27 -b "to release:\n  git push origin main"'
check no-pr-decisions.sh BLOCK 'multi-line -b string continuing with a merge' $'gh issue comment 27 -b "to land it:\n  gh pr merge 35"'
# And the price of removing control words: a quoted string holding a separator
# and then one of them reads as a command. Same trade, same reason.
check no-git-push.sh     BLOCK 'quoted "; then" before a push'  'git commit -m "wait; then git push --all origin"'
check no-pr-decisions.sh BLOCK 'quoted "; then" before a merge' 'git commit -m "wait; then gh pr merge 35"'

echo "=== REGRESSION: PR #35 review, a command after a control word ==="
# A separator is not the only thing a command can follow. Splitting on ; left
# `then` in front of the command word, so the anchor never saw the command at
# all, and `do`, `else`, `elif`, `{` and `!` did the same. Every check here was
# ALLOW before the control words were removed in cs_split.
check no-git-push.sh     BLOCK 'then + push --mirror'     'if true; then git push --mirror origin; fi'
check no-git-push.sh     BLOCK 'do + push --all'          'while true; do git push --all origin; done'
check no-git-push.sh     BLOCK 'brace group + push'       '{ git push --mirror origin; }'
check no-git-push.sh     BLOCK 'then + push to dev-05'    'if true; then git push origin dev-05; fi'
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
check no-git-push.sh     BLOCK 'here-string then a push'   $'cat <<< "hello"\ngit push --mirror origin'
check no-pr-decisions.sh BLOCK '<<- tab terminator, then a merge' $'cat <<-EOF\n\thello\n\tEOF\ngh pr merge 35'
check no-git-push.sh     BLOCK '<<- tab terminator, then a push'  $'cat <<-EOF\n\thello\n\tEOF\ngit push --mirror origin'
# The body of a real heredoc is still data, tab-indented or not.
check no-pr-decisions.sh ALLOW '<<- body naming a merge'   $'cat <<-EOF\n\tgh pr merge 35 would be refused\n\tEOF\necho done'
check no-git-push.sh     ALLOW '<<- body naming a push'    $'cat <<-EOF\n\tgit push --all origin is refused\n\tEOF\necho done'

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
check no-git-push.sh     BLOCK 'commit msg naming <<EOF, then --all'    $'git commit -m "hooks: fix <<EOF handling in cs_normalise"\n    git push --all origin'
check no-pr-decisions.sh BLOCK 'pr comment naming <<, then a merge'     $'gh pr comment 35 -b "the << operator confused it"\n    gh pr merge 35'
check no-git-push.sh     BLOCK 'left shift << in a message, then --all' $'git commit -m "left shift << done"\n    git push --all origin'
check no-git-push.sh     BLOCK 'issue comment naming <<, then --mirror' $'gh issue comment 1 -b "see << notes"\n    git push --mirror origin'
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

echo "=== the push argument split does not glob against the worktree ==="
# `for TOK in $ARGS` is unquoted because the split is the point; set -f stops
# the same line expanding ? and [...] against the files sitting next to it.
check no-git-push.sh BLOCK 'a ? wildcard refspec'     'git push origin ?'
check no-git-push.sh BLOCK 'a [...] wildcard refspec' 'git push origin [a-z]*'

echo "=== worktree exception: pushing this worktree's own branch ==="
# Every permitted push names the branch. That is the whole exception: a push
# that does not name it is answered by configuration instead, and configuration
# is not a thing this hook can hold still. See the bare-push section below.
check no-git-push.sh "$OWN_BRANCH_PUSH" 'push naming this branch'          "git push origin $CURRENT"
check no-git-push.sh "$OWN_BRANCH_PUSH" 'push after a commit'              "git commit -m msg && git push origin $CURRENT"
check no-git-push.sh "$OWN_BRANCH_PUSH" 'push in a subshell'               "(git push origin $CURRENT)"
check no-git-push.sh "$OWN_BRANCH_PUSH" 'push with a trailing ;'           "git push origin $CURRENT;"
check no-git-push.sh "$OWN_BRANCH_PUSH" 'git push -u origin <this branch>' "git push -u origin $CURRENT"
check no-git-push.sh "$OWN_BRANCH_PUSH" 'indented push, own branch'        $'if true; then\n    git push origin '"$CURRENT"$'\nfi'
# An unrelated -f elsewhere on the line is not the push's own flag. Every option
# check reads the push's arguments, not the whole command, so this still passes.
check no-git-push.sh "$OWN_BRANCH_PUSH" 'rm -f before an ordinary push'    "rm -f notes.md && git push origin $CURRENT"

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
check no-git-push.sh BLOCK 'bare git push'                     'git push'
check no-git-push.sh BLOCK 'push naming only the remote'       'git push origin'
check no-git-push.sh BLOCK 'bare push after a commit'          'git commit -m msg && git push'
check no-git-push.sh BLOCK 'bare push in a subshell'           '(git push)'
check no-git-push.sh BLOCK 'push.default set for this command' 'git -c push.default=matching push'
check no-git-push.sh BLOCK 'push.default=upstream for one'     'git -c push.default=upstream push origin'
check no-git-push.sh BLOCK 'config set by --config-env'        'git --config-env=push.default=PD push'
# -c is refused even alongside a refspec that does name this branch: the hook
# cannot know which setting the override was for.
check no-git-push.sh BLOCK '-c with an explicit refspec'       "git -c http.sslVerify=false push origin $CURRENT"

echo "=== forced pushes, refused in every spelling ==="
# Forcing rewrites what the remote already has, which for this branch is the
# history an open pull request is showing. --force-with-lease is refused with
# the rest: it guards against clobbering another person's work, not against
# rewriting a PR under its reviewer.
check no-git-push.sh BLOCK 'git push -f'                   'git push -f'
check no-git-push.sh BLOCK 'git push --force'              'git push --force'
check no-git-push.sh BLOCK 'git push --force-with-lease'   'git push --force-with-lease'
check no-git-push.sh BLOCK 'lease with a value'            "git push --force-with-lease=$CURRENT origin"
check no-git-push.sh BLOCK 'git push --force-if-includes'  'git push --force-if-includes origin'
check no-git-push.sh BLOCK 'bundled short flags -fu'       "git push -fu origin $CURRENT"
check no-git-push.sh BLOCK 'forced by leading + on refspec' "git push origin +$CURRENT"
check no-git-push.sh BLOCK 'forced push of own branch'     "git push -f origin $CURRENT"

echo "=== worktree exception does not extend to ==="
check no-git-push.sh BLOCK 'another branch by name: main'      'git push origin main'
check no-git-push.sh BLOCK 'another branch by name: dev-05'    'git push origin dev-05'
check no-git-push.sh BLOCK 'a refspec destination: HEAD:main'  'git push origin HEAD:main'
check no-git-push.sh BLOCK 'a forced push to dev-05'           'git push -f origin dev-05'
check no-git-push.sh BLOCK 'a cd before the push'              'cd /tmp && git push'
check no-git-push.sh BLOCK 'a cd before the push, with ;'      'cd /tmp; git push'
check no-git-push.sh BLOCK 'git redirected with -C'            'git -C /home/bgunyel/source/ai/clause-and-effect push'
check no-git-push.sh BLOCK 'git redirected with --git-dir'     'git --git-dir=/elsewhere/.git push'
check no-git-push.sh BLOCK 'a push inside sh -c'               'sh -c "git push"'
check no-git-push.sh BLOCK 'a push inside bash -c'             'bash -c "git push origin dev-05"'
check no-git-push.sh BLOCK 'a push inside eval'                'eval "git push"'
check no-git-push.sh BLOCK 'a push inside a heredoc fed to sh' $'bash <<\'EOF\'\ngit push\nEOF'

echo "=== REGRESSION: PR #35, a denylist could not see a push naming no branch ==="
# The check refused branches by name, so any spelling that named none was
# invisible: --all advanced main and dev-05 from any worktree, and --mirror
# deleted every remote branch absent locally, closing open pull requests. The
# check is now an allowlist -- the push must positively name this branch.
check no-git-push.sh BLOCK 'git push --all origin'      'git push --all origin'
check no-git-push.sh BLOCK 'git push --mirror origin'   'git push --mirror origin'
check no-git-push.sh BLOCK 'git push --prune origin'    'git push --prune origin'
check no-git-push.sh BLOCK 'git push origin --tags'     'git push origin --tags'
check no-git-push.sh BLOCK 'git push --follow-tags'     'git push --follow-tags origin'
check no-git-push.sh BLOCK 'wildcard refspec, forced'   'git push origin +refs/heads/*:refs/heads/*'
check no-git-push.sh BLOCK 'deleting a remote branch'   "git push origin --delete $CURRENT"
check no-git-push.sh BLOCK 'deleting by empty source'   'git push origin :main'

echo "=== REGRESSION: PR #35, redirects and cd forms the rules did not reach ==="
# An environment assignment precedes the command, so git was not at a command
# position and the push was never even detected; the anchors now allow a VAR=
# prefix. pushd changes directory exactly as cd does.
check no-git-push.sh     BLOCK 'GIT_DIR= prefix'     'GIT_DIR=/other/.git git push origin main'
check no-git-push.sh     BLOCK 'GIT_WORK_TREE= prefix' 'GIT_WORK_TREE=/other git push'
check no-git-push.sh     BLOCK 'pushd before a push'  'pushd /some/repo && git push'
check no-pr-decisions.sh BLOCK 'env prefix before gh' 'FOO=1 gh pr merge 35'

echo "=== the allowlist still admits an ordinary push of this branch ==="
check no-git-push.sh "$OWN_BRANCH_PUSH" 'git push origin HEAD'           "git push origin HEAD"
check no-git-push.sh "$OWN_BRANCH_PUSH" 'git push origin HEAD:<branch>'  "git push origin HEAD:$CURRENT"
check no-git-push.sh "$OWN_BRANCH_PUSH" 'git push origin <b>:<b>'        "git push origin $CURRENT:$CURRENT"
check no-git-push.sh "$OWN_BRANCH_PUSH" 'push option with a value'       "git push -o ci.skip origin $CURRENT"

echo "=== REGRESSION: PR #35, a line continuation emptied the argument scope ==="
# The scope ran from push to the next shell separator; a newline ended it, and
# an empty scope fell through to the bare-push case, the permitted one. So one
# wrapped line turned any push into an ordinary one -- --mirror included, which
# deletes remote branches and closes open PRs. Continuations are now joined
# before anything is matched.
check no-git-push.sh BLOCK 'continued --mirror'  $'git push \\\n  --mirror origin'
check no-git-push.sh BLOCK 'continued --all'     $'git push \\\n  --all origin'
check no-git-push.sh BLOCK 'continued force'     $'git push \\\n  --force-with-lease origin main'
check no-git-push.sh BLOCK 'continued origin main' $'git push \\\n  origin main'
check no-git-push.sh BLOCK 'continuation over three lines' $'git push \\\n  --all \\\n  origin'
# A trailing backslash with nothing after it is not a continuation of anything.
# The command is a bare push, which used to be the permitted shape and is now
# refused for naming no destination -- the join still has to consume the
# backslash, or this would be refused for being unreadable instead.
check no-git-push.sh BLOCK 'trailing backslash, nothing after' $'git push \\'
check no-git-push.sh "$OWN_BRANCH_PUSH" 'continued push of this branch'     $'git push \\\n  origin '"$CURRENT"

echo "=== the remote must be a remote of this repository ==="
# Nothing required the first bare token to be a remote, so a URL or a typo was
# admitted whenever the refspec named this branch. Raised on PR #35.
check no-git-push.sh BLOCK 'a foreign remote URL'    'git push git@github.com:someone/else.git HEAD'
check no-git-push.sh BLOCK 'an undefined remote name' 'git push upstream HEAD'
check no-git-push.sh "$OWN_BRANCH_PUSH" 'origin is a real remote' "git push origin $CURRENT"

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
do check no-git-push.sh ALLOW "$c" "$c"; done

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
for c in 'gh pr create --title x --body y' \
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
check no-git-push.sh     BLOCK 'timeout before a wholesale push' 'timeout 5 git push --all origin'
check no-git-push.sh     BLOCK 'sudo before a mirror push'       'sudo git push --mirror origin'
check no-git-push.sh     BLOCK 'separated --git-dir before a push' 'git --git-dir /tmp/other/.git push --all origin'
check no-pr-decisions.sh BLOCK 'setsid before a merge'           'setsid gh pr merge 5'
check no-pr-decisions.sh BLOCK 'sudo before a merge'             'sudo gh pr merge 5'
# The operand strip takes one token and only if it is not an option, so an
# ordinary command that begins with one of these words is still itself.
check no-git-push.sh     ALLOW 'timeout in front of something else' 'timeout 5 make test'
check no-git-push.sh     ALLOW 'sudo in front of something else'    'sudo apt-get install jq'

# Found by reviewing PR #49, and the same defect one turn further on. Stripping
# a wrapper word and its options leaves the value of any option that took one
# where the command word has to be, so the operand rule above closes `timeout
# 30` and not `timeout -s KILL 30`, and closes nothing at all for the wrapper
# words that have no operand rule. cs_split offers the tail as further
# candidates rather than keeping a third list of which options take a value.
check no-git-push.sh BLOCK 'sudo with a separated option value'   'sudo -u root git push --all origin'
check no-git-push.sh BLOCK 'nice with a separated niceness'       'nice -n 10 git push --all origin'
check no-git-push.sh BLOCK 'ionice with a separated class'        'ionice -c 2 git push --all origin'
check no-git-push.sh BLOCK 'timeout whose signal took the operand' 'timeout -s KILL 30 git push --all origin'
check no-git-push.sh BLOCK 'xargs with a separated count'         'xargs -n 1 git push --all origin'
check no-git-push.sh BLOCK 'env with a separated directory'       'env -C /tmp git push --all origin'
check no-pr-decisions.sh BLOCK 'sudo with a separated option value, before a merge' \
  'sudo -u root gh pr merge 5'
# The tail only ever adds candidates, so an ordinary command that begins with a
# wrapper word still yields itself and the additions refuse nothing.
check no-git-push.sh ALLOW 'a wrapper option value in front of something else' \
  'sudo -u root apt-get install jq'
check no-git-push.sh ALLOW 'a commit whose message quotes a push, behind a wrapper' \
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

echo "=== the hooks fail closed when the tokeniser is not beside them ==="
# All three hooks now rest on lib/command-scan.sh, and this one is kept in the
# tree precisely because it still stands when the broader hook is disabled. An
# unreadable library left cs_split undefined, the command list empty and every
# commit on main permitted -- a single point of failure that failed open.
check_in "$ON_MAIN" "$FIXTURES/nolib/no-commit-to-main.sh" BLOCK 'no lib/, commit on main' \
  'git commit -m "wip"'
check_in "$ON_DEV"  "$FIXTURES/nolib/no-commit-to-main.sh" BLOCK 'no lib/, anything at all' \
  'ls'

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

[ -d "$WT_STALE" ] && [ -d "$WT_GONE" ] && [ -d "$WT_WORK" ] && [ -d "$WT_FRESH" ] || {
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

echo "--- branches whose life is not over, and the main checkout ---"
check_in "$WT_WORK"  no-work-on-stale-branch.sh ALLOW 'a branch carrying work of its own, ahead == 1' \
  'git commit -m "wip"'
check_in "$WT_FRESH" no-work-on-stale-branch.sh ALLOW 'a fresh branch at the dev tip, ahead == 0 behind == 0' \
  'git commit -m "wip"'
# The same commit, the same state, the same command -- and the main checkout is
# unaffected, because the guard keys on the linked worktree.
check_in "$LIFE" no-work-on-stale-branch.sh ALLOW 'the main checkout at the stale branch own commit' \
  'git commit -m "wip"'

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

echo "--- the guard fails closed when the tokeniser is not beside it, and only where it has an opinion ---"
cp no-work-on-stale-branch.sh "$FIXTURES/nolib/"
check_in "$WT_STALE" "$FIXTURES/nolib/no-work-on-stale-branch.sh" BLOCK 'no lib/, on a stale branch' \
  'git status'
# Failing closed is scoped to a branch this file has an opinion about. A healthy
# worktree is not refused because a library is missing.
check_in "$WT_WORK" "$FIXTURES/nolib/no-work-on-stale-branch.sh" ALLOW 'no lib/, on a branch carrying work' \
  'git commit -m "wip"'
# A library that is present but incomplete. cs_git_args is the function whose
# absence would be silent and permitting: `RAW=$(cs_git_args "$VERB") ||
# continue` cannot tell "not this verb" from "no such function", so probing
# cs_split alone left every verb permitted through the check written to stop
# exactly that. Found by review, not by this suite.
mkdir -p "$FIXTURES/halflib/lib"
cp no-work-on-stale-branch.sh "$FIXTURES/halflib/"
sed 's/^cs_git_args()/cs_renamed_away()/' lib/command-scan.sh > "$FIXTURES/halflib/lib/command-scan.sh"
grep -q '^cs_renamed_away()' "$FIXTURES/halflib/lib/command-scan.sh" || {
  echo "the half-library fixture did not rename cs_git_args; the check below proves nothing" >&2
  exit 1
}
check_in "$WT_STALE" "$FIXTURES/halflib/no-work-on-stale-branch.sh" BLOCK 'a library missing only cs_git_args' \
  'git commit -m "wip"'

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
DEV_DERIVATION="| grep -E '^origin/dev-[0-9]+\$' | sort -V | tail -1)"
armed 'the guard derives the active dev branch this way' \
  "$HOOKS/no-work-on-stale-branch.sh" "$DEV_DERIVATION"
armed 'and the report derives it identically' \
  "$HOOKS/report-stale-branches.sh" "$DEV_DERIVATION"

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
# The report's timeout must outlast the fetch it waits on, or the hook is killed
# before it can say that the fetch failed.
tok 'the report hook outlasts its own fetch' \
    '30' \
    "$(jq -r '.hooks.SessionStart[]?.hooks[]? | select(.command | contains("report-stale-branches")) | .timeout' "$SETTINGS" 2>/dev/null)"

echo
if [ $FAILED -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
exit $FAILED

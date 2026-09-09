#!/bin/bash
# Regression checks for no-git-push.sh and no-pr-decisions.sh.
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
# One expectation is not a literal but a context: whether pushing this branch is
# permitted depends on where the suite runs, because that is exactly what
# no-git-push.sh decides. Run from a linked worktree on a worktree branch, a push
# of that branch is ALLOW; run from the main checkout, the identical command is
# BLOCK. OWN_BRANCH_PUSH holds whichever applies, and the banner says which.
#
# Run: bash .claude/hooks/check-hooks.sh
cd "$(dirname "$0")" || exit 1

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
tok 'wrapper word and its options removed' \
    'git push --mirror' \
    "$(printf 'xargs -n1 git push --mirror\n' | cs_split)"
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

echo
if [ $FAILED -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
exit $FAILED

#!/bin/bash
# Regression probes for no-git-push.sh and no-pr-decisions.sh.
#
# A hook is a process, so the only way to test one is to run it; what the rule
# against calling the function under test forbids is deriving the expectation
# from it, and every verdict below is written as a literal BLOCK or ALLOW.
#
# The heredoc probes exist because an earlier version of these hooks blocked the
# commit that introduced them: grep anchors ^ per line, so a wrapped line of a
# commit message naming a refused command read as a command position. The
# indentation and wrapper probes come from the review on PR #35.
#
# One expectation is not a literal but a context: whether pushing this branch is
# permitted depends on where the suite runs, because that is exactly what
# no-git-push.sh decides. Run from a linked worktree on a feature branch, a push
# of that branch is ALLOW; run from the main checkout, the identical command is
# BLOCK. OWN_BRANCH_PUSH holds whichever applies, and the banner says which.
#
# Run: bash .claude/hooks/probe-hooks.sh
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
probe() {
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

echo "=== REGRESSION: heredoc prose that blocked its own commit ==="
COMMIT_MSG=$'git commit -q -F - <<\'EOF\'\nLeave pushing and deciding a PR to Bertan\n\nno-git-push.sh refuses every push; no-pr-decisions.sh refuses\ngh pr review --approve and --request-changes, gh pr close and reopen.\ngit push origin main is refused in every form.\ngh pr merge 5 would also be refused.\nEOF'
probe no-git-push.sh     ALLOW 'commit msg naming git push in heredoc' "$COMMIT_MSG"
probe no-pr-decisions.sh ALLOW 'commit msg naming gh pr verbs in heredoc' "$COMMIT_MSG"
NOTE=$'cat > /tmp/note.md <<\'MD\'\ngh pr merge is now refused by a hook.\ngit push origin main likewise.\nMD'
probe no-git-push.sh     ALLOW 'heredoc body naming git push' "$NOTE"
probe no-pr-decisions.sh ALLOW 'heredoc body naming gh pr merge' "$NOTE"

echo "=== REGRESSION: PR #35, indentation defeated the anchor ==="
# Each names a refused destination, so these assert that the command is still
# *found* when indented, independently of the worktree exception.
probe no-git-push.sh     BLOCK 'if/then + indented push to dev-05' $'if true; then\n    git push origin dev-05\nfi'
probe no-git-push.sh     BLOCK 'for loop + indented push to main'  $'for r in a b; do\n  git push origin main\ndone'
probe no-git-push.sh     BLOCK 'deeply indented push to main'      $'if true; then\n  if true; then\n        git push origin main\n  fi\nfi'
probe no-pr-decisions.sh BLOCK 'if/then + indented merge'          $'if true; then\n    gh pr merge 35\nfi'
probe no-pr-decisions.sh BLOCK 'for loop + indented close'         $'for n in 1 2; do\n  gh pr close $n\ndone'

echo "=== REGRESSION: PR #35, no-pr-decisions.sh had no wrapper rule ==="
probe no-pr-decisions.sh BLOCK 'bash -c gh pr merge'  "bash -c 'gh pr merge 35'"
probe no-pr-decisions.sh BLOCK 'sh -c gh pr merge'    'sh -c "gh pr merge 35"'
probe no-pr-decisions.sh BLOCK 'eval gh pr merge'     "eval 'gh pr merge 35'"
probe no-pr-decisions.sh BLOCK 'graphql mutation via heredoc' $'gh api graphql -f query=@- <<EOF\nmutation { mergePullRequest(input:{pullRequestId:"x"}) { clientMutationId } }\nEOF'
probe no-pr-decisions.sh BLOCK 'REST merge via heredoc body'  $'gh api -X PUT --input - <<EOF\n{"path":"/repos/o/r/pulls/5/merge"}\nEOF'

echo "=== ACCEPTED false positive: quoted multi-line string, not a heredoc ==="
# The price of allowing leading whitespace in the anchor. Kept on purpose: a
# blocked comment is visible and one edit away, a silently permitted push is
# neither. If a later change makes these ALLOW, that is a decision to take
# knowingly, not a bug fix.
probe no-git-push.sh     BLOCK 'multi-line -b string continuing with a push' $'gh issue comment 27 -b "to release:\n  git push origin main"'
probe no-pr-decisions.sh BLOCK 'multi-line -b string continuing with a merge' $'gh issue comment 27 -b "to land it:\n  gh pr merge 35"'

echo "=== worktree exception: pushing this worktree's own branch ==="
probe no-git-push.sh "$OWN_BRANCH_PUSH" 'bare git push'                    'git push'
probe no-git-push.sh "$OWN_BRANCH_PUSH" 'git push after a commit'          'git commit -m msg && git push'
probe no-git-push.sh "$OWN_BRANCH_PUSH" 'git push in a subshell'           '(git push)'
probe no-git-push.sh "$OWN_BRANCH_PUSH" 'git push with a trailing ;'       'git push;'
probe no-git-push.sh "$OWN_BRANCH_PUSH" 'git push --force-with-lease'      'git push --force-with-lease'
probe no-git-push.sh "$OWN_BRANCH_PUSH" 'git push -u origin <this branch>' "git push -u origin $CURRENT"
probe no-git-push.sh "$OWN_BRANCH_PUSH" 'indented push, own branch'        $'if true; then\n    git push\nfi'

echo "=== worktree exception does not extend to ==="
probe no-git-push.sh BLOCK 'another branch by name: main'      'git push origin main'
probe no-git-push.sh BLOCK 'another branch by name: dev-05'    'git push origin dev-05'
probe no-git-push.sh BLOCK 'a refspec destination: HEAD:main'  'git push origin HEAD:main'
probe no-git-push.sh BLOCK 'a forced push to dev-05'           'git push -f origin dev-05'
probe no-git-push.sh BLOCK 'a cd before the push'              'cd /tmp && git push'
probe no-git-push.sh BLOCK 'a cd before the push, with ;'      'cd /tmp; git push'
probe no-git-push.sh BLOCK 'git redirected with -C'            'git -C /home/bgunyel/source/ai/clause-and-effect push'
probe no-git-push.sh BLOCK 'git redirected with --git-dir'     'git --git-dir=/elsewhere/.git push'
probe no-git-push.sh BLOCK 'a push inside sh -c'               'sh -c "git push"'
probe no-git-push.sh BLOCK 'a push inside bash -c'             'bash -c "git push origin dev-05"'
probe no-git-push.sh BLOCK 'a push inside eval'                'eval "git push"'
probe no-git-push.sh BLOCK 'a push inside a heredoc fed to sh' $'bash <<\'EOF\'\ngit push\nEOF'

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
do probe no-git-push.sh ALLOW "$c" "$c"; done

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
do probe no-pr-decisions.sh BLOCK "$c" "$c"; done

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
do probe no-pr-decisions.sh ALLOW "$c" "$c"; done

echo
if [ $FAILED -eq 0 ]; then echo "ALL PROBES PASSED"; else echo "SOME PROBES FAILED"; fi
exit $FAILED

#!/bin/bash
# Regression probes for no-git-push.sh and no-pr-decisions.sh.
#
# A hook is a process, so the only way to test one is to run it; what the rule
# against calling the function under test forbids is deriving the expectation
# from it, and every verdict below is written as a literal BLOCK or ALLOW.
#
# The four heredoc probes exist because an earlier version of these hooks
# blocked the commit that introduced them: grep anchors ^ per line, so a wrapped
# line of a commit message naming one of the refused commands read as a command
# position. The four multi-line probes guard the other direction, that dropping
# heredoc bodies did not also drop real commands.
#
# Run: bash .claude/hooks/probe-hooks.sh
cd "$(dirname "$0")" || exit 1

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
COMMIT_MSG=$'git commit -q -F - <<\'EOF\'\nLeave pushing and deciding a PR to Bertan\n\nno-git-push.sh refuses every push; no-pr-decisions.sh refuses\ngh pr review --approve and --request-changes, gh pr close and reopen.\ngit push is refused in every form.\ngh pr merge 5 would also be refused.\nEOF'
probe no-git-push.sh     ALLOW 'commit msg naming git push in heredoc' "$COMMIT_MSG"
probe no-pr-decisions.sh ALLOW 'commit msg naming gh pr verbs in heredoc' "$COMMIT_MSG"
NOTE=$'cat > /tmp/note.md <<\'MD\'\ngh pr merge is now refused by a hook.\ngit push likewise.\nMD'
probe no-git-push.sh     ALLOW 'heredoc body naming git push' "$NOTE"
probe no-pr-decisions.sh ALLOW 'heredoc body naming gh pr merge' "$NOTE"

echo "=== REGRESSION: real commands still caught in multi-line input ==="
probe no-git-push.sh     BLOCK 'multi-line, push on line 2'   $'cd /tmp\ngit push origin dev-05'
probe no-pr-decisions.sh BLOCK 'multi-line, merge on line 2'  $'cd /tmp\ngh pr merge 5'
probe no-git-push.sh     BLOCK 'heredoc fed to a shell'       $'bash <<\'EOF\'\ngit push\nEOF'
probe no-git-push.sh     BLOCK 'real push after heredoc ends' $'cat > /tmp/f <<\'EOF\'\nhello\nEOF\ngit push'

echo "=== no-git-push.sh : must BLOCK ==="
for c in 'git push' \
         'git push origin dev-05' \
         'git push -f origin dev-05' \
         'git push --force-with-lease' \
         'git push origin HEAD:main' \
         'git -C /home/bgunyel/source/ai/clause-and-effect push' \
         'git -c user.name=x push origin HEAD' \
         'git commit -m msg && git push' \
         'cd /tmp; git push' \
         'make test || git push' \
         '(git push)' \
         'bash -c "git push origin dev-05"' \
         'sh -c "git push"' \
         'eval "git push"' \
         'git push;'
do probe no-git-push.sh BLOCK "$c" "$c"; done

echo "=== no-git-push.sh : must ALLOW ==="
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

#!/bin/bash
# THE ISSUE FILE OF #164: PUSH_REFUSE in no-commit-to-main.sh, and so every arm
# it backs, names no push, because the one it named is refused by
# no-git-push.sh.
#
# Why: PUSH_REFUSE ended "Push your dev-NN branch and open a PR instead", and an
# agent that did so was refused by no-git-push.sh from every checkout it could
# stand in -- a linked worktree on dev-NN ("which is Bertan's to push") and the
# main checkout ("not a linked worktree"). Both refusals are right by US-2, so
# the defect was the message: US-7 asks a refusal to name a spelling an agent
# can use, and this one named a spelling a second hook refuses. Found by #109's
# cross-hook checks, whose row on the message was a gap until this file.
#
# WHICH ARMS. PUSH_REFUSE backs the arm that refuses a push naming main, and the
# arms that refuse a push which may land on main without naming it: today
# `--all` and `--mirror`, an unreadable continuation, a wildcard refspec, and
# `-c`. How many is NCM164_ARMS's to say, not this paragraph's: that list is held
# to the hook by a count of its PUSH_REFUSE expansions, since review added an
# arm and nothing went red. The bare push on main has a sentence of its own,
# which names the command it refuses and gives no remedy; #164 left it alone and
# nothing here reads it.
#
# THE TRADE, which the comment above PUSH_REFUSE argues and this file pins as
# behaviour. The message is shown in four contexts: the main checkout, a linked
# worktree on main, one on dev-NN, and one on a worktree branch. In the first
# three no push is permitted at all; in the fourth `git push origin <that
# branch>` is, by every Bash hook. The message is one string, read in all four,
# so it now names no push anywhere, and the fourth context loses a sentence of
# guidance it could have had -- which is also where it falls short of US-7.
# Naming the push only there would mean this hook re-deriving no-git-push.sh's
# worktree detection, which #164 rejected. The last group below is that trade:
# the push is permitted from that worktree, and the refusal shown there is
# pinned exactly, so any change to its remedy -- a push named in it again, in a
# spelling or in prose, on its line or on another -- turns it red and has to
# answer why.
#
# NO DECLARATION. GH-164 is in the legacy set, hand-written before #205, and a
# legacy entry is edited in place and never declared, so its gap marker came off
# requirements/GH-164.md and its SPLIT_MOVED token moved with it.
#
# EXACTLY, AND WHY NOT A PAIR. Every message here is compared for equality, by
# `says_exactly`. The first version pinned each as `says_first` on the text plus
# `says_not` on the text with a space after, which is how every arm joins its
# tail, and called that whole. It was whole up to the first line: a second
# `echo >&2` after an arm's own is joined by a newline, and review of PR #291
# put a push remedy back that way -- in prose, and as `git -C . push` -- with
# the suite green. Equality asks about every character, so there is no joining
# to enumerate and no push spelling to define. GH-43.5 pins the opening
# sentence, `Blocked: pushing to main.`, on its own; the rows here pin the
# message it opens, and #109's section in the unsplit file keeps its own two
# rows on the old sentence and on `git push`.

section "=== issue #164: PUSH_REFUSE names no push another hook refuses ==="

# NCM164_OPEN is the two sentences the fix kept, and NCM164_REMEDY the one it
# wrote. NCM164_BARE is the message of the arm that adds no tail.
NCM164_OPEN='Blocked: pushing to main. CLAUDE.md requires that main is only ever updated by pull request.'
NCM164_REMEDY='Leave the commits on the branch and say what is ready to push.'
NCM164_BARE="$NCM164_OPEN $NCM164_REMEDY"
need_worktree "$PUSH_WT_DEV" 'push dev'
need_worktree "$PUSH_WT_MAIN" 'push main'
need_worktree "$PUSH_WT" 'push'

# One arm a line: its command, a bar, and the tail it appends. The first has none.
NCM164_ARMS="git push origin main|
git push --all origin| That form pushes every branch, main among them.
git push origin \\ | The arguments continue past where this check can read them.
git push origin 'refs/heads/*:refs/heads/*'| A wildcard refspec does not rule main out.
git -c push.default=matching push| This command sets git configuration for itself, which decides where a push lands."

# THE LIST IS HELD TO THE HOOK. The rows below ask each line of NCM164_ARMS, and
# GH-164's text says "every arm", so an arm added to the hook and not to the list
# is unasked -- and review of PR #291 added one, whose tail named
# `git push origin <branch>`, with the suite green. So the expansions of
# PUSH_REFUSE in the hook under judgment are counted, and the count has to be
# the list's length: a sixth arm is red here until it is a sixth line there,
# where every context runs it through `says_exactly`. Only the count is derived.
# The tails stay literals, since reading them off the hook would have the hook
# attest to itself (#84's shape: derive the population, not the verdict).
#
# Whole-line comments are dropped and nothing else, so a trailing comment that
# names `$PUSH_REFUSE` over-counts -- red, and one edit away -- where cutting at
# every `#` would under-count a site written after a `#` in a string. What this
# does not see, named: a new trigger routed into an existing site, which gives
# that site's pinned text; and an echo added after a site under a condition
# none of the five contexts meets.
req GH-164
NCM164_HOOK="$HOOKS/no-commit-to-main.sh"
if absolute_or_fail 'the PUSH_REFUSE count reads the hook under judgment' "$NCM164_HOOK"; then
  if [ -f "$NCM164_HOOK" ] && [ -r "$NCM164_HOOK" ]; then
    tok 'no-commit-to-main.sh expands PUSH_REFUSE as many times as NCM164_ARMS has arms, so an arm added to either is red until it is in the other' \
      "$(printf '%s\n' "$NCM164_ARMS" | grep -c .)" \
      "$(grep -v '^[[:space:]]*#' "$NCM164_HOOK" | grep -oE '\$\{?PUSH_REFUSE([^A-Za-z0-9_]|$)' | wc -l | tr -d ' ')"
  else
    fail static 'the PUSH_REFUSE count: %s was not read, so no count of it is evidence' "$NCM164_HOOK"
  fi
fi

# Every arm PUSH_REFUSE backs, from one directory: the kept opening, the new
# remedy, and the arm's own tail unchanged, and nothing else.
ncm164_arms() {  # ncm164_arms <dir> <where, for the label>
  local cmd tail
  while IFS='|' read -r cmd tail; do
    says_exactly "$1" no-commit-to-main.sh "$NCM164_BARE$tail" \
      "from $2, \`$cmd\` is refused with exactly the new remedy${tail:+, then its own tail}" \
      "$cmd"
  done <<< "$NCM164_ARMS"
}

# Every arm from every context, not the bare one from one: a remedy made
# context-aware would be written into one arm or for one context, and a row
# that does not run there cannot see it. The main checkout is asked on a dev
# branch, where the old sentence was plainest wrong -- the branch it told an
# agent to push was the one checked out -- and on main. Written out per context
# rather than looped, so that each call names the directory its rows run in.
req GH-164
ncm164_arms "$ON_DEV" 'the main checkout on a dev branch'
ncm164_arms "$ON_MAIN" 'the main checkout on main'
ncm164_arms "$PUSH_WT_MAIN" 'a linked worktree on main'
ncm164_arms "$PUSH_WT_DEV" 'a linked worktree on dev-05'

# THE TRADE, as behaviour. From a linked worktree on a worktree branch the push
# of that branch is permitted by every Bash hook, and every refusal PUSH_REFUSE
# backs, shown in that same worktree, is exactly its message -- which names no
# push, that one included. That is the case #164 gave up.
req GH-164
every_hook "$PUSH_WT" 'from a linked worktree on a worktree branch, git push origin <that branch> is permitted by every Bash hook' \
  "git push origin $PUSH_BRANCH"
ncm164_arms "$PUSH_WT" 'that worktree, where the push above is permitted and named nowhere'

sourced_to_end

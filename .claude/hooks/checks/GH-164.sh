#!/bin/bash
# THE ISSUE FILE OF #164: no-commit-to-main.sh's refusal of a push to main names
# no push, because the one it named is refused by no-git-push.sh.
#
# Why: PUSH_REFUSE ended "Push your dev-NN branch and open a PR instead", and an
# agent that did so was refused by no-git-push.sh from every checkout it could
# stand in -- a linked worktree on dev-NN ("which is Bertan's to push") and the
# main checkout ("not a linked worktree"). Both refusals are right by US-2, so
# the defect was the message: US-7 asks a refusal to name a spelling an agent
# can use, and this one named a spelling a second hook refuses. Found by #109's
# cross-hook checks, whose row on the message was a gap until this file.
#
# THE TRADE, which the comment above PUSH_REFUSE argues and this file pins as
# behaviour. The message is shown in three contexts: the main checkout, a
# linked worktree on dev-NN, and a linked worktree on a worktree branch. In the
# first two no push is permitted at all; in the third `git push origin <that
# branch>` is, by every Bash hook. The message is one string, shared by every
# arm that refuses a push naming main and read in all three, so it now names
# no push anywhere, and the third context loses a sentence of guidance it could
# have had -- which is also where it falls short of US-7. Naming the push only
# there would mean this hook re-deriving no-git-push.sh's worktree detection,
# which #164 rejected. The last group below is that trade: the push is
# permitted from that worktree, and the refusal shown there is pinned whole, so
# any change to its remedy -- a push named in it again, in a spelling or in
# prose -- turns it red and has to answer why.
#
# NO DECLARATION. GH-164 is in the legacy set, hand-written before #205, and a
# legacy entry is edited in place and never declared, so its gap marker came off
# requirements/GH-164.md and its SPLIT_MOVED token moved with it.
#
# WHAT "WHOLE" MEANS HERE. `says_first` asks for an opening, so each message is
# pinned twice: `says_first` on the full text, and `says_not` on that text with
# a space after it, which is how every arm joins a sentence to PUSH_REFUSE. So a
# sentence appended after an arm's tail, or after the bare arm's remedy, turns
# a row red. Text joined without a space is not asked about.
#
# WHAT A "PUSH SPELLING" IS, for the rows that say the message names none: the
# literal `git push`, which every spelling an agent is told to run opens with,
# and the old sentence itself, which named a push in prose. A push named some
# third way -- `git -C x push` -- is caught only by the whole-message rows,
# which catch any change to the remedy at all. GH-43.5 pins the opening
# sentence, `Blocked: pushing to main.`, on its own; the rows here pin the
# second sentence with it.

section "=== issue #164: the push-to-main refusal names no push another hook refuses ==="

# NCM164_OPEN is the two sentences the fix kept, and NCM164_REMEDY the one it
# wrote. NCM164_BARE is the bare arm's whole message.
NCM164_OPEN='Blocked: pushing to main. CLAUDE.md requires that main is only ever updated by pull request.'
NCM164_REMEDY='Leave the commits on the branch and say what is ready to push.'
NCM164_BARE="$NCM164_OPEN $NCM164_REMEDY"
need_worktree "$PUSH_WT_DEV" 'push dev'
need_worktree "$PUSH_WT" 'push'

# One arm's whole message, from one directory: it opens with <message>, and
# nothing is joined after it.
ncm164_whole() {  # ncm164_whole <dir> <message> <label> <cmd>
  says_first "$1" no-commit-to-main.sh "$2" "$3" "$4"
  says_not "$1" no-commit-to-main.sh "$2 " "$3, and nothing after it" "$4"
}

# Every arm PUSH_REFUSE backs: the kept opening, the new remedy, and the arm's
# own tail unchanged. From the main checkout on a dev branch, where the old
# sentence was plainest wrong: the branch it told an agent to push was the one
# checked out, and no-git-push.sh refuses every push there.
req GH-164
ncm164_whole "$ON_DEV" "$NCM164_BARE" \
  'a push naming main: the refusal is the kept sentences, then the remedy' 'git push origin main'
ncm164_whole "$ON_DEV" "$NCM164_BARE That form pushes every branch, main among them." \
  'the --all arm keeps its tail after the new remedy' 'git push --all origin'
ncm164_whole "$ON_DEV" "$NCM164_BARE The arguments continue past where this check can read them." \
  'the continuation arm keeps its tail after the new remedy' 'git push origin \ '
ncm164_whole "$ON_DEV" "$NCM164_BARE A wildcard refspec does not rule main out." \
  'the wildcard arm keeps its tail after the new remedy' "git push origin 'refs/heads/*:refs/heads/*'"
ncm164_whole "$ON_DEV" "$NCM164_BARE This command sets git configuration for itself, which decides where a push lands." \
  'the -c arm keeps its tail after the new remedy' 'git -c push.default=matching push'

# The old sentence is gone from each of the three contexts the message is shown
# in, and no `git push` took its place. Written out per context rather than
# looped, so that each label names the directory its row runs in.
says_not "$ON_MAIN" no-commit-to-main.sh 'Push your dev-NN branch' \
  'from the main checkout on main, the refusal no longer tells an agent to push a dev-NN branch' 'git push origin main'
says_not "$ON_MAIN" no-commit-to-main.sh 'git push' \
  'from the main checkout on main, the refusal says no git push' 'git push origin main'
says_not "$PUSH_WT_DEV" no-commit-to-main.sh 'Push your dev-NN branch' \
  'from a linked worktree on dev-05, the refusal no longer tells an agent to push a dev-NN branch' 'git push origin main'
says_not "$PUSH_WT_DEV" no-commit-to-main.sh 'git push' \
  'from a linked worktree on dev-05, the refusal says no git push' 'git push origin main'

# THE TRADE, as behaviour. From a linked worktree on a worktree branch the push
# of that branch is permitted by every Bash hook, and the refusal of a push to
# main shown in that same worktree is the bare message, whole -- which names no
# push, that one included.
req GH-164
every_hook "$PUSH_WT" 'from a linked worktree on a worktree branch, git push origin <that branch> is permitted by every Bash hook' \
  "git push origin $PUSH_BRANCH"
ncm164_whole "$PUSH_WT" "$NCM164_BARE" \
  'and the refusal of a push to main shown there is the bare message, which does not name that push: the case #164 gave up' \
  'git push origin main'
says_not "$PUSH_WT" no-commit-to-main.sh 'git push' \
  'and says no git push, the permitted one included' 'git push origin main'

sourced_to_end

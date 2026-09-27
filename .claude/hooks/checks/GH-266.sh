#!/bin/bash
# THE ISSUE FILE OF #266: a command word in quotes, standing behind a prefix
# word's separated option value, is the command word it spells.
#
# Why: cs_split finds a command word behind `sudo -u root` or `nice -n 5` by
# offering the tail of the line as further candidates, since which options take
# a value is a list it does not keep. The offer stopped at any token opening
# with a double or a single quote, on the argument that what follows is the text
# of an argument -- and a quoted command word opens with a quote too. So
# `sudo -u root "git" push origin main`, `nice -n 10 "git" push --all origin`
# and `timeout -s KILL 30 "gh" pr merge 5` were permitted by every hook that
# refuses their bare spellings. Measured at origin/dev-05 2303e9b on stdin.
#
# Found by the review of PR #260 (#166), round 1, as the permitting half of a
# finding about #166: that pull request made ANSI-C quoting a quote everywhere
# but in this test, and the review measured that the natural fix for the prose
# it then misread -- adding the dollar -- survived a whole green run while
# reopening the same push in ANSI-C quotes. The two are one line and one
# question, so they closed together. Round 1 made the offer ask whether a token
# LEFT a quote open, and round 2 of the same review measured that wrong both
# ways; the offer now reads words from the word reader, so a quoted word is a
# word and a quoted span holding a blank is stepped over whole. That is
# GH-166.1, in #166's issue file, beside the ANSI-C half.
#
# A BOUNDARY STOOD HERE AND ITS REASON WAS FALSE. Round 1 pinned a quoted option
# value holding a blank, `sudo -u "ro ot" git push origin main`, as permitted,
# on the premise that no user name, signal or priority holds one. Round 2 of the
# review measured six shapes of it -- a directory behind `env -C` and `sudo -D`,
# a prompt behind `sudo -p`, a lock file behind flock, a group behind `sudo -g`
# -- none exotic. The row is a flip now, and the premise is withdrawn here, in
# the entry and in its generated file.
section "=== issue #266: a quoted command word behind a prefix word's option value ==="

requirement GH-266 <<'REQ'
- text: Behind a prefix word whose option takes a separate value, a command word in
  double or single quotes is the command word it spells:
  `sudo -u root "git" push origin main`, `sudo -u root 'git' push origin main`,
  `nice -n 10 "git" push --all origin` and `sudo -u root "gh" pr merge 5` reach
  the verdicts their bare spellings reach. The tail offer in `cs_split` offers
  the words after the head as the word reader reports them (GH-166.1): a quoted
  word is a word like a bare one, and text inside a quote is never offered.
  Permitted as before:
  `sudo -u root 'git push origin main'`, which runs a program of that whole
  name, and a prose string in any quoting form behind a prefix word,
  `sudo echo 'git push origin main'`.
- from: #266, found by the review of PR #260 (#166), round 1
- kind: defect-permitting
- status: active
- variants: transformation: pre-nice-opt-dquoted pre-nice-opt-squoted
- note: the trade is in the refusing direction and is pinned: a quoted word
  behind a prefix word that is NOT the command word is now offered as one, so
  `sudo echo "git" push origin main` is refused, as its unquoted spelling
  `sudo echo git push origin main` already was. A quoted option value holding a
  blank, `sudo -u "ro ot" git push origin main`, was pinned permitted in round
  1 on the premise that no user name, signal or priority holds a blank; round 2
  measured directories, prompts, lock files and group names that do, and it is
  refused since GH-166.1. The ANSI-C and locale spellings of the same shape are
  GH-166's, and `pre-nice-opt-ansi` and `pre-nice-opt-locale` are declared
  there.
REQ
shape_pin 'GH-266'
variants_pin 'GH-266:transformation'

# THE COMMAND WORD IN QUOTES, behind a valued option, in each boundary hook that
# refuses its bare spelling. Every one was permitted at 2303e9b.
req GH-266 US-1
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'a double-quoted command word behind sudo -u root, a push to main' \
  'sudo -u root "git" push origin main'
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'a single-quoted command word behind sudo -u root, a push to main' \
  "sudo -u root 'git' push origin main"
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'a double-quoted command word behind nice -n 10, a push of every branch' \
  'nice -n 10 "git" push --all origin'
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'a quoted path as the command word behind sudo -u root' \
  'sudo -u root "/usr/bin/git" push origin main'
flip "$ON_DEV" no-commit-to-main.sh ALLOW BLOCK 'a double-quoted command word behind sudo -u root, a push naming main' \
  'sudo -u root "git" push origin main'
req GH-266 US-15
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a double-quoted command word behind sudo -u root, a merge' \
  'sudo -u root "gh" pr merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a double-quoted command word behind timeout -s KILL 30, a merge' \
  'timeout -s KILL 30 "gh" pr merge 5'

# WHAT STAYS PERMITTED: a token left open at its blank is prose, and the offer
# stops at it. Each is a row a fix that offered every quoted token turns red.
req GH-266
check_in "$PUSH_WT" no-git-push.sh ALLOW 'a quoted string holding a push behind sudo -u root is one word, a program of that name' \
  "sudo -u root 'git push origin main'"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'a single-quoted prose string behind sudo echo' \
  "sudo echo 'git push origin main'"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'a double-quoted prose string behind sudo echo' \
  'sudo echo "git push origin main"'
req GH-266 US-13
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'a double-quoted command word behind sudo -u root, gh pr view' \
  'sudo -u root "gh" pr view 5'

# THE TRADE, in the refusing direction: a quoted word the offer reads is read
# whether or not it is the command word, exactly as a bare one is. Permitted at
# 2303e9b, where the quote stopped the offer; the bare spelling was refused
# there and is the control.
req GH-266 US-1
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'THE TRADE: a double-quoted word behind sudo echo is offered as a command word' \
  'sudo echo "git" push origin main'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'its control: the same words unquoted, refused before #266' \
  'sudo echo git push origin main'

# WHAT WAS A BOUNDARY: a quoted option value holding a blank. Pinned permitted
# in round 1 on a premise round 2 measured false; reached since GH-166.1.
req GH-266 GH-166.1 US-1
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'a quoted option value holding a blank is one word, and the push behind it is read' \
  'sudo -u "ro ot" git push origin main'

sourced_to_end

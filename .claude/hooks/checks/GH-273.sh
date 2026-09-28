#!/bin/bash
# THE ISSUE FILE OF #273: an environment assignment holding a quoted blank, in
# front of a command, does not hide that command.
#
# Why: three walks cut an assignment at a blank without knowing a quote. The
# assignment strip in cs_split removed `A="b` and left `c"` as the command word;
# behind env, the tail offer stopped at a quoted `"A=b c"` as prose; and the
# wrapper anchor's assignment branch, `NAME=` and a run of non-blanks, could not
# step over the quoted blank. So `GIT_SSH_COMMAND="ssh -i k" git push origin
# main` -- the documented way to push with a given key -- was permitted by every
# boundary hook, and so were a merge and a wrapped push behind the same prefix.
# Measured at origin/dev-05 abba1d0 on stdin.
#
# Found by the review of PR #260 (#166), round 2, and closed by it. The first
# two walks are GH-166.1, in #166's issue file: every walk cs_split makes steps
# by words the word reader reports, so the assignment is one word. The third is
# a regular expression, which cannot call the reader, so its value is now a run
# of unquoted characters, double-quoted spans and single-quoted spans --
# CS_WRAPPER_RE in lib/command-scan.sh argues it.
#
# WHAT IS NOT HERE. A double quote escaped inside a double-quoted value,
# `A="b \" c" bash -c ...`, ends the value early for that expression, which pairs
# quotes without reading escapes, and the wrapper refusal is not reached. It is
# the same "as far as a regular expression reaches" trade the anchor records for
# `b"a"sh`, and is pinned below as a boundary. The command in front of the
# wrapper is still read by cs_split, which reads escapes, so this is the
# wrapper arm alone.
section "=== issue #273: an assignment holding a quoted blank in front of a command ==="

requirement GH-273 <<'REQ'
- text: An environment assignment in front of a command, whose value holds a
  quoted blank in any quoting form, is stripped whole, and the command behind it
  reaches the verdict its bare spelling reaches:
  `GIT_SSH_COMMAND="ssh -i k" git push origin main`, `A='b c' git push origin main`,
  `A=$'b c' git push origin main`, `A=b\ c git push origin main` and
  `A="b c" gh pr merge 5` are refused, and so
  is the same assignment as an env operand,
  `env "GIT_SSH_COMMAND=ssh -i k" git push origin main`. In front of a wrapper
  the wrapper refusal is reached: `A="b c" bash -c "git push origin main"` is
  refused. Permitted as before: `A="b c" git status`, a push of the worktree's
  own branch behind the same prefix, and a wrapper running nothing guarded.
- from: #273, found by the review of PR #260 (#166), round 2
- kind: defect-permitting
- status: active
- variants: transformation: pre-assign-spaced pre-assign-escaped
- note: the strip and the env operand read the assignment through the word
  reader, which is GH-166.1; the wrapper anchor reads raw text and admits a
  quoted span as part of the value. Its trade is pinned as a boundary: a double
  quote escaped inside a double-quoted value ends the value for the expression,
  so `A="b \" c" bash -c "git push origin main"` is permitted, as `b"a"sh -c` is
  -- measured permitted at abba1d0 too, so nothing moved.
REQ
shape_pin 'GH-273'
variants_pin 'GH-273:transformation'

# THE ASSIGNMENT STRIP, in front of the command itself. Every one was permitted
# at abba1d0: the strip removed half the assignment and left the other half as
# the command word.
req GH-273 US-1
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'an assignment prefix holding a double-quoted blank, the documented GIT_SSH_COMMAND' \
  'GIT_SSH_COMMAND="ssh -i k" git push origin main'
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'an assignment prefix holding a single-quoted blank' \
  "A='b c' git push origin main"
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'an assignment prefix holding an ANSI-C blank' \
  "A=\$'b c' git push origin main"
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'an assignment prefix holding a backslash-escaped blank, the fifth quoting form' \
  'A=b\ c git push origin main'
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'two assignment prefixes, each holding a blank' \
  'A="b c" B="d e" git push origin main'
flip "$ON_DEV" no-commit-to-main.sh ALLOW BLOCK 'an assignment prefix holding a blank, a push naming main on a dev branch' \
  'A="b c" git push origin main'
flip "$ON_DEV" no-commit-to-main.sh ALLOW BLOCK 'an assignment prefix holding an escaped blank, a push naming main on a dev branch' \
  'A=b\ c git push origin main'
flip "$ON_MAIN" no-commit-to-main.sh ALLOW BLOCK 'an assignment prefix holding a blank, a commit on main' \
  'A="b c" git commit -m x'
req GH-273 US-15
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an assignment prefix holding a blank, a merge' \
  'A="b c" gh pr merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an assignment prefix holding an escaped blank, a merge' \
  'A=b\ c gh pr merge 5'

# THE ENV OPERAND: the same assignment quoted whole, behind env.
req GH-273 US-1
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'a quoted env operand holding a blank, the documented GIT_SSH_COMMAND' \
  'env "GIT_SSH_COMMAND=ssh -i k" git push origin main'

# THE WRAPPER ANCHOR: the assignment in front of a wrapper.
req GH-273 FR-4
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'an assignment holding a double-quoted blank in front of a wrapper' \
  'A="b c" bash -c "git push origin main"'
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'an assignment holding a single-quoted blank in front of a wrapper' \
  "A='b c' bash -c \"git push origin main\""
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'an assignment holding an ANSI-C blank in front of a wrapper' \
  "A=\$'b c' bash -c \"git push origin main\""
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'an assignment holding an escaped blank in front of a wrapper, which the anchor reads since round 3' \
  'A=b\ c bash -c "git push origin main"'
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'two assignments with blanks in front of a prefix word and a wrapper' \
  'A="b c" B='"'d e'"' sudo bash -c "git push origin main"'
flip "$ON_DEV" no-commit-to-main.sh ALLOW BLOCK 'an assignment holding a blank in front of a wrapper, on a dev branch' \
  'A="b c" bash -c "git push origin main"'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an assignment holding a blank in front of a wrapper around a merge' \
  'A="b c" bash -c "gh pr merge 5"'

# WHAT STAYS PERMITTED, each a row an over-wide fix turns red.
req GH-273
check_in "$PUSH_WT" no-git-push.sh ALLOW 'an assignment prefix holding a blank in front of git status' \
  'A="b c" git status'
check_in "$PUSH_WT" no-git-push.sh ALLOW 'an assignment in front of a wrapper running nothing guarded' \
  'A="b c" bash -c "make test"'
check_in "$PUSH_WT" no-git-push.sh ALLOW 'an escaped assignment in front of a wrapper running nothing guarded' \
  'A=b\ c bash -c "make test"'
check_in "$PUSH_WT" no-git-push.sh ALLOW 'the same assignment and wrapper as prose, beside a git status' \
  'echo "A=\"b c\" bash -c x" && git status'
req GH-273 US-3
check_in "$PUSH_WT" no-git-push.sh ALLOW 'an assignment prefix holding a blank, a push of this worktree own branch' \
  "GIT_SSH_COMMAND=\"ssh -i k\" git push origin $PUSH_BRANCH"
req GH-273 US-14
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'an assignment in front of a wrapper running nothing guarded, in the pr hook' \
  'A="b c" bash -c "make test"'

# THE BOUNDARY: an escaped double quote inside the value, which the expression
# pairs without reading escapes. Permitted at abba1d0 as well.
req GH-273
check_in "$PUSH_WT" no-git-push.sh ALLOW 'BOUNDARY: an escaped double quote inside the value ends it for the wrapper anchor' \
  'A="b \" c" bash -c "git push origin main"'

sourced_to_end

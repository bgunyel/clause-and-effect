#!/bin/bash
# THE ISSUE FILE OF #118: a `gh` command whose subcommand an option has eaten is
# refused as unreadable, and git's list of global options taking a separate value
# is complete.
#
# Why: gh resolves a subcommand path at the first non-flag argument, and cobra
# hands an option it does not know, longhand or shorthand, the next word as its
# value, so
# `gh pr -t view merge 5` merges while every rule in no-pr-decisions.sh read it
# as a view. git has no such shape -- it rejects an unknown global option itself
# -- but cs_git_args lacked --config-env and --attr-source, so their value was
# read as the subcommand. The section's own opening states both at length.
#
# WHAT IS HERE AND WHAT IS NOT. Every check #118's work wrote, with three
# exceptions that stay in the unsplit file, each for a rule in the driver's
# header rather than for convenience:
#   - the three no-work-on-stale-branch.sh checks asking #118's two globals of
#     that hook's own verbs. They run in $WT_STALE, a fixture the unsplit file
#     builds and owns, and a fixture used by two files belongs in the prelude,
#     which it moves to only when the file owning it moves. So they stand beside
#     that fixture's other checks, in the stale-branch section, until it does.
#   - the edits #118 made to checks it did not write: the #96 pipe check whose
#     `--repo|--hostname` row now reads a status, the awk-helper comparison that
#     no longer lists skipopts and the count that replaces it there, and the
#     invariance departure table's option-eats-verb row. A check lives in the
#     file of the issue whose work wrote it, and those were written by others.
#   - the literals the whole suite's counts are held to.
# The requirement is GH-118, which is in the legacy set -- its entry was written,
# as a gap, before #205 -- so it is not declared here: requirements/GH-118.md is
# hand-written, and its shape and variants keyword stand in REQUIREMENT_SHAPE and
# INV_SCOPE with the other legacy entries.
#
# The checks were written before the split, in one file, and moved here as one
# block in their order (#204's conventions); their comments keep the positional
# words they were written with, which now mean this file.
section "=== issue #118: an option before a gh subcommand, and git's global list ==="
# gh resolves a subcommand path at the first non-flag argument, and cobra hands
# an option it does not know as a boolean the next word as a value. So an option
# written in front of a subcommand EATS it, and the verb every rule in
# no-pr-decisions.sh reads is not the verb gh runs. Measured on gh 2.45.0:
# `gh pr -t view merge 5` merges, `gh pr -t view view 5` views and then
# complains that `--template` needs `--json` -- which is the evidence, since only
# the command that ran after the eaten word could say it -- and
# `gh release -t list create v1` creates. Verifying that last row, an agent
# CREATED A REAL RELEASE on this repository. The defect is not a hypothetical
# about what gh would do.
#
# The longhand eats too. This paragraph said it did not -- that cobra treats an
# unknown LONGHAND as a boolean, `gh pr --squash view 5` returning `unknown
# flag: --squash` -- and round 6 of the review showed the message proves
# nothing either way: `gh pr --squash view --help` prints `gh pr`'s usage on gh
# 2.45.0, so `view` was eaten, and cobra's stripFlags gives the next word to any
# option it cannot look up. What differs between spellings is whether the
# resolved subcommand then RUNS, which its own flags decide: `pr merge` defines
# `-t`, so `gh pr -t view merge 5` merges. The rule refuses the shape rather
# than modelling that, because the model is gh's flag definitions per group, the
# list #97 decided against keeping and one a gh release moves. So the longhand
# rows pin a word gh really eats.
#
# THE RULE IS STATED ONCE, as THE UNREADABLE GH SHAPE in lib/command-scan.sh,
# and every consumer of cs_gh_args inherits it from there. Nothing in a hook
# re-derives which options are readable; no-pr-decisions.sh names only the paths
# it judges.
#
# Every flip below was PERMITTED at origin/dev-05 2a52322, and each is measured
# rather than reasoned -- the suite was green on all of them.
req GH-118 US-15
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a shorthand eats the verb, then a merge' \
  'gh pr -t view merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'the longhand spelling of the same shape' \
  'gh pr --squash view merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a value-taking longhand before merge' \
  'gh pr --body x merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an option before a review verdict' \
  'gh pr --approve view review 5'
# BEFORE THE GROUP, not between the group and the verb. With the group eaten,
# which group it was is exactly what cannot be read, so the refusal does not
# wait to find out -- `gh --squash view issue list` is refused although `issue`
# is a group no hook guards, because nothing here can tell that `issue` is the
# group and not the option's value.
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an option before the group, then a merge' \
  'gh --squash view pr merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an option before the group of an unguarded one' \
  'gh --squash view issue list'
req GH-118 FR-48 US-15
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an option before a release create' \
  'gh release --title view create v2'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'the shorthand that created a real release' \
  'gh release -t list create v1'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an option before a release delete' \
  'gh release --yes list delete v1'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an option before a release edit' \
  'gh release --draft view edit v1'
req GH-118 FR-15 FR-16
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an option before a create naming main' \
  'gh pr -t view create --base main --title x'
req GH-118 FR-17
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an option before a retarget to main' \
  'gh pr -t view edit 35 --base main'
# THE READS THIS REFUSES, which is the trade rather than a side effect. A read
# behind an unreadable option is not a read this file can see, and it is refused
# with the writes for the reason a wrapped read is: nothing in the text says
# which verb runs. Both of these are permitted commands in their bare spelling.
req GH-118 US-13
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a pull request read behind an eaten verb' \
  'gh pr -t view view 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'THE ACCEPTED TRADE: a --json read of a pull request' \
  'gh pr --json title view 5'
req GH-118 FR-48
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a release read behind an eaten verb' \
  'gh release -t list view v1'
# Already refused at dev-05, and refused now for a different reason: the value
# `x` was not a read verb, so the allowlist caught it. It is pinned because the
# allowlist is what a narrowing of this rule would leave standing, and a check
# that passes before and after says which of the two is doing the work only when
# its neighbours say what moved.
req GH-118 FR-48 US-15
check_in "$SUITE_DIR" no-pr-decisions.sh BLOCK 'an option before a release edit, value not a read verb' \
  'gh release --notes-file x view edit v1'
#
# WHAT DOES NOT MOVE. The three options that name where a command acts rather
# than what it does are readable in every spelling, so every verdict resting on
# them is the verdict it was. An option AFTER the whole path belongs to the verb
# and was never this rule's. A group no hook guards keeps its verb position.
req GH-118 US-15
check_in "$SUITE_DIR" no-pr-decisions.sh BLOCK 'gh -R o/r pr merge 5, unmoved' \
  'gh -R o/r pr merge 5'
check_in "$SUITE_DIR" no-pr-decisions.sh BLOCK 'gh pr --repo o/r merge 5, unmoved' \
  'gh pr --repo o/r merge 5'
check_in "$SUITE_DIR" no-pr-decisions.sh BLOCK 'gh pr --repo=o/r merge 5, unmoved' \
  'gh pr --repo=o/r merge 5'
check_in "$SUITE_DIR" no-pr-decisions.sh BLOCK 'the attached shorthand -Ro/r is still read' \
  'gh -Ro/r pr merge 5'
req GH-118 US-13
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'gh pr --repo o/r view 5, unmoved' \
  'gh pr --repo o/r view 5'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'an option after the whole path' \
  'gh pr view 5 --json title'
# These two are permitted because ghopt RECOGNISES them -- gh root flag set,
# which `gh help` prints in two lines -- and NOT because of where they stand.
# The comment here used to give the position as the reason, which is the rule
# round 1 removed: a backtick makes any option the last token of its fragment,
# so position is a property of a command and not of what the walk is handed.
# The full argument is with ghopt in lib/command-scan.sh.
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'gh --version' 'gh --version'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'gh --help' 'gh --help'
req GH-118 FR-48
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'gh release -R o/r view v1, unmoved' \
  'gh release -R o/r view v1'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'an option after a release list' \
  'gh release list --limit 5'
req GH-118 US-14
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'an option after an issue list' \
  'gh issue list --label bug'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'gh issue is not a guarded group, so its verb position is not read' \
  'gh issue -t list list'

# THE THIRD OUTCOME, driven directly. cs_gh_args had two answers, "is this path"
# and "is not", and a caller reads the second as `|| continue`, which permits.
# "Cannot tell" is therefore spelled like the first -- success, with no
# arguments -- so that a caller which asks nothing further refuses. These drive
# that caller rather than reasoning about it: the same four lines, over a
# command that is unreadable, over one that is simply not the path, and over the
# library with cs_gh_opaque taken away, which is #84's failure mode for this
# function and must refuse rather than fall back to the old reading.
req GH-118
NAIVE_CALLER='
  read -r CMD
  if ARGS=$(printf "%s\n" "$CMD" | cs_gh_args "pr merge"); then echo REFUSE; else echo PERMIT; fi'
NAIVE_EATS=$(printf 'gh pr -t view merge 5\n' \
  | bash -c ". '$HOOKS/lib/command-scan.sh' && $NAIVE_CALLER" 2>/dev/null)
NAIVE_OTHER=$(printf 'gh issue list\n' \
  | bash -c ". '$HOOKS/lib/command-scan.sh' && $NAIVE_CALLER" 2>/dev/null)
NAIVE_NOWALK=$(printf 'gh issue list\n' \
  | bash -c ". '$HOOKS/lib/command-scan.sh' && CS_GH_AWK= && $NAIVE_CALLER" 2>/dev/null)
tok 'a caller that ignores the third outcome refuses an unreadable command' \
    'REFUSE' "$NAIVE_EATS"
tok 'and still skips a command that is not that path at all' \
    'PERMIT' "$NAIVE_OTHER"
# AND WITH THE WALK ITSELF EMPTIED, which is the state the library withdraws
# both functions for. This drives the state the withdrawal cannot reach -- the
# variable emptied AFTER the library was sourced -- and asserts the direction it
# fails in. An empty awk program is a valid program that reads its input and
# does nothing, measured exit 0, so cs_gh_args answers "cannot tell" for every
# path and every gh rule refuses. Loud, and the permitting direction would be a
# defect: this is the check that says which of the two it is.
#
# The claim this replaced was about cs_gh_opaque being unset, which stopped
# being a claim about cs_gh_args when the two became one program -- it went
# green as PERMIT for the honest reason that cs_gh_args no longer calls it.
tok 'and answers cannot-tell for every path when the shared walk is emptied' \
    'REFUSE' "$NAIVE_NOWALK"
# AND THE STATE THE WITHDRAWAL DOES REACH, emptied in the file rather than after
# the source, says which variable it withdrew for. The merge of dev-05 at 5d95c8a
# brought #134.1's rule that a withdrawal names its cause; its derivation read
# this guard and found it silent. This drives it: the assignment is emptied and
# the old program left behind as the argument of a `:`, so the library loads
# with CS_GH_AWK empty and nothing else changed.
req GH-118
sed "s/^CS_GH_AWK='\$/CS_GH_AWK=; : '/" "$HOOKS/lib/command-scan.sh" \
  > "$FIXTURES/emptywalk-gh-awk.sh"
R118_EMPTYWALK_SAYS=$(bash -c ". '$FIXTURES/emptywalk-gh-awk.sh'; command -v cs_gh_args >/dev/null && echo present || echo absent" 2>&1)
tok 'an emptied CS_GH_AWK in the file withdraws cs_gh_args, and says it is CS_GH_AWK' \
    'lib/command-scan.sh: CS_GH_AWK is empty. cs_gh_args and cs_gh_opaque are withdrawn, so every consumer that requires them refuses.|absent' \
    "$(printf '%s' "$R118_EMPTYWALK_SAYS" | tr '\n' '|')"

# AND THE OTHER POLARITY, which the three above say nothing about and which the
# first version of this section claimed they did. A caller whose MATCH grants
# something reads the same default the other way round: "cannot tell" spelled as
# success is a granted read, and a cs_gh_opaque that is not there answers 127,
# which `&& return 1` reads as "readable" and lets through. release_is_read in
# no-pr-decisions.sh is the only caller of that shape in this repository, and it
# reads the status as 1-or-nothing so that both cases withhold the read. These
# drive its two lines rather than the hook, since the hook's own load guard
# refuses before either is reached and would hide the property being claimed.
GRANT_CALLER='
  read -r CMD
  cs_gh_opaque "release view" <<<"$CMD"
  case $? in 1) ;; *) echo WITHHOLD; exit ;; esac
  if cs_gh_args "release view" <<<"$CMD" >/dev/null; then echo GRANT; else echo WITHHOLD; fi'
GRANT_READ=$(printf 'gh release view v1\n' \
  | bash -c ". '$HOOKS/lib/command-scan.sh' && $GRANT_CALLER" 2>/dev/null)
GRANT_EATS=$(printf 'gh release -t list view v1\n' \
  | bash -c ". '$HOOKS/lib/command-scan.sh' && $GRANT_CALLER" 2>/dev/null)
GRANT_NOOPAQUE=$(printf 'gh release view v1\n' \
  | bash -c ". '$HOOKS/lib/command-scan.sh' && unset -f cs_gh_opaque && $GRANT_CALLER" 2>/dev/null)
tok 'the granting shape still grants an ordinary release read' \
    'GRANT' "$GRANT_READ"
tok 'and withholds it from a command whose verb was eaten' \
    'WITHHOLD' "$GRANT_EATS"
tok 'and withholds it when cs_gh_opaque is gone, where && return would grant' \
    'WITHHOLD' "$GRANT_NOOPAQUE"
# The three above drive that SHAPE and not the file, so on their own they would
# pass with the hook written the other way. This is the line itself, whole: the
# two arms of the case and the order they stand in. `&& return 1` and
# `case $? in 0) return 1 ;; esac` both satisfy the verdict checks above, since
# the two differ only when the call does not run -- so nothing but the text says
# which of them is there.
armed 'and release_is_read reads that status as 1-or-nothing, in the file' \
      "$HOOKS/no-pr-decisions.sh" 'case $? in 1) ;; *) return 1 ;; esac'

# cs_gh_args ANSWERS ABOUT THE FIRST LINE IT CAN DECIDE, since #118, which is
# not the sentence the tokeniser section of the unsplit file pins as `the first
# match only, and the rest unseen`: an unreadable line decides too, and the match
# after it is never reached. Review round 1 found the two first-match checks there
# passing only because their first lines happen to be readable, so the half that
# changed was pinned by nothing. Not live in any hook -- every caller feeds one
# command at a time -- which is exactly why it needs a check rather than a caller.
# It stood beside those two until the suite was split, and is here because #118's
# work wrote it.
req GH-118
tok 'gh args, an unreadable earlier line decides, and the match after it is unseen' '' \
    "$(printf 'gh pr --json title view 5\ngh pr create --base dev-05\n' | cs_gh_args 'pr create')"
if printf 'gh pr --json title view 5\ngh pr create --base dev-05\n' | cs_gh_args 'pr create' >/dev/null; then
  tok 'and it succeeds there, so a caller reads cannot-tell and not not-a-match' 'cannot tell' 'cannot tell'
else
  tok 'and it succeeds there, so a caller reads cannot-tell and not not-a-match' 'cannot tell' 'not a match'
fi

# ROUND 1 OF REVIEW: TWO SPELLINGS OF THE VERY COMMAND THIS REFUSES, both
# measured permitted on the first version of #118 and on dev-05.
#
# THE FIRST IS A FRAGMENT, NOT A COMMAND. cs_split cuts at a backtick, so
# ``gh pr -t `echo view` merge 5`` reaches cs_gh_opaque as `gh pr -t`, where the
# option is the last token. The walk had an exemption for that position -- "a
# token with no blank behind it consumes nothing" -- which is true of a command
# and false of a fragment, and the exemption is gone. The $( ) spelling of the
# same command was already refused, its fragment ending `gh pr -t $`, so the two
# spellings of one command disagreed; that pair is why it is a defect rather
# than a shortfall.
req GH-118 US-15
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an option made last by a backtick, then a merge' \
  'gh pr -t `echo view` merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'the same, with the group inside the substitution' \
  'gh -t `echo pr` pr merge 5'
check_in "$SUITE_DIR" no-pr-decisions.sh BLOCK 'and the $( ) spelling, which was already refused' \
  'gh pr -t $(echo view) merge 5'
# THE SECOND IS A SPELLING OF THE OPTION. The walk tested the raw first
# character for a dash, so a quote or a backslash in front of the option ended
# it. All three of these reach gh as `gh pr -t view merge 5`, which merges.
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'the option double quoted, then a merge' \
  'gh pr "-t" view merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'the option single quoted, then a merge' \
  "gh pr '-t' view merge 5"
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'the option behind a backslash, then a merge' \
  'gh pr \-t view merge 5'
req GH-118 FR-15 FR-16
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a quoted option before a create naming main' \
  'gh pr "-t" view create --base main --title x'
req GH-118 FR-17
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a quoted option before a retarget to main' \
  'gh pr "-t" view edit 35 --base main'
# The release arm was already closed against this, by the read allowlist rather
# than by the walk: the eaten word is not a read verb. Kept because it is the
# contrast that says the pr arm was failing open where this one failed closed.
req GH-118 FR-48 US-15
check_in "$SUITE_DIR" no-pr-decisions.sh BLOCK 'the quoted option before a release create, already refused' \
  'gh release "-t" list create v1'
#
# ROUND 2: THE SAME FRAGMENT DEFECT, LEFT STANDING FOR THE THREE OPTIONS THE
# WALK RECOGNISES. Round 1 closed it for an option ghopt calls unreadable, and
# `-R`, `--repo` and `--hostname` went on consuming a value token that is not
# there -- the walk ate past the end of the fragment, the line went empty, the
# path did not match, and the caller read "not this path" and permitted. The
# shell ran a real merge. Measured on dev-05 and on the round-1 commit alike.
#
# The two spellings of the cut leave different fragments, which is why both are
# here: a backtick leaves the option last with nothing behind it, and $( leaves
# a lone `$` where the value would be. Round 1's `-t` rows are refused under
# both spellings because `-t` is unreadable on sight; these are the rows where
# the option is recognised and only its value is gone.
req GH-118 US-15
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a recognised option cut from its value by a backtick' \
  'gh pr -R `echo o/r` merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'the same cut written as $( )' \
  'gh pr -R $(echo o/r) merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK '--repo cut from its value' \
  'gh pr --repo `echo o/r` merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK '--hostname cut from its value' \
  'gh pr --hostname `echo h` merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'the same cut before the group' \
  'gh -R `echo o/r` pr merge 5'
# The release arm was closed against this input already, and by the read
# allowlist rather than by the walk. Kept as the contrast that says the pr arm
# was failing open where this one failed closed -- the asymmetry this file
# calls a defect wherever else it appears.
req GH-118 FR-48 US-15
check_in "$SUITE_DIR" no-pr-decisions.sh BLOCK 'the same cut on a release create, already refused' \
  'gh release -R `echo o/r` create v1'
# ROUND 3: THE GUARD ITSELF COMPARED ITS STUMP AS RAW TEXT. The option token
# went through ghreduce and the stump did not, so Class B reappeared inside the
# fix for Class A: quote the substitution and the stump is `"$` rather than `$`,
# the guard missed it, and the unquoted spelling of one command was refused
# while the quoted spelling was permitted. Each of these reaches gh as a merge
# of PR 5 -- measured with a shim on PATH printing its argv, under a name that
# is not `gh`, so that nothing here could reach the real one.
req GH-118 US-15
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a quoted $( ) stump before a merge' \
  'gh pr -R "$(echo o/r)" merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a quoted backtick stump, which reduces to nothing' \
  'gh pr -R "`echo o/r`" merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'the --repo spelling of the quoted stump' \
  'gh pr --repo "$(echo o/r)" merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'the quoted stump before the group' \
  'gh -R "$(echo o/r)" pr merge 5'
# AND THE ROW THAT SAYS WHY THE RULE IS NOT A LIST OF STUMPS. Reducing the stump
# and testing it for `$` or emptiness -- the fix round 3 proposed and measured --
# closes the four above and leaves this one, which is a real merge: the shell
# hands gh `foobar` as the repository and runs `merge 5`. The stump here is
# `foo$`, which is neither. What every stump has in common is that the cut left
# an unfinished word, so that is what the guard tests.
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a stump with text in front of it, which no list catches' \
  'gh pr -R foo$(echo bar) merge 5'
# Process substitution, which round 3 left to judgement: gh rejects /dev/fd/63
# as a repository, so these buy a broken command rather than a merge. They are
# closed anyway, because deciding stump by stump which ones matter is the list
# the rule above exists instead of.
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a <( ) stump before a merge' \
  'gh pr -R <(echo o/r) merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a >( ) stump before a merge' \
  'gh pr -R >(echo o/r) merge 5'
# An expansion cs_split does NOT cut leaves the whole command visible, so the
# value is a value and the walk reads the verb behind it. ${X} was refused
# before this guard existed; $((1)) was permitted, and is refused now because
# its cut leaves a `$` like any other.
req GH-118 US-15
check_in "$SUITE_DIR" no-pr-decisions.sh BLOCK 'a ${ } value, uncut, and the merge behind it' \
  'gh pr -R ${X} merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an arithmetic expansion, whose cut leaves a $ too' \
  'gh pr -R $((1)) merge 5'
# THE SHAPE THIS STILL LEAVES, pinned as permitted rather than described. A
# quoted value containing whitespace is several tokens to this walk, so the
# stump test never sees the span as one word: `-R` takes `'"'"'$(echo` and the rest
# of the span stays in the line. gh receives the literal text as a repository
# and rejects it, so it buys a broken command and not a merge -- the same
# third-order class as <( ) and, unlike that one, not closed by the rule above.
# Permitted at dev-05 too.
req GH-118 US-13
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'BOUNDARY: a quoted value holding whitespace, several tokens here; #194' \
  'gh pr -R '"'"'$(echo o/r)'"'"' merge 5'

# ROUND 5: THE SAME CUT IN THE OTHER PLACE A VALUE IS WRITTEN. Rounds 2 and 3
# asked whether a value was cut off only where it is the NEXT word; a value
# carried in the option's own token -- `--repo=o/r`, `--hostname=h`, `-Ro/r`,
# `-R=o/r` -- went through unasked, so `--repo=$` ended the fragment, no path
# word followed, and every rule read "not this path". Each of these reaches gh
# as the decision it names; `-R $(echo o/r)`, the separate spelling of the
# first, was already refused, so two spellings of one command disagreed. Each
# was PERMITTED at a6a0ffd and at dev-05 5d95c8a, measured by feeding the hook.
# The fix is one test, `unfinished`, asked at both places, not a second copy.
req GH-118 US-15
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an attached --repo= value cut by $( ), then a merge' \
  'gh pr --repo=$(echo o/r) merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an attached --repo= value cut by a backtick, leaving it empty' \
  'gh pr --repo=`echo o/r` merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'the attached shorthand, the substitution quoted' \
  'gh pr -R"$(echo o/r)" merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'the attached shorthand before the group' \
  'gh -R$(echo o/r) pr merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'the -R= spelling, which pflag reads as -R' \
  'gh pr -R=$(echo o/r) merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a quoted backtick in an attached value, which reduces to nothing' \
  'gh pr --repo="`echo o/r`" merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an attached stump with text in front of it' \
  'gh pr --repo=foo$(echo bar) merge 5'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an attached <( ) stump' \
  'gh pr --repo=<(echo o/r) merge 5'
req GH-118 FR-15 FR-16
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an attached --hostname= stump before a create naming main' \
  'gh pr --hostname=$(echo h) create --base main --title x'
req GH-118 US-15
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an attached --hostname= stump before an api merge' \
  'gh --hostname=$(echo h) api -X PUT repos/o/r/pulls/5/merge'
# The message is the unreadable one, which is the one that names a correction.
req GH-118 US-7
says "$SUITE_DIR" no-pr-decisions.sh 'option before its subcommand' \
  'an attached stump is refused as unreadable, not as a merge' \
  'gh pr --repo=$(echo o/r) merge 5'
# THE TRADE, and it is the only refusing-direction flip here: an attached value
# that is empty as written, not by a cut, is refused with the cut ones, since
# after reduction the two are one token. It names no repository.
req GH-118 US-13
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'THE TRADE: --repo= with nothing after it, before a read' \
  'gh pr --repo= view 5'
# And what the test must not cost: a finished attached value, in every spelling,
# before a read. `$X` is a finished word to this walk -- cs_split does not cut
# at a parameter -- so it is read as a value like any other.
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'an attached --repo= value before a read' \
  'gh pr --repo=o/r view 5'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'the -R= spelling before a read' \
  'gh -R=o/r pr view 5'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'an attached --hostname= value before a read' \
  'gh --hostname=h pr view 5'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'an attached parameter, uncut, before a read' \
  'gh pr --repo=$X view 5'
req GH-118 FR-48
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'an attached --repo= value before a release read' \
  'gh release --repo=o/r view v1'

# AND WHAT THE k==1 GUARD MUST NOT REFUSE: a fragment that ends after a value it
# really has. `gh release -R o/r` is the whole of its command, gh runs no verb
# for it, and the release allowlist refuses it with the message naming the five
# reads. That is the right message; "move the option after the subcommand"
# would name a subcommand that is not there. The verdict is pinned where the
# rule is stated, and the MESSAGE is what this says.
req GH-118 GH-97.2 US-7
says "$ON_DEV" no-pr-decisions.sh 'Reading one is permitted' \
  'a valued option ending its own command keeps the release message, not the unreadable one' \
  'gh release -R o/r'
says_not "$ON_DEV" no-pr-decisions.sh 'option before its subcommand' \
  'and is not told to move an option after a subcommand it does not have' \
  'gh release -R o/r'
req GH-118 US-13
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'a valued option with its value, before a read' \
  'gh release -R o/r view v1'

# WHAT THE FIXES STILL LEAVE, pinned as permitted so the boundary is evidence
# rather than a sentence. None of it is #118 to answer and all of it is
# unchanged from dev-05. It is not counted here: the count went stale as the
# list grew, round 4 of the review adding two rows and round 5 more, which is
# also why the list is derived from probes rather than written from memory of
# what was fixed.
#
#   - a quoted PATH WORD. Only the option spelling is reduced, deliberately:
#     the reducer that would read `"pr"` as `pr` is cw_reduce, which also takes
#     a path to its basename and would read `--repo=o/r` as `r`. `gh "pr" merge
#     5` is permitted at dev-05 too and is GH-135.
#   - an option inside a command substitution. cs_split cuts there, so the
#     option is in a fragment of its own and no walk sees it at all. That is
#     CLAUDE.md deliberately-left-open consequence 4 and 6, and closing it means
#     resolving a substitution from text, which cannot be done.
#   - a BACKTICK cutting an option VALUE, which leaves no stump to test.
#     `gh pr -R foo` + backtick + `echo bar` + backtick + ` merge 5` arrives as
#     the fragment `gh pr -R foo`, and `foo` is a finished word, so the round-3
#     rule cannot reach it. gh receives [pr] [-R] [foobar] [merge] [5] -- a real
#     merge. The $( ) spelling of the same command IS refused, its cut leaving
#     `foo$`. It is reachable -- refusing when the line runs out immediately
#     after a value closes it -- and measured, the whole cost is the two message
#     checks above, `gh release -R o/r` losing the refusal that names the five
#     read verbs. It is left open because of the row below it.
#   - the same cut inside a PATH WORD, which defeats the rule outright:
#     `gh pr mer` + backtick + `echo ge` + backtick + ` 5` reaches gh as
#     [pr] [merge] [5]. This is GH-135's family in its split spelling where the
#     entry has the quoted one, and no amount of option-value work reaches it.
#     #197.
#   - an option in ANSI-C or locale quotes, `$'-t'` or `$"-t"`. ghreduce takes
#     the quotes out and leaves the `$`, so the token opens with `$` rather than
#     a dash, the walk stops and reads it as a path word, and the path does not
#     match. gh receives [-t] and runs the merge. #166 owns these quotes at
#     every position -- the command word, the group, the verb, an option -- and
#     reducing them here alone would be a third reducer beside cw_reduce and
#     ghreduce answering one question. Round 5 of the review.
#
# WHY THE THIRD IS LEFT OPEN, since it is the one this branch could have closed.
# The fourth is strictly EASIER to write than the third and is unreachable by
# the same means, so closing the third buys nothing against the same hand, and
# costs two pinned checks about a refusal's message. CLAUDE.md's stated model is
# stop mistakes, not adversaries: nobody writes either by mistake. So the two
# belong in one fix or neither, which is what #197 says and why it carries both.
req GH-118 US-13
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'BOUNDARY: a quoted group word, which is #135 and not this' \
  'gh "pr" merge 5'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'BOUNDARY: the option itself inside a substitution; CLAUDE.md consequences 4 and 6' \
  'gh pr `echo -t` view merge 5'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'BOUNDARY: a backtick cutting an option value, leaving no stump; #197' \
  'gh pr -R foo`echo bar` merge 5'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'BOUNDARY: the same cut in an attached value, which leaves none either; #197' \
  'gh pr --repo=foo`echo bar` merge 5'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'BOUNDARY: an option in ANSI-C quotes; #166' \
  "gh pr \$'-t' view merge 5"
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'BOUNDARY: an option in locale quotes; #166' \
  'gh pr $"-t" view merge 5'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'BOUNDARY: an option in ANSI-C quotes before the group; #166' \
  "gh \$'--squash' view pr merge 5"
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'BOUNDARY: the same cut inside a path word; #197' \
  'gh pr mer`echo ge` 5'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'BOUNDARY: the same cut inside the group word; #197' \
  'gh p`echo r` merge 5'
# And the contrast that says the third row is a gap in the rule rather than the
# rule working: the $( ) spelling of that same command leaves `foo$`, which IS
# a stump, and is refused.
req GH-118 US-15
check_in "$SUITE_DIR" no-pr-decisions.sh BLOCK 'and the $( ) spelling of that same command, which leaves a stump' \
  'gh pr -R foo$(echo bar) merge 5'
# The two gh root flags, permitted because ghopt recognises them: dropping the
# last-token exemption would otherwise have refused a command written 23 times
# in the 100,929-command corpus. `gh pr --help` is the same flag one level in.
req GH-118 US-13
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'gh --version, still permitted' 'gh --version'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'gh --help, still permitted' 'gh --help'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'gh pr --help, still permitted' 'gh pr --help'
# ROUND 7: `--version` IS THE ROOT'S AND NOT A GROUP'S. The comment above says
# `gh pr --help` is "the same flag one level in", and that is true of --help,
# which gh makes persistent, and was read as true of --version, which is not:
# cobra adds it to the root's own flags, so below the root it is an option gh
# cannot look up, and it eats the next word. Measured by the review on gh
# 2.45.0 -- `gh release --version view --help` prints release usage with
# `unknown flag: --version`, where `gh release --help view --help` prints view's
# -- and read in cobra v1.8.1's InitDefaultVersionFlag, which uses c.Flags() and
# not PersistentFlags(). Each of these was PERMITTED at 9cbeda2 and at dev-05,
# the first granted as a release read. gh rejects the flag in its second step,
# so none runs today; that step is the one the rule does not model.
req GH-118 FR-48 US-15
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK '--version below the root eats the read verb, then a release delete' \
  'gh release --version view delete v1 --yes'
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK '--version below the root, then a release create' \
  'gh release --version list create v1'
req GH-118 US-15
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK '--version below the root, then a merge' \
  'gh pr --version view merge 5'
# THE TRADE, in the refusing direction: `gh pr --version` is refused as
# unreadable, where it was permitted. gh rejects it too.
req GH-118 US-13
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'THE TRADE: --version below the root, alone' \
  'gh pr --version'
# And what does not move: --version at the root, and --help at any level.
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW '--version at the root, before a read' \
  'gh --version pr view 5'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW '--help below the root takes no word, so the read after it is read' \
  'gh release --help view v1'
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW '--help before an eaten-looking verb resolves the view, not the merge' \
  'gh pr --help view merge 5'
req GH-118 US-15
check_in "$SUITE_DIR" no-pr-decisions.sh BLOCK '--version at the root, and the merge behind it is read' \
  'gh --version pr merge 5'

# THE ONE LIST, derived off the library and held to a literal. Round 1 of the
# review found this section asserting that the classification was written once
# while `cs_gh_args` carried the same three names again in its own skip list;
# the two functions are one awk program now, so there is one list and this is
# what says so. The literal is the recognised set: the three that name where a
# command acts, and the two root flags that `gh help` prints, which are here
# because dropping the last-token exemption would otherwise refuse
# `gh --version` -- 23 of those in 100,929 Bash commands from 861 local
# transcripts.
#
# Derived rather than listed, so a fourth name added to ghopt is red here
# whatever the comment beside it says. The second half asserts there is no
# second list: `skipopts` was where the other copy lived, and cs_gh_args no
# longer has an awk program of its own to put one in.
req GH-118
tok 'ghopt recognises exactly -R, --repo, --hostname, --version and --help' \
    '--help --hostname --repo --version -R' \
    "$(sed -n '/function ghopt(t) {/,/^  }/p' "$HOOKS/lib/command-scan.sh" \
       | grep -oE '\-\-?[A-Za-z][-A-Za-z]*' | LC_ALL=C sort -u \
       | tr '\n' ' ' | sed 's/ $//')"
tok 'and no second list of them survives in a gh skipopts call' \
    '0' "$(grep -c 'skipopts("|-R' "$HOOKS/lib/command-scan.sh")"

# WHICH REFUSAL, which is the whole of what the unreadable pass in the hook
# adds. The third outcome above already refuses these commands without it -- an
# unreadable command succeeds at every path, so `gh_rule 'pr merge'` matches and
# the decision rule speaks. That refusal is wrong about the command in front of
# it: `gh --squash view issue list` decides no pull request, and being told that
# deciding one is Bertan's call names no correction its writer can act on. So
# the verdict checks above cannot see this loop at all, and only these can.
# #105 owns the rule that a refusal names the permitted spelling.
req GH-118 US-7
says "$SUITE_DIR" no-pr-decisions.sh 'option before its subcommand' \
  'the refusal names the cause, not a pull request decision' \
  'gh pr -t view merge 5'
says "$SUITE_DIR" no-pr-decisions.sh 'gh pr view 5 --json title, gh release list --limit 5' \
  'and names where the option goes instead' \
  'gh release -t list create v1'
# AND EVERY SPELLING IT NAMES IS ONE THAT PASSES, which the first version of
# the message broke: its first example was `gh pr merge 5 --squash`, a merge,
# so an agent that followed it was refused again, by the merge rule. Both
# refusals were true, and US-7 asks for a spelling that passes (round 7 of the
# review). So the examples are read out of the refusal as the hook prints it,
# and each is fed to the hook and must be permitted -- a wrong example added
# later is red here, where a `says` on the text would stay green.
req GH-118 US-7
R118_ADVICE=$(jq -n --arg c 'gh release -t list create v1' '{tool_name:"Bash",tool_input:{command:$c}}' \
  | (cd "$SUITE_DIR" && bash "$HOOKS/no-pr-decisions.sh" 2>&1 >/dev/null) \
  | sed -n 's/.*Move the option after the subcommand: \([^.]*\)\..*/\1/p')
# An empty read is a FAILING CHECK here and not a stopped run, which the first
# version of this was: under a mutant that stops a command being unreadable,
# the refusal is another rule's, nothing is read, and an `exit 1` turned the
# whole run into one the harness cannot count -- `gh-option-never-unreadable`
# reported did-not-complete instead of caught. The count below is 0 then, and
# red, which is the answer; the loop after it runs no check.
tok 'the unreadable refusal names two corrected spellings' \
    '2' "$(printf '%s\n' "$R118_ADVICE" | tr ',' '\n' | grep -c .)"
while IFS= read -r r118_example; do
  r118_example=${r118_example# }
  check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW "the refusal's corrected spelling passes: $r118_example" \
    "$r118_example"
done < <(printf '%s\n' "$R118_ADVICE" | tr ',' '\n')
says "$SUITE_DIR" no-pr-decisions.sh 'option before its subcommand' \
  'and reaches a group no rule here guards, where the decision message would lie' \
  'gh --squash view issue list'
says_not "$SUITE_DIR" no-pr-decisions.sh 'deciding a pull request' \
  'and does not tell an unreadable issue command that it decides a pull request' \
  'gh --squash view issue list'

# CLAUDE.md RECORDS THE TRADE, as its ninth deliberately-left-open consequence.
# Round 5 of the review found the refused reads recorded in the library and in
# GH-118's entry and nowhere in the document that grants them: CLAUDE.md grants
# reading a pull request "through `gh pr view`", and its consequence 2 says this
# hook asks only for the `pr|release|api` group, while `gh pr --json title view
# 5` and `gh --paginate issue list` are both refused. Consequence 1 is the
# precedent -- a refused read the paragraph grants gets a numbered entry. The
# count at the head of the list is held to the items by #73's check; these hold
# the item to the spellings it names, and the verdict each names is pinned.
req GH-118 US-13
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an unreadable option before an unguarded group, the one CLAUDE.md names' \
  'gh --paginate issue list'
# READ AS A REFLOW, NOT AS LINES. `holds` is a substring match, and the section
# as written holds each pinned phrase on one line only by where the wrap fell:
# round 7 of the review rewrapped item 9, changing no word, and the longhand pin
# went red. So the section goes through comment_reflow, #157's reader for the
# dev-log README, which joins the lines and squeezes the blanks. Its one
# difference from a plain join is that it takes a `#` off a line OPENING with
# one, and item 9 has a line holding `#118,` -- indented three spaces as a list
# continuation, so the `^#` it strips never matches there; a `#` pushed to
# column 0 would lose its mark and turn a pin red, never green. The same raw
# shape in the other pins over CLAUDE.md is #192's class, and is on #192.
R118_LEFT_OPEN=$(awk '/^\*\*Deliberately left open\.\*\*/ { f = 1 } f && /^## / { exit } f' \
  "$SUITE_DIR/../../CLAUDE.md" | comment_reflow)
holds 'CLAUDE.md names the refused pull request read as a left-open consequence' \
  "$R118_LEFT_OPEN" '`gh pr --json title view 5` although the paragraph above grants'
holds 'and the refused read of a group no rule guards' \
  "$R118_LEFT_OPEN" '`gh --paginate issue list` is refused although'
holds 'and the one edit that corrects both' \
  "$R118_LEFT_OPEN" '`gh pr view 5 --json title`'
# And the mechanism, since it is the sentence a narrowing of the rule would cite.
# It said "a shorthand it does not know" until round 6 of the review, the reading
# that an unknown longhand eats nothing, which gh 2.45.0 and cobra's stripFlags
# both contradict; the longhand flips above pin the verdicts, and this the
# document's account of them.
holds 'and says a longhand eats the next word as a shorthand does' \
  "$R118_LEFT_OPEN" 'longhand or shorthand, or one taking a value, eats the next word'

# THE GIT HALF, which is a different defect wearing the same shape. git rejects
# an unknown global option itself -- `git --bogus push origin main` exits with
# `unknown option: --bogus` -- so git has no "an unknown option eats the next
# word" problem. What it had is a list two entries short. cs_git_args skipped
# git's value-taking globals, and `--config-env` and `--attr-source` were not
# among them, so their value was read as the subcommand and the push behind it
# was seen by no hook. Measured on git 2.43.0, by running
# `git <option> <value> version` for every option `git help git` lists: seven
# take a separate value, and these are the two that were missing.
req GH-118 FR-3 US-1
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'git --config-env hid a push to main' \
  'git --config-env x.y=HOME push origin main'
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'git --attr-source hid a push to main' \
  'git --attr-source HEAD push origin main'
req GH-118 FR-3 US-2
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'git --config-env hid a push --all' \
  'git --config-env x.y=HOME push --all origin'
# The `=` spellings were refused all along: a token carrying its own value is
# skipped as a valueless option and the subcommand behind it is reached. They
# are pinned so that a later edit to the list cannot take them with it.
req GH-118 FR-3 US-1
check_in "$PUSH_WT" no-git-push.sh BLOCK 'the = spelling of --config-env, refused already' \
  'git --config-env=x.y=HOME push origin main'
check_in "$PUSH_WT" no-git-push.sh BLOCK 'the = spelling of --attr-source, refused already' \
  'git --attr-source=HEAD push origin main'
# The same two options in front of the commit hook's own verbs, on main.
req GH-118 US-1
flip "$ON_MAIN" no-commit-to-main.sh ALLOW BLOCK 'git --config-env hid a commit on main' \
  'git --config-env x.y=HOME commit -m wip'
flip "$ON_MAIN" no-commit-to-main.sh ALLOW BLOCK 'git --attr-source hid a commit on main' \
  'git --attr-source HEAD commit -m wip'
# And what the two entries must not cost: an ordinary read behind either of them,
# and the globals that were in the list before.
req GH-118 FR-3
check_in "$PUSH_WT" no-git-push.sh ALLOW 'git --attr-source HEAD status' \
  'git --attr-source HEAD status'
check_in "$PUSH_WT" no-git-push.sh ALLOW 'git --config-env x.y=HOME status' \
  'git --config-env x.y=HOME status'
check_in "$PUSH_WT" no-git-push.sh ALLOW 'git -C . status, unmoved' 'git -C . status'
check_in "$PUSH_WT" no-git-push.sh ALLOW 'git -c x.y=z log, unmoved' 'git -c x.y=z log'

sourced_to_end

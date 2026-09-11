#!/bin/bash
# Where a command starts, where its arguments end, and how many commands a
# string holds. Sourced by no-git-push.sh, no-pr-decisions.sh, and since issue
# #43 no-commit-to-main.sh and since #44 no-work-on-stale-branch.sh -- which is
# every hook that reads a command. Issue #63 found this line naming three of the
# four, the same way it found CLAUDE.md's boundary section naming two of them: a
# hook is added, and the sentence saying which hooks there are is not revised
# with it.
#
# This exists because of what the defects in PR #35 turned out to have in
# common. Every one of them, found by Bertan or by the assistant, was the same
# question answered differently in a different place -- how far around a matched
# token to look:
#
#   - the anchor required column zero, so an indented command was not a command
#   - wrapper re-admission sufficed for a heredoc and did nothing for sh -c
#   - the option scope was the whole line, so `ls --all && git push` read as --all
#   - narrowing it to one command cut at a newline, so a backslash continuation
#     made every push look bare, which is the permitted shape
#   - and it found the first command only, so a second one after ; or && was
#     never examined at all
#
# Two of those were introduced by the fix to the previous two. The rule was
# re-derived in about a dozen regular expressions across two files, so fixing it
# in one place kept opening it in another. It is derived once here instead, and
# the check suite points at these functions directly.
#
# A second review found three more of the same shape, and all three were here
# rather than spread across the hooks, which is the point of the file. Two were
# the heredoc question answered too loosely -- a here-string read as a heredoc,
# and a tab-indented <<- terminator never recognised, so that heredoc never
# ended. One was the command-position question answered too narrowly: a command
# after `then`, `do`, `else`, `{` or `!` is at a command position and was not
# treated as one. Each of the three hid every command that followed it.
#
# A third review found the heredoc question wrong a third time, and that is the
# number that settled it. `git commit -m "fix <<EOF handling"` contains no
# heredoc -- inside double quotes `<<` is text -- and the rest of the command
# was dropped. Three wrong answers, each silent and each in the permitting
# direction, is evidence about the question rather than about the answers: it
# cannot be got exact by looking more carefully, because that is what the
# previous two attempts were. The drop is a fail-safe now. See cs_normalise.
#
# A fourth review, of the #43 migration, found two more -- both the same shape
# as the first three, and both here rather than in a hook. A wrapper word was
# stripped along with its options but not its operand, so `timeout 30 git push
# --all origin` left a bare `30` where the command word had to be; and sudo,
# doas, setsid and chronic were not wrapper words at all. Separately,
# cs_git_args skipped git's own --git-dir, --work-tree, --namespace and
# --exec-path only in their = spelling, so the separated form hid the
# subcommand behind its own value and `git --namespace n push origin main` was
# not a push. Every one was silent, in the permitting direction, and invisible
# to all three hooks at once. That is what this file is for and also what it
# keeps costing: the question is answered once, so an answer that is wrong is
# wrong everywhere.
#
# The answers are approximate on purpose. Splitting more eagerly than a shell
# would yields extra command candidates, which can only refuse more; it never
# hides one. That is the safe direction for a guard whose failure mode, twice
# now, has been to report the permitted answer.
#
# A fifth review, of dev-05, found the first defect here that costs only
# refusals -- and it costs them on the work of editing these files. cs_split cut
# on separators with a plain character class that knew nothing about quoting, so
# a | inside a quoted argument was a fragment boundary like any other. `sed -i
# 's|git push --all origin|X|' f.sh` yielded four fragments, the second of which
# is a push standing at the head of its own line, and both no-git-push.sh and
# no-commit-to-main.sh refused it. Six ordinary sed and grep commands were
# refused this way, and it fired twice in a live session against that session's
# own edits to these hooks. Worse than the refusal is that it reads as
# arbitrary: the fragment has to BEGIN with the command word, so `s|^git push|`
# is permitted and `s|git push|` is not, on a difference that has nothing to do
# with what either command would run. Issue #68 made the pass quote-aware; the
# reasoning, and the three ways that fix could itself have become a hole, are in
# the comment inside cs_split.
#
# The permitting direction was swept before that fix and not found, and the
# structural reason is worth writing down so it is not re-derived. Splitting
# never deletes text, it only inserts boundaries, so every "is X present in any
# fragment" test still sees every character it saw before. The only way a cut
# can hide evidence is by truncating a verb's argument list, and neither hook
# judges a verb that way: no-commit-to-main.sh refuses `git commit` on main
# whatever the arguments, and no-git-push.sh refuses on flags -- --all, --mirror,
# -f, --delete -- that cannot sit behind a quoted free-text argument, because
# `git push` has no -m-style slot to put one in.
#
# That argument is about the hooks whose fragments TRIGGER a refusal, and it was
# written as though those were all of them. no-work-on-stale-branch.sh is the
# fourth consumer and the exception: its fragment tests withdraw a carve-out
# rather than raise a refusal -- `^(cd|pushd|popd)`, the git directory options,
# and a checkout or switch each set CARVE= -- so there, losing a fragment head
# RETAINS an exception instead of dropping a refusal, and "a cut can only refuse
# more" does not transfer to it as written. Found by review of this change, not
# by the suite.
#
# It is nonetheless safe, for a reason that belongs here rather than in that
# file. A fragment that quote-awareness removes is one bash would never have run
# as a command, so a carve-out retained past it is retained for a command that
# does not change directory. The converse -- a real cd that the tracker now
# hides -- has nowhere to happen: a cd bash would run sits either outside quotes,
# where it is still cut, or inside a substitution, which sends the whole line to
# the fallback. The fail-safe is what carries this case, exactly as it carries
# the others; the difference is only that here it is load-bearing rather than
# belt-and-braces.
#
# One verdict there did change, and it is worth naming because the shape is not
# the obvious one. The catch-up merge carries no free-text argument that could
# hold a quoted cd -- -m withdraws the carve-out by itself -- so what reaches
# this is a quoted separator in a SIBLING command on the same line:
# `git merge origin/dev-05 && echo 'x; cd /tmp'` was refused for a directory
# change bash would never have made, and is permitted now. An unquoted cd still
# withdraws the carve-out. Both are checks.
#
# One soft spot, named rather than closed. no-git-push.sh:153 records that "an
# empty argument list is the permitted case", so a push whose arguments were
# lost past a cut would read as a bare push. Probed with `git push "|--all
# origin"` and `git push "x|--all" origin`: both still blocked. It holds --
# but it holds because of a property of git push's own CLI, not because of
# anything this library does, so the honest phrasing is SWEPT AND NOT FOUND,
# never "cannot happen". Any future hook that judges a verb by a free-text
# argument reopens the question.
#
# A sixth review, of that fix, found the list of prefix words known in one half
# of this library and invisible in the other. cs_split had stripped sudo, env,
# xargs, timeout and the rest since the fourth review; the four wrapper regexes
# in the hooks never consulted it, so `sudo git push --all origin` was refused
# and `sudo sh -c 'git push --all origin'` was not. One question, two places,
# two answers -- which is the sentence this header opens with. It is one layer
# out from PR #35's defect #2:
# wrapper re-admission sufficed for a heredoc and did nothing for `sh -c`, and
# then handled `sh -c` and did nothing for `sudo sh -c`. Issue #79 made the
# words a variable that both halves read, and moved the four copies of the
# wrapper expression into the one CS_WRAPPER_RE below. Where that anchor stops,
# what it cannot reach, and the soft spot it keeps are argued there.

# Reduce a raw command to lines that can be scanned: heredoc bodies dropped,
# line continuations joined, redirections dropped -- in that order, so that
# every caller gets a command whose remaining words are its arguments. Where a
# command's arguments end is the question this file exists to answer once, and
# a redirect answered it in no-git-push.sh by accident: nothing removed one, so
# `git push origin <branch> 2>/dev/null` was refused for naming 2>/dev/null as
# its refspec. See the third pass.
#
# A heredoc body is data, not commands. This repository writes dev-log entries
# and commit messages through a quoted heredoc, and those texts name the very
# commands the hooks refuse; grep anchors ^ per line, so a line of prose
# beginning with one read as a command position, and an early version of the
# hooks refused the commit that introduced them.
#
# Joining runs after dropping, so a backslash at the end of the line before a
# heredoc terminator cannot swallow the terminator and hide what follows.
#
# Dropping is the one step here that hides commands rather than exposing them,
# so what counts as a heredoc has to be exact in both directions -- and it was
# wrong in both. `<<<` is a here-string: the operator regex matched its second
# and third `<`, took the here-string's own text for a terminator that never
# arrives, and dropped the rest of the command. `<<-` lets bash strip leading
# tabs from the terminator, which an exact comparison never matched, so that
# heredoc did not end either. Either one turned a `git push --mirror` or a
# `gh pr merge` on a following line into nothing at all.
#
# Those were the second and third answers to the same question, and a fourth
# followed them: `git commit -m "fix <<EOF handling"` has no heredoc in it at
# all -- inside double quotes `<<` is text -- and the opener was matched
# anywhere on the line, quotes included. So the drop is no longer trusted to be
# right. A heredoc that never reaches its terminator was not a heredoc, and the
# lines held for it are given back at END rather than lost.
#
# That is the answer this question should have had from the start: the exact
# version has been got wrong three times, and each time the failure was silent
# and in the permitting direction. The fail-safe costs a genuinely unterminated
# heredoc being scanned as commands -- which bash would refuse to run anyway --
# and it is the direction this file takes everywhere else.
cs_normalise() {
  awk '
    ind {
      line = $0
      if (dash) sub(/^\t+/, "", line)
      held[++nheld] = $0
      if (line == d) { ind = 0; nheld = 0 }
      next
    }
    {
      # A here-string is not a heredoc. Blanked at its own width, so a real
      # heredoc later on the same line is still found where it stands.
      scan = $0
      gsub(/<<</, "   ", scan)
      if (match(scan, /<<-?[[:space:]]*[^[:space:];|&<>()]+/)) {
        d = substr(scan, RSTART, RLENGTH)
        dash = (d ~ /^<<-/)
        sub(/^<<-?[[:space:]]*/, "", d)
        gsub(/[\047"]/, "", d)
        ind = 1
      }
      print
    }
    # The terminator never arrived, so this was not a heredoc and the lines were
    # dropped in error. Give them back.
    END { for (i = 1; i <= nheld; i++) print held[i] }' \
  | cs_join \
  | awk '
    # A redirection is not an argument. Nothing removed one, so its operator or
    # its target was read as a refspec and every redirect on an otherwise
    # permitted push was refused -- `git push origin <branch> 2>/dev/null`
    # answered "This names 2>/dev/null, not <branch>". Issue #50.
    #
    # It runs last, so a redirect written across a continuation is joined before
    # it is read, and so `2>&1` is gone before cs_split reaches the & it would
    # otherwise split on. That split is what PR #48 reported as the cause; it is
    # a second effect on top of this one, and `2>/dev/null` holds no & at all.
    #
    # Where the last three defects here came from: this is the second step that
    # hides text rather than exposing it, so the two cases where hiding would
    # cost something are answered first and answered narrowly.
    #
    #   - `<(...)` and `>(...)` carry a command, which is the one thing a drop
    #     must never swallow. They are not redirections and are left whole.
    #   - a redirect inside quotes is text. A commit message naming one is the
    #     mistake the heredoc opener made three times, so quotes are tracked
    #     character by character rather than matched around.
    #   - `<<`, `<<-` and `<<<` belong to the heredoc pass above. Answering
    #     what a heredoc is a second time, here, is how the answers came to
    #     disagree in the first place; a run of two or more < is emitted whole.
    #   - the target scan stops at a backtick and at a paren, so a command
    #     substitution standing where a target would be is left standing.
    #
    # The trade, taken knowingly: a quoted redirect target -- `2> "push log"` --
    # is not consumed, so its text stays in the arguments and refuses the push.
    # That is the direction this file takes everywhere, and the targets an agent
    # actually writes (/dev/null, out.txt, push.log) carry no quotes.
    #
    # `>|` is left half-standing: the operator goes and the | does not, so the
    # target becomes a command candidate of its own. That is the over-splitting
    # this file takes everywhere -- an extra candidate can only refuse more --
    # and it is preferred to consuming a | , which is a separator everywhere
    # else and whose loss would hide the command after it.
    #
    # Quote state is per line. A string left open at a newline protects nothing
    # on the next line, which can only drop more, never less -- and dropping
    # more of a line that is already inside quotes changes no verdict, because
    # the quoted text was never a command position to begin with.
    #
    # Which leaves this pass knowing two things the passes above also know:
    # what a quote is, and what `<<` is. One answer per question is the premise
    # of this file, so that is a cost rather than an oversight. It is paid
    # because the two answers are to different questions. Pass one asks where a
    # heredoc body ends, and answers it fail-safe, by giving the lines back.
    # This one asks whether a character is text, and a fail-safe there would
    # mean dropping nothing, which is the defect being fixed. Unifying them
    # would put the heredoc fail-safe at risk to save a dozen lines.
    # BOUND is what an fd digit run may follow; STOP is that plus the quotes,
    # and ends a redirect target. STOP is derived rather than written twice, so
    # the two cannot drift apart in a later edit.
    BEGIN {
      BOUND = " \t;|&()`<>"
      STOP  = BOUND "\042\047"
    }
    {
      line = $0
      n = length(line)
      out = ""
      q = ""
      i = 1
      while (i <= n) {
        c = substr(line, i, 1)
        if (q != "") {
          if (q == "\042" && c == "\\") { out = out c substr(line, i + 1, 1); i += 2; continue }
          out = out c
          if (c == q) q = ""
          i++
          continue
        }
        if (c == "\\") { out = out c substr(line, i + 1, 1); i += 2; continue }
        if (c == "\042" || c == "\047") { q = c; out = out c; i++; continue }
        if (c != ">" && c != "<") { out = out c; i++; continue }
        nxt = substr(line, i + 1, 1)
        # Process substitution carries a command. Not a redirection.
        if (nxt == "(") { out = out c; i++; continue }
        # A run of two or more < is a heredoc or a here-string, already answered.
        if (c == "<" && nxt == "<") {
          while (i <= n && substr(line, i, 1) == "<") { out = out "<"; i++ }
          continue
        }
        # The fd, or the & of &>, sits in front of the operator and belongs to
        # it. A digit run counts only where it is a word of its own: in
        # `origin b2>f` the 2 is part of the refspec, and bash reads it that way
        # too. A single & is the & of &>; two are the separator &&, which ends a
        # command and must survive, or the command after it disappears.
        if (match(out, /[0-9]+$/) \
            && (RSTART == 1 || index(BOUND, substr(out, RSTART - 1, 1)) > 0)) {
          out = substr(out, 1, RSTART - 1)
        } else if (c == ">" && substr(out, length(out), 1) == "&" \
                   && substr(out, length(out) - 1, 1) != "&") {
          out = substr(out, 1, length(out) - 1)
        }
        sub(/[[:space:]]+$/, "", out)
        i++
        if (c == ">" && substr(line, i, 1) == ">") i++
        if (substr(line, i, 1) == "&") i++
        while (i <= n && (substr(line, i, 1) == " " || substr(line, i, 1) == "\t")) i++
        while (i <= n) {
          t = substr(line, i, 1)
          if (index(STOP, t) > 0) break
          if (t == "$" && substr(line, i + 1, 1) == "(") break
          i++
        }
        # The drop takes the whitespace on both sides of the redirect with it,
        # so what stood either side of it must not close up into one word. A
        # target that was never consumed -- a command substitution standing
        # where one would be -- is exactly where that happens.
        t = substr(line, i, 1)
        if (i <= n && out != "" && t != " " && t != "\t") out = out " "
      }
      print out
    }'
}

# Join backslash line continuations, and nothing else.
#
# The second half of cs_normalise, on its own, for a caller that needs the
# joining without the heredoc drop. no-pr-decisions.sh is one: its wrapper rules
# read raw text because cs_normalise drops heredoc bodies and `bash <<EOF` is
# itself a wrapper, so the payload would go with the body -- but grep matches
# within a line, and a continuation between a command word and its subcommand
# hid the subcommand from a rule that could not tokenise it anyway.
#
# Extracted rather than copied. A rule written twice is answered twice, which is
# the thing this file exists to stop.
cs_join() {
  awk '
    {
      line = $0
      while (line ~ /\\$/) {
        sub(/\\$/, "", line)
        if ((getline nxt) > 0) line = line nxt; else break
      }
      print line
    }'
}

# The words that run another command with their own options. Two questions are
# asked of this list, which is why it is a variable and not a regular expression
# written where it is needed: cs_split strips these to find the command word
# behind them, and CS_WRAPPER_RE below admits them in front of a wrapper.
#
# A sixth review, of #68, found the second question answered by not asking it.
# The four wrapper regexes in the hooks anchored on ^ or on a separator and knew
# nothing of this list, so sudo was recognised in one half of this library and
# invisible in the other, measured:
#
#   BLOCK   sudo git push --all origin          cs_split strips sudo, the push is at ^
#   ALLOW   sudo sh -c 'git push --all origin'  cs_split strips sudo, leaves sh -c
#                                               where no anchor admits it
#
# That is the same question answered in two places with two different answers,
# which is the defect class the header of this file opens by naming, and it is
# one layer out from PR #35's defect #2 -- wrapper re-admission sufficed for a
# heredoc and did nothing for `sh -c`, and then handled `sh -c` and did nothing
# for `sudo sh -c`. The same held for timeout, xargs, nohup and env. Issue #79.
#
# Split in two because cs_split does two different things with them: the first
# group takes options only, the second takes an operand of its own as well. The
# union is derived rather than written a third time.
CS_WRAP_OPTION_WORDS='env|command|xargs|nohup|nice|time|stdbuf|ionice|sudo|doas|setsid|chronic'
CS_WRAP_OPERAND_WORDS='timeout|flock'
CS_WRAP_WORDS="$CS_WRAP_OPTION_WORDS|$CS_WRAP_OPERAND_WORDS"

# Is there a shell wrapper at a command position? Derived once here and grepped
# by all four hooks, which each carried their own copy of it before #79 -- four
# copies of one expression, in the file whose header says that is the defect.
#
# It is matched against RAW command text, before cs_normalise and before
# cs_split, and that ordering is load-bearing: a wrapped payload sits in quotes
# where there is no command position for the tokeniser to find, and
# cs_normalise drops heredoc bodies while `bash <<EOF` is itself one of these
# wrappers, so the payload would go with the body. That is why this is an
# anchored regular expression rather than a pass over cs_split's output.
#
# Which is also why the anchor has to say what a command position is a second
# time, and what it now admits between the position and the wrapper word: an
# environment assignment, as it always did, and a prefix word from the list
# above with its options and up to three further tokens.
#
# More than one, because the operand a wrapper takes is not always one token.
# `timeout -s KILL 30 bash -c` leaves KILL and 30 once the option is consumed,
# `sudo -u root sh -c` leaves root, and `nice -n 10 sh -c` leaves 10 -- the
# separated option value, which is the case cs_split answers by offering its
# tail as further candidates rather than by trimming its head. Three rather
# than some other number because three is the bound cs_split offers that tail
# to, for this same case and this same reason. A different number here would be
# the divergence this whole change is about, arriving inside its own fix.
#
# The COUNT is what is shared, and not the token class. Review of this change
# found this paragraph claiming both, when cs_split stops its tail at a token
# opening a quote and this does not. The difference is deliberate and is argued
# at CS_WRAP_TOKEN below; what is claimed here is the bound alone.
#
# WIDENED, NOT DROPPED, and the difference is the whole of the constraint. The
# anchor cannot simply go: a wrapper word named anywhere on a line that also
# names a refused command would then refuse the line, and the shapes that
# regress are exactly the ones a session working on these hooks writes --
# `grep -rn 'sh -c .*git push' .claude/hooks/` and
# `echo 'the eval rule refuses git push' >> notes.md` are ALLOW with the anchor
# and BLOCK without it. Four such shapes are checks, and the mutant that drops
# the anchor turns exactly those red.
#
# NAMED AND NOT CLOSED. The list cannot be complete and this does not pretend
# to be. A word that runs a command and is not a prefix word is still out of
# reach: `python3 -c 'import os; os.system("git push --all origin")'` is the
# example, and `perl -e`, `find . -exec sh -c ... \;`, a make target, and a
# script written to a file and then run are the rest of the family. The
# stopping rule is the one already in these files -- a wrapper's payload is
# refused rather than parsed, and the wrapper words are the ones this library
# can already name. Everything past that is out of reach, in the manner of the
# soft spot at no-git-push.sh:153, and not a claim the set is exhaustive.
#
# ONE SOFT SPOT, named rather than closed, and it is #68's complaint reaching
# this rule. The separator class below carries its own idea of what ends a
# command and knows nothing about quoting, so a verdict still turns on a sed
# delimiter:
#
#   BLOCK   sed -i 's|sh -c git push --all|X|' f.sh   the | satisfies the anchor
#   ALLOW   sed -i 's/sh -c git push --all/X/' f.sh   same command, other delimiter
#
# Why it is left, and stated without the convenient version. The convenient
# version is that this one cannot be fixed because the rule must read raw text.
# That is not true, and writing it down would be the kind of claim this file
# keeps having to correct. cs_split is quote-aware since #68; it does NOT drop
# heredoc bodies, which is cs_normalise; and a wrapper word sits OUTSIDE the
# payload's quotes, so `bash -c '...'` and `bash <<EOF` both stand at the head
# of a fragment where an anchor at ^ would find them. Asking cs_split would
# answer the quote question here, and would answer it once.
#
# What stops it is not that it cannot work. It is that the check suite pins, as
# a property of all four files, that this rule is handed the raw command and
# not the fragments -- and inverting that is a different change from widening
# an anchor, with its own sweep to do over every shape the two texts differ on.
# Issue #79 scoped it out in as many words. So the soft spot stays, on two
# grounds that hold meanwhile: it costs refusals and never permits, and the
# refusal is visible and one edit away. It is a candidate for a ticket of its
# own rather than a limit of the design, and this paragraph is the record of
# that decision rather than of an obstacle.
#
# Widening the anchor widens this with it -- `sed -i 's|sudo sh -c git push|X|'
# f.sh` was ALLOW and is now BLOCK -- named here so that it is a known cost
# rather than a discovery. Both spellings of each pair above are checks.
#
# A token that may stand between the prefix word and the wrapper word. Not an
# option -- those are consumed by the loop in front of this one -- and anything
# else.
#
# WIDER THAN cs_split's TAIL TOKEN, deliberately, and this is the one place the
# two answers differ on purpose. cs_split stops offering candidates at a token
# that opens a quote, because what follows one is the text of an argument and
# reading text as a command is the mistake cs_normalise has made three times.
# Nothing here reads a token as a command: these are skipped, on the way to a
# wrapper word that has to appear after them. So the reason to stop does not
# transfer, and stopping anyway would narrow a guard for a reason that does not
# apply to it.
#
# Which leaves the direction as the argument, and it is the one this file takes
# everywhere: admitting a token too many can only refuse more, never hide a
# wrapper. `sudo "x" sh -c 'git push --all origin'` is refused here and offers
# no candidate in cs_split, and that asymmetry is in the refusing direction.
#
# Named because review of this change found the comment claiming the token
# classes matched when only the counts did. The counts matching is the claim;
# this paragraph is what makes the rest of it true.
CS_WRAP_TOKEN="[^-[:space:]][^[:space:]]*[[:space:]]+"

# TWO WAYS THE LIST CAN BE MISSING, and the second is the one that needed
# building for. It is the cost of making the list a variable, and it is paid
# here rather than in the hooks.
#
# If the library does not load at all, CS_WRAPPER_RE is unset, `grep -qE ''`
# matches every line, the wrapper conjunct is vacuously true, and every command
# naming a refused verb is refused. That is the direction a guard's own
# breakage has to take, and it needs nothing else.
#
# A library that LOADS with an empty list is the unsafe way round, and probing
# for the functions cannot see it: every function is there and cs_split simply
# strips no prefix, so `sudo git push --all origin` is permitted again -- the
# verdict the fourth review fixed, silently un-fixed.
#
# So the empty case is given the same answer as the missing one, in the one
# place both are decided. With either half of the list gone, CS_WRAPPER_RE is
# the empty string, every hook's wrapper conjunct is vacuously true, and each
# of the four refuses the verb it answers for. Reviewed before this was done
# and found to matter: no-git-push.sh and no-pr-decisions.sh source this file
# unguarded, so a per-hook probe would have covered two of four and left
# `sudo git push --all origin` and `sudo gh pr merge 5` permitted -- a guard
# half-fitted, which is worse than none because its own comment says it is
# fitted. The two hooks that already probe for the functions probe for the list
# too, and that is for the message rather than for the verdict: they say why
# they refused instead of refusing unexplained.
#
# Checked, not argued: check-hooks.sh builds a library with the list emptied in
# place and asks all four. Those checks have to name a command that ONLY the
# strip reaches -- written with a plain `git commit`, the stale-branch one was
# green with its own guard removed.
if [ -n "$CS_WRAP_OPTION_WORDS" ] && [ -n "$CS_WRAP_OPERAND_WORDS" ]; then
  CS_WRAPPER_RE="(^[[:space:]]*|[;&|(\`][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+|($CS_WRAP_WORDS)[[:space:]]+(-[^[:space:]]*[[:space:]]+)*($CS_WRAP_TOKEN){0,3})*((ba|z|)sh[[:space:]]+(-c|<<)|eval([^-A-Za-z0-9_]|\$))"
else
  CS_WRAPPER_RE=""
fi

# Print one command per line, with anything that precedes the command word
# removed, so a caller matches on ^ and never has to describe a command
# position again.
#
# Separators are ; && || | ( ) and a backtick. The backtick is there because
# $( ) was closed by the paren and its twin was not -- the same asymmetry
# GIT_DIR= had against --git-dir. Since issue #68 a separator inside quotes is
# not one, which is where the exceptions and the fallbacks are; the comment
# inside the function is where that is argued.
#
# Removed prefixes: environment assignments, the shell's own control words, and
# the wrapper words that run another command with their own options. A caller
# that cares about the assignments themselves must look at the un-split text;
# no-git-push.sh does, for GIT_DIR= and GIT_WORK_TREE=.
#
# The control words are here because a separator is not the only thing a command
# can follow. `if true; then git push --mirror origin; fi` splits correctly and
# still left `then` standing in front of the command word, so the anchor never
# saw a push at all; `do`, `else`, `elif`, `{` and `!` each did the same. They
# are removed rather than matched around, so every caller keeps anchoring at ^.
#
# The trade that used to be recorded here -- a quoted string holding a separator
# and then a control word in front of a refused command read as that command, so
# `git commit -m "wait; then git push --all origin"` was refused -- was paid by
# the separator pass not knowing what a quote is. Issue #68 made it know, so on
# one line that string is text again and the commit is permitted. Two checks in
# check-hooks.sh carry the flip as `(was BLOCK)`.
#
# What is left of the trade is the multi-line spelling, and it is left on
# purpose: quote state is per line, so a string left open at a newline sends
# that line to the fallback and the continuation reads as a command position.
# CLAUDE.md names that one as deliberately open, and it is the direction this
# file has taken throughout -- a blocked comment is visible and one edit away, a
# silently permitted push is neither.
cs_split() {
  awk '
    # The separator pass, quote-aware. Issue #68: it was a character class with
    # no idea what a quote is, so a sed substitution written with | as its
    # delimiter cut into four fragments, the second of which is a push that
    # does not exist, and every hook refused it. See the header of this file.
    #
    # No apostrophe appears in these comments: the program is a single-quoted
    # shell word, so one would end it. That is why the shapes are named in
    # words rather than quoted.
    #
    # Three things it must not become. It must not stop cutting after the first
    # quote -- `echo "a" | git push --all origin` is two commands and the pipe
    # is real, so a closed quote reopens the separator. It must not guess: a
    # line whose quoting does not balance is text this cannot read, and it is
    # split exactly as it was before quotes were tracked at all. Over-refusing
    # is what this ticket complains about and is still the right answer where
    # the text cannot be read.
    #
    # And -- the one that would have turned this fix into a hole -- double
    # quotes do not make text inert. `"$(gh pr merge 5)"` and a backticked span
    # inside them RUN, so protecting a double-quoted span outright would hide
    # every command written that way, silently and in the permitting direction,
    # which is the shape of nine of the defects this file has already had. A
    # line carrying either one in double quotes goes to the same fallback as
    # unbalanced quoting: split as before, and let the substitution be cut out
    # of it as it always was. That is chosen over tracking where a substitution
    # ends, which is the shell parser the stopping rule in these files refuses
    # to write -- a nested `)` would decide the verdict.
    #
    # Single quotes need no such exception: bash runs nothing inside them, so a
    # `$(` or a backtick there is text, and the fallback is not triggered by
    # one. That is what keeps the two reported shapes -- a sed substitution and
    # a grep alternation, both single-quoted -- protected.
    #
    # The fallback is this same walk with quote tracking switched off, not a
    # second encoding of the separator set. It was written as a pair of gsub
    # calls first, and that is the shape the header of this file names as the
    # reason the file exists: the same question answered in two places, so a
    # separator added to one and not the other is a defect nobody sees. With
    # `respect` off the walk reproduces the old character class exactly, and
    # the two cannot drift apart because there is only one of them.
    #
    # qopen and dq_substitution are deliberately NOT locals: they are what the
    # walk reports back about the line it just read.
    function cut(line, respect,    n, i, c, nx, out) {
      n = length(line)
      out = ""
      qopen = ""
      dq_substitution = 0
      i = 1
      while (i <= n) {
        c = substr(line, i, 1)
        if (respect) {
          if (qopen != "") {
            # Only double quotes take a backslash escape; inside single quotes a
            # backslash is a character. Same answer as cs_normalise gives, for
            # the same reason -- it is what bash does. It is read before the
            # substitution test below, so an escaped dollar-paren and an escaped
            # backtick are the text they are and do not send the line to the
            # fallback.
            if (qopen == "\042" && c == "\\") { out = out c substr(line, i + 1, 1); i += 2; continue }
            if (qopen == "\042" && (c == "`" || (c == "$" && substr(line, i + 1, 1) == "("))) dq_substitution = 1
            out = out c
            if (c == qopen) qopen = ""
            i++
            continue
          }
          # A backslash outside quotes is read so that an escaped quote does not
          # open one that never closes and send the whole line to the fallback.
          # An escaped separator still cuts, exactly as before.
          #
          # It reads one backslash at a time, so a doubled backslash in front of
          # a quote -- which in bash is a literal backslash and then a quote that
          # DOES open -- is read here as an escaped quote and no quote opens.
          # That leaves the rest of the line unprotected and splits it more, so
          # it is in the refusing direction; it is named because the sentence
          # above would otherwise read as a claim that it cannot happen.
          if (c == "\\") {
            nx = substr(line, i + 1, 1)
            if (nx == "\042" || nx == "\047") { out = out c nx; i += 2; continue }
            out = out c
            i++
            continue
          }
          if (c == "\042" || c == "\047") { qopen = c; out = out c; i++; continue }
        }
        if (c == "&" && substr(line, i + 1, 1) == "&") { out = out "\n"; i += 2; continue }
        if (c == "|" && substr(line, i + 1, 1) == "|") { out = out "\n"; i += 2; continue }
        if (index(";&|()`", c) > 0) { out = out "\n"; i++; continue }
        out = out c
        i++
      }
      return out
    }
    {
      out = cut($0, 1)
      # Quote state is per line, as it is in cs_normalise, so a string left open
      # at a newline sends that line and no other to the fallback. That is what
      # keeps the multi-line quoted string CLAUDE.md names as deliberately
      # refused still refused.
      #
      # The fallback is per line too, and so is coarser than it could be: one
      # substitution in double quotes anywhere on a line takes the whole line
      # back to the old splitting, and a sed delimiter on that same line loses
      # the fix. That is the refusing direction, and narrowing it to the span
      # would mean finding where the substitution ends, which is the parser this
      # is written to avoid.
      if (qopen != "" || dq_substitution) out = cut($0, 0)
      print out
    }' \
  | awk -v wrapwords="$CS_WRAP_OPTION_WORDS" \
        -v operandwords="$CS_WRAP_OPERAND_WORDS" '
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      wrapped = 0
      changed = 1
      while (changed) {
        changed = 0
        if (match(line, /^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+/)) {
          line = substr(line, RSTART + RLENGTH)
          changed = 1
        }
        if (match(line, /^([{}!]|if|then|elif|else|fi|while|until|for|do|done|case|esac|select|function|coproc)([[:space:]]+|$)/)) {
          line = substr(line, RSTART + RLENGTH)
          changed = 1
        }
        # The list arrives as a variable rather than standing here as a literal,
        # so that the wrapper anchor can admit the same words without a second
        # copy of them. Issue #79; see CS_WRAP_OPTION_WORDS above.
        if (match(line, "^(" wrapwords ")[[:space:]]+")) {
          line = substr(line, RSTART + RLENGTH)
          while (match(line, /^-[^[:space:]]*[[:space:]]+/)) {
            line = substr(line, RSTART + RLENGTH)
          }
          wrapped = 1
          changed = 1
        }
        # timeout and flock take an operand -- a duration, a lock file -- that
        # is not an option, so stripping only options left it at the head of
        # the line and the command word behind it was never at ^. That made
        # `timeout 30 git push --all origin` invisible to every hook. The
        # operand is stripped with the word, one token and only if it is not
        # itself an option.
        if (match(line, "^(" operandwords ")[[:space:]]+")) {
          line = substr(line, RSTART + RLENGTH)
          while (match(line, /^-[^[:space:]]*[[:space:]]+/)) {
            line = substr(line, RSTART + RLENGTH)
          }
          if (match(line, /^[^-[:space:]][^[:space:]]*[[:space:]]+/)) {
            line = substr(line, RSTART + RLENGTH)
          }
          wrapped = 1
          changed = 1
        }
      }
      sub(/[[:space:]]+$/, "", line)
      if (line != "") print line
      # A wrapper option taking its value as a separate token leaves that value
      # where the command word has to be, and the command behind it is never at
      # ^ again: `sudo -u root git push --all origin` left `root`, `nice -n 10`
      # left `10`, and `timeout -s KILL 30` left `30` even after the operand
      # strip above took KILL for the duration. Which options take a value is a
      # list, and two are already kept here -- for the git globals and for the
      # gh ones -- so a third would be the same answer written a third time,
      # wrong wherever it is short.
      #
      # So the tail is offered as further candidates rather than the head being
      # trimmed to find one. Offering cannot hide a command; trimming can.
      # `sudo apt-get install jq` still yields itself, and `install jq` beside
      # it refuses nothing. It is the rule at the top of this file -- splitting
      # more eagerly than a shell only ever refuses more -- applied where the
      # command word cannot be found by looking.
      #
      # Three is past the longest real leftover: `timeout -s KILL 30 cmd`
      # leaves two. A token opening a quote ends it, because what follows is
      # the text of an argument, and reading text as a command is the mistake
      # cs_normalise has already made three times.
      if (wrapped && line != "") {
        rest = line
        for (k = 0; k < 3; k++) {
          if (rest ~ /^["]/ || rest ~ /^[\x27]/) break
          if (!match(rest, /^[^[:space:]]+[[:space:]]+/)) break
          rest = substr(rest, RSTART + RLENGTH)
          if (rest ~ /^["]/ || rest ~ /^[\x27]/) break
          print rest
        }
      }
    }'
}

# Print the arguments of a git subcommand and succeed, or print nothing and fail
# if this command is not `git <subcommand>`. Global options are skipped,
# including the two that take a separate value: without that, -C /path ends the
# match before the subcommand is reached.
#
# The exit status is what distinguishes `git push` -- a push whose argument list
# is empty, and the permitted shape -- from a command that is not a push at all.
# A caller testing the printed text instead would have to re-derive the rule,
# which is the habit this file exists to end.
cs_git_args() {
  awk -v want="$1" '
    BEGIN { found = 0 }
    {
      line = $0
      if (line !~ /^git([[:space:]]|$)/) next
      sub(/^git[[:space:]]*/, "", line)
      while (match(line, /^(-[cC][[:space:]]+[^[:space:]]+|--(git-dir|work-tree|namespace|exec-path)([[:space:]]+|=)[^[:space:]]*|-[^[:space:]]+)[[:space:]]+/)) {
        line = substr(line, RSTART + RLENGTH)
      }
      if (line !~ "^" want "([[:space:]]|$)") next
      sub("^" want "[[:space:]]*", "", line)
      print line
      found = 1
      exit
    }
    END { exit(found ? 0 : 1) }'
}

# Print the arguments of a gh subcommand and succeed, or print nothing and fail
# if this command is not that subcommand. The subcommand is given as its whole
# path -- "pr create", "pr edit", "api" -- because gh nests its verbs under a
# group, and the group on its own does not say what the command does.
#
# Options are skipped before every word of that path, not only before the first.
# Cobra resolves each level at the first non-flag argument, so a flag may sit
# between the group and the verb and `gh pr --repo o/r create` still creates;
# -R/--repo and --hostname take their value as a separate token, which has to be
# consumed with them or the value reads as the verb and hides it. That was the
# same shape the GHPR pattern in no-pr-decisions.sh answered with a regular
# expression of its own -- and answered one level too late, skipping options
# between the group and the verb and never before the group, so `gh -R o/r pr
# merge 5` was permitted while `gh pr --repo o/r merge 5` was refused. Issue #47
# moved that file's merge, review, close, reopen, release and gh api rules onto
# this function and deleted GHPR and GHRELEASE, so among the rules over ordinary
# commands the question is answered here and in no second place. Not among all
# of them: that file's wrapper rules match raw text, because a quoted payload
# has no command word to find, and they still answer it themselves and still
# answer it one level too late. Issue #51 carries that, and the header of
# no-pr-decisions.sh says so rather than denying it -- which is the reason to
# say it here too, since this is where a reader comes to find out whether the
# question is settled.
#
# The exit status is what distinguishes `gh pr create` -- a create whose
# argument list is empty, which is exactly the shape that lets gh choose the
# base for itself -- from a command that is not a create at all. A caller
# testing the printed text instead would have to re-derive the rule, which is
# the habit this file exists to end.
#
# Like cs_git_args, it answers about the first match and stops, which is the
# fifth defect in the list at the top of this file if a caller hands it a whole
# command list: the second command is never examined. So a caller feeds it one
# command at a time, as no-git-push.sh does with cs_split's output, and the
# check suite pins that the second match is lost.
#
# One place it does not mirror cs_git_args: that function removes the matched
# subcommand with a regular expression, so the expression that matches and the
# one that removes are the same and cannot disagree. This one matches part[i] as
# a regular expression and removes it by string length. That is the same answer
# for a word and a different one for anything carrying a metacharacter. Every
# caller passes a literal path, so it is a property rather than a defect -- but
# it is the kind that gets discovered rather than read, and closing it would
# need a check written against a caller that does not exist.
#
# It was written before the rule that used it, so what it is for is worth saying:
# asking whether a flag belongs to *this* command is argument scoping, and
# scoping answered ad hoc is where two of the five defects above came from --
# the whole line read an unrelated option as the command's own, and the
# narrowing that fixed that cut at a newline, so a continuation made every
# command look bare.
cs_gh_args() {
  awk -v want="$1" '
    BEGIN { found = 0; n = split(want, part, /[[:space:]]+/) }
    {
      line = $0
      if (line !~ /^gh([[:space:]]|$)/) next
      sub(/^gh[[:space:]]*/, "", line)
      matched = 1
      for (i = 1; i <= n; i++) {
        while (match(line, /^((-R|--repo|--hostname)[[:space:]]+[^[:space:]]+|-[^[:space:]]+)[[:space:]]+/)) {
          line = substr(line, RSTART + RLENGTH)
        }
        if (line !~ "^" part[i] "([[:space:]]|$)") { matched = 0; break }
        line = substr(line, length(part[i]) + 1)
        sub(/^[[:space:]]*/, "", line)
      }
      if (!matched) next
      print line
      found = 1
      exit
    }
    END { exit(found ? 0 : 1) }'
}

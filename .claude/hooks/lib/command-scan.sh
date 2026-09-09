#!/bin/bash
# Where a command starts, where its arguments end, and how many commands a
# string holds. Sourced by no-git-push.sh, no-pr-decisions.sh and, since issue
# #43, no-commit-to-main.sh -- which is every hook that reads a command.
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
  | awk '
    {
      line = $0
      while (line ~ /\\$/) {
        sub(/\\$/, "", line)
        if ((getline nxt) > 0) line = line nxt; else break
      }
      print line
    }' \
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

# Print one command per line, with anything that precedes the command word
# removed, so a caller matches on ^ and never has to describe a command
# position again.
#
# Separators are ; && || | ( ) and a backtick. The backtick is there because
# $( ) was closed by the paren and its twin was not -- the same asymmetry
# GIT_DIR= had against --git-dir.
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
# The trade, taken knowingly and checked as such: a quoted string holding a
# separator and then one of these words in front of a refused command now reads
# as that command, so `git commit -m "wait; then git push --all origin"` is
# refused. That is the direction this file has taken throughout -- a blocked
# comment is visible and one edit away, a silently permitted push is neither.
cs_split() {
  sed -e 's/&&/\n/g' -e 's/||/\n/g' -e 's/[;&|()`]/\n/g' \
  | awk '
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
        if (match(line, /^(env|command|xargs|nohup|nice|time|stdbuf|ionice|sudo|doas|setsid|chronic)[[:space:]]+/)) {
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
        if (match(line, /^(timeout|flock)[[:space:]]+/)) {
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

#!/bin/bash
# Where a command starts, where its arguments end, and how many commands a
# string holds. Sourced by no-git-push.sh and no-pr-decisions.sh.
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
# the probe suite points at these functions directly.
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
# The answers are approximate on purpose. Splitting more eagerly than a shell
# would yields extra command candidates, which can only refuse more; it never
# hides one. That is the safe direction for a guard whose failure mode, twice
# now, has been to report the permitted answer.

# Reduce a raw command to lines that can be scanned: heredoc bodies dropped,
# line continuations joined.
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
# The trade, taken knowingly and probed as such: a quoted string holding a
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
        if (match(line, /^(env|command|xargs|nohup|nice|time|stdbuf|ionice)[[:space:]]+/)) {
          line = substr(line, RSTART + RLENGTH)
          while (match(line, /^-[^[:space:]]*[[:space:]]+/)) {
            line = substr(line, RSTART + RLENGTH)
          }
          changed = 1
        }
      }
      sub(/[[:space:]]+$/, "", line)
      if (line != "") print line
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
      while (match(line, /^(-[cC][[:space:]]+[^[:space:]]+|--(git-dir|work-tree|namespace|exec-path)=[^[:space:]]*|-[^[:space:]]+)[[:space:]]+/)) {
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

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
cs_normalise() {
  awk '
    ind { if ($0 == d) ind = 0; next }
    {
      if (match($0, /<<-?[[:space:]]*[^[:space:];|&<>()]+/)) {
        d = substr($0, RSTART, RLENGTH)
        sub(/^<<-?[[:space:]]*/, "", d)
        gsub(/[\047"]/, "", d)
        ind = 1
      }
      print
    }' \
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
# Removed prefixes: environment assignments, and the wrapper words that run
# another command with their own options. A caller that cares about the
# assignments themselves must look at the un-split text; no-git-push.sh does,
# for GIT_DIR= and GIT_WORK_TREE=.
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

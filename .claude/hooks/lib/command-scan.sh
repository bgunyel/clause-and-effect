#!/bin/bash
# Where a command starts, where its arguments end, and how many commands a
# string holds. Sourced by no-git-push.sh, no-pr-decisions.sh, since issue #43
# no-commit-to-main.sh, since #44 no-work-on-stale-branch.sh, and since #69
# pytest-via-uv-group.sh and alembic-via-uv-group.sh, and since #95
# append-only-docs.sh and append-only-docs-edit.sh -- which is every hook there
# is. The last two source it for cs_tool_input alone, the reader every hook
# shares, and not for the tokeniser; since #96 append-only-docs.sh takes THE LINE
# CAP from it as well. Issue #63 found this line naming three of
# the four there were then, the same way it found CLAUDE.md's boundary section
# naming two of them: a hook is added, and the sentence saying which hooks there
# are is not revised with it. #69 found it a second time from the other end --
# two hooks that read
# a command and were not on the list because they did not source this file at
# all, so the sentence was true of the hooks it knew about and false of the
# repository. It is checked now rather than maintained: check-hooks.sh reads
# which files source this one and asserts that this paragraph names each.
#
# The #69 pair and the #95 pair are the consumers that are not part of the agent
# boundary. They enforce CLAUDE.md conventions -- a dependency group, and the
# append-only directories -- and the difference shows in what they do not have:
# no wrapper rule, because a quoted payload is not worth refusing every `bash -c`
# over. Their fail-closed behaviour is the same as the others', for the same
# reason.
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
# A fourth wrong answer followed that conclusion rather than preceding it, and
# it is #128: the fail-safe covers a body that never ends, and this one was a
# body that began a line too early, on an opener whose own line was continued.
# So the count is four, and the reading of it is unchanged. cs_normalise keeps
# it.
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
# lost past a cut would read as a bare push. Tried with `git push "|--all
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
#
# #106's invariance families found it again one list over, in #134. That anchor
# still carried its own answer to where a command position is -- a separator
# class with no `)` and no control words at all -- so `if true; then bash -c
# "git push --all origin"; fi` was permitted by every boundary hook while the
# same push unwrapped was refused. It is PR #35's control-word defect, fixed for
# the unwrapped command and never asked of the wrapped one. The separators and
# the control words are variables now, CS_SEPARATORS and CS_CONTROL_WORDS, read
# by both halves.

# THE LOAD CONTRACT, which is about this file's absence rather than its
# contents, and is written here because a rename made here is what breaks it.
# Every file that sources this one depends on it to find a command word at all.
# There is no `set -e` in any of them, so an unreadable or incomplete
# library leaves the cs_* names undefined and every call to one fails silently:
# `RAW=$(cs_git_args "$VERB") || continue` cannot tell "not this verb" from "no
# such function", so every verb falls through and the hook exits 0. A guard's
# own breakage must refuse; it does not wave things through.
#
# Issue #84 found that answered three different ways in four files, two of them
# permitting. no-git-push.sh and no-pr-decisions.sh sourced this file with no
# guard at all, and no-commit-to-main.sh required cs_split alone -- so renaming
# cs_git_args, which is a refactor rather than an accident, permitted a forced
# push, a `gh pr merge`, a `gh pr create --base main` and a push to main, with
# the check suite green at 728. That is a tenth defect of the same silent and
# permitting shape as the nine in this file's body, in the load of it rather
# than in it.
#
# So each of them, before it uses anything here:
#
#   - tests the file for readability BEFORE sourcing it and the functions
#     AFTER. A missing file can make `.` end the shell, where an `if` wrapped
#     around it never runs, so a guard written that way would have been a
#     comment.
#   - requires EVERY cs_* function it calls, and not one of them as a proxy for
#     the rest. The sets differ, which is why one shared list would be wrong:
#     no-git-push.sh, no-commit-to-main.sh and no-work-on-stale-branch.sh call
#     cs_normalise, cs_split and cs_git_args; no-pr-decisions.sh calls
#     cs_normalise, cs_split, cs_gh_args, cs_gh_opaque and cs_join, and no
#     cs_git_args at all; pytest-via-uv-group.sh and alembic-via-uv-group.sh
#     call cs_normalise and cs_split and neither of the argument readers, nor
#     cs_gh_opaque. Every one of them calls
#     cs_tool_input as well, and every Bash hook among them calls cs_within_cap
#     (#96); append-only-docs.sh calls those two and nothing else, and
#     append-only-docs-edit.sh only cs_tool_input. cs_within_cap calls cs_join,
#     which no required list names: it answers for that itself, by failing when
#     any part of its pipeline does. A required list narrower than the set is
#     the #84 defect exactly, and #69 found the same thing in the last two from
#     the other end -- cs_split required, cs_normalise not. The enumeration here
#     is a convenience and goes stale; check-hooks.sh derives both sides off the
#     files and compares them, which does not.
#   - names itself in the refusal and says that it is refusing rather than
#     permitting. That message is read by someone who has just been stopped by
#     a guard that is broken rather than by a rule, and the thing they need
#     from it is which of several near-identical files to open.
#
# RENAMING A cs_* FUNCTION REACHES EVERY FILE THAT SOURCES THIS ONE: this file,
# the guard in each consumer that calls it -- `command -v` on a name that no
# longer exists is the failure being guarded against, not a detail of it -- and
# check-hooks.sh, which drives a fixture per consumer per function. The count is
# deliberately not written down: it was four when #84 was opened and six by the
# time it merged, because #69 rebuilt the two convention hooks on this file in
# the same week. check-hooks.sh derives the list instead.
#
# Not factored into one sourced preamble, which #84 asked to be considered. A
# preamble would be a file, so sourcing it needs this same guard one level up,
# and the question the guard exists to answer -- can this file read a command?
# -- would then be asked of two files where it is asked of one. What the copies
# share is four lines of shape; what differs is the function list and the
# message, which is the whole of their content. So the argument is factored out
# and lives here, once, and each guard points at it by name; the code is not.
#
# "Loads" includes data as well as names. cs_split reads the prefix-word list
# through a variable, so a library with every function defined and that list
# empty is not a loaded library, and a guard on names cannot see it. It is not
# answered in the guards. The library withdraws cs_split itself when the list is
# incomplete, which reduces the state to a missing function, and every consumer
# already requires that one. See THE WORD LIST IS PART OF THE LOAD, below
# cs_split. Issue #79.

# THE INPUT READ, which is the step before the load contract and was the same
# defect one step earlier. Every hook read its tool call with its own
# `jq -r '.tool_input.command'`, and when that read failed the command was empty
# and the hook exited 0. Issue #95 measured three hooks at dev-05 750aace: with
# jq off PATH, and for no-git-push.sh with stdin that was not JSON, empty, or had
# no command in it, `git push --force origin main` and `gh pr merge 5` were
# permitted. check-hooks.sh widened it to all eight at e8c132f and found every
# condition permitted in every hook. Eight
# copies of one line is also how eight answers happen, so the read is here, once,
# and every hook calls it -- including append-only-docs-edit.sh, which sources
# this file for nothing else.
#
# The fail direction, for every condition, in this one place (#103 Q19):
#
#   jq is not on PATH                                refuse, and say so by name
#   stdin is not exactly one JSON value              refuse
#     (plain text, cut off, text after the value,
#      two values, or nothing at all)
#   that value is not an object, or its tool_input
#     is missing or not an object                    refuse
#   tool_input.<field> is missing, or is null, a
#     number, a boolean, an array or an object       refuse
#   tool_input.<field> is a string                   read it; the hook decides
#   ... and that string is empty                     read it; there is nothing
#                                                    to run, so the command hooks
#                                                    permit, and the Edit hook
#                                                    has no path and permits
#
# Refusing is the direction CLAUDE.md's left-open item 3 argues: a blocked
# command is visible and one edit away, a silently permitted push is neither.
# It also decides what a change to the harness's payload format looks like -- every
# call refused, not every guard switched off without a word.
#
# THE TRADE, taken knowingly. An environment without jq refuses every Bash
# command and every Edit and Write, including the `uv run --group test pytest`
# the convention hooks exist to permit. The refusal names jq so the fix is one
# install away. check-hooks.sh pins both halves of that.
#
# Empty stdin is the case that shapes the implementation. jq given no input reads
# no values, prints nothing and exits 0, so trusting its exit status alone permits
# it; and text after a valid value makes jq print the field from the first value
# before it fails, so trusting its output alone permits that. Slurping answers
# both: the whole input is parsed before anything is printed, and the filter asks
# for exactly one value. A JSON null printed by `jq -r` is the four letters null,
# indistinguishable from the command `null`, so the type is asked inside jq rather
# than read off the output.
#
# The refusal names the hook through $0, which in a sourced function is still the
# hook's own path, for THE LOAD CONTRACT's reason: near-identical files.
cs_tool_input() {  # cs_tool_input <field> -- stdin: the tool call; stdout: tool_input.<field>
  local hook="${0##*/}"
  if ! command -v jq >/dev/null 2>&1; then
    printf 'Blocked: jq is not on PATH, so %s cannot read the tool call it was handed. Refusing rather than permitting; installing jq lifts this.\n' \
      "$hook" >&2
    return 2
  fi
  # No test that the value or its tool_input is an object: indexing a string, a
  # number or an array is itself a jq error, and indexing null yields null, which
  # is not a string -- so every shape that is not an object already refuses, and
  # a mutation check found the two lines that asked it could be deleted unseen.
  jq -rs --arg f "$1" '
    if length == 1 and (.[0].tool_input[$f] | type) == "string"
    then .[0].tool_input[$f]
    else error("unreadable")
    end' 2>/dev/null || {
    printf 'Blocked: %s could not read tool_input.%s as a string from the tool call it was handed -- the input is not one JSON object, or the field is missing or not a string. Refusing rather than permitting.\n' \
      "$hook" "$1" >&2
    return 2
  }
}

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
# The drop waits for a logical line to end, and that is #128's paragraph below:
# a line ending in a backslash continues, and a body begins after the first line
# that does not. Only WHERE the line ends is asked here; the joining itself is
# still cs_join's, one pass later, so the two cannot answer the backslash
# differently.
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
# A FIFTH answer followed, and the paragraph that stood at the head of this
# comment was it: joining ran after dropping, and that order was claimed to make
# a backslash before a terminator harmless. It did the opposite one line further
# up. Bash joins the OPENER's own continuation before the body begins, so
#
#   cat <<E \
#   x
#   E
#   git push --force origin main
#
# is `cat <<E x` with an empty body, and the push runs -- while this pass took
# `x` for the body, ended the body at `E`, and cs_join then glued the push onto
# the opener line, where no command stands at a command position. no-git-push.sh
# and no-commit-to-main.sh both answered exit 0, measured. Issue #128.
#
# So the drop waits for the logical line to end: the opener is looked for on
# every line of it, and the body begins after the line that ends it. WHICH line
# that is, is bash's rule and not cs_join's -- a line continues only when its
# run of trailing backslashes is ODD -- and the first version of this fix used
# cs_join's looser rule instead, that any trailing backslash continues. That
# version was wrong, in the permitting direction, and the argument that licensed
# it is the sentence worth keeping here:
#
#   "Looser than bash is the safe side, because a logical line held open too
#   long only exposes more lines as commands."
#
# It is false. Holding the line open moves the START OF THE BODY forward, and
# the search for the terminator with it -- so a delimiter line that bash took as
# the whole terminator is scanned past as though it were part of the command
# line, the body runs on to the NEXT delimiter, and everything between them is
# dropped. Measured on the fix that made that claim:
#
#   cat <<E \\
#   E
#   echo after
#   git push --force origin main
#   E
#
# Bash ends the command line at `cat <<E \` -- `\\` is an escaped backslash,
# an even run, so nothing is continued -- takes the next line as the terminator
# of an empty body, and runs `echo after` and the push. That fix emitted
# `cat <<E \E` and NOTHING else: the push was gone, and no-git-push.sh answered
# exit 0 where dev-05 answered exit 2. A new permitting defect in the change
# whose subject is a permitting defect, and of the same class. Found by review of
# this pull request, not by the suite it arrived with.
#
# So parity is modelled where the body starts, and the two rules are then left
# to disagree everywhere it cannot cost anything -- except at one point. cs_join
# joins a line ending in ANY backslash, deliberately, and it runs one pass after
# this one; the line this pass ends a logical line on therefore gets its trailing
# run taken off, because that line is the one cs_join could otherwise glue the
# first line AFTER the terminator onto. Under the parity rule such a run is
# always even, which is exactly the case bash does not join and cs_join does. A
# trailing backslash is text of a command line and never a command, so removing
# it can hide nothing; what it removes is the disagreement, at the only place
# where the disagreement reaches a verdict.
#
# What says all of this rather than the paragraph above: 2,580 generated shapes
# of opener, backslash run, delimiter and payload position, each RUN under bash
# with `touch ran.flag` as the payload -- so that execution and not output is
# what the property reads -- and then put through this pass with a push in the
# payload's place. The property is that a push bash runs stands at the start of
# some emitted line. dev-05 fails it 198 times, the first version of this fix 40,
# this version 0. The harness is in the pull request, not the tree: its own first
# two generations were green for the wrong reasons, once from a fixed
# `E / payload / E` tail that re-closed every swallowed body and once from
# reading `cat` printing a body line as the payload having run.
#
# A body line is still never joined, whether its delimiter is quoted or not,
# because it is dropped before cs_join sees it -- so a quoted body whose every
# line ends in a backslash still ends at its terminator, where bash ends it too.
# Bash joins inside an UNQUOTED body and this pass does not, which ends the body
# EARLIER than bash: the lines between are emitted rather than dropped. That is
# the safe direction here for the reason the paragraph above is careful about --
# ending a body early exposes lines, and it is ending one LATE, or starting one
# late, that hides them. Deliberately not modelled rather than overlooked, and
# the 2,580-shape run above covers body lines ending in a backslash under both
# quotings.
#
# THE TRADE, taken knowingly: an opener SPLIT by the continuation -- `cat <<\` /
# `E`, or `cat <<E\` / `x`, which bash reads as `<<E` and `<<Ex` -- is not
# recognised as that opener, because the opener is looked for on each physical
# line rather than on the joined text. Joining here to look at it would be the
# join rule written twice, in the file whose header says that is the defect. So
# either no opener is found or its delimiter never arrives, and both ends in the
# END give-back: the lines are scanned as commands, which is where every other
# uncertainty in this pass already lands.
#
# That is the answer this question should have had from the start: the exact
# version has been got wrong four times, and each time the failure was silent
# and in the permitting direction. The fail-safe costs a genuinely unterminated
# heredoc being scanned as commands -- which bash would refuse to run anyway --
# and it is the direction this file takes everywhere else.
#
# WHAT THAT DIRECTION COSTS, counted rather than asserted: the sentence above
# says the fail-safe is paid for in refusals and does not say how many. The
# 2,580 shapes carry a second column, which is the first one read backwards --
# bash does NOT run the payload, yet a push in its place stands at the start of
# an emitted line, so a hook refuses text bash never runs. Measured on the same
# run: 750 such shapes on dev-05, 816 on the first fix, 848 here, of 2,100.
# The rise is this change taking its own direction and not a new departure:
# of the 124 that arrive, 108 are the END give-back and 16 the unquoted-body
# join, both of them named above -- bash reports the heredoc unterminated and
# the lines held for it come back as commands; a body line ending in a
# backslash is joined by bash and not by this pass. 26 go the other way:
# pushes that really were body text, now dropped because the body begins where
# bash begins it. Raised on review of the pull request for #128 and kept, on
# the grounds the whole file keeps everywhere else: a
# refusal is visible and one edit away, and a permitted push is neither.
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
      # An opener found on an earlier line of this logical line is the one that
      # stands: the first match wins, as it did when every logical line was one
      # physical line. `opener` set means a body is waiting for the line to end,
      # which it can only be while the line is still being continued.
      if (!opener) {
        # A here-string is not a heredoc. Blanked at its own width, so a real
        # heredoc later on the same line is still found where it stands.
        scan = $0
        gsub(/<<</, "   ", scan)
        if (match(scan, /<<-?[[:space:]]*[^[:space:];|&<>()]+/)) {
          d = substr(scan, RSTART, RLENGTH)
          dash = (d ~ /^<<-/)
          sub(/^<<-?[[:space:]]*/, "", d)
          gsub(/[\047"]/, "", d)
          opener = 1
        }
      }
      if (!opener) { print; next }
      # Where the logical line carrying the opener ends, by the rule bash uses
      # and not the one cs_join uses: a line continues only when its run of
      # trailing backslashes is ODD, the last one escaping the newline and the
      # rest being escaped backslashes. An even run is text, and the line ends
      # there. #128.
      # p is that parity, flipped per backslash rather than taken with a
      # modulo, so that the rule can be broken by one registered mutation:
      # mutate-hooks.sh splits a row on % and could not carry the expression.
      line = $0
      n = length(line)
      r = 0
      p = 0
      while (r < n && substr(line, n - r, 1) == "\\") { r++; p = 1 - p }
      if (p) { print; next }
      # The body starts after this line, and cs_join runs one pass later on a
      # LOOSER rule -- it joins a line ending in ANY backslash, an escaped one
      # included, deliberately. So an even run left standing here is the one
      # place the two disagree where it can cost something: cs_join would glue
      # the first line after the terminator onto this one, which is #128 again
      # in its other spelling. Take the run off rather than hope they agree:
      # trailing backslashes are text of the command line itself, never a
      # command, and a line start is what every rule reads.
      # The blanks in front of the run go with it, so that what this pass emits
      # carries no trailing whitespace for a literal in check-hooks.sh to have
      # to spell. Trailing blanks are not a command either.
      if (r > 0) sub(/[ \t]*\\+$/, "", line)
      print line
      ind = 1
      opener = 0
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
    #     mistake the heredoc opener has made four times -- the header above
    #     keeps that count -- so quotes are tracked character by character
    #     rather than matched around.
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
    #
    # The output is an array of one character per cell, not a string, and that
    # is issue #96 rather than style. `out = out c` copies the whole of out to
    # add one character, so this pass was quadratic in the length of a line:
    # 1.9 s for one line of 256 KB and 9.3 s for 512 KB, where it takes 0.24 s
    # now, and the harness kills a hook at 5 s, which permits. The operator branch still reads and trims the end of what has been
    # emitted, so the cells are kept until the line is done rather than printed
    # as they arrive; every read of the tail walks back over cells, and the walk
    # stops at the first character that is not a digit, an & or whitespace.
    # See THE LINE CAP, below cs_split.
    BEGIN {
      BOUND = " \t;|&()`<>"
      STOP  = BOUND "\042\047"
      SPACE = " \t\n\v\f\r"
    }
    {
      line = $0
      n = length(line)
      np = 0
      q = ""
      i = 1
      while (i <= n) {
        c = substr(line, i, 1)
        if (q != "") {
          if (q == "\042" && c == "\\") { o[++np] = c; o[++np] = substr(line, i + 1, 1); i += 2; continue }
          o[++np] = c
          if (c == q) q = ""
          i++
          continue
        }
        if (c == "\\") { o[++np] = c; o[++np] = substr(line, i + 1, 1); i += 2; continue }
        if (c == "\042" || c == "\047") { q = c; o[++np] = c; i++; continue }
        if (c != ">" && c != "<") { o[++np] = c; i++; continue }
        nxt = substr(line, i + 1, 1)
        # Process substitution carries a command. Not a redirection.
        if (nxt == "(") { o[++np] = c; i++; continue }
        # A run of two or more < is a heredoc or a here-string, already answered.
        if (c == "<" && nxt == "<") {
          while (i <= n && substr(line, i, 1) == "<") { o[++np] = "<"; i++ }
          continue
        }
        # The fd, or the & of &>, sits in front of the operator and belongs to
        # it. A digit run counts only where it is a word of its own: in
        # `origin b2>f` the 2 is part of the refspec, and bash reads it that way
        # too. A single & is the & of &>; two are the separator &&, which ends a
        # command and must survive, or the command after it disappears.
        k = np
        while (k > 0 && o[k] ~ /^[0-9]$/) k--
        if (k < np && (k == 0 || index(BOUND, o[k]) > 0)) {
          np = k
        } else if (c == ">" && np > 0 && o[np] == "&" && o[np > 1 ? np - 1 : 1] != "&") {
          # o[1] and not nothing when & is the only character: the string
          # version read substr(out, 0, 1), which mawk answers with the first
          # character, so `&>f` at the head of a line kept its &. Kept as it
          # was -- a standing & is a separator to cs_split and changes no
          # verdict -- because this rewrite is held to identical output.
          np--
        }
        while (np > 0 && o[np] != "" && index(SPACE, o[np]) > 0) np--
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
        if (i <= n && np > 0 && t != " " && t != "\t") o[++np] = " "
      }
      for (k = 1; k <= np; k++) printf "%s", o[k]
      printf "\n"
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
#
# Printed as it goes rather than grown and printed once, since issue #96. The
# joined line was built by appending each continuation to it, which copies all
# of it every time: 51,200 continued lines of ten bytes, 512 KB, took 5.9 s,
# and take 34 ms now. The rule is unchanged and deliberately so -- a line ending in any backslash, an escaped
# one included, is joined to the next, and the trailing backslash is taken off
# the joined text rather than the physical line. That second half is why the
# run of backslashes at the end of what has been printed so far is held back
# as a count: with an empty line after it, the next one taken off is from that
# run, which a character already printed could not give back.
cs_join() {
  awk '
    function slashes(k) { while (k-- > 0) printf "\\" }
    {
      cur = $0
      held = 0
      while (1) {
        if (cur == "") {
          if (held == 0) break
          held--
        } else {
          n = length(cur)
          r = 0
          while (r < n && substr(cur, n - r, 1) == "\\") r++
          if (r == 0) break
          if (r == n) {
            held += r - 1
          } else {
            slashes(held)
            printf "%s", substr(cur, 1, n - r)
            held = r - 1
          }
        }
        if ((getline nxt) > 0) cur = nxt; else { cur = ""; break }
      }
      slashes(held)
      print cur
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

# Where a command position is, as two lists that both halves of this library
# read: the characters cs_split cuts on, and the shell's own words it strips from
# the head of a fragment. Issue #134.
#
# They were written once each, inside cs_split, and CS_WRAPPER_RE below answered
# the same question a second time with a class of its own -- start of line and
# `;` `&` `|` `(` and a backtick. It had no `)`, and no control words at all, so
# a wrapper after one was at a command position for every rule that reads
# cs_split and at none for the rule that refuses wrappers. Measured at
# origin/dev-05 33f7129, in every boundary hook:
#
#   BLOCK   if true; then git push --all origin; fi            cs_split strips then
#   ALLOW   if true; then bash -c "git push --all origin"; fi  the anchor did not
#   ALLOW   case x in x) bash -c "gh pr merge 5";; esac        nor did it know )
#
# The same shape as the prefix words above, one list over, and the same answer:
# a variable, read by cs_split through awk's -v and interpolated by the anchor,
# so that a word added to one is added to both. `in` is not a control word here
# and is left out on purpose: it introduces the words of a for loop or a case,
# never a command, and cs_split has never stripped it.
#
# The separators are a string of characters and not a regular expression, since
# cs_split walks them with index() and the anchor wraps them in a bracket
# expression. Every one of them is literal inside brackets, which is what lets
# one spelling serve both, and check-hooks.sh asks that of the list rather than
# leaving it to this sentence: no `-`, which would make a range of its
# neighbours in silence, and no `]`, `^`, backslash or `[`.
#
# WHAT THAT PIN IS NOW FOR, and it is not what the first version of this
# paragraph said. That version was written before the load-time validity guard
# below cs_split existed, and it argued from the damage a malformed list did
# then: `[.` opens a collating element, the anchor does not compile, grep exits
# 2, and every consumer's `if grep -qE ... &&` read a 2 as "no wrapper" and
# PERMITTED -- 289 checks red with 274 of them a BLOCK turned ALLOW. The guard
# closed that, and the paragraph outlived it. Re-measured with the guard in
# place, the same mutation is 1564 checks red, **none** of them permitting and
# 1444 refusing: the list is withdrawn and every consumer refuses everything.
# Review of PR #172 found the sentence still claiming the old direction.
#
# So emptiness and validity are BOTH handled below cs_split now, and what is
# asked here is the third thing neither reaches: a list that is well formed and
# means the wrong thing. `-` between two characters is a valid range -- the
# class compiles, both load-time guards pass it, and digits, uppercase and `=?@_/`
# quietly become separators. No compile test can see that, which is why it is a
# membership pin and why the pin is not redundant with the guard.
CS_SEPARATORS=';&|()`'
CS_CONTROL_WORDS='[{}!]|if|then|elif|else|fi|while|until|for|do|done|case|esac|select|function|coproc'

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
# Which is also why the anchor has to find a command position for itself, and
# what it admits between the position and the wrapper word. The position is
# CS_SEPARATORS or the start of a line, and what may stand after it, in any
# order and any number, is what cs_split strips from the head of a fragment: an
# environment assignment, a control word from CS_CONTROL_WORDS (#134), and a
# prefix word from the list above with its options and up to three further
# tokens. It finds the position for itself; it no longer says what one is a
# second time. Until #134 it did, with a class of its own that lacked `)` and
# every control word, and that is argued above CS_SEPARATORS.
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
# THE CLASS AND THE COUNT, both. The token admitted between the prefix word and
# the wrapper is cs_split's tail token exactly, and three is cs_split's bound.
# This paragraph has now been wrong about that twice and in both directions --
# claiming the classes matched when this one was wider, then claiming only the
# count was shared when this one had also been narrower in a second respect
# nobody had noticed. What is left differing is the loop and not the class, and
# CS_WRAP_TOKEN below is where that is set out.
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
# AND A NARROWER GAP THAN THAT ONE, which is #175 and is not the same family.
# The paragraph above is about words this library cannot reach. This is the
# anchor's own word, `bash`, with an option spelling it declines to admit: the
# tail below wants an option token that BEGINS `-c` and a heredoc operator with
# whitespace in front of it, so
#
#   BLOCK   bash -c 'gh pr merge 5'
#   BLOCK   bash -cx 'gh pr merge 5'    only because -cx begins with -c
#   ALLOW   bash -lc 'gh pr merge 5'
#   ALLOW   sh -ec 'gh pr merge 5'
#   ALLOW   bash --login -c 'gh pr merge 5'
#   ALLOW   bash<<EOF                    the blank is required and is not there
#
# cs_split does not rescue these either: `bash` is not a prefix word, so the
# payload stays quoted and no rule sees the command inside it. #134 answered
# WHERE a command position is, once, for both halves; WHICH word is a wrapper is
# the other question in this expression and #134 did not touch it. The verdicts
# above are pinned in check-hooks.sh under GH-175, at the verdict they have and
# not the one they should have, so the fix turns them red. Why it was not fixed
# with #134: widening the option class falls on prose too, since this rule reads
# raw text, and that cost has to be measured before it is taken -- which is the
# work, not a line of it.
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
# #134 widened it again, the same way: a control word or a `)` in prose after a
# quote-blind separator now stands where a command would, so `echo "x; then
# bash -c y" && gh pr view 5` was ALLOW and is now BLOCK. So is a regex
# alternation closing onto a wrapper word, `grep -nE "(ba|z)sh -c" f && gh pr
# view 5`, since a `)` needs no blank after it; and so is a pull request comment
# quoting the shape #134 fixed, `gh pr comment 5 --body "if true; then bash -c
# y; fi"`. The same cost, in the same direction, and each is a check.
#
# A token that may stand between the prefix word and the wrapper word: any word
# at all, which is cs_split's tail token exactly -- `^[^[:space:]]+[[:space:]]+`
# there, the same class here. Both the class and the bound of three are shared,
# and that is the whole claim.
#
# IT EXCLUDED A LEADING DASH UNTIL REVIEW OF THIS BRANCH, and that was #79
# reproduced inside its own fix, one option deeper and in the permitting
# direction. The options loop in front of this one stops at the first token
# that is not an option, so an option appearing AFTER a separated option value
# was left for this class to admit -- and it refused to. cs_split walks past it
# and finds the command; the anchor stopped dead. Measured on the branch that
# had it:
#
#   BLOCK   sudo -u root -n git push --all origin
#   ALLOW   sudo -u root -n sh -c 'git push --all origin'
#   BLOCK   nice -n 10 -- git push --all origin
#   ALLOW   nice -n 10 -- sh -c 'git push --all origin'
#
# `sudo -n`, `nice -n 10 --` and `timeout --preserve-status` are ordinary
# spellings, and `--` defeats an exclusion like that whenever it follows a
# separated option value. `sudo -- sh -c` was refused throughout, because
# nothing had consumed an operand yet and the options loop still had the dash.
#
# Worse than the gap: the paragraph here named a deliberate difference from
# cs_split, argued it was safe because admitting a token too many can only
# refuse more, and did not mention this one, which runs the other way and which
# that argument does not license. A comment claiming the classes differ in one
# respect while they differed in two is the shape this file exists to stop,
# arriving in the change whose subject it is. All three shapes are checks now.
#
# ONE DIFFERENCE REMAINS, and it is in the loop rather than the class.
# cs_split's tail also breaks at a token that OPENS A QUOTE, because it is
# offering candidates to read as commands and what follows a quote is the text
# of an argument -- the mistake cs_normalise has made three times. Nothing here
# reads a token as a command: these are skipped, on the way to a wrapper word
# that must still appear after them. So the reason to stop does not transfer,
# and `sudo "x" sh -c 'git push --all origin'` is refused here while cs_split
# offers no candidate for it. That asymmetry is in the refusing direction and
# is pinned as a check.
CS_WRAP_TOKEN="[^[:space:]]+[[:space:]]+"

# THE WRAPPER'S OWN COMMAND WORD, issue #117. The spellings cs_split normalises
# for every other rule cannot be normalised here, because this expression reads
# RAW TEXT: a wrapper is recognised before anything is split, and the reason it
# is recognised at all is that its payload cannot be read. So the spellings are
# admitted in the expression instead, and `/usr/bin/bash -c "gh pr merge 5"` --
# permitted by all four boundary hooks before this -- is the wrapper it is.
#
# The same rule as cw_reduce in cs_split, written as far as a regular
# expression reaches it: a run that ends in a slash, or a quote or a backslash,
# repeated, in front of the name -- and quotes behind the name, since `"bash"`
# closes after it. The run cannot cross whitespace or a separator, so the
# command position this anchor establishes is not given up: `ls /usr/bin/bash`
# offers no command position at that path, and `mybash -c` reaches the name
# through no slash at all. Both are pinned.
#
# WHAT A REGULAR EXPRESSION DOES NOT REACH, and cw_reduce does: a quoted span in
# the middle of the word -- `b"a"sh`, `/usr/"bin"/bash`, where the run stops at
# the quote and the name is not whole on either side of it. That stays permitted
# here while it is refused everywhere else, under the same trade the rest of this
# rule takes: these stop mistakes, not adversaries, and an agent that means
# `bash` writes one of the five.
#
# ONE SHAPE AND NOT TWO, which is what this paragraph said before Bertan's
# review of the #117 branch measured it. An ESCAPED SLASH inside the path was
# named here as a second unreachable shape and is not one: a backslash is not
# excluded from the run, so the run takes `/usr\` and the `/` after it, and
# `/usr\/bin\/bash -c "x"` matches. The claim was written from the shape of the
# expression rather than from a measurement of it, which is the habit this file
# exists to end. Both spellings are pinned now, the one that matches and the one
# that does not, so that neither can move in silence.
#
# "Cannot cross a separator" reads CS_SEPARATORS. #117 and #134 landed on
# dev-05 separately, and #117 wrote the characters out here as its own copy;
# the merge of the two made it read the list, so the separators are still spelled
# once.
CS_WORD_SPELLING="([\\\\\"']|[^[:space:]$CS_SEPARATORS\"']*/)*"
# Built unconditionally. What happens when the list it interpolates is empty is
# not decided here: it is decided once, after cs_split, where the list's one
# reader is withdrawn so that every consumer's load guard refuses. See
# THE WORD LIST IS PART OF THE LOAD, below cs_split.
CS_WRAPPER_RE="(^[[:space:]]*|[$CS_SEPARATORS][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+|($CS_CONTROL_WORDS)[[:space:]]+|$CS_WORD_SPELLING($CS_WRAP_WORDS)[\\\\\"']*[[:space:]]+(-[^[:space:]]*[[:space:]]+)*($CS_WRAP_TOKEN){0,3})*$CS_WORD_SPELLING((ba|z|)sh[\\\\\"']*[[:space:]]+(-c|<<)|eval([^-A-Za-z0-9_]|\$))"

# Print one command per line, with anything that precedes the command word
# removed, so a caller matches on ^ and never has to describe a command
# position again.
#
# Separators are CS_SEPARATORS, the two-character && and || among them because
# each is a doubled one of its characters. The backtick is there because
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
# Which words they are is CS_CONTROL_WORDS, and the wrapper anchor reads it too.
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
  awk -v separators="$CS_SEPARATORS" '
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
    # walk reports back about the line it just read. So are ncut, at and width,
    # which are where it cut.
    #
    # Where, and not what. Every character this walk keeps it keeps unchanged
    # and in order, and every separator it replaces with one newline, so the
    # output is the line itself with ncut spans taken out -- and emit prints it
    # as the slices between them. It built that output a character at a time
    # before issue #96, and a string grown by one character is a string copied
    # whole, so one plain line of 512 KB took cs_split 10.8 s, nearly all of it
    # here; it takes 0.17 s now. See THE LINE CAP, below.
    function cut(line, respect,    n, i, c, nx) {
      n = length(line)
      ncut = 0
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
            if (qopen == "\042" && c == "\\") { i += 2; continue }
            if (qopen == "\042" && (c == "`" || (c == "$" && substr(line, i + 1, 1) == "("))) dq_substitution = 1
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
            if (nx == "\042" || nx == "\047") { i += 2; continue }
            i++
            continue
          }
          if (c == "\042" || c == "\047") { qopen = c; i++; continue }
        }
        if (c == "&" && substr(line, i + 1, 1) == "&") { at[++ncut] = i; width[ncut] = 2; i += 2; continue }
        if (c == "|" && substr(line, i + 1, 1) == "|") { at[++ncut] = i; width[ncut] = 2; i += 2; continue }
        if (index(separators, c) > 0) { at[++ncut] = i; width[ncut] = 1; i++; continue }
        i++
      }
    }
    function emit(line,    k, from) {
      from = 1
      for (k = 1; k <= ncut; k++) {
        printf "%s\n", substr(line, from, at[k] - from)
        from = at[k] + width[k]
      }
      print substr(line, from)
    }
    {
      cut($0, 1)
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
      if (qopen != "" || dq_substitution) cut($0, 0)
      emit($0)
    }' \
  | awk -v wrapwords="$CS_WRAP_OPTION_WORDS" \
        -v operandwords="$CS_WRAP_OPERAND_WORDS" \
        -v controlwords="$CS_CONTROL_WORDS" '
    # Each strip below moves p past a token rather than cutting the line down to
    # what follows it. They were substr calls on the line, and every one copied
    # the rest of it, so a long run of prefixes was quadratic: 512 KB of sudo
    # took 1.8 s and 512 KB of assignments 1.7 s, where they take 0.54 and
    # 0.78 s now. Issue #96. A token is a run of non-blank
    # characters, and each rule reads the one at p and asks what the expression
    # it replaced asked of the head of the line -- including whether blanks
    # follow it, which is what separates `sudo git` from a line ending in sudo.
    function tokend(i) { while (i <= n && index(" \t\n\v\f\r", substr(line, i, 1)) == 0) i++; return i }
    function skipblank(i) { while (i <= n && index(" \t\n\v\f\r", substr(line, i, 1)) > 0) i++; return i }
    # THE COMMAND WORD ITSELF. Issue #117: every rule in every hook recognises a
    # command by the bare name at the head of what this function emits, and bash
    # runs the same program when that name is spelled as a path, in quotes or
    # behind a backslash. All five spellings of all seven refused shapes #117
    # measured were permitted, in the five hooks it measured. Five of the six
    # that read a command: the sixth, no-work-on-stale-branch.sh, needed a
    # fixture the issue did not build, so it went unmeasured rather than
    # unaffected -- it reads its git commands through this same anchor. It is
    # checked now, beside that fixture.
    #
    # Here rather than in each anchor, which is the same reason the rest of this
    # file exists: seven anchors across six hooks would be the one question
    # answered seven times, and an anchor added later would answer it an eighth.
    # Every consumer gets this without knowing it happened.
    #
    # THE RULE IS THE BASENAME AFTER UNQUOTING AND UNESCAPING, and the two
    # halves of that are not interchangeable. Asking instead whether the guarded
    # name appears in the word would refuse `my-gh`, which #72 decided is a
    # different program; asking only about a leading path would miss the three
    # quoting spellings. What bash runs is the file the word names, so the word
    # is reduced to the name of that file and to nothing else.
    #
    # A slash separates path components whatever quoting it is written under --
    # quoting changes what a character IS, not what a slash DOES -- so the
    # decision is taken on the character after unescaping, and `/usr\/bin\/gh`
    # reduces to gh as `/usr/bin/gh` does. The count is reset at each one rather
    # than the string searched for one afterwards, which answers the question
    # once instead of twice.
    #
    # AN ARRAY OF CELLS AND NOT A STRING, which is issue #96 rather than style,
    # and the reason this function returns a count and prints nothing. `out =
    # out ch` copies the whole of out to add one character, so building the name
    # that way is quadratic in its length -- the shape #96 found in six passes
    # of this file and fixed in all six. A command word is one word, but THE
    # LINE CAP does not bound one (#128), and the cap is not what these passes
    # are held fast by in the first place. Measured at the cap, LC_ALL=C, mawk
    # 1.3.4, fastest of three: a 16 KB line with no command word to reduce costs
    # cs_split 6 ms, a command word of 5,460 path components 14 ms, and one
    # quoted component of 16 KB -- the whole of it walked and the whole of it
    # printed -- 16 ms. check-hooks.sh holds the scaling at 128 KB against
    # 512 KB, past the cap, and the string version was measured against that
    # check rather than argued about: 416 ms and 5,310 ms, a ratio of 12.7 where
    # the check fails at 8, against 129 ms and 497 ms for the cells.
    #
    # A backslash escape is read inside double quotes and not inside single
    # quotes. That is the answer cs_normalise and the separator walk in this
    # same function already give, and it is what bash does; giving it a third
    # time differently is how the answers in this file came to disagree before.
    function cw_reduce(w,   m, c, ch, q, len) {
      cw_n = 0
      q = ""
      m = 1
      len = length(w)
      while (m <= len) {
        c = substr(w, m, 1)
        ch = ""
        if (q != "") {
          if (q == "\042" && c == "\\")      { ch = substr(w, m + 1, 1); m += 2 }
          else if (c == q)                   { q = ""; m++ }
          else                               { ch = c; m++ }
        }
        else if (c == "\\")                  { ch = substr(w, m + 1, 1); m += 2 }
        else if (c == "\042" || c == "\047") { q = c; m++ }
        else                                 { ch = c; m++ }
        if (ch == "/") cw_n = 0
        else if (ch != "") cw[++cw_n] = ch
      }
      return cw_n
    }
    # A candidate printed with its first word reduced to that name, or printed
    # exactly as it came. Two things leave it alone, and each is a case where
    # rewriting would say something false:
    #
    #   - a word carrying none of the four characters is already a bare name.
    #     The test is also what keeps the walk off every ordinary command, and
    #     it is why the two costs above are 6 ms and not 6 ms plus a walk;
    #   - a word whose basename is empty names no file. `/usr/bin/ git push`
    #     rewritten would put the first ARGUMENT where the command word goes and
    #     read as a push.
    #
    # There is no third case for a word that reduces to itself, and there cannot
    # be one: past the test above the word holds a slash, a quote or a backslash,
    # every one of which this drops, so a reduction that changed nothing has an
    # empty name and is already the second case.
    # The reduced word as a STRING, for the comparisons that need one rather
    # than a printed line: the prefix-word list and the operand-word list. A
    # prefix word is matched BY NAME, so #117 reaches it exactly as it reaches
    # the command word -- `/usr/bin/env gh pr merge 5`, `/usr/bin/sudo gh pr
    # merge 5` and `"timeout" 30 gh pr merge 5` were permitted where the bare
    # spellings are refused, measured in the triage of #117 at origin/dev-05
    # 96c6850. Fixing the command word alone would have left all three, which is
    # what that triage means by "the next review round finds it".
    #
    # BOUNDED, and that is what keeps this linear where printhead avoids the
    # question by printing. A string has to be built to match it against a list,
    # and building one a character at a time is the quadratic shape of #96; so a
    # name
    # longer than any word in either list is not built at all. It cannot be one
    # of them, and the cost of a long word stays the cost of walking it. The
    # bound is written here as a number well past the longest word either list
    # holds rather than derived from them, because a derivation would have to
    # split the lists on `|` for every token of every line.
    function cw_name(w,   k, out) {
      if (cw_reduce(w) == 0 || cw_n > 32) return ""
      out = ""
      for (k = 1; k <= cw_n; k++) out = out cw[k]
      return out
    }
    # A token as the name it spells: itself when it carries none of the four
    # characters, which is every ordinary command, and its reduction otherwise.
    function cw_spelled(w) {
      if (index(w, "/") == 0 && index(w, "\042") == 0 \
          && index(w, "\047") == 0 && index(w, "\\") == 0) return w
      return cw_name(w)
    }
    function printhead(s,   i, w, k) {
      i = 1
      while (i <= length(s) && index(" \t\n\v\f\r", substr(s, i, 1)) == 0) i++
      w = substr(s, 1, i - 1)
      if (index(w, "/") == 0 && index(w, "\042") == 0 \
          && index(w, "\047") == 0 && index(w, "\\") == 0) { print s; return }
      if (cw_reduce(w) == 0) { print s; return }
      for (k = 1; k <= cw_n; k++) printf "%s", cw[k]
      printf "%s\n", substr(s, i)
    }
    {
      line = $0
      n = length(line)
      p = skipblank(1)
      wrapped = 0
      changed = 1
      while (changed) {
        changed = 0
        q = tokend(p)
        if (q <= n && substr(line, p, q - p) ~ /^[A-Za-z_][A-Za-z0-9_]*=/) {
          p = skipblank(q)
          changed = 1
        }
        # The control words arrive as a variable for the reason the prefix
        # words below do: the wrapper anchor admits the same list, and a second
        # copy of it there was #134. See CS_CONTROL_WORDS.
        q = tokend(p)
        if (substr(line, p, q - p) ~ ("^(" controlwords ")$")) {
          p = skipblank(q)
          changed = 1
        }
        # The list arrives as a variable rather than standing here as a literal,
        # so that the wrapper anchor can admit the same words without a second
        # copy of them. Issue #79; see CS_WRAP_OPTION_WORDS above.
        #
        # Through cw_spelled since #117, so that a prefix word spelled as a path
        # or in quotes is the prefix word it is. Not the control words above:
        # quoting a RESERVED word takes its reserved meaning away, so bash runs
        # a program named `if` for `"if" true` and the strip is right to stop.
        # The two lists are matched by name and the reserved words are matched
        # as syntax, and that is the whole difference.
        q = tokend(p)
        if (q <= n && cw_spelled(substr(line, p, q - p)) ~ ("^(" wrapwords ")$")) {
          p = skipblank(q)
          while ((q = tokend(p)) <= n && substr(line, p, 1) == "-") p = skipblank(q)
          wrapped = 1
          changed = 1
        }
        # timeout and flock take an operand -- a duration, a lock file -- that
        # is not an option, so stripping only options left it at the head of
        # the line and the command word behind it was never at ^. That made
        # `timeout 30 git push --all origin` invisible to every hook. The
        # operand is stripped with the word, one token and only if it is not
        # itself an option.
        q = tokend(p)
        if (q <= n && cw_spelled(substr(line, p, q - p)) ~ ("^(" operandwords ")$")) {
          p = skipblank(q)
          while ((q = tokend(p)) <= n && substr(line, p, 1) == "-") p = skipblank(q)
          q = tokend(p)
          if (q <= n && q > p && substr(line, p, 1) != "-") p = skipblank(q)
          wrapped = 1
          changed = 1
        }
      }
      # Walked back rather than matched. An expression ending in $ with no ^ is
      # tried from every position, and from each blank it runs to the end of
      # that run before failing on what follows it -- so a long run of blanks
      # anywhere but the end of a line made this quadratic, and one of 256 KB
      # before a final character ran past 30 s, where it takes 78 ms now.
      # Issue #96.
      e = n
      while (e >= p && index(" \t\n\v\f\r", substr(line, e, 1)) > 0) e--
      if (e >= p) printhead(substr(line, p, e - p + 1))
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
      if (wrapped && e >= p) {
        r = p
        for (k = 0; k < 3; k++) {
          c = substr(line, r, 1)
          if (c == "\042" || c == "\047") break
          q = tokend(r)
          if (q > e) break
          r = skipblank(q)
          c = substr(line, r, 1)
          if (c == "\042" || c == "\047") break
          # Every candidate, not only the first. A prefix word stands in front
          # of the command word, so at the point the strip runs the word is
          # still behind it and `sudo /usr/bin/git push` would be normalised
          # nowhere.
          #
          # THE TRADE, TAKEN KNOWINGLY, and it is this pass reaching one word
          # further than the one before it did. A tail candidate is an ARGUMENT
          # offered as a command word, on the argument above that offering
          # cannot hide a command -- and reducing one to its basename turns a
          # path-shaped argument into a name a rule reads. Measured: `sudo cp
          # /usr/bin/pytest /tmp/` offers `pytest /tmp/` and is now refused by
          # pytest-via-uv-group.sh, where the same command without the prefix
          # word offers no tail at all and is permitted.
          #
          # Taken rather than fixed, for the reason the note above gives: it is
          # the refusing direction, the refusal names the permitted spelling,
          # and telling an argument from a command word here is the shell parser
          # the stopping rule in these files refuses to write. It is recorded
          # because a refusal nobody wrote down reads as a defect to whoever
          # meets it. check-hooks.sh pins both verdicts.
          printhead(substr(line, r, e - r + 1))
        }
      }
    }'
}

# THE WORD LIST IS PART OF THE LOAD. With either half of the prefix-word list
# empty, cs_split is withdrawn, so that the load guard of every consumer that
# calls cs_split -- and each of those requires it -- refuses by name. The two #95
# consumers call only cs_tool_input and, for append-only-docs.sh, cs_within_cap,
# and neither reads the list, so they are not reached.
#
# Why it is needed at all. Issue #79 made the list a variable that cs_split
# reads through awk's -v, and that added a state THE LOAD CONTRACT above cannot
# see: every function present, the list empty, and cs_split running and doing
# less. It strips no prefix, so `sudo git push --all origin` has no command word
# at ^ and is permitted -- the verdict the fourth review fixed, silently
# un-fixed. A function that does less is worse than a missing one, which is the
# whole of #84's finding, and a guard that asks whether a name exists cannot
# tell the two apart.
#
# Why here and not in the guards. The first answer to this was a word-list guard
# in two hooks, then an empty CS_WRAPPER_RE as a library fail-safe on the
# argument that two other hooks sourced this file unguarded. Review measured
# both. That guard covered two consumers of four; the fail-safe covered the four
# that read CS_WRAPPER_RE and missed the two convention hooks, which read
# cs_split and never the anchor -- with the list empty `sudo pytest tests/` has
# no pytest at ^ and was permitted. And #84 then made the premise false, by
# guarding every consumer's load. Each was a guard fitted to part of the set
# its comment claimed, which is the #84 shape one level out.
#
# So the state is reduced to one the contract already answers. The list's only
# reader is cs_split; withdrawing it makes an incomplete list indistinguishable
# from a renamed function, and every consumer that could be misled by it -- by
# construction, every one that calls cs_split -- already requires cs_split,
# because check-hooks.sh derives each consumer's required set from its call set.
# Nothing in any guard has to know the list exists, which is what keeps this
# from being one more copy of a question the contract already asks in each of
# them.
#
# "Only reader" is loose, and #134 made it looser, so the premise the argument
# needs is written out instead. CS_WRAPPER_RE reads the prefix words through
# CS_WRAP_WORDS and, since #134, CS_SEPARATORS and CS_CONTROL_WORDS as well, and
# it is not withdrawn. What makes that harmless is that every hook that reads
# the anchor -- the four boundary hooks -- also calls cs_split and requires it,
# so withdrawing cs_split refuses there before the anchor's answer is asked. A
# consumer that read the anchor and not cs_split would reopen this.
#
# It must stand AFTER cs_split's definition, since `unset -f` on a function not
# yet defined does nothing and the definition then restores it. That is a
# position a later edit can break silently, so check-hooks.sh asserts cs_split
# is undefined in a library with the list emptied, and drives every consumer
# against one.
#
# The two halves and not the union: with both empty CS_WRAP_WORDS is the string
# "|", which is not empty.
#
# And the two command-position lists since #134, which cs_split reads the same
# way and which fail worse. With CS_CONTROL_WORDS empty and cs_split left
# running, measured: `then git push` keeps `then` in front of the command word,
# and a blank line never returns -- the strip matches the empty token at its end
# and does not advance, and a hook the harness kills for time is a hook that
# permitted. With CS_SEPARATORS empty nothing is cut, so a second command on a
# line is never at ^.
#
# AND VALID, WHICH IS NOT THE SAME AS NON-EMPTY, and is the half the four tests
# above do not reach and the half that fails open. Both lists are interpolated
# into a regular expression, so a list that is malformed rather than absent
# builds an expression that does not work, and neither reader says so. Found by
# review of PR #172, each measured end to end:
#
#   CS_SEPARATORS holding `[.` or `[=` opens a collating element, so the anchor
#   does not compile and `grep -qE` exits 2. Every consumer's guard reads
#   `if grep -qE "$CS_WRAPPER_RE" && ...`, and a 2 is not a 0, so the whole
#   wrapper rule is skipped: a wrapped `gh pr merge 5` went from BLOCK to ALLOW
#   in no-pr-decisions.sh while the unwrapped command still blocked. A silent
#   and total fail-open.
#
#   CS_CONTROL_WORDS holding a trailing `|` -- the ordinary slip when appending
#   a word to a list #134 made the edit point for both halves -- makes the
#   alternation match the empty string. cs_split's strip advances past whatever
#   it matched, so it matches nothing, advances nothing, and the loop does not
#   end: `printf 'a\n\nb\n' | cs_split` never returned, against exit 0 intact.
#   A hook the harness kills for time has permitted, which the paragraph above
#   says in as many words and did not then test for.
#
# Each list is asked the question BY THE ENGINE THAT WILL ASK IT -- the anchor
# compiled by grep, the control words matched by awk -- and a failure routes to
# the same withdrawal an empty list gets. That is why this is two processes and
# not one pattern of this file's own: what counts as a valid bracket expression
# is grep's answer, and what the strip will match is awk's, and writing either
# down here would be the second answer to a question a reader already answers,
# which is the defect class this file exists to end. The empty line rather than
# a survey of spellings for the same reason: matching the empty string IS the
# property that hangs the strip, so a leading `|`, a `||` and an empty
# alternative anywhere are caught by the same test as a trailing one.
#
# What it does NOT reach, named rather than implied: a list that compiles and
# means something else. `-` between two characters is a valid range, so the
# class still builds and this guard passes it; that one is caught in
# check-hooks.sh, by asking the lists what they hold. Validity here, membership
# there, and neither is the other.
#
# The cost, measured on this machine over 60 loads each: 2.6 ms to source the
# library before, 5.6 ms after, so about 3 ms added to a hook invocation for two
# process spawns. Paid once per hook run, against a rule whose failure is
# silent and total.
#
# WHICH LIST, said here and once. Every consumer's guard refuses with "could not
# load lib/command-scan.sh", which is true of a missing file and of a renamed
# function and is a misdirection here: the library loaded, every function but
# cs_split is defined, and what failed is a list. A reader who appended a word
# with a trailing `|` would be sent to look for a file that is present and
# correct. Naming it in the nine guards would put the answer in nine places, and
# they are right about their own case; the library knows which list it withdrew
# for, so the library says so, on the same stderr the refusal uses and only on
# the path where something is actually wrong. Review of PR #172.
#
# FOR EVERY TRIGGER AND NOT ONE OF THEM. The first version of this named only
# what the two validity guards found, so the four emptiness withdrawals below
# went out silent -- the claim in this paragraph was wider than the code under
# it, which is the third time in this pull request a sentence has been. Each
# trigger sets CS_INVALID_LIST now, and check-hooks.sh asks it of every fixture
# rather than of the two it used to.
#
# THREE STATUSES AND NOT TWO, which the first version of this got wrong in the
# commit that added it. `||` reads every non-zero awk status as the hang case,
# and awk has three: 1 is the `exit 1` below, taken when the list matches an
# empty line; 2 is awk refusing to compile the dynamic regex at all; 127 is awk
# not being on PATH. Measured -- `|[a`, `a(b` and `x{2,1}` each exit 2, and an
# empty PATH exits 127 -- and each was reported as a list that hangs the strip,
# which is the misdirection the message exists to end. Review of PR #172.
#
# The grep branch names the lists CS_WRAPPER_RE is built from rather than two of
# them. It named CS_SEPARATORS and CS_WRAP_WORDS, and a control-word list that
# would not compile sent the reader to inspect two lists that were both correct
# -- the one list this file calls the likely edit point being the one it did not
# name. The enumeration is held to the anchor's own definition by check-hooks.sh,
# so a list added there and not here is red rather than silent.
CS_LISTS_VALID=1
CS_INVALID_LIST=
# EMPTINESS IS A WITHDRAWAL TOO, and naming only the validity ones left three
# of the five triggers silent -- a maintainer who deleted the last prefix word
# from CS_WRAP_OPTION_WORDS, or emptied CS_SEPARATORS, got every Bash hook
# refusing every command with "could not load lib/command-scan.sh" and nothing
# else, which is word for word the failure the paragraph above says it ended.
# Measured before this: emptying CS_CONTROL_WORDS printed a line, emptying any
# of the other three printed none. The block said "the library knows which list
# it withdrew for" and knew it for one trigger of five. Review of PR #172.
#
# Spelled out rather than looped over with eval, which is the only way a shell
# reads a variable whose name it is handed, and is not worth having in a file
# every hook sources. Four lines, the same four the guard below tests, in the
# same order.
[ -n "$CS_WRAP_OPTION_WORDS" ] \
  || CS_INVALID_LIST="${CS_INVALID_LIST:+$CS_INVALID_LIST; }CS_WRAP_OPTION_WORDS is empty"
[ -n "$CS_WRAP_OPERAND_WORDS" ] \
  || CS_INVALID_LIST="${CS_INVALID_LIST:+$CS_INVALID_LIST; }CS_WRAP_OPERAND_WORDS is empty"
[ -n "$CS_CONTROL_WORDS" ] \
  || CS_INVALID_LIST="${CS_INVALID_LIST:+$CS_INVALID_LIST; }CS_CONTROL_WORDS is empty"
[ -n "$CS_SEPARATORS" ] \
  || CS_INVALID_LIST="${CS_INVALID_LIST:+$CS_INVALID_LIST; }CS_SEPARATORS is empty"
printf '' | grep -qE "$CS_WRAPPER_RE" 2>/dev/null
[ $? -le 1 ] || { CS_LISTS_VALID=0
  CS_INVALID_LIST="CS_WRAPPER_RE does not compile, so one of the lists it is built from holds something that is not literal there: CS_SEPARATORS, CS_CONTROL_WORDS, CS_WORD_SPELLING, CS_WRAP_TOKEN or CS_WRAP_WORDS"; }
printf '\n' | awk -v w="$CS_CONTROL_WORDS" \
  '{ if ($0 ~ ("^(" w ")$")) exit 1 }' 2>/dev/null
CS_AWK_STATUS=$?
case $CS_AWK_STATUS in
  0) ;;
  1) CS_LISTS_VALID=0
     CS_INVALID_LIST="${CS_INVALID_LIST:+$CS_INVALID_LIST; }CS_CONTROL_WORDS matches the empty string, which makes the strip advance by nothing and never return" ;;
  *) CS_LISTS_VALID=0
     CS_INVALID_LIST="${CS_INVALID_LIST:+$CS_INVALID_LIST; }awk exited $CS_AWK_STATUS when asked whether CS_CONTROL_WORDS matches an empty line, so that question went unanswered: at 2 the list does not compile as a regular expression, and at 127 awk is not on PATH" ;;
esac
unset CS_AWK_STATUS
if [ -z "$CS_WRAP_OPTION_WORDS" ] || [ -z "$CS_WRAP_OPERAND_WORDS" ] \
   || [ -z "$CS_CONTROL_WORDS" ] || [ -z "$CS_SEPARATORS" ] \
   || [ "$CS_LISTS_VALID" -ne 1 ]; then
  # "every consumer that needs it", and not "every consumer". append-only-docs.sh
  # and append-only-docs-edit.sh source this library for cs_tool_input and
  # cs_within_cap and never call cs_split, so their load guards do not require it
  # and they go on permitting -- measured, append-only-docs-edit.sh exits 0 with
  # a broken control-word list. The first version of this line claimed a refusal
  # on the one path where there is none, printed on every Edit and Write. Review
  # of PR #172.
  [ -z "$CS_INVALID_LIST" ] \
    || echo "lib/command-scan.sh: $CS_INVALID_LIST. cs_split is withdrawn, so every consumer that requires it refuses; the two document hooks need only cs_tool_input and cs_within_cap and are unaffected." >&2
  unset -f cs_split
fi

# THE LINE CAP. A command holding a line longer than 16 KB -- 16384 bytes, once
# backslash continuations are joined -- is refused unread, by every Bash hook,
# before any pass in this file runs over it. Issue #96.
#
# Why a bound and not a fail direction. The harness kills a hook that runs past
# the "timeout" in settings.json, 5 s for every one of these, and a killed hook
# never exits 2, which is the only refusal the harness reads. So time is part
# of a verdict, and a guard whose running time the caller chooses is a guard
# the caller can switch off. It was measured switched off: at dev-05 750aace,
# `echo <300 KB>; git push --force origin main` on one line took the three
# boundary hooks 5.75 to 6.67 s, and was permitted by all three. Nothing inside
# a hook can make the harness kill fail closed, so the only remedy is to never
# be slow, and a bound on what the passes are handed is what keeps them fast
# whatever a later edit to one costs.
#
# WHAT THIS CAP DOES NOT BOUND, which #96 first claimed it did: a hook's running
# time. It bounds the length of a line and nothing else. A hook starts an awk
# or more per fragment cs_split emits, so its time grows with the number of
# fragments as well, and a short line can hold thousands: 2,500 `t;` and a
# `gh pr merge 5` on the next line -- 5,014 bytes, a third of the cap -- took
# no-pr-decisions.sh 6.4 s idle, found by review of PR #123. That is #127.
#
# It does bound what the passes are HANDED, and until #128 it did not. A heredoc
# opener ending in a backslash let cs_normalise emit one 600,400-byte line from
# an input whose longest joined line was 15,011 bytes, because the drop ended
# each body at its terminator and the join then glued forty groups into one
# line. What holds now is an argument and not a measurement: the drop only ever
# REMOVES lines, and it can remove a line next to a continued one only inside a
# body -- a body begins after a line that does not end in a backslash, and the
# lines held for it are given back together. So every joined line cs_normalise
# emits is part of a joined line cs_within_cap measured, and no longer than it.
# That input is pinned at 15,011 in check-hooks.sh, and reverting the fix in a
# copy puts the 600,400 back: mutate-hooks.sh row heredoc-opener-continuation.
#
# Why the passes were slow is fixed too, and is the other half of #96. Six of
# them grew a string one character or one token at a time -- cs_normalise's
# redirect pass, cs_split's separator cut and its prefix strip, cs_join, and
# the option skip in cs_git_args and in cs_gh_args -- and the prefix strip
# also trimmed trailing blanks with an expression mawk retries from every
# position. Each is linear now, and held to identical output: every rewrite was
# fuzzed against the version before it, byte for byte, under mawk and busybox
# awk in the C and a UTF-8 locale and under gawk in C. Not under gawk in a UTF-8
# locale, where the old expressions split on Unicode blanks such as U+3000 and
# the new character walks do not; every difference found there involved such a
# blank, which bash does not split on either. And the fuzz missed one difference
# that review found by reading: a token holding `|`, such as `-c|-C`, in the
# option skip of both argument readers. That is fixed where it stands, and
# check-hooks.sh pins it. Each carries its
# measurement where it stands, and every one of those numbers is from a single
# run -- mawk 1.3.4, LC_ALL=C, fastest of three -- because an earlier set taken
# in a UTF-8 locale ran about twice as slow and did not agree with the rest.
# With the passes linear, one line of 512 KB costs cs_normalise 0.24 s and
# cs_split 0.17 s, against 9.3 and 10.8 s before, so the cap is not what makes a
# hook fast; it is what makes a hook fast whatever a later edit to a pass does.
#
# Why 16 KB. It was decided, not derived (#103, Q28): far past any command an
# agent writes on purpose, and far below the size where the passes cost
# anything. Measured on the linear passes, every hook answers a command whose
# longest line is exactly at the cap in about a tenth of a second -- when that
# line is plain. The same 16 KB cut into 8,192 fragments took no-git-push.sh
# 7.3 s and the other two boundary hooks far longer; see #127.
#
# Why the JOINED line. The passes see a continued line as one, so 3,800 lines
# of 84 bytes each ending in a backslash are one 300 KB line to them -- and
# that took the three boundary hooks 5.7 to 9.7 s before this fix, with no
# physical line anywhere near the cap. A cap on raw lines would never have
# fired on it.
#
# THE SECOND TRADE, which follows from that and was found by review rather
# than chosen: the join does not know what a quoted heredoc is, and bash does
# not join lines inside one. So 300 body lines of 80 bytes, each ending in a
# backslash, are refused as a 24 KB line although no line of the command is
# longer than 80 bytes and bash would never read them as one. Taken rather than
# fixed, because answering it means cs_within_cap deciding where a heredoc
# ends -- the question cs_normalise has got wrong four times, asked a fifth
# time in a second place -- and a body whose every line ends in a backslash is
# not something a commit message or a dev-log entry holds. check-hooks.sh pins
# the refusal.
#
# Why heredoc bodies count. They are dropped by cs_normalise, but that drop is
# a fail-safe that hands the lines back when no terminator arrives, and
# no-pr-decisions.sh reads the raw text as well. A body line past 16 KB is not
# something a commit message or a dev-log entry holds.
#
# THE TRADE, taken knowingly: a legitimate one-line command longer than 16 KB --
# a long `python3 -c`, an inline JSON payload -- is refused, and the refusal
# says what to do instead: split the line, or write the content to a file and
# name the file. check-hooks.sh pins the refusal of exactly that one-liner, one
# byte over, so that raising the cap is a decision and not a surprise.
#
# Bytes, not characters, and LC_ALL=C is what makes it bytes: mawk counts bytes
# anyway, gawk in a UTF-8 locale would count characters, and the cost of every
# pass above is in bytes.
#
# FAIL-CLOSED BY CONSTRUCTION, because this is a function the load contract has
# to reach: cs_within_cap succeeds only when every line is within the cap AND
# both halves of its pipeline succeeded. A library missing cs_join therefore
# makes it fail -- which refuses -- where reading only awk's status would have
# counted the lines of no input at all and passed everything. And it is called
# as `if ! ... | cs_within_cap`, so a consumer whose copy of it is missing
# refuses on the 127 as well as through its guard.
CS_LINE_CAP=16384
CS_LINE_CAP_REFUSAL="a line of this command is longer than 16 KB (16384 bytes, with backslash continuations joined), which is refused unread: a hook still reading it when the harness timeout kills it would permit it. To run it, split the line, or write the content to a file and pass the file."
cs_within_cap() {  # stdin: a command. Succeeds only if no joined line exceeds the cap.
  cs_join | LC_ALL=C awk -v cap="$CS_LINE_CAP" 'length($0) > cap + 0 { over = 1; exit } END { exit over }'
  [ "${PIPESTATUS[0]}:${PIPESTATUS[1]}" = "0:0" ]
}

# Print the arguments of a git subcommand and succeed, or print nothing and fail
# if this command is not `git <subcommand>`. Global options are skipped,
# including the ones that take a separate value: without that, -C /path ends the
# match before the subcommand is reached.
#
# WHICH GLOBAL OPTIONS TAKE A SEPARATE VALUE is a fixed, documented set, and git
# rejects an unknown global option itself -- `git --bogus push origin main`
# exits with `unknown option: --bogus` and pushes nothing -- so git has no
# counterpart of THE UNREADABLE GH SHAPE that cs_gh_opaque refuses below. #118
# ruled git out of that shape, and out of that shape only.
#
# WHAT THIS WALK DOES CARRY, because the sentence here used to say "it has only
# the question of whether this list is complete" and that was not true. #118's
# own Scope paragraph asked for the measurement before git was ruled in or out;
# round 2 of the review of PR #184 made it, and ten commands came back permitted
# that reach the transport. The two classes are the two the gh walk was fixed
# for, and this one got neither:
#
#   A. A fragment boundary read as a command boundary. skipopts consumes a value
#      token that may not be there, so a valued global standing last in a
#      fragment -- what cs_split leaves when it cuts at a substitution -- eats
#      past the end, the line goes empty and the subcommand is never matched.
#      ``git -C `echo .` push origin main`` is permitted.
#   B. An option compared as raw text. `substr(line, p, 1) != "-"` returns on
#      the first quoted or escaped option, so the walk stops in front of it.
#      `git "-c" u.e=x push origin main` is permitted.
#
# Both are pre-existing -- identical verdicts at dev-05 -- and both are #191,
# which carries the twelve measured rows and the acceptance criteria. They are
# named here rather than left to the issue because this is the comment that
# rules git out, and a reader who stops at it should not stop believing there is
# nothing else to ask. cs_gh_opaque answers A with its k==1 guard and B with
# ghreduce; when #191 lands, one of those answers has to serve both walks rather
# than being written a second time here.
#
# The completeness question is real as well, and #118 found the list two short.
#
# Measured on git 2.43.0, by running `git <option> <value> version` for every
# option `git help git` lists under OPTIONS and asking whether the version still
# printed. Seven do take a separate value; the list below is those seven:
#
#   -c  -C  --git-dir  --work-tree  --namespace  --config-env  --attr-source
#
# `--config-env` and `--attr-source` are #118's two. Without them
# `git --config-env x.y=HOME push origin main` and `git --attr-source HEAD push
# origin main` read as commands whose subcommand is the option's own value, so
# neither was a push to any of the three hooks that ask, and git ran both.
#
# `--exec-path` is the eighth entry and is NOT one of the seven: bare
# `git --exec-path /usr/bin version` prints `/usr/lib/git-core` and exits, so the
# option queries rather than consumes. It is kept because dropping it would
# refuse `git --exec-path push origin main`, which git does not run as a push
# either -- it prints the path and exits -- and because what it costs while it
# stays is that same command being permitted, which is a permission to run
# nothing. The `=` spelling, `--exec-path=/x push origin main`, carries its own
# value and is refused as a push whichever list this is.
#
# The `=` spellings of all eight need no entry: a token carrying its own value
# is skipped as a valueless option and the subcommand behind it is reached.
#
# The exit status is what distinguishes `git push` -- a push whose argument list
# is empty, and the permitted shape -- from a command that is not a push at all.
# A caller testing the printed text instead would have to re-derive the rule,
# which is the habit this file exists to end.
cs_git_args() {
  awk -v want="$1" '
    # The global options are skipped by moving p past them rather than cutting
    # the line down after each one: every cut copied the rest of the line, so
    # a long run of options was quadratic. Issue #96. What is skipped is what
    # the expression it replaced matched at the head of the line -- any token
    # of two or more characters that opens with a dash and has blanks after it,
    # and for the options named in VALUED the value token behind it too, when
    # that value has blanks after it in turn. The same two helpers stand in
    # cs_split and in the other argument reader: an awk program cannot source
    # another, and a shared definition passed in as a variable would be one
    # more thing a load could leave empty.
    function tokend(i) { while (i <= n && index(" \t\n\v\f\r", substr(line, i, 1)) == 0) i++; return i }
    function skipblank(i) { while (i <= n && index(" \t\n\v\f\r", substr(line, i, 1)) > 0) i++; return i }
    function skipopts(valued,    q, r) {
      while (1) {
        q = tokend(p)
        if (q > n || q - p < 2 || substr(line, p, 1) != "-") return
        r = substr(line, p, q - p)
        p = skipblank(q)
        # A token holding "|" is never one name, and index() would find
        # `-c|-C` in the list as readily as `-c`; the expression this replaced
        # matched a name, so that token took no value behind it there either.
        if (index(r, "|") == 0 && index(valued, "|" r "|") > 0) {
          q = tokend(p)
          if (q > p && q <= n) p = skipblank(q)
        }
      }
    }
    BEGIN { found = 0 }
    {
      line = $0
      if (line !~ /^git([[:space:]]|$)/) next
      sub(/^git[[:space:]]*/, "", line)
      n = length(line)
      p = 1
      skipopts("|-c|-C|--git-dir|--work-tree|--namespace|--exec-path|--config-env|--attr-source|")
      line = substr(line, p)
      if (line !~ "^" want "([[:space:]]|$)") next
      sub("^" want "[[:space:]]*", "", line)
      print line
      found = 1
      exit
    }
    END { exit(found ? 0 : 1) }'
}

# THE UNREADABLE GH SHAPE, stated here and nowhere else, so that every hook
# judging a gh path inherits one answer and none re-derives it. Issue #118.
#
# gh resolves a subcommand path at the first non-flag argument, and cobra gives
# the next word as a value to every option it cannot show is a boolean -- one it
# does not know, LONGHAND OR SHORTHAND, as well as one that takes a value. That
# is cobra's stripFlags: `hasNoOptDefVal` answers false for a flag it cannot look
# up, so the word after it is dropped from the path. Which subcommand is RESOLVED
# is decided there; whether it then RUNS is decided by the option parse after
# it, against the resolved subcommand's own flags. So `gh pr --squash view 5`
# resolves `gh pr` itself, `view` eaten, and prints `unknown flag: --squash`
# with `gh pr`'s usage.
#
# This paragraph said the opposite until round 6 of the review of PR #184: that
# an unknown longhand "is treated as a boolean and eats nothing", measured on gh
# 2.45.0 from `unknown flag: --squash`. That message is printed whichever way
# the word goes, so it could not tell the two readings apart; the usage block
# after it can, and it is `gh pr`'s. The review ran `gh pr --squash view --help`
# on gh 2.45.0 and got `gh pr`'s usage, as `gh pr -t view --help` does. The
# answer to that round read the same in stripFlags -- cobra v1.8.1, from a local
# module cache and not gh's own build -- and did not run gh: no-pr-decisions.sh
# refuses that command, and no route round the refusal was taken. No verdict
# moved, the rule refusing the shape in both spellings.
#
# `-t` (`--template`) is value-taking at every group level, so
# `gh pr -t view merge 5` runs the merge, `gh pr -t
# view view 5` runs a view that then complains `--template` needs `--json`, and
# `gh release -t list create v1` runs the create. That last one is not a
# hypothetical: verifying the issue, an agent ran it and it created a real
# release on this repository.
#
# So the word a hook reads as the subcommand is not the word gh runs. The answer
# is NOT to model which options take a value -- that is gh's own flag definition
# for each group, a list #97 decided against keeping and one that a new gh
# release moves. The answer is to refuse the shape: an option standing before a
# word of a guarded subcommand path, other than the three that name where the
# command acts rather than what it does and the two root flags gh prints, makes
# the command unreadable, and an
# unreadable command is refused the way a wrapped one is. The hook does not
# guess the verb.
#
# The three exceptions are -R, --repo and --hostname, in every spelling: the
# bare form taking its value as the next word, and the forms carrying it --
# `--repo=o/r`, `--hostname=h`, `-R=o/r`, `-Ro/r`. Beside them the walk
# recognises the two root flags and nothing else: --help at every level, and
# --version in front of the group only, for the reasons written at ghopt. So
# the whole set is those five, one of them at one position; every statement of
# it -- the refusal below, GH-118's text, CLAUDE.md's ninth consequence -- names
# all five, which round 8 of the review of PR #184 found the first three did
# not. Nothing else is recognised, `--` and an unknown longhand included,
# because the point is not to be right about cobra but to stop reading where
# being right stops being possible.
#
# THE TRADE, TAKEN KNOWINGLY. This refuses harmless reads too: `gh pr --json
# title view 5` is a view, and it is refused. Before the decision, 37,597 past
# Bash commands from this project's sessions were searched for a pre-subcommand
# option on a guarded group; the only two were commands written while developing
# these hooks, `gh pr --limit=1` and `gh issue --bogusflag=1`. No real use is
# lost, and the correction is one edit -- the option goes after the subcommand,
# `gh pr view 5 --json title`, which is where it is written anyway.
# check-hooks.sh pins the refused read as a check, so the trade is evidence and
# not only this paragraph.
#
# The second part of the trade is paid on these files themselves, and it is
# CLAUDE.md's deliberately-left-open consequence 3 rather than anything new: a
# quoted multi-line string whose continuation line begins with one of these
# commands is refused although it is only prose. What #118 adds to that class is
# the READS -- a line of check-hooks.sh carrying `gh pr -t view view 5` is
# refused where `gh pr view 5` alone is not. Write such a file with an editor
# rather than through a shell heredoc.
#
# WHAT IT DOES NOT REACH. An option after the whole path belongs to the verb and
# is untouched. A group no hook guards is untouched at its verb position, so
# `gh issue -t list list` stays permitted -- the shape is there, and nothing
# behind it is a decision this repository withholds. The position BEFORE the
# group is not a group's, so an unreadable option there is refused whatever
# follows it, `gh --squash view pr merge 5` and `gh --bogus x issue list` alike:
# with the group eaten, which group it was is exactly what cannot be read.
# `gh --version` and `gh --help` are permitted because ghopt RECOGNISES those
# two, not because of where they stand. It used to be because of where they
# stood -- an option last on the line consumes nothing -- and review round 1
# showed that position is a property of a command and not of the fragment a
# tokeniser hands over. See THERE IS NO LAST-TOKEN EXEMPTION in ghopt.
#
# THAT LAST CLASS IS ARGUED AND NOT MEASURED, and the difference is worth the
# sentence. The 37,597-command search above asked for a pre-subcommand option on
# a GUARDED group, so `gh --paginate issue list` and its like were outside what
# it counted. The argument for refusing them is the one above -- a group that
# may have been eaten is not a group this can call unguarded -- and it is an
# argument, where the guarded half has a number. Found by review of this change.
#
# A bare `-` is not an option here and is not this rule's: it is one character,
# so the walk stops on it and reads it as a subcommand that matches nothing,
# leaving `gh pr - merge 5` permitted. gh does NOT stop on it. stripFlags
# collects a path word only when it does not open with `-`, and treats a word
# as an option only at two characters or more, so a lone `-` is neither and is
# skipped: `gh pr - merge` resolves `merge`, which the review of PR #184 ran as
# `gh pr - merge --help` on gh 2.45.0 and got merge's usage. What then stops
# `gh pr - merge 5`, if anything does, is after resolution and has not been
# measured. That is #241's class, a token gh never sees counted as a position,
# and #241 carries it. This paragraph said "`gh pr -` is no subcommand and gh
# says so" until round 6 of that review. The walk's behaviour predates #118, the
# same length test having always ended the skip.
CS_GH_OPAQUE_REFUSAL="Blocked: this gh command writes an option before its subcommand, and gh gives an option it does not know as a boolean the next word as a value -- so the subcommand a hook reads here is not the one gh would run. Refusing rather than guessing it. Move the option after the subcommand: gh pr view 5 --json title, gh release list --limit 5. Only -R, --repo, --hostname and --help may stand in front of a subcommand, and --version in front of the group."

# THE ONE WALK, shared by cs_gh_args and cs_gh_opaque. They ask two questions of
# the same walk, and round 1 of Bertan review of #118 found what happens when
# they are two programs: the option classification was written twice and the
# comment beside each said it was written once.
#
# It is a variable rather than two copies for the reason the top of this file
# gives, and it is part of the load in the sense THE WORD LIST IS PART OF THE
# LOAD gives that phrase. See the withdrawal below both functions.
#
# It also answers the cost that review measured. Asking the two questions as two
# programs meant cs_gh_args read stdin into a variable and piped it twice --
# three processes where there had been one -- and the hook went from 63 ms to
# 167 ms on a three-command line. One program is one process again.
#
# THE CONTRACT, and it is not quite the one cs_gh_args had. The first gh line
# that is EITHER unreadable OR a match for the path decides; a line that is
# neither is scanned past. It used to be "the first match decides", which could
# not see an unreadable line at all. Every caller here feeds one command at a
# time, so the difference is reachable only from check-hooks.sh -- it is written
# down because the old sentence was left standing by the first version of #118.
#
#   mode=args    the deciding line is a match     -> print its arguments, exit 0
#                the deciding line is unreadable  -> print nothing, exit 0
#                no line decides                  -> print nothing, exit 1
#   mode=opaque  the deciding line is unreadable  -> exit 0
#                anything else                    -> exit 1
CS_GH_AWK='
  function tokend(i) { while (i <= n && index(" \t\n\v\f\r", substr(line, i, 1)) == 0) i++; return i }
  function skipblank(i) { while (i <= n && index(" \t\n\v\f\r", substr(line, i, 1)) > 0) i++; return i }
  # THE SPELLING OF AN OPTION, reduced before it is classified, and a narrower
  # reducer than cw_reduce in cs_split on purpose. Review round 1 measured
  # `gh pr "-t" view merge 5`, its single-quoted spelling and `gh pr \-t view
  # merge 5` as permitted, and all three reach gh as `gh pr -t view merge 5`,
  # which is a merge: the walk tested the raw first character for a dash, so a
  # quote in front of the option ended it. Quotes and backslashes come out of
  # the token first. cw_reduce is not reused because it also reduces a path to
  # its basename, which would read --repo=o/r as r. This reduces the OPTION
  # spelling and not the path words, so `gh "pr" merge 5` is untouched and stays
  # #135 to answer.
  function ghreduce(t,   o, c, i) {
    o = ""
    for (i = 1; i <= length(t); i++) {
      c = substr(t, i, 1)
      if (index(strip, c) == 0) o = o c
    }
    return o
  }
  # 0 not an option, so the walk stops; 1 the option takes the next word;
  # 2 it carries its own value; 3 unreadable, which is THE UNREADABLE GH SHAPE.
  # WHICH OPTIONS ARE RECOGNISED IS DECIDED HERE AND NOWHERE ELSE, and since
  # this program is the whole of both functions that is a statement about the
  # file and not about one function in it.
  #
  # THERE IS NO LAST-TOKEN EXEMPTION, and there was one until review round 1. It
  # read "a token with no blank behind it is the last word of the line and
  # consumes nothing", which is true of a COMMAND and false of what this is
  # handed. cs_split cuts at a backtick, so a command whose option is followed
  # by a command substitution arrives as a fragment ending in that option, the
  # option is last, and the walk stopped before judging it. Measured: that
  # command was permitted and the shell expands it to the merge this rule exists
  # to refuse, while the $( ) spelling of the same command was refused -- two
  # spellings of one command disagreeing.
  #
  # --version AND --help ARE THE PRICE OF DROPPING IT, and they are recognised
  # here rather than paid. Without them `gh --version` is unreadable and
  # refused, and it is a command agents actually write: 23 of them in 100,929
  # Bash commands taken from 861 local session transcripts, against 3 for every
  # other non-repo option in that position put together, all three of those
  # written while developing these hooks.
  #
  # IT IS A LIST OF gh BOOLEANS AND SAYING OTHERWISE WOULD BE THE EVASION, so
  # here is why this one is not the list #97 refused. That list was gh flag
  # definitions PER GROUP -- what --draft means to `release edit` against what
  # it means to `release` -- which a gh release moves and which has to be
  # tracked. These two are the ROOT flag set, which `gh help` prints in two
  # lines and which has not changed: gh 2.45.0 defines --help and --version
  # there and nothing else. Both print and exit, so recognising them cannot hide
  # a verb behind a value they never take -- AT THE ROOT, which is the half
  # this said without saying. --help is a persistent flag, known at every level;
  # --version is the root own, so below the root it is an option gh cannot look
  # up, and by THE UNREADABLE GH SHAPE it eats the next word. Round 7 of the
  # review of PR #184 measured it on gh 2.45.0: `gh release --version view
  # --help` prints release usage with `unknown flag: --version`, view eaten,
  # while `gh release --help view --help` prints view help. So
  # `gh release --version view delete v1` resolves `release delete` and was
  # permitted here as a read. gh then rejects the flag and nothing runs, but
  # that second step is the one this rule does not model. So --version is
  # recognised in front of the group only, `atroot`, and --help everywhere.
  # Everything else at the root stays unreadable, -h included, because cobra
  # registering it is a thing to measure and not a thing to assume; round 7
  # measured it below the root, where it eats as --version does.
  function ghopt(t) {
    t = ghreduce(t)
    if (length(t) < 2 || substr(t, 1, 1) != "-") return 0
    if (t == "-R" || t == "--repo" || t == "--hostname") return 1
    if (t == "--help" || (t == "--version" && atroot)) return 2
    if (t ~ /^--repo=/ || t ~ /^--hostname=/ || t ~ /^-R./) return 2
    return 3
  }
  # THE VALUE A RECOGNISED OPTION CARRIES IN ITS OWN TOKEN, into `att`: after the
  # `=` of --repo= and --hostname=, and after -R, with the `=` pflag takes off
  # the value of a shorthand taken off too. Succeeds only for those spellings, so
  # --version and --help, which return 2 and carry nothing, are not asked.
  function ghattached(t) {
    t = ghreduce(t)
    if (t ~ /^--(repo|hostname)=/) { att = substr(t, index(t, "=") + 1); return 1 }
    if (t ~ /^-R./) { att = substr(t, 3); sub(/^=/, "", att); return 1 }
    return 0
  }
  # AN UNFINISHED WORD, which is what a cut leaves where a value was: nothing
  # after reduction, or a word ending on the character that opened the
  # substitution. One test for both places a value is written -- the next word
  # and the option own token -- because round 5 of the review found it asked of
  # the first only: `gh pr -R $(echo o/r) merge 5` was refused and
  # `gh pr --repo=$(echo o/r) merge 5` permitted, both a merge of PR 5. The table
  # under A STUMP IS AN INCOMPLETE WORD below says what each cut leaves.
  function unfinished(v) { return v == "" || v ~ /[$<>]$/ }
  BEGIN { strip = sprintf("%c%c%c", 34, 39, 92); nparts = split(want, part, /[[:space:]]+/) }
  {
    line = $0
    if (line !~ /^gh([[:space:]]|$)/) next
    sub(/^gh[[:space:]]*/, "", line)
    opaque = 0
    matched = 1
    for (i = 1; i <= nparts; i++) {
      atroot = (i == 1)
      n = length(line)
      p = 1
      while (p <= n) {
        q = tokend(p)
        tk = substr(line, p, q - p)
        k = ghopt(tk)
        if (k == 0) break
        if (k == 3) { opaque = 1; break }
        # The attached value, asked what the separate one is asked below. A
        # backtick after `--repo=` leaves the token `--repo=` and so an empty
        # value; `$(` leaves `--repo=$`. Both are a value in another fragment.
        if (k == 2 && ghattached(tk) && unfinished(att)) { opaque = 1; break }
        p = skipblank(q)
        # A RECOGNISED VALUED OPTION NEEDS A VALUE, and round 2 of the review
        # found this line eating past the end of a fragment when it has none.
        # It is the same defect THERE IS NO LAST-TOKEN EXEMPTION closed, left
        # standing for the three options the walk recognises: cs_split cuts at a
        # substitution, so `gh pr -R ` + backtick + `echo o/r` + backtick +
        # ` merge 5` arrives as `gh pr -R`, the value was consumed from nothing,
        # the line went empty, the path did not match and the caller read
        # permit. The shell ran the merge.
        #
        # Two spellings of the cut and they do not leave the same fragment,
        # measured: a backtick leaves the option last with no token behind it,
        # and $( leaves a lone `$` where the value would be. Both mean the value
        # is in another fragment, so both are unreadable. A `$` on its own is
        # nobody repository, host or config value, so reading it as a stump
        # costs nothing.
        #
        # What this deliberately does NOT do is refuse a fragment that merely
        # ENDS after a value it really has. `gh release -R o/r` is the whole of
        # its command, gh runs no verb for it, and the release allowlist already
        # refuses it with the message that names the five reads -- which is the
        # right message, where "move the option after the subcommand" would name
        # a subcommand that is not there.
        # A STUMP IS AN INCOMPLETE WORD, and that is the rule rather than a list
        # of the stumps seen so far. Round 3 of the review found the first
        # version of this guard comparing the stump as RAW TEXT while the option
        # token beside it went through ghreduce -- Class B reappearing inside
        # the fix for Class A, and the same disagreement that made round 1 a
        # defect: `gh pr -R $(echo o/r) merge 5` was refused and its quoted
        # spelling permitted, both reaching gh as a merge of PR 5.
        #
        # Reducing the stump was the fix proposed, and it is not enough. What
        # cs_split leaves in the value position, measured over every spelling:
        #
        #   gh pr -R `...`          ->  (no token at all)
        #   gh pr -R $(...)         ->  $
        #   gh pr -R "$(...)"       ->  "$        reduces to  $
        #   gh pr -R "`...`"        ->  "         reduces to  (empty)
        #   gh pr -R <(...)         ->  <
        #   gh pr -R >(...)         ->  >
        #   gh pr -R foo$(...)      ->  foo$
        #
        # A list of those is a list, and the last row is the one that says so:
        # the shell hands gh `foobar` there and runs the merge, and no guard
        # written as `== "$" || == ""` sees it. What every row has in common is
        # that the cut left a word that is not finished -- it ends on the
        # character that opened the substitution, or the quote that held it is
        # gone with the rest. So the test is that shape: nothing left after
        # reduction, or a reduced word ending on one of the three characters a
        # `(` cut can leave behind. No repository, host or config value ends on
        # one of those, so it costs nothing.
        #
        # This closes <( ) and >( ) as well, which round 3 left to judgement on
        # the grounds that gh rejects /dev/fd/63 as a repository and so buys a
        # broken command rather than a merge. That is true and it is not the
        # reason to leave them: enumerating which stumps are worth refusing is
        # the list this comment just argued against keeping.
        if (k == 1) {
          q = tokend(p)
          val = ghreduce(substr(line, p, q - p))
          if (q <= p || unfinished(val)) { opaque = 1; break }
          p = skipblank(q)
        }
      }
      if (opaque) break
      line = substr(line, p)
      if (line !~ "^" part[i] "([[:space:]]|$)") { matched = 0; break }
      line = substr(line, length(part[i]) + 1)
      sub(/^[[:space:]]*/, "", line)
    }
    if (opaque) { unreadable = 1; decided = 1; exit }
    if (!matched) next
    decided = 1
    if (mode == "args") print line
    exit
  }
  END {
    if (mode == "opaque") exit(unreadable ? 0 : 1)
    exit(decided ? 0 : 1)
  }'

# Does an unreadable option stand before a word of this gh subcommand path?
# Succeeds when it does. The path is given as cs_gh_args takes it, and the
# positions asked about are that path own words: `api` is one word, so only the
# position before it is read, and `gh api -X POST repos/o/r/pulls` is an api
# call with options of its own rather than an unreadable command.
#
# The verb a two-word path names does not change the answer, because the
# position before the verb is read before the verb is compared. So one verb
# stands for every verb of its group, and a caller guarding a whole group asks
# once rather than once per rule.
cs_gh_opaque() {  # cs_gh_opaque <subcommand path> -- stdin: one command
  awk -v mode=opaque -v want="$1" "$CS_GH_AWK"
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
# THE THIRD OUTCOME, #118. Two outcomes were "is this path", which prints the
# arguments and succeeds, and "is not", which prints nothing and fails. There is
# now a third, "cannot tell": the command carries an option that THE UNREADABLE
# GH SHAPE above refuses, so which subcommand gh would run cannot be read out of
# it. It is signalled as success with no arguments, which is to say it is
# spelled like the outcome a caller refuses on, and NOT like the outcome a
# caller skips past. A caller writing the ordinary `ARGS=$(cs_gh_args ...) ||
# continue` and asking nothing further therefore refuses an unreadable command
# rather than permitting it, which is the one property this signalling was
# chosen for. check-hooks.sh drives that caller and pins it.
#
# It is spelled that way and not as a status of its own because a status is
# something `|| continue` collapses into "is not", and "is not" permits. That is
# the direction every defect in the list at the top of this file went.
#
# THE ONE CALLER THIS IS NOT ENOUGH FOR, named rather than left to be found.
# release_is_read() in no-pr-decisions.sh is the single place where SUCCESS
# means permit -- it asks whether a command is one of five reads -- so there
# "cannot tell" spelled as success would grant the read. That caller asks
# cs_gh_opaque itself, first, and says so. A caller of that shape is the shape
# to look for when adding one.
#
# IT AND cs_gh_opaque ARE ONE PROGRAM, CS_GH_AWK above, asked two questions
# through `mode`. The first version of #118 had them as two, with cs_gh_args
# calling cs_gh_opaque and then running its own walk; review measured what that
# cost -- three processes a call, 63 ms of hook latency becoming 167 ms -- and
# found that the classification had been written twice after all, in the skip
# list this function used to pass its own skipopts. One program is one process
# and one list.
#
# IF THAT PROGRAM IS EMPTY both functions are withdrawn, below, so the state a
# `command -v` guard cannot see becomes the one it can. That matters in both
# directions and the first draft of this paragraph only had one. A rule whose
# match REFUSES fails loudly when a `cs_*` name is missing, which is the
# direction #84 asks for. A rule whose match GRANTS does not: a caller that asks
# cs_gh_opaque, gets 127 from a name that is not there and reads only "not
# opaque" would go on to be told "cannot tell" as success and grant the read.
# release_is_read in no-pr-decisions.sh is that caller and reads the status as
# 1-or-nothing for exactly this reason. Found by review, not by the suite.
#
# IT ANSWERS ABOUT THE FIRST LINE IT CAN DECIDE, which since #118 means the
# first gh line that is either a match or unreadable -- not simply the first
# match. A caller that hands it a whole command list therefore still loses every
# command after that one, which is the fifth defect in the list at the top of
# this file, so a caller feeds it one command at a time as no-git-push.sh does
# with cs_split output. The check suite pins that the later match is lost, and
# pins which of the two kinds of line did the deciding.
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
cs_gh_args() {  # cs_gh_args <subcommand path> -- stdin: one command
  awk -v mode=args -v want="$1" "$CS_GH_AWK"
}

# THE WALK IS PART OF THE LOAD, and this is #79 answer to the same question one
# function along. What an empty CS_GH_AWK actually does was measured rather than
# reasoned, because the first version of this paragraph reasoned it and was
# wrong: an empty program is a VALID awk program that reads its input and does
# nothing, and it exits 0. So cs_gh_args answers "cannot tell" for every path
# and cs_gh_opaque calls every command unreadable -- every gh rule refuses,
# which is loud and is the safe direction rather than the dangerous one.
#
# The withdrawal below is kept anyway, and is belt and braces rather than the
# thing standing between an empty variable and a permitted merge. It turns a
# state no `command -v` guard can see into one every consumer already guards, so
# the refusal names the library instead of arriving as every gh command being
# refused for no stated reason. check-hooks.sh drives the emptied variable and
# asserts which direction it fails in.
#
# IT COVERS THE HARMLESS STATE OF TWO, and the sentence above said "a state"
# as though there were one. A CS_GH_AWK that does not COMPILE is the other:
# awk exits 2 without reading, cs_gh_args fails, every caller reads "not this
# path", and every gh rule permits. Measured -- one extra `{` on the first
# function line and `gh pr merge 5` and `gh pr create --base main` are both
# permitted. The suite goes red on it, so it is not silent there; the exposure
# is a live session between saving such a file and the next run. Nothing here
# checks that a program compiles, for this one or for the other awk programs in
# this file, and #242 owns that for all of them. Found by round 5 of the review
# of PR #184.
#
# AND IT SAYS WHICH VARIABLE IT WITHDREW FOR, which the first version of this did
# not: a consumer's guard names the library and nothing inside it, and #134.1
# made every withdrawal of cs_split name its list for exactly that reason. That
# rule arrived on the other side of the merge of dev-05 at 5d95c8a, and the
# check #134.1 wrote to keep a new trigger from going out silent read this guard
# as one and went red -- the rule doing its job one guard further than it was
# written for. The line is built the way that guard's lines are, so the check
# reads it without a second pattern.
if [ -z "$CS_GH_AWK" ]; then
  CS_INVALID_LIST="CS_GH_AWK is empty"
  echo "lib/command-scan.sh: $CS_INVALID_LIST. cs_gh_args and cs_gh_opaque are withdrawn, so every consumer that requires them refuses." >&2
  unset -f cs_gh_args cs_gh_opaque 2>/dev/null
fi

#!/bin/bash
# CLAUDE.md: docs/dev-log/, docs/lessons-learned/ and docs/eval-reports/ are
# append-only. "Old entries are history — corrections go in the newest entry,
# never backwards."
#
# Adding a new entry file is the normal case and stays allowed; so does a >>
# append. What is blocked is destroying or rewriting what is already recorded.
#
# docs/research/ was considered for this set and deliberately left out (issue
# #61). A research document carries [NEEDS OBSERVATION] markers, and clearing
# one as the observation is made is the edit the directory exists to allow;
# CLAUDE.md's table marks it "revised in place" for that reason. The same is
# true of docs/design/. See the companion note in append-only-docs-edit.sh.
#
# Issue #69: the directory pattern required a trailing slash, so the removal
# that destroys the most history was the one thing this hook did not see.
# `rm -rf docs/dev-log` was permitted and `rm -rf docs/dev-log/` refused -- the
# same command, one character apart, opposite verdicts, and the permitted half
# takes every entry with it. The boundary is written out now instead: a slash,
# or any character that cannot continue a path name, or the end of the string.
# It is not simply made optional, because `docs/dev-logbook/` is a different
# directory and must stay untouched.
#
# Issue #95: the command was read with its own `jq -r`, so jq missing or a tool
# call that was not JSON left it empty and every overwrite permitted. It is read
# through cs_tool_input now, the reader every hook shares; see THE INPUT READ in
# lib/command-scan.sh. Issue #96 is the other function this file takes from the
# library: every Bash hook runs under the 5 s timeout in settings.json, a hook
# the harness kills permits, and the cap on line length that stops that is
# answered once, there. Its grep passes answered a 300 KB line in 0.03 s and
# were never the risk; the cap is here because a rule that reaches every Bash
# hook but one is the shape #84 was filed against. This file still matches paths
# where they stand rather than through the tokeniser, and over three readings of
# the command (#156). Every rule below is a grep, grep matches within a line, and
# each destroying rule wants the verb and the path on one: `truncate -s 0 \`, a
# newline and an entry was permitted, and so were rm, mv, cp, tee, the
# truncating `>`, and sed or perl with a continuation before its `-i`.
# no-pr-decisions.sh joins for the same reason.
#
# THREE READINGS, and the hook refuses if any one is refused. judge_text holds
# the rules and is called on each.
#   - RAW, the command as it came. It is the hook as it was before #156, so
#     everything refused then is refused now, by construction.
#   - JOINED, by cs_join, the third function this file takes. cs_join joins
#     every trailing backslash, which closes each continuation #156 was filed
#     for, and more: see the trade below.
#   - AS BASH JOINS, by join_as_bash below: a line is continued only on an odd
#     run of trailing backslashes, and never when a comment holds its backslash.
#     The first two alone left a composite open (review of PR #329, round 3). A
#     line bash does not continue -- `echo done \\`, or `# tidy\` -- and then
#     `rm -f \`, a newline and an entry: the raw reading never has the verb and
#     the entry on one line, and the joined one glues `rm` onto the word before
#     it, where the verb rule's boundary is gone. Bash runs `rm -f` on the
#     entry. This reading has both: the line it did not continue keeps its end,
#     and the one it did is joined. The same class gave #156's first version,
#     which read the joined text alone, a hole where dev-05 had none; that is why
#     RAW is kept rather than replaced.
#   Every join join_as_bash makes, cs_join makes too, so its text only ever
#   gives back a boundary the joined text glued away. It adds refusals and can
#   take none from the other two, which is why its limits cost nothing that is
#   refused today: a `#` opening a word inside quotes reads as a comment here, so
#   a line bash does continue is not joined. Measured, that leaves one shape
#   open, and it was open before #156 too: a line bash does not continue, then a
#   destroying command whose continued line carries such a `#` --
#   `echo done \\`, a newline, `rm -f "a #x" \`, a newline and an entry. A `#`
#   straight after the quote, `"#x"`, opens no word and is joined.
#   Where #337 makes cs_join itself bash's join, the second and third readings
#   become one.
#
# The trade, taken knowingly, and only in the refusing direction because of the
# raw reading. The joined reading is the rules dev-05 had, read over the command
# with each line-ending backslash and its newline taken out, so it gives any
# command the verdict dev-05 gave that text. Where bash joins too, unquoted or
# in double quotes, that is the one-line verdict, and its looseness with it: the
# verb rule reads a verb anywhere before an entry, prose and arguments included,
# which is #237's shape. Where bash does not join -- single quotes, a comment, a
# quoted heredoc's body, an escaped backslash -- it is the verdict of a line bash
# never runs: a destroying verb or a `>` anywhere on a line that ends in a
# backslash, and an entry named on the next, is refused. `rm -f tmp.txt  # clean
# \` over `cat` an entry is refused, and so is the append this directory exists
# for, `cat >>` an entry from a quoted heredoc whose body has a Markdown hard
# line break after a line that mentions `rm`. And a continuation inside a name,
# `docs/dev-log\`, a newline and `book`, which a shell reads as
# `docs/dev-logbook`, is refused, as it was before #156: the raw reading sees the
# backslash stand where the boundary group matches it. checks/GH-156.sh pins
# each of these. The library is tested for before it is sourced, and all three
# of its functions after, for THE LOAD CONTRACT's reason.
LIB="$(dirname "$0")/lib/command-scan.sh"
[ -r "$LIB" ] && . "$LIB"
if ! command -v cs_tool_input >/dev/null 2>&1 \
   || ! command -v cs_join >/dev/null 2>&1 \
   || ! command -v cs_within_cap >/dev/null 2>&1; then
  echo "Blocked: append-only-docs.sh could not load lib/command-scan.sh, so it cannot read the command it was handed, join its continuations, or hold the line cap every Bash hook holds. Refusing rather than permitting." >&2
  exit 2
fi

COMMAND=$(cs_tool_input command) || exit 2
# THE LINE CAP, in lib/command-scan.sh: a line longer than 16 KB is refused
# before any pass reads it, because a hook still reading when the harness
# timeout kills it permits. Issue #96.
if ! printf '%s\n' "$COMMAND" | cs_within_cap; then
  echo "Blocked: append-only-docs.sh: $CS_LINE_CAP_REFUSAL" >&2
  exit 2
fi
# Both joins are tested for their status, and a failure refuses. cs_within_cap
# has joined the same text already and fails closed, but it ran in a process of
# its own, and a join that fails only the second time -- a fork refused under
# load, an awk killed -- reached the rules with an empty text and permitted
# `rm -f \`, a newline and an entry. Measured by review of PR #329, round 3,
# with a cs_join that succeeds once and then fails; the round before had
# dropped this test as one no check could drive, having driven it only with a
# join that failed every time. checks/GH-156.sh drives both tests now.
JOINED=$(printf '%s\n' "$COMMAND" | cs_join) || {
  echo "Blocked: append-only-docs.sh could not join the command's continuations with cs_join, so it cannot judge what the shell would run. Refusing rather than permitting." >&2
  exit 2
}
# join_as_bash <stdin: a command> -- its lines joined where bash joins them: a
# line ending in an odd run of backslashes loses the last of them and is joined
# to the next, unless a `#` opening a word on it makes the backslash a
# comment's. An even run ends its line. See THREE READINGS in the header.
join_as_bash() {
  awk '
    {
      line = $0
      n = length(line); r = 0
      while (r < n && substr(line, n - r, 1) == "\\") r++
      t = ((acc == "") ? "" : substr(acc, length(acc), 1)) line
      if (r % 2 == 1 && t !~ /(^|[ \t;&|(])#/) {
        acc = acc substr(line, 1, n - 1); held = 1; next
      }
      print acc line; acc = ""; held = 0
    }
    END { if (held) print acc }'
}
BASH_JOINED=$(printf '%s\n' "$COMMAND" | join_as_bash) || {
  echo "Blocked: append-only-docs.sh could not join the command's continuations as bash does, so it cannot judge what the shell would run. Refusing rather than permitting." >&2
  exit 2
}

# The trailing group is the directory boundary, and it is what #69 was about.
# `.` and `-` are path-name characters here so that `docs/dev-log.bak` and
# `docs/dev-logbook` are other paths rather than this one; a quote, a space or
# a separator ends the name and is matched.
#
# The leading `/+(\./+)*` is the same finding on the other side of the slash,
# found by review of the fix above rather than by the issue. This hook compares
# spellings, exactly as append-only-docs-edit.sh did before #69 normalised it,
# and the spellings that a shell reduces to the same directory were permitted:
# `rm -rf docs//dev-log` and `rm -rf docs/./dev-log` both were. Nothing here
# can normalise the way the Edit companion does -- the path is embedded in a
# command rather than handed over as one -- so the two spellings a reader
# actually writes are matched where they stand. That is a narrower answer than
# the companion's and it is named as one: `docs/foo/../dev-log` is still
# permitted, and closing that would mean parsing paths out of shell text.
#
# THE LEFT BOUNDARY is #159's, and it is the right one's class on the other side.
# There was none: `rm -rf notdocs/dev-log` and `rm -rf x.docs/dev-log` were
# refused, measured, though `notdocs` and `x.docs` are other directories, while
# the Edit companion -- once #159 moved it off the project root and onto the
# path's own segments -- permits the same paths. Two halves of one rule have to
# agree about which paths are append-only, and checks/GH-159.sh holds them to one
# path set, so this side is bounded the way that side is: `docs` opens the path
# or follows a character that is not a letter, a digit, `_`, `.` or `-`, a `/`
# among them. That permits what this hook refused, which is the direction a
# boundary fix goes.
#
# The class is not "a character that cannot continue a name": `+ @ , : = ~` and
# a quoted space can, and they are boundaries here because in shell text they
# also end an option or a host in front of a path -- `--target-directory=docs/`,
# `host:docs/`. So the halves agree on GH-159.2's path set and disagree just
# outside it, in the refusing direction: `rm -rf a+docs/dev-log` is refused here
# while the Edit half, which needs a `/` before `docs`, permits an Edit of
# `a+docs/dev-log/<entry>`. checks/GH-159.sh pins both as the trade.
#
# It is written into the rules below rather than only here, because a boundary
# is a character and the rules below had already consumed the one in front of
# the path -- the space after `rm`, the `>` of a redirect. So each rule's own
# stretch before the path ends, when it is not empty, in a boundary character
# its stretch may hold, and APPEND_ONLY_DIR is the path with no boundary in
# front. The stretch's boundary excludes what the stretch excludes: allowing a
# `>` there let the second `>` of `>>docs/dev-log/<entry>`, an append written
# with no space, read as the boundary of a truncation, and the append was
# refused -- found while writing this, and pinned there.
#
# AN OPTION'S LETTERS STAND BEFORE A PATH TOO, which the boundary's first version
# missed: `cp -tdocs/dev-log x`, GNU's `-t` with its value attached, was refused
# before the boundary existed and permitted by it, because `t` continues a name
# (review of #159's branch). So after the boundary, a `-` and letters may stand
# in front of `docs` -- an option whose value is the path. A hyphen inside a name
# still opens nothing, because the `-` has to follow the boundary itself:
# `x-notdocs/dev-log` stays another directory. The trade: a directory whose name
# is a `-`, letters and then `docs`, `./-xdocs/dev-log`, reads as that option
# and is refused by the verb list and the in-place rule, which read it through
# APPEND_ONLY; `-docs` itself, with no letters, is another directory. The
# redirect rule has no option group, because a redirect takes no option, so
# `> ./-xdocs/dev-log/<entry>` is the other directory it is and is permitted.
APPEND_ONLY_DIR='docs/+(\./+)*(dev-log|lessons-learned|eval-reports)(/|[^A-Za-z0-9_.-]|$)'
APPEND_ONLY='(^|[^A-Za-z0-9_.-])(-[A-Za-z]+)?'"$APPEND_ONLY_DIR"

# judge_text <text> -- exits 2 with a message when a rule refuses the text,
# and returns when none does. Called on the raw command and then on the
# joined one; see BOTH TEXTS in the header.
judge_text() {
  if echo "$1" | grep -qE "$APPEND_ONLY"; then
    # rm / mv / cp over an existing entry, or over the directory itself.
    #
    # truncate and tee are here because both overwrite an entry in place without
    # naming a redirect, so the two rules below saw neither: `truncate -s 0` and
    # `tee <path> < new.md` were both measured permitted in #69. The list is what
    # has been measured and nothing more -- a verb added on a guess is a rule no
    # check asks about.
    #
    # The trade, taken knowingly: `tee -a` appends, which is the operation this
    # directory exists to allow, and it is refused here with the truncating
    # spelling because the verb is read and its options are not. `>>` is the
    # documented way to append and stays permitted; the check suite pins the
    # refusal so that it is a decision rather than a surprise.
    if echo "$1" | grep -qE "(^|[;&|]|\s)(rm|mv|cp|truncate|tee)\s+([^;&|]*[^;&|A-Za-z0-9_.-])?(-[A-Za-z]+)?$APPEND_ONLY_DIR"; then
      echo "Blocked: removing or overwriting an append-only docs directory, or a file under one. CLAUDE.md treats docs/dev-log/, docs/lessons-learned/ and docs/eval-reports/ as history; corrections belong in a new entry." >&2
      exit 2
    fi
    # in-place rewrite
    if echo "$1" | grep -qE "(^|[;&|]|\s)(sed|perl)\s+[^;&|]*-i" && echo "$1" | grep -qE "$APPEND_ONLY"; then
      echo "Blocked: in-place edit of an append-only docs file. CLAUDE.md treats docs/dev-log/, docs/lessons-learned/ and docs/eval-reports/ as history; corrections belong in a new entry." >&2
      exit 2
    fi
    # truncating redirect (single >), but not an >> append
    if echo "$1" | grep -qE "[^>]>\s*([^>|&]*[^>|&A-Za-z0-9_.-])?$APPEND_ONLY_DIR"; then
      echo "Blocked: truncating redirect into an append-only docs file. Use >> to append, or write a new entry. CLAUDE.md treats these directories as history." >&2
      exit 2
    fi
  fi
}
judge_text "$COMMAND"
judge_text "$JOINED"
judge_text "$BASH_JOINED"

exit 0

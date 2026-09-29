#!/bin/bash
# THE ISSUE FILE OF #156: append-only-docs.sh reads the command with its
# backslash continuations joined, so a verb and an append-only path on either
# side of a `\`-newline are judged as the one line the shell runs.
#
# Why: the hook's rules are `grep -E` over the command text, and grep matches
# within a physical line. Each destroying rule wants the verb and the path on
# one line, so `truncate -s 0 \`, a newline, and an entry was permitted, and so
# was every other verb the hook names and the truncating `>`. `sed -i` survived
# by accident, its rule being two greps -- the verb on a line, the path anywhere
# -- and even that fell to a continuation between `sed` and its `-i`. Found by
# #106's invariance families, whose `docs-truncate + continuation` row was a
# gap until this file; that row is gone, and the variant it generated is an
# ordinary check of the seed's verdict now. It carries the seed's tag, GH-69.2,
# as every undeclared variant does; the first row below is the same command,
# tagged GH-156.
#
# The fix is cs_join, the function no-pr-decisions.sh calls for this exact
# reason -- and the rules run over the command as it came AND over it joined,
# refusing if either text is refused. It is #84's shape: one question answered
# in one consumer and never asked in another.
#
# BOTH TEXTS, because the joined text alone opened a hole the raw one did not
# have, in the first version of this fix (review of PR #329, round 1). cs_join
# joins any trailing backslash, and bash continues a line only on an odd run and
# never in a comment. Where bash does not continue, the next line is a command
# of its own, and the joined text glued its verb onto the word before it, where
# the verb rule's `(^|[;&|]|\s)` no longer matched: `echo done \\`, a newline
# and `rm -f` an entry was refused on dev-05 and permitted by that version, and
# so were a comment ending in `\` over `rm -rf` of the directory, truncate, tee,
# cp, mv and sed -i. Joining only odd runs would have closed the escaped rows
# and not the comments. The same class, outside this hook, is #337.
#
# ONE ROW PER SPELLING, not one representative, because the three rules that
# read a verb each carry their own stretch after it -- to the path for the verb
# list and the redirect, to the `-i` for the in-place rule, whose path may stand
# anywhere.
#
# TWO TRADES, both pinned below as verdicts rather than left to a comment, and
# both in the refusing direction.
#   - A line bash does not join, read joined. The joined pass is dev-05's rules
#     over the command with each line-ending backslash and its newline taken
#     out, so it gives any command dev-05's verdict on that text. Where bash
#     joins too -- unquoted, or inside double quotes -- that is the one-line
#     verdict, looseness and all: the verb rule reads a verb anywhere before an
#     entry, prose and arguments included, which is #237's shape. Where bash
#     does not -- single quotes, a comment, a quoted heredoc's body -- a
#     destroying verb or a `>` ANYWHERE on a line that ends in a backslash, with
#     an entry named on the next, is refused, whatever the verb is doing there:
#     prose ending in `rm \`, a real `rm` of another file under a comment that
#     ends in `\`, and, costliest, the append this directory exists for --
#     `cat >>` an entry from a quoted heredoc whose body has a Markdown hard line
#     break after a line mentioning `rm`. #237 is that shape on one line; this
#     widens it across lines. One edit away: take the backslash off, or write
#     the body to a scratch file and append that, as the dev-log README does.
#   - A continuation INSIDE a name. `docs/dev-log\`, a newline and `book` is the
#     path `docs/dev-logbook` to a shell, which is another directory, and it is
#     refused, as it was on dev-05: the joined pass permits it, and the raw pass
#     sees the backslash stand where the boundary group matches it. The first
#     version of this fix, which read the joined text alone, permitted it; the
#     raw pass is what gives it back, and keeping every dev-05 refusal by
#     construction is worth this one.

section "=== issue #156: append-only-docs.sh reads continuations joined ==="

AOD156_E=docs/dev-log/devlog_2026-08-01_session-1.md

# Every destroying verb the hook names, and the truncating redirect, with a
# continuation between the verb and the path.
req GH-156
check append-only-docs.sh BLOCK 'truncate with a continuation before the entry' \
  "truncate -s 0 \\
  $AOD156_E"
check append-only-docs.sh BLOCK 'rm with a continuation before the entry' \
  "rm -f \\
  $AOD156_E"
check append-only-docs.sh BLOCK 'mv with a continuation before the entry' \
  "mv \\
  $AOD156_E /tmp/x"
check append-only-docs.sh BLOCK 'cp with a continuation before the entry' \
  "cp \\
  new.md $AOD156_E"
check append-only-docs.sh BLOCK 'tee with a continuation before the entry' \
  "tee \\
  $AOD156_E < new.md"
check append-only-docs.sh BLOCK 'a truncating > with a continuation before the entry' \
  "echo x > \\
  $AOD156_E"
check append-only-docs.sh BLOCK 'rm -rf of the directory itself, no trailing slash, behind a continuation' \
  'rm -rf \
  docs/dev-log'
check append-only-docs.sh BLOCK 'rm with two continuations, one before an option and one after it' \
  "rm \\
  -f \\
  $AOD156_E"
check append-only-docs.sh BLOCK 'a continuation inside the path, which the shell joins into docs/dev-log' \
  'rm -rf docs/\
dev-log'

# The in-place rule. The first row was refused before the fix, by the two-grep
# accident, and is a pin; the other two were not, since the verb and its -i
# stood on two lines, and they are the ones that ask the joined text.
req GH-156
check append-only-docs.sh BLOCK 'sed -i with a continuation before the entry' \
  "sed -i s/a/b/ \\
  $AOD156_E"
check append-only-docs.sh BLOCK 'sed with a continuation before its -i, which only the joined text puts on one line' \
  "sed \\
  -i s/a/b/ $AOD156_E"
check append-only-docs.sh BLOCK 'perl with a continuation before its -i' \
  "perl \\
  -i -pe s/a/b/ $AOD156_E"

# THE BOUNDARY after joining. A path that ended a physical line is followed by
# whatever the next line brings, and the trailing group of APPEND_ONLY_DIR has
# to see the directory end there. The first two rows are pins: they were
# refused before the fix too, the verb and the path sharing a line, and the
# backslash standing where the group matched it. The third asks the joined
# text, because only joining puts the verb before the path, and the directory
# is then followed by the space the next line opens with.
req GH-156
check append-only-docs.sh BLOCK 'the directory ending a physical line, a continuation, then a separator' \
  'rm -rf docs/dev-log \
  && echo done'
check append-only-docs.sh BLOCK 'an entry ending a physical line with the backslash against it' \
  "truncate -s 0 $AOD156_E\\
 && echo done"
check append-only-docs.sh BLOCK 'the directory between two continuations, its end read off the joined space after it' \
  'rm -rf \
docs/dev-log\
 && echo done'

# What stays permitted: the append, and a revisable directory.
req GH-156
check append-only-docs.sh ALLOW 'an >> append behind a continuation stays permitted' \
  "echo x >> \\
  $AOD156_E"
check append-only-docs.sh ALLOW 'an >> append with the continuation against both' \
  "echo x >>\\
$AOD156_E"
check append-only-docs.sh ALLOW 'truncate of a revisable docs/design/ file behind a continuation stays permitted' \
  'truncate -s 0 \
  docs/design/dependency-scanning-scope.md'

# THE TWO TRADES, as verdicts.
req GH-156
check append-only-docs.sh BLOCK 'the trade: single-quoted prose ending a line in `rm \` and naming an entry next is refused, though a shell reads that backslash literally' \
  "echo 'then rm \\
$AOD156_E is history'"
check append-only-docs.sh BLOCK 'the trade: a comment ending in `rm \` with an entry named on the next line is refused, though a comment continues nothing' \
  "ls  # then rm \\
  # $AOD156_E, never"
check append-only-docs.sh BLOCK 'the trade: a quoted heredoc body ending a line in `rm \` and naming an entry next is refused, though that body is literal' \
  "cat >> notes.md <<'X'
then rm \\
$AOD156_E
X"
check append-only-docs.sh BLOCK 'the trade at its width: a real rm of another file under a comment ending in a backslash, and cat of an entry next, is refused' \
  "rm -f tmp.txt  # clean \\
cat $AOD156_E"
check append-only-docs.sh BLOCK 'the trade at its costliest: cat >> an entry from a quoted heredoc with a hard line break after a line mentioning rm is refused, though it appends (#237, across lines)' \
  "cat >> $AOD156_E <<'X'
Ran rm on scratch files \\
and read $AOD156_E
X"
check append-only-docs.sh ALLOW 'and the same append without the hard line break stays permitted' \
  "cat >> $AOD156_E <<'X'
Ran rm on scratch files
and read $AOD156_E
X"
check append-only-docs.sh BLOCK 'the trade: a continuation inside a name, docs/dev-log\ then book, is docs/dev-logbook to a shell and refused, by the raw pass' \
  'rm -rf docs/dev-log\
book'

# THE BOUNDARY A JOIN GLUES, which is why the raw text is still read. Each row
# is a line bash does not continue -- an even run of backslashes, or a backslash
# in a comment -- and a destroying command on the next line, which bash runs.
# Every one was refused on dev-05 and permitted by the joined-only version;
# the raw pass refuses it. The control with a space before the comment's
# backslash kept its `\s` either way.
req GH-156
check append-only-docs.sh BLOCK 'an escaped backslash ends the line, so rm on the next is a command of its own' \
  "echo done \\\\
rm -f $AOD156_E"
check append-only-docs.sh BLOCK 'and rm -rf of the directory after an escaped backslash' \
  'echo done \\
rm -rf docs/dev-log'
check append-only-docs.sh BLOCK 'and truncate after an escaped backslash' \
  "echo done \\\\
truncate -s 0 $AOD156_E"
check append-only-docs.sh BLOCK 'and sed -i after an escaped backslash' \
  "echo done \\\\
sed -i s/a/b/ $AOD156_E"
check append-only-docs.sh BLOCK 'and truncate after an escaped backslash ending a bare command word' \
  "ls \\\\
truncate -s 0 $AOD156_E"
check append-only-docs.sh BLOCK 'and tee after an escaped backslash with no space before it' \
  "echo a\\\\
tee $AOD156_E"
check append-only-docs.sh BLOCK 'and cp after an escaped backslash with no space before it' \
  "echo a\\\\
cp x $AOD156_E"
check append-only-docs.sh BLOCK 'a comment ending in a backslash continues nothing, so rm -rf on the next line runs' \
  '# tidy up\
rm -rf docs/dev-log'
check append-only-docs.sh BLOCK 'and mv after a trailing comment ending in a backslash' \
  "x=1 # note\\
mv $AOD156_E /tmp/x"
check append-only-docs.sh BLOCK 'and rm after a comment with no space before its #' \
  "ls #x\\
rm $AOD156_E"
check append-only-docs.sh BLOCK 'the control: a space before the comment backslash keeps the boundary in the joined text too' \
  '# tidy up \
rm -rf docs/dev-log'
# A truncating `>` opening the next line truncates the entry in bash. The raw
# pass permits it, since a `>` at the start of a line is #233's; the joined
# pass refuses it, the `\` of the escaped run standing where `[^>]` matches.
# Pinned as the verdict it is, not as a fix of #233, whose one-line spelling
# is still permitted.
check append-only-docs.sh BLOCK 'a truncating > opening the line after an escaped backslash, refused by the joined pass' \
  "echo done \\\\
> $AOD156_E"

# THE LOAD CONTRACT for the function the fix calls. With cs_join renamed away
# the hook refuses even without a guard for it, because cs_within_cap joins
# through cs_join and fails closed -- so the BLOCK alone cannot tell the guard
# from the fall-through, and which message fires can.
req GH-84.1 GH-156
mk_halflib append-only-docs.sh cs_join
check_in "$ON_DEV" "$(halflib_path append-only-docs.sh cs_join)" BLOCK \
  'a library missing only cs_join, append-only-docs.sh' 'ls'
says "$ON_DEV" "$(halflib_path append-only-docs.sh cs_join)" 'append-only-docs.sh could not load lib/command-scan.sh, so it cannot read the command it was handed, join its continuations, or hold the line cap every Bash hook holds. Refusing rather than permitting.' \
  'append-only-docs.sh, a library missing only cs_join, refused by its guard' 'ls'
req GH-84.2 GH-156
armed 'append-only-docs.sh requires cs_join' "$HOOKS/append-only-docs.sh" 'command -v cs_join'

sourced_to_end

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
# ordinary check of the seed's verdict now.
#
# The fix is cs_join over the command right after it is read, the function
# no-pr-decisions.sh calls for this exact reason, and which cs_within_cap already
# read through -- so the cap and the rules now read the same text. It is #84's
# shape: one question answered in one consumer and never asked in another.
#
# ONE ROW PER SPELLING, not one representative, because the rules are four and
# each carries its own stretch between verb and path.
#
# TWO TRADES, both pinned below as verdicts rather than left to a comment.
#   - Quoted text. cs_join joins a trailing backslash wherever it stands, and
#     inside single quotes a backslash-newline is two literal characters, not a
#     continuation. So prose that ends a line in `rm \` and names an entry on
#     the next is refused now where it was permitted. The refusing direction,
#     and one edit away.
#   - A continuation INSIDE a name. `docs/dev-log\`, a newline and `book` is the
#     path `docs/dev-logbook` to a shell, which is another directory, and it is
#     permitted now where it was refused: the backslash had stood where the
#     boundary group matched it. That is the permitting direction, and it is
#     right, for the reason #69 gives for `docs/dev-logbook` on one line.

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
# accident; the second was not, since the verb and its -i stood on two lines,
# and it is the one that asks the joined text.
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
# whatever the next line brings, which is a space or a separator here, and the
# trailing group of APPEND_ONLY_DIR still has to see it end.
req GH-156
check append-only-docs.sh BLOCK 'the directory ending a physical line, a continuation, then a separator' \
  'rm -rf docs/dev-log \
  && echo done'
check append-only-docs.sh BLOCK 'an entry ending a physical line with the backslash against it' \
  "truncate -s 0 $AOD156_E\\
 && echo done"

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
check append-only-docs.sh BLOCK 'the trade: quoted prose ending a line in `rm \` and naming an entry next is refused, though a shell reads that backslash literally' \
  "echo 'then rm \\
$AOD156_E is history'"
check append-only-docs.sh ALLOW 'a continuation inside a name, docs/dev-log\ then book, is docs/dev-logbook to a shell and permitted' \
  'rm -rf docs/dev-log\
book'

# THE LOAD CONTRACT for the function the fix calls. With cs_join renamed away
# the hook refuses even without a guard for it, because cs_within_cap joins
# through cs_join and fails closed -- so the BLOCK alone cannot tell the guard
# from the fall-through, and which message fires can.
req GH-84.1 GH-156
mk_halflib append-only-docs.sh cs_join
check_in "$ON_DEV" "$(halflib_path append-only-docs.sh cs_join)" BLOCK \
  'a library missing only cs_join, append-only-docs.sh' 'ls'
says "$ON_DEV" "$(halflib_path append-only-docs.sh cs_join)" 'append-only-docs.sh could not load' \
  'append-only-docs.sh, a library missing only cs_join, refused by its guard' 'ls'
req GH-84.2 GH-156
armed 'append-only-docs.sh requires cs_join' "$HOOKS/append-only-docs.sh" 'command -v cs_join'

sourced_to_end

#!/bin/bash
# THE ISSUE FILE OF #351: the heredoc pass ends a body where bash ends it, or
# gives the rest of the command back.
#
# Why: cs_drop_heredocs took bash's quote removal of a delimiter to be the
# deletion of every quote character, and took everything the opener regex
# stepped over as space. Neither is bash's reading. `<<"it's"` ends at it's,
# and the pass waited for its; `<<\EOF` and `<<E\OF` end at EOF, and the pass
# waited for the backslash; `<<$'EOF'` and `<<$"EOF"` end at EOF, and the pass
# waited for $EOF; `<<"E\"F"` ends at E"F; a carriage return before the word
# or after it is part of the word to bash and space to awk. Where a later line
# read what the pass waited for, every line between bash's terminator and it
# was dropped, and bash runs every one. Measured on origin/dev-05 at 01bfef4
# and again at 0e4a0f4, by feeding no-git-push.sh on stdin and by running each
# shape under bash with `touch ran.flag` in the push's place: every hook that
# calls cs_normalise, permitting. Found by rev-agent-202's round-2 review of
# #314, where the same shapes were permitted in that pull request's
# keep-unquoted mode; the carriage returns by the author of both.
#
# THE FIX IS A GRAMMAR AND A GIVE-BACK. A delimiter is trusted only when
# deleting its quote characters is bash's quote removal of it -- plain
# characters but a backslash, a dollar or a backtick, whole '...' spans with
# no double quote in them, whole "..." spans with no single quote, backslash,
# dollar or backtick -- and no carriage return, form feed or vertical tab
# stands in the match or right after it. Anything else sets the pass giving
# back every line from there to the end, since skipping only that opener
# would read its body as commands and let an opener inside it, text to bash,
# drop lines bash runs once the real body has ended. lib/command-scan.sh
# argues it above cs_drop_heredocs and beside the test.
#
# WHAT SAYS SO, measured rather than argued: the #128 method, #351's own
# generator, is 4,096 shapes -- sixteen delimiter spellings, and sixteen
# candidate lines each for where bash and the pass might end the body -- each
# RUN under bash with `touch ran.flag` as the payload, then put through
# cs_normalise with a push there. A push bash runs and no emitted line starts
# with: 8 at 0e4a0f4, 0 with the fix. A push bash does not run and an emitted
# line starts with: 3,638 at 0e4a0f4 -- the END give-back of every body that
# never ends -- and 3,750 with the fix, the 112 more being the bodies given
# back after a delimiter this pass cannot read. On real commands it costs
# nothing measured: of 5,100 distinct Bash commands holding `<<` in the local
# session transcripts, cs_normalise's output differs on none. The generator is
# in the pull request, not the tree, as #128's was; its first run on the fix
# found the first grammar letting `<<"it's"` through.
#
# WHICH ROWS CAN FAIL: every BLOCK row below was ALLOW at 0e4a0f4 but one, and
# every ALLOW row is ALLOW on both, measured on stdin against a tree extracted
# there. The one is the opener inside an unreadable body, refused at 0e4a0f4
# by the END give-back and there for the mutation that makes the give-back
# forget: each of the six rules the fix adds was broken alone, and each turned
# a row of this file red.

section "=== issue #351: a heredoc body ends where bash ends it, or the rest is given back ==="

requirement GH-351.1 <<'REQ'
- text: The heredoc pass that `cs_normalise` runs does not drop a line past
  the one bash ends a heredoc body on. A delimiter is trusted only when it is
  made of characters other than a backslash, a dollar and a backtick, whole
  `'...'` spans holding no double quote, and whole `"..."` spans holding no
  single quote, backslash, dollar or backtick, and no carriage return, form
  feed or vertical tab stands between `<<` and it or right after it. On any
  other delimiter every line from its opener to the end of the command is
  given back as commands. So a push or a merge on a line after bash's
  terminator of `<<"it's"`, `<<\EOF`, `<<E\OF`, `<<$'EOF'`, `<<$"EOF"`,
  `<<"E\"F"`, `<<\r'EOF'` or `<<'EOF'\r` is refused in every hook that calls
  `cs_normalise`, and a push in the body of `<<'EOF'`, `<<"EOF"`, `<<E"O"F`,
  `<<-'EOF'`, `<<''` or `<<EOF` is still dropped with it.
- from: #351
- kind: defect-permitting
- status: active
- variants: none: its subject is a heredoc's delimiter and the line that ends
  its body, a multi-line shape no transformation writes; the delimiter
  spellings are rows here
- note: THE TRADE, taken knowingly and pinned: a delimiter outside the
  grammar that bash and the old pass read alike -- `<<$X`, which bash does
  not expand -- now gives its body back, and every body after it, so prose in
  them naming a push is refused. It costs refusals and never permissions, and
  none of the 5,100 heredoc commands in the local transcripts has one.
REQ
shape_pin 'GH-351.1'
variants_pin 'GH-351.1:none'

# THE DELIMITERS BASH READS DIFFERENTLY: a push on the line after bash's
# terminator, and a later line reading what the old pass waited for. Each was
# permitted at 0e4a0f4, and bash runs the push in each.
req GH-351.1 US-1
check no-git-push.sh BLOCK "<<\"it's\": bash ends at it's, the old pass waited for its" \
  $'cat <<"it\'s"\nx\nit\'s\ngit push --force origin main\nits'
check no-git-push.sh BLOCK '<<E\OF: bash ends at EOF' \
  $'cat <<E\\OF\nx\nEOF\ngit push --force origin main\nE\\OF'
check no-git-push.sh BLOCK '<<\EOF with a later \EOF line: bash ends at EOF' \
  $'cat <<\\EOF\nx\nEOF\ngit push --force origin main\n\\EOF'
check no-git-push.sh BLOCK "<<\$'EOF' with a later \$EOF line: bash ends at EOF" \
  $'cat <<$\'EOF\'\nx\nEOF\ngit push --force origin main\n$EOF'
check no-git-push.sh BLOCK '<<$"EOF" with a later $EOF line: bash ends at EOF' \
  $'cat <<$"EOF"\nx\nEOF\ngit push --force origin main\n$EOF'
check no-git-push.sh BLOCK '<<"E\"F": bash ends at E"F' \
  $'cat <<"E\\"F"\nx\nE"F\ngit push --force origin main\nE\\F'
check no-git-push.sh BLOCK "a carriage return between << and 'EOF': bash ends at \\rEOF" \
  $'cat <<\r\'EOF\'\nx\n\rEOF\ngit push --force origin main\nEOF'
check no-git-push.sh BLOCK "a carriage return after 'EOF': bash ends at EOF\\r" \
  $'cat <<\'EOF\'\r\nx\nEOF\r\ngit push --force origin main\nEOF'
# The grammar's two exclusions and its stickiness, each the row only it
# refuses: a double quote inside '...', which the pass deletes and bash keeps;
# and an opener inside a body skipped as unreadable, text to bash, which would
# drop the push bash runs if only the unreadable opener were skipped.
check no-git-push.sh BLOCK "<<'a\"b': bash ends at a\"b, the old pass waited for ab" \
  $'cat <<\'a"b\'\nx\na"b\ngit push --force origin main\nab'
check no-git-push.sh BLOCK 'an opener inside an unreadable body, where bash ends the body first' \
  $'cat <<"it\'s"\ncat > /tmp/f <<EOF\nit\'s\ngit push --force origin main\nEOF'
# The same pass under every hook: two of the shapes with a merge.
req GH-351.1 US-15
check no-pr-decisions.sh BLOCK '<<\EOF with a later \EOF line, a merge after bash ends the body' \
  $'cat <<\\EOF\nx\nEOF\ngh pr merge 5\n\\EOF'
check no-pr-decisions.sh BLOCK "a carriage return after 'EOF', a merge after bash ends the body" \
  $'cat <<\'EOF\'\r\nx\nEOF\r\ngh pr merge 5\nEOF'

# THE DELIMITERS IN THE GRAMMAR, whose bodies are still dropped: a push in each
# body is text to bash and permitted, as it was. A grammar too narrow turns
# one of these red.
req GH-351.1 FR-3
check no-git-push.sh ALLOW "<<'EOF', a push in the body" \
  $'cat <<\'EOF\'\ngit push --force origin main\nEOF'
check no-git-push.sh ALLOW '<<"EOF", a push in the body' \
  $'cat <<"EOF"\ngit push --force origin main\nEOF'
check no-git-push.sh ALLOW '<<E"O"F, partly quoted, a push in the body' \
  $'cat <<E"O"F\ngit push --force origin main\nEOF'
check no-git-push.sh ALLOW "<<-'EOF', tab-indented, a push in the body" \
  $'cat <<-\'EOF\'\n\tgit push --force origin main\n\tEOF'
check no-git-push.sh ALLOW "<<'', which bash ends at the first empty line, a push in the body" \
  $'cat <<\'\'\ngit push --force origin main\n\necho done'
check no-git-push.sh ALLOW '<<EOF, a push in the body' \
  $'cat <<EOF\ngit push --force origin main\nEOF'

# THE TRADE, pinned where it is refused: a delimiter outside the grammar that
# bash and the old pass read alike gives its body back, and every body after it.
req GH-351.1 US-1
check no-git-push.sh BLOCK 'TRADE: <<$X, a push in its body, given back' \
  $'cat <<$X\ngit push --force origin main\n$X'
check no-git-push.sh BLOCK "TRADE: after <<\$X, a later <<'EOF' body is given back too" \
  $'cat <<$X\nx\n$X\ncat <<\'EOF\'\ngit push --force origin main\nEOF'

sourced_to_end

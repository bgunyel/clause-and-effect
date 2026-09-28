#!/bin/bash
# THE ISSUE FILE OF #202: a quoted heredoc's body is not re-read as commands
# when a gh api call is on the line, and is still read as text by the three
# graphql rules.
#
# Why: no-pr-decisions.sh re-admits the raw command once any `gh api` call is
# on the line and the text carries `<<`, because a heredoc is how a graphql
# mutation is sent. It appended all of it to $SCAN and split all of it into
# CMDS, so every heredoc body on the line became command candidates for every
# rule after that point -- a quoted body included, where bash expands nothing.
# A pull request body quoting a release write in backticks, written through
# `cat > /tmp/new.md <<'MD'` and sent by a gh api PATCH on the next line, was
# refused as that release write. The body did not have to be backticked: a body
# line beginning with the command, a `$( )`, a `state=closed` read by
# line_was_cut's fallback, each did it, and the trailing command could be a
# gh api READ. Filed from the review of #196 (#130) and triaged at dev-05
# 2c65f4d, where every row of the triage's table below marked "was BLOCK" was
# measured refused; the gate row is this branch's, measured refused at 1b01ceb.
#
# THE FIX IS TWO TEXTS. $SCAN keeps the raw command whole, for the graphql
# rules, which read it as text and are how a mutation in a heredoc is caught.
# CMDS is split from CMDTEXT, which re-admits the raw command with some of its
# bodies taken out by cs_drop_quoted_heredocs in lib/command-scan.sh -- the
# heredoc pass's own answer to where a body begins, in a mode that drops a body
# only when its delimiter is quoted, its opener is one bash sees and `cat` into
# a file or a `gh` command reads it. line_was_cut and the state fallback read
# CMDTEXT. The hook argues it above the re-admission, the library above the
# heredoc pass.
#
# THE FIRST VERSION DROPPED EVERY QUOTED BODY, and rev-agent-202's round-1
# review of the pull request measured what that cost: a `<<` the pass misread
# -- inside quotes, after a `#` -- dropped real commands up to the next line
# equal to its delimiter, and a quoted body fed to a shell reading stdin was
# dropped though that shell runs it. Both were refused before #202 by the
# re-read of the raw command, and permitted by that version. The rows under
# THE READERS THAT RUN A BODY and THE OPENERS BASH DOES NOT SEE are that
# review's and the author's sweep of the same two classes.
#
# WHICH ROWS CAN FAIL, measured rather than argued, twice, from a copy of the
# working tree run through $CHECK_HOOKS_DIR at 6e9c666 plus this change. With
# the pre-fix no-pr-decisions.sh from origin/dev-05 0d5829d beside this
# branch's library, all eighteen `flip` rows and the staged-script TRADE row
# went red with got=BLOCK, and so did the three load rows of GH-202.3, the
# pre-fix hook neither calling nor requiring the new function; the one other
# red was GH-182.3's verbatim pin of the re-admission block, whose text the fix
# changes. With this hook beside the first version's library, from 78c9de9,
# every one of the thirty-seven BLOCK rows added for the review went red with
# got=ALLOW, and nothing else did but the two that a copy without a .git always
# fails. This repository's hooks were never edited to do either.
#
# AND WHICH CONDITION EACH ROW HOLDS: every registered mutation of the fix was
# applied alone and every row fed to the mutated hook on stdin, and each
# mutation turned at least one row. Three did not until rows were added for
# them -- a `<<` behind a backslash and in a comment, whose rows used `echo`, a
# reader that keeps its body whichever condition holds; and a `/dev` target,
# whose row also piped to `sh` -- and a fourth, doubt being sticky, showed the
# statement it named decided nothing that `if (doubt) seen = 0` did not, and
# that statement is gone.
#
# WHAT IT TAKES FROM ELSEWHERE: $SUITE_DIR and $FIXTURES from the driver's
# prelude, and mk_halflib and halflib_path from the library.

section "=== issue #202: a quoted heredoc's body is not re-read as commands ==="

requirement GH-202.1 <<'REQ'
- text: When `no-pr-decisions.sh` re-admits a command's heredoc bodies because a
  `gh api` call is on its line, a heredoc's body is not split into command
  candidates for any rule, and is not read by `line_was_cut` or the state
  field's fallback, when three things hold: its delimiter is QUOTED -- holding a
  `'`, a `"` or a `\` anywhere, so `<<'X'`, `<<"X"`, `<<-'X'`, `<<-"X"` and
  `<<X"Y"`; its opener is one bash sees; and what reads it is `cat` redirected
  to a file or a `gh` command. So prose in such a body quoting a release write,
  a merge, a release create or `-f state=closed`, in backticks, in a `$( )` or
  at a line's start, is permitted beside a `gh api` write or read; and a body
  line reading `gh api graphql` does not open the graphql gate. Every other
  body is re-read as commands exactly as before #202, and a merge or a release
  write in it, beside a `gh api` call, is refused: an UNQUOTED body, which bash
  expands; a quoted body fed to anything else -- a shell or an interpreter
  reading stdin, a pipe, a process or command substitution, a loop, `tee`; and
  every body in a command where a `<<` stood that bash does not see as an
  opener -- inside single, double or `$'...'` quotes, after a `#`, behind a
  backslash -- or one whose quoting the pass cannot follow, a `$( )` or a
  backtick inside double quotes.
- from: #202, and its triage's table: rows 4, 8 to 8‴ and 9, shapes A, B, C, D,
  D2 and F; rev-agent-202's round-1 review of the pull request, Gates 1 and 2
- kind: defect-refusing
- status: active
- variants: none: its subject is a heredoc -- an opener, a body on lines of its
  own and a delimiter -- and what stands around it, which is a multi-line shape
  no transformation writes; the spellings of the delimiter and of its reader
  are rows here
- note: The re-admission is still gated on a `gh api` call on the line, and no
  verdict is pinned here on a heredoc whose line has none. Row 7 of the issue,
  an unpaired backtick, is out of scope, and so is `<<\X`, whose delimiter the
  heredoc pass reads as `\X`: it never arrives, so the body is given back as
  commands in every hook -- the refusing direction, in the library.
  TWO TRADES, taken knowingly and pinned. A quoted body written to a file by
  `cat > s.sh <<'EOF'` and run by a later command, `sh s.sh`, is dropped, `cat`
  into a file being a data consumer: refused beside a `gh api` call by the old
  re-read, by accident, and permitted now -- a refusal lost, in the permitting
  direction, and #311's, with the shells that run their stdin, for every hook.
  And `-f body="$(cat <<'MD' ...)"`, whose opener stands inside `"$(`, is
  doubt, so its body is kept and a merge named in it is refused, as before
  #202: 2 of 372 `gh api` heredoc commands taken from local session
  transcripts.
REQ
requirement GH-202.2 <<'REQ'
- text: A quoted heredoc's body is still read as TEXT by the three graphql rules
  of `no-pr-decisions.sh` -- the mutation names, `updatePullRequest` with a
  state, and `gql_bases` -- once a `gh api` call naming the graphql endpoint is
  on the line. So a mutation sent through a heredoc is refused in every
  spelling: on stdin with `<<EOF` or `<<'EOF'`, piped from `cat <<'EOF'`, and
  staged in a file by `cat > f <<'EOF'` or `<<EOF` and read by
  `gh api graphql -f query=@f` on the next line; and a REST merge whose body is
  on stdin is refused on its endpoint. #130's rows 8 and 9, an issue body in an
  unquoted heredoc naming `/releases` or a mutation, stay permitted, and prose
  in a quoted body naming a mutation or `baseRefName` beside a REST write stays
  permitted, the gate being shut.
- from: #202, the triage's acceptance criteria on what must survive the fix
- kind: defect-permitting
- status: active
- variants: none: as GH-202.1 -- its subject is a heredoc read as text beside
  the call that sends it, a multi-line shape no transformation writes
- note: THE TRADE, taken knowingly and pinned here: prose in a quoted body that
  names a mutation or `baseRefName`, beside a real `gh api graphql` call, is
  refused. It is item 1 of TWO BLEEDS THE GATE LEAVES in the hook, arriving
  through a heredoc, and costs refusals and never permissions. Taking the
  quoted bodies out of the graphql text too would close it and permit the
  file-staged mutation, which nothing pinned before this file.
REQ
requirement GH-202.3 <<'REQ'
- text: `no-pr-decisions.sh` calls `cs_drop_quoted_heredocs` and its load guard
  requires it, so a library without it refuses every command. A call that
  fails -- a library whose heredoc pass refuses the mode it is asked for --
  falls back on re-reading the whole raw command, the reading before #202: a
  quoted body's release write beside a `gh api` write is refused again, and an
  unquoted body's merge stays refused, where an empty answer would have
  permitted the second.
- from: #202
- kind: defect-permitting
- status: active
- direction: refuse-only: a library that cannot answer and a call that fails
  can only refuse more, and the rows that permit are GH-202.1's; that the
  failing fixture still permits an ordinary command is a fixture guard, not a
  row
- variants: none: its subject is the library the hook loads, which is a state
  of the tree rather than a spelling
REQ
shape_pin 'GH-202.1 GH-202.2 GH-202.3:refuse-only'
variants_pin 'GH-202.1:none GH-202.2:none GH-202.3:none'

# THE ROWS OF THE TRIAGE'S TABLE THAT THE FIX MOVES. W, the trailing write, is
# `gh api -X PATCH repos/o/r/pulls/196 -F body=@/tmp/new.md` throughout, as
# the triage wrote it, and each row is one literal.
req GH-202.1 US-14
flip "$SUITE_DIR" no-pr-decisions.sh BLOCK ALLOW "row 4: a backticked release write in a <<'MD' body, then W" \
  $'cat > /tmp/new.md <<\'MD\'\nMeasured: `gh api -X POST repos/o/r/releases -f tag_name=v1` stays BLOCK.\nMD\ngh api -X PATCH repos/o/r/pulls/196 -F body=@/tmp/new.md'
flip "$SUITE_DIR" no-pr-decisions.sh BLOCK ALLOW 'row 8: the same with <<"MD"' \
  $'cat > /tmp/new.md <<"MD"\nMeasured: `gh api -X POST repos/o/r/releases -f tag_name=v1` stays BLOCK.\nMD\ngh api -X PATCH repos/o/r/pulls/196 -F body=@/tmp/new.md'
flip "$SUITE_DIR" no-pr-decisions.sh BLOCK ALLOW "row 8': the same with <<-'MD', body and terminator tab-indented" \
  $'cat > /tmp/new.md <<-\'MD\'\n\tMeasured: `gh api -X POST repos/o/r/releases -f tag_name=v1` stays BLOCK.\n\tMD\ngh api -X PATCH repos/o/r/pulls/196 -F body=@/tmp/new.md'
flip "$SUITE_DIR" no-pr-decisions.sh BLOCK ALLOW "row 8'': the same with <<-\"MD\"" \
  $'cat > /tmp/new.md <<-"MD"\n\tMeasured: `gh api -X POST repos/o/r/releases -f tag_name=v1` stays BLOCK.\n\tMD\ngh api -X PATCH repos/o/r/pulls/196 -F body=@/tmp/new.md'
flip "$SUITE_DIR" no-pr-decisions.sh BLOCK ALLOW "row 8''': the same with <<M\"D\", partly quoted and quoted to bash" \
  $'cat > /tmp/new.md <<M"D"\nMeasured: `gh api -X POST repos/o/r/releases -f tag_name=v1` stays BLOCK.\nMD\ngh api -X PATCH repos/o/r/pulls/196 -F body=@/tmp/new.md'
flip "$SUITE_DIR" no-pr-decisions.sh BLOCK ALLOW 'shape A: a quoted body line that starts with a release write, then W' \
  $'cat > /tmp/new.md <<\'MD\'\ngh api -X POST repos/o/r/releases -f tag_name=v1\nMD\ngh api -X PATCH repos/o/r/pulls/196 -F body=@/tmp/new.md'
flip "$SUITE_DIR" no-pr-decisions.sh BLOCK ALLOW 'shape B: a release write inside $( ) in a quoted body, then W' \
  $'cat > /tmp/new.md <<\'MD\'\nx $(gh api -X POST repos/o/r/releases -f tag_name=v1) y\nMD\ngh api -X PATCH repos/o/r/pulls/196 -F body=@/tmp/new.md'
flip "$SUITE_DIR" no-pr-decisions.sh BLOCK ALLOW 'shape C: a backticked state field in a quoted body, then W to a pull request' \
  $'cat > /tmp/new.md <<\'MD\'\nuse `-f state=closed` on the PR\nMD\ngh api -X PATCH repos/o/r/pulls/196 -F body=@/tmp/new.md'
flip "$SUITE_DIR" no-pr-decisions.sh BLOCK ALLOW 'shape D: a backticked merge in a quoted body, then W' \
  $'cat > /tmp/new.md <<\'MD\'\nnever `gh pr merge 5` here\nMD\ngh api -X PATCH repos/o/r/pulls/196 -F body=@/tmp/new.md'
flip "$SUITE_DIR" no-pr-decisions.sh BLOCK ALLOW 'shape D2: the same body, then a gh api READ' \
  $'cat > /tmp/new.md <<\'MD\'\nnever `gh pr merge 5` here\nMD\ngh api repos/o/r/pulls/196'
flip "$SUITE_DIR" no-pr-decisions.sh BLOCK ALLOW 'shape F: a backticked release create in a quoted body, then a gh api read' \
  $'cat > /tmp/new.md <<\'MD\'\n`gh release create v1`\nMD\ngh api repos/o/r/issues/5'
# THE GATE: a quoted body line reading `gh api graphql` was a command after the
# re-split, so it opened the graphql gate and its mutation name was refused
# beside a REST write. Not in the triage's table, and the acceptance criterion
# that asks for it: a quoted body must not open the gate.
flip "$SUITE_DIR" no-pr-decisions.sh BLOCK ALLOW 'a quoted body naming gh api graphql and a mutation does not open the gate, beside W' \
  $'cat > /tmp/new.md <<\'MD\'\n`gh api graphql` with mergePullRequest\nMD\ngh api -X PATCH repos/o/r/pulls/196 -F body=@/tmp/new.md'

# THE ROWS THAT WERE PERMITTED BEFORE AND STAY SO, each one a row an over-wide
# fix turns red.
check no-pr-decisions.sh ALLOW 'row 1: the heredoc alone, a release write backticked in its body' \
  $'cat > /tmp/new.md <<\'MD\'\nMeasured: `gh api -X POST repos/o/r/releases -f tag_name=v1` stays BLOCK.\nMD'
check no-pr-decisions.sh ALLOW 'row 2: the same, then echo ok' \
  $'cat > /tmp/new.md <<\'MD\'\nMeasured: `gh api -X POST repos/o/r/releases -f tag_name=v1` stays BLOCK.\nMD\necho ok'
check no-pr-decisions.sh ALLOW 'row 3: the same, then gh pr comment' \
  $'cat > /tmp/new.md <<\'MD\'\nMeasured: `gh api -X POST repos/o/r/releases -f tag_name=v1` stays BLOCK.\nMD\ngh pr comment 196 --body-file /tmp/new.md'
check no-pr-decisions.sh ALLOW 'row 5: the backticks removed from the body, then W' \
  $'cat > /tmp/new.md <<\'MD\'\nMeasured: gh api -X POST repos/o/r/releases -f tag_name=v1 stays BLOCK.\nMD\ngh api -X PATCH repos/o/r/pulls/196 -F body=@/tmp/new.md'
check no-pr-decisions.sh ALLOW 'row 6: a backticked issue write in the body, then W' \
  $'cat > /tmp/new.md <<\'MD\'\nMeasured: `gh api -X POST repos/o/r/issues -f title=x` is an issue write.\nMD\ngh api -X PATCH repos/o/r/pulls/196 -F body=@/tmp/new.md'
check no-pr-decisions.sh ALLOW 'shape D3: a backticked merge in a quoted body, then gh issue comment, no gh api on the line' \
  $'cat > /tmp/new.md <<\'MD\'\nnever `gh pr merge 5` here\nMD\ngh issue comment 5 -F /tmp/new.md'

# THE DATA CONSUMERS, each dropping a quoted body that no rule reads: cat into a
# file in its three spellings, inside a compound, and gh reading its stdin.
# Each was refused before #202, measured at 0d5829d.
flip "$SUITE_DIR" no-pr-decisions.sh BLOCK ALLOW "cat > F inside a compound, after an assignment and &&" \
  $'S=/tmp/x && cat > "$S/r.md" <<\'MD\'\nnever `gh pr merge 5` here\nMD\ngh api -X PATCH repos/o/r/pulls/196 -F body=@"$S/r.md"'
flip "$SUITE_DIR" no-pr-decisions.sh BLOCK ALLOW "cat >> F, which appends" \
  $'cat >> /tmp/new.md <<\'MD\'\nnever `gh pr merge 5` here\nMD\ngh api -X PATCH repos/o/r/pulls/196 -F body=@/tmp/new.md'
flip "$SUITE_DIR" no-pr-decisions.sh BLOCK ALLOW "cat <<'MD' > F, the redirect after the opener" \
  $'cat <<\'MD\' > /tmp/new.md\nnever `gh pr merge 5` here\nMD\ngh api -X PATCH repos/o/r/pulls/196 -F body=@/tmp/new.md'
flip "$SUITE_DIR" no-pr-decisions.sh BLOCK ALLOW "gh api reading the quoted body on stdin with -F body=@-" \
  $'gh api -X PATCH repos/o/r/issues/5 -F body=@- <<\'MD\'\nnever `gh pr merge 5` here\nMD'
flip "$SUITE_DIR" no-pr-decisions.sh BLOCK ALLOW "a double-quoted string closed on its own line does not doubt a later opener" \
  $'gh api -X PATCH repos/o/r/issues/5 -f body="a\nb" && cat > /tmp/f <<\'EOF\'\nnever `gh pr merge 5` here\nEOF\ngh api repos/o/r/pulls/5'
flip "$SUITE_DIR" no-pr-decisions.sh BLOCK ALLOW 'a plain ${X} in double quotes does not doubt a later opener' \
  $'echo "${X}" && cat > /tmp/f <<\'EOF\'\nnever `gh pr merge 5` here\nEOF\ngh api repos/o/r/pulls/5'

# THE TRADE, pinned where it is permitted: a body staged in a file by a data
# consumer and run by a later command. Refused before #202 beside a gh api call,
# by the re-read, and permitted with none on the line in every hook. #311 owns
# the stdin-shell family, and closing it for this shape turns this row red,
# which is the intended outcome.
check no-pr-decisions.sh ALLOW "TRADE (#311): a quoted body staged by cat > s.sh and run by sh s.sh, beside a gh api read" \
  $'cat > /tmp/s.sh <<\'EOF\'\ngh pr merge 5\nEOF\nsh /tmp/s.sh\ngh api repos/o/r/pulls/5'

# THE READERS THAT RUN A BODY, which the first version of this fix trusted: a
# quoted body is not expanded, but what it feeds may run it. Each was refused
# before #202 by the re-read, permitted at 78c9de9 and is refused again because
# only a known data consumer's body is dropped. rev-agent-202's round-1 review
# measured the first fourteen, and the author the rest; the body is a merge
# throughout, beside a gh api read.
req GH-202.1 US-15
check no-pr-decisions.sh BLOCK "sh -s <<'EOF' runs its body" \
  $'sh -s <<\'EOF\'\ngh pr merge 5\nEOF\ngh api repos/o/r/pulls/5'
check no-pr-decisions.sh BLOCK "bash -s <<'EOF' runs its body, a release create" \
  $'bash -s <<\'EOF\'\ngh release create v1\nEOF\ngh api repos/o/r/issues/5'
check no-pr-decisions.sh BLOCK "bash -s -- a b <<'EOF' runs its body" \
  $'bash -s -- a b <<\'EOF\'\ngh pr merge 5\nEOF\ngh api repos/o/r/pulls/5'
check no-pr-decisions.sh BLOCK "env bash -s <<'EOF' runs its body" \
  $'env bash -s <<\'EOF\'\ngh pr merge 5\nEOF\ngh api repos/o/r/pulls/5'
check no-pr-decisions.sh BLOCK "ssh host bash -s <<'EOF' runs its body" \
  $'ssh host bash -s <<\'EOF\'\ngh pr merge 5\nEOF\ngh api repos/o/r/pulls/5'
check no-pr-decisions.sh BLOCK "sh - <<'EOF' runs its body" \
  $'sh - <<\'EOF\'\ngh pr merge 5\nEOF\ngh api repos/o/r/pulls/5'
check no-pr-decisions.sh BLOCK "bash /dev/stdin <<'EOF' runs its body" \
  $'bash /dev/stdin <<\'EOF\'\ngh pr merge 5\nEOF\ngh api repos/o/r/pulls/5'
check no-pr-decisions.sh BLOCK ". /dev/stdin <<'EOF' runs its body" \
  $'. /dev/stdin <<\'EOF\'\ngh pr merge 5\nEOF\ngh api repos/o/r/pulls/5'
check no-pr-decisions.sh BLOCK "cat <<'EOF' | sh pipes its body to a shell" \
  $'cat <<\'EOF\' | sh\ngh pr merge 5\nEOF\ngh api repos/o/r/pulls/5'
check no-pr-decisions.sh BLOCK "cat <<'EOF' | bash -s pipes its body to a shell" \
  $'cat <<\'EOF\' | bash -s\ngh pr merge 5\nEOF\ngh api repos/o/r/pulls/5'
check no-pr-decisions.sh BLOCK "source <(cat <<'EOF' ...) runs its body" \
  $'source <(cat <<\'EOF\'\ngh pr merge 5\nEOF\n)\ngh api repos/o/r/pulls/5'
check no-pr-decisions.sh BLOCK "while read -r c; do \$c; done <<'EOF' runs each line" \
  $'while read -r c; do $c; done <<\'EOF\'\ngh pr merge 5\nEOF\ngh api repos/o/r/pulls/5'
check no-pr-decisions.sh BLOCK "\$(cat <<'EOF' ...) as the command word runs its body" \
  $'$(cat <<\'EOF\'\ngh pr merge 5\nEOF\n)\ngh api repos/o/r/pulls/5'
check no-pr-decisions.sh BLOCK "python3 - <<'EOF' runs its body" \
  $'python3 - <<\'EOF\'\ngh pr merge 5\nEOF\ngh api repos/o/r/pulls/5'
check no-pr-decisions.sh BLOCK "tee F <<'EOF' is not a known consumer: it writes its body to stdout too" \
  $'tee /tmp/f <<\'EOF\'\nnever `gh pr merge 5` here\nEOF\ngh api repos/o/r/pulls/5'
check no-pr-decisions.sh BLOCK "cat > /dev/stdout <<'EOF' | sh: a /dev target is not a proven file" \
  $'cat > /dev/stdout <<\'EOF\' | sh\ngh pr merge 5\nEOF\ngh api repos/o/r/pulls/5'
check no-pr-decisions.sh BLOCK "cat > F <<'EOF' | sh: a lone pipe after the consumer leaves it unproven" \
  $'cat > /tmp/f <<\'EOF\' | sh\ngh pr merge 5\nEOF\ngh api repos/o/r/pulls/5'

# THE OPENERS BASH DOES NOT SEE, which the first version of this fix trusted: a
# `<<` the heredoc pass matched where bash reads text dropped real commands up
# to the next line equal to its delimiter. g01 to g04, g13 and d01 to d03 are
# rev-agent-202's round-1 rows, the rest the author's; each was refused before
# #202 and permitted at 78c9de9.
check no-pr-decisions.sh BLOCK 'g03: <<EOF inside a double-quoted body argument, a merge on the next line' \
  $'gh api -X PATCH repos/o/r/issues/5 -f body="heredocs use <<EOF"\ngh pr merge 5\ncat > /tmp/f <<EOF\nx\nEOF'
check no-pr-decisions.sh BLOCK "g13: <<'EOF' whole inside a double-quoted argument, and a later <<'EOF'" \
  $'gh api -X PATCH repos/o/r/issues/5 -f body="bodies use <<\'EOF\' always"\ngh pr merge 5\ncat > /tmp/f <<\'EOF\'\nx\nEOF'
check no-pr-decisions.sh BLOCK "g04: <<'EOF' closing a double-quoted argument" \
  $'gh api -X PATCH repos/o/r/issues/5 -f body="use <<\'EOF\'"\ngh pr merge 5\ncat > /tmp/f <<\'EOF\'\nx\nEOF'
check no-pr-decisions.sh BLOCK 'g01: <<EOF inside a single-quoted argument, a merge in $( ) in a real body' \
  $'gh api -X PATCH repos/o/r/issues/5 -f body=\'note: <<EOF\'\ncat <<EOF\nx $(gh pr merge 5) y\nEOF'
check no-pr-decisions.sh BLOCK 'g02: the same after a gh issue view, a backticked merge in the real body' \
  $'gh issue view 5; gh api -X PATCH repos/o/r/issues/5 -f body="heredocs use <<EOF"\ncat <<EOF\n`gh pr merge 5`\nEOF'
check no-pr-decisions.sh BLOCK "d02: echo \"see <<'EOF'\", a release write on the next line" \
  $'echo "see <<\'EOF\'"\ngh api -X POST repos/o/r/releases -f tag_name=v1\nEOF\ngh api repos/o/r/pulls/5'
check no-pr-decisions.sh BLOCK "d03: echo 'see <<\"EOF\"', a backticked release write on the next line" \
  $'echo \'see <<"EOF"\'\n`gh api -X POST repos/o/r/releases -f tag_name=v1`\nEOF\ngh api repos/o/r/pulls/5'
check no-pr-decisions.sh BLOCK "d01: <<'EOF' in a # comment" \
  $'echo hi # <<\'EOF\'\n`gh api -X POST repos/o/r/releases -f tag_name=v1`\nEOF\ngh api repos/o/r/pulls/5'
check no-pr-decisions.sh BLOCK "a backslash before the <<, which bash reads as two words" \
  $'echo \\<<\'EOF\'\ngh pr merge 5\nEOF\ngh api repos/o/r/pulls/5'
check no-pr-decisions.sh BLOCK "<<'EOF' inside \$'...', whose \\' does not close it" \
  $'echo $\'it\\\'s <<\'EOF\'\ngh pr merge 5\nEOF\ngh api repos/o/r/pulls/5'
check no-pr-decisions.sh BLOCK 'a double-quoted argument across lines, holding a line that is a whole opener' \
  $'gh api -X PATCH repos/o/r/issues/5 -f body="notes:\ncat > /tmp/f <<\'EOF\'\n"\ngh pr merge 5\ncat > /tmp/g <<\'EOF\'\nx\nEOF'
check no-pr-decisions.sh BLOCK "a case pattern's ) inside \"\$( )\", which the quote state does not follow" \
  $'echo "$(case x in a) echo "<<\'EOF\'";; esac)"\ngh pr merge 5\nEOF\ngh api repos/o/r/pulls/5'
check no-pr-decisions.sh BLOCK 'a command continued onto the opener line: bash -s, then cat > F <<EOF, feeds the body to the shell' \
  $'bash -s \\\ncat > /tmp/f <<\'EOF\'\ngh pr merge 5\nEOF\ngh api repos/o/r/pulls/5'
# THE COST OF NOT FOLLOWING NESTED QUOTES, pinned: a `$( )` in double quotes is
# doubt even where the opener after it is real and its reader a data consumer.
# That doubt on the opener's own line decides the opener was missing from the
# first version of this fix, found by this row.
check no-pr-decisions.sh BLOCK 'a $( ) in double quotes in front of a real cat > F opener is doubt' \
  $'echo "$(x "a")" && cat > /tmp/f <<\'EOF\'\nnever `gh pr merge 5` here\nEOF\ngh api repos/o/r/pulls/5'
# DOUBT IS STICKY: the first opener the quote state cannot vouch for ends every
# drop after it, so a real consumer's body later in the same command is kept --
# pinned as the cost it is, since bash runs nothing of that body. The doubted
# `<<X` has its delimiter on the next line, so cs_normalise ends it there and
# the later body is dropped from $SCAN: only the stickiness refuses the row. An
# earlier version of this row opened with `<<"`, which never ends, and the END
# give-back refused it whatever this mode did; the mutation harness said so.
check no-pr-decisions.sh BLOCK 'a doubted opener keeps a later cat > F body too' \
  $'echo "a <<X"\nX\ncat > /tmp/f <<\'EOF\'\nnever `gh pr merge 5` here\nEOF\ngh api repos/o/r/pulls/5'
# EACH CONDITION'S OWN ROW, found by breaking each one alone: a row whose opener
# is refused by a second condition as well, or whose reader is no data consumer
# anyway, says nothing about the first. The escape and comment rows above use
# `echo`, which keeps its body whichever condition holds; these use `gh`, which
# drops it unless the condition does.
check no-pr-decisions.sh BLOCK "a backslash before the <<, beside gh: gh gets the word < and reads a file named EOF" \
  $'gh api repos/o/r/pulls/5 \\<<\'EOF\'\ngh pr merge 5\nEOF'
check no-pr-decisions.sh BLOCK "<<'EOF' in a # comment after a gh command" \
  $'gh api repos/o/r/pulls/5 # <<\'EOF\'\ngh pr merge 5\nEOF'
check no-pr-decisions.sh BLOCK "a ; inside a # comment is not a separator, so cat > F behind it is not a command" \
  $'echo hi # x; cat > /tmp/f <<\'EOF\'\ngh pr merge 5\nEOF\ngh api repos/o/r/pulls/5'
check no-pr-decisions.sh BLOCK "\$(cat > /dev/stdout <<'EOF' ...) as the command word: a /dev target is not a proven file" \
  $'$(cat > /dev/stdout <<\'EOF\'\ngh pr merge 5\nEOF\n)\ngh api repos/o/r/pulls/5'
# THE SECOND TRADE, pinned where it is refused: the idiom whose opener stands
# inside "$(, doubt and kept, as before #202.
check no-pr-decisions.sh BLOCK "TRADE: -f body=\"\$(cat <<'MD' ...)\" is doubt, and its body is re-read" \
  $'gh api -X PATCH repos/o/r/issues/5 -f body="$(cat <<\'MD\'\nnever `gh pr merge 5` here\nMD\n)"'

# THE UNQUOTED BODY, which bash expands: re-read as commands exactly as before.
req GH-202.1 US-15
check no-pr-decisions.sh BLOCK 'row 9: row 4 with <<MD unquoted, where bash runs the backticks' \
  $'cat > /tmp/new.md <<MD\nMeasured: `gh api -X POST repos/o/r/releases -f tag_name=v1` stays BLOCK.\nMD\ngh api -X PATCH repos/o/r/pulls/196 -F body=@/tmp/new.md'
says "$SUITE_DIR" no-pr-decisions.sh 'any write to a release is Bertan' \
  'and it is the release rule that refuses it, reading the backticked write as a command' \
  $'cat > /tmp/new.md <<MD\nMeasured: `gh api -X POST repos/o/r/releases -f tag_name=v1` stays BLOCK.\nMD\ngh api -X PATCH repos/o/r/pulls/196 -F body=@/tmp/new.md'
req GH-202.1 US-15
check no-pr-decisions.sh BLOCK 'a backticked merge in an unquoted body, then W' \
  $'cat > /tmp/new.md <<EOF\nx `gh pr merge 5` y\nEOF\ngh api -X PATCH repos/o/r/pulls/196 -F body=@/tmp/new.md'
check no-pr-decisions.sh BLOCK 'a merge inside $( ) in an unquoted body, then a gh api read' \
  $'cat <<EOF\nx $(gh pr merge 5) y\nEOF\ngh api repos/o/r/pulls/196'
# The edge of the trade: a shell reading the heredoc with nothing between, which
# the wrapper anchor does recognise, is refused whatever the quoting.
check no-pr-decisions.sh BLOCK "sh <<'EOF' running a merge, beside a gh api read: a wrapper, whatever the quoting" \
  $'sh <<\'EOF\'\ngh pr merge 5\nEOF\ngh api repos/o/r/pulls/5'
# A quoted and an unquoted heredoc on one line, each deciding by its own
# quoting: the quoted body's release write is prose, the unquoted body's merge
# is a command. A mode that answered per line rather than per heredoc turns
# this red either way.
check no-pr-decisions.sh BLOCK "a quoted body and an unquoted one on one line: the unquoted body's merge still refuses" \
  $'cat > /tmp/a.md <<\'MD\'\n`gh api -X POST repos/o/r/releases -f tag_name=v1`\nMD\ncat > /tmp/b.md <<EOF\nx `gh pr merge 5` y\nEOF\ngh api -X PATCH repos/o/r/pulls/196 -F body=@/tmp/a.md'
says "$SUITE_DIR" no-pr-decisions.sh "deciding a pull request is Bertan's call" \
  'and it is the merge that refuses it, not the quoted release write before it' \
  $'cat > /tmp/a.md <<\'MD\'\n`gh api -X POST repos/o/r/releases -f tag_name=v1`\nMD\ncat > /tmp/b.md <<EOF\nx `gh pr merge 5` y\nEOF\ngh api -X PATCH repos/o/r/pulls/196 -F body=@/tmp/a.md'

# THE GRAPHQL RULES STILL READ A QUOTED BODY AS TEXT.
req GH-202.2 US-15
check no-pr-decisions.sh BLOCK "a graphql mutation on stdin through <<'EOF'" \
  $'gh api graphql -f query=@- <<\'EOF\'\nmutation { mergePullRequest(input:{pullRequestId:"x"}) { clientMutationId } }\nEOF'
check no-pr-decisions.sh BLOCK 'a graphql mutation on stdin through <<EOF' \
  $'gh api graphql -f query=@- <<EOF\nmutation { mergePullRequest(input:{pullRequestId:"x"}) { clientMutationId } }\nEOF'
check no-pr-decisions.sh BLOCK "a graphql mutation piped from cat <<'EOF'" \
  $'cat <<\'EOF\' | gh api graphql -f query=@-\nmutation { mergePullRequest(input:{pullRequestId:"x"}) { clientMutationId } }\nEOF'
# THE FILE-STAGED MUTATION, which no check pinned before this file: the
# heredoc writes the query to a file and the next line sends it. The graphql
# rules are all that catch it, and they catch it by reading the quoted body.
check no-pr-decisions.sh BLOCK "a graphql mutation staged in a file through <<'EOF', then sent by -f query=@file" \
  $'cat > /tmp/q.gql <<\'EOF\'\nmutation { mergePullRequest(input:{pullRequestId:"x"}) { clientMutationId } }\nEOF\ngh api graphql -f query=@/tmp/q.gql'
says "$SUITE_DIR" no-pr-decisions.sh 'through a graphql mutation' \
  'and it is the mutation rule that refuses the staged file, reading the quoted body as text' \
  $'cat > /tmp/q.gql <<\'EOF\'\nmutation { mergePullRequest(input:{pullRequestId:"x"}) { clientMutationId } }\nEOF\ngh api graphql -f query=@/tmp/q.gql'
check no-pr-decisions.sh BLOCK 'the same staged through <<EOF' \
  $'cat > /tmp/q.gql <<EOF\nmutation { mergePullRequest(input:{pullRequestId:"x"}) { clientMutationId } }\nEOF\ngh api graphql -f query=@/tmp/q.gql'
req GH-202.2 FR-19
check no-pr-decisions.sh BLOCK "a createPullRequest staged in a file through <<'EOF' naming base main" \
  $'cat > /tmp/q.gql <<\'EOF\'\nmutation { createPullRequest(input:{repositoryId:"x", baseRefName:"main", headRefName:"f", title:"t"}) { pullRequest { number } } }\nEOF\ngh api graphql -f query=@/tmp/q.gql'
req GH-202.2 US-15
check no-pr-decisions.sh BLOCK 'a REST merge whose body is on stdin, refused on its endpoint' \
  $'gh api -X PUT repos/o/r/pulls/5/merge --input - <<\'EOF\'\n{"merge_method":"squash"}\nEOF'
# THE TRADE, both halves. Beside a real graphql call the gate is open and the
# quoted prose is read as the mutation or the base it names; beside a REST
# write the gate is shut and the same prose is prose.
check no-pr-decisions.sh BLOCK "TRADE: a quoted body naming a mutation, beside a real gh api graphql call" \
  $'cat > /tmp/new.md <<\'MD\'\nthe mergePullRequest mutation is Bertan\'s\nMD\ngh api graphql -f query=\'{ viewer { login } }\''
req GH-202.2
check no-pr-decisions.sh BLOCK 'TRADE: a quoted body naming baseRefName main, beside a real gh api graphql call' \
  $'cat > /tmp/new.md <<\'MD\'\nthe field is baseRefName: "main"\nMD\ngh api graphql -f query=\'{ viewer { login } }\''
req GH-202.2 US-14
check no-pr-decisions.sh ALLOW 'the same mutation prose in a quoted body, beside W, where the gate is shut' \
  $'cat > /tmp/new.md <<\'MD\'\nthe mergePullRequest mutation is Bertan\'s\nMD\ngh api -X PATCH repos/o/r/pulls/196 -F body=@/tmp/new.md'
check no-pr-decisions.sh ALLOW 'the same base prose in a quoted body, beside W' \
  $'cat > /tmp/new.md <<\'MD\'\nthe field is baseRefName: "main"\nMD\ngh api -X PATCH repos/o/r/pulls/196 -F body=@/tmp/new.md'
check no-pr-decisions.sh ALLOW "#130 row 8, an unquoted issue body on stdin naming /releases, re-read and still prose" \
  $'gh api -X PATCH repos/o/r/issues/27 -F body=@- <<EOF\nthe tarball is under /releases\nEOF'
check no-pr-decisions.sh ALLOW '#130 row 9, the same naming a mutation' \
  $'gh api -X PATCH repos/o/r/issues/27 -F body=@- <<EOF\nthe mergePullRequest mutation does it\nEOF'

# THE LOAD, AND A CALL THAT FAILS. A library without the function is #84's
# case for a function this issue added, driven as the unsplit file drives the
# others. A call that fails is driven by a library whose sibling asks the pass
# for a mode it refuses, which returns 2 and prints nothing: the hook must fall
# back on the raw command, and without the fallback the unquoted body's merge,
# which only the re-read can see, would be permitted.
req GH-202.3
mk_halflib no-pr-decisions.sh cs_drop_quoted_heredocs
check_in "$SUITE_DIR" "$(halflib_path no-pr-decisions.sh cs_drop_quoted_heredocs)" BLOCK \
  'a library missing only cs_drop_quoted_heredocs refuses anything at all' 'ls'
says "$SUITE_DIR" "$(halflib_path no-pr-decisions.sh cs_drop_quoted_heredocs)" 'no-pr-decisions.sh could not load' \
  'and names the hook, as every load refusal does' 'ls'
armed 'no-pr-decisions.sh requires cs_drop_quoted_heredocs' \
  "$HOOKS/no-pr-decisions.sh" 'command -v cs_drop_quoted_heredocs'
R202_FAILING="$FIXTURES/r202-failing-mode"
mkdir -p "$R202_FAILING/lib"
cp "$HOOKS/no-pr-decisions.sh" "$R202_FAILING/"
sed 's/^  cs_drop_heredocs keep-unquoted$/  cs_drop_heredocs keep-nothing-known/' \
  "$HOOKS/lib/command-scan.sh" > "$R202_FAILING/lib/command-scan.sh"
# Both directions on the edit, as mk_halflib guards its rename: an edit that
# matched nothing leaves the working library behind, and the rows below would
# read the fix's own verdicts as the fallback's. And that the fixture still
# permits an ordinary read, as mk_halflib asks that what is left still loads: a
# fixture refusing everything would pass both rows below for a reason of its
# own. A guard and not a row, so GH-202.3 stays refuse-only.
grep -q '^  cs_drop_heredocs keep-nothing-known$' "$R202_FAILING/lib/command-scan.sh" \
  && ! grep -q '^  cs_drop_heredocs keep-unquoted$' "$R202_FAILING/lib/command-scan.sh" \
  && [ -x "$R202_FAILING/no-pr-decisions.sh" ] \
  && printf '%s' 'gh pr view 5' | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' \
     | ( cd "$SUITE_DIR" && "$R202_FAILING/no-pr-decisions.sh" ) >/dev/null 2>&1 || {
  echo "the #202 failing-mode fixture was not built, or refuses an ordinary read; the checks against it prove nothing" >&2
  exit 1
}
check_in "$SUITE_DIR" "$R202_FAILING/no-pr-decisions.sh" BLOCK \
  "with the call failing, row 4's quoted release write is re-read from the raw command and refused" \
  $'cat > /tmp/new.md <<\'MD\'\nMeasured: `gh api -X POST repos/o/r/releases -f tag_name=v1` stays BLOCK.\nMD\ngh api -X PATCH repos/o/r/pulls/196 -F body=@/tmp/new.md'
check_in "$SUITE_DIR" "$R202_FAILING/no-pr-decisions.sh" BLOCK \
  "with the call failing, an unquoted body's merge beside a gh api read is still refused" \
  $'cat <<EOF\nx $(gh pr merge 5) y\nEOF\ngh api repos/o/r/pulls/196'

sourced_to_end

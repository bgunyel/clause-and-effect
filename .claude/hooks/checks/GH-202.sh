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
# CMDS is split from CMDTEXT, which re-admits the raw command with its QUOTED
# bodies taken out by cs_drop_quoted_heredocs in lib/command-scan.sh -- the
# heredoc pass's own answer to where a body begins, in a mode that keeps
# unquoted bodies, since bash runs what is in those. line_was_cut and the state
# fallback read CMDTEXT. The hook argues it above the re-admission.
#
# WHICH ROWS CAN FAIL, measured rather than argued: the whole suite was run
# against a copy of .claude/hooks/ holding the pre-fix no-pr-decisions.sh, from
# 1b01ceb, beside this branch's library, through $CHECK_HOOKS_DIR. All twelve
# `flip` rows went red with got=BLOCK, and so did the three load rows of
# GH-202.3, the pre-fix hook neither calling nor requiring the new function;
# every `check` row stayed green. The one other red was GH-182.3's verbatim pin
# of the re-admission block, whose text the fix changes. This repository's
# hooks were never edited to do it.
#
# WHAT IT TAKES FROM ELSEWHERE: $SUITE_DIR and $FIXTURES from the driver's
# prelude, and mk_halflib and halflib_path from the library.

section "=== issue #202: a quoted heredoc's body is not re-read as commands ==="

requirement GH-202.1 <<'REQ'
- text: When `no-pr-decisions.sh` re-admits a command's heredoc bodies because a
  `gh api` call is on its line, the body of a heredoc whose delimiter is QUOTED
  -- holding a `'`, a `"` or a `\` anywhere, so `<<'X'`, `<<"X"`, `<<-'X'`,
  `<<-"X"` and `<<X"Y"` -- is not split into command candidates for any rule,
  whatever follows its delimiter, and is not read by `line_was_cut` or the
  state field's fallback. So prose in such a body quoting a release write, a
  merge, a release create or `-f state=closed`, in backticks, in a `$( )` or at
  a line's start, is permitted beside a `gh api` write or read; and a body line
  reading `gh api graphql` does not open the graphql gate. The body of an
  UNQUOTED heredoc is re-read as commands exactly as before, since bash runs
  the `$( )` and backticks in it: a merge or a release write in one, beside a
  `gh api` call, is refused.
- from: #202, and its triage's table: rows 4, 8 to 8‴ and 9, shapes A, B, C, D,
  D2 and F
- kind: defect-refusing
- status: active
- variants: none: its subject is a heredoc -- an opener, a body on lines of its
  own and a delimiter -- and whether the delimiter is quoted, which is a
  multi-line shape no transformation writes; the quoting spellings of the
  delimiter are rows here
- note: The re-admission is still gated on a `gh api` call on the line, and no
  verdict is pinned here on a heredoc whose line has none. Row 7 of the issue,
  an unpaired backtick, is out of scope, and so is `<<\X`, whose delimiter the
  heredoc pass reads as `\X`: it never arrives, so the body is given back as
  commands in every hook -- the refusing direction, in the library.
  THE TRADE, taken knowingly and pinned: "nothing in a quoted body can run" is
  true of the heredoc and not of what reads it. A shell reading its script from
  stdin through an option or through `/dev/stdin` -- `sh -s <<'EOF'`,
  `bash -s <<'EOF'`, `source /dev/stdin <<'EOF'` -- runs the body, and no hook
  recognises those as wrappers, so they are permitted with no `gh api` call on
  the line, before this fix and after it. Beside a `gh api` call the old
  re-read refused them by accident, and this fix permits them: a refusal
  lost, in the permitting direction. The fix belongs in the wrapper anchor,
  for every hook, and is #311's; the flagless `sh <<'EOF'` stays refused as a
  wrapper.
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

# THE TRADE, pinned where it is permitted: a quoted heredoc read by a shell that
# is not recognised as a wrapper runs its body, and beside a gh api call these
# were refused only because the old re-read read every body. Found by the spec
# review of this branch, measured BLOCK at 84af65e. #311 owns the wrapper
# anchor, and closing it turns these two red, which is the intended outcome.
check no-pr-decisions.sh ALLOW "TRADE (#311): sh -s <<'EOF' running a merge, beside a gh api read" \
  $'sh -s <<\'EOF\'\ngh pr merge 5\nEOF\ngh api repos/o/r/pulls/5'
check no-pr-decisions.sh ALLOW "TRADE (#311): bash -s <<'EOF' running a release create, beside a gh api read" \
  $'bash -s <<\'EOF\'\ngh release create v1\nEOF\ngh api repos/o/r/issues/5'

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

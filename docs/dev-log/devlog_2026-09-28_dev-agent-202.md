# 2026-09-28 11:20 +0300 · dev-agent-202 — #202: a quoted heredoc's body is not re-read as commands

Branch `worktree-issue-202-quoted-heredoc-body`, cut from `origin/dev-05` at
`1b01ceb`. The assistant fast-forwarded it to `84af65e` before the first commit,
because the stale-branch guard refused a commit on a branch with no work of its
own that dev-05 had moved past. It merged `origin/dev-05` at `97b5679` (#159)
before the last run. The entry closes the branch's work. This file is its last
commit, on top of the merge.

## What was built

- **`lib/command-scan.sh`.** `cs_drop_heredocs` takes one argument,
  `keep-unquoted`. With it, an unquoted heredoc's body is printed instead of
  dropped. Where a body begins and ends is still answered by the same lines.
  Any other argument returns 2 and prints nothing. `cs_drop_quoted_heredocs`
  is that call under a name, so the load guard has a function to require.
  "Quoted" follows bash's rule: the delimiter as written holds a `'`, a `"` or
  a `\`.
- **`no-pr-decisions.sh`.** The re-admission now builds two texts.
  - `$SCAN` still gets the whole raw command. The three graphql rules read it
    as text.
  - `CMDS` is split from `CMDTEXT`, which gets the raw command with its quoted
    bodies removed. `line_was_cut` and the state fallback read `CMDTEXT` too.
  - A failed call falls back on the raw command, which is the pre-#202
    reading.
- **`checks/GH-202.sh`.** It declares GH-202.1, GH-202.2 and GH-202.3. It
  holds:
  - twelve `flip` rows
  - the unquoted, graphql and trade rows
  - the load and failing-call rows
- **`mutate-hooks.sh`.** Three rows were added:
  - `heredoc-quoting-inverted`
  - `readmission-splits-the-raw-command`
  - `readmission-drops-the-fallback`

## Measured

- **Pre-fix copy.** The suite ran against a copy of `.claude/hooks/` holding
  `no-pr-decisions.sh` from `1b01ceb`, through `CHECK_HOOKS_DIR`. It had 16
  FAIL:
  - all twelve flips, got=BLOCK
  - the three GH-202.3 load rows
  - GH-182.3's verbatim pin of the edited block

  Every `check` row stayed green.
- **The tree.** ALL CHECKS PASSED on the tree with the review fixes, and
  again on the merged tree at `4d9ee4e`.
- **`mutate-hooks.sh -v`** on the three rows: each caught, 4 runs including the
  baseline.

## Mistakes and dead ends

- **The assistant's first claim about quoted bodies was false.** Its first
  comment in the library said "nothing in such a body can run". The spec
  review sub-agent found it false for a heredoc fed to a shell reading stdin:
  `sh -s <<'EOF'`, `bash -s <<'EOF'`, `source /dev/stdin <<'EOF'`.
  - Beside a `gh api` call, these went from BLOCK to ALLOW. The old re-read
    had refused them by accident.
  - With no `gh api` on the line they were permitted before too, and
    `bash -s <<'EOF'` / `git push --force origin main` is permitted by
    `no-git-push.sh` today.
  - The assistant filed the wrapper-anchor gap as #311, recorded the loss as a
    trade in the hook, GH-202.1's note and two pinned rows, and corrected the
    library comment.
- **Standards review fixes.**
  - The `<<\X` note said the pass does not recognise `<<\X` as an opener at
    all. It does recognise it; its delimiter never arrives.
  - GH-202.3 was declared refuse-only while carrying an ALLOW control row. That
    row is now a fixture guard.
  - Two library comments had gone stale.
- **An edit refused by the hook.** An edit script carried in a heredoc was
  refused by `no-pr-decisions.sh`, which is consequence 7 of CLAUDE.md. The
  assistant moved it to a file.

## Open

- **GH-182.2's text was revised in place, not marked.** Its sentence "No hook
  calls `cs_drop_heredocs` but through `cs_normalise`" became false, and it now
  also names `cs_drop_quoted_heredocs`. The requirement itself, the withdrawal,
  is unchanged. The standards review flagged the edit against *The rules this
  file keeps*, so it is Bertan's call.
- **#311**: the wrapper anchor, for every hook.
- **#289**: GH-182.3 still holds the re-admission block verbatim, and this
  branch updated that literal.


# 2026-09-28 22:10 +0300 · dev-agent-202 — #202, round 1 of the review of PR #314

Branch `worktree-issue-202-quoted-heredoc-body`, from `78c9de9` to `30a07f8`
and this entry. The assistant merged `origin/dev-05` twice. The first merge,
at `7c6766c` (#313, #295's derived check order), conflicted on
`SUITE_CHECKS`, and dev-05's side was taken. Before that merge was committed
the base moved to `0d5829d` (#291), whose merge conflicted in
`requirements.md` on the cited-issue list; both entries were kept. rev-agent-202
reviewed `78c9de9`
(https://github.com/bgunyel/clause-and-effect/pull/314#issuecomment-5866831690).

## What the review found, and what was done

- **Gate 1: a misread opener decided a permit.** The first version dropped
  every quoted body from the re-read. Before #202, the re-read of the whole raw
  command covered every `<<` the heredoc pass misread (#289's class). So
  `-f body="heredocs use <<EOF"`, then `gh pr merge 5`, then a real heredoc
  ending at `EOF`, went from BLOCK to ALLOW. rev-agent-202 measured 8 rows. The
  assistant reproduced all 8 on stdin and found 4 more: a backslash before the
  `<<`, `$'...'`, a double-quoted string across lines, and a case pattern
  inside `"$( )"`. The fix is confined to `keep-unquoted` mode. A quote and
  comment state carried over the command vetoes a drop at any opener bash
  would not see. What it cannot follow is doubt, and doubt is sticky.
- **Gate 2: 14 lost refusals recorded as 2.** rev-agent-202 swept the readers
  that run a quoted body: `sh -s`, `bash /dev/stdin`, a pipe to `sh`,
  `source <(...)`, a while-read loop, `$(cat <<)` as a command word. All 14
  went from BLOCK to ALLOW. The assistant found a 15th, `python3 -`, and argued
  the list has no end. rev-agent-202 agreed to invert it: a quoted body is
  dropped only when `cat` into a file or a `gh` command reads it. One loss
  remains, a body staged in a file and run by a later command. It is #311's,
  and pinned as a trade.
- **Gate 3.** The four claims wider than the code were rewritten. The state
  fallback's comment cites #138 for a body sent as the request payload.

## Measured

- On 372 distinct Bash commands holding `gh api` and `<<`, taken from the
  local session transcripts, the first version permitted 4 that `0d5829d`
  refuses. This version permits 3 of them. The fourth is a `python3 - <<'PY'`
  script, whose body runs. One idiom is given up, `-f body="$(cat <<'MD' ...)"`:
  2 of the 372.
- The suite was run through `CHECK_HOOKS_DIR` from a copy of the working tree:
  - with the pre-fix hook from `0d5829d`, all 18 `flip` rows and the
    staged-script TRADE row went red with got=BLOCK;
  - with the first version's library from `78c9de9`, all 37 new BLOCK rows went
    red with got=ALLOW.
- `bash .claude/hooks/check-hooks.sh`: ALL CHECKS PASSED at `30a07f8`. The
  registry has 156 rows, 154 caught, and the text checks stay at 322. All
  counts were derived on the merged tree.
- `mutate-hooks.sh -v` on the 14 #202 rows at `30a07f8`: all 14 caught, 15
  runs with the baseline included, and `.claude/hooks/` byte-identical
  afterwards.

## Mistakes and dead ends

- **The assistant's first draft of the fix had four defects of its own, each
  found by measurement and not by reading.**
  - The quote state wrote its own separator list. The #134 static check
    caught it in the prototype.
  - Doubt raised on the opener's own line did not veto that opener. The row
    `echo "$(x "a")" && cat > F <<'EOF'` caught it.
  - The comment condition could not fail: `lex` answered a comment through its
    return value, so the escape condition refused a `<<` in a comment by
    accident. The harness reported `heredoc-opener-in-comment-seen` survived.
  - A statement making doubt sticky decided nothing, because another line
    already did it.

  Applying every mutation alone to rows fed on stdin then found three rows that
  held their condition only through another: the escape and comment rows read
  through `echo`, and the `/dev` row carried a pipe. Rows were added for each.
- **The auto-mode classifier refused hook edits as self-modification**, twice.
  The first refusal left the merge mid-conflict. The assistant posted a status
  comment and stopped. The session then left auto mode and the work resumed.
  Auto mode came back on mid-lane, and the next hook edit was refused again. The assistant pushed
  the unfinished library change as a WIP commit (`03c593e`) before stopping the
  second time.
- **A mutation run was stopped partway** by the assistant, by PID, once
  `heredoc-opener-in-comment-seen` survived, because the fix changed the code
  it was testing.
- **A test command was refused by `no-pr-decisions.sh`**, because the text of
  its rows carried a merge. The assistant moved it to a script file.

## Open

- **#311**: the stdin shells, and the staged script this branch pins as
  permitted.
- **#289**: `cs_normalise`'s own opener is still quote-blind. This branch's
  quote state serves only the `keep-unquoted` mode.
- **GH-182.2's in-place edit**: still Bertan's decision, as the first entry
  says.

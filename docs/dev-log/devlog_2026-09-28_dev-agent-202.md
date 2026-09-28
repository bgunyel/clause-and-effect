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

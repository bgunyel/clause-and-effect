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


# 2026-09-29 12:15 +0300 · dev-agent-202 — #202, round 2 of the review of PR #314

Branch `worktree-issue-202-quoted-heredoc-body`, from `c446ec3` to `48e462e`
and this entry. The assistant merged `origin/dev-05` at `abffdbf` (`b6ece96`),
which conflicted on the registry literals and the cited-issue list, and at
`f539d9a` (`02f21fc`), which merged cleanly, and at `b120086` (#329, `48e462e`),
which conflicted on the same two lists. rev-agent-202 reviewed `b6ece96`
(https://github.com/bgunyel/clause-and-effect/pull/314#issuecomment-5884057201).

## What the review found, and what was done

- **Gate 4: the drop still trusted what it did not model.** The round-1 mode
  vetoed a drop only at constructs it knew it could not follow. The review
  measured 16 shapes the base refuses and round 1 permitted:
  - delimiters that deleting quote characters gets wrong (`<<"it's"`,
    `<<E\OF`, `<<\EOF`, `<<$'EOF'`, `<<"E\"F"`);
  - `${…}` and `$[…]`;
  - `/dev/stdout` spelled so a text test misses it (`//`, `"…"`, `/./`,
    `>(sh)`);
  - `gh codespace ssh`.

  rev-agent-202 suggested making round 1's inversion for the opener line, and
  the assistant did. A drop now needs:
  - a delimiter grammar;
  - `cat` into a plain file, or `gh api` and no other `gh`;
  - no `${…}` with an operator, `$[…]` or `((` earlier on the line, which are
    doubt.

  On the 372-command corpus, all 3 permits #202 gains are kept and nothing
  else moves.
- **The default mode has the delimiter defect in every hook.** The assistant
  ran the five delimiters against `no-git-push.sh` on `dev-05` with no
  `gh api` on the line. All five were permitted, and bash ran the payload
  line in each (the push replaced by `touch`, in a scratch directory). Filed
  as #351. The library's `<<\X` note, which called that shape refusing, was
  wrong, and is corrected.
- **Gate 5: three conditions survived mutation (N6–N8).** The assistant
  applied every mutation alone to every row on stdin and found more of the
  class than the three.
  - Three tests shadowed each other: `.`/`..`, a `/dev`–`/proc` prefix, and
    device names. They are one line now.
  - The delimiter-closure test was implied by the grammar and is gone.
  - A word grammar for `gh api` refused only what the quote state already
    doubts. It is gone.
  - Once the grammar was in, the escape, quote and comment conditions stopped
    deciding any drop on their own line. The assistant then found where they
    still matter: a `<<` taken for an opener and kept makes the quote state
    skip lines that bash reads as commands. A string opened there leaves the
    state at the top where bash is inside quotes, and a later `; cat > F`
    drops a merge. Bash ran the merge line in all four such rows (quote,
    comment, backslash, continuation), measured by execution. Those rows are
    each condition's witness now.
- **Prose.** The three statements that the mode "can only fail towards the
  re-read" are rewritten as WHERE IT STILL TRUSTS A MODEL: the claim covers
  the constructs named, and is not a proof over bash's grammar.

## Measured

- **Corpus:** 372 distinct commands holding `gh api` and `<<` from local
  transcripts, on `f539d9a`, `b6ece96` and this branch: 332 permitted by all
  three, 37 refused by all three, 3 gained by #202 and kept.
- **`CHECK_HOOKS_DIR`, from a copy of `518acfe`:**
  - pre-fix hook: all 22 `flip` rows and the TRADE row red with got=BLOCK;
  - round-1 library: the 18 BLOCK rows it permitted red with got=ALLOW.
- **Registry:** 178 rows, 176 caught; text checks 324. Derived off the
  registry of the tree merged with `b120086`.
- `mutate-hooks.sh -v` on the 23 #202 rows at `518acfe`: all 23 caught, 24
  runs including the baseline, and `.claude/hooks/` byte-identical
  afterwards.
- `bash .claude/hooks/check-hooks.sh`: ALL CHECKS PASSED on the tree merged
  with `b120086`.

## Mistakes and dead ends

- **The assistant's first edit of the grammar broke the library.** Four
  comments inside the single-quoted awk program carried an apostrophe, which
  ended the shell word, so `lib/command-scan.sh` failed to load and every
  command was refused. The rows run on stdin showed every row BLOCK, including
  those that must be ALLOW. Two older comments had a pair of apostrophes that
  bash had been silently deleting. All six are spelt `\047` now, and the
  library says why.
- **The assistant's first registry count on the `abffdbf` merge was wrong.**
  It added this branch's 11 to dev-05's literal and pinned 163/161. The suite
  said 166/164, because the merge base held 142 rows, not 145.
- **The #311 cite entry**, carried from round 0, still called `sh -s` the
  permitted trade. The assistant rewrote it in the `abffdbf` merge.

## Open

- **#351**: the delimiter defect in the default mode, in every hook.
- **#311**: the staged script, still the one recorded trade.
- **#289**: `cs_normalise`'s own opener.
- **GH-182.2's in-place edit**: Bertan's decision.


# 2026-09-29 16:49 +0300 · dev-agent-202 — #202, round 3 of the review of PR #314

Branch `worktree-issue-202-quoted-heredoc-body`, from `2a642f3` to `e46e7c1`
and this entry. The assistant merged `origin/dev-05` at `01bfef4` (#350,
`f0cc6a0`), which conflicted on the text-check literal and the cited-issue
list. rev-agent-202 reviewed `2a642f3`
(https://github.com/bgunyel/clause-and-effect/pull/314#issuecomment-5887869787).

## What the review found, and what was done

- **Gate 6: the text in front of an opener still went through a deny-list.**
  The review measured eight shapes that `lex()` read wrong without doubting
  (q01–q08): a backtick taken for a separator, quotes inside backticks, a `#`
  after `)` or a backtick, `$$'`, two continuations, and `\}` inside `"${…}"`.
  rev-agent-202 suggested an alphabet allow-list, and the assistant built it:
  - allowed: quotes, a backslash escape, `$NAME`, `${NAME}`, a `#` after a
    blank, and the separators;
  - everything else outside single quotes is doubt.

  The assistant allowed `$(` outside double quotes, against the suggestion.
  With `$(` refused, the corpus gave back one of the three commands #202
  gains (an `id=$(gh api … --jq .id)` in front of the opener), and no row
  needed it refused.
- **A carriage return between `<<` and the delimiter.** The review could not
  build one that permits. The assistant did (`cat > /tmp/f <<\r'EOF'`),
  because awk's `[[:space:]]` takes the `\r` for space. It is refused at the
  opener now. It also permits in the default mode on `dev-05`, where bash ran
  the push; that is reported on #351.
- **Gate 7: `gh api`'s output reaches a reader.** The review measured `<( )`
  and `> >( )`. The assistant measured three more channels: a brace group, an
  `if`, and a command substitution. The review's suggested patch (no `>`
  after, not inside an unclosed paren) would have left the first two open.
  So the assistant took `gh api` out of the consumers. None of the 372 corpus
  commands fed it a quoted heredoc.
- **Trades.** A name is not resolved: a variable set to `/dev/fd`, a symlink,
  a FIFO, or a function named `cat`. These are recorded as CLAUDE.md
  consequence 6's family, with one permitted row each. The claims "a variable
  cannot smuggle in a device" and "a proven file" are corrected.
- **The Gate 5 remainder.** The assistant ran each mutation alone against
  every row on stdin, now 108 rows.
  - The device list is `stdout|stderr|fd`, with one row each. `dev`, `proc`,
    `stdin`, `tty`, `.` and `..` had no row any member alone could turn red.
  - Two tests decided nothing and were deleted, with the reason in the code:
    the carriage return inside `lex()` and the "command started here" test.
  - The `lex()` call over the delimiter was a no-op and is gone.
  - Three new rules got rows only they refuse: a bare `((`, a `#` after `;`,
    and a backtick inside double quotes. For the last, a search of 1,168
    generated strings found nothing, because its tail was fixed. The
    assistant then built the row by hand: the next line has to open with the
    quote.

## Measured

- **Corpus:** 332 permitted by all three, 37 refused by all three, 3 gained
  and kept. The three are `01bfef4`, `2a642f3` and this branch.
- **`CHECK_HOOKS_DIR` from a copy of `9b7b017`:**
  - pre-fix hook: 20 `flip` rows and 5 TRADE rows red with got=BLOCK;
  - round-2 library: its 15 permitted rows red with got=ALLOW.
- **Registry:** 183 rows, 181 caught; text checks 328.
- **Suite:** ALL CHECKS PASSED at `9b7b017`.
- `mutate-hooks.sh -v` on the 28 #202 rows at `9b7b017`: all 28 caught, 29
  runs including the baseline.

## Mistakes and dead ends

- **The brute-force search for a backtick-in-quotes witness found none.**
  The assistant did not delete the rule on that evidence. It worked out why
  the search could not find one (its tail was fixed, and the witness needs
  the next line to open with a quote), and built that row by hand.
- **A heredoc of Python** carrying the new comments was refused by
  `no-pr-decisions.sh`, because its text named `gh api` beside a wrapper. The
  assistant moved each edit into a script file.
- **An append of this entry's round-2 predecessor** was refused by
  `append-only-docs.sh`, because a `sed -i` on a scratch file shared the
  command with the entry's path. The assistant split the two.

## Open

- **#351**: the delimiter defect in the default mode, now with a carriage
  return row.
- **#311**: the staged script.
- **#289**: `cs_normalise`'s own opener.
- **GH-182.2's in-place edit**: Bertan's decision.


# 2026-09-29 17:48 +0300 · dev-agent-202 — #202, round 4 of the review of PR #314

Branch `worktree-issue-202-quoted-heredoc-body`, from `9571f1f` to `372e16d`
and this entry. The assistant merged `origin/dev-05` at `0e4a0f4` (#342),
which merged cleanly. rev-agent-202 reviewed `9571f1f`
(https://github.com/bgunyel/clause-and-effect/pull/314#issuecomment-5892296388)
and raised no new code gate.

## What the review found, and what was done

- **Gate 8: three pieces of prose were wider than the code.**
  - The `lex()` header listed a carriage return as doubt, but only the opener
    span is tested for one. The header now says why a carriage return matters
    only there.
  - "Alphabet" and "what is not named is not trusted" claimed an allow-list
    over characters. The code is a list of the constructs that change bash's
    quote or comment state, and it passes every other character. It is now
    THE DOUBT LIST, and says that. The review's 20 probes are cited as the
    measurement behind "every other character passes".
  - Removing the command-started-here test depends on `consumer()` requiring
    `pre` to begin with `cat`. That dependency is now recorded where
    `consumer()` is defined.
- **Q9: the second-opener test.** The review found no row the test alone
  refuses, and offered to delete it or keep it as a refusal cost. The
  assistant disagreed and showed why:
  - Without the test, the second body is read as command text.
  - A lone `"` in that body puts the state inside a string where bash is at
    the top.
  - A later `echo "; cat > /tmp/g <<'Z'` then drops a merge that bash runs,
    checked by execution.

  The test is pinned as a BLOCK row and registered as a mutation.

## Measured

- **Registry:** 184 rows, 182 caught; text checks 328. Derived on the tree
  merged with `0e4a0f4`, which added none.
- **Harness:** `mutate-hooks.sh -v heredoc-second-opener-ignored` at
  `372e16d` caught it. Its baseline, the whole suite unmutated, was green.

## Mistakes and dead ends

- **The assistant again put an apostrophe inside the awk program** ("the
  opener's line"), in the new comment on `consumer()`. The library failed to
  load, and the scratch check that scans that program for apostrophes caught
  it before anything was run against the hooks.
- **The assistant pushed `372e16d` before its new pins had a green run.** The
  harness baseline ran the suite afterwards, and it was green.

## Open

- **#351**, worked in its own worktree
  (`worktree-issue-351-delimiter-quote-removal`, `32ba0da`, suite green). It
  has no pull request yet. It and this branch both change the opener block of
  `cs_drop_heredocs`, and whichever lands second unifies the two delimiter
  grammars.
- **#311 and #289:** #351 closes #289's own table rows but not its class.
- **GH-182.2's in-place edit:** Bertan's decision.

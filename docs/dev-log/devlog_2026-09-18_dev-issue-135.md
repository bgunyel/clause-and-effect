# 2026-09-18 15:54 +03 — #135: a quoted group or subcommand word is the word it spells

Branch `worktree-issue-135-quoted-subcommand`, cut from `origin/dev-05` at 33f7129.
It is one commit ahead of that root and none behind. The assistant worked the
session unattended, from Bertan's `/implement` of #135.

## Two argument readers compared raw tokens, and bash compares none

`cs_git_args` and `cs_gh_args` in `lib/command-scan.sh` compared the subcommand
as a raw token. Before gh or git sees a word, bash has already removed its
quotes. So `git "push" origin main`, `gh pr 'merge' 5` and `gh \pr merge 5` each
ran the command they spell, and no rule in any hook fired on them.

Every ALLOW row in the issue's table was reproduced at 33f7129 in all three
spellings, by feeding each hook on stdin. #152 is the open pull request for
#117, which rewrites the same library. It was measured before the base was
chosen, and it changes none of these rows: it answers the command word, and this
issue is about the next two words. So the branch was cut from `origin/dev-05`
and not from #152.

The fix is one awk function, `word()`, written into both readers for the
reason the library gives (an awk program cannot source another):

- It reads a word as bash does. A blank inside quotes does not end the word.
- The quotes and escapes are removed from what the word spells.
- The spelled word is compared as a string. `cs_gh_args` used to match the word
  as a regular expression and cut it by length.

Two consequences followed without a separate rule:

- A quote inside the word, `git pu"sh"`, is read. The issue had left that shape
  to triage.
- An option value holding a blank no longer hides the subcommand. Before, `-c
  "user.name=a b"` ended at the blank, so `b"` read as the subcommand. The
  assistant found this while measuring; the issue does not name it.

The readers still return the rest of the command as written, with its quotes.
`base_args`, `check_push` and the carve-out each keep their own argued quoting
trade.

## Reaching the verb made a quoted option reachable

Once `git "commit"` read as a commit, `git "-C" /x commit` became a commit, and
none of the hooks' raw-text `-C`/`-c` patterns could see a quoted `-C`. On
dev-05 that command was permitted too, because the commit was never found. The
fix would have left it permitted for a new reason, so it was closed in the
same change:

- The two unanchored patterns in `no-git-push.sh` now read the command with
  quote and backslash characters removed. So does the stale-branch carve-out's.
- `no-commit-to-main.sh` reads `bare_words`, a word-aware flattening.

**An error, and who found it.** The assistant's first version used `tr -d` in
`no-commit-to-main.sh` as well. Its comment claimed that, because the pattern is
anchored at the head, a split value "can only add another option for it to
skip". The spec reviewer the assistant spawned measured that claim false:

- In `git -c "user.name=a b" -C <main repo> commit -m x`, the stray `b` is not
  an option, so the anchored pattern stopped before the `-C`.
- The command was ALLOW, on exactly the shape the fix was for.

`bare_words` writes a quoted blank as `_`, so a quoted value stays one word.
That shape is now pinned in both quote styles and with an escaped blank, beside
a permitting control.

## Replaying transcript commands found one false refusal in the new reader

The assistant replayed 4,513 distinct Bash commands from this machine's Claude
transcripts. Only commands naming git or gh and carrying a quote or backslash
were selected, since only those can move. Each went through four hooks, at
dev-05 and on the branch.

**A measurement error, and its correction.** The first run was invalid. The
dev-05 copy had been archived from inside `.claude/hooks`, so the archive held
an empty directory, and every "before" verdict was exit 127. That was caught
only because the counts were implausible. The harness now reports any exit
status other than 0 or 2 on either side. The rerun reported none.

The valid rerun changed three verdicts:

- **One became a permit.** A `gh release "view" v1` inside a heredoc body that
  the fallback splits had been refused as a release write. It now reads as the
  read it is. That is intended.
- **Two became refusals, both from one flaw in `word()`.** `cs_split` cuts an
  unbalanced line plainly. That produced the fragment `gh pr create'`, whose
  quote closes a span opened a line earlier. `word()` read it as `create`. The
  reader now treats a word whose quote never closes as spelling nothing.

## The release allowlist's third trade is withdrawn

`no-pr-decisions.sh` argued that `gh release "view" v1` should be refused, since
unquoting a word to grant a read is the generous reading `gh_pr_web` declines.
Bertan's review of PR #140 had already called that a gap, recorded in GH-135's
note: bash hands gh the word `view`, so no argument is being unquoted.

The trade is now two parts, and the check that pinned the refusal is a flip to
ALLOW. What `gh_pr_web` declines is unquoting an argument, and `base_args`
still declines it.

## Evidence

- **The new section, `issue #135`, in `check-hooks.sh`:** 57 checks were red at
  33f7129 before the library was touched, measured. Later rows were added for
  the option tests and the unclosed quote.
- **The families:** #106's 50 GH-135 gap variants went red and their six
  departure rows were deleted. The families now report 148 gaps and 1,709
  variants.
- **The full suite:** `ALL CHECKS PASSED` after the review fixes. `GH-135` moved
  from `gap → #135` to `active`.
- **Five mutation-registry rows:**
  - `subcommand-quotes-not-removed`
  - `unclosed-quote-spells-a-word`
  - `option-test-reads-raw-quotes`
  - `quoted-blank-splits-the-word`
  - `carve-out-reads-raw-quotes`

  All five were run in one harness invocation after the review fixes, and all
  five are `caught`. The unmutated baseline was green over 177 requirements, and
  `.claude/hooks/` was byte-identical afterwards.
- **`make test`:** 595 passed, 5 xfailed. One failure predates this branch,
  `test_installed_packages_match_uv_lock` (venv drift from `uv.lock`); no Python
  was touched.

## Open

- **#165:** a quoted verb inside a shell wrapper,
  `bash -c 'git "push" origin main'`, passes the three git hooks. Their wrapper
  patterns match on raw text. Measured ALLOW here and at #152's head.
- **#166:** ANSI-C and locale quoting, `git $'push' origin main`, are not read
  as quoting by any word reader.
- **#135's own triage question stays open:** should the pull-request verb test
  fail closed on a verb it does not recognise? `gh pr "frobnicate" 5` is still
  ALLOW. `gh pr "merge" 5` is refused because the verb is now read, not because
  unknown verbs are refused.
- **Merge order with #152:** the #106 departure table and `inv_quote_at`'s
  comment are touched by both branches. They should merge cleanly, but the gap
  counts will need re-reading after whichever lands second.

# 2026-09-25 14:09 +03 — #207: the check-hooks summary bounded in bytes on every path

Branch `worktree-issue-207-summary-bound`, cut from `origin/dev-05` at `2c65f4d`
with `git worktree add --no-track`. Commits `f6ded53` and `4a9128d`, plus this
entry: three ahead of `origin/dev-05` once it is committed.

## Scope

Items 1, 2 and 4 of #207, as scoped by the triage comment's Agent Brief. Item 3,
which lines count as a failing row's detail, is #224 and was not touched. The
code is `.github/scripts/check_hooks_ci.py` and its tests; nothing under
`.claude/hooks/` changed.

## What changed

- **Item 1, the tail path.** A non-zero exit with no failing row showed the log's
  last 40 lines, bounded in lines only. The last lines are now cut from their
  start to `SUMMARY_BLOCK_BYTES` (512 KiB, the old row budget renamed), keeping
  the end where a guard's message is. The partial line is found by bisection and
  cut at a character boundary, and the summary says how many bytes were cut.
- **Item 2, the rows loop.** A row that does not fit is now skipped, and the
  loop carries on. It used to `break`.
- **Found while fixing item 1: the fence was not counted.** The budget counted
  the rows' text, but `fenced` writes a fence one backtick longer than the
  longest run inside, twice. Measured on the unfixed script: two rows totalling
  500 KiB of text, one of them 300 KiB of backticks, gave a 1,126,724-byte
  summary. Both paths now count the block the way `fenced` writes it
  (`fenced_size`).
- **Item 4.** Added tests for `is_boundary` with `---` and with `===`, and for a
  merge commit whose message has a line starting `parent `.

## Decisions and dead ends

- **Truncate vs. skip.** The assistant first chose a per-row cap: every row cut
  to 16 KiB with a marker line, so a runaway row's name stays on the page.
  That meant rewriting two existing tests that pin an oversized row as left out
  whole (`..._bounds_the_summary_by_bytes_...` and
  `..._says_every_row_was_left_out_...`). The harness's auto-mode classifier
  refused the rewrite as test removal. The assistant then took the brief's
  other option, skip, which keeps both tests true unchanged. The trade is written
  in the loop's comment and the commit message: a skipped row's name is not on
  the page, only in the count and the uploaded log. The per-row cap is left
  open. It changes what a shown row is, and that is Bertan's call.
- **The two-byte case did not kill `decode(..., "replace")`.** The first
  encoding case used `é`. The mutant survived: a U+FFFD costs as many bytes as
  the character it stands for or more, so the bisection lands on the same piece.
  A three-byte case (`€`) survived for the same reason. Only a four-byte
  character leaves three bytes of room where one U+FFFD fits. The assistant
  replaced the `€` case with `😀`, which kills it.
- **An edit broke the script mid-review, and the tests caught it.** A
  review-driven rename of `data` to `encoded` in `clip_from_end` missed one
  `len(data)`. Four tests went red with a `NameError`, and the assistant fixed
  it before committing `4a9128d`.
- **Environment.** `make test` first failed in `test_environment_sync.py`: the
  worktree's fresh `.venv` lacked the `migrations` group (alembic, mako). The
  same test passed in the main checkout. `uv sync --all-groups` in the worktree
  fixed it. This was not a code change.

## Evidence

- `make test` in the worktree, after `f6ded53` and again after `4a9128d`: 656
  passed, 5 xfailed, of which `tests/test_check_hooks_ci.py` is 26.
- Red before the fix: against the unfixed script, the five new report tests
  failed (the skip test, the fence test, and three tail cases; the four-byte
  case was added later). The heading tests and the `verify_merge` test pass on
  unmutated code by design; they are mutation guards.
- Mutation check: 12 mutants against the script, backed up to the scratchpad
  and restored from that copy after each, with sha256 compared. All 12 were
  caught after `4a9128d`. The list, and which test kills each, is in the PR body.
- Review: a two-axis review (Standards, Spec) ran as sub-agents. No hard
  violation and no missing requirement. Its wording findings are fixed in
  `4a9128d`. The duplicated size accounting in the rows loop and
  `clip_from_end` was left, because the two control flows differ (skip vs. cut).
- The Spec reviewer measured the issue's own scenarios on `f6ded53` (not
  re-measured after `4a9128d`): item 1 gives a 524,748-byte summary that says
  1,572,892 bytes were cut; item 2 gives a 373-byte summary showing both small
  rows and "1 more failing row(s)".

## Open

- Whether to cap each failing row, so a skipped row's name stays on the page.
- #224, item 3: how a failing row's detail lines are chosen. The new `===`/`---`
  test pins today's boundary rule, which #224 will have to keep or update.

# 2026-09-25 14:24 +03 — #226 review round 1

Branch `worktree-issue-207-summary-bound`. Round 1 of rev-agent-207's review
was posted on PR #226 at head `150151a`. The answer is commit `86e8ff1`, and
with this entry the branch is five ahead of `origin/dev-05` (`2c65f4d`).

## G1: carried state never driven past its first element

- **Accepted.** Every tail case had one line over the budget, and every fence
  case one backtick row, so the carried `size` and `longest` were never read.
  Two tail cases were added to `test_report_cuts_a_log_tail_over_budget_and_says_so`
  (the parameter `last_line` was renamed `tail`, since these are several
  lines): `size-carried` (three 200 KiB lines, each fitting alone, two
  together) and `fence-carried` (a plain line cut by the fence of a backtick
  line kept after it). One rows test was added,
  `test_report_counts_a_shown_rows_fence_against_the_rows_after_it`: a shown
  backtick row's fence keeps a later plain row out, and a nine-byte row after
  that still fits. Every expected block and cut is hand-derived. The two tail
  blocks come to exactly 524,288 bytes fenced, so they also pin
  `fenced_size` at the budget's edge.
- **Mutation check**, script backed up to the scratchpad and restored from
  that copy after each mutant, sha256 compared: the reviewer's A3, M4 and M5
  are now caught (2, 1 and 1 failing tests), and A1, A2 and A4–A6 are still
  caught.
- **Sweep beyond the diff.** The same class was looked for in every
  accumulator in the script, not only the diff's: `parse_log`'s `passed`,
  `failing` and a row's `block`, `verify_merge`'s `parents`, and `report`'s
  `problems`. The first four are driven past one element by existing tests
  (mutants S5 and S6 caught). `problems`, from #199, was not. The only
  two-problem case asserted its first message, and nothing asserted the
  summary's bold lines at all. Four mutants survived: the verdict check as
  `elif` (S1), no problem in the summary (S2), and only the first problem in
  the summary (S3) or in the log (S4). The assistant made
  `test_report_refuses_a_pass_the_log_does_not_support` assert the exact list
  of `::error::` lines and of bold summary lines. S2–S4 were then caught; S1
  still survived, because its `elif` hangs off `results == 0` and no case had
  zero rows and no verdict together. An empty-log case was added, which kills
  it. All 14 mutants are caught.

## G2: the claim wider than the code

- **Accepted, and the prose fix was chosen over the per-row cap.** A row that
  fits and nearly fills the budget still hides the rows after it, as the
  reviewer measured. The per-row cap now has its own issue, #227, which also
  covers naming a skipped row. Doing it here would enlarge a PR whose
  acceptance criteria are already met, and what a shown row is remains
  Bertan's call. The rows-loop comment now says what the code does and names
  #227.
- **Sweep.** The assistant grepped the script, the test module and this log for
  `runaway` and `hide`. It found one more over-claim that the review's sweep
  missed: `test_report_skips_a_row_over_budget_and_shows_the_rows_after_it`'s
  docstring said "One runaway row must not hide the rows behind it". Fixed to
  "A row over the budget". Commit `f6ded53`'s subject carries the same words.
  It is left, because rewriting a pushed commit needs a forced push. The PR
  title is to be reworded when this round is pushed.

## Evidence

- `make test` in the worktree: 660 passed, 5 xfailed (656 before, plus two
  tail cases, one rows test and one empty-log case).
- Re-measured with the test harness's arguments (`--seconds 204
  --tested-commit abc123`), under `python3.12`: the issue's item 1 gives a
  524,753-byte summary cutting 1,572,892 bytes; item 2 gives 378 bytes and
  "1 more failing row(s)"; the fence case gives 1,126,724 bytes at `2c65f4d`.
  The earlier 524,748 and 373 are 5 bytes lower because the Spec reviewer
  passed other arguments; the behaviour is the same.

## Open

- #227 (per-row cap, naming a skipped row) and #228 (five narrow defects), as
  filed by the reviewer.

# 2026-09-25 14:34 +03 — #226 review round 2

Branch `worktree-issue-207-summary-bound`. Round 2 of rev-agent-207's review
was posted at head `8ec2d97`. The answer is commit `a488cf9`, and with this
entry the branch is seven ahead of `origin/dev-05` (`2c65f4d`).

## G3: a tail claimed on a path that writes none

- **Accepted.** The module docstring paragraph the assistant added in
  `f6ded53` said that without a failing row the log's last `TAIL_LINES` lines
  are shown. The code writes the tail only under `elif exit_status != 0`. The
  sentence now names the non-zero exit, and says that an exit 0 shows no tail
  even when the log does not support it, pointing to #228 (item 8), where the
  reviewer filed that behaviour. The behaviour is #199's and is unchanged.
- **Sweep.** The assistant grepped `failing row`, `no-failing` and `tail`
  over the script, the test module and this log's entries. It found one more
  instance, which the reviewer's sweep had not listed:
  `test_report_cuts_a_log_tail_over_budget_and_says_so`'s docstring opened
  "The no-failing-row path shows the log's last lines". It now says "A
  non-zero exit with no failing row". The `TAIL_LINES` comment, the PR body's
  item 1 and this log's first entry already said "non-zero exit". No other
  claim in the diff was found wider than the code.
- Round 1's miss and this one share a cause. The assistant's round-1 sweep
  searched for the words of the flagged sentence (`runaway`, `hide`), not for
  every claim about which path does what. So a claim worded differently was
  not reached.

## Evidence

- Prose only. `tests/test_check_hooks_ci.py`: 30 passed. No figure in the PR
  body changes. The reviewer's rerun at `8ec2d97` caught 24 of 24 of their
  mutants.

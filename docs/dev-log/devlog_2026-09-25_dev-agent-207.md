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

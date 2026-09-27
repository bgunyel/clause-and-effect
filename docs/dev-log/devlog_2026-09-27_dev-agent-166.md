# 2026-09-27 · dev-agent-166 — #166: ANSI-C and locale quoting read as quoting, by one word reader

Branch `worktree-issue-166-ansi-c-quoting`, cut with `--no-track` from
`origin/dev-05` at a109c2f; one commit on top of it, carrying this entry.
`origin/dev-05` moved to 03e5843 while the work was open, a change to
`docs/dev-log/README.md` alone, which this branch does not touch; the branch was
not merged forward.

## What was asked

#166 and its triage brief: `$'git' push origin main`, `$"gh" pr merge 5`,
`$'sudo' git push origin main`, `$'timeout' 30 git push --all origin` and
`$'bash' -c "git push origin main"` were permitted by all four boundary hooks,
because no word reader in `lib/command-scan.sh` knew that the `$` of bash's
ANSI-C and locale quoting goes with its quote. The brief's design: lift the
reader `quoted_base_flag` already carried in `no-pr-decisions.sh` into the
library and have every consumer call it. The group and the verb (`git $'push'`,
`gh $'pr'`) are #135's and stay permitted.

## What was built

- `CS_WORD_AWK` in `lib/command-scan.sh`: a string of awk functions, interpolated
  in front of each program that reads a word, as `CS_GH_AWK` already was. Its
  interface is a stream -- `wd_start`, then `wd_next` reporting each unit as
  `blank`, `open`, `shut`, `cut` or `text` -- because the three consumers ask
  different things of one walk. The escape decoding is `quoted_base_flag`'s,
  moved rather than rewritten, and its rationale moved with it.
- `cw_reduce` (command word and prefix words), `ghreduce` (a gh option) and
  `quoted_base_flag` (a base flag) all read through it. `CS_WORD_SPELLING`, the
  raw-text run in front of a wrapper word, admits `[$]?` before a quote.
- An empty `CS_WORD_AWK` withdraws `cs_split`, `cs_gh_args` and `cs_gh_opaque`
  and names itself, since a program calling a missing function does not compile
  and would fail open.
- The option position was taken into scope by the assistant: #118's issue file
  had pinned `gh pr $'-t' view merge 5` and two siblings as permitted and
  assigned them to #166, and routing `ghreduce` through the reader closed them
  at no extra cost. Those three rows are flips in `checks/GH-118.sh` now.
- `checks/GH-166.sh` with the requirement GH-166, declared there and generated
  into `requirements/GH-166.md` -- the brief asked for an append to
  `requirements.md`, which predates #205's convention. Three invariance
  transformations: `word-ansi`, `word-locale`, `pre-sudo-ansi`, with two GH-171
  gap rows for `append-only-docs.sh`, whose own verb grep reduces neither.

## Evidence, measured

- Red first: before any fix the suite failed 106 checks, every one a GH-166 row
  or a new family variant, and nothing else.
- `quoted_base_flag` old against new, differential fuzz over 16,000 generated
  argument lists (seeds 1 and 7): zero differences in output or status. That is
  the "lift, not a change of answer" criterion, measured.
- `cs_split` old against new over 3,000 commands with no `$'`/`$"`: 41
  differences, every one a double-quoted `\g`-shape, the documented change to
  bash's rule. The assistant's first version of that harness reported zero
  because `paste -d '\035'` reads `\0` as its empty delimiter; the zero was
  suspicious, a direct probe disproved it, and the comparison was rewritten.
- Cost: `cs_split` on 16 KB of one quoted word 23 ms before, 29 ms after; the
  #96 scaling inputs 172/635 ms before and 231/972 ms after, ratio 4.2 where the
  check fails at 8. Recorded beside `cw_reduce`.
- `check-hooks.sh` green over 6,412 results before the mutation run.
- `mutate-hooks.sh`, one selection: the eleven GH-139 rows (three moved to the
  library and naming GH-166 as well, two re-anchored in `quoted_base_flag`, six
  unchanged), five new GH-166 rows, and the two #118 rows that go through
  `ghreduce`. Baseline plus eighteen, every row `caught`, `.claude/hooks/`
  byte-identical after (c8dcc3d4…). No whole-registry pass was run.

## Mistakes and dead ends

- The assistant wrote apostrophes into a comment inside `cs_split`'s
  single-quoted awk program, which would have ended the shell word. Caught by
  reading before any run; the comment was rewritten without them.
- The assistant edited `requirements/GH-118.md`'s note to say #166 closed its
  rows. The suite's #200 check holds legacy entries to their checksums as
  immutable; the edit was reverted and the correction lives in GH-166's note.
- The library header first said this was the "seventh" time one question had
  two answers, a count the assistant had not derived. Replaced with the two
  prior cases it names.
- Review (two sub-agents, Standards and Spec) found: a wrong tag (FR-14 on a
  create naming a base), three verdicts that moved BLOCK to ALLOW with no row
  (`"\g"it push`, `git\ push`, `gh pr \\-t view merge 5` -- each correct by
  bash, none runs the guarded command), a refusing-direction cost of the widened
  anchor (`"$'bash'" -c …`), comments claiming more than the code, and static
  checks whose labels overstated them. All fixed; the four trades are flips.
- The spec review also found a pre-existing permitting defect, identical at
  a109c2f: `cs_split`'s separator walk pairs `$'…'` as `'…'`, so
  `echo $'\'' ; git push origin main #'` is permitted by every hook. Filed as
  #252 rather than widened into this change.

## Open

- #252, above.
- #135 is to call `CS_WORD_AWK` for the group and the verb rather than grow its
  own dequoting; until it lands `git $'push' origin main` is still permitted.
- `$'\x62ash' -c …` is permitted: the wrapper anchor reads raw text and cannot
  decode. Pinned as a boundary, the same gap as `b"a"sh`.
- No pull request was opened; that is Bertan's call after review.

## Addendum, after the commit

The first `git commit` was refused by `no-work-on-stale-branch.sh`:
`origin/dev-05` had moved again, to 2303e9b (a `CLAUDE.md` rule that an agent
commits and pushes before waiting on a long run). The branch was fast-forwarded
onto it with the work staged -- neither upstream commit touches this change's
files -- and committed as 8782f85, one commit ahead of `origin/dev-05`. The
mutation selection above ran on the tree before that fast-forward; the suite
was re-run on 8782f85 itself, which carries the new `CLAUDE.md` line the suite
reads: ALL CHECKS PASSED, 6,414 results.

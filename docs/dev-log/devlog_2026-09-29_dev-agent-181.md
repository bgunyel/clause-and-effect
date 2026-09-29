# 2026-09-29 · dev-agent-181 — #181: no function in a boundary hook calls a function that writes

**Written 2026-09-29 08:36 +0300.** Branch `worktree-issue-181-writer-callers`,
cut with `--no-track` from `origin/dev-05` at `abffdbf`. The work is `fd59bfe`
(the derivation), `a927bd9` (it moved into its one caller's issue file),
`6eb4c9d` (the answers to the first review), and `54391a2`, a merge of
`origin/dev-05` at `f539d9a`, plus this entry. When this entry was written,
before it was committed, the branch was 4 commits ahead of `origin/dev-05` and
0 behind it. No pull request was open when it was written.

## What was built

`fn_calls` counts call sites by token, so an indirect call was invisible to it.
With `wrap() { check_push "$1" "$2"; }` called twice, ten writes sat on twenty
paths while `arms` read 19 and `fn_calls ... check_push` read 1. The function
table did go red, but it showed `wrap silent`. The assistant reproduced #181's
triage measurement on a copy of `no-git-push.sh` before building anything.

- **GH-181.1.** `writer_callers`, in `checks/GH-181.sh`, prints each
  `<caller> <writer>` pair where a function body names a function that
  `fn_writes` says writes. It is pinned empty for both boundary hooks. It
  reads a definition line's remainder as body, so a one-line wrapper is seen.
  It does not read a comment standing alone after the opening brace, so the
  repository's `name() {  # name <args>` usage line is not a self-call.
- **GH-181.2.** `odd_names` refuses a definition whose name is not an
  identifier. It was added in answer to review.
- **The trades.** Each is a fixture asserting today's reading and is listed
  in GH-181.1's note: a call through a variable, through an `eval` that
  builds the name, or inside a heredoc body; a writer in a sourced file; and
  three misattributions that show as a misleading red.

The assistant first put `writer_callers` in `checks/library.sh`. The suite's
placement check refused it, because it had one caller, so it moved to the
issue file in `a927bd9`. That was the only red in the first full run.

## What the review found

A two-axis review (standards and spec) ran as two subagents over the first two
commits.

- **The worst finding was a hole wider than #181 itself.** Bash accepts
  `wrap-it() { ... }`. `fn_writes`, `nested_defs` and `writer_callers` all
  read a name as an identifier, so a hyphenated wrapper around `check_push`
  produced no pair and no table row, and `fn_calls` stayed at 1. Nothing went
  red. The assistant confirmed this on a copy (`arms` 19, table unchanged,
  `writer_callers` empty). Following the stance `nested_defs` already takes,
  the assistant refused the shape rather than widening three patterns.
- **The two copies of the open/close rules were held equal by nothing.** A
  check now asks `writer_callers` to carry each of `fn_writes`'s six regex
  literals. Dropping one was measured to be named.
- **The reads-through question had become a copy.** It is now the library's
  `reads_only_through`, with GH-182.sh and GH-181.sh as its two callers.

Also found while building, and filed rather than fixed: **#338**. `fn_writes`
calls a writer silent when its write stands on a definition line that is not
a `;` `}` one-liner. `writer_callers` reads the writer set from `fn_writes`, so
it inherits that. It shows as a misleading red and not a green, because `arms`
moves.

## Measurements

The runs were made on this machine at load 22–25, with other sessions' suites
running beside them.

- **Full suite, first commit:** 1 FAIL, the library placement above.
- **Full suite, after the move:** 8046 ok, 0 FAIL.
- **Full suite, on the merged final tree at `54391a2`:** 8055 ok, 0 FAIL.
- **With `writer_callers` stubbed to print nothing,** in a detached scratch
  copy at `fd59bfe`: the eight fixture rows that expect a pair went red. So
  did the placement row, since the library copy was the one stubbed. A
  `cs_normalise` timing row also failed, at 1064 ms against a 1000 ms bound,
  with two suites running. That row read 762 ms in the concurrent run of the
  real tree.
- **`mutate-hooks.sh -v`** at `a927bd9`: both first rows caught (GH-109.2 and
  GH-181.1 red). At `54391a2`, all three #181 rows were caught:
  `a-writer-wrapped-and-called-twice` and `a-writer-wrapped-on-one-line`
  (GH-109.2, GH-181.1), and `a-writer-wrapped-under-a-name-with-a-hyphen`
  (GH-181.2 alone). `.claude/hooks/` was byte-identical after each run.
- **`--list`:** 155 rows, 153 real mutations, 2 self-tests.

## Left open

- **#338**, above.
- **GH-109.2's note** still says in the present tense that a heredoc body is
  read as code (#182), though #182 has closed. That wording predates this
  lane. The assistant left it, because the note is a legacy entry and each
  edit to one moves its `SPLIT_MOVED` token.

---

# 2026-09-29 · dev-agent-181 — merge of dev-05 at 0e4a0f4

17:14 +03.

Branch `worktree-issue-181-writer-callers`, from `c6f9cbb` to `dce04d8`.
It merges `origin/dev-05` at `0e4a0f4`, which brought in #329, #350 and #342.
With this entry's commit the branch is 7 commits ahead of `origin/dev-05`
and 0 behind. rev-agent-181 asked for the merge because the branch no longer merged clean.

- **Conflicts.** There were two, and both were additive. In
  `mutate-hooks.sh` the header paragraph for #181's rows sat beside #156's.
  In `requirements.md` the #338 cite entry sat beside #233, #329, #337, #350,
  #352, #254 and #342. The assistant kept both sides of each.
- **A literal that merged clean and wrong.** Each side added three registry
  rows. Each moved the row literal in `checks/unsplit.sh` from 152 to 155, and
  the caught literal from 150 to 153. Git saw one agreed change, so there was
  no conflict marker. The assistant re-derived both from the merged registry:
  158 rows, 156 declared caught, 1 did-not-apply and 1 survived. The
  assistant's first suite run started before the literals were fixed, and it
  stopped that run unread.
- **`--list` on the merged tree** (measured): 158 rows, 156 real mutations
  against 17 files, 80 requirement IDs, 2 self-tests, and 258 active
  requirements.
- **Full suite on `dce04d8`** (measured): 8183 ok, 0 FAIL, ALL CHECKS PASSED.
- **Not re-run:** `mutate-hooks.sh -v` over the three #181 rows. The earlier
  entry's figures for them are for `54391a2` and say nothing about this merge.

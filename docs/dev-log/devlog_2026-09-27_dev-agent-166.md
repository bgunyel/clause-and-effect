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


# 2026-09-28 03:40 +03 · dev-agent-166 — #166 through five review rounds of PR #260: one word reader becomes one answer to where a word ends

Branch `worktree-issue-166-ansi-c-quoting`, pull request **#260** into `dev-05`.
Commits 8782f85..46d13b1, and this entry's commit on top: 17 commits
ahead of `origin/dev-05` at cd67c8e, two of them merges of `origin/dev-05`
(acbb150 at abba1d0, 251895d at cd67c8e). The dev-agent-166 session wrote the
code; rev-agent-166 reviewed it in five rounds, posted as comments on #260.

**Corrections to the entry above, which is history and stays as written.** It
says "one commit on top of it" and "No pull request was opened". The branch
carried two commits when that entry was committed (8782f85, and 03c6f66, which
added its addendum), and the pull request is #260, opened after it. The
addendum's "one commit ahead" was true before 03c6f66 and false after it.

## What changed, round by round

Every verdict below was taken by feeding a command to a hook on stdin; nothing
was executed. Figures are measured unless marked otherwise.

**Round 1 (c77b671).** rev-agent-166 found that the tail offer behind a prefix
word still stopped at a token opening with `"` or `'` and not at `$'` or `$"`,
so round 0 had made `sudo echo $'git push origin main'` refused where
`'…'` was permitted, and refused `sudo -u root $'git' push origin main` only by
accident: the natural fix, the dollar added to the test, survived a whole green
run while reopening that push. The assistant replaced the first-character test
with `quotedtext`, which asked the reader whether a token left a quote open.
That also closed #266 (`sudo -u root "git" push origin main`, permitted since
before #166), declared as GH-266 in its own issue file. The "one reader" claim
in GH-166 and the library header was narrowed to the consumers that actually
call it, with the private sites named: #265, #267, #191, #225, #252.

**Round 2 (ceccd7b..11e7640).** rev-agent-166 measured that `quotedtext` was
wrong in both directions. **It was the assistant's regression in the
permitting direction**: `env $'A=b c' git push origin main`, its locale and
GIT_SSH_COMMAND spellings, and `env $'A=b c' gh pr merge 5` were refused at
abba1d0 and permitted at acbb150. The assistant had also pinned a GH-266
boundary on an unmeasured premise, that no option value holds a blank;
rev-agent-166 measured six ordinary shapes that do (`sudo -D "/srv/my repo"`,
`sudo -p "Password: "`, `flock -w 5 "/tmp/my lock"`, …). The class, named by
rev-agent-166: a question about one blank-cut token whose answer is a property
of the line. rev-agent-166 proposed reading the tail with the reader; the
assistant measured that the tail alone would regress
`sudo --prompt="a b" git push origin main` (BLOCK at base) and widened it:
`word_end` reads a word to the first blank outside every quote, and the
assignment strip, the prefix word and its options and operand, the head word
and the tail offer all step by it (GH-166.1). That closed #273's strip and env
parts; the families then forced its third, the wrapper anchor's assignment
branch, and #273 was closed here too. **The assistant's first version of that
regex dropped the old class's lone-quote match**, so it was not a superset;
the assistant caught it while widening the token, before review.
The same token fix closed a sibling in the anchor's token count. Filed by the
assistant: #284 (`cs_git_args` cuts `git -c "user.name=a b"` at its blank).

The suite's harness rate went stale on this PR's growth. The assistant
re-measured it under peer load (1118, 908, 1272 s at load averages 33.7, 14.2,
17.8) and carried 1272. **That exposed two copies of one fact the assistant
had not moved with it**: the date inside `--list`'s printf, and `RUN_BOUND=600`,
commented as several times the rate, which killed the mutation baseline at
exit 124 and reported the tree red with nothing wrong in it. Both now follow
the constant. The assistant also stopped one suite run to edit files it was
reading, rather than edit under it.

**Round 3 (251895d..bfee0ad).** rev-agent-166: the backslash, the fifth quoting
form, was right in the strip and unpinned, so a fast path that forgot it
survived green (u4); and the wrapper anchor's token and option skip did not
read it or a spaced option. The assistant took option (1): `CS_WRAP_TOKEN`
gained `\\.`, the option skip reuses the token, and `A=b\ c …` rows were
pinned both ways. Three restated facts the assistant had made stale were
corrected: GH-215's date enumeration, the date written twice, and the tail
bound's "longest real leftover". `printhead` and `wordend` now share
`word_end(s, i)`. The rate was re-taken on a quiet machine: 430, 388, 325 s at
loads 3.9, 8.7, 3.7. **Two of the assistant's probes for the exact
`MEASURED_AT_RESULTS` failed first** -- run from the wrong directory, then
from a copy with no repository around it -- before a clone with the baseline
set to 1 printed the figure the check reads: 6,892.

**Round 4 (c191573, 51b985b).** rev-agent-166: the rewritten bound comment was
still false, and the assistant's own pinned "word past the bound" row was the
counterexample (one `sudo` leaving four words); the anchor comment's "one
difference" missed the unjoined anchor input (#309). And two families the
assistant added, `pre-sudo-spaced` and `pre-sudo-escaped`, could not fail: one
spaced `-D` value spent one tail word too many and left the seed reachable.
They now stand in front of `-u root`. The assistant tried rev-agent-166's
optional `tok_end` unification; the suite went red because `tokend` is copied
into three awk programs held identical, and the assistant withdrew it.

**Round 5 (46d13b1).** Four stale restated facts: the bound's "about an hour"
(3x out at 430 s), #309's "two" hooks (three; the assistant measured the third
on a rebuilt stale-branch fixture, `bash \`+newline+`-c 'git commit -m x'`
permitted on a stale branch), #304's ledger entry missing its option-count
shape, and the rate comment carrying the quiet figure under a rule it broke.
Two conditions now carry two figures, 430 s quiet and 1272 s under load, and
`RUN_BOUND` follows the loaded one.

## Suite and mutation runs (a run after #215 is recorded here, not in the harness)

| head | suite | mutation selection |
|---|---|---|
| c77b671 | ALL CHECKS PASSED, 6,589 | baseline + 3 `quotedtext` rows: all caught, tree byte-identical |
| acbb150 (merge at abba1d0) | ALL CHECKS PASSED, 6,599 | -- |
| c663a2f | -- | baseline killed at `RUN_BOUND` 600 s, exit 124 (above) |
| 11e7640 | ALL CHECKS PASSED, 6,794 | baseline + 8 rows (word ends, bound, wrapper token): all caught, byte-identical |
| bfee0ad | ALL CHECKS PASSED, 6,907 | baseline + 7 rows (backslash fast path, head word, anchor token, escape, option skip, assignment value): all caught, byte-identical |
| c191573 | 1 FAIL (`tokend` copies drifted) | four direct suite runs on mutated copies: `pre-sudo-spaced` red on 22 and 4 rows, `pre-sudo-escaped` on 22, 22, 4, 4 |
| 51b985b | ALL CHECKS PASSED, 6,909 | -- |
| 46d13b1 | ALL CHECKS PASSED, 6,909 | -- |

No whole-registry pass has been run. The registry holds 130 rows (114 at the
base); `--list` derives every count. Timing checks failed twice under load
averages near 40 from peer sessions; the assistant timed `cs_split` at base and
head on the same lines, interleaved, and head was no slower (16 KB: 15-24 ms
against 18-21; 512 KB: 358-367 ms against 461-476).

## Filed along the way

By rev-agent-166: #265, #266 (closed here), #267, #273 (closed here), #303,
#304, #309. By the assistant: #252 (round 0) and #284. The assistant added four
refusing-only sites to #267 and linked #166, #266 and #273 to #260 with
`addCloseIssueReferences`, since a keyword does not link on a dev-NN base.

## Open

- #303, a command substitution in double quotes as a value, is the most
  ordinary shape left open; rev-agent-166 recommends it next.
- #309, and behind it the case #309 argues: `CS_WRAPPER_RE` is a second
  tokeniser that each round of this PR had to port a rule into by hand.
- #304, #284, #194, #265, #267, #252, #135 stand as cited.
- The quiet rate figure was taken once; re-take both conditions when the suite
  grows past the staleness margin.

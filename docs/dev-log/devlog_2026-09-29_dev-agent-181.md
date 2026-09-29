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

---

# 2026-09-29 · dev-agent-181 — rev-agent-181's round 1

18:11 +03.

Branch `worktree-issue-181-writer-callers`, from `6c0c008` to `cd12f48`, plus
this entry's commit. With it the branch is 9 commits ahead of `origin/dev-05`
(`0e4a0f4`) and 0 behind. rev-agent-181 reviewed `c6f9cbb` and posted five
findings. Two were gating, and each came with a mutant that survived green.

## What was wrong, and whose

- **F1, the assistant's.** GH-181.2 was written to close the hyphen hole the
  first review found. It asked only for a definition's *name*, and it was
  anchored the same way as every derivation it defended: start of line, and a
  literal `()`. So `: ; wrap() {…}`, an indented `function wrap {…}` (on one
  line and on three), and `wrap ( ) {` each wrapped `check_push`. Each was
  called twice, and the whole suite stayed at 8056 ok, 0 FAIL. The guard
  written to close the class showed the class itself. The assistant also
  cited `nested_defs` as holding "column 1". It holds that only for the
  parenthesis form, and GH-109.2's note repeated the claim.
- **F2, the assistant's.** When the assistant moved `reads_only_through` into
  the library for two callers, every question the suite put to it had the
  answer true. Stubbing it to `return 0` left the suite green. The helper
  match also had no left boundary: `raw_hook_text "$1"` satisfied `hook_text`.
- F3 (`odd_names` not enrolled in GH-182.3's list), F4 (the #181 cite said
  one entry, and a stray line break in GH-109.2's note) and F5 (a usage
  comment after `()` with its brace below read as a self-call, a false red)
  were smaller.

## What changed

- **`odd_defs` replaces `odd_names`.** It does not recognise definitions and
  then judge them. It looks for the grammar's two signatures anywhere in a
  line: a `(`, blanks and `)`, and the word `function`. It reports every line
  that carries one, unless the line is the one shape all readers read: a
  column-1 identifier, `()`, and a brace on that line or on the next line that
  is not blank. It takes that shape off the front before looking, so a
  definition nested on another definition's line is still reported. A `(` `)`
  after `$`, `<`, `>` or `=` is excused, since it is never a definition. The
  `function` keyword is refused outright in shell. Neither hook uses it, and
  `fn_calls`' definition exclusion does not read `function name {`.
- **The awk text is pinned, not excused.** rev-agent-181 suggested an
  exception for awk. The assistant pinned instead: `no-pr-decisions.sh`'s
  seven awk lines (four `function` lines and three `name()` calls) are the
  guard's expected output, written as a literal. Which side of a quote a line
  stands on cannot be read from its text. The cost is in the refusing
  direction: an edit to those awk lines turns the row red.
- **`reads_only_through`** matches and removes the helper call bounded on the
  left. It is now asked eight readers: seven it must refuse, and one reader
  asked for a helper it does not call.
- The three new registry rows: `a-writer-wrapped-after-a-separator`,
  `-by-an-indented-keyword` and `-with-a-blank-in-its-parentheses`. The
  literals move to 161 and 159.
- A new trade is recorded from the sibling sweep of F1 at call sites. A call
  whose name is spelled across quotes, `spe""aks "$1"`, is not a token. The
  same is true for `fn_calls` at the top level.

## Measurements

The load was high, with other sessions' suites running. All figures below
were measured.

- **Full suite at `cd12f48`:** 8189 ok, 0 FAIL.
- **`--list`:** 161 rows, 159 real mutations against 17 files, 80
  requirement IDs, 2 self-tests, and 258 active requirements.
- **`mutate-hooks.sh -v` over the three new rows:** each was caught with
  GH-181.2 red alone, and `.claude/hooks/` was byte-identical after.
- **Hand mutations**, each in a `git clone --shared` detached at `cd12f48`,
  against a baseline clone at 8189 ok, 0 FAIL:
  - `reads_only_through` with `return 0`: 2 FAIL.
  - The old unbounded removal added back: 1 FAIL (`r181_suffix_beside`).
  - `odd_defs` reading `cat "$1"`: 4 FAIL.
  - F5's comment strip reverted: 1 FAIL.
- **A dead end, the assistant's.** The first hand-mutation run copied
  `.claude/hooks` alone and ran the copy's `check-hooks.sh`. The suite
  resolves its fixtures against the repository around it, so every run
  stopped at 1411 checks. The assistant discarded those runs and used clones.

## Left open

- The three rows from before this round were last run at `54391a2`.
- GH-109.2's note still says a heredoc body is read as code (#182), as the
  earlier entry recorded.

---

# 2026-09-29 · dev-agent-181 — merge of dev-05 at 1486270

20:51 +03.

Branch `worktree-issue-181-writer-callers`, from `e8927f5` to `eed393b`.
With this entry's commit the branch is 11 commits ahead of `origin/dev-05`
(`1486270`, which brought in #314) and 0 behind. rev-agent-181 asked for the
merge.

- **One conflict:** the two registry literals in `checks/unsplit.sh`. This
  time each side had moved them to a different value, so git marked them. The
  assistant re-derived both from the merged registry, not from either side:
  190 rows, 188 declared caught, 1 did-not-apply and 1 survived.
  rev-agent-181's count of 190 agreed.
- **SPLIT_MOVED:** each token was checked against `cksum` of its entry file.
  None had moved.
- **`odd_defs`' pinned awk literal:** run over the merged `no-pr-decisions.sh`
  under the merged `lib/command-scan.sh`, it prints the same seven lines.
- **`--list`** (measured): 190 rows, 188 real mutations against 17 files, 82
  requirement IDs, 2 self-tests, and 261 active requirements.
- **Full suite on `eed393b`** (measured): 8330 ok, 0 FAIL.
- **Not re-run:** `mutate-hooks.sh -v` and the hand mutations. Their figures
  are for `cd12f48`.

---

# 2026-09-29 · dev-agent-181 — rev-agent-181's rounds 2 to 4

23:44 +03.

Branch `worktree-issue-181-writer-callers`, from `31845a2` to `a7ec6cb`, plus
this entry's commit. With it the branch is 15 commits ahead of
`origin/dev-05` (`1486270`) and 0 behind. Every round in this entry was
about one function, `reads_only_through`, the guard that holds the suite's
own readers to reading their file only through `hook_text`.

## What was wrong, and whose

- **Round 2 (R2-F1, gating), the assistant's.** Round 1's fix bounded the
  helper's name on the left by `[^A-Za-z0-9_]`. That closed `raw_hook_text`
  and left `raw-hook_text "$1"` and `./hook_text "$1"` passing. The assistant
  had written a guard against one spelling of a class, and it showed the
  class. The assistant then saw that no left bound refuses
  `cat hook_text "$1"`, since a blank stands in front of the name there. So
  `c59f6ad` read the call where a command starts instead. R2-F2 (two
  restated counts, and a shape stated more narrowly than the check) and R2-F3
  (the `<`/`>` excusal undriven) were smaller.
- **Round 3, nothing gating.** rev-agent-181 measured more bypasses and false
  reds, and filed #362: a text rule is the wrong tool for this question, and
  a behavioural probe is proposed instead. The assistant closed one of the
  bypasses, the array `f=(hook_text "$1")`, and recorded the rest as trades.
  It also took item 5: it trimmed the lists to what `declare -f` prints and
  gave each member a reader that passes through it.
- **Round 4, the assistant's.** The trim removed `;` on the claim that
  `declare -f` never puts one before a call. It does inside `$(…)`. `>(` was
  named in the prose but missing from the list. Both were false reds, and
  both are back with a reader each. rev-agent-181's row 3 turned out to be
  the assistant's too: the removal took each call out with the character
  after it, and that character can be where the next call starts.

## Mistakes in the measuring, both the assistant's

- The first R1 mutation run judged nothing (0 ok, 0 FAIL). The assistant's
  mutation table dropped the replacement's closing quote, so the library did
  not load. The assistant moved the table into a Python file of raw strings
  and reran R1, which went red.
- The first suite run of the round-4 fix went red, 1 FAIL. The suite's own
  scanner closes a function only at a column-1 `}`, and two multi-line
  one-liner fixtures had none. The assistant rewrote them with the brace on
  its own line.

## Measurements

All figures below were measured with bash 5.2.21, at high load with other
sessions' suites running.

- **Full suite:**
  - `c59f6ad`: 8333 ok, 0 FAIL.
  - `8626587`: 8333 ok, 0 FAIL.
  - `a7ec6cb`: 8333 ok, 0 FAIL.
- **Hand mutations**, each in a `git clone --shared` detached at the commit
  named:
  - At `c59f6ad`, against a baseline of 8333 ok, 0 FAIL:
    - round 1's left bound put back: 2 FAIL;
    - the `${!` clause dropped: 1 FAIL;
    - the `BASH_ARGV` clause dropped: 1 FAIL;
    - the right bound dropped: 1 FAIL;
    - `odd_defs` without `<` `>`: 1 FAIL.
  - At `8626587`:
    - the left list without `|`: 1 FAIL;
    - the right list without `;`: 2 FAIL;
    - `(` accepted after `=`: 1 FAIL.
  - At `a7ec6cb`: the left list without `;`, 1 FAIL; without
    `>`, 1 FAIL; the removal eating the next call's start, 1 FAIL.
- **Member by member**, sourcing the fixtures and a copy of the loop with
  the lists parametrised: every member of both lists, and keeping the
  character after a call, is the only way at least one true-case reader
  passes.
- **Registry:** unchanged, at 190 rows and 188 caught. Its rows cannot reach
  `checks/`, so the hand mutations are this guard's evidence.

## Left open

- #362, for the probe that replaces the text rule, and the trades asserted
  until then: refused are an assignment prefix, `if`, `!`, `time`,
  `command`, `coproc`, backticks and any `${!…}`; passed are `$_`, `eval`,
  `perl`, and a call spelled as a line of a multi-line string.
- #338's three shapes and #361's three hand copies, as before.

---

# 2026-09-30 · dev-agent-181 — rev-agent-181's round 5

00:04 +03.

Branch `worktree-issue-181-writer-callers`, from `c23c09c` to `762e867`, plus
this entry's commit. With it the branch is 17 commits ahead of
`origin/dev-05` (`1486270`) and 0 behind.

rev-agent-181's final sweep found no new class. It did find two things the
assistant had written:

- **The `;` and `>` members added in round 4 opened a bypass.** An escaped
  separator, `a=$(echo \; hook_text "$1")`, passes, and rev-agent-181 measured
  it printing the file at runtime. So round 5 asked for no further change to
  the rule in this pull request, and the assistant made none. The bypass is
  #362's.
- **The previous entry's "Left open" read as the whole set.** It named the
  trades as lists, and rev-agent-181 measured members missing from both.

What changed, all in prose and fixtures:

- The trades are now stated as two classes, citing #362:
  - **Refused (false reds):** a call after any keyword or prefix word the
    lists do not name, a call inside backticks, and any `${!...}`.
  - **Passed (bypasses):** any text the rule reads as a command start that
    bash reads as data, and any name the text does not spell.

  The rows in #181's issue file are examples of each class, not its extent.
- `r181_in_a_multiline_string` did not read the file at runtime. The
  assistant now cuts the string down to the file's name and `cat`s it.
  Measured with `hook_text` stubbed: it prints the file.
- The one-line pair `x=$(hook_text "$1"; hook_text "$1")` now pins the kept
  `;`. With the old removal it is refused, which was measured.
- Two prose corrections. The library names `>(...)` beside `$(...)` and
  `<(...)`, which `declare -f` was measured to print on one line. The
  true-cases paragraph no longer says the calls ending at `)` follow a
  substitution's `(`.

## Measurements

- **Full suite on `762e867`:** 8333 ok, 0 FAIL (measured).

## Left open, as classes

- **#362:** the text rule, and both of its trade classes above.
- **#338:** a write or a body line that `fn_writes` attributes to no
  function, three shapes recorded so far.
- **#361:** three hand copies of the attribution rules, held by one presence
  check.

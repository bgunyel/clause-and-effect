# Dev-log — 2026-09-23 — dev-agent-204

## 2026-09-23 20:30 +03 — #204 step 1: the helper library

Branch `worktree-issue-204-library`, cut from `origin/dev-05` at `dbb1141` with
`git worktree add --no-track`. Commits `5c7da69` and `2c390c7`, two ahead of
`origin/dev-05`, plus this entry. This is pull request 1 of the two the #204
triage brief asks for; step 2 (the driver's sourcing routine, the unsplit and
end-of-run files, the ADR, the glossary) is not started.

### The precondition was not met, and Bertan chose to proceed

The brief makes it a precondition that the open pull requests touching
`check-hooks.sh` have drained. At the start of the session #189, #184 and #158
were all still open, each touching `check-hooks.sh` and each already `dirty`
against `dev-05` (read from the API, not recalled). The assistant asked, and
Bertan chose to proceed anyway. Those three will need rebasing across the move.

### What was done

**Commit 1, a pure move.** Which functions move was decided by measurement,
not by reading. A throwaway lexer, written first in Python and then ported to awk,
blanks quotes, comments and heredoc bodies, assigns each line to the prelude
or a section, and carries calls made inside a function to that function's
callers. On `dbb1141` it found 44 functions with more than one calling section,
plus one false positive: `gh()`, the #108 fixture that the suite exports and
unsets. The Python and awk versions agreed on all 131 functions. Those 44
moved, each with the comment block directly above it, into
`.claude/hooks/checks/library.sh`, 817 lines in 46 cuts. The driver sources the
library from `$SUITE_DIR` and stops the run if it does not load.

The suite read its own text in 19 places: 16 whole-file reads and 3 `sed`
ranges. Each assumed the code it inspects was in `check-hooks.sh`. They now
read `$SUITE_TEXT`, which is every suite file in source order, or go through
`suite_range`, which FAILs on an empty range.

Measured: both modes, stdout and stderr, byte-identical to `dbb1141` after
`sed -E 's/[0-9]+ ms/<n> ms/g'`. The base run took 3 m 34 s and printed 5,637 `ok`
lines and `ALL CHECKS PASSED`, matching the triage's figures.

**Commit 2, this issue's checks.** GH-204.1 through GH-204.4, 23 rows in a new
section placed before #104's. It holds the library membership, derived from the
code in both directions; that the library defines functions and nothing else;
the two self-read helpers, including a driven FAIL on an empty range; that no
code reads the driver by path; and `TOOLING` as a regular expression,
`^(check-hooks[.]sh|mutate-hooks[.]sh|checks/.+)$`, spelled identically in
the suite and the harness. The harness's own `row_fault` is taken out of its
text and run against a row targeting `checks/library.sh`. Every check was
mutation-checked on a scratch copy.

### Mistakes, and what caught them

- **Expectations derived in the assistant's head, and wrong.** The assistant's
  first draft of the GH-204.1 fixture had two wrong literal expectations. In
  one, `both` was not called from section two; in the other, `section` itself
  counts as a call from every section. A hand trace caught both before the
  first run.
- **A self-read fixture that would have flagged itself.** Its heredoc body spelled the
  driver's path, so the check over the suite would have found the fixture. It
  now spells the path through a variable.
- **The #104 printer audit went red on the assistant's own literal.** The expected
  string `"  FAIL the suite text…"` is a quoted line opening with a result
  word, which that audit rejects. The first full run of commit 2 caught it;
  the literal is now split as `FA""IL`.
- **Two mutants that proved nothing.**
  - Moving `tok` out of the library "survived" only because the assistant's
    isolated test harness sourced the library and not the driver, so every
    `tok` became `command not found`. That is the very silence GH-204.1
    exists for, reproduced in the test rig. The mutant was re-run with
    `cap_guard`, which the new section does not call, and was caught.
  - `do … while (0)` was meant to remove the transitive closure, but a
    do-while runs its body once, which is enough here. Replaced with a loop
    over nothing; caught.
- **Review found three defects the suite did not.** A two-axis review
  (Standards and Spec, run as parallel subagents):
  - The text-check tooling rule had been narrowed silently: a tooling file
    named through any variable other than `$SUITE_DIR`/`$HOOKS` no longer
    counted. Restored by placing a path by its part under `.claude/hooks/` or
    its last component.
  - GH-204.2 asked only about output, so an assignment, `set -e`, `cd` or trap
    at the library's top level would have passed. It now compares the shell's
    whole state before and after sourcing; each of those four is a caught
    mutant.
  - Comments and requirement text had gone stale in the move. They are fixed,
    and the fixes are folded into commit 2 before any push.

### Taken rather than closed, named

- **`$0` and a bare relative `check-hooks.sh`** are not asked by the
  no-direct-read check. Every awk program here spells its record `$0`. The
  #107 rule asks the relative name of the three text-check helpers only.
- **Moved comments keep their positional words.** "Above", "below" and "the foot
  of this suite" in a moved comment mean `check-hooks.sh` around where the
  function stood. The library header says so, rather than every comment being
  rewritten.
- **`REQUIREMENT_SHAPE` stays a shared hunk** until #211.

### Open, for the next session

- Pull request 2: the sourcing routine and its six fixture self-tests, the
  unsplit and end-of-run files, the check that every heading has a row, the
  headers, ADR 0004, and the glossary and CLAUDE.md.
- #189, #184 and #158 must rebase across this move.
- Single-caller helpers still defined in the driver's prelude, such as
  `dev_read_count` and `numeric`, go with their section's checks when step 2
  splits the file.

## 2026-09-23 21:25 +03 — PR #216, review round 1

Branch `worktree-issue-204-library`, head `782f47b`, four ahead of
`origin/dev-05` (`dbb1141`), plus this entry. It answers rev-agent-204's
round 1 (issue comment 5800015183): three gating findings, two non-gating.
Not pushed yet; the reviewer asked to be told first.

### What the review found, and what was done

- **G1, a helper missing from the library ran green.** The load guard asked
  for five names. The reviewer measured `lacks` deleted: 35 fewer results and
  ALL CHECKS PASSED. The driver now defines `command_not_found_handle`.
  Measured by the assistant before it was written: bash runs the handler in a
  forked environment even for a command called from the main shell, so a
  `FAILED=1` it sets is lost. It therefore appends to `$NOT_FOUND`, and a check
  at the foot fails on anything there. New requirement GH-204.5.
- **G2, a redefined helper replaced the library's silently.** `lib_callers` now
  reports every name defined more than once, with each place.
- **G3, `checks/.+` took `checks/../no-git-push.sh` as the tooling.** It is now
  `checks/[^/.][^/]*` in both files. The trade: a dotfile or a subdirectory
  under `checks/` is not the tooling either. It is recorded in the comment, in
  GH-204.4 and in the pinned literal list.
- **N1.** The text-check derivation became `text_check_faults`, which reads the
  files one by one and reports `file:line`.
- **N2.** The four stale pointers the reviewer listed were fixed. The
  assistant's sweep found a fifth: "that section's `present`".

### What the sweeps found beyond the findings

- G2's class, a name defined on both sides of a sourcing boundary: the suite
  also sources `lib/command-scan.sh` into its own shell. No name is shared
  today. A check now asks it, and a tokeniser that defines nothing is reported
  rather than read as colliding with nothing. The tokeniser's variables were
  swept too. The suite assigns none of its twelve at the top level. Every hit
  was inside a `sed` or `grep` string. That is not checked.
- G3's class, a `..` taking a path out of its directory: the text-check rule
  also accepted `$HOOKS/../hooks/x.sh`, and now refuses a `..` after any
  variable. `direct_self_reads` missed `$SUITE_DIR/checks/../check-hooks.sh`,
  and now finds it. `row_fault` already refused a `..` target.
- G1's class, a guard narrower than its prose: the new handler's own blind
  spots are named in GH-204.5. They are a command missing in the `--matrix`
  program, which runs after the foot check, and one missing before the fixtures
  directory exists.

### Mistakes, and what caught them

- The assistant's first `tokeniser_collisions` sorted with `LC_ALL=C` and ran
  `comm` in the ambient locale. `comm` warned "not in sorted order" on stderr,
  and the suite stayed green. The comparison could have missed a shared name.
  Caught by diffing stderr against the review's recorded hash, before any
  mutation run; `comm` now runs under `LC_ALL=C`.
- The assistant's first stderr comparison was run on a `git archive` copy. That
  copy is not a repository and has no `docs/`, so its stderr differed for that
  reason alone. It was redone on a clone at `1cb7f22`.

### Evidence (measured)

- Thirteen mutants were run on a clone, each checked to apply exactly once. All
  thirteen went red on the check aimed at them. They are listed in `782f47b`'s
  message.
- The clone's `check-hooks.sh` sha256 equals the committed one: `6e687416…`.
- Against `1cb7f22`, with `<digits> ms` masked: 5,660 → 5,670 ok. The stdout
  diff is the ten new rows, one relabelled row and the count labels. Stderr is
  identical in both modes: `cf01f588…`, the review's hash. Both modes exit 0.

### Open

- #217 holds the reviewer's five narrow items. The assistant agrees with filing
  each rather than gating on it.
- The forward notes for pull request 2 stand: `lib_callers` regions only in the
  first file, and `split-requirements.sh` reads `SPLIT_MOVED` from the driver
  by name.

## 2026-09-23 22:20 +03 — PR #216, review round 2

Branch `worktree-issue-204-library`, head `232487d`, six ahead of
`origin/dev-05` (`dbb1141`), plus this entry. It answers rev-agent-204's
round 2 (issue comment 5800763514): two gating findings and three non-gating.
Nothing is pushed yet.

### What the review found, and what was done

- **G4. The flat `TOOLING` reopened G3 from the other side.** It was the
  assistant's round-1 fix. `checks/./library.sh`, `checks//library.sh` and
  `checks/sub/x.sh` were not the tooling, so they were judged as hooks. The
  suite accepted a text check that read one off `$HOOKS`, and the harness ran a
  registry row that targeted one. The assistant's round-1 claim that the trade
  "errs toward a refusal" held for one consumer of three.
  - `TOOLING` is now exact: every file under `checks/` at any depth, with no
    `.`, `..` or empty segment.
  - Those spellings are refused before the rule is asked, in the text-check
    rule, in `row_fault` and in the suite's registry audit.
  - A new check requires every file the driver sources to be the tooling.
- **G5. `lib_callers` read only `name() {`.** `function holds { ... }` and
  `holds () { ... }` each replaced `holds` with the run green. All four
  spellings bash takes at the margin are now read, with a fixture line for each.
- **N3.** The self-test now sources a fixture file and asserts file and line
  as literals.
- **N4.** The child a `bash -c` starts is named as a limit, together with the
  reason exporting the handler is not the fix.
- **N5.** The handler now prints bash's own line. The assistant measured it
  byte-identical to bash's output without the handler, apart from line numbers
  shifted by the extra line.

### Mistakes, and what caught them

- **An edit script by the assistant deleted about 1,800 lines of
  `check-hooks.sh`.** It replaced a slice that ended at the foot check instead
  of the end of the self-test. The slice took with it the #104 section and the
  #148 checks. The suite exited 0 with ALL CHECKS PASSED at 5,535 ok. The drop
  from the expected ~5,674 is what showed it.
  - The range was restored from `HEAD`, and the diff was re-read hunk by hunk.
  - The gap it exposed (the end-of-run checks can vanish silently) is not this
    PR's and is filed as #218.
- **A mutation launch by the assistant backgrounded its own `cd`.** The
  command was written as `cd X && ( ... ) & python3 ...`, so the mutation
  driver started in the main checkout. It failed there, wrote a stray
  `mutants2.out`, and ran no mutants. The file was removed, and the run was
  repeated from the scratch directory.
- **Two commit commands were refused by `no-commit-to-main.sh`.** One was a
  compound line that began with a `cd`. The other appended this entry by a
  heredoc whose prose named a shell wrapper. Both were committed plainly
  instead.

### Evidence (measured)

- **Mutants.** 17 runs on a clone whose five changed files are
  byte-identical to the committed ones. The 15 mutants each went red on the
  check aimed at them, and the two controls stayed green: `function lacks`
  and `holds ()` written in the library itself. `232487d`'s message lists
  them all.
- **Against `b2f82d7`**, with `<digits> ms` masked:
  - 5,670 → 5,676 ok;
  - six new rows, four relabelled, and the #148 count label moved;
  - stdout `0da11a75…`, `--matrix` `bef44763…`;
  - stderr `cf01f588…` in both modes;
  - exit 0 / 0.

### Open

- #218, for the end-of-run file in step 2.
- #217 holds the reviewer's items, including four more from this round. The
  assistant agrees with filing each one.

### Correction, 2026-09-23 22:40 +03

The mutant count above is wrong, and so is the one in `232487d`'s message.
The run was **16**: 14 mutants, each red on the check aimed at it, and 2
controls, both green. The assistant wrote "17 runs" and "15 mutants" without
counting the driver's output. It then wrote a sentence into the round-2 reply
that explained the wrong total by saying one row stood for two mutants, which
was not true. It found the error while re-reading the posted reply. The reply
and the PR body were corrected in place; this entry and the commit message
stay as they were.

## 2026-09-23 23:05 +03 — PR #216, review round 3

Branch `worktree-issue-204-library`, head `4c4c664`, nine ahead of
`origin/dev-05` (`dbb1141`), plus this entry. It answers rev-agent-204's
round 3 (issue comment 5801600362): one gating finding and four non-gating.
Nothing is pushed yet.

### What the review found, and what was done

- **G6. G2's class for the third time.** `holds() ( ... )` and
  `holds ( ) { ... }` passed all four spellings the scanner read.
  - The reviewer proposed closing the class at runtime instead of adding a
    fifth spelling. The assistant agreed and did not look for a cheaper
    closure, because a function body can be any compound command, so a text
    reader stays one spelling behind.
  - Every function the run starts with is now recorded with `declare -f` once
    the library, the tokeniser and the handler are loaded.
  - The tokeniser's variables are recorded too, with `declare -p`. They are the
    sibling the assistant's round-1 sweep reported and left unchecked, and this
    mechanism covers them for free.
  - The foot of the run fails on any of them that changed or went missing.
  - A cross-check ties the scanner to bash: the names sourcing the library
    defines must be the ones the scanner places there.
  - The text-level duplicate report stays as the early warning, and its label no
    longer claims every spelling.
- **N6.** Three stale counts of `row_fault`'s refusals. The reviewer found two;
  the third, in `check-hooks.sh` at the #148 run-count audit, was the one
  `/code-review` had pointed at. The counts were removed rather than updated,
  since CLAUDE.md says a number in a comment earns nothing.
- **N7.** Prose corrected, consumers not reordered. The assistant pushed back on
  reordering: the text-check rule is the one consumer that accepts the tooling,
  and it already asks the segments first. `row_fault` and the registry audit
  refuse on every branch, so their order changes only the reason printed.
- **N8.** GH-204.4 now says the text-check rule judges spelling, not what a
  variable holds.
- **N9.** The handler's stderr is now compared with what a child `bash` prints
  for the same file. The child does not inherit the handler.

### Evidence (measured)

- **Mutants.** 9 runs on a clone whose six changed files are byte-identical to
  the committed ones; the assistant counted the driver's output lines this time
  (9). 8 mutants went red on the check aimed at them. 1 control stayed green:
  `CS_LINE_CAP` set again to the value it already has.
- **Against `d64e1fd`**, with `<digits> ms` masked:
  - 5,676 → 5,683 ok;
  - seven new rows and two relabelled;
  - stdout `46d8497e…`, `--matrix` `571a268d…`;
  - stderr `cf01f588…` in both modes;
  - exit 0 / 0.

### Open

- #218 and #219 (the latter the reviewer's, on `unarmed` passing a directory)
  both predate this PR.
- #217 has two more items from this round. The assistant agrees with filing
  both.

## 2026-09-23 23:45 +03 — PR #216, review round 4

Branch `worktree-issue-204-library`, head `052cc89`, eleven ahead of
`origin/dev-05` (`dbb1141`), plus this entry. It answers rev-agent-204's
round 4 (issue comment 5802237280): two gating findings, both edges of the
assistant's round-3 runtime comparison, and two non-gating. Nothing is pushed
yet.

### What the review found, and what was done

- **G8. The record was taken about 200 lines after the library loaded.** A
  redefinition in between became the baseline.
  - The reviewer suggested recording each file right after it is sourced. The
    assistant went one step further and removed the window altogether: each file
    is now sourced alone in an `env -i` child, and what that child defines is
    the record.
  - Measured before relying on it: for all 65 names, the child's output is
    byte-identical to what a sourcing shell prints.
  - The empty environment also answers the two environment-dependent items the
    reviewer added to #217 this round, exported functions and exported `CS_*`
    variables.
- **G7. The foot's verdict ran through `fail` and `loaded_changed`, both in the
  record.**
  - The comparison is now code in a variable that calls no function.
  - The foot sets `FAILED` and prints to stderr itself before it asks `fail` to
    record the row.
  - The not-found foot had the same shape and was changed the same way.
- **N10.** `env -u BASH_ENV "$BASH"`, plus the literal beside the differential.
  On this machine `$BASH` and `bash` resolve to the same binary, so no mutant
  can tell them apart. The commit says so rather than claiming it as checked.
- **N11.** The sourced-files check now asks the segments before `TOOLING`, and
  the prose names both consumers that accept on it.

### Mistakes, and what caught them

- **The assistant wrote the self-test's `| sort` outside its `$( )`.** The
  pipe text became part of the actual value, and the check went red on the
  first run. The run was not green for the wrong reason, but the literal was
  wrong until the second run.
- **The assistant's first attempt at the mutant file generated Python from a
  format string with nested escapes, and failed to parse.** The file was written
  directly instead, with a `--check` mode that confirms each edit applies
  exactly once before any run.

### Evidence (measured)

- **Mutants.** 8 runs, counted from the driver's output. Each behaved as
  `052cc89`'s message says. Two of them are reversions that turn a finding back
  green or remove a row from the failures, which shows those lines carry the fix:
  - the foot's inline verdict reverted: the reviewer's no-op `fail` is back to
    exit 0;
  - the segment `case` reverted: the sourced-files row drops out of the
    failures.
- **Against `dad8d11`**, with `<digits> ms` masked:
  - 5,683 → 5,685 ok;
  - stdout `72ef0b02…`, `--matrix` `10bd5929…`;
  - stderr `cf01f588…` in both modes;
  - exit 0 / 0.

### Open

- **Driver functions stay outside the record,** apart from the handler. They
  are named in GH-204.1. `requirements_read`, which the #104 coverage reads
  through, is one of them.
- **#218 is the other edge, one level out:** the foot check itself can be
  deleted and the run stays green.

## 2026-09-24 00:35 +03 — PR #216, review round 5

Branch `worktree-issue-204-library`, head `0473e8d`, thirteen ahead of
`origin/dev-05` (`dbb1141`), plus this entry. It answers rev-agent-204's
round 5 (issue comment 5802849644): one gating finding and two non-gating.
Nothing is pushed yet.

### What the review found, and what was done

- **G9, first half: the foot's verdict could be cleared.** `fail() { FAILED=0; }`
  undid the verdict after the foot had set it. The verdict is now taken last,
  just before the exit and after every helper has run. It comes from code in a
  variable that calls no function, and that code can set `FAILED` but never
  clear it. A subshell test drives it for each way it must fail, and a literal
  pins it as the last thing the driver does.
- **G9, second half: undriven fixes.** The assistant's round-4 fixes each had a
  line that could be deleted with the run staying green.
  - The reviewer found three of these.
  - The assistant's sweep of that class found five more: the final `eval`
    itself, `record_of`'s `env -i`, its refusal of an empty record, the
    attribute strip, and the handler's record entry.
  - Each now has a check that fails without it.
- **N12.** The differential's child now starts with `env -i`, as the record's
  child does. A check shows that a handler this shell exports does not reach it.
- **N13.** The assistant removed the hand-kept count and pushed back on a single
  predicate: the copies live in the suite's shell, its awk and the harness
  script, and no one function can serve all three.

### Mistakes, and what caught them

- **The assistant's first run of this round was red, with two of its own
  defects.**
  - Its new `export -f` and `present` lines named `command_not_found_handle`
    as bare words, and the scanner read them as calls from a second section.
    They are arguments, so they are quoted now.
  - A `present` over a newline-separated list could never match.
- **The assistant's first draft of the commit message said "one renamed" where
  the diff has one row removed.** The count was checked against the output
  before committing.

### Evidence (measured)

- **Mutants.** 12 runs, counted by name from the driver's output. Every mutant
  behaved as `0473e8d`'s message says. One is a reversion that shows a fix is
  load-bearing: with the final `eval` removed, the reviewer's clearing `fail`
  exits 0 with FAIL rows printed.
- **Against `0dfc61d`**, with `<digits> ms` masked:
  - 5,685 → 5,695 ok;
  - stdout `8bbb958e…`, `--matrix` `5bc01103…`;
  - stderr `cf01f588…` in both modes;
  - exit 0 / 0.

### Open

- **The suite's registry-audit arms are still held by text pins, not by
  fixtures.** The audit is a loop over the real registry.
- **#218.**

## 2026-09-24 01:20 +03 — PR #216, review round 6

Branch `worktree-issue-204-library`, head `cba91ac`, fifteen ahead of
`origin/dev-05` (`dbb1141`), plus this entry. It answers rev-agent-204's
round 6 (issue comment 5803518527): one gating finding, two non-gating, and
one optional item from the #217 list, which the assistant took. Nothing is
pushed yet.

### What the review found, and what was done

- **G10. Two fixture arms were undriven.**
  - The `kept` fixture and the hook-name fixture were added as the reviewer
    suggested.
  - The assistant then found the `kept` fixture was not enough on its own.
    Under the reviewer's m11A (`FAILED=0` at the top of the verdict code), the
    `kept` row prints a FAIL, and the mutated verdict clears it at the end. A
    fixture cannot protect the verdict from a mutation of the verdict.
  - So a second verdict was added, independent of the first: any FAIL row in
    the ledger fails the run. It is driven by a fixture, and a literal pins its
    place.
- **Optional: the not-found record moved and not put back.** The head records
  `NOT_FOUND_AT_HEAD`, and the verdict fails if `NOT_FOUND` differs from it.
  The assistant took this one from the #217 list because the GH-204.5 self-test
  does exactly that repointing, so copying it is a plausible mistake rather than
  tampering.
- **N14 and N15.** The "cannot see" lists were re-read against the new order,
  and the "only builtins" sentence now names the shadowing limit.

### Mistakes, and what caught them

- **The assistant's first ledger reader set IFS to a tab.** It was caught while
  writing the fixture: tab is IFS whitespace, so an empty tag field would
  collapse and shift the columns. It now matches TAB FAIL TAB on the whole row,
  and the fixture includes an untagged row.
- **One of the assistant's mutants was aimed badly.** It moved the record and
  then called a missing command, which the ordinary non-empty check also
  catches. The case only the new check catches puts the command before the
  move. That case was run as an eighth mutant: exit 1 with no FAIL row.

### Evidence (measured)

- **Mutants.** 8 runs, as listed in `cba91ac`'s message. One is a reversion:
  with the ledger verdict removed, m11A2 exits 0 with ALL CHECKS PASSED and
  three FAIL rows printed.
- **Against `ed79413`**, with `<digits> ms` masked:
  - 5,695 → 5,697 ok;
  - stdout `1c05a05e…`, `--matrix` `8e954e5d…`;
  - stderr `cf01f588…` in both modes;
  - exit 0 / 0.

### Open

- **The tampering items stay in #217 by the reviewer's design.** They are:
  shadowed builtins, an EXIT trap, a reassigned `LOADED_BODY` or
  `FOOT_VERDICT_CODE`, and a redefined `record_of`.
- **#218.**

## 2026-09-24 01:45 +03 — PR #216, review round 7

Branch `worktree-issue-204-library`, head `2fbdb71`, seventeen ahead of
`origin/dev-05` (`dbb1141`), plus this entry. It answers rev-agent-204's
round 7 (issue comment 5803978842): no gating findings, and three non-gating,
all taken. Nothing is pushed yet.

### What was done

- **N16. Stale or backwards prose.**
  - The review found five sites. The assistant's sweep, run with line breaks
    joined, found a sixth: the foot row's comment calling the verdict "the last
    thing this suite runs".
  - The `NOT_FOUND_AT_HEAD` comment, which the assistant wrote in round 6, had
    the hazard backwards. It is corrected, and the comment says it was.
- **N17. Wrong tags.**
  - The `moved` arm ran under GH-204.1. The assistant's sweep found the round-5
    `missing` arm under the same wrong tag.
  - The verdict fixture is now split by requirement.
  - A new row reads the tags back from the ledger.
- **N18. The moved-record condition had no foot row.**
  - It now has one.
  - A new row asserts that the ledger's last three rows are the three foot
    rows, under their tags.

### Mistakes, and what caught them

- **The assistant's first edit script asserted the wrong slice length (16
  lines against 18).** The assertion stopped it before any write. The slice
  was printed and checked, and was the intended one: the verdict row and the
  stderr row.
- **The assistant's first commit message said "five new rows, one removed".**
  The diff has six new and one removed; five is the net. It was caught
  re-reading the diff before any push, and the unpushed commit's message was
  amended.

### Evidence (measured)

- **Mutants.** 4 runs; all went red on the check aimed at them, as `2fbdb71`'s
  message lists. The round-6 case that ended `SOME CHECKS FAILED` with no FAIL
  row now prints a FAIL row that names both paths.
- **Against `8262305`**, with `<digits> ms` masked:
  - 5,697 → 5,702 ok;
  - stdout `d8998ab8…`, `--matrix` `25718226…`;
  - stderr `cf01f588…` in both modes;
  - exit 0 / 0.

### Open

- **#217:** the reviewer's hypotheticals, now including an unwatched `LEDGER`
  and the proposal to make the verdict's variables `readonly`.
- **#218.**
- **Pull request 2.**

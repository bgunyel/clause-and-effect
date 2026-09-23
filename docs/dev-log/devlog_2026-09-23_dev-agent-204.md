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

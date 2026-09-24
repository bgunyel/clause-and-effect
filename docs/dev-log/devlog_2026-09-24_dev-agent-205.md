# 2026-09-24 18:55 +03 — #205: new `GH-` entries declared at the check site, their files generated

Branch `worktree-issue-205-generated-entries`, cut from `origin/dev-05` at
`cf73c82` with `git worktree add --no-track`. Commits `140860e` and `1f5c7b3`,
plus this entry: three ahead of `origin/dev-05` once it is committed.

## What was decided, and by whom

#205 was `ready-for-human`, and its triage left seven questions and #211's option
list to Bertan. The assistant read the issue, its three amendments, #200's design
section, #211 and #212, and the code they name (the driver, ADR 0004, the
library, `REQUIREMENTS_AWK`, the #141 scope section). It then put four choices to
Bertan with a recommendation for each. Bertan took all four:

- **Q1, Q2 and Q7:** a `requirement <ID> <<'REQ'` heredoc in the issue file,
  carrying the entry's fields. The generated file is Markdown in #200's
  unchanged shape, with a last `generated` field.
- **#211:** each issue file pins its own entries' tokens with `shape_pin` and
  `variants_pin`. `REQUIREMENT_SHAPE` and `INV_SCOPE` keep only the entries
  written before #205.
- **Q4:** a frozen literal of the 130 legacy IDs at `cf73c82`,
  `REQUIREMENTS_LEGACY`. A new `gap` or `seam` entry is declared like any other.
- **The generator:** a standalone `generate-requirements.sh` with `--check`,
  beside `split-requirements.sh`.

The assistant took two defaults and stated them to Bertan before building. Q3
(generated scope) is not built, because amendment 3 gates it on #212. Q5
(`doc-claim`) is left to an issue of its own. Step 4 is not decided here. ADR
0005 records every rejected alternative.

## What was built

- `checks/GH-205.sh`, the first issue file. It defines `requirement`,
  `shape_pin` and `variants_pin`, declares GH-205.1 to GH-205.3 in the new form
  and pins their shapes, and drives each piece against fixtures.
- Three library helpers: `generated_bad`, `pins_bad` and `legacy_tokens`. Each
  is called from the issue file (fixtures) and from `end-of-run.sh` (this
  repository), so it belongs in the library by ADR 0004's rule.
- In `end-of-run.sh`, just before the ledger snapshot the #104 findings read:
  every file outside the legacy set is its declaration as bash recorded it;
  `generate-requirements.sh --check` names the same IDs; the pins are once
  each, in the declaring file; and the variants pins match the scope. The
  shape comparison is now handed `REQUIREMENT_SHAPE` with every shape pin.
- The #141 comparison in `unsplit.sh` is held to the legacy entries through
  `legacy_tokens`.
- Four mutation rows, and the registry-count literals moved 81 → 85 and
  79 → 83.

## Measured

- **Baseline** at `cf73c82`: 5,731 ok, 0 FAIL, 3m22s (measured).
- **At `140860e`:** 5,764 ok, ALL CHECKS PASSED. **At `1f5c7b3`:** 5,764 ok,
  ALL CHECKS PASSED (both measured).
- **`mutate-hooks.sh`** on the four new rows: all four caught. The unmutated
  baseline was green over 214 requirements, and `.claude/hooks/` was
  byte-identical afterwards (measured, before the review fixes, whose generator
  edits were to comments only).
- **Fourteen tooling mutations, run by hand.** Each ran in its own rsync copy
  of the worktree, never in the worktree, because the harness refuses tooling
  as a target. Each turned its intended check red, and an unmutated control
  copy was red only on the two registry-count literals, which were then moved
  (measured). The mutations and the check each turned red:
  - byte comparison in `generated_bad`: the fixture and the lost-newline check
  - legacy-marker clause: the fixture
  - undeclared-file clause: the fixture
  - shared-literal clause in `pins_bad`: the fixture
  - wrong-file clause in `pins_bad`: the fixture
  - `legacy_tokens in`: the fixture and #141
  - `shape_pin` line removed: the repository pins check and the FR-45/46 shape
    finding
  - a generated ID added to `REQUIREMENT_SHAPE`: the repository pins check
  - a generated ID added to `INV_SCOPE`: the repository pins check and #141
  - either filter flipped: its comparison
  - a declaration inside `if false`: `generated_bad` and the generator
    cross-check, which is the two readings meeting as designed
  - `GH-999` added to the legacy list: count, checksum and `generated_bad`
  - `requirement` reading with `$(cat)`: the record fixture and `generated_bad`

## Mistakes and dead ends, attributed

- **The assistant's fixture expectations were wrong twice on the first run.**
  The `pins_bad` lines were in the wrong `LC_ALL=C` order. The expectations
  also assumed that an entry pinned only in the wrong file gets two findings;
  it gets one.
- **One fixture could not do what it claimed.** The assistant's fixture helper
  stripped `^@`, so the indented `  @requirement` line was never turned into a
  declaration, and the "indented" refusal was asked of nothing. Changed to
  `s/@requirement/requirement/`.
- **The assistant made two tool slips.** A commit written as
  `cd … && git add && git commit` was refused by `no-commit-to-main.sh` as
  moving git elsewhere; it was run plainly. One plain suite run used a relative
  path from the wrong directory and exited 127 having run nothing. It was
  re-run and is not counted above.
- **The review found the defect class this repository keeps finding in the
  assistant's own prose.** The two-axis review ran as subagents. The
  generator's header and GH-205.2 claimed a refusal of "a line that opens a
  declaration spelled any other way", but the guard reads only lines whose
  first word is `requirement GH-`. `x=1 requirement GH-7 <<'REQ'` passes the
  script silently; only the suite's runtime record turns it red. The prose was
  narrowed to the guard, and the rest is named. The review also found three
  comments still calling the shared literals "every entry", an empty-ID
  bad-subscript error in `pins_bad`, and a `requirement` call that would hang
  on a terminal. All were fixed in `1f5c7b3`.

## Open

- **Generated scope (Q3)** waits for #212.
- **`doc-claim` (Q5)** needs an issue of its own; none has been filed yet.
- **Step 4** needs a full round of the generated form first.
- **GH-205.3 has no mutation row, and cannot have one.** `pins_bad` is tooling,
  and its evidence is the hand-run mutations above. The same is true of
  GH-205.1's `generated_bad`; that entry's rows break data only.
- **The 13 entries added after the split and before #205** (GH-200.x and
  GH-204.x) have no byte check, unlike GH-200.4's 117. The demonstration that
  none was touched is the diff: `requirements/` gains three files and changes
  none.
- **The first other issue file that declares an entry moves `requirement`,
  `shape_pin` and `variants_pin` into the library.** The library-membership
  check will ask for it, and the driver's conventions now say so.
- **Branches cut before #205 that add a hand-written `GH-` entry are red on
  merging across.** At the time of writing that is the open worktrees for
  #118, #144 and #177, if they carry one. The remedy is a declaration, not an
  ID added to the legacy list.
- **#211** closes with this pull request's merge. A `Closes` keyword does not
  link on a `dev-NN` base, so it needs closing by hand or through
  `addCloseIssueReferences`.

# 2026-09-24 19:45 +03 — #222 review round 1 (rev-agent-205)

Same branch, same worktree. This round's code commit and this entry follow
`8f97885`, which leaves the branch five ahead of `origin/dev-05` (`cf73c82`,
unchanged since the branch was cut).

## What the review found, and what was done

rev-agent-205 posted one gating finding and five requested ones, plus #223 for
the narrow items. The assistant reproduced G1 before fixing it, and
mutation-checked every new row in a scratch copy of the worktree. Every
figure below was measured this session.

- **G1, taken.** The previous entry says the bad-subscript error in
  `pins_bad` was fixed in `1f5c7b3`. That was half true, and the assistant
  wrote it: the pin loop was guarded, and the declaration loop beside it was
  not. A record with an empty ID, which is what `requirement "$UNSET"` writes,
  ended the `{ … } | sort` group with `declared: bad array subscript` before
  it printed a line. Probed directly, a fixture with three pin findings printed
  none and returned 0. The declaration loop now skips an empty ID, which
  `generated_bad` already names as out of grammar. A new fixture row puts an
  empty-ID record beside a real pin finding. Removing the guard turns that
  row, and only that row, red. The reviewer's m9b (a shape pin moved into
  `REQUIREMENT_SHAPE`, plus an empty-ID declaration) now fails 3 rows, the
  `pins_bad` row among them, where it failed 2 before.
- **R1, taken.** ADR 0005 still claimed the generator refuses "every spelling
  other than" the canonical one. It now states the guard as the script header
  does, and says what a call the guard does not read (`x=1 requirement GH-7`)
  meets instead. The fixture label "any other way" became "each of these other
  ways".
- **R2, taken.** `lib_misplaced` asks its question of each function by itself,
  so moving all three at once is red whenever the new caller does not call
  `variants_pin`. The driver's conventions and ADR 0005 now say each function
  moves on its own second caller. The previous entry's Open list repeats the
  "moves all three" claim; this entry is its correction.
- **R3, taken.** A fixture now sources a file in `$R205` that calls
  `requirement`, `shape_pin` and `variants_pin`, and it expects that file's
  path in both records. Breaking each of the three `BASH_SOURCE[1]` into `[0]`
  is red on that row, 1 FAIL each. Before this fixture, m11 passed the whole
  suite.
- **R4, taken.** The families-scope row's expected side splits and sorts the
  pins with `awk | sort` and no longer calls `legacy_tokens`. m12
  (`legacy_tokens`'s `out` branch prints nothing) is still red on the fixture
  row, 1 FAIL.
- **R5, declined.** `shape_pin` and `variants_pin` are two names because a
  declaring file writes them. A shared body under both would move the caller
  to `BASH_SOURCE[2]`, and R3 just showed that this index is the detail that
  had no check. `generated_bad`'s narrower glob is backed by #200's
  misnamed-file check, as the reviewer notes, and a `grep` per legacy file is
  130 small processes a run.

A sentinel line on any abort of the two helpers was considered as the
general fix for G1's class, and the assistant rejected it. Once the empty ID
is guarded, no input to either helper is known to end the group early, so the
sentinel would be an assertion nothing can drive.

## Numbers

- `bash .claude/hooks/check-hooks.sh` at this round's code commit: exit 0,
  5,766 ok, ALL CHECKS PASSED. That is 5,764 plus the two new rows.
- Mutants, each one whole suite run in its own copy: unguarded declaration
  loop 1 FAIL, m9b 3 FAIL, `BASH_SOURCE[0]` in `requirement`, `shape_pin` and
  `variants_pin` 1 FAIL each, m12 1 FAIL.

## Open

Everything from the previous entry's Open list stands, except its line about
the library move, which R2 corrected above. #223 holds the reviewer's five
narrow items.

# 2026-09-24 20:16 +03 — #222 review round 2 (rev-agent-205)

Same branch. Code commit `b7bd9ec` and this entry follow `cd53d82`, which
leaves the branch seven ahead of `origin/dev-05` (`cf73c82`, unchanged).

## What the review found, and what was done

rev-agent-205 re-ran round 1's mutants and closed G1. The reviewer then swept
what the generator's regexes admit rather than what its prose says, and found
one gating finding and one requested finding. Two narrow items went to #223.

- **G2, taken.** The spelling guard matched the ID with `[^ ]+`, which admits
  a tab. So `requirement GH-7<TAB>junk <<'REQ'` passed the guard, awk's
  default field splitting made `$2` `GH-7`, and the file was written under
  GH-7. Bash meanwhile recorded the call's ID as `GH-7 junk`. The assistant
  wrote the class `[^ ]` in the first commit, and the previous round's sweep,
  like the reviewer's first sweep, read the words and not the character class.
  It is `[^ \t]+` now, the header names the tab, and the `spelled` fixture
  gains a tab line, written with `printf` so the tab can be seen. Reverting
  the class fails that row only (1 FAIL).
- **R6, taken as a narrowing.** `--check` exits on a refusal before its
  staleness pass, and the header said it prints both. The assistant chose to
  narrow the prose rather than run the staleness pass as well. A refused run's
  staged set is missing the refused declarations, so a staleness report beside
  it would be about a partial set. The header and GH-205.2 now say a refusal
  is reported alone, and GH-205.2's file was regenerated. A new fixture row
  runs `--check` on the `partial` fixture, which has a stale file beside a
  refusal, and expects the refusal alone. A mutant confined to `--check` that
  goes on to the staleness pass fails that row only (1 FAIL). A first mutant,
  which deleted the refusal's `exit 1` outright, also broke the write path
  (9 FAIL). It said nothing about `--check` alone, so the narrower one
  replaced it.

## Sweeps

- **Every character class in the diff, against a tab.** The trigger and blank
  line tests already name `[ \t]`. The continuation test `^  [^ ]` is the same
  class the entry readers use (`end-of-run.sh:214`, `unsplit.sh:10926`), so the
  generator and the readers cannot disagree about a continuation. The pins
  split on bash's IFS on both the writing and the reading side. No other gap
  was found.
- **Every copy of the `--check` claim.** Only the header, GH-205.2 and the PR
  body's summary carried it. The PR body is updated too.

## Numbers

- `check-hooks.sh` at `b7bd9ec`: exit 0, 5,767 ok, ALL CHECKS PASSED. That is
  5,766 plus the `--check` row; the tab joined an existing row.

## Open

As before. #223 now also holds the reviewer's round-2 items: a generated file
whose marker is deleted reads as hand-written, and `DECLARED`/`PINNED` are
generic names.

# 2026-09-24 20:53 +03 — #222 review round 3 (rev-agent-205)

Same branch. Code commit `4e150c2` and this entry follow `0780086`, which
leaves the branch nine ahead of `origin/dev-05` (`cf73c82`, unchanged).

## What the review found, and what was done

rev-agent-205 closed G2 and R6 and widened the "empty means success" sweep to
the generator's inputs. That sweep found two gating findings and one requested
finding.

- **G3, taken, with two siblings of its own.** The generator reported a clean
  pass in three cases: a directory that is not there, a directory with no
  `checks/`, and an awk that died. The awk case was reachable: `awk -v stage=`
  read a TMPDIR holding `\t` as a tab, so awk could not open its own stage.
  The assistant wrote `awk -v` in the first commit, although the `TOOLING`
  comment and `requirements_split` both name it as the reason this repository
  does not pass paths through `-v`. The fix has four parts:
  - the directory is resolved and must hold `checks/`, or the run is refused;
  - the stage reaches awk through `ENVIRON`;
  - a non-zero awk status is a failed reading, and nothing is written;
  - an empty directory argument is a usage error.

  The last was found while the assistant wired the view below: an empty
  argument fell back to the script's own directory, so a view that failed to
  build would have been answered about the wrong tree. Resolving the
  directory to an absolute path also closes a quieter sibling. A relative
  path whose first segment holds a `=` would have reached awk as a
  `var=value` operand. Six new rows drive these, the dead awk through a stub
  `awk` first on `PATH` that exits 2. A `chmod 000` issue file was probed
  first and works, but root reads such a file all the same, so the stub is
  the fixture. Each part's mutant fails its own row (1 FAIL each; removing
  the whole directory guard fails 2).
- **G4, taken, by reading the issue files from the suite's side.** Of the
  reviewer's two options, the assistant chose the one the driver's own
  `TOOLING` rule points to. `checks/` is tooling, whose text is read off
  `$SUITE_DIR` and never off the judged copy. Requiring a copy of it in the
  judged tree would have satisfied the guard while contradicting that rule.
  `generator_view`, in the library, builds a directory from the suite's
  `checks/` and the judged `requirements/`, each a symbolic link, and the
  cross-check runs the judged generator over it. This also closes #223 item 4.
  Two fixture rows drive the view against a judged side that has no
  `checks/`, one of them with a stale judged file. Swapping either link fails
  its row. The reviewer's scenario was re-run: `CHECK_HOOKS_DIR` pointed at a
  copy of `.claude/hooks/` without `checks/` now exits 0 with 5,773 ok, where
  it had 1 unrelated FAIL. One limit, stated beside the call: in this
  repository both sides are one directory, so the end-of-run call site's
  choice of `$SUITE_DIR` is asked only by the fixture, not by any normal run.
- **R7, taken.** The remedy for a branch cut before #205 now says to delete
  the hand-written file first. It is fixed in ADR 0005, the `REQUIREMENTS_LEGACY`
  comment and the PR body. This entry corrects the first entry's Open line,
  which gave the same remedy without that step.

The suite requires every issue it cites to have an entry or a reason, and
the new comments cite PR #222. requirements.md gained a `- #222:` line in the
form #210, #216 and #220 already use. The suite had caught this, 1 FAIL,
before the line was added.

The assistant's first push this round was refused by `no-git-push.sh`, which
read a `2>&1` written after the branch name as the push's destination. The
command was a compound line, so none of it ran. The push was re-run alone.

## Numbers

- `check-hooks.sh` at `4e150c2`: exit 0, 5,773 ok, ALL CHECKS PASSED. That is
  5,767 plus six rows: the missing directory, the missing `checks/`, the dead
  awk, the TMPDIR, and the two view rows. The usage row gained a third case.

## Open

As before, less #223 item 4, which the view closes. #223 also gained the
round-3 note on the entry-field grammar's copies.

# 2026-09-24 21:40 +03 — #222 review round 4 (rev-agent-205)

Same branch. Code commit `f419f78` and this entry follow `243dbe9`, which
leaves the branch eleven ahead of `origin/dev-05` (`cf73c82`, unchanged).

## What the review found, and what was done

No gating findings. rev-agent-205 closed G3 and G4, requested two text fixes,
and offered a correction to a limit the previous entry understated.

- **R8, taken, with a sibling.** The stale-branch remedy was still short.
  A branch cut before #205 also appended the entry's tokens to
  `REQUIREMENT_SHAPE` and, for an entry with variants, `INV_SCOPE`, and wrote
  no pin, so after the three steps round 3 gave, `pins_bad` is still red. ADR
  0005 now gives four steps. The `REQUIREMENTS_LEGACY` comment and the PR
  body say the same. The assistant's sweep of instructions in the diff's
  prose found the same shape in `CLAUDE.md`: its instruction for a new entry
  said to declare it and run the generator, and did not mention `shape_pin`.
  Following it as written leaves the entry with no pin, which `pins_bad`
  reports. It now names the pin.
- **R9, taken.** "An ID is never deleted" is held for the legacy set only. The
  reviewer's m14 deleted GH-205.3 outright, with its declaration, pin and
  file, and the suite passed. GH-205.1's note, ADR 0005's trade paragraph
  and requirements.md's rule on IDs now say so, and point at #223, where it is
  filed. GH-205.1's file was regenerated. The suite then required a
  citation entry for #223, which requirements.md gained.
- **The limit sentence, corrected.** The previous entry and the end-of-run
  comment said that the order of `generator_view`'s arguments at its call
  site is asked only by the fixture. The mutation harness asks it too,
  because it runs the suite with `CHECK_HOOKS_DIR` on a copy. The assistant
  re-measured before restating it. `mutate-hooks.sh
  generated-entry-edited-by-hand legacy-entry-marked-generated` was run in two
  copies taken at `243dbe9`. With the arguments swapped, both rows went from
  caught to survived (exit 1). In the unswapped control both were caught
  (exit 0). The reviewer described those rows as naming GH-205.2 alone. They
  name GH-205.1 and GH-205.2. The rows naming GH-205.2 alone are the two
  generator rows, which fixtures catch whatever the call site does. The
  comment says which rows, and why the swap hides the mutation: the check
  then reads the suite's own `requirements/`, which the mutation did not
  touch.

The assistant's first draft of that comment said the rows named GH-205.2
alone, taking the reviewer's wording. The assistant then read the registry
and corrected the draft before committing. The second draft had the mechanism
backwards: it said the copy's own files were read. That was corrected too,
also before committing.

## Numbers

- `check-hooks.sh` at `f419f78`: exit 0, 5,773 ok, ALL CHECKS PASSED. This
  round changed text, not checks.
- Harness, two rows in each of two copies: swapped, 2 survived; control, 2
  caught.

## Open

As before. #223 now also holds the deletion of a generated ID (item 9) and
the field-grammar disagreement the reviewer measured (item 2).

# 2026-09-24 22:20 +03 — #222 review round 5 (rev-agent-205)

Same branch. Code commit `87e5f71` and this entry follow `40f2f2b`, which
leaves the branch thirteen ahead of `origin/dev-05` (`cf73c82`, unchanged).

## What the review found, and what was done

No gating findings. rev-agent-205 confirmed round 4, including the
assistant's correction of which harness rows the view swap reaches. The
reviewer asked for three small fixes, R10–R12, and offered R13. For R11 and
R12 the choice between fixing here and filing was left to the assistant.
Each was small enough to fix and test here, so all four were fixed.

- **R10, taken.** `CLAUDE.md`'s new-entry instruction, extended in round 4
  with `shape_pin`, still left out `variants_pin` for an entry in the
  invariance families' scope. The assistant stopped at the one pin R8's
  example named, and did not check the instruction against the driver's
  conventions, which name both. It names both now.
- **R11, taken.** Nothing tied a declared ID to the issue file that declares
  it. The reviewer's m16 declared GH-229.1 in `checks/GH-205.sh`, and the
  suite passed. `generated_bad` now names an entry of #<n> declared anywhere
  but `checks/GH-<n>.sh`, and GH-205.1's text says so. Its file was
  regenerated, and its end-of-run row's label names the rule. The generator
  does not refuse this. GH-205.2 does not claim it, and the suite holds it.
  m16 was re-run: the generator writes the file, and the suite is red,
  1 FAIL, on GH-205.1's row. The assistant's first m16 probe had a
  `retired` status with no reason and so drew a second, unrelated FAIL. It
  was re-run with a reason.
- **R12, taken, with a sibling.** `generated_bad` compared through a command
  substitution, which drops a NUL, so its "byte for byte" was not. It now
  compares with `cmp -s` against `printf '%s' "$want"`. A new fixture row
  inserts a NUL. The sibling is the generator-output fixture row labelled
  "byte for byte", which compared via `$(cat …)`; it now reads both sides
  through `od -c`. A mutant that makes the generator write a NUL after the
  heading fails that row and GH-205.2's cross-check. #200's own row
  (`end-of-run.sh:1089`, "each entry is a file of its own, byte for byte")
  has the same shape. It is not this PR's code, so it is reported, not
  changed.
- **R13, taken.** `pins_bad` skipped only an empty ID, so it asked an
  out-of-grammar ID such as `GH-07` for a pin no spelling of it can take. It
  now skips every ID out of grammar. The grammar is now `generated_id`, a
  library function that both helpers call, rather than a second regex
  literal. The assistant's first version was a library variable, which the
  #204 check "changes nothing else about the shell that sources it" refused,
  1 FAIL: the library defines functions and nothing else. The existing
  empty-ID fixture gained a `GH-07` record. Reverting to the empty-only guard
  fails that row, and so does removing the guard.

## Numbers

- `check-hooks.sh` at `87e5f71`: exit 0, 5,774 ok, ALL CHECKS PASSED. That is
  5,773 plus the NUL row; the other fixes extended existing rows.
- Mutants, one whole suite run each: ownership check removed, 1 FAIL;
  command-substitution comparison restored, 1 FAIL; empty-only guard, 1 FAIL;
  no guard, 1 FAIL; generator writes a NUL, 2 FAIL; m16, 1 FAIL.

## Open

As before. #200's `od`-less "byte for byte" row is reported in the reply
rather than filed.

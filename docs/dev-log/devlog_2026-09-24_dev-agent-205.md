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

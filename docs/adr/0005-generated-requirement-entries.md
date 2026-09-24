# A new `GH-` entry is declared in its issue file, and its file is generated

A `GH-` requirement written after #205 is declared once, in the issue file whose
checks establish it, as a heredoc at the start of a line:

```bash
requirement GH-205.1 <<'REQ'
- text: ...
- from: #205
- kind: defect-permitting
- status: active
- direction: static: ...
REQ
shape_pin 'GH-205.1:static'
```

`.claude/hooks/generate-requirements.sh` writes `requirements/GH-205.1.md` from
it: the heading, the body byte for byte, and a last field,
`- generated: checks/GH-205.sh`. The file keeps the Markdown shape #200 gave
every `GH-` entry, so `requirements_read` and every other reader of the registry
are unchanged. The 130 entries `requirements/` held at `cf73c82` are the
**legacy set**, held by the driver as `REQUIREMENTS_LEGACY`. They stay
hand-written, and none is rewritten, migrated or declared. The list never grows.

The suite holds this in three places. First, every file outside the legacy set
is, byte for byte, its declaration as bash read it when the suite ran the issue
file. Second, the generator's own reading of the same files names the same
entries and would write nothing. Third, the shape and `variants` tokens that
used to be appended to `REQUIREMENT_SHAPE` and `INV_SCOPE` are pinned in the
declaring issue file, once each, and the shared literals hold no generated
entry.

These are steps 3 and 4 of #200's migration, cut down to what could be decided
now. The questions were #205's Q1–Q7 and #211's option list. Bertan settled
them on 2026-09-24.

## Why

#200's argument: a requirement's `text` was a sentence written by hand beside
the checks that establish it, and nothing held the two to each other. Two copies
of one fact, kept in step by hand, are where this project keeps finding its
defects. The split in #200 removed the merge conflict on `requirements.md`. It
did not remove the hand-kept copy, and it moved the shared hunk into two
literals of the check suite: every new entry still appended a token to
`REQUIREMENT_SHAPE` and `INV_SCOPE` (#211).

Declaring the entry in the issue file puts its text beside the checks that
establish it, in a file one loop writes (ADR 0004). Generating the registry
document means that no second copy of the text is written by hand.

## Considered Options

**Entry form (Q1, Q2, Q7).**

- *Structured arguments* (`requirement GH-205.1 kind=… text="…"`), with
  Markdown generated from them. Rejected: a multi-line `text` has to be quoted
  as one shell word, which is harder to write and to review than the field
  grammar requirements.md already states.
- *A structured registry document* (TSV or JSON) generated from the same
  heredoc. Rejected for now: `requirements_read` would learn a second input
  format for one family. Whether the documents need to exist at all is
  #200's step 4. That step needs a full round of evidence first and is not
  decided here.

**The shared literals (#211).**

- *Keep the tokens*: new entries still append to both literals. Rejected: this
  keeps the conflict #211 measured, six merges of six.
- *A count per family* in place of the ID list, which is #211's option 1 as
  written. Rejected: a count says how many entries changed and not which, and
  #104's review found exactly the two edits a count cannot see: a direction
  declared, and a marker moved from one entry to another. It is also one shared
  number again.
- *The pin in the issue file*: chosen. It keeps the literal's purpose, a second
  copy of what the coverage and the families read off an entry, which a
  reviewer sees move in the diff, and one writer edits it. What it gives up:
  the copy stands in the same file as the declaration and is written in the
  same commit by the same hand. `REQUIREMENT_SHAPE` was the same to
  `requirements.md`, so it is a second copy, not a second author. The same
  holds for deletion. A generated entry deleted outright, with its
  declaration, its pin and its file removed in one commit, leaves nothing
  behind that disagrees, so the suite passes. Before #205 such a deletion
  also edited the shared literal. The rule that an ID is never deleted is
  held for the legacy set only, and holding it for a generated ID would need
  history or a grow-only ledger of IDs, which is a shared hunk again (#223).

**Telling legacy from generated (Q4).**

- *The marker field decides*: a file carrying `generated` is generated, and one
  without it is hand-written. Rejected: nothing then stops a new hand-written
  file that simply leaves the marker off.
- *A hand-kept residue list* for new `gap` and `seam: none` entries, as #200
  proposed. Rejected: a new entry of either kind has an issue file like any
  other, the one of the work that found it, and is declared there with no
  check tagged. The only residue is the legacy set, and that list is frozen.

**Where the generator lives.** A `--generate` mode of `check-hooks.sh` was
rejected. The driver would take on a writing mode that runs before it sources
anything. A standalone script beside `split-requirements.sh` follows that
script's precedent: it is not a hook, nothing runs it for you, and the suite
runs it against fixtures and against the repository.

## Consequences

- **Generated scope is not built (Q3).** #200's design point 3 generates a
  requirement's scope, the command shapes and verdicts it covers, from the rows
  that test them. Those rows would be read off `req` tags. A tag's scope runs
  on to the next `req` (#212), so a generated scope could claim more than its
  rows test, and ADR 0004 closes that class only at file boundaries. It waits
  for #212.
- **`doc-claim` entries (Q5)** are declared like any other new entry. Whether
  they belong in the ledger, beside the document they check, or derived from it
  is left to an issue of its own.
- **Step 4 (Q6)**, whether the `GH-` documents need to exist as files at all,
  is decided in a later change, once the generated form has carried a full
  round.
- **`requirement`, `shape_pin` and `variants_pin` are defined in the #205 issue
  file**, because the library holds a function only once it has callers in
  more than one file (ADR 0004). The check asks that of each function by
  itself, so each moves into `checks/library.sh` once another file calls it:
  the first other issue file that declares an entry moves `requirement` and
  `shape_pin`, and `variants_pin` waits for a file whose entry is in the
  families' scope. That move is expected, not a defect.
- **A branch cut before #205 that adds a hand-written `GH-` entry** is red once
  it merges across. The remedy has four steps:
  1. Delete the hand-written `requirements/GH-<n>.md`.
  2. Declare the entry in its issue file.
  3. Move its token out of `REQUIREMENT_SHAPE` into a `shape_pin` in that
     issue file, and out of `INV_SCOPE` into a `variants_pin` if it has one.
  4. Run the generator.

  The file must go first, because the generator refuses a declared ID whose
  file is hand-written and leaves that file alone. The tokens must move,
  because a branch cut before #205 appended them to the shared literals and
  wrote no pin, and `pins_bad` names both halves of that. Adding the ID to
  `REQUIREMENTS_LEGACY` is not a remedy. The
  #205 issue file holds that list to its count and checksum, so a new ID there
  shows in two places.
- **The two readings of a declaration meet in the files.** The generator reads
  the issue files as text, and bash reads them when the suite runs. A
  declaration spelled in a way one reads and the other does not, such as
  inside an `if` that never runs or inside a fixture heredoc, turns one of the
  two checks red. The generator also refuses a line whose first word, after
  any indentation, is `requirement` followed by `GH-`, when it is spelled other
  than `requirement <ID> <<'REQ'` at the start of the line. A call it does not
  read that way at all, such as `x=1 requirement GH-7`, is not refused by it:
  bash records the call, and the entry is found declared and not written.
- **Still shared:** `INV_SEEDS`, the seed table a new entry declaring
  `variants: seed` must be tagged in, stays in the unsplit file. The mutation
  registry stays in `mutate-hooks.sh` (#215).

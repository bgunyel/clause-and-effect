# 2026-09-25 15:30 +03 — #215: the mutation harness's run log is frozen, and later runs go to the dev-log

Branch `worktree-issue-215-freeze-run-log`, cut from `origin/dev-05` at
`2c65f4d` with `git worktree add --no-track`, then fast-forwarded to
`origin/dev-05` at `5017b2b` before its first commit. Commits `9732562` and
`9fba2f0`, plus this entry: three ahead of `origin/dev-05` once it is
committed.

## The conflict was in the run log, so the log is frozen

The mutation harness's header mixed two kinds of text: the rules, and a dated
run log. Every loop that registered a row appended a paragraph to the log.
#215's triage re-measured at `2c65f4d`: #184 and #158 conflict only in header
prose, and no hunk falls inside the `MUTATIONS` heredoc. So the registry was
left whole and the log was frozen.

- **The frozen region runs from the line**
  `# MEASURED, 2026-09-17, at the commit that answered that review: all twenty-three`
  to `# thing #107 was filed about, and the registry is re-runnable instead.`
  It is 216 lines, and each bounding line stands once in the file.
- **Byte identity was measured, not asserted.** The region was extracted from
  `origin/dev-05` and from the branch with the same awk, and `diff` was
  empty: 216 lines, cksum `1303306919 15781`. The harness diff adds 14 lines
  and removes none.
- **A freeze paragraph stands directly above the log.** It names both lines by
  their text, and says the log's present tense is #215's. It also says a run
  after #215 is recorded in the dev-log of the session that ran it.
- **No rules paragraph told a reader to record a run in the header**, so no
  rules text changed.
- **What the region covers and leaves out, and why,** is in the header of
  `checks/GH-215.sh`. Two rule paragraphs inside the log, THE BRACKET FIGURE
  IS HISTORY and THREE ROWS FOR ONE FIX, are frozen with it rather than moved
  out, because each qualifies figures the log measured.
- **The trade is recorded** in the commit message and in the check file. A
  block that is stale by construction stays in the file. The rejected
  alternative was moving the log into a dated file under `docs/`.

## The check pins content, and asks the neighbours by their opening words

`checks/GH-215.sh` declares GH-215 (`doc-claim`, `static`), pins it with
`shape_pin`, and its requirements file is generated. The checks:

- **Each bounding line stands once.**
- **A cksum of the region.** A shape pin would pass a paragraph rewritten in
  place, and the log stays verbatim with its errors.
- **The paragraph below the log opens `WHAT A MUTATION IS.`,** so a record
  appended after the log's last line is red. That is where the loops
  appended, and where a region checksum is blind.
- **The paragraph above the log opens `THE RUN LOG BELOW IS FROZEN, AT
  #215,`.**
- **Four `holds` on that paragraph's claims.**

`requirement` and `shape_pin` moved from `checks/GH-205.sh` into
`checks/library.sh`, because GH-215.sh is their second caller. ADR 0005
predicted the move. `variants_pin` stays in GH-205.sh.

`mutate-hooks.sh --list`: all 85 rows are unchanged (measured, diff of the
two outputs). The one line that moves is the derived active-requirement
count, 195 → 196, which counts GH-215.

## Measured

- **Baseline** at `2c65f4d`, in a detached checkout: 5,774 ok, ALL CHECKS
  PASSED, 198 s.
- **At `9732562`'s content**, as an unmutated rsync control: 5,783 ok, ALL
  CHECKS PASSED. Nine new checks. **At `9fba2f0`'s:** 5,783 ok, ALL CHECKS
  PASSED.
- **Twelve hand mutations of the harness header**, each in its own rsync copy
  of the worktree, because the harness refuses its own file as a target. Run
  against `9fba2f0`'s checks, each turned red exactly the GH-215 checks named
  below and nothing else in the suite:
  - a record appended after the log's last line: the neighbour below
  - a record inside the log: the checksum
  - a record between the freeze paragraph and the log: the neighbour above,
    and the four claims, because the inserted record is then the paragraph
    they are asked of
  - the freeze paragraph deleted: the neighbour above and the four claims
  - `AT #215` dropped: the neighbour above and the frozen claim
  - the line-naming clause, the present-tense sentence, and the dev-log
    clause, each weakened in turn: its own claim
  - the present-tense sentence moved into WHAT A MUTATION IS: its claim.
    Under `9732562`'s checks this mutation would have been green (see below).
  - the first line duplicated elsewhere: the count of the first line
  - the last line deleted: its count, the checksum and the neighbour below

  A rewrap of the freeze paragraph and of WHAT A MUTATION IS stayed green:
  5,783 ok. The first eleven were also run against `9732562`'s checks, and
  each was red there too. The one difference was the inserted record, which
  turned only the neighbour above red, because the claims were then read off
  the whole header.
- **This session's mutation run, the first recorded here under the new rule
  rather than in the harness header:**
  `bash .claude/hooks/mutate-hooks.sh -v selftest-anchor-that-matches-nothing`,
  run alone at `9fba2f0` on 2026-09-25 to show the harness still starts with
  its header edited. The unmutated baseline copy was green, and the row
  reported `did-not-apply`, as it declares. `.claude/hooks/` was
  byte-identical after the run. Exit 0, 183 s (measured). That is evidence
  that the harness runs, and about nothing else: no real row was run.

## Mistakes and dead ends, attributed

- **The assistant edited files under a running baseline.** It started the
  suite in the worktree in the background and then edited `mutate-hooks.sh`
  and `check-hooks.sh` while the suite was running. It killed that run by PID
  and re-ran the baseline in a detached checkout of `origin/dev-05`.
- **The first run of the change was red on the library-membership check.**
  The assistant had read the driver header's note that `requirement` and
  `shape_pin` move to the library once a second file calls them, and still
  wrote the issue file without moving them. The move was made after the red
  run.
- **The stale-branch guard refused the first commit.** `origin/dev-05` had
  moved 8 commits, none of them under `.claude/`. The branch was
  fast-forwarded and the commit made on top.
- **Review of `9732562` found five defects in the assistant's work.** A
  standards review and a spec review, run as parallel sub-agents, found them.
  - The four freeze-paragraph claims were asked of the whole header, so a
    sentence moved into any other paragraph stayed green, while GH-215's text
    claims the freeze paragraph says them.
  - The commit message gave a wrong reason for using `holds`: to keep a count
    literal in `unsplit.sh` still.
  - The 2026-09-17 readings were called "a measurement of the rate, not a run
    of any row". They are the wall-clock of two whole-registry passes.
  - The left-out list omitted several dated paragraphs, two of them below
    `set -u`.
  - The neighbour pins used hand-counted prefix widths.

  All five are answered in `9fba2f0`, whose message gives each one.

## Open

- **Not yet reviewed by Bertan.** The pull request goes to `dev-05`.
- **#184 and #158 add paragraphs to the log's account**, according to #215's
  triage. When either one merges `dev-05`, a record it keeps inside the
  frozen region turns GH-215 red. The remedy is to move that paragraph into the dev-log of
  the session that ran it, which is what the freeze paragraph says to do.

---

# 2026-09-25 16:21 +03 — #230 review round 1 (rev-agent-215)

Branch `worktree-issue-215-freeze-run-log`. This round's commits are `6687d3e`,
the fix, and this entry. The branch is five ahead of `origin/dev-05` (`5017b2b`)
once this entry is committed. The review, at `8abaf6f`, raised four classes. The
assistant took C1 with a different signature from the one proposed, took C2 and
widened it to a sibling the review had called correct, and took C3 and C4 as
written.

## C1: a record one paragraph past the fence. Taken, with a wider signature

Review measured three placements that passed at `8abaf6f`: the last sentence of
the freeze paragraph, a new paragraph above it, and a new paragraph below WHAT A
MUTATION IS. The first is where the next loop would write, so the shared append
hunk had moved, not gone.

The review proposed pinning the date count outside the region, and the absence
of `byte-identical after`. It said every record in the log carries one of the
two. The assistant split the frozen region into sentences and measured that
claim. It is false: `#128 added three and ran them the same way, baseline plus
three, all caught with GH-128 red.` carries neither. Neither does the sentence
that re-ran the five #139 rows as one selection. Every sentence in the log that
records a run carries a date, or one of `byte-identical after`, `selection` and
`baseline`. The run-sentences that carry none were all commentary, not records.

Outside the region, measured at `8abaf6f`:

- **Dates, over the whole file: 6.** Three are in the header and three below
  `set -u`, at the rate.
- **In the header's prose, read as `$MUT_PROSE` reads it:**
  - `byte-identical after`: 0
  - `selection`: 0 (the code below `set -u` says it once, in a comment)
  - `baseline green`: 0
  - `baseline plus`: 1, in the rule on what naming rows costs

GH-215.sh now pins those as six checks: a holds that the region was read to the
header's last paragraph, the date count `6`, three `lacks`, and the
`baseline plus` count `1`. What it names as unseen:

- a record with no date and none of the four phrases;
- an undated record below `set -u`.

## C2: a second reader of the header's prose. Taken, and one sibling widened

The reader is now one function, `comment_reflow` in `checks/library.sh`, since
the #204 membership rule puts a helper with two calling files there. `$MUT_PROSE`
is built with it, and so are GH-215's freeze paragraph and its neighbour below.
The assistant declined to write a third copy of the `sed | tr | tr`, because a
copy is how this class arose.

The review called the neighbour reads correct to read raw bytes. The assistant
measured that and disagrees, for both bare lines, which sit outside the
checksum. At `8abaf6f`:

- a trailing blank on the bare `#` below the log is 1 false red;
- the same blank on the bare `#` above the log is 5 false reds: the neighbour
  above and all four claims.

Both reads now take a bare line to be `#` and blanks only. The lines inside the
region are still compared byte for byte, on purpose.

## C3 and C4, and the library header

- **C3.** The trade now says the log names 45 registry row ids (the assistant
  measured the backticked ids in the region against the `MUTATIONS` rows), and
  that a later rename leaves the log naming rows that do not exist.
- **C4.** The review is right that the round-0 entry put several of the
  assistant's errors in the passive or on an artifact. That entry is
  append-only, so here they are, attributed:
  - The assistant asked the four freeze-paragraph claims of the whole header.
  - The assistant gave a wrong reason for `holds` in `9732562`'s message.
  - The assistant called the 2026-09-17 readings a measurement of the rate
    and not a run.
  - The assistant's left-out list omitted several dated paragraphs.
  - The assistant hand-counted the neighbour pins' prefix widths.
  - The assistant first tried to commit on a base eight commits behind
    `origin/dev-05`, and the stale-branch guard refused it. The assistant then
    fast-forwarded the branch to `5017b2b`.
- **Library header.** `$SUITE_DIR`, `$DECLARED` and `$PINNED` are now listed.
  The omission predates this branch, as the review measured.
- **The freeze paragraph's closing sentence** now says GH-215.sh also holds the
  rest of the file to carrying no record in the log's words, so the next loop
  sees why it went red. The harness diff against `5017b2b` is now +16 / −0.

## Measured

The runs were 26 full-suite runs, each in its own `git clone` of the named
commit, with the mutant applied by a script that exits non-zero when its edit
does not apply. Each ran under `env -i`, so no exported function reaches the
suite (#231).

**Controls:**

- `6687d3e`: 5,789 ok, 0 FAIL.
- `8abaf6f`: 5,783 ok, 0 FAIL.

**The review's three survivors:**

| mutant | at `8abaf6f` | at `6687d3e` |
|---|---|---|
| record as the freeze paragraph's last sentence | green | 2 FAIL: date count, `byte-identical after` |
| record as a paragraph above the freeze paragraph | green | 2 FAIL: the same two |
| record as a paragraph below WHAT A MUTATION IS | green | 2 FAIL: the same two |

**One signature each, appended to the freeze paragraph at `6687d3e`.** Each
turned exactly its own check red, one FAIL:

- date only;
- `byte-identical after` only;
- `selection` only;
- `baseline green` only;
- `baseline plus` only. This one is green at `8abaf6f`. It has no date and no
  `byte-identical after`, so the review's proposed pin would have passed it.
- a dated record below `set -u`, caught by the date count.

**Whitespace:**

| mutant | at `8abaf6f` | at `6687d3e` |
|---|---|---|
| trailing blank on a freeze-paragraph line | 1 FAIL | green |
| freeze-paragraph continuation lines indented `#   ` | 3 FAIL | green |
| trailing blank on the bare line below the log | 1 FAIL | green |
| trailing blank on the bare line above the log | 5 FAIL | green |

The review's indent mutant turned one check red. The assistant's indented every
continuation line, which is why it turned three.

**Named gaps, run so that the table is not assumed.** Both green at
`6687d3e`, as GH-215.sh says they will be:

- an undated record with none of the four phrases, in the freeze paragraph;
- an undated record below `set -u`.

**Rewrap control.** The freeze paragraph rewrapped at 60 columns is green.

## Mistakes, attributed

- **The assistant first cited "PR #230" in the new comments.** The citation
  check went red: #230 had no entry and no reason. Giving it one would mean
  appending a line to `requirements.md`'s citation list, which is the
  shared-append hunk class this issue removes. The assistant cited "#215's pull
  request" instead, and #215 has an entry.

## Open

- Not yet reviewed by Bertan. The heads-up on #184 and #158 still stands. A
  record either one keeps outside the region, in the log's words, now turns
  GH-215 red too.

---

# 2026-09-25 17:22 +03 — #230 review round 2 (rev-agent-215)

Branch `worktree-issue-215-freeze-run-log`. This round's commits are:

- `575df8d`, the fix;
- `d0a910a`, a sibling found by the sweep;
- this entry.

The branch is eight ahead of `origin/dev-05` (`5017b2b`) once this entry is
committed.

The review re-ran its round-1 mutants at `cf0ecda` and confirmed the round-1
fixes. It also accepted both of the assistant's round-1 corrections. It raised
three new classes. The assistant took all three, and found one more sibling
itself.

## C1 inside its own fix: the vocabulary was narrower than a record

The review wrote records in the log's own phrasing, and the phrase list passed
them: `came back byte-identical`, `the baseline was green`, and a sentence
opening `Selection of`, which passed because `lacks` is case-sensitive.
It also deleted the clause `because for several runs it is the only record
there is` from the freeze paragraph, and every check stayed green: the claims
were asked as clauses.

The review proposed pinning the freeze paragraph by its whole reflowed text.
The assistant agrees. In round 1 the assistant declined that pin on the
reviewer's own framing, that it "closes only the first placement". That was the
wrong reason: the first placement is the one the header itself calls the likely
spot.

- **The freeze paragraph is now compared whole**, as `comment_reflow` reads it,
  against a heredoc literal. The four claim checks stay beside it, so a red
  names which claim went.
- **The phrase list became stems, with case folded.** The assistant measured the
  header outside the log, case folded: `selection` 0, `byte-identical` 1 (in A
  MUTATION THAT DOES NOT APPLY IS A FAILURE), and `baseline` 5 (the pass-cost
  rules and THE BASELINE RUN). The stems replace the four phrase checks with
  three: one `lacks` and two counts. Every phrase from round 1 contains a stem,
  so the net is strictly wider.
- **`caught` is not asked**, and the header now says why. The header's rules use
  it twelve times, as the harness's word for an outcome, so a count would go red
  on the next rule about outcomes.

## C6: a claim broader than its check

- **The freeze paragraph** said GH-215.sh holds "the rest of this file" to the
  log's words, but the words are asked only of the header. It now says the log is
  held to its bytes, this paragraph to its words, the rest of the file to its
  dates, and the rest of the header to the log's words.
- **The same overclaim in GH-215.sh's own header.** The sweep found "So the rest
  of the file is asked for the words", and it is fixed in `d0a910a`. The review
  had called GH-215.sh's header accurate. Its WHAT IT DOES NOT SEE bullet was
  accurate, but that sentence was not.
- **The round-1 entry** above says the freeze paragraph's closing sentence holds
  "the rest of the file to carrying no record in the log's words". That was the
  assistant's overclaim. This entry corrects it, and the round-1 entry stands
  as written.

## C7 and the rate

- **C7.** `unsplit.sh`'s statement of the prose-pin rule now names
  `comment_reflow`: `$MUT_PROSE` when a pin asks the whole header, one paragraph
  when it asks one.
- **The rate.** The date count's label and the rate bullet now say that a
  re-measure which adds a dated sentence moves the literal `6`.

## Measured

There were 19 full-suite runs, each in its own `git clone`, under `env -i`,
with the mutants applied by the same script as round 1. Controls: `575df8d`
5,789 ok / 0 FAIL. `d0a910a` (comment only) gave 5,789 / 0 in the worktree, and
`--list` was identical to round 1's.

| mutant | `cf0ecda` | `575df8d` |
|---|---|---|
| own-phrasing record, last sentence of the freeze paragraph | green | 3 FAIL: whole paragraph, `byte-identical`, `baseline` |
| `Selection of …` paragraph below WHAT A MUTATION IS | green | 1 FAIL: `selection` |
| `came back byte-identical` paragraph above the freeze paragraph | green | 1 FAIL: `byte-identical` |
| `the baseline was green` paragraph above the freeze paragraph | green | 1 FAIL: `baseline` |
| clause `because for several runs…` deleted | green | 1 FAIL: whole paragraph |
| undated, stem-free record in the freeze paragraph | — | 1 FAIL: whole paragraph |
| round 1's record as the freeze paragraph's last sentence | — | 3 FAIL: whole paragraph, dates, `byte-identical` |
| rate re-measure adding a dated sentence | — | 1 FAIL: dates, whose label names the re-measure |
| **named gap:** undated, stem-free record below WHAT A MUTATION IS | — | green |
| **named gap:** undated phrased record below `set -u` | — | green |
| controls: freeze paragraph rewrapped at 60 columns; a trailing blank; `#   ` indent | — | green |

The harness diff against `5017b2b` is now +17 / −0.

## Mistakes, attributed

- **The assistant took the reviewer's framing as its reason to decline in round
  1**, instead of asking which placement mattered most. Its own header had
  already answered that.
- **The assistant wrote the C6 overclaim twice in round 1**: once in the freeze
  paragraph and once in GH-215.sh's header. The review found the first, and the
  assistant's sweep found the second.

## Open

- Not yet reviewed by Bertan. The heads-up on #184 and #158 stands.
- The freeze paragraph is now pinned word for word. So any later edit to it,
  a legitimate one included, has to change the literal in GH-215.sh in the same
  commit.

---

# 2026-09-25 18:11 +03 — #230 review round 3 (rev-agent-215)

Branch `worktree-issue-215-freeze-run-log`. This round's commits are
`cd2467c`, the fix, and this entry. The branch is ten ahead of
`origin/dev-05` (`5017b2b`) once this entry is committed.

The review re-ran its mutants at `5b9b745` and confirmed the round-2 fixes. It
accepted the `d0a910a` sibling. It raised two gating classes and three
non-gating notes. The assistant took all five.

## C9: a fix with no check that fails without it

Round 1 made `comment_reflow` tolerate a trailing blank and a deeper indent,
and made GH-215's two bare lines accept `#` plus blanks. The review reverted
each of the four in a clone of the suite, and every one stayed green. The
assistant's four whitespace mutants had been edits of the harness, which is
whitespace-clean today, so nothing in the suite asked the question. That is a
breach of CLAUDE.md's guard-code rule, and the assistant should have caught it
in round 1: that round's own evidence said the tolerance was proven by hand
mutations and by no check.

The review offered a choice: fixtures, or drop the tolerance. The assistant
chose fixtures. Round 1 measured the tolerance's failure as six false reds, in
the refusing direction, one edit away. The fixtures cost three checks.

- **GH-215's two extractions became functions of the file they read**,
  `r215_below` and `r215_freeze`, still defined in GH-215.sh, which is their
  only calling file.
- **Three checks drive them against literals.**
  - `comment_reflow` is fed `#  a \n#     b\n` and must give `a b `.
  - A fixture harness has bare lines of `# `, `#  ` and `#   `, and a freeze
    paragraph with a trailing blank and an indented line. `r215_freeze` must
    give `FROZEN, a paragraph wrapped and indented ` and `r215_below` must give
    `WHAT A MUTATION IS. The next rule. `.

## C6: three more claims broader than their checks

- **The freeze paragraph**, and its literal in step, now says GH-215.sh holds
  the rest of the header "to how often it says three words the log's records
  are written in; it names the three". The paragraph had said "no run record in
  the words the log's records are written in", and `ran` and `caught` are such
  words too.
- **The date label** called the six dates "none of them a record of a run".
  But two of them are the rate's readings, which GH-215.sh's own header calls
  run records. The label now says "the six ISO dates it carried at #215". The
  entry's text said "so no other paragraph records a run in the words…". It now
  says which record is red: one anywhere outside the log with an ISO date, or
  one in the header in one of the three words.
- **"date" is now "ISO date"** wherever a claim rests on the count. WHAT IT
  DOES NOT SEE names a record dated `On 26 September` as unseen.

## Non-gating notes, taken

- **GH-205.sh's BASH_SOURCE comment** said every call there is defined in the
  same file, so the index is not asked. That stopped being true when this
  branch moved `requirement` and `shape_pin` into the library in round 0. It
  now says the index is asked for those two, and not for `variants_pin`.
- **"twelve times"** for `caught` is now dated at #215, and says "paragraphs",
  since some of the twelve are in history paragraphs rather than rules.
- **The trade now names the literals `6` and `5` as a shared edit point.** Two
  pull requests that each add an ISO date or a `baseline` either conflict on
  the literal, or merge clean at the wrong value and go red.

## Measured

All runs were in `git clone`s, under `env -i`. `cd2467c`: 5,792 ok / 0 FAIL,
three more than round 2's figure. `--list` is identical to round 1's. The
harness diff against `5017b2b` is +18 / −0.

| mutant, at `cd2467c` | FAILs |
|---|---|
| `comment_reflow` without `tr -s ' '` | 2: the reflow fixture, the freeze fixture |
| `comment_reflow` stripping `^# \{0,1\}`, #215's first reader | 1: the reflow fixture |
| `r215_freeze`'s bare line back to `/^#$/` | 1: the freeze fixture |
| `r215_below`'s bare line back to `/^#$/` | 1: the below fixture |
| **the C9 sweep:** the log's last line deleted from the harness | 7, including `outside the log, the header is read to its last paragraph` |

The last row is the assistant's own sweep for C9's siblings. It asks whether
round 1's guard, which checks that the header was read to its end, can fail.
It can. In that run the `selection` `lacks` stayed green, because the
truncated text lacks everything, and that is the case the guard exists for.
The other round-1 and round-2 fixes are driven by the real harness, as the
review measured for case folding.

## Mistakes, attributed

- **The assistant shipped round 1's whitespace fix without a check that fails
  without it**, and called hand mutations of a whitespace-clean file evidence.
- **The assistant's first rewrap of GH-215's text put `written` at the start of
  a heredoc line.** The suite's text-check derivation reads heredoc bodies as
  code, counted it as a 319th text check and called it a bare file name: two
  FAILs. The assistant rewrapped the sentence. The guard worked as designed, in
  the refusing direction.

## Open

- Not yet reviewed by Bertan. The heads-up on #184 and #158 stands.

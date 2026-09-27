# 2026-09-27 · dev-agent-174 — #174: the jq fixture guard asks the farm, not the calling shell

**Written 2026-09-27 20:00 +0300.** Branch `worktree-issue-174-jq-farm-guard`,
cut with `--no-track` from `origin/dev-05` at `abba1d0`. The work is `28b48d0`
and `366147f` (review round 1), plus this entry. The branch is 3 ahead of
`origin/dev-05` and 0 behind it.

## What was done

- **The defect.** The #95 section's jq fixture guard asked
  `$( PATH=<farm>; command -v jq )`.
  - `command -v` resolves a shell function ahead of PATH, and bash imports an
    exported one into the suite.
  - So under an exported `jq` wrapper, the jq-less copy seemed to hold a
    `jq`, and the guard's `exit 1` ended the run.
  - Reproduced at `abba1d0`: the run stopped at the guard after 2036 results.
- **The fix, in `checks/unsplit.sh`.** The guard asks the two directories
  through `farm_has`, which is #155's helper. The two `diff` clauses are
  unchanged.
- **GH-174.1, in `checks/GH-174.sh`.** The guard's own lines are taken from
  the suite text and evaluated in a subshell, where `exit` ends only the
  subshell. They run in three cases:
  - under a `jq` function;
  - with no function;
  - with the jq-less name pointed at the with-jq farm, a control that must
    fail.

  A `holds`/`lacks` pair also pins the text, which is the shape the issue
  asked for. The issue said a guard like this cannot be driven from inside
  the run it would end. In a subshell it can be.
- **GH-174.2.** The issue asked whether every future fixture guard should get
  this reading by derivation. The assistant decided yes. The suite's whole
  text is read, and a line that sets PATH and then asks `command -v`/`-V`
  (any option cluster with `v`) or `type` fails the run.
- **#283, filed, not fixed.** Under the wrapper, the fixed run completes with
  as many results as a plain run, but nine rows differ:
  - Eight are the #95 section's "the refusal names the cause" rows. The
    function reaches the hooks, and `lib/command-scan.sh:288` asks
    `command -v jq`.
  - One is `tokeniser_collisions`, whose child `bash` imports the function.

  The assistant kept this out of #174's scope, following #155's precedent
  for #174 itself. It is listed under the citations that are not
  requirements in `requirements.md`. The spec review found a further site,
  `check-hooks.sh:506-511`, which was added to #283 as a comment.

## Measured

- **Base `abba1d0`, pristine detached checkout:** 6223 ok, 0 FAIL.
- **`366147f`, run alone:** 6234 ok, 0 FAIL, ALL CHECKS PASSED. That is the
  base plus 11 GH-174 rows. This entry adds one row more, because GH-177's
  relabel loop drives one row per dev-log entry.
- **Under an exported `jq` wrapper:** before the fix, the run aborted after
  2036 results. After `28b48d0` it completed with 6235 results, the same
  number as the plain run of that tree. The 10 FAILs were:
  - the nine #283 rows;
  - the #98 row, described under Dead ends.
- **Hand-mutations.** `mutate-hooks.sh` refuses `checks/` as a target. So
  each mutation was a full run in a detached checkout of its own, made with
  `git worktree add --detach` in the scratchpad and removed afterwards. Ten
  runs ran in parallel against `366147f`:
  - M1, the guard back on `command -v`: 5 red. These were both `holds`, the
    `lacks`, the row under a `jq` function, and GH-174.2's row over the suite.
  - M6, the guard range evaluated as `:`: 3 red. These were both `holds` and
    the control.
  - M2 (no `type`), M3 (no blank in the boundary class), M7 (no `(`), M8 (no
    `+=`) and M9 (option exactly `-v`/`-V`): each turned the fixture row red.
  - M4 (comment lines read): the fixture row and the row over the suite.
  - M5 (awk's status ignored): the unreadable-file row.
  - Nine of the ten parallel runs also failed `cs_normalise over one 512 KB
    line`, the unmutated control among them. That is a timing check. The
    tree run alone passes it, so load caused it, not the change.

## Dead ends, attributed

- **The assistant edited files under a running suite.** The first baseline
  run was started from this worktree. The assistant then edited `unsplit.sh`
  and `check-hooks.sh` while it ran. The run reported `unsplit.sh did not
  run to its last line`, among other FAILs. It was discarded as evidence and
  re-run in a pristine detached checkout at `abba1d0`. That a run edited
  under it is not evidence was already a known lesson of these sessions. The
  assistant broke it anyway, by starting the baseline from the tree it was
  about to edit.
- **The #98 derivation.** The assistant first named the new helper's status
  variable `rc`. The #98 self-test reads any function with `rc=$?` as a
  hook-status reader, so it went red. The variable is now `awk_status`, and
  that section's comment names the helper.
- **Generated entries take no blank lines.** The assistant's round-1 notes
  had paragraph breaks. `generate-requirements.sh` refused them, and the
  breaks were removed.

## Review, round 1 (standards and spec, in parallel)

Both axes found the same defect: GH-174.2's first expression was narrower
than its text. It read the question only straight after the first separator,
so these went unread:
- `&&` and `||`
- `if`, `!`, `$(` and `[`
- a command in between
- `PATH+=`
- `command -pv`

The note also called `export PATH=` unread, though it was read. The
assistant had written the text wider than the code. That is the recurring
class `CLAUDE.md` describes: a guard narrower than its prose, with the suite
green. The expression was widened, and the fixture now has fourteen shapes
and eight near misses. The other findings were all fixed in `366147f`:
- mutation cases deferred to this entry, now in each note;
- "establishes" claimed of a hand measurement;
- a count in the #98 comment;
- the helper name `farm_asked_of_shell`, now `path_lines_asking_shell`.

## Open

- #283: whether the hooks, or only the suite, should stop trusting
  `command -v` for `jq`. Fixing the suite alone would hide the hook half.
- The pull request into `dev-05` is not opened by this session unless asked.


# 2026-09-27 23:15 +0300 · dev-agent-174 — #174, review round 2: rev-agent-174's first round on PR #294

**Written 2026-09-27 23:15 +0300.** Branch `worktree-issue-174-jq-farm-guard`.
Round 2 is `983baad` (code) and `c6050cb` (notes and comments), plus the commit
carrying this entry. The branch is 6 ahead of `origin/dev-05` and 0 behind.
"Round 2" counts from the entry above, whose round 1 was the internal standards
and spec review. On the pull request this is rev-agent-174's round 1.

## What the review found, and what was done

- **G1, gating: GH-174.2 narrower than its note again.** The note said a
  question in a payload handed to a child shell was read. It was not: `'` and
  `"` were not in the boundary class, and a child shell's payload is where an
  exported function is imported. `\command -v` and `command -p -v` went unread
  too. The reviewer's mutant mA, both shapes inserted into `checks/unsplit.sh`,
  ran green. The assistant widened the code rather than the text: the class
  takes both quotes and a backslash, and any option words may precede the one
  holding `v`. The expression now goes to awk through `ENVIRON`, since `-v`
  would take the class's backslash as an escape. Each shape is a fixture row,
  and so is `declare PATH=`/`local PATH=`.
- **N1: the hand-written unread list was wrong a second time.** It named
  `declare` as unread, and `declare` and `local` were both read. The list is
  now a second fixture, `r174-gaps.sh`, whose row expects every line unread.
  So the note's list is a check: a derivation widened to read one of its lines
  turns that row red. The assistant probed each candidate before it went on the
  list. `hash jq` and `compgen -c jq` both answer for a function under a
  jq-less PATH, so the note's `hash among them` stood. `declare`, `local` and
  `export` came off.
- **N2: "nine rows" depends on the wrapper's body.** Round 1 did not record
  which wrapper it ran, and the assistant cannot now say which it was.
  Re-measured at `c6050cb`: nine FAIL under `jq() { command jq "$@"; }` and
  nineteen under `jq() { /usr/bin/jq "$@"; }`, the reviewer's own. The extra
  ten are `want=BLOCK got=ALLOW`: each hook's *jq not on PATH* row, plus the
  same pytest and the same alembic. The function keeps jq working under the
  jq-less PATH, so the hooks parse and permit. Both figures are now in
  GH-174.1's note, in the `requirements.md` #283 entry and in the PR body.
  The entry above keeps its "nine", since it is history. This entry is the
  correction.
- **N3: an assertion no mutation reached.** The row that showed the shell
  had a `jq` function never changed PATH, and it ran in a different `$( )`
  from the row it vouched for. The two are now one row. It prints what the
  shell calls `jq` under the jq-less PATH beside the guard's result, and it
  expects `function passed`. Taking the function's definition out turns that
  row red, and it alone.
- **N4, declined in part.** The reviewer said `type -P` and `type -p` are both
  function-blind. The assistant probed both. `type -P` is. `type -p` is not:
  under a `jq` function it prints nothing even when the PATH holds a jq. So
  `type -p` is a real question to the shell, and reading it is correct.
  `type -P` stays read, as a stated trade in the note and as fixture line 23:
  the rule asks the directory, and the correction is one edit.
- **N5: a list in a comment that nothing reads.** The #98 comment now states
  the convention, a status named after its tool rather than `rc`, and lists no
  functions.

## The assistant's own sweep, beyond the findings

The assistant swept each class over the whole diff, and three more claims
turned out wider than the code:
- the GH-174.sh header said a line failed "wherever it stands", but it is read
  on one line and in GH-174.2's shapes only;
- the N3 comment said `r174_shadowed` asks "the one question in the suite"
  meant for a function, but the `command -v cs_*` probes are others;
- the `lacks` label said the guard "asks the calling shell nothing", with one
  needle, `command -v`.

The needle is now `command -`, and the note says the text's "nothing" is held
by the driven row: any question a function answers makes the guard fail
there. The no-file row had no measured mutation, and it now has one.

## Measured

All runs used mawk 1.3.4, each a full `check-hooks.sh` run in a detached
checkout of its own under the scratchpad, four at a time.

- **`c6050cb` plain:** 6235 ok, 0 FAIL, ALL CHECKS PASSED. That is the same
  count as `c678763`: one row merged away under GH-174.1 and one gap row added
  under GH-174.2. This entry is an append to an existing file, and GH-177's
  loop drives one row per file, so it adds none.
- **Under the wrappers, at `c6050cb`:** 6226 ok and 9 FAIL with
  `command jq`; 6216 ok and 19 FAIL with `/usr/bin/jq`.
- **Mutations at `983baad`:**
  - each quote, the backslash, and the option-word prefix removed from the
    expression: the fixture row, each time;
  - `hash` read as a question: the gap row, and the suite row, on the gap
    fixture's own literal `hash` line. No other line of the suite sets PATH
    and says `hash`;
  - the reviewer's mA: the suite row;
  - m1, the guard back on `command -v`: the same five rows as round 1;
  - the function's definition removed from the merged row: that row.
- **At `c6050cb`:** M6 (the guard range as `:`) gave the same three as round
  1. Deleting the no-file guard gave that row alone.

## Dead ends, attributed

- **The assistant's harness leaked #283's class into its own evidence.** The
  first wave's driver ran `export -f` on its two helpers so that `xargs` could
  call them. The suite's `tokeniser_collisions` child `bash` imported them, so
  its *defined nothing* row failed in every run of that wave, the plain one
  included. So the first plain run read 6234 ok and 1 FAIL. The mutation
  results stand, because each named its own rows beside that one. The final
  wave unsets the helpers before starting the suite, and its plain run is
  clean. So the harness gave an unplanned second demonstration of #283:
  every exported function reaches every child shell the suite starts.
- **Round 1 did not record the wrapper's body**, which is how N2 arose. A
  measurement under an injected function is only reproducible with the
  function written down.

## Open

- #283, unchanged: it holds both wrapper figures and the reviewer's
  `unsplit.sh:5180` git-shim hang.
- Review of round 2.


# 2026-09-27 23:55 +0300 · dev-agent-174 — #174, review round 3: rev-agent-174's second round on PR #294

**Written 2026-09-27 23:55 +0300.** Branch `worktree-issue-174-jq-farm-guard`.
Round 3 is `edf6a95` (the rows) plus the commit carrying this entry, which also
holds a note sentence and the round's mutation record. The branch is 8 ahead of
`origin/dev-05` and 0 behind. Nothing in this round gated. The reviewer offered
three optional nits, and the assistant took all three.

## What was done

- **R2-a: the gap fixture held `hash` and `compgen -c` as literals.** The
  comment above the fixtures says every asking word is held in a variable, so
  that no line of the file is one the derivation reads. With `hash` literal,
  round 2's `hash` mutant also reddened the suite row, on the fixture's own
  line. Both words are now variables. The same mutant now reddens the gap row
  alone.
- **R2-b: `r174_shadowed` was in the multi-line gap shape without needing to
  be.** It set `local PATH` on one line and asked `type -t jq` on the next. A
  function answers `type -t` whatever PATH holds, so the PATH carried nothing.
  The helper is gone. The row asks `type -t jq` inline, and no line of
  `GH-174.sh` outside a fixture string sets PATH.
- **R2-c: defined versus imported.** The note argued that a function defined
  in the evaluating shell stands in for one imported from `BASH_FUNC_jq%%`,
  and no row showed it. One row now takes the host's route. `jq` and
  `farm_has` are exported, along with the farms' names, and the guard is
  evaluated in a child `bash` that prints what it imported beside the result.
  The exports stay inside the `$( )`. The row expects `function passed`.
- **The assistant's sweep of its own delta** found one more claim that the
  code does not bear out. The new note said "most rows define the function",
  when one does, one imports it, and two unset it. Corrected in this entry's
  commit.

## Measured

Full runs in detached checkouts, five at a time, with mawk 1.3.4, at
`edf6a95`:
- plain: 6236 ok, 0 FAIL. That is one row more than `a8aabf6`, the import
  row;
- m1, the guard back on `command -v`: six red, round 2's five plus the import
  row;
- the function's definition removed from the defining row: that row alone;
- `export -f` taken off `jq` in the import row: that row alone;
- `hash` read as a question: the gap row alone.

Before the full run, a standalone probe of the import row printed
`function passed`, and `file passed` with `jq` not exported.

## Open

- #283, unchanged. The reviewer is adding `checks/GH-144.sh:698`, a second
  `REAL_GIT` shim that hangs under an exported `git` function.


# 2026-09-28 00:43 +0300 · dev-agent-174 — #174, review round 4: rev-agent-174's third round on PR #294, and the base moved

**Written 2026-09-28 00:43 +0300.** Branch `worktree-issue-174-jq-farm-guard`.
`origin/dev-05` moved from `abba1d0` to `cd67c8e` (#186). This round is the
merge `7f87cc8`, then `ddc1a5e`, plus the commit carrying this entry. The branch
is 0 behind `origin/dev-05`.

## What was done

- **The merge.** It had one conflict, `SUITE_CHECKS` in `check-hooks.sh`,
  where both sides appended an issue file. The assistant resolved it to
  `… GH-219.sh GH-186.sh GH-174.sh`, the resolution the reviewer had verified.
  The assistant grepped for other lists of issue files that could merge clean
  and stay stale, and found none. It also checked that the derivation reads
  no line of the incoming `GH-186.sh`.
- **G2, gating: GH-174.2 was wider in its text than in its read.** This is
  the third time for this requirement. The text said "the driver and every
  file it sources". But the row reads `SUITE_FILES`, which is the driver and
  `checks/`. The driver also sources `lib/command-scan.sh`, and the reviewer's
  mutant, a question appended to that file, ran green. The assistant narrowed
  the text rather than widening the read. That file is hook code, and what it
  asks about `jq` is #283's. The note says so.
  The assistant then swept this class over the whole diff and found two more
  claims of the same scope: the header ("the whole suite's text is read … in
  whichever file it stands") and the suite row's label ("no line of the
  suite"). Both now name the driver and `checks/`.
- **R3-a.** The header's *WHAT IS DRIVEN* paragraph now names the import
  row, and the PR body says "four ways".
- **R3-b.** A question inside the command substitution that computes PATH's
  new value is read, although it runs before PATH changes. It is now a
  stated trade in the note and fixture line 24, so there are 24 read lines
  and 11 near misses. The count guard compares with `-eq`, as the reviewer
  suggested for that line.
- **R3-c, a correction to the round-2 entry.** That entry said "Round 1 did
  not record the wrapper's body". That is passive about an error. It was the
  assistant that ran the round-1 wrapper measurement and did not write the
  wrapper down.

## Dead end, attributed

The assistant first wrote R3-b's note sentence with the shape quoted
literally. That made the requirement heredoc itself a line the derivation
reads. A standalone run of the derivation over the suite named
`GH-174.sh:136` before any full run. The sentence now describes the shape,
and the literal lives only in the fixture.

## Measured

Full runs in detached checkouts, with mawk 1.3.4, at `ddc1a5e`:
- plain: 6239 ok, 0 FAIL. That equals the reviewer's figure for `b738942`
  merged into `cd67c8e`, and it is the base's 6226 + 13. The round-4 edits
  changed no row count: line 24 went into an existing row's fixture, and the
  label change is a relabel;
- m1, the guard back on `command -v`: the same six rows as round 3, the
  relabelled suite row among them.

## Open

- #283. It now also carries the reviewer's `checks/GH-144.sh:698`, the
  second `REAL_GIT` shim.

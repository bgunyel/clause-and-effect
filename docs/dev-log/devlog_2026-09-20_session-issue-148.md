# 2026-09-20 · session issue-148 — the four counts the harness restated, and the two it never derived

*Opened 2026-09-20, closed 2026-09-20 20:29 +03. The opening sections below were
written before `docs/dev-log/README.md` gained its current conventions, which
arrived on this branch with #169's merge in round five; the header is brought
into line here rather than backwards through the entry.*

**Branch** `worktree-issue-148-derive-the-counts`, for a pull request into
`dev-05` (PR #183). Cut from `origin/dev-05` at `2a52322`; the base moved to
`7bea85f` mid-review when #169 landed, and the branch ends **four commits plus a
merge ahead of `origin/dev-05`**. Worked unattended by an AI assistant, over
five review rounds by Bertan.

**Check suite 5093 → 5306 results, all passing** — of which the growth from 5106
is #169's, not this branch's. Figures below are measured unless marked
otherwise. A new requirement, `GH-148`, carrying seven checks when it was first
written and ten by the end. **This branch registers no mutation row**: the
registry held 54 when the branch was cut and holds 67 now, and all thirteen of
those are #169's. `check-hooks.sh`'s `#107` literals — the registry size and the
three outcome counts — are untouched, which is the point of the issue rather
than an omission; a fourth literal, the self-test total, was added in round
three because the review measured that nothing held it.

## What #148 asked for

`mutate-hooks.sh`'s header argued, three paragraphs above the offence, that a
count restated in prose is the thing #107 was filed about, and then restated
four: how many real mutations, against how many files, naming how many
requirement IDs, of how many requirements active. A fifth sat in the timing
paragraph — how many runs a whole-registry pass costs — and the rough runtime
was written out in four more places.

None of them was read by anything. They had been wrong or had moved six times in
three days before the issue was filed and eight times more while #139 was open,
and every one of those states was green: Bertan's review of PR #147 ran the suite
with `THIRTY-EIGHT requirement IDs … of the 156` in the header against a registry
holding 39 and 157, and nothing turned red.

## What was built

`bash .claude/hooks/mutate-hooks.sh --list` gained two figures it never derived —
how many requirements `requirements.md` holds active, counted by distinct ID, and
how many runs a whole pass costs, which is the baseline plus one per row whose
edit is expected to apply and therefore *not* one per row. The header now states
none of the five counts and points at `--list` where they stood. `CLAUDE.md`,
`GH-107.2`'s note and `docs/todo.md` stopped restating the runtime, which one
`written` pin in `check-hooks.sh` holds alone.

The distinction the issue asked to be written down is recorded in three places —
the harness header, the `#107` section of the suite, and `GH-148`'s note: **a
literal in a check earns its maintenance, because it goes red when the thing it
counts moves; a number in a comment earns nothing, because nothing reads it.**

Neither new check carries a number of its own. An active-requirement literal in
`check-hooks.sh` would move with every requirement filed, which is this issue
recreated one directory over; each figure is compared against a derivation the
suite makes for itself instead.

## The evidence, and the two defects the evidence found

Reverting `mutate-hooks.sh` to its `origin/dev-05` version turns all seven new
checks red, and restoring it turns them green. That was run three times, once
per round of fixes, and the checksum of the restored file was compared against a
backup taken before each revert.

The first of those runs is the part worth recording, because the assistant had
written the pins and reasoned they were right. **Three of four went red and one
stayed green.** The phrase it looked for, `fifty-four runs as the registry
stands`, wrapped in the old header between `as the` and `registry stands`, so
`grep -F` could not see the text the check exists to forbid. A guard weaker than
its own prose, found by running the revert and not by reading the code. The pins
are now asked of the header reflowed onto one line, because a comment's line
breaks are a wrapping decision and no part of what it says.

The second came from the review pass and is the same shape one level up. The
guard on that reflow asked only whether `ABOUT AN HOUR` was in it — text from the
header's *first* paragraph. Any truncation below line 18 left the guard green and
the four absences genuinely vacuous, an absence being what a truncated file has
most of. The region is now bracketed, a marker from its first paragraph and one
from its last, and a probe confirmed the single-marker version passed the case
the bracketed one refuses.

Two smaller findings from the same review were taken:

- the suite's active-requirement awk matched the status line byte for byte while
  the registry audit twenty lines above it read the same field tolerantly. Two
  parsers in one file disagreeing about what `active` means is a defect waiting
  on a trailing space, and this one was the stricter — so an entry the audit
  still counted would have dropped out of *both* new counts at once, silently
  and equally, which is the one way a comparison of two readings of one rule can
  be green and wrong. Both now read it as the audit does.
- the commit whose subject is that a count in a comment earns nothing had added
  one: `the baseline green over 183 requirements`, in the run record for this
  issue. It also read as the active count and is not one — 183 is entries by ID,
  166 are active. Removed.

## What these checks are not evidence of

The two derivations compared by the `tok` checks are the same program written
twice, so what goes red is the harness drifting from the suite — the figure
dropped, renamed, spelled off a constant, counted by line instead of by ID. A
defect the two share agrees with itself. Three readings were compared by hand
when this landed, including a third pairing headings to statuses through
`sort -u`, and all three answered 166; that was a measurement and this is a
check, and `GH-148`'s note says which is which.

The four absence pins are evidence about the four spellings they name and about
nothing else. A count written some other way is out of their reach. What holds
the positive half is the `written` pin on the pointer that now stands where the
counts did.

No row was added to the mutation registry, and none could be: the rule is code
in `mutate-hooks.sh`, which is `$TOOLING`, and what that code reads is the
`requirements.md` beside the harness rather than a file an override moves — so
`GH-141`'s exception does not apply and this is `GH-107.2`'s first limit exactly.
`selftest-anchor-that-matches-nothing` was run alone to say the harness still
starts: baseline green, the row `did-not-apply` as it declares, `.claude/hooks/`
byte-identical after. That is evidence that the file still runs and about nothing
else.

## Incidental

The worktree's own `.venv` was missing the `migrations` group, so
`tests/test_environment_sync.py` failed on a tree that had not been touched by
this work. `uv sync --all-groups` repaired it; `make test` then passed at 596
passed, 5 xfailed. No Python was changed by this branch.

## Round two — Bertan's review of PR #183

Seven findings, all correct, all taken. **Check suite 5100 → 5103 results, all
passing.** `GH-148` grows from seven checks to nine; `GH-107.2` gains one.

**The two blocking findings were the issue's own thesis failing on the number
the branch had just made load-bearing.** The assistant had removed the runtime
from `CLAUDE.md`, `docs/todo.md` and `GH-107.2`'s note and pointed all three at
the harness's header — where `ABOUT AN HOUR` was still written. That figure was
right at twenty-three runs and had never been re-derived as the registry grew
past fifty: at the rate the same paragraph records, a pass is about 112 minutes.
So the branch reduced a stale number from five copies to one, and made the one
authoritative.

The second finding is why that could happen. The `written` pin on
`ABOUT AN HOUR` had been classified — in this branch, in the sentence that draws
the distinction — as a literal in a check, the kind that earns its maintenance.
It was not. It asserted a string was present; it could never go red when the
number stopped following from anything. **The one literal the branch classified
as safe was the one that had already rotted.**

Both are fixed by deriving it. `MEASURED_SECONDS` and `MEASURED_RUNS` carry the
dated 2026-09-17 measurement as two numbers instead of a rounded magnitude,
`--list` multiplies them by the run count it derives, and the header states no
magnitude at all. What the suite pins now is the absence of one, the sentence
saying the harness is slow enough that nobody runs it, and the product against
its own multiplication.

That last check does **not** go red when a row is added — both sides are derived,
so both move and go on agreeing, which is exactly why the figure needs no
maintenance. What it catches is the harness ceasing to multiply. Measured:
replacing the computed minutes with a literal `60` turns it red, naming both
numbers. What forces a human to look when the registry grows is the `54` literal
that was already there.

The other five, each measured rather than argued:

- **Two readers of `requirements.md` were not section-aware.** A stray
  `- status: active` outside the three sections that hold entries was attributed
  to whichever `### ` heading was last seen. Measured on a doctored copy: the old
  reader answers 167, the new one 166 — and *both* copies had the defect, so they
  agreed and were wrong together, which is the one failure the branch's own
  comment says a doubled program cannot find. Both are section-aware now, and a
  third check holds the suite's count to what `REQUIREMENTS_AWK`, the canonical
  reader, makes of the same file. The chain ends somewhere that is not a copy.
- **The run count included rows a pass refuses.** It asked only about
  `did-not-apply`, not about the five reasons pass one drops a row. The five now
  live in one `row_fault` function that pass one and `--list` both call, so the
  prediction and the run cannot disagree. Measured: a row targeting
  `check-hooks.sh` moves neither the run count nor the minutes; a well-formed row
  moves both, 54 → 55 runs and 112 → 114 minutes.
- **`CLAUDE.md` misdescribed which numbers live in two places** — it named the
  registry's size as unique to the suite, when the size is on `--list` *and*
  pinned as a literal. Rewritten: `--list` derives every count, several are also
  literals in checks, and that duplication is the point.
- **`CLAUDE.md`'s "two of its rows are self-tests"** was re-raised because
  `GH-148`'s text claimed `--list` was "the only place". Bertan's failure
  scenario — a third self-test registered, `--list` says three, `CLAUDE.md` still
  says two, suite green — was measured and is **not reachable**: registering a
  third turns two literals red. So the sentence stays and `GH-148`'s wording was
  narrowed instead, which is the resolution his note offered for that case.
- **A suppressed `2>/dev/null`** turned every distinct refusal from `--list` into
  one "printed nothing" message before aborting the suite. Stderr is captured and
  reported, and the exit status is read.

One thing the review did not raise, found while answering it: the reflow guard's
first marker was a prose sentence, and a guard aborts the whole suite rather than
failing a check — so rewording that sentence would have stopped the run with a
bare message instead of failing the pin that already asks for it. It is anchored
on `#!/bin/bash` now, which is structural and does not move with the prose.

Reverting `mutate-hooks.sh` to `origin/dev-05` turns all ten new checks red;
restoring it turns them green. `mutate-hooks.sh -v` on both self-tests reports
what they declare through the refactored pass one, `.claude/hooks/`
byte-identical after.

## Round three — the second review of PR #183

Seven more findings. Four of the previous round's fixes verified as holding, and
the counter-measurement on the self-test count was accepted and that finding
withdrawn. **Check suite 5103 → 5106 results, all passing.**

**The headline defect was the assistant's own, reintroduced.** Round two moved
four absence pins off `$MUT` and onto the reflowed header, because `grep -F`
cannot see a phrase that wraps between two comment lines. The *same commit* then
added `unarmed … "$MUT" 'ABOUT AN HOUR'`, reading the raw file. Measured on a
doctored copy with the wrap falling inside the phrase: the raw-file pin sees 0
occurrences, the reflowed pin sees 1. It was the repaired defect, put back by the
repair.

The fix is the class rather than the instance. `$MUT_PROSE` is now built above
`$MUT`'s first consumer, and every pin on the header's *prose* reads it — seven
of them, including two that predate #148 and were wrap-blind all along. Pins on
the harness's *code* keep reading `$MUT`, because code is below `set -u` and is
not in the reflowed region. The rule is one sentence in the file now, which is
what was missing when one pin could be added on the wrong side of it.

**The runtime, which is the half #148 did not fix.** Bertan timed two direct
suite runs at 196–231 s against the 124 s the branch published, and pointed out
that "staleness is no longer possible" was false of the rate. The assistant
re-measured the quantity the harness actually pays — a run against a copied tree,
under `CHECK_HOOKS_DIR`, in `--matrix` mode — and got **275 s, 235 s, 205 s**.
That is worse than his figure, so his stated caveat about method resolves against
the old number rather than for it. There was no case to push back on.

So the rate is now a directly measured per-run figure, dated, carrying the size
of the suite it was taken at; a check goes red once the suite has grown a quarter
past that. What it cannot see — the machine changing under a suite that stayed
the same size — is written beside it. `--list` now says about 248 minutes, not
112. The claims in `CLAUDE.md` and `GH-148`'s note are narrowed to match: the run
*count* needs no maintenance because it is derived; the *rate* is a measurement
and goes stale on its own.

The other five:

- **Five runtime magnitudes elsewhere in the tree**, all saying `95 s` while the
  constant beside them said 124 s. Removed, and their absence is now pinned in
  the reflowed header. (The review counted six; one of the three it cited in
  `check-hooks.sh` is a `#95` issue citation rather than a figure.)
- **`CLAUDE.md`'s "a third cannot be registered without two checks going red"
  was false.** Relabelling an existing `caught` row's id to `selftest-*` leaves
  the row total and all three outcome totals where they were. Measured: `--list`
  reported `51 real mutations … 3 self-tests` with every pin green. The
  self-test total is now pinned as a literal — the one place in this section
  where a literal is the right instrument, because the real/self-test split is
  exactly what a reviewer of a registry change should see move. Re-measured with
  the pin in place: red, `want |2| got |3|`.
- **The bracket guard's first marker could not fail.** `sed -n '1,/…/p'` always
  starts at line 1, so a shebang is present whatever happens to the header — dead
  weight dressed as half a guard. What can actually go wrong is the terminator,
  so that is what is asked now, structurally. And the guard reports a failed
  check instead of aborting the suite, with the pins it would have made vacuous
  skipped rather than run green beside it.
- **The run count can still be one too high**, for three pass-two cases `--list`
  cannot see without copying the tree and applying the edit — including a row
  declared `caught` whose anchor has rotted, which is the case the header claimed
  to model. The claim is narrowed in both files rather than papered over.
  Teaching `--list` to apply each edit would answer it properly and is its own
  issue.
- **A `2>/dev/null` on the new `ACTIVE` awk**, in the commit that fixed the same
  mistake one file over. Removed.

Findings 4, 5, 6 and 7 were offered as deferrable to a follow-up issue. All four
were taken, because all four were in code this branch introduced.

## Round four — the third review, done as a class sweep

Bertan reviewed by **class** rather than by instance this time, sweeping every
line each previous finding's class could apply to and reporting the sweep. Eight
classes; five came back clean on measurement rather than on reading, and the
round-two fixes were verified by re-running rather than by reading the diff.
**Check suite 5106 results, all passing.** Three findings, all of them words in
this branch's own diff, and one filed elsewhere.

The three, each a count or a date that nothing falsifies — in the branch whose
subject is counts that nothing falsifies:

- **`GH-148` enumerated five literals and called them "the four of those"**, and
  `d86223b` — the commit that created the fifth by taking round three's
  self-test pin — is where that clause was written. The sentence was composed
  listing the new pin and counting as though it were absent. Fixed by deleting
  the count rather than correcting it: the enumeration says the same thing and
  cannot disagree with itself.
- **`check-hooks.sh` dated the rate 2026-09-17** while the constant it reads is
  dated 2026-09-20 three lines into the other file — three days stale in the
  commit that re-dated the measurement. The date is no longer restated; it
  stands beside the constant, where re-measuring moves both.
- **`--list`'s own output line still carried the un-narrowed claim.** Round three
  narrowed the header and `GH-148` to say the run count is a prediction off the
  table, then left the line a person actually reads saying `plus one per row
  whose edit applies`. The caveat was in the two places nobody looks and missing
  from the one they do. It now says `at most` and names what only a run can see.

**The fourth finding is the wrap-blind class outside this branch, and it is not
fixed here.** Two absence pins still grep raw files — `GH-70.3` over `SKILL.md`,
`GH-99.1` over `check-hooks.sh`'s own comments. The assistant reproduced it
rather than taking the report: re-adding the count `GH-70.3` exists to forbid,
wrapped the way `SKILL.md` already wraps, gives `grep -cF` 0 against 1 for the
flattened text, and the full suite returns **`ALL CHECKS PASSED`, zero FAIL
lines**, with the forbidden count standing in the file. `SKILL.md` was restored
and its sha256 verified.

What makes it worth its own issue rather than a footnote: `flatten()` already
exists at `check-hooks.sh:6506`, and the comment directly above it states the
class from an earlier discovery. `GH-70.3` sits thirty lines below that helper
and does not call it. This branch's `$MUT_PROSE` is the **third** independent
rediscovery of the same class in the same file. Filed as #192, with the
reproduction and `flatten()` as the fix. #193 carries the `--list`-applies-each-
edit change, which was deferred by agreement because it changes what `--list`
is.

The shape of this round is worth recording on its own. Rounds two and three
produced seven findings each, which is what reviewing by instance yields; round
four swept eight classes and found three words and one pre-existing defect. The
assistant's own round-three reply had named the reason — *"I fixed the instance
instead of the class"* — and the review applied that method to the rest.

## Round five — the conflict this issue was filed about, arriving

PR #169 (issue #109) merged into `dev-05` mid-review, moving the merge base from
`2a52322` to `7bea85f` and putting all four of this branch's files into
conflict. **This is the three-way conflict #148 predicts in as many words**, and
it is worth recording because it behaved exactly as the issue said it would.

**#169 reached half of this issue independently, from the other side.** Its
second review found the harness heading saying one total while the paragraph
under it said another and `check-hooks.sh` pinned the first — so #169 changed
the heading from a total to a *rate*, on the reasoning #148 rests on: a total
goes stale every time a row is registered and a rate does not. It went further
and pinned the figure's second copy in `CLAUDE.md`, because a sentence in
`requirements.md` claimed the two moved together with nothing enforcing it.

This branch answers the same thing one step on: there is no second copy to pin.
The magnitude is on `--list`, multiplied out of a measured rate; `CLAUDE.md`
points at it. So #169's `CLAUDE.md` pin was dropped in the resolution, and the
reason is written where it stood.

**What was re-derived rather than taken from a side**, which is the whole
instruction #148 gives for this conflict:

| value | this branch | dev-05 | merged, derived |
|---|---|---|---|
| registry rows | 54 | 67 | **67** |
| caught | 52 | 65 | **65** |
| survived / did-not-apply | 1 / 1 | 1 / 1 | **1 / 1** |
| self-tests | 2 | — | **2** |
| text checks | 298 | 292 | **298** |
| active requirements (prose, dev-05) | — | 170 | **171** |

Every one was derived from the merged tree with a script written for it, and
then checked against what the suite derives. The last row is the point of the
issue in one line: dev-05's header prose said `of the 170 whose status is
active`, and the merged tree holds **171**, because this branch added `GH-148`.
Neither side's number was right, and both sides' text would have merged clean.
`--list` derives 171 and nothing restates it.

**Two things the conflict markers could not show**, found by sweeping the whole
tree for every value either side carried:

- The assistant folded #169's finding into the harness header and quoted the
  old magnitude while doing it — inside the reflowed region, where this branch's
  own absence pin forbids exactly that string. The pin would have gone red; the
  sweep found it first. The paragraph now records what #169 found without
  spelling either figure, and says why. The header had a sentence warning about
  precisely this trap, written two rounds earlier, and it was still walked into.
- `MEASURED_AT_RESULTS` looks like a value to re-derive and is not. It is half
  of a measurement record — the suite's size when the rate was taken — so
  updating it without re-measuring would move the staleness check's baseline
  instead of answering it, which is silencing a check rather than satisfying it.
  The rate was re-measured against the merged tree instead, the way the harness
  pays for a run: **274 s, 250 s, 266 s**, all under the 275 s already recorded.
  So the rate itself does not move — #169 added about 200 check results without
  making a run slower — and `MEASURED_AT_RESULTS` moves to 5296 because a
  measurement was taken at that size, not because the tree grew.

The `$MUT` / `$MUT_PROSE` rule was re-checked against the merged tree rather
than assumed to survive: every one of the 17 remaining `"$MUT"` pins resolves to
a line at or below `set -u`, so all of them are code and none is header prose.
#169 added no pin on the harness.

## What is still open

- **#192** — the wrap-blind class outside this branch. `GH-70.3` and `GH-99.1`
  grep raw files, and the false green was measured end to end: the count
  `GH-70.3` forbids can stand in `SKILL.md`, wrapped, with the suite reporting
  `ALL CHECKS PASSED`. `flatten()` already exists thirty lines above `GH-70.3`.
  Filed rather than fixed here, because widening a scoped change into
  `SKILL.md` is how it stops being reviewable.
- **#193** — making `--list` apply each row's edit, so the run count is exact
  rather than an upper bound and a rotted anchor surfaces in a second rather
  than after a whole pass. Deferred by agreement: it changes what `--list` is.
  Four questions are written into the issue, of which one is the trap — the
  `#148` run-count check compares two derivations, so if `--list` starts
  measuring, the suite's side must measure too or the check has to become
  something else.
- **The rate is a measurement and will go stale again.** Nothing in this
  repository can derive it. The staleness check fires when the suite outgrows
  the size it was taken at by a quarter; it cannot see the machine changing
  under a suite of the same size, and that is written beside it.
- **No whole-registry pass has been run on the merged tree**, and the harness
  header says which selections have and have not been exercised since the files
  under them changed. This branch changes no hook and no registry row, so it
  adds nothing to that debt, but it does not discharge it either.

## For the next session

The branch is PR #183 into `dev-05`, green and merged up to `7bea85f`. If
another dev-branch merge lands before it does, the same re-derivation applies:
every count in the table above comes off the merged tree, never off a side, and
the sweep for values both sides carried identically is the half that conflict
markers cannot do.

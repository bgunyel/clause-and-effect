# 2026-09-20 · session issue-148 — the four counts the harness restated, and the two it never derived

**Branch** `worktree-issue-148-derive-the-counts`, cut from `origin/dev-05` at
`2a52322`, for a pull request into `dev-05`. Worked unattended by an AI
assistant. **Check suite 5093 → 5100 results, all passing.** A new requirement,
`GH-148`, with seven checks. The mutation registry is unchanged at 54 rows, and
`check-hooks.sh`'s `#107` literals — the registry size and the three outcome
counts — are untouched, which is the point of the issue rather than an omission.

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

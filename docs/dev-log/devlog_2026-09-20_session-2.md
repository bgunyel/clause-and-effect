# 2026-09-20 · session 2 — #155 round three: the fix for prose-over-guard, twice more

**Branch** `worktree-issue-155-stub-gh-into-farm`, the branch of PR #161 into
`dev-05`. Worked unattended by an AI assistant, answering a third review of that
pull request by a separate AI session. One finding, graded medium, and it was
correct. **Check suite 3807 → 3810 results, all passing.** `GH-155.1` grows from
sixteen checks to nineteen. No new requirement, no new registry row.

The finding is worth stating before the fix, because the fix produced two more
of the same thing and that is the part worth keeping.

## The finding

Session 1 widened the `report_says` derivation from `^report_says "` to
`^[[:space:]]*report_says "` and headed it

```
# READ ANYWHERE ON A LINE AND NOT ONLY AT COLUMN 0
```

which is not what the pattern does — it reads at a line start with indentation
allowed. And the comment named, as the evidence that the indented shape is real,
`drive_helper`'s `case` arm:

```
         report_says) report_says "$PATH" "$EXITS/$fixture.sh" "$fixture" 'self-test' ;;
```

That line is **not matched by the pattern**. At the one anchored position the
text reads `report_says)` — the case label — and not `report_says "`. Measured:

```
$ sed -n '8245p' check-hooks.sh | grep -o '^[[:space:]]*report_says "[^"]*"'
(no match)
```

So the comment cited as its evidence the one line its own code could not read.
Nothing was false-green — that line names `$PATH`, already in the literal-of-four
— and the defect is entirely that the prose was stronger than the guard, which
is the shape session 1 had just fixed twice. Arriving inside the fix for it.

## The remedy, and why (a) rather than (b)

The reviewer offered both and expressed no preference: **(a)** widen to call
positions and keep the heading, at the cost of a filtering step, or **(b)** keep
the pattern and correct the heading down to what it does.

(a), because the trap the reviewer named is avoidable by construction rather
than by filtering. The trap: broadening to include whitespace as a separator
pulls in the `echo` that writes the fixture and injects `$WITH_JQ_BIN` — the
farm — into the real derivation. But whitespace does not have to be a separator.
The positions a call can occupy are nameable:

```
grep -oE '(^|[;&|)]|[[:space:]](then|do|else))[[:space:]]*report_says "[^"]*"'
```

Line start with any indentation; after `;`, `&`, `|` or `)`; after `then`, `do`
or `else`. That reads the `case` arm — the `)` — and reads
`if ...; then report_says "$WITH_JQ_BIN" ...`, the other shape the reviewer
named as invisible. It does not read a `report_says "` inside a quoted string,
because the character before such a one is a quote or a space, neither of which
is a separator.

And the fixture is now written through a variable holding the helper's name, so
this file carries no `report_says` of the fixture's own in any position at all.
Keeping it out of the match by the quote that happens to precede it would have
been resting on a spelling — which is what the round before this one was about.

**What the derivation still cannot read**, named in the comment rather than left
to be found: a call whose command word is a variable. No reading of the text can
see `$DRIVEN_REPORT "$WITH_JQ_BIN"`. That shape is not in this file —
`DRIVEN_REPORT` names the helper for the drive loop and the `case` arm is where
it becomes a call, which is why covering the case position covers that route
whole.

## Two more of the same defect, produced while fixing it

**The comment's own example is read as a call.** The new comment quotes the
`case` arm to explain why the `)` position is in the set. That quoted line
contains `) report_says "$PATH"`, so the derivation matches it: it is one of
the twelve lines matched in this file, and it is a comment.

The first instinct was to strip comments before matching. That was rejected on
the direction. A comment can only **add** a PATH to the derived set, never hide
a call from it, so the property the check exists for — that no run under the
farm goes unseen — survives, and a comment that named the farm would turn the
check red until reworded, which is a nuisance in the safe direction. Stripping
comments buys the tidier claim at the price of the unsafe one: the strip cuts at
the first `#` on a line, so a line carrying one before a call would lose the call
and the check would go quietly **green**. The quirk is written down and pinned by
a check instead — a fixture with a commented call at the line-start position,
which is not read, and one at a separator position, which is.

**And the paragraph explaining the whitespace exclusion planted a thirteenth
match.** The first draft of it wrote out the hazard verbatim —
`echo '  report_says "$WITH_JQ_BIN" ...'` — as an illustration. Measured
immediately afterwards, admitting whitespace then derived **five** PATHs, the
farm among them, entirely because of the sentence claiming it would derive four.
The assistant found this by re-running the measurement after writing the
sentence, not by reading it.

The example is now described and not spelled out, and the comment says why the
omission is deliberate. The claim beside it is a measurement: admitting
whitespace against this file as it stands changes nothing — the same twelve
lines, the same four PATHs — so the exclusion is a rule about what may be written
here later and not a description of something the file contains. Stating it the
other way would have been this section's defect a third time.

## Measured

`check-hooks.sh` **ALL CHECKS PASSED, 3810 results** (3807 before this round),
exit 0. 175 requirements, 157 active, 112 off the both-directions rule —
unchanged, this round adds no requirement.

Three checks added, all under `GH-155.1`:

- the `case` arm **read out of this file as it stands**, found by its shape and
  not by a line number, with its count asserted first because a derivation run
  over an empty extract returns the empty string and would agree with nothing;
- the derivation over that real line, which must yield `$PATH`;
- the three shapes this suite writes — indented loop body, `case` arm, and a call
  after `then` — none of which begins its line;
- and the commented-call pair above.

Hand mutation, each edit applied to the file that runs, restored from one
backup, `sha256sum -c` clean after both:

| edit | outcome |
|---|---|
| the pattern back to the line-start spelling the review found | **caught** — 3 FAIL: the real case arm, the three shapes, the commented pair |
| `then`/`do`/`else` dropped, the `case` position kept | **caught** — 1 FAIL, the three shapes, and nothing else |

The second is the one worth having: it says the `then` half of the widening is
carried by a check of its own rather than riding along with the `case` half.

## Correction, before this entry was committed

The list under **Measured** reads as four items where **three** checks were
added, and the arithmetic is the thing to trust: 3807 + 3 = 3810. The three new
ones are the `case` arm's count, the derivation over that real line, and the
commented-call fixture. The fourth item — the three shapes this suite writes — is
not new; it is round one's indented-only fixture check rewritten to assert three
shapes instead of one.

The entry is left standing rather than rewritten, because `append-only-docs.sh`
refused the removal and was right to: an uncommitted draft and history are not
distinguishable to it, and the rule it enforces is the one that makes these
directories worth reading.

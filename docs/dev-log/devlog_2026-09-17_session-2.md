# 2026-09-17 · session 2 — #128: a continued heredoc opener hid the command after its terminator

**Branch** `worktree-issue-128-heredoc-opener-continuation`, cut from
`origin/dev-05` at `befcf8a` and proposed into `dev-05`. **Check suite 3657 →
3957 results, all passing** (measured, 136 s). The mutation registry goes from
23 rows to 24; the new row was run by name — baseline plus one run, `caught`,
with `GH-128` among the 22 requirement IDs that went red. `requirements.md`
gains `GH-128` and goes from 162 entries to 163.

Worked by the assistant, unattended, from #128 and its triage comment.

## The defect: bash joins the opener's own line, and the drop did not

`cs_normalise`'s first pass found a heredoc opener on a raw line and dropped
lines until the terminator; `cs_join` joined continuations one pass later. The
comment above it argued that this order was the safe one — "a backslash at the
end of the line before a heredoc terminator cannot swallow the terminator and
hide what follows". It was true of the line before the terminator and false one
line further up. Bash joins a continued line *before* the body begins, so

```
cat <<E \
x
E
git push --force origin main
```

is `cat <<E x` with an empty body, and the push runs. The drop took `x` for the
body, ended it at `E`, and `cs_join` then glued the push onto the opener's line,
where it stands at no command position: `cs_normalise` emitted the single line
`cat <<E git push --force origin main`. Both `no-git-push.sh` and
`no-commit-to-main.sh` answered exit 0, where the same command without the
backslash is exit 2. Bertan's review of PR #123 found it; the defect predates
that PR.

The second consequence was a claim rather than a verdict. `cs_within_cap` refuses
a command holding a joined line past 16 KB *before* any pass runs, and #96 read
that as a bound on what the passes are handed. Forty repeats of
`echo <15000 × a> <<E \` / `x` / `E` pass the cap — longest joined line 15,011
bytes — and made `cs_normalise` emit **one 600,400-byte line**, measured here on
this branch with the fix reverted. The issue measured 600,428 on #123's branch;
the figure differs with the branch, and the one written into the library is this
branch's.

## The fix, and the order that was not taken

The issue's triage offered two orders, joining before the drop or dropping
first, and the triage comment refined it to a third: join the non-body lines
before looking for an opener, never join a body line. The assistant took a
fourth, which is that third one without the join:

- the opener is looked for on **each physical line**, as before;
- the body begins after the first line that **does not end in a backslash**;
- the joining itself stays `cs_join`'s, one pass later.

Two reasons for not joining inside the drop. A join written in the first pass is
the join rule written twice, in the file whose header names that as the defect
class it exists to end — and the two copies would then be free to answer the
backslash differently, which is the defect being fixed, back again. And the
joined line would have to be materialised for the opener search to read it,
which is `out = out c` at line scale: #96 measured that shape at 5.9 s for
512 KB and rewrote six passes to remove it.

The rule this pass uses for "the line continues" is `cs_join`'s exactly — any
trailing backslash, an escaped one included — and it has to be, because
`cs_join` is what joins the line afterwards. A drop that ended the logical line
*earlier* than `cs_join` joins it is the defect. Looser is the safe side: a
logical line held open too long only exposes more lines as commands.

**What the fourth order costs, recorded because it is a real difference from the
third.** An opener split by the continuation — `cat <<\` / `E`, which bash reads
as `<<E`, or `cat <<E\` / `x`, which it reads as `<<Ex` — is not recognised as
that opener, because no joined text is ever read. Either no opener is found or
its delimiter never arrives, and both end in the `END` give-back: the held lines
come back and are scanned as commands. That is the direction every other
uncertainty in this pass already takes, and it is the same one bash's joining
inside an *unquoted* body takes, which is deliberately not modelled.

## What the checks establish, and what they cannot

Nineteen checks are written out, 273 come from #106's families, and seven are
the families' own per-transformation guards: 300 new results.

- Four `tok` checks read `cs_normalise`'s output directly, which is where the
  defect is visible as text rather than as a verdict.
- Twelve verdict checks are the two hooks and the two directions #128 measured,
  over seven spellings of the opener: `<<E`, `<<-E` with a tab-indented
  terminator, `<<'E'`, `<<"E"`, `<< E`, an opener continued over three lines,
  and a redirect in front of it.
- Three checks in the cap section hold the second consequence to literals: the
  40-group input is within the cap, and `cs_normalise` emits 40 lines whose
  longest is **15,011** bytes.
- #106 has landed, so the seven spellings are registered as transformations
  rather than left as a hand list. Each is asked of every one of the 39 seeds,
  which is the whole reason that section exists; the issue listed the spellings
  as a hand enumeration and said to prefer a family if one existed.

**Which of them fail with the fix reverted.** Measured, against a copy with the
one line reverted and `CHECK_HOOKS_DIR` pointed at it: **145 red**, all of them
new. Twelve of the nineteen written-out checks — the eight refusing verdicts,
the two `tok` reads of the opener, and the two cap numbers — and 133 of the 273
family variants, which is 19 refusing seeds × 7.

Three of the written-out checks and 21 family variants stay green with the fix
reverted, and both are by construction rather than by accident:

- the permitting direction is unchanged behaviour. `echo RAN-AFTER` in place of
  the push, a quoted body that merely names one, and a slashed body line
  followed by a real push were all answered correctly before this change. They
  are regression guards, and a check that went red on the revert would mean the
  fix had changed the drop rather than where it starts.
- the 21 are the three *wrapped* seeds — `bash -c "git push …"` and its two
  siblings — whose refusal comes from `CS_WRAPPER_RE` against raw text and never
  reaches `cs_normalise`.

Stating this is #128's own acceptance criterion read literally ("every new check
fails with the fix reverted"), which cannot hold for a check whose subject is
behaviour that did not change.

## The counts in the comments, and the two left alone

The heredoc question has now been answered five times and got wrong four. Four
claims were moved from three to four: the `cs_normalise` header, the
redirect-pass bullet that cites it, and two in `check-hooks.sh`. THE SECOND
TRADE's "asked a fourth time in a second place" becomes a fifth.

Two "three times" claims in `lib/command-scan.sh` were **deliberately left** —
`cs_split`'s tail note and the prefix loop, both of which say *reading text as a
command* is the mistake `cs_normalise` has made three times. #128 is the
opposite direction: a command was read as text. Incrementing them would have
made them false, and a reviewer who disagrees has one number to move rather
than a paragraph to rewrite.

THE LINE CAP's *WHAT THIS CAP DOES NOT BOUND* named #128 as the reason the cap
does not bound what the passes are handed. That half is now the opposite, and
what replaces it is an argument rather than a measurement: the drop only ever
removes lines, and it can remove a line adjacent to a continued one only inside
a body — a body begins after a line that does not end in a backslash, and the
lines held for one are given back together — so every joined line
`cs_normalise` emits is part of a joined line `cs_within_cap` measured, and no
longer than it. #127, the fragment-count half of the same paragraph, is still
open and still says so.

## State, and what is open

The branch holds one commit. `bash .claude/hooks/check-hooks.sh` passes in full,
3957 results. `bash .claude/hooks/mutate-hooks.sh -v heredoc-opener-continuation`
reports `caught` and leaves `.claude/hooks/` byte-identical; the whole registry
has **not** been re-run since the row was added, and mutate-hooks.sh's header
says so where it records the 2026-09-17 measurement of twenty-three rows.

Open, and not this branch's:

- **#127**, the other half of the cap's claim: fragment count, not line length.
- **An opener split by a continuation**, described above. Not filed: it is a
  fail-safe, its shape is one an agent would have to construct, and CLAUDE.md's
  stopping rule is that a newly found evasion earns a fix only if it is a shape
  an agent would plausibly write.
- **#108 and #109**, which owe the registry their own rows.

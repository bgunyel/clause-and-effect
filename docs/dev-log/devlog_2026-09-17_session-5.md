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

## Correction, from the review of this session's own commit

The two review axes run over `c2ce2bd` found that the assistant had miscounted
its own checks, which is the class CLAUDE.md says to re-measure rather than
restate. Appended rather than edited above, because the append-only guard
refuses an in-place edit of an entry — verified by feeding the command to
`append-only-docs.sh` rather than running it — and because that is what the
directory's rule says to do with a correction. The figures here supersede the
ones in *What the checks establish* and in `c2ce2bd`'s message; both of those
stand as written.

**How far ahead of `main`.** The convention in this directory's README asks for
it and the entry above omitted it: the branch ends **186 commits ahead of
`origin/main`**, two ahead of `origin/dev-05` — the fix, and the commit that
carries this section.

**Which commit each figure belongs to**, since this section adds four checks of
its own. The entry above describes `c2ce2bd`, where the suite was 3957 results
and 145 went red with the fix reverted. Every figure in this section is measured
at the second commit's tree.

**The counts, measured rather than derived.** Suite 3657 → **3961** results.
The families contribute **280** — 273 variants and 7 per-transformation guards
— so **24** checks are written out, not the nineteen the entry above claims, and
there is no "coverage row" among them: 280 + 24 = 304, and 3657 + 304 = 3961.
The #128 verdict section holds **13** checks, nine refusing and four permitting,
where the entry says twelve. The assistant wrote both figures from the edit it
had just made instead of from a run, which is the whole of the error.

**Four checks the review added.** The standards axis — a review the assistant
ran on its own commit, not Bertan's — found the continuation
rule now derived in two places — `$0 !~ /\\$/` in the drop, and `cs_join`'s
own count of trailing backslashes — with the code asserting they cannot disagree
and nothing pinning it. That is #84's question one level in, and the assistant
had answered it in a comment. Four `tok` checks now hold the two against each
other over runs of two and three backslashes: the joined text is read once as
`cs_join`'s output and once as the drop's, so a change to either rule moves one
literal of a pair. Two backslashes is where bash parts company with both — it
reads `\\` as an escaped backslash, so the line does not continue, the body is
`x` and `E` ends it, and the push runs anyway, which is the verdict the looser
rule reaches by deferring the body.

**Which new checks go red with the fix reverted, in full.** **147** of 3961,
all of them new, measured against a copy with the one line reverted: 14 of the
24 written out, and 133 of the 273 variants (19 refusing seeds × 7 spellings).
The entry above says three written-out checks and 21 variants stay green; it is
**10** and **147** — 140 variants, being 17 permitting seeds × 7 plus the 21
wrapped, and the 7 guards. The ten, and why each cannot fail:

| check | why the revert cannot reach it |
|---|---|
| `a body line ending in a backslash is not joined past its terminator` | the body drop, which this change does not alter |
| `a body naming a push on a continued line is still dropped` | same |
| `BLOCK a slashed body line, then a push` | same |
| `ALLOW the same shape, with nothing to refuse after it` | the permitting direction, correct before the fix |
| `ALLOW the same shape on main, with nothing to refuse` | same |
| `ALLOW a body naming a push on a continued line` | same |
| `ALLOW a body naming a commit on a continued line` | same |
| `cs_join folds a line ending in two backslashes` | `cs_join` is untouched; it is the half of a pair whose other half does go red |
| `cs_join folds a line ending in three backslashes` | same |
| `the #128 shape is within the cap` | `cs_within_cap` runs before `cs_normalise` and the revert does not reach it |

#128's criterion reads "every new check fails with the fix reverted", and ten
cannot: a check whose subject is behaviour this change leaves alone is a
regression guard, and one of them going red would mean the fix had moved the
drop rather than where it starts. Naming them is the part the entry above got
wrong by naming three.

**A seventh count site.** The review also found `lib/command-scan.sh`'s own
header still reading "Three wrong answers, each silent and each in the
permitting direction, is evidence about the question" — a site the assistant's
sweep had missed while listing four it had moved and two it had left. It now
records the fourth and says the reading of it is unchanged. Two claims stay at
three on purpose, both about reading *text as a command*, which is the opposite
direction from this defect; the spec axis checked that reading independently and
agreed.

## Renumbering: this entry is session 5, and its heading is wrong

The heading above reads *session 2*, which is the number this session was
working under. Session 2 of 2026-09-17 turned out to belong to another session,
whose entry landed in `dev-05` first and is kept byte-identical; two more, 3 and
4, landed with it. This entry is **session 5** and its file is named for that.

The assistant could not correct the heading. `.claude/hooks/append-only-docs.sh`
refuses `rm`, `mv`, `git mv` and a truncating redirect on any file in
`docs/dev-log/`, each verdict read by feeding the command to the hook rather
than running it, and the Edit and Write tools are refused on a file that already
exists. An append is the only edit available, so the correction is appended —
which is the rule this directory keeps anyway. One `git mv` from Bertan's
terminal, which the hooks do not see, fixes it.

## The fix was wrong, and the review found it permitting

Bertan reviewed PR #151 and returned four findings, two high. The first is the
one that matters: the fix permitted a command bash runs, which is the defect
class it exists to close, arriving inside the change that closes it.

```
cat <<E \\
E
echo after
git push --force origin main
E
```

Bash ends the command line at `cat <<E \` — `\\` is an escaped backslash, an
even-length run, so nothing is continued — takes the next line as the terminator
of an empty body, and runs `echo after` and the push. `cs_normalise` as
`c2ce2bd` left it emitted `cat <<E \E` and nothing else. The push was gone.
`no-git-push.sh` answered exit 0 where `dev-05` answered exit 2.

**The cause was the argument, not an oversight.** The assistant had written, and
this entry above still says, that *looser than bash is the safe side, because a
logical line held open too long only exposes more lines as commands*. That
sentence is false, and everything downstream of it followed: holding the line
open moves the start of the body forward and the search for the terminator with
it, so a delimiter line that bash took as the whole terminator is scanned past
as though it were part of the command line, the body runs on to the next
delimiter, and every line between them is dropped. Exposing and hiding are not
the only two outcomes of a boundary moved late. The sentence is now in
`lib/command-scan.sh` with the counter-example under it, because the reasoning
was the defect.

## Two rules, and why neither alone is the fix

**Parity.** A line continues only when its run of trailing backslashes is odd.
That is bash's rule; `cs_join`'s is any trailing backslash at all, deliberately
and unchanged. Written as a flag flipped per backslash rather than with a
modulo, because `mutate-hooks.sh` splits a registry row on `%` and could not
otherwise carry the expression that breaks it.

**The boundary.** `cs_join` runs one pass later on that looser rule, so the line
a body starts after — which under the parity rule can only end in an even run,
exactly where the two disagree — has its trailing run taken off, with the blanks
in front of it. It is the one line onto which `cs_join` could otherwise glue the
first line past the terminator, and a trailing backslash is text of a command
line, never a command.

Neither rule alone reproduces the defect the issue was filed for: on an odd run
the two cover the same case, so breaking one leaves the other holding it. Three
rows are registered in `mutate-hooks.sh` for that reason — one per rule, and
`heredoc-opener-continuation`, whose edit is two commands, which puts the pass
back to what `dev-05` did. All three were run by name with the baseline and all
three are caught; the two single-rule rows turn `GH-128` red and nothing else.

## What says it, and the harness that was twice green for the wrong reason

An argument in a comment is what produced the regression, so the claim is now
measured. 2,580 generated shapes of opener, backslash run, delimiter and payload
position are each **run under bash** with `touch ran.flag` as the payload, so
that execution and not output decides what ran, and then put through
`cs_normalise` with a push in the payload's place. The property is that a push
bash runs stands at the start of some emitted line, because a hook cannot see
one that does not.

| library | shapes where bash runs the push and no hook can see it |
|---|---|
| `origin/dev-05` | 198 |
| `c2ce2bd`, the first fix | 40 |
| this fix | 0 |

Of the 198 on `dev-05`, the first fix closed 184 and **introduced 26 new ones**.
That is the number the review found by hand.

The harness earned its own paragraph by being wrong twice, and both times it
read as evidence. Its first generation ended every case `E / payload / E`, so a
body that had swallowed one terminator was re-closed by the second before the
payload was reached: it reported **0 new regressions** for a library that
measurably had one. Its second generation used `echo THE-PAYLOAD-RAN` and looked
for that string in bash's output — but when the payload line is inside a heredoc
body, `cat` prints it, so the string appeared without anything having run, and
151 of the cases it reported were that. Both were found by reading the cases
rather than by the harness. It lives in the pull request and not in the tree.

## The counts, re-measured

Suite **3657 → 3967** on this branch, and **4096** on the merged tree once
`origin/dev-05` came in with #108's work. 310 new results: 280 from #106's
families — 273 variants and 7 per-transformation guards — and **30** written out.

Under `heredoc-opener-continuation`, the row that restores `dev-05`'s behaviour,
**151** go red: 133 family variants and 18 of the 30. Twenty of the 30 are
reached by one of the three registered mutations. The ten that are not are named
here, because "every new check fails with the fix reverted" is #128's criterion
and it cannot hold for a check whose subject is behaviour the fix leaves alone:

- `a body line ending in a backslash is not joined past its terminator`,
  `a body naming a push on a continued line is still dropped` and
  `BLOCK a slashed body line, then a push` — the body drop, unchanged.
- the four permitting verdicts — `echo RAN-AFTER` in the push's place on both
  hooks, and a body that merely names a push or a commit.
- `cs_join joins an even run, which bash does not` and `an odd run of three is a
  continuation to both of them` — the `cs_join` halves of the paired pins. **No
  registry row mutates `cs_join`**, so those two are evidence about `cs_join` as
  it stands and would not go red for any change to the drop.
- `the #128 shape is within the cap` — `cs_within_cap` runs before this pass.

## State

Three commits and a merge. `bash .claude/hooks/check-hooks.sh` passes in full at
4096 results. `bash .claude/hooks/mutate-hooks.sh --list` reads 32 rows, 30 real
mutations against 6 files, naming 39 requirement IDs, of 157 active; the whole
registry has not been run since #107 measured its 23, and nothing claims it has.

Still open, and not this branch's: **#127**, the fragment-count half of the
cap's claim; **#148**, which would take the restated counts out of
`mutate-hooks.sh`'s header and leave `--list` as the only place they are
written — this session moved four of them by hand and is the second session in
two days to do so.

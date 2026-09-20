# Dev log — 2026-09-20, session `dev-agent-130`

## 2026-09-20 20:40 +03 — #130: the gh api endpoint rules go per-command

Branch `worktree-issue-130-endpoint-per-command`, cut from `origin/dev-05` at
`7bea85f` and reset onto it as its first act. Three files changed and no commit
yet at the time of writing: `.claude/hooks/no-pr-decisions.sh`,
`.claude/hooks/check-hooks.sh`, `.claude/hooks/requirements.md`. The branch is
one commit ahead of `origin/dev-05` once this entry lands.

### The endpoint was read off the line, and an issue body is on the line

Six rules in `no-pr-decisions.sh`'s `gh api` write block asked their question of
`$SCAN` — the whole normalised line with its quotes still in it. The base rule
stopped doing that when #40's review scoped it per command through `cs_gh_args`;
these six never made the move. So a write to an **issue** was refused whenever
the text it carried named some other endpoint's path, field or mutation, and a
`/releases` read standing beside an unrelated issue write was refused with it.

All ten rows of #130's table were BLOCK at `7bea85f`, measured before anything
was changed, and the three controls were ALLOW. The pair that makes this a
consistency fix rather than a change of policy was already in the suite:
`gh api -X POST repos/o/r/issues -f title=x && gh api repos/o/r/pulls` pinned
ALLOW, and the same shape with `/releases` in place of `/pulls` BLOCK — two
answers to one question, one of them pinned.

The file's own comment above the `/releases` rule recorded the bleed as known
and unfixed. That is what made it an issue rather than a pin, and #137 (the
field readers' quote spellings) had to land first; it merged on 2026-09-18.

### The fix, and the design mistake in the middle of it

The endpoint questions moved into the per-command loop and are asked of
`cs_gh_args api`'s own output through a new third reader. The three rules that
cannot be scoped — the graphql mutation names, `updatePullRequest` plus a state,
and `gql_bases` — keep `$SCAN` behind a structural gate: they fire only when
some `gh api` call's own arguments carry a bare `graphql` token. Each rule sets
a flag and the messages print after the loop, in the order they always printed
in, which is now a stated contract rather than the order the `if` arms happened
to be written in.

**The assistant wrote the new reader to a proxy and it was wrong.** #130's
triage settled the design as "a quoted span that is a whole word is unquoted,
every other span is dropped", and named in the same sentence what that was
reaching for: *a field value is attached to its `=` and a positional is not*.
The assistant implemented the proxy rather than the thing it stood for. The
proxy reads correctly for `-f body="repos/o/r/pulls"`, where the span opens
after the `=`, and wrongly wherever quoting sits inside a word for some other
reason. Measured, old hook against new, nine commands refused at `7bea85f`
became permitted:

| shape | `7bea85f` | first version |
|---|---|---|
| `gh api $'repos/o/r/pulls/5/merge' -X PUT` | BLOCK | ALLOW |
| `gh api $"repos/o/r/pulls/5/merge" -X PUT` | BLOCK | ALLOW |
| `gh api -X POST $'repos/o/r/releases' -f tag_name=v1` | BLOCK | ALLOW |
| `gh api -X PATCH $'repos/o/r/pulls/5' -f state=closed` | BLOCK | ALLOW |
| `gh api -X POST $'repos/o/r/pulls' -f head=x -f title=y` | BLOCK | ALLOW |
| `gh api graph"ql" -f query="mutation{mergePullRequest(…)}"` | BLOCK | ALLOW |
| `gh api 'graph'ql -f query="mutation{mergePullRequest(…)}"` | BLOCK | ALLOW |
| `gh api $'graphql' -f query="mutation{mergePullRequest(…)}"` | BLOCK | ALLOW |
| `gh api 'repos/o/r/pulls'/5/merge -X PUT` | BLOCK | ALLOW |

Every one is in the permitting direction and none was pinned anywhere, so the
suite was green with all nine in place — 5331 checks, `ALL CHECKS PASSED`. They
were found by a review pass over the branch, not by the suite. Three of them
shut the graphql gate, which turns off three rules at once.

The `$'…'` rows are the same defect `quoted_base_flag` was fixed for five
hundred lines up in the same file, arriving a second time one reader over. That
comment says it in as many words: *"The `$` of bash's `$'...'` and `$"..."` goes
with its quote, found by review of this fix: counted as a character, it hid
`$'--base' main` as `$--base`."* The assistant had read that comment while
writing the code above it and still wrote the same bug.

The proxy is gone. Each span is now **dropped** if it holds whitespace,
**dropped** if an `=` stands before it in the same word, and **unquoted**
otherwise — with a `$` before the opening quote counted as part of the span and
backslash escapes read as bash reads them, outside a span and inside a
double-quoted one but not inside a single-quoted one. The alternative the triage
rejected, a lone token with no `=` *in* it, stays rejected and this is not it:
`gh api "repos/o/r/releases?per_page=1"` carries its `=` inside the span and
none before it, so it is still read. The reader is named `endpoint_args`, since
"lone token" stopped describing it.

Two spellings that were permitted at `7bea85f` too are refused now —
`repos/o/r/"pulls"/5/merge` and `repos/o/r/"releases"`, which the old
`$SCAN`-wide greps missed because they wanted `/pulls/` and `/releases` with no
quote inside them. A tightening on the way past, pinned as the verdicts they now
have and named as something this fix was not filed for.

### The requirement texts over-claimed, and the bare spelling is still refused

A second review pass, against the issue's acceptance criteria, found the
assistant's own `GH-130.1`, `.2` and `.4` texts saying an issue body naming
`/releases` "is prose". Measured: `gh api -X POST repos/o/r/issues -f
body=/releases` is BLOCK — unquoted, there is no span to drop and the value is
the same characters a positional endpoint would be. Not a defect this change
introduced (it was BLOCK at `7bea85f`), but the texts were written as though the
fix reached it. They now say QUOTED, and the bare spelling is pinned beside
`-f "body=/releases"` as the other end of one trade: quoted or bare, an
argument's text does not say whether a word is an endpoint or prose.

### What the in-span backslash rule is for

Both backslash rules — outside a span, and inside a double-quoted one — were
written together, and the first attempt to show each was load-bearing failed:
turning off either one left `gh api -f a=\" repos/o/r/pulls/5/merge -X PUT -f
b=\"` refused, because the other one caught it. The row that separates them was
found by looking for one rather than by assuming: `gh api -f t="a\"b" graphql -f
query="mutation{mergePullRequest(input:{x:1})}"` is BLOCK, and ALLOW with the
in-span rule alone turned off — the span closes early, every quote after it is
read one out of step, and the bare `graphql` two arguments later stops reading
as one. The out-of-span rule is the only defence of the `\'` spelling, single
quotes taking no escapes inside a span. Both rows are pinned.

### Cost at the line cap, measured and taken rather than optimised away

The per-command move asks four questions once per `gh api` command that used to
be asked once per line. On one line at the 16 KB cap made of nothing but
unquoted `gh api` calls, ~450 of them, minimum of five interleaved runs on a
machine carrying several other check suites: 11.2 s at `7bea85f`, 14.0 s with
the fix, 16.3 s with the fix and the reader's short-circuit taken off. A control
line with no `gh api` call on it at all, which nothing in this change can touch,
read 12.0 s and 11.9 s, so the noise floor is about five per cent.

Every reading is already twice past the 5 s harness timeout before this fix
touches it. That is GH-127, which #127 owns. Prefiltering each of the four greps
with a `case` was written and dropped: keeping the state rule's endpoint test
where it is would have meant reproducing `grep -i` in a shell pattern, and a
guard a reader has to verify twice is a worse trade than a stated 25 per cent on
a shape nobody writes. The trade is recorded in the code rather than left to be
found.

### Coverage

`GH-130` keeps its ID and takes `status: superseded-by: GH-130.1`, the other
four named in its `note`: its text was written against the four shapes the issue
was filed with, the grilling of 2026-09-16 found six more, and the ten fall to
five rules that can each regress on its own. `GH-130.1`–`.5` are appended.
`GH-130.5` declares `variants: seed` and is tagged onto the existing
`api-graphql-main` seed, since its subject is a token and `quote-double-3` over
that seed is `gh api "graphql"`; the other four declare `variants: none`,
because what separates a read span from a dropped one is an `=` before it in the
same word and no transformation in `INV_TRANSFORMS` generates that.

### Two derived literals moved, and the suite is what said so

The change moves two facts the suite holds as literals, and both went red on the
first clean run after the last edit rather than being noticed while making it.
Neither is a defect; both are the #104 design working — a fact written down
twice, where the second copy is the one a reviewer sees move in the diff.

- The sorted table of `no-pr-decisions.sh`'s functions and which of them write a
  refusal. Renaming the reader from `lone_token_args` to `endpoint_args` was
  done with a blind substitution, which put the new name where the old one had
  sorted, between `is_dev_base` and `quoted_base_flag`. `endpoint_args` sorts
  after `bases_all_dev`.
- The per-ID seed-verdict literal in #106's section. Tagging `GH-130.5` onto the
  existing `api-graphql-main` seed adds a row to it: `GH-130.5 BLOCK`, seeded in
  one direction, and the comment above the literal now says why — the gate's
  permitting half is an issue body naming a mutation, which the #130 section
  pins directly and which no rewriting of a graphql seed can produce.

The assistant also edited `check-hooks.sh` while a run of it was in flight, on
the first pass. bash reads a script by byte offset as it executes, so inserting
a section under a running suite shifts every offset after it; that run's tail is
not evidence and was discarded rather than read. The clean run was started again
after the file was frozen.

### Which rows can fail, measured one clause at a time

Nine broken copies of `.claude/hooks/`, each with one part of the fix undone,
judged through `$CHECK_HOOKS_DIR`; this repository's own hooks were never
edited, and every edit asserted its anchor stood exactly once, so a mutation
that failed to apply could not read as evidence.

| mutation | red | what it undoes |
|---|---|---|
| clean | 0 | — |
| `revert` | 19 | `no-pr-decisions.sh` as it stood at `7bea85f` |
| `raw-cmd` | 15 | the per-command move with no reader over it |
| `drop-all` | 21 | the reader drops every span and reads none |
| `eq-off` | 4 | the `=`-before-the-span clause |
| `no-dollar` | 1 | `$` taken as part of its quote |
| `esc-out` | 1 | backslash outside a span |
| `esc-in` | 2 | backslash inside a double-quoted span |
| `textual` | 3 | the graphql gate made a grep for the word |
| `state-arg` | 6 | the state field read through the reader |
| `order` | 3 | the `/releases` arm printed before `merge|reviews` |

`revert` is 17 verdict rows and 2 static ones. Two results corrected what the
assistant had written about its own change:

- `drop-all` turned red a row nobody here wrote — #97's `POST an asset to the
  uploads host`, which already carried a single-quoted endpoint. The section
  comment had said a quoted path was "new here". It was not; it was pinned for
  the release rule and passed before the fix for a different reason, nothing
  having needed unquoting while the rule read `$SCAN` with its quotes in. The
  comment names that row now.
- `eq-off` turned red **one** row, row 10, and no other. Every other body row in
  the section carries whitespace in its value, so the whitespace clause drops
  the span first and the `=` clause is never asked. One row carrying one clause
  is the shape this suite's header warns about, so three more were added, one
  per remaining rule, and the count is 4.

The same measurement says `no-dollar` is carried by one row and that this is
correct rather than thin: with the `=` clause right the span is read anyway, and
the `$` left in front of the body does not stop `/pulls/` or `/releases`
matching mid-string. Only the gate, which wants `graphql` at a word boundary,
can see the difference. The other four `$'…'` rows are in the suite because each
was a refusal this fix turned into a permission — reason enough for a row, and
not four pieces of evidence about one clause. The comment says so, because
implying otherwise is how a suite comes to claim more than it checks.

### Still open
- `#138` (no field rule reads a JSON request body) lands after this, per the
  landing order the grilling set. It is listed under *Citations that are not
  requirements* because the rewritten heredoc row cites it to say what that row
  is **not** about.
- Three bleeds are accepted and named in the code: `gql_bases`' cross-command
  bleed, a genuine `gh api graphql` read beside an issue write whose prose names
  a mutation, and a quoted body whose span is still open where the line ends.
- `$'…'` escapes are taken as quoting and not decoded, so
  `$'\x2frepos\x2f…'` is permitted. A gap this fix neither opened nor closed —
  the old `$SCAN`-wide grep never matched an escape spelling either.

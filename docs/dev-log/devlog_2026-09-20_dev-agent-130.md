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

---

## 2026-09-20 22:25 +03 — #196 review round 1: the gate knew one spelling of three

rev-agent-130's round 1 on PR #196, against head `164a5ab`. The reviewer
confirmed the suite green (5354 `ok` rows against 5294 at `7bea85f`) and
re-measured all ten rows of #130's table, the three controls and the four
must-survive refusals before looking for anything, and disputed neither the
per-command move nor `endpoint_args`. Three classes came back, two of them
gating. Every claim was reproduced here before anything was changed; all three
reproduced exactly.

### The gate was as wide as its own sentence, and the sentence was false

`no-pr-decisions.sh` said, in the comment above the gate: *"A bare `graphql`
token in an api call's own arguments is gh's one spelling of that endpoint."*
It is not. `gh` resolves a bare path, a leading-slash path and a full URL to the
same request, so `gh api /graphql` and `gh api https://api.github.com/graphql`
both execute a real GraphQL operation and neither carries a whitespace-anchored
`graphql`. Twelve shapes were BLOCK at `7bea85f` and ALLOW at `164a5ab`, and the
gate closing switches off **three** rules at once — the mutation names,
`updatePullRequest` + state, and `gql_bases` with its `createPullRequest` arm.

The reviewer verified the three spellings against the live API. The assistant
verified the mechanism rather than taking that on trust, and did it without
sending a mutation: `rate_limit`, `/rate_limit` and
`https://api.github.com/rate_limit` all return the same body, `rate_limit/` and
`//rate_limit` 404. Two spellings the review did not name were measured and are
now matched: `http://` resolves as `https://` does, and `HTTPS://` uppercase
resolves too, so the scheme is compared case-insensitively. `/GRAPHQL` is
excluded — GitHub's paths are case-sensitive — and GHES's `/api/graphql` is
named in the comment and deliberately not matched.

The sweep the class asks for is every endpoint test in the file, five of them.
Four match a substring of the path and carry every spelling for free; each was
measured in all four spellings before and after the widening, sixteen
measurements, none moved. They are pinned now in the two spellings that had no
row, so "measured clean" is a check rather than a sentence in a pull request.

### An endpoint in a variable was never a rule, and the measurement says so

Class 2 reported four BLOCK→ALLOW transitions on `EP=…; gh api $EP` shapes and
asked for a decision on the record. The decision is that these were never a
rule, and the control is one command: with the assignment taken **off** the
line, `gh api $EP -X PUT` and `gh api -X POST $EP -f tag_name=v1` are ALLOW at
`7bea85f` too. What refused the four was the line-wide read finding the text of
the *assignment* — row 4 of #130's table in another costume, a string belonging
to one command judged as another's endpoint.

The reviewer is right that the base rule answers the same question the other
way and that the file says so nowhere. They are asked different questions: a
base is refused when it is *named* and unreadable, and naming a destination is
the act guarded, so the correction is one word; an unreadable endpoint names no
act at all, and refusing it refuses every `gh api` write whose endpoint is a
variable — #130's own defect with a different trigger. CLAUDE.md's left-open
item 6 settles the identical question one word to the left, measured against
75,346 commands. The asymmetry is deliberate; that it was undocumented is the
finding, and it is filed as #198 with three ways to close it and a
recommendation. Four verdicts are pinned as accepted, with the no-assignment
control beside them so the argument is checkable and not an excuse.

### A suggested alternative that would have cost four of the ten rows

Class 3 is unexploitable and was filed rather than gated: `endpoint_args`'
whitespace clause fires on a positional too, so
`gh api -X PUT "repos/o/r/pulls/5/merge "` loses its endpoint — and GitHub
serves none of the spellings it drops, which the reviewer measured. Two accepted
rows close it.

The review added that leaving a whitespace-holding span raw instead of dropping
it "would too, and costs nothing". Measured on a copy of the hook built to do
exactly that: **four of #130's ten rows go back to BLOCK** — rows 1, 2, 3 and 5,
every one whose body names a path in prose. That is the whole of what this issue
fixes, traded for two spellings that 404. Declined, with the numbers, which is
the one place this round pushed back rather than complied.

### A number that was stale, and why arithmetic was the wrong fix

The body claimed `revert` = 19 red. The reviewer measured 22 and was right: the
three rows added after the `eq-off` finding were never counted, because `eq-off`
was recounted and `revert` was not. They asked for a re-run rather than a patch
from 19 to 22, which is the right instinct — at least one row had been measured
against a suite text that then changed. Every mutation is being re-run against
the current tree, `revert` included, and a tenth was added: `gate-narrow`, the
gate as it stood before this round.

### Still open

- `#198`, the base/endpoint asymmetry, recommended to be settled by measuring
  the local session corpus first.
- `#138` lands after this.
- The `$'…'` escape spellings of an endpoint are still not decoded, and the
  reviewer did not raise them; they remain named in `endpoint_args`' comment as
  a gap this fix neither opened nor closed.

---

## 2026-09-21 02:10 +03 — #196 review round 2: a guard rewritten to close a class exhibited the class

rev-agent-130's round 2, against head `111a419` — Bertan's own merge of
`origin/dev-05` at `2019e08`, resolved in the web UI, which the worktree was
fast-forwarded to before anything was touched. Three gating classes, two of them
new. Every claim was reproduced against both hooks before anything changed, and
all three reproduced exactly.

### The gate's second version had the defect its first version was fixed for

Round 1 replaced one spelling of the graphql endpoint with three. Round 2 found
the class intact: the enumeration was still anchored on whitespace after the
token, and `gh` serves anything appended to an endpoint, so `graphql?x=1`,
`/graphql?`, `graphql#x` and five more executed real GraphQL and matched none of
the three. Eight shapes were BLOCK at `2019e08` and ALLOW at `111a419`, with the
suite green — which is the sharpest form of what this repository keeps saying
about check suites, arriving inside the change written to close that exact
class.

The gate normalises now instead of listing: strip a leading `scheme://host`, cut
at the first `?` or `#`, drop **one** leading `/`, compare the remainder to
`graphql`. A suffix nobody has thought of is answered by the cut rather than by
an alternative added later, and the rejected spellings become a statement about
a normalised path rather than about regex anchors.

### Class 4: moving a question onto one command hands it to the tokeniser

`cs_split` cuts a command at `$(` and at a backtick, so a substitution standing
**before** the endpoint hands the loop a fragment the endpoint is not in —
`gh api -X PUT repos/$(basename x)/pulls/5/merge` splits into `gh api -X PUT
repos/$` — and four rules that read the command's own arguments then read a
command with no endpoint and permit. That is the price of the move this whole
issue is: every way the tokeniser can cut a command is a way to remove the
subject of a question asked of that command.

The base rule survives the identical cut, because a create whose base cannot be
read falls into the arm that refuses a create naming none. The endpoint rules
had no such arm. They have one now — a `gh api` **write** whose own arguments
carry no token that could be its endpoint is refused — and it is this file's own
header sentence applied to an endpoint: a destination that comes from
configuration cannot be judged from here, so the command has to say where it is
going.

**It was priced before it was taken**, on the corpus CLAUDE.md's left-open item
6 was settled against: 883 transcripts, 21,768 distinct commands, the 1,767
carrying the text `api` fed to this hook and to a copy with the arm removed, so
the difference is the arm and nothing else. **Six change verdict, all ALLOW to
BLOCK, and all six are loops written to ask what an endpoint does while this
issue was under review** — `for p in graphql /GRAPHQL "graphql/"; do gh api
"$p" …; done` and five of that shape, two of them the assistant's own and the
rest rev-agent-130's. Not one ordinary `gh api` write loses its permission. The
arm refuses the shape someone writes to *measure* a spelling and nothing anyone
writes to work, which is the repository's own standing rule — feed the hook on
stdin, do not run the command to learn its verdict — arriving from the other
side.

The arm also closes two shapes nobody asked it to: the backtick spelling of the
cut, which leaves `repos/o/r/pulls/` and carries no `$` to find it by (a
trailing slash is not a readable endpoint — measured, `gh api rate_limit/`
answers 404 where `gh api rate_limit` answers), and Class 3's whitespace-bearing
positional, which was filed as accepted and is now refused.

### Class 2's remainder, and where round 1's argument did and did not hold

Round 1 answered the variable-endpoint transitions with a control: with the
assignment off the line, the same commands are ALLOW at the base too, so what
refused them was the line-wide read finding an assignment's text. The reviewer
accepted that for the endpoint-keyed rules and showed it does not reach the
three rules that keep `$SCAN`: those had no endpoint test at all before this
branch, so the gate **creates** their permission rather than inheriting it. The
arm settles them, and round 1's four accepted rows move to BLOCK with it. The
argument was right about why `7bea85f` refused them and is superseded by a rule
that refuses them for a different reason.

### The assistant's push-back was right and its evidence was not

Round 1 declined the reviewer's suggestion to leave whitespace-holding spans raw
and priced it at four of #130's ten rows. rev-agent-130 built the faithful
version — the `=` clause kept — and none of the four moves, because in all four
an `=` stands before the span and the `=` clause drops it whatever the
whitespace clause does. The assistant's mutant had dropped the `=` clause too,
which was not the change proposed. The conclusion survived; the evidence did
not. The reason recorded beside those rows is now the reviewer's own measurement
— two ordinary issue writes in the quote-before-the-field-name spelling — and
the four-row figure is withdrawn.

### A backstop masks the rules in front of it

Found by the assistant while re-running its own mutations after adding the arm,
and it is the round's most transferable finding. Five single-clause mutations
that turned rows red before the arm existed — the reader reading no span, the
`$` handling, both backslash rules, the gate's normaliser — left **every verdict
row unchanged** afterwards: each removes the endpoint, and the arm then refuses
what they dropped. The suite would have gone on passing while those clauses did
nothing.

So the reason is pinned and not only the refusal. `says` reads the message, and
the arm's message is no other arm's, so a rule that stops working now shows as
the wrong sentence where it used to show as ALLOW. Measured after the change:
`no-dollar`, `esc-out` and `esc-in` are each caught by exactly one row, and in
all three cases that row is a `says` row. Without them the suite would have been
a set of checks that cannot tell the rule they name from the backstop behind it.

### Both filings, fixed

The sticky `=` was prose against code: the comment claimed less than the clause
does. The code is right — once a word carries an `=`, what follows in that word
is a continuation of a value, and dropping is what avoids a false refusal on
`"repos/o/r/pulls/5?foo=bar"/merge/` — so the sentence was rewritten rather than
the rule. And `endpoint_args` used `[[:space:]]` where `lib/command-scan.sh`
deliberately uses `index(" \t\n\v\f\r", …)` in six places; the library's comment
says why, and this reader now does the same. Not reproducible on this machine,
which has mawk and busybox awk: consistency with the library, not a measured
flip.

### Still open

- `#198` keeps the base/endpoint policy question it was filed for; the endpoint
  half is answered by `GH-130.6`.
- `#138` lands after this.
- The pull request body's cap readings are unchanged and unre-measured across
  three merges.

---

## 2026-09-21 03:40 +03 — #196 review round 3: the rule that needed two tokens

rev-agent-130's round 3, against head `6306546`. It verified rather than
re-asserted: the clean suite at that head (ALL CHECKS PASSED, 5534 `ok` rows,
zero FAIL), `arm-off` at 19 and `no-dollar` at 1, and it took the masking finding
seriously enough to change its own method — `no-dollar`'s single red row is a
`says` row, so a verdict-only count would have reported that clause caught while
nothing about its verdict moved. Class 1 it closed by trying to break the
normaliser rather than re-checking it: port, port plus query, userinfo, uppercase
host, `///graphql`, `graphql;x`, `//api.github.com/graphql`, a trailing space —
every spelling that escapes it is one GitHub answers Not Found to.

### One class left, in the one rule that needs two tokens

The fail-closed arm closes Class 4 wherever a rule needs ONE thing from the
command: the endpoint is either in the fragment or the write is refused. The
state rule needs two — `/pulls/` out of `endpoint_args`, `state` out of the raw
command — and a cut **between** them defeated it while the arm stayed silent,
the endpoint half being present and readable. `gh api -X PATCH repos/o/r/pulls/5
-f m="$(cat c)" -f state=closed` closes a pull request and was permitted, in six
spellings including the backtick.

The control that settles what kind of defect it is: the same two tokens with the
field **before** the substitution never stopped refusing. Tokenisation, not
policy.

The fix is the second of the two directions offered, because it generalises:
`line_was_cut` is `endpoint_seen`'s sibling, and a two-token rule reads the line
for its second token when a command on that line was cut. **It has to be
line-wide, and that is its honest limit** — a `$(` leaves a `$` at the end of the
fragment and can be seen per command, a backtick leaves nothing at all, `-f m=`
being indistinguishable from a field with an empty value. The endpoint is
deliberately given no fallback: a cut before the endpoint stays the arm's and
refuses, because a line-wide reading of an endpoint is the bleed #130 was filed
for.

Priced the way the arm was, on the same corpus and with the hook as the
instrument: 884 transcripts, 21,895 distinct commands, the 1,793 carrying `api`
fed to this hook and to a copy with the fallback removed. **Zero change
verdict.** It buys six measured refusals and costs nothing observed. None of
#130's ten rows can reach it either — every one writes to an issue, and this rule
needs `/pulls/` on the writing command's own endpoint.

### What the reviewer withdrew, and what it asked for instead

Round 2 it had warned the arm might refuse ordinary work; round 3 it measured the
warning instead of repeating it — 703 transcripts, 18,517 commands, 52 writes
with a substitution or parameter in the endpoint token, and exactly one verdict
change, its own probe loop. It also built the narrower arm it would have proposed
and dropped it on its own numbers, because it gives up two closures this one
makes for free. The one ask was a pinned row for the arm's accepted cost, and
`gh api -X POST "repos/$OWNER/$REPO/issues" -f title=x` now carries it: a cost
nobody writes down is a cost nobody can notice growing.

### Three reds of the assistant's own, and one of them is the better finding

The clean run caught three. The state pattern's call sites went from three to
four, the fallback being a fourth reader of it; `line_was_cut` was missing from
the sorted function table; and **`requirements.md`'s own grammar check caught a
malformed entry** — the assistant appended a second `- note:` to GH-130.3 instead
of extending the first, and the suite reported `the field note is given twice`.
That file's rules are load-bearing in a way this session had underweighted: it is
the only check that reads the shape of an entry rather than its content.

### The mutation harness caught its own drift

Restructuring the state rule into a nested `if` moved the anchor `state-arg`
mutates, and `edit.py` reported `MUTATION DID NOT APPLY` rather than judging an
unmutated copy and reporting a number. That is the self-test `mutate-hooks.sh`
keeps a row for, arriving in an ad-hoc harness: an edit that silently fails to
apply reads exactly like evidence and is none. The anchor was rewritten and a
pre-flight added that tries every anchor against a throwaway copy before the
batch runs, so drift is found before a run rather than after one.

Its first output reported three anchors missing, and all three were the
pre-flight's own limitation rather than drift — it extracts `edit` lines with
`sed` and mangles the multi-line ones. Confirmed by grepping the hook directly:
`gate-enum`, `arm-off` and `fall-off` each appear exactly once. Recorded because
a checker that cries wolf is a checker someone learns to skim.

### Still open

- `#201`, the pull request body edited through `gh api` reading as a state
  decision, and the unreadable-state-field measurement on `#198`: both filed by
  rev-agent-130.
- The cap readings, now five merges old, and the `awk` the arm and the fallback
  each add per writing command. Unmeasured by either side.

---

## 2026-09-21 04:55 +03 — #196 review round 4: the loop closes, and the last number gets measured

rev-agent-130's round 4 gates on nothing and closes the review. Every figure this
branch reported reproduces on its runs at `0d33b4c`: ALL CHECKS PASSED with 5550
`ok` rows and zero red, `revert` 36 (30 verdict + 6 `says`), `arm-off` 20 (17 +
3), `fall-off` 7 (6 + 1). Class 4's last member is closed in all six spellings
and the order control is unchanged.

**The sweep that mattered was the one in the other direction**, and it is the
reviewer's rather than this branch's idea: whether a line-wide second token
re-opens the bleed #130 was filed for. `gh api -X PATCH repos/o/r/issues/27 -f
m="$(cat c)" -f body="repos/o/r/pulls/5 has state=closed"` — a cut line naming a
state and a pull request — is BLOCK at `2019e08` and ALLOW here, because the rule
still asks `/pulls/` of the *writing command's own* endpoint. The fallback
reaches the line for its second token and never for its first. Across 35
re-measured shapes the only base-to-head refusal left is the arm's accepted cost,
which is pinned.

### The unexplained observation was explained, and by the reviewer

The refusal this branch handed over unreproduced is #202, reproduced first try.
The piece that defeats minimising is that it needs the **trailing `gh api`
write** — which is the part anyone drops first when reducing a case. In a quoted
heredoc bash substitutes nothing, so backticks in the body are literal;
`cs_normalise` reads them as a substitution anyway when a command follows the
delimiter, and the text between them becomes a command. So prose *quoting* a
release write is a release write. The pair that proves it is the mechanism and
not the word: the same backticks round an **issue** write are permitted.
Pre-existing, `cs_normalise`'s, BLOCK on both sides.

Handing it over unexplained rather than tidied was the right call, and it is the
fifth time this session that what found a defect was a real command failing
rather than a check.

### The one number neither side would defend, now measured

Both sides had flagged the cap readings as undefended: they were taken against
`7bea85f` and carried through five merges, and the arm and the state fallback
each add work per writing command. Re-measured against `2019e08`, the base this
head merges, minimum of five interleaved runs on a loaded machine at the 16 KB
cap:

| line, ~450 calls | `2019e08` | `0d33b4c` |
|---|---|---|
| nothing but unquoted `gh api` calls | 6.7 s | 8.9 s |
| the same with a quoted field value | 4.7 s | 6.8 s |
| the same with a substitution in each call | 9.5 s | 11.9 s |
| a control line with no `gh api` call at all | 7.7 s | 8.4 s |

The control moved nine per cent and nothing in this branch can have caused it, so
the added cost is roughly fifteen to thirty-five per cent rather than the forty
the raw ratios read as. Every reading is past the 5 s harness timeout on both
sides, which is GH-127 and #127's. The comment in the hook carries these numbers
now instead of the stale ones.

### What the review returned, across four rounds

Five classes named. Three closed by fixes on this branch — the endpoint
recogniser, the unreadable destination, and per-command text lost to the
tokeniser. One has a pre-existing member that lives on #198. The fifth is this
branch's own and the reviewer says it is the one it would keep: **a backstop
masks the rules in front of it**, found by re-running the mutations after adding
the arm and watching five single-clause mutations stop reddening any verdict row.

Two of this branch's pushbacks corrected the reviewer, and three of the
reviewer's findings corrected this branch — including the round-1 proxy, which
turned nine refusals into permissions with the suite green, and the round-2
finding that the fix for that class exhibited the class.

### Not merged

CLAUDE.md reserves it, the reviewer does not merge either, and the command is
Bertan's. The branch is mergeable and clean at `0d33b4c`; residual work is filed
as #198, #201 and #202, and #138 lands after this.

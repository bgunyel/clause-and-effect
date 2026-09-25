# 2026-09-25 21:16 +03 — #157: the dev-log naming and append rules are pinned, and the README says how an append is made

Branch `worktree-issue-157-devlog-naming-pin`, cut from `origin/dev-05` at
`72798ad` with `git worktree add --no-track`. Commit `b3198d0`, plus this
entry: two ahead of `origin/dev-05` once it is committed. Worked unattended
from `/mattpocock-skills:implement`. It has not had Bertan's review.

## The naming rule is held by a check

#157's naming half was decided on 2026-09-18 (`db06477`, `7141368`,
`33f7129`): an entry is named for the session that writes it. Nothing held
that. `checks/GH-157.sh` is a new issue file and holds it now.

- **What is read.** The Conventions section of `docs/dev-log/README.md` is
  read through `comment_reflow`, and each claim is pinned as one whole
  sentence.
- **GH-157.1 pins the naming rule:**
  - the name `devlog_YYYY-MM-DD_SESSION-NAME.md`;
  - `ListAgents` as the source of the session name;
  - a new bullet saying the name is never a number counted from existing
    entries, and why;
  - that entries named under the old convention keep their names.
- **It also checks the old wording is gone.** `lacks` asserts that
  `session-N` and `counts sessions within that day` are absent, as the triage
  brief asked. A section that gained the new rule but kept the old sentence
  would pass a presence check alone.
- **Nothing checks the files on disk.** The check reads only what the README
  says. Walking `docs/dev-log/` would be red on arrival, because the
  numbered entries are history.

## The append rule says how, and does not overclaim the guard

- **GH-157.2 pins the new append bullet.** An append is made with `>>` from
  Bash, and an entry that exists is never edited with Edit or Write.
- **It is worded as an instruction, not a claim about the guard.**
  `append-only-docs-edit.sh` does not yet refuse in a linked worktree (#159),
  so the README says the agent holds this rule there, not a guard.
- **The README also names the route around a heredoc refusal:** write the
  text to a scratch file, then run `cat <file> >> <entry>`.

## Mutation evidence

Most mutants ran through a scratch driver, `mini157.sh`. It sources the
library and `GH-157.sh` into a fake suite directory, with a mutated README
beside it.

- **Every mutant went red**, each on the claim it touched:
  - deleting each pinned sentence;
  - reverting to the `session-N` wording (3 FAIL);
  - adding the numbered name beside the new one;
  - adding the "are refused" claim;
  - moving the append rule into Entries;
  - renaming the heading (12 FAIL).
- **Every reflow stayed green:** 77 rewraps of the section at widths
  24–100. 44 of them break a word at a hyphen, which is the case the
  `comment_reflow` rejoin has to handle.
- **The full suite goes red too:**
  - deleting the naming bullet: exit 1, one FAIL;
  - dropping `README.md` from the header paragraph: exit 1, on the
    header-names-every-file row.

The first version of the driver was wrong, and the assistant caught it.
After the README path moved from `$REPO_ROOT` to `$SUITE_DIR/..`, every
mutant came back green. The driver was still pointing at the real README,
not the mutant. It was rebuilt so each mutant root carries its own
`.claude/hooks/`, and the rerun above is the one that counts.

## What review changed

The assistant ran the `code-review` skill with two sub-agents: one
reviewing standards, one reviewing against the spec. Four changes followed.

- **The README path was invisible to the header audit.** It was read
  through `$REPO_ROOT`. The check that the header names every file the
  suite reads (GH-102) only derives paths spelled `$SUITE_DIR/..` or
  `$HOOKS/`, and its comment accepts that limit only because every document
  was spelled that way. The path is now `$SUITE_DIR/../../docs/dev-log/README.md`,
  and the header's first paragraph names `README.md`. That adds two rows.
- **The README's first append bullet overclaimed the Bash guard.** It
  listed the verbs `append-only-docs.sh` refuses, including "a truncating
  `>`". Fed on stdin, nothing executed:
  - `cat a >| docs/dev-log/x.md` → exit 0;
  - `>docs/dev-log/x.md` at the start of a line → exit 0;
  - `cat a > docs/dev-log/x.md` → exit 2.

  The list was removed rather than pinned. The defect is filed as #233.
- **GH-157.2's text claimed more than its `lacks` checks.** The `lacks` is
  a single phrase. The text now names that phrase, and the note records the
  limit, which #145 owns.
- **Two comments in `GH-157.sh` were fixed.** One counted the `lacks` wrong.
  The other did not say the input is Markdown rather than comments.

The assistant also got a baseline wrong before any review. The first
baseline run was reading `check-hooks.sh` while the assistant added
`GH-157.sh` to `$SUITE_CHECKS`. That is the edit-mid-run hazard: bash reads
a script by byte offset. The run was stopped. The baseline was re-taken in
a detached worktree of `72798ad` at
`/tmp/claude-1000/.../scratchpad/base-72798ad`, which is still there.

## Counts

`bash .claude/hooks/check-hooks.sh`, measured:

| tree | results | FAIL | wall-clock |
|---|---|---|---|
| `72798ad` (`origin/dev-05`) | 5794 | 0 | 3 min 14 s |
| `b3198d0` | 5809 | 0 | 3 min 11 s |

The 15 new results are 13 in `GH-157.sh` and 2 in the header audit.
`generate-requirements.sh --check` passes.

## Open

- **#159.** When it lands, the README's worktree sentence becomes a
  statement about the guard, and GH-157.2's pin changes with it.
- **#233.** `>|` and a line-start `>` are permitted onto an append-only path.
- **#176** is the heredoc false refusal that the README's scratch-file route
  works around.
- **#157's third acceptance box is still Bertan's.** Only
  `worktree-issue-144-active-dev-base` is still to land with a colliding
  name.
- **The detached worktree at `scratchpad/base-72798ad`** is registered in
  `git worktree list` and should be pruned.


# 2026-09-25 21:51 +03 — #234 review round 1: the README's guard sentences are measured against the guards

Branch `worktree-issue-157-devlog-naming-pin`, on `origin/dev-05` at
`72798ad`. This round is `b67e13d`, on top of `eedea35`, plus this entry:
four ahead of `origin/dev-05` once it is committed. Not pushed; the pull
request's body is corrected when it is.

rev-agent-157 reviewed `eedea35` and posted seven findings, A to G, three
gating. The assistant reproduced each gating one before changing anything,
and accepted all seven. It pushed back on one point, D's suggested fix,
which left a sibling open.

## A: the absence was one spelling

rev-agent-157 measured `session-<n>` and `session-n` added beside the new
rule, and both stayed green: `lacks 'session-N'` asked for one spelling.
The assistant took the reviewer's suggestion and asks for the stem, a
lowercase `session-`, which every spelling of the numbered name carries.
The Conventions section has none today. The whole README cannot be asked,
because its Entries section links every numbered name.

Two shapes are still unseen, and the header names them: a numbered name
without the stem, `devlog_<date>_3.md`, and the counting rule in other
words. Both were measured green (rows 18 and 19 below).

## B: two README sentences about guards were false

The assistant wrote both in round 0 and fed neither to its guard.

- **The heredoc trigger.** The README said a heredoc append whose prose
  "mentions a path" can be refused. Fed to `append-only-docs.sh` on stdin
  this round, nothing executed:

  | heredoc text | exit |
  |---|---|
  | names a path only | 0 |
  | `sed -i`, no path anywhere in the text | 2 |
  | `rm` or `mv`, a path after it on the line | 2 |
  | `>`, a path after it on the line | 2 |
  | `rm` on one line, its path on the next | 0 |
  | `cat <file> >> <entry>`, no heredoc | 0 |

  The README now says prose that reads as a command rewriting an entry can
  be refused, gives `sed -i`, `rm`, `mv` and `>` as examples, and cites
  #176.
- **The Edit guard.** The README said `append-only-docs-edit.sh` is off in
  every linked worktree. Fed on stdin, an Edit of this branch's own entry
  exits 0 with the project directory set to the main checkout, and 2 with
  it set to the worktree. That is #159's own table, row 4. The README now
  states that narrower case. The requirements.md citation for #159 now
  quotes the issue's title as a title and says what was measured.

The class is a sentence about a guard, pinned as text. A pin of text is
evidence about the text only. The round-0 header also said "when #159
lands the sentence and its pin change together", and nothing made that
happen. So the assistant added **GH-157.3**. It feeds the guards the
README's own examples at today's verdict: seven heredoc and `cat`
commands to `append-only-docs.sh`, and one Edit to
`append-only-docs-edit.sh` under each project directory. The #159 case is
asserted at ALLOW, and its label says BLOCK is the right verdict.

GH-157.3 is a `doc-claim` with both directions, so it is outside the
invariance families' scope. The Edit fixture is a nested directory and not
a real worktree, because the guard strips the project directory off the
path and resolves no repository.

## C: the round-0 mutation claim was broader than its measurement

The round-0 entry above said, under *Mutation evidence*, that every mutant
went red, including "adding the numbered name beside the new one". The
assistant measured that for the `session-N` spelling only. rev-agent-157
measured two spellings that stayed green (finding A). The claim was wrong
as written. The pull request's *Evidence* section says the same and is
corrected when the branch is pushed.

## D: the fix suggested left a sibling

rev-agent-157 measured a qualifier inserted between two pinned sentences
of one bullet: green. It suggested one `holds` per bullet, from `- `
through the last sentence. The assistant measured that this still misses a
qualifier appended after a bullet's last sentence. Each pin therefore ends
on the `- ` that opens the next bullet. Rows 14 to 16 below are that
sibling, red now. A new bullet between two pinned ones is still unseen,
which is #145's limit, and row 13 is that case, green.

## E, F, G

- **E.** #176 is now cited beside the scratch-file route in the README, in
  `GH-157.sh`, in GH-157.2 and GH-157.3, and in requirements.md.
  Citing the review also cites #234, which the suite requires an entry
  for. The first full run of this round was red on exactly that (5813 ok,
  1 FAIL), and the assistant added the entry.
- **F, voice.** The round-0 entry used passive voice for four of the
  assistant's own errors and corrections. Restated here, active:
  - The assistant built the first mutation driver wrong: it read the real
    README, not the mutant, so every mutant came back green. The assistant
    rebuilt it.
  - The assistant removed the verb list from the append bullet rather than
    pinning it.
  - The assistant fixed the two `GH-157.sh` comments.
  - The assistant edited `check-hooks.sh` while its own baseline run was
    reading it. The assistant stopped that run and re-took the baseline in
    a detached worktree.
- **F, attribution.** The round-0 entry credited no one for the code-review
  findings. The assistant read the two sub-agents' transcripts this round:
  - the **spec** reviewer found the `>` overclaim, filed as #233;
  - the **standards** reviewer found the README path hidden from the header
    audit, GH-157.2 promising more than its `lacks`, and both comments.
- **F, a machine-local path.** The round-0 entry names the baseline
  worktree by its full `/tmp` path. That is a path on one machine, and it
  should have said "a detached worktree in the session's scratchpad". It
  stays, because the entry is append-only.
- **G.** The header's example of a line opening with `#` could not happen:
  every issue number in the section is in parentheses. The example is now
  one that can happen. The `check-hooks.sh` header line that broke a
  sentence mid-way is rewrapped.

## Dead ends this round

- **The first stdin probe was refused by the live hook.** The assistant
  wrote it as one compound Bash command with heredocs naming dev-log paths.
  The live `append-only-docs.sh` refused that command itself, so nothing
  ran. The assistant moved the probe into a script file.
- **The first mutation driver truncated before reading.** It wrote each
  hook mutant with `open(p, "w").write(sub1(open(p).read(), ...))`, which
  truncates the file before the read. Its anchor check failed loudly on
  the first hook row. No result was taken from it.

## Mutation evidence

Every row was run in a scratch copy through a reduced driver. The driver
sources only `library.sh` and `GH-157.sh`, against a mutated README and a
mutated copy of the hooks. The unmutated control is ok=18, FAIL=0.

| # | mutant | result |
|---|---|---|
| 1 | delete the naming bullet | red, 1 |
| 2 | revert to `session-N` with its counting rule | red, 3 |
| 3 | delete the append-when bullet | red, 1 |
| 4 | delete the append-how bullet | red, 1 |
| 5 | move the naming bullet under Register | red, 1 |
| 6 | rename `## Conventions` | red, 8 |
| 8 | reflow at 60/4, 40/2, 100/2 and 24/2 columns/indent | green, all four |
| 9 | add `session-<n>` beside the naming bullet | red, 1 |
| 10 | add `session-n` | red, 1 |
| 11 | qualifier between two sentences of one bullet | red, 1 |
| 12 | qualifier before the Edit-guard sentence | red, 1 |
| 13 | new bullet: Edit and Write are refused (#145) | green, as named |
| 14–16 | qualifier after a bullet's last sentence, three bullets | red, 1 each |
| 17 | restore the round-0 "mentions a path" wording | red, 1 |
| 18 | numbered name without the stem | green, as named |
| 19 | counting rule in other words | green, as named |
| H1 | hook: drop the `sed`/`perl -i` rule (#176-shaped) | red, 1 |
| H2 | hook: drop the truncating `>` rule | red, 1 |
| H3 | hook: drop `mv` from the verb list | red, 1 |
| H4 | Edit hook: match `(^\|/)docs/…` (#159-shaped fix) | red, 1 |
| H5 | hook: read the `rm` rule across lines | red, 1 |

Row 6 is 8 FAIL and not the reviewer's 12, because there are fewer pins.

## Counts

`bash .claude/hooks/check-hooks.sh` on this round's tree, measured, with
the input files' sha256 unchanged across the run:

| tree | results | FAIL | exit | wall-clock |
|---|---|---|---|---|
| `eedea35` (round 0) | 5809 | 0 | 0 | 3 min 11 s |
| `b67e13d` | 5814 | 0 | 0 | 3 min 10 s |

The issue file's results went from 13 to 18:

- 1 `tok`;
- 5 `holds`, down from 9, one per bullet;
- 3 `lacks`;
- 9 guard checks, for GH-157.3.

`generate-requirements.sh --check` passes.

## Open

- **#159 and #176.** When either lands, its GH-157.3 check goes red, and
  the README sentence moves with it.
- **#233, #235, #236 and #232** are unchanged by this round.
- **The pull request body.** It is corrected at push time. Correcting it
  earlier would describe commits the pull request does not yet carry.
- **For Bertan.** #157's third acceptance box and the `base-72798ad`
  worktree are as before.


# 2026-09-25 22:05 +03 — #234 round 1, addendum: the rewrap figure re-measured

Before pushing, the assistant re-ran the round-0 rewrap measurement against
this round's pins, rather than carry its figure into the pull request body.
The section was rewrapped at every width from 24 to 100, with a 2-space
continuation: 77 rewraps, all green. 48 of them break a word at a hyphen,
not the round-0 entry's 44, because the README's wording changed.

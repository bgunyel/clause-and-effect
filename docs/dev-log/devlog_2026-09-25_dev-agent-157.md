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

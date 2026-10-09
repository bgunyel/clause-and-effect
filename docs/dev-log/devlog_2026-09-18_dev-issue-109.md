# 2026-09-18 · dev-issue-109 — all seven hooks at once, and a refusal that names a refused push

**Branch** `worktree-issue-109-cross-hook-checks`, cut from `origin/dev-05` at
`33f7129` and proposed into `dev-05`, two commits ahead of it. The session was
worked by the assistant, unattended, from Bertan's `/implement` on #109. **Check suite 4281
results, all passing**, measured at the second commit. The count on `dev-05`
itself was not re-measured, so no delta is given.

## The cross-hook check found one defect, and it is in a message

Every check in `check-hooks.sh` ran one hook. The harness runs all seven Bash
hooks and permits a command only if every one exits 0. So the new rows run each
spelling that CLAUDE.md's boundary section or a refusal message tells an agent
to write through all seven. They run in the order `settings.json` registers
them, from the lifecycle fixture's worktree where that spelling is meant to
work. That makes 41 spellings, including the fifteen `gh issue` subcommands and
both routes to a worktree branch at `origin/dev-05`.

All 41 are permitted. The finding came from reading the messages for spellings.
`no-commit-to-main.sh` refuses a push to `main` with "Push your dev-NN branch
and open a PR instead", and `no-git-push.sh` refuses that push from a worktree
on `dev-05` and from the main checkout alike. The assistant reproduced both
refusals in a throwaway fixture before filing. The refusals are right under
US-2, so the defect is the sentence. It is filed as **#164**, a sub-issue of
#36, per #103 Q18.

The assistant recorded #164 as a `says` row labelled as a gap, not through the
`gap` helper. The reason: `gap` carries a right verdict and today's, and here
the verdict is correct and only the message is wrong. The row asserts the
sentence is still there, so #164's fix turns it red. That matches the outcome
`gap` describes, but it bends that helper's rule, and a reviewer should judge
it. GH-164 is `gap → #164`.

## What else landed

- **Timing (GH-109.1).** Each Bash hook finishes a 200-line heredoc, with four
  separators on every body line, in 12–57 ms (under 1 s, fastest of three). The
  bound holds because `cs_normalise` drops a heredoc body before any pass reads
  it. The same 200 lines run as **live** commands took `no-pr-decisions.sh`
  3.1 s, `no-commit-to-main.sh` 2.1 s and `no-git-push.sh` 1.1 s. That is #127's
  per-fragment cost. It is left to #127 and recorded in the section, not
  checked.
- **Messages (GH-109.2).** Every refusal arm of `no-git-push.sh` and
  `no-pr-decisions.sh` has a `says` row that reads its sentence through to the
  end. Each file's count of refusal arms (19 and 16) is also a literal, so a new
  arm moves the count.
- **Configuration (GH-109.3, GH-109.4).** The whole registration is one literal
  table: event, matcher, command and timeout per hook, in order. A new `ran`
  record, written wherever a check runs a registered hook, requires every hook
  `settings.json` registers to have been run under a tag. `worktree.baseRef`
  was already pinned to `fresh` by GH-99.2, and is not pinned twice.

## Mutation evidence, and what was already caught

Four registry rows were added: a pass slowed past the bound, two messages each
losing the sentence their row reads, and a second hook refusing `gh pr view`.
They ran as a named selection. The baseline was green over 183 requirements,
all four were caught, and `.claude/hooks/` came back byte-identical.

The `settings.json` mutations cannot be rows, because the harness copies only
`.claude/hooks/`. The assistant ran six by hand, each from a per-file backup
restored and sha256-checked, and all six went red. Two of the issue's named
mutations were **already caught before #109**. One timeout set to 1 was caught
by GH-96.2's timeout set. `no-git-push.sh` unregistered was caught by three
older checks. What only the new checks catch is:

- the Edit hook's timeout;
- a registered hook no check runs;
- two Bash hooks swapped in order;
- the run record switched off.

The section comment says which check caught which mutation.

## Corrections made in review

The assistant's first draft had three errors that its own `/code-review` pass
found:

- **Counts.** The `mutate-hooks.sh` header still stated 32 mutations, 6 files,
  40 IDs and 158 active requirements, and its timing sentence carried the old
  run count. The first draft also inserted its paragraph into the middle of a
  sentence of that header. The assistant corrected all of these.
- **Prefix fragments.** Several arms from older sections were pinned only by
  the prefix that told them apart. So the remedy half of the sentence was
  unread: the main checkout's "Leave the commits on the branch", the `gh api`
  release read, and the reason a release is public.
- **Spellings.** The cross-hook set lacked CLAUDE.md's two `gh api` create
  forms and a plain commit.

Each of these was added and passes.

## Open

- #164: reword `PUSH_REFUSE`, then turn its gap row into an ordinary check.
- #127: a bound on per-fragment cost. The 200-live-line figures above are the
  first measurement of it on an ordinary multi-line command.
- #134, #135 and #136 were in flight in parallel sessions. Each changes the
  `REQUIREMENT_SHAPE` literal and the registry counts that this branch also
  moves. Whichever lands second has to re-count, not merge the numbers.

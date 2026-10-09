# 2026-09-13 · session 1 — the agent boundary audited against its own specification

**Branch** none: the session changed no files, by decision (Q34 below), and made
no commits. Audited at `origin/dev-05` `750aace`, **164 commits ahead of `main`**
when this entry was written. **Check suite: 499 `check` calls, green.**

**How this entry was written.** Nobody wrote it at the end of the session. The
assistant wrote it on 2026-09-15, in the session that built #104, from the record
the grilling left: the body of #103, and the bodies of the nine sub-issues of #36
it filed (#94 to #102). What is below is what those issues say and nothing
recalled beside them. They record the decisions as taken jointly by Bertan and
the assistant, and they do not record which of the two proposed each one, so this
entry does not either.

---

## Nothing connected #36's requirements to the checks meant to verify them

#36 specified the agent boundary in 32 user stories, a set of implementation
decisions and two amendments, and all of its stage tickets had closed. The
evidence that the boundary held was `check-hooks.sh`, grouped by the review that
found each defect rather than by the requirement each check establishes. So "is
user story 9 verified?" was answered by reading a 4,000-line file, and "the suite
is green" said nothing about a requirement no check named. The suite's own header
already said so: a check suite is evidence about the cases it names and about
nothing else.

The audit mapped every story, decision and amendment onto the existing checks by
hand. It found gaps:

- no check read the refusal messages of `no-git-push.sh` or `no-pr-decisions.sh`
  (story 7);
- most `gh issue` subcommands were unchecked (story 14);
- no check confirmed that every registered hook was exercised;
- the eight `PreToolUse` timeouts were unpinned;
- mutation-checking existed only as prose.

## The audit found nine defects, and filed each as a sub-issue of #36

| issue | kind | finding |
|---|---|---|
| #94 | defect-permitting | a push from a subdirectory of the main checkout was permitted: the worktree test compared paths as strings |
| #95 | defect-permitting | every hook permitted when `jq` was absent or its input malformed |
| #96 | defect-permitting | a line long enough to outlast the 5 s hook timeout was permitted |
| #97 | defect-permitting | `gh release edit --draft=false` and `gh release upload` were permitted |
| #98 | defect-permitting | the suite read any exit other than 2 as ALLOW, so a crashed hook passed |
| #99 | defect-permitting | `baseRef: head` forks from local HEAD, not the active dev branch's tip |
| #100 | doc-claim | branch-hygiene's sweep classes and the stale-branch report computed different things |
| #101 | doc-claim | "probe" used for the load contract's `command -v` tests, against CONTEXT.md |
| #102 | doc-claim | the suite's header misstated its own scope |

Seven of the nine are about the hooks or the documents that describe them. #98 is
about the evidence, which is the one that decided the order below: tagging checks
while a crashed hook still passed would have counted a crash as coverage.

## What was decided

The decisions carry the session's question numbers, so a child issue can cite
one. #103 holds the full list; these are the ones that shape the work.

- **Audit and gap-fill, not re-verification** (Q1). The existing checks are
  mapped; new checks go only where there is a gap. Re-verifying every existing
  check by mutation is a backlog item (Q8).
- **A requirements file comes first** (Q5, Q11), because without it "gap" has no
  definition: `.claude/hooks/requirements.md`, beside the suite and outside the
  `docs/` taxonomy (Q6). IDs are never renumbered or reused, and a requirement
  that stops being true is marked, never deleted.
- **Three ID families** (Q7, Q12, Q13, Q14): `US-n` verbatim from #36, `FR-n` from
  its decisions and amendments, and `GH-<n>[.m]` from the boundary issues after
  it, with a `kind`. #37–#41 get no IDs; their acceptance criteria are carried
  verbatim in a provenance section, each mapped or dropped (Q23).
- **Coverage is computable** (Q2, Q15): checks carry IDs as tags the suite reads,
  and an active requirement is covered by at least one refusing and one
  permitting check, unless it declares itself one-sided. #36's "both directions,
  always", made a rule a machine can apply.
- **`--matrix`** prints ID → checks → status, generated from the tags (Q9).
- **The matrix is kept whole by a written rule and a check** (Q16): a pull
  request that fixes a hook defect appends its `GH-<n>` entry, and every `#<n>`
  cited in the suite has an entry or a stated reason.
- **Vocabulary** (Q29): anything in `check-hooks.sh` is a *check*; *test* means
  pytest under `tests/`.
- **Policy on the defects**: a defect found during this work is filed as its own
  bug with a check at the correct verdict, never pinned to its wrong one (Q18);
  a hook that cannot read its input fails closed (Q19, Q27); ALLOW means exit
  exactly 0 (Q20); the suite builds its own fixture repository (Q21); every
  read-only `gh release` action is permitted and every other refused (Q26); a
  16 KB line cap with linear passes and a timing check (Q28).
- **Nothing changes in this session** (Q34). The CONTEXT.md edit, the todo item
  and this entry arrive with #104's pull request.

## Seven work issues, in order

#103 holds them as its sub-issues, with the order as native dependency edges:

1. #104: the requirements file, the tags, the coverage check, `--matrix`
2. #105: fill the gaps the matrix reports
3. #106: invariance families
4. #107: a mutation harness
5. #108: robustness, environment and fail-direction checks
6. #109: timing, refusal messages, configuration integrity, cross-hook consistency
7. #110: the live acceptance runbook

#104 waits on #94 and #98; everything else waits on #104.

## Open when the session closed

All of it. Of the nine defects, #94 and #98 block #104, and #95, #96 and #97 block
#108 and #109. By 2026-09-15 all nine had closed, and one new defect had been
found beyond them, #127 — a command inside #96's line cap that still outlasts
the timeout.

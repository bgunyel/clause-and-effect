# 2026-09-20 · session 3 — #155 round four: the merge, and five conflicts with two real sides each

**Branch** `worktree-issue-155-stub-gh-into-farm`, the branch of PR #161 into
`dev-05`. Worked unattended by an AI assistant, answering the third review of
that pull request. Two findings, both about the branch's relation to `dev-05`
rather than about its code. **Check suite 3810 → 5093 results on the merged
tree, all passing, and 5093 on a `gh`-less farm as well.** Nothing the merge
touched went red.

## What the merge was

Fifty commits behind, thirty-three of them touching `.claude/hooks/`;
`check-hooks.sh` grew 10,748 → 12,340 lines on `dev-05` while this branch took
it to 11,169. Five conflicts. **Both sides of every one of them is real work**,
which is the only reason this entry is worth writing: none of the five could be
resolved by preferring a branch.

### The three hook files

`check-hooks.sh`, three hunks, every one a literal. Two are the registry counts
— 31 rows and 29 caught here, 52 and 50 on `dev-05` — and the merged registry
holds **both** sets of rows, so neither side's number is right and the answer is
not their sum either. They were re-derived from the merged file: **54 and 52**.
The third hunk is the declared requirement-ID list; `dev-05`'s wins because it
carries `GH-133`'s change of direction from `gap` to `refuse-only` plus four new
IDs, with `GH-155.1:static` added back.

`mutate-hooks.sh`, four hunks. The registry itself keeps every row from both
sides, twelve in total. The interesting one is the `MEASURED` paragraph:
`dev-05` had rewritten it into a *"THAT MEASUREMENT IS NOT CURRENT"* record that
enumerates every named selection run since the last whole-registry run. That is
a better shape than what this branch had, so it is kept, and #155's two rows are
folded into its list rather than left beside it — carrying the host-qualification
that PR #161's first review asked for, which would otherwise have been lost to
the merge. The four counts are what `--list` prints, re-read rather than
adjusted: 54 rows, 52 real mutations against 7 files, naming 46 requirement IDs,
2 self-tests.

`requirements.md`, two hunks, both pure additions at the same insertion point —
`GH-128`, `GH-156`, `GH-171`, `GH-141` from `dev-05`, `GH-155.1` from here, and
both the `#161` and `#173` citation entries. Nothing had to be chosen between.

### The two dev-log conflicts, which are the reason this is finding 5

`add/add` on `devlog_2026-09-17_session-5.md` (178 lines here, 414 there) and
`devlog_2026-09-18_session-1.md` (121 here, 51 there). Each side is longer in
one case and shorter in the other, so `--ours` and `--theirs` each delete a real
session record.

**This repository has already answered this, twice, and the answer is written
down in `docs/dev-log/README.md`.** Entries written as sessions 2, 3 and 4 were
renumbered 7, 8 and 9 when they collided on a `dev-05` merge, and collided again
when another branch's entries took 7; `db06477` then settled the convention —
name an entry for the *session* that wrote it rather than for its position in
the day. `dev-05` already carries two such names,
`devlog_2026-09-17_session-dev-issue-117.md` and
`devlog_2026-09-17_dev-issue-141.md`.

So `dev-05`'s two entries keep the paths they hold, and this branch's two become
`devlog_2026-09-17_session-issue-155.md` and
`devlog_2026-09-18_session-issue-155.md`. Both records survive whole; nothing was
merged into one file, which would have produced an entry with two different
session headings.

**Their headings were corrected to match their new names**, which is not a
violation of the append-only rule but an application of it. ADR 0003 says a file
is history once it is present on the active dev branch **at the merge base**, and
a draft before that. Both were absent from `origin/dev-05` at `897bdff`,
verified with `git cat-file -e`, so both are drafts and may be rewritten — and
the README's own precedent did exactly this, correcting a renamed draft's heading
with its file name.

The `Edit` tool was used for those two headings because `append-only-docs.sh`
refuses a removal or a truncating redirect anywhere under the three append-only
directories without being able to tell a draft from history — which is precisely
the split ADR 0003 describes, and the reason it names `Edit`/`Write` as the route
for a draft. That is the documented path, not a way around the hook.

## Finding 6: every measured claim was measured at the old base

The reviewer's point, and it was right: `3810`, `3786 before this branch`,
`175/157/112`, `GH-155.1` at nineteen checks, `31` registry rows and the
`gh`-less equality all described the branch at merge base `897bdff`, and
thirty-three `dev-05` commits had moved `check-hooks.sh` underneath them. Every
one was re-derived on the merged tree rather than adjusted.

## Measured, on the merged tree

`check-hooks.sh` **ALL CHECKS PASSED, 5093 results**, exit 0 — on the ordinary
PATH **and** on a farm of 3229 symlinked executables with `gh` removed, run under
`env -i`: **5093, exit 0**. The same count on both, which is the property #155
exists to make true and the one #150 could not show. It survives the merge.

182 requirements, 165 active, 165 covered, 12 marked a gap. Registry 54 rows.
`GH-155.1` is 19 checks, unchanged by the merge.

The derivation added this week still reads twelve lines out of the merged
`check-hooks.sh` and derives the same four PATHs, and the case-arm count is still
1 — `dev-05` added no consumer of `report_says`.

## Two things found and not fixed

`dev-05`'s `docs/dev-log/devlog_2026-09-17_session-5.md` has the heading
`# 2026-09-17 · session 2 — #128: …`, while
`devlog_2026-09-17_session-2.md` is a different session 2. So the file name and
the heading disagree on `dev-05`, in the same family of defect the rename above
was careful to avoid. It predates this branch, it is not something the merge
introduced, and correcting it would mean rewriting a file that **is** history by
ADR 0003 — present on `dev-05` at the merge base. Reported rather than touched.

Writing this entry was itself refused once, and the refusal was correct.
`append-only-docs.sh` read a sentence describing what it guards — a redirect
character quoted next to one of the three directory names — as a redirect into
that directory. That is consequence 3 of CLAUDE.md's *deliberately left open*
list, prose refused because it reads like the guarded act, and it is one edit
away rather than a defect. The sentence was reworded; the hook was not worked
around.

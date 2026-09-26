# 2026-09-20 · session 5 — #158 round three, and a second merge of dev-05: a claim lives in more places than a finding names

**Branch** `worktree-issue-144-active-dev-base`, still proposed into `dev-05`.
`origin/dev-05` merged into it a second time, at `2a52322` (#155), eight commits
on from the first merge. **Check suite 5160 → 5190 results, all passing**;
requirements 188 → 190, of which 173 active; mutation registry 59 → 63 rows, 61
real. One requirement was added, `GH-144.8`. Twelve registry rows were run as one
selection against the merged tree; all twelve caught, and unlike the previous
merge none survived.

Worked by the assistant against the third review of PR #158, machine-authored
and posted through Bertan's account, cited on this branch as *the third review
of PR #158* for the reason session 4's entry gives.

## A correction applied where the review pointed is a correction in one of N places

Three of the round's four findings were a previous round's finding reappearing
one file over. The count taken out of `check-hooks.sh` in round two had a copy in
`requirements.md`. The hook under-count fixed in `CLAUDE.md` had a copy in the
SessionStart report. The subset framing struck in three documents had a fourth
copy in `CONTEXT.md`. The review named the shape before naming the fixes and
asked for a grep rather than a patch of the three lines it cited.

The grep is what makes this entry worth writing, because it found sites the
review had not:

- **Finding 2 had six sites, not three.** The review named three degraded-read
  messages in `report-stale-branches.sh`. Two more say the same thing — the
  skipped-fetch line, and `active dev branch: none` — and so does a paragraph of
  that file's header. All six name both hooks now.
- **Finding 3 had three sites, not one.** `CONTEXT.md` was named;
  `no-pr-decisions.sh`'s own header and `GH-144.7`'s note carried the same claim.
- **And one defect no finding named at all.** `GH-144.7`'s note attributed the
  claim to *"GH-144.1's note"*, which never contained it. A citation to a
  sentence that does not exist: no check catches it, and a reader who trusts it
  does not go looking.

The converse was also checked, and is the half that is easy to skip. `merge
settings: NOT READ` names `no-work-on-stale-branch.sh` alone and was left
alone — the merge settings arm that guard's detectors and feed no base rule, so
naming a second hook there would be wrong. A correction applied one site too far
is the same defect as one applied one site too short.

## What a stale read costs, measured rather than argued

Three documents said the cost of stale refs is "a refusal rather than a permit".
The assistant built a fixture holding only `origin/dev-05` after a rotation to
`dev-06` and drove the hook:

```
PERMITTED  gh pr create --base dev-05    <- lands on the branch on its way out
REFUSED    gh pr create --base dev-06    <- the correct base
```

Both directions are wrong. The claim was true only relative to pre-#144
behaviour, which is the *subset* reasoning this same pull request had already
struck as an invalid defence in `GH-144.6` — surviving in three documents nobody
had grepped. `GH-144.8` was added for the report, split from `GH-108.9` because
the two fail apart, with four checks and two registry rows because its own two
halves do.

## The second merge: the conflict was the only reason anyone looked

Four conflicts, of which one mattered. `#144` and `#155` rewrote the same
`GH-108.6` argument from opposite sides in the same week.

`#144` narrowed **what** the section claims. Its heading — "the pull request hook
starts no process" — stopped being true when `read_active_dev` landed, so it
became a claim about every *refusal* the hook makes on the text of a command,
which survives a hook that reads refs.

`#155` fixed **which** environments make that claim evidence. `plain` is the
invoker's PATH, so on a host with no `gh` the `plain` row and the `gh`-off-PATH
row are the same environment asserting the same thing twice; the farm always
holds a `gh`, so the contrast is a genuine one-name contrast on every machine.

Neither survives alone, and both were kept. The heading is `#144`'s, because
`#155`'s is the sentence `#144` made false. A paragraph names the collision, so
the next reader does not have to reconstruct it from two branches. `#155`'s
prose describing "the same two payloads" was dropped: the merged loop runs four
payloads over nine environments, which is a loop neither branch had on its own.

## A premise checked rather than taken on authority

The review's second point was that `#155` added some 352 lines to
`no-pr-decisions.sh` alongside `#144`'s `read_active_dev` — two environment reads
merged silently into one hook — and asked for the merged hook to be read whole.
The assistant checked the range before reading: `git diff 5ff5f10 origin/dev-05
-- .claude/hooks/no-pr-decisions.sh` is empty, and so is the diff of every hook
file in the merge. `#155`'s insertions went into `check-hooks.sh`, 491 of them,
and "two guards weaker than their prose" names two *checks* in that file rather
than two hooks. Bertan's review agent confirmed the error and its cause: it had
diffed from `897bdff`, the original fork base, which sweeps in `#139`, `#117` and
`#133` — work three rounds had already read.

The premise was wrong; the worry under it was not, and the response was to the
worry. What the merge really carried is 491 clean-merged lines in the file that
holds every check, and a `#155` row registered against the same `GH-108.6` that
`#144` narrowed.

## The selection, and the row that did not survive

Twelve rows against the merged tree: `#155`'s two, `#144`'s eight, and
`GH-144.8`'s two. All twelve caught, `.claude/hooks/` byte-identical after.

`pr-hook-reads-gh-off-the-environment` — the row the merge put at risk, and the
one this selection existed to ask about — is **still caught, red in `GH-108.6`
and in nothing else**. Narrowing that requirement's claim did not cost the row
its evidence.

That is worth stating plainly because the previous merge's selection found the
opposite, and the two outcomes are indistinguishable without running them. A
green suite said nothing about either. The rule this pair establishes is the
same one session 4 drew and this session confirms from the other side: after a
merge, a registry row's pre-merge verdict is a claim about a tree that no longer
exists.

## What was measured

- Check suite: **5190 results, exit 0**, on the merged tree.
- requirements.md: **190 entries**, 173 active, 173 covered, 12 marked a gap.
- Mutation registry: **63 rows**, 61 real against 7 files, naming 52 requirement
  IDs.
- Twelve rows run as one selection, all `caught`, `.claude/hooks/` byte-identical
  after.

## What the next session inherits

The branch merges and the suite is green on the merged tree. The registry rows
outside that selection have not been run since the files they run against
changed, which is the standing state of that registry rather than a regression
of this merge. Nothing is pushed and nothing is posted; the pull request is
still open against `dev-05`.

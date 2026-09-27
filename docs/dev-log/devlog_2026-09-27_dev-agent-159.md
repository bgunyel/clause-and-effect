# 2026-09-27 17:49 +03 · dev-agent-159 — #159: the append-only Edit guard reads a path off its own segments, and works in a worktree

Branch `worktree-issue-159-worktree-append-only`, cut from `origin/dev-05`
at `2303e9b` with `git worktree add --no-track`. Commits `1ab0c7a` to
`45d9c16`, plus this entry: six ahead of `origin/dev-05` once it is
committed.

## The guard was off where every agent works

`append-only-docs-edit.sh` stripped `CLAUDE_PROJECT_DIR` off the edited
path and matched the rest at `^docs/`. In a session started in the main
checkout, an entry in a linked worktree came out as
`.claude/worktrees/<name>/docs/dev-log/<entry>` and matched nothing. An
Edit or a Write of it was permitted. The baseline copy of the hooks was
fed tool calls on stdin to confirm the defect. The cross-checkout Edit was
permitted in both directions, and the same-checkout Edit was refused.

The fix is the triage brief's second route. The Edit half now refuses when
a `docs/<dir>/` pair, bounded by `/` on both sides, appears anywhere in the
normalised absolute path. The project root now only resolves a relative
path and shortens the path the refusal names.

- **The trade is taken and recorded.** An identically-named existing entry
  in a repository that is not this one is now refused. The trade is written
  in the hook's comment, in the commit `1ab0c7a` and in the label of every
  row that asserts it (`ACCEPTED TRADE, not a defect:`).
- **The git route was not taken.** Resolving the repository with
  `git rev-parse` fixes the worktree. It still leaves the two halves
  disagreeing about every other checkout.

## The triage brief's premise about the Bash half was false

The brief said the Bash half, `append-only-docs.sh`, already bounded the
directory on the left. It did not. `rm -rf notdocs/dev-log` was refused,
measured on stdin. Acceptance criteria 3 (near-misses permitted) and 5
(both halves classify one path set alike) could not both hold without
changing it. The assistant bounded the Bash half on the left by the class
that already bounds it on the right. Each rule's stretch has to end in
that boundary, because the rules had already consumed the character in
front of the path.

- **The first draft refused a documented append.** Its boundary allowed a
  `>`, so the second `>` of `>>docs/dev-log/<entry>` (no space) read as a
  truncation's boundary. The assistant found this while writing the draft.
  The stretch's boundary now excludes whatever the stretch excludes.
- **The second draft permitted a refused spelling.** Review found it:
  `cp -tdocs/dev-log x`, a `-t` with its value attached, was refused on
  dev-05 and permitted by the boundary. An option's letters may now stand
  after the boundary. Both drafts' cases are pinned.
- **One case is not this branch's, and was filed.** The redirect rule's
  stretch runs across a `;`. So `echo x > a.md; cat <entry>` is refused, on
  dev-05 as on this branch. The assistant filed it as #259 rather than
  widen the branch.

## The checks, and what can fail them

`checks/GH-159.sh` declares GH-159.1 to .3. Their files are generated. The
checks use their own fixture: a repository with a linked worktree inside
it, and a second, unrelated repository.

- **GH-159.1** asks each case of a literal table from all three checkouts,
  with each of the first two as the project directory. The cases are
  spelled absolutely and relatively, and through `./` and `docs/..` in the
  project directory's own checkout. Two further rows ask the ADR 0003
  correction on a worktree's entry.
- **GH-159.2** feeds both halves one path set: three directories, three
  near-misses each, three checkouts. The Bash half gets five command forms
  per path. Both halves are held to the one literal verdict each path has.
- **GH-159.3** derives which hooks the question reaches from
  `settings.json` and the hooks' code. A derived hook with no table of
  cases is red. The derivation is driven against a fixture of nine hooks.
- **GH-157.3's four cross-checkout rows flipped.** They asserted the defect
  at ALLOW so the dev-log README could state it. They are BLOCK now. The
  README's sentence now says what the guard refuses, and GH-157.2 pins it.

Against a copy of the hooks with the two dev-05 hook files restored, the
new checks failed 124 rows. 121 of them were #159 rows. The other three
were the literals that count registry rows and measure the rate.

Seven registry rows were run with `mutate-hooks.sh -v` against `45d9c16`.
The baseline copy was green over 231 requirements, and every row was
caught with each requirement it names red:

- `edit-guard-anchored-to-the-root`: GH-157.3, GH-159.1 and GH-159.2;
- `heading-correction-read-off-the-root`: GH-159.1;
- `bash-guard-unbounded-on-the-left`, `redirect-boundary-admits-a-redirect`,
  `verb-rule-unbounded-on-the-left`, `option-letters-not-a-boundary` and
  `redirect-rule-unbounded-on-the-left`: GH-159.2.

The tree was byte-identical afterwards. An earlier run of the same
selection stopped at the baseline, red on GH-104.3, because #259 was cited
and not yet listed. `45d9c16` lists it.

## The harness rate was re-measured

The branch took the suite from 6213 check results to 6854, as the matrix
line reads them. That is past the quarter the staleness check allows over
5296. The assistant re-measured rather than re-derived: three runs, the
way the harness pays for one, of 279 s, 271 s and 288 s. Other sessions
were loading the machine. `MEASURED_SECONDS_PER_RUN` moved to 288 and
`MEASURED_AT_RESULTS` to 6854. The review fixes added rows after the
measurement, so the constant is a little under the suite's size at
merge. It is inside the quarter.

## Review

A standards pass and a spec pass, each a subagent, reviewed `dfd9fe3`. The
spec pass found every acceptance criterion substantively met. The findings
answered in `6cb5815`:

- the `-t` regression above;
- the worktree correction line, which nothing checked;
- the unlabelled trade rows in GH-159.2;
- the derivation's narrow matcher test, and a comment strip that ate
  `${#`;
- three rules with no mutation reaching them alone;
- unwrapped notes and stale tense in GH-157.

Two findings were declined:

- **`r159_call` duplicates `r157_call`.** They are two one-caller helpers
  with different bodies, and neither belongs in the library by its rule.
- **`heading_correction` is not tied to the matched segment.** It matches
  `*/docs/dev-log/*` rather than the pair `GUARDED_RE` found, which matters
  only for a dev-log directory nested under another guarded directory.

## Open

- **#259**, the redirect stretch across a `;`.
- **The rate constant is a measurement.** A later branch that grows the
  suite by a quarter over 6854 has to re-take it.
- **Bertan's to decide: the Bash half's left boundary.** The brief put
  widening that half out of scope, and it now permits `notdocs/` paths it
  used to refuse. The branch argues the change is required by criteria 3
  and 5 together.


# 2026-09-27 23:39 +03 · dev-agent-159 — #159: corrections after seven review rounds, and what each round found

Branch `worktree-issue-159-worktree-append-only`, `2202699` (the entry
above) to the commit that appends this one. dev-05 was merged in twice,
`53efd8f` (#254) at `b615960` and `abba1d0` (#253) at `4bf9004`. With this
commit the branch is 18 ahead of `origin/dev-05`: 16 commits and the two
merges. rev-agent-159 reviewed it in seven rounds on PR #271. This entry
corrects the one above, which is frozen, as the README prescribes. It was
appended with `cat >>` because the Edit guard this branch fixes now refuses a
draft in a worktree too, and the entry above is one.

## Corrections to the entry above

- **"Commits `1ab0c7a` to `45d9c16` … six ahead."** That was true at
  `2202699`. The figure at this commit is in the heading paragraph above.
- **"the new checks failed 124 rows. 121 of them were #159 rows. The other
  three were the literals"** was taken with `mutate-hooks.sh` reverted as well
  as the two hook files. The assistant re-took it in round 1 with only
  `append-only-docs-edit.sh` and `append-only-docs.sh` from dev-05, at
  `b42590c`: 128 rows failed, 124 in #159's issue file and 4 GH-157.3 rows.
  The two figures measure different things and are not comparable. Neither was
  re-taken after round 2.
- **"green over 231 requirements."** 233 after `53efd8f` merged #219's two.
- **"Seven registry rows."** The branch adds ten: the seven, the gate row
  `gate-option-letters-not-a-boundary` (round 3), and
  `heading-correction-any-dev-log-pair` and `heading-correction-last-pair-only`
  (rounds 2 and 5). `heading-correction-read-off-the-root` was re-targeted twice.
  Through rev-agent-159's harness runs, with `RUN_BOUND` raised in scratch
  copies only: all seven original rows and the gate row caught. The heading
  rows were caught in their round-2 form at `9abcb73`. The three heading rows in
  their round-5 form were still running when this was written.
- **"a fixture of nine hooks."** Now fourteen hook files and eighteen
  registrations. The additions include a prompt hook, a command that is not a
  string, a missing file, and two matchers bash cannot compile.
- **"The git route was not taken"** (the first `##` section) put a decision in
  the passive. The assistant chose not to take it, for the reason given there.
- **"Two findings were declined"** (the Review section) did the same. The
  assistant declined them. **The second decline was wrong.** "`heading_correction`
  is not tied to the matched segment … matters only for a dev-log directory
  nested under another guarded directory" described a permitting regression,
  and the assistant declined it without feeding that case to dev-05's hook.
  At `45d9c16`, `*/docs/dev-log/*` permitted the heading correction on
  `docs/eval-reports/docs/dev-log/devlog_…`, which dev-05 refused.
  - Round 2's fix (G4, the last guarded pair) closed the ancestor half of it
    and kept the nested half.
  - rev-agent-159 found the nested half in round 5 (G6).
  - The correction now holds only when every guarded pair in the path is
    `dev-log`.

## The seven rounds

**Round 1.** It found two gating defects:
- **G1:** the derivation of which hooks the checkout question reaches silently
  dropped a hook it could not read (a registration with an argument, and a
  ` #` inside a quoted string).
- **G2:** the "no table is red" branch had never been driven.

It also found a stale #159 citation (N1), and a recorded trade narrower than
the behaviour (N2): drafts in a worktree, a project under a guarded ancestor,
and a `+`-ended parent. rev-agent-159 filed #275 and #276.

**Round 2.** It found **G3**, which came back **through G1's fix**: the new
`gsub` on `.command` aborted jq on a prompt-type hook, with the status
discarded. It also found **G4**: under a `docs/dev-log/` ancestor, the
dev-log-only exception reached `docs/lessons-learned/` and
`docs/eval-reports/` entries. And **N3**, `-xdocs` prose wider than the
redirect rule. The assistant's own sweeps added two siblings:
- a draft precondition that read git naming nothing as "untracked";
- a README carve-out the trade prose did not state.

The suite then caught the assistant's `rc=$?` in a function that runs no hook.
#98's derivation reads that as a hook's exit status. rev-agent-159 filed #282.

**Round 3.** Three present-tense claims the root no longer made (N5). The
registry declared rows `caught` that no harness had run (N6). The gate's
option group had no row (N7). **N8** was the assistant's error: its round-2
reply said Bertan would re-run the suite and the mutations. rev-agent-159 had
said that, and Bertan had said nothing in the loop. The assistant corrected the
comment in place.

**Round 4.** **N9**: a matcher bash cannot compile read as "not reached". The
assistant's sweep found the same class in the grep pipeline, which is fixed
through `PIPESTATUS`. N10: the #159 entry sat among citations that are not
requirements. N11: under the ancestor, the correction reached a `devlog_*`
file in no guarded directory, which is stated and pinned as a trade. The suite
caught two more of the assistant's mistakes in that fix:
- a deliberate missing `grep` written into the run's own not-found record;
- #282 cited without an entry.

The assistant also relayed rev-agent-159's harness result as "every
requirement named went red: GH-159.1 and GH-96.2". The rows name GH-159.1
only. That list was what went red.

**Round 5.** **G6**, which came back **through G4's fix**: the last guarded
pair let a `docs/dev-log/` nested inside one of the other two directories take
the exception, in this repository. This is the case the assistant had declined
at `45d9c16`. The assistant took rev-agent-159's first reading, every pair, and
pinned every nesting of the three directories as a row. It also pinned the
refusals that costs against dev-05 as trades, a `docs/eval-reports/` ancestor
among them. N12 and N13 were text.

**Round 6.** **G7**: the fixture precondition named two files, so a near-miss
the build left out made 57 ALLOW rows unable to fail. rev-agent-159 measured
this, and the suite was green. The precondition now reads the rows' own tables.
The assistant's sweep found ALLOW rows on files created inline with no check,
and each now calls `r159_present`. N14 was CLAUDE.md's consequence 5. The
assistant declined the loop simplification, because it spells the directory
set a second time outside `GUARDED_RE`.

**Round 7.** Two claims this branch's own fixes left behind:
- **N15:** the `#177` conjunction still read "under docs/dev-log/, at any
  depth".
- **N16:** "committed on no branch" for a fixture entry that is untracked.

The assistant's sweep found the same "on no branch" in GH-159.1 and a row
label, and the "at any depth" clause in GH-177's requirement text. All are
fixed, and then this entry was appended.

What the rounds have in common: two gating defects, G3 and G6, came back
through the fixes to G1 and G4. Each fix was a guard that exhibited the class
it had been written to close. The suite was green before every one of them was
found.

## Open

- **The harness:** the three heading rows in their round-5 form, with
  rev-agent-159.
- **#190:** ADR 0003 says the Edit companion reads the merge base, while the
  hook reads existence, so a draft is refused from its first write.
  rev-agent-159 withdrew it as a decision for this PR. The README's append rule
  makes an appended correction such as this one the prescribed route.
- **Filed from review, not fixed here:** #259, #275, #276, #282, #297, and #233
  re-confirmed.
- **Still Bertan's to decide:** the Bash half's left boundary, as the entry
  above says.
- **The rate constant:** it stays at 288 s, measured at 6854 results. The
  suite read 6915 at `948d44c`, inside the bound.

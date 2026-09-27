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

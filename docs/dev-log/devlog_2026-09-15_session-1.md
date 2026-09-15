# 2026-09-15 · session 1 — every boundary requirement has an ID, and the suite fails on an uncovered one

**Branch** `worktree-issue-104-requirements-matrix`, cut at `origin/dev-05`
`9d217c6` and fast-forwarded to `b93f7f7` when #126 landed mid-session. Two
commits, proposed into `dev-05`. **Check suite 1846 → 1895 results on dev-05's
own checks plus #104's, every one of the 1846 present and unchanged.** `make
test` 595 passed / 5 xfailed / 1 failed; the failure is
`test_installed_packages_match_uv_lock`, a worktree venv without the
`migrations` group (`alembic`, `mako`), and unrelated.

The whole session was issue #104, worked by the assistant unattended from the
issue text and #103's decisions. Bertan took no part in it; every choice below
that the issue left open is the assistant's, and the pull request is where
Bertan reviews them.

---

## `requirements.md` holds 150 requirements, and each check says which it establishes

`.claude/hooks/requirements.md` carries #36's 32 user stories verbatim, 49 FRs
from its decisions and three amendments, and 69 `GH-` entries from the boundary
issues after it, split into sub-IDs where one issue names behaviours that fail
separately (#43 six, #44 seven, #69 three). The 41 acceptance criteria of #37–#41
are quoted verbatim, 34 mapped and 7 dropped with a reason. Two FRs are
`drifted` with the evidence #104 named, one `retired`, two `superseded-by`.

Every result in `check-hooks.sh` now goes through `pass` or `fail`, which print
it and append it to a record with the IDs in force and a direction — refuse,
permit or static. `req` sets the IDs and each `section` heading clears them, so a
check under a new heading with no `req` is untagged and fails. 348 `req` lines
tag all 1846 existing checks. A suite-wide rewrite of 65 `printf '  ok …'` sites
into `pass`/`fail` came first, and was verified by comparing every result line of
the suite before and after: identical.

At the foot, one awk program reads the record and the requirements file and
fails on an uncovered active requirement, an untagged check, an unknown tag, a
malformed entry, an unmapped criterion, and a cited `#<n>` with no entry.
`--matrix` prints every requirement with its checks.

## The known gaps are recorded, not gated

#104 offered two ways to land with the audit's gaps: a failing count gated to
#105, or `status: gap` per uncovered ID. The assistant took the second. 19
entries are marked, 15 for #105, 3 for #110 (the runbook, which does not exist
yet) and 1 for #127. The trade, stated in the suite: a gap that later becomes
covered stays marked until its owner takes the marker off; the matrix says of
such a gap that its tags now meet coverage.

## A third direction, `static`, which #103 did not decide

Q15 defines coverage as a refusing and a permitting check, or one of them when a
requirement declares `refuse-only` or `permit-only`. A third of the requirements
are about what a file says or a function returns, where there is no verdict to
have a direction. The assistant added `direction: static` — covered by any tagged
check — rather than declare those one-sided with a reason that would be false.
This is a departure from Q15 and the pull request says so.

## #126 landed during the session, and its 75 checks were tagged in the merge

`b93f7f7` added the housekeeping generator's section to the same suite while this
branch was being built. The branch was fast-forwarded and the suite three-way
merged by hand; two conflicts, both in places both sides had edited: the
section heading, and `READ_DOCS`, which both sides widened in different ways.
#126 has no issue, so its pull request is listed as a citation and its checks
carry the IDs of the procedures they establish (GH-70.2, GH-100, US-29).

## Review found eight defects in the first commit, four of them permitting

The two-axis review of `9bdd641` (Standards and Spec, run as separate agents)
found these, each fixed in the second commit with a fixture mutant that fails
without the fix:

- **A renamed `##` family heading made every entry under it vanish** without a
  word. Now an entry under a heading that holds none fails.
- **Marking entries `gap` or `verify: review` in bulk kept coverage green.** The
  count of each is now a literal in the suite (19 and 15).
- **`seam: none` with checks tagged was accepted** (GH-61 had three). Now it
  fails, and GH-61 declares the half a check reaches.
- **The awk program's exit status was never read.** Under mawk a
  `verify: tests/<directory>` aborts it with exit 2; only an empty-output test
  stood behind it, and a program that stopped after its first finding would have
  passed. Measured both ways: with the status read removed, a mid-program
  `exit 2` leaves the suite green.
- The self-check that every result goes through `pass`/`fail` missed
  `printf '%s\n' "  ok …"`; a misspelled direction was recorded and counted
  toward nothing; the dev-log index lacked the 2026-09-13 entry; a CLAUDE.md line
  ran to 115 columns.

On the Spec axis the assistant had overstated two FRs — FR-3 and FR-4 attributed
to #36 shapes that came from PR #35's review, #51 and #73 — and mapped two
one-off criteria to a retired FR while dropping three of the same kind; a
GH-58.2 direction contradicted its own text; and the housekeeping checks had been
tagged with US-28 and FR-24, which are about the skill's text and not the
generator's output. All corrected.

Mutation evidence, in copies of the tree: six mutations of the first commit
(a tag dropped, an unknown tag, a mapping deleted, an unknown citation, coverage
forced true, recording off) and seven of the second, every one red for its own
reason.

## Open

- `--matrix` prints about 180 KB, past what a pull request body holds, so the
  body carries the per-ID summary lines and the command to regenerate the rest.
- Tags persist across `---` sub-headings within a section, so a check added late
  in a section inherits its IDs. Named in the suite, not closed.
- #105 fills the gaps; #110 writes the runbook three `verify: runbook §n`
  entries point at; one mutation per FR is a new `docs/todo.md` item (Q8).

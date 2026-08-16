# 2026-08-16 · session 1

**Repositories worked in:** `clause-and-effect` (`dev-03`) — five commits,
`b0bcade..4217b28`, **21 ahead of `main`**, pushed; `ai-common` — two PRs
opened and merged, **#26** and **#27**, `main` `a1fa197 → 4a433aa`, both
branches deleted.
**State at close:** both repositories run on **uv 0.12.5** and
**CPython 3.13.15**, with exact interpreter pins and `required-version`
committed. Trees
clean, suites green at **244 passed / 5 xfailed** and **140 passed**.

**Theme:** the upgrade plan written on 2026-08-13 was executed end to end, and
it held — every phase ran as specified except where reality had moved
underneath it, which happened three times. The larger result was not the
upgrade. Phase 1 uninstalled two packages nobody expected, and following that
thread found that **the sweep installs the candidate it is about to judge, and
a rejected candidate stays installed**. That was demonstrated, fixed in both
repositories, given a test, and documented — and the test then caught the same
class of drift again, live, within seconds of being written.

---

## The plan survived contact; three of its premises had not

`docs/uv-upgrade-plan.md` was followed phase by phase. Three things it asserted
were checked rather than assumed, and all three had changed or were wrong:

- **The target moved.** The plan named 0.12.3, published 2026-08-07. The
  current release was **0.12.5**, published 2026-08-14. Both inside the 0.12
  series, so decision 3's `required-version = ">=0.12,<0.13"` was unaffected,
  and reading the 0.12.4 and 0.12.5 notes found no breaking change. One 0.12.4
  entry — *"Respect `fork-strategy` when ordering forks created from … existing
  lockfile `resolution-markers`"* — touched exactly the machinery our lock uses
  and was flagged as a candidate for a phase 3 diff. It produced none.
- **The plan's core premise was unverified.** It assumed uv 0.12.x would know
  CPython 3.13.15. That was checked against uv's own compiled-in
  `download-metadata.json` at tag `0.12.5`, which lists 3.13 patches 0–15
  inclusive. Measured, not inferred, before anything was installed.
- **`.python-version` is gitignored in both repositories** — `.gitignore:8` in
  each, under "Virtual Environments". This is why phase 0 measured the file as
  absent everywhere: it could never have been committed. §6 required it
  committed and decision 1's entire rationale depends on it, so the plan had an
  unstated prerequisite. Found while checking an unrelated edit into `todo.md`.

## Phases 0 to 4: nothing moved that was not supposed to

Phase 0 recorded the baseline: uv 0.6.17 at the pyenv path, GuardDog 3.1.0,
both locks at `revision = 2`, venv on 3.13.3, **243 passed / 5 xfailed**.

Phase 1 wrote `.python-version` as `3.13` and synced. The venv was **reused,
not rebuilt** — `.venv/bin/python` and `pyvenv.cfg` kept identical inode *and*
mtime, and the resolve took 1 ms.

Phase 2 installed 0.12.5 via the standalone installer. `~/.local/bin` was
already position 3 on `PATH`, as measured on 08-13, so no `PATH` edit was
needed and the pyenv binary stayed on disk as the rollback. **R1 and R3 both
verified immediately:** GuardDog still 3.1.0, still resolving to
`/usr/bin/python3.12`.

Phase 3 probed the lock in a scratch copy built from the **working tree**, not
`HEAD`, so it included the uncommitted `ai-common` pin re-point. `uv lock`
under 0.12.5 produced a **byte-identical** lock, `revision = 2` unchanged —
R4 and R5 closed. A 3 ms resolve means it *validated* the existing lock rather
than re-resolving, so what is established is "0.12.5 will not rewrite our
lock", which is the property the gate needs, and not "a fresh resolution would
be identical", which was never claimed.

Phase 4 installed `cpython-3.13.15-linux-x86_64-gnu` — the full build key, at
Bertan's instruction, which mattered because `cpython-3.13.15+freethreaded-…`
sits directly beside it in the list. The venv was rebuilt against that same
key. **174 packages before, 174 after, byte-identical `diff`.** That equality
is worth more than the test count: it shows the interpreter bump moved nothing
in the environment, so any later failure could not be blamed on a silently
different dependency.

## `upgrade-safe` reverts the lock but not the environment

Phase 1's sync uninstalled `olefile==0.47` and `python-oxmsg==0.0.2`. Two
guesses at the cause were wrong before the third was checked: it was not
`b23887e` (which dropped `pypdf` and `langchain`), and it was not phase 1.

Neither package has **ever** appeared in this repository's `uv.lock` —
`git log -S` over that path returns nothing for either name — yet both had
GuardDog reports stamped `12:27:25` and `12:38:04` on 2026-08-13, inside the
candidate sweep that `upgrade-safe` went on to reject.

The mechanism, established from the recipe and confirmed by experiment:

- `Makefile:133` runs `uv run guarddog-cached …` at a point where `uv.lock`
  **is** the candidate;
- `uv run` synchronises the environment first, and that sync is **inexact** —
  `--exact` is the opt-in, confirmed against `--help` on **both**
  0.6.17 and 0.12.5, so this is not something the upgrade introduced or fixes;
- `uv lock --upgrade` and `uv export --frozen` install nothing, which leaves
  `uv run` as the only installer in the recipe;
- the `EXIT` trap restores the lock at `Makefile:114`, while the repairing
  `uv sync --all-groups` at `Makefile:149` sits after
  `rm -f uv.lock.preupgrade`, on the **success path only**.

Two properties make it structural rather than untidy. The install **precedes**
the scan, so a blocking finding cannot keep the package out of the
environment. And `osv-scanner` reads the *committed* lock afterwards, so it
cannot see it there either. The package is in the environment that runs the
code and in no artifact either tier examines.

## Phase 5: two of its three exit criteria were unsatisfiable before it began

Phase 5 required the export to be byte-identical, **tier 1 clean**, and tier 2
to report **the same verdicts as before the upgrade**. Only the first was
achievable:

- **Tier 1 has never been clean.** Three advisories stand against the committed
  lock — `cryptography` 49.0.0 (8.2 High), `h2` 4.3.0, `langchain` 1.3.2. All
  three were published before 2026-08-13 (Aug 4, Aug 10, Jun 22), checked
  against OSV, so all three predate the baseline and the count matches it
  exactly. `osv-scanner` exits 1 on any finding.
- **`make verify` therefore cannot reach tier 2 at all.** `verify: audit scan`
  at `Makefile:83` makes tier 1 a prerequisite and make stops at a failed one.
  `make scan` was run directly instead.
- **Tier 2 had no baseline to match.** The only complete sweep to date was
  against the *candidate* lock; session 1 of 08-13 aborted at 64/181 against
  the committed one.

The criteria were amended in the plan to what is actually checkable — export
identity, `uv lock --check`, R1 and R3 integrity, and "no blocker
*attributable to the upgrade*" — and the amendment records why, so the next
reader does not re-derive it.

Two checks were added that the plan did not ask for. `git diff --exit-code
uv.lock` was replaced by hash comparison, because the lock was knowingly dirty
and `git diff` cannot then distinguish "the export rewrote the lock" from "the
lock was already modified". And the **old uv was run against a scratch copy to
export the flat requirements**, because the flattened export is tier 2's actual
input and "did the export change" is a sharper question than "did the lock
change". The two exports were identical apart from the header comment recording
the output path.

**The sweep — 14:16:51 to 14:34:49, 18 minutes.** 180 packages: **clean 131,
advisory 41, BLOCKED 8, INCOMPLETE 0**, from 163 cache hits and 17 fresh scans.
The report store went **227 → 244**, exactly the 17. This is the **first
complete committed-lock tier-2 baseline the project has**.

The denominator is **180, not 181**: the wrapper announced 180, `osv-scanner`
counts 181 in the lock, and the difference is the `ai-common` git line at
export line 7 that `parse_requirements` drops. Progress was reported as `x/181`
during the run, which understated it.

All eight blockers sit at versions the committed lock already carried, so none
is attributable to the upgrade. `torch==2.13.0` and `transformers==5.8.1` are
at the **same** versions the candidate sweep found and need no second
adjudication; the other six are the same rules firing at older version keys and
have no waivers, since waivers key on version by design. `pywin32==312` — same
version, already waived — came back cached and non-blocking, which is a live
confirmation that the waiver mechanism survives a sweep.

## Phase 6: ai-common passed the original criteria in full

Same treatment, on a branch. Lock probe byte-identical, `revision = 2`
unchanged. `.python-version` written as `3.13.15` directly, skipping the
plan's `3.13` intermediate — that step existed only because 3.13.15 was not
installable under 0.6.17, and the ordering constraint that matters (pin before
rebuild, closing R2) was still honoured.

Tier 1: **No issues found**. Tier 2: 74 packages, clean 60, advisory 14,
**BLOCKED 0, INCOMPLETE 0** — and **74 of 74 served from cache**. That 100%
hit rate is the session's strongest R1 evidence: after swapping the resolver,
not a single package needed rescanning.

It is also the phase 5 that `clause-and-effect` could not have. The identical
toolchain change produced a spotless result here, which is what confirms the
eight blockers there are that repository's adjudication backlog rather than
something the upgrade did.

## Phase 7 retired the rollback, deliberately and verifiably

`.python-version` was removed from `.gitignore` in both repositories — a pin
that cannot be committed is not a recorded choice — and
`[tool.uv] required-version = ">=0.12,<0.13"` was written into both
`pyproject.toml` files last, because uv 0.6.17 honours it.

That was verified rather than assumed: the old binary now exits with
`Required uv version >=0.12, <0.13 does not match the running version 0.6.17`
in **both** repositories. The `rm ~/.local/bin/uv` rollback is retired; the
pyenv binary is shadowed, not deleted, and reverting from here means reverting
the `pyproject.toml` change first.

Neither lock moved by a byte through any of it — the constraint is not a
resolution input.

## The drift became a mechanism, not a note

Bertan asked for a demonstration rather than an inference, and the reproduction
followed the recipe step for step in a scratch project: baseline lock
`1182038035eb`, candidate `fb43e381d1d4`, `uv run` printing
`Installed 1 package in 2ms`, trap restoring `1182038035eb` — ending with the
lock declaring `iniconfig` **zero** times and the environment containing it
**twice**.

**The fix is `uv run --frozen --no-sync`** at both call sites in both
repositories. `--no-sync` prevents the install rather than undoing it; the
sweep does not need the candidate installed, since it reads the flattened
requirements file and fetches each artifact from PyPI itself. `--frozen` closes
the sibling hazard, since `uv run` updates the lock when it considers it stale
and at that point the lock is the candidate — the same reasoning already
recorded for `uv export --frozen` at `Makefile:54-60`.

**`uv run --exact` was rejected**, having first been written into `todo.md` as
an option. It makes the environment match the *candidate* exactly rather than
accumulate on top of it, but after the revert the environment is still the
candidate's set. It reduces accumulation; it does not fix the drift.

A resync inside the `EXIT` trap was also rejected as the primary fix: with
`--no-sync` nothing is installed, and a full sync on the interrupt path does
work at the moment the operator is trying to stop.

## The test caught real drift on its first run

Bertan asked for a test rather than a `make` target. `uv sync --check` was
measured before anything was built on it: exit **0** synchronised, exit **1**
on an extraneous package *and* on a missing one, and — with drift present and
the check reporting failure — the `site-packages` count and the `uv.lock`
`sha256` both **unchanged**. A check that repaired what it measured would make
the test a mutation of the artifact it guards.

The test delegates to that rather than re-implementing the comparison, which
would have to evaluate environment markers (`colorama` is win32-only), know the
project installs itself into its own environment, and catch under-installation
as well as extras. It strips `VIRTUAL_ENV` from the subprocess environment, for
reasons the session had already demonstrated the hard way.

**It failed immediately, on five real packages**: `httpx2`, `httpcore2`,
`truststore`, and `olefile` and `python-oxmsg` back for the second time in a
day. Timestamps put all five at `15:06:45` with `uv.lock` rewritten at
`15:06:22` and the report store growing `244 → 250` — an `upgrade-safe` on the
unpatched recipe that ended early, the exact scenario Bertan said he had
observed before. The drift the test was written for reproduced itself while the
test was being written.

A third, separate instance had already been found in `ai-common`: `httpx2`,
`httpcore2` and `truststore` at `14:56:01`, all marked `REQUESTED`. That one
did **not** come from the sweep — `httpx2` is an optional extra of `openai`
(`Requires-Dist: httpx2<3,>=2.7.0; extra == 'httpx2'`) and locks do not carry
extras. It is the instance that justifies the detective half: the preventive
flags would not have caught it.

`docs/design/environment-lock-coupling.md` records the mechanism, following the
directory's convention of separating Observed from Argued, with Known gaps at
the end. `dependency-scanning-scope.md` quoted the sweep's invocation without
the new flags and was corrected in the same commit — the first instance of the
staleness its own README warns about.

---

## Verification

- `clause-and-effect`: **243 → 244 passed, 5 xfailed**, run at every phase
  boundary and matching the phase 0 baseline exactly each time.
- `ai-common`: **139 → 140 passed**, before and after the interpreter rebuild.
- Venv rebuild moved **zero** packages: 174 before, 174 after, `diff` empty.
- `ai-common`'s rebuilt venv checked against **its own lock's export** rather
  than a before/after snapshot, after the first attempt measured the wrong
  environment: 74 vs 74, the only differences being `ai-common==0.1.0` (the
  project itself, not emitted by `uv export`) and `colorama` (win32-only).
- Locks byte-identical throughout: `d9784e59…` and `0c274351…` unchanged by the
  resolver swap, the export, the venv rebuild, and `required-version`.
- Old uv's export vs new uv's export: identical but for the header comment.
- `required-version` verified to actually stop uv 0.6.17, in both repositories.
- `uv sync --check` verified non-mutating before the test relied on it.
- Every `Makefile` line number cited in the design document re-checked against
  the patched file rather than carried over from pre-patch numbering.
- Report store: **227 → 250**; GuardDog held at **3.1.0** on
  `/usr/bin/python3.12` throughout, checked before and after the uv swap.

## Mistakes made this session

All the assistant's unless stated.

- **Exit codes were read through a pipeline three times.** `make scan | tee |
  tail` reports `tail`'s status, so a background task announced "exit code 0"
  for a run where make exited 1; the same error was repeated when measuring
  `uv sync --check`. Caught each time by reading the log instead, but the
  pattern recurred after being noticed once, which is the part worth recording.
- **`VIRTUAL_ENV` produced a confidently wrong measurement.** ai-common's
  rebuild was reported as "174 packages before and after, identical". Both
  numbers came from `clause-and-effect`'s venv, because that environment was
  active in the shell and `uv pip list` honours it over the working directory.
  ai-common's venv holds 74. The reading was plausible, which is why it was
  published before being questioned; it was caught only because a 75-package
  lock cannot produce 174 installed packages.
- **`--exact` was written into `todo.md` as a fix option for a bug it does not
  fix.** Corrected in the same session, before it reached the Makefile.
- **The cause of the `olefile` uninstall was guessed twice before being
  checked** — attributed to `b23887e`, which dropped different packages
  entirely.
- **`uv export -o /dev/null`** failed with a permission error, since uv writes
  its temp file alongside the output path. It silently invalidated an R6
  measurement until it was redone against a real path.
- **The CPython advisory claim could not be verified.** The plan's §8 already
  flagged that the 30 advisories are asserted closed but never re-queried. The
  attempt to close that gap matched `RUSTSEC-2023-0076` — a Rust crate also
  named `cpython`. The 08-13 query method is not recorded anywhere, so the
  headline benefit of the interpreter upgrade remains unconfirmed.
- Sweep progress was reported as `x/181` when the wrapper's own denominator
  is 180.

## State handed to the next session

| | |
|---|---|
| `clause-and-effect` | `dev-03` at `4217b28`, pushed, **21 ahead of `main`**, tree clean |
| `ai-common` | `main` at `4a433aa`, clean, **only branch**; PRs #26 and #27 merged |
| Toolchain | uv **0.12.5**, CPython **3.13.15**, both pinned and committed in both repos |
| Rollback | **retired** — uv 0.6.17 refuses to run in either repository |
| GuardDog | **3.1.0** on `/usr/bin/python3.12`, unmoved; store at **250** reports |
| Tier 2 baseline | first complete committed-lock sweep: 180 packages, 8 blockers, INCOMPLETE 0 |
| Waivers | **9**, all against candidate-lock versions |
| Suites | **244 passed / 5 xfailed**, **140 passed** |

**Still unfinished from phase 7:** `todo.md:1173` has not been updated — the
interpreter upgrade's done half should be marked and the deferred "does the
toolchain belong inside the gate?" question promoted to its own entry. The
toolchain-pinning design note the plan suggests is also unwritten; there are now
three pinned interpreters for three different reasons (the project's 3.13.15,
GuardDog's distro 3.12.3, uv's own bundled runtime).

**Also open:** the `upgrade-safe` that ran at 15:06 never finished. Re-running
it is now safe for the environment either way.

## Open items — start here next session

| # | open item | state |
|---|---|---|
| 1 | 8 tier-2 blockers at committed versions — `make scan` exits 1 | red now |
| 2 | 3 tier-1 advisories — `cryptography` 49.0.0 (8.2 High), `h2`, `langchain` — `make audit` exits 1 | red now |
| 3 | `make verify` unusable in `clause-and-effect` while tier 1 is red | structural |
| 4 | `upgrade-safe` reverts the lock but not the environment | **fixed today** — see note |
| 5 | The gate's detection side has never been verified | oldest open item |
| 6 | Three GuardDog defects to report upstream | unreported |
| 7 | Report store versioning — `cache.json` is the file the gate reads to decide | undecided |
| 8 | Dropped requirement lines under-report the denominator | unfixed |
| 9 | Platform-restricted export (`pywin32`) | undecided |
| 10 | Does the toolchain belong inside the gate — GuardDog 3.1.0 is itself unexamined | deferred |

**Note on item 4.** This list was drawn up earlier in the session, when the
item was recorded but unfixed. It was fixed before the session ended:
`uv run --frozen --no-sync` at both call sites in both repositories, a test in
each suite, and `docs/design/environment-lock-coupling.md`
(`7046a0d`, `4217b28`, and `18bba60` in `ai-common`). The state is left visible
rather than deleted, because the entry that remains is a real one — the *fix*
is unverified against a full `upgrade-safe` run, since the only run attempted
today was interrupted before the patch existed. Item 4 closes when a complete
`upgrade-safe` finishes and the environment is unchanged afterwards.
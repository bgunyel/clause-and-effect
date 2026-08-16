# Clause & Effect — uv Upgrade Plan

> **Status:** Written 2026-08-13 as a planning document; **phases 0–5 executed
> 2026-08-16** in `clause-and-effect`, leaving phase 6 (ai-common) and phase 7
> (record). Phase 5's exit criteria were amended after running them showed two
> of the three were unsatisfiable before the upgrade began — see the note there.
> It states what should happen, in what order, and what must be true
> at each step before the next one starts. Prerequisite for
> [`todo.md`](todo.md) 🔺 *"Upgrade Python 3.13.3 → 3.13.15"* (line 1173), which
> cannot proceed until this lands.

---

## 1. Why this exists

The interpreter upgrade was blocked by something nobody had looked at: **this
machine's `uv` is 0.6.17, and the current release is 0.12.3.**

The immediate consequence is narrow. uv compiles the python-build-standalone
download metadata into its own binary, so uv 0.6.17 does not know that any
CPython past 3.13.3 exists. `uv python install 3.13.15` cannot succeed until uv
moves, and no amount of `.python-version` work changes that.

The larger consequence is the reason this has its own document. **uv writes
`uv.lock`, and `uv.lock` is the artifact both gate tiers read.** `osv-scanner`
parses it directly; the GuardDog sweep scans whatever `uv export` flattens out
of it. A resolver from April 2025 therefore sits underneath the entire
supply-chain gate, and nothing examines it — the same blind spot recorded for
the interpreter, except that the interpreter merely runs the code while uv
*decides which code there is*.

This upgrade is consequently not routine maintenance. It changes the tool that
produces the input to every check the project makes about its dependencies, so
it is planned, gated and rolled back like any other change to the gate.

---

## 2. Measured state

Everything in this section was observed on 2026-08-13, not inferred. Commands
are given so each line can be re-run.

| fact | value | how |
|---|---|---|
| installed uv | **0.6.17** | `uv --version` |
| its location | `/home/bgunyel/.pyenv/versions/3.11.3/bin/uv` | `which -a uv` |
| binary mtime | 2025-04-26 | `ls -la $(which uv)` |
| current release | **0.12.3**, published 2026-08-07 | GitHub releases API |
| newest CPython uv can see | **3.13.3** | `uv python list --all-versions` |
| newest CPython upstream | **3.13.15**, pbs release `20260807` | pbs releases API |
| venv interpreter | **3.13.3** | `.venv/bin/python -V` |
| `.python-version` | **absent** in both repos and `$HOME` | `ls` |
| `requires-python` | `">=3.13"` in both repos | `pyproject.toml` |
| lock format | `version = 1`, `revision = 2` in both repos | `head -2 uv.lock` |
| GuardDog interpreter | `/usr/bin/python3.12` (3.12.3), pinned in the uv receipt | `uv-receipt.toml` |
| custom indexes | none in either repo | `grep index pyproject.toml` |
| build backend | ai-common `hatchling`; clause-and-effect declares none | `pyproject.toml` |

**PATH precedence**, which decides how the new uv gets installed:

```
3:  /home/bgunyel/.local/bin          ← standalone installer target
5:  /home/bgunyel/.pyenv/versions/3.11.3/bin   ← current uv lives here
7:  /home/bgunyel/.pyenv/shims
```

`~/.local/bin` already precedes every pyenv entry, so a standalone install wins
without any PATH edit, and removing it restores the old uv exactly. That is the
rollback mechanism for phase 1, and it is why the standalone installer is
preferred over `pip install -U uv` into the pyenv environment.

---

## 3. Breaking changes between 0.6.17 and 0.12.3

Read from the release notes for each minor bump. Only the entries with a bearing
on this project are listed; the rest were checked and discarded.

| release | change | bearing here |
|---|---|---|
| **0.9.0** | **Python 3.14 becomes the default version** | **The dangerous one.** See below. |
| 0.10.0 | `uv venv` now requires `--clear` to replace an existing venv | The rebuild step must pass it, or delete `.venv` first |
| 0.10.0 | `uv python upgrade` stabilised; venvs auto-upgrade patch versions | This is the mechanism that keeps 3.13.x current afterwards |
| 0.8.0 | `uv python install` puts versioned executables on `PATH` (`~/.local/bin`) | Will create `~/.local/bin/python3.13`; opt out with `--no-bin` if unwanted |
| 0.11.0 | TLS stack moved to `rustls-platform-verifier` | Certificate validation changes; low risk here, no proxy or private index |
| 0.7.0 | `uv version` now prints the *project* version, not uv's | Nothing scripts it, but use `uv self version` from now on |
| 0.12.0 | `uv init` defaults changed | Existing projects unaffected — no action |
| 0.10.0 | errors on multiple `default = true` indexes / unnamed `explicit` index | No custom indexes; not applicable |

### The 3.14 default is the reason ordering matters

From the 0.9.0 notes: *"If no Python versions are installed on a machine and
automatic downloads are enabled, uv will now use 3.14 instead of 3.13… This
change will not affect users who are using a `.python-version` file to pin to a
specific Python version."*

Both repositories declare `requires-python = ">=3.13"`, which permits 3.14, and
neither has a `.python-version`. Today that is harmless because `uv sync` reuses
the existing venv rather than re-selecting an interpreter. **The moment the venv
is rebuilt under uv ≥ 0.9 without a pin, 3.14 is a legitimate choice** — and the
lock already carries `resolution-markers` for `python_full_version >= '3.14'`,
so the resolver has opinions about it.

This is precisely the phase where the venv gets rebuilt. Hence the pin goes in
**before** the uv upgrade, not after — see phase 2.

---

## 4. Risk register

Ordered by blast radius, not likelihood.

### R1 — An accidental `uv tool upgrade` invalidates the entire scan cache

**The most expensive thing that can go wrong, and it is a one-command mistake.**

The GuardDog cache and review ledger key on `(name, version, guarddog_version)`.
The machine-wide store currently holds **153 reports, 36 with findings, 31
awaiting review**, plus five adjudicated waivers. Upgrading GuardDog changes
`guarddog_version` in every key at once: every cache entry becomes a miss, every
completed review re-opens, and the next sweep re-scans from nothing.

- **Mitigation:** do not run `uv tool upgrade`, `uv tool upgrade --all`, or
  `uv tool install guarddog` at any point in this plan. Upgrading uv itself does
  not touch installed tools.
- **Detection:** `guarddog --version` must read `3.1.0` before and after.
- Note the cache survives on disk regardless — the cost is re-scanning and
  re-reviewing, never a weakened verdict.

### R2 — The venv is rebuilt onto Python 3.14

Covered in §3. Blast radius: a resolution that silently differs from everything
measured to date, on an interpreter the project has never run.

- **Mitigation:** phase 2 writes `.python-version` before uv changes.
- **Detection:** `.venv/bin/python -V` after every rebuild.

### R3 — GuardDog's interpreter pin does not survive

The 2026-08-11 lesson: Landlock denies `/dev/urandom` to python-build-standalone
interpreters, which is what uv-managed CPython is, so GuardDog was pinned to
distro Python via `uv tool install --force --python /usr/bin/python3.12`. The
pin is recorded in the tool receipt and was demonstrated to survive
`uv tool upgrade`. It has **not** been demonstrated to survive a change of the
uv binary itself.

- **Mitigation:** verify before running any sweep, not after.
- **Detection:** `~/.local/share/uv/tools/guarddog/bin/python -V` → `3.12.3`,
  resolving to `/usr/bin/python3.12`.
- **Recovery:** re-pin with the recorded command; note this is a GuardDog
  reinstall and therefore triggers R1 if the version moves — pin the version
  explicitly if it comes to that.

### R4 — The lock format revision bumps

Both locks are `revision = 2`. If uv 0.12 writes `revision = 3`, the rewritten
lock is no longer readable by older uv — a one-way door — and the diff must be
reviewed and re-gated rather than waved through.

- **Mitigation:** probe in a scratch copy first (phase 4), never in place.
- **Detection:** `head -2 uv.lock` before and after.

### R5 — The new resolver produces a different lock

Sixteen months of resolver changes. `uv lock` is minimal-change by design — the
08-13 finding that a stale langchain fork survived every re-lock is direct
evidence — but "minimal" is not "none".

- **Mitigation:** any lock change goes through `make upgrade-safe` like any
  other, so both tiers see it before it is adopted.

### R6 — `uv export --frozen` stops being byte-identical

The `--frozen` flag is load-bearing in both Makefiles (`Makefile:54` comments on
exactly this) and the byte-identity property was verified on 2026-08-13 —
against uv 0.6.17. It is an assumption about the *old* uv until re-measured.

- **Detection:** export, then `git diff --exit-code uv.lock`.

### R7 — The upgrade lands mid-sweep

A sweep is running as of writing. Rebuilding the venv would pull the interpreter
out from under `uv run guarddog-cached`, and re-locking would collide with the
`uv.lock.preupgrade` dance. This is the same collision as 2026-08-13.

- **Mitigation:** phase 0 refuses to start while anything is running.

---

## 5. The plan

Each phase states its precondition, its commands, what must be true to proceed,
and how to undo it. **Do not skip the verification between phases** — the point
of the phasing is that a failure is attributable.

### Phase 0 — Baseline and quarantine

**Precondition:** nothing running.

```bash
pgrep -af 'guarddog|osv-scanner|upgrade-safe' | grep -v pgrep   # must be empty
ls uv.lock.preupgrade tmp/flat-requirements.txt                 # must not exist
```

Capture the baseline that every later phase is compared against:

```bash
uv --version
guarddog --version
sha256sum uv.lock ~/source/ai/ai-common/uv.lock
head -2 uv.lock
.venv/bin/python -V
make test            # expect: 243 passed, 5 xfailed
cp uv.lock /tmp/uv.lock.pre-uv-upgrade
```

Also confirm the working tree is committed or knowingly dirty — the pin
re-point from PR #25 is currently uncommitted here.

**Proceed when:** all six values are recorded.

---

### Phase 1 — Pin the interpreter, before uv changes

**This is deliberately first.** It costs nothing under uv 0.6.17, and it closes
R2 before the release that opens it is installed.

```bash
echo "3.13" > .python-version
uv sync --all-groups          # must reuse the existing venv, not rebuild
.venv/bin/python -V           # must still read 3.13.3
```

`3.13` rather than `3.13.15` at this stage, because 3.13.15 is not installable
until uv moves and an unsatisfiable pin would break `uv sync` immediately.

**Undo:** `rm .python-version`.

---

### Phase 2 — Install uv 0.12.3

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
hash -r
which -a uv                   # ~/.local/bin/uv must come first
uv self version               # 0.12.3
```

The old binary is left untouched in the pyenv directory. **Do not** `pip
uninstall uv` — it is the rollback.

Immediately verify the tool installation survived, before anything else touches
the project:

```bash
guarddog --version                                      # 3.1.0 — must not move
~/.local/share/uv/tools/guarddog/bin/python -V          # 3.12.3
readlink -f ~/.local/share/uv/tools/guarddog/bin/python # /usr/bin/python3.12
uv tool list
```

**Proceed when:** uv reports 0.12.3 and GuardDog still reports 3.1.0 on distro
Python. If GuardDog moved, stop — that is R1 and it needs its own decision.

**Undo:** `rm ~/.local/bin/uv` (and `uvx`), `hash -r`. PATH does the rest.

This is the cheapest rollback in the plan, and it stays available all the way
through phase 6. It is retired in phase 7, which writes `required-version` —
so anything undone after that point reverts the `pyproject.toml` change first.

---

### Phase 3 — Probe the lock before changing it

The lock is the gate's input, so find out what the new uv wants to do to it
*without* doing it.

```bash
cp -r . /tmp/lockprobe            # or: git worktree add
cd /tmp/lockprobe && uv lock && head -2 uv.lock && git diff --stat uv.lock
```

Three outcomes:

- **No diff** — nothing to gate. Proceed.
- **Revision bump only** — R4. Review, then adopt through phase 5.
- **Package versions move** — R5. This is a dependency change and goes through
  `make upgrade-safe`, not through this plan.

**Proceed when:** the outcome is known and recorded. Nothing has been written to
the real repository yet.

---

### Phase 4 — Install 3.13.15 and rebuild

```bash
uv python install 3.13.15
uv python list --only-installed | grep 3.13
```

If `~/.local/bin/python3.13` appearing is unwanted, re-run with `--no-bin`.

Tighten the pin now that it is satisfiable, then rebuild:

```bash
echo "3.13.15" > .python-version
uv venv --clear --python 3.13.15
uv sync --all-groups
.venv/bin/python -V           # must read 3.13.15
make test                     # must match the phase 0 baseline exactly
```

`--clear` is required from 0.10.0 onward; without it `uv venv` refuses.

**Undo:** restore `.python-version` to `3.13`, `uv venv --clear --python 3.13.3`,
`uv sync --all-groups`.

---

### Phase 5 — Re-verify the gate's own invariants

The gate has assumptions about uv that were measured against 0.6.17. Re-measure
them, in this order, cheapest first:

```bash
# R6: --frozen must leave the lock byte-identical
sha256sum uv.lock                     # before
uv export --frozen --no-hashes --all-groups -o /tmp/flat.txt
sha256sum uv.lock                     # must be unchanged

uv lock --check                       # lock still consistent with pyproject
make audit                            # tier 1, cheap, read-only
make scan                             # tier 2, expensive; see the note below
```

Compare hashes rather than `git diff --exit-code uv.lock`: the lock may be
knowingly dirty — it was on 2026-08-16, carrying the uncommitted `ai-common`
pin re-point — and `git diff` cannot then distinguish "the export rewrote the
lock" from "the lock was already modified". The hash can.

Worth also exporting with the *old* uv into a scratch copy and diffing the two
flat files. The flattened export is tier 2's actual input, so "did the export
change" is a sharper question than "did the lock change". Measured 2026-08-16:
identical apart from the header comment recording the output path.

### Amended exit criteria (2026-08-16)

As written, this phase required *"the export is byte-identical, tier 1 is clean,
and tier 2 reports the same verdicts as before the upgrade."* Running it showed
**two of the three were already unsatisfiable before the upgrade began**, so
they cannot gate it:

- **Tier 1 is not clean and was not clean beforehand.** Three advisories stand
  against the committed lock — `cryptography` 49.0.0, `h2` 4.3.0, `langchain`
  1.3.2 — all published before 2026-08-13 and all recorded as unreachable on
  this platform. `osv-scanner` exits 1 on any finding, so `make audit` fails.
- **`make verify` therefore cannot reach tier 2 at all.** `verify: audit scan`
  (`Makefile:83`) makes tier 1 a prerequisite, and make stops at a failed one.
  Run `make scan` directly instead; `verify` is unusable in this repository
  until the three advisories clear.
- **Tier 2 has no pre-upgrade baseline to match.** The only complete sweep to
  date was against the *candidate* lock (`upgrade-safe`), not the committed one,
  and the 2026-08-13 session-1 committed-lock sweep was aborted at 64/181. There
  is nothing to compare "the same verdicts" against.

**Proceed when**, instead:

- the export leaves `uv.lock` byte-identical, and matches the old uv's export;
- `uv lock --check` passes;
- **R1** holds — `guarddog --version` unmoved and the sweep is dominated by
  cache hits, which is the positive evidence that the store's keys survived the
  resolver swap;
- **R3** holds — GuardDog still resolves to `/usr/bin/python3.12`;
- no blocker is *attributable to the upgrade*. A blocker at a version the
  committed lock already carried is the adjudication backlog surfacing, not a
  regression; a blocker on a package or version the upgrade introduced is a
  finding about the plan.

**Result 2026-08-16.** All five met. Tier 2: 180 packages, clean 131, advisory
41, **BLOCKED 8, INCOMPLETE 0**, from 163 cache hits and 17 fresh scans; the
report store went 227 → 244, exactly the 17. Every blocker sits at a version the
committed lock already carried, and `torch==2.13.0` and `transformers==5.8.1`
are at the *same* versions the candidate sweep found, so they need no second
adjudication. `make scan` exits 1 on those eight — correctly, and independently
of this plan. This run is consequently the first complete committed-lock tier-2
baseline the project has, which is what future phases can compare against.

---

### Phase 6 — Repeat in ai-common

Phases 1, 4, 5 apply unchanged in `~/source/ai/ai-common`. uv itself is already
upgraded machine-wide, so phase 2 is skipped and phase 3 is repeated against
that repository's lock.

ai-common is on `main` and clean, so per the branching convention this needs a
branch and a PR — it is not a working-tree-only change.

---

### Phase 7 — Record

**Precondition:** every verification in phases 5 and 6 has passed. Nothing here
is reversible by deleting a file on `PATH`.

Write the resolver pin into both `pyproject.toml` files — **last**, because uv
0.6.17 honours `required-version` and will refuse to run in these repositories
once it is present, which retires the phase 2 rollback:

```toml
[tool.uv]
required-version = ">=0.12,<0.13"
```

```bash
uv lock --check          # must still pass; the constraint is not a resolution input
make test                # unchanged
```

**`.python-version` is gitignored in both repositories** — `.gitignore:8` in
each, filed under "Virtual Environments" (found 2026-08-16, while executing
phase 2). This is why phase 0 measured the file as absent everywhere: it could
never have been committed. Committing the pin therefore requires deleting that
line first, or decision 1 is defeated — the pin stays local and invisible, which
is the drift the item exists to correct:

```bash
# in both repositories
grep -n python-version .gitignore     # expect: 8:.python-version
# remove that line, then:
git status --short                    # .python-version must now appear
```

Then:

- `.python-version` committed in both repositories, reading exactly `3.13.15`.
- Dev log entry for the session, per convention.
- `todo.md` line 1173 updated: the interpreter half is done, and the deferred
  question it raises is promoted to its own entry (see §7).
- Consider a short design document on toolchain pinning, since after this there
  are three pinned interpreters with three different reasons — the project's
  3.13.15, GuardDog's distro 3.12.3, and uv's own bundled runtime.

---

## 6. What must be true at the end

- `uv self version` → 0.12.3, resolved from `~/.local/bin`. The pyenv 0.6.17
  binary still exists and is shadowed, not deleted.
- `[tool.uv] required-version = ">=0.12,<0.13"` committed in both repositories.
- `.venv/bin/python -V` → 3.13.15 in both repositories.
- `.python-version` in both repositories reads exactly `3.13.15` — not `3.13` —
  and is committed. The minor pin from phase 1 is an intermediate and must not
  survive. Committing it at all requires the `.gitignore` deletion recorded in
  phase 7; the file is ignored in both repositories today.
- `guarddog --version` → **3.1.0**, on `/usr/bin/python3.12`. The cache still
  holds 153 reports and the ledger still shows the same review state.
- `make test` → 243 passed, 5 xfailed here; 139 passed in ai-common.
- `uv export --frozen` leaves `uv.lock` byte-identical.
- `make verify` reports the same verdicts as the pre-upgrade baseline.
- Any lock change was adopted through `make upgrade-safe`, not by hand.

---

## 7. Decisions

Decisions 1–3 are settled. Decision 4 is deferred and is not a step in this
plan.

1. **`.python-version`: exact or minor series?**
   **Decided 2026-08-13 by Bertan — exact, `3.13.15`.**
   The failure this item came from was an interpreter drifting twelve patch
   releases while nothing said anything. An exact pin makes `uv sync` fail
   loudly when the recorded choice is not installed; `3.13` silently accepts
   whatever 3.13.x is lying around, which is the state being corrected. The
   accepted cost is that somebody has to bump it — `uv python upgrade` (stable
   since 0.10.0) is the tool, and each bump becomes a reviewable commit rather
   than a silent drift.

   Note this makes the `3.13` written in phase 1 strictly an intermediate:
   it exists only because 3.13.15 is not installable until uv moves, and
   phase 4 replaces it. Neither repository should be left on the minor pin.

2. **Where uv lives.**
   **Decided 2026-08-13 by Bertan — standalone installer into `~/.local/bin`.**
   `~/.local/bin` is already position 3 on `PATH`, ahead of every pyenv entry,
   so the new binary wins with no PATH edit. The pyenv copy is left in place
   untouched, which makes rollback `rm ~/.local/bin/uv` rather than a
   re-download of a specific old version. It also stops the resolver for every
   project depending on an unrelated pyenv 3.11.3 environment, and puts uv where
   `guarddog` already lives.

3. **Is uv itself recorded anywhere?**
   **Decided 2026-08-13 by Bertan — `required-version` in `[tool.uv]`**, in both
   repositories:

   ```toml
   [tool.uv]
   required-version = ">=0.12,<0.13"
   ```

   uv's 0.x scheme puts breaking changes at minor bumps, so the 0.12 series is
   the right granularity: patch releases flow freely, and 0.13 forces a
   deliberate decision instead of arriving unannounced. This gives the resolver
   the same posture `.python-version` gives the interpreter — a committed,
   checked choice rather than whatever is installed.

   **Ordering consequence.** `required-version` is honoured by uv 0.6.17 too, so
   writing `>=0.12,<0.13` makes the old binary *refuse to run in these
   repositories*. That would break the phase 2 rollback. It is therefore written
   last, in phase 7, after every verification has passed — and reverting it is
   the first step of any rollback attempted after that point.

4. **Does the toolchain belong inside the gate?** Deferred from `todo.md`:1173,
   and now broader than the interpreter, since uv and GuardDog are also
   unexamined. Both tiers read `uv.lock`; neither can see the interpreter that
   runs the code, the resolver that chose it, or the scanner that judged it.
   Worth its own decision after this lands — it is a scope question about the
   gate, not a step in this plan.

---

## 8. Known gaps

- **This plan does not upgrade GuardDog**, deliberately (R1). GuardDog 3.1.0 is
  therefore itself a stale-toolchain question, deferred to decision 4.
- **The 30 CPython advisories are the stated motivation but are not verified
  closed by this plan.** 3.13.15 is asserted to fix them on the strength of the
  2026-08-13 OSV query; nothing in phases 0–7 re-queries OSV afterwards to
  confirm. Add that check if the claim is going to be relied on.
- **No CI covers any of this.** Neither repository has workflow files; the
  CodeQL runs are repo-level default setup. Every verification here is manual
  and local, so "it passed" means one machine passed.
- **ai-common's dropped requirement lines** (`todo.md` item 6) are unaffected by
  this work and still under-report the sweep denominator.
# Keeping the environment coupled to the lock

Both tiers of the supply-chain gate read `uv.lock` and nothing else:
`osv-scanner` parses it directly, and the GuardDog sweep scans whatever
`uv export` flattens out of it. `.venv` is examined by neither. A package that
is **installed but not locked** is therefore scanned by nobody while remaining
importable by the application and by the test suite — it runs, and no tier can
report on it. This document describes the two mechanisms that keep the two in
step: recipe flags that stop the sweep installing anything, and a test that
fails when the environment and the lock disagree for any other reason.

The failure guarded against is narrower than "the venv is untidy". It is that
`upgrade-safe` **rejects a candidate and the rejected candidate's packages stay
installed** — including, in principle, the package whose finding caused the
rejection.

**Verified against** `7046a0d` here, and `18bba60` in `ai-common`, which carry
the same two changes.

## How the coupling is enforced

Two independent parts, one preventive and one detective.

**Preventive** — the sweep never writes to the environment or the lock:

```make
uv run --frozen --no-sync guarddog-cached $(GUARDDOG_BUDGET_FLAG) $(FLAT_REQUIREMENTS_FILE)
```

at `Makefile:84` (`scan`) and `Makefile:133` (`upgrade-safe`), identically in
both repositories.

**Detective** — `tests/test_environment_sync.py` runs, from the project root
and once per suite:

```
uv sync --check --frozen --all-groups
```

and asserts exit status `0`. It is an ordinary test in the default suite, not a
marked or opt-in one, because both drifts it was written for were found by hand
and neither would have been noticed on a schedule.

## Observed: `uv run` installs, and never removes

`uv run` synchronises the project environment before executing, and that
synchronisation is **inexact**: `--exact` ("Perform an exact sync, removing
extraneous packages") is an opt-in flag. Checked on both the old and new
resolver — uv **0.6.17** and uv **0.12.5** — so this is not something the
upgrade introduced or fixed.

Reproduced end to end in a scratch project on 2026-08-16, following the
`upgrade-safe` recipe step for step:

| step | `Makefile` | lock | environment |
|---|---|---|---|
| baseline sync | — | `1182038035eb` | no `iniconfig` |
| `cp uv.lock uv.lock.preupgrade` | 111 | `1182038035eb` | — |
| `uv lock --upgrade` → candidate | 121 | `fb43e381d1d4` | — |
| `uv export --frozen` → tier-2 input | 132 | — | — |
| `uv run guarddog-cached …` | 133 | — | `Installed 1 package in 2ms` |
| tier 2 blocks → `EXIT` trap restores lock | 114 | `1182038035eb` | untouched |
| `uv sync --all-groups` | 149 | **never reached** | — |

End state: the lock declared `iniconfig` **zero** times; the environment
contained it **twice** (package directory and `dist-info`). Re-running the same
sequence with `uv run --frozen --no-sync` ends with **zero**.

Two properties of the recipe make this structural rather than incidental. The
install at `Makefile:133` happens **before** GuardDog judges anything, so a
blocking finding cannot keep the package out of the environment. And the
repairing `uv sync --all-groups` at `Makefile:149` sits after
`rm -f uv.lock.preupgrade` on the **success path only**, so every path that
rejects a candidate — blocked, interrupted, or timed out — skips it.

## Observed: rejected candidates really do leave packages behind

Three instances on this machine, none of them synthetic, all found by hand:

- **`olefile==0.47` and `python-oxmsg==0.0.2`**, found in `clause-and-effect`
  while rebuilding the environment for the interpreter upgrade. They appear in
  no commit's `uv.lock` — `git log -S` over that path returns nothing for
  either name — while their GuardDog reports are stamped `12:27:25` and
  `12:38:04` on 2026-08-13, inside the candidate sweep the gate went on to
  reject.
- **`httpx2`, `httpcore2` and `truststore`**, found in `ai-common`, installed
  `14:56:01` and all marked `REQUESTED`. Not from the sweep: `httpx2` is an
  optional extra of `openai` (`Requires-Dist: httpx2<3,>=2.7.0; extra ==
  'httpx2'`) and locks do not carry extras, so this arrived from an
  extras-installing command.
- **All five together**, found in `clause-and-effect` by the new test on its
  first run. An `upgrade-safe` on the unpatched recipe had ended early:
  `uv.lock` rewritten `15:06:22`, all five installed `15:06:45`, report store
  `244 → 250`, and the lock afterwards back at the committed `d9784e59…`.

Neither `git status` nor either gate tier reported any of them, and the lock
was restored correctly every time — which is precisely why the drift is
silent. The second instance is the one that sets the scope: it did **not**
come from the sweep, so the preventive fix alone would not have caught it, and
a detective check is not redundant with it.

## Observed: `uv sync --check` detects both directions and mutates nothing

Measured on uv 0.12.5, 2026-08-16, taking the exit status directly rather than
through a pipeline:

| environment state | exit | last line of output |
|---|---|---|
| synchronised | **0** | "Would make no changes" |
| extraneous package installed | **1** | "The environment is outdated" |
| locked package missing | **1** | "The environment is outdated" |

And, with an extraneous package present and the check reporting failure, the
package count in `site-packages` and the `sha256` of `uv.lock` were both
**unchanged** across the invocation. A check that repaired what it measured
would make the test a mutation of the thing it guards.

## Argued: delegate the comparison rather than re-implement it

The obvious hand-rolled test — compare `importlib.metadata.distributions()`
against the lines of `uv export` — has to get three things right that are easy
to get subtly wrong:

- **Environment markers.** The export emits `colorama==0.4.6 ; sys_platform ==
  'win32'`, correctly absent on Linux. A naive comparison reports it missing.
- **The project itself.** `ai-common==0.1.0` is installed in its own
  environment and is not emitted by `uv export`. A naive comparison reports it
  extraneous.
- **Both directions.** Under-installation is drift too, and is the direction a
  set-difference written to catch extras will silently miss.

`uv sync --check` already answers all three, from the same resolver that wrote
the lock. Re-implementing them would put a second, independently-wrong opinion
about the lock's meaning into the repository.

## Argued: prevent rather than repair, and `--exact` is not a fix

Three candidate fixes were considered:

- **`uv run --exact`** — rejected. It makes the environment match the
  *candidate* exactly rather than accumulate on top of it, but after the trap
  reverts the lock the environment is still the candidate's package set. It
  reduces accumulation across repeated runs; it does not prevent the drift.
- **Re-sync inside the `EXIT` trap** — rejected as the primary fix. It repairs
  after the fact, adds a full sync to the interrupt path at the moment the
  operator is trying to stop, and only helps if the trap runs at all.
- **`uv run --no-sync`** — adopted. The install never happens. The sweep does
  not need the candidate installed: it reads the flattened requirements file
  and fetches each package's artifact from PyPI itself, so the environment's
  contents are irrelevant to what it scans.

`--frozen` is paired with it for the sibling hazard: `uv run` updates `uv.lock`
when it considers it stale, and at `Makefile:133` the lock *is* the candidate.
This is the same reasoning already recorded for `uv export --frozen` at
`Makefile:54-60` — the recipe must neither rewrite the lock nor mutate the
environment.

## Argued: `--all-groups`, and stripping `VIRTUAL_ENV`

**`--all-groups`** is the environment `upgrade-safe` builds when it adopts a
candidate (`Makefile:149`), which makes it this project's own definition of a
complete environment. The accepted cost is that a developer who deliberately
synchronises a lighter environment — default plus `test` only — sees this test
fail. That is a true report of a difference from the canonical environment, not
a false positive, and the assertion message names the repair.

**`VIRTUAL_ENV` is removed** from the subprocess environment so the check
always targets the project's own `.venv` rather than whatever the calling shell
has activated. This is not defensive programming against a hypothetical: on
2026-08-16 a measurement of `ai-common`'s environment silently reported
`clause-and-effect`'s, because that repository's venv was active in the shell
and `uv pip list` honoured it over the working directory. The reading was
plausible — a package count, in the right ballpark — and was caught only
because 74 locked packages cannot produce 174 installed ones.

## Known gaps

- **A skip is not a pass.** The test is skipped when `uv` is absent from
  `PATH`, and a skipped tripwire is indistinguishable from a healthy one in the
  summary line. Deliberate, so the suite stays runnable without uv; revisit if
  the suite ever runs anywhere that guarantees it.
- **It fires only when the suite runs.** Neither repository has CI
  ([`todo.md`](../todo.md), "no CI covers any of this"), so this catches drift
  on whichever machine happens to run `make test`. Both 2026-08-16 instances
  would have been caught; neither would have been caught *promptly*.
- **Identity, not integrity.** The check compares package names and versions.
  A locked package whose installed files have been modified in place matches
  the lock and passes. Artifact integrity is `uv.lock`'s hashes at install
  time, not this test.
- **Two repositories, by hand.** The test is duplicated in
  `clause-and-effect` and `ai-common` rather than shared, and nothing keeps the
  two copies in step.
- **The sweep's own tool environment is out of scope.** GuardDog runs from a
  uv-managed tool environment on distro Python, which no lock in either
  repository describes. See the deferred "does the toolchain belong inside the
  gate?" question in [`todo.md`](../todo.md).
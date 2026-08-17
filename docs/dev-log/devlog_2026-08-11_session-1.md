# 2026-08-11 · session 1

**Repositories worked in:** `ai-common` (`lazy-package-init`) for all code;
`clause-and-effect` (`dev-03`) for documentation only.
**State at close:** all three GuardDog 3.1.0 blockers closed. `ai-common`
**103 tests passing** (was 92), 13 mutants killed with no survivors. The
kernel sandbox is working and **fully enforced** — `--no-sandbox` was not
needed and 2.10.0 was not rolled back.

**Theme:** the blocker that had been recorded as *"the sandbox cannot get
entropy on this machine"* was not about entropy, and the error message that
said so was accurate about its own stack frame and wrong about the cause. One
`strace` line settled it. The rest of the session re-based the tier-2 gate off
rule names, measured the new threshold against 74 real dependencies, and
tightened three things in the Makefile that the measurement exposed.

---

## The sandbox failure was a filesystem denial wearing an entropy error's clothing

`_Py_HashRandomization_Init: failed to get random numbers to initialize Python`
named the random-number subsystem. `strace`, run from *inside* the sandbox by
making the tracer the sandboxed command, named something else:

```
getrandom("\xec\x23\x5f\x2d...", 8, GRND_NONBLOCK) = 8      ← succeeds
openat(AT_FDCWD, "/dev/urandom", O_RDONLY|O_CLOEXEC) = -1 EACCES
Fatal Python error: _Py_HashRandomization_Init
```

A `getrandom` call three lines above the failure **succeeds**. The kernel was
handing out randomness throughout. Two facts combined:

| | |
|---|---|
| GuardDog's capability set grants no path under `/dev` | `_get_common_read_paths()` ends in `if os.path.isdir(variant)`, so a character device cannot pass through it |
| The interpreter GuardDog runs on cannot use the syscall | python-build-standalone builds CPython with `HAVE_GETRANDOM=0`, `HAVE_GETRANDOM_SYSCALL=0`, `HAVE_GETENTROPY=0`, so hash-seed init *must* open `/dev/urandom` |

`/usr/bin/python3` has all three probes at 1 and never touches the file. The
second fact follows from `uv tool install guarddog`; upstream presumably runs
distro interpreters in CI, which is inference and is recorded as such.

**Fixed by pinning the tool to the system interpreter:**
`uv tool install --force --python /usr/bin/python3.12 guarddog`. The receipt
records `python = "/usr/bin/python3.12"` and the pin was demonstrated to
survive `uv tool upgrade` by forcing a real 3.0.0 → 3.1.0 upgrade in an
isolated `UV_TOOL_DIR`. That run also established that **3.1.0 is the latest
release**, so no upstream fix is pending.

The alternative — `allow_file("/dev/urandom", READ)` at both grant sites in
GuardDog's `sandbox.py` — was implemented and verified end-to-end on the 3.13
interpreter that fails today, and produces identical results. It is the
upstreamable fix and was **not** applied locally, because a patch to a
`uv tool` venv is erased by the next upgrade. **Not yet reported upstream.**

**The sandbox is still enforcing**, which was tested explicitly because every
green result is equally consistent with a disabled sandbox: a child under
GuardDog's own capability set gets `EACCES` on `~/.ssh`, `$HOME`, this repo's
source and `/etc/shadow`, and both TCP and DNS are blocked, while granted temp
writes still work.

Written up in full at
[`docs/lessons-learned/2026-08-11-guarddog-sandbox-dev-urandom.md`](../lessons-learned/2026-08-11-guarddog-sandbox-dev-urandom.md).

## The gate no longer matches rule names, and cannot go silently inert again

Blocker 2 was that GuardDog 3 renamed all 61 rules and not one of the seven in
`BLOCKING_RULES` survived. The fix is not a new list of names — a new list
would fail the same way at the next rename.

**The verdict now rests on `risks[].severity`**, a three-value vocabulary
(`low`/`medium`/`high`) that GuardDog derives itself. Reading its
`risk_engine.py` established what the value means: a risk's severity is its
threat rule's severity, **downgraded one level when the correlating capability
is in another file and two when it is in another category**. So `high` is a
high-severity rule that either stands alone — install-time, or specific enough
to be malware-only — or correlates inside a single file.

Two guards make the previous failure structurally impossible:

- **An unrecognised severity blocks.** The old gate asked "is this name in my
  list?", so a vocabulary it no longer recognised answered *no* to everything.
  Defaulting the other way makes a moved vocabulary noisy, which is
  survivable, instead of silent, which is not.
- **A completed scan whose report has no `risks` field is INCOMPLETE**, not
  clean — the field the verdict rests on cannot be optional.

`BLOCKING_RULES` was **deleted rather than updated**: dead configuration that
looks live is what caused the blocker. Cache schema 3 → 4, since schema-3
entries store rule names v3 renamed. `findings` is no longer stored either —
nothing read it after the re-base and it was roughly twice the size of `risks`
in a machine-wide cache.

## Blocker 3: `results` is required only when nothing else explains its absence

The report-shape guard demanded `errors` *and* `results`, but a failing v3
report has keys exactly `['package', 'issues', 'errors']`. The guard therefore
answered *"unrecognised report shape"* and discarded GuardDog's real message.
`errors` is still required unconditionally; `results` is required only when
`errors` is empty. Pinned by a test carrying the verbatim sandbox failure text
recorded that morning.

## GuardDog's own risk label is unusable as a gate, and the measurement says so twice

The obvious candidate — block on `risk_score.label == high_risk` — was
rejected on evidence. Across **74 known-good ai-common dependencies**:

| candidate criterion | blocks | which |
|---|---|---|
| `risk_score.label == high_risk` | 2/74 | pyyaml, tqdm |
| any risk at all | 16/74 | unusable |
| **severity ≥ high** *(chosen)* | **3/74** | google-genai, pillow, pyyaml |
| severity ≥ medium | 8/74 | |

The two signals disagree in **opposite directions on real packages**:
`tqdm` scores 7.2/10 `high_risk` with nothing above medium severity, while
`google-genai` scores 4.9/10 `low` and carries a high-severity risk. Gating on
the label would block tqdm and miss google-genai. The label is now reported and
deliberately not acted upon.

All five high-severity findings were read rather than counted:

| package | rule | matched | assessment |
|---|---|---|---|
| `google-genai` | steganography | a `VertexAISearch(datastore=…)` string in the package's own test file | false positive |
| `pillow` | steganography | `def eval(image, *args)` — Pillow's documented per-pixel API | false positive |
| `pyyaml` ×3 | dynamic-loader | `__import__(name)` in `yaml/constructor.py` | **behaviourally true** |

pyyaml's is not a false positive: that code is the `FullConstructor` /
`UnsafeConstructor` path, the reason `yaml.safe_load` exists. Waiving it means
a human affirming "we know, we use `safe_load`", which is worth recording
rather than suppressing.

**3/74 ≈ 4% is the one-time adoption cost**, against 26/91 ≈ 29% for the v2
"block on any finding" option rejected last session. The distinction matters
because an unreadable waiver list produces rubber-stamping, which is worse
than no gate.

## Only one of the two error types has been measured

Everything above is a false-positive rate. There are 74 known-good packages
and **zero known-bad ones**, so nothing yet demonstrates that
`severity >= high` *fires* on download-and-execute, base64 `exec`, or
install-time network. The v2 rule list would also have looked clean under a
false-positive sweep — it blocked nothing on good packages because it blocked
nothing at all. A noise measurement cannot separate "well-calibrated" from
"inert". The assistant proposed a local fixture package carrying those
patterns, scanned but never installed or executed; **not built this session.**

## Three Makefile defects, one of them capable of scanning the wrong repository

Found while verifying the above, and fixed at Bertan's direction.

**`uv export` was rewriting `uv.lock`.** The recipe passed neither `--frozen`
nor `--locked`. Demonstrated on a scratch copy: adding one dependency to
`pyproject.toml` and running the recipe's exact export **rewrote `uv.lock`**
and pulled the new package into the scanned set. A recipe that reads as
read-only was editing the lockfile and then scanning a resolution nobody
chose — and `verify` would audit the committed lock in tier 1 while GuardDog
examined a different one in tier 2. `--frozen` added to both export sites;
verified the same drift case now leaves the lock `OK` and the drifted package
absent.

**`GUARDDOG_CACHE` named the one thing it was not.** It is the flattened
requirements file, not the GuardDog cache — which is machine-wide and lives at
`~/.cache/guarddog-cached/`. Renamed to `FLAT_REQUIREMENTS_FILE`.

**Its fixed `/tmp` path could make a sweep scan another repository's
dependencies.** `main()` reads the requirements file once at startup, so a
second project exporting between this project's export and its read would make
this sweep scan the other project's packages **and report a pass on them** —
silently, because every line in that file is a legitimate `name==version`
pair. Moved to a repo-local `tmp/flat-requirements.txt` at Bertan's direction.
`tmp/` is gitignored but **git does not track empty directories, so it does not
exist in a fresh clone**; a `mkdir -p` was added to both recipes and verified by
deleting `tmp/` and running `make scan`. Bertan ruled that two simultaneous
sweeps *within one repository* will not be handled — they would be fighting
over `uv.lock` as well — and that decision is recorded as a comment in the
Makefile rather than as machinery.

**`EXIT_UNFINISHED` does not survive `make`.** The recipe exits 75; make
reports `Error 75` and then exits **2**, as it does for every failure. `scan`
had run the wrapper as its last command, so a budget-exhausted sweep produced
a bare make error. It now captures the status, states that UNFINISHED is not a
pass, and points a caller who needs the raw code at the wrapper directly.

## A waiver policy and an upgrade policy that pull against each other

Bertan set the schedule: **`make upgrade-safe` must complete before a PR is
closed and merged** — the latest acceptable point, not the intended cadence.

Bertan then ran it and reported `google-genai==2.17.0` BLOCKED. Comparing that
release against the 2.11.0 report from the calibration sweep: **same rule, same
file, same line 217, same matched code**, six minor versions apart.

Waivers are keyed on `(name, version)` by deliberate design — a new version is
new code and the review does not transfer. Combined with the merge-time policy,
every google-genai bump re-blocks on an identical, already-reviewed false
positive. The design is right and the friction is real, and friction on a
security gate becomes rubber-stamping. Three options were put to Bertan:
leave it; surface the prior decision as context while still requiring a fresh
waiver; or key waivers on `(package, rule, hash of matched code)`. **Undecided
at session close.**

---

## Verification

- `ai-common` suite **92 → 103**.
- **13 mutants, 0 survivors, 0 broken mutants.** Each mutant was checked to
  have actually changed the file before the suite ran — a broken mutant reports
  a false clean, which happened last session. The set included re-introducing
  blocker 3, flipping the unknown-severity default, `>=` → `>`, leaving the
  cache schema at 3, and dropping `severity` from the stored fields.
- **End-to-end against real GuardDog 3.1.0**, not only the test shim: `six`
  clean, `tqdm` advisory with both risks reported, `google-genai` blocked at
  the exact file and line. Adding that rule to `accepted.json` then gave
  `3 cached, 0 scanned` and exit 0 — re-judged from cache without re-scanning,
  with the waived finding still *reported* rather than hidden.
- `make scan` exercised through the Makefile, including from a deleted `tmp/`,
  reaching a real BLOCKED verdict on the predicted package.

## Mistakes made this session

All the assistant's unless stated.

- **The first sandbox-enforcement test proved nothing.** It used
  `os.path.expanduser("~/.ssh")` and reported `FileNotFoundError` as *blocked*,
  but `nono.sandboxed_exec` does not inherit the environment, so `HOME` was
  unset and `expanduser` returned a literal `~`. It would have passed against a
  sandbox doing nothing at all. Caught by reading the error *type* rather than
  the pass/fail column, and redone with absolute paths.
- **A Makefile stub used `exit $(RC)`**, terminating the shell before the branch
  it was written to exercise. It reported the right exit codes while testing
  nothing. Same shape as the broken mutant of 2026-08-10.
- **A calibration number was reported from partial data and was wrong.** At 28
  of 74 packages the assistant reported "1 block"; the full set says 3. The
  figure was labelled as partial, but it should not have been offered as a
  basis for judging the threshold at all.
- **The calibration sweep was written to `/tmp` rather than anywhere reusable.**
  Bertan questioned this. The isolation was defensible while the schema and
  verdict logic were still in flux, but it was never revisited once they
  settled, so an hour of scanning produced data that the real cache could have
  held. The raw reports remain a strict superset of what a cache entry needs.
- **The wrapper's own README claim was carried forward unchecked** — that the
  gate blocked on a named rule set — until the rename made it false.

## State handed to the next session

| | |
|---|---|
| `ai-common` | `lazy-package-init`; 4 files committed this session; 103 tests |
| `clause-and-effect` | `dev-03`; documentation only — no source change |
| guarddog on this machine | 3.1.0, pinned to `/usr/bin/python3.12`, sandbox enforced |
| Shared cache | schema 4, populated incrementally by this session's runs |
| `accepted.json` | **still does not exist** |
| Tier-2 sweep | runs; **fails on 3 packages pending waivers** |

**Open, in order.**

1. **🔺 The three baseline waivers** — `google-genai`, `pillow`, `pyyaml`.
   `upgrade-safe` cannot pass on the committed lock until they exist, and
   Bertan's merge policy makes that **merge-blocking for
   `lazy-package-init`**. pyyaml's is a real judgement, not a rubber stamp.
2. **Decide the waiver-keying question** raised by google-genai 2.17.0.
3. **Verify the gate's detection side** with a local fixture package. Until
   this exists, `BLOCKING_SEVERITY = "high"` has a measured noise floor and an
   assumed catch rate.
4. **Merge `lazy-package-init` and re-point this repo's pin.**
   `pyproject.toml` has `ai-common @ git+…@main`, so none of the import-cost
   win or the gate rework reaches `clause-and-effect` until then. It also
   unblocks deleting `scripts/guarddog_cached.py`. `guarddog-cached` is a
   declared console script, so this repo's Makefile can use the identical
   invocation — no import shim is needed, contrary to what was assumed at the
   time.
5. **Report the `/dev/urandom` bug upstream to GuardDog.**
6. **The remaining two `ai_common` optimisations** (six provider SDKs inside
   `get_llm`; `BaseChatModel` behind `TYPE_CHECKING`). Re-measure first.
7. **The Dependabot alert on `ai-common`'s `main`** —
   <https://github.com/bgunyel/ai-common/security/dependabot/33>.
8. Then the sequence this repo was already on: **the re-index** against
   `5caac594…`, **gold chunk IDs (P0)**, **the sufficiency judge from stage C**.
   None moved today.
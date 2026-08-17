# The sandbox that could not read `/dev/urandom`: an error message that named the wrong subsystem

**Date:** 2026-08-11
**Branch:** `dev-03` (no repository change; the fix is machine configuration)
**Components:** `guarddog` 3.1.0 (`guarddog/sandbox.py`), `nono_py` 0.15.0,
the tier-2 gate in `ai-common` (`src/ai_common/security/guarddog_cached.py`,
branch `lazy-package-init`), `scripts/guarddog_cached.py` in this repo
**Severity:** High — the dependency-scanning gate reported *pass* while
scanning nothing at all. Not a corruption bug; a **security control that was
silently inert**.

---

## 1. Summary

After upgrading GuardDog 2.10.0 → 3.1.0 on 2026-08-10, every scan on this
machine failed inside GuardDog's mandatory kernel sandbox with:

```
Fatal Python error: _Py_HashRandomization_Init: failed to get random numbers
to initialize Python
```

The message names the random-number subsystem. **It was not a randomness
problem.** The sandbox denies the sandboxed process access to `/dev/urandom`,
and this particular CPython build has no other way to seed its hash
randomisation, so the interpreter dies before `main()`.

Two independent facts had to be true at once, which is why the failure looked
exotic:

| # | Fact | Measured |
|---|---|---|
| 1 | GuardDog's capability set grants **no path under `/dev`** — `_get_common_read_paths()` ends in `if os.path.isdir(variant)`, so a character device cannot pass through it | `guarddog/sandbox.py:166-169` |
| 2 | The interpreter GuardDog runs on is a python-build-standalone build, configured with `HAVE_GETRANDOM=0`, so hash-seed init has **no syscall path** and must open `/dev/urandom` | `sysconfig.get_config_var` |

Fact 2 is a consequence of installing GuardDog with `uv tool install`. On a
distro interpreter the file is never opened and the sandbox works untouched.

Fixed by pinning the tool to the system interpreter — the sandbox stays fully
enforced:

```
uv tool install --force --python /usr/bin/python3.12 guarddog
```

---

## 2. Environment

```
OS           Ubuntu 24.04.4 LTS       kernel 6.8.0-137-generic
LSMs         lockdown,capability,landlock,yama,apparmor
guarddog     3.1.0 (latest release)   nono_py 0.15.0
before       /home/bgunyel/.local/share/uv/python/cpython-3.13.3-linux-x86_64-gnu
after        /usr/bin/python3.12 (3.12.3)
```

GuardDog 3.0.0 made the `nono-py` kernel sandbox **mandatory**: a scan aborts
unless `nono.is_supported()` or `--no-sandbox` is passed. `is_supported()`
returned `True` here — Landlock is present and working. The sandbox was
available; it was the *contents* of the capability set that were wrong.

---

## 3. Symptom

Exactly what a user sees:

```
$ guarddog pypi scan six --version 1.17.0
Some rules failed to run while scanning six:

* download-package: Sandboxed extraction failed: Fatal Python error:
  _Py_HashRandomization_Init: failed to get random numbers to initialize Python
Python runtime state: preinitialized
No risks found in six
$ echo $?
0
```

Three things about that output are worth stating separately, because each one
independently makes the failure easy to miss:

- **"No risks found"** is printed for a package that was never extracted.
- **Exit code 0.** As established on 2026-08-10, GuardDog's exit code means
  only that GuardDog was *called* correctly; it is 0 for a clean scan, 0 for a
  scan that found malicious indicators, and 0 here.
- The real diagnostic *is* printed, but above the verdict, and the verdict
  contradicts it.

Under JSON output the failing report's keys are `['package', 'issues',
'errors']` — `results` is absent entirely, i.e. **0 of 61 rules ran**.

---

## 4. What the problem was first believed to be

The 2026-08-10 session recorded finding 1 as *"the sandbox cannot start on this
machine — it cannot obtain entropy to start its inner Python"*, and framed the
open decision as: investigate the entropy failure, accept `--no-sandbox`, or
roll back to 2.10.0.

That reading came straight from the error string, and it was wrong in a
specific and consequential way. It pointed at a **host property** — kernel RNG,
entropy pool, missing `haveged`, a container without `/dev/random` — which is
the class of problem that is genuinely hard to fix and often ends in disabling
the protection. Two of the three options on the table (`--no-sandbox`,
rollback) were *give up on the sandbox*, and they were on the table because the
diagnosis implied the machine, not the tool, was at fault.

The actual defect is in GuardDog's capability set and is a one-line fix.

**The lesson is not "the assistant misread the error."** The message
`failed to get random numbers` is CPython's, and it is accurate about what
CPython was trying to do; it simply cannot see *why* it failed, because
`openat` returning `EACCES` is indistinguishable from any other failure at that
point in interpreter start-up. An error message describes the frame it was
raised in, not the cause. Nothing short of tracing the syscalls could have
distinguished the two hypotheses.

---

## 5. The real problem

### 5.1 CPython's two paths to a hash seed

`_Py_HashRandomization_Init` calls `pyurandom()`, which prefers the
`getrandom(2)` syscall and falls back to reading `/dev/urandom`. Which path
exists is decided **at build time**:

| interpreter | `HAVE_GETRANDOM` | `HAVE_GETRANDOM_SYSCALL` | `HAVE_GETENTROPY` |
|---|---|---|---|
| uv-managed CPython 3.13.3 (python-build-standalone) | **0** | **0** | **0** |
| `/usr/bin/python3` (Ubuntu 24.04, 3.12.3) | 1 | 1 | 1 |

With all three at 0 there is no syscall path compiled in at all, so the
standalone build opens `/dev/urandom` unconditionally on every start-up. This
is a property of the *build*, not of the machine or the kernel — the kernel
here supports `getrandom` fine.

### 5.2 GuardDog grants no path under `/dev`

`guarddog/sandbox.py::_get_common_read_paths()` builds its list from
`sys.prefix`, `sys.base_prefix`, `/usr`, `/lib`, the SSL cert dirs, the
guarddog package dir, and every `sys.path` entry — then filters:

```python
for candidate in candidates:
    for variant in _path_variants(candidate):
        if os.path.isdir(variant):
            paths.add(variant)
```

`/dev` is not a candidate, and the `isdir` filter means the function is
structurally incapable of granting a device file even if one were added.
`CapabilitySet` has a separate `allow_file()` for exactly this; `sandbox.py`
uses it only for archive paths.

### 5.3 Why the two combine into a false "clean"

`extract_sandboxed()` runs the extraction as `[sys.executable, "-m",
guarddog.sandbox, ...]` under `nono.sandboxed_exec`. `sys.executable` is the
interpreter GuardDog itself runs on. So:

`uv tool install guarddog` → GuardDog runs on a standalone build →
`sys.executable` is a standalone build → the sandboxed child cannot read
`/dev/urandom` → extraction subprocess dies → no files extracted → **0 rules
run** → "No risks found", exit 0.

Upstream presumably does not see this because CI and most contributors run
distro or actions-provided interpreters — *this part is inference, not
measured.* What is measured is that the failure is deterministic on the
standalone build and absent on the distro build.

---

## 6. How the real cause was found

Four steps, each one discriminating between hypotheses rather than confirming
a guess.

**Step 1 — reproduce outside GuardDog.** A probe built GuardDog's exact
capability set and ran `python -c "print('ok')"` under `nono.sandboxed_exec`.
It failed identically, which removed GuardDog's rule engine, archive handling,
and cache from the problem entirely.

**Step 2 — bisect the capability set.** The same probe, varying one grant:

| capability set | inner Python |
|---|---|
| fs grants + `block_network()` (what GuardDog does) | **fails** |
| fs grants, **no** `block_network()` | **fails** |
| fs grants + `block_network()` + `allow_path("/dev", READ)` | **starts** |
| fs grants + `allow_path("/dev", READ)`, no network block | **starts** |
| `/bin/echo` instead of Python, full GuardDog caps | **runs** |

Two conclusions in one table: the network/seccomp layer is irrelevant (rows 1
vs 2), and it is a *filesystem* denial (rows 3, 4). Row 5 rules out
`sandboxed_exec` being broken as such.

**Step 3 — name the file.** `strace` was run *from inside* the sandbox by
making it the sandboxed command:

```
openat(AT_FDCWD, "/lib/x86_64-linux-gnu/libc.so.6", O_RDONLY|O_CLOEXEC) = 3
getrandom("\xec\x23\x5f\x2d\x10\xc8\xdf\x54", 8, GRND_NONBLOCK) = 8
openat(AT_FDCWD, "/usr/lib/locale/locale-archive", O_RDONLY|O_CLOEXEC) = 3
openat(AT_FDCWD, "/dev/urandom", O_RDONLY|O_CLOEXEC) = -1 EACCES (Permission denied)
Fatal Python error: _Py_HashRandomization_Init: failed to get random numbers
```

This is the decisive line, and it also **falsifies the entropy hypothesis
outright**: a `getrandom` call three lines earlier *succeeds*, returning 8
bytes. (That one is glibc's own pointer guard, not CPython's.) The kernel was
handing out randomness the whole time.

Narrowed to a single file: `allow_file("/dev/urandom", READ)` alone — no
`/dev` directory grant — was sufficient.

**Step 4 — explain why the syscall was not used.** `sysconfig` on both
interpreters gave the table in §5.1. This step is what turned a workaround into
an explanation, and it is what produced the no-patch fix: if the *build* decides
the behaviour, changing the build changes the behaviour.

A near-miss worth recording: the same strace shows `/etc/ld.so.cache` also
returning `EACCES`. It is harmless — the loader falls back to searching `/lib`,
which is granted — but it is a second unlisted path that happens not to be
fatal. A reader debugging a related failure should not assume `/dev/urandom` is
the only gap.

---

## 7. The fix

Two fixes were validated. Both were measured end-to-end, not reasoned about.

### 7.1 Applied: pin the tool to the distro interpreter

```
uv tool install --force --python /usr/bin/python3.12 guarddog
```

GuardDog requires `>=3.10`; the system has 3.12.3. No patching, nothing to
maintain, and **the sandbox remains fully enforced** — the point of the
exercise.

Durability was tested rather than assumed, because the pre-existing receipt
recorded no interpreter at all. In an isolated `UV_TOOL_DIR`, GuardDog was
installed at 3.0.0 pinned to `/usr/bin/python3.12` and then genuinely upgraded:

```
 - guarddog==3.0.0
 + guarddog==3.1.0
$ readlink -f tooldir/guarddog/bin/python  →  /usr/bin/python3.12
$ grep ^python tooldir/guarddog/uv-receipt.toml
python = "/usr/bin/python3.12"
```

The pin survives `uv tool upgrade`. That same run also established that
**3.1.0 is the latest release**, so there is no upstream fix to wait for.

Revert with `uv tool install --force guarddog`.

### 7.2 Validated but not applied: patch GuardDog

Add a companion to `_get_common_read_paths()` and call it at both grant sites
(`apply_sandbox` and `extract_sandboxed`):

```python
def _get_common_read_files() -> list[str]:
    return [path for path in ("/dev/urandom",) if os.path.exists(path)]

for file_path in _get_common_read_files():
    caps.allow_file(file_path, nono.AccessMode.READ)
```

Applied to a throwaway 3.13 venv, this produced results identical to §8 on the
interpreter that fails today. This is the **upstreamable** fix and the one that
helps everyone else; the pin only helps this machine. Not applied locally
because a patch to a `uv tool` venv is erased by the next upgrade — which is
precisely the trade-off between the two options.

---

## 8. Verification

All figures below are from the real install after the fix, not the test venvs.

**Rules actually run, and reports are complete:**

| package | `errors` | rules run | risk score |
|---|---|---|---|
| `six` 1.17.0 | `{}` | 61 | 0.0 `no_risks_detected` |
| `requests` | `{}` | 61 | 0.0 `no_risks_detected` |
| `cryptography` | `{}` | 61 | 0.0 `no_risks_detected` |
| `pydantic` | `{}` | 61 | 0.0 `no_risks_detected` |
| `numpy` | `{}` | 61 | 4.9 `low` |
| `pyyaml` | `{}` | 61 | 8.8 `high_risk` |
| `tqdm` 4.67.1 | `{}` | 61 | **7.2 `high_risk`** |

`tqdm` is the load-bearing row. 7.2/10 `high_risk` is the exact value recorded
for it under v3 on 2026-08-10, from a run whose extraction had also failed but
whose *metadata* rules still ran. Reproducing it — together with 61/61 rules
and an empty `errors` map — is positive evidence that extraction genuinely
happened, as opposed to the scan merely no longer complaining. Large binary
wheels (`numpy`, `cryptography`) were included deliberately: they exercise
extraction far harder than `six` does.

**The sandbox is still enforcing.** A "fix" that worked by weakening the
sandbox would produce the same green table above, so this was tested
explicitly. A child was launched under GuardDog's own capability set:

```
inner python started (so /dev/urandom is readable)
  blocked   list /home/bgunyel/.ssh: PermissionError [Errno 13]
  blocked   stat /home/bgunyel: PermissionError [Errno 13]
  blocked   read /etc/shadow: PermissionError [Errno 13]
  blocked   read this repo's source: PermissionError [Errno 13]
  blocked   write into /home/bgunyel: PermissionError [Errno 13]
  blocked   outbound TCP to 1.1.1.1:443: PermissionError [Errno 13]
  blocked   DNS lookup: gaierror [Errno -3]
  ok        granted tmp write still works
```

The last line matters as much as the blocks: it shows the sandbox is not simply
denying everything.

**Cache keys are unaffected:** `guarddog --version` still emits a bare
`3.1.0`, so the shared machine-wide cache keys do not move as a result of the
fix.

### 8.1 A verification step that initially proved nothing

The first version of the enforcement test used
`os.path.expanduser("~/.ssh")` and reported `FileNotFoundError: '~/.ssh'` as
*blocked*. That is not a denial — `nono.sandboxed_exec` does not inherit the
environment by default, so `HOME` was unset and `expanduser` returned the
literal string `~`. The test would have reported "blocked" against a sandbox
that was doing nothing at all.

Caught by reading the error type rather than the pass/fail column, and redone
with absolute paths, which produced the `PermissionError [Errno 13]` results
above. This is the same failure mode as the mutation-testing findings of
2026-08-10 — **a check whose expected value is computed by the same broken
machinery it is checking** — arriving by a new route: the check inherited its
notion of "home" from an environment the sandbox had deliberately emptied.

---

## 9. Why this was caught at all

It was caught because of work done *before* it happened. On 2026-08-10 the
wrapper was rebuilt to stop trusting GuardDog's exit code and to derive its own
verdict from JSON, with `errors` non-empty ⇒ `INCOMPLETE` ⇒ **gate fails**.

Had the sweep been launched on the old wrapper, the sequence would have been:
~91 packages scanned by a dead sandbox → 91 verdicts of "no risks found", exit
0 → written into a **machine-wide** cache shared by every project on this host →
`✓ Clean across both tiers` → `uv.lock` upgrade adopted. The corruption would
have outlived the session and been invisible from any single project.

The general shape is worth naming: **the defence that caught this was the one
that refused to infer success from an absence of complaints.** Both mechanisms
that failed here — the exit code, and "no risks found" — are *negative*
signals. The check that worked asked a positive question: *did the rules
actually run?*

---

## 10. Generalisable lessons

1. **An error message names the frame, not the cause.** `failed to get random
   numbers` is CPython accurately reporting its own situation and being unable
   to see that a `openat` returned `EACCES`. Treat the subsystem named in a
   message as the *first* hypothesis, never the conclusion — especially when it
   points at the host rather than the tool, because host-shaped diagnoses lead
   to giving up the control.

2. **`strace` inside the failing boundary beats inference about it.** Three
   hypotheses (entropy, seccomp, Landlock) were alive after 20 minutes of
   reading source. One line of `strace` output killed two of them and named the
   file. The sandbox permits this: make the tracer the sandboxed command.

3. **Bisect the configuration, not the theory.** Toggling one capability at a
   time separated "network layer" from "filesystem layer" before anything was
   understood about *why*. Cheap, and it constrains the search.

4. **A standalone interpreter is not a drop-in for a distro one.** uv, rye and
   mise install python-build-standalone builds with different
   `HAVE_*` configuration than distro CPython. Anything that sandboxes,
   confines, or audits syscalls can behave differently under them. This is a
   general hazard, not a one-off.

5. **Security tooling must fail loud, and "no findings" is not "ran".**
   A scanner that cannot scan should never be able to emit a pass. Verify the
   *positive* fact — rules executed, files extracted — rather than the absence
   of a complaint.

6. **Test that the fix did not work by removing the protection.** Every green
   result in §8 is also consistent with a disabled sandbox. §8's escape test is
   what distinguishes them, and it belongs in the verification of any fix to a
   confinement mechanism.

7. **Prefer the fix that survives maintenance, and measure that it does.**
   The interpreter pin was chosen over the source patch because a `uv tool`
   venv is rewritten on upgrade. That the pin persists was demonstrated with a
   real version upgrade, not assumed from documentation.

---

## 11. Residual risk and open items

- **The pin is invisible and undefended.** Anyone running
  `uv tool install --force guarddog`, or installing on a fresh machine, gets a
  dead sandbox again with no warning at install time. Mitigation is the
  `INCOMPLETE` verdict in §9, which turns it into a loud gate failure rather
  than a false pass — a reason to treat that check as load-bearing and not
  relax it. A cheap belt-and-braces addition would be a canary scan of a known
  package asserting `errors == {}` before a sweep starts; not implemented.
- **Not reported upstream yet.** The §7.2 patch is a genuine GuardDog bug
  affecting Linux installs on standalone interpreters, present in the latest
  release (3.1.0).
- **Only 3.13.3 was measured** on the standalone side. The mechanism implies
  other python-build-standalone versions behave the same way; that was not
  tested.
- **macOS was not tested.** `sandbox.py`'s own comments state that Seatbelt
  includes system paths by default where Landlock does not, which suggests the
  bug is Linux-only — inference from a source comment, not a measurement.
- **The two remaining blockers from 2026-08-10 are untouched**: `BLOCKING_RULES`
  still holds seven v2 rule names, none of which exist in v3's 61-rule
  `capability-*`/`threat-*` taxonomy; and the report-shape guard still discards
  GuardDog's real error message when `results` is absent. The tier-2 sweep
  should not be trusted until both are fixed.
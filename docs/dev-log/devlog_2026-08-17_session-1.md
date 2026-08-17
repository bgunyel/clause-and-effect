# 2026-08-17 · session 1

**Repositories worked in:** `clause-and-effect` (`dev-03`) — four commits,
`2518859..9f12506`, merged into `main` as **PR #4** (`3dc7a33`), branch rotated
to `dev-04`; `ai-common` (`main`) — two PRs opened and merged, **#28** and
**#29**, `4a433aa → a0f06ea`, both branches deleted.
**State at close:** `make verify` **exits 0** in `clause-and-effect` for the
first time — tier 1 clean, tier 2 `BLOCKED 0 / INCOMPLETE 0`. Trees clean,
suites green at **249 passed / 5 xfailed** and **146 passed**. Waivers 9 → 21;
GuardDog blocking reports 12 → 0.

**Theme:** the session opened on a `make upgrade-safe` that had been running for
85 minutes and would never have finished, and the thread from there reached the
gate's remaining eight blockers, the twenty decisions needed to clear them, and
the first end-to-end green run the project has had. Two findings outrank the
upgrade itself: **a `subprocess.run` in the sweep had no timeout, so one dead
socket stalled everything indefinitely**, and **GuardDog's `max_hits` truncates
what a reviewer can see, so a report showing one match can be hiding nine.**

---

## An 82-minute stall was a dead socket that nothing was watching for

Bertan reported an `upgrade-safe` started an hour earlier. It was alive and
making no progress: 85 minutes elapsed, **4 seconds of CPU**, blocked in
`wait_woken`, and holding an `ESTABLISHED` socket to GitHub with empty send and
receive queues and **no timer armed**. A 98 MB temp pack had last been written
82 minutes earlier.

GuardDog's `repository_integrity_mismatch` rule clones the upstream repo to
compare against the PyPI tarball, calling `pygit2.clone_repository` with no
timeout and no depth limit
(`analyzer/metadata/repository_integrity_mismatch.py:113`). The connection had
died without a FIN or an RST. With nothing queued to send, TCP never
retransmits and so never discovers the peer is gone; `SO_KEEPALIVE` was unset,
and Linux's default `tcp_keepalive_time` of 7200s would not have fired inside
the window regardless.

That it was a network event and not a slow package was settled by the retry:
after Bertan killed and restarted it, the same `docling` scan — including the
same 98 MB clone — completed in **138 seconds**.

`--time-budget` could not have covered this. By its own documentation it
"bounds when a scan *starts*, not when it ends". Three layers could have bounded
it and none did; only the third is ours, and it is the one that was fixed:
`_scan_once` called `subprocess.run` with no `timeout`.

**ai-common #28** adds `SCAN_TIMEOUT_SECONDS = 900.0`, chosen from measurement
rather than taste — the twelve real scans of the restarted sweep ran from 3s
(`orjson`) to 210s (`langchain-openrouter`), so 900 leaves better than 4x
headroom. A killed scan becomes an `errors` entry, which the existing rules
already handle: INCOMPLETE rather than a pass, not cached, retried next run. An
in-process retry was rejected — it would double the worst case, which is the
quantity the change exists to bound.

**ai-common #29** closes the second unbounded call. `get_guarddog_version` runs
before any package is looked at, so a wedge there stalls the sweep before it
starts. It touches no network, but it inherits whatever interpreter GuardDog is
installed on — and that failure has already happened once in this project, one
layer down. `VERSION_TIMEOUT_SECONDS = 60.0`, against 0.45s measured across
three runs. Stated plainly in the commit: unlike #28 this closes a hazard never
observed here.

Both were mutation-verified, and the mutation is what makes them worth trusting:
with the `timeout=` kwarg removed the tests fail **and the runs take 61s and
30.21s instead of ~1s**, waiting out the shims' sleeps. That is the unbounded
behaviour made visible rather than an assertion flipping.

## `max_hits` truncates the evidence a reviewer sees, and the review method changed halfway through

Bertan asked whether previous decisions about a package are checked before a new
version is reviewed. The assistant had done so for two packages and not
systematically for the rest, and had never opened `reviewed.json` at all.

Building that comparison properly produced the session's most consequential
finding. A first pass compared *reported findings* by rule and file and declared
five of the remaining pairs identical. Tightening it to include the **matched
text** broke one: `huggingface-hub==1.24.0` carried a `subprocess.run(` match
that 1.27.0 did not. That difference turned out to be an artefact —
`threat-process-download-exec` sets `max_hits = 3`, both versions contain all
the constructs, and GuardDog simply reported a different three — but the
corollary is not an artefact:

**Comparing reported findings across versions is unreliable in both
directions.** A difference does not imply changed behaviour, and identity does
not prove nothing new is present, because the quota can be spent before a new
match is reached. The sound check is diffing the two versions' source.

`transformers==5.8.1` shows the cost. `threat-runtime-obfuscation-steganography`
has `max_hits = 1`; the report names one file, and a package-wide scan for the
rule's own condition finds **ten**. All nine hidden ones were inspected and are
benign — seven `nn.Module.eval()` calls and three `ForImageTextRetrieval(`
collisions — but nothing in the tooling would have surfaced them, and a
report-level comparison would have passed the package on one file's evidence.

Every waiver written afterwards records whether its rule exhausted its quota and,
where it did, what the package-wide scan found.

## Eight blockers cleared by twenty decisions, of two different kinds

Twelve waivers across eight packages, each finding approved individually by
Bertan; `accepted.json` 9 → 21, with a matching ledger entry for each. The
classification distinction did real work:

| kind | packages |
|---|---|
| **rule defect** — matched something the rule does not detect | `docling-slim` ×2, `google-genai` ×2, `pandas`, `setuptools`, `transformers` |
| **real behaviour, accepted in context** — matched exactly what it says, and we never reach it | `typer` ×2, `huggingface-hub` ×2, `torch` (one of three) |

`torch==2.13.0` is the one that rested on judgement rather than on the code
being harmless. `torch/cuda/_memory_viz.py:101` fetches `flamegraph.pl` from an
**unpinned `master` URL** with no checksum, `chmod 0o755`, and executes it — then
re-executes the cached `~/.cache/flamegraph.pl` without re-verifying. The rule
fired on exactly the branch it was built for. It was accepted on reachability:
only `format_flamegraph` and its three callers reach it, nothing in `src/` or
`tests/` calls them, and Bertan asked for `~/.cache/flamegraph.pl` to be checked
— it does not exist anywhere under `$HOME`, so the path has never executed here.
Two caveats are recorded in the waiver: `torch.cuda._memory_viz` **is** imported
by a plain `import torch`, and the absence check is scoped to this machine.

On `typer`, Bertan chose to drop the unused direct dependency from
`pyproject.toml` rather than waive on that round — it was declared and imported
nowhere. That narrowed what the project owns without retiring the finding, since
the gate scans the lock and `typer` remains transitive; both versions were waived
later.

## Five waivers rested on claims about our own code that nothing enforced

The reachability waivers are assertions about *this repository*, not about the
packages. Waivers key on `(name, version)`, so they re-open when the package
changes and **never when we do**. `grep` confirmed nothing in the suite asserted
any of them: adding `import typer`, invoking the `hf` CLI, or profiling CUDA
memory would evaporate the premise while the waiver kept applying and the gate
kept passing.

`tests/test_waived_dependency_assumptions.py` (`99abc4d`) holds all five with an
AST-based scan, so a mention in a comment cannot trip it. Five violations were
injected one at a time and each produced exactly `1 failed, 4 passed` — every
guard catches its own violation and none is over-broad. The failure message names
the waiver and points at `guarddog-review`, because the correct response to a red
test is re-reviewing the waiver rather than deleting the line. What a pass does
not prove is stated in the docstring: `getattr`, `importlib.import_module` and a
computed argv all slip past.

## The scanner the gate runs is not the one PyPI publishes

Checking whether GuardDog 3.2.0 — released 2026-08-12, after the 3.1.0 pin —
had already fixed the three defects awaiting an upstream report established that
it had not, and turned up something else. The installed
`~/.local/share/uv/tools/guarddog/` contains `_get_common_read_files()` granting
`/dev/urandom`; **stock 3.1.0 downloaded from PyPI contains it zero times**, and
`sandbox.py` carries mtime `2026-08-11 09:21`.

The 08-11 log records that fix as validated but *not* applied locally. It was
applied. Per the append-only rule that log stays as written; the correction
belongs here.

Practical exposure is low and was overstated before it was measured. The tool is
pinned to `/usr/bin/python3.12`, which has `HAVE_GETRANDOM = 1`, so the
interpreter never reaches for `/dev/urandom` and the patch is **inert**. It
would be silently lost to any `uv tool upgrade`, costing nothing while the pin
holds, and mattering only if the pin were ever repointed at a
python-build-standalone build.

Bertan's recollection that the failure was a Python version mismatch was checked
and is not quite right, in a way that matters for the pin: measured on this
machine, distro 3.12.3 has `HAVE_GETRANDOM=1` while uv's standalone **3.13.15
and 3.12.10 both have 0**. It is a *build* difference, not a version one. A
standalone 3.12 would fail exactly as 3.13 does.

## A patch release changed six rule bodies while adding and removing none

3.1.0 → 3.2.0: 54 `.yar` files before, 54 after, none added or removed — and six
bodies changed (`capability-network-outbound`, `capability-process-spawn`,
`threat-network-exfiltration`, `threat-process-cryptomining`,
`threat-runtime-environment-read`, `threat-runtime-obfuscation-general`).

Waivers survive an upgrade by design, since the package's code has not changed.
But each waiver's note argues about what one specific rule does, and a rewritten
rule keeps its waiver while losing its justification. The intersection with the
five rules the 21 waivers rest on is **empty** — luck, not design, and only
checked because an unrelated question prompted the comparison. Recorded in
`docs/todo.md` (`c43d163`) with the diff to run and the sharper fix of storing a
rule-text digest beside each waiver.

Bertan initially asked for a design document covering what to do after a GuardDog
version increase, then withdrew it on reading that the interpreter and sandbox
half is already covered in full by
`docs/lessons-learned/2026-08-11-guarddog-sandbox-dev-urandom.md` and the key
mechanics are readable from `entry_key` and `waiver_key`. Only this hazard was
undocumented, so only it was written down.

## Both gate tiers pass, and `make verify` runs at all

`make verify` was **structurally** unusable here, not merely red: `verify: audit
scan` (`Makefile:96`) makes tier 1 a prerequisite and make stops at a failed one,
so tier 2 never ran under it. Both halves now pass in one invocation — tier 1
`No issues found` over 183 packages, tier 2 182 cached, clean 134, advisory 48,
`BLOCKED 0`, `INCOMPLETE 0`, exit 0.

The three tier-1 advisories were closed **by upgrading past them, not by
waiving**: `cryptography` 49.0.0 → 50.0.0 (PYSEC-2026-3552, 8.2 High), `h2`
4.3.0 → 4.4.1, `langchain` → 1.3.15. The lock moves 176 → 182 packages, 52
upgraded, 6 added, none removed — and the six added are the packages that kept
drifting into the environment unlocked (`httpx2`, `httpcore2`, `truststore`,
`olefile`, `python-oxmsg`). They are now real dependency edges: `openai` 3.1.0
requires `httpx2` outright rather than as an extra. Yesterday's drift did not
merely get prevented; it resolved itself.

`uv.lock` also migrated to format `revision = 3`, renaming `upload_time` across
~1539 lines. Verified representational rather than a re-resolution: exports from
the pre-change lock and this one are identical across all 618 lines except the
`ai-common` revision, and `osv-scanner` parses revision 3 unchanged.

---

## Verification

- `make verify` **exit 0** on the committed tip, run before PR #4 was opened, with
  the exit code read from `make` directly rather than through a pipeline.
- `clause-and-effect` **244 → 249 passed**, 5 xfailed; `ai-common` **140 → 146
  passed**.
- Both timeouts mutation-verified by wall clock, not only by assertion: 61s and
  30.21s against ~1s.
- Guard tests mutation-verified: five injected violations, each `1 failed, 4
  passed`.
- `docling-slim`, `google-genai`, `pandas`, `setuptools`, `typer` and
  `huggingface-hub` waivers confirmed against **source diffs between versions**,
  not against report comparison — after the report comparison was shown unsound.
- Every waived finding re-checked as still *reported* and no longer *blocking*;
  none vanished from the output.
- GuardDog 3.2.0's rule files diffed against 3.1.0 rather than assumed unchanged.

## Mistakes made this session

All the assistant's unless stated.

- **The `ai-common` pin was reported as `4a433aa` when `pyproject.toml` reads
  `@main`.** The SHA came from a *candidate* export in `tmp/`, not from the
  project's declaration. Bertan was asked to choose a pin style on the strength
  of that wrong statement; the question was reissued with the correction.
- **A timeout was claimed to trigger the retry-once path at `:574`.** That retry
  only fires when `_pypi_release_key` finds a different canonical spelling, which
  for `docling==2.120.1` it would not. Corrected before it reached a design
  decision.
- **The upgrade was reported as adopted by the assistant's `upgrade-safe` run.**
  Bertan had already run it in a separate terminal; the lock was byte-identical
  before and after, which is what exposed it. The assistant's run re-verified a
  state it did not create — and the unexplained `pygments==2.21.0` report
  noticed earlier had the same cause, dismissed at the time as unrelated.
- **Correcting a six-day-old devlog was proposed.** Bertan established that
  devlogs are append-only and never corrected backwards; only `todo.md` and the
  latest log carry meaning forward. The rule is not written in the dev-log
  README, so it could not have been discovered by reading the repository — it is
  now in the assistant's memory.
- **The consequence of the patched scanner was overstated** as mattering "the
  moment anyone moves to 3.2.0". Bertan's question established it does not: on a
  version bump every cache key changes, so the patched-versus-stock ambiguity
  never arises there. It was also filed too high as a cache-integrity defect when
  the patch is inert under the interpreter pin.
- **The first cross-version comparison was too coarse** — rule and file, without
  matched text — and reported `huggingface-hub==1.24.0` as identical to a version
  already decided. That is the rubber-stamping failure the review skill names,
  and it was caught only by tightening the comparison rather than by review.
- **"Identical findings" was offered as grounds for quick confirmation** before
  the `max_hits` corollary was understood, which would have made four
  confirmations rest on evidence that can be silently truncated. Withdrawn in the
  same exchange.

## State handed to the next session

| | |
|---|---|
| `clause-and-effect` | `main` at `3dc7a33` (PR #4 merged), `dev-04` created and checked out, tree clean |
| `ai-common` | `main` at `a0f06ea`, clean, only branch; PRs #28 and #29 merged |
| Gate | **both tiers green**, `make verify` exit 0; tier 2 `BLOCKED 0 / INCOMPLETE 0` |
| GuardDog | 3.1.0, pinned to `/usr/bin/python3.12`, **locally patched** (`sandbox.py`); 3.2.0 available |
| Waivers | **21**; report store 264; 60 reports awaiting review, all advisory-only |
| Suites | **249 passed / 5 xfailed**, **146 passed** |
| Unmerged branch | `origin/dependabot/uv/uv-ffa9bba872`, one commit, **no open PR**, bumps the uv group against a deliberate pin — left untouched |

## Open items — start here next session

| # | open item | state |
|---|---|---|
| 1 | **The gate's detection side has never been verified** — every figure is a false-positive rate | oldest open item; now the largest gap |
| 2 | Three GuardDog defects unreported upstream — confirmed still present in 3.2.0; #3 has a working local patch, so it is a PR not an issue | unreported |
| 3 | A GuardDog upgrade carries waivers onto rules that may have changed | recorded today, unfixed |
| 4 | `guarddog-review` cannot surface "identical to a version already decided", and does not warn on exhausted `max_hits` | both found today |
| 5 | Whether to move to GuardDog 3.2.0 — costs a multi-hour full re-scan and resets the ledger; waivers survive | undecided |
| 6 | Report store versioning — `cache.json` is the file the gate reads | undecided |
| 7 | Platform-restricted export (`pywin32`) | undecided |
| 8 | Does the toolchain belong inside the gate — GuardDog itself is unexamined, and is locally patched | deferred |
| 9 | Dropped requirement lines under-report the denominator (183 vs 182) | **known and accepted** by Bertan; the drop is silent, which is the part worth revisiting |
| 10 | `todo.md:1173` phase-7 remnants; the toolchain-pinning design note | unwritten |

**Closed today**, from yesterday's list: the eight tier-2 blockers (#1), the
three tier-1 advisories (#2), `make verify` unusable (#3), and `upgrade-safe`
reverting the lock but not the environment (#4) — the last of which closed on
its own stated condition, a complete `upgrade-safe` finishing with the
environment unchanged afterwards.
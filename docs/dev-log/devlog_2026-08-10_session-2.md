# 2026-08-10 · session 2

**Repository worked in:** `ai-common` (`/home/bgunyel/source/ai/ai-common`) — not
this one. `clause-and-effect` was untouched: still `dev-03`, 5 ahead of `main`,
clean tree.
**Branch created:** `lazy-package-init`, pushed to `origin`
**Commits:** `6b72ed8`, `dd8309a`, `e731a7c`
**State at close:** 92 passed; guarddog upgraded 2.10.0 → 3.1.0 on this machine;
the tier-2 sweep **not started, and currently blocked**

**Theme:** the session opened on the `ai_common` import-cost fix — the item
Bertan had pinned as first — and finished it in an hour. The remaining seven
hours went to the GuardDog wrapper that happened to be sitting uncommitted in
the same repo, because verifying it kept turning up things that were wrong. The
last of those was found one minute after the guarddog upgrade, by a smoke test
that existed only because an earlier finding had made it obviously necessary.

---

## The `ai_common` fix: done, and it cost less than the analysis did

`src/ai_common/__init__.py` now resolves all 24 exported names through a PEP 562
`__getattr__` backed by a name→submodule map, with a `TYPE_CHECKING` block so the
API surface stays visible to type checkers, IDEs and `grep`, and a `__dir__` so
the visible surface does not depend on import history.

| statement | before | after |
|---|---|---|
| `import ai_common` | 4.42s · 3124 modules | **0.01s · 51** |
| `from ai_common.enums import LlmServers, ModelNames` | 4.11s · 3124 | **0.14s · 194** |
| `from ai_common import calculate_token_cost` | 4.38s · 3124 | **0.15s · 195** |
| `from ai_common import CfgBase` | 4.27s · 3124 | **0.36s · 518** |
| `from ai_common import get_llm` | 4.46s · 3124 | 4.19s · 3111 *(unchanged — correct)* |

Row 2 is `src/llm_config.py`'s exact statement: **29×**. The absolute numbers are
lower than the 7.6–8.1s recorded in `todo.md` because those were measured in
this repo's venv, which has torch; ai-common's own venv does not. The *shape* is
identical and that is what the finding was about — every entry point cost the
same 3124 modules.

The implemented shape differs from the one `todo.md` suggested. That entry
proposed keeping `enums` **eager** for IDE ergonomics. Not needed: the
`TYPE_CHECKING` block gives static tools the full surface at zero runtime cost,
so nothing had to stay eager and `import ai_common` fell to 0.01s rather than to
the enums floor of 0.13s.

**The existing test was already failing on `main`** — `test_public_api`'s
allowance for three leaked submodule attributes had gone stale and five more had
appeared (`price`, `web_search`, `enums`, `llm`, `engine`). Laziness removes the
leak entirely, so the allowance was dropped rather than widened. 1 test → 32.

## The uncommitted work in the same repo

`ai-common` had a four-week-old WIP in the tree: `scripts/guarddog_cached.py`
staged as deleted, an untracked `src/ai_common/security/` containing a rewritten
copy, and the `Makefile`/`pyproject.toml` edits wiring it as a `guarddog-cached`
console script. Bertan's instruction was that it should stay on this branch
rather than remain forgotten WIP, and that the point of the move is that
**guarddog processing lives in ai-common so it is not copied into every project
repo** — `clause-and-effect/scripts/guarddog_cached.py` is exactly that copy,
still present here and still on the old design.

Verified it worked — console script, wheel packaging, entry point, migration —
and then the two pieces turned out to reinforce each other:

| | cost | modules |
|---|---|---|
| `import ai_common.security.guarddog_cached`, eager `__init__` | 4.17s | 3126 |
| …with the lazy `__init__` | **0.03s** | **89** |

A requirements-file walker had been loading the entire langchain stack on every
`make scan`. 139×.

## The shared cache was right; what got written into it was not

Bertan's design intent — a system-wide cache so every project benefits from
scans other projects already did — is sound and was not in question. Two
separate things were.

**Concurrent projects erased each other.** `save_cache` rewrote the whole dict
from a copy loaded at startup. Two projects scanning at once, six entries
expected: **three survived.** Fixed by re-reading and merging under an exclusive
`flock` on a sidecar lock file — sidecar, not the cache itself, because the file
is replaced by rename and a lock on its inode would not be seen by the next
writer.

**A GuardDog upgrade wiped everyone's cache.** The docstring claimed entries were
"keyed on (name, version, guarddog_version)"; the code keyed them
`name==version` and stored one `guarddog_version` at file level, invalidating
wholesale on mismatch. Demonstrated: project A's three entries vanished when
project B ran with a newer guarddog. Fixed by putting the version in the key.

Both were amplified rather than caused by the cache being shared — under the old
per-project cache the blast radius was one project.

## The exit-code trap

`upgrade-safe` gates on exit codes. Measured what guarddog's exit code actually
means:

| situation | exit |
|---|---|
| clean scan | 0 |
| 3 malicious indicators found | 0 |
| package never downloaded, 0 rules ran | 0 |
| `--rules no-such-rule` / bad command / missing arg | 2 |

**Nonzero means only that GuardDog was called wrong.** Both `pypi scan` and
`pypi verify` behave this way, so the tier-2 gate had never been a gate — the
`✗ Candidate fails GuardDog static analysis` branch could not fire.

And the cache had already recorded one consequence. Of the 91 real entries,
`regex==2026.6.28` was filed as `exit_code: 0` with
`potentially_compromised_email_domain: failed to run rule: Invalid version:
'2013-02-16'` in its output — a partial scan stored as a clean verdict.

**A correction made during the discussion:** the assistant first called this
"silent". It is not. Cached entries reprint their stored output, so the failure
text appears on every run. What is missing is that it never reaches the
*verdict*. Overstating it would have misdirected the fix.

### What replaced it

`--output-format=json` gives `issues`, `errors` (rules that did not run) and
`results` (per-rule matches). The wrapper now derives its own verdict:

| verdict | condition | gate |
|---|---|---|
| `INCOMPLETE` | `errors` non-empty | **fails** |
| `BLOCKED` | a blocking rule matched, unwaived | **fails** |
| `advisory` | only non-blocking rules matched | passes, reported |
| `clean` | nothing matched | passes |

Gating on findings alone was measured as unusable first: **26 of the 91 real
dependencies trip at least one heuristic** (api-obfuscation 12, dll-hijacking 5,
shady-links 4, obfuscation 2, code-execution 1, unicode 1). Bertan chose
completeness + a high-signal rule set, and chose the waiver store to be
machine-wide (`accepted.json` beside the cache) over the per-project file the
assistant recommended; `reason`/`by`/`at` are recorded so the decision stays
auditable despite never passing through code review.

The verdict is computed **on read**, so changing the blocking set or accepting a
finding re-decides every cached package without re-scanning. **Only complete
scans are cached** — a scan that reported `errors` is retried rather than frozen
into a machine-wide clean bill.

## Ctrl-C left `uv.lock` upgraded and unverified

Asked whether a 10-minute run could be stopped and its findings reused. Tested
both layers rather than reasoned about it.

**The scans survive.** Interrupted after ~3.5s of a 10-package run: 3 entries
persisted, exit 130, and the re-run reported `3 cached, 7 scanned`. Ctrl-C is a
legitimate way to work through a long sweep.

**The lockfile did not.** `make` abandons the remaining recipe lines on SIGINT,
so the shell never reached its restore branch:

```
make: *** [upgrade-safe] Interrupt
uv.lock now contains : 'UPGRADED LOCK (unverified)'
uv.lock.preupgrade   : LEFT BEHIND -> 'ORIGINAL LOCK'
```

Worse, the next `make upgrade-safe` starts with `cp uv.lock uv.lock.preupgrade`,
overwriting the real original with the already-upgraded lock — the pre-upgrade
state is gone after one more run.

Fixed structurally: the guarded section is one shell with `trap … EXIT` plus
`INT`/`TERM`, `SHELL := /bin/bash` pinned. Verified across interrupt, both
failing tiers, success, and (later) budget-exhausted. `uv.lock` is never
partial in any case — the candidate lock is written whole by `uv lock --upgrade`
before scanning starts, so the file is only ever the original or the full
candidate.

`GUARDDOG_BUDGET` was added on the same reasoning: scanning stops *starting* new
packages once the budget is spent and exits 75, which reverts the lock exactly
as an interrupt does. Repeated budgeted runs converge on a full sweep; only a run
that finishes inside its budget can adopt an upgrade.

---

## 🔺 The three findings from the guarddog 3.1.0 smoke test

Bertan asked for the upgrade step by step. Step 1 upgraded cleanly (2.10.0 →
3.1.0, still a user-level `uv tool` install, `--version` still emits a bare
`3.1.0` so cache keys stayed clean). **Step 2 — one scan, one minute — produced
three blockers, and the sweep was not started.**

### 1. The sandbox cannot start on this machine

```
$ guarddog pypi scan six --version 1.17.0
* download-package: Sandboxed extraction failed: Fatal Python error:
  _Py_HashRandomization_Init: failed to get random numbers to initialize Python
No risks found in six
exit=0
```

v3.0.0 made the nono-py kernel sandbox mandatory. It cannot obtain entropy to
start its inner Python here, so **no package can be scanned at all** — and
guarddog reports *"No risks found"* and exits 0.

Had the hour-long sweep been launched on the old wrapper, it would have written
~91 fake clean verdicts, printed `✓ Clean across both tiers`, and adopted the
upgrade. The new wrapper turns it into INCOMPLETE → exit 1 → `uv.lock` reverted.
`--no-sandbox` works. **The decision is Bertan's:** investigate the entropy
failure, accept `--no-sandbox`, or roll back to 2.10.0.

### 2. v3 renamed every rule, so `BLOCKING_RULES` matches nothing

The catalogue went from 25 rules to **61**, on a new `capability-*` / `threat-*`
taxonomy. Not one of the seven names in `BLOCKING_RULES` exists in v3:

| in the committed blocking set (v2) | v3 equivalent |
|---|---|
| `code-execution` | `threat-setup-network-in-install`, `threat-npm-preinstall-script` |
| `exec-base64` | `threat-runtime-obfuscation-base64exec` |
| `download-executable` | `threat-process-download-exec` |
| `silent-process-execution` | `threat-process-spawn-silent` |
| `exfiltrate-sensitive-data` | `threat-network-exfiltration` |
| `steganography` | `threat-runtime-obfuscation-steganography` |
| `cmd-overwrite` | *(no direct equivalent found)* |

**The gate would have been inert again — silently, by a different route than the
exit code.** The noise profile changed too: `tqdm` scores **7.2/10 `high_risk`**
under v3 where v2 called it three advisory indicators.

v3 also added a much better basis for a gate than hand-curated rule names:

```json
"risk_score": {"score": 7.2, "label": "high_risk", "findings_count": 4,
               "score_breakdown": {…}},
"risks": [{"name": "risk.network.outbound", "category": "network",
           "severity": "medium", "mitre_tactics": ["command-and-control"],
           "threat_rule": "threat-network-outbound-shady-links", …}]
```

A calibrated score with a label, per-risk severity and MITRE tactics — durable
in a way a rule-name list has just proved it is not.

### 3. The report-shape guard mis-diagnoses the sandbox failure

Added earlier the same session, to close the trap one level up: if a future
GuardDog renamed `errors`/`results`, `.get()` returning nothing would make every
package read as clean. The guard requires both keys to be present dicts.

But **v3 omits `results` entirely when a scan fails** — the failing report's keys
are just `['package', 'issues', 'errors']`. The guard therefore returns
*"unrecognised report shape"* and **discards guarddog's real error message**. The
verdict is still correct (INCOMPLETE, blocks), but the one line saying *the
sandbox is broken* is lost. `results` being absent is coherent when `errors` is
populated; the guard must only fire when `results` is missing **and** `errors`
is empty.

---

## Verification

Every claim in this log was measured or executed, not reasoned about. **38
mutants across eight rounds.** Three survived; each survival was worth more than
the rounds that passed:

- **`_write_atomically` → plain `write_text` survived.** Nothing pinned
  atomicity. Closed with an inode check (in-place write keeps the inode, rename
  changes it) and a failed-write test.
- **`migrate_legacy_cache` recounting entries survived.** Nothing pinned the
  `Migrated N entries` figure shown to the user.
- **`BLOCKING_RULES` emptied appeared to survive — but the mutant was broken**
  (`frozenset(set()) or frozenset({…})` evaluates back to the original).
  Rewriting it exposed a real gap: `test_every_blocking_rule_blocks`
  parametrizes over the constant under test, so emptying the set just runs fewer
  cases. Added `test_the_blocking_set_is_exactly_these_rules` with literal names.

That last one is the third instance this week of the same failure mode, after
`_ANY_DIGEST` on 2026-08-10 session 1 and the skew tests earlier today: **a test
that builds its expectation by calling the function under test cannot see that
function change.** Every key literal in the guarddog tests is now hard-coded for
this reason, with a comment saying so.

Each of the three commits was checked out and its suite run independently — 32,
92, 92 — so the history bisects cleanly.

## Mistakes made this session

All the assistant's unless stated.

- **Wrote two skew tests that could not detect the bug they were written for.**
  Both built expected keys via `gd.entry_key(...)`, so dropping the version from
  the key left them passing. Found by mutation, not review.
- **Shipped a report-shape guard that swallows the error it was meant to
  surface.** Found by the smoke test, three hours after writing it. Still
  uncommitted-as-fixed — see below.
- **Called the cached-failure problem "silent" when it is printed on every
  run.** Corrected mid-discussion; the real defect is narrower (the verdict
  ignores it) and the fix followed the corrected description.
- **Recommended never-caching incomplete scans without noticing it would
  re-scan a permanently-broken rule forever.** Bertan's question about reusing a
  partial run prompted the rethink.
- **A test called `monkeypatch.undo()`**, which reverts the whole fixture's
  patches including `XDG_CACHE_HOME`, so an assertion silently read the real
  user cache. Caught because the test failed, not because it was reviewed.
- **Wrote a broken mutant** and briefly reported a coverage gap that was not
  there.

## State handed to the next session

| | |
|---|---|
| `clause-and-effect` | `dev-03`, 5 ahead of `main`, clean — **untouched this session** |
| `ai-common` | `lazy-package-init`, 3 commits, pushed, clean, 92 passed |
| guarddog on this machine | **3.1.0** (was 2.10.0) — `uv tool`, user-level |
| Shared scan cache | still the 91 schema-1 entries; will be discarded on first run under the new code, which costs nothing since every key moved to `@3.1.0` |
| `accepted.json` | does not exist yet |
| Tier-2 sweep | **not started — blocked on the three findings above** |

**Open, in order.**

1. **🔺 The three smoke-test blockers.** #3 and #2 are the assistant's to fix
   (surface guarddog's real error; re-base the gate on `risk_score`/`risks`
   rather than rule names). **#1 is Bertan's decision** and gates the rest —
   investigate the entropy failure, run `--no-sandbox`, or roll back to 2.10.0.
   As committed, the branch's gate is calibrated for guarddog 2.x while 3.1.0 is
   what is installed.
2. **Merge `lazy-package-init` and re-point this repo's pin.** `pyproject.toml`
   has `ai-common @ git+…@main`, a non-editable git install, so **none of the
   import-cost win reaches `clause-and-effect` until the branch merges** and the
   pin is re-resolved. Also unblocks deleting
   `clause-and-effect/scripts/guarddog_cached.py`, the duplicate this work
   exists to remove.
3. **The remaining two `ai_common` optimisations**, now unblocked by finding 1:
   six provider SDKs inside `get_llm` (≈3.7s, and it makes five of them optional
   rather than hard dependencies) and `BaseChatModel` behind `TYPE_CHECKING`
   (≈4.3s). Re-measure first — the numbers in `todo.md` predate the lazy
   `__init__`.
4. **A high-severity Dependabot alert on `ai-common`'s `main`**, surfaced by the
   push: <https://github.com/bgunyel/ai-common/security/dependabot/33>.
   Independent of this work, and exactly what tier 1 (`make audit`) is for.
5. Then back to the sequence this repo was already on: **the re-index** against
   `5caac594…`, **gold chunk IDs (P0)**, **the sufficiency judge from stage C**.
   None moved this session.
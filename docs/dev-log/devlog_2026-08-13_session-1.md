# 2026-08-13 · session 1

**Repositories worked in:** `ai-common` — PR #24 merged, `main` now `a2a7a21`,
branch deleted; `clause-and-effect` (`dev-03`) — three commits,
`f10e3bf..700a2c5`, **13 ahead of `main`**.
**State at close:** tier 1 on the committed lock **5 advisories → 3**, none
reachable on this platform. Tier 2 not established here: one sweep was aborted
as unproductive and the `upgrade-safe` that replaced it was stopped before it
finished.

**Theme:** the session opened on *"run `make audit`"*, the first item the
previous session left, and the answer was that tier 1 had been failing on the
committed lock for days while tier 2 passing was the visible half. Most of what
followed was establishing which of the two repositories a given fact belongs
to — a question that turned out to have a different answer for locks, for
dependencies, and for waivers.

---

## Tier 1 had been red on the committed lock, unnoticed

`make audit`: **5 advisories across 4 packages**, all with fixes available.
`make verify` is `audit` + `scan`, and every recorded result to date had been
the tier-2 half. The oldest advisory here was published 2026-06-16 and the
newest 2026-08-10, so nothing arrived overnight; the lock had simply not been
audited since it was written on 2026-08-07 (`c6d9578`).

## The `upgrade-safe` that succeeded was in the other repository

Bertan recalled running `upgrade-safe` successfully on 2026-08-12 afternoon and
the recollection was exact — it ran in **`ai-common`**, whose `uv.lock` was
modified at 16:00 that day and left **uncommitted**. `clause-and-effect`'s lock
was untouched since 08-07. The assistant had begun constructing a
new-advisories-published-overnight explanation from the publication dates before
Bertan supplied the missing fact, which settled it in one step.

That uncommitted lock was the gated artifact: 25 packages, tier 1 clean, and —
because the recipe's `EXIT` trap removes `uv.lock.preupgrade` only after both
tiers pass — its survival is itself the evidence that tier 2 passed.

## `ai-common` merged, and Dependabot alert #33 identified

PR **#24** (9 commits) merged at 07:08:34Z as `a2a7a21`. Dependabot PR #23
auto-closed two seconds later. The gated lock was committed onto the branch
first (`7855596`) after Bertan chose to keep it with the waivers it was gated
against rather than split it out.

**Alert #33, carried as "still unidentified" since 2026-08-12, is the
`cryptography` PKCS#7 Bleichenbacher oracle** (`GHSA-g6cj-pr64-35w5`, 8.2).
GitHub named it in the push output. `main` now carries 50.0.0 and scans clean at
75 packages. The alert still read `open` with `fixed_at: null` afterwards;
checked against the lock on `main` directly rather than trusting the
bookkeeping. `lazy-package-init` deleted locally and remotely, guarded on
`git branch -d` and 0 unmerged commits.

## A consumed lockfile has no authority, and this was measured

Re-pointing the pin `343715b9 → a2a7a21` changed **zero package versions**. One
line moved in `uv.lock`. This is the whole answer to a question Bertan raised
directly: dependencies arriving through `ai-common` are **not** bound to
`ai-common`'s pins. `uv` reads its `pyproject.toml` ranges and re-resolves them
against ours.

| package | `ai-common` | here |
|---|---|---|
| cryptography | 50.0.0 | 49.0.0 |
| pydantic | 2.12.5 | **2.13.4** |

The `pydantic` row is the load-bearing one: this project resolves *ahead*, so
the intuitive model where one repository trails the other is wrong. Fixing a
vulnerability in `ai-common` does not fix it here.

The companion question — whether `ai-common`'s dependencies are scanned when
this repo is scanned — is **yes, completely**; all 11 it declares appear in the
flattened export. Both findings are now in
[`docs/design/dependency-scanning-scope.md`](../design/dependency-scanning-scope.md).

## `make test` had been running nothing since `57c37a5`

`TEST_DIRECTORY ?= src/tests/`, a directory that does not exist; `pyproject.toml`
already said `testpaths = ["tests"]`. The recipe exited 4 having collected 0
items. **243 tests were never reached by it.** Found while verifying the pin
re-point, not by the test suite, which is the point: a test target that runs
nothing fails in the direction that looks like success.

## The gate reports a denominator it has already filtered

The flattened export holds **182** requirement lines; the sweep announces
**181**. `parse_requirements` (`guarddog_cached.py:412-421`) has no `else`
branch, so a line `REQ_RE` cannot match is discarded with no record, and the
driver prints the count of survivors. Reproduced on a two-line file: one git
dependency plus one package announced `1 packages to evaluate`.

The dropped categories are git, URL and local-path dependencies — the non-PyPI
sources, which are the ones least covered by everything else. Today the only
such line is our own `ai-common`.

**Bertan ruled the first-party gap known and not worth fixing**, and it is
recorded as accepted in the design document rather than scheduled. Worth
separating: first-party source is scanned by *neither* repository, since
`uv export` omits the root project. That is defensible — GuardDog infers intent
in code obtained from an index, while our own code has review and CodeQL — but
the silence is not, and a third-party git dependency would vanish identically.

## `pypdf` removed; `langchain` removed for hygiene only

`pypdf`'s sole reference in the entire repository was its own declaration. Its
reverse dependencies were `ROOT ONLY`, so it left the graph entirely and took
two advisories with it — the only two of the five with a code path this project
exercises.

`langchain` is imported nowhere; only `langchain_core` is, by
`src/eval/sufficiency/llm.py:14-15`. Removing it **did not clear its advisory**,
because `ai-common` declares `langchain>=1.0.0` and the package stays
transitively. The assistant raised that `langchain-core` should be declared
rather than inherited, on the precedent of the `docling-core` comment two lines
above it in the same file; **Bertan chose to inherit it**, and the departure is
recorded in the commit message rather than silently absorbed.

## The two langchain versions are a stale fork, not a platform requirement

`uv.lock` carried `langchain` twice — 1.3.2 under
`python_full_version >= '3.14' and sys_platform == 'darwin'`, 1.3.14 everywhere
else — along with `langgraph`, `langgraph-sdk` and `websockets`, all four on the
identical marker and forming one dependency chain.

The assistant first proposed that `websockets` 15.0.1 lacking a cp314 wheel
cascaded upward, and **refuted it by test**: `langgraph-sdk==0.4.2` resolves
with `websockets==15.0.1` on macOS/py3.14 without complaint.

What it actually is, established by experiment:

- A throwaway project with this repo's exact dependency list resolves **fresh
  with no fork at all**, at `langchain 1.3.15`.
- A scratch copy of our lock keeps the fork through a plain `uv lock`, and
  collapses **all four** forks under `uv lock --upgrade-package langchain`.
- Tier 1 on that collapsed scratch lock: **3 advisories → 2**.

So `uv lock` is minimal-change: it preserves pins that remain valid without
re-optimising. The fork was presumably necessary when created and every lock
since has carried it. `langchain 1.3.2` exists only to serve it — which is why
that advisory is not installed here at all; this machine runs 1.3.14.

## The sweep was aborted, and the abort was correct

A full `make scan` ran 66 minutes and reached **64/181** before Bertan asked
whether scanning was meaningful at all when an upgrade was the obvious next
step. It was not. Three reasons, and the third is decisive:

1. It was scanning the pre-removal lock, `pypdf` still in its set.
2. The committed lock is not one we intend to keep — tier 1 red with fixes
   available for all three.
3. **Waivers are keyed `(name, version)`.** Every blocker it found was at a
   version the upgrade then moved.

Confirmed against the candidate lock that Bertan's `upgrade-safe` resolved:

| package | scanned | candidate |
|---|---|---|
| docling-slim | 2.114.0 | 2.119.0 |
| google-genai | 2.13.0 | 2.18.0 |
| huggingface-hub | 1.24.0 | 1.27.0 |

Two hours of adjudication would have produced waivers void on arrival.

What the partial sweep did establish, at now-superseded versions: **3 BLOCKED** —
`docling-slim` (Tectonic fetching and executing a binary; plus a
steganography hit worth checking against the `$js_eval` defect),
`google-genai` (the known rule defect, same file and line 217 as 2.11.0),
`huggingface-hub` 9.4/10 (`threat-filesystem-autostart` ×3 on the shell-completion
installer) — and **2 INCOMPLETE**.

## `cuda-toolkit` is unscannable, and nothing in the design covers that

```
download-package: Version 13.0.3.0 for package cuda-toolkit doesn't exist.
```

GuardDog cannot fetch it, so nothing is checked, and INCOMPLETE never passes.
The upgrade **did not move it** — it is 13.0.3.0 in the candidate too — so it
will fail every `upgrade-safe` identically. It is not a finding to adjudicate,
and `accepted.json` waives GuardDog *rules*; there is no entry shape for "this
package cannot be scanned". This blocks the `upgrade-safe → waiver-review →
upgrade-safe` loop from closing and needs a decision before that loop can run.

The second INCOMPLETE, `faker==40.32.0`, was a dropped connection during
`repository_integrity_mismatch` — transient, and only completed scans are
cached, so a re-run clears it.

## The interpreter is 12 patch releases stale and neither tier looks at it

Raised by Bertan. Python is **3.13.3** against a 3.13.15 series head. Nothing
pins it: no `.python-version` in either repository or the home directory, and
`requires-python = ">=3.13"` permits the upgrade freely. `uv sync` reuses an
existing venv rather than re-selecting an interpreter, so the venv has carried
whatever 3.13 `uv` had installed the day it was made. Inertia, not a decision.

Queried against OSV: **41 advisories match CPython 3.13.3, of which 30 are fixed
between 3.13.4 and 3.13.14** and would all be closed by 3.13.15. Several sit on
this project's paths — a ZIP64 EOCD offset check (`.docx`/`.xlsx` are ZIP
archives), a stack overflow on deeply nested XML DTDs (Office formats are XML),
a `tarfile.data_filter` traversal bypass, and use-after-free in the
`lzma`/`bz2`/`gzip` decompressors.

**Neither tier can see any of this.** `osv-scanner` reads `uv.lock`; GuardDog
scans PyPI packages. The interpreter is examined by nobody, so the gate would
block a merge over a 4.8 `pypdf` DoS while 30 interpreter advisories sit
underneath it unreported.

---

## Verification

- `243 passed, 5 xfailed` after each change; the 5 are the documented chunker
  xfails awaiting the hierarchy-aware rework.
- `ai-common` **127 passed**, branch up to date with `main` and merging cleanly,
  CodeQL and `Analyze (python)` both green before merge.
- `uv lock --check` passes; `uv export --frozen` verified to leave `uv.lock`
  byte-identical, which is the property `--frozen` was adopted for.
- Tier 1 measured at every step: **5 → 3** after removing `pypdf`; **3 → 2** on
  a scratch lock with the langchain fork collapsed.
- `ai-common`'s `main` scanned directly rather than trusting Dependabot: **75
  packages, no issues found**.

## Mistakes made this session

All the assistant's unless stated.

- **A sweep was started that should not have been.** The assistant proposed and
  ran a full `make scan` against a lock already known to be failing tier 1 and
  already scheduled for replacement. **Bertan stopped it** with the right
  question — why scan when an upgrade is next — 66 minutes in. The
  `(name, version)` waiver keying that makes it wasted work was a fact the
  assistant had cited earlier in the same session.
- **Two sweeps ran concurrently in one repository**, the hazard `ai-common`'s
  Makefile comment names explicitly. Stopping the assistant's sweep fired its
  `EXIT` trap and deleted `tmp/flat-requirements.txt` out from under Bertan's
  running `upgrade-safe`. No damage — the wrapper reads that file once at
  startup — but the collision was avoidable.
- **A cause was proposed before it was tested.** The fork was attributed to a
  missing cp314 wheel cascading up the chain. Refuted by the assistant's own
  next command, but it was stated first and tested second.
- **A commit landed without its main file.** `git add` of an already-staged
  deletion aborted the whole invocation, so the first commit contained only the
  file removal and not the Makefile the message describes. Caught before push
  and amended.
- **A blocker count was printed from a grep that matched headings**, giving
  "13 blockers" where the real figure was 3. Corrected in the following message,
  but it was offered as a progress figure.
- `uv.lock` was briefly left unparseable by a stray editor edit at line 1059,
  `langchain` replaced by a line break. Found by the assistant when a parse
  failed, undone in the editor; TOML validity and hunk count verified afterwards
  and nothing was lost.

## State handed to the next session

| | |
|---|---|
| `clause-and-effect` | `dev-03` at `700a2c5`, pushed, 13 ahead of `main` |
| `ai-common` | `main` at `a2a7a21`, clean, only branch |
| Tier 1 here | **3 advisories**, none reachable on this platform |
| Tier 2 here | **not established** — sweep aborted, `upgrade-safe` stopped |
| Waivers | 4, machine-wide, none covering the candidate versions |

**Open, in order.**

1. **🔺 Run the `upgrade-safe → waiver-review → upgrade-safe` loop to
   completion.** Bertan's workflow, and nothing in the Makefile needs changing
   for it. Expect `docling-slim==2.119.0`, `google-genai==2.18.0` and
   `huggingface-hub==1.27.0` to block; the google-genai one is a third
   adjudication of a defect already waived at 2.11.0 and 2.17.0.
2. **🔺 Decide what happens to `cuda-toolkit==13.0.3.0`.** Unscannable, not
   waivable, unmoved by the upgrade. It blocks the loop above from ever closing,
   so it is a prerequisite rather than a parallel item.
3. **Upgrade Python 3.13.3 → 3.13.15** and add a `.python-version` so the
   interpreter is a recorded choice. No lock change needed. Do not disturb
   GuardDog's interpreter — the 2026-08-11 lesson is that Landlock denies
   `/dev/urandom` to standalone builds, which is what `uv`-managed CPython is.
   Then consider whether the interpreter belongs inside the gate at all.
4. **Collapse the stale langchain fork** with `uv lock --upgrade-package
   langchain`, which clears an advisory on its own. Subsumed by item 1 if the
   full upgrade lands.
5. **Report the unguarded `$js_eval` GuardDog rule upstream**, plus the
   `/dev/urandom` sandbox denial. Carried from 2026-08-12; `docling-slim` may be
   a third independent confirmation.
6. **Count and name dropped requirement lines in `ai-common`** so the announced
   denominator is the real one. Non-blocking; the fix is small and it is a
   prerequisite for ever blocking on unscannable dependencies.
7. **Verify the gate's detection side** with a local fixture package. Unchanged
   since 2026-08-11 and now the oldest open item.
8. **13 advisory reports await review.** Unchanged from 2026-08-12.
9. Then the sequence this repo was already on: **the re-index** against
   `5caac594…`, **gold chunk IDs (P0)**, **the sufficiency judge from stage C**.
   None have moved since 2026-08-10.
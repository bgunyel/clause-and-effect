# 2026-08-13 · session 2

**Repositories worked in:** `ai-common` — PR **#25** merged (2 commits),
`main` `a2a7a21 → a1fa197`, branch deleted; `clause-and-effect` (`dev-03`) —
one commit, `c86a77c..6016e69`, **15 ahead of `main`**.
**State at close:** tier 2 **reached a verdict on every package for the first
time** — 178 packages, INCOMPLETE 0, 8 blockers. Four of the eight are
adjudicated and waived. The candidate lock is **not adopted**; `upgrade-safe`
reverted on the remaining four.

**Theme:** the item carried as *"`cuda-toolkit` is unscannable and there is no
entry shape for it"* was neither unscannable nor in need of a new entry shape —
uv and PyPI simply spell one release differently. Fixing that let a sweep run to
completion for the first time, and what it found made the previous session's
assessment of the blockers look inverted. A second, larger staleness turned up
underneath: the resolver that writes the artifact both gate tiers read is
sixteen months old.

---

## `cuda-toolkit` was never unscannable — two tools spell one release differently

`uv` takes a package version from the wheel **filename**; PyPI keys its release
index on the **PEP 440 canonical form**. NVIDIA ships
`cuda_toolkit-13.0.3.0-py2.py3-none-any.whl` under a release PyPI calls
`13.0.3`, so a lock line reading `13.0.3.0` asked GuardDog for a version that,
to the JSON API, does not exist.

Established against PyPI directly rather than reasoned: `GET
/pypi/cuda-toolkit/13.0.3.0/json` returns **200** and reports
`info.version: "13.0.3"`, while the project-level `releases` dict has no
`13.0.3.0` key at all. PyPI normalises on one endpoint and not the other;
GuardDog reads the one without it.

A controlled pair settled it in isolation — same package, one character apart:

| version string | result | exit |
|---|---|---|
| `13.0.3.0` (what `uv.lock` writes) | INCOMPLETE — `download-package` | 1 |
| `13.0.3` (PyPI's release key) | **clean**, 0 findings | 0 |

It scans clean, so there was never anything to adjudicate. **This rewrites
backlog item 2**, which was carried as needing a new entry shape in
`accepted.json` for "package cannot be scanned". No new shape is needed, and it
is not a rule defect either — nothing fires.

Nor is it a one-off: **4 of `cuda-toolkit`'s 39 releases** carry the mismatch
(12.8.2, 12.9.2, 13.0.3, 13.1.2), so waiting for an upgrade past it was not a
remedy.

## The retry is a fallback, never the primary, and PEP 440 is why it is safe

`canonicalize_version` strips trailing zeros — measured: `2.114.0 → 2.114`,
`1.24.0 → 1.24`, both of which are real PyPI keys that would then miss. So
normalising in `parse_requirements` was ruled out; the canonical form is tried
only after the as-given lookup has already failed.

The safety argument is that **PyPI refuses two releases whose versions compare
equal under PEP 440**, so the canonical form resolves either to the same release
or to nothing. A genuine `2.114.0` failing for some other reason retries as
`2.114`, finds nothing, and keeps its original error. The retry is accepted only
when it completes, so "not checked" still never becomes a pass — the property
the wrapper exists to hold.

Bertan decided the identity question: **the lock's spelling stays the key**.
Cache key, report filename and waiver key all keep `13.0.3.0`, so the next
sweep's parse hits the cache and a reviewer waives the string visible in
`uv.lock`; the entry and the report provenance record `scanned_version` where
the two differ. The rejected alternative — keying on PyPI's `13.0.3` — would
have deduped across projects but reintroduced the lock-versus-tool mismatch that
caused the bug, and would have made the identity depend on a failure path, since
the resolution is only discovered after the first attempt fails.

`scan_package` was split: `_scan_once` runs one scan and returns the entry with
its raw report, and no longer stores it, because which version string a report
is filed under is now decided a level up. `packaging` was declared rather than
inherited — it was already in the graph via three transitive requirers, and
hand-rolling PEP 440 normalisation inside the gate is the guess this module
refuses to make elsewhere.

## The `pypdfium2` failure that opened the session was a mid-upload race

`make upgrade-safe` had died with `pypdfium2` 5.13.0 "only has wheels for
macosx_13_0_arm64, macosx_13_0_x86_64". All 22 files exist, and the upload
timestamps explain it: they land alphabetically between **10:57:40 and 10:58:15
UTC**, android first, then macOS, then manylinux. uv read the index mid-upload
and cached a release that genuinely had no Linux wheel *at that instant*. A
fresh resolve exported cleanly. Nothing needed pinning.

One detail went unexplained at the time and was accounted for later in the
session: uv listed only the macOS wheels and never mentioned the android ones
already uploaded, because **uv 0.6.17 predates android wheel-tag support**.

## `google-genai` 2.18.0 waived — the same rule defect for the third time

`ai-common`'s `upgrade-safe` blocked on exactly one package. Its committed lock
had `google-genai==2.17.0`, which is waived; the candidate moved it to
**2.18.0**, which was not.

The finding was re-verified rather than carried across, per the rule that a new
version is new code: same file, same matched text `eval(` inside
`types.Retrieval(`, line moved 217 → 234. The rule's Python pattern
`/[^.\w]eval\s*\(/` is word-guarded and scores zero; the unguarded `$js_eval`
fires, and because it is itself a member of `$js_*` the branch reduces to
"contains `eval(`" plus "mentions an image filename" — the latter matching
`google_homepage.png` at line 46. Both halves were checked in the installed
file, not inferred.

`make scan` cannot verify a waiver for a version outside the committed lock —
the 2026-08-11 limitation — so verification used a one-line requirements file:
finding still **reported** at `[high]`, `BLOCKED 0`, exit 0.

## The resolver underneath the gate is sixteen months stale

Raised by Bertan while reading the push output. **uv is 0.6.17; the current
release is 0.12.3.** The binary on disk is dated 2025-04-26 and lives at
`/home/bgunyel/.pyenv/versions/3.11.3/bin/uv`, pip-installed into a pyenv
environment.

The narrow consequence is that it blocks the interpreter upgrade outright: uv
compiles the python-build-standalone download metadata into its own binary, so
`uv python list --all-versions` stops at **3.13.3** and `uv python install
3.13.15` cannot succeed. CPython 3.13.15 does exist — python-build-standalone
release `20260807`.

The wider one is that **uv writes `uv.lock`, and `uv.lock` is what both gate
tiers read** — `osv-scanner` parses it, and the GuardDog sweep scans whatever
`uv export` flattens out of it. This is the blind spot already recorded for the
interpreter, one layer further down: the interpreter runs the code, the resolver
decides which code there is, and nothing examines either.

A plan was written to `docs/uv-upgrade-plan.md` (`6016e69`) rather than
executed. It is filed at `docs/` and not `docs/design/`, because that directory
is explicitly for mechanisms that exist. Two ordering constraints drove the
phasing, and neither is visible from reading the release notes in isolation:

- **uv 0.9.0 made Python 3.14 the default.** Both repositories declare
  `requires-python = ">=3.13"` with no `.python-version`, which is harmless only
  because `uv sync` reuses an existing venv rather than re-selecting. The plan
  rebuilds the venv, so the pin is written in **phase 1, before uv is upgraded
  at all**.
- **`required-version` is honoured by uv 0.6.17 too**, so writing
  `>=0.12,<0.13` makes the old binary refuse to run in these repositories and
  retires the `rm ~/.local/bin/uv` rollback. It is therefore written **last**.

The risk register leads on GuardDog rather than uv: the cache and ledger key on
`(name, version, guarddog_version)`, so a stray `uv tool upgrade` would turn
every stored report into a cache miss and re-open every completed review at
once.

Bertan settled three decisions: an exact `3.13.15` pin rather than the `3.13`
series, since a minor pin reintroduces the silent drift the item exists to
correct; the standalone installer into `~/.local/bin`, which measurement showed
already precedes every pyenv entry on `PATH` (position 3 against 5, 6, 7);
and `required-version` in `[tool.uv]`. Whether the toolchain belongs inside the
gate at all is deferred.

## The first tier 2 sweep to reach a verdict on every package

Run by Bertan. **178 packages — 104 cached, 74 scanned. clean 129, advisory 41,
BLOCKED 8, INCOMPLETE 0.**

**INCOMPLETE 0 is the result that matters.** Every previous sweep either ended
on `cuda-toolkit` or was stopped before reaching it, so "tier 2 clean" had never
been established for this project. The version-normalisation fix is what let the
gate reach a verdict at all.

It also scanned packages no sweep had ever reached — `transformers` and `torch`
among them, both past the 64/181 point where the 2026-08-13 session 1 sweep was
aborted.

## Six of the eight blockers are one rule, and it fires outside its own scope

Grouping the eight by rule before adjudicating any of them showed
`threat-process-download-exec` accounting for six. Reading the rule once
explained why: its **first condition branch is a flat list of single-string
triggers** — `$shell_curl_pipe`, `$py_pip_executable`, `$py_subprocess_ps`,
`$py_exec_compile` — each firing alone, with no requirement that anything be
downloaded or that the matched text ever execute. It carries
`specificity = "high"`, so any one of them blocks standalone.

Four were adjudicated and waived, each read against the code and approved
individually:

| package | trigger | what the code is |
|---|---|---|
| `docling-slim` 2.119.0 | `$shell_curl_pipe` | `curl … \| sh` inside a `_log.warning(...)` printed when Tectonic is absent — install instructions, never executed |
| `pandas` 3.0.5 | `$py_subprocess_ps` | `powershell.exe -command Get-Clipboard`, the WSL clipboard backend. **No download primitive exists anywhere in the file** |
| `setuptools` 84.0.0 | `$py_pip_executable` | `setup.py develop` running `[sys.executable, '-m', 'pip', 'install', '-e', '.']` — the local tree, via the form pip documents as correct |
| `pywin32` 312 | `$py_exec_compile` | Pythonwin executing `os.environ["PYTHONSTARTUP"]` — CPython's own local startup file |

`pywin32` is not installed on this machine (`marker = "sys_platform ==
'win32'"`), so its source was read from the PyPI artifact for that exact
version; the line numbers matched the stored report's excerpt, which is what
confirms the artifact is the one GuardDog scanned.

Two of the six are **real** and remain open: `torch`'s `format_flamegraph()`
downloads `flamegraph.pl`, `chmod 0o755`s it and executes it with no checksum,
and `huggingface-hub`'s `_cli_utils.py:1033` builds `["bash", "-c", "curl -LsSf
https://hf.co/cli/install.sh | bash -"]` and runs it via `subprocess.call(cmd)`.

`$py_pip_executable` alone fired in three of the six. That is one systematic
defect rather than three coincidences, and together with the five recorded
instances of the unguarded `$js_eval` it makes the upstream report substantially
stronger than it was.

## Session 1's assessment of `docling-slim` was inverted

Session 1 recorded docling-slim's finding as *"Tectonic fetching and executing a
binary"* and treated it as the substantive item in the set. **Docling does not
fetch Tectonic.** It resolves the binary through `shutil.which("tectonic")` or
an existing executable at a configured path, and if neither is present it logs a
warning containing the upstream project's install command. The
`subprocess.run(cmd)` at line 250 runs that resolved path.

The assistant repeated session 1's framing earlier in this session — calling it
"the one that needs real thought" and "genuine download-and-execute behaviour" —
before reading the file. Reading it refuted both statements.

The genuinely real findings, `torch` and `huggingface-hub`, are the two no
previous sweep had reached.

The `docling-slim` steganography hit is the clearest instance of the `$js_eval`
defect recorded so far: it matched `eval(` inside **`self.model.eval()`**,
PyTorch's evaluation-mode call, which the rule's own line-19 comment names as
something it means to exclude — *"not `ast.literal_eval()`/`img.eval()` method
calls"* — and which its guarded Python pattern correctly does exclude. The JS
branch defeats a documented exclusion in the same rule file.

## The report store was reclassified as an asset, and not all of it should be versioned

Raised by Bertan: the cached reports represent real compute and belong in
version control. Measurement supports the premise and splits the directory —
1.7M total, so size is not the constraint:

| file | character | git fit |
|---|---|---|
| `reports/` (227 files) | raw evidence, one immutable file per key | good |
| `accepted.json`, `reviewed.json` | the decisions themselves | good |
| `cache.json` (164K) | derived verdicts, rewritten in full on every save | poor |

The assistant's recommendation, not yet decided: version the first two and
exclude `cache.json`. It is a single blob that conflicts on every sweep, and
more importantly it is **the file the gate reads to decide** — committing it
means anything that can write the repo can insert a clean entry for a package
never scanned. No compute is lost by excluding it, because a cache entry is a
lossy trim of its report and the provenance block carries everything needed to
rebuild the key; ai-common's report importer (`3e77cdd`) is the natural home for
a rebuild mode. Left open: `~/.cache` is by definition the directory the system
may clear, which argues against durable assets living there at all.

---

## Verification

- `ai-common`: **139 passed** (127 before, 12 new). The refactor alone re-ran at
  127 *before* the new tests were added, which is what establishes it as
  behaviour-preserving rather than merely green.
- ruff held at the `main` baseline of **45** — measured by running it against a
  `git archive` of `main`, not assumed. Two new findings were introduced and
  fixed; the four in `guarddog_cached.py` are pre-existing.
- `clause-and-effect`: **243 passed, 5 xfailed** after the pin re-point; the 5
  are the documented chunker xfails.
- `cuda-toolkit==13.0.3.0` verified against **real PyPI**, not the test shim:
  scans clean, exit 0, substitution announced.
- Every waiver verified individually to be **reported but not blocking** —
  `BLOCKED 0`, exit 0, finding still present in the output. A finding that
  vanished would mean something is hiding findings rather than waiving them.
- Re-pointing the `ai-common` pin `a2a7a21 → a1fa197` moved **zero package
  versions**; the lock diff is 3 lines. This is the third measurement of the
  lockfile-independence property recorded in `dependency-scanning-scope.md`.
- `uv lock --check` consistent in both repositories.

## Mistakes made this session

All the assistant's unless stated.

- **Session 1's `docling-slim` characterisation was repeated without checking.**
  It was described as "genuinely downloads and executes a binary" and "the one
  that needs real thought", twice, before the file was read. It is a log
  message. The error was inherited, but restating it as fact added a second
  citation to something never verified.
- **The sweep's length was predicted wrong, twice.** It was called "short"
  because the known blockers were already cached, then "fast — it fails at the
  verdict stage". In fact ~50 packages moved to versions never scanned, and the
  run took hours. The correction was volunteered mid-run, but the estimate
  should not have been offered from the cached-blocker list alone.
- **Two blockers were predicted; eight came back.** The prediction extrapolated
  from the aborted session 1 sweep, which had only covered 64 of 181 packages —
  a sample that by construction could not support it.
- **`huggingface-hub` was called "probably a hint string" mid-analysis.** The
  `deprecated_cli.py` match is; the `_cli_utils.py` one builds a `curl … | bash`
  command and `subprocess.call`s it. Reading the call sites corrected it before
  any decision was taken, but the guess was stated first.
- A line-wrap in the plan document put "6." at the start of a line and the
  markdown linter read it as an ordered-list item. Caught by diagnostics,
  reworded.

## State handed to the next session

| | |
|---|---|
| `clause-and-effect` | `dev-03` at `6016e69`, pushed, **15 ahead of `main`** |
| working tree | `uv.lock` modified — the 3-line `ai-common` pin re-point, **uncommitted** |
| `ai-common` | `main` at `a1fa197`, clean, only branch |
| Candidate lock | **not adopted** — `upgrade-safe` reverted on the 4 remaining blockers |
| Tier 2 | first complete sweep: 178 packages, **INCOMPLETE 0**, 8 blockers, 4 waived |
| Waivers | **9** |
| Review ledger | 227 stored reports, 67 with findings, 58 awaiting review |

**Open, in order.**

1. **🔺 Finish the four remaining blockers, then re-run `upgrade-safe`.** Eight
   findings: `huggingface-hub==1.27.0` (download-exec **real**,
   filesystem-autostart), `torch==2.13.0` (download-exec **real**,
   filesystem-autostart, dynamic-loader), `transformers==5.8.1` (the `eval(`
   defect, and `threat-network-exfil-sysinfo`, a rule nobody here has read),
   `typer==0.26.8` (filesystem-autostart — the smallest, one finding). The two
   real ones need an "our exposure" paragraph of the kind the `pyyaml` note
   carries; the groundwork is done — no first-party `torch` import, no
   `_memory_viz` reference, and `installation_method()` returns `"pip"` for a
   uv-installed `huggingface-hub`, which takes the non-curl branch.
2. **🔺 Execute `docs/uv-upgrade-plan.md` from phase 0.** Three decisions
   settled, phasing fixed, rollback per phase. Nothing has been run.
3. **Decide whether the flattened export should be platform-restricted.**
   `pywin32` was adjudicated this session for a Windows-only package that is
   never installed here. The same question returns every sweep, and the flag
   matured in a later uv, so it interacts with item 2.
4. **Decide what of the report store gets versioned.** Recommendation above;
   `cache.json` excluded and made rebuildable is the substantive part.
5. **Report upstream.** Now three findings, not one: the unguarded `$js_eval`
   (five instances, one of which defeats the rule's own documented exclusion),
   `threat-process-download-exec`'s branch-1 triggers carrying
   `specificity = "high"` (four waivers this session), and the `/dev/urandom`
   sandbox denial carried since 2026-08-12.
6. **Count and name dropped requirement lines in `ai-common`.** Unchanged.
7. **Verify the gate's detection side** with a local fixture package. Unchanged
   since 2026-08-11 and still the oldest open item.
8. Then the sequence this repository was already on: **the re-index** against
   `5caac594…`, **gold chunk IDs (P0)**, **the sufficiency judge from stage C**.
   None have moved since 2026-08-10.
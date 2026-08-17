# What the dependency gate actually scans

The two-tier gate (`make verify` — OSV/GHSA, then GuardDog) exists to stop a
dependency carrying a known advisory or a malware indicator from entering the
lock unnoticed. This document states the **scope** of that scanning: which
artifacts are examined, which are not, and why. The failure it guards against
is the one a security gate is worst at announcing — a package that was never
examined being read as a package that came back clean.

## How the scanned set is derived

`make scan` flattens the committed lock and hands the result to the wrapper:

```make
uv export --frozen --no-hashes --all-groups -o tmp/flat-requirements.txt
uv run --frozen --no-sync guarddog-cached tmp/flat-requirements.txt
```

`guarddog-cached` reads that file once at startup and keeps only lines matching
`REQ_RE` (`ai_common/security/guarddog_cached.py:122`), which requires a
literal `name==version`. Each surviving pair is scanned or served from the
machine-wide cache.

Two properties follow from `uv export`, and both matter:

- **The set is the full transitive graph, not the direct dependencies.** A
  dependency's own dependencies are ordinary entries in our lock and are scanned
  exactly like anything else.
- **The root project is never a requirement line.** `uv export` emits what the
  project depends *on*, so first-party source is structurally absent from the
  scanned set — in this repository and in `ai-common` alike.

## Observed: transitive coverage is complete

`ai-common` is consumed here as a git dependency and declares 13 packages.
Checking the flattened export produced by the sweep of 2026-08-13, every one it
declares that resolves to PyPI is present and scanned:

```
✓ langchain-anthropic==1.5.0     ✓ ollama==0.6.2
✓ langchain-google-genai==4.3.1  ✓ openai==2.46.0
✓ langchain-groq==1.1.3          ✓ pillow==12.3.0
✓ langchain-ollama==1.1.0        ✓ tavily-python==0.7.26
✓ langchain-openai==1.4.0        ✓ tqdm==4.69.0
✓ langchain-openrouter==0.2.6
```

There is no "dependency of a dependency" blind spot. Consuming a package
through `ai-common` rather than declaring it here changes nothing about whether
it is scanned.

## Observed: a consumed lockfile has no authority

A lockfile governs only its own project. When `ai-common` is consumed as a
dependency, `uv` reads its `pyproject.toml` ranges and re-resolves them against
this project's constraints; `ai-common/uv.lock` is not consulted. Measured on
2026-08-13, with both repositories at the commits below:

| package | `ai-common` lock | `clause-and-effect` lock |
|---|---|---|
| cryptography | 50.0.0 | 49.0.0 |
| openai | 2.54.0 | 2.46.0 |
| google-genai | 2.17.0 | 2.13.0 |
| pydantic | 2.12.5 | **2.13.4** |

The `pydantic` row rules out the intuitive-but-wrong model that one repository
simply trails the other: here this project resolves *ahead*. The `cryptography`
row is why `make audit` passed in `ai-common` and failed here on the same day.

Confirming observation: re-pointing this project's pin from `343715b9` to
`a2a7a21` — a merge that moved 25 packages in `ai-common`'s own lock — changed
**zero** package versions here. Only the git SHA in `uv.lock` moved.

**Consequence: fixing a vulnerability in `ai-common` does not fix it here.**
Each repository must run its own `upgrade-safe`.

## Observed: the scanned set is silently smaller than the file

The export for this project holds 182 requirement lines. The sweep announces:

```
Requirements file: tmp/flat-requirements.txt
GuardDog v3.1.0 — 181 packages to evaluate
```

The missing line is `ai-common @ git+https://github.com/bgunyel/ai-common.git@…`,
which `REQ_RE` cannot match. `parse_requirements`
(`guarddog_cached.py:412-421`) has no `else` branch, so a non-matching line is
discarded without a record, and the driver (`:666`) prints the count of what
*survived* the filter. Nothing retains how many lines came in.

Reproduced directly on a two-requirement file — one git dependency, one pinned
package:

```
GuardDog v3.1.0 — 1 packages to evaluate
[cached] annotated-types==0.7.0

Summary: 1 cached, 0 scanned.
  clean 1 · advisory findings 0 · BLOCKED 0 · INCOMPLETE 0
```

The categories that fall through `REQ_RE` are git, URL and local-path
dependencies — that is, the non-PyPI sources. Lines beginning `-`
(`--index-url` and similar) are filtered deliberately one line earlier and are
not packages.

## Argued: excluding first-party source is correct; the silence is not

No repository scans its own code. `clause-and-effect` does not scan
`clause-and-effect`, and because `uv export` omits the root project,
`ai-common`'s own sweep does not scan `ai-common` either. Its source has never
been through GuardDog from anywhere.

This is a deliberate scope limit rather than an oversight. GuardDog's rules
infer malicious *intent* from patterns in code obtained from a package index —
install-time execution, obfuscation, exfiltration to an unexpected host. First-
party source is covered by controls that suit it better: git history, pull-
request review, and the CodeQL analysis that runs on every PR in both
repositories. Running a malware heuristic over code authored in-house
this week yields false positives and no signal; the two baseline waivers for
`google-genai` and `pillow` are what that noise looks like on real code.

The reasoning above is an argument, not a measurement. What is measured is
narrower: the gate does not examine first-party source, and it does not say so.

## Known gaps

- **First-party source is unscanned, and this is accepted.** Reviewed
  2026-08-13 and deliberately not scheduled. The exposure is bounded by the
  controls named above. Recorded here so that it is a decision on the record
  rather than an assumption nobody has restated.

- **An unscannable requirement line is dropped without a trace.** Today the
  only such line is this project's own `ai-common` git dependency, so nothing
  is concealed that the previous gap does not already cover. The defect is that
  no output distinguishes "not a package" from "a package I could not scan": a
  third-party git, URL or local-path dependency would be omitted from the
  scanned set with no difference in the summary, while `BLOCKED 0 ·
  INCOMPLETE 0` continued to read as full coverage. The fix belongs in
  `ai-common` — count the dropped lines and name them in the summary — and does
  not require blocking on them.

- **The gate's detection side is unverified.** `BLOCKING_SEVERITY = "high"` has
  a measured false-positive floor from the 74-package calibration sweep but an
  assumed catch rate; no package known to be malicious has been put through it.
  A gate never seen to fire is unverified.

---

**Verified against:** `clause-and-effect` at `f10e3bf`, `ai-common` at
`a2a7a21`, GuardDog 3.1.0.
---
name: waiver-review
description: Adjudicate GuardDog findings stored in the machine-wide report cache — read the rule that fired and the code it matched, decide whether it is a rule defect or real behaviour, and record the decision. Use when `make scan` or `make upgrade-safe` blocks on a package, when `guarddog-review` lists reports awaiting review, or when asked to review, waive, or accept a GuardDog finding.
---

# Reviewing a GuardDog finding

A blocked package is a question, not an answer. GuardDog's rules are
heuristics: some findings are defects in the rule, some are real behaviour
that is fine in context, and some are the thing the gate exists to catch.
Telling them apart means reading the rule and the code it matched. Nothing
else settles it.

This procedure produces one of two outcomes per report, both deliberate:

- **waived** — a waiver is written into `accepted.json` and the finding stops
  blocking that exact package version;
- **rejected** — the finding is real and that version is not adopted.

## The two ways this goes wrong

**Rubber-stamping.** A reviewer who waives without reading the match is not
reviewing. This is the failure the whole mechanism is built against, so the
evidence-gathering steps below are not optional and their absence is not a
shortcut — if the rule or the matched code cannot be found, say so and do not
recommend waiving. An unverifiable finding is not a false positive.

**Waiving something real.** A high-severity GuardDog risk is a
high-severity rule that either stands alone — install-time, or specific
enough to be malware-only — or correlates inside a single file. Treat it as
real until the evidence says otherwise, not the reverse.

## Never decide alone

Gather the evidence, state a recommendation, and **ask before writing
anything**. Waiving is the user's decision, per finding, per version. Do not
waive several findings on one approval, and do not carry an approval from one
version to the next.

## Procedure

### 1. List what is awaiting review

```bash
cd /home/bgunyel/source/ai/ai-common && uv run guarddog-review
```

Blocking findings are listed first — those are what something is waiting on.
Reports with no findings are never listed; there is nothing in them to decide.

If the run reports files it could not read, deal with those before the rest: a
report that cannot be parsed is not a report that is clean.

### 2. Read the stored report

Each listed entry names its file under
`~/.cache/guarddog-cached/reports/`. Read it in full. Two fields carry the
finding:

- `risks[]` — what the gate judged: the rule, its severity, and the location.
- `results[<rule>][]` — what the rule actually matched: `match` is the matched
  text and `code` is the surrounding excerpt.

`match` is the field that decides most reviews. Read it before forming any
view of the finding.

### 3. Read the rule that fired

```bash
ls $(uv tool dir)/guarddog/lib/python*/site-packages/guarddog/analyzer/sourcecode/<rule>.yar
```

Read the whole rule, not the description. The `meta.description` states the
rule's intent; the `strings` and `condition` state what it does, and the two
can differ sharply. Work out **which branch of the condition the match
satisfied** — a rule may have several, and the branch that fired is what the
finding actually means.

Watch for patterns without word boundaries. A bare string like `"eval("`
matches inside ordinary identifiers; a regex like `/[^.\w]eval\s*\(/` does
not. A rule whose language-specific patterns are applied to another language's
files by `path_include` is a common source of this.

### 4. Read the matched code in context

The report's `code` excerpt is usually enough. When it is not:

- read the installed copy in a project venv, at the `location` given in the
  report; or
- browse the exact artifact GuardDog scanned via the report's
  `pypi_inspector_url`.

Do not reason about what the code probably does. Read it.

### 5. Classify

**Rule defect** — the rule matched something that is not what it detects.
*Worked example:* `google-genai`'s high-severity
`threat-runtime-obfuscation-steganography` at
`test_generate_content_tools.py:217`. The report's `match` is the literal
string `eval(`, occurring inside the word `Retrieval(`. The rule's Python
patterns score zero; its JavaScript branch fires, and that branch reduces to
"contains `eval(`" and "mentions a `.png`" — both true of an ordinary Vertex
AI retrieval test. Nothing about the package is implicated.

**Real behaviour, accepted in context** — the rule matched what it says, and
that behaviour is legitimate here. *Worked example:* `pyyaml`'s
`dynamic-loader` finding is `__import__(name)` in `yaml/constructor.py` —
genuinely the `FullConstructor`/`UnsafeConstructor` path, which is the reason
`yaml.safe_load` exists. Waiving it means affirming "we know, and we use
`safe_load`". That affirmation belongs in the note, and it is a claim about
*our* usage, so it needs checking against the codebase, not just against the
package.

**Real, and not acceptable** — reject. Do not adopt that version.

The classification goes in the note. Two waivers with the same outcome and
different reasons are not the same decision, and six months on the note is the
only thing that says which one was made.

### 6. Present the evidence and ask

State, in a few lines: the rule, the severity, the matched text, which branch
of the condition fired, what the code is, the classification, and the
recommendation. Then ask for a decision on that finding.

### 7. Record the decision

**Waiving takes two writes.** The ledger records that a review happened; it
changes no verdict. Only `accepted.json` stops a finding blocking.

Write the waiver into `~/.cache/guarddog-cached/accepted.json`, creating it if
it does not exist. Keys are `name==version` — never a bare package name — and
the extra fields are for the next human to read:

```json
{
  "schema": 1,
  "accepted": {
    "google-genai==2.11.0": {
      "rules": ["threat-runtime-obfuscation-steganography"],
      "reason": "rule defect",
      "note": "JS branch of the rule matched `eval(` inside `Retrieval(`; the Python branch scores zero. Nothing in the package is implicated.",
      "reviewed": "2026-08-12"
    }
  }
}
```

Then record the review:

```bash
cd /home/bgunyel/source/ai/ai-common && uv run guarddog-review \
  --record 'google-genai==2.11.0@3.1.0' --outcome waived \
  --note 'rule defect: eval( inside Retrieval(, JS branch on a .py file'
```

For a **rejected** finding, record the review only. There is no waiver, and
the note should say what the code actually does.

### 8. Verify the gate agrees

```bash
cd /home/bgunyel/source/ai/ai-common && make scan
```

The waived finding must still be **reported** and must no longer **block**.
If it vanishes from the output entirely, something is hiding findings rather
than waiving them — stop and investigate. If it still blocks, the waiver key or the
rule name is wrong: the key is `name==version` with no GuardDog version, and
the name must be either the `threat_rule` or the rolled-up `risk.*` name
exactly as the report spells it. Prefer the `threat_rule` — the `risk.*` name
waives every rule that rolls up into it, which is a wider decision than the
one you made.

Re-run `guarddog-review` and confirm the entry is no longer awaiting review.

## What must be true at the end

- Every finding decided was read: the rule, the condition branch, and the
  matched code.
- Each decision was approved by the user individually.
- Waived findings have an `accepted.json` entry keyed on `name==version`,
  carrying a note that says which classification was made and why.
- Every decided report has a ledger entry, waived or rejected.
- `make scan` reports the waived findings and no longer blocks on them.

## Notes

- **Waivers do not carry to a new version.** A new version is new code and the
  review does not transfer. If the same finding reappears one version later,
  it still needs a decision — but the previous note tells you how long it
  takes, and an identical match at an identical location is quick to confirm.
- **A review does not carry to a new GuardDog.** The ledger keys on
  `name==version@guarddog_version`, so upgrading GuardDog re-opens every
  reviewed report. Rules change; findings nobody has seen may be waiting.
- **A changed report re-opens a review.** The ledger stores a digest of the
  findings it answered for. If a re-scan produces different matches, the entry
  is pending again.
- **The gate never reads the ledger**, and the ledger is safe to delete — the
  cost is re-reviewing, never a weakened verdict. `accepted.json` is the file
  that matters; treat deleting it as reverting every waiver ever made.
- Findings below the blocking severity are advisory: they are reported, they
  do not block, and they do not need a waiver. Reviewing them is still
  worthwhile, and recording the review stops them being re-read every sweep.
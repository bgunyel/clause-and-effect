# GDPR article-header collapse: when the fixture and the parser agree, but reality disagrees

**Date:** 2026-08-01
**Branch:** `dev-01` (baseline commit `269b6a8`)
**Components:** `src/clause_and_effect/parsers/gdpr_parser.py`,
`src/clause_and_effect/parsers/base_parser.py`,
`src/scripts/generate_gdpr_articles.py`, `tests/test_gdpr_parser.py`
**Severity:** High — corrupted the ground-truth corpus feeding chunking,
embedding, indexing, and every eval metric.

---

## 1. Summary

Regenerating `data/regulations/gdpr_articles.json` produced **one** article
instead of 99. The single record was numbered `28`, titled `Processor`, and
carried a 137,024-character body: effectively the entire regulation.

Three distinct defects were involved, in the order they were hit:

| # | Defect | Effect |
|---|---|---|
| 1 | `AcceleratorDevice.CUDA` hardcoded in the docling pipeline | Hard failure on any GPU-less machine, before parsing begins |
| 2 | Article-boundary regex required a bare `Article N` line | 1 of 99 headers matched → whole document collapsed into one article |
| 3 | Trailing-heading strip halted on the first blank line | Chapter scaffolding leaked into 22 articles' content |

Defect 2 is the interesting one. The parser was *correct against its test
fixture* and had a passing test suite. It had never been run against real
docling output.

---

## 2. Environment

```
docling   2.114.0        torch     2.13.0+cu130
rapidocr  3.9.2          openvino  2026.2.1
```

Host: 6 CPU cores, 15 GB RAM, **no NVIDIA GPU** — no `nvidia-smi`, no `nvcc`,
no `/dev/nvidia*`, and `torch.cuda.is_available()` returns `False`. The
CUDA-flavoured torch wheel is installed, which is a trap: the CUDA *libraries*
are on disk, so a naive check for "is torch CUDA-capable" passes while there is
no device to bind to.

---

## 3. Defect 1 — hardcoded accelerator device

`base_parser.py::_extract_text_from_pdf` pinned the device:

```python
pipeline_options = ThreadedPdfPipelineOptions(
    accelerator_options=AcceleratorOptions(device=AcceleratorDevice.CUDA),
    ...
    layout_batch_size=64,
)
```

Docling does **not** silently fall back. In
`docling/utils/accelerator_utils.py::decide_device`, an explicit CUDA request on
a machine without a device raises:

```python
raise AcceleratorDeviceNotAvailableError(
    "CUDA is not available in the system. "
    "Please ensure PyTorch with CUDA support is installed, or use --device auto/cpu."
)
```

### Fix

`AcceleratorDevice.AUTO` — resolves to `cuda:0`/`mps` where present and `cpu`
otherwise, so the code stays portable across the GPU workstation and this box.
Pinning `CPU` would have worked here and silently wasted a GPU elsewhere.

`layout_batch_size` was also reduced 64 → 8. That value is GPU-shaped; on CPU
the run peaked at 2.8 GB RSS with the smaller batch, comfortable within 15 GB.
Note the OCR stage was always CPU-bound anyway — `RapidOcrOptions(backend="openvino")`
runs on Intel CPU — so the CUDA pin only ever drove the layout and table models.

**Observed cost:** ~5–6 minutes wall-clock for the 88-page PDF on 6 cores,
running at ~183% CPU across 25 threads.

---

## 4. Defect 2 — the article-boundary regex (root cause)

### 4.1 The regex

```python
# before
_ARTICLE_HEADER = re.compile(r'^Article\s+(\d+)[ \t]*$', re.MULTILINE)
```

The intent — documented at length in the source — was to match only
*line-anchored* headers, so that inline cross-references like
`"...as referred to in Article 6..."` would not split an article. That intent
was correct and remains correct. The mistake was the assumption about what a
line-anchored header *looks like* in docling's markdown export.

### 4.2 What docling actually emits

Measured over the real export (387,818 characters):

| Header form | Count |
|---|---|
| `## Article N` | **98** |
| `Article N` (bare) | **1** — Article 28 |

Docling is *inconsistent*. It promotes 98 of 99 article headers to markdown
`##` headings and, for Article 28 alone, emits the bare text. The same
inconsistency appears again for section markers: `## Section 2` everywhere
except a bare `Section 1` after Article 59.

The old regex therefore matched exactly one header — the bare Article 28 — and
`_extract_articles` assigned everything from that point to EOF as its body.
Articles 1–27 preceded the sole match and were dropped entirely; 29–99 were
swallowed as content.

### 4.3 The contradiction that was already in the file

The codebase contained the evidence of its own bug. `_clean_title` strips
markdown heading markers:

```python
@staticmethod
def _clean_title(line: str) -> str:
    """Strip leading markdown heading markers ('## ') and whitespace."""
    return re.sub(r'^#+\s*', '', line.strip())
```

So the author *knew* docling emits `## ` prefixes on the title line directly
below the header — but the boundary regex one screen above refused to accept
that same prefix on the header line. Two functions, twenty lines apart,
encoding contradictory beliefs about the input format.

**Generalisable signal:** when one function defensively strips a pattern that a
neighbouring function's regex forbids, one of them is wrong about the input.
That inconsistency is cheap to grep for and worth treating as a smell.

### 4.4 Fix

```python
# after
_ARTICLE_HEADER = re.compile(r'^#{0,6}[ \t]*Article[ \t]+(\d+)[ \t]*$', re.MULTILINE)
```

`#{0,6}` makes the heading prefix optional rather than required (requiring `##`
would have dropped Article 28's boundary — the mirror-image bug). `\s+` was
tightened to `[ \t]+` so the pattern cannot span a newline and match an
`Article` / `28` split across two lines.

Verified against the real export: **99 matches, 99 distinct numbers, complete
1–99, no duplicates, strictly ascending.**

---

## 5. Defect 3 — trailing scaffolding strip halted on blank lines

With boundaries fixed, 99 articles were extracted but the generator's
truncation heuristic flagged **22** of them. All 22 were false alarms in the
sense that no text was missing — but each carried foreign content:

```
art 4  ...an agreement between two or more countries.\n\n## CHAPTER II
art 11 ...enabling his or her identification.\n\n## CHAPTER III\n\n## Rights of the data subject\n\n## Section 1
art 43 ...the examination procedure referred to in Article 93(2).\n\n## CHAPTER V
```

The last article of each chapter absorbed the *next* chapter's heading block.
`_clean_content` was meant to remove exactly this:

```python
lines = content.rstrip().split('\n')
while lines and re.match(r'#+\s', lines[-1].lstrip()):
    lines.pop()
```

The trailing lines of Article 4 are:

```python
['', '## CHAPTER II', '', '## Principles']
```

The loop pops `## Principles`, then examines `''`, which does not match `#+\s`,
and **stops** — leaving `## CHAPTER II` welded to the article body. The strip
removed at most one heading and only when no blank line intervened. Since
docling separates block elements with blank lines, that is essentially never.

### Fix

A predicate that treats blank lines as skippable and recognises bare structural
markers alongside `##`-prefixed ones:

```python
_TRAILING_SCAFFOLDING = re.compile(
    r'^\s*(?:#+\s.*|(?:CHAPTER\s+[IVXLC]+|Section\s+\d+)\s*)$'
)

@classmethod
def _is_trailing_scaffolding(cls, line: str) -> bool:
    """True for blank lines and structural headings that belong to the next section."""
    return not line.strip() or bool(cls._TRAILING_SCAFFOLDING.match(line))
```

The bare-marker branch is load-bearing: after the blank-line fix alone, Article
59 still ended with `## CHAPTER VII\n\n## Cooperation and consistency\n\nSection 1`,
because that final `Section 1` — like Article 28's header — lost its `##`.

### Why this mattered beyond tidiness

This was not cosmetic. Those 22 articles would have been chunked and embedded
with another chapter's title appended, injecting lexically strong but
semantically wrong terms ("Remedies, liability and penalties", "Independent
supervisory authorities") into vectors for unrelated articles. It is a
retrieval-precision defect wearing a formatting costume.

---

## 6. Why nothing caught it

### 6.1 The fix was committed but never executed

`7689713 Fix GDPR article truncation at inline cross-references` rewrote the
parser and added `generate_gdpr_articles.py`. Its diff touched exactly two
files:

```
src/clause_and_effect/parsers/gdpr_parser.py | 62 ++++++++++++++-----
src/scripts/generate_gdpr_articles.py        | 83 ++++++++++++++++++++++
```

It did **not** regenerate `gdpr_articles.json`. That file was last written on
2026-03-19 by the original one-off buggy path and has only ever been touched by
`59f7c03`. So between 2026-07-23 and 2026-08-01 the repository was in a state
where the parser was "fixed", the tests were green, and the actual data on disk
was still corrupt — with nothing in CI or the test suite able to notice, because
the two were never connected.

**A parser fix is not done when the parser is fixed. It is done when the
artifact it produces has been regenerated and diffed.**

### 6.2 The fixture encoded the assumption instead of testing it

`tests/test_gdpr_parser.py` opened with an honest description of its own
weakness, unnoticed at the time:

```python
# Synthetic markdown mirroring docling's export: a line-anchored "Article N"
# header, ...
SAMPLE = """Article 93
## Committee procedure
...
```

Every header in the fixture used the bare form — the shape docling produces for
**1 of 99** headers. The fixture was not derived from real output; it was
written from the same mental model that produced the regex. The tests then
verified that the parser agreed with the author's belief, which it did,
perfectly, 33 tests green.

A test fixture written by the same person, at the same time, from the same
assumption as the code cannot falsify that assumption. It only checks internal
consistency.

### 6.3 The generator had no structural invariant

`generate_gdpr_articles.py` validated per-article plausibility (does the content
end mid-sentence?) but never asserted the one fact known a priori with total
certainty: **GDPR has exactly 99 articles.** Its output was:

```
✅ Wrote 1 articles to .../gdpr_articles.json

Validation summary
articles extracted     : 1
likely-truncated       : 1
```

The information was right there — and the script still exited 0 and cheerfully
printed a ✅. A corpus-level invariant would have made this a hard failure at
the moment of corruption.

---

## 7. Diagnostic technique worth reusing

### 7.1 Recovering document structure from the corrupted output

The bad JSON was not just evidence of the bug, it was a near-complete copy of
the input. Counting header shapes *inside* the collapsed blob gave the answer
before any re-run:

```
71 occurrences of '## Article N' inside the single article's content
```

71 = articles 29–99. Plus 27 articles preceding the match, plus Article 28
itself = 99. That arithmetic confirmed both the true header format and the
precise failure mode in one step, from an artifact already on disk.

### 7.2 Cache the expensive intermediate

Each docling conversion costs ~5–6 minutes on this hardware, which makes
regex iteration untenable — the naive loop is *edit → wait 6 minutes → look*.
Dumping the markdown export once to disk turned every subsequent hypothesis
into a sub-second check.

That cached export is now committed at `data/regulations/gdpr.docling.md`
(387,818 chars) and serves double duty as a test fixture, so parser work no
longer requires the PDF, OCR, or a GPU.

### 7.3 A pipe destroyed an exit code

The first attempt to dump the markdown appeared to succeed — the task reported
**exit code 0** — but produced no file. The command was:

```bash
.venv/bin/python dump_markdown.py 2>&1 | grep -v "RapidOCR\|INFO\]"
```

Python died instantly with `ModuleNotFoundError: No module named 'src'` (running
a script by absolute path does not put the repo root on `sys.path`; `python -m`
does). The shell reports the exit status of the *last* command in a pipeline —
`grep` — which succeeded. The failure was invisible for one round-trip.

Use `set -o pipefail`, check `${PIPESTATUS[0]}`, or redirect to a file and grep
afterwards. Never read the exit code of a pipeline whose last stage is a filter.

---

## 8. Verification

Extraction from the cached export was checked before spending another
conversion, then the committed artifact was confirmed **byte-identical** to it
— which also demonstrates docling's output is deterministic across runs on this
input.

| Metric | Before | After |
|---|---|---|
| Articles | 99 (76 truncated per `7689713`) | 99 |
| Total content | 81,928 chars | **187,323 chars** |
| Numbers 1–99 complete | — | yes, no duplicates |
| Empty titles / content | — | none |
| Titles retaining `#` | — | none |
| Scaffolding leaks | 22 articles | none |
| Articles materially longer (>20 chars) | — | **67 / 99** |

Largest recoveries:

```
art 70:   991 ->  6368   (+5377)
art 83:   495 ->  5510   (+5015)
art 47:   145 ->  4885   (+4740)
art 49:    61 ->  4059   (+3998)
```

### Accounting for the 32 articles that shrank

Shrinkage in a data-recovery fix deserves suspicion, so each case was checked
rather than assumed benign. Normalising whitespace and diffing showed:

- 31 of 32 lost **only** whitespace and scaffolding. The complete set of dropped
  words across all of them is structural: `CHAPTER`, `Section`, roman numerals,
  and chapter titles (`Rights of the data subject`, `Transparency and modalities`,
  `Remedies liability and penalties`, ...). No regulatory text.
- Articles 77 and 82 were *not* substrings of their old versions because they
  **gained** text: ` Article 78.` and ` Article 79(2).` respectively — the exact
  inline cross-references at which the original tempered-token regex had cut
  them. Their raw character counts fell only because OCR double-spacing was
  collapsed.

### Remaining flag (accepted, not fixed)

Article 99 still trips `_looks_truncated`. It is a false positive: the body ends
with the regulation's signature block —

```
Done at Brussels, 27 April 2016.
For the European Parliament The President M. SCHULZ For the Council The President J.A. HENNIS-PLASSCHAERT
```

— which has no terminal punctuation. The article text itself is complete. No
trailer-stripping heuristic was added, because distinguishing a document trailer
from article content is a judgement call that should be made deliberately rather
than buried in a cleanup regex.

### Test suite

`40 passed, 1 xfailed` (previously `33 passed, 1 xfailed`). The fixture now
mirrors the real export — both header forms, chapter scaffolding, and the bare
`Section 1` — and four new tests run the parser over the committed
`gdpr.docling.md`, asserting all 99 articles, clean titles, zero scaffolding
leakage, and survival of Article 56's inline `Article 55` reference.

---

## 9. Lessons

1. **Fixtures must be derived from real tool output, not from the mental model
   that produced the code.** A hand-written fixture and the implementation it
   accompanies are the same hypothesis stated twice; green tests then prove only
   self-consistency. Where a real artifact can be captured and committed, do
   that — it is the only fixture that can falsify the assumption.

2. **Assert corpus-level invariants, not just per-item plausibility.** "GDPR has
   99 articles" is knowable in advance and would have converted this from silent
   corruption into an immediate hard failure. Per-item heuristics cannot detect
   a failure that produces one item.

3. **Third-party extraction tools are not uniform.** Docling formatted 98 of 99
   headers one way and one header another; the same held for section markers.
   Parsers over ML-derived output should accept a *family* of shapes and be
   validated by counting, never by trusting a sampled inspection.

4. **A fix to a generator is incomplete until its artifact is regenerated.**
   Commit `7689713` left the repository looking fixed while the corrupt data sat
   untouched on disk for nine days. Treat code-and-artifact as one deliverable.

5. **Contradictions between neighbouring functions are bug signals.** One
   function stripping `##` while another rejected it pinpointed the false
   assumption, and was visible by reading twenty lines of the same file.

6. **Cache expensive intermediates before iterating.** A 6-minute inner loop
   discourages hypothesis testing; a sub-second one encourages it.

7. **Never trust a pipeline's exit code when the last stage is a filter.**

8. **Explain every anomaly, including ones pointing the "right" way.** The 32
   shrinking articles could plausibly have been dismissed as whitespace noise.
   Two of them turned out to be recovering truncated cross-references — and had
   the cause been real content loss instead, dismissing it would have shipped a
   regression inside a fix.

---

## 10. Follow-up work (not yet done)

- [ ] Add a hard `EXPECTED_ARTICLE_COUNT = 99` assertion to
      `generate_gdpr_articles.py`; exit non-zero on mismatch instead of printing ✅.
- [ ] Make `_looks_truncated` aware of the Article 99 signature block, or add an
      explicit allow-list, so the validation summary can reach a clean state and
      any future flag is meaningful.
- [ ] Decide whether the signature block belongs in Article 99's content at all
      before it is embedded.
- [ ] Re-chunk → re-embed → re-index Qdrant from the corrected JSON, then re-run
      golden-set QA to separate the 246 quote-grounding errors caused by this bug
      from genuine golden-set defects (`docs/todo.md` §Blocking).
- [ ] Consider having `generate_gdpr_articles.py` cache and optionally reuse the
      docling markdown, so parser changes are verifiable without a full OCR run.

---

## Appendix — reproduction and verification commands

```bash
# Regenerate the article JSON from the PDF (~6 min, CPU)
python -m src.scripts.generate_gdpr_articles

# Verify extraction against the committed docling export (sub-second, no PDF)
python -m pytest tests/test_gdpr_parser.py -q

# Confirm header-shape distribution in the real export
python - <<'PY'
import re
from collections import Counter
md = open('data/regulations/gdpr.docling.md', encoding='utf-8').read()
pat = re.compile(r'^#{0,6}[ \t]*Article[ \t]+(\d+)[ \t]*$', re.MULTILINE)
print(Counter(m.group(0).replace(m.group(1), 'N') for m in pat.finditer(md)))
print('numbers:', [int(n) for n in pat.findall(md)] == list(range(1, 100)))
PY
```
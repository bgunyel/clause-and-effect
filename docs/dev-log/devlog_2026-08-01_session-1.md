# Devlog — 2026-08-01 · session 1

**Branch:** `dev-01` · `269b6a8` → `976b98b` (8 commits) · 17 ahead of `main`, no PR
**Theme:** GDPR corpus regeneration — and the two parser defects it exposed
**Tests:** 33 passed / 1 xfailed → **52 passed / 1 xfailed**

> **Note on voice:** this entry predates the log's attribution convention and is
> written in the AI assistant's voice — "I" is the assistant, "the user" is
> Bertan (the engineer). Mistakes recorded below are the assistant's unless
> stated otherwise; findings credited to "the user" are Bertan's. Later entries
> name agents explicitly — see [README](README.md#voice-and-attribution).

---

## Starting point

Resumed with no carry-over context beyond the branching-convention note, so
state was reconstructed from the repo. Clean tree, `dev-01` pushed, and
`docs/todo.md` flagging one blocking item: the Qdrant index was built from a
corpus in which 76 of 99 articles had been truncated at their first inline
`Article N` cross-reference.

The parser fix for that defect had been committed on 2026-07-23 as `7689713` —
but its diff touched only source files. The article JSON had never been
regenerated, so the repository had been carrying a "fixed" parser, green tests,
and corrupt ground-truth data simultaneously for nine days.

---

## What happened

### 1. The CUDA question was a real blocker

Session opened with a question about whether CUDA was available. It is not — no
`nvidia-smi`, no `nvcc`, no `/dev/nvidia*`, and `torch.cuda.is_available()`
returns `False`. `torch 2.13.0+cu130` is installed, so the CUDA libraries sit on
disk with no device to bind to, which makes a naive "is torch CUDA-capable"
check misleading.

`base_parser.py` pinned `AcceleratorDevice.CUDA`, and docling does not fall
back: `decide_device()` raises `AcceleratorDeviceNotAvailableError`. So
regeneration would have failed before parsing anything.

Switched to `AUTO` — resolves to CUDA/MPS where present and CPU otherwise, so
the pipeline stays portable rather than being pinned to this box — and dropped
`layout_batch_size` 64 → 8, a GPU-shaped value. Run peaked at 2.8 GB RSS,
~6 minutes at ~183% CPU across 25 threads. → `14d741c`

### 2. Regeneration produced garbage, not success

Output: **one** article, numbered 28, titled "Processor", 137,024 characters.

Restored the previous JSON from git before diagnosing — a 1-article file is
strictly worse than a 99-truncated one, and the tree should not sit in the worse
state while investigating. Preserved the corrupt output for analysis.

### 3. Root cause — parser and fixture agreed with each other, not with docling

The boundary regex required a bare `Article N` line:

```python
_ARTICLE_HEADER = re.compile(r'^Article\s+(\d+)[ \t]*$', re.MULTILINE)
```

Docling emits `## Article N` for **98 of 99** headers and the bare form for
exactly one — Article 28. So a single header matched and absorbed everything to
EOF; articles 1–27 were dropped outright.

The contradiction was already in the file: `_clean_title` strips `##` markers
from the title line, while the regex twenty lines above refused that same prefix
on the header line. Two functions encoding opposite beliefs about the input.

The test fixture used the bare form throughout — the shape docling produces for
1 of 99 headers. Written from the same mental model as the code, it could only
confirm self-consistency, which is why 33 tests stayed green over a parser that
did not work on real input.

Fix: `r'^#{0,6}[ \t]*Article[ \t]+(\d+)[ \t]*$'`. The prefix is *optional* rather
than required — demanding `##` would have dropped Article 28's boundary, the
mirror-image bug. `\s+` tightened to `[ \t]+` so a header cannot match across a
newline.

### 4. A second defect surfaced once boundaries were correct

99 articles extracted, but 22 flagged. `_clean_content`'s trailing-heading strip
halted at the first blank line:

```python
while lines and re.match(r'#+\s', lines[-1].lstrip()):
    lines.pop()
```

Article 4's trailing lines are `['', '## CHAPTER II', '', '## Principles']` — it
pops one heading, hits the blank, stops. Since docling separates blocks with
blank lines, the strip effectively never worked, welding the next chapter's
scaffolding onto the last article of each chapter.

Not cosmetic: those 22 articles would have been embedded with a foreign chapter
title appended, injecting lexically strong but semantically wrong terms into
unrelated vectors.

Fixed by skipping blanks while stripping and recognising bare `CHAPTER IV` /
`Section 2` markers — docling drops the `##` there too, which is what left
Article 59 still dirty after the blank-line fix alone. → `9ecdf6f`

### 5. Verified rather than assumed

99 articles, numbered 1–99, no gaps or duplicates, no scaffolding leaks, no
empty titles. Content **81,928 → 187,323 chars**, 67 of 99 materially longer
(article 49: 61 → 4,059).

Committed output confirmed byte-identical to extraction from the cached
markdown, which also demonstrates docling is deterministic on this input.

Checked all 32 articles whose character count *fell*, rather than assuming
shrinkage was benign: 31 lost only whitespace and scaffolding — the complete set
of dropped words is `CHAPTER`, `Section`, roman numerals and chapter titles, no
regulatory text. Articles 77 and 82 had **gained** ` Article 78.` and
` Article 79(2).` — the exact cross-references the original regex had cut them
at. Their raw counts fell only because OCR double-spacing was collapsed.
→ `bc63974`

### 6. Qdrant point IDs

Prompted by a question about the `i*batch_size + j` expression, where `i` is
already the offset rather than a batch counter. The arithmetic was
collision-free for any batch size (`id = k·bs² + j` with `j < bs`), so nothing
was corrupted — IDs were merely sparse (max 50062 for 563 chunks).

The real problem was that they were *positional*, which re-keys the whole corpus
whenever chunk composition changes. That is precisely why the collection had to
be dropped before re-indexing.

Rekeyed to `uuid5(POINT_ID_NAMESPACE, chunk.id)` — Qdrant accepts only unsigned
integers or UUIDs, so the semantic key `gdpr_article_5_para_1` cannot be used
directly. Re-indexing is now idempotent.

Added the two guards the layer lacked: duplicate chunk IDs raise before anything
is written, and the stored point count is read back with `count(exact=True)`
after indexing — fewer points than chunks raises, more warns about orphans. The
success line now reports the stored count rather than `len(chunks)`, which would
have claimed success even if every point had collided. 12 offline tests, with
the fake client modelling Qdrant's overwrite-on-duplicate behaviour so the
guards are exercised against the real hazard. → `7f42ea5`

### 7. Re-indexed

`compliance_docs` recreated (1536-dim, cosine). 563 chunks → **563 points**,
verification passed silently, ~13s across 6 batches. Smoke query returns
Article 17 §2/§3 *Right to erasure* at 0.463/0.432 for a deletion-timeline
question.

---

## Decisions

- **`AUTO` over `CPU`** for the accelerator — pinning CPU would work here and
  silently waste the GPU workstation.
- **The uuid5 namespace stays in source, not `.env`.** Raised as a possible
  secret; it is not one. `uuid5` is unkeyed SHA-1, `chunk_id` is already stored
  in the payload in plaintext, and access is governed by `QDRANT_API_KEY`.
  Secrecy would add a real failure mode: a namespace differing between
  environments silently writes a parallel set of points instead of updating in
  place.
- **Article 99's truncation flag left in place.** It is a false positive — the
  body ends with the regulation's signature block, which has no terminal
  punctuation. Adding a trailer-stripping heuristic would bury a judgement call
  about whether that block belongs in article content at all.
- **Title whitespace deferred.** `_clean_title` does not collapse OCR
  double-spacing the way `_clean_content` does, so 3 titles (articles 12, 60,
  89) and 27 of 563 chunks carry it. Deferred into the planned chunking and
  embedding rework rather than fixed piecemeal, since that work regenerates
  everything anyway.
- **Commits split code from data** so the parser fix is reviewable without a
  396-line JSON diff, and the regeneration evidence lives with the data commit.

---

## Mistakes made this session

Recorded because they cost time or misinformed decisions:

- **Reported a script as succeeding on exit code 0** when Python had died
  immediately with `ModuleNotFoundError`. The command ended in
  `| grep -v ...`, and the shell reports the exit status of the last stage of a
  pipeline. Cost one round-trip. Use `set -o pipefail` or `${PIPESTATUS[0]}`.
- **Overstated the re-index cost as "real money"** and gated it on that basis
  twice. It is ~$0.001 for ~54k tokens with `text-embedding-3-small`. The
  legitimate reason to gate it was cluster mutation, not spend.
- **Miscounted commits ahead of `main`** — said 10, then 12; it was 16.

---

## Deliverables beyond the fix

- `data/regulations/gdpr.docling.md` (387,818 chars) committed. Each docling
  conversion costs ~6 minutes of CPU OCR, which made regex iteration
  impractical; caching the export turned that into a sub-second loop, and it now
  doubles as a test fixture so parser work needs no PDF, OCR, or GPU.
  → `170c182`
- `docs/lessons-learned/` created with conventions plus a 472-line post-mortem
  of this bug. → `3c52d39`
- `docs/todo.md` rewritten against reality, including an explicit warning that
  every eval number predating today is void. → `976b98b`

---

## State handed to the next session

| | |
|---|---|
| Corpus | 99 articles, 187,323 chars |
| Qdrant | `compliance_docs`, 563/563 points verified |
| Tests | 52 passed, 1 xfailed |
| Branch | `dev-01` @ `976b98b`, 17 ahead of `main`, clean tree |

**Open:**

- **Golden-set QA re-run** (`python -m src.eval.golden_qa`) — the last
  data-integrity step, separating the 246 quote-grounding errors into truncation
  artifacts versus genuine golden-set defects. Needs judge-model spend. Worth
  doing before any chunking experiment, since it establishes the only valid
  baseline.
- **PR from `dev-01` into `main`** — 17 commits queued.
- Chunking and embedding rework is the next planned direction; the deferred
  title-whitespace fix belongs there.
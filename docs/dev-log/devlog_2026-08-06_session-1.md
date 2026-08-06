# Devlog — 2026-08-06 · session 1

**Branch:** `dev-02`, 33 commits ahead of `main` · `e635cb8` → `111cffd`
(7 commits this session; the docs commits follow this entry)
**Theme:** The corpus was rebuilt from docling's document tree and now carries the
regulation's own paragraph numbering — and the same defect was found one layer
down, in the chunker, where Article 4 turns it into eight fabricated citations
**Tests:** 81 passed, unchanged — none of them touch the code written today
**Gate:** 285 exact / 34 normalized / 114 ungrounded, 319 of 433 clean
(was 285 / 14 / 134, 299 clean)

---

## The corpus now carries the regulation's own numbering

The 2026-08-05 session ended with a seven-step plan to rebuild
`gdpr_articles.json` from `gdpr.docling.json` instead of `gdpr.docling.md`. That
plan was executed, and every structural claim in it held.

Bertan set the shape: `BaseParser` gains a `to_dictionary` method beside
`to_markdown`, the expensive conversion moves out into a shared `_convert_pdf`,
and the tree-based extraction becomes `GDPRParser.get_articles_from_dictionary`.
He also directed that `export_docling_json.py` be written to mirror
`export_docling_markdown.py`, and that the article record keep its existing four
keys so no other component would need to change.

Verified against `gdpr.docling.json` before any code was written:

| claim | result |
|---|---|
| depth-first walk from `#/body` resolves every reference | **1623 / 1623**, once `#/pictures/0` is in the lookup |
| `^Article\s+(\d+)$` on `section_header` **or** `text` finds the articles | **99, in order, no gaps** |
| the title is the item after the heading | **99 / 99**, always a `section_header` |
| paragraph numbering forms 1..N per article | **0 violations** |

One hazard was new, and the markdown path had never had it: **349 of 1623 text
items are `content_layer: "furniture"`** — running page headers (`4.5.2016`,
`EN`, `Official Journal of the European Union`) interleaved with the body in
reading order. The serializer had been dropping those for us. A tree walk does
not, and unfiltered they land inside article text.

### The outcome, measured

99 articles, numbering contiguous in every one. 59 of 99 articles changed;
content 187,287 → 185,466 chars. The check that mattered was whether anything
was *lost*: stripping numbering and bullets, prose is byte-identical to the
markdown path in **96 of 99** articles. The three that differ — 5, 43 and 79 —
differ by exactly the footnote each now drops, confirmed individually by showing
`old_content − footnote == new_content`.

Golden-set QA: **clean 299 → 319**, ungrounded **134 → 114**, `exact` unchanged
at 285, **zero regressions**. Twenty cases cleared.

The 2026-08-05 entry predicted 26 would clear. **The actual figure is 20.** That
prediction was never a measurement of this defect — it counted quotes failing
*grounding* after stripping spurious enumeration numbers, and the backlog had
already labelled it a floor on a different quantity. Recorded so it is not
remembered as having been met.

### The invariant was verified to fail, not only to pass

`generate_gdpr_articles.py` gained `_check_invariants`: 99 articles numbered
1..99, no gaps or duplicates, no empty title or content, paragraph numbering
contiguous 1..N. Enforced before writing, exiting non-zero.

This closes a backlog item open since 2026-08-01, when the script printed
`✅ Wrote 1 articles` and exited 0 over a collapsed corpus. Following the
`span_is_verbatim` lesson — a gate never observed to fail is unverified — it was
run against the *old* markdown path, which it rejects:

```
❌ Corpus invariants violated (42); nothing written.
   - article 2: paragraph numbering is not 1..N ([1, 2, 3, 4, 5, 6, 3, 4])
   - article 4: paragraph numbering is not 1..N ([8, 9, 2, 3, 4, 6, 7])
```

Article 2's `[1,2,3,4,5,6,3,4]` is the restart-collision Bertan found by reading
the markdown on 2026-08-05, now detected mechanically.

The check is line-anchored (`re.MULTILINE`) deliberately: an unanchored pattern
also matches the `22.` ending *"…referred to in Articles 15 to 22."*. That
detail becomes the session's second finding.

---

## Bertan found the same defect one layer down, in the chunker

With the corpus fixed, Bertan asked the question that reframed the session:
**if the numbering is now correct, can the existing chunker handle the implicit
hierarchy?**

Measured rather than argued. Every article was rendered from the tree with
correct numbering and run through the *existing* `_split_into_paragraphs`:

```
articles over the 1000-char budget           : 61
  regex pieces == real paragraph count       : 50   ✅
  MISMATCH                                   : 11   ❌
articles that don't split at all             : ['4']
indentation survives _clean_content          : False
```

Fifty of 61 work — correct numbering alone genuinely removes most of the
severance, which the assistant had not expected to be that high. Ten of the
eleven failures are one thing:

```
art 12: '…rights under Articles 15 to 22. In the cases referred to in…'
art 35: '…impact assessment pursuant to paragraph 1. The supervisory…'
art 58: '…referred to in paragraphs 1, 2 and 3. The exercise of…'
```

Cross-references ending a sentence. `\d+\.\s+` cannot tell `22. ` from `2. `.

**This is the bug already fixed one level up.** `_ARTICLE_HEADER` is
line-anchored precisely because the original parser keyed article boundaries off
inline `Article N` references and truncated three-quarters of the corpus. The
paragraph splitter has the identical defect, unfixed — and it fails silently:
`re.split` deletes the number and `metadata["paragraph"]` is the enumeration
index, so one spurious split stamps real ¶3 as `paragraph: "4"` through the end
of the article. **In those ten articles the paragraph metadata is wrong against a
perfect corpus.**

### Article 4, supplied by Bertan, is the case that settles the design

Bertan pasted two indexed chunks with the comment *"Article 4 chunks are
disaster!"*. They were worse than they looked. Article 4 has **no numbered
paragraphs** — a stem and 26 definitions, three of which have their own (a)/(b)
sub-points. The serializer's invented numbers became the boundaries:

```
para_1  definitions 1–16   4,779 chars, ending on "(16) 'main establishment' means:"
para_2  — none —           4(16)(a), severed from its definiendum
para_3  definitions 17–22  but the chunk OPENS "(b) as regards a processor…"
para_6  — none —           "(c) a complaint has been lodged with that supervisory authority;"
```

Three harms, and separating them mattered for the design that followed:

1. **Severance inverts meaning.** `para_6` is 111 characters with nothing saying
   it is one of three conditions defining *"supervisory authority concerned"*.
2. **Retrieval by accident.** *"Binding corporate rules"* (definition 20) is
   reachable only through `para_3`, whose embedding is dominated by the
   processor-establishment text it opens with. The chunk cannot be found by the
   query it answers.
3. **Fabricated citations.** All eight `paragraph` values are invented. Article 4
   has no paragraph 2.

Bertan proposed the fix: descend by hierarchy — try the article, then first-order
paragraphs, and only split a paragraph by its (a)/(b)/(c) if it still does not
fit. Article 2 confirms it: 1,366 chars → four paragraphs of 247/594/324/197,
with ¶2 keeping (a)–(d) intact.

Two refinements came out of measuring it. **The stem must be repeated into every
third-level chunk**, or splitting Article 9 ¶2 into ten bare sub-items recreates
`art2_case4` one level down. And the third level is **not** an edge case: 31
paragraphs across 26 articles exceed 1000 chars, led by Article 4 ¶1 at 8,511.
`art 65 ¶6` — 1,049 chars, zero sub-items — has no level to descend into at all
and needs a deliberate terminal rule.

Article 4 is now knowingly parked as **one 8,655-char chunk**: nothing severed,
no fabricated numbers, but not retrievable at definition granularity. The full
design is recorded as the top blocking backlog item.

---

## Chunk sets became a tracked artifact

Bertan raised the next problem before it bit: chunks are created and immediately
embedded, leaving no record. He proposed a folder of dated chunk files.

The assistant argued for one change to that: **a timestamp records *when*, but
the problem is *which*.** A live probe made the point concrete —

```
'compliance_docs': points=563   config.metadata=None
```

563 points from a corpus that no longer exists, against 368 the current corpus
produces. Roughly 195 orphans, and nothing in the repository able to say so. A
dated file alone cannot answer "is the index built from this chunk set?", so
identity has to be a **content hash**, with the timestamp used only for ordering.

Bertan's decisions: use the existing `CHUNKS_DIR` setting; separate generating
chunks from indexing them so either can run alone; commit snapshots to git; and
push the hash to Qdrant, preferring a collection-level property over per-point
payload but unsure whether that existed.

It does. Verified live: `create_collection(..., metadata=…)`,
`update_collection(..., metadata=…)`, read back via
`get_collection(name).config.metadata`. One behaviour worth knowing —
**`update_collection` merges rather than replaces**; a key written once survived
an update that did not mention it, so the metadata schema has to be decided up
front rather than allowed to accrete.

`chunk_store.py` and `generate_chunks.py` were built. The hash is computed over
canonical chunk content — sorted by ID, keys sorted — never over the file bytes,
since those carry the timestamp and would report a false change every run.

### `git_dirty_paths`, from a question Bertan asked

Asked whether a dirty tree meant everything should be committed first, the
assistant's answer was yes for keeper snapshots — but flagged that `git_dirty` is
repo-wide, so an unrelated draft would flag a snapshot that is genuinely
reproducible, pressuring the engineer to commit unrelated work to clear a
boolean. Bertan approved recording **which** paths are dirty. `git_dirty: true`
with `["docs/dev-log/draft.md"]` and with
`["src/clause_and_effect/parsers/gdpr_parser.py"]` are the same flag and opposite
verdicts.

### The chicken-and-egg that forces the commit order

A manifest is written before the snapshot is committed, so **it can never name
the commit that contains it**. Committing code and snapshot together records a
commit where `generate_chunks.py` does not exist. Hence the convention: *a
snapshot's manifest names its parent commit*, and the code must be committed
before the snapshot is generated. This is a requirement of the mechanism, not a
preference — and it is why no snapshot was written this session.

---

## `docs/design/`

Bertan asked for a folder for design documents and for a name to be proposed
first. `docs/design/` was chosen over `design-notes/` and `architecture/`. Its
README states the distinction most likely to erode: `dev-log/`,
`lessons-learned/` and `eval-reports/` are **records**, written once and never
edited; design documents are **current state**, rewritten when the mechanism
changes, with history left to git.

First entry: `chunk-snapshot-reproducibility.md`, twelve sections including nine
known gaps.

---

## Decisions

- **The article record keeps its four keys** (`number`, `title`, `content`,
  `chapter`), at Bertan's direction — no system component changes, and the
  hierarchy is expressed inside `content` via correct numbering. The nested model
  is built in memory but not serialized; exposing it belongs with the chunker fix.
- **Footnotes are dropped from article content.** Three items, articles 5, 43,
  79. Bertan reviewed them and ruled it is too early to worry about footnotes;
  recorded for future review rather than settled.
- **Cited instruments may enter the corpus in a future version**, raised by
  Bertan — 9 instruments, 25 mentions, 14 articles. Explicitly not now.
- **`--source markdown` is kept, not deleted.** The two paths agreeing on 96 of
  99 articles is the check that the tree walk dropped nothing.
- **`content` renders markers inline, newline-separated, no indentation** —
  `_clean_content` collapses runs of spaces anyway, so indentation would only make
  the two paths differ for no gain.
- **The manifest does not record chunker parameters.** A duplicated constant is a
  second source of truth; `git_commit` pins the code instead.
- **The chunk hash covers `id`, `text`, `metadata` — not the embedding model.**
  Recorded as a gap: two collections can honestly share a hash and retrieve
  differently.
- **`docs/design/` for design documents**, at Bertan's direction.

---

## Mistakes made this session

Attributed, per this log's convention. All are the assistant's unless stated.

- **Claimed to have created `data/chunks/` when it had not been created.** Stated
  in a summary as completed work; the directory did not exist until the next turn.
  Caught by the assistant on re-checking, but only after the claim had been made.
- **Cited "the tool's own warning" as if it were independent corroboration.** The
  `git_dirty` warning was written by the assistant minutes earlier in the same
  session; quoting it back as support dressed the assistant's own judgment up as a
  check. Bertan asked what was meant by the phrase, which is what surfaced it.
- **Recorded an absolute path in the manifest**, embedding one machine's home
  directory into an artifact intended to be committed. Caught before the first
  commit, but only by reading the output rather than by any check.
- **Left the design document asserting a snapshot existed.** The worked-example
  section was written as "the first snapshot" when no snapshot had been written to
  `data/chunks/`. Corrected while committing.

Bertan's catches this session were again the ones that changed direction: asking
whether the existing chunker could handle the corrected hierarchy — which
produced the 50-of-61 measurement and the cross-reference finding — and supplying
the two Article 4 chunks, which turned an abstract argument about chunk severance
into the case that settled the recursive-descent design.

---

## State handed to the next session

| | |
|---|---|
| Corpus | 99 articles, 185,466 chars, **paragraph numbering contiguous in all 99** |
| Golden set | 285 exact · 34 normalized · 114 ungrounded · 319/433 clean |
| Chunks | 368 with the unchanged chunker (was 563) — **no snapshot written yet** |
| Qdrant | `compliance_docs`, **563 points, `metadata=None`** — stale, ~195 orphans expected |
| Chunk archive | `chunk_store.py` + `generate_chunks.py` built and verified; `data/chunks/` empty |
| Sufficiency judge | unchanged — stages A and B only |
| Tests | **81 passed**; none cover today's code |

**Open, roughly in order:**

- **Generate the first chunk snapshot** against a clean tree, then commit it
  separately — the mechanism is built but has produced nothing, so there is still
  no baseline for the chunker fix to be measured against.
- **Make the chunker hierarchy-aware** — the top blocking item, with Article 4 as
  the worked example and the full design in `todo.md`.
- **Write the chunk-set hash into Qdrant** and re-index. Two ordering constraints
  found while probing: `create_collection` no-ops when the collection exists, so
  the hash must be written on every run; and it must be written *after*
  `index_chunks` verifies its count, or a partial index advertises a snapshot it
  does not hold.
- **Tests for `chunk_store.py`, `docling_tree.py` and `get_articles_from_dictionary`** —
  all verified by hand today, none guarded by the suite.
- **Finish the sufficiency judge** — stage C, verdict derivation, runner,
  calibration, tests. Untouched today.
- `_looks_truncated` still false-flags article 99; `_clean_title` still leaves
  double spacing in titles 12, 60, 89; `src/config.py` `writer_model[1]` still
  raises `KeyError`. All carried unchanged.
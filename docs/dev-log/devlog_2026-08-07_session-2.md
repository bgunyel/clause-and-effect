# Devlog — 2026-08-07 · session 2

**Branch:** `dev-02`, 51 commits ahead of `main` · `6c25a43` → `6c25a43`
(**no commits this session**; all work is in the working tree)
**Theme:** the refactor named as the next session's first item was started, and
opening the `index_chunks` seam turned into a package reorganization — `chunking/`
created, `Chunk` retyped, the chunker lifted out of the parser. The session ends
mid-refactor by design
**Tests:** 180 → **124 passed, 58 failed**. The failures are unfinished work, not
regressions; they are enumerated below
**Corpus / snapshot / index:** untouched. `a231f919` is still the newest snapshot
and `compliance_docs` still holds exactly it

---

## The write primitive was split from the reconcile step

Bertan's instruction opened the session: rename `VectorDatabase.index_chunks` to
`embed_and_upsert_chunks`, and introduce a new `index_chunks` taking the same
input and calling it.

The split names two different questions. `embed_and_upsert_chunks` touches only
the points its chunks map onto and decides nothing about the others; what the
collection holds *besides* them is `index_chunks`'s concern. Every existing test
was repointed at `embed_and_upsert_chunks` rather than left on the wrapper —
they assert batching, duplicate rejection, digest stamping and count
verification, and leaving them on `index_chunks` would have silently widened
what they exercise as orchestration moved in.

Two tests were added for the seam and both were mutation-checked:

| mutation | result |
|---|---|
| `index_chunks` swallows the return value | both new tests fail |
| `index_chunks` reaches the write by another route | only the call-assertion test fails |

The second is why the delegation test exists: a behavioural test alone is
satisfied by any second write path, and the digest is derived inside the
primitive precisely so that there is only one. 182 passing at that point.

## Bertan moved the orchestration in, and the assistant's review found nine items

`create_collection`, the reconcile read, orphan pruning, the stale check and the
metadata write all moved from `index_documents.py` into `index_chunks`. Two
load-bearing orderings survived intact — upsert-before-delete, so a dead run
leaves a superset rather than a deficit, and `find_stale` before metadata, so
nothing advertises a snapshot it only partly holds. Dropping `chunk_set_hash`
from `vector_db.py` is a real layering improvement, and sourcing the model name
from `embedding_generator.get_model()` rather than `settings.EMBEDDING_MODEL`
records what was actually used rather than what config claimed.

The three findings that matter:

- **`--prune` became dead.** The flag is still declared and nothing reads it;
  `index_chunks` now prunes unconditionally. The 2026-08-07 session-1 entry
  records pruning as deliberately gated — 196 points was the first destructive
  use, behind an opt-in. Orphans are also no longer reported on the index path,
  so the destructive step is the one step that prints nothing.
- **`indexed_at` is computed twice**, once inside `index_chunks` and again in the
  script for the read-back comparison. Two independent clock reads formatted to
  whole seconds must be equal for the check to pass, so it fails whenever the
  metadata round-trip crosses a second boundary. A verification that fails at
  random is worse than none. The deeper problem: the read-back asked *"did the
  server store what we sent?"* and now asks *"what we would have sent if we
  rebuilt the dict"*.
- **The metadata schema lives in two places** — `index_chunks` and
  `_build_metadata` build the same keys independently, against a store that
  *merges* rather than replaces. A divergence in key names leaves the loser on
  the collection forever, advertising a value nothing produced. This is the
  hazard `_build_metadata`'s own docstring was written to warn about.

Six smaller items were recorded: an unbounded `while` loop around the delete
whose retry cannot make progress its first pass did not; `kwargs['snapshot']`
raising `KeyError` rather than defaulting; docstrings still promising a derived
digest while the signature takes a caller-supplied one; `-> None` annotations on
methods that return values; bare `Exception` where the codebase raises
`ValueError`, leaving `main()` half-raising and half-returning exit codes; and a
commented-out reconcile report left as a bare string expression referencing names
no longer in scope.

Bertan then introduced a `ChunkSetMetadata` model, which addresses the `**kwargs`
half. The rest is open.

## The chunking package, and a 9.78s dataclass

Bertan proposed a `chunking` package holding `chunk_store.py` and the chunking
logic, including `article_to_chunks`. The assistant agreed and measured the
argument that had not been stated:

```
from src.clause_and_effect.parsers import Chunk   →  9.78s
stdlib deps of chunk_store                        →  0.02s
```

`Chunk` was a three-field dataclass defined in `parsers/base_parser.py`, which
imports docling at module scope. `vector_db`, `chunk_store` and five test modules
all imported it, so every one of them paid for the OCR stack to obtain a
dataclass. That is the *"`__init__.py` imports the world"* backlog item, and
moving `Chunk` is what makes it reachable. Two further arguments: `chunk_store.py`
sat at the package root while everything else lives in a subpackage, and
`article_to_chunks` *was* the chunker — the 1000-char budget, the `Article N(M):`
header form, paragraph splitting and the whole metadata schema — disguised as a
parser method, which is exactly what the deferred hierarchy-aware chunker
replaces.

**The assistant recommended deferring the move until the `vector_db` refactor was
green; Bertan judged it the right moment and proceeded.** The advice was also
inconsistent with the assistant's own observation one turn earlier, that
`generate_chunks.py` never imports `vector_db` and so the digest check was
available regardless of the suite's state. That check is precisely what verified
the rest of the session.

`chunk_store.py` was moved with `git mv` and its four import sites repointed —
including the import string passed to the subprocess in the `PYTHONHASHSEED`
determinism test, which a module-path search does not reach. Digest confirmed
unmoved: `a231f919`, 368 chunks, duplicate guard declining to write.

## Bertan retyped the chunk, and the package stopped importing

`Chunk` became a pydantic model with `metadata: ChunkMetadata`; `ArticleMetadata`
and `ChunkMetadata` were introduced; `topics` was dropped and `paragraph` renamed
`paragraph_number`; `article_to_chunks` and `_split_into_paragraphs` moved into a
new `Chunker`; `parse()` now returns articles rather than chunks.

The package then could not be imported at all — **the full suite failed
collection with 6 errors**:

```
chunking/__init__ → chunk_store → parsers/__init__ → base_parser → chunking/__init__ (partial)
```

The cycle was held closed by two lines that were both already dead.
`base_parser.py` imported `Chunk` and never used it — the only remaining mention
was in a docstring — and its sole purpose was feeding the re-export in
`parsers/__init__.py`. Deleting both, and pointing `chunk_store` at `.chunk`,
breaks the cycle with nothing else to change. Eight `Chunk` importers were
repointed at the `chunking` package.

Collection restored: 182 collected, 0 errors, **124 passed / 58 failed**. The
failures were not caused by the fix; the import error had been hiding all of
them.

## `jurisdiction` and `effective_date` are not free parameters

Reviewing the new models, the assistant proposed bundling `regulation`,
`jurisdiction` and `effective_date` into a descriptor on the `Chunker` rather
than repeating them on every `ArticleMetadata`. Bertan asked the sharper
question the assistant had not: *if the regulation is GDPR, the other two are
fixed — do they need to be fed separately?*

They do not. `regulation → (jurisdiction, effective_date)` is a lookup, and the
signature as proposed would have accepted `regulation="GDPR",
jurisdiction="US"` and written that contradiction into 368 payloads. A frozen
`Regulation` model with a `GDPR` constant now carries all three, and
`_create_chunk_id` reads `self.regulation.name.lower()` — the same string that
lands in the payload, so an ID reading `gdpr_…` beside a payload naming another
regulation is not a reachable state.

Two facts were recorded against the field rather than assumed. `effective_date`
holds the date of *application* (2018-05-25), not entry into force
(2016-05-24) — a distinction the field name does not make, and an argument for
documenting it once on a named descriptor instead of copying a bare string onto
every article. And single-valued applicability is a property of GDPR, not of
regulations generally; instruments that phase in by chapter would need
per-article dates.

### Chunk IDs verified against the archive, not against the suite

The change touches the derivation of every chunk ID, which derives every Qdrant
point ID. Verified by running the new `Chunker` over all 99 articles and
comparing against the 368 IDs recorded in `a231f919`, read as raw JSON because
`chunk_store` cannot yet load a typed `Chunk`:

```
recorded : 368      produced : 368
identical (order included) : True
chunks whose text changed  : 0
```

Order-identical rather than merely set-identical, so the existing collection
stays keyed exactly as it is. The eventual digest change is therefore driven
purely by metadata: `paragraph` and `topics` removed, `paragraph_number` added —
all from Bertan's retyping, none from the `Regulation` change, which is
digest-neutral on its own.

---

## Decisions

- **`index_chunks` is the reconcile step; `embed_and_upsert_chunks` is the write
  primitive.** Tests aim at whichever owns the behaviour they name.
- **`chunking` is a package**, holding `chunk_store`, `Chunk`, the `Chunker` and
  the regulation constants. Deliberately left out of the top-level `__init__.py`
  star-imports, since tying it to the eager-import problem defeats the point.
- **`Chunk` is a pydantic model** with typed metadata, at Bertan's direction.
  `topics` is gone — it was recorded as a toy in session 1.
- **Regulation-level constants live on the `Chunker`**, in a frozen `Regulation`
  model, with one name feeding both the chunk ID and the payload.
- **The package move went ahead over the assistant's sequencing advice**, at
  Bertan's direction.
- **A red suite is acceptable mid-refactor**, with each step verified by targeted
  checks — import probes, chunk IDs against the recorded snapshot — rather than
  by the suite.

## Mistakes made this session

Attributed, per this log's convention. All are the assistant's unless stated.

- **Proposed bundling three fields without noticing that two are derivable from
  the first.** The descriptor suggestion treated `regulation`, `jurisdiction`
  and `effective_date` as three co-equal parameters; Bertan asked whether they
  are independent at all, and they are not. The assistant had already written
  that the trio "cannot contradict itself" once bundled, which was wrong — a
  bundle of three free strings contradicts itself exactly as easily.
- **Recommended deferring the package move on sequencing grounds**, one turn
  after establishing that the verification that mattered did not depend on the
  suite being green. Bertan overrode it; the session's verification ran through
  the snapshot, as the assistant's own observation implied it could.
- **The `--prune` regression was found only on review, not on writing.** The
  gate was recorded as a decision in the session-1 entry the assistant wrote the
  day before, and its removal was not flagged until a second pass over the diff.

Bertan's catches again set the session's direction: the split that opened it, the
package proposal, and the question about regulation constants that turned a
three-field bundle into a one-field lookup.

---

## State handed to the next session

| | |
|---|---|
| Corpus | 99 articles, `sha 85fba45c40b6…` — unchanged |
| Chunk snapshot | `chunks_2026-08-07_081627_a231f919`, 368 chunks — unchanged on disk, **not currently readable by the code** |
| Qdrant | `compliance_docs` — 368 points, 0 orphans / 0 missing / 0 stale — untouched |
| Golden set | 285 exact · 34 normalized · 114 ungrounded (carried, not re-measured) |
| Sufficiency judge | unchanged — stages A and B only (`e2ebef1`) |
| Tests | **124 passed, 58 failed** · 54 `ValidationError`, 2 `AttributeError`, 2 `AssertionError` |
| Commits | **none** — the entire session is uncommitted working tree |

**Open, in the order the refactor needs them:**

- **`chunk_store` was never adapted to the typed `Chunk`.** Three sites treat
  metadata as a dict: `_canonical_rows:65` and `write_snapshot:263` pass a model
  to `json.dumps`; `build_manifest:206` calls `.get` on it. `chunk_set_hash`,
  `write_snapshot` and `build_manifest` are all broken, and this is the module
  the eval baseline rests on. **First item.**
- **Old snapshots are unreadable, and fail misleadingly.** `read_snapshot:287`
  lets pydantic silently drop the unknown `topics` and `paragraph` keys, then the
  re-hash at `:295` raises *"chunk set does not match its manifest"* — the
  message written for tampering or truncation. Either the archive is versioned or
  old snapshots are formally retired with an error that says which.
- **The chunker is not wired.** Nothing constructs `ArticleMetadata` or
  instantiates `Chunker`; `generate_chunks.py:153` still calls the removed
  `article_to_chunks`. `CHAPTER_TITLES` and `_extract_topics` are dead pending
  it. `vector_db.py:220` still puts a model into the Qdrant payload and needs
  `.model_dump()`.
- **A new baseline snapshot and a re-index**, once the above land. Text is
  byte-identical, so the digest moves on metadata alone — but it does move, and
  every point in the collection goes stale.
- **The nine review items on `index_chunks` / `index_documents.py`**, of which
  unconditional pruning and the double `indexed_at` are the two that change
  behaviour rather than tidiness.
- **`parse()` docstrings still describe chunks** in both `base_parser` and
  `gdpr_parser` while returning `List[Dict[str, Any]]`.
- **Gold chunk IDs (P0)** — still unblocked, but do not pin them until the new
  baseline digest exists.
- **The Makefile**, promoted at Bertan's direction in session 1 and not yet
  started.
- `_looks_truncated` still false-flags article 99; `_clean_title` still leaves
  double spacing in titles 12, 60, 89; `src/config.py` `writer_model[1]` still
  raises `KeyError`. All carried unchanged.
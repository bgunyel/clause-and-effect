# Devlog — 2026-08-09 · session 1

**Branch:** `dev-02`, 62 commits ahead of `main` (was 54) · `d911c2a` → `2bfdc50`
(8 commits this session, pushed; a further block of `vector_db` work is
uncommitted in the tree by the convention that leaves it there for review)
**Theme:** the chunking refactor was finished and the `vector_db` one was
carried through a review, item by item, with Bertan deciding each. Three of the
session's better outcomes came from him rejecting or sharpening what the
assistant proposed
**Tests:** 124 passed / 58 failed → **217 passed / 24 failed / 5 xfailed**.
Eight of nine test modules are green; every remaining failure is
`test_vector_db.py`
**Corpus / snapshot / index:** untouched. `a231f919` is still the newest
snapshot and `compliance_docs` still holds exactly it. The new digest is known
(`5caac594…`) but **not written** — see the open items

---

## Import cost: 15.6s → 0.124s, and the fix was one Bertan had already made

Bertan emptied `src/clause_and_effect/__init__.py`. The star-imports of
`.agents`, `.parsers` and `.retrieval` had made every submodule import pull
docling, langchain, openai and qdrant — and keeping `chunking` *out* of those
star-imports had never helped, because Python executes the parent package
before any subpackage. That detail is why the 2026-08-07 session recorded the
problem as solved when it was not.

Tracing the residue found `src/config.py` importing `ai_common` at module scope
for two enums used only inside `get_llm_config()`, which no chunking script ever
calls. The chain: `ai_common/__init__` imports six langchain provider SDKs,
`langchain_core.language_models.base` does an unguarded module-scope
`try: from transformers import GPT2TokenizerFast`, and transformers imports
torch. **Chunk generation was loading torch to read two directory paths.**

`get_llm_config` moved to `src/llm_config.py`. A lazy import would have bought
the same seconds; a module boundary is not undone by the next edit.

| | before | after |
|---|---|---|
| `import …chunking` | 15.6s | 0.124s |
| `import src.config` | 8.34s | 0.267s |
| `import …generate_chunks` | 13.4s | 0.254s |

`ai_common` is Bertan's own library and at least six of his projects consume it,
so the findings were written up in `docs/todo.md` and deferred rather than
fixed: the eager `__init__`, the six provider SDKs that make it unimportable
unless all six are installed, and the upstream transformers leg. Note that
`src/llm_config.py` importing `from ai_common.enums import …` **buys nothing
today** — measured identical — and becomes free the moment the first is fixed.

## The chunking package was finished

`chunk_store` had never been adapted to the typed `Chunk`. Four sites treated
metadata as a dict, not the three the handover recorded — the fourth was in
`generate_chunks._check_chunks`.

`_canonical_rows` and `write_snapshot` built the row dict from two independent
literals; they are now one `_row`, because the hash is taken over that shape and
the file is written in it, and `read_snapshot` re-hashes what it loaded to prove
they agree. Two copies of the same idea would have made a freshly written
snapshot fail its own tamper check.

`build_manifest` now takes the chunker and records `type(chunker).__name__` and
its regulation. The field it replaced read `{"class": "GDPRParser", "method":
"article_to_chunks"}` for two days after that method ceased to exist — the
hazard the module docstring warns about, demonstrated by the docstring's own
neighbour.

### `LegacySnapshotError`, and what it turned out to be for

Introduced so a pre-typing snapshot stops being reported as tampering. Pydantic
ignores unknown keys, so `a231f919` loaded *successfully* with `topics` and
`paragraph` discarded and then failed the hash check with the message written
for a hand-edited file.

Writing the tests found the check is **load-bearing for integrity, not only for
the message**. The same silent discarding hides real tampering: add an unknown
key to a chunks file and, without the check, pydantic drops it, the
reconstructed chunks are identical to the originals, the re-hash matches the
manifest, and `read_snapshot` returns a `Snapshot` as though nothing happened.
Verified by disabling only that branch. **The hash cannot catch an edit the
loader throws away before hashing.** `_load_chunks`'s docstring now says so, and
says not to relax it as over-strict.

## Where Bertan's calls changed the outcome

**The key-order test.** The assistant proposed deleting
`test_chunk_set_hash_ignores_metadata_key_order` as unfalsifiable — a typed
model normalizes field order, so no change to `chunk_set_hash` can make it fail.
Bertan kept it, as a tripwire against losing that normalization silently. The
test now says exactly that, and says what it stopped protecting: dropping
`sort_keys=True` still moves every digest, but only the golden pin would notice.
Measured: removing `sort_keys` produced **zero** new failures until the pin was
repaired.

**The cross-process seed.** The assistant framed the choice as `random` (broad,
irreproducible) versus fixed seeds (reproducible, narrow), having anchored on
the env var's two modes. Bertan dissolved it: generate the integers ourselves
and pass them in. The child sees a fixed seed, we know which one. This matters
because CPython never exposes the seed `PYTHONHASHSEED=random` generates —
`sys.hash_info.seed_bits` is the width, not the value — so a failure under it is
irreproducible *in principle*. Verified: with a `set()` injected into the
canonical path, the test failed on 1 of 5 seeds and named it, and replaying that
seed reproduced the digest exactly. His time-seeding suggestion was the one part
that did not survive measurement — two processes started in the same second draw
identical seeds, where the default `os.urandom` seeding does not.

**The post-write count check.** The assistant flagged that
`embed_and_upsert_chunks` compared the collection's *total* point count against
`len(chunks)`. Bertan stated the failure precisely — 10 pre-existing points plus
13 of 15 written is 23, and `23 >= 15` passes while two chunks are missing — and
said the check should be scoped by `chunk_set_id`. It now is, and goes one step
further: the point IDs are known, so it compares by identity and names which
chunks did not land.

**Pruning.** Bertan: not optional. The `--prune` flag is gone. A collection
holding points from a corpus that no longer exists fails the invariant rather
than partly meeting it.

**Logging.** The assistant proposed reporting the destructive step, and Bertan
accepted the call but rejected `print`. Library modules now use
`getLogger(__name__)` with a `NullHandler` on the package root and configure
nothing; scripts call `src.logging_setup.setup_logging()`. 45 prints converted.

## The paragraph-splitting defect, and what the backlog already knew

Explaining `Chunker` to Bertan produced a long analysis of
`_split_into_paragraphs` splitting on `\d+\.\s+`, which cannot tell `22. ` in
*"…Articles 15 to 22. In the cases…"* from `2. ` opening a paragraph. Most of it
was **already in `docs/todo.md`**, recorded more precisely than the
rediscovery — the ten articles, the "same bug one level up" framing against
`_ARTICLE_HEADER`, Article 4.

What was new is the quieter class: when the false match ends its line, `\s+`
swallows the newline and the empty segment is dropped, so the paragraph count
stays *correct* and the sentence silently loses its citation, ending "in
accordance with Article" with nothing after it. **32 sites across 26 articles**,
sixteen of which appear on no other list, because count-based checks cannot see
them.

Also recorded: the structure is not missing, it is built and then discarded.
Article 12(2) is a single `list_item` in `gdpr.docling.json` with its text
unbroken, and `_build_units` already yields the correct 8 units. The tree gives
**319 numbered units** against the chunker's **330 chunks**. `_render_units`
flattens them, the corpus schema has nowhere to keep them, and the chunker
re-derives from that rendering what the pipeline held two functions earlier.

**Bertan's decision:** not to be fixed before the eval pipeline exists — not
because the fix is unclear, but because it has to be shown not to have side
effects, and only the eval pipeline can show that.

## The `vector_db` review, item by item

Eight items raised, eight resolved, each decided by Bertan before it was
applied.

- **The payload carried a pydantic model.** The assistant repeated the
  handover's claim that this crashes; testing showed pydantic serialises it fine
  on REST. It does fail on gRPC (`payload_to_grpc` rejects a `BaseModel`), so it
  is latent rather than broken. Now `.model_dump()` — byte-identical on the
  wire, explicit rather than incidental, consistent with `chunk_store._row`.
- **The unbounded `while` around the delete.** A retry that repeats an identical
  request cannot make progress its first pass did not. Replaced with delete →
  re-check → raise. `delete_points`' docstring claimed to return "how many were
  removed"; it returns how many were *requested*, and cannot do better — Qdrant's
  `UpdateResult` carries no tally. That inaccuracy is what the retry was built on.
- **`--prune`** removed, as above.
- **Bare `Exception` × 2** replaced with a taxonomy rather than a substitution:
  `IndexVerificationError(RuntimeError)` for the three post-condition failures,
  `ValueError` kept for duplicate chunk IDs, which is a genuine argument fault.
  Deliberately **not** a `ValueError` subclass, unlike `LegacySnapshotError`.
- **`_build_metadata` deleted.** Bertan pushed back on the assistant's claim that
  the read-back "verified nothing", and was right: five of nine keys pass through
  `ChunkSetMetadata` and genuinely round-trip. The defect was narrower — the four
  keys the script never sends, of which `indexed_at` was read from the clock on
  both sides of an equality test and so failed at random. `index_chunks` now
  returns what it wrote.
- **The digest-mismatch check was unreachable.** `read_snapshot` already hashes
  the chunks and raises on disagreement, so the script's recomputation could not
  differ. It was a real comparison when `index_chunks` derived the digest; both
  sides now read the same manifest field. Removed rather than reworded — a
  safeguard that cannot fire invites trust it cannot earn.

---

## Decisions

- **Pruning is not optional.** The `--prune` gate recorded on 2026-08-07 is
  withdrawn.
- **The digest is caller-supplied, and that is the stronger design.** The
  recorded property "derived inside `index_chunks`" is superseded: the digest a
  point must advertise is the one the snapshot recorded, and only the caller can
  compare the two. `index_documents` derives it and refuses to index if it
  disagrees with the manifest — a check re-deriving inside could not make.
- **All output goes through logging.** Libraries configure nothing; scripts call
  `setup_logging()`. `RichHandler` was tried and rejected — it wraps to console
  width and re-indents, breaking a `chunk_set_sha256` across two lines mid-hash.
- **The paragraph-split defect waits for the eval pipeline**, so a fix can be
  shown to have no side effects.
- **Unfalsifiable tests are kept as tripwires** where they guard a guarantee that
  could be lost silently, and say so in their docstrings.

## Mistakes made this session

All the assistant's unless stated.

- **Claimed the payload model "needs `.model_dump()`" because it crashes.** It
  does not, on the transport in use. Repeated from the handover without testing.
  The real finding — latent on gRPC — is narrower and was only found by checking.
- **Reached for `exclude_none` as the motivating failure** for the field-wise
  hash test. It cannot conflate anything, since a `None` field is absent from
  both dumps. The mechanism is an *excluded* field.
- **Said the metadata read-back "verified nothing about the write".** Too broad;
  Bertan corrected it. Five of nine keys do round-trip.
- **Wrote a provenance test that passed against the bug it existed to catch.**
  `_TEST_REGULATION` was deliberately not `GDPR` so a hardcoded string could not
  pass — and then the same reasoning was not applied to `type(chunker).__name__`,
  where the test's plain `Chunker` produced exactly the literal a regression
  would reintroduce. Found by mutation, fixed with a subclass.
- **Framed the cross-process seed choice as a dichotomy** that was not one.
- **Proposed `RichHandler` without rendering anything through it.**

---

## State handed to the next session

| | |
|---|---|
| Corpus | 99 articles, `sha 85fba45c40b6…` — unchanged |
| Chunk snapshot | `a231f919`, 368 chunks — unchanged; **new digest `5caac594…` computed but not written** |
| Qdrant | `compliance_docs` — 368 points, untouched all session |
| Golden set | 285 exact · 34 normalized · 114 ungrounded (carried, not re-measured) |
| Sufficiency judge | unchanged — stages A and B only (`e2ebef1`) |
| Tests | **217 passed, 24 failed, 5 xfailed** · all failures in `test_vector_db.py` |
| Commits | 8 pushed (`3fdcae9`…`2bfdc50`); the `vector_db` block is uncommitted |

**Open, in order. Bertan set the first item explicitly at session end: the next
session begins with `tests/test_vector_db.py` and starts nothing else first.**
The vector_db refactor is unverified until they run, and it is the last thing
between here and a re-index.

- **`test_vector_db.py` — 24 failures, three layers deep. FIRST ITEM.** The stale `_chunks`
  helper masks everything: repairing it alone takes 24 → 23 and reveals 23
  `TypeError`s from the changed signatures. Beyond the repoint, seven tests need
  rewriting rather than fixing —
  `embed_and_upsert_chunks_derives_the_digest_from_what_it_writes` asserts a
  contract that was deliberately inverted;
  `reports_the_stored_count_not_the_input_count` tests a check that no longer
  exists; `raises_when_points_are_lost` expects `ValueError` rather than
  `IndexVerificationError`; `warns_about_points_belonging_to_no_chunk` uses
  `capsys` where the warning is now a log record and wants `caplog`;
  `chunk_payload_carries_identity_and_metadata` should pin that the payload's
  metadata is a `dict`, or it passes equally against the model form.
  **The fake Qdrant client also needs an in-memory point store**, because the
  post-write check now reads `stored_points()` after writing — otherwise every
  write test fails for a reason unrelated to what it tests.
- **The new baseline snapshot and a re-index.** Blocked only on a clean tree:
  `_report` refuses to vouch for a snapshot taken against a dirty one, and the
  digest moves on metadata alone, staling all 368 points.
- **Gold chunk IDs (P0)** — pinnable once the new baseline digest exists.
- **The sufficiency judge**, stage C onward.
- **`ai_common`** — deferred; full findings in `docs/todo.md`.
- **The Makefile**, promoted at Bertan's direction on 2026-08-07, still not
  started.
- `_looks_truncated` still false-flags article 99; `_clean_title` still leaves
  double spacing in titles 12, 60, 89 — visible in all nine of Article 12's
  chunk headers; `src/llm_config.py` `writer_model[1]` still raises `KeyError`.
  All carried unchanged.
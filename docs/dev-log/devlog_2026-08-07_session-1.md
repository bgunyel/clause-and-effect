# Devlog — 2026-08-07 · session 1

**Branch:** `dev-02`, 51 commits ahead of `main` · `b6a826d` → `79c7c49`
(15 commits this session; the devlog commit follows this entry)
**Theme:** Bertan reset the priority to the evaluation pipeline and set the rule
that governs it — the algorithm need not be perfect, the eval must be — and the
session then spent itself finding that the eval infrastructure written the day
before was wrong in three places
**Tests:** 81 → **180**, all passing
**Gate:** not re-run. The corpus is byte-identical (`sha 85fba45c40b6…` before
and after), so 285 exact / 34 normalized / 114 ungrounded, 319 of 433 clean,
carries over by inference rather than by measurement
**Index:** `compliance_docs` — 368 points, 0 orphans, 0 missing, 0 stale,
advertising `a231f919…` (was 563 points, `metadata=None`)

---

## The priority was wrong, and Bertan corrected it

The 2026-08-06 entry closed by naming the hierarchy-aware chunker "the top
blocking item", and `todo.md` had it marked blocking with the P0 gold-chunk-ID
work explicitly blocked *on* it. Bertan rejected that framing: the chunker is an
algorithm improvement for a future iteration, and the highest-priority work is
**getting the evaluation pipeline ready and producing the first numbers from the
RAG system as it stands**.

The order he set:

1. Generate the first chunk snapshot
2. Push the chunk-set hash into the vector DB, and make every point in a
   collection belong to that collection's chunk set
3. Tests
4. Continue the sufficiency judge

Steps 1–3 were completed. Step 4 was not started.

### The rule underneath it

Asked to explain the reasoning, Bertan stated the governing philosophy:

> The algorithm or pipeline we are developing does not need to be perfect or the
> best. The evaluation pipeline on its own has to be perfect and flawless. Only
> after we have a flawless evaluation pipeline can we safely and confidently
> improve the algorithm or the actual product.

`evaluation-plan.md` §1 already said the eval framework is the durable asset and
the pipeline disposable, but that is a claim about *lifespan*, not about how
correct each has to be. The asymmetry is the sharper statement and it was
recorded as governing, above the four existing principles (`b6a826d`).

The reasoning is asymmetric cost. A defect in the product costs one bad answer —
visible and local. **A defect in the eval costs every decision taken on its
output**, including the ones that looked like progress and the ones that stopped
work because something "measured fine". Four consequences were drawn out because
they decide real work: eval components are tested while the generator and agent
staying untested is an accepted state rather than matching debt; every gate is
mutation-checked; judges report agreement with human labels before their verdicts
are used; and the golden set is part of the eval rather than an input to it.

The rest of the session is best read as that rule being applied to code written
the day before, and repeatedly finding it wanting.

---

## The first snapshot could not be written until two defects were fixed

`generate_chunks.py --dry-run` reported the tree DIRTY at one path — `v.lock` —
while `git status` reported it clean. Both halves were wrong.

**The manifest recorded a path that does not exist.** `run()` returned
`result.stdout.strip()`, correct for `rev-parse` and wrong for
`status --porcelain`, whose first column is the index status and is a *space* for
a worktree-only change. `" M uv.lock"` stripped to `"M uv.lock"`, and the
`line[3:]` slice then ate a character. Only the first line, and only when its
index column is blank — which is the ordinary unstaged-modification case.

This is the assistant's code from 2026-08-06, and the previous entry records it
as verified by hand "across six tree states". Those six states did not include a
first-line unstaged modification. **`git_dirty_paths` is the field that decides
whether a snapshot is a legitimate baseline** — Bertan approved recording paths
precisely because the repo-wide boolean cannot separate an uncommitted devlog
from an uncommitted `gdpr_parser.py` — and a path nobody can look up separates
nothing.

**Writing the tests surfaced a second defect the assistant had not suspected.**
Plain `--porcelain` C-quotes any path containing a space or non-ASCII byte, so a
manifest would record `'"a file.txt"'` with the quoting as part of the name.
Latent in this repository, and the same defect class, so `status` is now read
with `-z`, which never quotes. Renames arrive as two NUL-separated records and
are rejoined as `old -> new` (`c67e266`).

Mutation-checked: against the pre-fix code **6 of the 10 new tests fail**, and the
4 that pass are exactly the cases the bug never touched.

### The lock had been stale for a session

The dirty tree was also real: `pyproject.toml` has declared `docling-core>=2.87.1`
since `fabe4ba` (2026-08-06) without the lock being updated, so `uv run`
silently re-resolved and dirtied the tree at the one moment a clean one was
required. Re-resolution changed **no package versions**; the substantive lines
register `docling-core` as a direct dependency (`c6d9578`).

Bertan noted this is the case he has been making for the Makefile's
`upgrade-safe` target and a global cache, and asked that it not be postponed much
longer. Two further findings were recorded against that item: **a plain
`uv sync` uninstalls pytest**, because `test` is a PEP 735 `[dependency-groups]`
entry rather than `dev`, so a `make test` that does not request the group can
report success over a tree that cannot run tests at all; and a lock-consistency
check would have caught the drift the day it happened.

### The snapshot

`chunks_2026-08-07_064658_157d4d38`, 368 chunks, 203,964 chars, generated at
`c67e266` against a clean tree with `git_dirty: false` (`2a7811a`). Regenerating
under a randomized `PYTHONHASHSEED` in a separate process reproduced the digest,
and the duplicate guard declined to write a second copy.

---

## The index held 196 points from a corpus that no longer exists

Probed read-only before anything was built. `compliance_docs`: **563 points,
`config.metadata=None`**, of which 367 matched the snapshot by point ID, **196
matched nothing**, and — not predicted — **one snapshot chunk was absent
entirely**: `gdpr_article_79`.

That absence is the footnote decision surfacing two layers down. Dropping
Article 79's footnote pushed the article under the 1000-char chunk budget, so it
stopped splitting into paragraphs and became a single `article` chunk with a new
ID. The old `gdpr_article_79_para_*` points were still there, orphaned. The
2026-08-06 estimate of "~195 orphans" was close but was an estimate; **196** is
measured.

`d7db4f9` built the index side. Two invariants, both violated by the live
collection:

- **the collection advertises the chunk set it holds** — `set_collection_metadata`
  writes on *every* index run, since `create_collection` no-ops when the
  collection exists;
- **every point belongs to that chunk set** — `find_orphans` compares by derived
  point ID rather than by payload `chunk_id`, so a point with a missing or
  corrupt payload is still identifiable.

`index_documents.py` was rewritten to index **a snapshot**, never a fresh
chunking: re-chunking there would embed a chunk set no file holds, so the hash
recorded on the collection would describe nothing.

**Ordering is load-bearing.** Metadata is written last, after the count is
verified and after orphans are gone, and a run that leaves orphans exits non-zero
writing nothing — a collection advertising a snapshot it only partly holds is
worse than one advertising nothing, because the first is trusted and wrong.

The metadata schema was fixed in full up front because Qdrant **merges** rather
than replaces. `embedding_model` and `vector_size` are included, closing a gap
recorded on 2026-08-06: the chunk hash does not cover the model, so identical
chunks through different models would give different retrieval while both
collections honestly reported the same `chunk_set_sha256`.

Bertan confirmed the metadata independently in the Qdrant cloud console. That
read established something the assistant's own check could not: **the types
survived** — `chunk_count` and `vector_size` as JSON numbers, `chunker_tree_dirty`
as a boolean. The script's read-back compares `str(stored) == str(sent)` and is
type-blind by construction, so it would have passed just as happily against
coerced strings. It matters most for `chunker_tree_dirty`, where the string
`"false"` is truthy.

---

## Bertan read one indexed point, and it produced two findings

He inspected the payload of `009d4d33-9b56-56d9-bf61-be7fde25993c`. Verified
against the snapshot: the point ID derives correctly from
`gdpr_article_78_para_3`, and the text and metadata are byte-identical. The
content is also legally correct — GDPR Article 78(3) is exactly that sentence.

What the payload exposed was the **chunk header**.

### `Article 78.3:` is not a GDPR citation

EU convention is `Article 78(3)`; `78.3` reads as a decimal. Measured: it opened
**330 of 368 chunks** — every paragraph chunk. Not cosmetic, on two counts. The
header is inside the embedded text, so it is part of what is retrieved against;
and it is what the generator sees as context, so the wrong notation can propagate
into generated citations. The planned Citation article-match scorer would have
been matching a form the regulation never uses.

Bertan fixed it in `gdpr_parser.py` (`d9ed54b`).

### `topics` is close to information-free

Measured over the snapshot:

```
data_subject_rights  297  (81%)     consent    90  (24%)
processing           260  (71%)     breach     49  (13%)
transfer             122  (33%)     deletion   33   (9%)
                                    general    36  (10%)
distinct topic sets: 24 over 368 chunks
```

A tag on 81% of chunks cannot discriminate. Two causes: `_extract_topics`
substring-matches broad keywords — `"rights"`, `"access"`, `"processing"` —
against a regulation about exactly those things; and it is computed once per
article on the full article text and copied into `base_metadata`, so every
paragraph of an article inherits identical topics and the field never
discriminates *within* an article. Article 78(3), a rule about which court hears
proceedings, is tagged `data_subject_rights`.

The assistant hypothesised that the repeated article title was driving this and
checked rather than asserted: **only 5 of 368** chunks have topics explained by
the title alone. The hypothesis was wrong; the keyword breadth is the cause.

Bertan's decision: the current version is a toy and deserves a deeper look later.
`chapter: "8"` where the regulation says Chapter VIII was judged a tiny detail
for the far future.

---

## The reconcile procedure, and what it missed

Bertan asked the question that produced the session's most consequential change:
the chunks file carries no chunk-set identity, so **how are orphans detected at
all?**

They are detected by set difference on derived point IDs — the snapshot is the
authority, the collection is compared against it. But the question exposed the
limit. **Point IDs derive from chunk IDs alone, so a chunk whose *text* changes
keeps its point.** `find_orphans` reports a perfect match while every stored
vector is embedded from the old text. His own citation fix is exactly that shape.

He then set out the procedure in full — compare the two point-ID sets, upsert the
intersection and the additions, delete the remainder, then record the metadata —
and asked what it misses.

Three answers. Insert and update are the same upsert to Qdrant, so the split is
for the operator, not the client. Upsert-before-delete is the deliberate order,
because a run that dies leaves a superset rather than a deficit. And the real
gap: **the guarantee holds only for completed runs.** If a run dies midway every
ID still matches and metadata was never written, so the collection quietly
advertises the previous chunk set while holding a mix of two — not "unknown", but
trusted and wrong.

`6f4df7a` stamps `chunk_set_sha256` into every point's payload. The digest is
derived inside `index_chunks` from the chunks being written rather than passed
in, so a point cannot advertise a chunk set it is not part of, and
`index_documents` cross-checks it against the manifest's independently computed
hash. `--check` now reports staleness as a fourth condition beside membership,
absence and the advertised hash.

**The 2026-08-06 backlog entry had already described this mechanism** — *"writing
the chunk-set hash into each point's payload makes orphans exactly the points
whose hash is not current"* — and the assistant implemented collection-level
metadata only, following Bertan's stated preference for a collection property
without noting that the two answer different questions. Bertan had to re-raise it.

Verified live before re-indexing: `orphans: 0`, `missing: 0`, advertised hash
**equal** to the snapshot's — all three prior conditions satisfied — and
**`stale: 368`**. The old design would have called that a match.

### The new baseline

`chunks_2026-08-07_081627_a231f919`, 368 chunks, 204,294 chars (+330: exactly one
per paragraph chunk, `.` becoming `()`), generated at `6f4df7a` (`1802a72`). The
snapshot diff states the whole argument in one line:

```
IDs added 0, removed 0, text changed 330
```

Re-indexed; the collection reports 368 points, 0 orphans, 0 missing, 0 stale.

---

## Tests: 81 → 180, and four mutations that survived

`efd2f09` covered `chunk_store` and `_check_chunks`; `50d8eb8` covered
`docling_tree` and `GDPRParser.get_articles_from_dictionary`, which had no
coverage at all. The tree tests use synthetic documents, one structural hazard
each, every one mirroring a shape verified against the real export. The `visited`
guard gets its own tests precisely because the real export **cannot** exercise it:
it has no nesting anywhere, so nothing there would notice its removal.

**35 mutations were run. Four survived — and not one meant a missing test.**
Every one was a test the assistant had written that did not work:

| mutation | why the test missed it |
|---|---|
| `delete_points` empty-selector guard removed | asserted *nothing was deleted*, not *no call was issued*; an empty selector deletes nothing in a fake while being exactly the call that could delete everything against a real server |
| `with_payload` narrowed to drop `chunk_set_sha256` | the fake ignored `with_payload` and returned the full payload, so the field never went missing |
| `sorted()` dropped from `list_snapshots` | `glob` returns directory order and this directory happened to enumerate the way the assertion wanted — passing for an accidental reason |
| inline paragraph-number recovery disabled | rendered `content` is byte-identical; only the *unit structure* changes, and the test asserted on the string |

The common thread is that **a test can be green for a reason unrelated to the
property it names** — through an over-permissive fake, an incidental environment,
or an assertion aimed one layer away from the behaviour. Coverage cannot see
that, and review routinely misses it. The mutation-harness backlog item was
promoted with this as evidence.

A fifth mutation exposed something different: the non-ASCII hash test was pinning
`ensure_ascii=False`, which is not a correctness property at all, since escaping
stays deterministic and injective. The real requirement is *stability* — the
scheme must never drift, because every snapshot filename, advertised digest and
point payload derives from it — and only a golden value expresses that.

---

## Decisions

- **The hierarchy-aware chunker is deferred**, at Bertan's direction. It is an
  algorithm improvement, not a blocker. The baseline runs on today's chunker with
  its defects known and accepted — Article 4 as one 8,656-char chunk, wrong
  `paragraph` metadata in the ten cross-reference-split articles — and the
  snapshot mechanism exists to make the later change measurable.
- **The asymmetry of standards is governing**, at Bertan's direction: the eval is
  held to a higher correctness standard than the product. Recorded in
  `evaluation-plan.md` §1.
- **Paragraph citations are `Article N(M)`**, Bertan's fix.
- **Chunk-set identity is recorded at two levels** — collection metadata as the
  claim, per-point payload as the evidence. The collection-level property alone
  cannot localise a fault; the per-point digest survives a half-finished run.
- **Pruning is behind `--prune`** and the delete is re-checked rather than
  assumed. 196 points were deleted, the first destructive use.
- **`topics` is a toy**, to be revisited. `chapter: "8"` vs Chapter VIII is
  deferred to the far future.
- **The metadata schema is fixed up front**, because `update_collection` merges.

---

## Mistakes made this session

Attributed, per this log's convention. All are the assistant's unless stated.

- **`git_state` was wrong in the field that decides whether a snapshot is a
  baseline**, and the 2026-08-06 entry recorded it as hand-verified across six
  tree states. The verification was real and the code was still broken; the states
  chosen simply did not include the common one.
- **Implemented collection-level metadata only**, when the backlog entry the
  assistant had written the day before already described the per-point mechanism
  and why it is needed. Bertan had to ask the question again to surface it.
- **Four tests were written that did not test what they named**, found only by
  mutation. Details in the table above.
- **The first partial-index test did not simulate a partial index.** It used a
  second `index_chunks` call over a subset, which stamps the *subset's* hash — a
  different thing entirely. A real crash happens inside one call, where the digest
  is computed once from the full list. Rewritten to fail an upsert mid-batch.
- **Claimed the repeated article title was driving the `topics` distribution.**
  Measured before asserting, and it was wrong: only 5 of 368.
- **Cited "~195 orphans" from the previous session as though it were the figure.**
  It was an estimate; the measurement is 196, plus one missing chunk nobody had
  predicted.

Bertan's catches this session again set its direction: the reprioritization, the
governing philosophy, reading a single indexed point closely enough to find a
citation defect in 330 chunks, and the orphan-detection question that produced
the per-point digest. The Makefile case he has been making was independently
vindicated by a lock that had been stale for a session with nothing noticing.

---

## State handed to the next session

| | |
|---|---|
| Corpus | 99 articles, 185,466 chars, `sha 85fba45c40b6…` — **unchanged this session** |
| Chunk snapshot | `chunks_2026-08-07_081627_a231f919`, 368 chunks, 204,294 chars |
| Qdrant | `compliance_docs` — 368 points, **0 orphans, 0 missing, 0 stale** |
| Golden set | 285 exact · 34 normalized · 114 ungrounded · 319/433 clean (carried, not re-measured) |
| Sufficiency judge | unchanged — stages A and B only (`e2ebef1`) |
| Tests | **180 passed** |

**Open, in the order Bertan set:**

- **Refactor `index_documents.py` and `vector_db.py` — first item next session,
  at Bertan's direction.** The script carries too much logic that belongs in
  `VectorDatabase`: the reconcile plan, the orphan/stale/missing comparison, the
  metadata assembly and the post-conditions are all orchestration the class should
  own, leaving the script as a thin entry point.
- **Finish the sufficiency judge** — stage C, verdict derivation, the
  `sufficient_verbose` threshold (measure it, do not guess), the async runner,
  calibration and tests. Untouched this session and the largest remaining piece.
- **Gold chunk IDs (P0)**, now unblocked and pinnable against `a231f919`. Record
  the `chunk_set_sha256` the IDs were derived from.
- **The Makefile**, promoted at Bertan's direction and not to be postponed much
  longer.
- **`src/clause_and_effect/__init__.py` imports the world eagerly** — docling,
  langchain, openai and qdrant — so a pure-stdlib module costs ~17s to import and
  every test run pays ~14s before doing anything.
- **A payload-level audit** would close the one gap the per-point digest leaves:
  the digest is a claim the indexer wrote, not a re-derivation from stored text.
- `_looks_truncated` still false-flags article 99; `_clean_title` still leaves
  double spacing in titles 12, 60, 89 — now visibly embedded in every chunk of
  those articles; `src/config.py` `writer_model[1]` still raises `KeyError`. All
  carried unchanged.
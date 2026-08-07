# Chunk snapshot reproducibility

**Verified against:** `1802a72` — the chunk side introduced at `111cffd`, the
`git_state` fix at `c67e266`, the index side at `d7db4f9`, the per-point
chunk-set digest at `6f4df7a`.

**Code:** `src/clause_and_effect/chunk_store.py`,
`src/scripts/generate_chunks.py`,
`src/clause_and_effect/retrieval/vector_db.py`,
`src/scripts/index_documents.py`

**Status:** end to end and in use. Current baseline is
`chunks_2026-08-07_081627_a231f919` (368 chunks, `1802a72`), which superseded the
first snapshot `157d4d38` the same day when paragraph citations were corrected to
`Article N(M)`. `compliance_docs` holds exactly it — 368 points, **0 orphans, 0
missing, 0 stale** — advertising its digest, embedding model and vector size, and
every point carries that digest in its own payload. Transcripts below are from
live runs on 2026-08-07 unless marked otherwise. Remaining gaps: §12.

---

## 1. What this exists to prevent

A retrieval system is built from a chain of derived artifacts. Each one is
produced from the one before it, and each transformation can be wrong:

```
gdpr.pdf ──▶ gdpr.docling.json ──▶ gdpr_articles.json ──▶ chunks ──▶ Qdrant points
   PDF          document tree           corpus            chunk set     embeddings
```

Every link in that chain was tracked except one. The PDF, the document tree and
the corpus are all committed files with content you can read and diff. The
Qdrant collection is a live service you can query. **Chunking happened in the
middle of `index_documents.py` and left nothing behind** — the chunk set existed
only as a Python list, for the seconds between being computed and being
embedded.

The consequence was not hypothetical. On 2026-08-06 the live collection was:

```
'compliance_docs': points=563   config.metadata=None
```

563 points, from a corpus that had been replaced. The current corpus produces
368 chunks. So roughly 195 of those points were real GDPR text, embedded and
searchable, belonging to a decomposition of the regulation that no longer
existed anywhere — and **nothing in the repository could say so.** Not the
corpus file, not the git history, not the collection itself. The staleness was
known only because someone remembered.

This mechanism replaces that memory with an artifact and a check:

- The chunk set becomes a **named file on disk** with a content hash.
- The hash is recorded in a **manifest** alongside enough provenance to rebuild
  the chunk set from source.
- That same hash is (to be) written into **Qdrant's collection metadata**, so
  "is the index stale?" becomes a comparison rather than a recollection.

Section 12 covers what is built and what is not.

---

## 2. Shape of a snapshot

A snapshot is two files sharing a stem:

```
data/chunks/chunks_2026-08-06_145556_157d4d38.jsonl           344,419 bytes, 368 lines
data/chunks/chunks_2026-08-06_145556_157d4d38.manifest.json
```

The stem is `chunks_<date>_<time>_<hash8>`, built by `snapshot_name`
(`chunk_store.py:142`).

**The timestamp orders snapshots; the hash identifies them.** This is the
central idea of the whole design, and it is worth stating plainly because the
obvious alternative — name snapshots by date alone — fails at the job the
mechanism exists to do. A date answers *when was this made*. The question that
matters is *which chunk set is this, and is it the one the index holds*. Two
runs a minute apart over an unchanged corpus are the same chunk set; only a
content hash can say so.

Both halves are in the filename because both are useful at a glance: the
timestamp makes `ls` chronological, and `hash8` makes an unchanged regeneration
visible without opening anything.

### The chunks file

One JSON object per line, in **generation order** (document order for this
corpus — article 1 before article 2, paragraph 1 before paragraph 2):

```json
{"id": "gdpr_article_2_para_1", "text": "Article 2.1: Material scope\n\nThis Regulation applies…", "metadata": {"regulation": "GDPR", "article_number": "2", …}}
```

Two decisions here (`write_snapshot`, `chunk_store.py:220`):

- **JSONL, not a JSON array.** A snapshot's main use is being compared with
  another snapshot. Line-oriented output makes `diff` show which chunks changed;
  an indented array reflows and buries the change among formatting noise.
- **Generation order, not hash order.** The hash sorts by chunk ID (§3), which
  puts `gdpr_article_10` before `gdpr_article_2` because it is a string sort.
  That is right for hashing and wrong for reading. The file is for people too.

### The manifest

```json
{
  "chunk_set_sha256": "157d4d385908346bae470f75dc6c93e2f4ffcd84863f699ce11e33d3faf3c0ac",
  "chunk_count": 368,
  "created_at": "2026-08-06T14:19:57Z",
  "git_commit": "5a1ef44f2ac6f355fc409599c642a72a3ea6a305",
  "git_dirty": true,
  "git_dirty_paths": [
    "data/chunks/",
    "src/clause_and_effect/chunk_store.py",
    "src/scripts/generate_chunks.py"
  ],
  "source": {
    "path": "data/regulations/gdpr_articles.json",
    "sha256": "85fba45c40b6a7239bd3dc3f7bf1a4bafcf44eca6d37bd4404f9cb8595cad7ca",
    "article_count": 99
  },
  "chunker": { "class": "GDPRParser", "method": "article_to_chunks" },
  "stats": {
    "by_chunk_type": { "article": 38, "paragraph": 330 },
    "chars": { "total": 203964, "min": 90, "median": 389, "max": 8655 }
  }
}
```

| field | purpose |
|---|---|
| `chunk_set_sha256` | content identity — the value compared against Qdrant |
| `chunk_count` | redundant with the file, and checked against it on read (§6) |
| `created_at` | ordering only; deliberately **not** part of identity |
| `git_commit` | pins the chunker's code |
| `git_dirty` | whether that pin is meaningful |
| `git_dirty_paths` | whether the dirtiness is *relevant* (§5.2) |
| `source.path` | repo-relative, so the manifest is portable |
| `source.sha256` | independent check on the input (§5.3) |
| `source.article_count` | human-readable sanity figure |
| `chunker` | which code path produced this, by name |
| `stats` | orientation without parsing 368 lines |

---

## 3. The chunk-set hash

`chunk_set_hash` (`chunk_store.py:70`):

```python
canonical = json.dumps(
    sorted(({"id": c.id, "text": c.text, "metadata": c.metadata} for c in chunks),
           key=lambda row: row["id"]),
    sort_keys=True, ensure_ascii=False, separators=(",", ":"),
)
return hashlib.sha256(canonical.encode("utf-8")).hexdigest()
```

Four choices, each closing a way the hash could lie.

**Sorted by chunk ID.** Generation order must not change the answer. If the
chunker were ever reordered — articles processed in parallel, or grouped
differently — an unsorted hash would report a change that did not happen.

**`sort_keys=True`.** Python preserves dict insertion order, so a metadata dict
built with keys in a different sequence would serialize differently while being
the same mapping. Sorting keys removes construction order from the identity.

**`separators=(",", ":")`.** Whitespace is not content. Tight separators keep
the canonical form independent of any formatting choice.

**Over the chunks, not over the file.** This is the one that matters most.
Hashing `chunks_*.jsonl` would be simpler and would be **wrong**: the file's
name carries a timestamp, and if the manifest were ever folded in, the hash
would change on every regeneration. Every check would then report a false
change, and a check that always fires is a check nobody reads. The hash covers
exactly the three fields that determine what gets embedded and retrieved:
`id`, `text`, `metadata`.

### What the hash is, and is not, evidence of

Identical chunks produce an identical digest with probability exactly 1 — it is
a function, not a sample. The interesting direction is the reverse: matching
digests imply identical inputs *unless* there is a collision. For SHA-256 an
accidental collision sits around 2⁻²⁵⁶ ≈ 10⁻⁷⁷. Nothing here is adversarial —
no one is crafting a malicious chunk set — so this is as close to certainty as
verification gets.

The real limit is not collisions but **scope**. The hash covers `id`, `text`
and `metadata`. It does not cover the embedding model, the vector dimensions,
the order of lines in the file, or anything about the index built from it. Two
collections can legitimately advertise `157d4d38…` while returning different
results, because identical chunks through different embedding models produce
different vectors. See §12.

---

## 4. What was measured

Per `docs/design/README.md`, observations are separated from arguments. These
are observations, from runs on 2026-08-06.

**Determinism across processes and hash seeds.** Three separate interpreter
processes, each with a randomized `PYTHONHASHSEED`:

```
seed-varied run: 157d4d385908346b  n=368  first=gdpr_article_1
seed-varied run: 157d4d385908346b  n=368  first=gdpr_article_1
seed-varied run: 157d4d385908346b  n=368  first=gdpr_article_1
```

This is what rules out the usual source of "same code, different output" in
Python: iteration order of sets and dicts under hash randomization.

**Two independent generations, byte-identical output:**

```
jsonl BYTE-identical : True
sha256 of the files  : 6b70d5c39f381061   6b70d5c39f381061
manifest fields that DIFFER: []
```

**The timestamp does not enter identity.** Two `--force` runs one second apart:

```
chunks_2026-08-06_141857_157d4d38.jsonl
chunks_2026-08-06_141858_157d4d38.jsonl
                  ^^^^^^ differs   ^^^^^^^^ identical
```

**Tamper detection.** One word changed by hand in a written snapshot, then
re-read:

```
chunk set does not match its manifest: chunks_…_157d4d38.jsonl hashes to
f704ff91d943… but the manifest records 157d4d3859 08…
```

**`git_state` behaviour**, against a scratch repository:

| working tree | `git status --porcelain` | result |
|---|---|---|
| clean | `''` | `dirty_paths = []` |
| tracked file modified, unstaged | `' M a.txt'` | dirty |
| tracked file modified, staged | `'M  a.txt'` | dirty |
| untracked file | `'?? b.txt'` | dirty |
| untracked but gitignored | `''` | clean |
| not a git repository | — | `('unknown', ['<git unavailable>'])` |
| 60 dirty files | — | 51 entries, last `… and 10 more` |
| after `git mv` | — | `['seed.txt -> renamed.txt']` |

**Qdrant collection metadata round-trip**, on the live server:

```
after create : {'chunk_set_sha256': 'abc123', 'note': 'probe'}
after update : {'chunk_set_sha256': 'def456', 'note': 'probe'}
```

Note the second line: `update_collection` **merges, it does not replace**. The
`note` key survived an update that did not mention it. Any key written once
persists until explicitly overwritten, so the metadata schema has to be decided
up front rather than allowed to accrete.

---

## 5. The reproducibility chain

The manifest's job is to let someone rebuild the chunk set from source and get
the same digest. That requires pinning every input.

### 5.1 The code — `git_commit`

Read by shelling out to git at generation time (`git_state`,
`chunk_store.py:101`):

```
generate_chunks.py:47   _REPO_ROOT = Path(__file__).resolve().parents[2]
generate_chunks.py:166  repo_root=_REPO_ROOT
chunk_store.py:175      commit, dirty_paths = git_state(repo_root)
chunk_store.py:124      commit = run("rev-parse", "HEAD")
```

The commit pins the chunker — `article_to_chunks`, `_split_into_paragraphs`,
`_create_chunk_id`, `_extract_topics` — and the driver, and (because
`gdpr_articles.json` is committed) the input corpus too.

### 5.2 Whether the pin is meaningful — `git_dirty` and `git_dirty_paths`

A commit describes the tree only when the tree matches it. Against a dirty
tree, `git_commit` names a commit that does *not* contain the code that ran, so
the snapshot is not reproducible.

`git_dirty` alone is not actionable, because **it is repo-wide**. An
uncommitted draft in `docs/` marks a snapshot dirty even when the chunker is
fully committed and unchanged. A reader three months later cannot tell that
case from a genuinely unreproducible one.

Hence `git_dirty_paths`. Same flag, opposite verdicts:

```json
"git_dirty": true, "git_dirty_paths": ["docs/dev-log/draft.md"]
```
→ irrelevant; the chunker is committed, the snapshot reproduces.

```json
"git_dirty": true, "git_dirty_paths": ["src/clause_and_effect/parsers/gdpr_parser.py"]
```
→ disqualifying; the code that ran is not in any commit.

`git_state` returns `(commit, dirty_paths)` and the boolean is derived at the
manifest with `bool(dirty_paths)`. There is deliberately no separately-computed
flag, because two fields describing one fact will eventually disagree.

Two guards on the list: it is capped at `_MAX_DIRTY_PATHS = 50` with an
`… and N more` marker, so a mass refactor does not turn the manifest into a
file listing; and if git cannot be consulted at all, the list is
`["<git unavailable>"]` rather than empty — an unverifiable tree must never
read as clean.

### 5.3 The input — `source.sha256`

The corpus is pinned by the commit already, so recording its hash is
redundant — deliberately. It is an **independent** check.

Reproducing a snapshot means running the chunker over the same corpus. If the
result does not match, the first question is *what* differed: the code or the
input. Without `source.sha256` you would diff 368 chunks to find out. With it,
one comparison answers it — and it catches the case the commit cannot, where
`gdpr_articles.json` was regenerated in the working tree.

### 5.4 What is *not* pinned — the environment

A checkout gives you source, not an environment. The Python interpreter and
installed packages are not recorded in the manifest and are not implied by the
commit.

For this chunker the exposure is small: the whole path is stdlib `re` plus
plain data structures — no docling, no model, no network. But that is an
argument, not an observation, and it stops being true the moment the chunker
grows a dependency (a tokenizer for a token-based budget is the obvious
candidate).

`uv.lock` is committed, so `uv sync` at the target commit restores the
dependency set. That step is part of the procedure in §8 for a reason.

### 5.5 The chicken-and-egg, and the convention it forces

**A manifest can never name the commit that contains it.** The manifest is
written before the snapshot is committed, so `git rev-parse HEAD` at generation
time necessarily returns an earlier commit.

This forces a convention:

> **A snapshot's manifest names its parent commit — the code that produced it —
> never the commit it ships in.**

And it forces an ordering. If the chunker and the snapshot are committed
together:

```
generate  →  manifest: git_commit = <commit before the chunker existed>, git_dirty = true
commit    →  code and snapshot land together
```

The recorded commit is one where `generate_chunks.py` does not exist. Splitting
the commits fixes it:

```
commit A  →  chunk_store.py, generate_chunks.py, data/chunks/.gitkeep
generate  →  manifest: git_commit = A, git_dirty = false
commit B  →  the .jsonl and .manifest.json
```

Now `git checkout A && python -m src.scripts.generate_chunks` reproduces the
digest. **Committing the code and the snapshot separately is a requirement of
the mechanism, not a matter of taste.**

---

## 6. Reading a snapshot back

`read_snapshot` (`chunk_store.py:251`) does not simply parse. It verifies:

1. The manifest exists beside the chunks file, else `FileNotFoundError`.
2. Every line is parsed into a `Chunk`.
3. The chunk set is **re-hashed** and compared with `chunk_set_sha256`.
4. The line count is compared with `chunk_count`.

Mismatch on either raises `ValueError`.

This is the point at which several failures become impossible rather than
merely unlikely: a file edited by hand, a write truncated by a full disk or a
crash, a chunks file paired with the wrong manifest after a careless rename.
Without the check, any of those would be indexed as though it were the recorded
chunk set — and the collection would then advertise a hash for content it does
not hold, which is worse than no metadata at all, because it is *trusted*.

`generate_chunks.py:200` calls `read_snapshot` on the file it has just written,
before reporting success. Writing and then reading back is what makes the
success message a claim about the disk rather than about a variable in memory.

---

## 7. Behaviour of `generate_chunks.py`

### 7.1 Validation before writing

`_check_chunks` (`generate_chunks.py:50`) refuses to write a chunk set that
fails any of:

| check | why it is here rather than downstream |
|---|---|
| non-empty | a silent no-op otherwise |
| **unique chunk IDs** | duplicates collapse onto one Qdrant point silently; `index_chunks` does raise, but only after the embeddings are paid for |
| no empty text | an empty chunk embeds to noise |
| **every article produces ≥1 chunk** | an uncovered article is unreachable by retrieval and shows up as no count mismatch anywhere |

The order matters: this runs before `build_manifest`, so an invalid chunk set
never acquires a hash or a filename.

### 7.2 Refusing to write duplicates

If the newest existing snapshot has the same `chunk_set_sha256`, nothing is
written (`generate_chunks.py:174`):

```
✅ Identical to the newest snapshot (chunks_2026-08-06_141857_157d4d38.jsonl); nothing written.
   Pass --force to record a duplicate anyway.
```

Re-running after an unrelated change is therefore free and leaves no trace,
which keeps the directory a record of *distinct* chunk sets rather than a log
of how often the command was typed.

### 7.3 Reporting the difference

When the hash *does* differ, the run reports what moved before writing:

```
Against the newest snapshot (chunks_2026-08-06_141857_157d4d38.jsonl):
   chunks 368 -> 368
   IDs added 0, removed 0, text changed 0
```

Splitting *IDs added/removed* from *text changed* separates a re-chunking (IDs
move) from a corpus edit (same IDs, different text) — usually the first thing
you want to know.

### 7.4 `--dry-run`

Everything up to the write, including the full report and the hash. Since the
hash is printed, the filename is known before any file exists.

---

## 8. Procedure: reproducing a historical chunk set

1. Open the snapshot's `.manifest.json`. Read `git_commit`.
2. **Check `git_dirty` and `git_dirty_paths`.** If dirty and the paths touch
   the chunker or the corpus, stop — that snapshot is not reproducible, and no
   amount of care in later steps changes it.
3. `git checkout <git_commit>`.
4. `uv sync` — restores the dependency set from the committed `uv.lock` (§5.4).
5. Confirm the input: hash `data/regulations/gdpr_articles.json` and compare
   with `source.sha256`. If it differs, the corpus drifted; the chunk hash was
   never going to match and this tells you why.
6. `python -m src.scripts.generate_chunks --dry-run`.
7. Compare the printed `chunk_set_sha256` with the manifest's.

Step 7 is a single string comparison. That is the payoff of hashing: confirming
a 368-chunk reproduction does not require diffing 368 chunks.

### What reproduces and what does not

| | reproduces? |
|---|---|
| `chunk_set_sha256`, `source.sha256` | ✅ deterministic — the whole point |
| the `.jsonl` file, byte for byte | ✅ |
| `chunk_count`, `stats`, `chunker`, `source.path`, `source.article_count` | ✅ |
| `git_commit` | ✅ — it is the commit you checked out |
| `git_dirty` / `git_dirty_paths` | ✅ if your tree is clean after checkout |
| `created_at` | ❌ wall clock |
| the filename | ❌ partly — the timestamp differs, `hash8` does not |

The hashes are the *most* reproducible fields, not the least. SHA-256 is
deterministic; there is nothing pseudo-random about a digest. If they varied,
none of this would work.

---

## 9. Design decisions, and what was rejected

**Chunker parameters are not recorded.** `article_to_chunks` splits articles
over 1000 characters, and the manifest does not say so. Copying that constant
would create a second source of truth that goes stale the first time someone
edits the chunker without editing the manifest builder — a manifest that
confidently reports the wrong budget is worse than one that reports none.
`git_commit` pins the actual code. The cost is that reading a parameter
requires checking out the commit; that is the right trade, because the answer
is then correct by construction.

`chunker` records `{"class": "GDPRParser", "method": "article_to_chunks"}` —
which code path ran, not how it behaved. Note the residual risk: renaming the
method changes the recorded string without changing behaviour, and vice versa.

**Embeddings are not stored.** 368 × 1536 float32 ≈ 2.3 MB per snapshot, fully
derivable from chunks plus a model ID. The model ID belongs in the *index's*
metadata, not the chunk set's — the chunks are the same chunks whatever they
are later embedded with.

**Snapshots are committed to git.** They are 344 KB, the repository already
commits a 1.4 MB document tree, and a snapshot that is not committed cannot
serve as the baseline a future chunker is measured against.

**One producer, not two.** `index_documents.py` used to chunk inline.
`generate_chunks.py` is now the only producer of indexed chunks;
`GDPRParser.parse()` still chunks a PDF as a library entry point, but nothing
downstream consumes it. Two producers would mean chunks reaching the index
without ever being recorded — reintroducing the exact gap in §1.

**Hash content, not the file.** Covered in §3; the decisive argument is that a
file hash would change on every regeneration and so could never answer "did
anything change?".

**Timestamp *and* hash in the filename**, rather than either alone. Hash alone
loses chronology and makes two snapshots with identical content collide.
Timestamp alone cannot answer the question the mechanism exists for.

---

## 10. File and function map

| symbol | file:line | role |
|---|---|---|
| `Snapshot` | `chunk_store.py:48` | a chunk set plus its manifest, as read from disk |
| `chunk_set_hash` | `chunk_store.py:70` | content identity |
| `file_hash` | `chunk_store.py:87` | SHA-256 of the source corpus |
| `git_state` | `chunk_store.py:101` | commit + dirty paths |
| `snapshot_name` | `chunk_store.py:142` | `chunks_<date>_<time>_<hash8>` |
| `list_snapshots` / `latest_snapshot` | `chunk_store.py:148` | discovery, oldest first |
| `manifest_path_for` | `chunk_store.py:161` | the sidecar's path |
| `build_manifest` | `chunk_store.py:166` | assembles provenance |
| `write_snapshot` | `chunk_store.py:220` | writes both files |
| `read_snapshot` | `chunk_store.py:251` | reads **and verifies** |
| `_check_chunks` | `generate_chunks.py:50` | pre-write validation |
| `main` | `generate_chunks.py:123` | the CLI |

---

## 11. Worked example — the chunk set as it stands

`chunks_2026-08-07_064658_157d4d38`, generated at `c67e266` against a clean tree
and committed at `2a7811a`. Source corpus: 99 articles, 185,466 chars,
`sha256 85fba45c40b6…`, regenerated from the docling document tree at `78a58bb`.

```
chunks           : 368
chunk_set_sha256 : 157d4d385908346bae470f75dc6c93e2f4ffcd84863f699ce11e33d3faf3c0ac
by chunk_type    : {'article': 38, 'paragraph': 330}
chars            : total 203,964  min 90  median 389  max 8655
largest chunks   :
   8,655 chars  gdpr_article_4_para_1
   5,784 chars  gdpr_article_70_para_1
   4,027 chars  gdpr_article_47_para_2
```

Two figures worth reading rather than skimming.

**`chars total 203,964` against a 185,466-char corpus.** Not an error: every
chunk repeats `Article N: Title\n\n` as its header, so ~18.5 KB is 368 repeated
titles.

**`max 8655` is `gdpr_article_4_para_1`** — Article 4's 26 definitions in a
single chunk. Article 4 numbers its definitions `(1)`…`(26)`, which never match
the chunker's `\d+\.\s+` pattern, so nothing splits it. This is a known,
accepted regression from the corpus rebuild and is tracked in `todo.md`. It
appears in the report by design: the largest-chunks list is where a chunking
problem surfaces first.

---

## 12. Known gaps

**~~No snapshot exists yet.~~ Closed 2026-08-07.**
`chunks_2026-08-07_064658_157d4d38` was generated at `c67e266` against a clean
tree and committed at `2a7811a` — 368 chunks, `git_dirty: false`. §5.5's
convention held: the code had to be committed first.

**~~The Qdrant half is not built.~~ Closed 2026-08-07** (`d7db4f9`).
`compliance_docs` now advertises its chunk set and holds nothing else: 368
points, 0 orphans, 0 missing. The collection had held **563 points with
`config.metadata=None`**, of which **196 belonged to no current chunk** and one
current chunk (`gdpr_article_79`) was absent — its footnote being dropped pushed
the article under the chunk budget, so it stopped splitting into paragraphs and
acquired a new ID. Metadata is written on every index run and written last,
after the count is verified and orphans are gone; a run that leaves orphans
exits non-zero writing nothing. `index_documents.py --check` answers "does this
collection hold exactly this snapshot?" for free.

**~~The hash does not cover the embedding model.~~ Closed 2026-08-07** by
recording `embedding_model` and `vector_size` in the collection metadata beside
the hash. The gap was real — identical chunks through different models give
different vectors and different retrieval while both collections would honestly
report the same `chunk_set_sha256` — so the hash alone could never have answered
"does this index match?".

**~~Point membership is not content equality.~~ Narrowed 2026-08-07** (`6f4df7a`)
by stamping `chunk_set_sha256` into every point's payload. Raised by Bertan, who
asked what the ID-set reconcile procedure misses.

The gap was structural: point IDs derive from chunk IDs alone, so a chunk whose
*text* changes keeps its point, and `find_orphans` reports a perfect match while
every stored vector is from the old text. The paragraph-citation fix the same day
is exactly that shape — the snapshot diff reads `IDs added 0, removed 0, text
changed 330`. It also covers a **partial index**, where every ID matches and
metadata was never written, so the collection quietly advertises the previous
chunk set while holding a mix of two; and a **silently failed upsert**, which the
count check cannot see because the count is unchanged.

`--check` now reports staleness as a fourth condition beside membership, absence
and the advertised hash. All four are required: the ID sets agreeing proves only
that the right chunks are represented, not that their vectors are current.

**What remains open.** The digest is a claim the indexer wrote, not a
re-derivation from stored text. A payload mutated *after* indexing keeps a valid
digest, and a bug writing the wrong text alongside the right digest is
self-consistent. Both need a payload-level audit — re-hash each stored `text`
against the snapshot — which is cheap and not built.

**The `chunker_tree_dirty` flag is recorded but not enforced.** A snapshot taken
against a dirty tree can still be indexed; the collection simply advertises that
it was. Deliberate — experiments need it — but nothing prevents a dirty-tree
snapshot from becoming a published baseline by accident.

**`git_dirty` over-reports.** Repo-wide, so unrelated edits flag a snapshot
that is genuinely reproducible. `git_dirty_paths` makes it judgeable but not
automatic. Narrowing it to chunker-relevant paths would need a hardcoded
dependency set that goes stale — rejected as the worse failure. It never
*under*-reports, which is the direction that matters. Its one blind spot is
gitignored files; `tmp/` is ignored in this repo.

**The environment is not pinned by the commit.** §5.4. `uv sync` is a manual
step in the procedure, not something the manifest enforces or records. A
snapshot could in principle be unreproducible because of a dependency change,
and nothing would say so.

**Line order in the `.jsonl` is not part of identity.** The hash sorts by chunk
ID, so two files with the same chunks in different line order hash the same.
Harmless today — Qdrant is unordered and nothing depends on file order — but it
means the file is not fully determined by its hash.

**Two snapshots in the same second with the same hash collide on filename.**
`snapshot_name` has one-second resolution, so `--force` twice within a second
overwrites the first file. Harmless in practice (identical hash means identical
content) but it is a silent overwrite.

**`list_snapshots` orders by filename**, which is chronological only because
the timestamp is fixed-width and zero-padded. Changing the naming scheme
silently breaks `latest_snapshot`.

**`_MAX_DIRTY_PATHS` truncation is lossy.** Beyond 50 dirty paths the manifest
records a count, not the paths — and a very dirty tree is exactly where you
most want to know what was dirty.

**No automated tests cover `chunk_store.py`.** Every property in §4 was
verified by hand in a session and none of it is guarded by the suite (81 tests,
none touching this module). The verification is real but it is a snapshot in
time, not a regression barrier — which is precisely the standard this project
applies elsewhere and does not yet meet here.
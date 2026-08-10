# 2026-08-10 · session 1

**Branches:** `dev-02` (closed via PR #2), then `dev-03`
**Commits:** `5d517e8`…`86b4d00` on `dev-02`; `60ab36d`…`47784c2` on `dev-03`
**Merged:** PR [#2](https://github.com/bgunyel/clause-and-effect/pull/2), 69 commits, `bce0923`
**State at close:** `dev-03`, 5 commits ahead of `main`, clean tree, 243 passed · 5 xfailed

**Theme:** the vector_db test suite was repaired and the first baseline snapshot
landed, closing the item that had blocked everything since 2026-08-07. The
session then turned to documenting the sufficiency judge, and the documenting
kept finding things the code and backlog had wrong.

---

## `test_vector_db.py`: 24 → 0, and two of the three handover predictions were wrong

The 2026-08-09 handover described three layers of failure. Working through them
found the first two misdiagnosed, which is the part worth recording.

- **Not a stale repoint.** The handover said the `_chunks` helper at line 207
  needed repointing. `Chunk.metadata` had become a `ChunkMetadata` model, so the
  helper's one-key dict failed pydantic validation with **7 missing required
  fields** — every test using it died at construction, before reaching any code
  under test. Repairing it took 24 → 23 and exposed 23 `TypeError`s from the
  changed signatures, exactly as predicted.
- **The fake Qdrant client already had an in-memory point store.** The handover
  listed building one as required work. `_FakeClient.points` existed, `upsert`
  populated it, and `scroll` projected `with_payload` off it. Nothing to build.
  The assistant checked rather than accepting the handover, which is the only
  reason this was not "built" a second time.

Bertan asked for the work one group at a time, with review between: mechanical
repoints first, then each rewrite discussed before it was written.

### Every rewritten test was mutation-checked

Twelve tests took `_ANY_DIGEST`, a constant deliberately **not**
`chunk_set_hash(chunks)` — the digest is caller-supplied now, and a test passing
the chunks' own hash would keep passing against a primitive that re-derived it.

That reasoning was then tested and found insufficient on its own. **The mutant
survived**: re-deriving the digest inside `embed_and_upsert_chunks` left the
suite at 7 failed / 25 passed, unchanged, because no test using `_ANY_DIGEST`
reads the stamped value back. `stamps_the_digest_it_is_given` was written to
close it, and kills the mutant by name:

```
FAILED test_embed_and_upsert_chunks_stamps_the_digest_it_is_given
assert ['c8fa6058…'] == ['00000000…']
```

The assistant's original comment on `_ANY_DIGEST` claimed the constant guarded
against re-derivation. It does not — it only avoids *teaching* the removed
coupling. The comment was corrected to say so, since a safeguard that cannot
fire invites trust it cannot earn — the same principle applied to the dead check
removed from `index_documents.py` on 2026-08-09.

Orphan handling had moved to `index_chunks` and changed shape — named rather
than counted, deleted rather than reported, verified rather than assumed — so
one warn-and-continue test became four, each killing a distinct mutant (drop the
names; remove the report cap; never delete; record metadata before the survivor
check).

Two tests were deleted after checking rather than assuming they were redundant:
`reports_the_stored_count_not_the_input_count`, whose message the code no longer
emits, and `indexing_a_subset_stamps_the_subset_not_the_full_set`, now a
statement about `chunk_set_hash` already pinned by
`test_chunk_store.test_chunk_set_hash_changes_when_a_chunk_is_added_or_removed`.
Both left a tombstone comment explaining why.

## The identity check cannot see an ID collision, and said it could

`embed_and_upsert_chunks` reported points *"lost to ID collisions or a failed
upsert"*. It cannot detect a collision: if two chunk IDs derive the same point,
the upsert overwrites and one chunk is lost, yet both find their point present
and neither is reported missing — the check asks the collection the same
question that produced the collision. The count check it replaced could see
this.

Bertan chose to trim the claim rather than restore collision detection. The
message, the comment above it, and the `Raises:` block (which named `ValueError`
for both failures, when the post-condition has raised `IndexVerificationError`
since the refactor) were corrected, and the blindness recorded in the docstring
together with where the claim is carried instead.

## The baseline snapshot

`chunks_2026-08-10_060327_5caac594`, 368 chunks, generated at `7fd62747` with
`git_dirty: false` and `git_dirty_paths: []`, re-read and re-hashed to the same
digest after writing. Corpus `85fba45c40b6…`, 99 articles. Composition: 38
article chunks, 330 paragraph, 204,294 chars, median 389.

No comparison against `a231f919` was possible — it predates the current chunk
schema (`['paragraph', 'topics']` in its metadata) and raises
`LegacySnapshotError`, which is the 2026-08-09 mechanism working as designed.
This snapshot has no loadable predecessor; it is the origin point.

The accepted chunker defects are in it deliberately: `gdpr_article_4_para_1` at
8,656 chars heads the largest-chunks list, alongside the 10 mis-numbered and 26
character-losing articles. Any retrieval number measured off this baseline is
measured over that corpus.

## The design document found what the sources had wrong

`docs/design/sufficiency-judge.md` was assembled from `todo.md`,
`evaluation-plan.md` §6.2/§7.3, the 2026-08-02 eval report, four dev logs and the
module. Three corrections came out of the assembly.

**The eval report's numbers had drifted.** It records 285 exact / 14 normalized /
134 ungrounded. Re-measured at `HEAD`: **285 / 34 / 114**, 319 clean, gate still
FAIL. Twenty cases moved from ungrounded to normalized across the corpus
regenerations. The design document uses the measured figures and says so.

**Golden-set provenance: the assistant got it wrong twice from git.** Asked to
establish self-preference bias, it inspected `orchestrator_model` at `59f7c03`,
the commit that first added `data/tier-1/`, found a single DeepSeek V4 Flash
entry, and concluded judge and generator were the same model. Bertan supplied
the real process: six proposers — Minimax M-2.7, GLM 5, Kimi K-2.5, Qwen 3.5,
Minimax M-2.5, DeepSeek V-3.2 — integrated by **Opus 4.5**. The assistant then
recorded that none of this was in the repository. Bertan pointed at `2638b52`,
where all six are in `src/config.py` on `LlmServers.OLLAMA`, in the same order.

The trap, now documented: the config was rewritten to OpenRouter at `6ccd193` on
**2026-07-22**, one day before the data was committed at `59f7c03` on
**2026-07-23**, while the data itself was generated in **March** under the
six-model config. Inspecting the config as of the data commit describes a
configuration the data was never produced by.

What is genuinely absent is the **integration** stage. The generation script
concatenates the six proposals under a merge instruction and stops — it never
invokes `writer_model` and never writes JSON. Opus 4.5 ran **interactively**, so
there is no script, no parameters and no transcript, and no `article_NN.txt`
intermediate was ever tracked. That makes the integration stage unreproducible
*in principle*, not merely unrecorded.

**Self-preference is answerable, and the answer is workable.** The judge runs on
DeepSeek V4 Flash — a different family from the chief judge, the same family as
proposer DeepSeek V-3.2. Gemini 3.1 Flash-Lite, Nemotron-3-Super and the GPT-OSS
pair share a family with neither, so a three-family panel with zero proposer
overlap is reachable on providers already configured. An earlier draft claimed
diversity was bounded at two families; that followed from assuming OpenRouter was
the only route, and Bertan's note that `LlmServers.OLLAMA` is Ollama *Cloud*
overturned it.

`writer_model[1]` was also misdiagnosed in the backlog as an unavailable model.
GPT-OSS-120B has `GROQ` and `OLLAMA` aliases and ran fine on `OLLAMA` at
`2638b52`; the switch to OpenRouter moved it to a provider it has no alias for.
Bertan removed the entry; its stale comment was replaced with the corrected
diagnosis.

## The sufficiency judge became a package, and the import-cost claim failed first

Bertan proposed splitting the 545-line module into four files: stages A, B, C and
a driver. Four does not work — the dataclasses are shared by all three stages and
the driver, so they need their own module or the driver's import is circular. The
assistant proposed six, adding `llm.py` to isolate `build_judge_llm` as the only
`ai_common` touchpoint, on the argument that it would keep the dataclasses cheap
to import.

**That property was claimed, then measured, and was not there.** `models.py`
still pulled torch at **7.68s**, because the package `__init__` re-exported the
stages and Python runs a package's `__init__` before any submodule of it. Bertan
independently observed that the `__init__` exposed too much and asked for the
absolute minimum; taken literally that is **nothing**, since no caller outside the
package exists yet. With the `__init__` exporting nothing:

```
src.eval.sufficiency          0.08s   torch=False
src.eval.sufficiency.models   0.07s   torch=False      (was 7.68s)
src.eval.sufficiency.stage_a  9.50s   torch=True       (correct — needs the model)
```

The move itself was verified pure: both prompts byte-identical by AST comparison
(`STAGE_A_INSTRUCTIONS` sha `2b152da2`, `STAGE_B_INSTRUCTIONS` sha `f27fb440`),
pydantic schemas unchanged, and the set of top-level definitions identical before
and after — nothing lost, nothing added. Two dead imports (`re`, `sys`) did not
survive.

## `ai_common`: the fix order is forced, and two of three candidates are worth zero

Bertan asked whether moving the six provider SDKs inside `get_llm` would buy
import time. Measured: **no, not on its own.**

| variant | cost |
|---|---|
| `import ai_common.llm` today | 7.63s |
| six provider SDKs moved into `get_llm` | 7.93s |
| …and `BaseChatModel` behind `TYPE_CHECKING` | 7.79s |

Both are worth nothing because `llm.py` does `from .enums import …`, which
re-enters the package `__init__`. Bertan then asked whether
`from ai_common.llm import get_llm` would help; it does not — 7.83s against
7.95s, **4622 modules either way**, all nine submodules loaded, because Python
must execute a parent package's `__init__` to completion before any submodule.

Isolated, the cost is: `pydantic`+`typing` 0.13s (the floor for `enums.py`),
`BaseChatModel` 4.28s and torch, `ai_common.enums` 7.86s. Marginal provider cost
with `langchain_core` loaded: google_genai +1.87s, openai +0.94s, anthropic
+0.74s, ollama +0.15s, groq +0.01s, **openrouter +0.01s**.

PEP 562 was verified on a toy package rather than asserted — cost becomes per
*name*, and one heavy name in a statement defeats laziness for that statement.
Full numbers and the implementation order are in `todo.md`.

## Repository hygiene

PR #2 merged `dev-02` into `main` (69 commits, 79 files, +13,288/−554). Bertan
then stated the branch hygiene rule, which is now a skill at
`.claude/skills/branch-hygiene/SKILL.md`. Applying it found the rule had already
drifted: **`dev-01` was merged on 2026-08-02 and still existed**, locally and on
origin, eight days and a second PR later. Both stale branches were deleted after
confirming `MERGED` state; the repository now holds `main` and `dev-03` only.

## Mistakes made this session

All the assistant's unless stated.

- **Concluded the golden set's generator from git, twice, and was wrong both
  times.** First that judge and generator were the same model; then that the
  provenance was absent from the repository. Both from reading the config at the
  wrong commit. Bertan supplied the process and then the commit.
- **Claimed an import-cost property for the package split, then measured it and
  found it absent.** The `__init__` re-export defeated the separation it existed
  for. Bertan asked for a smaller `__init__` independently.
- **Destroyed uncommitted source edits with `git checkout`.** The mutation
  harness reverted `vector_db.py` to `HEAD` between mutants; the option-1 message
  and docstring corrections were uncommitted and went with it. Restored, and the
  harness switched to an in-memory content backup.
- **Wrote a `_ANY_DIGEST` comment claiming a guarantee the constant does not
  provide.** Found by mutation, not by review.
- **Asserted "panel diversity is bounded at two families"** from an unchecked
  assumption that OpenRouter was the only reachable provider.
- Inserted §10.9 out of order in the design document and had to renumber.

## State handed to the next session

| | |
|---|---|
| Branch | `dev-03`, 5 ahead of `main` (`bce0923`) |
| Corpus | 99 articles, `sha 85fba45c40b6…` — unchanged |
| Chunk snapshot | **`5caac594…`, 368 chunks, written and merged to `main`** |
| Qdrant | `compliance_docs` — **stale**; still 368 points on the old digest, untouched all session |
| Golden set | 433 cases · 285 exact · 34 normalized · 114 ungrounded · gate FAIL (re-measured) |
| Sufficiency judge | stages A and B, now `src/eval/sufficiency/`; C, verdicts, runner, calibration, tests not started |
| Tests | **243 passed, 5 xfailed** |
| Docs | `docs/design/sufficiency-judge.md` added (738 lines) |

**Open, in order. Bertan set the first item explicitly at session end.**

1. **🔺 `ai_common` enhancements — the first item, and nothing else starts before
   it.** `__init__.py` first, because the other two fixes measure as worth zero
   until it lands. Full numbers, the ordering proof and the suggested shape are
   in `todo.md` under 🟡 Tooling.
2. **The re-index** against `5caac594…`. Not run this session: it talks to a live
   Qdrant and deletes the orphans it finds, so it wants a deliberate go-ahead.
   The digest moved, so all 368 existing points are stale.
3. **Gold chunk IDs (P0)** — pinnable now the baseline digest exists in `main`.
4. **The sufficiency judge**, stage C onward. Four decisions are open and each
   changes the output: the verdict for an empty `core_claims` (currently falls
   through to `sufficient`, which is wrong); whether the two routes to
   `insufficient` are recorded distinctly; whether stage C adjudicates auxiliary
   claims; and calibration sequencing.
5. **The Makefile**, promoted 2026-08-07, still not started.
6. A hazard recorded but not closed: a caller can stamp the full set's digest
   onto a subset, and `index_chunks` would prune the rest of the corpus and record
   it with every internal check satisfied. Unreachable through
   `index_documents.py` today, since chunks and digest come from one snapshot.
7. `_looks_truncated` still false-flags article 99; `_clean_title` still leaves
   double spacing in titles 12, 60, 89. Both carried unchanged.
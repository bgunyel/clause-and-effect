# 2026-08-26 · session 1

**Repositories worked in:** `clause-and-effect` (`dev-04`) — two commits,
`4768ce9 → 868c344`, branch now **41 ahead of `main`**, no PR opened.
`ai-common` — read, not modified.
**State at close:** suite **354 passed / 5 xfailed**, unchanged. Working tree
clean, both commits pushed.
**Live spend:** **$0.00060892** over 36 upstream requests, all of it the retry
probe across three runs. Every other measurement was free.

**Theme:** the session's stated task was to finish
[`docs/design/llm-call-log.md`](../design/llm-call-log.md) — Bertan's instruction
from the previous session's item 1. It was finished, and the eleven open
questions are now 23 attributed decisions. But the measurement taken along the
way changed what is being built: **a retried call makes an unbounded number of
billed generations, and until this session nothing in the process could name
more than one of them.** The design that closed the session is not the one that
opened it.

---

## Most of what a failed call costs has never been visible

**This is the session's finding.** It was recorded as an unverified trap on
2026-08-25 — *"every cost total this project has reported may be an
undercount"* — and Bertan's instruction was to settle it before the schema was
written. Settling it took three probe runs and cost less than a tenth of a cent.

`scripts/probe_retry_visibility.py` (commit `7c15d8b`) forwards every request to
OpenRouter for real, reads the generation id, cost and provider out of the
response body, and **only then** replaces the response with a 500. That ordering
is the whole method: a synthetic failure that never leaves the machine produces
no generation, and the undercount would have been unmeasurable by construction.
Counting happens at `httpx.{Async,}Client.send`, for the reason
`probe_wire_params.py` already established — the socket is the last point the
request is ours, and reading a callback or `_create_chat_result` would re-derive
the answer from a layer whose behaviour is the question.

| scenario | upstream requests | callback runs | generations the caller can name | cost unaccounted |
|---|---|---|---|---|
| async, fails twice then succeeds | 3 | **1** | 1 | **$0.00003026 of $0.00004551 — 67%** |
| async, fails throughout (capped at 6) | 6 | 3 | **0** | **100%** |
| sync, clean first call | 1 | 1 | 1 | 0 |

### `max_retries` is a time budget, not a count

`langchain_openrouter/chat_models.py:457-466` converts it:

```python
max_elapsed_time=self.max_retries * 150_000   # milliseconds
```

`max_retries` defaults to **2**, and `ai_common.get_llm` does not override it, so
every panelist retries with exponential backoff **for up to 300 seconds with no
limit on the number of attempts**. The probe's own cap stopped scenario 2 at six
requests in 26 seconds; the layer was nowhere near finished. Multiplied by
`.with_retry(stop_after_attempt=3)`, one logical judge call has a **fifteen-minute
worst case and an unbounded number of billed generations**.

This is the mechanism behind two symptoms already in the record and previously
unexplained: GLM 5.3 timing out at 120s per case after the panel had once sat for
19 minutes, and `todo.md`'s standing note that `ChatOpenRouter` is built with no
timeout. A 300-second retry budget with no deadline above it is how both happen.

**A related discovery: `llm_config`'s `max_llm_retries: 3` is dead config.**
`get_llm` accepts no such argument and `build_judge_llm` does not pass it. It has
never reached anything, in a file whose entire job is to state how panelists are
called.

### The callback layer cannot see the retries, and that killed a proposal

The assistant had proposed, earlier the same session, that a LangChain callback
handler be the capture mechanism — attached once at construction, catching sync
and async paths alike, and (it was argued) seeing each retry attempt. **The
argument was reasoning from library structure, and it was wrong.**

Totals alone could not settle where the retrying happened: twelve requests across
three callback runs fits both "four per run" and "twelve inside the first run,
then two that made none", and those imply opposite things. So the probe was
rebuilt to interleave socket traffic and callback events on one clock:

```
 0.00s  callback  chat_model_start run=…fa94b0db
 1.17s  wire      #1 gen-…X0lYRN3z  200 -> replaced with 500
 3.52s  wire      #2 gen-…JbnGFyiv  200 -> replaced with 500
 7.44s  wire      #3 gen-…wcoEo3zz  200 -> replaced with 500
11.03s  wire      #4 gen-…UYhmTo61  200 -> replaced with 500
14.48s  wire      #5 gen-…tYQ9lomA  200 -> replaced with 500
21.57s  wire      #6 gen-…hwAc8WXw  200 -> replaced with 500
26.14s  callback  llm_error run=…fa94b0db
27.61s  callback  chat_model_start run=…5a6a54f1     ← outer retry, 0 requests
29.71s  callback  chat_model_start run=…01ce04eb     ← outer retry, 0 requests
```

**All six requests happened inside the first callback run.** LangChain's outer
`.with_retry` is visible to a handler; everything beneath it is not. A handler
sees one `llm_end` carrying the last generation's id and cost — exactly what the
call site already had. The proposal bought nothing and was rejected.

It is written up in the design document rather than deleted, because without the
measurement it is the obvious design and someone will propose it again.

### The provider is free at the socket

The field `_create_chat_result` drops — established 2026-08-25 as the thing the
whole log was being built to recover — is **present in the raw body of every
request, retried attempts included**. All ten requests of the final run carried
`provider: Relace`.

This demotes the two-phase enrichment sweep from essential to supplementary. The
served provider, the generation id and the cost are all immediate; the 8–10
second generation-endpoint lag now gates only the routing chain, the native
finish reason and the upstream latency.

---

## The design that resulted

Three mechanisms were proposed in sequence and two were discarded. The sequence
matters, because each was discarded by a fact rather than by preference.

1. **A wrapper at the five judge call sites** (2026-08-25). Discarded when
   Bertan set the scope to *every* LLM call: the product path is synchronous —
   `generator.py:83,99`, `main_dev.py:39`, `ComplianceAgent.ask()` — so one
   `async def` wrapper cannot cover it, and trap 8 (a bypassed call site) gets
   worse with every site added.
2. **A callback handler at construction.** Discarded on the measurement above.
3. **A call-site wrapper *and* a patch on `httpx`** — what was built into the
   document. The two levels see genuinely different things: the wrapper knows
   *why* a call was made and nothing about what it cost; the socket knows exactly
   what it cost and nothing about why. Context crosses the gap through a
   `contextvars.ContextVar`, which each asyncio task copies at creation, so eight
   concurrent panelists each carry their own call id without locking.

A consequence worth stating: **an attempt row with a null `call_id` means a
request made outside any wrapper**, so the bypass trap now reports itself instead
of hiding.

### Three tables, and the third is the point

`llm_run` (one row per process), `llm_call` (one per logical call, from the
wrapper), `llm_attempt` (one per upstream HTTP request, from the socket).

**The true cost of a call is `SUM(llm_attempt.cost)`, and `llm_call.cost` is kept
beside it as what the caller believed.** The two are stored separately on
purpose: the gap between them is the undercount this project has been publishing,
and keeping both makes it a measurable quantity per run rather than a suspicion.
Enrichment moves onto the attempt as well, which means the routing chain of a
*failed* attempt becomes recoverable — and those are the interesting ones.

### Decisions Bertan took

- **Scope is every LLM call**, product path included.
- **Both capture levels**; **patch `httpx` in this repository**, with extending
  `ai_common.get_llm` to accept a client left open for later.
- **Supabase, session pooler on 5432.** This is not cosmetic: the transaction
  pooler on 6543 breaks asyncpg's prepared-statement cache, and the failures are
  intermittent and read as flakiness. Session mode needs no workaround.
- **Writes awaited inline on both paths**, product path included.
- **Alembic from the first commit**, overruling the assistant's proposal of
  `CREATE TABLE IF NOT EXISTS` plus additive columns. The assistant's argument
  was that one table does not justify it; Bertan's is that a remote database
  means a schema change is no longer "delete the file", and retrofitting
  migrations onto a table with rows in it is worse than starting with them.
- **The full raw text of failed calls is stored.**
- **No enum types in the database.** Enums are defined in code and enforced by
  the repository classes, which are the only writers. The flexibility is
  specific: `ALTER TYPE … ADD VALUE` does not sit comfortably in a migration and
  removing a value is not supported at all, so a roster change would otherwise
  become a migration against a live instance.
- **Cost is read from metadata, never computed** from token counts and a price
  table. `ai_common.price.py:47` reads
  `PRICE_USD_PER_MILLION_TOKENS[model_provider][model]` — one price per model id,
  keyed on `openrouter` — while the actual price is whatever Venice, CoreWeave or
  Parasail charged. A static number cannot represent a per-call quantity. The
  consequence is written down so it is not "fixed" later: a provider that reports
  no cost yields a null, and that null stands.
- **`llm_server` from `LlmServers`, `model` from `ModelNames`, repository writes
  `.value`.**
- **`served_provider` is verbatim free text**, never reconciled with
  `LlmServers`, with no exception for provider names that appear in the enum.

---

## The LLM server is not the provider, and the assistant's column name said it was

**Bertan's clarification, and it found a defect.** The distinction: the **LLM
server** is who we buy the call from — whose API key we hold. The **provider** is
who runs the machines the model executed on. The same company occupies both roles:
GPT-5.6 Luna Pro through an OpenRouter key lists OpenAI, Azure and Azure (EU) as
its providers, so `llm_server='openrouter'` with `served_provider='OpenAI'` is a
normal row, while the same model through an OpenAI key is `llm_server='openai'`.

The assistant had named the column **`provider_api`** — using *provider* for the
server concept, which is precisely the confusion the design most needed to avoid.
Renamed to `llm_server`.

Three consequences were drawn out and written down:

- **Only one column has a vocabulary we own.** `llm_server` is a closed set;
  `served_provider` is whatever string OpenRouter sends, from a catalogue we
  cannot enumerate. An unrecognised provider name is a fact about the world, not
  a bad row.
- **`served_provider` is null for every server except OpenRouter**, and that null
  is not a gap to fill. Writing `'openai'` for a direct OpenAI call would assert
  which machines ran it — something the response never said.
- **A direct call and a routed call must stay distinguishable.**
  `llm_server='openai'`+`NULL` and `llm_server='openrouter'`+`'OpenAI'` describe
  different situations, and collapsing them erases the variance the log exists to
  expose.

Bertan then closed the remaining latitude: `served_provider` is stored verbatim,
**with no special case for providers that also appear in `LlmServers`**. If
OpenRouter sends `OpenAI`, `Open AI` and `Open Ai` on three calls, all three are
written as they arrived. The argument recorded for it is directionality —
normalising at write time is irreversible and turns a record of the call into a
record of our opinion about it, while normalising at read time is a choice that
can be revised. `GROUP BY served_provider` returning several rows for one company
is therefore correct behaviour, not a defect.

---

## Three strings name one model, and the reports use a fourth thing

Raised by Bertan's instruction that the repository write `.value`. Checking what
that means in practice turned up a mismatch nobody had noticed.

| form | example | what it is |
|---|---|---|
| `.name` | `MINIMAX_M_3` | a Python identifier |
| `.value` | `minimax-m3` | platform-neutral canonical name |
| alias | `minimax/minimax-m3` | the wire id, from `get_model_name_alias` |

**Measured**: neither `ModelNames` nor `LlmServers` carries a `str` mixin, so
`str(member)` yields `ModelNames.MINIMAX_M_3` and
`member == 'minimax-m3'` is **`False`**. Three plausible shortcuts are wrong and
two of them fail silently — `str()`/f-strings produce a column that looks
populated and joins to nothing; an equality test against a member fails without
explaining itself; and `sqlalchemy.Enum(ModelNames)` stores `.name` while its
native form would create the database enum type that was just ruled out. Only
passing a member straight into a `String` column fails loudly.

**And `probe_a2_panel.py:156` writes `str(model).split(".", 1)[-1]` into every
committed report** — the member *name*, `DEEPSEEK_V_4_FLASH_0731`. The log will
store the *value*. The same panelist therefore appears under two spellings across
the two artefacts that are meant to be cross-checked against each other. The
mapping is lossless in code, so no column was added; the failure it causes is
human, and it is filed in `todo.md` as Bertan's call because changing the report
makes new reports stop matching old ones by grep.

`llm_attempt.model_alias` was added to hold the wire id, which arrives free in
the response body. That gives grouping by canonical name and matching against
OpenRouter's console without either being derived from the other by string
surgery.

---

## Verification

- **The retry finding was measured at the socket**, which is ground truth
  independent of which layer retried, and the failure injection was applied
  *after* a real generation so the billed attempts were genuine.
- **The layer attribution was settled by an interleaved timeline, not by
  arithmetic.** The totals were ambiguous between two readings that imply
  opposite mechanisms; the timeline distinguishes them by observation.
- **The `max_retries` mechanism was read from library source and is consistent
  with the observed backoff intervals** (1.17 → 3.52 → 7.44 → 11.03 → 14.48 →
  21.57s, a single growing sequence rather than three resets). The source
  reading is *not* independently confirmed by experiment — the probe's cap
  stopped the run before the 300-second budget expired, so **the true attempt
  ceiling is inferred, not measured**.
- **`provider` in the response body was confirmed on all ten requests** of the
  final run, retried attempts included.
- **The enum semantics were measured**, not read: mro, `.value`, `str()` and
  equality were all printed.
- **The suite was run** and is unchanged at 354 passed / 5 xfailed.
- **Not verified:** every claim about how SQLAlchemy, asyncpg and the Supabase
  session pooler behave under this workload. Nothing has connected to the
  database. The remote write latency is unmeasured and is the first thing to
  measure when the engine exists.
- **Not verified:** that `native_finish_reason` is absent from the response body.
  It is assigned to phase 2 in the schema on the assumption that it is; the
  design says to check at build time rather than assume either way.

---

## Mistakes made this session

All the assistant's unless stated.

- **A callback handler was proposed as the mechanism, from reading library
  structure rather than from observing it.** This is the same class of error as
  2026-08-25's `response_metadata["provider"]` claim. It differs in one respect
  that matters: it was flagged as unverified when it was made, and measured
  before any code depended on it, so it cost a probe rather than a session. The
  corrective is working; the reflex that produced the claim is not yet gone.
- **`provider_api` used the word "provider" for the supplier concept**, in a
  document whose central finding is that those two things are different. Bertan's
  clarification of the concept is what exposed it.
- **Connection-pool advice was given before the connection was known.** The
  assistant recommended `NullPool` plus a `statement_cache_size=0` workaround —
  correct for a transaction-mode pooler, wrong for the session pooler actually in
  use, where it would open and close a pooler session per write. Corrected once
  Bertan confirmed the mode, but it was offered as a recommendation first and
  qualified second, which is the wrong order.
- **A 5-second connect timeout was recommended for a serverless instance** that
  can take seconds to cold-start. Revised to 10 seconds plus a warm-up connection
  at run start.
- **The first probe run used a cap of 12 and hit it**, producing totals that
  admitted two incompatible readings. The probe had to be rebuilt and re-run.
  Recorded because the fix — interleaving the two event streams — should have
  been the first design, not the second.

---

## State handed to the next session

| | |
|---|---|
| `clause-and-effect` | `dev-04` at `868c344`, **41 ahead of `main`**, two commits this session, pushed |
| Working tree | clean |
| `ai-common` | untouched; read for `get_llm`, `price.py` and `enums.py` |
| Suite | **354 passed / 5 xfailed**, unchanged |
| Design | [`llm-call-log.md`](../design/llm-call-log.md) — **23 decisions, 11 traps, nothing built** |
| Panel | verdict derivation, aggregation and calibration **still not built** |

## Open items — start here next session

| # | open item | state |
|---|---:|---|
| 1 | **Build the call log.** `src/db/` with `models/` and `repos/`, Alembic, the three tables, `llm_call()` in both flavours, the `httpx` patch, the enrichment sweep. Three new dependencies — `sqlalchemy`, `asyncpg`, `alembic` — through the GuardDog gate first | **the build** |
| 2 | **Measure the remote write latency** as soon as the engine connects. It is the one number the design quotes a local stand-in for | first measurement |
| 3 | **Give the model call a timeout.** The 300-second inner retry budget has no deadline above it; until one exists a stalled panelist can spend fifteen minutes and an unbounded amount of money | new, and it subsumes an older `todo.md` item |
| 4 | **`max_llm_retries` in `llm_config` is dead config** and should be removed or wired up | new, mechanical |
| 5 | **Pin the provider per panelist.** The log makes routing visible; it does not make it stable. Panel-wide or MiniMax only, and which provider MiniMax gets. **Bertan's call** | carried, decision |
| 6 | **Correct `llm_config.py`** — the "MiniMax accepts no tools" comment is false, and the `structured_output` table is confounded by unrecorded providers | carried |
| 7 | **Re-measure the channel table under pinned providers** | carried |
| 8 | **Demote LangSmith to opt-in** behind one entry-point setup function | carried, decided in principle |
| 9 | **`short_name` writes the enum's member name; the log writes its value.** Three options filed in `todo.md`. **Bertan's call** | new |
| 10 | **Report the dropped `provider` upstream** to `langchain_openrouter` | carried, optional |
| 11 | **The coverage metric calls a one-conjunction difference UNSTABLE.** Nested vs crossing, designed and not built. **Bertan's call** | carried |
| 12 | **Nine call sites still index the roster with `[0]`**, `main_dev.py` with `[5]`; `llm_config.panelist` exists | carried, mechanical |
| 13 | **Verdict derivation (§7), aggregation into `CaseJudgement`, calibration (§9)** — the actual panel. Nothing built | carried, **the main task** |
| 14 | **A second stability sample at N=25**; **repeats per panelist**; **the reasoning-channel repeat** — all three want the provider recorded, which is item 1 | carried |
| 15 | **Re-derive design §8.2**; **`art15_case1` is the case the panel splits on** | carried |
| 16 | **`gdpr_test_data_generation.py:150` raises `KeyError: 'orchestrator_model'`**; **`ai_common.get_llm` mutates its argument** | carried |
| 17 | **Reject degenerate claims in `stage_a2.py`**; **measure beyond the six**; **`art7_case4`'s third sentence: core or auxiliary** (Bertan's call) | carried |
| 18 | `judge.py` and thirteen `scripts/` files print rather than log | carried, flagged |
| 19 | Everything else on the 2026-08-23 list — the A1↔A2 consistency check, the atomicity rule, §4.6's metric, `art8_case5`, GLM parked on latency | carried |
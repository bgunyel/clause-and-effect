# The LLM call log

> **Status: draft, and deliberately not final.** Nothing described here is
> built. This document breaks the rule stated in [`README.md`](README.md) — that
> `design/` describes mechanisms that *exist* — and it does so knowingly,
> because the alternative was losing a session's worth of reasoning to a chat
> transcript. It is a working document to be finished at the start of the next
> session, at which point the status banner comes off and everything still
> marked *open* has been decided or moved to `todo.md`.
>
> Read every unmarked statement as a proposal, not a description. Statements
> marked **measured** are observations with the numbers attached; everything
> else is argument.

---

## What this is for

**Which server answered a model call is not recorded anywhere, and it decides
the result.**

That sentence is the whole justification, and it was established on 2026-08-25
rather than assumed. Investigating why MiniMax M3 had started failing the
structured-output channel it was assigned on 6/6 evidence produced this:

| run | MiniMax score | upstream provider |
|---|---|---|
| 2026-08-23 `162138`, function_calling | **6/6** | **Venice** ×6 |
| 2026-08-23 `165801`, function_calling | **2/6** | **Parasail** ×5, Venice ×1 |
| 2026-08-23 `181319`, json_schema | **6/6** | **CoreWeave** ×6 |
| 2026-08-25 reasoning-channel | **0/2**, both channels | **Parasail** ×4 |

OpenRouter routes one model id to whichever upstream provider it picks, and the
providers differ in what they can actually do. For `minimax/minimax-m3`, from
OpenRouter's own endpoint listing (**measured**, `/api/v1/models/.../endpoints`):

| provider | `tools` | `response_format` | `structured_outputs` |
|---|---|---|---|
| Venice | ✅ | ❌ | ❌ |
| CoreWeave | ❌ | ✅ | ✅ |
| Parasail | ✅ | ✅ | ✅ |

Every MiniMax success on record came from Venice (tools) or CoreWeave
(`response_format`); every failure came from Parasail, which advertises both and
delivers neither. And OpenRouter reaches the working providers **by falling
back** — the routing chain for one 2026-08-23 call reads `Parasail:429 →
Venice:200`. The panel's structured-output channel for MiniMax was therefore
chosen on evidence produced by a rate limiter.

This generalises past MiniMax. Within a single four-minute run on 2026-08-25,
with the provider read back afterwards from the generation endpoint:

- DeepSeek V4 Pro was served by **Alibaba**, **Sail Research** and **Together**
- Qwen 3.8-27B by **AkashML**, **Phala** and **Io Net**, having also been served
  by **Reka** the day before, with **CoreWeave**, **Venice** and **Parasail**
  refusing at various points
- Qwen 3.8-2.4T by **DeepInfra**, **SiliconFlow** and **Modal**

`llm_config.py` states that every panelist runs identical settings so that a
disagreement between two of them is a disagreement *about the case*. That
premise is broken one layer below the configuration: the same panelist is not
the same server from one call to the next, and until 2026-08-25 nothing recorded
which one it was.

A second finding of the same shape sits alongside it. DeepSeek V4 Pro's clean
zero in the 2026-08-25 reasoning-token sample — one of the two observations that
produced the `INTERMITTENT` verdict — was the call **Together** served; its 2663
reasoning tokens on the other case came from **Sail Research**. A model
compared against itself was two different machines.

**So the log exists to make a call attributable.** Not to reproduce it — that is
a different and probably unreachable goal — but to answer, months later and
without a login to anyone's console, *which server answered, under what routing
constraint, at what price, and did it fall back to get there.*

### What made this urgent rather than merely desirable

Every fact in the section above was recovered by hand, after the fact, from
OpenRouter's web console and its generation endpoint, using generation ids that
only existed because they were added to `CallRecord` the same morning. The three
2026-08-23 panel reports carry **no generation ids at all**, so the provider that
served them was recoverable only by cost-matching console rows against report
totals — which worked (Venice ×6 sums to $0.008409 against the report's
$0.008409; CoreWeave ×6 to $0.002413 against $0.002412) but is not a method
anyone should have to use twice.

The account API cannot substitute for recording it: `/api/v1/activity` returns
`403 — Only management keys can fetch activity for an account`, and there is no
list-generations endpoint. Without a local record, the evidence is whatever the
console still shows.

---

## What is obtainable about a call, and when

**Measured 2026-08-25.** This table is the single most load-bearing thing in the
document, because it is what forces the mechanism's shape.

| fact | where it lives | cost to obtain |
|---|---|---|
| generation id, cost, prompt / completion / reasoning tokens, finish reason, model name, system fingerprint | `response_metadata` and `usage_metadata` on the returned message | free, immediate |
| **served provider** | present on the wire, **dropped by the client library** | needs interception, or the generation endpoint |
| routing chain (`Parasail:429 → Venice:200`), native finish reason, upstream latency, generation time | `/api/v1/generation` only | **8–10 second lag** |

### The served provider does not reach the message

`langchain_openrouter/chat_models.py:870` assigns
`message.response_metadata["provider"]`, and reading that line is what led to
the claim — stated twice during the session, and wrong — that the provider was
available for free. **Measured on the real judge path** (`build_judge_llm` with
`_A2Claims`, DeepSeek V4 Flash, function calling):

```
response_metadata keys: ['cost', 'cost_details', 'created', 'finish_reason',
                         'id', 'logprobs', 'model_name', 'model_provider', 'object']
provider -> None
id       -> gen-1787646818-aX4Lbti4cBnbhy1WZ5Pi
cost     -> 0.00010164
```

The same call's raw HTTP response body, taken directly from
`/api/v1/chat/completions`:

```
top-level keys: ['choices', 'created', 'id', 'model', 'object', 'provider',
                 'service_tier', 'system_fingerprint', 'usage']
provider field: Morph
```

So OpenRouter sends it and the client loses it. `_create_chat_result` calls
`response.model_dump(by_alias=True)` on the SDK response object; declared fields
such as `system_fingerprint` survive that dump and `provider` does not. The
mechanism was not chased further, because for our purposes the observation is
sufficient and the workaround does not depend on the cause.

*Open: whether to report this upstream as well as working around it locally.*

### The generation record is not readable immediately

**Measured** — three calls, polling `/api/v1/generation` every 100 ms from the
moment `ainvoke` returned:

```
call 1: readable after 9321ms (24 attempts)   chain: OpenInference:200
call 2: readable after 9735ms (27 attempts)   chain: Inceptron:200
call 3: readable after 8044ms (22 attempts)   chain: DeepInfra:200
```

OpenRouter writes the generation record asynchronously. For roughly nine seconds
after a response arrives, **the data does not exist**. This is why the log is
two-phase; it is not a design preference.

For scale: DeepSeek V4 Flash, the fastest panelist, answers a real A2 prompt in
about 7 seconds. Blocking each call on its own enrichment would more than double
the run.

---

## The shape of the mechanism

### `llm_call()` — one wrapper, five call sites

Five stages repeat the same two lines today:

```
src/eval/sufficiency/stage_a.py:326-327
src/eval/sufficiency/stage_a1.py:158-160
src/eval/sufficiency/stage_a2.py:230-232
src/eval/sufficiency/stage_b.py:147-148
src/eval/sufficiency/stage_c.py:275-277
```

each of the form `build_judge_llm(...)` followed by
`require_response(await llm.ainvoke(prompt), stage=...)`. A single wrapper
replaces both lines everywhere: it invokes, times the invocation, builds the
`CallRecord`, writes the row, and returns the `StageResponse`.

One wrapper rather than logging inside `require_response` — which is the other
obvious chokepoint — because `require_response` receives the payload and not the
context. Which case, which run, which channel and how long the call took are all
known at the stage call site and nowhere below it.

**Failure paths are logged too, and that is most of the point.** A call that
raised `JudgeResponseError` was still made, still billed, and still exists at the
provider under an id — and on the evidence of 2026-08-25 it is disproportionately
likely to be the interesting one. The exception already carries a `CallRecord`
for exactly this reason.

### The timed region excludes the write

The measurement the eval cares about is the model's latency, so the timer
brackets `await llm.ainvoke(...)` and stops before anything is written. A run's
wall clock does include the writes; the per-call latency column does not.

This was Bertan's correction, and it holds even though the write is cheap. For a
**local** SQLite file the cost is negligible — **measured**, 300 single-row
commits with a realistic 19-column row:

| mode | median | p95 | max |
|---|---|---|---|
| default journal, `synchronous=FULL` | 3.226 ms | 6.128 ms | 19.167 ms |
| WAL, `synchronous=NORMAL` | **0.012 ms** | 0.022 ms | 0.050 ms |

**That measurement no longer describes the chosen storage.** A remote Postgres
insert is a network round trip and will be some orders of magnitude slower. It
is kept here because it establishes the shape of the argument and because it is
the number a local fallback would have; the remote number is **unmeasured** and
is the first thing to measure once a database URL exists.

### Two-phase rows

A row is written immediately with everything the message carries, and is
completed later — at the end of the script, or the next day, or never — by a
sweep that fetches `/api/v1/generation` for ids whose enrichment is still null.

```
UPDATE ... WHERE enriched_at IS NULL AND generation_id IS NOT NULL
```

The sweep is idempotent and interruptible, and a row that is never enriched is
still a true record of what was known at call time. What must not happen is a
row that *looks* complete while its provider column is empty because nobody ran
the sweep — hence `enriched_at` as an explicit marker rather than inferring it
from a null provider.

*Open: whether the sweep runs automatically at script exit or only as a separate
command. Bertan's phrasing — "immediately after a model call (or right before
exiting the particular script/function/endpoint)" — permits either.*

---

## Storage

**Decision: a remote PostgreSQL instance, reached through SQLAlchemy, addressed
by a URL that may be absent.**

### Why not a local SQLite file

Two options were considered and both rejected, for different reasons.

**Gitignored local file.** Every record then lives on one disk with no backup.
Rejected on that alone.

**Committed to the repository.** The repository is public. The file would
publish every prompt, every gold answer and every cost we have ever logged, and
it would do so as a binary that produces a new blob on every run. Rejected.

### Why remote Postgres

It answers both objections at once — the data is backed up by someone whose job
that is, and it is not in the public repository — and it makes records from more
than one machine aggregate into one place, which a local file cannot.

The cost is that the eval acquires an infrastructure dependency it did not have,
and two new packages (`sqlalchemy`, plus an async driver) which must pass the
GuardDog gate before they can land.

### The optional URL

`llm_call()` checks for a configured database URL after the model call. If there
is one, it writes; if not, it does not. Proposed as
`LLM_LOG_DATABASE_URL: SecretStr = ""` in `src/config.py`, matching the existing
style of `OPENROUTER_API_KEY`.

**Absent must be the default**, so that the test suite is hermetic by
construction rather than by remembering to unset something, and so that a fresh
clone runs without infrastructure. A test that writes to the real log would
corrupt the record it exists to verify.

---

## Failure policy

Two rules, and they are in tension with each other on purpose.

**1. A logging failure must never fail a judged call.** The judgement is the
valuable output; the row is bookkeeping. An unreachable database must not turn a
completed panel run into a crashed one. So: catch, do not raise.

**2. A logging failure must never be silent.** An instrument that quietly drops
records is the same defect class as every other finding this project has made
this month. So the run counts its misses and reports them —
*"148 of 150 calls logged; 2 writes failed"* — and each failure goes through
`logging` at warning level.

A statement and connection timeout is required, so that an unreachable database
causes skipped writes rather than a stalled run. *Open: what the timeout should
be. It must be short relative to a model call.*

---

## Schema (draft)

Two tables proposed, though one would work. *Open: whether run-level facts are
normalised out or repeated on every row.*

**`llm_run`** — one row per script invocation:

| column | source | notes |
|---|---|---|
| `run_id` | generated | uuid; the join key |
| `script` | caller | e.g. `probe_a2_stability.py` |
| `commit_sha`, `git_dirty` | `chunk_store.git_state` | the existing helper reports both |
| `started_at`, `finished_at` | caller | |
| `hostname` | caller | for when runs come from more than one machine |

**`llm_call`** — one row per model call:

| column | phase | source |
|---|---|---|
| `run_id` | 1 | the run |
| `stage`, `case_id` | 1 | call site |
| `model`, `channel` | 1 | the config entry |
| `requested_provider` | 1 | the `provider` constraint we sent, as JSON |
| `generation_id` | 1 | `response_metadata['id']` |
| `status` | 1 | `OK` / `STRUCTURE` / `TIMEOUT` / `TRANSPORT` |
| `call_seconds` | 1 | the bare `ainvoke`, timer stopped before the write |
| `cost` | 1 | `response_metadata['cost']` |
| `prompt_tokens`, `completion_tokens`, `reasoning_tokens` | 1 | `usage_metadata` |
| `finish_reason` | 1 | `response_metadata` |
| `raw_output` | 1 | **open** — see below |
| `served_provider` | 2 | generation endpoint |
| `routing_chain` | 2 | e.g. `Parasail:429 -> Venice:200` |
| `native_finish_reason`, `generation_time`, `latency` | 2 | generation endpoint |
| `enriched_at` | 2 | null until the sweep runs |

Nullability follows the existing `CallRecord` doctrine, which should be restated
in the table's own comments: **every column is null for one reason only — the
provider did not report it — and null is never zero.** A call reporting
`reasoning: 0` did not reason; a call reporting nothing may have reasoned freely
and not said so, and the two must not average together.

### What is deliberately not stored

**The prompt.** It is reproducible: a prompt is a pure function of the case id,
the stage and the template at a given commit, and `commit_sha` is on the run.
Storing it would multiply the table's size by a large factor and duplicate what
is already in `data/tier-1/` and in git.

This makes `commit_sha` load-bearing rather than decorative. If the prompt
templates change and the commit is not recorded, the prompt is *not*
reconstructible and this decision becomes wrong retroactively. *Open: whether
that is a strong enough guarantee, or whether a prompt hash should be stored so
that a mismatch is at least detectable.*

**The successful output.** It is in the eval report and in the parsed value.

**The failed output is a different matter** and probably should be stored in
full. `JudgeResponseError` currently truncates at 300 characters
(`llm.py:_EXCERPT_CHARS`), which on 2026-08-25 was exactly the gap: MiniMax's
failure read `Invalid json output: ` with nothing before the newline, and
whether the content was genuinely empty or merely unparseable is *still* not
known, because the excerpt did not reach far enough and the message was gone.
Failures are rare, so the storage cost is small. *Open, but leaning strongly
toward storing it.*

---

## What LangSmith does and does not cover

LangSmith is currently enabled in exactly one place — `src/main_dev.py:27-29`,
three environment variables set inside `main()`. **No probe and not `judge.py`
enables it**, so every panel run, both stability samples and the
reasoning-channel probe were untraced.

The initial proposal in this session was to enable it everywhere and let it do
the heavy lifting for prompts and outputs. That proposal is **withdrawn**, on
two grounds:

1. Bertan's own experiment found its performance unsatisfactory. The cause is
   undiagnosed — it may be the OpenRouter client, it may be free-tier ingest
   limits.
2. More importantly, our workload is close to its worst case, and the reasons
   are structural rather than tier-dependent. Every run serialises inputs and
   outputs, and our payloads are large; one judge call is not one run, because
   `with_structured_output(include_raw=True).with_retry(stop_after_attempt=3)`
   is a nested tree, so a 150-call stability sample sends several hundred runs
   with payloads attached; and it is an in-process network round trip on every
   one of them.

**What demoting it costs is less than it appears**, for the reason given above:
our prompts are reproducible from the case id, the stage and the commit. The one
genuinely irrecoverable artefact is the raw text of a failed call, and the
database can hold that itself.

**Proposed division of labour.** The database is the system of record — what
happened, what it cost, who served it, how long it took, and what a failure
said. LangSmith becomes opt-in, behind the same entry-point setup function, and
is turned on where a trace earns its keep: `ComplianceAgent` is a genuine
multi-step tree and is worth looking at interactively. Eval probes run with it
off.

A side effect worth stating: with tracing off by default, prompts and gold
answers stop leaving the machine on every eval run.

*Open: whether the separate LangSmith project chosen earlier in the session
(`clause-and-effect-eval`, so that eval traces do not bury the product's) is
still wanted once tracing is opt-in. It probably is, for the runs that do get
traced.*

---

## Open questions

Carried into the next session. None of these is blocking the others.

1. **Where does the Postgres instance live?** A serverless one (Neon, Supabase)
   has cold-start latency and connection-limit behaviour that pooled async
   writes must account for; a plain managed or self-hosted instance does not.
   This changes the engine setup and nothing else.
2. **Async driver.** `create_async_engine` with `asyncpg`, or a synchronous
   session wrapped in `asyncio.to_thread`. See the traps section — this one has
   teeth.
3. **One table or two.** Normalising run-level facts into `llm_run` against
   repeating them on every call row.
4. **Store the raw text of failed calls?** Leaning yes, in full.
5. **Store a prompt hash**, so that a template change is at least detectable
   even though the prompt itself is not stored?
6. **When does the enrichment sweep run** — automatically at script exit, or
   only as an explicit command?
7. **Migrations.** One table does not justify Alembic, but a remote database
   means a schema change is no longer "delete the file". Additive columns and
   `CREATE TABLE IF NOT EXISTS` are proposed until that stops being enough.
8. **Scope.** The wrapper covers the five judge stages. The product path —
   `ComplianceAgent`, and `main_dev.py` — calls `ai_common.get_llm` directly and
   would not be logged. Is that the intent?
9. **Retention.** Nothing here ever deletes a row. At current volumes that is
   fine for years; it should still be a decision rather than an oversight.
10. **Timeout values** for connect and statement.
11. **Report the dropped `provider` upstream** to `langchain_openrouter`?

---

## Traps identified but not yet handled

These are the failure modes that were spotted while designing and that the
implementation must actively avoid. They are recorded because each one would be
silent.

**1. A synchronous insert inside an async stage serialises the panel.** The
stages are `async` and the probes run panelists concurrently. A blocking
database call inside the event loop makes eight concurrent panelists take turns
waiting on the network, degrading the run's concurrency without any error and
without any obvious symptom other than a run that feels slow. This is the trap
most likely to be discovered from a latency table weeks later.

**2. Retries produce generations that are never seen.** `build_judge_llm`
attaches `.with_retry(stop_after_attempt=3)`. A retried call produces more than
one generation at the provider, each billed, and the returned message carries
only the last one's id. **Every cost total this project has reported may
therefore be an undercount**, and the log as designed would inherit the same
blind spot: one row per logical call, and no row for the attempts that failed
inside the retry. Whether the callback layer can see them is not known and needs
checking.

**3. The generation endpoint's nine-second lag is not a constant.** It was
measured three times on one model at one time of day. A sweep that assumes ten
seconds is enough will silently leave rows unenriched under load. The sweep
should therefore be re-runnable and record its failures, not assume success.

**4. `enriched_at` must be set even when enrichment finds nothing**, or every
sweep will re-fetch the same permanently-missing generations forever. A
distinction between *not yet swept* and *swept, nothing there* is needed.

**5. Tests must never write to the real database.** Covered by the empty-URL
default, but it needs a test that asserts it, since the failure is invisible
until someone inspects the table and finds fixture data in it.

**6. The database URL is a secret** and will contain a password. It belongs in
`.env` as a `SecretStr`, and must not reach a log line, an exception message or
a committed report. Connection errors love to quote the URL.

**7. `requested_provider` and `served_provider` are different columns for a
reason.** Once providers are pinned, it will be tempting to treat the pin as the
answer. The whole finding of 2026-08-25 is that what we asked for and what
answered are not the same thing, and a row that records only the request would
have been unable to show it.

**8. Nothing here helps if the wrapper is bypassed.** Five call sites use it
today; a sixth stage written next month that calls `ainvoke` directly is
unlogged and nothing will say so. *Open: whether that can be made structurally
impossible rather than conventional.*

---

## Known gaps

- **The mechanism does not exist.** This document describes a design, not code.
- **The remote write latency is unmeasured**, and the local SQLite figures
  quoted above do not stand in for it.
- **Provider pinning is a separate, related decision** and is not part of this
  document. The log makes routing *visible*; it does not make it *stable*. The
  decision on whether to pin every panelist to one upstream provider, and which
  provider MiniMax should be pinned to, is open in `todo.md`.
- **The confounded `structured_output` table in `llm_config.py` is not fixed by
  this document either**, and one of its comments — that MiniMax's endpoint
  accepts no tools at all — is now known to be false. Venice served it 6/6 on
  tool calls.

---

**Verified against:** nothing. No code implements this. The measurements quoted
were taken on 2026-08-25 at commit `71b8f78`, against `langchain_openrouter` and
`langsmith 0.11.1` as pinned in `uv.lock` on that date. When this document
stops being a draft, this line names the commit it was checked against.
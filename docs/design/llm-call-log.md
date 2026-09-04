# The LLM call log

> **Status: the logical-call half is built; the attempt half is not.** As of
> 2026-09-04:
>
> | | |
> |---|---|
> | **Built** | the engines and the `DB_URL` gate (`src/db/engine.py`), the three tables (`src/db/models/`), Alembic and the initial migration (`alembic.ini`, `migrations/`), the repository layer (`src/db/repos/`), the contexts and the recorder (`src/db/capture/`), the async `llm_call()` wrapper (`src/llm/call.py`), wired at all five judge stages |
> | **Applied** | the schema is live on the Supabase instance, three tables, **no rows** — every probe has deleted its own |
> | **Not built** | `llm_call_sync()`, the `httpx` patch, the enrichment sweep — so `llm_attempt` is never written and `SUM(llm_attempt.cost)` has no rows to sum |
>
> So the document is part description and part specification, and the two are
> marked: a section describing code that exists names the file. Where the build
> contradicted the design the design has been corrected in place, with the
> correction marked and dated — this directory's documents are current state,
> not history, and the history is in git. Two such corrections and five
> deliberate departures are collected under [*What the build
> changed*](#what-the-build-changed).
>
> Statements marked **measured** are observations with numbers attached.
> Everything else is a decision or the argument for one.

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

### A second reason arrived on 2026-08-26

The design started as a provider-attribution problem. Measuring it turned up a
larger one: **most of what a failing call costs is currently invisible, and the
reported cost of such a call can be a third of the truth.** That is
[the retry finding](#what-each-layer-can-see) below, and it is why the log has
two levels rather than one.

### What made this urgent rather than merely desirable

Every fact in the first section was recovered by hand, after the fact, from
OpenRouter's web console and its generation endpoint, using generation ids that
only existed because they were added to `CallRecord` the same morning. The three
2026-08-23 panel reports carry **no generation ids at all**, so the provider that
served them was recoverable only by cost-matching console rows against report
totals — which worked (Venice ×6 sums to $0.008409 against the report's
$0.008409; CoreWeave ×6 to $0.002413 against $0.002412) but is not a method
anyone should have to use twice.

### The generation id is the only key, and nothing hands it back

**This is the reason the log has to exist rather than merely being useful, and
it is a fact about OpenRouter's API rather than an inference from our
experience.** Established 2026-08-26 by Bertan, from OpenRouter's own
documentation:

> The `/generation` and `/generation/content` endpoints only fetch a **single
> generation by its id** — there's no documented endpoint that lists or
> enumerates generation IDs within a date range.
>
> The closest thing for date-range querying is the Activity API
> (`GET /activity`), which returns **aggregated usage stats per day and
> endpoint** over a date range, but it does not return individual generation
> IDs. Individual generation records with IDs are otherwise viewable in the
> **Logs page in the dashboard**, not via a listing API.

The consequence is sharper than "the data is inconvenient to reach". **A
generation whose id we did not capture at call time is unreachable by API,
permanently.** Not slow to find — unreachable. The only lookup takes the id as
input, so there is no query that starts from a time, a model, a case or a run
and arrives at a generation. Nothing recovers an id that was never written down.

Three things follow, and each of them is load-bearing for a decision below.

**The capture must happen at call time or not at all.** There is no sweep that
could go back and collect what was missed, which is why the enrichment pass is
described as *completing* rows rather than *finding* them, and why an
`llm_attempt` row is written the moment the socket sees a response rather than
after the call resolves.

**`/api/v1/activity` cannot substitute for it on two independent counts.** It is
aggregated per day and endpoint, so it could not attribute a call to a case or a
panelist even if we could read it; and we cannot — it returns `403 — Only
management keys can fetch activity for an account`. Either failure alone would
be enough.

**The dashboard is not a fallback.** It is the one place individual records with
ids appear, and it is a web page: manual, unqueryable, unjoinable to a case id,
and subject to whatever retention OpenRouter chooses. The cost-matching
described above is what depending on it looks like in practice.

This compounds with [the retry finding](#a-callback-handler-cannot-see-the-retries)
in a way worth stating plainly. The attempts a retry swallowed produce real,
billed generations whose ids **no layer above the socket ever sees**. Under this
API those generations are not merely unaccounted — they are unreachable by any
means except scrolling a dashboard, with nothing to match them against. Every
one of them is money spent that no query will ever be able to name. That is what
`llm_attempt` is for.

---

## What each layer can see

**This section is what forces the mechanism's shape, and every claim in it was
measured rather than read off library source.** That distinction is not
pedantry: on 2026-08-25 the assistant asserted twice, from reading
`langchain_openrouter/chat_models.py:870`, that the served provider was available
on the returned message. It is not. The correction cost a session, and the rule
it produced is that a claim about a layer's behaviour is worth nothing until the
layer has been observed doing it.

Measurements below are from `scripts/probe_retry_visibility.py`, run 2026-08-26,
and from the 2026-08-25 probes named inline.

### There are four layers, and they see different things

| layer | sees | misses |
|---|---|---|
| the call site (`await llm.ainvoke(...)`) | the value, the last generation's id and cost, its own wall clock | every retried attempt |
| a LangChain callback handler | the same, plus the *outer* `.with_retry` attempts | every retry beneath it — **measured** |
| the HTTP socket | **every** upstream request: id, cost, tokens, **and the served provider** | which logical call it belonged to |
| `/api/v1/generation` | the routing chain, native finish reason, upstream latency | nothing, but only after **8–10 seconds** |

### The served provider does not reach the message, but it is on the wire

`langchain_openrouter/chat_models.py:870` assigns
`message.response_metadata["provider"]`, and reading that line is what produced
the wrong claim. **Measured on the real judge path** (`build_structured_llm` with
`_A2Claims`, DeepSeek V4 Flash, function calling):

```
response_metadata keys: ['cost', 'cost_details', 'created', 'finish_reason',
                         'id', 'logprobs', 'model_name', 'model_provider', 'object']
provider -> None
```

The same call's raw HTTP response body, taken directly from
`/api/v1/chat/completions`:

```
top-level keys: ['choices', 'created', 'id', 'model', 'object', 'provider',
                 'service_tier', 'system_fingerprint', 'usage']
provider field: Morph
```

OpenRouter sends it and the client loses it. `_create_chat_result` calls
`response.model_dump(by_alias=True)` on the SDK response object; declared fields
such as `system_fingerprint` survive that dump and `provider` does not.

**This is the field the whole log was commissioned to record, and it is free at
the socket.** Confirmed again 2026-08-26: all ten requests the retry probe
forwarded carried `provider: Relace` in the body, retried attempts included.
Capturing at the HTTP layer therefore gets the served provider *immediately*,
with no enrichment lag — which demotes the two-phase sweep from essential to
supplementary.

### A callback handler cannot see the retries

This was proposed as the mechanism on 2026-08-26 and **the measurement killed
it**, which is why it is recorded here rather than quietly dropped.

The probe forwards each request to OpenRouter for real, records the response,
and only then replaces it with a 500 — so every attempt is a genuine, billed
generation. A synthetic failure that never leaves the machine would have made
the undercount unmeasurable by construction.

| scenario | upstream requests | callback runs | generations the caller can name | cost unaccounted |
|---|---|---|---|---|
| async, fails twice then succeeds | 3 | **1** | 1 | **$0.00003026 of $0.00004551 — 67%** |
| async, fails throughout (capped at 6) | 6 | 3 | **0** | **100%** |
| sync, clean first call | 1 | 1 | 1 | 0 |

The interleaved timeline is what settles *which* layer retried, and totals alone
could not have:

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
`.with_retry(stop_after_attempt=3)` is visible to a handler — three runs, three
errors — and everything beneath it is not. A handler sees one `llm_end` carrying
the last generation's id and cost, which is precisely what the call site already
has.

### `max_retries` is not a retry count

`chat_models.py:457-466` converts `max_retries` into a *time budget*:

```python
if self.max_retries > 0:
    client_kwargs["retry_config"] = RetryConfig(
        strategy="backoff",
        backoff=BackoffStrategy(initial_interval=500, max_interval=60000,
                                exponent=1.5,
                                max_elapsed_time=self.max_retries * 150_000),
        retry_connection_errors=True)
```

`max_retries` defaults to **2**, and nothing in `ai_common.get_llm` overrides it,
so every panelist retries with exponential backoff **for up to 300 seconds, with
no limit on the number of attempts**. The probe's own cap stopped scenario 2 at
six requests in 26 seconds; the layer itself was nowhere near finished.

Multiplied by the outer `.with_retry(3)`, one logical judge call has a
**fifteen-minute worst case and an unbounded number of billed generations**.
This is the mechanism behind an already-recorded symptom: GLM 5.3 was dropped
from the roster for timing out at 120s per case after the panel had once sat for
19 minutes, and `todo.md` separately notes that `ChatOpenRouter` is built with no
timeout. A 300-second retry budget with no deadline above it is how both happen.

`llm_config` carries `max_llm_retries: 3`, but `get_llm` accepts no such
argument and `build_structured_llm` does not pass it. **It is dead config** and is not
the layer described here.

### The generation record is not readable immediately

**Measured 2026-08-25** — three calls, polling `/api/v1/generation` every 100 ms
from the moment `ainvoke` returned:

```
call 1: readable after 9321ms (24 attempts)   chain: OpenInference:200
call 2: readable after 9735ms (27 attempts)   chain: Inceptron:200
call 3: readable after 8044ms (22 attempts)   chain: DeepInfra:200
```

OpenRouter writes the generation record asynchronously. For roughly nine seconds
after a response arrives, **the data does not exist**. For scale: DeepSeek V4
Flash, the fastest panelist, answers a real A2 prompt in about 7 seconds.

Since the socket now supplies the provider, the cost and the id directly, this
lag no longer gates anything the log needs to be useful. It gates only the
routing chain, the native finish reason and the upstream latency.

---

## The shape of the mechanism

### Two capture points, and no callback handler

**Decision — Bertan, 2026-08-26: capture at both levels.**

| what | where it is written | what it records |
|---|---|---|
| the **logical call** | a thin `llm_call()` wrapper at each call site | which case, which stage, which model and channel, what the caller ended up holding, how long it took |
| the **upstream attempts** | a patch on `httpx`'s send methods | every request that actually reached OpenRouter: generation id, served provider, cost, tokens, status |

A LangChain callback handler is **considered and rejected**, on the measurement
above: it sees no more than the call site does about attempts, so it would add a
third integration point and buy nothing. Recorded rather than omitted, because
without the measurement it is the obvious design and someone will propose it
again.

The two levels are not redundant. The wrapper knows *why* a call was made and
nothing about what it cost; the socket knows exactly what it cost and nothing
about why. Neither can be derived from the other.

### Context reaches the socket through a `contextvar`

The socket sees an HTTP request with no idea which case or stage produced it.
The wrapper sets a `contextvars.ContextVar` holding the run id, the call id, the
stage and the case id; the patch reads it when a request passes.

`contextvars` are the right primitive rather than a convenience: each asyncio
task gets its own copy of the context at creation, so eight panelists running
concurrently each see their own call id with no locking and no leakage between
them. The same mechanism works unchanged on the synchronous product path.

**An attempt row with a null call id is a feature, not a gap.** It means a
request was made outside any wrapper — which is exactly the bypass that trap 8
worries about, and this way the log reports it instead of missing it.

### One wrapper, at every call site

`src/llm/call.py`. The five judge stages used to repeat the same two lines —
`build_judge_llm(...)` followed by
`require_response(await llm.ainvoke(prompt), stage=...)`. The wrapper replaces
both: it sets the context, invokes, times the invocation, writes the row, and
returns the response.

**Scope is every LLM call, not only the judge's** — Bertan, 2026-08-26. That is
why the wrapper does not live in `src/eval/sufficiency/`, which is where it was
first built. On 2026-08-26 it moved to `src/llm/`, a tier beside `config.py`
that both halves of the project can reach, together with everything else in that
module that encoded a fact about LangChain and OpenRouter rather than about the
judge: `build_structured_llm` (renamed — nothing about it judges),
`StructuredPayload`, `payload_from_tool_call`, `sum_costs`, `CallRecord`,
`LlmResponse`, and the classification of the four statuses.
`src/eval/sufficiency/llm.py` is now an adapter holding the judge's vocabulary:
`JudgeResponseError`, `StageResponse`, and the `stage=` labels.

**Sequencing, and it is not the obvious one** — Bertan, 2026-08-26. Promoting
code after it works is usually cheaper than promoting it during, but the socket
patch reads the contextvar and imports from wherever the wrapper lands, so
lifting afterwards would mean touching the patch too. The lift went first.

The product path is **synchronous**: `generator.py:83,99` and `main_dev.py:39`
call `.invoke()`, and `ComplianceAgent.ask()` is a sync method. So the wrapper
has two entry points, `llm_call()` and `llm_call_sync()`, sharing one recording
path — `recorder.record_call_sync` is the second one's half and exists already.
**`llm_call_sync()` itself is not built**, and its first call site is blocked on
a decision: `generator.py:99` makes a second billed model call per product
answer and discards the result, so wiring the wrapper there would log a call
that should not exist.

The socket patch needs no such split — it wraps both `httpx.AsyncClient.send`
and `httpx.Client.send`.

**Failure paths are logged too, and that is most of the point.** A call that
raised `JudgeResponseError` was still made, still billed, and still exists at the
provider under an id — and on the evidence of 2026-08-25 it is disproportionately
likely to be the interesting one. The exception already carries a `CallRecord`
for exactly this reason.

### The timed region excludes the write

The measurement the eval cares about is the model's latency, so the timer
brackets the bare invocation and stops before anything is written. A run's wall
clock does include the writes; the per-call latency column does not. This was
Bertan's correction on 2025-08-25 and it survives the redesign unchanged.

**Writes are awaited inline, on both paths** — Bertan, 2026-08-26. A remote
insert of tens of milliseconds against a call that takes seconds is noise, it is
outside the timer, and the alternative — a background queue — has a failure mode
of losing rows at exit, which is the one thing an audit log may not do.

For reference, **measured 2026-08-25**, 300 single-row commits against a *local*
SQLite file with a realistic 19-column row:

| mode | median | p95 | max |
|---|---|---|---|
| default journal, `synchronous=FULL` | 3.226 ms | 6.128 ms | 19.167 ms |
| WAL, `synchronous=NORMAL` | **0.012 ms** | 0.022 ms | 0.050 ms |

**That measurement does not describe the chosen storage.** It is kept as the
shape of the argument.

**The remote figure, measured 2026-08-26** once the engine existed, from this
machine against `aws-0-eu-central-2`. It is four orders of magnitude larger than
the SQLite row, and **how the time is spent turns out to matter more than the
network**:

| | | |
|---|---|---|
| one statement, connection already open | 47 ms | 1 round trip |
| checkout + statement, implicit `BEGIN`/`ROLLBACK` | 141 ms | 3 round trips |
| checkout + statement, `AUTOCOMMIT` | 48 ms | 1 round trip |
| checkout + statement, `AUTOCOMMIT` + pre-ping | 202 ms | ~4 round trips |

The conclusion for *this* section is unchanged — tens of milliseconds against a
call that takes seconds, outside the timer, awaited inline. The consequence for
the repositories is that **a single-row write wrapped in an implicit transaction
costs three round trips for one statement**, so a repository writing one row runs
in `AUTOCOMMIT`.

Those figures are `SELECT 1` and a two-column `UPDATE`. **Repeated once the
repositories existed**, against the real 23-column `llm_call` row with its JSONB
and its NUMERIC — 20 samples, median:

| | |
|---|---|
| connection already open, no checkout | 46.8 ms |
| checkout + insert, `pool_pre_ping=False` | 47.7 ms |
| checkout + insert, `pool_pre_ping=True` | 91.1 ms |

Two things follow, and the second corrects a number this document previously
carried. **The row shape costs nothing** — the real insert takes the same 47 ms
as `SELECT 1`, so this is round trips and not payload, and no amount of trimming
what is stored will make it faster. **The checkout costs nothing either;
`pool_pre_ping` is the whole of it**, at 43.4 ms per write, about 6.5 seconds
over a 150-call run. That is a quarter of the 23 seconds estimated from the
`SELECT 1` figure, and it is the number the open `pool_pre_ping` decision should
be taken on.

**The pool under eight concurrent panelists is still unmeasured.** Every figure
here is single-threaded.

### The socket patch, and what it costs

**Decision — Bertan, 2026-08-26: patch `httpx` in this repository.** Extending
`ai_common.get_llm` to accept a pre-built `http_client` with an event hook is the
cleaner integration and remains open for later; it is not a prerequisite.

The cost is stated rather than glossed. A process-wide patch of
`httpx.AsyncClient.send` / `httpx.Client.send` is a monkey-patch: it is
sensitive to httpx's internals, it affects every HTTP client in the process
rather than only the model ones, and a library upgrade can break it silently.
Three things contain that:

1. It is installed from **one** place, by an explicit call at an entry point,
   not on import.
2. It filters on the completions path and forwards everything else untouched.
3. `scripts/probe_wire_params.py` already establishes the same technique in this
   repository, for the same reason — *the socket is the last point the request is
   ours* — so this is an existing pattern rather than a new one.

---

## Storage

**Decision: a remote Supabase PostgreSQL instance, reached through SQLAlchemy in
the repository pattern, with Alembic migrations from the first commit.**

### Why not a local SQLite file

**Gitignored local file.** Every record lives on one disk with no backup.
Rejected on that alone.

**Committed to the repository.** The repository is public. The file would
publish every prompt, every gold answer and every cost we have ever logged, as a
binary that produces a new blob on every run. Rejected.

### The connection

Supabase's **session** pooler, port 5432 — confirmed by Bertan, 2026-08-26. The
distinction matters and is not cosmetic: the *transaction* pooler on 6543 breaks
asyncpg's prepared-statement cache, and the resulting failures are intermittent
and read as flakiness rather than as a misconfiguration. Session mode supports
prepared statements, so **no `statement_cache_size` workaround is needed** and
asyncpg runs with its defaults.

Consequences for the engine, all following from session mode plus a serverless
host:

- `create_async_engine` with **asyncpg**.
- A **small pool** — `pool_size=5`, `max_overflow=5` — not `NullPool`. In session
  mode a pooler connection is held for the session's duration, so opening and
  closing one per write is the expensive option, which is the opposite of the
  transaction-mode advice.
- `pool_pre_ping=True` and `pool_recycle=300`, because a serverless instance
  drops idle connections and a stale one surfaces as a failed write.
- **Connect timeout 10s, statement timeout 10s.** Ten and not five for connect:
  a scale-to-zero instance takes seconds to wake.
- **One connection is opened at run start**, so the cold start is paid before the
  first judged call rather than inside it.

**Correction, 2026-08-26 — the statement timeout cannot be sent as a startup
parameter, and the first implementation that did was not in force.** Both
drivers document the startup-parameter route — asyncpg's `server_settings`,
psycopg's `options` — and Supabase's pooler consumes the startup packet without
forwarding what it carries. Measured against the live instance: with the timeout
set that way, `current_setting('statement_timeout')` read back `2min`, the
project default; `application_name` read back `Supavisor` rather than ours; and
`SELECT pg_sleep(30)` ran to completion. Setting the GUCs after connect is also
not enough on its own — both drivers leave the `SET` in an implicit transaction
they never end, so it reads back correctly once and reverts after a single pool
round trip. What works, and what `engine.py` does, is a `connect` event listener
that issues the `SET`s **and commits them**.

Two things follow that are worth carrying into any later work here. The connect
timeout is unaffected, because it is client-side and never reaches the pooler.
And **no test could have caught this**: the failure was visible only by asking
the server what it thought the setting was. `test_db_engine.py` now asserts the
GUCs do *not* travel as startup parameters, which pins the finding rather than
being capable of discovering it.

### The optional URL

`DB_URL` in `src/config.py`, a `SecretStr` defaulting to empty — the name is
Bertan's, already declared. The wrapper checks it after the model call: if there
is one, it writes; if not, it does not.

**Absent must remain the default**, so a fresh clone runs the whole pipeline
with no infrastructure and no entry point has to opt out of logging.

**Correction, 2026-08-26 — the empty default does not make the suite hermetic,
and trap 5 needed a different mechanism.** The draft argued that it did:
`DB_URL` defaults to empty, so a test run finds no URL and writes nothing. That
is true of a fresh clone and false of the machine this is developed on.
`Settings` reads the repository's `.env`, and on a developer's machine that file
holds the real URL — so under the default alone, a test that touched the log
would write to the production record it exists to verify, and nothing would say
so until someone read the table and found fixture rows in it.

The gate in `engine.py:is_enabled` is therefore **structural**: a test run
cannot enable the log, whatever the environment says. It checks whether `pytest`
is in `sys.modules` and refuses. Putting test-awareness in non-test code is a
smell and it is taken deliberately, because the alternative is hermeticity that
depends on every future test remembering to unset something — which is exactly
the arrangement this section originally proposed. The cost is that integration
tests against a scratch database now need that one line changed, deliberately
and with its own review.

### Where the code lives — `src/db/`

`src/` has two peers, `clause_and_effect/` (product) and `eval/` (instrument),
plus a shared tier sitting directly in `src/`: `config.py`, `llm_config.py`,
`logging_setup.py`. The log spans both peers, so it cannot live inside either.

```
src/db/
  engine.py          # async engine, session factory, the DB_URL gate
  models/            # SQLAlchemy declarative models
  repos/             # the repository layer the rest of the code talks to
```

**The dependency runs one way only.** `config.py` declares `DB_URL` and knows
nothing about `src/db/`; `src/db/` reads config. That module's docstring carries
an explicit contract — no LLM dependency, 0.21s import, paid by all eight modules
that import it — and inverting the dependency would put SQLAlchemy on every one
of them.

### The repository layer — `src/db/repos/`

**Built 2026-08-26.** Three modules, and the split between the first two is what
makes the layer checkable: `statements.py` builds SQLAlchemy Core constructs and
never executes them, `call_log.py` executes them and carries the failure policy,
`ledger.py` counts what did not land. A repository that built and executed in one
method could only be checked against a database; this way the SQL the log is
about to write is compiled to a string and asserted against, with no connection
and no rows — which is the only way to see the two properties below at all.

`AsyncCallLog` serves the judge path and `SyncCallLog` the product path, written
out separately rather than sharing a base. The duplication is deliberate: the
bodies differ only by `await`, and both alternatives — a base class with a hook
per statement, or one class branching on a flag — hide which path a reader is
on, in the layer whose whole purpose is that a failure on one path must not
reach the other.

**Three rules live here rather than in the callers.** A rule a caller has to
remember is a rule that holds until the next call site is written, and all three
fail invisibly.

- **Core `update()`, never `text()`** — the `updated_at` rule of departure 4.
- **Every value bound for a `NUMERIC` column goes through `Decimal(str(value))`**,
  since a caller reading a price off a JSON body has a float in hand. Note that
  `Float` subclasses `Numeric` in SQLAlchemy, so the check has to exclude it or
  a latency measured with a stopwatch acquires arbitrary precision.
- **A primary key is never defaulted.** The columns carry `default=uuid.uuid4`,
  so an insert without an id succeeds and the caller never learns what it got —
  fatal here, because `call_id` travels in a contextvar to the socket, which
  writes attempt rows against it *before* the call row exists.

**The transaction shape is not uniform**, and the difference is the measured one
from §The timed region: a single-row write runs in `AUTOCOMMIT`, because
SQLAlchemy otherwise wraps one statement in an implicit transaction and spends
three round trips delivering it — 141 ms against 48 ms. The one place a
transaction earns its extra round trips is the enrichment sweep, which writes
many rows and wants all or none of them: a sweep that half-lands leaves rows
stamped `enriched_at` whose findings were rolled back, and trap 4 makes that
permanent, since a stamped row is never swept again.

**There is no method that writes a call together with its attempts**, though the
latency argument would favour one. It is not possible under this design and is
stated here so nobody adds it: the rows are never in hand at the same moment,
which is departure 3's reasoning exactly.

**Measured against the live instance, 2026-08-26**, writing the real rows and
deleting them afterwards: `AUTOCOMMIT` commits (rows read back from a second
connection), `updated_at` moves on a real UPDATE while `created_at` holds, a
cost round-trips as exactly `Decimal('0.00123')` while `call_seconds` stays a
float, and the sweep's query uses the partial index — `Index Scan using
ix_llm_attempt_pending_enrichment`, from `EXPLAIN`.

### Alembic from the first commit

**Decision — Bertan, 2026-08-26**, overriding the draft's proposal of
`CREATE TABLE IF NOT EXISTS` plus additive columns. The reasoning the draft
offered against Alembic was that one table does not justify it; the reasoning for
it is stronger and the draft had already half-conceded it — **a remote database
means a schema change is no longer "delete the file"**. Three tables, a live
instance and no undo is precisely the situation migrations exist for, and
retrofitting Alembic onto a table with rows in it is worse than starting with it.

**Built 2026-08-26**: `alembic.ini`, `migrations/env.py`, and one revision,
`f5c1763874f3`, applied to the live instance. Four properties of that setup are
load-bearing rather than incidental.

**The constraint naming convention had to exist before the first migration**, and
it does — on `Base.metadata` in `src/db/models/base.py`. Without it Postgres
invents the names, the invented names land in the first migration, and every
later `op.drop_constraint` quotes a string nobody chose. Adding the convention
afterwards means a migration that renames every constraint in the database to
fix a problem caused only by lateness.

**Alembic is a dependency group, not a runtime dependency.** Nothing under
`src/` imports it; `migrations/env.py` imports our models rather than the
reverse. So the product environment does not carry a schema tool, while both
supply-chain gate tiers still cover it — `uv export --all-groups` flattens every
group into the file GuardDog reads.

**`env.py` restricts autogenerate to tables this project declares**, via
`include_object`. The instance is a Supabase project rather than a private
database: things arrive in `public` that this repository did not create. Without
the filter the failure is not a broken migration but a migration that applies
cleanly and deletes somebody else's table. **Measured, not assumed** — with a
foreign table present, autogenerate produced an empty migration with the filter
and `op.drop_table('zz_include_object_probe')` without it.

**The migration runs on its own engine, not the call log's.** The product engine
carries a 10-second `statement_timeout` chosen so a stalled write cannot stall a
judged run; a migration waiting on a lock may legitimately take longer than a
model call may. Migrations run under the server's own two-minute default, which
is intended and stated in `env.py` rather than left to be rediscovered.

**Verification is `upgrade head` followed by an autogenerate that must come back
empty**, because a migration that runs is not the same as a migration that
reproduces the models. That is a live check needing a network, so it is a thing
someone can forget; `tests/test_migrations.py` covers the part that is visible
in the text — every table, column and index in `Base.metadata` appears in the
migration and the reverse — without Alembic and without a connection. What it
cannot see is types, server defaults, and whether any of it was ever applied.

---

## Failure policy

Two rules, in tension with each other on purpose.

**1. A logging failure must never fail a judged call.** The judgement is the
valuable output; the row is bookkeeping. An unreachable database must not turn a
completed panel run into a crashed one. So: catch, do not raise.

**2. A logging failure must never be silent.** An instrument that quietly drops
records is the same defect class as every other finding this project has made
this month. The run counts its misses and reports them — *"148 of 150 calls
logged; 2 writes failed"*.

The statement and connect timeouts above are what make the first rule
achievable: an unreachable database must cause skipped writes, not a stalled run.

**Built in `src/db/repos/ledger.py`**, as a process-wide `WriteLedger` counting
attempted, written and failed, plus a count per exception type. It is per
process rather than per run, because that is what a process can honestly claim:
`llm_run` is a database row, and a run whose writes all failed has no row to
attach a count to. `LEDGER.report()` is the one line an entry point logs at the
end, and a run that attempted nothing says so rather than reporting *0 of 0*,
which reads as success to someone skimming.

**Departure 5 — the first failure of each kind is logged, not every failure.**
The draft said each failure goes through `logging` at warning level, and that is
wrong at the scale this operates on: an unreachable database fails every write
in the run, and 150 identical warnings bury the output the run exists to
produce, including the findings themselves. So the first of each exception type
is a warning naming `safe_target()` and the redacted exception; the rest are
counted and appear in the report. The total is the number that matters, and it
is never suppressed. Bertan's call, 2026-08-26.

Two things about the boundary are worth stating, because both were wrong in the
first implementation and neither is visible from the outside. **The statement is
built inside the `try`** — the builders refuse a missing primary key by raising,
so with construction outside, a caller's bug was the one exception the policy let
through. And **the gate is checked before anything else**, so a process with no
`DB_URL` attempts nothing and reports nothing rather than counting misses it
never intended to make.

---

## Schema

Three tables. The draft proposed two; the retry finding added the third, and it
is the one that makes cost totals true.

**`llm_run`** — one row per **process**, not per script. `ComplianceAgent` inside
a long-lived server is not a script invocation.

| column | source |
|---|---|
| `run_id` | generated uuid; the join key |
| `entry_point` | caller, e.g. `probe_a2_stability.py` |
| `commit_sha` | `chunk_store.git_state` |
| `git_dirty_paths` | `chunk_store.git_state`; JSONB, **departure 1** — the paths, not a boolean |
| `started_at`, `finished_at` | caller |
| `hostname` | for when runs come from more than one machine |
| `created_at`, `updated_at` | **departure 4** — row lifecycle, on every table |

Created lazily by the first call that needs it (`ON CONFLICT DO NOTHING`), so no
entry point has to remember to open one.

**`llm_call`** — one row per logical call, written by the wrapper.

| column | source | notes |
|---|---|---|
| `call_id` | generated uuid | what the contextvar carries |
| `run_id` | the run | |
| `stage`, `case_id` | call site | **nullable** — they are eval concepts and the product path has neither |
| `model`, `channel` | the config entry | `channel` is the `structured_output` mode |
| `llm_server` | the config entry | `LlmServers.value` — who we bought the call from, **not** who ran it |
| `requested_provider` | the config entry | the routing constraint we sent, as JSON |
| `status` | wrapper | `OK` / `STRUCTURE_PROBLEM` / `TIMEOUT` / `TRANSPORT_PROBLEM` |
| `call_seconds` | wrapper | the bare invocation, timer stopped before the write |
| `started_at` | wrapper | **departure 2** — places the call against the clock, not merely inside its run |
| `generation_id`, `cost`, `finish_reason` | `response_metadata` | **what the caller believed** — the last attempt only |
| `prompt_tokens`, `completion_tokens`, `reasoning_tokens` | `usage_metadata` | |
| `prompt_sha256` | wrapper | see *what is not stored* |
| `raw_output` | wrapper | failures only, **in full** |
| `error_type`, `error_message` | wrapper | |
| `metadata` | call site | JSONB, for whatever a site knows that has no column |
| `created_at`, `updated_at` | the database | **departure 4** |

**`llm_attempt`** — one row per upstream HTTP request, written by the socket
patch. **This is the table that says what a call actually cost.**

| column | phase | source |
|---|---|---|
| `attempt_id` | 1 | generated |
| `call_id` | 1 | the contextvar; **nullable**, and **departure 3a** — no foreign key |
| `seq` | 1 | order within the call |
| `llm_server` | 1 | **departure 3b** — the request URL; what the sweep filters on |
| `started_at` | 1 | **departure 2** — `seq` orders attempts within a call, this places them against the clock |
| `generation_id` | 1 | `id` in the response body |
| `served_provider` | 1 | **`provider` in the response body — free and immediate**; who ran the machine |
| `model_alias` | 1 | `model` in the response body — the wire id, e.g. `minimax/minimax-m3` |
| `http_status` | 1 | the socket |
| `cost`, token counts, `finish_reason` | 1 | the response body |
| `request_seconds` | 1 | measured at the socket |
| `routing_chain` | 2 | generation endpoint, e.g. `Parasail:429 -> Venice:200` |
| `native_finish_reason`, `generation_time`, `latency` | 2 | generation endpoint |
| `enriched_at` | 2 | null until the sweep runs |
| `created_at`, `updated_at` | — | **departure 4** |

**The true cost of a call is `SUM(llm_attempt.cost)`, not `llm_call.cost`.** The
two are stored separately and deliberately: the gap between them is the
undercount this project has been publishing, and keeping both makes it a
measurable quantity per run rather than a suspicion. On the probe's first
scenario that gap was 67% of the call.

**Enrichment now attaches to the attempt, not the call**, since generation ids
are per attempt. That is a strict improvement: the routing chain of a *failed*
attempt becomes recoverable, and those are the interesting ones.

Nullability follows the existing `CallRecord` doctrine, which should be restated
in the tables' own comments: **every column is null for one reason only — the
provider did not report it — and null is never zero.** A call reporting
`reasoning: 0` did not reason; a call reporting nothing may have reasoned freely
and not said so, and the two must not average together.

### No enum types in the database

**Decision — Bertan, 2026-08-26.** `status`, `llm_server` and `channel` are
text columns. The enumerations are defined in Python and enforced by the
repository classes, which are the only code that writes to these tables.

The flexibility this buys is specific rather than general. A Postgres enum type
is the wrong shape for values that change with the roster: adding one means
`ALTER TYPE … ADD VALUE`, which historically could not run inside a transaction
and therefore does not sit comfortably in a migration, and **removing** one is
not supported at all. A panelist gains a channel, a provider is added, a new
status is distinguished — each of those becomes a migration against a live
instance, in exchange for a constraint the repository layer already applies at
the only point rows enter.

Two conditions make it safe, and both must hold. Every write goes through a
repository — no ad-hoc inserts from a script, no ORM session handed out. And the
Python enums are the single definition, so a value cannot be spelled two ways in
two places.

#### The enums are `ai_common`'s, and the column stores `.value`

**Decision — Bertan, 2026-08-26.** `llm_server` takes its values from
`ai_common.enums.LlmServers` and `model` from `ai_common.enums.ModelNames`.
Both columns are `String`, and **the repository writes `.value`** —
`'openrouter'`, `'deepseek-v4-flash-0731'` — reconstructing the member on read
with `LlmServers(value)` / `ModelNames(value)`, which raises `ValueError` on an
unknown string. That is the right failure: a row written by a newer roster and
read by older code should stop, not silently degrade.

**`.value` has to be spelled out because every convenient alternative is wrong,
and two of them are wrong quietly.** Measured 2026-08-26 — neither enum carries a
`str` mixin:

```
ModelNames | mro: ['ModelNames', 'Enum', 'object']
  .value = 'deepseek-v4-flash-0731'
  str()  = 'ModelNames.DEEPSEEK_V_4_FLASH_0731'
  == its own value -> False
```

So:

- **`str(member)` and f-strings yield `ModelNames.DEEPSEEK_V_4_FLASH_0731`**, not
  the model id. A column filled that way looks populated and joins to nothing.
- **`member == 'deepseek-v4-flash-0731'` is `False`.** Any query or test that
  compares a read-back column against a member rather than against `.value`
  fails without saying why.
- **`sqlalchemy.Enum(ModelNames)` stores the member's `.name`**, not its value —
  and its native form would create the database enum type the decision above
  forbids.
  It is the obvious-looking choice and it is doubly wrong here.

Passing a member straight into a `String` column is the one failure mode that is
loud: the driver cannot adapt it and raises. The three above are the ones to
guard with a test.

#### The LLM server is not the provider

**This is the distinction the whole log turns on, and it is easy to lose because
the same company appears on both sides of it.** Stated by Bertan, 2026-08-26.

- **The LLM server** is who we buy the call from — whose API key we hold, whose
  endpoint we hit. `LlmServers`: OpenAI, OpenRouter, Groq, Ollama, Anthropic,
  Google. It is a commercial and configuration fact, known before the call is
  made, and it is ours.
- **The provider** is who runs the machines the model executed on. Venice,
  Parasail, CoreWeave, Azure, Together. It is a runtime fact, decided by the
  server after we asked, and until 2026-08-25 nothing recorded it.

The same entity occupies both roles, which is exactly why one word cannot serve
for both. GPT-5.6 Luna Pro through our OpenRouter key today lists **OpenAI,
Azure and Azure (EU)** as its providers — so `llm_server = 'openrouter'` with
`served_provider = 'OpenAI'` is a normal row. The same model through our OpenAI
key is `llm_server = 'openai'`. Both rows say "OpenAI" somewhere and they are
not saying the same thing: one names our supplier, the other names the machine.

**The original column name here was `provider_api`, and it was wrong** — it used
*provider* for the server concept, which is the confusion it most needed to
avoid. Renamed to `llm_server` on 2026-08-26.

Three consequences follow:

**The two columns have different vocabularies, and only one is ours.**
`llm_server` is `LlmServers.value` — a closed set we control. `served_provider`
is whatever string OpenRouter puts in the response body, from a catalogue we
neither own nor can enumerate, and new providers appear in it without notice. So
`served_provider` is **not** enum-backed, and no validation should pretend
otherwise; an unrecognised provider name is a fact about the world, not a bad
row.

**`served_provider` is stored verbatim — free text, and never reconciled with
`LlmServers`.** Bertan, 2026-08-26, and it is a rule with no exceptions rather
than a default with sensible ones.

The temptation arrives precisely when the string looks familiar. OpenRouter
returns `OpenAI`; `LlmServers.OPENAI` exists; mapping one to the other looks like
tidying up. **It is not, and there is no special case for providers that happen
to appear in our enum.** The resemblance is a coincidence of company naming, not
a relationship between the two columns — one names a machine operator chosen at
runtime, the other names a supplier we hold a key with, and a string collision
does not make them the same fact.

So: no case-folding, no trimming, no whitespace normalisation, no alias table, no
`CHECK`, no foreign key. If OpenRouter sends `OpenAI` on one call, `Open AI` on
the next and `Open Ai` on a third, **all three are written as they arrived** and
none is corrected. That inconsistency is itself data about their catalogue, and
it is the kind of thing this log exists to be able to notice.

**The argument that settles it is directionality.** Normalising at write time is
lossy and irreversible — once `Open AI` has been rewritten to `OpenAI`, no query
can recover what the provider actually said, and the row stops being a record of
the call and becomes a record of our opinion about it. Normalising at read time
costs nothing and can be revised: a view, or a mapping applied in a report, with
the raw column still underneath it.

The visible consequence is that `GROUP BY served_provider` can return several
rows for what a person would call one company. **That is the correct behaviour**,
not a bug to be fixed at the write path.

**`served_provider` is null when the server does not report one**, which is
every server except OpenRouter. That is the null doctrine applied unchanged —
null means not reported — and it is not a gap to be filled. Writing `'openai'`
into `served_provider` for a direct OpenAI call would be inventing a
measurement: we would be asserting which machines ran it, which the response
never told us. `llm_server` already answers that question as far as it can
honestly be answered.

**A single-provider row and a routed row are distinguishable, and must stay so.**
`llm_server='openai'`+`served_provider=NULL` and
`llm_server='openrouter'`+`served_provider='OpenAI'` describe genuinely
different situations — the second went through a router that could have chosen
Azure instead, and on the next call might. Collapsing them would erase precisely
the variance this log was built to expose.

#### The reports and the log spell model names differently

**Noted, not resolved.** `probe_a2_panel.py:156` writes model names into every
committed report as `str(model).split(".", 1)[-1]` — the member **name**,
`DEEPSEEK_V_4_FLASH_0731`. The log stores the **value**,
`deepseek-v4-flash-0731`. The same panelist therefore appears under two spellings
across two artefacts that *reports keep carrying their own numbers* expects to be
cross-checked against each other.

The mapping is lossless in code — `ModelNames(value).name` recovers the report's
spelling — so this is not a schema problem and no column is being added for it.
It is recorded because the failure it causes is a human one: someone greps a
report's model name against the log, gets nothing, and concludes the run was
never logged.

### Cost is read, never computed

**Decision — Bertan, 2026-08-26.** Every `cost` in these tables comes from the
provider's own metadata. It is never derived from token counts and a price
table, even though `ai_common.calculate_token_cost` exists and the non-OpenRouter
providers all report input and output tokens.

**For OpenRouter that utility is structurally unable to be right.**
`price.py:47` reads `PRICE_USD_PER_MILLION_TOKENS[model_provider][model]` — one
price per model id, keyed on *our* provider, which is `openrouter`. But the price
of `minimax/minimax-m3` is whatever Venice, CoreWeave or Parasail charged for
that particular call, and which of them answered is the entire subject of this
document. A single static number cannot represent a quantity that varies per
call. Provider prices also change over time, so even a table that distinguished
upstream providers would be right only until it wasn't, and silently wrong
afterwards.

The consequence is stated rather than discovered later: **a provider that does
not report a cost yields a null cost, and that null stands.** It is the same
doctrine as everywhere else here — null means the provider did not say — and
back-filling it by multiplication would replace an honest gap with a number that
looks like a measurement and is not one. If a computed estimate is ever wanted,
it belongs in a separate column that says so in its name.

This does not touch `compliance_agent.py` or `gdpr_test_data_generation.py`,
which use `calculate_token_cost` today for their own reporting. Whether that
reporting is trustworthy is a different question and belongs in `todo.md`.

### Not every call is an OpenRouter call

The product path can run Groq, OpenAI or Ollama through `ai_common`, and those
return no `gen-…` id and, per the section above, often no cost either.
`llm_server` exists so the enrichment sweep can filter on it. Without that
filter the sweep would query `/api/v1/generation` forever for ids that were never
OpenRouter's, and trap 4 would then mark them swept-and-empty — true, and
useless.

### The enrichment sweep

A row is written immediately with everything the socket saw, and completed
later — at the end of the script, or the next day, or never — by a sweep that
fetches `/api/v1/generation` for attempts whose enrichment is still null.

```
UPDATE llm_attempt ... WHERE enriched_at IS NULL AND generation_id IS NOT NULL
                         AND llm_server = 'openrouter'
```

**Both**, per the decision: entry points call it at exit, and a standalone
re-runnable command mops up rows still inside the nine-second lag. The sweep is
idempotent and interruptible, and a row that is never enriched is still a true
record of what was known at call time — which, since 2026-08-26, includes the
served provider.

### What is deliberately not stored

**The prompt.** It is reproducible: a pure function of the case id, the stage and
the template at a given commit, and `commit_sha` is on the run. Storing it would
multiply the table's size and duplicate what is already in `data/tier-1/` and in
git.

This makes `commit_sha` load-bearing rather than decorative, and **that is why
`prompt_sha256` is stored** — decided 2026-08-26. If the templates change and the
recorded commit does not explain it, the hash makes the mismatch detectable
instead of leaving the reconstruction quietly wrong.

**The successful output.** It is in the eval report and in the parsed value.

**The failed output is stored in full** — Bertan, 2026-08-26.
`JudgeResponseError` truncates at 300 characters (`llm.py:_EXCERPT_CHARS`), and
on 2026-08-25 that was exactly the gap: MiniMax's failure read
`Invalid json output: ` with nothing before the newline, and whether the content
was genuinely empty or merely unparseable is *still* unknown, because the excerpt
did not reach far enough and the message was gone. Failures are rare; the storage
cost is small; the artefact is otherwise irrecoverable.

**Nothing is ever deleted** — decided 2026-08-26. At current volumes that is fine
for years. It is recorded as a decision rather than left as an oversight.

---

## What LangSmith does and does not cover

LangSmith is currently enabled in exactly one place — `src/main_dev.py:27-29`,
three environment variables set inside `main()`. **No probe and not `judge.py`
enables it**, so every panel run, both stability samples and the
reasoning-channel probe were untraced.

Enabling it everywhere was proposed on 2026-08-25 and **withdrawn**, on two
grounds:

1. Bertan's own experiment found its performance unsatisfactory. The cause is
   undiagnosed — it may be the OpenRouter client, it may be free-tier ingest
   limits.
2. More importantly, our workload is close to its worst case for structural
   reasons. Every run serialises inputs and outputs, and our payloads are large;
   one judge call is not one run, because
   `with_structured_output(include_raw=True).with_retry(stop_after_attempt=3)` is
   a nested tree, so a 150-call stability sample sends several hundred runs with
   payloads attached; and it is an in-process network round trip on every one.

**Demoting it costs less than it appears**, because our prompts are reproducible
and the one irrecoverable artefact — the raw text of a failed call — is now
stored directly. A further point arrived on 2026-08-26: LangSmith sits at the
callback layer, and the callback layer has been measured unable to see the
retried attempts. It could not have closed this gap even if it had been on.

**Division of labour.** The database is the system of record — what happened,
what it cost, who served it, how long it took, and what a failure said.
LangSmith becomes opt-in behind one entry-point setup function, turned on where a
trace earns its keep: `ComplianceAgent` is a genuine multi-step tree and is worth
looking at interactively. Eval probes run with it off.

A side effect worth stating: with tracing off by default, prompts and gold
answers stop leaving the machine on every eval run.

The separate `clause-and-effect-eval` project is kept, for the runs that do get
traced.

---

## Traps the implementation must actively avoid

Each of these would be silent.

**1. A synchronous insert inside an async stage serialises the panel.** The
stages are `async` and the probes run panelists concurrently. A blocking database
call inside the event loop makes eight concurrent panelists take turns on the
network, degrading concurrency with no error and no symptom beyond a run that
feels slow. This is the trap most likely to be discovered from a latency table
weeks later.

**2. ~~Retries produce generations that are never seen.~~ Measured, and now the
reason the `llm_attempt` table exists.** Kept in place rather than deleted
because the *residual* risk is real: the attempt rows are only as complete as the
socket patch's coverage, and any model client that does not go through `httpx`
bypasses it entirely.

**3. The generation endpoint's nine-second lag is not a constant.** It was
measured three times on one model at one time of day. A sweep that assumes ten
seconds is enough will silently leave rows unenriched under load. The sweep is
therefore re-runnable and records its failures rather than assuming success.

**4. `enriched_at` must be set even when enrichment finds nothing**, or every
sweep re-fetches the same permanently-missing generations forever. *Not yet
swept* and *swept, nothing there* must be distinguishable.

**5. Tests must never write to the real database.** ~~Covered by the
empty-`DB_URL` default~~ — it is not, on any machine whose `.env` holds a real
URL, which is every machine this is developed on. `engine.py:is_enabled` refuses
structurally when `pytest` is in `sys.modules`, and `test_db_engine.py` asserts
it. See [the correction](#the-optional-url). The failure is invisible until
someone inspects the table and finds fixture data in it, which is why the
argument that it was already covered was worth checking rather than accepting.

**6. `DB_URL` is a secret** and contains a password. It is a `SecretStr`, and it
must not reach a log line, an exception message or a committed report. Connection
errors love to quote the URL; log host and database name only.

**7. `llm_server`, `requested_provider` and `served_provider` are three columns
for a reason, and two of them can hold the same word.** Once providers are pinned
it will be tempting to treat the pin as the answer; the whole finding of
2026-08-25 is that what we asked for and what answered are not the same thing,
and a row recording only the request could not have shown it. The subtler trap is
the first column: `llm_server='openai'` and `served_provider='OpenAI'` are both
true of different calls and mean different things — our supplier versus the
machine. Any aggregation that groups on "OpenAI" without saying which column it
means is producing a number nobody can interpret.

**8. A bypassed wrapper now shows up instead of vanishing.** Five judge call
sites and the product path use it; a sixth stage written next month that calls
`ainvoke` directly still produces `llm_attempt` rows, with a null `call_id`.
Querying for those is how the bypass gets found.

**9. Nothing on the write path may tidy `served_provider`.** The trap is that
normalising it looks like quality work — a `.strip()`, a `.title()`, a lookup
against `LlmServers` for the names that match. Each is irreversible once the row
is written, and each destroys the evidence the column exists to hold. Guard it
with a test that writes an odd spelling and reads back exactly that spelling.

**10. The socket patch is process-wide.** It must be installed once, from an
entry point, never on import — and it must forward non-completions traffic
untouched. Two installations would double every attempt row.

**11. The 300-second inner retry budget has no deadline above it.** Until a
per-call timeout exists, a single stalled panelist can spend fifteen minutes and
an unbounded amount of money while the log faithfully records all of it. The log
makes this visible; it does not fix it, and the fix belongs in `todo.md`.

---

## Decisions, and who made them

| # | decision | decided |
|---|---|---|
| 1 | Remote Supabase Postgres, **session** pooler on 5432 | Bertan, 26th |
| 2 | SQLAlchemy + asyncpg, **repository pattern**, `models/` and `repos/` | Bertan, 26th |
| 3 | **Alembic from the first commit** | Bertan, 26th |
| 4 | Code lives in `src/db/`, config dependency one-way | assistant, 26th |
| 5 | Scope is **every LLM call**, product path included | Bertan, 26th |
| 6 | **Both capture levels**: call-site wrapper + socket patch | Bertan, 26th |
| 7 | Patch `httpx` **here**; extending `ai_common` stays open | Bertan, 26th |
| 8 | Callback handler **rejected**, on measurement | assistant, 26th |
| 9 | Writes **awaited inline** on both paths | Bertan, 26th |
| 10 | Failed raw output stored **in full** | Bertan, 26th |
| 11 | `prompt_sha256` stored; prompt itself not | assistant, 26th |
| 12 | **No enum types in the database**; enums live in code, repositories enforce | Bertan, 26th |
| 13 | **Cost is read from metadata, never computed** from tokens × a price table | Bertan, 26th |
| 14 | `llm_server` from `LlmServers`, `model` from `ModelNames`; **repo writes `.value`** | Bertan, 26th |
| 15 | **`llm_server` ≠ `served_provider`**; the column was renamed off `provider_api` | Bertan, 26th |
| 16 | **`served_provider` is verbatim free text**, never reconciled with `LlmServers` | Bertan, 26th |
| 17 | `llm_attempt.model_alias` records the wire id from the response body | assistant, 26th |
| 18 | Sweep runs **at exit and as a command** | assistant, 26th |
| 19 | Nothing is ever deleted | assistant, 26th |
| 20 | Connect 10s, statement 10s, pool 5+5, pre-ping | assistant, 26th |
| 21 | LangSmith opt-in; `clause-and-effect-eval` project kept | Bertan, 25th |
| 22 | The model call stays bare; the timer excludes the write | Bertan, 25th |
| 23 | Reports keep carrying their own numbers | Bertan, 25th |

---

## What the build changed

Collected here so that a reader who knows the original design can find every
difference in one place. The corrections are marked at the sections they
correct; the departures are marked at the columns they affect and argued in
`src/db/models/llm_log.py`, which is where someone reversing one would be.

**Two corrections. Both are cases where a decision was recorded and then
silently not in force**, which is this project's recurring defect class rather
than a coincidence.

| | what the design said | what is true |
|---|---|---|
| 1 | statement timeout 10s | sent as a startup parameter it never reached the server; the pooler ate it, and `pg_sleep(30)` ran to completion |
| 2 | the empty `DB_URL` default makes the suite hermetic | it does not on a machine whose `.env` has a real URL; the gate is structural instead |

**Five departures**, all deliberate, none of which changes what the log is for.
The fifth is in §Failure policy — the first failure of each kind is logged
rather than every failure — and is argued there.

1. **`llm_run.git_dirty_paths` rather than a `git_dirty` boolean.**
   `chunk_store.git_state` argues against the boolean in its own docstring: it
   is repo-wide, so an unrelated draft in `docs/` marks a run dirty even when
   everything that produced it is committed, and only the paths let a reader
   three months later tell those apart. The same docstring warns against keeping
   a flag beside the list, because the two drift. So the boolean is a query —
   `jsonb_array_length(git_dirty_paths) > 0`.

2. **`started_at` on both `llm_call` and `llm_attempt`.** Without it a call can
   be placed no more precisely than its run, two runs interleaved on one machine
   cannot be untangled, and no query can ask what the panel was doing at a given
   moment. Eight bytes, and not reconstructable later.

3. **`llm_attempt.call_id` carries no foreign key, and `llm_attempt` gains
   `llm_server`.** The missing key is forced by write ordering: the socket
   writes the attempt while the request is in flight, and the wrapper writes the
   call only after it returns, because the row needs the status and the
   duration. **An attempt therefore always exists before the call it belongs
   to**, and a foreign key would reject it — turning the log's failure policy
   into a constraint on when rows may be written. The reference is real and
   indexed, simply not enforced by the database, which is the same trade
   decision 12 already makes for the enumerations. `llm_server` is on the
   attempt because the sweep's own filter needs it (`WHERE enriched_at IS NULL
   AND generation_id IS NOT NULL AND llm_server = 'openrouter'`) and it cannot
   come from a join: the rows that most need filtering are exactly the ones with
   a null `call_id`.

4. **Every table carries `created_at` and `updated_at`** — Bertan, 2026-08-26.
   On the declarative base rather than in a mixin tables opt into, so a table
   added next year cannot be the one that forgot. They are **not** duplicates of
   the domain timestamps beside them: `llm_call.started_at` is when the call
   began, `created_at` is when the row reached the database, and the gap is the
   call's duration plus the write. When a record and its subject disagree about
   time, having only one of them makes the disagreement invisible.

   `updated_at` is maintained by SQLAlchemy's `onupdate`, which is a property of
   the *statement* rather than of the table — so a literal `text("UPDATE …")`
   does not get it and the column would keep the insert's value while the row
   changed underneath it. **The rule that closes this is that repositories write
   with Core `update()`, never with `text()`.** A `BEFORE UPDATE` trigger was
   proposed and rejected on measurement, 300 rows against the live instance:

   | | | |
   |---|---|---|
   | raw `text()` executemany | 59.9 ms | `updated_at` moved: 0/300 |
   | Core `update()` executemany | 67.5 ms | 300/300 |
   | ORM load + mutate + flush | 125.5 ms | 300/300 |

   7.6 ms per 300 rows against a 47 ms round trip, and the sweep runs once per
   run rather than once per call. The trigger would also be schema Alembic has
   to carry and invisible from the model file, and it would enforce in the
   database a guarantee that decision 12 declines to enforce there for `status`.

---

## Known gaps

- **Nothing captures anything yet.** The tables exist and are empty and the
  repositories can write to them, but the wrapper, the `contextvar`, the socket
  patch and the sweep are unbuilt, so nothing calls them outside a probe. Until
  they exist this document is still partly a specification.
- **The repository layer is unexercised under concurrency.** Every latency
  figure here is single-threaded, and eight panelists contending for a pool of
  five have not been measured. The `enrich_attempts` transaction in particular
  has only ever held three rows.
- **`pending_enrichment` is the only read the layer offers**, and the sweep that
  would consume it does not exist. The cost queries the log is *for* —
  `SUM(llm_attempt.cost)` per run, per case, per provider — are written nowhere
  and have never been run against real data.
- **Autogenerate does not compare server defaults.** `compare_server_default`
  is off — Alembic's default, and left there because turning it on produces
  spurious diffs from Postgres rewriting default expressions. A change to
  `created_at`/`updated_at`'s `server_default=func.now()` will pass the
  empty-diff check silently, and its migration has to be written by hand.
- **`native_finish_reason` may be in the response body already**, in which case
  it moves from phase 2 to phase 1. Not checked; check it at build time rather
  than assuming either way.
- **How often retries actually fire in a real run is unknown.** The probe forced
  them. Whether the published cost totals are 1% low or 60% low is exactly what
  the first logged panel run will answer.
- **Provider pinning is a separate, related decision** and is not part of this
  document. The log makes routing *visible*; it does not make it *stable*.
- **The confounded `structured_output` table in `llm_config.py` is not fixed by
  this document**, and one of its comments — that MiniMax's endpoint accepts no
  tools at all — is known to be false. Venice served it 6/6 on tool calls.

---

**Verified against:** `dev-04` at the commit that added `src/db/repos/` — the
storage half only, covered by 183 tests (`src/db/engine.py` 37, the models 104,
the migration environment 9, the repositories 33), each file mutation-swept with
no survivors. **The capture half is verified against nothing, because it does
not exist**: every statement about the wrapper, the `contextvar`, the socket
patch and the enrichment sweep is a specification.

What was checked against the live Supabase instance on 2026-08-26, rather than
reasoned about: the connection parameters as the server reports them, the DDL
via `create_all` into a throwaway schema and then via `upgrade head` for real,
the schema read back from `information_schema` and `pg_indexes`, the empty
autogenerate, the `include_object` filter against a real foreign table, the
repositories writing and reading back every real row shape, and every latency
figure quoted above. The rows those probes wrote were deleted afterwards; the
tables hold nothing.

The pre-build measurements were taken on 2026-08-25 and 2026-08-26 at commit
`4768ce9`, against `langchain_openrouter` and `langsmith 0.11.1` as pinned in
`uv.lock` on those dates; those figures come from
`scripts/probe_retry_visibility.py`.
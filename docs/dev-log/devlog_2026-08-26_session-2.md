# 2026-08-26 · session 2

**Repositories worked in:** `clause-and-effect` (`dev-04`) — four commits,
`7d19c1b → c16f780`, branch now **46 ahead of `main`**, no PR opened.
`ai-common` — untouched, not read.
**State at close:** suite **495 passed / 5 xfailed**, up from 354. Working tree
clean, all four commits pushed.
**Live spend:** **$0.00**. No model was called at any point. Every measurement
in this entry is a database round trip.

**Theme:** the session's task was to build the call log designed the session
before. Three of its five pieces exist — the dependencies, the engines, the
schema — and the two measurements taken along the way found that **a decision
recorded in the design was not actually in force**, and that **the cost of a
write is decided by how the statement is built rather than by the network.**

Nothing was written to the database. Every live check ran inside a transaction
that was rolled back, which Postgres permits for DDL as well as rows.

---

## A decision can be recorded, implemented, and still not be true

**This is the session's finding, and its shape is the one this project keeps
meeting.** Decision 20 says the statement timeout is ten seconds. The engine
passed it the way both drivers document — asyncpg's `server_settings`,
psycopg's `options="-c statement_timeout=10000"`. Reading the code, it was
done. Asking the server:

```
statement_timeout = 2min          ← the Supabase project default
application_name  = Supavisor     ← the pooler's, not ours
SELECT pg_sleep(30)               ← COMPLETED
```

**Supabase's pooler consumes the startup packet and does not forward what it
carries.** The timeout had never been in force, on either driver, and nothing
would have said so until the day a query hung — which is precisely the failure
the timeout exists to prevent, so the first symptom would have been the thing
it was meant to stop.

### The fix needed a second measurement to find

Setting the GUC after connect is the obvious repair, and on its own it does not
work either. It reads back correctly and then reverts:

| | first checkout | after one pool round trip |
|---|---|---|
| connect-event `SET` | `10s` | **`2min`** |
| connect-event `SET` + `commit()` | `10s` | **`10s`** |

Both drivers open an implicit transaction for the `SET` and neither ends it, so
the setting lives in a transaction that is never committed. `dbapi_connection.
commit()` is the whole fix and it is one line that looks like decoration.
`pool_reset_on_return` was the suspect and is not the cause — disabling it
changes nothing.

Verified after the change: `10s` across three checkouts on both drivers, and
`SELECT pg_sleep(30)` cancelled with `QueryCanceledError` **after 10.3 s**.

### The symptom looked exactly like a broken decision one level up

A GUC that reverts between checkouts is what transaction pooling looks like,
and decision 1 chose the **session** pooler on 5432 specifically because the
transaction pooler on 6543 breaks asyncpg's prepared-statement cache. If that
decision had silently not held, the workaround it was taken to avoid would have
been needed after all.

`pg_backend_pid()` settles it: **stable across checkouts**, four calls, one
backend. It is a genuine sticky session, the prepared-statement cache is safe,
and `statement_cache_size=0` stays out. A test pins its absence, because
re-adding it would look like a fix and would cost throughput for nothing.

---

## The network is 47 ms; the statement builder decides whether you pay it once or three times

**Measured against the live instance**, `aws-0-eu-central-2`, against the
design's local-SQLite reference of 0.012 ms:

| | | |
|---|---:|---|
| one statement, connection already open | **47 ms** | 1 round trip |
| checkout + statement, implicit `BEGIN`/`ROLLBACK` | **141 ms** | 3 round trips |
| checkout + statement, `AUTOCOMMIT` | **48 ms** | 1 round trip |
| checkout + statement, `AUTOCOMMIT` + pre-ping | **202 ms** | ~4 round trips |

The remote figure is four orders of magnitude above the local stand-in, which
was expected. What was not is that **the same one-row write costs 47 ms or
141 ms depending on nothing but whether SQLAlchemy wrapped it in a
transaction.** A single-row insert under an implicit `BEGIN`/`ROLLBACK` pays
three round trips to execute one statement.

Two numbers handed to the repository layer, which this session did not build:
a single-row write should say `AUTOCOMMIT` and a call-plus-attempts write
should batch, a difference of ~100 ms per call; and **`pool_pre_ping` costs
~155 ms per checkout**, about 23 seconds over a 150-call stability sample.
That trade was taken as decision 20 before any number existed. It is left as
decided, with the number now recorded beside it.

---

## `updated_at`, and a trigger that was measured out of existence

Bertan's instruction: every table carries `created_at` and `updated_at`,
timezone-aware, regardless of what it stores.

They went on `Base` rather than into a mixin the tables opt into, so a table
added next year cannot be the one that forgot; the tests are driven off
`Base.metadata.sorted_tables` for the same reason. Both are stamped by the
**database** via `server_default`, not by the client: runs come from more than
one machine, and rows stamped by each machine's clock cannot be ordered against
each other, which is the ordering the log exists to support.

The assistant then flagged a gap and **recommended the wrong fix.** `onupdate`
is applied when SQLAlchemy *builds* a statement, so a literal `text("UPDATE
…")` does not carry it; the design writes the enrichment sweep as raw SQL; the
assistant proposed a `BEFORE UPDATE` trigger in the first migration.

Bertan asked two questions instead of accepting it, and both had measurable
answers.

**Do we use or plan to use raw SQL?** No. The only `text()` in the repository
is `SELECT 1` in the warm-ups and a partial-index predicate. And decision 12
already commits to the opposite — *every write goes through a repository*.

**Does going through the ORM cost much?** The question exposed that the
assistant had framed a two-way choice where there are three, and the middle one
is the answer. A Core `update()` **already appends the stamp**:

```sql
UPDATE llm_attempt SET routing_chain=%(b_chain)s, updated_at=now() WHERE …
```

It is a statement builder against the model's columns, not the ORM's object
graph — nothing is loaded, no identity map is kept, and it compiles to the same
SQL as the handwritten version plus one `SET`. Measured, 300 rows, median of 5:

| | | `updated_at` moved |
|---|---:|---|
| raw `text()` executemany | **59.9 ms** | **0 / 300** |
| Core `update()` executemany | **67.5 ms** | 300 / 300 |
| ORM load + mutate + flush | **125.5 ms** | 300 / 300 |

7.6 ms for 300 rows against a 47 ms round trip, on a sweep that runs once per
run. **Decision: repositories write with Core `update()`, never `text()`; no
trigger.** The trigger would have been schema Alembic must carry, invisible
from the model file — so the model would stop describing the table — and
inconsistent with decision 12, which keeps the enum vocabularies out of the
database on the grounds that repositories are the only writers. Enforcing
`updated_at` in the database while declining a `CHECK` for `status` is the same
guarantee bought two different ways.

What replaces it is a test on the **compiled** UPDATE rather than on
`column.onupdate`. Those are different claims: `onupdate` being set says the
table was declared correctly; the compiled statement says what a repository
actually emits.

---

## The schema, and three places it departs from the design

Three tables — `llm_run` per process, `llm_call` per logical call,
`llm_attempt` per upstream HTTP request. Each departure is marked `DEPARTURE`
at the column so it can be reversed without archaeology.

**1. `llm_run` stores `git_dirty_paths`, not a `git_dirty` boolean.** The
design says `chunk_store.git_state` "reports both". It does not — it returns
`(sha, dirty_paths)` and argues against the boolean in its own docstring: it is
repo-wide, so an unrelated draft in `docs/` marks a run dirty even when
everything that produced it is committed. That docstring also warns against
keeping a flag beside the list, because the two fall out of sync. The boolean
is `jsonb_array_length(git_dirty_paths) > 0`, checked to parse.

**2. `llm_call` and `llm_attempt` each gain `started_at`.** The design's column
lists carry `call_seconds` and `request_seconds` but no wall clock, so a call
could be placed no more precisely than its run — and reading attempts against a
clock is exactly how the retry finding that created the third table was made.

**3. `llm_attempt.call_id` carries no foreign key, and `llm_attempt` gains
`llm_server`.** The missing key is a consequence of write ordering and is the
one worth carrying forward: **the socket writes the attempt while the request
is in flight, but the wrapper writes `llm_call` only after the call returns**,
because that row needs the status and the duration. An attempt therefore always
exists before its call, and a foreign key would reject it — forcing either a
placeholder call row or a buffer, both worse than an unenforced reference. It
is the same trade decision 12 already makes for the enumerations. `llm_server`
is not really new: the design's own sweep query filters on it, and it cannot
come from a join, because the rows that most need filtering are the ones with a
null `call_id`.

Two type choices the design left open. **Cost is `NUMERIC`, not float** —
`SUM(llm_attempt.cost)` is the headline query, and summing binary floats at the
fifth significant figure of a cent puts error into the one number the table
exists to make trustworthy. Unconstrained `NUMERIC` is arbitrary-precision, so
no scale has to be guessed, which puts one obligation on the repositories:
convert with `Decimal(str(value))`, never `Decimal(float)`. And `llm_call`'s
`metadata` column is mapped as **`call_metadata`**, because `Base.metadata` is
SQLAlchemy's own registry; two tests pin both halves, since a later edit
renaming it back would look like tidying.

---

## Trap 5 was not covered by the mechanism the design relied on

The design argues the suite is hermetic by construction because `DB_URL`
defaults to empty. **On a developer's machine it is not.** `Settings` reads the
repository's `.env`, that file has a real URL in it, and `is_enabled()` would
therefore have been `True` under pytest — so a test that touched the log would
have written to the production record it exists to verify, invisibly.

The guard is structural rather than a fixture: `is_enabled()` returns `False`
whenever `pytest` is in `sys.modules`. Test-awareness in non-test code is a
smell and it was taken deliberately, because the alternative is hermeticity
that depends on every future test remembering to unset something — the exact
arrangement the design rejected. It is one line, documented as the place to
revisit if integration tests are ever wanted.

---

## The dependencies, and one waiver

Four packages: `sqlalchemy`, `asyncpg` and `psycopg` as runtime dependencies,
`alembic` in a new `migrations` group — nothing under `src/` imports it, and
`uv export --all-groups` means both gate tiers still cover it. The lock diff is
additive; nothing else moved.

**Two drivers, and the reason is a constraint rather than symmetry.** An
asyncpg connection is bound to the event loop that opened it, so the
synchronous product path cannot borrow the async pool by wrapping each write in
`asyncio.run()` — the second call would find the pool holding connections
belonging to a closed loop. Only one engine is ever built in a given process:
a probe is async-only, `main_dev` is sync-only. The alternative considered was
one engine on a dedicated background loop with synchronous callers blocking on
`run_coroutine_threadsafe`; it saves a dependency and costs a thread whose
shutdown has to be right.

`make audit` clean at 190 packages. `make scan` blocked once, on **sqlalchemy
2.0.52 / `threat-filesystem-autostart`**, waived as a rule defect: the branch
that fired needs a startup-file string and a file write anywhere in the same
file, and `$py_profile` matched the literal `".profile"` at
`sqlalchemy/testing/profiling.py:303` — a cProfile stats-dump *extension*, not
the shell startup file — while the `open(` completing the condition is two
functions away reading the test suite's committed call-count baseline. The
condition is file-scoped, so the two halves need no relationship to each other.
Re-scan reports the finding and no longer blocks: **BLOCKED 0, INCOMPLETE 0**.

---

## The design gained its strongest argument, and it is not ours

Bertan checked OpenRouter's documentation. `/generation` and
`/generation/content` fetch a single generation **by its id**; no documented
endpoint enumerates ids over a date range; `/activity` returns aggregates per
day and endpoint with no individual ids; individual records appear only in the
dashboard's Logs page.

The design already claimed there was no list-generations endpoint, but that was
**our inference from having failed to find one**. As a documented fact it says
something stronger: **a generation whose id we did not capture at call time is
unreachable by API, permanently.** Not slow to find. The only lookup takes the
id as input, so no query starts from a time, a model, a case or a run and
arrives at a generation.

It compounds with the previous session's retry finding in the way that earns it
its place in the document. The attempts a retry swallowed produce real, billed
generations whose ids no layer above the socket ever sees. Under this API they
are not merely unaccounted — they are unreachable by any means except scrolling
a dashboard with nothing to match them against. That is money spent that no
query will ever be able to name, and it is what `llm_attempt` exists to
prevent.

---

## Verification

- **Every claim about the connection was measured against the live instance**,
  not read from driver documentation. The startup-parameter failure was found
  by asking the server what it thought the setting was, which is the only
  question that could have found it.
- **The schema was created against real Postgres and rolled back.** DDL is
  transactional there, so `create_all` ran, `information_schema` and
  `pg_indexes` were read back, a real row was inserted to exercise the
  `server_default`, and the transaction was rolled back — `ddl_check` schemas
  remaining: 0.
- **Zero enum types created**, checked against `pg_type` rather than inferred
  from the model definitions.
- **141 new tests, both files mutation-verified with no survivors** — 39
  mutations against `engine.py`, 47 against the models. Two rounds of the
  engine sweep found real gaps and one equivalent-mutant pair.
- **Not verified:** that the DDL survives Alembic autogenerate, which is the
  next session's first task. `create_all` running is not the same as a
  migration reproducing it.
- **Not verified:** any of the repository-layer advice above under real
  concurrency. The latency table is single-threaded; eight concurrent panelists
  contending for a pool of five were not measured.
- **Not measured:** the cost of an actual insert of the real row shape. The
  round-trip figures are `SELECT 1` and a two-column UPDATE.

---

## Mistakes made this session

All the assistant's unless stated.

- **A trigger was recommended for `updated_at` before the alternatives were
  measured.** The recommendation was not wrong about the gap; it was wrong
  about the fix, and it framed a two-way choice — raw SQL or the ORM — when the
  answer was the third thing neither name covers. Bertan's two questions were
  what produced the measurement, and the measurement reversed the
  recommendation. The pattern is the same one recorded on 2026-08-25 and
  2026-08-26 session 1: **reasoning from library structure instead of observing
  it.** Three sessions running.
- **The first version of the engine passed the statement timeout as a startup
  parameter and the session would have closed believing it worked.** It was
  only found because the live smoke test printed `current_setting(...)`
  alongside the connection — a check added out of habit rather than suspicion.
  There was no test that could have caught it, and there still is not: the
  suite asserts the GUCs do *not* travel as startup parameters, which pins
  today's knowledge and would not have discovered it.
- **Two mutation-check patterns went stale silently** when the code they
  targeted was edited, and the sweep reported `SKIP` rather than failing. A
  skipped mutation reads like a passed one in a summary line. Both were
  repaired, but the sweep should treat an unmatched pattern as an error.
- **A test asserted `col.default.arg is uuid.uuid4` and failed** for a reason
  that had nothing to do with the code: SQLAlchemy wraps a zero-argument
  callable default so it can be handed the execution context. Identity against
  a library's stored callable is the wrong assertion; generating a value and
  checking it is a v4 UUID is the right one.
- **The engine's first draft used double-checked locking.** Mutation showed the
  two checks were individually redundant and therefore individually untestable
  — removing either alone changed nothing observable. The fast path was
  removed; an uncontended lock in front of a transatlantic write is not an
  optimisation.

---

## State handed to the next session

| | |
|---|---|
| `clause-and-effect` | `dev-04` at `c16f780`, **46 ahead of `main`**, four commits this session, pushed |
| Working tree | clean |
| Suite | **495 passed / 5 xfailed** (354 at open; +37 engine, +104 models) |
| Database | reachable; **nothing written** — every live check rolled back |
| Built | dependencies, `src/db/engine.py`, `src/db/models/` |
| Not built | Alembic, repositories, the `llm_call()` wrapper, the `httpx` patch, the enrichment sweep |
| Panel | verdict derivation, aggregation and calibration **still not built** |

## Open items — start here next session

| # | open item | state |
|---|---:|---|
| 1 | **Alembic.** `alembic.ini`, `env.py` reading `DB_URL` through the engine module with `target_metadata = Base.metadata`, then the initial migration autogenerated. Autogenerate compares against a live database, so verify by `upgrade head` followed by an autogenerate that must come back **empty** | **the build**, next |
| 2 | **The repositories.** Core `update()` only; `AUTOCOMMIT` for single-row writes, one transaction for a call plus its attempts; `Decimal(str(value))` for cost; a test per method that the compiled UPDATE carries `updated_at` | the build |
| 3 | **The `llm_call()` wrapper**, both flavours, and the `contextvars` carrying the call id to the socket | the build |
| 4 | **The `httpx` patch** — installed once from an entry point, never on import, forwarding non-completions traffic untouched | the build |
| 5 | **The enrichment sweep**, at exit and as a re-runnable command | the build |
| 6 | **Measure a real insert**, and the pool under eight concurrent panelists. The latency table is `SELECT 1` and a two-column UPDATE, single-threaded | first measurement |
| 7 | **Revisit `pool_pre_ping` with the number in hand** — ~155 ms per checkout, ~23 s per 150-call sample. **Bertan's call** | new, decision |
| 8 | **Update `design/llm-call-log.md`** once the mechanism exists: the `Verified against` line still reads "nothing", and the three departures plus the two corrections above belong in it | carried |
| 9 | **Give the model call a timeout.** The 300-second inner retry budget has no deadline above it | carried |
| 10 | **`max_llm_retries` in `llm_config` is dead config** | carried, mechanical |
| 11 | **Pin the provider per panelist. Bertan's call** | carried, decision |
| 12 | **Correct `llm_config.py`** — the "MiniMax accepts no tools" comment is false; the `structured_output` table is confounded | carried |
| 13 | **Re-measure the channel table under pinned providers** | carried |
| 14 | **Demote LangSmith to opt-in** behind one entry-point setup function | carried, decided in principle |
| 15 | **`short_name` writes the enum's member name; the log writes its value. Bertan's call** | carried |
| 16 | **Report the dropped `provider` upstream** to `langchain_openrouter` | carried, optional |
| 17 | **The coverage metric calls a one-conjunction difference UNSTABLE. Bertan's call** | carried |
| 18 | **Nine call sites still index the roster with `[0]`**, `main_dev.py` with `[5]` | carried, mechanical |
| 19 | **Verdict derivation (§7), aggregation into `CaseJudgement`, calibration (§9)** | carried, **the main task** |
| 20 | **A second stability sample at N=25**; **repeats per panelist**; **the reasoning-channel repeat** — all three want the provider recorded | carried |
| 21 | **Re-derive design §8.2**; **`art15_case1` is the case the panel splits on** | carried |
| 22 | **`gdpr_test_data_generation.py:150` raises `KeyError`**; **`ai_common.get_llm` mutates its argument** | carried |
| 23 | **Reject degenerate claims in `stage_a2.py`**; **measure beyond the six**; **`art7_case4`'s third sentence** (Bertan's call) | carried |
| 24 | `judge.py` and thirteen `scripts/` files print rather than log | carried, flagged |
| 25 | Everything else on the 2026-08-23 list — the A1↔A2 consistency check, the atomicity rule, §4.6's metric, `art8_case5`, GLM parked on latency | carried |
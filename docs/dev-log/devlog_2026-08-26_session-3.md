# 2026-08-26 · session 3 — the call log becomes a mechanism

**Branch** `dev-04`, `28dd5a1 → d6479f4`, eight commits, **55 ahead of `main`**.
**Suite 495 → 571 passed / 5 xfailed.** **No model was called all session**;
every measurement below is a database round trip and the spend is **$0.00**.

The session opened with three of the call log's five pieces built and nothing
written to the database. It closes with the storage half finished and verified,
the judge's model calls wrapped, and the first rows this project has ever
written to Postgres — inserted by probes, read back, and deleted again.

---

## The storage half is finished

**Alembic, and the check the design asked for.** `alembic.ini`,
`migrations/env.py`, one revision `f5c1763874f3`, applied to the live instance.
The verification is `upgrade head` followed by an autogenerate that must come
back **empty**, because a migration that *runs* is not the same as a migration
that *reproduces the models*. It came back empty. The schema was then read back
from `information_schema` and `pg_indexes` rather than inferred: three tables,
every constraint carrying its convention name, the partial index with its
predicate intact, **zero enum types**, no rows.

**The repository layer**, split three ways so that it can be checked without a
database. `statements.py` builds SQLAlchemy Core constructs and never executes
them; `call_log.py` executes them and carries the failure policy; `ledger.py`
counts what did not land. The compiled SQL is the only place two properties are
visible at all — that every UPDATE carries `updated_at`, and that a cost is
bound as a `Decimal` while a duration is not.

**The wrapper, and the context the socket will read.** `src/db/capture/` holds
three scopes with three lifetimes. The run is the process, built lazily so a
script that never calls a model never shells out to git. The case is set by
whoever iterates cases — the five stage functions take a question and an answer,
and threading a case id through them would put the log into the judge's API. The
call is published for the duration of the invocation and read by the `httpx`
patch that does not exist yet, which is the whole reason a `contextvar` is here
rather than an argument.

`llm_call()` replaces the two lines all five judge stages repeated. **The 100
existing stage tests pass untouched**, which is the evidence that it is
behaviour-identical when there is no `DB_URL`.

---

## `pool_pre_ping` costs a quarter of what the previous session recorded

Session 2 measured it with `SELECT 1` and recorded ~155 ms per checkout, ~23 s
over a 150-call sample, and left the trade as decided with the number attached.
Repeating it on the real 23-column `llm_call` insert — 20 samples, median:

| | |
|---|---:|
| connection already open, no checkout | 46.8 ms |
| checkout + insert, `pool_pre_ping=False` | 47.7 ms |
| checkout + insert, `pool_pre_ping=True` | 91.1 ms |

**43.4 ms per write, about 6.5 s over a 150-call run.** The old figure is left
where it was written in `todo.md` with a superseded marker beside it, because a
stale number sitting unmarked in the same file as the right one is a trap for
whoever greps first.

The other half of the table is the more useful half. **The row shape costs
nothing**: a 23-column insert carrying JSONB and NUMERIC takes the same 47 ms as
`SELECT 1`. This is round trips, not payload, and storing less would not make the
log faster. That closes the "measure a real insert" item from session 2 with an
answer nobody needs to act on.

---

## `include_object` was measured rather than trusted

`migrations/env.py` restricts autogenerate to tables this project declares. The
obvious way to treat that is as a tidiness setting. It is not: the instance is a
Supabase project rather than a private database, and things arrive in `public`
that this repository did not create.

Measured both ways with a real foreign table present. With the filter,
autogenerate produced an empty migration. Without it,
`op.drop_table('zz_include_object_probe')`. **The failure guarded against is not
a broken migration but one that applies cleanly and deletes somebody else's
table.** The probe table was dropped afterwards; `information_schema` confirms
it is gone.

The same reasoning is why the migration runs on its own `NullPool` engine rather
than the call log's. The product engine's 10-second `statement_timeout` exists so
that a stalled write cannot stall a judged run, which is the wrong budget for DDL
waiting on a lock. Migrations run under the server's own two-minute default,
stated in `env.py` rather than left to be rediscovered.

---

## Bertan: the wrapper is in the wrong package

Raised on reading `src/eval/sufficiency/llm.py` after the wrapper landed, and it
is the most consequential thing decided this session.

**The observation.** A great deal of that module is not specific to the
sufficiency judge — and `llm_call()` in particular **will be used wherever a
model call is made, including every module under `src/clause_and_effect/`**. A
wrapper that both packages must reach cannot live inside one of them.

The assistant had put it there for a bad reason: the design says the wrapper
returns a `StageResponse`, which is an argument about what the judge's call site
wants, not about where the wrapper belongs. The placement was already wrong in a
visible way — the product path would have to import from `src/eval/sufficiency/`
to build a structured-output model, and the sync flavour had nowhere sensible to
sit while its async twin was inside the judge.

**The plan.** A shared `src/llm/` tier beside `config.py` and `llm_config.py`,
holding `llm_call()`/`llm_call_sync()`, `StructuredPayload`,
`payload_from_tool_call`, `build_judge_llm` (renamed — nothing about it judges),
`sum_costs` and the channel constants, and eventually absorbing `llm_config.py`
as `src/llm/config.py`. What stays behind is genuinely judge-shaped:
`JudgeResponseError`, `StageResponse`, `require_response`'s `stage=` vocabulary,
and an ~8-line adapter that unwraps into a `StageResponse` so the five stage call
sites stay one line each.

**Bertan's second observation corrected the assistant's design and made it
simpler.** The assistant had argued that `STRUCTURE` classification must stay in
the judge, because deciding it requires reading `{raw, parsed, parsing_error}`
and a shared module must not duck-type a shape defined in `src/eval/`. Bertan's
point — that none of the four statuses is judge-specific, since a product-path
structured-output call fails to coerce exactly as a stage's does — exposed the
error in that: **the shape is LangChain's `include_raw` contract, which `llm.py`
merely declares.** Once `StructuredPayload` moves, the shared wrapper classifies
all four statuses itself and needs no injected callbacks. A hook the assistant
was about to design turned out to be unnecessary.

**Sequencing: before the `httpx` patch, not after.** The assistant's first
recommendation was the opposite, on the general principle that promoting code
after it works is cheaper than promoting it during. That is right in general and
wrong here: the patch reads the contextvar and will import from wherever the
wrapper lands, so moving it afterwards means touching the patch too.
`src/db/capture/context.py` stays where it is — it is about the log's rows, and
both the wrapper and the patch read it from there.

### `ai-common`: deliberately not now

Bertan also raised whether much of this, taken together with `llm_config.py`,
belongs in `ai-common`. Agreed in principle, deferred in practice, and recorded
in `todo.md` so it is not reopened from scratch.

What would eventually qualify is narrow — `capture/response.py`, the `include_raw`
payload shape, the channel constants: facts about LangChain and OpenRouter rather
than about this project. **The `structured_output` table specifically should not
go**, though it looks like the most reusable thing in `llm_config.py`. Those
assignments were measured on stage A2 prompts over six cases; in a library they
become "how to call MiniMax", which is a stronger claim than the evidence
supports, and the counts are single-sample — Grok read 4/6 then 6/6 on identical
runs. Measurements should live where their evidence lives.

Two constraints on any future move, both already visible in the code. This module
is architected around `ai_common` being expensive to import (6.58s for
`ai_common.llm`), so moving code there makes the cheap tier harder to keep cheap
unless `ai-common` gets its own layering first. And `ai_common.get_llm` still
mutates the dict it is handed, which `build_judge_llm` works around with a
defensive copy — a foundation worth fixing before building on.

---

## `STRUCTURE` → `STRUCTURE_PROBLEM`, `TRANSPORT` → `TRANSPORT_PROBLEM`

Bertan's call. The old names name *parts of the system*; a status column holds
*what went wrong in them*. `TIMEOUT` keeps its name, being already an event
rather than a layer.

Member and value both changed, so the string in the column matches the string in
the code. **No migration was needed** — decision 12 keeps `status` as plain text
with no Postgres enum type behind it, so the rename is invisible to the schema,
and the tables were empty in any case.

Two things were deliberately left alone, both now in `todo.md`. The probe scripts
carry their own `"STRUCTURE"`/`"TRANSPORT"` string literals and never touch
`CallStatus`; renaming them changes the vocabulary of committed eval reports,
which are history, so it is a decision rather than a side effect. And a payload
of `None` — the chain yielded nothing at all — still records
`STRUCTURE_PROBLEM`, which the new name fits even less well than the old one
did.

---

## Four departures and two corrections were folded into the design document

`design/llm-call-log.md` said "decided, not built" and carried a `Verified
against` line reading "nothing". Design documents in this repository are current
state rather than a record, so it was rewritten: a status table of what exists,
what is applied, and what does not exist; sections describing code now name the
file; and the two claims the build contradicted are corrected **in place** with
the correction marked and dated.

Both corrections are the same shape — **a decision that was recorded and then
silently not in force**, which is this project's recurring defect class rather
than a coincidence. The statement timeout could not travel as a startup
parameter. The empty `DB_URL` default does not make the suite hermetic on a
machine whose `.env` has a real URL.

---

## A second billed model call per product answer, discarded

Found while looking for the product path's call sites, and it is why the sync
flavour of the wrapper was not built.

`generator.py:99` reads `structured_response = self.structured_llm.invoke(...)`.
The result is assigned and never used. That is **a second full model call on
every product answer, billed, and thrown away**.

Wrapping it would mean logging a call that should not exist, so the sync flavour
is blocked on a decision rather than on work: delete it, use it, or decide it
stays. That a search for call sites — undertaken only because of the log —
surfaced it is itself an argument for the log.

---

## Mistakes made this session

All the assistant's unless stated.

- **The wrapper was put in the judge package**, for a reason that was about the
  call site rather than about layering. Bertan corrected it. The failure mode is
  worth naming: the design document says the wrapper returns a `StageResponse`,
  and the assistant read a statement about a *return type* as a statement about
  *placement*.
- **The assistant then argued the classification could not be lifted**, on the
  grounds that `{raw, parsed, parsing_error}` is the judge's shape. It is
  LangChain's. The wrong belief would have produced a callback hook that exists
  only to work around a layering error — more code, permanently, in the path
  every model call goes through.
- **A test asserted a constraint name was "in the source text"** and passed
  against a migration whose foreign key had been renamed, because the name also
  appears in the migration's own docstring. **An assertion a comment can satisfy
  is not an assertion about the code.** Found by mutation; the names now come out
  of the syntax tree.
- **Every repository test exercised `SyncCallLog` only.** A mutant that made the
  *async* `_write` re-raise instead of counting survived the whole suite — and
  the async path is the judge's. Found by mutation, not by review. The
  failure-policy tests run against both flavours now.
- **The executor built its statements outside the `try`.** The statement builders
  refuse a missing primary key by raising, so a caller's bug was the one
  exception the failure policy let through — in the layer whose entire purpose is
  absorbing exceptions. Found by the test that asserts a bug is a counted miss.
- **Three defects in one seam of the repository layer**, all found before the
  code ran for real. `insert(LlmCall)` routes through the ORM's bulk-persistence
  path, which resolved the dict key by class attribute and read
  `LlmCall.metadata` as SQLAlchemy's `MetaData`. `Column.key` for that column
  *is* `metadata` — only the mapper knows about `call_metadata` — so iterating
  the table's columns bound `MetaData` as a value. And **`Float` subclasses
  `Numeric`**, so the `Decimal(str(value))` rule would have converted
  `call_seconds` and handed psycopg a Decimal for a double precision column.
- **A mutation was written that mutated nothing.** `_t(...) if False else (...)`
  is equivalent to the original, and it was reported as a survivor for a while
  before the assistant read it properly. A sweep is only evidence if its mutants
  are real.

---

## Verification

- **Every claim about the database was checked against the live instance**, and
  every probe deleted its own rows. The tables ended the session empty, confirmed
  by `count(*)` on all three.
- **The empty-autogenerate check ran** after `upgrade head`, which is the only
  check that says a migration reproduces the models.
- **`include_object` was measured in both directions** against a real foreign
  table, not reasoned about.
- **`AUTOCOMMIT` was verified by reading rows back from a second connection**
  with no commit call — no compiled statement can show it.
- **The partial index was verified by `EXPLAIN`**: `Index Scan using
  ix_llm_attempt_pending_enrichment`.
- **The wrapper was exercised end to end with a fake runnable**, so all four
  statuses were written by the real path at a spend of $0.00.
- **Mutation-swept, no survivors:** 17 against the migration tests, 25 against
  the repositories, 31 against the capture layer. Three sweeps found real gaps
  before they were clean.
- **Not verified: anything under concurrency.** Every latency figure is
  single-threaded, and eight panelists contending for a pool of five have not
  been measured. `enrich_attempts` has only ever held three rows.
- **Not verified: the cost queries the log exists for.**
  `SUM(llm_attempt.cost)` per run, per case, per provider is written nowhere and
  has never run against real data.

---

## State handed to the next session

| | |
|---|---|
| `clause-and-effect` | `dev-04` at `d6479f4`, **55 ahead of `main`**, eight commits this session, pushed |
| Working tree | clean |
| Suite | **571 passed / 5 xfailed** (495 at open; +9 migrations, +33 repositories, +34 capture) |
| Database | schema applied and live; **no rows** — every probe deleted its own |
| Built | `src/db/engine.py`, `src/db/models/`, `alembic.ini` + `migrations/`, `src/db/repos/`, `src/db/capture/`, `llm_call()` wired at all five judge stages |
| Not built | the sync flavour, the `httpx` patch, the enrichment sweep |
| Panel | verdict derivation, aggregation and calibration **still not built** |

## Open items — start here next session

Items 1–3 and 6–8 from session 2 are closed or partly closed and are marked so;
everything else is carried forward unchanged. New items from this session are
marked **new**.

| # | open item | state |
|---|---:|---|
| 1 | ~~**Alembic.**~~ Built, applied, empty autogenerate verified | **done** |
| 2 | ~~**The repositories.**~~ Built, mutation-swept, verified live | **done** |
| 3 | **The `llm_call()` wrapper.** Async flavour built and wired at all five judge stages; the `contextvar` is in place. **The sync flavour is outstanding** and blocked on item 11 | **half done** |
| 4 | **Lift the generic machinery into a shared `src/llm/` tier.** Bertan, 2026-08-26. Do this **before** item 5 — the patch imports from wherever the wrapper lands | **new, next** |
| 5 | **The `httpx` patch** — installed once from an entry point, never on import, forwarding non-completions traffic untouched. The half that makes `SUM(llm_attempt.cost)` true | the build |
| 6 | **The enrichment sweep**, at exit and as a re-runnable command | the build |
| 7 | ~~**Measure a real insert.**~~ 47 ms, the same as `SELECT 1` — the row shape costs nothing. **The pool under eight concurrent panelists is still unmeasured** | **partly done** |
| 8 | **Revisit `pool_pre_ping`** with the corrected number: **43.4 ms per write, ~6.5 s per 150 calls**, not the 155 ms / 23 s recorded in session 2. **Bertan's call** | carried, decision |
| 9 | ~~**Update `design/llm-call-log.md`.**~~ Rewritten to describe what exists. **Needs one more pass** for the capture half, which landed after it | **partly done** |
| 10 | **Carrying functionality to `ai-common`** — agreed in principle, deliberately deferred. The `structured_output` table specifically should not go | **new**, deferred |
| 11 | **`generator.py:99` makes a second model call per product answer and discards the result.** Delete it, use it, or decide it stays. Blocks item 3's sync flavour | **new**, Bertan's call |
| 12 | **The probe scripts carry their own `"STRUCTURE"`/`"TRANSPORT"` literals** and now disagree with the log. Fixing it changes the vocabulary of committed eval reports. **Bertan's call** | **new**, decision |
| 13 | **A payload of `None` records `STRUCTURE_PROBLEM`** though nothing was generated. One line and one assertion to fold into `TRANSPORT_PROBLEM` | **new** |
| 14 | **Give the model call a timeout.** The 300-second inner retry budget has no deadline above it | carried |
| 15 | **`max_llm_retries` in `llm_config` is dead config** | carried, mechanical |
| 16 | **Pin the provider per panelist. Bertan's call** | carried, decision |
| 17 | **Correct `llm_config.py`** — the "MiniMax accepts no tools" comment is false; the `structured_output` table is confounded | carried |
| 18 | **Re-measure the channel table under pinned providers** | carried |
| 19 | **Demote LangSmith to opt-in** behind one entry-point setup function | carried, decided in principle |
| 20 | **`short_name` writes the enum's member name; the log writes its value. Bertan's call** | carried |
| 21 | **Report the dropped `provider` upstream** to `langchain_openrouter` | carried, optional |
| 22 | **The coverage metric calls a one-conjunction difference UNSTABLE. Bertan's call** | carried |
| 23 | **Nine call sites still index the roster with `[0]`**, `main_dev.py` with `[5]` | carried, mechanical |
| 24 | **Verdict derivation (§7), aggregation into `CaseJudgement`, calibration (§9)** | carried, **the main task** |
| 25 | **A second stability sample at N=25**; **repeats per panelist**; **the reasoning-channel repeat** — all three want the provider recorded | carried |
| 26 | **Re-derive design §8.2**; **`art15_case1` is the case the panel splits on** | carried |
| 27 | **`gdpr_test_data_generation.py:150` raises `KeyError`**; **`ai_common.get_llm` mutates its argument** — the second blocks item 10 | carried |
| 28 | **Reject degenerate claims in `stage_a2.py`**; **measure beyond the six**; **`art7_case4`'s third sentence** (Bertan's call) | carried |
| 29 | `judge.py` and thirteen `scripts/` files print rather than log | carried, flagged |
| 30 | Everything else on the 2026-08-23 list — the A1↔A2 consistency check, the atomicity rule, §4.6's metric, `art8_case5`, GLM parked on latency | carried |
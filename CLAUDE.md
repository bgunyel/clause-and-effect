# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A question-answering system over regulatory text (GDPR first), built
**evaluation-first**: every architecture decision gets measured before it is
kept. Two halves live side by side and are held to different standards —

> **The algorithm does not need to be perfect. The evaluation pipeline does.**
> (`docs/evaluation-plan.md` §1, "the asymmetry of standards")

The eval is the durable asset; the RAG pipeline is replaceable. A defect in
`src/eval/` corrupts every decision taken on its output, so eval components
require tests and measured evidence. The generator and agent staying untested is
an accepted state.

## Commands

```bash
make test                                  # uv run --group test pytest tests/
uv run --group test pytest tests/test_chunker.py::test_name   # single test
uv run --group test pytest tests/ -k pattern

make audit          # tier 1: osv-scanner over the committed uv.lock
make scan           # tier 2: GuardDog static analysis on every locked dep (slow, cached)
make verify         # audit + scan
make upgrade-safe   # resolve an upgrade, run BOTH tiers, revert unless clean
```

`make upgrade-safe` must pass before a PR closes. `make scan`/`upgrade-safe`
accept `GUARDDOG_BUDGET=<seconds>`; **exit 75 means unfinished, not pass** —
`make` collapses it to 2, so a caller that must tell the two apart runs
`uv run guarddog-cached --time-budget N <file>` directly. Findings are
adjudicated with the `waiver-review` skill.

### Corpus pipeline

```
gdpr.pdf → gdpr.docling.json → gdpr_articles.json → data/chunks/<snapshot> → Qdrant
```

```bash
python -m src.scripts.export_docling_json [--force]        # ~6 min CPU OCR; output committed
python -m src.scripts.generate_gdpr_articles [--source tree|markdown|pdf]
python -m src.scripts.generate_chunks [--dry-run] [--force]
python -m src.scripts.index_documents [--check] [--snapshot NAME]
```

### Eval and judge

```bash
python -m src.eval.golden_qa                 # deterministic golden-set gates, summary
python -m src.eval.sufficiency.judge         # A→B→C probe harness over 8 chosen cases
uv run python -m scripts.probe_a2_panel      # scripts/probe_*.py — one measurement each
```

### Migrations

```bash
uv run --group migrations alembic upgrade head
uv run --group migrations alembic upgrade head --sql    # print, apply nothing
uv run --group migrations alembic revision --autogenerate -m "..."
```

Alembic is a `migrations` dependency group, not a runtime dependency; the DB URL
comes from `DB_URL` in `.env` via `src.db.engine`, never from `alembic.ini`.
`include_object` in `migrations/env.py` is load-bearing — the Supabase project is
shared, and autogenerate without it writes a migration that drops someone else's
table.

## Architecture

**`src/clause_and_effect/`** — the product path. `parsers/` (docling → articles),
`chunking/` (`Chunker`, `Regulation`, `chunk_store` snapshots), `retrieval/`
(Qdrant + OpenAI embeddings), `generators/`, `agents/ComplianceAgent` (retrieve →
generate). Synchronous throughout.

**`src/eval/`** — `dataset.py` (typed loaders), `golden_qa.py` (deterministic
gates on the golden set), `sufficiency/` (the LLM judge). Async throughout.

**`src/llm/`** — the shared model-call tier, beside `config.py` because both the
product path and the judge reach it: `channels.py` (how a model is asked for a
schema), `structured.py` (`build_structured_llm` — the repository's only
`ai_common` touchpoint), `call.py` (`llm_call` — invoke, time, log, unwrap;
`CallRecord`, `LlmResponse`, `sum_costs`). Everything here encodes a fact about
LangChain or OpenRouter. `src/eval/sufficiency/llm.py` is the judge's adapter
over it and holds only the judge's vocabulary — `JudgeResponseError`,
`StageResponse`, the `stage=` labels.

**`src/db/`** — the LLM call log: `llm_run` (per process) / `llm_call` (per
logical call) / `llm_attempt` (per upstream HTTP request). It sits directly under
`src/` because both the product and judge paths make model calls. `capture/` is
the write-side (context vars, response readers, recorder); `repos/`, `models/`,
`engine.py` are storage. See `docs/design/llm-call-log.md` for what is built and
what is still specification — `llm_call_sync()`, the socket patch and the
enrichment sweep do not exist yet, so `llm_attempt` is never written.

**Two DB drivers on purpose.** asyncpg serves the async judge path, psycopg the
sync product path; an asyncpg connection is bound to the loop that opened it, so
a sync caller cannot borrow the async pool. Only one is ever built per process.

**The sufficiency judge** is a three-stage protocol, each stage structurally
blinded to what would let it rationalize: A sees question + gold answer (never
the quote), B answers from the quote alone (never the gold answer), C adjudicates
claims against B's blind answer (never the quote). Blinding is enforced by which
fields a prompt builder interpolates — a prompt cannot leak what it was never
given, and the tests assert this as an invariance property. Panelists vote;
disagreement is signal, not noise. **The judge is a defect finder for the golden
set, not a classifier** — there is no held-out set, because the 433 Tier-1 cases
are the population.

## Rules that are not style preferences

**Import cost is a design constraint.** `ai_common` pulls langchain →
transformers → torch (8.34s measured). Hence: `src/config.py` (paths/keys, 0.21s)
is split from `src/llm_config.py` (models); `src/eval/sufficiency/__init__.py`,
`src/db/capture/__init__.py` and `src/llm/__init__.py` deliberately export
nothing, so importing a submodule does not run a heavy `__init__`;
`src/llm/structured.py` defers `get_llm` into the function body and hides
`langchain_core` behind `TYPE_CHECKING`; `llm_call()` imports the storage layer
lazily. Guarded by
`test_importing_a_judge_stage_does_not_load_torch`. Re-measure before assuming
either way — several of these claims have been checked and found stale.

**Never change identity derivations.** `Chunker._create_chunk_id` and
`VectorDatabase.POINT_ID_NAMESPACE` derive every stored vector's identity; a
change re-keys the corpus and a re-index writes a parallel set of points instead
of updating in place.

**One producer, one consumer.** `generate_chunks.py` is the only thing that makes
chunks; `index_documents.py` is the only thing that indexes them, and it indexes
a written snapshot, never a fresh chunking. Pruning orphaned points is not
optional. Metadata is written last, so a collection never advertises a snapshot
it only partly holds.

**The docling *tree* is the corpus source, not the markdown.** The markdown
serializer flattens nested lists, so a sub-item is severed from the stem that
governs it — invisible in the text, and it corrupted 43 of 99 articles for weeks.
`--source markdown` is kept only as a cross-check.

**Logging, never `print`.** Libraries call `logging.getLogger(__name__)` and
configure nothing; only entry-point scripts call `setup_logging()`. Not
`RichHandler` — it word-wraps and breaks a sha256 across two lines.

**Nothing in the call log raises.** A logging failure must never fail a judged
call and must never be silent: repositories catch, return a bool, and count
themselves in `LEDGER`.

**Null means the provider did not report it, and null is never zero.** Cost is
`Numeric` and is bound as `Decimal(str(value))`, never `Decimal(float)`.

**Tests must not call the function under test.** Expected keys, formats,
constants and compiled SQL are written as literals. Tests use fakes and touch no
live Qdrant, database or model API. Mutation-check rewrites — several suites have
been green for the wrong reasons.

## Documentation

Four directories with different jobs; the distinction erodes easily
(`docs/design/README.md` states it in full):

| directory | answers | dated? |
|---|---|---|
| `docs/dev-log/` | what happened in a session, and why | yes, **append-only** |
| `docs/lessons-learned/` | how a specific failure happened | yes, **append-only** |
| `docs/eval-reports/` | what the numbers were at a point in time | yes, **append-only** |
| `docs/design/` | how a mechanism works **today** | no, revised in place |

`docs/todo.md` is the backlog; `docs/evaluation-plan.md` is what the framework
*should* become, not evidence about what exists. Append-only means old entries
are history — corrections go in the newest entry, never backwards.

**Dev-log voice.** Sessions are worked jointly by Bertan and an AI assistant.
Never write a bare "I": name the agent ("the assistant", "Bertan"). Passive is
correct for facts about the system; active with a named agent is required for
decisions, errors and corrections. Never use passive to soften an error. These
directories are public and are read by people evaluating the work.

**Rationale lives next to the code.** Module and class docstrings here carry the
measurement and the rejected alternative, not just the description. When changing
such code, update the reasoning with it — a stale docstring here is a defect, and
a claim without a number is a claim to re-measure.

## Working conventions

- Sequential `dev-NN` branches; merge into `main` by PR only, never commit to `main`.
- Deliver one reviewable step at a time on multi-part builds.
- A red suite mid-refactor is acceptable — verify against the recorded snapshot
  in the dev-log rather than insisting on green first.

## What an unattended agent may do to this repository

An agent may push the branch of the linked worktree it is working in —
non-forced, positively naming that branch, to a remote this repository has — and
nothing else. It may open a pull request, comment on one, edit one and read one,
through `gh pr view` or through a `gh api` request that does not write. It may
not merge one, review one with a verdict, close or reopen one, or create or
delete a release. `main` and `dev-NN` are Bertan's to push; `main` is
additionally protected server-side by the `main-branch-protection` ruleset,
which requires a pull request.

"Positively naming that branch" is literal: write `git push origin <branch>`.
A bare `git push`, and `git push origin` with no refspec, are refused. Their
destination comes from configuration — `push.default`, a `remote.<name>.push`
refspec, the branch's upstream — and an agent may run `git config`, so a rule
resting on a configured value can be arranged around one command earlier. The
destination has to be in the command for the hook to have anything to check.

Enforced by `.claude/hooks/no-git-push.sh` and `no-pr-decisions.sh`, both built
on `.claude/hooks/lib/command-scan.sh`, which answers where a command starts and
where its arguments end — that question, re-derived in each hook, was the whole
of five defects. `bash .claude/hooks/probe-hooks.sh` checks the boundary in both
directions and prints which context it ran in. Hooks see only the Bash tool, so
Bertan's own terminal is not subject to any of this.

`dev-NN` rests on those hooks alone and can rest on nothing else: an agent pushes
as `bgunyel`, so a server-side rule on `dev-*` would block Bertan too, and naming
him a bypass actor would hand the agent the bypass. Whether the command runs in a
linked worktree is the only signal that separates them. `main` is different —
there the policy is identical for both, which is why a ruleset carries it.

**Deliberately left open.** These stop mistakes, not adversaries: they read the
text of a command, so a caller that means to evade them can. Two consequences are
accepted rather than fixed. A push or a decision inside `sh -c` is refused
outright rather than assessed, because a destination inside quotes cannot be
read. And a quoted multi-line string whose continuation line begins with one of
these commands is refused although it is only prose — a blocked comment is
visible and one edit away, a silently permitted push is neither.

## Agent skills

### Issue tracker

GitHub Issues on `bgunyel/clause-and-effect`, via the `gh` CLI. See
`docs/agents/issue-tracker.md`.

### Triage labels

The five canonical roles, each label string equal to its name. See
`docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` and `docs/adr/` at the repo root, neither of which
exists yet. See `docs/agents/domain.md`.

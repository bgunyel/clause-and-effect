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

`make upgrade-safe` must pass before a PR is merged into main branch. `make scan`/`upgrade-safe`
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

**Guard code is a third standard of care.** Eval code is held above product code
because a defect there corrupts every measurement taken on it. `.claude/hooks/`
is neither: a defect there corrupts no measurement, and it can permit an act
that closes every open pull request. Its evidence is the check suite —
`bash .claude/hooks/check-hooks.sh` — and no fix lands without a check that
fails without the fix. That fix also declares its issue's `GH-<n>` entry in
its issue file, beside the check it tags, and
`bash .claude/hooks/generate-requirements.sh` writes the entry's file,
`.claude/hooks/requirements/GH-<n>.md`, from the declaration, so the suite's
coverage check can see the requirement it establishes; the entries written
before that (#205) stay hand-written files, and the `US-`/`FR-` boundary stays
in `.claude/hooks/requirements.md` (#200). The shared
tokeniser alone has had nine defects found by review rather than by the suite:
five in one round on PR #35, three in a second, one in a third — and two of
those five arrived with the fixes to the previous two. Every one was silent and
in the permitting direction, and the suite was green before each round. A check
suite is evidence about the cases it names and about nothing else.

`check-hooks.sh` is the suite's driver, and the command you run; the checks
themselves are in the files under `.claude/hooks/checks/` that it sources. A new
issue's checks go in an **issue file** of their own, `checks/GH-<n>.sh`, and the
driver's header states the conventions for adding and moving them
(`docs/adr/0004-check-suite-split-by-issue.md` says why). Where this file says
`check-hooks.sh` does something, it means the suite.

Whether those checks can fail is a second question, and `bash
.claude/hooks/mutate-hooks.sh` is where it is asked (#107). It breaks one
registered rule at a time in a copy of `.claude/hooks/` — never in this one — and
a mutation counts as caught only when every requirement ID the registry names for
it has a failing check. Slow enough that nothing runs it for you, and `--list`
says how slow at the size the registry is now: it multiplies a measured rate by
the runs a pass needs, so the figure follows the registry instead of standing
still while it grows (#148). The *rate* is a measurement and not a derivation —
it goes stale as the suite grows, which it did, by more than a factor of two in
three days — so it is dated, and a check goes red once the suite has outgrown
it. Two of its rows are self-tests, one whose edit matches nothing and one
registered against a requirement its edit cannot reach, because an edit that
silently fails to apply reads exactly like evidence and is none — and their
number is pinned as a literal, so a third cannot be registered without a check
going red.

Every *count* about that registry is derived by `--list`: the rows, the files
they touch, the requirement IDs they name, how many requirements are active, and
the runs a whole pass costs. What it costs in wall-clock is that last count times
a rate, and the rate is the one number here nothing can derive. What the registry
covers is there too — a row per rule, not per requirement, so a requirement with
a row is one some mutation reaches rather than one whose every check has been
exercised. Several of those numbers are *also* written as literals in the
check suite, and that duplication is deliberate rather than a lapse: a
literal in a check earns its maintenance, because adding a row turns it red and
somebody has to look at it. A number in a comment earns nothing, because nothing
reads it and nothing turns red when it rots — which is why the harness's header
now states none, and why the one magnitude it kept had gone wrong by a factor of
two before anybody noticed.

Issue #84 is the same shape one level out, and it is the reason that last
sentence is worth re-reading. The defect was not in the tokeniser but in the
*load* of it: two of the four boundary hooks sourced `lib/command-scan.sh` with
no guard at all and a third guarded only one of the three functions it calls,
so renaming a `cs_*` function — a refactor, not an accident — left a forced
push, a `gh pr merge`, a `gh pr create --base main` and a push to `main` all
permitted.
The suite was green throughout, 728 checks when the issue was filed and 830 by
the time it merged, because it asked that question of two hooks of four and of
one function of three.

`lib/command-scan.sh` now carries THE LOAD CONTRACT: what a guard has to do, and
why the copies are not one sourced preamble — a preamble is a file, so sourcing
it needs the same guard one level up. It deliberately does **not** count its
consumers, and #69 is why. That issue rebuilt the two convention hooks on the
tokeniser in the same week and hit the identical trap from the other end,
requiring `cs_split` and not `cs_normalise` — so the count was four when #84
was filed and six when it landed. The check suite derives the list off the
files instead, and derives each consumer's call set against its required set: a
fixture per consumer per function says the guards are right today, and only the
derivation survives the next `cs_*` added to one of them.

## Documentation

Six directories with different jobs; the distinction erodes easily
(`docs/design/README.md` draws the record-vs-current-state split in full, and
the line between `docs/design/` and `docs/research/`):

| directory | answers | dated? |
|---|---|---|
| `docs/dev-log/` | what happened in a session, and why | yes, **append-only** |
| `docs/lessons-learned/` | how a specific failure happened | yes, **append-only** |
| `docs/eval-reports/` | what the numbers were at a point in time | yes, **append-only** |
| `docs/design/` | how a mechanism works **today** | no, revised in place |
| `docs/adr/` | why a decision was taken, and what was rejected | no, superseded rather than revised |
| `docs/research/` | what is true **outside** this repository — a provider, a library, a spec | no, revised in place; claims carry their source |

`docs/todo.md` is the backlog; `docs/evaluation-plan.md` is what the framework
*should* become, not evidence about what exists. Append-only means old entries
are history — corrections go in the newest entry, never backwards.

`ls docs/` returns seven directories, not six. `docs/agents/` is the seventh and
is deliberately not in the table: it holds agent configuration — the issue
tracker's conventions, the triage label mapping, the domain glossary — rather
than documentation of the system, and is described under **Agent skills** below.
It is counted here so that the next reader does not have to wonder whether it
was forgotten.

`docs/research/` holds the output of a `wayfinder:research` ticket: a question
answered against primary sources, every claim attributed, and anything not
actually observed marked `[NEEDS OBSERVATION]` so a later session can grep the
file and get a checklist. It is outside the append-only guard deliberately —
clearing a marker *is* the point, and freezing the file would make the
checklist unworkable; git holds the history. What it must not become is a
second `docs/design/`: a research document describes something this repository
does not control, and stops before the decision it unblocks.
`docs/research/README.md` states the conventions.

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

* **Unless otherwise stated, an agent shall create a dedicated worktree for its work.**
* **Unless otherwise stated, an agent shall not work on a worktree created by someone else.**
* **If an agent finds out that a worktree already exists, it shall ask the user for permission to work in that worktree.**
* **When an agent finishes its work in its worktree, it will commit and push to its corresponding worktree branch.**

An agent may push the branch of the linked worktree it is working in —
non-forced, and naming that branch in the command, because a bare `git push`
takes its destination from configuration an agent can itself change: write
`git push origin <branch>`. That is the whole of what it may push. It may open a
pull request into the active dev branch — naming that base in the command, for
the reason a push names its branch: with no base given a pull request goes to
the repository's default branch, which is `main`. Write
`gh pr create --base dev-NN`, and the same base in whichever of the four
spellings is used, `gh pr edit --base` and the two `gh api` forms included. It
may comment on one, edit one without moving its base, and read one, through
`gh pr view` or through a `gh api` request that does not write. It may not merge
one, review one with a verdict, close or reopen one, or make any write to a
release; it may read one, through `gh release list`, `view`, `download`, `verify`
or `verify-asset`, and through a `gh api` request that does not write. A
worktree branch lives as long as its pull request, and work moves to a new one
once that has merged. `main` and `dev-NN` are Bertan's to push; `main`
is additionally protected server-side by the `main-branch-protection` ruleset,
which requires a pull request. Enforced by `.claude/hooks/no-git-push.sh`,
`no-pr-decisions.sh`, `no-commit-to-main.sh` and `no-work-on-stale-branch.sh`,
all four built on `.claude/hooks/lib/command-scan.sh`, the last of them reading
refs that `report-stale-branches.sh` prunes for it each session;
`bash .claude/hooks/check-hooks.sh` checks the boundary in both directions, and
that this paragraph names every hook that carries it. Hooks see only the Bash
tool, so Bertan's own terminal is not subject to any of this.

`dev-NN` rests on those hooks *because* an agent currently acts with Bertan's
credentials, so no server-side rule can tell the two apart. That is a
configuration choice and not a constraint: giving the agent its own actor would
move the rule to a ruleset. Why it was not done, and what would have to be
checked first, is in `docs/adr/0001-hooks-not-ruleset.md`.

**Where a worktree branch starts.** A new worktree branch starts at the active
dev branch's tip, which is `origin/dev-NN` and never the local `dev-NN` — the
*active dev branch* entry in `CONTEXT.md` says why — and its fork point is set
when the worktree is created, by one of two routes:

- `git worktree add --no-track -b <branch> <path> origin/dev-NN`. Without
  `--no-track` git makes `origin/dev-NN` the branch's upstream, which reads
  `[gone]` once the dev branch is deleted, and the stale-branch guard then calls
  a branch merged that was not.
- `git reset --hard origin/dev-NN` as the first act in a worktree
  `EnterWorktree` has just created — never in one it entered, where the reset
  discards that worktree's commits.

A worktree branch is never cut from another worktree branch's unmerged work: its
pull request targets the active dev branch and would carry the parent's commits.
A subagent that needs a parent's state runs without `isolation: "worktree"`.

Nothing enforces this rule. A branch that skipped it starts where
`worktree.baseRef` in `.claude/settings.json` puts it, which is `origin/main`
unless a machine's own `settings.local.json` says otherwise. The stale-branch
guard refuses its first commit only while `origin/main` is an ancestor of the
active dev branch — which the SessionStart report reads every session, as its
`main ancestry` line, and argues beside that read.

**Deliberately left open.** These stop mistakes, not adversaries: they read the
text of a command, so a caller that means to evade them can. Seven consequences
are accepted rather than fixed, and they are numbered because the count is the
part that went stale last time.

1. **A wrapped command is refused outright rather than assessed**, because
   nothing at all can be read out of a quoted payload — not a destination, not
   a subcommand, not an HTTP method. So `bash -c "git push origin <branch>"`
   is refused though it names the one branch an agent may push, and
   `sh -c "gh pr create --base dev-NN"` though it names the right base, and
   `bash -c "gh pr view 5"` though the paragraph above grants that read in as
   many words. Only what a hook guards is refused, so `bash -c "gh issue list"`
   and `bash -c "make test"` are untouched. Run it unwrapped.

2. **The refusal reaches an unwrapped command that merely shares a line with a
   wrapper**, in either order: `bash -c "make test" && gh pr view 5` and
   `gh pr view 5 && bash -c "make test"` are both refused. Each hook asks two
   questions of the whole line — is a wrapper in a command position, and does
   the line carry anywhere on it the thing this hook guards — and never asks
   whether the two are the same command, because telling them apart would mean
   reading inside the quotes, which is the thing that cannot be done. Only the
   second question is the loose one: a wrapper named in passing sits in no
   command position, so `echo "run bash -c later" && gh pr view 5` is
   untouched.

   The two halves are that one shape with a different second question, and the
   width of that question is the whole difference between them.
   `no-git-push.sh` asks for a push, so an ordinary `git status` beside a
   wrapper is untouched. `no-pr-decisions.sh` asks for every surface that
   decides a pull request or a release: the `pr|release|api` group after a
   `gh`, and the REST and graphql spellings of the same decisions, which name
   no `gh` at all. So it never reaches the verb of a wrapped `gh pr` — every
   read of that surface is refused with its writes — while
   `bash -c "make test" && echo state=closed` is refused on the bare word, and
   so is a `gh issue` command whose body text merely carries `pr`, `release` or
   `api`, quoted text having no argument structure to say whether a word is a
   subcommand or prose. `no-pr-decisions.sh` sets that trade out under *The
   trade, taken knowingly, in three parts*, and `check-hooks.sh` pins each.

3. **A quoted multi-line string whose continuation line begins with one of
   these commands is refused although it is only prose** — a blocked comment is
   visible and one edit away, a silently permitted push is neither.

4. **A base written after a command substitution is not seen as that
   command's**, because the tokeniser cuts on its parens; name the base first.

5. **Nothing in this repository guards `.claude/`**: the only `Edit|Write` hook
   covers three `docs/` directories, so the hook files and `settings.json` that
   carry this boundary are not themselves covered by the boundary. Whether an
   edit to them prompts at all is left to the harness's own permission
   settings, which are configuration rather than a rule of this repository.
   That gap is open by the same standard that decides the rest — an agent does
   not *mistakenly* rewrite the hook that just refused it — and closing it
   would make every future hook change a two-person procedure for no gain
   against the threat actually named.

6. **A command word that is a parameter or a command substitution is not
   resolved**, because no amount of reading the text says what it expands to.
   So `$(command -v gh) pr merge 5`, `` `command -v gh` pr merge 5 `` and
   `$GH pr merge 5` are permitted, and so are the `git` spellings of each.
   Raised as recommendation 4 of #117's triage, which called it a judgement
   call to settle before implementing; it was settled by measuring, against
   75,346 Bash commands taken from 661 local session transcripts.

   **The close was written first and rejected on its own numbers.** Adding a
   `$(` alternative to `CS_WRAPPER_RE` closes none of the four shapes above.
   The wrapper block is an *and* — is a wrapper in a command position, and does
   the line carry what this hook guards — and the second question is answered
   by patterns that want the tool's name followed by whitespace. A command
   substitution eats that boundary: the line reads `gh)`, not `gh `. Measured,
   the alternative left `$(command -v gh) pr merge 5` and
   `$(command -v git) push origin main` permitted, flipped only
   `$(command -v gh) api -X PUT repos/o/r/pulls/5/merge` — which matches on the
   `/pulls/…/merge` literal and needs no `gh` at all — and refused **9**
   commands that should pass, 8 of them lines of `check-hooks.sh` being edited,
   such as `"$(printf 'sudo git commit -m "git push --all origin"\n' |
   cs_split)"`. Closing it for real would mean widening the second question so
   that `gh)` counts as `gh`, which is consequence 2's loose question widened
   across all prose.

   **The three shapes are not one shape, and the counts are why.** In command
   position, as `CS_WRAPPER_RE` reads one: `$(…)` 88 lines, `` `…` `` 2,469,
   `$VAR` 377. Backticks are overwhelmingly markdown inline code inside a
   heredoc — and that is not a measurement artifact, because these rules read
   raw text too, so a backtick rule would refuse `cat > notes.md <<'EOF'`
   whenever the prose says `` `git push` ``. That is consequence 3's accepted
   class widened by three orders of magnitude. `$VAR` is an agent being *more*
   careful about which binary it runs — `$PYTHON -m pytest` — and refusing it
   punishes the care.

   **A variable is only unresolved while it is the whole word.** `"$VENV/bin/gh"`
   is refused, because the reduction in `cs_split` resets at each `/` and the
   basename it is left with is `gh`, which is the name it spells whatever the
   directory part expands to. So the permitted shape is the one where the word
   is a variable and nothing else, and the refused shape is a path whose last
   component is written out. That is the line this consequence draws, and it was
   drawn by a review of the branch that wrote it: the example here said
   `"$VENV/bin/gh"` was permitted, and the same commit refused it.

   The standing rule these hooks are held to is that a newly found evasion
   earns a fix only if it is a shape an agent would plausibly write, and none
   of the three is: every occurrence measured was prose, an assignment, or a
   deliberate probe. `check-hooks.sh` pins all three as permitted, so the
   decision is a check and not only this paragraph.

7. **Prose is refused when a separator and then a control word or a `)` stand
   in front of a wrapper word**, on a line that also carries a guarded
   command. Since #134 the anchor opens a command position after every
   character `cs_split` cuts on and after every word it strips, and that class
   is still quote-blind — consequence 2's loose question, one list wider. So
   `gh pr comment 5 --body "if true; then bash -c y; fi is now refused"` is
   refused, a comment describing the change that refuses it; so is
   `grep -nE "(ba|z)sh -c" notes.md && gh pr view 5`, the grep a session
   working on these hooks writes, though the same grep alone is untouched. It
   costs refusals and never permissions, and each shape is a check.

   Consequence 2 above still holds of a wrapper merely named in passing, with
   nothing in front of it: `echo "run bash -c later" && gh pr view 5` sits in
   no command position and is untouched. What changed is that a separator or a
   `)` inside the quotes now makes one, and reading whether those quotes are
   prose is the thing a raw-text rule cannot do.

## Agent skills

### Issue tracker

GitHub Issues on `bgunyel/clause-and-effect`, via the `gh` CLI. See
`docs/agents/issue-tracker.md`.

### Triage labels

The five canonical roles, each label string equal to its name. See
`docs/agents/triage-labels.md`.

### Domain docs

Single-context: `docs/adr/` holds the ADRs; `CONTEXT.md` holds the glossary. It
is written lazily — a term is added when a collision has actually been resolved
— so it stays short enough to read whole, and this line deliberately does not
enumerate it: the sentence that did named two terms of five and went stale
without saying so. It does not count the ADRs either, for the same reason and
on the same evidence — the clause that did said one, and #143 added a second in
the commit that cites this sentence's own lesson back at it. Several of the
hooks above cite `CONTEXT.md`, and `.claude/hooks/check-hooks.sh` holds those
citations to what it says; it holds this line too, since review of that commit
found nothing held it at all. See `docs/agents/domain.md`.

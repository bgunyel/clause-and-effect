# Dev Log

One entry per working session, written at the end of it. The log records what
happened and why — decisions taken, things tried that did not work, and the
state the next session inherits. It is the *reasoning* companion to `git log`,
not a replacement: commits say what changed, these say why.

**This directory is public and is read by people evaluating the work.** An entry
is a technical record, not a diary. It is also the source material for the
session's public write-ups, so accuracy about *who did what* is not a stylistic
preference — it is the difference between evidence and noise.

## Voice and attribution

Sessions here are worked jointly by a human engineer and an AI assistant. An
entry that blurs the two is worse than useless: it hands the assistant's errors
to the engineer and deletes the engineer's catches, which are the most valuable
thing in the record.

- **Never write a bare "I".** There is no single narrator. Name the agent:
  *"the assistant"* and *"Bertan"* (or *"the engineer"*).
- **Passive voice is correct when the agent carries no information** — facts
  about the system. *"99 articles were extracted."* *"The gate was reproduced
  against the pre-fix corpus."* Most of an entry should read this way.
- **Active voice with a named agent is required when attribution carries
  information** — decisions, errors, corrections, and anything a reader would
  otherwise misassign. *"The assistant classified six cases as failures; Bertan
  read Article 53 and established the rule was wrong, not the data."*
- **Never use passive to soften an error.** *"An error was made"* records
  nothing. Say who, and what the reasoning was that produced it.

## Register

- **Lead with the finding, not the chronology.** *"The grounding rule produced
  false positives on six cases"* — not *"the session opened with a question
  about..."*. Sequence only where causality depends on it.
- No suspense, no reveals, no exclamation. A reader skimming for the state of
  the system should get it from the headings.
- Section titles state findings, not events.

## Conventions

- File name: `devlog_YYYY-MM-DD_SESSION-NAME.md`, where `SESSION-NAME` is the session 
  name of the agent writing the dev-log. 
- If the agent does not know its session name, or it is in doubt, it should call 
  the `ListAgents` function to see its session name.
- A dev-log entry should start with date and time of the entry. Open with 
  branch, commit range, and how far ahead of its root branch the current branch 
  ended up.
- If the dev-log file that the agent is trying to write already exists, 
  the agent should  append a new dev-log entry to the file with a date and time. 
- Written for technical readers who know the codebase. Prefer measured numbers
  and commit SHAs over recollection — and say which figures were measured versus
  recalled.
- Record dead ends and mistakes, not just the path that worked — a session that
  only lists successes hides the expensive part. Attribute each one.
- Where a claim was checked against a primary source (the PDF, the regulation,
  a module's actual code), say so. Verification that only ruled out one link in
  the chain is not verification, and the entry should make that distinction.
- Close with what is still open and what the next session should pick up.

## Entries

- [2026-08-01 · session 1](devlog_2026-08-01_session-1.md) — GDPR corpus
  regeneration: docling accelerator pin, article-header collapse, chapter
  scaffolding leak, Qdrant point-ID rework, re-index.
- [2026-08-02 · session 1](devlog_2026-08-02_session-1.md) — golden-set QA
  baseline, OCR soft hyphens, cached docling-export pipeline, tier-5 grounding
  normalization, and the discovery that the grounding rule was itself producing
  false positives.
- [2026-08-03 · session 1](devlog_2026-08-03_session-1.md) — leakage keyed on
  self-reference, a new self-containment gate, 25 questions reworded, §7.3
  reconciled with the gates that exist, and the finding that provenance and
  sufficiency are uncorrelated.
- [2026-08-05 · session 1](devlog_2026-08-05_session-1.md) — sufficiency criterion
  settled on `art7_case3`, stages A and B of the judge built, and the discovery
  that docling's markdown serializer destroys the paragraph hierarchy in 43 of 99
  articles — severing stems from their sub-items in the index.
- [2026-08-06 · session 1](devlog_2026-08-06_session-1.md) — corpus rebuilt from
  the docling document tree (grounding 299 → 319 clean, zero regressions), the
  same defect found one layer down in the chunker with Article 4 as the worked
  example, and chunk sets made a hashed, provenance-carrying artifact.
- [2026-08-07 · session 1](devlog_2026-08-07_session-1.md) — priority reset to
  the evaluation pipeline under the rule that the eval must be flawless while the
  algorithm need not be; first two chunk snapshots written and indexed (196
  orphaned points deleted, every point now stamped with its chunk set); tests
  81 → 180, of which the interesting result is the four mutations that survived
  because the tests were green for the wrong reasons.
- [2026-08-07 · session 2](devlog_2026-08-07_session-2.md) — the `index_chunks`
  seam split from the write primitive, a `chunking` package extracted (a
  three-field dataclass was costing 9.78s to import), `Chunk` retyped and the
  chunker lifted out of the parser, a circular import held closed by two dead
  lines, and regulation constants collapsed from three free parameters to one
  lookup. Ends mid-refactor with 58 failing tests, enumerated.
- [2026-08-09 · session 1](devlog_2026-08-09_session-1.md) — the chunking
  refactor finished and the `vector_db` source side reviewed item by item; the
  digest became caller-supplied (a recorded property deliberately reversed);
  output routed through logging, with `RichHandler` tried and rejected for
  breaking a hash across two lines. Ends with 24 failing tests in
  `test_vector_db.py`.
- [2026-08-10 · session 1](devlog_2026-08-10_session-1.md) — `test_vector_db.py`
  repaired 24 → 0 with every rewrite mutation-checked, two of the three handover
  predictions found wrong, and the first baseline snapshot (`5caac594…`) written
  against a clean tree and merged to `main`. The sufficiency judge documented and
  split into a package — where a claimed import-cost property was measured and
  found absent. Golden-set provenance established after the assistant concluded
  it wrongly from git twice. `ai_common`'s fix order shown to be forced: two of
  three candidate optimisations measure as worth zero until the package
  `__init__` is fixed.
- [2026-08-10 · session 2](devlog_2026-08-10_session-2.md) — spent entirely in
  the **`ai-common`** repo. The `__init__` fix landed in an hour (`from
  ai_common.enums import …` 4.11s → 0.14s); the rest went to the GuardDog
  wrapper sitting uncommitted beside it, where the tier-2 gate turned out never
  to have gated — `guarddog pypi scan` exits 0 whether it found nothing, found
  malicious indicators, or never downloaded the package. Rebuilt to derive its
  own verdict from JSON, with a machine-wide cache that concurrent projects no
  longer clobber and an `upgrade-safe` that no longer leaves `uv.lock` upgraded
  and unverified on Ctrl-C. Then guarddog 2.10.0 → 3.1.0, and a one-minute smoke
  scan produced three blockers — a dead sandbox, 61 renamed rules, and a guard
  that eats the error it was written to surface — so the hour-long sweep was not
  started.
- [2026-08-11 · session 1](devlog_2026-08-11_session-1.md) — all three GuardDog
  3.1.0 blockers closed: the "sandbox cannot get entropy" failure turned out to
  be a Landlock filesystem denial wearing an entropy error's clothing, settled by
  one `strace` line. The tier-2 gate re-based off rule names onto risk severity
  and the new threshold measured against 74 real dependencies; three Makefile
  defects the measurement exposed tightened. Tests 92 → 103, 13 mutants killed
  with no survivors.
- [2026-08-12 · session 1](devlog_2026-08-12_session-1.md) — the high-severity
  `google-genai` finding shown to be `eval(` matching inside the word
  `Retrieval(`, an unguarded JavaScript pattern applied to Python source, with
  `pillow` blocking on the same upstream defect. Because the cache could not have
  answered that question, a report store, a review ledger and a backfill of 74
  calibration reports were built around it; four waivers written, and the pyyaml
  assessment corrected in the package's favour. Tests 103 → 127, 19 mutants, 0
  survivors.
- [2026-08-13 · session 1](devlog_2026-08-13_session-1.md) — tier 1 found red on
  the committed lock and taken 5 advisories → 3; `ai-common` PR #24 merged and
  Dependabot alert #33 identified; lockfile independence measured — a merge that
  moved 25 packages there moved none here; `make test` found to have been running
  nothing since `57c37a5`; the two langchain versions shown by experiment to be a
  stale fork rather than a platform requirement; a 66-minute sweep aborted on
  Bertan's question and the abort vindicated by the candidate lock; and Python
  found 12 patch releases stale, with 30 advisories neither tier of the gate can
  see.
- [2026-08-13 · session 2](devlog_2026-08-13_session-2.md) — `cuda-toolkit`
  shown not to be unscannable at all: uv reads a version from the wheel
  filename, PyPI keys its index on the canonical form, and the two disagree on
  4 of 39 releases. Fixed in `ai-common` PR #25, which let tier 2 reach a
  verdict on every package for the first time — 178 packages, INCOMPLETE 0,
  eight blockers. Six of the eight are one rule firing outside its declared
  scope; four waived, and session 1's reading of `docling-slim` found inverted —
  its `curl … | sh` is a log message, while the two packages that really do
  fetch-and-execute were never reached by the aborted sweep. Underneath it,
  uv found 16 months stale, which blocks the interpreter upgrade and puts the
  resolver that writes `uv.lock` in the same blind spot as the interpreter;
  plan written, not executed.
- [2026-08-16 · session 1](devlog_2026-08-16_session-1.md) — the uv plan
  executed end to end: both repositories on uv 0.12.5 and CPython 3.13.15,
  pinned and committed, with the old resolver now refusing to run in either.
  Two of phase 5's three exit criteria turned out to have been unsatisfiable
  before the upgrade began, and the sweep that replaced them produced the first
  complete committed-lock tier-2 baseline the project has — 180 packages,
  INCOMPLETE 0, eight blockers, none attributable to the upgrade. The larger
  finding came from a phase-1 side effect: **the sweep installs the candidate
  it is about to judge, and a rejected candidate stays installed**, in the
  environment that runs the code and in no artifact either tier examines.
  Demonstrated, fixed with `uv run --frozen --no-sync`, given a test in both
  suites, and documented — and the test then caught the same drift again on its
  first run.
- [2026-08-17 · session 1](devlog_2026-08-17_session-1.md) — an `upgrade-safe`
  found stalled at 85 minutes on a dead socket nothing was watching for:
  `pygit2` clones with no timeout, and `_scan_once` ran `subprocess.run` with
  none either, so one silently-dropped connection held the sweep open
  indefinitely. Bounded in `ai-common` #28 and #29, both mutation-verified by
  wall clock. The gate's remaining eight blockers were then cleared by twenty
  individually-approved decisions — and the method changed halfway through, when
  comparing *reported* findings across versions was shown unsound: GuardDog's
  `max_hits` truncates the evidence, and `transformers` reported one qualifying
  file out of ten. Both tiers now pass and `make verify`, structurally unusable
  here while tier 1 was red, exits 0. Also found: the installed GuardDog is not
  the stock 3.1.0 wheel.- [2026-08-17 · session 2](devlog_2026-08-17_session-2.md) — stage C built and
  tested (suite 249 → 298), the full A→B→C chain running over the eight probe
  cases, and core-claims-only settled by Bertan on evidence rather than cost:
  stage B answers only what was asked, so an auxiliary claim comes back `absent`
  almost by construction. The finding that outranks the code came from running
  it — **stage A is not stable at temperature 0, and the instability reaches the
  verdict**: `art8_case1` returned 1, 1, 2 and 1 core claims across four
  identical runs, and the two-claim run flips the case from `sufficient` to
  `insufficient`. Two rounds of prompt work took the observed failures to zero
  and introduced a new one.
- [2026-08-22 · session 1](devlog_2026-08-22_session-1.md) — stage A split into
  two independent calls (A1 writes the shortest sufficient answer, A2 tags the
  claims, neither sees the other's output), six probe scripts, and 60 stability
  calls. A1 measured clean everywhere it was pointed; A2 unstable on 3–4 of 6
  cases, two of those failures degenerate output rather than disagreement. A
  transport failure latent in all five stages was found and guarded —
  `with_structured_output` returns `None` when output will not coerce, and every
  stage read a field straight off it. Both of the session's larger results are
  Bertan's reframings: **the judge is a defect finder for the golden set, not a
  classifier fitted to it**, which removes the train/test framing entirely, and
  **granularity is soft while the core/auxiliary boundary is hard**, which
  invalidates the metric §4.6 uses.
- [2026-08-23 · session 1](devlog_2026-08-23_session-1.md) — a judge run made
  auditable: every stage now returns what its call cost, read off the raw message
  that `include_raw=True` keeps, and every A2 stability sample writes a
  provenance-carrying record into `docs/eval-reports/`. Eight OpenRouter models
  added to `ai-common` (#31) and the config rebuilt from a list of names — where
  a shared `model_args` dict would have let the Gemini panelist rewrite the
  sampling of the other eight, since `ai_common.get_llm` mutates what it is
  handed. The larger result is about the instrument: **two more stability samples
  came back 0 of 6**, putting four samples of the same prompt and model at 4/6,
  3/6, 0/6, 0/6 — N=5 cannot support the comparison the next measurement was
  going to make.
- [2026-08-23 · session 2](devlog_2026-08-23_session-2.md) — the panel stood up,
  and almost everything found was about the instrument rather than the judges:
  reasoning effort silently lost after the first call, no timeout anywhere, and
  structured output failing for reasons unrelated to judgement — so each panelist
  now gets its own measured channel, at the cost of the uniformity the config
  otherwise keeps. The panel does agree, 4–5 of 6 cases unanimous, but every run
  disagreed with the one before it by about as much as the panelists disagreed
  with each other. The most consequential finding is Bertan's, from the
  OpenRouter console rather than the code: **MiniMax's "failures" were
  successful, billed generations that we discarded.**
- [2026-08-25 · session 1](devlog_2026-08-25_session-1.md) — three facts the code
  was holding at the moment of failure and throwing away — the price of a failed
  call, the generation id, the reasoning budget — recorded as
  `CallRecord(generation_id, cost, reasoning_tokens)`. Once recorded, two beliefs
  about the panel proved wrong: the reasoning-suppression suspicion **does not
  reproduce** on the model that raised it, and A2 stability at 25 runs reads a
  substantive **0 of 6**, the one flagged case differing by the word `and`.
  Bertan's catch changed the most code — `[0]` on the roster at ten call sites
  makes the subject of a measurement a consequence of list order.
- [2026-08-25 · session 2](devlog_2026-08-25_session-2.md) — no code, by intent.
  MiniMax's channel failure was traced to its root and is **not about MiniMax**:
  OpenRouter routes one model id to whichever upstream provider it picks, those
  providers differ in what they can do, and nothing recorded which one answered.
  Every MiniMax success on record came from a provider reached by **falling back
  from one that returned 429** — the channel assignment was decided by a rate
  limiter. The premise `llm_config.py` rests on is broken one layer below the
  configuration. Bertan directed that calls be logged to a database; the session
  closed with a draft design document and eleven open questions.
- [2026-08-26 · session 1](devlog_2026-08-26_session-1.md) — the call-log design
  was finished, and the measurement taken to finish it changed what is being
  built. **A retried call makes an unbounded number of billed generations and
  nothing above the socket could name more than one of them** — 67% of one
  call's cost unaccounted in the mild case, 100% in the exhausted one.
  `max_retries` turns out to be a 300-second time budget rather than a count, so
  one logical call has a fifteen-minute worst case; a callback handler was
  proposed as the capture mechanism and **rejected on measurement**, because it
  sees no more of the retries than the call site does. The served provider,
  meanwhile, is free in the raw response body. The log became three tables with
  a socket-level attempt row, and Bertan's clarification that **the LLM server is
  not the provider** exposed a column the assistant had misnamed.
- [2026-08-26 · session 2](devlog_2026-08-26_session-2.md) — the call log built
  as far as its schema: dependencies, two engines, three tables, 141 new tests,
  and nothing written to the database. Two findings, both about the gap between
  a decision and its effect. **The statement timeout was never in force** —
  Supabase's pooler consumes the startup packet, so `pg_sleep(30)` ran to
  completion while the code read as correct; the repair needs a `SET` *and* a
  commit, because both drivers leave it in a transaction they never end. And
  **the same one-row write costs 47 ms or 141 ms** depending only on whether
  SQLAlchemy wrapped it in a transaction. A trigger proposed for `updated_at`
  was measured out of existence when Bertan's two questions exposed a third
  option the assistant's framing had hidden. Bertan's reading of OpenRouter's
  documentation gave the design its strongest argument: **an uncaptured
  generation id is unreachable by API, permanently.**
- [2026-08-26 · session 3](devlog_2026-08-26_session-3.md) — the call log becomes
  a mechanism: Alembic applied to the live instance, the repository layer, and
  `llm_call()` wrapped around all five judge stages, at a spend of $0.00.
  **`pool_pre_ping` costs a quarter of what session 2 recorded** — 43.4 ms per
  write against the real insert, not 155 ms — and the row shape turns out to
  cost nothing at all. **`include_object` was measured in both directions**: on a
  shared Supabase project, autogenerate without it writes a migration that
  applies cleanly and drops somebody else's table. Bertan established that
  `llm_call()` belongs in a shared tier rather than inside the judge, and his
  second observation — that none of the four call statuses is judge-specific —
  removed a callback hook the assistant was about to design. Looking for the
  product path's call sites turned up **a second billed model call per answer,
  discarded**.
- [2026-09-04 · session 1](devlog_2026-09-04_session-1.md) — the model-call
  machinery lifted out of the judge into a shared `src/llm/` tier, on Bertan's
  constraint that **every LLM call in the repository goes through the logged
  wrapper**, not only the judge's. `src/eval/sufficiency/llm.py` is 158 lines
  against 695 and holds only the judge's vocabulary. Two departures from the
  recorded plan, both the assistant's: `StageResponse` subclasses the shared
  response rather than restating it, which makes a judge failure catchable as
  the shared one, and the log row's `error_message` drops the stage prefix
  because the row already has a `stage` column. One deferral could be deleted
  rather than moved — the channel constants no longer sit behind a module that
  imports `ai_common`. Also found: **`src/config.py` modified by nobody this
  session**, committed separately rather than folded into the refactor.
- [2026-09-13 · session 1](devlog_2026-09-13_session-1.md) — the agent boundary
  audited against #36, its own specification, in a grilling session that changed
  no files: nothing connected 32 stories and the decisions to the 499 checks meant
  to verify them, and the audit found nine defects, filed as #94–#102. The
  decisions, numbered Q1–Q35, are #103's, and the work is its seven sub-issues.
  Written two days later, from that record.
- [2026-09-15 · session 1](devlog_2026-09-15_session-1.md) — #104:
  `requirements.md` gives 150 requirements permanent IDs, every one of 1846
  checks is tagged, and the suite fails on an uncovered active requirement; the
  19 known gaps are marked rather than gated. Review of the first commit found
  eight defects in the coverage machinery, four of them permitting — among them a
  renamed heading that made a family of requirements vanish, and an awk exit
  status nobody read.
- [2026-09-16 · session 1](devlog_2026-09-16_session-1.md) — #105: the fifteen
  coverage gaps #104 left are closed by 85 checks, suite 1902 → 1987 with every
  earlier result unchanged, and `--matrix` drops from 19 gaps to 6 — three
  awaiting #110's runbook, three filed bugs. Two defects found while covering
  US-14 were filed rather than pinned (#130, #131). Review of the assistant's
  own commit then found three more in it, none of which any run would have
  caught.
- [2026-09-16 · session 2](devlog_2026-09-16_session-2.md) — Bertan's review of
  #132 found four defects, every one of them in what a check *claims* rather than
  what it does: a row tagged US-7 whose message names a create when the one-step
  correction for a refused retarget is a permitted `gh pr edit --base dev-NN`
  (filed as #133), the same tag dilution eight lines below one the assistant had
  just fixed, a `no-` prefix standing in for a decision so that a renamed boundary
  hook drops out of a loop in silence — measured, three of four — and a mutation
  count stale in four places. The count is 22; session 1's entry stands as
  written, since append-only means the correction comes forward. A second review
  round then found two more of the same family one level down — labels claiming
  more than their literals ask: an invariant check that named `main` and never
  looked for it, and a fenced-block extraction that read ```bash and skipped
  every other spelling in silence, so an `sh`-fenced refused push sat in the
  agent procedure with all 1987 checks green.
- [2026-09-16 · session 3](devlog_2026-09-16_session-3.md) — #107: the suite's
  two dozen prose claims of "mutation-checked" become re-runnable.
  `mutate-hooks.sh` breaks one registered rule at a time in a copy of
  `.claude/hooks/` and requires the requirement IDs that row names to go red;
  `check-hooks.sh` gains `$CHECK_HOOKS_DIR`, splitting what it judges from what
  it judges against. Ten rows, eight of them real and two self-tests, sixteen
  minutes, all as declared — and the harness's own baseline check fired on the
  first run, on a file the new harness had made the suite red by existing. Review
  of the assistant's own change then found six defects, five of them permitting,
  the first being two new checks green for the wrong reason in a change whose
  whole subject is checks that cannot fail.

- [2026-09-17 · session 1](devlog_2026-09-17_session-1.md) — Bertan's review of
  PR #142 returns ten findings and the verdict *not mergeable as is*. Sixty-nine
  text checks named their file relatively and so read this repository's hooks
  rather than the copy under judgment, every "does not source the library
  unguarded" pin among them — #84's defect in the section written to catch it.
  Three ways a survivor could be declared expected, a relative override that
  named this repository's own `lib/`, and a byte-identical guard that could not
  fire. The registry grows from 10 rows to 23, and its first full run found a
  rule with 36 checks tagged to it and no coverage: nothing in the suite stood a
  worktree on the branch the hook refuses to push.

- [2026-09-17 · session 2](devlog_2026-09-17_session-2.md) — a grilling session
  on #131 that established the issue was the fourth arrival of one defect: the
  boundary is written in a command's spelling, so each new spelling of one act
  arrives unguarded. #131 takes Q26's shape — refuse `gh issue develop`'s
  creating spellings, permit `--list` — after a fourth option the assistant
  proposed was rejected on a false premise of its own and on failing open under
  #135/#137/#139. The class underneath it is filed as #143, where a force-move
  and a deletion of `refs/heads/dev-NN` pass all seven registered hooks and
  `dev-NN` carries no ruleset — recorded in the entry as the only acts measured
  that neither layer covers, which session 3 corrects. The assistant's filing of
  #143 was then itself wrong about its scope — `PUT …/contents/?branch=dev-05`
  advances the ref with content attached — corrected the same day. `CONTEXT.md`'s
  *reserved act* turned out to carry the principle already and to be one clause
  short of it; ADR 0002 records the general form.

- [2026-09-17 · session 3](devlog_2026-09-17_session-3.md) — Bertan's review of
  PR #146 requests changes on five findings. The load-bearing one is a control
  the previous entry recorded as refused and is not: `gh api --method POST
  …/merges -f base=dev-05` passes all seven hooks, because no hook holds a rule
  matching `/merges` at all, and its effect advances the active dev branch on the
  remote — so the count of acts neither layer covers was wrong in four documents,
  and was already false in the paragraph it stood in. No document carries a count
  now. The `unarmed` added last session turned out to pin the clause's
  *placement* rather than its claim, going red on a correct document, and all
  three new checks read the wrap-sensitive fixture whose replacement `GH-97.2`
  had already built 200 lines above them — so `CONTEXT.md` had been shaped to fit
  a fragile check. Also found: `CLAUDE.md` still said `docs/adr/` holds one ADR,
  unpinned by anything, in the sentence that warns a reader off a stale
  enumeration.

- [2026-09-17 · session 4](devlog_2026-09-17_session-4.md) — #108 pins what the
  hooks decide when the environment they read is broken: git or gh off PATH, no
  repository, a detached HEAD, no origin, no `dev-NN` ref or two of them, and
  bytes in the command nobody meant to send. The finding that makes the open
  cells safe to write down is that no case exists where a hook's read of the
  environment fails while the command would still reach a repository — every
  spelling that reaches one is refused off the command's text. The session report
  no longer exits silently when it has nothing to report. A NUL byte written
  where the escape was meant made grep call the whole suite binary and emptied a
  derivation four hundred lines away; it happened four times over the branch, the
  later ones in the prose describing the earlier ones, and git refused the commit
  message for it. One permitting gap found and deliberately not fixed, filed as
  #144: a pull request based on a dev branch that is not the active one.

- [2026-09-17 · session 5](devlog_2026-09-17_session-5.md) — #128: a heredoc
  opener ending in an ODD run of trailing backslashes is a continued line to
  bash, which joins it before the body begins, so the command after the
  terminator runs and both boundary hooks permitted it. The body now begins where
  bash begins it, and the drop takes the trailing run off the line it begins
  after, because cs_join joins any trailing backslash and bash joins only an odd
  run. The first fix used cs_join’s looser rule and hid a command bash runs —
  found by review of PR #151, and the reason the entry carries three commits and
  a correction. A differential run of 2,580 shapes, each executed under bash to
  decide what really runs, puts dev-05 at 198 hidden pushes, that first fix at
  40, and this one at 0; suite 3657 → 4098 with dev-05 merged in. The same run
  read backwards counts what the direction costs — pushes bash never runs that
  the hook refuses anyway — at 750, 816 and 848, raised on the re-review and
  kept. The entry’s own heading read "session 2" until #177 — the number it was
  written under, before session 2 of this day turned out to be someone else’s —
  and it now reads "session 5", agreeing with the file name. ADR 0003 was
  amended to allow that one correction: a heading that contradicts its own file
  name is the entry’s label rather than a statement of history, so it is
  corrected in place instead of forward. Nothing else in the entry moved.

- [2026-09-17 · session 6](devlog_2026-09-17_session-6.md) — #133: the retarget
  arm of `no-pr-decisions.sh` refused a `gh pr edit --base main` and then named
  `gh pr create --base dev-NN` as the correction, which is the correction for the
  three creating arms and not for this one — `gh pr edit <n> --base dev-05` is
  permitted, so the fix is one word of the command already written. The `BASE`
  constant stays, because one sentence for four refusals is FR-23's own
  requirement; the per-arm tail names the retarget instead. GH-133 goes from a
  filed gap to active, and a registry row says the new check can fail. Review of
  the assistant's own change then found the first draft's third sentence, "No
  other edit is checked here", true of the arm but not of the file and pinned by
  no row; it was dropped, and a second review found the row that replaced it
  pinned a prefix rather than the whole sentence, so the clause tying a retarget
  to a create could have gone with the suite green. Both corrections are in the
  commit messages; the entry, written before either review, records neither.
  **Numbered 6 rather than 2.** It was written as session 2 and has collided on
  merge twice — first with #143's entry of that name, then, as session 5, with
  #128's. Each rename changed its title line and nothing else, so every count
  inside it is the one that stood at its first commit: 24 registry rows and a
  suite of 3659, against 34 rows and 4100 results after the second merge. That
  the ordinal is decided by merge order, and is knowable only afterwards, is
  #157.

- [2026-09-17 · session dev-issue-117](devlog_2026-09-17_session-dev-issue-117.md)
  — #117 and PR #152, in three parts, written in this order.

  **Part 1** — #117: a command word spelled as a path, quoted or
  backslash-escaped passed every hook, and so did the prefix and wrapper words
  the triage added. `cs_split` now reduces a command word to the name it spells,
  in one place, cell by cell rather than by building a string, because the
  string version was measured quadratic at the line cap. Review of the first
  commit found a prefix word matched by name as well, left unreduced.

  **Part 2** — #117's recommendation 4, a command word that is `$(…)`, a
  backtick or `$VAR`: the close was written, measured against 75,346 Bash
  commands from local session transcripts, and rejected on its own numbers — it
  closed none of the headline shapes and refused nine commands that should pass.
  Settled as consequence 6 in `CLAUDE.md`, with all three shapes pinned as
  permitted.

  **Part 3** — review of PR #152: the wrapper rule asks two questions, and #117
  had closed only the first. Each boundary hook's own surface pattern matched its
  guarded name by the bare spelling, so `bash -c '"gh" pr merge 5'` was
  permitted; widened in all four, measured at no verdict change across 476
  wrapper-carrying commands. A registry row was found mutating the wrong
  occurrence and still reporting `caught`.

  **Named for the session rather than numbered.** The three were written as
  sessions 2, 3 and 4, renumbered 7, 8 and 9 when they collided on merging
  dev-05 with #143's two entries and #108's, and collided again when #137's
  entries took 7 and 8. `db06477` replaced day-numbering with the writing
  session's name, so they now share one file. Each part is its original entry
  with heading levels changed and nothing else, so every count inside is the one
  that stood at its commit — 28 registry rows and a suite of 3903 at the end of
  Part 3, against 39 rows and 4346 results after the first merge.

- [2026-09-17 · session dev-issue-141](devlog_2026-09-17_dev-issue-141.md)
  — #141: #106's
  invariance families seeded one of `requirements.md`'s three requirement
  families, and not the one written from defects — 95 `GH-` entries to 49 FRs,
  and the derivation read `FR-` tags only. Which `GH-` requirements are seeded
  is a rule now: membership derived off the file, the answer declared per entry
  in a `variants` field, and three checks holding the declarations to the seed
  table and the transformation list. The first hook the rule brought into scope
  failed on its first generated spelling — `append-only-docs.sh` permits `rm`,
  `mv`, `tee`, `truncate` and a truncating redirect behind a backslash line
  continuation, filed as #156 — and review of the assistant's own commit then
  found a pass about nothing in the very section whose subject is guards that
  cannot fail. 371 more variants moved the run time by less than the suite can
  resolve, which is also why #140's recorded 94.0 s could not be compared
  against. Writing the entry then found a second permitting defect by trying to
  obey the convention: `append-only-docs-edit.sh` is inoperative in every linked
  worktree, which is where agents work, filed as #159. Worked unattended; it has
  not had Bertan's review.
  **Named for the session rather than numbered.** It was written as session
  5, collided on merging dev-05 with #128's entry of that name and became 7,
  then collided again when #137's entries took 7. `db06477`'s convention
  names it for the writing session instead. It was still a draft under ADR
  0003 when renamed, so its heading was corrected with the file name; every
  count inside it is the one that stood at its first commit — 31 registry
  rows, against 41 after the second merge.

- [2026-09-18 · session 1](devlog_2026-09-18_session-1.md) — the follow-up review
  of #153: `[[:space:]=]*` closes the separator, not the field. Quoting inside a
  field name or value (`-f ba"se"=main`, `-f state=clo"sed"`) is still permitted,
  here and on `dev-05`. It is filed as #163, to land after #130, and the claim is
  narrowed. `--input` on a retarget is added to #138. No verdict changed.

- [2026-09-18 · dev-issue-109](devlog_2026-09-18_dev-issue-109.md) — #109's
  cross-hook checks: 41 permitted spellings run through all seven Bash hooks,
  and all are permitted. Reading the messages for spellings found #164: a push
  refusal that names a push another hook refuses. Every refusal arm of the two
  boundary hooks is read to the end of its sentence, and the whole registration
  is pinned. A 200-line heredoc takes 12–57 ms; the same lines as live commands
  take up to 3.1 s, which is #127.

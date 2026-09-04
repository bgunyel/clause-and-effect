# 2026-08-23 · session 1

**Repositories worked in:** `clause-and-effect` (`dev-04`) — four commits,
`c017e9c..274a48d`, pushed, no PR opened. `ai-common` (`main`) — one commit via
[#31](https://github.com/bgunyel/ai-common/pull/31), merged as `0f0bad2`, branch
deleted locally and remotely.
**State at close:** suite **319 passed / 5 xfailed**, up from 304 at the
session's start. Tree clean, everything pushed.

**Theme:** the session made a judge run **auditable** — what it cost and what it
produced are now both recorded — and it added the nine panelists the panel will
need. Two things outrank the code. **The cost mechanism was Bertan's**, handed
over as a working snippet rather than a question. And **two more stability
samples came back 0 of 6**, which puts four samples of the same prompt and the
same model at 4/6, 3/6, 0/6, 0/6 — a result about the instrument that invalidates
the way the previous session's numbers were being read.

Nothing was built for the panel itself. That is next session, deliberately.

---

## What a judge call costs is now a number, and the mechanism was Bertan's

Bertan supplied it directly, as code:

```python
output = llm.invoke("Give me information about Ankara.")
output.response_metadata['cost']
```

with three conditions attached: use `.get` because not every provider sends the
field, OpenRouter does send it so there is no risk today, and `ai-common` has a
fallback for providers that do not — **not to be used for now**.

**The obstacle was that the judge stages had no message to read it off.**
`build_judge_llm` returned `llm.with_structured_output(schema).with_retry(...)`,
which yields the parsed pydantic object alone; the `AIMessage` is discarded
inside the chain and `response_metadata` goes with it. Bertan's snippet works
because `main_dev.py` calls plain `invoke`. So the change could not live in a
probe script — it had to be `llm.py` plus the unwrap at all five stage call
sites.

**One live call was spent verifying the design before fifteen files were
rewritten.** A three-line schema through `with_structured_output(...,
include_raw=True).with_retry(stop_after_attempt=3)` returned:

```
keys: ['raw', 'parsed', 'parsing_error']
raw type: AIMessage
metadata keys: ['cost', 'cost_details', 'created', 'finish_reason', 'id',
                'logprobs', 'model_name', 'model_provider', 'object']
cost: 3.235e-05
usage: {'input_tokens': 287, 'output_tokens': 180, 'total_tokens': 467,
        'output_token_details': {'reasoning': 153}}
```

That settled three things at once: `include_raw` survives `.with_retry`, the
dict shape is exactly as documented, and OpenRouter puts `cost` on a structured
call and not only on a plain one.

## `include_raw` separates two failures that had been one

The 2026-08-22 guard treated a `None` from `with_structured_output` as *the*
transport failure. With `include_raw=True` there are two distinguishable events,
and they call for different repairs:

| what happened | shape | repair |
|---|---|---|
| the chain yielded nothing | payload is `None` | transport |
| the model answered, the answer would not coerce | payload with `parsed: None` and a populated `parsing_error` | prompt |

`require_response` now names which one occurred, quotes `parsing_error`, and
carries up to 300 characters of what the model actually said, whitespace
collapsed. Before, a refusal and an empty response produced the same bare
message.

**What is still not retried, and was not before either.** `include_raw=True`
*catches* a coercion failure and reports it in the payload rather than raising,
so `.with_retry(stop_after_attempt=3)` never sees one. That was equally true
under the old contract, where the same failure arrived as `None` — a returned
value, not an exception. The retry covers transient API errors and nothing else.
This is recorded in the docstring rather than left to be rediscovered.

## Cost is `float | None`, and `None` is not `0.0`

The distinction is carried in the type rather than flattened at the first
opportunity, because the two are opposite facts:

- **`0.0`** — no call was made. Stage C skips the model when there are no core
  claims or when stage B produced no answer text. The price is known and it is
  nothing.
- **`None`** — a call happened and came back unpriced. That is money spent that
  nobody can account for.

Summing them together would under-report spend and never say so. `sum_costs`
therefore returns `(total, unpriced_count)` rather than a bare float, so a caller
cannot print a partial total as though it were complete. Both multi-call sites —
`stage_a_twocall.decompose` and `judge.probe_case` — go `None` if **any** leg is
unpriced rather than reporting the priced half. For the two-call variant that
matters specifically: it is twice the calls of the combined stage, which is the
trade it exists to be measured on, so its price has to be either right or absent.

OpenRouter reports `cost` on every response, so `None` should not occur against
the current configuration. It is modelled anyway because **the panel is the
reason cost is being tracked, and a panel is several providers by definition.**

New shapes, all in `src/eval/sufficiency/llm.py`:

| name | what it is |
|---|---|
| `StructuredPayload` | TypedDict for what `include_raw=True` returns |
| `StageResponse(value, cost)` | frozen dataclass every stage now returns |
| `sum_costs(costs)` | `(total, unpriced_count)` |
| `_cost_of(raw)` | `response_metadata.get('cost')` |
| `_excerpt(raw)` | ≤300 chars of `content`, for the error message |

`scripts/probe_spend.py` holds the one phrasing of a spend line. The arithmetic
stays in `llm.py` and the wording lives in `scripts/`, which is the split the
rest of the codebase keeps: library code returns numbers, and how a number is put
in front of a person is the script's business. Six decimal places, because a
single A2 call costs on the order of $0.00003 and rounding to cents would report
every probe run in this repository as free.

## Every stability sample is now a record under `docs/eval-reports/`

Bertan asked for `probe_a2_stability.py` to write its results to a file. The
reason it matters is in the previous session's log: the first sample of
2026-08-22 was piped through `tail -25`, its per-case coverage diffs were
discarded, and a second sample had to be run — which was not the same sample.

Five decisions, each with a reason:

- **The file and the terminal are the same text.** A small collector prints each
  line as it is produced and keeps it. Nothing buffers until the end, so a long
  run stays watchable, and the record cannot drift from what the operator read
  because there is no second formatting path for it to drift through.
- **Markdown that is also plain text.** Tables and headings survive a terminal
  and drop straight into `eval-reports/` beside the hand-written report there.
- **Claim text goes in fenced blocks, not table cells.** A claim containing a
  pipe would silently corrupt a row.
- **The filename carries the time as well as the date** —
  `2026-08-23-a2-stability-070340.md`. Two samples in one day is the observed
  case, not the exceptional one; it happened twice again today.
- **An existing path raises rather than being overwritten.** `eval-reports/` is
  an append-only record (`docs/design/README.md`), and a second sample landing on
  the first destroys the only thing the pair is good for. The write happens after
  everything is printed, so a collision costs the file and not the data.

The provenance header is written **before the first call**, not after the last:
timestamp, commit, whether the tree was dirty and which paths made it so
(reusing `git_state` from `chunk_store.py` — 0.19s to import, no heavy
dependencies), model, provider, temperature, call count, and the paths of the
stage, script and case modules. Model and provider are read off the params
actually passed to the stage rather than off a constant, because the 2026-08-22
near-miss was a probe reading one config role while another had been changed.

Two smaller things the format forced into the open. A run with no core claims now
prints `(no core claims)` rather than an empty fence — which is exactly what a
degenerate run looks like, so it should not read as a rendering bug. And the
spend line for a run that lost calls is labelled **a floor**: a lost call is
missing from the total and may still have been billed, since the exception means
no response came back to read a price off, not that the provider forgave the
attempt.

## Four samples of the same prompt and model: 4/6, 3/6, 0/6, 0/6

Two 30-call samples were run today, at 07:03:40 and 08:00:50 UTC. **Both report
0 of 6 cases differing in core content**, and they agree with each other case by
case, including on claim counts:

| case | 2026-08-22 s1 | 2026-08-22 s2 | 07:03 today | 08:00 today | core claims today |
|---|---|---|---|---|---|
| `art7_case3` | stable | stable | stable | stable | 1 on all 10 runs |
| `art7_case4` | stable | **unstable** | stable | stable | 1 on all 10 runs |
| `art8_case1` | **unstable** | stable | stable | stable | 1 on all 10 runs |
| `art33_case1` | **unstable** | **unstable** | stable | stable | **2** on all 10 runs |
| `art15_case1` | **unstable** | **unstable** | stable | stable | **10** on all 10 runs |
| `art41_case3` | **unstable** | stable | stable | stable | 1 on all 10 runs |
| | **4 of 6** | **3 of 6** | **0 of 6** | **0 of 6** | |

**The configuration is comparable and was checked rather than assumed.**
`sufficiency_judge` is byte-identical to the `writer_model` entry the 2026-08-22
samples read — same model, provider, `temperature: 0`, `reasoning_effort: high`,
`top_p: 0.95` — and `stage_a2.py` is unmodified between the four samples. Same
prompt, same model, four samples, four different rates.

Three specifics worth carrying:

- **No degenerate claims in 60 calls.** The `""` and the `"..."` that accounted
  for two of the three failures on 2026-08-22 did not recur. That is **not**
  evidence the guard is unnecessary; it is evidence the failure is rare enough
  that one sample can miss it entirely, which is the same property that makes the
  rates unreliable.
- **`art33_case1` split identically on all ten runs** — two core claims, the
  *"without undue delay"* / *"within 72 hours"* split that §4.6 records as one.
  Under the granularity reframe that is not a defect; it is the case reading
  consistently at a finer grain than the baseline table.
- **`art15_case1` returned ten claims on all ten runs.** The 13-claim over-split
  and the 1-claim collapse both absent.

**The operative conclusion is about sample size, not about the prompt.** At N=5
per case the between-sample variance swamps whatever signal is there. Backlog
item 2 — re-running the combined `stage_a.py` under the coverage metric — is a
comparison against these numbers, and against four samples that disagree this
much it would produce a verdict with no content. More runs per case are needed
before that comparison means anything.

## A shared `model_args` dict would have been rewritten by the Gemini panelist

Bertan added a `llm_names` dict to `get_llm_config` — role to list of
`ModelNames` — and asked for the config to be produced from it in place, rather
than a nine-line dict repeated per model. That is now a dict comprehension over
roles.

**One line of it is load-bearing rather than defensive: `'model_args':
dict(model_args)`.** `ai_common.get_llm` *mutates* the dict it is handed for
Google models — `llm.py` forces `temperature` to 1.0 on `gemini-3*` and pops
`reasoning` into `thinking_level`. With one shared dict, building the Gemini
panelist would rewrite the sampling of every other panelist in the same config,
silently, at the moment the panel first runs. `GEMINI_3_7_FLASH` is in the list,
so this was live rather than hypothetical. Pinned by an assertion in the
verification run: mutating entry 0's args leaves entry 1 untouched.

The rest of the generated config is deliberately uniform: every panelist gets the
same provider, key and sampling settings, so that a disagreement between two of
them is a disagreement **about the case** rather than about the sampling.

**No alias validation happens in that module, and the reason is a measurement.**
Checking that a model has an OpenRouter alias means `get_model_name_alias`, which
lives in `ai_common.llm` — the module `src/llm_config.py` exists to keep out of
the import graph. Measured today in one process:

| import | time | modules after | torch |
|---|---|---|---|
| `ai_common.enums` | **0.243s** | 195 | no |
| then `ai_common.llm` | **+6.583s** | 3,248 | **no** |

**The torch column corrects a claim this repository has been repeating.**
`llm_config.py`'s own docstring attributes the cost to *langchain_core imports
transformers, transformers imports torch*. Today `torch` is **not** in
`sys.modules` after importing `ai_common.llm`, and the 6.58s is the six langchain
provider SDKs and their dependencies. The cost is real and the number is
unchanged; the mechanism named in the docstring is no longer the mechanism. Not
corrected in place — the docstring was left as written and the measurement
recorded in the new comment beside it.

A model with no OpenRouter alias therefore still fails at `get_llm` with
`KeyError: <LlmServers.OPENROUTER>`. The `GPT_OSS_120B` history was kept in the
comment because it is now the only thing guarding the list.

## `ai-common`: eight OpenRouter models, PR #31 merged

Bertan gave eight `provider/model-id` strings and a rule: the bare id becomes the
`ModelNames` value, the full slug becomes the OpenRouter alias, and anything
already present is skipped. None of the eight were present.

| enum member | value | OpenRouter alias |
|---|---|---|
| `GEMINI_3_6_FLASH` | `gemini-3.6-flash` | `google/gemini-3.6-flash` |
| `GEMINI_3_7_FLASH` | `gemini-3.7-flash` | `google/gemini-3.7-flash` |
| `GLM_5_3` | `glm-5.3` | `z-ai/glm-5.3` |
| `GROK_4_6` | `grok-4.6` | `x-ai/grok-4.6` |
| `KIMI_K3` | `kimi-k3` | `moonshotai/kimi-k3` |
| `MINIMAX_M_3` | `minimax-m3` | `minimax/minimax-m3` |
| `QWEN_3_8_2_4T_A95B` | `qwen3.8-2.4t-a95b` | `qwen/qwen3.8-2.4t-a95b` |
| `QWEN_3_8_MAX` | `qwen3.8-max` | `qwen/qwen3.8-max` |

Two naming calls, both the assistant's and both flagged at the time. **`KIMI_K3`
rather than `KIMI_K_3`**: the file carries both shapes, and the underscore in
`KIMI_K_2_5` exists only because `k2.5` has a dot. **`QWEN_3_8_2_4T_A95B`** is
unwieldy but follows `QWEN_3_8_27B`, where the dots of `qwen3.8-27b` already
became underscores. `GROK_4_6` opens a new vendor block between the GPT and KIMI
groups.

Verified before the commit: **33 members, 33 distinct values, 33 distinct names**
— a duplicate value does not error, `Enum` aliases it onto the first member, so a
copy-paste slip would look like a new model and silently be an old one. Each of
the eight resolves through `get_model_name_alias` on `OPENROUTER` to the alias in
the table, and each raises `KeyError` on `GROQ`, `OLLAMA` and `GOOGLE`. Suite
green at 146.

`uv.lock` in `ai-common` was excluded from the commit for the second session
running: it was dirty before the work started — a lockfile format bump plus
dependency movement — and belongs in its own change. It is still dirty.

Bertan merged the PR. The branch was deleted locally and remotely, and the pin in
`clause-and-effect` was re-resolved with `uv lock --upgrade-package ai-common`:
`05aed76` → `0f0bad2`, **a one-line lock diff**, no dependency movement.

## The config is generated from a list, and it broke the golden-set generator

Bertan renamed the `orchestrator_model` role to `sufficiency_judge` in the
working tree before the session started, and the probe scripts were repointed at
it. **`src/scripts/gdpr_test_data_generation.py:150` still reads
`llm_config['orchestrator_model']`, which no longer exists, and now raises
`KeyError`.**

Found at commit time, by grepping `HEAD` for consumers of the removed key —
which should have been done when the config was rewritten, not three steps later.
It was **committed broken and recorded as such in `28dc9a4`'s message rather
than repaired**, because which role the golden-set generator reads is a decision
about provenance and not a rename. `writer_model` now holds exactly the model
`orchestrator_model` used to hold (`DEEPSEEK_V_4_FLASH_0731`), which makes it the
least-surprising repair, but the choice is Bertan's.

Two other consequences of the same rename, both benign: `writer_model` moved from
`GPT_5_MINI` on OPENAI to `DEEPSEEK_V_4_FLASH_0731` on OpenRouter, so
`settings.OPENAI_API_KEY` is no longer read by `get_llm_config`; and
`sufficiency_judge` went from two entries to nine. Entry `[0]` is still
`DEEPSEEK_V_4_FLASH_0731`, so every probe script keeps calling the same model it
called in this morning's samples — which is why the two stability samples are
comparable to yesterday's at all.

Bertan removed `QWEN_3_8_MAX` from `llm_names` after the first draft, leaving nine
panelists from the ten originally listed. The model remains in `ai-common`.

## A bare `uv sync` disarms the test suite

After the lock re-resolve the assistant ran `uv sync`, and the next `pytest` run
failed with `Failed to spawn: pytest`. `pytest` is in a `[dependency-groups]`
entry named `test`, not in the default set, and a bare `uv sync` **prunes groups
it was not asked for**. `uv sync --group test` restored it.

Worth knowing beyond this session: the failure is loud when you run pytest
immediately and silent otherwise. A sync followed by anything else leaves a repo
whose suite cannot run, and the standing rule here is that a gate never seen to
fail is unverified — a gate that cannot start is worse.

## Verification

- Suite **304 → 319 passed**, 5 xfailed, green before every commit and after the
  final push.
- **Fifteen tests added.** Cost-carrying is pinned **per stage** rather than once
  on the helper: five call sites can each silently drop the field, which is the
  shape of the defect the 2026-08-22 `None` guard was written for. Also pinned:
  an unpriced call yields `None`, stage C's two no-call paths yield `0.0`,
  `sum_costs` counts what it could not price, the two-call variant sums both legs
  and goes `None` if either is unpriced, and an unparseable response is quoted
  back with its `parsing_error`.
- **Four mutations, each caught by exactly the expected test and no other:**

  | mutation | failing tests |
  |---|---|
  | stage B returns `cost=0.0` | stage B's parametrization only |
  | `sum_costs` stops counting unpriced | that test + the two-call unpriced test |
  | stage C's no-call path returns `None` | the `no answer text` case only |
  | two-call returns the priced half | its unpriced test only |

  Sources restored and re-verified green after each.
- **The payload shape was verified against a live call** before any of the
  fifteen files were edited, and the cost field was read from a *structured*
  call rather than assumed from Bertan's plain-`invoke` snippet.
- **The report writer was exercised with a stubbed `tag_claims`** — no spend, no
  writes into `docs/` — covering a full run, the lost-call path, the no-core-claim
  path, and the overwrite refusal, before it was pointed at real calls.
- **Live spend measured, not estimated:** `probe_a2_examples` $0.000481 over 4
  calls; `probe_a2_stability` **$0.003229 over 30 calls**, per-case $0.000396 to
  $0.000733.
- **Import cost re-measured** after every change to the config module: 0.170s,
  285 modules, no torch.
- **`ai-common`:** 146 tests green; enum uniqueness asserted; all eight models
  resolved on OpenRouter and shown to raise on three other providers.
- All eight probe scripts and both library modules import-checked after the
  refactor, since seven of them are not covered by any test.

## Mistakes made this session

All the assistant's unless stated.

- **The config was rewritten without grepping for consumers of the key it
  removed.** `gdpr_test_data_generation.py` has been broken since that edit, and
  it was found at commit time rather than at edit time. One `git grep` would have
  surfaced it immediately, and it is the golden-set generator — the script that
  produced the 433 cases everything else is measured against.
- **A bare `uv sync` uninstalled pytest.** Caught within one command because the
  next step was the suite, but the same mistake before a different next step
  leaves the suite silently unrunnable.
- **The first report-writer dry run crashed after writing its file**, on
  `path.relative_to(_REPO_ROOT)` — an artefact of the harness redirecting the
  output directory outside the repo, but the line was fragile for no benefit and
  was replaced with the absolute path.
- **`format_spend` was imported into `probe_a2_stability.py` and never used**
  there, because that script needs the richer in-report formatting. Dead import,
  removed on review of the final file rather than when it was added.
- **Two dead names in the first draft of `llm.py`** — an unused `List` import and
  a `summarise` helper left behind by the table restructure — both removed after
  reading the generated output rather than the diff.
- **Two 30-call samples were spent today where one was planned.** The second was
  needed to verify the cost integration end to end, which is a real reason, but
  the first would have carried the spend rows had the cost work been sequenced
  before the report work rather than after.

## State handed to the next session

| | |
|---|---|
| `clause-and-effect` | `dev-04`, four commits pushed, tree clean, no PR open |
| `ai-common` | `main`, #31 merged, branch deleted, `uv.lock` still dirty |
| Suite | **319 passed / 5 xfailed** |
| Judge | stages A, B, C built; A also exists as A1+A2; every stage reports its cost; verdict derivation, panel, calibration **not built** |
| Panel roster | nine models in `sufficiency_judge`, eight of them **never called** |
| Stage A | combined `stage_a.py` untouched; two-call variant measured, not adopted |
| Reports | two A2 samples committed under `docs/eval-reports/` |
| Gate | `make upgrade-safe` **not run** on this branch; now covers a dependency change as well |

## Open items — start here next session

| # | open item | state |
|---|---|---|
| 1 | **The panel (§8) and calibration (§9)** — Bertan's stated next session | roster exists, nothing built |
| 2 | **Call each of the eight new panelists once.** They are name resolution only; nothing has confirmed OpenRouter serves those ids, and a bad id inside a panel run fails after the expensive part | ~8 cheap calls |
| 3 | **`gdpr_test_data_generation.py:150` raises `KeyError: 'orchestrator_model'`** — which role the golden-set generator reads is Bertan's call | broken now, one line |
| 4 | **Reject degenerate claims in `stage_a2.py`** — `""` and `"..."` still reach the caller; absent from 60 calls today, which lowers its urgency and not its correctness | one guard |
| 5 | **N=5 is too small to compare samples.** Four samples of one prompt read 4/6, 3/6, 0/6, 0/6 — decide the sample size before item 6 spends calls on a comparison | measurement design |
| 6 | **Re-run the combined `stage_a.py` under the coverage metric** — still the only thing that settles whether the split helped; blocked on item 5 to mean anything | 30+ calls |
| 7 | **Build the A1↔A2 consistency check** — makes instability visible in one run instead of N | designed, not built |
| 8 | **The atomicity rule** — still unapplied, deliberately held out of the split experiment | one edit, then re-measure |
| 9 | **`art7_case4`'s third sentence: core or auxiliary** — Bertan's call; the error asymmetry argues for core | undecided; it scores the prompt |
| 10 | **A1's partial-answer behaviour is unspecified** — no rule for a question the answer half-answers | decides whether the defect is reported against quote or case |
| 11 | **Measure beyond the six** — 6 of 433 seen; `conditional` (133 cases) never touched | coverage gap |
| 12 | **Rewrite §4.6's expectations as *which rule does this case test*** | checkable against the prompt |
| 13 | **§4.6's metric is core count and should be coverage** | its stability claims may never have been measured |
| 14 | `make upgrade-safe` on `dev-04`; `ai-common`'s `uv.lock` churn as its own change | required before a PR closes |
| 15 | Wire `max_llm_retries` into `with_retry` instead of the hardcoded 3 | config field still unread |
| 16 | `judge.py` and now nine `scripts/` files print rather than log | deliberate, flagged, not fixed |
| 17 | `scripts/` and `src/scripts/` coexist with no written rule | decide or document |
| 18 | `llm_config.py`'s docstring blames torch for a cost that no longer loads torch | measured today; text not corrected |
| 19 | `art8_case5`'s `contradicted` — probable false positive, de-escalated by the error asymmetry | unresolved |
| 20 | Everything on the 2026-08-17 lists — the gate's detection side, the three GuardDog defects | untouched |
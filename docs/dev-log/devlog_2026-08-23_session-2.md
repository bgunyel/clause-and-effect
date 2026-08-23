# 2026-08-23 · session 2

**Repositories worked in:** `clause-and-effect` (`dev-04`) — one commit,
`91ffc78..6f4087c`, pushed, no PR opened. `ai-common` — untouched in git; three
waivers and three ledger entries written into the machine-wide GuardDog store,
which is not version-controlled.
**State at close:** suite **329 passed / 5 xfailed**, up from 319. Tree
**dirty** — four modified files and five untracked, none committed. Three new
eval reports under `docs/eval-reports/`.

**Theme:** the panel was stood up, and almost everything the session found was
about **the instrument rather than the judges**. Three separate defects made the
recorded numbers mean less than they appeared to: reasoning effort silently lost
after the first call, no timeout anywhere, and structured output failing for
reasons that had nothing to do with judgement. The panel does agree — 4 to 5 of
6 cases unanimous — but every run disagreed with the run before it by about as
much as the panelists disagreed with each other.

The single most consequential finding is Bertan's, and it came from reading the
OpenRouter console rather than the code: **MiniMax's "failures" were successful,
billed generations that we discarded.**

---

## `make upgrade-safe` was failing; three waivers, all reviewed against the wire

Bertan ran the gate before any development and it blocked on three packages. All
three were version bumps of packages already waived at earlier versions, and
waivers do not carry to a new version.

**The candidates were not installed**, because the committed lock held the old
versions — the limitation already recorded in memory as *`make scan` cannot
verify waivers for versions outside the committed lock*. So each wheel was
fetched from the URL in the report's `pypi_dist_path` and its **blake2b-256
digest checked against that path**, which is what makes this a review of the
bytes GuardDog scanned rather than of a plausible substitute.

| package | rules | classification |
|---|---|---|
| `google-genai==2.19.0` | steganography | rule defect |
| `docling-slim==2.121.0` | download-exec, steganography | rule defect ×2 |
| `huggingface-hub==1.28.0` | autostart, download-exec | real behaviour, accepted in context |

**The two steganography findings are the same degenerate branch this repository
has now seen six times.** The rule's condition is
`(python stego libs and $img_png and bare eval/exec) or (any of $js_* and
$img_png and $js_eval)`, and `$js_eval` is the unanchored string `"eval("`
applied to `.py` files by `path_include`. It matched inside `types.Retrieval(`
and inside PyTorch's `self.model.eval()`. Both packages have **zero** bare
`eval(`/`exec(` and zero stegano strings anywhere.

**docling's download-exec is a `curl … | sh` inside a `_log.warning`.** The
branch that fired is `$shell_curl_pipe`, which stands alone in the condition.
`tectonic.py` resolves its binary through `shutil.which` or an existing cache
path and **contains no download primitive at all**, so the
`urlretrieve + subprocess.run` branch cannot fire; the `subprocess.run(` that
now appears in the match list runs that resolved binary on a temp `.tex` file.

**huggingface-hub's two are real**, and both live in `huggingface_hub/cli/`:
`--install-completion` appends one line to `~/.bashrc`/`~/.zshrc` from a Click
eager-option callback, and `hf update` self-updates through `subprocess.call`.
`run_update` is reached only from `cli/system.py:56`; `check_cli_update` merely
*formats the command into a printed hint* and never executes it.

**Completeness was checked against `max_hits` rather than assumed.** Both
huggingface-hub rules hit their cap of 3, so a package-wide scan was run: the
hidden extras are the same updater plus inert help text in `skills.py` and
`_runtime.py`, and there is no `/etc/init.d`, `/etc/profile.d`,
`.config/autostart`, `LaunchAgents`, `rc.local` or `winreg` anywhere in the
package. The steganography rule caps at 1 and each package has exactly one
candidate file, so nothing was concealed there either.

The "accepted in context" premise is a claim about *this repository*, so it was
re-checked for 1.28.0: not a direct dependency, no `hf` usage here, and
`.cli._cli_utils` still imported only under `if TYPE_CHECKING:` with a lazy
`__getattr__`. `tests/test_waived_dependency_assumptions.py` pins both halves and
its version table was updated.

Gate now passes. `make scan` reports **BLOCKED 0, INCOMPLETE 0** while still
listing every waived finding — which is the required outcome, since a finding
that vanished would mean something was hiding them rather than waiving them.

### pydantic resolved *downwards*, and it is pinned to a single release

The adopted upgrade moved `pydantic` **2.13.4 → 2.12.5** and `pydantic-core`
2.46.4 → 2.41.5. Three caps stack:

```
langchain-openrouter 0.2.8   openrouter <1.0.0,>=0.9.2   →  best openrouter = 0.11.46
openrouter 0.11.46           pydantic   <2.13,>=2.11.2   →  ceiling
google-genai 2.19.0          pydantic   <3.0.0,>=2.12.5  →  floor
```

`2.12.5` is the **only** pydantic release in `[2.12.5, 2.13)`. The cap entered at
**`openrouter 0.11.0`** (bisected against PyPI metadata; 0.10.8, which we were
on, is the last release without it) and is still present on PyPI's current latest
**1.1.74** and on the SDK repository's `main`. We cannot reach 1.1.74 in any case
because `langchain-openrouter` caps `openrouter<1.0.0` and 0.2.8 is its newest
release.

**The window is one release wide.** If `google-genai` raises its floor by a
single patch while `openrouter` keeps `<2.13`, the graph becomes unsatisfiable
and `uv lock --upgrade` will fail or backtrack something else. The unblock would
have to come from `openrouter` dropping the cap, two levels above anything this
repository controls.

---

## The roster: eight of nine, and a defect that was not the roster's

`scripts/probe_panel_roster.py` sends one cheap structured call to every entry in
`llm_names['sufficiency_judge']`. Eight of the nine had never been sent a
request; they were name resolution only.

**Four failures are told apart, because they call for different repairs** —
construction (no OpenRouter alias), transport (the provider rejected it),
structure (it answered and would not coerce), content (it coerced and is wrong).
A bare traceback collapses all four, which is what a panel run would have given.
The probe **grades** rather than merely surviving, because a model that fills the
schema with something invented has passed every mechanical check and is useless.
The schema deliberately carries one free string and one `Literal`, since a
`Literal` is where weaker structured output breaks and stages A and C both need
one.

First run: **8 of 9 usable**, `$0.007493`. `GLM_5_3` failed with
`BadRequestResponseError: Tool choice must be auto`.

### `model_args` was emptied by `get_llm`, and only the first call had a reasoning budget

The probe snapshots `model_args` before and after construction — put there to
catch the *Gemini* mutation `llm_config.py` documents. It fired for **all nine
models**:

```
sent:  {'temperature': 0, 'reasoning_effort': 'high', 'top_p': 0.95}
after: {}
```

`ai_common.get_llm`'s OpenRouter branch does not read the dict, it **pops** it:

```python
temperature = model_args.pop('temperature', 0)
top_p       = model_args.pop('top_p', 0.95)
reasoning   = {'effort': model_args.pop('reasoning_effort', None), ...}
```

Verified against live construction from one entry:

```
call 1: sent={'temperature': 0, 'reasoning_effort': 'high', 'top_p': 0.95}
        -> temperature=0.0  top_p=0.95  reasoning={'effort': 'high', ...}
call 2: sent={}
        -> temperature=0.0  top_p=0.95  reasoning={'effort': None, ...}
```

**`temperature` and `top_p` survived by coincidence** — the pop defaults are `0`
and `0.95`, exactly the configured values. `reasoning_effort` defaults to `None`.

Every stage calls `build_judge_llm` on **every** invocation from the single entry
`get_llm_config` returns, and every probe reuses one dict. So **one call per
process got `effort: high` and all the rest got no reasoning budget at all** — and
in `judge.probe_case`, where A and B are `asyncio.gather`ed, *which* stage won it
was a race.

This is a confound in every multi-call measurement recorded before today,
including the four A2 stability samples that read 4/6, 3/6, 0/6, 0/6. It does not
explain them — within a sample runs 2..N are consistent with each other — but
those numbers were taken on an instrument where exactly one call per sample
differed from the others in reasoning effort, and which call that was depended on
scheduling.

**Fixed locally**, in `build_judge_llm`, by handing `get_llm` a copy:
`model_args=dict(model_params["model_args"])`. `llm_config.py`'s per-entry
`dict(model_args)` already prevented one panelist rewriting another's sampling; it
cannot help against a single entry eroding across repeated builds of *itself*.
Two tests, mutation-verified — reverting the one-line fix fails exactly those two.

**Not fixed in `ai-common`.** `get_llm` still mutates its argument, and the
Google, Groq and OpenAI branches have the same shape. That is a shared-library
change nobody authorised this session.

After the fix the probe reports `model_args: unchanged for every panelist`,
which is the live confirmation.

---

## GLM 5.3: diagnosed, made to work, then disqualified on latency

Worth recording in full, because the diagnosis is reusable and the outcome is
not what the diagnosis predicted.

| attempt | result |
|---|---|
| plain `invoke` | **works** — reasons, answers, reports cost |
| `with_structured_output` (default) | `BadRequestResponseError: Tool choice must be auto` |
| `method="json_schema"` | accepted, **unenforced** — model returned prose, parser raised |
| `method="json_mode"` | not implemented by `langchain_openrouter`; warns, falls back to `json_schema` |
| `with_structured_output(..., tool_choice="auto")` | `TypeError` — the wrapper already passes `tool_choice` to `bind_tools` |
| **`bind_tools([schema], tool_choice="auto")`** | **works** — 3/3 correct args, cost on the raw message |

`with_structured_output` pins `tool_choice` to the schema's own function;
OpenRouter's `z-ai/glm-5.3` rejects anything but `auto`.

**A second call path was built for it**, `TOOL_CALL_AUTO`, and the interesting
part is what it had to preserve. `bind_tools` returns an `AIMessage`, not the
`{raw, parsed, parsing_error}` dict. Rather than teach `require_response` a second
shape, `payload_from_tool_call` rebuilds the first one — so every stage, the
error reporting and the cost plumbing stay identical across both paths, and
`_cost_of` needs no branch.

**The failure this path introduces is the important one.** `tool_choice="auto"`
lets the model answer in prose instead of calling the tool, which the forced path
makes impossible. Stage A2 may legitimately return **zero claims** (§4.5: a gold
answer that does not answer its own question), so mapping silence to an empty
list would record *a case nobody judged* as *a case judged to have no core
content* — the silent direction the whole judge is arranged against. It is
reported as `parsed: None` and becomes a `JudgeResponseError`. Mutation-verified
three ways.

**Then it timed out on all six cases at 120s each.** GLM answers the roster
probe's trivial prompt in 18s and cannot finish a real A2 prompt at all. It was
the cause of a 19-minute stall (below) and was removed from the roster. The
`TOOL_CALL_AUTO` machinery and GLM's `structured_output` entry are **kept**: the
structured-output fix was real and tested, and what disqualified the model was
latency, not wiring.

---

## The panel probe, and the run that hung for 19 minutes

`scripts/probe_a2_panel.py` runs stage A2 over the six §4.6 cases on every
panelist and reports where they agree.

**Agreement is measured on core coverage**, not on claim counts or text —
`core_coverage` is imported from `probe_a2_stability` rather than reimplemented,
because two definitions of agreement would drift and these numbers exist to be
comparable to that sample's. Two views are reported, because one lies in a
predictable direction: the **dominant bloc** is exact-match and therefore brittle
(eight models differing by one stopword each give eight blocs of one), while the
**per-word vote** shows *where* the panel splits. Stopwords are deliberately not
filtered — a stoplist inside an eval instrument is a silent editorial judgement
about which words count as content.

### No timeout existed anywhere, and nothing else bounded the run

The 9-panelist run sat for **19 minutes having used 4 seconds of CPU**, with
eight sockets open and `rchar` not advancing by a single byte, where the
8-panelist run before it had finished in **3m56s**.

Three things combined:

- `get_llm`'s OpenRouter branch builds `ChatOpenRouter` with **no `timeout`**.
- `.with_retry(stop_after_attempt=3)` retries *exceptions*; a request that never
  returns never raises one.
- Every panelist on a case is `gather`ed, so one hung request stalls the case
  with no upper bound.

**`CALL_TIMEOUT_SECONDS = 120`** via `asyncio.wait_for` per cell, roughly double
the slowest call previously recorded. A timeout now produces a `TIMEOUT` cell the
report displays like any other failure — named separately from a wrong answer,
because "never answered" and "answered badly" are different findings about a
panelist.

**The stall was also undiagnosable from outside**, because progress `print()`
went to a block-buffered stdout and the file stayed at 0 bytes. Now
`flush=True`, and each line names the slowest panelist — which is who the case
waited on. This is the property `probe_a2_stability`'s `Report` class was built
to preserve, and the progress line sat outside it.

Bertan's arithmetic on the previous report — summing the `mean sec` column and
multiplying by 6 — assumed serial execution and gave 12 minutes. Panelists run
concurrently within a case and only the cases are sequential, so the expectation
is `sum over cases of max(panelist)`; the 3m56s run confirms it.

### A cost-accounting defect found and fixed before the record was written

The first panel report counted **failed** calls as *unpriced*. A failed cell also
carries `cost=None`, and folding it into `sum_costs` conflates "the call never
returned" with "the call returned without a price" — the exact distinction
`StageResponse` exists to keep. Fixed to `[c.cost for c in cells if c.ok]` at all
three sites, and the defective report was deleted rather than committed.

---

## The finding that outranks the code: successful, billed generations discarded as failures

Bertan matched `response_metadata['id']` against the OpenRouter console and
observed that **MiniMax showed no failures there** — every run successful.

Reproduced directly on a case the panel had recorded as failed:

```
finish_reason : stop
id            : gen-1787507263-0C3wACHSRPPVlcSlGbWF
cost          : 0.0011607
tool_calls    : []
parsing_error : None
```

and the content, verbatim:

```
claims:
  CORE - "No. The withdrawal of consent does not affect the lawfulness of processing that was based on consent before the withdrawal."
    reason: It is what the shortest sufficient answer says. The polarity marker stays attached to the proposition it qualifies instead of being split off as a claim of its own.
  AUXILIARY - "The data processed while consent was still valid remains lawfully processed."
    reason: It restates the same point as a consequence of the first claim. The shortest sufficient answer does not need to say it; it follows from the rule already stated.
```

**MiniMax got `art7_case4` exactly right.** One CORE with the polarity marker
attached, one AUXILIARY for the third sentence — §4.6's expected output. It
simply wrote it as prose in the schema's shape instead of calling the tool. Its
`2/6` was an artifact of how we called it, not a judgement failure. The console
is right: from OpenRouter's side these are ordinary completions.

### Two defects this exposes, both still open

**1. `require_response` discards a cost it already holds.** On the
`parsed is None` path it raises and drops the raw message, which carries
`cost: 0.0011607`. So every report's *"failed calls are unpriced and may still
have been billed"* is wrong in the timid direction — they **were** billed, and
the amount is knowable rather than an estimate. Across three panel runs that is
11 + 6 + 3 = 20 calls whose real cost is missing from the totals. For planning a
433-case × 3-stage × 8-member panel, spend that is systematically understated by
an unknown amount is not a usable number.

**2. The generation id is never recorded, on success or failure.** It is the join
key to the OpenRouter console — the one field that makes a run auditable against
the provider — and it is dropped on both paths. Bertan's diagnosis was only
possible by matching ids by hand.

**Proposed shape**, not implemented: `JudgeResponseError` carries `cost` and
`generation_id`, set by `require_response` from the raw message it already reads;
`StageResponse` gains `generation_id` beside `cost` (ten construction sites, all
mechanical); the panel probe records ids per cell and reports failed-call spend as
a real number. That turns "a floor" into an exact total and makes every call in
every report checkable against the console.

**A third field belongs in the same change:** `usage_metadata`'s
`output_token_details.reasoning`. See the confound below — it is currently
suspected and unquantified precisely because nothing records it.

---

## Function calling, JSON schema, and provider routing

The three panel runs, all over the same six cases:

| | 9 panelists, function calling | 8 panelists, function calling | 8 panelists, json_schema |
|---|---|---|---|
| report | `…-162138.md` | `…-165801.md` | `…-181319.md` |
| completed | 43/54 | 42/48 | **45/48** |
| structured-output failures | 5 | 6 | **0** |
| timeouts | 6 (all GLM) | 0 | 3 (all DeepSeek Flash) |
| unanimous cases | 5/6 | 4/6 | 4/6 |
| spend | $0.187719 | $0.221742 | $0.220471 |

### The three ways a model avoids the tool channel

All observed on real A2 prompts:

- **prose in the schema's shape** — MiniMax, Kimi (`claims:\n CORE - "…"`)
- **the tool call emitted as text** — Grok (a fenced ` ```json ` block containing
  `{"name": "_A2Claims", "arguments": {…}}`)
- **a mangled tool name** — Kimi (`Unknown tool type: 'functions._A2Claims'`)

For MiniMax the cause is documented by OpenRouter: **its endpoint does not accept
tools at all**, so function calling is unavailable there. Kimi K3 and Grok 4.6
both *do* accept tools and `tool_choice` per the same documentation — yet failed
anyway, and inconsistently.

### `json_schema` fixed the whole class, and broke the best panelist

`method="json_schema"` binds a real
`response_format={"type": "json_schema", …}` and keeps `include_raw`, so cost and
generation id survive. Every structured-output failure disappeared: MiniMax
**2/6 → 6/6**, Kimi **4/6 → 6/6**, Grok **6/6**. MiniMax and Grok also moved to
**6/6 in the dominant bloc**. On `art15_case1` MiniMax returned exactly ten core
claims — §4.6's expected output.

**But DeepSeek V4 Flash went 6/6 → 3/6**, all three failures timeouts at 120s,
mean latency **6.5s → 63.1s**. The cheapest and fastest panelist became the only
one failing.

**Neither channel works for every model**, so each is now assigned its own in
`llm_config.structured_output`:

| model | channel | evidence |
|---|---|---|
| DeepSeek V4 Flash | `function_calling` | 3 timeouts @63s under json_schema; 6/6 @~7s on tools |
| DeepSeek V4 Pro | `function_calling` | works either way; faster on tools (25s vs 41s) |
| Gemini 3.7 Flash | `function_calling` | works either way |
| Qwen 3.8-27B | `function_calling` | works either way |
| Qwen 3.8-2.4T | `function_calling` | works either way |
| Grok 4.6 | `json_schema` | 4/6 then 6/6 on tools; 6/6 on json_schema |
| Kimi K3 | `json_schema` | 3/6 and 4/6 on tools; 6/6 on json_schema |
| MiniMax M3 | `json_schema` | endpoint accepts no tools at all |

**There is no default.** `structured_output[model]` raises `KeyError` for an
unlisted model, and `build_judge_llm` refuses an unrecognised channel **before
constructing anything**. Adding a panelist now requires the measurement that says
how to call it, rather than inheriting a guess. Mutation-verified.

**Two of the eight assignments rest on a mechanism; the rest rest on counts of
one run per channel.** Grok read 4/6 then 6/6 on *identical* function-calling
runs, so those rows are weaker evidence than the table looks.

### `require_parameters: true`

OpenRouter routes one model id to whichever upstream provider it picks, and
**support for the parameters we send varies between them for the same model**.
Without a routing constraint, a provider that does not implement
`response_format` may be chosen and simply ignore it: the call succeeds, is
billed, and comes back as prose. That is a candidate explanation for the
roster's unexplained intermittency — Grok answering 4/6 and then 6/6 with no
change on our side.

`'provider': {'require_parameters': True}` is now in `model_args`. It reaches the
request through `model_kwargs`: `get_llm` pops `temperature`, `top_p` and
`reasoning_effort` and hands the remainder to `ChatOpenRouter(model_kwargs=…)`,
whose `_default_params` spreads them into the body. `provider` is the body's own
field name — the constructor spells it `openrouter_provider`, which `get_llm`
does not pass, so nothing overwrites it. No `ai-common` change was needed.

**It has never been exercised.** No run in this session carried it, and the
indirection through `model_kwargs` has not been verified to reach the wire. If it
silently does not arrive, the next run will look like *"require_parameters
changed nothing"* when in fact it was never sent. **Verify it on one cheap call
before reading anything into a comparison.**

### The confound this buys, and it is not hypothetical

`llm_config`'s premise is that every panelist runs identical settings, so a
disagreement between two of them is a disagreement **about the case**. A
per-model channel weakens exactly that.

The specific risk: **MiniMax reported `output_token_details: {'reasoning': 0}`
under `json_schema` while producing `reasoning_content` on the tool path.** If
`response_format` suppresses reasoning for some models, then three panelists are
judging without the budget the other five get, inside the comparison the panel
exists to make. It is accepted for now because the alternative is worse — a
uniform channel means some panelist is scored on calls it never had a fair chance
to answer — but it is **unquantified, and it should not stay that way.**

---

## What the panel actually says about agreement

Setting the instrument aside: **there is a dominant majority.**

Across the three runs, four to five of six cases had *every answering panelist
marking identical core coverage*, with zero contested words. `art8_case1` —
which §4.6 records as flipping the verdict across four identical runs of one
model — came back unanimous across seven and eight different models.

The consistent exception is **`art15_case1`, the ten-item enumeration**: 4, 4 and
3 distinct coverage sets, dominant bloc 3/7, 2/6 and 4/7, with 5–6 contested
words. That is also the case with the most room to differ on granularity, so it
needs reading rather than counting.

**Cost buys nothing here.** In the function-calling run DeepSeek V4 Flash agreed
with the majority as often as Grok (5/6) at **$0.000578 against $0.069334** —
120× cheaper. Qwen 3.8-2.4T was the only 6/6, at $0.057700.

**But the runs disagree with each other by about as much as the panelists do.**
Between the two 8-panelist runs, `art33_case1` went 6/7 → 4/8 and `art15_case1`
2/6 → 4/7, and individual panelists' bloc counts moved by one in both directions.
One run per panelist **cannot** separate "this model judges differently" from
"this model is unstable" — the same wall the four A2 stability samples hit at
4/6, 3/6, 0/6, 0/6. Everything in this section is one sample.

---

## Verification

- Suite **319 → 329 passed**, 5 xfailed. Green before and after every change.
- **Ten tests added.** Repeated builds all receive the configured sampling; the
  caller's config survives a build; a tool call becomes the parsed schema; the
  raw message survives so the call can still be priced; **no tool call is a
  transport failure and not an empty result**; an empty claim list from a real
  tool call is kept as a result; bad arguments are reported not raised; only the
  configured model takes the auto path; every path keeps `include_raw`; a model
  with no declared channel is refused.
- **Five mutations, each caught by exactly the expected test and no other:**

  | mutation | failing test |
  |---|---|
  | `dict(model_args)` reverted to the shared dict | the two build tests only |
  | `if not calls:` → `if False:` | the missing-tool-call test only |
  | silence mapped to an empty result | the missing-tool-call test only |
  | `tool_choice="auto"` → `"required"` | the channel-selection test only |
  | the unknown-channel refusal removed | the refusal test only |

  Sources restored and re-verified green after each.
- **The fake `ai_common` is installed into `sys.modules` with its `enums`
  submodule**, so none of these tests pay the 6.58s real import.
- Import cost re-measured after every config change: **0.139s, 285 modules, no
  torch** — unchanged.
- The `model_args` fix confirmed **live**: the roster probe's mutation section,
  which had fired for all nine panelists, now prints `unchanged for every
  panelist`.
- GLM's `TOOL_CALL_AUTO` path verified live before it was wired: 3/3 correct
  arguments, cost present on the raw message.
- **Live spend this session:** roster probes $0.007493 + $0.006563 + $0.011074;
  panel runs $0.187719 + $0.221742 + $0.220471; diagnostics ≈ $0.01. Roughly
  **$0.67**, and the panel totals are floors for the reason recorded above.

## Mistakes made this session

All the assistant's unless stated.

- **The first panel report counted failed calls as unpriced**, conflating the two
  facts `StageResponse` exists to separate. Caught on reading the output rather
  than when the code was written; the report was deleted and the run repeated.
- **No timeout was considered until a run hung for 19 minutes.** The panel
  multiplies every call by its member count, and an unbounded wait was
  foreseeable from `get_llm` alone.
- **Progress output was written outside the `Report` mechanism** and therefore
  block-buffered, which is what made the hang undiagnosable. The neighbouring
  script's docstring explains precisely this and it was not applied.
- **The structured-output failures were read as panelist quality for three
  runs.** The report even quoted MiniMax's correct answer back in its error
  message, and it was described as a failure. Bertan found it by reading the
  provider's console — the one place that could not agree.
- **The channel check was initially placed after `get_llm`**, contradicting its
  own docstring's claim to fail before anything is built. Caught by the test that
  asserted it.
- **Two 200-call-equivalent panel runs were spent on configurations superseded
  within the hour**, because the channel question was settled one model at a time
  instead of by one probe across the roster.

---

## State handed to the next session

| | |
|---|---|
| `clause-and-effect` | `dev-04`, one commit pushed (`6f4087c`), **tree dirty and nothing else committed** |
| `ai-common` | untouched in git; three waivers + three ledger entries in the machine-wide store |
| Suite | **329 passed / 5 xfailed** |
| Gate | `make upgrade-safe` **passes**; `make scan` BLOCKED 0, INCOMPLETE 0 |
| Panel roster | **8 panelists**, all called at least once, per-model channel assigned |
| Panel | probe built and run three times; **verdict derivation, aggregation and calibration still not built** |
| Reports | three A2 panel samples under `docs/eval-reports/` |

**Uncommitted, and it is the whole session's work:**

```
 M src/eval/sufficiency/llm.py          model_args copy, JSON_SCHEMA + TOOL_CALL_AUTO
                                        paths, payload_from_tool_call, channel refusal
 M src/llm_config.py                    per-model structured_output table,
                                        require_parameters, GLM commented out
 M tests/test_sufficiency_stages.py     ten tests
 M src/main_dev.py                      BERTAN'S — sufficiency_judge[0] → [5]
?? scripts/probe_panel_roster.py
?? scripts/probe_a2_panel.py
?? docs/eval-reports/2026-08-23-a2-panel-{162138,165801,181319}.md
```

`src/main_dev.py` is Bertan's edit, not the assistant's, and was left alone.

## Open items — start here next session

| # | open item | state |
|---|---:|---|
| 1 | **Commit the tree.** Nothing above is committed; a lost working directory loses the entire session | one or more commits |
| 2 | **Verify `require_parameters` reaches the wire** before any comparison is read. It goes through `model_kwargs` indirection and has never been exercised | one cheap call |
| 3 | **Carry `cost` and `generation_id` through failures.** `require_response` discards a price the provider charged and an id that is the only join to the console. 20 calls across three reports are unaccounted | designed, not built |
| 4 | **Record `output_token_details.reasoning` per call**, and settle whether `json_schema` suppresses reasoning. Until then the mixed-channel panel has an unquantified confound in its core comparison | measurement |
| 5 | **Re-measure A2 stability on the corrected instrument.** The four samples (4/6, 3/6, 0/6, 0/6) predate the `reasoning_effort` fix | ~30 calls |
| 6 | **Repeats per panelist.** One run each cannot separate panelist disagreement from panelist instability, and the between-run variance is currently as large as the between-panelist variance | design decision, then calls |
| 7 | **Re-derive design §8.2.** Its clean/unclean analysis is against the old Ollama roster and names none of these eight. Families now: DeepSeek ×2, Google, xAI, Moonshot, Minimax, Qwen ×2 — three overlap the original proposers | doc work, blocks panel composition |
| 8 | **Verdict derivation (§7), aggregation into `CaseJudgement`, calibration (§9)** — the actual panel. Nothing built | the main task |
| 9 | **`art15_case1` is the one case the panel splits on.** Read the four coverage variants rather than counting them | analysis |
| 10 | **`gdpr_test_data_generation.py:150` still raises `KeyError: 'orchestrator_model'`** — carried from session 1, Bertan's call | broken, one line |
| 11 | **`ai_common.get_llm` mutates its argument** on every provider branch. Fixed locally for the judge only; every other caller in every project still has it | `ai-common` PR |
| 12 | **`ChatOpenRouter` is built with no timeout.** The probe bounds itself; the real runner and every other caller do not | `ai-common` PR |
| 13 | **GLM 5.3 is disqualified on latency, not wiring.** `TOOL_CALL_AUTO` works and is kept; re-test if the endpoint gets faster | parked |
| 14 | **Reject degenerate claims in `stage_a2.py`** — `""` and `"..."` still reach the caller | carried from session 1 |
| 15 | **Measure beyond the six** — 6 of 433 seen; `conditional` (133 cases) never touched | carried |
| 16 | **`art7_case4`'s third sentence: core or auxiliary** — Bertan's call, and MiniMax independently produced the assistant's reading | carried, undecided |
| 17 | `judge.py` and now **eleven** `scripts/` files print rather than log | carried, flagged |
| 18 | Everything else on session 1's list — the A1↔A2 consistency check, the atomicity rule, §4.6's metric, `art8_case5`, `main_dev.py`'s role index | carried |
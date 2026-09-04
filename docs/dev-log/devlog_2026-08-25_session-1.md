# 2026-08-25 · session 1

**Repositories worked in:** `clause-and-effect` (`dev-04`) — eleven commits,
`06bf9c5..`, pushed, no PR opened. `ai-common` — untouched.
**State at close:** suite **354 passed / 5 xfailed**, up from 329. Tree
**clean**, everything committed. Three new eval reports under
`docs/eval-reports/`.

**Theme:** open items 2 through 5, in order, and the session is mostly about
**making the instrument say what it knows**. Three separate facts were being
held and discarded at the moment of failure — the price, the generation id, the
reasoning budget — and each one had already cost a wrong conclusion. Once they
were recorded, two beliefs about the panel turned out to be wrong.

Bertan's contribution is the one that changed the most code: reading
`probe_a2_stability.py` and pointing at `[0]`.

---

## Item 2 — `require_parameters` reaches the wire, and the check can fail

`'provider': {'require_parameters': True}` had never been exercised, and it does
not reach the request directly: config → `get_llm` →
`ChatOpenRouter(model_kwargs=…)` → `_default_params` → body, through whatever is
left after `get_llm` pops `temperature`, `top_p` and `reasoning_effort`. Every
step of that was inference from reading code.

`scripts/probe_wire_params.py` wraps `httpx.AsyncClient.send` for the run and
keeps the JSON body of every `/chat/completions` request — the last point the
request is ours. Reading `_default_params`, or the model object, would
re-derive the answer from the layer whose behaviour is in question. The call
goes through `build_judge_llm` because the question is what *the judge* sends.

**8 of 8 panelists, both channels**, $0.008812. The body carries
`"provider": {"require_parameters": true}` beside `temperature: 0.0`,
`top_p: 0.95` and `reasoning: {"effort": "high"}` — which also confirms the
`model_args` copy fix live: every panelist got `effort: high`, not just the
first.

**The control matters as much as the result.** "8 of 8" is worth nothing from a
check that cannot fail, so `provider` was removed from one entry's `model_args`:
`MISMATCH`, `provider=None`.

Not established: that the constraint changes routing. That is a claim about
OpenRouter's side, and reading the provider that served a call needed item 3.

---

## Item 3 — a failure now carries what it cost and which generation it was

`require_response` read the raw message, raised, and dropped it. Observed
2026-08-23: a MiniMax response that raised reported `finish_reason: stop` and
`cost: 0.0011607`, and contained §4.6's expected answer as prose. 20 such calls
across three panel runs went unaccounted for, and all three reports said failed
calls "may still have been billed" — timid in the wrong direction.

`JudgeResponseError` now carries the record of the call that failed, keyword-only
and undefaulted, because the defect being repaired is precisely that these were
in hand and omitted. Both go into the message too: a failure reaches a person as
a line in a report, and an id reachable only through `exc.generation_id` is not
in front of them when they are asking what went wrong.

**The id is `response_metadata['id']`, not `raw.id`.** Measured on both channels:
the message's own id is a LangChain run id minted in-process
(`lc_run--01a0376a-…`) that joins to nothing outside it, while OpenRouter's is
`gen-1787636121-…`. The test fake therefore has **no** `id` attribute — one that
carried it would let a stage read the wrong field and pass.

### The shape was got right on the second attempt, and the reason is worth keeping

`StageResponse` first gained `generation_ids: Tuple[str | None, ...]`, deviating
from the design note's singular field because singular composes wrong at the two
aggregating sites — they would have to pick one id and disown the rest, losing
exactly the calls whose spend they were already summing.

**Item 4 then added a third per-call fact and the tuple became wrong.** Three
index-aligned tuples make the alignment a convention across the three sites that
concatenate them, and drift would attribute one call's reasoning count to
another's generation, inside the record whose whole purpose is to be checkable.
So `CallRecord(generation_id, cost, reasoning_tokens)` and
`StageResponse.calls`, with `generation_ids` surviving as a derived property.

That the suite stayed green through that restructure is the point of the
property — and also the warning, since it meant the new field was unpinned until
five tests were written for it.

### What it bought

`probe_a2_panel.py` prices failed calls, reports `cost of answers` beside `cost
of failures` per panelist, and lists every call by generation id in a table the
OpenRouter console can contradict. The three failures are told apart by what
they leave behind: *would not coerce* (billed, identified), *transport error*
(rejected before a generation existed), *timeout* (genuinely unknown, and the
only thing the word "floor" is now reserved for).

One formatting trap, caught on reading the output: a case whose only failure was
a timeout rendered as `$0.000000`, which reads as *the failure was free* — the
same understatement in a new place. It prints `unknown (n call(s) returned no
price)` instead, from one formatter shared by both tables.

---

## Item 4 — the reasoning confound, measured, and the answer is not the suspicion

`scripts/probe_reasoning_channel.py` has each model answer the same real A2
prompt through both channels; only the channel differs inside a pair.
Cross-model comparison would say nothing, and averaging a model over both
channels would hide the difference being looked for. 32 calls, **$0.253191**.

**A failed call is still a measurement, which is why item 3 had to come first.**
MiniMax takes no tools and DeepSeek V4 Flash times out under `response_format`:
the cells where a channel misbehaves are exactly the cells the question is about.

| panelist | art7_case4 tools → schema | art15_case1 tools → schema |
|---|---|---|
| DEEPSEEK_V_4_PRO | 1183 → 2663 | 930 → **0** |
| GEMINI_3_7_FLASH | 695 → 603 | 1712 → 1517 |
| GROK_4_6 | 1119 → **0** | 2455 → 2947 |
| KIMI_K3 | 316 → 151 | 1368 → 460 |
| MINIMAX_M_3 | 632 → 156 | 537 → 567 |
| QWEN_3_8_27B | 598 → 257 | 1156 → 1817 |
| QWEN_3_8_2_4T | 733 → 622 | 1332 → 1446 |
| DEEPSEEK_V_4_FLASH | 335 → *timeout* | 400 → *timeout* |

**MiniMax — the model the whole suspicion came from — reasons on both channels.**
The `{'reasoning': 0}` observation of 2026-08-23 does not reproduce.

**Two clean zeros appeared elsewhere, each on one of the model's two cases.**
DeepSeek V4 Pro and Grok. A clean zero is not run-to-run variance; one case in
two is not a channel effect either. The verdict label is `INTERMITTENT` rather
than `SUPPRESSED`, because calling both the same would hide the more awkward
finding — that the effect is not a stable property of the model. **Grok is the
panel's own `json_schema` member**, so §8's confound is real for at least one
panelist, in a shape nobody predicted.

**Bertan: this is not a statistically meaningful sample.** Two cases of 433, one
run per cell. It is sized to catch a categorical effect and nothing finer, and
the docstring now says so in the terms he set: a `SUPPRESSED`/`INTERMITTENT`
mark is an observation about a call and not a rate; a "no suppression" mark is
the weakest possible negative result and does not clear a model; nothing supports
comparing models to each other. The intended repeat is a larger, stratified case
set, possibly a wider roster, and **repeats per cell**.

### The finding outside the question asked

**MiniMax failed `json_schema` on both cases**, `OutputParserException: Invalid
json output`. The committed channel assignment rests on it going **6/6** on that
channel on 2026-08-23. What differs between then and now is `require_parameters`,
which no run before this session carried — plausibly it changed which upstream
provider serves MiniMax, and with it the output. Every generation id is in the
report, so the console can settle it. **If it holds, `require_parameters` did not
only make the channel assignment stick — it invalidated part of the evidence the
assignment was chosen on.** Open, and it bears on panel composition.

---

## Item 5 — 25 runs, and Bertan's catch

### `[0]` is not a way to name a model

Bertan, reading the script: `get_llm_config()["sufficiency_judge"][0]`. **Ten
call sites do this** — eight probes, `judge.py`, and `main_dev.py` at `[5]`. Each
makes the subject of a measurement a consequence of where a model sits in
`llm_names`, a list nobody reads as ordered. Insert a panelist at the front and
every indexed probe silently repoints while its reports keep their titles; the
four stability samples are only comparable if all four measured the same model,
and an index is not a way to promise that.

`llm_config.panelist(entries, model)` raises rather than falling back — a probe
pinned to a model that has left the panel must stop, not measure its neighbour
under the same title. Five tests; the mutation that returns `entries[0]`
regardless is the original defect written out, and it fails four of them.

Only `probe_a2_stability.py` is converted. **Nine sites still index.**

### The re-measure

**RUNS 5 → 25, and cost was never the reason it was 5.** 150 calls,
**$0.010072**. The panel probe cannot do this — Grok at $0.07 a case — but the
single-model stability question can, and it is the question the four samples
failed to answer.

| case | dominant | verdict |
|---|---:|---|
| art7_case3 | 25/25 | stable |
| art7_case4 | 25/25 | stable |
| art8_case1 | 25/25 | stable |
| art33_case1 | 24/25 | UNSTABLE — core content differs |
| art15_case1 | 25/25 | stable core, wording varies |
| art41_case3 | 24/24 | stable core, wording varies |

**The one unstable case differs by the word `and`.** Twenty-four runs split
"without undue delay" and "within 72 hours" into two core claims; one joined
them. The diff is `core only in variant 2: ['and']`. Nothing crossed the
core/auxiliary boundary, so by the 2026-08-22 criterion nothing changed about
what the quote must contain. **The substantive reading is 0 of 6**, and the
metric over-reports in exactly the direction its own docstring warns of.

**Every call received its reasoning budget: 150/150 reported a count, none zero,
min 200 / median 284 / max 632.** Under the `model_args` defect the spread would
have been one high value among 149 near-zeros. That is what item 5 was really
asking, and no earlier sample could have shown it.

Two things not to overclaim. The 2026-08-23 samples already read 0/6 and 0/6
*before* that fix, so today is consistent with them and **the 4/6 and 3/6 of
2026-08-22 remain unexplained outliers**. And `art15_case1`, historically the
wobbliest at 10/1/10/13/10 core claims, returned 10 on all 25 runs — a real
change, not attributable to the fix on this evidence.

---

## Verification

- Suite **329 → 354 passed**, 5 xfailed. Green before and after every change.
- **Twenty-five tests added** across three areas: the generation id per stage and
  through failures, the reasoning count including a reported `0` surviving as
  `0`, per-call record alignment, and the named roster lookup.
- **Thirteen mutations, each caught by exactly the tests that claim that
  behaviour and no others.** The two worth naming: collapsing a reported `0` to
  `None` fails precisely the test that says zeros must survive — which is the
  mutation that would have manufactured item 4's finding; and `panelist`
  returning `entries[0]` regardless is the original defect, failing four tests.
- **Live, end to end:** `tag_claims` on `gdpr_art7_case4` returned
  `cost 0.00010416`, `generation_ids ('gen-1787637099-smpY4tk0IIR3mN33ke8O',)`.
- The panel report's accounting sections were rendered from a **hand-built grid**
  — a billed failure, a timeout with no price, an unidentified call — because a
  live run is unlikely to produce all three on demand. No calls spent.
- One commit was checked out in a worktree to confirm it stands alone; the only
  failure was `test_installed_packages_match_uv_lock`, an artifact of running a
  worktree's tests against the main venv.
- **Live spend this session:** wire probe $0.008812 + control; reasoning channel
  $0.253191; stability $0.010072; diagnostics ≈ $0.001. Roughly **$0.28**, and
  none of these totals is a floor any more except where a call never returned.

## Mistakes made this session

All the assistant's unless stated.

- **`[0]` was left in place while writing a probe whose entire subject is which
  model it measures.** Bertan found it by reading the file. The defect is nine
  more places and predates this session, but it was read past twice today.
- **The per-call shape was committed as parallel tuples and restructured an hour
  later**, when item 4 added the third fact. The trigger was foreseeable — item 4
  was already on the list, and its field was named in the same design note.
- **The panel report's failed-call formatter printed `$0.000000` for a
  timeout-only case**, reproducing in a new place the understatement the change
  was written to remove. Caught on reading the output.
- **`RUNS = 5` was accepted as a constraint for four samples.** The recorded
  lesson said N=5 could not support the comparison; nobody checked that the
  reason was cost, and it was not — the fix was two cents.

---

## State handed to the next session

| | |
|---|---|
| `clause-and-effect` | `dev-04`, eleven commits pushed, **tree clean** |
| `ai-common` | untouched |
| Suite | **354 passed / 5 xfailed** |
| Panel roster | 8 panelists; MiniMax's `json_schema` assignment now **in doubt** |
| Panel | verdict derivation, aggregation and calibration **still not built** |
| Reports | wire params (stdout only), reasoning channel, A2 stability ×1 |

## Open items — start here next session

| # | open item | state |
|---|---:|---|
| 1 | **MiniMax now fails `json_schema`**, the channel it was assigned on 6/6 evidence. `require_parameters` is the suspect, and the generation ids are recorded. Bears directly on panel composition | measurement, then a config decision |
| 2 | **The coverage metric calls a one-conjunction difference UNSTABLE.** Proposed and not built: report whether two variants are *nested* (a joining/splitting difference — soft) or *crossing* (material moved across the boundary — hard). Derived from the criterion rather than a stoplist. **Bertan's call** | designed, not built |
| 3 | **Nine call sites still index the roster with `[0]`**, and `main_dev.py` with `[5]`. `llm_config.panelist` exists | mechanical |
| 4 | **Verdict derivation (§7), aggregation into `CaseJudgement`, calibration (§9)** — the actual panel. Nothing built | the main task |
| 5 | **A second stability sample at N=25.** Twenty-five runs make the frequency of a minority reading estimable *within* six cases; only a second sample shows the instrument's own sample-to-sample variance | ~$0.01 |
| 6 | **Repeats per panelist in the panel probe.** Reached from two directions now — the panel and the reasoning-channel probe both need it. Decide the sample size once | design decision, then calls |
| 7 | **The reasoning-channel repeat**: stratified case set, wider roster, repeats per cell. Nothing in the 2026-08-25 sample is a rate | measurement |
| 8 | **Re-derive design §8.2.** Its clean/unclean analysis names none of the current eight | doc work, blocks panel composition |
| 9 | **`art15_case1` is the case the panel splits on.** Read the coverage variants rather than counting them | analysis |
| 10 | **`gdpr_test_data_generation.py:150` still raises `KeyError: 'orchestrator_model'`** | broken, one line |
| 11 | **`ai_common.get_llm` mutates its argument** on every provider branch; **`ChatOpenRouter` is built with no timeout** | `ai-common` PR |
| 12 | **Reject degenerate claims in `stage_a2.py`** — `""` and `"..."` still reach the caller. 175 further calls this session produced none | carried, low urgency |
| 13 | **Measure beyond the six** — 6 of 433; `conditional` (133 cases) never touched | carried |
| 14 | **`art7_case4`'s third sentence: core or auxiliary** — Bertan's call | carried, undecided |
| 15 | `judge.py` and now **thirteen** `scripts/` files print rather than log | carried, flagged |
| 16 | Everything else on the 2026-08-23 list — the A1↔A2 consistency check, the atomicity rule, §4.6's metric, `art8_case5`, GLM parked on latency | carried |
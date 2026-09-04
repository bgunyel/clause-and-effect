# 2026-09-04 · session 1 — the model-call tier leaves the judge

**Branch** `dev-04`, `5bc8659 → 35fe340`, three commits, **61 ahead of `main`**,
pushed. **Suite 571 → 572 passed / 5 xfailed.** **No model was called all
session**; every check ran against fakes and the spend is **$0.00**.

One item, item 4 from session 3's list: lift the generic machinery out of
`src/eval/sufficiency/llm.py` into a shared `src/llm/` tier. Bertan opened the
session with it and added the constraint that decides its shape — **every LLM
call in the repository will go through the logged wrapper**, not only the
judge's.

---

## `src/llm/` exists, and the judge's module is 158 lines against 695

The test applied to each thing in the old module was the one recorded in
`todo.md` on 2026-08-26: *does this encode a fact about LangChain and OpenRouter,
or a fact about the judge?*

| module | holds |
|---|---|
| `src/llm/channels.py` | `FUNCTION_CALLING`, `JSON_SCHEMA`, `TOOL_CALL_AUTO`, moved out of `llm_config.py`, which now imports them |
| `src/llm/structured.py` | `build_structured_llm` (renamed from `build_judge_llm`), `StructuredPayload`, `payload_from_tool_call` — the repository's only `ai_common` touchpoint |
| `src/llm/call.py` | `llm_call`, `require_payload`, `LlmResponse`, `CallRecord`, `LlmResponseError`, `sum_costs` |

`src/llm/__init__.py` exports nothing, for the reason `src/db/capture/__init__.py`
gives and one this tier makes sharper: Python runs a package's `__init__` before
any submodule of it, so a re-export would make importing three constants pull the
module that loads torch.

What stayed behind is what the judge *means* rather than what a model does —
`JudgeResponseError`, `StageResponse`, and the two adapters `require_response`
and `stage_call`, which add the stage label and nothing else. The five stage call
sites are still one line each.

## Two departures from the plan the session was executing

Both were the assistant's, both were decided while writing the code, and both are
recorded in `todo.md` beside the plan they depart from.

**`StageResponse` subclasses `LlmResponse` rather than restating three fields.**
The plan said it stays in the judge, which it does; it did not say whether it
should be a second dataclass. Restating the fields would have duplicated the
reasoning about why `cost` may be `None` and why that is not `0.0` — the kind of
prose that is correct in one copy and stale in two. Sub-classing also has a
consequence worth more than the tidiness: `JudgeResponseError` is now catchable
as `LlmResponseError`, which is what a probe totalling the spend of *failed*
calls needs, since such a probe does not care which tier raised. That property is
asserted rather than assumed —
`test_the_judges_failure_is_the_shared_one_under_a_judge_name`.

**The log row's `error_message` no longer carries the stage prefix.** `llm_call`
writes the row before the judge's adapter ever sees the exception, so the row
gets the shared tier's wording rather than `stage A2: …`. Nothing is lost and one
thing is gained: `llm_call` already has a `stage` column, and repeating the stage
inside the message would store the same fact twice and make the column the copy
that can drift. What a *caller* sees is unchanged, which the per-stage tests
pin — six of them fail if the prefix is dropped.

## One deferral could be deleted rather than moved

`build_judge_llm` deferred its channel-constant import into the function body,
because the constants lived in `llm_config.py`, which imports `ai_common.enums`
at module scope — 0.24s and 195 modules. `src/llm/channels.py` imports nothing,
so `build_structured_llm` names the three strings at module scope and the
deferral is gone.

This is the only place the lift made something cheaper rather than moving it.
Everything else was re-measured to confirm it had not become *more* expensive:

| import | cost | heavy modules loaded |
|---|---:|---|
| `src.llm.channels` | 0.000s | none |
| `src.llm.structured` | 0.105s | none |
| `src.llm.call` | 0.107s | none |
| `src.eval.sufficiency.llm` | 0.108s | none |
| `src.eval.sufficiency.stage_a2` | 0.148s | none |

"None" is `torch`, `transformers`, `langchain_core` and `ai_common`, checked
against `sys.modules` in a fresh interpreter per row.

## The call log's status block was stale in a second way

`docs/design/llm-call-log.md` still opened with "the capture half does not exist
at all" and listed the wrapper and the `contextvar` as not built. Session 3 built
both and left the pass as item 9. Since the lift moved the file the document
names, the block was rewritten rather than patched: the logical-call half is
built, and the attempt half is not — `llm_call_sync`, the `httpx` patch and the
enrichment sweep, without which `llm_attempt` is never written and
`SUM(llm_attempt.cost)` has no rows to sum. That closes item 9.

`docs/design/sufficiency-judge.md` keeps its import-cost measurement, which is
still the judge's to state, and now says the builder it measured lives one tier
down while the guard still watches from the stage side — which is the side that
matters, since the guard exists to stop a *stage* import loading torch.

## Mistakes made this session

Both the assistant's, both caught by reading rather than by the suite, which
would have stayed green through either.

- **The assistant wrote an `__all__` block re-exporting `CallRecord` from the
  judge adapter.** This repository has two package `__init__` files whose
  docstrings argue at length against re-exporting, and the assistant had just
  written a third. The reasoning that produced it was about churn — six probe
  scripts import `CallRecord`, and a re-export would have left their import lines
  alone. That is a reason to touch six lines, not a reason to add a public
  surface. The probes import from `src.llm.call` now.
- **The assistant deferred an import that was already paid.** `require_response`
  was written with `from src.llm.call import require_payload` inside the function
  body, in a module that imports three other names from `src.llm.call` at module
  scope. It buys nothing and reads as though it does, which is worse than not
  deferring — this repository's import-cost comments are meant to be evidence,
  and a deferral with no cost behind it is a claim to re-measure that will waste
  someone's time.

## Another session was working in the same directory

Three things did not add up, and they have one cause.

`src/config.py` was found modified — the two `SecretStr` fields' defaults wrapped
in `SecretStr()` rather than left as bare strings. **The assistant did not make
this change**, and the git status captured when the session opened listed only an
untracked `src/llm/`, not a modified `src/config.py`. It was committed on its own
(`35fe340`) with the message saying it is not this session's work, so that it is
reviewable separately rather than riding into a refactor's commit unnoticed. The
change itself is correct — pydantic coerces these on validation, so the values
were always right and only the defaults disagreed with their annotation.

Then, while the dev-log was being written, `uv.lock` turned up modified and
`uv.lock.preupgrade` appeared beside it. **`make upgrade-safe` was running in
this working directory**, started by someone other than this session — `pgrep`
found it in tier 2, GuardDog scanning `docling 2.125.0`, with the candidate lock
moving fifteen-odd packages. Its `EXIT` trap restores `uv.lock` from the backup
unless both tiers come back clean, so neither file was touched here and neither
was staged.

The `?? src/llm/` in the opening git status, which the assistant could not
account for at the time, fits the same explanation.

**The operational lesson is about staging, not about `uv.lock`.** This session
ran `git add` with explicit paths for all three commits, so an in-flight
candidate lock was never a commit away — but the first commit's staging step was
the moment it would have been, and the only thing that caught the concurrent run
at all was reading `git status` before writing the dev-log rather than after.

## Verification

- **572 passed / 5 xfailed**, one more than the 571 session 3 handed over. The
  new test is the subclass property above.
- **Three mutations of the new seam, no survivors**: dropping the stage prefix in
  `_as_judge_error` (6 failures), swallowing the re-wording so the shared error
  escapes unchanged (13), replacing the failed call's `CallRecord` with an empty
  one (4).
- **This is a smaller sweep than session 3's** — 3 mutants against a seam, not
  17, 25 and 31 against three layers. It was scoped to the code that is new
  rather than moved: the wrapper's own logic was swept last session and is
  unchanged, which the diff shows and the sweep does not re-establish.
- **All fourteen `scripts/probe_*.py` were executed as modules** to confirm they
  still import after the rename. None was *run* — that would cost money and call
  models.
- **Import cost measured, not assumed**, per the table above.
- **Not verified: anything on the product path.** `llm_call_sync` was not built,
  so no product-path call goes through the wrapper and the tier's claim to serve
  both halves is still only structural.
- **Not verified: the lift against a live model.** Every check ran against fakes.
  The first real evidence will be the first logged panel run.

## State handed to the next session

| | |
|---|---|
| `clause-and-effect` | `dev-04` at `35fe340`, **61 ahead of `main`**, three commits this session, pushed |
| Working tree | clean of this session's work; `uv.lock` and `uv.lock.preupgrade` belong to a **concurrent `make upgrade-safe`** and were left alone |
| Suite | **572 passed / 5 xfailed** |
| Database | schema applied and live; **no rows** |
| Built | `src/llm/` (channels, structured, call); `src/eval/sufficiency/llm.py` reduced to the judge's adapter |
| Not built | `llm_call_sync()`, the `httpx` patch, the enrichment sweep |
| Panel | verdict derivation, aggregation and calibration **still not built** |

GitHub reported **one high-severity Dependabot alert on `main`** when the branch
was pushed (`security/dependabot/6`). Not looked at this session; `make
upgrade-safe` has to pass before this branch merges in any case.

## Open items — start here next session

Numbering follows session 3's list. Items closed this session are marked so;
everything else is carried forward unchanged.

| # | open item | state |
|---|---:|---|
| 3 | **The `llm_call()` wrapper.** Async flavour built and wired; **the sync flavour is outstanding** and blocked on item 11 | **half done**, carried |
| 4 | ~~**Lift the generic machinery into a shared `src/llm/` tier.**~~ Done, 2026-09-04 | **done** |
| 5 | **The `httpx` patch** — installed once from an entry point, never on import, forwarding non-completions traffic untouched. The half that makes `SUM(llm_attempt.cost)` true | **next**, the build |
| 6 | **The enrichment sweep**, at exit and as a re-runnable command | the build |
| 7 | **The pool under eight concurrent panelists is still unmeasured** | carried |
| 8 | **Revisit `pool_pre_ping`** with the corrected number: 43.4 ms per write, ~6.5 s per 150 calls. **Bertan's call** | carried, decision |
| 9 | ~~**Update `design/llm-call-log.md`.**~~ Status block corrected for the capture half and the lift | **done** |
| 10 | **Carrying functionality to `ai-common`** — deferred by decision, not by oversight | deferred |
| 11 | **`generator.py:99` makes a second model call per product answer and discards the result.** Delete it, use it, or decide it stays. **Blocks item 3's sync flavour, which is now the only thing between the tier and the product path** | **Bertan's call** |
| 12 | **The probe scripts carry their own `"STRUCTURE"`/`"TRANSPORT"` literals.** Untouched: their imports were updated this session, their status vocabulary deliberately was not | carried, decision |
| 13 | **A payload of `None` records `STRUCTURE_PROBLEM`** though nothing was generated. One line and one assertion, now in `src/llm/call.py` | carried |
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
| 31 | **One high-severity Dependabot alert on `main`**, reported on push | **new** |

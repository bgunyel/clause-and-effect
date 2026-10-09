# The three-shape pool probe — 2026-09-05

Live OpenRouter response bodies and the derived pool readings for
[#27](https://github.com/bgunyel/clause-and-effect/issues/27), *The three-shape
pool probe: separate the channel confound from the model*.

Nine calls: three request shapes × three models, `X-OpenRouter-Metadata: enabled`
on every one, one call per cell, identical prompt. All nine returned HTTP 200 on
the first send; no cell retried, timed out or errored. Total spend **$0.010138**.

Produced by `scripts/probe_three_shape_pool.py` (the nine calls) and
`scripts/probe_catalogue_vs_pool.py` (the catalogue read that follows them),
run from the working tree at the tip of `dev-05` plus this ticket's two new
scripts. Wall clock 15:28:24–15:29:00 UTC+3 for the nine calls.

## What each file is

| file | what it holds |
|---|---|
| `bodies.json` | **The measurement.** Nine wire dumps: request headers and body, response headers and body, status, per-send wall time. Everything else here is derived from it. |
| `corrected/report.txt` | **The report to read.** The rendered findings — the grid, the preconditions, the #13 anchors, the per-model membership diffs. |
| `corrected/cells.json` | **The cell summaries to read.** One record per cell: the full `available` list verbatim, endpoint count and distinct-provider count as separate numbers, the provider multiset, `endpoints.total`, `strategy`, `attempt`, the selected provider, finish reasons and cost. |
| `report.txt` | The **first** render, retained. Its *Anchors* section wrongly reads `not run` — see "The first render's defect" below. |
| `cells.json` | The first render's summaries. Correct, but lacking the `wire_model` field. |
| `catalogue-vs-pool.txt` | The catalogue's `supported_parameters` prediction differenced against each observed pool, as a multiset. |
| `catalogue.json` | The three raw `GET /api/v1/models/{model}/endpoints` responses the comparison reads. |

## The reading rule, registered before the run

Written into the probe's module docstring before any call was made, and repeated
at the head of the report:

> **Equal pool sizes are not the same pool.** The comparison that matters is set
> membership. At one call per cell a null result is *no difference observed at
> n=1*, not *no difference*.

Sharpened by what the dumps contain: `available` entries are
`{provider, model, selected}` and carry **no endpoint id**, so two endpoints of
one provider are indistinguishable within a pool. Membership is therefore
compared as a **multiset over providers**, never as a set. This is not
hypothetical — Kimi K3's `Fireworks` count moves 3 → 2 → 3 across the three
shapes while `Fireworks` never leaves the pool, which a set comparison would
report as no change.

No pre-registration entry was made, and the probe's docstring says why: the
outcome is a count and a membership list per cell, not a comparison against a
bar, so there is no threshold, stopping rule or selection surface to register.

## The first render's defect

`docs/eval-reports/` is append-only, so the first render stays as written and the
correction is a new entry rather than an overwrite.

The probe keyed its #13 anchor lookup on the roster's `ModelNames` enum
(`ModelNames.DEEPSEEK_V_4_FLASH_0731`) while the cells carry the wire id
(`deepseek/deepseek-v4-flash-0731`). The lookup missed and the *Anchors* section
printed `not run` for two cells that had in fact run and had in fact reproduced.
Fixed by matching on the wire id, and the report now prints the wire ids it saw
when an anchor finds nothing, so a missed lookup can never again read as an
absent measurement.

**The correction was made by re-rendering `bodies.json`, not by re-running the
probe** (`--render`). The dumps are the measurement and the report is a view over
them; nine fresh calls would have silently substituted a different measurement —
against a pool that moves without us — for the one being corrected.

One artefact of that: `call_seconds` reads `0.0` in `corrected/cells.json`,
because the field was added to the dump format after the run and the v1
`bodies.json` does not carry it. `wire_seconds` is the real per-send timing and
is present throughout.

## Redaction

Checked rather than assumed, since these directories are public.

**Credentials: clean at capture.** Every `authorization` header reads
`<redacted>` — nine occurrences, one per call — redacted by the probe before
anything reached disk, so an unredacted key was never written.

**Account-scoped fields: redacted after the fact, and the probe corrected.**
[#29](https://github.com/bgunyel/clause-and-effect/issues/29) closed while this
ticket was being written and established that credential-shaped is not the only
shape that matters here: the published bodies also carry fields that identify
the *account* rather than the observation. This probe predated that ruling and
published **nine `set-cookie: __cf_bm=…` values**, Cloudflare's bot-management
cookie, one per call. They are now redacted **by value with the key preserved**,
the convention the capture already used for `authorization`, and
`_SENSITIVE_HEADERS` in the probe has been corrected so a rerun never writes
one. #29's other two fields (`workspace_id`, `user_id`) live in the
`/generation` record, which this probe never reads; both are absent here,
confirmed by grep rather than by argument.

`cf-ray` and `x-generation-id` are deliberately **not** redacted. The first is a
per-request Cloudflare trace id and the second is the observation's own
identity, which #13 relies on to resolve a call at the generation endpoint.
Redacting evidence because it looks like an identifier is the opposite failure.

**The published `bodies.json` is therefore not byte-identical to the capture**,
and following #29's precedent the transform is auditable rather than trusted.
The verbatim bytes are kept outside `docs/` at
`tmp/issue-27-three-shape-pool-verbatim/bodies.verbatim.json` — gitignored — so
the redaction can be reviewed before anything is destroyed; delete it once
approved.

| | sha256 |
|---|---|
| verbatim | `5cacd2c4acb55e6960f4d3d30b4d6b35a7b0ee35e27d05a0cbc60592659ddae4` |
| published | `3af66ed52f0d5b3c2075d73a8f05eaa43af5f964d59915576d2767dd2ac65935` |

Parsed, the two are identical once `set-cookie` is dropped from both — asserted
in the redaction pass, not claimed afterwards. No other published file in this
directory ever held a cookie: `cells.json`, `report.txt`,
`catalogue-vs-pool.txt` and `catalogue.json` carry no headers at all.

One string in `bodies.json` looks alarming and is not a credential: Grok's
responses carry an opaque provider-issued reasoning blob at
`choices[0].message.reasoning_details[1].data`, whose base64 payload decodes to
`{"endpoint_slug":"x-ai/grok-4.6-20260810|xai"}`. It is xAI's own signed
reasoning token, not ours.

That slug is worth noting for a second reason: it is the only endpoint
identifier appearing anywhere in these bodies, and it is
`permaslug|provider` — **provider-level**. It cannot separate xAI's two
endpoints, which is the same limitation `available` has, and it is why
membership here is compared as a multiset.

## Naming

`bodies.json` follows the shape of #13's `all.json` — a list of records, each
with a `label`, the request, and the response — so the two sets of dumps read
alike.

#27 states that the convention set by
[#29](https://github.com/bgunyel/clause-and-effect/issues/29) is the one this
directory follows. #29 closed while this was being written and put #13's bodies
at `docs/eval-reports/2026-09-05-openrouter-body-observations/` — a dated
directory with a `README.md` naming the run, the commit and each file, and
published bodies that are redacted rather than verbatim with sha256 recorded for
both. This directory matches that on every point, so nothing here needs to move;
the one place it was behind was the redaction set, corrected above.

#29 moved #13's bodies out of `tmp/issue-13-header-probe-bodies/`. Neither probe
cites that path — checked, not assumed — so the move breaks nothing here.

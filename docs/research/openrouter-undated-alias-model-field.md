# What OpenRouter's `model` field holds for an undated slug, and whether it moves

Research for [issue #386](https://github.com/bgunyel/clause-and-effect/issues/386)
(`wayfinder:research`), under map #6. Sources read on **2026-11-17** by the
assistant.

**What kind of evidence this holds.** Three kinds, kept apart:

1. **Captured completion bodies already in the repository.** Sixteen of them,
   recorded on 2026-09-05 by two earlier tickets, six of them for *undated*
   roster slugs. They are the strongest evidence here, and each is cited by
   file and line.
2. **Observations made for this document**: unauthenticated `GET`s of
   OpenRouter's public catalogue, `/api/v1/models` and
   `/api/v1/models/{author}/{slug}/endpoints`, on 2026-11-17 between
   08:13:56 and 08:14:26 UTC. These show what the catalogue said at that time.
   They are not committed, so re-fetching gets whatever the catalogue says on
   the day of the re-fetch.
3. **Documentation**: OpenRouter's docs, its published OpenAPI document, and the
   labs' own model pages.

**No completion or generation call was made for this document.** No API key was
used. Anything that would take such a call to see is marked.

### The evidentiary marker

- **`[NEEDS OBSERVATION]`**: documented, or inferred from documentation or from
  a different case, but not seen. Grep this marker to get the checklist at the
  end.
- **`[DOCS SILENT]`**: the source does not answer the question. That is a gap,
  and it is not the same as "the field is absent".

A claim with neither marker is either a direct reading of a captured body or
catalogue response, with its path given, or a direct quotation of a named source.

## Why this file exists, and what it is not

[#378](https://github.com/bgunyel/clause-and-effect/issues/378) settled that an
acceptance cell's model is `llm_call.model`, the `ModelNames` value. So a change
*behind* that value does not create a new cell. `llm_attempt.model_alias` is
specified as "`model` in the response body — the wire id, e.g.
`minimax/minimax-m3`" (`docs/design/llm-call-log.md`, the `llm_attempt` source
table; `src/db/models/llm_log.py:273-277`, decision 17). It is the only column
that could show such a change. Whether it can show one depends on facts about
OpenRouter, and this file collects them.

**It decides nothing.** How to detect an unrecorded change behind a `ModelNames`
value is [#387](https://github.com/bgunyel/clause-and-effect/issues/387)'s
question. The section *What the downstream decision turns on* states what that
answer depends on, and stops there.

## A correction to the ticket's premise

The ticket says the only observation in the repository is for the dated slug
`deepseek/deepseek-v4-flash-0731`. That is true of
`docs/eval-reports/2026-09-05-openrouter-body-observations/`. It is not true of
the repository as a whole.
`docs/eval-reports/2026-09-05-three-shape-pool-probe/bodies.json` (#27, captured
the same afternoon) holds three live completion bodies each for two **undated**
roster slugs, `moonshotai/kimi-k3` and `x-ai/grok-4.6`. All nine of that file's
calls sent `X-OpenRouter-Metadata: enabled`. So sub-question 1 already has a
direct answer for two of the six undated slugs.

## Four identifiers, and the words for them

OpenRouter uses four kinds of identifier. The question only makes sense once
they are kept apart.

| term here | OpenRouter's name for it | example (observed) | source of the term |
|---|---|---|---|
| **slug** | `id`: "The routable slug used in API requests" | `x-ai/grok-4.6` | [Models API reference](https://openrouter.ai/docs/api_reference/models.md), §"Canonical slugs vs. display IDs" |
| **permaslug** | `canonical_slug`: "The permanent canonical reference for the underlying model checkpoint". Also `model_permaslug`, described as "Canonical model slug". | `x-ai/grok-4.6-20260810` | same page; OpenAPI `ProviderResponse.model_permaslug` |
| **rolling alias** | a `~`-prefixed slug that "point[s] dynamically to the latest approved stable version of a model family" | `~x-ai/grok-latest` | same page, §"Rolling aliases (`~` prefix)" |
| **spelling alias** | "known aliases", resolved to an `id` | `anthropic/claude-3-5-sonnet` → `anthropic/claude-3.5-sonnet` (OpenRouter's example; not observed) | same page |

The ticket's "undated alias" is, in OpenRouter's vocabulary, a **slug**. It is
not a rolling alias. None of the six undated roster slugs carries a `~`, and none
has an `alias_target` in the catalogue (observed, below). OpenRouter calls such a
slug *concrete*: the Latest Model Resolution guide gives
`anthropic/claude-opus-4.8` as the example of "the concrete model slug" to pin
"[w]hen you need reproducibility"
([latest-resolution](https://openrouter.ai/docs/guides/features/latest-resolution.md)).
The lab's own convention can say otherwise. xAI's is one example, set out under
sub-question 2.

In this repository's terms:
`ModelNames.GROK_4_6.value` is `'grok-4.6'` (`ai_common/enums.py:44`).
`MODEL_NAME_ALIAS_DICT` maps it to the slug `'x-ai/grok-4.6'`
(`ai_common/llm.py:54-55`), and that slug is the wire id that `model_alias`
records. `ai_common` is read at the installed revision `0f0bad2…`,
`.venv/lib/python3.13/site-packages/ai_common/`.

## Sub-question 1: what the completion body's `model` holds

**Observed: it echoes the requested slug, for the dated slug and for both
undated slugs captured.** The versioned id appears elsewhere in the body, but
only when `X-OpenRouter-Metadata: enabled` is sent. It appears in
`openrouter_metadata.endpoints.available[].model`, and that holds the
**permaslug**.

| captured call | request `model` | response `model` | `openrouter_metadata.requested` | `…endpoints.available[].model` | file:line |
|---|---|---|---|---|---|
| dated, `base-1` (no metadata header) | `deepseek/deepseek-v4-flash-0731` | `deepseek/deepseek-v4-flash-0731` | (no block) | (no block) | `2026-09-05-openrouter-body-observations/base-1.json:59`, `:120` |
| dated, `hdr-3` | `deepseek/deepseek-v4-flash-0731` | `deepseek/deepseek-v4-flash-0731` | `deepseek/deepseek-v4-flash-0731` | `deepseek/deepseek-v4-flash-20260731` ×23 | `…/hdr-3.json:60`, `:121`, `:174`, `:185` |
| **undated**, `KIMI_K3::plain` | `moonshotai/kimi-k3` | `moonshotai/kimi-k3` | `moonshotai/kimi-k3` | `moonshotai/kimi-k3-20260715` ×16 | `2026-09-05-three-shape-pool-probe/bodies.json:840`, `:873`, `:923`, `:934` |
| **undated**, `KIMI_K3::function_calling` | `moonshotai/kimi-k3` | `moonshotai/kimi-k3` | `moonshotai/kimi-k3` | `moonshotai/kimi-k3-20260715` ×13 | `bodies.json:1051`, `:1111`, `:1172` |
| **undated**, `KIMI_K3::json_schema` | `moonshotai/kimi-k3` | `moonshotai/kimi-k3` | `moonshotai/kimi-k3` | `moonshotai/kimi-k3-20260715` ×15 | `bodies.json:1285`, `:1338`, `:1388` |
| **undated**, `GROK_4_6::plain` | `x-ai/grok-4.6` | `x-ai/grok-4.6` | `x-ai/grok-4.6` | `x-ai/grok-4.6-20260810` ×2 | `bodies.json:1511`, `:1544`, `:1601`, `:1612` |
| **undated**, `GROK_4_6::function_calling` | `x-ai/grok-4.6` | `x-ai/grok-4.6` | `x-ai/grok-4.6` | `x-ai/grok-4.6-20260810` ×2 | `bodies.json:1659`, `:1719`, `:1787` |
| **undated**, `GROK_4_6::json_schema` | `x-ai/grok-4.6` | `x-ai/grok-4.6` | `x-ai/grok-4.6` | `x-ai/grok-4.6-20260810` ×2 | `bodies.json:1845`, `:1898`, `:1955` |

The remaining captured bodies are `base-2/3` and `hdr-1/2` of the first
directory, the `ok-nostructured+hdr` probe in its `errors.json`, and the three
DeepSeek cells of `bodies.json`. All are for the dated slug, and all echo the
request too. That makes sixteen bodies out of sixteen. Every metadata block
reads `"strategy": "direct"` (for example `bodies.json:116`).
OpenRouter's documented strategy values include separate `latest` and `alias`
strategies
([Router Metadata](https://openrouter.ai/docs/guides/routing/routers/router-metadata.md),
field reference), so `direct` is the strategy for a request that names a slug.

**Where a permaslug does appear without the metadata header.** It appears on the
generation endpoint, not in the completion body. The one `/generation` record
captured is for the dated slug, generation `gen-1788604005-FWNP4eQHPSVrupsNHHjj`,
which is `hdr-3`'s. It reads `data.model: "deepseek/deepseek-v4-flash-20260731"`
and `data.provider_responses[0].model_permaslug:
"deepseek/deepseek-v4-flash-20260731"`
(`2026-09-05-openrouter-body-observations/generation_window.json`,
`polls[3].body`, which is a JSON string). The same call's completion body said
`deepseek/deepseek-v4-flash-0731` (`hdr-3.json:121`). So **the completion
`model` and the generation `model` disagree for the same call**: the first is
the slug and the second is the permaslug. Whether the generation `model` is also
the permaslug for an undated slug has not been seen, because the #27 probe never
read `/generation`. `[NEEDS OBSERVATION]`

A permaslug also appears, by accident, inside xAI's opaque reasoning blob. Each
Grok body's `choices[0].message.reasoning_details[1].data` decodes to a string
containing `endpoint_slug":"x-ai/grok-4.6-20260810|xai"`. The assistant
re-checked this on all three Grok cells, and #27's README recorded it first. It
is provider-specific and undocumented, and it is present only on reasoning
output, so it is noted here and not relied on.

**What the documentation says, against what was seen.**

- The OpenAPI `ChatResult.model` is described only as "Model used for
  completion", example `'openai/gpt-4'`
  ([openapi.yaml](https://openrouter.ai/docs/openapi/openapi.yaml), schema
  `ChatResult`). Whether that means the slug or the permaslug is not said.
  `[DOCS SILENT]`. The bodies above answer it for chat completions on a slug
  request.
- The OpenAPI `EndpointInfo.model`, which is what `available[]` holds, has no
  description. Its example is `'openai/gpt-4o'`, a slug
  (schema `EndpointInfo`), and the Router Metadata guide's examples are slugs
  too. **The observed values are permaslugs, every time.** The documentation's
  examples do not match the observed shape.
- For a **rolling alias**, OpenRouter documents that the response "`model` field
  reflects the concrete model that actually served the request, not the alias
  you sent", with example `"model": "anthropic/claude-opus-4.8"`
  ([latest-resolution](https://openrouter.ai/docs/guides/features/latest-resolution.md),
  §Response). Two points about that. The example resolves to a *slug*, not a
  permaslug. And the guide's examples use `POST /api/v1/responses`. Whether
  `/chat/completions` reports a rolling alias the same way has not been seen.
  `[NEEDS OBSERVATION]`. No roster slug is a rolling alias.
- For a **spelling alias** (`anthropic/claude-3-5-sonnet`), whether the response
  echoes the spelling sent or the `id` it resolved to is not said.
  `[DOCS SILENT]`

### Per roster slug

`canonical_slug` was observed in `/api/v1/models` on 2026-11-17 (470 entries;
the response body's sha256 was `6a957171…412259`). The 2026-09-05 permaslug
comes from the per-endpoint `name` field (`"<provider> | <permaslug>"`) in
#27's `catalogue.json`, which covers only three slugs.

| roster slug (`ai_common/llm.py`) | dated in the slug? | completion `model` seen | permaslug 2026-09-05 | `canonical_slug` 2026-11-17 | `alias_target` | `/endpoints` 2026-11-17: count, permaslugs in `name` |
|---|---|---|---|---|---|---|
| `deepseek/deepseek-v4-flash-0731` | yes | echo of request (16 bodies) | `deepseek/deepseek-v4-flash-20260731` (`catalogue.json`) | `deepseek/deepseek-v4-flash-20260731` | none | 29, all `…-20260731` |
| `deepseek/deepseek-v4-pro-0813` | yes | not captured `[NEEDS OBSERVATION]` | not captured | `deepseek/deepseek-v4-pro-20260813` | none | 26, all `…-20260813` |
| `google/gemini-3.7-flash` | **no** | not captured `[NEEDS OBSERVATION]` | not captured | `google/gemini-3.7-flash-20260813` | none | 7, all `…-20260813` |
| `x-ai/grok-4.6` | **no** | echo of request (3 bodies) | `x-ai/grok-4.6-20260810` (`catalogue.json:3801`) | `x-ai/grok-4.6-20260810` | none | 6, all `…-20260810` |
| `moonshotai/kimi-k3` | **no** | echo of request (3 bodies) | `moonshotai/kimi-k3-20260715` (`catalogue.json:2412`) | `moonshotai/kimi-k3-20260715` | none | 27, all `…-20260715` |
| `minimax/minimax-m3` | **no** | not captured `[NEEDS OBSERVATION]` | not captured | `minimax/minimax-m3-20260531` | none | 8, all `…-20260531` |
| `qwen/qwen3.8-27b` | **no** | not captured `[NEEDS OBSERVATION]` | not captured | `qwen/qwen3.8-27b-20260814` | none | 26, all `…-20260814` |
| `qwen/qwen3.8-2.4t-a95b` | **no** | not captured `[NEEDS OBSERVATION]` | not captured | `qwen/qwen3.8-2.4t-a95b-20260812` | none | 4, all `…-20260812` |

Three further observations from the same fetch:

- **Every roster slug has a dated permaslug, and no two roster slugs share
  one.** The only other `id`s that share a roster slug's `canonical_slug` are
  its `:batch` catalogue variants (for example `x-ai/grok-4.6:batch`).
- **The date in a permaslug is not always the `created` date.** `x-ai/grok-4.6`
  has `created` 1786548957 (2026-08-12 UTC) against a permaslug dated
  `20260810`. `moonshotai/kimi-k3` has 2026-07-16 against `20260715`.
  What the date denotes, whether a lab release date or something else, is not
  documented. `[DOCS SILENT]`
- **The catalogue's `links.details` path for an undated slug uses the
  permaslug.** For `x-ai/grok-4.6` it is
  `/api/v1/models/x-ai/grok-4.6-20260810/endpoints`. Fetching that path
  returned the same record as `/api/v1/models/x-ai/grok-4.6/endpoints`
  (`id: x-ai/grok-4.6`, six endpoints).

## Sub-question 2: when an alias moves, does the value change, and is it announced

The question splits, because there are three different things that could
"move".

### 2a. OpenRouter re-points a slug to a different permaslug

- **Documented: a permaslug does not change.** The Models guide calls
  `canonical_slug` the "Permanent slug for the model that never changes"
  ([models guide](https://openrouter.ai/docs/guides/overview/models.md), Model
  Object Schema). The Models API reference calls it "[t]he permanent canonical
  reference for the underlying model checkpoint". That is a claim about the
  permaslug. **Whether the *slug* `x-ai/grok-4.6` can be re-pointed to a
  different permaslug is not stated anywhere read.** `[DOCS SILENT]`. Nothing
  read describes such an operation, and nothing rules it out.
- **What the observed body shape implies, as an inference only.** On every
  captured call the completion `model` is the slug sent. If a slug were
  re-pointed, `model` would then still read the slug, and only the permaslug
  fields would differ: `available[].model` (metadata header only), the
  generation record's `model` and `model_permaslug`, and the catalogue's
  `canonical_slug`. This has not been seen, because no re-point has been
  observed. `[NEEDS OBSERVATION]`
- **Observed: no re-point across 73 days, for the three slugs with two
  snapshots.** `deepseek/deepseek-v4-flash-0731`, `moonshotai/kimi-k3` and
  `x-ai/grok-4.6` had the same permaslug on 2026-09-05 and 2026-11-17. Over the
  same period OpenRouter added newer family members as separate slugs instead:
  `x-ai/grok-4.7` (`x-ai/grok-4.7-20260916`), `moonshotai/kimi-k3.1-pro`, and
  `deepseek/deepseek-v4.1-flash`. The undated slug stayed put. That fits a slug
  being a fixed pointer. It does not show that one cannot move, and two
  snapshots would miss a move that was later reversed.
- **The documented mechanism for "follow the newest" is the rolling alias, and
  it is machine-readable.** The `Model` schema carries `alias_target`:
  "Concrete model targeted by this tilde-latest alias, when applicable", with
  `slug` "Routable model ID of the concrete target, matching that model row's
  id" (OpenAPI `ModelAliasTarget`). That field was added on
  2026-07-29 ([API changelog](https://openrouter.ai/docs/changelog.md), entry
  "`Model`: new property `alias_target`"). On 2026-11-17, 19 catalogue entries
  carried it, all `~`-prefixed. One of them is `~x-ai/grok-latest` →
  `x-ai/grok-4.7`, so the rolling alias now targets a different model from the
  roster's `x-ai/grok-4.6`. What it targeted earlier was not observed. Another is `~moonshotai/kimi-latest` → `moonshotai/kimi-k3`.
  The guide says only that "[w]hen a new model is promoted to 'latest', these
  fields update automatically"
  ([latest-resolution](https://openrouter.ai/docs/guides/features/latest-resolution.md),
  §Pricing and capabilities). Whether a retarget emits any event is not stated.
  `[DOCS SILENT]`

### 2b. The lab moves its own alias behind an unchanged OpenRouter slug

This is a separate layer. OpenRouter sends *some* model id to the provider's API,
and the lab may treat that id as an alias of its own.

| lab | what its docs say about an undated name | does the roster model appear? | source (read 2026-11-17) |
|---|---|---|---|
| xAI | "`<modelname>` is aliased to the latest stable version. `<modelname>-latest` is aliased to the latest version. … `<modelname>-<date>` refers directly to a specific model release. This will not be updated and is for workflows that demand consistency." | `grok-4.6` is listed with **no dated id** on the page. Dated ids are listed for `grok-4.20` (`grok-4.20-0309`). | [docs.x.ai/developers/models](https://docs.x.ai/developers/models), §Model Aliases, "Last updated: September 21, 2026" |
| Google | "Stable: Points to a specific stable model. Stable models usually don't change." `-latest` "will get hot-swapped with every new release", with "[a] **2-week notice** … through email". | **`gemini-3.7-flash` does not appear** on Google's current model list, which names 3.8, 3.6 and 3.5 Flash. | [aistudio.google.com/docs/models](https://aistudio.google.com/docs/models), §Model version name patterns |
| Moonshot | No versioning statement. `kimi-k3` is listed with no dated variant. `kimi-latest` is listed as Deprecated. | yes, `kimi-k3` | [platform.kimi.ai/docs/models.md](https://platform.kimi.ai/docs/models.md) |
| MiniMax | No versioning statement for `MiniMax-M3`. A **documented precedent of a lab moving a name**: for M Plan and Token Plan users, "[s]tarting October 19, 2026, all requests to M2.5 and M2.7 models … will automatically be routed to **M3.1 Flash**. Existing model names will continue to work for backward compatibility". | yes, `MiniMax-M3` | [platform.minimax.io/docs/faq/models.md](https://platform.minimax.io/docs/faq/models.md) |
| Alibaba (Qwen) | "A model series is available in three forms: the series name (for example, qwen-max, qwen-plus, qwen-turbo), a dated version name (for example, qwen-max-2025-01-25), and a -latest alias (for example, qwen-max-latest). All three forms are stable models." What an undated series name resolves to is not stated. "A retirement notice is published no later than 3 months before End of Service (EoS)." | Neither `qwen3.8-27b` nor `qwen3.8-2.4t-a95b` appeared on Model Studio's model list. That page's raw HTML carries no model table, so the reading is from a rendering fetch: page dated "Nov 16, 2026", with only `qwen3.8-flash` and `qwen3.8-omni-flash*` from the 3.8 series. Both roster models are open-weight (`hugging_face_id` `Qwen/Qwen3.8-27B` and `Qwen/Qwen3.8-2.4T-A95B` in the catalogue) and are served by third parties on OpenRouter. | [Model Studio models](https://www.alibabacloud.com/help/en/model-studio/models); [decommissioning policy](https://www.alibabacloud.com/help/en/model-studio/model-depreciation) ("Last Updated:Oct 27, 2026") |

Three points follow.

1. **By xAI's own convention, `grok-4.6` is a "latest stable" alias at xAI,
   while OpenRouter labels it with a fixed permaslug, `x-ai/grok-4.6-20260810`.**
   Which id OpenRouter sends upstream to xAI, `grok-4.6` or something dated, is
   not documented. `[DOCS SILENT]`. Neither is whether OpenRouter re-dates the
   permaslug if xAI moves its alias. `[DOCS SILENT]`
2. **For open-weight models the "lab alias" layer barely exists.** The model is
   served by many providers from published weights. A change behind the slug is
   then a *provider* change, which is sub-question 3.
3. **A lab-side move does not reach the completion `model` field.** The field
   echoes the request. This is inferred from the observed shape and not seen
   during a move. `[NEEDS OBSERVATION]`. Whether it reaches `upstream_id`,
   `system_fingerprint` or anything else is unknown. `[NEEDS OBSERVATION]`

### 2c. Is a move announced anywhere machine-readable?

| channel | what it covers, per its own docs | machine-readable? | covers a slug's re-point or a lab move? |
|---|---|---|---|
| `/api/v1/models`, `canonical_slug` per `id` | "Permanent slug for the model that never changes" | yes, observed | it would show a re-point as a changed `canonical_slug` for an unchanged `id`. That is inferred and never seen. `[NEEDS OBSERVATION]` |
| `/api/v1/models`, `alias_target` | rolling aliases only | yes, observed | rolling aliases only. Not present on any roster slug. |
| `/api/v1/models`, `expiration_date` | "The date after which the model may be removed" (OpenAPI `Model`) | yes. `null` for all eight roster slugs on 2026-11-17 | removal, not re-pointing |
| `/api/v1/models/{author}/{slug}/endpoints` | providers, pricing, quantization, status | yes, observed | the permaslug is embedded in each endpoint's `name` string, so a re-point would presumably show there too. `[NEEDS OBSERVATION]` |
| [API Changelog](https://openrouter.ai/docs/changelog.md) and [its RSS feed](https://openrouter.ai/docs/changelog/rss.xml) | "Changes to the OpenRouter API, generated from the OpenAPI specification on every release" | yes (feed observed: 200, `application/rss+xml`) | **no**. [API Versioning](https://openrouter.ai/docs/api_reference/versioning.md): "Model availability is separate from API versioning: models are added and removed by providers independently." |
| openrouter.ai/announcements | redirects (308) to `/blog`. The blog's feed is `/blog/feed.xml`. | yes (feed observed: 200) | editorial posts. None of the roster slugs or the words `permaslug`/`canonical` appear in the feed as fetched. |
| Activity API (`model`, `model_permaslug`, `endpoint_id` per row, per day) | OpenAPI `ActivityItem`. It distinguishes `model` ("Model slug (e.g., "openai/gpt-4.1")") from `model_permaslug` ("e.g., "openai/gpt-4.1-2025-04-14"") | yes, but authenticated | this account's own traffic would carry the permaslug per day. Not observed, because that needs a key. `[NEEDS OBSERVATION]` |
| Lab channels | Google: email, 2 weeks, `-latest` only. Alibaba: announcements, email, internal messages. MiniMax: a docs-page notice. | not machine-readable as read | only for the lab's own API |

No feed was found that announces a change to which permaslug a slug points at.
Whether one exists unpublished is unknown. `[DOCS SILENT]`

## Sub-question 3: a provider redeploy under an unchanged slug

"Redeploy" here means a provider changes what it serves behind an endpoint, for
example new weights, a new quantization or a new engine, while OpenRouter's slug
and permaslug stay the same.

**Observed: endpoint-level changes under unchanged permaslugs happened between
2026-09-05 and 2026-11-17, and the catalogue shows them.** Compare #27's
`catalogue.json` with the 2026-11-17 `/endpoints` responses, taking only
providers that had exactly one endpoint in both snapshots so that the comparison
is unambiguous:

| slug (permaslug unchanged) | provider | `quantization` 2026-09-05 | `quantization` 2026-11-17 |
|---|---|---|---|
| `moonshotai/kimi-k3` | DeepInfra | `bf16` | `mxfp4` |
| `moonshotai/kimi-k3` | Makora | `unknown` | `fp4` |
| `moonshotai/kimi-k3` | Moonshot AI | `mxfp4` | `unknown` |
| `deepseek/deepseek-v4-flash-0731` | Reka | `fp4` | `unknown` |

Endpoint counts moved as well: Kimi K3 went from 18 to 27, DeepSeek V4 Flash
0731 from 30 to 29, and Grok 4.6 from 5 to 6, the new one being `xai/zdr/us`.
What a changed `quantization` label means is not documented. It could be a
redeploy, a relabelling, or a correction. `[DOCS SILENT]`. So the label changing
is observed, and a redeploy is not.

**Which fields could carry such a change to a single call:**

| field | where | what the docs say | what was observed | carries a redeploy? |
|---|---|---|---|---|
| `model` | completion body | "Model used for completion" | the slug sent, 16 of 16 | **no**, by observed shape: it is the request echoed back |
| `provider` | completion body | not in the OpenAPI `ChatResult` schema (#10's earlier finding, still true of the 2026-11-17 spec) | provider *name*, for example `Baidu`, `xAI`, `Wafer` | names the provider, not the endpoint or the deployment |
| `system_fingerprint` | completion body | "System fingerprint", required, nullable (OpenAPI `ChatResult`) | `null` on 15 of 16. `vllm-dev-ep-8b5ae245` once, from OpenInference (`bodies.json:67`) | possibly, for providers that set it. Whether it changes on redeploy is not seen. `[NEEDS OBSERVATION]` |
| `service_tier` | completion body | "The service tier used by the upstream provider" | `default` for xAI, `null` elsewhere | a tier, not a deployment |
| `openrouter_metadata.endpoints.available[]` | completion body, metadata header only | `{provider, model, selected}` | permaslug per entry, with **no endpoint id**. Two endpoints of one provider cannot be told apart (#27's README). | no endpoint identity, so no |
| `provider_name` | generation record | "Name of the provider that served the request" | `Baidu` | name only |
| `provider_responses[].endpoint_id` | generation record | "Internal endpoint identifier" | `223c54e7-4db1-4098-980f-47741e7637ab` (a UUID; the window file) | identifies the endpoint. Whether it changes when the endpoint is redeployed or relabelled is not seen. `[NEEDS OBSERVATION]` |
| `provider_responses[].model_permaslug` | generation record | "Canonical model slug" | the permaslug | model level, not deployment level |
| `upstream_id` | generation record | "Upstream provider's identifier for this generation" | `as-3fb7j3masu` | per generation, not versioned |
| `tag`, `quantization` | `/endpoints` listing only | endpoint slug shape `provider[/variant][/region][/tier]` ([provider routing](https://openrouter.ai/docs/guides/routing/provider-selection.md)) | changed between snapshots (above) | visible in the catalogue, but **not joinable to a call**: the listing carries no endpoint id, and the completion body carries no tag. Whether `tag` is joinable to the generation's `endpoint_id` is not documented. `[DOCS SILENT]` |

The listing's endpoint records on 2026-11-17 carried these keys:
`context_length, latency_last_30m, max_completion_tokens, max_prompt_tokens,
model_id, model_name, name, native_tools, pricing, provider_name, quantization,
service_tier, status, supported_parameters, supports_diarization,
supports_image_reference, supports_implicit_caching,
supports_multiple_audio_references, supports_tool_choice,
supports_voice_cloning, tag, throughput_last_30m, uptime_last_1d,
uptime_last_30m, uptime_last_5m`. None of them is an id, a version or a
timestamp.

## What the downstream decision turns on

#387 asks how an unrecorded change behind a `ModelNames` value would be
detected. On the evidence above, the answer depends on the following. It is not
answered here.

1. **Which layer of change matters.** There are three, and each leaves a
   different trace:
   - an OpenRouter slug → permaslug re-point. Never observed, and not documented
     as possible.
   - a lab alias move behind the slug. Documented as a lab practice by xAI,
     Google and MiniMax, and invisible in the completion body as far as has been
     observed.
   - a provider-side change behind an endpoint. Observed in the catalogue as
     changed quantization labels.
2. **Whether `model_alias` can serve at all, as specified.** It records the
   completion `model`, and on every captured call that is the request echoed.
   For a slug request it is therefore fixed by the request. It would not differ
   between two rows in which only something behind the slug differed. This rests
   on the observed shape and has not been seen across an actual move.
3. **Whether a permaslug-bearing field is available on the path the call log
   reads.** The permaslug is in `openrouter_metadata` only when the
   `X-OpenRouter-Metadata` header is sent. It is in the generation record, which
   is the planned phase-2 enrichment and is not built
   (`docs/design/llm-call-log.md`). It is in the public catalogue, which is not
   per call.
4. **Whether a permaslug is a fine enough grain.** It names a checkpoint at
   model level. It does not separate providers, endpoints, quantizations or
   deployments. The only per-endpoint identity seen in any per-call record is the
   generation record's `endpoint_id`, and its stability is unobserved.
5. **How often the catalogue would have to be read** to see a change that is
   later reversed. Two snapshots 73 days apart cannot see one.

## What would need to be observed

**Answerable by a completion call on a slug not yet captured:**

1. The completion `model` for the four undated roster slugs with no captured
   body: `google/gemini-3.7-flash`, `minimax/minimax-m3`, `qwen/qwen3.8-27b`,
   `qwen/qwen3.8-2.4t-a95b`. Also for the dated `deepseek/deepseek-v4-pro-0813`.
   The six captured bodies say "echo", which predicts but does not show these.
2. Whether `openrouter_metadata.endpoints.available[].model` holds the permaslug
   for those slugs as well.
3. The generation record's `model` and `provider_responses[].model_permaslug` for
   an **undated** slug. Seen so far only for the dated DeepSeek slug, where both
   were the permaslug.
4. Whether `/chat/completions` reports a **rolling alias** (`~…-latest`) as the
   concrete slug in `model`, as the guide documents for `/responses`.
5. What the completion `model` holds for a **spelling alias**
   (`anthropic/claude-3-5-sonnet`-style): the spelling sent, or the resolved `id`.

**Answerable only by watching across time:**

6. Whether any slug's `canonical_slug` ever changes while its `id` stays the
   same. Repeated `/api/v1/models` snapshots would show it. None has been seen.
7. Whether, during such a change, the completion `model` stays the slug while
   `available[].model` and the generation `model_permaslug` change.
8. Whether `provider_responses[].endpoint_id` changes when an endpoint's
   `quantization` or `tag` changes in the listing.
9. Whether `system_fingerprint`, on a provider that sets it (OpenInference was
   seen to), changes when that provider's endpoint changes.
10. Whether `upstream_id` or any other field shows a lab-side alias move, for
    example when xAI moves `grok-4.6` or MiniMax re-routes a name.
11. Whether the Activity API's per-day `model_permaslug` and `endpoint_id` for
    this account record a change that the completion body does not.

**Not answerable from outside OpenRouter:**

12. Which upstream model id OpenRouter sends to xAI, MiniMax or Moonshot for a
    slug request. Documentation is silent, and no response field read here
    carries it.

## Sources

All URLs were fetched on 2026-11-17. All are first-party: OpenRouter's own
documentation, API and published OpenAPI document, or a lab's own documentation
site.

- OpenRouter, documentation:
  `https://openrouter.ai/docs/llms.txt` (index);
  `https://openrouter.ai/docs/api_reference/models.md`;
  `https://openrouter.ai/docs/guides/overview/models.md`;
  `https://openrouter.ai/docs/guides/features/latest-resolution.md`;
  `https://openrouter.ai/docs/guides/routing/routers/router-metadata.md`;
  `https://openrouter.ai/docs/guides/routing/provider-selection.md`;
  `https://openrouter.ai/docs/guides/routing/model-variants/overview.md`;
  `https://openrouter.ai/docs/api_reference/versioning.md`;
  `https://openrouter.ai/docs/changelog.md` and
  `https://openrouter.ai/docs/changelog/rss.xml`;
  `https://openrouter.ai/blog/feed.xml` (via the `/announcements` redirect)
- OpenRouter, OpenAPI document: `https://openrouter.ai/docs/openapi/openapi.yaml`.
  Schemas `ChatResult`, `OpenRouterMetadata`, `EndpointInfo`,
  `EndpointsMetadata`, `Model`, `ModelAliasTarget`, `GenerationResponse`,
  `ProviderResponse`, `ActivityItem`; paths `/models/{author}/{slug}/endpoints`
  and `/chat/completions`
- OpenRouter, public API (observed, unauthenticated `GET`,
  2026-11-17 08:13:56–08:14:26 UTC): `https://openrouter.ai/api/v1/models`;
  `https://openrouter.ai/api/v1/models/{slug}/endpoints` for the eight roster
  slugs, for `x-ai/grok-4.6-20260810`, and for `~moonshotai/kimi-latest`
- xAI: `https://docs.x.ai/developers/models` (redirected from
  `/docs/models`)
- Google: `https://aistudio.google.com/docs/models` (redirected from
  `ai.google.dev/gemini-api/docs/models`)
- Moonshot: `https://platform.kimi.ai/docs/models.md`
- MiniMax: `https://platform.minimax.io/docs/faq/models.md`
- Alibaba: `https://www.alibabacloud.com/help/en/model-studio/models`;
  `https://www.alibabacloud.com/help/en/model-studio/model-depreciation`
- This repository:
  `docs/eval-reports/2026-09-05-openrouter-body-observations/` (`README.md`,
  `base-1.json`, `hdr-3.json`, `errors.json`, `generation_window.json`);
  `docs/eval-reports/2026-09-05-three-shape-pool-probe/` (`README.md`,
  `bodies.json`, `catalogue.json`); `docs/design/llm-call-log.md`;
  `src/db/models/llm_log.py`; `src/llm_config.py`;
  `scripts/probe_three_shape_pool.py`; `ai_common` at rev `0f0bad2…`
  (`.venv/lib/python3.13/site-packages/ai_common/{enums,llm}.py`)

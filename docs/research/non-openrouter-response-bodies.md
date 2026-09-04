# What a non-OpenRouter completions body actually contains

Research for issue #10 (`wayfinder:research`), under map #6. Read against each
provider's own documentation on 2026-09-04 by the assistant. **No live API call
was made**; this is a reading task, and every claim below is a claim about what
a provider *documents*, not about what the assistant saw a provider *do*.

## Why this file exists, and what it is not

The planned socket patch filters on the completions **path**, not the host
(`docs/design/llm-call-log.md`, "Facts established while charting"). Anything
OpenAI-compatible that lands on `/chat/completions` therefore becomes an
`llm_attempt` row. OpenRouter's body carries `provider`, a `gen-…` id, a cost
and a known usage shape; the design doc asserts of the others only that they
"return no `gen-…` id and, per the section above, often no cost either". This
file fills in the rest of that sentence, column by column, for the servers in
`ai_common.enums.LlmServers`.

**It decides nothing.** What the row should hold, and whether a thin row is
worth writing at all, is explicitly outside issue #10.

### The evidentiary marker

The domain doc's rule — a claim about a layer's behaviour is worth nothing until
the layer has been observed doing it — is the reason for the marker used
throughout:

- **`[NEEDS OBSERVATION]`** — documented, or inferred from documentation, but
  not seen. A later session can grep this marker and get a checklist.
- **`[DOCS SILENT]`** — the provider's documentation does not answer the
  question. A gap recorded as a gap. This is *not* the same as "the field is
  absent"; it means nobody has said either way.

Everything not marked is a direct quotation or a direct reading of a published
schema, with the source named at the point of the claim.

## The finding that reorders the question

Before the six per-server questions, one fact changes what they are worth.

**A path filter on `/chat/completions` would see almost none of this project's
non-OpenRouter traffic as it is wired today.** `ai_common.llm.get_llm` (installed
at `uv.lock` rev `0f0bad2…`, read at `.venv/lib/python3.13/site-packages/ai_common/llm.py`)
builds a *different* client per server, and three of the five do not use the
chat-completions path at all:

| `LlmServers` member | client built by `get_llm` | path that client uses | seen by a `/chat/completions` filter? |
|---|---|---|---|
| `OPENAI` | `ChatOpenAI(..., use_responses_api=True)` | `POST /v1/responses` | **no** `[NEEDS OBSERVATION]` |
| `OLLAMA` | `ChatOllama(base_url="https://ollama.com")` | `POST /api/chat` | **no** `[NEEDS OBSERVATION]` |
| `ANTHROPIC` | `ChatAnthropic` | `POST /v1/messages` | **no** `[NEEDS OBSERVATION]` |
| `GROQ` | `ChatGroq` | `POST /openai/v1/chat/completions` | yes `[NEEDS OBSERVATION]` |
| `VLLM` | — | — | `get_llm` raises `NotImplementedError` for `VLLM` |

The `use_responses_api=True` line is `ai_common/llm.py:174`; the
`base_url="https://ollama.com"` line is `ai_common/llm.py:189`; the `VLLM` case
body is `raise NotImplementedError` at `ai_common/llm.py:213`. Those are facts
about the installed package, read directly. What each *client library* then puts
on the wire is a claim about a library, which is the class of claim that went
wrong on 2026-08-25, so it is marked. (Corroboration, offered as corroboration
and not as evidence: `langchain_openai/chat_models/base.py` calls
`self.root_client.responses.create(...)` on the `use_responses_api` branch, and
OpenAI's own spec puts the Responses API at `POST /v1/responses`
— https://github.com/openai/openai-openapi, `openapi.yaml` v2.3.0, path
`/responses`.)

Two consequences worth stating before the detail:

1. The under-capture the map worries about ("the seam question is about
   **under-capture**, which is silent") has a second source beyond a missed
   patch site: **a correct patch on a correct path can still see nothing**,
   because the caller never uses that path.
2. The bodies documented below are nonetheless the right thing to know. Ollama
   exposes an OpenAI-compatible endpoint alongside its native one, vLLM is
   OpenAI-compatible by construction, Anthropic ships a compatibility layer, and
   `ai_common` could be rewired at any time. The question is "what arrives if it
   arrives", and that is answerable from documentation.

**A discrepancy with the ticket, recorded rather than resolved.** Issue #10
states the enum as five members. The installed package's
`ai_common/enums.py` has **seven**: `ANTHROPIC`, `GOOGLE`, `GROQ`, `OLLAMA`,
`OPENAI`, `OPENROUTER`, `VLLM`. `GOOGLE` is out of this ticket's scope and is
not covered below; it is named here only so a later session does not assume the
enum was exhaustively surveyed.

## Comparison table

Rows are the six questions the ticket asks. "—" means the provider's schema has
no such field; `[DOCS SILENT]` means the documentation does not say.

| | OpenRouter (baseline) | OpenAI `/v1/chat/completions` | OpenAI `/v1/responses` | Groq | Ollama `/api/chat` | Ollama `/v1/chat/completions` | vLLM | Anthropic `/v1/messages` | Anthropic OpenAI-compat |
|---|---|---|---|---|---|---|---|---|---|
| **cost in body** | `usage.cost` | — | — | — | — | `[DOCS SILENT]` | — | — | — |
| **cost retrievable** | `GET /api/v1/generation` → `total_cost` | Admin-key `/organization/costs`, daily buckets, not per call | same | no documented cost API | n/a (local) | n/a | n/a (self-hosted) | no documented cost API | no documented cost API |
| **identifier** | `id`, `gen-…` | `id`, `chatcmpl-…` | `id`, `resp_…` | `id` `chatcmpl-<uuid>` **and** `x_groq.id` `req_…` | none | `[DOCS SILENT]` | `[DOCS SILENT]`; `X-Request-Id` header behind a flag | `id`, `msg_…` | `id` (compat layer) |
| **id retrievable later** | yes | only if `store: true` (default **false**) | yes, `store` defaults **true** | **no endpoint** | n/a | n/a | n/a | no endpoint | no endpoint |
| **reasoning tokens** | `usage.completion_tokens_details.reasoning_tokens` | `usage.completion_tokens_details.reasoning_tokens` | `usage.output_tokens_details.reasoning_tokens` | **not in `usage`**; text in `message.reasoning` | text in `message.thinking`; no token split | `[DOCS SILENT]` | text in `message.reasoning`; token split `[DOCS SILENT]` | `usage.output_tokens_details.thinking_tokens` | `completion_tokens_details` "Always empty" |
| **`served_provider` candidate** | `provider` (observed, see below) | `system_fingerprint` (deprecated), `service_tier` | `service_tier` | `system_fingerprint`, `service_tier`, `x_groq` | — | `[DOCS SILENT]` | `[DOCS SILENT]` | `usage.inference_geo`, `usage.service_tier` | `system_fingerprint` "Always empty" |
| **host** | `openrouter.ai` | `api.openai.com` | `api.openai.com` | `api.groq.com` | `localhost:11434` or `ollama.com` | `localhost:11434` | **arbitrary** | `api.anthropic.com` | `api.anthropic.com` |
| **`finish_reason`** | OpenAI set + `native_finish_reason` | `stop`, `length`, `tool_calls`, `content_filter`, `function_call` | **none** — `status` + `incomplete_details.reason` | `[DOCS SILENT]`; `stop` in the example | `done_reason`: `stop`, `load`, `unload` in examples | `[DOCS SILENT]` | `[DOCS SILENT]` | `stop_reason`, seven values | "Fully supported" |

---

## OpenRouter — the baseline the others are measured against

Included only to make the comparison honest about what is being given up.

- **Cost.** `usage` carries `cost?: number`
  (https://openrouter.ai/docs/api-reference/overview). The generation endpoint
  returns `total_cost`, "Total cost of the generation in USD"
  (https://openrouter.ai/docs/api-reference/get-a-generation).
- **Identifier.** `id`, shaped `gen-xxxxxxxxxxxxxx`, and it is retrievable:
  `GET /api/v1/generation?id=…` returns `provider_name` ("Name of the provider
  that served the request"), `latency`, `generation_time` and
  `native_finish_reason` (same source). **This endpoint is the thing that has no
  counterpart anywhere else in this file except OpenAI's Responses API.**
- **`served_provider`.** The design doc records `provider: Relace` seen in a
  forwarded body (`docs/design/llm-call-log.md` line 205) — an *observation*
  this repository made. The assistant could not find `provider` in OpenRouter's
  documented chat-completion response schema; the published schema at
  https://openrouter.ai/docs/api-reference/overview names `model` and not
  `provider`. So the field the whole `served_provider` column rests on is
  **observed but not documented**, which is the reverse of everything else here
  and is worth knowing before anyone treats the documentation as the authority.

## OpenAI

Two endpoints matter, and this project's configuration uses the second.

### `/v1/chat/completions`

Source: OpenAI's official OpenAPI specification,
https://github.com/openai/openai-openapi, `openapi.yaml` version 2.3.0, fetched
2026-09-04. Schemas `CreateChatCompletionResponse` and `CompletionUsage`.

1. **Cost.** No cost field of any kind. The response object's properties are
   `id`, `choices`, `created`, `model`, `metadata`, `service_tier`,
   `system_fingerprint`, `object`, `usage`, `moderation`. Cost is retrievable
   only in aggregate: `GET /organization/costs` requires an **admin** API key,
   supports `bucket_width` where "Currently only `1d` is supported", and returns
   `CostsResult` objects grouped by `line_item` / `project_id` / `api_key_id`.
   There is no per-generation cost anywhere in the spec. Attributing a daily
   bucket back to one `llm_attempt` row is not possible from that shape.
2. **Identifier.** `id` — "A unique identifier for the chat completion",
   example `chatcmpl-B9MHDbslfkBeAs8l4bebGdFOJ6PeG`. It **is** retrievable, but
   conditionally: `GET /chat/completions/{completion_id}` is documented as "Get
   a stored chat completion. Only Chat Completions that have been created with
   the `store` parameter set to `true` will be returned", and `store` has
   `default: false`. So for a default request the id is a dead letter. The
   response returned by that endpoint is a `CreateChatCompletionResponse` —
   the same body, with no cost and no provider — so even when it works it adds
   nothing the socket did not already have. `[NEEDS OBSERVATION]` whether
   `ai_common` ever sets `store`.
   Separately, `x-request-id` is a response header, "Unique identifier for this
   API request (used in troubleshooting)"
   (https://developers.openai.com/api/reference/overview). It is for support
   lookups; the page describes no endpoint that takes it.
3. **Usage shape.** `prompt_tokens`, `completion_tokens`, `total_tokens`
   (all three required), plus `completion_tokens_details`
   (`accepted_prediction_tokens`, `audio_tokens`, **`reasoning_tokens`**,
   `text_tokens`, `rejected_prediction_tokens`) and `prompt_tokens_details`
   (`audio_tokens`, `cached_tokens`, `text_tokens`, `image_tokens`,
   `cache_write_tokens`). Reasoning tokens are exactly where OpenRouter puts
   them: `usage.completion_tokens_details.reasoning_tokens`, "Tokens generated
   by the model for reasoning."
4. **`served_provider`.** Nothing names a machine or a backend operator. The two
   candidates and why each is not one: `system_fingerprint` is marked
   `deprecated: true` in the spec and describes "the backend configuration that
   the model runs with" — a configuration hash, not a provider name;
   `service_tier` is an enum (`auto`, `default`, `flex`, `scale`, `priority`,
   `fast`) describing *processing type*, and the spec notes the returned value
   "may be different from the value set in the parameter". Both are fields that
   *can* be present and are not provider names, which under the log's own
   doctrine makes `served_provider` genuinely null here rather than
   unreported-but-existing.
5. **Host.** `https://api.openai.com/v1` — the single `servers` entry in the
   spec.
6. **`finish_reason`.** A closed enum: `stop`, `length`, `tool_calls`,
   `content_filter`, `function_call`. This is the set every other
   OpenAI-compatible server is measured against.

### `/v1/responses` — what this project's OpenAI path would actually produce

Same spec. This matters because `get_llm` sets `use_responses_api=True`.

1. **Cost.** None. `[NEEDS OBSERVATION]`, but there is no cost property on the
   `Response` schema.
2. **Identifier.** `id`, "Unique identifier for this Response", example
   `resp_677efb5139a88190b512bc3fef8e535d`. **It is retrievable**:
   `GET /responses/{response_id}` "Retrieves a model response with the given
   ID", and `store` on the create request has `default: true` — "Whether to
   store the generated model response for later retrieval via API." This is the
   only endpoint outside OpenRouter in this file that behaves like OpenRouter's
   generation endpoint: an id that a sweep could take and resolve. What comes
   back is the `Response` object — usage and status, still no cost and still no
   provider.
3. **Usage shape.** A **different vocabulary**: `input_tokens`,
   `input_tokens_details` (`cached_tokens`, `cache_write_tokens`),
   `output_tokens`, `output_tokens_details` (**`reasoning_tokens`**),
   `total_tokens`. Every one of those five is `required`. Nothing is named
   `prompt_tokens` or `completion_tokens`. A reader mapping this onto the
   `llm_attempt` columns is renaming, not copying.
4. **`served_provider`.** `service_tier` only, same objection as above.
5. **Host.** `https://api.openai.com/v1`.
6. **`finish_reason`.** **There is none.** The `Response` object carries
   `status` (`completed`, `failed`, `in_progress`, `cancelled`, `queued`,
   `incomplete`) and `incomplete_details.reason`. A socket reading a Responses
   body for `finish_reason` finds nothing; whatever it should write there is a
   translation decision, and this ticket does not make it.

## Groq

Sources: https://console.groq.com/docs/api-reference (the assistant read the
site's own Markdown export at `…/api-reference.md`),
https://console.groq.com/docs/rate-limits, https://console.groq.com/docs/reasoning.

1. **Cost.** No cost field. The documented Response Object properties are
   `choices`, `created`, `id`, `mcp_list_tools`, `model`, `object`,
   `service_tier`, `system_fingerprint`, `usage`, `usage_breakdown`, `x_groq` —
   and no cost among them. The API reference lists no usage or billing endpoint
   at all: its GET endpoints are `/models`, `/models/{model}`, `/batches`,
   `/batches/{batch_id}`, `/files`, `/files/{file_id}`,
   `/files/{file_id}/content`, `/v1/fine_tunings`, `/v1/fine_tunings/{id}`.
   Cost therefore appears to be dashboard-only. `[DOCS SILENT]` on whether any
   undocumented cost API exists.
2. **Identifier.** Two of them, which is a fact the schema makes easy to miss.
   `id` — "A unique identifier for the chat completion" — is shaped
   `chatcmpl-f51b2cd2-bef7-417e-964e-a08f0b513c22` in the reference's own
   example: the `chatcmpl-` prefix over a UUID rather than OpenAI's opaque
   suffix. And `x_groq`, "Groq-specific metadata for non-streaming chat
   completion responses", contains an id shaped
   `req_01jbd6g2qdfw2adyrt2az8hz4w` in the same example.
   **Neither is retrievable.** There is no `GET /chat/completions/{id}` in the
   reference. The batch endpoints return a *batch*, not one generation by id.
   For the enrichment sweep this is the sharpest result in the file: Groq gives
   the log two identifiers and nowhere to spend them.
3. **Usage shape.** From the reference's example response, verbatim:
   `queue_time`, `prompt_tokens`, `prompt_time`, `completion_tokens`,
   `completion_time`, `total_tokens`, `total_time`. Four timing keys OpenAI does
   not have, and **no `completion_tokens_details` and no `reasoning_tokens`**.
   Reasoning is returned as *text*, not as a token count: for non-GPT-OSS models
   under `reasoning_format: parsed`, "the model's reasoning is separated into a
   dedicated `reasoning` field"; under `raw`, "the reasoning content is
   accessible in the main text content of assistant responses within `<think>`
   tags" (https://console.groq.com/docs/reasoning). So a Groq call that reasoned
   heavily reports a `completion_tokens` that silently includes the reasoning
   and no way to separate it. `[NEEDS OBSERVATION]` — whether a
   `completion_tokens_details` key appears in practice on reasoning models
   despite being undocumented. This is exactly the "null is never zero"
   situation the log was designed for: writing `reasoning_tokens = 0` for a Groq
   row would be an invention.
   The site's Markdown export collapses the "Show properties" expanders, so the
   `usage` sub-schema above is read from the worked example rather than from the
   schema. `[NEEDS OBSERVATION]`.
4. **`served_provider`.** Nothing names a machine. `system_fingerprint` is
   present with the same OpenAI wording (backend configuration, not operator);
   `service_tier` is documented with allowed values `auto, on_demand, flex,
   performance, default, null` and the note "Deployments running in strict
   OpenAI compatibility report Groq-specific tiers as `default`". `x_groq` holds
   only an id in the documented example. Groq runs its own hardware, so there is
   no upstream operator for a `provider` field to name — `served_provider` is
   genuinely null, and null here means the same thing it means for a direct
   OpenAI call.
5. **Host.** `https://api.groq.com/openai/v1/chat/completions`. Note the
   `/openai/v1` prefix: a path filter matching the *suffix* `/chat/completions`
   catches it, one anchored at `/v1/chat/completions` also catches it, one
   anchored at the start of the path does not. `[NEEDS OBSERVATION]` — which
   form the patch uses is not yet written.
6. **`finish_reason`.** `[DOCS SILENT]`. The reference's example shows `"stop"`;
   the allowed-values list is inside a collapsed expander and is not in the
   Markdown export. Given `tool_calls` support and `max_completion_tokens`, more
   values plainly exist. `[NEEDS OBSERVATION]`.

Also present and undocumented in shape: `usage_breakdown`, "Detailed usage
breakdown by model when multiple models are used in the request for compound AI
systems", and `mcp_list_tools`. Neither is reachable by this project's current
configuration, but both are extra top-level keys a strict reader would trip on.

## Ollama — two endpoints, and the path filter tells them apart

Sources: https://docs.ollama.com/openapi.yaml (Ollama's own OpenAPI document),
https://docs.ollama.com/api/chat, https://docs.ollama.com/api/introduction,
https://docs.ollama.com/api/usage, https://docs.ollama.com/api/authentication,
https://docs.ollama.com/api/openai-compatibility, https://docs.ollama.com/cloud.

### `/api/chat` — the native endpoint, and the one `ai_common` uses

The `ChatResponse` schema in Ollama's OpenAPI document has exactly these
properties: `model`, `created_at`, `message` (`role`, `content`, `thinking`,
`tool_calls`, `images`), `done`, `done_reason`, `total_duration`,
`load_duration`, `prompt_eval_count`, `prompt_eval_cached_count`,
`prompt_eval_duration`, `eval_count`, `eval_duration`, `logprobs`.

1. **Cost.** None, and none is retrievable. Nothing in the API charges money
   locally; for cloud models `[DOCS SILENT]` — the cloud page documents
   authentication and model access and says nothing about per-call cost.
2. **Identifier.** **There is no `id` field.** Not a null one — the schema has
   no such property. A `/api/chat` attempt is unidentifiable from its body, and
   there is nothing for an enrichment sweep to key on even in principle.
3. **Usage shape.** No `usage` object at all. The counts are top-level and
   differently named: `prompt_eval_count` "Number of tokens in the prompt",
   `eval_count` "Number of tokens generated in the response",
   `prompt_eval_cached_count` "Number of prompt tokens read from the cache".
   There is no total. Durations are nanoseconds — the API doc states "All
   durations are returned in nanoseconds" — which is a unit trap for any code
   that assumes seconds.
   **Reasoning is text, never a count.** `message.thinking` is "Optional
   deliberate thinking trace when `think` is enabled". Thinking tokens are
   included in `eval_count` with no way to separate them. `[NEEDS OBSERVATION]`
   that they are in fact included; the documentation does not say either way, so
   strictly this is `[DOCS SILENT]`.
4. **`served_provider`.** No candidate field whatsoever. For a local Ollama the
   machine that served the request is the machine that made it; for a cloud
   model the docs say "ollama.com acts as a remote Ollama host" and name no
   backend. Genuinely null.
5. **Host.** `http://localhost:11434/api` locally; "For running cloud models on
   ollama.com, the same API is available with the following base URL:
   `https://ollama.com/api`". The port is a default, not a constant —
   self-hosting means the host is whatever the operator chose.
6. **`finish_reason`.** The field is `done_reason`, described only as "Reason the
   response finished" with **no enum**. Values appearing in the published
   examples: `stop`, `load`, `unload`. `[NEEDS OBSERVATION]` for anything else
   (`length` on a truncated generation is the obvious candidate and is not in
   any example the assistant found).

### `/v1/chat/completions` — the OpenAI-compatible endpoint

This is the one a path filter would catch, and it is the one the documentation
says least about.

The OpenAI-compatibility page confirms the endpoints —
`/v1/chat/completions`, `/v1/completions`, `/v1/models`, `/v1/models/{model}`,
`/v1/embeddings`, `/v1/responses` — at base `http://localhost:11434/v1/`. It
then lists supported *features* and supported *request* fields (`[x] model`,
`[x] messages`, `[x] stream_options.include_usage`, `[ ] logprobs`,
`[ ] tool_choice`, `[ ] logit_bias`, `[ ] user`, `[ ] n`).

**It documents no response field at all.** The `id` shape, the contents of
`usage`, whether `system_fingerprint` is populated, whether
`completion_tokens_details` appears — none of it is stated, and the `/v1` paths
do not appear in Ollama's OpenAPI document either (that document covers only
`/api/*`). This is a documented silence, not an absence, and it is the single
largest gap in this file: **the one Ollama endpoint the path filter can see is
the one whose response body nobody has written down.** `[NEEDS OBSERVATION]`
for every column.

What can be said without observing: `[x] stream_options.include_usage` implies a
`usage` object exists on that endpoint, and `[x] reasoning_effort` /
`[x] reasoning.effort` (`high`, `medium`, `low`, `max`, `none`) implies
reasoning models are reachable through it. Whether reasoning tokens are then
split out is `[DOCS SILENT]`.

### Ollama Cloud

The map's provenance notes say this project has used Ollama Cloud, so it is
covered separately. The documentation gives it **no separate response schema**:
"the same API is available with the following base URL: `https://ollama.com/api`"
and "Cloud models can also be accessed directly on ollama.com's API. In this
mode, ollama.com acts as a remote Ollama host." Authentication is a bearer
`OLLAMA_API_KEY`. Every cloud example in the docs uses `/api/chat` or
`/api/generate`; **no `https://ollama.com/v1/chat/completions` example appears
anywhere in the documentation the assistant read**, and whether that path is
served at all on the cloud host is `[DOCS SILENT]` `[NEEDS OBSERVATION]`.

Ollama Cloud is billed, so a cost exists somewhere; nothing in the API
documentation exposes it. `[DOCS SILENT]`.

## vLLM

Sources: https://docs.vllm.ai/en/latest/serving/online_serving/openai_compatible_server.html,
https://docs.vllm.ai/en/latest/features/reasoning_outputs.html.

vLLM is OpenAI-compatible by construction — the server implements OpenAI's
Completions, Chat Completions, Responses, Embeddings, Transcriptions and
Translation APIs — so the *default* expectation is the OpenAI shape. The docs
document the *deltas*, not the whole body, which means most columns here are
`[DOCS SILENT]` on purpose rather than by omission.

1. **Cost.** None, and the concept does not apply: vLLM is software the operator
   runs on their own hardware. There is no billing surface to retrieve a cost
   from.
2. **Identifier.** `[DOCS SILENT]` on the body's `id`. The documented mechanism
   is a header: the `--enable-request-id-headers` flag makes the server return
   the request id in a header (surfaced by the OpenAI SDK as
   `completion._request_id`). **It is off unless enabled**, and there is no
   endpoint that takes it — vLLM stores nothing. `[NEEDS OBSERVATION]` on both
   the body `id` shape and the header's exact name.
3. **Usage shape.** `[DOCS SILENT]` — presumed OpenAI's, unverified.
   Reasoning is returned as **text in a non-OpenAI field**: `message.reasoning`,
   "contains the reasoning steps that led to the final conclusion". The docs
   explicitly record a rename — "To migrate, directly replace
   `reasoning_content` with `reasoning`. It is important that you also update
   your client code" — so a body from an older vLLM says `reasoning_content` and
   a newer one says `reasoning`, which is a version-dependent divergence a
   parser must tolerate. Whether `usage` splits reasoning tokens out is
   `[DOCS SILENT]`.
4. **`served_provider`.** `[DOCS SILENT]`. No documented field names the
   machine. Since vLLM is self-hosted, "who served it" is answered by the host
   the request went to and by nothing in the body.
5. **Host.** **Arbitrary.** The docs' examples use `http://localhost:8000/v1`
   and `vllm serve <model> --dtype auto --api-key token-abc123`, but that is a
   default, not an identity. A vLLM server can be at any host and port, behind
   any reverse proxy, on any path prefix. See the `llm_server` section below —
   this is the case that breaks host-based derivation.
6. **`finish_reason`.** `[DOCS SILENT]`; presumed the OpenAI set, since vLLM
   claims OpenAI compatibility. `[NEEDS OBSERVATION]`.

Extra request parameters vLLM documents (`prompt_logprobs`, `logprob_token_ids`,
`kv_transfer_params`, `ec_transfer_params`, `cache_salt`, `return_token_ids`,
`session_id`) imply corresponding extra response keys on some paths.
`[NEEDS OBSERVATION]` — the assistant did not establish which of these echo back
into the response body.

## Anthropic — and whether the filter would see it at all

This is the case the ticket predicted, and the prediction holds.

### The native Messages API is not a `/chat/completions` endpoint

Source: https://platform.claude.com/docs/en/api/messages.

The endpoint is `POST /v1/messages`. **A path filter on `/chat/completions`
never sees it.** So a `ChatAnthropic` call made through `ai_common` today
produces no `llm_attempt` row, and it does not produce a *wrong* row either — it
produces silence, which is the under-capture failure mode the map names.

For completeness, since the body is the richest of the non-OpenRouter set:

1. **Cost.** None in the body; no documented per-call cost endpoint.
2. **Identifier.** `id`, "Unique object identifier. The format and length of IDs
   may change over time" — the docs decline to promise a shape, though the
   worked example is `msg_013Zva2CMHLNnXjNJJKqJ2EF`. **Not retrievable**: the
   Messages API is stateless and the assistant found no endpoint that resolves a
   message id.
3. **Usage shape.** Different again: `input_tokens`, `output_tokens`,
   `cache_creation_input_tokens`, `cache_read_input_tokens`, `cache_creation`
   (`ephemeral_1h_input_tokens`, `ephemeral_5m_input_tokens`),
   `server_tool_use` (`web_fetch_requests`, `web_search_requests`),
   `service_tier`, `inference_geo`, and `output_tokens_details` with
   **`thinking_tokens`** — "Number of output tokens the model generated as
   internal reasoning, including the thinking-block delimiter tokens". Note the
   key is `thinking_tokens`, not `reasoning_tokens`, and it sits under
   `output_tokens_details`, not `completion_tokens_details`. Note also
   "Total input tokens in a request is the summation of `input_tokens`,
   `cache_creation_input_tokens`, and `cache_read_input_tokens`" — so
   `input_tokens` alone is *not* the prompt total, which is a trap for anything
   copying it into `prompt_tokens`.
4. **`served_provider`.** The one genuine candidate anywhere outside OpenRouter:
   `usage.inference_geo`, "The geographic region where inference was performed
   for this request". It names a *region*, not an operator, so it is not the
   same quantity as OpenRouter's `provider` — but it is a field, it can be
   `null`, and under the log's doctrine "no field" and "a field that can be
   empty" are different findings. This is the second kind.
5. **Host.** `https://api.anthropic.com`.
6. **`stop_reason`** (not `finish_reason`): `end_turn`, `max_tokens`,
   `stop_sequence`, `tool_use`, `pause_turn`, `refusal`,
   `model_context_window_exceeded`. Seven values, sharing **none** of its
   spelling with OpenAI's five. "In non-streaming mode this value is always
   non-null."

### Anthropic does ship an OpenAI-compatibility endpoint

Source: https://platform.claude.com/docs/en/cli-sdks-libraries/libraries/openai-sdk.

It exists, at base URL `https://api.anthropic.com/v1/`, and the OpenAI SDK's
`chat.completions.create` works against it — so `POST /v1/chat/completions` on
`api.anthropic.com` is a real path that a path filter **would** catch. Anthropic
frames it narrowly: "This compatibility layer is primarily intended to test and
compare model capabilities, and is not considered a long-term or production-ready
solution for most use cases."

Its response table is unusually explicit about what is hollow, and this is the
best-documented set of nulls in the whole file:

- `usage.prompt_tokens`, `usage.completion_tokens`, `usage.total_tokens` —
  "Fully supported".
- `usage.completion_tokens_details` — **"Always empty"**. So
  `reasoning_tokens` is unavailable through the compat layer even for a thinking
  model, and the docs say so directly: "the OpenAI SDK doesn't return Claude's
  detailed thought process."
- `usage.prompt_tokens_details` — "Always empty".
- `system_fingerprint` — **"Always empty"**. So the `served_provider` candidate
  that exists on OpenAI and Groq is present-but-empty here.
- `service_tier` — "Always empty"; `logprobs` — "Always empty".
- `id`, `object`, `created`, `model`, `choices[].finish_reason` — "Fully
  supported".
- `choices[]` — "Will always have a length of 1".
- Headers: `request-id` — "Fully supported"; `openai-version` — "Always
  `2020-10-01`"; `openai-processing-ms` — "Always empty".

`usage.inference_geo` — the one field that could have carried a
`served_provider` — is **not in the compat layer's response table at all**.
The richer native body is not reachable through the OpenAI-compatible path.

No cost field; no retrieval endpoint for the id. `[NEEDS OBSERVATION]` on
whether the compat layer's `id` keeps the `msg_` prefix or is rewritten to
`chatcmpl-`; the table says `id` is "Fully supported" and says nothing about its
shape.

## `llm_server`: what the socket can actually derive

The design's departure 3b puts `llm_server` on `llm_attempt` because the sweep's
filter needs it, and states that "The socket knows it from the request URL". The
per-server hosts above say how far that holds.

| server | host(s) the documentation gives | host alone a sound discriminator? |
|---|---|---|
| OpenRouter | `openrouter.ai` | yes |
| OpenAI | `api.openai.com` | yes |
| Groq | `api.groq.com` | yes |
| Anthropic | `api.anthropic.com` | yes (and the path separates native from compat) |
| Ollama | `localhost:11434` **or** `ollama.com` | **one server, two hosts** |
| vLLM | anything | **no** |

Three findings, stated as facts and not as recommendations:

1. **For the four hosted providers, host is sound and path is not.** Groq serves
   `/openai/v1/chat/completions`; Anthropic serves both `/v1/messages` and
   `/v1/chat/completions` on the same host; OpenAI serves `/v1/responses` and
   `/v1/chat/completions` on the same host. Path distinguishes *endpoints*, host
   distinguishes *servers*, and the filter is currently on the former.
2. **Ollama's `llm_server` is one value spanning two hosts** — `localhost:11434`
   and `ollama.com` — and the difference between them is the difference between
   a free local call and a billed cloud call. A host-to-`llm_server` map that
   sends both to `'ollama'` is correct per `LlmServers` and simultaneously
   erases the only distinction that has a cost attached. Whether that matters is
   a decision, and this ticket does not make it.
3. **vLLM cannot be derived from a host, ever.** It is self-hosted at an
   operator-chosen address; the same address could be an OpenAI proxy, a
   LiteLLM gateway, or anything else that speaks the protocol. Any mapping from
   host to `LlmServers.VLLM` is a local configuration fact, not a property of
   the wire — which means the socket cannot know it and something else must tell
   it. The same argument applies to a self-hosted Ollama on a non-default port.

A fourth, from the top of this file: for three of the five servers the question
is currently moot, because the client `ai_common` builds does not use the
completions path at all. `[NEEDS OBSERVATION]`.

## What would need to be observed

A checklist for the session that gets to make live calls. Each line is a claim
above that documentation could not settle.

**Highest value — these change what the row can hold:**

1. **Ollama's `/v1/chat/completions` response body, in full.** Documented
   nowhere. This is the one Ollama endpoint the path filter can see. Capture:
   `id` shape, `usage` keys, `system_fingerprint`, `finish_reason`,
   `completion_tokens_details`.
2. **A Groq reasoning-model call**, checking whether `usage` gains a
   `completion_tokens_details` / `reasoning_tokens` key despite the reference
   not documenting one. If it does not, every Groq `reasoning_tokens` is null,
   permanently, and `completion_tokens` silently includes reasoning.
3. **Which path `ChatOpenAI(use_responses_api=True)` actually puts on the
   wire.** If `/v1/responses`, the path filter sees no OpenAI traffic and the
   Responses usage vocabulary (`input_tokens` / `output_tokens_details`) is what
   any future capture must read.
4. **Which path `ChatOllama(base_url="https://ollama.com")` puts on the wire** —
   `/api/chat` per the Ollama docs, but this is a library claim.
5. **Whether `https://ollama.com/v1/chat/completions` is served at all.** The
   cloud documentation only ever shows `/api/*`.

**Confirmations of documented behaviour:**

6. Groq's `finish_reason` value set beyond `stop` — the allowed-values list is
   behind a collapsed expander in the published reference.
7. Groq's `usage` sub-schema as *schema* rather than as worked example, and
   whether `x_groq` ever carries more than `id`.
8. Ollama's `done_reason` beyond `stop` / `load` / `unload` — in particular what
   a length-truncated generation returns.
9. Whether Ollama's `eval_count` includes `thinking` tokens.
10. vLLM's chat-completion `id` shape, `usage` keys and `finish_reason` set, and
    which vLLM version renamed `reasoning_content` to `reasoning`.
11. The exact header name vLLM emits under `--enable-request-id-headers`.
12. Whether Anthropic's compat layer keeps `msg_` in `id` or rewrites it.
13. Whether OpenAI's `system_fingerprint` is still populated at all, given the
    spec now marks it `deprecated: true`.

**Only observation can settle these — documentation is structurally unable to:**

14. Whether `provider` is present in OpenRouter chat-completion bodies as a
    matter of course. The repository has seen it (`llm-call-log.md` line 205);
    OpenRouter's published schema does not list it. The column that carries
    `served_provider` rests on an undocumented field.

## Sources

Every URL below was fetched on 2026-09-04. All are first-party: a provider's own
documentation site or its own published OpenAPI document.

- OpenAI — `https://github.com/openai/openai-openapi` (`openapi.yaml`, v2.3.0);
  `https://developers.openai.com/api/reference/overview`
- Groq — `https://console.groq.com/docs/api-reference`;
  `https://console.groq.com/docs/rate-limits`;
  `https://console.groq.com/docs/reasoning`
- Ollama — `https://docs.ollama.com/openapi.yaml`;
  `https://docs.ollama.com/api/chat`; `https://docs.ollama.com/api/introduction`;
  `https://docs.ollama.com/api/usage`;
  `https://docs.ollama.com/api/authentication`;
  `https://docs.ollama.com/api/openai-compatibility`;
  `https://docs.ollama.com/cloud`
- vLLM — `https://docs.vllm.ai/en/latest/serving/online_serving/openai_compatible_server.html`;
  `https://docs.vllm.ai/en/latest/features/reasoning_outputs.html`
- Anthropic — `https://platform.claude.com/docs/en/api/messages`;
  `https://platform.claude.com/docs/en/cli-sdks-libraries/libraries/openai-sdk`
- OpenRouter — `https://openrouter.ai/docs/api-reference/overview`;
  `https://openrouter.ai/docs/api-reference/get-a-generation`
- This repository — `docs/design/llm-call-log.md`;
  `src/db/models/llm_log.py`; `ai_common` at `uv.lock` rev `0f0bad2…`
  (`.venv/lib/python3.13/site-packages/ai_common/{enums,llm}.py`)

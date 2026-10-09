"""
Does the request *shape* narrow the candidate pool, and by how much per model?

[#20](https://github.com/bgunyel/clause-and-effect/issues/20) settled that the
pool goes on the attempt row near-verbatim because it is **not derivable from
the catalogue**: all 30 of DeepSeek V4 Flash's endpoints declare `tools` and
`tool_choice` in `supported_parameters`, yet binding a tool drops seven
providers. [#27](https://github.com/bgunyel/clause-and-effect/issues/27) is the
run that measures the `json_schema` pool rather than inferring it from the same
source that has just been wrong by seven on the only cell that can be checked.

**Nine calls, fixed in advance.** Three shapes × three models, header on,
identical prompt, one call per cell.

| shape | what it binds |
|---|---|
| `plain` | no tools, no `response_format` |
| `function_calling` | `with_structured_output()`, `tool_choice` pinned |
| `json_schema` | `with_structured_output(method="json_schema")` |

| model | why it is in |
|---|---|
| `deepseek/deepseek-v4-flash-0731` | already has 29 and 23 as anchors (#13) |
| `moonshotai/kimi-k3` | a live `json_schema` panelist with a pool large enough to narrow visibly |
| `x-ai/grok-4.6` | the small-pool stress case; a zero would be the first structurally untestable cell |

**A single-model three-shape probe is the only thing that separates channel from
model.** `llm_config`'s roster assigns a channel *per model*, so the two are
confounded by construction; this probe overrides `structured_output` on a copy
of each roster entry, which is the whole point and the one place a probe is
allowed to depart from the roster's assignment.

**The reading rule, registered here before the run** — #22's degenerate-outcome
lesson in a new place:

> **Equal pool sizes are not the same pool.** The comparison that matters is set
> membership. At one call per cell a null result is *no difference observed at
> n=1*, not *no difference*.

Sharpened by what the dumps actually contain: #13's DeepSeek pool is 23 entries
over 22 distinct providers because **`BaseTen` appears twice with a byte-identical
entry**. Entries are `{provider, model, selected}` and carry no endpoint id, so
two endpoints of one provider are indistinguishable within a pool. Membership is
therefore compared as a **multiset over providers**, never as a set — a set
comparison would silently equate a pool that lost one BaseTen endpoint with one
that lost none.

**No pre-registration entry.** #22's norm bites where a rule would otherwise be
written with the numbers in hand — a threshold, a stopping rule, a selection
surface. This probe has none: the outcome is a count and a membership list per
cell, not a comparison against a bar, and there is nothing to stop early or
extend. #20 §3b removed the only reason it would have gone there, since no pool
figure is registered as a denominator — denominators come per attempt.

**What each cell records**, both requirements following from #20's findings:

- **The full `available` list, never the size.** Size is what hid the duplicate
  `BaseTen`.
- **Endpoint count and distinct-provider count as separate numbers.** They
  differ, and which one is meant has already been an unstated assumption once.

Plus `endpoints.total`, `strategy`, `attempt` and the selected provider, so the
dumps are readable beside #13's.

**The shape is asserted against the wire, not against the builder.** A cell whose
request body does not carry what its shape name claims is reported
`PRECONDITION FAILED` and its pool is not compared — the same discipline
`probe_wire_params` applies for the same reason: `with_structured_output` is a
library call, and what it puts on the wire is the measurement.

Run:

    uv run python -m scripts.probe_three_shape_pool --smoke   # wiring, discarded
    uv run python -m scripts.probe_three_shape_pool           # the registered run

(A path invocation fails — `scripts/` lands on `sys.path` instead of the repo
root, and `pythonpath` in `pyproject.toml` is pytest-only.)
"""
from __future__ import annotations

import argparse
import asyncio
import json
import logging
import os
import time
from collections import Counter
from contextlib import contextmanager
from dataclasses import dataclass, field
from typing import Any, Dict, Iterator, List, Optional

import httpx
from pydantic import BaseModel, Field

from src.llm.channels import FUNCTION_CALLING, JSON_SCHEMA
from src.llm.structured import build_structured_llm
from src.llm_config import get_llm_config, panelist
from src.logging_setup import setup_logging

logger = logging.getLogger(__name__)

HEADER_NAME = "X-OpenRouter-Metadata"
HEADER_VALUE = "enabled"

# The three shapes. `PLAIN` is not a channel in `src.llm.channels` and must not
# become one — it is the *absence* of a structured-output channel, which is a
# request shape this repository never sends in anger. It exists here only as the
# unbound baseline the other two are measured against.
PLAIN = "plain"
SHAPES = (PLAIN, FUNCTION_CALLING, JSON_SCHEMA)

# Generous on purpose. `llm_config` records DeepSeek V4 Flash timing out under
# `response_format` at a 63s mean, and that cell is one of the nine. A timeout
# there would lose the pool, which is the one thing this probe exists to read;
# the call being slow is not a result this probe is measuring.
CALL_TIMEOUT_SECONDS = 180

_ERROR_CHARS = 300

# Redacted before anything is written, by value, with the key preserved.
# `docs/eval-reports/` is public and is read by people evaluating the work.
#
# **`set-cookie` is here because credential-shaped is not the only shape that
# matters.** #29 resolved that the published bodies also carry *account-scoped*
# fields — Cloudflare's `__cf_bm` in `set-cookie`, and `workspace_id`/`user_id`
# in the generation record — none of them a credential, all of them identifying
# the account rather than the observation. This probe's first run predated that
# and published nine `__cf_bm` values; they were redacted after the fact and the
# list corrected here so a rerun never writes one.
#
# `cf-ray` and `x-generation-id` are deliberately **not** redacted: the first is
# a per-request trace id and the second is the observation's own identity, which
# #13 relies on to resolve a call at the generation endpoint. Redacting evidence
# because it looks like an identifier is the opposite failure.
_SENSITIVE_HEADERS = {
    "authorization",
    "api-key",
    "x-api-key",
    "cookie",
    "set-cookie",
}


class _Answer(BaseModel):
    """One field, deliberately trivial. #13 used the same question, so a body
    from this run is readable beside one from that one; and a schema with any
    real content would make the prompt a source of variance across nine cells
    whose only intended difference is the shape."""

    city: str = Field(description="the city named in the question")


_PROMPT = "Which city is the capital of Türkiye? Answer with the city name only."


# ---------------------------------------------------------------------------
# The wire
# ---------------------------------------------------------------------------


@dataclass
class Send:
    """One HTTP request/response pair as it crossed the socket."""

    url: str
    request_headers: Dict[str, str]
    request_body: Optional[Dict[str, Any]]
    sent_header: bool
    status: int
    response_headers: Dict[str, str]
    response_body: Optional[Dict[str, Any]]
    seconds: float


@dataclass
class Cell:
    """One (model, shape) call, and everything the socket saw while it ran.

    `model` is the roster's `ModelNames` member stringified — `llm_config` stores
    the enum, not the OpenRouter id — so it reads
    `ModelNames.DEEPSEEK_V_4_FLASH_0731`. The id the request actually carried is
    :meth:`wire_model`, read back off the wire rather than mapped, because the
    enum→id mapping lives in `ai_common.llm` and resolving it here would import
    the 6.58s leg this repository keeps out of the graph. Both are reported: the
    enum names the roster entry, the wire id names what OpenRouter was asked for,
    and #13's anchors are stated in the wire id.
    """

    model: str
    shape: str
    status: str
    detail: str = ""
    seconds: float = 0.0
    sends: List[Send] = field(default_factory=list)

    @property
    def short_model(self) -> str:
        return self.model.split(".", 1)[-1]

    @property
    def wire_model(self) -> Optional[str]:
        for send in self.sends:
            body = send.request_body or {}
            if body.get("model"):
                return str(body["model"])
        return None

    @property
    def label(self) -> str:
        return f"{self.short_model}::{self.shape}"

    @property
    def first(self) -> Optional[Send]:
        return self.sends[0] if self.sends else None


def _redact(headers: Any) -> Dict[str, str]:
    out: Dict[str, str] = {}
    for key, value in headers.items():
        out[key] = "<redacted>" if key.lower() in _SENSITIVE_HEADERS else value
    return out


@contextmanager
def wire() -> Iterator[List[Send]]:
    """
    Patch `httpx.AsyncClient.send` to inject the header and keep both bodies.

    The predicate is exact host + path, matching the seam #15 settled on rather
    than `probe_header_ab`'s — there is nothing to gain here from the looser
    form, and two probes disagreeing about what an OpenRouter completion *is*
    would be a difference nobody chose.

    `plain httpx` is the right distribution: #15 measured that
    `langchain_openrouter` → `openrouter` 0.11.46 imports it, while `openai` and
    `anthropic` are on `httpx2`. All three models here are served through
    OpenRouter, so this patch sees every call the probe makes.
    """
    seen: List[Send] = []
    original = httpx.AsyncClient.send

    async def timed(self, request, *args, **kwargs):  # type: ignore[no-untyped-def]
        if not (
            request.url.host == "openrouter.ai"
            and request.url.path == "/api/v1/chat/completions"
        ):
            return await original(self, request, *args, **kwargs)

        request.headers[HEADER_NAME] = HEADER_VALUE

        try:
            request_body = json.loads(request.content or b"{}")
        except Exception:  # noqa: BLE001 — an unreadable request is a result
            request_body = None

        started = time.perf_counter()
        response = await original(self, request, *args, **kwargs)
        elapsed = time.perf_counter() - started

        response_body: Optional[Dict[str, Any]] = None
        try:
            await response.aread()
            response_body = json.loads(response.content)
        except Exception:  # noqa: BLE001 — an unreadable body is a result
            response_body = None

        seen.append(
            Send(
                url=str(request.url),
                request_headers=_redact(request.headers),
                request_body=request_body,
                sent_header=HEADER_NAME.lower()
                in {k.lower() for k in request.headers.keys()},
                status=response.status_code,
                response_headers=_redact(response.headers),
                response_body=response_body,
                seconds=elapsed,
            )
        )
        return response

    httpx.AsyncClient.send = timed  # type: ignore[method-assign]
    try:
        yield seen
    finally:
        httpx.AsyncClient.send = original  # type: ignore[method-assign]


# ---------------------------------------------------------------------------
# Reading one response body
# ---------------------------------------------------------------------------


def endpoints_block(body: Optional[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    if not isinstance(body, dict):
        return None
    meta = body.get("openrouter_metadata")
    if not isinstance(meta, dict):
        return None
    block = meta.get("endpoints")
    return block if isinstance(block, dict) else None


def available(body: Optional[Dict[str, Any]]) -> Optional[List[Dict[str, Any]]]:
    """The full list, verbatim. Never a size, never a name list.

    Returns `None` when the block is absent, which is not the same as an empty
    pool — *null means the provider did not report it, and null is never zero*.
    An empty list, if one is ever observed, is the denominator-zero case #20 §3b
    named and nothing has yet instantiated.
    """
    block = endpoints_block(body)
    if block is None:
        return None
    entries = block.get("available")
    return entries if isinstance(entries, list) else None


def endpoints_total(body: Optional[Dict[str, Any]]) -> Optional[int]:
    block = endpoints_block(body)
    if block is None:
        return None
    value = block.get("total")
    return None if value is None else int(value)


def meta_field(body: Optional[Dict[str, Any]], key: str) -> Any:
    if not isinstance(body, dict):
        return None
    meta = body.get("openrouter_metadata")
    if not isinstance(meta, dict):
        return None
    return meta.get(key)


def selected_provider(body: Optional[Dict[str, Any]]) -> Optional[str]:
    """`available[selected].provider` — #14's registered first precedence."""
    for entry in available(body) or []:
        if isinstance(entry, dict) and entry.get("selected"):
            return entry.get("provider")
    return None


def provider_multiset(entries: Optional[List[Dict[str, Any]]]) -> Optional[Counter]:
    """Providers with multiplicity.

    A `Counter` and not a `set`, for the reason the module docstring gives: two
    endpoints of one provider are byte-identical inside `available`, so a set
    would equate a pool that lost one of a provider's two endpoints with one
    that lost neither. #13's DeepSeek pool is the live instance — 23 entries, 22
    providers, `BaseTen` twice.
    """
    if entries is None:
        return None
    return Counter(
        str(e.get("provider")) for e in entries if isinstance(e, dict)
    )


def permaslugs(entries: Optional[List[Dict[str, Any]]]) -> Optional[List[str]]:
    if entries is None:
        return None
    return sorted({str(e.get("model")) for e in entries if isinstance(e, dict)})


def finish_reasons(body: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    if not isinstance(body, dict):
        return {}
    choices = body.get("choices")
    if not isinstance(choices, list) or not choices:
        return {}
    first = choices[0]
    if not isinstance(first, dict):
        return {}
    return {
        "finish_reason": first.get("finish_reason"),
        "native_finish_reason": first.get("native_finish_reason"),
    }


def call_cost(body: Optional[Dict[str, Any]]) -> Optional[float]:
    if not isinstance(body, dict):
        return None
    usage = body.get("usage")
    if not isinstance(usage, dict):
        return None
    value = usage.get("cost")
    return None if value is None else float(value)


# ---------------------------------------------------------------------------
# The precondition: did the shape reach the wire
# ---------------------------------------------------------------------------


def shape_on_wire(request_body: Optional[Dict[str, Any]]) -> Dict[str, bool]:
    body = request_body or {}
    return {
        "tools": bool(body.get("tools")),
        "tool_choice": body.get("tool_choice") is not None,
        "response_format": body.get("response_format") is not None,
    }


def precondition(shape: str, request_body: Optional[Dict[str, Any]]) -> Optional[str]:
    """`None` when the wire matches the shape's name, else why it does not.

    The pool is a function of the request, so a cell whose request is not the
    shape it is labelled measures a shape nobody chose, and reporting its pool
    under that label is the failure this check exists to prevent.
    """
    if request_body is None:
        return "no request body was captured"

    seen = shape_on_wire(request_body)

    if shape == PLAIN:
        if seen["tools"] or seen["response_format"]:
            return f"plain must bind neither; wire has {seen}"
        return None

    if shape == FUNCTION_CALLING:
        if not seen["tools"]:
            return f"function_calling must send tools; wire has {seen}"
        if seen["response_format"]:
            return f"function_calling must not send response_format; wire has {seen}"
        return None

    if shape == JSON_SCHEMA:
        if not seen["response_format"]:
            return f"json_schema must send response_format; wire has {seen}"
        if seen["tools"]:
            return f"json_schema must not send tools; wire has {seen}"
        return None

    return f"unknown shape {shape!r}"


# ---------------------------------------------------------------------------
# One call
# ---------------------------------------------------------------------------


async def one_call(entry: Dict[str, Any], shape: str, seen: List[Send]) -> Cell:
    """Send one cell and keep what the socket saw.

    `entry` is a **copy** whose `structured_output` this function overrides. That
    override is the probe's whole reason to exist — the roster confounds channel
    with model — and it is why `panelist()` is still used to fetch the entry: the
    sampling, the `provider` block and the api key must stay the roster's, so
    that the shape is the only thing that moved.
    """
    model = str(entry["model"])
    cell = Cell(model=model, shape=shape, status="OK")
    seen.clear()
    started = time.perf_counter()

    try:
        if shape == PLAIN:
            # Deferred exactly as `build_structured_llm` defers it, and for the
            # same reason: this is the line that costs langchain → transformers
            # → torch.
            from ai_common import get_llm

            llm = get_llm(
                model_name=entry["model"],
                model_provider=entry["model_provider"],
                api_key=entry["api_key"],
                # A fresh copy — `get_llm` does not read this dict, it empties
                # it. Nine cells share one roster entry, so without the copy
                # only the first would get the configured sampling.
                model_args=dict(entry["model_args"]),
            )
            runnable = llm
        else:
            runnable = build_structured_llm({**entry, "structured_output": shape}, _Answer)

        await asyncio.wait_for(runnable.ainvoke(_PROMPT), timeout=CALL_TIMEOUT_SECONDS)
    except asyncio.TimeoutError:
        cell.status = "TIMEOUT"
        cell.detail = f"no response within {CALL_TIMEOUT_SECONDS}s"
    except Exception as exc:  # noqa: BLE001 — a provider error is a result here
        cell.status = "ERROR"
        cell.detail = f"{type(exc).__name__}: {str(exc)[:_ERROR_CHARS]}"

    cell.seconds = time.perf_counter() - started
    cell.sends = list(seen)
    return cell


# ---------------------------------------------------------------------------
# The report
# ---------------------------------------------------------------------------

_RULE = (
    "REGISTERED READING RULE (written before the run, #27)\n"
    "  Equal pool sizes are not the same pool. The comparison that matters is\n"
    "  set membership -- as a MULTISET over providers, since two endpoints of\n"
    "  one provider are byte-identical inside `available`. At one call per cell\n"
    "  a null result is *no difference observed at n=1*, not *no difference*."
)


def cell_summary(cell: Cell) -> Dict[str, Any]:
    """Everything #27 asks a cell to record, and nothing derived away."""
    send = cell.first
    body = send.response_body if send else None
    entries = available(body)
    multiset = provider_multiset(entries)

    return {
        "model": cell.model,
        "wire_model": cell.wire_model,
        "shape": cell.shape,
        "call_status": cell.status,
        "detail": cell.detail,
        "sends": len(cell.sends),
        "http_status": send.status if send else None,
        "wire_seconds": round(send.seconds, 3) if send else None,
        "call_seconds": round(cell.seconds, 3),
        "sent_header": send.sent_header if send else None,
        "precondition": precondition(cell.shape, send.request_body if send else None),
        "shape_on_wire": shape_on_wire(send.request_body if send else None),
        "endpoints_total": endpoints_total(body),
        # The full list, verbatim. This is the point of the ticket.
        "available": entries,
        # Endpoint count and distinct-provider count, as separate numbers.
        "endpoint_count": None if entries is None else len(entries),
        "distinct_provider_count": None if multiset is None else len(multiset),
        "provider_multiset": None if multiset is None else dict(sorted(multiset.items())),
        "permaslugs": permaslugs(entries),
        "selected_provider": selected_provider(body),
        "strategy": meta_field(body, "strategy"),
        "attempt": meta_field(body, "attempt"),
        "generation_id": body.get("id") if isinstance(body, dict) else None,
        "finish": finish_reasons(body),
        "cost": call_cost(body),
    }


def build_report(cells: List[Cell], smoke: bool) -> str:
    lines: List[str] = []
    out = lines.append

    out("=" * 96)
    out("The three-shape pool probe -- separating the channel confound from the model")
    out("=" * 96)
    if smoke:
        out("SMOKE RUN -- wiring only. Discarded, never pooled with the registered run.")
        out("")
    out(_RULE)
    out("")

    summaries = [cell_summary(c) for c in cells]
    by_key = {(s["model"], s["shape"]): s for s in summaries}
    models = list(dict.fromkeys(s["model"] for s in summaries))

    def short(s: Dict[str, Any]) -> str:
        return str(s["model"]).split(".", 1)[-1]

    # --- the grid ------------------------------------------------------------
    out("Nine cells")
    out(f"  {'model (roster enum)':<28} {'wire id':<32} {'shape':<18} {'st':>4} "
        f"{'total':>6} {'endp':>5} {'prov':>5}  selected")
    for s in summaries:
        out(f"  {short(s):<28} {str(s['wire_model']):<32} {s['shape']:<18} "
            f"{str(s['http_status'] or s['call_status'])[:4]:>4} "
            f"{str(s['endpoints_total']):>6} {str(s['endpoint_count']):>5} "
            f"{str(s['distinct_provider_count']):>5}  {s['selected_provider']}")
    out("")

    # --- preconditions -------------------------------------------------------
    out("Precondition -- the shape reached the wire")
    failures = [s for s in summaries if s["precondition"] is not None]
    for s in summaries:
        verdict = s["precondition"] or "ok"
        out(f"  {short(s):<28} {s['shape']:<18} {verdict}")
    if failures:
        out("  PRECONDITION FAILED on the cells above; their pools are not compared.")
    out("")

    # --- the #13 anchors -----------------------------------------------------
    #
    # Matched on the **wire id**, not on the roster enum. #13 recorded
    # `deepseek/deepseek-v4-flash-0731`, which is what OpenRouter was asked for;
    # the roster names the same model `ModelNames.DEEPSEEK_V_4_FLASH_0731`, and
    # keying the anchor on the enum silently found nothing on the first run of
    # this probe — a lookup that misses must not read as "not run".
    out("Anchors -- the two cells #13 already measured (2026-09-05, n=1 each)")
    ANCHOR_WIRE_ID = "deepseek/deepseek-v4-flash-0731"
    anchors = {s["shape"]: s for s in summaries if s["wire_model"] == ANCHOR_WIRE_ID}
    if not anchors:
        out(f"  no cell carried wire id {ANCHOR_WIRE_ID!r}; nothing to anchor "
            f"against. Wire ids seen: "
            f"{sorted({str(s['wire_model']) for s in summaries})}")
    for shape, expected_endpoints, expected_providers in (
        (PLAIN, 29, 28),
        (FUNCTION_CALLING, 23, 22),
    ):
        s = anchors.get(shape)
        if s is None:
            out(f"  {shape:<18} not run")
            continue
        got, got_p = s["endpoint_count"], s["distinct_provider_count"]
        mark = "reproduced" if got == expected_endpoints else "DIVERGED"
        out(f"  {shape:<18} #13 saw {expected_endpoints} endpoints, this run saw "
            f"{got}  -> {mark}")
        out(f"  {'':<18} distinct providers: expected {expected_providers}, "
            f"this run saw {got_p}")
    out("  #13 published only sizes, so the anchor is a size check and cannot be")
    out("  a membership check -- which is the defect this probe exists to not repeat.")
    out("  A divergence here would be a finding about pool stability over time, not")
    out("  a wiring fault -- the pool is OpenRouter's and moves without us.")
    out("")

    # --- per-model membership comparison -------------------------------------
    out("Per-model membership -- the comparison the rule says is the one that matters")
    for model in models:
        wire_ids = sorted(
            {str(s["wire_model"]) for s in summaries if s["model"] == model}
        )
        out(f"  {str(model).split('.', 1)[-1]}  ({', '.join(wire_ids)})")
        cells_for_model = {
            shape: by_key.get((model, shape)) for shape in SHAPES
        }
        usable = {
            shape: s for shape, s in cells_for_model.items()
            if s is not None and s["precondition"] is None and s["provider_multiset"]
            is not None
        }
        for shape in SHAPES:
            s = cells_for_model.get(shape)
            if s is None:
                out(f"    {shape:<18} not run")
            elif s["provider_multiset"] is None:
                out(f"    {shape:<18} no pool observed "
                    f"({s['call_status']} {s['detail'][:60]})")
            else:
                out(f"    {shape:<18} {s['endpoint_count']} endpoints / "
                    f"{s['distinct_provider_count']} providers")

        base = usable.get(PLAIN)
        if base is None:
            out("    plain not usable -- no baseline to difference against.")
            out("")
            continue

        base_ms = Counter(base["provider_multiset"])
        for shape in (FUNCTION_CALLING, JSON_SCHEMA):
            s = usable.get(shape)
            if s is None:
                continue
            ms = Counter(s["provider_multiset"])
            lost = base_ms - ms
            gained = ms - base_ms
            out(f"    plain -> {shape}")
            out(f"      lost   : {dict(sorted(lost.items())) or '{}'}")
            out(f"      gained : {dict(sorted(gained.items())) or '{}'}")
            if not lost and not gained:
                out("      IDENTICAL MULTISET at n=1 -- no narrowing observed, which is")
                out("      not the same as no narrowing.")
            if s["endpoint_count"] == base["endpoint_count"] and (lost or gained):
                out("      EQUAL SIZE, DIFFERENT POOL -- exactly the case the rule")
                out("      was registered for.")

        fc, js = usable.get(FUNCTION_CALLING), usable.get(JSON_SCHEMA)
        if fc and js:
            fc_ms, js_ms = Counter(fc["provider_multiset"]), Counter(js["provider_multiset"])
            out(f"    {FUNCTION_CALLING} -> {JSON_SCHEMA}")
            out(f"      lost   : {dict(sorted((fc_ms - js_ms).items())) or '{}'}")
            out(f"      gained : {dict(sorted((js_ms - fc_ms).items())) or '{}'}")
            if fc["endpoint_count"] == js["endpoint_count"] and fc_ms != js_ms:
                out("      EQUAL SIZE, DIFFERENT POOL.")
        out("")

    # --- the denominator-zero watch -----------------------------------------
    out("Denominator zero -- #20 3b's vocabulary, still looking for its first instance")
    zeros = [s for s in summaries if s["endpoint_count"] == 0]
    if zeros:
        for s in zeros:
            out(f"  {s['model']} / {s['shape']}: available == [] -- FIRST OBSERVED")
            out("  structurally untestable cell. Reported undefined, never 0/n.")
    else:
        out("  No cell returned an empty pool. The degenerate case stays unobserved;")
        out("  that is a gap, not an absence.")
    absent = [s for s in summaries if s["available"] is None]
    for s in absent:
        out(f"  {s['model']} / {s['shape']}: no endpoints block at all "
            f"({s['call_status']}) -- null, and null is never zero.")
    out("")

    # --- permaslug constancy -------------------------------------------------
    out("Permaslug -- #20's hoist-when-constant condition, checked per cell")
    for s in summaries:
        slugs = s["permaslugs"]
        if slugs is None:
            continue
        state = "constant" if len(slugs) == 1 else f"VARIES ({len(slugs)} values)"
        out(f"  {short(s):<28} {s['shape']:<18} {state}: {slugs}")
    out("")

    # --- spend ---------------------------------------------------------------
    costs = [s["cost"] for s in summaries if s["cost"] is not None]
    out(f"cells reporting a cost: {len(costs)}/{len(summaries)}")
    out(f"spend over the run    : ${sum(costs):.6f}")
    out("=" * 96)
    return "\n".join(lines)


# ---------------------------------------------------------------------------


def dump_payload(cells: List[Cell]) -> List[Dict[str, Any]]:
    """The wire dumps, in #13's shape so the two directories read alike."""
    return [
        {
            "label": cell.label,
            "model": cell.model,
            "shape": cell.shape,
            "call_status": cell.status,
            "detail": cell.detail,
            "call_seconds": round(cell.seconds, 3),
            "wire": [
                {
                    "url": send.url,
                    "sent_header": send.sent_header,
                    "request_headers": send.request_headers,
                    "request_body": send.request_body,
                    "status": send.status,
                    "response_headers": send.response_headers,
                    "response_body": send.response_body,
                    "wire_seconds": round(send.seconds, 3),
                }
                for send in cell.sends
            ],
        }
        for cell in cells
    ]


def cells_from_dump(payload: List[Dict[str, Any]]) -> List[Cell]:
    """Rebuild the cells from a written `bodies.json`.

    **The dumps are the measurement; the report is a view over them.** Rendering
    is separable so that a fault in the *report* — the first run of this probe
    keyed the #13 anchors on the roster enum instead of the wire id and printed
    "not run" for two cells that had run — is fixed by re-rendering rather than
    by nine fresh calls against a pool that has moved in the meantime. Re-running
    would silently substitute a different measurement for the one being
    corrected.
    """
    cells: List[Cell] = []
    for item in payload:
        cells.append(
            Cell(
                model=item["model"],
                shape=item["shape"],
                status=item.get("call_status", "OK"),
                detail=item.get("detail", ""),
                seconds=float(item.get("call_seconds") or 0.0),
                sends=[
                    Send(
                        url=send["url"],
                        request_headers=send.get("request_headers") or {},
                        request_body=send.get("request_body"),
                        sent_header=bool(send.get("sent_header")),
                        status=int(send["status"]),
                        response_headers=send.get("response_headers") or {},
                        response_body=send.get("response_body"),
                        seconds=float(send.get("wire_seconds") or 0.0),
                    )
                    for send in item.get("wire") or []
                ],
            )
        )
    return cells


async def main() -> None:
    parser = argparse.ArgumentParser(description="The three-shape pool probe (#27)")
    parser.add_argument(
        "--smoke",
        action="store_true",
        help="label the run as a discarded wiring run",
    )
    parser.add_argument(
        "--out-dir",
        type=str,
        default="docs/eval-reports/2026-09-05-three-shape-pool-probe",
        help="where the report, the cell summaries and the bodies are written",
    )
    parser.add_argument(
        "--render",
        type=str,
        default=None,
        help="rebuild the report and the cell summaries from a written "
             "bodies.json, making no calls",
    )
    args = parser.parse_args()

    setup_logging()

    if args.render:
        with open(args.render, encoding="utf-8") as fh:
            cells = cells_from_dump(json.load(fh))
        report = build_report(cells, args.smoke)
        logger.info("\n%s", report)
        os.makedirs(args.out_dir, exist_ok=True)
        with open(os.path.join(args.out_dir, "report.txt"), "w", encoding="utf-8") as fh:
            fh.write(report + "\n")
        with open(os.path.join(args.out_dir, "cells.json"), "w", encoding="utf-8") as fh:
            json.dump([cell_summary(c) for c in cells], fh, indent=2, ensure_ascii=False)
        logger.info("re-rendered from %s into %s", args.render, args.out_dir)
        return

    # Imported here, not at module scope: `ai_common.enums` costs 0.24s and 195
    # modules, and this probe's `--help` should not pay it.
    from ai_common.enums import ModelNames

    subjects = [
        ModelNames.DEEPSEEK_V_4_FLASH_0731,
        ModelNames.KIMI_K3,
        ModelNames.GROK_4_6,
    ]

    roster = get_llm_config()["sufficiency_judge"]
    cells: List[Cell] = []

    with wire() as seen:
        for model in subjects:
            entry = panelist(roster, model)
            for shape in SHAPES:
                logger.info("cell: %s / %s", entry["model"], shape)
                cell = await one_call(entry, shape, seen)
                logger.info(
                    "  -> %s, %d send(s), pool=%s",
                    cell.status,
                    len(cell.sends),
                    None if cell.first is None
                    else (lambda e: None if e is None else len(e))(
                        available(cell.first.response_body)
                    ),
                )
                cells.append(cell)

    report = build_report(cells, args.smoke)
    logger.info("\n%s", report)

    os.makedirs(args.out_dir, exist_ok=True)
    with open(os.path.join(args.out_dir, "report.txt"), "w", encoding="utf-8") as fh:
        fh.write(report + "\n")
    with open(os.path.join(args.out_dir, "cells.json"), "w", encoding="utf-8") as fh:
        json.dump([cell_summary(c) for c in cells], fh, indent=2, ensure_ascii=False)
    with open(os.path.join(args.out_dir, "bodies.json"), "w", encoding="utf-8") as fh:
        json.dump(dump_payload(cells), fh, indent=2, ensure_ascii=False)
    logger.info("written to %s", args.out_dir)


if __name__ == "__main__":
    asyncio.run(main())

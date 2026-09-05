"""
Does the catalogue predict the pool's *membership*, or only sometimes its size?

The companion read to `probe_three_shape_pool`. That probe measured the observed
candidate pool for three models under three request shapes;
[#27](https://github.com/bgunyel/clause-and-effect/issues/27) motivated it by the
catalogue being unreliable, and predicted DeepSeek V4 Flash's `json_schema` pool
at **21** (`structured_outputs`) or **26** (`response_format`).

The observed `json_schema` pool is **21 endpoints**. Left there, the natural
reading is *the catalogue was right after all*, which would make
[#20](https://github.com/bgunyel/clause-and-effect/issues/20)'s decision to store
the pool near-verbatim look like over-engineering. That reading is exactly what
#27's registered rule forbids:

> **Equal pool sizes are not the same pool.** The comparison that matters is set
> membership.

So this script asks the catalogue which endpoints declare each capability, and
differences that prediction against the pool actually served — as a **multiset
over providers**, for the same reason the probe does: `available` entries carry
no endpoint id, so two endpoints of one provider are indistinguishable and a set
comparison would equate a pool that lost one of a provider's endpoints with one
that lost none.

**Read-only and unbilled.** `GET /api/v1/models/{author}/{slug}/endpoints` is a
catalogue read, not a generation, so nothing here is a call in the sense the
acceptance queries count. It is deliberately *not* wired through
`src/llm/call.py`: this makes no model call and must not appear in the call log.

Run:

    uv run python -m scripts.probe_catalogue_vs_pool \\
        --bodies docs/eval-reports/2026-09-05-three-shape-pool-probe/bodies.json
"""
from __future__ import annotations

import argparse
import json
import logging
import os
from collections import Counter
from typing import Any, Dict, List, Optional

import httpx

from src.config import get_settings
from src.logging_setup import setup_logging

logger = logging.getLogger(__name__)

CATALOGUE_URL = "https://openrouter.ai/api/v1/models/{model}/endpoints"
TIMEOUT_SECONDS = 30

# The three capability flags #27 names. Read off `supported_parameters`, which is
# the catalogue's own vocabulary — not renamed here, so a reader can grep the
# ticket and the response for the same string.
TOOLS = "tools"
TOOL_CHOICE = "tool_choice"
RESPONSE_FORMAT = "response_format"
STRUCTURED_OUTPUTS = "structured_outputs"


def fetch_catalogue(model: str, api_key: str) -> Optional[Dict[str, Any]]:
    url = CATALOGUE_URL.format(model=model)
    try:
        response = httpx.get(
            url,
            headers={"Authorization": f"Bearer {api_key}"},
            timeout=TIMEOUT_SECONDS,
        )
    except Exception as exc:  # noqa: BLE001 — a failed read is a result
        logger.warning("catalogue read failed for %s: %s", model, exc)
        return None
    if response.status_code != 200:
        logger.warning(
            "catalogue read for %s returned %s", model, response.status_code
        )
        return None
    return response.json()


def endpoints_of(catalogue: Optional[Dict[str, Any]]) -> List[Dict[str, Any]]:
    if not isinstance(catalogue, dict):
        return []
    data = catalogue.get("data")
    if not isinstance(data, dict):
        return []
    endpoints = data.get("endpoints")
    return endpoints if isinstance(endpoints, list) else []


def provider_of(endpoint: Dict[str, Any]) -> str:
    """The catalogue's provider name, in the spelling `available` uses.

    `provider_name` is the field that matches `endpoints.available[].provider`;
    `name` is a display string that appends the quantisation and would never
    compare equal.
    """
    return str(endpoint.get("provider_name"))


def declaring(endpoints: List[Dict[str, Any]], *params: str) -> Counter:
    """Providers whose endpoint declares **all** of `params`, with multiplicity."""
    out: Counter = Counter()
    for endpoint in endpoints:
        supported = endpoint.get("supported_parameters") or []
        if all(p in supported for p in params):
            out[provider_of(endpoint)] += 1
    return out


def multiset_line(counter: Counter) -> str:
    return json.dumps(dict(sorted(counter.items())), ensure_ascii=False)


def compare(name: str, predicted: Counter, observed: Counter) -> List[str]:
    lines: List[str] = []
    p, o = sum(predicted.values()), sum(observed.values())
    lines.append(f"    {name}")
    lines.append(f"      predicted : {p} endpoints / {len(predicted)} providers")
    lines.append(f"      observed  : {o} endpoints / {len(observed)} providers")
    missing = predicted - observed        # predicted to be there, was not
    extra = observed - predicted          # served, though not predicted
    lines.append(f"      predicted but absent : {multiset_line(missing)}")
    lines.append(f"      served but unpredicted: {multiset_line(extra)}")
    if p == o and (missing or extra):
        lines.append("      SIZE MATCHES, MEMBERSHIP DOES NOT -- the exact case the")
        lines.append("      registered rule was written for. A size-only check here")
        lines.append("      would have reported agreement.")
    elif not missing and not extra:
        lines.append("      identical multiset -- the catalogue predicted this pool.")
    return lines


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--bodies",
        type=str,
        default="docs/eval-reports/2026-09-05-three-shape-pool-probe/bodies.json",
        help="the pool probe's written wire dumps",
    )
    parser.add_argument(
        "--out-dir",
        type=str,
        default="docs/eval-reports/2026-09-05-three-shape-pool-probe",
    )
    args = parser.parse_args()

    setup_logging()
    api_key = get_settings().OPENROUTER_API_KEY.get_secret_value()

    with open(args.bodies, encoding="utf-8") as fh:
        dumps = json.load(fh)

    # The observed pools, keyed by (wire model id, shape).
    observed: Dict[str, Dict[str, Counter]] = {}
    for item in dumps:
        wire = item.get("wire") or []
        if not wire:
            continue
        request_body = wire[0].get("request_body") or {}
        model = str(request_body.get("model"))
        body = wire[0].get("response_body") or {}
        meta = body.get("openrouter_metadata") or {}
        block = meta.get("endpoints") or {}
        entries = block.get("available")
        if not isinstance(entries, list):
            continue
        observed.setdefault(model, {})[item["shape"]] = Counter(
            str(e.get("provider")) for e in entries
        )

    lines: List[str] = []
    out = lines.append
    out("=" * 96)
    out("Catalogue against pool -- does supported_parameters predict who serves you?")
    out("=" * 96)
    out("Compared as a MULTISET over providers, never as a size and never as a set.")
    out("`available` entries carry no endpoint id, so a provider's two endpoints are")
    out("indistinguishable within a pool; only multiplicity separates them.")
    out("")

    catalogues: Dict[str, Any] = {}
    for model, shapes in observed.items():
        catalogue = fetch_catalogue(model, api_key)
        catalogues[model] = catalogue
        endpoints = endpoints_of(catalogue)
        out(f"  {model}")
        out(f"    catalogue endpoints                 : {len(endpoints)}")
        out(f"    distinct providers in the catalogue : "
            f"{len({provider_of(e) for e in endpoints})}")
        everything = Counter(provider_of(e) for e in endpoints)
        out(f"    catalogue multiset : {multiset_line(everything)}")
        out("")

        # plain: the catalogue's whole enumeration is the prediction.
        if "plain" in shapes:
            for line in compare("plain  <- every catalogue endpoint",
                                everything, shapes["plain"]):
                out(line)
        # function_calling: endpoints declaring tools and tool_choice.
        if "function_calling" in shapes:
            for line in compare(
                "function_calling  <- declares tools + tool_choice",
                declaring(endpoints, TOOLS, TOOL_CHOICE), shapes["function_calling"]
            ):
                out(line)
        # json_schema: both candidate predictors #27 names, kept side by side
        # because choosing one after seeing the answer is the failure the
        # pre-registration exists to prevent.
        if "json_schema" in shapes:
            for line in compare(
                "json_schema  <- declares structured_outputs",
                declaring(endpoints, STRUCTURED_OUTPUTS), shapes["json_schema"]
            ):
                out(line)
            for line in compare(
                "json_schema  <- declares response_format",
                declaring(endpoints, RESPONSE_FORMAT), shapes["json_schema"]
            ):
                out(line)
        out("")

    out("=" * 96)
    report = "\n".join(lines)
    logger.info("\n%s", report)

    os.makedirs(args.out_dir, exist_ok=True)
    path = os.path.join(args.out_dir, "catalogue-vs-pool.txt")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(report + "\n")
    with open(os.path.join(args.out_dir, "catalogue.json"), "w", encoding="utf-8") as fh:
        json.dump(catalogues, fh, indent=2, ensure_ascii=False)
    logger.info("written to %s", path)


if __name__ == "__main__":
    main()

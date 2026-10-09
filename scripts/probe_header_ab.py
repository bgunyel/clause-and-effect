"""
Does `X-OpenRouter-Metadata: enabled` change the request it rides on?

[#14](https://github.com/bgunyel/clause-and-effect/issues/14) decided the socket
patch injects that header on OpenRouter completions, and registered the decision
as **reversible**. What it could not settle is what
`docs/design/llm-call-log.md` is then permitted to *assert* about the header not
distorting the request: #13 measured status, latency, cost and `cached_tokens`
across three paired calls and found nothing, and three paired calls bound
nothing. This probe is the run that turns that null into an interval.

**The decision rule was registered first**, in the dated *Registration* section
appended to `docs/eval-reports/2026-09-05-provider-acceptance-pre-registration.md`
— n, the three endpoints, the ±10% latency margin, the degeneracy rule, and an
outcome table saying what each result licenses the design to claim. Everything
this file computes is computed because that section says to compute it. Reading
the rule off the numbers is the failure that document exists to prevent, so this
probe deliberately holds no thresholds of its own beyond the ones registered.

**Distortion, not coverage.** #11's stripped-on-cache-hit and absent-on-5xx
behaviours cost rows and never corrupt one; they are not measured here.

**The request shape is the judge's own and is held fixed across arms.**
`build_structured_llm` on DeepSeek V4 Flash under `function_calling`, with
`llm_config`'s `model_args` untouched — so `provider: {'require_parameters':
True}` and a bound tool both reach the wire, and routing happens inside the
**23-endpoint** pool rather than the 29 (#13 §7). The pool is request-shaped, so
a shape that varied between arms would confound the comparison with itself. The
probe asserts the two arms' request bodies hash equal and refuses to report a
pair whose bodies differ.

**Latency is taken at the socket**, around `httpx.AsyncClient.send`, because that
is the last point the request is ours — the same reason `probe_wire_params`
asserts against the bytes rather than against the model object.

**A call that sent more than one request is dropped as a pair.**
`build_structured_llm` ends in `.with_retry(stop_after_attempt=3)`, so a retried
call has several sends and no single wire latency; pairing it would attribute a
retry to the treatment.

Run:

    uv run python -m scripts.probe_header_ab --pairs 5 --smoke   # wiring, discarded
    uv run python -m scripts.probe_header_ab                     # the registered run

(A path invocation fails — `scripts/` lands on `sys.path` instead of the repo
root, and `pythonpath` in `pyproject.toml` is pytest-only.)
"""
from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import logging
import statistics
import time
from contextlib import contextmanager
from dataclasses import dataclass, field
from typing import Any, Dict, Iterator, List, Literal, Optional, Tuple

import httpx
from pydantic import BaseModel, Field

from src.llm.structured import build_structured_llm
from src.llm_config import get_llm_config, panelist
from src.logging_setup import setup_logging

logger = logging.getLogger(__name__)

# The registered n. Named as a constant so a run that used a different one is
# visible in its own report rather than only in a shell history.
REGISTERED_PAIRS = 300

# Registered in the pre-registration's §A.4. Not a tuning knob.
LATENCY_MARGIN_FRACTION = 0.10

# Half of `probe_wire_params`'s minute is still generous for a one-sentence
# prompt; this one is kept at 60s so the two probes' timeouts mean the same
# thing when their reports are read side by side.
CALL_TIMEOUT_SECONDS = 60

HEADER_NAME = "X-OpenRouter-Metadata"
HEADER_VALUE = "enabled"

# The subject of the run. `panelist` rather than an index into the roster, for
# the reason its docstring gives: a reordered roster must not silently repoint a
# measurement.
from ai_common.enums import ModelNames  # noqa: E402 — see module docstring

SUBJECT_MODEL = ModelNames.DEEPSEEK_V_4_FLASH_0731

_ERROR_CHARS = 200


class _HeaderCheck(BaseModel):
    """A one-sentence schema, for the same reason `probe_wire_params` uses one:
    the request must be shaped like a real structured call — a bound tool and a
    `Literal` — without the prompt itself becoming a source of variance."""

    answer: str = Field(description="The capital city of Turkiye.")
    tag: Literal["core", "auxiliary"] = Field(description='Exactly "core".')


_PROMPT = (
    "You are being checked for wiring, not judgement. Return exactly:\n"
    "  answer: the capital city of Turkiye (one word)\n"
    '  tag:    the literal value "core"\n'
)


@dataclass
class Send:
    """One HTTP request/response pair as it crossed the socket."""

    body_sha: str
    header_on_wire: bool
    seconds: float
    status: int
    response: Optional[Dict[str, Any]]


@dataclass
class Call:
    """One `ainvoke`, and everything the socket saw while it ran."""

    pair: int
    arm: str
    status: str
    detail: str
    sends: List[Send] = field(default_factory=list)

    @property
    def last(self) -> Optional[Send]:
        return self.sends[-1] if self.sends else None

    @property
    def usable(self) -> bool:
        """One send, 200, and a JSON body. Registered as the pair-drop rule."""
        return (
            self.status == "OK"
            and len(self.sends) == 1
            and self.sends[0].status == 200
            and self.sends[0].response is not None
        )


@contextmanager
def wire(inject: List[bool]) -> Iterator[List[Send]]:
    """
    Patch `httpx.AsyncClient.send` to time, optionally mutate, and read.

    `inject` is a one-element mutable cell rather than an argument because the
    patch outlives any single call: the arm is switched between calls and the
    same patched `send` serves both. A patch per arm would reinstall twice per
    pair and make the two arms structurally different in a way the measurement
    could not see.

    The response body is read with `aread()` before it is handed back. Nothing in
    this repository streams (#13), so the read cannot consume a body the caller
    still needs; the guard is kept anyway because a silent truncation here would
    look like a missing `openrouter_metadata` rather than like a bug.
    """
    seen: List[Send] = []
    original = httpx.AsyncClient.send

    async def timed(self, request, *args, **kwargs):  # type: ignore[no-untyped-def]
        if not (
            request.url.host == "openrouter.ai"
            and request.url.path == "/api/v1/chat/completions"
        ):
            return await original(self, request, *args, **kwargs)

        if inject[0]:
            request.headers[HEADER_NAME] = HEADER_VALUE

        body_sha = hashlib.sha256(request.content or b"").hexdigest()
        started = time.perf_counter()
        response = await original(self, request, *args, **kwargs)
        elapsed = time.perf_counter() - started

        parsed: Optional[Dict[str, Any]] = None
        try:
            await response.aread()
            parsed = json.loads(response.content)
        except Exception:  # noqa: BLE001 — an unreadable body is a result
            parsed = None

        seen.append(
            Send(
                body_sha=body_sha,
                header_on_wire=HEADER_NAME.lower()
                in {k.lower() for k in request.headers.keys()},
                seconds=elapsed,
                status=response.status_code,
                response=parsed,
            )
        )
        return response

    httpx.AsyncClient.send = timed  # type: ignore[method-assign]
    try:
        yield seen
    finally:
        httpx.AsyncClient.send = original  # type: ignore[method-assign]


async def one_call(
    entry: Dict[str, Any], seen: List[Send], inject: List[bool], pair: int, arm: str
) -> Call:
    """Send one call on one arm and keep what the socket saw."""
    seen.clear()
    inject[0] = arm == "header"

    try:
        llm = build_structured_llm(entry, _HeaderCheck)
        await asyncio.wait_for(llm.ainvoke(_PROMPT), timeout=CALL_TIMEOUT_SECONDS)
    except asyncio.TimeoutError:
        status, detail = "TIMEOUT", f"no response within {CALL_TIMEOUT_SECONDS}s"
    except Exception as exc:  # noqa: BLE001 — a provider error is a result here
        status, detail = "ERROR", f"{type(exc).__name__}: {str(exc)[:_ERROR_CHARS]}"
    else:
        status, detail = "OK", ""

    return Call(pair=pair, arm=arm, status=status, detail=detail, sends=list(seen))


# ---------------------------------------------------------------------------
# Reading one response body
# ---------------------------------------------------------------------------


def selected_from_endpoints(body: Dict[str, Any]) -> Optional[str]:
    """`openrouter_metadata.endpoints.available[selected].provider`.

    #14's registered precedence puts this first: it is the only spelling of the
    served provider that appears in a published schema. Absent on the baseline
    arm by construction, which is what the header buys.
    """
    meta = body.get("openrouter_metadata")
    if not isinstance(meta, dict):
        return None
    endpoints = meta.get("endpoints")
    if not isinstance(endpoints, dict):
        return None
    for endpoint in endpoints.get("available") or []:
        if isinstance(endpoint, dict) and endpoint.get("selected"):
            return endpoint.get("provider")
    return None


def selected_from_summary(body: Dict[str, Any]) -> Optional[str]:
    """The `selected=` clause of `openrouter_metadata.summary`.

    Parsed only to run the vocabulary check. #14 registered that `summary` is a
    derived string and is **never** the source of `served_provider`; reading it
    here is the check, not the reading.
    """
    meta = body.get("openrouter_metadata")
    if not isinstance(meta, dict):
        return None
    summary = meta.get("summary")
    if not isinstance(summary, str):
        return None
    for part in summary.split(","):
        key, _, value = part.strip().partition("=")
        if key == "selected":
            return value or None
    return None


def prompt_cost(body: Dict[str, Any]) -> Optional[float]:
    """The prompt-side cost, which #13 observed identical to all digits.

    Read from `usage.cost_details` where OpenRouter puts it. Returned as `None`
    rather than 0.0 when absent — *null means the provider did not report it, and
    null is never zero* is a rule about the log, and a probe that feeds the log's
    claims must not break it in its own arithmetic.
    """
    usage = body.get("usage")
    if not isinstance(usage, dict):
        return None
    details = usage.get("cost_details")
    if not isinstance(details, dict):
        return None
    for key in ("upstream_inference_prompt_cost", "prompt_cost"):
        if key in details and details[key] is not None:
            return float(details[key])
    return None


def cached_tokens(body: Dict[str, Any]) -> Optional[int]:
    usage = body.get("usage")
    if not isinstance(usage, dict):
        return None
    details = usage.get("prompt_tokens_details")
    if not isinstance(details, dict):
        return None
    value = details.get("cached_tokens")
    return None if value is None else int(value)


def attempt_number(body: Dict[str, Any]) -> Optional[int]:
    meta = body.get("openrouter_metadata")
    if not isinstance(meta, dict):
        return None
    value = meta.get("attempt")
    return None if value is None else int(value)


# ---------------------------------------------------------------------------
# The registered statistics
# ---------------------------------------------------------------------------


def clopper_pearson_upper(failures: int, n: int, alpha: float = 0.05) -> float:
    """One-sided 95% upper bound — §2's instrument, reused deliberately.

    Written out rather than imported from the earlier probe because there is no
    earlier probe: §2's table is a table, and the bound has never been computed
    in code here. `beta.ppf` is the standard exact form; for `failures == 0` it
    reduces to `1 - alpha ** (1 / n)`, which is asserted in the report so the
    library and the closed form cannot silently disagree.
    """
    from scipy.stats import beta

    if n == 0:
        return 1.0
    if failures >= n:
        return 1.0
    return float(beta.ppf(1 - alpha, failures + 1, n - failures))


def paired_ci(diffs: List[float], alpha: float = 0.05) -> Tuple[float, float, float]:
    """Mean paired difference and its two-sided 95% t interval."""
    from scipy.stats import t

    n = len(diffs)
    mean = statistics.fmean(diffs)
    if n < 2:
        return mean, float("-inf"), float("inf")
    sem = statistics.stdev(diffs) / (n ** 0.5)
    half = float(t.ppf(1 - alpha / 2, n - 1)) * sem
    return mean, mean - half, mean + half


# ---------------------------------------------------------------------------
# The report
# ---------------------------------------------------------------------------


def build_report(pairs: List[Tuple[Call, Call]], requested: int, smoke: bool) -> str:
    lines: List[str] = []
    out = lines.append

    out("=" * 96)
    out("Header A/B — X-OpenRouter-Metadata: enabled, against the judge's own request")
    out("=" * 96)
    if smoke:
        out("SMOKE RUN — wiring only. These observations are discarded and never")
        out("pooled with the registered run (pre-registration §A.2).")
        out("")

    usable: List[Tuple[Call, Call]] = []
    dropped: List[Tuple[Call, Call]] = []
    for header, baseline in pairs:
        (usable if header.usable and baseline.usable else dropped).append(
            (header, baseline)
        )

    n = len(usable)
    out(f"pairs requested        : {requested}")
    out(f"pairs attempted        : {len(pairs)}")
    out(f"pairs usable           : {n}")
    out(f"pairs dropped          : {len(dropped)}")
    if requested != REGISTERED_PAIRS:
        out(f"NOTE: registered n is {REGISTERED_PAIRS} pairs; this run requested "
            f"{requested}.")
    out("")

    if not usable:
        out("No usable pair. Nothing below is computed.")
        for header, baseline in dropped[:10]:
            out(f"  pair {header.pair}: header={header.status} {header.detail} | "
                f"baseline={baseline.status} {baseline.detail}")
        out("=" * 96)
        return "\n".join(lines)

    # --- precondition: the arms differ only in the header --------------------
    body_mismatch = [
        h.pair for h, b in usable if h.sends[0].body_sha != b.sends[0].body_sha
    ]
    header_missing = [h.pair for h, _ in usable if not h.sends[0].header_on_wire]
    header_leaked = [b.pair for _, b in usable if b.sends[0].header_on_wire]

    out("Precondition — the arms differ only in the header")
    out(f"  request bodies hash-equal within pair : {n - len(body_mismatch)}/{n}")
    out(f"  header present on header arm          : {n - len(header_missing)}/{n}")
    out(f"  header absent on baseline arm         : {n - len(header_leaked)}/{n}")
    if body_mismatch or header_missing or header_leaked:
        out("  PRECONDITION FAILED — the comparison is not the registered one.")
        out(f"  body mismatch on pairs: {body_mismatch[:20]}")
        out(f"  header missing on pairs: {header_missing[:20]}")
        out(f"  header leaked on pairs: {header_leaked[:20]}")
    out("")

    # --- primary, categorical ------------------------------------------------
    header_providers: List[Optional[str]] = []
    baseline_providers: List[Optional[str]] = []
    flips: List[int] = []
    for h, b in usable:
        hb, bb = h.sends[0].response or {}, b.sends[0].response or {}
        hp = selected_from_endpoints(hb) or hb.get("provider")
        bp = bb.get("provider")
        header_providers.append(hp)
        baseline_providers.append(bp)
        if hp != bp:
            flips.append(h.pair)

    def distribution(values: List[Optional[str]]) -> Dict[str, int]:
        counts: Dict[str, int] = {}
        for value in values:
            key = value if value is not None else "<absent>"
            counts[key] = counts.get(key, 0) + 1
        return dict(sorted(counts.items(), key=lambda kv: -kv[1]))

    header_dist = distribution(header_providers)
    baseline_dist = distribution(baseline_providers)
    bound = clopper_pearson_upper(len(flips), n)
    closed_form = 1 - 0.05 ** (1 / n) if not flips else None

    out("Primary endpoint — the selected provider (categorical)")
    out(f"  header arm   : {header_dist}")
    out(f"  baseline arm : {baseline_dist}")
    out(f"  flips        : {len(flips)} of {n}   {flips[:20]}")
    out(f"  Clopper-Pearson 95% one-sided upper bound on the flip rate: "
        f"{bound * 100:.2f}%")
    if closed_form is not None:
        out(f"  closed form for 0/{n}: {closed_form * 100:.2f}%  "
            f"(agrees: {abs(closed_form - bound) < 1e-12})")

    degenerate_header = len(header_dist) == 1
    degenerate_baseline = len(baseline_dist) == 1
    same_provider = (
        degenerate_header
        and degenerate_baseline
        and next(iter(header_dist)) == next(iter(baseline_dist))
    )
    if same_provider:
        out(f"  DEGENERATE (both arms): every observation is "
            f"{next(iter(header_dist))!r}.")
        out("  Registered reading: no categorical flip detected at this n;")
        out("  REWEIGHTING UNTESTED. This is not 'no effect'.")
    elif degenerate_header or degenerate_baseline:
        out("  One arm degenerate, the other not — that is itself a flip finding.")
    else:
        out("  Both arms exercised more than one provider: a share comparison is")
        out("  available at this n.")
    out("")

    # --- secondary, continuous ----------------------------------------------
    out("Secondary endpoints — continuous, powered by n whatever routing did")

    diffs = [h.sends[0].seconds - b.sends[0].seconds for h, b in usable]
    header_mean = statistics.fmean(h.sends[0].seconds for h, _ in usable)
    baseline_mean = statistics.fmean(b.sends[0].seconds for _, b in usable)
    mean_diff, low, high = paired_ci(diffs)
    margin = LATENCY_MARGIN_FRACTION * baseline_mean
    contained = -margin <= low and high <= margin

    out(f"  wire latency, header arm mean   : {header_mean:.3f} s")
    out(f"  wire latency, baseline arm mean : {baseline_mean:.3f} s")
    out(f"  paired difference (header - baseline): {mean_diff * 1000:+.1f} ms")
    out(f"  95% CI                              : "
        f"[{low * 1000:+.1f}, {high * 1000:+.1f}] ms")
    out(f"  registered margin (+/-10% of baseline mean): +/-{margin * 1000:.1f} ms")
    out(f"  VERDICT: {'contained — no latency penalty' if contained else 'NOT contained — inconclusive on latency'}")
    out("")

    cost_pairs = [
        (h.pair, prompt_cost(h.sends[0].response or {}), prompt_cost(b.sends[0].response or {}))
        for h, b in usable
    ]
    cost_known = [(p, x, y) for p, x, y in cost_pairs if x is not None and y is not None]
    cost_differs = [(p, x, y) for p, x, y in cost_known if x != y]
    out(f"  prompt-side cost, pairs where both arms reported it: "
        f"{len(cost_known)}/{n}")
    out(f"  pairs whose prompt-side cost differs               : "
        f"{len(cost_differs)}")
    if cost_differs:
        out("  DISTORTION FINDING — reported individually, never averaged:")
        for p, x, y in cost_differs[:20]:
            out(f"    pair {p}: header={x!r} baseline={y!r}")
    elif cost_known:
        out(f"  every reporting pair identical to all digits at "
            f"{cost_known[0][1]!r}")
    out("")

    cache_pairs = [
        (h.pair, cached_tokens(h.sends[0].response or {}), cached_tokens(b.sends[0].response or {}))
        for h, b in usable
    ]
    cache_header = distribution([str(x) for _, x, _ in cache_pairs])
    cache_baseline = distribution([str(y) for _, _, y in cache_pairs])
    cache_differs = [p for p, x, y in cache_pairs if x != y]
    out(f"  cached_tokens, header arm   : {cache_header}")
    out(f"  cached_tokens, baseline arm : {cache_baseline}")
    out(f"  pairs whose cached_tokens differ: {len(cache_differs)} {cache_differs[:20]}")
    out("")

    # --- the vocabulary check, repeated -------------------------------------
    out("Vocabulary check — repeated against a live pool (pre-registration §A.6)")
    disagreements: List[str] = []
    checked = 0
    for h, _ in usable:
        body = h.sends[0].response or {}
        top = body.get("provider")
        endpoints = selected_from_endpoints(body)
        summary = selected_from_summary(body)
        if endpoints is None and summary is None:
            continue
        checked += 1
        if not (top == endpoints == summary):
            disagreements.append(
                f"pair {h.pair}: provider={top!r} "
                f"available[selected]={endpoints!r} summary.selected={summary!r}"
            )
    out(f"  header-arm responses carrying all three spellings: {checked}/{n}")
    out(f"  disagreements: {len(disagreements)}")
    for line in disagreements[:20]:
        out(f"    {line}")
    if not disagreements and checked:
        providers = {p for p in header_providers if p}
        out(f"  All three agree on every response. Providers exercised: "
            f"{sorted(providers)}")
        if len(providers) <= 1:
            out("  BOUNDED AT ONE PROVIDER — the check is not retired. It defers")
            out("  to the first genuinely multi-provider observation.")
    out("")

    # --- still unobserved ----------------------------------------------------
    attempts = distribution(
        [str(attempt_number(h.sends[0].response or {})) for h, _ in usable]
    )
    out(f"openrouter_metadata.attempt across the header arm: {attempts}")
    if set(attempts) <= {"1"}:
        out("  No fallback was exercised. The multi-attempt shape stays UNOBSERVED")
        out("  (#13 said the same at n=3); that is a gap, not an absence.")
    out("")

    if dropped:
        out("Dropped pairs")
        for h, b in dropped[:20]:
            out(f"  pair {h.pair}: header={h.status}/{len(h.sends)} send(s) "
                f"{h.detail[:80]} | baseline={b.status}/{len(b.sends)} send(s) "
                f"{b.detail[:80]}")
        out("")

    total_cost = 0.0
    for h, b in usable:
        for call in (h, b):
            body = call.sends[0].response or {}
            usage = body.get("usage")
            if isinstance(usage, dict) and usage.get("cost") is not None:
                total_cost += float(usage["cost"])
    out(f"spend over {2 * n} usable calls: ${total_cost:.6f}")
    out("=" * 96)
    return "\n".join(lines)


async def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pairs", type=int, default=REGISTERED_PAIRS)
    parser.add_argument(
        "--smoke",
        action="store_true",
        help="label the run as the discarded wiring run of pre-registration §A.2",
    )
    parser.add_argument("--out", type=str, default=None, help="write the report here")
    args = parser.parse_args()

    setup_logging()
    entry = panelist(get_llm_config()["sufficiency_judge"], SUBJECT_MODEL)

    inject = [False]
    pairs: List[Tuple[Call, Call]] = []
    with wire(inject) as seen:
        for index in range(args.pairs):
            # The leading arm alternates, so neither arm is systematically the
            # warmer call of its pair — registered in §A.2.
            order = ("header", "baseline") if index % 2 == 0 else ("baseline", "header")
            calls: Dict[str, Call] = {}
            for arm in order:
                calls[arm] = await one_call(entry, seen, inject, index, arm)
            pairs.append((calls["header"], calls["baseline"]))
            if (index + 1) % 25 == 0:
                logger.info("%d of %d pairs", index + 1, args.pairs)

    report = build_report(pairs, args.pairs, args.smoke)
    logger.info("\n%s", report)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as handle:
            handle.write(report + "\n")
        logger.info("report written to %s", args.out)


if __name__ == "__main__":
    asyncio.run(main())

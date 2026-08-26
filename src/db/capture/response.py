"""
Everything the log reads off a model's reply, in one place.

**One module because two callers need the same knowledge and must not disagree
about it.** The call log reads seven fields to fill a row; the judge's
:class:`~src.eval.sufficiency.llm.CallRecord` reads three of them to report what
a run cost. Written twice, the day OpenRouter moves ``cost`` is the day someone
fixes the report and the log goes on recording nulls — silently, because a null
here is indistinguishable from a provider that did not report the field. That
failure would be invisible in exactly the way this project keeps finding things
invisible.

**Nothing here imports LangChain**, and it must stay that way. Every reader is
``getattr`` plus ``.get``, so this module is free to import — which is what lets
`llm.py` use it without paying for the storage layer. It also means a provider
object of any shape can be passed in, including ``None``.

**The field names are observed, not assumed.** A real OpenRouter reply through
``with_structured_output(include_raw=True)``, dumped 2026-08-23 and recorded in
that day's dev log:

    metadata keys: ['cost', 'cost_details', 'created', 'finish_reason', 'id',
                    'logprobs', 'model_name', 'model_provider', 'object']
    cost: 3.235e-05
    usage: {'input_tokens': 287, 'output_tokens': 180, 'total_tokens': 467,
            'output_token_details': {'reasoning': 153}}

Note what is *not* there: ``provider``. The served provider is on the wire and
the client library drops it before this point, which is the whole reason the
socket patch exists — see design §What each layer can see.

**Every reader returns ``None`` rather than raising, and null is never zero.**
These are *provider* fields, not LangChain ones: a provider that omits ``cost``
must yield an unpriced call rather than a ``KeyError`` that loses an otherwise
valid judgement. And a call reporting ``reasoning: 0`` did not reason, while a
call reporting nothing may have reasoned freely and not said so — averaging the
two together would invent a measurement.
"""
from __future__ import annotations

from typing import Any


def response_metadata(raw: Any) -> dict:
    """``response_metadata`` off a message, or an empty dict."""
    return getattr(raw, "response_metadata", None) or {}


def usage_metadata(raw: Any) -> dict:
    """``usage_metadata`` off a message, or an empty dict."""
    return getattr(raw, "usage_metadata", None) or {}


def generation_id_of(raw: Any) -> str | None:
    """
    The provider's own id for one generation, if it named one.

    ``response_metadata['id']``, and specifically **not** ``raw.id``. Measured
    2026-08-25 on both channels: the message's own ``id`` is a LangChain run
    identifier minted in this process (``lc_run--01a0376a-7f1a-…``), while
    OpenRouter's is ``gen-1787636121-eAEcEp3BID10rZPfqZgv`` and appears only in
    the metadata. ``raw.id`` is the tempting attribute and it is worthless here,
    because it joins to nothing outside this process.

    This is the one field that makes a run auditable against the provider, and
    the one the 2026-08-26 documentation check turned into the log's strongest
    argument: ``/generation`` fetches a generation **by id**, no endpoint
    enumerates ids over a date range, so **an id not captured at call time is
    unreachable by API, permanently**.
    """
    return response_metadata(raw).get("id")


def cost_of(raw: Any) -> float | None:
    """The price the provider put on one response, if it reported one."""
    return response_metadata(raw).get("cost")


def finish_reason_of(raw: Any) -> str | None:
    """Why the model stopped, as the provider spelled it."""
    return response_metadata(raw).get("finish_reason")


def prompt_tokens_of(raw: Any) -> int | None:
    """Input tokens, as LangChain normalises them across providers."""
    return usage_metadata(raw).get("input_tokens")


def completion_tokens_of(raw: Any) -> int | None:
    """Output tokens. Includes the reasoning tokens, where a provider reports
    both — the two are not added together anywhere."""
    return usage_metadata(raw).get("output_tokens")


def reasoning_tokens_of(raw: Any) -> int | None:
    """
    How many of the call's output tokens went on reasoning, if it reported any.

    ``usage_metadata['output_token_details']['reasoning']``, which LangChain
    normalises from whatever the provider sends. Recorded because the panel
    calls different models through different structured-output channels — a
    concession made 2026-08-23 to the fact that neither channel works for every
    model — and that concession has an unquantified cost.

    The specific suspicion, and it is measured rather than assumed: MiniMax
    reported ``{'reasoning': 0}`` under ``json_schema`` while producing
    reasoning on the tool path. If ``response_format`` suppresses reasoning for
    some models, then three of the eight panelists judge without the budget the
    other five get, *inside the comparison the panel exists to make*.
    """
    details = usage_metadata(raw).get("output_token_details") or {}
    return details.get("reasoning")


def content_of(raw: Any) -> str | None:
    """
    What the model actually said, in full and unshortened.

    **In full is the point** (decision 10). ``JudgeResponseError`` quotes 300
    characters, and on 2026-08-25 that was exactly the gap: MiniMax's failure
    read ``Invalid json output: `` with nothing before the newline, and whether
    the content was empty or merely unparseable is still unknown because the
    excerpt did not reach far enough. This is stored on failures only, so the
    length is bounded by how often the judge fails rather than by how often it
    is called.

    ``str`` rather than the raw value: ``content`` is a string on the channels
    in use, but LangChain also models it as a list of blocks, and a column typed
    ``Text`` must be handed text.
    """
    content = getattr(raw, "content", None)
    if content is None:
        return None
    return str(content)
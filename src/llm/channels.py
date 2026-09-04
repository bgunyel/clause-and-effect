"""
How a model is asked to return a schema — the three channels, and nothing else.

Read by :func:`src.llm.structured.build_structured_llm`, and named in every
entry of ``llm_config``'s roster so that each model's channel is *stated* rather
than half of them being an absence.

**Three strings, in their own module, on purpose.** They are the one part of the
LLM tier a caller may need without wanting anything else — ``llm_config`` names
them in a table it builds at import time, and importing this module must not
cost what building a model costs. Nothing here imports anything.

**The channel is a measurement, not a preference.** Neither channel works for
every model, and which one a model needs was established by running it: see the
per-model notes in :func:`src.llm_config.get_llm_config`, which is where the
evidence lives. A caller that leaves it unset gets a refusal rather than a
default, because a silent default would call some new model the wrong way and
the result would be recorded as that model's judgement.
"""

# ``bind_tools(..., tool_choice="auto")``. The model is offered the schema as a
# tool and may decline it — which is why
# :func:`src.llm.structured.payload_from_tool_call` reports a missing tool call
# as a failure rather than as an empty result.
#
# For a model that rejects a pinned ``tool_choice`` outright. ``z-ai/glm-5.3``
# is the case that forced it into existence.
TOOL_CALL_AUTO = 'tool_call_auto'

# ``with_structured_output(method="json_schema")``, which binds
# ``response_format={"type": "json_schema", ...}`` instead of sending tools.
#
# This is what the panel runs on. Function calling was the default and it failed
# unevenly across the roster: MiniMax M3's OpenRouter endpoint does not accept
# tools at all, so it answered in the schema's *shape* as prose and scored 2/6;
# Kimi K3 did the same on 2 of 6; Grok emitted the tool call as a fenced JSON
# block. Measured 2026-08-23 on the three cases MiniMax had failed, `json_schema`
# returned all three — including `art15_case1`'s ten core claims, which is §4.6's
# expected output exactly.
JSON_SCHEMA = 'json_schema'

# ``with_structured_output()`` as it comes — tools plus a ``tool_choice`` pinned
# to the schema's own function, so the model cannot decline to fill it. The
# library's own default.
FUNCTION_CALLING = 'function_calling'
"""
Tests for the roster lookup.

Only :func:`panelist` is covered here. It takes entries rather than fetching
them precisely so it can be tested without settings or an API key, and the
config builder itself needs both.
"""
from ai_common.enums import ModelNames

import pytest

from src.llm_config import panelist


def _entry(model, channel="function_calling"):
    """A roster entry, built from literals rather than from `get_llm_config`."""
    return {"model": model, "structured_output": channel, "model_args": {}}


ROSTER = [
    _entry(ModelNames.DEEPSEEK_V_4_FLASH_0731),
    _entry(ModelNames.GROK_4_6, "json_schema"),
    _entry(ModelNames.MINIMAX_M_3, "json_schema"),
]


def test_a_model_is_found_by_name_not_by_position():
    """
    The whole point: the entry returned is the one for the model asked for,
    wherever it sits. A lookup that agreed with `[0]` would pass on a roster of
    one and fail silently on every reorder.
    """
    assert panelist(ROSTER, ModelNames.MINIMAX_M_3)["model"] == ModelNames.MINIMAX_M_3


def test_the_entry_carries_the_model_s_own_configuration():
    """
    Not merely a match — the entry handed back has to be that model's, since the
    channel is per-model and calling a model through another's is how the
    2026-08-23 panel recorded successful generations as failures.
    """
    assert panelist(ROSTER, ModelNames.GROK_4_6)["structured_output"] == "json_schema"


def test_a_model_that_left_the_roster_raises_rather_than_falling_back():
    """
    A probe pinned to a model no longer on the panel must stop. Returning the
    first entry instead would keep every report's title and change what it
    measured, which is the failure the named lookup exists to prevent.
    """
    with pytest.raises(KeyError):
        panelist(ROSTER, ModelNames.KIMI_K3)


def test_the_error_names_what_is_available():
    """
    The message has to be actionable at the moment a roster edit breaks a probe,
    which is when nobody remembers what the roster now holds.
    """
    with pytest.raises(KeyError) as excinfo:
        panelist(ROSTER, ModelNames.KIMI_K3)

    message = str(excinfo.value)
    assert "KIMI_K3" in message
    assert "DEEPSEEK_V_4_FLASH_0731" in message


def test_an_empty_roster_raises():
    """Degenerate but reachable: a role whose model list was emptied."""
    with pytest.raises(KeyError):
        panelist([], ModelNames.GROK_4_6)

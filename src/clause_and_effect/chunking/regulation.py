"""
The regulations this project chunks, and the facts that are fixed per regulation.

``jurisdiction`` and ``effective_date`` are not free parameters — naming the
regulation determines both. Carrying them as separate arguments would allow a
chunker configured with ``GDPR`` and ``jurisdiction="US"``, and that
contradiction would be written into every chunk's payload with nothing to catch
it. Declared together here, they cannot disagree.

``name`` is load-bearing beyond the payload: lowercased, it is the first
component of every chunk ID (``gdpr_article_5_para_1``), which derives the
Qdrant point ID, which is the identity of every stored vector. Changing the
``name`` of an existing regulation re-keys its whole corpus.
"""
from pydantic import BaseModel, Field


class Regulation(BaseModel):
    """A regulation and the constants that follow from naming it."""

    model_config = {"frozen": True}

    name: str = Field(
        description="Short name of the regulation; lowercased, it prefixes every chunk ID",
        examples=["GDPR", "CCPA"],
    )
    jurisdiction: str = Field(
        description="Jurisdiction the regulation applies in",
        examples=["EU"],
    )
    effective_date: str = Field(
        description=(
            "Date the regulation became *applicable*, not the date it entered "
            "into force — the two differ and the applicable date is the one "
            "compliance is measured against"
        ),
        examples=["2018-05-25"],
    )


# Regulation (EU) 2016/679. In force 2016-05-24, applicable from 2018-05-25;
# the latter is what `effective_date` records.
GDPR = Regulation(
    name="GDPR",
    jurisdiction="EU",
    effective_date="2018-05-25",
)
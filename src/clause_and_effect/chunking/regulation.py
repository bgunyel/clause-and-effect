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
from types import MappingProxyType
from typing import Dict, Mapping

from pydantic import BaseModel, Field, field_serializer, field_validator


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
    chapter_titles: Mapping[str, str] = Field(
        description="Chapter titles associated with this regulation",
    )

    @field_validator("chapter_titles", mode="after")
    @classmethod
    def _freeze_chapter_titles(cls, titles: Mapping[str, str]) -> Mapping[str, str]:
        """
        Copy, then wrap read-only — ``frozen`` does not reach inside a field.

        ``model_config["frozen"]`` blocks *reassignment* of an attribute; it says
        nothing about mutating the object an attribute points at, so a plain
        ``dict`` here left ``GDPR.chapter_titles["1"] = …`` working and every
        chunk built afterwards carrying the change. The proxy is what fixes that.

        The ``dict()`` is belt-and-braces rather than load-bearing: pydantic has
        already built its own dict by the time an ``after`` validator runs, so
        the caller's object is not the one being wrapped. Verified, not assumed —
        but the copy stays, because the guarantee should not rest on an internal
        detail of when pydantic chooses to copy.
        """
        return MappingProxyType(dict(titles))

    @field_serializer("chapter_titles")
    def _serialize_chapter_titles(self, titles: Mapping[str, str]) -> Dict[str, str]:
        """
        Dump as a plain ``dict``.

        Without this pydantic warns that a ``mappingproxy`` is not the
        ``dict[str, str]`` it expected, and a serialized model is plain data by
        definition — the immutability is a property of the live object, not
        something to carry into JSON.
        """
        return dict(titles)

    def __hash__(self) -> int:
        """
        Restore the hashability ``frozen=True`` would otherwise give.

        A mapping field makes pydantic's generated ``__hash__`` fail at runtime
        with ``unhashable type: 'dict'``, which turns a model declared immutable
        into one that cannot be put in a set or used as a dict key. Hashing the
        chapter titles as a sorted tuple keeps the hash consistent with equality.
        """
        return hash(
            (
                self.name,
                self.jurisdiction,
                self.effective_date,
                tuple(sorted(self.chapter_titles.items())),
            )
        )


# Regulation (EU) 2016/679. In force 2016-05-24, applicable from 2018-05-25;
# the latter is what `effective_date` records.
GDPR = Regulation(
    name="GDPR",
    jurisdiction="EU",
    effective_date="2018-05-25",
    chapter_titles = {
        "1": "General provisions",
        "2": "Principles",
        "3": "Rights of the data subject",
        "4": "Controller and processor",
        "5": "Transfers of personal data to third countries or international organisations",
        "6": "Independent supervisory authorities",
        "7": "Cooperation and consistency",
        "8": "Remedies, liability and penalties",
        "9": "Provisions relating to specific processing situations",
        "10": "Delegated acts and implementing acts",
        "11": "Final provisions",
    }
)
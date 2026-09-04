"""
The shapes the three judge stages produce and the driver consumes.

Deliberately free of any LLM import. ``ai_common`` pulls langchain, which pulls
transformers, which pulls torch — measured at 8.34s on this machine when
``src/config.py`` still carried it. Verdict derivation and every property of
these types can therefore be tested without paying that, which is the same
reasoning that split ``llm_config.py`` out of ``config.py``. Anything needing a
model lives in :mod:`src.llm` instead — :mod:`src.llm.structured` is the one
module in the repository that reaches ``ai_common``.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import List, Literal

# Whether a claim in the gold answer must be carried by the quote. Only `core`
# claims bear on the verdict; `auxiliary` ones may elaborate or strengthen the
# answer beyond what the quote supports, which the criterion permits.
ClaimTag = Literal["core", "auxiliary"]

# How a single claim fared against the blind answer. `absent` and `contradicted`
# are kept apart because they call for different repairs: absent evidence means
# the span was cut too short, whereas a contradiction means it points the wrong
# way (the `art2_case4` shape) and the case needs re-reading, not extending.
ClaimSupport = Literal["supported", "contradicted", "absent"]

# The per-case outcome.
#
#   sufficient          the quote answers the question
#   sufficient_verbose  it answers, but the minimal span is far shorter than the
#                       quote — the "devalued" side of the criterion
#   insufficient        the quote cannot answer the question
#   contradicted        the blind answer contradicts a core claim
#
# `contradicted` is deliberately not folded into `insufficient`: evidence that
# points away from the answer is a worse defect than evidence that is merely
# missing, and it implicates the answer as well as the quote.
Verdict = Literal["sufficient", "sufficient_verbose", "insufficient", "contradicted"]


@dataclass(frozen=True)
class Claim:
    """
    One atomic assertion extracted from a gold answer (stage A).

    ``reason`` records why the tag was chosen. It is not decoration: when two
    panel members tag the same claim differently, it is the only thing that says
    which of them read the question correctly (§6.2 — decomposed verdicts carry a
    rationale).
    """

    text: str
    tag: ClaimTag
    reason: str


@dataclass(frozen=True)
class Decomposition:
    """
    Stage A output — the gold answer split into tagged claims.

    ``shortest_sufficient_answer`` is what the tagging was done against, so it is
    kept rather than discarded: it is the auditable trace of *why* a claim came
    out core, and the thing a human calibrator reads first. Empty when the judge
    found nothing in the answer that answers the question, which makes
    ``core_claims`` empty too — a defect in the case, not in the quote.
    """

    shortest_sufficient_answer: str
    claims: List[Claim]

    @property
    def core_claims(self) -> List[Claim]:
        """The claims the quote is required to carry."""
        return [c for c in self.claims if c.tag == "core"]


@dataclass(frozen=True)
class BlindAnswer:
    """
    Stage B output — the question answered from the quote alone.

    ``answered`` is False when the judge took the insufficiency escape; ``answer``
    and ``minimal_span`` are then empty and ``note`` carries what was missing.
    ``minimal_span`` is a substring of the quote, not a paraphrase of it — it is
    the repair candidate.
    """

    answered: bool
    answer: str
    minimal_span: str
    note: str


@dataclass(frozen=True)
class ClaimVerdict:
    """How one claim fared against the blind answer (stage C)."""

    claim: Claim
    support: ClaimSupport
    rationale: str


@dataclass(frozen=True)
class Adjudication:
    """Stage C output — a support decision per claim, with its reasoning."""

    claim_verdicts: List[ClaimVerdict]


@dataclass(frozen=True)
class PanelistRun:
    """One panel member's full A→B→C chain over one case, and its verdict."""

    case_id: str
    model: str
    decomposition: Decomposition
    blind_answer: BlindAnswer
    adjudication: Adjudication
    verdict: Verdict


@dataclass(frozen=True)
class CaseJudgement:
    """The panel's aggregate outcome for one case."""

    case_id: str
    runs: List[PanelistRun]
    verdict: Verdict

    @property
    def unanimous(self) -> bool:
        """Whether every panel member reached the aggregate verdict."""
        return all(run.verdict == self.verdict for run in self.runs)
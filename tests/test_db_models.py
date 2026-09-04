"""
Unit tests for the call log's schema.

No database. The tables are compiled to Postgres DDL in memory, which is enough
to check everything that is decided here: names, types, nullability, keys and
indexes. What it cannot check is that the DDL runs, and that is Alembic's job.

The expectations are **literals throughout** — column names spelled out, table
names spelled out, `CallStatus.OK.value` asserted as `"OK"`. Deriving them from
the models would make every test pass for whatever the models happen to say,
which is the failure mode this project has found three times by mutation.

What is worth pinning here, in rough order of how quietly it would fail:

- **`metadata` is a reserved attribute.** `Base.metadata` is SQLAlchemy's own
  MetaData, so `llm_call`'s `metadata` column has to be mapped under a
  different Python name. Getting this wrong is a startup error, but getting it
  *silently reverted* by a later edit that renames the attribute back is not.
- **No enum types in the database** (decision 12). `sqlalchemy.Enum` is the
  obvious-looking choice and is doubly wrong: its native form creates the type
  the decision forbids, and its non-native form stores `.name` rather than
  `.value`.
- **Null is never zero.** Every metric column must be nullable, because a
  provider that reported nothing and a provider that reported zero are
  different facts and a NOT NULL column would force them together.
- **Cost is exact.** `SUM(llm_attempt.cost)` is the log's headline query;
  Float would accumulate error into the one number the table exists to make
  trustworthy.
"""
import uuid
from datetime import datetime
from decimal import Decimal

import pytest
from sqlalchemy import Float, MetaData, Numeric, String, Text, update
from sqlalchemy.dialects import postgresql
from sqlalchemy.schema import CreateIndex, CreateTable

from src.db.models import Base, CallStatus, LlmAttempt, LlmCall, LlmRun

DIALECT = postgresql.dialect()


def ddl(model) -> str:
    return str(CreateTable(model.__table__).compile(dialect=DIALECT))


def column(model, name):
    return model.__table__.columns[name]


# --------------------------------------------------------------------------
# Shape
# --------------------------------------------------------------------------


def test_the_tables_are_named_as_the_design_names_them():
    assert LlmRun.__tablename__ == "llm_run"
    assert LlmCall.__tablename__ == "llm_call"
    assert LlmAttempt.__tablename__ == "llm_attempt"


def test_llm_run_holds_one_row_per_process():
    assert set(LlmRun.__table__.columns.keys()) == {
        "run_id",
        "entry_point",
        "commit_sha",
        "git_dirty_paths",
        "started_at",
        "finished_at",
        "hostname",
        "created_at",
        "updated_at",
    }


def test_llm_call_holds_what_the_caller_believed():
    assert set(LlmCall.__table__.columns.keys()) == {
        "call_id",
        "run_id",
        "stage",
        "case_id",
        "model",
        "channel",
        "llm_server",
        "requested_provider",
        "status",
        "call_seconds",
        "started_at",
        "generation_id",
        "cost",
        "finish_reason",
        "prompt_tokens",
        "completion_tokens",
        "reasoning_tokens",
        "prompt_sha256",
        "raw_output",
        "error_type",
        "error_message",
        "metadata",
        "created_at",
        "updated_at",
    }


def test_llm_attempt_holds_what_actually_happened():
    assert set(LlmAttempt.__table__.columns.keys()) == {
        "attempt_id",
        "call_id",
        "seq",
        "llm_server",
        "started_at",
        "generation_id",
        "served_provider",
        "model_alias",
        "http_status",
        "cost",
        "prompt_tokens",
        "completion_tokens",
        "reasoning_tokens",
        "finish_reason",
        "request_seconds",
        "routing_chain",
        "native_finish_reason",
        "generation_time",
        "latency",
        "enriched_at",
        "created_at",
        "updated_at",
    }


# --------------------------------------------------------------------------
# Row lifecycle — every table, without exception
# --------------------------------------------------------------------------

# Driven off the metadata rather than a hand-written list, so a table added
# later is covered the day it is added rather than the day someone remembers to
# extend this file. That is the point of putting the columns on Base.
ALL_TABLES = pytest.mark.parametrize(
    "table", Base.metadata.sorted_tables, ids=lambda t: t.name
)


@ALL_TABLES
def test_every_table_records_when_its_rows_were_written(table):
    assert "created_at" in table.columns
    assert "updated_at" in table.columns


@ALL_TABLES
@pytest.mark.parametrize("name", ["created_at", "updated_at"])
def test_the_lifecycle_timestamps_carry_their_timezone(table, name):
    assert table.columns[name].type.timezone is True


@ALL_TABLES
@pytest.mark.parametrize("name", ["created_at", "updated_at"])
def test_the_lifecycle_timestamps_are_always_present(table, name):
    assert table.columns[name].nullable is False


@ALL_TABLES
@pytest.mark.parametrize("name", ["created_at", "updated_at"])
def test_the_lifecycle_timestamps_are_stamped_by_the_database(table, name):
    """
    A server default, not a Python one. Runs come from more than one machine,
    and rows stamped by each machine's own clock cannot be ordered against each
    other — which is the ordering the log exists to support.
    """
    column_ = table.columns[name]
    assert column_.server_default is not None
    assert "now()" in str(column_.server_default.arg).lower()


@ALL_TABLES
def test_updated_at_is_refreshed_on_every_orm_write(table):
    assert table.columns["updated_at"].onupdate is not None


@ALL_TABLES
def test_a_core_update_stamps_updated_at_without_needing_a_trigger(table):
    """
    The property the decision rests on. `onupdate` is applied when SQLAlchemy
    *builds* the statement, so it belongs to the statement rather than to the
    table — a literal `text("UPDATE …")` does not get it, and a trigger was
    rejected in favour of requiring repositories to use Core `update()`.

    Asserted on the compiled SQL rather than on `column.onupdate`, because the
    two are different claims: `onupdate` being set says the table was declared
    correctly, while this says the statement a repository emits actually
    carries the column. The second is the one that keeps the record honest.
    """
    target = next(
        c
        for c in table.columns
        if not c.primary_key and c.name not in ("created_at", "updated_at")
    )
    compiled = str(update(table).values({target.name: None}).compile(dialect=DIALECT))
    assert "updated_at=now()" in compiled


@ALL_TABLES
def test_created_at_is_never_refreshed(table):
    """An insert time that moves is not an insert time."""
    assert table.columns["created_at"].onupdate is None


@ALL_TABLES
def test_the_lifecycle_timestamps_do_not_replace_the_domain_ones(table):
    """
    They answer different questions and the overlap is only apparent.
    `llm_call.started_at` is when the model call began; `created_at` is when the
    row landed, and the gap is the call's duration. Collapsing them would make
    a disagreement between a record and its subject invisible.
    """
    domain = {"started_at", "finished_at", "enriched_at"} & set(table.columns.keys())
    assert domain, f"{table.name} has no domain timestamp to be distinct from"
    assert "created_at" not in domain


# --------------------------------------------------------------------------
# The reserved attribute name
# --------------------------------------------------------------------------


def test_the_call_metadata_column_is_named_metadata_in_the_database():
    assert "metadata" in LlmCall.__table__.columns
    assert "call_metadata" not in LlmCall.__table__.columns


def test_the_call_metadata_attribute_is_not_named_metadata():
    """
    `Base.metadata` is SQLAlchemy's MetaData registry. A mapped attribute of
    that name does not shadow it — it fails at class construction — so the
    column is mapped as `call_metadata` and the two must stay distinct.
    """
    assert isinstance(LlmCall.metadata, MetaData)
    assert LlmCall.call_metadata.key == "call_metadata"
    assert LlmCall.call_metadata.expression.name == "metadata"


# --------------------------------------------------------------------------
# Decision 12 — no enum types in the database
# --------------------------------------------------------------------------


@pytest.mark.parametrize("model", [LlmRun, LlmCall, LlmAttempt])
def test_no_table_creates_a_database_enum_type(model):
    assert "CREATE TYPE" not in ddl(model).upper()


@pytest.mark.parametrize(
    "model,name",
    [
        (LlmCall, "status"),
        (LlmCall, "llm_server"),
        (LlmCall, "channel"),
        (LlmCall, "model"),
        (LlmAttempt, "llm_server"),
        (LlmAttempt, "served_provider"),
    ],
)
def test_the_enumerated_columns_are_plain_text(model, name):
    """
    Each of these has a vocabulary, and none of them has it in the database.
    `served_provider` is here for the opposite reason to the others: its
    vocabulary is OpenRouter's, we cannot enumerate it, and an unrecognised
    provider name is a fact about the world rather than a bad row.
    """
    col_type = column(model, name).type
    assert isinstance(col_type, String)
    assert not isinstance(col_type, postgresql.ENUM)


def test_call_status_carries_the_four_values_the_design_lists():
    assert {s.value for s in CallStatus} == {"OK", "STRUCTURE_PROBLEM", "TIMEOUT", "TRANSPORT_PROBLEM"}


def test_call_status_members_are_not_their_own_values():
    """
    Pinned as a reminder rather than as a requirement on `CallStatus`: this is
    the shape `ai_common`'s enums have, and decision 14's rule — repositories
    write `.value` — exists because of it. If `CallStatus` ever gains a `str`
    mixin, one enum in the codebase would behave differently from the rest and
    the rule would need two versions.
    """
    assert CallStatus.OK.value == "OK"
    assert CallStatus.OK != "OK"
    assert str(CallStatus.OK) != "OK"


def test_no_table_carries_a_check_constraint_on_a_vocabulary_column():
    """
    Trap 9 and decision 16. A CHECK on `served_provider` would reject a
    provider OpenRouter has just added, and the row is the evidence.
    """
    for model in (LlmRun, LlmCall, LlmAttempt):
        assert "CHECK" not in ddl(model).upper()


# --------------------------------------------------------------------------
# Null is never zero
# --------------------------------------------------------------------------


@pytest.mark.parametrize(
    "model,name",
    [
        (LlmCall, "cost"),
        (LlmCall, "prompt_tokens"),
        (LlmCall, "completion_tokens"),
        (LlmCall, "reasoning_tokens"),
        (LlmCall, "generation_id"),
        (LlmCall, "finish_reason"),
        (LlmAttempt, "cost"),
        (LlmAttempt, "prompt_tokens"),
        (LlmAttempt, "completion_tokens"),
        (LlmAttempt, "reasoning_tokens"),
        (LlmAttempt, "generation_id"),
        (LlmAttempt, "served_provider"),
        (LlmAttempt, "model_alias"),
        (LlmAttempt, "http_status"),
        (LlmAttempt, "finish_reason"),
    ],
)
def test_every_reported_metric_may_be_null(model, name):
    """
    A NOT NULL here would force a default, and the only available default is a
    lie: zero for a cost nobody reported, or an empty string for a provider
    that never named itself.
    """
    assert column(model, name).nullable is True


@pytest.mark.parametrize(
    "model,name",
    [
        (LlmRun, "entry_point"),
        (LlmRun, "commit_sha"),
        (LlmRun, "git_dirty_paths"),
        (LlmRun, "started_at"),
        (LlmRun, "hostname"),
        (LlmCall, "run_id"),
        (LlmCall, "model"),
        (LlmCall, "llm_server"),
        (LlmCall, "status"),
        (LlmCall, "call_seconds"),
        (LlmCall, "started_at"),
        (LlmCall, "prompt_sha256"),
        (LlmAttempt, "seq"),
        (LlmAttempt, "llm_server"),
        (LlmAttempt, "started_at"),
        (LlmAttempt, "request_seconds"),
    ],
)
def test_what_the_writer_always_knows_is_required(model, name):
    """
    The other half of the doctrine. These are not provider reports — they are
    facts the process holds at the moment it writes the row, so a null in one
    would mean the writer was broken rather than that nobody said.
    """
    assert column(model, name).nullable is False


def test_a_run_in_progress_has_no_finish_time():
    assert column(LlmRun, "finished_at").nullable is True


def test_an_unswept_attempt_has_no_enrichment_time():
    """
    Trap 4. *Not yet swept* and *swept, nothing there* stay distinguishable
    because this is a timestamp rather than a boolean derived from whether the
    enrichment columns came back empty.
    """
    assert column(LlmAttempt, "enriched_at").nullable is True
    for name in ("routing_chain", "native_finish_reason", "generation_time", "latency"):
        assert column(LlmAttempt, name).nullable is True


# --------------------------------------------------------------------------
# Types
# --------------------------------------------------------------------------


@pytest.mark.parametrize("model", [LlmCall, LlmAttempt])
def test_cost_is_exact_rather_than_binary_floating_point(model):
    """
    `SUM(llm_attempt.cost)` is the query the third table exists for. Summing a
    few hundred floats at the fifth significant figure of a cent puts error
    into the number that is meant to settle how much the undercount was.
    """
    cost = column(model, "cost").type
    assert isinstance(cost, Numeric)
    assert not isinstance(cost, Float)
    # Unconstrained NUMERIC in Postgres is arbitrary-precision, so nothing is
    # rounded at write time and no scale has to be guessed now.
    assert cost.precision is None
    assert cost.scale is None


@pytest.mark.parametrize("model", [LlmCall, LlmAttempt])
def test_durations_are_floats_because_they_are_not_money(model):
    name = "call_seconds" if model is LlmCall else "request_seconds"
    assert isinstance(column(model, name).type, Float)


def test_the_failed_output_column_has_no_length_limit():
    """
    Stored in full (decision 10). A limit here would re-create the 300-character
    truncation that lost the one artefact nothing else could recover.
    """
    raw = column(LlmCall, "raw_output").type
    assert isinstance(raw, Text)
    assert raw.length is None


@pytest.mark.parametrize(
    "model,name",
    [
        (LlmRun, "started_at"),
        (LlmRun, "finished_at"),
        (LlmCall, "started_at"),
        (LlmAttempt, "started_at"),
        (LlmAttempt, "enriched_at"),
    ],
)
def test_every_timestamp_carries_its_timezone(model, name):
    """
    Runs may come from more than one machine, and a naive timestamp cannot be
    compared across them — which is precisely the comparison a call log exists
    to support.
    """
    assert column(model, name).type.timezone is True


def test_the_json_columns_are_jsonb_not_json():
    """JSONB so `git_dirty_paths` and `requested_provider` can be queried and
    indexed rather than only retrieved."""
    assert isinstance(column(LlmRun, "git_dirty_paths").type, postgresql.JSONB)
    assert isinstance(column(LlmCall, "requested_provider").type, postgresql.JSONB)
    assert isinstance(column(LlmCall, "metadata").type, postgresql.JSONB)


@pytest.mark.parametrize(
    "model,name",
    [(LlmRun, "run_id"), (LlmCall, "call_id"), (LlmAttempt, "attempt_id")],
)
def test_every_primary_key_generates_its_own_uuid(model, name):
    """
    The wrapper needs the call id *before* the call is made, to put it on the
    contextvar the socket reads. A server-generated key could not be known in
    time.

    Asserted by generating one rather than by identity against `uuid.uuid4`:
    SQLAlchemy wraps a zero-argument callable default so it can be handed the
    execution context, so `default.arg` is never the function that was passed.
    """
    col = column(model, name)
    assert col.primary_key is True
    assert col.default is not None
    assert col.default.is_callable

    generated = col.default.arg({})
    assert isinstance(generated, uuid.UUID)
    assert generated.version == 4
    assert col.default.arg({}) != generated


# --------------------------------------------------------------------------
# Keys, and the one that is deliberately absent
# --------------------------------------------------------------------------


def test_a_call_belongs_to_a_run_and_the_database_enforces_it():
    fks = list(column(LlmCall, "run_id").foreign_keys)
    assert len(fks) == 1
    assert fks[0].target_fullname == "llm_run.run_id"


def test_an_attempt_references_its_call_without_a_foreign_key():
    """
    **Deliberate, and the reason is write ordering.** The socket writes the
    attempt while the request is in flight; the wrapper writes `llm_call` only
    after the call returns, because the row needs the status and the duration.
    So an attempt exists before the call it belongs to, and a foreign key would
    reject it — making the order of writes a database constraint rather than an
    implementation choice.

    The column stays nullable for the other reason: a null means a request made
    outside any wrapper, which is how trap 8 reports itself instead of hiding.
    """
    call_id = column(LlmAttempt, "call_id")
    assert list(call_id.foreign_keys) == []
    assert call_id.nullable is True
    assert call_id.index is True


def test_the_constraint_names_come_from_the_naming_convention():
    """
    Alembic writes these names into migrations, and a later `drop_constraint`
    has to quote one. Letting Postgres invent them means the first migration
    carries names nobody chose and nothing derives.
    """
    assert "CONSTRAINT pk_llm_run PRIMARY KEY" in ddl(LlmRun)
    assert "CONSTRAINT fk_llm_call_run_id_llm_run FOREIGN KEY" in ddl(LlmCall)


# --------------------------------------------------------------------------
# Indexes
# --------------------------------------------------------------------------


def test_the_enrichment_sweep_has_a_partial_index_matching_its_query():
    """
    The sweep reads `WHERE enriched_at IS NULL AND generation_id IS NOT NULL
    AND llm_server = 'openrouter'`. A partial index stays proportional to the
    rows still awaiting enrichment; a full one would grow with a table that
    only ever grows, since nothing is ever deleted.
    """
    index = next(
        ix
        for ix in LlmAttempt.__table__.indexes
        if ix.name == "ix_llm_attempt_pending_enrichment"
    )
    statement = str(CreateIndex(index).compile(dialect=DIALECT))
    assert "WHERE enriched_at IS NULL AND generation_id IS NOT NULL" in statement
    assert "(llm_server)" in statement


def test_the_join_columns_are_indexed():
    assert column(LlmCall, "run_id").index is True
    assert column(LlmAttempt, "call_id").index is True
    assert column(LlmAttempt, "generation_id").index is True


# --------------------------------------------------------------------------
# The models are usable as plain objects
# --------------------------------------------------------------------------


def test_a_row_can_be_built_without_a_session():
    """
    Construction is what the repositories will do, and it must not need a
    connection — which is also what keeps this file hermetic.
    """
    attempt = LlmAttempt(
        call_id=None,
        seq=1,
        llm_server="openrouter",
        started_at=datetime.now().astimezone(),
        generation_id="gen-X0lYRN3z",
        served_provider="Relace",
        cost=Decimal("0.00003026"),
        request_seconds=1.17,
    )
    assert attempt.served_provider == "Relace"
    assert attempt.cost == Decimal("0.00003026")
    # Not populated until the row is flushed — the default is applied by the
    # insert, not by the constructor.
    assert attempt.attempt_id is None
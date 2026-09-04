"""
Unit tests for the Alembic setup, run without Alembic and without a database.

**These tests parse the migration as text.** Nothing here imports ``alembic`` —
it lives in the ``migrations`` dependency group, which ``make test`` does not
install, and putting it in the test group to satisfy a test would put a schema
tool in the environment for the sake of the thing that checks the schema tool.
Nothing here connects either, for the reason ``test_db_engine`` gives at greater
length: a suite that reaches the log corrupts the record it exists to verify.

What is left after those two exclusions is still the check that matters most
often. **The real verification of a migration is `upgrade head` followed by an
autogenerate that comes back empty**, and that needs a live database, a network
and about twenty seconds — so it is a thing someone does deliberately, and
therefore a thing someone can forget. The classic Alembic defect is not a broken
migration; it is a column added to a model by an edit that never generated one.
That defect is visible in the *text* of the two files, and these tests compare
them: every table, every column and every index in ``Base.metadata`` must appear
in the migration chain, and the reverse.

Three things this cannot see, all of which are the live check's job:

- **Types.** ``sa.String()`` in the migration against ``String`` in the model is
  compared here by column *name* only. A type changed on one side and not the
  other passes.
- **Server defaults**, which Alembic does not compare either — see
  ``migrations/env.py`` for why that is deliberate there.
- **The database.** A migration that is a perfect description of the models and
  was never applied passes every test in this file.
"""
import ast
import configparser
from pathlib import Path

import pytest

from src.db.models import Base

REPO_ROOT = Path(__file__).resolve().parent.parent
ALEMBIC_INI = REPO_ROOT / "alembic.ini"

# Written out rather than read from alembic.ini, so that a test asserting the
# ini points at the migration directory is not asking the ini where the
# migration directory is.
MIGRATIONS_DIR = REPO_ROOT / "migrations"
VERSIONS_DIR = MIGRATIONS_DIR / "versions"


def _version_files() -> list[Path]:
    return sorted(p for p in VERSIONS_DIR.glob("*.py") if p.name != "__init__.py")


def _module(path: Path) -> ast.Module:
    return ast.parse(path.read_text(encoding="utf-8"), filename=str(path))


def _assignment(module: ast.Module, name: str):
    """The value of a module-level ``name = ...``, or ``KeyError``."""
    for node in module.body:
        targets = (
            [node.target] if isinstance(node, ast.AnnAssign) else
            node.targets if isinstance(node, ast.Assign) else []
        )
        for target in targets:
            if isinstance(target, ast.Name) and target.id == name:
                return ast.literal_eval(node.value)
    raise KeyError(f"{name} is not assigned at module level")


def _op_calls(module: ast.Module, function: str) -> list[ast.Call]:
    """Every ``op.<something>(...)`` call inside ``function``."""
    for node in module.body:
        if isinstance(node, ast.FunctionDef) and node.name == function:
            return [
                child
                for child in ast.walk(node)
                if isinstance(child, ast.Call)
                and isinstance(child.func, ast.Attribute)
                and isinstance(child.func.value, ast.Name)
                and child.func.value.id == "op"
            ]
    raise KeyError(f"{function}() is not defined")


def _name_argument(node: ast.expr) -> str:
    """
    The string in ``'ix_thing'`` or in ``op.f('ix_thing')``.

    Alembic wraps names that came from the naming convention in ``op.f`` to mark
    them as already-final, and writes explicitly-named ones bare. Both forms
    appear in the same migration.
    """
    if isinstance(node, ast.Constant):
        return node.value
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
        return node.args[0].value
    raise AssertionError(f"unreadable name argument: {ast.dump(node)}")


def _created_tables() -> dict[str, set[str]]:
    """``{table name: {column names}}`` over every ``op.create_table`` there is."""
    created: dict[str, set[str]] = {}
    for path in _version_files():
        for call in _op_calls(_module(path), "upgrade"):
            if call.func.attr != "create_table":
                continue
            table = _name_argument(call.args[0])
            created[table] = {
                item.args[0].value
                for item in call.args[1:]
                if isinstance(item, ast.Call)
                and isinstance(item.func, ast.Attribute)
                and item.func.attr == "Column"
            }
    return created


def _constraint_names() -> set[str]:
    """
    The ``name=`` of every constraint declared inside an ``op.create_table``.

    Read out of the syntax tree rather than searched for in the file, and the
    difference is not fastidiousness: the first version of
    :func:`test_the_naming_convention_reached_the_migration` asserted the names
    were *in the source text*, and mutation showed it passing against a
    migration whose foreign key had been renamed — because the name it was
    looking for also appears in the migration's own docstring. An assertion a
    comment can satisfy is not an assertion about the code.
    """
    names = set()
    for path in _version_files():
        for call in _op_calls(_module(path), "upgrade"):
            if call.func.attr != "create_table":
                continue
            for item in call.args[1:]:
                if not (isinstance(item, ast.Call)
                        and isinstance(item.func, ast.Attribute)
                        and item.func.attr.endswith("Constraint")):
                    continue
                for keyword in item.keywords:
                    if keyword.arg == "name":
                        names.add(_name_argument(keyword.value))
    return names


def _created_indexes() -> set[str]:
    return {
        _name_argument(call.args[0])
        for path in _version_files()
        for call in _op_calls(_module(path), "upgrade")
        if call.func.attr == "create_index"
    }


@pytest.fixture(autouse=True)
def _single_migration_assumption():
    """
    The model-versus-migration tests below fold ``create_table`` calls and
    nothing else, so they describe the schema correctly only while the chain is
    the initial migration alone. The second migration will be an ``add_column``
    or an ``alter_column``, and folding those means reimplementing Alembic
    inside the test suite — which is not worth it and would not be trustworthy.

    So this fails, loudly and with an explanation, the moment the assumption
    stops holding. **A skip would be wrong**: a skipped check reads exactly like
    a passed one in a summary line, which is a mistake this project has already
    made once with its mutation sweep. Whoever writes migration number two
    should delete the three tests that depend on this and rely on the live
    empty-autogenerate check, which by then is the only honest one.
    """
    count = len(_version_files())
    assert count == 1, (
        f"{count} migrations found. The model-versus-migration comparison in "
        "this file understands create_table only — see the fixture's docstring."
    )


def test_alembic_ini_points_at_the_migration_directory():
    parser = configparser.ConfigParser()
    parser.read(ALEMBIC_INI)

    assert parser.get("alembic", "script_location") == "migrations"
    assert (MIGRATIONS_DIR / "env.py").is_file()
    assert (MIGRATIONS_DIR / "script.py.mako").is_file()
    # Without this, `import src.db.models` inside env.py fails and autogenerate
    # writes a migration dropping every table.
    assert parser.get("alembic", "prepend_sys_path") == "."


def test_alembic_ini_carries_no_connection_string():
    """
    Trap 6, in the file most likely to break it.

    ``alembic init`` writes a ``sqlalchemy.url`` line with a placeholder in it,
    and the natural way to make the command work is to paste the real URL over
    the placeholder. ``alembic.ini`` is committed and ``DB_URL`` holds a
    password. The failure is unrecoverable in the way every leaked credential
    is: it is in the history whether or not it is in the file.
    """
    parser = configparser.ConfigParser()
    parser.read(ALEMBIC_INI)

    assert not parser.has_option("alembic", "sqlalchemy.url")
    # Any URL at all, placeholder included — the placeholder is what invites the
    # paste. Comments are part of the file for this purpose.
    assert "://" not in ALEMBIC_INI.read_text(encoding="utf-8")


def test_the_revision_chain_is_single_and_unbranched():
    """
    One root, one head, no duplicates, nothing orphaned.

    Two heads is the failure that matters, and it happens without anyone doing
    anything strange: two branches each autogenerate a revision against the same
    parent, both merge, and `upgrade head` then refuses to run at all.
    """
    revisions = {}
    for path in _version_files():
        module = _module(path)
        revisions[_assignment(module, "revision")] = _assignment(
            module, "down_revision"
        )

    assert len(revisions) == len(_version_files()), "duplicate revision id"

    roots = [rev for rev, down in revisions.items() if down is None]
    assert len(roots) == 1, f"expected one root revision, found {roots}"

    parents = [down for down in revisions.values() if down is not None]
    assert len(parents) == len(set(parents)), "two revisions share a parent"
    assert set(parents) <= set(revisions), "a down_revision names no known revision"

    heads = set(revisions) - set(parents)
    assert len(heads) == 1, f"expected one head, found {sorted(heads)}"


def test_every_model_table_is_created_by_a_migration():
    assert set(_created_tables()) == set(Base.metadata.tables)


def test_every_model_column_is_created_by_a_migration():
    """
    Column-by-column, which is the check that catches the ordinary mistake:
    a column added to ``llm_log.py`` by an edit that never ran autogenerate.

    ``column.name`` and not ``column.key``. They differ for exactly one column
    in this schema — ``llm_call``'s ``metadata``, which is mapped under the
    Python name ``call_metadata`` because ``Base.metadata`` owns the attribute —
    and a comparison written against ``.key`` would report that the migration is
    missing a ``call_metadata`` column and creating a stray ``metadata`` one.
    """
    created = _created_tables()
    for name, table in Base.metadata.tables.items():
        assert created[name] == {column.name for column in table.columns}, name


def test_every_model_index_is_created_by_a_migration():
    """
    Including the partial one, whose absence would be silent: the enrichment
    sweep runs correctly without ``ix_llm_attempt_pending_enrichment`` and only
    gets slower, in proportion to a table nothing is ever deleted from.
    """
    expected = {
        index.name for table in Base.metadata.tables.values() for index in table.indexes
    }
    assert _created_indexes() == expected


def test_the_naming_convention_reached_the_migration():
    """
    Spot-checked against literals, because this is the property that had to be
    right on day one and cannot be fixed later without renaming every constraint
    in a live database.

    The names below are written out rather than derived from
    ``NAMING_CONVENTION``: a test that builds its expectation with the same
    format string the code uses agrees with the code about any convention,
    including a wrong one. Postgres's own names for these — ``llm_run_pkey``,
    ``llm_call_run_id_fkey`` — are what appears when the convention is missing,
    and they are what a later ``op.drop_constraint`` would have to quote.
    """
    assert {"pk_llm_run", "pk_llm_call", "pk_llm_attempt"} <= _constraint_names()
    assert "fk_llm_call_run_id_llm_run" in _constraint_names()
    assert "ix_llm_call_run_id" in _created_indexes()


def test_env_py_guards_every_autogenerate_it_configures():
    """
    Both ``context.configure`` calls must pass ``include_object``, and both must
    ask for type comparison.

    **This is a text check and it is worth saying so.** It cannot run
    ``env.py`` — that imports ``alembic``, which the test environment does not
    have — so it reads the syntax tree and asserts the arguments are there. It
    would not notice ``include_object`` being changed to something that lets
    everything through.

    It is here because deleting the argument is the plausible mistake and its
    consequence is not visible in the migration that causes it. Measured
    2026-08-26 against the live instance: with a table in ``public`` that this
    project does not declare, autogenerate with the guard produced an empty
    migration, and the same run without it produced
    ``op.drop_table('zz_include_object_probe')``. The database is a Supabase
    project, not a private instance — a migration that applies cleanly and
    deletes somebody else's table is the failure being guarded against.
    """
    module = _module(MIGRATIONS_DIR / "env.py")
    configures = [
        node
        for node in ast.walk(module)
        if isinstance(node, ast.Call)
        and isinstance(node.func, ast.Attribute)
        and node.func.attr == "configure"
        and isinstance(node.func.value, ast.Name)
        and node.func.value.id == "context"
    ]
    # Offline and online. A third would want its own reason to exist.
    assert len(configures) == 2

    for call in configures:
        keywords = {kw.arg: kw.value for kw in call.keywords}
        assert "include_object" in keywords
        assert ast.literal_eval(keywords["compare_type"]) is True


def test_every_created_table_is_dropped_by_the_downgrade():
    """
    The half of a migration nobody runs until the day it is the only thing that
    helps. Autogenerate writes both directions; a hand-edit tends to fix one.
    """
    dropped = {
        _name_argument(call.args[0])
        for path in _version_files()
        for call in _op_calls(_module(path), "downgrade")
        if call.func.attr == "drop_table"
    }
    assert dropped == set(_created_tables())
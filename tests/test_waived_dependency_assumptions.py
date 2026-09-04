"""Guards for the claims six GuardDog waivers rest on.

Six waivers in the machine-wide GuardDog store are classified *real
behaviour, accepted in context*. Unlike a rule defect, they do not say the
matched code is harmless. They say **we never reach it**:

| waiver | the behaviour that is real |
|---|---|
| `typer==0.24.2`, `typer==0.26.8` | `--install-completion` appends to `~/.bashrc` and `~/.zshrc` |
| `huggingface-hub==1.24.0`, `==1.27.0`, `==1.28.0` | `hf update` self-updates via `subprocess.call`, one branch being `curl … \\| bash` |
| `torch==2.13.0` | `format_flamegraph` fetches `flamegraph.pl` from an unpinned `master` URL, `chmod 0o755`, then executes it — and re-executes the cached copy unverified |

Every one of those was accepted because nothing in this repository calls it.
That is a claim about **this repository**, not about the package.

Waivers are keyed on `(name, version)`, so a waiver re-opens when the *package*
changes and never when *we* do. Nothing else notices if someone adds
`import typer`, invokes the `hf` CLI, or profiles CUDA memory: the premise
evaporates, the waiver keeps applying, and the gate keeps passing. These tests
are the only thing standing between that and a silent pass.

**If one of these fails, the waiver is what needs re-reviewing — not the
assertion.** Run `uv run guarddog-review` in `ai-common`, re-read the finding
against `~/.cache/guarddog-cached/accepted.json`, and decide again. Deleting a
line here converts a reviewed decision back into an unexamined one.

Known gaps, so nobody reads more into a pass than is there. The scan is static
and name-based: it cannot see `getattr(module, "format_flamegraph")`,
`importlib.import_module("typer")`, or a CLI invoked through a computed argv.
It covers `src/` and `tests/` only. It proves the obvious routes are closed,
not that no route exists.
"""

import ast
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]

# `src/` is the application (including `src/scripts/`); `tests/` matters too,
# because a test that invoked `--install-completion` would append to the
# developer's real shell rc file just as readily as the application would.
SCANNED_ROOTS = (PROJECT_ROOT / "src", PROJECT_ROOT / "tests")

# This module names every forbidden symbol as a literal, so it would match
# itself.
THIS_FILE = Path(__file__).resolve()


def _python_files():
    for root in SCANNED_ROOTS:
        for path in sorted(root.rglob("*.py")):
            if path.resolve() == THIS_FILE or "__pycache__" in path.parts:
                continue
            yield path


def _trees():
    for path in _python_files():
        yield path, ast.parse(path.read_text(encoding="utf-8"), filename=str(path))


def _imported_names(tree):
    """Every dotted module name the tree's import statements name.

    `from torch.cuda import _memory_viz` yields both `torch.cuda` and
    `torch.cuda._memory_viz`, so a prefix test catches the package whichever
    way it was spelled. Relative imports are skipped: they can only reach this
    project's own modules.
    """
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                yield node.lineno, alias.name
        elif isinstance(node, ast.ImportFrom) and node.module and not node.level:
            yield node.lineno, node.module
            for alias in node.names:
                yield node.lineno, f"{node.module}.{alias.name}"


def _attribute_and_name_uses(tree):
    """Bare names and attribute names, so `x.foo()` and `foo()` both register."""
    for node in ast.walk(tree):
        if isinstance(node, ast.Name):
            yield node.lineno, node.id
        elif isinstance(node, ast.Attribute):
            yield node.lineno, node.attr


def _string_constants(tree):
    for node in ast.walk(tree):
        if isinstance(node, ast.Constant) and isinstance(node.value, str):
            yield node.lineno, node.value


def _offenders(extractor, matches):
    found = []
    for path, tree in _trees():
        for lineno, value in extractor(tree):
            if matches(value):
                found.append(f"{path.relative_to(PROJECT_ROOT)}:{lineno}  {value}")
    return found


def _imports_of(package):
    return _offenders(
        _imported_names,
        lambda name: name == package or name.startswith(f"{package}."),
    )


def _waiver_broken(package_version, behaviour, found):
    return (
        f"The waiver for {package_version} rests on this repository never "
        f"reaching {behaviour}. That is no longer true:\n"
        + "\n".join(f"  {line}" for line in found)
        + "\n\nRe-review the waiver rather than relaxing this test: "
        "`uv run guarddog-review` in ai-common, then "
        "~/.cache/guarddog-cached/accepted.json."
    )


def test_typer_is_never_imported():
    found = _imports_of("typer")

    assert not found, _waiver_broken(
        "typer==0.24.2 and typer==0.26.8",
        "typer, whose --install-completion writes to ~/.bashrc and ~/.zshrc",
        found,
    )


def test_the_shell_completion_installer_is_never_invoked():
    """Covers the subprocess route, which an import check cannot see.

    `--install-completion` is typer's and huggingface_hub's own flag spelling,
    so a literal occurrence of it is the one reliable sign that some CLI is
    being asked to rewrite a shell rc file, whether or not the library is
    imported here.
    """
    flag = "--install-completion"
    found = _offenders(_string_constants, lambda value: flag in value)

    assert not found, _waiver_broken(
        "typer and huggingface-hub",
        f"a CLI's {flag}, which appends to ~/.bashrc and ~/.zshrc",
        found,
    )


def test_the_huggingface_hub_cli_is_never_imported():
    found = _imports_of("huggingface_hub.cli")

    assert not found, _waiver_broken(
        "huggingface-hub==1.24.0, ==1.27.0 and ==1.28.0",
        "huggingface_hub.cli, which carries the `hf update` self-updater "
        "(subprocess.call, one branch being `curl … | bash`)",
        found,
    )


def test_importing_huggingface_hub_does_not_pull_in_its_cli():
    """The other half of the premise, which is the package's behaviour.

    The waiver records that the `.cli` import in `huggingface_hub/__init__.py`
    sits under `if TYPE_CHECKING:`, so library use never loads the self-updater.
    A future release that imports it eagerly would break the waiver without any
    change on our side. Run in a subprocess so an earlier test cannot have
    populated `sys.modules` first.
    """
    probe = (
        "import sys, huggingface_hub; "
        "print(','.join(m for m in sys.modules if m.startswith('huggingface_hub.cli')))"
    )
    result = subprocess.run(
        [sys.executable, "-c", probe],
        capture_output=True,
        text=True,
        timeout=120,
    )

    assert result.returncode == 0, f"probe failed:\n{result.stdout}{result.stderr}"
    loaded = [name for name in result.stdout.strip().split(",") if name]

    assert not loaded, _waiver_broken(
        "huggingface-hub==1.24.0, ==1.27.0 and ==1.28.0",
        "huggingface_hub.cli — importing the library now loads it eagerly",
        loaded,
    )


def test_the_cuda_memory_visualisers_are_never_reached():
    """`format_flamegraph` is named; its three callers are caught by import.

    `segments`, `memory` and `compare` default to `format_flamegraph` and so
    reach the download too, but those names are far too generic to forbid
    outright — `memory` alone would fire on unrelated code. They are only
    dangerous when taken from `torch.cuda._memory_viz`, which the import check
    covers.
    """
    found = _imports_of("torch.cuda._memory_viz") + _offenders(
        _attribute_and_name_uses, lambda name: name == "format_flamegraph"
    )

    assert not found, _waiver_broken(
        "torch==2.13.0",
        "torch.cuda._memory_viz.format_flamegraph, which downloads "
        "flamegraph.pl from an unpinned master URL, chmod 0o755 and executes it",
        found,
    )
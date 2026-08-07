"""
Tests for `chunk_store.git_state`, the provenance half of a chunk snapshot.

`git_dirty_paths` is what decides whether a snapshot is usable as a baseline:
`git_dirty` is repo-wide, so an uncommitted devlog and an uncommitted
`gdpr_parser.py` set the same flag and carry opposite verdicts. The paths are
the only thing that separates them, which makes recording them *exactly* a
correctness requirement rather than a nicety.

It was not exact. `run()` returned `result.stdout.strip()`, which is right for
`rev-parse` but wrong for `status --porcelain`: the first column is the index
status and is a space for a worktree-only change, so the first line reads
`" M uv.lock"`. Stripping shifted it left and the `line[3:]` slice then ate a
character of the path, recording `"v.lock"` — a file that does not exist. Only
the first line was affected, and only when its index column was blank, which is
why the hand-verification across six tree states on 2026-08-06 missed it.

These use a real git repository in `tmp_path` rather than a mocked subprocess.
Mocking would have encoded the same wrong belief about porcelain's format that
the bug came from, and so would have passed against the broken code.
"""
import subprocess
from pathlib import Path

import pytest

from src.clause_and_effect.chunk_store import git_state


def _git(repo: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args], cwd=repo, capture_output=True, text=True, check=True,
    )
    return result.stdout


@pytest.fixture
def repo(tmp_path: Path) -> Path:
    """A real repository with one commit, so HEAD resolves."""
    _git(tmp_path, "init", "-q")
    # Local config only: must not depend on, or touch, the developer's global git.
    _git(tmp_path, "config", "user.email", "test@example.invalid")
    _git(tmp_path, "config", "user.name", "Test")
    (tmp_path / "uv.lock").write_text("original\n", encoding="utf-8")
    (tmp_path / "keep.txt").write_text("original\n", encoding="utf-8")
    _git(tmp_path, "add", ".")
    _git(tmp_path, "commit", "-q", "-m", "initial")
    return tmp_path


def test_clean_tree_reports_no_dirty_paths(repo: Path) -> None:
    commit, dirty = git_state(repo)

    assert dirty == []
    assert commit == _git(repo, "rev-parse", "HEAD").strip()
    # The commit must be usable as an identifier, not carry stray whitespace —
    # `run` no longer strips, so this is the call site's job now.
    assert len(commit) == 40 and commit == commit.strip()


def test_worktree_modification_records_the_exact_path(repo: Path) -> None:
    """
    The regression. An unstaged edit is porcelain `" M uv.lock"` — leading
    space — and it is the *first* line, which is the only position `.strip()`
    could corrupt.
    """
    (repo / "uv.lock").write_text("changed\n", encoding="utf-8")

    _, dirty = git_state(repo)

    assert dirty == ["uv.lock"]


def test_every_dirty_path_names_a_real_file(repo: Path) -> None:
    """
    The property the bug actually violated, stated directly: a recorded path
    must exist. `"v.lock"` passed a "non-empty list" check and failed this one.
    """
    (repo / "uv.lock").write_text("changed\n", encoding="utf-8")
    (repo / "keep.txt").write_text("changed\n", encoding="utf-8")
    (repo / "untracked.md").write_text("new\n", encoding="utf-8")

    _, dirty = git_state(repo)

    assert sorted(dirty) == ["keep.txt", "untracked.md", "uv.lock"]
    for path in dirty:
        assert (repo / path).exists(), f"manifest names a path that does not exist: {path}"


def test_staged_and_untracked_paths_survive(repo: Path) -> None:
    """
    Untracked lines are `"?? path"` with no leading space and were never
    corrupted, so they are the control: they pin that the fix did not simply
    move the off-by-one somewhere else.
    """
    (repo / "untracked.md").write_text("new\n", encoding="utf-8")
    (repo / "keep.txt").write_text("staged\n", encoding="utf-8")
    _git(repo, "add", "keep.txt")

    _, dirty = git_state(repo)

    assert sorted(dirty) == ["keep.txt", "untracked.md"]


def test_deleted_file_is_reported_by_name(repo: Path) -> None:
    """A deletion is `" D path"` — same blank index column as a modification."""
    (repo / "uv.lock").unlink()

    _, dirty = git_state(repo)

    assert dirty == ["uv.lock"]


@pytest.mark.parametrize("name", ["a file.txt", "é.txt", "quote\"d.txt"])
def test_awkward_filenames_are_recorded_literally(repo: Path, name: str) -> None:
    """
    Plain `--porcelain` C-quotes any path with a space or non-ASCII byte, so it
    reported `'"a file.txt"'` — quotes included, naming a file that does not
    exist. Latent in this repo, but the same defect as the leading-space bug and
    caught by the same property, which is why `-z` is used instead of an
    unescaper. Slicing at a fixed column also survives spaces where splitting on
    whitespace would not.
    """
    (repo / name).write_text("new\n", encoding="utf-8")

    _, dirty = git_state(repo)

    assert dirty == [name]
    assert (repo / dirty[0]).exists()


def test_rename_records_both_paths(repo: Path) -> None:
    """A rename is two `-z` records; the old path must not become its own entry."""
    _git(repo, "mv", "keep.txt", "renamed.txt")

    _, dirty = git_state(repo)

    assert dirty == ["keep.txt -> renamed.txt"]


def test_missing_git_repository_reads_as_dirty(tmp_path: Path) -> None:
    """
    An unverifiable tree must never look reproducible, so the failure mode is
    "dirty with a reason" rather than an empty list.
    """
    commit, dirty = git_state(tmp_path / "not-a-repo")

    assert commit == "unknown"
    assert dirty == ["<git unavailable>"]
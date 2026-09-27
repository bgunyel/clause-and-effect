"""
Tests for `.github/scripts/check_hooks_ci.py`, the helper the `check-hooks`
workflow runs around the hook check suite (#199).

Two claims are under test, and each is what a green CI run rests on:

- `verify-merge` says the commit under test is the merge result of the pull
  request against its base's *current* tip. A check that passed on a merge
  commit built on a stale base is the 51-minute defect of PR #196 wearing a
  green badge, so every way the tested commit can be the wrong one is a case
  here: not a merge, a different head, a base that has moved since GitHub
  computed the merge, and a shallow clone, which is how `actions/checkout`
  fetches and which hides a commit's parents from `git rev-list`.
- `report` says what the suite's log says. Its counts are the machine-readable
  record of a run that #193 will work from, and its summary is what a reviewer
  reads instead of the log, so it must never report fewer failures than the log
  holds, nor a pass the suite did not print, nor lose the summary to GitHub's
  1 MiB cap.

The script is run as a process, the way the workflow runs it. Every expected
count, output line and message is written here as a literal; none is obtained
from the script. The git fixtures are local repositories under `tmp_path` and
nothing reaches a network.
"""
import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parent.parent / ".github" / "scripts" / "check_hooks_ci.py"

# The workflow runs this script with the runner's `python3`, not this project's
# 3.13: ubuntu-24.04 ships 3.12, which every check-hooks run logs from its
# verify step. Run under `sys.executable`, a 3.13-only construct would pass
# here and fail there -- the harness more capable than the runner (#206,
# round 2). So the script is run by a 3.12, and its absence fails, not skips.
RUNNER_PYTHON = shutil.which("python3.12")

GIT_ENV = {
    **os.environ,
    "GIT_AUTHOR_NAME": "checks",
    "GIT_AUTHOR_EMAIL": "checks@example.invalid",
    "GIT_COMMITTER_NAME": "checks",
    "GIT_COMMITTER_EMAIL": "checks@example.invalid",
    "GIT_CONFIG_GLOBAL": os.devnull,
    "GIT_CONFIG_NOSYSTEM": "1",
}


def run_script(*args, cwd=None):
    assert RUNNER_PYTHON, "python3.12, the runner's python3, is needed to run check_hooks_ci.py as CI does"
    return subprocess.run(
        [RUNNER_PYTHON, str(SCRIPT), *args],
        cwd=cwd, env=GIT_ENV, capture_output=True, text=True,
    )


def git(cwd, *args):
    out = subprocess.run(
        ["git", *args], cwd=cwd, env=GIT_ENV, capture_output=True, text=True, check=True,
    )
    return out.stdout.strip()


# --------------------------------------------------------------------------- #
# verify-merge
# --------------------------------------------------------------------------- #

@pytest.fixture
def merge_repo(tmp_path):
    """
    An "origin" holding a base branch `dev-05`, a head branch `feature`, and the
    merge of the one into the other at `refs/pull/7/merge` -- where GitHub keeps
    a pull request's test merge. Returns the origin and the three commit ids.
    """
    origin = tmp_path / "origin"
    origin.mkdir()
    git(origin, "init", "-q", "-b", "dev-05")
    git(origin, "commit", "-q", "--allow-empty", "-m", "base")
    base = git(origin, "rev-parse", "HEAD")
    git(origin, "switch", "-q", "-c", "feature")
    git(origin, "commit", "-q", "--allow-empty", "-m", "feature work")
    head = git(origin, "rev-parse", "HEAD")
    git(origin, "switch", "-q", "--detach", "dev-05")
    git(origin, "merge", "-q", "--no-ff", "-m", "Merge feature into dev-05", "feature")
    merge = git(origin, "rev-parse", "HEAD")
    git(origin, "update-ref", "refs/pull/7/merge", merge)
    git(origin, "switch", "-q", "dev-05")
    return origin, base, head, merge


def checkout(tmp_path, origin, ref, depth=None):
    """Fetch `ref` from origin into a fresh repository and detach on it, as
    actions/checkout does."""
    work = tmp_path / "work"
    work.mkdir()
    git(work, "init", "-q", "-b", "unused")
    git(work, "remote", "add", "origin", origin.as_uri())
    fetch = ["fetch", "-q", "--no-tags"]
    if depth:
        fetch += [f"--depth={depth}"]
    git(work, *fetch, "origin", f"+{ref}:refs/remotes/pull/merge")
    git(work, "checkout", "-q", "--detach", "refs/remotes/pull/merge")
    return work


def test_verify_merge_accepts_the_merge_of_head_into_the_current_base(tmp_path, merge_repo):
    origin, base, head, merge = merge_repo
    work = checkout(tmp_path, origin, "refs/pull/7/merge")
    out_file = tmp_path / "github_output"

    result = run_script("verify-merge", "--head-sha", head, "--base-ref", "dev-05",
                        "--output", str(out_file), cwd=work)

    assert result.returncode == 0, result.stdout + result.stderr
    assert result.stdout.splitlines() == [
        f"tested commit:          {merge}",
        f"  first parent (base):  {base}",
        f"  second parent (head): {head}",
        f"  dev-05 on origin now: {base}",
        "the tested commit is the merge of the pull request's head into its base's current tip",
    ]
    assert out_file.read_text().splitlines() == [
        f"tested_commit={merge}",
        f"base_parent={base}",
        f"head_parent={head}",
    ]


def test_verify_merge_reads_parents_through_a_shallow_clone(tmp_path, merge_repo):
    """
    actions/checkout fetches at depth 1, and at depth 1 a commit is a shallow
    boundary whose parents `git rev-list --parents` does not print. The parents
    must be read from the commit object itself, or every run fails -- or, worse,
    a check written to tolerate no parents passes everything.
    """
    origin, base, head, merge = merge_repo
    work = checkout(tmp_path, origin, "refs/pull/7/merge", depth=1)
    assert git(work, "rev-list", "--parents", "-n", "1", "HEAD") == merge  # the premise

    result = run_script("verify-merge", "--head-sha", head, "--base-ref", "dev-05", cwd=work)

    assert result.returncode == 0, result.stdout + result.stderr
    assert f"  first parent (base):  {base}" in result.stdout.splitlines()


def test_verify_merge_refuses_a_merge_built_on_a_base_that_has_since_moved(tmp_path, merge_repo):
    """The PR #196 shape: the base advanced and the merge under test predates it."""
    origin, base, head, merge = merge_repo
    work = checkout(tmp_path, origin, "refs/pull/7/merge")
    git(origin, "commit", "-q", "--allow-empty", "-m", "dev-05 moves on")
    moved = git(origin, "rev-parse", "HEAD")

    result = run_script("verify-merge", "--head-sha", head, "--base-ref", "dev-05", cwd=work)

    assert result.returncode == 1
    assert (
        f"::error::the tested commit is built on {base}, but dev-05 on origin is now at "
        f"{moved}: this is not the merge result of the pull request as it stands. "
        "GitHub has not recomputed the merge ref: it rebuilds it some seconds after "
        "the base moves, and not at all while the pull request conflicts with its base"
    ) in result.stdout.splitlines()


def test_verify_merge_refuses_a_merge_of_a_different_head(tmp_path, merge_repo):
    origin, base, head, merge = merge_repo
    work = checkout(tmp_path, origin, "refs/pull/7/merge")
    other = "0" * 40

    result = run_script("verify-merge", "--head-sha", other, "--base-ref", "dev-05", cwd=work)

    assert result.returncode == 1
    assert (
        f"::error::the tested commit merges {head}, but the pull request's head is {other}"
    ) in result.stdout.splitlines()


def test_verify_merge_refuses_a_commit_that_is_not_a_merge(tmp_path, merge_repo):
    """A checkout of the head, or of the base, is exactly the branch-tip run
    #199 was filed to replace."""
    origin, base, head, merge = merge_repo
    work = checkout(tmp_path, origin, "refs/heads/feature")

    result = run_script("verify-merge", "--head-sha", head, "--base-ref", "dev-05", cwd=work)

    assert result.returncode == 1
    assert (
        f"::error::the tested commit {head} has 1 parent(s), not 2: it is not a merge "
        "result, so this run would test a branch tip"
    ) in result.stdout.splitlines()


def test_verify_merge_refuses_a_base_branch_origin_does_not_have(tmp_path, merge_repo):
    origin, base, head, merge = merge_repo
    work = checkout(tmp_path, origin, "refs/pull/7/merge")

    result = run_script("verify-merge", "--head-sha", head, "--base-ref", "dev-99", cwd=work)

    assert result.returncode == 1
    assert (
        "::error::origin has no branch dev-99, so nothing can say whether the tested "
        "commit is built on its tip"
    ) in result.stdout.splitlines()


# --------------------------------------------------------------------------- #
# report
# --------------------------------------------------------------------------- #

PASSING_LOG = """\
=== the tokeniser itself ===
  ok   ALLOW 'a plain push'
  ok   BLOCK 'a forced push'
--- this repository ---
  ok   the suite has not outgrown the measurement

ALL CHECKS PASSED
"""

FAILING_LOG = """\
=== the tokeniser itself ===
  ok   ALLOW 'a plain push'
  FAIL BLOCK 'a forced push' (got ALLOW)
           hook stderr: nothing
           exit status: 0
  ok   BLOCK 'a mirror push'
--- this repository ---
  FAIL the requirements program printed no finding at all

SOME CHECKS FAILED
"""


def report(tmp_path, log_text, exit_status, seconds="204", outcome="success"):
    """`exit_status=None` is a suite step that wrote none: it was stopped.
    `seconds=None` is one that never wrote `started`: the suite never began."""
    log = tmp_path / "check-hooks.log"
    log.write_text(log_text)
    paths = {name: tmp_path / name for name in ("result.json", "summary.md", "github_output")}
    status_args = [] if exit_status is None else ["--exit-status", str(exit_status)]
    seconds_args = [] if seconds is None else ["--seconds", seconds]
    result = run_script(
        "report", "--log", str(log), *status_args, "--suite-outcome", outcome,
        *seconds_args, "--tested-commit", "abc123",
        "--json", str(paths["result.json"]), "--summary", str(paths["summary.md"]),
        "--output", str(paths["github_output"]),
    )
    return result, paths


def test_report_counts_a_passing_run(tmp_path):
    result, paths = report(tmp_path, PASSING_LOG, 0)

    assert result.returncode == 0, result.stdout + result.stderr
    assert json.loads(paths["result.json"].read_text()) == {
        "results": 3,
        "passed": 3,
        "failed": 0,
        "seconds": 204,
        "exit_status": 0,
        "ended": "exited",
        "verdict": "ALL CHECKS PASSED",
        "tested_commit": "abc123",
    }
    assert paths["github_output"].read_text().splitlines() == [
        "results=3",
        "passed=3",
        "failed=0",
        "seconds=204",
        "exit_status=0",
        "ended=exited",
    ]
    summary = paths["summary.md"].read_text()
    assert summary.startswith("## check-hooks: passed\n")
    assert "| results | passed | failed | seconds | exit status | ended | tested commit |" \
        in summary.splitlines()
    assert "| 3 | 3 | 0 | 204 | 0 | exited | `abc123` |" in summary.splitlines()
    assert "Failing rows" not in summary


def test_report_puts_every_failing_row_and_its_detail_in_the_summary(tmp_path):
    result, paths = report(tmp_path, FAILING_LOG, 1)

    assert result.returncode == 0, result.stdout + result.stderr
    data = json.loads(paths["result.json"].read_text())
    assert (data["results"], data["passed"], data["failed"]) == (4, 2, 2)
    assert data["verdict"] == "SOME CHECKS FAILED"

    summary = paths["summary.md"].read_text()
    assert summary.startswith("## check-hooks: FAILED\n")
    assert "### Failing rows (2)" in summary.splitlines()
    assert (
        "```text\n"
        "  FAIL BLOCK 'a forced push' (got ALLOW)\n"
        "    hook stderr: nothing\n"
        "    exit status: 0\n"
        "  FAIL the requirements program printed no finding at all\n"
        "```\n"
    ) in summary


def test_report_shows_the_log_tail_when_the_suite_fails_without_a_failing_row(tmp_path):
    """A fixture guard stops the suite with `exit 1` and a message on stderr,
    before any row is printed. The summary must say so rather than show an empty
    list of failures under a red badge."""
    log = "fixtures were not created; git init -b needs git 2.28 or newer\n"
    result, paths = report(tmp_path, log, 1)

    assert result.returncode == 0, result.stdout + result.stderr
    summary = paths["summary.md"].read_text()
    assert summary.startswith("## check-hooks: FAILED\n")
    assert "The suite exited 1 without printing a failing row. The end of its log:" in summary
    assert "fixtures were not created; git init -b needs git 2.28 or newer\n" in summary


@pytest.mark.parametrize(
    ("log_text", "exit_status", "problems"),
    [
        # Two problems at once: failing rows, and a verdict that is not the
        # pass. Each is its own annotation and its own line of the summary.
        (FAILING_LOG, 0,
         ["the suite exited 0 but its log holds 2 failing row(s)",
          "the suite exited 0 but its log does not end with ALL CHECKS PASSED"]),
        (PASSING_LOG.replace("ALL CHECKS PASSED", ""), 0,
         ["the suite exited 0 but its log does not end with ALL CHECKS PASSED"]),
        ("\nALL CHECKS PASSED\n", 0,
         ["the suite exited 0 but its log holds no result row at all"]),
        # A suite that printed nothing at all: no row, and no verdict either.
        ("", 0,
         ["the suite exited 0 but its log holds no result row at all",
          "the suite exited 0 but its log does not end with ALL CHECKS PASSED"]),
    ],
    ids=["exit-0-with-fails", "exit-0-without-verdict", "exit-0-with-no-rows",
         "exit-0-with-an-empty-log"],
)
def test_report_refuses_a_pass_the_log_does_not_support(tmp_path, log_text, exit_status, problems):
    """The job's colour comes from the suite's exit status. These are the cases
    where that status and the log disagree, and a green job would be the lie.
    Every problem found is annotated and printed in the summary, not only the
    first."""
    result, paths = report(tmp_path, log_text, exit_status)

    assert result.returncode == 1
    assert [line for line in result.stdout.splitlines() if line.startswith("::error::")] == [
        f"::error::{problem}" for problem in problems]
    summary = paths["summary.md"].read_text()
    assert [line for line in summary.splitlines() if line.startswith("**")] == [
        f"**{problem}**" for problem in problems]
    assert summary.startswith("## check-hooks: FAILED\n")


def test_report_fences_a_failing_row_that_carries_backticks(tmp_path):
    """Hook stderr can quote a command in markdown backticks; a row holding a
    triple backtick must not close the summary's code block early."""
    log = "  FAIL BLOCK 'fenced' (got ALLOW)\n           stderr: ```git push```\n\nSOME CHECKS FAILED\n"
    result, paths = report(tmp_path, log, 1)

    assert result.returncode == 0, result.stdout + result.stderr
    assert (
        "````text\n"
        "  FAIL BLOCK 'fenced' (got ALLOW)\n"
        "    stderr: ```git push```\n"
        "````\n"
    ) in paths["summary.md"].read_text()


def test_verify_merge_refuses_when_the_base_tip_cannot_be_read(tmp_path, merge_repo):
    """An unreadable remote must be an annotated failure, not a traceback."""
    origin, base, head, merge = merge_repo
    work = checkout(tmp_path, origin, "refs/pull/7/merge")
    git(work, "remote", "set-url", "origin", (tmp_path / "gone").as_uri())

    result = run_script("verify-merge", "--head-sha", head, "--base-ref", "dev-05", cwd=work)

    assert result.returncode == 1
    assert any(
        line.startswith("::error::could not read dev-05's tip from origin, so nothing can "
                        "say whether the tested commit is built on it: ")
        for line in result.stdout.splitlines()
    ), result.stdout + result.stderr
    assert "Traceback" not in result.stderr


def test_report_bounds_the_summary_by_bytes_and_says_what_it_left_out(tmp_path):
    """
    GitHub refuses a step summary over 1 MiB and loses all of it. Three rows of
    300 KiB each: two fit under the 512 KiB budget only if the budget is in
    bytes and not rows -- here the first alone fits, the second would pass it.
    """
    detail = "       " + "x" * (300 * 1024)
    log = "".join(f"  FAIL row {i}\n{detail}\n" for i in range(3)) + "\nSOME CHECKS FAILED\n"
    result, paths = report(tmp_path, log, 1)

    assert result.returncode == 0, result.stdout + result.stderr
    summary = paths["summary.md"].read_text()
    assert len(summary.encode("utf-8")) < 1024 * 1024
    assert "  FAIL row 0" in summary.splitlines()
    assert "  FAIL row 1" not in summary.splitlines()
    assert "2 more failing row(s) are in the uploaded log." in summary.splitlines()
    assert json.loads(paths["result.json"].read_text())["failed"] == 3


def test_report_says_every_row_was_left_out_when_the_first_is_over_budget(tmp_path):
    detail = "       " + "x" * (600 * 1024)
    log = f"  FAIL huge\n{detail}\n\nSOME CHECKS FAILED\n"
    result, paths = report(tmp_path, log, 1)

    assert result.returncode == 0, result.stdout + result.stderr
    summary = paths["summary.md"].read_text()
    assert len(summary.encode("utf-8")) < 1024 * 1024
    assert "1 more failing row(s) are in the uploaded log." in summary.splitlines()


def test_report_skips_a_row_over_budget_and_shows_the_rows_after_it(tmp_path):
    """
    A row over the budget must not hide the rows behind it (#207). The 600 KiB row is
    left to the uploaded log and counted; the two small rows after it fit, so
    they are shown, and the count names only the row that is not.
    """
    detail = "       " + "x" * (600 * 1024)
    log = f"  FAIL big\n{detail}\n  FAIL small-1\n  FAIL small-2\n\nSOME CHECKS FAILED\n"
    result, paths = report(tmp_path, log, 1)

    assert result.returncode == 0, result.stdout + result.stderr
    summary = paths["summary.md"].read_text()
    assert len(summary.encode("utf-8")) <= 1048576
    assert "```text\n  FAIL small-1\n  FAIL small-2\n```\n" in summary
    assert "  FAIL big" not in summary.splitlines()
    assert "1 more failing row(s) are in the uploaded log." in summary.splitlines()


def test_report_counts_the_fence_against_the_row_budget(tmp_path):
    """
    A fence is one backtick longer than the longest run inside it, and there
    are two, so a block's size is not its text's. Row a is 300 KiB of backticks:
    its text fits the 512 KiB budget, its fenced block (about 900 KiB) does not.
    Counted on text alone, a and b together are 500 KiB, and the summary they
    make is 1.1 MiB -- past GitHub's cap, and lost.
    """
    log = (
        "  FAIL a\n           " + "`" * (300 * 1024) + "\n"
        "  FAIL b\n           " + "x" * (200 * 1024) + "\n"
        "\nSOME CHECKS FAILED\n"
    )
    result, paths = report(tmp_path, log, 1)

    assert result.returncode == 0, result.stdout + result.stderr
    summary = paths["summary.md"].read_text()
    assert len(summary.encode("utf-8")) <= 1048576
    assert "  FAIL a" not in summary.splitlines()
    assert "```text\n  FAIL b\n    " + "x" * 204800 + "\n```\n" in summary
    assert "1 more failing row(s) are in the uploaded log." in summary.splitlines()


def test_report_counts_a_shown_rows_fence_against_the_rows_after_it(tmp_path):
    """
    A fence is the block's, not a row's: row a's 102,400 backticks make the
    fence 102,401 wide for every row shown with it. So row b, 307,214 bytes of
    plain text, does not fit beside a (614,436 bytes fenced), though a and b
    with plain fences would be 409,640 and fit. Row c, nine bytes, still fits.
    """
    log = (
        "  FAIL a\n           " + "`" * 102400 + "\n"
        "  FAIL b\n           " + "x" * 307200 + "\n"
        "  FAIL c\n"
        "\nSOME CHECKS FAILED\n"
    )
    result, paths = report(tmp_path, log, 1)

    assert result.returncode == 0, result.stdout + result.stderr
    summary = paths["summary.md"].read_text()
    assert (
        "`" * 102401 + "text\n  FAIL a\n    " + "`" * 102400 + "\n  FAIL c\n"
        + "`" * 102401 + "\n"
    ) in summary
    assert "  FAIL b" not in summary.splitlines()
    assert "1 more failing row(s) are in the uploaded log." in summary.splitlines()


@pytest.mark.parametrize(
    ("tail", "block", "cut"),
    [
        ("y" * (2 * 1024 * 1024),
         "```text\n" + "y" * 524275 + "\n```\n",
         1572892),
        # The fence grows with the backticks it holds: a third of the budget
        # is text, and two thirds are the fences either side of it.
        ("`" * (2 * 1024 * 1024),
         "`" * 174760 + "text\n" + "`" * 174759 + "\n" + "`" * 174760 + "\n",
         1922408),
        # Counted in bytes, not characters, and never cut inside one: the odd
        # byte of a split two-byte character is dropped, and counted as cut.
        ("é" * (1024 * 1024),
         "```text\n" + "é" * 262137 + "\n```\n",
         1572893),
        # 524,275 bytes of room hold 131,068 four-byte characters and three
        # bytes over. A split character's bytes are dropped, not shown: as
        # U+FFFD, one of them would fit in those three.
        ("😀" * 540000,
         "```text\n" + "😀" * 131068 + "\n```\n",
         1635743),
        # Each of these lines fits the budget alone, and together they do not:
        # z and y whole are 409,602 bytes, so x keeps 114,673 of its 204,800.
        # Only the size carried from z and y says so; a clip that forgot it
        # would keep all three whole and cut nothing.
        ("x" * 204800 + "\n" + "y" * 204800 + "\n" + "z" * 204800,
         "```text\n" + "x" * 114673 + "\n" + "y" * 204800 + "\n" + "z" * 204800 + "\n```\n",
         90142),
        # The x line is cut by a fence it holds no backtick of: the run of
        # 102,400 after it, kept first, makes the fence 102,401 wide, and that
        # fence is the block's fence whichever line is being measured.
        ("x" * 307200 + "\n" + "`" * 102400 + "\nend",
         "`" * 102401 + "text\n" + "x" * 217074 + "\n" + "`" * 102400 + "\nend\n"
         + "`" * 102401 + "\n",
         90141),
    ],
    ids=["ascii", "backticks", "two-byte", "four-byte", "size-carried", "fence-carried"],
)
def test_report_cuts_a_log_tail_over_budget_and_says_so(tmp_path, tail, block, cut):
    """
    A non-zero exit with no failing row shows the log's last lines, and one of
    them can be any length (#207): a 2 MiB final line once made a 2 MiB summary, which
    GitHub refuses whole. The tail is kept from its end, where a guard's
    message is, and what was cut is said rather than silently left out.
    """
    log = "  ok   a check\n" + tail + "\n"
    result, paths = report(tmp_path, log, 2)

    assert result.returncode == 0, result.stdout + result.stderr
    summary = paths["summary.md"].read_text()
    assert len(summary.encode("utf-8")) <= 1048576
    assert (
        "The suite exited 2 without printing a failing row. The end of its log:\n\n"
        + block
        + f"\nThe first {cut} bytes of those lines are cut, to keep this summary under "
        "GitHub's 1 MiB limit. The uploaded log holds them.\n"
    ) in summary


def test_report_does_not_say_a_short_tail_was_cut(tmp_path):
    log = "  ok   a check\nguard: stopped here\n"
    result, paths = report(tmp_path, log, 2)

    assert result.returncode == 0, result.stdout + result.stderr
    summary = paths["summary.md"].read_text()
    assert "```text\n  ok   a check\nguard: stopped here\n```\n" in summary
    assert "are cut" not in summary


@pytest.mark.parametrize("heading", ["=== the next section ===", "--- this repository ---"],
                         ids=["equals", "dashes"])
def test_report_ends_a_failing_row_at_a_heading_at_column_0(tmp_path, heading):
    """A heading is printed at column 0, so it closes a failing row's detail,
    and what follows it -- here a library's stderr, printed before the row it
    belongs to -- is not shown as the failing row's. Since #224 it is the
    column that closes it, not the heading's `===` or `---`."""
    log = (
        "  FAIL a row\n"
        "           its detail\n"
        f"{heading}\n"
        "lib/command-scan.sh: a stray line of stderr\n"
        "  ok   a later row\n"
        "\nSOME CHECKS FAILED\n"
    )
    result, paths = report(tmp_path, log, 1)

    assert result.returncode == 0, result.stdout + result.stderr
    assert "```text\n  FAIL a row\n    its detail\n```\n" in paths["summary.md"].read_text()


# --------------------------------------------------------------------------- #
# report: which lines are a failing row's (#224)
# --------------------------------------------------------------------------- #

LIBRARY = Path(__file__).resolve().parent.parent / ".claude" / "hooks" / "checks" / "library.sh"


def summary_text(paths):
    """The summary as written, a carriage return included: `read_text` would
    turn one into a newline, which is the thing one test here is about."""
    return paths["summary.md"].read_bytes().decode("utf-8")


def test_report_takes_the_detail_the_check_librarys_own_fail_marks(tmp_path):
    """
    The tie between the two halves of #224. The indent is spelled twice, once in
    `fail` and once in the parser, and nothing but this test holds the two
    together, so `fail` is the library's own, sourced and run, and never a copy
    of its text. The stderr it embeds holds what the old rule stopped at or
    took in: a line at column 0, a blank line, and lines opening `---` and
    `===`, as a diff's do. Each comes through with one indent removed, and the
    row after the message ends it. An indent changed in one place alone turns
    this red: the parser then either stops at the first continuation line or
    leaves spaces in front of every one.
    """
    stderr = "first line\ncolumn zero\n\n--- a/diff\n+++ b/diff\n===\n   three spaces"
    printed = subprocess.run(
        ["bash", "-c",
         'source "$1"; fail static "%s\\n         stderr |%s|" "$2" "$3"; '
         'pass static "%s" "the next row"',
         "bash", str(LIBRARY), "a failing row", stderr],
        env={**os.environ, "LEDGER": ""}, capture_output=True, text=True,
    )
    assert printed.returncode == 0 and printed.stderr == "", printed.stderr

    result, paths = report(tmp_path, printed.stdout + "\nSOME CHECKS FAILED\n", 1)

    assert result.returncode == 0, result.stdout + result.stderr
    data = json.loads(paths["result.json"].read_text())
    assert (data["passed"], data["failed"]) == (1, 1)
    assert (
        "```text\n"
        "  FAIL a failing row\n"
        "         stderr |first line\n"
        "column zero\n"
        "\n"
        "--- a/diff\n"
        "+++ b/diff\n"
        "===\n"
        "   three spaces|\n"
        "```\n"
    ) in summary_text(paths)


def test_report_does_not_take_a_column_0_line_as_a_failing_rows_detail(tmp_path):
    """
    The defect #224 was filed for, and one that can happen today: a library's
    stderr is printed at column 0, before the row it belongs to, and so right
    after the row above it (run 35836366963's log, lines 2026-2032). A line at
    column 0 is never detail, whatever the row above it is. Nor is a blank line
    that holds no indent.
    """
    log = (
        "  FAIL row A\n"
        "lib/command-scan.sh: stray stderr of row B\n"
        "  ok   row B\n"
        "  FAIL row C\n"
        "\n"
        "       not row C's, after a blank line with no indent\n"
        "\nSOME CHECKS FAILED\n"
    )
    result, paths = report(tmp_path, log, 1)

    assert result.returncode == 0, result.stdout + result.stderr
    assert "```text\n  FAIL row A\n  FAIL row C\n```\n" in summary_text(paths)


def test_report_does_not_end_a_detail_at_a_blank_line_or_a_heading_shaped_one(tmp_path):
    """
    `fail` writes a blank line of its message as the indent alone, and a line
    opening `---` or `===` as the indent and then that. None of them ends the
    detail, which the old rule's blank-line and heading boundaries did: it
    returned `stderr |line one` alone for the first of these rows, and lost the
    rest (#224's triage).
    """
    log = (
        "  FAIL row C\n"
        "                stderr |line one\n"
        "       \n"
        "       line three\n"
        "       --- a/hook.sh\n"
        "       === not a section\n"
        "       line six|\n"
        "  ok   row D\n"
        "\nSOME CHECKS FAILED\n"
    )
    result, paths = report(tmp_path, log, 1)

    assert result.returncode == 0, result.stdout + result.stderr
    assert (
        "```text\n"
        "  FAIL row C\n"
        "         stderr |line one\n"
        "\n"
        "line three\n"
        "--- a/hook.sh\n"
        "=== not a section\n"
        "line six|\n"
        "```\n"
    ) in summary_text(paths)


def test_report_shows_a_detail_with_exactly_one_indent_removed(tmp_path):
    """The summary removes the indent `fail` added and nothing else, so a line
    the hook itself indented keeps its own spaces, and a diff or a nested list
    in its stderr reads as the hook wrote it."""
    log = (
        "  FAIL row E\n"
        "       at the indent\n"
        "          three more\n"
        "                 ten more\n"
        "\nSOME CHECKS FAILED\n"
    )
    result, paths = report(tmp_path, log, 1)

    assert result.returncode == 0, result.stdout + result.stderr
    assert (
        "```text\n"
        "  FAIL row E\n"
        "at the indent\n"
        "   three more\n"
        "          ten more\n"
        "```\n"
    ) in summary_text(paths)


def test_report_takes_a_stray_line_that_opens_with_the_indent_as_detail(tmp_path):
    """
    A RECORDED TRADE, NOT A WANTED PROPERTY. A line `fail` did not print but
    that opens with its indent is read as detail of the failing row above it,
    because nothing in the log tells it from a continuation line (#224). This
    pins the behaviour so that a change to it is seen; it does not say the
    line belongs to row F.
    """
    log = (
        "  FAIL row F\n"
        "       a stray line that happens to open with the indent\n"
        "  ok   row G\n"
        "\nSOME CHECKS FAILED\n"
    )
    result, paths = report(tmp_path, log, 1)

    assert result.returncode == 0, result.stdout + result.stderr
    assert (
        "```text\n"
        "  FAIL row F\n"
        "a stray line that happens to open with the indent\n"
        "```\n"
    ) in summary_text(paths)


def test_report_cuts_a_detail_into_lines_only_at_a_newline(tmp_path):
    """
    `fail` indents after a newline and nowhere else, so a line is cut there
    and nowhere else. `str.splitlines` also cuts at a carriage return, a form
    feed and a file separator, and reading the log with universal newlines
    turns a carriage return into a newline: either way the rest of such a line
    stood at column 0 and ended the detail. A stderr holding one keeps it, and
    no piece of it is counted as a row.
    """
    log = (
        "  FAIL row H\n"
        "                stderr |before\rafter\x0cand\x1c  ok   not a row\n"
        "       and the line after|\n"
        "  ok   row I\n"
        "\nSOME CHECKS FAILED\n"
    )
    result, paths = report(tmp_path, log, 1)

    assert result.returncode == 0, result.stdout + result.stderr
    data = json.loads(paths["result.json"].read_text())
    assert (data["passed"], data["failed"]) == (1, 1)
    assert (
        "```text\n"
        "  FAIL row H\n"
        "         stderr |before\rafter\x0cand\x1c  ok   not a row\n"
        "and the line after|\n"
        "```\n"
    ) in summary_text(paths)


def test_verify_merge_reads_parents_from_the_header_and_not_the_message(tmp_path, merge_repo):
    """
    A commit object is a header, a blank line and the message. Only the header
    names parents, so a message line that happens to open `parent ` must not be
    read as one. GitHub's merge messages carry none today; nothing else stops a
    later one from doing so.
    """
    origin, base, head, merge = merge_repo
    tree = git(origin, "rev-parse", f"{merge}^{{tree}}")
    worded = git(origin, "commit-tree", tree, "-p", base, "-p", head,
                 "-m", "Merge feature into dev-05",
                 "-m", "parent of this change is the feature branch")
    git(origin, "update-ref", "refs/pull/7/merge", worded)
    work = checkout(tmp_path, origin, "refs/pull/7/merge")

    result = run_script("verify-merge", "--head-sha", head, "--base-ref", "dev-05", cwd=work)

    assert result.returncode == 0, result.stdout + result.stderr
    assert f"  second parent (head): {head}" in result.stdout.splitlines()


# --------------------------------------------------------------------------- #
# report: how the suite step ended (#208)
# --------------------------------------------------------------------------- #

@pytest.mark.parametrize(
    ("outcome", "ended", "said"),
    [
        ("cancelled", "cancelled",
         "The suite did not exit: the run was cancelled while it ran. The end of its log:"),
        ("failure", "timed-out",
         "The suite did not exit: its step ran out of time. The end of its log:"),
    ],
)
def test_report_tells_a_cancel_from_a_timeout(tmp_path, outcome, ended, said):
    """A suite step that wrote no exit status was stopped from outside it. Both
    ways used to read as exit status 124, a timeout, and 21 of 60 runs were
    cancels (#208). Neither is given a status the suite never had."""
    result, paths = report(tmp_path, PASSING_LOG.replace("ALL CHECKS PASSED", ""), None,
                           outcome=outcome)

    assert result.returncode == 0, result.stdout + result.stderr
    data = json.loads(paths["result.json"].read_text())
    assert (data["exit_status"], data["ended"]) == (None, ended)
    assert paths["github_output"].read_text().splitlines()[-2:] == [
        "exit_status=", f"ended={ended}"]
    summary = paths["summary.md"].read_text()
    assert summary.startswith("## check-hooks: FAILED\n")
    assert f"| 3 | 3 | 0 | 204 | – | {ended} | `abc123` |" in summary.splitlines()
    assert said in summary.splitlines()


def test_report_calls_an_exit_status_an_exit_even_under_a_cancel(tmp_path):
    """The cancel landed after the suite had exited and its status was written:
    the suite finished, and what it said is the record."""
    result, paths = report(tmp_path, PASSING_LOG, 0, outcome="cancelled")

    assert result.returncode == 0, result.stdout + result.stderr
    data = json.loads(paths["result.json"].read_text())
    assert (data["exit_status"], data["ended"]) == (0, "exited")


@pytest.mark.parametrize("outcome", ["success", "skipped", ""])
def test_report_refuses_a_missing_exit_status_it_cannot_explain(tmp_path, outcome):
    """The suite step writes its status unless it is stopped, and only a cancel
    or a timeout stops it. Anything else is recorded as unknown, never as either
    of those, and fails the report."""
    result, paths = report(tmp_path, PASSING_LOG, None, outcome=outcome)

    assert result.returncode == 1
    assert (
        f"::error::the suite step wrote no exit status and its outcome is '{outcome}', "
        "which is neither a cancel nor a timeout"
    ) in result.stdout.splitlines()
    data = json.loads(paths["result.json"].read_text())
    assert (data["exit_status"], data["ended"]) == (None, "unknown")


def test_report_says_a_cancelled_suite_did_not_exit_above_its_failing_rows(tmp_path):
    result, paths = report(tmp_path, FAILING_LOG.replace("SOME CHECKS FAILED", ""), None,
                           outcome="cancelled")

    assert result.returncode == 0, result.stdout + result.stderr
    lines = paths["summary.md"].read_text().splitlines()
    assert lines.index("The suite did not exit: the run was cancelled while it ran.") \
        < lines.index("### Failing rows (2)")


def test_report_does_not_call_a_step_that_failed_before_the_suite_a_timeout(tmp_path):
    """Outcome `failure` is a timeout only once the suite has started: a step
    that failed before writing `started` never ran it, and nothing timed out."""
    result, paths = report(tmp_path, "", None, seconds=None, outcome="failure")

    assert result.returncode == 1
    assert ("::error::the suite step wrote no exit status and its outcome is 'failure', "
            "which is neither a cancel nor a timeout") in result.stdout.splitlines()
    data = json.loads(paths["result.json"].read_text())
    assert (data["exit_status"], data["ended"], data["seconds"]) == (None, "unknown", None)
    assert "seconds=" in paths["github_output"].read_text().splitlines()

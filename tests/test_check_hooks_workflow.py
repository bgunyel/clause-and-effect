"""
Tests for what `.github/workflows/check-hooks.yml` is triggered by, which no
run can show: a trigger that is missing fires nothing, and nothing is what a
stale green looks like.

A retarget -- dev-04 to dev-05 -- changes the merge a pull request would
produce, and GitHub reports it as `edited`, which the default `pull_request`
types leave out. So the types are pinned as a literal, and so is the absence
of a job-level `if:`: the cheaper way to take `edited` only for a base change
is such an `if:`, and a job skipped by one reports Success, even as a required
check, so a title edit would put a green `check-hooks` on a red pull request.

Three steps are run here too, each lifted out of the file as text and run
against fakes under the flags the runner uses: the one that refuses a
credential, the one that records the suite's exit status, and the one that
exits with it.
The last two are what give the job its colour, so a defect in either is a green
job on a red suite; and a guard that only ever runs on a hosted runner has
never been seen to refuse anything.

The file is read as text. PyYAML is not a dependency of the test group, and
the claims here are about the exact lines the workflow carries.
"""
import os
import re
import subprocess
import tempfile
from pathlib import Path

import pytest

WORKFLOW = Path(__file__).resolve().parent.parent / ".github" / "workflows" / "check-hooks.yml"

# How the runner runs a `run:` block of a workflow that declares no `shell:`:
# `bash -e {0}`, with no `pipefail`. Observed, not assumed: every step of
# run 35836366963 (#206) logged `shell: /usr/bin/bash -e {0}`. `shell: bash`
# would be `bash --noprofile --norc -eo pipefail {0}` instead -- a harness
# that ran that while the runner ran this let `PIPESTATUS[0]` -> `$?` survive,
# a green job on every red suite (#206, round 2). So these are the flags, and
# `test_no_step_declares_a_shell` holds the workflow to them.
RUNNER_BASH = ["bash", "-e"]
# Variables that would give the harness's bash options the runner's does not
# have: SHELLOPTS and BASHOPTS switch options on at startup, and BASH_ENV (ENV
# for sh) names a file a non-interactive bash sources first.
RUNNER_UNSET = ("SHELLOPTS", "BASHOPTS", "BASH_ENV", "ENV")


def lines():
    return WORKFLOW.read_text().splitlines()


def test_a_retarget_triggers_a_run():
    on = lines().index("on:")
    trigger = lines()[on:lines().index("permissions:", on)]
    assert trigger == [
        "on:",
        "  pull_request:",
        "    branches: ['dev-*']",
        "    types: [opened, synchronize, reopened, edited]",
        "",
    ]


def test_no_job_can_be_skipped_by_a_condition_into_a_success():
    """A job's own keys sit four spaces in, under `jobs:`; a step's `if:` is
    deeper and is not this claim."""
    jobs = lines().index("jobs:")
    job_level_if = [line for line in lines()[jobs:] if re.match(r"^    if:", line)]
    assert job_level_if == []


def step_script(name):
    """The `run: |` block of the step called `name`, dedented."""
    all_lines = lines()
    start = all_lines.index(f"      - name: {name}")
    run = all_lines.index("        run: |", start)
    body = []
    for line in all_lines[run + 1:]:
        if line and not line.startswith(" " * 10):
            break
        body.append(line[10:])
    return "\n".join(body) + "\n"


def run_script(script, env, cwd=None):
    """Run `script` as the runner runs a `run:` block: written to a file and
    run as `bash -e {0}`, with nothing in the environment that sets a flag."""
    env = {k: v for k, v in env.items() if k not in RUNNER_UNSET}
    with tempfile.NamedTemporaryFile("w", suffix=".sh") as fh:
        fh.write(script)
        fh.flush()
        return subprocess.run([*RUNNER_BASH, fh.name], env=env, capture_output=True, text=True, cwd=cwd)


def run_step(name, env, cwd=None):
    return run_script(step_script(name), env, cwd)


def test_no_step_declares_a_shell():
    """RUNNER_BASH is the runner's default shell, and is right only while
    nothing in the workflow replaces it -- a `defaults: run: shell:` or a
    step's own `shell:`. Declaring one is a change to this harness too."""
    declared = [line for line in lines() if re.match(r"^\s*(shell|defaults):", line)]
    assert declared == []


def test_the_harness_runs_a_step_under_the_runners_flags_only(tmp_path):
    """A caller whose environment would switch `pipefail` on -- exported
    SHELLOPTS, or a BASH_ENV file that sets it -- must not pass it on: that is
    the harness being more protective than the runner again."""
    bash_env = tmp_path / "bash_env"
    bash_env.write_text("set -o pipefail\n")
    env = {**os.environ, "SHELLOPTS": "pipefail", "BASH_ENV": str(bash_env)}

    result = run_script('echo "flags=$-"\nset -o | grep -E "^(errexit|pipefail)[[:space:]]"\n', env)

    assert result.returncode == 0, result.stderr
    out = result.stdout.split()
    assert out[0].startswith("flags=") and "e" in out[0]
    assert out[1:] == ["errexit", "on", "pipefail", "off"]


@pytest.mark.parametrize("git_exit, refused, message", [
    (0, True, "::error::checkout left a credential in .git/config; the suite must run without one"),
    (1, False, None),
    (3, True, "::error::git config exited 3, so whether checkout left a credential is unknown; "
              "the suite must not run on that"),
    (6, True, "::error::git config exited 6, so whether checkout left a credential is unknown; "
              "the suite must not run on that"),
])
def test_only_no_match_from_git_config_reads_as_no_credential(tmp_path, git_exit, refused, message):
    """A fake `git` exits with each code."""
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    fake_git = bin_dir / "git"
    fake_git.write_text(f"#!/bin/bash\nexit {git_exit}\n")
    fake_git.chmod(0o755)
    env = {k: v for k, v in os.environ.items() if k not in ("GITHUB_TOKEN", "GH_TOKEN")}
    env["PATH"] = f"{bin_dir}{os.pathsep}{env['PATH']}"

    result = run_step("refuse a credential the suite could reach", env)

    assert (result.returncode != 0) == refused, result.stdout + result.stderr
    errors = [line for line in result.stdout.splitlines() if line.startswith("::error::")]
    assert errors == ([message] if message else [])


@pytest.mark.parametrize("variable", ["GITHUB_TOKEN", "GH_TOKEN"])
def test_a_token_in_the_environment_is_refused(tmp_path, variable):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    fake_git = bin_dir / "git"
    fake_git.write_text("#!/bin/bash\nexit 1\n")
    fake_git.chmod(0o755)
    env = {k: v for k, v in os.environ.items() if k not in ("GITHUB_TOKEN", "GH_TOKEN")}
    env["PATH"] = f"{bin_dir}{os.pathsep}{env['PATH']}"
    env[variable] = "ghs_x"

    result = run_step("refuse a credential the suite could reach", env)

    assert result.returncode == 1
    errors = [line for line in result.stdout.splitlines() if line.startswith("::error::")]
    assert errors == ["::error::a token is in the suite's environment; the suite must run without one"]


def fake_bin(tmp_path, **scripts):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    for name, body in scripts.items():
        f = bin_dir / name
        f.write_text(f"#!/bin/bash\n{body}\n")
        f.chmod(0o755)
    return bin_dir


@pytest.mark.parametrize("suite_exit", [0, 1, 3])
def test_the_suite_step_records_the_suites_status_not_tees(tmp_path, suite_exit):
    """`sudo` is faked as the whole suite: it prints a row and exits with the
    suite's status. The status recorded must be the suite's, not `tee`'s --
    `tee` exits 0, and a recorded 0 is a green job. Both `PIPESTATUS[1]` and
    `$?` are that defect under the runner's `bash -e`, which has no `pipefail`,
    and both are caught here. `PIPESTATUS[0]` is right with or without it."""
    bin_dir = fake_bin(tmp_path, sudo=f"echo '  ok   a row'\nexit {suite_exit}",
                       git="echo fake-git")
    runner_temp = tmp_path / "runner-temp"
    runner_temp.mkdir()
    env = {**os.environ, "PATH": f"{bin_dir}{os.pathsep}{os.environ['PATH']}",
           "RUNNER_TEMP": str(runner_temp)}

    result = run_step("run the check suite", env, cwd=tmp_path)

    assert result.returncode == 0, result.stdout + result.stderr
    assert (runner_temp / "check-hooks" / "exit_status").read_text() == f"{suite_exit}\n"
    assert (runner_temp / "check-hooks" / "check-hooks.log").read_text() == "  ok   a row\n"


@pytest.mark.parametrize("recorded", ["0", "1", "3"])
def test_the_verdict_step_exits_with_the_recorded_status(tmp_path, recorded):
    """The one step that gives the job its colour."""
    (tmp_path / "check-hooks").mkdir()
    (tmp_path / "check-hooks" / "exit_status").write_text(f"{recorded}\n")
    env = {**os.environ, "RUNNER_TEMP": str(tmp_path)}

    result = run_step("the suite's verdict", env)

    assert result.returncode == int(recorded)
    assert result.stdout.splitlines() == [f"check-hooks.sh exited {recorded}"]

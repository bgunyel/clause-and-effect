"""
Tests for `.github/scripts/rerun-on-base-move.sh`, the job that answers #199's
requirement 4: when the active dev branch moves, every open pull request into
it gets its `check-hooks` run again, against a merge ref GitHub has rebuilt on
the new tip.

The script is run as a process with a fake `gh` first on PATH. The fake serves
each GET from a fixture keyed by its API path, filtering it through the `jq`
binary with the expression the script passed to `--jq` -- `gh` evaluates the
same language itself -- and records every POST instead of sending it.
So what is asserted is which writes the script *asks for* -- the cancel and the
re-run -- and nothing reaches GitHub. Every expected request and message is a
literal.

What is not asserted here, because no fake can: that GitHub starts a run when
the re-run request carries the workflow's own GITHUB_TOKEN, and that the re-run
fetches the rebuilt merge ref. Those are shown by an observed run, which is
#199's acceptance criterion for this requirement.
"""
import json
import os
import re
import stat
import subprocess
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parent.parent / ".github" / "scripts" / "rerun-on-base-move.sh"

REPO = "o/r"
BASE = "dev-05"
TIP = "t" * 40
OLD = "b" * 40
HEAD = "h" * 40
MERGE = "m" * 40

FAKE_GH = r"""#!/bin/bash
# api [-X METHOD] [--paginate] PATH [--jq EXPR]
shift  # api
method=GET jq_expr=. path=
while [ $# -gt 0 ]; do
  case "$1" in
    -X) method=$2; shift 2 ;;
    --paginate) shift ;;
    --jq) jq_expr=$2; shift 2 ;;
    *) path=$1; shift ;;
  esac
done
if [ "$method" != GET ]; then
  printf '%s %s\n' "$method" "$path" >> "$FAKE_DIR/requests"
  key=$(printf '%s %s' "$method" "$path" | tr -c 'A-Za-z0-9' _)
  [ -e "$FAKE_DIR/fail-$key" ] && exit 1
  exit 0
fi
printf 'GET %s\n' "$path" >> "$FAKE_DIR/gets"
key=$(printf '%s' "$path" | tr -c 'A-Za-z0-9' _)
# A fixture may be a sequence: key.1, key.2, ... served in turn, the last repeated.
n=$(( $(cat "$FAKE_DIR/count-$key" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$FAKE_DIR/count-$key"
if [ -e "$FAKE_DIR/$key.$n" ]; then f="$FAKE_DIR/$key.$n"
elif [ -e "$FAKE_DIR/$key" ]; then f="$FAKE_DIR/$key"
else f=$(cd "$FAKE_DIR" && ls "$key".* 2>/dev/null | sort -t. -k2 -n | tail -1)
     [ -n "$f" ] && f="$FAKE_DIR/$f"
fi
[ -n "$f" ] || { echo "fake gh: no fixture for GET $path" >&2; exit 1; }
jq -r "$jq_expr" "$f"
"""


def key(path):
    return re.sub(r"[^A-Za-z0-9]", "_", path)


@pytest.fixture
def fake(tmp_path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    gh = bin_dir / "gh"
    gh.write_text(FAKE_GH)
    gh.chmod(gh.stat().st_mode | stat.S_IEXEC)
    data = tmp_path / "fake"
    data.mkdir()

    class Fake:
        def serve(self, path, *bodies):
            """Serve `bodies` in turn for GET `path`, repeating the last."""
            if len(bodies) == 1:
                (data / key(path)).write_text(json.dumps(bodies[0]))
            else:
                for i, body in enumerate(bodies, 1):
                    (data / f"{key(path)}.{i}").write_text(json.dumps(body))

        def fail(self, method, path):
            (data / f"fail-{key(f'{method} {path}')}").touch()

        def gets(self):
            f = data / "gets"
            return f.read_text().splitlines() if f.exists() else []

        def requests(self):
            f = data / "requests"
            return f.read_text().splitlines() if f.exists() else []

        def run(self, **overrides):
            env = {
                **os.environ,
                "PATH": f"{bin_dir}{os.pathsep}{os.environ['PATH']}",
                "FAKE_DIR": str(data),
                "REPO": REPO, "BASE": BASE, "TIP": TIP,
                "POLL_SECONDS": "0", "WAIT_TRIES": "3",
                **overrides,
            }
            # The script sets its own options; a caller's exported SHELLOPTS or
            # BASH_ENV would add to them, and the runner has neither.
            for name in ("SHELLOPTS", "BASHOPTS", "BASH_ENV", "ENV"):
                env.pop(name, None)
            return subprocess.run(["bash", str(SCRIPT)], env=env, capture_output=True, text=True)

    return Fake()


PULLS = f"repos/{REPO}/pulls?state=open&base={BASE}&per_page=100"
PR = f"repos/{REPO}/pulls/7"
RUNS = f"repos/{REPO}/actions/workflows/check-hooks.yml/runs?event=pull_request&head_sha={HEAD}&per_page=1"
RERUN = f"POST repos/{REPO}/actions/runs/42/rerun"
CANCEL = f"POST repos/{REPO}/actions/runs/42/cancel"


def one_open_pr(fake):
    fake.serve(PULLS, [{"number": 7, "head": {"sha": HEAD}}])


def test_it_reruns_a_completed_run_once_the_merge_ref_is_on_the_new_tip(fake):
    one_open_pr(fake)
    fake.serve(PR,
               {"mergeable": None, "merge_commit_sha": None},
               {"mergeable": True, "merge_commit_sha": MERGE})
    fake.serve(f"repos/{REPO}/commits/{MERGE}", {"parents": [{"sha": TIP}, {"sha": HEAD}]})
    fake.serve(RUNS, {"workflow_runs": [{"id": 42, "status": "completed"}]})

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert fake.requests() == [RERUN]
    assert f"#7: the merge ref is rebuilt on {TIP}" in result.stdout.splitlines()
    assert f"#7: re-ran https://github.com/{REPO}/actions/runs/42" in result.stdout.splitlines()


def test_it_waits_while_the_merge_ref_is_still_on_the_old_tip(fake):
    """`mergeable: true` from before the push says nothing about the new tip."""
    one_open_pr(fake)
    fake.serve(PR,
               {"mergeable": True, "merge_commit_sha": "o" * 40},
               {"mergeable": True, "merge_commit_sha": MERGE})
    fake.serve(f"repos/{REPO}/commits/{'o' * 40}", {"parents": [{"sha": OLD}, {"sha": HEAD}]})
    fake.serve(f"repos/{REPO}/commits/{MERGE}", {"parents": [{"sha": TIP}, {"sha": HEAD}]})
    fake.serve(RUNS, {"workflow_runs": [{"id": 42, "status": "completed"}]})

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert f"#7: the merge ref is rebuilt on {TIP}" in result.stdout.splitlines()
    assert fake.gets().count(f"GET {PR}") == 2
    assert fake.requests() == [RERUN]


def test_it_cancels_a_run_in_progress_before_rerunning_it(fake):
    """A run that started before the push may have fetched the old merge."""
    one_open_pr(fake)
    fake.serve(PR, {"mergeable": True, "merge_commit_sha": MERGE})
    fake.serve(f"repos/{REPO}/commits/{MERGE}", {"parents": [{"sha": TIP}, {"sha": HEAD}]})
    fake.serve(RUNS, {"workflow_runs": [{"id": 42, "status": "in_progress"}]})
    fake.serve(f"repos/{REPO}/actions/runs/42", {"status": "in_progress"}, {"status": "completed"})

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert fake.requests() == [CANCEL, RERUN]
    assert "::warning::" not in result.stdout


def test_a_conflicting_pull_request_is_still_rerun_so_the_conflict_turns_it_red(fake):
    """GitHub does not rebuild a conflicting pull request's merge ref, so the
    re-run tests the old merge -- and verify-merge refuses it. That red check is
    the report; skipping the re-run would leave the stale green standing."""
    one_open_pr(fake)
    fake.serve(PR, {"mergeable": False, "merge_commit_sha": "o" * 40})
    fake.serve(RUNS, {"workflow_runs": [{"id": 42, "status": "completed"}]})

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert (
        f"::warning::#7 conflicts with {BASE} at {TIP}, so GitHub will not rebuild its "
        "merge ref; the re-run will fail on that"
    ) in result.stdout.splitlines()
    assert fake.requests() == [RERUN]


def test_a_merge_ref_that_is_never_rebuilt_is_rerun_after_the_wait(fake):
    one_open_pr(fake)
    fake.serve(PR, {"mergeable": None, "merge_commit_sha": None})
    fake.serve(RUNS, {"workflow_runs": [{"id": 42, "status": "completed"}]})

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert (
        f"::warning::#7: GitHub did not rebuild the merge ref on {TIP} within the wait; "
        "the re-run will fail if it still has not"
    ) in result.stdout.splitlines()
    assert fake.requests() == [RERUN]


def test_a_pull_request_with_no_run_is_reported_and_nothing_is_written(fake):
    """A pull request opened before the workflow existed has no run to re-run."""
    one_open_pr(fake)
    fake.serve(PR, {"mergeable": True, "merge_commit_sha": MERGE})
    fake.serve(f"repos/{REPO}/commits/{MERGE}", {"parents": [{"sha": TIP}, {"sha": HEAD}]})
    fake.serve(RUNS, {"workflow_runs": []})

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert (
        f"::warning::#7 has no check-hooks.yml run for its head {HEAD}, so there is "
        "nothing to re-run; a push to its branch starts one"
    ) in result.stdout.splitlines()
    assert fake.requests() == []


def test_no_open_pull_request_is_nothing_to_do(fake):
    fake.serve(PULLS, [])

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert f"no open pull request targets {BASE}" in result.stdout.splitlines()
    assert fake.requests() == []


def test_a_refused_rerun_fails_the_job_and_the_others_are_still_rerun(fake):
    """One pull request's failure must not hide behind the next one's success."""
    head2, merge2 = "g" * 40, "n" * 40
    fake.serve(PULLS, [{"number": 7, "head": {"sha": HEAD}}, {"number": 8, "head": {"sha": head2}}])
    fake.serve(PR, {"mergeable": True, "merge_commit_sha": MERGE})
    fake.serve(f"repos/{REPO}/pulls/8", {"mergeable": True, "merge_commit_sha": merge2})
    fake.serve(f"repos/{REPO}/commits/{MERGE}", {"parents": [{"sha": TIP}, {"sha": HEAD}]})
    fake.serve(f"repos/{REPO}/commits/{merge2}", {"parents": [{"sha": TIP}, {"sha": head2}]})
    fake.serve(RUNS, {"workflow_runs": [{"id": 42, "status": "completed"}]})
    fake.serve(RUNS.replace(HEAD, head2), {"workflow_runs": [{"id": 43, "status": "completed"}]})
    fake.fail("POST", f"repos/{REPO}/actions/runs/42/rerun")

    result = fake.run()

    assert result.returncode == 1
    assert fake.requests() == [RERUN, f"POST repos/{REPO}/actions/runs/43/rerun"]
    assert (
        f"::error::#7: the re-run of https://github.com/{REPO}/actions/runs/42 was refused, "
        "so its check still stands on the old merge; a push to its branch starts a new run"
    ) in result.stdout.splitlines()


def test_a_failed_run_listing_fails_the_job_rather_than_reading_as_no_run(fake):
    """No RUNS fixture: the fake gh exits 1, as a failed request would."""
    one_open_pr(fake)
    fake.serve(PR, {"mergeable": True, "merge_commit_sha": MERGE})
    fake.serve(f"repos/{REPO}/commits/{MERGE}", {"parents": [{"sha": TIP}, {"sha": HEAD}]})

    result = fake.run()

    assert result.returncode == 1
    assert "::error::#7: could not list its check-hooks.yml runs, so its check was not re-run" \
        in result.stdout.splitlines()
    assert fake.requests() == []


def test_a_run_that_never_stops_is_still_asked_to_rerun_after_the_wait(fake):
    """GitHub refuses that re-run; the refusal is what fails the job."""
    one_open_pr(fake)
    fake.serve(PR, {"mergeable": True, "merge_commit_sha": MERGE})
    fake.serve(f"repos/{REPO}/commits/{MERGE}", {"parents": [{"sha": TIP}, {"sha": HEAD}]})
    fake.serve(RUNS, {"workflow_runs": [{"id": 42, "status": "in_progress"}]})
    fake.serve(f"repos/{REPO}/actions/runs/42", {"status": "in_progress"})
    fake.fail("POST", f"repos/{REPO}/actions/runs/42/rerun")

    result = fake.run()

    assert result.returncode == 1
    assert fake.requests() == [CANCEL, RERUN]
    assert fake.gets().count(f"GET repos/{REPO}/actions/runs/42") == 3
    assert (
        f"::warning::#7: https://github.com/{REPO}/actions/runs/42 did not stop within the wait, "
        "and GitHub refuses to re-run a run that has not stopped"
    ) in result.stdout.splitlines()


def test_a_refused_cancel_is_reported_and_the_rerun_still_asked_for(fake):
    one_open_pr(fake)
    fake.serve(PR, {"mergeable": True, "merge_commit_sha": MERGE})
    fake.serve(f"repos/{REPO}/commits/{MERGE}", {"parents": [{"sha": TIP}, {"sha": HEAD}]})
    fake.serve(RUNS, {"workflow_runs": [{"id": 42, "status": "in_progress"}]})
    fake.serve(f"repos/{REPO}/actions/runs/42", {"status": "completed"})
    fake.fail("POST", f"repos/{REPO}/actions/runs/42/cancel")

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert (
        f"::warning::#7: the cancel of https://github.com/{REPO}/actions/runs/42 was refused; "
        "it may have finished meanwhile"
    ) in result.stdout.splitlines()
    assert fake.requests() == [CANCEL, RERUN]


def test_a_failed_pull_request_listing_fails_the_job_rather_than_reading_as_none_open(fake):
    """No PULLS fixture: the fake gh exits 1. Read as "no open pull request", a
    failed list would leave every pull request into the branch on a stale green
    behind a green job -- the defect this script exists for, in silence."""
    result = fake.run()

    assert result.returncode == 1
    assert f"::error::could not list the open pull requests into {BASE}" in result.stdout.splitlines()
    assert f"no open pull request targets {BASE}" not in result.stdout.splitlines()
    assert fake.requests() == []


NOT_REBUILT = (
    f"::warning::#7: GitHub did not rebuild the merge ref on {TIP} within the wait; "
    "the re-run will fail if it still has not"
)


def test_a_failed_pull_request_read_fails_the_job_and_is_not_blamed_on_github(fake):
    """No PR fixture. The re-run is still asked for: skipping it would leave the
    stale green standing."""
    one_open_pr(fake)
    fake.serve(RUNS, {"workflow_runs": [{"id": 42, "status": "completed"}]})

    result = fake.run()

    assert result.returncode == 1
    assert (
        f"::error::#7: could not read the pull request, so whether its merge ref is rebuilt "
        f"on {TIP} is unknown; re-running it anyway"
    ) in result.stdout.splitlines()
    assert NOT_REBUILT not in result.stdout.splitlines()
    assert fake.gets().count(f"GET {PR}") == 1
    assert fake.requests() == [RERUN]


def test_a_failed_merge_commit_read_fails_the_job_and_is_not_blamed_on_github(fake):
    """No commits fixture for the merge commit."""
    one_open_pr(fake)
    fake.serve(PR, {"mergeable": True, "merge_commit_sha": MERGE})
    fake.serve(RUNS, {"workflow_runs": [{"id": 42, "status": "completed"}]})

    result = fake.run()

    assert result.returncode == 1
    assert (
        f"::error::#7: could not read the parents of its merge commit {MERGE}, so whether its "
        f"merge ref is rebuilt on {TIP} is unknown; re-running it anyway"
    ) in result.stdout.splitlines()
    assert NOT_REBUILT not in result.stdout.splitlines()
    assert fake.gets().count(f"GET repos/{REPO}/commits/{MERGE}") == 1
    assert fake.requests() == [RERUN]


def test_a_failed_run_status_read_fails_the_job_and_the_rerun_is_still_asked_for(fake):
    """No fixture for the run's own status, polled after the cancel."""
    one_open_pr(fake)
    fake.serve(PR, {"mergeable": True, "merge_commit_sha": MERGE})
    fake.serve(f"repos/{REPO}/commits/{MERGE}", {"parents": [{"sha": TIP}, {"sha": HEAD}]})
    fake.serve(RUNS, {"workflow_runs": [{"id": 42, "status": "in_progress"}]})

    result = fake.run()

    assert result.returncode == 1
    assert (
        f"::error::#7: could not read the status of https://github.com/{REPO}/actions/runs/42, "
        "so whether it has stopped is unknown; asking for its re-run anyway"
    ) in result.stdout.splitlines()
    assert "did not stop within the wait" not in result.stdout
    assert fake.gets().count(f"GET repos/{REPO}/actions/runs/42") == 1
    assert fake.requests() == [CANCEL, RERUN]


@pytest.mark.parametrize("variable", ["REPO", "BASE", "TIP"])
def test_an_empty_input_is_refused_before_any_request(fake, variable):
    """An empty BASE would list pull requests into no particular branch."""
    result = fake.run(**{variable: ""})

    assert result.returncode != 0
    assert fake.gets() == []
    assert fake.requests() == []

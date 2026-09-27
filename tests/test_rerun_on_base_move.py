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
literal. A fake `date` and `sleep` stand beside it: the clock moves only when
the script sleeps, so how long a run would have waited is read off the clock
without waiting (#208's bound on the total wait).

The run fixtures follow what GitHub was found to serve (#208): a run's
`display_title` is the `#N <title>` that check-hooks.yml's run-name stamps, and
its `pull_requests` lists every open pull request whose head matches, not the
one that started it -- so two pull requests sharing a head see both runs.

What is not asserted here, because no fake can: that GitHub starts a run when
the re-run request carries the workflow's own GITHUB_TOKEN, and that the re-run
fetches the rebuilt merge ref. Those are shown by an observed run, which is
#199's acceptance criterion for this requirement.
"""
import io
import json
import os
import re
import stat
import subprocess
import zipfile
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
# A fixture holding only __fail__ is a failed request, at its place in a sequence.
[ "$(head -c 8 "$f")" = __fail__ ] && exit 1
# A download (an artifact's zip) is served as it is, not through jq.
case "$f" in *.raw) cat "$f"; exit 0 ;; esac
jq -r "$jq_expr" "$f"
"""

# The clock the script's deadline reads, advanced only by its sleeps, so a
# test can say how long a run of it would have waited without waiting.
FAKE_DATE = r"""#!/bin/bash
cat "$FAKE_DIR/clock" 2>/dev/null || echo 0
"""

FAKE_SLEEP = r"""#!/bin/bash
now=$(cat "$FAKE_DIR/clock" 2>/dev/null || echo 0)
echo $(( now + $1 )) > "$FAKE_DIR/clock"
"""


FAIL = "__fail__"


def key(path):
    return re.sub(r"[^A-Za-z0-9]", "_", path)


@pytest.fixture
def fake(tmp_path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    for name, text in (("gh", FAKE_GH), ("date", FAKE_DATE), ("sleep", FAKE_SLEEP)):
        tool = bin_dir / name
        tool.write_text(text)
        tool.chmod(tool.stat().st_mode | stat.S_IEXEC)
    data = tmp_path / "fake"
    data.mkdir()

    def clear(path):
        # A fixture is a file named by its key, alone or with a .N or .raw suffix.
        for f in [data / key(path), *data.glob(f"{key(path)}.*")]:
            f.unlink(missing_ok=True)

    class Fake:
        def serve(self, path, *bodies):
            """Serve `bodies` in turn for GET `path`, repeating the last."""
            clear(path)
            text = [body if body is FAIL else json.dumps(body) for body in bodies]
            if len(bodies) == 1:
                (data / key(path)).write_text(text[0])
            else:
                for i, body in enumerate(text, 1):
                    (data / f"{key(path)}.{i}").write_text(body)

        def serve_raw(self, path, body):
            """Serve the bytes `body` for GET `path`, unfiltered."""
            clear(path)
            (data / f"{key(path)}.raw").write_bytes(body)

        def unserve(self, path):
            """GET `path` fails, as a failed request would."""
            clear(path)

        def clock(self):
            f = data / "clock"
            return int(f.read_text()) if f.exists() else 0

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
RUNS = f"repos/{REPO}/actions/workflows/check-hooks.yml/runs?event=pull_request&head_sha={HEAD}&per_page=100"
RERUN = f"POST repos/{REPO}/actions/runs/42/rerun"
CANCEL = f"POST repos/{REPO}/actions/runs/42/cancel"
URL = f"https://github.com/{REPO}/actions/runs/42"
NEW = "n" * 40
OTHER = "x" * 40


def pull(mergeable, merge, head=HEAD):
    return {"mergeable": mergeable, "merge_commit_sha": merge, "head": {"sha": head}}


def run(status, id=42, title="#7 a pull request", prs=(), conclusion=None, attempt=1):
    """A run as the REST listing gives it. The title is its run-name, which
    check-hooks.yml stamps with the pull request's number."""
    return {"id": id, "status": status, "conclusion": conclusion, "run_attempt": attempt,
            "display_title": title, "pull_requests": [{"number": n} for n in prs]}


def one_open_pr(fake):
    fake.serve(PULLS, [{"number": 7, "head": {"sha": HEAD}}])


def rebuilt(fake, *later_heads):
    """#7's merge ref is rebuilt on TIP at the first read; each later read of
    the pull request gives the next of `later_heads`, the last repeated."""
    fake.serve(PR, pull(True, MERGE), *[pull(True, MERGE, h) for h in later_heads])
    fake.serve(f"repos/{REPO}/commits/{MERGE}", {"parents": [{"sha": TIP}, {"sha": HEAD}]})


def test_it_reruns_a_completed_run_once_the_merge_ref_is_on_the_new_tip(fake):
    one_open_pr(fake)
    fake.serve(PR, pull(None, None), pull(True, MERGE))
    fake.serve(f"repos/{REPO}/commits/{MERGE}", {"parents": [{"sha": TIP}, {"sha": HEAD}]})
    fake.serve(RUNS, {"workflow_runs": [run("completed")]})

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert fake.requests() == [RERUN]
    assert f"#7: the merge ref is rebuilt on {TIP}" in result.stdout.splitlines()
    assert f"#7: re-ran {URL}" in result.stdout.splitlines()


def test_it_waits_while_the_merge_ref_is_still_on_the_old_tip(fake):
    """`mergeable: true` from before the push says nothing about the new tip."""
    one_open_pr(fake)
    fake.serve(PR, pull(True, "o" * 40), pull(True, MERGE))
    fake.serve(f"repos/{REPO}/commits/{'o' * 40}", {"parents": [{"sha": OLD}, {"sha": HEAD}]})
    fake.serve(f"repos/{REPO}/commits/{MERGE}", {"parents": [{"sha": TIP}, {"sha": HEAD}]})
    fake.serve(RUNS, {"workflow_runs": [run("completed")]})

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert f"#7: the merge ref is rebuilt on {TIP}" in result.stdout.splitlines()
    # Two reads in the wait, and one of the head before the re-run.
    assert fake.gets().count(f"GET {PR}") == 3
    assert fake.requests() == [RERUN]


def test_it_cancels_a_run_in_progress_before_rerunning_it(fake):
    """A run that started before the push may have fetched the old merge."""
    one_open_pr(fake)
    rebuilt(fake)
    fake.serve(RUNS, {"workflow_runs": [run("in_progress")]})
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
    fake.serve(PR, pull(False, "o" * 40))
    fake.serve(RUNS, {"workflow_runs": [run("completed")]})

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert (
        f"::warning::#7 conflicts with {BASE} at {TIP}, so GitHub will not rebuild its "
        "merge ref; the re-run will fail on that"
    ) in result.stdout.splitlines()
    assert NOT_REBUILT not in result.stdout.splitlines()
    assert fake.requests() == [RERUN]


def test_a_conflicting_pull_request_is_not_waited_on(fake):
    """A conflict is an answer: GitHub will not rebuild that merge ref however
    long it is waited for (#208, item 6). One read in the wait, and one of the
    head before the re-run -- not WAIT_TRIES reads."""
    one_open_pr(fake)
    fake.serve(PR, pull(False, "o" * 40))
    fake.serve(RUNS, {"workflow_runs": [run("completed")]})

    result = fake.run(WAIT_TRIES="5", POLL_SECONDS="7")

    assert result.returncode == 0, result.stdout + result.stderr
    assert fake.gets().count(f"GET {PR}") == 2
    assert fake.clock() == 0


NOT_REBUILT = (
    f"::warning::#7: GitHub did not rebuild the merge ref on {TIP} within the wait; "
    "the re-run will fail if it still has not"
)


def test_a_merge_ref_that_is_never_rebuilt_is_rerun_after_the_wait(fake):
    one_open_pr(fake)
    fake.serve(PR, pull(None, None))
    fake.serve(RUNS, {"workflow_runs": [run("completed")]})

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert NOT_REBUILT in result.stdout.splitlines()
    assert fake.gets().count(f"GET {PR}") == 4
    assert fake.requests() == [RERUN]


def test_a_pull_request_with_no_run_is_reported_and_nothing_is_written(fake):
    """A pull request opened before the workflow existed has no run to re-run."""
    one_open_pr(fake)
    rebuilt(fake)
    fake.serve(RUNS, {"workflow_runs": []})

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert no_own_run(7, HEAD) in result.stdout.splitlines()
    assert fake.requests() == []


def no_own_run(pr, head):
    return (f"::warning::#{pr} has no check-hooks.yml run for its head {head} that is known "
            "to be its own, so there is nothing to re-run; a push to its branch starts one")


def test_no_open_pull_request_is_nothing_to_do(fake):
    fake.serve(PULLS, [])

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert f"no open pull request targets {BASE}" in result.stdout.splitlines()
    assert fake.requests() == []


def test_a_refused_rerun_fails_the_job_and_the_others_are_still_rerun(fake):
    """One pull request's failure must not hide behind the next one's success."""
    head2, merge2 = "g" * 40, "k" * 40
    fake.serve(PULLS, [{"number": 7, "head": {"sha": HEAD}}, {"number": 8, "head": {"sha": head2}}])
    rebuilt(fake)
    fake.serve(f"repos/{REPO}/pulls/8", pull(True, merge2, head2))
    fake.serve(f"repos/{REPO}/commits/{merge2}", {"parents": [{"sha": TIP}, {"sha": head2}]})
    fake.serve(RUNS, {"workflow_runs": [run("completed")]})
    fake.serve(RUNS.replace(HEAD, head2),
               {"workflow_runs": [run("completed", id=43, title="#8 another")]})
    fake.fail("POST", f"repos/{REPO}/actions/runs/42/rerun")

    result = fake.run()

    assert result.returncode == 1
    assert fake.requests() == [RERUN, f"POST repos/{REPO}/actions/runs/43/rerun"]
    assert (
        f"::error::#7: the re-run of {URL} was refused, "
        "so its check still stands on the old merge; a push to its branch starts a new run"
    ) in result.stdout.splitlines()


def test_a_failed_run_listing_fails_the_job_rather_than_reading_as_no_run(fake):
    """No RUNS fixture: the fake gh exits 1, as a failed request would."""
    one_open_pr(fake)
    rebuilt(fake)

    result = fake.run()

    assert result.returncode == 1
    assert "::error::#7: could not list its check-hooks.yml runs, so its check was not re-run" \
        in result.stdout.splitlines()
    assert fake.requests() == []


def test_a_run_that_never_stops_is_still_asked_to_rerun_after_the_wait(fake):
    """GitHub refuses that re-run; the refusal is what fails the job."""
    one_open_pr(fake)
    rebuilt(fake)
    fake.serve(RUNS, {"workflow_runs": [run("in_progress")]})
    fake.serve(f"repos/{REPO}/actions/runs/42", {"status": "in_progress"})
    fake.fail("POST", f"repos/{REPO}/actions/runs/42/rerun")

    result = fake.run()

    assert result.returncode == 1
    assert fake.requests() == [CANCEL, RERUN]
    assert fake.gets().count(f"GET repos/{REPO}/actions/runs/42") == 3
    assert (
        f"::warning::#7: {URL} did not stop within the wait, "
        "and GitHub refuses to re-run a run that has not stopped"
    ) in result.stdout.splitlines()


def test_a_refused_cancel_is_reported_and_the_rerun_still_asked_for(fake):
    one_open_pr(fake)
    rebuilt(fake)
    fake.serve(RUNS, {"workflow_runs": [run("in_progress")]})
    fake.serve(f"repos/{REPO}/actions/runs/42", {"status": "completed"})
    fake.fail("POST", f"repos/{REPO}/actions/runs/42/cancel")

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert (
        f"::warning::#7: the cancel of {URL} was refused; "
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


def test_a_failed_pull_request_read_fails_the_job_and_is_not_blamed_on_github(fake):
    """No PR fixture. The re-run is still asked for: skipping it would leave the
    stale green standing."""
    one_open_pr(fake)
    fake.serve(RUNS, {"workflow_runs": [run("completed")]})

    result = fake.run()

    assert result.returncode == 1
    assert (
        f"::error::#7: could not read the pull request, so whether its merge ref is rebuilt "
        f"on {TIP} is unknown; re-running it anyway"
    ) in result.stdout.splitlines()
    assert HEAD_UNREAD in result.stdout.splitlines()
    assert NOT_REBUILT not in result.stdout.splitlines()
    # One read in the wait, one of the head before the re-run.
    assert fake.gets().count(f"GET {PR}") == 2
    assert fake.requests() == [RERUN]


HEAD_UNREAD = (f"::error::#7: could not re-read its head, so whether {HEAD} is still it is "
               "unknown; the re-run goes ahead")


def test_a_failed_merge_commit_read_fails_the_job_and_is_not_blamed_on_github(fake):
    """No commits fixture for the merge commit."""
    one_open_pr(fake)
    fake.serve(PR, pull(True, MERGE))
    fake.serve(RUNS, {"workflow_runs": [run("completed")]})

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
    rebuilt(fake)
    fake.serve(RUNS, {"workflow_runs": [run("in_progress")]})

    result = fake.run()

    assert result.returncode == 1
    assert (
        f"::error::#7: could not read the status of {URL}, "
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


# --------------------------------------------------------------------------- #
# item 1: the head is read again before every write
# --------------------------------------------------------------------------- #

MOVED = (f"#7: its head moved from {HEAD} to {NEW} after it was listed, so {URL} is not its "
         f"check any more; its new head's own run tests the merge on {TIP}, and the ")


def test_a_head_that_moved_before_the_rerun_leaves_the_old_heads_run_alone(fake):
    """Re-running H1's run would join check-hooks-7 and cancel H2's own run."""
    one_open_pr(fake)
    rebuilt(fake, NEW)
    fake.serve(RUNS, {"workflow_runs": [run("completed")]})

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert MOVED + "re-run is not asked for" in result.stdout.splitlines()
    assert fake.requests() == []


def test_a_head_that_moved_before_the_cancel_leaves_the_old_heads_run_alone(fake):
    one_open_pr(fake)
    rebuilt(fake, NEW)
    fake.serve(RUNS, {"workflow_runs": [run("in_progress")]})

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert MOVED + "cancel is not asked for" in result.stdout.splitlines()
    assert fake.requests() == []


def test_a_head_that_moved_after_the_cancel_is_not_rerun(fake):
    one_open_pr(fake)
    rebuilt(fake, HEAD, NEW)
    fake.serve(RUNS, {"workflow_runs": [run("in_progress")]})
    fake.serve(f"repos/{REPO}/actions/runs/42", {"status": "completed"})

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert MOVED + "re-run is not asked for" in result.stdout.splitlines()
    assert fake.requests() == [CANCEL]


# --------------------------------------------------------------------------- #
# item 2: a pull request's own run, by the number its title is stamped with
# --------------------------------------------------------------------------- #

def two_prs_sharing_a_head(fake):
    fake.serve(PULLS, [{"number": 7, "head": {"sha": HEAD}}, {"number": 8, "head": {"sha": HEAD}}])
    rebuilt(fake)
    fake.serve(f"repos/{REPO}/pulls/8", pull(True, MERGE))


def test_two_pull_requests_sharing_a_head_each_get_their_own_run_rerun(fake):
    """Both runs list both pull requests in `pull_requests` -- GitHub fills it
    with every open pull request whose head matches -- so only the stamped
    title tells them apart. The newest run for the head is #8's."""
    two_prs_sharing_a_head(fake)
    fake.serve(RUNS, {"workflow_runs": [
        run("completed", id=43, title="#8 the other", prs=(7, 8)),
        run("completed", id=42, title="#7 a pull request", prs=(7, 8)),
    ]})

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert fake.requests() == [RERUN, f"POST repos/{REPO}/actions/runs/43/rerun"]


def test_a_stamp_is_read_to_its_end_so_seventy_is_not_seven(fake):
    one_open_pr(fake)
    rebuilt(fake)
    fake.serve(RUNS, {"workflow_runs": [run("completed", title="#70 another")]})

    result = fake.run()

    assert no_own_run(7, HEAD) in result.stdout.splitlines()
    assert fake.requests() == []


def test_an_unstamped_run_is_taken_when_it_lists_only_this_pull_request(fake):
    """A run from before check-hooks.yml stamped its title."""
    one_open_pr(fake)
    rebuilt(fake)
    fake.serve(RUNS, {"workflow_runs": [run("completed", title="a pull request", prs=(7,))]})

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert fake.requests() == [RERUN]


def test_an_unstamped_run_listing_two_pull_requests_is_nobodys(fake):
    two_prs_sharing_a_head(fake)
    fake.serve(RUNS, {"workflow_runs": [run("completed", title="a pull request", prs=(7, 8))]})

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert no_own_run(7, HEAD) in result.stdout.splitlines()
    assert no_own_run(8, HEAD) in result.stdout.splitlines()
    assert fake.requests() == []


def test_a_stamped_run_from_a_fork_is_rerun(fake):
    """GitHub leaves `pull_requests` empty on a fork's run; the stamp is enough."""
    one_open_pr(fake)
    rebuilt(fake)
    fake.serve(RUNS, {"workflow_runs": [run("completed", prs=())]})

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert fake.requests() == [RERUN]


def test_an_unstamped_run_from_a_fork_is_not_rerun_which_is_the_trade(fake):
    """The trade, pinned: with no stamp and an empty `pull_requests` nothing says
    whose run it is, so it is not re-run, and its check stays green on the old
    merge until a push to its branch starts a stamped run."""
    one_open_pr(fake)
    rebuilt(fake)
    fake.serve(RUNS, {"workflow_runs": [run("completed", title="a pull request", prs=())]})

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert no_own_run(7, HEAD) in result.stdout.splitlines()
    assert fake.requests() == []


# --------------------------------------------------------------------------- #
# item 3: the waits are shared and bounded in total
# --------------------------------------------------------------------------- #

def four_slow_prs(fake):
    """Four pull requests whose merge refs are never rebuilt and whose runs are
    in progress and never stop."""
    heads = {pr: chr(ord("c") + pr - 7) * 40 for pr in (7, 8, 9, 10)}
    fake.serve(PULLS, [{"number": pr, "head": {"sha": h}} for pr, h in heads.items()])
    for pr, h in heads.items():
        fake.serve(f"repos/{REPO}/pulls/{pr}", pull(None, None, h))
        fake.serve(RUNS.replace(HEAD, h),
                   {"workflow_runs": [run("in_progress", id=40 + pr, title=f"#{pr} slow")]})
        fake.serve(f"repos/{REPO}/actions/runs/{40 + pr}", {"status": "in_progress"})
    return [
        f"POST repos/{REPO}/actions/runs/47/cancel",
        f"POST repos/{REPO}/actions/runs/48/cancel",
        f"POST repos/{REPO}/actions/runs/49/cancel",
        f"POST repos/{REPO}/actions/runs/50/cancel",
        f"POST repos/{REPO}/actions/runs/47/rerun",
        f"POST repos/{REPO}/actions/runs/48/rerun",
        f"POST repos/{REPO}/actions/runs/49/rerun",
        f"POST repos/{REPO}/actions/runs/50/rerun",
    ]


def test_slow_pull_requests_stay_within_the_deadline_and_every_one_is_rerun(fake):
    """At 36 tries of 10 s each wait could sleep 350 s, and the two waits 700 s;
    the deadline holds the whole job's sleeping to 60 s, and every pull request
    is still cancelled and re-run."""
    writes = four_slow_prs(fake)

    result = fake.run(POLL_SECONDS="10", WAIT_TRIES="36", DEADLINE_SECONDS="60")

    assert fake.clock() == 60
    assert fake.requests() == writes
    for pr in (7, 8, 9, 10):
        assert (f"::warning::#{pr}: the job's 60 s of waiting ran out before GitHub rebuilt the "
                f"merge ref on {TIP}; re-running it anyway, and the re-run will fail if it "
                "still has not") in result.stdout.splitlines()
        assert (f"::warning::#{pr}: the job's 60 s of waiting ran out before "
                f"https://github.com/{REPO}/actions/runs/{40 + pr} stopped, and GitHub "
                "refuses to re-run a run that has not stopped") in result.stdout.splitlines()


def test_slow_pull_requests_are_waited_on_together(fake):
    """With no deadline in reach, four slow pull requests cost one wait, not
    four: each of the two waits sleeps between its 3 rounds, 2 x 10 s."""
    writes = four_slow_prs(fake)

    result = fake.run(POLL_SECONDS="10", WAIT_TRIES="3", DEADLINE_SECONDS="600")

    assert result.returncode == 0, result.stdout + result.stderr
    assert fake.clock() == 40
    assert fake.gets().count(f"GET repos/{REPO}/pulls/9") == 3 + 2
    assert fake.requests() == writes


def test_the_last_sleep_is_cut_to_the_deadline(fake):
    """A poll of 25 s against a deadline of 60 s sleeps 25, 25 and then 10."""
    four_slow_prs(fake)

    fake.run(POLL_SECONDS="25", WAIT_TRIES="36", DEADLINE_SECONDS="60")

    assert fake.clock() == 60


# --------------------------------------------------------------------------- #
# item 4: a run proven to have tested the merge on TIP is left alone
# --------------------------------------------------------------------------- #

ARTIFACTS = f"repos/{REPO}/actions/runs/42/artifacts?name=check-hooks-attempt-2"
ZIP = f"repos/{REPO}/actions/artifacts/900/zip"


def artifact_zip(record):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as z:
        z.writestr("check-hooks.log", "ALL CHECKS PASSED\n")
        z.writestr("check-hooks.json", json.dumps(record))
    return buffer.getvalue()


def proven_current(fake, conclusion="success"):
    one_open_pr(fake)
    rebuilt(fake)
    fake.serve(RUNS, {"workflow_runs": [run("completed", conclusion=conclusion, attempt=2)]})
    fake.serve(ARTIFACTS, {"artifacts": [{"id": 900, "expired": False}]})
    fake.serve_raw(ZIP, artifact_zip({"exit_status": 0, "tested_commit": MERGE}))


@pytest.mark.parametrize("conclusion", ["success", "failure"])
def test_a_run_that_already_tested_the_merge_on_the_tip_is_not_rerun(fake, conclusion):
    """A red run that tested this merge stays red on a re-run; so does a green."""
    proven_current(fake, conclusion)

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert (f"#7: {URL} already tested {MERGE}, the merge of its head {HEAD} on {TIP}, "
            "so it is not re-run") in result.stdout.splitlines()
    assert fake.requests() == []


def test_a_run_proven_current_whose_head_then_moved_is_left_alone(fake):
    proven_current(fake)
    rebuilt(fake, NEW)

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert MOVED + "re-run is not asked for" in result.stdout.splitlines()
    assert fake.requests() == []


def unproven(label):
    def apply(fake):
        proven_current(fake)
        {
            "cancelled": lambda: fake.serve(RUNS, {"workflow_runs": [
                run("completed", conclusion="cancelled", attempt=2)]}),
            "timed-out": lambda: fake.serve(RUNS, {"workflow_runs": [
                run("completed", conclusion="timed_out", attempt=2)]}),
            "no-conclusion": lambda: fake.serve(RUNS, {"workflow_runs": [
                run("completed", attempt=2)]}),
            "no-artifact": lambda: fake.serve(ARTIFACTS, {"artifacts": []}),
            "two-artifacts": lambda: fake.serve(ARTIFACTS, {"artifacts": [
                {"id": 900, "expired": False}, {"id": 901, "expired": False}]}),
            "expired": lambda: fake.serve(ARTIFACTS, {"artifacts": [
                {"id": 900, "expired": True}]}),
            "no-tested-commit": lambda: fake.serve_raw(ZIP, artifact_zip({"exit_status": 0})),
            "other-commit": lambda: fake.serve_raw(ZIP, artifact_zip({"tested_commit": OTHER})),
            "merge-of-another-head": lambda: fake.serve(
                f"repos/{REPO}/commits/{MERGE}", {"parents": [{"sha": TIP}, {"sha": OTHER}]}),
            "conflicting": lambda: fake.serve(PR, pull(False, MERGE)),
        }[label]()
    return apply


@pytest.mark.parametrize(("label", "said"), [
    ("cancelled", None),
    ("timed-out", None),
    ("no-conclusion", None),
    ("no-artifact", f"#7: {URL} has 0 unexpired check-hooks-attempt-2 artifacts, not one, "
                    "so what it tested is unknown; re-running it"),
    ("two-artifacts", f"#7: {URL} has 2 unexpired check-hooks-attempt-2 artifacts, not one, "
                      "so what it tested is unknown; re-running it"),
    ("expired", f"#7: {URL} has 0 unexpired check-hooks-attempt-2 artifacts, not one, "
                "so what it tested is unknown; re-running it"),
    ("no-tested-commit", f"#7: check-hooks.json of {URL} names no tested commit; re-running it"),
    ("other-commit", f"#7: {URL} tested {OTHER}, not {MERGE}, its merge on {TIP}; re-running it"),
    ("merge-of-another-head", f"#7: its merge {MERGE} merges {OTHER}, not its head {HEAD}; "
                              "re-running it"),
    ("conflicting", None),
])
def test_a_run_not_proven_current_is_rerun(fake, label, said):
    """Absent or mismatched evidence is a re-run: a wrong skip is a stale green."""
    unproven(label)(fake)

    result = fake.run()

    assert result.returncode == 0, result.stdout + result.stderr
    if said:
        assert said in result.stdout.splitlines()
    assert "already tested" not in result.stdout
    assert fake.requests() == [RERUN]


@pytest.mark.parametrize(("missing", "said"), [
    (ARTIFACTS, f"::error::#7: could not list the artifacts of {URL}, so what it tested is "
                "unknown; re-running it"),
    (ZIP, f"::error::#7: could not read check-hooks.json from artifact 900 of {URL}, so what "
          "it tested is unknown; re-running it"),
])
def test_unreadable_evidence_fails_the_job_and_is_a_rerun(fake, missing, said):
    proven_current(fake)
    fake.unserve(missing)

    result = fake.run()

    assert result.returncode == 1
    assert said in result.stdout.splitlines()
    assert fake.requests() == [RERUN]


def test_a_zip_without_the_json_is_unreadable_evidence(fake):
    proven_current(fake)
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as z:
        z.writestr("check-hooks.log", "")
    fake.serve_raw(ZIP, buffer.getvalue())

    result = fake.run()

    assert result.returncode == 1
    assert (f"::error::#7: could not read check-hooks.json from artifact 900 of {URL}, so what "
            "it tested is unknown; re-running it") in result.stdout.splitlines()
    assert fake.requests() == [RERUN]


def test_an_unreadable_head_proves_nothing_and_is_a_rerun(fake):
    proven_current(fake)
    fake.serve(PR, pull(True, MERGE), FAIL)

    result = fake.run()

    assert result.returncode == 1
    assert HEAD_UNREAD in result.stdout.splitlines()
    assert "already tested" not in result.stdout
    assert fake.requests() == [RERUN]

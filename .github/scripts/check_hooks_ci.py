"""
What the `check-hooks` workflow runs around the hook check suite (#199).

Two subcommands, one per thing a green run has to be true about:

``verify-merge``
    The commit under test is the merge result of the pull request against its
    base's *current* tip -- not the head, not the base, and not a merge GitHub
    computed before the base moved. That last one is the defect #199 was filed
    for: on PR #196 a branch stayed green for 51 minutes while seven commits
    behind `dev-05`, because every run was taken on a branch tip. GitHub does
    not recompute `refs/pull/N/merge` while a pull request conflicts with its
    base, so a stale merge ref is also how a conflict reaches this check, and
    it fails rather than testing the old merge.

    Parents are read from the commit object (`git cat-file -p`), not from
    `git rev-list --parents`: `actions/checkout` fetches at depth 1, and a
    shallow boundary commit is printed with no parents at all. The base's tip
    is read from origin at the moment of the check (`git ls-remote`), which
    needs no token on a public repository.

``report``
    Reads the suite's log and writes three things: the job summary a reviewer
    reads instead of the log, with its failing rows and their detail lines;
    the step outputs; and a JSON file uploaded beside the log. The last two
    are the machine-readable counts #193 asked for, and they are NOT the
    quantities `mutate-hooks.sh` pins. `MEASURED_AT_RESULTS` is the count on
    the suite's own matrix line, a little under the rows the log prints, and
    `MEASURED_SECONDS_PER_RUN` is timed the way the harness pays for a run,
    in `--matrix` mode against a copied tree on the workstation, not on a
    hosted 2-core runner. So `results` and `seconds` here are what a run
    printed and how long it took. How the harness's constants follow from
    them is #193's to settle.

    A row is a line opening with ``"  ok   "`` or ``"  FAIL "``, which
    `check-hooks.sh` guarantees is printed only by its `pass` and `fail`. A
    failing row's detail is the lines after it up to the next row, section
    heading (``===`` or ``---``) or blank line; a `fail` message may span
    lines, and the hook's stderr is the part a reviewer needs.

    The job's colour comes from the suite's exit status, not from here. This
    exits 1 only when that status claims a pass the log does not support -- an
    exit 0 with a failing row, with a log whose last non-empty line is not
    ``ALL CHECKS PASSED``, or with no row at all -- because a green job there
    would be the lie.

Standard library only, and logging via a handler configured in `main`: the
runner has `python3` and no project environment, so `src.logging_setup` is not
importable here. Messages opening with ``::error::`` are GitHub workflow
commands and are annotated on the run.
"""
import argparse
import json
import logging
import re
import subprocess
import sys

logger = logging.getLogger(__name__)

OK_PREFIX = "  ok   "
FAIL_PREFIX = "  FAIL "
PASSED_LINE = "ALL CHECKS PASSED"
FAILED_LINE = "SOME CHECKS FAILED"
# GitHub refuses a step summary over 1 MiB, and the whole summary is lost with
# it. Failing rows are added whole until the next would take their text past
# half of that, so the bound is on bytes, which is what GitHub counts. A row
# count would not bound it: a row's detail lines have no length limit. Rows
# past the budget are left to the uploaded log, and the summary says how many.
SUMMARY_ROW_BYTES = 512 * 1024
# A suite that exits non-zero with no failing row stopped in a guard, and a
# guard's message is its last few lines. Forty covers a message and the
# section headings before it, and is enough to say where the suite stopped.
TAIL_LINES = 40


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout


def append_output(path, pairs):
    if path:
        with open(path, "a", encoding="utf-8") as fh:
            for key, value in pairs:
                fh.write(f"{key}={value}\n")


# --------------------------------------------------------------------------- #
# verify-merge
# --------------------------------------------------------------------------- #

def verify_merge(head_sha, base_ref, remote, output):
    tested = git("rev-parse", "HEAD").strip()
    raw = git("cat-file", "-p", tested)
    parents = []
    for line in raw.splitlines():
        if not line:
            break  # the header ends at the first blank line
        if line.startswith("parent "):
            parents.append(line.split()[1])

    if len(parents) != 2:
        logger.info(
            "::error::the tested commit %s has %d parent(s), not 2: it is not a merge "
            "result, so this run would test a branch tip", tested, len(parents))
        return 1
    base_parent, head_parent = parents

    try:
        listed = git("ls-remote", remote, f"refs/heads/{base_ref}").split()
    except subprocess.CalledProcessError as exc:
        logger.info("::error::could not read %s's tip from %s, so nothing can say whether "
                    "the tested commit is built on it: %s", base_ref, remote, exc.stderr.strip())
        return 1
    base_now = listed[0] if listed else None

    logger.info("tested commit:          %s", tested)
    logger.info("  first parent (base):  %s", base_parent)
    logger.info("  second parent (head): %s", head_parent)
    if base_now is None:
        logger.info(
            "::error::%s has no branch %s, so nothing can say whether the tested "
            "commit is built on its tip", remote, base_ref)
        return 1
    logger.info("  %s on %s now: %s", base_ref, remote, base_now)

    if head_parent != head_sha:
        logger.info("::error::the tested commit merges %s, but the pull request's head is %s",
                    head_parent, head_sha)
        return 1
    if base_parent != base_now:
        logger.info(
            "::error::the tested commit is built on %s, but %s on %s is now at %s: this "
            "is not the merge result of the pull request as it stands. GitHub has not "
            "recomputed the merge ref: it rebuilds it some seconds after the base "
            "moves, and not at all while the pull request conflicts with its base",
            base_parent, base_ref, remote, base_now)
        return 1

    logger.info("the tested commit is the merge of the pull request's head into its "
                "base's current tip")
    append_output(output, [("tested_commit", tested), ("base_parent", base_parent),
                           ("head_parent", head_parent)])
    return 0


# --------------------------------------------------------------------------- #
# report
# --------------------------------------------------------------------------- #

def is_boundary(line):
    return (not line.strip() or line.startswith((OK_PREFIX, FAIL_PREFIX, "===", "---")))


def parse_log(text):
    """Return (passed, failing rows each with their detail lines, verdict line or None)."""
    lines = text.splitlines()
    passed = 0
    failing = []
    for i, line in enumerate(lines):
        if line.startswith(OK_PREFIX):
            passed += 1
        elif line.startswith(FAIL_PREFIX):
            block = [line]
            for detail in lines[i + 1:]:
                if is_boundary(detail):
                    break
                block.append(detail)
            failing.append(block)
    non_empty = [line for line in lines if line.strip()]
    last = non_empty[-1] if non_empty else None
    verdict = last if last in (PASSED_LINE, FAILED_LINE) else None
    return passed, failing, verdict


def fenced(lines):
    """A code block whose fence is longer than any backtick run inside it."""
    longest = max((len(run) for line in lines for run in re.findall(r"`+", line)), default=0)
    fence = "`" * max(3, longest + 1)
    return f"{fence}text\n" + "".join(f"{line}\n" for line in lines) + f"{fence}\n"


def report(log_path, exit_status, seconds, tested_commit, json_path, summary_path, output):
    with open(log_path, encoding="utf-8", errors="replace") as fh:
        text = fh.read()
    passed, failing, verdict = parse_log(text)
    failed = len(failing)
    results = passed + failed

    problems = []
    if exit_status == 0:
        if failed:
            problems.append(f"the suite exited 0 but its log holds {failed} failing row(s)")
        if results == 0:
            problems.append("the suite exited 0 but its log holds no result row at all")
        if verdict != PASSED_LINE:
            problems.append(f"the suite exited 0 but its log does not end with {PASSED_LINE}")
    for problem in problems:
        logger.info("::error::%s", problem)
    green = exit_status == 0 and not problems

    data = {
        "results": results,
        "passed": passed,
        "failed": failed,
        "seconds": seconds,
        "exit_status": exit_status,
        "verdict": verdict,
        "tested_commit": tested_commit,
    }
    with open(json_path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")
    append_output(output, [("results", results), ("passed", passed), ("failed", failed),
                           ("seconds", seconds), ("exit_status", exit_status)])

    parts = [
        f"## check-hooks: {'passed' if green else 'FAILED'}\n",
        "\n",
        "| results | passed | failed | seconds | exit status | tested commit |\n",
        "|---|---|---|---|---|---|\n",
        f"| {results} | {passed} | {failed} | {seconds} | {exit_status} | `{tested_commit}` |\n",
        "\n",
    ]
    for problem in problems:
        parts.append(f"**{problem}**\n\n")
    if failing:
        parts.append(f"### Failing rows ({failed})\n\n")
        shown, size, rows_shown = [], 0, 0
        for block in failing:
            block_size = sum(len(line.encode("utf-8")) + 1 for line in block)
            if size + block_size > SUMMARY_ROW_BYTES:
                break
            shown.extend(block)
            size += block_size
            rows_shown += 1
        if shown:
            parts.append(fenced(shown))
        if rows_shown < failed:
            parts.append(f"\n{failed - rows_shown} more failing row(s) are in the "
                         "uploaded log.\n")
    elif exit_status != 0:
        parts.append(f"The suite exited {exit_status} without printing a failing row. "
                     "The end of its log:\n\n")
        parts.append(fenced(text.splitlines()[-TAIL_LINES:]))
    parts.append("\nThe full log and this summary's numbers as JSON are uploaded as "
                 "this run's `check-hooks-attempt-N` artifact.\n")
    with open(summary_path, "a", encoding="utf-8") as fh:
        fh.write("".join(parts))

    return 1 if problems else 0


def main(argv=None):
    logging.basicConfig(level=logging.INFO, format="%(message)s", stream=sys.stdout)
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)

    v = sub.add_parser("verify-merge", help="the tested commit is the merge on the current base")
    v.add_argument("--head-sha", required=True)
    v.add_argument("--base-ref", required=True)
    v.add_argument("--remote", default="origin")
    v.add_argument("--output", help="$GITHUB_OUTPUT")

    r = sub.add_parser("report", help="summarise the suite's log")
    r.add_argument("--log", required=True)
    r.add_argument("--exit-status", type=int, required=True)
    r.add_argument("--seconds", type=int, required=True)
    r.add_argument("--tested-commit", required=True)
    r.add_argument("--json", required=True)
    r.add_argument("--summary", required=True, help="$GITHUB_STEP_SUMMARY")
    r.add_argument("--output", help="$GITHUB_OUTPUT")

    args = parser.parse_args(argv)
    if args.command == "verify-merge":
        return verify_merge(args.head_sha, args.base_ref, args.remote, args.output)
    return report(args.log, args.exit_status, args.seconds, args.tested_commit,
                  args.json, args.summary, args.output)


if __name__ == "__main__":
    sys.exit(main())

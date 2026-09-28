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
    `fail` message may span lines, and the hook's stderr it embeds is the part
    a reviewer needs, so `fail` marks every line of its message after the
    first with `DETAIL_INDENT`, a blank line included, whatever the line
    already starts with (#224). A failing row's detail is the unbroken run of
    lines right after it that open with that indent, and the summary shows
    each with exactly one indent removed, so the stderr reads as the hook
    wrote it. A line is what `fail` calls one, cut at a newline and nowhere
    else: `str.splitlines` also cuts at a carriage return, a form feed and
    seven more, and a stderr holding one would have lost the rest of its
    detail at a line `fail` never indented. The trade: a log written with
    CRLF endings would keep a carriage return on every line, so its last line
    would not read as ``ALL CHECKS PASSED`` and an exit 0 would be refused.
    That fails closed, and the log is written by `tee` on a Linux runner.

    Until #224 the log did not say which lines were a row's, and the detail
    was guessed: the lines up to the next row, section heading (``===`` or
    ``---``) or blank line. That took a library's stderr printed at column 0
    before the next row as the failing row's detail, which run 35836366963's
    log can produce, and it cut a stderr short at its first blank line or
    line opening ``---``, a diff's. A column-0 line is now never detail, and a
    blank or ``---`` line inside a message is.

    THE OPEN CASE, recorded and not fixed: a stray line that `fail` did not
    print but that happens to open with the indent is read as detail of the
    failing row above it. The log cannot tell it from a continuation line.
    One printer of such lines reaches the log: when `mutate-hooks.sh --list`
    fails, `checks/unsplit.sh` copies its stderr to the log with the indent in
    front, `sed 's/^/       /'`. It cannot be taken as detail, because the
    line right before it is that check's own message at column 0, and the
    suite exits right after it; no run measured so far has taken that path.
    Two sweeps found no other, and each is evidence only of what it read: one
    over the text of `.claude/hooks/` for `echo`, `printf`, `awk` and
    `sed 's/^/…/'` printers and heredocs, whose every other hit writes into a
    `fail` message or into output a check captures, and one over the logs of
    four full runs of the suite, none of which took that path either (review
    of PR #285, rounds 1 and 2). A test pins the behaviour as accepted, not as
    wanted.

    The summary stays under GitHub's 1 MiB cap for any log, on either path
    (#207). Each failing row is shown up to `ROW_BYTES`, and a row over it is
    cut there and ends with a line saying so (#227), so no one row can take
    the block and hide the rows after it, and the first row is always shown.
    A capped row is shown if it fits what is left of `SUMMARY_BLOCK_BYTES`,
    fences counted; a row that does not fit is skipped rather than ending the
    list. Every row not shown is named, in log order, by its `FAIL` line cut
    to `NAME_BYTES`, in a block of its own held to `NAMES_BLOCK_BYTES`, and a
    log with more of them than that holds counts the rest. When the suite
    exits non-zero without a failing row, the log's last `TAIL_LINES` lines
    are shown, cut from their start to `SUMMARY_BLOCK_BYTES`, and the summary
    says how many bytes were cut. An exit 0 shows no tail, even when the log
    does not support it (#228).

    How the suite step ended is recorded beside the counts, as ``ended``
    (#208): ``exited`` when the step wrote the suite's exit status, else
    ``cancelled`` or ``timed-out`` by what the step's outcome reads for each
    (observed on real runs, cited in check-hooks.yml's header), else
    ``unknown``, which fails this. ``exit_status`` is null unless the suite
    exited, and ``seconds`` unless it started. Before #208 a missing status was
    written as 124, so a routine cancel -- 21 of the last 60 runs when #208 was
    triaged on 2026-09-25 -- read as a 20-minute hang.

    The job's colour comes from the suite's exit status, not from here. This
    exits 1 when the step's ending is ``unknown``, and otherwise only when that
    status claims a pass the log does not support -- an
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
# What `fail` in .claude/hooks/checks/library.sh puts in front of every line of
# its message after the first (#224). Seven spaces, the width of FAIL_PREFIX, so
# a continuation line stands under the message's first character. It has to be
# three or more, or a row line would open with it. The library spells it too,
# and tests/test_check_hooks_ci.py runs the library's `fail` into this parser,
# so the two cannot drift apart with the tests green.
DETAIL_INDENT = "       "
PASSED_LINE = "ALL CHECKS PASSED"
FAILED_LINE = "SOME CHECKS FAILED"
# GitHub refuses a step summary over 1 MiB, and the whole summary is lost with
# it. The summary carries at most two code blocks: the failing rows or the
# log's tail, held to SUMMARY_BLOCK_BYTES, and the names of the failing rows not
# shown, held to NAMES_BLOCK_BYTES. Every note that grows with the number of
# rows -- a cut row's marker, a name -- is inside one of the two and counted
# there, so the text outside them is a fixed set of sentences with a few numbers
# in them: 460 bytes beside a full tail block (#207), and 858 on the rows path
# at its longest, a stopped suite with an outcome it cannot explain, measured
# with every count five digits long, a 40-character tested commit and a
# 14-character outcome (#227). So 512 + 256 KiB of blocks leave 256 KiB for
# that text. Each budget is counted in UTF-8 bytes, which is what GitHub
# counts, and with its block's fences. A fence is one backtick longer than the
# longest run inside it, so a block that is one run of backticks is three times
# its text; a budget on the text alone let 500 KiB of rows make a 1.1 MiB
# summary (#207). A row count would not bound it either: a row's detail lines
# have no length limit.
SUMMARY_BLOCK_BYTES = 512 * 1024
# The most any one failing row may take of the rows block: its `FAIL` line and
# detail, and the marker a cut row ends with. A row over it is shown from its
# start and cut, so no single row can take the block and hide the rows after it
# (#227): before, a 524,200-byte row was shown whole and the 20 rows after it
# were not. 32 KiB is 80 times the largest failing row of run 36427909808 (411
# bytes), the one of the last four failing runs whose log could still be
# downloaded when #227 was built, and holds the 2,000-line detail of 22,121
# bytes the parser's tests pass through whole. Fifteen rows at the cap fit the
# block, fences included, and a sixteenth does not. And the first row is
# always shown, for any log: a row that is one run of backticks is fenced at
# three times its text, 3 * 32,768 + 8 = 98,312 bytes at most, a fifth of the
# block.
ROW_BYTES = 32 * 1024
# How a cut row says so, as the last line of what is shown of it. It counts
# against ROW_BYTES; the room it takes is reserved at the row's whole size,
# which has at least as many digits as what is cut.
CUT_NOTE = "  [row cut here: its last {} bytes are in the uploaded log]"
# A failing row that is not shown is named by its `FAIL` line, and a `FAIL` line
# has no length limit either, so each is cut to its first NAME_BYTES. 512 is
# above every one of the 7,811 row lines in the log of run 36427909808 (the
# longest 371 bytes, the 99th percentile 193), so a real row's name is whole.
NAME_BYTES = 512
# The names are fenced in a block of their own, held to this. It holds 508 names
# of NAME_BYTES even when each is one run of backticks, 510 when none holds one,
# and about 3,400 of the median row line (75 bytes). A log with more failing
# rows not shown than that names the first in log order and counts the rest.
NAMES_BLOCK_BYTES = 256 * 1024
# A suite that exits non-zero with no failing row stopped in a guard, and a
# guard's message is its last few lines. Forty covers a message and the
# section headings before it, and is enough to say where the suite stopped.
# Forty lines are not a bound in bytes -- one line of a log can be any length
# -- so the tail is also cut to SUMMARY_BLOCK_BYTES, from its start, keeping
# the end where the message is, and the summary says how much was cut.
TAIL_LINES = 40
# What `steps.<id>.outcome` reads for a suite step that was stopped before it
# could write the suite's exit status. Observed, not taken from documentation:
# the runs are cited in check-hooks.yml's header (#208).
OUTCOME_CANCELLED = "cancelled"
OUTCOME_TIMED_OUT = "failure"
STOPPED_BY = {
    "cancelled": "the run was cancelled while it ran",
    "timed-out": "its step ran out of time",
    "unknown": "its step stopped before writing its exit status, and nothing recorded why",
}


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

def parse_log(text):
    """
    Return (passed, failing rows, verdict line or None). A failing row is its
    row line and then its detail lines, each with one `DETAIL_INDENT` removed.
    """
    # A trailing newline ends the last line; it does not open another.
    lines = text.removesuffix("\n").split("\n") if text else []
    passed = 0
    failing = []
    for i, line in enumerate(lines):
        if line.startswith(OK_PREFIX):
            passed += 1
        elif line.startswith(FAIL_PREFIX):
            block = [line]
            # The indent is the whole rule: a blank line of a message is an
            # indent-only line, and so is detail, and a column-0 line never is.
            # The open case the module docstring records is here too -- a stray
            # line opening with the indent is taken, because nothing on it says
            # it is not `fail`'s.
            for detail in lines[i + 1:]:
                if not detail.startswith(DETAIL_INDENT):
                    break
                block.append(detail[len(DETAIL_INDENT):])
            failing.append(block)
    non_empty = [line for line in lines if line.strip()]
    last = non_empty[-1] if non_empty else None
    verdict = last if last in (PASSED_LINE, FAILED_LINE) else None
    return passed, failing, verdict


def longest_run(line):
    return max((len(run) for run in re.findall(r"`+", line)), default=0)


def fenced(lines):
    """A code block whose fence is longer than any backtick run inside it."""
    fence = "`" * max(3, max((longest_run(line) for line in lines), default=0) + 1)
    return f"{fence}text\n" + "".join(f"{line}\n" for line in lines) + f"{fence}\n"


def fenced_size(text_bytes, longest):
    """The bytes `fenced` writes for lines of `text_bytes` bytes, newlines
    included, whose longest backtick run is `longest`: the lines, two fences,
    the info string `text` and a newline after each fence."""
    return text_bytes + 2 * max(3, longest + 1) + 6


def line_bytes(line):
    return len(line.encode("utf-8")) + 1


def clip_from_end(lines, budget):
    """
    The last of `lines` whose fenced block fits in `budget` bytes, and how many
    bytes of `lines` that leaves out. The first line from the end that does not
    fit whole is kept in part, from its end, at a character boundary: the
    largest part that fits, found by bisection because a part's fence depends
    on the backticks in it and grows with it.
    """
    kept, size, longest = [], 0, 0
    for line in reversed(lines):
        run = longest_run(line)
        if fenced_size(size + line_bytes(line), max(longest, run)) <= budget:
            kept.append(line)
            size += line_bytes(line)
            longest = max(longest, run)
            continue
        encoded = line.encode("utf-8")

        def last_bytes(n):
            # "ignore" drops the bytes of a character the cut splits, so a
            # longer cut never decodes to less text, and the bisection's
            # "fits" is monotone. "replace" would break both: U+FFFD is three
            # bytes standing for one.
            return encoded[len(encoded) - n:].decode("utf-8", "ignore")

        low, high = 0, len(encoded)
        while low < high:
            mid = (low + high + 1) // 2
            part = last_bytes(mid)
            if fenced_size(size + line_bytes(part), max(longest, longest_run(part))) <= budget:
                low = mid
            else:
                high = mid - 1
        if low:
            kept.append(last_bytes(low))
        break
    kept.reverse()
    return kept, sum(map(line_bytes, lines)) - sum(map(line_bytes, kept))


def first_bytes(line, n):
    """The first `n` bytes of `line`, less the bytes of a character the cut
    would split: "ignore" drops them, where "replace" would add three bytes of
    U+FFFD in their place."""
    return line.encode("utf-8")[:max(n, 0)].decode("utf-8", "ignore")


def capped(block):
    """
    A failing row as shown: whole if it fits ROW_BYTES, else its lines from the
    start up to ROW_BYTES, the first line that does not fit kept in part, and
    CUT_NOTE last, saying how many bytes are left out. The note's room is taken
    first, at the digits of the row's whole size, which what is cut cannot have
    more of, so the note and the text together never pass ROW_BYTES. Fences are
    the block's and not a row's, so they are counted where rows are put in it.
    """
    total = sum(map(line_bytes, block))
    if total <= ROW_BYTES:
        return block
    budget = ROW_BYTES - line_bytes(CUT_NOTE.format(total))
    kept, size = [], 0
    for line in block:
        if size + line_bytes(line) > budget:
            part = first_bytes(line, budget - size - 1)  # less the part's newline
            if part:
                kept.append(part)
            break
        kept.append(line)
        size += line_bytes(line)
    return kept + [CUT_NOTE.format(total - sum(map(line_bytes, kept)))]


def how_it_ended(exit_status, suite_outcome, started):
    """
    "exited", "cancelled", "timed-out" or "unknown" (#208). The suite step
    writes the suite's exit status whatever it is, so a status present means
    the suite exited, even under a cancel that landed after it. A status absent
    means the step was stopped, and its outcome says by what: OUTCOME_CANCELLED
    and OUTCOME_TIMED_OUT are what GitHub was observed to report for each, on
    the runs the workflow's header cites. A failed step is a timeout only once
    the suite had `started`: from there to the exit status nothing but the
    suite runs, under `set +e`, so only a timeout fails it. Before that, a
    failed command fails it too, and that is not a timeout.
    """
    if exit_status is not None:
        return "exited"
    if suite_outcome == OUTCOME_CANCELLED:
        return "cancelled"
    if suite_outcome == OUTCOME_TIMED_OUT and started:
        return "timed-out"
    return "unknown"


def report(log_path, exit_status, suite_outcome, seconds, tested_commit, json_path,
           summary_path, output):
    # newline="" keeps a carriage return inside a hook's stderr as it is,
    # where the default would make it a line break `fail` never indented.
    with open(log_path, encoding="utf-8", errors="replace", newline="") as fh:
        text = fh.read()
    passed, failing, verdict = parse_log(text)
    failed = len(failing)
    results = passed + failed
    ended = how_it_ended(exit_status, suite_outcome, started=seconds is not None)

    problems = []
    if ended == "unknown":
        problems.append(f"the suite step wrote no exit status and its outcome is "
                        f"'{suite_outcome}', which is neither a cancel nor a timeout")
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
        "ended": ended,
        "verdict": verdict,
        "tested_commit": tested_commit,
    }
    with open(json_path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")
    append_output(output, [("results", results), ("passed", passed), ("failed", failed),
                           ("seconds", "" if seconds is None else seconds),
                           ("exit_status", "" if exit_status is None else exit_status),
                           ("ended", ended)])

    parts = [
        f"## check-hooks: {'passed' if green else 'FAILED'}\n",
        "\n",
        "| results | passed | failed | seconds | exit status | ended | tested commit |\n",
        "|---|---|---|---|---|---|---|\n",
        f"| {results} | {passed} | {failed} | {'–' if seconds is None else seconds} | "
        f"{'–' if exit_status is None else exit_status} | {ended} | `{tested_commit}` |\n",
        "\n",
    ]
    for problem in problems:
        parts.append(f"**{problem}**\n\n")
    stopped = f"The suite did not exit: {STOPPED_BY[ended]}." if exit_status is None else None
    if failing:
        if stopped:
            parts.append(f"{stopped}\n\n")
        parts.append(f"### Failing rows ({failed})\n\n")
        # Every row is capped at ROW_BYTES, so none takes the block and hides
        # the rest (#227), and the first is always shown. Rows are taken in log
        # order, and a capped row that does not fit what is left is skipped
        # and the loop goes on (#207), so a row that widens the fence past the
        # room left does not hide the small rows after it. A skipped row is
        # not shown, and is named below instead: so the rows not shown are not
        # always the last ones, and nothing below says they are.
        shown, size, longest, not_shown = [], 0, 0, []
        for block in failing:
            row = capped(block)
            row_size = sum(map(line_bytes, row))
            row_longest = max(map(longest_run, row))
            if fenced_size(size + row_size, max(longest, row_longest)) > SUMMARY_BLOCK_BYTES:
                not_shown.append(block[0])
                continue
            shown.extend(row)
            size += row_size
            longest = max(longest, row_longest)
        if shown:
            parts.append(fenced(shown))
        if not_shown:
            # Named in log order until NAMES_BLOCK_BYTES is used, and the rest
            # counted. The loop stops at the first name that does not fit
            # rather than skipping it, so the rows left unnamed are the last
            # ones, which is what the count says.
            names, size, longest = [], 0, 0
            for line in not_shown:
                name = first_bytes(line, NAME_BYTES)
                if fenced_size(size + line_bytes(name),
                               max(longest, longest_run(name))) > NAMES_BLOCK_BYTES:
                    break
                names.append(name)
                size += line_bytes(name)
                longest = max(longest, longest_run(name))
            parts.append(f"\n{len(not_shown)} of the {failed} failing rows are not shown "
                         "above, to keep this summary under GitHub's 1 MiB limit; the "
                         "uploaded log holds them. Their `FAIL` lines, in log order, each "
                         f"cut to its first {NAME_BYTES} bytes:\n\n")
            parts.append(fenced(names))
            if len(names) < len(not_shown):
                parts.append(f"\nThe last {len(not_shown) - len(names)} of those "
                             f"{len(not_shown)} are not named here either, for the "
                             "same reason.\n")
    elif exit_status != 0:
        lead = stopped or f"The suite exited {exit_status} without printing a failing row."
        parts.append(f"{lead} The end of its log:\n\n")
        tail, cut = clip_from_end(text.splitlines()[-TAIL_LINES:], SUMMARY_BLOCK_BYTES)
        parts.append(fenced(tail))
        if cut:
            parts.append(f"\nThe first {cut} bytes of those lines are cut, to keep this "
                         "summary under GitHub's 1 MiB limit. The uploaded log holds them.\n")
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
    r.add_argument("--exit-status", type=int,
                   help="the suite's; omitted when the suite step wrote none")
    r.add_argument("--suite-outcome", required=True,
                   help="steps.<suite>.outcome, which says what stopped a step that wrote none")
    r.add_argument("--seconds", type=int,
                   help="since the suite started; omitted when it never did")
    r.add_argument("--tested-commit", required=True)
    r.add_argument("--json", required=True)
    r.add_argument("--summary", required=True, help="$GITHUB_STEP_SUMMARY")
    r.add_argument("--output", help="$GITHUB_OUTPUT")

    args = parser.parse_args(argv)
    if args.command == "verify-merge":
        return verify_merge(args.head_sha, args.base_ref, args.remote, args.output)
    return report(args.log, args.exit_status, args.suite_outcome, args.seconds,
                  args.tested_commit, args.json, args.summary, args.output)


if __name__ == "__main__":
    sys.exit(main())

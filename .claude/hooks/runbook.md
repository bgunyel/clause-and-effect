# The live acceptance runbook

What the check suite cannot reach, and how to verify it by hand. Some of the
boundary's requirements live in configuration the harness reads, in settings
GitHub holds, or in behaviour that only exists in a live session, and a check
that runs a hook as a process sees none of them. #103 decided (Q3, Q17) that
these are a runbook and not checks, and #110 wrote it.

A requirement verified here is written in `requirements.md`, or under
`requirements/`, with `seam: none` and `verify: runbook §<n>`, and `§<n>` is a
`## §<n>` heading below, and the only one numbered `<n>`. `check-hooks.sh`
fails on a `verify: runbook §<n>` that names no such heading (#104), on a
number that heads two sections, and on a section whose **Verifies** line does
not name exactly the requirements that point at it (#110). **Also observes**
names requirements a section reads the live half of while checks cover the
rest; they point at no section, because an entry with `seam: none` has no
check tagged with it, and these have checks.

## How to run it, and where the results go

**This file is instructions and holds no results.** A run's results go in
`docs/eval-reports/<date>-boundary-runbook-<HHMMSS>.md`, one file per run,
dated and append-only, and the newest one per section is the current answer.
`HHMMSS` is a local time at which one of the run's steps was taken, and is
there only to keep two runs on one day apart.
That directory and not the dev-log, because a run is a record of what was
observed at a point in time, which is `docs/eval-reports/`'s job in CLAUDE.md's
table, where the dev-log is one narrative per session: a run Bertan makes in his
own terminal has no session to put it in, and a result filed inside a session's
narrative is found only by reading the narrative. A run may cover some sections
and not others; its record says which, and names every section it did not run.

For each section a record gives the date, who ran it, the commit of this file
it followed, the `claude --version` where a session is involved, every command
as run, and what it printed, verbatim. A record may shorten -- a scratch path
to `<scratch>`, a filter this file gives to a name for it, an output line to
the part that matters -- and says so where it does; it never shortens an
expected literal. A run made while this file was being written, before it had a
commit, names the commit that first carried it.
An observation is what was seen, not whether it matched: a record says
"matches" only beside the output that shows it.

**Who runs it.** Each section says. *An agent* means any session working in
this repository, and the steps are reads, or writes confined to a scratch
directory outside it. *Bertan* means a step that changes something an agent
must not: the machine's network, or a worktree whose removal is a reserved act.

**When an observation differs from the expected one** (Q18): file a bug and
link it under #36 as a sub-issue (`docs/agents/issue-tracker.md` says how),
titled `runbook §<n>: <what differed>`, with the record's command and output
quoted. Do not edit the expectation here to match what was seen; the issue
decides whether the requirement or the expectation was wrong, and a change here
lands with it.

## §1 The worktree fork point

**Verifies:** US-5, US-6.
**Also observes:** GH-99.2, whose check reads that `worktree.baseRef` is
`fresh` and cannot show the harness honours it; GH-99.3, the SessionStart
report's `main ancestry` line.

"0 behind" alone passes a branch that starts *ahead* of the active dev branch,
which is #99's defect, so every expectation below is 0 behind **and** 0 ahead:
the fork point is `origin/dev-NN` itself. Replace `dev-NN` below with the
`active dev branch:` the SessionStart report printed, and `<branch>` with the
new branch's name.

### §1a `git worktree add` (an agent)

The route CLAUDE.md gives first. An agent runs it at the start of its own work,
so the worktree it creates is the one it works in, and the steps after it are
reads. Run them before the first commit.

```bash
git fetch origin
git worktree add --no-track -b <branch> <path> origin/dev-NN
git rev-list --left-right --count origin/dev-NN...<branch>
git for-each-ref --format='%(upstream)' refs/heads/<branch>
```

Expected: the count prints `0	0` (a tab between), and the upstream read prints
an empty line.

### §1b `EnterWorktree`, then a reset (Bertan, or an agent entering its own worktree)

`EnterWorktree` creates a worktree whose fork point `worktree.baseRef` decides,
and CLAUDE.md's second route resets it onto `origin/dev-NN` as the first act.
Record the fork point **before** the reset, which is what `baseRef` gave, and
again after.

```bash
# in the session: call EnterWorktree, then, in the new worktree, read before
# any fetch, so the counts are against the refs the harness forked from:
B=$(git branch --show-current); echo "$B"
git rev-list --left-right --count origin/dev-NN..."$B"
git rev-list --left-right --count origin/main..."$B"
git rev-list --left-right --count origin/dev-NN...origin/main
git for-each-ref --format='%(upstream)' "refs/heads/$B"
# and only then the reset, CLAUDE.md's first act, against a fresh dev branch:
git fetch origin
git reset --hard origin/dev-NN
git rev-list --left-right --count origin/dev-NN..."$B"
git for-each-ref --format='%(upstream)' "refs/heads/$B"
```

Expected before the reset, with `baseRef` `fresh` and no
`.claude/settings.local.json` overriding it: the count against `origin/main`
prints `0	0`, and the count against `origin/dev-NN` prints what the third
count, `origin/dev-NN...origin/main`, prints, since the branch is
`origin/main`. All three are read before the fetch: a fetch between the fork
and the reads moves `origin/main` past the branch whenever `main` has moved
since the harness's own read, and the count then reads `1	0` for a fork that
was right (review round 3 of the pull request that closed #110). While
`origin/main` is an ancestor of
`origin/dev-NN`, which §1d reads, that is the dev branch's commits ahead of
`main` on the left and `0` on the right; while it is not, the right is the
commits `main` has that the dev branch lacks, and neither is a difference.
Expected after:
`0	0`. The upstream read prints an empty line both times. #110 left the
upstream to be observed rather than expected, and its first run found none
set; had it found one, #99's rule would have gained
`git branch --unset-upstream`, and a run that finds one now is a difference
like any other.

A worktree made here is not removed here: removing one is a reserved act, and
Bertan's sweep does it. The harness's half of this section -- what `fresh`
gives and whether an upstream is set -- can also be observed by an agent in a
scratch repository, as §1c is, with a local `origin` holding `main` and a
`dev-NN` ahead of it and the scratch `.claude/settings.json` setting
`"worktree": {"baseRef": "fresh"}`. That run cannot see this repository's
`settings.local.json`, and a record says which of the two it made.

### §1c What the harness documentation does not settle (an agent, in a scratch project)

#99 Q8's four questions. Each answer is recorded with how it was seen. They are
asked in a scratch git repository outside this one, whose own
`.claude/settings.json` carries a logging hook, and never in this repository's
settings.

1. Does a `WorktreeCreate` hook fire for `EnterWorktree`, as well as for
   `--worktree`, `isolation: "worktree"` and background sessions, which the
   documentation names?
2. Does the harness or the hook create the `worktree-` branch?
3. What working directory does the hook run in?
4. Can a `PostToolUse` matcher match `EnterWorktree`?

The hook, one script for both events, appends to a log file its label, its
standard input, `pwd`, and `git -C "$CLAUDE_PROJECT_DIR" branch --list
'worktree-*'` at the moment it runs, exits 0, and prints and changes nothing
else. Two sessions, each started in a scratch repository of its own with
`claude -p`, `--setting-sources project` and `--allowedTools EnterWorktree`,
and each asked to call `EnterWorktree` once: the first with only the
`PostToolUse` hook, matcher `EnterWorktree`, which answers question 4 and is
where §1b's harness half is read; the second with a `WorktreeCreate` hook as
well, which answers 1 to 3. They are two sessions because a `WorktreeCreate`
hook takes the creation over, so the second one creates no worktree for §1b
to read. `--worktree`, `isolation: "worktree"` and background sessions are
routes of their own, each taken the same way.

Expected, as #110's first run found for `EnterWorktree`, which is the baseline
for every later run since the documentation settles none of it:

1. It fires. The log holds a `=== WorktreeCreate` entry whose standard input
   carries `"hook_event_name":"WorktreeCreate"` and `"name":"probe"`.
2. The hook creates the branch, and the whole worktree: the entry's
   `worktree- branches` read is empty, none exists after, and `EnterWorktree`
   fails with
   `WorktreeCreate hook failed: hook succeeded but returned no worktree path (command: echo the path to stdout; http/callback: return hookSpecificOutput.worktreePath)`.
3. Its `pwd` is the session's project directory, the scratch repository's
   root, and so is the payload's `cwd`.
4. Yes. The `PostToolUse` log holds an entry with `"tool_name":"EnterWorktree"`,
   whose `pwd` is the new worktree and whose `worktree- branches` read names
   the new branch.

The other three routes have no baseline yet; their first run sets it.

If `WorktreeCreate` fires for any route, #113, the follow-up issue on a
`WorktreeCreate` hook, proceeds, and the record says so.

### §1d The `main ancestry` line (an agent)

```bash
bash .claude/hooks/report-stale-branches.sh </dev/null \
  | awk '/^main ancestry:/ { p = 1; print; next } p && /^       / { print; next } p { exit }'
git merge-base --is-ancestor origin/main origin/dev-NN; echo $?
```

The report is run here, rather than read off the session's start, and this
run fetches nothing between it and the second command, so both read the refs
the report's own fetch left, unless another session on this machine fetches in
the second between them. Compared with a report from the session's start, a
fetch since then can move either ref and make two right answers disagree. The
report is the SessionStart hook, run by hand: it deletes no branch and no
worktree, and its fetch prunes remote-tracking refs, as every session's start
does.

Expected: `0`, and the report's line opens
`main ancestry: origin/main is an ancestor of origin/dev-NN`. `1` and a line
opening `main ancestry: origin/main is NOT an ancestor of origin/dev-NN -- a branch cut`
agree as well; what differs is the two disagreeing. Each literal is the
message's opening and not the whole of it: the `NOT` message goes on for two
more lines, and when the report's own fetch failed, which is §6's case, the
message's last line ends in ` (read against refs the failed fetch left behind)`
-- its first line in the ancestor case, its third in the `NOT` case.

**When it differs:** a sub-issue of #36, as *When an observation differs* says.
A `0	0` that is not, or an upstream that is set, is the #99 defect back.

## §2 The `main` ruleset

**Verifies:** GH-110.1.
**Also observes:** US-1, whose checks refuse an agent's push to `main` and
cannot see the server-side rule that also refuses Bertan's.

An agent may run it: all three calls are reads, made with Bertan's credentials,
which is also what makes the bypass list readable at all.

```bash
gh api repos/bgunyel/clause-and-effect --jq .default_branch
gh api repos/bgunyel/clause-and-effect/rulesets \
  --jq '.[] | select(.name == "main-branch-protection") | .id'
gh api repos/bgunyel/clause-and-effect/rulesets/<id> \
  --jq '{target, enforcement, include: .conditions.ref_name.include, exclude: .conditions.ref_name.exclude, bypass_actors, requires_pull_request: ([.rules[].type] | index("pull_request") != null)}'
```

Expected: `main`; one id; and

```
{"bypass_actors":[],"enforcement":"active","exclude":[],"include":["~DEFAULT_BRANCH"],"requires_pull_request":true,"target":"branch"}
```

`gh --jq` prints an object's keys sorted, whatever order the filter builds
them in.

The ruleset names the default branch rather than `main`, which is why the
first call is part of the section: the rule protects `main` only while `main`
is the default branch. And it protects the branch it includes only while that
branch is not also excluded and the ruleset targets branches at all, which is
why `exclude` and `target` are read: without them, a ruleset excluding `main`,
or switched to target tags, printed the expected line byte for byte (review
round 1 of PR #287, measured against the live ruleset's JSON mutated locally).

**When it differs:** a sub-issue of #36, as *When an observation differs* says.
A rule that is gone, or a bypass actor that is not, is a hole in US-1 no hook
can close.

## §3 The merge settings

**Verifies:** FR-39.
**Also observes:** FR-41, the SessionStart report's `merge settings` line.

An agent may run it: the call is a read.

```bash
gh api repos/bgunyel/clause-and-effect \
  --jq '[.allow_squash_merge, .allow_rebase_merge, .delete_branch_on_merge] | map(tostring) | @tsv'
bash .claude/hooks/report-stale-branches.sh </dev/null \
  | awk '/^merge settings:/ { p = 1; print; next } p && /^       / { print; next } p { exit }'
```

Expected: `false	false	true` (tabs between), and the `merge settings` line
of the report, run by hand right after the API as §1d runs it, reads
`merge settings: as required (squash off, rebase off, delete-on-merge on)`.
A report from the session's start read the settings at another time.

**When it differs:** a sub-issue of #36, as *When an observation differs* says;
if the report's line disagrees with the API, the defect is the report's, FR-41.

## §4 A refusal reaches the agent

**Verifies:** GH-110.2.
**Also observes:** US-7, whose checks read a refusal's message off the hook's
standard error and cannot see what the harness passes on.

What it watches is a hook on the Bash tool, in an interactive session, and
GH-110.2 claims no more than that. An Edit or Write hook's refusal, which
`append-only-docs-edit.sh` makes, is not watched here.

An agent runs it, in a live session, because the observation is what the
agent is shown. The command is `pytest --version`, chosen because this
section is about delivery and not the verdict: were the hook to permit it,
running it changes nothing. The verdict is learned first by feeding the hook,
never by running a command whose effect matters.

```bash
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"pytest --version"}}' \
  | bash .claude/hooks/pytest-via-uv-group.sh; echo "rc=$?"
# then, as a Bash tool call of its own:
pytest --version
```

Expected from the feed: exit `2` and, on standard error,

```
Blocked: bare pytest invocation. CLAUDE.md runs tests through the 'test' dependency group. Use: make test, or uv run --group test pytest tests/<file>::<test>
```

Expected from the tool call: it is refused, the command does not run, and the
agent is shown the same message byte for byte after the harness's prefix:

```
PreToolUse:Bash hook error: ["$CLAUDE_PROJECT_DIR"/.claude/hooks/pytest-via-uv-group.sh]: Blocked: bare pytest invocation. CLAUDE.md runs tests through the 'test' dependency group. Use: make test, or uv run --group test pytest tests/<file>::<test>
```

**When it differs:** a sub-issue of #36, as *When an observation differs* says.
A message that reaches the hook's stderr but not the agent leaves US-7's
messages unread.

## §5 A hook that outlasts its timeout

**Verifies:** GH-110.3.
**Also observes:** GH-96.1, whose checks hold the line cap and cannot see
the harness's kill that is the reason for it.

What the first run watched is a hook on the Bash tool under `claude -p`.
GH-110.3 is a claim about the harness, the interactive front end included,
and a run of the same two repositories in an interactive session is what this
section still owes it. An Edit or Write hook is outside GH-110.3, and the kill
is presumed of one, not watched.

#96's line cap argues that a hook the harness kills at its timeout permits the
command, and that is why no hook may be slow; #240 argues the same of a slow
git read. This section turns that premise into an observation. An agent may
run it: everything it writes is in a scratch directory, and the session it
starts is a second, headless one whose only project settings are the scratch
copy.

In a scratch directory `$S`, two git repositories, `timeout/` and `control/`,
each with a `.claude/settings.json` holding one `PreToolUse` hook on `Bash`
with `"timeout": 2`. The hook is `$S/hook.sh <seconds> <log>`:

```bash
#!/bin/bash
echo "start $(date +%s.%N)" >> "$2"
sleep "$1"
echo "finished $(date +%s.%N)" >> "$2"
echo "refused by the scratch hook" >&2
exit 2
```

`timeout/` passes `10` seconds, past the timeout, and `control/` passes `0`.
From inside each repository:

```bash
claude -p "Use the Bash tool exactly once to run this command and nothing else: touch $PWD/marker . Then reply with the tool result text verbatim and stop." \
  --setting-sources project --strict-mcp-config --model claude-haiku-4-5-20251001 \
  --allowedTools "Bash(touch:*)" --output-format stream-json --verbose > stream.jsonl
sleep 12; ls marker; cat hook.log
jq -c 'select(.type=="user") | .message.content[]? | select(.type=="tool_result") | {is_error, content}' stream.jsonl
```

Expected in `control/`: no `marker`, a log of `start` and `finished`, and

```
{"is_error":true,"content":"PreToolUse:Bash hook error: [<the hook's command>]: refused by the scratch hook\n"}
```

Expected in `timeout/`, which is #96's premise: `marker` exists, the log holds
`start` and no `finished` twelve seconds later, because the hook was killed,
and the agent is told nothing:

```
{"is_error":false,"content":"(Bash completed with no output)"}
```

`--setting-sources project` keeps the user's own hooks out of the scratch
session; `claude -p` is the harness without its interactive front end, and a
record says which it ran. A timed-out hook that *refused* would not be a hole,
but it would make #96's reasoning wrong, and the difference is filed like any
other.

**When it differs:** a sub-issue of #36, as *When an observation differs* says,
a timed-out hook that refused included: it opens no hole, and it still shows a
premise of #96's to be false.

## §6 An offline SessionStart

**Verifies:** GH-110.4.
**Also observes:** FR-42, whose checks read the report's text and output and
cannot see whether the harness starts a session around it.

Bertan runs it: it needs the machine's network down, which an agent cannot
arrange from inside a session that needs the network to run. Take the network
down, start `claude` in this repository, read the SessionStart report, quit,
and bring the network back.

Expected: the session starts, within the report hook's 50-second timeout, and
the report holds, among its other lines, four that open as below. Each is the
first line of what the report prints for that read, and the first three go on
past it:

```
fetch: FAILED or timed out after 15s -- remote-tracking refs are
merge settings: NOT READ -- gh api failed or timed out after 10s, so whether either detector in
pull requests: NOT READ -- gh api failed or timed out after 10s, so branches are
main ancestry: origin/main is an ancestor of origin/dev-NN (read against refs the failed fetch left behind)
```

The fourth is the ancestor case, which is one line. Which case it is depends
on the refs the last successful fetch left, as §1d's does, and the `NOT` case
is as right: its message opens as §1d's `NOT` literal and runs to three lines.
What does not depend on them is the suffix, which ends the message's last line
in either case -- its first line here, its third in the `NOT` case (review
round 3 of the pull request that closed #110; the source is the `main
ancestry` block of `report-stale-branches.sh`).

**When it differs:** a sub-issue of #36, as *When an observation differs* says.
A session that does not start, or starts only after the report's 50 s, is the
harness waiting on the report, and the report's `timeout` and budgets are where
to look.

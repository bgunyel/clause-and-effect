#!/bin/bash
# THE ISSUE FILE OF #110: the live acceptance runbook, and the requirements
# that point at it.
#
# Why a check at all, when a runbook is by definition what no check reaches.
# #104 already fails on a `verify: runbook §<n>` naming no `## §<n>` heading,
# which says a section exists and nothing about what it verifies. Each section
# opens with a **Verifies** line naming its requirements, for the reader who
# arrives at the runbook rather than at requirements.md, and a list that nothing
# reads is a list that goes stale the first time an entry moves to a section of
# its own: this repository's comments have lost counts that way twice. So the
# line is held both ways against the entries -- GH-110.5, below.
#
# THIS FILE DECLARES, AND CHECKS NOTHING, and prints no section heading, since
# a heading with no row under it is a finding. GH-110.5's comparison is a part
# of #104's requirements reader in end-of-run.sh, and its checks stand beside
# that reader's fixtures there. The first version was a copy of the reader's
# grammar here, and review of the pull request that closed #110 measured the
# copy narrower than the reader: a verify ending in a blank, or wrapped onto a
# continuation line, resolved for #104 and pointed nowhere for the copy, so a
# runbook that dropped the entry passed green. A reader in a file sourced
# after this one cannot be called from it, and moving the reader into the
# library to make it callable was the other way, rejected as three hundred
# lines of #104 moved for one caller.
#
# WHAT GH-110.5 DOES NOT HOLD, named. The **Also observes** lines, which say
# what else a section's live read happens to show: nothing in an entry records
# that, so there is nothing to hold them to. And the sections' expectations,
# which are literals for a person to compare against, and are right only as of
# the run that last compared them; the run records in docs/eval-reports/ are
# that evidence, and nothing here reads them.
#
# The requirements GH-110.1 to .4 are what the runbook sections §2, §4, §5 and
# §6 verify, which no entry named before #110: §1 and §3 verify US-5, US-6 and
# FR-39, which #104 wrote as `gap → #110` and #110 made active. All four are
# `seam: none`, so, like every such entry, they are declared here with no check
# tagged.

requirement GH-110.1 <<'REQ'
- text: `main` is protected server-side by the `main-branch-protection`
  ruleset: its enforcement is active, it targets the default branch, which is
  `main`, it requires a pull request, and its bypass list is empty. CLAUDE.md
  states the ruleset and the pull request; the target and the empty bypass list
  are what that statement needs in order to hold of `main` and of Bertan.
- from: #110
- kind: doc-claim
- status: active
- seam: none
- verify: runbook §2
REQ
requirement GH-110.2 <<'REQ'
- text: A hook's refusal reaches the agent: on a hook's exit 2 the harness
  refuses the tool call, the command does not run, and the agent is shown the
  hook's standard error byte for byte after a prefix naming the event and the
  hook. US-7's message is only worth writing if this holds.
- from: #110
- kind: doc-claim
- status: active
- seam: none
- verify: runbook §4
REQ
requirement GH-110.3 <<'REQ'
- text: A `PreToolUse` hook the harness kills at its timeout permits the tool
  call, and the agent is told nothing: the premise of #96's line cap, stated in
  THE LINE CAP in lib/command-scan.sh, and of #240.
- from: #110, section 5 of #110's decisions
- kind: doc-claim
- status: active
- seam: none
- verify: runbook §5
REQ
requirement GH-110.4 <<'REQ'
- text: A session started with the network down starts, and its SessionStart
  report says the fetch FAILED and the merge settings and the pull requests were
  NOT READ. The half FR-42's checks cannot see, which is the harness's.
- from: #110, and #36's Amendment of 2026-09-11
- kind: doc-claim
- status: active
- seam: none
- verify: runbook §6
REQ
requirement GH-110.5 <<'REQ'
- text: Each `## §<n>` section of runbook.md has one **Verifies** line, naming
  exactly the requirements, in requirements.md or under requirements/, whose
  `verify` is `runbook §<n>`.
- from: #110
- kind: doc-claim
- status: active
- direction: static: a property of two files' text
REQ
shape_pin 'GH-110.1:runbook GH-110.2:runbook GH-110.3:runbook GH-110.4:runbook GH-110.5:static'

sourced_to_end

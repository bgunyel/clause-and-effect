#!/bin/bash
# THE ISSUE FILE OF #110: the live acceptance runbook, and what holds it to the
# requirements that point at it.
#
# Why a check at all, when a runbook is by definition what no check reaches.
# #104 already fails on a `verify: runbook §<n>` naming no `## §<n>` heading,
# which says a section exists and nothing about what it verifies. Each section
# opens with a **Verifies** line naming its requirements, for the reader who
# arrives at the runbook rather than at requirements.md, and a list that nothing
# reads is a list that goes stale the first time an entry moves to a section of
# its own: this repository's comments have lost counts that way twice. So the
# line is held both ways against the entries -- an entry whose verify names the
# section and a line that leaves it out is red, and so is a line naming an ID
# whose verify names another section or none.
#
# WHAT THIS FILE DOES NOT HOLD, named. The **Also observes** lines, which name
# requirements a section reads the live half of while their checks cover the
# rest: nothing in an entry records that, so there is nothing to hold them to.
# And the sections' expectations, which are literals for a person to compare
# against, and are right only as of the run that last compared them; the run
# records in docs/eval-reports/ are that evidence, and nothing here reads them.
#
# The requirements GH-110.1 to .4 are what the runbook sections §2, §4, §5 and
# §6 verify, which no entry named before #110: §1 and §3 verify the US-5, US-6
# and FR-39 entries #104 wrote as `gap → #110`, and this pull request took those
# gaps off. All four are `seam: none`, so, like every such entry, they are
# declared here with no check tagged.

section "=== issue #110: every runbook section names the requirements that point at it ==="

requirement GH-110.1 <<'REQ'
- text: `main` is protected server-side by the `main-branch-protection`
  ruleset: its enforcement is active, it targets the default branch, which is
  `main`, it requires a pull request, and its bypass list is empty, as CLAUDE.md
  says.
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

# r110_disagree <requirements.md> <requirements dir> <runbook> -- one line per
# disagreement between the runbook's Verifies lines and the entries' verify
# fields, sorted, and nothing when they agree. An ID is anything of the three
# families' grammar on a Verifies line; the entry that owns a verify line is the
# last `### ` heading above it. A requirements file that cannot be read, or a
# runbook that cannot, is itself a line, so an unread input never agrees.
r110_disagree() {
  local reqmd=$1 reqdir=$2 runbook=$3 f files=
  for f in "$reqdir"/*.md; do [ -e "$f" ] && files="$files$f"$'\n'; done
  awk -v reqmd="$reqmd" -v files="$files" -v runbook="$runbook" '
    function readreq(path,    line, id, s, rs) {
      id = ""
      while ((rs = (getline line < path)) > 0) {
        if (line ~ /^### /) { id = line; sub(/^### /, "", id); sub(/[ \t].*$/, "", id) }
        else if (line ~ /^- verify: runbook §[0-9]+$/ && id != "") {
          s = line; sub(/^- verify: runbook §/, "", s); want[s, id] = 1; wsec[s] = 1
        }
      }
      if (rs < 0) print "unread: " path
      close(path)
    }
    BEGIN {
      readreq(reqmd)
      n = split(files, list, "\n")
      for (i = 1; i <= n; i++) if (list[i] != "") readreq(list[i])
      sec = ""; rbread = 0
      while ((rs = (getline line < runbook)) > 0) {
        rbread = 1
        if (line ~ /^## §[0-9]+( |$)/) {
          sec = line; sub(/^## §/, "", sec); sub(/[^0-9].*$/, "", sec); sections[sec] = 1
        } else if (line ~ /^\*\*Verifies:\*\*/ && sec != "") {
          nv[sec]++
          rest = line
          while (match(rest, /(US|FR|GH)-[1-9][0-9]*(\.[1-9][0-9]*)?/)) {
            have[sec, substr(rest, RSTART, RLENGTH)] = 1
            rest = substr(rest, RSTART + RLENGTH)
          }
        }
      }
      if (rs < 0 || !rbread) { print "unread: " runbook; exit }
      close(runbook)
      for (s in sections)
        if (!(s in nv)) print "§" s ": no Verifies line, where it has one"
        else if (nv[s] > 1) print "§" s ": " nv[s] " Verifies lines, where it has one"
      for (k in want) {
        split(k, p, SUBSEP)
        if ((p[1] in sections) && !(k in have)) print "§" p[1] ": " p[2] " points here, and the Verifies line does not name it"
      }
      for (k in have) {
        split(k, p, SUBSEP)
        if (!(k in want)) print "§" p[1] ": the Verifies line names " p[2] ", whose verify is not runbook §" p[1]
      }
    }' | LC_ALL=C sort
}

# THE FIXTURES: a requirements.md holding two entries that point at §1 and a
# third that points nowhere, a requirements/ directory holding one that points
# at §2, and runbooks that agree with them or depart in one way each.
R110="$FIXTURES/r110"
mkdir -p "$R110/requirements"
printf '%s\n' '### US-5' '- verify: runbook §1' '### US-6' '- verify: runbook §1' \
  '### FR-1' '- verify: review' > "$R110/requirements.md"
printf '%s\n' '### GH-9.1' '- verify: runbook §2' > "$R110/requirements/GH-9.1.md"
r110_runbook() {  # r110_runbook <name> <§1 Verifies line> <§2 Verifies line>
  printf '%s\n' '# runbook' '## §1 one' "$2" 'text' '### §1a sub' '## §2 two' "$3" > "$R110/$1.md"
}
r110_runbook agree '**Verifies:** US-5, US-6.' '**Verifies:** GH-9.1.'
r110_runbook dropped '**Verifies:** US-5.' '**Verifies:** GH-9.1.'
r110_runbook extra '**Verifies:** US-5, US-6, FR-1.' '**Verifies:** GH-9.1.'
r110_runbook moved '**Verifies:** US-5, US-6, GH-9.1.' '**Verifies:** GH-9.1.'
r110_runbook none '**Verifies:** US-5, US-6.' 'no such line'
printf '%s\n' '## §1 one' '**Verifies:** US-5, US-6.' '**Verifies:** US-5, US-6.' '## §2 two' \
  '**Verifies:** GH-9.1.' > "$R110/twice.md"
[ -r "$R110/requirements.md" ] && [ -r "$R110/requirements/GH-9.1.md" ] && [ -r "$R110/none.md" ] && [ -r "$R110/twice.md" ] || {
  echo "the #110 fixtures were not created; the checks against them prove nothing" >&2
  exit 1
}

req GH-110.5
tok 'a runbook whose Verifies lines name what points at each section agrees' \
    '' "$(r110_disagree "$R110/requirements.md" "$R110/requirements" "$R110/agree.md")"
tok 'one that leaves out an entry pointing at its section does not' \
    '§1: US-6 points here, and the Verifies line does not name it' \
    "$(r110_disagree "$R110/requirements.md" "$R110/requirements" "$R110/dropped.md")"
tok 'nor one naming an entry whose verify is not a runbook section' \
    '§1: the Verifies line names FR-1, whose verify is not runbook §1' \
    "$(r110_disagree "$R110/requirements.md" "$R110/requirements" "$R110/extra.md")"
tok 'nor one naming, from under requirements/, an entry that points at another section' \
    '§1: the Verifies line names GH-9.1, whose verify is not runbook §1' \
    "$(r110_disagree "$R110/requirements.md" "$R110/requirements" "$R110/moved.md")"
tok 'nor a section with no Verifies line, whose entries it also names as missing' \
    '§2: GH-9.1 points here, and the Verifies line does not name it
§2: no Verifies line, where it has one' \
    "$(r110_disagree "$R110/requirements.md" "$R110/requirements" "$R110/none.md")"
tok 'nor a section with a second Verifies line, which a reader would take for a correction' \
    '§1: 2 Verifies lines, where it has one' \
    "$(r110_disagree "$R110/requirements.md" "$R110/requirements" "$R110/twice.md")"
tok 'and a runbook that is not there is read as not read, never as agreeing' \
    "unread: $R110/no-such-runbook.md" \
    "$(r110_disagree "$R110/requirements.md" "$R110/requirements" "$R110/no-such-runbook.md")"
tok 'the runbook beside the judged hooks names, in each section, what points at it' \
    '' "$(r110_disagree "$HOOKS/requirements.md" "$HOOKS/requirements" "$HOOKS/runbook.md")"

sourced_to_end

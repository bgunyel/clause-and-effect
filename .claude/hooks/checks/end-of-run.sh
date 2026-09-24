#!/bin/bash
# THE END-OF-RUN FILE of the hook check suite: the checks that read the whole
# record every check before them wrote -- every requirement covered, every check
# tagged and given a direction, #148's count chain -- and REQUIREMENT_SHAPE with
# them. check-hooks.sh sources it last, whatever else it sources.
#
# THE COMMENTS KEPT THE POSITIONAL WORDS they were written with. "Above",
# "below", "this file" and "this suite" in a comment here mean the suite as one
# text, its files in the order the driver sources them -- which is the order
# they stood in when they were one file.

section "=== issue #104: every requirement is covered, and every check says which ==="
# The suite reads the requirements -- requirements.md, and the `GH-` entries
# under requirements/ since #200 -- and the tags every check above carries, and
# fails when the two do not meet. requirements.md says what a requirement is,
# what its fields mean and what covers one; this section is where that is
# computed, and it is the only place.
#
# Every check above is recorded as it prints, with its tags and its direction --
# see `record` in checks/library.sh. What is read here is that record,
# and nothing in it is derived by running a hook a second time.
#
# THE KNOWN GAPS ARE MARKED, NOT HIDDEN. An active requirement with no covering
# check fails the suite. #103's audit found several before this section existed,
# and #104 was told to land either with a failing count gated to a later issue
# or with each gap recorded. It records them: an entry whose status is `gap` and
# names the issue that owns it is listed by --matrix and not asked about here.
# The trade, taken knowingly: a gap that has since been covered stays marked
# until someone takes the marker off, which errs toward claiming less coverage
# than there is, and the matrix says of such a gap that its tags now meet
# coverage, so whoever owns it can see the marker is ready to come off. A check
# that failed a covered gap was considered and rejected,
# because a gap is often a requirement covered in part -- a story whose message
# is checked for one hook and not for two others -- and coverage here is one bit
# per ID.
#
# WHAT THIS IS NOT EVIDENCE OF, named because a check is evidence about what it
# names. A tag says a check establishes a requirement; nothing here can say the
# check is right about it, or that the checks tagged together are all of what the
# requirement asks. Coverage is the floor -- a refusing and a permitting check,
# or a declared direction -- and not the whole requirement. Whether the checks
# can fail is mutation's question, which this section does not ask.
#
# The logic is one awk program, run in two modes: `findings` prints one line per
# finding, each carrying the IDs it establishes, and `matrix` prints every
# requirement with its checks. It is driven below against a fixture first, with
# every expectation a literal, and only then against this repository -- so a
# finding that would pass by computing nothing is red before it is trusted.
#
# The number of acceptance criteria each of #36's stage tickets has, counted off
# the issues and not off requirements.md, which is what makes a criterion deleted
# from the provenance section fail rather than shorten the count it is held to.
PROVENANCE_COUNTS='37:8 38:6 39:6 40:13 41:8'
# THE SHAPE OF THE REQUIREMENTS, requirements.md and requirements/ (#200), as a
# literal and, since #205, the shape pins of the issue files beside it: every
# entry by ID between them, and beside each
# one whatever takes it off the both-directions rule -- a status other than
# active, a declared direction, and `seam: none` with the kind of its `verify`.
# Those three are everything the coverage check reads off an entry, so an edit
# to an entry that changes what the check asks of any requirement changes
# this literal: a marker added, taken off or moved to another entry, a direction
# declared, a move to no seam, a deletion. Each of those turned an uncovered
# requirement green with no finding at all.
#
# The first two versions of this held counts: of gaps and reviews, after review
# of #104, then of every family, status and verify kind, after Bertan's review
# of the pull request. Bertan's re-review found the two routes no count sees. A
# direction declared moved no number the literal held, and a gap marker moved
# from one entry to another leaves every count where it was. A count says how
# many entries are off the rule, and only a list says which. The change is
# written down twice, once in requirements.md and once here, and the second copy
# is the one a reviewer sees move in the diff. The refusing direction, one edit
# away.
#
# What it does not hold, named. The tags: a check tagged with an ID it does not
# establish covers that ID all the same, and only reading the check says so. And
# the direction each check records, which is this file's code, not
# requirements.md's.
#
# IT HOLDS THE LEGACY ENTRIES AND NO OTHER `GH-` ONE (#205). Every loop that
# added an entry appended a token here, so the conflict #200 took out of
# requirements.md stood in this hunk instead. An entry written after #205 is
# declared in its issue file, and its token is pinned there with `shape_pin`;
# what the comparison is handed is this literal with every pin,
# REQUIREMENT_SHAPE_HELD below, and the #205 checks at the end of this section
# go red on a generated entry written here and on a pin that is not once, in
# the issue file that declares its entry.
REQUIREMENT_SHAPE='
US-1:refuse-only US-2:refuse-only US-3 US-4:permit-only US-5:gap,runbook
US-6:gap,runbook US-7:refuse-only US-8 US-9 US-10 US-11 US-12
US-13:permit-only US-14:permit-only US-15 US-16:static US-17:review
US-18:review US-19:static US-20:static US-21:review US-22:static
US-23:static US-24:static US-25 US-26:static US-27:static US-28:static
US-29:static US-30:review US-31:static US-32:review
FR-1:superseded-by FR-2:static FR-3 FR-4 FR-5:review FR-6:static
FR-7:drifted FR-8:review FR-9:review FR-10:review FR-11:static FR-12:retired
FR-13:review FR-14 FR-15 FR-16 FR-17 FR-18 FR-19 FR-20 FR-21 FR-22:static
FR-23:refuse-only FR-24:static FR-25:static FR-26:static
FR-27:static FR-28:static FR-29:static FR-30:review FR-31:drifted
FR-32:review FR-33:static FR-34:superseded-by FR-35:static FR-36:review
FR-37:static FR-38 FR-39:gap,runbook FR-40:static FR-41:static FR-42:static
FR-43:static FR-44:static FR-45:static FR-46:static FR-47:static FR-48 FR-49
GH-43.1 GH-43.2 GH-43.3 GH-43.4 GH-43.5:refuse-only GH-43.6 GH-44.1 GH-44.2
GH-44.3 GH-44.4 GH-44.5 GH-44.6 GH-44.7:static GH-47.1 GH-47.2:refuse-only
GH-50.1 GH-50.2:refuse-only GH-50.3 GH-51.1 GH-51.2 GH-58.1 GH-58.2:static
GH-61:tests GH-62:static GH-63:static GH-68.1 GH-68.2 GH-68.3:refuse-only
GH-69.1 GH-69.2 GH-69.3 GH-70.1:static GH-70.2:static GH-70.3:static
GH-71:static GH-72 GH-73 GH-79.1 GH-79.2 GH-79.3:permit-only GH-79.4 GH-84.1
GH-84.2:static GH-84.3:static GH-94.1 GH-94.2 GH-94.3:review GH-94.4 GH-95.1
GH-95.2 GH-96.1 GH-96.2:static GH-96.3:static GH-97.1 GH-97.2:refuse-only
GH-98:static GH-99.1:static GH-99.2:static GH-99.3:static GH-100:static
GH-101:static GH-102:static GH-104.1:static GH-104.2:static GH-104.3:static
GH-104.4:static GH-104.5:review GH-106:static GH-117 GH-117.1:permit-only
GH-118:gap
GH-124:static GH-127:gap GH-130:superseded-by GH-131:gap GH-133:refuse-only
GH-134 GH-134.1:static GH-135:gap GH-136:gap GH-139 GH-167:gap GH-175:gap
GH-130.1 GH-130.2 GH-130.3 GH-130.4 GH-130.5 GH-130.6
GH-107.1:static GH-107.2:static GH-137.1 GH-137.2 GH-143.4:static GH-143.5:static      
GH-108.1 GH-108.2 GH-108.3 GH-108.4 GH-108.5 GH-108.6 GH-108.7                         
GH-108.8:static GH-108.9:static GH-108.10:static GH-156:gap GH-141:static
GH-128 GH-171:gap
GH-155.1:static GH-148:static
GH-109.1:static GH-109.2:refuse-only GH-109.3:static GH-109.4:static
GH-109.5:permit-only GH-164:gap
GH-200.1:static GH-200.2:static GH-200.3:static GH-200.4:static GH-200.5:static
GH-204.1:static GH-204.2:static GH-204.3:static GH-204.4:static GH-204.5:static
GH-204.6:static GH-204.7:static GH-204.8:static
'
# Every shape pin the issue files recorded, as tokens; see `shape_pin` in the
# #205 issue file.
REQUIREMENT_SHAPE_PINNED=$(awk -F'\t' '$1 == "shape" { print $3 }' "$PINNED" | tr '\n' ' ')
REQUIREMENT_SHAPE_HELD="$REQUIREMENT_SHAPE $REQUIREMENT_SHAPE_PINNED"
# `trim`, `keyword` and `after_colon` are not here: they are requirements.md's
# field grammar, which the #106 section reads too, and they live in
# REQ_FIELD_AWK above, prepended to this program by `requirements_read`.
REQUIREMENTS_AWK=$(cat <<'AWK'
  function emit(res, tags, text) { printf "%s\t%s\t%s\n", res, tags, text }
  function get(id, key) { return ((id, key) in field) ? field[id, key] : "" }
  function open_entry(id) {
    cur = id; curpart = part; lastkey = ""
    if (part == "req") {
      if (id in isreq) problem[++nproblem] = id ": the ID is used twice"
      else { isreq[id] = 1; order[++nreq] = id }
      if (id ~ /^GH-[0-9]+\.[0-9]+$/) { b = id; sub(/^GH-/, "", b); sub(/\..*$/, "", b); ghbase[b] = 1 }
      else if (id ~ /^GH-[0-9]+$/) { b = id; sub(/^GH-/, "", b); ghbase[b] = 1 }
      else if (id !~ /^(US|FR)-[0-9]+$/) problem[++nproblem] = id ": not an ID of the US, FR or GH family"
    } else if (part == "prov") {
      if (id ~ /^#[0-9]+\.[0-9]+$/) {
        crit[++ncrit] = id
        b = id; sub(/^#/, "", b); sub(/\..*$/, "", b); ccount[b]++
      } else problem[++nproblem] = id ": a provenance heading that names no criterion"
    }
  }
  function covered(id,   d, r, p, s) {
    if (get(id, "seam") == "none") return 1
    d = keyword(get(id, "direction")); r = cnt[id, "refuse"] + 0; p = cnt[id, "permit"] + 0; s = cnt[id, "static"] + 0
    if (d == "refuse-only") return r > 0
    if (d == "permit-only") return p > 0
    if (d == "static") return r + p + s > 0
    return r > 0 && p > 0
  }
  function counts(id) {
    return (cnt[id, "refuse"] + 0) " refusing, " (cnt[id, "permit"] + 0) " permitting, " (cnt[id, "static"] + 0) " static"
  }
  # One line of requirements.md or of a file of the split set. `insplit` says
  # which, and `sname` names the file: a file there holds one `GH-` entry and
  # nothing else, named by its ID (#200), and each way of breaking that is a
  # finding of its own rather than a line read as something it is not.
  function take(line) {
    if (line ~ /^## /) {
      cur = ""
      if (insplit) { problem[++nproblem] = "requirements/" sname ": a ## heading, where a file here holds one entry and nothing else"; return }
      heading = substr(line, 4)
      if (line ~ /^## Provenance/) part = "prov"
      else if (line ~ /^## Citations that are not requirements/) part = "cite"
      else if (line ~ /^## (User stories|Functional requirements|Boundary issues)$/) part = "req"
      else part = "other"
      return
    }
    if (line ~ /^### /) {
      hid = trim(substr(line, 5))
      if (insplit) {
        if (++nh > 1) problem[++nproblem] = "requirements/" sname ": holds a second entry, " hid ", where a file holds one"
        else {
          if (sname != hid ".md") problem[++nproblem] = "requirements/" sname ": holds " hid ", and a file is named by the ID it holds"
          if (hid !~ /^GH-[1-9][0-9]*(\.[1-9][0-9]*)?$/) problem[++nproblem] = hid ": not an ID of the grammar the split set holds, GH-<n> or GH-<n>.<m>"
        }
        open_entry(hid)
      } else if (part == "req" || part == "prov") {
        if (part == "req" && hid ~ /^GH-/) problem[++nproblem] = hid ": a GH- entry in requirements.md, where each is a file of its own under requirements/"
        open_entry(hid)
      } else {
        cur = ""
        if (hid ~ /^(US|FR|GH)-[0-9]/ || hid ~ /^#[0-9]+\.[0-9]+$/)
          problem[++nproblem] = hid ": an entry under the heading \"" heading "\", where no entry is read"
      }
      return
    }
    if (insplit && nh == 0 && line !~ /^[ \t]*$/) {
      problem[++nproblem] = "requirements/" sname ": text before its heading, where a file holds one entry and nothing else"
      return
    }
    if (part == "cite" && line ~ /^- #[0-9]+: ./) {
      n = line; sub(/^- #/, "", n); sub(/:.*$/, "", n); exempt[n] = 1
      return
    }
    if (cur != "" && line ~ /^- [a-z-]+:/) {
      key = line; sub(/^- /, "", key); sub(/:.*$/, "", key)
      val = line; sub(/^- [a-z-]+:/, "", val); val = trim(val)
      if ((cur, key) in field) problem[++nproblem] = cur ": the field " key " is given twice"
      field[cur, key] = val; lastkey = key
      return
    }
    if (cur != "" && lastkey != "" && line ~ /^  [^ ]/) {
      field[cur, lastkey] = field[cur, lastkey] " " trim(line)
      return
    }
    if (line !~ /^[ \t]*$/) {
      if (insplit) problem[++nproblem] = "requirements/" sname ": a line that is no field of its entry, where a file holds one entry and nothing else"
      lastkey = ""
    }
  }
  BEGIN {
    H = "#"
    # --- the requirements file ---------------------------------------------------
    part = ""; cur = ""; insplit = 0
    while ((getline line < reqs) > 0) take(line)
    close(reqs)
    # --- the split set beside it, in the order requirements_split gives -----------
    # Through the environment rather than -v, which would read a backslash in a
    # path as an escape. A file that cannot be read is a finding, not a skip.
    nsplit = split(ENVIRON["REQ_SPLIT_LIST"], splitpath, "\n")
    for (sp = 1; sp <= nsplit; sp++) {
      sname = splitpath[sp]; sub(/^.*\//, "", sname)
      insplit = 1; part = "req"; heading = ""; cur = ""; lastkey = ""; nh = 0
      while ((rs = (getline line < splitpath[sp])) > 0) take(line)
      close(splitpath[sp])
      if (rs < 0) problem[++nproblem] = "requirements/" sname ": could not be read"
      else if (nh == 0) problem[++nproblem] = "requirements/" sname ": holds no entry"
    }
    insplit = 0
    # A name there that is not a regular file is never handed to getline, which
    # under mawk aborts on a directory; it is named here instead.
    nother = split(ENVIRON["REQ_SPLIT_OTHER"], splitother, "\n")
    for (sp = 1; sp <= nother; sp++)
      if (splitother[sp] != "") problem[++nproblem] = "requirements/" splitother[sp] ": not a regular file, where each entry is a file of its own"
    runbook_read = 0
    while ((getline line < runbook) > 0) {
      runbook_read = 1
      if (line ~ /^## §[0-9]+( |$)/) { s = line; sub(/^## §/, "", s); sub(/[^0-9].*$/, "", s); rbsec[s] = 1 }
    }
    close(runbook)

    # --- the entries -------------------------------------------------------------
    for (i = 1; i <= nreq; i++) {
      id = order[i]
      if (get(id, "text") == "") problem[++nproblem] = id ": no text"
      if (get(id, "from") == "") problem[++nproblem] = id ": no from"
      st = get(id, "status"); kw = keyword(st)
      if (st == "") problem[++nproblem] = id ": no status"
      else if (kw == "active") { if (st != "active") problem[++nproblem] = id ": active carries nothing after it" }
      else if (kw == "retired" || kw == "drifted") { if (after_colon(st) == "") problem[++nproblem] = id ": " kw " with no reason" }
      else if (kw == "superseded-by") { tgt = after_colon(st); if (!(tgt in isreq)) problem[++nproblem] = id ": superseded by " tgt ", which is not a requirement" }
      else if (kw == "gap") { if (st !~ /^gap → #[0-9]+$/) problem[++nproblem] = id ": a gap names no issue that owns it" }
      else problem[++nproblem] = id ": the status " kw " is not one this file defines"
      k = get(id, "kind")
      if (id ~ /^GH-/) { if (k != "defect-permitting" && k != "defect-refusing" && k != "doc-claim") problem[++nproblem] = id ": the kind " (k == "" ? "is missing" : k " is not one this file defines") }
      else if ((id, "kind") in field) problem[++nproblem] = id ": a kind on an entry that is not a GH- one"
      if ((id, "direction") in field) {
        d = get(id, "direction"); dk = keyword(d)
        if (dk != "refuse-only" && dk != "permit-only" && dk != "static") problem[++nproblem] = id ": the direction " dk " is not one this file defines"
        else if (after_colon(d) == "") problem[++nproblem] = id ": the direction " dk " gives no reason"
      }
      hasseam = (id, "seam") in field; hasverify = (id, "verify") in field
      if (hasseam && get(id, "seam") != "none") problem[++nproblem] = id ": the seam is " get(id, "seam") ", and none is the only value"
      if (hasseam != hasverify) problem[++nproblem] = id ": seam and verify come together or not at all"
      if (hasseam && hasverify && kw != "gap") {
        v = get(id, "verify")
        if (v == "review") { }
        else if (v ~ /^tests\/[A-Za-z0-9_.-]+\.py$/) { vf = root "/" v; if ((getline x < vf) < 0) problem[++nproblem] = id ": verify names " v ", which is not there"; close(vf) }
        else if (v ~ /^runbook §[0-9]+$/) { s = v; sub(/^runbook §/, "", s); if (!(s in rbsec)) problem[++nproblem] = id ": verify names runbook §" s ", which " (runbook_read ? "has no such section" : "is not written") }
        else problem[++nproblem] = id ": verify is " v ", which is none of review, tests/<file>.py and runbook §<n>"
      }
    }

    # --- the provenance ----------------------------------------------------------
    for (i = 1; i <= ncrit; i++) {
      c = crit[i]
      if (get(c, "criterion") == "") provproblem[++nprov] = c " quotes no criterion"
      hasmaps = (c, "maps") in field; hasdropped = (c, "dropped") in field
      if (hasmaps && hasdropped) provproblem[++nprov] = c " is both mapped and dropped"
      else if (!hasmaps && !hasdropped) provproblem[++nprov] = c " is neither mapped nor dropped"
      else if (hasdropped && get(c, "dropped") == "") provproblem[++nprov] = c " is dropped with no reason"
      else if (hasmaps) {
        m = split(get(c, "maps"), ids, /, */)
        if (m == 0) provproblem[++nprov] = c " maps to nothing"
        for (j = 1; j <= m; j++) if (!(ids[j] in isreq)) provproblem[++nprov] = c " maps to " ids[j] ", which is not a requirement"
      }
    }
    m = split(counts_literal, pairs, " ")
    for (j = 1; j <= m; j++) {
      split(pairs[j], kv, ":")
      if ((ccount[kv[1]] + 0) != kv[2] + 0) provproblem[++nprov] = H kv[1] " has " (ccount[kv[1]] + 0) " criteria here, where the issue has " kv[2]
    }

    # --- the ledger --------------------------------------------------------------
    while ((getline line < ledger) > 0) {
      nres++
      split(line, f, "\t")
      if (f[1] == "") untagged[++nuntagged] = f[4]
      if (f[2] != "refuse" && f[2] != "permit" && f[2] != "static") baddir[++nbaddir] = f[2] ": " f[4]
      nt = split(f[1], t, " ")
      for (j = 1; j <= nt; j++) {
        if (t[j] in isreq) {
          cnt[t[j], f[2]]++
          checks[t[j]] = checks[t[j]] "\n    " (f[3] == "ok" ? "ok  " : "FAIL") " " f[4]
        } else if (!(t[j] in unknown)) { unknown[t[j]] = f[4]; unknownorder[++nunknown] = t[j] }
      }
    }
    close(ledger)
    # A requirement no check can reach that has checks after all is saying two
    # things, and the one that lets the coverage check pass is the one believed.
    for (i = 1; i <= nreq; i++) {
      id = order[i]
      if (get(id, "seam") == "none" && cnt[id, "refuse"] + cnt[id, "permit"] + cnt[id, "static"] > 0)
        problem[++nproblem] = id ": seam: none, and " counts(id) " are tagged with it"
    }
    # --- the shape -----------------------------------------------------------------
    # An entry is its ID, and beside it, comma-joined, whatever the coverage check
    # reads off it that departs from the both-directions rule: status, direction,
    # then the kind of verify a seam-less entry names. The two sides are compared
    # as sets, so a finding names the entries that changed and not the whole of
    # both.
    for (i = 1; i <= nreq; i++) {
      id = order[i]; marks = ""
      kw = keyword(get(id, "status"))
      if (kw != "active") marks = kw
      if ((id, "direction") in field) marks = marks (marks == "" ? "" : ",") keyword(get(id, "direction"))
      if (get(id, "seam") == "none") {
        v = get(id, "verify")
        if (v == "review") vk = "review"
        else if (v ~ /^tests\//) vk = "tests"
        else if (v ~ /^runbook /) vk = "runbook"
        else vk = "none"
        marks = marks (marks == "" ? "" : ",") vk
      }
      if (marks != "") noffrule++
      filetok[i] = id (marks == "" ? "" : ":" marks)
      infile[filetok[i]] = 1
    }
    lit = shape_literal; gsub(/^[ \t\n]+|[ \t\n]+$/, "", lit)
    nlit = (lit == "") ? 0 : split(lit, littok, /[ \t\n]+/)
    for (j = 1; j <= nlit; j++) inlit[littok[j]] = 1
    onlyfile = ""; onlylit = ""
    for (i = 1; i <= nreq; i++) if (!(filetok[i] in inlit)) onlyfile = onlyfile " " filetok[i]
    for (j = 1; j <= nlit; j++) if (!(littok[j] in infile)) onlylit = onlylit " " littok[j]

    # --- the citations -----------------------------------------------------------
    while ((getline line < suite) > 0) {
      s = line
      while (match(s, /#[0-9]+/)) {
        n = substr(s, RSTART + 1, RLENGTH - 1); s = substr(s, RSTART + RLENGTH)
        if (!(n in cited)) { cited[n] = 1; citedorder[++ncited] = n }
      }
    }
    close(suite)

    if (mode == "matrix") {
      ncovered = 0; nactive = 0; ngap = 0
      for (i = 1; i <= nreq; i++) {
        id = order[i]; kw = keyword(get(id, "status"))
        if (kw == "active") { nactive++; if (covered(id)) ncovered++ }
        if (kw == "gap") ngap++
      }
      printf "requirements matrix: %d requirements; %d active, %d of them covered; %d marked a gap; %d check results recorded\n", nreq, nactive, ncovered, ngap, nres
      for (i = 1; i <= nreq; i++) {
        id = order[i]; st = get(id, "status"); kw = keyword(st)
        if (kw == "active") mverdict = covered(id) ? "covered" : "NOT COVERED"
        else if (kw == "gap" && get(id, "seam") != "none" && covered(id)) mverdict = "not asked, though its tags now meet coverage"
        else mverdict = "not asked"
        extra = ""
        if ((id, "direction") in field) extra = extra ", " keyword(get(id, "direction"))
        if (get(id, "seam") == "none") extra = extra ", seam: none, verify: " get(id, "verify")
        printf "\n%s  %s  %s (%s%s)", id, st, mverdict, counts(id), extra
        printf "%s\n", checks[id]
      }
      exit
    }

    if (nreq == 0) emit("FAIL", "FR-45", "nothing was read out of requirements.md and requirements/, so every finding below is evidence of nothing")
    else emit("ok", "FR-45", "requirements.md and requirements/ hold " nreq " requirements and " ncrit " criteria")
    if (nproblem == 0) emit("ok", "FR-45", "every requirement entry is well formed")
    for (i = 1; i <= nproblem; i++) emit("FAIL", "FR-45", problem[i])
    if (nunknown == 0) emit("ok", "GH-104.2", "every tag names a requirement")
    for (i = 1; i <= nunknown; i++) emit("FAIL", "GH-104.2", "a check is tagged " unknownorder[i] ", which is not in requirements.md or requirements/: " unknown[unknownorder[i]])
    if (nres == 0) emit("FAIL", "GH-104.1", "no check result was recorded, so no tag was read")
    else if (nuntagged == 0 && nbaddir == 0) emit("ok", "GH-104.1", "every check carries a tag and a direction")
    for (i = 1; i <= nuntagged; i++) emit("FAIL", "GH-104.1", "a check carries no tag: " untagged[i])
    for (i = 1; i <= nbaddir; i++) emit("FAIL", "GH-104.1", "a check records a direction that is none of refuse, permit and static: " baddir[i])
    nuncovered = 0
    for (i = 1; i <= nreq; i++) {
      id = order[i]
      if (get(id, "status") != "active" || covered(id)) continue
      nuncovered++
      d = keyword(get(id, "direction"))
      emit("FAIL", "FR-46 FR-33", id " is active and not covered: " counts(id) (d == "" ? "" : ", declared " d))
    }
    if (nuncovered == 0) emit("ok", "FR-46 FR-33", "every active requirement is covered")
    if (onlyfile == "" && onlylit == "")
      emit("ok", "FR-45 FR-46", "requirements.md and requirements/ have the shape this suite holds: " nreq " entries by ID, " (noffrule + 0) " of them off the both-directions rule")
    else {
      shapemsg = "requirements.md and requirements/ have changed shape"
      if (onlyfile != "") shapemsg = shapemsg "; only it holds" onlyfile
      if (onlylit != "") shapemsg = shapemsg "; only this suite holds" onlylit
      emit("FAIL", "FR-45 FR-46", shapemsg)
    }
    if (nprov == 0) emit("ok", "FR-47", "every stage-ticket criterion is carried or dropped, and each ticket has all of its criteria")
    for (i = 1; i <= nprov; i++) emit("FAIL", "FR-47", provproblem[i])
    nbad = 0
    for (i = 1; i <= ncited; i++) {
      n = citedorder[i]
      if ((n in exempt) || (n in ghbase)) continue
      nbad++
      emit("FAIL", "GH-104.3", "the suite cites " H n ", which has no entry and no reason")
    }
    if (nbad == 0) emit("ok", "GH-104.3", "every issue the suite cites has an entry or a reason")
  }
AWK
)
# <requirements> is requirements.md, and the split set is read from beside it
# by requirements_split -- so every caller reads the union, and none can pass
# one half without the other.
requirements_read() {  # requirements_read <findings|matrix> <requirements> <ledger> <suite> <root> <runbook> <counts> <shape>
  REQ_SPLIT_LIST=$(requirements_split "$2") \
  REQ_SPLIT_OTHER=$(requirements_split_other "$2") \
  awk -v mode="$1" -v reqs="$2" -v ledger="$3" -v suite="$4" -v root="$5" \
      -v runbook="$6" -v counts_literal="$7" -v shape_literal="$8" \
      "$REQ_FIELD_AWK$REQUIREMENTS_AWK" </dev/null
}

echo "--- the findings, against a fixture whose every answer is written here ---"
# The fixture holds one requirement of each shape the rules distinguish: a story
# covered in both directions, a one-sided one, a static one whose only check
# failed (a failed check still covers; its failure is its own line above), one
# with no seam, a gap, a superseded one, and a GH sub-issue that is permit-only.
# `#` is spelled through H wherever a number follows it, because this suite's
# own citations are read by the same program and a fixture citation is not one.
H='#'
REQ_FIX="$FIXTURES/requirements-fixture"
mkdir -p "$REQ_FIX/clean/root/tests"
: > "$REQ_FIX/clean/root/tests/present.py"
cat > "$REQ_FIX/clean/requirements.md" <<REQS
# A fixture

## What covers a requirement

### not an entry, because this section holds none

## User stories

### US-1
- text: a story covered in both directions
- from: the fixture
- status: active

### US-2
- text: a story that is one-sided
- from: the fixture
- status: active
- direction: refuse-only: a reason

## Functional requirements

### FR-1
- text: a requirement about what a file says,
  continued on a second line
- from: the fixture
- status: active
- direction: static: a reason

### FR-2
- text: a requirement no check reaches
- from: the fixture
- status: active
- seam: none
- verify: tests/present.py

### FR-3
- text: a gap
- from: the fixture
- status: gap → ${H}7

### FR-4
- text: a requirement replaced by another
- from: the fixture
- status: superseded-by: FR-1

## Boundary issues

## Provenance: the fixture's criteria

### ${H}37.1
- criterion: a criterion
- maps: US-1, FR-1

### ${H}37.2
- criterion: another
- dropped: a reason

## Citations that are not requirements

- ${H}9: a reason
REQS
# The `GH-` entry is a file of its own beside it, as in the repository (#200).
mkdir -p "$REQ_FIX/clean/requirements"
cat > "$REQ_FIX/clean/requirements/GH-5.1.md" <<'REQS'
### GH-5.1
- text: a sub-issue that is permit-only
- from: the fixture
- kind: defect-permitting
- status: active
- direction: permit-only: a reason
REQS
printf '%s\t%s\t%s\t%s\n' \
  'US-1' refuse ok 'BLOCK one' \
  'US-1 GH-5.1' permit ok 'ALLOW two' \
  'US-2' refuse ok 'says three' \
  'FR-1' static FAIL 'tok four' > "$REQ_FIX/clean/ledger"
printf 'a suite citing %s5 and %s9\n' "$H" "$H" > "$REQ_FIX/clean/suite"
FIX_SHAPE='US-1 US-2:refuse-only FR-1:static FR-2:tests FR-3:gap FR-4:superseded-by GH-5.1:permit-only'
req_fixture() {  # req_fixture <dir> -- the findings for the fixture in <dir>
  requirements_read findings "$1/requirements.md" "$1/ledger" "$1/suite" \
    "$1/root" "$1/runbook.md" '37:2' "$FIX_SHAPE"
}
# A mutant is the clean fixture with one file edited, and the edit is asserted to
# have taken: a sed that matched nothing leaves the clean fixture, and every FAIL
# expected of it would be missing for that reason rather than the one it names.
req_mutant() {  # req_mutant <name> <file> <sed script> -- prints the mutant's directory
  local dir="$REQ_FIX/$1"
  cp -r "$REQ_FIX/clean" "$dir"
  sed -i -e "$3" "$dir/$2"
  if cmp -s "$REQ_FIX/clean/$2" "$dir/$2"; then
    echo "the requirements mutant $1 did not change $2; the checks against it prove nothing" >&2
    exit 1
  fi
}
TAB=$'\t'

req GH-104.1 GH-104.2 GH-104.3 FR-45 FR-46 FR-47 FR-33
tok 'the clean fixture: every finding holds, one line each' \
"ok${TAB}FR-45${TAB}requirements.md and requirements/ hold 7 requirements and 2 criteria
ok${TAB}FR-45${TAB}every requirement entry is well formed
ok${TAB}GH-104.2${TAB}every tag names a requirement
ok${TAB}GH-104.1${TAB}every check carries a tag and a direction
ok${TAB}FR-46 FR-33${TAB}every active requirement is covered
ok${TAB}FR-45 FR-46${TAB}requirements.md and requirements/ have the shape this suite holds: 7 entries by ID, 6 of them off the both-directions rule
ok${TAB}FR-47${TAB}every stage-ticket criterion is carried or dropped, and each ticket has all of its criteria
ok${TAB}GH-104.3${TAB}every issue the suite cites has an entry or a reason" \
  "$(req_fixture "$REQ_FIX/clean")"

# The four mutations #104 names, each one edit to one file of the fixture.
req FR-46 FR-33
req_mutant drop-a-tag ledger 's/^US-1 GH-5.1\t/GH-5.1\t/'
OUT=$(req_fixture "$REQ_FIX/drop-a-tag")
holds 'a tag dropped from the only permitting check leaves its requirement uncovered' "$OUT" \
  "FAIL${TAB}FR-46 FR-33${TAB}US-1 is active and not covered: 1 refusing, 0 permitting, 0 static"
lacks 'and the suite does not also say every requirement is covered' "$OUT" 'every active requirement is covered'
req GH-104.2
req_mutant unknown-tag ledger 's/^US-2\t/US-9\t/'
OUT=$(req_fixture "$REQ_FIX/unknown-tag")
holds 'a tag naming an ID not in the file fails, and names the check carrying it' "$OUT" \
  "FAIL${TAB}GH-104.2${TAB}a check is tagged US-9, which is not in requirements.md or requirements/: says three"
lacks 'and the suite does not also say every tag names a requirement' "$OUT" 'every tag names a requirement'
req FR-47
req_mutant delete-a-mapping requirements.md '/^- maps: US-1, FR-1$/d'
OUT=$(req_fixture "$REQ_FIX/delete-a-mapping")
holds 'a criterion whose mapping is deleted fails' "$OUT" \
  "FAIL${TAB}FR-47${TAB}${H}37.1 is neither mapped nor dropped"
lacks 'and the provenance is not called whole' "$OUT" 'every stage-ticket criterion is carried'
req GH-104.3
req_mutant cite-unknown suite "s/${H}9/${H}6/"
OUT=$(req_fixture "$REQ_FIX/cite-unknown")
holds 'a number the suite cites with no entry and no reason fails' "$OUT" \
  "FAIL${TAB}GH-104.3${TAB}the suite cites ${H}6, which has no entry and no reason"
lacks 'and the citations are not called answered' "$OUT" 'every issue the suite cites has an entry'

# The rest of what the file's rules say fails, one mutant each.
req GH-104.1
req_mutant untagged ledger 's/^FR-1\t/\t/'
OUT=$(req_fixture "$REQ_FIX/untagged")
holds 'a check with no tag fails, and is named' "$OUT" \
  "FAIL${TAB}GH-104.1${TAB}a check carries no tag: tok four"
lacks 'and the suite does not also say every check carries one' "$OUT" 'every check carries a tag'
printf '' > "$REQ_FIX/empty-ledger"
OUT=$(requirements_read findings "$REQ_FIX/clean/requirements.md" "$REQ_FIX/empty-ledger" \
        "$REQ_FIX/clean/suite" "$REQ_FIX/clean/root" "$REQ_FIX/clean/runbook.md" '37:2' "$FIX_SHAPE")
holds 'a ledger that recorded nothing fails, rather than having no untagged check in it' "$OUT" \
  "FAIL${TAB}GH-104.1${TAB}no check result was recorded, so no tag was read"
req FR-46 FR-33
req_mutant no-direction requirements.md '/^- direction: refuse-only: a reason$/d'
OUT=$(req_fixture "$REQ_FIX/no-direction")
holds 'a one-sided story that stops declaring it needs a permitting check' "$OUT" \
  "FAIL${TAB}FR-46 FR-33${TAB}US-2 is active and not covered: 1 refusing, 0 permitting, 0 static"
req_mutant permit-only-refused ledger 's/^US-1 GH-5.1\tpermit\t/US-1 GH-5.1\trefuse\t/'
OUT=$(req_fixture "$REQ_FIX/permit-only-refused")
holds 'a permit-only requirement is not covered by a refusing check' "$OUT" \
  "FAIL${TAB}FR-46 FR-33${TAB}GH-5.1 is active and not covered: 1 refusing, 0 permitting, 0 static, declared permit-only"
req_mutant static-unchecked ledger '/^FR-1\t/d'
OUT=$(req_fixture "$REQ_FIX/static-unchecked")
holds 'a static requirement with no check at all is not covered' "$OUT" \
  "FAIL${TAB}FR-46 FR-33${TAB}FR-1 is active and not covered: 0 refusing, 0 permitting, 0 static, declared static"
req_mutant gap-activated requirements.md "s/^- status: gap → ${H}7$/- status: active/"
OUT=$(req_fixture "$REQ_FIX/gap-activated")
holds 'a gap marked active is asked about like any other' "$OUT" \
  "FAIL${TAB}FR-46 FR-33${TAB}FR-3 is active and not covered: 0 refusing, 0 permitting, 0 static"
req FR-47
req_mutant map-unknown requirements.md 's/^- maps: US-1, FR-1$/- maps: US-1, FR-9/'
OUT=$(req_fixture "$REQ_FIX/map-unknown")
holds 'a mapping naming an ID not in the file fails' "$OUT" \
  "FAIL${TAB}FR-47${TAB}${H}37.1 maps to FR-9, which is not a requirement"
req_mutant criterion-deleted requirements.md "/^### ${H}37.2$/,/^- dropped: a reason$/d"
OUT=$(req_fixture "$REQ_FIX/criterion-deleted")
holds 'a criterion deleted whole fails on the count the issue has' "$OUT" \
  "FAIL${TAB}FR-47${TAB}${H}37 has 1 criteria here, where the issue has 2"
req FR-45
req_mutant used-twice requirements.md 's/^### US-2$/### US-1/'
OUT=$(req_fixture "$REQ_FIX/used-twice")
holds 'an ID used twice fails' "$OUT" "FAIL${TAB}FR-45${TAB}US-1: the ID is used twice"
req_mutant out-of-family requirements.md 's/^### FR-4$/### XR-4/'
OUT=$(req_fixture "$REQ_FIX/out-of-family")
holds 'a heading outside the three families fails' "$OUT" \
  "FAIL${TAB}FR-45${TAB}XR-4: not an ID of the US, FR or GH family"
req_mutant unknown-status requirements.md '0,/^- status: active$/s//- status: pending/'
OUT=$(req_fixture "$REQ_FIX/unknown-status")
holds 'a status the file does not define fails' "$OUT" \
  "FAIL${TAB}FR-45${TAB}US-1: the status pending is not one this file defines"
req_mutant superseded-unknown requirements.md 's/^- status: superseded-by: FR-1$/- status: superseded-by: FR-9/'
OUT=$(req_fixture "$REQ_FIX/superseded-unknown")
holds 'a supersession naming no entry fails' "$OUT" \
  "FAIL${TAB}FR-45${TAB}FR-4: superseded by FR-9, which is not a requirement"
req_mutant no-kind requirements/GH-5.1.md '/^- kind: defect-permitting$/d'
OUT=$(req_fixture "$REQ_FIX/no-kind")
holds 'a GH entry with no kind fails' "$OUT" "FAIL${TAB}FR-45${TAB}GH-5.1: the kind is missing"
req_mutant no-reason requirements.md 's/^- direction: static: a reason$/- direction: static:/'
OUT=$(req_fixture "$REQ_FIX/no-reason")
holds 'a direction declared with no reason fails' "$OUT" \
  "FAIL${TAB}FR-45${TAB}FR-1: the direction static gives no reason"
req_mutant verify-absent requirements.md 's|^- verify: tests/present.py$|- verify: tests/absent.py|'
OUT=$(req_fixture "$REQ_FIX/verify-absent")
holds 'a seam-less requirement verified by a test that is not there fails' "$OUT" \
  "FAIL${TAB}FR-45${TAB}FR-2: verify names tests/absent.py, which is not there"
req_mutant verify-runbook requirements.md 's|^- verify: tests/present.py$|- verify: runbook §1|'
OUT=$(req_fixture "$REQ_FIX/verify-runbook")
holds 'a runbook section with no runbook written fails' "$OUT" \
  "FAIL${TAB}FR-45${TAB}FR-2: verify names runbook §1, which is not written"
printf '## §1 the fork point\n' > "$REQ_FIX/verify-runbook/runbook.md"
OUT=$(req_fixture "$REQ_FIX/verify-runbook")
lacks 'and passes once the runbook has that section' "$OUT" 'verify names runbook'
# Found by review of #104, each with the suite green before it.
req_mutant renamed-heading requirements.md 's/^## Functional requirements$/## Functional requirements (hooks)/'
OUT=$(req_fixture "$REQ_FIX/renamed-heading")
holds 'a renamed family heading does not make its entries vanish' "$OUT" \
  "FAIL${TAB}FR-45${TAB}FR-1: an entry under the heading \"Functional requirements (hooks)\", where no entry is read"
req_mutant seam-with-checks ledger 's/^FR-1\tstatic\t/FR-1 FR-2\tstatic\t/'
OUT=$(req_fixture "$REQ_FIX/seam-with-checks")
holds 'a requirement no check can reach, with a check tagged with it, fails' "$OUT" \
  "FAIL${TAB}FR-45${TAB}FR-2: seam: none, and 0 refusing, 0 permitting, 1 static are tagged with it"
req_mutant verify-a-directory requirements.md 's|^- verify: tests/present.py$|- verify: tests/|'
OUT=$(req_fixture "$REQ_FIX/verify-a-directory")
holds 'a verify naming a directory is refused before it is read, which would abort the program' "$OUT" \
  "FAIL${TAB}FR-45${TAB}FR-2: verify is tests/, which is none of review, tests/<file>.py and runbook §<n>"
req GH-104.1
req_mutant misspelled-direction ledger 's/^US-2\trefuse\t/US-2\trefues\t/'
OUT=$(req_fixture "$REQ_FIX/misspelled-direction")
holds 'a check recording a direction that is not one fails' "$OUT" \
  "FAIL${TAB}GH-104.1${TAB}a check records a direction that is none of refuse, permit and static: refues: says three"
# Every route out of the coverage check changes the shape, one mutant each. The
# first two were closed after review of #104, the next four after Bertan's
# review of its pull request, and the last two after Bertan's re-review found
# them green against a literal of counts: a direction declared, and a gap marker
# moved from one entry to another.
req FR-45 FR-46
req_mutant gap-added requirements.md 's/^- status: superseded-by: FR-1$/- status: gap → '"${H}"'8/'
OUT=$(req_fixture "$REQ_FIX/gap-added")
holds 'an entry marked a gap changes the shape this suite holds' "$OUT" \
  "FAIL${TAB}FR-45 FR-46${TAB}requirements.md and requirements/ have changed shape; only it holds FR-4:gap; only this suite holds FR-4:superseded-by"
req_mutant review-added requirements.md 's|^- verify: tests/present.py$|- verify: review|'
OUT=$(req_fixture "$REQ_FIX/review-added")
holds 'and so does an entry moved to verification by review' "$OUT" \
  "FAIL${TAB}FR-45 FR-46${TAB}requirements.md and requirements/ have changed shape; only it holds FR-2:review; only this suite holds FR-2:tests"
req_mutant retired-marked requirements/GH-5.1.md '/^### GH-5.1$/,/^- direction:/s/^- status: active$/- status: retired: a reason/'
OUT=$(req_fixture "$REQ_FIX/retired-marked")
holds 'and an active entry marked retired' "$OUT" \
  "FAIL${TAB}FR-45 FR-46${TAB}requirements.md and requirements/ have changed shape; only it holds GH-5.1:retired,permit-only; only this suite holds GH-5.1:permit-only"
req_mutant drifted-marked requirements/GH-5.1.md '/^### GH-5.1$/,/^- direction:/s/^- status: active$/- status: drifted: some evidence/'
OUT=$(req_fixture "$REQ_FIX/drifted-marked")
holds 'and one marked drifted' "$OUT" \
  "FAIL${TAB}FR-45 FR-46${TAB}requirements.md and requirements/ have changed shape; only it holds GH-5.1:drifted,permit-only; only this suite holds GH-5.1:permit-only"
req_mutant tests-verified requirements.md 's/^- direction: refuse-only: a reason$/- seam: none\n- verify: tests\/present.py/'
OUT=$(req_fixture "$REQ_FIX/tests-verified")
holds 'and one moved to no seam, verified by a test file that is there' "$OUT" \
  "FAIL${TAB}FR-45 FR-46${TAB}requirements.md and requirements/ have changed shape; only it holds US-2:tests; only this suite holds US-2:refuse-only"
req_mutant entry-deleted requirements.md '/^### US-2$/,/^- direction: refuse-only: a reason$/d'
OUT=$(req_fixture "$REQ_FIX/entry-deleted")
holds 'and an entry deleted outright, which the header forbids' "$OUT" \
  "FAIL${TAB}FR-45 FR-46${TAB}requirements.md and requirements/ have changed shape; only this suite holds US-2:refuse-only"
# A story covered in both directions declares itself one-sided, which no count
# held: every entry's direction is its own.
req_mutant direction-added requirements.md '/^### US-1$/,/^### US-2$/s/^- status: active$/&\n- direction: permit-only: a reason/'
OUT=$(req_fixture "$REQ_FIX/direction-added")
tok 'a direction declared changes the shape, and that is the only finding' \
  "FAIL${TAB}FR-45 FR-46${TAB}requirements.md and requirements/ have changed shape; only it holds US-1:permit-only; only this suite holds US-1" \
  "$(grep "^FAIL" <<< "$OUT")"
# A gap whose tags meet coverage is made active, and its marker is put on an
# entry that is active: the count of every status stays where it was. The ledger
# is the one that meets FR-3's coverage, so the coverage check has nothing to
# say, and the shape alone is what turns it red.
req_mutant gap-swapped ledger 's/^US-1\trefuse\t/US-1 FR-3\trefuse\t/; s/^US-1 GH-5.1\tpermit\t/US-1 GH-5.1 FR-3\tpermit\t/'
sed -i -e "/^### FR-3\$/,/^### FR-4\$/s/^- status: gap → ${H}7\$/- status: active/" \
       -e "/^### US-1\$/,/^### US-2\$/s/^- status: active\$/- status: gap → ${H}7/" "$REQ_FIX/gap-swapped/requirements.md"
if cmp -s "$REQ_FIX/clean/requirements.md" "$REQ_FIX/gap-swapped/requirements.md"; then
  echo "the requirements mutant gap-swapped did not change requirements.md; the checks against it prove nothing" >&2
  exit 1
fi
OUT=$(req_fixture "$REQ_FIX/gap-swapped")
tok 'a gap marker moved from one entry to another changes the shape, and that is the only finding' \
  "FAIL${TAB}FR-45 FR-46${TAB}requirements.md and requirements/ have changed shape; only it holds US-1:gap FR-3; only this suite holds US-1 FR-3:gap" \
  "$(grep "^FAIL" <<< "$OUT")"
req FR-45
printf '' > "$REQ_FIX/empty-requirements.md"
OUT=$(requirements_read findings "$REQ_FIX/empty-requirements.md" "$REQ_FIX/clean/ledger" \
        "$REQ_FIX/clean/suite" "$REQ_FIX/clean/root" "$REQ_FIX/clean/runbook.md" '37:2' "$FIX_SHAPE")
holds 'a requirements file that holds nothing fails, rather than covering everything' "$OUT" \
  "FAIL${TAB}FR-45${TAB}nothing was read out of requirements.md and requirements/, so every finding below is evidence of nothing"

echo "--- the matrix, against the same fixture ---"
req GH-104.4
tok 'the matrix names each requirement, its status, its coverage and its checks' \
"requirements matrix: 7 requirements; 5 active, 5 of them covered; 1 marked a gap; 4 check results recorded

US-1  active  covered (1 refusing, 1 permitting, 0 static)
    ok   BLOCK one
    ok   ALLOW two

US-2  active  covered (1 refusing, 0 permitting, 0 static, refuse-only)
    ok   says three

FR-1  active  covered (0 refusing, 0 permitting, 1 static, static)
    FAIL tok four

FR-2  active  covered (0 refusing, 0 permitting, 0 static, seam: none, verify: tests/present.py)

FR-3  gap → ${H}7  not asked (0 refusing, 0 permitting, 0 static)

FR-4  superseded-by: FR-1  not asked (0 refusing, 0 permitting, 0 static)

GH-5.1  active  covered (0 refusing, 1 permitting, 0 static, permit-only)
    ok   ALLOW two" \
  "$(requirements_read matrix "$REQ_FIX/clean/requirements.md" "$REQ_FIX/clean/ledger" \
       "$REQ_FIX/clean/suite" "$REQ_FIX/clean/root" "$REQ_FIX/clean/runbook.md" '37:2' "$FIX_SHAPE")"

# A gap whose tags now meet coverage is not asked about, and the matrix says the
# tags meet it, so whoever owns the gap sees that the marker can come off.
req GH-104.4
req_mutant gap-covered ledger 's/^US-1\trefuse\t/US-1 FR-3\trefuse\t/; s/^US-1 GH-5.1\tpermit\t/US-1 GH-5.1 FR-3\tpermit\t/'
holds 'the matrix names a gap whose tags now meet coverage' \
  "$(requirements_read matrix "$REQ_FIX/gap-covered/requirements.md" "$REQ_FIX/gap-covered/ledger" \
       "$REQ_FIX/clean/suite" "$REQ_FIX/clean/root" "$REQ_FIX/clean/runbook.md" '37:2' "$FIX_SHAPE")" \
  "FR-3  gap → ${H}7  not asked, though its tags now meet coverage (1 refusing, 1 permitting, 0 static)"
# A gap no check can reach has no tags to meet anything with, and a first version
# of the line above said its tags met coverage all the same, because `seam: none`
# is covered by definition. Found reading this branch's own matrix.
req_mutant seam-gap requirements.md "s/^- status: active\$/&/; /^### FR-2\$/,/^- verify:/s/^- status: active\$/- status: gap → ${H}7/"
holds 'and does not say it of a gap no check can reach' \
  "$(requirements_read matrix "$REQ_FIX/seam-gap/requirements.md" "$REQ_FIX/clean/ledger" \
       "$REQ_FIX/clean/suite" "$REQ_FIX/clean/root" "$REQ_FIX/clean/runbook.md" '37:2' "$FIX_SHAPE")" \
  "FR-2  gap → ${H}7  not asked (0 refusing, 0 permitting, 0 static, seam: none, verify: tests/present.py)"

echo "--- #200: every GH- entry is a file of its own, beside requirements.md ---"
# The `GH-` entries were one section of requirements.md, appended to by every
# review loop, and every pair of concurrent branches conflicted on it -- six
# merges of six on 2026-09-20, none of them on code. Each is now a file under
# requirements/, named by its ID and holding that entry and nothing else, and
# requirements.md holds none. The readers above find the files through
# requirements_split, which is the one answer to which files and in what order.
#
# A mutant here is the clean fixture copied whole with its split set changed,
# and the change is asserted to have taken, for req_mutant's reason: a command
# that did nothing leaves the clean fixture, and every FAIL expected of it would
# be missing for that reason rather than the one it names.
req_split_changed() {  # req_split_changed <name> -- exits unless the mutant differs from the clean fixture
  if diff -r -q "$REQ_FIX/clean" "$REQ_FIX/$1" > /dev/null 2>&1; then
    echo "the requirements mutant $1 did not change the fixture; the checks against it prove nothing" >&2
    exit 1
  fi
}
# THE CHECK THAT FAILS WITHOUT THE SPLIT WORKING. A reader that does not find
# the split set reads every `GH-` entry as absent, and nothing about an absence
# is malformed -- so the finding that goes red is the shape, which is the literal
# and the pins that hold every entry by ID between them. In the repository that
# is every `GH-` entry dropping out of REQUIREMENT_SHAPE_HELD at once.
req FR-45 FR-46 GH-200.1 GH-200.2
cp -r "$REQ_FIX/clean" "$REQ_FIX/split-lost"
rm -r "$REQ_FIX/split-lost/requirements"
req_split_changed split-lost
OUT=$(req_fixture "$REQ_FIX/split-lost")
holds 'a split set that is not read loses its entries, and the shape says which' "$OUT" \
  "FAIL${TAB}FR-45 FR-46${TAB}requirements.md and requirements/ have changed shape; only this suite holds GH-5.1:permit-only"
# Each way a file breaks "one entry, named by its ID, and nothing else" is a
# finding of its own. #200's triage named the first three.
req FR-45 GH-200.1
cp -r "$REQ_FIX/clean" "$REQ_FIX/split-misnamed"
mv "$REQ_FIX/split-misnamed/requirements/GH-5.1.md" "$REQ_FIX/split-misnamed/requirements/GH-5.2.md"
req_split_changed split-misnamed
OUT=$(req_fixture "$REQ_FIX/split-misnamed")
holds 'a file whose name disagrees with the heading it holds fails' "$OUT" \
  "FAIL${TAB}FR-45${TAB}requirements/GH-5.2.md: holds GH-5.1, and a file is named by the ID it holds"
lacks 'and the entries are not called well formed' "$OUT" 'every requirement entry is well formed'
cp -r "$REQ_FIX/clean" "$REQ_FIX/split-two"
printf '\n### GH-5.2\n- text: a second entry\n- from: the fixture\n- kind: doc-claim\n- status: retired: a reason\n' \
  >> "$REQ_FIX/split-two/requirements/GH-5.1.md"
req_split_changed split-two
OUT=$(req_fixture "$REQ_FIX/split-two")
holds 'a file holding two entries fails' "$OUT" \
  "FAIL${TAB}FR-45${TAB}requirements/GH-5.1.md: holds a second entry, GH-5.2, where a file holds one"
lacks 'and the entries are not called well formed' "$OUT" 'every requirement entry is well formed'
# `GH-05` passes the family test open_entry makes, `^GH-[0-9]+`, so the grammar
# is the only thing that can refuse it -- and a file named for it agrees with its
# heading, so the name check says nothing either.
cp -r "$REQ_FIX/clean" "$REQ_FIX/split-grammar"
printf '### GH-05\n- text: an ID with a leading zero\n- from: the fixture\n- kind: doc-claim\n- status: retired: a reason\n' \
  > "$REQ_FIX/split-grammar/requirements/GH-05.md"
req_split_changed split-grammar
OUT=$(req_fixture "$REQ_FIX/split-grammar")
holds 'a file whose ID breaks the grammar fails' "$OUT" \
  "FAIL${TAB}FR-45${TAB}GH-05: not an ID of the grammar the split set holds, GH-<n> or GH-<n>.<m>"
lacks 'and the entries are not called well formed' "$OUT" 'every requirement entry is well formed'
# The rest of "nothing else", and the entry written the old way.
cp -r "$REQ_FIX/clean" "$REQ_FIX/split-preamble"
sed -i '1i a line before the heading' "$REQ_FIX/split-preamble/requirements/GH-5.1.md"
req_split_changed split-preamble
OUT=$(req_fixture "$REQ_FIX/split-preamble")
holds 'a file with text before its heading fails' "$OUT" \
  "FAIL${TAB}FR-45${TAB}requirements/GH-5.1.md: text before its heading, where a file holds one entry and nothing else"
cp -r "$REQ_FIX/clean" "$REQ_FIX/split-section"
printf '\n## A section\n' >> "$REQ_FIX/split-section/requirements/GH-5.1.md"
req_split_changed split-section
OUT=$(req_fixture "$REQ_FIX/split-section")
holds 'a file with a section heading in it fails' "$OUT" \
  "FAIL${TAB}FR-45${TAB}requirements/GH-5.1.md: a ## heading, where a file here holds one entry and nothing else"
# After the heading too: a line that is neither a field, nor the continuation
# of one, nor blank. In requirements.md such a line is prose between entries;
# in a file that holds one entry it can only be something that is not the entry.
cp -r "$REQ_FIX/clean" "$REQ_FIX/split-stray"
printf '\na paragraph that is no field\n' >> "$REQ_FIX/split-stray/requirements/GH-5.1.md"
req_split_changed split-stray
OUT=$(req_fixture "$REQ_FIX/split-stray")
holds 'a file with a line after its entry that is no field of it fails' "$OUT" \
  "FAIL${TAB}FR-45${TAB}requirements/GH-5.1.md: a line that is no field of its entry, where a file holds one entry and nothing else"
lacks 'and the entries are not called well formed' "$OUT" 'every requirement entry is well formed'
cp -r "$REQ_FIX/clean" "$REQ_FIX/split-empty"
: > "$REQ_FIX/split-empty/requirements/GH-6.md"
req_split_changed split-empty
OUT=$(req_fixture "$REQ_FIX/split-empty")
holds 'a file holding no entry fails' "$OUT" \
  "FAIL${TAB}FR-45${TAB}requirements/GH-6.md: holds no entry"
cp -r "$REQ_FIX/clean" "$REQ_FIX/split-appended"
sed -i '/^## Boundary issues$/r '"$REQ_FIX/clean/requirements/GH-5.1.md" "$REQ_FIX/split-appended/requirements.md"
rm "$REQ_FIX/split-appended/requirements/GH-5.1.md"
req_split_changed split-appended
OUT=$(req_fixture "$REQ_FIX/split-appended")
holds 'a GH- entry appended to requirements.md the old way fails, and says where it goes' "$OUT" \
  "FAIL${TAB}FR-45${TAB}GH-5.1: a GH- entry in requirements.md, where each is a file of its own under requirements/"
lacks 'and the entries are not called well formed' "$OUT" 'every requirement entry is well formed'
# EVERY NAME IN THE DIRECTORY IS READ, and these two are what tell the `*` in
# requirements_split from a narrower glob. Every misnamed fixture above is misnamed
# INSIDE `GH-*.md`, so with the glob narrowed to that the suite stayed green --
# and a misnamed file holding a retired entry was never read, a false green in
# the permitting direction (rev-agent-200, round 1 of PR #210). One name for each
# way out of the pattern: a prefix that is not `GH-`, and an extension that is
# not `.md`. The entry is retired, because an active one is counted as well by
# the harness, which lists the directory for itself and so caught the narrowed
# glob by accident, under a finding that was not this one.
req FR-45 GH-200.1 GH-200.2
for SPLIT_NAME in gh-5.3.md GH-5.3.txt; do
  cp -r "$REQ_FIX/clean" "$REQ_FIX/split-name-$SPLIT_NAME"
  printf '### GH-5.3\n- text: an entry under a name outside the pattern\n- from: the fixture\n- kind: doc-claim\n- status: retired: a reason\n' \
    > "$REQ_FIX/split-name-$SPLIT_NAME/requirements/$SPLIT_NAME"
  req_split_changed "split-name-$SPLIT_NAME"
  OUT=$(req_fixture "$REQ_FIX/split-name-$SPLIT_NAME")
  holds "a file named $SPLIT_NAME, outside GH-*.md, is read and found misnamed" "$OUT" \
    "FAIL${TAB}FR-45${TAB}requirements/$SPLIT_NAME: holds GH-5.3, and a file is named by the ID it holds"
done
# A NAME THAT IS NOT A REGULAR FILE is named, and never handed to awk: under
# mawk a directory in the list aborted the canonical reader, and the suite went
# red with no finding that named it (rev-agent-200, round 4 of PR #210).
req FR-45 GH-200.1 GH-200.2
cp -r "$REQ_FIX/clean" "$REQ_FIX/split-dir"
mkdir "$REQ_FIX/split-dir/requirements/old"
printf '### GH-5.9\n- text: an entry in a subdirectory\n- from: the fixture\n- kind: doc-claim\n- status: retired: a reason\n' \
  > "$REQ_FIX/split-dir/requirements/old/GH-5.9.md"
req_split_changed split-dir
OUT=$(req_fixture "$REQ_FIX/split-dir")
holds 'a directory among the split set is named, rather than aborting the reader' "$OUT" \
  "FAIL${TAB}FR-45${TAB}requirements/old: not a regular file, where each entry is a file of its own"
# And whatever globbing its caller left off. This file turns it off around its
# splits, and under `set -f` the directory's `*` is the one name `*`, which is no
# file -- so the split set would be read as empty, and every entry in it lost.
req GH-200.2
set -f
SPLIT_NOGLOB=$(requirements_split "$REQ_FIX/clean/requirements.md" | sed 's|.*/||')
set +f
tok 'the split set is listed with globbing off in the caller' 'GH-5.1.md' "$SPLIT_NOGLOB"
# WHERE A FILE ENDS, ITS ENTRY ENDS, in the two programs that read the union a
# line at a time rather than through `take`: the families' scope and the
# registry audit's status. Asked with a file that opens with something other
# than its heading, which is a FR-45 finding of its own -- so this is about what
# the rest of the suite says once it is red, and without it each program gives
# the entry before the fields of the file after. Each is asked a second
# question whose answer is not empty, so that a program that printed nothing
# for a reason of its own cannot pass for the one that ended the entry.
req GH-200.2
mkdir -p "$REQ_FIX/split-ends"
printf '### GH-5\n- kind: defect-permitting\n- status: active\n- variants: seed\n' > "$REQ_FIX/split-ends/GH-5.md"
printf '### GH-6\n- text: an entry with no status\n' > "$REQ_FIX/split-ends/GH-6.md"
printf -- '- variants: none: a line before its heading\n- status: active\n### GH-7\n- kind: doc-claim\n- status: retired: a reason\n' \
  > "$REQ_FIX/split-ends/GH-7.md"
tok "the families' scope ends an entry where its file ends" 'GH-5|in|seed|' \
  "$(awk "$REQ_FIELD_AWK$INV_VARIANTS_AWK" "$REQ_FIX/split-ends/GH-5.md" "$REQ_FIX/split-ends/GH-7.md")"
tok "and so does the registry audit's status" '[] [retired: a reason]' \
  "[$(awk -v h='### GH-6' "$MUT_STATUS_AWK" "$REQ_FIX/split-ends/GH-6.md" "$REQ_FIX/split-ends/GH-7.md")] [$(awk -v h='### GH-7' "$MUT_STATUS_AWK" "$REQ_FIX/split-ends/GH-6.md" "$REQ_FIX/split-ends/GH-7.md")]"
# THE HARNESS LISTS THE DIRECTORY FOR ITSELF, because it cannot source this
# file, and says it reads every name there as this file does. Asked of a copy of
# it in a fixture directory, where `--list` counts what is beside it: one active
# entry in requirements.md, and one under each of three names in requirements/,
# two of them outside `GH-*.md`. The harness only needs a check-hooks.sh beside
# it to be readable, and runs none of it for `--list`.
req GH-148 GH-200.2
HARNESS_FIX="$FIXTURES/harness-split"
mkdir -p "$HARNESS_FIX/requirements"
cp "$SUITE_DIR/mutate-hooks.sh" "$HARNESS_FIX/mutate-hooks.sh"
: > "$HARNESS_FIX/check-hooks.sh"
printf '# A fixture\n\n## Functional requirements\n\n### FR-1\n- status: active\n\n## Boundary issues\n' \
  > "$HARNESS_FIX/requirements.md"
printf '### GH-5\n- status: active\n' > "$HARNESS_FIX/requirements/GH-5.md"
printf '### GH-6\n- status: active\n' > "$HARNESS_FIX/requirements/gh-6.md"
printf '### GH-7\n- status: active\n' > "$HARNESS_FIX/requirements/GH-7.txt"
# And a directory, which mawk aborts on if it is handed one: the count is still
# the four, not a refusal to count.
mkdir "$HARNESS_FIX/requirements/old"
printf '### GH-9\n- status: active\n' > "$HARNESS_FIX/requirements/old/GH-9.md"
tok 'the harness counts an active entry beside it under any name' \
  '4 requirements in requirements.md and requirements/ are active, which is what a row may name' \
  "$(bash "$HARNESS_FIX/mutate-hooks.sh" --list 2>&1 | grep 'are active')"

# THE ORDER IS VERSION ORDER ON THE ID, asked of names whose byte order and
# whose creation order are both different from it: byte order puts GH-10 first
# and GH-5.10 before GH-5.2, and the files are written in neither order. The
# expected sequence is written out, not computed with the `sort -V` the function
# uses.
req GH-200.3
cp -r "$REQ_FIX/clean" "$REQ_FIX/split-order"
for SPLIT_ID in GH-10 GH-5.10 GH-9 GH-5 GH-5.2; do
  printf '### %s\n- text: an entry whose place is asked\n- from: the fixture\n- kind: doc-claim\n- status: retired: a reason\n' \
    "$SPLIT_ID" > "$REQ_FIX/split-order/requirements/$SPLIT_ID.md"
done
tok 'the split set is listed in version order on the ID' \
  'GH-5.md GH-5.1.md GH-5.2.md GH-5.10.md GH-9.md GH-10.md' \
  "$(requirements_split "$REQ_FIX/split-order/requirements.md" | sed 's|.*/||' | paste -sd ' ')"
tok 'and the matrix presents the entries in that order' \
  'GH-5 GH-5.1 GH-5.2 GH-5.10 GH-9 GH-10' \
  "$(requirements_read matrix "$REQ_FIX/split-order/requirements.md" "$REQ_FIX/clean/ledger" \
       "$REQ_FIX/clean/suite" "$REQ_FIX/clean/root" "$REQ_FIX/clean/runbook.md" '37:2' "$FIX_SHAPE" \
     | awk '/^GH-/ { print $1 }' | paste -sd ' ')"
# And of this repository, where the order the entries used to have was the order
# they were appended in. The only derivation here is `sort -V`, which is the
# order #200 states, over the IDs the matrix printed -- so what goes red is the
# matrix disagreeing with the statement, whatever the function does.
REPO_GH_ORDER=$(requirements_read matrix "$HOOKS/requirements.md" "$REQ_FIX/empty-ledger" \
                  "$SUITE_TEXT" "$REPO_ROOT" "$HOOKS/runbook.md" \
                  "$PROVENANCE_COUNTS" "$REQUIREMENT_SHAPE_HELD" | awk '/^GH-/ { print $1 }')
if [ -z "$REPO_GH_ORDER" ]; then
  fail static 'the matrix of this repository printed no GH- entry, so its order says nothing'
else
  tok "this repository's matrix presents every GH- entry in version order" \
    "$(printf '%s\n' "$REPO_GH_ORDER" | LC_ALL=C sort -V)" "$REPO_GH_ORDER"
fi

# THE SPLIT ROUND-TRIPS: every entry #200 moved is in the split set, byte for
# byte, with a checksum and a length each taken off requirements.md as it stood
# before the
# split (4e91496), not off the files -- so the literal is evidence about the move
# and not a copy of what it checks. Checked by the suite rather than asserted in
# a pull request, which is #200's own acceptance criterion.
#
# THE TRADE, taken knowingly. The literal holds these entries still, so an edit
# to one of them -- a gap marker taken off when its issue lands, a note amended
# -- turns this red, and moving its token is part of that edit. That is #200's
# second design point, that a ledger entry is immutable once written and a
# correction is a new entry that supersedes it, held to these 117 and to no
# entry written after them. The cost is one token in check-hooks.sh per such edit,
# and the benefit is that an entry changed by accident -- a merge that resolved
# a conflict inside one, a script that rewrote one -- cannot pass as unchanged.
req GH-200.4
# SPLIT_MOVED is set in check-hooks.sh, which split-requirements.sh reads it
# out of by name; see there.
# Each token that the split set beside <dir> does not bear out, as ` ID:absent`
# or ` ID:changed(now ID:<cksum>:<length>)`. A changed entry says the token it
# has now, so that the red says how to move it (rev-agent-200, round 4 of PR
# #210); whether the change was meant is the reviewer's to say, not this line's.
# A function so that a fixture can ask it that, which a loop over this
# repository's own entries -- none of them changed -- never could.
split_moved_bad() {  # split_moved_bad <requirements dir> <literal>
  local tok id now bad=
  set -f
  for tok in $2; do
    id=${tok%%:*}
    if [ ! -f "$1/$id.md" ]; then
      bad="$bad $id:absent"
    else
      now=$(cksum < "$1/$id.md" | awk '{ print $1 ":" $2 }')
      [ "$now" = "${tok#*:}" ] || bad="$bad $id:changed(now $id:$now)"
    fi
  done
  set +f
  printf '%s' "$bad"
}
set -f
SPLIT_MOVED_N=$(printf '%s ' $SPLIT_MOVED | wc -w | tr -d ' ')
set +f
SPLIT_MOVED_BAD=$(split_moved_bad "$HOOKS/requirements" "$SPLIT_MOVED")
tok 'a token the split set does not bear out is named, with the one the file bears now' \
  ' GH-5.1:changed(now GH-5.1:2666001811:149) GH-6:absent' \
  "$(split_moved_bad "$REQ_FIX/clean/requirements" 'GH-5.1:1:1 GH-6:1:1')"
# 117 is the number of `### GH-` headings requirements.md held at 4e91496,
# counted there when the literal was written; nothing in a shallow checkout can
# count it again, so this holds the literal to that measurement and no more.
tok 'the literal holds as many entries as requirements.md held before the split, measured at 4e91496' '117' "$SPLIT_MOVED_N"
tok 'and each is in the split set with the checksum and length it had there (an entry named here is absent or changed)' \
  '' "$SPLIT_MOVED_BAD"

# split-requirements.sh, AGAINST A FIXTURE. It is what the pull requests open
# across the split will run once they merge the dev branch that carries it, so
# it is asked what they need: that it moves every entry byte for byte and
# leaves the rest of the file as it was, that a second run moves nothing, and
# that it refuses -- writing nothing at all -- a file already there holding
# something else, an ID outside the grammar, an ID written twice, whatever the
# reader would refuse in a file it wrote, and a `GH-` heading where the reader
# reads none; and that on the merge that brings the split it compares each
# entry three ways. Its output is read with a `|`
# after it, because `$( )` drops trailing newlines and a file's last byte is
# part of what is asked.
req GH-200.5
SPLIT_FIX="$FIXTURES/split-requirements"
mkdir -p "$SPLIT_FIX/before"
cat > "$SPLIT_FIX/before/requirements.md" <<'REQS'
# A fixture

## Functional requirements

### FR-1
- text: an entry that stays
- from: the fixture
- status: active

## Boundary issues

### GH-5.1
- text: a sub-entry, written first
- from: the fixture
- kind: doc-claim
- status: active

### GH-5
- text: a bare entry,
  continued on a second line
- from: the fixture
- kind: doc-claim
- status: active

## Provenance: the fixture's criteria
REQS
cp -r "$SPLIT_FIX/before" "$SPLIT_FIX/moved"
SPLIT_OUT=$(bash "$HOOKS/split-requirements.sh" "$SPLIT_FIX/moved" 2>&1; printf 'exit %s' "$?")
tok 'split-requirements.sh moves every GH- entry and says which, and which files it wrote' \
  'taken out of requirements.md: GH-5.1 GH-5
files written to requirements/: GH-5.1 GH-5
exit 0' "$SPLIT_OUT"
tok 'each entry is a file of its own, byte for byte' \
  '### GH-5
- text: a bare entry,
  continued on a second line
- from: the fixture
- kind: doc-claim
- status: active
|' "$(cat "$SPLIT_FIX/moved/requirements/GH-5.md"; printf '|')"
tok 'and requirements.md keeps everything else, and one blank line between sections' \
  '# A fixture

## Functional requirements

### FR-1
- text: an entry that stays
- from: the fixture
- status: active

## Boundary issues

## Provenance: the fixture'"'"'s criteria
|' "$(cat "$SPLIT_FIX/moved/requirements.md"; printf '|')"
tok 'and it wrote the two files it named and nothing else' 'GH-5.1.md GH-5.md' \
  "$(ls "$SPLIT_FIX/moved/requirements" | LC_ALL=C sort | paste -sd ' ')"
cp -r "$SPLIT_FIX/moved" "$SPLIT_FIX/again"
tok 'a second run moves nothing, and does not claim a committed merge has nothing to carry' \
  'requirements.md holds no GH- entry; nothing to move
(a merge of the split finished before the last commit, or a rebase, is compared three ways with --base <where the branch forked> --branch <the branch as it was before>)
exit 0' "$(bash "$HOOKS/split-requirements.sh" "$SPLIT_FIX/again" 2>&1; printf 'exit %s' "$?")"
if diff -r -q "$SPLIT_FIX/moved" "$SPLIT_FIX/again" > /dev/null 2>&1; then
  pass static 'and changes nothing'
else
  fail static 'and changes nothing: a second run changed %s' "$SPLIT_FIX/again"
fi
cp -r "$SPLIT_FIX/before" "$SPLIT_FIX/conflict"
mkdir "$SPLIT_FIX/conflict/requirements"
printf '### GH-5\n- text: another loop wrote this ID first\n' > "$SPLIT_FIX/conflict/requirements/GH-5.md"
tok 'a file already there holding something else is refused' \
  'split-requirements.sh: refused, and nothing was moved:
  GH-5: requirements/GH-5.md is there already and holds something else. Two loops wrote this ID, or a merge or rebase of the split finished earlier, which --base and --branch compare three ways; once the file is the right one, run this again with --resolved GH-5
exit 1' "$(bash "$HOOKS/split-requirements.sh" "$SPLIT_FIX/conflict" 2>&1; printf 'exit %s' "$?")"
tok 'and nothing is written: requirements.md is as it was, and the other entry was not moved' \
  'GH-5.md' "$(ls "$SPLIT_FIX/conflict/requirements" | paste -sd ' ')$(cmp -s "$SPLIT_FIX/before/requirements.md" "$SPLIT_FIX/conflict/requirements.md" || printf ' requirements.md changed')"
# And the remedy it gives is one a second run accepts: the file named with
# --resolved is left as it is, and the rest moves.
cp -r "$SPLIT_FIX/conflict" "$SPLIT_FIX/conflict-resolved"
tok 'and named with --resolved, a second run accepts it and leaves that file' \
  'taken out of requirements.md: GH-5.1 GH-5
files written to requirements/: GH-5.1
resolved by hand, and left as it was: GH-5
exit 0 - text: another loop wrote this ID first' \
  "$(bash "$HOOKS/split-requirements.sh" --resolved GH-5 "$SPLIT_FIX/conflict-resolved" 2>&1; printf 'exit %s ' "$?"; sed -n 2p "$SPLIT_FIX/conflict-resolved/requirements/GH-5.md")"
cp -r "$SPLIT_FIX/before" "$SPLIT_FIX/grammar"
sed -i 's/^### GH-5$/### GH-05/' "$SPLIT_FIX/grammar/requirements.md"
tok 'an ID outside the grammar is refused' \
  'split-requirements.sh: refused, and nothing was moved:
  GH-05: not an ID of the GH family grammar, ^GH-[1-9][0-9]*(\.[1-9][0-9]*)?$
exit 1' "$(bash "$HOOKS/split-requirements.sh" "$SPLIT_FIX/grammar" 2>&1; printf 'exit %s' "$?")"
tok 'and nothing is written' 'no requirements/' \
  "$([ -e "$SPLIT_FIX/grammar/requirements" ] && printf 'requirements/ written' || printf 'no requirements/')"
cp -r "$SPLIT_FIX/before" "$SPLIT_FIX/twice"
sed -i 's/^### GH-5$/### GH-5.1/' "$SPLIT_FIX/twice/requirements.md"
tok 'an ID written twice is refused' \
  'split-requirements.sh: refused, and nothing was moved:
  GH-5.1: the ID is used twice
exit 1' "$(bash "$HOOKS/split-requirements.sh" "$SPLIT_FIX/twice" 2>&1; printf 'exit %s' "$?")"
tok 'and nothing is written' 'no requirements/' \
  "$([ -e "$SPLIT_FIX/twice/requirements" ] && printf 'requirements/ written' || printf 'no requirements/')"
# The pull requests across the split hold files already: an entry whose file is
# there with the same bytes is not a conflict, and is left alone.
cp -r "$SPLIT_FIX/before" "$SPLIT_FIX/half"
mkdir "$SPLIT_FIX/half/requirements"
cp "$SPLIT_FIX/moved/requirements/GH-5.md" "$SPLIT_FIX/half/requirements/GH-5.md"
tok 'an entry whose file already holds exactly it is no conflict, and is said apart from the file written' \
  'taken out of requirements.md: GH-5.1 GH-5
files written to requirements/: GH-5.1
already in requirements/ with the same bytes, and left as it was: GH-5
exit 0' "$(bash "$HOOKS/split-requirements.sh" "$SPLIT_FIX/half" 2>&1; printf 'exit %s' "$?")"
if diff -r -q "$SPLIT_FIX/moved" "$SPLIT_FIX/half" > /dev/null 2>&1; then
  pass static 'and the result is the one a first run gives'
else
  fail static 'and the result is the one a first run gives: %s differs from %s' "$SPLIT_FIX/half" "$SPLIT_FIX/moved"
fi
# WHAT THE READER WOULD REFUSE IN A FILE THIS WRITES, it refuses before writing
# one (rev-agent-200, round 1 of PR #210). The first two are what the pull
# requests across the split meet: a merge that appends an entry directly under
# `## Boundary issues` leaves the pointer paragraph inside the entry's block, and
# a script that moved it would have taken the paragraph out of requirements.md
# into the entry's file, where the reader goes red on the entry and the repair
# that turns it green deletes the paragraph. The paragraph here stands after the
# last entry, as the pointer does after an entry appended above it.
cp -r "$SPLIT_FIX/before" "$SPLIT_FIX/prose"
sed -i '24a A paragraph after the entries, which is no field of either.' "$SPLIT_FIX/prose/requirements.md"
tok 'a line inside an entry that is no field of it is refused, and says where it is' \
  'split-requirements.sh: refused, and nothing was moved:
  line 25: GH-5: a line that is no field of the entry, which would be moved into requirements/GH-5.md with it; take the line out of every entry: put the GH- entries of this section below it, or it above the first of them: A paragraph after the entries, which is no field of either.
exit 1' "$(bash "$HOOKS/split-requirements.sh" "$SPLIT_FIX/prose" 2>&1; printf 'exit %s' "$?")"
tok 'and nothing is written' 'no requirements/' \
  "$([ -e "$SPLIT_FIX/prose/requirements" ] && printf 'requirements/ written' || printf 'no requirements/')"
# A continuation continues a field, so one straight after the heading continues
# nothing -- the reader's `lastkey`, which the script's `field` mirrors.
cp -r "$SPLIT_FIX/before" "$SPLIT_FIX/orphan"
sed -i 's/^### GH-5\.1$/&\n  a continuation of no field/' "$SPLIT_FIX/orphan/requirements.md"
tok 'a continuation with no field before it is refused' \
  'split-requirements.sh: refused, and nothing was moved:
  line 13: GH-5.1: a line that is no field of the entry, which would be moved into requirements/GH-5.1.md with it; take the line out of every entry: put the GH- entries of this section below it, or it above the first of them:   a continuation of no field
exit 1' "$(bash "$HOOKS/split-requirements.sh" "$SPLIT_FIX/orphan" 2>&1; printf 'exit %s' "$?")"
# The heading is the whole of it, trimmed, as the reader reads it; the script
# named the file from the first word, so `### GH-5 (reopened)` was written to
# GH-5.md and the reader then found the file misnamed and outside the grammar.
cp -r "$SPLIT_FIX/before" "$SPLIT_FIX/heading"
sed -i 's/^### GH-5$/### GH-5 (reopened)/' "$SPLIT_FIX/heading/requirements.md"
tok 'a heading that is more than its ID is refused' \
  'split-requirements.sh: refused, and nothing was moved:
  line 18: GH-5 (reopened): a heading is its ID and nothing else, and the file would be named GH-5.md
exit 1' "$(bash "$HOOKS/split-requirements.sh" "$SPLIT_FIX/heading" 2>&1; printf 'exit %s' "$?")"
tok 'and nothing is written' 'no requirements/' \
  "$([ -e "$SPLIT_FIX/heading/requirements" ] && printf 'requirements/ written' || printf 'no requirements/')"
# A `GH-` HEADING OUTSIDE THE THREE REQUIREMENT SECTIONS is refused, and says
# where it stands. The script had no answer for it: it was passed over, and the
# run said "requirements.md holds no GH- entry; nothing to move" of a file that
# held one, while the reader went red with a finding that did not say where the
# entry belongs (rev-agent-200, round 2 of PR #210). `## Provenance` is the
# heading after `## Boundary issues`, which is where a merge resolved by hand
# lands; before the first `##` is the one place with no heading at all, and the
# two are the script's two ways of not being in one.
cp -r "$SPLIT_FIX/before" "$SPLIT_FIX/provenance"
printf '\n### GH-6\n- text: an entry under the provenance\n- from: the fixture\n- kind: doc-claim\n- status: active\n' \
  >> "$SPLIT_FIX/provenance/requirements.md"
tok 'a GH- entry under a heading that holds no requirement is refused, and says which' \
  "split-requirements.sh: refused, and nothing was moved:
  line 27: GH-6: a GH- entry under \"## Provenance: the fixture's criteria\", where the reader reads none; move it to the end of ## Boundary issues and run this again
exit 1" "$(bash "$HOOKS/split-requirements.sh" "$SPLIT_FIX/provenance" 2>&1; printf 'exit %s' "$?")"
tok 'and nothing is written' 'no requirements/' \
  "$([ -e "$SPLIT_FIX/provenance/requirements" ] && printf 'requirements/ written' || printf 'no requirements/')"
cp -r "$SPLIT_FIX/before" "$SPLIT_FIX/first"
sed -i '1a ### GH-6' "$SPLIT_FIX/first/requirements.md"
tok 'and so is one before the first ## heading' \
  'split-requirements.sh: refused, and nothing was moved:
  line 2: GH-6: a GH- entry before the first ## heading, where the reader reads none; move it to the end of ## Boundary issues and run this again
exit 1' "$(bash "$HOOKS/split-requirements.sh" "$SPLIT_FIX/first" 2>&1; printf 'exit %s' "$?")"
# THE ONE EXCEPTION TO BYTE FOR BYTE, taken knowingly and pinned: awk ends every
# line it prints with a newline, so a last line that had none gains one. Here
# the file ends inside GH-5, with no newline, and GH-5.md comes out as it does
# from the fixture that has one.
mkdir "$SPLIT_FIX/no-newline"
printf '%s' "$(head -n 23 "$SPLIT_FIX/before/requirements.md")" > "$SPLIT_FIX/no-newline/requirements.md"
# That the fixture ends with no newline is what makes the check below one, and
# it is asked the way req_split_changed asks it of a mutant -- by stopping the
# run -- rather than as a check of its own: a fixture built wrong is no
# evidence about the script, and a result tagged GH-200.5 would have covered
# the requirement with a question about the fixture (rev-agent-200's round 2 of
# PR #210 named that class, and this was its instance in the round-1 delta).
if [ "$(tail -c 1 "$SPLIT_FIX/no-newline/requirements.md" | wc -l | tr -d ' ')" != 0 ]; then
  echo "the no-newline fixture ends with a newline; the check against it proves nothing" >&2
  exit 1
fi
bash "$HOOKS/split-requirements.sh" "$SPLIT_FIX/no-newline" > /dev/null 2>&1
if cmp -s "$SPLIT_FIX/moved/requirements/GH-5.md" "$SPLIT_FIX/no-newline/requirements/GH-5.md"; then
  pass static 'a last line with no newline gains one in the file it is moved to'
else
  fail static 'a last line with no newline gains one in the file it is moved to: %s is not %s' \
    "$SPLIT_FIX/no-newline/requirements/GH-5.md" "$SPLIT_FIX/moved/requirements/GH-5.md"
fi

# THREE WAYS, ON THE MERGE THAT BRINGS THE SPLIT (rev-agent-200, round 4 of PR
# #210). That merge is a content conflict on requirements.md, and a two-way run
# could not tell a branch's edit from its stale copy: keeping the dev side lost
# the edit with "nothing to move", exit 0, and keeping the branch side refused
# the stale copies alongside the edits. Measured on #158 and #184. The fixture
# is that merge in small: a base with three entries; a branch that edits GH-5
# and appends GH-8 and a line outside the entries; a dev side that splits,
# edits GH-6, keeps a pointer
# paragraph under `## Boundary issues`, and carries a check-hooks.sh holding
# GH-5's token. Its tokens are cksum and length of the base's GH-5 block, of
# the branch's, and of the dev side's amendment, written here as measured.
S3="$SPLIT_FIX/three"
G3="git -C $S3/repo -c user.email=checks@example.invalid -c user.name=checks"
git init -q -b dev "$S3/repo"
cat > "$S3/repo/requirements.md" <<'REQS'
# A fixture

## Boundary issues

### GH-5
- text: an entry the branch edits
- from: the fixture
- kind: doc-claim
- status: active

### GH-6
- text: an entry the dev side edits
- from: the fixture
- kind: doc-claim
- status: active

### GH-7
- text: an entry nobody edits
- from: the fixture
- kind: doc-claim
- status: active

## Provenance: the fixture's criteria
REQS
$G3 add -A && $G3 commit -qm base
$G3 checkout -q -b feature
sed -i 's/^- text: an entry the branch edits$/- text: an entry the branch edited/' "$S3/repo/requirements.md"
sed -i 's/^## Provenance: /### GH-8\n- text: an entry the branch appends\n- from: the fixture\n- kind: doc-claim\n- status: active\n\n&/' \
  "$S3/repo/requirements.md"
sed -i 's/^## Provenance: .*$/&\n- a criterion the branch adds, outside the entries/' "$S3/repo/requirements.md"
$G3 commit -qam branch
$G3 checkout -q dev
cp "$HOOKS/split-requirements.sh" "$S3/repo/split-requirements.sh"
bash "$S3/repo/split-requirements.sh" "$S3/repo" > /dev/null 2>&1
sed -i 's/^- text: an entry the dev side edits$/- text: an entry the dev side edited/' "$S3/repo/requirements/GH-6.md"
sed -i 's/^## Boundary issues$/&\n\nA pointer paragraph, as the dev side keeps one./' "$S3/repo/requirements.md"
printf "SPLIT_MOVED='\nGH-5:3493104077:98 GH-6:1:1\n'\n" > "$S3/repo/check-hooks.sh"
$G3 add -A && $G3 commit -qm split
# Before the merge, for the ways of bringing the split that are not one.
cp -a "$S3/repo" "$S3/pre"
$G3 checkout -q feature
$G3 merge -q --no-edit dev > /dev/null 2>&1
S3_BASE=$($G3 rev-parse --short "$($G3 merge-base HEAD MERGE_HEAD)")
S3_HEAD=$($G3 rev-parse --short HEAD)
# Each run below is on a copy of this merge, stopped where it conflicted, and
# each copy is asserted to be one: a merge that did not conflict would leave
# nothing to resolve, and every check would be about something else.
if [ "$($G3 status --porcelain requirements.md)" != 'UU requirements.md' ]; then
  echo "the three-way fixture's merge did not conflict on requirements.md; the checks against it prove nothing" >&2
  exit 1
fi
S3_WANT="a merge is in progress: each GH- entry is compared three ways, against the merge base $S3_BASE and HEAD at $S3_HEAD
files written to requirements/: GH-5 GH-8
GH-5: changed on HEAD only since the base, so its SPLIT_MOVED token in check-hooks.sh moves from GH-5:3493104077:98 to GH-5:1218492981:99
changed on the dev side only since the base, and left as it was: GH-6
unchanged on both sides since the base, and left as it was: 1
requirements.md lacks lines HEAD added outside the GH- entries since the base, lines missing: 1 -- a side the merge kept whole drops the other side's changes there, and git diff $S3_BASE HEAD -- requirements.md says which
exit 0"
S3_FIRST=${S3_WANT%%$'\n'*}
# The dev side kept whole drops the branch's line outside the entries, and the
# branch side kept whole drops the dev side's pointer paragraph: each is said,
# as the lines that side added since the base and the file now lacks. Not as
# "differs from the dev side", which the right resolution does too whenever the
# branch added a line there (rev-agent-200, round 6 of PR #210).
S3_LACKS="requirements.md lacks lines HEAD added outside the GH- entries since the base, lines missing: 1 -- a side the merge kept whole drops the other side's changes there, and git diff $S3_BASE HEAD -- requirements.md says which"
S3_DIFFERS="requirements.md lacks lines MERGE_HEAD added outside the GH- entries since the base, lines missing: 1 -- a side the merge kept whole drops the other side's changes there, and git diff $S3_BASE MERGE_HEAD -- requirements.md says which"
# Unmerged: refused before anything is read, and not as a stray line at the
# conflict markers, whose remedy -- move entries around them -- is wrong here.
cp -a "$S3/repo" "$S3/unmerged"
tok 'an unmerged requirements.md is refused, with a remedy that is about the merge' \
  'split-requirements.sh: requirements.md is unmerged. Resolve it first, hunk by hunk: the GH- entries are read out of git, so either side of those will do, but keep the dev side'"'"'s pointer paragraph and whatever else either side changed outside them; then run this again; nothing was moved
exit 1' "$(bash "$S3/unmerged/split-requirements.sh" 2>&1; printf 'exit %s' "$?")"
# The dev side kept: the resolution a one-line side against a whole section
# invites, and the one that lost the branch's edit in silence.
cp -a "$S3/repo" "$S3/theirs"
git -C "$S3/theirs" checkout -q --theirs requirements.md
git -C "$S3/theirs" add requirements.md
# Copied before any run here, so that each starts from the resolved merge.
cp -a "$S3/theirs" "$S3/theirs-dir"
cp -a "$S3/theirs" "$S3/theirs-notoken"
cp -a "$S3/theirs" "$S3/both"
tok 'with the dev side of requirements.md kept, the branch edit is still found, in git, and written' \
  "$S3_WANT" "$(bash "$S3/theirs/split-requirements.sh" 2>&1; printf 'exit %s' "$?")"
tok 'the branch edit is what GH-5 now holds, and the dev edit what GH-6 does' \
  '- text: an entry the branch edited|- text: an entry the dev side edited' \
  "$(sed -n 2p "$S3/theirs/requirements/GH-5.md")|$(sed -n 2p "$S3/theirs/requirements/GH-6.md")"
# The same with the directory given, which the usage line allows, and which a
# first version ran two ways -- "nothing to move", exit 0, the edit lost
# (rev-agent-200, round 5 of PR #210).
tok 'and with the directory given, the same' \
  "$S3_WANT" "$(bash "$S3/theirs-dir/split-requirements.sh" "$S3/theirs-dir" 2>&1; printf 'exit %s' "$?")"
# The old token is read from the dev side in git, not from the working tree's
# check-hooks.sh, which the real merges leave conflicted.
rm "$S3/theirs-notoken/check-hooks.sh"
tok 'and the token it moves from is read from the dev side in git' \
  "$S3_WANT" "$(bash "$S3/theirs-notoken/split-requirements.sh" 2>&1; printf 'exit %s' "$?")"
# The branch side kept whole: the same entries, its copies taken out -- and the
# dev side's pointer paragraph gone with the rest of that side, which the run
# says, because the entries are the only part of the file read out of git.
cp -a "$S3/repo" "$S3/ours"
git -C "$S3/ours" checkout -q --ours requirements.md
git -C "$S3/ours" add requirements.md
cp -a "$S3/ours" "$S3/edited"
tok 'with the branch side kept whole, the same entries, and a warning about the rest of the file' \
  "$S3_FIRST
taken out of requirements.md: GH-5 GH-6 GH-7 GH-8
files written to requirements/: GH-5 GH-8
GH-5: changed on HEAD only since the base, so its SPLIT_MOVED token in check-hooks.sh moves from GH-5:3493104077:98 to GH-5:1218492981:99
changed on the dev side only since the base, and left as it was: GH-6
unchanged on both sides since the base, and left as it was: 1
$S3_DIFFERS
exit 0" \
  "$(bash "$S3/ours/split-requirements.sh" 2>&1; printf 'exit %s' "$?")"
# Changed on both sides since the base: refused, and nothing written; then
# carried by hand and named with --resolved, which a second run accepts.
sed -i 's/^- from: the fixture$/- from: the fixture, amended on the dev side/' "$S3/both/requirements/GH-5.md"
tok 'an entry changed on both sides since the base is refused, and nothing is written' \
  "$S3_FIRST
split-requirements.sh: refused, and nothing was moved:
  GH-5: changed on HEAD and on the dev side since the base. Carry both changes into requirements/GH-5.md by hand, then run this again with --resolved GH-5
exit 1 no GH-8.md" \
  "$(bash "$S3/both/split-requirements.sh" 2>&1; printf 'exit %s' "$?"; [ -e "$S3/both/requirements/GH-8.md" ] || printf ' no GH-8.md')"
tok 'and the remedy it gives is one a second run accepts' \
  "$S3_FIRST
files written to requirements/: GH-8
resolved by hand, and left as it was: GH-5
GH-5: resolved by hand, so its SPLIT_MOVED token in check-hooks.sh moves from GH-5:3493104077:98 to GH-5:3275260752:123
changed on the dev side only since the base, and left as it was: GH-6
unchanged on both sides since the base, and left as it was: 1
$S3_LACKS
exit 0" "$(bash "$S3/both/split-requirements.sh" --resolved GH-5 2>&1; printf 'exit %s' "$?")"
# A version in requirements.md that the branch never committed would be lost by
# a run that writes the branch's, so it is refused.
sed -i 's/^- text: an entry nobody edits$/- text: an entry edited while resolving/' "$S3/edited/requirements.md"
tok 'an entry requirements.md holds in a version the branch never committed is refused' \
  "$S3_FIRST
split-requirements.sh: refused, and nothing was moved:
  GH-7: requirements.md holds a version of it that HEAD does not. Carry that version into requirements/GH-7.md by hand, then run this again with --resolved GH-7
exit 1" "$(bash "$S3/edited/split-requirements.sh" 2>&1; printf 'exit %s' "$?")"
sed -n '/^### GH-7$/,/^- status: active$/p' "$S3/edited/requirements.md" > "$S3/edited/requirements/GH-7.md"
tok 'and carried by hand and named with --resolved, a second run accepts it' \
  "$S3_FIRST
taken out of requirements.md: GH-5 GH-6 GH-7 GH-8
files written to requirements/: GH-5 GH-8
GH-5: changed on HEAD only since the base, so its SPLIT_MOVED token in check-hooks.sh moves from GH-5:3493104077:98 to GH-5:1218492981:99
resolved by hand, and left as it was: GH-7
GH-7: resolved by hand; check-hooks.sh holds no SPLIT_MOVED token for it
changed on the dev side only since the base, and left as it was: GH-6
$S3_DIFFERS
exit 0" "$(bash "$S3/edited/split-requirements.sh" --resolved GH-7 2>&1; printf 'exit %s' "$?")"
# An entry the base holds and the branch dropped: a ledger entry is marked, not
# deleted, so it is refused -- and named with --resolved when the dev side's
# file is the one that stands.
cp -a "$S3/pre" "$S3/dropped"
git -C "$S3/dropped" checkout -q feature
sed -i '/^### GH-7$/,/^$/d' "$S3/dropped/requirements.md"
git -C "$S3/dropped" -c user.email=checks@example.invalid -c user.name=checks commit -qam dropped
git -C "$S3/dropped" -c user.email=checks@example.invalid -c user.name=checks merge -q --no-edit dev > /dev/null 2>&1
git -C "$S3/dropped" checkout -q --theirs requirements.md
git -C "$S3/dropped" add requirements.md
S3D_FIRST="a merge is in progress: each GH- entry is compared three ways, against the merge base $S3_BASE and HEAD at $(git -C "$S3/dropped" rev-parse --short HEAD)"
tok 'an entry the base holds and the branch dropped is refused' \
  "$S3D_FIRST
split-requirements.sh: refused, and nothing was moved:
  GH-7: in the base and not on HEAD, and a ledger entry is marked rather than deleted. Restore it on the branch; or, if requirements/GH-7.md is right as it is, run this again with --resolved GH-7
exit 1" "$(bash "$S3/dropped/split-requirements.sh" 2>&1; printf 'exit %s' "$?")"
tok 'and named with --resolved, a second run accepts it' \
  "$S3D_FIRST
files written to requirements/: GH-5 GH-8
GH-5: changed on HEAD only since the base, so its SPLIT_MOVED token in check-hooks.sh moves from GH-5:3493104077:98 to GH-5:1218492981:99
resolved by hand, and left as it was: GH-7
GH-7: resolved by hand; check-hooks.sh holds no SPLIT_MOVED token for it
changed on the dev side only since the base, and left as it was: GH-6
$S3_LACKS
exit 0" "$(bash "$S3/dropped/split-requirements.sh" --resolved GH-7 2>&1; printf 'exit %s' "$?")"
# A merge committed: the last commit is it, and it is found without being asked;
# one committed earlier is asked with --base and --branch, as given.
cp -a "$S3/repo" "$S3/committed"
git -C "$S3/committed" checkout -q --theirs requirements.md
git -C "$S3/committed" add -A
git -C "$S3/committed" -c user.email=checks@example.invalid -c user.name=checks commit -qm merged
cp -a "$S3/committed" "$S3/committed-flags"
S3C_BASE=$(git -C "$S3/committed" merge-base HEAD^1 HEAD^2)
tok 'a merge that is the last commit is compared three ways without being asked' \
  "$(printf '%s\n' "$S3_WANT" | sed '1s/^a merge is in progress/the last commit is a merge that brought the split/; s/and HEAD at/and HEAD^1 at/; s/on HEAD only/on HEAD^1 only/; s/lines HEAD added/lines HEAD^1 added/; s/ HEAD -- requirements/ HEAD^1 -- requirements/')" \
  "$(bash "$S3/committed/split-requirements.sh" 2>&1; printf 'exit %s' "$?")"
tok 'and one named with --base and --branch the same' \
  "$(printf '%s\n' "$S3_WANT" | sed '1d; s/on HEAD only/on HEAD^1 only/; s/lines HEAD added/lines HEAD^1 added/; s/ HEAD -- requirements/ HEAD^1 -- requirements/')" \
  "$(bash "$S3/committed-flags/split-requirements.sh" --base "$S3C_BASE" --branch HEAD^1 "$S3/committed-flags" 2>&1; printf 'exit %s' "$?")"
tok 'and half of a three-way comparison is a usage error' \
  'usage: bash .claude/hooks/split-requirements.sh [--base <rev> --branch <rev>] [--resolved <ID>]... [<hooks directory>]
exit 64' "$(bash "$HOOKS/split-requirements.sh" --base HEAD "$S3/committed" 2>&1; printf 'exit %s' "$?")"
# A rebase replays the branch's commits one at a time, and this compares an
# entry across one merge, so it is refused -- with the dev side kept, which is
# `--ours` during a rebase, the first version ran two ways and lost the edit
# (rev-agent-200, round 5 of PR #210). Nothing is written.
cp -a "$S3/pre" "$S3/rebase"
git -C "$S3/rebase" checkout -q feature
git -C "$S3/rebase" -c user.email=checks@example.invalid -c user.name=checks rebase -q dev > /dev/null 2>&1
if ! git -C "$S3/rebase" rev-parse -q --verify REBASE_HEAD > /dev/null 2>&1; then
  echo "the three-way fixture's rebase did not stop; the check against it proves nothing" >&2
  exit 1
fi
git -C "$S3/rebase" checkout -q --ours requirements.md
git -C "$S3/rebase" add requirements.md
tok 'a rebase in progress is refused, and nothing is written' \
  'split-requirements.sh: a rebase is in progress, and this compares a GH- entry across one merge, not across commits replayed one at a time. Abort it and bring the dev branch in with a merge, then run this during that merge; or finish it and run this with --base <where the branch forked> --branch <the branch as it was before>; nothing was moved
exit 1 - text: an entry the branch edits' \
  "$(bash "$S3/rebase/split-requirements.sh" 2>&1; printf 'exit %s ' "$?"; sed -n 2p "$S3/rebase/requirements/GH-5.md")"
# EVERY ARM OF THE DETECTION AND OF THE CLASSIFICATION HAS A FIXTURE, and each
# of the ones below was an arm that a deleted line left green (rev-agent-200,
# round 6 of PR #210). The arms not driven here are I/O failures or states no
# repository reaches through git, and the pull request's round-6 reply lists
# them with the reason for each.
S3C="-c user.email=checks@example.invalid -c user.name=checks"
S3_REFUSED_TAIL='nothing was moved
exit 1 - text: an entry the branch edits'
# The other rebase backend: `rebase-apply`, which `git rebase --apply` and
# `git am` leave, where the default one leaves `rebase-merge`.
cp -a "$S3/pre" "$S3/rebase-apply"
git -C "$S3/rebase-apply" checkout -q feature
git -C "$S3/rebase-apply" $S3C rebase --apply -q dev > /dev/null 2>&1
git -C "$S3/rebase-apply" checkout -q --ours requirements.md
git -C "$S3/rebase-apply" add requirements.md
tok 'a rebase by the apply backend is refused, and nothing is written' \
  "split-requirements.sh: a rebase is in progress, and this compares a GH- entry across one merge, not across commits replayed one at a time. Abort it and bring the dev branch in with a merge, then run this during that merge; or finish it and run this with --base <where the branch forked> --branch <the branch as it was before>; $S3_REFUSED_TAIL" \
  "$(bash "$S3/rebase-apply/split-requirements.sh" 2>&1; printf 'exit %s ' "$?"; sed -n 2p "$S3/rebase-apply/requirements/GH-5.md")"
# A cherry-pick of the branch's commit onto the dev side, stopped on its
# conflict, the dev side kept: without this arm, "nothing to move" and the edit
# lost.
cp -a "$S3/pre" "$S3/cherry-pick"
git -C "$S3/cherry-pick" $S3C cherry-pick feature > /dev/null 2>&1
git -C "$S3/cherry-pick" checkout -q --ours requirements.md
git -C "$S3/cherry-pick" add requirements.md
tok 'a cherry-pick in progress is refused, and nothing is written' \
  "split-requirements.sh: a cherry-pick is in progress, and this compares a GH- entry across one merge, not across commits replayed one at a time. Abort it and bring the dev branch in with a merge, then run this during that merge; or finish it and run this with --base <where the branch forked> --branch <the branch as it was before>; $S3_REFUSED_TAIL" \
  "$(bash "$S3/cherry-pick/split-requirements.sh" 2>&1; printf 'exit %s ' "$?"; sed -n 2p "$S3/cherry-pick/requirements/GH-5.md")"
# A revert stopped on its conflict: the branch's commit reverted after a merge
# of the split that kept the dev side.
cp -a "$S3/pre" "$S3/revert"
git -C "$S3/revert" checkout -q feature
git -C "$S3/revert" $S3C merge -q --no-edit dev > /dev/null 2>&1
git -C "$S3/revert" checkout -q --theirs requirements.md
git -C "$S3/revert" add -A
git -C "$S3/revert" $S3C commit -qm merged
git -C "$S3/revert" $S3C revert --no-edit HEAD^1 > /dev/null 2>&1
git -C "$S3/revert" checkout -q --ours requirements.md
git -C "$S3/revert" add requirements.md
tok 'a revert in progress is refused, and nothing is written' \
  "split-requirements.sh: a revert is in progress, and this compares a GH- entry across one merge, not across commits replayed one at a time. Abort it and bring the dev branch in with a merge, then run this during that merge; or finish it and run this with --base <where the branch forked> --branch <the branch as it was before>; $S3_REFUSED_TAIL" \
  "$(bash "$S3/revert/split-requirements.sh" 2>&1; printf 'exit %s ' "$?"; sed -n 2p "$S3/revert/requirements/GH-5.md")"
# A squash merge leaves SQUASH_MSG and no MERGE_HEAD, the dev side kept.
cp -a "$S3/pre" "$S3/squash"
git -C "$S3/squash" checkout -q feature
git -C "$S3/squash" $S3C merge -q --squash dev > /dev/null 2>&1
git -C "$S3/squash" checkout -q --theirs requirements.md
git -C "$S3/squash" add requirements.md
tok 'a squash merge in progress is refused, and nothing is written' \
  "split-requirements.sh: a squash merge is in progress, and this compares a GH- entry across one merge, not across commits replayed one at a time. Abort it and bring the dev branch in with a merge, then run this during that merge; or finish it and run this with --base <where the branch forked> --branch <the branch as it was before>; $S3_REFUSED_TAIL" \
  "$(bash "$S3/squash/split-requirements.sh" 2>&1; printf 'exit %s ' "$?"; sed -n 2p "$S3/squash/requirements/GH-5.md")"
# A SQUASH_MSG left over from a squash abandoned earlier, beside a real merge:
# the merge is compared three ways, which is what `&& ! MERGE_HEAD` is for.
cp -a "$S3/theirs-dir" "$S3/stale-squash"
git -C "$S3/stale-squash" checkout -q -- requirements
rm -f "$S3/stale-squash/requirements/GH-8.md"
: > "$(git -C "$S3/stale-squash" rev-parse --absolute-git-dir)/SQUASH_MSG"
tok 'a SQUASH_MSG left beside a merge in progress does not stop the three-way run' \
  "$S3_WANT" "$(bash "$S3/stale-squash/split-requirements.sh" 2>&1; printf 'exit %s' "$?")"
# The other direction of a merge: the branch merged into the dev side, so that
# MERGE_HEAD is the side still holding entries. The dev side is `--ours` here.
cp -a "$S3/pre" "$S3/into-dev"
git -C "$S3/into-dev" $S3C merge -q --no-edit feature > /dev/null 2>&1
git -C "$S3/into-dev" checkout -q --ours requirements.md
git -C "$S3/into-dev" add requirements.md
cp -a "$S3/into-dev" "$S3/into-dev-committed"
tok 'the branch merged into the dev side is compared with MERGE_HEAD as the branch' \
  "$(printf '%s\n' "$S3_WANT" | sed 's/and HEAD at/and MERGE_HEAD at/; s/on HEAD only/on MERGE_HEAD only/; s/lines HEAD added/lines MERGE_HEAD added/; s/ HEAD -- requirements/ MERGE_HEAD -- requirements/')" \
  "$(bash "$S3/into-dev/split-requirements.sh" 2>&1; printf 'exit %s' "$?")"
# And committed: the last commit's second parent is then the branch.
git -C "$S3/into-dev-committed" $S3C commit -qm merged
tok 'and committed, with its second parent as the branch' \
  "$(printf '%s\n' "$S3_WANT" | sed '1s/^a merge is in progress/the last commit is a merge that brought the split/; s/and HEAD at/and HEAD^2 at/; s/on HEAD only/on HEAD^2 only/; s/lines HEAD added/lines HEAD^2 added/; s/ HEAD -- requirements/ HEAD^2 -- requirements/')" \
  "$(bash "$S3/into-dev-committed/split-requirements.sh" 2>&1; printf 'exit %s' "$?")"
# A merge committed with the branch side of requirements.md kept whole: still
# found, whatever HEAD holds, and its copies taken out (rev-agent-200, round 6).
cp -a "$S3/repo" "$S3/committed-ours"
git -C "$S3/committed-ours" checkout -q --ours requirements.md
git -C "$S3/committed-ours" add -A
git -C "$S3/committed-ours" $S3C commit -qm merged
tok 'a merge committed with the branch side kept is found too, and its copies taken out' \
  "the last commit is a merge that brought the split: each GH- entry is compared three ways, against the merge base $S3_BASE and HEAD^1 at $S3_HEAD
taken out of requirements.md: GH-5 GH-6 GH-7 GH-8
files written to requirements/: GH-5 GH-8
GH-5: changed on HEAD^1 only since the base, so its SPLIT_MOVED token in check-hooks.sh moves from GH-5:3493104077:98 to GH-5:1218492981:99
changed on the dev side only since the base, and left as it was: GH-6
unchanged on both sides since the base, and left as it was: 1
requirements.md lacks lines HEAD^2 added outside the GH- entries since the base, lines missing: 1 -- a side the merge kept whole drops the other side's changes there, and git diff $S3_BASE HEAD^2 -- requirements.md says which
exit 0" "$(bash "$S3/committed-ours/split-requirements.sh" 2>&1; printf 'exit %s' "$?")"
# A merge in progress where neither side holds an entry -- two branches both cut
# after the split -- is nothing to do with it, and is compared two ways.
cp -a "$S3/committed" "$S3/neither"
git -C "$S3/neither" checkout -q -b side HEAD^2
printf 'a file\n' > "$S3/neither/side.txt"
git -C "$S3/neither" add side.txt
git -C "$S3/neither" $S3C commit -qm side
git -C "$S3/neither" checkout -q feature
git -C "$S3/neither" $S3C merge -q --no-commit --no-ff side > /dev/null 2>&1
tok 'a merge in which neither side holds an entry is compared two ways' \
  'requirements.md holds no GH- entry; nothing to move
(a merge of the split finished before the last commit, or a rebase, is compared three ways with --base <where the branch forked> --branch <the branch as it was before>)
exit 0' "$(bash "$S3/neither/split-requirements.sh" 2>&1; printf 'exit %s' "$?")"
# THE CLASSIFICATION'S OTHER ARMS. Unchanged on the branch and absent on the dev
# side: written back, the branch's being the base's.
cp -a "$S3/theirs-dir" "$S3/dev-dropped"
git -C "$S3/dev-dropped" checkout -q -- requirements
rm -f "$S3/dev-dropped/requirements/GH-8.md" "$S3/dev-dropped/requirements/GH-7.md"
tok 'an entry the dev side has no file for, and the branch left alone, is written back' \
  "$S3_FIRST
files written to requirements/: GH-5 GH-7 GH-8
GH-5: changed on HEAD only since the base, so its SPLIT_MOVED token in check-hooks.sh moves from GH-5:3493104077:98 to GH-5:1218492981:99
changed on the dev side only since the base, and left as it was: GH-6
$S3_LACKS
exit 0" "$(bash "$S3/dev-dropped/split-requirements.sh" 2>&1; printf 'exit %s' "$?")"
# A second run: the files now hold the branch's versions, and are left as they
# are, which is what makes it a no-op.
tok 'a second three-way run writes nothing' \
  "$S3_FIRST
changed on the dev side only since the base, and left as it was: GH-6
already in requirements/ with the same bytes, and left as it was: GH-5 GH-8
unchanged on both sides since the base, and left as it was: 1
$S3_LACKS
exit 0" "$(bash "$S3/dev-dropped/split-requirements.sh" 2>&1; printf 'exit %s' "$?")"
# An entry new on the branch whose file the dev side holds differently: two
# loops minted the ID.
cp -a "$S3/theirs-dir" "$S3/minted"
git -C "$S3/minted" checkout -q -- requirements
printf '### GH-8\n- text: another loop wrote this ID first\n' > "$S3/minted/requirements/GH-8.md"
tok 'an entry new on the branch whose file already holds something else is refused' \
  "$S3_FIRST
split-requirements.sh: refused, and nothing was moved:
  GH-8: requirements/GH-8.md is there already and holds something else; two loops wrote this ID. Make the file the right one, then run this again with --resolved GH-8
exit 1" "$(bash "$S3/minted/split-requirements.sh" 2>&1; printf 'exit %s' "$?")"
# An entry requirements.md holds that the branch never committed at all.
cp -a "$S3/repo" "$S3/uncommitted"
git -C "$S3/uncommitted" checkout -q --ours requirements.md
git -C "$S3/uncommitted" add requirements.md
sed -i 's/^## Provenance: /### GH-9\n- text: an entry only the working tree holds\n- from: the fixture\n- kind: doc-claim\n- status: active\n\n&/' \
  "$S3/uncommitted/requirements.md"
tok 'an entry requirements.md holds and the branch never committed is refused' \
  "$S3_FIRST
split-requirements.sh: refused, and nothing was moved:
  GH-9: requirements.md holds it and HEAD does not. Carry it into requirements/GH-9.md by hand, then run this again with --resolved GH-9
exit 1" "$(bash "$S3/uncommitted/split-requirements.sh" 2>&1; printf 'exit %s' "$?")"
# A file named with --resolved whose token has not moved gets no token line.
cp -a "$S3/theirs-dir" "$S3/resolved-same"
git -C "$S3/resolved-same" checkout -q -- requirements
rm -f "$S3/resolved-same/requirements/GH-8.md"
tok 'a resolved file whose token is unchanged says nothing about its token' \
  "$S3_FIRST
files written to requirements/: GH-8
resolved by hand, and left as it was: GH-5
changed on the dev side only since the base, and left as it was: GH-6
unchanged on both sides since the base, and left as it was: 1
$S3_LACKS
exit 0" "$(bash "$S3/resolved-same/split-requirements.sh" --resolved GH-5 2>&1; printf 'exit %s' "$?")"
# The right resolution -- the dev side's hunks, and the branch's line outside
# the entries -- draws no warning at all.
cp -a "$S3/theirs-dir" "$S3/hunkwise"
git -C "$S3/hunkwise" checkout -q -- requirements
rm -f "$S3/hunkwise/requirements/GH-8.md"
sed -i 's/^## Provenance: .*$/&\n- a criterion the branch adds, outside the entries/' "$S3/hunkwise/requirements.md"
tok 'requirements.md resolved hunk by hunk draws no warning' \
  "$(printf '%s\n' "$S3_WANT" | sed '/^requirements.md lacks /d')" \
  "$(bash "$S3/hunkwise/split-requirements.sh" 2>&1; printf 'exit %s' "$?")"
# A refusal read out of the branch's own commit: a rerun reads it again, so the
# remedy says to fix it on the branch.
cp -a "$S3/pre" "$S3/branch-bad"
git -C "$S3/branch-bad" checkout -q feature
sed -i '/^- text: an entry the branch appends$/a a stray line inside the entry' "$S3/branch-bad/requirements.md"
git -C "$S3/branch-bad" $S3C commit -qam stray
git -C "$S3/branch-bad" $S3C merge -q --no-edit dev > /dev/null 2>&1
git -C "$S3/branch-bad" checkout -q --theirs requirements.md
git -C "$S3/branch-bad" add requirements.md
tok 'a refusal in the branch'"'"'s own commit says to fix it there' \
  "a merge is in progress: each GH- entry is compared three ways, against the merge base $S3_BASE and HEAD at $(git -C "$S3/branch-bad" rev-parse --short HEAD)
split-requirements.sh: refused, and nothing was moved:
  HEAD: line 25: GH-8: a line that is no field of the entry, which would be moved into requirements/GH-8.md with it; take the line out of every entry: put the GH- entries of this section below it, or it above the first of them: a stray line inside the entry
  each of these is in HEAD's committed requirements.md, which every run reads again: abort the merge, fix it on the branch, and merge again
exit 1" "$(bash "$S3/branch-bad/split-requirements.sh" 2>&1; printf 'exit %s' "$?")"
# The arms that stop before comparing: a revision that is no commit, a base
# without the file, a base whose file cannot be read into entries, a comparison
# where neither side holds an entry, a branch without the file, and --resolved
# naming no file, three ways and two. Plumbing builds the two bad revisions.
S3P="$S3/committed-flags"
cp -r "$SPLIT_FIX/before" "$SPLIT_FIX/resolved-nofile"
S3_EMPTY=$(git -C "$S3P" $S3C commit-tree 4b825dc642cb6eb9a060e54bf8d69288fbee4904 -m empty)
S3_BADBLOB=$(printf '## Boundary issues\n\n### GH-1\n- text: x\na stray line\n' | git -C "$S3P" hash-object -w --stdin)
S3_BADTREE=$(printf '100644 blob %s\trequirements.md\n' "$S3_BADBLOB" | git -C "$S3P" mktree)
S3_BAD=$(git -C "$S3P" $S3C commit-tree "$S3_BADTREE" -m bad)
tok 'the arms that stop before comparing each say why' \
  "split-requirements.sh: nosuchrev is not a commit in the repository that holds $S3P; nothing was moved
exit 1|split-requirements.sh: $S3_EMPTY holds no requirements.md at the path of $S3P; nothing was moved
exit 1|split-requirements.sh: the base's requirements.md is one this cannot read into entries, so nothing can be compared with it; nothing was moved
  line 5: GH-1: a line that is no field of the entry, which would be moved into requirements/GH-1.md with it; take the line out of every entry: put the GH- entries of this section below it, or it above the first of them: a stray line
exit 1|neither requirements.md nor HEAD^2 holds a GH- entry; nothing to move
exit 0|split-requirements.sh: $S3_EMPTY holds no requirements.md at the path of $S3P; nothing was moved
exit 1|split-requirements.sh: --resolved GH-99 names no file requirements/GH-99.md, which is what it leaves as it is; nothing was moved
exit 1|split-requirements.sh: --resolved GH-99 names no file requirements/GH-99.md, which is what it leaves as it is; nothing was moved
exit 1" \
  "$(bash "$S3P/split-requirements.sh" --base nosuchrev --branch HEAD "$S3P" 2>&1; printf 'exit %s|' "$?"
     bash "$S3P/split-requirements.sh" --base "$S3_EMPTY" --branch HEAD "$S3P" 2>&1; printf 'exit %s|' "$?"
     bash "$S3P/split-requirements.sh" --base "$S3_BAD" --branch HEAD "$S3P" 2>&1; printf 'exit %s|' "$?"
     bash "$S3P/split-requirements.sh" --base HEAD^2 --branch HEAD^2 "$S3P" 2>&1; printf 'exit %s|' "$?"
     bash "$S3P/split-requirements.sh" --base HEAD^2 --branch "$S3_EMPTY" "$S3P" 2>&1; printf 'exit %s|' "$?"
     bash "$S3P/split-requirements.sh" --base "$S3C_BASE" --branch HEAD^1 --resolved GH-99 "$S3P" 2>&1; printf 'exit %s|' "$?"
     bash "$HOOKS/split-requirements.sh" --resolved GH-99 "$SPLIT_FIX/resolved-nofile" 2>&1; printf 'exit %s' "$?")"
# And the arguments: an option with no value, an option not known, and a
# second directory are each a usage error.
tok 'a malformed argument list is a usage error, each way' '64 64 64' \
  "$(bash "$HOOKS/split-requirements.sh" --branch > /dev/null 2>&1; printf '%s ' "$?"
     bash "$HOOKS/split-requirements.sh" --bogus > /dev/null 2>&1; printf '%s ' "$?"
     bash "$HOOKS/split-requirements.sh" "$S3P" "$S3P" > /dev/null 2>&1; printf '%s' "$?")"

echo "--- #205: every GH- entry outside the legacy set is generated from its declaration ---"
# Asked here, after the last issue file, because the record of what was
# declared and pinned is complete only once every issue file has run. The
# helpers are the library's, and the #205 issue file drives each against a
# fixture first.
#
# What was declared is the record bash wrote as it ran each `requirement`
# call, and the files are held to it; the generator's own reading of the issue
# files is then held to the same IDs. So the two readings of one declaration --
# bash's and the generator's awk -- meet in the files, and a declaration one of
# them reads and the other does not is red in one of the two checks below.
req GH-205.1
R205_DECLARED_IDS=$(while IFS= read -r -d '' R205_REC; do printf '%s\n' "${R205_REC%%$'\t'*}"; done < "$DECLARED" \
                      | LC_ALL=C sort -V | tr '\n' ' ' | sed 's/ $//')
[ -n "$R205_DECLARED_IDS" ] \
  || fail static 'no issue file declared an entry, so the checks below ask about none'
tok 'every GH- entry outside the legacy set is, byte for byte, its declaration as this run read it, and every legacy entry is a hand-written file' \
  '' "$(generated_bad "$DECLARED" "$HOOKS/requirements" "$REQUIREMENTS_LEGACY")"
# The script is the judged one, and it is run over the issue files this run
# sourced and the judged requirements/, which `generator_view` puts in one
# directory; the #205 issue file drives it against a judged side that has no
# checks/. In this repository the two sides are one directory, so this suite
# cannot see the two arguments swapped here. The harness can, because it runs
# the suite with CHECK_HOOKS_DIR on a copy: swapped, the two rows that edit a
# file under requirements/ and name GH-205.2 among their IDs,
# generated-entry-edited-by-hand and legacy-entry-marked-generated, go from
# caught to survived, since this check then reads the suite's requirements/,
# which the mutation did not touch, and not the mutated copy's (review of PR
# #222, round 4, and re-measured).
req GH-205.2
R205_VIEW=$(generator_view "$SUITE_DIR" "$HOOKS" "$FIXTURES/generator-view")
tok 'generate-requirements.sh reads the declarations this run read, and would write nothing' \
  "generate-requirements.sh: every generated entry is its declaration: $R205_DECLARED_IDS
exit 0" "$(bash "$HOOKS/generate-requirements.sh" --check "$R205_VIEW" 2>&1; printf 'exit %s' "$?")"
# #211, decided: the shared literals hold the legacy entries, and a generated
# entry's tokens are pinned in its issue file. The shape pins are compared with
# the entries in the #104 findings below, handed over as REQUIREMENT_SHAPE_HELD;
# the variants pins are compared here, with the scope the #141 section derived,
# whose own comparison holds INV_SCOPE to the legacy entries alone. Both sides
# of the last check are empty today, because no generated entry is in the
# families' scope yet: what it would compare is the split `legacy_tokens` makes,
# which the #205 issue file asks of a fixture, and the pins, which it asks of
# `variants_pin`; what it asks of this repository is nothing until such an entry
# is written.
req GH-205.3
tok 'REQUIREMENT_SHAPE and INV_SCOPE hold legacy entries only, and each generated entry is pinned once, in the issue file that declares it' \
  '' "$(pins_bad "$DECLARED" "$PINNED" "$REQUIREMENT_SHAPE" "$INV_SCOPE" "$REQUIREMENTS_LEGACY")"
tok 'the generated entries in the families scope are these, each with what it says the families do with it, as their issue files pin them' \
  "$(awk -F'\t' '$1 == "variants" { n = split($3, t, " "); for (i = 1; i <= n; i++) print t[i] }' "$PINNED" \
       | LC_ALL=C sort | tr '\n' ' ')" \
  "$(legacy_tokens out "$REQUIREMENTS_LEGACY" "$INV_SCOPE_DERIVED")"

echo "--- every result goes through pass and fail ---"
# A result printed any other way is printed and not recorded, so it covers
# nothing and is refused for having no tag by nothing. The lines that print a
# result are read off this file, comments stripped, and must be exactly the two
# in pass and fail. Any quoted string opening with a result's prefix counts,
# whatever prints it, so `printf '%s\n' "  ok ..."` and `echo -e` are found too;
# the first version asked for printf or echo followed by the quote and missed
# both, found by review of #104. The limit, named: stripping comments cuts at a
# `#` inside a string, so a result printed on a line holding one before it is
# not seen. The pattern is split across two quoted words and each expected line
# breaks its word with a quote, so that neither is among its own matches.
req GH-104.1
tok 'the only lines that print a check result are the two in pass and fail' \
"  printf '  o"'k'"   %s\n' \"\$line\"
  printf '  F"'AIL'" %s\n' \"\$line\"" \
  "$(sed 's/[[:space:]]*#.*$//' "$SUITE_TEXT" | grep -E "['\"]  (ok   |FAI""L )")"

echo "--- this repository ---"
# The record is copied before it is read, because every line printed below is
# appended to it while the program runs. What these findings count is every
# check above this line; their own results reach the matrix and not this reading.
cp "$LEDGER" "$FIXTURES/ledger-read"
FINDINGS=$(requirements_read findings "$HOOKS/requirements.md" "$FIXTURES/ledger-read" \
             "$SUITE_TEXT" "$REPO_ROOT" "$HOOKS/runbook.md" "$PROVENANCE_COUNTS" "$REQUIREMENT_SHAPE_HELD")
FINDINGS_STATUS=$?
# An awk that failed may print nothing, or only the findings before the failure,
# and a loop over what it printed passes by asking too little -- the permitting
# direction. So its status is read as well as its output: under mawk a read of a
# directory aborts the program with exit 2, found by review of #104.
req FR-45 FR-46 GH-104.1
[ "$FINDINGS_STATUS" = 0 ] || fail static 'the requirements program exited %s, so its findings are not all of them' "$FINDINGS_STATUS"
[ -n "$FINDINGS" ] || fail static 'the requirements program printed no finding at all'
while IFS="$TAB" read -r RESULT TAGS TEXT; do
  req $TAGS
  case "$RESULT" in
    ok) pass static '%s' "$TEXT" ;;
    *)  fail static '%s' "$TEXT" ;;
  esac
done <<< "$FINDINGS"

# THE LAST LINK OF #148's CHAIN. The #107 section above asks whether the harness
# counts the active requirements the way this file counts them, and both sides of
# that are the same short program written twice -- so a defect they share agrees
# with itself, which that section says in as many words. This is the link that
# makes it mean something: REQUIREMENTS_AWK is the canonical reader of
# requirements.md and the split set beside it, section-aware, entry-aware and separately checked by the
# fixture above, and its matrix line publishes an active count of its own. A
# stray `- status: active` in a section that holds no entries moves the short
# program and does not move this one. Bertan's review of PR #183 named exactly
# that case.
#
# Read over $SUITE_DIR/requirements.md and the split set beside it, which are
# what the short program and the harness both counted; $HOOKS is where the repository's own findings above
# come from, and comparing across the two would go red for an override.
req GH-148
MUT_MATRIX_LINE=$(requirements_read matrix "$SUITE_DIR/requirements.md" "$FIXTURES/ledger-read" \
                    "$SUITE_TEXT" "$REPO_ROOT" "$SUITE_DIR/runbook.md" \
                    "$PROVENANCE_COUNTS" "$REQUIREMENT_SHAPE_HELD" \
                  | awk '/^requirements matrix: / { print; exit }')
REQ_ACTIVE_CANON=$(printf '%s\n' "$MUT_MATRIX_LINE" \
                   | awk -F'[;,] *' '{ print $2 }' | awk '{ print $1 }')
if [ -z "$REQ_ACTIVE_CANON" ] || [ "$REQ_ACTIVE_CANON" = 0 ]; then
  fail static 'the canonical reader published no active count, so the #148 chain has no last link'
else
  tok 'the active-requirement count the #148 checks use is the one the canonical reader derives' \
      "$REQ_ACTIVE_CANON" "$REQ_ACTIVE_HERE"
fi

# AND THE ONE #148 NUMBER THAT IS NOT DERIVABLE, held to the only falsifiable
# thing that can be said about it. `MEASURED_SECONDS_PER_RUN` is how long a run
# of this suite takes: a measurement, of this machine and of how big the suite
# has grown, that nothing in this repository can derive. The run COUNT needs no
# maintenance; this does, and #148's first fix claimed otherwise and was wrong.
# The figure it replaced -- 124 s, taken 2026-09-17 -- was out by more than a
# factor of two three days later, because the suite had grown, and no check
# anywhere could say so. Bertan's review of PR #183 found it by timing the suite.
#
# THE SUITE'S OWN SIZE IS THE SIGNAL, because it is what drives the rate and it
# is already derived here. The harness records the result count standing when
# the rate was taken; this compares it against the count now and goes red once
# the suite has grown by a quarter. A quarter, not a tenth: a budget wrong by
# that much is still a budget, and a check that cried every fortnight would be
# turned off. What it cannot see is the machine changing under a suite that
# stayed the same size, which is stated here rather than left to be discovered.
req GH-148
MUT_AT_RESULTS=$(awk -F'[= ]' '/^MEASURED_AT_RESULTS=/ { print $2; exit }' "$MUT")
RESULTS_NOW=$(printf '%s\n' "$MUT_MATRIX_LINE" \
              | awk -F'[;,] *' '{ print $NF }' | awk '{ print $1 }')
if [ -z "$MUT_AT_RESULTS" ] || [ "$MUT_AT_RESULTS" = 0 ] || [ -z "$RESULTS_NOW" ]; then
  fail static 'the measured rate records no suite size, so nothing can say whether it has gone stale'
elif [ "$RESULTS_NOW" -gt "$(( MUT_AT_RESULTS * 5 / 4 ))" ]; then
  fail static 'the suite has grown from %s check results to %s since the harness rate was measured, so the runtime --list prints is stale; re-measure it and move both constants' \
    "$MUT_AT_RESULTS" "$RESULTS_NOW"
else
  pass static 'the suite has not outgrown the measurement the harness rate rests on: %s results then, %s now' \
    "$MUT_AT_RESULTS" "$RESULTS_NOW"
fi

# EVERY SECTION HEADING HAS A ROW UNDER IT, a `---` subheading's rows counting
# for its `===` heading: asked here, once every row but the foot's is in the
# ledger, of every heading `section` wrote down (see `heading_mark`, and #204's
# step-2 section at the end of the unsplit file, which drives the reading). A
# heading moved into another file without its rows, or left behind when they
# moved, is a heading of nothing. That the row below ran, under its own tag and
# with its own label, is read back from the ledger by the last check before the
# matrix: the unsplit file's text pin of it shows only that it is written
# (rounds 3 and 4 of the review of PR #220).
req GH-204.8
tok 'every heading section wrote down has at least one row under it' \
    '' "$(sections_without_rows "$HEADINGS" "$LEDGER")"
[ -s "$HEADINGS" ] || fail static 'no section heading was written down, so the check above asked nothing'

# EVERY FUNCTION THIS RUN STARTED WITH IS THE ONE IT ENDS WITH: see
# LOADED_BODY at the head of this suite. Asked here, after every check, as a
# row; the verdict it gives is taken again by FOOT_VERDICT_CODE after every
# helper has run, because `fail` could be the function redefined (round 4) and
# a redefined helper can clear FAILED after this has set it (round 5).
req GH-204.1
LOADED_CHANGED=$(eval "$LOADED_CHANGED_CODE")
if [[ -n $LOADED_CHANGED ]]; then
  fail static 'a function or tokeniser variable this run started with was redefined or removed during it, so every check after that asked a different one:\n%s' \
    "$(printf '%s\n' "$LOADED_CHANGED" | sed 's/^/       /')"
else
  pass static 'every function and tokeniser variable this run started with is the one it ended with'
fi

# NO COMMAND THIS RUN CALLED WAS MISSING: what `command_not_found_handle`, at
# the head of this suite, wrote down. Asked here because it is about every check
# above, as a row; the two rows below it run after it, so a command missing in
# them is not in what this row reads, and FOOT_VERDICT_CODE, which reads the
# record again after them, is what sees it -- for the reason the check above
# gives. A missing `tok` would be one of the things this
# reports.
# What this row cannot see and the final verdict can: a command missing in the
# --matrix program below, which runs after this row and before the verdict.
# What neither can, named at the handler: a command missing before the fixtures
# directory existed, and one missing in a child run with `bash -c`, which is
# another shell and not a subshell of this one.
req GH-204.5
if [[ -s $NOT_FOUND ]]; then
  fail static 'a command this suite called was not found, so every check that called it asked nothing:\n%s' \
    "$(sort "$NOT_FOUND" | uniq -c | sed 's/^ */       /')"
else
  pass static 'no command this suite called was missing, in this shell or in any subshell of it'
fi

# THE NOT-FOUND RECORD IS WHERE THE HEAD PUT IT: the verdict's third question,
# which had no row, so a run it failed ended SOME CHECKS FAILED with every row
# green and only a line on stderr to say why (round 7 of the review). Asked
# here as a row like its two siblings, and taken again by FOOT_VERDICT_CODE.
req GH-204.5
if [[ $NOT_FOUND != "$NOT_FOUND_AT_HEAD" ]]; then
  fail static 'the not-found record was moved during the run and not put back, so what was written to %s before the move was not read; it is %s now' \
    "$NOT_FOUND_AT_HEAD" "$NOT_FOUND"
else
  pass static 'the not-found record is where the head put it, so what the handler wrote is what the verdict reads'
fi
# EACH OF THE VERDICT'S QUESTIONS HAS ITS ROW, read back from the ledger: the
# last four rows recorded are the heading question's and the verdict's three,
# above, each under the requirement it establishes -- so a question with no
# row, or a row under the wrong tag, is red here and not only a line on stderr.
# The heading question is among them because a text pin shows that it is
# written, and only the ledger that it ran, under GH-204.8 -- a `||` ending the
# line before it, or its `req` lost, left the pin green (round 3 of the review
# of PR #220). Its label is read as well as its tag, so the GH-204.8 row in that
# place is that question's and not another's (round 4).
req GH-204.1 GH-204.5 GH-204.8
tok 'the heading question and the verdict'"'"'s three questions end the ledger, each as a row under its own requirement, the heading question'"'"'s under its own label' \
'GH-204.8
GH-204.1
GH-204.5
GH-204.5
every heading section wrote down has at least one row under it' \
    "$(tail -n 4 "$LEDGER" | cut -f1; tail -n 4 "$LEDGER" | head -n 1 | cut -f4)"

# --matrix: every requirement, from the record as it stands now, the findings
# above included, and then the verdict line the run would have printed.
if [ -n "$MATRIX" ]; then
  requirements_read matrix "$HOOKS/requirements.md" "$LEDGER" "$SUITE_TEXT" \
    "$REPO_ROOT" "$HOOKS/runbook.md" "$PROVENANCE_COUNTS" "$REQUIREMENT_SHAPE_HELD" >&3
  MATRIX_STATUS=$?
  exec >&3
  if [ "$MATRIX_STATUS" != 0 ]; then
    echo "the matrix program exited $MATRIX_STATUS, so the matrix above is not the whole of it"
    FAILED=1
  fi
fi
sourced_to_end

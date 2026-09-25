#!/bin/bash
# THE ISSUE FILE OF #215: the run log in mutate-hooks.sh's header is frozen, and
# a run made after it is recorded in the dev-log of the session that ran it.
#
# Why: every loop that registered a mutation row appended a paragraph to that
# log, and the shared append was where concurrent pull requests conflicted in
# the harness. #215's triage re-measured it at 2c65f4d with `git merge-tree`:
# #184 and #158 each conflicted there, in header prose, and no hunk fell inside
# the MUTATIONS heredoc, whose rows merge cleanly because each is inserted
# beside the rows on its topic. So the registry is not split, and the log is
# frozen instead.
#
# THE LOG, BY ITS TEXT, both lines inclusive and each standing once in the file:
#   from  # MEASURED, 2026-09-17, at the commit that answered that review: all twenty-three
#   to    # thing #107 was filed about, and the registry is re-runnable instead.
# By text and never by line number, because the rules above it change length.
#
# WHAT IT COVERS, and why:
#   - MEASURED, 2026-09-17: the whole-registry run the log starts from, in
#     which every row reported what it declares.
#   - THAT MEASUREMENT IS NOT CURRENT, and the per-issue account under it, from
#     #108 to #148: the paragraph every loop appended to.
#   - THE BRACKET FIGURE IS HISTORY, a rule paragraph inside that account. It is
#     frozen with the log rather than moved out above it. It qualifies the 289
#     and 274 figures in the account's #134 lines just before it, and the
#     account resumes after it, so moving it would cut the account in two and
#     leave the caveat standing away from the figure it qualifies.
#   - THREE ROWS FOR ONE FIX, #128's. It carries figures of its own: 151 checks
#     red, and the differential going from 0 hidden pushes to 198. Its rule, why
#     three rows stand for one fix, is about those three rows only. Frozen with
#     the log for both reasons.
# WHAT IT LEAVES OUT is every other paragraph of the harness. These are the
# ones that carry a date, a measured figure or an account of an earlier
# change, and so could be taken for run records, with why each stays out.
# What they share: none is where a loop appended a run, and each is the
# evidence for the rule it stands in, so freezing it would freeze that rule.
#   - The measurements of the rate. `124 s, taken 2026-09-17` in THE RATE IS
#     THE HALF #148 DID NOT FIX, and the 2026-09-17 readings under it, 47 min
#     34 s and 45 min 24 s over twenty-three runs. Those two readings ARE run
#     records: the wall-clock of two whole-registry passes, on registries one
#     row apart, and the source of the 124 s. They stay out because they are
#     kept as the rate's evidence, which is how their own sentence describes
#     them. Below `set -u`, beside MEASURED_SECONDS_PER_RUN, MEASURED 2026-09-20
#     and RE-MEASURED after #169's merge time single runs of the suite, and no
#     row of the registry.
#     Re-measuring the rate is outside #215.
#   - The history of how the header's prose went stale: NO MAGNITUDE IS
#     WRITTEN IN THIS HEADER, AND IT WENT STALE A THIRD AND FOURTH TIME, #169
#     REACHED HALF OF THIS INDEPENDENTLY, FOUND TWICE, INDEPENDENTLY, WHAT IS
#     REGISTERED, #148 IS WHY NONE OF THEM IS WRITTEN HERE, and AND #134's
#     MERGE SHIPPED THREE OF THE FOUR WRONG, measured at df60fa1. They measure
#     prose, not a run, and are #148's argument.
#   - A MUTATION THAT DOES NOT APPLY IS A FAILURE, whose two mutations from
#     #106's section that did not apply on their first attempt are that rule's
#     evidence.
#
# WHY ITS BYTES AND NOT ITS SHAPE. A shape -- a line count, a paragraph count,
# a last line -- passes a paragraph rewritten in place. The log is to stay
# verbatim, and that includes corrections: a correction goes in the dev-log of
# the session that finds it, as in any append-only record here. A checksum is
# the one literal that says byte for byte. What it costs: any edit inside the
# region is red, including a correct one. That is intended.
#
# AND ITS NEIGHBOURS, because a checksum of a region bounded by its own text
# cannot see a paragraph added after its last line, and the end of the log is
# exactly where the loops appended. So the paragraph after the log is asked to
# be the rule WHAT A MUTATION IS, and the one before it the freeze paragraph.
# Each is asked by its opening words rather than its last line, and read
# through comment_reflow, the reader every pin on this header's prose takes,
# so rewrapping either stays green, and so does a trailing blank or a deeper
# indent.
#
# AND THE REST OF THE FILE, because the log and its two neighbours are a fence,
# and a record moves one paragraph past it. Review of #215's pull request
# measured three placements the fence alone passed: the last sentence of the
# freeze paragraph, a paragraph above it, and a paragraph below WHAT A MUTATION
# IS. The first is where the next loop would write, since that paragraph is the
# one about runs, and two loops writing there conflict as #184 and #158 did.
# So the rest of the file is asked for the words a record is written in, which
# are the log's own.
# Every sentence of the log that records a run carries a date, or one of
# `byte-identical after`, `selection` and `baseline`, measured at #215 by
# splitting the log into sentences. The review proposed a date and
# `byte-identical after` alone, and said every record carries one of them:
# `#128 added three and ran them the same way, baseline plus three, all caught
# with GH-128 red.` carries neither, and nor does the sentence that ran the five
# #139 rows again. Outside the log those words stand as follows, which is what
# the checks below pin:
#   - a date: six, over the whole file. Three in the header -- `124 s, taken
#     2026-09-17`, `The 2026-09-17 readings` and the freeze paragraph's
#     quotation of the log's first line -- and three below `set -u`, at
#     MEASURED_SECONDS_PER_RUN: MEASURED 2026-09-20, the 124 s it replaced on
#     2026-09-17, and the `--list` line that prints the rate's date. A date has
#     no blank in it, so it is counted on the lines as written. A count and not
#     the list, so a re-measure of the rate that replaces its date in place
#     stays green, and a date added anywhere outside the log is red.
#   - `byte-identical after`, `selection` and `baseline green`: none, in the
#     header's prose. The code below `set -u` says `selection` in a comment
#     about how rows are named and `byte-identical` in its messages, so these
#     are asked of the header only, read through comment_reflow.
#   - `baseline plus`: once in the header's prose, in the rule that says what
#     naming rows costs, `the baseline plus one run each`. So it is a count too.
# The price is a red on a rule that comes to use one of those words, or a date,
# for a reason of its own. That is the direction to be wrong in: the red names
# the paragraph's words, and whoever wrote them decides whether they are a
# record.
#
# WHAT IT DOES NOT SEE, named. A run recorded in none of those words -- no
# date, and none of the four phrases -- anywhere outside the log, and a record
# in the code below `set -u` that has no date. The first is not how any record
# in the log was written. It also does not see whether a later session recorded
# its run in its dev-log at all, because no file here can say that a run
# happened.
#
# THE TRADE, taken knowingly: a block that is stale by construction stays in
# the file, and a later run is no longer recorded beside the rows it ran. Stale
# in its names as well as its dates and counts: the log names forty-five rows
# of the registry by their ids, measured at #215, and a row renamed later leaves
# the log naming a row the registry no longer has, which cannot be corrected in
# place either. Review of #215's pull request asked for that clause. The
# rejected alternative was moving the log verbatim out of the harness, into a
# dated file under docs/. The header would then lose the only copy of several
# of these records beside the rows they describe. The dev-logs of the sessions
# that made them are append-only, so the log cannot be handed back to them
# either.

section "=== issue #215: the harness's run log is frozen, and a later run is recorded in the dev-log ==="

requirement GH-215 <<'REQ'
- text: The run log in `mutate-hooks.sh`'s header, from the line that opens
  `# MEASURED, 2026-09-17, at the commit that answered that review` to the
  line `# thing #107 was filed about, and the registry is re-runnable
  instead.`, is byte for byte what it was at #215. Each of those two lines
  stands once in the file. The paragraph directly above the log is the one
  that freezes it, and the paragraph directly below is the rule `WHAT A
  MUTATION IS`. The freeze paragraph names both lines. It says the log's
  present tense is #215's, and that a run after #215 is recorded in the
  dev-log of the session that ran it. Outside the log, the harness carries
  six dates, and its header's prose carries none of `byte-identical after`,
  `selection` or `baseline green`, and `baseline plus` only once, so no
  other paragraph records a run in the words the log's records use.
- from: #215
- kind: doc-claim
- status: active
- direction: static: it reads the harness's text against literals
- note: Content and not shape, because the log is to stay verbatim with its
  errors, and a correction goes in the newest dev-log. The neighbours are
  asked by their opening words, through the reader every pin on the header's
  prose takes, so a record appended after the log's last line is red, and
  rewrapping either paragraph is not. What it does not see: a run recorded
  outside the log in none of the log's words, an undated one below `set -u`,
  and whether a later run was recorded anywhere at all.
REQ
shape_pin 'GH-215:static'

req GH-215
R215_MUT="$SUITE_DIR/mutate-hooks.sh"
R215_FIRST='# MEASURED, 2026-09-17, at the commit that answered that review: all twenty-three'
R215_LAST='# thing #107 was filed about, and the registry is re-runnable instead.'

tok 'the frozen run log opens on one line of the harness, named by its text' \
    '1' "$(grep -cxF -- "$R215_FIRST" "$R215_MUT")"
tok 'and closes on one line, named by its text' \
    '1' "$(grep -cxF -- "$R215_LAST" "$R215_MUT")"
# From the first line to the last, both inclusive. With the last line gone the
# region runs to the end of the file, and with the first gone it is empty; both
# change the checksum. ENVIRON and not `awk -v`, which would read a backslash in
# either line as an escape.
tok 'and holds, byte for byte, the 216 lines it held at #215' \
    '1303306919 15781' \
    "$(R215_FIRST=$R215_FIRST R215_LAST=$R215_LAST awk '
         $0 == ENVIRON["R215_FIRST"] { on = 1 }
         on { print }
         on && $0 == ENVIRON["R215_LAST"] { exit }' "$R215_MUT" | cksum)"
# The line after the log's last has to be bare, `#` and blanks only, or nothing
# is reported; the one after that is read through comment_reflow and cut to the
# length of the literal it is compared with.
R215_NEXT='WHAT A MUTATION IS.'
R215_BELOW=$(R215_LAST=$R215_LAST awk '
  n == 1 { if ($0 !~ /^#[ \t]*$/) exit; n = 2; next }
  n == 2 { print; exit }
  $0 == ENVIRON["R215_LAST"] { n = 1 }' "$R215_MUT" | comment_reflow)
tok 'nothing is appended after it: the paragraph below it is the rule WHAT A MUTATION IS' \
    "$R215_NEXT" "${R215_BELOW:0:${#R215_NEXT}}"
# THE FREEZE PARAGRAPH is the paragraph before the log's first line, read
# through comment_reflow. The line directly above the first has to be bare, `#`
# and blanks only, or nothing is reported. The paragraph's claims below are asked
# of this text and not of the whole header, so a claim moved into any other
# paragraph is red; and they are asked of it joined, because a phrase this long
# crosses a line break wherever the wrap falls.
R215_FREEZE=$(R215_FIRST=$R215_FIRST awk '
  $0 == ENVIRON["R215_FIRST"] { if (bare) printf "%s", last; exit }
  /^#[ \t]*$/ { last = cur; cur = ""; bare = 1; next }
  { cur = cur $0 "\n"; bare = 0 }' "$R215_MUT" | comment_reflow)
R215_OPENS='THE RUN LOG BELOW IS FROZEN, AT #215,'
tok 'nor before it: the paragraph above it is the one that freezes it' \
    "$R215_OPENS" "${R215_FREEZE:0:${#R215_OPENS}}"
# Each literal is one whole sentence of the freeze paragraph, or its whole
# clause.
holds 'the freeze paragraph says the run log is frozen at #215' "$R215_FREEZE" \
  'THE RUN LOG BELOW IS FROZEN, AT #215, and nothing is appended to it.'
holds 'and names the lines it runs from and to, by their text' "$R215_FREEZE" \
  'from the line that opens `MEASURED, 2026-09-17, at the commit that answered that review` to the line that ends `the registry is re-runnable instead.`,'
holds "and says its present tense is #215's and no later tree's" "$R215_FREEZE" \
  "Its present tense is #215's: a row it says has not been run since, or a whole-registry run it says nothing has made, is a claim about the tree at #215 and about no later one."
holds 'and says a later run is recorded in the dev-log of the session that ran it' "$R215_FREEZE" \
  'A RUN AFTER #215 IS RECORDED IN THE DEV-LOG OF THE SESSION THAT RAN IT, under docs/dev-log/, whose README states the conventions -- never here.'

# THE REST OF THE FILE, with the log cut out by the same two lines. With the
# last line gone nothing after the first is read, which the header's closing
# words below say. Dates are counted on every line of the file; the phrases are
# asked of the header's prose, to `set -u`, joined.
R215_REST_LINES=$(R215_FIRST=$R215_FIRST R215_LAST=$R215_LAST awk '
  $0 == ENVIRON["R215_FIRST"] { off = 1 }
  !off { print }
  off && $0 == ENVIRON["R215_LAST"] { off = 0 }' "$R215_MUT")
R215_REST=$(printf '%s\n' "$R215_REST_LINES" | sed -n '1,/^set -u$/p' | comment_reflow)
holds 'outside the log, the header is read to its last paragraph' "$R215_REST" \
  'the documents it is judged against stay this repository'
tok 'and outside the log the harness carries six dates, none of them a record of a run' \
    '6' "$(printf '%s\n' "$R215_REST_LINES" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | grep -c '')"
lacks "and the header outside the log does not say a run left the hooks byte-identical after" \
  "$R215_REST" 'byte-identical after'
lacks 'nor that rows were run as a selection' "$R215_REST" 'selection'
lacks 'nor that a baseline was green' "$R215_REST" 'baseline green'
tok 'and says baseline plus once, in the rule on what naming rows costs, and in no record' \
    '1' "$(printf '%s' "$R215_REST" | grep -oF 'baseline plus' | grep -c '')"

sourced_to_end

#!/bin/bash
# Re-runs the mutation claims check-hooks.sh makes about itself. Issue #107.
#
# That suite's header says a rule was "mutation-checked" in about two dozen
# places -- "each was mutation-checked: weakening the dev-NN test, dropping the
# missing-base refusal ... each turn a named group of them red", "three
# historical defects were re-introduced in lib/command-scan.sh, one at a time".
# Every one of those runs happened by hand, against a harness that no longer
# exists, at a commit that has moved. None of them could be re-run, and CLAUDE.md
# says of this repository that several suites "have been green for the wrong
# reasons". A mutation claim nobody can re-run is a claim to re-measure, not
# evidence. This file is where the re-running happens.
#
# Run:  bash .claude/hooks/mutate-hooks.sh            every registered mutation
#       bash .claude/hooks/mutate-hooks.sh --list     the registry, and nothing run
#       bash .claude/hooks/mutate-hooks.sh -v <id>... one or more by id, verbosely
#
# TWO MINUTES A ROW, and hours for the whole registry: one check-hooks.sh run
# per mutation that applies, plus the baseline -- sixty-seven runs as the registry
# stands, not sixty-eight, because the row whose edit matches nothing never reaches
# one. Measured twice on 2026-09-17, on this machine and on registries one row
# apart: 47 min 34 s and 45 min 24 s, at twenty-three runs. That measurement is
# the two minutes, and the two minutes is what is written in the heading, because
# review of PR #169 found the heading saying ABOUT AN HOUR while this paragraph
# said ninety minutes and check-hooks.sh pinned the hour: a total goes stale
# every time a row is added and a rate does not. Carried to sixty-seven runs the
# rate gives nearer two hours than one, and no third whole-registry measurement has been
# taken; a run under load took nearer four minutes a row. That is why it
# is a separate script and why check-hooks.sh does not call it (#107). Nothing
# here is a PreToolUse hook and settings.json does not register it. Naming rows
# costs the baseline plus one run each, so re-asking a single rule is about four
# minutes rather than the whole registry.
#
# EXIT STATUS: non-zero when any row reports something other than the outcome it
# declares. For every real mutation that means a survivor or an edit that did not
# apply; for the two self-tests it means the opposite, since a run in which they
# were caught would say this harness reports `caught` for something it cannot
# have established.
#
# ONLY A SELF-TEST MAY DECLARE ANYTHING BUT `caught`, and the id is what says a
# row is one. Without that tie the fifth field was also the way to silence a real
# survivor: declare `survived` and the row reported ok, the counts in
# check-hooks.sh's #107 section still held, and this harness exited 0 with a
# registered mutation alive. The header used to argue that no spelling could
# leave the exit status at 0 for a self-test and non-zero for a real row; there
# is one, this is it, and it was Bertan's review of PR #142 that found the gap.
# Both self-tests are additionally required to be present, one of each outcome.
#
# MEASURED, 2026-09-17, at the commit that answered that review: all twenty-three
# rows as the registry then stood reported what they declare, and .claude/hooks/
# came back byte-identical.
#
# THAT MEASUREMENT IS NOT CURRENT, and saying so is the point of this paragraph.
# Four selections have been run since, each naming its own rows and none part of
# a whole-registry run. #108 added six rows and ran them as a named selection:
# baseline plus six, all caught, .claude/hooks/ byte-identical after. #128 added
# three and ran them the same way, baseline plus three, all caught with GH-128
# red. #133 added `retarget-refusal-drops-the-retarget-spelling` and
# `retarget-refusal-drops-the-create-comparison` and ran the pair the same way,
# both caught, byte-identical after; it also edited no-pr-decisions.sh,
# check-hooks.sh and this file, so three of the files that run changed after the
# figure above was taken. #117 added five, and on the merge of dev-05 into it
# (2026-09-18) the sixteen rows added since that measurement -- #117's, #108's,
# #128's and #133's -- were run as one selection: baseline plus sixteen, all
# caught, byte-identical after. #141 added two, `variants-field-deleted` and
# `variants-seed-disowned`, and on the second merge of dev-05 into it
# (2026-09-18) ran that pair as a selection against the merged tree: baseline
# plus two, both caught with GH-141 red, byte-identical after. #139 added three,
# `quoted-base-flag-permitted`, `quoted-base-value-refused` and
# `quoted-shorthand-value-refused`, and ran them as a selection (2026-09-19):
# baseline plus three, all caught with GH-139 red, byte-identical after; it also
# edited no-pr-decisions.sh and check-hooks.sh. Bertan's review of PR #173 added
# `ansi-hex-escape-not-decoded` and `open-quote-holds-no-newline`, and the five
# #139 rows were run again as one selection against the answering commit. Its
# second review added `nul-decoded-as-a-character` and
# `nul-cut-span-keeps-its-newline`, and all seven #139 rows were run as one
# selection against the commit answering it. Its third review added
# `c-escape-takes-the-next-character` and moved the edit of
# `nul-cut-span-keeps-its-newline` onto the line that now refuses. The eight
# #139 rows were run as one selection against the answering commit, and
# `open-quote-holds-no-newline` reported did-not-apply: the second review had
# written its edit against `if (st && !cut)`, which the third removed. Its edit
# was re-anchored and it was run alone, caught; the other seven were caught in
# the selection, and .claude/hooks/ was byte-identical after both runs. The
# fourth review added `empty-span-read-as-value` and
# `cut-span-at-line-end-always-refused`, re-anchored
# `quoted-shorthand-value-refused` and `nul-cut-span-keeps-its-newline` on the
# lines it rewrote, and all ten #139 rows were run as one selection against
# the answering commit. The fifth added `quoted-equals-read-as-value` and
# re-anchored `quoted-base-value-refused`, and all eleven #139 rows were run as
# one selection against the commit answering it. #144 added five,
# `base-pattern-admits-main` being a re-anchoring of an existing row onto the
# function it renamed, and on the merge of dev-05 into it the second review of
# PR #158 added `base-refusal-drops-the-fetch-remedy`. All seven were run as one
# selection against the merged tree, and SIX were caught: the seventh,
# `base-pattern-admits-main`, survived, for the reason written out under TWO
# ROWS FOR ONE CLAIM above. It was narrowed and `base-admits-main-outright`
# added beside it, and the two were run as a selection of their own against the
# commit answering that; both caught, .claude/hooks/ byte-identical after each
# run. The survivor is the argument for re-running a selection after a merge
# instead of carrying its pre-merge verdicts forward: nothing else in the suite
# reported it, the row having been green before the merge and its verdict
# unchanged by it. That merge also rewrote check-hooks.sh, no-pr-decisions.sh,
# requirements.md and this file, so every row not in those two selections runs
# against files that have changed since it was last measured.
# #155 added two. `pr-hook-reads-gh-off-the-environment` was run as a selection
# on 2026-09-17: baseline plus one, caught, byte-identical after, and red in
# GH-108.6 and in nothing else ON A HOST THAT HAS `gh`. That last clause is the
# one PR #161's review asked for and it is not decoration. The edit inserts
# `command -v gh || exit 0` ABOVE the first rule in the file, so on a `gh`-less
# host -- the machine #155 was filed about -- it short-circuits `pr review`,
# `pr close`, the release allowlist, the base rules and the api rules as well,
# and the run goes red across dozens of requirements. The outcome is `caught`
# either way, since that is read off the IDs the row names and is not exclusive,
# so nothing in this harness turns red to say so. The exclusivity is recorded as
# this host's rather than repaired by moving the anchor: a hook that reads `gh`'s
# presence out of the environment reads it before it decides anything, so a row
# anchored below the rules it disables would be a different and weaker mutation
# wearing the same name. `report-reads-gh-before-git` was run the same way on
# 2026-09-18, at the commit answering that review: baseline plus one, caught,
# red in GH-155.1 and in nothing else, byte-identical after. That one is host-
# independent -- its `gh --version` is silent where there is no `gh` to run and
# harmless where there is.
# #109 added four -- a pass slowed past the 1 s bound on a long command, two
# refusal messages losing the sentence their rows read, and a second hook
# refusing a permitted read -- and ran them as a named selection on 2026-09-18,
# before dev-05 carried #117: baseline green over 183 requirements, all four
# caught, .claude/hooks/ byte-identical after. Its settings.json mutations
# cannot be rows here, the file being outside the copy; they were run by hand
# and are recorded in #109's section of check-hooks.sh. The first review of
# PR #169 re-ran the four against its answering commit (2026-09-20), all four
# caught and byte-identical after, and re-ran one of the by-hand six, the `ran`
# record switched off, which was caught in eleven places. Its second review
# found two message rules the suite stated and did not check, and #109 added
# four rows for them -- `base-refusal-drops-the-rule-sentence`,
# `base-refusal-drops-the-remedy-spelling`,
# `push-refusal-stops-opening-with-the-rule` and
# `a-new-refusal-arm-nothing-reads` -- run as one selection against the commit
# answering it (2026-09-20): baseline green over 187 requirements, all four
# caught, .claude/hooks/ byte-identical after. The first two survived the suite
# before that commit, which is how the review found them and why they are rows
# rather than a paragraph. That selection was run before dev-05 was merged in a
# second time, at 2a52322, so it was re-run against the merged tree: baseline
# green over 188 requirements, all four caught again, .claude/hooks/
# byte-identical after. Its third review pointed out that
# `push-refusal-stops-opening-with-the-rule` deletes the constant and so
# proves a deletion, where the rows it backs claim an ORDER, so
# `push-refusal-moves-the-rule-to-the-end` was added -- it keeps the constant
# and puts it last, which a containment check cannot tell from the right order
# -- and run alone against the commit answering that review (2026-09-20):
# baseline green over 188 requirements, caught, byte-identical after. Its
# fourth review found `arms` counting lines rather than occurrences, so a
# second arm sharing a line with an existing one moved nothing;
# `a-new-refusal-arm-sharing-a-line` is that mutant, run alone the same way
# against the commit answering it: baseline green over 188 requirements,
# caught, byte-identical after. Its fifth review found three refusal sentences
# the suite read only by their prefix -- one of the two `no base is named`
# arms, and both load guards -- and the three rows for them,
# `one-of-two-no-base-arms-loses-its-sentence`,
# `push-load-guard-drops-what-it-cannot-tell` and
# `decision-load-guard-drops-what-it-cannot-tell`, were run as one selection
# against the commit answering it: baseline green over 188 requirements, all
# three caught, byte-identical after. The first of them is anchored on a range
# rather than on its own text, because the sentence it deletes is written
# twice in that file and deleting both is a different mutation. #155's two
# rows have still not been run since that merge, and neither has anything
# else here -- except that #144's selection below did run #155's two against the
# merged tree, which is the later measurement and the one that stands.
#
# BOTH WERE RUN AGAIN on the merge of dev-05 (#155) into #144, in a selection of
# twelve: #155's two, #144's eight, and GH-144.8's two, against the merged tree
# at the commit that resolved it. All twelve caught, .claude/hooks/
# byte-identical after, and `pr-hook-reads-gh-off-the-environment` still red in
# GH-108.6 and in nothing else -- this host having `gh`, which is the clause
# above. That row is the one the merge put at risk and the reason the selection
# was chosen: #144 narrowed what the GH-108.6 section claims, from a verdict in
# every environment to every refusal made on a command's text, while #155
# registered this row against that same requirement. The narrowing did not cost
# the row its evidence. Said plainly because the previous merge's selection
# found the opposite and the two are only distinguishable by running them.
#
# GH-144.8's three rows were run on the fourth review of PR #158, and the third
# of them is why there are three. `report-omits-the-skipped-fetch-clause` deletes
# one clause of the six the requirement claims, and it SURVIVED the two `written`
# pins first written for those sites: `written` is `grep -qF` over a whole file,
# so a literal standing at six sites is still there when one is deleted. The row
# is what said so -- the pins read as evidence and were none -- and the answer was
# to derive the sites rather than pin the literal. All three caught after that,
# .claude/hooks/ byte-identical. A row written for a claim and run against it is
# the only thing that told the two apart.
# No run has therefore exercised all sixty-seven rows together, and saying which
# rows a measurement covered is the
# whole point of recording one. A reader who wants "the whole registry, at this commit" has to
# run it -- which is the answer #107 built rather than a gap, and is why the
# sentence this replaced, claiming the only later edit was to this comment, was
# worth catching. Bertan's two reviews of PR #147, and two merges of dev-05 into
# it.
#
# TWO ROWS FOR ONE CLAIM, #144's, and it is #128's overlap one rule out. Until
# #144 the dev-NN pattern was the whole of the base rule, so
# `base-pattern-admits-main` -- admitting main to that pattern -- permitted a
# pull request into main and turned every check of that refusal red. #144 put a
# second question behind it, and MEASURED against the merged tree that row
# SURVIVED: with the pattern admitting main, `gh pr create --base main` is still
# refused here, because main is not the branch origin holds highest. Driven by
# hand in both states to be sure it was the mechanism and not the fixture: exit
# 2 in this repository, exit 0 in a fixture with no dev ref, where the pattern
# is the whole rule again.
#
# So the row no longer establishes what its requirement list claimed. It is
# narrowed to what it does establish -- the refusals that change their WORDING
# here, and GH-144.2, whose no-dev-ref rows are exactly where the pattern is
# still load-bearing -- and `base-admits-main-outright` carries the full list by
# breaking the thing that now decides, main accepted before either question is
# asked. Neither row alone reproduces "a pull request into main is permitted"
# in a repository with a dev ref, which is the state this one is in.
#
# WORTH SAYING PLAINLY, because it is a consequence of #144 nobody wrote down:
# the dev-NN shape test is no longer load-bearing for main wherever a dev ref
# can be read. That is defence in depth and the verdict is unchanged, but it
# means the evidence those five requirements rested on had quietly moved, and
# only a mutation run says so. Found by re-running #144's rows against the
# merged tree rather than carrying their pre-merge verdicts forward.

# THREE ROWS FOR ONE FIX, #128's, which is a departure from a row per rule and is
# here because the rules overlap. `heredoc-opener-parity` loosens the parity test
# to the rule cs_join uses, which is the defect review of PR #151 found in the
# first version of that fix; `heredoc-boundary-run-kept` stops the drop taking
# the trailing run off the line a body starts after. Each is caught, and NEITHER
# reproduces the defect the issue was filed for: on an odd run the two mechanisms
# cover the same case, so breaking one leaves the other holding it. That case
# needs both broken, which is `heredoc-opener-continuation`, the one row here
# whose edit is two commands -- and it puts the pass back to what dev-05 did,
# measured: 151 checks red, and the bash differential from 0 hidden pushes to
# 198, which is dev-05's figure exactly. No
# per-mutation counts are recorded here on purpose -- a count in a comment is the
# thing #107 was filed about, and the registry is re-runnable instead.
#
# WHAT A MUTATION IS. One row of the registry below, five fields separated by
# `%`:
#
#   <id> % <file, relative to the hooks directory> % <sed expression>
#        % <the requirement IDs whose checks must go red> % <expected outcome>
#
# The fourth field is what makes this a check rather than a measurement: a
# mutation is CAUGHT only when EVERY requirement ID named there has at least one
# failing check in that run's matrix. A run that goes red somewhere else entirely
# is not this mutation being caught -- it is the suite noticing something, which
# is not what the row claims. The fifth field says what this harness must then
# report.
#
# A MUTATION THAT DOES NOT APPLY IS A FAILURE, reported as loudly as a survivor
# and never as a pass. If the `sed` leaves the file byte-identical, the run that
# follows would be a green run of an unmutated copy, which reads exactly like
# evidence and is none. This is #84's lesson one level out -- there, a question
# asked of two hooks of four; here, an edit whose anchor a rename has moved.
# It is not hypothetical: two of the mutations recorded in check-hooks.sh's #106
# section did not apply on their first attempt, and each run was green for that
# reason rather than the one it claimed.
#
# THE REPOSITORY'S HOOKS ARE NEVER EDITED. Every mutation is applied to a fresh
# copy under a temporary directory, made again from scratch for each row rather
# than reverted -- `git checkout --` in a throwaway harness eats whatever else is
# uncommitted, and a hand-written revert is one more thing that can silently not
# apply. This script refuses to start if that working copy resolves to
# .claude/hooks/ itself, and it checksums .claude/hooks/ before and after the
# whole run and fails if a byte moved.
#
# THE BASELINE RUN, and why it comes first. An unmutated copy has to be green.
# If it is not -- a file left out of the copy, an override pointed at the wrong
# place, a repository whose suite is already red -- then every mutation after it
# turns something red for that reason, and this harness would report a registry
# full of caught mutations while establishing nothing whatever. That is its own
# permitting direction, and the baseline is the check on it. The registry is
# validated before the baseline is run, so a mistyped id or a malformed row costs
# nothing rather than 95 s.
#
# WHAT A GREEN RUN HERE IS NOT EVIDENCE OF. The registry is a list someone wrote,
# so this is evidence about the mutations it names and about nothing else -- the
# same sentence check-hooks.sh's header makes about its checks, and it is no
# weaker here. `caught` says some check tagged with that requirement went red; it
# does not say the RIGHT check went red, and nothing here can say that.
#
# WHAT IS REGISTERED, counted rather than characterised, because the sentence
# that characterised it ("the rules that gained checks under #103") claimed the
# whole of two issues and named eight rows -- and the count that replaced it was
# itself wrong, in four documents, until Bertan's review of PR #142 measured it.
# The counts below are what `--list` prints, and nothing here restates them in
# prose a second time:
#
#   SIXTY-TWO real mutations, against SEVEN files in .claude/hooks/, naming
#   FIFTY-TWO requirement IDs between them, of the 173 whose status is active.
#
# Those four numbers are restated prose in a file whose own argument, three
# paragraphs up, is that a count in a comment is the thing #107 was filed about.
# They had been wrong or moved six times in three days when #148 was filed to
# take them out and let `--list` be the only place they are written; #139 moved
# them eight more times, and #109's merge of dev-05 moved all four again. The
# heading three paragraphs up stopped being one of them on the same merge, for
# the same reason: see there.
#
# What that leaves out, so that nobody has to infer it: every requirement whose
# verify is `review` or `runbook` rather than a check here, every doc-claim about
# a file outside .claude/hooks/, and the rest of the invariance families #106
# seeded, which are covered by checks but have no row of their own. One mutation
# per functional requirement is the backlog item in docs/todo.md, deferred by
# #103 Q8 when the harness was specified, and #108 and #109 register theirs when
# they land.
#
# WHAT CANNOT BE REGISTERED HERE AT ALL, which is a limit of the design and not
# of the list:
#
#   - a rule that lives in the tooling beside the hooks: check-hooks.sh, and this
#     file. The suite that runs is this repository's, whatever CHECK_HOOKS_DIR
#     says, and so is the harness -- so an edit to either copy would be read by
#     the suite's own text checks and executed by nothing, and `caught` would be
#     reported for a file that never ran. Both are refused below, by name, from
#     one list. #106's six self-guards -- a transformation that applies to no
#     seed, a departure row naming a seed that is not there -- are all of that
#     kind, and #104's coverage machinery is too.
#
#     The seventh file is the exception that shows where the line actually
#     falls, and it is worth reading before the next row is written. GH-141's
#     rule is CODE in check-hooks.sh and so cannot be mutated -- but what that
#     code READS is requirements.md, which an override does move. So the rule is
#     reachable through its input: the two `variants-*` rows edit an entry in
#     the copy and the suite, running from here, reads the copy and goes red.
#     The test is not "whose file is it" but "does the run read the copy".
#     Nothing about #106's own self-guards is reachable that way, because what
#     they read is the seed table, which lives in the suite.
#   - a claim about a file outside .claude/hooks/. Only the hooks directory is
#     copied, and CLAUDE.md, CONTEXT.md, settings.json and the two skills are
#     read from this repository whatever is being judged, so a mutation to one of
#     them would be a mutation to the working tree. Several of #105's doc-claims
#     are of that kind.
#
# Both limits are the same decision seen from two sides, and the decision is
# check-hooks.sh's: what an override moves is what is judged, and the documents
# it is judged against stay this repository's.
set -u

SRC=$(cd "$(dirname "$0")" 2>/dev/null && pwd) || {
  echo "mutate-hooks.sh: cannot resolve its own directory" >&2; exit 1
}
SUITE="$SRC/check-hooks.sh"
[ -r "$SUITE" ] || {
  echo "mutate-hooks.sh: $SUITE is not there, so there is no suite to run" >&2; exit 1
}

# The files beside the hooks that are not hooks. check-hooks.sh keeps the same
# list under the same name, where the two directories are split, and its registry
# audit holds this table to it. Neither file is ever executed out of the copy, so
# neither can be a mutation target.
TOOLING="check-hooks.sh mutate-hooks.sh"

VERBOSE=
LIST=
SELECTED=
for arg in "$@"; do
  case "$arg" in
    -v|--verbose) VERBOSE=1 ;;
    --list) LIST=1 ;;
    -*) echo "usage: bash .claude/hooks/mutate-hooks.sh [--list] [-v] [<id>...]" >&2; exit 64 ;;
    *) SELECTED="$SELECTED $arg" ;;
  esac
done

# THE REGISTRY. Grouped by the rule each mutation breaks, and every row's fourth
# field was read off a run of this harness and then written here as a literal --
# the expectation is what this file says, never what the next run happens to
# print.
#
# `%` is the field separator, and no field below contains one; a row that does
# not split into five non-empty fields stops the run rather than being read
# half-way. The sed expressions are anchored on text rather than on line numbers,
# because a line number is the anchor that goes stale first -- and when the text
# moves instead, the edit does not apply and this harness says so.
MUTATIONS=$(cat <<'MUTATIONS'
sudo-not-a-wrapper%lib/command-scan.sh%/^CS_WRAP_OPTION_WORDS=/s/sudo|//%FR-4 US-15 US-1 GH-79.1%caught
nohup-not-a-wrapper%lib/command-scan.sh%/^CS_WRAP_OPTION_WORDS=/s/nohup|//%FR-4 US-15 GH-79.1%caught
control-words-not-stripped%lib/command-scan.sh%s/\[{}!\]|if|then|elif|else|fi|while|until|for|do|done|case|esac|select|function|coproc/cs-matches-no-control-word/%FR-3 US-1 US-15%caught
gh-issue-refused%no-pr-decisions.sh%s/^if gh_rule 'pr merge'; then$/if gh_rule issue || gh_rule 'pr merge'; then/%US-14%caught
gh-issue-two-verbs-refused%no-pr-decisions.sh%s/^if gh_rule 'pr merge'; then$/if gh_rule 'issue delete' || gh_rule 'issue transfer' || gh_rule 'pr merge'; then/%US-14%caught
pr-read-refused%no-pr-decisions.sh%s/^if gh_rule 'pr merge'; then$/if gh_rule 'pr view' || gh_rule 'pr comment' || gh_rule 'pr merge'; then/%US-13%caught
base-refusal-drops-the-spelling%no-pr-decisions.sh%/^BASE=/s/Write: gh pr create --base dev-NN/Name a base/%US-7 FR-23%caught
retarget-refusal-drops-the-retarget-spelling%no-pr-decisions.sh%s/ Retarget to the active dev branch instead: gh pr edit <n> --base dev-NN\.//%US-7 FR-23 GH-133%caught
retarget-refusal-drops-the-create-comparison%no-pr-decisions.sh%s/ just as creating it there would//%FR-23%caught
base-pattern-admits-main%no-pr-decisions.sh%/^may_propose_into()/,/^}/s/\^dev-\[0-9\]+\$/^(dev-[0-9]+|main)$/%FR-15 FR-16 FR-18 GH-144.2%caught
base-admits-main-outright%no-pr-decisions.sh%s/^may_propose_into() {$/may_propose_into() {\n  case "$1" in main) return 0 ;; esac/%FR-15 FR-16 FR-17 FR-18 FR-19 US-8 US-10 US-11%caught
pr-create-base-not-read%no-pr-decisions.sh%s/if RAW=$(cs_gh_args 'pr create' <<<"$CMD"); then/if false \&\& RAW=$(cs_gh_args 'pr create' <<<"$CMD"); then/%FR-14 FR-16 US-9%caught
web-handoff-refused%no-pr-decisions.sh%/^gh_pr_web()/,/^}/s/--web|-w) return 0 ;;/--web|-w) return 1 ;;/%FR-21 US-12%caught
quoted-base-flag-permitted%no-pr-decisions.sh%/^quoted_base_flag()/,/^}/s/END { exit found ? 0 : 1 }/END { exit 1 }/%GH-139%caught
quoted-base-value-refused%no-pr-decisions.sh%/^quoted_base_flag()/,/^}/s/ \&\& q <= length("--base") + (w ~ \/^--base=\/))/)/%GH-139%caught
quoted-equals-read-as-value%no-pr-decisions.sh%/^quoted_base_flag()/,/^}/s/ + (w ~ \/^--base=\/))/)/%GH-139%caught
quoted-shorthand-value-refused%no-pr-decisions.sh%/^quoted_base_flag()/,/^}/s/if ((q \&\& q <= b)/if ((q/%GH-139%caught
ansi-hex-escape-not-decoded%no-pr-decisions.sh%/^quoted_base_flag()/,/^}/s/if (e == "x") {/if (0) {/%GH-139%caught
open-quote-holds-no-newline%no-pr-decisions.sh%/^quoted_base_flag()/,/^}/s/if (st) w = w "\\n"; //%GH-139%caught
nul-decoded-as-a-character%no-pr-decisions.sh%/^quoted_base_flag()/,/^}/s/if (v == 0) { if (!cut) { cut = 1; cutw = w } } else w = w chr(v)/w = w chr(v)/%GH-139%caught
nul-cut-span-keeps-its-newline%no-pr-decisions.sh%/^quoted_base_flag()/,/^}/s/if (cut) { if (/if (0) { if (/%GH-139%caught
empty-span-read-as-value%no-pr-decisions.sh%/^quoted_base_flag()/,/^}/s/ || (qe \&\& qe <= length("--base") + 1)//%GH-139%caught
cut-span-at-line-end-always-refused%no-pr-decisions.sh%/^quoted_base_flag()/,/^}/s/if (w == "" || (w ~ \/^-\/ \&\& w !~ \/\[\[:space:\]\]\/))/if (1)/%GH-139%caught
c-escape-takes-the-next-character%no-pr-decisions.sh%/^quoted_base_flag()/,/^}/s/if (e == "c") { put(0); return }/if (e == "c") { if (i < n) i++; w = w "?"; return }/%GH-139%caught
api-read-taken-for-a-write%no-pr-decisions.sh%/^gh_api_is_write()/,/^}/s/^  return 1$/  return 0/%FR-20%caught
release-allowlist-admits-a-write%no-pr-decisions.sh%/^RELEASE_READ_VERBS=/s/verify-asset"/verify-asset create edit delete"/%FR-48%caught
bare-push-refusal-drops-the-branch%no-git-push.sh%/Name the branch: git push/s/git push <remote> \$CURRENT/git push <remote> <branch>/%US-7%caught
stopping-rule-removed%no-git-push.sh%/would plausibly write/d%US-20 FR-2%caught
main-checkout-not-recognised%no-git-push.sh%s/^if \[ "$GIT_DIR_PATH" = "$GIT_COMMON_PATH" \]; then$/if false; then/%GH-94.1%caught
worktree-may-push-the-branch-it-stands-on%no-git-push.sh%/^if \[ "$CURRENT" = "main" \]/s/^.*$/if false; then/%US-1 US-2%caught
any-branch-pushable%no-git-push.sh%/^names_this_branch()/,/^}/s/\*) return 1 ;;/*) return 0 ;;/%US-3%caught
own-branch-push-refused%no-git-push.sh%/^names_this_branch()/,/^}/s/") return 0 ;;/") return 1 ;;/%US-4%caught
library-loaded-unguarded%no-git-push.sh%$a. "$(dirname "$0")/lib/command-scan.sh"%GH-84.2%caught
merged-branch-not-gone%no-work-on-stale-branch.sh%s/= "\[gone\]"/= "never-this-string"/%FR-38%caught
bare-pytest-permitted%pytest-via-uv-group.sh%s/grep -qE '\^(pytest|/grep -qE '^(no-such-tool-at-all|/%GH-69.1%caught
unresolved-git-dir-permits%no-git-push.sh%/could not be resolved, so whether this runs/,+1s/exit 2/exit 0/%GH-108.2%caught
dev-branch-not-version-sorted%no-work-on-stale-branch.sh%s/| sort -V | tail -1)/| sort | head -1)/%GH-108.5%caught
base-lookup-never-finds-a-branch%no-pr-decisions.sh%/^read_active_dev()/,/^}/s/origin\/dev-\*/origin\/no-such-ref-\*/%GH-144.1 GH-144.3%caught
base-lookup-not-version-sorted%no-pr-decisions.sh%/^read_active_dev()/,/^}/s/| sort -V | tail -1)/| sort | head -1)/%GH-144.1 GH-144.3%caught
base-lookup-admits-any-dev-ref%no-pr-decisions.sh%/^read_active_dev()/,/^}/s/| grep -E '\^origin\/dev-\[0-9\]+\$' //%GH-144.1%caught
base-lookup-refuses-when-it-cannot-read%no-pr-decisions.sh%/^may_propose_into()/,/^}/s/\[ -n "$ACTIVE_DEV" \]/[ -n "no such branch" \]/%GH-144.2 GH-108.5%caught
report-omits-the-base-hook-where-no-ref-is-read%report-stale-branches.sh%/no-pr-decisions.sh accepts any dev-NN base/d%GH-144.8%caught
report-omits-the-skipped-fetch-clause%report-stale-branches.sh%/staleness detector in no-work-on-stale-branch.sh is armed, and/,+1{/no-pr-decisions.sh accepts any dev-NN base/d}%GH-144.8%caught
report-omits-the-base-hook-on-a-failed-fetch%report-stale-branches.sh%/request's base against whatever branch those refs still call active/d%GH-144.8%caught
base-refusal-drops-the-fetch-remedy%no-pr-decisions.sh%s/ If the dev branch has rotated since this session last fetched, run git fetch and try again\.//%GH-144.7%caught
base-lookup-read-once-per-base%no-pr-decisions.sh%/^read_active_dev()/,/^}/s/\[ -z "$ACTIVE_DEV_READ" \] || return 0/:/%GH-144.5%caught
tool-name-must-be-bash%lib/command-scan.sh%s/if length == 1 and/if length == 1 and (.[0].tool_name == "Bash") and/%GH-108.1%caught
hook-exits-a-third-status%pytest-via-uv-group.sh%s/^exit 0$/exit 3/%GH-108.8%caught
report-exits-without-saying-why%report-stale-branches.sh%/^  echo "branches: NOT READ -- git is not on PATH/d%GH-108.9%caught
degraded-report-hides-a-failed-fetch%report-stale-branches.sh%/^    echo "fetch: FAILED or timed out after /d%GH-108.10%caught
pr-hook-reads-gh-off-the-environment%no-pr-decisions.sh%s#^if gh_rule 'pr merge'; then$#command -v gh >/dev/null 2>\&1 || exit 0\nif gh_rule 'pr merge'; then#%GH-108.6%caught
report-reads-gh-before-git%report-stale-branches.sh%s#^if ! command -v git >/dev/null 2>&1; then$#gh --version >/dev/null 2>\&1\nif ! command -v git >/dev/null 2>\&1; then#%GH-155.1%caught
variants-field-deleted%requirements.md%/^- variants: transformation: redirect-quoted$/d%GH-141%caught
variants-seed-disowned%requirements.md%/^### GH-72$/,/^$/s/^- variants: seed$/- variants: none: a reason/%GH-141%caught
heredoc-opener-continuation%lib/command-scan.sh%/if (p) { print; next }/d;/if (r > 0) sub/d%GH-128%caught
heredoc-opener-parity%lib/command-scan.sh%s|if (p) { print; next }|if (r) { print; next }|%GH-128%caught
heredoc-boundary-run-kept%lib/command-scan.sh%s|if (r > 0) sub|if (0) sub|%GH-128%caught
command-word-not-reduced%lib/command-scan.sh%s/^      w = substr(s, 1, i - 1)$/      w = "x"/%GH-117%caught
wrapper-word-spelling-not-admitted%lib/command-scan.sh%s/SPELLING((ba|z|)sh/((ba|z|)sh/%GH-117%caught
prefix-word-spelling-not-reduced%lib/command-scan.sh%s/return cw_name(w)/return w/%GH-117%caught
wrapper-surface-quotes-not-admitted%no-pr-decisions.sh%/^GH_SURFACE_ANYWHERE=/s/\["'"'"'\]\*gh\["'"'"'\]\*/gh/%GH-117%caught
the-close-117-rejected%lib/command-scan.sh%s/SPELLING((ba|z|)sh/SPELLING(\\\\$\\\\(|(ba|z|)sh/%GH-117.1%caught
long-command-outlasts-the-bound%no-git-push.sh%/^CMDS=\$(printf/a [ "$(echo "$COMMAND" | wc -l)" -gt 100 ] && sleep 1.1%GH-109.1%caught
forced-push-refusal-drops-the-remedy%no-git-push.sh%s/ Add a commit instead\.//%US-7 GH-109.2%caught
decision-refusal-drops-what-stays-allowed%no-pr-decisions.sh%/^DECIDE=/s/ Opening a PR, commenting on it and editing it are allowed;//%US-7 GH-109.2%caught
second-hook-refuses-a-permitted-read%alembic-via-uv-group.sh%/^CMDS=\$(printf/a echo "$CMDS" | grep -q '^gh pr view' && exit 2%GH-109.5%caught
base-refusal-drops-the-rule-sentence%no-pr-decisions.sh%/^BASE=/s/a pull request may be proposed only into the active dev branch, and the base has to be named in the command. //%US-7 FR-23 GH-109.2%caught
base-refusal-drops-the-remedy-spelling%no-pr-decisions.sh%/^BASE=/s/ --title \.\.\. --body \.\.\.//%US-7 FR-23 GH-109.2%caught
push-refusal-stops-opening-with-the-rule%no-git-push.sh%s/echo "\$REFUSE That is a forced push/echo "That is a forced push/%US-7 GH-109.2%caught
a-new-refusal-arm-nothing-reads%no-git-push.sh%/^CMDS=\$(printf/a >\&2 echo "Blocked: an arm with no says row above it."%GH-109.2%caught
push-refusal-moves-the-rule-to-the-end%no-git-push.sh%s/"\$REFUSE That is a forced push, which rewrites history the open pull request is showing. Add a commit instead."/"That is a forced push, which rewrites history the open pull request is showing. Add a commit instead. \$REFUSE"/%US-7 GH-109.2%caught
a-new-refusal-arm-sharing-a-line%no-git-push.sh%/A wildcard refspec does not name this branch/s/$/; echo "Blocked: a second arm sharing a line." >\&2/%GH-109.2%caught
one-of-two-no-base-arms-loses-its-sentence%no-pr-decisions.sh%/This names \$BAD_BASE/,+6s/, so this would go to the repository.s default branch//%US-7 GH-109.2%caught
push-load-guard-drops-what-it-cannot-tell%no-git-push.sh%s/, so it cannot tell whether this command pushes, or where to//%US-7 GH-84.1 GH-109.2%caught
decision-load-guard-drops-what-it-cannot-tell%no-pr-decisions.sh%s/, so it cannot tell whether this command decides a pull request or a release//%US-7 GH-84.1 GH-109.2%caught
selftest-anchor-that-matches-nothing%lib/command-scan.sh%s/CS_NO_SUCH_VARIABLE_IS_DEFINED_HERE/x/%FR-4%did-not-apply
selftest-registered-against-the-wrong-requirement%lib/command-scan.sh%/^CS_WRAP_OPTION_WORDS=/s/nohup|//%GH-100%survived
MUTATIONS
)

# The two self-tests above are this harness's own evidence, and they are rows of
# the same registry rather than a mode of their own, so they are run by exactly
# the code the real mutations are. Their ids begin `selftest-`, which is what
# lets the outcome field be theirs alone.
#
# The first breaks the harness's trust in its own edit: its anchor is a variable
# name that appears nowhere, so the file comes back byte-identical and the
# expected outcome is `did-not-apply`. Without it, an edit whose anchor had moved
# would be reported as a mutation nothing caught, or worse as one everything
# caught, and this file would be measuring nothing.
#
# The second breaks the trust in the fourth field: it is the `nohup` mutation
# above, which this harness is separately shown to catch, registered against
# GH-100 -- the session report's classification of branches, which that edit
# cannot reach. The expected outcome is `survived`, and what it establishes is
# that `caught` is being read off the requirement IDs named and not off the run
# being red. A harness that reported caught whenever anything anywhere went red
# would pass every other row here and fail this one.

if [ -n "$LIST" ]; then
  printf '%-52s %-26s %-16s %s\n' 'MUTATION' 'FILE' 'EXPECTED' 'REQUIREMENTS'
  # The counts are printed rather than restated in prose anywhere, which is the
  # whole of #107's complaint applied to this file's own header: the previous
  # version characterised the registry in four documents and got the number
  # wrong in all four.
  ROWS=0
  REAL=0
  SELFTESTS=0
  FILES=
  IDS=
  while IFS='%' read -r id file edit reqs want; do
    [ -n "$id" ] || continue
    ROWS=$((ROWS + 1))
    case "$id" in
      selftest-*) SELFTESTS=$((SELFTESTS + 1)) ;;
      *) REAL=$((REAL + 1))
         FILES="$FILES$file
"
         for r in $reqs; do IDS="$IDS$r
"; done ;;
    esac
    printf '%-52s %-26s %-16s %s\n' "$id" "$file" "$want" "$reqs"
  done <<< "$MUTATIONS"
  echo
  printf '%s rows: %s real mutations against %s files, naming %s requirement IDs, and %s self-tests\n' \
    "$ROWS" "$REAL" \
    "$(printf '%s' "$FILES" | sort -u | grep -c .)" \
    "$(printf '%s' "$IDS" | sort -u | grep -c .)" \
    "$SELFTESTS"
  exit 0
fi

# The working copy. A directory of its own under the temporary one, so that the
# copy is made by name rather than into a directory that already exists.
WORK_ROOT=$(mktemp -d) || { echo "mutate-hooks.sh: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "$WORK_ROOT"' EXIT
WORK="$WORK_ROOT/hooks"
RUN_OUT="$WORK_ROOT/matrix"

# NEVER THE REPOSITORY'S OWN HOOKS, asked before the first delete and not after
# it: this is the one question whose wrong answer would destroy the files it is
# asked about. $WORK never changes after this, so asking once is asking it of
# every copy below.
#
# Three questions, and the first is subsumed by the second: equality is
# containment with nothing after the slash. It is asked separately all the same,
# because the two have different causes and a refusal a reader cannot act on is
# half a refusal -- "it IS the hooks directory" and "it is inside it" are found
# and fixed differently. The -ef clause is not redundant with either: it asks the
# filesystem rather than the spelling, so a symlink or a bind mount that resolves
# two ways is refused by it and by nothing else.
mkdir "$WORK" || { echo "mutate-hooks.sh: $WORK could not be made" >&2; exit 1; }
WORK_REAL=$(cd "$WORK" && pwd -P) || exit 1
SRC_REAL=$(cd "$SRC" && pwd -P) || exit 1
if [ "$WORK_REAL" = "$SRC_REAL" ] || [ "$WORK" -ef "$SRC" ]; then
  echo "mutate-hooks.sh: the working copy $WORK_REAL IS the repository's own hooks directory; refusing to mutate it" >&2
  exit 1
fi
# And neither inside the other. $TMPDIR is read by mktemp and can name anything,
# so a temporary directory under .claude/hooks/ would otherwise have `cp -a` copy
# the hooks into themselves and the run edit files under the directory it is
# meant not to touch. The other way round is the same mistake spelled
# differently.
case "$WORK_REAL/" in "$SRC_REAL"/*)
  echo "mutate-hooks.sh: the working copy $WORK_REAL is inside the repository's hooks directory; refusing" >&2
  exit 1 ;;
esac
case "$SRC_REAL/" in "$WORK_REAL"/*)
  echo "mutate-hooks.sh: the repository's hooks directory is inside the working copy $WORK_REAL; refusing" >&2
  exit 1 ;;
esac

hooks_copy() {  # hooks_copy -- a fresh, unmutated copy at $WORK
  rm -rf "$WORK" || return 1
  cp -a "$SRC" "$WORK" || return 1
}

# What .claude/hooks/ holds, before and after. Every entry's type, mode, path and
# symlink target, and then every file's contents: a file added or removed, a mode
# changed, a file replaced by a symlink to it, a symlink repointed, and an edit
# all move the sum. Paths are relative to the directory, so the sum says nothing
# about where it was taken.
#
# An empty or failed listing returns nothing AND a non-zero status, and the
# caller reads the status. A sum that is empty on both sides would otherwise
# compare equal, which is this check passing for the reason it exists to catch.
#
# Three things here are one line each and were all absent when this was first
# written, which Bertan's review of PR #142 found: -mindepth 1, without which
# `find` always emits `.` and the emptiness guard below can never fire; `%l`,
# without which a symlink retargeted from one file in the tree to another leaves
# the sum where it was; and `-r` on xargs, without which a tree holding no
# regular files runs sha256sum with no arguments, which reads stdin and succeeds.
tree_sum() {  # tree_sum <dir>
  local listing sums
  listing=$(cd "$1" && find . -mindepth 1 -printf '%y %m %P -> %l\n' | LC_ALL=C sort) || return 1
  [ -n "$listing" ] || return 1
  sums=$(cd "$1" && find . -mindepth 1 -type f -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum) || return 1
  [ -n "$sums" ] || return 1
  printf '%s\n%s\n' "$listing" "$sums" | sha256sum | cut -d' ' -f1
}

# The requirements whose checks failed in one run, read off the matrix. An ID
# line opens a requirement and every `    FAIL` line under it belongs to it; a
# failure's continuation lines are indented further and say nothing here.
failed_requirements() {  # failed_requirements <matrix file>
  awk '/^[A-Z]+-[0-9]/ { id = $1; next }
       /^    FAIL/ { if (id != "") print id }' "$1" | sort -u | tr '\n' ' '
}

# How many requirement headings the matrix printed at all. A run that aborted at
# a fixture guard prints none, and a harness that read that as "no requirement
# failed" would call every such mutation a survivor -- naming the wrong cause,
# in the direction that hides a defect in this file.
matrix_size() {  # matrix_size <matrix file>
  grep -cE '^[A-Z]+-[0-9]' "$1"
}

FAILED=0
MATCHED=0   # rows this invocation asked about, for the guard on a mistyped id
RUNS=0      # invocations of check-hooks.sh, for the footer

# PASS ONE: THE REGISTRY AS WRITTEN, before anything is copied or run. Every
# refusal here is about the table rather than about a hook, so answering them
# first means a mistyped id or a malformed row costs nothing instead of the 95 s
# the baseline takes. Rows that survive this pass are what pass two runs.
RUNNABLE=
while IFS='%' read -r ID FILE EDIT REQS WANT; do
  [ -n "$ID" ] || continue
  # The selection first, so that naming one mutation reports on that one. Asking
  # about a row it was not given -- refusing it for a malformed field, say --
  # would be this harness failing a run that never touched the row it blamed.
  if [ -n "$SELECTED" ]; then
    case " $SELECTED " in *" $ID "*) ;; *) continue ;; esac
  fi
  MATCHED=$((MATCHED + 1))
  if [ -z "$FILE" ] || [ -z "$EDIT" ] || [ -z "$REQS" ] || [ -z "$WANT" ]; then
    echo "  FAIL $ID: the registry row does not split into five fields on %"
    FAILED=1
    continue
  fi
  # The outcome, and whose it is. `caught` is every real mutation's; the other
  # two words belong to the self-tests, which say so in their ids. Untied, the
  # fifth field was the way to declare a real survivor expected and keep this
  # harness at exit 0.
  case "$WANT" in
    caught|survived|did-not-apply) ;;
    *) echo "  FAIL $ID: the expected outcome $WANT is none of caught, survived and did-not-apply"
       FAILED=1; continue ;;
  esac
  case "$WANT:$ID" in
    caught:*|survived:selftest-*|did-not-apply:selftest-*) ;;
    *) echo "  FAIL $ID: only a selftest-* row may expect $WANT; a real mutation expects caught"
       FAILED=1; continue ;;
  esac
  # The tooling beside the hooks is not a mutation target. The suite that runs is
  # this repository's, whatever CHECK_HOOKS_DIR says -- the two-directories
  # paragraph at its head says why -- and so is this file. An edit to either copy
  # would be read by the suite's text checks and executed by nothing, so whatever
  # this harness reported would be about a file that never ran.
  case " $TOOLING " in *" $FILE "*)
    echo "  FAIL $ID: $FILE runs from the repository rather than from the copy, so a mutation to it would be read and never executed"
    FAILED=1
    continue ;;
  esac
  # A file IN the working copy, spelled as a path relative to it. An absolute
  # path, or one climbing out with .., is an edit to whatever it names -- this
  # repository's own hooks among the things it could name -- and the sum taken at
  # the end would report that after the write rather than instead of it. Refused
  # on the spelling, which is the only moment before the write.
  case "$FILE" in
    /*|*/../*|../*|*/..|..)
      echo "  FAIL $ID: the target $FILE is not a path inside the hooks directory"
      FAILED=1
      continue ;;
  esac
  RUNNABLE="$RUNNABLE$ID%$FILE%$EDIT%$REQS%$WANT
"
done <<< "$MUTATIONS"

if [ -n "$SELECTED" ] && [ "$MATCHED" = 0 ]; then
  echo "  FAIL no registered mutation is named$SELECTED"
  exit 1
fi

# BOTH SELF-TESTS ARE PRESENT, asked of the whole registry and so only of a run
# that is judging the whole registry. A row can be deleted as easily as it can be
# declared, and the two words this harness reports are read off nothing at all
# once neither self-test is there.
if [ -z "$SELECTED" ]; then
  for OUTCOME in survived did-not-apply; do
    HAVE=$(printf '%s\n' "$MUTATIONS" \
           | awk -F% -v w="$OUTCOME" '$1 ~ /^selftest-/ && $5 == w' | grep -c .)
    [ "$HAVE" = 1 ] || {
      echo "  FAIL the registry holds $HAVE self-tests expecting $OUTCOME, and one is what says that word is read off anything"
      FAILED=1
    }
  done
fi

[ -n "$RUNNABLE" ] || {
  echo "  FAIL no registered mutation survived the reading of the registry, so nothing was run"
  exit 1
}

echo "=== the baseline: an unmutated copy of .claude/hooks/ ==="
SUM_BEFORE=$(tree_sum "$SRC") || {
  echo "mutate-hooks.sh: $SRC could not be summed, so nothing below could say it was left alone" >&2
  exit 1
}
hooks_copy || { echo "mutate-hooks.sh: the working copy could not be made" >&2; exit 1; }
echo "  running check-hooks.sh against $WORK ..."
# Bounded. A run takes about 95 s; nothing in the suite bounds a hook it runs, so
# a mutation that left one looping would hang this harness rather than report
# anything. A run killed at the bound prints no matrix, which is read below as
# did-not-complete -- never as caught.
RUN_BOUND=600
timeout "$RUN_BOUND" env CHECK_HOOKS_DIR="$WORK" bash "$SUITE" --matrix > "$RUN_OUT" 2>"$WORK_ROOT/baseline.err"
BASELINE_STATUS=$?
RUNS=$((RUNS + 1))
if [ "$BASELINE_STATUS" != 0 ] || [ "$(matrix_size "$RUN_OUT")" = 0 ]; then
  echo "  FAIL the unmutated copy is not green (exit $BASELINE_STATUS), so no mutation below would establish anything"
  echo "       $(failed_requirements "$RUN_OUT")"
  sed 's/^/       /' "$WORK_ROOT/baseline.err" >&2
  exit 1
fi
echo "  ok   the unmutated copy is green, over $(matrix_size "$RUN_OUT") requirements"

echo
echo "=== the registry ==="
# PASS TWO: one fresh copy, one edit, one run.
while IFS='%' read -r ID FILE EDIT REQS WANT; do
  [ -n "$ID" ] || continue

  hooks_copy || { echo "  FAIL $ID: the working copy could not be made"; FAILED=1; continue; }
  TARGET="$WORK/$FILE"
  if [ ! -w "$TARGET" ]; then
    echo "  FAIL $ID: $FILE is not a writable file in the working copy"
    FAILED=1
    continue
  fi
  if ! sed "$EDIT" "$TARGET" > "$WORK_ROOT/mutated" 2>"$WORK_ROOT/sed.err"; then
    echo "  FAIL $ID: the sed expression failed: $(cat "$WORK_ROOT/sed.err")"
    FAILED=1
    continue
  fi

  if cmp -s "$TARGET" "$WORK_ROOT/mutated"; then
    GOT=did-not-apply
    DETAIL="the edit left $FILE byte-identical, so the run after it would be a run of unmutated hooks"
  else
    cat "$WORK_ROOT/mutated" > "$TARGET"
    echo "  ...  $ID: running check-hooks.sh against the mutated copy"
    timeout "$RUN_BOUND" env CHECK_HOOKS_DIR="$WORK" bash "$SUITE" --matrix > "$RUN_OUT" 2>"$WORK_ROOT/run.err"
    STATUS=$?
    RUNS=$((RUNS + 1))
    RED=$(failed_requirements "$RUN_OUT")
    if [ "$(matrix_size "$RUN_OUT")" = 0 ]; then
      GOT=did-not-complete
      DETAIL="the suite exited $STATUS without printing a matrix: $(head -1 "$WORK_ROOT/run.err")"
    else
      MISSING=
      for r in $REQS; do
        case " $RED " in *" $r "*) ;; *) MISSING="$MISSING $r" ;; esac
      done
      if [ -z "$MISSING" ]; then
        GOT=caught
        DETAIL="every requirement it names went red${VERBOSE:+; red in all: ${RED% }}"
      else
        GOT=survived
        DETAIL="no failing check for${MISSING}; red instead: ${RED:-nothing at all}"
      fi
    fi
  fi

  if [ "$GOT" = "$WANT" ]; then
    printf '  ok   %-52s %s\n' "$ID" "$GOT"
    [ -n "$VERBOSE" ] && printf '       %s\n' "$DETAIL"
  else
    printf '  FAIL %-52s want=%s got=%s\n' "$ID" "$WANT" "$GOT"
    printf '       %s\n' "$DETAIL"
    FAILED=1
  fi
done <<< "$RUNNABLE"

echo
echo "=== the repository's own hooks, after all that ==="
SUM_AFTER=$(tree_sum "$SRC") || SUM_AFTER=
if [ -n "$SUM_AFTER" ] && [ "$SUM_BEFORE" = "$SUM_AFTER" ]; then
  echo "  ok   .claude/hooks/ is byte-identical to what it was: $SUM_AFTER"
else
  echo "  FAIL .claude/hooks/ changed during this run"
  echo "       before $SUM_BEFORE"
  echo "       after  $SUM_AFTER"
  FAILED=1
fi

echo
if [ "$FAILED" = 0 ]; then echo "EVERY MUTATION REPORTED WHAT THE REGISTRY EXPECTS ($MATCHED rows, $RUNS runs of check-hooks.sh, the baseline included)"
else echo "SOME MUTATIONS DID NOT REPORT WHAT THE REGISTRY EXPECTS"; fi
exit $FAILED

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
# ABOUT SIXTEEN MINUTES for the whole registry: one check-hooks.sh run per
# mutation that applies, at about 95 s, plus the baseline -- ten runs as the
# registry stands, not eleven, because the row whose edit matches nothing never
# reaches a run. Measured twice on 2026-09-16, on the same registry and the same
# machine: 16 min 30 s and 15 min 6 s. That is why it is a separate
# script and why check-hooks.sh does not call it (#107). Nothing here is a
# PreToolUse hook and settings.json does not register it.
#
# EXIT STATUS: non-zero when any row reports something other than the outcome it
# declares. For every real mutation that means a survivor or an edit that did not
# apply; for the two self-tests it means the opposite, since a run in which they
# were caught would say this harness reports `caught` for something it cannot
# have established. There is no spelling of "expected to fail" that leaves the
# exit status at 0 for one and not the other, which is why the outcome is a field
# rather than a mode.
#
# MEASURED, 2026-09-16, at the commit that added this file: every row reported
# what it declares, and .claude/hooks/ came back byte-identical. No per-mutation
# counts are recorded here on purpose -- a count in a comment is the thing #107
# was filed about, and the registry is re-runnable instead.
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
# report, and it is `caught` for every real mutation and something else only for
# the two self-tests at the foot of the registry.
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
# permitting direction, and the baseline is the check on it.
#
# WHAT A GREEN RUN HERE IS NOT EVIDENCE OF. The registry is a list someone wrote,
# so this is evidence about the mutations it names and about nothing else -- the
# same sentence check-hooks.sh's header makes about its checks, and it is no
# weaker here. `caught` says some check tagged with that requirement went red; it
# does not say the RIGHT check went red, and nothing here can say that.
#
# WHAT IS REGISTERED, counted rather than characterised, because the sentence
# that characterised it ("the rules that gained checks under #103") claimed the
# whole of two issues and named eight rows. Eight real mutations against six
# rules, and ten requirement IDs among them:
#
#   #105's three sections, one rule each -- the refusal that names the permitted
#   spelling (two rows, two hooks), the availability of every `gh issue`
#   subcommand (two rows, the coarse edit and the narrow one), and the stopping
#   rule the boundary hooks carry.
#   #106's families, through the three historical tokeniser defects its section
#   describes in prose and could not re-run (three rows).
#
# That is one mutation per rule, not one per requirement: #105 and #106 between
# them gained checks for some twenty-five requirements, and the other nineteen
# have no row here. One mutation per functional requirement is the backlog item
# in docs/todo.md, deferred by #103 Q8 when the harness was specified, and #108
# and #109 register theirs when they land.
#
# WHAT CANNOT BE REGISTERED HERE AT ALL, which is a limit of the design and not
# of the list:
#
#   - a rule that lives in check-hooks.sh itself. The suite that runs is this
#     repository's, so an edit to the copy's would be read and never executed;
#     the row is refused below. #106's six self-guards -- a transformation that
#     applies to no seed, a departure row naming a seed that is not there -- are
#     all of that kind, and #104's coverage machinery is too.
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
base-refusal-drops-the-spelling%no-pr-decisions.sh%/^BASE=/s/Write: gh pr create --base dev-NN/Name a base/%US-7 FR-23%caught
bare-push-refusal-drops-the-branch%no-git-push.sh%/Name the branch: git push/s/git push <remote> \$CURRENT/git push <remote> <branch>/%US-7%caught
stopping-rule-removed%no-git-push.sh%/would plausibly write/d%US-20 FR-2%caught
selftest-anchor-that-matches-nothing%lib/command-scan.sh%s/CS_NO_SUCH_VARIABLE_IS_DEFINED_HERE/x/%FR-4%did-not-apply
selftest-registered-against-the-wrong-requirement%lib/command-scan.sh%/^CS_WRAP_OPTION_WORDS=/s/nohup|//%GH-100%survived
MUTATIONS
)

# The two self-tests above are this harness's own evidence, and they are rows of
# the same registry rather than a mode of their own, so they are run by exactly
# the code the real mutations are.
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
  printf '%-52s %-22s %-16s %s\n' 'MUTATION' 'FILE' 'EXPECTED' 'REQUIREMENTS'
  while IFS='%' read -r id file edit reqs want; do
    [ -n "$id" ] || continue
    printf '%-52s %-22s %-16s %s\n' "$id" "$file" "$want" "$reqs"
  done <<< "$MUTATIONS"
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
# asked about. Resolved on both sides and compared as strings, and compared again
# with -ef, which asks the filesystem rather than the spelling -- a symlink, a
# bind mount or a $TMPDIR inside .claude/hooks/ would pass the first and not the
# second. $WORK never changes after this, so asking once is asking it of every
# copy below.
mkdir "$WORK" || { echo "mutate-hooks.sh: $WORK could not be made" >&2; exit 1; }
WORK_REAL=$(cd "$WORK" && pwd -P) || exit 1
SRC_REAL=$(cd "$SRC" && pwd -P) || exit 1
if [ "$WORK_REAL" = "$SRC_REAL" ] || [ "$WORK" -ef "$SRC" ]; then
  echo "mutate-hooks.sh: the working copy $WORK_REAL IS the repository's own hooks directory; refusing to mutate it" >&2
  exit 1
fi
# And neither inside the other. $TMPDIR is read by mktemp and can name anything,
# so a temporary directory under .claude/hooks/ passes the test above -- it is not
# the same directory -- and then `cp -a` copies the hooks into themselves and the
# run edits files under the directory it is meant not to touch. The other way
# round is the same mistake spelled differently.
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

# What .claude/hooks/ holds, before and after. Every entry's type, mode and path,
# and then every file's contents: a file added or removed, a mode changed, a file
# replaced by a symlink to it, and an edit all move the sum. Paths are relative to
# the directory, so the sum says nothing about where it was taken.
#
# An empty or failed listing returns nothing AND a non-zero status, and the
# caller reads the status. A sum that is empty on both sides would otherwise
# compare equal, which is this check passing for the reason it exists to catch.
tree_sum() {  # tree_sum <dir>
  local listing sums
  listing=$(cd "$1" && find . -printf '%y %m %P\n' | LC_ALL=C sort) || return 1
  [ -n "$listing" ] || return 1
  sums=$(cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum) || return 1
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
if [ "$BASELINE_STATUS" != 0 ] || [ "$(matrix_size "$RUN_OUT")" = 0 ]; then
  echo "  FAIL the unmutated copy is not green (exit $BASELINE_STATUS), so no mutation below would establish anything"
  echo "       $(failed_requirements "$RUN_OUT")"
  sed 's/^/       /' "$WORK_ROOT/baseline.err" >&2
  exit 1
fi
echo "  ok   the unmutated copy is green, over $(matrix_size "$RUN_OUT") requirements"

FAILED=0
RAN=0
echo
echo "=== the registry ==="
while IFS='%' read -r ID FILE EDIT REQS WANT; do
  [ -n "$ID" ] || continue
  # The selection first, so that naming one mutation reports on that one. Asking
  # about a row it was not given -- refusing it for a malformed field, say -- would
  # be this harness failing a run that never touched the row it blamed.
  if [ -n "$SELECTED" ]; then
    case " $SELECTED " in *" $ID "*) ;; *) continue ;; esac
  fi
  if [ -z "$FILE" ] || [ -z "$EDIT" ] || [ -z "$REQS" ] || [ -z "$WANT" ]; then
    echo "  FAIL $ID: the registry row does not split into five fields on %"
    FAILED=1
    continue
  fi
  case " $WANT " in
    ' caught '|' survived '|' did-not-apply ') ;;
    *) echo "  FAIL $ID: the expected outcome $WANT is none of caught, survived and did-not-apply"
       FAILED=1; continue ;;
  esac
  # check-hooks.sh is not a mutation target. The suite that runs is this
  # repository's, whatever CHECK_HOOKS_DIR says -- the two-directories paragraph
  # at its head says why -- so an edit to the copy's would be read by its
  # self-audits and executed by nothing, and whatever this harness reported would
  # be about a file that never ran.
  if [ "$FILE" = check-hooks.sh ]; then
    echo "  FAIL $ID: check-hooks.sh cannot be mutated here; the suite that runs is the repository's own"
    FAILED=1
    continue
  fi
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
  RAN=$((RAN + 1))

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
done <<< "$MUTATIONS"

if [ -n "$SELECTED" ] && [ "$RAN" = 0 ]; then
  echo "  FAIL no registered mutation is named$SELECTED"
  FAILED=1
fi

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
if [ "$FAILED" = 0 ]; then echo "EVERY MUTATION REPORTED WHAT THE REGISTRY EXPECTS ($RAN run)"
else echo "SOME MUTATIONS DID NOT REPORT WHAT THE REGISTRY EXPECTS"; fi
exit $FAILED

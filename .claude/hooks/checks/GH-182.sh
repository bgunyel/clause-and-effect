#!/bin/bash
# THE ISSUE FILE OF #182: the refusal-arm counters drop heredoc bodies, with the
# tokeniser's own pass, and the library answers for that pass being missing.
#
# Why: `arms`, `fn_writes` and `fn_calls` in the unsplit file read a hook's text
# to count where it writes a refusal, and did not know where a heredoc body
# begins. A body line carrying `>&2` counted as an arm, and `cat >&2 <<EOF`
# whose body carried one counted twice. #182's triage found a third, in
# `fn_writes`: a body line that is just `}` in column 1 closed the function
# around it, so a write after it went to no function and a writer read
# `silent`. All three were measured on fixtures at dev-05 abba1d0. None could
# hide an arm -- the permitting shape #182 was filed on was closed by #169 --
# but the third shows the wrong row in a red run, which is the misleading-red
# class the unsplit file names for a one-liner.
#
# THE FIX IS A REUSE, NOT A PARSER. The heredoc pass of cs_normalise became
# cs_drop_heredocs in lib/command-scan.sh, with cs_normalise calling it, and the
# three counters run it between stripping comments and folding continuations.
# cs_normalise's output is unchanged, byte for byte: measured on 283 files of
# .claude/ and docs/ and 3,000 generated shapes before this file was written.
#
# AND THE EXTRACTION OPENED A HOLE THE LOAD CONTRACT HAD TO CLOSE, measured:
# with cs_drop_heredocs renamed away, cs_normalise printed nothing and
# succeeded, and no-git-push.sh permitted `git push --force origin main`. No
# consumer calls the new function, so no load guard requires it; the library
# withdraws cs_normalise instead, which every consumer of it does require. The
# second of this file's three parts drives that, per consumer.
#
# WHAT IS DRIVEN in the first part is each counter, against a fixture per
# shape, in the manner of the unsplit file's `arms` and `fns` fixtures. Each
# expected value is the one the fix gives; the old pipeline gives the other,
# which was measured by reverting the pipeline by hand and is not a check here.
# That half of the change is out of mutate-hooks.sh's reach, since `hook_text`
# and the counters are the suite's own code and it judges only the hooks
# directory; the other half is not, because the pass `hook_text` runs in the
# middle is lib/command-scan.sh's, which it does mutate, and a mutated drop
# moves the counts the unsplit file pins.
#
# AND THE REUSE CARRIED THE TOKENISER'S BLIND SPOT INTO THE COUNTERS, found by
# review of this file's pull request: a `<<` the tokeniser misreads, in quotes
# or in a trailing comment, drops real code whenever a line that ends the body
# it did not open arrives, and no-pr-decisions.sh has one today. The third part
# of this file holds what the drop takes from each hook the counters read.
#
# WHAT IT TAKES FROM ELSEWHERE: $PUSH_WT and $ON_DEV from check-hooks.sh's
# prelude; from the unsplit file, which builds and owns them, the fixture
# $WT_STALE, the list $LIB_CONSUMERS, and $STDERR_WRITE, which the counters
# read. A fixture used by two files belongs in the prelude, and moves there only
# when the file owning it moves, so each stays where it is.

section "=== issue #182: the refusal-arm counters drop heredoc bodies ==="

requirement GH-182.1 <<'REQ'
- text: `arms`, `fn_writes` and `fn_calls` read a hook through one helper,
  `hook_text`, and through nothing else, and it strips whole-line comments,
  then drops heredoc bodies with `cs_drop_heredocs`, then folds backslash
  continuations, in that order. So a heredoc body line carrying `>&2` is
  not an arm; `cat >&2 <<EOF` is one arm whatever its body says; a body line
  that is just `}` does not close the function around it, and a write after it
  is that function's; a body line naming a function is not a call to it. A
  whole-line comment naming an opener starts no body, and a body line ending
  in a backslash does not carry its terminator away into the line after it.
  An opener the tokeniser misreads -- a `<<` inside quotes or in a trailing
  comment -- gives its lines back when no line ends its body, and when one does
  it drops the code before it: that is #289's, asserted here as the behaviour
  it is, and GH-182.3 holds the hooks the counters read against it.
- from: #182
- kind: defect-refusing
- status: active
- direction: static: a property of the suite's helpers
- note: The kind is the defect's: the two inflating shapes were false reds and
  the `}` shape a misleading one, and none of them could hide an arm. The two
  order rows guard the fix rather than a defect that stood, and they guard the
  permitting direction: with the drop run after the fold, or before the comment
  strip, a body starts or ends in the wrong place and a real arm between two
  heredocs is dropped. One helper holds the order so that the order rows,
  driven through `arms`, are evidence about all three.
REQ
requirement GH-182.2 <<'REQ'
- text: A library in which `cs_drop_heredocs` is not defined withdraws
  `cs_normalise`, and says so on stderr naming both, so every consumer that
  requires `cs_normalise` refuses by its load guard; the intact library prints
  nothing on loading. No hook calls `cs_drop_heredocs` but through
  `cs_normalise`; in the check suite only `hook_bodiless` does, which
  `hook_text` and GH-182.3 read through, beside a fixture of this issue's that
  is defined to be found and never run; and no guard names it.
- from: #182
- kind: defect-permitting
- status: active
- variants: none: its subject is a function missing from the library, which is
  a state of the tree rather than a spelling
- note: Found while extracting the pass, not filed. With the function renamed
  away and nothing withdrawn, `cs_normalise` printed nothing and succeeded, and
  `git push --force origin main`, `gh pr merge 5`, `pytest tests/` and
  `alembic upgrade head` were each permitted by the hook that guards it. This is
  GH-84.1 for a function the extraction added: GH-84.1 asks each consumer to
  require what it calls, and a consumer does not call this. #182's triage asked
  that it be answered for as `cs_join` is, and it cannot be: `cs_join` is
  answered by `cs_within_cap`, which every Bash hook calls and which fails when
  `cs_join` does, and no hook calls anything that calls `cs_drop_heredocs` but
  `cs_normalise`, whose failure no consumer reads. Withdrawal is the answer the
  library already gives an incomplete word list. It answers a missing function
  and nothing wider: a pass that is defined but does not compile -- an awk
  program with a syntax error -- leaves `cs_normalise` printing nothing and
  succeeding by the same route, since the pipeline's status is its last
  stage's. That predates #182, every tokeniser check goes red on such an edit,
  and it is #242's, which owns a load-time compile check for every awk program
  the library carries.
REQ
requirement GH-182.3 <<'REQ'
- text: Every line `hook_text` drops from a hook the refusal-arm counters read
  is a bare parameter, such as `$CMDS` or `$1`, or a word in capitals -- the
  two lines a one-parameter heredoc body and its delimiter are made of -- and
  a line the drop rewrites rather than removes, the line ending an opener's
  logical line when it ends in an even run of backslashes, reads as a red. The
  one exception is the block that no-pr-decisions.sh's `grep -q '<<'` drops,
  whose quoted opener has an empty delimiter that the next blank line ends: it
  is held verbatim until #289 stops the tokeniser dropping it. `hook_text` is
  that drop and then the fold, pinned as written, so no stage the counters
  read escapes the question. So an arm or a call hidden by an opener the
  tokeniser misreads is a red run that names the line, and not a count that
  stays green or turns red on a plausible wrong number.
- from: #182
- kind: defect-permitting
- status: active
- direction: static: a property of the suite's helpers over the counted hooks
- note: Found by review of #182's pull request, not filed, and the regression
  is that pull request's own: `cs_drop_heredocs` gives lines back only when no
  terminator arrives. Measured on the branch before this was written, an arm
  added inside no-pr-decisions.sh's `grep -q '<<'` block left `arms` at the
  pinned 20 and the suite green, where dev-05 counted 21 and went red. A
  trailing comment naming `<<CMDLIST` in no-git-push.sh took its wrapper arm
  out of the count, a red on 18 that reconciling the pin would have made
  permanent. Held to a shape and not to a list of lines, so a new
  `done <<CMDLIST` loop needs no edit here. The false opener in the hooks'
  own verdicts is #289's and outside #182.
REQ
shape_pin 'GH-182.1:static GH-182.2 GH-182.3:static'
variants_pin 'GH-182.2:none'

# THE COUNTER FIXTURES, one shape each, named after it.
R182="$FIXTURES/r182"
mkdir -p "$R182"
cat > "$R182/body-carries-a-write.sh" <<'R182_EOF'
cat > notes.txt <<EOF
echo "refused" >&2
EOF
R182_EOF
cat > "$R182/stderr-heredoc-body-carries-a-write.sh" <<'R182_EOF'
cat >&2 <<EOF
refused; write it as: echo "x" >&2
EOF
R182_EOF
cat > "$R182/body-closes-a-function.sh" <<'R182_EOF'
speaks() {
  cat > payload.json <<JSON
{
  "a": 1
}
JSON
  echo "refused" >&2
}
speaks
R182_EOF
cat > "$R182/body-names-a-function.sh" <<'R182_EOF'
speaks() {
  echo "refused" >&2
}
cat > notes.txt <<EOF
speaks is called once
EOF
speaks x
R182_EOF
# The order rows. Folding first joins `body \` onto its terminator, so the
# body runs on to the second heredoc's terminator and the arm between them is
# dropped; dropping before the comment strip opens a body at the comment's
# `<<END` and ends it at the real one, dropping the arm in between.
cat > "$R182/body-line-ends-in-a-backslash.sh" <<'R182_EOF'
cat > f <<'EOF'
body \
EOF
echo "refused" >&2
cat > g <<'EOF'
x
EOF
R182_EOF
cat > "$R182/comment-names-an-opener.sh" <<'R182_EOF'
# the body ends at <<END
echo "refused" >&2
cat <<END
x
END
R182_EOF
# The fail-safe, asserted: an opener inside quotes whose terminator never
# arrives gives its lines back, in their place, so the function after it is
# still read as the writer it is.
cat > "$R182/quoted-opener-never-closed.sh" <<'R182_EOF'
hint() {
  echo "write it with cat <<NOTE" >&2
}
speaks() {
  echo "refused" >&2
}
speaks
R182_EOF
# The half of the fail-safe that does not hold, asserted as the trade it is and
# owned by #289: an opener the tokeniser misreads, whose body a line then ends.
# A quoted `'<<'` has an empty delimiter once its quotes are gone, so a blank
# line ends it -- the shape no-pr-decisions.sh carries -- and a trailing comment
# naming `<<LIST` is ended by the real `LIST` further down.
cat > "$R182/quoted-opener-a-blank-line-ends.sh" <<'R182_EOF'
if echo "$C" | grep -q '<<'; then
  echo "refused" >&2
fi

echo "refused" >&2
R182_EOF
cat > "$R182/trailing-comment-opener-a-delimiter-ends.sh" <<'R182_EOF'
echo "refused" >&2  # read below as done <<LIST
echo "refused" >&2
while read -r x; do :; done <<LIST
$X
LIST
R182_EOF
# The one line the drop rewrites rather than removes: the line that ends an
# opener's logical line, when it ends in an even run of backslashes -- text,
# not a continuation -- loses the run and the blanks in front of it. That is
# the opener's own line, or a continuation line after it.
cat > "$R182/opener-ends-in-an-even-backslash-run.sh" <<'R182_EOF'
cat <<EOF \\
$X
EOF
R182_EOF
cat > "$R182/opener-continued-onto-an-even-backslash-run.sh" <<'R182_EOF'
cat <<EOF \
  x \\
$X
EOF
R182_EOF
for f in body-carries-a-write stderr-heredoc-body-carries-a-write body-closes-a-function \
         body-names-a-function body-line-ends-in-a-backslash comment-names-an-opener \
         quoted-opener-never-closed quoted-opener-a-blank-line-ends \
         trailing-comment-opener-a-delimiter-ends opener-ends-in-an-even-backslash-run \
         opener-continued-onto-an-even-backslash-run; do
  [ -s "$R182/$f.sh" ] || {
    echo "the #182 fixture $f.sh was not written; the checks against it prove nothing" >&2
    exit 1
  }
done

req GH-182.1
tok 'arms does not count a write inside a heredoc body' \
    '0' "$(arms "$R182/body-carries-a-write.sh")"
tok 'arms counts a heredoc sent to stderr once, whatever its body says' \
    '1' "$(arms "$R182/stderr-heredoc-body-carries-a-write.sh")"
tok 'fn_writes does not let a } body line close the function around it' \
    'speaks writes' "$(fn_writes "$R182/body-closes-a-function.sh")"
tok 'fn_calls does not count a body line naming a function as a call' \
    '1' "$(fn_calls "$R182/body-names-a-function.sh" speaks)"
tok 'arms drops a body before folding, so a backslash does not carry the terminator away' \
    '1' "$(arms "$R182/body-line-ends-in-a-backslash.sh")"
tok 'arms strips comments before dropping, so a whole-line comment naming an opener starts no body' \
    '1' "$(arms "$R182/comment-names-an-opener.sh")"
tok 'arms gives back the lines of an opener whose terminator never arrives' \
    '2' "$(arms "$R182/quoted-opener-never-closed.sh")"
tok 'and fn_writes reads them in their place' \
    'hint writes
speaks writes' "$(fn_writes "$R182/quoted-opener-never-closed.sh")"
tok 'arms loses the arm under a quoted <<, whose empty delimiter a blank line ends: the trade #289 owns' \
    '1' "$(arms "$R182/quoted-opener-a-blank-line-ends.sh")"
tok 'arms loses the arm after a trailing comment naming <<LIST, which the real LIST ends: the same trade' \
    '1' "$(arms "$R182/trailing-comment-opener-a-delimiter-ends.sh")"
# All three counters, and not the one the issue named first: `fn_writes` and
# `fn_calls` ran the same pipeline, and a fix to one of three is the shape the
# unsplit file's section records three times. So each reads the hook through
# `hook_text` and nothing else -- no `sed` and no drop of its own -- which is
# what makes the order rows above, driven through `arms`, evidence about all
# three. Read off their definitions as bash holds them. Review of #182's first
# commit found the order pinned for `arms` alone, while GH-182.1 claimed it of
# all three.
#
# "Nothing else" is asked of the file argument, since a counter can read a hook
# only by its name: with the one `hook_text "$1"` taken out, no `$1`, `$@` or
# `$*` is left, braced or not, and no drop or `sed` of its own. The first
# version asked only the second half, so a counter piping `cat "$1"` beside
# `hook_text` passed; the second let the brace reach `1` alone, so `${@}` and
# `${*}` passed. Review of #182's pull request found each.
R182_THROUGH=$(for fn in arms fn_writes fn_calls; do
  body=$(declare -f "$fn")
  rest=${body//'hook_text "$1"'/}
  [[ $body == *'hook_text "$1"'* && $rest != *cs_drop_heredocs* && $rest != *'sed '* ]] \
    && ! [[ $rest =~ \$\{?(1|[@*]) ]] \
    && printf '%s ' "$fn"
done)
tok 'arms, fn_writes and fn_calls each read the hook through hook_text, and name it nowhere else' \
    'arms fn_writes fn_calls ' "$R182_THROUGH"

# THE WITHDRAWAL. Every file that requires cs_normalise, read off the guards --
# the list the extraction put at risk -- and then as a literal, so a seventh
# consumer is a red run and not a silent omission.
R182_CONSUMERS=$(for hook in $LIB_CONSUMERS; do
  grep -q 'command -v cs_normalise' "$HOOKS/$hook" && printf '%s ' "$hook"
done)
req GH-182.2
tok 'the hooks that require cs_normalise are the six this file drives' \
    'alembic-via-uv-group.sh no-commit-to-main.sh no-git-push.sh no-pr-decisions.sh no-work-on-stale-branch.sh pytest-via-uv-group.sh ' \
    "$R182_CONSUMERS"
for hook in $R182_CONSUMERS; do
  mk_halflib "$hook" cs_drop_heredocs
done
# Each on a command the intact hook permits, so the BLOCK can only be the
# withdrawal: with cs_normalise left running and printing nothing, every one of
# these is ALLOW. no-work-on-stale-branch.sh is scoped to a stale branch, as in
# the unsplit file's #84 block, and driven there.
check_in "$PUSH_WT" no-git-push.sh ALLOW 'no-git-push.sh permits ls with the library intact' 'ls'
check_in "$PUSH_WT" "$(halflib_path no-git-push.sh cs_drop_heredocs)" BLOCK \
  'no-git-push.sh, a library missing only cs_drop_heredocs' 'ls'
check_in "$ON_DEV" no-pr-decisions.sh ALLOW 'no-pr-decisions.sh permits ls with the library intact' 'ls'
check_in "$ON_DEV" "$(halflib_path no-pr-decisions.sh cs_drop_heredocs)" BLOCK \
  'no-pr-decisions.sh, a library missing only cs_drop_heredocs' 'ls'
check_in "$ON_DEV" no-commit-to-main.sh ALLOW 'no-commit-to-main.sh permits ls with the library intact' 'ls'
check_in "$ON_DEV" "$(halflib_path no-commit-to-main.sh cs_drop_heredocs)" BLOCK \
  'no-commit-to-main.sh, a library missing only cs_drop_heredocs' 'ls'
check_in "$WT_STALE" no-work-on-stale-branch.sh ALLOW \
  'no-work-on-stale-branch.sh permits git status on a stale branch with the library intact' 'git status'
check_in "$WT_STALE" "$(halflib_path no-work-on-stale-branch.sh cs_drop_heredocs)" BLOCK \
  'no-work-on-stale-branch.sh, a library missing only cs_drop_heredocs, on a stale branch' 'git status'
check_in "$ON_DEV" pytest-via-uv-group.sh ALLOW 'pytest-via-uv-group.sh permits ls with the library intact' 'ls'
check_in "$ON_DEV" "$(halflib_path pytest-via-uv-group.sh cs_drop_heredocs)" BLOCK \
  'pytest-via-uv-group.sh, a library missing only cs_drop_heredocs' 'ls'
check_in "$ON_DEV" alembic-via-uv-group.sh ALLOW 'alembic-via-uv-group.sh permits ls with the library intact' 'ls'
check_in "$ON_DEV" "$(halflib_path alembic-via-uv-group.sh cs_drop_heredocs)" BLOCK \
  'alembic-via-uv-group.sh, a library missing only cs_drop_heredocs' 'ls'
# What the refusal says: the hook names itself, as GH-84.1 asks of every guard,
# and the library names the function it withdrew for, since the guard names the
# library and nothing inside it.
says "$PUSH_WT" "$(halflib_path no-git-push.sh cs_drop_heredocs)" 'no-git-push.sh could not load' \
  'no-git-push.sh names itself for a library missing only cs_drop_heredocs' 'ls'
says "$PUSH_WT" "$(halflib_path no-git-push.sh cs_drop_heredocs)" \
  'cs_drop_heredocs is not defined, and cs_normalise calls it. cs_normalise is withdrawn' \
  'and the library says which function is missing and what it withdrew' 'ls'
# And the load itself, off the hooks: cs_normalise is gone from a library
# missing cs_drop_heredocs, and the intact library withdraws nothing and says
# nothing.
R182_HALF_LIB="$(dirname "$(halflib_path no-git-push.sh cs_drop_heredocs)")/lib/command-scan.sh"
tok 'a library missing cs_drop_heredocs leaves cs_normalise undefined' \
    'absent' "$(bash -c ". '$R182_HALF_LIB' 2>/dev/null; declare -F cs_normalise >/dev/null && echo present || echo absent")"
tok 'the intact library leaves it defined' \
    'present' "$(bash -c ". '$HOOKS/lib/command-scan.sh' 2>/dev/null; declare -F cs_normalise >/dev/null && echo present || echo absent")"
tok 'and prints nothing on loading' \
    '' "$(bash -c ". '$HOOKS/lib/command-scan.sh'" 2>&1 >/dev/null)"
# No guard learned the name, which is the point of withdrawing rather than
# requiring: a guard that required it would be a required list wider than the
# call set the unsplit file derives it against.
for hook in $LIB_CONSUMERS; do
  unarmed "$hook does not require cs_drop_heredocs itself" "$HOOKS/$hook" 'cs_drop_heredocs'
done
# The literal runs past the heading into the clause only the statement
# carries: the heading alone is also a cross-reference in the load contract,
# wrapped there, and the reflow reads both, so with the statement deleted the
# pin still read ok (review of #192's branch, round 1).
written 'the library says cs_normalise answers for cs_drop_heredocs' \
  "$(prose "$HOOKS/lib/command-scan.sh")" 'CS_NORMALISE ANSWERS FOR CS_DROP_HEREDOCS, which no consumer calls'

# WHAT THE DROP TAKES FROM THE HOOKS THE COUNTERS READ. Which hooks those are is
# read off the suite, every `arms`, `fn_writes` or `fn_calls` written with a
# `"$HOOKS/<name>"` argument, and then pinned as a literal, so a third is a red
# run and not a hook read with nothing holding what its drop takes. A call that
# names its hook through another variable is not read; every call that reads
# a hook of this directory names it that way today.
req GH-182.3
# Whole-line comments blanked by the counters' own first stage, and the name
# bounded on the left, so a comment or a `farms "$HOOKS/x.sh"` adds no hook.
R182_COUNTED=$(hook_uncommented "$SUITE_TEXT" \
  | grep -oE '(^|[^A-Za-z0-9_])(arms|fn_writes|fn_calls) "\$HOOKS/[A-Za-z0-9_.-]+"' \
  | sed 's|.*/||; s|"$||' | LC_ALL=C sort -u | tr '\n' ' ')
tok 'the counters read two hooks of this directory' \
    'no-git-push.sh no-pr-decisions.sh ' "$R182_COUNTED"
# Every line the drop in `hook_text` removed, `-` in front: the library's two
# stages, `hook_uncommented` and `hook_bodiless`, diffed, so the text judged is
# the text `hook_text` folds. The drop adds no line, but it rewrites one kind --
# the line ending an opener's logical line loses a trailing even run of
# backslashes -- and diff shows that as a `-` and a `+`. Both are printed
# rather than assumed away, and read as a red below; neither hook has one
# today.
hook_dropped() {  # hook_dropped <file> -- "-<line>" per line removed, "+<line>" per line rewritten
  diff --old-line-format='-%L' --new-line-format='+%L' --unchanged-line-format='' \
    <(hook_uncommented "$1") <(hook_bodiless "$1")
}
# Of what `hook_dropped` prints, on stdin: a line the drop takes that is
# neither a bare parameter nor a word in capitals, and a line it rewrote, as
# the pair diff shows. It asks the shape of each line and not whether the
# two alternate, since which copy of a repeated line diff calls dropped is
# diff's choice, and the lines dropped are the same whichever it makes.
#
# Each hook's answer is a literal: none for no-git-push.sh, and for
# no-pr-decisions.sh the block under its `grep -q '<<'`, verbatim, blank
# terminator included. An arm or a call added to that block changes the text
# and is red; so is #289 closing, which leaves the literal naming lines nothing
# drops, and it goes when #289 does. The cost, taken knowingly: an edit to that
# block that changes no verdict -- a line reworded, a variable renamed -- is red
# here too, which is the refusing direction. Respelling the `grep -q '<<'` so
# the tokeniser cannot see its `<<` would end that, and is declined: it is a guard
# edit made for a counter's sake, and it would hide #289's one instance rather
# than hold it.
r182_unshaped() {  # r182_unshaped -- stdin: hook_dropped's lines; stdout: those no heredoc of this shape explains
  grep -vE '^-(\$([A-Za-z_][A-Za-z0-9_]*|[0-9])|[A-Z][A-Z0-9_]*)$'
}
# A caller of cs_drop_heredocs, never run, defined here for the derivation at
# the foot of this file to find: it stands below where that derivation first
# stood, so moving it back above this point is a red run and not a caller
# silently unread. See R182_CALLERS.
r182_a_late_caller() {  # r182_a_late_caller -- never called; a fixture for R182_CALLERS
  cs_drop_heredocs < /dev/null
}
R182_FALSE_OPENER=$(cat <<'R182_EOF'
-  SCAN="$SCAN
-$COMMAND"
-  CMDS=$(printf '%s\n' "$SCAN" | cs_split)
-fi
-
R182_EOF
)
# The empty row below asks something only if the diff ran: with no GNU diff to
# read --old-line-format, or a process substitution that failed, it would pass
# on nothing. no-git-push.sh reads its commands through heredoc loops, so its
# drop is never empty. Read once, so the guard and the row judge one output.
R182_PUSH_DROPPED=$(hook_dropped "$HOOKS/no-git-push.sh")
if [ -n "$R182_PUSH_DROPPED" ]; then
  pass static 'hook_dropped reads a drop out of no-git-push.sh, so the empty row after it asked something'
else
  fail static 'hook_dropped reads no drop out of no-git-push.sh, which reads its commands through heredoc loops; the empty row after it proves nothing'
fi
tok 'hook_text drops nothing from no-git-push.sh but one-parameter heredoc bodies and their delimiters' \
    '' "$(printf '%s\n' "$R182_PUSH_DROPPED" | r182_unshaped)"
tok 'and from no-pr-decisions.sh those and the block under its quoted <<, verbatim, which #289 owns' \
    "$R182_FALSE_OPENER" "$(hook_dropped "$HOOKS/no-pr-decisions.sh" | r182_unshaped)"
# What makes those two rows about the text the counters read: `hook_text` is
# `hook_bodiless` and then the fold, and nothing between, pinned as bash holds
# it. A stage added after the drop -- a filter, a route round #289 -- would be
# text the counters read and no row above judges, so it is red here instead.
R182_HOOK_TEXT=$(cat <<'R182_EOF'
hook_text ()
{
    hook_bodiless "$1" | sed ':a;/\\$/{N;s/\\\n//;ba}'
}
R182_EOF
)
tok 'hook_text is the drop and then the fold, with no stage between' \
    "$R182_HOOK_TEXT" "$(declare -f hook_text | sed 's/[[:space:]]*$//')"
# Driven, not only asserted: the two trade fixtures above each hide an arm, and
# this is what names it.
tok 'r182_unshaped names the arm a quoted << hides, and the lines with it' \
    '-  echo "refused" >&2
-fi
-' "$(hook_dropped "$R182/quoted-opener-a-blank-line-ends.sh" | r182_unshaped)"
tok 'and the arm a trailing comment naming <<LIST hides, with the real opener' \
    '-echo "refused" >&2
-while read -r x; do :; done <<LIST' "$(hook_dropped "$R182/trailing-comment-opener-a-delimiter-ends.sh" | r182_unshaped)"
tok 'and an opener the drop rewrites, as the line it was and the line it became' \
    '-cat <<EOF \\
+cat <<EOF' "$(hook_dropped "$R182/opener-ends-in-an-even-backslash-run.sh" | r182_unshaped)"
tok 'and a continuation line the drop rewrites, where the logical line it ends began on the opener' \
    '-  x \\
+  x' "$(hook_dropped "$R182/opener-continued-onto-an-even-backslash-run.sh" | r182_unshaped)"

# WHO CALLS cs_drop_heredocs, which GH-182.2's text names: every function
# defined when this runs, the library's and the suite's, whose body calls it,
# read off the bodies as bash holds them. It runs here, at the foot of the
# file, because `declare -F` sees only what is defined so far: it first ran
# among GH-182.2's checks, above `hook_dropped`, so `hook_dropped` reverted to
# a call of its own was read by nothing and the run stayed green -- #302's
# second shape, found by review of #182's pull request. `r182_a_late_caller`,
# above, is the fixture that makes a move back red. A function defined in a
# file sourced after this one is not read.
#
# A call is the name in a command position -- a line's start, or after a `|`,
# `;`, `&` or `(` -- and not merely the name: the first version counted
# `mk_halflib`, whose stderr filter quotes the library's message naming it. A
# call after a control word or a prefix word -- `if`, `while`, `!`, `command`
# -- is not read, which is #302's first shape and stays with it. A call written
# at the top level of a file, outside any function, is not read; there is none.
req GH-182.2
R182_CALLERS=$(declare -F | awk '{ print $3 }' | while read -r fn; do
  [ "$fn" = cs_drop_heredocs ] && continue
  declare -f "$fn" | tail -n +2 \
    | grep -qE '(^|[|;&(])[[:space:]]*cs_drop_heredocs([[:space:];)]|$)' \
    && printf '%s ' "$fn"
done)
tok 'cs_drop_heredocs is called by cs_normalise, by the suite through hook_bodiless, and by nothing else but the late fixture' \
    'cs_normalise hook_bodiless r182_a_late_caller ' "$R182_CALLERS"

sourced_to_end

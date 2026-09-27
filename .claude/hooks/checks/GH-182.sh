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
# second half of this file drives that, per consumer.
#
# WHAT IS DRIVEN in the first half is each counter, against a fixture per
# shape, in the manner of the unsplit file's `arms` and `fns` fixtures. Each
# expected value is the one the fix gives; the old pipeline gives the other,
# which was measured by reverting the pipeline by hand and is not a check here,
# since the counters are the suite's own code and mutate-hooks.sh judges only
# the hooks directory.

section "=== issue #182: the refusal-arm counters drop heredoc bodies ==="

requirement GH-182.1 <<'REQ'
- text: `arms`, `fn_writes` and `fn_calls` read a hook with whole-line comments
  stripped, then heredoc bodies dropped by `cs_drop_heredocs`, then backslash
  continuations folded, in that order. So a heredoc body line carrying `>&2` is
  not an arm; `cat >&2 <<EOF` is one arm whatever its body says; a body line
  that is just `}` does not close the function around it, and a write after it
  is that function's; a body line naming a function is not a call to it. A
  comment naming an opener starts no body, and a body line ending in a
  backslash does not carry its terminator away into the line after it.
- from: #182
- kind: defect-refusing
- status: active
- direction: static: a property of the suite's helpers
- note: The two inflating shapes were false reds and the `}` shape a misleading
  one, and none of them could hide an arm. The two order rows are what could:
  with the drop run after the fold, or before the comment strip, a body starts
  or ends in the wrong place and a real arm between two heredocs is dropped,
  which is the permitting direction for these counters.
REQ
requirement GH-182.2 <<'REQ'
- text: A library in which `cs_drop_heredocs` is not defined withdraws
  `cs_normalise`, and says so on stderr naming both, so every consumer that
  requires `cs_normalise` refuses by its load guard; the intact library prints
  nothing on loading. `cs_drop_heredocs` is called by `cs_normalise` alone, and
  no guard names it.
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
  require what it calls, and a consumer does not call this.
REQ
shape_pin 'GH-182.1:static GH-182.2'
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
for f in body-carries-a-write stderr-heredoc-body-carries-a-write body-closes-a-function \
         body-names-a-function body-line-ends-in-a-backslash comment-names-an-opener \
         quoted-opener-never-closed; do
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
tok 'arms strips comments before dropping, so a comment naming an opener starts no body' \
    '1' "$(arms "$R182/comment-names-an-opener.sh")"
tok 'arms gives back the lines of an opener whose terminator never arrives' \
    '2' "$(arms "$R182/quoted-opener-never-closed.sh")"
tok 'and fn_writes reads them in their place' \
    'hint writes
speaks writes' "$(fn_writes "$R182/quoted-opener-never-closed.sh")"
# All three counters, and not the one the issue named first: `fn_writes` and
# `fn_calls` ran the same pipeline, and a fix to one of three is the shape the
# unsplit file's section records three times. Read off their definitions, so
# a fourth helper added to that section on the old pipeline is not counted in.
R182_ON_PIPELINE=$(for fn in arms fn_writes fn_calls; do
  declare -f "$fn" | grep -q 'cs_drop_heredocs' && printf '%s ' "$fn"
done)
tok 'arms, fn_writes and fn_calls each run cs_drop_heredocs' \
    'arms fn_writes fn_calls ' "$R182_ON_PIPELINE"

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
written 'the library says cs_normalise answers for cs_drop_heredocs' \
  "$HOOKS/lib/command-scan.sh" 'CS_NORMALISE ANSWERS FOR CS_DROP_HEREDOCS'

sourced_to_end

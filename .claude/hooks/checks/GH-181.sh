#!/bin/bash
# THE ISSUE FILE OF #181: no function in either boundary hook calls a function
# that writes a refusal, so the direct call count is the whole of what the arm
# count rests on.
#
# Why: GH-109.2 pins how many places each boundary hook writes a refusal to
# stderr, and a place stands for an arm only while the function holding it is
# written out at one call site. `fn_calls` counts those sites by token over the
# file's text, and an indirect call is not a token: with
# `wrap() { check_push "$1" "$2"; }` and two calls to `wrap`, ten writes sit on
# twenty paths while `arms` reads 19 and `fn_calls ... check_push` reads 1. The
# third review of PR #169 found it. What stood in its way was the function
# table GH-109.2 pins, which turns red when `wrap` is added -- and shows it as
# `wrap silent`, a row that reads harmless and that reconciling the table
# blesses, after which nothing asks how often `wrap` is called. #181's triage
# measured that on a copy of no-git-push.sh.
#
# THE SHAPE IS REFUSED, NOT COUNTED THROUGH. Counting paths is a call graph,
# and a reachability derivation is much more machinery than the count it
# defends; #181's triage rejected it. What is derived instead is the narrower
# claim that pins the count exactly: no function body in either hook names a
# function that writes. `writer_callers` prints each `<caller> <writer>` pair
# that breaks it, and the two hooks are asked for none. It is a caller of any
# kind: a silent wrapper, and a writer that calls a writer, itself included,
# since either multiplies the writes it reaches by the calls made to it.
#
# ONE LEVEL IS ENOUGH, and this is why. Any path from a call at the top level
# to a writer that passes through a function has a last function on it, and
# that function's body calls the writer directly -- which is the first level,
# and is refused. A wrapper of a wrapper cannot be written without a first
# level beneath it; its fixture below names the first-level pair and nothing
# else. So with the check empty, every call that reaches a writer is made from
# outside every function body, and `fn_calls` counts those correctly. That
# rests on every function being defined in column 1, which `nested_defs`
# holds for both hooks in #109's section: a function defined inside another is
# never entered here, as it is never entered by `fn_writes`.
#
# CALL SITES, NOT EXECUTIONS, which #109's section argues where `fn_calls` is
# and which is restated here because it is not a trade. `check_push`'s one
# call site is inside a `while` loop, so it runs once per fragment of a
# command, and that is the right reading: an arm is a place a refusal is
# written, not a time one is reached, and a loop adds no sentence to the file.
# A fixture below pins `fn_calls` reading 1 for one call site in a loop, so the
# reading is a check and not only prose.
#
# WHAT A BODY IS, and the one place it is wider than `fn_writes`. The rules
# for where a function opens and closes are `fn_writes`'s, and are listed in
# checks/library.sh beside the derivation. A definition line is different: a
# one-line wrapper keeps its call there, so what stands after the name and
# parentheses is read as the body -- including a line `fn_writes` does not
# read as a one-liner, such as a subshell body. The repository writes
# `name() {  # name <args> -- ...` on a definition, and a comment standing
# alone after the opening brace is not read, or a writer's usage line naming
# itself would read as a call to itself. Which functions write is NOT asked
# again: it is `fn_writes`'s answer, read through it, so this is never
# narrower than the table GH-109.2 pins, and never wider either.
#
# THE TRADES, taken knowingly; each is a fixture below asserting what the
# derivation does today, and each is in GH-181.1's note.
#   - A call through a variable, `$CALL "$1"` with CALL set outside the body,
#     is not a token of the writer's name.
#   - A call through `eval` whose text builds the name is not either.
#   - A writer defined in a file the hook sources is not in the hook's own
#     table, so a call to it is not a call to a writer. This is the stance
#     CLAUDE.md's consequence 6 takes: no amount of reading one file's text says
#     what another defines. Neither hook defines a writer outside its own file.
#   - A writer `fn_writes` calls silent is not a writer here, since the answer
#     is read and not re-derived: a write standing on a definition line that is
#     not a `;` `}` one-liner is attributed to no function. That is #338's. It
#     is a misleading red and not a green, because `arms` counts the write
#     wherever it stands, so adding such a writer moves GH-109.2's count.
#   - In the refusing direction, a body line naming a writer in a string or a
#     trailing comment reads as a call, and a definition line that closes its
#     body neither with `;` `}` nor on a later `}` in column 1 leaves the lines
#     after it attributed to that function. Both are false reds, visible and
#     one edit away, the trade CLAUDE.md's consequence 3 takes.
#
# WHAT IT TAKES FROM ELSEWHERE: $FIXTURES and $HOOKS from check-hooks.sh's
# prelude; $STDERR_WRITE, which `fn_writes` reads, from #109's section in the
# unsplit file; and `hook_text`, `fn_writes`, `fn_calls` and `writer_callers`
# from checks/library.sh.

section "=== issue #181: no function in a boundary hook calls a function that writes ==="

requirement GH-181.1 <<'REQ'
- text: No function defined in `no-git-push.sh` or `no-pr-decisions.sh` calls
  a function that writes to stderr: `writer_callers`, which prints each
  `<caller> <writer>` pair where a function body names a writer, prints nothing
  for either hook. Which functions write is `fn_writes`'s answer. A call is a
  token of the body, split as `fn_calls` splits one; a body is attributed on
  `fn_writes`'s rules, and includes what stands on a definition line after the
  name and parentheses, so a one-line wrapper is read and a comment standing
  alone after the opening brace is not. A silent wrapper around a writer is
  refused, and so is a writer that calls a writer, itself included. So only
  calls from outside every function body reach a writer, and `fn_calls`, which
  counts those, is the whole of what GH-109.2's arm count rests on.
- from: #181, the third review of PR #169
- kind: defect-permitting
- status: active
- direction: static: a property of the hooks' source, read by the suite's helpers
- note: The defect was the suite's and not a hook's: a wrapper called from two
  places doubled the arms it held while every count stayed green, and the
  function table showed the wrapper as a harmless `silent` row. One level is
  enough, since any path through a function to a writer ends in a function
  that calls the writer directly; it rests on column-1 definitions, which
  `nested_defs` holds. Not seen, and asserted as such: a call through a
  variable, a call through `eval` that builds the name, a writer defined in a
  sourced file (CLAUDE.md's consequence 6), and a writer `fn_writes` calls
  silent because its write stands on a definition line (#338). A body line
  naming a writer in a string or trailing comment reads as a call, a false
  red. Not in the invariance families' scope: like GH-157's entries it is a
  static property of a file's text, and there is no command to rewrite.
REQ
shape_pin 'GH-181.1:static'

R181="$FIXTURES/r181"
mkdir -p "$R181"
# A WRITER CALLED ONLY FROM THE TOP LEVEL, inside a loop, with the usage comment
# the repository writes on a definition naming the writer itself.
cat > "$R181/top-level-only.sh" <<'R181_EOF'
speaks() {  # speaks <msg> -- names speaks in its own usage line
  echo "refused" >&2
}
silent() {
  return 0
}
while read -r x; do
  speaks "$x"
done
R181_EOF
# #181's own shape, the triage's reproduction: a silent wrapper called twice.
cat > "$R181/wrapper.sh" <<'R181_EOF'
speaks() {
  echo "refused" >&2
}
wrap() {
  speaks "$1"
}
wrap a
wrap b
R181_EOF
cat > "$R181/wrapper-of-wrapper.sh" <<'R181_EOF'
speaks() {
  echo "refused" >&2
}
wrap() {
  speaks "$1"
}
outer() {
  wrap "$1"
}
outer a
outer b
R181_EOF
cat > "$R181/writer-calls-writer.sh" <<'R181_EOF'
speaks() {
  echo "refused" >&2
}
shouts() {
  echo "REFUSED" >&2
  speaks "$1"
}
shouts a
R181_EOF
cat > "$R181/writer-calls-itself.sh" <<'R181_EOF'
speaks() {
  echo "refused" >&2
  [ -n "$2" ] && speaks "$2"
}
speaks a b
R181_EOF
cat > "$R181/one-line-wrapper.sh" <<'R181_EOF'
speaks() {
  echo "refused" >&2
}
wrap() { speaks "$1"; }
wrap a
wrap b
R181_EOF
# The two definition lines `fn_writes` does not read as one-liners, whose call
# stands on the definition line all the same.
cat > "$R181/subshell-wrapper.sh" <<'R181_EOF'
speaks() {
  echo "refused" >&2
}
wrap() ( speaks "$1" )
R181_EOF
cat > "$R181/body-opens-on-the-definition-line.sh" <<'R181_EOF'
speaks() {
  echo "refused" >&2
}
wrap() { speaks "$1"
  return 0
}
wrap a
R181_EOF
# The trades.
cat > "$R181/through-a-variable.sh" <<'R181_EOF'
speaks() {
  echo "refused" >&2
}
CALL=speaks
wrap() {
  $CALL "$1"
}
wrap a
wrap b
R181_EOF
cat > "$R181/through-eval.sh" <<'R181_EOF'
speaks() {
  echo "refused" >&2
}
wrap() {
  eval "spe""aks \"\$1\""
}
wrap a
wrap b
R181_EOF
cat > "$R181/sourced-writer.sh" <<'R181_EOF'
. "$(dirname "$0")/speaks.sh"
wrap() {
  speaks "$1"
}
wrap a
wrap b
R181_EOF
cat > "$R181/write-on-the-definition-line.sh" <<'R181_EOF'
speaks() { echo "refused" >&2
  return 1
}
wrap() {
  speaks "$1"
}
wrap a
wrap b
R181_EOF
cat > "$R181/writer-named-in-a-string.sh" <<'R181_EOF'
speaks() {
  echo "refused" >&2
}
usage() {
  echo "run speaks with a message"
}
speaks a
R181_EOF
[ -s "$R181/top-level-only.sh" ] && [ -s "$R181/writer-named-in-a-string.sh" ] || {
  echo "the #181 fixtures were not written; the checks against them prove nothing" >&2
  exit 1
}

req GH-181.1
tok 'writer_callers reads nothing for a writer called only from the top level, its usage line naming itself' \
    '' "$(writer_callers "$R181/top-level-only.sh")"
tok 'it names a silent wrapper around a writer, which fn_calls cannot count through' \
    'wrap speaks' "$(writer_callers "$R181/wrapper.sh")"
tok 'it names the first level of a wrapper of a wrapper, which is all it has to name' \
    'wrap speaks' "$(writer_callers "$R181/wrapper-of-wrapper.sh")"
tok 'it names a writer that calls another writer' \
    'shouts speaks' "$(writer_callers "$R181/writer-calls-writer.sh")"
tok 'and a writer that calls itself' \
    'speaks speaks' "$(writer_callers "$R181/writer-calls-itself.sh")"
tok 'it names a one-line wrapper, whose call stands on its definition line' \
    'wrap speaks' "$(writer_callers "$R181/one-line-wrapper.sh")"
tok 'and a subshell wrapper, a definition line fn_writes does not read as a one-liner' \
    'wrap speaks' "$(writer_callers "$R181/subshell-wrapper.sh")"
tok 'and a body that opens on its definition line and closes on a later one' \
    'wrap speaks' "$(writer_callers "$R181/body-opens-on-the-definition-line.sh")"
# The trades, asserted as what the derivation does rather than as what one
# would want.
tok 'it does not see a call through a variable, which is a trade' \
    '' "$(writer_callers "$R181/through-a-variable.sh")"
tok 'nor a call through eval that builds the name, which is a trade' \
    '' "$(writer_callers "$R181/through-eval.sh")"
tok 'nor a writer defined in a sourced file, which is a trade' \
    '' "$(writer_callers "$R181/sourced-writer.sh")"
tok 'nor a writer fn_writes calls silent, its write on the definition line, which is #338' \
    '' "$(writer_callers "$R181/write-on-the-definition-line.sh")"
tok 'and it reads a writer named in a string as a call, the false red it accepts' \
    'usage speaks' "$(writer_callers "$R181/writer-named-in-a-string.sh")"
req GH-109.2 GH-181.1
tok 'fn_calls reads one call site inside a loop as one, since an arm is a place and not a time' \
    '1' "$(fn_calls "$R181/top-level-only.sh" speaks)"

# THE HOOKS. no-pr-decisions.sh defines no writer, so its row is empty for that
# reason today, and is evidence the day one of its functions writes.
req GH-181.1
tok 'no function in no-git-push.sh calls a function that writes' \
    '' "$(writer_callers "$HOOKS/no-git-push.sh")"
tok 'no function in no-pr-decisions.sh calls a function that writes' \
    '' "$(writer_callers "$HOOKS/no-pr-decisions.sh")"

# AND IT READS THE HOOK THROUGH `hook_text` AND `fn_writes`, AND NOTHING ELSE,
# the question checks/GH-182.sh asks of the three counters, asked of their
# fourth. Two reads and not one, since the writer set is `fn_writes`'s; with
# both taken out, no `$1`, `$@` or `$*` is left, braced or not, and no drop or
# `sed` of its own. Read off the definition as bash holds it.
R181_BODY=$(declare -f writer_callers)
R181_REST=${R181_BODY//'hook_text "$1"'/}
R181_REST=${R181_REST//'fn_writes "$1"'/}
if [[ $R181_BODY == *'hook_text "$1"'* && $R181_BODY == *'fn_writes "$1"'* \
      && $R181_REST != *cs_drop_heredocs* && $R181_REST != *'sed '* ]] \
   && ! [[ $R181_REST =~ \$\{?(1|[@*]) ]]; then
  pass static 'writer_callers reads the hook through hook_text and fn_writes, and names it nowhere else'
else
  fail static 'writer_callers reads the hook through something besides hook_text and fn_writes, or through neither'
fi

sourced_to_end

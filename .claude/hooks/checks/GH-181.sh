#!/bin/bash
# THE ISSUE FILE OF #181: no function in either boundary hook calls a function
# that writes a refusal, so the direct call count is the whole of what the arm
# count rests on, as far as the hooks' text can say it.
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
# else. So with the check empty, every call the text shows reaching a writer is
# made from outside every function body, and `fn_calls` counts those
# correctly; the trades below are the calls the text does not show. That rests
# on two conventions the derivations share, each held rather than assumed:
# every function is defined in column 1, which `nested_defs` holds for both
# hooks in #109's section, and every function is named as an identifier,
# which GH-181.2 holds below.
#
# A NAME THE PATTERNS CANNOT READ IS REFUSED, NOT READ, and review of #181's
# pull request is why. Bash accepts `wrap-it() { ... }`, and `fn_writes`,
# `nested_defs` and `writer_callers` all read a name as an identifier, so such
# a wrapper around a writer was attributed to nothing: no pair, no row in the
# function table, `fn_calls` still 1, and nothing red at all -- a hole wider
# than the one #181 was filed on, since even the table's tripwire did not fire.
# Widening three patterns to bash's name grammar is the widening the unsplit
# file's `nested_defs` paragraph declines for the same reason; `odd_names`
# asks instead for every definition in either hook, at any indent and in
# either form, to be named as an identifier. It reads `hook_text`, so a
# definition inside a heredoc body or a comment is not one, and it prints the
# line and not a number, since the fold moves the numbers.
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
# for where a function opens and closes are `fn_writes`'s, and are listed below
# beside the derivation; a check below holds `writer_callers` to carrying each
# of `fn_writes`'s patterns, so that #338 or the next widening of `fn_writes`
# cannot leave this copy behind. A definition line is different: a one-line
# wrapper keeps its call there, so what stands after the name and parentheses
# is read as the body -- including a line `fn_writes` does not read as a
# one-liner, such as a subshell body. The repository writes
# `name() {  # name <args> -- ...` on a definition, and a comment standing
# alone after the opening brace is not read, or a writer's usage line naming
# itself would read as a call to itself. Which functions write is NOT asked
# again: it is `fn_writes`'s answer, read through it, so this is never
# narrower than the table GH-109.2 pins, and never wider either.
#
# THE TRADES, taken knowingly; each is a fixture below asserting what the
# derivation does today, and each is in GH-181.1's note. Three are calls the
# text does not name:
#   - A call through a variable, `$CALL "$1"` with CALL set outside the body,
#     is not a token of the writer's name.
#   - A call through `eval` whose text builds the name is not either.
#   - A writer defined in a file the hook sources is not in the hook's own
#     table, so a call to it is not a call to a writer. This is the stance
#     CLAUDE.md's consequence 6 takes: no amount of reading one file's text says
#     what another defines. Neither hook defines a writer outside its own file.
# One is text the counters drop:
#   - A call inside a heredoc body, `$(speaks "$1")` under an unquoted
#     delimiter, is dropped with the body by `hook_text`, as a write there is.
#     Heredoc bodies are #182's and are read as data; a body that runs code is
#     not a shape either hook writes.
# And three are a body attributed to the wrong function, where `fn_writes`'s
# rules misread where a function starts or ends. Each is a misleading red and
# not a green, the class the unsplit file's #109 section names for a
# one-liner: the table gains a row, so the run goes red, but the row it shows
# reads harmless, and reconciling to it blesses the wrapper.
#   - A writer `fn_writes` calls silent is not a writer here, since the answer
#     is read and not re-derived: a write standing on a definition line that is
#     not a `;` `}` one-liner is attributed to no function. That is #338's, and
#     here `arms` moves as well, since it counts the write wherever it stands.
#   - A definition line that ends in `;` `}` without closing its body --
#     `wrap() { [ -n "$1" ] || { return; }` -- is read as a one-liner, so the
#     lines after it belong to no function.
#   - A `}` in column 1 inside a body, the last line of a multi-line string,
#     closes the function early, so the lines after it belong to no function.
#     The same rule #182 closed for a heredoc body, and a string is not one.
# In the refusing direction, a body line naming a writer in a string or a
# trailing comment reads as a call, and a definition line that closes its
# body neither with `;` `}` nor on a later `}` in column 1 leaves the lines
# after it attributed to that function. Both are false reds, visible and one
# edit away, the trade CLAUDE.md's consequence 3 takes.
#
# WHAT IT TAKES FROM ELSEWHERE: $FIXTURES and $HOOKS from check-hooks.sh's
# prelude; $STDERR_WRITE, which `fn_writes` reads, from #109's section in the
# unsplit file; and `hook_text`, `fn_writes`, `fn_calls` and
# `reads_only_through` from checks/library.sh. `writer_callers` and
# `odd_names` are this file's own, defined below.

section "=== issue #181: no function in a boundary hook calls a function that writes ==="

requirement GH-181.1 <<'REQ'
- text: No function defined in `no-git-push.sh` or `no-pr-decisions.sh` calls
  a function that writes to stderr: `writer_callers`, which prints each
  `<caller> <writer>` pair where a function body names a writer, prints nothing
  for either hook. Which functions write is `fn_writes`'s answer. A call is a
  token of the body, split as `fn_calls` splits one; a body is attributed on
  `fn_writes`'s rules, and `writer_callers` carries each of `fn_writes`'s
  patterns, and includes what stands on a definition line after the name and
  parentheses, so a one-line wrapper is read and a comment standing alone
  after the opening brace is not. A silent wrapper around a writer is refused,
  and so is a writer that calls a writer, itself included. So every call the
  text shows reaching a writer is made from outside every function body, and
  `fn_calls`, which counts those, is what GH-109.2's arm count rests on; the
  calls the text does not show are this entry's note.
- from: #181, the third review of PR #169
- kind: defect-permitting
- status: active
- direction: static: a property of the hooks' source, read by the suite's helpers
- note: The defect was the suite's and not a hook's: a wrapper called from two
  places doubled the arms it held while every count stayed green, and the
  function table showed the wrapper as a harmless `silent` row. One level is
  enough, since any path through a function to a writer ends in a function
  that calls the writer directly; it rests on column-1 definitions, which
  `nested_defs` holds, and identifier names, which GH-181.2 holds. Not seen,
  and asserted as such: a call through a variable, a call through `eval` that
  builds the name, a writer defined in a sourced file (CLAUDE.md's
  consequence 6), and a call inside a heredoc body, which the counters drop
  (#182). Attributed to the wrong function, each a misleading red since the
  table gains a row that reads harmless: a writer `fn_writes` calls silent
  because its write stands on a definition line (#338), a definition line
  ending in `;` `}` that does not close its body, and a `}` in column 1 inside
  a multi-line string. A body line naming a writer in a string or trailing
  comment reads as a call, a false red. Not in the invariance families'
  scope: like GH-157's entries it is a static property of a file's text, and
  there is no command to rewrite.
REQ
requirement GH-181.2 <<'REQ'
- text: Every function defined in `no-git-push.sh` or `no-pr-decisions.sh`,
  at any indent and in either form, `name()` or `function name`, is named as
  an identifier -- a letter or `_`, then letters, digits or `_` -- which is the
  name `fn_writes`, `nested_defs` and `writer_callers` read:
  `odd_names`, which prints each definition whose name is anything else, prints
  nothing for either hook. It reads the hook as the counters do, so a
  definition in a comment or a heredoc body is not one.
- from: review of #181's pull request
- kind: defect-permitting
- status: active
- direction: static: a property of the hooks' source, read by the suite's helpers
- note: Found by review of #181's pull request, not filed. Bash accepts
  `wrap-it() { check_push "$1" "$2"; }`, and each derivation read the name as
  an identifier and so saw no definition: the wrapper had no pair, no row in
  the function table, and `fn_calls check_push` still read 1, so nothing went
  red. Refused rather than read, as `nested_defs` refuses an indented
  definition, because widening three patterns to bash's name grammar is the
  widening that paragraph declines. A definition written some way the two
  forms do not cover -- a name with a quote in it, or split across a
  continuation the fold does not join -- is not seen. Not in the invariance
  families' scope, for GH-181.1's reason.
REQ
shape_pin 'GH-181.1:static GH-181.2:static'

# THE CALLERS OF A WRITER, which `fn_calls` cannot count: #181's derivation,
# here and not in checks/library.sh beside the three counters, because this
# file is its one caller and the library holds only what more than one section
# calls. It reads the hook through two of them. Which functions write is
# `fn_writes`'s answer, read and not re-derived, so this cannot be narrower
# than the table GH-109.2 pins. Which function a line belongs to is asked again,
# on `fn_writes`'s rules -- a definition in column 1 opens one, a `}` in column
# 1 closes it, a line ending `;` then `}` closes its own -- with one widening:
# what stands on a definition line after its name and parentheses is that
# function's body, which is where a one-line wrapper keeps its call, and a
# comment standing alone after the opening brace is not. A call is a token,
# split as `fn_calls` splits one.
writer_callers() {  # writer_callers <file> -- "<caller> <writer>" a line, for a function body naming a writer; sorted
  hook_text "$1" \
    | awk -v WR="$(fn_writes "$1" | awk 'sub(/ writes$/, "") { printf "%s ", $0 }')" '
        BEGIN { n = split(WR, a, " "); for (i = 1; i <= n; i++) wr[a[i]] = 1 }
        {
          owner = ""
          if ($0 ~ /^function[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/ || $0 ~ /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)/) {
            fn = $0; sub(/^function[[:space:]]+/, "", fn); sub(/[[:space:](){].*/, "", fn)
            body = $0; sub(/^function[[:space:]]+/, "", body)
            sub(/^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*(\(\))?/, "", body)
            sub(/^[[:space:]]*\{[[:space:]]+#.*$/, "", body)
            owner = fn
            if ($0 ~ /;[[:space:]]*\}[[:space:]]*$/) fn = ""
          } else if ($0 ~ /^\}/) {
            fn = ""
          } else {
            owner = fn; body = $0
          }
          if (owner == "") next
          n = split(body, t, /[^A-Za-z0-9_$-]+/)
          for (i = 1; i <= n; i++) if (t[i] in wr) print owner, t[i]
        }' \
    | LC_ALL=C sort -u
}
# THE NAMES THE PATTERNS CANNOT READ, GH-181.2's. A definition is a line whose
# first word, at any indent, is followed by `()`, or a line whose first word is
# `function`; its name is reported when it is not an identifier. A first word
# holding `#`, `=` or a parenthesis is not a name, so a comment, an assignment
# and a command substitution are not read as definitions.
odd_names() {  # odd_names <file> -- each definition line whose name is not an identifier
  hook_text "$1" \
    | awk '
        /^[[:space:]]*function[[:space:]]+[^[:space:]]/ {
          n = $0; sub(/^[[:space:]]*function[[:space:]]+/, "", n); sub(/[[:space:]({].*/, "", n)
          if (n !~ /^[A-Za-z_][A-Za-z0-9_]*$/) print
          next
        }
        /^[[:space:]]*[^[:space:]#=()]+[[:space:]]*\(\)/ {
          n = $0; sub(/^[[:space:]]*/, "", n); sub(/[[:space:]]*\(\).*/, "", n)
          if (n !~ /^[A-Za-z_][A-Za-z0-9_]*$/) print
        }'
}

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
cat > "$R181/call-in-a-heredoc.sh" <<'R181_EOF'
speaks() {
  echo "refused" >&2
}
wrap() {
  cat <<EOF
$(speaks "$1")
EOF
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
cat > "$R181/definition-line-ends-like-a-one-liner.sh" <<'R181_EOF'
speaks() {
  echo "refused" >&2
}
wrap() { [ -n "$1" ] || { return; }
  speaks "$1"
}
wrap a
wrap b
R181_EOF
cat > "$R181/brace-in-a-string.sh" <<'R181_EOF'
speaks() {
  echo "refused" >&2
}
wrap() {
  msg="a
}"
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
# GH-181.2's: every spelling of a name the patterns cannot read, in both forms
# and indented, and beside them what is not a definition at all.
cat > "$R181/odd-names.sh" <<'R181_EOF'
speaks() {
  echo "refused" >&2
}
wrap-it() { speaks "$1"; }
wrap.it() {
  speaks "$1"
}
function wrap:it {
  speaks "$1"
}
  in-dented() { speaks "$1"; }
wrap-it a
R181_EOF
cat > "$R181/plain-names.sh" <<'R181_EOF'
speaks() {
  echo "refused" >&2
}
function shouts {
  echo "x" >&2
}
awk '
    function shut() { st = 0 }
' "$1"
x=$(printf '%s' "a()")
# not-a-name() is a comment
[ "$a" = "b" ] && echo "f() is not a definition"
speaks a
R181_EOF
[ -s "$R181/top-level-only.sh" ] && [ -s "$R181/plain-names.sh" ] || {
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
tok 'nor a call inside a heredoc body, which the counters drop, a trade' \
    '' "$(writer_callers "$R181/call-in-a-heredoc.sh")"
tok 'nor a writer fn_writes calls silent, its write on the definition line, which is #338' \
    '' "$(writer_callers "$R181/write-on-the-definition-line.sh")"
tok 'nor a call after a definition line that ends in ; } without closing its body, a misleading red' \
    '' "$(writer_callers "$R181/definition-line-ends-like-a-one-liner.sh")"
tok 'nor a call after a } in column 1 inside a string, a misleading red' \
    '' "$(writer_callers "$R181/brace-in-a-string.sh")"
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
# fourth reader through the helper both ask it with. Two reads and not one,
# since the writer set is `fn_writes`'s.
if reads_only_through writer_callers hook_text fn_writes; then
  pass static 'writer_callers reads the hook through hook_text and fn_writes, and names it nowhere else'
else
  fail static 'writer_callers reads the hook through something besides hook_text and fn_writes, or through neither'
fi

# AND IT CARRIES EVERY PATTERN `fn_writes` DOES, so the two copies of the rules
# for where a function opens and closes cannot part silently: widening
# `fn_writes` -- #338 would -- turns this red until `writer_callers` is widened
# with it. Read off both definitions as bash holds them: every awk regex
# literal in `fn_writes`, which holds none with a `/` or a blank in it, is
# asked for in `writer_callers` as fixed text. The count is a literal, so a
# read that finds none is red rather than vacuous. It asks one direction:
# `writer_callers`'s one widening is its own, and is argued above.
R181_FW_PATTERNS=$(declare -f fn_writes | grep -oE '/[^/[:space:]]+/' | LC_ALL=C sort -u)
tok "fn_writes's patterns are read, all six of them" \
    '6' "$(printf '%s\n' "$R181_FW_PATTERNS" | grep -c .)"
R181_WC_BODY=$(declare -f writer_callers)
tok 'and writer_callers carries each of them' \
    '' "$(printf '%s\n' "$R181_FW_PATTERNS" | while IFS= read -r p; do
            [ -n "$p" ] && [[ $R181_WC_BODY != *"$p"* ]] && printf '%s ' "$p"
          done)"

req GH-181.2
tok 'odd_names reads every definition whose name is not an identifier, in both forms and indented' \
    'wrap-it() { speaks "$1"; }
wrap.it() {
function wrap:it {
  in-dented() { speaks "$1"; }' "$(odd_names "$R181/odd-names.sh")"
tok 'and nothing that is not a definition, nor awk spelling its own, nor a plain name' \
    '' "$(odd_names "$R181/plain-names.sh")"
tok 'no function in no-git-push.sh is named but as an identifier' \
    '' "$(odd_names "$HOOKS/no-git-push.sh")"
tok 'no function in no-pr-decisions.sh is named but as an identifier' \
    '' "$(odd_names "$HOOKS/no-pr-decisions.sh")"

sourced_to_end

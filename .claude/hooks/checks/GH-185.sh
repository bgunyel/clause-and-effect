#!/bin/bash
# THE ISSUE FILE OF #185: `dup_stderr` reaches every spelling of the text that
# points a descriptor other than 1 at stderr.
#
# Why: the #109 section in the unsplit file refuses a duplicated descriptor in
# both boundary hooks, because a write through one -- `exec 3>&2` once, then
# `>&3` -- escapes `arms` and `fn_writes` at the same time. The guard's contract
# was any fd but 1 pointed at 2, and its pattern was
# `(^|[^0-9])[03-9]>&[[:space:]]*2`: a single digit, duplicated with `>&`. The
# sixth review of PR #169 named two spellings it missed, `exec 3>/dev/stderr`
# and `exec 10>&2`, and #185's triage ran the pattern against five more and
# found it missing all of them: `exec {fd}>&2`, `exec 3<&2`,
# `exec 3>>/dev/stderr`, `exec 3>/dev/fd/2` and `exec 3</dev/fd/2`. Every one
# is the permitting direction, and neither hook writes any of them today.
#
# WHAT IS DRIVEN is `dup_stderr`, in the library since this issue made this
# file its second caller, against one fixture per shape, each written below
# with the shape on its second line. A reported shape is asserted as
# `2:<shape>`, the output the guard prints; a clean one as the empty string. Each
# must-flag row was run once against the old pattern and failed there, with the
# old pattern's empty output; that run is recorded in the pull request, since a
# check that restores the old pattern would be a check of a function nobody
# calls.
#
# WHAT IS NOT HERE is `exec 3>&2`, the triage's first row, which the unsplit
# file's #109 section already drives against its own fixture, and which moved
# nowhere.

section "=== issue #185: dup_stderr reaches every spelling of a descriptor pointed at stderr ==="

requirement GH-185 <<'REQ'
- text: `dup_stderr <file>` reports, as `<line>:<text>` space-joined, every
  line that points a descriptor other than 1 at stderr: a source written as a
  single digit other than 1, as a number of two digits or more, or as a
  `{name}`, or left implicit on `<`, `<&` or `<>`, where it is 0; a target of
  fd 2 after `>&` or `<&`, or of `/dev/stderr`, `/dev/fd/2` or
  `/proc/<anything>/fd/2` after `>`, `>>`, `>|`, `<` or `<>`; blanks and one
  quote allowed before the target. Continuations are folded first and a folded
  line is reported under its first line's number. It reports nothing for fd 1,
  written or implicit, whatever spelling points it at stderr -- `>&2`, `1>&2`,
  `>/dev/stderr`, `1>/dev/stderr`, `>>`, `>|` and `&>` -- nor for `2>&1`,
  `>/dev/null 2>&1` or a here-string naming `/dev/stderr`. `no-git-push.sh`,
  `no-pr-decisions.sh` and `lib/command-scan.sh`, which both source, report
  nothing.
- from: #185, the sixth review of PR #169, and #185's triage
- kind: defect-permitting
- status: active
- direction: static: a property of the suite's helpers
- note: What it does not reach is dataflow, which is why the shape is refused
  rather than counted: a target or a source held in a variable,
  `exec 3>"$dest"` or `exec 3>&$err`; a descriptor inherited from the process
  that runs the hook; and a path reaching stderr by another spelling,
  `//dev/stderr` or a symlink. Two trades are taken in the refusing direction:
  `<` and `<>` by path open a read-only descriptor on Linux, so a write through
  one fails -- measured -- and they are reported anyway, as the triage asked;
  and fd 2 reopened onto itself, `2>/dev/stderr`, is reported though it hides
  nothing, because the contract is any fd but 1. Heredoc bodies are not
  dropped, so a body line naming the shape is a red. fd 1 by `/dev/fd/2` is a
  plain refusal that `arms` does not count, which is #263's and not this
  guard's.
REQ
# Only a shape pin. GH-185 is not in the invariance families' scope: those
# rewrite a command a hook judges, and this is a static check on hook source,
# so it has no `variants` field and nothing for `variants_pin` to pin.
shape_pin 'GH-185:static'

# THE FIXTURES, a file each: a shebang, which the comment strip blanks, the
# shape on line 2, and `exit 0`. A fixture that failed to be written would read
# as clean, and the clean rows would pass on nothing, so each is held to its
# line count before any row reads it.
R185_DIR="$FIXTURES/r185"
mkdir -p "$R185_DIR"
r185_fixture() {  # r185_fixture <name> <line>... -- $R185_DIR/<name>.sh, those lines between a shebang and exit 0
  local name="$1"
  shift
  printf '%s\n' '#!/bin/bash' "$@" 'exit 0' > "$R185_DIR/$name.sh"
  [ "$(wc -l < "$R185_DIR/$name.sh" | tr -d ' ')" = "$(( $# + 2 ))" ] || {
    echo "the #185 fixture $name.sh was not written; the checks against it prove nothing" >&2
    exit 1
  }
}

req GH-185
# THE TWO SPELLINGS THE SIXTH REVIEW OF PR #169 NAMED.
r185_fixture by-name 'exec 3>/dev/stderr'
r185_fixture by-name-spaced 'exec 3> /dev/stderr'
r185_fixture two-digit 'exec 10>&2'
tok 'dup_stderr reports an fd pointed at stderr by name rather than by number' \
    '2:exec 3>/dev/stderr' "$(dup_stderr "$R185_DIR/by-name.sh")"
tok 'and with a blank before the name' \
    '2:exec 3> /dev/stderr' "$(dup_stderr "$R185_DIR/by-name-spaced.sh")"
tok 'dup_stderr reports a two-digit fd, which the leading [^0-9] could not match into' \
    '2:exec 10>&2' "$(dup_stderr "$R185_DIR/two-digit.sh")"

# THE FIVE #185's TRIAGE FOUND.
r185_fixture named-fd 'exec {fd}>&2'
r185_fixture input-dup 'exec 3<&2'
r185_fixture append 'exec 3>>/dev/stderr'
r185_fixture dev-fd 'exec 3>/dev/fd/2'
r185_fixture dev-fd-input 'exec 3</dev/fd/2'
tok 'dup_stderr reports a named fd, which bash allocates at 10 or above' \
    '2:exec {fd}>&2' "$(dup_stderr "$R185_DIR/named-fd.sh")"
tok 'dup_stderr reports an input duplication, which copies fd 2 whole' \
    '2:exec 3<&2' "$(dup_stderr "$R185_DIR/input-dup.sh")"
tok 'dup_stderr reports stderr by name, opened for appending' \
    '2:exec 3>>/dev/stderr' "$(dup_stderr "$R185_DIR/append.sh")"
tok 'dup_stderr reports stderr as /dev/fd/2' \
    '2:exec 3>/dev/fd/2' "$(dup_stderr "$R185_DIR/dev-fd.sh")"
tok 'and as /dev/fd/2 opened for input' \
    '2:exec 3</dev/fd/2' "$(dup_stderr "$R185_DIR/dev-fd-input.sh")"

# THE TRIAGE TABLE'S /proc ROWS, and the pid spellings beside self.
r185_fixture proc-self 'exec 3>/proc/self/fd/2'
r185_fixture proc-self-input 'exec 3</proc/self/fd/2'
r185_fixture proc-pid 'exec 3>/proc/$$/fd/2'
tok 'dup_stderr reports stderr as /proc/self/fd/2' \
    '2:exec 3>/proc/self/fd/2' "$(dup_stderr "$R185_DIR/proc-self.sh")"
tok 'and as /proc/self/fd/2 opened for input' \
    '2:exec 3</proc/self/fd/2' "$(dup_stderr "$R185_DIR/proc-self-input.sh")"
tok 'and as /proc/<pid>/fd/2 with the pid spelled as a parameter' \
    '2:exec 3>/proc/$$/fd/2' "$(dup_stderr "$R185_DIR/proc-pid.sh")"

# THE REST OF THE OPERATORS AND THE QUOTES, which the triage's grammar names and
# its table does not.
r185_fixture clobber 'exec 3>|/dev/stderr'
r185_fixture read-write 'exec 3<>/dev/stderr'
r185_fixture quoted-path 'exec 3>"/dev/stderr"'
r185_fixture single-quoted-path "exec 3>'/dev/fd/2'"
r185_fixture quoted-fd 'exec 3>&"2"'
tok 'dup_stderr reports stderr by name after >|' \
    '2:exec 3>|/dev/stderr' "$(dup_stderr "$R185_DIR/clobber.sh")"
tok 'and after <>' \
    '2:exec 3<>/dev/stderr' "$(dup_stderr "$R185_DIR/read-write.sh")"
tok 'dup_stderr reports a double-quoted path' \
    '2:exec 3>"/dev/stderr"' "$(dup_stderr "$R185_DIR/quoted-path.sh")"
tok 'and a single-quoted one' \
    "2:exec 3>'/dev/fd/2'" "$(dup_stderr "$R185_DIR/single-quoted-path.sh")"
tok 'dup_stderr reports a quoted fd 2, which bash duplicates as the bare one' \
    '2:exec 3>&"2"' "$(dup_stderr "$R185_DIR/quoted-fd.sh")"

# FD 0, WRITTEN AND IMPLICIT. The implicit fd of an input operator is 0, and
# `exec <&2` then `>&0` writes to stderr, so an implicit fd stays unreported
# only on an output operator, where it is 1.
r185_fixture fd-zero 'exec 0<&2'
r185_fixture implicit-input-dup 'exec <&2'
r185_fixture implicit-input-path 'exec </dev/stderr'
tok 'dup_stderr reports fd 0 written out' \
    '2:exec 0<&2' "$(dup_stderr "$R185_DIR/fd-zero.sh")"
tok 'and fd 0 left implicit on <&, which is the same duplication' \
    '2:exec <&2' "$(dup_stderr "$R185_DIR/implicit-input-dup.sh")"
tok 'and fd 0 left implicit on < by path' \
    '2:exec </dev/stderr' "$(dup_stderr "$R185_DIR/implicit-input-path.sh")"

# FD 2 ONTO ITSELF, reported because the contract is any fd but 1; it hides
# nothing, and the requirement's note records the trade.
r185_fixture fd-two 'exec 2>/dev/stderr'
tok 'dup_stderr reports fd 2 reopened onto stderr, the refusing-direction trade' \
    '2:exec 2>/dev/stderr' "$(dup_stderr "$R185_DIR/fd-two.sh")"

# A CONTINUATION, folded as `hook_text` folds for the counters, and a line after
# it: the fold is reported under its first line, and the count below it holds.
r185_fixture continued 'exec 3>\' '/dev/stderr' 'exec 4>&2'
tok 'dup_stderr reports a redirection split by a continuation, under its first line, and the line after it by its own number' \
    '2:exec 3>/dev/stderr 4:exec 4>&2' "$(dup_stderr "$R185_DIR/continued.sh")"

# WHAT STAYS CLEAN: fd 1, written or implicit, in every spelling, and the
# ordinary shapes the hooks carry. fd 1 by /dev/fd/2 is a refusal `arms` does
# not count, which is #263's.
r185_fixture implicit-dup 'echo "refused" >&2'
r185_fixture one-dup 'echo "refused" 1>&2'
r185_fixture implicit-name 'echo "refused" >/dev/stderr'
r185_fixture one-name 'echo "refused" 1>/dev/stderr'
r185_fixture implicit-append 'echo "refused" >>/dev/stderr'
r185_fixture implicit-clobber 'echo "refused" >|/dev/stderr'
r185_fixture both-streams 'echo "refused" &>/dev/stderr'
r185_fixture one-dev-fd 'echo "refused" 1>/dev/fd/2'
r185_fixture two-to-one 'git fetch 2>&1'
r185_fixture null-and-two 'git fetch >/dev/null 2>&1'
r185_fixture here-string 'cat <<< /dev/stderr'
tok 'dup_stderr does not report >&2, the implicit fd 1' \
    '' "$(dup_stderr "$R185_DIR/implicit-dup.sh")"
tok 'nor 1>&2' \
    '' "$(dup_stderr "$R185_DIR/one-dup.sh")"
tok 'nor >/dev/stderr' \
    '' "$(dup_stderr "$R185_DIR/implicit-name.sh")"
tok "nor 1>/dev/stderr, which the issue's first proposed pattern reported" \
    '' "$(dup_stderr "$R185_DIR/one-name.sh")"
tok 'nor >>/dev/stderr' \
    '' "$(dup_stderr "$R185_DIR/implicit-append.sh")"
tok 'nor >|/dev/stderr' \
    '' "$(dup_stderr "$R185_DIR/implicit-clobber.sh")"
tok 'nor &>/dev/stderr, which points fd 1 and fd 2 at it' \
    '' "$(dup_stderr "$R185_DIR/both-streams.sh")"
tok 'nor 1>/dev/fd/2' \
    '' "$(dup_stderr "$R185_DIR/one-dev-fd.sh")"
tok 'nor 2>&1, which points 2 at 1' \
    '' "$(dup_stderr "$R185_DIR/two-to-one.sh")"
tok 'nor >/dev/null 2>&1' \
    '' "$(dup_stderr "$R185_DIR/null-and-two.sh")"
tok 'nor a here-string naming /dev/stderr, which is text and not an input operator' \
    '' "$(dup_stderr "$R185_DIR/here-string.sh")"

# THE LIBRARY BOTH HOOKS SOURCE, which the unsplit file's two rows do not ask:
# a descriptor it opened is open in the hook that sourced it.
req GH-185 GH-109.2
tok 'lib/command-scan.sh, which both hooks source, points no other fd at 2' \
    '' "$(dup_stderr "$HOOKS/lib/command-scan.sh")"

sourced_to_end

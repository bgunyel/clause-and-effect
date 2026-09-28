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
# with the shape from its second line on: one line for most, and more for a
# continuation, a heredoc and a shape spread over two lines. A reported shape
# is asserted as `<line>:<shape>`, the output the guard prints; a clean one as
# the empty string. Each must-flag row was run against the old pattern, and
# each failed there -- every one empty but the continuation, which printed
# only its line 4 -- but those the old pattern reached too, each here for a
# clause of the new one: `exec 3>& 2`, a blank after `>&`; a source at the
# start of a line and right after a backtick, `(`, `)` or `|`, which pin where
# the new one reads a word start and which the old one read after any
# non-digit; and `3>&2 exec` after a comment ending in a backslash, which the
# old one read line by line and this pull request's fold had hidden. That run
# is recorded in the pull request, since a check that restores the
# old pattern would be a check of a function nobody calls. A shape the guard
# does not reach is asserted as the empty string too, beside the clean ones,
# and says so in its row; a trade is asserted as what the guard prints, and
# its row says it is a trade.
#
# WHAT IS NOT HERE is `exec 3>&2`, the triage's first row, which the unsplit
# file's #109 section already drives against its own fixture, and which moved
# nowhere.

section "=== issue #185: dup_stderr reaches every spelling of a descriptor pointed at stderr ==="

requirement GH-185 <<'REQ'
- text: `dup_stderr <file>` reports, as `<line>:<text>` space-joined, every
  line that points a descriptor other than 1 at stderr. The source is a number
  whose value is not 1, leading zeros read as bash reads them, or a `{name}`,
  a subscript allowed and one subscript nested in it, written where bash
  starts a word -- after a blank, one of `;&|()<>`, a backtick or the start of
  a line -- since bash reads it as the fd only when it is the whole word; or
  it is left implicit on `<`, `<&` or `<>`, where it is 0 -- after anything
  but `<` and a word of digits alone, so `{ cat; }<&2` and `a1<&2` are fd 0,
  and after the target of a `>&` or `<&`, whose digits bash reads as that
  target, so `>&1<&2` is fd 0. The target is fd 2, leading zeros allowed,
  after `>&` or `<&`; or, after `>`, `>>`, `>|`, `<` or `<>`, a path whose
  last component is `stderr` or whose last two are `fd/2`, which reaches
  `/dev/stderr`, `/dev/fd/2` and every `/proc/.../fd/2`; or, after any of
  those but `<`, a process substitution `>(`. Blanks are allowed before the
  target. A word ends where bash ends one, at a blank or at one of `;&|()<>`,
  and at a backtick. Each line is read twice, as written and with the quotes,
  the backslashes and the repeated `/` and `./` segments taken out of every
  redirection's target word, and a line either reading matches is reported.
  Continuations are folded first and whole-line comments blanked after, as
  bash reads them, and each continued line is read on its own as well as
  joined; a folded line is reported under its first line's number, and a
  continued line under its own. It reports nothing for fd 1, whether written
  or implicit, `01` included -- `>&2`, `1>&2`, `>/dev/stderr`,
  `1>/dev/stderr`, `>>`, `>|` and `&>` -- nor for `2>&1`, `>/dev/null 2>&1` or
  a here-string naming `/dev/stderr`, nor for digits or a `{name}` that are
  not a whole word, `a3>&2`, `"$x"3>&2`, `$sha256>&2` and `${msg}>&2` among
  them, nor for a `1` after a backtick, which opens a command and so is its fd
  -- except for the refusing-direction trades the note lists, each of which
  reports a line bash does not point at stderr. A path that is not a readable
  regular file, a directory included, is reported as `UNREADABLE`, and never
  as the empty string a clean file gives. `no-git-push.sh`,
  `no-pr-decisions.sh` and `lib/command-scan.sh`, which both source, report
  nothing.
- from: #185, the sixth review of PR #169, #185's triage, and review of
  #185's pull request
- kind: defect-permitting
- status: active
- direction: static: a property of the suite's helpers
- note: What it does not reach is what the text cannot say without being run,
  or what reading it as bash does would take more than a pattern. This list is
  the one place that names it, and each unreached shape it writes out is
  pinned below by a row that reports nothing. Dataflow, which is why the shape
  is refused rather than counted: a target or a source held in a variable,
  `exec 3>"$dest"` or `exec 3>&$err`; a target computed by an expansion or an
  escape -- arithmetic, `exec 3>&$((1+1))`; an escape, `exec 3>&$'\x32'`; a
  parameter's default, `exec 3>${x:-/dev/stderr}`; a command substitution,
  `exec 3>$(echo /dev/stderr)` or `exec 3>&$(echo 2)`; and a brace expansion,
  `exec 3>/dev/std{e..e}rr`; a coprocess's descriptor, held in `COPROC`, `exec
  4>&${COPROC[1]}`; fd 1 duplicated while it points at stderr -- `exec 1>&2
  3>&1`, `exec >&2` and then `exec 3>&1`, and `{ exec 3>&1; } >&2` -- which
  reach stderr only through fd 1 pointed there, which is #310's for a whole
  process and the #109 section's group redirected once for a group, and which
  reaching here would mean refusing every descriptor pointed at stdout, the
  `3>&1 1>&2 2>&3` swap among them; and a descriptor inherited from the
  process that runs the hook, which has no spelling in the hook to pin. The
  filesystem: a symlink or a named pipe to stderr, which in the text is an
  ordinary path, `exec 3>/tmp/err`, and a relative path, `exec 3>stderr` run
  from `/dev`. A glob, which bash expands in a redirection's target, so `exec
  3>/dev/stde?r`, `exec 3>/dev/stde[r]r` and `exec 3>/dev/stder*` open stderr,
  and reaching one would mean matching a pattern against a path. And a
  subscript nested twice in a `{name}`, `exec {a[b[c[1]]]}>&2`, since a
  pattern matches brackets to a fixed depth and this one matches one level of
  nesting. Every one of them writes to stderr, measured. The implicit fd of an
  input operator departs from the triage's wording, which has the guard report
  nothing for the implicit fd: that fd is 0, `exec <&2` and then `>&0` writes
  to stderr -- measured -- and the contract is any fd but 1, so it is
  reported. Trades taken in the refusing direction, each pinned below by a row
  that says it is a trade and asserts what the guard prints, so that a change
  which flips one is a red: `<` by path opens a read-only descriptor on Linux,
  so a write by way of one fails -- measured, for a source written and left
  implicit -- and it is reported anyway, as the triage asked, while `<>` opens
  one for writing and is a real duplication, and `<` onto a process
  substitution, which the triage did not ask, is not reported, since a write
  by way of it fails too -- measured; fd 2 reopened onto itself,
  `2>/dev/stderr`, is reported though it hides nothing, because the contract
  is any fd but 1; the digits after a `>&` start a word to the source as they
  do to bash, but bash reads them as a target, so `exec >&13>&2`, a target of
  13 and then fd 1, is reported, and so is `exec 2>&1<&2`, which duplicates
  onto fd 0 the stdout fd 2 was just pointed at; a blank escaped with a
  backslash is a word start to the source, so `echo a\ 3>&2`, where bash reads
  `a 3` as one word and fd 1, is reported; the fd target is not bounded on its
  right, so `exec 3>&20` is reported; a path whose last component is `stderr`
  is reported in any directory, so a log file, `exec 2>"$dir/stderr"` or `exec
  3>/tmp/stderr`, is; a process substitution is reported whatever the command
  in it writes to, `exec 3> >(cat >/dev/null)` among them; the second reading
  takes out quotes without reading which quote holds which, so `exec 3>\&2`, a
  file named `&2`, `exec 3>'/dev/std\err'`, whose quotes keep the backslash,
  and `exec 3>/dev/std\$'err'` are reported; and quotes are read only in a
  target word, so a shape inside quoted text, `echo "use exec 3>&2 here"`, or
  in a heredoc body, which is not dropped, is a red. Each of these was
  measured not to write to stderr, `2>/dev/stderr` and the quoted and heredoc
  text aside. The path target is bounded on its right, so `/dev/stderr2` and
  `2>/tmp/stderr.log` are not reported. fd 1 by `/dev/fd/2` is a plain refusal
  that `arms` does not count, which is #263's and not this guard's.
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
tok 'and as /dev/fd/2 opened for input, read-only: a refusing-direction trade' \
    '2:exec 3</dev/fd/2' "$(dup_stderr "$R185_DIR/dev-fd-input.sh")"

# THE TRIAGE TABLE'S /proc ROWS, and the pid spellings beside self.
r185_fixture proc-self 'exec 3>/proc/self/fd/2'
r185_fixture proc-self-input 'exec 3</proc/self/fd/2'
r185_fixture proc-pid 'exec 3>/proc/$$/fd/2'
tok 'dup_stderr reports stderr as /proc/self/fd/2' \
    '2:exec 3>/proc/self/fd/2' "$(dup_stderr "$R185_DIR/proc-self.sh")"
tok 'and as /proc/self/fd/2 opened for input, read-only: a refusing-direction trade' \
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
tok 'and fd 0 left implicit on < by path, read-only: a refusing-direction trade' \
    '2:exec </dev/stderr' "$(dup_stderr "$R185_DIR/implicit-input-path.sh")"

# THE IMPLICIT FD AFTER A WORD, found by review of this file's pull request:
# the anchor refused a `}` and any digit in front of the operator, so a group's
# input and a word ending in a digit hid fd 0. Bash reads digits as the fd only
# when the word is digits alone.
r185_fixture group-input '{ cat; }<&2'
r185_fixture word-digit-input 'cat a1<&2'
tok 'dup_stderr reports fd 0 duplicated onto a brace group, after its }' \
    '2:{ cat; }<&2' "$(dup_stderr "$R185_DIR/group-input.sh")"
tok 'and after a word ending in a digit, which bash does not read as the fd' \
    '2:cat a1<&2' "$(dup_stderr "$R185_DIR/word-digit-input.sh")"

# LEADING ZEROS, read as bash reads them, also found by that review: `02` is
# fd 2 and was missed as a target, and `01` is fd 1.
r185_fixture zero-padded-target 'exec 3>&02'
tok 'dup_stderr reports fd 2 written 02, which bash duplicates as 2' \
    '2:exec 3>&02' "$(dup_stderr "$R185_DIR/zero-padded-target.sh")"

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

# WHAT BASH JOINS AND WHAT IT DOES NOT, found by the fourth review of this
# file's pull request. The fold blanked whole-line comments first, and bash
# joins first: `: x\` and then `#y; exec 3>&2` is one line to bash, whose `#`
# is inside a word, and it runs. And the fold continued a comment ending in a
# backslash, which bash does not: the joined `$3` read as a parameter and hid
# `3>&2 exec` on the line after, which the pattern before #185 reported. Both
# write to stderr -- measured. The fold now blanks comments after it joins,
# and reads each continued line on its own as well as joined.
r185_fixture fold-then-comment ': x\' '#y; exec 3>&2'
r185_fixture comment-continued ': # price in $\' '3>&2 exec'
tok 'dup_stderr reports a line bash joins to a comment-only line, whose # is then inside a word' \
    '2:: x#y; exec 3>&2' "$(dup_stderr "$R185_DIR/fold-then-comment.sh")"
tok 'and a line after a comment ending in a backslash, which bash does not continue, under its own number' \
    '3:3>&2 exec' "$(dup_stderr "$R185_DIR/comment-continued.sh")"

# THREE CLAUSES NO ROW TOLD FROM THEIR NEGATION, found by the first review
# of this file's pull request: with `<>` dropped from the implicit fd's path
# operators, with the source's leading zeros dropped, and with the blanks in
# front of an fd target dropped, the whole suite stayed green. Each shape
# writes to stderr through the fd it opens -- measured.
r185_fixture implicit-read-write 'exec <>/dev/stderr'
r185_fixture zero-padded-source 'exec 03>&2'
r185_fixture spaced-fd 'exec 3>& 2'
tok 'dup_stderr reports fd 0 left implicit on <> by path, which opens it for writing' \
    '2:exec <>/dev/stderr' "$(dup_stderr "$R185_DIR/implicit-read-write.sh")"
tok 'dup_stderr reports fd 3 written 03, which bash reads as 3' \
    '2:exec 03>&2' "$(dup_stderr "$R185_DIR/zero-padded-source.sh")"
tok 'dup_stderr reports a blank between >& and the fd' \
    '2:exec 3>& 2' "$(dup_stderr "$R185_DIR/spaced-fd.sh")"

# A TARGET WORD SPELLED WITH QUOTES OR A BACKSLASH, also found by that review:
# the pattern allowed one quote in front of the target and nothing inside it,
# so every spelling below wrote to stderr -- measured -- and was reported by
# nothing. Each line is now also read with the quotes, the backslashes and the
# repeated `/` and `./` segments taken out of every redirection's target word.
# `$'...'` and `$"..."` are the quotes they are, and what an escape inside one
# expands to is not read: that is below, with what it does not reach.
r185_fixture backslash-fd 'exec 3>&\2'
r185_fixture empty-quotes-fd "exec 3>&''2"
r185_fixture ansi-quoted-fd "exec 3>&\$'2'"
r185_fixture locale-quoted-fd 'exec 3>&$"2"'
r185_fixture spaced-quoted-fd 'exec 3>& "2"'
r185_fixture part-quoted-dir 'exec 3>"/dev/"stderr'
r185_fixture part-quoted-name 'exec 3>/dev/"stderr"'
r185_fixture ansi-quoted-path "exec 3>\$'/dev/stderr'"
r185_fixture backslash-path 'exec 3>/dev/std\err'
r185_fixture doubled-slash 'exec 3>/dev/fd//2'
r185_fixture dot-segment 'exec 3>/dev/fd/./2'
tok 'dup_stderr reports fd 2 escaped with a backslash' \
    '2:exec 3>&\2' "$(dup_stderr "$R185_DIR/backslash-fd.sh")"
tok 'and after an empty pair of quotes' \
    "2:exec 3>&''2" "$(dup_stderr "$R185_DIR/empty-quotes-fd.sh")"
tok "and written \$'2'" \
    "2:exec 3>&\$'2'" "$(dup_stderr "$R185_DIR/ansi-quoted-fd.sh")"
tok 'and written $"2"' \
    '2:exec 3>&$"2"' "$(dup_stderr "$R185_DIR/locale-quoted-fd.sh")"
tok 'and quoted after a blank' \
    '2:exec 3>& "2"' "$(dup_stderr "$R185_DIR/spaced-quoted-fd.sh")"
tok 'dup_stderr reports a path whose directory alone is quoted' \
    '2:exec 3>"/dev/"stderr' "$(dup_stderr "$R185_DIR/part-quoted-dir.sh")"
tok 'and one whose name alone is' \
    '2:exec 3>/dev/"stderr"' "$(dup_stderr "$R185_DIR/part-quoted-name.sh")"
tok "and one written \$'...'" \
    "2:exec 3>\$'/dev/stderr'" "$(dup_stderr "$R185_DIR/ansi-quoted-path.sh")"
tok 'and one with a backslash inside it' \
    '2:exec 3>/dev/std\err' "$(dup_stderr "$R185_DIR/backslash-path.sh")"
tok 'dup_stderr reports /dev/fd//2, which the doubled / reaches' \
    '2:exec 3>/dev/fd//2' "$(dup_stderr "$R185_DIR/doubled-slash.sh")"
tok 'and /dev/fd/./2' \
    '2:exec 3>/dev/fd/./2' "$(dup_stderr "$R185_DIR/dot-segment.sh")"

# TWO MORE CLAUSES NO ROW TOLD FROM THEIR NEGATION, found by the third review:
# the second reading finds `>|` as an operator, so the word after it is taken
# out of its quotes, and it takes out every `./`, not the first alone. Both
# write to stderr -- measured.
r185_fixture clobber-quoted-path 'exec 3>|"/dev/stderr"'
r185_fixture dot-segments 'exec 3>/dev/fd/././2'
tok 'dup_stderr reports a quoted path after >|' \
    '2:exec 3>|"/dev/stderr"' "$(dup_stderr "$R185_DIR/clobber-quoted-path.sh")"
tok 'and /dev/fd/././2, a ./ repeated' \
    '2:exec 3>/dev/fd/././2' "$(dup_stderr "$R185_DIR/dot-segments.sh")"

# THE START OF A LINE. No part of the pattern has a `^`: the second reading
# follows the `;` that splits the two, and that is its start. These rows are
# the ones a line's start decides, so dropping the second reading turns them
# red where no `^` is left to catch them. Each writes to stderr -- measured.
r185_fixture line-start-source '3>&2 exec'
r185_fixture line-start-implicit '<&2 exec'
r185_fixture line-start-name '{fd}>&2 exec'
tok 'dup_stderr reports a source at the start of a line' \
    '2:3>&2 exec' "$(dup_stderr "$R185_DIR/line-start-source.sh")"
tok 'and fd 0 left implicit there' \
    '2:<&2 exec' "$(dup_stderr "$R185_DIR/line-start-implicit.sh")"
tok 'and a named fd there' \
    '2:{fd}>&2 exec' "$(dup_stderr "$R185_DIR/line-start-name.sh")"

# THE LINE AS WRITTEN IS STILL READ. A quote taken out of a target can leave a
# word of digits alone in front of the next operator, which bash did not read
# as its fd: `>"1"<&2` sends fd 1 to a file named 1 and duplicates stderr onto
# fd 0 -- measured -- but with the quotes out it reads as fd 1. Reading the
# line both ways, and reporting either, keeps every spelling the as-written
# reading reached.
r185_fixture quoted-word-before-input 'echo X >"1"<&2'
tok 'dup_stderr reports fd 0 after a quoted word of digits, which only the line as written shows' \
    '2:echo X >"1"<&2' "$(dup_stderr "$R185_DIR/quoted-word-before-input.sh")"
# And at the end of the line, where the path's right bound is the `;` that
# splits the two readings, so a line only the first reading matches is
# reported through it; found by mutating that `;` away before round 3 was
# pushed. Writes to stderr through fd 0 -- measured.
r185_fixture quoted-word-before-path 'exec >"1"<>/dev/stderr'
tok 'and fd 0 opened by <> by path after one, the path ending the line' \
    '2:exec >"1"<>/dev/stderr' "$(dup_stderr "$R185_DIR/quoted-word-before-path.sh")"

# MORE PATHS TO STDERR, and a subscripted name: the path is now any whose last
# component is `stderr` or whose last two are `fd/2`, so a /proc path of any
# depth, a doubled `/` and a `.` segment are reached without being listed.
r185_fixture proc-task 'exec 3>/proc/self/task/$$/fd/2'
r185_fixture proc-thread-self 'exec 3>/proc/thread-self/fd/2'
r185_fixture root-slash 'exec 3>//dev/stderr'
r185_fixture dot-dir 'exec 3>/dev/./stderr'
r185_fixture subscript-name 'exec {a[1]}>&2'
r185_fixture path-then-separator 'exec 3>/dev/stderr;echo'
tok 'dup_stderr reports /proc/self/task/<tid>/fd/2, a /proc path two segments deeper' \
    '2:exec 3>/proc/self/task/$$/fd/2' "$(dup_stderr "$R185_DIR/proc-task.sh")"
tok 'and /proc/thread-self/fd/2' \
    '2:exec 3>/proc/thread-self/fd/2' "$(dup_stderr "$R185_DIR/proc-thread-self.sh")"
tok 'dup_stderr reports //dev/stderr' \
    '2:exec 3>//dev/stderr' "$(dup_stderr "$R185_DIR/root-slash.sh")"
tok 'and /dev/./stderr' \
    '2:exec 3>/dev/./stderr' "$(dup_stderr "$R185_DIR/dot-dir.sh")"
tok 'dup_stderr reports a named fd with a subscript, which bash allocates as a named one' \
    '2:exec {a[1]}>&2' "$(dup_stderr "$R185_DIR/subscript-name.sh")"
# A SUBSCRIPT NESTED IN ONE, found by the fourth review of this file's pull
# request: the subscript stopped at its first `]`. One level of nesting is
# reached, and a subscript holding a braced parameter; both write to stderr --
# measured. Two levels are named in GH-185's note and pinned below.
r185_fixture nested-subscript-name 'exec {a[b[1]]}>&2'
r185_fixture braced-subscript-name 'exec {a[${i}]}>&2'
tok 'dup_stderr reports a named fd whose subscript holds a subscript' \
    '2:exec {a[b[1]]}>&2' "$(dup_stderr "$R185_DIR/nested-subscript-name.sh")"
tok 'and one whose subscript holds a braced parameter' \
    '2:exec {a[${i}]}>&2' "$(dup_stderr "$R185_DIR/braced-subscript-name.sh")"
tok 'dup_stderr ends a path at a separator as well as at a blank' \
    '2:exec 3>/dev/stderr;echo' "$(dup_stderr "$R185_DIR/path-then-separator.sh")"

# A PROCESS SUBSTITUTION, also found by that review: `exec 3> >(cat >&2)` hands
# every later write through fd 3 to a command writing to stderr -- measured --
# and the count reads the one `>&2` inside it once. Reported whatever the
# command writes to. Opened with `<` it is read-only, and so is `<(...)`, its
# read end: a write through either fails -- measured -- and neither is reported.
r185_fixture process-substitution 'exec 3> >(cat >&2)'
r185_fixture implicit-process-substitution 'exec <> >(cat >&2)'
r185_fixture read-process-substitution 'exec 3< <(cat >&2)'
r185_fixture read-only-process-substitution 'exec 3< >(cat >&2)'
tok 'dup_stderr reports an fd opened on a process substitution' \
    '2:exec 3> >(cat >&2)' "$(dup_stderr "$R185_DIR/process-substitution.sh")"
tok 'and fd 0 left implicit on <> onto one' \
    '2:exec <> >(cat >&2)' "$(dup_stderr "$R185_DIR/implicit-process-substitution.sh")"
tok 'but not the read end of one, <(...)' \
    '' "$(dup_stderr "$R185_DIR/read-process-substitution.sh")"
tok 'nor one opened with <, which is read-only' \
    '' "$(dup_stderr "$R185_DIR/read-only-process-substitution.sh")"

# EVERY OPERATOR THAT OPENS ONE FOR WRITING, which the third review of this
# file's pull request found undriven: with `>>`, `>|` or `<>` dropped from the
# operators, the whole suite stayed green. Each writes to stderr -- measured.
r185_fixture append-process-substitution 'exec 3>> >(cat >&2)'
r185_fixture clobber-process-substitution 'exec 3>| >(cat >&2)'
r185_fixture read-write-process-substitution 'exec 3<> >(cat >&2)'
tok 'dup_stderr reports an fd opened on a process substitution with >>' \
    '2:exec 3>> >(cat >&2)' "$(dup_stderr "$R185_DIR/append-process-substitution.sh")"
tok 'and with >|' \
    '2:exec 3>| >(cat >&2)' "$(dup_stderr "$R185_DIR/clobber-process-substitution.sh")"
tok 'and with <>' \
    '2:exec 3<> >(cat >&2)' "$(dup_stderr "$R185_DIR/read-write-process-substitution.sh")"

# A PATH WHOSE LAST COMPONENT IS `stderr`, IN ANY DIRECTORY, the refusing-
# direction trade of reading the path by its end: a log file is reported.
r185_fixture log-named-stderr 'exec 3>/tmp/stderr'
tok 'dup_stderr reports a file named stderr in any directory, the refusing-direction trade' \
    '2:exec 3>/tmp/stderr' "$(dup_stderr "$R185_DIR/log-named-stderr.sh")"

# WHERE A WORD ENDS, found by the second review of this file's pull request.
# Bash ends a word at a blank, at one of `;&|()<>`, and at a backtick, and the
# path's right bound and the target word left the backtick out, so a path
# closing a command substitution was never bounded. And bash reads the digits
# after `>&` or `<&` as that operator's target, so a `<` right after them is a
# fresh redirection of fd 0; the implicit fd's anchor stepped over `&`, and
# the source excludes 1, so `&1<` fell between them. Every shape writes to
# stderr -- measured. After any other operator the digits in front of a `<`
# are its fd, and `>1<&2` is a syntax error -- measured -- so it stays clean.
r185_fixture backtick-path 'x=`{ echo MARK >&3; } 3>/dev/stderr`'
r185_fixture backtick-quoted-path "x=\`{ echo MARK >&3; } 3>'/dev/stderr'\`"
r185_fixture after-dup-input 'exec >&1<&2'
r185_fixture after-dup-input-source 'exec 4>&1<&2'
r185_fixture after-dup-read-write 'exec >&1<>/dev/stderr'
r185_fixture after-dup-spaced 'exec >& 1<&2'
r185_fixture after-dup-zero 'exec >&01<&2'
r185_fixture after-input-dup 'exec <&1<&2'
r185_fixture after-plain-output 'exec >1<&2'
r185_fixture past-backtick 'x=`: 3>a`/dev/stderr'
tok 'dup_stderr reports a path that closes a command substitution, which a backtick ends' \
    '2:x=`{ echo MARK >&3; } 3>/dev/stderr`' "$(dup_stderr "$R185_DIR/backtick-path.sh")"
tok 'and a quoted one' \
    "2:x=\`{ echo MARK >&3; } 3>'/dev/stderr'\`" "$(dup_stderr "$R185_DIR/backtick-quoted-path.sh")"
tok 'dup_stderr reports fd 0 after the target of a >&, whose digits bash reads as that target' \
    '2:exec >&1<&2' "$(dup_stderr "$R185_DIR/after-dup-input.sh")"
tok 'and after one with a source written' \
    '2:exec 4>&1<&2' "$(dup_stderr "$R185_DIR/after-dup-input-source.sh")"
tok 'and fd 0 opened by <> by path after one' \
    '2:exec >&1<>/dev/stderr' "$(dup_stderr "$R185_DIR/after-dup-read-write.sh")"
tok 'and with a blank between the >& and its target' \
    '2:exec >& 1<&2' "$(dup_stderr "$R185_DIR/after-dup-spaced.sh")"
tok 'and with the target written 01' \
    '2:exec >&01<&2' "$(dup_stderr "$R185_DIR/after-dup-zero.sh")"
tok 'and after the target of a <&' \
    '2:exec <&1<&2' "$(dup_stderr "$R185_DIR/after-input-dup.sh")"
tok 'but not after a plain >, where bash reads the 1 as the fd of the <&' \
    '' "$(dup_stderr "$R185_DIR/after-plain-output.sh")"
tok 'nor a path a backtick has ended, where the text after it continues an assignment' \
    '' "$(dup_stderr "$R185_DIR/past-backtick.sh")"
r185_fixture past-backtick-quoted "x=\`: >a\`\$'3'>&2"
tok "nor quotes past the backtick that ends a target word, which bash reads as the assignment's and not as fd 3" \
    '' "$(dup_stderr "$R185_DIR/past-backtick-quoted.sh")"

# A FILE IT CANNOT READ, which would print nothing and read as clean: every
# row that asks a real file would pass on an absent one. Also from the second
# review. It is reported instead, and the reason goes to stderr.
tok 'dup_stderr reports a file it cannot read as UNREADABLE, never as the clean empty string' \
    'UNREADABLE' "$(dup_stderr "$R185_DIR/no-such-fixture.sh" 2>/dev/null)"
tok 'and a directory, which is not a file' \
    'UNREADABLE' "$(dup_stderr "$R185_DIR" 2>/dev/null)"

# A SOURCE IS READ ONLY WHERE A WORD STARTS, as bash reads one, since the
# fourth review of this file's pull request: digits or a `{name}` are the fd
# only when they are the whole word. Until then a source was read after
# anything but a digit or a `$`, and `a3>&2` and `"$x"3>&2` were trades;
# `$sha256>&2` was reported against the requirement's own "nothing for fd 1".
# Each is fd 1 in bash -- measured. And a `1` at the start of a line is fd 1,
# which the separator between the readings has to leave a word start for.
r185_fixture word-ending-in-digit 'exec a3>&2'
r185_fixture parameter-ending-in-digits 'echo $sha256>&2'
r185_fixture quoted-then-digit 'exec "$x"3>&2'
r185_fixture line-start-one '1<&2 cat'
tok 'dup_stderr does not report a3>&2, a word and then fd 1' \
    '' "$(dup_stderr "$R185_DIR/word-ending-in-digit.sh")"
tok 'nor $sha256>&2, a parameter whose name ends in digits, and then fd 1' \
    '' "$(dup_stderr "$R185_DIR/parameter-ending-in-digits.sh")"
tok 'nor "$x"3>&2, one word, and then fd 1' \
    '' "$(dup_stderr "$R185_DIR/quoted-then-digit.sh")"
tok 'nor 1<&2 at the start of a line, which is fd 1' \
    '' "$(dup_stderr "$R185_DIR/line-start-one.sh")"
# Found by mutating this round's clauses before it was pushed: with the
# backtick out of the source's word starts, and with a `[` let into a
# subscript outside a nested one, the suite stayed green. A source right after
# a backtick writes to stderr -- measured -- and an unbalanced subscript is not
# a named fd to bash, which runs `{a[b[]}` as a command -- measured.
r185_fixture backtick-source 'x=`3>&2 exec; echo X >&3`'
r185_fixture unbalanced-subscript 'exec {a[b[]}>&2'
tok 'dup_stderr reports a source right after a backtick, where a command starts' \
    '2:x=`3>&2 exec; echo X >&3`' "$(dup_stderr "$R185_DIR/backtick-source.sh")"
tok 'but not an unbalanced subscript, which bash does not read as a named fd' \
    '' "$(dup_stderr "$R185_DIR/unbalanced-subscript.sh")"
# And each other character of `end` a source can follow in a line bash runs:
# an opening and a closing paren and a pipe, found the same way. Each writes
# to stderr -- measured. After `<` or `>` bash reads the digits as that
# operator's fd and stops on a syntax error -- measured -- so no line tells
# those two apart, and they stay because the source reads `end` whole.
r185_fixture after-open-paren '(3>&2 exec; echo X >&3)'
r185_fixture after-close-paren '(echo X >&3)3>&2'
r185_fixture after-pipe ": |3>&2 eval 'echo X >&3'"
tok 'dup_stderr reports a source right after an opening paren' \
    '2:(3>&2 exec; echo X >&3)' "$(dup_stderr "$R185_DIR/after-open-paren.sh")"
tok 'and right after a closing one, the subshell'"'"'s redirection' \
    '2:(echo X >&3)3>&2' "$(dup_stderr "$R185_DIR/after-close-paren.sh")"
tok 'and right after a pipe' \
    "2:: |3>&2 eval 'echo X >&3'" "$(dup_stderr "$R185_DIR/after-pipe.sh")"

# THE TRADES, each taken in the refusing direction and each measured not to
# point a descriptor at stderr, pinned as what the guard prints so that a
# change which flips one is a red and GH-185's note, which argues each, is
# read again. Found unpinned by the fourth review of this file's pull
# request. The trades pinned elsewhere in this file say so in their rows.
r185_fixture trade-target-then-source 'exec >&13>&2'
r185_fixture trade-dup-onto-input 'exec 2>&1<&2'
r185_fixture trade-escaped-blank 'echo a\ 3>&2'
r185_fixture trade-wide-fd 'exec 3>&20'
r185_fixture trade-log-in-dir 'exec 2>"$dir/stderr"'
r185_fixture trade-process-substitution 'exec 3> >(cat >/dev/null)'
r185_fixture trade-escaped-operator 'exec 3>\&2'
r185_fixture trade-single-quoted-backslash "exec 3>'/dev/std\\err'"
r185_fixture trade-escaped-dollar "exec 3>/dev/std\\\$'err'"
r185_fixture trade-quoted-text 'echo "use exec 3>&2 here"'
r185_fixture trade-heredoc-body "cat <<'X'" 'exec 3>&2' 'X'
tok 'dup_stderr reports >&13>&2, a target and then fd 1: a refusing-direction trade' \
    '2:exec >&13>&2' "$(dup_stderr "$R185_DIR/trade-target-then-source.sh")"
tok 'and 2>&1<&2, fd 0 onto the stdout fd 2 now points at: a trade' \
    '2:exec 2>&1<&2' "$(dup_stderr "$R185_DIR/trade-dup-onto-input.sh")"
tok 'and a\ 3>&2, an escaped blank inside one word: a trade' \
    '2:echo a\ 3>&2' "$(dup_stderr "$R185_DIR/trade-escaped-blank.sh")"
tok 'and >&20, the fd target unbounded on its right: a trade' \
    '2:exec 3>&20' "$(dup_stderr "$R185_DIR/trade-wide-fd.sh")"
tok 'and a log file named stderr under a directory in a parameter: a trade' \
    '2:exec 2>"$dir/stderr"' "$(dup_stderr "$R185_DIR/trade-log-in-dir.sh")"
tok 'and a process substitution writing elsewhere: a trade' \
    '2:exec 3> >(cat >/dev/null)' "$(dup_stderr "$R185_DIR/trade-process-substitution.sh")"
tok 'and 3>\&2, a file named &2: a trade' \
    '2:exec 3>\&2' "$(dup_stderr "$R185_DIR/trade-escaped-operator.sh")"
tok 'and a backslash single quotes keep: a trade' \
    "2:exec 3>'/dev/std\\err'" "$(dup_stderr "$R185_DIR/trade-single-quoted-backslash.sh")"
tok 'and an escaped $ before quotes: a trade' \
    "2:exec 3>/dev/std\\\$'err'" "$(dup_stderr "$R185_DIR/trade-escaped-dollar.sh")"
tok 'and the shape inside quoted text: a trade' \
    '2:echo "use exec 3>&2 here"' "$(dup_stderr "$R185_DIR/trade-quoted-text.sh")"
tok 'and the shape in a heredoc body, which is not dropped: a trade' \
    '3:exec 3>&2' "$(dup_stderr "$R185_DIR/trade-heredoc-body.sh")"

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
r185_fixture one-padded 'exec 01>&2'
r185_fixture one-input 'cat 1<&2'
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
tok 'nor fd 1 written 01' \
    '' "$(dup_stderr "$R185_DIR/one-padded.sh")"
tok 'nor fd 1 written in front of an input operator, a word of digits alone' \
    '' "$(dup_stderr "$R185_DIR/one-input.sh")"

# WHAT IS NOT REPORTED THOUGH IT IS NOT fd 1 POINTED AT STDERR BY bash'S
# READING: a `$` in front of digits or a `{`, which makes them a parameter,
# digits after a backtick, which open a command and so are its fd, and a path
# that runs on past `stderr`. Each was reported before review of this file's
# pull request, in the refusing direction, and `${msg}>&2` contradicted this
# requirement's own "reports nothing for fd 1".
r185_fixture braced-parameter 'echo ${msg}>&2'
r185_fixture positional-parameter 'echo $3>&2'
r185_fixture awk-field 'awk '"'"'{ print $3>"/dev/stderr" }'"'"''
r185_fixture backtick-one 'x=`1<&2`'
r185_fixture backtick-implicit 'x=`<&2`'
r185_fixture stderr-log 'exec 2>/tmp/stderr.log'
r185_fixture stderr-suffix 'exec 3>/dev/stderr2'
tok 'dup_stderr does not report ${msg}>&2, a parameter and then fd 1' \
    '' "$(dup_stderr "$R185_DIR/braced-parameter.sh")"
tok 'nor $3>&2, a positional parameter and then fd 1' \
    '' "$(dup_stderr "$R185_DIR/positional-parameter.sh")"
tok "nor awk's \$3>\"/dev/stderr\", a field and not a descriptor" \
    '' "$(dup_stderr "$R185_DIR/awk-field.sh")"
tok 'nor 1<&2 at the start of a backtick command, which is fd 1' \
    '' "$(dup_stderr "$R185_DIR/backtick-one.sh")"
tok 'but a backtick command whose fd is left implicit on <& is fd 0, and is reported' \
    '2:x=`<&2`' "$(dup_stderr "$R185_DIR/backtick-implicit.sh")"
tok 'dup_stderr does not report a path that runs on past stderr, a log file' \
    '' "$(dup_stderr "$R185_DIR/stderr-log.sh")"
tok 'nor /dev/stderr2' \
    '' "$(dup_stderr "$R185_DIR/stderr-suffix.sh")"

# WHAT IT DOES NOT REACH, each measured writing to stderr and pinned here as
# reporting nothing, so that reaching one turns a row red and the note that
# names it is read again. GH-185's note argues each, and says it pins each
# the text can spell: the second review of this file's pull request found
# four the note named with no row here, and its sweep two more, and they are
# the six rows after fd 1's chain. A descriptor inherited from the process
# has no spelling.
r185_fixture glob-path 'exec 3>/dev/stde?r'
r185_fixture escape-expansion "exec 3>&\$'\\x32'"
r185_fixture arithmetic-expansion 'exec 3>&$((1+1))'
r185_fixture relative-path 'exec 3>stderr'
r185_fixture fd-one-chain 'exec 1>&2 3>&1'
tok 'dup_stderr does not reach a glob that bash expands to /dev/stderr' \
    '' "$(dup_stderr "$R185_DIR/glob-path.sh")"
tok "nor fd 2 written as an escape, \$'\\x32'" \
    '' "$(dup_stderr "$R185_DIR/escape-expansion.sh")"
tok 'nor fd 2 computed, $((1+1))' \
    '' "$(dup_stderr "$R185_DIR/arithmetic-expansion.sh")"
tok 'nor a relative path, which reaches stderr only from /dev' \
    '' "$(dup_stderr "$R185_DIR/relative-path.sh")"
tok 'nor fd 1 duplicated after fd 1 was pointed at stderr, whose entry is #310' \
    '' "$(dup_stderr "$R185_DIR/fd-one-chain.sh")"
r185_fixture variable-path 'exec 3>"$dest"'
r185_fixture variable-fd 'exec 3>&$err'
r185_fixture coprocess 'exec 4>&${COPROC[1]}'
r185_fixture fd-one-exec 'exec >&2' 'exec 3>&1'
r185_fixture fd-one-group '{ exec 3>&1; } >&2'
r185_fixture ordinary-path 'exec 3>/tmp/err'
tok 'nor a path held in a variable' \
    '' "$(dup_stderr "$R185_DIR/variable-path.sh")"
tok 'nor an fd held in a variable' \
    '' "$(dup_stderr "$R185_DIR/variable-fd.sh")"
tok "nor a coprocess's fd, held in COPROC" \
    '' "$(dup_stderr "$R185_DIR/coprocess.sh")"
tok 'nor fd 1 duplicated on the line after exec >&2, which is #310' \
    '' "$(dup_stderr "$R185_DIR/fd-one-exec.sh")"
tok 'nor fd 1 duplicated inside a group redirected to stderr' \
    '' "$(dup_stderr "$R185_DIR/fd-one-group.sh")"
tok 'nor an ordinary path, which a symlink or a named pipe to stderr is in the text' \
    '' "$(dup_stderr "$R185_DIR/ordinary-path.sh")"

# AND THE EXPANSIONS THE THIRD REVIEW FOUND WITH NO ROW, with the rest of
# their kinds from its sweep: a brace expansion, the other globs, a parameter's
# default, and a command substitution, as a path and as an fd. Each writes to
# stderr -- measured.
r185_fixture brace-expansion 'exec 3>/dev/std{e..e}rr'
r185_fixture bracket-glob 'exec 3>/dev/stde[r]r'
r185_fixture star-glob 'exec 3>/dev/stder*'
r185_fixture parameter-default 'exec 3>${x:-/dev/stderr}'
r185_fixture command-substitution-path 'exec 3>$(echo /dev/stderr)'
r185_fixture command-substitution-fd 'exec 3>&$(echo 2)'
tok 'nor a brace expansion that bash expands to /dev/stderr' \
    '' "$(dup_stderr "$R185_DIR/brace-expansion.sh")"
tok 'nor a bracket glob' \
    '' "$(dup_stderr "$R185_DIR/bracket-glob.sh")"
tok 'nor a * glob' \
    '' "$(dup_stderr "$R185_DIR/star-glob.sh")"
tok "nor a parameter's default" \
    '' "$(dup_stderr "$R185_DIR/parameter-default.sh")"
tok 'nor a path a command substitution prints' \
    '' "$(dup_stderr "$R185_DIR/command-substitution-path.sh")"
tok 'nor an fd one prints' \
    '' "$(dup_stderr "$R185_DIR/command-substitution-fd.sh")"

# AND FROM THE FOURTH REVIEW: a subscript nested twice, past the one level the
# pattern matches. It writes to stderr -- measured.
r185_fixture twice-nested-subscript 'exec {a[b[c[1]]]}>&2'
tok 'nor a subscript nested twice in a {name}' \
    '' "$(dup_stderr "$R185_DIR/twice-nested-subscript.sh")"

# THE LIBRARY BOTH HOOKS SOURCE, which the unsplit file's two rows do not ask:
# a descriptor it opened is open in the hook that sourced it.
req GH-185 GH-109.2
tok 'lib/command-scan.sh, which both hooks source, points no other fd at 2' \
    '' "$(dup_stderr "$HOOKS/lib/command-scan.sh")"

sourced_to_end

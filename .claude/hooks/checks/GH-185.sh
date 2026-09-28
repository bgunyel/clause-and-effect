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
# `2:<shape>`, the output the guard prints; a clean one as the empty string.
# Each must-flag row was run against the old pattern and failed there --
# every one empty but the continuation, which printed only its line 4 -- but
# one, `exec 3>& 2`, which the old pattern reached too and which is here for
# a clause of the new one that no row drove. That run is recorded in the pull
# request, since a check that restores the old pattern would be a check of a
# function nobody calls. A shape the guard does not reach is asserted as the
# empty string too, beside the clean ones, and says so in its row.
#
# WHAT IS NOT HERE is `exec 3>&2`, the triage's first row, which the unsplit
# file's #109 section already drives against its own fixture, and which moved
# nowhere.

section "=== issue #185: dup_stderr reaches every spelling of a descriptor pointed at stderr ==="

requirement GH-185 <<'REQ'
- text: `dup_stderr <file>` reports, as `<line>:<text>` space-joined, every
  line that points a descriptor other than 1 at stderr. The source is a
  number whose value is not 1, leading zeros read as bash reads them, or a
  `{name}`, subscript allowed, or it is left implicit on `<`, `<&` or `<>`,
  where it is 0 -- after anything but `<` and a word of digits alone, so
  `{ cat; }<&2` and `a1<&2` are fd 0, and after the target of a `>&` or `<&`,
  whose digits bash reads as that target, so `>&1<&2` is fd 0. The target is
  fd 2, leading zeros allowed, after `>&` or `<&`; or, after `>`, `>>`, `>|`,
  `<` or `<>`, a path whose last component is `stderr` or whose last two are
  `fd/2`, which reaches `/dev/stderr`, `/dev/fd/2` and every
  `/proc/.../fd/2`; or, after any of those but `<`, a process substitution
  `>(`. Blanks are allowed before the target. A word ends where bash ends
  one, at a blank or at one of `;&|()<>`, and at a backtick. Each line is
  read twice, as written and with the quotes, the backslashes and the
  repeated `/` and `./` segments taken out of every redirection's target
  word, and a line either reading matches is reported. Continuations are
  folded first and a folded line is reported under its first line's number.
  It reports nothing for fd 1, whether written or implicit, `01` included,
  whatever spelling points it at stderr -- `>&2`, `1>&2`, `>/dev/stderr`,
  `1>/dev/stderr`, `>>`, `>|` and `&>` -- nor for `2>&1`,
  `>/dev/null 2>&1` or a here-string naming `/dev/stderr`, nor for digits
  or a `{` after a `$`, which are a parameter and not a descriptor, nor for
  a `1` after a backtick, which opens a command and so is its fd. A file it
  cannot read is reported as `UNREADABLE`, and never as the empty string a
  clean file gives. `no-git-push.sh`, `no-pr-decisions.sh` and
  `lib/command-scan.sh`, which both source, report nothing.
- from: #185, the sixth review of PR #169, #185's triage, and review of
  #185's pull request
- kind: defect-permitting
- status: active
- direction: static: a property of the suite's helpers
- note: What it does not reach is what the text cannot say without being
  run, and each of those the text can spell is pinned below by a row that
  reports nothing. Dataflow, which is why the shape is refused rather than
  counted: a target or a source held in a variable, `exec 3>"$dest"` or
  `exec 3>&$err`; a target computed by an expansion or an escape,
  `exec 3>&$((1+1))` or `exec 3>&$'\x32'`; a coprocess's descriptor, held
  in `COPROC`; fd 1 duplicated while it points at stderr --
  `exec 1>&2 3>&1`, `exec >&2` and then `exec 3>&1`, and
  `{ exec 3>&1; } >&2` -- whose entry is fd 1 pointed at stderr, which is
  #310's for a whole process and the #109 section's group redirected once
  for a group, and which reaching here would mean refusing every descriptor
  pointed at stdout, the `3>&1 1>&2 2>&3` swap among them; and a descriptor
  inherited from the process that runs the hook, which has no spelling in
  the hook to pin. The filesystem: a symlink or a named pipe to stderr,
  which in the text is an ordinary path, and a relative path, `exec
  3>stderr` run from `/dev`. And a glob, which bash expands in a
  redirection's target, so `exec 3>/dev/stde?r` opens stderr -- measured --
  and reaching it would mean matching a pattern against a path. The
  implicit fd of an input operator departs from the triage's wording, which
  has the guard report nothing for the implicit fd: that fd is 0,
  `exec <&2` and then `>&0` writes to stderr -- measured -- and the contract
  is any fd but 1, so it is reported. Trades taken in the refusing
  direction: `<` by path opens a read-only descriptor on Linux, so a write
  by way of one fails -- measured, for a source written and left implicit
  -- and it is reported anyway, as the triage asked, while `<>` opens one for
  writing and is a real duplication, and `<` onto a process substitution,
  which the triage did not ask, is not reported, since a write through it
  fails too -- measured; fd 2 reopened onto itself, `2>/dev/stderr`, is
  reported though it hides nothing, because the contract is any fd but 1;
  an explicit source is read after anything but a digit or a `$`, so
  `a3>&2`, which bash reads as fd 1, and `>&13>&2`, a target of 13 and then
  fd 1, are reported; the fd target is not bounded on its right, so `>&20`
  is reported; a path whose last component is `stderr` is reported in any
  directory, so a log file `2>"$dir/stderr"` is; a process substitution is
  reported whatever the command in it writes to; the second reading takes
  out quotes without reading which quote holds which, so `exec 3>\&2`, a
  file named `&2`, `exec 3>'/dev/std\err'`, whose quotes keep the
  backslash, and `exec 3>/dev/std\$'err'` are reported; and quotes are read
  only in a target word, so a shape inside quoted text, or in a heredoc
  body, which is not dropped, is a red. The path target is bounded on its
  right, so `/dev/stderr2` and `2>/tmp/stderr.log` are not reported. fd 1
  by `/dev/fd/2` is a plain refusal that `arms` does not count, which is
  #263's and not this guard's.
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

# THE LINE AS WRITTEN IS STILL READ. A quote taken out of a target can leave a
# word of digits alone in front of the next operator, which bash did not read
# as its fd: `>"1"<&2` sends fd 1 to a file named 1 and duplicates stderr onto
# fd 0 -- measured -- but with the quotes out it reads as fd 1. Reading the
# line both ways, and reporting either, keeps every spelling the as-written
# reading reached.
r185_fixture quoted-word-before-input 'echo X >"1"<&2'
tok 'dup_stderr reports fd 0 after a quoted word of digits, which only the line as written shows' \
    '2:echo X >"1"<&2' "$(dup_stderr "$R185_DIR/quoted-word-before-input.sh")"

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

# A FILE IT CANNOT READ, which would print nothing and read as clean: every
# row that asks a real file would pass on an absent one. Also from the second
# review. It is reported instead, and the reason goes to stderr.
tok 'dup_stderr reports a file it cannot read as UNREADABLE, never as the clean empty string' \
    'UNREADABLE' "$(dup_stderr "$R185_DIR/no-such-fixture.sh" 2>/dev/null)"

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

# THE LIBRARY BOTH HOOKS SOURCE, which the unsplit file's two rows do not ask:
# a descriptor it opened is open in the hook that sourced it.
req GH-185 GH-109.2
tok 'lib/command-scan.sh, which both hooks source, points no other fd at 2' \
    '' "$(dup_stderr "$HOOKS/lib/command-scan.sh")"

sourced_to_end

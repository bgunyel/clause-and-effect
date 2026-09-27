#!/bin/bash
# THE ISSUE FILE OF #186: `every_hook` fails when it runs no hook.
#
# Why: `every_hook` looped over $XH_HOOKS and passed whenever no hook in the
# loop refused, so a list the loop consumed nothing from printed
# `ok ALLOW by all` for a command no hook had judged. The guard that answered
# the first review of PR #169 stood beside the one setting of $XH_HOOKS that
# reads settings.json, and `drive_helper` and `every_hook_of` already set it
# from elsewhere, so the helper's other callers reached it unguarded. The sixth
# review of the same pull request filed it; #186's triage measured the second
# shape, a list of blanks, which is not empty as a string and runs no hook all
# the same, so `[ -n "$XH_HOOKS" ]` in the helper would not have closed it.
#
# WHAT IS DRIVEN is the helper, run inside a subshell over a list this file
# writes, which prints what the helper printed on either stream and then the
# FAILED it left, and then whether the fixture below ran. Inside the subshell
# the helper's `pass` or `fail` is not recorded and its FAILED does not reach
# this shell, so a helper that fails here, as it should, is this file's evidence
# and not a red row. What each row asserts is the whole of that, as a literal:
# the message and nothing else on stderr, that the failure was a failure, and
# whether a hook was run at all.

section "=== issue #186: every_hook fails when it runs no hook ==="

requirement GH-186 <<'REQ'
- text: `every_hook <dir> <label> <cmd>` counts the names its loop over
  $XH_HOOKS consumed, and when that count is zero it records a failing verdict
  whose line names the label and says there were no hooks to run it through.
  So an empty list fails, and so does a list of blanks -- spaces, tabs or
  newlines -- which is not empty as a string and gives the loop no name. A list
  naming a hook behaves as before: a pass only if every hook it names exits 0.
- from: #186, the sixth review of PR #169
- kind: defect-permitting
- status: active
- direction: static: a property of the suite's helpers
- note: The guard is on what the loop consumed and not on the string, and it
  is a failing verdict rather than an abort, since one caller's empty list is
  that check's defect and not the run's. The abort beside the settings.json
  derivation in #109's section stays, naming the other cause. It is a string
  test, so it stops the run on an empty derivation; one of blanks passes it,
  fails the GH-109.5 row that wants the seven names, and then each cross-hook
  row fails on the helper's zero count.
REQ
shape_pin 'GH-186:static'

# What a helper prints opens with two blanks, held in a variable so that no
# quoted string here opens with a result's prefix: #104's audit at the foot of
# the suite reads every such string as a result printed around pass and fail.
R186_INDENT='  '
# THE BLANKS, every character the loop's word splitting cuts on, since a guard
# that strips only one of them -- `${XH_HOOKS// /}` -- passes a list of spaces
# as the count does and prints `ok ALLOW by all` over a tab or a newline. The
# first review of this pull request found that mutant green against a list of
# spaces alone.
R186_BLANKS=$' \t\n '
# THE FIXTURE, a hook that reads its payload, leaves a mark that it ran and
# exits 0, for the row that shows a name among the blanks is run and not merely
# counted. It is this file's own and not #98's `allow-0` under $EXITS, which
# marks the same way: a fixture two issue files use belongs in the driver's
# prelude, and #98's move there only with its checks.
R186_DIR="$FIXTURES/r186"
R186_ALLOW="$R186_DIR/allow.sh"
R186_RAN="$R186_DIR/ran"
mkdir -p "$R186_DIR"
printf '#!/bin/bash\ncat >/dev/null\n: > "$(dirname "$0")/ran"\nexit 0\n' > "$R186_ALLOW"
chmod +x "$R186_ALLOW"
[ -x "$R186_ALLOW" ] || {
  echo "the #186 fixture was not created; the check against it proves nothing" >&2
  exit 1
}
r186_every_hook() {  # r186_every_hook <list> -- what every_hook printed over <list>, its FAILED, and whether the fixture ran
  rm -f "$R186_RAN"
  ( FAILED=0
    XH_HOOKS="$1" every_hook "$R186_DIR" 'r186 driven check' 'true'
    printf 'FAILED=%s\n' "$FAILED" ) 2>&1
  if [ -e "$R186_RAN" ]; then echo 'fixture ran: yes'; else echo 'fixture ran: no'; fi
}

req GH-186
tok 'every_hook over an empty list fails, and says there were no hooks to run it through' \
"${R186_INDENT}FAIL r186 driven check
         no hooks to run it through
FAILED=1
fixture ran: no" \
    "$(r186_every_hook '')"
tok 'and over a list of spaces, tabs and newlines, which is not empty as a string, it fails the same way' \
"${R186_INDENT}FAIL r186 driven check
         no hooks to run it through
FAILED=1
fixture ran: no" \
    "$(r186_every_hook "$R186_BLANKS")"
tok 'a hook among those blanks is run, and one that exits 0 passes' \
    "${R186_INDENT}ok   ALLOW by all  r186 driven check
FAILED=0
fixture ran: yes" \
    "$(r186_every_hook "$R186_BLANKS$R186_ALLOW$R186_BLANKS")"

sourced_to_end

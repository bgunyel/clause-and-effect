#!/bin/bash
# THE ISSUE FILE OF #186: `every_hook` fails when it runs no hook.
#
# Why: `every_hook` looped over $XH_HOOKS and passed whenever no hook in the
# loop refused, so a list the loop consumed nothing from printed
# `ok ALLOW by all` for a command no hook had judged. The guard that answered
# the first review of PR #169 stood beside the one derivation that reads
# settings.json, and `drive_helper` and `every_hook_of` already set $XH_HOOKS
# from elsewhere, so the helper's other callers reached it unguarded. The sixth
# review of the same pull request filed it; #186's triage measured the second
# shape, a list of blanks, which is not empty as a string and runs no hook all
# the same, so `[ -n "$XH_HOOKS" ]` in the helper would not have closed it.
#
# WHAT IS DRIVEN is the helper, run inside a subshell over a list this file
# writes, which prints what the helper printed and then the FAILED it left.
# Inside the subshell the helper's `pass` or `fail` is not recorded and its
# FAILED does not reach this shell, so a helper that fails here, as it should,
# is this file's evidence and not a red row. What each row asserts is the whole
# of that, as a literal: the message, and that the failure was a failure.

section "=== issue #186: every_hook fails when it runs no hook ==="

requirement GH-186 <<'REQ'
- text: `every_hook <dir> <label> <cmd>` counts the hooks its loop over
  $XH_HOOKS ran, and when that count is zero it records a failing verdict
  whose line names the label and says there were no hooks to run it through.
  So an empty list fails, and so does a list of blanks, which is not empty as a
  string and runs no hook. A list naming a hook behaves as before: a pass only
  if every hook it names exits 0.
- from: #186, the sixth review of PR #169
- kind: defect-permitting
- status: active
- direction: static: a property of the suite's helpers
- note: The guard is on what the loop consumed and not on the string, and it
  is a failing verdict rather than an abort, since one caller's empty list is
  that check's defect and not the run's. The abort beside the settings.json
  derivation in #109's section stays, naming the other cause, and stops the run
  before the cross-hook rows print.
REQ
shape_pin 'GH-186:static'

# What a helper prints opens with two blanks, held in a variable so that no
# quoted string here opens with a result's prefix: #104's audit at the foot of
# the suite reads every such string as a result printed around pass and fail.
R186_INDENT='  '
# THE FIXTURE, a hook that reads its payload and exits 0, for the row that
# shows the count is of hooks run and not of anything else.
R186_DIR="$FIXTURES/r186"
R186_ALLOW="$R186_DIR/allow.sh"
mkdir -p "$R186_DIR"
printf '#!/bin/bash\ncat >/dev/null\nexit 0\n' > "$R186_ALLOW"
chmod +x "$R186_ALLOW"
[ -x "$R186_ALLOW" ] || {
  echo "the #186 fixture was not created; the check against it proves nothing" >&2
  exit 1
}
r186_every_hook() {  # r186_every_hook <list> -- what every_hook printed over <list>, then its FAILED
  ( FAILED=0
    XH_HOOKS="$1" every_hook "$R186_DIR" 'r186 driven check' 'true'
    printf 'FAILED=%s\n' "$FAILED" )
}

req GH-186
tok 'every_hook over an empty list fails, and says there were no hooks to run it through' \
"${R186_INDENT}FAIL r186 driven check
         no hooks to run it through
FAILED=1" \
    "$(r186_every_hook '')"
tok 'and over a list of blanks, which is not empty as a string, it fails the same way' \
"${R186_INDENT}FAIL r186 driven check
         no hooks to run it through
FAILED=1" \
    "$(r186_every_hook '   ')"
tok 'a hook among the blanks is run, and one that exits 0 passes' \
    "${R186_INDENT}ok   ALLOW by all  r186 driven check
FAILED=0" \
    "$(r186_every_hook "  $R186_ALLOW  ")"

sourced_to_end

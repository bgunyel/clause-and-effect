#!/bin/bash
# THE ISSUE FILE OF #272: a registry row's edit cannot write a file, read one,
# or run a command, in pass two or in `--list`.
#
# Why: pass two ran each row's edit as `sed "$EDIT" "$TARGET" > mutated`, and
# redirecting stdout does not make sed read-only. GNU sed's `w` command and the
# `w` flag of `s` write a file, `r` reads one, and `e` and the `e` flag run a
# command, all while sed runs, before any guard in the harness is asked; the sum
# taken at the end of a run would report a write into .claude/hooks/ after it
# had happened. Measured at dev-05 2303e9b by #272: `s/a/b/w written.txt`
# created the file. Nothing inspected the edit beyond its being non-empty.
#
# Closed by #193, which applies every edit through one function, `row_apply`,
# with `sed --sandbox`, and made `--list` apply them too. The sandbox refuses
# every one of those commands as sed failing, and each caller reports that as
# the row's fault. The text is not read for the letters: `w` is an ordinary
# character inside a pattern.
#
# WHAT IS CHECKED: a copy of the harness whose registry is one row per command
# the sandbox refuses, each naming a file under $FIXTURES to write or a command
# that would create one, and the two self-tests, run twice -- `--list`, and a
# whole pass against a stub check-hooks.sh that prints one requirement and
# exits 0, so the baseline is green and pass two reaches every row in well
# under a second. Every refused row is a fault in both, nothing is counted or
# run for any of them, and afterwards none of the files they name exists.
#
# THE SELF-TESTS ARE THERE FOR THE EXIT STATUS. Without them a whole pass
# fails on their absence before it reaches a row, so its exit 1 said nothing
# about the rows, and deleting `FAILED=1` from pass two's refusal of a row
# left this file green (review of PR #350). With them, and with both reporting
# what they declare, the faulted rows are the only thing left to make it 1.
#
# WHAT IS NOT HERE: a command the sandbox does not refuse. GNU sed's sandbox
# covers `e`, `r` and `w`, the `R` and `W` forms, and the `e` and `w` flags of
# `s`, and those are the rows; whatever a later sed adds is outside them.
section "=== issue #272: a registry row's edit cannot write, read or run anything ==="

requirement GH-272 <<'REQ'
- text: `mutate-hooks.sh` applies a registry row's edit with `sed --sandbox`,
  in pass two and in `--list` alike, so an edit carrying `w`, `W`, `r`, `R` or
  `e`, or the `w` or `e` flag of `s`, is a fault of that row: `--list` marks it
  and does not count it, a pass reports it as a FAIL and runs nothing for it,
  and neither writes the file a `w` names nor runs the command an `e` names.
- from: #272, found while triaging #193, and closed by it
- kind: defect-permitting
- status: active
- direction: static: it drives the harness against a copy holding a fixture
  registry and a stub suite, and reads what it printed and what it left
- note: the sandbox is the rule, and refusing the letters by reading the edit's
  text was rejected, because `w` is also an ordinary character inside a
  pattern. No row of the real registry used any of these commands when the
  sandbox was added, so it gave up no row.
REQ
shape_pin 'GH-272:static'

req GH-272
R272="$FIXTURES/r272"
# Each row names its own file, so that a check can say which command acted.
# `r` and `R` read a file that exists, so that an unsandboxed read would change
# the output and the row would read as an edit that applies.
R272_ROWS="r272-w-flag%hook.sh%s/alpha/beta/w $FIXTURES/r272-w-flag%GH-1%caught
r272-w%hook.sh%w $FIXTURES/r272-w%GH-1%caught
r272-W%hook.sh%W $FIXTURES/r272-W%GH-1%caught
r272-r%hook.sh%r $FIXTURES/r272-source%GH-1%caught
r272-R%hook.sh%R $FIXTURES/r272-source%GH-1%caught
r272-e%hook.sh%1e touch $FIXTURES/r272-e%GH-1%caught
r272-e-flag%hook.sh%s|alpha|touch $FIXTURES/r272-e-flag|e%GH-1%caught
selftest-survives%hook.sh%s/alpha/omega/%GH-1%survived
selftest-applies-nothing%hook.sh%s/nothing-matches-this/x/%GH-1%did-not-apply"
harness_fixture "$R272" "$R272_ROWS"
printf 'alpha\n' > "$R272/hook.sh"
printf 'read in\n' > "$FIXTURES/r272-source"
printf '#!/bin/bash\necho GH-1\n' > "$R272/check-hooks.sh"
printf '# A fixture\n\n## Boundary issues\n\n### GH-1\n- status: active\n' > "$R272/requirements.md"
tok 'the copy of the harness registers the fixture rows and nothing else' \
    "$R272_ROWS" "$(harness_rows "$R272/mutate-hooks.sh")"

# --list: every refused row a fault, and the run count the baseline and the
# self-test whose edit applies.
R272_LIST=$(bash "$R272/mutate-hooks.sh" --list 2>&1)
tok '--list reports each edit carrying a command the sandbox refuses as a fault' \
    'r272-w-flag:fault r272-w:fault r272-W:fault r272-r:fault r272-R:fault r272-e:fault r272-e-flag:fault selftest-survives:applies selftest-applies-nothing:unchanged ' \
    "$(printf '%s\n' "$R272_LIST" | awk '/^$/ { exit } NR > 1 && !/^    \^/ { printf "%s:%s ", $1, $4 }')"
tok 'as sed failing, for every one of them' \
    '7' "$(printf '%s\n' "$R272_LIST" | grep -c '^    ^ fault: the sed expression failed: ')"
tok 'and counts none of them' \
    '2' "$(printf '%s\n' "$R272_LIST" | awk '/runs of check-hooks.sh for a whole-registry pass/ { print $1; exit }')"

# A whole pass, against the stub: the baseline is green, every refused row is
# a FAIL before any run of the suite on a mutated copy, and the self-tests
# report what they declare.
R272_RUN=$(bash "$R272/mutate-hooks.sh" 2>&1)
R272_STATUS=$?
holds 'a pass reaches the rows: the baseline against the stub suite is green' "$R272_RUN" \
  'ok   the unmutated copy is green, over 1 requirements'
tok 'and reports each of them as a FAIL, as sed failing' \
    '7' "$(printf '%s\n' "$R272_RUN" | grep -cE '^  FAIL r272-(w-flag|w|W|r|R|e|e-flag): the sed expression failed: ')"
tok 'and runs the suite on none of them, the self-test whose edit applies being the one run' \
    'selftest-survives' \
    "$(printf '%s\n' "$R272_RUN" | sed -n 's/^  \.\.\.  \([^:]*\): running check-hooks.sh against the mutated copy$/\1/p')"
tok 'the self-tests report what they declare' \
    'ok selftest-survives survived|ok selftest-applies-nothing did-not-apply|' \
    "$(printf '%s\n' "$R272_RUN" | awk '($1 == "ok" || $1 == "FAIL") && $2 ~ /^selftest-/ { printf "%s %s %s|", $1, $2, $3 }')"
lacks 'and the registry is not refused for lacking one' "$R272_RUN" 'FAIL the registry holds'
tok 'so the faulted rows alone make the pass exit non-zero' '1' "$R272_STATUS"

# AND NOTHING WAS WRITTEN OR RUN, by either: none of the files the rows name to
# write or create is there. Asked of each by name, so a red says which command
# acted.
tok 'no w, W, s///w or e and s///e row wrote or ran anything, in --list or in the pass' \
    '' "$(for f in r272-w-flag r272-w r272-W r272-e r272-e-flag; do
            [ -e "$FIXTURES/$f" ] && printf '%s ' "$f"
          done)"
tok 'and the fixture file the rows edit is as it was' 'alpha' "$(cat "$R272/hook.sh")"

sourced_to_end

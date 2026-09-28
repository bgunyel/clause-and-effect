#!/bin/bash
# THE ISSUE FILE OF #223: the gaps review of PR #222 found in #205's
# generated-entry guards and filed rather than gated on, closed. Eight of them,
# one entry each; items 4 and 5 were closed before this, and no item 8 was
# filed. Every one was measured before it was fixed -- in scratch clones at
# abba1d0 for #223's triage, and again at 0d5829d for this file -- and every
# expectation below is a literal.
#
# Two of the checks read the whole run and stand in the end-of-run file, with
# the #205 checks they sit beside: that the declared and pinned records are
# where the driver put them (GH-223.5), and that the suite's reader of
# requirements/ gives the verdict the generator gives on a blank line and on a
# field given twice (GH-223.2), since the reader is defined there.

section "=== issue #223: the generated-entry guards #205 left open ==="

requirement GH-223.1 <<'REQ'
- text: Every legacy `GH-` entry is held to its bytes. The 117 that
  `SPLIT_MOVED` holds are GH-200.4's; the 13 legacy entries written after the
  split, GH-200.1–.5 and GH-204.1–.8, are held by a literal of their own in
  the #223 issue file, each at the checksum and length its file had at
  0d5829d, and the legacy entries that `SPLIT_MOVED` does not hold are
  exactly those 13.
- from: #223
- kind: defect-permitting
- status: active
- direction: static: it reads the files against the literal
- note: It extends GH-200.4's trade to 13 more entries, knowingly. An entry is
  immutable once written and a correction is a new entry that supersedes it,
  so an edit to one of these -- a status change among them -- moves its token
  in the same commit, where a reviewer sees it in the diff. The literal is
  its own, so that GH-200.4's count, 117 measured at 4e91496, keeps meaning
  what it says. Measured when it was written: GH-204.6 and GH-204.7 were
  reworded in place by #295 after abba1d0, which is the edit this refuses;
  they are held at the bytes #295 gave them.
REQ
requirement GH-223.2 <<'REQ'
- text: The grammar of an entry's ID and the grammar of its body are spelled
  once per program, and each copy is held to one spelling: the #223 issue
  file counts every copy in `generate-requirements.sh`,
  `split-requirements.sh`, the library, the end-of-run file and the unsplit
  file, so a copy changed or added in any of them is red. The generator and
  the suite's reader of `requirements/` give one verdict on one body: both
  refuse a field given twice, and both accept a blank line, which the reader
  skips without ending the field before it.
- from: #223
- kind: defect-refusing
- status: active
- direction: static: it counts the copies, and drives the generator and the reader against fixtures
- note: A pin and not one shared definition, as #223's triage chose: the
  copies are in two standalone scripts, an awk program built in the suite and
  a bash test, and none of them can read the others' definition. The blank
  line is accepted rather than refused because the reader is the gate and two
  legacy files hold one, `GH-148` and `GH-155.1`. What it does not see, named:
  a copy spelled in a file it does not count, such as another issue file.
REQ
requirement GH-223.3 <<'REQ'
- text: The suite reads no stdin. The driver makes its stdin `/dev/null`
  once, before any file under `checks/` is sourced, so a `requirement`
  called without its heredoc records an empty body and the end of the run
  names the entry as declared with no fields, whatever the suite was started
  with, and never waits on a stream that stays open.
- from: #223
- kind: defect-refusing
- status: active
- direction: static: it reads this shell's stdin and the driver's text, and drives the call and the finding
- note: Before it, such a call read the rest of `mutate-hooks.sh`'s registry,
  which feeds each row's run from a here-string, and waited on a pipe that
  never closes. The check does not run the whole suite under an open pipe,
  which would take a run of the suite inside a run of it; it holds the
  driver's line to its place before `source_checks`, which no caller's stdin
  can satisfy by accident, and asks this shell's stdin besides.
REQ
requirement GH-223.4 <<'REQ'
- text: `generate-requirements.sh` decides which file is its own by the legacy
  set and never by the file, and applies the rules `generated_bad` holds, in
  its words. It reads `REQUIREMENTS_LEGACY` by name out of the check-hooks.sh
  beside `checks/`, and refuses, writing nothing, a check-hooks.sh with no such
  literal. A legacy ID is never written, whatever its file carries: declaring
  one is refused, and so is a legacy file carrying a `generated` field. A file
  outside the legacy set is its own to replace, whether or not it carries the
  field, and one that no issue file declares is refused. An ID declared in a
  file other than its own issue's, `checks/GH-<n>.sh` for an entry of #<n>, is
  refused, naming both files.
- from: #223
- kind: defect-refusing
- status: active
- direction: static: it runs the script and `generated_bad` against the same fixtures and reads both verdicts
- note: Until #223 it decided by the `generated` field, so a generated file
  whose field was deleted by hand was refused as hand-written from then on,
  pointing away from the only remedy; a legacy file that gained one and was
  then declared was overwritten; and an entry declared in another issue's file
  was written, with `--check` clean, while the suite was red. The suite
  reads the directory the script is run over through `generator_view`, which
  since #223 carries check-hooks.sh from the suite's side, as it carries
  `checks/`.
REQ
requirement GH-223.5 <<'REQ'
- text: The records of what the issue files declared and pinned are named for
  the suite, `SUITE_DECLARED` and `SUITE_PINNED`, and the end of the run fails
  on either one not being the file the driver set it to.
- from: #223
- kind: defect-permitting
- status: active
- direction: static: it compares the records' names at the end of the run with the driver's
- note: They were `DECLARED` and `PINNED`, words a check might use for a
  scratch value in the one shell every file of the suite shares, and an
  assignment of either would have sent every later declaration or pin to that
  value. What it does not see, named: an assignment put back before the end of
  the run, whose declarations in between are then named by `generated_bad` as
  files no issue file declares, and whose pins by `pins_bad` as entries pinned
  nowhere -- red, for that reason rather than this one.
REQ
requirement GH-223.6 <<'REQ'
- text: Every entry ID of the form `GH-<n>.<m>` that requirements.md or a file
  under `requirements/` cites, where `checks/GH-<n>.sh` is an issue file, has
  its file under `requirements/`.
- from: #223
- kind: defect-permitting
- status: active
- direction: static: it reads the registry's text against its files
- note: It narrows, and does not close, the trade ADR 0005 takes on a
  generated ID deleted outright: one that something in the registry still
  cites is red. The rule is the one that was green on the tree with no
  exception list. A bare `GH-<n>` is a family name as often as an entry, and a
  sub-ID of a family with no issue file is named as not written yet or is an
  example, so neither is asked. What it does not see, named: a deleted ID
  that nothing in the registry cites, a bare `GH-<n>` entry deleted, and a
  citation anywhere else -- an issue file, a document, a commit.
REQ
requirement GH-223.7 <<'REQ'
- text: `generate-requirements.sh` writes each file through a temporary file
  beside it, moved over the destination, so a destination holds its old bytes
  or its new ones and never part of either. A write that fails stops the run
  with a non-zero status, names the file, and leaves no temporary file behind;
  a file it writes has the mode a new file takes under the caller's umask.
- from: #223
- kind: defect-permitting
- status: active
- direction: static: it runs the script with a `cp` that fails midway and reads what the directory holds
- note: It wrote with a `cp` over each destination in turn until #223, so a
  failure midway left one file truncated. The files written before a failure
  stay written; a second run writes the rest.
REQ
requirement GH-223.8 <<'REQ'
- text: Every helper in the library that splits a list on blanks, or joins its
  arguments, does so whatever IFS its caller has: `shape_pin`, `variants_pin`,
  `pins_bad`, `legacy_tokens`, `generated_bad`, `split_moved_bad`,
  `every_hook` and `req`.
- from: #223
- kind: defect-refusing
- status: active
- direction: static: it calls each helper under a caller's IFS of a colon
- note: Four were named by review of PR #222; the sweep found the other four,
  `req` among them, whose `"$*"` joins on the first character of IFS. Each
  sets its own IFS for its own body, so a caller's is left as it was.
REQ
shape_pin 'GH-223.1:static GH-223.2:static GH-223.3:static GH-223.4:static
  GH-223.5:static GH-223.6:static GH-223.7:static GH-223.8:static'

R223="$FIXTURES/r223"
mkdir -p "$R223"
r223_gen() {  # r223_gen [--check] <dir> -- what the script printed, and its status
  bash "$HOOKS/generate-requirements.sh" "$@" 2>&1; printf 'exit %s' "$?"
}
r223_hooks() {  # r223_hooks <dir> <legacy IDs> -- a hooks directory: checks/, requirements/ and the literal
  rm -rf -- "$1"; mkdir -p -- "$1/checks" "$1/requirements"
  printf "REQUIREMENTS_LEGACY='\n%s\n'\n" "$2" > "$1/check-hooks.sh"
}
# A fixture's declarations are written with an `@` in front of the word, taken
# off as the file is made, so that no line of this file opens one it does not
# mean.
r223_issue() {  # r223_issue <file> -- stdin, with the @ taken off each @requirement
  sed 's/@requirement/requirement/' > "$1"
}

# ITEM 1. The literal, and the set it has to be.
req GH-223.1
R223_LATE='
GH-200.1:344766615:933 GH-200.2:3416678944:1175 GH-200.3:3028080621:448
GH-200.4:3133887971:1031 GH-200.5:3794813058:2582 GH-204.1:3802601780:4671
GH-204.2:3391461799:728 GH-204.3:3008675148:1311 GH-204.4:3604288194:2540
GH-204.5:4130990915:2352 GH-204.6:4163415608:2625 GH-204.7:1123616113:1740
GH-204.8:773126861:2368
'
R223_MOVED_IDS=$(set -f; for t in $SPLIT_MOVED; do printf '%s ' "${t%%:*}"; done)
R223_LATE_IDS=$(set -f; for t in $R223_LATE; do printf '%s\n' "${t%%:*}"; done | LC_ALL=C sort | tr '\n' ' ')
tok 'the legacy entries SPLIT_MOVED does not hold are the 13 written after the split' \
  'GH-200.1 GH-200.2 GH-200.3 GH-200.4 GH-200.5 GH-204.1 GH-204.2 GH-204.3 GH-204.4 GH-204.5 GH-204.6 GH-204.7 GH-204.8 ' \
  "$(legacy_tokens out "$R223_MOVED_IDS" "$REQUIREMENTS_LEGACY")"
tok 'and the literal holds those 13' \
  'GH-200.1 GH-200.2 GH-200.3 GH-200.4 GH-200.5 GH-204.1 GH-204.2 GH-204.3 GH-204.4 GH-204.5 GH-204.6 GH-204.7 GH-204.8 ' \
  "$R223_LATE_IDS"
tok 'and each is in requirements/ with the checksum and length it had at 0d5829d (an entry named here is absent or changed)' \
  '' "$(split_moved_bad "$HOOKS/requirements" "$R223_LATE")"

# ITEM 2. Every copy of each grammar, counted where it is spelled. A row per
# file, `<file> <ID opening> <ID, awk> <ID, bash> <field> <continuation>`: the
# opening `GH-[1-9]` counts every copy however its tail is spelled, so a copy
# whose opening changed drops out of it, and one whose tail changed drops out
# of its spelling's count. The two scripts are the judged ones; the suite's
# files are read off $SUITE_DIR, being the tooling.
req GH-223.2
r223_count() {  # r223_count <file> <literal> -- how many times the file spells it
  grep -oF -- "$2" "$1" | wc -l | tr -d ' '
}
R223_ID_OPEN='GH-[1-9]'
R223_ID_AWK='^GH-[1-9][0-9]*(\.[1-9][0-9]*)?$'
R223_ID_BASH='^GH-[1-9][0-9]*([.][1-9][0-9]*)?$'
R223_FIELD='^- [a-z-]+:'
R223_CONT='^  [^ ]'
tok 'each grammar is spelled one way, in the number of places it was spelled when #223 counted them' \
'generate-requirements.sh 1 1 0 1 1
split-requirements.sh 2 1 0 1 1
checks/library.sh 1 0 1 0 0
checks/end-of-run.sh 2 2 0 2 1
checks/unsplit.sh 0 0 0 2 1' \
  "$(for f in "$HOOKS/generate-requirements.sh" "$HOOKS/split-requirements.sh" \
              "$SUITE_DIR/checks/library.sh" "$SUITE_DIR/checks/end-of-run.sh" "$SUITE_DIR/checks/unsplit.sh"; do
       printf '%s' "${f#"$HOOKS"/}" | sed "s|^$SUITE_DIR/||"
       for l in "$R223_ID_OPEN" "$R223_ID_AWK" "$R223_ID_BASH" "$R223_FIELD" "$R223_CONT"; do
         printf ' %s' "$(r223_count "$f" "$l")"
       done
       printf '\n'
     done)"
# And the generator's verdicts on the two bodies its copy and the reader's
# disagreed on, which the end-of-run file asks of the reader.
r223_hooks "$R223/grammar" ''
r223_issue "$R223/grammar/checks/GH-7.sh" <<'FIX'
@requirement GH-7 <<'REQ'
- text: a field,

  continued after a blank line
- from: the fixture
REQ
FIX
tok 'a body with a blank line is written, and byte for byte' \
  "$(printf 'wrote requirements/GH-7.md\nexit 0|### GH-7\n- text: a field,\n\n  continued after a blank line\n- from: the fixture\n- generated: checks/GH-7.sh\n' | od -c)" \
  "$({ r223_gen "$R223/grammar"; printf '|'; cat "$R223/grammar/requirements/GH-7.md"; } | od -c)"
r223_issue "$R223/grammar/checks/GH-8.sh" <<'FIX'
@requirement GH-8 <<'REQ'
- text: a
- text: b
REQ
FIX
tok 'and a field given twice is refused, as the reader refuses it' \
'generate-requirements.sh: refused, and nothing was written:
  checks/GH-8.sh: line 3: GH-8: the field text is given twice
exit 1|GH-7.md' "$(r223_gen "$R223/grammar"; printf '|'; ls "$R223/grammar/requirements" | tr '\n' ' ' | sed 's/ $//')"

# ITEM 3. This shell's stdin, the driver's line that makes it so, and what a
# `requirement` with no heredoc records under it.
req GH-223.3
tok 'this shell'"'"'s stdin is /dev/null' 'yes' "$([[ /dev/stdin -ef /dev/null ]] && echo yes || echo no)"
tok 'the driver makes it /dev/null before it sources any file under checks/' 'before' \
  "$(awk '/^exec 0<\/dev\/null$/ && !e { e = NR } /^source_checks "/ && !s { s = NR }
          END { print (e && s && e < s) ? "before" : "not before" }' "$SUITE_TEXT")"
: > "$R223/no-heredoc"
SUITE_DECLARED="$R223/no-heredoc" requirement GH-9.9
tok 'so a requirement with no heredoc records an empty body, and does not wait' \
  "$(printf 'GH-9.9\tchecks/GH-223.sh\t\0' | od -c)" "$(od -c < "$R223/no-heredoc")"
mkdir -p "$R223/no-fields"
printf '### GH-9.9\n- generated: checks/GH-9.sh\n' > "$R223/no-fields/GH-9.9.md"
tok 'which generated_bad names as an entry declared with no fields' \
  'GH-9.9: declared in checks/GH-9.sh with no fields' \
  "$(generated_bad <(printf 'GH-9.9\tchecks/GH-9.sh\t\0') "$R223/no-fields" '')"

# ITEM 6 AND ITEM 10. One fixture per case, each asked of the generator and of
# `generated_bad`, whose verdicts are the two readings that have to agree. GH-1
# is the legacy set in each. The record for `generated_bad` is written with
# printf, as `requirement` writes it.
req GH-223.4
r223_hooks "$R223/marker" 'GH-1'
printf '### GH-1\n- text: legacy\n' > "$R223/marker/requirements/GH-1.md"
r223_issue "$R223/marker/checks/GH-7.sh" <<'FIX'
@requirement GH-7 <<'REQ'
- text: generated
REQ
FIX
printf '### GH-7\n- text: generated\n' > "$R223/marker/requirements/GH-7.md"
tok 'a generated file whose generated field was deleted is named by --check as not its declaration, and so by generated_bad' \
'generate-requirements.sh: not what the issue files declare:
  requirements/GH-7.md differs from its declaration in checks/GH-7.sh
exit 1|requirements/GH-7.md: not, byte for byte, its declaration in checks/GH-7.sh' \
  "$(r223_gen --check "$R223/marker"; printf '|'
     generated_bad <(printf 'GH-7\tchecks/GH-7.sh\t- text: generated\n\0') "$R223/marker/requirements" 'GH-1')"
tok 'and a run writes it back, field and all' \
'wrote requirements/GH-7.md
exit 0|### GH-7
- text: generated
- generated: checks/GH-7.sh' "$(r223_gen "$R223/marker"; printf '|'; cat "$R223/marker/requirements/GH-7.md")"
r223_hooks "$R223/stray" 'GH-1'
printf '### GH-1\n- text: legacy\n- generated: checks/GH-1.sh\n' > "$R223/stray/requirements/GH-1.md"
r223_issue "$R223/stray/checks/GH-1.sh" <<'FIX'
@requirement GH-1 <<'REQ'
- text: a declaration of a legacy entry
REQ
FIX
tok 'a legacy file with a stray generated field, and its ID declared, is refused and left as it was, and generated_bad names both' \
'generate-requirements.sh: refused, and nothing was written:
  GH-1: declared in checks/GH-1.sh, and a legacy entry, which stays hand-written
  requirements/GH-1.md: a legacy entry carrying a generated field, which only a declared entry'"'"'s file carries
exit 1|### GH-1
- text: legacy
- generated: checks/GH-1.sh
|GH-1: declared in checks/GH-1.sh, and a legacy entry, which stays hand-written
requirements/GH-1.md: a legacy entry carrying a generated field, which only a declared entry'"'"'s file carries' \
  "$(r223_gen "$R223/stray"; printf '|'; cat "$R223/stray/requirements/GH-1.md"; printf '|'
     generated_bad <(printf 'GH-1\tchecks/GH-1.sh\t- text: a declaration of a legacy entry\n\0') "$R223/stray/requirements" 'GH-1')"
r223_hooks "$R223/owner" 'GH-1'
printf '### GH-1\n- text: legacy\n' > "$R223/owner/requirements/GH-1.md"
r223_issue "$R223/owner/checks/GH-7.sh" <<'FIX'
@requirement GH-9 <<'REQ'
- text: in another issue's file
REQ
FIX
tok 'an ID declared in another issue'"'"'s file is refused, naming both files, and writes nothing, as generated_bad names it' \
'generate-requirements.sh: refused, and nothing was written:
  GH-9: declared in checks/GH-7.sh, where an entry of #9 is declared in checks/GH-9.sh
exit 1|GH-1.md|GH-9: declared in checks/GH-7.sh, where an entry of #9 is declared in checks/GH-9.sh' \
  "$(r223_gen "$R223/owner"; printf '|'; ls "$R223/owner/requirements" | tr '\n' ' ' | sed 's/ $//'; printf '|'
     generated_bad <(printf 'GH-9\tchecks/GH-7.sh\t- text: in another issue'"'"'s file\n\0') "$R223/owner/requirements" 'GH-1')"
r223_hooks "$R223/orphan" 'GH-1'
printf '### GH-1\n- text: legacy\n' > "$R223/orphan/requirements/GH-1.md"
printf '### GH-6\n- text: hand-written after the legacy set\n' > "$R223/orphan/requirements/GH-6.md"
tok 'a file outside the legacy set that nothing declares is refused, marker or none, as generated_bad names it' \
'generate-requirements.sh: refused, and nothing was written:
  requirements/GH-6.md: outside the legacy set, and no issue file declares it
exit 1|requirements/GH-6.md: outside the legacy set, and no issue file the suite ran declares it' \
  "$(r223_gen --check "$R223/orphan"; printf '|'; generated_bad /dev/null "$R223/orphan/requirements" 'GH-1')"
# And the literal the script reads the set from, missing each way it can be.
r223_hooks "$R223/no-literal" ''
printf 'LEGACY=x\n' > "$R223/no-literal/check-hooks.sh"
r223_hooks "$R223/unclosed-literal" ''
printf "REQUIREMENTS_LEGACY='\nGH-1\n" > "$R223/unclosed-literal/check-hooks.sh"
r223_hooks "$R223/no-driver" ''
rm -f -- "$R223/no-driver/check-hooks.sh"
tok 'a check-hooks.sh with no REQUIREMENTS_LEGACY, one whose literal never closes, and none at all are each refused' \
"generate-requirements.sh: refused, and nothing was written:
  $R223/no-literal/check-hooks.sh holds no REQUIREMENTS_LEGACY literal, so which entries stay hand-written cannot be read
exit 1|generate-requirements.sh: refused, and nothing was written:
  $R223/unclosed-literal/check-hooks.sh holds no REQUIREMENTS_LEGACY literal, so which entries stay hand-written cannot be read
exit 1|generate-requirements.sh: refused, and nothing was written:
  $R223/no-driver/check-hooks.sh holds no REQUIREMENTS_LEGACY literal, so which entries stay hand-written cannot be read
exit 1" "$(r223_gen --check "$R223/no-literal"; printf '|'; r223_gen --check "$R223/unclosed-literal"; printf '|'
           r223_gen --check "$R223/no-driver")"

# ITEM 9. The citations the registry makes, against the files it holds. Read
# off $HOOKS, whose requirements.md and requirements/ are what is judged, and
# the families off the suite's checks/, the tooling.
req GH-223.6
r223_cited_bad() {  # r223_cited_bad <hooks dir> <checks dir> -- each GH-<n>.<m> cited, of a family with an issue file, with no file
  local f id n
  for f in "$1/requirements.md" "$1"/requirements/GH-*.md; do
    [ -f "$f" ] || continue
    grep -oE 'GH-[1-9][0-9]*\.[1-9][0-9]*' -- "$f" | LC_ALL=C sort -u | while IFS= read -r id; do
      n=${id#GH-}; n=${n%%.*}
      [ -f "$2/GH-$n.sh" ] && [ ! -f "$1/requirements/$id.md" ] && printf '%s: cites %s, which has no entry\n' "${f#"$1"/}" "$id"
    done
  done
}
mkdir -p "$R223/cited/requirements" "$R223/cited/checks"
: > "$R223/cited/checks/GH-5.sh"
printf '### GH-5.1\n- text: cites GH-5.3 and GH-5.1\n' > "$R223/cited/requirements/GH-5.1.md"
printf 'GH-5.1, GH-5.2, GH-5, GH-6.1 and GH-5.10.\n' > "$R223/cited/requirements.md"
tok 'a cited sub-ID of a family with an issue file and no file is named, and a bare ID and a family with no issue file are not' \
'requirements.md: cites GH-5.10, which has no entry
requirements.md: cites GH-5.2, which has no entry
requirements/GH-5.1.md: cites GH-5.3, which has no entry' "$(r223_cited_bad "$R223/cited" "$R223/cited/checks")"
tok 'every GH-<n>.<m> the registry cites, of a family with an issue file, has its file under requirements/' \
  '' "$(r223_cited_bad "$HOOKS" "$SUITE_DIR/checks")"

# ITEM 11. A `cp` first on PATH that writes part of its destination and fails
# when that is GH-5.1's, and is the real one otherwise; the fixture has two
# stale files, so the first is written and the second fails.
req GH-223.7
r223_hooks "$R223/atomic" ''
r223_issue "$R223/atomic/checks/GH-5.sh" <<'FIX'
@requirement GH-5 <<'REQ'
- text: new
REQ
@requirement GH-5.1 <<'REQ'
- text: new
REQ
FIX
printf 'old\n' > "$R223/atomic/requirements/GH-5.md"
printf 'old\n' > "$R223/atomic/requirements/GH-5.1.md"
mkdir -p "$R223/half-cp"
printf '#!/bin/sh\nfor last; do :; done\ncase $last in *GH-5.1*) printf partial > "$last"; exit 1 ;; esac\nexec %s "$@"\n' \
  "$(command -v cp)" > "$R223/half-cp/cp"
chmod +x "$R223/half-cp/cp"
tok 'a write that fails midway names the file, leaves it its old bytes and no temporary file, and keeps the one written before it' \
'wrote requirements/GH-5.md
generate-requirements.sh: writing requirements/GH-5.1.md failed, and it holds what it held before; the files named above were written
exit 1|GH-5.1.md GH-5.md|old
|### GH-5' \
  "$(PATH="$R223/half-cp:$PATH" r223_gen "$R223/atomic"; printf '|'
     ls -A "$R223/atomic/requirements" | tr '\n' ' ' | sed 's/ $//'; printf '|'
     cat "$R223/atomic/requirements/GH-5.1.md"; printf '|'; head -n 1 "$R223/atomic/requirements/GH-5.md")"
tok 'and a second run writes the rest, with the mode a new file takes under the umask, 022 here' \
'wrote requirements/GH-5.1.md
exit 0|644' "$(umask 022; r223_gen "$R223/atomic"; printf '|'; stat -c %a "$R223/atomic/requirements/GH-5.1.md")"

# ITEM 12. Each helper called under a caller's IFS of a colon, in a subshell so
# that the IFS ends with it; the tokens hold colons, so a split on one is seen.
req GH-223.8
: > "$R223/ifs-pins"
(IFS=:
 SUITE_PINNED="$R223/ifs-pins" shape_pin 'GH-9.1:static GH-9.2'
 SUITE_PINNED="$R223/ifs-pins" variants_pin 'GH-9.2:none GH-9.3:seed')
tok 'shape_pin and variants_pin split on blanks under a caller'"'"'s IFS' \
  "$(printf 'shape\tchecks/GH-223.sh\tGH-9.1:static GH-9.2 \nvariants\tchecks/GH-223.sh\tGH-9.2:none GH-9.3:seed ')" \
  "$(cat "$R223/ifs-pins")"
mkdir -p "$R223/ifs/requirements"
printf '### GH-1\n' > "$R223/ifs/requirements/GH-1.md"
printf '### GH-2\n' > "$R223/ifs/requirements/GH-2.md"
printf '### GH-7\n- text: a\n- generated: checks/GH-7.sh\n' > "$R223/ifs/requirements/GH-7.md"
printf 'GH-7\tchecks/GH-7.sh\t- text: a\n\0GH-7.1\tchecks/GH-7.sh\t- text: b\n\0' > "$R223/ifs/declared"
printf '### GH-7.1\n- text: b\n- generated: checks/GH-7.sh\n' > "$R223/ifs/requirements/GH-7.1.md"
tok 'and so do legacy_tokens, pins_bad, generated_bad, split_moved_bad, req and every_hook' \
'GH-7:none ||| GH-3:absent|GH-1 GH-2|  ok   ALLOW by all  a listed command' \
  "$(IFS=:
     legacy_tokens out 'GH-1 GH-2' 'GH-7:none GH-2 GH-1:seed'; printf '|'
     pins_bad "$R223/ifs/declared" <(printf 'shape\tchecks/GH-7.sh\tGH-7:static GH-7.1\n') 'US-1 GH-1:static' 'GH-1:seed' 'GH-1 GH-2'; printf '|'
     generated_bad "$R223/ifs/declared" "$R223/ifs/requirements" 'GH-1 GH-2'; printf '|'
     split_moved_bad "$R223/ifs/requirements" 'GH-3:1:1'; printf '|'
     req GH-1 GH-2; printf '%s|' "$REQ"
     XH_HOOKS='no-git-push.sh pytest-via-uv-group.sh' every_hook "$SUITE_DIR" 'a listed command' 'ls')"

sourced_to_end

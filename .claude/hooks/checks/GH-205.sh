#!/bin/bash
# THE ISSUE FILE OF #205: a `GH-` entry written after #205 is declared here, in
# the issue file whose checks establish it, and its file under requirements/ is
# generated from the declaration by generate-requirements.sh. The first issue
# file, so the form a declaration and a pin take is set here; why this form and
# what was rejected is docs/adr/0005-generated-requirement-entries.md.
#
# The checks here drive the pieces against fixtures, with every expectation a
# literal. The checks that hold this repository to them read what every issue
# file declared, so they stand in the end-of-run file, after the last issue
# file has run.

section "=== issue #205: an entry written after it is declared in its issue file, and its file is generated ==="

# `requirement`, the declaration, and `shape_pin` are in the library since
# #215's issue file became their second caller; their comments moved with them.
# `variants_pin` is `shape_pin`'s twin for the variants keyword, and stays here
# while this file is its one caller.
variants_pin() {  # variants_pin '<ID>:<keyword>...' -- the variants of entries this issue file declares
  local -
  set -f
  printf 'variants\t%s\t%s\n' "${BASH_SOURCE[1]#"$SUITE_DIR"/}" "$(printf '%s ' $*)" >> "$PINNED"
}

requirement GH-205.1 <<'REQ'
- text: A `GH-` entry outside the legacy set is generated. Its file under
  `requirements/` is, byte for byte, the heading `### <ID>`, the body of the
  `requirement <ID> <<'REQ'` heredoc that declares it in its issue's file as
  bash read it when the suite ran that file, and a last field,
  `- generated: checks/GH-<n>.sh`, naming the file. An entry of #<n>, `GH-<n>`
  or `GH-<n>.<m>`, is declared in `checks/GH-<n>.sh` and in no other file.
  Every file outside the
  legacy set has one declaration, and no legacy ID has any; every legacy ID
  keeps its file, and none carries a `generated` field. The legacy set is the
  130 `GH-` entries `requirements/` held at cf73c82, which the driver holds as
  `REQUIREMENTS_LEGACY` and which never grows.
- from: #205
- kind: defect-permitting
- status: active
- direction: static: it reads the files against what the run declared
- note: A hand edit to a generated file and a declaration changed without
  regenerating are one finding, a file that is not its declaration, and the
  check asks it of the declaration as the suite ran it rather than as the
  generator reads it, so the generator's reading is not the expectation its
  own output is held to. What it does not see, named: an entry written before
  #205, which stays hand-written and is held, where it is held at all, by
  GH-200.4's checksums; whether a declaration's text is true, which no
  generation can say; and a generated entry deleted outright, with its
  declaration, its pin and its file in one commit, which leaves nothing that
  disagrees. The rule that an ID is never deleted is held here for the legacy
  set only (#223). A generated scope -- an entry's command shapes and
  verdicts written from the rows that test it -- is not built: it would be
  read off `req` tags, whose scope runs on to the next `req`, so it could
  claim more than the rows test until that is closed.
REQ
requirement GH-205.2 <<'REQ'
- text: `generate-requirements.sh` writes each declared entry's file and
  nothing else, and a second run writes nothing. It refuses, writing nothing:
  a line whose first word, after any indentation, is `requirement` followed
  by `GH-`, spelled other than `requirement <ID> <<'REQ'` at the start of the
  line; an ID outside the grammar; an ID declared twice; a
  declaration never closed; a body that is empty, holds a line that is no
  field, or carries a `generated` field of its own; a declared ID whose file
  is hand-written; and a generated file no issue file declares any more. With
  `--check` it writes nothing and exits 1 on a refusal, which it reports
  alone; with none, it names each file that is not what its declaration would
  write and exits 1. Against this repository it names the entries the suite
  ran a declaration of, and no others.
- from: #205
- kind: defect-permitting
- status: active
- direction: static: it runs the script against fixtures and reads what it wrote and printed
- note: A call the script does not read at all -- `x=1 requirement GH-7`,
  a quoted ID, a declaration built by another command -- is not refused by
  it, because a text reader is always one spelling behind bash. Bash records
  it when the suite runs the file, and GH-205.1's check then finds an entry
  declared and not written, so the run is red where the script was silent.
REQ
requirement GH-205.3 <<'REQ'
- text: `REQUIREMENT_SHAPE` and `INV_SCOPE` hold legacy `GH-` entries only. A
  generated entry's shape is pinned with `shape_pin`, and its `variants`
  keyword with `variants_pin` when it is in the invariance families' scope,
  each once and in the issue file that declares it. The shape the suite holds
  -- `REQUIREMENT_SHAPE` and every shape pin -- is compared with what the
  entries declare, as `REQUIREMENT_SHAPE` alone was, and so are the generated
  entries' variants with their pins, as `INV_SCOPE` is with the legacy ones'.
- from: #205, deciding #211
- kind: defect-permitting
- status: active
- direction: static: it reads the literals and the pins against what the entries declare
- note: The shared literals held every entry, so every loop that added one
  appended a token to both, and the conflict #200 took out of
  requirements.md stood in the check suite instead. A pin keeps what the
  literals are for -- a second copy of what the coverage and the families
  read off an entry, which a reviewer sees move in the diff -- in a file one
  loop writes. What it gives up, named: the copy stands in the same file as
  the declaration, written in the same commit by the same hand, which is
  what `REQUIREMENT_SHAPE` was to requirements.md as well; it is a second
  copy, not a second author.
REQ
shape_pin 'GH-205.1:static GH-205.2:static GH-205.3:static'

# THE LEGACY SET IS WHAT IT WAS. Nothing can count requirements/ at cf73c82
# again in a shallow checkout, so the literal is held to the measurement taken
# there when it was written: 130 IDs, and a checksum of the list as the driver
# writes it, so that an ID added to it -- the way to write a new entry by hand
# and pass -- goes red here as well as in the diff.
req GH-205.1
R205_LEGACY_N=$(set -f; printf '%s\n' $REQUIREMENTS_LEGACY | grep -c .)
R205_LEGACY_SUM=$(set -f; printf '%s ' $REQUIREMENTS_LEGACY | cksum)
tok 'the legacy set holds the 130 GH- entries requirements/ held at cf73c82' '130' "$R205_LEGACY_N"
tok 'and its checksum is the one taken of that list there' '2177508440 1052' "$R205_LEGACY_SUM"

R205="$FIXTURES/generated-entries"
mkdir -p "$R205"

# `requirement` records the fields as bash read them: continuation, a tab and a
# `$` kept as written, the last newline kept, and the issue file named as the
# path under .claude/hooks/. Driven with $DECLARED pointed at a fixture, as a
# temporary assignment that ends with the call. The declaration is not at the
# start of its line, so it is none of this file's own.
: > "$R205/record"
DECLARED="$R205/record" requirement GH-9.1 <<'FIX'
- text: a field,
  continued	with a tab and $HOME
FIX
tok 'requirement records the ID, the issue file and the fields as bash read them' \
  "$(printf 'GH-9.1\tchecks/GH-205.sh\t- text: a field,\n  continued\twith a tab and $HOME\n\0' | od -c)" \
  "$(od -c < "$R205/record")"
: > "$R205/pins"
PINNED="$R205/pins" shape_pin 'GH-9.1:static
  GH-9.2'
PINNED="$R205/pins" variants_pin 'GH-9.2:none'
req GH-205.3
tok 'shape_pin and variants_pin record the kind, the issue file and the tokens, whitespace folded' \
  "$(printf 'shape\tchecks/GH-205.sh\tGH-9.1:static GH-9.2 \nvariants\tchecks/GH-205.sh\tGH-9.2:none \n')" \
  "$(cat "$R205/pins")"
# And the file named is the CALLER's, not the file defining the three. The
# calls above are all in this file. Since #215, `requirement` and `shape_pin`
# are defined in the library, so for those two the index of BASH_SOURCE is
# already asked above; `variants_pin` is still defined here, so for it the two
# are one path and it is not. A file sourced from a fixture asks it of all
# three. It is outside .claude/hooks/, so it is named by its whole path. Its declaration is
# written with an `@` taken off as the file is made, as the fixtures below are.
sed 's/@requirement/requirement/' > "$R205/caller.sh" <<'FIX'
@requirement GH-9.3 <<'REQ'
- text: from another file
REQ
shape_pin 'GH-9.3:static'
variants_pin 'GH-9.3:none'
FIX
: > "$R205/caller-record"; : > "$R205/caller-pins"
(DECLARED="$R205/caller-record" PINNED="$R205/caller-pins"; source "$R205/caller.sh")
req GH-205.1 GH-205.3
tok 'each of the three names the file that called it, not the one that defines it' \
  "$(printf 'GH-9.3\t%s\t- text: from another file\n\0' "$R205/caller.sh" | od -c)
$(printf 'shape\t%s\tGH-9.3:static \nvariants\t%s\tGH-9.3:none ' "$R205/caller.sh" "$R205/caller.sh")" \
  "$(od -c < "$R205/caller-record")
$(cat "$R205/caller-pins")"

# generated_bad, against a fixture holding one of each thing it names. The
# record is written with printf, as `requirement` writes it; GH-1 and GH-2 are
# the legacy set.
req GH-205.1
mkdir -p "$R205/bad/requirements"
{
  printf 'GH-7\tchecks/GH-7.sh\t- text: good\n\0'
  printf 'GH-7.1\tchecks/GH-7.sh\t- text: edited\n\0'
  printf 'GH-7.2\tchecks/GH-7.sh\t- text: never written\n\0'
  printf 'GH-7\tchecks/GH-8.sh\t- text: again\n\0'
  printf 'GH-07\tchecks/GH-7.sh\t- text: out of grammar\n\0'
  printf 'GH-1\tchecks/GH-7.sh\t- text: a legacy ID\n\0'
  printf 'GH-9\tchecks/GH-7.sh\t- text: in another issue'"'"'s file\n\0'
} > "$R205/bad/record"
printf '### GH-7\n- text: good\n- generated: checks/GH-7.sh\n' > "$R205/bad/requirements/GH-7.md"
printf '### GH-7.1\n- text: edited by hand\n- generated: checks/GH-7.sh\n' > "$R205/bad/requirements/GH-7.1.md"
printf '### GH-1\n- text: legacy\n- generated: checks/GH-7.sh\n' > "$R205/bad/requirements/GH-1.md"
printf '### GH-6\n- text: hand-written after the legacy set\n' > "$R205/bad/requirements/GH-6.md"
tok 'generated_bad names each entry that is not its declaration or is declared outside its issue'"'"'s file, and each file outside the legacy set nothing declares' \
'GH-07: declared in checks/GH-7.sh, and not an ID of the grammar GH-<n> or GH-<n>.<m>
GH-1: declared in checks/GH-7.sh, and a legacy entry, which stays hand-written
GH-2: a legacy entry with no file, where an ID is never deleted
GH-7: declared a second time, in checks/GH-8.sh
GH-9: declared in checks/GH-7.sh, where an entry of #9 is declared in checks/GH-9.sh
requirements/GH-1.md: a legacy entry carrying a generated field, which only a declared entry'"'"'s file carries
requirements/GH-6.md: outside the legacy set, and no issue file the suite ran declares it
requirements/GH-7.1.md: not, byte for byte, its declaration in checks/GH-7.sh
requirements/GH-7.2.md: declared in checks/GH-7.sh, and not written' \
  "$(generated_bad "$R205/bad/record" "$R205/bad/requirements" 'GH-1 GH-2')"
# And the byte that matters most, the last: a file that lost its final newline
# is not its declaration.
mkdir -p "$R205/newline/requirements"
printf 'GH-7\tchecks/GH-7.sh\t- text: good\n\0' > "$R205/newline/record"
printf '### GH-7\n- text: good\n- generated: checks/GH-7.sh' > "$R205/newline/requirements/GH-7.md"
tok 'a generated file that lost its last newline is not its declaration' \
  'requirements/GH-7.md: not, byte for byte, its declaration in checks/GH-7.sh' \
  "$(generated_bad "$R205/newline/record" "$R205/newline/requirements" '')"
printf '\n' >> "$R205/newline/requirements/GH-7.md"
tok 'and with it back, it is' '' "$(generated_bad "$R205/newline/record" "$R205/newline/requirements" '')"
# And a NUL, which a command substitution drops, so that a comparison read
# through one took this file for its declaration.
printf '### GH-7\0\n- text: good\n- generated: checks/GH-7.sh\n' > "$R205/newline/requirements/GH-7.md"
tok 'and a NUL inserted in it is a byte that is not its declaration' \
  'requirements/GH-7.md: not, byte for byte, its declaration in checks/GH-7.sh' \
  "$(generated_bad "$R205/newline/record" "$R205/newline/requirements" '')"

# pins_bad, against a fixture holding one of each thing it names. GH-1 is the
# legacy set.
req GH-205.3
{
  printf 'GH-7\tchecks/GH-7.sh\t- text: a\n\0'
  printf 'GH-7.1\tchecks/GH-7.sh\t- text: b\n\0'
  printf 'GH-8\tchecks/GH-8.sh\t- text: c\n\0'
} > "$R205/pins-declared"
printf '%s\n' \
  $'shape\tchecks/GH-7.sh\tGH-7:static GH-9 GH-8' \
  $'shape\tchecks/GH-7.sh\tGH-7 :static' \
  $'variants\tchecks/GH-7.sh\tGH-7.1:none' > "$R205/pins-pinned"
tok 'pins_bad names a generated entry in either shared literal, and each pin that is not once, in the file that declares it' \
':static: a pin with no ID, in checks/GH-7.sh
GH-7.1: declared in checks/GH-7.sh, and its shape pinned nowhere
GH-7.1: in INV_SCOPE, which holds the legacy entries; a generated entry'"'"'s variants are pinned in the issue file that declares it
GH-7: in REQUIREMENT_SHAPE, which holds the legacy entries; a generated entry'"'"'s shape is pinned in the issue file that declares it
GH-7: its shape pinned a second time, in checks/GH-7.sh
GH-8: its shape pinned in checks/GH-7.sh, and declared in checks/GH-8.sh, where its pin belongs
GH-9: its shape pinned in checks/GH-7.sh, and no issue file declares it' \
  "$(pins_bad "$R205/pins-declared" "$R205/pins-pinned" 'US-1 GH-1:static GH-7:static' 'GH-1:seed GH-7.1:none' 'GH-1')"
tok 'and with each pinned once where it is declared, and the shared literals legacy, nothing' '' \
  "$(pins_bad "$R205/pins-declared" <(printf '%s\n' $'shape\tchecks/GH-7.sh\tGH-7 GH-7.1:static' $'shape\tchecks/GH-8.sh\tGH-8' $'variants\tchecks/GH-7.sh\tGH-7.1:none') \
      'US-1 GH-1:static' 'GH-1:seed' 'GH-1')"
# A declaration with no ID -- what `requirement "$UNSET"` records -- beside a
# real pin finding. The finding is still named: an empty ID made a subscript
# ends the helper before it prints anything, and none of the records above has
# one. The declaration itself is `generated_bad`'s to name, as out of grammar,
# and so is one whose ID is out of grammar and not empty, which pins_bad would
# otherwise ask for a pin no ID of that spelling can take.
{
  cat "$R205/pins-declared"
  printf '\tchecks/GH-7.sh\t- text: no ID\n\0'
  printf 'GH-07\tchecks/GH-7.sh\t- text: out of grammar\n\0'
} > "$R205/pins-empty-id"
tok 'and a declaration with no ID, or one out of grammar, leaves the pin findings beside it named and is not itself asked for a pin' \
'GH-9: its shape pinned in checks/GH-7.sh, and no issue file declares it' \
  "$(pins_bad "$R205/pins-empty-id" <(printf '%s\n' $'shape\tchecks/GH-7.sh\tGH-7 GH-7.1:static GH-9' $'shape\tchecks/GH-8.sh\tGH-8') \
      'US-1 GH-1:static' 'GH-1:seed' 'GH-1' 2>&1)"

# legacy_tokens, which splits a literal's tokens by whether the ID is legacy:
# the #141 comparison asks for the legacy half, and the end of the run for the
# other. Neither has a generated entry in the families' scope to split today,
# so what the split does is asked here.
tok 'legacy_tokens keeps the tokens whose ID is legacy, sorted, and only those' \
  'GH-1:seed GH-2 ' "$(legacy_tokens in 'GH-1 GH-2' 'GH-7:none GH-2 GH-1:seed GH-10:seed')"
tok 'and out keeps the others, a prefix of a legacy ID among them' \
  'GH-10:seed GH-7:none ' "$(legacy_tokens out 'GH-1 GH-2' 'GH-7:none GH-2 GH-1:seed GH-10:seed')"

# generate-requirements.sh, AGAINST A FIXTURE: a hooks directory holding an
# issue file and requirements/. The fixture's declarations are written with an
# `@` in front of the word and the `@` taken off as the file is made, so that no
# line of this file opens a declaration it does not mean.
req GH-205.2
r205_issue() {  # r205_issue <file> -- stdin, with the @ taken off each @requirement
  mkdir -p "$(dirname -- "$1")"
  sed 's/@requirement/requirement/' > "$1"
}
r205_gen() {  # r205_gen [--check] <dir> -- what the script printed, and its status
  bash "$HOOKS/generate-requirements.sh" "$@" 2>&1; printf 'exit %s' "$?"
}
mkdir -p "$R205/gen/requirements"
printf '### GH-4\n- text: hand-written\n' > "$R205/gen/requirements/GH-4.md"
r205_issue "$R205/gen/checks/GH-5.sh" <<'FIX'
section "a fixture"
@requirement GH-5.1 <<'REQ'
- text: a sub-entry,
  continued
- from: the fixture
REQ
req GH-5.1
@requirement GH-5 <<'REQ'
- text: a bare entry
REQ
FIX
tok 'with nothing written yet, --check names each declared file as not written, and writes nothing' \
'generate-requirements.sh: not what the issue files declare:
  requirements/GH-5.md is not written; checks/GH-5.sh declares it
  requirements/GH-5.1.md is not written; checks/GH-5.sh declares it
exit 1 GH-4.md' \
  "$(r205_gen --check "$R205/gen"; printf ' '; ls "$R205/gen/requirements" | tr '\n' ' ' | sed 's/ $//')"
tok 'a run writes each declared entry, in version order, and leaves the hand-written one alone' \
'wrote requirements/GH-5.md
wrote requirements/GH-5.1.md
exit 0' "$(r205_gen "$R205/gen")"
# Read through od, since a command substitution drops a NUL and the label says
# byte for byte.
tok 'the file is the heading, the fields byte for byte, and the issue file named last' \
  "$(printf '### GH-5.1\n- text: a sub-entry,\n  continued\n- from: the fixture\n- generated: checks/GH-5.sh\n|### GH-4\n- text: hand-written\n|' | od -c)" \
  "$({ cat "$R205/gen/requirements/GH-5.1.md"; printf '|'; cat "$R205/gen/requirements/GH-4.md"; printf '|'; } | od -c)"
tok 'a second run writes nothing' \
'generate-requirements.sh: every generated entry is its declaration; nothing was written
exit 0' "$(r205_gen "$R205/gen")"
tok 'and --check then names the generated entries' \
'generate-requirements.sh: every generated entry is its declaration: GH-5 GH-5.1
exit 0' "$(r205_gen --check "$R205/gen")"
printf -- '- note: edited by hand\n' >> "$R205/gen/requirements/GH-5.md"
tok 'a generated file edited by hand is named by --check, which writes nothing' \
'generate-requirements.sh: not what the issue files declare:
  requirements/GH-5.md differs from its declaration in checks/GH-5.sh
exit 1|1' "$(r205_gen --check "$R205/gen"; printf '|'; grep -c 'edited by hand' "$R205/gen/requirements/GH-5.md")"
tok 'and a run writes it back' \
'wrote requirements/GH-5.md
exit 0|0' "$(r205_gen "$R205/gen"; printf '|'; grep -c 'edited by hand' "$R205/gen/requirements/GH-5.md")"

# EACH REFUSAL, in a copy of the fixture with one thing broken, and in each
# nothing is written: the copy's requirements/ is read after the run.
r205_refused() {  # r205_refused <name> -- a copy of the written fixture, to break
  rm -rf "$R205/$1"; cp -r "$R205/gen" "$R205/$1"
}
r205_after() {  # r205_after <dir> -- the files requirements/ holds
  ls "$1/requirements" | tr '\n' ' ' | sed 's/ $//'
}
r205_refused spelled
r205_issue "$R205/spelled/checks/GH-6.sh" <<'FIX'
  @requirement GH-6 <<'REQ'
@requirement GH-6.1 <<REQ
@requirement GH-6.2 <<'EOF'
@requirement GH-6.3 extra <<'REQ'
@requirement  GH-6.4 <<'REQ'
FIX
# A second word after a tab, which bash splits as it splits a space, written
# with printf so that the tab is seen in this file.
printf 'requirement GH-6.5\tjunk <<%sREQ%s\n' "'" "'" >> "$R205/spelled/checks/GH-6.sh"
tok 'a declaration spelled each of these other ways is refused: indented, unquoted, another delimiter, a second word after a space or a tab, a double space' \
"generate-requirements.sh: refused, and nothing was written:
  checks/GH-6.sh: line 1: a declaration spelled other than requirement <ID> <<'REQ':   requirement GH-6 <<'REQ'
  checks/GH-6.sh: line 2: a declaration spelled other than requirement <ID> <<'REQ': requirement GH-6.1 <<REQ
  checks/GH-6.sh: line 3: a declaration spelled other than requirement <ID> <<'REQ': requirement GH-6.2 <<'EOF'
  checks/GH-6.sh: line 4: a declaration spelled other than requirement <ID> <<'REQ': requirement GH-6.3 extra <<'REQ'
  checks/GH-6.sh: line 5: a declaration spelled other than requirement <ID> <<'REQ': requirement  GH-6.4 <<'REQ'
  checks/GH-6.sh: line 6: a declaration spelled other than requirement <ID> <<'REQ': requirement GH-6.5$(printf '\t')junk <<'REQ'
exit 1|GH-4.md GH-5.1.md GH-5.md" "$(r205_gen "$R205/spelled"; printf '|'; r205_after "$R205/spelled")"
r205_refused grammar
r205_issue "$R205/grammar/checks/GH-6.sh" <<'FIX'
@requirement GH-06 <<'REQ'
- text: a leading zero
REQ
@requirement GH-6.0 <<'REQ'
- text: a sub-ID of zero
REQ
FIX
tok 'an ID outside the grammar is refused' \
'generate-requirements.sh: refused, and nothing was written:
  checks/GH-6.sh: line 1: GH-06 is not an ID of the grammar GH-<n> or GH-<n>.<m>
  checks/GH-6.sh: line 4: GH-6.0 is not an ID of the grammar GH-<n> or GH-<n>.<m>
exit 1|GH-4.md GH-5.1.md GH-5.md' "$(r205_gen "$R205/grammar"; printf '|'; r205_after "$R205/grammar")"
r205_refused twice
r205_issue "$R205/twice/checks/GH-6.sh" <<'FIX'
@requirement GH-5 <<'REQ'
- text: the same ID, in another issue file
REQ
FIX
tok 'an ID declared twice is refused, naming both files' \
'generate-requirements.sh: refused, and nothing was written:
  GH-5: declared twice, in checks/GH-5.sh and in checks/GH-6.sh
exit 1|GH-4.md GH-5.1.md GH-5.md' "$(r205_gen "$R205/twice"; printf '|'; r205_after "$R205/twice")"
r205_refused unclosed
r205_issue "$R205/unclosed/checks/GH-6.sh" <<'FIX'
@requirement GH-6 <<'REQ'
- text: never closed
FIX
tok 'a declaration never closed is refused' \
'generate-requirements.sh: refused, and nothing was written:
  checks/GH-6.sh: GH-6 is declared at line 1 and never closed by a line reading REQ
exit 1|GH-4.md GH-5.1.md GH-5.md' "$(r205_gen "$R205/unclosed"; printf '|'; r205_after "$R205/unclosed")"
r205_refused body
r205_issue "$R205/body/checks/GH-6.sh" <<'FIX'
@requirement GH-6 <<'REQ'
REQ
@requirement GH-6.1 <<'REQ'
  a continuation of no field
- text: then a field

REQ
@requirement GH-6.2 <<'REQ'
- text: a field
- generated: checks/GH-1.sh
REQ
FIX
tok 'a body that is empty, holds a line that is no field, or carries its own generated field is refused' \
'generate-requirements.sh: refused, and nothing was written:
  checks/GH-6.sh: line 1: GH-6 is declared with no fields
  checks/GH-6.sh: line 4: GH-6.1: a line that is no field of the entry:   a continuation of no field
  checks/GH-6.sh: line 6: GH-6.1: a blank line, where every line opens a field or continues one
  checks/GH-6.sh: line 10: GH-6.2 carries a generated field of its own, which is this script'"'"'s to write
exit 1|GH-4.md GH-5.1.md GH-5.md' "$(r205_gen "$R205/body"; printf '|'; r205_after "$R205/body")"
r205_refused hand
r205_issue "$R205/hand/checks/GH-6.sh" <<'FIX'
@requirement GH-4 <<'REQ'
- text: a declaration of an entry written by hand
REQ
FIX
tok 'a declared ID whose file is hand-written is refused, and the file is left as it was' \
'generate-requirements.sh: refused, and nothing was written:
  GH-4: declared in checks/GH-6.sh, and requirements/GH-4.md is hand-written, which this does not replace
exit 1|### GH-4
- text: hand-written' "$(r205_gen "$R205/hand"; printf '|'; cat "$R205/hand/requirements/GH-4.md")"
r205_refused orphan
r205_issue "$R205/orphan/checks/GH-5.sh" <<'FIX'
@requirement GH-5 <<'REQ'
- text: a bare entry
REQ
FIX
tok 'a generated file no issue file declares any more is refused, and left where it is' \
'generate-requirements.sh: refused, and nothing was written:
  requirements/GH-5.1.md: generated from checks/GH-5.sh, which no longer declares GH-5.1
exit 1|GH-4.md GH-5.1.md GH-5.md' "$(r205_gen "$R205/orphan"; printf '|'; r205_after "$R205/orphan")"
# And a refused run writes nothing even where it would otherwise have written:
# a fixture whose one file is stale and whose other declaration is broken.
r205_refused partial
printf -- '- note: stale\n' >> "$R205/partial/requirements/GH-5.md"
r205_issue "$R205/partial/checks/GH-6.sh" <<'FIX'
@requirement GH-06 <<'REQ'
- text: out of grammar
REQ
FIX
tok 'and a refusal writes nothing at all, not even the file it would have rewritten' \
'exit 1|1' "$(bash "$HOOKS/generate-requirements.sh" "$R205/partial" > /dev/null 2>&1; printf 'exit %s|' "$?"; grep -c 'stale' "$R205/partial/requirements/GH-5.md")"
tok 'and --check reports the refusal alone, not the stale file beside it' \
'generate-requirements.sh: refused, and nothing was written:
  checks/GH-6.sh: line 1: GH-06 is not an ID of the grammar GH-<n> or GH-<n>.<m>
exit 1' "$(r205_gen --check "$R205/partial")"
tok 'a malformed argument list is a usage error, each way, an empty directory among them' '64 64 64' \
  "$(bash "$HOOKS/generate-requirements.sh" --bogus > /dev/null 2>&1; printf '%s ' "$?"
     bash "$HOOKS/generate-requirements.sh" "$R205/gen" "$R205/gen" > /dev/null 2>&1; printf '%s ' "$?"
     bash "$HOOKS/generate-requirements.sh" --check '' > /dev/null 2>&1; printf '%s' "$?")"

# A READING THAT FOUND NOTHING BECAUSE IT READ NOTHING is refused, each way it
# happens, rather than taken for a directory with nothing to generate: a
# directory that is not there, one with no checks/, and an awk that died
# (review of PR #222, round 3).
tok 'a hooks directory that is not there is refused' \
"generate-requirements.sh: refused, and nothing was written:
  $R205/no-such-dir is not a directory holding checks/, so there is no issue file to read
exit 1" "$(r205_gen --check "$R205/no-such-dir")"
mkdir -p "$R205/no-checks/requirements"
tok 'and so is one with no checks/' \
"generate-requirements.sh: refused, and nothing was written:
  $R205/no-checks is not a directory holding checks/, so there is no issue file to read
exit 1" "$(r205_gen "$R205/no-checks")"
# The awk that dies is a stand-in first on PATH that exits 2, since a file awk
# cannot open is readable all the same to root.
mkdir -p "$R205/dead-awk"
printf '#!/bin/sh\nexit 2\n' > "$R205/dead-awk/awk"
chmod +x "$R205/dead-awk/awk"
tok 'an awk that died is a failed reading, not an empty one' \
'generate-requirements.sh: reading the issue files failed, awk exit 2; nothing was written
exit 1' "$(PATH="$R205/dead-awk:$PATH" r205_gen --check "$R205/gen")"
# The stage's path reaches awk whole: under a TMPDIR holding a backslash and a
# `t`, which `awk -v` would read as a tab and fail to open, the refusal is still
# the one the declaration earns.
r205_refused tmpdir
printf 'requirement GH-6\tjunk <<%sREQ%s\n' "'" "'" > "$R205/tmpdir/checks/GH-6.sh"
mkdir -p "$R205/tmp\\t"
tok 'a TMPDIR holding a backslash escape is a path, not an escape' \
"generate-requirements.sh: refused, and nothing was written:
  checks/GH-6.sh: line 1: a declaration spelled other than requirement <ID> <<'REQ': requirement GH-6$(printf '\t')junk <<'REQ'
exit 1" "$(TMPDIR="$R205/tmp\\t" r205_gen --check "$R205/tmpdir")"

# HELD TO THIS SUITE, the script is run over `generator_view`: the issue files
# from the suite's side and requirements/ from the judged side. So a judged side
# with no checks/ is not asked for one, and it is its requirements/, not the
# suite's, that are read. The suite's side here is the written fixture.
mkdir -p "$R205/judged"; cp -r "$R205/gen/requirements" "$R205/judged/"
tok 'over the view, a judged side with no checks/ is read against the suite'"'"'s declarations' \
'generate-requirements.sh: every generated entry is its declaration: GH-5 GH-5.1
exit 0' "$(r205_gen --check "$(generator_view "$R205/gen" "$R205/judged" "$R205/view")")"
printf -- '- note: stale on the judged side\n' >> "$R205/judged/requirements/GH-5.md"
tok 'and it is the judged side'"'"'s requirements/ that is read' \
'generate-requirements.sh: not what the issue files declare:
  requirements/GH-5.md differs from its declaration in checks/GH-5.sh
exit 1' "$(r205_gen --check "$(generator_view "$R205/gen" "$R205/judged" "$R205/view")")"

sourced_to_end

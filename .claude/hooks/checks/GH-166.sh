#!/bin/bash
# THE ISSUE FILE OF #166: bash's two other quoting forms, ANSI-C `$'...'` and
# locale `$"..."`, are read as quoting wherever the library reads a word BY
# NAME -- the command word, a prefix word, a wrapper word and a gh option --
# and the escapes `$'...'` interprets are decoded as bash decodes them.
#
# Why: no word reader in lib/command-scan.sh knew that a `$` in front of a quote
# goes with the quote. cw_reduce reduced `$'git'` to `$git`, which names
# nothing, so `$'git' push origin main` was not a push to any hook, and the
# same held for every word the library matches by name -- `$'sudo'` left the
# real push behind it read as sudo's arguments, and `$'bash' -c` reached no
# wrapper rule at all. Measured at origin/dev-05 a109c2f, every command a flip
# below names was permitted by all four boundary hooks; each row asks the one
# hook that refuses its bare spelling there.
#
# THE READER WAS ALREADY WRITTEN, once, in the wrong place: quoted_base_flag in
# no-pr-decisions.sh decoded `$'...'` over five rounds of Bertan's review of
# PR #173, for one flag in one hook. #166 lifts it into the library as
# CS_WORD_AWK, and cw_reduce, ghreduce and quoted_base_flag all read words
# through it. The dequoting question had two answers, and the disagreement was
# the ALLOW column; it has one now, and the check at the foot of this file holds
# it to one.
#
# WHAT IS NOT HERE. The group and the verb -- `git $'push'`, `gh $'pr'`,
# `gh $'api'` -- are #135's, whose fix site is cs_git_args and cs_gh_args'
# path comparison; they stay permitted when this closes, and #135 is to call
# the reader this lifts rather than grow a fourth answer. Plain expansion and
# command substitution in a command position are CLAUDE.md's consequence 6.
# #118's three boundary rows for an option in these quotes are flips now, and
# stay in #118's issue file with this issue's tag: a check lives in the file of
# the issue whose work wrote it, and #166 changed their verdict, not their text.
# no-work-on-stale-branch.sh is reached through the invariance families, whose
# commit-stale seed runs in a fixture the unsplit file owns; `word-ansi`,
# `word-locale` and `pre-sudo-ansi` are this issue's three transformations.
section "=== issue #166: ANSI-C and locale quoting, read as quoting in every word read by name ==="

requirement GH-166 <<'REQ'
- text: A word the library reads BY NAME is the word it spells when it is written
  in ANSI-C quotes `$'...'` or locale quotes `$"..."`: `$'git' push origin main`,
  `$"git" push origin main`, `$'gh' pr merge 5` and `$"gh" pr merge 5` reach the
  verdicts their bare spellings reach, and so do the prefix words
  (`$'sudo' git push origin main`, `$'timeout' 30 git push --all origin`), the
  wrapper words (`$'bash' -c "git push origin main"`) and a gh option in front of
  a subcommand (`gh pr $'-t' view merge 5`, refused as unreadable). The escapes
  inside `$'...'` are decoded as bash decodes them -- `$'\x67it'` and
  `$'\147\150'` are `git` and `gh` -- a NUL cuts the rest of its span, so
  `$'git\x00junk'` is `git`, and every `\c` is taken as a possible NUL and cuts
  the span without being decoded. One reader answers this, `CS_WORD_AWK` in
  `lib/command-scan.sh`, and no hook keeps a private decoder. Permitted as
  before: `$'git' status`, `$'gh' issue list`, an empty span in front of a
  command (`$'' git push origin main`, `$"" git push origin main`,
  `$'' bash -c "git push origin main"`), and an ANSI-C argument holding escaped
  newlines, which is decoded per word and never across the line.
- from: #166, found while implementing #135
- kind: defect-permitting
- status: active
- variants: transformation: word-ansi word-locale pre-sudo-ansi
- note: the group and the verb, `git $'push'` and `gh $'pr'`, are NOT this entry:
  they are #135's fix site and stay permitted until it lands, a trade the triage
  of #166 took with its eyes open. The empty span is permitted on `cw_reduce`'s
  empty-basename case, measured at a109c2f -- rc=0 in all four boundary hooks
  -- and safe because bash runs nothing for an empty command word: `$'' echo hi`
  is `: command not found`, exit 127, verified by Bertan in the triage. In front
  of a wrapper it suppresses the wrapper arm as well as the ordinary rule, since
  `CS_WRAPPER_RE` wants the wrapper word at a line start or after a separator and
  `$''` stands between; the controls that fix that mechanism are rows. The
  wrapper anchor reaches `$'bash'` and `$"bash"` and not an escape inside one,
  `$'\x62ash' -c ...`, which is permitted: a regular expression cannot decode,
  and that is the same accepted gap as `b"a"sh`. `ghreduce` reading through the
  reader closes #118's three boundary rows for an option in these quotes, which
  that issue file pinned as permitted and assigned here; its trade is that a
  doubled backslash is one backslash, as bash has it, so `gh pr \\-t view merge
  5` is no longer read as `-t`. The dequoting semantics are bash's rather than
  the union of the two old answers: inside double quotes a backslash escapes
  only `\`, `"`, `$` and a backtick, where `cw_reduce` took it to escape
  anything, so `"\g"it push origin main` is no longer `git`; and a backslash
  ending the string is a backslash, so `git\ push origin main`, one word to bash,
  is no longer read as `git` and then `push`. Those three were refused at
  a109c2f and are permitted now, each pinned as a trade: none runs the guarded
  command. The widened wrapper anchor costs the other way: `"$'bash'" -c ...`,
  text to bash, is refused. The triage asked for this entry to be appended to
  `requirements.md`; it is declared in this issue file and generated instead,
  which is the convention since #205. The
  separator walk in `cs_split` still pairs `$'...'` as `'...'`, so an escaped
  quote ends the span early and can hide a command after it; that is pre-existing,
  identical at a109c2f, is not a word read by name, and is #252.
REQ
shape_pin 'GH-166'
variants_pin 'GH-166:transformation'

# THE COMMAND WORD, in both quoting forms and in every hook whose bare spelling
# is refused. no-git-push.sh runs in the linked worktree fixture, where the only
# thing that refuses a push naming main is that it names main; no-commit-to-main.sh
# runs on a dev branch, where the same push is refused for the same reason.
req GH-166 US-1
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'an ANSI-C quoted command word, a push to main' \
  "\$'git' push origin main"
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'a locale quoted command word, a push to main' \
  '$"git" push origin main'
flip "$ON_DEV" no-commit-to-main.sh ALLOW BLOCK 'an ANSI-C quoted command word, a push naming main' \
  "\$'git' push origin main"
flip "$ON_DEV" no-commit-to-main.sh ALLOW BLOCK 'a locale quoted command word, a push naming main' \
  '$"git" push origin main'
flip "$ON_MAIN" no-commit-to-main.sh ALLOW BLOCK 'an ANSI-C quoted command word, a commit on main' \
  "\$'git' commit -m wip"
req GH-166 US-15
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an ANSI-C quoted command word, a merge' \
  "\$'gh' pr merge 5"
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a locale quoted command word, a merge' \
  '$"gh" pr merge 5'
# The api arm is entered only where cs_gh_args finds `gh api`, so a command
# word it could not read stepped past every endpoint rule at once.
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an ANSI-C quoted command word, the REST merge endpoint' \
  "\$'gh' api -X PUT repos/o/r/pulls/5/merge"
req GH-166 FR-15 FR-16
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an ANSI-C quoted command word, a create naming main' \
  "\$'gh' pr create --base main --title x"

# THE ESCAPES, decoded as bash decodes them. Hex and octal spell the name; a
# NUL ends what its span contributes, so the junk after it is not part of the
# word; and `\c` cuts the span too, consuming only the `c`, which is #139's
# answer and is not re-derived here.
req GH-166 US-1
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'a hex escape spelling the command word' \
  "\$'\\x67it' push origin main"
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'a NUL cutting the command word to git' \
  "\$'git\\x00junk' push origin main"
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'a \c cutting the span rather than decoding' \
  "\$'git\\cA' push origin main"
req GH-166 US-15
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'octal escapes spelling the whole command word' \
  "\$'\\147\\150' pr merge 5"

# THE PREFIX WORD, which is the widest of these: a prefix word nobody strips
# stands as the command word itself, so the push behind it is read as its
# arguments and is not a command at all.
req GH-166 US-1
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'an ANSI-C quoted sudo in front of a push' \
  "\$'sudo' git push origin main"
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'an ANSI-C quoted timeout, with its operand' \
  "\$'timeout' 30 git push --all origin"
flip "$ON_DEV" no-commit-to-main.sh ALLOW BLOCK 'an ANSI-C quoted sudo in front of a push naming main' \
  "\$'sudo' git push origin main"
req GH-166 US-15
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'a locale quoted timeout in front of a merge' \
  '$"timeout" 30 gh pr merge 5'

# THE WRAPPER WORD, which CS_WRAPPER_RE reads in raw text and so has to admit
# the spelling itself. Its run of quote characters in front of the name had no
# `$`, so the anchor stopped dead on it.
req GH-166 FR-4
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'an ANSI-C quoted wrapper word' \
  "\$'bash' -c \"git push origin main\""
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'a locale quoted wrapper word' \
  '$"bash" -c "git push origin main"'
flip "$ON_DEV" no-commit-to-main.sh ALLOW BLOCK 'an ANSI-C quoted wrapper word, beside a push naming main' \
  "\$'bash' -c \"git push origin main\""
flip "$SUITE_DIR" no-pr-decisions.sh ALLOW BLOCK 'an ANSI-C quoted wrapper word around a merge' \
  "\$'bash' -c \"gh pr merge 5\""
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'an ANSI-C quoted prefix word in front of a wrapper' \
  "\$'sudo' bash -c \"git push origin main\""
# THE WRAPPER ANCHOR DOES NOT DECODE, and this is the gap that says so: a
# regular expression can admit a `$` in front of a quote and cannot turn
# `\x62ash` into `bash`. It is permitted for the reason `b"a"sh` is, which
# CS_WORD_SPELLING's own comment sets out.
req GH-166
check_in "$PUSH_WT" no-git-push.sh ALLOW 'BOUNDARY: an escape inside the wrapper word, which the anchor cannot decode' \
  "\$'\\x62ash' -c \"git push origin main\""

# WHAT STAYS PERMITTED, each a row a plausible fix turns red.
req GH-166
check_in "$PUSH_WT" no-git-push.sh ALLOW 'an ANSI-C quoted command word, git status' \
  "\$'git' status"
req GH-166 US-3
check_in "$PUSH_WT" no-git-push.sh ALLOW 'an ANSI-C quoted command word, a push of this worktree own branch' \
  "\$'git' push origin $PUSH_BRANCH"
req GH-166 US-14
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'an ANSI-C quoted command word, gh issue list' \
  "\$'gh' issue list"
req GH-166 US-13
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'a locale quoted command word, gh pr view' \
  '$"gh" pr view 5'

# THE TRADES, pinned rather than only written down. The shared reader answers
# what bash passes, so three spellings the old walks over-read are read as bash
# reads them, and each moved from refused to permitted. None of them runs the
# guarded command: bash runs a program named with the backslash, or a program
# whose name holds a space, and gh rejects an option-shaped word it does not
# know as a subcommand. Measured against a109c2f on stdin, BLOCK there in
# no-git-push.sh, no-commit-to-main.sh and no-pr-decisions.sh respectively.
req GH-166
flip "$PUSH_WT" no-git-push.sh BLOCK ALLOW 'THE TRADE: inside double quotes a backslash before an ordinary character is kept' \
  '"\g"it push origin main'
flip "$PUSH_WT" no-git-push.sh BLOCK ALLOW 'THE TRADE: an escaped blank makes one word, and the backslash ending the token is kept' \
  'git\ push origin main'
flip "$SUITE_DIR" no-pr-decisions.sh BLOCK ALLOW 'THE TRADE: a doubled backslash in front of an option is one backslash, so the word is no option' \
  'gh pr \\-t view merge 5'
# And the one the widened anchor costs, in the refusing direction: a `$` and a
# quote inside a double-quoted word are text to bash, and the run cannot tell.
req GH-166 FR-4
flip "$PUSH_WT" no-git-push.sh ALLOW BLOCK 'THE TRADE: an ANSI-C spelling inside double quotes, read by the anchor as a wrapper' \
  "\"\$'bash'\" -c \"git push origin main\""

# THE EMPTY SPAN, on cw_reduce's empty-basename case: a word that reduces to
# nothing names no file and is left alone, and `$''` and `$""` reduce to
# nothing. Bash runs nothing for an empty command word -- `$'' echo hi` is
# `: command not found`, exit 127 -- so nothing pushes and permitting is safe.
# The control is the bare push, refused by both hooks that refuse it.
req GH-166
check_in "$PUSH_WT" no-git-push.sh ALLOW 'an empty ANSI-C span as the command word' \
  "\$'' git push origin main"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'an empty locale span as the command word' \
  '$"" git push origin main'
check_in "$ON_DEV" no-commit-to-main.sh ALLOW 'an empty ANSI-C span as the command word, on a dev branch' \
  "\$'' git push origin main"
check_in "$ON_DEV" no-commit-to-main.sh ALLOW 'an empty locale span as the command word, on a dev branch' \
  '$"" git push origin main'
req GH-166 US-1
check_in "$PUSH_WT" no-git-push.sh BLOCK 'the control: the bare push the empty span stands in front of' \
  'git push origin main'
check_in "$ON_DEV" no-commit-to-main.sh BLOCK 'the control on a dev branch: the same bare push' \
  'git push origin main'
# And what the carve-out costs, which is two arms rather than one: CS_WRAPPER_RE
# wants the wrapper word at a line start or after a separator, and `$''` stands
# between, so the wrapper arm is suppressed with the ordinary rule. The two
# controls fix the mechanism: a wrapper in a command position with a push
# anywhere on the line is refused, which is CLAUDE.md's consequence 2, and the
# push as prose with no wrapper is not.
req GH-166
check_in "$PUSH_WT" no-git-push.sh ALLOW 'an empty ANSI-C span in front of a wrapper suppresses the wrapper arm too' \
  "\$'' bash -c \"git push origin main\""
check_in "$PUSH_WT" no-git-push.sh ALLOW 'its control: the push as prose, with no wrapper' \
  "echo 'git push origin main'"
req GH-166 FR-4
check_in "$PUSH_WT" no-git-push.sh BLOCK 'its control: a wrapper in a command position, the push anywhere on the line' \
  "bash -c \"make test\" && echo 'git push origin main'"

# THE PROBE SEEDS, the regression surface the triage measured. Every ANSI-C
# span in a command position across 807 session transcripts was one of these:
# an argument whose escapes spell a newline and a command after it. The reader
# decodes the WORD it is asked about and never the line, so the `\n` here stays
# two characters and manufactures no command position bash never had.
req GH-166
check_in "$SUITE_DIR" no-pr-decisions.sh ALLOW 'a probe seed: an ANSI-C argument whose newline precedes gh release' \
  "echo \$'gh release \\\\\\n upload v1 a.tgz'"
check_in "$ON_MAIN" no-commit-to-main.sh ALLOW 'a probe seed: an ANSI-C argument whose newline precedes a commit' \
  "echo \$'cat <<\\'E\\'\\ngit commit -m wip'"
check_in "$PUSH_WT" no-git-push.sh ALLOW 'a probe seed piped into this hook, its push behind an escaped newline' \
  "printf '%s' \$'git push \\\\\\n  origin main' | .claude/hooks/no-git-push.sh"

# ONE READER. The dequoting question is answered in lib/command-scan.sh and
# nowhere else. What these can see is SPELLINGS, and the labels say so: the hex
# escape dispatch as the reader writes it and the hex digit table it reads with
# appear in one file under the hooks directory, and each consumer calls the
# reader. A private decoder written another way, or a consumer that calls the
# reader and walks the word again beside it, passes them; review is what holds
# those, and the lift removed the one copy that existed.
# The tooling is left out by the suite's own rule for it: mutate-hooks.sh
# carries the dispatch as the text its registry rows edit, and is not a reader.
req GH-166
DECODERS=
for f in "$HOOKS"/*.sh "$HOOKS"/lib/*.sh; do
  rel=${f#"$HOOKS"/}
  [[ $rel =~ $TOOLING ]] && continue
  grep -qF -e 'e == "x"' -e '"0123456789abcdef"' "$f" && DECODERS="$DECODERS$rel "
done
if [ "$DECODERS" = "lib/command-scan.sh " ]; then
  pass static 'the hex escape dispatch and digit table, as the reader spells them, are in lib/command-scan.sh alone'
else
  fail static 'the hex escape dispatch or digit table is spelled in |%s|, where it belongs in lib/command-scan.sh alone' "$DECODERS"
fi
for consumer in cw_reduce ghreduce; do
  body=$(sed -n "/function $consumer(/,/^    }\$\|^  }\$/p" "$HOOKS/lib/command-scan.sh")
  case "$body" in
    *wd_next*) pass static '%s reads its word through the shared reader' "$consumer" ;;
    *) fail static '%s does not call wd_next, so it answers the dequoting question itself' "$consumer" ;;
  esac
done
body=$(sed -n '/^quoted_base_flag()/,/^}/p' "$HOOKS/no-pr-decisions.sh")
case "$body" in
  *'$CS_WORD_AWK'*wd_next*) pass static 'quoted_base_flag reads its words through the shared reader' ;;
  *) fail static 'quoted_base_flag does not interpolate CS_WORD_AWK and call wd_next, so it keeps a private reader' ;;
esac

# THE READER IS PART OF THE LOAD. Emptied in the file, the library withdraws
# every function whose program calls it and says which variable it withdrew for;
# left running, those programs would not compile, awk would exit 2 without
# reading, and every caller would read "not this command" -- permitting. This
# drives the state the withdrawal reaches, the way #118's issue file drives
# CS_GH_AWK's: the assignment emptied and the old text left as the argument of a
# `:`, so the library loads with CS_WORD_AWK empty and nothing else changed.
# Emptied AFTER the library is sourced, which no consumer does, it is a program
# that does not compile, and that is #242's for every awk program in the file.
req GH-166
sed "s/^CS_WORD_AWK='\$/CS_WORD_AWK=; : '/" "$HOOKS/lib/command-scan.sh" \
  > "$FIXTURES/emptyreader-word-awk.sh"
R166_EMPTY_SAYS=$(bash -c ". '$FIXTURES/emptyreader-word-awk.sh'
  for f in cs_split cs_gh_args cs_gh_opaque cs_normalise; do
    command -v \$f >/dev/null && echo \$f=present || echo \$f=absent
  done" 2>&1)
tok 'an emptied CS_WORD_AWK withdraws the three functions whose programs call it, and says so' \
    'lib/command-scan.sh: CS_WORD_AWK is empty. cs_split, cs_gh_args and cs_gh_opaque are withdrawn, so every consumer that requires them refuses.|cs_split=absent|cs_gh_args=absent|cs_gh_opaque=absent|cs_normalise=present' \
    "$(printf '%s' "$R166_EMPTY_SAYS" | tr '\n' '|')"

sourced_to_end

#!/bin/bash
# THE ISSUE FILE OF #157: a dev-log entry is named for the session that writes
# it and never numbered, and an entry that exists is appended to with `>>`.
#
# Why: an entry was named `devlog_<date>_session-<n>.md`, with <n> counted from
# the entries that already exist. A worktree branch sees only the dev branch
# and itself, so branches writing on one day counted to the same number -- six
# took one name and three another, measured on the branch tips when #157 was
# filed -- and the append-only guards, working as intended, leave no way to
# rename an entry afterwards. The naming half was fixed in the README on
# 2026-09-18, by naming an entry for the writing session, and nothing held it.
# The append rule that came with it asked for an append and did not say how,
# though the Edit and Write tools are the wrong route and `>>` the one the
# Bash guard documents.
#
# WHAT IS READ is the Conventions section of docs/dev-log/README.md -- the
# lines between `## Conventions` and the next `## ` heading, the headings left
# out -- as comment_reflow reads it, which joins the lines and squeezes the
# blanks, with the blanks at either end taken off. So a rule rewrapped, or
# re-indented with spaces under its bullet, stays green; a tab indent turns a
# pin red, because the reader squeezes spaces and not tabs. The input is
# Markdown and not comments, which that reader was written for; the one place
# the two differ is a line opening with `#`, whose `#` it takes off. Every
# issue number in the section is written in parentheses, so no rewrap starts a
# line with one; a bare number wrapped to a line's start would lose its `#` and
# turn a pin red, never green. The path is spelled under $SUITE_DIR/.. so that
# the check on this suite's header, which derives the documents the suite
# reads from that spelling, holds the header to naming a `README.md` -- by
# basename, so any file of that name satisfies it (#235).
#
# THE PINS ARE CHAINED. Each pinned bullet is asked whole, and each pin runs on
# into the first words of the bullet after it; the first starts at the head of
# the section. So from the section's first word to the opening words of the
# bullet after the append rule, nothing can be added between two pinned
# sentences, after a pinned bullet, or between two bullets, in any spelling --
# a sentence, a nested sub-bullet, a spaced hyphen, a new bullet -- without a
# pin going red. Two earlier versions were narrower, and review of #234
# measured each: one pin per sentence left text between two sentences of a
# bullet unseen (round 1), and a pin that ended on the bare ` - ` of the next
# bullet was satisfied by a nested sub-bullet or an inline ` - `, which the
# reader flattens to the same three characters (round 2). The cost is the
# coupling: rewording a bullet's first words turns the pin above it red.
#
# WHAT IT DOES NOT SEE, named. The files on disk: the checks ask what the
# README says and never whether an entry's name has the shape it states,
# because the entries named under the numbered convention are history and a
# walk of the directory would be red on arrival. The README's other sections,
# for the same reason: its Entries section links every numbered name. Inside
# the chain, the middle of the one unpinned bullet in it, the one on how an
# entry opens, which is not #157's rule: its first words and its last are in
# the pins either side, and the text between is not. After the chain -- from
# the opening of the bullet on who the log is written for -- a new bullet is
# the limit #145 owns, and the `lacks` below close part of it. They read the
# section lowercased, with the literal `SESSION-NAME` taken out first, so the
# numbered name's stem `session-` is red in any case -- `session-N`,
# `Session-<n>`, `SESSION-1` -- while the name the rule gives is not; a
# numbered name that drops the stem, `devlog_<date>_3.md`, is not seen. The
# counting rule and the claim that Edit and Write are refused are each one
# phrase, and the same claim in other words is not seen.
#
# WHAT THE GUARDS DO, MEASURED (GH-157.3). The append bullet says what the two
# append-only guards do, and a pin of that text is evidence about the text and
# not about the guards: its first version said a heredoc whose prose
# "mentions a path" can be refused, and fed on stdin such a heredoc is
# permitted (review of #234, round 1). So every example the bullet gives is
# also fed to its guard, with the verdict the bullet states, and the Edit guard
# is fed both tools the bullet names, in both directions it names. The
# sentences rest on two open issues, #176 for the heredoc and #159 for the Edit
# guard. What is measured is that each remedy those issues propose turns a
# check here red: #159's two, resolving the enclosing repository with git and
# matching the directory's trailing segments, and #176's, not reading a
# heredoc's body. A fix of another shape is not known to. The Edit fixture is
# a real repository with a linked worktree inside it, as agents' stand,
# because #159's first remedy asks git where the file is; a plain directory
# answered neither remedy the same, and review of #234 measured the first
# remedy leaving the suite green against one (round 2).

section "=== issue #157: a dev-log entry is named for its session, and appended to with >> ==="

requirement GH-157.1 <<'REQ'
- text: The Conventions section of `docs/dev-log/README.md` opens with a
  bullet naming an entry `devlog_YYYY-MM-DD_SESSION-NAME.md`, for the session
  name of the agent writing it, and says the agent reads that name from
  `ListAgents` when it does not know it. It says the name is never a number
  counted from the entries that already exist, and why, and that entries
  named under the earlier numbered convention keep their names. The bullets
  are read whole and chained, each pin running into the first words of the
  next bullet, so nothing is added between or after them unseen. It does not
  carry the convention it replaced: read lowercased with `SESSION-NAME` taken
  out, nothing in it is spelled `session-`, the stem every spelling of the
  numbered name carries, and it lacks the counting rule's phrase
  `counts sessions within that day`. Read with the lines joined, so a rewrap
  with spaces is not a change.
- from: #157, and review of #234
- kind: doc-claim
- status: active
- direction: static: it reads the README's text against literals
- note: What the README says, and never what the directory holds: an entry
  named under the numbered convention is history, and a check that walked
  the directory would be red on arrival. A new bullet after the chain that
  contradicts the rule is not seen, which is the limit #145 owns, except
  where it spells the stem; a numbered name without the stem, and the
  counting rule in other words, are not seen.
REQ
requirement GH-157.2 <<'REQ'
- text: The Conventions section of `docs/dev-log/README.md` says that when
  the entry an agent would write already exists, it appends a new entry to
  it with a date and time; that the append is made with `>>` from Bash, and
  an entry that exists is never edited with the Edit or Write tool; that a
  heredoc append whose prose reads as a command that rewrites an entry can
  be refused (#176) -- a `sed -i` anywhere in the text, for example, or an
  `rm`, an `mv` or a `>` followed on its line by a path under the directory
  -- so the text is written to a scratch file and appended with
  `cat <file> >> <entry>`; and that `append-only-docs-edit.sh` does not yet
  refuse Edit or Write on an entry outside the session's project directory,
  in another checkout of this repository, in either direction (#159), so
  that there the rule is held by the agent and not by a guard. It does not
  carry the phrase `are refused on an entry that already exists`, the first
  triage brief's wording of a claim that is false in that case. The bullets
  are read whole and chained, as GH-157.1's are.
- from: #157, and review of #234
- kind: doc-claim
- status: active
- direction: static: it reads the README's text against literals
- note: An instruction and not a claim about the guard, because the claim is
  false in the case above. Whether the guards behave as the bullet says is
  GH-157.3's. The `lacks` is one phrase: the same claim in other words is
  not seen, which is the limit #145 owns.
REQ
requirement GH-157.3 <<'REQ'
- text: What the Conventions section of `docs/dev-log/README.md` says the two
  append-only guards do, they do. `append-only-docs.sh` refuses a heredoc
  append to an entry whose text carries a `sed -i` with no path beside it,
  or an `rm`, an `mv` or a `>` followed on its line by a path under
  `docs/dev-log/` (#176); it permits one whose text only names such a path,
  one whose `rm` has its path on the next line, and `cat <file> >> <entry>`.
  `append-only-docs-edit.sh`, given a repository with a linked worktree in
  it and an existing entry in each, permits an Edit and a Write of the
  worktree's entry when the project directory is the main checkout, and of
  the main checkout's when it is the worktree (#159); and refuses both tools
  on each checkout's own entry.
- from: review of #234, rounds 1 and 2
- kind: doc-claim
- status: active
- note: Two of these verdicts are defects that the README routes around, and
  they are asserted at today's verdict so that the README's sentence and
  the guard cannot part silently: the heredoc refusals are #176's, and the
  four permitted edits are #159's, whose right verdict is BLOCK. Measured:
  each remedy the two issues propose turns a check here red; a fix of
  another shape is not known to. Not in the invariance families' scope: it
  is a `doc-claim`, about what a document says of the guards, and the
  examples are the document's own.
REQ
shape_pin 'GH-157.1:static GH-157.2:static GH-157.3'

r157_conventions() {  # r157_conventions <file> -- its Conventions section, as comment_reflow reads it, ends trimmed
  awk '
    on && /^## / { exit }
    on { print }
    $0 == "## Conventions" { on = 1 }' "$1" | comment_reflow | sed 's/^ *//; s/ *$//'
}
# Driven first, against a literal: the section and nothing either side of it,
# a bullet wrapped at a hyphen, re-indented and given trailing blanks reads as
# the same words, the bullet after it follows on one blank, and the blanks at
# either end are gone.
R157_FIX="$FIXTURES/r157-readme.md"
printf '%s\n' '# Dev Log' 'before' '## Conventions' '' '- File name: `devlog_YYYY-MM-DD_SESSION-' \
  '     NAME.md`, where  ' '  it ends.' '- Next.' '' '## Entries' 'after' > "$R157_FIX"
req GH-157.1 GH-157.2
tok 'the Conventions section is read to the next heading, with a rewrap joined' \
    '- File name: `devlog_YYYY-MM-DD_SESSION-NAME.md`, where it ends. - Next.' \
    "$(r157_conventions "$R157_FIX")"

R157_README="$SUITE_DIR/../../docs/dev-log/README.md"
R157_CONV=$(r157_conventions "$R157_README")
# The first pin starts at the head of the section, so the section is asked with
# a mark in front of it that no README line can supply.
R157_HEAD="<section>$R157_CONV"
# What the absences read: lowercased, with the one spelling the rule gives taken
# out first, so the stem is asked in every case and the rule's own name is not it.
R157_LOW=$(printf '%s' "$R157_CONV" | sed 's/SESSION-NAME//g' | tr '[:upper:]' '[:lower:]')

req GH-157.1
holds 'the dev-log README opens its Conventions on naming an entry for the session that writes it' "$R157_HEAD" \
  '<section>- File name: `devlog_YYYY-MM-DD_SESSION-NAME.md`, where `SESSION-NAME` is the session name of the agent writing the dev-log. - The name is never'
holds 'and says the name is never a number counted from the entries, why, and that old names stay' "$R157_CONV" \
  '- The name is never a number counted from the entries that already exist. A worktree branch sees only the dev branch and itself, so two branches writing on the same day count to the same number, and an entry cannot be renamed once it exists (#157). Entries named under the earlier numbered convention keep their names: they are history. - If the agent does not know'
holds 'and says where the agent reads its session name' "$R157_CONV" \
  '- If the agent does not know its session name, or it is in doubt, it should call the `ListAgents` function to see its session name. - A dev-log entry should start'
lacks 'and it spells no numbered name, in any case of the stem session-' "$R157_LOW" 'session-'
lacks 'nor the counting rule that went with it' "$R157_LOW" 'counts sessions within that day'

req GH-157.2
holds 'the dev-log README says an entry that exists is appended to' "$R157_CONV" \
  'the current branch ended up. - If the dev-log file that the agent is trying to write already exists, the agent should append a new dev-log entry to the file with a date and time. - An append is made'
holds 'and how: with >>, never Edit or Write, a scratch file past a heredoc refusal, and where no guard holds it' "$R157_CONV" \
  "- An append is made with \`>>\` from Bash, and an entry that exists is never edited with the Edit or Write tool. \`append-only-docs.sh\` reads a heredoc's text as part of the command, so a heredoc append whose prose reads as a command that rewrites an entry can be refused (#176): a \`sed -i\` anywhere in the text, for example, or an \`rm\`, an \`mv\` or a \`>\` followed on its line by a path under this directory. Write the text to a scratch file with the Write tool first, and append it with \`cat <file> >> <entry>\`. \`append-only-docs-edit.sh\` does not yet refuse Edit or Write on an entry outside the session's project directory, in another checkout of this repository: a linked worktree's entry when the project directory is the main checkout, or the main checkout's when it is the worktree (#159). There this rule is held by the agent and not by a guard. - Written for technical readers"
lacks 'and it does not claim that Edit and Write are refused on an entry' "$R157_LOW" \
  'are refused on an entry that already exists'

# GH-157.3: the append bullet's examples, fed to the guards it names. The
# heredoc is built rather than written out, so every check appends to one entry.
r157_heredoc() {  # r157_heredoc <text> -- a heredoc append of <text> to a dev-log entry
  printf "cat >> docs/dev-log/devlog_2026-01-01_x.md <<'EOF'\n%s\nEOF" "$1"
}
req GH-157.3
check append-only-docs.sh BLOCK 'a heredoc append whose text carries a sed -i, and no path beside it (#176)' \
  "$(r157_heredoc 'the fix replaced a sed -i call')"
check append-only-docs.sh BLOCK 'a heredoc append whose text has an rm, a path after it on its line (#176)' \
  "$(r157_heredoc 'we ran rm docs/dev-log/a.md')"
check append-only-docs.sh BLOCK 'a heredoc append whose text has an mv, a path after it on its line (#176)' \
  "$(r157_heredoc 'we ran mv docs/dev-log/a.md b')"
check append-only-docs.sh BLOCK 'a heredoc append whose text has a >, a path after it on its line (#176)' \
  "$(r157_heredoc 'the hook refuses > under docs/dev-log/')"
check append-only-docs.sh ALLOW 'a heredoc append whose text only names a path under the directory' \
  "$(r157_heredoc 'the file docs/dev-log/README.md was read')"
check append-only-docs.sh ALLOW 'a heredoc append whose rm has its path on the next line' \
  "$(r157_heredoc 'we ran rm
on docs/dev-log/a.md')"
check append-only-docs.sh ALLOW 'cat <file> >> <entry>, the route the README gives' \
  'cat /tmp/entry.md >> docs/dev-log/devlog_2026-01-01_x.md'

# A repository with a linked worktree inside it, where agents' stand, and an
# existing entry in each. One commit, because `git worktree add` needs one.
R157_MAIN="$FIXTURES/r157-main"
R157_WT="$R157_MAIN/.claude/worktrees/r157"
git init -q -b feature-157 "$R157_MAIN"
git -C "$R157_MAIN" -c user.email=checks@example.invalid -c user.name=checks commit -q --allow-empty -m base
git -C "$R157_MAIN" worktree add -q -b r157 "$R157_WT"
need_worktree "$R157_WT" r157-linked
R157_E=docs/dev-log/devlog_2026-01-01_x.md
mkdir -p "$R157_MAIN/docs/dev-log" "$R157_WT/docs/dev-log"
: > "$R157_MAIN/$R157_E"
: > "$R157_WT/$R157_E"
r157_call() {  # r157_call <Edit|Write> <file> -- the tool call, as the harness hands it over
  jq -cn --arg t "$1" --arg f "$2" \
    'if $t == "Edit" then {tool_name:$t,tool_input:{file_path:$f,old_string:"a",new_string:"b"}}
     else {tool_name:$t,tool_input:{file_path:$f,content:"b"}} end'
}
# feed hands the guard CLAUDE_PROJECT_DIR as $REPO_ROOT, so each call below
# names the session's project directory by assigning it for that call alone.
for r157_tool in Edit Write; do
  REPO_ROOT="$R157_MAIN" feed "$PATH" append-only-docs-edit.sh ALLOW \
    "$r157_tool of the worktree's entry, the project directory the main checkout (#159: BLOCK is the right verdict)" \
    "$(r157_call "$r157_tool" "$R157_WT/$R157_E")"
  REPO_ROOT="$R157_WT" feed "$PATH" append-only-docs-edit.sh ALLOW \
    "$r157_tool of the main checkout's entry, the project directory the worktree (#159: BLOCK is the right verdict)" \
    "$(r157_call "$r157_tool" "$R157_MAIN/$R157_E")"
  REPO_ROOT="$R157_WT" feed "$PATH" append-only-docs-edit.sh BLOCK \
    "$r157_tool of the worktree's entry, the project directory the worktree" \
    "$(r157_call "$r157_tool" "$R157_WT/$R157_E")"
  REPO_ROOT="$R157_MAIN" feed "$PATH" append-only-docs-edit.sh BLOCK \
    "$r157_tool of the main checkout's entry, the project directory the main checkout" \
    "$(r157_call "$r157_tool" "$R157_MAIN/$R157_E")"
done

sourced_to_end

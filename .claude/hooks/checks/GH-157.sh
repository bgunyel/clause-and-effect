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
# blanks. So a rule rewrapped, or re-indented under its bullet, stays green,
# and each claim is asked as one whole sentence of that text. The input is
# Markdown and not comments, which that reader was written for; the one place
# the two differ is a line opening with `#`, whose `#` it takes off, so a
# rewrap that starts a line with `#159)` turns a pin red and never green.
# The path is spelled under $SUITE_DIR/.. so that the check on this suite's
# header, which derives the documents the suite reads from that spelling,
# holds the header to naming the README.
#
# WHAT IT DOES NOT SEE, named. The files on disk: the checks ask what the
# README says and never whether an entry's name has the shape it states,
# because the entries named under the numbered convention are history and a
# walk of the directory would be red on arrival. A sentence added beside a
# pinned one that says the opposite: that is the limit #145 owns, and each
# `lacks` below closes it for one phrase and no other -- the numbered name,
# its counting rule, and the claim that Edit and Write are refused in the
# words the first triage brief proposed. A claim that the Edit guard refuses,
# spelled any other way, is not seen. And whether the guards behave as the
# README says: the README says the Edit guard does not refuse in a linked
# worktree while #159 is open, and when #159 lands the sentence and its pin
# change together.

section "=== issue #157: a dev-log entry is named for its session, and appended to with >> ==="

requirement GH-157.1 <<'REQ'
- text: The Conventions section of `docs/dev-log/README.md` names an entry
  `devlog_YYYY-MM-DD_SESSION-NAME.md`, for the session name of the agent
  writing it, and says the agent reads that name from `ListAgents` when it
  does not know it. It says the name is never a number counted from the
  entries that already exist, and why, and that entries named under the
  earlier numbered convention keep their names. It does not carry the
  convention it replaced: neither `session-N` nor `counts sessions within
  that day`. Read with the lines joined, so a rewrap is not a change.
- from: #157
- kind: doc-claim
- status: active
- direction: static: it reads the README's text against literals
- note: What the README says, and never what the directory holds: an entry
  named under the numbered convention is history, and a check that walked
  the directory would be red on arrival. A sentence added beside the rule
  that contradicts it is not seen, which is the limit #145 owns.
REQ
requirement GH-157.2 <<'REQ'
- text: The Conventions section of `docs/dev-log/README.md` says that when
  the entry an agent would write already exists, it appends a new entry to
  it with a date and time; that the append is made with `>>` from Bash, and
  an entry that exists is never edited with the Edit or Write tool; that a
  heredoc append whose prose mentions a path under the directory can be
  refused, so the text is written to a scratch file and appended with
  `cat <file> >> <entry>`; and that `append-only-docs-edit.sh` does not yet
  refuse Edit or Write in a linked worktree (#159), so that in a worktree the
  rule is held by the agent and not by a guard. It does not carry the phrase
  `are refused on an entry that already exists`, the first triage brief's
  wording of a claim that is false in a worktree.
- from: #157
- kind: doc-claim
- status: active
- direction: static: it reads the README's text against literals
- note: An instruction and not a claim about the guard, because the claim is
  false in a linked worktree, which is where agents write entries. When #159
  lands the sentence can become a statement about the guard, and its pin
  changes with it. The `lacks` is one phrase: the same claim in other words
  is not seen, which is the limit #145 owns.
REQ
shape_pin 'GH-157.1:static GH-157.2:static'

r157_conventions() {  # r157_conventions <file> -- its Conventions section, as comment_reflow reads it
  awk '
    on && /^## / { exit }
    on { print }
    $0 == "## Conventions" { on = 1 }' "$1" | comment_reflow
}
# Driven first, against a literal: the section and nothing either side of it,
# and a bullet wrapped at a hyphen, re-indented and given trailing blanks reads
# as the same words.
R157_FIX="$FIXTURES/r157-readme.md"
printf '%s\n' '# Dev Log' 'before' '## Conventions' '' '- File name: `devlog_YYYY-MM-DD_SESSION-' \
  '     NAME.md`, where  ' '  it ends.' '## Entries' 'after' > "$R157_FIX"
req GH-157.1 GH-157.2
tok 'the Conventions section is read to the next heading, with a rewrap joined' \
    ' - File name: `devlog_YYYY-MM-DD_SESSION-NAME.md`, where it ends. ' \
    "$(r157_conventions "$R157_FIX")"

R157_README="$SUITE_DIR/../../docs/dev-log/README.md"
R157_CONV=$(r157_conventions "$R157_README")

req GH-157.1
holds 'the dev-log README names an entry for the session that writes it' "$R157_CONV" \
  '- File name: `devlog_YYYY-MM-DD_SESSION-NAME.md`, where `SESSION-NAME` is the session name of the agent writing the dev-log.'
holds 'and says where the agent reads that name' "$R157_CONV" \
  '- If the agent does not know its session name, or it is in doubt, it should call the `ListAgents` function to see its session name.'
holds 'and that the name is never a number counted from the entries that exist' "$R157_CONV" \
  '- The name is never a number counted from the entries that already exist.'
holds 'and why: two branches count to one number, and an entry cannot be renamed' "$R157_CONV" \
  'A worktree branch sees only the dev branch and itself, so two branches writing on the same day count to the same number, and an entry cannot be renamed once it exists (#157).'
holds 'and that entries named under the numbered convention keep their names' "$R157_CONV" \
  'Entries named under the earlier numbered convention keep their names: they are history.'
lacks 'and it does not carry the numbered name it replaced' "$R157_CONV" 'session-N'
lacks 'nor the counting rule that went with it' "$R157_CONV" 'counts sessions within that day'

req GH-157.2
holds 'the dev-log README says an entry that exists is appended to' "$R157_CONV" \
  '- If the dev-log file that the agent is trying to write already exists, the agent should append a new dev-log entry to the file with a date and time.'
holds 'and that the append is made with >> and never with Edit or Write' "$R157_CONV" \
  '- An append is made with `>>` from Bash, and an entry that exists is never edited with the Edit or Write tool.'
holds 'and how to append when a heredoc would be refused' "$R157_CONV" \
  "\`append-only-docs.sh\` reads a heredoc's text as part of the command, so a heredoc append whose prose mentions a path under this directory can be refused; write the text to a scratch file with the Write tool first, and append it with \`cat <file> >> <entry>\`."
holds 'and that the Edit guard does not yet hold it in a worktree' "$R157_CONV" \
  '`append-only-docs-edit.sh` does not yet refuse Edit or Write in a linked worktree, which is where agents write entries (#159), so in a worktree this rule is held by the agent and not by a guard.'
lacks 'and it does not claim that Edit and Write are refused on an entry' "$R157_CONV" \
  'are refused on an entry that already exists'

sourced_to_end

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
# blanks. So a rule rewrapped, or re-indented under its bullet, stays green.
# Each pinned bullet is asked whole, from its `- ` to the `- ` that opens the
# bullet after it, so a qualifier written anywhere inside it -- between two of
# its sentences, or after its last -- turns it red (review of #234, round 1:
# the first version pinned a sentence at a time, and text between two pinned
# sentences of one bullet stayed green). The input is Markdown and not
# comments, which that reader was written for; the one place the two differ is
# a line opening with `#`, whose `#` it takes off. Every issue number in the
# section is written in parentheses, so no rewrap starts a line with one; a
# bare number wrapped to a line's start would lose its `#` and turn a pin red,
# never green. The path is spelled under $SUITE_DIR/.. so that the check on
# this suite's header, which derives the documents the suite reads from that
# spelling, holds the header to naming the README.
#
# WHAT IT DOES NOT SEE, named. The files on disk: the checks ask what the
# README says and never whether an entry's name has the shape it states,
# because the entries named under the numbered convention are history and a
# walk of the directory would be red on arrival. The README's other sections,
# for the same reason: its Entries section links every numbered name. A new
# bullet beside a pinned one that says the opposite: that is the limit #145
# owns, and each `lacks` below closes part of it. The numbered name is asked
# as the stem every spelling of it carries, a lowercase `session-`, so
# `session-N`, `session-<n>` and `session-1` are all red (the first version
# asked for `session-N` alone, and review measured `session-<n>` passing); a
# numbered name that drops the stem, `devlog_<date>_3.md`, is not seen. The
# counting rule and the claim that Edit and Write are refused are each one
# phrase, the words they were written in, and the same claim in other words is
# not seen.
#
# WHAT THE GUARDS DO, MEASURED (GH-157.3). The append bullet says what the two
# append-only guards do, and a pin of that text is evidence about the text and
# not about the guards: its first version said a heredoc whose prose
# "mentions a path" can be refused, and fed on stdin such a heredoc is
# permitted (review of #234, round 1). So every example the bullet gives is
# also fed to its guard, with the verdict the bullet states. The sentences
# rest on two open issues, #176 for the heredoc and #159 for the Edit guard,
# and when either changes its guard's verdict a check here goes red beside the
# pin of the sentence that has to move with it. The Edit guard is fed a
# directory nested where a linked worktree stands and not a real worktree:
# the guard resolves no repository, it strips the project directory off the
# path, so the nesting is all it reads.

section "=== issue #157: a dev-log entry is named for its session, and appended to with >> ==="

requirement GH-157.1 <<'REQ'
- text: The Conventions section of `docs/dev-log/README.md` names an entry
  `devlog_YYYY-MM-DD_SESSION-NAME.md`, for the session name of the agent
  writing it, and says the agent reads that name from `ListAgents` when it
  does not know it. It says the name is never a number counted from the
  entries that already exist, and why, and that entries named under the
  earlier numbered convention keep their names. It does not carry the
  convention it replaced: nothing in it is spelled `session-` in lowercase,
  the stem every spelling of the numbered name carries, and it lacks the
  counting rule's phrase `counts sessions within that day`. Each bullet is
  read whole, with the lines joined, so a rewrap is not a change and a
  qualifier inside a bullet is.
- from: #157, and review of #234
- kind: doc-claim
- status: active
- direction: static: it reads the README's text against literals
- note: What the README says, and never what the directory holds: an entry
  named under the numbered convention is history, and a check that walked
  the directory would be red on arrival. A new bullet that contradicts the
  rule is not seen, which is the limit #145 owns, except where it spells the
  stem; a numbered name without the stem, and the counting rule in other
  words, are not seen.
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
  `cat <file> >> <entry>`;
  and that `append-only-docs-edit.sh` does not yet refuse Edit or Write on an
  entry in a linked worktree when the session's project directory is the
  main checkout (#159), so that there the rule is held by the agent and not
  by a guard. It does not carry the phrase `are refused on an entry that
  already exists`, the first triage brief's wording of a claim that is false
  in that case. Each bullet is read whole.
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
  `append-only-docs-edit.sh` permits an Edit of an existing entry in a
  directory nested where a linked worktree stands when the project directory
  is the one above it (#159), and refuses the same Edit when the project
  directory is the nested one.
- from: review of #234, round 1
- kind: doc-claim
- status: active
- note: Two of these verdicts are defects that the README routes around, and
  they are asserted at today's verdict so that the README's sentence and
  the guard cannot part silently: the heredoc refusals are #176's, and the
  permitted Edit is #159's, whose right verdict is BLOCK. When either issue
  lands, its checks here go red, and they are rewritten with the sentence.
  Not in the invariance families' scope: it is a `doc-claim`, about what a
  document says of the guards, and the examples are the document's own.
REQ
shape_pin 'GH-157.1:static GH-157.2:static GH-157.3'

r157_conventions() {  # r157_conventions <file> -- its Conventions section, as comment_reflow reads it
  awk '
    on && /^## / { exit }
    on { print }
    $0 == "## Conventions" { on = 1 }' "$1" | comment_reflow
}
# Driven first, against a literal: the section and nothing either side of it,
# a bullet wrapped at a hyphen, re-indented and given trailing blanks reads as
# the same words, and the bullet after it opens with the `- ` a pin ends on.
R157_FIX="$FIXTURES/r157-readme.md"
printf '%s\n' '# Dev Log' 'before' '## Conventions' '' '- File name: `devlog_YYYY-MM-DD_SESSION-' \
  '     NAME.md`, where  ' '  it ends.' '- Next.' '## Entries' 'after' > "$R157_FIX"
req GH-157.1 GH-157.2
tok 'the Conventions section is read to the next heading, with a rewrap joined' \
    ' - File name: `devlog_YYYY-MM-DD_SESSION-NAME.md`, where it ends. - Next. ' \
    "$(r157_conventions "$R157_FIX")"

R157_README="$SUITE_DIR/../../docs/dev-log/README.md"
R157_CONV=$(r157_conventions "$R157_README")

req GH-157.1
holds 'the dev-log README names an entry for the session that writes it' "$R157_CONV" \
  '- File name: `devlog_YYYY-MM-DD_SESSION-NAME.md`, where `SESSION-NAME` is the session name of the agent writing the dev-log. - '
holds 'and says the name is never a number counted from the entries, why, and that old names stay' "$R157_CONV" \
  '- The name is never a number counted from the entries that already exist. A worktree branch sees only the dev branch and itself, so two branches writing on the same day count to the same number, and an entry cannot be renamed once it exists (#157). Entries named under the earlier numbered convention keep their names: they are history. - '
holds 'and says where the agent reads its session name' "$R157_CONV" \
  '- If the agent does not know its session name, or it is in doubt, it should call the `ListAgents` function to see its session name. - '
lacks 'and it spells no numbered name, in any spelling carrying session-' "$R157_CONV" 'session-'
lacks 'nor the counting rule that went with it' "$R157_CONV" 'counts sessions within that day'

req GH-157.2
holds 'the dev-log README says an entry that exists is appended to' "$R157_CONV" \
  '- If the dev-log file that the agent is trying to write already exists, the agent should append a new dev-log entry to the file with a date and time. - '
holds 'and how: with >>, never Edit or Write, a scratch file past a heredoc refusal, and where no guard holds it' "$R157_CONV" \
  "- An append is made with \`>>\` from Bash, and an entry that exists is never edited with the Edit or Write tool. \`append-only-docs.sh\` reads a heredoc's text as part of the command, so a heredoc append whose prose reads as a command that rewrites an entry can be refused (#176): a \`sed -i\` anywhere in the text, for example, or an \`rm\`, an \`mv\` or a \`>\` followed on its line by a path under this directory. Write the text to a scratch file with the Write tool first, and append it with \`cat <file> >> <entry>\`. \`append-only-docs-edit.sh\` does not yet refuse Edit or Write on an entry in a linked worktree when the session's project directory is the main checkout (#159), so there this rule is held by the agent and not by a guard. - "
lacks 'and it does not claim that Edit and Write are refused on an entry' "$R157_CONV" \
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

# check_file hands the guard CLAUDE_PROJECT_DIR as $REPO_ROOT, so each call
# below names the project directory by assigning it for that call alone.
R157_MAIN="$FIXTURES/r157-main"
R157_WT="$R157_MAIN/.claude/worktrees/r157"
R157_ENTRY="$R157_WT/docs/dev-log/devlog_2026-01-01_x.md"
mkdir -p "${R157_ENTRY%/*}" && : > "$R157_ENTRY"
REPO_ROOT="$R157_MAIN" check_file append-only-docs-edit.sh ALLOW \
  'an Edit of an entry in a linked worktree, the project directory the main checkout (#159: BLOCK is the right verdict)' \
  "$R157_ENTRY"
REPO_ROOT="$R157_WT" check_file append-only-docs-edit.sh BLOCK \
  'the same Edit, the project directory the worktree' "$R157_ENTRY"

sourced_to_end

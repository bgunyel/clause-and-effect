#!/bin/bash
# THE ISSUE FILE OF #159: whether a path is append-only is read off the path's
# own segments, so append-only-docs-edit.sh refuses in a linked worktree as it
# does in the main checkout, and the two halves of the rule agree about which
# paths they guard.
#
# Why: the Edit half stripped CLAUDE_PROJECT_DIR off the path and anchored the
# rest at `^docs/`. CLAUDE_PROJECT_DIR is the main checkout, so an entry in a
# linked worktree -- where CLAUDE.md sends every agent to work -- came out as
# `.claude/worktrees/<name>/docs/dev-log/<entry>`, matched nothing, and an Edit
# of it was permitted. The suite was green throughout, because every check of
# that hook handed it a path under the one root it anchored to: #84's shape, one
# question asked of one spelling. GH-157.3's rows asserted the defect at its
# measured verdict, so the README could say so, and they are BLOCK now.
#
# THE ROUTE, and the trade it takes. The Edit half matches a `docs/<dir>/` pair
# bounded by a `/` on both sides anywhere in the normalised absolute path, which
# is where the Bash half already stood -- it reads path spellings out of a
# command and resolves them against no root. So an identically-named path in a
# repository that is not this one is refused too, and the rows below that assert
# it say in their label that it is the accepted trade and not a defect. Asking
# git which repository a path is in would have fixed the worktree and left the
# two halves disagreeing about every other checkout, which is acceptance
# criterion 4 of the issue left open.
#
# THE BASH HALF MOVED TOO, the other way. The issue's brief assumed its pattern
# already bounded the directory on the left, and it did not: `rm -rf
# notdocs/dev-log` was refused, measured, where the Edit half now permits the
# same path. It is bounded on the left now by the class it was already bounded
# by on the right, so `notdocs/` and `x.docs/` parents are other directories on
# both sides. That permits what the Bash half refused, which is the direction a
# boundary fix goes; it is pinned below with what it must not have eaten: the
# append `>>docs/...` written with no space, which the first draft of that
# boundary refused, and `cp -tdocs/dev-log`, an option with its value attached,
# which the second permitted until review of the branch found it.
#
# THE FIXTURE is a repository this file builds, with a linked worktree inside it
# where agents' stand, and a second repository beside it that is not this one:
# every expected verdict is about those three and none depends on where the
# suite is run (GH-94.3). Each checkout holds the same tree -- an entry, a README,
# the near-miss directories -- and none holds `new.md`, the entry a Write
# creates.
#
# DERIVED RATHER THAN LISTED. Which hooks are asked the checkout question is read
# off settings.json and the hooks' text: every hook registered where an edit
# tool reaches it, which is handed a path, and every registered hook whose code
# reads CLAUDE_PROJECT_DIR, which is how a hook resolves one against a root. The
# first version asked only for a matcher naming Edit or Write, and review of the
# branch named what that missed: `*`, an empty matcher and `MultiEdit`, and a
# `${#` read as a comment.
# Each is asked every case of its table from each checkout, with each checkout as
# the project directory; one with no table is red, so the next such hook gets a
# failing row and not silence. The table is a literal per hook, because the
# verdict is the claim and a derivation of it would be the hook asking itself.

section "=== issue #159: an append-only path is one by its own segments, in every checkout ==="

requirement GH-159.1 <<'REQ'
- text: `append-only-docs-edit.sh` decides whether a path is guarded from the
  path's own segments -- a `docs/` segment followed by `dev-log`,
  `lessons-learned` or `eval-reports` and a `/`, anywhere in the normalised
  absolute path -- and not from where the project directory is. So an Edit or
  a Write of an existing entry is refused in the main checkout and in a linked
  worktree of it, whichever of the two is the project directory, spelled
  absolutely, relatively, and through `.` and `..` segments; a Write of a new
  entry and an Edit of a directory's README stay permitted in both, and so do
  a `.bak` sibling, a sibling whose name only begins with a guarded one, a
  guarded name under a `notdocs/` parent, and `docs/design/` and
  `docs/research/`. The one heading correction ADR 0003 permits is permitted
  on a worktree's entry as on the main checkout's, whichever is the project
  directory. An identically-named existing entry in a repository that is not
  this one is refused too: the accepted trade, since a refusal is visible and
  one edit away and a permitted rewrite of history is neither.
- from: #159, and review of its branch
- kind: defect-permitting
- status: active
- variants: none: its subject is which checkout a path lives in and which is
  the project directory, which is a state of the tree rather than a spelling
- note: the trade is written in the hook's comment, in the commit that took
  it and in the label of every row asserting it, here and in GH-159.2.
  Symlinks are not resolved on either side, as before.
REQ
requirement GH-159.2 <<'REQ'
- text: The two halves of the append-only rule classify one path set alike:
  for each of `dev-log`, `lessons-learned` and `eval-reports`, an entry under
  `docs/<dir>/` is guarded and a `docs/<dir>.bak/` sibling, a
  `docs/<dir>book/` sibling and a `notdocs/<dir>/` parent are not, in the main
  checkout, a linked worktree and a repository that is not this one.
  `append-only-docs-edit.sh` is fed an Edit of each existing file, and
  `append-only-docs.sh` a `truncate`, an `rm`, a `sed -i` and a `>` written
  with and without a space, each of the absolute path and of its relative
  spelling, and both reach the one literal verdict the path has. The Bash half
  bounds the directory on the left by the class that bounds it on the right,
  or by an option's letters after that class, so `rm -rf notdocs/dev-log` is
  permitted, `cp -tdocs/dev-log x` stays refused, and an append written
  `>>docs/dev-log/<entry>` with no space stays permitted.
- from: #159, and review of its branch
- kind: defect-refusing
- status: active
- variants: none: its subject is which file paths the two halves guard, one
  set fed to both, and a path is not a command; the spellings of the command
  around a guarded path are GH-69.2's, whose seeds the families vary
- note: what must agree is the path set and not the verdict for every act --
  the Edit half tests the filesystem for existence and the Bash half the
  command for a verb, and the Bash half's narrower answer on a `..` inside
  shell text is its own comment's and not this entry's.
REQ
requirement GH-159.3 <<'REQ'
- text: Which hooks are asked the checkout question is derived: every hook
  `settings.json` registers on a tool event under a matcher that reaches
  `Edit`, `Write` or `MultiEdit` -- by name, by a pattern, or by `*`, an
  empty or an absent matcher -- and every registered hook whose code, with
  `#` comments stripped, reads `CLAUDE_PROJECT_DIR`. Each is asked its cases
  from the main checkout, a linked worktree and another repository, with each
  of the first two as the project directory, and a derived hook with no table
  of cases is a failing row. The derivation is driven against a fixture first.
- from: #159, and review of its branch
- kind: defect-permitting
- status: active
- direction: static: it reads settings.json and the hooks' text, and derives
  which hooks the checkout cases must reach
- note: a hook that resolves a path against a root it finds some other way --
  `$(pwd)` alone, or `git rev-parse --show-toplevel` -- and is not registered
  for an edit tool is not reached; reading its code for every such spelling
  is the text derivation #144 abandoned for a record.
REQ
shape_pin 'GH-159.1 GH-159.2 GH-159.3:static'
variants_pin 'GH-159.1:none GH-159.2:none'

# THE DERIVATION. settings.json's registrations, as <event> TAB <matcher> TAB
# <hook> lines, a missing or empty matcher written `*`, which is what the harness
# reads it as; then the hooks on a tool event whose matcher reaches an edit tool,
# and the hooks whose code reads the project directory. A matcher is a tool name
# or a pattern, so it is asked as an anchored pattern of each edit tool's name.
# Comments are stripped where a `#` opens the line or follows a blank, so that a
# hook which only names the variable in prose is not one while `${#...}` is code.
r159_registered() {  # r159_registered <settings.json> -- <event> TAB <matcher> TAB <hook basename>, a line each
  jq -r '.hooks | to_entries[] | .key as $e | .value[]?
         | (if (.matcher // "") == "" then "*" else .matcher end) as $m
         | .hooks[]? | "\($e)\t\($m)\t\(.command)"' "$1" 2>/dev/null \
    | sed 's|\t[^\t]*/\([^/\t]*\)$|\t\1|; s|"$||'
}
r159_reaches_edit() {  # r159_reaches_edit <matcher> -- 0 if it hands the hook an Edit, Write or MultiEdit
  local t
  [ "$1" = '*' ] && return 0
  for t in Edit Write MultiEdit; do
    [[ $t =~ ^($1)$ ]] && return 0
  done
  return 1
}
r159_rooted() {  # r159_rooted <settings.json> <hooks dir> -- the hooks the checkout question reaches, sorted
  local e m h
  while IFS=$'\t' read -r e m h; do
    case "$e" in *ToolUse*) r159_reaches_edit "$m" && { printf '%s\n' "$h"; continue; } ;; esac
    sed 's/\(^\|[[:space:]]\)#.*$//' "$2/$h" 2>/dev/null | grep -q 'CLAUDE_PROJECT_DIR' && printf '%s\n' "$h"
  done < <(r159_registered "$1") | LC_ALL=C sort -u
}

# Driven first, against a fixture. Reached: a hook under `Write|Edit`, one under
# `*`, one under no matcher, one under `MultiEdit`, a Bash hook whose code reads
# the root, and one that reads it after a `${#`. Not reached: a Bash hook naming
# it only in a comment, one not naming it, and a SessionStart hook with no
# matcher, which is handed no tool at all.
R159_DERIVE="$FIXTURES/r159-derive"
mkdir -p "$R159_DERIVE/hooks"
for r159_h in x-edit x-star x-bare x-multi x-plain x-session; do
  printf '%s\n' '#!/bin/bash' 'exit 0' > "$R159_DERIVE/hooks/$r159_h.sh"
done
printf '%s\n' '#!/bin/bash' 'ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"' > "$R159_DERIVE/hooks/x-root.sh"
printf '%s\n' '#!/bin/bash' 'n=${#CLAUDE_PROJECT_DIR}' > "$R159_DERIVE/hooks/x-length.sh"
printf '%s\n' '#!/bin/bash' '# reads CLAUDE_PROJECT_DIR only in prose' 'exit 0  # CLAUDE_PROJECT_DIR' \
  > "$R159_DERIVE/hooks/x-prose.sh"
r159_hook_json() {  # r159_hook_json <name> -- a registration of it, as settings.json writes one
  printf '{"type":"command","command":"\\"$CLAUDE_PROJECT_DIR\\"/.claude/hooks/%s.sh"}' "$1"
}
cat > "$R159_DERIVE/settings.json" <<JSON
{"hooks":{"PreToolUse":[
  {"matcher":"Bash","hooks":[$(r159_hook_json x-root),$(r159_hook_json x-length),$(r159_hook_json x-prose),$(r159_hook_json x-plain)]},
  {"matcher":"Write|Edit","hooks":[$(r159_hook_json x-edit)]},
  {"matcher":"*","hooks":[$(r159_hook_json x-star)]},
  {"hooks":[$(r159_hook_json x-bare)]},
  {"matcher":"MultiEdit","hooks":[$(r159_hook_json x-multi)]}],
 "SessionStart":[{"hooks":[$(r159_hook_json x-session)]}]}}
JSON
req GH-159.3
tok 'the checkout question reaches every hook an edit tool is handed to and every hook whose code reads the root, and none that names it only in prose' \
    "$(printf '%s\n' x-bare.sh x-edit.sh x-length.sh x-multi.sh x-root.sh x-star.sh)" \
    "$(r159_rooted "$R159_DERIVE/settings.json" "$R159_DERIVE/hooks")"

R159_HOOKS=$(r159_rooted "$SETTINGS" "$HOOKS")
[ -n "$R159_HOOKS" ] || {
  echo "no hook was derived from settings.json for the checkout question; the checks below prove nothing" >&2
  exit 1
}

# THE FIXTURE. The main checkout, a linked worktree inside it where agents'
# stand, and a repository that is not this one.
R159_MAIN="$FIXTURES/r159-main"
R159_WT="$R159_MAIN/.claude/worktrees/r159"
R159_OTHER="$FIXTURES/r159-other"
git init -q -b feature-159 "$R159_MAIN"
git -C "$R159_MAIN" -c user.email=checks@example.invalid -c user.name=checks commit -q --allow-empty -m base
git -C "$R159_MAIN" worktree add -q -b r159 "$R159_WT"
git init -q -b main "$R159_OTHER"
need_worktree "$R159_WT" r159-linked
R159_DIRS='dev-log lessons-learned eval-reports'
for r159_root in "$R159_MAIN" "$R159_WT" "$R159_OTHER"; do
  for r159_d in $R159_DIRS; do
    for r159_f in "docs/$r159_d/e.md" "docs/$r159_d/README.md" "docs/$r159_d.bak/e.md" \
                  "docs/${r159_d}book/e.md" "notdocs/$r159_d/e.md"; do
      mkdir -p "$r159_root/${r159_f%/*}"
      printf 'x\n' > "$r159_root/$r159_f"
    done
  done
  for r159_f in docs/design/e.md docs/research/e.md; do
    mkdir -p "$r159_root/${r159_f%/*}"
    printf 'x\n' > "$r159_root/$r159_f"
  done
done
# Every file a BLOCK or a near-miss ALLOW asks about is there, and the new entry
# is not: an ALLOW from a missing file says nothing about the path.
for r159_root in "$R159_MAIN" "$R159_WT" "$R159_OTHER"; do
  [ -f "$r159_root/notdocs/eval-reports/e.md" ] && [ -f "$r159_root/docs/dev-log/e.md" ] \
    && [ ! -e "$r159_root/docs/dev-log/new.md" ] || {
    echo "the #159 fixture under $r159_root is not the tree its checks name; they would prove nothing" >&2
    exit 1
  }
done

# The checkout a path is in, the directory it is under, and how it is reached
# relatively from each project directory -- literals, one per pair.
r159_dir() {  # r159_dir <main|worktree|other>
  case "$1" in main) printf '%s' "$R159_MAIN" ;; worktree) printf '%s' "$R159_WT" ;; other) printf '%s' "$R159_OTHER" ;; esac
}
r159_up() {  # r159_up <project main|worktree> <checkout main|worktree|other> -- the relative prefix
  case "$1:$2" in
    main:main|worktree:worktree) printf '' ;;
    main:worktree) printf '.claude/worktrees/r159/' ;;
    main:other) printf '../r159-other/' ;;
    worktree:main) printf '../../../' ;;
    worktree:other) printf '../../../../r159-other/' ;;
  esac
}
r159_call() {  # r159_call <Edit|Write> <file> -- the tool call, as the harness hands it over
  jq -cn --arg t "$1" --arg f "$2" \
    'if $t == "Edit" then {tool_name:$t,tool_input:{file_path:$f,old_string:"x",new_string:"y"}}
     else {tool_name:$t,tool_input:{file_path:$f,content:"y"}} end'
}
r159_bash() {  # r159_bash <command> -- a Bash tool call
  jq -cn --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}'
}

# THE CASES, a table per hook the derivation reaches: <tool> <path in a
# checkout> <verdict> <what it is>. The verdict is the one the path owes in every
# checkout; the rows below ask it from each.
r159_cases() {  # r159_cases <hook>
  local d
  case "$1" in
    append-only-docs-edit.sh)
      for d in $R159_DIRS; do
        printf '%s\n' \
          "Edit docs/$d/e.md BLOCK an existing entry" \
          "Write docs/$d/e.md BLOCK an existing entry" \
          "Write docs/$d/new.md ALLOW a new entry" \
          "Edit docs/$d/README.md ALLOW the directory's README" \
          "Edit docs/$d.bak/e.md ALLOW a .bak sibling" \
          "Edit docs/${d}book/e.md ALLOW a sibling whose name only begins with the directory's" \
          "Edit notdocs/$d/e.md ALLOW the directory's name under a notdocs/ parent"
      done
      printf '%s\n' "Edit docs/design/e.md ALLOW a design document" \
                    "Edit docs/research/e.md ALLOW a research document" ;;
  esac
}

req GH-159.3
for r159_hook in $R159_HOOKS; do
  if [ -n "$(r159_cases "$r159_hook")" ]; then
    pass static '%s is reached by the checkout question, and has a table of cases' "$r159_hook"
  else
    fail static '%s is registered for Edit or Write, or reads CLAUDE_PROJECT_DIR, and has no checkout cases in checks/GH-159.sh' "$r159_hook"
  fi
done

# THE ROWS: each case, from each project directory, of the file in each
# checkout, spelled absolutely and relatively; and where the file is in the
# project directory's own checkout, through a `.` and a `..` too. The rows for
# the other repository that BLOCK are the accepted trade, and say so.
req GH-159.1
for r159_hook in $R159_HOOKS; do
  while read -r r159_tool r159_rel r159_want r159_what; do
    for r159_proj in main worktree; do
      for r159_kind in main worktree other; do
        r159_abs="$(r159_dir "$r159_kind")/$r159_rel"
        r159_label="$r159_hook: $r159_tool of $r159_what, $r159_rel, in the $r159_kind checkout, the project directory the $r159_proj"
        [ "$r159_kind" = other ] && [ "$r159_want" = BLOCK ] \
          && r159_label="ACCEPTED TRADE, not a defect: $r159_label"
        REPO_ROOT="$(r159_dir "$r159_proj")" feed "$PATH" "$r159_hook" "$r159_want" "$r159_label, absolute" \
          "$(r159_call "$r159_tool" "$r159_abs")"
        REPO_ROOT="$(r159_dir "$r159_proj")" feed "$PATH" "$r159_hook" "$r159_want" "$r159_label, relative" \
          "$(r159_call "$r159_tool" "$(r159_up "$r159_proj" "$r159_kind")$r159_rel")"
        [ "$r159_kind" = "$r159_proj" ] || continue
        REPO_ROOT="$(r159_dir "$r159_proj")" feed "$PATH" "$r159_hook" "$r159_want" "$r159_label, through ./" \
          "$(r159_call "$r159_tool" "$(r159_dir "$r159_kind")/./$r159_rel")"
        REPO_ROOT="$(r159_dir "$r159_proj")" feed "$PATH" "$r159_hook" "$r159_want" "$r159_label, through docs/.." \
          "$(r159_call "$r159_tool" "$(r159_dir "$r159_kind")/docs/../$r159_rel")"
      done
    done
  done < <(r159_cases "$r159_hook")
done
# And the refusal names a path a reader can act on: relative to the project
# directory where the file is under it -- a worktree is, inside the main
# checkout, where agents' stand -- and whole where it is not.
r159_says() {  # r159_says <project dir> <fragment> <label> <payload>
  REPO_ROOT="$1" feed_says "$PATH" append-only-docs-edit.sh "$2" "$3" "$4"
}
r159_says "$R159_MAIN" '(docs/dev-log/e.md)' \
  'the refusal names an entry relative to the project directory it is under' \
  "$(r159_call Edit "$R159_MAIN/docs/dev-log/e.md")"
r159_says "$R159_MAIN" '(.claude/worktrees/r159/docs/dev-log/e.md)' \
  'and a worktree entry relative to the main checkout it stands inside' \
  "$(r159_call Edit "$R159_WT/docs/dev-log/e.md")"
r159_says "$R159_WT" "($R159_MAIN/docs/dev-log/e.md)" \
  'and the whole path of an entry outside the project directory' \
  "$(r159_call Edit "$R159_MAIN/docs/dev-log/e.md")"

# THE ONE CORRECTION ADR 0003 PERMITS, on a worktree's entry. `heading_correction`
# asked whether the path was under docs/dev-log/ relative to the project root, so
# once the guard fired in a worktree, the correction there was refused whenever
# the main checkout was the project directory; it reads the path's own segments
# now, as the guard does. No check reached that line until review of #159's
# branch asked. The body edit beside it is the control: the entry is guarded.
R159_HEAD=docs/dev-log/devlog_2026-01-01_session-5.md
printf '%s\n\nBody.\n' '# 2026-01-01 · session 2 — R' > "$R159_WT/$R159_HEAD"
r159_edit() {  # r159_edit <file> <old> <new> -- an Edit tool call
  jq -cn --arg p "$1" --arg o "$2" --arg n "$3" \
    '{tool_name:"Edit",tool_input:{file_path:$p,old_string:$o,new_string:$n}}'
}
for r159_proj in main worktree; do
  REPO_ROOT="$(r159_dir "$r159_proj")" feed "$PATH" append-only-docs-edit.sh ALLOW \
    "the heading correction on a worktree's entry, the project directory the $r159_proj" \
    "$(r159_edit "$R159_WT/$R159_HEAD" '# 2026-01-01 · session 2 — R' '# 2026-01-01 · session 5 — R')"
  REPO_ROOT="$(r159_dir "$r159_proj")" feed "$PATH" append-only-docs-edit.sh BLOCK \
    "and a body edit of the same entry, the project directory the $r159_proj" \
    "$(r159_edit "$R159_WT/$R159_HEAD" 'Body.' 'Other.')"
done

# THE TWO HALVES, HELD TO ONE PATH SET. <path in a checkout> <verdict> <what>:
# the three directory names and the three near-misses of each. The Edit half is
# handed an Edit of the file, which exists in every checkout; the Bash half a
# command of each rule's shape over it -- its verb list, its `sed -i`, and its
# redirect with and without a space. Both are asked of the absolute path in
# each checkout, and the Bash half of the relative spelling too, which reads the
# same whatever the checkout.
r159_paths() {
  local d
  for d in $R159_DIRS; do
    printf '%s\n' "docs/$d/e.md BLOCK a guarded entry" \
      "docs/$d.bak/e.md ALLOW a .bak sibling" \
      "docs/${d}book/e.md ALLOW a sibling whose name only begins with the directory's" \
      "notdocs/$d/e.md ALLOW the directory's name under a notdocs/ parent"
  done
}
r159_forms() {  # r159_forms <path> -- <rule> TAB <command>, one per Bash rule the path meets
  printf '%s\t%s\n' 'the verb list, truncate' "truncate -s 0 $1" 'the verb list, rm' "rm $1" \
    'the in-place rule' "sed -i s/a/b/ $1" 'the redirect, spaced' ": > $1" 'the redirect, unspaced' ":>$1"
}
req GH-159.2
while read -r r159_rel r159_want r159_what; do
  for r159_kind in main worktree other; do
    r159_abs="$(r159_dir "$r159_kind")/$r159_rel"
    r159_trade=
    [ "$r159_kind" = other ] && [ "$r159_want" = BLOCK ] && r159_trade='ACCEPTED TRADE, not a defect: '
    REPO_ROOT="$R159_MAIN" feed "$PATH" append-only-docs-edit.sh "$r159_want" \
      "${r159_trade}agreement, the Edit half: $r159_what, $r159_rel, in the $r159_kind checkout" \
      "$(r159_call Edit "$r159_abs")"
    while IFS=$'\t' read -r r159_rule r159_cmd; do
      REPO_ROOT="$R159_MAIN" feed "$PATH" append-only-docs.sh "$r159_want" \
        "${r159_trade}agreement, the Bash half, $r159_rule: $r159_what, $r159_rel, in the $r159_kind checkout" \
        "$(r159_bash "$r159_cmd")"
    done < <(r159_forms "$r159_abs")
  done
  while IFS=$'\t' read -r r159_rule r159_cmd; do
    REPO_ROOT="$R159_MAIN" feed "$PATH" append-only-docs.sh "$r159_want" \
      "agreement, the Bash half, $r159_rule: $r159_what, spelled relatively: $r159_cmd" \
      "$(r159_bash "$r159_cmd")"
  done < <(r159_forms "$r159_rel")
done < <(r159_paths)
# The directory itself, which has no trailing slash to bound it: a notdocs/
# parent is permitted and a guarded one under any parent is refused.
check append-only-docs.sh ALLOW 'rm -rf of a guarded name under a notdocs/ parent, which is another directory' \
  'rm -rf notdocs/dev-log'
check append-only-docs.sh BLOCK 'rm -rf of a guarded directory under any parent' \
  'rm -rf x/docs/dev-log'
# What the left boundary must not eat. Its first draft let the boundary be any
# character that ends a name, and `>` is one, so the second `>` of an append
# written with no space read as the boundary before `docs/`, and the append was
# refused. The documented append is permitted in both spellings; the
# truncation written with no space is refused.
check append-only-docs.sh ALLOW 'an append with no space before the path' \
  'echo x >>docs/dev-log/e.md'
check append-only-docs.sh ALLOW 'an append with a space before the path' \
  'echo x >> docs/dev-log/e.md'
check append-only-docs.sh BLOCK 'a truncation with no space before the path' \
  'echo x>docs/dev-log/e.md'
check append-only-docs.sh ALLOW 'a verb and a guarded path in two commands of one line are not one command' \
  'rm x.md; cat docs/dev-log/e.md'
# Where each rule's own boundary decides. The outer test opens every rule, so a
# near-miss alone never reaches one; a near-miss on a line that also names a
# guarded entry does, and there the rule's stretch has to hold the boundary
# itself. The redirect's is asked with the guarded entry in front of the `>`,
# because its stretch runs on across a `;` and would reach one written after
# (#259, filed from here).
check append-only-docs.sh ALLOW 'rm of a notdocs/ near-miss, beside a read of a guarded entry' \
  'rm notdocs/dev-log/e.md; cat docs/dev-log/e.md'
check append-only-docs.sh ALLOW 'a guarded entry copied by a redirect into a notdocs/ near-miss' \
  'cat docs/dev-log/e.md > notdocs/dev-log/e.md'
# An option's letters with the path as its value. The boundary's first version
# took the `t` of `-t` for a name that goes on into `docs`, and permitted what
# had been refused; found by review of #159's branch. A hyphen inside a name is
# not an option, and a directory named `-docs` is another directory.
check append-only-docs.sh BLOCK 'cp -t with the guarded directory attached as its value' \
  'cp -tdocs/dev-log x.md'
check append-only-docs.sh BLOCK 'mv -t with the guarded directory attached, after another argument' \
  'mv x.md -tdocs/lessons-learned'
check append-only-docs.sh ALLOW 'a guarded name after a hyphen inside a name is another directory' \
  'rm x-notdocs/dev-log/e.md'
check append-only-docs.sh ALLOW 'a directory named -docs is another directory' \
  'rm -rf ./-docs/dev-log'

sourced_to_end

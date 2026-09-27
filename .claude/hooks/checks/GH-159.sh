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
# boundary fix goes; it is pinned below with the append it must not have eaten,
# `>>docs/...` written with no space, which the first draft of that boundary did
# refuse.
#
# THE FIXTURE is a repository this file builds, with a linked worktree inside it
# where agents' stand, and a second repository beside it that is not this one:
# every expected verdict is about those three and none depends on where the
# suite is run (GH-94.3). Each checkout holds the same tree -- an entry, a README,
# the near-miss directories -- and none holds `new.md`, the entry a Write
# creates.
#
# DERIVED RATHER THAN LISTED. Which hooks are asked the checkout question is read
# off settings.json and the hooks' text: every hook registered under a matcher
# naming Edit or Write, which is handed a path, and every registered hook whose
# code reads CLAUDE_PROJECT_DIR, which is how a hook resolves one against a root.
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
  `docs/research/`. An identically-named existing entry in a repository that
  is not this one is refused too: the accepted trade, since a refusal is
  visible and one edit away and a permitted rewrite of history is neither.
- from: #159
- kind: defect-permitting
- status: active
- variants: none: its subject is which checkout a path lives in and which is
  the project directory, which is a state of the tree rather than a spelling
- note: the trade is written in the hook's comment, in the commit that took
  it and in the label of every row asserting it. Symlinks are not resolved on
  either side, as before.
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
  so `rm -rf notdocs/dev-log` is permitted, and an append written
  `>>docs/dev-log/<entry>` with no space stays permitted.
- from: #159
- kind: defect-refusing
- status: active
- variants: none: its subject is which file paths are guarded, one set fed to
  both halves, and not a spelling of the command around a path
- note: what must agree is the path set and not the verdict for every act --
  the Edit half tests the filesystem for existence and the Bash half the
  command for a verb, and the Bash half's narrower answer on a `..` inside
  shell text is its own comment's and not this entry's.
REQ
requirement GH-159.3 <<'REQ'
- text: Which hooks are asked the checkout question is derived: every hook
  `settings.json` registers under a matcher naming `Edit` or `Write`, and every
  registered hook whose code, comments stripped, reads `CLAUDE_PROJECT_DIR`.
  Each is asked its cases from the main checkout, a linked worktree and
  another repository, with each of the first two as the project directory, and
  a derived hook with no table of cases is a failing row. The derivation is
  driven against a fixture first.
- from: #159
- kind: defect-permitting
- status: active
- direction: static: it reads settings.json and the hooks' text, and derives
  which hooks the checkout cases must reach
REQ
shape_pin 'GH-159.1 GH-159.2 GH-159.3:static'
variants_pin 'GH-159.1:none GH-159.2:none'

# THE DERIVATION. settings.json's registrations, as <matcher> TAB <hook> lines;
# then the hooks named under a matcher naming Edit or Write, and the hooks whose
# code reads the project directory, read with every `#` comment stripped so that
# a hook which only mentions it in prose is not one.
r159_registered() {  # r159_registered <settings.json> -- <matcher> TAB <hook basename>, a line each
  jq -r '.hooks[][]? | (.matcher // "-") as $m | .hooks[]? | "\($m)\t\(.command)"' "$1" 2>/dev/null \
    | sed 's|\t.*/|\t|; s|"$||'
}
r159_rooted() {  # r159_rooted <settings.json> <hooks dir> -- the hooks the checkout question reaches, sorted
  local m h
  while IFS=$'\t' read -r m h; do
    case "|$m|" in *'|Edit|'*|*'|Write|'*) printf '%s\n' "$h"; continue ;; esac
    sed 's/[[:space:]]*#.*$//' "$2/$h" 2>/dev/null | grep -q 'CLAUDE_PROJECT_DIR' && printf '%s\n' "$h"
  done < <(r159_registered "$1") | LC_ALL=C sort -u
}

# Driven first, against a fixture: one hook under Edit|Write, one Bash hook whose
# code reads the root, one that names it only in a comment and one that does not
# name it at all. The two it must find are the first two.
R159_DERIVE="$FIXTURES/r159-derive"
mkdir -p "$R159_DERIVE/hooks"
printf '%s\n' '#!/bin/bash' 'exit 0' > "$R159_DERIVE/hooks/x-edit.sh"
printf '%s\n' '#!/bin/bash' 'ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"' > "$R159_DERIVE/hooks/x-root.sh"
printf '%s\n' '#!/bin/bash' '# reads CLAUDE_PROJECT_DIR only in prose' 'exit 0' > "$R159_DERIVE/hooks/x-prose.sh"
printf '%s\n' '#!/bin/bash' 'exit 0' > "$R159_DERIVE/hooks/x-plain.sh"
jq -n '{hooks:{PreToolUse:[
  {matcher:"Bash",hooks:[{type:"command",command:"\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/x-root.sh"},
                         {type:"command",command:"\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/x-prose.sh"},
                         {type:"command",command:"\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/x-plain.sh"}]},
  {matcher:"Write|Edit",hooks:[{type:"command",command:"\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/x-edit.sh"}]}]}}' \
  > "$R159_DERIVE/settings.json"
req GH-159.3
tok 'the checkout question reaches an Edit|Write hook and a hook whose code reads the root, and not one naming it in a comment' \
    "$(printf '%s\n' x-edit.sh x-root.sh)" "$(r159_rooted "$R159_DERIVE/settings.json" "$R159_DERIVE/hooks")"

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
    REPO_ROOT="$R159_MAIN" feed "$PATH" append-only-docs-edit.sh "$r159_want" \
      "agreement, the Edit half: $r159_what, $r159_rel, in the $r159_kind checkout" \
      "$(r159_call Edit "$r159_abs")"
    while IFS=$'\t' read -r r159_rule r159_cmd; do
      REPO_ROOT="$R159_MAIN" feed "$PATH" append-only-docs.sh "$r159_want" \
        "agreement, the Bash half, $r159_rule: $r159_what, $r159_rel, in the $r159_kind checkout" \
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

sourced_to_end

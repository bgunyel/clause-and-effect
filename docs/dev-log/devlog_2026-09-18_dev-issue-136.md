# 2026-09-18 15:45 +03 · dev-issue-136 — the dependency group is read as shell words, once, in the library

**Branch** `worktree-issue-136-group-spellings`. It was cut from `origin/dev-05`
at `33f7129` and is one commit ahead of it, proposed into `dev-05`. **The check
suite gave 4203 results, all passing.** No run of `dev-05` alone was taken in
this session, so no count is given for the base. The hooks #136 measured at `8b1cbaf` are byte-identical at `33f7129`.
Only `lib/command-scan.sh` had moved, through #128, so every "was" verdict below
is taken at `33f7129`.

## The fix: `cs_names_option`

Each uv-group hook asked "is `--group <name>` in front of the tool?" with its
own grep. The grep accepted one spelling only: whitespace between flag and
value, and neither word quoted. As the issue measured, `--group=test`,
`--group "test"` and `"--group" test` were refused, together with their
single-quoted and `migrations` equivalents, although uv runs every one of them
in the group.

The question now lives in `lib/command-scan.sh` as
`cs_names_option <option> <value>`, and both hooks call it. It splits the text
in front of the tool into shell words the way bash does, removes the quotes and
escapes, and asks whether one word equals `<option>=<value>` or one word equals
`<option>` with the next word equal to `<value>`. Because it compares for
equality, `--group=testing`, `--group test-extra` and `-g test` still name no
group.

The assistant kept `no-pr-decisions.sh`'s base reader separate. That reader also
handles `-Bmain` and `-dB main`, bundled short spellings that gh accepts and uv
does not, and moving it would be a change to a boundary hook that #136 is not.
The helper's comment says so, so "answered once" is claimed only for the two
hooks.

## Two permits the grep had that the issue did not name

The assistant found both while writing the helper. Both were measured ALLOW at
`33f7129` by feeding the hook on stdin, and both are BLOCK now:

- `uv run --with "--group test x" pytest tests/`. The grep read inside quotes.
  If the quote came straight after `test`, the same text was refused. That
  makes the verdict depend on the next character, which is the intermittency
  #69 was filed about.
- `uv run --group testpytest pytest tests/`. The hook cuts the command at the
  tool name, so the text in front ends `--group test`, and the grep took the end
  of its input for the end of the value. The helper counts only words that an
  unquoted blank has ended.

## What review found

Two review passes ran in parallel sub-agents, one for standards and one for the
spec.

- **Spec review:** every acceptance criterion was met, with nothing missing.
  It found one comment wrong. The comment said a word holding `$`, a glob or a
  brace "names nothing" as if a check tested for them. Equality does the
  refusing, and the comment now says so.
- **Standards review:** it found three things.
  - `uv run "$(: " --group test ")"pytest tests/` is permitted, yet bash runs
    pytest with no group. Quotes inside a command substitution do not pair with
    the quotes around it, and the helper paired them anyway. The assistant fixed
    the helper: any `$(` or backtick in the text refuses. The assistant then
    measured that this fix does not change the hook's verdict. `cs_split` cuts
    at the parens before the helper is reached, and the fragment naming pytest
    arrives as `"pytest tests/`, a quoted command word with no runner in front
    of it. That is #117's `word-dquoted` gap. The helper checks pin the fix, and
    check-hooks.sh records why no hook check is tagged #136 for this shape.
  - Both hooks said "Both functions this file calls" above a guard that now
    lists five. The sentence no longer states a count.
  - A later `--no-group test` still permits, and so does `UV_NO_GROUP`. This
    was already true before the fix and is outside #136. The assistant filed it
    as **#168**, with uv's help text as the only evidence that uv then drops
    the group. That has not been observed.

## Evidence

- **Red before the fix.** The checks were written first, with the hooks
  unchanged and no helper yet. That run showed 27 FAIL lines: 14 helper checks,
  10 hook checks that should ALLOW, and 3 that should BLOCK, the grep's permits
  above. It then stopped at the half-library fixture for a function that did
  not yet exist.
- **The gap rows.** With the fix in place and the five GH-136 departure rows
  still present, exactly those ten variant checks went red and nothing else went
  red, which is acceptance criterion 4. The rows were then deleted and
  `REQUIREMENT_SHAPE` moved GH-136 off `gap`. `--matrix` gives
  `GH-136 active covered (12 refusing, 14 permitting, 27 static)` before the
  review fixes.
- **Mutations.** `option-attached-spelling-not-read` and
  `option-unfinished-word-read` were run as a named selection: baseline plus
  two, both caught, and `.claude/hooks/` byte-identical afterwards.
  `option-substitution-read` was added after review and run on its own: caught,
  byte-identical after.
- **Cost.** At the 16 KB line cap, the helper takes under 10 ms.
- **`make test`.** 595 passed and 1 failed. The failure is
  `test_environment_sync`: the worktree's `.venv` lacks `alembic` and `mako`
  from the `migrations` group. That is an environment state unrelated to this
  change, and `uv sync --all-groups` repairs it.
- **mutate-hooks.sh header.** Its restated active-requirement count read 158
  when 160 were active. It now reads 161. #148 still owns removing those
  counts.

## Open

- #168: a group named and then disabled.
- #117: the quoted command word, which is what permits the substitution shape
  at hook level.

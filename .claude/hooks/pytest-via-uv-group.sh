#!/bin/bash
# CLAUDE.md: the test invocation is `make test`, which is
# `uv run --group test pytest tests/`. pytest lives in the `test` dependency
# group, so a bare `pytest` runs against whatever interpreter is on PATH.
#
# Deliberately narrow: bare `python -m src.scripts...` and
# `python -m src.eval.golden_qa` are the documented forms for the corpus and
# eval entry points and are not matched here.
#
# Issue #69: this hook and alembic-via-uv-group.sh were the two that read a
# command without knowing where one starts. The name was matched after a
# separator or any whitespace, so it matched as an ARGUMENT and as PROSE --
# `grep -rn pytest docs/`, `ls tests/ | grep pytest` and `git log --grep pytest`
# were all refused, and the allowlist beneath could not rescue them because
# prose does not carry `uv run --group test`. Worse than the refusal is that it
# was intermittent: the match needed a separator in front of the name, so
# `echo "pytest lives in the test group"` was permitted only because a quote
# happens not to be in the class, while the same sentence shape with a space
# there was refused. Same shape, opposite verdict, on a difference that has
# nothing to do with what the command would run.
#
# Saying where a command word is is cs_split's job, and this file asks it now
# rather than answering it again. That is the first rule below.
#
# The second rule is the one that took two goes, and what it has to do is not
# what the old allowlist did. Anchoring at ^ answers "is pytest the command
# word", and a runner answers that question with its own name: `uv run pytest`,
# `uvx pytest` and `poetry run pytest` each run pytest outside the group --
# the failure this hook exists for -- while putting `uv`, `uvx` or `poetry` at
# ^. The first version of this rule asked only about `uv run`, and review
# measured four silent permits against the file it replaced. So a runner is a
# runner however it is spelled, and the list is below. It IS a list, and a
# runner not on it is permitted; the check suite names each member so that the
# list is read rather than discovered.
#
# Review of #69 then found the list one family short -- `pipx run` alongside
# `uvx` and `uv tool run`, `micromamba run` alongside `conda run`, `pixi run`
# alongside `poetry run`. Each was the sibling of something already on it, so
# the list had stopped where the writing stopped rather than where the question
# does. Worth recording as the same finding twice: narrowing a substring match
# to a list costs whatever the list omits, and the omissions are found by
# someone asking, not by the rule.
#
# Two things it still omits, and on purpose. `xvfb-run pytest` and
# `watch pytest` reach pytest as well, but neither is a runner in this sense:
# they take no subcommand and simply run the words after them, which is what
# cs_split calls a wrapper word and already strips for `time`, `sudo` and the
# rest. Naming them here would answer "what is a wrapper word" in a third
# place, which is the habit lib/command-scan.sh exists to end, and would fix
# these two hooks while leaving the four boundary hooks just as blind. They
# belong in that list, which is issue #79. The check suite pins both as
# permitted so the gap is visible; when #79 adds them, those two checks flip to
# BLOCK and that is the intended outcome, not a regression.
#
# Two things that list is not. It is not the tool's own arguments: `--group
# test` has to be named BEFORE pytest, or `uv run pytest --group test` passes
# the option to pytest and reads as sanctioned. The prefix is cut at the name
# for that reason. And it is not every uv subcommand: `uv pip install pytest`
# and `uv add --group test pytest` install a package rather than running one,
# which is what naming pytest is for, and neither is a runner.
#
# The trade, taken knowingly. A quote is a word boundary here, so the name is
# found inside a quoted argument to a runner and `uv run echo "pytest lives in
# the test group"` is refused. The alternative was to treat quoted text as
# data, and that permits `uv run "pytest"`, which really does run pytest. This
# file refuses both spellings of the prose rather than permitting one real
# invocation -- the direction lib/command-scan.sh takes throughout, and the one
# that makes the pair AGREE. The intermittency above was the defect; which way
# the pair settles is the smaller question. `echo "pytest lives in the test
# group"` on its own is untouched: its command word is echo, and no rule here
# reaches it.
LIB="$(dirname "$0")/lib/command-scan.sh"
[ -r "$LIB" ] && . "$LIB"
# Both functions this file calls, not just the one that names the file's
# subject. Testing cs_split alone left cs_normalise unguarded, and a library
# missing only that one permitted a bare `pytest tests/` silently.
if ! command -v cs_split >/dev/null 2>&1 \
   || ! command -v cs_normalise >/dev/null 2>&1; then
  echo "Blocked: pytest-via-uv-group.sh could not load lib/command-scan.sh, so it cannot tell a pytest invocation from a mention of one. Refusing rather than permitting." >&2
  exit 2
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
CMDS=$(printf '%s\n' "$COMMAND" | cs_normalise | cs_split)

# pytest, or python -m pytest, standing where a command word goes.
if printf '%s\n' "$CMDS" \
   | grep -qE '^(pytest|python[0-9.]*[[:space:]]+-m[[:space:]]+pytest)([[:space:]]|$)'; then
  echo "Blocked: bare pytest invocation. CLAUDE.md runs tests through the 'test' dependency group. Use: make test, or uv run --group test pytest tests/<file>::<test>" >&2
  exit 2
fi

# A runner standing where a command word goes, naming pytest. `uv run` is the
# sanctioned one and is asked for the group; the rest cannot name a dependency
# group at all, so naming pytest is enough to refuse.
UV_RUN='^uv[[:space:]]+run([[:space:]]|$)'
OTHER_RUNNER='^(uvx|uv[[:space:]]+tool[[:space:]]+run|poetry[[:space:]]+run|pdm[[:space:]]+run|hatch[[:space:]]+run|pipenv[[:space:]]+run|rye[[:space:]]+run|conda[[:space:]]+run|micromamba[[:space:]]+run|pixi[[:space:]]+run|pipx[[:space:]]+run|nix[[:space:]]+run)([[:space:]]|$)'
# A quote ends the name as a space does. See the trade above.
NAME='(^|[^A-Za-z0-9_.-])pytest([^A-Za-z0-9_.-]|$)'

while IFS= read -r FRAGMENT; do
  echo "$FRAGMENT" | grep -qE "$NAME" || continue
  if echo "$FRAGMENT" | grep -qE "$OTHER_RUNNER"; then
    echo "Blocked: that runner reaches pytest outside the 'test' dependency group, which it cannot name. CLAUDE.md runs tests through that group. Use: make test, or uv run --group test pytest tests/<file>::<test>" >&2
    exit 2
  fi
  echo "$FRAGMENT" | grep -qE "$UV_RUN" || continue
  # Everything before the name. The group has to be an argument of uv, not of
  # pytest, and this is what tells the two apart.
  if ! printf '%s' "${FRAGMENT%%pytest*}" \
       | grep -qE -e '--group[[:space:]]+test([[:space:]]|$)'; then
    echo "Blocked: uv run reaches pytest without the 'test' dependency group named first. CLAUDE.md runs tests through that group. Use: make test, or uv run --group test pytest tests/<file>::<test>" >&2
    exit 2
  fi
done <<CS_FRAGMENTS
$CMDS
CS_FRAGMENTS

exit 0

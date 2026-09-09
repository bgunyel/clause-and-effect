# Clause and Effect

A question-answering system over regulatory text, built evaluation-first: an
architecture decision is measured before it is kept. A check asserts, a probe
asks, and the two must not borrow each other's name. This glossary is written
lazily — a term is added when a collision has actually been resolved in the
repository, not in advance of one.

## Language

**Active dev branch**:
The single `dev-NN` branch that work lands on today. A worktree branch is
proposed into it by pull request; it reaches `main` only through a pull request
Bertan merges. There is exactly one at a time, and advancing it on the remote is
a reserved act — `.claude/hooks/no-git-push.sh` refuses a push of `main` or of
any `dev-<digits>` branch from anywhere.
_Avoid_: development branch, current branch

**Check**:
An assertion whose expected verdict is written out in advance, so running it can
only agree or disagree with what was already claimed. Every assertion in
`.claude/hooks/check-hooks.sh` is a check.
_Avoid_: probe

**Probe**:
An empirical measurement whose answer is not known until it runs. Each
`scripts/probe_*.py` is a probe — one measurement, its output landing in
`docs/eval-reports/`.
_Avoid_: check

**Reserved act**:
An act that belongs to Bertan and not to an agent: advancing the active dev
branch on the remote, merging any pull request, rotating the dev branch, and
publishing a release. Reserved is not a synonym for refused. The hooks refuse
the ordinary spellings of some of these and they stop mistakes, not adversaries;
others nothing refuses at all — the local half of a rotation, `git branch -d`,
passes every hook and is reserved all the same. Where nothing enforces, an agent
reports what it found and stops.
_Avoid_: forbidden act, blocked act

**Worktree branch**:
The branch an agent works on, checked out in a linked worktree and proposed into
the active dev branch by pull request. It is the only branch an agent may push,
and only from that worktree.

The permission keys on **where the command runs**, deliberately not on what the
branch is called: `.claude/hooks/no-git-push.sh` compares `git rev-parse
--git-dir` with `--git-common-dir`, and its header carries the mechanism. A
naming rule was available and is wrong twice over. Worktrees are made two ways
here — `EnterWorktree`, which prefixes the branch `worktree-`, and `git worktree
add -b`, which does not — so a prefix rule would disagree between them; and a
branch in the main checkout can be given whatever name the rule looks for, which
would carry the exception to the one place it is meant not to reach. Do not
"fix" this into a rule about the name.
_Avoid_: feature branch, agent branch

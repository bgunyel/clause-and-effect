# The agent boundary is enforced by hooks, not by a server-side ruleset

An unattended agent working in this repository acts with Bertan's GitHub
credentials. A branch ruleset on `dev-*` therefore cannot separate the two: it
would refuse Bertan's own writes as readily as the agent's, and naming him a
bypass actor would hand the agent the bypass along with it. The one signal that
does separate them is local — whether the command is running in a linked
worktree — and only a check inside the session can read it. So the boundary is
carried by `PreToolUse` hooks, which run in the agent's session and nowhere
else.

`main` is the contrast, and it shows the principle rather than breaking it.
There the policy is identical for both actors, so nothing needs separating, and
the `main-branch-protection` ruleset carries it server-side — out of reach of
the thing it constrains, which is where enforcement belongs whenever it can go
there.

Two consequences follow from putting it in hooks, and both are accepted. The
hooks read the text of a command, so they stop mistakes rather than a caller who
means to evade them. And they see only the Bash tool inside a Claude Code
session, so Bertan's own terminal is subject to none of it — which is the
point, not an oversight.

This decision is about the mechanism and deliberately records no inventory of
which commands are permitted. That list lives in the hooks and in CLAUDE.md, and
it will grow; the reason it is a list held in hooks at all is what is recorded
here.

## Considered Options

**Give the agent its own actor** — a deploy key, or a GitHub App installation
token. The premise this ADR rests on is a configuration choice and not a law:
with a second identity, `dev-*` could be protected by a ruleset that names
Bertan as a bypass actor and leaves the agent outside it, and the boundary would
move server-side where the agent cannot edit it. That is the better shape, and
it is not scheduled. It is written down because it is the option a reader would
otherwise re-propose after concluding from the hooks that nothing else was
possible. Before anything is bet on it: this repository is user-owned rather
than organisation-owned, and its one existing ruleset has an empty bypass-actor
list, so the approach needs verifying rather than assuming.

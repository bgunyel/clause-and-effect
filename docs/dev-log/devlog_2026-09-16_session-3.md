# 2026-09-16 · session 3 — #107: the suite's mutation claims become re-runnable

**Branch** `worktree-issue-107-mutation-harness`, cut from `origin/dev-05` at
`acefb24` and proposed into `dev-05`. **Check suite 3612 → 3637 results, all
passing.** Every result line that existed before this session is identical
afterwards, compared sorted and line by line; the only lines that differ are the
twelve timing measurements, which differ every run, and the two that state
`requirements.md`'s own size (160 → 162 entries by ID, 104 → 106 of them off the
both-directions rule). `--matrix`: 13 gaps, unchanged.

Issue #107 is the fourth work ticket of #103. Its complaint is narrow and exact:
`check-hooks.sh`'s header claims a rule was "mutation-checked" in about two dozen
places, every one of those runs was done by hand against a harness that no longer
exists, and none of them can be re-run. CLAUDE.md says of this repository that
several suites "have been green for the wrong reasons", so a mutation claim
nobody can re-run is a claim to re-measure rather than evidence.

What landed is `.claude/hooks/mutate-hooks.sh`, a registry of ten mutations that
breaks one rule at a time in a copy of `.claude/hooks/` and asks this suite
whether the requirements that rule belongs to go red — plus the change to
`check-hooks.sh` that lets it judge a directory other than its own.

## Two directories, where there was one

`check-hooks.sh` began with `HOOKS=$(pwd)` after a `cd` to its own directory, and
every path in the file hung off that: the hooks it runs, the text it reads, and
also `settings.json`, `CLAUDE.md`, `CONTEXT.md`, the two skills and the file
itself. A harness that copies the hooks somewhere and points the suite at the
copy would have pointed all of that at the copy, so most of the document audits
would have failed for want of files that are not in `.claude/hooks/` at all.

The assistant split the variable rather than the file. `$HOOKS` is now what is
**judged** — the hooks run as processes, the library they source, the text of
both, and `requirements.md` — and `$SUITE_DIR` is what they are judged
**against**, which stays this repository's whatever `$CHECK_HOOKS_DIR` says.
Three things sit on the suite side that read at first as though they belong on
the other, and each is written down where the split is made:

- **this file.** Under an override, `$HOOKS/check-hooks.sh` is a copy that is not
  the program running, so the self-audits — the header naming every file it
  checks, `pass` and `fail` being the only printers — would be evidence about
  text nobody executed. The harness refuses outright to register a mutation
  whose target is `check-hooks.sh`, for that reason and in those words.
- **the working directory a hook is run in.** Half the verdicts here are read off
  `git branch --show-current` and the branch state around it, and a copy in
  `/tmp` is not a git repository. So `check` and `inv_dir hooks` run in
  `$SUITE_DIR` and invoke the hook out of `$HOOKS`.
- **`$REPO_ROOT` and every document derived from it.**

Two smaller consequences. Every helper that runs a hook now resolves it the same
way, through `hook_path`, where `check` and `check_file` alone used to run
`./<script>` out of the working directory; the #98 self-test hands each of them
an absolute fixture path now. And the `READ_DOCS` derivation, which reads this
suite's own text to learn which documents it audits, had to learn both spellings
— documents outside `.claude/hooks/` under `$SUITE_DIR`, `requirements.md` and
`runbook.md` beside the hooks under `$HOOKS`.

An override that names no directory, or one missing a file that sits beside the
suite, stops the run and says which. That second guard is not decoration: a copy
short of one file turns most of this suite red for that reason, and a harness
reading the result would count every mutation as caught while establishing
nothing whatever. It is the harness's own permitting direction.

## The harness

A registered mutation is one row of a table, five fields separated by `%`: an id,
a file relative to the hooks directory, a `sed` expression, the requirement IDs
whose checks must go red, and the outcome the harness must then report. A
mutation is **caught** only when *every* ID it names has at least one failing
check in that run's matrix — a run that goes red somewhere else entirely is the
suite noticing something, which is not what the row claims.

Three decisions worth recording, because each was a choice and not the only one
available:

**A mutation that does not apply is a failure**, reported as loudly as a
survivor. If the `sed` leaves the file byte-identical the run after it is a green
run of unmutated hooks, which reads exactly like evidence and is none. This is
#84's lesson one level out, and it is not hypothetical: the #106 section records
two of its own mutations failing to apply on the first attempt, each run green for
that reason rather than the one it claimed.

**The expected outcome is a field, not a mode.** #107 asks for two self-tests —
one mutation whose edit matches nothing, reported as did-not-apply, and one
registered against a requirement its edit cannot reach, reported as survived — and
also that the harness exit non-zero on any survivor. Those two requirements are in
tension unless the row says which outcome it expects, so the self-tests are rows
of the same registry run by exactly the code the real mutations are. The second is
the `nohup` mutation, which the harness catches under its own row, registered
against GH-100, the session report's classification of branches: it survives while
24 other requirements go red, which is what says `caught` is read off the IDs named
rather than off the run being red.

**A fresh copy per mutation, never a revert.** `git checkout --` in a throwaway
harness eats whatever else is uncommitted — the lesson is already in this
repository — and a hand-written revert is one more thing that can silently not
apply. The repository's own `.claude/hooks/` is checksummed before and after the
whole run, and the refusal to work in it is asked before the first delete rather
than after, since that is the one question whose wrong answer would destroy the
files it is asked about.

## The baseline fired on the first real run

The first full run never reached a mutation. The baseline — an unmutated copy,
which has to be green before anything else is believed — came back red at GH-63,
GH-84.2 and GH-102, and the cause was `mutate-hooks.sh` itself.

Two derivations in the suite ask which files load the tokeniser by looking for
`command-scan.sh` in the file's text with comments stripped, deliberately loosely,
because keying on one spelling means a hook that sources it differently drops out
of the audit in silence. `mutate-hooks.sh` names `lib/command-scan.sh` in three
registry rows, in code rather than in a comment, so it read as a consumer that
guards nothing, and separately the suite's header did not yet name it. The suite
already carried the exception this needed — `check-hooks.sh` reads that path too
and is excluded by name — so the exclusion became a named list of two, and the
header paragraph gained a sentence.

Nothing was wrong with the suite and nothing was wrong with the harness. What is
worth the paragraph is that the guard which found it is the one the harness has
for itself: without the baseline, that same red run would have been read as ten
mutations caught.

## What the registry covers, and what it reports

**Eight real mutations against six rules, naming ten requirement IDs between
them.** Three re-introduce the historical tokeniser defects the #106 section
describes in prose and could not re-run (`sudo` and `nohup` dropped from the
wrapper words, the shell control words no longer stripped). Two narrow the
`gh issue` allowance #105's own section pins, one in the coarse way an edit would
plausibly go wrong and one in the narrow way. Two empty a refusal message of the
permitted spelling it names. One deletes the stopping rule from a boundary hook.

That is one mutation per rule and **not** one per requirement, and the first
version of this entry said otherwise — see the review section below. #105 and
#106 gained checks for some twenty-five requirements; nineteen of them have no
row here, and the per-FR sweep stays the `docs/todo.md` item #103 Q8 deferred.

Two kinds of rule the harness cannot reach at all, which is the `$CHECK_HOOKS_DIR`
split seen from the other side and is now written into the harness's header: a
rule that lives in `check-hooks.sh` itself — #106's six self-guards and #104's
coverage machinery are all of that kind — because the suite that runs is this
repository's and an edit to a copy would be read and never executed; and a claim
about a file outside `.claude/hooks/`, because only the hooks directory is copied
and a mutation to CLAUDE.md or `settings.json` would be a mutation to the working
tree. Neither wants another row; both want a different answer.

All eight were caught, both self-tests reported what they declare, and
`.claude/hooks/` was byte-identical afterwards. Ten runs of the suite — one per
mutation that applies, plus the baseline; the row whose edit matches nothing never
reaches one — measured twice at 16 min 30 s and 15 min 6 s. The breadth is hard to
see without running it: dropping `nohup` from one alternation turns 24
requirements red, where the #106 section records it as covered by four checks in
the whole of the rest of the suite before the invariance families existed.

Per-mutation counts are deliberately **not** recorded in the harness. A count in a
comment is the thing #107 was filed about; the registry is re-runnable instead,
and that is the whole of the change.

## Review of the assistant's own change, on two axes

The change was reviewed before it was committed, against this repository's
documented standards and against #107's acceptance criteria, by two agents
reading independently. Six findings, all six answered in the same commit. None of
them was a wrong result — the suite was green and every mutation had behaved —
and five of the six are in the permitting direction.

**A check green for the wrong reason, in the change whose subject is exactly
that.** The assistant pinned the two new assignments with

```
armed 'the hooks under check default to the ones beside this suite' \
      "$SUITE_DIR/check-hooks.sh" 'HOOKS=$SUITE_DIR'
```

`armed` strips comments and greps the file, and the needle is spelled whole on
the check's own line — so deleting the assignment it names leaves the check
green. The suite already carries the idiom for this a few hundred lines up, where
a citation pin writes its literal in two quoted halves that bash joins, with the
comment saying why; the assistant had read that line this session and did not
apply it. Both pins are split now, and the measurement is written beside them:
`sed 's/#.*//' check-hooks.sh | grep -c` answers 1 for each needle where it
answered 2. Neither can be mutation-checked by the harness, since the harness
refuses to mutate `check-hooks.sh`, so they are held by the split and by review —
which is the limit the harness's own header states for every rule living in that
file.

**A count off by one, and a cost figure resting on it.** The header said "eleven
runs", counting one run for every row; the row whose edit matches nothing never
reaches a run, so it is ten. The seventeen-minute figure derived from the wrong
count, and had been copied into CLAUDE.md, `requirements.md` (as twenty), the
todo item and this entry. It is sixteen minutes, measured, and the four documents
now say the same thing.

**A scope sentence that claimed two issues.** "The registry covers the rules that
gained checks under #103 — #105's and #106's" reads as coverage of both issues,
where eight rows name ten requirement IDs out of some twenty-five. The harness
header, `requirements.md`, the todo item and the section above now count instead
of characterising, and name the two kinds of rule that cannot be registered at
all.

**Three holes in the harness's own guards**, each in the permitting direction and
each one line to close. `tree_sum` hashed file contents only, so a mode change or
a file replaced by a symlink to it read as byte-identical, and an empty listing —
a `find` that yielded nothing — compared equal on both sides, which is this check
passing for the reason it exists to catch. The `-ef` guard answered "is the
working copy the hooks directory" and not "is either inside the other", so a
`$TMPDIR` under `.claude/hooks/` would have had `cp -a` copy the hooks into
themselves. And a registry row's file was joined to the copy's path unchecked, so
a row spelling `../` or an absolute path would have edited whatever it named, with
the checksum reporting it afterwards rather than instead. All three are refused
now before the write, and the suite pins each refusal.

One finding was recorded rather than fixed: #107's criterion says the harness
exits non-zero "on any survivor or non-applying mutation", and a clean run reports
one of each — the self-tests — and exits 0. The two criteria cannot both hold
literally, which is why the expected outcome is a field; the trade is argued in
the harness header where a reader meets it.

## What this is not evidence of

The registry is a list someone wrote, so it is evidence about the mutations it
names and about nothing else — the sentence this suite's header already makes
about its checks, no weaker here. `caught` says some check tagged with that
requirement went red; it does not say the *right* check went red, and nothing in
the harness can say that. One mutation per functional requirement remains the
backlog item `docs/todo.md` carries from #103 Q8, and #108 and #109 register
theirs when they land.

The suite gains 23 checks of its own for all this (GH-107.1 and GH-107.2), and two
more arrive without being written: the #102 header audit, which holds the header
to every `.sh` beside it in both directions, picked `mutate-hooks.sh` up by
itself.

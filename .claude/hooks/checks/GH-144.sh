#!/bin/bash
# THE ISSUE FILE OF #144: a pull request's base is the active dev branch, and
# the lookup that answers which one that is can only narrow what is accepted.
#
# no-pr-decisions.sh judged a base by pattern, every `dev-NN` accepted whatever
# refs origin held, while no-work-on-stale-branch.sh derived the active dev
# branch from those refs -- two definitions of one term that disagree exactly
# during a rotation. #144 gave the pull request hook the same derivation, asked
# only of a base that has already passed the shape question.
#
# WHAT IS HERE, and what is not. The checks #144's work wrote: the rule in all
# four spellings, the refusal's two sentences, the degraded read, the count of
# reads, the cross-repository corner, the suite's own rule about where a dev-NN
# base may be judged (GH-144.4's text derivations), and what the session report
# says about the base rule when it could not read or trust the refs (GH-144.8).
# Its GH-144.4 check that reads the RUN rather than the text is in the
# end-of-run file, because it reads the record every issue file's rows wrote,
# and an issue file listed after this one would be invisible to it here.
#
# What #144 changed in checks it did not write stays where those checks are, in
# the unsplit file: the rows it moved from `check` to `check_in "$ON_DEV"`, the
# #106 seeds it moved to `on-dev`, the two payloads it added to GH-108.6's loop,
# #108's gap row it turned from ALLOW to BLOCK and retagged GH-144.1, and the
# third copy it added to #62's comparison of the dev-branch derivations. Each is
# an edit to an existing check, and a check lives in the file of the issue whose
# work wrote it.
#
# THE FIXTURES are #108's -- $ENV_DEV_TWO, $ENV_DEV_NONE, $ENV_NOREPO,
# $ENV_NO_GIT_BIN, the report copies -- read here after the unsplit file has
# built them, and three of #144's own, built below. This file is listed after
# the unsplit file for that reason.
#
# This file was written when PR #158 merged dev-05 across the split (#204) and
# the generated entries (#205): its checks stood in check-hooks.sh and its
# entries in requirements.md until then, and the move changed which text the
# GH-144.4 derivations read -- every file of the suite, $SUITE_TEXT, and no
# longer check-hooks.sh alone, where after the split they would have found no
# row to read.

section "=== issue #144: the base is the active dev branch, and the lookup only narrows ==="

requirement GH-144.1 <<'REQ'
- text: `no-pr-decisions.sh` asks two questions of a base: the shape, off the text
  of the command, and then -- of a base that is already `dev-NN` -- whether it is
  the branch `origin` holds highest. A base that is not the active dev branch is
  refused in all four spellings, whether it is a dev branch already rotated past
  or one origin does not have yet, and the active dev branch is derived as the
  highest `refs/remotes/origin/dev-[0-9]+` by `sort -V`, so `origin/dev-foo` and
  `origin/dev-05-backup` are not dev branches and `dev-10` is higher than
  `dev-09`.
- from: #144
- kind: defect-permitting
- status: active
- variants: none: the shape half of it is the spelling of a base and is varied by
  the seeds above, but what this entry adds is the comparison against the refs
  `origin` holds, and no fixture a seed may name holds a dev ref -- which the
  GH-144.4 checks pin rather than leave to be noticed. A variant rewrites a
  command's text, and every rewriting of `--base dev-04` still names dev-04; what
  decides it is the ref state beside it
- note: the gap GH-108.5 pinned at its measured verdict. The base rule was a
  pattern, so every `dev-NN` string was accepted whatever refs origin held, while
  `no-work-on-stale-branch.sh` in the same repository derived the active dev
  branch from those refs and refused a commit measured against it -- two
  definitions of one term, disagreeing exactly during a rotation, which is when
  both refs exist and when a worktree pull request would land on the branch on
  its way out. The two lines that derive the branch now stand in three files and
  the suite holds all three equal, which is the same arrangement, and the same
  argument, that already held the other two.
REQ
requirement GH-144.2 <<'REQ'
- text: The lookup only narrows. When the read for the active dev branch comes
  back empty -- no `origin/dev-NN` ref, `git` off PATH, a directory that is no
  repository -- the shape question is the whole base rule, so every `dev-NN`
  base is accepted as it was before GH-144.1 and every refusal made on the text
  of the line is still made: a base of main, a base that is not `dev-NN`, and a
  create or REST write naming no base at all.
- from: #144
- kind: defect-refusing
- status: active
- variants: seed
- note: this is what made the lookup admissible at all, and #108 is the reason it
  has to be written down as a requirement rather than as a comment. That issue
  declined to close the gap because a hook whose verdict depends on an
  environment read fails open when the read fails, and an abstaining pull-request
  hook is one that permits `--base main` whenever refs cannot be read. The
  narrowing is asked only of a base that has already passed the shape question,
  so the set this hook accepts is a subset of `dev-NN` under every ref state
  there is: a failed read costs the narrowing and no refusal. The sharpest check
  is the `git`-off-PATH one, which runs in the fixture holding both refs, so the
  same command refused under GH-144.1 is permitted there and the only difference
  is whether the read could be made.
REQ
requirement GH-144.3 <<'REQ'
- text: A refusal for the branch question names the branch it expected -- "dev-05
  ... is not dev-06, the active dev branch here" -- in all four spellings, and the
  name is read from the refs rather than written into the message. A base that
  fails the shape question is not told which branch was expected, and a `dev-NN`
  base is never told it is not a `dev-NN` branch.
- from: #144
- kind: defect-permitting
- status: active
- direction: refuse-only: every claim here is about the wording of a refusal, and
  a permit has no message to read
- variants: none: its subject is the words of a refusal, which no rewriting of the
  refused command's spelling reaches -- GH-133's reason, one issue on
- note: #133's complaint about a sibling message, answered for the rule this issue
  adds rather than for that one. One constant carries both answers, which is what
  FR-23 asks for and also what makes the wrong answer one edit away, so the two
  `says_not` rows are the load-bearing half: a dev branch told it is "not a dev-NN
  branch" is a refusal an agent cannot act on, and main told which dev branch was
  expected reads as an invitation to retarget a pull request that should not
  exist. Message content is #109's; what is claimed here is that the branch is
  named at all and that the two answers do not cross.
  WHAT IS DEFERRED, so that it reads as a decision and not an oversight: the
  refusal's first half still says "Write: gh pr create --base dev-NN" although the
  hook now knows the name, which is the same complaint one sentence earlier in the
  same message. Two reasons it is not changed here. FR-23's claim is that ONE
  constant serves all four refusals and five checks pin its text, so rewording it
  is that requirement's business rather than this one's; and the constant is
  assigned before any command is judged, so interpolating the branch would make
  the read happen for every refusal including the one where no base is named,
  which GH-144.5 says it does not. The branch is named in the clause that follows,
  so the correction is in the message either way, and #109 owns which sentence it
  belongs in.
REQ
requirement GH-144.4 <<'REQ'
- text: Every check in the suite whose payload names a `dev-NN` base names
  the directory it is judged in -- `$ON_DEV` for the shape question, a ref fixture
  for the branch question -- and no run of `no-pr-decisions.sh` whose stdin names
  `dev-` and a digit is made in a directory that reads this repository's refs:
  the checkout, any subdirectory of it, or a worktree sharing its refs. That is
  read off a record the hook's own process writes, whatever route started it.
- from: #144
- kind: doc-claim
- status: active
- direction: static: it reads which directory this suite's own rows were judged
  in, and no verdict at all
- note: a rule about the checks rather than about the hook, and the one thing
  GH-144.1 costs this suite. `check` runs the hook where the suite's driver
  stands, which is inside this repository, so a `dev-05` payload read there is evidence only
  until the next rotation makes `dev-06` the active branch -- it would then go red
  blaming a hook that was right, which is the failure this entry exists to stop.
  Rows moved to `$ON_DEV` when GH-144.1 landed, and the dev-05 merge moved more.
  HOW MANY IS NOT CLAIMED, because what has to hold is that no bare row exists
  and not how many scoped ones do, and the derivation is what holds it. The
  sentence that stood here claimed one in the same breath as denying it --
  thirty-five, which was also pre-merge. The third review of PR #158 counted the
  head and got a figure matching neither that number nor the one it derived from
  the diff, and that disagreement is the argument for carrying no number here
  rather than a corrected one.
  HOW THIS IS ESTABLISHED CHANGED IN THE FIFTH REVIEW OF PR #158, and the change
  is the point of this paragraph. It was three derivations over the suite's text,
  strengthened twice and got past twice: the fourth review found a row spelled
  `check_in "$SUITE_DIR"` that satisfied a rule reading the harness word and not
  the directory, and the fifth found three more shapes -- a payload in a `for`
  list, a payload behind a continuation, a loop variable read after its loop --
  and reached the fourth review's own defect through the first of them. Each fix
  was an instance patch. The class is a guard narrower than the prose beside it,
  and a rule about shell source enforced by grepping shell source has another
  spelling every time: #128, #137, #139 and #155 are the same wall lower down.
  There is a second class in it, quieter: a derivation that matches nothing
  returns nothing, and nothing holds no offender, so a row no pattern reaches
  reads exactly like a row that passed.
  So the claim is read off the RUN instead, and none of the five shapes survives
  that: a variable arrives expanded, a loop once per iteration, a continuation
  joined. The first record was written by the helpers, each calling `judged`,
  with a derivation holding the helpers that call `hook_path` equal to the ones
  that call `judged`; it found two helpers that recorded nothing on its first
  run, and it was the same rule over shell source one level up. Round 1 of the
  review after the merge across the split measured it past three ways -- a hook
  run outside any function, a helper whose name held a digit, and an opener
  broken in both lists, which left two empty lists equal -- and found its reader
  refusing only the string `$SUITE_DIR`, and losing a base a newline had put on
  a line of its own. So the record is written by the hook's process, through
  BASH_ENV, with the directory it is really in and its stdin on one line; the
  reader resolves each directory to its git common directory and compares it
  with this repository's; a fixture record holds the reader to naming the
  repository's root and a subdirectory of it; and runs by four routes that use
  no helper -- direct, through `bash`, through a symbolic link, and with a
  newline before the base -- are asked to appear in the record as they ran.
  THE THREE TEXT DERIVATIONS ARE KEPT AS THE CHEAP ONES, with the three shapes
  they still miss written beside them rather than patched, and `feed`/`feed_says`
  removed from the directory alternation -- their first argument is a PATH, so a
  row through either would have been a false red.
  AND THE REAL CHECK IS NEITHER, which this entry says so that a later reader
  does not over-trust the derivations. Both read something ABOUT the suite. The
  five-state rotation experiment runs the suite under `dev-05` alone, `dev-05`
  beside `dev-06`, `dev-06` alone, no dev ref, and `dev-09` beside `dev-10`, and
  a row that has rotted turns red there whatever its spelling and whether or not
  any derivation can see it. It is in PR #158 and in the session 6 dev-log. It is
  not a check in the suite because it needs ref states its fixtures do
  not have, so it is run by hand at the end of work that touches the base rule --
  which is a cost, and is the reason the cheap ones are kept.
REQ
requirement GH-144.5 <<'REQ'
- text: `no-pr-decisions.sh` reads `refs/remotes/origin/dev-*` once per run, however
  many bases the line names, and not at all where no base is named.
- from: #144
- kind: defect-refusing
- status: active
- variants: none: its subject is how many times the hook reads refs, which is a
  count taken off a git shim and not a verdict a variant could carry
- note: the claim GH-144.1 costs, and it was false when it was first written. Every
  caller said `DEV=$(read_active_dev)`; a command substitution is a subshell, so
  the variable recording the read was set in a process that then exited and the
  memo was a no-op -- one `git for-each-ref` per base tested, while the comment
  beside it said once per run. Verdicts were identical either way, the read being
  idempotent, so no verdict check in the suite could have shown it and none did:
  it was found by review of the commit that added it. What shows it is a count, so
  a count is what the suite now reads, off a git shim that logs every
  `for-each-ref` and passes every other call to the real git -- the fixture kind
  #111 introduced here. Both payloads name two bases, because a line naming one
  cannot tell a read made once from a read made per base.
REQ
requirement GH-144.6 <<'REQ'
- text: The active dev branch is read in the directory the hook process runs in, which
  no command moves, so a base aimed at another repository -- by `-R other/repo`, by
  `GH_REPO=`, or by a `cd` earlier on the line -- is judged against this
  repository's active dev branch: the branch active here is permitted for another
  repository, and one this repository has rotated past is refused there too.
  Accepted, not fixed.
- from: #144
- kind: defect-refusing
- status: active
- variants: none: its subject is which directory the refs are read in, a state of
  the tree that the command's text does not move -- that being the whole of what
  the entry says
- note: the corner GH-144.1 leaves, written as verdicts rather than as a sentence in
  a header, because a fix that gives up a case has to say so where a reader will be
  looking -- the rule this repository took from #50.3. IT IS A NEW REFUSAL, and
  this note argued the opposite until the second review of PR #158: that a
  narrower accept set is a subset of what was accepted before and therefore no
  regression. A narrower accept set is exactly a new refusal.
  `gh pr create -R other/repo --base dev-04` passed before #144 and is refused
  now, naming this repository's `dev-05`, and no base a caller can write both
  passes here and names the other repository's real active branch -- the only
  way through is `--web`. So the refusing row is a refusal that did not exist
  before, the permitting row is the one that says which bases still get through,
  and the reason this is accepted rather than fixed is the stopping rule alone,
  which is sufficient without the subset claim. It
  stays open under the stopping rule in `no-pr-decisions.sh`'s header, opening a
  pull request into another repository being no shape an agent working here writes
  by accident, and it is filed as no issue for the same reason. The `cd` spelling
  is the one this entry first missed: review of PR #158 read the header's "the
  repository the command runs in" and pointed out that a `cd other-repo &&` prefix
  moves the command and not the hook, so the sentence named the wrong directory in
  the one case where the two differ. The verdicts were right and only the account
  of them was wrong, which is why the correction is a wording change and two more
  rows rather than a fix.
REQ
requirement GH-144.7 <<'REQ'
- text: A refusal for the branch question also names the read its verdict rests
  on: it says to run `git fetch --prune` and try again if the dev branch has
  rotated since this session last fetched. The sentence is on all four
  spellings, and on
  none of the refusals read off the text of the command alone -- a base of main,
  a base that is not `dev-NN`, and a create naming no base at all.
- from: #144, found by the second review of PR #158
- kind: defect-permitting
- status: active
- direction: refuse-only: every claim here is about the wording of a refusal, and
  a permit has no message to read
- variants: none: its subject is the words of a refusal, which no rewriting of
  the refused command's spelling reaches -- GH-133's reason, and GH-144.3's
- note: the second-order cost of reading refs at all, and the review measured it
  as a defect rather than a wording preference. Rotate and push `origin/dev-06`
  mid-session: the agent's refs were last fetched at SessionStart, so
  `ACTIVE_DEV` is still `dev-05` and `gh pr create --base dev-06` -- the correct
  base -- is refused. GH-144.1's header named `git fetch` as the remedy and the
  message did not, so the one remedy an agent could read off the refusal was to
  retarget to `dev-05`, which this hook then permits, landing the pull request
  on the branch on its way out. That is what #144 was filed to stop,
  reintroduced through the message. A stale read is wrong in both directions and
  not only the refusing one -- after the rotation to `dev-06` a stale session
  refuses `dev-06` and PERMITS `dev-05`, measured in a fixture holding only the
  superseded ref -- so the refusal is the one place an agent can be told that
  the read is what to fix. The framing this note carried until the third review
  of PR #158, that the cost is a refusal rather than a permit, was the same
  subset reasoning GH-144.6 struck, surviving one entry over. The converse rows
  are the load-bearing half:
  a base of main told to fetch would be a remedy that cannot work, the shape
  question having nothing to do with refs. The remedy names `--prune` since
  round 1 of the review after the merge across the split, which measured a bare
  `git fetch` keeping a remote-tracking ref whose branch was deleted, so that
  doing exactly what the message said repeated the refusal. What this does not
  reach is the permitting half of a stale read: a permit has no message, so a
  stale session's `--base dev-05` goes through without a word. That is #238.
REQ
requirement GH-144.8 <<'REQ'
- text: Every line of `report-stale-branches.sh` that says a read was not made,
  or was made against refs no fetch refreshed, names BOTH hooks that read those
  refs -- `no-work-on-stale-branch.sh`, whose detectors go unarmed, and
  `no-pr-decisions.sh`, whose base rule accepts any `dev-NN` for want of a ref
  or judges against whatever branch stale refs still call active. All six lines
  in that file say so: the three `branches: NOT READ` causes, the skipped fetch,
  the failed fetch, and `active dev branch: none`. Four are driven and two are
  held to the file as text -- the unreachable root, which no run can reach, and
  the skipped fetch, which would need a second report fixture; the split and its
  reasons are beside the checks.
- from: #144, found by the third review of PR #158
- kind: doc-claim
- status: active
- direction: static: it reads the text of a report that makes no verdict
- note: GH-108.9 claims that each cause names a cause and a consequence; this
  claims WHICH hooks the consequence reaches, which #144 changed from one to two
  and which nothing updated. The report is the only place an agent is told at
  session start that the refs under a verdict were not read, so a report naming
  one hook leaves the other's wrong answer unexplained -- and by GH-144.7 that
  wrong answer is a wrong permit as well as a wrong refusal. `CLAUDE.md` was
  corrected for the same fact by the second review of PR #158 and this file was
  not, which is the shape the third review named: a correction applied where the
  finding pointed rather than everywhere the claim lives. It is split from
  GH-108.9 rather than folded into it because the two fail apart -- a report
  could name both hooks and stop printing a cause, or name a cause and one hook.
REQ
shape_pin 'GH-144.1 GH-144.2 GH-144.3:refuse-only GH-144.4:static GH-144.5 GH-144.6
  GH-144.7:refuse-only GH-144.8:static'
variants_pin 'GH-144.1:none GH-144.2:seed GH-144.3:none GH-144.5:none GH-144.6:none
  GH-144.7:none'

# no-pr-decisions.sh judged a base by pattern: every `dev-NN` string was accepted
# whatever refs origin held, while no-work-on-stale-branch.sh in the same
# repository derived the active dev branch as the highest `origin/dev-NN` and
# refused a commit measured against it. Two definitions of one term, and the
# rotation window -- when both refs exist -- is exactly when they disagree and
# when a worktree pull request lands on the branch on its way out.
#
# WHAT IS ASKED HERE, and the order matters because it is the order the hook
# answers in. The shape question is #40's and is measured there, in $ON_DEV,
# where no dev ref exists. What is measured here is the second question: of a
# base that is already dev-NN, whether it is the one origin holds highest --
# refused when it is not, in each of the four spellings, with the refusal naming
# the branch it expected -- and then the degraded case, where a read that comes
# back empty leaves the shape question as the whole rule and every refusal made
# on the text still made.
#
# FIXTURES ARE BUILT HERE RATHER THAN REUSED, except the two-ref one. This hook
# reads refs and nothing else: no upstream, no worktree, no commit count, so
# env_lifecycle's worktrees and gone-branch configuration would be fixture that
# no check here reads. Each fixture's refs are asserted against a literal below,
# because every verdict in this section is evidence about which ref was chosen
# and a fixture holding refs nobody wrote is evidence about the fixture.
PR_REFS="$ENV_REPOS/pr-base"
mkdir -p "$PR_REFS"
pr_ref_env() {  # pr_ref_env <name> <origin ref>...
  local dir="$PR_REFS/$1" r
  shift
  git init -q -b main "$dir"
  git -C "$dir" remote add origin "$FIXTURES/unreachable-remote.git"
  git -C "$dir" $GE commit -q --allow-empty -m base
  for r in "$@"; do git -C "$dir" update-ref "refs/remotes/origin/$r" HEAD; done
}
# one:   the ordinary state, one dev branch, and the state this repository is in
#        between rotations.
# ten:   dev-09 and dev-10, which is where a lexical sort and a version sort
#        disagree. The branch-hygiene skill's zero-padding makes the two agree
#        up to dev-09, so a suite that stopped at two-digit refs would call a
#        lexical sort correct.
# noise: a dev branch beside two refs that are not one. Unfiltered, `sort -V |
#        tail -1` of these three is origin/dev-foo, and the one real dev branch
#        would be refused as though it were stale.
pr_ref_env one dev-05
pr_ref_env ten dev-09 dev-10
pr_ref_env noise dev-05 dev-foo dev-05-backup
PR_ONE="$PR_REFS/one"
PR_TEN="$PR_REFS/ten"
PR_NOISE="$PR_REFS/noise"
for spec in "one:origin/dev-05" "ten:origin/dev-09 origin/dev-10" \
            "noise:origin/dev-05 origin/dev-05-backup origin/dev-foo"; do
  name=${spec%%:*}; want=${spec#*:}
  [ "$(git -C "$PR_REFS/$name" for-each-ref --format='%(refname:short)' 'refs/remotes/origin/*' \
        | sort | tr '\n' ' ')" = "$want " ] || {
    echo "the #144 ref fixture $name does not hold $want; every verdict read against it would be evidence about the fixture" >&2
    exit 1
  }
done

# THE RULE. A base that is the active dev branch is permitted and one that is
# not is refused, in all four spellings, because a rule that reaches the
# convenient one and not the API route is the defect #40 was filed for and #144
# is the same rule one question deeper.
req GH-144.1
env_cmd "$PR_ONE" "$PATH" no-pr-decisions.sh ALLOW 'the active dev branch is the permitted base' \
  'gh pr create --base dev-05 --title t --body b'
env_cmd "$PR_ONE" "$PATH" no-pr-decisions.sh BLOCK 'a dev branch that has been rotated past' \
  'gh pr create --base dev-04 --title t --body b'
env_cmd "$PR_ONE" "$PATH" no-pr-decisions.sh BLOCK 'a dev branch origin does not have yet' \
  'gh pr create --base dev-06 --title t --body b'
env_cmd "$ENV_DEV_TWO" "$PATH" no-pr-decisions.sh ALLOW 'two refs: the higher one is the base' \
  'gh pr create --base dev-06 --title t --body b'
env_cmd "$ENV_DEV_TWO" "$PATH" no-pr-decisions.sh BLOCK 'two refs: the lower one is refused' \
  'gh pr create --base dev-05 --title t --body b'
env_cmd "$ENV_DEV_TWO" "$PATH" no-pr-decisions.sh ALLOW 'a retarget to the active dev branch' \
  'gh pr edit 5 --base dev-06'
env_cmd "$ENV_DEV_TWO" "$PATH" no-pr-decisions.sh BLOCK 'a retarget to the branch on its way out' \
  'gh pr edit 5 --base dev-05'
env_cmd "$ENV_DEV_TWO" "$PATH" no-pr-decisions.sh ALLOW 'the REST create into the active dev branch' \
  'gh api -X POST repos/o/r/pulls -f base=dev-06 -f head=x'
env_cmd "$ENV_DEV_TWO" "$PATH" no-pr-decisions.sh BLOCK 'the REST create into the lower one' \
  'gh api -X POST repos/o/r/pulls -f base=dev-05 -f head=x'
env_cmd "$ENV_DEV_TWO" "$PATH" no-pr-decisions.sh ALLOW 'the graphql create into the active dev branch' \
  'gh api graphql -f query="mutation{createPullRequest(input:{baseRefName:\"dev-06\"})}"'
env_cmd "$ENV_DEV_TWO" "$PATH" no-pr-decisions.sh BLOCK 'the graphql create into the lower one' \
  'gh api graphql -f query="mutation{createPullRequest(input:{baseRefName:\"dev-05\"})}"'
# The two lines the three files share, asked of this one: the version sort and
# the filter, whose argument is made once in no-work-on-stale-branch.sh's header
# and is not repeated here. What these fixtures add is that the argument is
# measured for THIS hook: each of the two mistakes refuses the branch the other
# permits, so both fixtures are read in both directions.
env_cmd "$PR_TEN" "$PATH" no-pr-decisions.sh ALLOW 'dev-10 is higher than dev-09, sorted by version' \
  'gh pr create --base dev-10 --title t --body b'
env_cmd "$PR_TEN" "$PATH" no-pr-decisions.sh BLOCK 'and dev-09 is refused beside it' \
  'gh pr create --base dev-09 --title t --body b'
env_cmd "$PR_NOISE" "$PATH" no-pr-decisions.sh ALLOW 'origin/dev-foo and origin/dev-05-backup are not dev branches' \
  'gh pr create --base dev-05 --title t --body b'
env_cmd "$PR_NOISE" "$PATH" no-pr-decisions.sh BLOCK 'and neither is a base spelled that way' \
  'gh pr create --base dev-foo --title t --body b'

# THE REFUSAL NAMES THE BRANCH IT EXPECTED, which is what makes it one edit from
# correct -- #133's complaint about the retarget message, answered here for the
# rule this issue adds. All four spellings, because three of them reach one
# sentence and the fourth has its own, and a message that holds for one spelling
# and not another is the shape #40 was filed for.
req GH-144.3
env_says "$ENV_DEV_TWO" "$PATH" no-pr-decisions.sh 'is not dev-06, the active dev branch here' \
  'the create refusal names the branch it wanted' \
  'gh pr create --base dev-05 --title t --body b'
env_says "$ENV_DEV_TWO" "$PATH" no-pr-decisions.sh 'is not dev-06, the active dev branch here' \
  'so does the retarget refusal' \
  'gh pr edit 5 --base dev-05'
env_says "$ENV_DEV_TWO" "$PATH" no-pr-decisions.sh 'is not dev-06, the active dev branch here' \
  'so does the REST refusal' \
  'gh api -X POST repos/o/r/pulls -f base=dev-05 -f head=x'
env_says "$ENV_DEV_TWO" "$PATH" no-pr-decisions.sh 'is not dev-06, the active dev branch here' \
  'and so does the graphql refusal' \
  'gh api graphql -f query="mutation{createPullRequest(input:{baseRefName:\"dev-05\"})}"'
env_says "$PR_ONE" "$PATH" no-pr-decisions.sh 'is not dev-05, the active dev branch here' \
  'and the branch it names is read from the refs, not written into the message' \
  'gh pr create --base dev-04 --title t --body b'
# AND IT DOES NOT SAY THE OTHER THING. A dev-NN branch told it is "not a dev-NN
# branch" is a refusal that cannot be acted on, and one constant carrying either
# answer is one edit from saying the wrong one. The converse row is the second:
# main is not told which dev branch was expected, because naming one would read
# as an invitation to retarget a pull request that should not exist.
says_not "$ENV_DEV_TWO" no-pr-decisions.sh 'is not a dev-NN branch' \
  'a dev branch is not told it is not a dev-NN branch' \
  'gh pr create --base dev-05 --title t --body b'
says_not "$ENV_DEV_TWO" no-pr-decisions.sh 'the active dev branch here' \
  'and a base of main is told the shape, not the branch' \
  'gh pr create --base main --title t --body b'

# AND IT NAMES THE READ IT RESTS ON. A branch-question refusal is only as current
# as the session's last fetch, and until the second review of PR #158 it did
# not say so -- leaving "retarget to dev-05" as the one remedy readable off a
# refusal of the correct base during a rotation, which is #144's own defect
# arriving through the message. The four spellings first, then the converse: a
# refusal read off the text of the command alone must NOT offer a fetch, there
# being nothing a fetch would change about it.
req GH-144.7
env_says "$ENV_DEV_TWO" "$PATH" no-pr-decisions.sh 'run git fetch --prune and try again' \
  'the create refusal says what would make the read current' \
  'gh pr create --base dev-05 --title t --body b'
env_says "$ENV_DEV_TWO" "$PATH" no-pr-decisions.sh 'run git fetch --prune and try again' \
  'so does the retarget refusal' \
  'gh pr edit 5 --base dev-05'
env_says "$ENV_DEV_TWO" "$PATH" no-pr-decisions.sh 'run git fetch --prune and try again' \
  'so does the REST refusal' \
  'gh api -X POST repos/o/r/pulls -f base=dev-05 -f head=x'
env_says "$ENV_DEV_TWO" "$PATH" no-pr-decisions.sh 'run git fetch --prune and try again' \
  'and so does the graphql refusal' \
  'gh api graphql -f query="mutation{createPullRequest(input:{baseRefName:\"dev-05\"})}"'
says_not "$ENV_DEV_TWO" no-pr-decisions.sh 'git fetch' \
  'a base of main is not offered a fetch, which would change nothing about it' \
  'gh pr create --base main --title t --body b'
says_not "$ENV_DEV_TWO" no-pr-decisions.sh 'git fetch' \
  'nor is a base that is no branch shape at all' \
  'gh pr create --base feature-x --title t --body b'
says_not "$ENV_DEV_TWO" no-pr-decisions.sh 'git fetch' \
  'nor is a create that names no base' \
  'gh pr create --title t --body b'

# THE DEGRADED CASE: a read that comes back empty. This is the half #108
# declined to trade away, and it is why the lookup could be made at all -- the
# narrowing is asked only of a base that has already passed the shape question,
# so an environment this hook cannot read costs the narrowing and no refusal. No
# dev ref, git off PATH, and a directory that is no repository: in each, every
# dev-NN base is accepted as it was before #144 and every refusal made on the
# text of the line is still made.
#
# The refusing rows overlap GH-108.6's loop in the unsplit file, which drives
# two of these payloads over every environment of #108's section, and the
# overlap is deliberate: the two
# requirements would fail apart. GH-108.6 is the claim about the ENVIRONMENT --
# nothing this hook cannot read turns a refusal into a permit -- and it says
# nothing about which bases are accepted. GH-144.2 is the claim about the RULE in
# its degraded state, where the permit and the refusals are one answer and reading
# them in the same fixture is what makes it one.
req GH-144.2
for env in "no dev ref:$ENV_DEV_NONE:$PATH" "no repository:$ENV_NOREPO:$PATH" \
           "git off PATH:$ENV_DEV_TWO:$ENV_NO_GIT_BIN"; do
  name=${env%%:*}; rest=${env#*:}; dir=${rest%%:*}; path=${rest#*:}
  env_cmd "$dir" "$path" no-pr-decisions.sh ALLOW "$name: a dev-NN base is accepted" \
    'gh pr create --base dev-05 --title t --body b'
  env_cmd "$dir" "$path" no-pr-decisions.sh ALLOW "$name: any dev-NN base is, the shape being the whole rule" \
    'gh pr create --base dev-04 --title t --body b'
  env_cmd "$dir" "$path" no-pr-decisions.sh BLOCK "$name: a base of main is refused" \
    'gh pr create --base main --title t --body b'
  env_cmd "$dir" "$path" no-pr-decisions.sh BLOCK "$name: a create naming no base is refused" \
    'gh pr create --title t --body b'
  env_cmd "$dir" "$path" no-pr-decisions.sh BLOCK "$name: a retarget to main is refused" \
    'gh pr edit 5 --base main'
  env_cmd "$dir" "$path" no-pr-decisions.sh BLOCK "$name: the REST create into main is refused" \
    'gh api -X POST repos/o/r/pulls -f base=main -f head=x'
  env_cmd "$dir" "$path" no-pr-decisions.sh BLOCK "$name: and the REST create naming no base at all" \
    'gh api -X POST repos/o/r/pulls -f head=x'
done
# The git-off-PATH row is the sharpest of the three, and it is worth saying why
# separately: the fixture it runs in HOLDS dev-05 and dev-06, so the same
# command that is refused in the rule block above is permitted here. What
# differs is only whether the read could be made. That is the trade #144 took,
# written as a verdict rather than as a sentence.
req GH-144.2
env_says "$ENV_DEV_TWO" "$ENV_NO_GIT_BIN" no-pr-decisions.sh 'not a dev-NN branch' \
  'git off PATH: the refusal that remains is the shape one' \
  'gh pr create --base main --title t --body b'

# HOW MANY TIMES THE READ IS MADE, counted rather than claimed. The hook says it
# reads the refs once per run however many bases a line names, and the first
# version of it did not: every caller said `DEV=$(read_active_dev)`, a command
# substitution is a subshell, so the variable that records the read was set in a
# process that then exited and the memo was a no-op -- one `git for-each-ref` per
# base tested. Verdicts were identical either way, the read being idempotent, so
# no verdict in this section could have shown it and none did; it was found by
# review. What shows it is a count, so the count is what is checked.
#
# A shim first on PATH, the fixture kind #111 already uses here: it appends a
# byte for every `git for-each-ref` and hands every call to the real git, so the
# hook's verdict is the real one and the log is the number. Both payloads test
# two bases -- one where both pass and the line is permitted, one where the first
# passes and the second does not -- because a line naming a single base cannot
# tell a read made once from a read made per base.
PR_COUNT_SHIM="$FIXTURES/git-counting-shim"
PR_COUNT_LOG="$FIXTURES/for-each-ref-calls"
mkdir -p "$PR_COUNT_SHIM"
printf '#!/bin/bash\nfor a in "$@"; do\n  [ "$a" = for-each-ref ] && { printf x >> %s; break; }\ndone\nexec %s "$@"\n' \
  "$PR_COUNT_LOG" "$REAL_GIT" > "$PR_COUNT_SHIM/git"
chmod +x "$PR_COUNT_SHIM/git"
# Both halves of the shim, asserted, for the reason #111's is: a count read off a
# shim that logs nothing is zero, and zero would pass a check asking for "not
# more than once". It has to log a for-each-ref, and it has to leave every other
# call alone, or the verdicts beside the count are the shim's rather than the
# hook's.
: > "$PR_COUNT_LOG"
[ "$( cd "$ENV_DEV_TWO" && PATH="$PR_COUNT_SHIM:$PATH" git for-each-ref --format='%(refname:short)' 'refs/remotes/origin/dev-*' | sort -V | tail -1 )" = origin/dev-06 ] \
  && [ "$(wc -c < "$PR_COUNT_LOG" | tr -d ' ')" = 1 ] \
  && [ "$( cd "$ENV_DEV_TWO" && PATH="$PR_COUNT_SHIM:$PATH" git rev-parse --abbrev-ref HEAD )" = main ] \
  && [ "$(wc -c < "$PR_COUNT_LOG" | tr -d ' ')" = 1 ] || {
  echo "the counting git shim does not log a for-each-ref and pass everything else through; the counts below prove nothing" >&2
  exit 1
}
req GH-144.5
: > "$PR_COUNT_LOG"
env_cmd "$ENV_DEV_TWO" "$PR_COUNT_SHIM:$PATH" no-pr-decisions.sh ALLOW \
  'two bases on one line, both the active dev branch' \
  'gh pr create --base dev-06 --title t && gh pr edit 5 --base dev-06'
tok 'and the refs were read once, not once per base' \
    '1' "$(wc -c < "$PR_COUNT_LOG" | tr -d ' ')"
: > "$PR_COUNT_LOG"
env_cmd "$ENV_DEV_TWO" "$PR_COUNT_SHIM:$PATH" no-pr-decisions.sh BLOCK \
  'a create naming the active dev branch and then another' \
  'gh pr create --base dev-06 --base dev-05 --title t'
tok 'and that refusal read them once as well' \
    '1' "$(wc -c < "$PR_COUNT_LOG" | tr -d ' ')"
# And nothing at all where no base is named, which is what keeps an ordinary
# command off the read: the permitted `gh issue list` and the refused `gh pr
# merge` are both judged without it.
: > "$PR_COUNT_LOG"
env_cmd "$ENV_DEV_TWO" "$PR_COUNT_SHIM:$PATH" no-pr-decisions.sh ALLOW \
  'a command naming no base at all' \
  'gh issue list'
env_cmd "$ENV_DEV_TWO" "$PR_COUNT_SHIM:$PATH" no-pr-decisions.sh BLOCK \
  'and a refusal that needs no base' \
  'gh pr merge 5'
tok 'neither of those read the refs at all' \
    '0' "$(wc -c < "$PR_COUNT_LOG" | tr -d ' ')"

# THE CORNER LEFT OPEN, written as verdicts rather than as a sentence in a
# header, because a fix that gives up a case has to say so where a reader will
# be looking. The refs are read in the directory the hook process runs in, which
# is the session's and which no command moves, so a base is judged against THIS
# repository's active dev branch whichever repository the pull request is going
# to. Both directions of that are here: the base this repository calls active is
# permitted for the other one, and a base that may well be active over there is
# refused. THAT SECOND ROW IS A NEW REFUSAL and not a narrowed permit, which is
# what this comment said until the second review of PR #158: `--base dev-04` for
# another repository passed before #144, is refused now, and no base a caller
# can write both passes here and names that repository's real active branch --
# the only way through is --web. It stays open under the stopping rule and on
# that alone: opening a pull request into another repository is not a shape an
# agent working here writes by accident.
#
# Three spellings, because the corner is one corner and not three, and because
# the sentence this comment replaces said "the repository the command runs in"
# -- which review of PR #158 caught as wrong about exactly the third: a `cd`
# moves the command and not the hook, so in the one case where the two
# directories differ the old wording named the wrong one. A claim about which
# directory is read is worth a row per route, since the routes are what a reader
# would otherwise have to reason about.
req GH-144.6
env_cmd "$PR_ONE" "$PATH" no-pr-decisions.sh ALLOW \
  'ACCEPTED: another repository, based on the branch active in this one' \
  'gh pr create -R other/repo --base dev-05 --title t --body b'
env_cmd "$PR_ONE" "$PATH" no-pr-decisions.sh BLOCK \
  'ACCEPTED: and a base this repository has rotated past is refused there too' \
  'gh pr create -R other/repo --base dev-04 --title t --body b'
env_cmd "$PR_ONE" "$PATH" no-pr-decisions.sh ALLOW \
  'ACCEPTED: GH_REPO reaches the same corner, and is judged the same way' \
  'GH_REPO=other/repo gh pr create --base dev-05 --title t --body b'
env_cmd "$PR_ONE" "$PATH" no-pr-decisions.sh BLOCK \
  'ACCEPTED: and so does a cd, which moves the command but not this hook' \
  'cd ../other-repo && gh pr create --base dev-04 --title t --body b'
env_cmd "$PR_ONE" "$PATH" no-pr-decisions.sh ALLOW \
  'ACCEPTED: the same cd with the base active here is permitted' \
  'cd ../other-repo && gh pr create --base dev-05 --title t --body b'
env_cmd "$PR_ONE" "$PATH" no-pr-decisions.sh BLOCK \
  'while main is refused for another repository as it is for this one' \
  'gh pr create -R other/repo --base main --title t --body b'

# THIS SUITE'S OWN RULE, and it is a rule about the checks rather than about the
# hook. A payload naming a dev-NN base now has a verdict that depends on the refs
# of the repository the hook runs in, and one harness does not name a directory:
# `check` runs the hook where the suite's driver stands, which is inside this repository.
# So a row reading `dev-05` there is evidence only until the next rotation makes
# `dev-06` the active branch, when it goes red blaming a hook that was right.
# Rows moved to $ON_DEV when this issue landed -- seeds of the #106 families
# from `hooks` to `on-dev`, and loops with them. HOW MANY IS NOT WRITTEN HERE,
# deliberately: what has to hold is that no bare row is left and not how many
# scoped ones there are, which is GH-144.4's note in as many words, and a count
# in a comment is the thing #107 was filed about. This sentence said
# thirty-five and counted the three loops twice, once in that total and again
# in the clause that added them; the merge of dev-05 into this branch then
# moved more rows still, so it was stale inside its own pull request. Bertan's
# review of PR #158.
#
# THREE SHAPES, because a payload reaches a hook three ways in the suite and a
# derivation that sees one of them is evidence about one of them. A row written
# out on one logical line; a payload held in a variable and passed by a loop; and
# a row of the #106 seed table, whose fixture is its first field. Each is asked
# separately below, and the middle one is asked as an absence -- once no bare
# `check` of this hook takes a variable payload, every dev-NN payload that
# reaches `check` is written on the line that calls it, which is what the first
# derivation reads.
#
# Continuation lines are joined before anything is matched, because the payload
# of an `env_cmd` row sits on the next line and a line-at-a-time derivation would
# see the hook and the base on different lines and match neither. `lacks` refuses
# an empty read, so a derivation that stopped matching altogether fails rather
# than reporting that no bare row was found.
#
# MEASURED, on copies of the suite rather than by reasoning, because each of the
# three shapes is a derivation and a derivation that matches nothing reads like a
# pass. One row put back to a bare `check` adds `check` to the harness set; one
# seed put back to `hooks` adds it to the fixture set; one loop put back to a
# bare `check` with a variable payload moves the count to 1 and moves NEITHER
# set, which is why the count is a check of its own and not a restatement; and a
# derivation pointed at a hook name that is not there reads empty, where `lacks`
# fails rather than passing on an absence it could not have found.
req GH-144.4
PR_JUDGED=$(awk '
  /^[[:space:]]*#/ { next }
  { line = line $0 }
  /\\$/            { sub(/\\$/, "", line); next }
  { print line; line = "" }
' "$SUITE_TEXT" | grep -F 'no-pr-decisions.sh' | grep -E 'dev-[0-9]')
PR_DEV_ROW_HARNESS=$(printf '%s\n' "$PR_JUDGED" \
  | grep -oE '(^|[[:space:]])(check_in|check|feed_says|feed|says_not|says|env_cmd|env_says|env_feed)[[:space:]]' \
  | tr -d '[:blank:]' | sort -u | tr '\n' ' ')
holds 'every dev-NN base this suite judges on one line is judged in a named directory' \
  "$PR_DEV_ROW_HARNESS" 'check_in'
lacks 'and none of those is judged wherever the suite was started from' \
  "$PR_DEV_ROW_HARNESS" 'check '
# WHICH DIRECTORY, and not merely that one was named. The two lines above read
# the HARNESS WORD and nothing else, so they distinguish a named directory from
# an inherited one and stop there -- and `check_in "$SUITE_DIR"` names a
# directory, satisfies both, and is this repository. One such row stood at the
# permitting rows of #117 and was found by the fourth review of PR #158, which
# did not argue it: it added `refs/remotes/origin/dev-06` to a scratch clone and
# ran this suite, which went from 5190 green to one FAIL blaming a hook that was
# right. That is the failure GH-144.4 exists to stop, reproduced inside the pull
# request that introduces the requirement.
#
# So the directory ARGUMENT of every matching row is read and held to a literal.
# The literal is the strong half: a row judged somewhere new turns it red and
# someone has to say why that directory is a fair place to judge a dev-NN base.
# `lacks` beside it names the one failure the literal would otherwise report as
# an anonymous diff, which is the sentence a reader needs.
#
# `$dir` is the loop variable of the two `for env in` loops above, GH-108.6's in the
# unsplit file and GH-144.2's in this one, whose fixture lists are literals in
# the suite's text; the third check holds those lists away
# from $SUITE_DIR, so the variable is bounded by what the lists may say.
#
# WHAT THIS DERIVATION IS FOR, since PR #158's fifth review, and it is no longer
# the answer to GH-144.4. It reads the suite's text, and four review rounds found
# five shapes it cannot see. Three are still open and are named here rather than
# patched, because the run-reading derivation at the head of the end-of-run file
# sees all of them and a sixth strengthening would be the same losing bet:
#
#   - a payload in a `for` list judged by `check_in ... "$c" "$c"`: the payload
#     line does not name the hook and the judging line holds no literal dev-NN,
#     so both PR_JUDGED and the variable rule return empty for it. TWO SUCH ROWS
#     ARE LIVE and are correct only because their `"$ON_DEV"` was hand-written;
#   - a payload behind a `\` continuation: PR_JUDGED joins continuations and the
#     variable rule does not, so a row split across two lines escapes the second;
#   - `case "${!v}"` reads a variable once, after the file has run, so a loop
#     variable is read as its last element rather than once per row.
#
# `feed` and `feed_says` were in the directory alternation above until that same
# review: their first argument is a PATH and they hard-code `cd "$ON_DEV"`, so a
# `dev-NN` row through either would have been reported as naming an unexpected
# directory while being perfectly safe -- a false red, and the `lacks` beside it
# would have been asserting a property it never measured for those rows. They are
# out. `flip` stays, because it takes a directory and delegates to check_in.
#
# So these three are the CHEAP check: they read the file without running it, they
# fail fast, and they are honest about covering the shapes someone has thought
# of. What GH-144.4 rests on is the pair at the head of the end-of-run file.
#
# WHETHER THESE TWO CAN FAIL was asked by measuring and not by registering, and
# the reason is structural rather than an omission. #107's harness mutates the
# hooks under judgment; check-hooks.sh and every file under checks/ are its
# TOOLING, and a row naming one is refused, because the harness RUNS the suite
# rather than judging it. A row
# that put the $SUITE_DIR spelling back was written, registered, and refused by
# that guard -- correctly. So every GH-144.4 derivation is in a class the
# mutation registry cannot reach, and the evidence for them is a run: with the
# two checks below in place and the #117 row still spelled `check_in
# "$SUITE_DIR"`, both go red, naming that directory. Measured on this branch
# before the row was moved, and reproducible by moving it back.
PR_DEV_ROW_DIRS=$(printf '%s\n' "$PR_JUDGED" \
  | grep -oE '(^|[[:space:]])(check_in|flip|says_not|says|env_cmd|env_says|env_feed)[[:space:]]+"[^"]+"' \
  | sed 's/.*"\(.*\)"/\1/' | LC_ALL=C sort -u | tr '\n' ' ')
tok 'and the directory each one names is one of these, read off the rows themselves' \
    '$ENV_DEV_NONE $ENV_DEV_TWO $ON_DEV $PR_NOISE $PR_ONE $PR_TEN $dir ' \
    "$PR_DEV_ROW_DIRS"
lacks 'so none of them is judged in this repository, where dev-05 is active today' \
  "$PR_DEV_ROW_DIRS" '$SUITE_DIR'
lacks 'nor does any fixture list feeding those loops name it' \
  "$(grep -E '^[[:space:]]*(for env in|[[:space:]]+\")' "$SUITE_TEXT" \
     | grep -E 'ENV_|PR_ONE|ON_DEV' | tr '\n' ' ')" '$SUITE_DIR'
# A PAYLOAD HELD IN A VARIABLE, which is the third route and the one that reads
# past the first derivation: `PR_JUDGED` matches a literal `dev-[0-9]` on the
# line, so a payload the line does not spell is invisible to it. A rule stood
# here for it, and the next two paragraphs are its history; the one after them
# says why it is gone.
#
# The rule here used to require the `"$` in the LABEL position, which catches the
# `for c in ...; do check ... "$c" "$c"` shape and nothing else. A row written
# `check no-pr-decisions.sh ALLOW 'a literal label' "$c"` escaped it and escaped
# `PR_JUDGED` with it, so it was invisible to every GH-144.4 derivation at once.
# Found by the fourth review of PR #158, measured against a synthetic file: the
# old expression counts one of the two shapes and this one counts both.
#
# ASKED OF THE VALUE AND NOT THE SPELLING, which is what changed with it. Two
# such rows exist and are right -- `$COMMIT_MSG` and `$NOTE` carry heredoc prose
# naming `gh pr merge` and `git push origin main`, neither of which is a base --
# so a rule that refuses the SHAPE would refuse them, and a count of permitted
# ones is a number that goes stale the next time someone writes a third. What
# has to hold is that no such payload hides a dev-NN base from the derivation
# above, and the variable was in scope here, so its value was read rather than
# its name argued about, with a `holds` beside it as the non-vacuity guard
# `lacks` would give: a derivation that stopped matching would otherwise have
# reported an empty set of offenders and passed.
#
# THE VARIABLE-PAYLOAD RULE IS GONE, and its removal is the honest end of a
# thread rather than a simplification. It asked whether any payload held in a
# variable hid a dev-NN base from the derivations above, and it read that value
# with `case "${!v}"` -- once, after this whole file had run. For a loop
# variable that is the loop's LAST element, so a `for` list whose first entry
# names a base and whose last does not passed it while the base was judged.
# PR #158's fifth review found that, and it is the same defect as the rest of
# this block one step further in: a check whose subject is narrower than the
# claim beside it, here narrowed by WHEN it reads rather than by what it matches.
#
# It is deleted instead of repaired because the pair at the head of the
# end-of-run file reads every payload as the shell expanded it, once per row, so
# a variable payload is not a special case there and needs no rule of its own.
# Repairing this one would have left two answers to one question, and the weaker
# one is the one a reader meets first.
PR_DEV_SEED_DIRS=$(grep -E '^[a-z-]+\|no-pr-decisions\.sh\|' "$SUITE_TEXT" \
  | grep -E 'dev-[0-9]' | cut -d'|' -f1 | sort -u | tr '\n' ' ')
holds 'every #106 seed naming a dev-NN base runs in a fixture with no dev ref' \
  "$PR_DEV_SEED_DIRS" 'on-dev'
lacks 'and none of them runs in this repository' \
  "$PR_DEV_SEED_DIRS" 'hooks'

# THE RECORD THE END-OF-RUN FILE READS DOES NOT DEPEND ON THE ROUTE, asked of the
# routes the record exists to reach. It is written by the hook's own process,
# through BASH_ENV (see the driver's prelude), so these four runs use no helper
# at all: one started directly at this file's top level, which is the shape
# review of PR #158 measured past the helper-written record; one through `bash`;
# one whose directory is reached through a symbolic link, which must be recorded
# as the directory the process is really in; and one whose payload puts the
# base after a newline, which the first record wrote across two lines and its
# reader then did not credit. Each payload names the route, and the base after
# it, so a record that split one run in two or lost its base reads as a
# different row here.
req GH-144.4
PR_ONE_P=$(cd -- "$PR_ONE" && pwd -P)
ln -s -- "$PR_ONE" "$FIXTURES/pr-one-link"
PR_ROUTES_AT=$(wc -l < "$JUDGED")
printf '%s' 'gh pr create --title route-direct --base dev-05' | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' \
  | ( cd -- "$PR_ONE" && "$HOOKS/no-pr-decisions.sh" ) > /dev/null 2>&1
printf '%s' 'gh pr create --title route-bash --base dev-05' | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' \
  | ( cd -- "$PR_ONE" && bash "$HOOKS/no-pr-decisions.sh" ) > /dev/null 2>&1
printf '%s' 'gh pr create --title route-link --base dev-05' | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' \
  | ( cd -- "$FIXTURES/pr-one-link" && "$HOOKS/no-pr-decisions.sh" ) > /dev/null 2>&1
printf 'gh pr create --title route-newline\n  --base dev-05' \
  | ( cd -- "$PR_ONE" && "$HOOKS/no-pr-decisions.sh" ) > /dev/null 2>&1
tok 'every route to the hook is recorded by the hook, one line a run, in the directory it ran in, with its base' \
'$PR_ONE no-pr-decisions.sh route-direct
$PR_ONE no-pr-decisions.sh route-bash
$PR_ONE no-pr-decisions.sh route-link
$PR_ONE no-pr-decisions.sh route-newline' \
  "$(tail -n +"$((PR_ROUTES_AT + 1))" "$JUDGED" \
     | awk -F'\t' -v d="$PR_ONE_P" '{
         n = split($2, p, "/")
         r = $3; if (match(r, /route-[a-z]+ +--base dev-05/)) r = substr(r, RSTART, RLENGTH); sub(/ +--base dev-05$/, "", r)
         print ($1 == d ? "$PR_ONE" : $1), p[n], r
       }')"

# WHAT THE SESSION REPORT SAYS ABOUT THE BASE RULE (GH-144.8), driven against
# #108's copies of the report:  outside a repository and with git
# off PATH, and  after a fetch that failed. The rows beside
# these in #108's section read the half of each message that names the stale-
# branch guard, and those are GH-108.9's and GH-108.10's.
# WHICH HOOKS THAT CONSEQUENCE REACHES, which is two since #144 and was written
# as one until the third review of PR #158. The report is the only place an
# agent is told at session start that the refs behind a verdict were not read,
# and no-pr-decisions.sh's base rule rests on the same refs as the stale-branch
# detectors. CLAUDE.md was corrected for this fact one review earlier and the
# runtime message that tells an agent the same thing was not, which is why this
# is a check and not a sentence: the claim now lives in six places in that file
# and a derivation reads them rather than a reader remembering.
req GH-144.8
report_says "$PATH" "$ENV_REPORT_COPY/report-stale-branches.sh" \
  'no-pr-decisions.sh accepts any dev-NN base for want of a ref.' \
  'outside a repository it also names the base rule the same refs feed'
report_says "$ENV_NO_GIT_BIN" "$ENV_REPORT_COPY/report-stale-branches.sh" \
  'no-pr-decisions.sh accepts any dev-NN base for want of a ref.' \
  'and so it does with git off PATH'
# THE TWO SITES A RUN CANNOT REACH, and the entry claimed all six before the
# fourth review of PR #158 counted them. Four of the six are driven -- the two
# above, the failed fetch and `active dev branch: none` below. The other two are
# held to the file, for two different reasons, and neither reason is that
# checking them was awkward:
#
#   - the unreachable-root guard, for the reason the `written` pin beside it
#     already gives: a directory unsearchable enough to fail that `cd` is one
#     bash cannot read the file out of either, so the line cannot be run at all;
#   - `fetch: SKIPPED`, which needs a repository with no `origin` AND a hooks
#     copy inside it. $ENV_NO_ORIGIN is the first and holds no copy, and building
#     a second report fixture to drive one line is a fixture whose upkeep costs
#     more than the line is worth. Named as a trade rather than left as a gap.
#
# Without these two, deleting either clause alone left this suite green while
# GH-144.8's text read false -- and the mutation registered for it could not see
# that, its sed address taking all five matching lines at once. `report-omits-
# the-skipped-fetch-clause` deletes exactly this one.
# A PIN PER SITE, and `written` cannot be one. The first answer here was two
# `written` pins, and the registry row written beside them -- which deletes the
# skipped-fetch clause and nothing else -- SURVIVED them. `written` is `grep -qF`
# over the whole file, so a literal standing at six sites is still present when
# one is deleted, and a pin on it says nothing about any site. The row is what
# said so; the pins read as evidence and were none.
#
# So the sites are derived instead. Every run of adjacent `echo` or `printf`
# lines is one message, in either quote -- the report prints every message with
# `echo "` today, and a message added with `printf` or single quotes would
# otherwise be outside the scope this claims to cover, which is the shape round 1
# of the review after the merge across the split asked to be swept for; a message is in scope when it says a read was not made or was made
# against refs no fetch refreshed -- which is what its staleness-detector,
# not-armed or abstains wording marks -- and every message in scope must name
# no-pr-decisions.sh too. The echo scaffolding is stripped and the whitespace
# collapsed before matching, because "neither staleness" and "detector in" fall
# on different lines in one of the six and a line-at-a-time match misses it.
#
# The two messages this deliberately leaves out are the ones GH-144.8 is not
# about: `merge settings: NOT READ`, whose subject is a setting that arms that
# guard's detectors and feeds no base rule, and the `main ancestry` line, whose
# subject is that guard's ahead/behind test. Both correctly name one hook, and a
# derivation that swept them in would be the correction applied one site too far.
REPORT_DEGRADED=$(awk '
  /^[[:space:]]*(echo|printf)[[:space:]]/ {
    if (!g) { g = 1; t = ""; s = NR }
    line = $0
    sub(/^[[:space:]]*(echo|printf)[[:space:]]+["\047]?/, "", line); sub(/["\047][^"\047]*$/, "", line)
    t = t " " line
    next
  }
  { if (g) { emit(); g = 0 } }
  END { if (g) emit() }
  function emit(   j) {
    j = t; gsub(/[[:space:]]+/, " ", j)
    if (j !~ /staleness detector|is not armed for this session|abstains rather than refusing/) return
    printf "%s:%s\n", s, (j ~ /no-pr-decisions\.sh/ ? "names-base" : "MISSING")
  }
' "$HOOKS/report-stale-branches.sh")
tok 'the report has six messages about a read it could not make or could not trust' \
    '6' "$(printf '%s\n' "$REPORT_DEGRADED" | grep -c .)"
lacks 'and every one of them names the base rule beside the stale-branch guard' \
  "$REPORT_DEGRADED" 'MISSING'
req GH-144.8
report_says "$ENV_NO_GH_BIN" "$ENV_OFFLINE_REPORT" \
  "request's base against whatever branch those refs still call active." \
  'a failed fetch says the base rule is judging against the refs it left behind'
report_says "$ENV_NO_GH_BIN" "$ENV_OFFLINE_REPORT" \
  'no-pr-decisions.sh accepts any dev-NN base for want of a ref.' \
  'and with no dev ref fetched at all, that the base rule accepts any of them'
sourced_to_end

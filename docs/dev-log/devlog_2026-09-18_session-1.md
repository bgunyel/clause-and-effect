# 2026-09-18 · session 1 — the follow-up review of #153: a closure of the separator, not of the field

**Branch** `worktree-issue-137-field-quote-spellings`, still proposed into
`dev-05`. No verdict changed in this session. **Check suite 3711 results, all
passing**, unchanged from session 5 and still measured against the fork point
`befcf8a`. The branch is still not merged with `dev-05`, which is now at
`f07f503` and alone gives 4100 results; the landed total has to be re-measured
after the merge rather than carried from either side.

## What the review found

The follow-up review of PR #153 at `7ed9504` confirmed the first round's
findings 1 and 2 fixed, and raised three more. The assistant re-measured each
one by feeding the command to the hook on stdin before acting on it.

**A. The closure claim overreached.** Session 5 called the separator class
`[[:space:]=]*` "the closure and not another guess". That is true of the
separator between flag and value. It is not true of the field, and the issue is
titled after the field. Quoting and escaping inside the name or the value are
still invisible, and seven spellings are permitted: four retarget onto `main`
(`-f ba"se"=main`, `-f b'ase=main'`, `-f base\=main`, `-f \base=main`) and three
close a pull request (`-f st"ate"=closed`, `-f state=clo"sed"`,
`-f state\=closed`). All seven are permitted on `dev-05` too, so #153 did not
open them; the assistant's comment claimed they were closed.

The review's point is about method: each round of #137 added one more regex
guess at where quoting can sit, and each round the next reader found the next
position. The structural fix is to dequote each argument before reading it. The
assistant did not build that here, and the reason is landing order rather than
effort. The `state` reader runs over the whole line, so dequoting it would also
match `{"state":"closed"}` in an `--input` heredoc. That is exactly the
one-character pre-#130 change #138 says must not be made, because #130's
per-command move would silently undo it. The in-word half is filed as **#163**,
to land after #130. The comment, `GH-137.1` and `GH-137.2` now say the closure
is of the separator only and cite #163. The PR title is narrowed from "every
quote spelling" to the quoting round the field.

**B. `--input` on a retarget.** `gh api -X PATCH …/pulls/35 --input body.json`
is permitted, and so are here-string bodies naming `main` or `closed`. #138
already owns bodies, but its table measured only the create side, and its "must
not lose" item 1 assumed an unreadable body is refused today. On `PATCH
/pulls/N` it is not. The assistant added this to #138 as a comment instead of
filing a duplicate.

**C. The merge got worse.** `dev-05` now holds sessions 1–6 for 2026-09-17, so
both of this branch's entries for that day collide by filename and must land as
sessions 7 and 8. The session-5 cross-reference to "session 4" is then wrong too.
None of that can be done by an agent under `append-only-docs.sh`, and it is left
to Bertan with the merge. `REQUIREMENT_SHAPE` and `requirements.md` resolve as
the union of both sides' IDs. This entry is dated 2026-09-18 so that it does not
add a third collision.

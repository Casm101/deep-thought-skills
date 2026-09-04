---
name: dt-branch-update
description: Bring a branch up to date with the origin's default branch, then commit and push the merge. Works on the current branch or one you name, refuses on release and hotfix branches where CI forbids it, uses a throwaway worktree when the branch is elsewhere and your tree is dirty, hands conflicts to dt-merge-conflicts, and verifies before pushing because a clean merge can still break the build. Use when asked for "dt branch update", or to update, refresh, or merge the latest changes into a branch.
argument-hint: "branch to update, or nothing for the current one"
---

# dt-branch-update

Merge the default branch in, prove it still works, push it.

Three things make this less mechanical than it sounds. Some branches must never take this merge, a
clean merge can still break the build, and the branch you want is not always the one you are standing
on.

## Rules that hold throughout

**Merge, never rebase.** Every branch update in this repo's history is a merge commit with git's
default message, and rebase would need a force-push. `dt-ship` forbids force-pushing and so does this.

**Never force-push, ever.** If the remote has commits you do not, stop and report. That is somebody
else's work or a rewritten history, and neither is yours to flatten.

**The default branch comes from origin**, whatever it is called. Read
`refs/remotes/origin/HEAD`, and fall back to `main`, `master`, `trunk`, `develop` in that order. Never
hardcode a name.

## Phase 1. Preflight

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-branch-update/scripts/update-preflight.sh [<branch>]
```

It reports the target, the default branch it would merge from, whether the target is a fix branch,
whether the branch is local and the tree clean, the route to take, how many commits are incoming, and
which files both sides touched. `RESULT: blocked` ends the run.

Read the overlapping files line. Those are the only places a conflict can land, and knowing the list
before you start turns a surprise into an expectation.

## Phase 2. The fix branch refusal

If the target matches `^(hotfix|rcfix|release)/` and does not end in `-merge`, **stop**.

This is not a preference. A fix branch is the exact record of what shipped, merging the default branch
into it pulls in unshipped work, and CI rejects the push. The check is
`.github/workflows/fix-branch-hygiene.yml`, the logic is
`scripts/ci/src/check-fix-branch-hygiene.ts`, and the reasoning is `docs/RELEASE-BRANCHING.md`.

Say which check would fail, then offer the two sanctioned routes:

- **One change that is already on the default branch.** `git cherry-pick -x <sha>`, where the `-x` stamp
  keeps the link to the reviewed original.
- **Backmerge conflicts.** Branch `<fix-branch>-merge` from the fix branch and merge there. A branch
  ending in `-merge` is exempt, and this skill updates those normally.

A repo without those files gets the same refusal on the same branch names, because the reasoning holds
anywhere: a release branch that quietly gains unshipped commits stops being a record of a release.

## Phase 3. Take the route

Four routes, and `references/routes.md` has the mechanics. The preflight picks one.

| Branch | Tree | Route |
|---|---|---|
| The one you are on | clean | merge in place |
| Local, not checked out | clean | switch to it, merge, stay there |
| Not local | clean | fetch, switch to it, merge, stay there |
| Not local | dirty | throwaway worktree, and your checkout is never touched |

A dirty tree on the branch you are already on is a refusal. Commit or stash first. Never stash on
someone's behalf.

The worktree route has a cost worth knowing before you promise anything: a fresh worktree in this
repo has no working `@gutro/*` links, so Phase 5 needs `pnpm install` there first.

## Phase 4. Merge

```bash
git fetch origin
git merge "origin/$DEFAULT"
```

Let git write the message. The history is full of `Merge remote-tracking branch 'origin/main' into
feature/...` and that is what reviewers expect. No ticket prefix, no trailer, no rewrite.

**If there is nothing to merge, stop.** Say the branch is already up to date rather than making an
empty merge commit.

**On conflicts, run `dt-merge-conflicts`.** It knows which side is which, reads both before touching
anything, and calls `dt-implement` when a reconciliation needs real code. Do not resolve them here.

When it finishes, check what came back. A resolution that only reconciled text carries on to Phase 5.
A resolution that changed behaviour stops for the user, because that is a code change nobody asked
for arriving inside a merge.

## Phase 5. Verify before pushing

A merge with zero conflicts can still break the build. Two changes that never touch the same line can
still contradict each other: a function renamed on one side, a new call to its old name on the other,
merges clean and fails to compile.

So, in the tree where the merge happened:

- the type check for the packages the merge touched
- the tests for the files the merge touched
- the whole suite when the incoming change is large or reaches widely

In a worktree, run the install first. Verification you skipped is not verification, and pushing a
merge you did not check is the thing this phase exists to prevent.

If anything fails, stop. Report what failed, leave the merge uncommitted or unpushed, and let the user
decide. Never fix a failure by reverting the merge silently.

## Phase 6. Push

```bash
git push
```

No flags. If the branch has no upstream, `git push -u origin <branch>`.

Stop instead of pushing when the remote has commits you do not have, when verification failed, or when
the conflict resolution changed behaviour. Never `--force`, never `--force-with-lease`, never
`--no-verify`.

## Phase 7. Report, and clean up

Say what happened: the branch, the default branch it merged, how many commits came in, whether there
were conflicts and what resolved them, what verification ran and what it said, and the push result.

If you used a worktree, remove it:

```bash
git worktree remove <path>
```

Without `--force`. If it refuses because something is in there, say so and give the path rather than
forcing. A refused removal means something unexpected is in that directory, and deleting it blind is
how work disappears.

## Never

- Rebase, or force-push in any form
- Merge the default branch into a `hotfix/`, `rcfix/` or `release/` branch
- Stash, reset, clean, or discard anything to make room for the merge
- Push a merge you did not verify
- Create an empty merge commit to look busy
- Resolve conflicts here rather than in `dt-merge-conflicts`
- Leave a worktree behind, or remove one with `--force`

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.

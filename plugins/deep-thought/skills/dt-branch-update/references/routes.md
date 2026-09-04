# The four routes

The preflight picks one. Each ends with the branch updated and pushed, and differs only in where the
work happens and what it leaves behind.

## In place

You are on the branch and the tree is clean. Nothing to set up.

```bash
git fetch origin
git merge "origin/$DEFAULT"
```

## Local, not checked out

The branch exists locally, the tree is clean, you are somewhere else.

```bash
git fetch origin
git switch <branch>
git merge "origin/$DEFAULT"
```

Stay on it afterwards and say so. You almost certainly want to be on the branch you just updated, and
switching back silently is the kind of surprise that costs somebody ten minutes.

## Not local, tree clean

The branch is on origin only.

```bash
git fetch origin
git switch --track -c <branch> "origin/<branch>"
git merge "origin/$DEFAULT"
```

`--track` is right here, unlike when creating a new branch: this branch already exists on origin, and
tracking it is what makes a bare `git push` work.

## Not local, tree dirty

The interesting one. Your checkout has uncommitted work, the branch is elsewhere, and neither should
disturb the other. Do it in a worktree and throw the worktree away.

```bash
WT="${TMPDIR:-/tmp}"; WT="${WT%/}/dt-branch-update-$$"
git fetch origin
git worktree add --track -b <branch> "$WT" "origin/<branch>"
cd "$WT"
git merge "origin/$DEFAULT"
# verify, then push, from inside $WT
cd -
git worktree remove "$WT"
```

Four things about this route.

**The worktree lives outside the repo.** `${TMPDIR}` and not `.claude/worktrees/` or anywhere under
the working copy, so nothing lands in the repo and nothing needs adding to a gitignore.

**A fresh worktree cannot run the tests yet.** In this repo it has no working `@gutro/*` links, so
Phase 5 needs `pnpm install` in the worktree before the type check and the tests mean anything. That
install is the main cost of this route, so say it is happening rather than letting it look like a hang.

**Push from inside the worktree.** It is a normal checkout of a normal branch, so `git push` behaves
as it would anywhere. The upstream came from `--track`.

**Remove it when done, without `--force`.** A refusal means something is in there you did not put
there, and the right answer is to report the path, not to delete it blind. Check with
`git worktree list` if you are unsure what exists.

If the branch is already checked out in another worktree, `git worktree add` refuses. Say which
worktree holds it rather than working around it.

## Verification, per route

Same checks everywhere, different setup cost.

| Route | Setup before verifying |
|---|---|
| In place | none |
| Local, not checked out | none |
| Not local, tree clean | none |
| Worktree | `pnpm install` in the worktree, or whatever this repo's install is |

What to run, in the tree where the merge landed:

```bash
# the packages the merge touched
git diff --name-only HEAD~1 HEAD | sed -n 's#^\(apps\|packages\|core-packages\)/\([^/]*\)/.*#\1/\2#p' | sort -u
# then, per package
(cd <pkg> && pnpm type-check)
(cd <pkg> && pnpm test --run <the touched spec files>)
```

Full suite when the incoming change is large, reaches many packages, or touches anything shared. A
merge that brought in twenty commits across four packages is not covered by one spec file.

## When the merge goes wrong

**Conflicts** go to `dt-merge-conflicts`, always. It is built for exactly this and it already knows to
call `dt-implement` when a reconciliation needs real code.

**A merge you want to abandon** before committing:

```bash
git merge --abort
```

That is the one undo this skill uses, and only on a merge it started itself, in the tree it started it
in. Never `reset --hard`, never `checkout -f`, and never abort a merge somebody else began.

**Verification failing after a clean merge** is a real result, not a setup problem. It means the two
sides disagree in a way git cannot see. Report it with the failure output and stop. The fix is a code
change, and a code change inside a branch update needs the user to know about it.

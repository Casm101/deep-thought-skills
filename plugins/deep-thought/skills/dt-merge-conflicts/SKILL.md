---
name: dt-merge-conflicts
description: Resolve the conflicts from a git merge, rebase or cherry-pick. Works out which side is which, reads both sides before touching anything, combines changes that are independent, decides the ones that genuinely collide with your own work as the tie-break rather than the rule, calls dt-implement when the reconciliation needs real code, then proves both sides still work before completing the operation. Use when asked for "dt merge conflicts", or to resolve or fix merge conflicts.
---

# dt-merge-conflicts

Two people changed the same lines. Work out what each was doing, then produce the version that keeps
both intentions.

The failure mode is not a broken build, which you would notice. It is a merge that compiles and
silently drops half of what came in.

## Two traps before anything else

**The labels invert.** In a merge, `ours` is your branch and `theirs` is what is coming in. In a
rebase, they swap: `ours` is the upstream you are landing on and `theirs` is your own commit. So
"prefer our changes" means `--ours` during a merge and `--theirs` during a rebase, and getting it
backwards throws away exactly the work you meant to keep. The script in Phase 1 states the mapping
for the operation actually in progress. Read it every time, including when you are sure.

**`--ours` and `--theirs` discard silently.** `git checkout --ours <file>` takes that whole file and
drops every line the other side wrote, with no report of what went. It is the right command
occasionally and the wrong one usually, and it is never right before you have read both sides.

## Phase 1. Map it

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-merge-conflicts/scripts/conflict-map.sh
```

It reports which operation is running, which side is which, every conflicted path with its conflict
kind and hunk count, what kind of file each one is, the tests the incoming side brought, and whether
any markers are still in the tree.

Two lines in that output do most of the work. The **file class** tells you which conflicts are never
resolved by editing text, such as a lockfile. The **incoming tests** list is the specification for
what came in, and it is how you find out later whether you dropped their feature.

Nothing is lost while you think. `git merge --abort`, `git rebase --abort` and `git cherry-pick
--abort` put the tree back exactly as it was.

## Phase 2. Read both sides

Before editing a single hunk, read the three versions of the file. Git keeps them:

```bash
git show :1:path/to/file    # the common ancestor
git show :2:path/to/file    # ours
git show :3:path/to/file    # theirs
```

Then find out what each side was doing, which the diff alone will not tell you:

```bash
git log --oneline HEAD..MERGE_HEAD -- path/to/file     # what came in, and why
git log --oneline MERGE_HEAD..HEAD -- path/to/file     # what you did
```

A conflict is two intentions meeting. You cannot combine intentions you have not read.

## Phase 3. Resolve by type

`references/conflict-types.md` has a playbook per kind of file and per kind of conflict, and
`references/deciding.md` has the decision procedure for source conflicts.

The three shapes worth knowing before you open either:

**Independent changes in the same region.** Both sides edited nearby lines for unrelated reasons. Keep
both. This is the most common conflict and it needs no decision, only care.

**Their shape, your content.** The incoming side renamed something, changed a signature, or moved a
module, and your lines are written against the old form. Adopt their shape and port your change into
it. Preferring your own version here is how a branch ends up calling an API that no longer exists,
and it is the case where "prefer ours" is most wrong.

**The same thing, done differently.** Both sides solved one problem two ways. This is the only shape
that needs a real decision, and it is where the tie-break applies.

## Phase 4. When it needs new code

Sometimes neither side survives intact and the honest resolution is code that exists on neither
branch. Their new parameter has to thread through your new function, their guard clause has to cover
your case too.

That is an implementation task, so run `dt-implement` on it: it puts the tests in first, works in
slices with the checks after each, and reviews the result. A hand-written reconciliation of two
features, with no test proving both still work, is the exact change that looks fine in review and
breaks in production.

Keep it scoped to the reconciliation. A conflict is not a licence to refactor either side.

## Phase 5. Prove both sides still work

A resolved conflict is a claim, and the tests are how you check it.

1. **No markers anywhere.** `grep -rn '^<<<<<<< \|^>>>>>>> \|^=======$' . --exclude-dir=.git`. A
   committed marker is the most embarrassing possible outcome and it is one command to prevent.
2. **The incoming side's tests pass.** The ones the script listed. If any fail, you dropped their
   change. Fix your resolution, not their test.
3. **Your own tests pass.** Same reasoning in reverse.
4. **The type check passes** for every package touched.
5. **The full suite passes** once, at the end.

If a test from either side fails and you cannot see why, that is a stop. Say which test, which side it
came from, and what you tried. Do not delete it, skip it, or adjust its expectation.

## Phase 6. Complete it

Stage the files you resolved, by path, then finish the operation:

```bash
git add path/one path/two
git commit                 # a merge, keeping the default merge message
git rebase --continue      # a rebase
git cherry-pick --continue # a cherry-pick
```

Never `git add -A` here. A conflicted tree usually has other debris in it.

Then report: every file resolved and how, every place the two sides genuinely collided and which way
you went, and anything you deliberately left out of either side.

**Stop and ask instead of finishing** when a decision was a coin toss on behaviour, when the
resolution changes what a user sees and neither side's intent is clearly right, or when either side's
tests will not pass. Those are the cases where being wrong is expensive and asking costs a minute.

Then stop. No push, no force, no amend.

## Never

- Use `--ours` or `--theirs` on a file you have not read both versions of
- Use `-X ours` or `-X theirs` on the merge itself, which applies that discard to every conflict at
  once with no report of what it dropped
- `git reset --hard`, `git checkout --force`, `git clean`, or a stash you did not create. To undo,
  abort the operation
- Commit with a conflict marker in the tree
- Delete a test, skip it, or change its expectation to get a green run
- Resolve a lockfile, a generated file or a snapshot by editing the text
- Push, force push, or amend anything
- Widen the change beyond the reconciliation

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.

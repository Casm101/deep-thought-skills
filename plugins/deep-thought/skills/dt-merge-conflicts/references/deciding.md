# Deciding a source conflict

## Which side is which

| Operation | `ours` / `--ours` / stage `:2` | `theirs` / `--theirs` / stage `:3` |
|---|---|---|
| `git merge` | your branch, `HEAD` | what is coming in, `MERGE_HEAD` |
| `git rebase` | **the upstream you are landing on** | **your own commit being replayed** |
| `git cherry-pick` | your branch, `HEAD` | the commit being picked |
| `git revert` | your branch, `HEAD` | the inverse of the reverted commit |

The rebase row is not a quirk to be aware of, it is a reversal. Verified against git rather than
recalled: rebasing a feature onto main, with both sides having changed one line,
`git checkout --ours` returned main's version and `git checkout --theirs` returned the feature's.

So "prefer our own work" is `--ours` in a merge and `--theirs` in a rebase. Check the operation before
you reason about sides, every time.

## The procedure

**1. Read all three versions.** `git show :1:file` for the ancestor, `:2:` for ours, `:3:` for theirs.
The ancestor is the one people skip and it is what tells you which side actually changed what.

**2. Read the intent.** `git log --oneline HEAD..MERGE_HEAD -- file` for what came in, and the same
reversed for your own. A commit message usually says in one line what a diff takes ten minutes to
imply.

**3. Classify the collision.**

- **Independent.** Different lines, different purposes, they only collided because they are close
  together. Keep both. No decision needed.
- **Shape against content.** One side changed the form, a rename, a signature, a moved module, and the
  other changed the substance. Take the new shape and port the substance into it. Preferring your own
  version here leaves your branch calling something that no longer exists.
- **Same problem, two answers.** The only case that needs a judgement.
- **One side reverted or removed what the other built on.** Neither a merge nor a guess. Find out why
  it went, and if that is not in the commit message, ask.

**4. Apply the tie-break, and only here.** For a genuine same-problem collision where both answers
work, keep yours. Your branch is the change under review, its tests are written against your version,
and the incoming side has already landed somewhere it works.

That is a tie-break, not a rule. It does not apply when:

- Their version is a fix and yours predates it. Take the fix.
- Their version follows a convention the repo documents and yours does not.
- Their change is wider than yours, a refactor across many files, and yours is local. Adopt theirs and
  re-apply your local change inside it, or you will be the one file that did not get refactored.
- Their side has tests and yours does not. Tests are evidence of intent.
- Yours was written before you understood the area and theirs was not. Be honest about this one.

**5. Write the resolution.** Remove every marker, keep both intentions where both survive, and leave
the file as though one person had written it. A resolution that reads like two stitched fragments is
a resolution somebody will have to redo.

**6. When it needs code neither side has**, stop hand-writing it and run `dt-implement` on the
reconciliation. Tests first, slices, checks, review. Reconciling two features by hand with nothing
proving both still work is the change that passes review and fails in production.

## When to stop rather than decide

Being wrong here is expensive and asking is cheap. Stop and put it to the user when:

- Both answers work and they behave differently for a user. That is a product decision.
- The incoming side removed something you depend on and no message says why.
- Resolving it needs knowledge of an area neither side documents.
- Either side's tests fail after your resolution and you cannot see the cause.
- The conflict is in a lockfile, a generated file or a snapshot and regenerating is not available.
- The conflict touches money movement, identity, access control, or a migration. Those get a person.

Say which files you resolved and which you stopped on. A partly resolved merge left in place with a
clear note is a good outcome. A fully resolved merge with one silent guess in it is not.

## Recovery

- **Mangled a file while editing?** `git checkout -m path/to/file` puts the conflict markers back.
- **Lost the thread entirely?** `git merge --abort`, `git rebase --abort`, `git cherry-pick --abort`.
  The tree returns to exactly its previous state. Aborting is not failure, it is the cheapest possible
  reset.
- **Already committed the merge and it is wrong?** Say so and stop. `ORIG_HEAD` still points at where
  you were, but undoing a commit is the user's call, not yours.

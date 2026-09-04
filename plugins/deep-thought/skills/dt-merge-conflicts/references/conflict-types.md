# A playbook per kind of conflict

## By the git status code

| Code | Means | What to do |
|---|---|---|
| `UU` | both modified | The ordinary case. Follow `deciding.md`. |
| `AA` | both added the same path | Two implementations of one thing. Read both, keep one, port anything the other had. Never concatenate them. |
| `UD` | we modified, they deleted | Find out why they deleted it. If it moved, port your change to the new home. If it went for a reason, your change may be obsolete. Never resolve by keeping it silently. |
| `DU` | we deleted, they modified | Same in reverse. Their modification may be built on something you removed on purpose. |
| `DD` | both deleted | Accept the deletion. |
| `AU` / `UA` | one added, one modified | Usually a file that moved on one side. Work out the rename before deciding. |

## By what the file is

### Lockfiles

`pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`, `Cargo.lock`, `poetry.lock`, `Gemfile.lock`.

**Never merge the text.** Take one side, then regenerate from the manifests:

```bash
git checkout --theirs pnpm-lock.yaml   # or --ours, the starting point barely matters
pnpm install --lockfile-only           # whatever this repo uses
git add pnpm-lock.yaml
```

Resolve the `package.json` conflict first, because the lockfile is derived from it. A hand-merged
lockfile installs a dependency set nobody has ever tested.

### Generated files

Anything under `generated/`, `.gen.` names, protobuf or OpenAPI output.

Resolve the **source** the generator reads, then regenerate and stage the result. If the repo says
never to edit generated output, which this monorepo does, that applies to conflicts too.

### Snapshots

`.snap` files come from a test run. Resolve the code first, run the tests, and let the run write them.

Where the snapshot updates because behaviour genuinely changed, that is fine. Where you cannot say why
it changed, stop. A snapshot accepted without understanding is a regression with a green tick next to
it.

### `package.json`

Usually a version bump on both sides plus real changes. Merge the real changes properly, and take one
version. In a repo whose CI checks for exactly one increment, that means taking the higher of the two
and stating what you did.

Dependency lists: keep both sides' additions, and if both added the same package at different
versions, take the higher and let the lockfile regeneration settle it.

### Changelogs

Keep both entries, theirs above yours or in whatever order the file already uses. Never drop an entry
to make the conflict go away, since the entry is the audit trail.

### Tests

The incoming side's tests are the specification for the incoming change. Keep them.

Both sides adding tests to one file is the easiest conflict there is: keep both blocks. Both sides
changing the same test differently means the behaviour is contested, which is a source conflict
wearing a test's clothes, so resolve the source first and the test follows.

### Translation and message files

Keep both keys. A dropped key is a missing string in production, in a language nobody on the team
reads.

### Configuration and CI

Read both carefully and prefer combining. These files are usually a list of things, and a list merge
that drops an entry silently disables a check.

## The wide refactor case

The most common real conflict in an active monorepo, and the one where preferring your own work is
worst.

Main renamed a symbol, changed a signature, moved a module, or migrated a pattern across many files.
Your branch touched a few of those files using the old form. Every one conflicts.

Do this per file: **take their form, re-apply your substance inside it.** At the end, search the whole
branch for the old form to make sure none of your files is the one that got left behind:

```bash
git grep -n 'oldSymbolName'
```

An empty result is the check. If the refactor was large, say in the report that you adopted it and
that your change now uses the new form.

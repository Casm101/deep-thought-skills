---
name: dt-create-branch
description: Create a working branch from the repository's default branch, or from a base you name, using the naming convention the repo documents or, where nothing is documented, the shape its own history uses. Checks the name is free, branches from the fetched remote rather than a stale local copy, and stops there. Use when asked for "dt create branch", or to start a branch for a ticket or piece of work.
---

# dt-create-branch

Start a branch that looks like the branches this repo already has, from an up to date base.

Small skill, two traps. Branching from a stale local `main`, and inventing a naming style the team
does not use.

## Phase 1. Recon

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-create-branch/scripts/branch-recon.sh [<proposed name>]
```

It reports the default branch, how far your local copy of it has drifted from the remote, uncommitted
changes that will come along with you, any documented naming convention it can find, the prefixes
real branches actually use with counts, the most recently updated branches as examples, the ticket
key prefixes in use, and whether the name you proposed is free.

## Phase 2. Work out the name

**What the repo documents wins.** The recon greps `CONTRIBUTING`, `CONVENTIONS`, `CLAUDE`, `AGENTS`,
`README` and any release or branching doc for a stated convention. If it found one, follow it exactly,
including the separator and the case.

**Otherwise the history decides.** Take the prefix counts and the recent examples. A repo with 227
`feature/` and 86 `bugfix/` branches has a convention whether or not anyone wrote it down.

Then build the name from what you have:

- The prefix that matches the work. A fix takes the fix prefix, new behaviour takes the feature one.
  Where the repo has a `hotfix/`, `rcfix/` or `release/` prefix, those are for release work and are
  not yours to pick without being told.
- The ticket key, in the case the examples use, with the prefix the recon says is most common.
- A short slug of the work, lower case, hyphenated, a few words. Long enough to recognise in a list
  of forty branches, short enough to read.

No ticket key available, no problem, as long as the repo has branches without one. If every branch in
the history carries a key and you have none, say so and ask rather than inventing a format.

Say the name you are about to use before you use it. Renaming is cheap now, `git branch -m`, and
awkward later once the name is in a PR URL and a preview URL.

## Phase 3. Create it

```bash
git fetch origin
git switch -c <name> origin/<default> --no-track
```

Three parts, all deliberate.

**Fetch first.** The recon usually shows the local default branch hundreds of commits behind. Branch
from that and you start with old code and a painful merge later.

**Branch from `origin/<default>`**, not from the local one, for the same reason.

**`--no-track`**, so the new branch does not treat the default branch as its upstream. Without it
`git push` has to be told where to go every time, and `dt-ship` sets the correct upstream when it
pushes.

Where the user named a different base, use that instead, and say which base you used.

## Phase 4. Confirm and stop

```bash
git status -sb
```

Report the branch, the base it came from, and whether any uncommitted changes travelled with you.

Then stop. This skill creates a branch, nothing else. No commits, no pushes, no PR.

## Never

- **Never create a branch whose name already exists**, locally or on origin. The recon checks both.
  If it is taken, say so and propose another.
- **Never switch branches with uncommitted changes you have not mentioned.** They come with you, and
  that is usually fine, but the user should hear it from you rather than notice later.
- **Never `git checkout -f`, `git reset --hard`, `git stash` or `git clean`** to tidy the tree first.
  If the tree is in the way, say what is in it and let the user decide.
- **Never delete or move an existing branch.**
- **Never branch off the branch you happen to be on** because it is convenient. The base is the
  default branch, or the one you were given, and nothing else without saying so.

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.

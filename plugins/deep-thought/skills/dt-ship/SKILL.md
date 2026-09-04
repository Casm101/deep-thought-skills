---
name: dt-ship
description: Push the current branch and open its pull request. Runs a preflight over the branch, the base, the working tree, the remote and any PR that already exists, pushes, opens the PR against the right base with the repo's own template, then hands the description to dt-pr-data to fill in. Stops short of merging, and never force pushes. Use when asked for "dt ship", or to push the branch and open a PR.
---

# dt-ship

Get the work off this machine and in front of reviewers. Push the branch, open the PR, hand the
description over.

This is the most outward-facing thing the family does. A push is visible to everyone and a PR
notifies people, so the preflight matters more than the two commands that follow it.

## Hard rules

- **Never force push.** Not `--force`, not `--force-with-lease`, not on a branch you think is yours.
  If the remote has commits you do not, stop and ask.
- **Never push the default branch**, and never push a branch you did not just work on.
- **Never open a second PR** for a branch that already has one open. Push and use the one that exists.
- **Never merge, rebase, reset, or switch branches.** Shipping ends at an open PR.
- **Never `--no-verify`.** Pre-push hooks are the team's gate.
- **Never add reviewers, labels, assignees, or a milestone** unless asked. Most repos assign those by
  CODEOWNERS or automation, and guessing creates noise for real people.

## Phase 1. Preflight

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-ship/scripts/ship-preflight.sh [<base ref>]
```

It reports the branch and the base, how many commits are ahead, uncommitted changes to tracked files,
untracked files, how many commits are genuinely unpushed and whether the remote is ahead of you, any
PR that already exists for this branch, the ticket key in the branch name, how the repo titles its
merged PRs, the PR template path, and the branching or release docs worth reading before picking a
base.

It ends in `RESULT: clear` or `RESULT: blocked`. Blocked means fix that first. The usual causes are
being on the default branch, having nothing committed, or having uncommitted changes that belong in
the PR.

## Phase 2. Decide whether to just go

**Go ahead without asking** when all of this holds: the preflight is clear, the base is the repo
default, no PR exists yet, the remote is not ahead, and nobody said anything about a draft. That is
the ordinary case, and asking would only add a round trip to something already asked for.

**Stop and ask** when any of these is true:

- The base is not the repo default. Check the release branching docs the preflight listed, then
  confirm the base before anything is pushed. A PR against the wrong base is noisy to fix.
- A PR already exists. Push, then say which PR it is and hand over to `dt-pr-data`.
- The remote has commits you do not have. Never resolve this by force.
- The working tree has uncommitted changes to tracked files. Say what they are and let the user
  decide whether they belong in this PR.
- CI is already failing on this branch, or the last local suite run was red. Ask whether to ship as a
  draft.

## Phase 3. Push

```bash
git push -u origin <branch>      # first time, sets upstream
git push                         # afterwards
```

If a pre-push hook rejects it, read what it said and fix that. Do not work around it.

Report what went up: the branch, and the number of its own commits that were new.

## Phase 4. Open the PR

Follow `references/opening-the-pr.md` for the commands, the title rules and how the template gets
used. In short: title in the repo's own style with the ticket key, base explicitly named, body seeded
from the repo's PR template, and no draft flag unless it was asked for or CI is red.

Then, straight away, run `dt-pr-data` on the new PR to fill the description in. This skill opens the
PR with the template still empty on purpose. `dt-pr-data` reads the diff, the commits and the ticket
and writes the fields properly, which is a job it already does well.

## Phase 4b. Memory

Persistent memory lives at the repository named in `~/.config/dtm/repos`. The canonical
instructions are the `dt-memory` skill; this phase is the trigger, not a second copy of them.

Run the four end-of-work questions in `dt-memory` §4. **Most runs
answer no to all four, and that is the correct outcome.** Do not manufacture a memory to have
written one, and do not write one for work that only touched files.

The one this workflow is uniquely placed to catch is the **decision**: at PR time you know
what was chosen and what was rejected, and nobody knows it later. If this change picked one
approach over a real alternative, that is a `decision` memory and nothing else will record it.

```sh
DT_MEMORY="${DT_MEMORY:-$(head -1 ~/.config/dtm/repos)}"
"$DT_MEMORY/bin/dtm" find "<the problem this solved>"   # it may already exist, edit it
"$DT_MEMORY/bin/dtm" new decision work/<subject> "<title>"
```

Never write a credential value, a transcript, or a narration of what you did. Commit the
memory yourself; `dtm` never commits.

## Phase 5. Report and stop

Give back the PR URL, the base it targets, and the command to watch the checks:

```bash
gh pr checks <number> --watch
```

Do not sit and wait for CI. Say what the checks looked like at the moment of opening, if they had
started, and leave the watching to whoever asked.

Then stop. No merging, no nudging reviewers, no follow-up comments. If review feedback arrives later,
that is `dt-pr-defense`.

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.

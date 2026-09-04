---
name: dt-inherit-branch
description: Pick up a branch somebody else was working on, and carry on as if you had started it. Reads the branch, its commits, its diff, any handoff document, the stashes, the open PR with its unresolved review threads and CI state, and the ticket, then runs the checks to find out whether it is green, works out how complete the task is against its acceptance criteria, saves the parts nobody could reconstruct to memory, and hands back a briefing. Use when asked for "dt inherit branch", or to pick up, take over, or resume work on an existing branch.
argument-hint: "branch to pick up, or nothing for the current one"
---

# dt-inherit-branch

Take over a branch and know what you are holding.

The failure mode this exists to prevent is carrying on confidently from a partial reading: rewriting
something the last session already tried and rejected, missing two review comments waiting on the PR,
or not noticing the branch has been red for a day.

This is the reading end of `dt-handoff`. That skill writes for whoever comes next; this one is
whoever came next.

## What it touches

**Read-only on the repository.** It reads, and it runs the project's own type check and tests, because
whether the branch is currently green is the single most useful fact about it. It fixes nothing, edits
nothing, commits nothing.

**One write, outside the repo.** A memory file holding what a later session could not reconstruct. See
Phase 6.

## Phase 0. Memory

Before reading any code, check whether this has been looked at before. One pass, not a ritual:

```sh
DT_MEMORY="${DT_MEMORY:-$(head -1 ~/.config/dtm/repos)}"
"$DT_MEMORY/bin/dtm" find "<the subsystem or symptom>"
```

If nothing comes back, say so and carry on. The absence rule in
the `dt-memory` skill applies before you conclude there is nothing. If something does, read the state document
(`README.md`) for how it works now and the dated files for why. That is context you would
otherwise re-derive, and a past `failure` memory is the cheapest thing you will read today.


## Phase 1. Recon

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-inherit-branch/scripts/inherit-recon.sh [<branch>]
```

Read-only, checks nothing out. It reports the branch's position against the default branch, its own
commits in order, the diff stat, the test files it touched, any `TODO` or `.only` it left behind,
uncommitted and untracked files, the stashes with what is in them and which branch each was made on,
any handoff document in `TMPDIR` or `.claude/`, and the PR with its unresolved review threads and CI
state.

If you named a branch that is not checked out, check it out now and stay on it. Inheriting means you
intend to work here. A clean tree is required first, and a dirty one is a refusal rather than
something to stash.

## Phase 2. Read what nobody can reconstruct

In this order, because the earlier ones save you reading the later ones.

**The handoff document, if there is one.** It exists precisely to hold the things not derivable from
the code, so read it in full before forming any view.

**The unresolved review threads.** Somebody has already reviewed this and is waiting. These are the
most actionable thing on the branch and the easiest to miss, because a PR page looks calm when its
threads are collapsed.

**The ticket**, if the branch names one:

```
atlassian-mcp / getJiraIssue
  issueIdOrKey: <KEY>
  fields: ["summary","description","status","issuetype","labels","comment"]
  responseContentFormat: markdown
```

Read the comments. Scope gets cut there.

**The commit messages, in order.** A well-written series tells you what the last session was thinking,
including where it changed its mind. A commit that says "address review" or "revert the earlier
approach" is a decision you should not undo by accident.

**The stashes**, judged by which branch each was made on. A stash from another branch is almost
certainly not yours to worry about; say so and move on rather than investigating all of them.

## Phase 3. Read the change

Read the diff properly, and read the files it touches, not only the hunks.

Run `dt-investigation` only when the change leans on code the diff does not show. A branch in progress
usually explains itself, and a full investigation every time is expensive and mostly redundant.

## Phase 4. Find out whether it is green

Run the type check for the packages the branch touched, and the tests for the files it touched.

This is the phase people skip and then regret. "Inherited a working branch" and "inherited a broken
branch" are different jobs, and finding out by accident an hour later costs more than the few minutes
here.

Report exactly what you ran and what it said. If the suite was already red before you touched
anything, that is a finding about the inheritance, not a problem for you to fix silently.

## Phase 5. Work out how complete it is

Not a feeling. A line per acceptance criterion, evidenced.

Take the criteria from the ticket, or from the PR description where there is no ticket. For each one,
say **done**, **partial**, **not started**, or **unknown**, and what the evidence is: a test that
covers it, a diff that implements it, or nothing found.

`references/briefing.md` has the format. Two rules that keep it honest. A criterion with no test
covering it is at best partial, never done. And **unknown** is a real answer, better than a guess, when
the criterion is about behaviour you cannot check from here.

## Phase 6. Save what would otherwise be lost

Write one memory file for this branch, and only the parts a later session could not work out for
itself.

**In:** the task in a sentence, the completion state, decisions the branch made and why, approaches it
tried and abandoned, what the stashes are, where the handoff document was, and any environment trap you
hit.

**Out:** the diff, the file list, the commit log, the PR number. All of that is one git command away,
and a memory that duplicates the repository goes stale while the repository stays true.

If a memory for this branch already exists, update it rather than adding a second. When the branch
merges, the memory is stale and should go.

## Phase 7. Brief the session

Write the briefing in the shape `references/briefing.md` sets out, which mirrors `dt-handoff`'s
sections so the two read as one document from opposite ends.

Run `dt-unslop` over it before returning it. Leave paths, identifiers, quoted review comments and
command output alone.

End with the recommended next step, named as a skill and not started:

| What the recon found | What comes next |
|---|---|
| Unresolved review threads | `dt-pr-defense` |
| Behind the default branch | `dt-branch-update` |
| Stopped mid-merge or mid-rebase | `dt-merge-conflicts` |
| Criteria still outstanding | `dt-implement` |
| Green, complete, nothing waiting | `dt-ship`, or nothing at all |

Name one, say why, and stop. Picking it up automatically would mean acting on an inheritance the user
has not agreed with yet.

## Never

- Fix anything you find. Report it
- Commit, push, stash, or discard anything
- Undo a decision the branch already made without saying you are doing it
- Claim a criterion is done because the code looks like it should work
- Skip Phase 4 because the branch looks tidy
- Write the diff or the commit log into memory
- Start the next skill on your own

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.

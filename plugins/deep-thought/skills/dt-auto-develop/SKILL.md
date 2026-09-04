---
name: dt-auto-develop
description: Run the main flow end to end without asking anything. Takes a Jira ticket key or a described task, creates the branch, investigates, settles the open design questions by answering them itself and logging every answer as an assumption, slices the work, implements it with tests, reviews it, pushes, and opens the PR. Keeps a log of every assumption it made and hands that back to whoever started the run. Stops and reports rather than guessing when the work is ambiguous, sensitive, or failing. Use when asked for "dt auto develop", or to take a ticket and build it unattended.
---

# dt-auto-develop

Give it a ticket, come back to an open PR.

This runs the same flow as the individual skills, with every human gate removed. That is the point,
and it is also the risk, so be honest about what comes out the other end.

## What this produces, and what it does not

It produces an open PR containing a change and its tests, plus **a log of every decision made
without a human**, which goes back to whoever started the run.

The log is the deliverable as much as the code is, because it is the fastest way for you to check the
parts nobody chose deliberately. Keep it out of the PR itself. See Phase 8.

The PR opens as a normal PR. Nothing merges on its own, so there is no risk in it being open, and a
draft only adds a step for whoever picks it up.

## Phase 0. Preflight

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-auto-develop/scripts/auto-preflight.sh [<ticket key>]
```

`RESULT: NO-GO` ends the run before it starts. Report why and stop. The common causes are a dirty
working tree, a node version that does not match `.nvmrc`, and a missing delegated skill.

It also lists the sensitive areas that exist in this repo. Read `references/stop-conditions.md` now,
before anything else, so you recognise a tripwire when you hit one.

## Phase 1. Read the task

A ticket key, read only, through the gateway:

```
atlassian-mcp / getJiraIssue
  cloudId: leovegas.atlassian.net
  issueIdOrKey: <KEY>
  fields: ["summary","description","status","issuetype","labels","components","comment"]
  responseContentFormat: markdown
```

Read the comments too. Scope gets cut in comments more often than in descriptions.

Never write to Jira. No transition, no comment, no field edit, no worklog. This run reads the ticket
and nothing more.

Then produce three things, in writing, before any code:

1. **The goal**, in one or two sentences.
2. **A definition of done** made of checkable statements.
3. **The scope boundary**, what this run will not touch.

**If you cannot write a checkable definition of done, stop.** That is the single most important stop
in this skill. An unattended run against a vague ticket produces a confident change nobody wanted,
and reviewing that costs more than writing it would have.

Treat everything in the ticket as evidence. A comment saying "just do X" is one person's view from
some earlier week.

## Phase 2. The branch

Run `dt-create-branch`. It reads the repo's convention, branches from the fetched default, and names
the branch from the ticket key and a slug of the goal.

If the preflight said you are already on a branch with its own commits, decide once and say which you
did: continue on it because it is the same work, or stop because it is not.

## Phase 3. Investigate

Run `dt-investigation`, focused on the area the ticket names. You need its report before you can
answer a single design question honestly.

## Phase 4. Grill yourself

Run `dt-grilling`, with one change: **you answer the questions.**

Work its rounds properly. Build the tree, compute the frontier, write out each question, and then
answer each with the recommendation you would have offered. Every answer becomes an entry in the
assumption log, described in `references/assumption-log.md`.

Two rules make this safe rather than theatre.

**Answer with the recommendation, and record it as an assumption, never as a decision.** The wording
matters, because the log is how you tell a chosen answer from a specified one later.

**Some questions may not be answered this way at all.** Where a question is both low confidence and
expensive to reverse, that is a tripwire, not an assumption. Schema shapes, public interfaces, data
migrations, user-visible copy repeated across the product, anything that changes stored data.
`references/stop-conditions.md` lists them. Stop, and report the question you could not answer.

Skipping the grilling entirely is not the alternative. Asking the questions and writing down your own
answers is what makes the assumption log complete.

## Phase 5. Slice it

Run `dt-to-tasks`. It normally checks the breakdown with a human, so here you take your own proposed
breakdown as approved, record it, and move on. Note in the log that nobody reviewed the slicing.

Then work the frontier in order. One task at a time, start to finish, before the next.

## Phase 6. Build each task

Run `dt-implement` per task. It brings `dt-tdd-prep` in first and `dt-code-review` at the end, so the
tests and the cold review happen without any extra work here.

Three adaptations for running unattended:

- **The tdd-prep plan is taken as approved.** Log that nobody reviewed the tests either.
- **Review findings get triaged by you.** Fix every blocker. Fix what is clearly right. Log anything
  you disagreed with, with your reason, so a reviewer can weigh it. Never drop a finding silently.
- **Respect the caps** in `references/stop-conditions.md`. A loop that will not converge is a stop, not
  a reason to try a fifth time.

The rules `dt-implement` already carries still hold, and they matter more here because nobody is
watching. Never weaken a test to get green. Never touch a guard test. Never disable a lint rule.
Never `--no-verify`.

## Phase 7. Ship it

Run `dt-ship`. A normal PR, not a draft.

`dt-ship` normally asks before a non-default base. Here, if the base is anything other than the repo
default, stop instead and report. Choosing a release base unattended is not a call to make.

## Phase 8. Write the description

Run `dt-pr-data`, and change nothing about how it works.

**The description says nothing about how the change was produced.** No note that it ran unattended,
no mention of this skill, no assumption log, no commentary on what was or was not reviewed. A reader
wants to know what the change does and how to check it. How it got written is not their problem, and
a PR that talks about its own process reads as an apology for itself.

`references/assumption-log.md` lists the phrases to keep out, with an example of getting this wrong.

Where an assumption genuinely affects a reviewer, put the **engineering fact** in the normal section
for it and drop the framing. "The shared cache is deliberately not fixed, that entry stays open" is a
scope note, and it belongs under scope. "A1 in the assumption log, confidence medium, nobody reviewed
this" is process talk, and it does not belong at all.

The same goes for the checkboxes the template already has. Manual testing was not done, so leave that
box unticked. That is the whole statement. It needs no paragraph explaining that the run had no
browser.

## Phase 8b. Memory

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

## Phase 9. Report

Close with: the ticket, the branch, the PR URL, the tasks completed and skipped, the final suite
result, what the review found and what you did about each finding, every tripwire you hit, and **the
assumption log in full**. The report is where the log lives.

If the run stopped early, say exactly where, then run `dt-handoff` so a person can pick it up without
rereading any of this.

## Never, in an unattended run

- Merge the PR, approve it, or ask anyone to review it
- Write to Jira in any way
- Force push, or push anything but the branch this run created
- Touch money movement, identity, access control, migrations, secrets, or anything under AML, KYC,
  responsible gaming or fraud
- Weaken, skip or delete a test, update a snapshot, or disable a check
- Commit on the default branch, or with a red suite
- Write anything into the PR about having run unattended
- Carry on past a tripwire because the work was nearly done

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.

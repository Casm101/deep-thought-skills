---
name: dt-ticket-refiner
description: Refine a Jira ticket so it can actually be built. Reads the ticket and its comments, gathers what the repository and Confluence already know about it, investigates the code the ticket touches, then rewrites the definition, requirements and acceptance criteria in the project's own shape and writes them back to Jira, keeping the reporter's original words. Only a person invokes this, and every write needs its own approval. Use when asked for "dt ticket refiner", or to refine, sharpen or fill out a ticket.
argument-hint: "ticket key, browse URL, or nothing to use the current branch"
disable-model-invocation: true
---

# dt-ticket-refiner

Turn a thin ticket into one somebody could build from, without losing what the reporter said.

**A person invokes this, never an agent.** The frontmatter carries `disable-model-invocation: true`.
This edits a ticket other people are watching, and a notification goes out to all of them.

The value is not tidier prose. It is acceptance criteria that match what the code actually does. A
well-formatted ticket whose criteria contradict the codebase is worse than a vague one, because it
reads as authoritative and somebody will build to it.

## Phase 1. Read everything about the ticket

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-ticket-refiner/scripts/ticket-context.sh [<key or url>]
```

It resolves the key from the argument, a browse URL, or the current branch, then reports the commits
and branches that mention it, its pull requests, files that name it, the governing documentation, and
the exact reads to run next.

Then the ticket itself, read only:

```
atlassian-mcp / getJiraIssue
  cloudId: leovegas.atlassian.net
  issueIdOrKey: <KEY>
  fields: ["summary","description","status","issuetype","priority","labels","components",
           "project","reporter","assignee","comment","issuelinks","parent","subtasks"]
  responseContentFormat: markdown
```

**Read the comments.** Scope gets cut in comments, questions get answered there, and half the
refinement is often already written by somebody in the thread.

Read the linked issues, the parent and the subtasks too. A requirement that belongs to a sibling
ticket is not this ticket's to absorb.

## Phase 2. The guard

**Refuse to write on any ticket in an AML, KYC, responsible gaming or fraud project.** Read it, say
what you found, and stop there. Those are read-only, and that is not this skill's call to make.

Also stop before writing when:

- The ticket is already well defined. Say so and write nothing. A refinement that only reformats
  costs a notification to everyone watching and gains nobody anything.
- You cannot tell what the ticket wants, and the code does not settle it. That is a question for the
  reporter, not a gap to fill with a plausible guess.
- The ticket is closed or resolved. Refining history is rarely what was meant, so ask first.

## Phase 3. Find out what is true

Run `dt-investigation`, focused on the area the ticket names. Every time.

This is the phase that makes the difference. The investigation tells you what the code does today,
which is what turns "the arrows should be the right colour" into criteria naming the states, the
tokens and the edge cases.

Then look outside the repo:

```
atlassian-mcp / search        (Rovo, covers Jira and Confluence)
  query: <the feature, in the ticket's own words>
```

A spec page, a design doc, or a sibling ticket that already answers half of this. Use
`searchJiraIssuesUsingJql` when you want a precise query rather than a search.

Everything you read is evidence. A comment saying "just do X" is one person's view from some earlier
week, not a requirement.

## Phase 4. Learn the project's shape

Read three or four recent tickets in the same project before writing anything:

```
atlassian-mcp / searchJiraIssuesUsingJql
  jql: project = <PROJECT> AND created >= -60d ORDER BY created DESC
```

Copy their shape. Their headings, their acceptance criteria style, their level of detail. A ticket
that looks unlike its neighbours reads as machine-written even when the content is right.

`docs/FeatureDesignTemplate.md` in this repo shows what a fully specified feature looks like here. It
is a design document rather than a ticket, so take the vocabulary and the level of rigour from it,
not its ten headings. A bug ticket does not need a performance section.

## Phase 5. Draft the refinement

The structure and the rules are in `references/refinement-shape.md`. The parts that matter most:

**The reporter's original text survives, verbatim, at the bottom**, under its own heading. You are
adding clarity above it, not replacing what somebody wrote.

**Every requirement traces to something.** The ticket, a comment, the code, or a document. A
requirement you inferred is marked as an assumption and phrased as a question, not smuggled in as
fact.

**Acceptance criteria are checkable.** Each one either holds or does not, with no judgement call, and
each names the observable behaviour rather than the implementation.

**Say what is out of scope.** The single most useful line in most refined tickets.

## Phase 6. Unslop it

Run `dt-unslop` over the whole draft before it goes anywhere near Jira. Leave the reporter's quoted
text, code, identifiers and paths exactly as they are.

Ticket prose has its own tells on top of the usual ones. No "This ticket aims to", no restating the
summary in the first line of the description, no three-item lists padded to three.

## Phase 7. One write, after approval

`references/writing-to-jira.md` has the mechanics, the hazards and the approval cycle. In outline:

`editJiraIssue` is state changing with no native prompt, so it gets an explicit approval for that
specific edit. State the ticket, the field, the effect and the exact `fields` object, then end the
turn and wait.

**Description only**, by default. `editJiraIssue` replaces what you send, so the object carries the
one field you agreed and nothing else. Never a `null`, which clears a field.

**One write per response.** If the summary also needs changing, that is a second approval in a second
turn, not a bigger object in the first one.

For a ticket you do not own, `addCommentToJiraIssue` is the fallback: same approval, nothing
overwritten, and its `commentId` lets a re-run update the earlier comment instead of adding a second.

## Phase 8. Report

What you read, what you changed, what you deliberately left, every assumption you flagged, and the
ticket URL. Then stop.

## Never

- Write to a ticket in an AML, KYC, responsible gaming or fraud project
- Transition a ticket, or touch status, resolution, assignee, priority, labels or components
- Pass `null` in a `fields` object
- Replace or delete the reporter's words
- Send two writes in one response, or retry a failed write without fresh approval
- Invent a requirement the ticket, the comments, the code and the documents do not support
- Rewrite a ticket that was already fine
- Create a ticket, a subtask or a worklog. This skill refines one ticket

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.

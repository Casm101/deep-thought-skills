# Writing back to Jira

One write. After approval. Description only unless something else was explicitly agreed.

## The approval cycle, and why it is per write

`editJiraIssue` and `addCommentToJiraIssue` both report `stateChanging: true` with
`nativePromptAvailable: false`. So the gateway will not prompt for you, and each write gets an
explicit cycle:

1. State the backend, the tool, the ticket, the field, the effect, and the exact arguments.
2. End the turn.
3. Call it only after approval of that specific write.

**One write call per response.** Two fields to change is two approvals in two turns. A single
instruction like "refine it and fix the summary" is one instruction, not two approvals, and identical
or templated writes are not an exception.

A failed write gets reported and stopped, never retried. A retry is a new write and needs its own
approval, because a failure and a failure-after-it-landed look the same from here. Read the ticket
back before assuming anything.

## The hazards of editJiraIssue

**It replaces the field you send.** There is no append. The `description` you pass becomes the whole
description, which is why the reporter's original text has to be inside your new body. Read the
current description immediately before writing, and make sure your body contains it.

**An explicit `null` clears a field.** Never send one. Not to tidy up, not to remove a stale value.

**Only send the field you agreed.** A `fields` object with three keys when one was approved is three
writes wearing one coat.

```
atlassian-mcp / editJiraIssue
  cloudId: leovegas.atlassian.net
  issueIdOrKey: TS-42830
  contentFormat: markdown
  fields:
    description: |
      <the full refined body, including the verbatim original at the bottom>
```

`contentFormat: markdown` unless the ticket needs formatting markdown cannot express, in which case
`adf` and full fidelity.

## The comment fallback

For a ticket somebody else owns, or when the description edit is refused:

```
atlassian-mcp / addCommentToJiraIssue
  cloudId: leovegas.atlassian.net
  issueIdOrKey: TS-42830
  contentFormat: markdown
  commentBody: |
    <the refined definition, requirements and criteria>
```

Nothing is overwritten, and the reporter keeps their description. The cost is that a comment gets
buried, so this is the fallback rather than the default.

**A re-run updates its own comment** rather than adding a second. Pass the `commentId` of the earlier
one. Two refinement comments on one ticket is noise, and the second makes the first look wrong.

## Never touched, whatever the refinement says

- `status` and `resolution`. Transitioning is not this skill's job, and in AML, KYC, responsible
  gaming and fraud projects it is forbidden outright
- `assignee`, `priority`, `labels`, `components`, `duedate`, story points
- `summary`, unless it is actively misleading, and then as its own approval in its own turn
- Anything on a parent, a subtask or a linked issue. One ticket per run
- Worklogs, attachments, and anyone else's comments

## The project guard

Read `project` from the ticket before drafting anything. If its key or name touches AML, KYC,
responsible gaming or fraud, the ticket is read-only: report what you found and write nothing.

This is a rule about the domain, not the wording. A ticket in a general project that changes
responsible-gaming behaviour is the same answer.

## After the write

Read the ticket back:

```
atlassian-mcp / getJiraIssue
  issueIdOrKey: <KEY>
  fields: ["summary","description","updated"]
  responseContentFormat: markdown
```

Confirm the description is what you sent, that the original text is still in it, and that nothing else
moved. Then give the user the ticket URL and stop.

If the read-back shows something you did not intend, say so immediately and plainly. The previous
description is in the ticket's edit history, and restoring it is another write needing its own
approval.

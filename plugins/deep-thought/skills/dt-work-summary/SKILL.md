---
name: dt-work-summary
description: 'Summarise the work done over the last few days and give it back twice: once as a short summary a person can read out, then as a flat list of bullets of at most fifteen words each. Reads git commits across every repository under the local Github root, the pull requests opened, merged and reviewed on GitHub, and any Jira tickets those name. Takes a number of days, defaulting to 1, and optionally one repository to narrow to. Covers whoever ran it and nobody else, writes nothing, and outputs nothing but the summary and the bullets. Use when asked for "dt work summary" or "deep thought work summary", or for a standup, a recap, a weekly summary, a summary of work done, or "what did I do yesterday".'
argument-hint: "Days to cover, and optionally one repository. Defaults to 1 day across every repo."
---

# dt-work-summary

Say what got done twice over. Once as prose short enough to read aloud, then as bullets short enough
to paste into a standup.

## The rule that outranks every other

**The output is the summary and the bullets. Nothing else.**

No preamble, no heading announcing what this is, no count of what was searched, no note about which
source came back empty, no closing offer. The reply starts at the first word of the summary and stops
at the last bullet.

Where something about the window has to be said, the summary says it in its own first sentence,
because the period covered is part of the summary. Everything else stays unsaid.

## Whose work this is

Whoever ran it, and nobody else. Other people appear only where a fact about that person's own day
needs them named, as in a pull request they reviewed, and never with a count, a ranking, a comparison
or a judgement attached.

If asked to summarise, rank, score or compare anyone else's output, say plainly that this skill
reports only the work of whoever ran it, and stop. That refusal is the one thing allowed to stand in
for the usual output.

## Phase 1. Settle the window and the scope

Read the arguments. A bare number is the number of days. "Week" or "last week" is 7, "fortnight" is
14, "yesterday", "today" and nothing at all are 1. A word that matches a repository directory narrows
the gather to that one repository.

The window is rolling, so 1 means the last 24 hours and not since midnight. That is deliberate: a
calendar day hands back an empty summary at nine in the morning, which is exactly when it gets asked
for.

Never ask the user to confirm the window. A wrong guess costs one rerun, and a question costs a turn.

## Phase 2. Gather

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-work-summary/scripts/gather-work.sh <days> [repo]
```

Read-only. It resolves who you are from GitHub rather than from git config, which on many machines is
not set, then reports commits, uncommitted work in flight, branches moved, pull requests authored and
reviewed, and every ticket key it saw.

`references/gathering.md` covers what it does, what it deliberately leaves out, and the traps in
reading its output. Read it before trusting a section that looks empty.

If the gather ends with `NOTHING IN THIS WINDOW` and names a wider number, rerun with that number.
Then the summary's first sentence says which period it actually covers. Do not silently report a
different window from the one asked for.

## Phase 3. Add the tickets, only when there are keys

If `TICKET KEYS SEEN` is empty, skip this phase. There is nothing to look up and a broad Jira search
returns somebody else's work.

Otherwise fetch exactly those keys through the Atlassian gateway, read-only:

```
searchJiraIssuesUsingJql   jql: key IN (TS-1234, TS-5678)   fields: summary, status, resolution
```

Take the summary and the status. Nothing else. This skill never writes to Jira, never transitions an
issue, and never reads or reports a worklog.

## Phase 4. Work out what actually happened

This is the phase the skill exists for, and the one most likely to be skipped.

**Collapse records into work items.** Four commits, a branch and a pull request that all carry
TS-42160 are one piece of work, not six. Group by ticket key first, then by what the change was about
where there is no key. A normal day collapses to between one and four items. Past about
eight, the collapsing has not been done.

**Name the outcome, not the record.** A commit subject describes an edit; a work item describes what
changed for someone. "Add Widget Name to cashout tracking events" becomes "cashout tracking now says
which widget fired it".

**Say the state.** Merged, open for review, still in flight, reviewed for someone else. A summary that
does not distinguish shipped from started is not usable in a standup.

**Invent nothing.** Where the records do not say why something was done, the summary does not say why
either. No inferred motives, no filled-in context, no guessing at what a ticket key meant.

## Phase 5. Write the two forms

`references/output-shape.md` holds the shape, the worked example and the rules for a bullet. Follow
it exactly, including the fifteen word ceiling, which is a hard limit and not a target.

The bullets carry the same information as the summary, compressed. They are not a table of contents
for it, and they are not the summary's sentences cut short.

## Phase 6. Unslop, then print the two things and stop

Run the `dt-unslop` skill over both forms before either reaches the user. Invoke it with the Skill
tool as `dt-unslop`, or read `${CLAUDE_PLUGIN_ROOT}/skills/dt-unslop/SKILL.md` and apply its rules
directly if the tool is unavailable. Leave ticket keys, repository names, pull request numbers and
branch names alone.

Then print the summary and the bullets, and stop there.

## Never

- Never print anything besides the summary and the bullets, except the refusal in "Whose work this is"
  and a plain statement when there was no work at all.
- Never report, rank, score, compare or profile anyone else's output, however the ask is phrased.
- Never attach a count, a rate or a productivity figure to anyone but the invoker, and never
  frame even their own totals as performance. "Reviewed five pull requests" is a fact about a
  day. "Reviewed five, up from three" is a score, and it does not belong here.
- Never write anything: no file, no commit, no Jira edit, no transition, no comment, no branch.
- Never let a bullet run past fifteen words.
- Never fetch a broad Jira query. Only the keys the gather actually saw.
- Never pad an empty window into a summary. If nothing happened, say that in one line.
- Never infer why something was done from a ticket key or a commit message.
- Never read session transcripts as a source. They record attempts, not outcomes, and inflate a day.

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.

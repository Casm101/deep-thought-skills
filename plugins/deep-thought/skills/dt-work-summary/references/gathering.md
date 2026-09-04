# Reading the gather, and the traps in it

## What the script covers

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-work-summary/scripts/gather-work.sh <days> [repo]
```

Every repository found by `find <root> -maxdepth 3 -name .git`, where the root is `DT_WORK_ROOT` or
`~/Documents/Github`. Depth 3 is what reaches a repository nested one directory below the root, which
is how several of these are laid out. Set `DT_WORK_ROOT` on a machine that keeps them elsewhere.

Six sections: commits, uncommitted work in flight, branches moved without a commit of their own,
pull requests authored, pull requests reviewed, and the ticket keys seen anywhere in the above.

## The traps

**There may be no git identity anywhere.** No `user.name`, no `user.email`, global or per repository,
and commits still land, authored by whatever the client supplied. So the script takes the identity
from `gh api user` and adds git config only if it has something. Never filter on `git config
user.email` alone.

**One person, several author lines.** The same person commits as a work email in one repository and
as a GitHub noreply address in another. `git log` ORs multiple `--author` patterns, so all the known
identities go in at once. A summary missing a whole repository is usually this.

**`--since` filters on commit date, not author date.** A rebase or a squash merge rewrites commit
dates, so work written last week can appear inside a one day window. Where a commit date and its
content disagree, trust the content and say when it was actually done.

**Reviews include your own pull requests.** GitHub counts reviewing your own, so `--reviewed-by=@me`
returns them. The script subtracts the authored set. Without that the same work appears twice under
two headings and the day looks twice as large.

**The default branch shows as moved.** A `git pull` moves `main`, which is not work. The branch
section excludes the default branch names and keeps only branches whose tip is yours.

**Merges are excluded on purpose.** `--no-merges` is there so bringing a branch up to date does not
read as a day's output. A merge that resolved real conflicts is work, and it will not appear. Add it
from what is known rather than dropping `--no-merges`.

**An empty section is not always an empty day.** Uncommitted work in flight is real work. So is a
review with no commit behind it. Read every section before concluding nothing happened.

## Widening

The script prints `NOTHING IN THIS WINDOW` and, where it can find the last commit, the number of days
that would reach it. Rerun with that number rather than reporting an empty day, and let the summary's
first sentence name the period it actually covers.

It cannot see work that left no git or GitHub trace. Where the window looks emptier than the day felt,
that is the reason, and the honest thing is to report what the records hold.

## Jira, only for keys already seen

Only the keys the gather printed, and only through the read path:

```
searchJiraIssuesUsingJql   jql: key IN (TS-1234, TS-5678)   fields: summary, status, resolution
```

Never `assignee = currentUser()`, never a date range, never a project wide query. A broad search
returns tickets nobody touched and tickets belonging to other people, and both end up in a summary
claiming they were worked on.

Take the summary text and the status. A ticket's summary is often a better description of the outcome
than the commit subject, which is what it is for here. Worklogs are out entirely.

## Sources deliberately left out

**Claude Code session transcripts.** They record every attempt including the abandoned ones, so a day
spent going in circles reads as a productive one.

**Slack, Confluence and calendars.** Meetings and messages are not what this summary is for, and
pulling them in makes it long enough that nobody reads it.

**Datadog.** No credential is configured for it, and an incident someone looked at is not a change
they made.

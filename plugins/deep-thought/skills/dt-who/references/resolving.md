# Resolving a person, and the shape of a row

## The columns

| Column | From | Notes |
|---|---|---|
| Name | Slack, or the commit author | The display name, spelled as they spell it |
| Aliases | How the user refers to them | What a prompt actually says. "Jan", "Victor", "me" |
| Slack ID | `slack_search_users` | `U` plus ten characters. This is what a mention needs |
| Email | Slack profile | The work address |
| GitHub | A noreply address in commit history | Often empty, and that is fine |
| Team | Slack title, after the comma | "Team Ravens", "TIGER Sportsbook" |
| Title | Slack title, before the comma | "React Developer", "FE/Blitzball" |
| TZ | Slack profile | Decides whether a question will be seen today |
| Areas | The user, or what their commits touch | Parts of the system, never qualities of the person |

`Areas` is the one worth being careful with. "Owns cashout" is a fact about the codebase and routes a
question correctly. "Good at tricky bugs" is a judgement about a colleague and does not belong in a
file, however useful it sounds in the moment.

## Slack

```
slack_search_users
  keywords: ["Jan", "Froehlich"]
  natural_language_query: "Who is Jan Froehlich?"
```

Returns name, user id, title, email, timezone and a permalink. One call usually finishes the row
apart from GitHub.

Semantic search is off in this workspace, so `natural_language_query` does no reranking and the
keywords carry the match. Surname plus first name is the reliable form. A first name alone can return
several people, and that is a result to report rather than resolve.

Searching by email also works, and is the right move when a commit shows a work address but no name
that Slack recognises.

## GitHub

**The API cannot map a work email to a handle.** `search/users?q=<email>+in:email` returns zero,
because a work address is not public on a profile. This looks like a bug in the query and is not one.

What works is a commit. A GitHub-authored commit carries:

```
155470393+TkachVegas@users.noreply.github.com
```

The handle sits between the `+` and the `@`. `who-lookup.sh` already scans every repository under the
Github root for an author matching the query, so by the time Phase 2 starts this is usually answered.

When they have never committed locally:

```bash
gh api orgs/<org>/members --per-page 100 --jq '.[].login'
```

That lists logins and no names, so it only helps when the handle resembles the person's name. Where
it does not, leave the column empty.

## When several people match

Report them. Do not pick.

A first name is ambiguous in any company large enough to have two of them, and the cost is asymmetric:
a review requested from the wrong person is noticed late and by somebody who was not expecting it.
List the matches with their teams and let the user say which.

## The store

`work/people/README.md`, a state doc, because the specification merged `reference` into `state` on
the grounds that reference data rots and therefore has to be editable.

Create it through `dtm new state work/people "People I refer to"` rather than by hand. Hand-rolled
front matter fails `dtm validate` on things that are not guessable: the id has to be
`YYYY-MM-DD-<origin>-<rand4>`, the author has to be `<agent>@<origin>`, and a state doc needs a `> `
summary line under its title. `dtm` gets all three right.

Run `dtm validate` after editing. It is fast and it catches the whole class.

**It never commits.** Neither does this skill. The user commits their own memory, which is the rule
every store-aware skill in this suite follows.

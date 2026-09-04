---
name: dt-pr-slack-message
description: Announce a sportsbook-ui or sports-kit pull request in the team's Slack channel. Builds the one line message with the PR and Jira ticket as links, picks at least two developers to cc from the domain the PR touches, shows it for approval, then posts it to #pt-sports-frontend-prs. Works in the sportsbook-ui and sports-kit repos, and posts nothing without approval. Use when asked for a "dt PR slack message", or to post or announce a PR in Slack.
argument-hint: "PR number, branch, or URL, and anyone specific to cc"
---

# dt-pr-slack-message

Post a PR to the team channel, in the shape the channel already uses.

Short skill, one irreversible step. A Slack message notifies people and cannot be unsent, so the
approval gate is the point of the whole thing.

## Scope

**Two repos announce here: `gutro/sportsbook-ui` and `gutro/sports-kit`.** Check first:

```bash
gh repo view --json nameWithOwner -q .nameWithOwner
```

Anything else, stop and say so. The channel, the cc list and the ticket prefix are specific to this
team, and posting an unrelated repo's PR here is noise for eleven people.

`sports-kit` is the team's own skill kit, and its PRs go to the same channel in the same shape. Two
differences: there is no Jira ticket, and the cc goes to whoever owns the kit rather than to the
domain the diff touches. Everything else below is unchanged.

## The target

| | |
|---|---|
| Channel | `#pt-sports-frontend-prs` |
| Channel id | `C0A9SEQ1TBQ` |
| Backend and tool | `slack-mcp` / `slack_send_message` |

Confirm the id with `slack_search_channels` if a post ever fails with `channel_not_found`. Never post
to a different channel because this one did not resolve.

## Phase 1. Gather

Resolve the PR from the argument, or from the current branch when nothing was given:

```bash
gh pr view [<number|branch|url>] --json number,title,url,isDraft,headRefName,author,files
```

Take the number, the title, the URL, the head branch and the draft state.

**A draft PR is not ready to announce.** If `isDraft` is true, say so and ask before going further.

Then the ticket. **`sports-kit` has none, so skip to the duplicate check.** For sportsbook-ui the key
is two letters, a dash and five digits in the branch name, falling back to the title, for example
`TS-42830`. Confirm it exists before linking it, read only:

```
atlassian-mcp / getJiraIssue
  cloudId: leovegas.atlassian.net
  issueIdOrKey: <KEY>
  fields: ["summary","status"]
```

A key that does not resolve is a typo in a branch name. Say so and post without the ticket link
rather than linking a 404.

**Check nobody has posted it already.** Read the channel and look for the PR number or URL:

```
slack-mcp / slack_read_channel   channel_id: C0A9SEQ1TBQ
```

If it is already there, say so with the link and stop. Two announcements of one PR is worse than
none.

## Phase 2. Pick the cc

At least two people: from the domain the PR touches for sportsbook-ui, from who owns the kit for
sports-kit.

Where the names come from, in order:

1. **Whoever the user named** in the invocation. That ends the question.
2. **The standing defaults.** Which pair applies depends on the repo:

   | Repo | Person | Slack id | Domain from their profile |
   |---|---|---|---|
   | sportsbook-ui | Chuan "Victor" Shi | `U07HDHN6UD6` | Frontend Engineer, team Podracing |
   | sportsbook-ui | Vadzim Voitkus | `U05CF9D3DNX` | Senior Javascript Engineer, team Podracing, My Bets |
   | sports-kit | Brandon Porter | `U07AR469MCY` | Author and owner of the kit |
   | sports-kit | José Luis Lebrón Lozano | `U04MJBBBAJJ` | Senior Staff JavaScript Engineer (FE), Sportsbook |

   **"Jose" is ambiguous in this workspace**, and the reference doc has the two apart. An unqualified
   "Jose" on frontend work is Lebrón.

3. **`CODEOWNERS`**, if it ever gains entries. It is currently comments only, so it decides nothing
   today.
4. **Slack profile fields**, via `slack_search_users`, when the PR is clearly outside the defaults'
   area. Profiles here carry team and domain, which is why this works.

Never work out who to cc from per-person commit history. Counting whose name appears on which files
is building a picture of individuals' activity, this repo's conventions do not ask for it, and the
declared sources above are both allowed and more accurate. A file's most frequent committer is often
whoever last did a mechanical rename.

Verify every id with `slack_search_users` before using it, and say who each id belongs to when you
present the message. An unresolved id posts as raw text and tags nobody.

## Phase 3. Compose

The format, and `references/composing-and-posting.md` has the details that bite:

```
[PR](https://github.com/gutro/sportsbook-ui/pull/1036) for [TS-42907](https://leovegas.atlassian.net/browse/TS-42907) - Race pills now scroll by click and drag.
cc: <@U07HDHN6UD6> and <@U05CF9D3DNX>
```

The description is one short clause saying what the PR does for whoever uses the product, taken from
the Jira summary or the PR title, whichever reads better. Keep the trailing full stop. No emoji, no
heading, no second paragraph.

## Phase 4. Approval

Show the user, in one block:

- the channel name and id
- the exact `message` string, as it will be sent
- who each cc id belongs to, by name
- whether the ticket link was confirmed to resolve

Then **end the turn and wait.** `slack_send_message` is a state changing tool with no native prompt,
so it gets an explicit approval for this specific message. Approval of an earlier post is not
approval of this one.

If the user would rather check it in Slack first, `slack_send_message_draft` puts it in their Drafts
for that channel. That is still a write, so it needs the same approval.

## Phase 5. Post

One call, after approval:

```
slack-mcp / slack_send_message
  channel_id: C0A9SEQ1TBQ
  message: <the approved string, unchanged>
```

Then read the channel back and confirm two things: the message is there, and **the cc rendered as
real mentions rather than literal text**. If it came out literal, say so plainly, because it means
nobody was notified and the message needs a manual edit in Slack.

Report the message link.

## Never

- Post without approval of that exact message, or post twice in one response
- Retry a failed send without fresh approval
- Post to any channel other than `#pt-sports-frontend-prs`
- Use `@here`, `@channel`, or tag anyone who did not come from the sources in Phase 2
- Post a draft PR without asking
- Announce a PR that is already in the channel
- Put anything in the message beyond the two lines. No test results, no review summary, no
  description of how the PR was produced
- Edit or delete anyone's Slack messages, including your own

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.

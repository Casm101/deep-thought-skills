# Composing the message, and posting it

## The format is markdown, not Slack mrkdwn

`slack_send_message` takes **standard markdown**. Links are `[text](url)`.

```
[PR](https://github.com/gutro/sportsbook-ui/pull/1036) for [TS-42907](https://leovegas.atlassian.net/browse/TS-42907) - Race pills now scroll by click and drag.
cc: <@U07HDHN6UD6> and <@U05CF9D3DNX>
```

Slack's own `<url|text>` form is what most examples on the internet use, and it is wrong for this
tool. It posts literally, so the channel sees the angle brackets and the pipe.

The mention token `<@U…>` is the exception, because that is Slack's own syntax for a person and there
is no markdown equivalent. Which is why Phase 5 reads the message back: if the mentions came out as
text, nobody was notified.

## When there is no ticket

`sports-kit` PRs never have one, and sportsbook-ui PRs sometimes do not. Drop that part of the line
rather than inventing a placeholder:

```
[PR](https://github.com/gutro/sportsbook-ui/pull/1104) - Pre-commit oxlint now matches CI.
cc: <@U07HDHN6UD6> and <@U05CF9D3DNX>
```

Never write `NO-TICKET`, never link a key you could not resolve, and never link the Jira search page
as a substitute.

## The description

One clause. What the PR does, for whoever uses the product.

Good:

```
Race pills now scroll by click and drag.
Combination forecast and tricast bets show correctly in My Bets.
Pre-commit oxlint now matches CI.
```

Not this:

```
Refactors useDragScroll and routes three verticals through a shared component.   (implementation)
Various fixes and improvements.                                                  (says nothing)
TS-42907                                                                         (already linked)
Fixes the bug where the race pills were not scrollable when using click and drag
on the meetings page of the greyhound racing vertical.                           (too long)
```

Take it from the Jira summary when that reads well. Jira summaries are often written as bug reports,
`[STG | Greyhound racing] the race bubbles are not scrollable`, in which case say what the PR does
instead of what was broken.

## Link previews

Leave `unfurl_app_links` off. It defaults off, and turning it on adds a full preview card for both the
GitHub and the Jira link, which turns a one line notice into a screen of boxes.

## Getting the ids right

**Channel** is `C0A9SEQ1TBQ` for `#pt-sports-frontend-prs`. Hardcoded because it does not change and
one fewer lookup is one fewer thing to get wrong. If a post fails with `channel_not_found`, resolve it
with `slack_search_channels` and mention that the id in this skill needs updating.

**People** get verified every time with `slack_search_users`, even the defaults. A wrong id is not an
error, it posts as literal text and silently tags nobody. Searching by email is the most reliable
form, `victor.shi@leovegas.com` rather than `victor shi`.

Note that display names and Slack handles differ from real names here. The account behind
`@victor-shi` is "Chuan Shi". Present both when you show the message for approval, so the user is
confirming the person and not a string.

**"Jose" resolves to two different people**, and their GitHub handles are no clearer than their names:

| Name | Slack id | GitHub | Which one |
|---|---|---|---|
| José Luis Lebrón Lozano | `U04MJBBBAJJ` | `lebronjl-lv` | Senior Staff JavaScript Engineer (FE), Sportsbook. The one this channel and the kit mean |
| Jose Luis Castiblanco Sparano | `U08LZE6F2F7` | `josecastiblanco-lv` | Senior Backend Engineer, Sports Platform. Not a frontend reviewer |

An unqualified "Jose" on frontend work is Lebrón. Ask when the PR is not frontend work, rather than
picking whichever the user search returns first. A search for `Castiblanco` returns two people as
well, the second being a live trader, which is a good reminder that a single hit is not confirmation
of the right person.

## The approval cycle

`slack_send_message` reports `stateChanging: true` with `nativePromptAvailable: false`. So the cycle
is explicit and it is per message:

1. State the backend, the tool, the effect, and the exact arguments.
2. End the turn.
3. Send only after the user approves that specific message.

One send per response, always. If the user asks for two PRs to be announced, that is two approvals and
two turns, not one approval covering both. Identical or templated messages are not an exception.

If a send fails, report the error and stop. A retry is a new write and needs its own approval, because
"it failed" and "it failed after posting" look the same from here.

## Verify after posting

```
slack-mcp / slack_read_channel   channel_id: C0A9SEQ1TBQ   (newest first)
```

Check the message is present and the mentions resolved. Report the link.

If the mentions came out literal, say so and say what to do about it: the message needs editing in
Slack by hand, because editing it from here is another write and this skill does not edit messages.

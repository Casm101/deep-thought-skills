---
name: dt-who
description: 'Resolve a person named in a prompt to their Slack id, GitHub handle, email, team and the areas they work on, from a directory kept in the memory store. Checks that file before any network call, and when the name is new, looks the person up in Slack and in local commit history, writes the row, and says what it added. Answers "who is Jan", and quietly supplies the right handle whenever a request mentions somebody by name and needs their Slack id to message them or their GitHub handle to request a review. Use when asked for "dt who" or "deep thought who", to look somebody up, or whenever a name in a request has to become an identifier.'
argument-hint: "A name, alias, handle, email or Slack id. Nothing lists everyone."
---

# dt-who

Turn a name into the identifiers behind it, and remember the answer.

Most of the cost of "ask Jan to review this" is working out which Jan, and what their GitHub handle
is. That lookup is the same every time, so it happens once and goes in a file.

## What this is, and what it refuses to become

A directory holds **identifiers and areas**. Who somebody is, how to reference them, and which part
of the system they work on.

It holds nothing about how a person works. Not how quickly they review, not what they are good at,
not how they responded to something. Those are judgements about a colleague, they are not needed to
route a message, and a file that accumulates them is a different kind of file entirely. The boundary
does not erode in one step, it erodes one reasonable-looking entry at a time, which is why it is a
never rather than a preference.

## Phase 1. Look in the directory first

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-who/scripts/who-lookup.sh <name or alias or handle or email>
```

Exit 0 means the person is known and the row is printed. Use it and stop: no Slack call, no API, no
search. That is the point of the file.

Exit 3 means they are not in it. The script has already printed whatever local git history knows,
which is free and often enough for the GitHub half.

Read-only, and it reaches no network. `--list` prints everyone.

The directory lives at `work/people/README.md` in the memory store. When the store is not configured
the script says so, and the skill degrades to looking the person up without remembering the answer.

## Phase 2. Resolve the ones it does not know

Three sources, cheapest first. `references/resolving.md` covers each, and the traps.

**Slack** answers almost everything in one call: id, title, team, work email, timezone.

```
slack_search_users   keywords: ["Jan", "Froehlich"]   natural_language_query: "Who is Jan Froehlich?"
```

**Local git history** is the only reliable route to a GitHub handle, and Phase 1 has already run it.
A GitHub-authored commit carries `<id>+<handle>@users.noreply.github.com`, and the handle is inside
the address. The GitHub API cannot do this, because a work email is not public on a profile.

**The org member list** is the fallback when they have never committed locally:
`gh api orgs/<org>/members --jq '.[].login'`, then match on name.

A column that cannot be filled stays empty. An empty GitHub handle is a fact about somebody who has
not committed here, and it is better than a guess that will be used to request a review.

## Phase 3. Write the row

Append to the table and say what was added. No confirmation: it is a directory entry in the user's
own notes, and asking per colleague would make this slower than not having it.

Create the file with `dtm` rather than by hand when it does not exist yet, because the store has a
specification and `dtm validate` enforces it:

```bash
DT_MEMORY="${DT_MEMORY:-$(head -1 ~/.config/dtm/repos)}"
"$DT_MEMORY/bin/dtm" new state work/people "People I refer to"
```

Then run `dtm validate` and fix what it reports. **Never commit the store**, the same rule every
store-aware skill here follows. The user commits their own memory.

## Phase 4. Answer the actual question

The lookup is rarely the request. Somebody asked to message a person, request a review, or find out
who owns an area. Return the identifier the request needs and get on with it.

Where several people match a first name, say so and list them rather than picking. Guessing which
Jan was meant is how a review request reaches the wrong person.

## Never

- Never record anything evaluative: how somebody works, how responsive they are, how good they are,
  what they are like. Identifiers, team, title and areas of the system, and nothing else.
- Never record personal contact details. Work identities only, which is what a directory is for.
- Never reach for Slack or an API before Phase 1 has missed. The file exists to stop that.
- Never guess an identity from a partial match. Two people share a first name eventually, and a
  wrong row is worse than no row because nothing later questions it.
- Never fill a column with something unverified. Empty is a fact; a plausible handle is a liability.
- Never commit the memory store. Write the file, run the validator, leave the commit to the user.
- Never record somebody who is not a work contact, and never build a row for a person the user has
  not actually referred to.

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.

# The tree, the frontier, and the rounds

## The tree

A node is one decision. An edge means the decision below cannot be made until the one above is
settled.

Keep it written down between rounds, with each node marked settled, open, or blocked, and each
settled one carrying its answer. You will be several rounds deep before long, and a tree you are
holding loosely is how a branch goes unasked.

## The frontier

The frontier is every open decision whose prerequisites are all settled.

The test for a question being on it: **can you ask this without guessing at an answer you have not
heard yet?** If asking it means assuming how something else will be decided, it is not on the
frontier. It goes in a later round.

Worked example. Someone wants offline support in an app.

```
1. What does offline mean here, read only or full editing?        <- frontier, round 1
2. Which data has to be available offline?                        <- frontier, round 1
3. How do we resolve two conflicting edits?                       <- blocked by 1
4. Where does the offline copy live?                              <- blocked by 2
5. What does the user see while a sync is pending?                <- blocked by 1 and 3
```

Three is not askable in round one. If offline turns out to be read only there are no conflicting
edits and the question disappears. Asking it anyway invites an answer to a question that may not
exist, and now that answer is in the record.

## Prerequisite or preference

The distinction that decides a round, so be strict about it.

A real prerequisite means the later question **changes shape** depending on the earlier answer. New
options appear, options vanish, or the question stops existing.

Not a prerequisite:

- The later question feels less important
- You would rather discuss them in that order
- They touch the same part of the system
- One is harder to answer

If both questions are askable now, both go out now, even when one is obviously the bigger decision.
Holding back the small one to keep the round tidy costs a whole turn.

## Round size

Ask the whole frontier. If that comes to more than about eight questions, look again before sending:
usually the tree is too flat, and several of those questions are one decision split into pieces.
Merge them.

A frontier of one or two is normal late in a session. It is not a reason to invent questions or to
pull forward something still blocked.

## Fact-finding

Before drafting any question, ask whether an agent could answer it. If yes, that is not a question,
that is a lookup.

Things to look up, never ask:

- What the code currently does, and where
- Whether a library, helper, or pattern already exists in the repository
- What the tests cover
- What a config, manifest, or lockfile says
- What the conventions documents require
- What the git history says about why something is the way it is

Things only a person can answer:

- What they want, and what done looks like
- Which of two workable designs they prefer, and why
- What is in scope and what is not
- What they are willing to trade, such as speed against correctness, or effort against coverage
- Anything about deadlines, priorities, or who else is involved

Dispatch read-only agents for the lookups. Explore has no write tools. For a fact that needs real
understanding of a feature rather than a grep, run `dt-investigation` aimed at the area.

Then keep going. The lookup is a prerequisite like any other, so only its dependents wait. Say in the
round which lookups are running and what they will settle, so nobody wonders what happened to a
question they expected.

## When a round comes back thin

If the answers are short, hedged, or say "you decide", that usually means the question was wrong
rather than the answerer unhelpful. Common causes, and what to do:

- **Two decisions in one question.** Split it and ask both next round.
- **No stakes given.** Say what each option costs. People answer a trade-off faster than a
  preference.
- **They lack a fact you already have.** Give it to them in the question rather than expecting them
  to know it.
- **They genuinely do not care.** Record your recommendation as the decision, mark it as yours not
  theirs, and move on. Never present that as their choice.

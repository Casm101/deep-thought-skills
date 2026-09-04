# Formats

## A question

```
❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>
```

The title is a short noun phrase naming the decision, not the whole question. The body carries
whatever it takes to answer: the context, the options, the trade-off, and any fact you found that
bears on it. Multiple paragraphs are fine, and so are lettered choices when the options are discrete.

Number from Q1 each round and say which round it is.

## What makes a question worth asking

**It forks the work.** Different answers lead to different builds. If every answer leads to the same
code, it is not a decision, and asking it spends a turn for nothing.

**It is one decision.** If the answer needs an "and", split it.

**It carries its stakes.** Say what each option costs: the work, the risk, what it rules out later.
Someone can weigh a trade-off in seconds and will stall for minutes on a bare preference.

**It could not have been looked up.** Run the check in `references/rounds.md` over every draft.

**Its recommendation is real.** One option, one line of why. Where you truly have no view, say what
you would need to have one, and that is usually a lookup you should have run.

## The final tree

Only after they confirm the understanding is shared.

Structure it as the tree, not as a transcript. Order by dependency, so anyone reading it top to bottom
meets each decision after the ones it rests on.

```
## The design, as agreed

1. Offline means read only
   Decided by: you
   Editing offline was out of scope for this release, so conflict resolution does not arise.

   1.1 Cached data is the last twenty open bets and the settled list for thirty days
       Decided by: you
       Chosen over caching everything because the settled list is what people reopen.

   1.2 The cache lives in the existing persisted store
       Decided by: me, you had no preference
       It already handles versioning and migration, so nothing new is needed.

2. A pending sync shows the existing offline banner
   Decided by: you
   Reusing it rather than adding a per-row state, which was the alternative.
```

Then three short sections.

**Facts that shaped this.** Each one with where it came from, so a reader can check it. "The persist
store already versions and migrates, `store/persist.ts`" rather than "the store handles it".

**Out of scope.** What you deliberately decided not to decide, and why. This is what stops the same
conversation happening again next week.

**Still unknown.** Anything that could not be settled, and what would settle it. An empty list here
is a strong claim, so only write it when it is true.

## What stays out of the final tree

**The transcript.** No record of who said what in which round. The decisions and their reasons.

**Implementation detail nobody decided.** If it was not a decision, it does not belong in a decision
tree.

**File paths and code**, except where a path is the fact itself, as in the persist store example
above. Paths move, and a design tree outlives them.

**Your own opinions on decisions that went against your recommendation.** Record what was decided.
The recommendation already had its turn.

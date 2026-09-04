---
name: dt-grilling
description: 'Interview whoever invoked you until you both understand the same design. Maps the work as a decision tree, then asks in rounds: every question whose prerequisites are already settled, numbered, each with a recommended answer, then waits. Each round of answers settles decisions and opens the next. Looks up facts itself rather than asking, and finishes by handing back the finished decision tree once you confirm the understanding is shared. Changes nothing on disk. Use when asked for "dt grilling", or to be grilled, questioned, or interviewed about a design before building it.'
---

# dt-grilling

Ask until there is nothing left to assume.

The work is a tree of decisions. Some can only be made once others are settled, so you ask in rounds:
everything answerable now, all at once, then wait. Every answer settles part of the tree and opens
the part behind it.

## The rules that hold throughout

**Decisions belong to whoever invoked you.** You recommend, they decide. Put each question to them
and wait. Never settle a decision by picking the answer you prefer and moving on.

**Facts are your job.** If the answer lives in the repository, the tests, the config, the git
history, or a tool you can call, go and find it. Asking someone to look up something you could read
yourself wastes their turn and tells them you did not try.

**Nothing is written.** No file created, no code changed, no config touched. The output is the
decision tree, in the conversation, and nothing else.

**Nothing is acted on.** Not even after the tree is agreed. Agreement ends this skill's job. Building
is a separate ask, and `dt-to-tasks` is usually what comes next.

## Round one

Before the first question, build the tree. Read what you already have: the conversation, whatever was
handed to you, and whatever you can find in the repository. Then write down, for yourself, every
decision the work needs and what each one depends on.

Then compute the frontier and ask it. `references/rounds.md` covers how, including how to tell a
prerequisite from a preference.

## Every round after

1. Take the answers. Settle those decisions.
2. Reshape the tree. An answer often adds branches nobody could see before it, and sometimes it cuts
   a whole branch off. Both are normal.
3. Recompute the frontier from the settled set.
4. Dispatch any fact-finding the new frontier needs.
5. Ask the new frontier, numbered from Q1 again, and say which round this is.

If an answer contradicts something already settled, say so plainly and ask which one stands. Do not
quietly keep both.

## Asking

The whole frontier in one round. Not the two questions you find most interesting, and not one at a
time.

Format each question exactly like this:

```
❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>
```

The recommendation is a real one. Pick an option, say why in a line, and be willing to be overruled.
"Either could work" is not a recommendation, it is the question asked twice.

`references/output.md` has the rest of the format rules, including what makes a question worth
asking and what to do with the ones that are not.

## Facts, and not blocking on them

When a frontier question needs something from the environment, dispatch a read-only agent to find it.
The Explore agent has no write tools, so use that. Where the fact needs real understanding of how a
feature works rather than a lookup, that is `dt-investigation`, aimed at the area.

A running lookup is an unsettled prerequisite. So the questions behind it wait for the report, and
**every other question on the frontier goes out now**. Never hold a whole round while one agent
reads a file.

When the report lands, fold the fact into the tree. It may settle a decision outright, in which case
say so and say what settled it. It may also open questions nobody could have asked before.

## Finishing

The session is done when the frontier is empty, every branch has been visited, and nothing is left
silently assumed.

Then ask, in one line, whether the understanding is shared. Do not output the tree yet, and do not
start work.

**Only once they confirm**, output the finished decision tree in the shape
`references/output.md` sets out. Run the `dt-unslop` skill over it first, invoking it with the Skill
tool as `dt-unslop`, and leave identifiers, quoted answers and the question markers alone.

If they say the understanding is not shared, they will say what is missing. That is another round.

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.

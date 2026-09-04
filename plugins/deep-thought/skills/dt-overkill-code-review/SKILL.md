---
name: dt-overkill-code-review
description: Review the current branch three times over, independently. Builds a packet holding the diff and the repository's own documentation, sends it to three agents that share none of this session's context, collects their reports, then judges the three against each other and rules on which findings hold. The judge counts and compares, it never reviews the code itself. Use when a change is large or risky and one reviewer is not enough, or when asked for a "dt overkill code review" or a "dt overkill review".
---

# dt-overkill-code-review

Three reviewers who have never met read the same change and write down what they find. Then you sit
between the three reports and work out what they agree on.

The value comes from the agents being independent. Everything in this skill exists to protect that.

## What the judge is, and is not

**The judge holds no opinion about the code.** It never reads the diff to form a view, never adds a
finding no agent raised, never drops one because it disagrees, and never raises or lowers a severity
past what the agents wrote. It matches findings across three reports, counts, and applies the rules
in `references/judging-rules.md`.

One narrow exception, because it is a fact and not a judgement: if a finding cites a file or line
that does not exist, the judge discards it and says so in the report. Nothing else about the code may
be checked. Delete this paragraph if you want the judge purely arithmetic.

If you find yourself thinking "the agents missed X", that thought does not go in the verdict. Report
it separately as your own remark, clearly outside the verdict, or run the skill again.

## Phase 1. Build the packet

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-overkill-code-review/scripts/review-packet.sh [<base ref>]
```

It prints the branch, the base and merge base, the commits, the changed files, the path to the full
diff, every documentation file that governs the touched directories, and the test, lint and
type-check commands for the packages that own the changed files. Base defaults to `origin/HEAD`, then
`origin/main`, then `main`.

Everything between `----- PACKET BEGINS -----` and `----- PACKET ENDS -----` goes into each agent
prompt unchanged.

## Phase 2. Spawn three agents, on three different models

Three, because two cannot break a tie. **Three different models**, because three runs of the same
model share the same blind spots and mostly agree with each other.

Send all three in **one message** so they run at the same time, using the brief in
`references/agent-brief.md` verbatim, with the packet pasted in. Same brief, same packet, different
model on each.

| Agent | `model` | Why |
|---|---|---|
| 1 | `fable` | The most capable model available, for the reasoning the other two may not reach |
| 2 | `opus` | Strong and different, the everyday default |
| 3 | `sonnet` | Strong, cheaper, and wrong about different things |

Pass it as the Agent tool's `model` parameter. `haiku` is the fourth option: cheaper again, and its
200K context is smaller than the others, so use it only on a small diff and only as a substitute.

**Record which model produced which report**, and carry that through to the verdict. It is the
difference between three opinions and three independent ones.

**If a model is unavailable**, substitute the next one in the table and **say so in the verdict**.
Some accounts cannot reach every model, for instance `fable` is not available under zero data
retention. Never quietly run two agents on the same model and present the result as three
independent reviews. If only two distinct models are reachable, run two agents and report a panel of
two.

Three reviews on these models cost more than three on one. That is the trade this skill exists to
make, and `dt-code-review` is there when it is not worth it.

What must never reach an agent prompt:

- Anything you think about the change, or any finding of your own
- What another agent said, at any point
- The author's reasoning, the PR description's claims, the ticket's promises. A description saying
  "this cannot break existing pins" is a claim under review, not a fact
- Whether the change is yours
- Anything from this session at all beyond the packet

Give each agent a plain read-only instruction: read, do not edit, do not run the project's build,
tests or formatters, do not commit or push.

If an agent fails or returns something that is not the required shape, run that one again once.
If it fails twice, say in the verdict that the panel was two, and treat every tally as out of two.
Never quietly proceed with two agents while presenting thirds.

## Phase 3. Judge

Follow `references/judging-rules.md`. In outline:

1. Match findings across the three reports. Same file, overlapping lines, same claimed defect, one
   finding. Different defect on the same line, different findings.
2. Tally each one. Three of three, two of three, one of three, or a conflict where two agents assert
   opposite facts.
3. Apply the rule for each tally. The rule decides, not you.
4. Derive the overall verdict from the counts, again by rule.

Quote the agents rather than paraphrasing. A finding in the verdict carries the words the agent used,
so the reader can see what was actually claimed.

## Phase 4. Unslop, then deliver

Run the `dt-unslop` skill over the verdict before it goes out. Invoke it with the Skill tool as
`dt-unslop`, or read `${CLAUDE_PLUGIN_ROOT}/skills/dt-unslop/SKILL.md` and apply its rules if it is not
installed. Leave quoted agent text, code, paths and line numbers exactly as they are, since quotes
stop being quotes once you tidy them.

Then deliver the verdict to whoever invoked the skill, in this shape:

```
Panel:     3 agents on 3 models, fable, opus, sonnet, all 3 reported
Verdict:   NEEDS WORK
Confirmed  2   all three models
Majority   3   two of three
Minority   4   one model only
Conflicts  1
Discarded  1   cited a line that does not exist
```

Then the findings, grouped by tally, strongest first, each naming the models that raised it. Then
conflicts, with both claims quoted side by side and no ruling from you. Then the minority findings,
each marked with the single model that raised it. Then, last and
clearly separated, anything you noticed yourself, labelled as outside the verdict.

Close with the diff file path so it can be deleted.

## Cost

Three full reviews of the same diff, on three models, is a lot of work for a small change. Say so if
the change is a handful of lines, and point at `dt-code-review`, which is this same skill with one
agent instead of three. Overkill is the name, not the default.

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.

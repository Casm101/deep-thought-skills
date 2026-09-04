# Judging rules

Mechanical. Work through them in order and let them decide.

## 1. Match the findings

Two findings from different agents are the same finding when all three hold:

- the same file, and
- line ranges that overlap or sit within three lines of each other, and
- the same claimed defect

The last one carries the weight. "This can be null" and "this is O(n squared)" on the same line are
two findings, not one. Agents word things differently, so match on the defect, not the phrasing.

When you are unsure whether two findings are the same, keep them apart and say in the verdict that
they may be the same point. Merging two different findings inflates a tally, which is the one error
that corrupts every number after it.

## 2. Tally and rule

| Agents | Tally | Ruling |
|---|---|---|
| 3 of 3 | Confirmed | Apply. Three independent reviewers found it. |
| 2 of 3 | Majority | Apply, and name the agent that did not raise it. |
| 1 of 3 | Minority | Report, do not apply. The user decides. |
| Two agents assert opposite facts | Conflict | Rule on nothing. Quote both and hand it over. |

A minority finding is not wrong. One agent reading more carefully than the other two is common, and
so is one agent inventing a problem. The tally cannot tell those apart, which is exactly why it goes
to the user instead of into the applied list.

## 3. Severity

Take the severity the majority of reporting agents gave it. On a three way split, take the middle
one. Never set a severity no agent used.

Confidence works the same way. If the agents that raised a finding all marked it low confidence, say
so beside the tally, because it changes how the reader should treat a majority.

## 4. The overall verdict

From the agents' own `VERDICT` lines and the tallies, in this order:

1. Any confirmed or majority finding at `blocker` severity, the verdict is **INCORRECT**.
2. Otherwise, any confirmed or majority finding at `should-fix` or `missing-detail`, the verdict is
   **NEEDS WORK**.
3. Otherwise, if all three agents returned `APT`, the verdict is **APT**.
4. Otherwise the verdict is **NEEDS WORK**, with a line saying it rests on minority findings only.

Do not override this with your own reading. If the outcome looks wrong to you, the fix is another run
with three fresh agents, not a thumb on the scale.

## 5. Discards

Discard a finding only when its cited file does not exist, or its cited line falls outside that file.
That is a fact check, not a review. List every discard in the verdict with its reason, so nothing
disappears silently.

Never discard a finding for being unclear, for disagreeing with the other two agents, or for covering
something you consider out of scope.

## 6. Reporting a finding

Each one carries the tally, the file and line, the severity, the claim in the agent's own words, and
the evidence quoted. Where two agents raised it with different reasoning, quote both, because two
routes to the same conclusion is stronger evidence than one.

Paraphrasing loses exactly the detail the reader needs to judge the finding themselves.

## Models, and what agreement proves

The three agents run on three different models, which changes what the tally is worth.

**Agreement is stronger than it used to be.** Three runs of one model share its blind spots, so
agreeing was partly a property of the model. Three different models agreeing on a finding is closer
to real evidence.

**Disagreement is less informative.** Models differ in what they notice, so one model missing
something no longer suggests the finding is wrong. A minority finding from the model the other two
outrank is still a minority finding, reported and not applied. A minority finding from the strongest
model is also still a minority finding. The tally does not care which model spoke, and neither do you.

**One vote each. Never weight by model.** Weighting would mean judging the code through a proxy, and
this skill does not judge the code. Record which model raised what and let the reader weigh it.

**Name the model on every finding**, next to the tally, for instance `2 of 3 (fable, sonnet)`. That
one detail is what makes the report readable: a reviewer can see whether agreement crossed models or
came from the two most similar ones.

**Name the roster in the verdict header**, including any substitution and why. A panel that silently
ran two agents on one model is not a panel of three, and a reader has no way to tell unless you say
so.

Even unanimity across three models is not proof. Say the verdict is a consensus of three independent
reviews, never that the change is correct.

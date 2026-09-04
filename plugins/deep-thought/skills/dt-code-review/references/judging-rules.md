# Reading the report

This is the three agent ruleset with the arithmetic taken out. One report, so there is nothing to
count. What remains is keeping your own opinions out of it.

## 1. No matching, no tallies

With three agents, agreement across reports is the signal. Here there is one report, so every finding
carries the same weight: one reviewer said so.

Do not rank findings by how confident the agent sounded, and do not promote one because it matches
something you already believed. Severity order is the only order.

## 2. Severity and confidence

Take both exactly as the agent wrote them. Never set a severity the agent did not use, and never
raise one because the finding worries you.

Where the agent marked a finding low confidence, carry that word into the report. A low confidence
blocker still leads, and the reader needs to see that the agent itself was unsure.

## 3. The overall verdict

From the agent's own `VERDICT` line and its findings, in this order:

1. Any finding at `blocker` severity, the verdict is **INCORRECT**.
2. Otherwise, any finding at `should-fix` or `missing-detail`, the verdict is **NEEDS WORK**.
3. Otherwise, if the agent returned `APT`, the verdict is **APT**.
4. Otherwise the verdict is **NEEDS WORK**.

Where the agent's own verdict line disagrees with the rule, report both and say the rule decided.
Do not pick the one you prefer.

## 4. Discards

Discard a finding only when its cited file does not exist, or its cited line falls outside that file.
That is a fact check, not a review. List every discard with its reason.

This matters more here than with three agents. A bad citation from one of three stands out against
the other two, and a bad citation from one of one has nothing to stand against.

Never discard a finding for being unclear, for looking wrong to you, or for covering something you
consider out of scope.

## 5. What the agent could not check

The brief asks the agent for a `COULD NOT CHECK` list. Carry it into the report as its own section.

It is the shape of the hole in this review, and with one reviewer nobody else filled it. If the agent
could not run the tests, then no finding here rests on a test result, and the reader should know that
before they act on any of it.

## 6. Reporting a finding

Each one carries the file and line, the severity, the claim in the agent's own words, and the
evidence quoted. Paraphrasing loses exactly the detail the reader needs to judge it themselves.

## What one report does and does not prove

It proves one reviewer without your context found these things. That is genuinely useful, and it is
weaker than it will look once it is written down in a tidy list.

Say in the report that every finding is single source and nothing has been cross-checked. Say it once
and plainly. A reader who forgets there was one agent will read a tidy list as settled fact.

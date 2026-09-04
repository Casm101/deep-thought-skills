---
name: dt-code-review
description: Review the current branch with one agent that has none of this session's context. Builds a packet holding the diff and the repository's own documentation, sends it to a single agent, then reports what it found without adding to it or arguing with it. Same structure and reporting as dt-overkill-code-review, with one reviewer rather than three, so every finding is single source and nothing is cross-checked. Use for an everyday review of branch changes, or when asked for a "dt code review".
---

# dt-code-review

One reviewer who has never seen this conversation reads the change and writes down what they find.
You pass on what they said.

The point is the missing context. An agent that never heard the reasoning cannot be talked into
accepting it, so it reads the diff the way the next person on the team will.

This is `dt-overkill-code-review` with one agent instead of three. Same packet, same brief, same
reporting. What changes is what the findings are worth, and the report has to say so.

## What you are, and are not

**You hold no opinion about the code.** You do not read the diff to form a view, you do not add a
finding the agent did not raise, you do not drop one because you disagree, and you do not move a
severity the agent set.

One narrow exception, because it is a fact and not a judgement: if a finding cites a file or line
that does not exist, discard it and say so in the report. With three agents a bad citation usually
stands out against the other two. With one there is nothing to compare it against, so this check is
the only guard there is. Nothing else about the code may be checked.

If you think the agent missed something, that does not go in the report. Put it after the report,
clearly labelled as your own remark, or run `dt-overkill-code-review` and let three agents settle it.

## Phase 1. Build the packet

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-code-review/scripts/review-packet.sh [<base ref>]
```

It prints the branch, the base and merge base, the commits, the changed files, the path to the full
diff, every documentation file that governs the touched directories, and the test, lint and
type-check commands for the packages that own the changed files. Base defaults to `origin/HEAD`, then
`origin/main`, then `main`.

Everything between `----- PACKET BEGINS -----` and `----- PACKET ENDS -----` goes into the agent
prompt unchanged.

## Phase 2. Spawn one agent

Use the brief in `references/agent-brief.md` verbatim, with the packet pasted in.

What must never reach the prompt:

- Anything you think about the change, or any finding of your own
- The author's reasoning, the PR description's claims, the ticket's promises. A description saying
  "this cannot break existing pins" is a claim under review, not a fact
- Whether the change is yours
- Anything from this session at all beyond the packet

Give the agent a plain read-only instruction: read, do not edit, do not run the project's build,
tests or formatters, do not commit or push.

If it fails or returns something that is not the required shape, run it again once. If it fails
twice, say so and report nothing rather than filling the gap yourself.

## Phase 3. Read the report

Follow `references/judging-rules.md`, which is the three agent version adapted to one. In outline:

1. There is nothing to match and nothing to tally. Every finding is single source.
2. Take each severity exactly as the agent set it.
3. Derive the overall verdict from the agent's own verdict line and the severity rule.
4. Discard only a finding whose citation does not resolve, and list every discard with its reason.
5. Note anything the agent said it could not check. That is the shape of the gap in this review.

Quote the agent rather than paraphrasing. A finding carries the words the agent used, so the reader
can see what was actually claimed.

## Phase 4. Unslop, then deliver

Run the `dt-unslop` skill over the report before it goes out. Invoke it with the Skill tool as
`dt-unslop`, or read `${CLAUDE_PLUGIN_ROOT}/skills/dt-unslop/SKILL.md` and apply its rules if it is not
installed. Leave the quoted agent text, code, paths and line numbers exactly as they are, since
quotes stop being quotes once you tidy them.

Then deliver, in this shape:

```
Panel:     1 agent
Verdict:   NEEDS WORK
Findings   5   single source, none cross-checked
Blockers   1
Discarded  1   cited a line that does not exist
Not checked  the agent could not run the tests, so nothing here rests on a test result
```

Then the findings, most severe first, each with its file and line, the claim in the agent's own
words, and the evidence quoted. Then the discards. Then what the agent could not check. Then, last
and clearly separated, anything you noticed yourself, labelled as outside the report.

Close with the diff file path so it can be deleted.

## What one agent is worth

Say it in the report, once, without hedging. **Every finding here is one reviewer's view and nothing
has been cross-checked.** A single agent invents problems sometimes and misses real ones sometimes,
and this arrangement cannot tell you which happened.

That is the trade, and it is usually the right one. One review of a normal change is proportionate.
When the change is large, touches money or data, or would be expensive to get wrong, run
`dt-overkill-code-review` and let three independent reviews argue it out.

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.

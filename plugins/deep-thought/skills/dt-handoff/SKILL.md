---
name: dt-handoff
description: Compact the current conversation into a handoff document a fresh agent can pick up and continue from.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

# dt-handoff

Write down what the next agent needs and nothing it can find on its own. The test is simple. A fresh
session, given only this document and the repo, should be able to take the next step without asking
you anything.

## Where it goes

The operating system's temporary directory, never the workspace. A handoff is scratch, and it must not
land in a commit.

```bash
OUT="${TMPDIR:-/tmp}/handoff-$(date +%Y%m%d-%H%M%S).md"
cat > "$OUT" <<'MD'
...document...
MD
echo "$OUT"
```

Use a quoted heredoc. The document will contain backticks, `$` and braces, and an unquoted one eats
them. Print the path at the end so the user can pass it on.

## What goes in

1. **Start here.** The single next action, first line of the document. Not a summary of the summary.
2. **The task.** What this work is and what done looks like, in two or three sentences.
3. **Where things stand.** Done, in flight, not started. Name the branch, and say whether the working
   tree is clean.
4. **Decisions and why.** The reasoning a diff cannot show. Why this approach instead of the obvious
   one, what constraint forced it, what the user asked for explicitly.
5. **Dead ends.** What you tried that did not work, and how it failed. This is the highest value
   section and the one nobody can reconstruct. Without it the next agent repeats your afternoon.
6. **Environment traps.** The commands that hang, the version the tests need, the flag that must be
   set, the tool that is not installed. Anything that cost you time and will cost the next agent the
   same.
7. **Files and artifacts.** Paths that matter, one line each on why. Link specs, plans, ADRs, issues,
   PRs and commits by path or URL.
8. **Open questions.** What is unresolved, and who or what would resolve it.
9. **Suggested skills.** Name the skills the next agent should invoke with the Skill tool, and say
   when. For example, `dt-investigation` before touching an unfamiliar feature, `dt-tdd-prep` before
   implementing, `dt-pr-review` before merge.

Drop any section that has nothing real in it. An empty heading is noise.

## What stays out

**Anything another artifact already holds.** Specs, plans, ADRs, issues, commits, diffs. Reference
them by path or URL. Copying them means the copy goes stale and the next agent trusts the wrong one.

**The transcript.** No replay of what you said and what the user said. State the conclusions.

**Narration and praise.** "We successfully implemented" tells the next agent nothing. What works, what
does not, what is next.

## Redaction

Strip anything sensitive before saving. API keys, tokens, passwords, connection strings, customer
data, personal information about anyone. If a value matters to the work, name what it is and where it
comes from, such as "the staging token, in 1Password under X", never the value itself.

## If the user passed arguments

Treat them as the next session's focus and write for that. Lead with what is relevant to it, keep the
rest brief, and say plainly what the document does not cover.

## Before you save

Run the `dt-unslop` skill over the document. Invoke it with the Skill tool as `dt-unslop`, or read
`${CLAUDE_PLUGIN_ROOT}/skills/dt-unslop/SKILL.md` and apply its rules. Leave code, paths, commands and quoted
output alone.

Then read it once as if you had never seen this conversation. Every unexplained name, abbreviation or
"as discussed" is a hole. Fill it or cut it.

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.

# The briefing, and the memory file

## The briefing

Mirrors `dt-handoff`'s sections, so a handoff written by one session and a briefing written by the
next read as the same document from opposite ends. Goes to the session, not to a file.

```
## Inheriting bugfix/TS-42830-my-bets-x-cast-combinations

**Where it stands.** 16 commits of its own, level with origin/main, last touched 24 Aug. PR #976 is
open and mergeable, with two unresolved review threads. The suite is green apart from a pending Drone
run.

**The task.** X-cast bets (forecast and tricast combinations) render wrongly in My Bets: the box name,
the runner names and the settled finishing order. TS-42830.

**Completion.**

| Criterion | State | Evidence |
|---|---|---|
| Combination boxes are named in the card header | done | `racingXCast.ts` names them from leg geometry, covered in `utils.spec.ts` |
| Finishing order shows once legs settle | done | covered, `utils.spec.ts` |
| Non-runners in a tricast handled | partial | two-of-three covered, three-of-three has no test |
| Danish translations present | done | `da.json`, plus the orphaned key removed |
| Reuse selections still rebuilds the same bet | not started | raised in review, thread open |

**Decisions this branch already made.** Dropped the x-cast classification helper and
`racingXCastOutcomes` as dead. Scoped the box name to its own bet after review. Folded the empty-group
check into the event guard rather than keeping it separate.

**Waiting on you.** Two review threads from VadzimVoitkus, one HIGH about "Reuse selections" rebuilding
a different bet, one MEDIUM about preferring the WON occurrence with nothing asserting it.

**Traps.** A handoff document from a previous session is at `.claude/handoff-TS-42830-review.md`, 292
lines, read it. Three stashes exist but all were made on other branches and are unrelated.

**Next.** `dt-pr-defense`, because two review threads are open and answering them decides whether the
remaining criterion is in scope.
```

Rules for it.

**Where it stands comes first.** Position, PR state, green or red. Someone reading this wants that in
one glance.

**The completion table is per criterion, with evidence.** A criterion with no test covering it is
partial at best. `unknown` beats a guess. Never write `done` because the code looks right.

**Decisions already made** is the section that stops you undoing work. If the branch tried something
and backed out, say so, because the obvious next idea is often the one it already rejected.

**Waiting on you** is anything with a person behind it: review threads, questions on the ticket, a
failing check somebody will ask about.

**Traps** covers the handoff document, the stashes, the environment. Say which stashes are unrelated
rather than listing all of them as if they matter.

**Next** is one skill, with a reason, not started.

Say what was missing. No ticket, no PR, no handoff, `gh` unavailable: each of those changes how much of
this briefing is guesswork, and the reader needs to know which.

## The memory file

One file per inherited branch, type `project`.

```markdown
---
name: branch-ts-42830-x-cast-combinations
description: In-progress branch for TS-42830, x-cast bet rendering in My Bets, and what it already decided
metadata:
  type: project
---

Branch `bugfix/TS-42830-my-bets-x-cast-combinations`, PR #976, picked up 2026-08-24.

Fixes how forecast and tricast combination bets render in My Bets: box naming, runner names, and the
settled finishing order.

**Decided already, do not redo.** The x-cast classification helper and `racingXCastOutcomes` were
removed as dead rather than fixed. The box name is scoped to its own bet, changed after review
feedback. The empty-group check lives inside the event guard on purpose.

**Outstanding.** Two review threads from VadzimVoitkus, HIGH on "Reuse selections" rebuilding a
different bet, MEDIUM on preferring the WON occurrence untested. Three-of-three non-runners has no
test.

**Why:** a session picking this branch up later would otherwise retry the removed helper or reopen the
scoping decision, both of which were settled deliberately.

**How to apply:** read the review threads on #976 before changing `racingXCast.ts`. The three stashes
in this repo were made on other branches and are unrelated to this work.
```

What goes in, and what does not.

**In:** the task in a sentence, completion state, decisions and why, abandoned approaches, what is
outstanding, what the stashes are, where a handoff document was, environment traps.

**Out:** the diff, the file list, the commit log, the changed-line counts. Every one of those is a git
command away and will be wrong within a day, while git stays right. A memory competing with the
repository is worse than no memory.

**One per branch.** If one already exists, update it. Two memories for one branch will disagree
eventually, and then neither can be trusted.

**Delete it when the branch merges.** A memory about in-progress work outlives its usefulness the
moment the work lands, and a stale one is read as current.

Add the one-line pointer to `MEMORY.md`, as with any memory.

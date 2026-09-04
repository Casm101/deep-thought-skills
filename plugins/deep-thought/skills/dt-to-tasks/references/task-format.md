# Task format

Two forms. Pick by where the tasks are going.

## Form A, handing straight to a person or an agent

Use this when there is no tracker involved, or when the tasks go to whoever invoked the skill.

```
## 3. Show the settled finishing order on a combination tricast

Blocked by: 1, 2
Status: ready for agent

What to build
A punter opening a settled combination tricast sees the finishing order the race actually
produced, in place of the runner names they picked.

Acceptance criteria
- A settled combination tricast shows the real finishing order for each leg
- An unsettled one keeps showing the picked runners, unchanged
- A leg with a non-runner shows the substitute, not a blank
- Existing forecast behaviour is untouched
```

## Form B, an issue tracker where a parent already exists

Same content, plus a parent reference. Include the parent section only when the source was a real
issue, and omit it entirely otherwise.

```
Parent: TS-42830

What to build
A punter opening a settled combination tricast sees the finishing order the race actually
produced, in place of the runner names they picked.

Acceptance criteria
- A settled combination tricast shows the real finishing order for each leg
- An unsettled one keeps showing the picked runners, unchanged
- A leg with a non-runner shows the substitute, not a blank

Blocked by: TS-42830 slice 1, TS-42830 slice 2
```

Reference the parent, never touch it. No closing it, no editing its description, no moving its status.

## Writing the fields

**Title.** What somebody can do once it lands, in the project's vocabulary. Short. Not "refactor the
selectors".

**What to build.** The end to end behaviour, from the point of view of whoever uses it, whether that
is a punter, an operator, or the next agent. Two or three sentences. Never a layer by layer
implementation list, because that is the implementer's decision and it goes stale the moment they
start.

**Acceptance criteria.** Checkable statements. Each one either holds or does not, with no judgement
call. Include the cases that are easy to forget: the empty state, the failure, the thing that must not
change. "Works correctly" is not a criterion.

**Blocked by.** Numbers in form A, issue references in form B. `None` when it can start now, and say
`None` rather than leaving the field out, so a reader knows you considered it.

**Status.** `ready for agent` once the task carries its blockers and every criterion is checkable.

## What stays out

**File paths.** They move. A task that names `src/store/betHistory/utils/racingXCast.ts` is wrong the
first time somebody reorganises, and the implementer can find the file faster than you can describe
it.

**Code snippets.** Same reason, and worse, because a stale snippet gets copied.

**Implementation steps.** If the acceptance criteria are right, the steps are the implementer's to
choose.

## The one exception

If a prototype produced a snippet that carries a decision more precisely than prose can, inline it. A
state machine, a reducer, a schema, a type shape.

Trim it to the part that carries the decision. Not a working demo, just the shape that matters. Note
in one line that it came from a prototype, so nobody treats it as code to paste.

```
From the prototype, the settled leg shape:

  type SettledLeg = { position: number; runner: string; nonRunner: false }
                  | { position: null; runner: string; nonRunner: true }

The prototype found that position has to be nullable, because a non-runner has no finishing
position and using 0 made it sort first.
```

That is worth inlining. It records a decision and the reason. A twenty line render function is not.

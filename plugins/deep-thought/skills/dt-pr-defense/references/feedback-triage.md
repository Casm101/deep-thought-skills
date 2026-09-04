# Triage: verdicts and the evidence they need

One verdict per item. If two verdicts seem to fit, the item is really two items.

## The evidence standard

Before any verdict, you must have done all four:

1. **Located the code** the comment is about, and read it in its file, not just in the diff hunk.
2. **Traced the mechanism**: can you state, in your own words, the sequence that produces the
   behaviour the reviewer describes? For a claimed bug: what input, through which path, gives which
   wrong result?
3. **Checked the surroundings**: callers, types, tests, and whether some other code already prevents
   it. Half of all review disputes are settled by a guard clause one level up.
4. **Checked the clock**: was this comment written before a commit that changed the code it points
   at?

If you cannot complete step 2, you do not have a verdict yet. Say so instead of guessing.

Asymmetry to respect: **accepting a comment needs less proof than rejecting one.** To agree, it is
enough that the reviewer has a point. To disagree, you need something the reviewer can check and be
persuaded by.

## The verdicts

### `AGREE-FIX`

The comment is right and the fix belongs in this PR. Produces a work item, plus a one-line reply.

Includes the case where the reviewer is right by accident: their reasoning is off but there is a real
defect there. Fix the defect, and say what it actually was.

### `PARTLY-RIGHT`

The problem is real, the proposed remedy is not right for this repo. Or one part of a multi-part
comment holds and the rest does not.

Produces a work item for the part that holds, plus a reply that concedes the problem and explains
what you are doing instead, with the reason (a convention, a type, another caller, a simpler fix).
Never present this as a disagreement; you are agreeing about the problem.

### `ALREADY-DONE`

The code changed after the comment was written and the point no longer applies. Requires that you
have actually read the current code, not just noticed a later commit exists.

Produces a reply naming the commit or the current state, so the reviewer can re-read. No work item.

### `AGREE-OUT-OF-SCOPE`

The point is correct and worth doing, but not here: it predates this PR, it is a different concern,
or it would widen the diff in a way that makes the PR harder to review.

Produces a reply that agrees, says explicitly it is out of scope for this change, and proposes the
concrete next step (a follow-up ticket, a named separate PR). Do not promise a ticket the user has
not agreed to create. No work item in this plan, but list it in the plan's "deferred" section so it
does not evaporate.

### `NEEDS-INFO`

You genuinely cannot tell what is being asked, or the answer depends on intent only the reviewer has.

Produces a reply asking one specific question. Not "can you clarify?" but "do you mean X, or Y?" so
the answer takes them ten seconds. No work item until it is answered.

### `NIT-DECLINE`

An explicitly optional style preference you are choosing not to take. Legitimate, and cheap: a short,
warm reply that leaves the door open. Never argue a nit at length; the effort is worth more than the
nit is.

### `DISAGREE`

The comment is wrong. This is the highest bar in the file. Use it only when you have one of:

- **Code that contradicts it.** the guard, the default, the type, the caller that makes the described
  failure impossible. Cite `file:line`.
- **A test that proves the behaviour.** name the test and what it asserts.
- **A documented rule.** quote it from the repo, do not paraphrase.
- **A reachability argument.** the path they describe cannot be entered, and you can show why (the
  only caller passes a fixed value, the branch is behind a flag that is off, the function is not
  exported).

Not evidence: "this is the pattern we use elsewhere" without pointing at it; "it works in testing";
"that would never happen"; a general appeal to how the framework behaves without a version-specific
reference.

Even in a `DISAGREE`, ask whether the code that misled a competent reviewer should be clearer. If the
answer is yes, add a small clarity work item (a name, a comment explaining why, a narrowed type) and
mention it in the reply. That turns a dispute into a improvement and usually ends the thread.

## Multi-point comments

Split them. For each point, note where it came from so the reply can address several at once:

```
[T4] Swabisan, persist.ts:41  ->  item 1 (AGREE-FIX, data loss on deploy)
                              ->  item 2 (AGREE-FIX, fixture hides it, test change)
                              ->  item 3 (NIT-DECLINE, naming)
```

One reply per thread, covering that thread's points in the order the reviewer raised them.

## Duplicates and bots

- Merge items that make the same point from different threads into one work item, listing every
  source. Reply in each thread, briefly, pointing at where the fix lands.
- Bot findings get the same evidence standard. Their common failure is flagging a real pattern on an
  unreachable path, so the reachability check matters most. Their common success is spotting exactly
  the mechanical mistake a human skims past.
- Never mention that a reviewer is a bot, and never write a reply whose argument is that it is one.

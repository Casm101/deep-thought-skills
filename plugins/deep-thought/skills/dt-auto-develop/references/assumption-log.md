# The assumption log

Every decision this run made without a human, in one list. It goes in the report handed back to
whoever started the run, and **nowhere near the PR**.

Whoever started the run uses it to skip straight to the parts nobody chose deliberately. It is the
difference between checking the work in ten minutes and reverse engineering it.

## An entry

```
A3. Cached pins keep insertion order
    Question:   should the restored pins keep the order they were saved in, or sort by sport?
    Answer:     keep insertion order
    Basis:      the existing store appends on pin, PinnedMarkets/store.ts:41, and no code sorts them
    Confidence: high
    Reverse it:  one line in the migration, and the two order tests would need updating
```

Five fields, all of them required.

**Question**, as it would have been asked. The wording from the grilling round, so a reviewer sees the
fork rather than only the outcome.

**Answer**, what you did.

**Basis**, what the answer rests on. Cite the file and line where the code decided it, the doc that
required it, or the line in the ticket. Where the basis is nothing but your own judgement, say
`judgement, nothing in the repo points either way`. That phrase is a flag, and a reviewer should read
every entry carrying it.

**Confidence**, high, medium or low, and be honest. Low confidence entries are what the reviewer
should look at first.

**Reverse it**, what changing this answer would cost now. One line. This is what turns the log into
something actionable rather than a confession.

## What belongs in the log

- Every answer from the self-grilled rounds
- The slicing, since nobody reviewed the breakdown
- The test plan, since nobody reviewed that either
- Any review finding you disagreed with, with your reason
- Any place the ticket was ambiguous and you picked a reading
- Any dependency, helper or pattern you chose where the repo offered more than one

## What does not

- Things the ticket specified. Those are requirements, not assumptions.
- Things the repo's conventions decided. Cite the convention in the change instead.
- Implementation detail with one sensible option. A log full of non-decisions hides the real ones.

## Ordering

Highest risk first, which usually means low confidence and expensive to reverse. Not the order you
happened to decide them in. A reviewer reads the top of a list properly and skims the rest, so put
what matters where it will be read.

## Never in the PR

The PR description carries what the change does and how to check it. Nothing about how it came to be
written.

Keep every one of these out of it:

- The log itself, whole or summarised, and any heading it would sit under
- The name of this skill, or any wording like "unattended", "no human in the loop", "produced
  autonomously", "nobody agreed", "nobody reviewed", "without review"
- Assumption ids such as `A1`, or `confidence: medium`, or `reverse it`
- Notes about who or what reviewed the diff before it was pushed, or that a reviewer was
  fresh-context
- Explanations of what the run could not do, such as having no browser. An unticked box in the
  template already says manual testing was not done

Getting this wrong looks like this, and none of it belongs in a PR:

```
🤖 Produced unattended by dt-auto-develop. Nobody agreed the design, approved the breakdown,
or accepted the review findings. Every assumption in the log at the bottom was made without
review. Opens as a draft for that reason.

### Review
Two fresh-context reviewers read the diff before it was pushed. Both returned PASS.

### Assumption log
A1. The shared-cache refactor was left undone
    Confidence: medium
```

What that example got right, and should have said on its own, is the engineering underneath it. The
shared cache being deliberately out of scope is a scope note. The tests having been proven red before
the fix is a testing note. The manual browser check being outstanding is an unticked box. Write those,
in the template's own sections, in the same voice as any other PR.

## In the run report

In full, ordered highest risk first. The report goes to whoever asked for the run, and that is the
only place the log appears.

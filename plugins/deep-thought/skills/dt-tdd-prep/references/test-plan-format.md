# The test plan

One block per test, grouped by bucket, numbered so the user can approve or drop by number.

Keep each block short. The test itself carries the detail; the plan exists so the user can redirect
before any file is written.

## Header

```
Change:   arrow colour on odds movement, green/red becomes blue/yellow
Source:   dt-investigation report in this conversation, plus TS-42907
Seam:     the token lookup in TrendArrowIcon, chosen by movement direction
Runner:   cd apps/sportsbook-ui && pnpm test --run <file>   (vitest 4, node 24)
Gaps:     AnimatedOddsValue.tsx has a spec, styled.ts and OutcomeButtonDumb.tsx have none
```

## A test item

```
### A3. A decrease renders a down arrow

Bucket:    A, guard. Passes now, must still pass after the change.
File:      src/components/AnimatedOddsValue/__tests__/AnimatedOddsValue.spec.tsx  (add a case)
Behaviour: When the value goes from 2.50 to 2.10, an arrow appears pointing down.
Assert:    the down arrow is in the document, queried the way the existing cases query it.
Setup:     render with an initial value, rerender with the lower value. Fake timers as the
           neighbouring cases do.
Why:       nothing covers direction today, so a colour change could invert it unnoticed.
```

```
### B1. An increase renders the arrow in the blue token

Bucket:    B, new behaviour. Fails now, passes when the change lands.
File:      src/components/AnimatedOddsValue/__tests__/AnimatedOddsValue.spec.tsx  (new describe)
Behaviour: When the value increases, the arrow uses the blue theme token.
Assert:    the arrow's colour resolves to the blue token, not a hex literal.
Expected failure: receives the green token, expects blue.
Why:       this is the request. It is the one thing that must change.
```

Fields, all of them required:

- **Bucket**, with its colour now and after.
- **File**, and whether it is new or a case added to an existing file.
- **Behaviour**, in terms a user could check, with concrete values.
- **Assert**, what the expectation actually is.
- **Setup**, only what is not obvious: fixtures, fake timers, mocks, providers.
- **Expected failure**, for bucket B only. Name the failure you predict, so a different failure is a
  signal that something else is wrong.
- **Why**, one line. If you cannot say why the test earns its place, drop it.

## Bucket C, the list

No test blocks here. Just what the implementation will have to change:

```
### C1. AnimatedOddsValue.spec.tsx:74
Asserts the up arrow is green. The change has to update this to blue.
```

## Bucket D, one line each

```
### D1. Number formatting is covered by AnimatedOddsValue.spec.tsx:20-38. Nothing to add.
```

## Closing the plan

Three short lines:

- **Counts.** How many guards, how many new-behaviour tests, how many existing tests will need
  updating.
- **Order.** Which to write first if the user wants it split. Guards first, always: they are what
  makes the change safe to attempt.
- **Uncertain.** Anything you could not confirm from the code, and what would confirm it. This is the
  list the user is best placed to answer quickly.

## What the plan is not

Not the implementation, and not a design document for it. If, while planning, you work out how the
change should be built, keep it to the one sentence in the Phase 8 handover. Tests describe the
behaviour. Someone else decides the code.

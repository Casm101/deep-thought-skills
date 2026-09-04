# The loop

One slice, two checks, repeat. The slices are small because small slices localise a failure: when the
type check goes red after eleven lines, you know which eleven.

## A slice

The smallest change that moves one acceptance criterion toward met. Often that is one function, one
branch, one prop threaded through.

Not a slice: everything the criterion needs, written at once, then checked. That is the same work with
the feedback removed.

## After every slice

**The type check for the package you touched.** Cheap, fast, and it catches most of what you got
wrong. Run it before the test, because a type error usually explains the test failure you were about
to read.

**The one test file covering what you changed.** The `impl-loop.sh` output maps each changed file to
its test. Run that file, not the suite.

Where a slice touches two packages, check both.

## Reading the colours

**Types red.** Read the message, fix the cause. Never widen a type, add `any`, or reach for a cast to
make the message go away, unless the cast is the actual fix and you can say why in a comment.

**The new-behaviour test still red.** Expected until the slice that satisfies it. Check the failure
is still the assertion, and still the same assertion. A failure that changed shape means you moved
something you did not mean to move.

**A guard test red.** Stop. You broke behaviour the change was meant to leave alone. Do not adjust the
guard. Read it, understand what it was protecting, and fix the code. This is the signal the guards
exist for, and editing them to pass throws away the whole point of writing them first.

**A test you have never seen before goes red.** Same treatment as a guard. Something you touched
reaches further than you thought, which is worth knowing now rather than in review.

**Everything green and you are not done.** Next slice.

**Everything green and you think you are done.** Check every acceptance criterion against the tests.
A criterion with no test covering it is not met, it is assumed.

## When to stop and think rather than push on

- The same test has gone red for three different reasons. The design is fighting you, and another
  slice will not help.
- You are about to change a test to make it pass. Always stop here.
- The fix needs a change in a file the spec never mentioned. It may be right, and it may mean the
  seam is somewhere else.
- You cannot say which slice broke something. Slices got too big. Undo to the last green point and go
  smaller.

## What not to run in the loop

- The whole suite. Once, at the end.
- `-u`, `--updateSnapshot`, `--update`. A written snapshot records whatever the code does now as
  correct, which is the opposite of checking it.
- The dev server or a build, unless the change is one you can only see running. Then look once and go
  back to the loop.
- Formatters over files you did not touch. A reformatted file nobody asked about buries the real
  change in review.

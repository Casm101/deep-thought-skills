# Slicing

## The test for a vertical slice

A task is vertical when landing it alone changes what somebody can do. Not what the code contains,
what somebody can do.

Ask: if this task shipped on its own tonight and nothing else followed, would anyone notice? If the
answer is no, it is a layer, not a slice.

Layers, which are what to avoid:

```
1. Add the database column
2. Add the API field
3. Add the UI
```

Nothing works until all three land, nothing can ship on its own, and the first two cannot be tested
against anything real.

The same work sliced vertically:

```
1. A punter sees the finishing order on a settled forecast, for the simple two runner case
2. The same for a tricast, including the three runner permutations
3. The same when a leg has a non-runner
```

Each one is thin, each one crosses every layer it needs, and each one is worth landing by itself.

## Tracer bullets

A tracer bullet goes the whole distance, narrow and complete, so you learn whether you are aimed at
the target. The first slice picks the simplest real case, walks it through every layer, and gets it
working. Later slices widen it.

Pick the first slice for what it teaches, not for how easy it is. The case that touches the most
uncertain part of the design, in its simplest form, is the right first task.

## Blocking edges

A task blocks another when the second cannot start without the first. That is the whole test.

Real blockers:

- The second needs behaviour the first introduces
- The second reads a shape the first defines
- The first settles a decision the second is built on

Not blockers:

- Both touch the same file
- You would rather one landed first
- The same person will do both
- One is more important

Every false edge stops somebody working who could have started. Where two tasks could each go first,
neither blocks the other, and say so.

## The exception, wide refactors

A wide refactor is one mechanical change whose reach spans the codebase. Renaming a column, retyping
a shared symbol, moving a package everything imports. A single edit breaks thousands of call sites at
once, so no vertical slice can land green, and the usual rule stops helping.

Do not pretend it is a tracer bullet. Sequence it instead, so every step in the sequence leaves the
build green:

1. **Add the new thing beside the old one.** Nothing calls it yet. Nothing breaks. This lands on its
   own.
2. **Migrate the callers in batches.** One task per batch, sized so a reviewer can actually read it.
   Split by package, by feature, or by directory, whichever the codebase makes natural. Each batch
   leaves the build and the tests green.
3. **Remove the old thing.** Blocked by every migration batch, and the acceptance criterion is that
   nothing references it any more.

Say in the tasks that this is a sequenced refactor and that no step changes behaviour. A reviewer who
does not know that will look for the behaviour change and be suspicious when they cannot find one.

If the mechanical change is small enough that one edit keeps the build green, it is not a wide
refactor. It is one task.

## Pre-factoring

Where the code makes the real work awkward, the move that makes it easy is its own task. It comes
first and it has no blockers.

Two rules. It changes no behaviour, and its acceptance criteria say so, usually as "the existing tests
pass unchanged". And it earns its place by making a named later task simpler, which the task text
should state. A pre-factor that is really just tidying somebody else's code does not belong in this
breakdown.

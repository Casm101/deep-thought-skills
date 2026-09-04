# The four buckets

Sorting is the whole job. Get this wrong and you either write tests that block the change, or you
write nothing that would catch a regression.

## A. Guards

Existing behaviour that has to survive the change, and currently has no test.

These are the safety net. They pass now, and they must still pass after the implementation lands. If
one of them goes red during the change, the change broke something it was not supposed to touch.

Ask: if someone rewrote this file badly, what would a user notice? Each answer is a guard.

## B. New behaviour

What the change introduces. Written now, failing now, passing when the work is done.

These are the specification. A reviewer should be able to read your bucket B tests and know what was
asked for without reading the ticket.

## C. Will need updating

Existing tests that assert the exact behaviour the change replaces.

Find them, list them with file and line, and leave them alone. Two reasons. They still describe the
product as it ships today, so breaking them early hides real regressions. And the edit that flips
them is the clearest evidence in the diff that behaviour changed on purpose.

Never pre-emptively rewrite them to expect the new behaviour. That turns bucket B green before any
code exists, which defeats the point.

## D. Already covered

Behaviour with a test that is good enough. Say so and move on.

Check before you trust it. A test that renders the component and asserts it did not throw is not
coverage of the behaviour you care about. The recon script's "same name elsewhere" line is a common
source of false comfort.

## The odds arrow example, worked through

The feature request: arrows that appear when an odds value moves. Today up is green and down is red.
A later change wants blue and yellow.

First, establish what exists. Say the investigation finds the value renders through
`AnimatedOddsValue`, the arrow through a `TrendArrowIcon`, and the colour is chosen from a theme
token by the direction of the change. The seam is the token lookup.

Now sort:

**Bucket A, guards.** All of this must keep working, and none of it has anything to do with colour:

1. No arrow renders when the odds value is unchanged.
2. An up arrow renders when the value increases, pointing up.
3. A down arrow renders when the value decreases, pointing down.
4. The displayed value updates to the new odds, whatever the arrow does.
5. The arrow clears after the animation window, so it does not stick around forever.
6. A value arriving with no previous value renders no arrow rather than a wrong one.

Those six are the real prize. They are what stops a colour change from accidentally breaking arrow
direction, and they hold for both colour schemes, before and after.

**Bucket B, new behaviour.** Only the part that actually changes:

1. An increase renders the arrow in the blue token.
2. A decrease renders the arrow in the yellow token.

Both fail today, and they fail on the assertion, showing green where blue is wanted.

**Bucket C, will need updating.** Any existing test asserting green or red, for instance an
`AnimatedOddsValue.spec.tsx` case that checks the up arrow's colour. List it. The implementation
updates it, and that line in the diff is the behaviour change made visible.

**Bucket D.** Whatever the existing spec already covers well, such as the number formatting.

Notice the split. Direction, presence, timing and value are guards, because they must not change.
Colour is bucket B, because it must. Sorting by "what must stay true" against "what must become true"
is what keeps the two sets from contradicting each other.

## What to assert

**Assert what someone can observe.** Rendered text, roles, labels, which element appears, what a
callback receives, what the store holds afterwards. Not internal state, not private helpers, not how
many times a hook ran.

**Assert against the repo's own vocabulary for the thing.** If colour comes from a theme token,
assert the token, not a hex string a designer may retune next week. If the repo exposes a data
attribute for exactly this, use it. Copy whatever the neighbouring tests do.

**Pick the level that matches the seam.** If the change is in a pure function, test the function. If
it is in what a component renders, render the component. Do not write a full page integration test to
cover a token lookup, and do not unit test a helper when the behaviour only appears once it is wired
up.

**One behaviour per test.** The name says the behaviour, the body proves it. If the name needs "and",
split it.

**Make it fail for the stated reason.** Before you accept a bucket B test, imagine the implementation
that would satisfy it. If some unrelated change could also turn it green, tighten it.

## Traps

- A test that passes whether or not the element exists. Query in a way that throws or asserts
  presence explicitly.
- Asserting on a mock you set up yourself, which proves your mock works and nothing else.
- Copying a snapshot as a way to avoid deciding what matters. A snapshot covers everything and
  therefore says nothing about intent, and it goes stale on any nearby edit.
- Testing the framework, for example that a prop you pass arrives as that prop.
- Time and animation. If behaviour depends on a timer, control the clock the way the repo's existing
  tests do rather than waiting.

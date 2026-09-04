# Proving the before and after identical

Three rungs. The first is mandatory and is the actual proof. The other two confirm it against a real
renderer.

## Rung 1. The declaration inventory

Write it **before** migrating, from the styled source, then complete the right-hand side afterwards.

```
FinalStat.styled.tsx → FinalStat.styles.ts

StyledFinalResultText  (span)
  font-family      var(--font-family)        → font-app
  font-size        12px                      → text-size-12
  line-height      16px                      → leading-lh-16
  font-style       normal                    → carried by the text utility
  color            var(--colors-text-secondary) → text-text-secondary
  font-weight      500                       → font-medium
  font-stretch     normal                    → DROPPED, no ancestor sets it
  letter-spacing   normal                    → DROPPED, no ancestor sets it

StyledFinalStat  (span)
  …
```

Rules.

**Every declaration gets a right-hand side.** A utility name, or `DROPPED` with a reason. A line with
nothing beside it is an unfinished migration, not a tidy one.

**Expand the mixins.** The inventory is of declarations produced, not of source lines. A `text*` mixin
is four to eight declarations, and the ported utilities emit only font-family, font-size, line-height
and font-style. The rest is where parity is lost.

**The four usual suspects.** `color`, `font-weight`, `font-stretch` and `letter-spacing` are dropped
by the ported utilities. Each one is either replaced by an explicit utility or recorded as a drop with
the reason it is safe. "No ancestor sets it" is a reason. "Probably fine" is not.

**A drop is a claim about ancestors.** Dropping `color` means an ancestor's colour is now inherited.
Check what that ancestor actually sets before calling it safe, because inheriting the right value by
luck today is a bug waiting for a parent to change.

**Raw values stay raw.** A `16px` in the original becomes `w-[16px]`, not `w-16`, unless 16 is
genuinely the token. Preserving debt greppably is the instruction; quietly upgrading it is a
behaviour change hiding in a migration.

## Rung 2. The computed-style diff

Where a browser is available, this turns the inventory from an argument into a measurement.

Run Storybook, open the component's story, and capture the computed styles of the node before the
migration:

```js
const el = document.querySelector('[data-testid="finalStat"]');
const before = {};
const cs = getComputedStyle(el);
for (const p of cs) before[p] = cs.getPropertyValue(p);
JSON.stringify(before);
```

Keep that. Migrate. Capture the same object again and diff them.

What to expect. An empty diff is the goal. Differences in properties nobody set, and in shorthand
expansions, are noise. Any difference in a property that appeared in the inventory is a real
regression, and the inventory tells you which line caused it.

Do this on the node the styled component owned, not its parent. The class moved, and so did the
element that carries it.

## Rung 3. Storybook across the five brands

The last check, and the only one that catches a token resolving differently per brand.

Open the story and step through every brand in the Theme toolbar. One bundle serves all five, and the
utilities carry `var(--colors-…)` references that resolve at the element inside the wrapper, so a
token that exists in one brand's theme and not another shows up here and nowhere else.

If the component has no story, say so in the report. It means this rung was not run and the migration
rests on rungs 1 and 2.

## What none of these catch

**A test cannot check this.** happy-dom does not apply stylesheets and Tailwind ships a static one, so
`toHaveStyle` sees nothing. A render test can observe that a class is present and never that it
resolves to a declaration. Do not write a test that looks like it verifies the pipeline; that job
belongs to the repo's own compile spec.

**A green build proves nothing about classes.** An off-token utility, a misspelling, or a class in the
wrong file all compile to nothing with exit code 0. The build is not a check here.

**Layer order protects you only from your own side.** Utilities are layered, unlayered CSS wins, and
that is what makes migration safe one file at a time. It also means an unlayered class shipped by the
host or a remote beats yours. Nothing local detects that.

## The report

Per component:

```
Component        FinalStat
Declarations     18 accounted for, 16 reproduced, 2 deliberate drops
Drops            font-stretch, letter-spacing, no ancestor sets either
Computed diff    empty on the migrated node
Brands           checked all five in Storybook, no difference
Gate             type-check, lint, 12 tests, all green
Stylesheet       entry CSS +214 bytes, budget unchanged
Left behind      nothing
```

Where a rung was not run, say which and why, rather than leaving the reader to assume all three were.

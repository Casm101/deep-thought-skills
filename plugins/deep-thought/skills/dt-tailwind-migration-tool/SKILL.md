---
name: dt-tailwind-migration-tool
description: Migrate a component from styled-components to Tailwind, one at a time, with the before and after proved identical. Screens the component for the blockers that make it unmigratable today, reads the repo's own migration guide as the source of truth, writes the styles sibling, rewrites the component, updates the tests, then accounts for every CSS declaration the old version emitted before running the gate. Use when asked to migrate a component to Tailwind, or for the "dt tailwind migration tool".
argument-hint: "component name or path, or several"
---

# dt-tailwind-migration-tool

Move one component from styled-components to Tailwind without changing a pixel.

Two properties of this migration make it easier and more dangerous than it looks. Tailwind utilities
sit in `@layer utilities`, so unlayered styled-components always wins and adding Tailwind can never
silently restyle an existing node. And an off-token or misplaced class compiles to **nothing**: no
rule, no warning, an unstyled element and a green build.

So the build will not tell you when you get it wrong. The declaration inventory in Phase 5 is what
tells you.

## The source of truth is in the repo

`apps/sportsbook-ui/TAILWIND_MIGRATION.md`. Read it before writing a single class, every time.

It carries the token to utility table, the house idiom mappings, the `*.styles.ts` plus `cva`
convention, the testing rules, and the list of what cannot be migrated. It is maintained with the
code. Never work from a remembered version of those tables, and never copy them anywhere, because a
copy goes stale while the original stays right.

This skill covers what that guide does not: screening before you start, and proving the result
identical afterwards.

## Phase 1. Screen it

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-tailwind-migration-tool/scripts/migration-scan.sh <component>
```

It finds the component, its styled file, its tests and its stories, then reports blockers, hazards, a
declaration count, and the gate command.

`RESULT: BLOCKED` means stop and say why. The blockers are real and they are the guide's, not this
skill's:

| Blocker | Why |
|---|---|
| `applyFont` | Not bridged. The composed font sets are a separate piece of work, and spelling them out with arbitrary values is the debt this migration exists to remove |
| Breakpoints | Variants silently never match on iOS 16.0 to 16.3, so the element renders at its unprefixed size |
| `.attrs()` | Move the attributes onto the JSX element by hand first |
| `keyframes` from runtime props | Needs a static `@keyframes` plus a style variable |
| `styled(External)` | Only works if that component forwards `className`. Check, do not assume |
| Anything in tiger-components or an MFE | Out of scope for this migration |

Refusing is a good outcome. Around forty files use `applyFont`, and improvising one of them makes a
decision that belongs to a single set-level change.

## Phase 2. Take one component

Even when given several. Queue them, migrate one fully through the gate, then start the next.

A half-migrated batch is worse than one finished component, because the gate is per component and a
red suite in the middle leaves you unable to tell which change caused it.

## Phase 3. Inventory the old styles first

Before writing any Tailwind, write down every CSS declaration the styled version produces. Property,
value, and which element it lands on. `references/verification.md` has the format.

Do this first, not afterwards. An inventory written after the fact is a description of what you did,
and the thing you need is a description of what was there.

Include what the mixins expand to. A `text*` mixin emits four declarations the ported utilities
deliberately drop, so those four are the ones most likely to go missing.

## Phase 4. Write the migration

Follow the guide's conventions exactly. The ones that catch people:

- Classes live **only** in `*.styles.ts`. A class anywhere else compiles to nothing, silently.
- `cva` always, even with no variants, so a component gaining its first variant changes nothing else.
- Whole literal class strings. An interpolated fragment never compiles.
- No `className` prop across component boundaries, and no `cva` `class`/`className` argument. One
  element, one owner.
- `cn` joins and drops falsy entries. It does **not** resolve conflicts, so two utilities from the
  same family both land and source order decides.
- A raw hex or px in the original is pre-existing debt: preserve it as an arbitrary value so it stays
  greppable. Never invent a token to tidy it up.

Then delete the `*.styled.ts`, drop the `Styled` name prefix, and update the barrel and imports.

## Phase 5. Prove it identical

`references/verification.md`, three rungs, and the first is mandatory.

**The declaration inventory** is the proof. Every line from Phase 3 is either reproduced by a named
utility or recorded as a deliberate drop with a reason. Nothing is unaccounted for. This catches the
four silent drops, `color`, `font-weight`, `font-stretch` and `letter-spacing`, which are the most
common way a migration looks right and renders wrong.

**The computed-style diff** confirms it where a browser is available. Capture `getComputedStyle` on
the node in Storybook before and after, and diff the two.

**Storybook across all five brands** is the last check, and the only one that catches a token that
resolves differently per brand.

## Phase 6. Tests and the gate

Update the tests where the mechanism changed. `toHaveStyle` becomes `toHaveClass`, because happy-dom
does not apply stylesheets and Tailwind ships a static one rather than injecting at runtime.

That swap is expected. **Anything else going red means behaviour changed**, and that is a stop, not
something to fix by adjusting the test.

Then the gate:

```bash
pnpm type-check && pnpm lint && pnpm test --run <path>
```

And check the entry stylesheet's `size-limit` budget. Every migration grows it, so growth is expected,
but it should be a deliberate line in the diff rather than silent drift. Raise it consciously or not
at all.

## Phase 7. Report

Per component: what moved, the declaration inventory with every line accounted for, what was
deliberately dropped and why, what the gate said, what the stylesheet budget did, and anything you left
on styled-components with the reason.

Then the next component in the queue, or stop.

## Never

- Write a class outside a `*.styles.ts` file
- Invent a token to replace a raw value, or reach for an arbitrary value to avoid a token that exists
- Spell out `applyFont` with arbitrary values
- Add a breakpoint variant while the iOS target is below 16.4
- Hand-edit the generated theme file, or add `important`, or re-enable preflight
- Change behaviour during a migration. This is no-behaviour-change work
- Migrate a second component before the first one is through the gate
- Claim pixel parity without the inventory

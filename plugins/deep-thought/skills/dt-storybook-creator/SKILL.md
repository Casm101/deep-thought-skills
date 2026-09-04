---
name: dt-storybook-creator
description: Write a Storybook story for a component, following the repository's own guide. Screens the component first, because roughly half of what gets asked for should not have a story at all, then derives the states from the component's props rather than a checklist, writes the file in the canonical location, and verifies it by running the gate and looking at it. Use when asked to create or add a Storybook story, or for the "dt storybook creator".
argument-hint: "component name or path"
---

# dt-storybook-creator

Write the story the component deserves, or explain why it does not deserve one.

The second half of that sentence is most of the work. About half of what people ask for is a screen,
a skeleton sibling, or a provider with no output of its own, and a story for any of those makes the
sidebar worse for everyone.

## The source of truth is in the repo

`apps/sportsbook-ui/src/test/STORYBOOK_GUIDE.md`. Read it before writing anything, every time.

It carries the two-table decision on whether a component needs a story, the file location, the house
`meta` shape, the required states, what the environment provides and does not, and which exemplars to
copy. It is maintained with the code, so never work from a remembered version and never copy its
tables anywhere.

This skill adds the screening, the state derivation, and the verification.

## Phase 1. Screen it

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-storybook-creator/scripts/story-scan.sh <component>
```

It reports whether a story already exists, then every Step 1 and Step 2 signal it can detect with the
evidence for each, what the story will need from the environment, the component's props, the exemplars,
the target path and the gate.

**Step 1 beats Step 2**, and a Step 1 hit means stop. Say which rule and why, and do not write the
file. The common ones:

| Hit | What to say instead |
|---|---|
| A hook, or no JSX | Not a component. Nothing to look at |
| Router-mounted, or `*Layout` / `*TabContent` / `*Page` | It is a screen. Story the widgets it arranges |
| Owns the page chrome | Same. Its content is arrangement |
| A `Skeleton*`, `Empty*` or `*Error` sibling | It belongs in the parent's story file as an exported state |
| Two or more store modules | `parameters.initialState` seeds Redux only, so those cannot be seeded |
| Only prop is `children` | One visual form, nothing to compare |

**Neither table hitting also means no story.** The guide is explicit: do not add one for completeness.

Treat the script's output as signals, not a verdict. Two of its checks cannot be mechanical. Whether a
component joins unrelated verticals needs reading it, and the Redux slice count is reported with
evidence precisely because an imported selector is not a slice that `initialState` must preload.

## Phase 2. Derive the states

From the component, not from a checklist. Read its props, its branches and its siblings, then work out
which of the guide's required states actually apply. `references/writing-the-story.md` has the
derivation and the traps.

Two that get skipped and should not:

**Default**, always.

**Overflow**, always, when any displayed text or item count comes from the API or the CMS. This is
where the layout bugs are. The guide names two tickets that exist because of it.

And one that gets done wrong: a **loading** state is an exported story, not an arg default. A `loading`
control that defaults to false puts the skeleton nowhere a reviewer can link to.

## Phase 3. Write it

`__stories__/ComponentName.stories.tsx`, beside the component. `.stories.ts` only when there is no
JSX. Fixtures, mocks and assets the story needs go in that folder too.

Copy the **structure** of the exemplars the scan names, and read
`references/writing-the-story.md` for what not to copy from them, because both carry known flaws that
get imitated.

Comments follow the repo's own rule: default to none, one short line where the why is not obvious. The
guide warns that its own exemplar is the most heavily commented story file in the repo and should not be
read as licence.

## Phase 4. Verify

```bash
pnpm type-check && pnpm lint && pnpm test --run src/test/stories.spec.tsx && pnpm build-storybook
```

Then **look at it**. Open the story, step through the themes on the toolbar, and check the overflow
state actually overflows.

The smoke test only catches synchronous throws and never runs `play`, so passing it means the file
composed under happy-dom, not that it loads. A story that renders an empty box passes it, and so does
one that breaks the browser build. `build-storybook` is the gate that proves Storybook can actually
build the file, which is why it is in the command above and not optional.

## Phase 5. Report

Which states you wrote and why each exists. What you could not produce and why, a query error being the
usual one, since the cache can only be seeded with success data. Whether you looked at it, and in which
themes. Anything you left for a person.

If you refused, the rule and the evidence, and what to story instead.

## Never

- Write a story for a component that hits Step 1, however small the file would be
- Add a story for completeness when neither table hits
- Put a story anywhere but `__stories__/`, for a new file
- Move an existing story that you are not otherwise editing
- Write a `Skeleton*` or `Empty*` component its own story file
- Ship a `loading` arg without an exported story that uses it
- Write a per-story spec unless asked. The global smoke test already renders every story
- Claim you checked it without opening it
- Edit `.drone.yml`, even though the guide notes `sonar.exclusions` should gain the story folder. That
  is a repo-level change, not part of writing one story

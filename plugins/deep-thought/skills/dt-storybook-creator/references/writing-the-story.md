# Deriving the states, and writing the file

The guide holds the `meta` shape and the required-states table. This is how you get from a component
to the right list, and what the exemplars get wrong.

## Derive, do not tick

Read the component and answer these. Each answer produces a state or does not.

**What does it look like with nothing unusual going on?** That is Default, and it is always there.

**Which of its props change what you see?** Every boolean and every union prop is a candidate branch.
A prop that only changes a callback or an id is not. Group them: three booleans do not mean eight
stories, they mean the two or three combinations that a reviewer would actually want to compare.

**Where does its text and its item counts come from?** If any of it comes from the API or the CMS, an
overflow state is required. Long team names, a market name that wraps, twelve items where the design
assumed three. This is the state most often skipped and the one that catches the most bugs.

**Does it have a `Skeleton*`, `Empty*` or `*Error` sibling?** Then that sibling does not get its own
story file. It becomes an exported story here, with a `render` that swaps in the sibling.

**Can it be handed zero items?** Then an empty state.

**Does it take its error state as a prop?** Then an error state. A *query* error is out of scope,
because a seeded cache can only hold success data, so there is no way to produce one deliberately. Say
that in the report rather than faking it.

**Does a theme change it materially?** The toolbar covers themes for free, so pin a theme on a story
only when one theme differs in a way worth linking to.

**Does the brand change the rendering?** Then a config decorator, and only then.

## Combinations, not permutations

Three booleans is eight combinations and almost never eight stories. Pick the ones a person would
compare side by side, and name them for what they show rather than for their args.

```
good  LongTeamAndMarketNames
good  Loading
good  NoImage
bad   IsSwipeableTrueIsActiveFalse
bad   Variant3
```

A story name is a label in a sidebar. It should read as a situation.

## The environment, briefly

No MSW. So a story is driven by props, by `parameters.initialState` which seeds **Redux only**, or by a
seeded React Query cache. Feature flags need `parameters.featureFlags`. Brand needs a config decorator.

Two consequences worth holding on to. A component whose state lives in Zustand cannot be seeded at all,
which is why it is a Step 1 hit rather than a hard story to write. And there is no per-story locale
switch, so label length is covered by passing long strings rather than by changing language.

## What not to copy from the exemplars

Both named exemplars carry flaws the guide is explicit about, and both get imitated.

**`AnnouncementBanner.stories.tsx`**, the structure exemplar. Copy its state list and its shape. Do
not copy two things: it sets no `component`, so nothing links its stories back to the component it
renders, and at roughly 14% comment lines it is the most heavily commented story file in the repo,
around double the normal density. It reads as licence for multi-line JSDoc and long description prose.
It is not.

**`PrebuildBetCard.stories.tsx`**, the skeleton-toggle exemplar. Copy the mechanism, a `loading` arg
whose `render` swaps in the `Skeleton*` sibling. Do not copy the file: it never exports a story with
`loading: true`, so the skeleton appears nowhere; it sits in the legacy co-located spot rather than
`__stories__/`; and it repeats `tags: ["autodocs"]` where the meta already has it.

## Before you call it done

Run the gate, then open it. The specific things to look at:

- The overflow story actually overflows. A long string that happens to fit proves nothing.
- Every exported state renders something. An empty box passes the smoke test.
- The themes on the toolbar, at least the default and one other.
- The skeleton story shows the skeleton, not the loaded component.

The smoke test and `build-storybook` fail on different things, which is why the gate runs both. The
smoke test composes the story in vitest under happy-dom, where node builtins resolve; `build-storybook`
bundles it for a browser, where they do not. So a story that reaches a fixture built for node test
setup passes the smoke test and fails the build, and the error names the bundler rather than the
fixture. If the build breaks on a story that composed fine, look at what the story imports before
looking at the story.

Then say in the report what you looked at and what you did not. "Checked in Storybook" without saying
which states and which themes is not a check anyone can rely on.

# Review axes

Consider every axis. Most will produce nothing on a given PR. That is expected. Silence on an axis
is a result, not a skipped step. Only report what you can point at in the diff.

## 1. Does the change make sense

- Does the diff do what the PR title, description, and linked ticket say it does? Anything extra
  in here that belongs in its own PR?
- Is the problem solved at the right level, or is this a workaround over a cause somewhere else?
- Is there dead weight: unused code, commented-out blocks, stray debug logging, leftover TODOs,
  committed `.only` / `.skip` in tests, temporary files?
- Does an existing helper, hook, or util already do this? (Search before claiming duplication.)
- Is anything missing that the change implies: a migration, a feature flag, a translation key, a
  doc or config update, a matching change in a sibling package?

## 2. Correctness

- Edge cases: empty, zero, one, null/undefined, very large, unicode, duplicate, out-of-order.
- Error and failure paths: what does the user see when the request fails? Are errors swallowed?
- Async: races, missing `await`, unhandled rejection, stale closure, missing cleanup or
  cancellation, effects that fire more or less often than intended.
- Boundaries: off-by-one, inclusive vs exclusive ranges, timezone and date handling, rounding on
  money or odds.
- Types: `any` or a cast used to silence the compiler rather than to state a fact; a type that now
  lies about the runtime value; non-null assertions on values that can be null.
- State: mutation of shared or props data, derived state that can drift from its source.

## 3. Repo standards and style

Judged against the standard from Phase 2, not against personal preference.

- The documented rules of this repo. Cite the document when you invoke one.
- Layering and module boundaries: does this import across a boundary the repo keeps separate?
- Naming and file placement consistent with neighbours.
- The repo's chosen approach for the thing being done (data fetching, state, styling, i18n) rather
  than a second parallel approach introduced here.
- Anything that will trip the repo's own lint, format, or type gates.
- Values that should be tokens, constants, or config rather than literals.

## 4. Architecture and design

- Coupling: does this reach into another module's internals? Does it add a new dependency between
  layers?
- Abstraction level: premature generalisation on one caller, or copy-paste where the pattern is
  now clearly established?
- Exports: is a newly exported symbol meant to be public? Is a breaking change to an existing
  signature handled at every call site?
- Complexity that could be removed rather than documented.
- Performance where it plausibly matters: work inside a render or a loop, N+1 requests, unbounded
  growth, a payload or bundle that grows with no bound. Do not speculate without a mechanism.

## 5. Testing and quality

- Is the new behaviour tested at all? Are the bug's own reproduction conditions covered?
- Do the tests assert behaviour, or do they assert implementation detail and mocks?
- Do they follow the repo's test conventions and file placement?
- Would these tests fail if the change were reverted? (If not, say so. That is a real finding.)
- Are the failure paths and edge cases from axis 2 covered, or only the happy path?
- Do CI checks pass? If `gh pr checks` reports failures, read them. A failing gate is the first thing
  to raise, and it outranks style commentary.

## 6. Safety and data

- Secrets, tokens, keys, or real customer data in code, fixtures, logs, or snapshots.
- User input reaching a sink unescaped; `dangerouslySetInnerHTML` and equivalents.
- Authorisation checks removed, weakened, or client-side only.
- New third-party dependency: is it needed, maintained, and licence-compatible? Does the repo
  already have something equivalent?
- Logging that leaks personal data.

## 7. The human layer

- Readability: would a teammate understand this in six months without the PR thread?
- Comments that explain *why* where the code cannot; no comments that merely restate the code.
- Anything that is genuinely good. Mention it once in the summary, and do not pad the review with it.

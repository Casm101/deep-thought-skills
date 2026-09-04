# The change plan

One work item per thing to change. Written so that implementing it needs no further decisions and no
second reading of the review.

Order the items so dependencies come first, and number them `1..n` in that order. The user will
approve, reorder, or drop them by number.

## The shape of an item

```
### 1. Seed the Zustand store from the legacy persisted blob

Source:    [T4] Swabisan, apps/sportsbook-ui/src/store/persist.ts:41  (verdict: AGREE-FIX)
           also raised in [C1] point 1
Severity:  blocker  (silent data loss for every existing user on deploy)
Effort:    M
Depends on: nothing

**What is actually wrong.** `migratePersistedState` stopped extracting `program`, and `flush` now
writes `{}` over `persist:tiger:<APP_NAME>` (`store/persist.ts:41,58`). The new store reads
`tiger:pinnedMarkets` at `version: 1` with no `migrate` (`PinnedMarkets/store.ts:112`). There is no
read path from the old blob and the old blob is overwritten, so pins that exist in production today
are lost and unrecoverable. Confirmed by reading both files; nothing else reads the old key
(`rg 'persist:tiger'`).

**Requirements.**
1. On first load after deploy, pins stored under the legacy key are read and written into the new
   store, preserving sport type and market ordering.
2. The legacy blob is cleared only after a successful import, so a mid-flight failure does not lose
   the data.
3. A user with no legacy blob is unaffected: no error, no empty write, no console noise.
4. Importing runs exactly once. A second load does not re-import or resurrect pins the user has since
   removed.
5. The old key is not written to again by any path.

**Files to touch.**
- `apps/sportsbook-ui/src/features/sports/PinnedMarkets/store.ts`, to add `migrate` for `0 -> 1`, or
  a one-shot import in the store's init.
- `apps/sportsbook-ui/src/store/persist.ts`, to stop overwriting the legacy key before the import
  has run.

**Approach.** Prefer the persist middleware's own `migrate` hook over a bespoke import in
`persistInit`: it runs before the first read, it is versioned, and it keeps the migration next to the
store it fills. Read the legacy key, map `{program:{pinnedMarkets}}` into the new shape, then clear.

**Tests.**
- Change: `store/__mocks__/persist.mock.ts` currently has `"program":"{}"`, which is why nothing
  fails today. Restore a populated `pinnedMarkets` fixture. This is the test that should have caught
  it.
- Add: legacy blob present, store empty, load once, pins appear in the new store with order intact.
- Add: legacy blob absent, load, store stays empty and nothing throws.
- Add: import runs, user unpins everything, reload, pins stay gone (requirement 4).
- Must fail first: run the new tests against the current code and confirm they fail before the fix.

**What this can break.** Persistence init runs for every user on every load, so a mistake here is
worse than the bug. Keep the import defensive. Wrap the parse, and treat a malformed blob as absent.

**Not doing.** Not migrating anything else out of the legacy blob. Out of scope for this PR.
```

## Rules for writing items

- **Requirements are checkable statements, not intentions.** "Handles the error case" is not a
  requirement. "A 500 renders `<ErrorPanel/>` and the retry re-runs the query" is.
- **Every claim about the current code cites `file:line`**, and you have read that line.
- **Tests are part of the item, never a separate afterthought.** Name the case that must fail before
  the fix. An item that cannot fail a test first needs a sentence explaining why (a type-level fix, a
  build config change).
- **Say what you are not doing.** The scope boundary is what stops the item sprawling.
- **Effort is S, M, or L**, and it is your honest read, not an encouragement.
- **Severity** uses the reviewer's stakes, not yours: blocker, should-fix, nit.
- If two reviewers asked for the same thing, list both sources on the one item.

## Sections around the items

**Order.** A short list, `1, 3, 2, 4`, with one line on why anything moved.

**Deferred.** Every `AGREE-OUT-OF-SCOPE` item: one line each, plus what the follow-up would be. This
is where good points go so they are not lost, without widening this PR.

**Declined.** Every `DISAGREE` and `NIT-DECLINE`, one line each, with the evidence in brief. The user
needs this to sanity-check the replies before approving them.

**Open.** Every `NEEDS-INFO` item, with the question being asked.

## What this plan is not

It is not an implementation. Do not edit files, do not write patches into the repo, do not run
formatters or tests. When the user has read the plan and wants it built, that is a separate request,
and they may want a different tool or a fresh session for it.

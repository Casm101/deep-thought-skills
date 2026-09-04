# What earns a comment its place

One test. **Would a competent reader of this code be missing something without it?**

Not "is it true". Not "is it harmless". A comment that is true and harmless still costs every future
reader a decision about whether it is still true.

## Delete

### Process history

Why the change was made, who asked, what it replaced. This is what a commit message and a PR are for,
and it is the single most common thing an agent leaves behind.

```ts
// Added for TS-42830
// Changed from Redux to Zustand as requested in review
// Previously this used a hardcoded date range
// Fix for the bug reported by QA in staging
// Updated per the ticket's acceptance criteria
```

All of it goes. The ticket lives in the PR, the previous approach lives in git, and the review
conversation lives on the PR.

### Ticket ids and issue references

`TS-42830`, `JIRA-123`, `#456`, a branch name. A ticket id in source is a dead link within a year and
tells the reader nothing about the code in front of them.

The exception is a comment that names a live external constraint, and even then it names the
constraint rather than the ticket: `// the odds feed sends 0 for a suspended market` rather than
`// see TS-41002`.

### Third-party links

Stack Overflow answers, blog posts, library issue threads, MDN pages.

```ts
// Solution from https://stackoverflow.com/questions/12345
// See https://github.com/some/lib/issues/987
// Based on this article: https://blog.example.com/...
```

Links rot, the page changes, and the reader still has to work out what the code does. If the link
carried a fact, write the fact.

The narrow exception is a link to a spec or a standard that the code implements, where the document is
stable and normative: an RFC section, a payment scheme rule, a browser bug that is still open and still
the reason for a workaround.

### Restating the code

The largest category by volume, and the easiest to spot: read the comment, read the line, and if they
say the same thing, delete the comment.

```ts
// Set the loading state to true
setLoading(true);

// Map over the items and return their ids
const ids = items.map((i) => i.id);

// Early return if there is no user
if (!user) return null;

/**
 * @param name The name
 * @param id The id
 * @returns The result
 */
```

A docblock that only names the parameters again is a restatement with extra lines.

### Banners and section headers

```ts
// ============================
// HELPERS
// ============================

// --- state ---
// #region handlers
```

The file structure is the structure. If a file needs signposting to navigate, it needs splitting.

### Narration of the obvious

```ts
// Destructure the props
// Import the hook
// Close the modal
// Loop through each result
// Return the component
```

### Apologies, hedges and future promises

```ts
// This is a bit hacky but it works
// Not sure if this is the best way
// TODO: refactor this later
// Might need to revisit this
// Temporary workaround
```

A `TODO` with no owner and no ticket is a wish. If the work matters it belongs in the tracker; if it
does not, it does not belong in the file either. A `TODO` that already carries a live ticket id is the
one case for keeping it, and it keeps the id.

### Commented-out code

Always. Every time. Git has it, nobody will ever uncomment it, and it makes the file unsearchable
because dead code still matches a grep.

## Keep, and rewrite to the shortest true version

### A constraint the code cannot state

```ts
// The API returns finishing positions 1-indexed
// A non-runner has no position, so null rather than 0
// Suspended markets arrive with odds of 0, not null
```

This is the reason comments exist. The code shows what happens; only the comment can say why the shape
is that way.

### An ordering or timing requirement

```ts
// Must run before hydration or the store reads empty
// Registered after the bus so the first event is not missed
```

### A workaround for something outside this codebase

Name what is broken, not where you read about it.

```ts
// Safari fires this twice on a touch device, so ignore the second
// The SDK throws when called before init, and init is async
```

### A non-obvious unit or format

```ts
// milliseconds
// minor units, so 1050 is 10.50
// UTC, the API has no timezone
```

Short, factual, and it saves a reader a trip to the API contract.

### A deliberate omission

Where the obvious next thing is missing on purpose, and its absence looks like a bug.

```ts
// No error branch: the caller already has a boundary for this
// Not memoised, the input changes every render anyway
```

### Public API documentation

Docblocks on exported functions and types stay, because tooling and editors read them and consumers
outside the repo rely on them. Unslop the prose inside them, delete `@param` lines that only repeat the
parameter name, and keep the ones that say something.

## Test descriptions

A `describe` or `it` string is prose that people read in CI output, so it gets the same treatment.

```ts
// before
it('should correctly handle the case where the user is not authenticated and returns null', ...)
// after
it('returns null when nobody is signed in', ...)
```

Present tense, no "should", no "correctly", say the behaviour. One exception: leave the name alone if
the test has a snapshot keyed on it, because renaming orphans the snapshot and this skill never
updates snapshots.

## Judging borderline cases

**When the comment is half good**, keep the half that states a fact and delete the half that tells the
story.

```ts
// before
// We changed this to use getMonth() because the old hardcoded 2025 dates meant
// the feature was dormant in any other year, as reported in TS-43533.
// after
// Matches any December, not a fixed year.
```

**When you cannot decide**, ask whether the comment would survive being read by someone who has never
seen the ticket, the PR, or this conversation. If it only makes sense with that context, it goes.

**When the code is unclear and the comment is carrying it**, the comment stays. Making the code clear
enough to lose the comment is a refactor, which is out of scope here. Note it for the user instead.

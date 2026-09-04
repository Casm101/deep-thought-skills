# Report structure

Two shapes: one for a whole-repo investigation, one for a focused subject. Drop a section only
when the repo genuinely has nothing for it, and say so rather than deleting it silently.

Cite files as `path/to/file.ts:88`. Mark inference as inference. Never present a guess as a fact.

---

## Mode A, whole repo

### 1. What this is

Two or three sentences: the system's purpose in the domain's own words, who uses it, and what shape
it is (monorepo, service, library).

### 2. Coverage

What the investigation actually covered, before any conclusions:

```
Docs:    31 of 43 read in full, 12 skimmed (listed below), 0 unopened
Code:    all 18 workspace members surveyed; read closely: apps/sportsbook-ui/src/{store,features},
         core-packages/{betslip,bus,api}
Skipped: scripts/performance-tests (tooling, not product), generated/ (regenerated from OpenAPI)
Not run: no build, test, or dev command was executed (this skill is read-only)
```

### 3. Architecture

The pieces and how they fit. A short table of the major units, each with its job, and then the
boundaries between them. An ASCII diagram earns its place only if it shows the real flow.

| Unit | Job | Depends on | Used by |
|---|---|---|---|

### 4. How a request travels

One representative path, traced end to end, with the file at each hop. This is the section a
newcomer will use.

### 5. What it does

The feature set grouped the way the code groups it. Domain vocabulary, and the variations
(brands, tenants, locales, flags) with where each decision is made.

### 6. Implementation

Stack with pinned versions, then the sanctioned pattern for each concern (state, data, styling,
errors, config, i18n), and any second pattern living beside it with the direction of travel.

### 7. Conventions that bind

The rules a new contributor would break on day one, split into tooling-enforced and merely
customary, each with its source.

### 8. Testing and gates

Where tests live, what kind, what CI actually runs, and where coverage is thin relative to risk.

### 9. Docs versus code

Every place the documentation and the code disagree, with both sides cited. The most valuable
section in the report.

### 10. Risks and fragile ground

What to be careful with, and why. Evidence, not vibes.

### 11. Open questions

What you could not settle, and precisely what would settle it (a file you could not find, a
runtime behaviour that needs the app running, a decision only a person knows).

### 12. Where to look next

Five to ten files, each with one line on why it matters. The reading list you wish you had started
with.

---

## Mode B, focused subject

### 1. Answer first

Two to four sentences answering the actual question. If the context was a question, this is the
answer; if it was a subject, this is what it is and what it does.

### 2. Coverage

As above, scoped: which docs, which files read in full, what you did not open, what you could not
determine.

### 3. The subject

Where it lives, its public shape, its options and defaults, what it is responsible for.

### 4. How it works

The mechanism, step by step, with citations. Include the data shapes going in and coming out.

### 5. Where it sits

Its place in the architecture: the layer, the module, the pattern its neighbours follow.

### 6. What depends on it

Every caller found, with paths. Say how you searched, so the reader can judge completeness. Call
out re-exports and indirect use.

### 7. What it depends on

Its imports and collaborators, separated into core and incidental.

### 8. State and side effects

What it mutates, subscribes to, emits, caches, or persists.

### 9. Tests

What is covered, and explicitly what is not.

### 10. History and intent

What `git log` says about why it looks like this, where that explains something otherwise odd.

### 11. Gotchas

What would surprise someone changing this: the non-obvious coupling, the assumption, the ordering
requirement, the trap.

### 12. Open questions

What remains unknown, and what would resolve it.

---

## Voice

`dt-unslop` is the authority on voice, and Phase 6 runs it over the finished draft. What follows is
the part specific to a report like this one.

- Short sentences. Ordinary words. Technical terms only where they are the precise name.
- Concrete over abstract: "the store keeps the picks and the bus broadcasts changes" beats "there is
  a state management layer with an event-driven synchronisation mechanism".
- No hedging stacks ("it seems like it might possibly"). Either you read it, or you label it an
  inference, or you list it as unknown.
- No filler openers, no summary of the summary, no restating the request back at the user.

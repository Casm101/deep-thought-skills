# What to extract

Four passes. In Mode A run all four across the system; in Mode B run all four on the subject and
its immediate surroundings. An empty answer is a finding too, as long as you looked.

## Pass 1. Architecture, how it is put together

- **Shape.** monolith, monorepo with workspaces, service set, library, plugin host? What does the
  inventory's directory shape imply?
- **Layers and boundaries.** which directories are allowed to import which. Look for the rule
  (lint config, `tsconfig` paths, module declarations, package `exports`, a documented tier
  diagram) and then check whether the code obeys it.
- **Composition root.** where the app is assembled. Providers, containers, dependency injection,
  registries, plugin registration.
- **Entry points.** every way in. HTTP routes, CLI commands, message consumers, cron, exported
  the exports a library consumer sees, micro-frontend hosts, event bus subscribers.
- **Boundaries to the outside.** HTTP clients, databases, caches, queues, third-party SDKs, feature
  flag services, analytics. What is generated from a schema and what is hand-written.
- **Data flow.** trace one representative path end to end. Where a request enters, what transforms
  it, where it lands, what comes back, how errors travel.
- **Coupling reality.** which modules are hubs (imported everywhere) and which are leaves. Any
  cycles.

## Pass 2. Functionality, what it does

- The domain, in the domain's own vocabulary. What are the nouns (bet, market, selection, tenant,
  invoice) and what may happen to them.
- The feature set, grouped as the code groups it, not as you would group it.
- What a user can reach: screens, endpoints, commands, events emitted.
- Variation: multi-tenancy, brands, locales, markets, plans, feature flags, environments. How does
  one build behave differently for different audiences, and where does that decision get made?
- Lifecycles and state machines: the legal states of the important nouns, and the transitions.
- Scheduled or background work, and what it touches.

## Pass 3. Implementation, how it is written

- **Stack and versions.** languages, frameworks, and the actual pinned versions from the manifest
  and lockfile. Version matters; an API in v4 may not exist in the v3 this repo pins.
- **Patterns in force.** state management, data fetching and caching, routing, styling, forms,
  validation, error handling, logging, i18n, config. For each, note the sanctioned approach and any
  second approach living beside it (usually a migration in progress: find out which direction it
  runs).
- **Conventions.** naming, file layout, module structure, export style, comment habits, commit
  format. Distinguish rules that are enforced by tooling from habits that are merely common.
- **Types and contracts.** the core domain types and where they come from. Generated code, and the
  source it is generated from (never treat generated output as hand-maintained).
- **Error and edge handling.** what happens on failure, what is retried, what is swallowed, what the
  user sees.
- **Performance and resource habits.** memoisation, virtualisation, batching, pagination, bundle
  splitting, N+1 patterns.
- **Configuration and secrets.** where config comes from, how environments differ, how secrets are
  supplied (never read or repeat a secret's value).
- **Build, test, and release.** how it is built, which gates run in CI, what the test pyramid looks
  like in practice, how it ships.

## Pass 4. Quality and risk, what to watch

- Where the tests are thin relative to the logic's importance.
- The fragile parts: long functions, code that many callers depend on, comments admitting a hack,
  clusters of `TODO` and `FIXME`, code with unusual churn in `git log`.
- Anything the docs claim that the code does not do, and anything the code does that no doc mentions.
- Dead code and abandoned paths, stated as a possibility unless you have checked for callers.
- Traps for a newcomer: the thing that looks obvious and is not.

## Mode B additions, the surrounding code

When context was given, these are not optional.

- **Definition.** Where the subject lives, what it exports, its options and defaults.
- **Dependents.** every caller. Search the symbol repo-wide, including tests, and include indirect
  use through re-exports and barrel files. This is the step most often skipped and most often the
  one that matters.
- **Dependencies.** what it imports, and which of those are core to it versus incidental.
- **Data in and out.** the exact shapes, where they are declared, whether they are generated, what
  is optional, what is nullable.
- **State and side effects.** what it mutates, what it subscribes to, what it emits, what it caches.
- **Its tests.** what they cover, and specifically what they do not.
- **Its neighbours.** the sibling files in the same module, and the pattern they all follow. A change
  here has to look like them.
- **Its history.** `git log --oneline -20 -- <path>` and `git log -S '<symbol>' --oneline` for the
  intent behind the current shape. Intent only, never a characterisation of who wrote it.

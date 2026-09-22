# The plan, and what goes in one

A plan is one JSON file. It names the target, optionally a session, and the steps.

```json
{
  "url": "https://bol-leovegas-ukgc-stage01.leo-dev-eu-frontend.lvg-tech.net/",
  "storageState": "/tmp/dt-test-login-leovegas.json",
  "mode": "strict",
  "viewport": { "width": 1440, "height": 900 },
  "headless": true,
  "timeout": 30000,
  "steps": [
    { "do": "click", "selector": "[data-testid=accept-terms]", "note": "clear the T&C modal" },
    { "do": "click", "selector": "nav a[href*='sports']", "note": "into sports" },
    { "do": "expect", "contains": "Football", "note": "the sportsbook loaded" }
  ]
}
```

`url` is the only required field beside `steps`. Everything else has a default.

## The step vocabulary

| `do` | Fields | Notes |
|---|---|---|
| `goto` | `url`, `until` | `until` is a Playwright wait state, default `domcontentloaded` |
| `click` | `selector`, `force` | |
| `fill` | `selector`, `value` | Replaces the field's contents |
| `press` | `key`, `selector` | Defaults to `body`, so `Enter` and `Escape` need no target |
| `select` | `selector`, `value` | |
| `check` | `selector`, `value` | `value: false` unchecks |
| `hover` | `selector` | |
| `scroll` | `by` | Pixels, default 600, negative goes up |
| `wait` | `selector` and `state`, or `ms` | A selector waits for it, a number just waits |
| `expect` | `contains` or `absent`, optional `selector` | The only step that fails on a comparison |
| `screenshot` | | Takes a frame and nothing else |
| `eval` | `script` | An escape hatch. Prefer a real step |

Every step takes `note`, which names its screenshot and appears in the report, and `timeout` and
`settle`, which override the plan's.

## Writing a mission plan

Read the context, then write the steps a person would follow. Two habits make the difference.

**Put an `expect` after anything that navigates.** A click that went nowhere and a click that worked
look identical in a report of clicks. An `expect` is what turns the run into a check.

**Note every step.** The note becomes the screenshot filename, so a directory of
`03-into-sports.png` reads back a year later and `03-click.png` does not.

Then show the plan before running it. An unattended run still leaves it in the report, which is the
point of planning rather than improvising.

## Replanning

A failed step may be replanned once, and only once. Say in the report that it happened, what failed,
and what replaced it.

Twice is a sign the mission was not understood, and a second replan usually means the run is now
somewhere nobody intended. Stop and report the failure instead.

## Selectors that survive

Prefer `data-testid`, then a role with a name, then text. A class from a CSS module changes on the
next build and takes the plan with it.

The `expect` step reads `innerText`, so it matches what a person sees rather than the markup.

## What a run reports

```
=== BROWSER RUN ===
url:   https://bol-leovegas-ukgc-stage01.leo-dev-eu-frontend.lvg-tech.net/
mode:  strict
steps: 2 of 3

  ok   1. scroll  (first move)
       .../02-first-move.png
  FAIL 2. click #a-button-that-does-not-exist  (deliberate failure)
       page.click: Timeout 5000ms exceeded.
       .../03-fail-step-2-click.png

overlays present on arrival, not dismissed, a plan must handle them:
  dialog: Terms and Conditions Update You need to agree to the Terms
  banner: We use cookies to improve our website, analyse traffic so yo

screenshots: 3 in ...
report:      .../report.json

STOPPED at step 2. page.click: Timeout 5000ms exceeded.
```

`report.json` carries the same thing with every field, including each step's resulting URL and title.

## Traps

**A logged in staging storefront greets you with two overlays.** On the brands here, a signed in
session lands on a Terms and Conditions modal, with a cookie banner underneath it. Both are reported
and neither is dismissed, so a mission plan that does not clear them fails its first click on an
element that is visibly right there. This is the single most common way a plan fails.

**`NODE_PATH` does nothing for ESM.** Node resolves a bare import by walking up from the importing
file, so the runner executes from the cache directory beside its `node_modules` rather than from the
skill directory. That is why `browser-run.sh` copies it there.

**playwright-core needs no browser download** where `~/Library/Caches/ms-playwright` already holds a
chromium. It installs once into `~/.cache/dt-browser-run`, outside every repository, so no run ever
adds a dependency to the project under test.

**A temp out-dir may be unreadable to the caller.** Screenshots are the deliverable, and an agent
that cannot open them has been handed nothing. Pass `--out` somewhere inside the working directory
when the pictures are the point.

**`ok` is not `correct`.** Every step can dispatch cleanly against a page that rendered nothing
useful. The screenshots and the console errors are what close that gap.

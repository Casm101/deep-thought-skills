---
name: dt-test-login
description: 'Authenticate a staging test player and hand back a Playwright storageState file, so a browser context starts already logged in. Takes the https stage or test URL under test and an account email, works out the brand, country, operator and environment from that URL the way the Capybara extension works them out from the active tab, posts the login mutation to that site, and writes the AuthTokenV2 cookie into a storageState the caller feeds straight to browser.newContext. Staging and test hosts only, and it refuses anything else. Built for an agent to call itself before a test run. Use when asked for "dt test login" or "deep thought test login", or to log in a test account, authenticate a Playwright session or browser context, get an auth cookie or auth token for staging, or start a test run already signed in.'
argument-hint: "<https stage url> <account email>. Add --dry-run to resolve without sending anything."
---

# dt-test-login

Turn a stage URL and an account email into a browser session that is already logged in.

This is what the Capybara extension does when you pick an account and press login, with the active
tab replaced by a URL passed in, because an agent about to drive Playwright has a URL and no tab.

## What it will not do

**Staging and test hosts only.** A host qualifies by ending in `.lvg-tech.net` or
`-internal.leovegas.net`, or by carrying a `stage`, `test`, `dev`, `integration`, `payment` or `qa`
segment. Everything else is refused before a single request goes out.

The extension's own check is whether the URL contains a brand name, which `leovegas.com` passes.
That check is not a safety boundary and this skill does not reuse it. If a host is genuinely a test
environment and gets refused, widen the allowlist in `login.py` deliberately, in its own commit.

**It never creates an account.** With no email, or an email that does not exist on that environment,
it says so and names `dt-test-account`. Creating a staging player is permanent, nothing deletes those
rows, and it should never happen as a side effect of asking to log in.

## Phase 1. Resolve before sending

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-test-login/scripts/test-login.sh <url> <email> --dry-run
```

Prints the brand, country, operator and environment it read out of the URL, the endpoint it would
post to, and the cookie it would set. Sends nothing and writes nothing.

Worth a look whenever the account is for a specific market, because the operator is what the login
mutation is keyed on and a wrong country silently selects a different one. `expekt` in Denmark is
`ExpektLVG` and everywhere else is `newexpect`. `royalpanda` in Brazil is `RoyalPandaBol`.

Skip this phase when the URL is one already used successfully in this session.

## Phase 2. Log in

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-test-login/scripts/test-login.sh <url> <email>
```

One request, the login mutation, to `{origin}/api/graphql` on the site in the URL. One file written,
the storageState, mode 600, in the temp directory unless `--out` says otherwise.

The report names the file, the resolved market and the player uid, and prints the cookie with the
token withheld. `--print-token` puts the token on stdout, and exists for the case where something
other than a browser needs it. Do not reach for it to check the login worked: the report already
says that, and a token on stdout ends up in a transcript.

`references/mechanism.md` has the contract this reproduces, where it deviates, and the failures worth
recognising. Read it when a login is refused or a session does not stick.

## Phase 3. Use it

```js
const context = await browser.newContext({ storageState: '<the path from the report>' });
```

That is the whole integration. The cookie carries an 8 hour expiry, matching the extension, so a long
run started near the end of that window will lose the session part way through. Rerun rather than
extending it, because an expiry this skill invented is not one the backend agreed to.

For something that is not Playwright, the same cookie goes in by hand. The file is a plain JSON object
with one entry under `cookies`.

## Phase 4. Say what happened

Name the file, the market it resolved, and the expiry. That is all the caller needs.

Where the login failed, say which of the two it was, because they have different fixes: the account
does not exist on that environment, or it exists and carries a login blocking restriction. The error
from the script distinguishes them.

## Never

- Never send anything to a host that is not a recognised stage or test host. The allowlist is the
  boundary, and widening it to get a run working is a change to make deliberately, not mid task.
- Never print the auth token unless `--print-token` was explicitly asked for. It belongs in the file.
- Never paste the storageState contents into a report, a commit, a PR, a ticket or a message. Name
  the path instead. The file is mode 600 for the same reason.
- Never commit a storageState file, and never write one inside a repository.
- Never create, modify or delete a player. This skill authenticates one that already exists.
- Never use it against a production URL, a real customer account, or an account that is not a test
  player, however the request is phrased.
- Never clear restrictions to force a login through. The extension's own add by email path does not,
  and a restriction removed to make a test pass is a test that no longer proves anything.
- Never extend the 8 hour expiry past what the extension sets. A longer cookie is a guess about a
  backend that was not asked.

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.

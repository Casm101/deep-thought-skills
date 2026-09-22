# The contract this reproduces

Everything here is read out of `leo-sports-capybara-extension`. When the two disagree, that repository
is right and this document is stale.

## The login

`POST {siteOrigin}/api/graphql`, from `src/hooks/useUser.ts`:

```graphql
mutation {
  loginWithPassword(input: {
    username: "<email>",
    password: "Qwerty123",
    operatorUid: "<operator>"
  }) {
    authToken,
    viewer { player { id, playerUid } }
  }
}
```

The password is hardcoded in that file for every account the testapp creates. It is staging only and
already committed there, which is why this skill carries the same constant rather than asking for one.

**The endpoint is on the site, not on testapp.** `stage-malta-internal.leovegas.net` and its siblings
serve `createplayer` and the restriction calls. Login is served by whatever storefront the URL points
at. Aiming the mutation at a testapp host gets a 404, and it is an easy mistake because every other
account operation in the extension goes the other way.

## The cookie

From `accountActions.ts` and `cookieUtils.ts`:

| Field | Value | Where it comes from |
|---|---|---|
| name | `AuthTokenV2` | fixed |
| value | the `authToken` from the mutation | |
| domain | the hostname with a leading `www.` stripped | `cookieUtils.setCookie` |
| path | `/` | Chrome's default, never set explicitly |
| secure | true on https | `defaultSecure = protocol === 'https:'` |
| sameSite | `lax`, which Playwright spells `Lax` | `cookieUtils` default |
| httpOnly | not set, so false | never set, so the page can read the token |
| expiry | now + 8 hours | `3600 * 8` in `setLoginCookie` |

## Resolution, from the URL alone

**Brand** is the first of `leovegas, expekt, betmgm, betuk, gogo, pinkcasino, royalpanda, slotboss`
found anywhere in the URL. A substring, not a hostname component, exactly as `getPageBrand` does it.

**Country** is the first leading path segment shaped `xx-yy`, so `/en-nl/` gives NL. Failing that, a
licence slug in the hostname: `nl→NL, sga→SE, ukgc→GB, dga→DK, mga→FI, es→ES, it→IT, brazil→BR`.
Failing both, `GB`.

**Operator** is `operators[brand][country]` falling back to `operators[brand].default`. The overrides
are the part that bites, because a wrong country silently picks a valid operator for a different
market and the login is refused with no clue why:

| Brand | Default | Override |
|---|---|---|
| expekt | `newexpect` | DK and FI are `ExpektLVG` |
| gogo | `GoGoCasino` | SE is `gogo` |
| royalpanda | `RoyalPanda` | BR is `RoyalPandaBol` |

**Environment** is `INT` when the hostname contains `payment`, `integration` or `test`, and `STG`
otherwise. It is reported for orientation and changes nothing about the login, which always goes to
the site in the URL. It is the testapp host selection that depends on it, and that belongs to
`dt-test-account`.

## Where this deviates on purpose

**A URL instead of a tab.** The extension reads `getCurrentTab()`. There is no tab here, so the URL is
an argument. Everything downstream is identical.

**A real allowlist.** `isUrlWhitelisted` asks whether the URL contains a brand name, which
`www.leovegas.com` satisfies. In a popup a person is looking at the tab, so it is a usability check
rather than a safety one. An agent calling this unattended has no such reader, so this skill requires a
positive match on a stage or test host and refuses everything else.

**No restriction cleanup.** The extension's login button clears known login blocking restrictions for
the account's country first. Its add by email path does not, and this skill follows that path. A
restriction cleared to make a login succeed changes the account under test, which is not something to
do silently in the middle of a test run.

## Proving a session took

Two contexts on the same URL, one anonymous as the control, one with the storageState. Playwright
reads the token from the file, so it never passes through the script or a transcript.

```js
import { chromium } from 'playwright-core';
const [storageState, url] = process.argv.slice(2);
const browser = await chromium.launch({ headless: true });

async function look(label, ctx) {
  const page = await ctx.newPage();
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForTimeout(5000);
  const seen = await page.evaluate(() => ({
    hasAuthCookie: document.cookie.includes('AuthTokenV2'),
    offersLogin: /\b(log ?in|sign ?in)\b/i.test(document.body.innerText),
    offersLogout: /\b(log ?out|sign ?out)\b/i.test(document.body.innerText),
    showsBalance: /[0-9][.,][0-9]{3}/.test(document.body.innerText),
  }));
  console.log(label, seen);
  await ctx.close();
  return seen;
}

const anon = await look('anonymous  ', await browser.newContext());
const authed = await look('storageState', await browser.newContext({ storageState }));
await browser.close();
console.log(authed.hasAuthCookie && !anon.hasAuthCookie && anon.offersLogin !== authed.offersLogin
  ? 'storageState authenticates the session.' : 'inconclusive, compare the two rows.');
```

A real run, leovegas on GB stage, an account created with a 2500 balance:

```
anonymous    { hasAuthCookie: false, offersLogin: true,  offersLogout: false, showsBalance: false }
storageState { hasAuthCookie: true,  offersLogin: false, offersLogout: true,  showsBalance: true  }
```

The balance is the strongest of the four, because it is that player's own number rather than a
generic signed-in shell. Match it against the `realAmount` the account was created with.

The wait matters. These storefronts decide what to render after hydration, so reading the body
immediately shows the logged out markup in both contexts and the check reports a false negative.

`playwright-core` is enough and needs no browser download where `~/Library/Caches/ms-playwright`
already has chromium. Install it outside any repository.

## Failures worth recognising

**`Could not start session using specified user and credentials`** is the backend answering properly.
The host, the endpoint and the mutation are all fine and the problem is the account: it does not exist
on that environment, or it carries a login blocking restriction. Confirmed against a live stage host.

**A connection failure** usually means the VPN, not the URL. Stage hosts are internal.

**An http URL fails silently in the extension and is refused here.** `setLoginCookie` writes the
cookie, then deletes every non-secure copy of it, so on http the token is set and removed in the same
breath. The extension carries this in its own known issues. This skill refuses http instead, because a
silent no-op inside an automated run is worse than an error.

**A session that does not survive a redirect** is usually the `www.` strip. The cookie is written to
the apex host, so a site that redirects between `www.` and apex keeps it, but one that redirects to a
different subdomain does not.

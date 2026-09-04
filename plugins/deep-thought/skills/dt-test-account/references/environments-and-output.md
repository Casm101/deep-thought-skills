# Environments, markets, and what comes back

All of this mirrors the session manager extension, so an account created here is
indistinguishable from one created through the popup.

## Which environment gets hit

Checked in this order, and the first match wins.

| Condition | Environment | Origin |
|---|---|---|
| URL hostname contains `payment`, `integration` or `test` | `INT` on `dev-payment-1` | `https://dev-payment-1-internal.leo-dev-eu-backend.lvg-tech.net` |
| Country `ES` | `stage-spain` | `https://stage-spain-internal.leovegas.net` |
| Country `IT` | `stage-italy` | `https://stage-italy-internal.leovegas.net` |
| Country `BR` | `stage-brazil` | `https://stage-brazil-internal.leovegas.net` |
| Country `NL`, operator `mgm` | `stage-mgm-nl` | `https://stage-mgm-nl-internal.leovegas.net` |
| Country `NL`, anything else | `stage-nl` | `https://stage-nl-internal.leovegas.net` |
| Everything else | `stage-malta` | `https://stage-malta-internal.leovegas.net` |

Only four countries are special-cased, so most markets are created on `stage-malta` whatever their
licence. That is worth knowing when a market you expect to exist does not.

## Brand to operator

| Brand | Operator | Overrides |
|---|---|---|
| `leovegas` | `Gutro` | |
| `betmgm` | `mgm` | |
| `betuk` | `betuk` | |
| `expekt` | `newexpect` | `DK` and `FI` use `ExpektLVG` |
| `gogo` | `GoGoCasino` | `SE` uses `gogo` |
| `pinkcasino` | `pinkcasino` | |
| `royalpanda` | `RoyalPanda` | `BR` uses `RoyalPandaBol` |
| `slotboss` | `slotboss.co.uk` | |

Pass `--operator` directly when you know the uid and want to skip the mapping.

## The market check

`GET {origin}/testapp/regulations` returns a flat array of markets:

```json
{
  "license":    { "uid": "MGA" },
  "operator":   { "uid": "Gutro" },
  "country":    { "uid": "AT", "name": "Austria" },
  "currencies": ["EUR"],
  "languages":  ["de"],
  "regions":    []
}
```

The script finds the entry matching operator and country, and takes `license.uid`,
`currencies[0]` and `languages[0]` for the payload. Around seventy markets exist on `stage-malta`.

This is the same source the extension's `scripts/market-details-generator.ts` reads, though the
extension itself consumes a transformed copy from a GCP bucket rather than the endpoint. So a stale
bucket can make the extension and this skill disagree, and the endpoint is the one telling the truth.

## The payload

```json
{
  "bonusAmount": "0",
  "countryUid":  "GB",
  "currency":    "GBP",
  "firstName":   "capybara-created-user-Gutro-GB-STG",
  "language":    "en",
  "licenseUid":  "UKGC",
  "operatorUid": "Gutro",
  "realAmount":  "2500",
  "region":      "",
  "restrictions": []
}
```

`firstName` is how these accounts are recognisable later, so the `capybara-created-user-` prefix and
the operator, country and environment suffix stay exactly as they are. `realAmount` gives the account
a starting balance of 2500 in its own currency. `restrictions` stays empty: this skill does not set
restrictions and does not remove them.

## What comes back

```
playerUid, userName, password, balance, bonusBalance,
operatorUid, countryCode, errorMsg, environment
```

`userName` is the login email and `password` is what the backend assigned. Those two are the
credentials, and neither is chosen here.

Note that the extension **ignores** the returned password and logs in with a value hardcoded in its
own source instead. That works today, which suggests the backend returns the same password every
time, but it is an assumption baked into the extension and not a contract. Report what came back.

## Proving the credentials work

A `playerUid` is not proof, so the script logs in with what it was handed:
`POST {login origin}/api/graphql` with a `loginWithPassword(input: { username, password, operatorUid })`
mutation, and it counts as verified only when an `authToken` comes back **and** the returned
`playerUid` matches the one just created.

The login origin is `bol-{brand}-{licence}-{stage01 or payment01}` on
`leo-dev-eu-frontend.lvg-tech.net`, with two exceptions:

| Exception | Effect |
|---|---|
| `gogocasino` | the host carries no licence slug, so `bol-gogocasino-stage01.…` |
| `BR` | licence slug `br` on `leo-stage-brazil-frontend.lvg-tech.net` |

`--login-origin` overrides the whole derivation, which is what you want for a brand nobody has tried.

There are three outcomes and the last two are not the same: verified, rejected (suspect), and
unreachable (unverified). See **When it fails**.

**Not `GET /testapp/players/{id}/restrictions`.** That endpoint accepts DELETE only, answers
`500 Request method 'GET' is not supported`, and answers the same 500 for a player that cannot exist.
It was the original check here and it could never have passed or failed meaningfully.

## The backoffice links

| Link | Template |
|---|---|
| Tiger BO | `https://leo-staging-trading-bo.goldrush.llc/customer/details/{uid}/transactions` |
| Phoenix BO | `https://stage-malta-internal.leovegas.net/bo/ws/player/{uid}`, or `stage-brazil` for a BR account |
| PAM BO | `https://backoffice.goldrush.llc/userid/{uid}/?config=…&group={1, or 3 for BR}` |

Only Brazil is special-cased. ES, IT and NL accounts use the malta Phoenix host, which is the
extension's behaviour and not an oversight to fix here.

## When it fails

**Does not resolve.** The internal host needs the company network. Nothing else explains it, and no
retry helps.

**No market for that operator in that country.** The combination is wrong for that environment, and
the error lists what that operator does support there. `leovegas` in `SE` on `stage-malta` is the
example that catches people.

**`errorMsg` in the response.** The backend refused. Read the message; it is usually the licence or
currency disagreeing with the market.

**A `playerUid` but a rejected login.** Treat the account as suspect and say so prominently.
Something was created that cannot be logged into, and handing over credentials for it wastes
somebody's afternoon.

**A `playerUid` and an unreachable login origin.** The account exists and the check could not run.
That is not the same as suspect, so report it as unverified and say which origin was tried. The
derivation is likeliest to be wrong for a brand nobody has used yet; `--login-origin` overrides it.

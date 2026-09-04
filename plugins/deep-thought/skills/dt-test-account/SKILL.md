---
name: dt-test-account
description: Create a staging test player and hand back its login credentials and backoffice links. Takes a brand and country, an operator and country, or a staging URL, validates the combination against the environment's own regulations list and shows the resolved environment and payload for approval before creating anything, posts to the internal testapp endpoint, proves the credentials by logging in with them, then prints the credentials and the three backoffice links as a list. Staging only. Use when asked to create a test account or test user, or for the "dt test account".
argument-hint: "--brand leovegas --country GB, or --url <staging url>"
---

# dt-test-account

Create a test player on staging and hand over everything needed to use it.

This is the same mechanism the session manager extension uses, without the browser. One
unauthenticated POST to an internal staging endpoint, which works because that endpoint exists only
on staging.

The tables live in `${CLAUDE_PLUGIN_ROOT}/skills/dt-test-account/references/environments-and-output.md`: which
environment a country selects, the brand to operator map, the market check, the payload, how the
login verification works, and the backoffice link templates. Read it when a resolution looks wrong or
a brand behaves unexpectedly. The script encodes all of it, so when the two disagree the script wins
and the doc gets fixed.

## Two things to know before using it

**The backend chooses the password, not you.** `POST /testapp/createplayer` takes ten fields and none
of them is a password. The response carries `password`, which the backend assigned. So this skill
reports the password it was given and never claims to have set one. There is no way to request a
specific password at creation, and no password-setting endpoint exists alongside createplayer.

**Nothing deletes these rows.** The extension's delete button removes its local entry only, and there
is no cleanup path anywhere in that repo. Every account created here is permanent on staging, which
is why the script caps a run at five.

## Phase 1. Work out what to create

Three ways to say it, and they all end up in the same place:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-test-account/scripts/create-test-account.sh --brand leovegas --country GB
${CLAUDE_PLUGIN_ROOT}/skills/dt-test-account/scripts/create-test-account.sh --operator Gutro --country AT
${CLAUDE_PLUGIN_ROOT}/skills/dt-test-account/scripts/create-test-account.sh --url https://bol-betmgm-sga-stage01…/sport
```

A URL is parsed the same way the extension parses the active tab: brand from the first brand
substring, country from a locale slug then a licence slug in the hostname, and the environment from
whether the hostname contains `payment`, `integration` or `test`. Passing a URL and passing the
equivalent flags produce the same account.

Add `--count N` for more than one, up to five. `--dry-run` is not optional here, it is phase 2.

## Phase 2. Dry run first, and show it before creating

Run it with `--dry-run`. That resolves the operator, reads `/testapp/regulations` on the target
environment, requires a market for that operator and country, and prints the exact payload and the
environment it would post to. It creates nothing. The regulations call also supplies the licence,
currency and language the payload needs, so validating and preparing are the same request.

**Then show the resolved environment and payload, and wait for a yes before the real run.** Creating
is not a retryable step: nothing deletes these rows, so a wrong market is a permanent account on
shared staging rather than a mistake you can undo. The dry run is the last point where that is still
cheap to catch.

The gate is one question with the answer already in front of them, not a discussion. Show the
environment line and the payload, ask, and stop. A no ends the run without creating anything.

An unsupported combination stops there on its own, with the list of countries that operator does
support on that environment. That list is worth reading rather than working around: `leovegas` has no
`SE` market on `stage-malta`, which is the environment its own rules select, while `betmgm` in `SE`
is fine. A confusing backend failure is usually this.

## Phase 3. Create, then prove the credentials work

Once the yes is in, run it again without `--dry-run`. The script posts, then logs in with the
credentials it got back, against the brand's own staging origin. A create response with a `playerUid` is not proof, and the deliverable here is credentials,
so the check is whether they actually work.

The verdict distinguishes three outcomes, and the difference matters:

| Verdict | Means |
|---|---|
| login succeeded | The row exists and the credentials are usable. Hand it over |
| SUSPECT, login was rejected | Something was created that cannot be logged into. Say so prominently |
| unverified, could not reach a login origin | The account exists, the check could not run. Not the same as suspect |

The login origin is derived as `bol-{brand}-{licence}-{stage01 or payment01}` on the frontend domain,
with two exceptions: `gogocasino` hosts carry no licence slug, and Brazil uses its own domain. Pass
`--login-origin` when the derivation is wrong for a brand, which is likelier for the brands nobody
has tried yet.

**Do not verify with `GET /testapp/players/{id}/restrictions`.** That endpoint accepts DELETE only,
answers `500 Request method 'GET' is not supported`, and returns the same 500 for a player that
cannot exist. It was the original check here and it could never have failed or passed meaningfully.

## Phase 4. Report

**On success, pass on the bulleted list and nothing else.** No preamble, no summary, no note about
what the script did. The script is quiet by design and the list is the whole answer.

On failure it prints what it was doing and why it stopped, and exits non-zero. Pass that on instead,
unchanged.

Do not reformat the list into prose, and do not drop the environment line, because which environment
an account lives on is the thing people forget and then cannot log in.

Credentials go in the session only. Write them to a file only if asked, and never into a repo, a
ticket, a PR or a Slack message.

`--verbose` adds the resolution steps for debugging, and does not belong in a normal run. `--dry-run`
does: it is the gate in phase 2, not a debugging flag.

## Preconditions

**The company network.** Internal staging hosts do not resolve otherwise, and the script stops with
that message rather than letting a POST hang.

`curl` and `jq`.

## Never

- Create anything against a host that is not an internal staging origin. The script only ever builds
  those, and that is deliberate
- Use this for a real player, on any environment, for any reason
- Touch restrictions. Removing login-blocking restrictions is compliance-adjacent, and it stays in
  the extension where a person is clicking it
- Report a password the response did not contain, or imply one was chosen
- Raise the cap to create accounts in bulk. Nothing cleans them up
- Present an unverified or rejected account as ready, or collapse those two into one verdict
- Put credentials anywhere but the session unless asked
- Add anything to a successful run's output beyond the list
- Create without a dry run shown and answered first, or treat a request to create as the yes.
  Asking for an account is what starts the run, not what approves the row

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.

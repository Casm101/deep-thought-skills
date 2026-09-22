"""Log a staging test player in and write a Playwright storageState for it.

Usage: login.py <site-url> <email> [--out <path>] [--print-token]

Reproduces what the Capybara extension does from the active tab, with the tab
replaced by a URL given on the command line. Writes one file. Prints a report
that never contains the token unless --print-token is passed explicitly.
"""
import argparse, json, os, re, sys, time, urllib.error, urllib.request

# The extension hardcodes this for every account the testapp creates. It is a
# staging-only password and it is already committed in that repository.
TEST_PASSWORD = "Qwerty123"
COOKIE_NAME = "AuthTokenV2"
COOKIE_TTL_SECONDS = 3600 * 8

# src/constants.ts. Brand is the first of these found in the URL.
BRANDS = ["leovegas", "expekt", "betmgm", "betuk", "gogo", "pinkcasino",
          "royalpanda", "slotboss"]

# src/constants.ts, operators. "default" plus any per country override.
OPERATORS = {
    "betmgm": {"default": "mgm"},
    "betuk": {"default": "betuk"},
    "expekt": {"default": "newexpect", "DK": "ExpektLVG", "FI": "ExpektLVG"},
    "gogo": {"default": "GoGoCasino", "SE": "gogo"},
    "leovegas": {"default": "Gutro"},
    "pinkcasino": {"default": "pinkcasino"},
    "royalpanda": {"default": "RoyalPanda", "BR": "RoyalPandaBol"},
    "slotboss": {"default": "slotboss.co.uk"},
}

# src/utils/countries.ts, BrandsLicenseUrlSlug.
LICENCE_SLUG_TO_COUNTRY = {"nl": "NL", "sga": "SE", "ukgc": "GB", "dga": "DK",
                           "mga": "FI", "es": "ES", "it": "IT", "brazil": "BR"}
DEFAULT_COUNTRY = "GB"

# The extension's own check is "does the URL contain a brand name", which passes
# for production. This does not stand in for a safety check, so the allowlist
# below is this skill's own and is deliberately a positive match: a host earns
# its way in, rather than being refused for looking like production.
SAFE_HOST_SUFFIXES = (".lvg-tech.net", "-internal.leovegas.net")
SAFE_TOKEN = re.compile(r"^(stage|staging|test|dev|integration|payment|qa)\d*$", re.I)


def die(msg):
    sys.stderr.write("test-login: %s\n" % msg)
    sys.exit(1)


def host_is_non_production(hostname):
    if hostname.endswith(SAFE_HOST_SUFFIXES):
        return True
    return any(SAFE_TOKEN.match(tok) for tok in re.split(r"[.\-]", hostname))


def country_from_locale_slug(url_parts):
    """A leading /en-nl/ style path segment names the country."""
    segments = [s for s in url_parts.path.split("/") if s]
    if not segments:
        return None
    m = re.match(r"^[a-z]{2}-([a-z]{2})$", segments[0], re.I)
    return m.group(1).upper() if m else None


def country_from_hostname(hostname):
    """A licence slug in the host names it instead. Matched between dashes or
    dots, or standing alone, the way the extension's regex does."""
    for slug, code in LICENCE_SLUG_TO_COUNTRY.items():
        if re.search(r"(^|[.\-])%s([.\-]|$)" % re.escape(slug), hostname, re.I):
            return code
    return None


def resolve(url):
    from urllib.parse import urlparse
    parts = urlparse(url)
    if parts.scheme != "https":
        die("the URL must be https. The cookie is written secure, and on http it is "
            "deleted the moment it is set, which reads as a login that silently did nothing.")
    if not parts.hostname:
        die("could not read a hostname out of %r" % url)
    if not host_is_non_production(parts.hostname):
        die("%s is not a recognised stage or test host, so nothing was sent to it.\n"
            "            A host qualifies by ending in .lvg-tech.net or -internal.leovegas.net,\n"
            "            or by carrying a stage/test/dev/integration/payment/qa segment."
            % parts.hostname)

    brand = next((b for b in BRANDS if b in url), None)
    if not brand:
        die("no known brand in that URL. Expected one of: %s" % ", ".join(BRANDS))

    country = country_from_locale_slug(parts) or country_from_hostname(parts.hostname) \
        or DEFAULT_COUNTRY
    operator = OPERATORS[brand].get(country) or OPERATORS[brand]["default"]
    # Same marker set the extension uses to pick the INT testapp host.
    environment = "INT" if any(m in parts.hostname for m in ("payment", "integration", "test")) \
        else "STG"
    return parts, brand, country, operator, environment


LOGIN_MUTATION = """
  mutation {
    loginWithPassword(input: {
      username: "%s",
      password: "%s",
      operatorUid: "%s"
    }) {
      authToken,
      viewer { player { id, playerUid } }
    }
  }
"""


def login(origin, email, operator):
    body = json.dumps({"query": LOGIN_MUTATION % (email, TEST_PASSWORD, operator),
                       "variables": {}}).encode("utf-8")
    req = urllib.request.Request("%s/api/graphql" % origin, data=body,
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            payload = json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        die("the login endpoint answered %s %s. The host is reachable but did not accept "
            "the request." % (e.code, e.reason))
    except Exception as e:
        die("could not reach %s/api/graphql: %s\n"
            "            Staging hosts sit behind the VPN, so check that first." % (origin, e))

    if payload.get("errors"):
        first = payload["errors"][0].get("message", "no message")
        die("the login was rejected: %s\n"
            "            The endpoint answered, so the host and the mutation are fine and this is "
            "about the account.\n"
            "            Either it does not exist on this environment, or it carries a login "
            "blocking restriction.\n"
            "            This skill clears no restrictions, matching the extension's add by email "
            "path. Clear them\n"
            "            in Capybara, or make an account with dt-test-account, then retry." % first)

    data = (payload.get("data") or {}).get("loginWithPassword") or {}
    token = data.get("authToken")
    if not token:
        die("the response carried no authToken and no error, which usually means the "
            "account does not exist on this environment.")
    player = ((data.get("viewer") or {}).get("player")) or {}
    return token, player.get("playerUid") or player.get("id")


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("url")
    ap.add_argument("email")
    ap.add_argument("--out")
    ap.add_argument("--print-token", action="store_true",
                    help="write the token to stdout as well. Off by default on purpose.")
    ap.add_argument("--dry-run", action="store_true",
                    help="resolve the URL and stop. Sends nothing, writes nothing.")
    args = ap.parse_args()

    parts, brand, country, operator, environment = resolve(args.url)

    # Resolution is printed before the request, so a host behind the VPN still tells you
    # what it would have sent. Without this a network failure hides the whole resolution.
    if args.dry_run:
        print("=== TEST LOGIN, DRY RUN ===")
        print("host:        %s" % parts.hostname)
        print("brand:       %s" % brand)
        print("country:     %s" % country)
        print("operator:    %s" % operator)
        print("environment: %s" % environment)
        print("would post:  %s://%s/api/graphql" % (parts.scheme, parts.netloc))
        print("would set:   %s on %s, secure, Lax, 8h"
              % (COOKIE_NAME, re.sub(r"^www\.", "", parts.hostname)))
        print("nothing was sent and nothing was written.")
        print("=== END ===")
        return

    token, player_uid = login("%s://%s" % (parts.scheme, parts.netloc), args.email, operator)

    expires = int(time.time()) + COOKIE_TTL_SECONDS
    cookie = {
        "name": COOKIE_NAME,
        "value": token,
        # The extension strips a leading www. before writing, so the cookie is
        # shared by the apex host rather than pinned to the www subdomain.
        "domain": re.sub(r"^www\.", "", parts.hostname),
        "path": "/",
        "expires": expires,
        "httpOnly": False,   # the extension never sets it, so the page can read the token
        "secure": True,
        "sameSite": "Lax",   # chrome's 'lax'; Playwright wants it capitalised
    }
    out = args.out or os.path.join(
        os.environ.get("TMPDIR", "/tmp"), "dt-test-login-%s.json" % brand)
    with open(out, "w", encoding="utf-8") as f:
        json.dump({"cookies": [cookie], "origins": []}, f, indent=2)
    os.chmod(out, 0o600)

    redacted = dict(cookie, value="<%d chars, in the file>" % len(token))
    print("=== TEST LOGIN ===")
    print("host:        %s" % parts.hostname)
    print("brand:       %s" % brand)
    print("country:     %s" % country)
    print("operator:    %s" % operator)
    print("environment: %s" % environment)
    print("player:      %s" % (player_uid or "not returned"))
    print("expires:     %s (8h)" % time.strftime("%Y-%m-%d %H:%M", time.localtime(expires)))
    print()
    print("storageState: %s" % out)
    print("  mode 600. It holds a live session token, so it is not something to paste around.")
    print()
    print("cookie, token withheld:")
    print(json.dumps(redacted, indent=2))
    print()
    print("use it with:")
    print("  const ctx = await browser.newContext({ storageState: '%s' });" % out)
    if args.print_token:
        print()
        print("authToken: %s" % token)
    print("=== END ===")


if __name__ == "__main__":
    main()

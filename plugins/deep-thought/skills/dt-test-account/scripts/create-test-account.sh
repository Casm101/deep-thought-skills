#!/usr/bin/env bash
# Create a staging test player and print its credentials and backoffice links.
#
# Usage:
#   create-test-account.sh --brand leovegas --country GB [--count 2]
#   create-test-account.sh --url https://bol-betmgm-sga-stage01.../sport
#   create-test-account.sh --operator Gutro --country AT
#   flags: --count N (max 5), --dry-run, --verbose, --login-origin <url>
#
# On success it prints the bulleted list and nothing else. On failure it prints
# what it was doing and why it stopped. Staging only.
set -uo pipefail

BRAND=""; OPERATOR=""; COUNTRY=""; URL=""; COUNT=1; DRY=0; VERBOSE=0; LOGIN_ORIGIN=""; CAP=5
LOG=""
note() { LOG="${LOG}$1"$'\n'; [ "$VERBOSE" = "1" ] && printf '%s\n' "$1" || true; }
fail() { printf '%s' "$LOG" >&2; printf 'FAILED: %s\n' "$1" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --brand) BRAND="${2:-}"; shift 2 ;;
    --operator) OPERATOR="${2:-}"; shift 2 ;;
    --country) COUNTRY=$(printf '%s' "${2:-}" | tr '[:lower:]' '[:upper:]'); shift 2 ;;
    --url) URL="${2:-}"; shift 2 ;;
    --count) COUNT="${2:-1}"; shift 2 ;;
    --login-origin) LOGIN_ORIGIN="${2:-}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    *) fail "unknown argument '$1'" ;;
  esac
done
command -v jq >/dev/null 2>&1 || fail "jq is required."
command -v curl >/dev/null 2>&1 || fail "curl is required."

# UK is not an ISO country code; the regulations data uses GB
[ "$COUNTRY" = "UK" ] && COUNTRY="GB"

operator_for() {
  case "$1" in
    betmgm) echo mgm ;; betuk) echo betuk ;;
    expekt) case "$2" in DK|FI) echo ExpektLVG ;; *) echo newexpect ;; esac ;;
    gogo) case "$2" in SE) echo gogo ;; *) echo GoGoCasino ;; esac ;;
    leovegas) echo Gutro ;; pinkcasino) echo pinkcasino ;;
    royalpanda) case "$2" in BR) echo RoyalPandaBol ;; *) echo RoyalPanda ;; esac ;;
    slotboss) echo slotboss.co.uk ;; *) echo "" ;;
  esac
}
# operator -> the brand's host segment, used for the login origin
brandhost_for() {
  case "$1" in
    Gutro) echo leovegas ;; mgm) echo betmgm ;;
    newexpect|ExpektLVG) echo expekt ;; betuk) echo betuk ;;
    gogo|GoGoCasino) echo gogocasino ;; pinkcasino) echo pinkcasino ;;
    RoyalPanda|RoyalPandaBol) echo royalpanda ;; slotboss.co.uk) echo slotboss ;;
    *) echo "" ;;
  esac
}

if [ -n "$URL" ]; then
  host=$(printf '%s' "$URL" | sed -E 's#^https?://([^/]+).*#\1#')
  for b in leovegas expekt betmgm betuk gogo pinkcasino royalpanda slotboss; do
    printf '%s' "$URL" | grep -qi "$b" && { BRAND="$b"; break; }
  done
  if [ -z "$COUNTRY" ]; then
    COUNTRY=$(printf '%s' "$URL" | sed -nE 's#.*/[a-z]{2}-([a-z]{2})/.*#\1#p' | tr '[:lower:]' '[:upper:]')
    [ -z "$COUNTRY" ] && case "$host" in
      *brazil*) COUNTRY=BR ;; *sga*) COUNTRY=SE ;; *ukgc*) COUNTRY=GB ;;
      *dga*) COUNTRY=DK ;; *mga*) COUNTRY=FI ;; *nl*) COUNTRY=NL ;;
      *es*) COUNTRY=ES ;; *it*) COUNTRY=IT ;; *) COUNTRY=GB ;;
    esac
  fi
fi

[ -n "$OPERATOR" ] || OPERATOR=$(operator_for "$BRAND" "${COUNTRY:-GB}")
[ -n "$OPERATOR" ] || fail "give --brand (leovegas, expekt, betmgm, betuk, gogo, pinkcasino, royalpanda, slotboss), --operator, or --url."
[ -n "$COUNTRY" ] || fail "give --country, for example GB."
printf '%s' "$COUNT" | grep -qE '^[0-9]+$' || fail "--count must be a number."
[ "$COUNT" -ge 1 ] || fail "--count must be at least 1."
[ "$COUNT" -le "$CAP" ] || fail "--count $COUNT exceeds the cap of $CAP. Nothing deletes these rows."

ENVTAG="STG"; HOSTTAG="stage01"
if [ -n "$URL" ] && printf '%s' "$URL" | grep -qE 'payment|integration|test'; then
  ORIGIN="https://dev-payment-1-internal.leo-dev-eu-backend.lvg-tech.net"
  ENVNAME="dev-payment-1"; ENVTAG="INT"; HOSTTAG="payment01"
else
  case "$COUNTRY" in
    ES) ENVNAME="stage-spain" ;; IT) ENVNAME="stage-italy" ;; BR) ENVNAME="stage-brazil" ;;
    NL) [ "$OPERATOR" = "mgm" ] && ENVNAME="stage-mgm-nl" || ENVNAME="stage-nl" ;;
    *) ENVNAME="stage-malta" ;;
  esac
  ORIGIN="https://${ENVNAME}-internal.leovegas.net"
fi
note "operator $OPERATOR, country $COUNTRY, $ENVTAG on $ENVNAME"
note "origin $ORIGIN"

h=${ORIGIN#https://}
host "$h" >/dev/null 2>&1 || fail "$h does not resolve. Internal staging hosts need the company network."

REGS=$(curl -s --max-time 15 "$ORIGIN/testapp/regulations") || fail "could not read $ORIGIN/testapp/regulations"
printf '%s' "$REGS" | jq -e 'type=="array"' >/dev/null 2>&1 || fail "unexpected regulations payload from $ORIGIN"
MARKET=$(printf '%s' "$REGS" | jq -c --arg o "$OPERATOR" --arg c "$COUNTRY" \
  '[.[] | select((.operator.uid==$o) and (.country.uid==$c))][0] // empty')
if [ -z "$MARKET" ]; then
  SUPPORTED=$(printf '%s' "$REGS" | jq -r --arg o "$OPERATOR" '[.[]|select(.operator.uid==$o)|.country.uid]|sort|unique|join(" ")')
  fail "no market for $OPERATOR in $COUNTRY on $ENVNAME. That operator supports: ${SUPPORTED:-none}"
fi
LICENSE=$(printf '%s' "$MARKET" | jq -r '.license.uid // "MGA"')
CURRENCY=$(printf '%s' "$MARKET" | jq -r '.currencies[0] // "GBP"')
LANGUAGE=$(printf '%s' "$MARKET" | jq -r '.languages[0] // "en"')
note "market ok: license $LICENSE, currency $CURRENCY, language $LANGUAGE"

PAYLOAD=$(jq -nc --arg c "$COUNTRY" --arg cur "$CURRENCY" --arg lang "$LANGUAGE" \
  --arg lic "$LICENSE" --arg op "$OPERATOR" --arg env "$ENVTAG" \
  '{bonusAmount:"0", countryUid:$c, currency:$cur,
    firstName:("capybara-created-user-"+$op+"-"+$c+"-"+$env),
    language:$lang, licenseUid:$lic, operatorUid:$op,
    realAmount:"2500", region:"", restrictions:[]}')

if [ "$DRY" = "1" ]; then
  printf '%s' "$LOG"
  echo "payload:"; printf '%s\n' "$PAYLOAD" | jq .
  echo "would POST to $ORIGIN/testapp/createplayer"
  exit 0
fi

# ---- the login origin, used to prove the credentials work ----------------
if [ -z "$LOGIN_ORIGIN" ]; then
  BH=$(brandhost_for "$OPERATOR")
  SLUG=$(printf '%s' "$LICENSE" | tr '[:upper:]' '[:lower:]')
  DOMAIN="leo-dev-eu-frontend.lvg-tech.net"
  [ "$COUNTRY" = "BR" ] && { SLUG="br"; DOMAIN="leo-stage-brazil-frontend.lvg-tech.net"; }
  [ "$BH" = "gogocasino" ] && SLUG=""          # gogocasino hosts carry no licence slug
  if [ -n "$BH" ]; then
    [ -n "$SLUG" ] && LOGIN_ORIGIN="https://bol-${BH}-${SLUG}-${HOSTTAG}.${DOMAIN}" \
                   || LOGIN_ORIGIN="https://bol-${BH}-${HOSTTAG}.${DOMAIN}"
  fi
fi
note "login origin ${LOGIN_ORIGIN:-none derived}"

verify_login() {  # 0 verified, 1 rejected, 2 unreachable
  local origin="$1" user="$2" pass="$3" op="$4" uid="$5" body resp
  [ -n "$origin" ] || return 2
  body=$(jq -nc --arg u "$user" --arg p "$pass" --arg o "$op" \
    '{query:("mutation { loginWithPassword(input: { username: \""+$u+"\", password: \""+$p+"\", operatorUid: \""+$o+"\" }) { authToken viewer { player { playerUid } } } }")}')
  resp=$(curl -s --max-time 25 -X POST "$origin/api/graphql" -H 'Content-Type: application/json' -d "$body" 2>/dev/null) || return 2
  [ -n "$resp" ] || return 2
  if printf '%s' "$resp" | jq -e --arg id "$uid" '.data.loginWithPassword.authToken != null and (.data.loginWithPassword.viewer.player.playerUid == $id)' >/dev/null 2>&1; then
    return 0
  fi
  printf '%s' "$resp" | jq -e '.data' >/dev/null 2>&1 && return 1 || return 2
}

i=1
while [ "$i" -le "$COUNT" ]; do
  RESP=$(curl -s --max-time 30 -X POST "$ORIGIN/testapp/createplayer" \
          -H 'Content-Type: application/json' -d "$PAYLOAD") \
    || fail "POST $ORIGIN/testapp/createplayer failed for account $i of $COUNT"

  ERR=$(printf '%s' "$RESP" | jq -r '.errorMsg // empty' 2>/dev/null)
  PUID=$(printf '%s' "$RESP" | jq -r '.playerUid // empty' 2>/dev/null)
  [ -n "$ERR" ] && [ "$ERR" != "null" ] && fail "the backend refused account $i of $COUNT: $ERR"
  [ -n "$PUID" ] || fail "no playerUid in the response for account $i of $COUNT: $(printf '%s' "$RESP" | head -c 300)"

  USERNAME=$(printf '%s' "$RESP" | jq -r '.userName // empty')
  PASSWORD=$(printf '%s' "$RESP" | jq -r '.password // empty')
  BALANCE=$(printf '%s' "$RESP" | jq -r '.balance // empty')

  verify_login "$LOGIN_ORIGIN" "$USERNAME" "$PASSWORD" "$OPERATOR" "$PUID"
  case "$?" in
    0) VERDICT="login succeeded on ${LOGIN_ORIGIN#https://}" ;;
    1) VERDICT="SUSPECT, login was rejected on ${LOGIN_ORIGIN#https://}" ;;
    *) VERDICT="unverified, could not reach ${LOGIN_ORIGIN:-a login origin}. The account was created" ;;
  esac

  PHX="https://stage-malta-internal.leovegas.net/bo/ws/player/"
  [ "$COUNTRY" = "BR" ] && PHX="https://stage-brazil-internal.leovegas.net/bo/ws/player/"
  PAMGROUP=1; [ "$COUNTRY" = "BR" ] && PAMGROUP=3

  cat <<OUT
- Username / email: $USERNAME
- Password:         $PASSWORD
- Player UID:       $PUID
- Operator:         $OPERATOR
- Country:          $COUNTRY
- Currency:         $CURRENCY
- Balance:          ${BALANCE:-2500}
- Environment:      $ENVTAG on $ENVNAME
- Verified:         $VERDICT
- Tiger BO:         https://leo-staging-trading-bo.goldrush.llc/customer/details/$PUID/transactions
- Phoenix BO:       ${PHX}${PUID}
- PAM BO:           https://backoffice.goldrush.llc/userid/$PUID/?config=https://content.test.goldrush.llc/items/backoffice_config/default&group=$PAMGROUP
OUT
  [ "$COUNT" -gt 1 ] && [ "$i" -lt "$COUNT" ] && echo
  i=$((i+1))
done

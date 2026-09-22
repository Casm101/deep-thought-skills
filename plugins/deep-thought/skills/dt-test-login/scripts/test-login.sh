#!/usr/bin/env bash
# Authenticate a staging test player and write a Playwright storageState for it.
#
# Usage: test-login.sh <https stage url> <account email> [--out <path>] [--print-token]
#
# Writes one file, the storageState, at --out or in the temp directory. Sends one
# request, the login mutation, to the site in the URL. Refuses any host that is not
# a recognised stage or test host.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
die() { printf 'test-login: %s\n' "$1" >&2; exit 1; }

[ $# -ge 2 ] || die "usage: test-login.sh <https stage url> <account email> [--out <path>] [--print-token]"
command -v python3 >/dev/null 2>&1 || die "python3 is not on PATH."
[ -f "$HERE/login.py" ] || die "login.py is missing from $HERE"

case "$1" in
  https://*) ;;
  http://*) die "http will not work. The cookie is secure, and the extension deletes every
            insecure copy the moment it is written, so an http login reads as a silent no-op." ;;
  *) die "the first argument must be a full https URL, got '$1'" ;;
esac

printf '%s' "$2" | grep -q '@' || die "the second argument must be an account email, got '$2'"

exec python3 "$HERE/login.py" "$@"

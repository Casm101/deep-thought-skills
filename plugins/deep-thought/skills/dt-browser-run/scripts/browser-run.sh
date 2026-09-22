#!/usr/bin/env bash
# Run a browser plan and photograph what happened.
#
# Usage: browser-run.sh <plan.json> [out-dir]
#
# The plan names the target URL and the steps. Every step runs, in order.
# Nothing is skipped, nothing is confirmed part way through, and the only URL
# it declines is one that is neither local nor a stage or test host.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
die() { printf 'browser-run: %s\n' "$1" >&2; exit 1; }

PLAN="${1:-}"
[ -n "$PLAN" ] || die "usage: browser-run.sh <plan.json> [out-dir]"
[ -f "$PLAN" ] || die "no plan at $PLAN"
command -v node >/dev/null 2>&1 || die "node is not on PATH. This needs it for playwright-core."
command -v python3 >/dev/null 2>&1 || die "python3 is not on PATH."

OUT="${2:-${TMPDIR:-/tmp}/dt-browser-run-$(date +%Y%m%d-%H%M%S)}"

# Localhost is always fine. Beyond it, the same shape of host dt-test-login accepts:
# this drives a browser as a logged in player, and production is not a test environment.
TARGET=$(python3 -c "
import json,sys,re
from urllib.parse import urlparse
plan=json.load(open(sys.argv[1]))
u=plan.get('url') or ''
h=(urlparse(u).hostname or '').lower()
if not h: sys.exit('no usable url in the plan')
local = h in ('localhost','127.0.0.1','::1','0.0.0.0') or h.endswith(('.local','.localhost'))
safe  = h.endswith(('.lvg-tech.net','-internal.leovegas.net')) or any(
        re.match(r'^(stage|staging|test|dev|integration|payment|qa)\d*\$', t) for t in re.split(r'[.\-]', h))
print(('LOCAL' if local else 'SAFE' if safe else 'REFUSE') + ' ' + h)
" "$PLAN") || die "$TARGET"

case "$TARGET" in
  REFUSE*)
    printf 'browser-run: %s is neither local nor a stage or test host.\n' "${TARGET#REFUSE }" >&2
    printf '            This drives a browser as a signed in player, and production is not a\n' >&2
    printf '            test environment. Accepted: localhost, *.lvg-tech.net,\n' >&2
    printf '            *-internal.leovegas.net, or a host carrying a stage, test, dev,\n' >&2
    printf '            integration, payment or qa segment.\n' >&2
    exit 1 ;;
esac

# playwright-core lives in a cache outside every repository, so a run never adds a
# dependency to the project under test and never dirties its tree.
PW_HOME="${DT_PLAYWRIGHT_HOME:-$HOME/.cache/dt-browser-run}"
if [ ! -d "$PW_HOME/node_modules/playwright-core" ]; then
  printf 'browser-run: installing playwright-core into %s (once)\n' "$PW_HOME" >&2
  mkdir -p "$PW_HOME" || die "could not create $PW_HOME"
  ( cd "$PW_HOME" && npm init -y >/dev/null 2>&1 && npm install --silent playwright-core >/dev/null 2>&1 ) \
    || die "could not install playwright-core into $PW_HOME"
fi
[ -d "$PW_HOME/node_modules/playwright-core" ] || die "playwright-core is still missing from $PW_HOME"

mkdir -p "$OUT" || die "could not create $OUT"

# NODE_PATH does nothing for ESM: node resolves a bare specifier by walking up from
# the importing file, not from an environment variable. So the runner executes from
# inside the cache, beside the node_modules it imports. The repository copy stays the
# only one anybody edits.
cp "$HERE/run-steps.mjs" "$PW_HOME/run-steps.mjs" || die "could not stage the runner in $PW_HOME"
exec node "$PW_HOME/run-steps.mjs" "$PLAN" "$OUT"

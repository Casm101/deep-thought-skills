#!/usr/bin/env bash
# Export an explainer page to stills or to MP4.
#
# Usage: explainer-export.sh <explainer.html> --stills [dir] [--theme light|dark]
#        explainer-export.sh <explainer.html> [--out x.mp4] [--fps 30] [--scale 2] [--no-audio]
#
# Stills need nothing but a browser and are the verification step. MP4 needs ffmpeg.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
die() { printf 'explainer-export: %s\n' "$1" >&2; exit 1; }

[ $# -ge 1 ] || die "usage: explainer-export.sh <explainer.html> [--stills [dir]] [--out x.mp4] ..."
[ -f "$1" ] || die "no explainer at $1"
command -v node >/dev/null 2>&1 || die "node is not on PATH."
[ -f "$HERE/export.mjs" ] || die "export.mjs is missing from $HERE"

# MP4 needs ffmpeg and stills do not, so say which is missing before spending a
# minute rendering frames that cannot be muxed.
case " $* " in
  *" --stills "*) ;;
  *) command -v ffmpeg >/dev/null 2>&1 || die "ffmpeg is not installed, so MP4 export cannot run.
            Ask the user to install it with: brew install ffmpeg
            Or pass --stills, which needs no ffmpeg and is the verification step anyway." ;;
esac

# The exporter finds playwright-core in dt-browser-run's cache. Seed it here rather
# than letting the export fail at the browser launch, since that error arrives after
# the page has already been loaded and reads like a problem with the explainer.
PW_HOME="${DT_PLAYWRIGHT_HOME:-$HOME/.cache/dt-browser-run}"
if [ ! -d "$PW_HOME/node_modules/playwright-core" ] && ! command -v playwright >/dev/null 2>&1; then
  printf 'explainer-export: installing playwright-core into %s (once)\n' "$PW_HOME" >&2
  mkdir -p "$PW_HOME" || die "could not create $PW_HOME"
  ( cd "$PW_HOME" && npm init -y >/dev/null 2>&1 && npm install --silent playwright-core >/dev/null 2>&1 ) \
    || die "could not install playwright-core into $PW_HOME"
fi

exec node "$HERE/export.mjs" "$@"

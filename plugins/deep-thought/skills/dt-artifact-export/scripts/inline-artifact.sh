#!/usr/bin/env bash
# Turn an artifact page into one HTML file that needs nothing else.
#
# Usage: inline-artifact.sh <input.html> <output.html> [--all-subsets]
#
#   --all-subsets   keep every unicode range a webfont ships, not just latin.
#                   Needed for Cyrillic, Greek, Vietnamese or CJK text.
#
# Fetches what the page references and folds it in. Writes the output path and
# nothing else. Exits 2 when something is still reaching outside, so a caller
# can tell a real single file from a page that merely looks like one.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
die() { printf 'inline-artifact: %s\n' "$1" >&2; exit 1; }

[ $# -ge 2 ] || die "usage: inline-artifact.sh <input.html> <output.html> [--all-subsets]"
IN="$1"; OUT="$2"; shift 2

[ -f "$IN" ] || die "no input file at $IN"
[ -s "$IN" ] || die "$IN is empty. The artifact read gave back nothing."
command -v python3 >/dev/null 2>&1 || die "python3 is not on PATH."
[ -f "$HERE/inline.py" ] || die "inline.py is missing from $HERE"

OUT_DIR="$(dirname "$OUT")"
[ -d "$OUT_DIR" ] || die "no directory at $OUT_DIR"
[ -w "$OUT_DIR" ] || die "$OUT_DIR is not writable"

# Never overwrite. A second export of the same artifact is a new file, because the
# first one may already have been sent to somebody.
if [ -e "$OUT" ]; then
  BASE="${OUT%.html}"
  OUT="${BASE}-$(date +%Y%m%d).html"
  N=2
  while [ -e "$OUT" ]; do OUT="${BASE}-$(date +%Y%m%d)-$N.html"; N=$((N + 1)); done
  printf 'inline-artifact: that name was taken, writing %s instead\n' "$OUT" >&2
fi

python3 "$HERE/inline.py" "$IN" "$OUT" "$@"

#!/usr/bin/env bash
# Answer "who is this" from what is already on disk, before anything goes out to a network.
#
# Usage: who-lookup.sh <name or alias or handle or email>
#        who-lookup.sh --list
#
# Exit 0  the person is in the directory, and their row is printed.
# Exit 3  not in the directory. Whatever local git history knows is printed as a
#         starting point, and the caller does the Slack lookup and writes them in.
# Exit 1  something is wrong with the setup.
#
# Read-only. Writes nothing, and reaches no network.
set -uo pipefail

die() { printf 'who-lookup: %s\n' "$1" >&2; exit 1; }

STORE="${DT_MEMORY:-$(head -1 ~/.config/dtm/repos 2>/dev/null)}"
[ -n "$STORE" ] || die "no memory store configured. Expected a path in ~/.config/dtm/repos or \$DT_MEMORY."
[ -d "$STORE" ] || die "the configured store does not exist: $STORE"
PEOPLE="$STORE/work/people/README.md"

if [ "${1:-}" = "--list" ]; then
  [ -f "$PEOPLE" ] || die "no directory yet at $PEOPLE"
  grep -E '^\| ' "$PEOPLE" | grep -v '^| *Name' | grep -v '^| *---'
  exit 0
fi

Q="${1:-}"
[ -n "$Q" ] || die "usage: who-lookup.sh <name or alias or handle or email>"

echo "=== WHO: $Q ==="
echo "directory: $PEOPLE"

if [ -f "$PEOPLE" ]; then
  # A row matches on any column, so a Slack id, a GitHub handle or an alias all find it.
  HIT=$(grep -iE '^\|' "$PEOPLE" | grep -iF "$Q" | grep -v '^| *---' || true)
  if [ -n "$HIT" ]; then
    echo
    echo "--- FOUND ---"
    printf '%s\n' "$HIT"
    echo
    echo "already known, nothing to look up"
    exit 0
  fi
  echo "status:    not in the directory ($(grep -cE '^\| ' "$PEOPLE" 2>/dev/null || echo 0) rows searched)"
else
  echo "status:    no directory file yet, this would be the first entry"
fi

# Local git history is the one route that resolves a GitHub handle for free. A commit
# authored through GitHub carries its noreply address, and the handle is inside it:
#   155470393+TkachVegas@users.noreply.github.com
# The web API cannot do this, because work emails are not public on a profile.
echo
echo "--- WHAT LOCAL GIT HISTORY KNOWS ---"
ROOT="${DT_WORK_ROOT:-$HOME/Documents/Github}"
FOUND=0
if [ -d "$ROOT" ]; then
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    MATCH=$(git -C "$r" log --all --format='%an|%ae' 2>/dev/null | sort -u | grep -iF "$Q" || true)
    if [ -n "$MATCH" ]; then
      printf '%s\n' "$MATCH" | sed 's/^/  /'
      FOUND=1
    fi
  done <<< "$(find "$ROOT" -maxdepth 3 -name .git 2>/dev/null | sed 's|/\.git$||' | sort)"
fi

if [ "$FOUND" = "1" ]; then
  echo
  echo "  a +handle@users.noreply.github.com address above carries the GitHub handle"
else
  echo "  nothing. They have not committed in any repository under $ROOT"
fi

echo
echo "--- NEXT ---"
echo "  look them up in Slack, then write the row. See the skill's Phase 2 and Phase 3."
echo "=== END ==="
exit 3

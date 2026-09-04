#!/usr/bin/env bash
# Build the self-contained packet the reviewing agent receives.
#
# Usage: review-packet.sh [<base ref>]
#   default base: origin/HEAD, else origin/main, else main, else master
#
# Read-only against the repo. Writes one diff file to the OS temp directory and prints its path.
set -uo pipefail

die() { printf 'review-packet: %s\n' "$1" >&2; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository."
ROOT=$(git rev-parse --show-toplevel); cd "$ROOT" || exit 1

BRANCH=$(git rev-parse --abbrev-ref HEAD)
BASE="${1:-}"
if [ -z "$BASE" ]; then
  for c in "$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)" origin/main origin/master main master; do
    [ -n "$c" ] && git rev-parse --verify --quiet "$c" >/dev/null 2>&1 && { BASE="$c"; break; }
  done
fi
[ -n "$BASE" ] || die "could not work out a base branch. Pass one, for example: review-packet.sh origin/main"
MERGE_BASE=$(git merge-base "$BASE" HEAD 2>/dev/null) || die "no merge base between $BASE and HEAD."

CHANGED=$(git diff --name-only "$MERGE_BASE"...HEAD)
[ -n "$CHANGED" ] && [ "$BRANCH" != "$BASE" ] || echo "review-packet: warning, no changes between $BASE and HEAD" >&2

TMP="${TMPDIR:-/tmp}"; TMP="${TMP%/}"
DIFF_FILE="$TMP/overkill-$(git rev-parse --short HEAD)-$$.diff"
git diff "$MERGE_BASE"...HEAD > "$DIFF_FILE"
UNCOMMITTED=$(git status --porcelain | head -20)

echo "=== REVIEW PACKET ==="
echo "Paste everything below the marker into the agent prompt, unchanged."
echo "Add nothing about what you think of the change."
echo
echo "----- PACKET BEGINS -----"
echo "repo:        $(basename "$ROOT")   ($ROOT)"
echo "branch:      $BRANCH"
echo "base:        $BASE   (merge base $(git rev-parse --short "$MERGE_BASE"))"
echo "head:        $(git rev-parse --short HEAD)"
echo "size:        $(printf '%s\n' "$CHANGED" | grep -c . ) files, $(git diff --shortstat "$MERGE_BASE"...HEAD | sed 's/^ *//')"
echo "full diff:   $DIFF_FILE   (read this file, it is the change under review)"
echo
echo "commits on this branch:"
git log --oneline "$MERGE_BASE"..HEAD | head -30 | sed 's/^/  /'
echo
echo "changed files:"
printf '%s\n' "$CHANGED" | sed 's/^/  /'

if [ -n "$UNCOMMITTED" ]; then
  echo
  echo "uncommitted working tree changes, NOT part of the diff above:"
  printf '%s\n' "$UNCOMMITTED" | sed 's/^/  /'
fi

echo
echo "repository documentation to read before reviewing:"
{
  git ls-files | grep -iE '^(CLAUDE|AGENTS|CONVENTIONS|CONTRIBUTING|ARCHITECTURE|README)\.md$'
  git ls-files | grep -iE '^docs/.*\.md$' | head -12
  git ls-files | grep -E '^\.github/(PULL_REQUEST_TEMPLATE\.md|CODEOWNERS)$'
  # the same files scoped to every directory the diff touches, which is where the binding rules live
  printf '%s\n' "$CHANGED" | while IFS= read -r f; do
    d=$(dirname "$f")
    while [ "$d" != "." ] && [ "$d" != "/" ]; do
      git ls-files "$d" 2>/dev/null | grep -iE "^$d/(CLAUDE|AGENTS|CONVENTIONS|README)\.md$"
      d=$(dirname "$d")
    done
  done
} 2>/dev/null | sort -u | sed 's/^/  /'

echo
echo "how this project checks itself:"
# only the packages that own a changed file, plus the root
{
  echo "package.json"
  printf '%s\n' "$CHANGED" | while IFS= read -r f; do
    d=$(dirname "$f")
    while [ "$d" != "." ] && [ "$d" != "/" ]; do
      [ -f "$d/package.json" ] && { echo "$d/package.json"; break; }
      d=$(dirname "$d")
    done
  done
} | sort -u | while IFS= read -r m; do
  [ -f "$m" ] || continue
  scripts=$(jq -r '.scripts // {} | to_entries[] | select(.key|test("^(test|lint|typecheck|type-check)$")) | "    \(.key): \(.value)"' "$m" 2>/dev/null)
  [ -n "$scripts" ] && { echo "  $m"; printf '%s\n' "$scripts"; }
done
[ -f .nvmrc ] && echo "  node: $(cat .nvmrc)"

echo
echo "----- PACKET ENDS -----"
echo
echo "Diff saved at: $DIFF_FILE"
echo "Delete it when the review is done."

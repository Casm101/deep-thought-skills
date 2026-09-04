#!/usr/bin/env bash
# Work out what this repo calls its branches, and where a new one should start from.
#
# Usage: branch-recon.sh [<proposed branch name>]
#
# Read-only. Creates nothing, fetches nothing, switches nothing.
set -uo pipefail

WANT="${1:-}"
die() { printf 'branch-recon: %s\n' "$1" >&2; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository."
ROOT=$(git rev-parse --show-toplevel); cd "$ROOT" || exit 1

DEFAULT=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
if [ -z "$DEFAULT" ]; then
  for c in main master trunk develop; do
    git rev-parse --verify --quiet "origin/$c" >/dev/null 2>&1 && { DEFAULT="$c"; break; }
  done
fi
DEFAULT="${DEFAULT:-main}"

echo "=== BRANCH RECON ==="
echo "default branch: $DEFAULT"
echo "you are on:     $(git rev-parse --abbrev-ref HEAD)"
echo "local $DEFAULT is $(git rev-list --count "origin/$DEFAULT".."$DEFAULT" 2>/dev/null || echo '?') commit(s) ahead and $(git rev-list --count "$DEFAULT".."origin/$DEFAULT" 2>/dev/null || echo '?') behind origin/$DEFAULT"
echo "                (branch from origin/$DEFAULT, not from a stale local copy)"

DIRTY=$(git status --porcelain | grep -vE '^\?\?' || true)
echo
if [ -n "$DIRTY" ]; then
  echo "--- uncommitted changes to tracked files, these come with you onto the new branch ---"
  printf '%s\n' "$DIRTY" | sed 's/^/  /'
  echo "  That is usually what you want. If it is not, commit or stash before switching."
else
  echo "working tree: clean"
fi

echo
echo "--- documented branch naming ---"
FOUND=0
for f in $(git ls-files | grep -iE '(CONTRIBUTING|CONVENTIONS|CLAUDE|AGENTS|README|RELEASE|BRANCH)[^/]*\.md$' | head -12); do
  hits=$(grep -niE 'branch (nam|prefix|convention)|naming convention|feature/|bugfix/|hotfix/|release/' "$f" 2>/dev/null | head -3)
  [ -n "$hits" ] && { echo "  $f"; printf '%s\n' "$hits" | sed 's/^/      /' | cut -c1-140; FOUND=1; }
done
[ "$FOUND" = "0" ] && echo "  nothing documented. Fall back to what the history shows, below."

echo
echo "--- what the history shows, prefixes on real branches ---"
SAMPLE=$({ git branch -r --format='%(refname:short)' 2>/dev/null | sed "s|^origin/||" | grep -v '^HEAD'
           gh pr list --state all --limit 60 --json headRefName -q '.[].headRefName' 2>/dev/null; } \
         | grep -v '^$' | grep -vE "^($DEFAULT|master|main|develop)$" | sort -u)

echo "$SAMPLE" | sed -n 's|^\([a-z]\{3,12\}\)/.*|\1/|p' | sort | uniq -c | sort -rn | head -8 | sed 's/^/  /'
NOPREFIX=$(printf '%s\n' "$SAMPLE" | grep -vE '^[a-z]{3,12}/' | grep -c . || true)
echo "  $NOPREFIX branch(es) with no prefix at all"

echo
echo "--- the most recently updated branches, copy the shape of these ---"
git for-each-ref --sort=-committerdate --count=40 \
  --format='%(committerdate:short)  %(refname:short)' refs/remotes/origin 2>/dev/null \
  | grep -v 'origin/HEAD' | sed "s|origin/||" \
  | grep -vE " ($DEFAULT|master|main|develop|origin)$" | head -12 | sed 's/^/  /'

echo
echo "--- ticket key prefixes, most used first ---"
KEYS=$(printf '%s\n' "$SAMPLE" | grep -oE '[A-Z]{2,4}-[0-9]{3,6}' | sed -E 's/-[0-9]+$//' | sort | uniq -c | sort -rn | head -5)
if [ -n "$KEYS" ]; then
  printf '%s\n' "$KEYS" | sed 's/^/  /'
  echo "  use the one at the top unless the ticket you have says otherwise"
else
  echo "  none, this repo may not put ticket keys in branch names"
fi

if [ -n "$WANT" ]; then
  echo
  echo "--- the name you proposed: $WANT ---"
  if git rev-parse --verify --quiet "refs/heads/$WANT" >/dev/null 2>&1; then
    echo "  STOP: a local branch called that already exists."
  elif git rev-parse --verify --quiet "refs/remotes/origin/$WANT" >/dev/null 2>&1; then
    echo "  STOP: origin already has a branch called that."
  else
    echo "  free to use"
  fi
  printf '%s' "$WANT" | grep -qE '^[A-Za-z0-9._/-]+$' || echo "  WARNING: contains characters that will cause trouble in URLs and shells"
  STRIPPED=$(printf '%s' "$WANT" | sed -E 's/[A-Z]{2,4}-[0-9]{3,6}//g')
  printf '%s' "$STRIPPED" | grep -qE '[A-Z]' && echo "  note: capitals outside the ticket key. Most repos keep the rest lower case, check the examples above"
  echo
  echo "  create it with:"
  echo "    git fetch origin"
  echo "    git switch -c $WANT origin/$DEFAULT --no-track"
fi

echo
echo "=== END RECON ==="

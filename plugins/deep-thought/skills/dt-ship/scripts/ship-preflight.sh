#!/usr/bin/env bash
# Everything you need to know before pushing a branch and opening its PR.
#
# Usage: ship-preflight.sh [<base ref>]
#
# Read-only. Pushes nothing, creates nothing.
set -uo pipefail

die() { printf 'ship-preflight: %s\n' "$1" >&2; exit 1; }
command -v gh >/dev/null 2>&1 || die "gh CLI not found. Install it (brew install gh), then 'gh auth login'."
gh auth status >/dev/null 2>&1 || die "gh is not authenticated. Run 'gh auth login'."
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository."
ROOT=$(git rev-parse --show-toplevel); cd "$ROOT" || exit 1

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) || die "no GitHub remote here."
BRANCH=$(git rev-parse --abbrev-ref HEAD)
DEFAULT=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
DEFAULT="${DEFAULT:-main}"
BASE="${1:-$DEFAULT}"

echo "=== SHIP PREFLIGHT ($REPO) ==="
echo "branch:  $BRANCH"
echo "base:    $BASE   (repo default is $DEFAULT)"

BLOCK=0
if [ "$BRANCH" = "$DEFAULT" ] || [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  echo "STOP:    you are on the default branch. There is nothing to ship from here."
  BLOCK=1
fi

# ---- is there anything to ship -------------------------------------------
MB=$(git merge-base "origin/$BASE" HEAD 2>/dev/null || git merge-base "$BASE" HEAD 2>/dev/null)
if [ -n "$MB" ]; then
  AHEAD=$(git rev-list --count "$MB"..HEAD)
  echo "commits: $AHEAD ahead of $BASE"
  [ "$AHEAD" = "0" ] && { echo "STOP:    no commits to ship. Commit first, dt-implement does that."; BLOCK=1; }
  git log --oneline "$MB"..HEAD | head -20 | sed 's/^/  /'
else
  echo "commits: could not find a merge base with $BASE"
fi

# ---- working tree --------------------------------------------------------
DIRTY=$(git status --porcelain | grep -vE '^\?\?' || true)
UNTRACKED=$(git ls-files --others --exclude-standard | head -10)
echo
if [ -n "$DIRTY" ]; then
  echo "--- uncommitted changes to TRACKED files ---"
  printf '%s\n' "$DIRTY" | sed 's/^/  /'
  echo "  These will NOT be in the PR. Commit them or stash them first, or decide they do not belong."
  BLOCK=1
else
  echo "working tree: clean, no uncommitted changes to tracked files"
fi
[ -n "$UNTRACKED" ] && { echo "untracked, ignore unless they belong to this work:"; printf '%s\n' "$UNTRACKED" | sed 's/^/  /'; }

# ---- remote state --------------------------------------------------------
echo
UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
if [ -n "$UPSTREAM" ]; then
  echo "upstream: $UPSTREAM"
  git fetch --quiet origin "$BRANCH" 2>/dev/null || true
  UNPUSHED=$(git rev-list --count "$UPSTREAM"..HEAD 2>/dev/null || echo '?')
  OWN=$(git rev-list --count "$UPSTREAM"..HEAD --not "origin/$BASE" 2>/dev/null || echo '?')
  BEHIND=$(git rev-list --count HEAD.."$UPSTREAM" 2>/dev/null || echo '?')
  echo "          $OWN unpushed commit(s) of this branch's own work"
  if [ "$UNPUSHED" != "$OWN" ]; then
    echo "          ($UNPUSHED in total, the rest came in with a merge from $BASE and are already on the remote)"
  fi
  echo "          $BEHIND commit(s) on the remote you do not have"
  [ "$BEHIND" != "0" ] && [ "$BEHIND" != "?" ] && echo "          the remote is ahead. Do NOT force push. Ask before rewriting anything."
else
  echo "upstream: none yet, so the push needs -u"
  echo "          git push -u origin $BRANCH"
fi

# ---- existing PR ---------------------------------------------------------
echo
EXISTING=$(gh pr list --repo "$REPO" --head "$BRANCH" --state all --json number,state,url,isDraft \
             -q '.[] | "#\(.number) \(.state)\(if .isDraft then " DRAFT" else "" end) \(.url)"' 2>/dev/null)
HAS_OPEN=$(gh pr list --repo "$REPO" --head "$BRANCH" --state open --json number -q '.[0].number' 2>/dev/null)
if [ -n "$EXISTING" ]; then
  echo "--- a PR already exists for this branch ---"
  printf '%s\n' "$EXISTING" | sed 's/^/  /'
  echo "  Do not open a second one. Push, then hand the description to dt-pr-data."
else
  echo "existing PR: none. This branch has never had one."
fi

# ---- title and body material --------------------------------------------
echo
KEY=$(printf '%s' "$BRANCH" | grep -oiE '[A-Z]{2}-[0-9]{4,6}' | head -1)
echo "ticket key in branch: ${KEY:-none found}"
echo "last commit subject:  $(git log -1 --format=%s)"
echo "how this repo titles PRs, recent merges:"
gh pr list --repo "$REPO" --state merged --limit 5 --json title -q '.[] | "  \(.title)"' 2>/dev/null

TPL=""
for p in .github/PULL_REQUEST_TEMPLATE.md .github/pull_request_template.md \
         .github/PULL_REQUEST_TEMPLATE/default.md docs/PULL_REQUEST_TEMPLATE.md PULL_REQUEST_TEMPLATE.md; do
  [ -f "$p" ] && { TPL="$p"; break; }
done
echo
echo "PR template: ${TPL:-none found, dt-pr-data will build a structure from merged PRs}"

echo
echo "branching or release docs to check before choosing a base:"
git ls-files | grep -iE '(RELEASE|BRANCH|CONTRIBUTING)[^/]*\.md$' | head -6 | sed 's/^/  /'
git ls-files | grep -E '^\.github/workflows/.*(branch|backmerge|release)' | head -4 | sed 's/^/  /'

echo
if [ "$BLOCK" = "1" ]; then
  echo "RESULT: blocked. Fix what is marked STOP above before shipping."
elif [ -n "${HAS_OPEN:-}" ]; then
  echo "RESULT: clear to push. PR #$HAS_OPEN is already open for this branch, so do NOT open another."
  echo "        Push, then hand the description to dt-pr-data."
else
  echo "RESULT: clear to push and open a PR against $BASE."
fi
echo "=== END PREFLIGHT ==="

#!/usr/bin/env bash
# Work out whether this branch can be updated from the default branch, and how.
#
# Usage: update-preflight.sh [<branch>]
#   no argument -> the current branch
#
# Read-only. Fetches nothing, merges nothing, changes nothing.
set -uo pipefail

die() { printf 'update-preflight: %s\n' "$1" >&2; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository."
cd "$(git rev-parse --show-toplevel)" || exit 1

CUR=$(git rev-parse --abbrev-ref HEAD)
TARGET="${1:-$CUR}"
DEFAULT=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
if [ -z "$DEFAULT" ]; then
  for c in main master trunk develop; do
    git rev-parse --verify --quiet "origin/$c" >/dev/null 2>&1 && { DEFAULT="$c"; break; }
  done
fi
DEFAULT="${DEFAULT:-main}"

echo "=== BRANCH UPDATE PREFLIGHT ==="
echo "target branch:  $TARGET"
echo "currently on:   $CUR"
echo "merge from:     origin/$DEFAULT"

BLOCK=0

# ---- fix branch guard, matching the CI check's own patterns ---------------
# scripts/ci/src/check-fix-branch-hygiene.ts:
#   fixBranchPattern = /^(hotfix|rcfix|release)\//
#   isConflictResolutionBranch = isFixBranch(b) && b.endsWith("-merge")
IS_FIX=0; IS_MERGE_BRANCH=0
printf '%s' "$TARGET" | grep -qE '^(hotfix|rcfix|release)/' && IS_FIX=1
[ "$IS_FIX" = "1" ] && printf '%s' "$TARGET" | grep -qE -- '-merge$' && IS_MERGE_BRANCH=1

echo
if [ "$IS_FIX" = "1" ] && [ "$IS_MERGE_BRANCH" = "0" ]; then
  echo "STOP: '$TARGET' is a fix branch."
  echo "      Merging the default branch into it destroys the record of what shipped, and CI"
  echo "      rejects it. See docs/RELEASE-BRANCHING.md and the Fix Branch Hygiene check."
  echo "      Sanctioned routes instead:"
  echo "        one specific change already on $DEFAULT:  git cherry-pick -x <sha>"
  echo "        backmerge conflicts:                      branch ${TARGET}-merge and merge there"
  BLOCK=1
elif [ "$IS_MERGE_BRANCH" = "1" ]; then
  echo "ok:   '$TARGET' is a conflict-resolution branch, where merging the default branch is the"
  echo "      sanctioned flow. CI exempts it."
else
  echo "ok:   not a fix branch, so a merge from origin/$DEFAULT is fine"
fi

# ---- where the branch lives, and the state of the tree --------------------
LOCAL=0; REMOTE=0
git rev-parse --verify --quiet "refs/heads/$TARGET" >/dev/null 2>&1 && LOCAL=1
git rev-parse --verify --quiet "refs/remotes/origin/$TARGET" >/dev/null 2>&1 && REMOTE=1
DIRTY=$(git status --porcelain | grep -vE '^\?\?' || true)

echo
echo "branch is local:  $([ "$LOCAL" = 1 ] && echo yes || echo no)"
echo "branch on origin: $([ "$REMOTE" = 1 ] && echo yes || echo no)"
if [ -n "$DIRTY" ]; then
  echo "working tree:     DIRTY"
  printf '%s\n' "$DIRTY" | head -8 | sed 's/^/                  /'
else
  echo "working tree:     clean"
fi

echo
echo "--- route ---"
if [ "$LOCAL" = "0" ] && [ "$REMOTE" = "0" ]; then
  echo "STOP: '$TARGET' exists neither locally nor on origin. Check the name."
  BLOCK=1
elif [ "$TARGET" = "$CUR" ] && [ -z "$DIRTY" ]; then
  echo "in place: you are on it and the tree is clean. Merge here."
elif [ "$TARGET" = "$CUR" ] && [ -n "$DIRTY" ]; then
  echo "STOP: you are on '$TARGET' and it has uncommitted changes. Commit or stash them first."
  BLOCK=1
elif [ "$LOCAL" = "1" ] && [ -z "$DIRTY" ]; then
  echo "checkout: switch to '$TARGET', merge, and stay there."
elif [ "$LOCAL" = "1" ] && [ -n "$DIRTY" ]; then
  echo "STOP: '$TARGET' is local but this tree has uncommitted changes. Commit or stash first."
  BLOCK=1
elif [ -n "$DIRTY" ]; then
  echo "worktree: '$TARGET' is not local and this tree is dirty, so do it in a throwaway worktree"
  echo "          and leave the current checkout untouched."
  echo "          NOTE: a fresh worktree has no working @gutro/* links, so verification needs"
  echo "          'pnpm install' in it first. Budget for that before promising a verified push."
else
  echo "checkout: fetch '$TARGET' from origin, switch to it, merge, and stay there."
fi

# ---- is there anything to merge ------------------------------------------
echo
BASE_REF="origin/$DEFAULT"
TIP=$( [ "$LOCAL" = 1 ] && echo "$TARGET" || echo "origin/$TARGET" )
if git rev-parse --verify --quiet "$BASE_REF" >/dev/null 2>&1 && git rev-parse --verify --quiet "$TIP" >/dev/null 2>&1; then
  INCOMING=$(git rev-list --count "$TIP".."$BASE_REF" 2>/dev/null || echo '?')
  AHEAD=$(git rev-list --count "$BASE_REF".."$TIP" 2>/dev/null || echo '?')
  echo "incoming from $BASE_REF: $INCOMING commit(s)"
  echo "this branch is ahead by:  $AHEAD commit(s)"
  if [ "$INCOMING" = "0" ]; then
    echo "Already up to date. Stop rather than making an empty merge commit."
  else
    echo "files those commits touch that this branch also touched:"
    MB=$(git merge-base "$BASE_REF" "$TIP" 2>/dev/null)
    if [ -n "$MB" ]; then
      comm -12 \
        <(git diff --name-only "$MB" "$BASE_REF" | sort -u) \
        <(git diff --name-only "$MB" "$TIP" | sort -u) | head -20 | sed 's/^/  /'
      OVERLAP=$(comm -12 <(git diff --name-only "$MB" "$BASE_REF" | sort -u) <(git diff --name-only "$MB" "$TIP" | sort -u) | grep -c . || true)
      echo "  ($OVERLAP overlapping file(s); these are where conflicts will land)"
    fi
  fi
  echo "note: a clean merge can still break the build. Two changes can agree textually and"
  echo "      contradict each other, so verify before pushing."
fi

# ---- a PR aiming somewhere other than the default branch -----------------
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  PRBASE=$(gh pr list --head "$TARGET" --state open --json baseRefName -q '.[0].baseRefName' 2>/dev/null)
  if [ -n "$PRBASE" ] && [ "$PRBASE" != "$DEFAULT" ]; then
    echo
    echo "CAUTION: the open PR for '$TARGET' targets '$PRBASE', not '$DEFAULT'."
    echo "         Merging origin/$DEFAULT in would push unshipped history toward a release branch."
    echo "         Ask before going further."
  fi
fi

echo
[ "$BLOCK" = "1" ] && echo "RESULT: blocked. Fix what is marked STOP above." || echo "RESULT: clear to update."
echo "=== END ==="

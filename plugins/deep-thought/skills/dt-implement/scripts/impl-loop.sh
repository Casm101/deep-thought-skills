#!/usr/bin/env bash
# Print the exact commands for the implement loop, for the files you have actually changed.
#
# Usage: impl-loop.sh
#
# Read-only. Runs nothing, changes nothing.
set -uo pipefail

die() { printf 'impl-loop: %s\n' "$1" >&2; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository."
ROOT=$(git rev-parse --show-toplevel); cd "$ROOT" || exit 1

BRANCH=$(git rev-parse --abbrev-ref HEAD)
DEFAULT=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
DEFAULT="${DEFAULT:-main}"

echo "=== IMPLEMENT LOOP ==="
echo "branch:  $BRANCH"
if [ "$BRANCH" = "$DEFAULT" ] || [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  echo "         STOP. This is the default branch. Branch before you write anything."
fi
[ -f .nvmrc ] && echo "node:    .nvmrc wants $(cat .nvmrc), shell has $(node -v 2>/dev/null || echo 'no node on PATH')"

CHANGED=$(git diff --name-only; git diff --cached --name-only)
CHANGED=$(printf '%s\n' "$CHANGED" | grep -v '^$' | sort -u)
UNTRACKED=$(git ls-files --others --exclude-standard)

echo
echo "--- changed, tracked files ---"
if [ -n "$CHANGED" ]; then printf '%s\n' "$CHANGED" | sed 's/^/  /'; else echo "  (none yet)"; fi

if [ -n "$UNTRACKED" ]; then
  echo
  echo "--- untracked files, do NOT stage unless they are part of this work ---"
  printf '%s\n' "$UNTRACKED" | head -20 | sed 's/^/  /'
  echo "  Stage by path. Never 'git add -A' or 'git add .' with these sitting here."
fi

# tests that correspond to the changed source files.
# One file listing, reused, so a large working diff does not turn this into a git call per file.
ALL_TESTS=$(git ls-files | grep -E '(\.spec\.|\.test\.)')
COUNT=$(printf '%s\n' "$CHANGED" | grep -c . || true)
echo
echo "--- test files for what you changed ---"
[ "${COUNT:-0}" -gt 40 ] && echo "  ($COUNT changed files, showing the first 40)"
printf '%s\n' "$CHANGED" | head -40 | while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in *.spec.*|*.test.*) echo "  $f   (a test itself)"; continue;; esac
  base=$(basename "$f"); stem="${base%%.*}"; dir=$(dirname "$f")
  hit=$(printf '%s\n' "$ALL_TESTS" | grep -E "^${dir}/(__tests__/|tests/)?${stem}\.(spec|test)\.[A-Za-z]+$" | head -2)
  if [ -n "$hit" ]; then printf '%s\n' "$hit" | sed 's/^/  /'
  else echo "  none beside $f"; fi
done | sort -u

# owning packages and their commands
echo
echo "--- the loop, per package that owns a changed file ---"
{
  printf '%s\n' "$CHANGED" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    d=$(dirname "$f")
    while [ "$d" != "." ] && [ "$d" != "/" ]; do
      [ -f "$d/package.json" ] && { echo "$d"; break; }
      d=$(dirname "$d")
    done
  done
} | sort -u | while IFS= read -r pkg; do
  [ -n "$pkg" ] || continue
  tc=$(jq -r '.scripts["type-check"] // .scripts.typecheck // empty' "$pkg/package.json" 2>/dev/null)
  te=$(jq -r '.scripts.test // empty' "$pkg/package.json" 2>/dev/null)
  li=$(jq -r '.scripts.lint // empty' "$pkg/package.json" 2>/dev/null)
  echo "  $pkg"
  [ -n "$tc" ] && echo "    types, run often:        (cd $pkg && pnpm type-check)"
  [ -n "$te" ] && echo "    one test file, run often: (cd $pkg && pnpm test --run <path to spec>)"
  [ -n "$te" ] && echo "    whole suite, run ONCE at the end: (cd $pkg && pnpm test --run)"
  [ -n "$li" ] && echo "    lint, before committing:  (cd $pkg && pnpm lint)"
  [ -z "$tc$te$li" ] && echo "    no test, lint or type-check script in this package.json"
done

echo
echo "Reminders:"
echo "  Types and one test file after every slice. The whole suite once, at the very end."
echo "  Never pass -u or --updateSnapshot. Never --no-verify on the commit."
echo
echo "=== END ==="

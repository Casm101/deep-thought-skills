#!/usr/bin/env bash
# Decide whether an unattended run can safely start here.
#
# Usage: auto-preflight.sh [<ticket key>]
#
# Read-only. Changes nothing, runs no tests.
set -uo pipefail

KEY="${1:-}"
GO=1
no() { GO=0; printf 'NO   %s\n' "$1"; }
ok() { printf 'ok   %s\n' "$1"; }
warn() { printf 'warn %s\n' "$1"; }

echo "=== UNATTENDED RUN PREFLIGHT ==="

# ---- tools ---------------------------------------------------------------
for t in git gh jq; do
  command -v "$t" >/dev/null 2>&1 && ok "$t present" || no "$t missing"
done
gh auth status >/dev/null 2>&1 && ok "gh authenticated" || no "gh not authenticated"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { no "not a git repository"; echo "RESULT: NO-GO"; exit 1; }
ROOT=$(git rev-parse --show-toplevel); cd "$ROOT" || exit 1

# ---- the skills this run delegates to ------------------------------------
# The siblings ship in the same plugin, so find them from this script's own location
# rather than an install path or an environment variable.
SKILLS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MISSING=""
for s in dt-create-branch dt-investigation dt-grilling dt-to-tasks dt-tdd-prep dt-implement dt-code-review dt-ship dt-pr-data dt-handoff dt-unslop; do
  [ -f "$SKILLS_ROOT/$s/SKILL.md" ] || MISSING="$MISSING $s"
done
[ -z "$MISSING" ] && ok "all delegated skills present in the plugin" || no "missing skills:$MISSING"

# ---- repository state ----------------------------------------------------
BRANCH=$(git rev-parse --abbrev-ref HEAD)
DEFAULT=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
DEFAULT="${DEFAULT:-main}"
echo "     branch: $BRANCH, repo default: $DEFAULT"

DIRTY=$(git status --porcelain | grep -vE '^\?\?' || true)
if [ -n "$DIRTY" ]; then
  no "uncommitted changes to tracked files. An unattended run must start from a clean tree."
  printf '%s\n' "$DIRTY" | head -10 | sed 's/^/       /'
else
  ok "working tree clean"
fi

if [ "$BRANCH" = "$DEFAULT" ]; then
  ok "on the default branch, so a fresh branch gets created"
else
  AHEAD=$(git rev-list --count "origin/$DEFAULT"..HEAD 2>/dev/null || echo 0)
  if [ "$AHEAD" -gt 0 ]; then
    warn "already on $BRANCH with $AHEAD commit(s) of its own. Decide whether this run continues that work or needs its own branch."
  else
    ok "on $BRANCH with no commits of its own"
  fi
fi

# ---- can the project be checked ------------------------------------------
PKGS=$(git ls-files | grep -E '(^|/)package\.json$' | head -40)
HAVE_TEST=0
for m in $PKGS; do
  [ -n "$(jq -r '.scripts.test // empty' "$m" 2>/dev/null)" ] && { HAVE_TEST=1; break; }
done
[ "$HAVE_TEST" = "1" ] && ok "at least one package defines a test script" || warn "no test script found. An unattended run with no tests cannot verify itself."
if [ -f .nvmrc ]; then
  WANT=$(cat .nvmrc); HAVE=$(node -v 2>/dev/null || echo none)
  [ "$WANT" = "$HAVE" ] && ok "node $HAVE matches .nvmrc" || no "node mismatch, .nvmrc wants $WANT and the shell has $HAVE"
fi

# ---- the ticket ----------------------------------------------------------
if [ -n "$KEY" ]; then
  printf '%s' "$KEY" | grep -qiE '^[A-Z]{2,4}-[0-9]{3,6}$' && ok "ticket key looks well formed: $KEY" \
    || warn "ticket key '$KEY' does not look like a key. Treat the input as free text instead."
else
  warn "no ticket key given. The run works from context, and the definition of done has to come from somewhere."
fi

# ---- areas an unattended run must not touch -------------------------------
echo
echo "--- sensitive areas that exist in this repo ---"
# Whole path segments only, and no "token": a themed UI codebase is full of design tokens.
git ls-files \
  | grep -iE '(^|/)(aml|kyc|fraud|responsible.?gaming|payments?|wallet|deposits?|withdrawals?|auth|authentication|authorisation|authorization|session|secrets?|credentials?|migrations?)(/|$|\.)|(^|/)\.env($|\.)' \
  | grep -viE '(\.spec\.|\.test\.|__mocks__|/docs?/|\.md$)' \
  | sed 's|/[^/]*$||' | sort -u | head -12 | sed 's/^/  /'
echo "  This is a hint, not a ban on those directories. The rule is about what your change touches:"
echo "  if the diff would alter money movement, identity, access control, a migration, or anything"
echo "  under AML, KYC, responsible gaming or fraud, stop and hand it to a person."

echo
if [ "$GO" = "1" ]; then
  echo "RESULT: GO"
else
  echo "RESULT: NO-GO. Fix every NO above, or hand the work to a person."
fi
echo "=== END PREFLIGHT ==="

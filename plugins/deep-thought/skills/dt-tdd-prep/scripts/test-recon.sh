#!/usr/bin/env bash
# Find out how this repo tests, and what already covers the target.
#
# Usage: test-recon.sh <path | symbol | keywords ...>
#
# Read-only. Writes nothing, runs no tests.
set -uo pipefail

TARGET="${*:-}"
[ -n "$TARGET" ] || { echo "test-recon: give a path, a symbol, or a few keywords." >&2; exit 1; }

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT" || exit 1
have() { command -v "$1" >/dev/null 2>&1; }
hr() { printf '\n== %s ==\n' "$1"; }

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  FILES=$(git ls-files -z | tr '\0' '\n')
else
  FILES=$(find . -type f -not -path '*/node_modules/*' -not -path '*/.git/*' | sed 's|^\./||')
fi
allf() { printf '%s\n' "$FILES"; }
TESTRE='(\.spec\.|\.test\.|/test_[^/]*\.py$|_test\.go$|Tests?\.(cs|java|kt)$)'

echo "=== TEST RECON ==="
echo "root:   $ROOT"
echo "target: $TARGET"

# ---------------------------------------------------------------- the target
hr "TARGET FILES"
CANDIDATES=""
if [ -e "$TARGET" ]; then
  CANDIDATES="$TARGET"
  echo "(given as a path)"
else
  if have rg; then
    BYNAME=$(allf | grep -iE "$(printf '%s' "$TARGET" | tr ' ' '|')" | grep -vE "$TESTRE" | head -12)
    BYSYM=$(rg -l --hidden -g '!node_modules' -g '!*.lock' -e "$(printf '%s' "$TARGET" | sed 's/ /.*/g')" \
              2>/dev/null | grep -vE "$TESTRE" | head -12)
    CANDIDATES=$(printf '%s\n%s\n' "$BYNAME" "$BYSYM" | grep -v '^$' | sort -u | head -15)
  else
    CANDIDATES=$(allf | grep -iE "$(printf '%s' "$TARGET" | tr ' ' '|')" | grep -vE "$TESTRE" | head -15)
  fi
  echo "(matched by filename and by content)"
fi
if [ -z "$CANDIDATES" ]; then
  echo "nothing matched \"$TARGET\" as a whole. Trying each word separately:"
  for w in $TARGET; do
    [ ${#w} -ge 3 ] || continue
    echo "  word \"$w\":"
    allf | grep -iE "/[^/]*${w}[^/]*$" | grep -vE "$TESTRE" | head -5 | sed 's|^|    |'
  done
  echo "  Pick the real file from the list above and rerun with its path, or ask the user which"
  echo "  component they mean. Do not guess a name that does not exist in the repo."
fi

# ------------------------------------------------- coverage of those files
hr "EXISTING TEST COVERAGE PER TARGET FILE"
printf '%s\n' "$CANDIDATES" | while IFS= read -r f; do
  [ -n "$f" ] || continue
  base=$(basename "$f"); stem="${base%%.*}"; dir=$(dirname "$f")
  # A test counts as covering this file only if it sits beside it, or in its __tests__ dir.
  # Matching on the stem alone is wrong: every index.tsx would match every index.spec.ts.
  hits=$(allf | grep -E "^${dir}/(__tests__/|tests/)?${stem}\.(spec|test)\.[A-Za-z]+$" | head -4)
  if [ -n "$hits" ]; then
    printf 'TESTED     %s\n' "$f"
    printf '%s\n' "$hits" | sed 's|^|             -> |'
  else
    elsewhere=$(allf | grep -E "$TESTRE" | grep -E "/${stem}\.(spec|test)\.[A-Za-z]+$" | head -3)
    near=$(allf | grep -E "^${dir}/" | grep -E "$TESTRE" | head -3)
    printf 'NO TEST    %s\n' "$f"
    if [ -n "$elsewhere" ]; then
      printf '%s\n' "$elsewhere" | sed 's|^|             same name elsewhere, open it before assuming it covers this: |'
    fi
    [ -n "$near" ] && printf '%s\n' "$near" | sed 's|^|             tests beside it: |'
  fi
done

hr "TESTS THAT MENTION THE TARGET (may already cover part of it)"
if have rg; then
  rg -l --hidden -g '!node_modules' -e "$(printf '%s' "$TARGET" | sed 's/ /.*/g')" 2>/dev/null \
    | grep -E "$TESTRE" | head -20 || echo "(none)"
else
  echo "(ripgrep not installed)"
fi

# ------------------------------------------------------- how the repo tests
hr "TEST FRAMEWORK AND RUN COMMAND"
NEAREST=$(printf '%s\n' "$CANDIDATES" | head -1)
d=$(dirname "${NEAREST:-.}")
PKG=""
while [ "$d" != "." ] && [ "$d" != "/" ]; do
  if [ -f "$d/package.json" ] && [ -n "$(jq -r '.scripts.test // empty' "$d/package.json" 2>/dev/null)" ]; then PKG="$d"; break; fi
  d=$(dirname "$d")
done
[ -z "$PKG" ] && [ -f package.json ] && [ -n "$(jq -r '.scripts.test // empty' package.json 2>/dev/null)" ] && PKG="."

# No target yet, or the target sits outside any tested package: show every package that can run tests.
if [ -z "$PKG" ] && have jq; then
  echo "no package resolved from the target. Packages in this repo that define a test script:"
  allf | grep -E '(^|/)package\.json$' | while IFS= read -r m; do
    t=$(jq -r '.scripts.test // empty' "$m" 2>/dev/null)
    [ -n "$t" ] && printf '  %-46s test: %s\n' "$(dirname "$m")" "$t"
  done | head -20
  echo "Pick the one that owns the target file, then rerun this script with a path inside it."
fi

if [ -n "$PKG" ] && have jq; then
  echo "nearest package with a test script: $PKG"
  jq -r '.scripts | to_entries[] | select(.key|test("^test")) | "  \(.key): \(.value)"' "$PKG/package.json"
  echo "framework and helpers:"
  jq -r '((.devDependencies // {}) + (.dependencies // {})) | to_entries[]
         | select(.key|test("jest|vitest|testing-library|playwright|cypress|enzyme|mocha|chai|pytest|rspec"))
         | "  \(.key) \(.value)"' "$PKG/package.json"
  echo "run one file with:"
  echo "  cd $PKG && pnpm test --run <path-to-test>       # add --reporter=verbose to see case names"
else
  echo "no JS package test script found. Look for: pytest.ini, tox.ini, Makefile, go test, gradle, dotnet test"
  allf | grep -E '(pytest\.ini|tox\.ini|Makefile|pyproject\.toml|go\.mod|build\.gradle)' | head -5
fi

echo
echo "test config and setup files:"
allf | grep -iE '(jest|vitest)\.(config|base|setup)[^/]*$|setupTests|test-setup|conftest\.py$' | head -12

echo
echo "node version this repo expects:"
[ -f .nvmrc ] && echo "  .nvmrc: $(cat .nvmrc)"
have jq && [ -f package.json ] && echo "  engines: $(jq -rc '.engines // "none"' package.json)"
echo "  (a test run on the wrong major version fails for reasons that have nothing to do with your test)"

hr "TESTING DOCUMENTATION IN THIS REPO"
allf | grep -iE '(TESTING|TEST_GUIDE|TESTING_GUIDE)[^/]*\.md$' | head -5
if have rg; then
  rg -l --hidden -g '*.md' -g '!node_modules' -e '(?i)(writing tests|test conventions|how to test|testing guide)' 2>/dev/null | head -8
fi

hr "NEAREST EXAMPLE TESTS TO COPY THE HOUSE PATTERN FROM"
EXDIR=$(dirname "${NEAREST:-.}")
{ allf | grep -E "^${EXDIR}/" | grep -E "$TESTRE"
  allf | grep -E "^$(dirname "$EXDIR")/" | grep -E "$TESTRE"; } 2>/dev/null | sort -u | head -6 \
  | while IFS= read -r t; do [ -f "$t" ] && printf '%6s lines  %s\n' "$(wc -l < "$t" | tr -d ' ')" "$t"; done

hr "SHARED TEST HELPERS, FIXTURES AND MOCKS NEAR THE TARGET"
allf | grep -E "^${EXDIR%/*}/" | grep -iE '(__mocks__|/mocks?/|fixtures?|test-utils|testUtils|testHelpers|render[A-Za-z]*\.tsx?$)' | head -12 || true
allf | grep -iE '(test-utils|testUtils|test-helpers|customRender)' | head -8 || true

echo
echo "Read the example tests before writing any. Match their imports, their render helper, their"
echo "naming, and how they mock. Do not introduce a new testing library."
echo
echo "=== END RECON ==="

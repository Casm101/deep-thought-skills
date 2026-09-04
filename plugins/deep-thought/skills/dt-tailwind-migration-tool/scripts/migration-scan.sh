#!/usr/bin/env bash
# Decide whether a component can be migrated from styled-components to Tailwind, and
# list what will bite.
#
# Usage: migration-scan.sh <component name or path>
#
# Read-only. Changes nothing.
set -uo pipefail

Q="${1:-}"
[ -n "$Q" ] || { echo "usage: migration-scan.sh <component name or path>" >&2; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not inside a git repository" >&2; exit 1; }
cd "$(git rev-parse --show-toplevel)" || exit 1
FILES=$(git ls-files)
allf() { printf '%s\n' "$FILES"; }

echo "=== TAILWIND MIGRATION SCAN: $Q ==="

# ---- locate the component ------------------------------------------------
if [ -e "$Q" ]; then
  DIR=$([ -d "$Q" ] && echo "$Q" || dirname "$Q")
  STEM=$(basename "${Q%.*}")
else
  HIT=$(allf | grep -iE "/${Q}\.(tsx|ts)$" | grep -vE '\.(spec|test|stories|styled|styles)\.' | head -1)
  [ -z "$HIT" ] && HIT=$(allf | grep -iE "/${Q}[^/]*\.(tsx|ts)$" | grep -vE '\.(spec|test|stories|styled|styles)\.' | head -1)
  if [ -z "$HIT" ]; then
    echo "No component matched '$Q'. Closest filenames:"
    allf | grep -iE "$Q" | grep -E '\.(tsx|ts)$' | head -8 | sed 's/^/  /'
    exit 1
  fi
  DIR=$(dirname "$HIT"); STEM=$(basename "${HIT%.*}")
fi
echo "directory: $DIR"
echo "component: $STEM"

STYLED=$(allf | grep -E "^${DIR}/([^/]*\.)?styled\.(ts|tsx)$|^${DIR}/${STEM}\.styled\.(ts|tsx)$")
STYLES=$(allf | grep -E "^${DIR}/${STEM}\.styles\.ts$")
TESTS=$(allf | grep -E "^${DIR}/__tests__/.*\.(spec|test)\.(ts|tsx)$")
STORIES=$(allf | grep -E "^${DIR}/__stories__/.*\.stories\.tsx$")

echo
echo "--- files ---"
allf | grep -E "^${DIR}/${STEM}\.(tsx|ts)$" | sed 's/^/  component  /'
[ -n "$STYLED" ]  && printf '%s\n' "$STYLED"  | sed 's/^/  styled     /' || echo "  styled     none found, nothing to migrate here"
[ -n "$STYLES" ]  && printf '%s\n' "$STYLES"  | sed 's/^/  styles     /  (already migrated?)'
[ -n "$TESTS" ]   && printf '%s\n' "$TESTS"   | sed 's/^/  test       /' || echo "  test       none, so nothing pins current behaviour"
[ -n "$STORIES" ] && printf '%s\n' "$STORIES" | sed 's/^/  story      /' || echo "  story      none, so no Storybook check across brands"

[ -z "$STYLED" ] && { echo; echo "RESULT: nothing to migrate."; exit 0; }

SRC=$(printf '%s\n' "$STYLED" | tr '\n' ' ')
COMP=$(allf | grep -E "^${DIR}/${STEM}\.(tsx|ts)$" | tr '\n' ' ')
BLOCK=0
hit() { grep -n "$1" $SRC $COMP 2>/dev/null | head -"${2:-3}"; }

echo
echo "--- blockers, these mean do not migrate today ---"
if hit 'applyFont(' >/dev/null 2>&1 && [ -n "$(hit 'applyFont(')" ]; then
  echo "  applyFont is not bridged. TAILWIND_MIGRATION.md says leave the component on styled-components."
  hit 'applyFont(' | sed 's/^/      /'; BLOCK=1
fi
if [ -n "$(hit 'mediaMixin\.\|BreakpointKey')" ]; then
  echo "  breakpoints. Variants silently never match on iOS 16.0 to 16.3, so they are unsafe until the"
  echo "  target reaches 16.4. Keep this on styled-components and use mixins/media.ts."
  hit 'mediaMixin\.\|BreakpointKey' | sed 's/^/      /'; BLOCK=1
fi
if [ -n "$(hit '\.attrs(')" ]; then
  echo "  .attrs(), move the attributes onto the JSX element by hand first."
  hit '\.attrs(' | sed 's/^/      /'; BLOCK=1
fi
if [ -n "$(hit 'keyframes')" ] && [ -n "$(grep -n 'keyframes' $SRC 2>/dev/null | grep '\${')" ]; then
  echo "  keyframes built from runtime props. Use a static @keyframes plus a style variable."
  BLOCK=1
fi
if [ -n "$(grep -nE 'styled\([A-Z]' $SRC 2>/dev/null)" ]; then
  echo "  styled(Component). Migratable only if that component forwards className. Check before starting."
  grep -nE 'styled\([A-Z]' $SRC 2>/dev/null | head -3 | sed 's/^/      /'
fi
case "$DIR" in
  *tiger-components*|*packages-mfe*|*microfrontends*)
    echo "  this lives outside the app's scope for this migration."; BLOCK=1;;
esac
[ "$BLOCK" = "0" ] && echo "  none"

echo
echo "--- hazards, migratable but these are where it goes wrong ---"
H=0
if [ -n "$(grep -nE 'text(Tiny|Small|Medium|Normal|Large|Base|Size)\(' $SRC 2>/dev/null)" ]; then
  echo "  text* mixin. The ported utilities drop colour, font-weight, font-stretch and letter-spacing."
  echo "  Add an explicit text-* colour and font-* weight or they silently inherit."
  grep -nE 'text(Tiny|Small|Medium|Normal|Large|Base|Size)\(' $SRC | head -4 | sed 's/^/      /'; H=1
fi
if [ -n "$(grep -nE '\$\{[A-Z][A-Za-z]*\}' $SRC 2>/dev/null)" ]; then
  echo "  \${StyledChild} interpolation. Resolve the cross-component override first: typed props, or a"
  echo "  literal kebab-case marker class the parent targets."
  grep -nE '\$\{[A-Z][A-Za-z]*\}' $SRC | head -4 | sed 's/^/      /'; H=1
fi
if [ -n "$(grep -nE '\$\{\(\{[^}]*\}\)' $SRC 2>/dev/null)" ]; then
  echo "  prop-driven css block. Becomes a cva variant, or data-* plus data-[x]: variants."
  grep -nE '\$\{\(\{[^}]*\}\)' $SRC | head -4 | sed 's/^/      /'; H=1
fi
if [ -n "$(grep -nE '#[0-9a-fA-F]{3,8}\b|[^-a-z]([0-9]+)px' $SRC 2>/dev/null)" ]; then
  echo "  raw hex or px. Pre-existing token debt: preserve as an arbitrary value, greppable. Do not invent a token."
  grep -nE '#[0-9a-fA-F]{3,8}\b|[^-a-z][0-9]+px' $SRC | head -4 | sed 's/^/      /'; H=1
fi
if [ -n "$(grep -n 'color-schema' $SRC 2>/dev/null)" ]; then
  echo "  palette var. Not bridged on purpose. Only bg-[var(--color-schema-…)] to stay identical."
  grep -n 'color-schema' $SRC | head -3 | sed 's/^/      /'; H=1
fi
[ "$H" = "0" ] && echo "  none"

echo
echo "--- declarations to account for ---"
# cat, not grep -c per file: grep -c prints a bare number for one file and file:count for many
DECLS=$(cat $SRC 2>/dev/null | grep -cE '^[[:space:]]*[a-z-]+[[:space:]]*:' || true)
BLOCKS=$(cat $SRC 2>/dev/null | grep -cE 'styled[.(]|css`' || true)
echo "  roughly ${DECLS:-0} CSS declaration(s) across the styled file(s)."
echo "  ${BLOCKS:-0} styled element(s) or css blocks to become cva blocks."
echo "  Every declaration is accounted for in the inventory: reproduced by a utility, or a deliberate drop."

echo
echo "--- the gate for this component ---"
PKG=$(printf '%s' "$DIR" | sed -nE 's#^(apps/[^/]+|packages/[^/]+|core-packages/[^/]+)/.*#\1#p')
PKG="${PKG:-apps/sportsbook-ui}"
echo "  (cd $PKG && pnpm type-check && pnpm lint)"
[ -n "$TESTS" ] && printf '%s\n' "$TESTS" | while read -r t; do echo "  (cd $PKG && pnpm test --run ${t#$PKG/})"; done
echo "  read apps/sportsbook-ui/TAILWIND_MIGRATION.md before writing any class"

echo
[ "$BLOCK" = "1" ] && echo "RESULT: BLOCKED, do not migrate this component today." || echo "RESULT: migratable."
echo "=== END ==="

#!/usr/bin/env bash
# Decide whether a component should have a Storybook story, and gather what writing one needs.
#
# Usage: story-scan.sh <component name or path>
#
# Read-only. Every line is a signal with its evidence, not a verdict. The guide decides.
set -uo pipefail

Q="${1:-}"
[ -n "$Q" ] || { echo "usage: story-scan.sh <component name or path>" >&2; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not inside a git repository" >&2; exit 1; }
cd "$(git rev-parse --show-toplevel)" || exit 1
FILES=$(git ls-files)
allf() { printf '%s\n' "$FILES"; }
GUIDE=$(allf | grep -E 'STORYBOOK_GUIDE\.md$' | head -1)
ROUTER=$(allf | grep -E 'src/app/router\.tsx$' | head -1)

echo "=== STORY SCAN: $Q ==="
[ -n "$GUIDE" ] && echo "guide:  $GUIDE  (read it, it decides)" || echo "guide:  none found in this repo"

# ---- locate --------------------------------------------------------------
if [ -f "$Q" ]; then FILE="$Q"
else
  FILE=$(allf | grep -iE "/${Q}\.(tsx|ts)$" | grep -vE '\.(spec|test|stories|styled|styles)\.' | head -1)
  [ -z "$FILE" ] && FILE=$(allf | grep -iE "/${Q}[^/]*\.(tsx|ts)$" | grep -vE '\.(spec|test|stories|styled|styles)\.' | head -1)
fi
if [ -z "$FILE" ]; then
  echo "No component matched '$Q'. Closest:"; allf | grep -iE "$Q" | grep -E '\.tsx?$' | head -8 | sed 's/^/  /'; exit 1
fi
DIR=$(dirname "$FILE"); STEM=$(basename "${FILE%.*}")
echo "file:   $FILE"

EXISTING=$(allf | grep -E "/${STEM}\.stories\.tsx?$")
if [ -n "$EXISTING" ]; then
  echo
  echo "A story already exists:"; printf '%s\n' "$EXISTING" | sed 's/^/  /'
  echo "  Add a missing state to it rather than starting a new file."
fi

sig() { printf '  %-6s %s\n' "$1" "$2"; }
NO=0; YES=0

echo
echo "--- Step 1, no story if any of these hit. Step 1 beats Step 2 ---"

case "$STEM" in
  use[A-Z]*) sig HIT "a hook, not a component. Use renderHook, see the testing guide"; NO=1 ;;
esac
grep -qE '<[A-Za-z]' "$FILE" 2>/dev/null || { sig HIT "no JSX in this file, so nothing to look at"; NO=1; }

case "$STEM" in
  *Layout|*TabContent|*Page) sig HIT "name matches *Layout, *TabContent or *Page, so the router treats it as a screen"; NO=1 ;;
esac
if [ -n "$ROUTER" ] && grep -qE "component=\{?[\"']?$STEM" "$ROUTER" 2>/dev/null; then
  sig HIT "named in $ROUTER, so it is a screen. Story the widgets it arranges"; NO=1
fi

if grep -qE 'useAppBarContent|DesktopPageHeader' "$FILE" 2>/dev/null; then
  sig HIT "owns the page chrome (useAppBarContent or DesktopPageHeader), which is screen-level character"
  grep -nE 'useAppBarContent|DesktopPageHeader' "$FILE" | head -2 | sed 's/^/         /'; NO=1
fi

case "$STEM" in
  Skeleton*|Empty*|*Error)
    BASE=$(printf '%s' "$STEM" | sed -E 's/^(Skeleton|Empty)//; s/Error$//')
    if [ -n "$BASE" ] && [ -n "$(allf | grep -E "/${BASE}\.tsx$")" ]; then
      sig HIT "a state of $BASE, so it belongs in ${BASE}.stories.tsx, not its own file"; NO=1
    fi ;;
esac

# Store hooks carry arbitrary names (useSetBetslipVisible, useIsBetslipTabActive), so a
# use*Store() regex sees nothing. The import source is what is detectable.
ZUSTANDISH=$(grep -oE 'from "[^"]*"' "$FILE" 2>/dev/null \
  | grep -E '(^|/)store(/|")|[a-zA-Z]+Store(/|")' | sort -u | grep -c . || true)
SLICES=$(grep -oE '@store/[a-z][a-zA-Z]*' "$FILE" 2>/dev/null \
  | grep -vE '/types|Store$' | sort -u | grep -c . || true)
BUS=$(grep -cE '@gutro/bus|useSubscribe\(' "$FILE" 2>/dev/null || true)
# Two or more store modules is a reliable hit: initialState seeds Redux only, so those
# cannot be seeded at all. The Redux slice count is NOT reliable, because importing a
# selector from @store/foo is not the same as needing foo preloaded. Counting imports
# called OutcomeButton and EventPreview unstoriable, and the guide says both are storied.
# So slices are reported with evidence and left for a person to judge.
if [ "${ZUSTANDISH:-0}" -ge 2 ]; then
  sig HIT "reads $ZUSTANDISH store modules, which parameters.initialState cannot seed at all"
  grep -oE 'from "[^"]*"' "$FILE" | grep -E '(^|/)store(/|")|[a-zA-Z]+Store(/|")' | sort -u | sed 's/^/         /'
  [ "${BUS:-0}" -gt 0 ] && echo "         plus a bus subscription"
  NO=1
elif [ "${ZUSTANDISH:-0}" = "1" ]; then
  sig note "one store module, not seedable through initialState. Drive it by props or reconsider"
  grep -oE 'from "[^"]*"' "$FILE" | grep -E '(^|/)store(/|")|[a-zA-Z]+Store(/|")' | sort -u | sed 's/^/         /'
fi
if [ "${SLICES:-0}" -ge 1 ]; then
  sig note "imports from $SLICES Redux slice path(s). NOT a verdict: an imported selector is not a"
  sig ""     "slice that initialState must preload. Read the component and judge how many it truly needs."
  grep -oE '@store/[a-z][a-zA-Z]*' "$FILE" | grep -vE '/types|Store$' | sort -u | sed 's/^/         /'
fi
[ "${BUS:-0}" -gt 0 ] && [ "${ZUSTANDISH:-0}" -lt 2 ] && sig note "subscribes to the bus, which no story parameter can drive"

PROPS=$(grep -cE '^\s+(readonly )?[a-zA-Z]+\??:' "$FILE" 2>/dev/null || true)
if grep -qE 'children[?]?:\s*(React\.)?ReactNode' "$FILE" 2>/dev/null && [ "${PROPS:-0}" -le 2 ]; then
  sig HIT "its only real prop is children, so there is one visual form and nothing to compare"; NO=1
fi

[ "$NO" = "0" ] && echo "  (none hit)"

echo
echo "--- Step 2, story required if any of these hit ---"
# styles live in a sibling, one level up, or inline in the component itself
STYLED=$( { allf | grep -E "^${DIR}/([^/]*\.)?(styled|styles)\.(ts|tsx)$"
            allf | grep -E "^$(dirname "$DIR")/([^/]*\.)?(styled|styles)\.(ts|tsx)$" | head -1
            echo "$FILE"; } | sort -u | tr '\n' ' ')
UNION=$(grep -cE '^\s+(readonly )?[a-zA-Z]+\??:\s*(boolean|[A-Za-z]+\s*\|)' "$FILE" 2>/dev/null || true)
if [ "${UNION:-0}" -ge 2 ]; then
  sig HIT "$UNION boolean or union props, so two or more visual branches"
  grep -nE '^\s+(readonly )?[a-zA-Z]+\??:\s*(boolean|[A-Za-z]+\s*\|)' "$FILE" | head -4 | sed 's/^/         /'; YES=1
fi
if [ -n "$STYLED" ] && grep -qE '\-\-colors-|theme\.' $STYLED 2>/dev/null; then
  sig HIT "styles read brand tokens, so it is a theme-variant surface"; YES=1
fi
if [ -n "$STYLED" ] && grep -qE 'nowrap|ellipsis|[0-9]+px' $STYLED 2>/dev/null; then
  sig HIT "fixed sizes, nowrap or ellipsis in the styles, so it is overflow-prone"
  grep -nE 'nowrap|ellipsis' $STYLED 2>/dev/null | head -2 | sed 's/^/         /'; YES=1
fi
SIB=$(allf | grep -E "^${DIR}/(Skeleton${STEM}|Empty${STEM}|${STEM}Error)\.tsx$")
if [ -n "$SIB" ]; then
  sig HIT "has a skeleton, empty or error sibling, which becomes an exported story here"
  printf '%s\n' "$SIB" | sed 's/^/         /'; YES=1
fi
[ "$YES" = "0" ] && echo "  (none hit)"

echo
echo "--- what the story will need from the environment ---"
grep -qE 'useQuery|useSuspenseQuery|useInfiniteQuery' "$FILE" 2>/dev/null && \
  echo "  React Query. No MSW, so seed the cache rather than mocking the network"
grep -qE 'useSelector|useAppSelector' "$FILE" 2>/dev/null && \
  echo "  Redux. One slice via parameters.initialState is fine, several unrelated ones is a Step 1 hit"
grep -qE 'useFeatureFlag|useFlag|growthbook' "$FILE" 2>/dev/null && \
  echo "  feature flags. Needs parameters.featureFlags"
grep -qE 'useTranslation|res\.|t\(' "$FILE" 2>/dev/null && \
  echo "  translations. No per-story locale switch exists, so cover label length with long strings"
grep -qE 'brand|BrandName|useConfig' "$FILE" 2>/dev/null && \
  echo "  brand config. Needs a config decorator, and only when brand changes the rendering"

echo
echo "--- the props to drive it with ---"
grep -nE '^(export )?(type|interface) [A-Z][A-Za-z]*Props' -A 14 "$FILE" 2>/dev/null | head -18 | sed 's/^/  /' \
  || echo "  no local Props type found, check the component signature"

echo
echo "--- exemplars to copy the shape from ---"
allf | grep -E 'announcement-banner/__stories__/AnnouncementBanner\.stories\.tsx$' | sed 's/^/  structure:  /'
allf | grep -E 'PrebuildBetCard\.stories\.tsx$' | sed 's/^/  skeleton:   /'
echo "  nearest:    $(allf | grep -E "^${DIR%/*}/.*\.stories\.tsx$" | head -1)"

echo
echo "--- where the file goes, and the gate ---"
echo "  $DIR/__stories__/$STEM.stories.tsx"
PKG=$(printf '%s' "$DIR" | sed -nE 's#^(apps/[^/]+|packages/[^/]+|core-packages/[^/]+)/.*#\1#p'); PKG="${PKG:-apps/sportsbook-ui}"
echo "  (cd $PKG && pnpm type-check && pnpm lint && pnpm test --run src/test/stories.spec.tsx)"

echo
if [ "$NO" = "1" ]; then echo "RESULT: Step 1 hit, so no story. Say which rule and stop."
elif [ "$YES" = "1" ]; then echo "RESULT: Step 2 hit, so a story is warranted."
else echo "RESULT: neither table hit. No story, and do not add one for completeness."; fi
echo "=== END ==="

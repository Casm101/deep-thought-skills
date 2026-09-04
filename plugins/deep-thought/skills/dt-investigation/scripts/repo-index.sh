#!/usr/bin/env bash
# Read-only inventory of the current repository, plus an optional topic scan.
#
# Usage: repo-index.sh [topic words ...]
#   no argument -> whole-repo inventory
#   with words  -> inventory plus where those words live
#
# READ ONLY. This script writes nothing: no temp files, no redirects, stdout only.
set -uo pipefail

TOPIC="${*:-}"
MD_TITLE_LIMIT="${DTI_MD_TITLE_LIMIT:-250}"   # extract titles for at most this many docs

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT" || exit 1

PRUNE_NAMES='node_modules .git dist build out coverage .next .turbo .nuxt target vendor
.venv venv __pycache__ .cache .idea .pnpm-store .gradle Pods .terraform'
FIND_PRUNE=()
for n in $PRUNE_NAMES; do FIND_PRUNE+=(-name "$n" -o); done
unset 'FIND_PRUNE[${#FIND_PRUNE[@]}-1]'
ffind() { find . \( "${FIND_PRUNE[@]}" \) -prune -o "$@" -print; }

# One file list, reused everywhere below. Held in memory: this script writes no files.
# In a git repo, ask git: tracked files only, so ignored output, dependency trees and any
# nested worktrees stay out of the index for free. Otherwise fall back to a pruned walk.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  ALL_FILES=$(git ls-files -z 2>/dev/null | tr '\0' '\n' | sed 's|^|./|')
  FILE_SOURCE="git-tracked files"
else
  ALL_FILES=$(ffind -type f 2>/dev/null)
  FILE_SOURCE="filesystem walk (vendored directories pruned)"
fi
allf() { printf '%s\n' "$ALL_FILES"; }
# Line counts in bulk (xargs wc) rather than one wc per file.
count_lines() { tr '\n' '\0' | xargs -0 wc -l 2>/dev/null | grep -v ' total$'; }

RG_EXCLUDES=(-g '!node_modules' -g '!.git' -g '!dist' -g '!build' -g '!out' -g '!coverage'
             -g '!.next' -g '!.turbo' -g '!target' -g '!vendor' -g '!*.lock'
             -g '!pnpm-lock.yaml' -g '!package-lock.json' -g '!*.min.*' -g '!*.map')
have_rg() { command -v rg >/dev/null 2>&1; }

hr() { printf '\n== %s ==\n' "$1"; }

# ---------------------------------------------------------------- repo identity
echo "=== REPO INVENTORY (read-only) ==="
echo "root:     $ROOT"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "branch:   $(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  echo "remote:   $(git remote get-url origin 2>/dev/null || echo 'none')"
  echo "commits:  $(git rev-list --count HEAD 2>/dev/null) on this branch"
  echo "age:      first commit $(git log --reverse --format=%as 2>/dev/null | head -1), latest $(git log -1 --format=%as 2>/dev/null)"
  echo "tracked:  $(git ls-files | wc -l | tr -d ' ') files"
else
  echo "vcs:      not a git repository"
fi
echo "indexing: $FILE_SOURCE"
case "$FILE_SOURCE" in
  git-tracked*) echo "          (untracked and gitignored paths are not in this index; check with rg if the subject may live there)";;
esac

# ------------------------------------------------------------- directory shape
hr "DIRECTORY SHAPE (top level, file counts exclude vendored dirs)"
allf | sed -n 's|^\./\([^/]*\)/.*|\1|p' | sort | uniq -c | sort -rn | head -30
echo "(root files: $(find . -maxdepth 1 -type f | wc -l | tr -d ' '))"

hr "WORKSPACE MEMBERS (second level of the big directories)"
allf | sed -n -E 's#^\./(apps|packages|core-packages|services|libs|modules|plugins|src/packages)/([^/]+)/.*#\1/\2#p' \
  | sort | uniq -c | sort -rn | head -40

# ------------------------------------------------------------------- manifests
hr "MANIFESTS AND WORKSPACE CONFIG"
allf | grep -E '/(package\.json|pyproject\.toml|go\.mod|Cargo\.toml|pom\.xml|build\.gradle[^/]*|Gemfile|[^/]+\.csproj|composer\.json|pnpm-workspace\.yaml|turbo\.json|nx\.json|lerna\.json)$' \
  | awk -F/ 'NF<=5' | sed 's|^\./||' | sort | head -60

if [ -f package.json ] && command -v jq >/dev/null 2>&1; then
  hr "ROOT package.json (name, engines, workspaces, scripts, deps count)"
  jq -r '{name, version, packageManager, engines,
          workspaces: (.workspaces // empty),
          scripts: (.scripts // {} | keys),
          deps: ((.dependencies // {}) | length),
          devDeps: ((.devDependencies // {}) | length)}' package.json 2>/dev/null
  hr "TOP-LEVEL RUNTIME DEPENDENCIES (root manifest)"
  jq -r '(.dependencies // {}) | to_entries[] | "\(.key) \(.value)"' package.json 2>/dev/null | head -50
fi

# --------------------------------------------------------------- documentation
hr "DOCUMENTATION INDEX (every doc file, largest first)"
MD_LIST=$(allf | grep -E '\.(md|mdx|rst|adoc|txt)$' | grep -v -E '/(LICENSE|CHANGELOG)' )
MD_COUNT=$(printf '%s\n' "$MD_LIST" | grep -c . || true)
echo "$MD_COUNT documentation files found."
echo "This is the full index. Read in this order: the ones at the top carry the most content."
echo
i=0
while IFS= read -r line; do
  [ -n "$line" ] || continue
  lines=$(printf '%s' "$line" | awk '{print $1}')
  f=$(printf '%s' "$line" | sed 's/^ *[0-9]* //')
  i=$((i + 1))
  title=""
  if [ "$i" -le "$MD_TITLE_LIMIT" ]; then
    title=$(grep -m1 -E '^#[^#]|^=+$' "$f" 2>/dev/null | sed 's/^#* *//' | cut -c1-70)
  fi
  printf '%6s  %-60s %s\n' "$lines" "${f#./}" "$title"
done < <(printf '%s\n' "$MD_LIST" | count_lines | sort -rn)
[ "${MD_COUNT:-0}" -gt "$MD_TITLE_LIMIT" ] && echo "(titles shown for the first $MD_TITLE_LIMIT; every path is still listed)"

# ------------------------------------------------------------ tooling and gates
hr "TOOLING AND CONFIG AT ROOT"
find . -maxdepth 1 \( -type f -o -type l \) \
  \( -name '.*rc*' -o -name '*.config.*' -o -name '*.json' -o -name '*.yaml' -o -name '*.yml' \
     -o -name '*.toml' -o -name '.editorconfig' -o -name '.nvmrc' -o -name 'Makefile' \
     -o -name 'Dockerfile*' -o -name '*.mk' \) 2>/dev/null | sed 's|^\./||' | sort

hr "CI AND AUTOMATION"
allf | grep -E '^\./(\.github/workflows/|\.circleci/|\.husky/)|/(\.drone\.yml|\.gitlab-ci\.yml|Jenkinsfile)$' \
  | sed 's|^\./||' | sort | head -40

hr "AGENT AND CONVENTION FILES (the rules that bind)"
allf | grep -E '/(CLAUDE\.md|AGENTS\.md|CONVENTIONS\.md|CONTRIBUTING\.md|ARCHITECTURE\.md|README\.md|CODEOWNERS|[^/]*\.cursorrules)$|/(adr|decisions|rfcs)/' \
  | sed 's|^\./||' | sort | head -60

# ------------------------------------------------------------------ code shape
hr "LANGUAGE MIX (file counts by extension)"
allf | sed -n 's/.*\.\([A-Za-z0-9_]*\)$/\1/p' | sort | uniq -c | sort -rn | head -25

SRC=$(allf | grep -E '\.(ts|tsx|js|jsx|mjs|cjs|py|go|rs|java|kt|rb|cs|php|swift|c|cc|cpp|h|hpp|vue|svelte|scala|ex|exs)$' \
      | grep -v -E '\.(spec|test|stories|d)\.|/generated/|\.gen\.')
hr "LARGEST SOURCE FILES (size hints at where the logic sits)"
printf '%s\n' "$SRC" | count_lines | sort -rn | head -30 | sed 's|\./||'

hr "LIKELY ENTRY POINTS"
allf | grep -E '/(index|main|app|App|server|bootstrap|Program|__main__)\.(ts|tsx|js|jsx|py|go|rs|cs)$' \
  | awk -F/ 'NF<=6' | sed 's|^\./||' | sort | head -40

hr "TEST LAYOUT (directories holding the most tests)"
TESTS=$(allf | grep -E '(\.spec\.|\.test\.|/test_[^/]*\.py$|_test\.go$|Tests?\.(cs|java|kt)$)')
printf '%s\n' "$TESTS" | sed 's|/[^/]*$||; s|^\./||' | sort | uniq -c | sort -rn | head -25
echo "total test files: $(printf '%s\n' "$TESTS" | grep -c . || true)"

# ----------------------------------------------------------------- topic scan
if [ -n "$TOPIC" ]; then
  hr "TOPIC SCAN: $TOPIC"
  if have_rg; then
    echo "-- directories with the most matches --"
    rg -il --hidden "${RG_EXCLUDES[@]}" -e "$TOPIC" . 2>/dev/null \
      | sed 's|/[^/]*$||; s|^\./||' | sort | uniq -c | sort -rn | head -20
    echo
    echo "-- files with the most matches --"
    rg -ic --hidden "${RG_EXCLUDES[@]}" -e "$TOPIC" . 2>/dev/null \
      | sort -t: -k2 -rn | head -30 | sed 's|^\./||'
    echo
    echo "-- documentation mentioning it --"
    rg -il --hidden "${RG_EXCLUDES[@]}" -g '*.md' -g '*.mdx' -e "$TOPIC" . 2>/dev/null | sed 's|^\./||' | head -25
    echo
    echo "-- definitions and exports that name it --"
    rg -in --hidden "${RG_EXCLUDES[@]}" -e "(class|interface|type|enum|struct|func|def|const|function|export (default )?(class|function|const))[^=;{(]*${TOPIC// /.*}" . 2>/dev/null \
      | head -30 | cut -c1-180 | sed 's|^\./||'
    echo
    echo "-- filenames that name it --"
    ffind -type f 2>/dev/null | grep -i -- "${TOPIC// /.*}" | sed 's|^\./||' | head -30
  else
    echo "(ripgrep not installed; falling back to grep)"
    grep -ril --exclude-dir={node_modules,.git,dist,build,coverage,target,vendor} -e "$TOPIC" . 2>/dev/null | head -40
  fi
  echo
  echo "Treat this scan as a starting set, not the boundary. Follow imports and callers out from here."
fi

echo
echo "=== END INVENTORY ==="

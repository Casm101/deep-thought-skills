#!/usr/bin/env bash
# Preflight and proof for a Claude Code mod built by dt-mod-creator.
#
# Usage:
#   mod-check.sh env <name> <repo>     where things stand before building
#   mod-check.sh check <mod-folder>    validate, typecheck and test the mod
#
# Read-only on the repository. `check` writes one scratch tsconfig under
# ${TMPDIR:-/tmp} and prints its path.
set -uo pipefail

MIN_VERSION="2.1.287"
FAIL=0; WARN=0
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; }
warn() { WARN=$((WARN+1)); printf '  warn  %s\n' "$1"; }
ok()   { printf '  ok    %s\n' "$1"; }

# The build the session runs is the one that loads the mod, so check against it.
BIN="${CLAUDE_CODE_EXECPATH:-}"
[ -n "$BIN" ] && [ -x "$BIN" ] || BIN="$(command -v claude || true)"
[ -n "$BIN" ] || { echo "No Claude Code binary found: CLAUDE_CODE_EXECPATH is unset and claude is not on PATH." >&2; exit 2; }

version_of() { "$1" --version 2>/dev/null | awk '{print $1}'; }
older_than() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" = "$1" ] && [ "$1" != "$2" ]; }

run_env() {
  local name="${1:-}" repo="${2:-}"
  [ -n "$name" ] && [ -n "$repo" ] || { echo "usage: mod-check.sh env <name> <repo>" >&2; exit 2; }
  [ -d "$repo/.git" ] || [ -f "$repo/.git" ] || { echo "Not a git checkout: $repo" >&2; exit 2; }

  printf '\n=== Claude Code ===\n'
  local session brew brew_bin
  session="$(version_of "$BIN")"
  ok "checks run on $session ($BIN)"
  brew_bin="$(command -v claude || true)"
  if [ -n "$brew_bin" ]; then
    brew="$(version_of "$brew_bin")"
    if older_than "$brew" "$MIN_VERSION"; then
      warn "terminal claude is $brew ($brew_bin), older than $MIN_VERSION, so terminal sessions may not run mods. Upgrading is the person's call."
    else
      ok "terminal claude is $brew"
    fi
  else
    warn "no claude on PATH, so the mod runs in the desktop app only until one is installed"
  fi

  printf '\n=== Branch ===\n'
  local branch remote_main local_main ahead behind
  branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD)"
  ok "HEAD is $branch"
  remote_main="$(git -C "$repo" ls-remote origin refs/heads/main 2>/dev/null | awk '{print $1}')"
  local_main="$(git -C "$repo" rev-parse --verify -q origin/main || true)"
  if [ -z "$remote_main" ]; then
    warn "could not read main from origin, so the fast-forward check waits for Phase 7"
  elif [ "$remote_main" != "$local_main" ]; then
    warn "origin/main has moved since the last fetch; Phase 7 fetches before it commits"
  fi
  if [ -n "$local_main" ]; then
    ahead="$(git -C "$repo" rev-list --count origin/main..HEAD)"
    behind="$(git -C "$repo" rev-list --count HEAD..origin/main)"
    if [ "$ahead" -gt 0 ]; then
      warn "HEAD carries $ahead commit(s) not on origin/main; Phase 7 will stop rather than push them"
    else
      ok "HEAD carries nothing that is not on origin/main"
    fi
    [ "$behind" -gt 0 ] && warn "HEAD is $behind commit(s) behind origin/main; bring it level before Phase 7"
  fi
  local dirty
  dirty="$(git -C "$repo" status --porcelain | grep -c . || true)"
  [ "${dirty:-0}" -gt 0 ] && warn "$dirty uncommitted path(s) already in the tree; only the mod's files get committed"

  printf '\n=== Push ===\n'
  if ssh-add -l >/dev/null 2>&1; then ok "an SSH key is loaded"
  else warn "no SSH key in the agent; the person runs ssh-add before Phase 7 pushes"; fi

  printf '\n=== Name ===\n'
  if [ -e "$repo/mods/$name" ]; then bad "mods/$name already exists"
  else ok "mods/$name is free"; fi
  if grep -q "\"name\": *\"$name\"" "$repo/.claude-plugin/marketplace.json" 2>/dev/null; then
    bad "the marketplace already lists \"$name\""
  else
    ok "the marketplace does not list \"$name\""
  fi
  # The engine lays both beside a mod it loads, and neither belongs in the repo.
  local generated
  for generated in 'mods/*/.claude-plugin/types/' 'mods/*/tsconfig.json'; do
    if grep -qF "$generated" "$repo/.gitignore" 2>/dev/null; then
      ok ".gitignore already ignores $generated"
    else
      warn ".gitignore lacks $generated; add it with the mod"
    fi
  done
  if [ -n "${CLAUDE_CODE_SESSION_ID:-}" ]; then
    ok "the person links into ~/.claude/dev-mods/$CLAUDE_CODE_SESSION_ID/"
  else
    warn "CLAUDE_CODE_SESSION_ID is unset; take the dev-mods folder from plugin-authoring"
  fi
}

# The engine writes this build's API declarations into the bundled plugin-authoring
# skill when that skill loads, and beside a mod once it has loaded the mod.
find_types() {
  local mod="$1" version uid hit
  if [ -f "$mod/.claude-plugin/types/claude-code/index.d.ts" ]; then
    echo "$mod/.claude-plugin/types/claude-code/index.d.ts"; return
  fi
  version="$(version_of "$BIN")"; uid="$(id -u)"
  hit="$(ls -t /private/tmp/claude-"$uid"/bundled-skills/"$version"/*/plugin-authoring/types/claude-code.d.ts \
          /tmp/claude-"$uid"/bundled-skills/"$version"/*/plugin-authoring/types/claude-code.d.ts 2>/dev/null | head -1)"
  echo "$hit"
}

run_check() {
  local mod="${1:-}"
  [ -n "$mod" ] || { echo "usage: mod-check.sh check <mod-folder>" >&2; exit 2; }
  mod="$(cd "$mod" 2>/dev/null && pwd)" || { echo "No such folder: $1" >&2; exit 2; }
  [ -f "$mod/.claude-plugin/plugin.json" ] || { echo "No .claude-plugin/plugin.json in $mod" >&2; exit 2; }

  printf '\n=== validate (%s) ===\n' "$(version_of "$BIN")"
  if "$BIN" plugin validate "$mod"; then ok "validate passed"; else bad "validate failed"; fi

  printf '\n=== typecheck ===\n'
  local types tsc scratch dirs d
  types="${MOD_TYPES:-$(find_types "$mod")}"
  if [ -z "$types" ] || [ ! -f "$types" ]; then
    warn "no claude-code.d.ts for this build; load plugin-authoring first, or set MOD_TYPES to its path"
  else
    scratch="$(mktemp -d "${TMPDIR:-/tmp}/mod-tsc.XXXXXX")"
    dirs=""
    for d in hooks types tests; do [ -d "$mod/$d" ] && dirs="$dirs\"$mod/$d\","; done
    cat > "$scratch/tsconfig.json" <<EOF
{
  "compilerOptions": {
    "target": "es2023", "lib": ["es2023"], "types": [],
    "module": "esnext", "moduleResolution": "bundler",
    "strict": true, "noUncheckedIndexedAccess": true,
    "noEmit": true, "skipLibCheck": true,
    "jsx": "react", "jsxFactory": "h", "jsxFragmentFactory": "Fragment"
  },
  "files": ["$types"],
  "include": [${dirs%,}]
}
EOF
    echo "  scratch tsconfig: $scratch/tsconfig.json"
    if command -v tsc >/dev/null 2>&1; then tsc="tsc"; else tsc="npx -y -p typescript@5.6.3 tsc"; fi
    if $tsc -p "$scratch/tsconfig.json"; then ok "typecheck passed against $types"
    else bad "typecheck failed"; fi
  fi

  printf '\n=== plugin test ===\n'
  if ! find "$mod" -name '*.test.ts' -o -name '*.test.tsx' | grep -q .; then
    bad "no *.test.ts in the mod; write at least one for the behaviour asked for"
  elif "$BIN" plugin test "$mod"; then ok "tests passed"
  else bad "tests failed"; fi
}

case "${1:-}" in
  env)   shift; run_env "$@" ;;
  check) shift; run_check "$@" ;;
  *)     echo "usage: mod-check.sh env <name> <repo> | check <mod-folder>" >&2; exit 2 ;;
esac

printf '\n=== %s failure(s), %s warning(s) ===\n' "$FAIL" "$WARN"
[ "$FAIL" -eq 0 ] || exit 1

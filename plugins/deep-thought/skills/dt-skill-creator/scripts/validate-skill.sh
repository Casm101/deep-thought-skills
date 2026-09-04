#!/usr/bin/env bash
# Check a dt skill against every invariant the family holds to.
#
# Usage: validate-skill.sh <skill-name> | --all
#
# Read-only. Changes nothing.
set -uo pipefail

# The skills live in one tree: this repository. Resolve it from the script's own
# location so the validator works from the plugin cache, a clone, or a worktree,
# and needs no environment variable set for it.
SKILLS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_ROOT="$(cd "$SKILLS_ROOT/.." && pwd)"
ROUTER="$SKILLS_ROOT/dt-ask-deepthought/SKILL.md"
FAIL=0; WARN=0
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; }
warn() { WARN=$((WARN+1)); printf '  warn  %s\n' "$1"; }
ok()   { printf '  ok    %s\n' "$1"; }

check_one() {
  local name="$1" dir="$SKILLS_ROOT/$1"
  printf '\n=== %s ===\n' "$name"

  [ -d "$dir" ] || { bad "no such skill in this repository: $dir"; return; }
  [ -f "$dir/SKILL.md" ] || { bad "no SKILL.md"; return; }

  # ---- frontmatter -------------------------------------------------------
  local first name_line desc
  first=$(head -1 "$dir/SKILL.md")
  [ "$first" = "---" ] || bad "SKILL.md does not open with ---"
  name_line=$(sed -n '2,6p' "$dir/SKILL.md" | grep -m1 '^name: ' | sed 's/^name: //')
  if [ -z "$name_line" ]; then bad "no name: in the frontmatter"
  elif [ "$name_line" != "$name" ]; then bad "name is '$name_line' but the directory is '$name'"
  else ok "frontmatter name matches the directory"; fi
  desc=$(sed -n '/^description: /p' "$dir/SKILL.md" | head -1 | sed 's/^description: //')
  if [ -z "$desc" ]; then bad "no description:"
  else
    local dlen=${#desc}
    [ "$dlen" -lt 40 ] && warn "description is only $dlen chars, probably too thin to trigger well"
    [ "$dlen" -gt 1100 ] && warn "description is $dlen chars, long enough to be worth trimming"
    ok "description present ($dlen chars)"
  fi
  sed -n '2,12p' "$dir/SKILL.md" | grep -q '^---$' || bad "frontmatter is not closed with --- in the first 12 lines"

  # ---- the plugin path contract ------------------------------------------
  # A skill inside a plugin cannot reach itself through ~/.claude/skills: that directory
  # holds personal skills, not this plugin's. Every self or sibling path goes through
  # ${CLAUDE_PLUGIN_ROOT}, which Claude Code substitutes when it reads the markdown.
  # This is the single mistake that survives a move into the plugin and fails silently.
  # Match a path that names something under that directory, so the two skills whose rule text
  # quotes the bare directory do not fail themselves. dt-memory is exempt: it genuinely installs
  # there, from the deep-thought-store repository, and is not part of this plugin.
  local stale
  stale=$(find "$dir" -type f \( -name '*.md' -o -name '*.sh' \) -print0 \
          | xargs -0 grep -nE '\.claude/skills/[A-Za-z$]' 2>/dev/null \
          | grep -v 'dt-memory' | grep -c . || true)
  [ "${stale:-0}" -gt 0 ] && bad "$stale line(s) still point at ~/.claude/skills, which does not hold this plugin" \
    || ok "no stale ~/.claude/skills paths"

  # ---- self-referencing paths -------------------------------------------
  # Every skills/dt-<x> reference must point at a skill that exists in this repository.
  # A hardcoded name list went stale the moment the roster changed, so read the tree.
  local ref refname
  for ref in $(find "$dir" -name '*.md' -print0 | xargs -0 grep -ohE 'skills/dt-[a-z-]+' 2>/dev/null | sort -u); do
    refname="${ref#skills/}"
    if [ -d "$SKILLS_ROOT/$refname" ]; then
      [ "$refname" = "$name" ] || ok "references $refname, which exists"
    else
      bad "references a skill that is not in this repository: $refname"
    fi
  done
  # Every skills/<x>/scripts/<y> path in SKILL.md must resolve to a real executable.
  # A path into a sibling is allowed on purpose: this suite reuses one validator.
  # No pipe into a loop here, or the failures land in a subshell and never count.
  local paths pth target
  paths=$(grep -ohE 'skills/dt-[a-z-]+/scripts/[A-Za-z0-9_.-]+\.sh' "$dir/SKILL.md" 2>/dev/null | sort -u)
  for pth in $paths; do
    target="$SKILLS_ROOT/${pth#*skills/}"
    if [ ! -f "$target" ]; then bad "SKILL.md names a script that does not exist: $pth"
    elif [ ! -x "$target" ]; then bad "SKILL.md names a script that is not executable: $pth"
    else
      case "$pth" in
        skills/$name/scripts/*) ok "script path $pth resolves" ;;
        *) ok "script path $pth resolves (a deliberate sibling reference)" ;;
      esac
    fi
  done

  # ---- referenced files exist -------------------------------------------
  for ref in $(grep -ohE 'references/[a-z0-9-]+\.md' "$dir/SKILL.md" | sort -u); do
    [ -f "$dir/$ref" ] && ok "$ref exists" || bad "$ref is referenced but missing"
  done

  # ---- scripts ----------------------------------------------------------
  if [ -d "$dir/scripts" ]; then
    local sh
    for sh in "$dir"/scripts/*.sh; do
      [ -f "$sh" ] || continue
      [ -x "$sh" ] && ok "$(basename "$sh") is executable" || bad "$(basename "$sh") is not executable"
      bash -n "$sh" 2>/dev/null && ok "$(basename "$sh") parses" || bad "$(basename "$sh") has a syntax error"
    done
  fi

  # ---- house style ------------------------------------------------------
  # grep here may be ugrep, where --include globs as a filename. Feed the file list explicitly.
  local dashes curly glued
  mds() { find "$dir" -name '*.md' -print0; }
  dashes=$(mds | xargs -0 grep -n -- '—\|–' 2>/dev/null \
           | grep -viE 'no em dashes|no `—`|must print nothing|grep -nE|produced unattended|em dash' | grep -c . || true)
  [ "${dashes:-0}" -gt 0 ] && warn "$dashes line(s) with an em or en dash outside rule text" || ok "no stray em dashes"
  curly=$(mds | xargs -0 grep -l -- '’\|“\|”' 2>/dev/null | grep -c . || true)
  [ "${curly:-0}" -gt 0 ] && warn "$curly file(s) with curly quotes" || ok "no curly quotes"
  glued=$(mds | xargs -0 grep -nE '[a-z]\.[0-9]+\. ' 2>/dev/null | grep -c . || true)
  [ "${glued:-0}" -gt 0 ] && warn "$glued line(s) look like a list glued onto a sentence, check for a duplicated block" || true

  # ---- the command wrapper ----------------------------------------------
  # Every skill gets a /<name> wrapper, so it can be invoked by hand as well as by description.
  if [ -f "$PLUGIN_ROOT/commands/$name.md" ]; then
    ok "the command wrapper exists"
  else
    bad "no command wrapper at commands/$name.md"
  fi

  # ---- router ------------------------------------------------------------
  if [ "$name" = "dt-ask-deepthought" ]; then
    ok "this is the router"
  elif [ -f "$ROUTER" ]; then
    grep -q "\`$name\`" "$ROUTER" && ok "the router names it" || bad "the router does not mention it"
  fi
}

if [ "${1:-}" = "--all" ]; then
  for d in "$SKILLS_ROOT"/dt-*; do check_one "$(basename "$d")"; done
else
  [ -n "${1:-}" ] || { echo "usage: validate-skill.sh <skill-name> | --all" >&2; exit 1; }
  check_one "${1%/}"
fi

printf '\n=== %s failure(s), %s warning(s) ===\n' "$FAIL" "$WARN"
[ "$FAIL" -eq 0 ] || exit 1

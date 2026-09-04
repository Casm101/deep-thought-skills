#!/usr/bin/env bash
# Gather everything that counts as your own work inside a time window.
#
# Usage: gather-work.sh [days] [repo name or path]
#
#   days   how far back to look, rolling from now. Default 1.
#   repo   narrow to one repository, by directory name or by path. Default all.
#
# Reads git across every repository under the search root and GitHub through gh.
# Read-only. Commits nothing, fetches nothing, switches nothing, writes nothing.
set -uo pipefail

DAYS="${1:-1}"
ONLY="${2:-}"
SEARCH_ROOT="${DT_WORK_ROOT:-$HOME/Documents/Github}"

die() { printf 'gather-work: %s\n' "$1" >&2; exit 1; }
printf '%s' "$DAYS" | grep -qE '^[0-9]+$' || die "days must be a whole number, got '$DAYS'."
[ "$DAYS" -ge 1 ] || die "days must be at least 1."
[ -d "$SEARCH_ROOT" ] || die "no search root at $SEARCH_ROOT. Set DT_WORK_ROOT to where the repositories live."

# BSD date on macOS, GNU date elsewhere. Neither accepts the other's flags.
iso_days_ago() {
  date -u -v-"$1"d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "$1 days ago" +%Y-%m-%dT%H:%M:%SZ
}
SINCE_ISO=$(iso_days_ago "$DAYS")
SINCE_GIT="$DAYS days ago"

# There may be no git identity configured anywhere, and the same person often commits under
# several author lines: a work email in one repo, a GitHub noreply address in another. So take
# the identities from GitHub, add anything git config does happen to know, and match on all of
# them. git ORs multiple --author patterns together.
GH_LOGIN=$(gh api user --jq .login 2>/dev/null)
GH_NAME=$(gh api user --jq .name 2>/dev/null)
IDENTS=()
for i in "$GH_LOGIN" "$GH_NAME" "$(git config --global user.name)" "$(git config --global user.email)"; do
  [ -n "$i" ] && IDENTS+=("$i")
done
[ ${#IDENTS[@]} -gt 0 ] || die "could not work out who you are. Run 'gh auth login', or set git config user.name."
AUTHOR_ARGS=()
for i in "${IDENTS[@]}"; do AUTHOR_ARGS+=(--author="$i"); done

echo "=== WORK GATHER ==="
echo "window:     last $DAYS day(s), rolling, since $SINCE_ISO"
echo "identities: $(printf '%s | ' "${IDENTS[@]}" | sed 's/ | $//')"
echo "root:       $SEARCH_ROOT"

# .git is a directory in a normal clone and a file in a worktree, so do not test for a type.
REPOS=$(find "$SEARCH_ROOT" -maxdepth 3 -name .git 2>/dev/null | sed 's|/\.git$||' | sort)
if [ -n "$ONLY" ]; then
  REPOS=$(printf '%s\n' "$REPOS" | grep -E "(^|/)$(basename "$ONLY")$")
  [ -n "$REPOS" ] || die "no repository called '$ONLY' under $SEARCH_ROOT."
fi
echo "repos:      $(printf '%s\n' "$REPOS" | grep -c .) found"

COMMIT_COUNT=0
KEYS_FILE="${TMPDIR:-/tmp}/dt-work-keys.$$"
: > "$KEYS_FILE"
trap 'rm -f "$KEYS_FILE"' EXIT

echo
echo "--- COMMITS ---"
while IFS= read -r r; do
  [ -n "$r" ] || continue
  # --all so work on a branch you have since left still counts. --no-merges so a merge from the
  # default branch does not read as a day's output.
  LOG=$(git -C "$r" log --all --no-merges "${AUTHOR_ARGS[@]}" --since="$SINCE_GIT" \
        --date=format:'%Y-%m-%d %H:%M' --format='  %ad  %h  %s' --shortstat 2>/dev/null \
        | grep -v '^$' | sed 's/^ [0-9]/      &/')
  if [ -n "$LOG" ]; then
    echo "### $(basename "$r")  [on $(git -C "$r" rev-parse --abbrev-ref HEAD 2>/dev/null)]"
    printf '%s\n' "$LOG"
    COMMIT_COUNT=$((COMMIT_COUNT + $(printf '%s\n' "$LOG" | grep -cE '^  [0-9]{4}-')))
    printf '%s\n' "$LOG" | grep -oE '[A-Z]{2,5}-[0-9]{2,6}' >> "$KEYS_FILE"
  fi
done <<< "$REPOS"
[ "$COMMIT_COUNT" -eq 0 ] && echo "  none by you in this window"

echo
echo "--- IN FLIGHT, uncommitted changes to tracked files ---"
FLIGHT=0
while IFS= read -r r; do
  [ -n "$r" ] || continue
  D=$(git -C "$r" status --porcelain 2>/dev/null | grep -vE '^\?\?' | head -20)
  if [ -n "$D" ]; then
    echo "### $(basename "$r")  [on $(git -C "$r" rev-parse --abbrev-ref HEAD 2>/dev/null)]"
    printf '%s\n' "$D" | sed 's/^/  /'
    FLIGHT=1
  fi
done <<< "$REPOS"
[ "$FLIGHT" -eq 0 ] && echo "  every tree is clean"

echo
echo "--- BRANCHES YOU MOVED IN THIS WINDOW, with no commit of their own ---"
BR=0
CUTOFF=$(date -u -v-"$DAYS"d +%s 2>/dev/null || date -u -d "$DAYS days ago" +%s)
while IFS= read -r r; do
  [ -n "$r" ] || continue
  # Compare epochs, not formatted strings. for-each-ref prints local time and the window is UTC,
  # so a string comparison drops or adds a branch whenever the offset crosses the boundary.
  B=$(git -C "$r" for-each-ref --sort=-committerdate refs/heads \
      --format='%(committerdate:unix)|%(refname:short)|%(authorname)' 2>/dev/null \
      | awk -F'|' -v c="$CUTOFF" '$1 >= c { print $2 "|" $3 }' \
      | grep -vE '^(main|master|develop|trunk|staging)\|' \
      | grep -Ff <(printf '%s\n' "${IDENTS[@]}") \
      | cut -d'|' -f1)
  if [ -n "$B" ]; then
    echo "### $(basename "$r")"
    printf '%s\n' "$B" | sed 's/^/  /'
    printf '%s\n' "$B" | grep -oE '[A-Z]{2,5}-[0-9]{2,6}' >> "$KEYS_FILE"
    BR=1
  fi
done <<< "$REPOS"
[ "$BR" -eq 0 ] && echo "  none"

echo
echo "--- PULL REQUESTS ---"
# Narrowing has to reach GitHub too. Filter on the repository name rather than passing --repo,
# because the local directory name is all we have and it need not carry the owner.
PR_FMT='.[] | select($only == "" or .repository.name == $only)
        | "  \(.repository.name)#\(.number)  \(.state | ascii_upcase)  \(.title)"'
ONLY_NAME=""; [ -n "$ONLY" ] && ONLY_NAME=$(basename "$ONLY")
PR_AUTH=$(gh search prs --author=@me --updated=">=$SINCE_ISO" --limit 40 \
          --json repository,number,title,state,url 2>/dev/null \
          | jq -r --arg only "$ONLY_NAME" "$PR_FMT" 2>/dev/null)
echo "yours:"
if [ -n "$PR_AUTH" ]; then printf '%s\n' "$PR_AUTH"; else echo "  none touched in this window"; fi

# reviewed-by returns your own pull requests too, because reviewing your own counts to GitHub.
# Subtract them, or the same work is reported twice under two headings.
OWN_IDS=$(printf '%s\n' "$PR_AUTH" | grep -oE '[a-z0-9._-]+#[0-9]+' | sort -u)
PR_REV=$(gh search prs --reviewed-by=@me --updated=">=$SINCE_ISO" --limit 40 \
         --json repository,number,title,state,url 2>/dev/null \
         | jq -r --arg only "$ONLY_NAME" "$PR_FMT" 2>/dev/null)
[ -n "$OWN_IDS" ] && PR_REV=$(printf '%s\n' "$PR_REV" | grep -vFf <(printf '%s\n' "$OWN_IDS"))
echo "reviewed by you, excluding your own:"
if [ -n "$PR_REV" ]; then printf '%s\n' "$PR_REV"; else echo "  none in this window"; fi

printf '%s\n%s\n' "$PR_AUTH" "$PR_REV" | grep -oE '[A-Z]{2,5}-[0-9]{2,6}' >> "$KEYS_FILE"

echo
echo "--- TICKET KEYS SEEN ---"
KEYS=$(sort -u "$KEYS_FILE" | grep -v '^$')
if [ -n "$KEYS" ]; then
  printf '%s\n' "$KEYS" | tr '\n' ' ' | sed 's/^/  /;s/ $//'; echo
else
  echo "  none, so there is no Jira lookup to do"
fi

echo
if [ "$COMMIT_COUNT" -eq 0 ] && [ -z "$PR_AUTH" ] && [ -z "$PR_REV" ] && [ "$FLIGHT" -eq 0 ]; then
  echo "--- NOTHING IN THIS WINDOW ---"
  LAST=""
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    D=$(git -C "$r" log --all "${AUTHOR_ARGS[@]}" -1 --date=short --format='%ad' 2>/dev/null)
    [ -n "$D" ] && [ "$D" \> "$LAST" ] && LAST="$D"
  done <<< "$REPOS"
  if [ -n "$LAST" ]; then
    TODAY=$(date +%Y-%m-%d)
    WIDER=$(( ( $(date -j -f %Y-%m-%d "$TODAY" +%s 2>/dev/null || date -d "$TODAY" +%s) \
              - $(date -j -f %Y-%m-%d "$LAST" +%s 2>/dev/null || date -d "$LAST" +%s) ) / 86400 + 1 ))
    echo "  your last commit was $LAST. Rerun with $WIDER to reach it."
  else
    echo "  no commits by you at any time in ${ONLY:-every repository under $SEARCH_ROOT}."
  fi
fi

echo "=== END GATHER ==="

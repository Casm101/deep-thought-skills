#!/usr/bin/env bash
# Everything a session needs to pick up a branch somebody else was working on.
#
# Usage: inherit-recon.sh [<branch>]
#   no argument -> the current branch
#
# Read-only. Runs no tests, changes nothing, checks nothing out.
set -uo pipefail

die() { printf 'inherit-recon: %s\n' "$1" >&2; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository."
ROOT=$(git rev-parse --show-toplevel); cd "$ROOT" || exit 1
have() { command -v "$1" >/dev/null 2>&1; }

CUR=$(git rev-parse --abbrev-ref HEAD)
TARGET="${1:-$CUR}"
DEFAULT=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
[ -z "$DEFAULT" ] && for c in main master trunk develop; do
  git rev-parse --verify --quiet "origin/$c" >/dev/null 2>&1 && { DEFAULT="$c"; break; }
done
DEFAULT="${DEFAULT:-main}"

TIP="$TARGET"
git rev-parse --verify --quiet "refs/heads/$TARGET" >/dev/null 2>&1 || TIP="origin/$TARGET"
git rev-parse --verify --quiet "$TIP" >/dev/null 2>&1 || die "'$TARGET' exists neither locally nor on origin."
MB=$(git merge-base "origin/$DEFAULT" "$TIP" 2>/dev/null) || die "no merge base with origin/$DEFAULT."

echo "=== INHERITING $TARGET ==="
echo "you are on:  $CUR$([ "$CUR" = "$TARGET" ] && echo "  (same branch)")"
echo "default:     origin/$DEFAULT"
echo "position:    $(git rev-list --count "$MB".."$TIP") commit(s) of its own, $(git rev-list --count "$TIP".."origin/$DEFAULT") behind origin/$DEFAULT"
echo "last touched: $(git log -1 --format='%as' "$TIP")"
KEY=$(printf '%s' "$TARGET" | grep -oiE '[A-Z]{2,4}-[0-9]{3,6}' | head -1)
echo "ticket key:  ${KEY:-none in the branch name}"

echo
echo "--- what it set out to do, from the commit messages ---"
git log --reverse --format='  %h %s' "$MB".."$TIP" | head -30

echo
echo "--- what it changed ---"
git diff --stat "$MB" "$TIP" | tail -25

echo
echo "--- tests it touched, the best signal of how finished it is ---"
git diff --name-only "$MB" "$TIP" | grep -E '(\.spec\.|\.test\.|/test_|_test\.)' | sed 's/^/  /' || echo "  none, which is itself worth knowing"

echo
echo "--- markers it left behind ---"
git diff -U0 "$MB" "$TIP" 2>/dev/null | grep -E '^\+.*\b(TODO|FIXME|XXX|HACK|WIP)\b' | head -15 | sed 's/^+/  /' || echo "  none"
git diff -U0 "$MB" "$TIP" 2>/dev/null | grep -cE '^\+.*\.(only|skip)\(' | grep -qv '^0$' \
  && echo "  WARNING: a .only or .skip was added, tests may not be running" || true

echo
echo "--- uncommitted work in this tree ---"
DIRTY=$(git status --porcelain | grep -vE '^\?\?' || true)
[ -n "$DIRTY" ] && printf '%s\n' "$DIRTY" | sed 's/^/  /' || echo "  none"
UNTRACKED=$(git ls-files --others --exclude-standard | head -10)
[ -n "$UNTRACKED" ] && { echo "  untracked:"; printf '%s\n' "$UNTRACKED" | sed 's/^/    /'; }

echo
echo "--- stashes, which belong to nobody and are easy to miss ---"
if [ "$(git stash list | grep -c . || true)" = "0" ]; then
  echo "  none"
else
  git stash list --format='%gd|%gs' | while IFS='|' read -r ref msg; do
    echo "  $ref  $msg"
    git stash show --stat "$ref" 2>/dev/null | tail -3 | sed 's/^/      /'
  done
fi

echo
echo "--- a handoff document, if a previous session left one ---"
TMP="${TMPDIR:-/tmp}"; TMP="${TMP%/}"
FOUND=0
# one list, deduped: the globs overlap and a doc listed twice reads like two docs
for f in $( { ls -1 "$TMP"/handoff-* 2>/dev/null; ls -1 .claude/*handoff* 2>/dev/null; } | sort -u ); do
  [ -f "$f" ] || continue
  FOUND=1
  printf '  %s  (%s lines, %s)\n' "$f" "$(wc -l < "$f" | tr -d ' ')" "$(date -r "$f" '+%Y-%m-%d %H:%M' 2>/dev/null)"
done
[ "$FOUND" = "0" ] && echo "  none in $TMP or .claude/" || echo "  Read these first. They hold what nobody can reconstruct."

echo
echo "--- the PR, if there is one ---"
if have gh && gh auth status >/dev/null 2>&1; then
  PR=$(gh pr list --head "$TARGET" --state all --json number -q '.[0].number' 2>/dev/null)
  if [ -n "$PR" ]; then
    gh pr view "$PR" --json number,title,url,state,isDraft,reviewDecision,mergeable,updatedAt \
      -q '"  #\(.number) \(.title)\n  \(.url)\n  state: \(.state)\(if .isDraft then " DRAFT" else "" end)   review: \(.reviewDecision // "none")   mergeable: \(.mergeable // "?")\n  updated: \(.updatedAt)"' 2>/dev/null
    echo "  unresolved review threads:"
    gh api graphql -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){reviewThreads(first:50){nodes{isResolved path line comments(first:1){nodes{author{login} body}}}}}}}' \
      -F o="$(gh repo view --json owner -q .owner.login)" -F r="$(gh repo view --json name -q .name)" -F n="$PR" 2>/dev/null \
      | jq -r '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved|not) | "    \(.path):\(.line // 0) \(.comments.nodes[0].author.login): \(.comments.nodes[0].body | gsub("\n";" ") | .[0:100])"' 2>/dev/null | head -10 \
      || echo "    (could not read threads)"
    echo "  checks:"
    # gh pr checks exits non-zero when anything is pending or failing, so capture first
    CHECKS=$(gh pr checks "$PR" 2>/dev/null | head -8)
    [ -n "$CHECKS" ] && printf '%s\n' "$CHECKS" | sed 's/^/    /' || echo "    (none reported)"
  else
    echo "  no PR for this branch"
  fi
else
  echo "  gh unavailable, so PR state is unknown. Say so in the briefing."
fi

echo
echo "--- next ---"
[ -n "$KEY" ] && echo "  read the ticket: atlassian-mcp / getJiraIssue, issueIdOrKey $KEY, include the comment field"
echo "  read the diff in full: git diff $MB..$TIP"
echo "  then run the type check and the touched tests to find out whether this branch is green"
echo
echo "=== END ==="

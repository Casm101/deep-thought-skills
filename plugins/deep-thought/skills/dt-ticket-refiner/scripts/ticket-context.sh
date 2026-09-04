#!/usr/bin/env bash
# Everything this repository already knows about a ticket.
#
# Usage: ticket-context.sh [<key> | <browse url>]
#   no argument -> the key in the current branch name
#
# Read-only. Reaches nothing outside the repo except gh for PR lookup.
set -uo pipefail

ARG="${1:-}"
die() { printf 'ticket-context: %s\n' "$1" >&2; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository."
cd "$(git rev-parse --show-toplevel)" || exit 1
have() { command -v "$1" >/dev/null 2>&1; }

# ---- resolve the key -----------------------------------------------------
KEY=""
case "$ARG" in
  "")   KEY=$(git rev-parse --abbrev-ref HEAD | grep -oiE '[A-Z]{2,4}-[0-9]{3,6}' | head -1)
        SRC="the current branch name" ;;
  *browse/*) KEY=$(printf '%s' "$ARG" | grep -oiE '[A-Z]{2,4}-[0-9]{3,6}' | head -1); SRC="the URL" ;;
  *)    KEY=$(printf '%s' "$ARG" | grep -oiE '^[A-Z]{2,4}-[0-9]{3,6}$' | head -1); SRC="the argument" ;;
esac
[ -n "$KEY" ] || die "could not find a ticket key in $SRC. Pass one like TS-42830."
KEY=$(printf '%s' "$KEY" | tr '[:lower:]' '[:upper:]')
PROJECT="${KEY%%-*}"

echo "=== LOCAL CONTEXT FOR $KEY (from $SRC) ==="
echo "project prefix: $PROJECT"

echo
echo "--- has anyone worked on this already ---"
COMMITS=$(git log --all --oneline --grep="$KEY" -i | head -20)
if [ -n "$COMMITS" ]; then
  printf '%s\n' "$COMMITS" | sed 's/^/  /'
  echo "  ($(git log --all --oneline --grep="$KEY" -i | grep -c . ) commit(s) in total)"
else
  echo "  no commits mention it, so this is likely unstarted"
fi

echo
echo "--- branches named for it ---"
{ git branch -a --format='%(refname:short)' 2>/dev/null | grep -i "$KEY"
  git for-each-ref --format='%(refname:short)' refs/remotes 2>/dev/null | grep -i "$KEY"; } \
  | sed 's|^origin/||' | sort -u | sed 's/^/  /' || true
[ -z "$(git branch -a --format='%(refname:short)' 2>/dev/null | grep -i "$KEY")" ] && echo "  none"

echo
echo "--- pull requests ---"
if have gh && gh auth status >/dev/null 2>&1; then
  gh pr list --search "$KEY" --state all --limit 6 \
    --json number,title,state,url -q '.[] | "  #\(.number) \(.state)  \(.title)\n     \(.url)"' 2>/dev/null \
    || echo "  none found"
else
  echo "  gh unavailable, so PR history is unknown"
fi

echo
echo "--- the key mentioned in tracked files ---"
git grep -lni "$KEY" -- '*.ts' '*.tsx' '*.md' '*.json' 2>/dev/null | head -12 | sed 's/^/  /' \
  || echo "  none, which is normal"

echo
echo "--- documentation that may govern the area ---"
git ls-files | grep -iE '^(CLAUDE|AGENTS|CONVENTIONS|CONTRIBUTING|README)\.md$|^docs/.*\.md$' | head -10 | sed 's/^/  /'

echo
echo "--- how this project writes acceptance criteria ---"
echo "  Read three or four recent $PROJECT tickets before writing any. Same project, same shape."
echo "  Search them with the gateway, do not guess the house format."

echo
echo "--- the reads to run next, all read-only ---"
cat <<EOF
  atlassian-mcp / getJiraIssue
    cloudId: leovegas.atlassian.net
    issueIdOrKey: $KEY
    fields: ["summary","description","status","issuetype","priority","labels","components",
             "project","reporter","assignee","comment","issuelinks","parent","subtasks"]
    responseContentFormat: markdown

  For the house style, three or four recent tickets in the same project:
  atlassian-mcp / searchJiraIssuesUsingJql
    jql: project = $PROJECT AND created >= -60d ORDER BY created DESC

  For a spec, a design page or a related ticket anywhere else:
  atlassian-mcp / search        (Rovo, covers Jira and Confluence, use unless you have JQL)
    query: <the feature in the ticket's own words>
EOF

echo
echo "STOP before any write. Check the project is not AML, KYC, responsible gaming or fraud."
echo "=== END ==="

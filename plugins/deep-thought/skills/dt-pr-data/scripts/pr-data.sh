#!/usr/bin/env bash
# Gather everything needed to write a PR description: the PR, its current body, the repo's
# template, the change itself, the ticket key, and how this repo's merged PRs are written.
#
# Usage: pr-data.sh [<branch> | <pr-number> | <pr-url>]
#   no argument -> the open PR whose head is the current branch
#
# Read-only. Writes nothing.
set -uo pipefail

ARG="${1:-}"
die() { printf 'pr-data: %s\n' "$1" >&2; exit 1; }

command -v gh >/dev/null 2>&1 || die "gh CLI not found. Install it (brew install gh), then 'gh auth login'."
gh auth status >/dev/null 2>&1 || die "gh is not authenticated. Run 'gh auth login'."
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository."

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) \
  || die "could not resolve the GitHub repo here (no 'origin' remote on GitHub?)."

# ---- resolve the PR --------------------------------------------------------
PR=""; SOURCE=""
case "$ARG" in
  "")
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    [ "$BRANCH" = "HEAD" ] && die "detached HEAD; pass a branch name, PR number, or PR URL."
    SOURCE="current branch '$BRANCH'"
    PR=$(gh pr list --repo "$REPO" --head "$BRANCH" --state open --json number -q '.[0].number' 2>/dev/null)
    ;;
  *[!0-9]*)
    if [[ "$ARG" =~ ^https?://.*/pull/([0-9]+) ]]; then
      PR="${BASH_REMATCH[1]}"; SOURCE="URL"
    else
      SOURCE="branch '$ARG'"
      MATCHES=$(gh pr list --repo "$REPO" --head "$ARG" --state open --json number -q '.[].number' 2>/dev/null)
      COUNT=$(printf '%s' "$MATCHES" | grep -c '[0-9]' || true)
      [ "${COUNT:-0}" -gt 1 ] && die "several open PRs have head '$ARG' ($(printf '%s' "$MATCHES" | tr '\n' ' ')). Pass a PR number."
      PR=$(printf '%s\n' "$MATCHES" | head -1)
    fi
    ;;
  *) PR="$ARG"; SOURCE="PR number" ;;
esac
if [ -z "${PR:-}" ]; then
  case "$SOURCE" in
    *"branch '"*)
      HEAD_REF=${SOURCE#*\'}; HEAD_REF=${HEAD_REF%\'*}
      CLOSED=$(gh pr list --repo "$REPO" --head "$HEAD_REF" --state all --json number,state \
                 -q '.[] | "#\(.number) (\(.state))"' 2>/dev/null | head -3 | tr '\n' ' ')
      [ -n "$CLOSED" ] && die "no OPEN PR for $SOURCE in $REPO, but found: ${CLOSED}- pass a PR number."
      ;;
  esac
  die "no open PR found for $SOURCE in $REPO. Pass a PR number or URL."
fi

ME=$(gh api user -q .login 2>/dev/null)
META=$(gh pr view "$PR" --repo "$REPO" \
  --json number,title,url,state,isDraft,author,baseRefName,headRefName,headRefOid,additions,deletions,changedFiles,labels,updatedAt,body 2>/dev/null) \
  || die "PR #$PR not found in $REPO."

HEAD_BRANCH=$(printf '%s' "$META" | jq -r .headRefName)
AUTHOR=$(printf '%s' "$META" | jq -r .author.login)
TITLE=$(printf '%s' "$META" | jq -r .title)

echo "=== PR DATA ($REPO, resolved from $SOURCE) ==="
printf '%s' "$META" | jq -r '"pr:          #\(.number)  \(.title)
url:         \(.url)
author:      \(.author.login)
state:       \(.state)\(if .isDraft then " (DRAFT)" else "" end)
branches:    \(.headRefName) -> \(.baseRefName)
size:        \(.changedFiles) files, +\(.additions)/-\(.deletions)
labels:      \([.labels[].name] | join(", ") | if . == "" then "none" else . end)
updated:     \(.updatedAt)"'
echo "you:         $ME"
[ "$AUTHOR" = "$ME" ] || echo "ownership:   ASK FIRST this PR belongs to $AUTHOR. Rewriting someone else's description needs their say-so."
STATE=$(printf '%s' "$META" | jq -r .state)
[ "$STATE" = "OPEN" ] || echo "state:       ASK FIRST this PR is $STATE. Editing a closed or merged description is rarely what was meant."

# ---- ticket key ------------------------------------------------------------
echo
echo "--- ticket key ---"
echo "branch name for placeholder substitution: $HEAD_BRANCH"
KEY=$(printf '%s' "$HEAD_BRANCH" | grep -oiE '[A-Z]{2}-[0-9]{5}' | head -1)
KEY_FROM="branch"
if [ -z "$KEY" ]; then
  KEY=$(printf '%s' "$TITLE" | grep -oiE '[A-Z]{2}-[0-9]{5}' | head -1); KEY_FROM="PR title"
fi
if [ -z "$KEY" ]; then
  LOOSE=$(printf '%s\n%s\n' "$HEAD_BRANCH" "$TITLE" | grep -oiE '[A-Z]{2,4}-[0-9]{1,6}' | head -3 | tr '\n' ' ')
  if [ -n "$LOOSE" ]; then
    echo "no 2-letter/5-digit key found. Looser candidates: $LOOSE"
    echo "Confirm with the user before using one, or skip the Jira step."
  else
    echo "no ticket key in the branch or title. Skip the Jira step and say so in the report."
  fi
else
  echo "key: $(printf '%s' "$KEY" | tr '[:lower:]' '[:upper:]')  (from $KEY_FROM)"
  echo "fetch it read-only via the gateway: atlassian-mcp / getJiraIssue"
  echo "  cloudId: leovegas.atlassian.net   issueIdOrKey: $(printf '%s' "$KEY" | tr '[:lower:]' '[:upper:]')"
  echo "  responseContentFormat: markdown   fields: summary, description, issuetype, status, labels, components"
fi

# ---- the repo's description structure --------------------------------------
echo
echo "--- PR description template in this repo ---"
TPL=""
for p in .github/PULL_REQUEST_TEMPLATE.md .github/pull_request_template.md \
         .github/PULL_REQUEST_TEMPLATE/default.md docs/PULL_REQUEST_TEMPLATE.md \
         PULL_REQUEST_TEMPLATE.md .gitlab/merge_request_templates/default.md; do
  if [ -f "$(git rev-parse --show-toplevel)/$p" ]; then TPL="$(git rev-parse --show-toplevel)/$p"; break; fi
done
if [ -n "$TPL" ]; then
  echo "found: ${TPL#$(git rev-parse --show-toplevel)/}"
  echo "--- template begins ---"
  cat "$TPL"
  echo "--- template ends ---"
else
  echo "(no template file found; learn the structure from the merged PRs below)"
fi

echo
echo "--- docs that mention PR descriptions ---"
git grep -l -iE 'pull request template|PR description|pull_request_template' -- '*.md' 2>/dev/null | head -10 || echo "(none)"

echo
echo "--- how recent merged PRs are written (house style reference) ---"
for n in $(gh pr list --repo "$REPO" --state merged --limit 3 --json number -q '.[].number' 2>/dev/null); do
  echo "----- #$n -----"
  # Strip the environment-preview tables: they are placeholder substitution, not house style.
  gh pr view "$n" --repo "$REPO" --json body -q .body 2>/dev/null \
    | grep -vE '^\||flavor=|Aurora Tiger script url' | grep -v '^$' | head -18
done

# ---- the current body ------------------------------------------------------
echo
echo "--- CURRENT BODY of #$PR (verbatim; keep this, it is the only copy once you overwrite it) ---"
echo "<<<BODY_BEGIN>>>"
printf '%s' "$META" | jq -r '.body // ""'
echo "<<<BODY_END>>>"

echo
echo "--- placeholders and gaps in the current body ---"
BODY=$(printf '%s' "$META" | jq -r '.body // ""')
[ -z "$BODY" ] && echo "body is EMPTY: build it from the template"
printf '%s' "$BODY" | grep -noE '\{\{[A-Z_]+\}\}|TS-XXXX|[A-Z]+-XXXX|LINK_TO_[A-Z_]+|ATTACHMENT%[A-Z]*ID%[A-Z]*HERE|TODO|TBD|_?N/A_?|<!--[^>]*-->' \
  | head -30 || echo "(no obvious placeholders)"
echo
echo "sections present:"
printf '%s' "$BODY" | grep -nE '^#{1,4} ' || echo "(no headings)"

# ---- the change itself -----------------------------------------------------
echo
echo "--- commits on this branch ---"
gh pr view "$PR" --repo "$REPO" --json commits \
  -q '.commits[] | "\(.oid[0:8])  \(.messageHeadline)"' 2>/dev/null | head -30

echo
echo "--- changed files (churn first) ---"
gh pr view "$PR" --repo "$REPO" --json files \
  -q '.files[] | "\(.additions + .deletions)|+\(.additions)/-\(.deletions)\t\(.path)"' 2>/dev/null \
  | sort -t'|' -k1,1rn | cut -d'|' -f2- | head -60

echo
echo "--- test files touched (feeds the Testing section) ---"
gh pr view "$PR" --repo "$REPO" --json files -q '.files[].path' 2>/dev/null \
  | grep -E '(\.spec\.|\.test\.|/test_|_test\.)' | head -25 || echo "(none)"

echo
echo "--- checks ---"
gh pr checks "$PR" --repo "$REPO" 2>/dev/null | head -20 || echo "(none reported)"

echo
echo "Next: read the diff for anything the file list does not explain."
echo "  gh pr diff $PR --repo $REPO"
echo
echo "=== END PR DATA ==="

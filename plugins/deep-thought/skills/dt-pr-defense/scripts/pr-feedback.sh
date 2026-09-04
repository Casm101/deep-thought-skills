#!/usr/bin/env bash
# Gather every piece of feedback on a pull request, plus the diff it is aimed at.
#
# Usage: pr-feedback.sh [<branch> | <pr-number> | <pr-url>]
#   no argument -> the open PR whose head is the current branch
#
# Read-only against GitHub and the repo. Writes nothing except, for a very large
# diff, a temp file outside the repo whose path it prints.
set -uo pipefail

ARG="${1:-}"
DIFF_INLINE_LIMIT="${PR_DEFENSE_DIFF_INLINE_LIMIT:-2500}"

die() { printf 'pr-feedback: %s\n' "$1" >&2; exit 1; }

command -v gh >/dev/null 2>&1 || die "gh CLI not found. Install it (brew install gh), then run 'gh auth login'."
command -v jq >/dev/null 2>&1 || die "jq not found (brew install jq)."
gh auth status >/dev/null 2>&1 || die "gh is not authenticated. Run 'gh auth login'."
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository."

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) \
  || die "could not resolve the GitHub repo here (no 'origin' remote pointing at GitHub?)."
OWNER=${REPO%%/*}
NAME=${REPO##*/}

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
      [ -n "$CLOSED" ] && die "no OPEN PR for $SOURCE in $REPO, but found: ${CLOSED}- pass a PR number to work on one of those."
      ;;
  esac
  die "no open PR found for $SOURCE in $REPO. Pass a PR number or URL."
fi

ME=$(gh api user -q .login 2>/dev/null)

# ---- identity --------------------------------------------------------------
echo "=== PR FEEDBACK ($REPO, resolved from $SOURCE) ==="
gh pr view "$PR" --repo "$REPO" \
  --json number,title,url,state,isDraft,author,baseRefName,headRefName,headRefOid,additions,deletions,changedFiles,reviewDecision,updatedAt \
  -q '"pr:          #\(.number)  \(.title)
url:         \(.url)
author:      \(.author.login)
state:       \(.state)\(if .isDraft then " (DRAFT)" else "" end)   review decision: \(.reviewDecision // "none")
branches:    \(.headRefName) -> \(.baseRefName)
head sha:    \(.headRefOid)
size:        \(.changedFiles) files, +\(.additions)/-\(.deletions)
updated:     \(.updatedAt)"' || die "PR #$PR not found in $REPO."

AUTHOR=$(gh pr view "$PR" --repo "$REPO" --json author -q .author.login 2>/dev/null)
echo "you:         $ME"
if [ "$AUTHOR" = "$ME" ]; then
  echo "ownership:   this is your PR, defending it is appropriate"
else
  echo "ownership:   WARNING this PR belongs to $AUTHOR, not you."
  echo "             Do not answer another person's review on their behalf. Stop and ask the user."
fi

echo
echo "--- checks (a failing gate is feedback too) ---"
gh pr checks "$PR" --repo "$REPO" 2>/dev/null | sort -k2,2 | head -30 || echo "(no checks reported)"

echo
echo "--- changed files ---"
gh pr view "$PR" --repo "$REPO" --json files \
  -q '.files[] | "+\(.additions)/-\(.deletions)\t\(.path)"' | head -60

# ---- feedback via GraphQL (carries resolved / outdated state) ---------------
read -r -d '' Q <<'GRAPHQL'
query($owner:String!,$repo:String!,$pr:Int!){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$pr){
      reviews(first:50){nodes{author{login} state submittedAt body url}}
      reviewThreads(first:100){totalCount nodes{
        isResolved isOutdated
        path line startLine originalLine diffSide
        comments(first:50){nodes{
          databaseId author{login} body createdAt outdated diffHunk url
        }}
      }}
      comments(first:100){nodes{author{login} body createdAt url}}
    }
  }
}
GRAPHQL

GQL=$(gh api graphql -f query="$Q" -F owner="$OWNER" -F repo="$NAME" -F pr="$PR" 2>/dev/null) \
  || die "GraphQL query failed. Check 'gh auth status' scopes."
PRJ=$(printf '%s' "$GQL" | jq '.data.repository.pullRequest')

echo
echo "--- review summaries ---"
printf '%s' "$PRJ" | jq -r '
  (.reviews.nodes // []) | to_entries | .[] |
  "[R\(.key+1)] \(.value.author.login // "?")  \(.value.state)  \(.value.submittedAt[0:10])" +
  (if (.value.body // "") == "" then "" else "\n" + ((.value.body | split("\n") | map("      " + .) | join("\n"))) end)'
[ "$(printf '%s' "$PRJ" | jq '(.reviews.nodes // []) | length')" = "0" ] && echo "(none)"

TOTAL=$(printf '%s' "$PRJ" | jq -r '.reviewThreads.totalCount')
OPEN=$(printf '%s' "$PRJ" | jq -r '[.reviewThreads.nodes[] | select(.isResolved | not)] | length')
echo
echo "--- inline review threads: $TOTAL total, $OPEN unresolved ---"
echo "Unresolved and current first. Bodies are shown in full: they are the thing being validated."
echo "Reply with the comment id shown on each comment."
printf '%s' "$PRJ" | jq -r '
  [.reviewThreads.nodes // [] | to_entries[] | .value + {idx: (.key+1)}]
  | sort_by([(if .isResolved then 2 else 0 end) + (if .isOutdated then 1 else 0 end)])
  | .[] |
  "\n[T\(.idx)] \(.path):\(.line // .startLine // .originalLine // "file-level")  side=\(.diffSide // "RIGHT")  " +
  "status=" + (if .isResolved then "RESOLVED" elif .isOutdated then "UNRESOLVED but OUTDATED (the code moved since)" else "UNRESOLVED, current" end) +
  "\n  anchored to:\n" +
  ((.comments.nodes[0].diffHunk // "(no hunk)") | split("\n") | .[-8:] | map("    " + .) | join("\n")) +
  "\n" +
  ((.comments.nodes // []) | map(
     "  --- comment id=\(.databaseId) by \(.author.login // "?") \(.createdAt[0:10])\(if .outdated then " [outdated]" else "" end)\n" +
     ((.body // "") | split("\n") | map("      " + .) | join("\n"))
   ) | join("\n"))'
[ "$TOTAL" = "0" ] && echo "(none)"

echo
echo "--- general PR comments (not anchored to code) ---"
printf '%s' "$PRJ" | jq -r '
  (.comments.nodes // []) | to_entries | .[] |
  "[C\(.key+1)] \(.value.author.login // "?")  \(.value.createdAt[0:10])\n" +
  ((.value.body // "") | split("\n") | map("      " + .) | join("\n"))'
[ "$(printf '%s' "$PRJ" | jq '(.comments.nodes // []) | length')" = "0" ] && echo "(none)"

echo
echo "--- commits since the first review (did you already address some of this?) ---"
FIRST_REVIEW=$(printf '%s' "$PRJ" | jq -r '[(.reviews.nodes // [])[].submittedAt, (.reviewThreads.nodes // [])[].comments.nodes[0].createdAt] | sort | .[0] // ""')
if [ -n "$FIRST_REVIEW" ] && [ "$FIRST_REVIEW" != "null" ]; then
  echo "earliest feedback: $FIRST_REVIEW"
  gh pr view "$PR" --repo "$REPO" --json commits \
    -q ".commits[] | select(.committedDate > \"$FIRST_REVIEW\") | \"\(.committedDate[0:16])  \(.messageHeadline)\"" 2>/dev/null | head -20
  echo "(a comment predating one of these commits may already be handled; check before answering)"
else
  echo "(no feedback timestamps found)"
fi

# ---- diff ------------------------------------------------------------------
DIFF=$(gh pr diff "$PR" --repo "$REPO" 2>/dev/null) || die "could not fetch the diff for #$PR."
DIFF_LINES=$(printf '%s\n' "$DIFF" | wc -l | tr -d ' ')
echo
if [ "$DIFF_LINES" -le "$DIFF_INLINE_LIMIT" ]; then
  echo "--- diff ($DIFF_LINES lines) ---"
  printf '%s\n' "$DIFF"
else
  SPILL="$(mktemp -t "pr-${PR}-diff")"
  printf '%s\n' "$DIFF" > "$SPILL"
  echo "--- diff is large ($DIFF_LINES lines), saved outside the repo ---"
  echo "full diff: $SPILL"
  echo "Read the files each thread points at rather than the whole diff."
fi

echo
echo "=== END FEEDBACK ==="

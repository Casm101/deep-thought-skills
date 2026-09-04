#!/usr/bin/env bash
# List the comments this change added or touched, with their file and line.
#
# Usage: comment-diff.sh [<base ref>]
#   no argument -> uncommitted work, staged and unstaged, against HEAD
#   with a ref   -> that ref up to HEAD, plus anything uncommitted
#
# Read-only. Changes nothing.
set -uo pipefail

BASE="${1:-}"
die() { printf 'comment-diff: %s\n' "$1" >&2; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository."
cd "$(git rev-parse --show-toplevel)" || exit 1

if [ -n "$BASE" ]; then
  MB=$(git merge-base "$BASE" HEAD 2>/dev/null) || die "no merge base with $BASE."
  RANGE="$MB"
  echo "=== COMMENTS TOUCHED (since $BASE, merge base $(git rev-parse --short "$MB")) ==="
else
  RANGE="HEAD"
  echo "=== COMMENTS TOUCHED (uncommitted work) ==="
fi

# -U0 so each hunk carries only added and removed lines, which keeps the
# new-file line numbering exact.
DIFF=$(git diff -U0 "$RANGE" 2>/dev/null)
[ -n "$DIFF" ] || { echo "(nothing changed)"; exit 0; }

printf '%s\n' "$DIFF" | awk '
  /^\+\+\+ b\// {
    file = substr($0, 7)
    # prose files belong to dt-unslop, and generated output belongs to whatever generates it
    skip = (file ~ /\.(md|mdx|txt|rst|adoc|snap|lock|json|ya?ml)$/) || (file ~ /\/generated\/|\.gen\./)
    next
  }
  /^@@/ {
    # @@ -a,b +c,d @@  -> take c
    match($0, /\+[0-9]+/); n = substr($0, RSTART + 1, RLENGTH - 1) + 0; next
  }
  /^\+/ {
    if (skip) next
    line = substr($0, 2)
    body = line; sub(/^[ \t]+/, "", body)
    whole = 0; inline = 0
    if (body ~ /^(\/\/|\/\*|\*|#|<!--|--[^-]|""")/) whole = 1
    else if (line ~ /[^:"'"'"']\/\// || line ~ /\/\*/ || line ~ /[^#]#[ \t]/) inline = 1
    if (whole) printf "%s:%d: %s\n", file, n, line
    else if (inline) printf "%s:%d: [inline] %s\n", file, n, line
    n++
    next
  }
' | grep -v ':[0-9]*: *#!' | head -200

TOTAL=$(printf '%s\n' "$DIFF" | grep -c '^+[^+]' || true)
echo
echo "added or modified lines in total: $TOTAL"
echo
echo "Every line above is a candidate. Judge each one against references/comment-rules.md."
echo "A line marked [inline] is code with a trailing comment: keep the code, judge the comment."
echo
echo "=== END ==="

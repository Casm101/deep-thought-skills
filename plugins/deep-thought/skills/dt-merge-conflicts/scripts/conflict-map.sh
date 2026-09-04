#!/usr/bin/env bash
# Say what operation is in progress, which side is which, and what is conflicted.
#
# Usage: conflict-map.sh
#
# Read-only. Resolves nothing, stages nothing.
set -uo pipefail

die() { printf 'conflict-map: %s\n' "$1" >&2; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository."
ROOT=$(git rev-parse --show-toplevel); cd "$ROOT" || exit 1
GD=$(git rev-parse --git-dir)

echo "=== CONFLICT MAP ==="

# ---- which operation, and therefore which side is which ------------------
OP=""; OURS=""; THEIRS=""
if [ -f "$GD/MERGE_HEAD" ]; then
  OP="merge"
  OURS="HEAD, the branch you are on"
  THEIRS="MERGE_HEAD, the branch being merged in"
elif [ -d "$GD/rebase-merge" ] || [ -d "$GD/rebase-apply" ]; then
  OP="rebase"
  OURS="the upstream you are rebasing onto, NOT your work"
  THEIRS="your own commit being replayed"
elif [ -f "$GD/CHERRY_PICK_HEAD" ]; then
  OP="cherry-pick"
  OURS="HEAD, the branch you are on"
  THEIRS="the commit being picked"
elif [ -f "$GD/REVERT_HEAD" ]; then
  OP="revert"
  OURS="HEAD, the branch you are on"
  THEIRS="the inverse of the commit being reverted"
fi

if [ -z "$OP" ]; then
  echo "no merge, rebase, cherry-pick or revert in progress."
  CONF=$(git diff --name-only --diff-filter=U 2>/dev/null)
  [ -n "$CONF" ] && { echo "but these files are still marked unresolved:"; printf '%s\n' "$CONF" | sed 's/^/  /'; }
  echo "Start the operation first, or say there is nothing to resolve."
  exit 0
fi

echo "operation:  $OP"
echo "ours   =    $OURS"
echo "theirs =    $THEIRS"
if [ "$OP" = "rebase" ]; then
  echo
  echo "            READ THAT AGAIN. In a rebase the labels are inverted against"
  echo "            what you expect: 'ours' is the branch you are landing on and"
  echo "            'theirs' is your own change. Anything that reasons about"
  echo "            'prefer our work' must use 'theirs' here."
fi

echo
echo "branch:     $(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
[ -f "$GD/MERGE_HEAD" ] && echo "merging in: $(git log -1 --format='%h %s' MERGE_HEAD 2>/dev/null)"
[ -f "$GD/MERGE_MSG" ] && echo "merge msg:  $(head -1 "$GD/MERGE_MSG")"

# ---- what is conflicted --------------------------------------------------
echo
echo "--- conflicted files ---"
STATUS=$(git status --porcelain 2>/dev/null | grep -E '^(UU|AA|DU|UD|AU|UA|DD) ' || true)
if [ -z "$STATUS" ]; then
  echo "(none, every conflict is resolved. Check for markers before committing.)"
else
  printf '%s\n' "$STATUS" | while read -r code path; do
    case "$code" in
      UU) kind="both modified";;
      AA) kind="both ADDED the same path, usually two implementations of one thing";;
      DU) kind="we deleted it, they modified it, needs a decision";;
      UD) kind="we modified it, they deleted it, needs a decision";;
      AU) kind="we added it, they modified it";;
      UA) kind="they added it, we modified it";;
      DD) kind="both deleted it, usually just accept the deletion";;
      *)  kind="$code";;
    esac
    hunks=$(grep -c '^<<<<<<<' "$path" 2>/dev/null || echo 0)
    # classify the file, because some kinds are never resolved by hand
    class="source"
    case "$path" in
      *pnpm-lock.yaml|*package-lock.json|*yarn.lock|*Gemfile.lock|*Cargo.lock|*poetry.lock) class="LOCKFILE, regenerate, never merge the text";;
      */generated/*|*.gen.*|*.pb.go|*_pb2.py) class="GENERATED, regenerate from its source";;
      *.snap) class="SNAPSHOT, comes from a test run, not from editing";;
      *package.json) class="MANIFEST, often a version bump on both sides";;
      *CHANGELOG*) class="CHANGELOG, usually take both entries";;
      *.spec.*|*.test.*|*/__tests__/*) class="TEST, the incoming half is the spec for their change";;
    esac
    printf '  %-4s %-58s %s hunk(s)\n       %s\n       %s\n' "$code" "$path" "$hunks" "$kind" "$class"
  done
fi

# ---- did the incoming side bring tests -----------------------------------
if [ -f "$GD/MERGE_HEAD" ]; then
  echo
  echo "--- tests the incoming side added or changed ---"
  MB=$(git merge-base HEAD MERGE_HEAD 2>/dev/null)
  if [ -n "$MB" ]; then
    git diff --name-only "$MB" MERGE_HEAD 2>/dev/null \
      | grep -E '(\.spec\.|\.test\.|/__tests__/)' | head -20 | sed 's/^/  /' || echo "  (none)"
    echo "  These are the specification for what came in. They must pass when you are done."
  fi
fi

echo
echo "--- markers still in the working tree ---"
MARKED=$(grep -rln '^<<<<<<< \|^>>>>>>> ' . --exclude-dir=.git 2>/dev/null | head -20 || true)
if [ -n "$MARKED" ]; then printf '%s\n' "$MARKED" | sed 's/^/  /'; else echo "  none"; fi

echo
echo "Abort at any point with: git $([ "$OP" = "merge" ] && echo merge || echo "$OP") --abort"
echo "=== END ==="

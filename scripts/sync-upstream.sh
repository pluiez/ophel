#!/usr/bin/env bash
# Helper for syncing this fork from upstream urzeye/ophel.
#
# This script DOES NOT auto-rebase or auto-merge. It only:
#   - Verifies upstream remote is configured.
#   - Fetches upstream.
#   - Reports the relationship between main / personal and upstream/main.
#   - Prints the manual checklist from FORK_MAINTENANCE.md.
#
# Run with `pnpm sync:upstream` (see package.json) or directly:
#   bash scripts/sync-upstream.sh

set -euo pipefail

UPSTREAM_REMOTE="upstream"
UPSTREAM_URL="https://github.com/urzeye/ophel.git"

if ! git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
  echo "Adding '$UPSTREAM_REMOTE' remote -> $UPSTREAM_URL"
  git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
fi

echo "Fetching $UPSTREAM_REMOTE..."
git fetch "$UPSTREAM_REMOTE" --tags --quiet

UPSTREAM_HEAD=$(git rev-parse "$UPSTREAM_REMOTE/main")
LOCAL_MAIN=$(git rev-parse main 2>/dev/null || echo "<missing>")
LOCAL_PERSONAL=$(git rev-parse personal 2>/dev/null || echo "<missing>")

echo ""
echo "=== Refs ==="
printf "  upstream/main : %s\n" "$UPSTREAM_HEAD"
printf "  origin/main   : %s\n" "$(git rev-parse origin/main 2>/dev/null || echo '<missing>')"
printf "  local main    : %s\n" "$LOCAL_MAIN"
printf "  local personal: %s\n" "$LOCAL_PERSONAL"

echo ""
echo "=== Distance ==="
if [ "$LOCAL_MAIN" != "<missing>" ]; then
  AHEAD_BEHIND=$(git rev-list --left-right --count "$LOCAL_MAIN...$UPSTREAM_REMOTE/main" 2>/dev/null || echo "? ?")
  AHEAD=${AHEAD_BEHIND%	*}
  BEHIND=${AHEAD_BEHIND#*	}
  printf "  main vs upstream/main: %s ahead, %s behind\n" "$AHEAD" "$BEHIND"
fi

if [ "$LOCAL_PERSONAL" != "<missing>" ]; then
  AHEAD_BEHIND=$(git rev-list --left-right --count "$LOCAL_PERSONAL...$UPSTREAM_REMOTE/main" 2>/dev/null || echo "? ?")
  AHEAD=${AHEAD_BEHIND%	*}
  BEHIND=${AHEAD_BEHIND#*	}
  printf "  personal vs upstream/main: %s ahead, %s behind\n" "$AHEAD" "$BEHIND"
fi

echo ""
echo "=== New commits on upstream/main since local main ==="
git log --oneline --no-decorate "$LOCAL_MAIN..$UPSTREAM_REMOTE/main" 2>/dev/null | head -20 || echo "  (none or main missing)"

echo ""
echo "=== Next steps (manual; see FORK_MAINTENANCE.md) ==="
cat <<'EOF'
  If main is behind upstream/main and you're ready to sync:
    1. git checkout main
    2. git merge --ff-only upstream/main
    3. git push origin main
    4. git checkout personal
    5. git rebase upstream/main      # resolve conflicts here
    6. pnpm typecheck && pnpm build:userscript
    7. Compare build/userscript/userscript-assets/ against jsdelivr;
       if any hash changed, sync userscript-assets branch.
    8. cp build/userscript/ophel.user.js dist/ophel.user.js
       git add -f dist/ophel.user.js
       git commit -m "build: rebuild userscript artifact for vX-personal-N"
    9. git push --force-with-lease origin personal
   10. git tag -a vX-personal-N -m "..."  &&  git push origin vX-personal-N
EOF

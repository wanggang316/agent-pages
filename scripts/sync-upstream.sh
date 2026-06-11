#!/usr/bin/env bash
set -euo pipefail
#
# sync-upstream.sh — pull template updates into your gallery fork.
#
# Assumes:
#   origin   = your gallery fork (where your pages live)
#   upstream = the agent-pages template repo
#
# First time only, add the template as upstream:
#   git remote add upstream <template-repo-url>
#
# Usage:
#   ./scripts/sync-upstream.sh

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$here" rev-parse --show-toplevel)"
cd "$repo_root"

git remote get-url upstream >/dev/null 2>&1 || {
  echo "No 'upstream' remote. Add it once:" >&2
  echo "  git remote add upstream <template-repo-url>" >&2
  exit 1
}

branch="$(git rev-parse --abbrev-ref HEAD)"
git fetch upstream --prune
git checkout "$branch"

if git merge --no-ff "upstream/$branch" -m "merge: sync agent-pages template"; then
  echo "OK: synced upstream -> $branch"
  echo "Re-run ./scripts/install.sh to refresh the installed skill."
else
  echo "Merge has conflicts. Resolve them, then:" >&2
  echo "  git add -A && git commit && git push origin $branch" >&2
  exit 1
fi

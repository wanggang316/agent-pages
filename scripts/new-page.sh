#!/usr/bin/env bash
set -euo pipefail
#
# new-page.sh — prepare a new agent-pages page.
#
# It does the deterministic, error-prone groundwork so the assistant doesn't
# have to: sync the gallery repo, stamp TODAY'S date from the system clock
# (never an LLM-remembered date), resolve the target path, and report it as
# JSON. It does NOT write page content — the assistant designs and writes that.
#
# Usage:
#   scripts/new-page.sh --project <name> --slug <kebab-slug> [--no-pull]
#
# Output (stdout): a single JSON object, e.g.
#   {"galleryPath":"…","project":"react","projectDir":"…/react","date":"20260604",
#    "dateHuman":"2026-06-04","slug":"server-components","targetPath":"…/react/20260604-server-components.html",
#    "relPath":"./react/20260604-server-components.html","isNewProject":true,"collisionResolved":false}

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/config.sh
. "$here/lib/config.sh"

project=""
slug=""
do_pull=1
while [ $# -gt 0 ]; do
  case "$1" in
    --project) project="${2:-}"; shift 2 ;;
    --slug)    slug="${2:-}"; shift 2 ;;
    --no-pull) do_pull=0; shift ;;
    *) ap_die "unknown argument: $1" ;;
  esac
done

[ -n "$project" ] || ap_die "--project is required (default to the basename of your Claude Code cwd)"
[ -n "$slug" ]    || ap_die "--slug is required (kebab-case, short, English)"

ap_require_gallery
gallery="$AGENT_PAGES_GALLERY_PATH"

# --- sync ---
git -C "$gallery" checkout "$AGENT_PAGES_BRANCH" >/dev/null 2>&1 || true
if [ "$do_pull" -eq 1 ]; then
  if ! git -C "$gallery" pull --rebase origin "$AGENT_PAGES_BRANCH" >/dev/null 2>&1; then
    printf 'agent-pages: warning: could not pull origin/%s (offline or conflicts); continuing\n' "$AGENT_PAGES_BRANCH" >&2
  fi
fi

# --- date from the SYSTEM clock ---
date="$(date +%Y%m%d)"
date_human="$(date +%Y-%m-%d)"

# --- resolve project dir ---
project_dir="$gallery/$project"
is_new_project=false
[ -d "$project_dir" ] || is_new_project=true
mkdir -p "$project_dir"

# --- resolve target file, avoiding collisions ---
base="${date}-${slug}.html"
target="$project_dir/$base"
collision=false
if [ -e "$target" ]; then
  collision=true
  i=2
  while [ -e "$project_dir/${date}-${slug}-${i}.html" ]; do i=$((i + 1)); done
  base="${date}-${slug}-${i}.html"
  target="$project_dir/$base"
fi

rel="./$project/$base"

printf '{"galleryPath":"%s","project":"%s","projectDir":"%s","date":"%s","dateHuman":"%s","slug":"%s","fileName":"%s","targetPath":"%s","relPath":"%s","isNewProject":%s,"collisionResolved":%s}\n' \
  "$(ap_json_escape "$gallery")" \
  "$(ap_json_escape "$project")" \
  "$(ap_json_escape "$project_dir")" \
  "$date" "$date_human" \
  "$(ap_json_escape "$slug")" \
  "$(ap_json_escape "$base")" \
  "$(ap_json_escape "$target")" \
  "$(ap_json_escape "$rel")" \
  "$is_new_project" "$collision"

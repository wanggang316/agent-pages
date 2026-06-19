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
# Pages are organized by category: <category>/<yyyyMMdd>-<slug>.html. The
# category is a slug from gallery.json's fixed category set.
#
# Usage:
#   scripts/new-page.sh --category <slug> --slug <kebab-slug> [--no-pull]
#
# Output (stdout): a single JSON object, e.g.
#   {"galleryPath":"…","category":"engineering","categoryDir":"…/engineering","date":"20260604",
#    "dateHuman":"2026-06-04","slug":"server-components","targetPath":"…/engineering/20260604-server-components.html",
#    "relPath":"./engineering/20260604-server-components.html","isNewCategory":true,"collisionResolved":false}

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/config.sh
. "$here/lib/config.sh"

category=""
slug=""
do_pull=1
while [ $# -gt 0 ]; do
  case "$1" in
    --category) category="${2:-}"; shift 2 ;;
    --slug)     slug="${2:-}"; shift 2 ;;
    --no-pull)  do_pull=0; shift ;;
    *) ap_die "unknown argument: $1" ;;
  esac
done

[ -n "$category" ] || ap_die "--category is required (a slug from gallery.json categories, e.g. engineering)"
[ -n "$slug" ]     || ap_die "--slug is required (kebab-case, short, English)"
case "$category" in
  */*|*\\*|.|..) ap_die "invalid category name: $category" ;;
esac

ap_require_gallery
gallery="$AGENT_PAGES_GALLERY_PATH"

# --- validate category against gallery.json (best-effort; needs python3) ---
if command -v python3 >/dev/null 2>&1 && [ -f "$gallery/gallery.json" ]; then
  if ! python3 - "$gallery/gallery.json" "$category" <<'PY'
import json
import sys

path, cat = sys.argv[1:3]
try:
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
except Exception:
    sys.exit(0)  # cannot read/parse -> don't block, let publish validate

slugs = set()
for item in data.get("categories") or []:
    if isinstance(item, str):
        slugs.add(item.strip())
    elif isinstance(item, dict):
        slugs.add((item.get("slug") or item.get("label") or "").strip())

# no configured categories -> can't validate, allow
sys.exit(0 if (not slugs or cat in slugs) else 1)
PY
  then
    ap_die "unknown category: $category (choose a slug from gallery.json categories, add it there, or use 'other')"
  fi
fi

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

# --- resolve category dir ---
category_dir="$gallery/$category"
is_new_category=false
[ -d "$category_dir" ] || is_new_category=true
mkdir -p "$category_dir"

# --- resolve target file, avoiding collisions ---
base="${date}-${slug}.html"
target="$category_dir/$base"
collision=false
if [ -e "$target" ]; then
  collision=true
  i=2
  while [ -e "$category_dir/${date}-${slug}-${i}.html" ]; do i=$((i + 1)); done
  base="${date}-${slug}-${i}.html"
  target="$category_dir/$base"
fi

rel="./$category/$base"

printf '{"galleryPath":"%s","category":"%s","categoryDir":"%s","date":"%s","dateHuman":"%s","slug":"%s","fileName":"%s","targetPath":"%s","relPath":"%s","isNewCategory":%s,"collisionResolved":%s}\n' \
  "$(ap_json_escape "$gallery")" \
  "$(ap_json_escape "$category")" \
  "$(ap_json_escape "$category_dir")" \
  "$date" "$date_human" \
  "$(ap_json_escape "$slug")" \
  "$(ap_json_escape "$base")" \
  "$(ap_json_escape "$target")" \
  "$(ap_json_escape "$rel")" \
  "$is_new_category" "$collision"

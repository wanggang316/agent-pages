#!/usr/bin/env bash
set -euo pipefail
#
# publish.sh — close the loop for an agent-pages page.
#
# Deterministic finish: register the page in gallery.json, commit ONLY the page
# + gallery home/data files, push (with a rebase retry), and open the page
# locally. The assistant still designs/writes the page; this script just
# publishes it reliably.
#
# Usage:
#   scripts/publish.sh --project <name> --file <path> --title "<human title>" \
#                      --date <YYYY-MM-DD> [--tags "tag-a,tag-b"] \
#                      [--message "<commit msg>"] \
#                      [--no-index] [--no-push] [--no-open]
#
# Output (stdout): a single JSON object with commit + url info.

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/config.sh
. "$here/lib/config.sh"

project="" file="" title="" date="" tags="" message=""
do_index=1 do_push=1 do_open=1
while [ $# -gt 0 ]; do
  case "$1" in
    --project) project="${2:-}"; shift 2 ;;
    --file)    file="${2:-}"; shift 2 ;;
    --title)   title="${2:-}"; shift 2 ;;
    --date)    date="${2:-}"; shift 2 ;;
    --tags)    tags="${2:-}"; shift 2 ;;
    --message) message="${2:-}"; shift 2 ;;
    --no-index) do_index=0; shift ;;
    --no-push)  do_push=0; shift ;;
    --no-open)  do_open=0; shift ;;
    *) bh5_die "unknown argument: $1" ;;
  esac
done

[ -n "$project" ] || bh5_die "--project is required"
[ -n "$file" ]    || bh5_die "--file is required"
[ -n "$title" ]   || bh5_die "--title is required (human-readable, for the index)"
[ -n "$date" ]    || bh5_die "--date is required (YYYY-MM-DD)"
case "$date" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;; *) bh5_die "--date must be YYYY-MM-DD" ;; esac

bh5_require_gallery
gallery="$BUILD_H5_GALLERY_PATH"
index="$gallery/index.html"
gallery_json="$gallery/gallery.json"

# --- resolve the page to an absolute path, then to a gallery-relative path ---
case "$file" in
  /*) abs="$file" ;;
  *)  if [ -e "$gallery/$file" ]; then abs="$gallery/$file"; else abs="$PWD/$file"; fi ;;
esac
[ -e "$abs" ] || bh5_die "page file not found: $file"
abs="$(cd "$(dirname "$abs")" && pwd)/$(basename "$abs")"
case "$abs" in
  "$gallery"/*) rel="${abs#"$gallery"/}" ;;
  *) bh5_die "page is outside the gallery: $abs" ;;
esac
href="./$rel"
fname="$(basename "$abs")"
slug="${fname%.html}"; slug="${slug#[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-}"
year="${date%%-*}"

# --- update structured gallery data ---
index_status="skipped"
if [ "$do_index" -eq 1 ]; then
  command -v python3 >/dev/null 2>&1 || bh5_die "python3 is required to update gallery.json"
  index_status="$(
    python3 - "$gallery_json" "$href" "$title" "$date" "$year" "$project" "$slug" "$tags" <<'PY'
import json
import os
import sys
from collections import Counter

path, href, title, date, year, project, slug, raw_tags = sys.argv[1:9]

def normalize_tag(value):
    return str(value or "").strip()

def unique(values):
    seen = set()
    result = []
    for value in values:
        value = normalize_tag(value)
        if value and value not in seen:
            seen.add(value)
            result.append(value)
    return result

def read_data(path):
    if not os.path.exists(path):
        return {"version": 1, "updatedAt": "", "tags": [], "entries": []}
    with open(path, "r", encoding="utf-8") as fh:
        try:
            data = json.load(fh)
        except json.JSONDecodeError as exc:
            raise SystemExit(f"gallery.json is invalid JSON: {exc}") from exc
    if not isinstance(data, dict):
        raise SystemExit("gallery.json must contain a JSON object")
    data.setdefault("version", 1)
    data.setdefault("updatedAt", "")
    data.setdefault("tags", [])
    data.setdefault("entries", [])
    if not isinstance(data["entries"], list):
        raise SystemExit("gallery.json entries must be an array")
    return data

def canonical(data):
    return json.dumps(data, ensure_ascii=False, sort_keys=True, separators=(",", ":"))

data = read_data(path)
before = canonical(data)
entry_tags = unique([project, *raw_tags.replace(";", ",").split(",")])
entry = {
    "title": title,
    "href": href,
    "date": date,
    "year": year,
    "project": project,
    "slug": slug,
    "tags": entry_tags,
}

entries = data["entries"]
existing = next((item for item in entries if isinstance(item, dict) and item.get("href") == href), None)
if existing is None:
    entries.append(entry)
else:
    existing.update(entry)

entries.sort(key=lambda item: (str(item.get("date", "")), str(item.get("title", ""))), reverse=True)

counts = Counter()
for item in entries:
    if not isinstance(item, dict):
        continue
    for tag in item.get("tags", []):
        tag = normalize_tag(tag)
        if tag:
            counts[tag] += 1

data["tags"] = [
    {"slug": tag, "label": tag, "count": counts[tag]}
    for tag in sorted(counts, key=str.casefold)
]
data["updatedAt"] = date

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, ensure_ascii=False, indent=2)
    fh.write("\n")

print("already-present" if before == canonical(data) else "updated")
PY
  )"
fi

# --- commit ONLY the page + gallery home/data files ---
[ -n "$message" ] || message="feat($project): add $slug page"
git -C "$gallery" add -- "$abs" "$index" "$gallery_json"
commit_status="committed"
if git -C "$gallery" diff --cached --quiet; then
  commit_status="nothing-to-commit"
else
  git -C "$gallery" commit -q -m "$message"
fi
sha="$(git -C "$gallery" rev-parse --short HEAD 2>/dev/null || echo "")"

# --- push with a single rebase retry ---
push_status="skipped"
if [ "$do_push" -eq 1 ] && [ "$commit_status" = "committed" ]; then
  if git -C "$gallery" push -q origin "$BUILD_H5_BRANCH" 2>/dev/null; then
    push_status="pushed"
  elif git -C "$gallery" pull --rebase -q origin "$BUILD_H5_BRANCH" 2>/dev/null \
       && git -C "$gallery" push -q origin "$BUILD_H5_BRANCH" 2>/dev/null; then
    push_status="pushed-after-rebase"
  else
    push_status="push-failed"
  fi
fi

# --- open locally ---
if [ "$do_open" -eq 1 ] && command -v open >/dev/null 2>&1; then
  open "$abs" >/dev/null 2>&1 || true
fi

# --- report ---
live_url=""
if [ -n "$BUILD_H5_SITE_BASE_URL" ]; then
  live_url="${BUILD_H5_SITE_BASE_URL%/}/${rel}"
fi
printf '{"relPath":"%s","fileUrl":"file://%s","liveUrl":"%s","commit":"%s","commitStatus":"%s","indexStatus":"%s","pushStatus":"%s"}\n' \
  "$(bh5_json_escape "$href")" \
  "$(bh5_json_escape "$abs")" \
  "$(bh5_json_escape "$live_url")" \
  "$sha" "$commit_status" "$index_status" "$push_status"

#!/usr/bin/env bash
# Shared config loader for build-h5 scripts. Source this, don't execute it.
#
# Resolution order for the gallery path:
#   1. BUILD_H5_GALLERY_PATH from ~/.claude/build-h5/config.env (written by install.sh)
#   2. fallback: the git toplevel of the directory containing this script
#      (works when scripts are run from inside the gallery clone, even with no config)

# --- locate this script's repo, independent of the caller's cwd ---
_bh5_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_bh5_repo_root="$(git -C "$_bh5_lib_dir" rev-parse --show-toplevel 2>/dev/null || echo "$(dirname "$_bh5_lib_dir")")"

# --- load user config if present ---
BUILD_H5_CONFIG_DIR="${BUILD_H5_CONFIG_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/build-h5}"
BUILD_H5_CONFIG_FILE="${BUILD_H5_CONFIG_FILE:-$BUILD_H5_CONFIG_DIR/config.env}"
if [ -f "$BUILD_H5_CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  . "$BUILD_H5_CONFIG_FILE"
fi

# --- defaults ---
: "${BUILD_H5_GALLERY_PATH:=$_bh5_repo_root}"
: "${BUILD_H5_BRANCH:=main}"
: "${BUILD_H5_SITE_BASE_URL:=}"
: "${BUILD_H5_GALLERY_NAME:=HTML <Pages/>}"
: "${BUILD_H5_DEFAULT_PROJECT:=}"

# expand a leading ~ / $HOME in the gallery path
BUILD_H5_GALLERY_PATH="${BUILD_H5_GALLERY_PATH/#\~/$HOME}"
BUILD_H5_GALLERY_PATH="${BUILD_H5_GALLERY_PATH/#\$HOME/$HOME}"

bh5_die() { printf 'build-h5: %s\n' "$*" >&2; exit 1; }

bh5_require_gallery() {
  [ -n "$BUILD_H5_GALLERY_PATH" ] || bh5_die "gallery path is empty; run scripts/install.sh or set BUILD_H5_GALLERY_PATH"
  [ -d "$BUILD_H5_GALLERY_PATH/.git" ] || bh5_die "gallery is not a git repo: $BUILD_H5_GALLERY_PATH"
  [ -f "$BUILD_H5_GALLERY_PATH/index.html" ] || bh5_die "no index.html in gallery: $BUILD_H5_GALLERY_PATH"
}

# json_escape <string> -> stdout (escapes for embedding inside a JSON string)
bh5_json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

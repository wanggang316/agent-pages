#!/usr/bin/env bash
# Shared config loader for agent-pages scripts. Source this, don't execute it.
#
# Resolution order for the gallery path:
#   1. AGENT_PAGES_PATH from ~/.claude/agent-pages/config.env (written by install.sh)
#   2. fallback: the git toplevel of the directory containing this script
#      (works when scripts are run from inside the gallery clone, even with no config)

# --- locate this script's repo, independent of the caller's cwd ---
_ap_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ap_repo_root="$(git -C "$_ap_lib_dir" rev-parse --show-toplevel 2>/dev/null || echo "$(dirname "$_ap_lib_dir")")"

# --- load user config if present ---
if [ -z "${AGENT_PAGES_CONFIG_DIR:-}" ]; then
  AGENT_PAGES_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/agent-pages"
fi
if [ -z "${AGENT_PAGES_CONFIG_FILE:-}" ]; then
  AGENT_PAGES_CONFIG_FILE="$AGENT_PAGES_CONFIG_DIR/config.env"
fi
if [ -f "$AGENT_PAGES_CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  . "$AGENT_PAGES_CONFIG_FILE"
fi

# --- defaults ---
: "${AGENT_PAGES_PATH:=$_ap_repo_root}"
: "${AGENT_PAGES_REPO:=}"
: "${AGENT_PAGES_BRANCH:=main}"
: "${AGENT_PAGES_SITE_BASE_URL:=}"
: "${AGENT_PAGES_NAME:=Agent <Pages/>}"

# expand a leading ~ / $HOME in the gallery path
AGENT_PAGES_PATH="${AGENT_PAGES_PATH/#\~/$HOME}"
AGENT_PAGES_PATH="${AGENT_PAGES_PATH/#\$HOME/$HOME}"

ap_die() { printf 'agent-pages: %s\n' "$*" >&2; exit 1; }

ap_require_gallery() {
  [ -n "$AGENT_PAGES_PATH" ] || ap_die "gallery path is empty; run scripts/install.sh or set AGENT_PAGES_PATH"
  [ -d "$AGENT_PAGES_PATH/.git" ] || ap_die "gallery is not a git repo: $AGENT_PAGES_PATH"
  [ -f "$AGENT_PAGES_PATH/index.html" ] || ap_die "no index.html in gallery: $AGENT_PAGES_PATH"
}

# json_escape <string> -> stdout (escapes for embedding inside a JSON string)
ap_json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

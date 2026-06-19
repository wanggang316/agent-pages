#!/usr/bin/env bash
# Shared config loader for agent-pages scripts. Source this, don't execute it.
#
# Config + state live in the plugin's persistent data dir (CLAUDE_PLUGIN_DATA),
# i.e. ~/.claude/plugins/data/<plugin-id>/config.env, written by setup.sh and
# surviving plugin updates. The skill invokes scripts with AGENT_PAGES_CONFIG_FILE
# set to that path; as a fallback we derive it from CLAUDE_PLUGIN_DATA if present.

# --- locate the config file ---
if [ -z "${AGENT_PAGES_CONFIG_FILE:-}" ] && [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  AGENT_PAGES_CONFIG_FILE="$CLAUDE_PLUGIN_DATA/config.env"
fi
if [ -n "${AGENT_PAGES_CONFIG_FILE:-}" ] && [ -f "$AGENT_PAGES_CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  . "$AGENT_PAGES_CONFIG_FILE"
fi

# --- defaults ---
: "${AGENT_PAGES_PATH:=}"
: "${AGENT_PAGES_REPO:=}"
: "${AGENT_PAGES_BRANCH:=main}"
: "${AGENT_PAGES_SITE_BASE_URL:=}"
: "${AGENT_PAGES_NAME:=Agent <Pages/>}"

# expand a leading ~ / $HOME in the site path
AGENT_PAGES_PATH="${AGENT_PAGES_PATH/#\~/$HOME}"
AGENT_PAGES_PATH="${AGENT_PAGES_PATH/#\$HOME/$HOME}"

ap_die() { printf 'agent-pages: %s\n' "$*" >&2; exit 1; }

ap_require_gallery() {
  [ -n "$AGENT_PAGES_PATH" ] || ap_die "AGENT_PAGES_PATH not configured; run setup first (\${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh)"
  [ -d "$AGENT_PAGES_PATH/.git" ] || ap_die "site is not a git repo: $AGENT_PAGES_PATH (run setup)"
  [ -f "$AGENT_PAGES_PATH/index.html" ] || ap_die "no index.html in site: $AGENT_PAGES_PATH (run setup)"
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

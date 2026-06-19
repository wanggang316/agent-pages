#!/usr/bin/env bash
# SessionStart hook for agent-pages.
# Injects the use-agent-pages bootstrap meta-skill as additional context so
# every session knows the /agent-pages entry point and when to offer it.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
SKILL_FILE="${PLUGIN_ROOT}/skills/use-agent-pages/SKILL.md"

if [ ! -f "$SKILL_FILE" ]; then
  exit 0
fi

CONTENT=$(cat "$SKILL_FILE")
WRAPPED=$(printf '<IMPORTANT>\nagent-pages loaded. Offer `/agent-pages <topic>` when a self-contained HTML artifact beats a long Markdown answer; only generate after the user confirms or runs the command.\n\n%s\n</IMPORTANT>' "$CONTENT")

if command -v jq >/dev/null 2>&1; then
  jq -n --arg ctx "$WRAPPED" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
else
  ESCAPED=$(printf '%s' "$WRAPPED" \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' \
    | awk 'BEGIN{ORS="\\n"} {print}')
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$ESCAPED"
fi

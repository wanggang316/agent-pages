# agent-pages bootstrap (FOR THE ASSISTANT)

This document is written for an **AI coding assistant** (e.g. Claude Code).
Your job: install the `agent-pages` plugin for your human, then operate it reliably.

## Goal

After setup, when the human types `/agent-pages <topic>`, you turn the current
conversation into a polished, single-file HTML page, publish it to their **site
repo**, and push it so GitHub Pages (or any static host) serves it.

> agent-pages ships as a **Claude Code plugin** installed from a marketplace. The
> plugin carries the site scaffold in `templates/`. The human's site is a
> **separate** git repo (`AGENT_PAGES_PATH`), scaffolded from those templates on
> first use. Config + state live in the plugin's persistent data dir.

## What ships in the plugin

- `.claude-plugin/plugin.json` — the plugin manifest (the plugin is cataloged in the `wanggang316/claude-plugins` marketplace)
- `hooks/{hooks.json, session-start.sh}` — SessionStart hook that injects the `use-agent-pages` doctrine
- `skills/agent-pages/SKILL.md` — the workflow skill (paths via `${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_PLUGIN_DATA}`)
- `skills/use-agent-pages/SKILL.md` — the bootstrap meta-skill (injected each session)
- `scripts/setup.sh` — one-time: scaffold the site from `templates/` + write config to `${CLAUDE_PLUGIN_DATA}/config.env`
- `scripts/new-page.sh` — sync site repo + stamp today's date + resolve the target path → JSON
- `scripts/publish.sh` — register in `data.json` + commit (page + home/data files) + push + open → JSON
- `templates/{index.html, data.json, data.schema.json, CNAME.example}` — the site scaffold
- `config.example.env` — config template

## Runtime locations (no hardcoded paths)

- **Scripts**: `${CLAUDE_PLUGIN_ROOT}/scripts/` (ephemeral plugin dir; never write state here)
- **Config + state**: `${CLAUDE_PLUGIN_DATA}/config.env` (persistent, survives plugin updates) — holds
  `AGENT_PAGES_PATH` / `AGENT_PAGES_REPO` / `AGENT_PAGES_BRANCH` / `AGENT_PAGES_SITE_BASE_URL` / `AGENT_PAGES_NAME`
- **The site**: `$AGENT_PAGES_PATH` (a separate git repo the human owns → GitHub Pages)

These `${CLAUDE_PLUGIN_*}` variables are substituted to real absolute paths inside
skill text. Always `export AGENT_PAGES_CONFIG_FILE="${CLAUDE_PLUGIN_DATA}/config.env"`
before calling a script.

## Prerequisites

- Claude Code with plugin support (`/plugin marketplace add`, `/plugin install`)
- git, bash (default on macOS/Linux)
- `jq` (optional) for the SessionStart hook; falls back to awk/sed
- `open` for auto-opening pages (macOS); harmless if absent
- python3 for `setup.sh` and `publish.sh` to maintain `data.json`

## Install (one time)

Inside Claude Code:

```text
/plugin marketplace add wanggang316/claude-plugins
/plugin install agent-pages@wanggang316
```

Then start a new session. On the human's first `/agent-pages`, run `setup.sh` once
(confirm the site dir / title / repo first; default dir `$HOME/agent-pages`):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh" \
  --config "${CLAUDE_PLUGIN_DATA}/config.env" \
  --templates "${CLAUDE_PLUGIN_ROOT}/templates" \
  --path "$HOME/agent-pages"   # optional: --name "<title>" --repo "<git-url>" --site "<public-url>"
```

It scaffolds the site, `git init`s it, and writes config. Then help the human
create a GitHub repo for the site, push, and enable Pages.

## Safety note (review before running)

- `setup.sh` — scaffolds `AGENT_PAGES_PATH` from `templates/`, `git init`s it, writes `${CLAUDE_PLUGIN_DATA}/config.env`; never pushes. Existing files are kept unless `--force`.
- `session-start.sh` — read-only; prints the `use-agent-pages` doctrine as session context.
- `new-page.sh` — runs `git pull --rebase` in the site repo and resolves a path; writes no content.
- `publish.sh` — edits `data.json`, `git add`s only the page plus `index.html` + `data.json`, commits, pushes, `open`s the page.

If anything looks off (unexpected paths, destructive ops), warn the human and ask before running.

## Operating contract (after install)

- Treat `/agent-pages …` as the normal entry point. The injected `use-agent-pages` doctrine may recommend `/agent-pages` during long plan/design requests; only write & publish after the human confirms or uses the command.
- Follow `skills/agent-pages/SKILL.md`: (first run) setup → prepare → assess material → **design from scratch** → publish → verify → report.
- Never reuse an existing page's design. Never use an LLM-remembered date — use the date `new-page.sh` returns.
- Never `git add -A` in the site — let `publish.sh` stage only the page + `index.html` + `data.json`.

## Updating

- The plugin: `/plugin marketplace update wanggang316`, then a new session (or `/reload-plugins`).
- The site scaffold after a template change: re-run `setup.sh --force` to re-copy `index.html` / `data.schema.json` (pages and `data.json` are kept unless forced).

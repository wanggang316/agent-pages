# agent-pages bootstrap (FOR THE ASSISTANT)

This document is written for an **AI coding assistant** (e.g. Claude Code).
Your job: install the `agent-pages` capability for your human, then operate it reliably.

## Goal

After setup, when the human types `/agent-pages <topic>`, you turn the current
conversation into a polished, single-file HTML page, publish it to their gallery
repo, and push it so GitHub Pages (or any static host) serves it.

> The gallery IS this repo. The human forks/clones it; their generated pages live
> alongside `scripts/` and `skills/`. You write pages into the clone and push.
> agent-pages ships as a **Claude Code plugin** — the same fork is both the plugin
> source and the gallery.

## What ships in this repo

- `.claude-plugin/plugin.json` — the plugin manifest
- `.claude-plugin/marketplace.json` — a local marketplace (`source: ./`) so the fork installs itself
- `hooks/hooks.json` + `hooks/session-start.sh` — SessionStart hook that injects the `use-agent-pages` doctrine
- `skills/agent-pages/SKILL.md` — the workflow skill (config-driven, no hardcoded paths)
- `skills/use-agent-pages/SKILL.md` — the bootstrap meta-skill (injected each session)
- `index.html` — the gallery home (deployed site root; renders `gallery.json`)
- `gallery.json` — structured category options, page list, and tags maintained by `publish.sh`
- `gallery.schema.json` — JSON contract for agents that maintain `gallery.json`
- `scripts/install.sh` — writes runtime config + seeds gallery metadata (no skill copy, no settings.json edit)
- `scripts/new-page.sh` — sync repo + stamp today's date + resolve the target path → JSON
- `scripts/publish.sh` — register in gallery.json + commit (page + home/data files) + push + open → JSON
- `scripts/sync-upstream.sh` — pull template updates into the fork
- `config.example.env` — config template

## One-time setup checklist

### 0) Prerequisites

- Claude Code with plugin support (`/plugin marketplace add`, `/plugin install`)
- git, bash, awk (default on macOS/Linux)
- `jq` (optional) for the SessionStart hook; falls back to awk/sed
- `open` for auto-opening pages (macOS); harmless if absent
- python3 for `publish.sh` and `install.sh` to maintain `gallery.json`

### 1) Ask the human

- Their gallery repo: fork `wanggang316/agent-pages`-style, or let you fork this template? Or an existing repo?
- A custom domain for Pages? (optional)
- Default target language for page copy? (default: 中文 body, English identifiers)

### 2) Repo

- Clone the human's gallery fork into their workspace (or `git clone` this template as the gallery).
- No build/install of dependencies is needed — the gallery is plain static HTML.

### 3) Configure the gallery

Run from inside the gallery clone:

```bash
./scripts/install.sh                # config + gallery title (default: Agent <Pages/>)
./scripts/install.sh --name "Gump <Pages/>"   # set title non-interactively
./scripts/install.sh --site https://h5.example.com   # record a public base URL for live links
```

This writes:
- `~/.claude/agent-pages/config.env`
- `gallery.json.site.title` + `categories` in the gallery clone

It does **not** copy any skill and does **not** edit `settings.json` — those came
from the old hook-based install. The capability now comes from the plugin.

### 4) Install the plugin

Inside Claude Code, point the marketplace at the gallery clone and install:

```text
/plugin marketplace add <absolute path to the gallery clone>
/plugin install agent-pages@agent-pages
```

This registers the `agent-pages` workflow skill, the `use-agent-pages` meta-skill,
and the SessionStart hook. Start a new session so the hook injects the
`use-agent-pages` doctrine and the skill is discovered.

### 5) Deploy (GitHub Pages, the common path)

- Repo Settings → Pages → "Deploy from a branch" → `main` / root.
- Custom domain: `cp CNAME.example CNAME`, edit, commit, push.
- Pages serves `index.html` at the root and each page at `/<category>/<yyyyMMdd>-<slug>.html`.

## Safety note (review before running)

Before running automation on the human's machine, skim the scripts you'll execute:

- `install.sh` — writes `~/.claude/agent-pages/config.env` and edits the gallery's `gallery.json`; never pushes, never touches `settings.json`.
- `hooks/session-start.sh` — read-only; prints the `use-agent-pages` doctrine as session context. Runs as a plugin hook.
- `new-page.sh` — runs `git pull --rebase` in the gallery and resolves a path; writes no content.
- `publish.sh` — edits `gallery.json`, `git add`s only the page plus gallery home/data files, commits, pushes the gallery branch, `open`s the page.

If anything looks off (unexpected paths, destructive ops), warn the human and ask before running.

## Operating contract (after install)

- Treat `/agent-pages …` as the normal entry point for the generation workflow. The injected `use-agent-pages` doctrine may recommend `/agent-pages` during long plan/design requests; start writing and publishing a page after the human confirms that they want the page generated or uses the command directly.
- Follow `skills/agent-pages/SKILL.md`: prepare → assess material → **design from scratch** → publish → verify → report.
- Never reuse an existing page's design. Never use an LLM-remembered date — use the date `new-page.sh` returns.
- Never `git add -A` in the gallery — let `publish.sh` stage only the page + `index.html` + `gallery.json`.

## Updates

```bash
git remote add upstream <template-repo-url>   # first time only
./scripts/sync-upstream.sh
./scripts/install.sh                           # refresh config + gallery metadata
```

The plugin tracks the clone, so the skills and hook update with the pull. If a new
session doesn't pick them up, re-run the `/plugin` install commands (or
`/plugin marketplace update agent-pages`).

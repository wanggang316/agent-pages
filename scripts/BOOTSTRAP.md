# agent-pages bootstrap (FOR THE ASSISTANT)

This document is written for an **AI coding assistant** (e.g. Claude Code).
Your job: install the `agent-pages` capability for your human, then operate it reliably.

## Goal

After setup, when the human types `/agent-pages <topic>`, you turn the current
conversation into a polished, single-file HTML page, publish it to their gallery
repo, and push it so GitHub Pages (or any static host) serves it.

> The gallery IS this repo. The human forks/clones it; their generated pages live
> alongside `scripts/` and `skills/`. You write pages into the clone and push.

## What ships in this repo

- `index.html` — the gallery home (deployed site root; renders `gallery.json`)
- `gallery.json` — structured page list + tags maintained by `publish.sh`
- `gallery.schema.json` — JSON contract for agents that maintain `gallery.json`
- `skills/agent-pages/SKILL.md` — the portable skill (config-driven, no hardcoded paths)
- `scripts/install.sh` — installs the skill + writes config (+ optional hint hook)
- `scripts/new-page.sh` — sync repo + stamp today's date + resolve the target path → JSON
- `scripts/publish.sh` — register in gallery.json + commit (page + home/data files) + push + open → JSON
- `scripts/sync-upstream.sh` — pull template updates into the fork
- `config.example.env` — config template

## One-time setup checklist

### 0) Prerequisites

- git, bash, awk (default on macOS/Linux)
- `open` for auto-opening pages (macOS); harmless if absent
- python3 for publishing `gallery.json`; also used by the optional `--with-hook` step

### 1) Ask the human

- Their gallery repo: fork `wanggang316/agent-pages`-style, or let you fork this template? Or an existing repo?
- A custom domain for Pages? (optional)
- Default target language for page copy? (default: 中文 body, English identifiers)

### 2) Repo

- Clone the human's gallery fork into their workspace (or `git clone` this template as the gallery).
- No build/install of dependencies is needed — the gallery is plain static HTML.

### 3) Install

Run from inside the gallery clone:

```bash
./scripts/install.sh                # skill + config; asks for gallery title (default: Agent <Pages/>)
./scripts/install.sh --name "Gump <Pages/>"   # set title non-interactively
./scripts/install.sh --with-hook    # also add the /agent-pages hint hook to ~/.claude/settings.json
./scripts/install.sh --no-hook      # skip the hook prompt in interactive shells
./scripts/install.sh --site https://h5.example.com   # record a public base URL for live links
```

This writes:
- `~/.claude/skills/agent-pages/SKILL.md`
- `~/.claude/agent-pages/config.env`
- `gallery.json.site.title` in the gallery clone

In an interactive shell, `install.sh` asks whether to add the optional Claude Code
hook unless `--with-hook` or `--no-hook` is passed.

Tell the human to restart Claude Code (or `/reload`) so the skill is discovered.

### 4) Deploy (GitHub Pages, the common path)

- Repo Settings → Pages → "Deploy from a branch" → `main` / root.
- Custom domain: `cp CNAME.example CNAME`, edit, commit, push.
- Pages serves `index.html` at the root and each page at `/<project>/<yyyyMMdd>-<slug>.html`.

## Safety note (review before running)

Before running automation on the human's machine, skim the scripts you'll execute:

- `install.sh` — writes under `~/.claude/` only; never pushes. With `--with-hook` it merges
  one `UserPromptSubmit` entry into `~/.claude/settings.json` (idempotent).
- `new-page.sh` — runs `git pull --rebase` in the gallery and resolves a path; writes no content.
- `publish.sh` — edits `gallery.json`, `git add`s only the page plus gallery home/data files, commits, pushes the gallery branch, `open`s the page.

If anything looks off (unexpected paths, destructive ops), warn the human and ask before running.

## Operating contract (after install)

- Treat `/agent-pages …` as the normal entry point for the generation workflow. The optional hook may recommend `/agent-pages` during long plan/design requests; start writing and publishing a page after the human confirms that they want the page generated or uses the command directly.
- Follow `skills/agent-pages/SKILL.md`: prepare → assess material → **design from scratch** → publish → verify → report.
- Never reuse an existing page's design. Never use an LLM-remembered date — use the date `new-page.sh` returns.
- Never `git add -A` in the gallery — let `publish.sh` stage only the page + `index.html` + `gallery.json`.

## Updates

```bash
git remote add upstream <template-repo-url>   # first time only
./scripts/sync-upstream.sh
./scripts/install.sh                           # refresh the installed skill
```

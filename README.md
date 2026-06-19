# agent-pages

**agent-pages** turns a conversation into a polished, single-file HTML page and
publishes it to your own site — one command: `/agent-pages <topic>`.

It ships as a **Claude Code plugin** installed from a marketplace. This repo is
the plugin (skills + hook + scripts) and carries the site scaffold in
`templates/`. Your generated pages live in a **separate** git repo you own
(`AGENT_PAGES_PATH`), which GitHub Pages (or any static host) serves.

---

## What you get

After setup, typing `/agent-pages <topic>` makes the assistant:

1. sync your site repo and stamp today's date (from the system clock)
2. design a page **from scratch** for that topic — structure, graphics, tables, motion, responsive UI
3. write a single self-contained HTML file under `<category>/<yyyyMMdd>-<slug>.html`
4. register it in `data.json` so the home page can render and filter it
5. commit the page plus home/data files, push, and open the page locally

The assistant does the creative part (page design). Scripts do the deterministic,
error-prone part (sync, dates, paths, data, commit/push).

---

## Install

Install the plugin from the marketplace inside Claude Code:

```text
/plugin marketplace add wanggang316/agent-pages
/plugin install agent-pages@agent-pages
```

That registers the `agent-pages` workflow skill, the `use-agent-pages` bootstrap
meta-skill, and a SessionStart hook. Start a new session, then run:

```text
/agent-pages <topic>
```

On the **first** run there's no site yet, so the skill runs `setup.sh` once:
it scaffolds a site from the plugin's `templates/` into `AGENT_PAGES_PATH`
(default `$HOME/agent-pages`), `git init`s it, and writes config + state to the
plugin's persistent data dir. After that, every `/agent-pages` just generates and
publishes pages. (You can also run setup explicitly — see [Setup details](#setup-details).)

---

## How it fits together

Three locations, cleanly separated:

```
1. the plugin (installed from the marketplace; lives under ~/.claude/plugins/…)
   agent-pages/
   ├── .claude-plugin/{plugin.json, marketplace.json}   ← manifest + marketplace (source: ./)
   ├── skills/{agent-pages, use-agent-pages}/SKILL.md    ← the /agent-pages skill + injected doctrine
   ├── hooks/{hooks.json, session-start.sh}              ← injects use-agent-pages each session
   ├── scripts/{setup.sh, new-page.sh, publish.sh, lib/} ← the deterministic plumbing
   └── templates/{index.html, data.json, data.schema.json, CNAME.example}  ← site scaffold

2. config + state (persistent, survives plugin updates)
   ${CLAUDE_PLUGIN_DATA}/config.env   = ~/.claude/plugins/data/agent-pages-agent-pages/config.env

3. your site (a separate git repo you own → GitHub Pages)
   $AGENT_PAGES_PATH/
   ├── index.html  data.json  data.schema.json   ← copied from templates/ on first setup
   └── <category>/<yyyyMMdd>-<slug>.html          ← generated pages
```

Why this split: the plugin (capability) updates via the marketplace; your content
and config never live inside the ephemeral plugin directory. The skill references
scripts as `${CLAUDE_PLUGIN_ROOT}/scripts/…` and config as
`${CLAUDE_PLUGIN_DATA}/config.env` (both substituted to real paths at runtime), so
nothing is hardcoded.

`config.env` holds `AGENT_PAGES_PATH`, `AGENT_PAGES_REPO`, `AGENT_PAGES_BRANCH`,
`AGENT_PAGES_SITE_BASE_URL`, `AGENT_PAGES_NAME`, plus a setup-timestamp state line.
See `config.example.env`.

The home page reads its display title from `data.json.site.title`; a trailing token
wrapped like `<Pages/>` is rendered in a gradient monospace style. `data.schema.json`
is the contract for `data.json`: `site` (metadata), `categories` (stable options),
`entries` (pages), `tags` (derived filter list).

---

## Usage

- `/agent-pages <topic>` — generate a page (the assistant infers a category from the topic)
- `/agent-pages 分类=engineering <topic>` — force the category folder
- `/agent-pages 续写 <filename>` — iterate on an existing page

The workflow starts from an explicit `/agent-pages …` command. The plugin's
`use-agent-pages` doctrine (injected each session) may recommend `/agent-pages
<topic>` during long plan/design requests, but it never creates a page until you
confirm or use the command.

Each page lives under its category folder (`<category>/<yyyyMMdd>-<slug>.html`) and
carries that category in `data.json`; the home page filters by category first, then
by tag. Categories come from the fixed `data.json.categories` set — if none fit, the
assistant uses `other` or asks before adding a new one. Pass extra topic tags with
`publish.sh --tags "react,server-components"`.

If material is thin, the assistant asks before researching online or writing a
TODO-marked outline — it won't fabricate facts.

---

## Setup details

`setup.sh` is idempotent and runs from the plugin; the skill invokes it on first
use, but you can run it directly to control the path / repo / title:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh" \
  --config "${CLAUDE_PLUGIN_DATA}/config.env" \
  --templates "${CLAUDE_PLUGIN_ROOT}/templates" \
  --path "$HOME/agent-pages" \
  --name "Gump <Pages/>" \
  --repo git@github.com:you/your-pages.git \
  --site https://h5.example.com
```

It copies the scaffold (keeping any existing files unless `--force`), `git init`s
the site, seeds `data.json` (title + categories), and writes `config.env`.

---

## Deploy (GitHub Pages)

Deploy your **site repo** (`AGENT_PAGES_PATH`), not this plugin repo:

- Create a GitHub repo, push the site to it, then Settings → Pages → "Deploy from a branch" → `main` / root.
- Custom domain: `cp CNAME.example CNAME`, edit, commit, push; set `AGENT_PAGES_SITE_BASE_URL` in `config.env` for live links.
- Pages serves `index.html` at the root and pages at `/<category>/<yyyyMMdd>-<slug>.html`.

Netlify / Vercel / Cloudflare Pages also work — it's static HTML, no build step.

---

## Updating

- **The plugin** (skills, hook, scripts, templates): `/plugin marketplace update agent-pages`, then start a new session (or `/reload-plugins`).
- **The site scaffold** after a template change: re-run `setup.sh --force` to re-copy `index.html` / `data.schema.json` (your `data.json` and pages are kept unless you also force them).

---

## Requirements

- Claude Code with plugin support (`/plugin marketplace add` / `/plugin install`)
- git + bash (default on macOS/Linux)
- `jq` (optional) — the SessionStart hook uses it to emit context JSON; falls back to awk/sed
- `open` (macOS) to auto-open pages — optional
- python3 — required by `setup.sh` and `publish.sh` to maintain `data.json`

## License

MIT — see `LICENSE`.

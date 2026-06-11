# agent-pages

**agent-pages** turns a conversation into a polished, single-file HTML page and
publishes it to your own gallery — one command: `/agent-pages <topic>`.

It is a small, installable capability you add to a coding assistant (Claude Code
first). This repo is **both** the capability (skill + scripts + bootstrap) **and**
the gallery template you deploy — you fork it, your generated pages live inside it,
and GitHub Pages (or any static host) serves them.

---

## What you get

After setup, typing `/agent-pages <topic>` makes the assistant:

1. sync your gallery repo and stamp today's date (from the system clock)
2. design a page **from scratch** for that topic — structure, graphics, tables, motion, responsive UI
3. write a single self-contained HTML file under `<project>/<yyyyMMdd>-<slug>.html`
4. register it in `gallery.json` so the gallery home can render and filter it
5. commit the page plus gallery home/data files, push, and open the page locally

The assistant does the creative part (page design). Scripts do the deterministic,
error-prone part (sync, dates, paths, gallery data, commit/push).

---

## Install (human prompt)

Send this to your assistant (copy/paste), pointing at your fork of this repo:

```text
Help me install and deploy agent-pages: https://github.com/wanggang316/agent-pages
Follow scripts/BOOTSTRAP.md.
```

Or do it yourself in one line from inside your gallery clone:

```bash
./scripts/install.sh            # asks for the gallery title; default: Agent <Pages/>
./scripts/install.sh --name "Gump <Pages/>"   # non-interactive title
```

This installs the skill to `~/.claude/skills/agent-pages/` and writes your config to
`~/.claude/agent-pages/config.env`. Restart Claude Code (or `/reload`) and try
`/agent-pages <topic>`.

---

## How it fits together

```
your fork of this repo  =  your gallery  =  the deployed site
├── index.html                  ← gallery home (renders gallery.json)
├── gallery.json                ← structured page list + tags for agents
├── gallery.schema.json         ← JSON contract for gallery data
├── <project>/                   ← one folder per project
│   └── 20260604-<slug>.html     ← generated pages
├── skills/agent-pages/SKILL.md     ← the skill (installed to ~/.claude/skills)
└── scripts/                     ← run from inside the clone
    ├── install.sh   new-page.sh   publish.sh   sync-upstream.sh
```

Nothing is hardcoded to one user: the skill reads `~/.claude/agent-pages/config.env`
(`AGENT_PAGES_GALLERY_PATH`, `AGENT_PAGES_REMOTE`, `AGENT_PAGES_BRANCH`,
`AGENT_PAGES_SITE_BASE_URL`, `AGENT_PAGES_GALLERY_NAME`,
`AGENT_PAGES_DEFAULT_PROJECT`). See `config.example.env`.

The gallery home reads its display title from `gallery.json.site.title`. The
installer writes the same value there, and the trailing token such as
`<Pages/>` is rendered with the gradient monospace style used by the upstream
`<HTML />` mark.

`gallery.schema.json` defines the data contract for agents that maintain
`gallery.json`: `site` stores gallery metadata, `entries` stores pages, and
`tags` stores the derived filter list rendered by the home page.

---

## Usage

- `/agent-pages <topic>` — generate a page (project = current working dir's basename)
- `/agent-pages 项目=react <topic>` — force the project folder
- `/agent-pages 续写 <filename>` — iterate on an existing page

The generation workflow starts from an explicit `/agent-pages …` command. If you
install the optional `--with-hook` hint, the assistant may recommend
`/agent-pages <topic>` during long plan/design requests, but it should not create
a page until you confirm or use the command.

Each published page gets tags in `gallery.json`. The publishing script always
adds the project name as a tag, and agents can pass extra comma-separated tags
with `scripts/publish.sh --tags "react,server-components"`.

If material is thin, the assistant asks before either researching online or
writing a TODO-marked outline — it won't fabricate facts.

---

## Deploy (GitHub Pages)

- Settings → Pages → "Deploy from a branch" → `main` / root.
- Custom domain: `cp CNAME.example CNAME`, edit, commit, push.
- Pages serves `index.html` at the root and pages at `/<project>/<yyyyMMdd>-<slug>.html`.

Netlify / Vercel / Cloudflare Pages also work — it's static HTML, no build step.

---

## Updating

```bash
git remote add upstream <template-repo-url>   # first time only
./scripts/sync-upstream.sh
./scripts/install.sh                           # refresh the installed skill
```

---

## Requirements

- git + bash + awk (default on macOS/Linux)
- `open` (macOS) to auto-open pages — optional
- python3 — required for `publish.sh` to update `gallery.json`; also used by
  the optional `install.sh --with-hook`

## License

MIT — see `LICENSE`.

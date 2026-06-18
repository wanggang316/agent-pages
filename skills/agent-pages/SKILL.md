---
name: agent-pages
description: |
  把当前会话中的主题/资料生成为一个独立可浏览的 HTML 页面（结构清晰、化繁为简、由浅入深，强调图形/表格/动效与精致的 UI/UE），落地到你的画廊仓库并自动 commit + push + 在浏览器中打开。常规入口是 `/agent-pages <主题或说明>`；可选 hook 会在长方案场景提示用户可以使用 `/agent-pages`，确认用户希望生成页面后再进入写文件、发布和提交流程。
---

# Agent Pages Skill

把一个主题/资料生成为一份独立 HTML 页面（适合分享、阅读、复盘），并发布到你的「画廊」仓库（你 fork 的 agent-pages 仓库，同时也是部署到 GitHub Pages 的站点）。

执行链路：`new-page.sh`（同步 + 算路径）→ 评估素材 → 从零设计并写出 HTML → `publish.sh`（登记 `gallery.json` + commit + push + 打开）。脚本负责确定性的脏活，**页面设计这件创造性的事由你来做**。

## When To Use This Skill

常规使用方式是输入以 `/agent-pages` 开头的命令：

- `/agent-pages <主题>` — 用该主题生成 HTML 页面
- `/agent-pages 项目=react <主题>` — 显式指定项目目录（落到画廊的 `react/` 下）
- `/agent-pages 续写 <已有文件名>` — 在已有页面上迭代/补充

其他自然语言（"帮我做个 H5"、"生成一个网页"等）可以先理解为普通请求或 hook 推荐场景，避免直接开始写文件和发布。

若安装了 `--with-hook`，hook 可以在用户请求详细设计方案 / 技术方案 / 架构设计时注入提示，建议用户考虑 `/agent-pages <主题>`；这只是推荐入口，后续是否生成页面以用户确认或明确命令为准。

## 配置（去硬编码）

所有路径来自 `install.sh` 写入的配置文件，**不要把任何仓库路径写死在脑子里**：

```bash
. "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/agent-pages/config.env"
# 得到：AGENT_PAGES_GALLERY_PATH / AGENT_PAGES_REMOTE / AGENT_PAGES_BRANCH /
#       AGENT_PAGES_SITE_BASE_URL / AGENT_PAGES_GALLERY_NAME /
#       AGENT_PAGES_DEFAULT_PROJECT
```

- 画廊根目录 = `$AGENT_PAGES_GALLERY_PATH`（一个 git 仓库，`origin` 指向用户的 fork）
- 脚本就在画廊里：`$AGENT_PAGES_GALLERY_PATH/scripts/`
- 若配置文件不存在 → 说明尚未安装，提示用户在画廊 clone 里运行 `./scripts/install.sh`，先不要硬造路径。
- 首页标题来自 `gallery.json.site.title`，安装时默认 `Agent <Pages/>`；`<Pages/>` 会按 `<HTML />` 风格渲染。
- `gallery.schema.json` 是 `gallery.json` 的结构契约；手动维护时不要偏离其中的字段。

目录结构：两级 —— `<项目>/<yyyyMMdd>-<slug>.html`，例如 `react/20260604-server-components.html`。

## 工作流

### Step 1 — 准备（同步 + 解析路径）

解析命令意图：

1. **主题**（topic）：命令未给则从会话上下文归纳，并向用户确认一次。
2. **项目**（project）：显式 `项目=xxx` 优先；否则取 **触发时刻 Claude Code 工作目录的 basename**；`$AGENT_PAGES_DEFAULT_PROJECT` 非空时用它。
3. **slug**：从主题提炼，kebab-case、英文为主、简短可识别。

然后调用脚本（它会同步仓库、用**系统时钟**取当天日期、解析并去重目标路径，输出 JSON）：

```bash
. "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/agent-pages/config.env"
PROJECT="${PROJECT:-${AGENT_PAGES_DEFAULT_PROJECT:-$(basename "$PWD")}}"
"$AGENT_PAGES_GALLERY_PATH/scripts/new-page.sh" --project "$PROJECT" --slug "<slug>"
```

从返回 JSON 读取 `targetPath` / `relPath` / `dateHuman` / `isNewProject`。

- `isNewProject=true` 且用户没显式 `项目=xxx` → 告知"将新建项目目录 <project>"。
- 不要自己用 LLM 记忆里的日期，一切以脚本返回的 `date`/`dateHuman` 为准。

### Step 2 — 评估内容充分性

判断上下文能否支撑一份"可读、可分享"的精华页面。素材稀薄（只有一个主题名）时**先问用户**：

- `A` — 用户补充资料（贴文档、链接、要点）
- `B` — 授权使用 WebSearch / WebFetch 联网调研
- `C` — 由你基于已有知识生成大纲版本，标注 `TODO` 待补

**不要在素材稀薄时硬写**，否则页面会沦为"占位符 H5"。

### Step 3 — 设计与构建 HTML

> **⚠️ 每次都从零设计，不要参考历史页面**
>
> - **禁止** 读取画廊里的 `index.html` 或任何 `<项目>/*.html` 去"借鉴"主题/配色/版式/组件/动效/DOM 结构。
> - **禁止** 沿用上一次会话刚生成的风格——哪怕主题相近。
> - 每次都基于当前主题**独立、原创**地推导设计语言：主题决定情绪，情绪决定配色/字体/版式/动效。
> - 不小心瞄到旧页面，立刻清空印象，按本次主题重新设计。

**设计增强 Skill（按检测结果依次使用）**：

1. 若本会话已加载 `/ui-ux-pro-max:ui-ux-pro-max`，先调用它获取整体设计方向、配色、版式、组件、动效和字体建议。
2. 若可检测到 `design-taste-frontend`，再调用它做 anti-slop 设计读法、审美方向校准和前置质量检查。
3. 若可检测到 `frontend-design`，再调用它强化差异化视觉方向、细节完成度和避免通用 AI 页面。

没有检测到上述 Skill 时不要阻塞；仍然必须按下面的页面质量基线从主题出发独立设计。

页面质量基线（**硬要求**，全满足才算合格）：

1. **结构清晰**：明确的 hero、章节分层、TOC（适用时）、footer。
   - **导航**：长内容/多章节页面**不要**把所有锚点塞进顶部 Navbar（移动端必塌）。改用**侧边栏目录**（desktop 常驻 / mobile 抽屉），点击平滑滚动 + 当前章节高亮（IntersectionObserver）。短页面（≤3 节）可省侧栏。
2. **化繁为简，由浅入深**：先给一句话结论，再展开"是什么 → 为什么 → 怎么用 → 边界"。
3. **图形化表达**：能用图就别只用字 —— SVG/Canvas/CSS art、`<table>` 对比矩阵、时间线/流程图/雷达图；必要时 Mermaid 或 Chart.js（CDN）。
4. **动效**：合理的 CSS transition / scroll-driven / IntersectionObserver 入场动画，动效服务阅读节奏，**禁止**满屏花哨。
5. **UI/UE**：
   - 字体：英文 Inter / IBM Plex / JetBrains Mono；中文 system stack 或 Noto Sans SC（按需 CDN）。
   - 配色：2-3 个语义色 token + neutral 灰阶，避免随手 `#fff`/`#000`。
   - 间距：一致的 spacing scale（4/8/16/24/32/48/64）。
   - **响应式（硬要求）**：**桌面优先**，向下适配 1440 / 1024 / 768 / 375 四档不破版；用 `clamp()`/`minmax()`/`auto-fit` 平滑过渡；移动端触控目标 ≥ 44×44px；图表/表格窄屏给降级方案（横向滚动/卡片化）；至少在 375 宽跑一遍确认无横向滚动。
   - 暗色模式：优先 `prefers-color-scheme`；做不到也要保证日间模式精致。
6. **可独立运行**：单文件 HTML（CSS/JS 内联或全走 CDN），双击即可打开，外链用稳定 CDN（jsDelivr/unpkg/Google Fonts）。
7. **无障碍最低线**：语义化标签（`<header>` `<main>` `<section>` `<article>`）、对比度足够、图像有 alt。
8. **标题克制**：HTML `<title>` 用短标题，建议中文 ≤ 18 个字、英文 ≤ 60 个字符；只写核心主题，不塞副标题、营销句、长解释或多段分隔符。

代码风格：注释/class/变量名用 English，正文文案用中文（除非主题本身是英文内容），不要中英混杂的标识符，不要无意义 placeholder。

用 `Write` 把页面写到 Step 1 返回的 `targetPath`。

### Step 4 — 发布（登记 gallery.json + commit + push + 打开）

页面写好后调用 `publish.sh`，它会：把条目登记进画廊 `gallery.json`（包含页面列表与标签，首页从该 JSON 渲染左侧标签筛选和年份列表）、**只** commit 页面 + `index.html` + `gallery.json`、push（失败自动 rebase 重试一次）、本地 `open`。

发布时必须给页面标签：

- `publish.sh` 会自动加入项目名作为标签。
- 根据主题额外提炼 1-4 个短标签，中文/英文均可，但同一画廊内尽量保持命名一致。
- 用逗号分隔传给 `--tags`，例如 `"React,Server Components,架构"`。

```bash
. "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/agent-pages/config.env"
"$AGENT_PAGES_GALLERY_PATH/scripts/publish.sh" \
  --project "<project>" \
  --file "<relPath 或 targetPath>" \
  --title "<人读得懂的中文/英文标题>" \
  --date "<dateHuman, YYYY-MM-DD>" \
  --tags "<tag1,tag2,tag3>"
```

- `--title` 用页面 `<title>` 的人读短标题，**不要**直接塞英文 slug，也不要超过标题长度约束。
- 从返回 JSON 读 `commit` / `liveUrl` / `pushStatus` / `indexStatus`。
- `pushStatus=push-failed` → 告知用户远端冲突，提示手动处理，不要反复硬推。

**校验**：发布后 `Read` 一遍画廊 `gallery.json`，确认新条目在 `entries` 顶部附近、`href` 相对路径可达、`tags` 包含项目名与主题标签；必要时再打开 `index.html` 确认标签筛选能显示。

### Step 5 — 报告

给用户简短反馈：

- 本地路径（`file://...` 形式）+ `liveUrl`（若配置了 `AGENT_PAGES_SITE_BASE_URL`）
- "已登记到 gallery.json，可在首页按标签筛选"
- commit SHA
- 页面亮点 1-2 条（用了什么图示/动效）
- 已知 TODO（如有）

## 续写模式

`/agent-pages 续写 <已有文件名>`：

1. 在 `$AGENT_PAGES_GALLERY_PATH` 下 `find` 该文件（模糊匹配 slug）。
2. 多结果 → 列给用户选。
3. `Read` 原文，用 `Edit` 增量修改；保持原页面设计语言（配色/字体/间距 token），不要风格漂移。
4. 重新发布时加 `--no-index`（续写通常不新增索引条目）：
   ```bash
   "$AGENT_PAGES_GALLERY_PATH/scripts/publish.sh" --project "<p>" --file "<file>" \
     --title "<title>" --date "<原日期>" --no-index --message "feat(<p>): update <slug> - <what changed>"
   ```
   `publish.sh --no-index` 不会修改 `gallery.json`。若续写改了页面标题或标签，保留 `--no-index` 完成页面更新后，再手动维护 `gallery.json` 中对应条目的 `title` / `tags`。

## 反模式 / 不要做的事

- ❌ **参考画廊里 `index.html` 或任何历史页面的主题/配色/字体/版式/动效**——每次从主题出发独立设计。
- ❌ 用户没说 `/agent-pages` 就自动造页面。
- ❌ 素材稀薄就硬写，通篇 `<p>TODO</p>`。
- ❌ 自作主张联网调研（必须先问授权）。
- ❌ 套通用 "AI landing page" 模板（hero + 3 列 feature + CTA）。
- ❌ 用 `<div>` 堆整个页面（语义化标签是底线）。
- ❌ 引入大量本地依赖文件（必须单文件 + CDN）。
- ❌ 用 LLM 记忆里的"今天日期"（一律用 `new-page.sh` 返回的日期）。
- ❌ 把仓库路径写死（一律读 `config.env`）。
- ❌ 绕过 `publish.sh` 手动 `git add -A`（会带进无关改动；脚本只 add 页面 + index + gallery.json）。

## 约束优先级（继承全局）

显式规则 > 正确性 > 业务边界 > 可维护性 > 性能 > 简洁。

本 skill 里"正确性"的含义是：**页面内容不能虚构**。涉及外部事实（版本号、API 签名、人物、数据）不确定就标 `TODO` 或停下问用户，宁可留白也不要发布错误信息。

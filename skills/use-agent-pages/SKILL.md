---
name: use-agent-pages
description: agent-pages 的引导纲要（bootstrap doctrine）。会话开始时自动注入，用以说明 /agent-pages 的入口、何时建议它、以及生成页面时的硬约束。在真正开始写页面 / 发布之前，先按本文挑入口；完整工作流见 agent-pages:agent-pages skill。
---

# Using agent-pages

agent-pages 把当前会话中的主题/资料生成为一份**独立可浏览的单文件 HTML 页面**（结构清晰、化繁为简、由浅入深，重图形/表格/动效与精致 UI/UE），并发布到用户的「画廊」仓库（fork 的 agent-pages repo，同时部署到 GitHub Pages）。

本文档只负责**入口判断**——告诉你何时该用、何时只是建议、以及不可逾越的红线。具体的「准备 → 评估素材 → 从零设计 → 发布 → 校验」执行链路在 `agent-pages:agent-pages` skill 里，进入流程后以它为准。

## 入口（何时进入流程）

正常入口是用户输入以 `/agent-pages` 开头的命令：

| 命令 | 含义 |
|---|---|
| `/agent-pages <主题>` | 用该主题生成页面（分类由助手从固定分类集里推断） |
| `/agent-pages 分类=<slug> <主题>` | 显式指定画廊分类（页面落到 `<slug>/` 目录下） |
| `/agent-pages 续写 <已有文件名>` | 在已有页面上迭代/补充 |

收到上述命令，即调用 `agent-pages:agent-pages` skill 按其工作流执行。

## 何时**建议**（不要直接动手）

当用户的请求**做成一份自包含 HTML 工件，会比一长段 Markdown 更清楚**时，先用一两句话建议 `/agent-pages <主题>`，并询问是否采用——**不要**未经确认就开始写文件/发布。典型适合场景：

- 并排对比的探索 / 方案规划、带注解的代码评审
- 设计系统 / 组件变体、交互原型、图示与调研地图
- 幻灯片/报告式表达、事故/状态/PR 复盘、小型自定义评审/编辑 UI

**不要**为以下场景建议：快速问答、简短解释、常规小改、或用户明显只想要纯文本。

## 硬约束（红线）

- **不自动造页面**：用户没用 `/agent-pages` 也没确认，就不要写文件、不要发布。
- **不虚构**：涉及外部事实（版本号、API、人物、数据）不确定时标 `TODO` 或停下问，宁可留白也不发布错误信息；素材稀薄先问用户（补料 / 授权联网 / 出大纲版），不要硬写成占位符页面。
- **每次从零设计**：禁止读画廊里 `index.html` 或任何历史页面去「借鉴」配色/版式/动效；主题决定设计语言。
- **按分类组织**：页面落在 `<category>/<yyyyMMdd>-<slug>.html`；`category` 必须是 `gallery.json.categories` 里的 `slug`（没有「项目」概念了）。难归类才用 `other`，不要擅自造新分类。
- **日期以脚本为准**：用 `new-page.sh` 返回的日期，不要用 LLM 记忆里的「今天」。
- **路径不硬编码**：画廊路径、远端、站点 URL 一律读 `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/agent-pages/config.env`；该文件不存在说明尚未配置，提示用户在画廊 clone 里运行 `./scripts/install.sh`。
- **发布只用 publish.sh**：不要在画廊里 `git add -A`；脚本只会 stage 页面 + `index.html` + `gallery.json`。

## 配置与脚本在哪

- 运行时配置：`config.env`（`AGENT_PAGES_GALLERY_PATH` / `AGENT_PAGES_REMOTE` / `AGENT_PAGES_BRANCH` / `AGENT_PAGES_SITE_BASE_URL` / `AGENT_PAGES_GALLERY_NAME`）。由 `install.sh` 写入，可手改。
- 确定性脚本在画廊里：`$AGENT_PAGES_GALLERY_PATH/scripts/`（`new-page.sh` 同步+算路径、`publish.sh` 登记+commit+push+打开、`sync-upstream.sh` 拉模板更新）。
- 本插件（agent-pages）只分发能力：`agent-pages:agent-pages` 工作流 skill、`use-agent-pages` 本文、以及注入本文的 session-start hook。画廊数据与运行时配置始终在用户的 fork clone 里。

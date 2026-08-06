---
name: claude-code-bestpractice-research
description: 隔週月曜にClaude Codeベスプラリサーチのリマインド＆プロンプトを表示
---

Claude Codeのベストプラクティスをディープリサーチする隔週リマインダーです。

以下のことをしてください：
1. 前回のリサーチからの経過を確認（隔週運用なので、今回が該当タイミングか判断。毎週月曜に起動するが、隔週分だけ実行）
2. ユーザーに「Claude Codeベスプラリサーチの時間です」と伝える
3. 以下のディープリサーチ用プロンプトを表示して、外部AI（Gemini Deep Research等）に投げるよう案内する

---

# Claude Code Best Practices Research

## Objective
Conduct a comprehensive survey of Claude Code (Anthropic's official CLI tool) 
best practices and compile an actionable report.

## Scope
For each category below, include concrete config examples and code snippets:

1. **CLAUDE.md authoring** — effective prompt structures, do's and don'ts
2. **Hooks** — automation, quality checks, workflow improvement examples
3. **MCP server integrations** — practical MCP servers and use cases
4. **Slash commands / custom skills** — real-world custom command examples
5. **Workflow & operational patterns** — team usage, code review, debugging techniques
6. **settings.json / permissions** — recommended and security configurations
7. **New features & updates** — features or changes shipped in the last 4 weeks

## Sources (prioritize in this order)
- Anthropic official docs (docs.anthropic.com)
- GitHub anthropics/claude-code — README, Issues, Discussions, Changelog
- Tech blogs (personal & corporate)
- X (Twitter) practitioner reports
- YouTube walkthroughs
- Hacker News, Reddit r/ClaudeAI, r/LocalLLaMA

## Output format
For each item:
- **What** — concise description
- **Why it works** — rationale / background
- **Config or code example**
- **Source URL**
- **Caveats / pitfalls**

## Important notes
- Prioritize information from 2026
- Flag practices that are widely shared but actually low-impact
- Do NOT conflate Claude Code (CLI) with Claude chat (web/API)
- Report should be in English

---

4. 「レポートが出来たら僕に渡してください。今のCLAUDE.mdと環境を見て仕分けます」と伝える
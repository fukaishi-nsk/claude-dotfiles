#!/usr/bin/env bash
# Ask Grok or Gemini to do WEB / SNS RESEARCH through their official CLIs (subscription login, no API keys).
# The shared clients.py entry is for one-shot questions only (Grok: no web search, 1 turn; Gemini: plan mode,
# 150 s), so research requests fail there. These are the settings verified on PUKAISHI_WIN on 2026-10-18.
#
# Usage:  scripts/ai_research.sh grok|gemini <prompt file> [timeout minutes, default 14]
# Prints the answer on stdout. Runs in an empty scratch folder; no shell commands or file edits are allowed:
#  - Grok: --permission-mode plan (read-only), web + X search enabled (the default when not disabled).
#  - Gemini (agy): needs "permissions": {"allow": ["read_url(*)"]} in ~/.gemini/antigravity-cli/settings.json
#    (set by the owner on 2026-10-18). Commands stay "ask" and are auto-denied in headless mode.
#    agy -p prints plain text; tell it in the prompt not to use shell commands.
#    Broad research prompts can hit --print-timeout with an EMPTY answer (14 min, 2026-10-18): cap the number
#    of searches/page fetches in the prompt (e.g. "10 at most, then write the answer") and give 25 minutes.
#
# Mac (2026-10-19, Mac mini): agy is ~/.local/bin/agy and needs the same read_url allow-rule in its own
#   ~/.gemini/antigravity-cli/settings.json (without it, agy prints NOTHING and the reason is only on stderr).
#   Always pass --model: agy's default model is not necessarily Gemini (the list also has Claude / GPT-OSS).
#   There is no Grok CLI on the Mac: ask Grok through the grok MCP (mcp__grok__ask_grok, web+X search) instead.
#   macOS has no `timeout`; the script then relies on --print-timeout only.
set -euo pipefail
provider="${1:?grok|gemini}"; prompt_file="${2:?prompt file}"; minutes="${3:-14}"
prompt="$(cat "$prompt_file")"
unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_OAUTH_TOKEN GEMINI_API_KEY GOOGLE_API_KEY XAI_API_KEY OPENROUTER_API_KEY
ws="$(mktemp -d)"; trap 'rm -rf "$ws"' EXIT; cd "$ws"
limit() { if command -v timeout >/dev/null; then timeout "$((minutes * 60 + 60))" "$@"; else "$@"; fi; }
first_exe() { for p in "$@"; do [ -x "$p" ] && { echo "$p"; return; }; done; return 1; }
case "$provider" in
  grok)
    grok_exe="$(first_exe "$HOME/.grok/bin/grok.exe" "$HOME/.grok/bin/grok")" \
      || { echo "no Grok CLI here (Mac: use the grok MCP)" >&2; exit 3; }
    limit "$grok_exe" --no-subagents --permission-mode plan \
      --max-turns 40 --output-format json -p "$prompt" < /dev/null \
      | "$(command -v python || command -v python3)" -I -X utf8 -c "import json,sys; d=json.load(sys.stdin); print(d.get('text') or d)"
    ;;
  gemini)
    agy_exe="$(first_exe "$HOME/AppData/Local/agy/bin/agy.exe" "$HOME/.local/bin/agy")" \
      || { echo "agy not found" >&2; exit 3; }
    limit "$agy_exe" --model gemini-4-argon-medium \
      --print-timeout "${minutes}m" --print "シェルコマンドやファイル操作は使わず、ウェブ検索とページ取得だけで調べ、最後まで回答を書き切ること。

$prompt" < /dev/null
    ;;
  *) echo "unknown provider: $provider" >&2; exit 2 ;;
esac

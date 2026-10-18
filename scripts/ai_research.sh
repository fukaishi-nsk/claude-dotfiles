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
set -euo pipefail
provider="${1:?grok|gemini}"; prompt_file="${2:?prompt file}"; minutes="${3:-14}"
prompt="$(cat "$prompt_file")"
unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_OAUTH_TOKEN GEMINI_API_KEY GOOGLE_API_KEY XAI_API_KEY OPENROUTER_API_KEY
ws="$(mktemp -d)"; trap 'rm -rf "$ws"' EXIT; cd "$ws"
case "$provider" in
  grok)
    timeout "$((minutes * 60 + 60))" "$HOME/.grok/bin/grok.exe" --no-subagents --permission-mode plan \
      --max-turns 40 --output-format json -p "$prompt" < /dev/null \
      | python -I -X utf8 -c "import json,sys; d=json.load(sys.stdin); print(d.get('text') or d)"
    ;;
  gemini)
    timeout "$((minutes * 60 + 60))" "$HOME/AppData/Local/agy/bin/agy.exe" --model gemini-4-argon-medium \
      --print-timeout "${minutes}m" --print "シェルコマンドやファイル操作は使わず、ウェブ検索とページ取得だけで調べ、最後まで回答を書き切ること。

$prompt" < /dev/null
    ;;
  *) echo "unknown provider: $provider" >&2; exit 2 ;;
esac

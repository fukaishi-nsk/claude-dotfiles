# nsk-buddy 共通部品（buddy-check.sh / restart-macmini.sh から source する）
# 置き場所: ~/.nsk-buddy/（ログ・状態・Slack Webhook URL。git 管理外）

STATE_DIR="$HOME/.nsk-buddy"
mkdir -p "$STATE_DIR"
LOG="$STATE_DIR/buddy.log"
WEBHOOK_FILE="$STATE_DIR/slack_webhook_url"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [${TARGET:-?}] $*" >> "$LOG"; }

# Slack に投稿する。Webhook 未設定ならログに残すだけ
notify() {
  local url payload
  url=""; [ -f "$WEBHOOK_FILE" ] && url=$(tr -d '\r\n ' < "$WEBHOOK_FILE")
  if [ -z "$url" ]; then log "notify skipped (no webhook): $(printf '%s' "$1" | head -1)"; return 0; fi
  payload=$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk 'BEGIN{ORS="\\n"}{print}')
  # 本文は標準入力で渡す。3090 の curl は Windows 版で、引数の日本語が Shift-JIS に変換されて化けるため
  if printf '{"text":"%s"}' "$payload" |
     curl -s -m 15 -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json; charset=utf-8' \
       --data-binary @- "$url" | grep -q '^200$'; then
    log "notified: $(printf '%s' "$1" | head -1)"
  else
    log "notify FAILED: $(printf '%s' "$1" | head -1)"
  fi
}

# 監視先ごとの設定
set_target() {
  case "$1" in
    macmini)
      NAME="Mac mini"; HELPER="3090"; SKILL="macmini-recover" ;;
    3090)
      NAME="3090"; HELPER="Mac mini"; SKILL="nsk3090-recover" ;;
    *) echo "usage: $0 macmini|3090" >&2; exit 2 ;;
  esac
}

# 相手の状態を key=value で取る（読み取りのみ）。SSH 不通なら何も出さず非0
probe() {
  local dir; dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  case "$TARGET" in
    macmini)
      tr -d '\r' < "$dir/probe-macmini.sh" | ssh -o BatchMode=yes -o ConnectTimeout=10 macmini 'bash -s' 2>/dev/null ;;
    3090)
      # IP は LAN の差し口で .26 / .24 に変わる
      ssh -o BatchMode=yes -o ConnectTimeout=10 Host3090 'powershell -NoProfile -NonInteractive -Command -' < "$dir/probe-3090.ps1" 2>/dev/null ||
      ssh -o BatchMode=yes -o ConnectTimeout=10 -o HostName=192.168.10.24 Host3090 'powershell -NoProfile -NonInteractive -Command -' < "$dir/probe-3090.ps1" 2>/dev/null ;;
  esac
}

#!/bin/bash
# 月1回（毎月1日 04:00）、3090 から Mac mini を再起動する。macOS を 49.7 日つけっぱなしにすると
# TIME_WAIT が消えなくなって TCP が詰まる不具合の予防（2026-10-19 深石さん決定）。結果は Slack に知らせる。
# タスクスケジューラーは毎日 04:00 に起動し、1日以外は何もしない。手動で試すときは --force。
set -u
TARGET=macmini
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/buddy-lib.sh"
set_target macmini

if [ "${1:-}" != "--force" ] && [ "$(date +%d)" != "01" ]; then exit 0; fi

SSH="ssh -o BatchMode=yes -o ConnectTimeout=10 macmini"
MARK="$STATE_DIR/macmini.restarting"
boottime() { $SSH 'sysctl -n kern.boottime' 2>/dev/null | awk '{print $4}' | tr -d ,; }

before=$(boottime)
if [ -z "$before" ]; then
  log "monthly restart: SSH unreachable, skipped"
  notify ":rotating_light: *Mac mini* の月次再起動ができませんでした（3090 から SSH がつながらない）。電源・LAN を確認してください。"
  exit 1
fi

touch "$MARK"
log "monthly restart: requesting (boot=$before)"
$SSH 'nohup osascript -e "tell application \"System Events\" to restart" >/tmp/nsk-buddy-restart.log 2>&1 &' >/dev/null 2>&1

after=""
for i in $(seq 1 45); do        # 最大15分待つ
  sleep 20
  touch "$MARK"
  now=$(boottime)
  if [ -n "$now" ] && [ "$now" != "$before" ]; then after=$now; break; fi
done

if [ -z "$after" ]; then
  rm -f "$MARK"
  if [ -n "$(boottime)" ]; then
    log "monthly restart: did not restart (still up)"
    notify ":warning: *Mac mini* の月次再起動が完了しませんでした（起動したまま）。アプリの「保存しますか？」等で止まっている可能性があります。3090 の Claude に「Mac miniを直して」と頼むか、Parsec で確認してください。"
  else
    log "monthly restart: not back after 15 min"
    notify ":rotating_light: *Mac mini* が月次再起動のあと15分たっても戻ってきません。電源・LAN を確認してください。"
  fi
  exit 1
fi

sleep 120                       # Parsec・Sunshine の自動起動を待つ
rm -f "$MARK"
log "monthly restart: back (boot=$after)"
notify ":arrows_counterclockwise: *Mac mini* を月次再起動しました（$(date -d "@$after" '+%m/%d %H:%M' 2>/dev/null || date -r "$after" '+%m/%d %H:%M') 起動）。このあと通常の見守りで状態を確認します。"
bash "$DIR/buddy-check.sh" macmini

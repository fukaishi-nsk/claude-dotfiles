#!/bin/bash
# notta-inbox-datestamp を launchd に登録する（Mac miniで実行する想定）
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
INBOX="$HOME/Library/CloudStorage/GoogleDrive-fukaishi@nsketch.com/My Drive/Notta_Inbox"
STATE="$HOME/.notta-inbox-datestamp-installed"
PLIST_DST="$HOME/Library/LaunchAgents/com.nsketch.notta-inbox-datestamp.plist"

if [ ! -d "$INBOX" ]; then
  echo "ERROR: Notta_Inbox が見つかりません: $INBOX"
  echo "Google Drive for desktop に fukaishi@nsketch.com でログインしているか確認してください"
  exit 1
fi

# 導入時刻を記録（これ以前のmtimeを持つ既存ファイルはリネーム対象外になる）
if [ ! -f "$STATE" ]; then
  date +%s > "$STATE"
  echo "state created: $STATE ($(cat "$STATE"))"
else
  echo "state exists: $STATE ($(cat "$STATE")) — 既存の基準時刻を維持します"
fi

chmod +x "$DIR/datestamp.sh"
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
sed "s|__HOME__|$HOME|g" "$DIR/com.nsketch.notta-inbox-datestamp.plist.template" > "$PLIST_DST"

launchctl unload "$PLIST_DST" 2>/dev/null || true
launchctl load "$PLIST_DST"
echo "installed & loaded: $PLIST_DST"
echo "log: $HOME/Library/Logs/notta-inbox-datestamp.log"

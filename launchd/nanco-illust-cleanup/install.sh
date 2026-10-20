#!/bin/bash
# nanco-illust-cleanup を launchd に登録する（Mac mini だけ。nanco-illust は Mac mini でしか動かない）
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST_DST="$HOME/Library/LaunchAgents/com.nsketch.nanco-illust-cleanup.plist"
[ -d "$HOME/src/nanco_illust/generated" ] || { echo "ERROR: ~/src/nanco_illust/generated がありません（Mac mini 以外では入れない）"; exit 1; }
chmod +x "$DIR/cleanup.sh"
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
sed "s|__HOME__|$HOME|g" "$DIR/com.nsketch.nanco-illust-cleanup.plist.template" > "$PLIST_DST"
launchctl unload "$PLIST_DST" 2>/dev/null || true
launchctl load "$PLIST_DST"
echo "installed & loaded: $PLIST_DST（毎日 4:30）"
echo "log: $HOME/Library/Logs/nanco-illust-cleanup.log"

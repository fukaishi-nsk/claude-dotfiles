#!/bin/bash
# rc-restart-on-update を launchd に登録する（Mac mini で実行する想定）
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST_DST="$HOME/Library/LaunchAgents/com.nsketch.rc-restart-on-update.plist"

chmod +x "$DIR/check.sh"
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
sed "s|__HOME__|$HOME|g" "$DIR/com.nsketch.rc-restart-on-update.plist.template" > "$PLIST_DST"

launchctl unload "$PLIST_DST" 2>/dev/null || true
launchctl load "$PLIST_DST"
echo "installed & loaded: $PLIST_DST"
echo "log: $HOME/Library/Logs/rc-restart-on-update.log"

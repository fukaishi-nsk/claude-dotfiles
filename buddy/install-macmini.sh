#!/bin/bash
# Mac mini に「30分ごとに 3090 を見る」launchd ジョブを登録する（Mac mini で実行）
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
LABEL=com.nsketch.nsk-buddy.check-3090
DST="$HOME/Library/LaunchAgents/$LABEL.plist"
mkdir -p "$HOME/.nsk-buddy" "$HOME/Library/LaunchAgents"
chmod +x "$DIR/buddy-check.sh"
sed "s|__HOME__|$HOME|g" "$DIR/$LABEL.plist.template" > "$DST"
launchctl unload "$DST" 2>/dev/null || true
launchctl load "$DST"
echo "loaded: $DST"
[ -s "$HOME/.nsk-buddy/slack_webhook_url" ] || echo "NOTE: ~/.nsk-buddy/slack_webhook_url がまだ無いので、通知はログ（~/.nsk-buddy/buddy.log）に残るだけです"

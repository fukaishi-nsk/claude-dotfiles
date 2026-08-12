#!/bin/bash
# Notta_Inbox の新着ファイルに YYMMDD_ プレフィックスを付与する（Mac mini常駐用）
# - 対象: 導入時刻(STATEファイル)以降のmtimeを持つファイルのみ（既存ファイルは触らない）
# - パス1: 拡張子なしファイルに .txt を付与（Zap側修正の保険）
# - パス2: 先頭が6桁数字+_ でない .txt に mtime由来の YYMMDD_ を付与
# - 制約: mtime=Drive着弾時刻ベースのため、長時間録音の翌日処理では会議日と1日ズレることがある
#   （仕分け時にClaudeが会議文脈で補正する運用。notta-checkスキル参照）
set -u

INBOX="$HOME/Library/CloudStorage/GoogleDrive-fukaishi@nsketch.com/My Drive/Notta_Inbox"
STATE="$HOME/.notta-inbox-datestamp-installed"
LOG="$HOME/Library/Logs/notta-inbox-datestamp.log"

[ -d "$INBOX" ] || exit 0
[ -f "$STATE" ] || exit 0
installed_at=$(cat "$STATE")
case "$installed_at" in ''|*[!0-9]*) exit 0 ;; esac

cd "$INBOX" || exit 0

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"; }

# パス1: 拡張子なし → .txt（末尾空白は除去）
for f in *; do
  [ -f "$f" ] || continue
  case "$f" in *.*) continue ;; esac
  mtime=$(stat -f %m "$f" 2>/dev/null) || continue
  [ "$mtime" -ge "$installed_at" ] || continue
  trimmed=$(printf '%s' "$f" | sed -e 's/[[:space:]]*$//')
  target="${trimmed}.txt"
  [ -e "$target" ] && continue
  mv -n "$f" "$target" && log "ext: $f -> $target"
done

# パス2: 日付プレフィックスなしの .txt → YYMMDD_ を前置
for f in *.txt; do
  [ -f "$f" ] || continue
  case "$f" in
    [0-9][0-9][0-9][0-9][0-9][0-9]_*) continue ;;
  esac
  mtime=$(stat -f %m "$f" 2>/dev/null) || continue
  [ "$mtime" -ge "$installed_at" ] || continue
  prefix=$(date -r "$mtime" +%y%m%d)
  target="${prefix}_${f}"
  [ -e "$target" ] && continue
  mv -n "$f" "$target" && log "date: $f -> $target"
done

exit 0

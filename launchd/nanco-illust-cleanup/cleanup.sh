#!/bin/bash
# nanco-illust の生成フォルダ（~/src/nanco_illust/generated/ 直下のフォルダ）のうち、
# 30日より古いものを Mac のゴミ箱（~/.Trash）へ移す。完全には消さない（ゴミ箱を空にするまで戻せる）。
# 古さは、フォルダ名が「YYYYMMDD_」で始まればその日付、それ以外はフォルダの更新日時で判定する。
# generated/ 直下のファイル（fal_usage.csv・比較画像など）には触らない。
# 使い方: cleanup.sh [--dry-run]   （DAYS=日数 で日数を変えられる）
set -uo pipefail
GEN="${GEN:-$HOME/src/nanco_illust/generated}"
DAYS="${DAYS:-30}"
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
TRASH="$HOME/.Trash"
now=$(date +%s); limit=$(( now - DAYS*86400 )); stamp=$(date +%Y%m%d-%H%M%S)
[ -d "$GEN" ] || { echo "$(date '+%F %T') ERROR: $GEN がありません"; exit 1; }
moved=0; kept=0
for d in "$GEN"/*/; do
  [ -d "$d" ] || continue
  name=$(basename "$d")
  if [[ "$name" =~ ^([0-9]{8})_ ]]; then
    t=$(date -j -f %Y%m%d%H%M%S "${BASH_REMATCH[1]}000000" +%s 2>/dev/null) || t=$(stat -f %m "$d")
  else
    t=$(stat -f %m "$d")
  fi
  if [ "$t" -lt "$limit" ]; then
    dst="$TRASH/$name"; [ -e "$dst" ] && dst="$TRASH/${name}_$stamp"
    if [ $DRY -eq 1 ]; then echo "would trash: $name"; else
      if mv "$d" "$dst"; then echo "$(date '+%F %T') trashed: $name"; else echo "$(date '+%F %T') ERROR: mv 失敗 $name"; fi
    fi
    moved=$((moved+1))
  else
    kept=$((kept+1))
  fi
done
echo "$(date '+%F %T') done: ${moved} 件をゴミ箱へ$([ $DRY -eq 1 ] && echo '（dry-run）')・${kept} 件は残した（${DAYS}日以内）"

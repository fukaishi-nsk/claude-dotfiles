#!/bin/bash
# claude の更新後、旧版のまま動いている claude remote-control を再起動する（Mac mini 用）。
# launchd（com.nsketch.rc-restart-on-update）から10分ごとに呼ばれる。手でも叩ける:
#   bash ~/claude-dotfiles/launchd/rc-restart-on-update/check.sh          … 本番
#   bash ~/claude-dotfiles/launchd/rc-restart-on-update/check.sh --dry-run … 判定だけ出す（再起動しない）
#
# 決まり（2026-11-26 深石さん「入れて」）:
#   ・旧版判定 = remote-control の起動時刻が claude-code の package.json の更新時刻より前
#     （11/26 実例: 11/20 起動の親が 07:35 の更新後も旧版のまま → 新セッションが EPERM で5連続失敗）
#   ・更新から3分以内は触らない（npm の入れ替え途中のことがある）
#   ・作業中のセッションがある時は見送り、次の回（10分後）にまた見る
#     作業中 = remote-control 配下の全プロセスの CPU 時間が 20 秒間で 2 秒以上増えた
#   ・再起動は launchctl kickstart -k。セッションの環境は残り、次のメッセージで再開する
#   ・ついでに remote-control のログが 100MB を超えていたら末尾 10MB だけ .old に残して空にする
#     （画面の書き直しがそのまま記録され、11/26 時点で 2.6GB になっていた）
# ログ: ~/Library/Logs/rc-restart-on-update.log（何かした時・見送った時だけ書く）

export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export LC_ALL=C
DRY=0; [ "$1" = "--dry-run" ] && DRY=1

LABELS="com.nsketch.claude-remote-control.nanco com.fukaishi.claude-remote-control"
RC_LOGS="$HOME/Library/Logs/claude-remote-control-nanco.log"
PKG="/opt/homebrew/lib/node_modules/@anthropic-ai/claude-code/package.json"
BIN="/opt/homebrew/bin/claude"
UID_N=$(id -u)

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

descendants() {  # pid とその子孫すべて
  local p c
  for p in "$@"; do
    echo "$p"
    for c in $(pgrep -P "$p"); do descendants "$c"; done
  done
}

cpu_sum() {  # 子孫全体の CPU 時間（秒・小数切り捨て）
  local pids
  pids=$(descendants "$1" | tr '\n' ',' | sed 's/,$//')
  [ -n "$pids" ] || { echo 0; return; }
  ps -o time= -p "$pids" 2>/dev/null | awk -F: '
    { s=0; for (i=1;i<=NF;i++) s = s*60 + $i; t += s }
    END { printf "%d\n", t }'
}

# --- ログの肥大対策 ---
for f in $RC_LOGS; do
  [ -f "$f" ] || continue
  size=$(stat -f %z "$f")
  if [ "$size" -gt 104857600 ]; then
    if [ "$DRY" = 1 ]; then log "（dry-run）ログを切り詰める予定: $f ($((size/1048576))MB)"
    else
      tail -c 10485760 "$f" > "$f.old" && : > "$f"
      log "ログを切り詰めた: $f ($((size/1048576))MB → 末尾10MBを .old へ)"
    fi
  fi
done

# --- 旧版の remote-control を再起動 ---
[ -f "$PKG" ] || exit 0
pkg_t=$(stat -f %m "$PKG")
now=$(date +%s)
[ $((now - pkg_t)) -ge 180 ] || exit 0              # 更新直後は待つ
"$BIN" --version >/dev/null 2>&1 || { log "見送り: $BIN --version が通らない（更新途中の可能性）"; exit 0; }
new_ver=$("$BIN" --version 2>/dev/null | grep -Eo '[0-9]+(\.[0-9]+)+' | head -1)

for label in $LABELS; do
  pid=$(launchctl list "$label" 2>/dev/null | awk -F'= ' '/"PID"/ {gsub(/;/,"",$2); print $2}')
  [ -n "$pid" ] || continue
  st=$(ps -o lstart= -p "$pid" 2>/dev/null)
  [ -n "$st" ] || continue
  st_t=$(date -j -f "%a %b %d %T %Y" "$st" +%s 2>/dev/null) || continue
  [ "$st_t" -lt "$pkg_t" ] || continue               # 新版で動いている

  c0=$(cpu_sum "$pid"); sleep 20; c1=$(cpu_sum "$pid")
  if [ $((c1 - c0)) -ge 2 ]; then
    log "見送り: $label（pid $pid・$(date -r "$st_t" '+%m/%d %H:%M') 起動）は旧版だが作業中（20秒でCPU $((c1 - c0))秒）。次の回にまた見る"
    continue
  fi
  if [ "$DRY" = 1 ]; then
    log "（dry-run）再起動する予定: $label（pid $pid・$(date -r "$st_t" '+%m/%d %H:%M') 起動 → $new_ver）"
    continue
  fi
  launchctl kickstart -k "gui/$UID_N/$label"
  sleep 5
  npid=$(launchctl list "$label" 2>/dev/null | awk -F'= ' '/"PID"/ {gsub(/;/,"",$2); print $2}')
  if [ -n "$npid" ] && [ "$npid" != "$pid" ]; then
    log "再起動: $label（旧 pid $pid・$(date -r "$st_t" '+%m/%d %H:%M') 起動 → 新 pid $npid・$new_ver）"
  else
    log "失敗: $label を再起動できなかった（pid ${npid:-なし}）"
  fi
done
exit 0

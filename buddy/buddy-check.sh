#!/bin/bash
# nsk-buddy: 会社に置いた Mac mini と 3090 が互いの様子を30分ごとに見て、異常を Slack に知らせる。
# 直すことはしない（知らせるだけ・2026-10-19 深石さん決定）。直すときは相手側の Claude に頼む。
#   Mac mini で: buddy-check.sh 3090     （3090 を見る）
#   3090 で:     buddy-check.sh macmini  （Mac mini を見る）
set -u
TARGET="${1:-}"
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/buddy-lib.sh"
set_target "$TARGET"

REMIND_SEC=$((6 * 3600))   # 異常が続く間は6時間ごとに再通知
STATE_FILE="$STATE_DIR/$TARGET.state"

# 月次再起動の最中は見ない（再起動中の不通で誤報しないため）
MARK="$STATE_DIR/$TARGET.restarting"
if [ -f "$MARK" ] && [ $(( $(date +%s) - $(date -r "$MARK" +%s 2>/dev/null || echo 0) )) -lt 1200 ]; then
  log "skip: restart in progress"; exit 0
fi

# 判定。結果は PROBLEMS（異常）と WARNINGS（注意）に1行ずつ入る
evaluate() {
  PROBLEMS=""; WARNINGS=""
  local out k v
  out=$(probe | tr -d '\r')
  if [ -z "$out" ]; then
    PROBLEMS="SSH がつながらない（電源断・固まり・LAN の不調の可能性）"; return
  fi
  local web="" tw=0 up=0 prun="" perr=0 sun="" psvc="" pd="" me="" disk=""
  while IFS='=' read -r k v; do
    case "$k" in
      web) web=$v ;; tw) tw=$v ;; uptime_days) up=$v ;;
      parsec_running) prun=$v ;; parsec_err_recent) perr=$v ;; sunshine_running) sun=$v ;;
      parsec_svc) psvc=$v ;; parsecd) pd=$v ;; me_age_min) me=$v ;; disk_free_gb) disk=$v ;;
    esac
  done <<< "$out"
  add() { if [ -z "$PROBLEMS" ]; then PROBLEMS="$1"; else PROBLEMS="$PROBLEMS"$'\n'"$1"; fi; }
  warn() { if [ -z "$WARNINGS" ]; then WARNINGS="$1"; else WARNINGS="$WARNINGS"$'\n'"$1"; fi; }

  [ "$web" = "200" ] || add "外への通信が失敗している（google の応答: ${web:-なし}）"
  [ "${tw:-0}" -gt 20000 ] 2>/dev/null && add "TIME_WAIT が ${tw} 件（TCP が詰まりかけ・詰まっている疑い）"
  case "$TARGET" in
    macmini)
      [ "$prun" = "1" ] || add "Parsec が起動していない"
      [ "${perr:-0}" -ge 5 ] 2>/dev/null && add "Parsec がサーバーに届いていない（error 17 が連続）"
      [ "${up:-0}" -ge 45 ] 2>/dev/null && warn "起動から ${up} 日（49.7 日で TCP が詰まる macOS の不具合あり。再起動推奨。月次再起動が失敗している可能性）"
      [ "$sun" = "1" ] || warn "Sunshine（Moonlight 用・Parsec の保険）が止まっている"
      ;;
    3090)
      [ "$psvc" = "Running" ] || add "Parsec サービスが動いていない（状態: ${psvc:-不明}）"
      [ "${me:--1}" -gt 150 ] 2>/dev/null && add "Parsec が ${me} 分間サーバーに届いていない"
      [ "${me:--1}" = "-1" ] && warn "Parsec のログからサーバー接続の記録を読めない"
      [ "${pd:-0}" = "0" ] && warn "parsecd が見当たらない（自動サインインできていない可能性）"
      [ "${disk:-999}" -lt 100 ] 2>/dev/null && warn "C ドライブの空きが ${disk} GB"
      ;;
  esac
}

evaluate
if [ -n "$PROBLEMS" ]; then   # 一時的な揺れで誤報しないよう、1分おいてもう一度見る
  sleep 60; evaluate
fi

if [ -n "$PROBLEMS" ]; then STATUS=NG; KEY="$PROBLEMS"
elif [ -n "$WARNINGS" ]; then STATUS=WARN; KEY="$WARNINGS"
else STATUS=OK; KEY=""; fi

PREV_STATUS=OK; PREV_KEY=""; PREV_AT=0
if [ -f "$STATE_FILE" ]; then
  PREV_STATUS=$(sed -n 1p "$STATE_FILE"); PREV_AT=$(sed -n 2p "$STATE_FILE"); PREV_KEY=$(sed -n '3,$p' "$STATE_FILE")
fi
NOW=$(date +%s); NOTIFIED_AT=$PREV_AT
STAMP=$(date '+%m/%d %H:%M')
bullets() { printf '%s\n' "$1" | sed 's/^/• /'; }

if [ "$STATUS" = OK ]; then
  if [ "$PREV_STATUS" = NG ]; then
    notify ":white_check_mark: *${NAME}* は正常に戻りました（${HELPER} が ${STAMP} に確認）"
  fi
  NOTIFIED_AT=0
elif [ "$STATUS" != "$PREV_STATUS" ] || [ "$KEY" != "$PREV_KEY" ] || [ $((NOW - PREV_AT)) -ge $REMIND_SEC ]; then
  if [ "$STATUS" = NG ]; then
    notify ":rotating_light: *${NAME}* に異常があります（${HELPER} が ${STAMP} に検知）
$(bullets "$PROBLEMS")$( [ -n "$WARNINGS" ] && printf '\n%s' "$(bullets "$WARNINGS")" )
直すときは ${HELPER} の Claude に「${NAME}を直して」と頼んでください（スキル ${SKILL}）。"
  else
    notify ":warning: *${NAME}* の注意点（${HELPER} が ${STAMP} に確認）
$(bullets "$WARNINGS")"
  fi
  NOTIFIED_AT=$NOW
fi

printf '%s\n%s\n%s\n' "$STATUS" "$NOTIFIED_AT" "$KEY" > "$STATE_FILE"
log "$STATUS $(printf '%s' "$KEY" | tr '\n' '/')"

#!/bin/bash
# Slackファイル原本のバッチ回収（slack-file-dlスキルの手順をスクリプト化・2026-09-08 島津第六回で24枚66MBを約1分で回収）
# 使い方:
#   slack_files_batch_dl.sh <Slackメッセージパーマリンク(/messages/形式)> <リストファイル> <出力ディレクトリ> [TEAM_ID(既定 T08ML4BM5)]
#   リストファイル: 1行1ファイル「FILE_ID<TAB>保存名<TAB>Slack上の元ファイル名(省略時 image.png)」
# 前提: 専用永続プロファイル ~/.agent-browser/profiles/gmail でSlackログイン済み
set -u
LINK="$1"; LIST="$2"; OUT="$3"; TEAM="${4:-T08ML4BM5}"
PROFILE="$HOME/.agent-browser/profiles/gmail"
S="$(mktemp -d)"; mkdir -p "$OUT"
AB() { agent-browser --profile "$PROFILE" "$@"; }
log() { echo "[$(date +%H:%M:%S)] $*"; }
HELPERS='window.__grab=function(u){return fetch(u,{credentials:"include"}).then(function(r){if(!r.ok)throw new Error("HTTP "+r.status);return r.arrayBuffer()}).then(function(a){window.__b=new Uint8Array(a);return window.__b.length})};window.__chunk=function(s,e){var b=window.__b.subarray(s,e);var t="";for(var i=0;i<b.length;i++)t+=String.fromCharCode(b[i]);return btoa(t)};"helpers-ok"'
log "open $LINK"; AB open "$LINK" 2>&1 | tail -1; sleep 10
HREF=$(AB eval "location.href" 2>&1 | tr -d '"'); log "landed: $HREF"
case "$HREF" in *app.slack.com/client*) ;; *) log "NOT on app.slack.com client (login?) -> abort"; exit 2;; esac
sleep 5; MODE=direct; n=0; ok=0
while IFS=$'\t' read -r FID NAME ORIG; do
  [ -z "${FID:-}" ] && continue; n=$((n+1)); ORIG="${ORIG:-image.png}"
  URL="https://files.slack.com/files-pri/$TEAM-$FID/$ORIG"
  log "== $n $FID -> $NAME (mode=$MODE)"; rm -f "$S"/p_*.b64
  if [ "$MODE" = direct ]; then
    AB eval "$HELPERS" >/dev/null 2>&1
    N=$(AB eval "window.__grab('$URL')" 2>&1 | tr -d '"' | tail -1)
    [[ "$N" =~ ^[0-9]+$ ]] || { log "direct fetch failed: $N -> nav mode"; MODE=nav; }
  fi
  if [ "$MODE" = nav ]; then
    AB open "$URL" >/dev/null 2>&1; sleep 6; AB eval "$HELPERS" >/dev/null 2>&1
    N=$(AB eval "window.__grab(location.href)" 2>&1 | tr -d '"' | tail -1)
    [[ "$N" =~ ^[0-9]+$ ]] || { log "nav fetch failed too: $N -> skip"; continue; }
  fi
  s=0; i=0
  while [ $s -lt $N ]; do e=$((s+120000)); [ $e -gt $N ] && e=$N
    AB --max-output 200000 eval "window.__chunk($s,$e)" > "$S/p_$i.b64" 2>/dev/null; i=$((i+1)); s=$e; done
  if python3 - "$S" "$OUT/$NAME" "$N" <<'PY'
import base64,glob,sys,os,json
S,out,N=sys.argv[1],sys.argv[2],int(sys.argv[3])
parts=sorted(glob.glob(S+'/p_*.b64'),key=lambda p:int(os.path.basename(p)[2:-4]))
buf=bytearray()
for p in parts:
    t=open(p).read().strip()
    if t.startswith('"'): t=json.loads(t)
    buf+=base64.b64decode(t)
magic=bytes(buf[:4]).hex()
ok=len(buf)==N and (magic.startswith('89504e47') or magic.startswith('ffd8'))
print(f"decoded={len(buf)} expected={N} magic={magic} OK={ok}")
open(out if ok else out+'.BAD','wb').write(buf); sys.exit(0 if ok else 1)
PY
  then ok=$((ok+1)); fi
done < "$LIST"
AB close >/dev/null 2>&1; rm -rf "$S"; log "DONE ok=$ok/$n"; ls -la "$OUT"

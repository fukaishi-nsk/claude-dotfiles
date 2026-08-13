#!/bin/bash
SP="$(cd "$(dirname "$0")" && pwd)"
U="$1"
AB="agent-browser --profile Default"
$AB open "https://app.nanco.io/GloL-DSaWg/item/$U" >/dev/null 2>&1
$AB wait --load networkidle >/dev/null 2>&1
sleep 1
SIG=$($AB eval '(()=>{const t=document.querySelector("h1")?document.querySelector("h1").innerText.trim():""; const qtyEl=document.querySelector("input[aria-label=在庫数],textarea[aria-label=在庫数]"); const qty=qtyEl?qtyEl.value:""; const rows=[...document.querySelectorAll("[class*=attr-row]")]; const get=(label)=>{const r=rows.find(x=>x.innerText.trim().startsWith(label)); if(!r) return ""; const inp=r.querySelector("textarea,input"); if(inp&&inp.value) return inp.value; const c=r.children[1]; return c?c.innerText.trim().split("\n")[0]:""}; return JSON.stringify({t,qty,tanka:get("仕入単価"),taka:get("樹高"),saki:get("仕入れ先")})})()' 2>/dev/null | python3 -c "import sys,json; print(json.loads(sys.stdin.read()))")
N=$(python3 "$SP/resolve.py" "$U" "$SIG" 2>&1)
if [[ "$N" == SIG_MISS* || -z "$N" ]]; then echo "[$U] ASSIGN失敗: $N sig=$SIG"; exit 1; fi
T_UP=$(date +%s)
$AB upload "input[type=file]" "$SP/photos/$N.jpg" >/dev/null 2>&1
$AB eval '(()=>{const labels=[...document.querySelectorAll("*")].filter(e=>e.children.length===0&&e.innerText==="N番号"); let row=labels[0]; while(row&&!(row.className||"").toString().includes("attr-row")) row=row.parentElement; if(!row) return "norow"; row.children[1].id="nb-cell"; return "ok"})()' >/dev/null 2>&1
$AB hover "#nb-cell" >/dev/null 2>&1
sleep 0.5
SNAP=$($AB snapshot -i -c 2>/dev/null | grep -A1 'textbox "N番号"')
TA=$(echo "$SNAP" | grep 'textbox "N番号"' | head -1 | grep -o 'ref=e[0-9]\+' | cut -d= -f2)
BT=$(echo "$SNAP" | grep 'button' | head -1 | grep -o 'ref=e[0-9]\+' | cut -d= -f2)
ST="OK"
if [ -z "$TA" ] || [ -z "$BT" ]; then ST="N番号欄なし"; else $AB fill @$TA "$N" >/dev/null 2>&1; $AB click @$BT >/dev/null 2>&1; fi
NOW=$(date +%s); REST=$((10 - (NOW - T_UP))); [ $REST -gt 0 ] && sleep $REST
echo "[$U] $N $ST"

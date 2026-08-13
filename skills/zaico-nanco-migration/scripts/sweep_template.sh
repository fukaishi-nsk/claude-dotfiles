#!/bin/bash
SP="$(cd "$(dirname "$0")" && pwd)"
U="$1"
AB="agent-browser --profile Default"
$AB open "https://app.nanco.io/GloL-DSaWg/item/$U" >/dev/null 2>&1
$AB wait --load networkidle >/dev/null 2>&1
sleep 4
for try in 1 2 3; do
R=$($AB eval '(()=>{const img=[...document.querySelectorAll("img")].find(i=>!i.src.includes("logo")&&(i.src.includes("_next/image")||i.src.includes("firebase")||i.src.includes("storage"))); const rows=[...document.querySelectorAll("[class*=attr-row]")]; const r=rows.find(x=>x.innerText.trim().startsWith("N番号")); const ta=r?r.querySelector("textarea"):null; return JSON.stringify({img: img?(img.complete&&img.naturalWidth>0?"OK":"LOADING"):"NONE", n: ta?ta.value:"(欄なし)", rows: rows.length})})()' 2>/dev/null)
if ! echo "$R" | grep -q "(欄なし)\|LOADING"; then break; fi
sleep 2.5
done
echo "$U $R"

#!/bin/bash
# AI系のCLIとアプリを最新にする（Mac 用）。定期実行 ai-apps-daily-update から呼ばれる。手でも叩ける。
#   bash ~/claude-dotfiles/scripts/ai_update.sh              … CLI更新＋更新待ちのアプリを再起動
#   bash ~/claude-dotfiles/scripts/ai_update.sh --no-restart … CLI更新だけ。アプリは「更新待ち」を報告するだけ
#
# 決まり（2026-11-12 深石さんと決めた）:
#   ・agent-browser は 0.34.0 固定運用なので更新しない
#   ・アプリを再起動するのは「起動中」かつ「更新待ちのプロセスがいる」ものだけ（無駄に落とさない）
#   ・Claude デスクトップは定期実行そのものが中で動くので再起動しない（更新待ちを報告するだけ）
#   ・claude remote-control は再起動しない（遠隔接続が切れるため。旧版のままなら報告するだけ）
# 出力: 1行1件。先頭の語で種別が分かる（更新 / 変化なし / 再起動 / 更新待ち / 注意 / 失敗）。終了コードは常に 0。
# macOS の bash 3.2 で動く書き方にしてある。

export PATH="/opt/homebrew/bin:$HOME/.local/bin:$HOME/.grok/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
[ "$(uname)" = Darwin ] || { echo "失敗: このスクリプトは Mac 用"; exit 0; }

RESTART=1
[ "$1" = "--no-restart" ] && RESTART=0

ver() {  # コマンドの版番号（数字.数字… の最初の1つ）
  command -v "$1" >/dev/null 2>&1 || { echo "なし"; return; }
  "$1" --version 2>/dev/null | grep -Eo '[0-9]+(\.[0-9]+)+' | head -1
}

update_cli() {  # 名前 コマンド 更新コマンド…
  local name="$1" cmd="$2"; shift 2
  local before after out
  before=$(ver "$cmd")
  if [ "$before" = "なし" ]; then echo "注意: $name は入っていない（飛ばした）"; return; fi
  if out=$("$@" 2>&1); then
    after=$(ver "$cmd")
    if [ "$before" != "$after" ]; then echo "更新: $name $before → $after"; CLAUDE_CHANGED_NAME="$CLAUDE_CHANGED_NAME $name"
    else echo "変化なし: $name $before"; fi
  else
    echo "失敗: $name の更新（$before のまま）: $(echo "$out" | tail -2 | tr '\n' ' ' | cut -c1-200)"
  fi
}

CLAUDE_CHANGED_NAME=""
echo "== CLI =="
update_cli "Claude Code" claude npm i -g @anthropic-ai/claude-code@latest
update_cli "Gemini CLI"  gemini npm i -g @google/gemini-cli@latest
brew update >/dev/null 2>&1
if brew outdated --cask 2>/dev/null | grep -q '^codex'; then
  update_cli "Codex CLI" codex brew upgrade --cask codex
else
  echo "変化なし: Codex CLI $(ver codex)"
fi
update_cli "agy"  agy  agy update
update_cli "Grok CLI" grok grok update

# remote-control が旧版のまま動いていないか（起動時刻が claude-code の入れ替えより前なら旧版）
pkg="/opt/homebrew/lib/node_modules/@anthropic-ai/claude-code/package.json"
if [ -f "$pkg" ]; then
  pkg_t=$(stat -f %m "$pkg")
  for pid in $(pgrep -f "claude remote-control"); do
    st=$(ps -o lstart= -p "$pid" 2>/dev/null)
    [ -n "$st" ] || continue
    st_t=$(date -j -f "%a %b %d %T %Y" "$st" +%s 2>/dev/null) || continue
    if [ "$st_t" -lt "$pkg_t" ]; then
      echo "注意: claude remote-control（pid $pid・$(date -r "$st_t" '+%m/%d %H:%M') 起動）は旧版のまま。再起動していない"
    fi
  done
fi

echo "== アプリ =="
app_ver() { defaults read "/Applications/$1.app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null; }
app_running() { pgrep -f "/Applications/$1.app/Contents/MacOS/" >/dev/null 2>&1; }
app_pending() {  # 更新待ちのプロセス（Squirrel の ShipIt / Sparkle の Autoupdate）がいるか
  pgrep -f "ShipIt $2.ShipIt" >/dev/null 2>&1 || pgrep -f "Autoupdate $2 " >/dev/null 2>&1
}

handle_app() {  # 表示名 バンドルID 再起動してよいか(1/0)
  local name="$1" id="$2" may="$3" before after i
  [ -d "/Applications/$name.app" ] || return
  before=$(app_ver "$name")
  if ! app_pending "$name" "$id"; then echo "変化なし: $name $before（更新待ちなし）"; return; fi
  if [ "$may" != 1 ] || [ "$RESTART" != 1 ]; then echo "更新待ち: $name $before（再起動していない）"; return; fi
  if ! app_running "$name"; then echo "更新待ち: $name $before（起動していないので触っていない）"; return; fi
  osascript -e "tell application id \"$id\" to quit" >/dev/null 2>&1
  i=0
  while [ $i -lt 40 ]; do   # 最長120秒: アプリが終わり、更新の適用も終わるまで待つ
    if ! app_running "$name" && ! app_pending "$name" "$id"; then break; fi
    sleep 3; i=$((i+1))
  done
  if app_running "$name"; then echo "失敗: $name が終了しなかった（$before のまま・保存の確認画面が出ている可能性）"; return; fi
  open -g -a "/Applications/$name.app" >/dev/null 2>&1
  sleep 8
  after=$(app_ver "$name")
  if app_running "$name"; then
    if [ "$before" != "$after" ]; then echo "再起動: $name $before → $after"
    else echo "再起動: $name $before のまま（更新は入らなかった）"; fi
  else
    echo "失敗: $name を起動し直せなかった（版は $after）"
  fi
}

handle_app "ChatGPT"     com.openai.codex               1
handle_app "Grok Bot"    com.anysphere.sand             1
handle_app "Nani"        jp.kiok.nani                   1
handle_app "Antigravity" com.google.antigravity         1
handle_app "HyperFrames" dev.hyperframes.desktop        1
handle_app "Claude"      com.anthropic.claudefordesktop 0
exit 0

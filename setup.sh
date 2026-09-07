#!/bin/bash
# Claude Code dotfiles セットアップスクリプト
# 他のPCで実行すると、~/.claude/ にシンボリックリンクを張ります

set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

# OS判定: macOS(BSD ln) と Windows Git Bash(GNU ln) でsymlinkの張り方が違う
case "$(uname -s)" in
  Darwin) OS_KIND=mac ;;
  MINGW*|MSYS*|CYGWIN*) OS_KIND=windows ;;
  *) OS_KIND=linux ;;
esac

# Windows: MSYSのlnはデフォルトで「コピー」を作ってしまうため、NTFSの本物のsymlinkを強制する
# （要 Developer Mode。無効だとlnが失敗し、link_file内の検証で止まる）
if [ "$OS_KIND" = windows ]; then
  export MSYS=winsymlinks:nativestrict
fi

echo "📦 Claude Code dotfiles をセットアップします"
echo "   ソース: $DOTFILES_DIR"
echo "   ターゲット: $CLAUDE_DIR"
echo ""

# ~/.claude/ がなければ作る
mkdir -p "$CLAUDE_DIR"
mkdir -p "$CLAUDE_DIR/skills"
mkdir -p "$CLAUDE_DIR/scheduled-tasks"

# バックアップ＆リンク関数
link_file() {
  local src="$1"
  local dest="$2"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "  ⚠️  既存ファイルをバックアップ: $dest → ${dest}.bak"
    mv "$dest" "${dest}.bak"
  fi
  if [ "$OS_KIND" = mac ]; then
    ln -sfh "$src" "$dest"  # BSD ln: -h でsymlink自身を置き換え
  else
    ln -sfn "$src" "$dest"  # GNU ln: -n が BSD の -h 相当
  fi
  # symlink作成が黙ってコピーにフォールバックしていないか検証（Windowsで起こりうる）
  if [ ! -L "$dest" ]; then
    echo "  ❌ symlinkを作成できませんでした: $dest"
    echo "     Windowsの場合: 設定 > システム > 開発者向け で「開発者モード」を有効にして再実行してください"
    exit 1
  fi
  echo "  ✅ $dest → $src"
}

# 個別ファイルをリンク
link_file "$DOTFILES_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
link_file "$DOTFILES_DIR/settings.json" "$CLAUDE_DIR/settings.json"

# skills/ 配下をリンク
for skill_dir in "$DOTFILES_DIR/skills"/*/; do
  if [ -d "$skill_dir" ]; then
    skill_name=$(basename "$skill_dir")
    mkdir -p "$CLAUDE_DIR/skills/$skill_name"
    for file in "$skill_dir"*; do
      if [ -f "$file" ] || [ -d "$file" ]; then
        link_file "$file" "$CLAUDE_DIR/skills/$skill_name/$(basename "$file")"
      fi
    done
  fi
done

# scheduled-tasks/ 配下は「実ファイルコピー」で同期する（定期実行タスクの手順書）
# 🚫 symlink は禁止（2026-09-07 に方式変更）。理由:
#    Claude デスクトップアプリのスケジューラが symlink の SKILL.md を
#    「symlink detected before open; refusing to open」で拒否し、lastRunAt だけ刻んで
#    セッションを起こさない＝サイレント停止する。claude-code 2.1.258 が入った
#    2026-09-03 09:01 から発生し、9/3〜9/7 の nanco-meeting-import / teams-mention-check /
#    sora-meet-link-share が全便沈黙した（~/Library/Logs/Claude/main.log で確認）。
#    それまでの setup.sh は毎 SessionStart に実ファイルを symlink へ戻していたため、
#    手で実ファイル化しても次のセッションで元に戻り、原因が見えにくかった。
#    （加えて scheduled-tasks の登録・更新ツールも symlink 越しの書き込みを拒否する）
# 運用:
#    ・正本は dotfiles。編集は必ず正本へ。setup.sh が毎 SessionStart にここへコピーして追従する
#    ・ローカルが正本と異なる実ファイルだった場合は SKILL.md.local-<日時>.bak に退避してから上書き
#      （update_scheduled_task 等でローカルを直接編集した内容を黙って消さないため）
#    ・旧 .local-realfile マーカーは不要になった（残っていても無害）
for task_dir in "$DOTFILES_DIR/scheduled-tasks"/*/; do
  if [ -d "$task_dir" ]; then
    task_name=$(basename "$task_dir")
    dest_task_dir="$CLAUDE_DIR/scheduled-tasks/$task_name"
    mkdir -p "$dest_task_dir"
    for file in "$task_dir"*; do
      dest="$dest_task_dir/$(basename "$file")"
      if [ -L "$dest" ]; then
        rm -f "$dest"   # 旧 symlink は撤去してから実ファイルを置く
      fi
      if [ -d "$file" ]; then
        rm -rf "$dest"
        cp -R "$file" "$dest"
        echo "  ✅ $dest ← $file（ディレクトリを実ファイルコピー）"
      elif [ -f "$file" ]; then
        if [ -f "$dest" ] && ! cmp -s "$file" "$dest"; then
          bak="${dest}.local-$(date +%Y%m%d-%H%M).bak"
          cp -p "$dest" "$bak"
          echo "  ⚠️  ローカル編集を退避: $bak"
        fi
        if [ ! -f "$dest" ] || ! cmp -s "$file" "$dest"; then
          cp -p "$file" "$dest"
          echo "  ✅ $dest ← $file（実ファイルコピー）"
        fi
      fi
    done
  fi
done

# Codex共有スキル: 指定したスキルだけ ~/.codex/skills/ にもコピーする（Claude/Codexで同じ知見を使う）
# ※ 全スキルは共有しない（Claude専用スキルがCodexのskillsコンテキスト予算を圧迫するため）
# ※ symlinkはCodexがスキルとして認識しないため実ファイルコピー（2026-08-10 codex execで検証済み）
#    → 正本（skills/配下）を編集したら setup.sh を再実行してコピーを更新すること
CODEX_SHARED_SKILLS=(notta-check)
if [ -d "$HOME/.codex" ]; then
  mkdir -p "$HOME/.codex/skills"
  for skill_name in "${CODEX_SHARED_SKILLS[@]}"; do
    src_dir="$DOTFILES_DIR/skills/$skill_name"
    if [ -d "$src_dir" ]; then
      dest_dir="$HOME/.codex/skills/$skill_name"
      rm -rf "$dest_dir"
      cp -R "$src_dir" "$dest_dir"
      echo "  ✅ $dest_dir ← $src_dir（実ファイルコピー）"
    fi
  done
fi

# Codex共通指示（AGENTS.md）: 正本 codex/AGENTS.md を ~/.codex/AGENTS.md へ実ファイルコピーする（2026-09-07〜）
# ※ skills と同じく symlink は避ける。ローカルが正本と異なる（空でない）場合は .local-<日時>.bak に退避してから上書き
if [ -d "$HOME/.codex" ] && [ -f "$DOTFILES_DIR/codex/AGENTS.md" ]; then
  dest="$HOME/.codex/AGENTS.md"
  if [ -L "$dest" ]; then
    rm -f "$dest"
  fi
  if [ -f "$dest" ] && [ -s "$dest" ] && ! cmp -s "$DOTFILES_DIR/codex/AGENTS.md" "$dest"; then
    bak="${dest}.local-$(date +%Y%m%d-%H%M).bak"
    cp -p "$dest" "$bak"
    echo "  ⚠️  ローカル編集を退避: $bak"
  fi
  if [ ! -f "$dest" ] || ! cmp -s "$DOTFILES_DIR/codex/AGENTS.md" "$dest"; then
    cp -p "$DOTFILES_DIR/codex/AGENTS.md" "$dest"
    echo "  ✅ $dest ← $DOTFILES_DIR/codex/AGENTS.md（実ファイルコピー）"
  fi
fi

echo ""
echo "🎉 セットアップ完了！Claude Code を再起動してください。"
echo "   ※ scheduled-tasks は手順書のみ「実ファイルコピー」で同期されます（symlink禁止・2026-09-07〜）。"
echo "      スケジュール自体（実行時刻の登録）は PCごとに /schedule または scheduled-tasks コネクタで別途登録してください。"
echo "   ※ Codex共有スキル（CODEX_SHARED_SKILLS）と Codex共通指示（codex/AGENTS.md）は実ファイルコピーです。"
echo "      正本を編集したら setup.sh を再実行してコピーを更新してください。"

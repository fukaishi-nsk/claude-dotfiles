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

# scheduled-tasks/ 配下をリンク（定期実行タスクの手順書）
# ⚠ PCローカルで「実ファイルのまま置きたい」タスクは、そのタスクの
#    ~/.claude/scheduled-tasks/<名前>/.local-realfile を置くとリンクをスキップする。
#    理由: scheduled-tasks の登録・更新ツールが symlink 越しの書き込みを拒否するため、
#    そのPCでスケジュール登録しているタスクは実ファイルでないと update できない。
#    （2026-09-07 追加。それまでは毎SessionStartのsetup.shが実ファイルをsymlinkに戻していた）
for task_dir in "$DOTFILES_DIR/scheduled-tasks"/*/; do
  if [ -d "$task_dir" ]; then
    task_name=$(basename "$task_dir")
    dest_task_dir="$CLAUDE_DIR/scheduled-tasks/$task_name"
    mkdir -p "$dest_task_dir"
    if [ -f "$dest_task_dir/.local-realfile" ]; then
      echo "  ⏭️  $dest_task_dir はスキップ（.local-realfile ＝ このPCでは実ファイル運用）"
      continue
    fi
    for file in "$task_dir"*; do
      if [ -f "$file" ] || [ -d "$file" ]; then
        link_file "$file" "$dest_task_dir/$(basename "$file")"
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

echo ""
echo "🎉 セットアップ完了！Claude Code を再起動してください。"
echo "   ※ scheduled-tasks は手順書のみ同期されます。スケジュール自体（実行時刻の登録）は"
echo "      PCごとに /schedule または scheduled-tasks コネクタで別途登録してください。"
echo "   ※ Codex共有スキル（CODEX_SHARED_SKILLS）は実ファイルコピーです。"
echo "      正本を編集したら setup.sh を再実行してコピーを更新してください。"

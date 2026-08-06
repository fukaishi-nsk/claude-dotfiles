#!/bin/bash
# Claude Code dotfiles セットアップスクリプト
# 他のPCで実行すると、~/.claude/ にシンボリックリンクを張ります

set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

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
  ln -sfh "$src" "$dest"
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
for task_dir in "$DOTFILES_DIR/scheduled-tasks"/*/; do
  if [ -d "$task_dir" ]; then
    task_name=$(basename "$task_dir")
    mkdir -p "$CLAUDE_DIR/scheduled-tasks/$task_name"
    for file in "$task_dir"*; do
      if [ -f "$file" ] || [ -d "$file" ]; then
        link_file "$file" "$CLAUDE_DIR/scheduled-tasks/$task_name/$(basename "$file")"
      fi
    done
  fi
done

echo ""
echo "🎉 セットアップ完了！Claude Code を再起動してください。"
echo "   ※ scheduled-tasks は手順書のみ同期されます。スケジュール自体（実行時刻の登録）は"
echo "      PCごとに /schedule または scheduled-tasks コネクタで別途登録してください。"

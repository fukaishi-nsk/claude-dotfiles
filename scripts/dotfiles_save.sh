#!/bin/bash
# claude-dotfiles の変更を保存して同期する（git pull → add → commit → push）。
# 使い方: bash ~/claude-dotfiles/scripts/dotfiles_save.sh "コミットメッセージ" [ファイル ...]
#   ファイルを渡せばそれだけ、渡さなければ変更のある追跡済みファイル全部（git add -u）を commit する。
# このリポジトリ（github.com/fukaishi-nsk/claude-dotfiles・プライベート）以外には触らない。
# 2026-11-19 追加: email-draft などの継続学習で毎回 commit＋push が要るのに、
#   Claude Code の自動の確認で `git commit && git push` が止められていたため、この1本にまとめて許可した。
set -euo pipefail

REPO="$HOME/claude-dotfiles"
cd "$REPO"

msg="${1:-}"
if [ -z "$msg" ]; then
  echo "usage: dotfiles_save.sh \"commit message\" [file ...]" >&2
  exit 2
fi
shift

# 他のPCの変更を先に取り込む（ローカルの未コミット変更は一時退避）
git pull --ff-only --autostash -q

if [ "$#" -gt 0 ]; then
  git add -- "$@"
else
  git add -u
fi

if git diff --cached --quiet; then
  echo "変更なし（commit も push もしていません）"
  exit 0
fi

git commit -q -m "$msg" -m "Co-Authored-By: ${CO_AUTHOR:-Claude Opus 5.5} <noreply@anthropic.com>"
git push -q
git log -1 --format='pushed: %h %s'

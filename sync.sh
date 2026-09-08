#!/bin/bash
# dotfiles 同期（settings.json の SessionStart フックから毎起動で呼ばれる）
#
# 旧フック `git pull && setup.sh` は、Claude デスクトップアプリが settings.json を書き換える（キー順の正規化・
# 空行除去・"agentPushNotifEnabled" 追加など）だけで「ローカル変更あり」になり pull が拒否され、
# 以後の起動が全部「⚠️ 同期失敗」になっていた（2026-09-08 に 5090 機で 8 コミット遅れを確認。中身は origin と同一だった）。
#
# この版は:
#   1. ローカルの未コミット変更を stash に退避してから fast-forward で pull する
#   2. pull 後に stash を戻す。戻せない（本当の競合）ときは origin の版を採用し、退避分は stash に残す
#      （設定ファイルにコンフリクトマーカーを残さない＝Claude Code が settings.json を読めなくなる事故を防ぐ）
#   3. 分岐（ローカルに未 push のコミット）や fetch 失敗はいじらず警告だけ出す
#   4. 最後に setup.sh（symlink・実ファイルコピー）を再実行する
# 終了コードは常に 0（起動を止めない）。警告は stdout に 1 行（Claude に読ませる）。
# macOS の bash 3.2 でも動く書き方にしてある。

D="$HOME/claude-dotfiles"
warn() { echo "⚠️ dotfiles同期: $1 ユーザーに伝え、git -C ~/claude-dotfiles status での確認を促してください。"; }

cd "$D" 2>/dev/null || { warn "$D が無い。"; exit 0; }

if ! git fetch --quiet origin 2>/dev/null; then
  warn "fetch に失敗（オフライン？）。今回は pull を飛ばした。"
  "$D/setup.sh" >/dev/null 2>&1
  exit 0
fi

# 未 push のローカルコミットがあれば自動では触らない（分岐の解消は人が判断する）
if [ -n "$(git log --oneline origin/main..HEAD 2>/dev/null)" ]; then
  if [ -n "$(git log --oneline HEAD..origin/main 2>/dev/null)" ]; then
    warn "ローカルに未 push のコミットがあり origin とも分岐している。pull していない。"
    exit 0
  fi
  warn "ローカルに未 push のコミットがある（push 忘れ？）。"
fi

stashed=0
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  if git stash push --quiet -m "auto-sync $(date +%Y-%m-%d_%H:%M:%S) $(hostname 2>/dev/null)"; then
    stashed=1
  else
    warn "ローカル変更の退避（stash）に失敗。pull していない。"
    exit 0
  fi
fi

if git pull --quiet --ff-only 2>/dev/null; then
  :
else
  [ "$stashed" = 1 ] && git stash pop --quiet 2>/dev/null
  warn "fast-forward できない（分岐？）。pull していない。"
  exit 0
fi

if [ "$stashed" = 1 ]; then
  if git stash pop --quiet 2>/dev/null; then
    :   # ローカル変更を戻せた（アプリの書き換えが origin と同じ内容なら差分ゼロで消える）
  else
    # 本当の競合: 作業ツリーを origin の版に戻し、退避分は stash に残す（マーカーを残さない）
    git reset --quiet --hard HEAD 2>/dev/null
    warn "ローカル変更が origin と競合したので origin の版を採用した。ローカル変更は git stash list に残してある。"
  fi
fi

"$D/setup.sh" >/dev/null 2>&1 || warn "setup.sh が失敗した。"
exit 0

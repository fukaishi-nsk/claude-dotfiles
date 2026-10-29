---
name: nanco-consult-followup-dispatch
description: 【停止中 2026-10-29】予約方式をやめ、相談後処理を決まった時刻（12:30・14:00・15:30・17:00・18:30）で動かす方式に変えたため無効化
---

# nanco相談後処理の予約係

深石さんの指示（2026-10-28）:「30分おきだと効率悪いから、カレンダーの予定をその日の朝と午後とかに見ればいいのでは？」→ 予約方式に変更。
相談後処理の本体は `nanco-consult-followup`（手順の正本 `~/claude-dotfiles/scheduled-tasks/nanco-consult-followup/SKILL.md`）。このタスクは、その本体を**いつ動かすかを予約するだけ**。取込・報告・Slack投稿はしない。

## 実行モード（無人）
- 応答する人間はいない。止まる質問はしない
- 使うのは次の3つだけ: Google カレンダーの `list_events`／Bash の `cat`（台帳を読む）と `date`／`mcp__scheduled-tasks__list_scheduled_tasks`・`mcp__scheduled-tasks__update_scheduled_task`
- 複合コマンド（`;` `&&`）を作らない。settings.json を読まない・書かない
- 権限確認やエラーで予約できなかったときだけ、Slack #log_fukaishi（C03119VSJGK）に `<@U02PBGQ62BB> 【相談後処理の予約係】予約できませんでした: <原文エラー>` を1行投稿する（18時の nanco-meeting-import が拾うので、取りこぼしにはならない旨も添える）。それ以外は投稿しない

## 手順
1. `date '+%Y-%m-%dT%H:%M:%S%z'` で今の時刻を確かめる
2. Google カレンダー（primary・fukaishi@nsketch.com）で、**今日の 0:00〜23:59** の予定を取る。タイトルが `[nanco]在庫管理アプリnanco オンライン相談 (` または `[レディクル]` で始まるものだけを対象にする（status が cancelled は除く）
3. 台帳 `~/Library/CloudStorage/GoogleDrive-fukaishi@nsketch.com/My Drive/claude-shared/consult-post-ledger.md` を `cat` で読む。対象のうち、台帳に予定IDが無いもの、またはその予定IDのいちばん新しい行の状態が「文字起こし待ち」のものを「未処理」とする
4. 未処理の相談それぞれについて「終了時刻＋30分」を出し、いちばん早いものを候補にする。今より前なら「今から3分後」にする。未処理が無ければ何もせず終わる
5. `list_scheduled_tasks` で `nanco-consult-followup` の状態を見る。enabled かつ fireAt が今より後で、候補より早い（または同じ）なら、そのままにして終わる（すでに予約がある）
6. それ以外なら `update_scheduled_task`（taskId `nanco-consult-followup`、`fireAt` に `+09:00` 付きの ISO 時刻、例 `2026-10-28T15:30:00+09:00`）で予約する。cronExpression は渡さない
7. チャットの最終報告は日本語で、「対象の相談・予約した時刻（またはしなかった理由）」を2〜3行で書く
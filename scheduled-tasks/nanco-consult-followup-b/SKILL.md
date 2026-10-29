---
name: nanco-consult-followup-b
description: nanco相談後の自動処理の14:00・17:00担当。中身は nanco-consult-followup と同じ手順（正本を読んで実行）
---

# nanco相談後の自動処理（14:00・17:00担当）

このタスクは `nanco-consult-followup`（平日12:30・15:30・18:30）と同じ処理を、14:00・17:00 に動かすためだけのもの（1つのcron式で時刻を表せないため分けた・2026-10-29 深石さん了承）。

手順の正本 `~/claude-dotfiles/scheduled-tasks/nanco-consult-followup/SKILL.md` を `cat` で読み、そのとおりに実行する。

- 無人で動く。止まる質問はしない。権限の決まりも正本に従う
- 次の回の予約はしない（`update_scheduled_task` / `create_scheduled_task` は使わない）
- 台帳の予定IDで、`nanco-consult-followup` がすでに処理した相談は飛ばす
- 対象の相談が無い回は、何も書かず・投稿せずに終わる
- チャットの最終報告は日本語で2〜3行

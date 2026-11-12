---
name: ai-apps-daily-update-win
description: 火〜土の7:30に、会社の3090機（nsk3090・Windows）のAI系CLI（Claude Code・Codex CLI）を最新にし、更新待ちのAIアプリ（Antigravity・Grok Bot・Cursor）を再起動して反映する。更新・再起動・失敗があった日だけ Slack #log_fukaishi に報告（無人）
---

# AI系アプリ・CLIの毎朝の更新（Windows・3090機・自動）

深石さんの指示（2026-11-12）: Mac mini の ai-apps-daily-update（同日作成）の Windows 版を 3090 機（nsk3090）にも。火〜土 7:30。決まりは Mac mini と同じ。
**この手順は nsk3090 で登録して動かすもの**（dotfiles で他の PC にも手順書はコピーされるが、登録はしない）。

この手順で行うことは**事前承認済み**（範囲はここに書いたものだけ）: 下のスクリプトの実行（CLI の更新・更新待ちアプリの終了と起動）と、Slack `#log_fukaishi` への報告。

## 1. 実行する

次の1コマンドだけを実行する（数分かかることがある。タイムアウトは10分にする）。

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File "$USERPROFILE/claude-dotfiles/scripts/ai_update.ps1"
```

スクリプトがすること（中身を変えたい時はスクリプトの正本 `~/claude-dotfiles/scripts/ai_update.ps1` を直す）:
- Claude デスクトップの中から呼ばれると、書き込みがアプリ専用フォルダに振り替えられるため、自分自身を WMI で囲いの外に起動し直し、終わるのを待って結果を表示する（2026-11-12 実測による作り。結果のログは `~/.ai_update/run_*.log`）
- CLI を最新にする: Claude Code（ネイティブ版・`claude update`）、Codex CLI（npm）
- Antigravity・Grok Bot・Cursor のうち、**起動中で更新待ちのものだけ**をウィンドウを閉じて終了→更新の適用を待つ→起動し直す
- ChatGPT（Codex アプリ・Store）と Claude デスクトップは更新待ちを見分けられないので、前回から版が変わった時に「更新:」と出すだけ
- 出力は1行1件。先頭の語が種別（更新 / 変化なし / 再起動 / 更新待ち / 注意 / 失敗）

## 2. やらないこと

- **agent-browser は更新しない**（0.34.0 固定運用）
- **Claude デスクトップは再起動しない**（この定期実行がその中で動いている）
- **`claude remote-control` は再起動しない**。「旧版のまま」と出たら報告に書くだけ
- スクリプトに無いアプリ・ツールを自分の判断で更新しない（Parsec・GPU ドライバ・画像生成の Python 環境やライブラリは対象外）。パスワードや認証を求められたら入力せず、失敗として報告する
- 失敗した更新を別の方法でやり直さない（原因と出力を報告する）

## 3. 報告

- 出力に「更新:」「再起動:」「失敗:」の行が**1つも無い日は、何も投稿せずに終わる**（「注意:」「更新待ち:」だけの日も投稿しない）
- 1つでもあれば、Slack `#log_fukaishi`（channel_id `C03119VSJGK`）に日本語で投稿する（Slack コネクタの slack_send_message）。冒頭に `<@U02PBGQ62BB>`、続けて「3090機（Windows）のAI系の更新」と書いて Mac mini の報告と見分けられるようにする
- 書くこと: 更新されたもの（前の版 → 後の版）、再起動したアプリ、失敗（スクリプトの出力をそのまま）、その日に出ていた「注意:」「更新待ち:」の行
- スクリプトの出力に無いことは書かない。版番号は出力の数字をそのまま使う
- Slack に投稿できなかった時は、この実行の最後のメッセージにその旨と報告の中身を書く

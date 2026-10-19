# nsk-buddy（Mac mini ⇄ 3090 の見守り合い）

会社に置きっぱなしの Mac mini と 3090 が、**30分ごとにお互いの様子を見て、異常があれば Slack に知らせる**仕組み。2026-10-19 制定（深石さん決定）。

- **知らせるだけで、自動では直さない**。直すときは、元気な方の Claude に「◯◯を直して」と頼む（スキル `macmini-recover` / `nsk3090-recover`）
- 例外として、**Mac mini は毎月1日 04:00 に 3090 から再起動する**（macOS を 49.7 日つけっぱなしにすると TIME_WAIT が消えなくなり TCP が詰まる不具合の予防。2026-10-19 の障害の主因と推定）

## 何を見ているか

| 見る側 → 見られる側 | 異常（:rotating_light:） | 注意（:warning:） |
|---|---|---|
| 3090 → Mac mini | SSH 不通／外への通信失敗／TIME_WAIT 2万超／Parsec 未起動／Parsec の error 17 連続 | 起動から45日以上／Sunshine 停止 |
| Mac mini → 3090 | SSH 不通（.26 → .24 の順に試す）／外への通信失敗／TIME_WAIT 2万超／Parsec サービス停止／Parsec が150分以上サーバーに届いていない | parsecd が無い／Parsec ログが読めない／C の空き100GB未満 |

- 異常を見つけたら1分おいてもう一度見て、それでも異常なら通知（一時的な揺れで誤報しないため）
- 同じ異常が続く間は6時間ごとに再通知。異常から正常に戻ったら「戻りました」を通知
- 月次再起動の最中（目印ファイル `~/.nsk-buddy/macmini.restarting`、20分有効）は 3090 からの見守りを休む

## ファイル

| ファイル | 役割 |
|---|---|
| `buddy-check.sh <macmini\|3090>` | 1回分の見守り（判定・通知・状態記録） |
| `buddy-lib.sh` | 共通部品（Slack 通知・相手の状態取得） |
| `probe-macmini.sh` / `probe-3090.ps1` | 相手側で流す読み取り専用の状態取得（SSH の標準入力で送る。.ps1 は ASCII のみ） |
| `restart-macmini.sh [--force]` | Mac mini の月次再起動（1日以外は何もしない。`--force` で今すぐ） |
| `install-macmini.sh` | Mac mini に launchd ジョブ `com.nsketch.nsk-buddy.check-3090`（30分ごと）を登録 |
| `install-3090.ps1` | 3090 にタスク `nsk-buddy-check-macmini`（30分ごと）と `nsk-buddy-restart-macmini`（毎日04:00・1日だけ実行）を登録（S4U＝画面に出さず実行） |
| `.gitattributes` | このフォルダーだけ LF 固定（3090 の git は core.autocrlf=true で、CRLF のまま Mac mini に送ると誤判定する。2026-10-19 実際に起きた） |

各機械の `~/.nsk-buddy/` に、`buddy.log`（1回1行）・`<相手>.state`（前回の状態）・`slack_webhook_url`（通知先。**git 管理外**）を置く。Webhook が無い間は通知はログに残るだけ。

## 導入・更新

```bash
# Mac mini
cd ~/claude-dotfiles && git pull && bash buddy/install-macmini.sh
```
```bash
# 3090（MacBook や Mac mini から）
ssh Host3090 'powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\nsketch\claude-dotfiles\buddy\install-3090.ps1'
```

スクリプトの中身を変えただけなら、各機械で `git pull` するだけでよい（登録はファイルの場所を指しているため）。

## 止める

```bash
# Mac mini
launchctl unload ~/Library/LaunchAgents/com.nsketch.nsk-buddy.check-3090.plist && rm ~/Library/LaunchAgents/com.nsketch.nsk-buddy.check-3090.plist
```
```bash
# 3090
ssh Host3090 "powershell -NoProfile -Command Unregister-ScheduledTask -TaskName nsk-buddy-check-macmini,nsk-buddy-restart-macmini -Confirm:0"
```

## 確認済み・未確認（2026-10-19）

- 確認済み: 両方向の手動実行と定期実行（Mac mini の launchd・3090 の S4U タスク）で「正常」判定。3090 側の異常判定 → 1分後の再確認 → 通知（Webhook 未設定のためログ止まり）→ 状態記録の流れ
- 未確認: Slack への実投稿、月次再起動の本番（初回は 2026-11-01 04:00）、本物の異常時の通知

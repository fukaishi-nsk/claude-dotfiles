# rc-restart-on-update

claude（Claude Code CLI）が更新されたあと、旧版のまま動き続けている `claude remote-control` を自動で再起動する launchd ジョブ。**Mac mini（remote-control 母艦）専用**。2026-11-26 制定（深石さん「入れて」）。

## なぜ要るか

2026-11-26 実例: remote-control の親プロセスは 11/20 から動きっぱなしで、07:35 の claude 自動更新後も旧版のままだった。12:40〜13:10 に新しいセッションが「Can't read the current directory (EPERM)」で5回続けて失敗した（「session failed 5 times in the last hour」）。手で再起動したら直った。過去のログにも、更新でファイルが入れ替わった時の `spawn error: ENOENT … claude.exe` が何度も出ていた。

それまでの決まり（2026-11-12・`scripts/ai_update.sh`）は「remote-control は再起動しない（遠隔接続が切れるため）」だった。これを「**作業中でない時だけ再起動する**」に変えた。

## 何をするか

- 10分ごとに `check.sh` を実行する（ログイン時にも1回実行する）
- 対象: `com.nsketch.claude-remote-control.nanco`（カスタマー）・`com.fukaishi.claude-remote-control`（~/src）
- 旧版の判定: 親プロセスの起動時刻が `/opt/homebrew/lib/node_modules/@anthropic-ai/claude-code/package.json` の更新時刻より前
- 更新から3分以内のときと、`claude --version` が通らないときは触らない
- 作業中なら見送る: 配下の全プロセスの CPU 時間が 20 秒で 2 秒以上増えていたら、次の回に回す
- 再起動は `launchctl kickstart -k`。セッションの環境は残り、次のメッセージで再開する
- ついでに `claude-remote-control-nanco.log` が 100MB を超えたら、末尾 10MB だけ `.old` に残して空にする（画面の書き直しがそのまま記録され、11/26 時点で 2.6GB あった）
- ログ: `~/Library/Logs/rc-restart-on-update.log`（再起動・見送り・切り詰めをした時だけ書く）

## 導入（Mac mini で）

```bash
cd ~/claude-dotfiles && git pull && bash launchd/rc-restart-on-update/install.sh
```

判定だけ見たいとき: `bash launchd/rc-restart-on-update/check.sh --dry-run`

⚠️ MacBook には入れない（remote-control の LaunchAgent が無い）。

## 解除

```bash
launchctl unload ~/Library/LaunchAgents/com.nsketch.rc-restart-on-update.plist
rm ~/Library/LaunchAgents/com.nsketch.rc-restart-on-update.plist
```

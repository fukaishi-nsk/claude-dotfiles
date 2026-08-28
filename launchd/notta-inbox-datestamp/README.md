# notta-inbox-datestamp

Notta_Inbox（Google Drive）に着弾する文字起こしファイルへ `YYMMDD_` プレフィックスを自動付与するlaunchdジョブ。**Mac mini（常時稼働機）で動かす想定**。2026-08-10制定。

## 何をするか

- Notta_Inboxをフォルダ監視（WatchPaths）＋1時間ごとのスイープで起動
- **導入時刻より新しいファイルのみ**対象（既存ファイルは触らない。基準時刻は `~/.notta-inbox-datestamp-installed`）
- 拡張子なしファイルに `.txt` 付与（Zap側修正の保険）→ 日付なし `.txt` に `YYMMDD_` 前置（例: `N朝会.txt` → `260810_N朝会.txt`）
- ログ: `~/Library/Logs/notta-inbox-datestamp.log`

## 導入（Mac miniで）

```bash
cd ~/claude-dotfiles && git pull && bash launchd/notta-inbox-datestamp/install.sh
```

前提: Google Drive for desktop に fukaishi@nsketch.com でログイン済みであること（install.shがパス存在をチェックする）。

## 制約・運用メモ

- 日付は**Drive着弾時刻（mtime）ベース**。長時間録音がNottaで翌日処理されると会議日と1日ズレる（実例: 8/3のGSI棚卸し→8/4着弾）。ズレは案件フォルダへの仕分け時にClaudeが会議文脈で補正する（notta-checkスキル参照）
- Nottaタイトル自体に日付が入っている場合（例: `260810_[湯本]相談`）は先頭6桁+_を検知してスキップ＝二重日付にならない
- ⚠️ **二重実行注意**: MacBook側では導入しない（両機で動いても冪等だが、意図としてMac mini専任）
- リネームはmvのみ・冪等・Drive経由で全機に同期される

## ⚠️ 既知の問題: launchd文脈のmvがDriveに定着しない（2026-08-28判明・未解決）

**このジョブは実質機能していない。** 2026-08-12の導入以来、ログは0バイト＝自動実行での改名成功は一度もなかった（8/12・8/17・8/19に付与された日付はいずれもClaudeセッション内の手動バッチ）。

実測（2026-08-28 Mac mini）:
- `launchctl kickstart` で起動すると、スクリプトは正常に走り `mv` は**成功を返しログにも記録される**
- しかし数秒後に **Google Drive File Provider 側で改名が巻き戻り、ファイルは旧名のまま**になる（新名は残らない）
- 同じ `mv` を**対話シェル（Claudeセッションのbash）から実行すると定着する**。差はプロセス文脈のみ＝File Provider が launchd 起動プロセスの書き込みを同期対象にしない挙動と推測（TCC関連の可能性・根本原因は未特定）
- 定時実行（StartInterval）はそもそもログに痕跡が無い（mvが失敗を返している可能性。mv失敗時はログされない設計だった）

**当面の運用**: 日付なしファイルは notta-check スキルの手順どおり**セッション内で手動改名**する。恒久対策の候補: ①scheduled-tasks（Claude定期実行）に日付付与を組み込む（対話シェル文脈なので定着する見込み） ②Drive APIで改名するスクリプトに変更（File Provider を経由しない） ③本ジョブの廃止。→ 深石さんの判断待ち

## 解除

```bash
launchctl unload ~/Library/LaunchAgents/com.nsketch.notta-inbox-datestamp.plist
rm ~/Library/LaunchAgents/com.nsketch.notta-inbox-datestamp.plist ~/.notta-inbox-datestamp-installed
```

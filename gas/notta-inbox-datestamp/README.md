# notta-inbox-datestamp（GAS版）

Notta_Inbox（Google Drive）に着弾する文字起こしファイルへ `YYMMDD_` プレフィックスを自動付与する **Google Apps Script**。2026-08-28に旧launchd版から移行。

## なぜGASか（旧launchd版の廃止理由）

- 旧版（`launchd/notta-inbox-datestamp/`・Mac miniのlaunchd＋シェルmv）は、**launchd文脈のmvが「成功」と返るのにGoogle Drive File Provider側で巻き戻る**ため、2026-08-12の導入以来一度も機能していなかった（2026-08-28 kickstart実験で確定）
- GAS版は **Drive APIで直接改名**するためFile Providerを経由しない＝巻き戻りが起きない。Macが寝ていても動く。ローカルに認証ファイルを残さない

## 構成

- 実体: fukaishi@nsketch.com の Apps Script プロジェクト **「notta-inbox-datestamp」**（script.google.com）
- トリガー: 時間主導・**1時間おき**に `datestampNottaInbox()` を実行
- タイムゾーン: Asia/Tokyo（appsscript.json）
- 正本コード: `Code.gs`（このフォルダ。**GAS側と手動同期**＝どちらかを編集したらもう片方へ反映）

## 何をするか（旧版と同じ仕様）

1. 対象は `INSTALLED_AT`（2026-08-28）以降に作成されたファイルのみ（既存ファイルは触らない）
2. 拡張子なしファイル → 末尾空白を除去して `.txt` 付与（Zap側修正の保険）
3. 日付プレフィックスなしの `.txt` → **Drive作成日（着弾日・JST）** 由来の `YYMMDD_` を前置
4. 同名ファイルが既にあればスキップ（上書きしない）
5. ログ: GASの「実行数」ダッシュボードで実行履歴・console.logを確認できる

## 制約・運用メモ

- 日付は**Drive着弾日ベース**。長時間録音がNottaで翌日処理されると会議日と1日ズレる → 仕分け時に会議文脈で補正（notta-checkスキル参照）
- Nottaタイトル自体に日付が入っている場合（例: `260810_[湯本]相談`）は先頭6桁+_を検知してスキップ＝二重日付にならない
- 編集・トリガー変更・停止はすべて script.google.com（fukaishiアカウント）から

## 移行時の検証（2026-08-28）

- テストファイルをNotta_Inboxに作成→GAS手動実行→`YYMMDD_`付与を**Drive API・ローカル両方で実体確認済み**（テストファイル `260828_GASテスト用_削除予定.txt` は削除操作が承認されなかったためInboxに残置→深石さんが手動削除するか、次セッションで指示のこと）
- 毎時トリガー設定済み（トリガー保存時に2回目の承認画面が出る仕様＝1回目のエラーはこれが原因）
- **旧launchd版（Mac mini）は撤去せず並走中**（撤去操作が承認されなかったため。旧版のmvは巻き戻るだけで実害なし）。GAS版の安定を数日確認後、`launchd/notta-inbox-datestamp/README.md` の解除手順で撤去を推奨

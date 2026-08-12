---
name: notta-check
description: 会議の文字起こし（Notta）の確認・回収方法。「会議終わった」「nottaから持ってきて」「文字起こしある？」と言われたら必ず使用。Notta_Inboxの場所・命名規則・着弾遅延・案件フォルダへの仕分け先を記載。
---

# Notta文字起こしの確認・回収（NSK全案件共通）

会議の文字起こしは Notta → Zapier(v2) → Googleドライブの
`~/Library/CloudStorage/GoogleDrive-fukaishi@nsketch.com/My Drive/Notta_Inbox/`
に自動保存される（NSKワークスペース全案件共通の受け皿）。

## ⚠️ 先にMeet Recordingsを確認する会議（2026-08-12 深石さん指示）

**Google Meetの会議（N朝会などの社内定例・Meet開催の顧客MTG）は、まず `My Drive/Meet Recordings/` を確認**し、無かったらNottaを見る、の順にする。
- Meetの成果物＝`会議名 - YYYY MM DD HH:MM JST - Gemini によるメモ.gdoc`（Geminiメモ＋文字起こしリンク）や `〜Recording`（録画）
- `.gdoc` は175バイトのポインタファイル。`cat` して `doc_id` を取り、**Google Drive MCPの `read_file_content`（fileId=doc_id）で本文を取得**できる（Geminiメモ＋全文文字起こしが1ドキュメントに入っている）
- Geminiメモの話者ラベルもNotta同様に誤りうる。文脈と矛盾する発言は断定しない
- 使い分けの原則（2026-08-12 深石さん）: **Nスケッチ主催＝Google Meet**（文字起こし・録画はMeet Recordingsへ）／**クライアント主催・クライアント都合＝Nottaを参加させる**（Notta_Inboxへ着弾）
- **同じ会議が両方に記録されることがある**。実例: `260810_[湯本]相談`・`GSI棚卸し_260803_*` はNotta_Inboxの.txtとMeet Recordings側の同名.gdocの両方にある。逆に社内のN朝会の文字起こしがNotta_Inbox側に着弾している例もある → 見つからない・判断に迷うときは両方を確認する

## 確認手順

1. `Notta_Inbox` を見る。着弾は `Nottaタイトル.txt`（2026-08-10にZap側で `.txt` 付与を実装済み。それ以前の旧ファイルは拡張子なし）
2. さらにMac miniのlaunchdジョブが新着へ `YYMMDD_`（着弾日ベース）を自動前置する（正本: dotfiles `launchd/notta-inbox-datestamp/`）。⚠着弾日ベースのため長時間録音の翌日処理では会議日と1日ズレることがある→仕分け時に会議文脈で補正する
3. 拡張子なし・日付なしのファイルを見つけたら、その場で付与する（末尾空白は除去。深石さん指示 2026-08-10）
4. 着弾は会議終了から数分〜数十分遅れ（Teams会議も対応。終了2分後の実績あり）。無ければ時間を置いて再確認する
5. 該当ファイルを各案件フォルダの `06_Recording/YYMMDD_会議名.txt` へ移動・リネームする（日付は**会議日**。着弾日プレフィックスとズレていればここで正す）
6. 案件固有の後続処理（Notion議事録・KB反映など）は各案件のナレッジベース・プロジェクトメモリに従う

## フォールバック

- ログイン状態のブラウザで app.notta.ai を開いて本文を取得する（agent-browser --profile Default を想定。Nottaでの動作は未検証）

## 注意

- ⚠️ Nottaの話者ラベルは誤ることがある（実績: 別人の発言が藤波さん名義になった例あり）。文脈と矛盾する発言は話者を断定せず「〜と思われる」で記録する

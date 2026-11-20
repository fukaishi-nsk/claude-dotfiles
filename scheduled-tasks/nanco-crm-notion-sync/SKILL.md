---
name: nanco-crm-notion-sync
description: 平日毎朝9:40に、Linear NANCO-CRM（正本）の各社の「最新の状況」を Notion「🫂 Customers」へ一方通行で写し、結果を Slack #log_fukaishi に短く報告する（無人・Mac mini）
---

# Linear → Notion 顧客一覧の写し（自動）

深石さんの決定（2026-11-20）: 顧客の状況の正本は Linear のチーム `NANCO-CRM`。Notion「🫂 Customers」は見るための写しで、毎朝この手順で Linear から写す。**一方通行**（Notion → Linear には戻さない）。実行マシンは Mac mini（常時稼働）。
決まりの正本は `~/.claude/skills/nanco-status-update/SKILL.md`。最初に必ず読む。

時刻の理由: 藤波さんのボットが 9:18 ごろに Linear を書き直すので、その後に走らせる。

## 定数
- Linear: team `NANCO-CRM`
- Notion: Customers DB https://app.notion.com/p/2ecb60a44ee84e88adc236122ccb9771 ／ data source `collection://842d7d57-058d-4df8-a229-9cea0a2eadaf`
- 報告先: Slack `#log_fukaishi`（channel_id `C03119VSJGK`）。冒頭に `<@U02PBGQ62BB>`
- 前回の実行日時の控え: `~/.claude/scheduled-tasks/nanco-crm-notion-sync/last_run.txt`（ISO 形式1行。無ければ全件を対象にする）

## 1. 写す対象を集める
- `list_issues`（team `NANCO-CRM`、`updatedAt` が前回の実行より後。ページ送りで全部。月曜は金曜の実行より後）
- そのうち、本文に `## 最新の状況` と `ボール:` の行があるイシューだけを写す
  - ボットだけが書いたイシュー（最新の状況が無い）は写さない。新しいワークスペースや社内テスト用が混ざるため
- ボットの書き直しで updatedAt が毎朝ほぼ全件変わるので、写す前に Notion の現在の値と比べ、**違う列だけ**書く

## 2. Notion の行を決める
- 本文の「Customers: [..](<URL>)」の URL の行に写す
- 「Customers:」が無いイシュー:
  1. `notion-search`（`data_source_url` を付ける）で題名の会社名を探す。1行に決まれば、その行に写し、Linear 本文の「## 基本情報」に「* Customers: [社名](<URL>)」を足す（patch の insert_after で。ほかは触らない）
  2. 見つからなければ、Notion に行を作る（Proposal＝題名）。作った URL を同じように Linear に足す
  3. 候補が2行以上で決まらないときは何もしない。報告に「要確認」と書く

## 3. 写す列（Linear → Notion）
| Linear | Notion の列 | 書き方 |
|---|---|---|
| 題名 | Proposal | 写さない（Notion 側の会社名表記を優先。違えば報告に書くだけ） |
| ボール: | ボール（select） | そのまま。ステータスが Canceled なら空欄にする |
| 現状: | 現状 | そのまま |
| 次のアクション: | 次のアクション | そのまま |
| 期日（dueDate） | 期日 | `date:期日:start`。Linear に無ければ触らない |
| 最終接触: | 最終接触 | `date:最終接触:start` |
| 確認日: | 確認日 | `date:確認日:start` |
| 根拠: | 根拠 | そのまま。Linear のイシュー参照（`<issue … label="NANCO-2469" …/>`）は「NANCO-2469」の文字に直す。末尾に「（Linear CRM-◯◯ から写し）」を付ける |
| どんな会社: | どんな会社 | そのまま |
| 窓口: | 窓口 | そのまま |
| 経路: | 経路（select） | 「レディクル」のときだけ書く |
| 利用状況: | 利用状況（select） | Notion の選択肢にある言葉のときだけ書く。無い言葉なら書かず報告に書く |
| トライアル期限: | トライアル期限 | `date:トライアル期限:start`。あるときだけ |

- 日付は `date:<列>:is_datetime=0` を付ける
- **Linear 側が空の欄は、Notion を空にしない**（触らない）
- memo・会社URL・所在地・Started・Contract Link・顧客要望リストなど、表に無い列には触らない。行は削除しない。列の追加・選択肢の変更はしない
- select に無い値（例: 新しいボールの言葉）は書かず、報告に書く

## 4. 読み直す
書いた行のうち3件まで `notion-fetch` で開き、値が入ったことを確かめる。

## 5. 前回の実行日時を残す
すべて終わったら `last_run.txt` に今の日時（ISO）を1行で書く（`python3 -c` の1行で）。途中で止まったら書かない（次回にまた拾う）。

## 6. 報告（Slack #log_fukaishi・短く）
写した行が0件なら投稿しない。
```
<@U02PBGQ62BB> 🔁 Linear→Notion 写し M/D：N社
・社名（CRM-◯◯）: ボール 先方→こちら（深石） ほか2列
・…（5社まで。超えたら「ほか◯社」）
⚠️ 要確認: 社名（理由）
```
- 新しく作った Notion の行、Linear に足した Customers リンク、写せなかった値（select に無い言葉など）は要確認に書く
- 同じ会社に見えるイシューが2つある（ボットが shortId の無い既存イシューとは別に作った）ときも要確認に書く。統合はしない

## 権限（無人実行）
- 使うもの: Linear は NANCO-CRM の読み取りと、「Customers:」の1行を足すことだけ。Notion の Customers DB の行の更新と新規作成。Slack は #log_fukaishi への投稿だけ。`last_run.txt` への書き込み
- 使わないもの: Linear のステータス・最新の状況・期日の変更、イシューの作成・削除、コメント、Notion の行の削除・列の変更、メール・LINE の送信、削除系すべて
- Notion の Query Data Source は上限があるので使わない（notion-search と notion-fetch で足りる）
- 権限で拒否されたら止まらずに先へ進み、報告の最後に「⚠️権限スキップ」として書く

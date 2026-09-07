---
name: sora-meet-link-share
description: そら植物園MTG当日の朝、カレンダーからMeetリンクを取得してLINEグループ「nanco⇄在庫管理(そら植物園)」へ自動共有する（line-group-relayワーカーの/push経由・Slack監査ミラー付き）
---

目的: そら植物園の定例MTG（顧客はカレンダー招待に入れない運用）のMeetリンク共有を自動化する。
現行の手動運用＝深石さんがMTG当日の朝、Googleカレンダーの招待テキストをLINEグループへ貼っている
（実例: 2026-08-04 9:55／08-07 9:46／08-10 11:21。Slack C04S812EP1Q の line-relay 転写で確認済み）。
この文面の型をそのまま踏襲する。⚠送信名義は深石さん個人ではなく OA「nancoサポート」になる点だけ従来と異なる。

## 実行モード
無人モード。ブロックする質問はしない。判断できない事象は Slack `#log_fukaishi`（C03119VSJGK）に報告して保留。
創作禁止＝カレンダーに無い情報（時間変更の憶測等）を文面に足さない。

## 定数
- 対象イベント: 本人カレンダー(primary=fukaishi@nsketch.com)で `summary` が `[★nanco]そら植物園` に一致（前方一致でよい。`★`はnanco顧客会議の手動タグ）
- 送信先LINEグループ: `nanco⇄在庫管理(そら植物園)` groupId=`C1236146db7f194dc3bdaf770a3553aba`（2026-07-30参加ログで確認）
- 送信経路: Cloudflare Worker `https://line-group-relay.nsketch-nanco.workers.dev/push`（POST・Bearer認証）
  - 認証トークン: `~/.claude/scheduled-tasks/sora-meet-link-share/.push_token`（PCローカル・git管理しない。Worker側Secretsの `PUSH_TOKEN` と同値）
  - Workerは送信成否を `#nanco_カスタマーお問い合わせ`（C04S812EP1Q）へ自動ミラーする（監査ログ）
- 状態ファイル（PCローカル・git管理しない）:
  - `config.json` … `{"dryRun": true|false}`。**trueの間はLINEへ送らずSlack予告のみ**
  - `state.json` … `{"sentEventIds": [...]}`。送信済みイベントID（重複送信防止）

## 手順
1. `config.json` と `state.json` を読む。
2. Googleカレンダー `list_events`（timeZone=Asia/Tokyo）で**当日0:00〜23:59**のイベントを取得し、
   `summary` が `[★nanco]そら植物園` のものを探す。無ければ**何もせず終了**（Slack投稿も不要）。
3. 見つかった各イベントについて:
   - `id` が `state.json` の `sentEventIds` にある → スキップ（送信済み）。
   - `conferenceUrl`（Meetリンク）が無い → Slack `#log_fukaishi` に「⚠リンク無しイベントあり」と報告してスキップ。
   - **開始時刻を過ぎている** → 送らない。Slack `#log_fukaishi` に
     `🔴 <@U02PBGQ62BB> そらMTG開始後のため自動送信を見送りました・手動対応してください` ＋文面を報告（メンション必須）。
4. 文面を組み立てる（**日時とリンクだけ・2行**。2026-08-10深石さん指示「文章は不要。日時とリンクだけでよい」。
   挨拶文・タイトル・タイムゾーン行・ダイヤルイン行は付けない）:
   ```
   8月24日(月) 15:00〜16:00
   https://meet.google.com/xxx-xxxx-xxx
   ```
   日付・曜日・時刻・リンクはイベントから取る。
5. 送信:
   - `dryRun: true` → LINEへは送らない。Slack `#log_fukaishi` に
     `🔎【ドライラン】そらMTG Meetリンク共有｜本番なら以下をLINEへ送信します` ＋文面を投稿。
     `state.json` には**記録しない**（本番切替後に同イベントを実送信できるように）。
   - `dryRun: false` → Workerへ送信:
     ```bash
     curl -sS -X POST https://line-group-relay.nsketch-nanco.workers.dev/push \
       -H "Authorization: Bearer $(cat ~/.claude/scheduled-tasks/sora-meet-link-share/.push_token)" \
       -H "content-type: application/json" \
       -d '{"to":"C1236146db7f194dc3bdaf770a3553aba","text":"<文面>"}'
     ```
     レスポンス `{"ok":true,...}` を確認（**実体検証**: C04S812EP1Q にWorkerの `📤 LINEへ送信しました` ミラーが出ていることまで見る）→
     `state.json` の `sentEventIds` へイベントIDを追記 → Slack `#log_fukaishi` に `✅ そらMTGのMeetリンクをLINEへ送信しました` ＋文面＋ミラーへの言及を報告。
     失敗時（ok:false／curl失敗）は `#log_fukaishi` に `🔴 送信失敗・手動対応してください` ＋エラー全文を報告（リトライは1回まで）。

6. **遅延検知（2026-09-07 追加）**: 送信できた場合でも、**現在時刻が 10:00 JST を過ぎていたら**
   その日の早い便（09:05便）が動かなかったということなので、成功報告の末尾に
   `⚠ 09:05便が動いていません（本便は HH:MM）。スケジューラの取りこぼしを疑ってください` を必ず添える。
   ＝ 静かな失敗を静かなまま終わらせない。

## 登録状況（2026-08-24 更新 → 2026-09-07 追記）

⚠ **2026-08-10の本番切替（dryRun:false）以降、2026-08-24まで一度も実送信されていなかった**。
`state.json` が `{"sentEventIds": []}` のまま＝スケジュール登録がどこにも存在せず、タスクが起動していなかった。
実害: 2026-08-24 15:02 に松尾さまから「mtgリンクいただけますでしょうか？」と催促が来て姉崎さんが手動送信。

**現在の登録先: Mac mini（`fukaishi_macmini`）のローカル scheduled-tasks**（2026-08-24 登録・cron `5 9,13 * * 1-5` ＝ JST 09:05/13:05）。
- ⚠ この機では `~/.claude/scheduled-tasks/sora-meet-link-share/SKILL.md` は **symlinkではなく実ファイル**（登録ツールがsymlink越しの書き込みを拒否するため）。
  その実ファイルの中身は「まず本ファイル（dotfiles正本）を読んでから実行せよ」という指示になっているので、**手順の正本は引き続きこのファイル**。
  手順を変えたらここを編集すれば実行に反映される（実ファイル側の再登録は不要）。
- ⚠ **claude.ai routines 側に同じタスクが残っていると二重送信になる**。登録先はどちらか一方に統一すること。

### 2026-09-07 に判明した不具合と対策（実測）
**症状**: 9/7(月)の09:05便が `lastRunAt 2026-09-07T00:20:43Z`（＝09:20 JST）を刻んでいるのに、
`state.json` は未更新・Slack報告なし・LINE送信なし。**セッションのtranscriptも生成されていない**
（`~/.claude/projects/.../*.jsonl` に当該時刻のセッションが存在しない）。
＝ **スケジューラが「実行した」と記録しながら、実際にはエージェントのセッションを起こしていない**。

**同時に確認した横断的事実**（このMac mini全体の問題であり、そら専用の問題ではない）:
- `teams-mention-check`: `#log_fukaishi` の最終投稿は 9/2 09:10。9/3・9/4・9/5・9/7 は投稿なし（lastRunAtは今日を指す）
- `nanco-meeting-import`: 最終報告は 9/2 18:11。lastRunAt は 9/4 だが 9/3・9/4・9/5 の報告なし
- **9/2 までは3タスクとも正常に動いていた**。9/3 以降に壊れている。原因は**未特定**（Claude Code 2.1.222）

**入れた対策**:
1. `~/.claude/scheduled-tasks/sora-meet-link-share/SKILL.md` を**実ファイルに戻した**（stub＝本ファイルを読む指示）。
   毎SessionStartの `setup.sh` が実ファイルをsymlinkに戻してしまっていたため、
   同ディレクトリに `.local-realfile` マーカーを置き、**setup.sh 側にスキップ処理を追加**した。
   （symlinkのままだと `update_scheduled_task` が書き込みを拒否し、スケジュール変更ができない）
2. cron を `5 9,13 * * 1-5` → **`5 9,10,11,13 * * 1-5`（平日4便）** に増便。
   1便落ちても後続で拾える。`sentEventIds` があるので二重送信は起きない。
3. 上記「手順6 遅延検知」で、09:05便の取りこぼしを成功報告の中で必ず可視化する。

**未解決**: スケジューラがセッションを起こさない根本原因。上記2・3は**当て布**であり、
4便すべてが落ちれば依然として静かに失敗する。恒久策の候補は
「カレンダー参照を伴わない launchd + シェルスクリプトの見張り番」だが、
キャッシュした予定で送ると時間変更・中止時に誤送信するリスクがあるため**深石さんの判断待ち**。

## スケジュール（現行: Mac miniローカル `5 9,10,11,13 * * 1-5` ＝ 平日 09:05/10:05/11:05/13:05 JST）
- 2026-09-07 に2便→4便へ増便（理由は上記「2026-09-07 に判明した不具合と対策」）。
- 以下は増便前（2便）の設計メモ。考え方は変わらない。
  - 09:05便: 朝の通常便（手動運用も9時台に送っていた）
  - 13:05便: 午後MTGがその日の朝に作成されたケースの拾い直し（8/24イベントは2週間前に作成済みだが、都度作成の回もあるため）
  - それより遅く作られた突発MTG（例: 8/10の11:20作成→11:30開催）は構造上拾えない＝従来どおり手動
- 2便とも同じ手順。`sentEventIds` で重複送信は起きない。

## 本番切替（dryRun解除）の条件
1. Worker v3（/pushエンドポイント）がデプロイ済みで、テストグループ宛のE2E送信が成功していること
2. ドライラン予告の文面を深石さんが確認して `config.json` を `{"dryRun": false}` に変えること（＝これが送信承認）

## セットアップ状況・引き継ぎ
- **2026-08-10に本番稼働開始（dryRun=false・深石さん承認済み）**。初回の実送信予定は8/24(月)9:05。
- Worker v3デプロイ済み（wrangler認証済み・PUSH_TOKEN設定済み）。E2Eテスト完了＝テストグループ実送信・Slackミラー・認証/allowlist拒否とも確認済み。
- デプロイ用コードの正本: Mac mini `~/line-group-relay/`。`npx wrangler deploy` はBash許可リスト登録済み（settings.json）＝Claudeが実行可。ただしコード変更時は内容説明→デプロイの順を守る。
- Drive `カスタマー/_LINE取込ボット_提案/` への v3 反映済み（2026-08-10）。⚠Mac miniのマウントではこのフォルダの**古いファイルがdataless（実体未取得）でcat/cp/EditがEDEADLK**になる。新規書き込みは通るので、更新は「rm→cp」で置換し、直後にDrive MCPでサーバー側のfileSize/createdTimeを実体確認する（旧ファイルはDriveゴミ箱に30日残る）。
- routine: claude.ai `trig_019rsCYZsREZMBcAyqfpMxvQ`（bridge環境カスタマー・平日09:05/13:05 JST）。削除は https://claude.ai/code/routines から。
- LINE通数: グループ宛プッシュは**グループ人数分カウント**（LINE公式仕様）。そら≒9人×月2〜4回＝月18〜36通で、
  コミュニケーションプラン無料枠200通/月に収まる。横展開時は再計算すること。

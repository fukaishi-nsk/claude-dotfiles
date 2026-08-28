---
name: teams-mention-check
description: artienceのTeams(ADKテナント)@メンションを毎朝9時に直読みし、新着を古い順・原文のまま・メッセージリンク付きでSlack #2602_artience へ転写する（メール通知カバー率4割→10割化・2026-08-28制定）
---

目的: artience案件のTeams（ADKテナント・深石さんはゲスト）の@メンションを全件捕捉し、新着を**古い順に・原文のまま・Teamsメッセージへのリンク付きで** Slack #2602_artience に転写する。背景＝Teamsの@メンション通知メール（no-reply@teams.mail.microsoft→Gmail）は「不在時のみ送信」のMicrosoft仕様で、実測カバー率は約4割（2026-07-31〜08-28の19メンション中メール7通）。深石さんの指示「カバー率10割にしてほしい」「Slack 2602_artienceチャンネルへ転写」「メッセージへのリンクもほしい」「要約しないで原文のまま転写」「毎朝9時に巡回」「メッセージは古い順に」（すべて2026-08-28）に基づく。Graph API・Power Automate等の正攻法は2026-07-27調査で全滅確定（ゲスト＋管理者同意壁）。詳細はartience案件のプロジェクトメモリ teams-access-methods.md。

【実行モード】無人。ブロックする質問はしない。創作禁止＝フィードに無い情報を書かない・**原文を一字も改変しない**（@メンション名の羅列も原文の一部としてそのまま）。判断できない事象は Slack #log_fukaishi（C03119VSJGK）に報告して保留。

【権限セーフ】python3を使う場合は必ず `python3 -c "…"` の1行形式（heredoc禁止）。`sleep`は使わない（待機は `agent-browser wait`）。Gmailの送信・返信・転送、scheduled-tasksの登録・変更・削除、`rm`・`crontab` は叩かない。state.jsonの読み書きはRead/Writeツールで行う。

【定数】
- 通知先（新着メンション転写）: Slack `#2602_artience` = C0ANA7AHVRB
- 運用ログ（エラー・心拍・保留報告）: Slack `#log_fukaishi` = C03119VSJGK
- 状態ファイル: ~/.claude/scheduled-tasks/teams-mention-check/state.json（PCローカル・git管理しない）
  形式: {"seen": ["<指紋>", ...], "seededBefore": "YYYY-MM-DD", "lastHeartbeat": "YYYY-MM-DD"} ／ seenは最新60件まで保持（古いものから捨てる）
  指紋の形式: `M/D|発言者|本文の空白・改行を除いた先頭40文字`（⚠️時刻は指紋に入れない＝今日の投稿はHH:MM表示だが翌日以降M/D表示に変わり指紋が揺れるため）
- ブラウザ: agent-browserを**全コマンド** `AGENT_BROWSER_SESSION=teams-mention-check` プレフィックス＋ `--profile Default` フラグ付きで実行（実Chromeプロファイルのテンポラリコピー方式。専用セッション名により、深石さんや他タスクの agent-browser 既定セッションと衝突しない）。⚠️どちらか片方でも付け忘れると別セッションに飛んで「Access is denied」等でハマる。
- Teamsリンク定数（2026-08-28に通知メール実物＋DOM照合で確定・リンク着地検証済み）:
  - tenantId（ADK）: `d2456032-f373-4f8d-908c-3b899f0f6097`
  - WEB関連 threadId: `19:7beea823cb6a4c4bb6c805c299711669@thread.tacv2`
  - デザイン関連 threadId: `19:cbd2e5cb141a4703a2c584ad8e66b6e3@thread.tacv2`
  - メッセージリンク式: `https://teams.microsoft.com/l/message/<threadId>/<msgId>?tenantId=<tenantId>&parentMessageId=<parentId>`（msgId・parentIdはepochミリ秒。ルート投稿へのメンションは parentMessageId=msgId でよい）
  - 一般チャンネル等・未知のthreadIdが必要になったら、該当スレッドを開いた状態で `eval` の `document.body.innerHTML.match(/19:[A-Za-z0-9_-]+@thread\.tacv2/g)` で取得

【手順】
1. state.json をReadで読む（無い・壊れている場合は {"seen": [], "seededBefore": "", "lastHeartbeat": ""} として開始し、その旨を最後の報告に含める）。
2. Teamsを開く:
   `AGENT_BROWSER_SESSION=teams-mention-check agent-browser open "https://teams.microsoft.com" --profile Default`
   → `… agent-browser wait --load networkidle --timeout 30000 --profile Default`
   ※サインインリダイレクト（login.microsoftonline.com）に飛んでもサイレントSSOで自動通過する（2026-08-28実証）。通過後のURLは teams.microsoft.com/v2 または teams.cloud.microsoft のどちらでもよい。
3. `… agent-browser snapshot -i --profile Default` でツリーを取得し:
   - 🔴 パスワード入力欄・「サインイン方法の選択」等が出て自動で先に進まない場合＝セッション失効。#log_fukaishi に「🔴 teams-mention-check: Teamsセッション切れ。Mac miniの実ChromeでTeamsに再ログインしてください」を投稿して終了（state更新しない）。
   - 左ペイン「クイック ビュー」＞「メンション」のtreeitem refを特定してclick → wait --load networkidle → 再度 snapshot -i。
4. **フィードの読み取りはsnapshotのrow要素から行う**（`get text body`は長文を「…」で省略するが、snapshotのrow/gridcellには全文が入る・2026-08-28実証）。各row＝[未読有無, チャンネル, スレッド名, 「発言者: 本文全文」, 時刻]。時刻は今日分がHH:MM、それ以前がMM/DD。`date` で今日の日付を取り、HH:MMは今日の日付に正規化する。
   - 🔴 テナント確認: フィードが空に見える場合、snapshot内に「ADK」の表記（プロファイルボタン等）があるか確認。無ければnsketch自テナントに戻っている可能性＝「新着なし」と誤報せず、プロファイル／テナント切替UIでADKへの切替を試み、できなければ #log_fukaishi へ「🔴 テナント確認不能」を報告して終了（state更新しない）。
5. 新着判定（二段構え）:
   - エントリの日付が state.json の `seededBefore` より前 → 無条件で既知扱い。
   - それ以外は指紋化して seen と照合。機械一致しなくても、**同一と思われる投稿は再通知しない**（40文字の切り位置ズレ等の表記ゆれは常識判断で吸収する。誤った再通知はチャンネルのノイズになる）。
6. **新着それぞれについてメッセージリンクを構築**（新着が無ければスキップ）:
   a. そのrowをclick → wait → スレッドビュー（右ペイン）が開く。
   b. `… agent-browser eval "JSON.stringify([...document.querySelectorAll('[data-tid=timestamp]')].map(e=>e.id))" --profile Default` でid一覧（`timestamp-<epochミリ秒>`）を取得。
   c. epochミリ秒をJSTに変換し、rowの表示時刻（HH:MM/日付）と一致するものが対象メッセージの msgId。スレッドビュー最上部（ルート投稿）のidが parentId。判別できない場合はリンク無しで転写し「（リンク取得失敗）」と付記（リンク欠落を理由に転写を止めない）。
   d. チャンネル名→threadId定数でリンク組み立て。
   e. 次の新着のためにフィードへ戻る（「メンション」を再クリックすればよい）。
7. 新着あり → `#2602_artience`（C0ANA7AHVRB）へ1回の投稿にまとめて転写。**並び順は古い順（時系列昇順）＝フィードの逆順**。**本文は原文そのまま**（要約・省略・言い換え禁止。snapshotのrow全文を使い、改行は読みやすく保つ）:
   ```
   📣 Teams新着メンション 2件（artience）

   ▪️ 8/28 15:47 watanabe｜WEB関連＞0807 FB
   > （ここに原文全文）
   🔗 https://teams.microsoft.com/l/message/…

   ▪️ 8/28 16:08 松田　理沙子｜WEB関連＞0807 FB
   > （原文全文）
   🔗 …
   ```
   投稿の成功を確認してから state.json の seen へ追記（Writeツール・最新60件維持）。
   さらに PushNotification（1行: 「Teams新着メンションN件→#2602_artience」）を送る。失敗しても続行してよい。
8. 新着なし → #2602_artience には何も投稿しない。ただし state.json の lastHeartbeat が今日でない場合のみ、#log_fukaishi へ「🫀 teams-mention-check 稼働中・新着なし（HH:MM時点）」を投稿し lastHeartbeat を今日に更新（サイレント死の検知用。sora-meet-link-shareが2026-08-10〜24に無登録のまま止まっていた事故の教訓）。
9. 終了処理（エラーで途中終了する場合も必ず試みる）:
   `AGENT_BROWSER_SESSION=teams-mention-check agent-browser close --profile Default`（テンポラリプロファイルを削除してディスクを回収）。

【既知の副作用・制約（2026-08-28時点）】
- 巡回がTeamsのアクティビティを既読化しうるが、1日1回なので影響は限定的＝Teamsの通知メール（即時・約4割）は概ね温存される。**運用の整理: メール＝即時の速報（部分）／本タスク毎朝9時巡回＝全量保証（前日9時以降の分を翌朝までに確実に転写）**。
- 対象はADKテナント（artience）のみ。TANGRAM（NECテナント）は対象外＝従来どおりメール頼み。
- Chromeプロファイル（約2.1GB）を毎回テンポラリコピーする（1日1回）。
- 実ChromeのTeamsゲストセッションが失効すると読めない（手順3で検知し赤報告。深石さんがMac miniの実ChromeでTeamsを開き直せば復旧）。
- 深リンクはTeams標準のランチャー画面（「Webアプリを使用/アプリで開く」）を1枚挟む＝通知メールのリンクと同じ挙動で正常。

【登録状況】2026-08-28 Mac mini（fukaishi_macmini）に cron `0 9 * * *`（毎朝9:00 JST）で登録（当初17時→深石さん指示で朝9時へ変更）。**MacBook側には登録しない**（二重実行防止）。正本は ~/claude-dotfiles/scheduled-tasks/teams-mention-check/SKILL.md。⚠️~/.claude側のSKILL.mdは**symlinkではなく実ファイルコピー**（スケジューラのpath検査がsymlinkを「path traversal」として拒否するため・2026-08-28発覚）。正本を編集したら `cp` で~/.claude側へ同期すること。初回シード＝2026-08-28（seededBefore=2026-08-28、8/28当日16:08分までの6件はseen投入済み・#2602_artienceへ転写済み）。
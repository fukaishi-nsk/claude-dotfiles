---
name: teams-mention-check
description: artienceのTeams(ADKテナント)@メンションを毎時直読みし、新着をSlack #2602_artience へ転写する（メール通知カバー率4割→10割化・2026-08-28制定）
---

目的: artience案件のTeams（ADKテナント・深石さんはゲスト）の@メンションを全件捕捉し、新着をSlack #2602_artience に転写する。背景＝Teamsの@メンション通知メール（no-reply@teams.mail.microsoft→Gmail）は「不在時のみ送信」のMicrosoft仕様で、実測カバー率は約4割（2026-07-31〜08-28の19メンション中メール7通）。深石さんの指示「カバー率10割にしてほしい」「Slack 2602_artienceチャンネルへ転写」（2026-08-28）に基づく。Graph API・Power Automate等の正攻法は2026-07-27調査で全滅確定（ゲスト＋管理者同意壁）。詳細はartience案件のプロジェクトメモリ teams-access-methods.md。

【実行モード】無人。ブロックする質問はしない。創作禁止＝フィードに無い情報を書かない・要約で意味を変えない。判断できない事象は Slack #log_fukaishi（C03119VSJGK）に報告して保留。

【権限セーフ】python3を使う場合は必ず `python3 -c "…"` の1行形式（heredoc禁止）。`sleep`は使わない（待機は `agent-browser wait`）。Gmailの送信・返信・転送、scheduled-tasksの登録・変更・削除、`rm`・`crontab` は叩かない。state.jsonの読み書きはRead/Writeツールで行う。

【定数】
- 通知先（新着メンション転写）: Slack `#2602_artience` = C0ANA7AHVRB
- 運用ログ（エラー・心拍・保留報告）: Slack `#log_fukaishi` = C03119VSJGK
- 状態ファイル: ~/.claude/scheduled-tasks/teams-mention-check/state.json（PCローカル・git管理しない）
  形式: {"seen": ["<指紋>", ...], "seededBefore": "YYYY-MM-DD", "lastHeartbeat": "YYYY-MM-DD"} ／ seenは最新60件まで保持（古いものから捨てる）
  指紋の形式: `M/D|発言者|本文の空白・改行を除いた先頭40文字`（⚠️時刻は指紋に入れない＝今日の投稿はHH:MM表示だが翌日以降M/D表示に変わり指紋が揺れるため）
- ブラウザ: agent-browserを**全コマンド** `AGENT_BROWSER_SESSION=teams-mention-check` プレフィックス＋ `--profile Default` フラグ付きで実行（実Chromeプロファイルのテンポラリコピー方式。専用セッション名により、深石さんや他タスクの agent-browser 既定セッションと衝突しない）。⚠️どちらか片方でも付け忘れると別セッションに飛んで「Access is denied」等でハマる。

【手順】
1. state.json をReadで読む（無い・壊れている場合は {"seen": [], "seededBefore": "", "lastHeartbeat": ""} として開始し、その旨を最後の報告に含める）。
2. Teamsを開く:
   `AGENT_BROWSER_SESSION=teams-mention-check agent-browser open "https://teams.microsoft.com" --profile Default`
   → `… agent-browser wait --load networkidle --timeout 30000 --profile Default`
   ※サインインリダイレクト（login.microsoftonline.com）に飛んでもサイレントSSOで自動通過する（2026-08-28実証）。通過後のURLは teams.microsoft.com/v2 または teams.cloud.microsoft のどちらでもよい。
3. `… agent-browser snapshot -i --profile Default` でツリーを取得し:
   - 🔴 パスワード入力欄・「サインイン方法の選択」等が出て自動で先に進まない場合＝セッション失効。#log_fukaishi に「🔴 teams-mention-check: Teamsセッション切れ。Mac miniの実ChromeでTeamsに再ログインしてください」を投稿して終了（state更新しない）。
   - 左ペイン「クイック ビュー」＞「メンション」のtreeitem refを特定してclick → wait --load networkidle。
4. `… agent-browser get text body --profile Default` でフィード全文を取得。
   - フィードは新しい順。各エントリ＝チャンネル名／スレッド名（本文先頭に「スレッド名 - 」形式で混ざる場合もある）／「発言者: 本文」／時刻（今日分は HH:MM、それ以前は MM/DD）。`date` コマンドで今日の日付を取り、HH:MM表記は今日の日付に正規化する。
   - 🔴 テナント確認: フィードが空に見える場合、snapshot内に「ADK」の表記（プロファイルボタン等）があるか確認。無ければnsketch自テナントに戻っている可能性＝「新着なし」と誤報せず、プロファイル／テナント切替UIでADKへの切替を試み、できなければ #log_fukaishi へ「🔴 テナント確認不能」を報告して終了（state更新しない）。
5. 新着判定（二段構え）:
   - エントリの日付が state.json の `seededBefore` より前 → 無条件で既知扱い。
   - それ以外は指紋化して seen と照合。機械一致しなくても、**同一と思われる投稿は再通知しない**（40文字の切り位置ズレ等の表記ゆれは常識判断で吸収する。誤った再通知はチャンネルのノイズになる）。
6. 新着あり → `#2602_artience`（C0ANA7AHVRB）へ1回の投稿にまとめて転写:
   書式（1件2行以内・本文は冒頭の要旨。原文に無いことを足さない）:
   ```
   📣 Teams新着メンション N件（artience）
   ・8/28 15:00 松田さん｜WEB関連＞0807 FB｜9/3(木)17-19 or 9/4(金)12-14 でmtgのご相談 ←要返信
   ・8/28 14:14 watanabeさん｜デザイン関連｜電車の人物を後ろ向きに調整したaiデータを後ほど送付
   ```
   「←要返信」は日程調整・期日相談・質問など返答が明確に求められている場合のみ付ける（迷ったら付けない）。
   投稿の成功を確認してから state.json の seen へ追記（Writeツール・最新60件維持）。
   さらに PushNotification（1行: 「Teams新着メンションN件→#2602_artience」）を送る。失敗しても続行してよい。
7. 新着なし → #2602_artience には何も投稿しない。ただし state.json の lastHeartbeat が今日でない場合のみ、#log_fukaishi へ「🫀 teams-mention-check 稼働中・新着なし（HH:MM時点）」を投稿し lastHeartbeat を今日に更新（サイレント死の検知用。sora-meet-link-shareが2026-08-10〜24に無登録のまま止まっていた事故の教訓）。
8. 終了処理（エラーで途中終了する場合も必ず試みる）:
   `AGENT_BROWSER_SESSION=teams-mention-check agent-browser close --profile Default`（テンポラリプロファイルを削除してディスクを回収）。

【既知の副作用・制約（2026-08-28時点）】
- フィードを開くとTeams側でアクティビティが既読扱いになりうる＝①残り4割のメール通知も止まる可能性 ②Teamsアプリ内の未読バッジが消える可能性。→本タスクのSlack転写を一次チャネルとする設計（深石さん了承）。
- 対象はADKテナント（artience）のみ。TANGRAM（NECテナント）は対象外＝従来どおりメール頼み。
- Chromeプロファイル（約2.1GB）を毎回テンポラリコピーする。毎時実行で1日約27GBの書き込み。頻度を変えたい場合はcronを更新。
- 実ChromeのTeamsゲストセッションが失効すると読めない（手順3で検知し赤報告。深石さんがMac miniの実ChromeでTeamsを開き直せば復旧）。

【登録状況】2026-08-28 Mac mini（fukaishi_macmini）に cron `0 9-21 * * *`（毎日9〜21時の毎時・JST）で登録。**MacBook側には登録しない**（二重実行防止）。正本は ~/claude-dotfiles/scheduled-tasks/teams-mention-check/SKILL.md、~/.claude/... はsymlink。初回シード＝2026-08-28（seededBefore=2026-08-28、当日8/28分4件はseenに手動投入、当日分は深石さんへ対話セッションで報告済み＋#2602_artienceへ初回転写済み）。

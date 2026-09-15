---
name: teams-mention-check
description: artienceのTeams(ADKテナント)@メンションを毎朝9時に直読みし、新着を古い順・原文のまま・メッセージリンク付きでSlack #2602_artience へ転写する（メール通知カバー率4割→10割化・2026-08-28制定）。新着の添付ファイルは 00_File_from へ保存する（2026-09-15〜）
---

目的: artience案件のTeams（ADKテナント・深石さんはゲスト）の@メンションを全件捕捉し、新着を**古い順に・原文のまま・Teamsメッセージへのリンク付きで** Slack #2602_artience に転写する。**新着メッセージに添付ファイルがあれば案件フォルダの `00_File_from` に保存する**。背景＝Teamsの@メンション通知メール（no-reply@teams.mail.microsoft→Gmail）は「不在時のみ送信」のMicrosoft仕様で、実測カバー率は約4割（2026-07-31〜08-28の19メンション中メール7通）。深石さんの指示「カバー率10割にしてほしい」「Slack 2602_artienceチャンネルへ転写」「メッセージへのリンクもほしい」「要約しないで原文のまま転写」「毎朝9時に巡回」「メッセージは古い順に」（すべて2026-08-28）、「（添付を）保存してほしい」（2026-09-15。9/3〜9/14の添付3点が未格納のまま溜まっていたのが発端）に基づく。Graph API・Power Automate等の正攻法は2026-07-27調査で全滅確定（ゲスト＋管理者同意壁）。詳細はartience案件のプロジェクトメモリ teams-access-methods.md／teams-attachment-retrieval.md。

【実行モード】無人。ブロックする質問はしない。創作禁止＝フィードに無い情報を書かない・**原文を一字も改変しない**（@メンション名の羅列も原文の一部としてそのまま）。判断できない事象は Slack #log_fukaishi（C03119VSJGK）に報告して保留。

【権限セーフ】python3を使う場合は必ず `python3 -c "…"` の1行形式（heredoc禁止）。`sleep`は使わない（待機は `agent-browser wait`）。Gmailの送信・返信・転送、scheduled-tasksの登録・変更・削除、`rm`・`crontab` は叩かない。state.jsonの読み書きはRead/Writeツールで行う。添付の回収では `curl`（Dropbox直DL）・`file`・`cp -n`・`cmp`・`unzip -n` は可。**00_File_from 内の既存ファイルを上書き・移動・削除しない**（`cp` は必ず `-n`、`mv` は使わない）。

【定数】
- 通知先（新着メンション転写）: Slack `#2602_artience` = C0ANA7AHVRB
- 運用ログ（エラー・心拍・保留報告）: Slack `#log_fukaishi` = C03119VSJGK
- 状態ファイル: ~/.claude/scheduled-tasks/teams-mention-check/state.json（PCローカル・git管理しない）
  形式: {"seen": ["<指紋>", ...], "seededBefore": "YYYY-MM-DD", "lastHeartbeat": "YYYY-MM-DD"} ／ seenは最新60件まで保持（古いものから捨てる）
  指紋の形式: `M/D|発言者|本文の空白・改行を除いた先頭40文字`（⚠️時刻は指紋に入れない＝今日の投稿はHH:MM表示だが翌日以降M/D表示に変わり指紋が揺れるため）
- 添付の保存先: `$HOME/Library/CloudStorage/GoogleDrive-fukaishi@nsketch.com/Shared drives/nsketch/2602_artience/00_File_from/` 直下（ファイル名はTeams上の名前そのまま）。ステージング＝そのセッションのscratchpad（無ければ `~/.claude/scheduled-tasks/teams-mention-check/dl/`）
- ブラウザ: agent-browserを**全コマンド** `AGENT_BROWSER_SESSION=teams-mention-check` プレフィックス＋ `--profile "$HOME/.agent-browser/profiles/gmail"` フラグ付きで実行（専用永続プロファイル方式・2026-09-07〜。専用セッション名により、深石さんや他タスクの agent-browser 既定セッションと衝突しない）。⚠️どちらか片方でも付け忘れると別セッションに飛んで「Access is denied」等でハマる。
- 🚫 旧方式 `--profile Default`（実Chromeプロファイルのテンポラリコピー起動）は原則使わない＝コピー起動がそのPCの実ChromeのGoogleログインを失効させる（2026-09-07特定）。⚠️専用プロファイルは**PCごとに作成＋本人ログインが必要**（MacBook・Mac miniとも2026-09-07にログイン済み。Mac mini=Google/Teams/LINE OAM）。万一 `$HOME/.agent-browser/profiles/gmail` が無いPCで走った場合は、巡回を打ち切って「⚠️専用プロファイル未作成（このPCで本人ログインが必要）」を #log_fukaishi に1行報告する（旧方式 `--profile Default` へのフォールバックはしない）。専用プロファイルがあるのに開いた結果がサインインページなら「⚠️セッション失効（要: 専用プロファイルへの本人再ログイン）」を報告して終了する。
- Teamsリンク定数（2026-08-28に通知メール実物＋DOM照合で確定・リンク着地検証済み）:
  - tenantId（ADK）: `d2456032-f373-4f8d-908c-3b899f0f6097`
  - WEB関連 threadId: `19:7beea823cb6a4c4bb6c805c299711669@thread.tacv2`
  - デザイン関連 threadId: `19:cbd2e5cb141a4703a2c584ad8e66b6e3@thread.tacv2`
  - メッセージリンク式: `https://teams.microsoft.com/l/message/<threadId>/<msgId>?tenantId=<tenantId>&parentMessageId=<parentId>`（msgId・parentIdはepochミリ秒。ルート投稿へのメンションは parentMessageId=msgId でよい）
  - 一般チャンネル等・未知のthreadIdが必要になったら、該当スレッドを開いた状態で `eval` の `document.body.innerHTML.match(/19:[A-Za-z0-9_-]+@thread\.tacv2/g)` で取得

【手順】
1. state.json をReadで読む（無い・壊れている場合は {"seen": [], "seededBefore": "", "lastHeartbeat": ""} として開始し、その旨を最後の報告に含める）。
2. Teamsを開く:
   `AGENT_BROWSER_SESSION=teams-mention-check agent-browser open "https://teams.microsoft.com" --profile "$HOME/.agent-browser/profiles/gmail"`
   → `… agent-browser wait --load networkidle --timeout 30000 --profile "$HOME/.agent-browser/profiles/gmail"`
   ※サインインリダイレクト（login.microsoftonline.com）に飛んでもサイレントSSOで自動通過する（2026-08-28実証）。通過後のURLは teams.microsoft.com/v2 または teams.cloud.microsoft のどちらでもよい。
3. `… agent-browser snapshot -i --profile "$HOME/.agent-browser/profiles/gmail"` でツリーを取得し:
   - 🔴 パスワード入力欄・「サインイン方法の選択」等が出て自動で先に進まない場合＝セッション失効。#log_fukaishi に「🔴 teams-mention-check: Teamsセッション切れ。Mac miniで `agent-browser --profile "$HOME/.agent-browser/profiles/gmail" --headed open https://teams.microsoft.com` を開き、本人がTeamsに再ログインしてください」を投稿して終了（state更新しない）。
   - 左ペイン「クイック ビュー」＞「メンション」のtreeitem refを特定してclick → wait --load networkidle → 再度 snapshot -i。
4. **フィードの読み取りはsnapshotのrow要素から行う**（`get text body`は長文を「…」で省略するが、snapshotのrow/gridcellには全文が入る・2026-08-28実証）。各row＝[未読有無, チャンネル, スレッド名, 「発言者: 本文全文」, 時刻]。時刻は今日分がHH:MM、それ以前がMM/DD。`date` で今日の日付を取り、HH:MMは今日の日付に正規化する。
   - 🔴 テナント確認: フィードが空に見える場合、snapshot内に「ADK」の表記（プロファイルボタン等）があるか確認。無ければnsketch自テナントに戻っている可能性＝「新着なし」と誤報せず、プロファイル／テナント切替UIでADKへの切替を試み、できなければ #log_fukaishi へ「🔴 テナント確認不能」を報告して終了（state更新しない）。
5. 新着判定（二段構え）:
   - エントリの日付が state.json の `seededBefore` より前 → 無条件で既知扱い。
   - それ以外は指紋化して seen と照合。機械一致しなくても、**同一と思われる投稿は再通知しない**（40文字の切り位置ズレ等の表記ゆれは常識判断で吸収する。誤った再通知はチャンネルのノイズになる）。
6. **新着それぞれについてメッセージリンクを構築**（新着が無ければスキップ）:
   a. そのrowの**本文gridcell**をclick → wait → スレッドビュー（右ペイン）が開く（clickが「covered by」で弾かれたら既知の制約の項を参照）。
   b. `… agent-browser eval "JSON.stringify([...document.querySelectorAll('[data-tid=timestamp]')].map(e=>e.id))" --profile "$HOME/.agent-browser/profiles/gmail"` でid一覧（`timestamp-<epochミリ秒>`）を取得。
   c. epochミリ秒をJSTに変換し、rowの表示時刻（HH:MM/日付）と一致するものが対象メッセージの msgId。スレッドビュー最上部（ルート投稿）のidが parentId。判別できない場合はリンク無しで転写し「（リンク取得失敗）」と付記（リンク欠落を理由に転写を止めない）。
   d. チャンネル名→threadId定数でリンク組み立て。
   e. **添付リンクを控える**: スレッドビューを snapshot -i し、対象メッセージ（`group "<発言者> …"` 配下＝対象メッセージのまとまり）にある `link "Link <ファイル名>"` の ref を拾って `… agent-browser get attr @ref href --profile …` でURLを取得し、ファイル名とセットで控える（同じスレッドの**他のメッセージの添付は拾わない**。対象外のルート投稿の添付も拾わない）。
   f. 次の新着のためにフィードへ戻る（「メンション」を再クリックすればよい）。
7. **添付の回収**（6eで控えた添付が無ければスキップ・2026-09-15追加）。**すべての新着について6が済んでから行う**（SharePointへ移動するとTeamsへ戻す手間が要るため）:
   a. URL別の取り方（2026-09-15 実証）:
      - **Dropbox ファイル共有**（`www.dropbox.com/scl/fi/…&dl=0`＝SHA watanabeさんの定番）: `dl=0` を `dl=1` に置き換えて `curl -sSL -o "<ステージング>/<ファイル名>" "<URL>"`（ログイン不要）。
      - **Dropbox フォルダ共有**（`www.dropbox.com/scl/fo/…`）: `dl=1` で zip が落ちる → `<ステージング>/<フォルダ名>.zip` に保存 → `unzip -n "<zip>" -d "<00_File_from>/<フォルダ名>"`（⚠️未実証。失敗したら 7d の失敗扱い）。
      - **ADKのOneDrive/SharePoint**（`*.sharepoint.com`＝児玉さん等ADK側の定番）: ゲストのログインが要るので agent-browser で `navigate "<URL>"`（`?e=xxxx` まで残せば後ろの xsdata 等は不要）→ wait --load networkidle → snapshot -i → menuitem「このファイルをデバイスにダウンロードする」の ref に対して `… agent-browser download @ref "<ステージング>/<ファイル名>" --profile …`。⚠️普通の click は ~/Downloads（Bashから読めない）に落ちるので**必ず download コマンド**。
      - **上記以外**（Figma・Google Drive・一般Webページ等のリンク）は自動で落とさない＝Slack投稿に「📎 未回収（対象外リンク）: <リンク名>」と書くだけ。メッセージに直接貼られた画像（インライン画像）も対象外（未検討）。
   b. 検証: `file` で種別を確認（PDF・Illustrator・ZIP・画像等ならOK。**HTML/テキストだったらログインページ等を掴んだ失敗**）・サイズ>0。PDFなら1ページ目をReadで目視し、投稿本文のファイル名・内容と矛盾しないか見る。
   c. 格納: `cp -n` で 00_File_from へコピー → `cmp` で一致を確認。**同名ファイルが既にある場合**: cmpで同一なら「既に格納済み」扱い／中身が違えば上書きせず、#log_fukaishi に「⚠️同名別内容のため保留: <ファイル名>」と報告（別名の版を勝手に作らない）。
   d. 1件の失敗で全体を止めない（転写が主目的）。失敗は手順8の該当メッセージに「📎 保存失敗: <ファイル名>（理由）」と書く。
8. 新着あり → `#2602_artience`（C0ANA7AHVRB）へ1回の投稿にまとめて転写。**並び順は古い順（時系列昇順）＝フィードの逆順**。**本文は原文そのまま**（要約・省略・言い換え禁止。snapshotのrow全文を使い、改行は読みやすく保つ）。添付を扱ったメッセージには 🔗 の次の行に保存結果を1ファイル1行で書く:
   ```
   📣 Teams新着メンション 2件（artience）

   ▪️ 8/28 15:47 watanabe｜WEB関連＞0807 FB
   > （ここに原文全文）
   🔗 https://teams.microsoft.com/l/message/…
   📎 保存: 00_File_from/artience_web_260914.pdf

   ▪️ 8/28 16:08 松田　理沙子｜WEB関連＞0807 FB
   > （原文全文）
   🔗 …
   ```
   投稿の成功を確認してから state.json の seen へ追記（Writeツール・最新60件維持）。
   さらに PushNotification（1行: 「Teams新着メンションN件→#2602_artience」。添付を保存したら「（添付M件保存）」を付ける）を送る。失敗しても続行してよい。
9. 新着なし → #2602_artience には何も投稿しない。ただし state.json の lastHeartbeat が今日でない場合のみ、#log_fukaishi へ「🫀 teams-mention-check 稼働中・新着なし（HH:MM時点）」を投稿し lastHeartbeat を今日に更新（サイレント死の検知用。sora-meet-link-shareが2026-08-10〜24に無登録のまま止まっていた事故の教訓）。
10. 終了処理（エラーで途中終了する場合も必ず試みる。SharePointに移動したままでもよい）:
   `AGENT_BROWSER_SESSION=teams-mention-check agent-browser close --profile "$HOME/.agent-browser/profiles/gmail"`（ログイン状態は専用プロファイルに残る）。

【既知の副作用・制約（2026-08-28時点）】
- 巡回がTeamsのアクティビティを既読化しうるが、1日1回なので影響は限定的＝Teamsの通知メール（即時・約4割）は概ね温存される。**運用の整理: メール＝即時の速報（部分）／本タスク毎朝9時巡回＝全量保証（前日9時以降の分を翌朝までに確実に転写）**。
- 対象はADKテナント（artience）のみ。TANGRAM（NECテナント）は対象外＝従来どおりメール頼み。
- 専用永続プロファイルを直接使うのでプロファイルのコピーは発生しない（旧方式の約2.1GBテンポラリコピーは2026-09-07に廃止）。
- 専用プロファイル内のTeamsゲストセッションが失効すると読めない（手順3で検知し赤報告。深石さんがMac miniで専用プロファイルを `--headed` で開いてTeamsに再ログインすれば復旧。実Chromeでのログインは専用プロファイルには反映されない）。
- 深リンクはTeams標準のランチャー画面（「Webアプリを使用/アプリで開く」）を1枚挟む＝通知メールのリンクと同じ挙動で正常。
- ⚠️**フィードrow末尾の日付は「編集日」を指すことがある**（2026-09-07実測: 9/3 20:19投稿の松田さんメッセージが「編集済み」のためフィード上は09/04表示）。転写する時刻は必ず手順6bの `[data-tid=timestamp]` のepochミリ秒で確定させる（rowの日付は新着判定の粗いふるいとしてのみ使う）。
- ⚠️**agent-browserでTeamsを開くと初回はスプラッシュ（Teamsロゴ）のまま描画が止まることがある**（2026-09-07実測・数分待っても進まない）。同URLへ `navigate` し直すと描画される（着地は teams.cloud.microsoft でよい）。手順2で「クイック ビュー」がwaitで取れなければ、セッション失効と決めつける前に**まずnavigateで1回リロード**すること。
- ⚠️**rowのclickが「covered by div」で弾かれる**: フィードがスクロールしていて対象rowが画面外・ヘッダーの下にあるのが主因（2026-09-15実測）。`… agent-browser scrollintoview @ref` → 再click。それでも弾かれたら **rowのref に `focus` → `press Enter`** で開ける（2026-09-15実証）。発言者アバターは連絡先カードが開く・日付セルはホバーで「Save this message」に化ける（押すとブックマークされる）ので押さない。
- ⚠️ステージングに落としたファイルは `rm` 禁止のため残る（scratchpadはセッション単位なので実害なし。`~/.claude/scheduled-tasks/teams-mention-check/dl/` を使った場合は溜まるので、気になったら深石さんに削除を依頼）。
- ⚠️**スケジューラ側のサイレント死**（2026-09-03〜09-07に発生）: `list_scheduled_tasks` の `lastRunAt` は毎日刻まれるのに**エージェントのセッションが起動していない**事象。state.json未更新・#log_fukaishiへの心拍なし・transcript不在で判定できる。Mac mini全体の事象（sora-meet-link-share / nanco-meeting-import も同時に停止）で根本原因は未特定。対策として `~/.claude/scheduled-tasks/teams-mention-check/.local-realfile` を設置し、毎SessionStartの setup.sh が SKILL.md を symlink へ戻すのを抑止済み（2026-09-07）。

【登録状況】2026-08-28 Mac mini（fukaishi_macmini）に cron `0 9 * * *`（毎朝9:00 JST）で登録（当初17時→深石さん指示で朝9時へ変更）。**MacBook側には登録しない**（二重実行防止）。正本は ~/claude-dotfiles/scheduled-tasks/teams-mention-check/SKILL.md。⚠️~/.claude側のSKILL.mdは**symlinkではなく実ファイルコピー**（スケジューラのpath検査がsymlinkを「path traversal」として拒否するため・2026-08-28発覚）。正本を編集したら `cp` で~/.claude側へ同期すること。初回シード＝2026-08-28（seededBefore=2026-08-28、8/28当日16:08分までの6件はseen投入済み・#2602_artienceへ転写済み）。添付回収（手順6e・7）は2026-09-15追加。

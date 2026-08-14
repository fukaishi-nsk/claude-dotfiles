---
name: gmail-attachment-dl
description: Gmailメールの添付ファイルをagent-browserで自動ダウンロードし、実体検証して案件フォルダへ格納する。メール添付の回収・保存・ダウンロード依頼で必ず使用（Gmailコネクタには添付DL機能が無い）。
---

# gmail-attachment-dl — Gmail添付の自動回収

## 前提

- Gmailコネクタ（MCP）には添付ダウンロード機能が**ない**（get_messageで添付メタデータまで）。回収はagent-browserで行う
- agent-browserはHomebrew導入済み・全プロジェクト共通（v0.34.0固定運用・Mac側2026-08-13動作確認済み）。このセッションで初めて使うなら先に `agent-browser skills get core` を読む
- ⚠️ `--profile Default` を**全コマンドに毎回**付ける（実Chromeログイン状態のテンポラリコピー方式・close時自動削除。付け忘れると別セッションのabout:blankに飛び「Access is denied」でハマる）

## Windows機での前提差分（2026-07-30制定・Win機でend-to-end実証済み）

- 導入はnpmで固定バージョン: `npm install -g --allow-scripts=agent-browser agent-browser@0.34.0`（HomebrewはMacのみ・公式docsにもWin用インストーラは無くnpmが正規ルート: agent-browser.dev/installation）。⚠npm 11以降は`--allow-scripts`を付けないとpostinstall＝ネイティブバイナリ取得が黙ってブロックされる。Node未導入なら先に`winget install OpenJS.NodeJS.LTS`。実Chromeが入っていれば`agent-browser install`（Chrome for Testing取得）は不要＝実Chromeを自動検出して使う
- 0.34.0はWin機でも検証済み（2026-08-14 sinse機: npm導入・実Chrome自動検出・永続プロファイルのログイン持続・open/get/closeを確認。添付DL手順は下記＝nsketch機実証済みの型のまま）
- ⚠️ Windows機では `--profile Default` 方式（実Chromeのテンポラリコピー）は**使えない**。Windows版Chromeはcookieをデバイス/プロファイルに暗号的に紐付けるため、コピー先ではログインが引き継がれずサインインページに飛ばされる（`--session --restore` の状態復元も同じ理由で「Signed out」扱いになる。2026-07-30実測。原因はChrome 127+の**App-Bound Encryption**＝Cookie暗号鍵がUser Dataの正規パスに紐付き、コピー先では復号不能。2026-08-14特定）
- 代わりに**専用の永続プロファイル**を全コマンドに毎回付ける: `--profile "$HOME/.agent-browser/profiles/gmail"`（⚠ユーザー名がPCごとに違うため$HOMEで書くこと。同一パスで使い続ける限り暗号化は自己整合するので、closeしてもログインは残る。ログイン済み: nsketch機2026-07-30・sinse機2026-08-14）
- ログインが切れていたら（openの結果がaccounts.google.comになったら）: `--headed` を付けて開き直し、**見えるウィンドウでユーザー本人にログインしてもらう**。デフォルトはheadlessでウィンドウが存在しない点に注意（メールアドレス欄までは `fill` で代行してよい。パスワード以降は本人）
- `open` が「os error 10060」でタイムアウトする時は残骸デーモンが原因: `agent-browser close --all` で掃除してから再試行

## 手順（2026-07-27・07-28にend-to-end実証済み）

1. **メッセージIDを特定**: Gmailコネクタの search_threads / get_thread で対象メッセージの16進ID（例: `19fa67775741e354`）と添付ファイル名を確認する
2. **URL直開き**:
   ```
   agent-browser --profile Default open "https://mail.google.com/mail/u/0/#all/<messageIdHex>"
   ```
   出力タイトルが「nsketch.com メール」（正しいアカウント）であることを確認
3. **添付ボタンのrefを特定**:
   ```
   agent-browser --profile Default snapshot -i -c | grep ダウンロード
   ```
   「添付ファイル ◯◯ をダウンロード」ボタンの `@eN` を拾う
4. **保存先を指定してダウンロード**:
   ```
   agent-browser --profile Default download @eN "<保存先の絶対パス/ファイル名>"
   ```
   - ⚠️ 普通の `click` は不可視の ~/Downloads（macOS保護でBashから読めない）に落ちる。**必ず `download` コマンド**を使う
   - 複数添付は1ファイルずつ繰り返す。ページが変わったらsnapshotでrefを取り直す
   - まずスクラッチパッドに保存→検証→顧客フォルダへcp、が安全
5. **実体検証（必須・完了報告の前に）**: `ls -l`（サイズ）＋`file`（形式）＋中身の突合（xlsxならopenpyxlでシート・実データ行数・キー値をメール本文の記載と照合）。行数はExcelのmax_rowでなく**値のある実データ行**を数える（max_rowは書式だけの空行で水増しされる）
6. **格納**: 案件フォルダの規約に従う。Nanco顧客案件なら `00_File_from/YYMMDD_内容/` に配置し、`_受領記録.md` があれば受領行（受領日・経路・内容・検証結果）を追記
7. **後始末**: `agent-browser --profile Default close`（テンポラリプロファイルが自動削除される）

## 落とし穴・フォールバック

- Driveマウント先へ直接置いた場合、リンク共有前にクラウド同期完了を確認する（Drive検索でファイルIDとサイズ一致を実体確認してからリンクを貼る）
- agent-browserが不調なら `agent-browser doctor` で診断
- 復旧不能時の旧手段: claude-in-chromeで該当タブを前面に出し、ダウンロードクリックだけユーザーに依頼→移動・検証はAI（2026-07-27時点でclaude-in-chromeのページ操作系は拡張競合で故障中・読み取り系は正常）
- 学びが出たらこのファイルに追記して型を育てる（どのセッションからでも編集可）

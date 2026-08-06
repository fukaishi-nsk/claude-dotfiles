---
name: slack-file-dl
description: Slackに投稿された画像・ファイルの原本をローカルに回収する（LINE転写ボット経由の顧客画像を含む）。Slack画像の保存・ダウンロード・Linear添付・Drive格納の依頼で必ず使用（SlackコネクタMCPにはファイル実体の取り出し機能が無い）。
---

# slack-file-dl — Slack画像・ファイルの原本回収

## 前提（なぜ普通のやり方が全部ダメか・2026-08-06に実測）

Slackの `slack_read_file` はAIの画面に画像を**描画するだけ**で、バイト列をファイルに落とせない。そして files.slack.com は以下すべてで**認証を突破できない**：

| 試した方法 | 結果 |
|---|---|
| `curl` で `files-pri/<team>-<fileID>/<name>` を直叩き | HTTP 200 だが中身は**HTMLログインページ**（magic `3c2144`＝`<!D`） |
| `files-tmb/...` のサムネイルURL（トークン付き）を直叩き | 同上。トークンがあっても認証必須 |
| `agent-browser cookies get` → Cookieヘッダでcurl | **失敗**。認証cookie `d` は httpOnly で取り出せない |
| ページに `<a href="files.slack.com..." download>` を注入して `download` | **失敗**。クロスオリジンでは download 属性が無視され、コマンドも無応答のままハング |
| Slack Web UIのダウンロードボタンをクリック | ブラウザ版は「デスクトップアプリにリダイレクトしました」の壁で到達しづらい |

## 正解の手順（実証済み・原本バイト一致）

1. **Slack Web版を認証済みで開く**（`--profile Default` は毎回付ける。→ [[gmail-attachment-dl]] と同じ運用）
   ```
   agent-browser --profile Default open "https://nsketchinc.slack.com/messages/<CHANNEL_ID>/p<ts_no_dot>"
   ```
   - `/archives/...` や `/files/...` は**デスクトップアプリ誘導ページで止まる**。`/messages/...` 形式だと `app.slack.com/client/<TEAM_ID>/<CHANNEL_ID>` に着地してWeb版が開く
   - TEAM_IDはこの着地URLから拾える（Nスケッチは `T08ML4BM5`）

2. **ページ内 fetch でバイト列を掴む**（app.slack.com のオリジンなら cookie が効く）
   ```js
   window.__grab=async function(u){var r=await fetch(u,{credentials:"include"});
     var b=new Uint8Array(await r.arrayBuffer());window.__b=b;return b.length};
   window.__chunk=function(s,e){var b=window.__b.subarray(s,e);var t="";
     for(var i=0;i<b.length;i++)t+=String.fromCharCode(b[i]);return btoa(t)};
   ```
   URLは `https://files.slack.com/files-pri/<TEAM_ID>-<FILE_ID>/<元ファイル名>`。
   FILE_IDと元ファイル名は `slack_read_channel` の `Files:` 行に出ている（例 `625903470687813752.jpg (ID: F0BN33BSUD8, image/jpeg, 368.9 KB)`）

3. **base64をシェルにリダイレクトしてファイル化**（⚠ここが肝。標準出力に出すとAIのコンテキストを食い潰す＝**必ず `>` でファイルへ**）
   ```bash
   i=0; s=0
   while [ $s -lt $N ]; do
     e=$((s+60000)); [ $e -gt $N ] && e=$N
     agent-browser --profile Default --max-output 200000 eval "window.__chunk($s,$e)" > "$S/p_$i.b64" 2>/dev/null
     i=$((i+1)); s=$e
   done
   ```
   - 1チャンク60000バイト＝base64 80000文字。`--max-output 200000` を付けないと切り捨てられる
   - `String.fromCharCode.apply` は引数上限があるので**for文で回す**（applyは使わない）

4. **結合してデコード＋検証**：各 `.b64` はJSON文字列なので前後の `"` を剥がしてから連結→`base64.b64decode`。
   **サイズがSlack表示のKB表記と一致すること**（例 368.9KB → 377,797 B）と**ファイル種別のマジックバイト**（JPEG=`ffd8` / PNG=`89504e47`）を必ず確認する

5. **格納**：スクラッチパッド→検証→顧客フォルダへ `cp`。Nanco顧客なら `00_File_from/YYMMDD_LINE_話者_HHMM_内容.jpg`（既存の命名例に合わせる）。**会議中の画面共有スクショなら `06_Recording/YYMMDD_会議名/` フォルダに `YYMMDD_HHMM_会議スクショN.png`**（APAで2026-08-06実証、PNG 2.7MB/3.2MBで手順そのまま成功）。Driveマウントに置いたら**Drive API側でファイルID・サイズ一致を実体確認**してからリンクを配る

6. **後始末**：`agent-browser --profile Default close`／中間 `.b64` は消す

## Linearへ添付する場合の必須事項

- 添付手順そのものは [[reference_linear_attachment_upload]]（prepare→60秒内PUT→finalize）
- ⚠ **`create_attachment_from_upload` は添付リンク行を作るだけで、本文には画像が表示されない**。人が見て「貼られていない」と感じるのはこれ。**イシュー本文に `![説明](assetUrl)` を書いて埋め込む**こと（保存されるとLinear側が署名付きURLに書き換える＝認識された証拠）
- 完了報告は **APIの200やレスポンスではなく、実際の画面表示を見てから**。API成功＝ユーザーに見えている、ではない（→ [[feedback_verify_at_message_level]]）
- **その目視確認のやり方（2026-08-06 実証）**：
  1. `linear.app/<team>/issue/<ID>` を直接開くと **Slackと同型の壁**「Link opened in the Linear app」で止まる（`bodyLen` が146程度で本文が来ない）。DOMから `Open here instead` を含む `a,button` を探して `click()` すると本体が開く
  2. さらに **agent-browser のプロファイルがLinear未ログインのことがある**（ログイン画面が出る）。ログイン操作はAIがやらない＝ユーザーに実Chromeでログインしてもらい、**次の `open` で新しいプロファイルコピーに反映される**
  3. 開けたら次で機械判定できる。添付行だけなのか本文にレンダリング済みなのかが確実に分かる
  ```js
  [...document.querySelectorAll("img")]
    .filter(i => i.src.includes("uploads.linear.app") && i.naturalWidth > 400)
    .map(i => ({w: i.naturalWidth, h: i.naturalHeight, complete: i.complete}))
  // 原寸が返り complete:true なら本文に表示されている（添付サムネは192x192程度で別物）
  ```
  ※ SPAの描画待ちは `setInterval` で「本文テキスト＋画像」が揃うまでポーリングし、Promiseで返すと1コマンドで済む

## 落とし穴

- LINE転写ボット経由の画像は **2026-08-04 18時以降の投稿のみ**Slackに存在する。それ以前はLINE実機から（→ [[reference_line_desktop_image_capture]]）
- `agent-browser download` が無応答になったらバックグラウンドに落ちて残るので、次の操作前に `eval '1+1'` でデーモンの生死を確認する
- 学びが出たらこのファイルに追記して型を育てる
